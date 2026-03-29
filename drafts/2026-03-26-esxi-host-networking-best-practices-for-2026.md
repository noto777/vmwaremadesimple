# ESXi Host Networking Best Practices for 2026

I've been configuring ESXi networking for over a decade and the fundamentals haven't changed — isolation, redundancy, consistent MTU — but the way you implement them has. 25 Gbps uplinks are now standard for anything mid-tier. AI/ML workloads are demanding RDMA support on infrastructure that wasn't designed for it. And the NSX vs. vSwitch decision is more nuanced than "enterprises use NSX." Here's what actually matters in 2026.

## Hardware: Pick the Right NIC

Not all NICs behave the same under hypervisor load. For modern ESXi deployments, look for hardware that offloads packet processing to the NIC itself — this is what frees up vCPU cycles for your guest VMs.

What to look for:
- **TSO, LRO, GSO support** — TCP Segmentation Offload, Large Receive Offload, Generic Segmentation Offload. These shift packet processing from CPU to NIC firmware
- **SR-IOV and VMDq** — Single Root I/O Virtualization gives high-I/O VMs (databases, AI training workloads) dedicated hardware queues instead of competing on a shared NIC
- **25 Gbps uplinks minimum** for east-west traffic in mid-tier deployments. 100 Gbps for storage backends and AI inference clusters

[Intel E810 Series 25GbE NIC — validated for ESXi 8.x vNSA APIs](https://www.amazon.com/s?k=Intel+E810+Series+25GbE+NIC+—+validated+for+ESXi+8.x+vNSA+APIs)
[Mellanox ConnectX-6 Lx 25GbE — SR-IOV capable, VCF 9 supported](https://www.amazon.com/s?k=Mellanox+ConnectX-6+Lx+25GbE+—+SR-IOV+capable,+VCF+9+supported)
Check your current NIC drivers and capabilities across all hosts:

```powershell
# Requires PowerCLI 13.3 or later
Connect-VIServer -Server vcenter.yourdomain.local

# List all NICs with driver and firmware versions across every host
Get-VMHost | ForEach-Object {
    $esxcli = Get-EsxCli -VMHost $_ -V2
    $nics = $esxcli.network.nic.list.Invoke()
    $nics | Select-Object @{N='Host';E={$_.Name}}, Name, Driver, FirmwareVersion, Speed, Duplex, Link
} | Format-Table -AutoSize
```

```powershell
# Check SR-IOV capability on all hosts
Get-VMHost | ForEach-Object {
    $esxcli = Get-EsxCli -VMHost $_ -V2
    $sriovNics = $esxcli.network.sriovnic.list.Invoke()
    $sriovNics | Select-Object @{N='Host';E={$_.Name}}, Name, NumVFs, ActiveVFs
} | Format-Table -AutoSize
```

**Energy Efficient Ethernet (EEE):** Disable it on production uplinks. EEE introduces latency spikes during wake-up cycles that are unacceptable for vMotion, storage traffic, or any latency-sensitive workload:

```powershell
# Disable EEE on production uplinks across all hosts
Connect-VIServer -Server vcenter.yourdomain.local

Get-VMHost | ForEach-Object {
    $vmhost = $_
    $esxcli = Get-EsxCli -VMHost $vmhost -V2
    $nics = $esxcli.network.nic.list.Invoke()
    foreach ($nic in $nics) {
        $args = $esxcli.network.nic.set.CreateArgs()
        $args.nicname = $nic.Name
        $args.eee = $false
        $esxcli.network.nic.set.Invoke($args)
        Write-Host "[$($vmhost.Name)] Disabled EEE on $($nic.Name)"
    }
}
```

**LACP:** For bonded uplinks, use LACP Active/Active. Static trunking works but gives you no automatic failover negotiation. Match the mode to your physical switch config — Active/Active on both sides for load balancing across multiple uplinks.

## Traffic Segregation: Separate Everything

Merging traffic types onto a single port group is the most common networking mistake I see in VMware environments. It works until it doesn't — and when it breaks, it's hard to diagnose.

Four mandatory port groups:

1. **Management** — vCenter to ESXi host communication only
2. **vMotion** — live migration traffic, dedicated VLAN or VXLAN ID
3. **Storage (NFS/iSCSI)** — high-priority, low-latency, jumbo frames (MTU 9000) where supported
4. **Guest/VM traffic** — general VM communication

Create them consistently across all hosts with PowerCLI:

```powershell
# Create segmented port groups on a vSphere Standard Switch across all hosts
# Requires PowerCLI 13.3 or later — adjust VLANs for your environment
Connect-VIServer -Server vcenter.yourdomain.local

$vlanMotion   = 200
$vlanStorage  = 300
$vlanGuest    = 400
$vlanMgmt     = 100
$vSwitchName  = "vSwitch0"

Get-VMHost | ForEach-Object {
    $vmhost = $_

    # vMotion port group with jumbo frames
    New-VirtualPortGroup -VMHost $vmhost -VirtualSwitch (Get-VirtualSwitch -VMHost $vmhost -Name $vSwitchName) `
        -Name "vMotion-Optimized" -VLanId $vlanMotion | Out-Null
    Get-VirtualPortGroup -VMHost $vmhost -Name "vMotion-Optimized" |
        Set-VirtualPortGroup -Mtu 9000 | Out-Null

    # Storage NFS port group
    New-VirtualPortGroup -VMHost $vmhost -VirtualSwitch (Get-VirtualSwitch -VMHost $vmhost -Name $vSwitchName) `
        -Name "Storage-NFS" -VLanId $vlanStorage | Out-Null
    Get-VirtualPortGroup -VMHost $vmhost -Name "Storage-NFS" |
        Set-VirtualPortGroup -Mtu 9000 | Out-Null

    # Guest traffic port group
    New-VirtualPortGroup -VMHost $vmhost -VirtualSwitch (Get-VirtualSwitch -VMHost $vmhost -Name $vSwitchName) `
        -Name "Guest-Traffic" -VLanId $vlanGuest | Out-Null

    Write-Host "[$($vmhost.Name)] Port groups created"
}

# Verify
Get-VMHost | Get-VirtualPortGroup | Select-Object VMHost, Name, VLanId |
    Sort-Object VMHost, Name | Format-Table -AutoSize
```

> MTU 9000 (jumbo frames) is only safe if your physical switch ports also support it. If you enable jumbo frames in ESXi but the switch isn't configured for it, you'll get silent packet fragmentation that shows up as intermittent performance issues. Verify end-to-end.

[SCREENSHOT: vSphere Distributed Switch port group list showing Management, vMotion, Storage, and Guest port groups with VLAN assignments and MTU settings]

## vSwitch vs NSX-T: Which One Do You Need

The answer depends on whether you need micro-segmentation and east-west encryption, not on whether you're an "enterprise."

**Standard vSwitch (vSS):** Good for cost-sensitive environments, home labs, and single-site deployments where micro-segmentation isn't required. Near-native performance, minimal CPU overhead. If your security model doesn't require VM-level firewall policies, vSS is probably sufficient.

**Distributed Switch (vDS):** Step up when you need consistent port group policies across all hosts in a cluster without managing each host individually. Included with VVF and VCF.

**NSX-T:** Required when you need:
- Micro-segmentation (firewall policies at the VM level, not the VLAN level)
- East-west traffic encryption within the datacenter
- Overlay networking for multi-tenant or multi-site environments

NSX is included in VCF. It's not in VVF. If you're on VVF and want NSX features, it's a separate add-on.

If you're deploying NSX-T overlays with Geneve encapsulation, size your uplinks appropriately — overlay adds packet overhead. Ensure at least 50% uplink headroom when running heavy overlay traffic to avoid CPU saturation from encapsulation/decapsulation.

## Security: Micro-Segmentation and Monitoring

The flat network model — every VM on the same VLAN, trusting each other — is a ransomware propagation path. Configure firewall rules that follow the principle of least privilege at the hypervisor level:

- Web servers should not be able to initiate connections to database servers directly unless an explicit rule permits it
- Isolate management traffic from guest traffic at the switch level, not just the VLAN level
- NSX distributed firewall handles this natively; on vSwitch-only environments, use host-based firewall rules

**Monitoring:** You can't tune what you don't measure. Integrate ESXi network metrics into your observability stack. Watch for:

- **Packet drop rates** — indicates uplink saturation or MTU mismatches
- **Queue depth** — high queue depth means the CPU is struggling to process network interrupts
- **CRC errors** — bad cables, dirty optics, or switch port errors showing up as corruption

[SCREENSHOT: Grafana dashboard showing ESXi NIC packet drop rate and CRC error count over 24 hours, with a spike highlighted during a vMotion event]

## Troubleshooting Common Issues

**"No route to host" on NSX-T overlays**

Check Geneve VTEP configuration and MTU:

```powershell
# Verify MTU and IP configuration on all hosts
Connect-VIServer -Server vcenter.yourdomain.local

Get-VMHost | ForEach-Object {
    $vmhost = $_
    $esxcli = Get-EsxCli -VMHost $vmhost -V2
    $interfaces = $esxcli.network.ip.interface.list.Invoke()
    $interfaces | Select-Object @{N='Host';E={$vmhost.Name}}, Name, MTU, Enabled
} | Format-Table -AutoSize
```

Ensure the physical switch port supports jumbo frames if your overlay MTU exceeds 1500. Verify VTEP IP assignments in NSX Manager match what the hosts report.

**High latency or vMotion timeouts**

Isolate vMotion onto a dedicated physical NIC if possible. If sharing is required, adjust QoS policy to prioritize vMotion traffic. Check for CPU saturation on the source host — if the host is at 90%+ CPU, vMotion will time out before completing the memory copy phase.

```powershell
# Check vMotion network adapter configuration on all hosts
Connect-VIServer -Server vcenter.yourdomain.local

Get-VMHost | Get-VMHostNetworkAdapter -VMKernel |
    Where-Object { $_.VMotionEnabled } |
    Select-Object VMHost, Name, IP, SubnetMask, MTU, VMotionEnabled |
    Format-Table -AutoSize
```

**Packet loss on RDMA/RoCE workloads**

RoCEv2 requires Priority Flow Control (PFC) and Data Center Bridging (DCB) on the physical switch ports. Without PFC, congestion on RDMA flows causes silent packet drops that degrade application performance without obvious error messages. Enable PFC on the switch and verify NIC firmware supports RoCEv2 specifically.

**VLANs not working on standard vSwitch**

A standard vSwitch supports one VLAN ID per port group, per uplink. If you need to trunk multiple VLANs on a single physical link without NSX overlays, upgrade to a Distributed Switch — vDS handles VLAN trunking and policy enforcement across multiple hosts cleanly.

## Starting Your Networking Audit

Run this against your entire cluster to identify legacy drivers, unsupported NICs, and missing features before you discover the problem during a production incident:

```powershell
# Full NIC audit across all hosts in a cluster — PowerCLI 13.3+
Connect-VIServer -Server vcenter.yourdomain.local

Get-VMHost | ForEach-Object {
    $vmhost = $_
    $esxcli = Get-EsxCli -VMHost $vmhost -V2
    $nics = $esxcli.network.nic.list.Invoke()
    $nics | Select-Object `
        @{N='Host';E={$vmhost.Name}},
        Name,
        Driver,
        FirmwareVersion,
        Speed,
        Duplex,
        @{N='LinkUp';E={$_.Link}}
} | Sort-Object Host, Name | Format-Table -AutoSize
```

Find anything running at 1 Gbps in a cluster where the rest is 10 or 25 Gbps — that's your bottleneck. Find drivers that are years out of date — that's your next patching priority.

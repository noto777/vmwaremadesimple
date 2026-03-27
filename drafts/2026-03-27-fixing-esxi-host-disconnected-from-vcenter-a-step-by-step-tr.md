# Fixing 'ESXi Host Disconnected from vCenter': Step-by-Step Troubleshooting

Your host shows "Disconnected" in vCenter. VMs are still running — the hypervisor didn't crash — but you've lost DRS, HA failover, and vMotion for that host until you fix it. Here's how to diagnose and reconnect it quickly.

## What the Status Actually Means

Three states to know:

- **Disconnected** — host was previously known to vCenter but lost contact (network timeout, heartbeat loss, or `hostd` service failure)
- **Inaccessible** — more severe: network partition, authentication failure, or vCenter lost the host record entirely
- **Not Responding** — host is unreachable at the management network layer

"Disconnected" doesn't mean the host is dead. It usually means the management network timed out or `hostd` stopped responding to vCenter. Start there before assuming hardware failure.

## Phase 1: Quick Diagnosis

Check the physical layer first. I've spent 20 minutes debugging `hostd` before noticing someone had bounced a management switch port.

1. Confirm switch port status on both management and vMotion interfaces
2. Check for VLAN or ACL mismatches between the host and vCenter's management subnet
3. Trace routing from vCenter to the host's management IP

If the network layer looks healthy, pull the logs:

```bash
# On the ESXi host via SSH
# Look for: "heartbeat timeout", "connection refused", "vpxa error"
tail -n 200 /var/log/vmware/hostd/hostd.log

# On vCenter
tail -n 200 /var/log/vmware/vpxd/vpxd.log
```

## Phase 2: Service Restart (Try This First)

Restarting management services reconnects most disconnected hosts without a reboot. SSH to the host and run:

```bash
services.sh restart hostd
services.sh restart vmware-vdsocket
```

Wait 2 minutes. Watch vCenter — the host icon should go from yellow/red back to green. Verify with:

```bash
services.sh status
```

If that doesn't work, try reconnecting the management interface directly:

```bash
# Check interface names first
esxcli network ip interface list

# Disconnect and reconnect vmk0 (or whatever your management vmkernel is)
esxcli network ip interface disconnect --nic=vmk0
esxcli network ip interface connect --nic=vmk0
```

A full host reboot is the last resort — it clears all kernel-level network state but takes your VMs offline during the reboot window. Schedule it as a maintenance window.

[SCREENSHOT: vSphere Client showing host connection state transition from Disconnected to Connected after service restart]

## Phase 3: Re-add the Host from Inventory

If service restarts don't work, rebuild the inventory relationship. First, confirm two things:

1. **NTP sync** — time drift over 5 minutes breaks SSL certificate validation. Check both endpoints: `date` on the ESXi host and `date` on vCenter (via SSH or appliance shell).
2. **License validity** — an expired license causes vCenter to reject reconnection attempts.

**Via vSphere Client (GUI):**
1. Right-click the disconnected host → **Remove from Inventory** (VMs stay on the datastore, they just become orphaned)
2. Navigate to the datastore the host was using
3. Right-click datastore root → **Add to Inventory**
4. Select the ESXi host and complete the wizard

**Via PowerCLI (scriptable/bulk):**

```powershell
Import-Module VMware.VimAutomation.Core
Connect-VIServer -Server vcenter.yourdomain.local -User administrator@vsphere.local -Password $cred

$esxHost = Get-VMHost -Name "esxi-host-01.yourdomain.local"
Remove-VMHost -VMHost $esxHost -Confirm:$false
Add-VMHost -Name "esxi-host-01.yourdomain.local" -Location (Get-Datacenter "YourDC") -User root -Password $hostcred
```

## Troubleshooting Specific Errors

### "SSL certificate validation failed"

Almost always clock skew. Check time on both endpoints:

```bash
# ESXi host
date

# vCenter (via SSH or appliance shell)
date
```

If clocks are off, fix NTP on whichever endpoint is drifted, then retry. For a temporary test bypass only (not production):

```powershell
Add-VMHost -VMHost $esxHost -AcceptAllCertificates
```

For a permanent fix, regenerate the self-signed cert on the ESXi host and import it into vCenter's trust store.

### "The specified host is already registered"

vCenter's database still has the host as connected even though the UI shows Disconnected. This happens after network blips during rolling updates.

```powershell
Remove-VMHost -VMHost $esxHost -Confirm:$false
Add-VMHost -Name "esxi-host-01.yourdomain.local" -Location (Get-Datacenter "YourDC") -User root -Password $hostcred
```

### "Network unreachable" / "Connection timed out"

The host can't reach vCenter on the management network.

```bash
# From ESXi — test ICMP first
ping <vcenter-management-ip>

# Then test TCP 443
nc -zv <vcenter-management-ip> 443
```

If ICMP works but TCP 443 fails, you've got a firewall blocking outbound 443 from ESXi to vCenter — or a load balancer terminating SSL incorrectly.

### "Host name does not match certificate"

Happens when the management IP changes but the ESXi cert still has the old hostname as CN/SAN. Check the current cert:

```bash
hostname
openssl x509 -in /etc/vmware/ssl/server.crt -noout -subject
```

Regenerate with the correct hostname:

```bash
# Generate new key and self-signed cert
vmkfstools -c 2048 new-key.pem
openssl req -new -nodes -key new-key.pem -x509 -days 365 \
  -out server.crt -subj "/CN=newhostname.yourdomain.local"

# Replace and restart
rm /etc/vmware/ssl/*
cp new-key.pem /etc/vmware/ssl/server.key
cp server.crt /etc/vmware/ssl/server.crt
services.sh restart hostd
services.sh restart vmware-vdsocket
```

## Prevention

Four things that eliminate most disconnection incidents:

1. **NTP on every ESXi host** — use a domain controller or internal time source, not `pool.ntp.org` directly from production hosts
2. **Management VLAN QoS** — heartbeats are small packets; queuing delays during heavy traffic periods can drop them. Prioritize management traffic
3. **MTU consistency** — check jumbo frame settings match end-to-end if you're using them; mismatches cause fragmentation that looks like intermittent connectivity
4. **Automated alerting** — run this PowerCLI snippet on a schedule to catch disconnections before they become support tickets:

```powershell
# Alert on disconnected hosts
Get-VMHost | Where-Object { $_.ConnectionState -eq 'Disconnected' } | ForEach-Object {
    Write-Host "ALERT: $($_.Name) is disconnected" -ForegroundColor Red
    # Replace with your alerting mechanism (webhook, email, Teams, etc.)
}
```

# How to Migrate VMs Between vCenter Servers

**Meta Description:** Three methods for migrating virtual machines between different vCenter Server instances: VMware HCX for live migrations across disconnected sites, direct cross-vCenter vMotion for same-version connected environments, and OVF export/import as a fallback when the other methods do not apply.

---

## 1. Introduction

### When Cross-vCenter Migration Comes Up

Organizations split data centers into smaller zones, consolidate legacy sites, fail over between geographically separated locations, or restructure after acquisitions. All of these require moving VMs from one vCenter Server instance to another.

### Why It Is Harder Than Intra-vCenter Migration

Migrating a VM within a single vCenter domain uses the built-in Migrate wizard and usually completes without issues. Cross-vCenter migration is different: the destination ESXi hosts are not managed by the source vCenter. Network segmentation, licensing tier differences, and VM hardware version compatibility introduce failure modes that the standard wizard cannot handle.

This article covers three methods:
*   **Method A: VMware HCX** — live migration across disconnected sites without powering off VMs. Requires HCX licensing.
*   **Method B: Direct Cross-vCenter vMotion** — works when source and destination hosts share physical network connectivity and run compatible ESXi versions.
*   **Method C: OVF/OVA Export/Import** — works in all scenarios, including disconnected networks and major version differences. Requires VM downtime.

---

## 2. Pre-Migration Planning & Prerequisites

### Network Topology

Cross-vCenter migrations require network paths that internal migrations do not. Verify these before starting:

*   **vCenter-to-vCenter connectivity:** Both vCenter Servers must reach each other over HTTPS (port 443). If using PowerCLI automation, SSH access may also be needed depending on your security policy.
*   **Host-to-host connectivity (Method B only):** The source ESXi host must reach the destination ESXi host directly over VMkernel port groups dedicated to vMotion. This traffic cannot route through the vCenter management layer.
*   **IP address planning:** If source and destination VMs sit in different subnets, the VM's network stack must handle the transition. Plan for post-migration IP changes if the subnets differ.

```powershell
# Verify connectivity from a Windows admin workstation to the destination host
Test-NetConnection -ComputerName <Destination_ESXi_IP> -Port 443
```

> Run a packet capture (`tcpdump` on an ESXi host or Wireshark on a port mirror) before starting. This reveals dropped packets from intermediate firewalls or MTU mismatches that cause fragmentation during vMotion. These problems are much easier to diagnose before the migration than during it.

### Licensing & Compatibility

*   **ESXi version compatibility:** The destination ESXi hosts must support the hardware version of your VMs. Migrating from ESXi 6.7 to 8.0 requires upgrading the VM hardware version on the source side first, using the `Upgrade Hardware Version` wizard. Skipping this step causes the import to fail silently or the VM to boot with degraded device support.
*   **License tiers:** Confirm that the destination vCenter license includes the features you need. HCX (Method A) requires a separate HCX license and either SDDC Manager or a standalone HCX Manager deployment.

### Backup Strategy

Take a snapshot of every VM you plan to migrate immediately before starting. Name snapshots clearly (e.g., `Pre-Migration-20260324-1400`). Do not delete these snapshots until the VM has been running stably on the destination for at least 24 hours.

Define a rollback plan before you begin: if Method A fails mid-migration, can you revert the snapshot on the source? If Method B fails, do you have an OVF export ready to import on a temporary host?

---

## 3. Method A: VMware HCX

HCX enables cross-datacenter vMotion: VMs move between disconnected sites while remaining powered on, without requiring shared storage between source and destination.

### When to Use

*   Large-scale migrations where downtime is not acceptable.
*   Migrations between different storage arrays or protocols (SAN to NAS, for example).
*   Sites with no direct Layer 2 connectivity where HCX Network Extension provides the bridge.

### Step 1: Prepare HCX Components

1.  **Deploy HCX Manager:** Install the HCX Manager appliance on your management network.
2.  **Install HCX Agent:** Deploy the HCX agent on all source and destination ESXi hosts. This is done via the HCX Manager wizard or a deployment script.
3.  **Configure overlay networking:** HCX creates overlay tunnels that let VMs retain their IP addresses across sites. Verify that the overlay configuration matches your subnet requirements.

### Step 2: Register Hosts and Create Transport Zones

Register hosts with HCX Manager and define a Transport Zone that logically groups the source and destination sites for migration.

```bash
# Verify HCX agent status on an ESXi host
curl -k https://<HCX_Manager_IP>:443/api/v1/hosts
```

[SCREENSHOT: HCX Manager dashboard showing registered Source and Destination sites in the Transport Zone]

### Step 3: Initiate the Migration

In vCenter Server (or SDDC Manager), select the VMs to migrate.

*   **Select Source:** VMs in the source data center.
*   **Select Destination:** Target hosts in the destination data center.
*   **Network Mapping:** Map the source port group to the destination port group. HCX handles the underlying tunneling via NSX-T or HCX Network Extension.

The interface offers "Migrate Now," "Migrate Later," or scheduling options.

### Step 4: Monitor and Verify

During migration, the VM state changes from "Migrating" to "Completed." The VM stays powered on throughout. After completion:
*   Verify the IP address is unchanged (if using HCX Network Extension).
*   Confirm applications respond normally.
*   Check HCX Manager logs for any warnings about network latency or packet loss during the transfer.

> During large batch migrations, monitor bandwidth utilization on the HCX tunnel. If you see saturation, stagger the migration schedule. A saturated WAN link causes latency spikes for non-migrated VMs sharing the same network path, which may trigger application timeouts unrelated to the migration itself.

---

## 4. Method B: Cross-vCenter vMotion with Direct Connection

When HCX licensing is not available and the source and destination ESXi hosts can communicate over the physical network, direct cross-vCenter vMotion is the next option.

### When to Use

*   Single-tenant environments where you control the entire network path between sites.
*   Migrations between two vCenters managing physically connected but separately managed clusters.
*   Shared storage (SAN) environments where the datastore is visible from both sides.

### Step 1: Establish Direct Connectivity

The source ESXi host must initiate a vMotion session directly to the destination host. This requires either placing both hosts in the same Layer 2 segment or configuring routing and VLANs to permit vMotion traffic between them. Verify connectivity by pinging the destination host's VMkernel IP from the source host's VMkernel interface.

### Step 2: Prepare the Destination

Confirm the destination cluster has sufficient CPU and RAM. Check that the VM hardware version does not exceed the destination ESXi host's maximum supported version. If migrating from an older vCenter to a newer one, upgrade the hardware version on the source side first.

### Step 3: Execute Cross-vCenter vMotion

In the source vCenter, right-click the VM and select **Migrate**.
1.  Select **Change compute only** (if storage is shared or will be handled separately).
2.  Choose the migration mode:
    *   **Powered Off** migration works reliably across different vCenter instances.
    *   **Running** (live) migration across separate vCenter management domains is **not supported** by the standard vMotion wizard without HCX or Enhanced Linked Mode between the vCenters. Attempting it will fail with an "Unable to establish connection" error. If you need live migration, use Method A instead.

[SCREENSHOT: The "Migrate" wizard showing the selection of the destination cluster across different vCenter instances]

### Step 4: Cleanup

After the VM appears and runs successfully on the destination vCenter:
*   Unregister the VM from the source inventory.
*   Remove stale references to prevent the source vCenter from trying to manage decommissioned resources.

> Before powering off the VM for migration, check whether the destination host's HA settings will automatically restart the VM on a different physical host than intended. Disable HA admission control temporarily if you need precise host placement after import.

---

## 5. Method C: OVF/OVA Export/Import

When compatibility issues prevent Methods A and B — different ESXi major versions, incompatible network drivers, or no network path between sites — export and import is the remaining option.

### When to Use

*   Migrating between significantly different vCenter versions (e.g., 6.x to 8.x).
*   Moving VMs to a completely isolated environment with no network connectivity to the source.
*   One-way migrations where downtime is acceptable.

### Step 1: Export the VM

In the source vCenter, right-click the VM and select **Export OVF/OVA**. This creates a compressed archive containing the virtual disks (`.vmdk`), configuration (`.ovf`), and metadata.

```bash
# PowerCLI alternative to GUI export
Import-VIServer -Server <Source_vCenter>
Export-VM -Name "MyAppServer" -OvfPath "C:\Exports\MyAppServer.ovf" -Force
```
*Ensure the destination path has enough free disk space. OVF exports are often larger than the actual consumed disk inside the VM because thin-provisioned disks are exported at their full allocated size.*

[SCREENSHOT: The Export OVF wizard with the destination path selected]

### Step 2: Transfer Files

Move the `.ovf` and `.vmdk` files to the destination environment using SCP, FTP, or physical media. For air-gapped environments, removable drives work. For cloud-bridged transfers, upload to S3 or equivalent and download from the destination side.

> Checksum the OVF file before and after transfer. On Linux: `md5sum MyAppServer.ovf`. On Windows: `Get-FileHash -Algorithm MD5 .\MyAppServer.ovf`. If the checksums differ, the file was corrupted in transit and the import will fail with a disk validation error.

### Step 3: Import to Destination

On the destination vCenter, go to **File > Manage > Import OVF Template**. Select the `.ovf` file and follow the wizard:
*   Map existing virtual disks to local or new storage.
*   Assign the VM to a cluster.
*   Configure network mappings — the source port group name probably does not exist on the destination, so you will need to map it to the equivalent destination port group.

### Step 4: Post-Import Configuration

Power on the VM. Expect network connectivity issues: the MAC address and IP configuration from the source are preserved, but the underlying network segment has changed.

Boot into the VM and verify:
*   On Windows: `ipconfig /all` — check IP, subnet mask, gateway, and DNS.
*   On Linux: `ip addr` and `ip route` — check interface assignment and default route.

If the subnet differs from the source, update the IP configuration to match the destination network. The VM will be unreachable until this is corrected.

---

## 6. Troubleshooting Reference

| Issue | Likely Cause | Resolution |
| :--- | :--- | :--- |
| **"Storage Not Shared" Error** | Destination cluster cannot see the source datastore. | For Method B, confirm shared storage visibility. For Method C, ensure you are importing disks rather than referencing source storage. Use `vmkfstools` to convert disk formats if needed (e.g., VMFS to NFS). |
| **Hardware Version Mismatch** | Destination ESXi does not support the VM's hardware version. | Upgrade the VM hardware version in the source vCenter before migration. Check VMware's [hardware version compatibility matrix](https://knowledge.broadcom.com/external/article?legacyId=1003746) for version-to-ESXi mappings. |
| **Network Latency/Timeouts During vMotion** | Firewall blocking vMotion traffic or MTU mismatch between sites. | Verify port 8000 (vMotion) and 443 (management) are open. Check MTU settings — if one side uses jumbo frames (9000) and the other uses 1500, vMotion packets fragment and the session times out. |
| **VM Locked in Source** | Another administrator has the VM console open, or an HA operation is pending. | Check the VM's recent tasks in the source vCenter. Wait for pending HA operations to complete before retrying. |
| **OVF Import Fails** | Disk corruption during transfer or invalid UUIDs. | Re-verify checksums. If checksums match but import still fails, re-export the VM from the source — the original export may have been interrupted. |

[SCREENSHOT: Error message popup regarding datastore access and how to navigate to the solution]

---

## 7. Conclusion

The right migration method depends on your constraints:

1.  **VMware HCX**: Live migration across disconnected networks. Requires HCX licensing and overlay network setup. No VM downtime.
2.  **Direct Cross-vCenter vMotion**: Works for same-version, physically connected environments. No additional licensing beyond standard vSphere. Requires VM power-off unless using Enhanced Linked Mode.
3.  **OVF/OVA Export/Import**: Works in every scenario including air-gapped and cross-version migrations. Requires VM downtime proportional to disk size and transfer speed.

**Next Steps:**
*   **Inventory audit:** Identify which VMs need migration and group them by ESXi version compatibility and network connectivity to the destination.
*   **Test run:** Migrate a non-critical VM using Method B or C first. This validates your network paths and identifies firewall or MTU issues before you touch anything important.
*   **Internal documentation:** Record the firewall ports, VLAN configurations, and HCX tunnel settings specific to your environment. The next migration will be faster if you do not have to rediscover these.
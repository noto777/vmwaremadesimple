Meta Description: A diagnostic reference for VMware vSAN clusters covering capacity warnings, network faults, disk group failures, and command-line analysis with esxcli. Includes specific log paths, quorum math, and maintenance mode decision points.

---

# VMware vSAN Troubleshooting: Diagnosing Cluster Issues

## Starting Point: What to Check First

Before pulling logs or running esxcli commands, check the obvious. Many vSAN alerts trace back to a network change, a host that left maintenance mode uncleanly, or an NTP drift nobody noticed.

**What you need to follow along:**
*   SSH access enabled on ESXi hosts (or `esxcli` via vCenter).
*   Read-only or administrative permissions in the vSphere Client.
*   Familiarity with vSAN disk groups, components, objects, and storage policies.

### Cluster Health in the vSphere Client

Open the vSphere Client. Navigate to **Home > Hosts and Clusters**, select your vSAN cluster, then **Monitor > vSAN > Health**.

*   Red and yellow indicators here give you a starting point, but they are often symptoms rather than causes. A single host disconnection can cascade into dozens of health warnings.
*   Note the specific check names — you will need them if you open a GSS ticket.

[SCREENSHOT: The vSphere Client vSAN Health Dashboard showing a cluster with one yellow warning and one critical error]

### Physical Disk and Disk Group Status

Navigate to **Configure > vSAN > Physical Disk** (or **Disk Groups**).

*   Confirm all disks report "Online" or "Ready."
*   A failed cache drive takes out the entire disk group attached to it — every capacity drive in that group becomes unavailable. On a host with a single disk group, this means all local vSAN storage for that host is gone until the cache drive is replaced.

### Network Configuration

vSAN traffic is sensitive to packet loss and MTU mismatches. Two areas to verify:

*   **MTU:** If you use Jumbo Frames, confirm MTU 9000 is configured end-to-end — ESXi VMkernel adapters, physical switch ports, and any intermediate routers. A mismatch between two hosts causes large frame drops, which vSAN interprets as connectivity loss. The result is either degraded performance or a cluster partition.
*   **VLANs and Firewall Rules:** The vSAN VMkernel port group must be on the correct VLAN. Ports 8443 (vSAN) and 902 (VMware HA) must be open between all hosts.

### Time Synchronization

Clock skew between ESXi hosts breaks certificate validation and can prevent nodes from communicating. Configure NTP on every host and on the vCenter Server Appliance. If hosts drift more than a few seconds apart, you will see authentication failures in the vmkernel log before the health dashboard catches up.

---

## Capacity Warnings When Disk Space Looks Fine

A **"Not Enough Capacity"** or **"vSAN Object not compliant"** alert with apparently plenty of raw disk space usually means the storage policy cannot be satisfied given the current cluster state — not that you are out of disk.

### Diagnosing the Gap

Three things to check:

1.  **Host availability.** Is a host in maintenance mode, disconnected, or powered off? vSAN cannot place replicas on unavailable hosts. With FTT=1 (two copies) on a three-host cluster, losing one host means there is nowhere to place a second replica for objects that lived on the failed host.
2.  **Disk group failures.** A failed cache drive removes that entire disk group from the available capacity pool. On hosts with one disk group, this effectively removes the host from vSAN storage.
3.  **Storage policy math.** FTT=1 requires at least three hosts. FTT=2 requires five. If you are at the minimum host count and lose one, the cluster cannot satisfy the policy. The alert is accurate — you do not have enough capacity for the configured redundancy level.

### Reconnecting a Failed Host

If the problem is a disconnected host:

1.  In the vSphere Client, select the host and go to **Configure > vSAN > Maintenance Mode**. Choose "No data migration" to bring it back quickly, or "Full data migration" if you need vSAN to redistribute objects first. The choice matters: "No data migration" is faster but leaves the cluster in a degraded policy compliance state until the host finishes resynchronizing.
2.  If the host will not reconnect, SSH in and check the vmkernel log:

```bash
# Connect via SSH
ssh root@<esxi-host-ip>

# Tail the vSAN specific logs for errors
tail -f /var/log/vmkernel.log | grep -i "vsan"

# Check for network or hardware errors specifically around the time of failure
grep -E "(vmknic|link down|disk)" /var/log/vmkernel.log
```

Messages about lost connectivity to the vSAN network or disk controller errors point to hardware or cabling problems rather than configuration. A host reboot may clear transient states; persistent errors usually mean a component replacement.

[SCREENSHOT: The vSphere Client showing a host in "Maintenance Mode" with a progress bar for data migration]

---

## Network Latency and Packet Loss

vSAN requires sub-millisecond latency within a cluster (VMware's documentation specifies <1ms for non-stretched clusters). Packet loss at any rate degrades replication and can prevent object placement entirely.

*   **Symptoms:** Object migrations stall, write performance drops, capacity warnings appear despite available disk space.
*   **Diagnosis:** Check for drops on the vSAN VMkernel interface:

```bash
# Replace vmk10 with your actual vSAN VMkernel adapter name
esxcli network ip connection list -I vmk10 | grep -E "(tx_drop|rx_drop)"

# Check for high latency
ping -c 100 -s 8972 <destination-host-ip>
```

If you find drops, check physical switch buffer utilization, NIC teaming policy (MAC-based or IP hash — not the default route based on originating virtual port, which does not distribute vSAN traffic well), and cable integrity.

## Disk Group Corruption or Stale Components

A disk group can report as healthy in the UI while individual components are stuck in a "stale" state, making data inaccessible.

*   **Symptoms:** Component count mismatches in the vSAN UI; specific objects report "Unhealthy" despite all disk groups showing online.
*   **Diagnosis:**

```bash
esxcli storage core device list | grep -A 5 "vSAN"
esxcli storage vmfs extent list
```

*   **Resolution options:**
    *   A host reboot clears many stale component states. This is the least destructive option.
    *   If rebooting does not help, force a storage rescan:
    ```bash
    esxcli storage core device scan
    esxcli storage vmfs unmount -v <volume-name>
    # Re-scan and remount if necessary
    ```
    *   Removing and recreating a disk group is a last resort — it destroys all data on the capacity drives in that group. Before doing this, confirm that all objects have replicas on other hosts by checking component placement with `esxcli vsan object component list`.

## vCenter Communication Loss

If vCenter goes offline, the vSAN cluster continues running — VMs stay up, I/O continues. What you lose is management visibility and the ability to make configuration changes.

*   **Symptoms:** vSphere Client shows "Disconnected," but VMs are accessible via their guest OS.
*   **Recovery:**
    1.  Restart vCenter services or reboot the VCSA.
    2.  Once vCenter reconnects, run `esxcli storage core device scan` on each host to re-establish metadata synchronization.
    3.  If the cluster does not re-register automatically, you may need to remove and re-add the cluster object in vCenter. This does not affect running VMs or vSAN data — it is a management plane operation only.

## Storage Policy Non-Compliance During Rebuilds

During host rebuilds or replacements, objects may show "Non-Compliant" because the cluster temporarily cannot satisfy the FTT policy.

*   **Symptoms:** Red checkmarks under **Monitor > vSAN > Health > Storage Policy Compliance**.
*   **What to check:**
    *   Confirm you have enough healthy hosts to satisfy the FTT level. For FTT=1, you need at least three hosts online.
    *   If replacing a host, ensure the new host has compatible disk configurations and has been added to the cluster before starting data migration from the old host.
    *   After resolving the underlying issue, force a compliance recheck:
    ```bash
    # In the vSphere Client UI:
    # Right-click Cluster -> vSAN -> Disk Groups -> Check Compliance
    ```
    vSAN will re-evaluate all object placements. This can take minutes to hours depending on the number of objects and cluster size.

[SCREENSHOT: The vSAN Health Monitor showing "Storage Policy Compliance" status with a list of non-compliant objects]

---

## Command-Line Diagnostics with esxcli

When the vSphere Client does not give enough detail, these commands provide granular information.

### Object Health

```bash
# Get detailed info on a specific vSAN object (replace UUID)
esxcli vsan object list -o <object-uuid>

# View the health status of all objects on a host
esxcli vsan object list
```

### Cluster Membership and Quorum

vSAN requires a quorum of `floor(N/2) + 1` hosts for write operations. If the available host count drops below this threshold, the cluster goes read-only to prevent split-brain data corruption.

```bash
# Check the current vSAN cluster membership status
esxcli vsan cluster get

# View the status of specific components and their placement
esxcli vsan object component list -o <object-uuid>
```

### Log Analysis

`/var/log/vmkernel.log` is the primary log for vSAN diagnostics on each host.

```bash
# Search for vSAN errors in the last 1000 lines
grep "vsan" /var/log/vmkernel.log | tail -n 1000

# Search specifically for disk I/O errors or latency spikes
grep -E "(I/O error|latency|timeout)" /var/log/vmkernel.log
```

If the logs do not point to a clear cause, collect a full support bundle via the vSphere Client (**Support > Collect Support Bundle**) or using the `vm-support` command on the host. VMware GSS will need this bundle to investigate further.

---

## What to Do Next

vSAN is designed to self-heal — it will attempt to rebuild object replicas on remaining hosts after a failure. Many "critical" alerts reflect this in-progress state rather than permanent damage. The question is how long you can tolerate the reduced redundancy while the rebuild completes.

If you are running a three-host cluster with FTT=1 and lose a host, you have zero fault tolerance until that host returns or is replaced. There is no safety margin. This is a design constraint, not a bug, and it is worth understanding before the failure happens rather than after.

For ongoing monitoring, feed vSAN health metrics into whatever monitoring system you already run — Prometheus, Nagios, vRealize Operations, or similar. The vSphere Client health dashboard is useful for interactive troubleshooting but does not replace persistent alerting.
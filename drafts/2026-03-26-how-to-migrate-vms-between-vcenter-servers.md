# How to Migrate VMs Between Independent vCenter Servers

Moving VMs between two separate, unlinked vCenter servers is one of those tasks that sounds simple and isn't. The VMs live on ESXi hosts, but their identity — configuration, inventory registration, management context — belongs to the source vCenter. You can't drag and drop across vCenter instances. You have to re-register the VM in the destination's inventory while preserving disk data and network config.

Here's how to do it cleanly.

## Prerequisites

Get these right before you touch anything.

### Network Connectivity

Port 443 (HTTPS) must be open from your migration workstation to both vCenter servers. If you're connecting directly to ESXi hosts (bypassing vCenter), you also need Port 902 open.

Verify DNS resolution from your migration workstation — you need to reach both vCenter hostnames, not just IPs. Name resolution failures during the deployment phase are a common source of "Connection refused" errors that aren't actually connection problems.

[SCREENSHOT: Network diagram showing source vCenter, destination vCenter, ESXi hosts, and migration workstation — with port 443 and 902 labeled]

### Credentials

You need valid credentials for **both** vCenter environments:

- Source: `Read/Write` on the inventory — enough to power off VMs and export metadata
- Destination: sufficient privileges to create VMs and register them in the target datacenter and cluster

Use domain service accounts, not local ESXi host accounts. Avoid local admin credentials for migration scripts — credential changes or lockouts mid-migration are painful.

### Inventory Check: Prevent Name Collisions

Before starting, search the destination vCenter for VMs or hosts that share names with your source environment. A VM named `WebServer-01` in both inventories will cause the migration to fail immediately with "Object with this name already exists." Rename conflicting objects on the destination side first.

### Backups

Take a snapshot of production VMs before starting. For non-production VMs, a pre-migration snapshot is enough. For production: use Veeam, Commvault, or your existing backup tool and verify restore capability before you touch the live environment.

No exceptions on this. Network blips, storage overflows, and unexpected power events happen.

## Choosing Your Migration Method

### Method A: VMware vCenter Converter Standalone (Free)

[VMware vCenter Converter Standalone — free download via Broadcom Customer Portal](https://www.amazon.com/s?k=VMware+vCenter+Converter+Standalone+—+free+download+via+Broadcom+Customer+Portal)
Converter Standalone is the right tool for most cross-vCenter migrations, especially between disconnected environments. It acts as an intermediary: connects to the source ESXi host, pulls virtual disk data, and creates a new VM definition on the destination ESXi host registered to the destination vCenter.

Works for hot (powered-on) and cold (powered-off) migrations. Can convert between different hypervisors. Handles thick-to-thin disk conversion during the move.

Download and install it on a Windows workstation with network access to both environments.

### Method B: Enterprise Tools (HCX / SRM)

If you're already running VMware HCX or Site Recovery Manager, these provide more sophisticated cross-vCenter migration with near-zero downtime — but they're enterprise licensed tools most environments don't have deployed for day-to-day use.

For most consolidation or upgrade migrations, Converter Standalone is the right call. It's free and doesn't require anything you don't already have.

## Step-by-Step: Hot Migration with Converter Standalone

[SCREENSHOT: vCenter Converter Standalone wizard — Source Configuration screen showing VMware vSphere selected]

### Step 1: Launch and Define the Source

Open Converter Standalone. In the Source section:
- Select **VMware vSphere**
- Enter the Source vCenter Server hostname or IP
- Enter credentials with Read/Write access

If the vCenter service is unreachable but the ESXi host is accessible, you can enter the ESXi host IP directly — this bypasses inventory filtering but works when vCenter is down.

### Step 2: Select VMs

Browse the source inventory and select the VMs to migrate. If you have many, filter by name pattern (e.g., `*PROD*`). For hot migrations: confirm "Power off after conversion" is **unchecked**.

### Step 3: Define the Destination

- Select **VMware vSphere** for the destination
- Enter the Destination vCenter Server hostname
- Enter credentials with VM creation privileges
- Select the correct datacenter and cluster — this determines where the new VM object lands

### Step 4: Network and Storage Mapping

[SCREENSHOT: Converter Standalone network mapping table showing source VLAN-10 mapped to destination VLAN-20]

Converter will try to auto-map networks. In cross-vCenter migrations, VLANs often differ between environments — review the network mapping table manually.

For storage: if the destination ESXi hosts can't see the source datastore (different SAN, different vSAN cluster), Converter creates new VMDKs on an accessible destination datastore and copies data over the network. This is expected behavior — you don't need to fix it unless you specifically require the VM to keep its original datastore UUID.

### Step 5: Start the Conversion

Review settings and click **Start**. Converter streams VMDK data from the source host to the destination, creating a new VM in the destination vCenter inventory. Monitor the progress bar and watch for warnings about missing drivers or network mismatches.

[SCREENSHOT: Converter Standalone conversion progress screen showing percentage and estimated time]

### Step 6: Post-Migration Verification

After completion:
1. Open the Destination vCenter and find the new VM (it may have a `-(Converted)` suffix)
2. Power it on
3. Verify network connectivity, IP addresses (especially if static), and application functionality
4. If everything checks out, decommission or power off the source VM

Don't delete the source VM until you've verified the destination copy is fully operational.

## Common Issues and Fixes

### "Object with this name already exists"
A VM or host with that name is already in the destination inventory. Find it in destination vCenter, rename or delete it, then re-run.

### Network adapter mismatch
The destination uses different VLANs. During the Converter wizard, manually map source network adapters to the correct destination port groups. If using DHCP, confirm the destination DHCP scope covers the subnet your VM needs.

### Storage not found on destination
Expected in cross-storage migrations. Converter creates new VMDKs on accessible destination datastores — this is correct behavior. Only an issue if you need to preserve a specific datastore UUID.

### Permission denied
The service account lacks "Virtual Machine Inventory" or "Host Inventory" read/write permissions. Also verify port 902 is open if connecting directly to ESXi hosts.

### VM boots but hangs at login screen (hot migration)
VMware Tools aren't installed or are outdated on the source VM. Converter tries to reinstall them — if the guest OS has security lockdowns blocking that, you'll get a reboot loop. Verify VMware Tools are current on source VMs before starting hot migrations.

## Practical Notes

**Time zone consistency** — source and destination vCenter servers and ESXi hosts should be in the same time zone (or at least NTP-synced). Time drift causes SSL certificate validation failures during API calls.

**ESXi version gaps** — if the destination cluster runs a newer ESXi version than the source, Converter will adjust VM hardware compatibility levels (VMX). Confirm your destination ESXi version supports the virtual hardware your applications require.

**Static IP VMs** — if your VM has a static IP and the destination is on a different subnet, update the IP in the guest OS after migration before you decommission the source. Don't rely on DHCP to sort it out if the VM was static.

**Automate pre-checks for bulk migrations** — if you're migrating 20+ VMs, write a PowerCLI script to inventory source VMs, check for name conflicts in the destination, and verify network mappings before you start the first conversion:

```powershell
# Quick bulk pre-check: find name conflicts between vCenters
Connect-VIServer -Server source-vcenter.yourdomain.local -User $user1 -Password $pass1
$sourceVMs = Get-VM | Select-Object -ExpandProperty Name
Disconnect-VIServer -Server source-vcenter.yourdomain.local -Confirm:$false

Connect-VIServer -Server dest-vcenter.yourdomain.local -User $user2 -Password $pass2
$destVMs = Get-VM | Select-Object -ExpandProperty Name
Disconnect-VIServer -Server dest-vcenter.yourdomain.local -Confirm:$false

$conflicts = $sourceVMs | Where-Object { $destVMs -contains $_ }
if ($conflicts) {
    Write-Host "Name conflicts found — resolve before migrating:" -ForegroundColor Yellow
    $conflicts | ForEach-Object { Write-Host "  - $_" }
}
else {
    Write-Host "No name conflicts found. Safe to proceed." -ForegroundColor Green
}
```

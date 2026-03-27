# VCF 9 Migration: SDDC Manager Setup and Nested Lab Design

VCF 9 isn't optional if you're adding Gen12 hardware or need current security patches — Broadcom cut off Gen12 driver support for pre-9 releases. If you're still on VCF 8 and your hardware refresh is coming up, here's what the migration actually involves.

## Prerequisites

Before you touch anything, check your SDDC Manager version:

```bash
sddcmanager-cli --version
# or
cat /opt/vmware/sddcmanager/etc/version.txt
```

You need **8.10 or later** for a direct upgrade path. Anything older requires an intermediate VLCM step first — add that to your timeline.

Also verify NSX-T compatibility against the VCF 9 release notes before you start. Some older NSX-T builds are missing the kernel modules for the new distributed firewall features.

**Back up before you do anything else.** I don't care how confident you are — back up.

```powershell
# Export current cluster state via PowerCLI
Connect-VIServer -Server vcenter.yourdomain.local -User administrator@vsphere.local -Password $cred

Get-Cluster | Export-Csv C:\temp\pre_migration_clusters.csv -NoTypeInformation
Get-VM     | Export-Csv C:\temp\pre_migration_vms.csv -NoTypeInformation
```

Then run the SDDC Manager native backup:

```bash
sddcmanager-cli backup
```

Store these artifacts **outside** the management network segment.

## SDDC Manager Configuration

[SCREENSHOT: SDDC Manager dashboard showing version, cluster health, and patch status]

The appliance specs matter. I've seen setups where someone deployed SDDC Manager on a shared datastore and then hit a disk-full condition that locked out both compute and management at the same time. Don't do that. Give it a dedicated datastore — minimum 1 TB SSD, RAID 1 or vSAN-backed.

Minimum specs for the management appliance:
- 2x Intel Xeon Gold or AMD EPYC
- 64 GB RAM
- 1 TB NVMe SSD (dedicated, not shared with ESXi boot partitions)

**Networking:** Management, vMotion, and storage traffic need to be isolated — not just separated by VLAN, but enforced by separate uplinks if your hardware supports it. And use internal NTP, not 8.8.8.8 or external public pools. External DNS latency spikes will cause SDDC Manager to lose contact with NSX-T controllers at the worst possible moments.

```bash
# /etc/ntp.conf — use your own internal NTP sources
server ntp1.yourdomain.local iburst
server ntp2.yourdomain.local iburst
restrict default kod nomodify notrap nopeer noquery
restrict 127.0.0.1
```

Enable MFA on SDDC Manager immediately after setup. Disable HTTP and any legacy REST API endpoints you're not actively using (`/opt/vmware/sddcmanager/conf/` controls these). Update all plugins and NSX components to the latest patch level before creating any workload clusters.

```bash
# Check plugin status
sddcmanager-cli plugin list --status

# Verify NSX component versions
nsx-t-cli version check --local
```

## Nested Lab Design

[SCREENSHOT: Nested lab topology showing foundation layer, management network isolation, and nested ESXi hosts on separate VLAN]

The rule with nested labs: **always build the foundation layer on stable physical hardware first.** I've seen people try to nest SDDC Manager directly onto a resource-constrained home lab host and end up with datastore exhaustion and controller heartbeat timeouts within hours.

Foundation layer baseline:
- vSphere 8.0 Update 2 minimum
- NSX-T Data Center 4.5
- Dedicated management VLAN that doesn't overlap any production traffic

Assign static IPs to all management interfaces. DHCP conflicts during failover testing are a time sink.

Keep nested vSAN storage completely separate from the foundation layer storage. Don't run nested ESXi hosts on the same datastore as SDDC Manager unless you've enforced strict VLAN tagging and firewall rules.

For network isolation in your lab, this Terraform variable block gives you the structure you want:

```yaml
# Nested Lab Network Isolation — Terraform variable block
variables:
  foundation_mgmt_cidr: "10.10.10.0/24"
  nested_mgt_cidr: "10.10.20.0/24"
  storage_cidr: "10.10.30.0/24"

deployment_config:
  management_network_cidr: "${var.foundation_mgmt_cidr}"
  nested_management_network_cidr: "${var.nested_mgt_cidr}"
  storage_network_cidr: "${var.storage_cidr}"
  isolate_management: true
```

Set CPU reservations and memory limits on nested workloads so they can't starve the foundation layer during peak testing.

## Troubleshooting

**"Database connection failed" or "NSX Controller unreachable"** — the most common upgrade failures. Check `/var/log/vmware/sddcmanager/` first. These errors almost always trace back to firewall rules blocking port 443 between the management appliance and the NSX Manager API endpoint.

**Storage full during upgrade** — don't assume the system auto-cleans temp files. It doesn't. Manually clear archived logs older than 30 days before you start:

```bash
# Check log age and manually purge per your retention policy
find /var/log/vmware/sddcmanager/ -name "*.log" -mtime +30 -delete
```

**CPU saturation before upgrade** — if the SDDC Manager node is running at sustained 90%+ CPU, the upgrade agents will hang or fail API calls. Check vCenter Performance Charts first. Don't start a VCF upgrade on a node that's already struggling.

**DNS latency** — verify that internal names resolve within 50ms from the management network. Slow DNS causes NSX-T health check timeouts that look like connectivity failures.

```bash
# Verify NSX Manager API is reachable
curl -k https://<nsx-mgr-ip>/api/1.0/admin/configs -H "Authorization: Bearer <token>"
```

**Log every step with timestamps.** After the migration, you'll want a changelog of exactly what was updated, what anomalies appeared, and when. Issues that surface a week later are much easier to debug when you have that record.

[AFFILIATE: Dell PowerEdge Gen12 servers validated on VCF 9 HCL]

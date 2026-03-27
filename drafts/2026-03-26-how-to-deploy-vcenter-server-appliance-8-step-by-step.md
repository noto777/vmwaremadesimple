# How to Deploy vCenter Server Appliance 8 (Step-by-Step)

vCSA 8 is a substantial jump from 7.x — it's built on RHEL 9, ships with native Tanzu Kubernetes Grid integration, and has meaningfully better performance from the containerized architecture. If you're standing up a new environment or migrating from vCSA 7, here's the full deployment process.

## What You Need Before Starting

- ESXi host running vSphere 7.0 U3 or later (vSphere 8.x for full feature compatibility)
- vCSA 8.0 OVA downloaded from the [Broadcom Customer Portal](https://support.broadcom.com) — ensure you grab the x86_64 build
- Valid vCenter Server 8.x license key (7.x keys won't activate on vCSA 8)
- DNS working in both directions: forward lookup for the vCenter hostname, reverse lookup for the IP
- Static IP assigned for the management interface — don't deploy vCenter on DHCP
- 32 GB RAM and at least 100 GB datastore space available on the target ESXi host

[SCREENSHOT: Broadcom Customer Portal showing vCSA 8.0 download page with OVA file selected]

**A word on the backup requirement if you're migrating from 7.x:** There's no undo. Once you decommission the old vCSA and stand up the new one, data loss is possible if something goes wrong. Use the VCSA native backup or Veeam before touching the live environment. If possible, deploy vCSA 8 as a new appliance on a separate datastore, validate it fully, then decommission the old one.

```powershell
# Check current vCenter version before migration
Connect-VIServer -Server old-vcenter.yourdomain.local
$global:DefaultVIServer.Version
```

## Hardware Specs

| Setting | Minimum | Production Recommended |
|---|---|---|
| CPU | 4 cores | 8+ cores |
| RAM | 16 GB | 32 GB (64 GB if running Tanzu workloads) |
| Disk | 50 GB | 100+ GB (logs and DB grow fast) |
| Network | Dedicated management VLAN | Required — don't share with VM guest traffic |

Don't deploy vCSA on an ESXi host that's already near capacity. The appliance needs headroom for HA, DRS, and update operations. I've seen vCSA become unresponsive when the host it lives on hits 95% memory utilization.

## Deploying via vSphere Client (OVF Method)

This is the most common path — works for single-node and small cluster deployments.

### Step 1: Initiate OVF Deployment

1. Log into the vSphere Client (HTML5) on the ESXi host where you're deploying
2. Select the target host or cluster
3. Click **Actions** → **Deploy OVF Template**

[SCREENSHOT: vSphere Client HTML5 — "Deploy OVF Template" dialog open, with local file selected]

### Step 2: Upload and Validate the OVA

Select your `vcsa-all-8.0.x.x.ova` file. The wizard validates the file signature and lists available hardware configurations. If signature validation fails, re-download the OVA — don't skip signature validation in production.

### Step 3: Configure Virtual Hardware

| Setting | Value |
|---|---|
| vCPUs | 8 (production), 4 (test/dev) |
| RAM | 32 GB minimum for production |
| Disk | 100 GB minimum — select the target datastore here |

[SCREENSHOT: "Configure Virtual Hardware" step showing CPU set to 8 cores, RAM to 32 GB, and datastore selection]

### Step 4: Network Mapping

Map the Management Network interface to your dedicated management VLAN. Get this right — if you select the wrong port group here, the appliance will come up on the wrong network and you'll have to redeploy.

> DNS must work from this network. If vCSA can't resolve its own hostname and the hostnames of your ESXi hosts, service discovery fails immediately after first boot.

### Step 5: Deploy

Review the summary:
- Version: 8.0.x
- CPU / RAM / Disk: verified
- Network mapping: correct management VLAN
- Storage path: correct datastore with sufficient free space

Click **Finish**. The OVF tool provisions virtual disks, creates the VM, and powers it on. Depending on your storage and network speed, this takes 5-20 minutes.

[SCREENSHOT: OVF deployment progress bar at ~60% — "Provisioning disk 2 of 3"]

## First Boot: Initial Configuration

After deployment completes, the appliance reboots. You'll see the IP address in the VM console output.

### Step 1: Access the Web UI

Open a browser to `https://<management-ip>`. Accept the self-signed certificate warning for now.

Login with the default `root` user. The temporary password is shown in the console output during the first boot sequence — it's visible for 15 seconds.

[SCREENSHOT: vCenter Server 8 login screen in browser showing initial temporary password prompt]

### Step 2: Change Root Password

First thing after login. Set a strong password meeting complexity requirements (uppercase, lowercase, number, symbol, minimum 8 characters). The appliance won't let you skip this.

### Step 3: Configure NTP

vCenter depends on accurate time for SSL certificate generation, database integrity, and HA. Clock skew over 5 minutes will cause certificate validation failures across your cluster.

Navigate to **Administration** → **Time Configuration**. Add your NTP sources. Use internal time sources if you have them — your domain controller, a dedicated NTP appliance. Set the time zone to match your datacenter.

### Step 4: Activate the License

**Administration** → **License** → enter your 8.x subscription key → **Activate**. Verify the UI shows "Licensed" status before proceeding.

[SCREENSHOT: Administration → License page showing "Licensed" status with vCenter Server 8 Standard selected]

## Post-Deployment Validation

Before declaring success, run through this checklist:

```bash
# SSH into vCenter as root or via Appliance Shell
# Check core services
systemctl status vmware-vpostgres
systemctl status vmware-cps
systemctl status vmware-stun
```

All three should show `active (running)`. If `vmware-vpostgres` is down, the inventory won't load. Restart it via `systemctl restart vmware-vpostgres` and check the logs at `/var/log/vmware/vpostgres/`.

Then verify via the UI:
1. **Inventory** view loads and shows your ESXi hosts with green status
2. **Administration** → **Certificates** — no immediate expiry warnings
3. Ping vCenter from a client machine, confirm HTTPS access works cleanly

## Common Issues

**"Invalid License Key"**
Almost always a 7.x key being entered on vCSA 8. Check the key format — 8.x keys have a different structure. If you're migrating, note that license migration requires specific procedures; contact Broadcom support.

**DNS resolution failures**
The most common post-deployment problem. vCSA can't discover ESXi hosts if DNS isn't working:

```bash
# Inside vCenter appliance shell — check resolv.conf
cat /etc/resolv.conf

# Test resolution of an ESXi host
nslookup esxi01.yourdomain.local
```

If resolution fails, fix `/etc/resolv.conf` to point to your internal DNS servers. Also verify that your ESXi hosts' management IPs resolve in DNS — both forward and reverse.

**Certificate mismatch warnings in browser**
Expected with self-signed certs. For a test environment, accept the warning. For production: import your corporate CA certificate via **Administration** → **Certificate Management** to eliminate browser warnings across the team.

**Deployment fails at "Provisioning" stage**
Usually one of three causes:
- Insufficient datastore space (verify 20%+ free headroom before deploying)
- Browser-based antivirus blocking OVA extraction — temporarily disable during upload
- Wrong browser — use Chrome, Firefox, or Edge. IE is not supported.

**`vmware-cps` (Content Proxy Service) fails after first login**
This shows up as "Service Discovery Failed" when browsing inventory. Restart it:

```bash
systemctl restart vmware-cps
```

Also verify that port 443 is open between your management network clients and the vCenter management IP. A firewall rule blocking the vSphere Client → vCSA communication is a common oversight in locked-down environments.

## Greenfield vs Migration Decision

**Greenfield:** Deploy to your production datastore after staging validation is complete. Simple.

**Migration from vCSA 7:** Export your inventory via PowerCLI before touching anything, deploy the new instance in parallel, validate it, then migrate hosts to the new vCenter and decommission the old one. Never overwrite in-place.

```powershell
# Export inventory before migration — run against your current vCSA 7
Connect-VIServer -Server old-vcenter.yourdomain.local
Get-Cluster  | Export-Csv C:\temp\clusters_backup.csv  -NoTypeInformation
Get-VMHost   | Export-Csv C:\temp\hosts_backup.csv     -NoTypeInformation
Get-VM       | Export-Csv C:\temp\vms_backup.csv       -NoTypeInformation
Get-VDSwitch | Export-Csv C:\temp\vds_backup.csv       -NoTypeInformation
```

Keep this export until you've verified the new vCSA 8 is fully operational and all hosts are connected and healthy.

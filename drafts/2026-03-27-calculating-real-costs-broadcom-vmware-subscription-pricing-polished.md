---
title: "Calculating Real VMware Costs: Broadcom Subscription Pricing Breakdown"
slug: calculating-real-costs-broadcom-vmware-subscription-pricing
description: "Broadcom's per-core subscription model has hit VMware admins with 150–1,000% cost increases. Here's the actual VCF vs VVF pricing math, the 72-core minimum trap, late-renewal penalties, and PowerCLI scripts to audit your environment before renewal."
keywords: VMware licensing, Broadcom VMware pricing, VCF vs VVF cost, vSphere Foundation pricing 2026, VMware per-core licensing, VMware subscription cost
date: 2026-03-27
author: Rob Notaro
category: Licensing & Cost
tags: [broadcom, vmware, licensing, vSphere, VCF, VVF, cost, subscription, PowerCLI]
---

# Calculating Real VMware Costs: Broadcom Subscription Pricing Breakdown

Broadcom's acquisition of VMware didn't just change the vendor name — it rewired how VMware environments are priced. Community reports put the cost increases at **150% to over 1,000%** for many organizations. That's not hyperbole; I've seen quotes that bear it out.

This isn't a piece about whether the new model is fair. It's a practical guide: how Broadcom counts cores, what VCF versus VVF actually includes, where the hidden costs are, and how to run a PowerCLI audit before your renewal so you're not negotiating blind.

> **TL;DR:** VMware now costs roughly **$190–250 per core per year** depending on tier, with a **72-core minimum order**. A modest 5-host cluster with dual 16-core CPUs = 160 cores = **$30,400–40,000/year at list price**. Before Broadcom, that same cluster might have run $5,000–10,000/year on perpetual + SnS.

[SCREENSHOT: Side-by-side cost comparison table — pre-Broadcom perpetual vs. post-Broadcom subscription for a 5-host cluster]

## What Actually Changed: The End of Perpetual Licensing

On January 22, 2024, Broadcom [officially ended](https://blogs.vmware.com/cloud-foundation/2024/01/22/vmware-end-of-availability-of-perpetual-licensing-and-saas-services/) perpetual VMware licenses for all products. Here's the complete picture:

| Feature | Pre-Broadcom (≤2023) | Post-Broadcom (2024+) |
|---|---|---|
| License model | Perpetual + annual SnS | Subscription-only (annual or multi-year) |
| License metric | Per socket (1 license = 1 CPU, up to 32 cores) | Per core (16-core minimum per CPU, 72-core minimum order) |
| Product options | Modular — buy vSphere, vSAN, NSX separately | Bundled — VCF or VVF only |
| Essentials/Essentials Plus | Available for SMBs | Discontinued |
| Support | Optional, purchasable separately | Mandatory, bundled into subscription |
| Compliance enforcement | Trust-based, infrequent audits | Active telemetry monitoring, strict enforcement |
| Late renewal | No penalty | 20% surcharge on first-year subscription cost |

The elimination of Essentials and Essentials Plus is particularly brutal for small businesses. There's no budget on-ramp for VMware anymore.

## The Two Bundles: VCF vs VVF

Broadcom collapsed the entire VMware product catalog into two subscription offerings.

### VMware Cloud Foundation (VCF) — The Full Stack

VCF includes everything:

- vSphere (hypervisor + vCenter Standard)
- vSAN (1 TiB included per core)
- NSX (network virtualization, overlay networking)
- vSphere Kubernetes Service (VKS, formerly TKG)
- VCF Operations (formerly Aria Suite)
- VCF Operations for Networks

**List price:** ~$240–250 per core per year (community-verified Q1 2025 quotes; your negotiated rate will vary)

The trap: NSX adds real operational complexity. If your organization doesn't need software-defined networking today, you're still paying for it. VCF requires a minimum of 16 cores per physical CPU for counting, and carries the 72-core minimum order for new purchases.

**Minimum cluster requirement:** Broadcom's official VCF design requires a minimum of **7 physical nodes** (4 for management domain + 3 for workload domain) with vSAN storage.

### VMware vSphere Foundation (VVF) — The Lean Tier

VVF strips out NSX and Aria:

- vSphere (hypervisor + vCenter Standard)
- vSAN (0.25 TiB included per core)
- vSphere Kubernetes Service (single supervisor cluster only)
- **No NSX** — standard and distributed virtual switches only
- **No Aria/VCF Operations**

**List price:** ~$190–192 per core per year (community-verified)

VVF is cheaper per core, but the vSAN entitlement is tight. A dual-socket server with 32 total cores gets only ~8 TiB included. For most production workloads you'll hit that cap and need vSAN Capacity Add-On licenses — which erodes the cost advantage.

[SCREENSHOT: VVF vs VCF feature comparison matrix — checkmarks showing NSX and Aria gaps in VVF]

## The 72-Core Minimum: The Hidden Tax on Small Deployments

Effective April 10, 2025, **Broadcom mandates a minimum purchase of 72 cores per product per order**. Each physical CPU is counted at a minimum of 16 cores, even if the processor has fewer.

What this means:

- Single-socket server with 8 cores? You pay for **72 cores**
- 3-host cluster with single-socket 12-core CPUs (36 total cores)? You pay for **72 cores**
- 5-host cluster with dual-socket 16-core CPUs (160 total cores)? You pay for all **160 cores** — you exceed the minimum

**The math for a small shop:**
```
72 cores × $192/core/year (VVF list) = $13,824/year
```

Before Broadcom, a comparable small environment on vSphere Essentials might have cost $600–800/year in SnS renewals on a perpetual license bought years ago.

## Step 1: Audit Your Physical Core Count with PowerCLI

Before any conversation with Broadcom or a reseller, know your exact core count. Run this against your vCenter:

```powershell
Connect-VIServer -Server vcenter.yourdomain.local

# Per-host breakdown with Broadcom billable core count
Get-VMHost | Sort-Object Name | ForEach-Object {
    $hostView    = $_ | Get-View
    $cpuPackages = $hostView.Hardware.CpuInfo.NumCpuPackages  # Physical sockets
    $cpuCores    = $hostView.Hardware.CpuInfo.NumCpuCores     # Physical cores (total)
    $billable    = [math]::Max($cpuCores, $cpuPackages * 16)  # Broadcom 16-core minimum per CPU

    [PSCustomObject]@{
        Host           = $_.Name
        Sockets        = $cpuPackages
        PhysicalCores  = $cpuCores
        CoresPerSocket = [math]::Round($cpuCores / $cpuPackages)
        BillableCores  = $billable
    }
} | Format-Table -AutoSize
```

```powershell
# Total billable cores — your license floor
$totalBillable = Get-VMHost | ForEach-Object {
    $v       = $_ | Get-View
    $sockets = $v.Hardware.CpuInfo.NumCpuPackages
    $cores   = $v.Hardware.CpuInfo.NumCpuCores
    [math]::Max($cores, $sockets * 16)
} | Measure-Object -Sum

$licenseFloor = [math]::Max($totalBillable.Sum, 72)
Write-Host "Billable cores: $($totalBillable.Sum)"
Write-Host "Effective license minimum: $licenseFloor cores"
```

> ⚠️ Do NOT use `Get-CimInstance Win32_Processor` against ESXi hosts — ESXi is not Windows. Use `Get-View` with `Hardware.CpuInfo` as shown.

[SCREENSHOT: PowerCLI console output showing core audit results for a 3-host cluster]

## Step 2: Calculate vSAN Storage Requirements

If you use vSAN, calculate raw storage against the per-core entitlement. Use Broadcom's [official core/TiB calculator KB](https://knowledge.broadcom.com/external/article/313548/counting-cores-for-vmware-cloud-foundati.html) for precise numbers.

```powershell
# VVF: 0.25 TiB per core | VCF: 1 TiB per core
$vcfCoresLicensed = $licenseFloor
$vvfStorageIncl   = $vcfCoresLicensed * 0.25  # TiB included with VVF
$vcfStorageIncl   = $vcfCoresLicensed * 1.0   # TiB included with VCF

$vsanCapacityGB = Get-Datastore | Where-Object {$_.Type -eq "vsan"} |
    Select-Object -ExpandProperty CapacityGB
$vsanTiB = [math]::Round(($vsanCapacityGB / 1024), 2)

Write-Host "Raw vSAN capacity: $vsanTiB TiB"
Write-Host "VVF included storage: $vvfStorageIncl TiB"
Write-Host "VCF included storage: $vcfStorageIncl TiB"

if ($vsanTiB -gt $vvfStorageIncl) {
    $addOnNeeded = [math]::Ceiling($vsanTiB - $vvfStorageIncl)
    Write-Host "⚠️ VVF requires $addOnNeeded TiB in vSAN Capacity Add-On licenses"
}
```

## Step 3: Model 1-Year vs 3-Year Costs

Multi-year commitments typically yield 15–20% discount versus annual list price — but they lock you into current pricing and the current feature set.

```powershell
$coreCount   = $licenseFloor
$vcfPerCore  = 250    # $/core/year list — verify with your VAR
$vvfPerCore  = 192    # $/core/year list

$discount3yr = 0.17   # ~17% typical multi-year discount

@(
    [PSCustomObject]@{ Tier="VCF"; Term="1-year"; Total=[math]::Round($coreCount * $vcfPerCore) }
    [PSCustomObject]@{ Tier="VCF"; Term="3-year"; Total=[math]::Round($coreCount * $vcfPerCore * 3 * (1 - $discount3yr)) }
    [PSCustomObject]@{ Tier="VVF"; Term="1-year"; Total=[math]::Round($coreCount * $vvfPerCore) }
    [PSCustomObject]@{ Tier="VVF"; Term="3-year"; Total=[math]::Round($coreCount * $vvfPerCore * 3 * (1 - $discount3yr)) }
) | Format-Table -AutoSize
```

**5-host cluster, dual 16-core CPUs (160 billable cores):**

| Tier | Term | Annual Cost | 3-Year Total |
|---|---|---|---|
| VCF | 1-year | $40,000 | $120,000 |
| VCF | 3-year | ~$33,200/yr | ~$99,600 |
| VVF | 1-year | $30,720 | $92,160 |
| VVF | 3-year | ~$25,500/yr | ~$76,500 |

*List prices. Negotiated rates for larger deployments are typically 20–40% lower — engage your VAR.*

## The Late-Renewal Penalty Trap

Broadcom charges a **20% late-renewal surcharge** on the first-year subscription cost if you miss your anniversary date.

On a 160-core VCF deployment at $40,000/year, missing the renewal date costs you **$8,000 on top of the renewal fee**. This is a hard deadline.

Set calendar reminders at 90 days, 30 days, and 7 days before your anniversary. Confirm renewal dates in the [Broadcom Support Portal](https://support.broadcom.com). Designate a backup renewal owner.

## Troubleshooting Licensing Issues

### "License Mismatch" After Host Addition

Adding a host whose core count pushes you over your purchased total triggers a compliance warning in vCenter Health.

```powershell
# Check current license state per host
Get-VMHost | ForEach-Object {
    $v = $_ | Get-View
    [PSCustomObject]@{
        Host          = $_.Name
        State         = $_.ConnectionState
        LicenseKey    = $_.LicenseKey
        PhysicalCores = $v.Hardware.CpuInfo.NumCpuCores
    }
} | Format-Table -AutoSize
```

Purchase additional cores before adding the host. Don't add hosts with the intention of true-up later — Broadcom's telemetry reports near-real-time.

### vSAN Features Grayed Out

Either you've exceeded your included TiB entitlement, or you're on VVF trying to access a VCF-only feature (erasure coding, stretched cluster, dedup/compression require VCF):

```bash
# On the ESXi host — check vSAN status
esxcli vsan health cluster list

# Check storage policy compliance
esxcli storage vsan status get -s
```

Erasure coding specifically requires VCF. VVF doesn't include it at any tier.

### NSX Features Missing After Move to VVF

If you migrated from a VCF trial or legacy NSX-T deployment to VVF, NSX will be unlicensed. VVF does not include NSX. All NSX overlays and distributed firewall rules will cease functioning. Either upgrade to VCF (NSX included) or purchase NSX as a separate add-on.

## Hidden Costs Checklist

Before finalizing any Broadcom quote, verify these frequently-missed line items:

| Cost Item | Notes |
|---|---|
| vSAN Capacity Add-On | Required when raw storage exceeds per-core entitlement |
| NSX Advanced Add-Ons | Distributed Firewall, IDS/IPS are add-ons even within VCF |
| VCF Operations for Networks | Some versions require separate license |
| ARM/Non-x86 Infrastructure | Separate SKU — requires Broadcom conversation |
| Multi-site/stretched cluster | Additional vSAN licensing implications |
| Late-renewal penalty | 20% of first-year cost if anniversary date is missed |
| Hardware refresh true-up | Adding hosts mid-term requires immediate license amendment |

## Alternatives Worth Knowing

The community is actively evaluating alternatives. I'm not recommending a migration here — the cost and retraining investment is real, and most organizations will stay on VMware for 3–5 more years while they evaluate. But you should know what's being discussed:

- **Proxmox VE** — open-source, free tier, community-supported; enterprise support ~€1,500/year for 3 servers ([AFFILIATE: Proxmox enterprise subscription])
- **Microsoft Hyper-V / Azure Stack HCI** — viable for Windows-heavy shops
- **Nutanix AHV** — bundled with Nutanix licensing; significant migration lift required
- **OpenShift Virtualization** — Red Hat's KVM-based VM platform, Kubernetes-native

The 72-core minimum and late-renewal penalties make staying painful. A full migration is often more painful. Do the math for your specific environment before deciding.

## Before Your Next Renewal: Action Items

1. **Run the PowerCLI core audit** (Step 1 above) — know your exact billable core count before any conversation
2. **Check your renewal anniversary date** in the Broadcom Support Portal today
3. **Model VCF vs VVF** — involve your storage team on vSAN entitlement requirements
4. **Verify vSAN raw capacity** against included TiB to spot Add-On requirements early
5. **Set renewal reminders** — the 20% late fee is a calendar alert away from being avoidable
6. **Get VAR quotes, not just list prices** — negotiated rates can be 20–40% below list for larger deployments
7. **Evaluate VMUG Advantage** if you run a home lab or dev environment — $200/year for lab access to the full VMware suite

For hardware supporting your VMware environment, see our [home lab hardware guide](/how-to-build-a-vmware-home-lab-on-a-budget) for current picks on budget-friendly validated platforms. [AFFILIATE: Dell PowerEdge R650xs — VCF 9 HCL validated, dual Xeon Silver]

---

## Sources

- [Broadcom: End of Availability of Perpetual Licensing (Official Blog)](https://blogs.vmware.com/cloud-foundation/2024/01/22/vmware-end-of-availability-of-perpetual-licensing-and-saas-services/)
- [William Lam: Updated Core/TiB Calculator Scripts for VCF and VVF](https://williamlam.com/2024/02/updated-inventory-calculator-scripts-for-counting-cores-tibs-for-vmware-cloud-foundation-vcf-and-vmware-vsphere-foundation-vvf.html)
- [Broadcom KB 313548: Counting Cores for VMware Cloud Foundation](https://knowledge.broadcom.com/external/article/313548/counting-cores-for-vmware-cloud-foundati.html)
- [CRN: Broadcom VMware 72-Core Minimum and Late-Renewal Penalties](https://www.crn.com/news/data-center/2025/broadcom-vmware-ups-minimum-core-purchase-substantially-levies-late-renewal-penalties)
- [Redress Compliance: VMware Licensing Changes Explained](https://redresscompliance.com/broadcom-vmware-licensing-and-subscription-changes-explained/)
- [r/vmware: Latest List Price Discussion (2025)](https://www.reddit.com/r/vmware/comments/1jo8oa1/latest_list_price/)

*Last verified: March 2026. Broadcom pricing changes frequently — always confirm current rates with your reseller before budgeting.*

# VMware Licensing After the Broadcom Acquisition: What It Actually Costs You

Broadcom acquired VMware in November 2023 for $69 billion and immediately killed the per-socket licensing model. On January 22, 2024, perpetual VMware licenses ended. If you're still figuring out what this means for your environment and your budget, here's the unvarnished version.

## What Changed: Per Socket → Per Core

Under the old model, you licensed vSphere by CPU socket. A dual-socket server — two CPUs, whatever core count — required two socket licenses. Core count mattered less than socket count, which is why most shops didn't care whether they bought 16-core or 32-core CPUs.

That's gone. Broadcom's model charges per physical CPU core, across every host in your cluster.

| | Pre-Broadcom (≤2023) | Post-Broadcom (2024+) |
|---|---|---|
| License metric | Per socket (1 license = 1 CPU, up to 32 cores) | Per core (16-core minimum per CPU, 72-core minimum order) |
| License model | Perpetual + optional annual SnS | Subscription-only |
| Product options | Modular — buy vSphere, vSAN, NSX separately | Bundled — VCF or VVF only |
| SMB on-ramp | Essentials/Essentials Plus | Discontinued |
| Compliance monitoring | Infrequent audits, trust-based | Active telemetry, near-real-time |
| Late renewal | No penalty | 20% surcharge on first-year cost |

**The math on a typical server:** A dual-socket host with 16-core CPUs = 32 cores. At ~$192/core/year (VVF list price), that's $6,144 per year per host. Before Broadcom, that same host on a perpetual license might have cost $5,000-$10,000 total — once, not annually.

[SCREENSHOT: Side-by-side licensing cost comparison — pre-Broadcom perpetual cost vs. post-Broadcom per-core annual cost for a 5-host cluster]

## The Two Products: VCF and VVF

Broadcom replaced the entire VMware product catalog with two bundles.

**VMware Cloud Foundation (VCF)** — the full stack:
- vSphere + vCenter
- vSAN (1 TiB per core included)
- NSX (network virtualization)
- vSphere Kubernetes Service
- VCF Operations (formerly Aria Suite)

List price: ~$250/core/year (as of Q1 2025 — verify with your VAR)

**VMware vSphere Foundation (VVF)** — the lean tier:
- vSphere + vCenter
- vSAN (0.25 TiB per core included)
- vSphere Kubernetes Service (single supervisor only)
- No NSX, no Aria Operations

List price: ~$192/core/year

For most shops under 50 hosts without dedicated NSX networking staff: VVF. VCF's NSX component is powerful, but it requires real expertise to configure and maintain properly. Paying for it when you're not going to use it is expensive.

## Who This Hits Hardest

**Enterprises with expiring contracts:** If you're under a legacy VMware agreement, you're protected until renewal. But any expansion — adding hosts, adding cores — requires purchasing at new per-core pricing immediately. When your contract renews, expect a significant increase. Start the renewal negotiation 6-12 months early.

**SMBs:** Broadcom eliminated Essentials and Essentials Plus. There is no longer a budget VMware tier for small shops. The 72-core minimum order (more on this below) means even a 2-host environment pays for at least 72 cores whether they need them or not.

**Home lab operators and small dev environments:** The free ESXi hypervisor no longer comes with a standalone free license. You need a VMUG Advantage membership ($200/year) for legitimate lab use. This is actually a good deal — VMUG gives you lab access to the full VMware suite including vCenter, vSAN, and more.

## The 72-Core Minimum

Effective April 10, 2025, Broadcom requires a **minimum purchase of 72 cores per product per order**. Each physical CPU is counted at a minimum of 16 cores, even if the processor has fewer.

What this means for small environments:

```
72 cores × $192/core/year (VVF list) = $13,824/year minimum
```

A 3-host cluster with single-socket 12-core CPUs has 36 actual cores — but you pay for 72. Before Broadcom, a comparable environment on Essentials Plus perpetual might have cost under $800/year in renewal SnS.

## Audit Your Environment Before Renewal

Before any conversation with Broadcom or a reseller, know your exact core count. Run this against your vCenter:

```powershell
Connect-VIServer -Server vcenter.yourdomain.local

Get-VMHost | Sort-Object Name | ForEach-Object {
    $v           = $_ | Get-View
    $sockets     = $v.Hardware.CpuInfo.NumCpuPackages
    $totalCores  = $v.Hardware.CpuInfo.NumCpuCores
    $billable    = [math]::Max($totalCores, $sockets * 16)  # Broadcom 16-core minimum per CPU

    [PSCustomObject]@{
        Host           = $_.Name
        Sockets        = $sockets
        PhysicalCores  = $totalCores
        BillableCores  = $billable
    }
} | Format-Table -AutoSize
```

```powershell
# Total billable cores across your entire cluster
$total = Get-VMHost | ForEach-Object {
    $v = $_ | Get-View
    $s = $v.Hardware.CpuInfo.NumCpuPackages
    $c = $v.Hardware.CpuInfo.NumCpuCores
    [math]::Max($c, $s * 16)
} | Measure-Object -Sum

$licFloor = [math]::Max($total.Sum, 72)
Write-Host "Billable cores: $($total.Sum)  |  License floor (min 72): $licFloor"
```

> Do NOT use `Get-CimInstance Win32_Processor` for this — ESXi is not Windows. Use `Get-View` with `Hardware.CpuInfo` as shown.

[SCREENSHOT: PowerCLI output showing per-host core count audit with billable cores column]

## Fix Common Licensing Issues

**"Insufficient License" errors after adding a host:**
The license manager cache is stale, or your new host's cores pushed you over your purchased total.

```bash
# SSH into the ESXi host
esxcli system license list
esxcli system license set --key "YOUR_NEW_PER_CORE_KEY" --mode percpu
```

Also try via vSphere Client: host → **Monitoring** → **Licensing** → **Update Licenses** / **Resync**.

**Unexpected per-core invoice from your hardware vendor:**
Check the Sales Agreement line item explicitly for "Per Core" licensing. If you're an SMB, ask specifically for a quote referencing current "VMware Ready" bundle pricing — resellers sometimes still quote from outdated templates.

**Hyper-Threading and license count confusion:**
Broadcom counts physical cores. If your license covers logical cores (HT threads), you're paying for double the physical core count. Verify with your account manager whether your specific license key covers physical or logical cores. Misinterpreting this causes significant under-licensing.

## What I'd Do Before My Next Renewal

1. **Run the PowerCLI audit above** — know your exact billable core count before any conversation
2. **Check your renewal anniversary date** in the Broadcom Support Portal and set reminders at 90, 30, and 7 days out — the 20% late penalty is avoidable with a calendar alert
3. **Model VCF vs VVF costs** using the per-core numbers — if you don't use NSX today, VVF is almost certainly the right choice
4. **Get quotes from your VAR, not just Broadcom list prices** — negotiated rates for multi-year or larger deployments typically run 20-40% below list
5. **If you're under 72 billable cores**, evaluate whether a VMUG Advantage membership covers your needs (lab/dev/test environments) and whether the cost delta versus a full commercial subscription makes sense

The era of cheap, scalable perpetual VMware licensing is over. That's not going to change. The question now is how to get the most out of the subscription you're buying.

---
*Pricing verified against community reports as of March 2026. Confirm current rates with your Broadcom reseller before budgeting — list prices change. Broadcom KB on licensing: [knowledge.broadcom.com](https://knowledge.broadcom.com)*

<!-- Extracted from: calculating-real-costs-broadcom-vmware-subscription-pricing.html -->
<!-- Article: Calculating Real VMware Costs: A Complete Breakdown of Broadcom's Subscription Pricing -->
<!-- Sections: PowerCLI cost-modeling scripts (Steps 1-3) and Hidden Costs Checklist -->

## Step-by-Step: Calculating Your Real Cost

### Step 1: Audit Your Physical Core Count with PowerCLI

Before any conversation with Broadcom or a reseller, you need a precise core count. Use PowerCLI against your vCenter to generate an accurate inventory:

```powershell
# Connect to vCenter first
Connect-VIServer -Server vcenter.yourdomain.local

# Get physical CPU core count per host (this is what Broadcom counts)
Get-VMHost | Sort-Object Name | ForEach-Object {
    $hostView = $_ | Get-View
    $cpuPackages = $hostView.Hardware.CpuInfo.NumCpuPackages  # Physical sockets
    $cpuCores    = $hostView.Hardware.CpuInfo.NumCpuCores     # Physical cores (total)
    $coresPerCPU = [math]::Round($cpuCores / $cpuPackages)
    
    # Broadcom counts each CPU at minimum 16 cores
    $billableCores = [math]::Max($cpuCores, $cpuPackages * 16)
    
    [PSCustomObject]@{
        Host           = $_.Name
        Sockets        = $cpuPackages
        PhysicalCores  = $cpuCores
        CoresPerSocket = $coresPerCPU
        BillableCores  = $billableCores
    }
} | Format-Table -AutoSize
```

```powershell
# Get total billable cores across all hosts — your licensing floor
$totalBillable = Get-VMHost | ForEach-Object {
    $v = $_ | Get-View
    $sockets = $v.Hardware.CpuInfo.NumCpuPackages
    $cores   = $v.Hardware.CpuInfo.NumCpuCores
    [math]::Max($cores, $sockets * 16)
} | Measure-Object -Sum

$licenseFloor = [math]::Max($totalBillable.Sum, 72)
Write-Host "Total billable cores (Broadcom model): $($totalBillable.Sum)"
Write-Host "Effective license minimum: $licenseFloor cores"
```

> ⚠️ **Do NOT use `Get-CimInstance Win32_Processor` against ESXi hosts** — ESXi is not Windows and this query will fail or return garbage. Use `Get-View` with `Hardware.CpuInfo` as shown above.

### Step 2: Calculate vSAN Storage Requirements

If you're using vSAN, calculate your raw storage against the per-core entitlement. Use William Lam's [official Broadcom core/TiB calculator](https://knowledge.broadcom.com/external/article/313548/counting-cores-for-vmware-cloud-foundati.html) for precise numbers.

```powershell
# VVF gives 0.25 TiB per core; VCF gives 1 TiB per core
# Calculate whether you need vSAN Capacity Add-On licenses

$vcfCoresLicensed  = $licenseFloor  # from Step 1
$vvfStorageIncl    = $vcfCoresLicensed * 0.25  # TiB included with VVF
$vcfStorageIncl    = $vcfCoresLicensed * 1.0   # TiB included with VCF

# Get actual raw vSAN capacity in your cluster
$vsanCapacity = Get-Datastore | Where-Object {$_.Type -eq "vsan"} | 
    Select-Object -ExpandProperty CapacityGB
$vsanTiB = [math]::Round(($vsanCapacity / 1024), 2)

Write-Host "Raw vSAN capacity: $vsanTiB TiB"
Write-Host "VVF included storage: $vvfStorageIncl TiB"
Write-Host "VCF included storage: $vcfStorageIncl TiB"

if ($vsanTiB -gt $vvfStorageIncl) {
    $addOnNeeded = [math]::Ceiling($vsanTiB - $vvfStorageIncl)
    Write-Host "⚠️  VVF requires $addOnNeeded TiB in vSAN Capacity Add-On licenses"
}
```

### Step 3: Model 1-Year vs. 3-Year Costs

Multi-year commitments typically yield **15–20% discount** versus annual list price — but they lock you into current pricing and the current feature set. Model both scenarios:

```powershell
# Cost modeling: VCF vs VVF, 1yr vs 3yr
$coreCount     = $licenseFloor  # from Step 1
$vcfListYear   = 250            # $/core/year list price (verify with your VAR)
$vvfListYear   = 192            # $/core/year list price

$discount1yr   = 0.00   # no discount on annual
$discount3yr   = 0.17   # ~17% typical multi-year discount

$results = @(
    [PSCustomObject]@{ Tier="VCF"; Term="1-year"; CostPerCore=$vcfListYear; Total=[math]::Round($coreCount * $vcfListYear * (1 - $discount1yr)) }
    [PSCustomObject]@{ Tier="VCF"; Term="3-year"; CostPerCore=[math]::Round($vcfListYear*(1-$discount3yr),2); Total=[math]::Round($coreCount * $vcfListYear * 3 * (1 - $discount3yr)) }
    [PSCustomObject]@{ Tier="VVF"; Term="1-year"; CostPerCore=$vvfListYear; Total=[math]::Round($coreCount * $vvfListYear * (1 - $discount1yr)) }
    [PSCustomObject]@{ Tier="VVF"; Term="3-year"; CostPerCore=[math]::Round($vvfListYear*(1-$discount3yr),2); Total=[math]::Round($coreCount * $vvfListYear * 3 * (1 - $discount3yr)) }
)

$results | Format-Table -AutoSize
```

**Real-world example** for a 5-host cluster with dual 16-core CPUs (160 billable cores):

| Tier | Term | Annual Cost | 3-Year Total |
|---|---|---|---|
| VCF | 1-year | $40,000 | $120,000 |
| VCF | 3-year | ~$33,200/yr | ~$99,600 |
| VVF | 1-year | $30,720 | $92,160 |
| VVF | 3-year | ~$25,500/yr | ~$76,500 |

*List prices. Negotiated rates for large deployments are typically lower — engage your VAR or Broadcom directly.*

## Hidden Costs Checklist

Before finalizing any Broadcom quote, verify these frequently-missed line items:

| Cost Item | Notes |
|---|---|
| vSAN Capacity Add-On | Required when raw storage exceeds per-core entitlement |
| NSX Advanced Add-Ons | Distributed Firewall, IDS/IPS are add-ons even within VCF |
| VCF Operations for Networks | Some versions require separate license |
| ARM/Non-x86 Infrastructure | Separate SKU discussion with Broadcom required |
| Multi-site/stretched cluster | Additional vSAN licensing implications |
| Late-renewal penalty | 20% of first-year cost if you miss anniversary date |
| Hardware refresh true-up | Adding hosts mid-term requires immediate license amendment |

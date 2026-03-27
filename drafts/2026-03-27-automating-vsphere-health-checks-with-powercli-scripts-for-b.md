# Automating vSphere Health Checks with PowerCLI for Broadcom License Compliance

Broadcom's subscription model added a new compliance risk that didn't exist under perpetual licensing: Broadcom's telemetry monitors your environment in near-real time. If your core count drifts out of compliance — say you added a host mid-term without amending your subscription — you'll find out at renewal with penalties attached. Manual quarterly checks aren't good enough anymore. Here's a PowerCLI automation framework I use to keep health and licensing status continuously visible.

## Prerequisites

PowerCLI 13.x or later. Earlier versions are missing the cmdlets for Broadcom API endpoints and updated SSO auth flows.

```powershell
# Install or update PowerCLI
Install-Module VMware.PowerCLI -RequiredVersion 13.* -AllowClobber -Force
Import-Module VMware.PowerCLI

# Connect to vCenter
Connect-VIServer -Server vcenter.yourdomain.local -User administrator@vsphere.local -Password $cred
```

Your account needs `System.Management.User` privileges or higher — standard vCenter user accounts can manage VMs but typically can't query license entitlements via the API.

Before running anything, verify outbound connectivity to Broadcom's licensing endpoints:

```powershell
Test-NetConnection -ComputerName license.broadcom.com -Port 443
```

If this fails, coordinate with your security team. PowerCLI needs that connection to fetch entitlement data. Configure a proxy via `Set-PowerCLIConfiguration -ProxyUrl <url>` if required.

## Script Architecture

I split this into three functions so failures are isolated:

1. **Get-LicensingStatus** — queries the API for entitlement type and named user counts
2. **ValidateHealthMetrics** — checks ESXi version and patch levels against the supported matrix
3. **GenerateComplianceReport** — aggregates data, handles API errors gracefully, exports to CSV

The key design choice: if the license check times out due to network latency, I flag the host as "Unknown Status" rather than crashing the whole script. You want to catch genuine compliance gaps, not get blocked by transient network issues.

## Step 1: Inventory Discovery

```powershell
# Filter to production clusters only
$clusters = Get-Cluster | Where-Object { $_.Name -like "*Production*" }

foreach ($cluster in $clusters) {
    Write-Host "Processing: $($cluster.Name)"
}
```

## Step 2: Licensing Validation

In standard PowerCLI 13+, there's no single `Get-BroadcomLicenseStatus` cmdlet. You query `Get-VmHostLicense` and parse `EntitlementType` and `Status`. For BYOK, verify the key via the `Key` property.

```powershell
$hosts = Get-VMHost
$reportData = @()

foreach ($vmHost in $hosts) {
    try {
        $licenses = Get-VmHostLicense -VmHost $vmHost

        if (-not $licenses) {
            throw "No licenses found on host: $($vmHost.Name)"
        }

        $currentEntitlement = $licenses | Where-Object { $_.EntitlementType -like "*Broadcom*" }

        $status    = "N/A"
        $licType   = "Unknown"
        $userCount = 0
        $maxUsers  = 0

        if ($currentEntitlement) {
            $licType = $currentEntitlement.EntitlementType.Split("-")[0]

            if ($currentEntitlement.Status -eq "Revoked" -or $currentEntitlement.Status -eq "Invalid") {
                $status = "Critical: License Revoked"
            }
            elseif ($currentEntitlement.Status -eq "Active") {
                if ($licType -eq "Subscription") {
                    $userCount = [int]$currentEntitlement.SubscriptionUserCount
                    $maxUsers  = [int]$currentEntitlement.MaxSubscribedUsers
                    $status    = if ($userCount -le $maxUsers) { "Compliant" } else { "Critical: Over Limit" }
                }
                else {
                    $status = "Compliant (BYOK)"
                }
            }
            else {
                $status = "Warning: Entitlement Status Unclear"
            }
        }
        else {
            $status = if ($licenses.EntitlementType -like "*Perpetual*" -or 
                          $licenses.EntitlementType -like "*VMware License*") {
                "Critical: Deprecated License Detected"
            }
            else { "Unknown Status (No Entitlement)" }
        }
    }
    catch {
        Write-Warning "Failed to process $($vmHost.Name): $_"
        $status    = "Error: API Timeout or Access Denied"
        $licType   = "N/A"
        $userCount = 0
        $maxUsers  = 0
    }

    $reportData += [PSCustomObject]@{
        HostName      = $vmHost.Name
        LicenseType   = $licType
        UserCount     = $userCount
        MaxUsers      = $maxUsers
        HealthStatus  = $status
        LastCheckTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}
```

## Step 3: Export and Alert

```powershell
# Skip hosts in maintenance mode
$reportData = $reportData | Where-Object { $_.HostName -notmatch "Maintenance" }

# Export with timestamp
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportData | Export-Csv -Path "C:\Logs\vSphere_License_Audit_$ts.csv" -NoTypeInformation

# Console summary for critical issues
$criticalCount = ($reportData | Where-Object { $_.HealthStatus -like "*Critical*" }).Count
if ($criticalCount -gt 0) {
    Write-Host "CRITICAL: $criticalCount hosts require immediate attention." -ForegroundColor Red
}
else {
    Write-Host "No critical violations detected." -ForegroundColor Green
}
```

[SCREENSHOT: PowerCLI console output showing compliance report with host names, license types, and status column — one row highlighted red for a deprecated license]

## Scheduling and Alerting

Run this on a schedule — Windows Task Scheduler or a cron job on a Linux jump host. I run it hourly during business hours and daily overnight.

Alert only on "Critical" and "Unknown" statuses. If you alert on everything (warnings, patch notices, etc.), the team will start ignoring the alerts, and you'll miss a real license revocation.

```powershell
$criticalHosts = $reportData | Where-Object { 
    $_.HealthStatus -like "*Critical*" -or 
    $_.HealthStatus -like "*Unknown*" 
}

if ($criticalHosts.Count -gt 0) {
    $alertBody = "CRITICAL: License compliance issues detected.`n`nHosts:`n" + 
                 ($criticalHosts | Select-Object -ExpandProperty HostName | Join-String -Separator "`n")

    # Use your preferred notification method
    # Send-MailMessage, Teams webhook, PagerDuty, etc.
    Send-MailMessage -To "ops@yourdomain.com" -Subject "vSphere License Compliance Alert" -Body $alertBody
}
```

## Troubleshooting

**"Get-VmHostLicense is not recognized"** — you're on an older PowerCLI version. Run `Get-Module VMware.PowerCLI` to check. Update to 13.x.

**API timeouts / "Cannot connect to license server"** — vCenter needs outbound 443 to `license.broadcom.com`. Check your firewall rules. If you're behind a corporate proxy, set it via `Set-PowerCLIConfiguration`.

**"Insufficient privileges"** — your service account needs `System.Management.User` or a custom role with "Read license" on the SSO domain. Standard VM admin roles won't cut it for license queries.

**CSV opens with merged columns in Excel** — always use `-NoTypeInformation` in `Export-Csv`. If it's still garbled, the issue is file encoding. Export to UTF-8 explicitly:

```powershell
$reportData | Export-Csv -Path "audit.csv" -NoTypeInformation -Encoding UTF8
```

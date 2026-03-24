# vSphere 8 Health Check Automation with PowerCLI

**Meta Description:** Automating vSphere 8 health checks with PowerCLI: connecting to vCenter, querying the Health Check service, parsing output into JSON and CSV reports, and sending email alerts on critical findings.

---

## Why Automate Health Checks

The vSphere Client Health tab shows cluster status at a glance, but it requires someone to log in and look at it. If no one checks for three days, a warning that appeared on Monday becomes a critical failure by Thursday.

Automated health checks solve two problems: they run on a schedule without human intervention, and they produce logs you can review after the fact to identify trends. A host that intermittently reports storage latency warnings over two weeks is telling you something different than one that shows a single transient alert.

### What vSphere 8 Changed

vSphere 8 expanded the Health Check service beyond the binary green/yellow/red model of earlier versions. The current service returns structured data — check names, severity levels, timestamps, and descriptive messages — that can be parsed programmatically. This makes it possible to feed health check results directly into monitoring systems, ticketing queues, or email alerts without screen-scraping the GUI.

### What This Post Covers

1.  Connecting to vSphere 8 via PowerCLI with proper credential handling.
2.  Running health checks and filtering results by category.
3.  Exporting results to JSON and CSV.
4.  Sending email alerts when critical issues are detected.

---

## Prerequisites

### Environment

*   A running **vSphere 8** environment (VCSA or Windows-based vCenter).
*   A management workstation running PowerShell 7+ (recommended over Windows PowerShell 5.1 for .NET compatibility).

### Installing PowerCLI

```powershell
# Install the latest version of PowerCLI from the PSGallery
Install-Module -Name VMware.PowerCLI -Force -AllowClobber

# Verify installation
Get-Module -ListAvailable VMware.PowerCLI
```

To update an existing installation:

```powershell
Update-Module VMware.PowerCLI
```

### Permissions

The account running health checks needs these vCenter permissions:
*   **Global > System View** — required to access system-wide health data.
*   **Health Check Service** — permission to execute and read health check results.
*   **Read Access** — on the host and cluster objects you are querying.

Create a dedicated service account (e.g., `svc_healthcheck@vsphere.local`) with only these permissions. Using a full administrator account for an automated script that only needs read access widens the impact if the credentials are compromised.

---

## Connecting to vCenter

### Interactive Session

```powershell
# Define variables for security
$vCenterFQDN = "vcenter.example.com"
$AdminUser = "administrator@vsphere.local"
$AdminPass = Read-Host -AsSecureString -Prompt "Enter password for $AdminUser"

# Connect to vCenter
Connect-VIServer -Server $vCenterFQDN -User $AdminUser -Password $AdminPass
```

### Unattended Scripts (Scheduled Tasks)

For scripts running on a schedule without human input, use a `PSCredential` object:

```powershell
$SecurePass = ConvertTo-SecureString "YourSecurePassword" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential("administrator@vsphere.local", $SecurePass)

Connect-VIServer -Server "vcenter.example.com" -Credential $Cred
```

Hardcoding a password in a script file is a security liability. For production use, retrieve credentials at runtime from a secrets manager — HashiCorp Vault, Azure Key Vault, or Windows Credential Manager. The `ConvertTo-SecureString` approach shown above is adequate for lab environments but should not be used where the script file might be accessible to other users.

[SCREENSHOT: PowerShell terminal showing a successful Connect-VIServer output with connection details]

---

## Running Health Checks

The `Get-HealthCheck` cmdlet queries the vSphere 8 Health Check service and returns structured objects.

### Cluster-Level Health Overview

```powershell
# Get the target cluster object
$Cluster = Get-Cluster -Name "DC1-Production"

# Retrieve all health checks for the cluster
$HealthResults = Get-HealthCheck -Entity $Cluster

# Display the status and details
$HealthResults | Select-Object Name, Status, Message, Time | Format-Table -AutoSize
```

The output includes:
*   **Name:** The identifier of the health check (e.g., "Network Connectivity", "Storage Latency", "VMware HA").
*   **Status:** OK, Warning, Critical, or Unknown.
*   **Message:** Description of the finding.
*   **Time:** When the check last ran.

### Filtering by Category

If you only care about storage health, filter the results:

```powershell
# Filter for Storage-related health checks only
$StorageHealth = Get-HealthCheck -Entity $Cluster | Where-Object { $_.Name -like "*Storage*" }

if ($StorageHealth.Status -ne "OK") {
    Write-Host "Critical Storage Issues Detected!" -ForegroundColor Red
    $StorageHealth | Select-Object Name, Status, Message
} else {
    Write-Host "All storage checks passed." -ForegroundColor Green
}
```

[SCREENSHOT: Output of Get-HealthCheck showing a mix of OK and Warning statuses for a cluster]

Note that the `-ne "OK"` comparison works correctly only if `$StorageHealth` contains a single object. If there are multiple storage checks, compare each one individually inside a `foreach` loop, or use `Where-Object { $_.Status -ne "OK" }` to filter to non-OK results.

---

## Generating Reports

Terminal output is useful for interactive troubleshooting. For ongoing monitoring, export the data to files that can be ingested by other systems.

### JSON Report

JSON works well for feeding data into monitoring dashboards (Grafana, Splunk) or ticketing APIs (ServiceNow).

```powershell
# Define output path
$OutputDir = "C:\Reports\vSphere8_Health"
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ReportFile = Join-Path $OutputDir "HealthCheck_$Timestamp.json"

# Gather data from all clusters
$ClusterList = Get-Cluster
$AllHealthData = @()

foreach ($Cluster in $ClusterList) {
    $Checks = Get-HealthCheck -Entity $Cluster | Select-Object Name, Status, Message, Time

    foreach ($Check in $Checks) {
        $AllHealthData += [PSCustomObject]@{
            ClusterName = $Cluster.Name
            CheckName   = $Check.Name
            Status      = $Check.Status
            Message     = $Check.Message
            Timestamp   = $Check.Time
        }
    }
}

# Export to JSON
$AllHealthData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReportFile

Write-Host "Report generated at: $ReportFile" -ForegroundColor Green
```

### CSV Report (Issues Only)

For spreadsheet review, export only the checks that returned Warning or Critical status:

```powershell
$CsvFile = Join-Path $OutputDir "HealthCheck_Issues_$Timestamp.csv"

# Filter for non-OK statuses
$IssuesOnly = $AllHealthData | Where-Object { $_.Status -ne "OK" }

if ($IssuesOnly) {
    $IssuesOnly | Export-Csv -Path $CsvFile -NoTypeInformation -Encoding UTF8
    Write-Host "Found $($IssuesOnly.Count) issues. Report saved to: $CsvFile" -ForegroundColor Yellow
} else {
    # Create an empty file if no issues found, so the script doesn't fail
    "" | Export-Csv -Path $CsvFile -NoTypeInformation -Encoding UTF8
    Write-Host "All systems healthy. Empty report generated." -ForegroundColor Green
}
```

### Email Alerts on Critical Findings

Extend the script to send an email when critical issues are found:

```powershell
if ($IssuesOnly.Status -eq "Critical") {
    $SmtpServer = "smtp.example.com"
    $SmtpPort = 587
    $Subject = "CRITICAL vSphere 8 Health Alert - $vCenterFQDN"
    $Body = $IssuesOnly | ConvertTo-Html -Fragment

    Send-MailMessage -From "ops@example.com" -To "admin-team@example.com" -Subject $Subject -Body $Body -SmtpServer $SmtpServer -UseSsl -Credential $Cred
}
```

[SCREENSHOT: Example of a generated HTML email report showing critical health issues]

Note: `Send-MailMessage` is marked as obsolete in PowerShell 7. Microsoft recommends using the `MailKit` library or a third-party module instead. The cmdlet still works but may be removed in a future PowerShell release.

---

## Troubleshooting the Script Itself

### Connection Timeouts

`Connect-VIServer` may time out on large environments or congested networks. Increase the timeout:

```powershell
Connect-VIServer -Server $vCenterFQDN -Credential $Cred -Timeout 60
```

Also verify that the management workstation can resolve the vCenter FQDN via DNS and that port 443 is reachable. A firewall rule change or VPN disconnect can break what worked yesterday.

### Permission Denied on Health Check Queries

If `Get-HealthCheck` returns "Insufficient privilege," the service account is missing the **System View** global permission. Use `Get-VIPermission` to audit what is currently assigned:

```powershell
Get-VIPermission -Entity (Get-Folder -NoRecursion) | Where-Object { $_.Principal -like "*svc_healthcheck*" }
```

### JSON Export Truncation

`ConvertTo-Json` defaults to a depth of 2, which flattens nested objects. vSphere 8 health check output can be deeply nested. Set `-Depth 10` or higher:

```powershell
$AllHealthData | ConvertTo-Json -Depth 15
```

If the output still looks wrong, pipe a single health check object to `ConvertTo-Json -Depth 20` and examine the structure to find how deep the nesting goes.

### PowerShell Version Incompatibilities

The VMware.PowerCLI module targets PowerShell 7+ for full feature support. Running on Windows PowerShell 5.1 works for most cmdlets but may produce errors with newer health check features that depend on .NET 6+ APIs. If you encounter unexplained errors on 5.1, test the same script on PowerShell 7 before investigating further.

---

## Scheduling and Next Steps

With the script working interactively, the next step is scheduling it. On Windows, use Task Scheduler to run the `.ps1` file at whatever interval makes sense for your environment — every 15 minutes during business hours, hourly overnight, or whatever matches your SLA requirements. On Linux, use cron.

Beyond scheduling, consider:

*   **Feeding JSON output into Grafana or Splunk** for dashboards that show health trends over days and weeks, not just the current snapshot.
*   **Correlating health check timestamps with vCenter events** using `Get-VIEvent` to link warnings to specific changes — a DRS migration, a host entering maintenance mode, a storage path failover.
*   **Alerting thresholds:** The current script alerts on any Critical status. You may want to also alert on Warning statuses that persist across multiple consecutive checks, which indicates a condition that is not self-resolving.
<meta name="description" content="How to install VMware PowerCLI via PowerShell Gallery, connect to vCenter or a standalone ESXi host, and run your first automation commands. Covers prerequisites, certificate issues, and credential handling.">

# Setting Up VMware PowerCLI: Installation and First Commands

## What PowerCLI Does

VMware PowerCLI is a PowerShell module that exposes the vSphere API as cmdlets. Anything you can do in the vSphere Client — provisioning VMs, changing configurations, pulling reports — you can script with PowerCLI. The value is repeatability: a script runs the same way every time, which manual clicking does not.

PowerCLI works with vCenter Server (for managing an entire cluster) and with standalone ESXi hosts directly.

### What This Post Covers

1.  Checking that your workstation meets the prerequisites.
2.  Installing the VMware.PowerCLI module from PowerShell Gallery.
3.  Connecting to vCenter or an ESXi host.
4.  Running a few commands to confirm the connection works and to retrieve VM data.

---

## Prerequisites

### System Requirements

PowerCLI runs on Windows, Linux, and macOS, but the Windows experience has the fewest rough edges.

*   **Operating System:** Windows 10, Windows 11, or Windows Server (2016/2019/2022).
*   **PowerShell Version:** 5.1 (ships with Windows) or PowerShell 7+ for the latest module features and cross-platform support.
*   **.NET Framework:** Windows ships with .NET Framework 4.x, which PowerCLI requires. If you are on PowerShell 7, .NET is bundled.

### Permissions

PowerCLI authenticates against the vSphere API using your vSphere credentials. You need:

1.  **A vSphere user account** with appropriate privileges. For learning and initial testing, an Administrator account works. For scripted tasks that run unattended, create a dedicated service account with only the permissions the script needs — `Virtual machine.inventory.Read` and `Virtual machine.Provisioning` for VM management, for example.
2.  **Network access** to the vCenter Server or ESXi host on TCP port 443. If your workstation is behind a firewall, confirm this port is open.

### Verify Your PowerShell Version

Older PowerShell versions (before 5.1) do not support `Install-Module`. Check your version:

```powershell
$PSVersionTable
```

[SCREENSHOT: Output of $PSVersionTable showing PSVersion 5.1 or higher]

If the version is below 5.1, upgrade to PowerShell 7 from the [PowerShell GitHub releases page](https://github.com/PowerShell/PowerShell/releases). PowerShell 7 installs alongside Windows PowerShell 5.1 — it does not replace it.

---

## Installation

Two installation methods exist: online via PowerShell Gallery (the standard approach) and offline via MSI installer (for air-gapped environments).

### Method A: PowerShell Gallery (Online)

Open PowerShell as Administrator (right-click > "Run as Administrator") and run:

```powershell
Install-Module -Name VMware.PowerCLI -Scope CurrentUser -AllowClobber -Force
```

Parameter notes:
*   `-Scope CurrentUser` installs the module under your user profile only. Change to `-Scope AllUsers` if you want it available system-wide (requires admin rights).
*   `-AllowClobber` permits the install even if some cmdlet names overlap with other installed modules.
*   `-Force` suppresses confirmation prompts.

If PowerShell asks whether you trust the `PSGallery` repository, type **Y** and press Enter. This is a one-time prompt.

[SCREENSHOT: PowerShell prompt displaying the 'Do you want to run this script?' confirmation dialog]

Verify the installation:

```powershell
Get-Module -ListAvailable VMware.PowerCLI
```

You should see `VMware.PowerCLI` listed with a version number. If it appears, the install succeeded.

[SCREENSHOT: Output of Get-Module showing the VMware.PowerCLI module details]

### Method B: MSI Installer (Offline/Air-Gapped)

For workstations without internet access:

1.  Download the MSI installer from the [VMware PowerCLI Downloads page](https://developer.vmware.com/web/tool/7509/powercli) on a machine that does have internet access.
2.  Transfer the `.msi` file to the target workstation.
3.  Run the installer. It handles .NET dependencies and PowerShell snap-in registration.
4.  Open a new PowerShell window and run `Import-Module VMware.PowerCLI` to confirm it loads.

---

## Connecting to vCenter or ESXi

### Interactive Connection

The `Connect-VIServer` cmdlet establishes a session. For an interactive prompt where you type your password:

```powershell
Connect-VIServer -Server vcenter.yourdomain.com -User administrator@vsphere.local
```

PowerShell will prompt for the password. On success, it displays the server name, API version, and session timestamp.

[SCREENSHOT: Console output showing successful Connect-VIServer connection]

To connect to a standalone ESXi host instead, replace the `-Server` value with the host's IP or FQDN.

### Credential Object (for Scripts)

For scripts that should not prompt for input, create a credential object first:

```powershell
# Create a credential object for the user
$Credential = Get-Credential -UserName "administrator@vsphere.local" -Message "Please enter your vCenter password"

# Connect using the stored credential
Connect-VIServer -Server vcenter.yourdomain.com -Credential $Credential
```

This still prompts once when you run the script interactively but can be combined with stored credentials (Windows Credential Manager, HashiCorp Vault, etc.) for fully unattended execution.

### Verifying and Closing the Connection

Confirm your session is active:

```powershell
Get-VIServer
```

This returns a table with Server, Port, and Version columns. If it returns nothing, the connection failed silently — re-run `Connect-VIServer` and check for error output.

When finished, close the session:

```powershell
Disconnect-VIServer -Server vcenter.yourdomain.com -Confirm:$false
```

---

## First Commands

With a connection established, here are some commands to confirm everything works and to start pulling useful data.

### List All VMs

```powershell
Get-VM | Select-Object Name, PowerState, NumCPU, MemoryGB | Format-Table
```

This retrieves every VM visible to your account, selects four properties, and formats the output as a table.

[SCREENSHOT: Table output showing VM names and their power states]

### Filter: Find Powered-Off VMs

```powershell
Get-VM | Where-Object {$_.PowerState -eq "PoweredOff"} | Select-Object Name, GuestOS
```

The pipeline passes output from `Get-VM` through `Where-Object` for filtering, then to `Select-Object` to choose which properties to display.

### Export VM Inventory to CSV

```powershell
Get-VM | Select-Object Name, NumCPU, MemoryGB, Host | Export-Csv -Path "C:\Scripts\VM_Inventory.csv" -NoTypeInformation
```

Open the resulting file in Excel or any text editor. This is useful for audits, capacity planning, or feeding into licensing calculations under the new Broadcom vCPU-based model.

[SCREENSHOT: Notepad or Excel window opening the generated VM_Inventory.csv file]

---

## Troubleshooting Installation and Connection Issues

### "The term 'Connect-VIServer' is not recognized"

The module is installed but not loaded in the current session. Run `Import-Module VMware.PowerCLI` or close and reopen PowerShell. PowerShell auto-imports modules on first cmdlet use in most configurations, but this can fail if the module path is not in `$env:PSModulePath`.

### "Certificate Validation Failed"

Your vCenter uses a self-signed certificate that PowerShell does not trust. Two options:

**For testing only** — disable certificate validation for the session:
```powershell
[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
Connect-VIServer -Server vcenter.yourdomain.com -User admin@vsphere.local
```

**For anything beyond testing** — import the vCenter's CA certificate into your workstation's Trusted Root Certification Authorities store. This is the correct fix. Disabling validation means your script cannot detect a man-in-the-middle attack on the connection.

### "Access Denied" or Permissions Errors

The account you connected with lacks the required vSphere permissions. Check the role assignment in vCenter under **Administration > Access Control > Roles**. For read-only operations like `Get-VM`, the account needs at least `Read` permissions on the relevant inventory objects. For provisioning, it needs `Virtual machine.Provisioning` rights.

### Module Version Conflicts

If you have an older PowerCLI version installed alongside a newer one, cmdlet loading can fail with ambiguous errors. Remove old versions first:

```powershell
Uninstall-Module -Name VMware.PowerCLI -AllVersions
```

Then reinstall the latest version from PowerShell Gallery.

---

## Where to Go From Here

PowerCLI is installed, connected, and returning data. From here, the useful directions are:

*   **Pipeline chaining:** Combine cmdlets to build workflows — `Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"} | Start-VM` is the pattern. Each cmdlet passes objects to the next.
*   **Writing .ps1 scripts:** Move from interactive commands to saved scripts that can be scheduled via Task Scheduler or cron.
*   **Advanced cmdlets:** `New-VM`, `Set-VM`, `New-VirtualSwitch`, `Get-VMHost` — the module includes hundreds of cmdlets covering networking, storage, HA, and more. Run `Get-Command -Module VMware.PowerCLI` to see the full list.
*   **CI/CD integration:** PowerCLI scripts run in Jenkins, Azure DevOps, and GitHub Actions pipelines. This enables infrastructure provisioning as part of an automated deployment pipeline.
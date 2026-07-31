# Invoke-KeyVaultCertRenewal.ps1

Automates renewing an IIS-bound TLS certificate from Azure Key Vault on a Windows VM, using the VM's managed identity.

## What it does

1. **Ensuring log rotation** - creates `C:\ProgramData\KeyVaultCertRenewal`, archives the previous day's log by date, and prunes archives older than 30 days.
2. **Checking Azure CLI** - installs the Azure CLI (via the official MSI) if it isn't already present, then refreshes `PATH` from the registry.
3. **Detecting web server** - confirms IIS (`W3SVC`) is installed and loads the `WebAdministration` module.
4. **Collecting server names** - parses host names from IIS `https` site bindings.
5. **Authenticating to Azure** - logs in with `az login --identity`, using `$AzureClientId` if set (user-assigned identity).
6. **Locating Key Vault** - finds the single Key Vault accessible to the managed identity (or uses the `$KeyVaultName` override).
7. **Matching certificate** - finds the certificate in the vault whose Subject Alternative Names cover one of the detected server names.
8. **Checking certificate status** - compares the vault certificate's thumbprint against the locally installed certificate (public cert/metadata only - no secret access, no local changes) and exits early if they already match.
9. **Downloading certificate** - if the thumbprints differ, downloads the certificate as a PFX-encoded secret.
10. **Installing certificate** - imports the PFX into `Cert:\LocalMachine\My` and removes the old certificate.
11. **Updating IIS bindings and reloading** - rebinds each matching `https` binding to the new certificate via `netsh http` and runs `iisreset /noforce`.

## Requirements

- Windows Server with IIS installed (`W3SVC` service, `WebAdministration` module).
- A managed identity (system- or user-assigned) with `get`/`list` access to the target Key Vault's certificates and secrets.
- Must be run as **Administrator** (`#Requires -RunAsAdministrator`) - writes to the certificate store, updates IIS SSL bindings, and restarts IIS.
- PowerShell 5.1 or later (Windows PowerShell or PowerShell 7+).

## Manual overrides

Set these at the top of the script to skip auto-detection:

| Variable         | Purpose                                                                                 |
|------------------|------------------------------------------------------------------------------------------|
| `$KeyVaultName`  | Use a specific Key Vault instead of auto-discovering the single accessible vault.         |
| `$AzureClientId` | Client ID of a user-assigned managed identity to log in with, instead of the system-assigned identity. |

## Usage

```powershell
.\Invoke-KeyVaultCertRenewal.ps1
```

Exits `0` and prints "already up to date, nothing to do" if the installed certificate's thumbprint already matches the vault; otherwise downloads, installs, and rebinds.

## Running on a schedule (Task Scheduler)

Register a daily task running as `SYSTEM` (so it can use the VM's system-assigned managed identity):

```powershell
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Invoke-KeyVaultCertRenewal.ps1"'
$trigger = New-ScheduledTaskTrigger -Daily -At 00:00
Register-ScheduledTask -TaskName 'KeyVaultCertRenewal' -Action $action -Trigger $trigger -RunLevel Highest -User 'SYSTEM'
```

### Testing the scheduled task without waiting

```powershell
Start-ScheduledTask -TaskName 'KeyVaultCertRenewal'
Get-ScheduledTaskInfo -TaskName 'KeyVaultCertRenewal'
Get-Content C:\ProgramData\KeyVaultCertRenewal\keyvault-cert-renewal.log -Tail 50
```

## Log rotation

The script archives `keyvault-cert-renewal.log` to a date-stamped file whenever the log's last write date differs from today, and deletes archives older than 30 days - both on every run, so no separate scheduled task is required.

## Troubleshooting

- Every log line is timestamped, e.g. `[ 2026-07-31 - 16:25:37 ]`, to make it clear when each step ran.
- All `az` CLI calls run through an `Invoke-Az` helper that merges stdout/stderr and checks `$LASTEXITCODE` explicitly, so failures surface as a clear `Fail` message with the CLI's actual output instead of a PowerShell stack trace.
- If "Collecting server names" fails, add a host name to an `https` site binding in IIS Manager (or via `New-WebBinding`) and re-run.
- If "Authenticating to Azure" fails, confirm the VM has a managed identity enabled and that it has been granted `get`/`list` access to the target Key Vault.

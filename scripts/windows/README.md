# Invoke-KeyVaultCertRenewal.ps1

Renews IIS TLS certificates from Azure Key Vault using the VM's managed identity. Handles multiple sites on one host, updates the bindings, and never writes the PFX to disk in the clear. Supports both the machine certificate store and the IIS Central Certificate Store.

## What it does

1. **Ensuring log rotation** - creates `C:\ProgramData\KeyVaultCertRenewal`, restricts it to SYSTEM and Administrators, archives the previous day's log, and prunes archives older than 30 days.
2. **Checking Azure CLI** - installs the Azure CLI MSI if absent, verifying its Authenticode signature before executing it.
3. **Authenticating to Azure** - `az login --identity`, using the user-assigned identity when one is supplied.
4. **Detecting web server** - confirms `W3SVC` is present, loads the `WebAdministration` module, and detects whether the Central Certificate Store is enabled.
5. **Collecting server names** - reads every site binding's host header, http and https alike.
6. **Locating Key Vault** - uses `-KeyVaultName`, or the single vault the identity can see.
7. **Matching certificates** - looks up one certificate per host name by name convention (see below).
8. **Checking certificate status** - compares each vault thumbprint against what is installed and against the live binding.
9. **Downloading certificates** - reads the PFX secret into memory only.
10. **Installing certificates** - imports into `LocalMachine\My` (intermediates into `LocalMachine\CA`), or writes `<hostname>.pfx` to the Central Certificate Store share.
11. **Applying IIS bindings** - updates or creates the https binding, then reads it back to verify.
12. **Reloading IIS** - only when asked; binding changes are live immediately.

## Certificate naming

Key Vault names cannot contain dots, so each host name maps to a certificate by replacing them with dashes:

```
iis-site-one.az.builtwithcaffeine.cloud  ->  iis-site-one-az-builtwithcaffeine-cloud
```

The script fetches that certificate by name rather than enumerating the vault, so the identity needs only **get** on certificates and secrets - not `list`. A host name with no matching certificate is reported and skipped; the remaining sites still process.

## The PFX never touches disk in the clear

The Key Vault secret is base64-decoded to a byte array and passed straight to `X509Certificate2Collection.Import()`. Key storage flags are `MachineKeySet | PersistKeySet` so IIS can use the key and it survives the process, but **not** `Exportable` - the key is usable, never extractable. The byte array is zeroed immediately after import.

Under Central Certificate Store the certificate has to become a file, so it is re-encrypted in memory under the CCS password using `EphemeralKeySet` - the private key never enters a machine key container - and written via a temp name that is then moved into place, so IIS never reads a half-written file.

## Central Certificate Store

CCS is detected automatically via `Get-WebCentralCertProvider`. When enabled, the model changes: certificates are files named `<hostname>.pfx` on the store share, and bindings carry no thumbprint at all - they simply set `sslFlags` bit 2 and IIS resolves the certificate by host header at request time.

Because every PFX in the share must be encrypted with the provider's private key password, and Windows will not hand that password back once configured, you have to supply it:

```powershell
$ccsPassword = Read-Host -AsSecureString 'CCS private key password'
.\Invoke-KeyVaultCertRenewal.ps1 -CentralCertStorePassword $ccsPassword
```

The script refuses to run rather than guess if CCS is enabled and no password is given. Differences in CCS mode:

| | Store mode | CCS mode |
| --- | --- | --- |
| Certificate lives in | `LocalMachine\My` | `<share>\<hostname>.pfx` |
| Staleness check | Store thumbprint + binding thumbprint | File thumbprint + binding `sslFlags` |
| Binding change | `AddSslCertificate` | `sslFlags` set to SNI + CCS |
| New bindings created with | `sslFlags 1` | `sslFlags 3` |
| Verification | Binding `certificateHash` read back | File thumbprint *and* CCS flag read back |
| Backup | `applicationHost.config` | `applicationHost.config` + the previous `.pfx` |

CCS backups of `.pfx` files are deleted as soon as the run succeeds - they are private keys, and unlike a config file there is no reason to keep them for a month.

For a scheduled run, either pass the password in the task's `<Arguments>` (it will be visible to anyone who can read the task definition) or, better, keep the CCS password itself in Key Vault and fetch it in a wrapper script.

## Binding handling

| Existing binding | Action |
| --- | --- |
| https binding with a different certificate | Rebinds it to the new thumbprint |
| http binding only | Creates an https binding on port 443 with SNI enabled |
| https binding already on the right thumbprint | Left alone |

Pass `-NoBindingCreate` to restrict the script to updating existing https bindings.

After applying, each binding is read back and its `certificateHash` compared to the expected thumbprint. A mismatch triggers a rollback rather than reporting success.

## Requirements

- Windows Server with IIS (`W3SVC` and the `WebAdministration` module). SNI requires IIS 8.0 or later.
- A managed identity with **get** on the target vault's certificates and secrets.
- If the Central Certificate Store is enabled, its private key password (`-CentralCertStorePassword`) and a store path reachable by the account running the script.
- The vault's data plane must be reachable. With a private endpoint, confirm `<vault>.vault.azure.net` resolves to the endpoint's address - a wrong answer surfaces as a TLS hostname mismatch.
- Must run **as Administrator** - it writes to the machine certificate store and edits `applicationHost.config`.
- Windows PowerShell 5.1 or PowerShell 7+.

## Usage

```powershell
.\Invoke-KeyVaultCertRenewal.ps1 [options]
```

| Parameter | Purpose |
| --- | --- |
| `-KeyVaultName <name>` | Skip vault auto-detection |
| `-ClientId <guid>` | Authenticate as a specific user-assigned identity |
| `-CentralCertStorePassword <SecureString>` | Required when IIS Central Certificate Store is enabled |
| `-NoBindingCreate` | Never create an https binding, only update existing ones |
| `-RestartIis` | Run `iisreset /noforce` after applying |
| `-DryRun` | Report what would change without installing or binding anything |

`KEY_VAULT_NAME` and `AZURE_CLIENT_ID` work as environment variables too.

Start with a dry run:

```powershell
.\Invoke-KeyVaultCertRenewal.ps1 -DryRun
```

## Running on a schedule

[KeyVaultCertRenewal.xml](KeyVaultCertRenewal.xml) is an importable Task Scheduler definition. It expects the script at **`C:\CertRenewal\Invoke-KeyVaultCertRenewal.ps1`** and runs **once every 24 hours**: midnight plus a random delay of up to 4 hours, so a fleet doesn't hit Key Vault simultaneously. `StartWhenAvailable` catches up after downtime, and `IgnoreNew` prevents overlapping runs.

```powershell
New-Item -ItemType Directory -Path C:\CertRenewal -Force
Copy-Item .\Invoke-KeyVaultCertRenewal.ps1 C:\CertRenewal\

# Import the task (runs as LOCAL SYSTEM, which holds the managed identity)
Register-ScheduledTask -TaskName 'KeyVaultCertRenewal' `
  -Xml (Get-Content .\KeyVaultCertRenewal.xml -Raw)
```

Or with `schtasks`:

```powershell
schtasks /create /tn "KeyVaultCertRenewal" /xml "KeyVaultCertRenewal.xml"
```

If the VM has more than one managed identity, add `-ClientId <guid>` to the `<Arguments>` line in the XML before importing, or set `AZURE_CLIENT_ID` as a machine environment variable.

Verify:

```powershell
Get-ScheduledTaskInfo -TaskName 'KeyVaultCertRenewal'   # next run time, last result
Start-ScheduledTask -TaskName 'KeyVaultCertRenewal'     # run now
Get-Content C:\ProgramData\KeyVaultCertRenewal\keyvault-cert-renewal.log -Tail 50
```

`LastTaskResult` of `0` is success. The script exits non-zero when it installs certificates but cannot complete - worth alerting on.

Daily is deliberate for 90-day certificates: it gives roughly 75 attempts before expiry, and runs where nothing changed exit early without ever reading the secret.

## Safety behaviour

- **Idempotent.** A run with nothing to do makes no changes and no restart.
- **Verified before trusted.** The imported thumbprint is checked against Key Vault, and the resulting binding is read back and compared.
- **Rollback.** A binding or verification failure restores `applicationHost.config` and removes only the certificates this run imported.
- **Single instance.** A global mutex prevents overlapping runs.
- **Guarded cleanup.** A superseded certificate is deleted only once the new binding is live and no other binding still references it.
- **Expiry alerting.** A certificate that matches locally but expires within 14 days raises a warning - that indicates the ACME issuance side has stopped renewing, which this script cannot fix.

## Backups

`applicationHost.config` is copied to `C:\ProgramData\KeyVaultCertRenewal\backups\<timestamp>\` before any binding is touched. One copy covers every site, since all bindings live in that single file. Backups older than 30 days are pruned automatically.

To restore by hand:

```powershell
Copy-Item C:\ProgramData\KeyVaultCertRenewal\backups\20260827221955\applicationHost.config `
          $env:windir\system32\inetsrv\config\applicationHost.config -Force
```

## Logging

Output goes to the console and to `C:\ProgramData\KeyVaultCertRenewal\keyvault-cert-renewal.log`:

```
2026-08-27 22:19:52 ==> Matching certificates
2026-08-27 22:19:54     iis-site-one.az.builtwithcaffeine.cloud
2026-08-27 22:19:54       iis-site-one-az-builtwithcaffeine-cloud, expires 2026-11-25 (89 days)
2026-08-27 22:19:54 OK  Matched 1 of 1 host(s)
```

`==>` marks a stage, `OK` success, `!!` a warning and `XX` a failure. The log directory is ACL'd to SYSTEM and Administrators only, since it names every host and vault the machine touches.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `TLS validation failed reaching <vault>.vault.azure.net` | DNS returns the wrong address for the vault - check private endpoint records and overlapping VNet ranges. The script prints the resolved IP. |
| `Access denied reading '<cert>'` | The identity lacks **get** on certificates/secrets, or the access policy targets a different identity. |
| `no certificate named '<cert>'` | No vault certificate matches that host name's dashed name. |
| `No binding with a host name found in IIS` | Every binding uses a blank or `*` host header. Add a host name in IIS Manager or via `New-WebBinding`. |
| `Binding for <host> reports thumbprint ...` | The binding did not take the new certificate; the run was rolled back. |
| `IIS Central Certificate Store is enabled` | Supply `-CentralCertStorePassword`, the provider's private key password. |
| `Central Certificate Store path is not reachable` | The share is offline, or SYSTEM cannot reach it. A UNC store needs a provider account with access. |
| `Binding for <host> is not flagged for the Central Certificate Store` | The binding's `sslFlags` did not take; the run was rolled back. |
| `W3SVC is not running` | IIS is stopped. Certificates and bindings are set and apply on next start. |

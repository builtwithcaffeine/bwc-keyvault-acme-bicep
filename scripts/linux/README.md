# Invoke-KeyVaultCertRenewal.sh

Automates renewing a web server's TLS certificate from Azure Key Vault on a Linux VM (nginx or Apache), using the VM's managed identity.

## What it does

1. **Checking Azure CLI** - installs the Azure CLI if it isn't already present.
2. **Ensuring log rotation** - installs a `logrotate` config for `/var/log/keyvault-cert-renewal.log` (daily rotation, 30 days retention, compressed).
3. **Detecting web server** - detects nginx or Apache on the host.
4. **Collecting server names** - parses `server_name` (nginx) / `ServerName` (Apache) directives from the web server's `sites-enabled` directory.
5. **Authenticating to Azure** - logs in with `az login --identity`, using `AZURE_CLIENT_ID` if set (user-assigned identity).
6. **Locating Key Vault** - finds the single Key Vault accessible to the managed identity (or uses the `KEYVAULT_NAME` override).
7. **Matching certificate** - finds the certificate in the vault whose Subject Alternative Names cover one of the detected server names.
8. **Checking certificate status** - compares the vault certificate's SHA-256 fingerprint against the locally installed certificate (public cert/metadata only - no secret access, no local changes) and exits early if they already match.
9. **Downloading certificate** - if the fingerprints differ, downloads the certificate as a PFX secret and splits it into a certificate/key pair.
10. **Installing certificate** - installs the certificate and key under `/etc/ssl/<certificate-name>/`.
11. **Reloading web server** - reloads nginx/Apache to pick up the new certificate.

## Requirements

- Debian/Ubuntu-based VM with nginx or Apache installed.
- A managed identity (system- or user-assigned) with `get`/`list` access to the target Key Vault's certificates and secrets.
- `openssl`, `grep`, `awk`, `sed`, `base64`, `date`, `install`, `systemctl` available (standard on most distros).
- Must be run as `root` (writes to `/etc/ssl`, `/etc/logrotate.d`, and reloads the web server via `systemctl`).

## Manual overrides

Set these at the top of the script (or export before running) to skip auto-detection:

- `KEYVAULT_NAME` — use a specific Key Vault instead of auto-discovering the single accessible vault.
- `AZURE_CLIENT_ID` — client ID of a user-assigned managed identity to log in with, instead of the system-assigned identity.

## Usage

```bash
bash Invoke-KeyVaultCertRenewal.sh
```

Exits `0` and prints "already up to date, nothing to do" if the installed certificate's fingerprint already matches the vault; otherwise downloads, installs, and reloads.

## Running on a schedule (cron)

As `root`, add a daily job (e.g. midnight):

```bash
crontab -e
```

```cron
0 0 * * * /usr/bin/bash /home/ladm_bwcadmin/Invoke-KeyVaultCertRenewal.sh >> /var/log/keyvault-cert-renewal.log 2>&1
```

### Testing the cron job without waiting

```bash
# Run exactly as cron would (no TTY, minimal environment)
sudo env -i /usr/bin/bash /home/ladm_bwcadmin/Invoke-KeyVaultCertRenewal.sh >> /var/log/keyvault-cert-renewal.log 2>&1; echo "exit: $?"

# Confirm cron itself fired the job
grep CRON /var/log/syslog | tail

# Review the log
tail -n 50 /var/log/keyvault-cert-renewal.log
```

## Log rotation

The script installs `/etc/logrotate.d/keyvault-cert-renewal` on every run, rotating `/var/log/keyvault-cert-renewal.log` daily, keeping 30 days of history (compressed), and truncating in place so cron's `>>` redirect keeps writing to the same file handle. No separate setup is required - `logrotate` runs via the system's own daily cron/timer.

## Troubleshooting

- Colors/formatting auto-disable when not attached to a terminal (e.g. under cron), so log output stays plain text.
- Every log line is timestamped, e.g. `[ 2026-07-31 - 15:15:00 ]`, to make it clear when each step ran.
- If "Collecting server names" fails, add a `server_name`/`ServerName` directive to your site config under `sites-enabled` and re-run.

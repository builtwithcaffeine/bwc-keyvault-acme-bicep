# Invoke-KeyVaultCertRenewal.sh

Renews TLS certificates for nginx or Apache from Azure Key Vault, using the VM's managed identity. Handles multiple sites on one host, updates the site configuration, and reloads the web server.

## What it does

1. **Ensuring log rotation** - writes `/etc/logrotate.d/keyvault-acme-update` if missing (daily, 30 days, compressed).
2. **Checking Azure CLI** - installs the Azure CLI from Microsoft's signed apt/dnf/zypper repository if absent.
3. **Authenticating to Azure** - `az login --identity`, using the user-assigned identity when one is supplied.
4. **Detecting web server** - finds nginx or Apache, and records whether its config already passes its own config test.
5. **Collecting server names** - reads every `server_name` / `ServerName` / `ServerAlias`, pairing each hostname with the file that declares it.
6. **Locating Key Vault** - uses `--key-vault-name`, or the single vault the identity can see.
7. **Matching certificates** - looks up one certificate per hostname by name convention (see below) and reads its expiry and fingerprint.
8. **Checking certificate status** - compares each vault fingerprint against the installed copy; unchanged hosts are skipped.
9. **Downloading certificates** - pulls the PFX secret, splits it into a full chain and private key, and verifies the fingerprint and that the key matches the certificate.
10. **Installing certificates** - writes `/etc/ssl/<fqdn>/fullchain.pem` (0644) and `privkey.pem` (0600).
11. **Validating site configuration** - stages config edits in a temp directory without touching anything on disk.
12. **Applying site configuration** - writes the staged files, runs `nginx -t` / `apachectl -t`, and rolls back on failure.
13. **Reloading web server** - reloads via `systemctl`, then removes the superseded backups.

## Certificate naming

Key Vault names cannot contain dots, so each hostname maps to a certificate by replacing them with dashes:

```
nginx-site-one.az.builtwithcaffeine.cloud  ->  nginx-site-one-az-builtwithcaffeine-cloud
```

The script fetches that certificate by name. It does not enumerate the vault, so the identity needs only `get` - not `list`. A hostname with no matching certificate is reported and skipped; the remaining sites still process.

## Site configuration handling

Each vhost falls into one of three cases:

| Existing config | Action |
| --- | --- |
| Has `ssl_certificate` / `SSLCertificateFile` | Rewrites the paths to `/etc/ssl/<fqdn>/` |
| Has a TLS listener but no certificate | Injects the certificate directives into that block |
| No TLS listener at all | Generates a complete `server { listen 443 ssl; ... }` / `<VirtualHost *:443>` block, reusing the existing document root |

Pass `--no-tls-append` to restrict the script to the first case only.

A config file serving hosts that need *different* certificates is skipped with a warning, because the rewrite is file-wide. Split those into one file per site.

For Apache, `mod_ssl` is enabled automatically via `a2enmod ssl` when a TLS vhost is generated. On distributions without `a2enmod`, the run fails with instructions to install it.

## Requirements

- nginx or Apache, and a managed identity with **get** on the target vault's certificates and secrets.
- The vault's data plane must be reachable. With a private endpoint, confirm `<vault>.vault.azure.net` resolves to the endpoint's address - a wrong answer surfaces as a TLS hostname mismatch.
- `openssl`, `awk`, `sed`, `grep`, `base64`, `flock`, `systemctl`.
- Must run as root: it writes `/etc/ssl`, edits site configs, and reloads the web server.

## Usage

```bash
sudo ./Invoke-KeyVaultCertRenewal.sh [options]
```

| Option | Purpose |
| --- | --- |
| `--key-vault-name NAME` | Skip vault auto-detection |
| `--client-id GUID` | Authenticate as a specific user-assigned identity |
| `--cert-dir PATH` | Base directory for certificates (default `/etc/ssl`) |
| `--no-tls-append` | Never create or modify TLS vhosts, only update existing paths |
| `--dry-run` | Report what would change without writing anything |

`KEY_VAULT_NAME`, `AZURE_CLIENT_ID`, and `CERT_DIR` work as environment variables too, which is how the systemd unit passes them.

Start with a dry run - it covers the configuration stage as well as certificate status:

```bash
sudo ./Invoke-KeyVaultCertRenewal.sh --dry-run
```

## Running on a schedule

Unit files live in [systemd/](systemd). The timer runs **once every 24 hours**: `OnCalendar=daily` fires at midnight and `RandomizedDelaySec=4h` shifts each host to a random point between 00:00 and 04:00, so a fleet doesn't hit Key Vault at once. `Persistent=true` catches up after downtime rather than skipping the day.

```bash
sudo install -m 0750 Invoke-KeyVaultCertRenewal.sh /usr/local/sbin/
sudo cp systemd/keyvault-cert-renewal.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now keyvault-cert-renewal.timer
```

If the VM has more than one managed identity, uncomment `Environment=AZURE_CLIENT_ID=...` in the service unit so the right one is used.

Verify:

```bash
systemctl list-timers keyvault-cert-renewal      # next scheduled run
sudo systemctl start keyvault-cert-renewal       # run now
journalctl -u keyvault-cert-renewal -n 50        # output of the last run
```

Daily is deliberate for 90-day certificates: it gives roughly 75 attempts before expiry, and runs where nothing changed exit early without ever reading the secret.

## Safety behaviour

- **Idempotent.** A run with nothing to do makes no writes and no reload.
- **Staged edits.** Config changes are built in a temp directory and only applied once every file has been prepared.
- **Rollback.** If the config test fails after applying, certificates and configs are restored from the backup taken earlier in the run.
- **Pre-existing breakage isn't punished.** If the config was already failing before the run, certificates are kept, the reload is skipped, and the script exits non-zero telling you to fix it - rather than blaming and reverting its own changes.
- **Single instance.** `flock` on `/run/keyvault-acme-update.lock` prevents overlapping runs.
- **Verified material.** Downloads are checked against the vault fingerprint, and the private key is confirmed to match the certificate before anything is installed.
- **Expiry alerting.** A certificate that matches locally but expires within 14 days raises a warning - that indicates the ACME issuance side has stopped renewing, which this script cannot fix.

## Backups

Every file the script is about to overwrite - certificates, keys and site configs - is copied to `/var/backups/keyvault-acme-update/<timestamp>/` (mode `0700`) before the write. The full path is flattened into the filename:

```
/var/backups/keyvault-acme-update/20260827221955/_etc_nginx_sites-available_default
```

Backups are **not** written next to the original. Debian's nginx config ends with `include /etc/nginx/sites-enabled/*;`, with no extension filter, so a backup left in that directory would be parsed as a second config and produce duplicate `server` blocks.

They are kept after a successful run for post-mortem, and directories older than 30 days are pruned automatically. Superseded **private keys** are the exception - they are shredded once the replacement is confirmed live, so an old key never lingers on disk. To restore by hand:

```bash
ls /var/backups/keyvault-acme-update/
sudo cp /var/backups/keyvault-acme-update/20260827221955/_etc_nginx_sites-available_default \
        /etc/nginx/sites-available/default
sudo nginx -t && sudo systemctl reload nginx
```

## Logging

Output goes to the console and to `/var/log/keyvault-acme-update.log`:

```
2026-08-27 22:19:52 ==> Matching certificates
2026-08-27 22:19:54     apache-site-one.az.builtwithcaffeine.cloud
2026-08-27 22:19:54       apache-site-one-az-builtwithcaffeine-cloud, expires 2026-11-25 (89 days)
2026-08-27 22:19:54 OK  Matched 1 of 1 host(s)
```

`==>` marks a stage, `OK` success, `!!` a warning and `XX` a failure. Warnings and failures also go to stderr, so `journalctl -p warning -u keyvault-cert-renewal` shows just those. Colour is applied to the console only - the log file stays plain text, and Azure CLI stderr is appended to it for diagnosis.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `TLS validation failed reaching <vault>.vault.azure.net` | DNS returns the wrong address for the vault - check private endpoint records and overlapping VNet ranges. The script prints the resolved IP. |
| `Access denied reading '<cert>'` | The identity lacks **get** on certificates/secrets, or the access policy targets a different identity. |
| `no certificate named '<cert>'` | No vault certificate matches that hostname's dashed name. |
| `nginx -T failed` warning | The live config is invalid; the script falls back to scanning `sites-enabled` and still installs certificates, but cannot reload until you fix it. |
| `serves hosts needing different certificates` | One config file contains vhosts for hosts using different certificates - split it. |
| `is not running, skipping reload` | The web server is stopped. Certificates are installed and apply on next start. |

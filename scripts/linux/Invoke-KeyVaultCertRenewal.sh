#!/usr/bin/env bash
#
# Renews an nginx/Apache TLS certificate from Azure Key Vault using the VM's managed identity.
#
# Usage:
#   sudo ./Invoke-KeyVaultCertRenewal.sh [--key-vault-name NAME] [--client-id GUID] [--cert-dir PATH]
#                                        [--no-tls-append] [--dry-run]
#
set -euo pipefail

# Parsing of openssl (notAfter=, sha256 Fingerprint=) and date output must not vary by locale
export LC_ALL=C
# Lock file, temp cert/key material and az scratch files are owner-only by default
umask 077

# ---- Configuration ----------------------------------------------------------

KEY_VAULT_NAME="${KEY_VAULT_NAME:-}"     # empty = auto-detect the single accessible vault
AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-}"   # empty = system-assigned identity
CERT_DIR="${CERT_DIR:-/etc/ssl}"        # certificates are installed to <CERT_DIR>/<fqdn>/
APPEND_TLS=1                             # generate a TLS vhost when one is missing
LOG_FILE="/var/log/keyvault-acme-update.log"
LOCK_FILE="/run/keyvault-acme-update.lock"
LOGROTATE_FILE="/etc/logrotate.d/keyvault-acme-update"
DRY_RUN=0

need_value() { [[ -n "${2:-}" ]] || { echo "$1 requires a value" >&2; exit 2; }; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key-vault-name) need_value "$1" "${2:-}"; KEY_VAULT_NAME="$2"; shift 2 ;;
    --client-id)      need_value "$1" "${2:-}"; AZURE_CLIENT_ID="$2"; shift 2 ;;
    --cert-dir)       need_value "$1" "${2:-}"; CERT_DIR="$2"; shift 2 ;;
    --no-tls-append)  APPEND_TLS=0; shift ;;
    --dry-run)        DRY_RUN=1; shift ;;
    -h|--help)        sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ $EUID -eq 0 ]] || { echo "This script must be run as root." >&2; exit 1; }

# ---- Logging helpers --------------------------------------------------------

# Created only when absent - installing /dev/null over an existing log would truncate it
if [[ ! -f "$LOG_FILE" ]]; then
  install -m 0640 -o root -g root /dev/null "$LOG_FILE"
else
  chmod 0640 "$LOG_FILE"
fi

ts() { date '+[ %Y-%m-%d - %H:%M:%S ]'; }
log()     { printf '%s %s\n' "$(ts)" "$*" | tee -a "$LOG_FILE"; }
step()    { echo; log "==> $*"; }
info()    { log "    $*"; }
success() { log "OK  $*"; }
warn()    { log "!!  $*"; }
fail()    { log "XX  $*"; exit 1; }

# Prevent overlapping runs (e.g. a slow run still executing when the timer fires again)
exec 9>"$LOCK_FILE"
flock -n 9 || { log "another run is already in progress, exiting"; exit 1; }

TMP_DIR="$(mktemp -d)"
chmod 0700 "$TMP_DIR"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# Runs an az query into a file, exposing the CLI's own error text in AZ_ERROR -
# without this a permissions failure is indistinguishable from an empty result
AZ_ERROR=""
az_tsv() {
  local out="$1"; shift
  local err="$TMP_DIR/az-err.txt"
  AZ_ERROR=""
  if az "$@" -o tsv > "$out" 2>"$err"; then return 0; fi
  cat "$err" >> "$LOG_FILE"
  AZ_ERROR="$(tr '\n' ' ' < "$err" | tr -s ' ' | cut -c1-300)"
  return 1
}

# ---- Ensuring log rotation --------------------------------------------------

step "Ensuring log rotation"
if [[ ! -f "$LOGROTATE_FILE" ]]; then
  cat > "$LOGROTATE_FILE" <<EOF
$LOG_FILE {
    daily
    rotate 30
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
    create 0640 root root
}
EOF
  chmod 0644 "$LOGROTATE_FILE"
  success "Created $LOGROTATE_FILE (30 days)"
else
  success "Log rotation already configured"
fi

# ---- Checking Azure CLI -----------------------------------------------------

step "Checking Azure CLI"
if ! command -v az >/dev/null 2>&1; then
  warn "Azure CLI not found, installing..."
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq curl ca-certificates gnupg apt-transport-https >/dev/null
    # Registering the signed repo lets apt verify every package, unlike piping the
    # installer script straight into a root shell
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor --yes -o /usr/share/keyrings/microsoft.gpg \
      || fail "Could not import the Microsoft signing key"
    chmod 0644 /usr/share/keyrings/microsoft.gpg
    # shellcheck disable=SC1091
    . /etc/os-release
    printf 'deb [arch=%s signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ %s main\n' \
      "$(dpkg --print-architecture)" "$VERSION_CODENAME" > /etc/apt/sources.list.d/azure-cli.list
    apt-get update -qq
    apt-get install -y -qq azure-cli >>"$LOG_FILE" 2>&1 \
      || fail "Azure CLI install failed, see $LOG_FILE"
  elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
    PKG=$(command -v dnf || command -v yum)
    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    "$PKG" install -y https://packages.microsoft.com/config/rhel/9/packages-microsoft-prod.rpm >>"$LOG_FILE" 2>&1 || true
    "$PKG" install -y azure-cli >>"$LOG_FILE" 2>&1 || fail "Azure CLI install failed, see $LOG_FILE"
  elif command -v zypper >/dev/null 2>&1; then
    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    zypper install -y azure-cli >>"$LOG_FILE" 2>&1 || fail "Azure CLI install failed, see $LOG_FILE"
  else
    fail "Unsupported distribution - install the Azure CLI manually and re-run."
  fi
fi
command -v az >/dev/null 2>&1 || fail "Azure CLI installation could not be verified."
command -v openssl >/dev/null 2>&1 || fail "openssl is required but not installed."
success "Azure CLI available"

# ---- Authenticating to Azure ------------------------------------------------

step "Authenticating to Azure"
if [[ -n "$AZURE_CLIENT_ID" ]]; then
  # Always re-login: a cached session may belong to a different identity on this VM
  # --client-id replaced --username in newer Azure CLI releases, so try both
  az login --identity --client-id "$AZURE_CLIENT_ID" >/dev/null 2>>"$LOG_FILE" \
    || az login --identity --username "$AZURE_CLIENT_ID" >/dev/null 2>>"$LOG_FILE" \
    || fail "az login --identity for $AZURE_CLIENT_ID failed, see $LOG_FILE"
  info "Using user-assigned identity: $AZURE_CLIENT_ID"
elif ! az account show >/dev/null 2>&1; then
  az login --identity >/dev/null 2>>"$LOG_FILE" \
    || fail "az login --identity failed, see $LOG_FILE"
  info "Using system-assigned identity"
else
  info "Using existing Azure CLI session"
fi
success "Authenticated to Azure"

# ---- Detecting web server ---------------------------------------------------

step "Detecting web server"
WEB_SERVER=""
APACHE_BIN=""
if command -v nginx >/dev/null 2>&1; then
  WEB_SERVER="nginx"
elif command -v apachectl >/dev/null 2>&1; then
  WEB_SERVER="apache"; APACHE_BIN="apachectl"
elif command -v apache2ctl >/dev/null 2>&1; then
  WEB_SERVER="apache"; APACHE_BIN="apache2ctl"
elif command -v httpd >/dev/null 2>&1; then
  WEB_SERVER="apache"; APACHE_BIN="httpd"
else
  fail "Neither nginx nor Apache was found on this host"
fi
success "Detected web server: $WEB_SERVER"

# A config that is already broken must not be blamed on - or rolled back by - this run
CONFIG_OK=1
if [[ "$WEB_SERVER" == "nginx" ]]; then
  nginx -t >"$TMP_DIR/preflight.txt" 2>&1 || CONFIG_OK=0
else
  "$APACHE_BIN" -t >"$TMP_DIR/preflight.txt" 2>&1 || CONFIG_OK=0
fi
if (( CONFIG_OK )); then
  info "Existing configuration passes its config test"
else
  cat "$TMP_DIR/preflight.txt" >> "$LOG_FILE"
  warn "Existing configuration is already invalid, $WEB_SERVER cannot be reloaded until it is fixed:"
  warn "$(grep -m1 -iE 'emerg|error|syntax' "$TMP_DIR/preflight.txt" || head -n1 "$TMP_DIR/preflight.txt")"
fi

# ---- Collecting server names ------------------------------------------------

step "Collecting server names"
# Each entry is "hostname<TAB>config-file" so the matching vhost can be updated later
VHOST_MAP="$TMP_DIR/vhosts.tsv"
: > "$VHOST_MAP"

# Extracts "server_name a b c;" / "ServerName a" / "ServerAlias a b" from a config file
parse_server_names() {
  local conf="$1"
  awk -v conf="$conf" '
    /^[[:space:]]*(server_name|ServerName|ServerAlias)[[:space:]]/ {
      line = $0
      sub(/#.*$/, "", line); sub(/;.*$/, "", line)
      sub(/^[[:space:]]*(server_name|ServerName|ServerAlias)[[:space:]]+/, "", line)
      n = split(line, names, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        if (names[i] != "" && names[i] != "_" && names[i] !~ /^[*~]/) print names[i] "\t" conf
      }
    }
  ' "$conf"
}

if [[ "$WEB_SERVER" == "nginx" ]]; then
  # nginx -T dumps the fully resolved config, annotated with "# configuration file <path>:"
  if nginx -T > "$TMP_DIR/nginx-dump.txt" 2>"$TMP_DIR/nginx-err.txt"; then
    awk '
      /^# configuration file / { file = $4; sub(/:$/, "", file); next }
      /^[[:space:]]*server_name[[:space:]]/ {
        line = $0
        sub(/#.*$/, "", line); sub(/;.*$/, "", line)
        sub(/^[[:space:]]*server_name[[:space:]]+/, "", line)
        n = split(line, names, /[[:space:]]+/)
        for (i = 1; i <= n; i++) {
          if (names[i] != "" && names[i] != "_" && names[i] !~ /^[*~]/) print names[i] "\t" file
        }
      }
    ' "$TMP_DIR/nginx-dump.txt" | sort -u > "$VHOST_MAP"
  else
    # A config test failure is expected on first run, when the vhost still points at a
    # certificate path this script has not created yet - fall back to scanning the tree
    cat "$TMP_DIR/nginx-err.txt" >> "$LOG_FILE"
    warn "nginx -T failed: $(head -n 3 "$TMP_DIR/nginx-err.txt" | tr '\n' ' ')"
    warn "Falling back to scanning nginx config for server names"
    # Prefer sites-enabled so disabled vhosts are not given certificates;
    # -R (not -r) follows the symlinks it contains
    NGINX_SCAN_ROOT=/etc/nginx
    [[ -d /etc/nginx/sites-enabled ]] && NGINX_SCAN_ROOT=/etc/nginx/sites-enabled
    while IFS= read -r conf; do
      parse_server_names "$conf"
    done < <(grep -RlE '^[[:space:]]*server_name[[:space:]]' "$NGINX_SCAN_ROOT" 2>/dev/null || true) \
      | sort -u > "$VHOST_MAP"
  fi
else
  # apachectl -S lines all end in "(<file>:<line>)" preceded by the host name, whether
  # they read "port 443 namevhost x.com (...)", "*:80 x.com (...)" or "default server x.com (...)"
  if "$APACHE_BIN" -S > "$TMP_DIR/apache-dump.txt" 2>&1; then
    awk '
      $NF ~ /^\(\/.*:[0-9]+\)$/ && NF >= 2 {
        host = $(NF - 1)
        file = $NF
        gsub(/[()]/, "", file)
        sub(/:[0-9]+$/, "", file)
        if (host ~ /\./ && host !~ /^[*:]/) print host "\t" file
      }
    ' "$TMP_DIR/apache-dump.txt" | sort -u > "$VHOST_MAP"
  else
    cat "$TMP_DIR/apache-dump.txt" >> "$LOG_FILE"
    warn "$APACHE_BIN -S failed: $(head -n 3 "$TMP_DIR/apache-dump.txt" | tr '\n' ' ')"
  fi

  # -S reports nothing useful when every vhost lacks a ServerName, so scan the tree
  if [[ ! -s "$VHOST_MAP" ]]; then
    warn "No server names in $APACHE_BIN -S output, scanning Apache config instead"
    APACHE_ROOT=$([[ -d /etc/apache2 ]] && echo /etc/apache2 || echo /etc/httpd)
    [[ -d "$APACHE_ROOT/sites-enabled" ]] && APACHE_ROOT="$APACHE_ROOT/sites-enabled"
    while IFS= read -r conf; do
      parse_server_names "$conf"
    done < <(grep -RlE '^[[:space:]]*ServerName[[:space:]]' "$APACHE_ROOT" 2>/dev/null || true) \
      | sort -u > "$VHOST_MAP"
  fi
fi

if [[ ! -s "$VHOST_MAP" ]]; then
  if [[ "$WEB_SERVER" == "apache" ]]; then
    fail "No ServerName found in any enabled Apache vhost - add 'ServerName <fqdn>' to your site config and re-run"
  fi
  fail "No server_name found in any enabled nginx vhost - add 'server_name <fqdn>;' to your site config and re-run"
fi

# sites-enabled entries are symlinks into sites-available, so resolve to the real
# file to avoid staging the same config twice under two different paths
while IFS=$'\t' read -r vhost_name vhost_file; do
  printf '%s\t%s\n' "$vhost_name" "$(realpath -m "$vhost_file" 2>/dev/null || echo "$vhost_file")"
done < "$VHOST_MAP" | sort -u > "$VHOST_MAP.tmp"
mv "$VHOST_MAP.tmp" "$VHOST_MAP"

mapfile -t SERVER_NAMES < <(cut -f1 "$VHOST_MAP" | sort -u)
success "Found ${#SERVER_NAMES[@]} server name(s)"
for name in "${SERVER_NAMES[@]}"; do info "- $name"; done

# ---- Locating Key Vault -----------------------------------------------------

step "Locating Key Vault"
if [[ -n "$KEY_VAULT_NAME" ]]; then
  info "Using manual override"
else
  az_tsv "$TMP_DIR/vaults.txt" keyvault list --query '[].name' \
    || fail "az keyvault list failed: $AZ_ERROR"
  mapfile -t VAULTS < <(grep -v '^$' "$TMP_DIR/vaults.txt" || true)
  (( ${#VAULTS[@]} > 0 )) || fail "No Key Vault accessible to this managed identity"
  (( ${#VAULTS[@]} == 1 )) || fail "Expected exactly one accessible Key Vault, found ${#VAULTS[@]}: ${VAULTS[*]}"
  KEY_VAULT_NAME="${VAULTS[0]}"
fi
success "Using Key Vault: $KEY_VAULT_NAME"

# ---- Matching certificates --------------------------------------------------

step "Matching certificates"
declare -A CERT_BY_HOST CERT_FINGERPRINT CERT_EXPIRY CERT_DAYS
MATCHED_HOSTS=()

for host in "${SERVER_NAMES[@]}"; do
  # Rejects anything that is not a plain hostname, so it can never escape $CERT_DIR
  if [[ ! "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
    warn "Skipping malformed server name: $host"
    continue
  fi

  # Key Vault names cannot contain dots, so site.example.com is stored as site-example-com
  cert="${host//./-}"

  # Reads only the public certificate (cer) - no secret access, no local changes
  if ! az_tsv "$TMP_DIR/$cert.b64cer" keyvault certificate show --vault-name "$KEY_VAULT_NAME" --name "$cert" --query 'cer'; then
    case "$AZ_ERROR" in
      *CERTIFICATE_VERIFY_FAILED*|*SSLError*|*"certificate verify failed"*)
        # ARM reached the vault but the data plane did not, so this is name resolution
        # or TLS interception in front of <vault>.vault.azure.net
        info "$KEY_VAULT_NAME.vault.azure.net resolves to: $(getent hosts "$KEY_VAULT_NAME.vault.azure.net" | awk '{print $1}' | tr '\n' ' ')"
        fail "TLS validation failed reaching $KEY_VAULT_NAME.vault.azure.net - check private endpoint DNS or an intercepting proxy: $AZ_ERROR" ;;
      *Forbidden*|*AccessDenied*|*"not authorized"*|*"does not have"*)
        fail "Access denied reading '$cert' - grant the identity get on certificates and secrets: $AZ_ERROR" ;;
      *NotFound*|*"not found"*|*CertificateNotFound*)
        warn "$host: no certificate named '$cert' in $KEY_VAULT_NAME"; continue ;;
      *)
        warn "$host: could not read '$cert': $AZ_ERROR"; continue ;;
    esac
  fi

  if [[ ! -s "$TMP_DIR/$cert.b64cer" ]]; then
    warn "$host: certificate '$cert' returned no public certificate (cer) data"
    continue
  fi

  base64 -d < "$TMP_DIR/$cert.b64cer" > "$TMP_DIR/$cert.der" || fail "Could not decode certificate data for $cert"
  openssl x509 -inform DER -in "$TMP_DIR/$cert.der" -out "$TMP_DIR/$cert.vault.pem" \
    || fail "Could not parse certificate data for $cert"

  CERT_FINGERPRINT["$cert"]="$(openssl x509 -in "$TMP_DIR/$cert.vault.pem" -noout -fingerprint -sha256 | cut -d= -f2-)"
  CERT_EXPIRY["$cert"]="$(openssl x509 -in "$TMP_DIR/$cert.vault.pem" -noout -enddate | cut -d= -f2)"
  CERT_DAYS["$cert"]=$(( ($(date -d "${CERT_EXPIRY[$cert]}" +%s) - $(date +%s)) / 86400 ))
  (( ${CERT_DAYS[$cert]} >= 0 )) || warn "Certificate '$cert' has already expired"

  CERT_BY_HOST["$host"]="$cert"
  MATCHED_HOSTS+=("$host")
  info "$host -> $cert (expires ${CERT_EXPIRY[$cert]}, ${CERT_DAYS[$cert]} days)"
done

(( ${#MATCHED_HOSTS[@]} > 0 )) || fail "No certificate in $KEY_VAULT_NAME matches: ${SERVER_NAMES[*]}"
success "Matched ${#MATCHED_HOSTS[@]} of ${#SERVER_NAMES[@]} host(s)"

# ---- Checking certificate status --------------------------------------------

step "Checking certificate status"
STALE_HOSTS=()

for host in "${MATCHED_HOSTS[@]}"; do
  cert="${CERT_BY_HOST[$host]}"
  local_fingerprint=""
  if [[ -f "$CERT_DIR/$host/fullchain.pem" ]]; then
    local_fingerprint="$(openssl x509 -in "$CERT_DIR/$host/fullchain.pem" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2- || true)"
  fi

  if [[ "${CERT_FINGERPRINT[$cert]}" == "$local_fingerprint" ]]; then
    info "$host: up to date"
    # An up-to-date copy of a near-expiry certificate means the ACME issuance
    # side has not renewed it yet, which this script cannot fix
    (( ${CERT_DAYS[$cert]} > 14 )) \
      || warn "$host: Key Vault copy expires in ${CERT_DAYS[$cert]} days - check the ACME renewal job"
  else
    STALE_HOSTS+=("$host")
    info "$host: needs update"
  fi
done

STALE_CERTS=()
if (( ${#STALE_HOSTS[@]} > 0 )); then
  mapfile -t STALE_CERTS < <(for host in "${STALE_HOSTS[@]}"; do echo "${CERT_BY_HOST[$host]}"; done | sort -u)
fi
success "${#STALE_HOSTS[@]} of ${#MATCHED_HOSTS[@]} host(s) need a new certificate"

if (( DRY_RUN )); then
  for host in "${STALE_HOSTS[@]:-}"; do
    [[ -n "$host" ]] && warn "Dry run: ${CERT_BY_HOST[$host]} would be installed to $CERT_DIR/$host"
  done
fi

# ---- Downloading certificates -----------------------------------------------

# OpenSSL 3 rejects the legacy RC2 encryption used by some PFX exports unless -legacy is passed
pkcs12() { openssl pkcs12 "$@" -passin pass: 2>/dev/null || openssl pkcs12 "$@" -passin pass: -legacy; }
# Strips OpenSSL's bag attribute preamble so nginx/Apache see clean PEM
strip_pem() { awk '/^-----BEGIN/,/^-----END/' "$1"; }

step "Downloading certificates"
for cert in "${STALE_CERTS[@]:-}"; do
  [[ -n "$cert" ]] || continue
  (( DRY_RUN )) && continue
  # Certificates are stored as PFX-encoded secrets alongside the certificate object
  pfx_b64="$TMP_DIR/$cert.b64"
  pfx_file="$TMP_DIR/$cert.pfx"
  az_tsv "$pfx_b64" keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$cert" --query 'value' \
    || fail "Failed to read secret '$cert' from Key Vault '$KEY_VAULT_NAME': $AZ_ERROR"
  [[ -s "$pfx_b64" ]] || fail "Secret '$cert' is empty"
  base64 -d < "$pfx_b64" > "$pfx_file" || fail "Could not decode PFX data for $cert"
  shred -u "$pfx_b64" 2>/dev/null || rm -f "$pfx_b64"

  # -nokeys emits the leaf plus any chain certs in one pass, which is exactly a fullchain
  pkcs12 -in "$pfx_file" -nokeys -out "$TMP_DIR/$cert.chainbag.pem" || fail "Could not extract certificate from PFX for $cert"
  pkcs12 -in "$pfx_file" -nocerts -nodes -out "$TMP_DIR/$cert.rawkey.pem" || fail "Could not extract private key from PFX for $cert"
  shred -u "$pfx_file" 2>/dev/null || rm -f "$pfx_file"

  strip_pem "$TMP_DIR/$cert.chainbag.pem" > "$TMP_DIR/$cert.fullchain.pem"
  strip_pem "$TMP_DIR/$cert.rawkey.pem" > "$TMP_DIR/$cert.privkey.pem"

  new_fingerprint="$(openssl x509 -in "$TMP_DIR/$cert.fullchain.pem" -noout -fingerprint -sha256 | cut -d= -f2-)"
  [[ "$new_fingerprint" == "${CERT_FINGERPRINT[$cert]}" ]] \
    || fail "Downloaded $cert fingerprint ($new_fingerprint) does not match Key Vault (${CERT_FINGERPRINT[$cert]})"

  # The key must belong to the certificate, or the reload will fail once the config is live
  cert_modulus="$(openssl x509 -in "$TMP_DIR/$cert.fullchain.pem" -noout -modulus 2>/dev/null | openssl md5)"
  key_modulus="$(openssl rsa -in "$TMP_DIR/$cert.privkey.pem" -noout -modulus 2>/dev/null | openssl md5 || true)"
  if [[ -n "$key_modulus" && "$cert_modulus" != "$key_modulus" ]]; then
    fail "Private key does not match the certificate for $cert"
  fi

  info "Downloaded and verified: $cert"
done
if (( DRY_RUN )); then
  info "Dry run: skipped downloading ${#STALE_CERTS[@]} certificate(s)"
else
  success "All certificates downloaded and verified"
fi

# ---- Installing certificates ------------------------------------------------

step "Installing certificates"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

for host in "${STALE_HOSTS[@]:-}"; do
  [[ -n "$host" ]] || continue
  (( DRY_RUN )) && continue
  cert="${CERT_BY_HOST[$host]}"
  target_dir="$CERT_DIR/$host"
  install -d -m 0750 -o root -g root "$target_dir"

  # Keep the previous pair so a failed config test can be rolled back
  if [[ -f "$target_dir/fullchain.pem" ]]; then cp -p "$target_dir/fullchain.pem" "$target_dir/fullchain.pem$BACKUP_SUFFIX"; fi
  if [[ -f "$target_dir/privkey.pem" ]]; then cp -p "$target_dir/privkey.pem" "$target_dir/privkey.pem$BACKUP_SUFFIX"; fi

  install -m 0644 -o root -g root "$TMP_DIR/$cert.fullchain.pem" "$target_dir/fullchain.pem"
  install -m 0600 -o root -g root "$TMP_DIR/$cert.privkey.pem" "$target_dir/privkey.pem"
  info "$host -> $target_dir ($cert, ${CERT_FINGERPRINT[$cert]})"
done
if (( DRY_RUN )); then
  info "Dry run: skipped installing certificates for ${#STALE_HOSTS[@]} host(s)"
else
  success "Installed certificates for ${#STALE_HOSTS[@]} host(s)"
fi

# ---- Validating site configuration ------------------------------------------

step "Validating site configuration"
# The rewrite is file-wide, so a file serving hosts that need different certificates
# cannot be edited safely and is skipped rather than given one host's certificate
declare -A FILE_HOST
declare -A CONFLICT_FILES
for host in "${MATCHED_HOSTS[@]}"; do
  while IFS= read -r conf; do
    [[ -n "$conf" ]] || continue
    existing="${FILE_HOST[$conf]:-}"
    if [[ -z "$existing" ]]; then
      FILE_HOST["$conf"]="$host"
    elif [[ "${CERT_BY_HOST[$existing]}" != "${CERT_BY_HOST[$host]}" ]]; then
      CONFLICT_FILES["$conf"]=1
      warn "$conf serves hosts needing different certificates ($existing, $host) - skipping, split it into one file per site"
    fi
  done < <(awk -F'\t' -v h="$host" '$1 == h { print $2 }' "$VHOST_MAP")
done

TARGET_FILES=()
for conf in "${!FILE_HOST[@]}"; do
  [[ -n "${CONFLICT_FILES[$conf]:-}" ]] || TARGET_FILES+=("$conf")
done

# Rewrites are staged in the temp dir first so nothing is touched until every file validates
STAGE_DIR="$TMP_DIR/stage"
mkdir -p "$STAGE_DIR"
declare -A STAGED
PENDING_FILES=()
NO_TLS_FILES=()
APPENDED_FILES=()
STAGE_INDEX=0
TLS_ACTION=""

# Gives a config file a working TLS vhost: injects the certificate directives into an
# existing TLS listener, or generates a whole vhost when the site is HTTP-only
append_tls_block() {
  local conf="$1" host="$2" fullchain="$3" privkey="$4" staged="$5" root=""

  if [[ "$WEB_SERVER" == "nginx" ]]; then
    if grep -qE '^[[:space:]]*listen[[:space:]].*ssl' "$conf"; then
      # Inserted after the last of the consecutive listen directives, so an
      # IPv4/IPv6 pair is not split apart
      awk -v fc="$fullchain" -v pk="$privkey" '
        { lines[NR] = $0 }
        END {
          for (i = 1; i <= NR; i++) {
            if (!at && lines[i] ~ /^[[:space:]]*listen[[:space:]]/ && lines[i] ~ /ssl/) {
              j = i
              while (j + 1 <= NR && lines[j + 1] ~ /^[[:space:]]*listen[[:space:]]/) j++
              at = j
            }
          }
          for (i = 1; i <= NR; i++) {
            print lines[i]
            if (i == at) {
              match(lines[i], /^[[:space:]]*/)
              indent = substr(lines[i], 1, RLENGTH)
              print indent "ssl_certificate " fc ";"
              print indent "ssl_certificate_key " pk ";"
            }
          }
        }
      ' "$conf" > "$staged"
      TLS_ACTION="certificate directives added to existing ssl listener"
      return 0
    fi

    root="$(awk '/^[[:space:]]*root[[:space:]]/ { sub(/;.*$/, ""); sub(/^[[:space:]]*root[[:space:]]+/, ""); print; exit }' "$conf")"
    [[ -n "$root" ]] || root="/var/www/html"

    cat "$conf" > "$staged"
    cat >> "$staged" <<EOF

# TLS vhost generated by Invoke-KeyVaultCertRenewal.sh
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $host;

    ssl_certificate $fullchain;
    ssl_certificate_key $privkey;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    root $root;
    index index.html index.htm index.nginx-debian.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    TLS_ACTION="TLS vhost generated"
  else
    if grep -qiE '<VirtualHost[^>]*:443' "$conf"; then
      awk -v fc="$fullchain" -v pk="$privkey" '
        { print }
        !done && /<VirtualHost[^>]*:443/ {
          match($0, /^[[:space:]]*/)
          indent = substr($0, 1, RLENGTH) "    "
          print indent "SSLEngine on"
          print indent "SSLCertificateFile " fc
          print indent "SSLCertificateKeyFile " pk
          done = 1
        }
      ' "$conf" > "$staged"
      TLS_ACTION="certificate directives added to existing :443 vhost"
      return 0
    fi

    root="$(awk '/^[[:space:]]*DocumentRoot[[:space:]]/ { sub(/^[[:space:]]*DocumentRoot[[:space:]]+/, ""); gsub(/"/, ""); print; exit }' "$conf")"
    [[ -n "$root" ]] || root="/var/www/html"

    cat "$conf" > "$staged"
    cat >> "$staged" <<EOF

# TLS vhost generated by Invoke-KeyVaultCertRenewal.sh
<VirtualHost *:443>
    ServerName $host
    DocumentRoot $root

    SSLEngine on
    SSLCertificateFile $fullchain
    SSLCertificateKeyFile $privkey
    SSLProtocol -all +TLSv1.2 +TLSv1.3
</VirtualHost>
EOF
    TLS_ACTION="TLS vhost generated"
  fi
  return 0
}

for conf in "${TARGET_FILES[@]}"; do
  if [[ ! -f "$conf" ]]; then warn "Config file not found: $conf"; continue; fi

  cert_host="${FILE_HOST[$conf]}"
  fullchain="$CERT_DIR/$cert_host/fullchain.pem"
  privkey="$CERT_DIR/$cert_host/privkey.pem"
  staged="$STAGE_DIR/$((STAGE_INDEX++)).conf"

  if ! grep -qiE '^[[:space:]]*(ssl_certificate|SSLCertificateFile)[[:space:]]' "$conf"; then
    if (( ! APPEND_TLS )); then
      NO_TLS_FILES+=("$conf")
      continue
    fi
    append_tls_block "$conf" "$cert_host" "$fullchain" "$privkey" "$staged"
    STAGED["$conf"]="$staged"
    PENDING_FILES+=("$conf")
    APPENDED_FILES+=("$conf")
    info "$conf ($cert_host): $TLS_ACTION"
    continue
  fi

  if [[ "$WEB_SERVER" == "nginx" ]]; then
    sed -E \
      -e "s#^([[:space:]]*)ssl_certificate[[:space:]]+[^;]+;#\1ssl_certificate $fullchain;#" \
      -e "s#^([[:space:]]*)ssl_certificate_key[[:space:]]+[^;]+;#\1ssl_certificate_key $privkey;#" \
      "$conf" > "$staged"
  else
    sed -E \
      -e "s#^([[:space:]]*)SSLCertificateFile[[:space:]]+.*#\1SSLCertificateFile $fullchain#I" \
      -e "s#^([[:space:]]*)SSLCertificateKeyFile[[:space:]]+.*#\1SSLCertificateKeyFile $privkey#I" \
      -e "/^[[:space:]]*SSLCertificateChainFile[[:space:]]/Id" \
      "$conf" > "$staged"
  fi

  if cmp -s "$conf" "$staged"; then
    info "Already current: $conf ($cert_host)"
  else
    STAGED["$conf"]="$staged"
    PENDING_FILES+=("$conf")
    info "Pending update: $conf ($cert_host)"
  fi
done

if (( ${#NO_TLS_FILES[@]} > 0 )); then
  warn "${#NO_TLS_FILES[@]} vhost(s) left unchanged - add ssl_certificate/ssl_certificate_key pointing at $CERT_DIR/<fqdn>/:"
  for conf in "${NO_TLS_FILES[@]}"; do warn "  $conf (${FILE_HOST[$conf]})"; done
fi

success "Validated ${#TARGET_FILES[@]} config file(s), ${#PENDING_FILES[@]} to update (${#APPENDED_FILES[@]} new TLS vhost(s))"

if (( DRY_RUN )); then
  step "Done"
  success "Dry run complete, nothing was changed"
  exit 0
fi

if (( ${#STALE_HOSTS[@]} == 0 && ${#PENDING_FILES[@]} == 0 )); then
  step "Done"
  success "All certificates and site configuration are already up to date, nothing to do."
  exit 0
fi

# ---- Applying site configuration --------------------------------------------

step "Applying site configuration"
SSL_MODULE_ENABLED=0
rollback() {
  warn "Rolling back configuration and certificates"
  if (( SSL_MODULE_ENABLED )); then a2dismod ssl >>"$LOG_FILE" 2>&1 || true; fi
  for conf in "${TARGET_FILES[@]}"; do
    if [[ -f "$conf$BACKUP_SUFFIX" ]]; then mv -f "$conf$BACKUP_SUFFIX" "$conf"; fi
  done
  for host in "${STALE_HOSTS[@]:-}"; do
    [[ -n "$host" ]] || continue
    if [[ -f "$CERT_DIR/$host/fullchain.pem$BACKUP_SUFFIX" ]]; then mv -f "$CERT_DIR/$host/fullchain.pem$BACKUP_SUFFIX" "$CERT_DIR/$host/fullchain.pem"; fi
    if [[ -f "$CERT_DIR/$host/privkey.pem$BACKUP_SUFFIX" ]]; then mv -f "$CERT_DIR/$host/privkey.pem$BACKUP_SUFFIX" "$CERT_DIR/$host/privkey.pem"; fi
  done
}

for conf in "${PENDING_FILES[@]:-}"; do
  [[ -n "$conf" ]] || continue
  cp -p "$conf" "$conf$BACKUP_SUFFIX"
  cat "${STAGED[$conf]}" > "$conf"
  info "Applied: $conf"
done

if (( ${#PENDING_FILES[@]} == 0 )); then
  info "No config changes required, certificate files replaced in place"
fi

# A generated <VirtualHost *:443> is inert without mod_ssl, and apachectl -t
# still passes without it, so the module has to be enabled explicitly
if [[ "$WEB_SERVER" == "apache" ]] && (( ${#APPENDED_FILES[@]} > 0 )); then
  if "$APACHE_BIN" -M 2>/dev/null | grep -q ssl_module; then
    info "mod_ssl already enabled"
  elif command -v a2enmod >/dev/null 2>&1; then
    a2enmod ssl >>"$LOG_FILE" 2>&1 || { rollback; fail "a2enmod ssl failed, see $LOG_FILE"; }
    SSL_MODULE_ENABLED=1
    info "Enabled mod_ssl (also adds Listen 443 via ports.conf)"
  else
    rollback
    fail "mod_ssl is not loaded and a2enmod is unavailable - install it (e.g. 'dnf install mod_ssl') and re-run"
  fi

  apache_root=$([[ -d /etc/apache2 ]] && echo /etc/apache2 || echo /etc/httpd)
  grep -RqE '^[[:space:]]*Listen[[:space:]]+([0-9.]+:)?443' "$apache_root" 2>/dev/null \
    || warn "No 'Listen 443' directive found under $apache_root - the new TLS vhost will not bind"
fi

# The config test runs against the live tree, so it can only happen once changes are applied
if [[ "$WEB_SERVER" == "nginx" ]]; then
  nginx -t >"$TMP_DIR/posttest.txt" 2>&1 && CONFIG_TEST_OK=1 || CONFIG_TEST_OK=0
else
  "$APACHE_BIN" -t >"$TMP_DIR/posttest.txt" 2>&1 && CONFIG_TEST_OK=1 || CONFIG_TEST_OK=0
fi
cat "$TMP_DIR/posttest.txt" >> "$LOG_FILE"

if (( ! CONFIG_TEST_OK )); then
  if (( CONFIG_OK )); then
    rollback
    fail "$WEB_SERVER config test failed after applying changes, rolled back: $(grep -m1 -iE 'emerg|error|syntax' "$TMP_DIR/posttest.txt" || true)"
  fi
  # The config was already failing before this run, so the new certificates are
  # kept and only the reload is skipped
  warn "Certificates installed, but $WEB_SERVER config was already invalid before this run"
  warn "Fix the config and run 'systemctl reload $WEB_SERVER' to activate them"
  step "Done"
  exit 1
fi
success "Configuration applied and config test passed"

# ---- Reloading web server ---------------------------------------------------

step "Reloading $WEB_SERVER"
if [[ "$WEB_SERVER" == "nginx" ]]; then
  WEB_SERVICE=nginx
else
  WEB_SERVICE=$(systemctl list-units --type=service --all --no-legend 'apache2.service' 'httpd.service' 2>/dev/null | awk '{print $1}' | head -n1)
  WEB_SERVICE="${WEB_SERVICE:-apache2}"
fi

# A stopped server is not a failure - the certificates are in place and will be
# picked up whenever it is started, so there is nothing to roll back
if ! systemctl is-active --quiet "$WEB_SERVICE"; then
  warn "$WEB_SERVICE is not running, skipping reload - certificates are installed and will apply on next start"
elif systemctl reload "$WEB_SERVICE" >>"$LOG_FILE" 2>&1; then
  success "$WEB_SERVER reloaded"
else
  rollback
  fail "$WEB_SERVER reload failed, see $LOG_FILE"
fi

# Remove superseded backups only after the new certificates are confirmed live
for host in "${STALE_HOSTS[@]:-}"; do
  [[ -n "$host" ]] && rm -f "$CERT_DIR/$host/fullchain.pem$BACKUP_SUFFIX" "$CERT_DIR/$host/privkey.pem$BACKUP_SUFFIX"
done
for conf in "${TARGET_FILES[@]}"; do rm -f "$conf$BACKUP_SUFFIX"; done

# ---- Summary ----------------------------------------------------------------

step "Done"
info "Key Vault:  $KEY_VAULT_NAME"
info "Web server: $WEB_SERVER"
for host in "${MATCHED_HOSTS[@]}"; do
  cert="${CERT_BY_HOST[$host]}"
  info "$host -> $CERT_DIR/$host ($cert, expires ${CERT_EXPIRY[$cert]}, ${CERT_DAYS[$cert]} days)"
done
info "Log:        $LOG_FILE"
success "Updated ${#STALE_HOSTS[@]} host(s) across ${#TARGET_FILES[@]} site config(s), $WEB_SERVER reloaded"

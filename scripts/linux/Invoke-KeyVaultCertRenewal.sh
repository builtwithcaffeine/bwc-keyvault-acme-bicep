#!/usr/bin/env bash
#
# Renews an nginx/Apache TLS certificate from Azure Key Vault using the VM's managed identity.
#
# Usage:
#   sudo ./Invoke-KeyVaultCertRenewal.sh [--key-vault-name NAME] [--client-id GUID] [--cert-dir PATH] [--dry-run]
#
set -euo pipefail

# ---- Configuration ----------------------------------------------------------

KEY_VAULT_NAME="${KEY_VAULT_NAME:-}"     # empty = auto-detect the single accessible vault
AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-}"   # empty = system-assigned identity
CERT_DIR="${CERT_DIR:-/etc/ssl/keyvault}"
LOG_FILE="/var/log/keyvault-acme-update.log"
LOCK_FILE="/var/run/keyvault-acme-update.lock"
LOGROTATE_FILE="/etc/logrotate.d/keyvault-acme-update"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key-vault-name) KEY_VAULT_NAME="$2"; shift 2 ;;
    --client-id)      AZURE_CLIENT_ID="$2"; shift 2 ;;
    --cert-dir)       CERT_DIR="$2"; shift 2 ;;
    --dry-run)        DRY_RUN=1; shift ;;
    -h|--help)        sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ $EUID -eq 0 ]] || { echo "This script must be run as root." >&2; exit 1; }

# ---- Logging helpers --------------------------------------------------------

install -m 0640 -o root -g root /dev/null "$LOG_FILE" 2>/dev/null || touch "$LOG_FILE"
chmod 0640 "$LOG_FILE"

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

# ---- Ensuring log rotation --------------------------------------------------

step "Ensuring log rotation"
if [[ ! -f "$LOGROTATE_FILE" ]]; then
  cat > "$LOGROTATE_FILE" <<'EOF'
/var/log/keyvault-acme-update.log {
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
    apt-get install -y -qq curl ca-certificates >/dev/null
    # Microsoft-published installer; adds the signed apt repo and installs azure-cli
    curl -fsSL https://aka.ms/InstallAzureCLIDeb | bash >>"$LOG_FILE" 2>&1 \
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

# ---- Collecting server names ------------------------------------------------

step "Collecting server names"
# Each entry is "hostname<TAB>config-file" so the matching vhost can be updated later
VHOST_MAP="$TMP_DIR/vhosts.tsv"
: > "$VHOST_MAP"

if [[ "$WEB_SERVER" == "nginx" ]]; then
  # nginx -T dumps the fully resolved config, annotated with "# configuration file <path>:"
  nginx -T > "$TMP_DIR/nginx-dump.txt" 2>>"$LOG_FILE" || fail "nginx -T failed, config may be invalid"
  awk '
    /^# configuration file / { file = $4; sub(/:$/, "", file); next }
    /^[[:space:]]*server_name[[:space:]]/ {
      line = $0
      sub(/;.*$/, "", line)
      sub(/^[[:space:]]*server_name[[:space:]]+/, "", line)
      n = split(line, names, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        if (names[i] != "" && names[i] != "_" && names[i] !~ /^[*~]/) print names[i] "\t" file
      }
    }
  ' "$TMP_DIR/nginx-dump.txt" | sort -u > "$VHOST_MAP"
else
  # apachectl -S lists: "port 443 namevhost example.com (/etc/apache2/sites-enabled/x.conf:12)"
  "$APACHE_BIN" -S > "$TMP_DIR/apache-dump.txt" 2>&1 || fail "$APACHE_BIN -S failed, config may be invalid"
  awk '
    /port 443 namevhost/ {
      host = $4
      file = $5
      gsub(/[()]/, "", file)
      sub(/:[0-9]+$/, "", file)
      if (host != "" && file != "") print host "\t" file
    }
  ' "$TMP_DIR/apache-dump.txt" | sort -u > "$VHOST_MAP"
fi

if [[ ! -s "$VHOST_MAP" ]]; then
  fail "No TLS-enabled virtual hosts with a server name were found for $WEB_SERVER"
fi

mapfile -t SERVER_NAMES < <(cut -f1 "$VHOST_MAP" | sort -u)
success "Found ${#SERVER_NAMES[@]} server name(s)"
for name in "${SERVER_NAMES[@]}"; do info "- $name"; done

# ---- Authenticating to Azure ------------------------------------------------

step "Authenticating to Azure"
if ! az account show >/dev/null 2>&1; then
  info "Logging in using managed identity..."
  if [[ -n "$AZURE_CLIENT_ID" ]]; then
    az login --identity --client-id "$AZURE_CLIENT_ID" >/dev/null 2>>"$LOG_FILE" \
      || fail "az login --identity --client-id $AZURE_CLIENT_ID failed, see $LOG_FILE"
  else
    az login --identity >/dev/null 2>>"$LOG_FILE" \
      || fail "az login --identity failed, see $LOG_FILE"
  fi
fi
success "Authenticated to Azure"

# ---- Locating Key Vault -----------------------------------------------------

step "Locating Key Vault"
if [[ -n "$KEY_VAULT_NAME" ]]; then
  info "Using manual override"
else
  mapfile -t VAULTS < <(az keyvault list --query '[].name' -o tsv 2>>"$LOG_FILE" | grep -v '^$' || true)
  (( ${#VAULTS[@]} > 0 )) || fail "No Key Vault accessible to this managed identity"
  (( ${#VAULTS[@]} == 1 )) || fail "Expected exactly one accessible Key Vault, found ${#VAULTS[@]}: ${VAULTS[*]}"
  KEY_VAULT_NAME="${VAULTS[0]}"
fi
success "Using Key Vault: $KEY_VAULT_NAME"

# ---- Matching certificate ---------------------------------------------------

step "Matching certificate"
mapfile -t VAULT_CERTS < <(az keyvault certificate list --vault-name "$KEY_VAULT_NAME" --query '[].name' -o tsv 2>>"$LOG_FILE" | grep -v '^$' || true)
(( ${#VAULT_CERTS[@]} > 0 )) || fail "No certificates found in $KEY_VAULT_NAME"

CERT_NAME=""
MATCHED_HOSTS=()
for vault_cert in "${VAULT_CERTS[@]}"; do
  mapfile -t SANS < <(az keyvault certificate show --vault-name "$KEY_VAULT_NAME" --name "$vault_cert" \
    --query 'policy.x509CertificateProperties.subjectAlternativeNames.dnsNames' -o tsv 2>>"$LOG_FILE" | grep -v '^$' || true)
  for san in "${SANS[@]}"; do
    # Translate a SAN (possibly a wildcard, e.g. *.example.com) into an anchored regex
    san_regex="^$(printf '%s' "$san" | sed -e 's/[].[^$\\/+?(){}|]/\\&/g' -e 's/\*/[^.]+/g')$"
    for server_name in "${SERVER_NAMES[@]}"; do
      if printf '%s' "$server_name" | grep -Eqi "$san_regex"; then
        CERT_NAME="$vault_cert"
        MATCHED_HOSTS+=("$server_name")
      fi
    done
  done
  [[ -n "$CERT_NAME" ]] && break
done

[[ -n "$CERT_NAME" ]] || fail "No certificate in $KEY_VAULT_NAME matches: ${SERVER_NAMES[*]}"
mapfile -t MATCHED_HOSTS < <(printf '%s\n' "${MATCHED_HOSTS[@]}" | sort -u)
success "Found certificate: $CERT_NAME"
for host in "${MATCHED_HOSTS[@]}"; do info "matches $host"; done

# ---- Checking certificate status --------------------------------------------

step "Checking certificate status"
TARGET_DIR="$CERT_DIR/$CERT_NAME"
FULLCHAIN="$TARGET_DIR/fullchain.pem"
PRIVKEY="$TARGET_DIR/privkey.pem"

# Uses only the public certificate (cer) - no secret access, no local changes
VAULT_CER_B64="$(az keyvault certificate show --vault-name "$KEY_VAULT_NAME" --name "$CERT_NAME" --query 'cer' -o tsv 2>>"$LOG_FILE")"
[[ -n "$VAULT_CER_B64" ]] || fail "Certificate '$CERT_NAME' returned no public certificate (cer) data"

printf '%s' "$VAULT_CER_B64" | base64 -d > "$TMP_DIR/vault.der" || fail "Could not decode certificate data"
openssl x509 -inform DER -in "$TMP_DIR/vault.der" -out "$TMP_DIR/vault.pem" \
  || fail "Could not parse certificate data"

VAULT_FINGERPRINT="$(openssl x509 -in "$TMP_DIR/vault.pem" -noout -fingerprint -sha256 | cut -d= -f2)"
VAULT_EXPIRY="$(openssl x509 -in "$TMP_DIR/vault.pem" -noout -enddate | cut -d= -f2)"
EXPIRY_EPOCH="$(date -d "$VAULT_EXPIRY" +%s)"
EXPIRY_DAYS=$(( (EXPIRY_EPOCH - $(date +%s)) / 86400 ))
info "Expires: $VAULT_EXPIRY ($EXPIRY_DAYS days remaining)"
(( EXPIRY_DAYS >= 0 )) || warn "Vault certificate '$CERT_NAME' has already expired"

LOCAL_FINGERPRINT=""
if [[ -f "$FULLCHAIN" ]]; then
  LOCAL_FINGERPRINT="$(openssl x509 -in "$FULLCHAIN" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2 || true)"
fi

if [[ "$VAULT_FINGERPRINT" == "$LOCAL_FINGERPRINT" ]]; then
  success "Certificate $CERT_NAME is already up to date, nothing to do."
  exit 0
fi

if (( DRY_RUN )); then
  warn "Dry run: certificate $CERT_NAME would be downloaded and installed to $TARGET_DIR"
  exit 0
fi

# ---- Downloading certificate ------------------------------------------------

step "Downloading certificate"
# Certificates are stored as PFX-encoded secrets alongside the certificate object
PFX_B64="$TMP_DIR/cert.b64"
PFX_FILE="$TMP_DIR/cert.pfx"
(umask 077; az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$CERT_NAME" --query 'value' -o tsv > "$PFX_B64" 2>>"$LOG_FILE") \
  || fail "Failed to read secret '$CERT_NAME' from Key Vault '$KEY_VAULT_NAME'"
[[ -s "$PFX_B64" ]] || fail "Secret '$CERT_NAME' is empty"
base64 -d < "$PFX_B64" > "$PFX_FILE" || fail "Could not decode PFX data"
shred -u "$PFX_B64" 2>/dev/null || rm -f "$PFX_B64"

# OpenSSL 3 rejects the legacy RC2 encryption used by some PFX exports unless -legacy is passed
pkcs12() { openssl pkcs12 "$@" -passin pass: 2>/dev/null || openssl pkcs12 "$@" -passin pass: -legacy; }
pkcs12 -in "$PFX_FILE" -nokeys -clcerts -out "$TMP_DIR/cert.pem" || fail "Could not extract certificate from PFX"
pkcs12 -in "$PFX_FILE" -nokeys -cacerts -out "$TMP_DIR/chain.pem" || true
pkcs12 -in "$PFX_FILE" -nocerts -nodes -out "$TMP_DIR/key.pem" || fail "Could not extract private key from PFX"
shred -u "$PFX_FILE" 2>/dev/null || rm -f "$PFX_FILE"

# Strip OpenSSL's bag attribute preamble so nginx/Apache see clean PEM
strip_pem() { awk '/^-----BEGIN/,/^-----END/' "$1"; }
strip_pem "$TMP_DIR/cert.pem" > "$TMP_DIR/fullchain.pem"
if [[ -s "$TMP_DIR/chain.pem" ]]; then strip_pem "$TMP_DIR/chain.pem" >> "$TMP_DIR/fullchain.pem"; fi
strip_pem "$TMP_DIR/key.pem" > "$TMP_DIR/privkey.pem"

NEW_FINGERPRINT="$(openssl x509 -in "$TMP_DIR/fullchain.pem" -noout -fingerprint -sha256 | cut -d= -f2)"
[[ "$NEW_FINGERPRINT" == "$VAULT_FINGERPRINT" ]] \
  || fail "Downloaded certificate fingerprint ($NEW_FINGERPRINT) does not match Key Vault ($VAULT_FINGERPRINT)"
success "Certificate downloaded and verified"

# ---- Installing certificate -------------------------------------------------

step "Installing certificate"
install -d -m 0750 -o root -g root "$CERT_DIR"
install -d -m 0750 -o root -g root "$TARGET_DIR"

# Keep the previous pair so a failed config test can be rolled back
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"
if [[ -f "$FULLCHAIN" ]]; then cp -p "$FULLCHAIN" "$FULLCHAIN$BACKUP_SUFFIX"; fi
if [[ -f "$PRIVKEY" ]]; then cp -p "$PRIVKEY" "$PRIVKEY$BACKUP_SUFFIX"; fi

install -m 0644 -o root -g root "$TMP_DIR/fullchain.pem" "$FULLCHAIN"
install -m 0600 -o root -g root "$TMP_DIR/privkey.pem" "$PRIVKEY"
info "Fingerprint: $VAULT_FINGERPRINT"
success "Certificate installed to $TARGET_DIR"

# ---- Updating site configuration --------------------------------------------

step "Updating site configuration"
mapfile -t TARGET_FILES < <(
  for host in "${MATCHED_HOSTS[@]}"; do
    awk -F'\t' -v h="$host" '$1 == h { print $2 }' "$VHOST_MAP"
  done | sort -u
)

CONFIG_CHANGED=0
for conf in "${TARGET_FILES[@]}"; do
  [[ -f "$conf" ]] || { warn "Config file not found: $conf"; continue; }
  cp -p "$conf" "$conf$BACKUP_SUFFIX"

  if [[ "$WEB_SERVER" == "nginx" ]]; then
    sed -i -E \
      -e "s#^([[:space:]]*)ssl_certificate[[:space:]]+[^;]+;#\1ssl_certificate $FULLCHAIN;#" \
      -e "s#^([[:space:]]*)ssl_certificate_key[[:space:]]+[^;]+;#\1ssl_certificate_key $PRIVKEY;#" \
      "$conf"
  else
    sed -i -E \
      -e "s#^([[:space:]]*)SSLCertificateFile[[:space:]]+.*#\1SSLCertificateFile $FULLCHAIN#I" \
      -e "s#^([[:space:]]*)SSLCertificateKeyFile[[:space:]]+.*#\1SSLCertificateKeyFile $PRIVKEY#I" \
      "$conf"
    # A bundled fullchain makes a separate chain file redundant and Apache 2.4.8+ rejects it
    sed -i -E "s#^([[:space:]]*)SSLCertificateChainFile[[:space:]]+.*#\1#I" "$conf"
  fi

  if cmp -s "$conf" "$conf$BACKUP_SUFFIX"; then
    rm -f "$conf$BACKUP_SUFFIX"
    info "No change needed: $conf"
  else
    CONFIG_CHANGED=1
    info "Updated: $conf"
  fi
done

# ---- Validating and reloading -----------------------------------------------

step "Validating and reloading $WEB_SERVER"
rollback() {
  warn "Rolling back configuration and certificate"
  for conf in "${TARGET_FILES[@]}"; do
    if [[ -f "$conf$BACKUP_SUFFIX" ]]; then mv -f "$conf$BACKUP_SUFFIX" "$conf"; fi
  done
  if [[ -f "$FULLCHAIN$BACKUP_SUFFIX" ]]; then mv -f "$FULLCHAIN$BACKUP_SUFFIX" "$FULLCHAIN"; fi
  if [[ -f "$PRIVKEY$BACKUP_SUFFIX" ]]; then mv -f "$PRIVKEY$BACKUP_SUFFIX" "$PRIVKEY"; fi
}

if [[ "$WEB_SERVER" == "nginx" ]]; then
  nginx -t >>"$LOG_FILE" 2>&1 || { rollback; fail "nginx config test failed, see $LOG_FILE"; }
  systemctl reload nginx >>"$LOG_FILE" 2>&1 || nginx -s reload >>"$LOG_FILE" 2>&1 \
    || { rollback; fail "nginx reload failed, see $LOG_FILE"; }
else
  "$APACHE_BIN" -t >>"$LOG_FILE" 2>&1 || { rollback; fail "Apache config test failed, see $LOG_FILE"; }
  APACHE_SERVICE=$(systemctl list-units --type=service --all --no-legend 'apache2.service' 'httpd.service' 2>/dev/null | awk '{print $1}' | head -n1)
  systemctl reload "${APACHE_SERVICE:-apache2}" >>"$LOG_FILE" 2>&1 \
    || { rollback; fail "Apache reload failed, see $LOG_FILE"; }
fi
success "$WEB_SERVER reloaded"

# Remove superseded backups only after the new certificate is confirmed live
rm -f "$FULLCHAIN$BACKUP_SUFFIX" "$PRIVKEY$BACKUP_SUFFIX"
for conf in "${TARGET_FILES[@]}"; do rm -f "$conf$BACKUP_SUFFIX"; done

step "Done"
if (( CONFIG_CHANGED )); then
  success "Certificate $CERT_NAME installed, site config updated and $WEB_SERVER reloaded"
else
  success "Certificate $CERT_NAME renewed in place and $WEB_SERVER reloaded"
fi

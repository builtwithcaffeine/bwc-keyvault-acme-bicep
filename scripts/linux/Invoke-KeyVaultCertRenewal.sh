#!/usr/bin/env bash
set -euo pipefail

# Force C locale so date/openssl output parsing (notAfter=, fingerprint=) never
# depends on the system locale.
export LC_ALL=C

# Restrict permissions on every file this script creates (lock file, temp cert/key
# material, az stderr scratch file) to the owner (root) by default.
umask 077

# Manual overrides - set either to skip auto-detection, leave empty to auto-detect
KEYVAULT_NAME=""
AZURE_CLIENT_ID=""

# Log rotation configuration
LOG_FILE="/var/log/keyvault-cert-renewal.log"
LOGROTATE_CONF="/etc/logrotate.d/keyvault-cert-renewal"
chmod 640 "${LOG_FILE}" 2>/dev/null || true

# Prevent overlapping runs (e.g. a slow run still executing when cron fires again)
LOCK_FILE="/var/run/keyvault-cert-renewal.lock"
exec 200>"${LOCK_FILE}"
if ! flock -n 200; then
  echo "$(date '+[ %Y-%m-%d - %H:%M:%S ]') another run is already in progress, exiting" >&2
  exit 1
fi

# Scratch file for az's stderr, kept separate from stdout so a stray warning can
# never corrupt a captured value (e.g. a base64 secret). Cleaned up on exit
# alongside any later temp cert material, regardless of how the script terminates.
AZ_STDERR_FILE=$(mktemp)
trap 'rm -f "${AZ_STDERR_FILE}"; [ -n "${TMP_DIR:-}" ] && rm -rf "${TMP_DIR}"' EXIT

# Color/formatting helpers, disabled automatically when not attached to a terminal
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  C_RESET=$(tput sgr0); C_BOLD=$(tput bold)
  C_CYAN=$(tput setaf 6); C_GREEN=$(tput setaf 2)
  C_YELLOW=$(tput setaf 3); C_RED=$(tput setaf 1)
else
  C_RESET=""; C_BOLD=""; C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi

ts()      { date '+[ %Y-%m-%d - %H:%M:%S ]'; }
step()    { printf '\n%s %s==>%s %s%s%s\n' "$(ts)" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "$1" "${C_RESET}"; }
info()    { printf '%s     %s\n' "$(ts)" "$1"; }
success() { printf '%s %s✔%s %s\n' "$(ts)" "${C_GREEN}" "${C_RESET}" "$1"; }
warn()    { printf '%s %s⚠%s %s\n' "$(ts)" "${C_YELLOW}" "${C_RESET}" "$1"; }
fail()    { printf '%s %s✘%s %s\n' "$(ts)" "${C_RED}" "${C_RESET}" "$1" >&2; exit 1; }

# Runs `az "$@"`, capturing stdout and stderr into separate variables (never merged,
# so stray stderr text like a deprecation warning can't corrupt a captured stdout
# value) and the exit code explicitly instead of relying on process substitution.
az_call() {
  local rc
  AZ_OUTPUT=$(az "$@" 2>"${AZ_STDERR_FILE}") && rc=0 || rc=$?
  AZ_STDERR=$(cat "${AZ_STDERR_FILE}" 2>/dev/null || true)
  : > "${AZ_STDERR_FILE}"
  return "${rc}"
}

step "Checking Azure CLI"
if ! command -v az >/dev/null 2>&1; then
  warn "Azure CLI not found, installing..."
  installer_script=$(mktemp)
  curl -sL --fail https://aka.ms/InstallAzureCLIDeb -o "${installer_script}"
  info "Installer sha256: $(sha256sum "${installer_script}" | cut -d' ' -f1)"
  bash "${installer_script}"
  rm -f "${installer_script}"
fi
success "Azure CLI available"

step "Ensuring log rotation"
if command -v logrotate >/dev/null 2>&1; then
  cat > "${LOGROTATE_CONF}" <<EOF
${LOG_FILE} {
    daily
    rotate 30
    maxage 30
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
}
EOF
  success "Log rotation configured: ${LOGROTATE_CONF} (${LOG_FILE}, 30 days)"
else
  warn "logrotate not found, skipping log rotation setup"
fi

step "Detecting web server"
WEBSERVER=""
SITES_ENABLED_DIR=""
SERVER_NAME_DIRECTIVE=""

if command -v nginx >/dev/null 2>&1; then
  WEBSERVER="nginx"
  SITES_ENABLED_DIR="/etc/nginx/sites-enabled"
  SERVER_NAME_DIRECTIVE="server_name"
elif command -v apache2ctl >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1; then
  WEBSERVER="apache"
  SITES_ENABLED_DIR="/etc/apache2/sites-enabled"
  SERVER_NAME_DIRECTIVE="ServerName"
else
  fail "Neither nginx nor apache is installed"
fi

success "Detected web server: ${WEBSERVER}"

if [ ! -d "${SITES_ENABLED_DIR}" ]; then
  fail "Sites-enabled directory not found at ${SITES_ENABLED_DIR}"
fi

step "Collecting server names from ${SITES_ENABLED_DIR}"
# -R (not -r) so symlinked configs (the norm for sites-enabled) are followed
# (uses [[:space:]] instead of \s, which isn't portable in POSIX ERE)
# guarded with || true - an empty match must not trip set -e/pipefail silently
raw_server_names=$(grep -RhoE "^[[:space:]]*${SERVER_NAME_DIRECTIVE}[[:space:]]+[^;#]+" "${SITES_ENABLED_DIR}" 2>/dev/null || true)

if [ -z "${raw_server_names}" ]; then
  if [ "${WEBSERVER}" = "nginx" ]; then
    example="server_name example.com;"
  else
    example="ServerName example.com"
  fi
  fail "No ${SERVER_NAME_DIRECTIVE} entries found in any file under ${SITES_ENABLED_DIR}. Add a directive like '${example}' to your site config and re-run."
fi

raw_server_names=$(echo "${raw_server_names}" | awk '{$1=""; print}')
raw_server_names=$(echo "${raw_server_names}" | tr -s ' \t' '\n')
raw_server_names=$(echo "${raw_server_names}" | sed '/^$/d')
mapfile -t SERVER_NAMES < <(echo "${raw_server_names}" | sort -u)

if [ "${#SERVER_NAMES[@]}" -eq 0 ]; then
  fail "No ${SERVER_NAME_DIRECTIVE} entries found in ${SITES_ENABLED_DIR}"
fi

success "Found ${#SERVER_NAMES[@]} server name(s)"
for server_name in "${SERVER_NAMES[@]}"; do
  info "- ${server_name}"
done

step "Authenticating to Azure"
# AZURE_CLIENT_ID selects the user-assigned identity, if set
if ! az_call account show; then
  info "Logging in using managed identity..."
  if [ -n "${AZURE_CLIENT_ID:-}" ]; then
    az_call login --identity --username "${AZURE_CLIENT_ID}" || fail "az login --identity failed: ${AZ_STDERR}"
  else
    az_call login --identity || fail "az login --identity failed: ${AZ_STDERR}"
  fi
fi
success "Authenticated to Azure"

step "Locating Key Vault"
if [ -n "${KEYVAULT_NAME}" ]; then
  info "Using manual override"
else
  # Only one Key Vault is expected to be accessible to this managed identity
  az_call keyvault list --query "[].name" -o tsv || fail "az keyvault list failed: ${AZ_STDERR}"
  mapfile -t KEYVAULTS <<< "${AZ_OUTPUT}"
  KEYVAULTS=("${KEYVAULTS[@]//$'\r'/}")

  if [ "${#KEYVAULTS[@]}" -eq 0 ] || [ -z "${KEYVAULTS[0]}" ]; then
    fail "No Key Vault accessible to this managed identity"
  elif [ "${#KEYVAULTS[@]}" -gt 1 ]; then
    fail "Expected exactly one accessible Key Vault, found ${#KEYVAULTS[@]}: ${KEYVAULTS[*]}"
  fi

  KEYVAULT_NAME="${KEYVAULTS[0]}"
fi
success "Using Key Vault: ${KEYVAULT_NAME}"

step "Matching certificate"
# Match a certificate in the vault whose SANs cover one of the detected server names
az_call keyvault certificate list --vault-name "${KEYVAULT_NAME}" --query "[].name" -o tsv || fail "az keyvault certificate list failed: ${AZ_STDERR}"
mapfile -t VAULT_CERT_NAMES <<< "${AZ_OUTPUT}"

CERT_NAME=""
for server_name in "${SERVER_NAMES[@]}"; do
  for vault_cert_name in "${VAULT_CERT_NAMES[@]}"; do
    [ -n "${vault_cert_name}" ] || continue
    sans=$(az keyvault certificate show --vault-name "${KEYVAULT_NAME}" --name "${vault_cert_name}" --query "policy.x509CertificateProperties.subjectAlternativeNames.dnsNames" -o tsv 2>/dev/null || true)
    if echo "${sans}" | grep -qx "${server_name}"; then
      CERT_NAME="${vault_cert_name}"
      break 2
    fi
  done
done

if [ -z "${CERT_NAME}" ]; then
  fail "No certificate found in ${KEYVAULT_NAME} matching: ${SERVER_NAMES[*]}"
fi

success "Found certificate: ${CERT_NAME}"

CERT_DIR="/etc/ssl/${CERT_NAME}"
CERT_FILE="${CERT_DIR}/fullchain.crt"
KEY_FILE="${CERT_DIR}/privkey.key"
if [ -d "${CERT_DIR}" ]; then
  info "Local path: ${CERT_DIR}"
else
  info "Local path: ${CERT_DIR} (not yet created)"
fi
info "Certificate: ${CERT_FILE}"
info "Private key: ${KEY_FILE}"

step "Checking certificate status"
# Uses only the public certificate (cer) and metadata - no secret access, no local changes
if ! VAULT_CER_B64=$(az keyvault certificate show --vault-name "${KEYVAULT_NAME}" --name "${CERT_NAME}" --query cer -o tsv); then
  fail "Failed to read certificate '${CERT_NAME}' from Key Vault '${KEYVAULT_NAME}'"
fi

if [ -z "${VAULT_CER_B64}" ]; then
  fail "Certificate '${CERT_NAME}' returned no public certificate (cer) data"
fi

if ! VAULT_CERT_INFO=$(echo "${VAULT_CER_B64}" | base64 -d | openssl x509 -inform DER -noout -enddate -fingerprint -sha256 2>&1); then
  fail "Failed to parse certificate data: ${VAULT_CERT_INFO}"
fi

VAULT_EXPIRY_DATE=$(echo "${VAULT_CERT_INFO}" | grep -i '^notAfter=' | cut -d= -f2- || true)
VAULT_FINGERPRINT=$(echo "${VAULT_CERT_INFO}" | grep -i '^sha256 Fingerprint=' | cut -d= -f2- || true)

if [ -z "${VAULT_EXPIRY_DATE}" ] || [ -z "${VAULT_FINGERPRINT}" ]; then
  fail "Could not parse expiry/fingerprint from certificate data: ${VAULT_CERT_INFO}"
fi

EXPIRY_EPOCH=$(date -d "${VAULT_EXPIRY_DATE}" +%s)
NOW_EPOCH=$(date +%s)
EXPIRY_DAYS=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
info "Expires: ${VAULT_EXPIRY_DATE} (${EXPIRY_DAYS} days remaining)"

LOCAL_FINGERPRINT=""
if [ -f "${CERT_FILE}" ]; then
  LOCAL_FINGERPRINT=$(openssl x509 -in "${CERT_FILE}" -noout -fingerprint -sha256 | grep -i '^sha256 Fingerprint=' | cut -d= -f2- || true)
fi

if [ "${VAULT_FINGERPRINT}" = "${LOCAL_FINGERPRINT}" ]; then
  echo ""
  success "Certificate ${CERT_NAME} is already up to date, nothing to do."
  exit 0
fi

mkdir -p "${CERT_DIR}"
chmod 750 "${CERT_DIR}"

TMP_DIR=$(mktemp -d)

TMP_PFX="${TMP_DIR}/cert.pfx"
TMP_CERT="${TMP_DIR}/fullchain.pem"
TMP_KEY="${TMP_DIR}/privkey.pem"

step "Downloading certificate"
# Certificates are stored as PFX-encoded secrets alongside the certificate object
az_call keyvault secret show --vault-name "${KEYVAULT_NAME}" --name "${CERT_NAME}" --query value -o tsv || fail "az keyvault secret show failed: ${AZ_STDERR}"
echo "${AZ_OUTPUT}" | base64 -d > "${TMP_PFX}"
unset AZ_OUTPUT

openssl pkcs12 -in "${TMP_PFX}" -nokeys -passin pass: -out "${TMP_CERT}"
openssl pkcs12 -in "${TMP_PFX}" -nocerts -nodes -passin pass: -out "${TMP_KEY}"
chmod 600 "${TMP_KEY}"
success "Certificate downloaded and decoded"

# Integrity check - make sure the downloaded cert and key are actually a matching pair
CERT_MODULUS=$(openssl x509 -in "${TMP_CERT}" -noout -modulus | openssl md5)
KEY_MODULUS=$(openssl rsa -in "${TMP_KEY}" -noout -modulus 2>/dev/null | openssl md5)
if [ "${CERT_MODULUS}" != "${KEY_MODULUS}" ]; then
  fail "Downloaded certificate and private key do not match, aborting install"
fi

step "Installing certificate"
# Keep a timestamped backup of the previous cert/key so a bad renewal can be rolled back
if [ -f "${CERT_FILE}" ] || [ -f "${KEY_FILE}" ]; then
  BACKUP_DIR="${CERT_DIR}/backup-$(date '+%Y%m%d%H%M%S')"
  mkdir -p "${BACKUP_DIR}"
  chmod 700 "${BACKUP_DIR}"
  [ -f "${CERT_FILE}" ] && cp -p "${CERT_FILE}" "${BACKUP_DIR}/" || true
  [ -f "${KEY_FILE}" ] && cp -p "${KEY_FILE}" "${BACKUP_DIR}/" || true
  info "Previous certificate backed up to ${BACKUP_DIR}"
fi

install -m 644 "${TMP_CERT}" "${CERT_FILE}"
install -m 600 "${TMP_KEY}" "${KEY_FILE}"
info "Certificate: ${CERT_FILE}"
info "Private key: ${KEY_FILE}"
success "Certificate installed"

step "Reloading ${WEBSERVER}"
if [ "${WEBSERVER}" = "nginx" ]; then
  systemctl reload nginx
else
  systemctl reload apache2 2>/dev/null || systemctl reload httpd
fi
success "${WEBSERVER} reloaded"

step "Done"
success "Certificate ${CERT_NAME} installed and ${WEBSERVER} reloaded"

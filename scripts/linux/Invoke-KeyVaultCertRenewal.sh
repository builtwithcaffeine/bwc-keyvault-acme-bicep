#!/usr/bin/env bash
set -Eeuo pipefail

# This script intentionally does not use `set -x`: Azure Key Vault secret values
# and private-key material must never be copied into a log. Set DEBUG=1 for safe,
# structured diagnostics that log commands and timings but never secret-bearing output.

IFS=$'\n\t'
export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export LC_ALL=C
umask 077

# Optional environment overrides. Environment values are preserved rather than
# overwritten, which makes the script usable from a protected systemd EnvironmentFile.
KEYVAULT_NAME="${KEYVAULT_NAME:-}"
# User-assigned managed identity client-ID override. If empty, the script uses
# IMDS to discover the VM's single unambiguous user-assigned identity.
AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-}"
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
AZURE_CLOUD="${AZURE_CLOUD:-AzureCloud}"
CERT_NAME="${CERT_NAME:-}"
WEB_SERVER="${WEB_SERVER:-auto}"       # auto, nginx, or apache
CONFIG_DIR="${CONFIG_DIR:-}"           # optional absolute config directory
DEBUG="${DEBUG:-0}"
EXPIRY_WARN_DAYS="${EXPIRY_WARN_DAYS:-30}"

readonly LOG_FILE='/var/log/keyvault-cert-renewal.log'
readonly LOGROTATE_CONF='/etc/logrotate.d/keyvault-cert-renewal'
readonly LOCK_FILE='/run/keyvault-cert-renewal.lock'

case "${DEBUG,,}" in
  1|true|yes) DEBUG=1 ;;
  0|false|no|'') DEBUG=0 ;;
  *) printf 'DEBUG must be 0/1, true/false, or yes/no\n' >&2; exit 2 ;;
esac

if ! [[ "${EXPIRY_WARN_DAYS}" =~ ^[0-9]{1,4}$ ]] || (( 10#${EXPIRY_WARN_DAYS} > 3650 )); then
  printf 'EXPIRY_WARN_DAYS must be an integer from 0 through 3650\n' >&2
  exit 2
fi
EXPIRY_WARN_DAYS=$(( 10#${EXPIRY_WARN_DAYS} ))

UUID_REGEX='^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$'
if [[ -n "${AZURE_CLIENT_ID}" && ! "${AZURE_CLIENT_ID}" =~ ${UUID_REGEX} ]]; then
  printf 'AZURE_CLIENT_ID must be a UUID client ID\n' >&2
  exit 2
fi
if [[ -n "${AZURE_SUBSCRIPTION_ID}" && ! "${AZURE_SUBSCRIPTION_ID}" =~ ${UUID_REGEX} ]]; then
  printf 'AZURE_SUBSCRIPTION_ID must be a UUID subscription ID\n' >&2
  exit 2
fi
if [[ ! "${AZURE_CLOUD}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  printf 'AZURE_CLOUD contains unsupported characters\n' >&2
  exit 2
fi

if [[ "${WEB_SERVER}" != 'auto' && "${WEB_SERVER}" != 'nginx' && "${WEB_SERVER}" != 'apache' ]]; then
  printf 'WEB_SERVER must be auto, nginx, or apache\n' >&2
  exit 2
fi

if [[ -n "${CONFIG_DIR}" && ( "${CONFIG_DIR}" != /* || "${CONFIG_DIR}" == *$'\n'* || "${CONFIG_DIR}" == *$'\r'* ) ]]; then
  printf 'CONFIG_DIR must be an absolute path without control characters\n' >&2
  exit 2
fi

if [[ "$(id -u)" -ne 0 ]]; then
  printf 'This script must be run as root (it writes under /etc, /var/log, and /run)\n' >&2
  exit 1
fi

for bootstrap_command in tee flock mktemp stat; do
  if ! command -v "${bootstrap_command}" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "${bootstrap_command}" >&2
    exit 1
  fi
done

# Do not follow a planted symlink or append privileged logs to a non-root file.
if [[ -L "${LOG_FILE}" ]]; then
  printf 'Refusing to use symlink as log file: %s\n' "${LOG_FILE}" >&2
  exit 1
fi
if [[ -e "${LOG_FILE}" && "$(stat -c '%u' -- "${LOG_FILE}")" -ne 0 ]]; then
  printf 'Refusing to use log file not owned by root: %s\n' "${LOG_FILE}" >&2
  exit 1
fi
touch -- "${LOG_FILE}"
chown root:root "${LOG_FILE}"
chmod 0640 "${LOG_FILE}"
exec > >(tee -a -- "${LOG_FILE}") 2>&1

CURRENT_STEP='initialization'
FAIL_REPORTED=0
RUN_DIR=''
STAGED_CERT=''
STAGED_KEY=''
ROLLBACK_ARMED=0

ts()      { date '+[ %Y-%m-%dT%H:%M:%S%z ]'; }
step()    { CURRENT_STEP=$1; printf '\n%s ==> %s\n' "$(ts)" "$1"; }
info()    { printf '%s     %s\n' "$(ts)" "$1"; }
debug()   { [[ "${DEBUG}" -eq 1 ]] && printf '%s DEBUG %s\n' "$(ts)" "$1" || true; }
success() { printf '%s OK %s\n' "$(ts)" "$1"; }
warn()    { printf '%s WARN %s\n' "$(ts)" "$1" >&2; }
fail()    { FAIL_REPORTED=1; printf '%s ERROR %s\n' "$(ts)" "$1" >&2; exit 1; }

cleanup() {
  local rc=$?
  set +e
  trap - EXIT
  if [[ "${ROLLBACK_ARMED}" -eq 1 ]] && declare -F restore_previous_files >/dev/null 2>&1; then
    restore_previous_files
  fi
  [[ -n "${STAGED_CERT}" ]] && rm -f -- "${STAGED_CERT}"
  [[ -n "${STAGED_KEY}" ]] && rm -f -- "${STAGED_KEY}"
  if [[ -n "${RUN_DIR}" ]]; then
    case "${RUN_DIR}" in
      /tmp/keyvault-cert-renewal.*) rm -rf -- "${RUN_DIR}" ;;
      *) printf '%s ERROR Refusing to clean unexpected temporary path: %s\n' "$(ts)" "${RUN_DIR}" >&2 ;;
    esac
  fi
  exit "${rc}"
}

on_error() {
  local rc=$?
  local line=${BASH_LINENO[0]:-${LINENO}}
  local command=${BASH_COMMAND:-unknown}
  command=${command//$'\n'/ }
  if [[ "${FAIL_REPORTED}" -eq 0 ]]; then
    printf '%s ERROR Unexpected failure (exit %d) during "%s" at line %s: %s\n' \
      "$(ts)" "${rc}" "${CURRENT_STEP}" "${line}" "${command}" >&2
  fi
  exit "${rc}"
}

on_signal() {
  local signal=$1
  warn "Received ${signal}; cleaning up and exiting"
  exit 130
}

trap cleanup EXIT
trap on_error ERR
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM
trap 'on_signal HUP' HUP

if [[ -L "${LOCK_FILE}" ]]; then
  fail "Refusing to use symlink as lock file: ${LOCK_FILE}"
fi
if [[ -e "${LOCK_FILE}" && ! -f "${LOCK_FILE}" ]]; then
  fail "Lock path exists but is not a regular file: ${LOCK_FILE}"
fi
if [[ -e "${LOCK_FILE}" && "$(stat -c '%u' -- "${LOCK_FILE}")" -ne 0 ]]; then
  fail "Refusing to use lock file not owned by root: ${LOCK_FILE}"
fi
exec {LOCK_FD}>"${LOCK_FILE}"
chmod 0600 "${LOCK_FILE}"
if ! flock -n "${LOCK_FD}"; then
  info 'Another renewal run already holds the lock; exiting successfully'
  exit 0
fi

RUN_DIR=$(mktemp -d '/tmp/keyvault-cert-renewal.XXXXXXXX')
readonly RUN_DIR
AZ_STDERR_FILE="${RUN_DIR}/az.stderr"
: > "${AZ_STDERR_FILE}"

# Use an isolated Azure CLI profile. This prevents a cached human/service-principal
# session from silently replacing the intended managed identity, and prevents the
# renewal job from persisting access tokens after it exits.
export AZURE_CONFIG_DIR="${RUN_DIR}/azure-cli"
export AZURE_CORE_COLLECT_TELEMETRY=no
export AZURE_EXTENSION_USE_DYNAMIC_INSTALL=no
mkdir -m 0700 -- "${AZURE_CONFIG_DIR}"

AZ_OUTPUT=''
AZ_STDERR=''
az_call() {
  local rc started elapsed
  started=$(date +%s)
  if [[ "${DEBUG}" -eq 1 ]]; then
    local quoted_command='az'
    local arg
    for arg in "$@"; do
      printf -v quoted_command '%s %q' "${quoted_command}" "${arg}"
    done
    debug "Running: ${quoted_command} --only-show-errors"
  fi

  : > "${AZ_STDERR_FILE}"
  if AZ_OUTPUT=$(az "$@" --only-show-errors 2>"${AZ_STDERR_FILE}"); then
    rc=0
  else
    rc=$?
  fi
  AZ_STDERR=$(<"${AZ_STDERR_FILE}")
  : > "${AZ_STDERR_FILE}"
  elapsed=$(( $(date +%s) - started ))
  debug "Azure CLI exit=${rc}, duration=${elapsed}s, stdout_bytes=${#AZ_OUTPUT}, stderr_bytes=${#AZ_STDERR}"
  return "${rc}"
}

az_error() {
  local text=${AZ_STDERR:-no error detail returned}
  text=${text//$'\r'/}
  printf '%.2000s' "${text}"
}

validate_vault_name() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9-]{1,22}[A-Za-z0-9]$ ]]
}

validate_certificate_name() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,126}$ ]]
}

valid_dns_name() {
  local name=$1
  [[ ${#name} -le 253 ]] || return 1
  [[ "${name}" =~ ^(\*\.)?([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]
}

dns_pattern_matches() {
  local pattern=${1,,}
  local host=${2,,}
  pattern=${pattern%.}
  host=${host%.}

  [[ "${pattern}" == "${host}" ]] && return 0
  [[ "${pattern}" == '*.'* ]] || return 1
  [[ "${host}" != '*.'* ]] || return 1

  local base=${pattern#*.}
  [[ "${host}" == *."${base}" ]] || return 1
  local left=${host%."${base}"}
  [[ -n "${left}" && "${left}" != *.* ]]
}

IMDS_DISCOVERY_ERROR=''
DISCOVERED_IDENTITY_RESOURCE_ID=''
discover_user_assigned_identity() {
  local response_file="${RUN_DIR}/imds-identity-response.json"
  local error_file="${RUN_DIR}/imds-identity-error.txt"
  local http_code curl_rc response token payload_b64 payload
  local client_id identity_resource_id user_identity_resource_id remainder

  : > "${response_file}"
  : > "${error_file}"
  if http_code=$(curl --silent --show-error --noproxy '*' \
    --connect-timeout 2 --max-time 10 \
    --header 'Metadata:true' \
    --get \
    --data-urlencode 'api-version=2018-02-01' \
    --data-urlencode "resource=${ARM_RESOURCE}" \
    --output "${response_file}" \
    --write-out '%{http_code}' \
    'http://169.254.169.254/metadata/identity/oauth2/token' \
    2>"${error_file}"); then
    curl_rc=0
  else
    curl_rc=$?
  fi

  if [[ "${curl_rc}" -ne 0 ]]; then
    IMDS_DISCOVERY_ERROR="IMDS request failed: $(<"${error_file}")"
    return 1
  fi

  response=$(<"${response_file}")
  : > "${response_file}"
  if [[ "${http_code}" != '200' ]]; then
    response=${response//$'\r'/ }
    response=${response//$'\n'/ }
    IMDS_DISCOVERY_ERROR="IMDS returned HTTP ${http_code}: ${response:0:500}"
    unset response
    return 1
  fi

  # The response is trusted VM-local IMDS JSON. Extract only the JWT, never log
  # it, and immediately discard the original response.
  token=$(sed -nE 's/.*"access_token"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' <<<"${response}")
  unset response
  if [[ -z "${token}" ]]; then
    IMDS_DISCOVERY_ERROR='IMDS returned HTTP 200 without a parseable access token'
    return 1
  fi

  remainder=${token#*.}
  if [[ "${remainder}" == "${token}" || "${remainder}" != *.* ]]; then
    unset token remainder
    IMDS_DISCOVERY_ERROR='IMDS returned a malformed access token'
    return 1
  fi
  payload_b64=${remainder%%.*}
  unset token remainder
  payload_b64=${payload_b64//-/+}
  payload_b64=${payload_b64//_/\/}
  case $(( ${#payload_b64} % 4 )) in
    0) ;;
    2) payload_b64+='==' ;;
    3) payload_b64+='=' ;;
    *) unset payload_b64; IMDS_DISCOVERY_ERROR='IMDS returned an invalid JWT payload'; return 1 ;;
  esac

  if ! payload=$(printf '%s' "${payload_b64}" | base64 --decode 2>/dev/null); then
    unset payload_b64
    IMDS_DISCOVERY_ERROR='Could not decode the IMDS token payload'
    return 1
  fi
  unset payload_b64

  client_id=$(sed -nE 's/.*"appid"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' <<<"${payload}")
  if [[ -z "${client_id}" ]]; then
    client_id=$(sed -nE 's/.*"azp"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' <<<"${payload}")
  fi
  identity_resource_id=$(sed -nE 's/.*"xms_mirid"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' <<<"${payload}")
  user_identity_resource_id=$(sed -nE 's/.*"xms_az_rid"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' <<<"${payload}")
  unset payload

  # UAMI tokens identify a Microsoft.ManagedIdentity/userAssignedIdentities
  # resource. A VM resource ID indicates that IMDS selected the system identity.
  if [[ "${user_identity_resource_id,,}" == */providers/microsoft.managedidentity/userassignedidentities/* ]]; then
    DISCOVERED_IDENTITY_RESOURCE_ID=${user_identity_resource_id}
  elif [[ "${identity_resource_id,,}" == */providers/microsoft.managedidentity/userassignedidentities/* ]]; then
    DISCOVERED_IDENTITY_RESOURCE_ID=${identity_resource_id}
  else
    unset client_id identity_resource_id user_identity_resource_id
    IMDS_DISCOVERY_ERROR='IMDS did not select a user-assigned identity. If the VM also has a system-assigned identity, set AZURE_CLIENT_ID to the required UAMI client ID.'
    return 1
  fi

  if [[ ! "${client_id}" =~ ${UUID_REGEX} ]]; then
    unset client_id
    IMDS_DISCOVERY_ERROR='The selected UAMI token did not contain a valid client ID'
    return 1
  fi

  AZURE_CLIENT_ID=${client_id}
  unset client_id identity_resource_id user_identity_resource_id
  return 0
}

required_commands=(
  awk base64 cat chmod chown cp curl cut date find grep install mkdir mv openssl rm
  sed sha256sum sort stat systemctl tail touch tr
)

step 'Checking prerequisites'
for required_command in "${required_commands[@]}"; do
  command -v "${required_command}" >/dev/null 2>&1 || fail "Required command not found: ${required_command}"
done
if ! command -v az >/dev/null 2>&1; then
  fail 'Azure CLI is not installed. Provision it through your OS/package-management process before running this privileged renewal job.'
fi
if ! date -d '@0' +%s >/dev/null 2>&1; then
  fail 'GNU date is required (date -d is unavailable)'
fi
debug "Bash version: ${BASH_VERSION}"
if az_call version --query '"azure-cli"' -o tsv; then
  info "Azure CLI version: ${AZ_OUTPUT}"
fi
success 'Prerequisites available'

step 'Ensuring log rotation'
if command -v logrotate >/dev/null 2>&1; then
  [[ ! -L "${LOGROTATE_CONF}" ]] || fail "Refusing to replace symlink: ${LOGROTATE_CONF}"
  LOGROTATE_TMP="${RUN_DIR}/logrotate.conf"
  cat > "${LOGROTATE_TMP}" <<EOF
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
  install -o root -g root -m 0644 -- "${LOGROTATE_TMP}" "${LOGROTATE_CONF}"
  success "Log rotation configured: ${LOGROTATE_CONF}"
else
  warn 'logrotate is not installed; the renewal log will not be rotated by this script'
fi

step 'Detecting web server'
WEBSERVER=''
SITES_ENABLED_DIR=''
SERVER_DIRECTIVE_REGEX=''
APACHE_CTL=''
SERVICE_NAME=''

if [[ "${WEB_SERVER}" == 'nginx' ]] || { [[ "${WEB_SERVER}" == 'auto' ]] && command -v nginx >/dev/null 2>&1; }; then
  command -v nginx >/dev/null 2>&1 || fail 'WEB_SERVER=nginx was requested, but nginx was not found'
  WEBSERVER='nginx'
  SERVICE_NAME='nginx'
  SERVER_DIRECTIVE_REGEX='server_name'
  if [[ -n "${CONFIG_DIR}" ]]; then
    SITES_ENABLED_DIR=${CONFIG_DIR}
  elif [[ -d /etc/nginx/sites-enabled ]]; then
    SITES_ENABLED_DIR='/etc/nginx/sites-enabled'
  else
    SITES_ENABLED_DIR='/etc/nginx/conf.d'
  fi
elif [[ "${WEB_SERVER}" == 'apache' ]] || [[ "${WEB_SERVER}" == 'auto' ]]; then
  if command -v apache2ctl >/dev/null 2>&1; then
    APACHE_CTL=$(command -v apache2ctl)
    SERVICE_NAME='apache2'
  elif command -v httpd >/dev/null 2>&1; then
    APACHE_CTL=$(command -v httpd)
    SERVICE_NAME='httpd'
  else
    fail 'Neither nginx nor Apache was found'
  fi
  WEBSERVER='apache'
  SERVER_DIRECTIVE_REGEX='Server(Name|Alias)'
  if [[ -n "${CONFIG_DIR}" ]]; then
    SITES_ENABLED_DIR=${CONFIG_DIR}
  elif [[ -d /etc/apache2/sites-enabled ]]; then
    SITES_ENABLED_DIR='/etc/apache2/sites-enabled'
  else
    SITES_ENABLED_DIR='/etc/httpd/conf.d'
  fi
fi

[[ -d "${SITES_ENABLED_DIR}" ]] || fail "Web-server config directory not found: ${SITES_ENABLED_DIR} (set CONFIG_DIR to override)"
success "Detected ${WEBSERVER}; scanning ${SITES_ENABLED_DIR}"

webserver_test() {
  if [[ "${WEBSERVER}" == 'nginx' ]]; then
    nginx -t
  else
    "${APACHE_CTL}" configtest
  fi
}

webserver_reload() {
  systemctl reload "${SERVICE_NAME}"
}

step "Collecting server names from ${SITES_ENABLED_DIR}"
raw_server_lines=$(grep -RhsiE "^[[:space:]]*${SERVER_DIRECTIVE_REGEX}[[:space:]]+" "${SITES_ENABLED_DIR}" 2>/dev/null || true)
[[ -n "${raw_server_lines}" ]] || fail "No ${SERVER_DIRECTIVE_REGEX} directives found under ${SITES_ENABLED_DIR}"

declare -a SERVER_NAMES=()
declare -A SERVER_NAME_SEEN=()
while IFS= read -r config_line; do
  config_line=${config_line%%#*}
  config_line=${config_line%%;*}
  config_line=$(sed -E "s/^[[:space:]]*${SERVER_DIRECTIVE_REGEX}[[:space:]]+//I" <<<"${config_line}")
  IFS=$' \t' read -r -a config_names <<<"${config_line}"
  for server_name in "${config_names[@]}"; do
    server_name=${server_name#\"}; server_name=${server_name%\"}
    server_name=${server_name#\'}; server_name=${server_name%\'}
    server_name=${server_name,,}
    server_name=${server_name%.}
    [[ -n "${server_name}" ]] || continue
    if ! valid_dns_name "${server_name}"; then
      debug "Skipping unsupported/non-DNS server name token: ${server_name}"
      continue
    fi
    if [[ -z "${SERVER_NAME_SEEN[${server_name}]+set}" ]]; then
      SERVER_NAME_SEEN[${server_name}]=1
      SERVER_NAMES+=("${server_name}")
    fi
  done
done <<<"${raw_server_lines}"

[[ "${#SERVER_NAMES[@]}" -gt 0 ]] || fail "No valid DNS server names found under ${SITES_ENABLED_DIR}"
success "Found ${#SERVER_NAMES[@]} unique DNS server name(s)"
for server_name in "${SERVER_NAMES[@]}"; do
  info "- ${server_name}"
done

step 'Authenticating to Azure with a user-assigned managed identity'
az_call cloud set --name "${AZURE_CLOUD}" --output none \
  || fail "Could not select Azure cloud '${AZURE_CLOUD}': $(az_error)"
az_call cloud show --name "${AZURE_CLOUD}" --query endpoints.resourceManager -o tsv \
  || fail "Could not read the Resource Manager endpoint for '${AZURE_CLOUD}': $(az_error)"
ARM_RESOURCE=${AZ_OUTPUT//$'\r'/}
[[ "${ARM_RESOURCE}" == https://* ]] \
  || fail "Azure cloud '${AZURE_CLOUD}' returned an invalid Resource Manager endpoint"

if [[ -n "${AZURE_CLIENT_ID}" ]]; then
  info "Using AZURE_CLIENT_ID override: ${AZURE_CLIENT_ID}"
else
  info 'AZURE_CLIENT_ID is empty; discovering the VM user-assigned identity through IMDS'
  discover_user_assigned_identity \
    || fail "Could not auto-discover an unambiguous VM user-assigned identity: ${IMDS_DISCOVERY_ERROR} Set AZURE_CLIENT_ID explicitly."
  info "Discovered UAMI client ID: ${AZURE_CLIENT_ID}"
  debug "Discovered UAMI resource ID: ${DISCOVERED_IDENTITY_RESOURCE_ID}"
fi
az_call login --identity --client-id "${AZURE_CLIENT_ID}" --allow-no-subscriptions --output none \
  || fail "User-assigned managed-identity login failed for client ID '${AZURE_CLIENT_ID}': $(az_error)"
if [[ -n "${AZURE_SUBSCRIPTION_ID}" ]]; then
  az_call account set --subscription "${AZURE_SUBSCRIPTION_ID}" \
    || fail "Could not select Azure subscription '${AZURE_SUBSCRIPTION_ID}': $(az_error)"
fi
az_call account show --query '{tenantId:tenantId,subscriptionId:id}' -o json \
  || fail "Managed-identity session validation failed: $(az_error)"
debug "Azure context: ${AZ_OUTPUT}"
success "Authenticated with user-assigned managed identity ${AZURE_CLIENT_ID} using an isolated Azure CLI profile"

step 'Locating Key Vault'
if [[ -n "${KEYVAULT_NAME}" ]]; then
  validate_vault_name "${KEYVAULT_NAME}" || fail "Invalid Key Vault name: ${KEYVAULT_NAME}"
  info 'Using KEYVAULT_NAME override'
else
  az_call keyvault list --query '[].name' -o tsv \
    || fail "Could not list Key Vaults: $(az_error)"
  mapfile -t KEYVAULTS < <(printf '%s\n' "${AZ_OUTPUT}" | tr -d '\r' | sed '/^$/d' | sort -u)
  if [[ "${#KEYVAULTS[@]}" -eq 0 ]]; then
    fail 'No Key Vault was found in the selected subscription'
  elif [[ "${#KEYVAULTS[@]}" -gt 1 ]]; then
    fail "More than one Key Vault was found (${KEYVAULTS[*]}). Set KEYVAULT_NAME explicitly."
  fi
  KEYVAULT_NAME=${KEYVAULTS[0]}
  validate_vault_name "${KEYVAULT_NAME}" || fail "Azure returned an invalid Key Vault name: ${KEYVAULT_NAME}"
fi
success "Using Key Vault: ${KEYVAULT_NAME}"

declare -A CERT_SAN_CACHE=()
declare -A CERT_SAN_LOADED=()

load_certificate_sans() {
  local name=$1 normalized
  az_call keyvault certificate show --vault-name "${KEYVAULT_NAME}" --name "${name}" \
    --query 'policy.x509CertificateProperties.subjectAlternativeNames.dnsNames' -o tsv || return $?
  normalized=$(printf '%s\n' "${AZ_OUTPUT}" | tr '\t\r' '\n\n' | sed '/^$/d' | tr '[:upper:]' '[:lower:]' | sort -u)
  CERT_SAN_CACHE["${name}"]=${normalized}
  CERT_SAN_LOADED["${name}"]=1
}

certificate_covers_server() {
  local cert_name=$1 server_name=$2 san
  while IFS= read -r san; do
    [[ -n "${san}" ]] || continue
    dns_pattern_matches "${san}" "${server_name}" && return 0
  done <<<"${CERT_SAN_CACHE[${cert_name}]:-}"
  return 1
}

declare -a SELECTED_CERTS=()
declare -A SELECTED_CERT_SEEN=()
declare -A CERT_SERVER_LIST=()

add_certificate_mapping() {
  local cert_name=$1 server_name=$2
  if [[ -z "${CERT_SERVER_LIST[${cert_name}]:-}" ]]; then
    CERT_SERVER_LIST["${cert_name}"]=${server_name}
  else
    CERT_SERVER_LIST["${cert_name}"]+=$'\n'"${server_name}"
  fi
  if [[ -z "${SELECTED_CERT_SEEN[${cert_name}]+set}" ]]; then
    SELECTED_CERT_SEEN["${cert_name}"]=1
    SELECTED_CERTS+=("${cert_name}")
  fi
}

step 'Mapping server names to Key Vault certificates'
if [[ -n "${CERT_NAME}" ]]; then
  validate_certificate_name "${CERT_NAME}" || fail "Invalid Key Vault certificate name: ${CERT_NAME}"
  load_certificate_sans "${CERT_NAME}" \
    || fail "Could not inspect certificate '${CERT_NAME}': $(az_error)"
  override_match_count=0
  for server_name in "${SERVER_NAMES[@]}"; do
    if certificate_covers_server "${CERT_NAME}" "${server_name}"; then
      add_certificate_mapping "${CERT_NAME}" "${server_name}"
      override_match_count=$(( override_match_count + 1 ))
    fi
  done
  (( override_match_count > 0 )) \
    || fail "Certificate override '${CERT_NAME}' does not cover any configured server name"
  info 'Using CERT_NAME override'
else
  if ! az_call keyvault certificate list --vault-name "${KEYVAULT_NAME}" --query '[].name' -o tsv; then
    if [[ "${AZ_STDERR}" == *CERTIFICATE_VERIFY_FAILED* || "${AZ_STDERR}" == *'Hostname mismatch'* ]]; then
      warn "Key Vault TLS hostname validation failed. Check DNS/private-endpoint routing and HTTPS_PROXY; do not disable certificate verification."
    fi
    fail "Could not list certificates in '${KEYVAULT_NAME}': $(az_error)"
  fi
  mapfile -t VAULT_CERT_NAMES < <(printf '%s\n' "${AZ_OUTPUT}" | tr -d '\r' | sed '/^$/d' | sort -u)
  [[ "${#VAULT_CERT_NAMES[@]}" -gt 0 ]] || fail "No certificates found in '${KEYVAULT_NAME}'"

  for vault_cert_name in "${VAULT_CERT_NAMES[@]}"; do
    if ! validate_certificate_name "${vault_cert_name}"; then
      warn "Ignoring certificate with unexpected name: ${vault_cert_name}"
      continue
    fi
    if ! load_certificate_sans "${vault_cert_name}"; then
      warn "Could not inspect certificate '${vault_cert_name}'; enable DEBUG=1 for command diagnostics"
      debug "Azure error for '${vault_cert_name}': $(az_error)"
    fi
  done

  for server_name in "${SERVER_NAMES[@]}"; do
    expected_cert_name=${server_name//./-}
    declare -a server_candidates=()
    for vault_cert_name in "${VAULT_CERT_NAMES[@]}"; do
      [[ "${CERT_SAN_LOADED[${vault_cert_name}]:-0}" -eq 1 ]] || continue
      if certificate_covers_server "${vault_cert_name}" "${server_name}"; then
        server_candidates+=("${vault_cert_name}")
      fi
    done

    if [[ "${#server_candidates[@]}" -eq 0 ]]; then
      fail "No Key Vault certificate covers configured server name '${server_name}'"
    fi

    selected_for_server=''
    for candidate in "${server_candidates[@]}"; do
      if [[ "${candidate}" == "${expected_cert_name}" ]]; then
        selected_for_server=${candidate}
        break
      fi
    done

    if [[ -z "${selected_for_server}" ]]; then
      if [[ "${#server_candidates[@]}" -eq 1 ]]; then
        selected_for_server=${server_candidates[0]}
      else
        fail "Multiple certificates cover '${server_name}' (${server_candidates[*]}), and none is named '${expected_cert_name}'. Set CERT_NAME explicitly or make the mapping unambiguous."
      fi
    fi

    add_certificate_mapping "${selected_for_server}" "${server_name}"
    success "Mapped ${server_name} -> ${selected_for_server}"
  done
fi

[[ "${#SELECTED_CERTS[@]}" -gt 0 ]] || fail 'No certificates selected'
success "Selected ${#SELECTED_CERTS[@]} certificate object(s)"
for selected_cert_name in "${SELECTED_CERTS[@]}"; do
  info "- ${selected_cert_name}"
done

declare -a UPDATED_CERTS=()
declare -A HAD_CERT_BY_CERT=()
declare -A HAD_KEY_BY_CERT=()
declare -A BACKUP_DIR_BY_CERT=()

restore_previous_files() {
  local cert_name cert_dir cert_file key_file backup_dir restore_stage
  warn 'Restoring all certificate files changed by this run'
  for cert_name in "${UPDATED_CERTS[@]}"; do
    cert_dir="/etc/ssl/${cert_name}"
    cert_file="${cert_dir}/fullchain.crt"
    key_file="${cert_dir}/privkey.key"
    backup_dir=${BACKUP_DIR_BY_CERT[${cert_name}]:-}

    if [[ "${HAD_CERT_BY_CERT[${cert_name}]:-0}" -eq 1 ]]; then
      restore_stage=$(mktemp "${cert_dir}/.restore-cert.XXXXXXXX")
      install -o root -g root -m 0644 -- "${backup_dir}/fullchain.crt" "${restore_stage}"
      mv -f -- "${restore_stage}" "${cert_file}"
    else
      rm -f -- "${cert_file}"
    fi

    if [[ "${HAD_KEY_BY_CERT[${cert_name}]:-0}" -eq 1 ]]; then
      restore_stage=$(mktemp "${cert_dir}/.restore-key.XXXXXXXX")
      install -o root -g root -m 0600 -- "${backup_dir}/privkey.key" "${restore_stage}"
      mv -f -- "${restore_stage}" "${key_file}"
    else
      rm -f -- "${key_file}"
    fi
    warn "Restored previous files for ${cert_name}"
  done
  ROLLBACK_ARMED=0
}

process_certificate() {
  local cert_name=$1
  local cert_dir="/etc/ssl/${cert_name}"
  local cert_file="${cert_dir}/fullchain.crt"
  local key_file="${cert_dir}/privkey.key"
  local vault_der="${RUN_DIR}/${cert_name}.vault.der"
  local tmp_pfx="${RUN_DIR}/${cert_name}.pfx"
  local tmp_cert="${RUN_DIR}/${cert_name}.fullchain.pem"
  local tmp_key="${RUN_DIR}/${cert_name}.private-key.pem"
  local vault_cert_info vault_start_date vault_expiry_date vault_fingerprint
  local start_epoch expiry_epoch now_epoch expiry_days
  local local_fingerprint='' local_pair_valid=0
  local local_cert_key_hash='' local_private_key_hash=''
  local pfx_content_type openssl_error downloaded_fingerprint
  local cert_public_key_hash private_public_key_hash
  local concrete_host_count=0 mapped_server_name
  local had_cert=0 had_key=0 backup_dir=''
  local staged_cert staged_key

  if [[ -L "${cert_dir}" ]]; then
    fail "Refusing to use symlink as certificate directory: ${cert_dir}"
  fi
  if [[ -e "${cert_dir}" && ! -d "${cert_dir}" ]]; then
    fail "Certificate path exists but is not a directory: ${cert_dir}"
  fi
  for destination in "${cert_file}" "${key_file}"; do
    [[ ! -L "${destination}" ]] || fail "Refusing to replace symlink: ${destination}"
  done

  step "Checking certificate status: ${cert_name}"
  info "Certificate path: ${cert_file}"
  info "Private-key path: ${key_file}"

  az_call keyvault certificate show --vault-name "${KEYVAULT_NAME}" --name "${cert_name}" --query cer -o tsv \
    || fail "Could not read public certificate '${cert_name}': $(az_error)"
  [[ -n "${AZ_OUTPUT}" ]] || fail "Certificate '${cert_name}' returned no public certificate data"
  if ! printf '%s' "${AZ_OUTPUT}" | base64 --decode > "${vault_der}"; then
    AZ_OUTPUT=''
    fail "Certificate '${cert_name}' contains invalid base64 public-certificate data"
  fi
  AZ_OUTPUT=''

  if ! vault_cert_info=$(openssl x509 -inform DER -in "${vault_der}" -noout \
    -startdate -enddate -fingerprint -sha256 2>&1); then
    fail "Could not parse Key Vault public certificate '${cert_name}': ${vault_cert_info}"
  fi
  vault_start_date=$(grep -i '^notBefore=' <<<"${vault_cert_info}" | cut -d= -f2- || true)
  vault_expiry_date=$(grep -i '^notAfter=' <<<"${vault_cert_info}" | cut -d= -f2- || true)
  vault_fingerprint=$(grep -i '^sha256 Fingerprint=' <<<"${vault_cert_info}" | cut -d= -f2- || true)
  [[ -n "${vault_start_date}" && -n "${vault_expiry_date}" && -n "${vault_fingerprint}" ]] \
    || fail "Could not parse validity or fingerprint for '${cert_name}'"

  start_epoch=$(date -d "${vault_start_date}" +%s) \
    || fail "Could not parse certificate start date: ${vault_start_date}"
  expiry_epoch=$(date -d "${vault_expiry_date}" +%s) \
    || fail "Could not parse certificate expiry date: ${vault_expiry_date}"
  now_epoch=$(date +%s)
  (( now_epoch >= start_epoch )) || fail "Certificate '${cert_name}' is not valid until ${vault_start_date}"
  (( now_epoch < expiry_epoch )) || fail "Certificate '${cert_name}' expired at ${vault_expiry_date}"
  expiry_days=$(( (expiry_epoch - now_epoch) / 86400 ))
  info "Expires ${vault_expiry_date} (${expiry_days} days remaining)"
  if (( expiry_days < EXPIRY_WARN_DAYS )); then
    warn "Certificate '${cert_name}' expires in fewer than ${EXPIRY_WARN_DAYS} days"
  fi

  # Validate every concrete mapping against the issued certificate, not just the
  # Key Vault policy. This also protects the no-op path when files are current.
  while IFS= read -r mapped_server_name; do
    [[ -n "${mapped_server_name}" ]] || continue
    [[ "${mapped_server_name}" == '*.'* ]] && continue
    concrete_host_count=$(( concrete_host_count + 1 ))
    openssl x509 -inform DER -in "${vault_der}" -noout -checkhost "${mapped_server_name}" >/dev/null 2>&1 \
      || fail "Certificate '${cert_name}' does not cover mapped server name '${mapped_server_name}'"
  done <<<"${CERT_SERVER_LIST[${cert_name}]:-}"
  if [[ "${concrete_host_count}" -eq 0 ]]; then
    warn "Could not validate a concrete hostname for '${cert_name}'; relying on Key Vault SAN policy"
  fi

  if [[ -f "${cert_file}" ]]; then
    if local_fingerprint=$(openssl x509 -in "${cert_file}" -noout -fingerprint -sha256 2>/dev/null \
      | grep -i '^sha256 Fingerprint=' | cut -d= -f2-); then
      debug "Local fingerprint for ${cert_name}: ${local_fingerprint}"
    else
      local_fingerprint=''
      warn "Existing local certificate for '${cert_name}' is unreadable or invalid"
    fi
  fi

  if [[ "${vault_fingerprint}" == "${local_fingerprint}" && -f "${key_file}" ]]; then
    if local_cert_key_hash=$(openssl x509 -in "${cert_file}" -pubkey -noout 2>/dev/null \
      | openssl pkey -pubin -outform DER 2>/dev/null \
      | sha256sum | awk '{print $1}') \
      && local_private_key_hash=$(openssl pkey -in "${key_file}" -pubout -outform DER 2>/dev/null \
      | sha256sum | awk '{print $1}') \
      && [[ -n "${local_cert_key_hash}" && "${local_cert_key_hash}" == "${local_private_key_hash}" ]]; then
      local_pair_valid=1
    fi
  fi

  if [[ "${vault_fingerprint}" == "${local_fingerprint}" && "${local_pair_valid}" -eq 1 ]]; then
    success "Certificate '${cert_name}' and private key are already current"
    return 0
  elif [[ "${vault_fingerprint}" == "${local_fingerprint}" ]]; then
    warn "Certificate '${cert_name}' is current, but its private key is missing, unreadable, or mismatched; reinstalling"
  fi

  mkdir -p -- "${cert_dir}"
  chown root:root "${cert_dir}"
  chmod 0750 "${cert_dir}"

  step "Downloading and validating certificate: ${cert_name}"
  az_call keyvault secret show --vault-name "${KEYVAULT_NAME}" --name "${cert_name}" --query contentType -o tsv \
    || fail "Could not inspect certificate secret '${cert_name}': $(az_error)"
  pfx_content_type=${AZ_OUTPUT//$'\r'/}
  [[ "${pfx_content_type}" == 'application/x-pkcs12' ]] \
    || fail "Certificate secret '${cert_name}' has unsupported content type '${pfx_content_type:-unset}'; expected application/x-pkcs12"

  az_call keyvault secret show --vault-name "${KEYVAULT_NAME}" --name "${cert_name}" --query value -o tsv \
    || fail "Could not download certificate secret '${cert_name}': $(az_error)"
  [[ -n "${AZ_OUTPUT}" ]] || fail "Certificate secret '${cert_name}' returned an empty value"
  if ! printf '%s' "${AZ_OUTPUT}" | base64 --decode > "${tmp_pfx}"; then
    AZ_OUTPUT=''
    fail "Certificate secret '${cert_name}' is not valid base64"
  fi
  AZ_OUTPUT=''
  chmod 0600 "${tmp_pfx}"

  if ! openssl_error=$(openssl pkcs12 -in "${tmp_pfx}" -nokeys -passin pass: -out "${tmp_cert}" 2>&1); then
    fail "Could not extract certificate chain from PFX '${cert_name}': ${openssl_error}"
  fi
  if ! openssl_error=$(openssl pkcs12 -in "${tmp_pfx}" -nocerts -nodes -passin pass: -out "${tmp_key}" 2>&1); then
    fail "Could not extract private key from PFX '${cert_name}': ${openssl_error}"
  fi
  chmod 0600 "${tmp_cert}" "${tmp_key}"
  rm -f -- "${tmp_pfx}"

  downloaded_fingerprint=$(openssl x509 -in "${tmp_cert}" -noout -fingerprint -sha256 \
    | grep -i '^sha256 Fingerprint=' | cut -d= -f2-) \
    || fail "Could not fingerprint downloaded certificate '${cert_name}'"
  [[ "${downloaded_fingerprint}" == "${vault_fingerprint}" ]] \
    || fail "Downloaded PFX leaf for '${cert_name}' does not match its Key Vault certificate object"

  cert_public_key_hash=$(openssl x509 -in "${tmp_cert}" -pubkey -noout \
    | openssl pkey -pubin -outform DER 2>/dev/null \
    | sha256sum | awk '{print $1}') \
    || fail "Could not derive public key from certificate '${cert_name}'"
  private_public_key_hash=$(openssl pkey -in "${tmp_key}" -pubout -outform DER 2>/dev/null \
    | sha256sum | awk '{print $1}') \
    || fail "Could not derive public key from private key '${cert_name}'"
  [[ -n "${cert_public_key_hash}" && "${cert_public_key_hash}" == "${private_public_key_hash}" ]] \
    || fail "Downloaded certificate and private key do not match for '${cert_name}'"

  success "Validated certificate, validity, hostname, fingerprint, and private key for '${cert_name}'"

  [[ -f "${cert_file}" ]] && had_cert=1
  [[ -f "${key_file}" ]] && had_key=1
  HAD_CERT_BY_CERT["${cert_name}"]=${had_cert}
  HAD_KEY_BY_CERT["${cert_name}"]=${had_key}
  BACKUP_DIR_BY_CERT["${cert_name}"]=''

  if [[ "${had_cert}" -eq 1 || "${had_key}" -eq 1 ]]; then
    backup_dir=$(mktemp -d "${cert_dir}/backup-$(date '+%Y%m%d%H%M%S')-XXXXXXXX")
    chmod 0700 "${backup_dir}"
    [[ "${had_cert}" -eq 1 ]] && cp -p -- "${cert_file}" "${backup_dir}/fullchain.crt"
    [[ "${had_key}" -eq 1 ]] && cp -p -- "${key_file}" "${backup_dir}/privkey.key"
    BACKUP_DIR_BY_CERT["${cert_name}"]=${backup_dir}
    info "Previous files backed up to ${backup_dir}"
  fi

  STAGED_CERT=$(mktemp "${cert_dir}/.fullchain.crt.XXXXXXXX")
  STAGED_KEY=$(mktemp "${cert_dir}/.privkey.key.XXXXXXXX")
  install -o root -g root -m 0644 -- "${tmp_cert}" "${STAGED_CERT}"
  install -o root -g root -m 0600 -- "${tmp_key}" "${STAGED_KEY}"

  UPDATED_CERTS+=("${cert_name}")
  ROLLBACK_ARMED=1
  mv -f -- "${STAGED_CERT}" "${cert_file}"
  STAGED_CERT=''
  mv -f -- "${STAGED_KEY}" "${key_file}"
  STAGED_KEY=''
  success "Installed staged certificate files for '${cert_name}'"
}

for selected_cert_name in "${SELECTED_CERTS[@]}"; do
  process_certificate "${selected_cert_name}"
done

step "Testing ${WEBSERVER} configuration"
if ! WEB_TEST_OUTPUT=$(webserver_test 2>&1); then
  if [[ "${#UPDATED_CERTS[@]}" -gt 0 ]]; then
    restore_previous_files
  fi
  fail "${WEBSERVER} configuration test failed: ${WEB_TEST_OUTPUT}"
fi

if [[ "${#UPDATED_CERTS[@]}" -eq 0 ]]; then
  success "All ${#SELECTED_CERTS[@]} selected certificate(s) are current and ${WEBSERVER} configuration is valid"
  exit 0
fi

step "Reloading ${WEBSERVER}"
if ! RELOAD_OUTPUT=$(webserver_reload 2>&1); then
  restore_previous_files
  if webserver_test >/dev/null 2>&1; then
    webserver_reload >/dev/null 2>&1 || warn 'Could not reload the web server after rollback; manual intervention is required'
  fi
  fail "${WEBSERVER} reload failed; all files changed by this run were restored: ${RELOAD_OUTPUT}"
fi
ROLLBACK_ARMED=0
success "${WEBSERVER} configuration tested and service reloaded"

for selected_cert_name in "${UPDATED_CERTS[@]}"; do
  cert_dir="/etc/ssl/${selected_cert_name}"
  mapfile -t OLD_BACKUPS < <(find "${cert_dir}" -maxdepth 1 -mindepth 1 -type d -name 'backup-*' -print | sort -r | tail -n +6)
  for old_backup in "${OLD_BACKUPS[@]}"; do
    [[ -n "${old_backup}" ]] && rm -rf -- "${old_backup}"
  done
done

step 'Done'
success "Installed ${#UPDATED_CERTS[@]} certificate update(s) and reloaded ${WEBSERVER} successfully"

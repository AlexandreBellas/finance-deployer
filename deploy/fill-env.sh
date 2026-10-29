#!/usr/bin/env bash
# Write the .env from the environment. The workflow passes
# INVESTMENTS_* GitHub secrets. This script does not contain config values.
set -euo pipefail

output="${1:?Usage: fill-env.sh OUTPUT_PATH}"

clean() {
  local name="$1"
  if [[ ! -v "${name}" ]]; then
    return 0
  fi
  local -n ref="${name}"
  local value="${ref}"
  while [[ "${value}" == *$'\n' || "${value}" == *$'\r' ]]; do
    value="${value%$'\n'}"
    value="${value%$'\r'}"
  done
  ref="${value}"
}

require_set() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing GitHub secret: ${name}" >&2
    return 1
  fi
}

missing=0
while read -r name; do
  [[ -z "${name}" ]] && continue
  clean "${name}"
  require_set "${name}" || missing=1
done <<'NAMES'
INVESTMENTS_FTP_SERVER
INVESTMENTS_FTP_USERNAME
INVESTMENTS_FTP_PASSWORD
INVESTMENTS_SSH_REMOTE_HOST
INVESTMENTS_SSH_REMOTE_USER
INVESTMENTS_SSH_REMOTE_PASSWORD
INVESTMENTS_SSH_REMOTE_PORT
INVESTMENTS_SSH_REMOTE_PATH
INVESTMENTS_PHP_BIN
INVESTMENTS_APP_NAME
INVESTMENTS_APP_ENV
INVESTMENTS_APP_KEY
INVESTMENTS_APP_DEBUG
INVESTMENTS_APP_URL
INVESTMENTS_ASSET_URL
INVESTMENTS_APP_TIMEZONE
INVESTMENTS_APP_LOCALE
INVESTMENTS_SELF_HOSTED
INVESTMENTS_REGISTRATION_ENABLED
INVESTMENTS_AI_CHAT_ENABLED
INVESTMENTS_LOG_CHANNEL
INVESTMENTS_LOG_LEVEL
INVESTMENTS_FILESYSTEM_DISK
INVESTMENTS_SESSION_DRIVER
INVESTMENTS_QUEUE_CONNECTION
INVESTMENTS_CACHE_STORE
INVESTMENTS_DB_CONNECTION
INVESTMENTS_DB_HOST
INVESTMENTS_DB_PORT
INVESTMENTS_DB_DATABASE
INVESTMENTS_DB_USERNAME
INVESTMENTS_DB_PASSWORD
INVESTMENTS_MARKET_DATA_PROVIDER
INVESTMENTS_MARKET_DATA_REFRESH
INVESTMENTS_BASE_CURRENCY
INVESTMENTS_MAIL_MAILER
INVESTMENTS_MAIL_FROM_ADDRESS
INVESTMENTS_MAIL_FROM_NAME
NAMES

optional_names=(
  INVESTMENTS_DAILY_CHANGE_TIME
  INVESTMENTS_ALPHAVANTAGE_API_KEY
  INVESTMENTS_FINNHUB_API_KEY
  INVESTMENTS_ALPACA_API_KEY
  INVESTMENTS_ALPACA_API_SECRET
  INVESTMENTS_TWELVEDATA_API_SECRET
  INVESTMENTS_CHAT_PROVIDER
  INVESTMENTS_CHAT_MODEL
  INVESTMENTS_OPENAI_API_KEY
  INVESTMENTS_MAIL_HOST
  INVESTMENTS_MAIL_PORT
  INVESTMENTS_MAIL_USERNAME
  INVESTMENTS_MAIL_PASSWORD
  INVESTMENTS_MAIL_ENCRYPTION
)
for name in "${optional_names[@]}"; do
  clean "${name}"
done

if [[ "${missing}" -ne 0 ]]; then
  exit 1
fi

fail() {
  echo "$1" >&2
  exit 1
}

[[ "${INVESTMENTS_APP_ENV}" == "production" ]] || fail "Set INVESTMENTS_APP_ENV to production."
[[ "${INVESTMENTS_APP_DEBUG}" == "false" ]] || fail "Set INVESTMENTS_APP_DEBUG to false."
[[ "${INVESTMENTS_APP_KEY}" =~ ^base64:[A-Za-z0-9+/]{43}=$ ]] || fail "INVESTMENTS_APP_KEY must be a Laravel key from: php artisan key:generate --show"
[[ "${INVESTMENTS_APP_URL}" == https://* ]] || fail "INVESTMENTS_APP_URL must start with https://"
[[ "${INVESTMENTS_ASSET_URL}" == https://* ]] || fail "INVESTMENTS_ASSET_URL must start with https://"
[[ "${INVESTMENTS_SELF_HOSTED}" == "true" ]] || fail "Set INVESTMENTS_SELF_HOSTED to true."
[[ "${INVESTMENTS_REGISTRATION_ENABLED}" == "true" || "${INVESTMENTS_REGISTRATION_ENABLED}" == "false" ]] || fail "Set INVESTMENTS_REGISTRATION_ENABLED to true or false."
[[ "${INVESTMENTS_AI_CHAT_ENABLED}" == "true" || "${INVESTMENTS_AI_CHAT_ENABLED}" == "false" ]] || fail "Set INVESTMENTS_AI_CHAT_ENABLED to true or false."
[[ "${INVESTMENTS_SESSION_DRIVER}" == "file" ]] || fail "Set INVESTMENTS_SESSION_DRIVER to file. Shared hosting has no Redis, and this release has no sessions table."
[[ "${INVESTMENTS_CACHE_STORE}" == "file" ]] || fail "Set INVESTMENTS_CACHE_STORE to file. Shared hosting has no Redis, and this release has no cache table."
[[ "${INVESTMENTS_QUEUE_CONNECTION}" == "sync" ]] || fail "Set INVESTMENTS_QUEUE_CONNECTION to sync. Shared hosting has no queue worker, and this release has no jobs table."
[[ "${INVESTMENTS_FILESYSTEM_DISK}" == "local" ]] || fail "Set INVESTMENTS_FILESYSTEM_DISK to local."
[[ "${INVESTMENTS_DB_CONNECTION}" == "mysql" || "${INVESTMENTS_DB_CONNECTION}" == "mariadb" ]] || fail "Set INVESTMENTS_DB_CONNECTION to mysql or mariadb."
[[ "${INVESTMENTS_DB_PORT}" =~ ^[0-9]+$ ]] || fail "INVESTMENTS_DB_PORT must be numeric."
[[ "${INVESTMENTS_SSH_REMOTE_PORT}" =~ ^[0-9]+$ ]] || fail "INVESTMENTS_SSH_REMOTE_PORT must be numeric."
[[ "${INVESTMENTS_SSH_REMOTE_PATH}" == /* ]] || fail "INVESTMENTS_SSH_REMOTE_PATH must be an absolute path."
[[ "${INVESTMENTS_PHP_BIN}" == /* ]] || fail "INVESTMENTS_PHP_BIN must be an absolute path."
[[ "${INVESTMENTS_MARKET_DATA_REFRESH}" =~ ^[0-9]+$ ]] || fail "INVESTMENTS_MARKET_DATA_REFRESH must be a number of minutes."
[[ "${INVESTMENTS_BASE_CURRENCY}" =~ ^[A-Z]{3}$ ]] || fail "INVESTMENTS_BASE_CURRENCY must be a 3-letter ISO code, such as USD or BRL."

case "${INVESTMENTS_MAIL_MAILER}" in
  log|smtp|sendmail) ;;
  *) fail "INVESTMENTS_MAIL_MAILER must be log, smtp, or sendmail." ;;
esac
if [[ "${INVESTMENTS_MAIL_MAILER}" == "smtp" ]]; then
  smtp_missing=0
  for name in INVESTMENTS_MAIL_HOST INVESTMENTS_MAIL_PORT INVESTMENTS_MAIL_USERNAME INVESTMENTS_MAIL_PASSWORD; do
    require_set "${name}" || smtp_missing=1
  done
  if [[ "${smtp_missing}" -ne 0 ]]; then
    exit 1
  fi
  [[ "${INVESTMENTS_MAIL_PORT}" =~ ^[0-9]+$ ]] || fail "INVESTMENTS_MAIL_PORT must be numeric."
fi

quote_into() {
  local dest="$1"
  local key="$2"
  local value="$3"
  if [[ "${value}" == *$'\n'* || "${value}" == *$'\r'* ]]; then
    fail "INVESTMENTS_${key} contains a newline."
  fi
  if [[ "${value}" == *"'"* ]]; then
    fail "INVESTMENTS_${key} contains a single quote. Choose a value without one."
  fi
  printf -v "${dest}" "'%s'" "${value}"
}

write() {
  local key="$1"
  local value="$2"
  local quoted
  quote_into quoted "${key}" "${value}"
  printf '%s=%s\n' "${key}" "${quoted}" >> "${output}"
}

write_optional() {
  local key="$1"
  local value="$2"
  if [[ -n "${value}" ]]; then
    write "${key}" "${value}"
  fi
}

umask 077
: > "${output}"

write APP_NAME "${INVESTMENTS_APP_NAME}"
write APP_ENV "${INVESTMENTS_APP_ENV}"
write APP_KEY "${INVESTMENTS_APP_KEY}"
write APP_DEBUG "${INVESTMENTS_APP_DEBUG}"
write APP_URL "${INVESTMENTS_APP_URL}"
write ASSET_URL "${INVESTMENTS_ASSET_URL}"
write APP_TIMEZONE "${INVESTMENTS_APP_TIMEZONE}"
write APP_LOCALE "${INVESTMENTS_APP_LOCALE}"
write SELF_HOSTED "${INVESTMENTS_SELF_HOSTED}"
write REGISTRATION_ENABLED "${INVESTMENTS_REGISTRATION_ENABLED}"
write AI_CHAT_ENABLED "${INVESTMENTS_AI_CHAT_ENABLED}"
write LOG_CHANNEL "${INVESTMENTS_LOG_CHANNEL}"
write LOG_LEVEL "${INVESTMENTS_LOG_LEVEL}"
write FILESYSTEM_DISK "${INVESTMENTS_FILESYSTEM_DISK}"
write SESSION_DRIVER "${INVESTMENTS_SESSION_DRIVER}"
write QUEUE_CONNECTION "${INVESTMENTS_QUEUE_CONNECTION}"
write CACHE_STORE "${INVESTMENTS_CACHE_STORE}"
write DB_CONNECTION "${INVESTMENTS_DB_CONNECTION}"
write DB_HOST "${INVESTMENTS_DB_HOST}"
write DB_PORT "${INVESTMENTS_DB_PORT}"
write DB_DATABASE "${INVESTMENTS_DB_DATABASE}"
write DB_USERNAME "${INVESTMENTS_DB_USERNAME}"
write DB_PASSWORD "${INVESTMENTS_DB_PASSWORD}"
write MARKET_DATA_PROVIDER "${INVESTMENTS_MARKET_DATA_PROVIDER}"
write MARKET_DATA_REFRESH "${INVESTMENTS_MARKET_DATA_REFRESH}"
write BASE_CURRENCY "${INVESTMENTS_BASE_CURRENCY}"
write MAIL_MAILER "${INVESTMENTS_MAIL_MAILER}"
write MAIL_FROM_ADDRESS "${INVESTMENTS_MAIL_FROM_ADDRESS}"
write MAIL_FROM_NAME "${INVESTMENTS_MAIL_FROM_NAME}"

write_optional DAILY_CHANGE_TIME "${INVESTMENTS_DAILY_CHANGE_TIME:-}"
write_optional ALPHAVANTAGE_API_KEY "${INVESTMENTS_ALPHAVANTAGE_API_KEY:-}"
write_optional FINNHUB_API_KEY "${INVESTMENTS_FINNHUB_API_KEY:-}"
write_optional ALPACA_API_KEY "${INVESTMENTS_ALPACA_API_KEY:-}"
write_optional ALPACA_API_SECRET "${INVESTMENTS_ALPACA_API_SECRET:-}"
write_optional TWELVEDATA_API_SECRET "${INVESTMENTS_TWELVEDATA_API_SECRET:-}"
write_optional CHAT_PROVIDER "${INVESTMENTS_CHAT_PROVIDER:-}"
write_optional CHAT_MODEL "${INVESTMENTS_CHAT_MODEL:-}"
write_optional OPENAI_API_KEY "${INVESTMENTS_OPENAI_API_KEY:-}"
write_optional MAIL_HOST "${INVESTMENTS_MAIL_HOST:-}"
write_optional MAIL_PORT "${INVESTMENTS_MAIL_PORT:-}"
write_optional MAIL_USERNAME "${INVESTMENTS_MAIL_USERNAME:-}"
write_optional MAIL_PASSWORD "${INVESTMENTS_MAIL_PASSWORD:-}"
write_optional MAIL_ENCRYPTION "${INVESTMENTS_MAIL_ENCRYPTION:-}"

chmod 600 "${output}"
echo "Wrote ${output}"

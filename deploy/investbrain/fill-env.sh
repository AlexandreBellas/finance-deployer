#!/usr/bin/env bash
# Write Investbrain's .env from the environment. The workflow passes
# INVESTBRAIN_* GitHub secrets. This script does not contain config values.
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
INVESTBRAIN_FTP_SERVER
INVESTBRAIN_FTP_USERNAME
INVESTBRAIN_FTP_PASSWORD
INVESTBRAIN_SSH_REMOTE_HOST
INVESTBRAIN_SSH_REMOTE_USER
INVESTBRAIN_SSH_REMOTE_PASSWORD
INVESTBRAIN_SSH_REMOTE_PORT
INVESTBRAIN_SSH_REMOTE_PATH
INVESTBRAIN_PHP_BIN
INVESTBRAIN_APP_NAME
INVESTBRAIN_APP_ENV
INVESTBRAIN_APP_KEY
INVESTBRAIN_APP_DEBUG
INVESTBRAIN_APP_URL
INVESTBRAIN_ASSET_URL
INVESTBRAIN_APP_TIMEZONE
INVESTBRAIN_APP_LOCALE
INVESTBRAIN_SELF_HOSTED
INVESTBRAIN_REGISTRATION_ENABLED
INVESTBRAIN_AI_CHAT_ENABLED
INVESTBRAIN_LOG_CHANNEL
INVESTBRAIN_LOG_LEVEL
INVESTBRAIN_FILESYSTEM_DISK
INVESTBRAIN_SESSION_DRIVER
INVESTBRAIN_QUEUE_CONNECTION
INVESTBRAIN_CACHE_STORE
INVESTBRAIN_DB_CONNECTION
INVESTBRAIN_DB_HOST
INVESTBRAIN_DB_PORT
INVESTBRAIN_DB_DATABASE
INVESTBRAIN_DB_USERNAME
INVESTBRAIN_DB_PASSWORD
INVESTBRAIN_MARKET_DATA_PROVIDER
INVESTBRAIN_MARKET_DATA_REFRESH
INVESTBRAIN_BASE_CURRENCY
INVESTBRAIN_MAIL_MAILER
INVESTBRAIN_MAIL_FROM_ADDRESS
INVESTBRAIN_MAIL_FROM_NAME
NAMES

optional_names=(
  INVESTBRAIN_DAILY_CHANGE_TIME
  INVESTBRAIN_ALPHAVANTAGE_API_KEY
  INVESTBRAIN_FINNHUB_API_KEY
  INVESTBRAIN_ALPACA_API_KEY
  INVESTBRAIN_ALPACA_API_SECRET
  INVESTBRAIN_TWELVEDATA_API_SECRET
  INVESTBRAIN_CHAT_PROVIDER
  INVESTBRAIN_CHAT_MODEL
  INVESTBRAIN_OPENAI_API_KEY
  INVESTBRAIN_MAIL_HOST
  INVESTBRAIN_MAIL_PORT
  INVESTBRAIN_MAIL_USERNAME
  INVESTBRAIN_MAIL_PASSWORD
  INVESTBRAIN_MAIL_ENCRYPTION
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

[[ "${INVESTBRAIN_APP_ENV}" == "production" ]] || fail "Set INVESTBRAIN_APP_ENV to production."
[[ "${INVESTBRAIN_APP_DEBUG}" == "false" ]] || fail "Set INVESTBRAIN_APP_DEBUG to false."
[[ "${INVESTBRAIN_APP_KEY}" =~ ^base64:[A-Za-z0-9+/]{43}=$ ]] || fail "INVESTBRAIN_APP_KEY must be a Laravel key from: php artisan key:generate --show"
[[ "${INVESTBRAIN_APP_URL}" == https://* ]] || fail "INVESTBRAIN_APP_URL must start with https://"
[[ "${INVESTBRAIN_ASSET_URL}" == https://* ]] || fail "INVESTBRAIN_ASSET_URL must start with https://"
[[ "${INVESTBRAIN_SELF_HOSTED}" == "true" ]] || fail "Set INVESTBRAIN_SELF_HOSTED to true."
[[ "${INVESTBRAIN_REGISTRATION_ENABLED}" == "true" || "${INVESTBRAIN_REGISTRATION_ENABLED}" == "false" ]] || fail "Set INVESTBRAIN_REGISTRATION_ENABLED to true or false."
[[ "${INVESTBRAIN_AI_CHAT_ENABLED}" == "true" || "${INVESTBRAIN_AI_CHAT_ENABLED}" == "false" ]] || fail "Set INVESTBRAIN_AI_CHAT_ENABLED to true or false."
[[ "${INVESTBRAIN_SESSION_DRIVER}" == "file" ]] || fail "Set INVESTBRAIN_SESSION_DRIVER to file. Shared hosting has no Redis, and this release has no sessions table."
[[ "${INVESTBRAIN_CACHE_STORE}" == "file" ]] || fail "Set INVESTBRAIN_CACHE_STORE to file. Shared hosting has no Redis, and this release has no cache table."
[[ "${INVESTBRAIN_QUEUE_CONNECTION}" == "sync" ]] || fail "Set INVESTBRAIN_QUEUE_CONNECTION to sync. Shared hosting has no queue worker, and this release has no jobs table."
[[ "${INVESTBRAIN_FILESYSTEM_DISK}" == "local" ]] || fail "Set INVESTBRAIN_FILESYSTEM_DISK to local."
[[ "${INVESTBRAIN_DB_CONNECTION}" == "mysql" || "${INVESTBRAIN_DB_CONNECTION}" == "mariadb" ]] || fail "Set INVESTBRAIN_DB_CONNECTION to mysql or mariadb."
[[ "${INVESTBRAIN_DB_PORT}" =~ ^[0-9]+$ ]] || fail "INVESTBRAIN_DB_PORT must be numeric."
[[ "${INVESTBRAIN_SSH_REMOTE_PORT}" =~ ^[0-9]+$ ]] || fail "INVESTBRAIN_SSH_REMOTE_PORT must be numeric."
[[ "${INVESTBRAIN_SSH_REMOTE_PATH}" == /* ]] || fail "INVESTBRAIN_SSH_REMOTE_PATH must be an absolute path."
[[ "${INVESTBRAIN_PHP_BIN}" == /* ]] || fail "INVESTBRAIN_PHP_BIN must be an absolute path."
[[ "${INVESTBRAIN_MARKET_DATA_REFRESH}" =~ ^[0-9]+$ ]] || fail "INVESTBRAIN_MARKET_DATA_REFRESH must be a number of minutes."
[[ "${INVESTBRAIN_BASE_CURRENCY}" =~ ^[A-Z]{3}$ ]] || fail "INVESTBRAIN_BASE_CURRENCY must be a 3-letter ISO code, such as USD or BRL."

case "${INVESTBRAIN_MAIL_MAILER}" in
  log|smtp|sendmail) ;;
  *) fail "INVESTBRAIN_MAIL_MAILER must be log, smtp, or sendmail." ;;
esac
if [[ "${INVESTBRAIN_MAIL_MAILER}" == "smtp" ]]; then
  smtp_missing=0
  for name in INVESTBRAIN_MAIL_HOST INVESTBRAIN_MAIL_PORT INVESTBRAIN_MAIL_USERNAME INVESTBRAIN_MAIL_PASSWORD; do
    require_set "${name}" || smtp_missing=1
  done
  if [[ "${smtp_missing}" -ne 0 ]]; then
    exit 1
  fi
  [[ "${INVESTBRAIN_MAIL_PORT}" =~ ^[0-9]+$ ]] || fail "INVESTBRAIN_MAIL_PORT must be numeric."
fi

quote_into() {
  local dest="$1"
  local key="$2"
  local value="$3"
  if [[ "${value}" == *$'\n'* || "${value}" == *$'\r'* ]]; then
    fail "INVESTBRAIN_${key} contains a newline."
  fi
  if [[ "${value}" == *"'"* ]]; then
    fail "INVESTBRAIN_${key} contains a single quote. Choose a value without one."
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

write APP_NAME "${INVESTBRAIN_APP_NAME}"
write APP_ENV "${INVESTBRAIN_APP_ENV}"
write APP_KEY "${INVESTBRAIN_APP_KEY}"
write APP_DEBUG "${INVESTBRAIN_APP_DEBUG}"
write APP_URL "${INVESTBRAIN_APP_URL}"
write ASSET_URL "${INVESTBRAIN_ASSET_URL}"
write APP_TIMEZONE "${INVESTBRAIN_APP_TIMEZONE}"
write APP_LOCALE "${INVESTBRAIN_APP_LOCALE}"
write SELF_HOSTED "${INVESTBRAIN_SELF_HOSTED}"
write REGISTRATION_ENABLED "${INVESTBRAIN_REGISTRATION_ENABLED}"
write AI_CHAT_ENABLED "${INVESTBRAIN_AI_CHAT_ENABLED}"
write LOG_CHANNEL "${INVESTBRAIN_LOG_CHANNEL}"
write LOG_LEVEL "${INVESTBRAIN_LOG_LEVEL}"
write FILESYSTEM_DISK "${INVESTBRAIN_FILESYSTEM_DISK}"
write SESSION_DRIVER "${INVESTBRAIN_SESSION_DRIVER}"
write QUEUE_CONNECTION "${INVESTBRAIN_QUEUE_CONNECTION}"
write CACHE_STORE "${INVESTBRAIN_CACHE_STORE}"
write DB_CONNECTION "${INVESTBRAIN_DB_CONNECTION}"
write DB_HOST "${INVESTBRAIN_DB_HOST}"
write DB_PORT "${INVESTBRAIN_DB_PORT}"
write DB_DATABASE "${INVESTBRAIN_DB_DATABASE}"
write DB_USERNAME "${INVESTBRAIN_DB_USERNAME}"
write DB_PASSWORD "${INVESTBRAIN_DB_PASSWORD}"
write MARKET_DATA_PROVIDER "${INVESTBRAIN_MARKET_DATA_PROVIDER}"
write MARKET_DATA_REFRESH "${INVESTBRAIN_MARKET_DATA_REFRESH}"
write BASE_CURRENCY "${INVESTBRAIN_BASE_CURRENCY}"
write MAIL_MAILER "${INVESTBRAIN_MAIL_MAILER}"
write MAIL_FROM_ADDRESS "${INVESTBRAIN_MAIL_FROM_ADDRESS}"
write MAIL_FROM_NAME "${INVESTBRAIN_MAIL_FROM_NAME}"

write_optional DAILY_CHANGE_TIME "${INVESTBRAIN_DAILY_CHANGE_TIME:-}"
write_optional ALPHAVANTAGE_API_KEY "${INVESTBRAIN_ALPHAVANTAGE_API_KEY:-}"
write_optional FINNHUB_API_KEY "${INVESTBRAIN_FINNHUB_API_KEY:-}"
write_optional ALPACA_API_KEY "${INVESTBRAIN_ALPACA_API_KEY:-}"
write_optional ALPACA_API_SECRET "${INVESTBRAIN_ALPACA_API_SECRET:-}"
write_optional TWELVEDATA_API_SECRET "${INVESTBRAIN_TWELVEDATA_API_SECRET:-}"
write_optional CHAT_PROVIDER "${INVESTBRAIN_CHAT_PROVIDER:-}"
write_optional CHAT_MODEL "${INVESTBRAIN_CHAT_MODEL:-}"
write_optional OPENAI_API_KEY "${INVESTBRAIN_OPENAI_API_KEY:-}"
write_optional MAIL_HOST "${INVESTBRAIN_MAIL_HOST:-}"
write_optional MAIL_PORT "${INVESTBRAIN_MAIL_PORT:-}"
write_optional MAIL_USERNAME "${INVESTBRAIN_MAIL_USERNAME:-}"
write_optional MAIL_PASSWORD "${INVESTBRAIN_MAIL_PASSWORD:-}"
write_optional MAIL_ENCRYPTION "${INVESTBRAIN_MAIL_ENCRYPTION:-}"

chmod 600 "${output}"
echo "Wrote ${output}"

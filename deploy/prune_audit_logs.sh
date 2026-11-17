#!/usr/bin/env bash
# =============================================================================
#  SAN ANDREAS RP — ротация таблицы audit_logs в MySQL/MariaDB
#  Удаляет записи старше SARP_AUDIT_RETENTION_DAYS (по умолчанию 90 суток)
#  небольшими порциями, чтобы не блокировать игровой сервер длинной транзакцией.
#  Запускается ежедневно (см. deploy/sarp.cron).
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${SARP_ENV_FILE:-${ROOT}/.env}"
RETENTION_DAYS="${SARP_AUDIT_RETENTION_DAYS:-90}"
BATCH_SIZE="${SARP_AUDIT_DELETE_BATCH:-5000}"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "[audit-retention] ОШИБКА: не найден файл конфигурации ${ENV_FILE}" >&2
    exit 1
fi

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

: "${MYSQL_HOST:=127.0.0.1}"
: "${MYSQL_PORT:=3306}"
: "${MYSQL_USER:=sarp_server}"
: "${MYSQL_PASSWORD:=}"
: "${MYSQL_DATABASE:=san_andreas_rp}"

if ! command -v mysql >/dev/null 2>&1; then
    echo "[audit-retention] ОШИБКА: клиент mysql не найден в PATH" >&2
    exit 1
fi

total_deleted=0

while true; do
    batch_deleted="$(MYSQL_PWD="${MYSQL_PASSWORD}" mysql \
        --host="${MYSQL_HOST}" \
        --port="${MYSQL_PORT}" \
        --user="${MYSQL_USER}" \
        --database="${MYSQL_DATABASE}" \
        --batch \
        --skip-column-names \
        --execute="DELETE FROM audit_logs WHERE created_at < (NOW() - INTERVAL ${RETENTION_DAYS} DAY) LIMIT ${BATCH_SIZE}; SELECT ROW_COUNT();")"

    if [[ -z "${batch_deleted}" ]]; then
        batch_deleted=0
    fi

    total_deleted=$((total_deleted + batch_deleted))

    if (( batch_deleted < BATCH_SIZE )); then
        break
    fi
done

echo "[audit-retention] $(date '+%Y-%m-%d %H:%M:%S') удалено записей старше ${RETENTION_DAYS} суток: ${total_deleted}."

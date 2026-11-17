#!/usr/bin/env bash
# =============================================================================
#  SAN ANDREAS RP — резервное копирование базы данных MySQL/MariaDB
#  Запускается cron-задачей каждые 6 часов (см. deploy/sarp.cron).
#  Формат дампа: mysqldump --single-transaction --quick, архив gzip.
#  Срок хранения: 14 дней (переопределяется SARP_BACKUP_RETENTION_DAYS).
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${SARP_ENV_FILE:-${ROOT}/.env}"
BACKUP_DIR="${SARP_BACKUP_DIR:-${ROOT}/scriptfiles/backups}"
RETENTION_DAYS="${SARP_BACKUP_RETENTION_DAYS:-14}"
LOCK_FILE="${SARP_BACKUP_LOCK:-${BACKUP_DIR}/.backup.lock}"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "[backup] ОШИБКА: не найден файл конфигурации ${ENV_FILE}" >&2
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

if ! command -v mysqldump >/dev/null 2>&1; then
    echo "[backup] ОШИБКА: утилита mysqldump не найдена в PATH" >&2
    exit 1
fi

mkdir -p "${BACKUP_DIR}"
chmod 0700 "${BACKUP_DIR}"

exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
    echo "[backup] Предыдущая задача резервного копирования ещё выполняется, выход."
    exit 0
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
TARGET="${BACKUP_DIR}/sarp_${MYSQL_DATABASE}_${STAMP}.sql.gz"
TEMP_TARGET="${TARGET}.tmp"

umask 077
MYSQL_PWD="${MYSQL_PASSWORD}" mysqldump \
    --host="${MYSQL_HOST}" \
    --port="${MYSQL_PORT}" \
    --user="${MYSQL_USER}" \
    --single-transaction \
    --quick \
    --routines \
    --triggers \
    --events \
    --default-character-set=utf8mb4 \
    --databases "${MYSQL_DATABASE}" \
    | gzip -9 > "${TEMP_TARGET}"

if [[ ! -s "${TEMP_TARGET}" ]]; then
    rm -f "${TEMP_TARGET}"
    echo "[backup] ОШИБКА: получен пустой дамп, резервная копия не создана" >&2
    exit 1
fi

mv "${TEMP_TARGET}" "${TARGET}"
chmod 0600 "${TARGET}"

# Оставляем архивы за последние RETENTION_DAYS суток (по умолчанию 14).
find "${BACKUP_DIR}" -type f -name "sarp_${MYSQL_DATABASE}_*.sql.gz" \
    -mtime "+$((RETENTION_DAYS - 1))" -delete

echo "[backup] $(date '+%Y-%m-%d %H:%M:%S') создан архив ${TARGET} ($(du -h "${TARGET}" | cut -f1)); хранение ${RETENTION_DAYS} суток."

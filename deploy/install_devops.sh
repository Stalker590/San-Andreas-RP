#!/usr/bin/env bash
# =============================================================================
#  SAN ANDREAS RP — установка продакшн-окружения Linux (ROADMAP 9.3)
#  Создаёт системного пользователя, каталоги, systemd-юнит, задачи cron
#  и правило logrotate. Скрипт идемпотентен: повторный запуск безопасен.
#
#  Использование:
#      sudo ./deploy/install_devops.sh
#  Переопределяемые переменные:
#      SARP_DIR=/opt/san-andreas-rp SARP_USER=sarp
# =============================================================================
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "[install] ОШИБКА: запустите скрипт от имени root (sudo)." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SARP_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
APP_USER="${SARP_USER:-sarp}"
APP_GROUP="${SARP_GROUP:-${APP_USER}}"
UNIT_PATH="/etc/systemd/system/omp-server.service"
CRON_PATH="/etc/cron.d/sarp"
LOGROTATE_PATH="/etc/logrotate.d/sarp"

if [[ ! -x "${APP_DIR}/omp-server" ]]; then
    echo "[install] ОШИБКА: не найден исполняемый файл ${APP_DIR}/omp-server." >&2
    exit 1
fi

if ! getent group "${APP_GROUP}" >/dev/null 2>&1; then
    groupadd --system "${APP_GROUP}"
fi

if ! id "${APP_USER}" >/dev/null 2>&1; then
    useradd --system --gid "${APP_GROUP}" --home-dir "${APP_DIR}" \
        --shell /usr/sbin/nologin "${APP_USER}"
fi

install -d -m 0755 -o "${APP_USER}" -g "${APP_GROUP}" "${APP_DIR}/logs"
install -d -m 0700 -o "${APP_USER}" -g "${APP_GROUP}" "${APP_DIR}/scriptfiles/backups"

chown -R "${APP_USER}:${APP_GROUP}" "${APP_DIR}/logs" "${APP_DIR}/scriptfiles/backups"
chmod 0755 "${APP_DIR}/deploy/backup_mysql.sh" "${APP_DIR}/deploy/prune_audit_logs.sh"

sed -e "s|@APP_DIR@|${APP_DIR}|g" -e "s|@APP_USER@|${APP_USER}|g" \
    "${SCRIPT_DIR}/omp-server.service" > "${UNIT_PATH}"
chmod 0644 "${UNIT_PATH}"

sed -e "s|@APP_DIR@|${APP_DIR}|g" -e "s|@APP_USER@|${APP_USER}|g" \
    "${SCRIPT_DIR}/sarp.cron" > "${CRON_PATH}"
chmod 0644 "${CRON_PATH}"
chown root:root "${CRON_PATH}"

sed -e "s|@APP_DIR@|${APP_DIR}|g" -e "s|@APP_USER@|${APP_USER}|g" \
    "${SCRIPT_DIR}/logrotate-sarp" > "${LOGROTATE_PATH}"
chmod 0644 "${LOGROTATE_PATH}"
chown root:root "${LOGROTATE_PATH}"

systemctl daemon-reload
systemctl enable omp-server.service
systemctl restart omp-server.service

echo "[install] Готово."
echo "[install] Каталог сервера: ${APP_DIR}"
echo "[install] Пользователь:    ${APP_USER}:${APP_GROUP}"
echo "[install] systemd:         ${UNIT_PATH} (LimitNOFILE=65535)"
echo "[install] cron:            ${CRON_PATH} (бэкап каждые 6 часов, аудит ежедневно)"
echo "[install] logrotate:       ${LOGROTATE_PATH}"

#!/usr/bin/env bash
# =============================================================================
#  SAN ANDREAS RP — Docker Entrypoint (динамическая генерация конфигов и запуск)
#  Выполняет:
#  1. Подстановку переменных окружения (OMP_*) в config.json через jq.
#  2. Генерацию scriptfiles/mysql.ini и ./mysql.ini для BlueG MySQL R41-4.
#  3. Ожидание готовности MariaDB/MySQL (mysqladmin ping / TCP healthcheck).
#  4. Запуск ./omp-server через exec (PID 1 для корректной обработки SIGTERM).
# =============================================================================
set -euo pipefail

APP_DIR="${SARP_APP_DIR:-/opt/omp-server}"
cd "${APP_DIR}"

# -----------------------------------------------------------------------------
#  1. Значения по умолчанию из окружения (.env)
# -----------------------------------------------------------------------------
: "${MYSQL_HOST:=db}"
: "${MYSQL_PORT:=3306}"
: "${MYSQL_DATABASE:=san_andreas_rp}"
: "${MYSQL_USER:=sarp_server}"
: "${MYSQL_PASSWORD:=sarp_local_dev_password_2026}"
: "${MYSQL_CHARSET:=cp1251}"
: "${MYSQL_POOL_SIZE:=12}"
: "${MYSQL_WAIT_TIMEOUT:=60}"

: "${OMP_SERVER_NAME:=SAN ANDREAS RP | English Roleplay}"
: "${OMP_LANGUAGE:=English}"
: "${OMP_MAX_PLAYERS:=500}"
: "${OMP_PORT:=7777}"
: "${OMP_BIND_ADDRESS:=0.0.0.0}"
: "${OMP_RCON_ENABLE:=false}"
: "${OMP_RCON_PASSWORD:=change_rcon_secret_in_production}"
: "${OMP_ANNOUNCE:=false}"
: "${OMP_ENABLE_QUERY:=true}"
: "${OMP_SERVER_PASSWORD:=}"
: "${OMP_WEBSITE:=}"
: "${OMP_DISCORD_INVITE:=}"

mkdir -p "${APP_DIR}/scriptfiles" "${APP_DIR}/logs" "${APP_DIR}/scriptfiles/backups"

# -----------------------------------------------------------------------------
#  2. Обновление config.json через jq без нарушения JSON-структуры
# -----------------------------------------------------------------------------
CONFIG_FILE="${APP_DIR}/config.json"
CONFIG_TEMPLATE="${APP_DIR}/config.template.json"

if [[ -f "${CONFIG_TEMPLATE}" && ! -f "${CONFIG_FILE}" ]]; then
    cp "${CONFIG_TEMPLATE}" "${CONFIG_FILE}"
fi

if [[ -f "${CONFIG_FILE}" ]] && command -v jq >/dev/null 2>&1; then
    TEMP_JSON="$(mktemp "${APP_DIR}/config.json.XXXXXX")"
    jq \
        --arg name "${OMP_SERVER_NAME}" \
        --arg lang "${OMP_LANGUAGE}" \
        --arg bind "${OMP_BIND_ADDRESS}" \
        --arg rcon_pass "${OMP_RCON_PASSWORD}" \
        --arg srv_pass "${OMP_SERVER_PASSWORD}" \
        --arg website "${OMP_WEBSITE}" \
        --arg discord "${OMP_DISCORD_INVITE}" \
        --argjson max_players "${OMP_MAX_PLAYERS}" \
        --argjson port "${OMP_PORT}" \
        --argjson rcon_enable "${OMP_RCON_ENABLE}" \
        --argjson announce "${OMP_ANNOUNCE}" \
        --argjson enable_query "${OMP_ENABLE_QUERY}" \
        '.name = $name
         | .language = $lang
         | .max_players = $max_players
         | .network.port = $port
         | .network.bind = $bind
         | .artwork.port = $port
         | .rcon.enable = $rcon_enable
         | .rcon.password = $rcon_pass
         | .announce = $announce
         | .enable_query = $enable_query
         | .password = $srv_pass
         | .website = $website
         | .discord.invite = $discord' \
        "${CONFIG_FILE}" > "${TEMP_JSON}"
    mv "${TEMP_JSON}" "${CONFIG_FILE}"
    chmod 0640 "${CONFIG_FILE}"
    echo "[entrypoint] config.json updated (name='${OMP_SERVER_NAME}', port=${OMP_PORT}, max_players=${OMP_MAX_PLAYERS})."
fi

# -----------------------------------------------------------------------------
#  3. Генерация mysql.ini для плагина BlueG MySQL R41-4 и mod_database.pwn
#     Плагин mysql_connect_file("mysql.ini") и fopen("mysql.ini") читают из
#     scriptfiles/mysql.ini (или корневой рабочей директории).
# -----------------------------------------------------------------------------
write_mysql_ini() {
    local target_path="$1"
    cat > "${target_path}" <<EOF
hostname = ${MYSQL_HOST}
username = ${MYSQL_USER}
password = ${MYSQL_PASSWORD}
database = ${MYSQL_DATABASE}
server_port = ${MYSQL_PORT}
port = ${MYSQL_PORT}
pool_size = ${MYSQL_POOL_SIZE}
auto_reconnect = true
multi_statements = true
EOF
    chmod 0600 "${target_path}"
}

write_mysql_ini "${APP_DIR}/scriptfiles/mysql.ini"
write_mysql_ini "${APP_DIR}/mysql.ini"
echo "[entrypoint] Generated mysql.ini (${MYSQL_USER}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}, pool_size=${MYSQL_POOL_SIZE}, charset=${MYSQL_CHARSET})."

# -----------------------------------------------------------------------------
#  4. Ожидание готовности СУБД MariaDB/MySQL
# -----------------------------------------------------------------------------
if [[ "${SKIP_DB_WAIT:-0}" != "1" ]]; then
    echo "[entrypoint] Waiting for MariaDB/MySQL at ${MYSQL_HOST}:${MYSQL_PORT} (timeout: ${MYSQL_WAIT_TIMEOUT}s)..."
    elapsed=0
    db_ready=0
    while [[ "${elapsed}" -lt "${MYSQL_WAIT_TIMEOUT}" ]]; do
        if command -v mysqladmin >/dev/null 2>&1; then
            if MYSQL_PWD="${MYSQL_PASSWORD}" mysqladmin ping \
                --host="${MYSQL_HOST}" \
                --port="${MYSQL_PORT}" \
                --user="${MYSQL_USER}" \
                --connect-timeout=2 \
                --silent >/dev/null 2>&1; then
                db_ready=1
                break
            fi
        elif command -v mariadb-admin >/dev/null 2>&1; then
            if MYSQL_PWD="${MYSQL_PASSWORD}" mariadb-admin ping \
                --host="${MYSQL_HOST}" \
                --port="${MYSQL_PORT}" \
                --user="${MYSQL_USER}" \
                --connect-timeout=2 \
                --silent >/dev/null 2>&1; then
                db_ready=1
                break
            fi
        elif (echo >/dev/tcp/"${MYSQL_HOST}"/"${MYSQL_PORT}") >/dev/null 2>&1; then
            db_ready=1
            break
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    if [[ "${db_ready}" -eq 1 ]]; then
        echo "[entrypoint] Database ${MYSQL_HOST}:${MYSQL_PORT} is online and accepting connections."
    else
        echo "[entrypoint] [WARN] Database ${MYSQL_HOST}:${MYSQL_PORT} did not respond within ${MYSQL_WAIT_TIMEOUT}s; proceeding with startup." >&2
    fi
fi

# -----------------------------------------------------------------------------
#  5. Запуск сервера open.mp (или переданной команды)
# -----------------------------------------------------------------------------
if [[ $# -gt 0 ]]; then
    exec "$@"
else
    echo "[entrypoint] Starting open.mp server (./omp-server)..."
    exec ./omp-server
fi

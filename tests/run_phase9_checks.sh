#!/usr/bin/env bash
# =============================================================================
#  SAN ANDREAS RP — автоматическая проверка фазы 9 (ROADMAP 9.1–9.3)
#  1. Полная сборка ./build.sh (0 ошибок, 0 предупреждений).
#  2. Статические проверки ролей, предметов, экономики, античита и DevOps.
#  3. SQL-инварианты базы данных (если БД доступна; иначе SKIP).
#
#  Использование: ./tests/run_phase9_checks.sh
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}" || exit 1

failures=0
skipped=0

step_fail() {
    printf '  [FAIL] %s\n' "$1"
    failures=$((failures + 1))
}

step_ok() {
    printf '  [OK]   %s\n' "$1"
}

step_skip() {
    printf '  [SKIP] %s\n' "$1"
    skipped=$((skipped + 1))
}

echo "================================================================"
echo " SAN ANDREAS RP — проверки фазы 9"
echo "================================================================"

# -----------------------------------------------------------------------------
#  1. Сборка игрового режима
# -----------------------------------------------------------------------------
echo
echo "1. Сборка gamemodes/main.pwn"
build_log="$(mktemp)"
if ./build.sh >"${build_log}" 2>&1; then
    if grep -qiE '(^|[^a-z])(warning|error) [0-9]+' "${build_log}"; then
        step_fail "build.sh вернул предупреждения или ошибки"
        tail -40 "${build_log}"
    else
        step_ok "build.sh: 0 ошибок, 0 предупреждений"
    fi
else
    step_fail "build.sh завершился с ошибкой"
    tail -40 "${build_log}"
fi
rm -f "${build_log}"

# -----------------------------------------------------------------------------
#  2. Статические проверки исходников
# -----------------------------------------------------------------------------
echo
echo "2. Статические проверки исходников"
if python3 tests/phase9_static_checks.py; then
    step_ok "статические проверки пройдены"
else
    step_fail "статические проверки содержат ошибки"
fi

# -----------------------------------------------------------------------------
#  3. SQL-инварианты живой базы данных
# -----------------------------------------------------------------------------
echo
echo "3. SQL-инварианты базы данных"
ENV_FILE="${SARP_ENV_FILE:-${ROOT}/.env}"

if [[ ! -f "${ENV_FILE}" ]]; then
    step_skip "файл .env не найден — SQL-проверки пропущены"
elif ! command -v mysql >/dev/null 2>&1; then
    step_skip "клиент mysql не установлен — SQL-проверки пропущены"
else
    # shellcheck disable=SC1090
    set -a
    source "${ENV_FILE}"
    set +a

    : "${MYSQL_HOST:=127.0.0.1}"
    : "${MYSQL_PORT:=3306}"
    : "${MYSQL_USER:=sarp_server}"
    : "${MYSQL_PASSWORD:=}"
    : "${MYSQL_DATABASE:=san_andreas_rp}"

    if ! MYSQL_PWD="${MYSQL_PASSWORD}" mysql \
        --host="${MYSQL_HOST}" --port="${MYSQL_PORT}" --user="${MYSQL_USER}" \
        --database="${MYSQL_DATABASE}" --connect-timeout=3 \
        --batch --skip-column-names --execute="SELECT 1;" >/dev/null 2>&1; then
        step_skip "база данных ${MYSQL_DATABASE} недоступна — SQL-проверки пропущены"
    else
        sql_error_file="$(mktemp)"
        sql_output="$(MYSQL_PWD="${MYSQL_PASSWORD}" mysql \
            --host="${MYSQL_HOST}" --port="${MYSQL_PORT}" --user="${MYSQL_USER}" \
            --database="${MYSQL_DATABASE}" --batch --skip-column-names \
            < tests/phase9_invariants.sql 2>"${sql_error_file}")"
        sql_status=$?

        if [[ ${sql_status} -ne 0 ]]; then
            step_fail "ошибка выполнения SQL-инвариантов: $(cat "${sql_error_file}")"
        else
            sql_failures=0
            while IFS=$'\t' read -r check_name violations; do
                [[ -z "${check_name}" ]] && continue
                if [[ ! "${violations}" =~ ^[0-9]+$ ]]; then
                    continue
                fi
                if [[ "${violations}" != "0" ]]; then
                    printf '  [FAIL] %s: %s нарушений\n' "${check_name}" "${violations}"
                    sql_failures=$((sql_failures + 1))
                fi
            done <<< "${sql_output}"

            if [[ ${sql_failures} -eq 0 ]]; then
                step_ok "все SQL-инварианты соблюдены (0 нарушений)"
            else
                failures=$((failures + sql_failures))
            fi
        fi
        rm -f "${sql_error_file}"
    fi
fi

# -----------------------------------------------------------------------------
#  4. Итог
# -----------------------------------------------------------------------------
echo
echo "================================================================"
if [[ ${failures} -eq 0 ]]; then
    echo " ИТОГ: ФАЗА 9 ПРОЙДЕНА (пропущено проверок: ${skipped})"
    echo "================================================================"
    exit 0
else
    echo " ИТОГ: ОБНАРУЖЕНО ОШИБОК: ${failures} (пропущено проверок: ${skipped})"
    echo "================================================================"
    exit 1
fi

#!/usr/bin/env bash
# =============================================================================
#  SAN ANDREAS RP — сборка игрового режима gamemodes/main.pwn -> main.amx
#  Флаги компилятора берутся из qawno/pawn.cfg (-O2 -d1 -;+ -(+ -t4 -E):
#  pawncc читает этот файл автоматически, поэтому CLI и GUI qawno
#  собирают проект с одинаковыми параметрами.
#
#  Перед компиляцией проверяется, что все исходники проекта сохранены
#  в Windows-1251 (CP1251), а не в UTF-8: иначе кириллица в клиенте
#  GTA SA / open.mp превратится в «кракозябры».
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QAWNO_DIR="${ROOT}/qawno"
PAWNCC="${QAWNO_DIR}/pawncc"
GM_DIR="${ROOT}/gamemodes"
MODULES_DIR="${GM_DIR}/modules"
ENTRY="${GM_DIR}/main.pwn"
OUTPUT_BASE="${GM_DIR}/main"

if [[ ! -x "${PAWNCC}" ]]; then
    echo "[build] ОШИБКА: компилятор не найден: ${PAWNCC}" >&2
    exit 1
fi

if [[ ! -f "${QAWNO_DIR}/pawn.cfg" ]]; then
    echo "[build] ОШИБКА: отсутствует ${QAWNO_DIR}/pawn.cfg с флагами сборки" >&2
    exit 1
fi

if [[ ! -f "${ENTRY}" ]]; then
    echo "[build] ОШИБКА: точка входа не найдена: ${ENTRY}" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
#  1. Контроль кодировки исходников (CP1251, без BOM)
# -----------------------------------------------------------------------------
encoding_errors=0
while IFS= read -r -d '' src; do
    if [[ "$(head -c 3 "${src}" | od -An -tx1 | tr -d ' \n')" == "efbbbf" ]]; then
        echo "[build] ОШИБКА КОДИРОВКИ: ${src#"${ROOT}/"} содержит UTF-8 BOM. Пересохраните файл в Windows-1251." >&2
        encoding_errors=1
        continue
    fi
    if LC_ALL=C grep -q $'[\x80-\xff]' "${src}"; then
        if iconv -f UTF-8 -t UTF-8 "${src}" >/dev/null 2>&1; then
            echo "[build] ОШИБКА КОДИРОВКИ: ${src#"${ROOT}/"} сохранён в UTF-8. Пересохраните файл в Windows-1251." >&2
            encoding_errors=1
        fi
    fi
done < <(
    {
        printf '%s\0' "${ENTRY}"
        if [[ -d "${MODULES_DIR}" ]]; then
            find "${MODULES_DIR}" -type f \( -name '*.pwn' -o -name '*.inc' \) -print0
        fi
    }
)

if [[ "${encoding_errors}" -ne 0 ]]; then
    echo "[build] Сборка прервана: исправьте кодировку файлов." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
#  2. Компиляция
# -----------------------------------------------------------------------------
cd "${ROOT}"
echo "[build] Компиляция ${ENTRY#"${ROOT}/"} ..."

set +e
compile_log="$(
    LD_LIBRARY_PATH="${QAWNO_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
    "${PAWNCC}" "${ENTRY}" \
        "-o${OUTPUT_BASE}" \
        "-i${QAWNO_DIR}/include" \
        "-i${GM_DIR}" \
        "-i${MODULES_DIR}" 2>&1
)"
compile_status=$?
set -e

printf '%s\n' "${compile_log}"

if [[ "${compile_status}" -ne 0 ]] || grep -qiE '(^|[^a-z])(warning|error) [0-9]+' <<<"${compile_log}"; then
    echo "[build] СБОРКА НЕ ПРОЙДЕНА: компилятор вернул ошибки или предупреждения (код ${compile_status})." >&2
    exit 1
fi

echo "[build] Готово: ${OUTPUT_BASE#"${ROOT}/"}.amx (0 ошибок, 0 предупреждений)."

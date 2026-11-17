#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SAN ANDREAS RP — статические проверки фазы 9 (ROADMAP 9.2 / 9.3).

Скрипт не требует запуска игрового сервера: он проверяет исходники,
конфигурацию сборки и наличие обязательных элементов античита.
Запускается из tests/run_phase9_checks.sh.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODULES = ROOT / "gamemodes" / "modules"

passed = 0
failed = 0


def ok(message: str) -> None:
    global passed
    passed += 1
    print(f"  [OK]   {message}")


def fail(message: str) -> None:
    global failed
    failed += 1
    print(f"  [FAIL] {message}")


def read(path: Path) -> str:
    return path.read_bytes().decode("cp1251", errors="replace")


def check_encoding() -> None:
    bad = []
    for path in sorted(MODULES.rglob("*.pwn")):
        raw = path.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            bad.append(f"{path.relative_to(ROOT)}: UTF-8 BOM")
            continue
        try:
            raw.decode("utf-8")
            has_cyrillic = any(0x80 <= byte <= 0xFF for byte in raw)
            if has_cyrillic:
                bad.append(f"{path.relative_to(ROOT)}: UTF-8 вместо Windows-1251")
        except UnicodeDecodeError:
            pass
    if bad:
        fail("кодировка исходников: " + "; ".join(bad))
    else:
        ok("все .pwn сохранены в Windows-1251 без BOM")


def extract_entries(text: str, marker: str) -> list[str]:
    start = text.find(marker)
    if start < 0:
        return []
    brace = text.find("{", start)
    if brace < 0:
        return []
    depth = 0
    end = -1
    for index in range(brace, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                end = index
                break
    if end < 0:
        return []
    body = text[brace + 1:end]
    entries = []
    depth = 0
    current: list[str] = []
    for char in body:
        if char == "{":
            depth += 1
            if depth == 1:
                current = []
                continue
        elif char == "}":
            if depth == 1:
                entries.append("".join(current))
            depth -= 1
            continue
        if depth >= 1:
            current.append(char)
    return entries


def check_roles() -> None:
    text = read(MODULES / "entities" / "mod_roles.pwn")
    entries = extract_entries(text, "stock const gRoleConfigs")
    if len(entries) != 25:
        fail(f"реестр ролей: найдено {len(entries)} записей вместо 25")
        return

    ids: list[int] = []
    names: list[str] = []
    for entry in entries:
        match = re.search(r"(\d+)\s*,\s*\"([^\"]+)\"", entry)
        if not match:
            fail("реестр ролей: не удалось прочитать ID/название записи")
            return
        ids.append(int(match.group(1)))
        names.append(match.group(2))

    if ids != list(range(1, 26)):
        fail(f"реестр ролей: идентификаторы не 1..25: {ids}")
    elif len(set(names)) != 25 or any(not name.strip() for name in names):
        fail("реестр ролей: пустые или повторяющиеся названия")
    else:
        ok("25 стартовых ролей: ID 1..25, названия уникальны")


def check_items() -> None:
    text = read(MODULES / "entities" / "mod_items.pwn")
    entries = extract_entries(text, "static stock const sBuiltinItemDefs")
    if len(entries) != 91:
        fail(f"реестр предметов: найдено {len(entries)} записей вместо 91")
        return

    ids: list[int] = []
    codes: list[str] = []
    for entry in entries:
        match = re.search(r"true\s*,\s*(\d+)\s*,\s*\"([^\"]+)\"", entry)
        if not match:
            fail("реестр предметов: не удалось прочитать ID/код записи")
            return
        ids.append(int(match.group(1)))
        codes.append(match.group(2))

    if ids != list(range(1, 92)):
        fail(f"реестр предметов: идентификаторы не 1..91: {ids}")
    elif len(set(codes)) != 91:
        fail("реестр предметов: повторяющиеся code_name")
    else:
        ok("91 предмет: ID 1..91, code_name уникальны")


def check_ports() -> None:
    text = read(MODULES / "systems" / "mod_ports.pwn")
    owner = re.search(r"#define\s+PORT_EXPORT_OWNER_PERCENT\s+\((\d+)\)", text)
    trucker = re.search(r"#define\s+PORT_EXPORT_TRUCKER_PERCENT\s+\((\d+)\)", text)
    if not owner or not trucker:
        fail("порты: не найдены константы распределения экспортной выручки")
        return
    owner_value = int(owner.group(1))
    trucker_value = int(trucker.group(1))
    if owner_value != 90 or trucker_value != 5 or owner_value + trucker_value > 100:
        fail(f"порты: неверное распределение {owner_value}/{trucker_value}/остаток")
    else:
        ok("порты: распределение экспортной выручки 90% / 5% / 5%")


def check_zero_faucet() -> None:
    crafting = read(MODULES / "systems" / "mod_crafting.pwn")
    logistics = read(MODULES / "systems" / "mod_logistics.pwn")

    if "Enterprise_TakeReserve" not in crafting:
        fail("Zero-Faucet: добыча не списывает выплаты из reserve_usd предприятия")
    elif not re.search(r"reserve_usd`\s*>=\s*%d", crafting):
        fail("Zero-Faucet: SQL-списание резерва без защиты reserve_usd >= payout")
    elif "Enterprise_TakeReserve" not in logistics:
        fail("Zero-Faucet: логистика не списывает оплату из резерва предприятия")
    else:
        ok("Zero-Faucet: выплаты шахтёрам и логистике идут из reserve_usd с проверкой остатка")


def check_anticheat() -> None:
    path = MODULES / "core" / "mod_anticheat.pwn"
    if not path.exists():
        fail("античит: отсутствует core/mod_anticheat.pwn")
        return

    text = read(path)
    required = {
        "IPacket:207": "перехват OnFoot-синхронизации",
        "IPacket:200": "перехват InCar-синхронизации",
        "IPacket:203": "перехват Aim-синхронизации",
        "IPacket:204": "перехват обновления оружия/патронов",
        "OnPlayerCommandReceived": "фильтрация флуда командами",
        "Internal_CheckDialogFlood": "фильтрация флуда диалогами",
        "BanEx": "блокировка нарушителя",
        "Audit_Log": "запись нарушения в audit_logs",
        "AC_MarkServerTeleport": "учёт серверных телепортов",
        "Internal_RunIntegrationTests": "автоматические тесты 9.2",
    }
    missing = [description for marker, description in required.items() if marker not in text]
    if missing:
        fail("античит: отсутствуют элементы — " + ", ".join(missing))
        return

    main = read(ROOT / "gamemodes" / "main.pwn")
    ac_pos = main.find('mod_anticheat.pwn"')
    ui_pos = main.find('mod_commands.pwn"')
    if ac_pos < 0:
        fail("античит: модуль не подключён в main.pwn")
    elif ui_pos < 0 or ac_pos < ui_pos:
        fail("античит: модуль должен подключаться последним (после ui/)")
    else:
        ok("античит: 4 сетевых пакета, флуд, бан, аудит и серверные телепорты на месте")


def check_no_stubs() -> None:
    pattern = re.compile(r"(?://|/\*|\*)\s*(TODO|FIXME)\b|реализовать позже|остальной код аналогично", re.IGNORECASE)
    hits = []
    for path in sorted(MODULES.rglob("*.pwn")):
        for number, line in enumerate(read(path).splitlines(), start=1):
            if pattern.search(line):
                hits.append(f"{path.relative_to(ROOT)}:{number}")
    if hits:
        fail("найдены заглушки/TODO: " + ", ".join(hits[:10]))
    else:
        ok("в модулях нет TODO/FIXME и заглушек")


def check_storage_mutex() -> None:
    text = read(MODULES / "entities" / "mod_storage.pwn")
    if "Storage_AcquireMutex" in text and "Storage_ReleaseMutex" in text:
        ok("хранилища: захват и освобождение gStorageMutex реализованы")
    else:
        fail("хранилища: не найдены функции работы с gStorageMutex")


def check_roadmap() -> None:
    text = (ROOT / "ROADMAP.md").read_text(encoding="utf-8")
    missing = [item for item in ("9.1.", "9.2.", "9.3.") if f"\\[x\\] **{item}" not in text]
    if missing:
        fail("ROADMAP: не отмечены выполненные пункты " + ", ".join(missing))
    else:
        ok("ROADMAP: пункты 9.1–9.3 отмечены как выполненные")


def check_devops() -> None:
    files = {
        "deploy/omp-server.service": ["LimitNOFILE=65535", "Restart=always", "ExecStart="],
        "deploy/backup_mysql.sh": ["--single-transaction", "--quick", "gzip", "RETENTION_DAYS"],
        "deploy/prune_audit_logs.sh": ["DELETE FROM audit_logs", "INTERVAL"],
        "deploy/sarp.cron": ["0 */6 * * *", "backup_mysql.sh", "prune_audit_logs.sh"],
        "deploy/logrotate-sarp": ["log.txt", "rotate 14", "copytruncate"],
    }
    problems = []
    for relative, markers in files.items():
        path = ROOT / relative
        if not path.exists():
            problems.append(f"{relative}: файл отсутствует")
            continue
        content = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in content:
                problems.append(f"{relative}: нет «{marker}»")
    if problems:
        fail("DevOps: " + "; ".join(problems))
    else:
        ok("DevOps: systemd, cron-бэкап, очистка audit_logs и logrotate настроены")


def main() -> int:
    print("SAN ANDREAS RP — статические проверки фазы 9")
    check_encoding()
    check_roles()
    check_items()
    check_ports()
    check_zero_faucet()
    check_anticheat()
    check_storage_mutex()
    check_no_stubs()
    check_devops()
    check_roadmap()
    print(f"\nИтог: успешно {passed}, ошибок {failed}.")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

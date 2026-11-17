/*
 * =============================================================================
 *  SAN ANDREAS RP — Пакетный сетевой античит на базе Pawn.RakNet
 *  Файл:      gamemodes/modules/core/mod_anticheat.pwn
 *  Фаза:      ROADMAP [9.1] — Сетевой античит на базе Pawn.RakNet
 *  Кодировка: Windows-1251 (CP1251) без BOM
 *  Зависимости: все предыдущие фазы (Storage, Character, Weapons, Roles,
 *               Economy, Ports, Audit). Модуль подключается последним.
 * =============================================================================
 */

#if defined _mod_anticheat_included
    #endinput
#endif
#define _mod_anticheat_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. Константы и макросы модуля
// =============================================================================

// Идентификаторы перехватываемых входящих пакетов SA-MP / open.mp.
#define AC_PACKET_VEHICLE_SYNC                  (200)
#define AC_PACKET_AIM_SYNC                      (203)
#define AC_PACKET_WEAPONS_UPDATE                (204)
#define AC_PACKET_PLAYER_SYNC                   (207)

// Пороговые значения античита.
#define AC_MAX_PACKETS_PER_SECOND               (240)
#define AC_MAX_DIALOGS_PER_SECOND               (10)
#define AC_MAX_COMMANDS_PER_SECOND              (8)

#define AC_TELEPORT_DISTANCE                    (100.0)
#define AC_TELEPORT_INSTANT_WINDOW_MS           (1000)
#define AC_TELEPORT_GRACE_MS                    (2500)

#define AC_FOOT_MAX_HORIZONTAL_SPEED            (45.0)
#define AC_FOOT_AIRBREAK_SPEED                  (28.0)
#define AC_FOOT_AIRBREAK_VERTICAL_TOLERANCE     (4.0)
#define AC_FOOT_AIRBREAK_SAMPLES                (3)

#define AC_LAND_MAX_SPEED                       (95.0)
#define AC_AIRCRAFT_MAX_SPEED                   (180.0)

#define AC_HP_TOLERANCE                         (25)
#define AC_ARMOUR_TOLERANCE                     (25)
#define AC_MISMATCH_SAMPLES                     (3)
#define AC_AMMO_TOLERANCE                       (8)
#define AC_SYNC_MISMATCH_STREAK                 (3)
#define AC_SYNC_MISMATCH_WINDOW_MS              (2000)
#define AC_STATE_GRACE_MS                       (2500)
#define AC_SPAWN_SYNC_GRACE_MS                  (3500)
#define AC_SERVER_VALUE_EPSILON                 (0.5)

#define AC_SCORE_DECAY_INTERVAL_MS              (10000)
#define AC_SCORE_KICK_THRESHOLD                 (55)
#define AC_SCORE_BAN_THRESHOLD                  (100)
#define AC_SEVERITY_CRITICAL                    (100)
#define AC_WARNING_COOLDOWN_MS                  (4000)

#define AC_KICK_DELAY_MS                        (900)
#define AC_WORLD_BOUND_MIN                      (-4000.0)
#define AC_WORLD_BOUND_MAX                      (4000.0)
#define AC_WORLD_Z_MIN                          (-500.0)
#define AC_WORLD_Z_MAX                          (3000.0)

#define AC_AUDIT_ACTION                         "ANTICHEAT"
#define AC_SERIAL_UNIQUENESS_SAMPLES            (512)

// =============================================================================
//  2. Перечисления (enum) и инкапсулированные массивы состояния
// =============================================================================

enum E_AC_VIOLATION
{
    AC_VIOL_NONE = 0,
    AC_VIOL_WEAPON_HACK,
    AC_VIOL_AMMO_HACK,
    AC_VIOL_TELEPORT,
    AC_VIOL_SPEEDHACK,
    AC_VIOL_AIRBREAK,
    AC_VIOL_GODMODE,
    AC_VIOL_VEHICLE_SPOOF,
    AC_VIOL_PACKET_FLOOD,
    AC_VIOL_DIALOG_FLOOD,
    AC_VIOL_COMMAND_FLOOD,
    AC_VIOL_MAX
};

enum E_AC_PLAYER_STATE
{
    bool:E_AC_INITIALIZED,
    bool:E_AC_BANNED,
    bool:E_AC_PENDING_KICK,
    E_AC_SCORE,
    E_AC_LAST_VIOLATION_TICK,
    E_AC_LAST_WARNING_TICK,
    E_AC_LAST_PACKET_WINDOW,
    E_AC_PACKET_COUNT,
    E_AC_LAST_DIALOG_WINDOW,
    E_AC_DIALOG_COUNT,
    E_AC_LAST_COMMAND_WINDOW,
    E_AC_COMMAND_COUNT,
    E_AC_GRACE_UNTIL,
    E_AC_SYNC_MODE,
    bool:E_AC_HAS_LAST_POS,
    Float:E_AC_LAST_X,
    Float:E_AC_LAST_Y,
    Float:E_AC_LAST_Z,
    E_AC_LAST_SYNC_TICK,
    E_AC_HP_MISMATCH,
    E_AC_ARMOUR_MISMATCH,
    E_AC_AIRBREAK_SAMPLES,
    E_AC_WEAPON_STREAK,
    E_AC_AMMO_STREAK,
    E_AC_LAST_SYNC_MISMATCH_TICK,
    bool:E_AC_SERVER_CACHE_VALID,
    Float:E_AC_CACHED_HEALTH,
    Float:E_AC_CACHED_ARMOUR,
    E_AC_STATE_GRACE_UNTIL,
    E_AC_TOTAL_VIOLATIONS
};

static stock sAcPlayers[MAX_PLAYERS][E_AC_PLAYER_STATE];
static stock sAcViolationCounts[AC_VIOL_MAX];
static stock sAcPacketsChecked = 0;
static stock sAcTotalViolations = 0;
static stock sAcTotalKicks = 0;
static stock sAcTotalBans = 0;

// Результаты автоматических интеграционных тестов фазы 9.2.
static stock sAcTestRolesFailures = 0;
static stock sAcTestItemsFailures = 0;
static stock sAcTestEconomyFailures = 0;
static stock sAcTestMutexFailures = 0;
static stock sAcTestSerialFailures = 0;
static stock sAcTestPortsFailures = 0;
static stock sAcTestsEverRan = 0;

// =============================================================================
//  3. Внутренние вспомогательные функции (static stock)
// =============================================================================

static stock Internal_GetViolationCode(E_AC_VIOLATION:violation, output[], len = sizeof(output))
{
    switch (violation)
    {
        case AC_VIOL_NONE:          format(output, len, "AC_NONE");
        case AC_VIOL_WEAPON_HACK:   format(output, len, "AC_WEAPON_HACK");
        case AC_VIOL_AMMO_HACK:     format(output, len, "AC_AMMO_HACK");
        case AC_VIOL_TELEPORT:      format(output, len, "AC_TELEPORT");
        case AC_VIOL_SPEEDHACK:     format(output, len, "AC_SPEEDHACK");
        case AC_VIOL_AIRBREAK:      format(output, len, "AC_AIRBREAK");
        case AC_VIOL_GODMODE:       format(output, len, "AC_GODMODE");
        case AC_VIOL_VEHICLE_SPOOF: format(output, len, "AC_VEHICLE_SPOOF");
        case AC_VIOL_PACKET_FLOOD:  format(output, len, "AC_PACKET_FLOOD");
        case AC_VIOL_DIALOG_FLOOD:  format(output, len, "AC_DIALOG_FLOOD");
        case AC_VIOL_COMMAND_FLOOD: format(output, len, "AC_COMMAND_FLOOD");
        default:                    format(output, len, "AC_UNKNOWN");
    }
    return 1;
}

static stock Internal_GetViolationTitleRu(E_AC_VIOLATION:violation, output[], len = sizeof(output))
{
    switch (violation)
    {
        case AC_VIOL_WEAPON_HACK:   format(output, len, "Оружие, отсутствующее в инвентаре");
        case AC_VIOL_AMMO_HACK:     format(output, len, "Подмена количества патронов");
        case AC_VIOL_TELEPORT:      format(output, len, "Телепортация по карте");
        case AC_VIOL_SPEEDHACK:     format(output, len, "Превышение серверной скорости");
        case AC_VIOL_AIRBREAK:      format(output, len, "Полёт без транспорта (AirBreak)");
        case AC_VIOL_GODMODE:       format(output, len, "Бессмертие (GodMode / NOP Damage)");
        case AC_VIOL_VEHICLE_SPOOF: format(output, len, "Подмена идентификатора транспорта");
        case AC_VIOL_PACKET_FLOOD:  format(output, len, "Флуд синхронизационными пакетами");
        case AC_VIOL_DIALOG_FLOOD:  format(output, len, "Флуд ответами диалогов");
        case AC_VIOL_COMMAND_FLOOD: format(output, len, "Флуд консольными командами");
        default:                    format(output, len, "Неизвестное нарушение");
    }
    return 1;
}

static stock Internal_GetViolationSeverity(E_AC_VIOLATION:violation)
{
    switch (violation)
    {
        case AC_VIOL_NONE:          return 0;
        case AC_VIOL_WEAPON_HACK:   return 100;
        case AC_VIOL_AMMO_HACK:     return 100;
        case AC_VIOL_GODMODE:       return 100;
        case AC_VIOL_VEHICLE_SPOOF: return 60;
        case AC_VIOL_TELEPORT:      return 35;
        case AC_VIOL_AIRBREAK:      return 35;
        case AC_VIOL_SPEEDHACK:     return 30;
        case AC_VIOL_PACKET_FLOOD:  return 30;
        case AC_VIOL_DIALOG_FLOOD:  return 20;
        case AC_VIOL_COMMAND_FLOOD: return 20;
        default:                    return 0;
    }
}

static stock bool:Internal_IsCoordValid(Float:value, Float:minValue, Float:maxValue)
{
    // Проверка в форме "!(value >= min)" отсекает NaN и бесконечность.
    if (!(value >= minValue))
    {
        return false;
    }
    if (!(value <= maxValue))
    {
        return false;
    }
    return true;
}

static stock bool:Internal_IsAircraftModel(model)
{
    switch (model)
    {
        case 417, 425, 447, 460, 476, 487, 488, 497, 511, 512, 513,
             519, 520, 548, 553, 563, 577, 578, 579, 580, 581, 582,
             583, 584, 585, 586, 587, 588, 589, 590, 591, 592, 593:
        {
            return true;
        }
    }
    return false;
}

static stock Float:Internal_GetVehicleSpeedLimit(vehicleid)
{
    new const model = GetVehicleModel(vehicleid);
    if (Internal_IsAircraftModel(model))
    {
        return AC_AIRCRAFT_MAX_SPEED;
    }
    return AC_LAND_MAX_SPEED;
}

static stock Internal_ResetPlayerState(playerid)
{
    sAcPlayers[playerid][E_AC_INITIALIZED] = true;
    sAcPlayers[playerid][E_AC_BANNED] = false;
    sAcPlayers[playerid][E_AC_PENDING_KICK] = false;
    sAcPlayers[playerid][E_AC_SCORE] = 0;
    sAcPlayers[playerid][E_AC_LAST_VIOLATION_TICK] = 0;
    sAcPlayers[playerid][E_AC_LAST_WARNING_TICK] = 0;
    sAcPlayers[playerid][E_AC_LAST_PACKET_WINDOW] = 0;
    sAcPlayers[playerid][E_AC_PACKET_COUNT] = 0;
    sAcPlayers[playerid][E_AC_LAST_DIALOG_WINDOW] = 0;
    sAcPlayers[playerid][E_AC_DIALOG_COUNT] = 0;
    sAcPlayers[playerid][E_AC_LAST_COMMAND_WINDOW] = 0;
    sAcPlayers[playerid][E_AC_COMMAND_COUNT] = 0;
    sAcPlayers[playerid][E_AC_GRACE_UNTIL] = 0;
    sAcPlayers[playerid][E_AC_SYNC_MODE] = 0;
    sAcPlayers[playerid][E_AC_HAS_LAST_POS] = false;
    sAcPlayers[playerid][E_AC_LAST_X] = 0.0;
    sAcPlayers[playerid][E_AC_LAST_Y] = 0.0;
    sAcPlayers[playerid][E_AC_LAST_Z] = 0.0;
    sAcPlayers[playerid][E_AC_LAST_SYNC_TICK] = 0;
    sAcPlayers[playerid][E_AC_HP_MISMATCH] = 0;
    sAcPlayers[playerid][E_AC_ARMOUR_MISMATCH] = 0;
    sAcPlayers[playerid][E_AC_AIRBREAK_SAMPLES] = 0;
    sAcPlayers[playerid][E_AC_WEAPON_STREAK] = 0;
    sAcPlayers[playerid][E_AC_AMMO_STREAK] = 0;
    sAcPlayers[playerid][E_AC_LAST_SYNC_MISMATCH_TICK] = 0;
    sAcPlayers[playerid][E_AC_SERVER_CACHE_VALID] = false;
    sAcPlayers[playerid][E_AC_CACHED_HEALTH] = 0.0;
    sAcPlayers[playerid][E_AC_CACHED_ARMOUR] = 0.0;
    sAcPlayers[playerid][E_AC_STATE_GRACE_UNTIL] = 0;
    sAcPlayers[playerid][E_AC_TOTAL_VIOLATIONS] = 0;
}

static stock bool:Internal_CanCheckPlayer(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return false;
    }
    if (!IsPlayerConnected(playerid))
    {
        return false;
    }
    if (sAcPlayers[playerid][E_AC_BANNED] || sAcPlayers[playerid][E_AC_PENDING_KICK])
    {
        return false;
    }

    // До завершения авторизации клиентские пакеты не анализируются:
    // в этот период персонаж ещё не привязан к аккаунту.
    if (!Account_IsLogged(playerid))
    {
        return false;
    }
    if (!Character_IsLoaded(playerid))
    {
        return false;
    }
    if (!Character_IsAlive(playerid))
    {
        return false;
    }
    if (!IsPlayerSpawned(playerid))
    {
        return false;
    }

    // Жёсткий фильтр состояний: движение/здоровье проверяются только
    // для пешего игрока или водителя. Смерть, выбор персонажа и
    // спектатор (PLAYER_STATE_WASTED / NONE / SPECTATING) игнорируются.
    new const PLAYER_STATE:playerState = GetPlayerState(playerid);
    if (playerState != PLAYER_STATE_ONFOOT && playerState != PLAYER_STATE_DRIVER)
    {
        return false;
    }
    return true;
}

static stock Internal_StorePosition(playerid, Float:x, Float:y, Float:z, mode)
{
    sAcPlayers[playerid][E_AC_LAST_X] = x;
    sAcPlayers[playerid][E_AC_LAST_Y] = y;
    sAcPlayers[playerid][E_AC_LAST_Z] = z;
    sAcPlayers[playerid][E_AC_LAST_SYNC_TICK] = GetTickCount();
    sAcPlayers[playerid][E_AC_SYNC_MODE] = mode;
    sAcPlayers[playerid][E_AC_HAS_LAST_POS] = true;
}

static stock Internal_SendKickNotice(playerid, const title[])
{
    new message[224];
    format(message, sizeof(message),
        "[Античит]: Вы отключены от сервера системой защиты от читов. Причина: %s.",
        title);
    SendClientMessage(playerid, COLOR_UI_ERROR, message);
}

static stock Internal_KickPlayer(playerid, E_AC_VIOLATION:violation)
{
    if (!IsPlayerConnected(playerid) || sAcPlayers[playerid][E_AC_PENDING_KICK] || sAcPlayers[playerid][E_AC_BANNED])
    {
        return 0;
    }

    sAcPlayers[playerid][E_AC_PENDING_KICK] = true;
    sAcTotalKicks++;

    new title[64];
    Internal_GetViolationTitleRu(violation, title, sizeof(title));
    Internal_SendKickNotice(playerid, title);

    SetTimerEx("AC_KickTimer", AC_KICK_DELAY_MS, false, "dd", playerid, Config_GetPlayerSessionToken(playerid));
    return 1;
}

static stock Internal_BanPlayer(playerid, E_AC_VIOLATION:violation, const details[])
{
    if (!IsPlayerConnected(playerid) || sAcPlayers[playerid][E_AC_BANNED])
    {
        return 0;
    }

    sAcPlayers[playerid][E_AC_BANNED] = true;
    sAcTotalBans++;

    new title[64];
    new reason[144];
    Internal_GetViolationTitleRu(violation, title, sizeof(title));
    format(reason, sizeof(reason), "SAN ANDREAS RP | %s | %s", title, details);

    new playerName[MAX_PLAYER_NAME + 1];
    GetPlayerName(playerid, playerName, sizeof(playerName));
    printf("%s [Core/AntiCheat] БАН: игрок %s заблокирован. Причина: %s.",
        SERVER_LOG_PREFIX, playerName, reason);

    BanEx(playerid, reason);
    Internal_SendKickNotice(playerid, title);
    SetTimerEx("AC_KickTimer", AC_KICK_DELAY_MS, false, "dd", playerid, Config_GetPlayerSessionToken(playerid));
    return 1;
}

static stock Internal_ApplyViolation(playerid, E_AC_VIOLATION:violation, const details[])
{
    if (violation <= AC_VIOL_NONE || violation >= AC_VIOL_MAX)
    {
        return 0;
    }
    if (!IsPlayerConnected(playerid))
    {
        return 0;
    }
    if (sAcPlayers[playerid][E_AC_BANNED] || sAcPlayers[playerid][E_AC_PENDING_KICK])
    {
        return 0;
    }

    new const nowTick = GetTickCount();
    new const severity = Internal_GetViolationSeverity(violation);

    sAcViolationCounts[violation]++;
    sAcTotalViolations++;
    sAcPlayers[playerid][E_AC_TOTAL_VIOLATIONS]++;
    sAcPlayers[playerid][E_AC_SCORE] += severity;
    sAcPlayers[playerid][E_AC_LAST_VIOLATION_TICK] = nowTick;

    new title[64];
    new code[32];
    new playerName[MAX_PLAYER_NAME + 1];
    new auditDetails[240];

    Internal_GetViolationTitleRu(violation, title, sizeof(title));
    Internal_GetViolationCode(violation, code, sizeof(code));
    GetPlayerName(playerid, playerName, sizeof(playerName));

    new const charId = Character_IsLoaded(playerid) ? Character_GetId(playerid) : 0;
    format(auditDetails, sizeof(auditDetails),
        "%s | Игрок: %s | Счёт: %d | %s",
        title, playerName, sAcPlayers[playerid][E_AC_SCORE], details);

    Audit_Log(charId, AC_AUDIT_ACTION, code, "CHARACTER", 0, sAcPlayers[playerid][E_AC_SCORE], auditDetails);

    printf("%s [Core/AntiCheat] Нарушение %s у игрока %s (счёт %d): %s.",
        SERVER_LOG_PREFIX, code, playerName, sAcPlayers[playerid][E_AC_SCORE], details);

    if (severity >= AC_SEVERITY_CRITICAL || sAcPlayers[playerid][E_AC_SCORE] >= AC_SCORE_BAN_THRESHOLD)
    {
        Internal_BanPlayer(playerid, violation, details);
        return 2;
    }

    if (sAcPlayers[playerid][E_AC_SCORE] >= AC_SCORE_KICK_THRESHOLD)
    {
        Internal_KickPlayer(playerid, violation);
        return 1;
    }

    if ((nowTick - sAcPlayers[playerid][E_AC_LAST_WARNING_TICK]) >= AC_WARNING_COOLDOWN_MS)
    {
        sAcPlayers[playerid][E_AC_LAST_WARNING_TICK] = nowTick;
        new message[224];
        format(message, sizeof(message),
            "[Античит]: Зафиксировано подозрительное действие (%s). Предупреждение %d из %d.",
            title, sAcPlayers[playerid][E_AC_SCORE], AC_SCORE_KICK_THRESHOLD);
        SendClientMessage(playerid, COLOR_UI_WARNING, message);
    }
    return 0;
}

static stock Internal_RegisterSyncMismatch(playerid, E_AC_VIOLATION:violation, const details[])
{
    new const nowTick = GetTickCount();

    if ((nowTick - sAcPlayers[playerid][E_AC_LAST_SYNC_MISMATCH_TICK]) > AC_SYNC_MISMATCH_WINDOW_MS)
    {
        sAcPlayers[playerid][E_AC_WEAPON_STREAK] = 0;
        sAcPlayers[playerid][E_AC_AMMO_STREAK] = 0;
    }
    sAcPlayers[playerid][E_AC_LAST_SYNC_MISMATCH_TICK] = nowTick;

    new streak = 0;
    if (violation == AC_VIOL_WEAPON_HACK)
    {
        sAcPlayers[playerid][E_AC_WEAPON_STREAK]++;
        streak = sAcPlayers[playerid][E_AC_WEAPON_STREAK];
    }
    else
    {
        sAcPlayers[playerid][E_AC_AMMO_STREAK]++;
        streak = sAcPlayers[playerid][E_AC_AMMO_STREAK];
    }

    if (streak >= AC_SYNC_MISMATCH_STREAK)
    {
        Internal_ApplyViolation(playerid, violation, details);
        sAcPlayers[playerid][E_AC_WEAPON_STREAK] = 0;
        sAcPlayers[playerid][E_AC_AMMO_STREAK] = 0;
    }
    else
    {
        // Рассинхронизация могла возникнуть из-за выброса оружия или
        // запоздавшего пакета — принудительно синхронизируем клиент.
        Character_SyncLayer1Weapons(playerid);
    }
    return 1;
}

static stock bool:Internal_CheckWeaponOwnership(playerid, weaponid)
{
    if (!Weapons_IsTrackedFirearm(weaponid))
    {
        return true;
    }

    new const itemSlot = Weapons_GetItemSlot(playerid, WEAPON:weaponid, false);
    if (itemSlot == INVALID_STORAGE_ITEM_SLOT)
    {
        new details[160];
        format(details, sizeof(details),
            "Клиент удерживает ствол ID %d, которого нет в Слое 1", weaponid);
        Internal_RegisterSyncMismatch(playerid, AC_VIOL_WEAPON_HACK, details);
        return false;
    }

    sAcPlayers[playerid][E_AC_WEAPON_STREAK] = 0;
    return true;
}

static stock Internal_CheckHealthSync(playerid, clientHealth, clientArmour)
{
    new Float:serverHealth = 0.0;
    new Float:serverArmour = 0.0;

    if (!GetPlayerHealth(playerid, serverHealth))
    {
        return 0;
    }
    GetPlayerArmour(playerid, serverArmour);

    if (serverHealth <= 0.0)
    {
        sAcPlayers[playerid][E_AC_HP_MISMATCH] = 0;
        sAcPlayers[playerid][E_AC_ARMOUR_MISMATCH] = 0;
        return 0;
    }

    new const nowTick = GetTickCount();

    // Первый пакет после входа/спавна: кэш серверных значений ещё пуст,
    // поэтому клиентские HP/Armour не сравниваем и выдаём окно стабилизации.
    if (!sAcPlayers[playerid][E_AC_SERVER_CACHE_VALID])
    {
        sAcPlayers[playerid][E_AC_CACHED_HEALTH] = serverHealth;
        sAcPlayers[playerid][E_AC_CACHED_ARMOUR] = serverArmour;
        sAcPlayers[playerid][E_AC_SERVER_CACHE_VALID] = true;
        sAcPlayers[playerid][E_AC_STATE_GRACE_UNTIL] = nowTick + AC_STATE_GRACE_MS;
        sAcPlayers[playerid][E_AC_HP_MISMATCH] = 0;
        sAcPlayers[playerid][E_AC_ARMOUR_MISMATCH] = 0;
        return 0;
    }

    new Float:cachedHealth = sAcPlayers[playerid][E_AC_CACHED_HEALTH];
    new Float:cachedArmour = sAcPlayers[playerid][E_AC_CACHED_ARMOUR];

    // Серверное изменение HP/Armour (лечение, урон, кровотечение, спавн):
    // обновляем кэш и не считаем это читерством.
    if (floatabs(serverHealth - cachedHealth) > AC_SERVER_VALUE_EPSILON ||
        floatabs(serverArmour - cachedArmour) > AC_SERVER_VALUE_EPSILON)
    {
        sAcPlayers[playerid][E_AC_CACHED_HEALTH] = serverHealth;
        sAcPlayers[playerid][E_AC_CACHED_ARMOUR] = serverArmour;
        sAcPlayers[playerid][E_AC_STATE_GRACE_UNTIL] = nowTick + AC_STATE_GRACE_MS;
        sAcPlayers[playerid][E_AC_HP_MISMATCH] = 0;
        sAcPlayers[playerid][E_AC_ARMOUR_MISMATCH] = 0;
        return 0;
    }

    // Окно стабилизации после спавна или серверного изменения HP/Armour.
    if (nowTick < sAcPlayers[playerid][E_AC_STATE_GRACE_UNTIL])
    {
        sAcPlayers[playerid][E_AC_HP_MISMATCH] = 0;
        sAcPlayers[playerid][E_AC_ARMOUR_MISMATCH] = 0;
        return 0;
    }

    if (float(clientHealth) > (cachedHealth + float(AC_HP_TOLERANCE)))
    {
        sAcPlayers[playerid][E_AC_HP_MISMATCH]++;
    }
    else
    {
        sAcPlayers[playerid][E_AC_HP_MISMATCH] = 0;
    }

    if (float(clientArmour) > (cachedArmour + float(AC_ARMOUR_TOLERANCE)))
    {
        sAcPlayers[playerid][E_AC_ARMOUR_MISMATCH]++;
    }
    else
    {
        sAcPlayers[playerid][E_AC_ARMOUR_MISMATCH] = 0;
    }

    if (sAcPlayers[playerid][E_AC_HP_MISMATCH] >= AC_MISMATCH_SAMPLES ||
        sAcPlayers[playerid][E_AC_ARMOUR_MISMATCH] >= AC_MISMATCH_SAMPLES)
    {
        new details[192];
        format(details, sizeof(details),
            "Клиент сообщает HP %d / броню %d, сервер: HP %.0f / броня %.0f",
            clientHealth, clientArmour, cachedHealth, cachedArmour);
        Internal_ApplyViolation(playerid, AC_VIOL_GODMODE, details);

        sAcPlayers[playerid][E_AC_HP_MISMATCH] = 0;
        sAcPlayers[playerid][E_AC_ARMOUR_MISMATCH] = 0;
    }
    return 1;
}

static stock bool:Internal_ValidateMovement(playerid, Float:x, Float:y, Float:z, mode)
{
    if (!Internal_IsCoordValid(x, AC_WORLD_BOUND_MIN, AC_WORLD_BOUND_MAX) ||
        !Internal_IsCoordValid(y, AC_WORLD_BOUND_MIN, AC_WORLD_BOUND_MAX) ||
        !Internal_IsCoordValid(z, AC_WORLD_Z_MIN, AC_WORLD_Z_MAX))
    {
        Internal_ApplyViolation(playerid, AC_VIOL_TELEPORT, "Координаты вне допустимых границ карты");
        return false;
    }

    new const nowTick = GetTickCount();

    if (nowTick < sAcPlayers[playerid][E_AC_STATE_GRACE_UNTIL])
    {
        Internal_StorePosition(playerid, x, y, z, mode);
        return true;
    }

    if (!sAcPlayers[playerid][E_AC_HAS_LAST_POS] || sAcPlayers[playerid][E_AC_SYNC_MODE] != mode)
    {
        Internal_StorePosition(playerid, x, y, z, mode);
        return true;
    }

    if (nowTick < sAcPlayers[playerid][E_AC_GRACE_UNTIL])
    {
        Internal_StorePosition(playerid, x, y, z, mode);
        return true;
    }

    new elapsedMs = nowTick - sAcPlayers[playerid][E_AC_LAST_SYNC_TICK];
    if (elapsedMs < 10)
    {
        elapsedMs = 10;
    }
    if (elapsedMs > 3000)
    {
        Internal_StorePosition(playerid, x, y, z, mode);
        return true;
    }

    // Серверный телепорт (спавн, больница, тюрьма, вход в интерьер) меняет
    // серверную позицию до прихода клиентского пакета — это не читерство.
    new Float:serverX = 0.0;
    new Float:serverY = 0.0;
    new Float:serverZ = 0.0;
    GetPlayerPos(playerid, serverX, serverY, serverZ);

    new const Float:lastToServer = Utils_GetDistance3D(
        sAcPlayers[playerid][E_AC_LAST_X],
        sAcPlayers[playerid][E_AC_LAST_Y],
        sAcPlayers[playerid][E_AC_LAST_Z],
        serverX, serverY, serverZ);

    if (lastToServer > AC_TELEPORT_DISTANCE)
    {
        Internal_StorePosition(playerid, x, y, z, mode);
        return true;
    }

    new const Float:distance = Utils_GetDistance3D(
        sAcPlayers[playerid][E_AC_LAST_X],
        sAcPlayers[playerid][E_AC_LAST_Y],
        sAcPlayers[playerid][E_AC_LAST_Z],
        x, y, z);

    if (distance > AC_TELEPORT_DISTANCE && elapsedMs <= AC_TELEPORT_INSTANT_WINDOW_MS)
    {
        new details[176];
        format(details, sizeof(details),
            "Мгновенное перемещение на %.1f м за %d мс", distance, elapsedMs);
        Internal_ApplyViolation(playerid, AC_VIOL_TELEPORT, details);
        Internal_StorePosition(playerid, x, y, z, mode);
        return false;
    }

    new Float:seconds = float(elapsedMs) / 1000.0;

    if (mode == 1)
    {
        new const Float:horizontalDistance = Utils_GetDistance3D(
            sAcPlayers[playerid][E_AC_LAST_X],
            sAcPlayers[playerid][E_AC_LAST_Y],
            0.0,
            x, y, 0.0);
        new const Float:horizontalSpeed = horizontalDistance / seconds;
        new const Float:verticalSpeed = (z - sAcPlayers[playerid][E_AC_LAST_Z]) / seconds;

        if (horizontalSpeed > AC_FOOT_MAX_HORIZONTAL_SPEED)
        {
            new details[176];
            format(details, sizeof(details),
                "Скорость пешком %.1f м/с при серверном лимите %.1f м/с",
                horizontalSpeed, AC_FOOT_MAX_HORIZONTAL_SPEED);
            Internal_ApplyViolation(playerid, AC_VIOL_SPEEDHACK, details);
            Internal_StorePosition(playerid, x, y, z, mode);
            return false;
        }

        if (horizontalSpeed > AC_FOOT_AIRBREAK_SPEED &&
            floatabs(verticalSpeed) < AC_FOOT_AIRBREAK_VERTICAL_TOLERANCE)
        {
            sAcPlayers[playerid][E_AC_AIRBREAK_SAMPLES]++;
            if (sAcPlayers[playerid][E_AC_AIRBREAK_SAMPLES] >= AC_FOOT_AIRBREAK_SAMPLES)
            {
                new details[176];
                format(details, sizeof(details),
                    "Горизонтальный полёт %.1f м/с без вертикального падения",
                    horizontalSpeed);
                Internal_ApplyViolation(playerid, AC_VIOL_AIRBREAK, details);
                sAcPlayers[playerid][E_AC_AIRBREAK_SAMPLES] = 0;
                Internal_StorePosition(playerid, x, y, z, mode);
                return false;
            }
        }
        else
        {
            sAcPlayers[playerid][E_AC_AIRBREAK_SAMPLES] = 0;
        }
    }
    else
    {
        new const Float:vehicleSpeed = distance / seconds;
        new const Float:speedLimit = Internal_GetVehicleSpeedLimit(GetPlayerVehicleID(playerid));

        if (vehicleSpeed > speedLimit)
        {
            new details[192];
            format(details, sizeof(details),
                "Скорость транспорта %.1f м/с при серверном лимите %.1f м/с",
                vehicleSpeed, speedLimit);
            Internal_ApplyViolation(playerid, AC_VIOL_SPEEDHACK, details);
            Internal_StorePosition(playerid, x, y, z, mode);
            return false;
        }
    }

    Internal_StorePosition(playerid, x, y, z, mode);
    return true;
}

static stock bool:Internal_CheckPacketFlood(playerid)
{
    new const nowTick = GetTickCount();

    if ((nowTick - sAcPlayers[playerid][E_AC_LAST_PACKET_WINDOW]) >= 1000)
    {
        sAcPlayers[playerid][E_AC_LAST_PACKET_WINDOW] = nowTick;
        sAcPlayers[playerid][E_AC_PACKET_COUNT] = 1;
        return true;
    }

    sAcPlayers[playerid][E_AC_PACKET_COUNT]++;
    if (sAcPlayers[playerid][E_AC_PACKET_COUNT] > AC_MAX_PACKETS_PER_SECOND)
    {
        Internal_ApplyViolation(playerid, AC_VIOL_PACKET_FLOOD,
            "Превышена частота входящих синхронизационных пакетов");
        sAcPlayers[playerid][E_AC_PACKET_COUNT] = 0;
        return false;
    }
    return true;
}

static stock bool:Internal_CheckDialogFlood(playerid)
{
    new const nowTick = GetTickCount();

    if ((nowTick - sAcPlayers[playerid][E_AC_LAST_DIALOG_WINDOW]) >= 1000)
    {
        sAcPlayers[playerid][E_AC_LAST_DIALOG_WINDOW] = nowTick;
        sAcPlayers[playerid][E_AC_DIALOG_COUNT] = 1;
        return true;
    }

    sAcPlayers[playerid][E_AC_DIALOG_COUNT]++;
    if (sAcPlayers[playerid][E_AC_DIALOG_COUNT] > AC_MAX_DIALOGS_PER_SECOND)
    {
        Internal_ApplyViolation(playerid, AC_VIOL_DIALOG_FLOOD,
            "Превышена частота ответов на диалоговые окна");
        sAcPlayers[playerid][E_AC_DIALOG_COUNT] = 0;
        return false;
    }
    return true;
}

static stock bool:Internal_CheckCommandFlood(playerid)
{
    new const nowTick = GetTickCount();

    if ((nowTick - sAcPlayers[playerid][E_AC_LAST_COMMAND_WINDOW]) >= 1000)
    {
        sAcPlayers[playerid][E_AC_LAST_COMMAND_WINDOW] = nowTick;
        sAcPlayers[playerid][E_AC_COMMAND_COUNT] = 1;
        return true;
    }

    sAcPlayers[playerid][E_AC_COMMAND_COUNT]++;
    if (sAcPlayers[playerid][E_AC_COMMAND_COUNT] > AC_MAX_COMMANDS_PER_SECOND)
    {
        Internal_ApplyViolation(playerid, AC_VIOL_COMMAND_FLOOD,
            "Превышена частота ввода консольных команд");
        sAcPlayers[playerid][E_AC_COMMAND_COUNT] = 0;
        return false;
    }
    return true;
}

// =============================================================================
//  4. Публичный API модуля (AC_*)
// =============================================================================

stock AC_MarkServerTeleport(playerid, grace_ms = AC_TELEPORT_GRACE_MS)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    if (!IsPlayerConnected(playerid))
    {
        return 0;
    }
    sAcPlayers[playerid][E_AC_GRACE_UNTIL] = GetTickCount() + grace_ms;
    return 1;
}

stock AC_GetViolationScore(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    return sAcPlayers[playerid][E_AC_SCORE];
}

stock AC_GetTotalViolations()
{
    return sAcTotalViolations;
}

stock AC_GetTotalKicks()
{
    return sAcTotalKicks;
}

stock AC_GetTotalBans()
{
    return sAcTotalBans;
}

stock AC_GetPacketsChecked()
{
    return sAcPacketsChecked;
}

stock bool:AC_AreIntegrationTestsPassed()
{
    return (sAcTestsEverRan > 0 &&
        sAcTestRolesFailures == 0 &&
        sAcTestItemsFailures == 0 &&
        sAcTestEconomyFailures == 0 &&
        sAcTestMutexFailures == 0 &&
        sAcTestSerialFailures == 0 &&
        sAcTestPortsFailures == 0);
}

// =============================================================================
//  5. Автоматические интеграционные и балансовые тесты (ROADMAP 9.2)
// =============================================================================

static stock Internal_TestStarterRoles()
{
    new failures = 0;

    for (new role = 1; role <= MAX_STARTER_ROLES; role++)
    {
        if (!Roles_IsValidId(role))
        {
            failures++;
            continue;
        }

        new name[ROLE_TITLE_MAX_LEN];
        Roles_GetNameRu(role, name, sizeof(name));
        if (name[0] == EOS)
        {
            failures++;
        }

        if (Roles_GetStartCashUsd(role) < 0 || Roles_GetStartBankUsd(role) < 0 || Roles_GetStartDebtUsd(role) < 0)
        {
            failures++;
        }

        new const wanted = Roles_GetStartWanted(role);
        if (wanted < 0 || wanted > 100)
        {
            failures++;
        }

        new Float:x = 0.0, Float:y = 0.0, Float:z = 0.0, Float:a = 0.0;
        new interior = 0, virtualWorld = 0;
        if (!Roles_GetSpawnPos(role, x, y, z, a, interior, virtualWorld))
        {
            failures++;
        }
        if (!Internal_IsCoordValid(x, AC_WORLD_BOUND_MIN, AC_WORLD_BOUND_MAX) ||
            !Internal_IsCoordValid(y, AC_WORLD_BOUND_MIN, AC_WORLD_BOUND_MAX) ||
            !Internal_IsCoordValid(z, AC_WORLD_Z_MIN, AC_WORLD_Z_MAX))
        {
            failures++;
        }

        new const idx = role - 1;
        if (gRoleConfigs[idx][E_ROLE_ID] != role)
        {
            failures++;
        }

        if (gRoleConfigs[idx][E_ROLE_ITEM_ID_1] > 0 && !Item_IsValid(gRoleConfigs[idx][E_ROLE_ITEM_ID_1])) failures++;
        if (gRoleConfigs[idx][E_ROLE_ITEM_ID_2] > 0 && !Item_IsValid(gRoleConfigs[idx][E_ROLE_ITEM_ID_2])) failures++;
        if (gRoleConfigs[idx][E_ROLE_ITEM_ID_3] > 0 && !Item_IsValid(gRoleConfigs[idx][E_ROLE_ITEM_ID_3])) failures++;
        if (gRoleConfigs[idx][E_ROLE_ITEM_ID_4] > 0 && !Item_IsValid(gRoleConfigs[idx][E_ROLE_ITEM_ID_4])) failures++;
        if (gRoleConfigs[idx][E_ROLE_ITEM_ID_5] > 0 && !Item_IsValid(gRoleConfigs[idx][E_ROLE_ITEM_ID_5])) failures++;
        if (gRoleConfigs[idx][E_ROLE_ITEM_ID_6] > 0 && !Item_IsValid(gRoleConfigs[idx][E_ROLE_ITEM_ID_6])) failures++;

        if (gRoleConfigs[idx][E_ROLE_SKILL_VAL_1] < 0 || gRoleConfigs[idx][E_ROLE_SKILL_VAL_1] > SKILL_MAX_VALUE) failures++;
        if (gRoleConfigs[idx][E_ROLE_SKILL_VAL_2] < 0 || gRoleConfigs[idx][E_ROLE_SKILL_VAL_2] > SKILL_MAX_VALUE) failures++;
        if (gRoleConfigs[idx][E_ROLE_SKILL_VAL_3] < 0 || gRoleConfigs[idx][E_ROLE_SKILL_VAL_3] > SKILL_MAX_VALUE) failures++;
        if (gRoleConfigs[idx][E_ROLE_SKILL_VAL_4] < 0 || gRoleConfigs[idx][E_ROLE_SKILL_VAL_4] > SKILL_MAX_VALUE) failures++;
        if (gRoleConfigs[idx][E_ROLE_SKILL_VAL_5] < 0 || gRoleConfigs[idx][E_ROLE_SKILL_VAL_5] > SKILL_MAX_VALUE) failures++;
    }
    return failures;
}

static stock Internal_TestItemRegistry()
{
    new failures = 0;

    if (Item_GetLoadedCount() != TOTAL_SEED_ITEM_DEFS)
    {
        failures++;
    }

    for (new defId = 1; defId <= TOTAL_SEED_ITEM_DEFS; defId++)
    {
        if (!Item_IsValid(defId))
        {
            failures++;
            continue;
        }

        if (Item_GetBaseWeight(defId) <= 0)
        {
            failures++;
        }
        if (Item_GetBaseVolume(defId) < 0)
        {
            failures++;
        }

        new name[ITEM_DISPLAY_NAME_LEN];
        Item_GetName(defId, name, sizeof(name));
        if (name[0] == EOS)
        {
            failures++;
        }
    }

    // DoD 2.1: 200 патронов M4 добавляют ровно 2400 г к базовым 3400 г.
    if (Item_CalculateInstanceWeight(23, 1, 200) != 5800)
    {
        failures++;
    }
    return failures;
}

static stock Internal_TestZeroFaucetEconomy()
{
    new failures = 0;

    if (!(PORT_PRICE_CLAMP_MIN < PORT_PRICE_CLAMP_MAX))
    {
        failures++;
    }
    if (PORT_PRICE_CLAMP_MIN <= 0.0)
    {
        failures++;
    }

    new validEnterprises = 0;
    for (new entId = 0; entId < MAX_ENTERPRISES; entId++)
    {
        if (!Enterprise_IsValid(entId))
        {
            continue;
        }

        validEnterprises++;
        if (Enterprise_GetReserve(entId) < 0)
        {
            failures++;
        }
        if (!Storage_IsValidSlot(Enterprise_GetWarehouseSlot(entId)))
        {
            failures++;
        }
    }

    if (validEnterprises <= 0)
    {
        failures++;
    }
    return failures;
}

static stock Internal_TestPortQuotes()
{
    new failures = 0;
    new quotes = 0;

    for (new portId = 1; portId <= MAX_PORT_TERMINALS; portId++)
    {
        for (new defId = 1; defId <= TOTAL_SEED_ITEM_DEFS; defId++)
        {
            new const buyPrice = Ports_GetBuyPrice(portId, defId);
            new const sellPrice = Ports_GetSellPrice(portId, defId);

            if (buyPrice <= 0 && sellPrice <= 0)
            {
                continue;
            }

            quotes++;
            if (sellPrice <= 0 || buyPrice <= sellPrice)
            {
                failures++;
            }
        }
    }

    if (quotes < TOTAL_BUILTIN_PORT_QUOTES)
    {
        failures++;
    }
    return failures;
}

static stock Internal_TestStorageMutexStress()
{
    new failures = 0;

    new const testSlot = Storage_Create(
        STORAGE_VEHICLE_TRUNK,
        9999980,
        1000000,
        1000000,
        false,
        0,
        0.0, 0.0, 0.0,
        0,
        0,
        0,
        0,
        true
    );

    if (testSlot == INVALID_STORAGE_SLOT)
    {
        return 1;
    }

    // 20 раундов по 24 одновременных претендента: мьютекс обязан
    // пропустить ровно одного и заблокировать остальных 23.
    for (new round = 0; round < 20; round++)
    {
        new acquired = 0;
        for (new contender = 1; contender <= 24; contender++)
        {
            if (Storage_AcquireMutex(testSlot, contender))
            {
                acquired++;
            }
        }

        if (acquired != 1)
        {
            failures++;
        }
        Storage_ReleaseMutex(testSlot);
    }

    Storage_Unload(testSlot);
    return failures;
}

static stock Internal_TestWeaponSerialUniqueness()
{
    new serials[AC_SERIAL_UNIQUENESS_SAMPLES];
    new failures = 0;

    for (new i = 0; i < AC_SERIAL_UNIQUENESS_SAMPLES; i++)
    {
        serials[i] = Utils_GenerateWeaponSerial();
    }

    for (new i = 0; i < AC_SERIAL_UNIQUENESS_SAMPLES; i++)
    {
        for (new j = (i + 1); j < AC_SERIAL_UNIQUENESS_SAMPLES; j++)
        {
            if (serials[i] == serials[j])
            {
                failures++;
                break;
            }
        }
        if (failures > 0)
        {
            break;
        }
    }
    return failures;
}

static stock bool:Internal_RunIntegrationTests()
{
    sAcTestRolesFailures = Internal_TestStarterRoles();
    sAcTestItemsFailures = Internal_TestItemRegistry();
    sAcTestEconomyFailures = Internal_TestZeroFaucetEconomy();
    sAcTestPortsFailures = Internal_TestPortQuotes();
    sAcTestMutexFailures = Internal_TestStorageMutexStress();
    sAcTestSerialFailures = Internal_TestWeaponSerialUniqueness();
    sAcTestsEverRan++;

    printf("%s [Core/AntiCheat] Тесты 9.2: роли=%s (%d) | предметы=%s (%d) | экономика=%s (%d) | порты=%s (%d) | мьютексы=%s (%d) | серийники=%s (%d).",
        SERVER_LOG_PREFIX,
        (sAcTestRolesFailures == 0) ? ("ОК") : ("ОШИБКА"), sAcTestRolesFailures,
        (sAcTestItemsFailures == 0) ? ("ОК") : ("ОШИБКА"), sAcTestItemsFailures,
        (sAcTestEconomyFailures == 0) ? ("ОК") : ("ОШИБКА"), sAcTestEconomyFailures,
        (sAcTestPortsFailures == 0) ? ("ОК") : ("ОШИБКА"), sAcTestPortsFailures,
        (sAcTestMutexFailures == 0) ? ("ОК") : ("ОШИБКА"), sAcTestMutexFailures,
        (sAcTestSerialFailures == 0) ? ("ОК") : ("ОШИБКА"), sAcTestSerialFailures);

    return AC_AreIntegrationTestsPassed();
}

// =============================================================================
//  6. Асинхронные таймеры и служебные колбеки
// =============================================================================

forward AC_KickTimer(playerid, expectedToken);
public AC_KickTimer(playerid, expectedToken)
{
    if (!IsPlayerConnected(playerid))
    {
        return 0;
    }
    if (Config_GetPlayerSessionToken(playerid) != expectedToken)
    {
        return 0;
    }

    Kick(playerid);
    return 1;
}

timer AC_IntegrationTests[1500]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }
    Internal_RunIntegrationTests();
}

// =============================================================================
//  7. Хуки системных колбеков (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        Internal_ResetPlayerState(playerid);
    }

    for (new i = 0; i < _:AC_VIOL_MAX; i++)
    {
        sAcViolationCounts[E_AC_VIOLATION:i] = 0;
    }

    sAcPacketsChecked = 0;
    sAcTotalViolations = 0;
    sAcTotalKicks = 0;
    sAcTotalBans = 0;
    sAcTestsEverRan = 0;

    // Тесты запускаются после завершения всех OnGameModeInit, когда
    // предприятия, порты и предметы уже загружены в RAM.
    defer AC_IntegrationTests();

    printf("%s [Core/AntiCheat] Сетевой античит Pawn.RakNet активирован (пакеты %d/%d/%d/%d).",
        SERVER_LOG_PREFIX,
        AC_PACKET_VEHICLE_SYNC,
        AC_PACKET_AIM_SYNC,
        AC_PACKET_WEAPONS_UPDATE,
        AC_PACKET_PLAYER_SYNC);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    Internal_ResetPlayerState(playerid);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    Internal_ResetPlayerState(playerid);
    return 1;
}

hook OnPlayerSpawn(playerid)
{
    if (playerid >= 0 && playerid < MAX_PLAYERS)
    {
        new const nowTick = GetTickCount();

        sAcPlayers[playerid][E_AC_HAS_LAST_POS] = false;
        sAcPlayers[playerid][E_AC_SYNC_MODE] = 0;
        sAcPlayers[playerid][E_AC_GRACE_UNTIL] = nowTick + AC_TELEPORT_GRACE_MS;
        sAcPlayers[playerid][E_AC_STATE_GRACE_UNTIL] = nowTick + AC_SPAWN_SYNC_GRACE_MS;
        sAcPlayers[playerid][E_AC_SERVER_CACHE_VALID] = false;
        sAcPlayers[playerid][E_AC_CACHED_HEALTH] = 0.0;
        sAcPlayers[playerid][E_AC_CACHED_ARMOUR] = 0.0;
        sAcPlayers[playerid][E_AC_HP_MISMATCH] = 0;
        sAcPlayers[playerid][E_AC_ARMOUR_MISMATCH] = 0;
        sAcPlayers[playerid][E_AC_WEAPON_STREAK] = 0;
        sAcPlayers[playerid][E_AC_AMMO_STREAK] = 0;

        // Все модули уже применили спавн-позицию и HP/Armour, после чего
        // принудительно синхронизируем серверные значения с клиентом.
        defer AC_SpawnStateSync(playerid, Config_GetPlayerSessionToken(playerid));
    }
    return 1;
}

hook OnPlayerUpdate(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !IsPlayerConnected(playerid))
    {
        return 1;
    }
    Internal_CheckPacketFlood(playerid);
    return 1;
}

hook OnPlayerWeaponShot(playerid, WEAPON:weaponid, BULLET_HIT_TYPE:hittype, hitid, Float:fX, Float:fY, Float:fZ)
{
    #pragma unused hittype, hitid, fX, fY, fZ

    if (!Internal_CanCheckPlayer(playerid))
    {
        return 1;
    }

    // Одиночный выстрел после выброса оружия — это гонка пакетов,
    // а не доказательство читерства: блокируем выстрел и синхронизируем клиент.
    if (Weapons_IsTrackedFirearm(_:weaponid) &&
        Weapons_GetItemSlot(playerid, weaponid, false) == INVALID_STORAGE_ITEM_SLOT)
    {
        Character_SyncLayer1Weapons(playerid);
        return 0;
    }
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused dialogid, response, listitem, inputtext

    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 1;
    }

    if (!Internal_CheckDialogFlood(playerid))
    {
        return 0;
    }
    return 1;
}

public OnPlayerCommandReceived(playerid, cmd[], params[], flags)
{
    #pragma unused cmd, params, flags

    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 1;
    }

    if (!Internal_CheckCommandFlood(playerid))
    {
        return 0;
    }
    return 1;
}

// =============================================================================
//  8. Перехват входящих сетевых пакетов (Pawn.RakNet)
// =============================================================================

IPacket:207(playerid, BitStream:bs)
{
    if (!Internal_CanCheckPlayer(playerid))
    {
        return 1;
    }
    if (GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
    {
        return 1;
    }

    new syncData[PR_OnFootSync];
    BS_ReadOnFootSync(bs, syncData);
    sAcPacketsChecked++;

    new const weaponid = syncData[PR_weaponId];
    if (weaponid > 0 && !Internal_CheckWeaponOwnership(playerid, weaponid))
    {
        return 0;
    }

    Internal_CheckHealthSync(playerid, syncData[PR_health], syncData[PR_armour]);

    if (syncData[PR_surfingVehicleId] > 0)
    {
        new Float:sx = syncData[PR_position][0];
        new Float:sy = syncData[PR_position][1];
        new Float:sz = syncData[PR_position][2];
        Internal_StorePosition(playerid, sx, sy, sz, 1);
        return 1;
    }

    new Float:px = syncData[PR_position][0];
    new Float:py = syncData[PR_position][1];
    new Float:pz = syncData[PR_position][2];

    if (!Internal_ValidateMovement(playerid, px, py, pz, 1))
    {
        return 0;
    }
    return 1;
}

IPacket:200(playerid, BitStream:bs)
{
    if (!Internal_CanCheckPlayer(playerid))
    {
        return 1;
    }
    if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
    {
        return 1;
    }

    new syncData[PR_InCarSync];
    BS_ReadInCarSync(bs, syncData);
    sAcPacketsChecked++;

    new const serverVehicleId = GetPlayerVehicleID(playerid);
    if (serverVehicleId <= 0)
    {
        return 1;
    }

    if (syncData[PR_vehicleId] != serverVehicleId)
    {
        new details[176];
        format(details, sizeof(details),
            "Клиент управляет авто ID %d, сервер подтверждает ID %d",
            syncData[PR_vehicleId], serverVehicleId);
        Internal_ApplyViolation(playerid, AC_VIOL_VEHICLE_SPOOF, details);
        return 0;
    }

    Internal_CheckHealthSync(playerid, syncData[PR_playerHealth], syncData[PR_armour]);

    new Float:px = syncData[PR_position][0];
    new Float:py = syncData[PR_position][1];
    new Float:pz = syncData[PR_position][2];

    if (!Internal_ValidateMovement(playerid, px, py, pz, 2))
    {
        return 0;
    }
    return 1;
}

IPacket:203(playerid, BitStream:bs)
{
    if (!Internal_CanCheckPlayer(playerid))
    {
        return 1;
    }

    new aimData[PR_AimSync];
    BS_ReadAimSync(bs, aimData);
    sAcPacketsChecked++;

    if (aimData[PR_camMode] > 4)
    {
        Internal_ApplyViolation(playerid, AC_VIOL_SPEEDHACK, "Недопустимый режим камеры в пакете прицеливания");
        return 0;
    }

    new Float:fx = aimData[PR_camFrontVec][0];
    new Float:fy = aimData[PR_camFrontVec][1];
    new Float:fz = aimData[PR_camFrontVec][2];
    new Float:vectorLength = floatsqroot((fx * fx) + (fy * fy) + (fz * fz));

    if (!(vectorLength >= 0.5) || !(vectorLength <= 1.5))
    {
        Internal_ApplyViolation(playerid, AC_VIOL_SPEEDHACK, "Некорректный вектор направления камеры");
        return 0;
    }

    new Float:cx = aimData[PR_camPos][0];
    new Float:cy = aimData[PR_camPos][1];
    new Float:cz = aimData[PR_camPos][2];

    if (!Internal_IsCoordValid(cx, AC_WORLD_BOUND_MIN, AC_WORLD_BOUND_MAX) ||
        !Internal_IsCoordValid(cy, AC_WORLD_BOUND_MIN, AC_WORLD_BOUND_MAX) ||
        !Internal_IsCoordValid(cz, AC_WORLD_Z_MIN, AC_WORLD_Z_MAX))
    {
        Internal_ApplyViolation(playerid, AC_VIOL_SPEEDHACK, "Позиция камеры вне границ карты");
        return 0;
    }
    return 1;
}

IPacket:204(playerid, BitStream:bs)
{
    if (!Internal_CanCheckPlayer(playerid))
    {
        return 1;
    }

    new weaponData[PR_WeaponsUpdate];
    BS_ReadWeaponsUpdate(bs, weaponData);
    sAcPacketsChecked++;

    for (new slotId = 0; slotId < PR_MAX_WEAPON_SLOTS; slotId++)
    {
        if (!weaponData[PR_slotUpdated][slotId])
        {
            continue;
        }

        new const weaponid = weaponData[PR_slotWeaponId][slotId];
        if (!Weapons_IsTrackedFirearm(weaponid))
        {
            continue;
        }

        new const itemSlot = Weapons_GetItemSlot(playerid, WEAPON:weaponid, false);
        if (itemSlot == INVALID_STORAGE_ITEM_SLOT)
        {
            new details[176];
            format(details, sizeof(details),
                "Клиентский слот %d содержит ствол ID %d без предмета в Слое 1",
                slotId, weaponid);
            Internal_RegisterSyncMismatch(playerid, AC_VIOL_WEAPON_HACK, details);
            return 0;
        }

        sAcPlayers[playerid][E_AC_WEAPON_STREAK] = 0;

        new const clientAmmo = weaponData[PR_slotWeaponAmmo][slotId];
        new const serverAmmo = Storage_GetItemAmmo(itemSlot);
        if (clientAmmo > (serverAmmo + AC_AMMO_TOLERANCE))
        {
            new details[176];
            format(details, sizeof(details),
                "Клиент сообщает %d патронов, в Слое 1 хранится %d",
                clientAmmo, serverAmmo);
            Internal_RegisterSyncMismatch(playerid, AC_VIOL_AMMO_HACK, details);
            return 0;
        }

        sAcPlayers[playerid][E_AC_AMMO_STREAK] = 0;
    }
    return 1;
}

// =============================================================================
//  9. Команды (Pawn.CMD) и фоновые таймеры (y_timers)
// =============================================================================

CMD:acstats(playerid, params[])
{
    #pragma unused params

    if (!Account_IsLogged(playerid) || Account_GetAdminLevel(playerid) < 3)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Античит]: Команда доступна только администраторам.");
        return 1;
    }

    new message[208];
    format(message, sizeof(message),
        "[Античит]: Проверено пакетов: %d | Нарушений: %d | Киков: %d | Банов: %d.",
        sAcPacketsChecked, sAcTotalViolations, sAcTotalKicks, sAcTotalBans);
    SendClientMessage(playerid, COLOR_UI_INFO, message);

    new title[64];
    for (new i = 1; i < _:AC_VIOL_MAX; i++)
    {
        if (sAcViolationCounts[E_AC_VIOLATION:i] <= 0)
        {
            continue;
        }
        Internal_GetViolationTitleRu(E_AC_VIOLATION:i, title, sizeof(title));
        format(message, sizeof(message), "[Античит]: %s — %d.", title, sAcViolationCounts[E_AC_VIOLATION:i]);
        SendClientMessage(playerid, COLOR_UI_INFO, message);
    }

    format(message, sizeof(message),
        "[Античит]: Интеграционные тесты 9.2: %s.",
        AC_AreIntegrationTestsPassed() ? ("ПРОЙДЕНЫ") : ("НЕ ПРОЙДЕНЫ"));
    SendClientMessage(playerid, AC_AreIntegrationTestsPassed() ? COLOR_UI_SUCCESS : COLOR_UI_ERROR, message);
    return 1;
}

CMD:actest(playerid, params[])
{
    #pragma unused params

    if (!Account_IsLogged(playerid) || Account_GetAdminLevel(playerid) < 3)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Античит]: Команда доступна только администраторам.");
        return 1;
    }

    Internal_RunIntegrationTests();

    new message[208];
    format(message, sizeof(message),
        "[Античит/9.2] Роли: %s (%d) | Предметы: %s (%d) | Экономика: %s (%d).",
        (sAcTestRolesFailures == 0) ? ("ОК") : ("ОШИБКА"), sAcTestRolesFailures,
        (sAcTestItemsFailures == 0) ? ("ОК") : ("ОШИБКА"), sAcTestItemsFailures,
        (sAcTestEconomyFailures == 0) ? ("ОК") : ("ОШИБКА"), sAcTestEconomyFailures);
    SendClientMessage(playerid, COLOR_UI_INFO, message);

    format(message, sizeof(message),
        "[Античит/9.2] Порты: %s (%d) | Мьютексы 24x20: %s (%d) | Серийные номера: %s (%d).",
        (sAcTestPortsFailures == 0) ? ("ОК") : ("ОШИБКА"), sAcTestPortsFailures,
        (sAcTestMutexFailures == 0) ? ("ОК") : ("ОШИБКА"), sAcTestMutexFailures,
        (sAcTestSerialFailures == 0) ? ("ОК") : ("ОШИБКА"), sAcTestSerialFailures);
    SendClientMessage(playerid, COLOR_UI_INFO, message);

    SendClientMessage(playerid,
        AC_AreIntegrationTestsPassed() ? COLOR_UI_SUCCESS : COLOR_UI_ERROR,
        AC_AreIntegrationTestsPassed()
            ? "[Античит/9.2] Все автоматические проверки пройдены."
            : "[Античит/9.2] Обнаружены ошибки интеграционных проверок, см. консоль сервера.");
    return 1;
}

timer AC_SpawnStateSync[250](playerid, expectedToken)
{
    if (!IsPlayerConnected(playerid))
    {
        return;
    }
    if (Config_GetPlayerSessionToken(playerid) != expectedToken)
    {
        return;
    }
    if (!Character_IsLoaded(playerid) || !IsPlayerSpawned(playerid))
    {
        return;
    }

    new Float:serverHealth = 0.0;
    new Float:serverArmour = 0.0;
    if (!GetPlayerHealth(playerid, serverHealth))
    {
        return;
    }
    GetPlayerArmour(playerid, serverArmour);

    // Мёртвого персонажа не «лечим» античитом: HP <= 0 обрабатывает медицина.
    if (serverHealth <= 0.0)
    {
        return;
    }

    // Принудительная синхронизация серверных значений с клиентом.
    SetPlayerHealth(playerid, serverHealth);
    SetPlayerArmour(playerid, serverArmour);

    new const nowTick = GetTickCount();
    sAcPlayers[playerid][E_AC_CACHED_HEALTH] = serverHealth;
    sAcPlayers[playerid][E_AC_CACHED_ARMOUR] = serverArmour;
    sAcPlayers[playerid][E_AC_SERVER_CACHE_VALID] = true;
    sAcPlayers[playerid][E_AC_STATE_GRACE_UNTIL] = nowTick + AC_STATE_GRACE_MS;
    sAcPlayers[playerid][E_AC_GRACE_UNTIL] = nowTick + AC_TELEPORT_GRACE_MS;
    sAcPlayers[playerid][E_AC_HAS_LAST_POS] = false;
    sAcPlayers[playerid][E_AC_HP_MISMATCH] = 0;
    sAcPlayers[playerid][E_AC_ARMOUR_MISMATCH] = 0;
}

task Tick_AntiCheat[250]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }

    new const nowTick = GetTickCount();

    foreach (new playerid : Player)
    {
        if (sAcPlayers[playerid][E_AC_SCORE] <= 0)
        {
            continue;
        }

        if ((nowTick - sAcPlayers[playerid][E_AC_LAST_VIOLATION_TICK]) >= AC_SCORE_DECAY_INTERVAL_MS)
        {
            sAcPlayers[playerid][E_AC_SCORE]--;
            sAcPlayers[playerid][E_AC_LAST_VIOLATION_TICK] = nowTick;
        }
    }
}

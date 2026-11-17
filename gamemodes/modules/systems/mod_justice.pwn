/*
 * =============================================================================
 *  SAN ANDREAS RP — 100-уровневый розыск, тюрьмы, каторга и Warrant Decay
 *  Файл:      gamemodes/modules/systems/mod_justice.pwn
 *  Пункт:     ROADMAP [7.3] — 100-уровневый розыск, тюрьмы и Warrant Decay
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_justice_included
    #endinput
#endif
#define _mod_justice_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ ПРАВОСУДИЯ, СРОКОВ И ИСПРАВИТЕЛЬНЫХ УЧРЕЖДЕНИЙ
// =============================================================================

#define JUSTICE_MAX_WANTED_LEVEL                (100)
#define JUSTICE_SENTENCE_SECONDS_PER_LEVEL      (3600)
#define JUSTICE_DECAY_ACTIVE_SECONDS            (3600)
#define JUSTICE_AFK_THRESHOLD_MS                (15000)
#define JUSTICE_COMMAND_COOLDOWN_MS             (500)
#define JUSTICE_LABOR_COOLDOWN_MS               (60000)
#define JUSTICE_LABOR_REDUCTION_SECONDS         (180)
#define JUSTICE_ARREST_DISTANCE                  (3.0)
#define JUSTICE_DAILY_JOB_SKILL_GAIN            (1)
#define ROLE_ID_GUNRUNNER                       (16)
#define ROLE_ID_DEPUTY_SON                      (25)

#define DIALOG_JUSTICE_INFO                     (1600)

// =============================================================================
//  2. СТРУКТУРЫ СОСТОЯНИЯ, КООРДИНАТЫ ТЮРЕМ И МАССИВЫ (static stock)
// =============================================================================

static stock sJusticeLastCommandTick[MAX_PLAYERS];
static stock sJusticeLastLaborTick[MAX_PLAYERS];
static stock sJusticeLastArrestTick[MAX_PLAYERS];

static stock const Float:sJailPositions[3][3] =
{
    { 264.5, 77.5, 1001.0 },        // КПЗ полицейского участка
    { 214.6, 189.7, 1006.0 },       // Государственная тюрьма
    { 208.5, 122.5, 1004.5 }        // Федеральная тюрьма строгого режима
};

static stock const sJailInteriorIds[3] = { 6, 3, 10 };

static stock const Float:sReleasePositions[3][3] =
{
    { 1544.7, -1667.9, 13.6 },
    { 1544.7, -1667.9, 13.6 },
    { 1544.7, -1667.9, 13.6 }
};

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (static stock)
// =============================================================================

static stock Internal_GetJailIndex(E_JAIL_TYPE:jail_type)
{
    switch (jail_type)
    {
        case JAIL_TYPE_NONE:             return -1;
        case JAIL_TYPE_KPZ:              return 0;
        case JAIL_TYPE_STATE_PRISON:     return 1;
        case JAIL_TYPE_FEDERAL_SUPERMAX: return 2;
    }
    return -1;
}

static stock Internal_GetJailTitleRu(E_JAIL_TYPE:jail_type, output[], len = sizeof(output))
{
    switch (jail_type)
    {
        case JAIL_TYPE_KPZ:              format(output, len, "КПЗ полицейского участка");
        case JAIL_TYPE_STATE_PRISON:     format(output, len, "Государственная тюрьма");
        case JAIL_TYPE_FEDERAL_SUPERMAX: format(output, len, "Федеральная тюрьма строгого режима");
        default:                         format(output, len, "Исправительное учреждение");
    }
    return 1;
}

static stock Internal_FormatSentence(seconds, output[], len = sizeof(output))
{
    if (seconds <= 0)
    {
        format(output, len, "0 часов");
        return 1;
    }
    new const hours = (seconds + 3599) / 3600;
    new const minutes = (seconds % 3600) / 60;
    if (minutes > 0)
    {
        format(output, len, "%d ч. %d мин.", hours, minutes);
    }
    else
    {
        format(output, len, "%d ч.", hours);
    }
    return 1;
}

static stock bool:Internal_ParseNonNegativeInt(const input[], &outValue)
{
    outValue = 0;
    if (input[0] == EOS)
    {
        return false;
    }
    for (new i = 0, len = strlen(input); i < len; i++)
    {
        if (input[i] < '0' || input[i] > '9')
        {
            return false;
        }
        if (outValue > 200000000)
        {
            return false;
        }
        outValue = (outValue * 10) + (input[i] - '0');
    }
    return true;
}

static stock Internal_ParseWarrantParams(const params[], &targetid, &levels, reason[], reasonLen)
{
    targetid = -1;
    levels = 0;
    reason[0] = EOS;

    new i = 0;
    new const len = strlen(params);
    while (i < len && params[i] == ' ')
    {
        i++;
    }
    if (i >= len)
    {
        return 0;
    }

    new digits = 0;
    while (i < len && params[i] >= '0' && params[i] <= '9')
    {
        targetid = (targetid == -1 ? 0 : targetid * 10) + (params[i] - '0');
        i++;
        digits++;
    }
    if (digits == 0)
    {
        targetid = -1;
        return 0;
    }

    while (i < len && params[i] == ' ')
    {
        i++;
    }
    if (i >= len)
    {
        return 0;
    }

    digits = 0;
    while (i < len && params[i] >= '0' && params[i] <= '9')
    {
        levels = (levels * 10) + (params[i] - '0');
        i++;
        digits++;
    }
    if (digits == 0)
    {
        return 0;
    }

    while (i < len && params[i] == ' ')
    {
        i++;
    }
    if (i < len)
    {
        format(reason, reasonLen, "%s", params[i]);
    }
    else
    {
        format(reason, reasonLen, "Решение сотрудника правоохранительных органов");
    }
    return 1;
}

static stock bool:Internal_IsLawEnforcementActor(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return false;
    }
    new const orgId = Character_GetOrgId(playerid);
    if (orgId <= 0)
    {
        return false;
    }
    if (Organizations_GetPlayerRankOrder(playerid) < 2)
    {
        return false;
    }
    return Organizations_CanActInLegalField(orgId);
}

static stock Internal_TeleportToJail(playerid)
{
    new const E_JAIL_TYPE:jailType = Character_GetJailType(playerid);
    new const jailIndex = Internal_GetJailIndex(jailType);
    if (jailIndex < 0)
    {
        return 0;
    }

    SetPlayerInterior(playerid, sJailInteriorIds[jailIndex]);
    SetPlayerVirtualWorld(playerid, 0);
    Utils_SetPlayerPos(playerid, sJailPositions[jailIndex][0], sJailPositions[jailIndex][1], sJailPositions[jailIndex][2]);
    SetCameraBehindPlayer(playerid);
    SetPlayerSpecialAction(playerid, SPECIAL_ACTION_NONE);
    return 1;
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API ПРАВОСУДИЯ (Justice_*)
// =============================================================================

stock Justice_GetWantedLevel(playerid)
{
    return Character_GetWantedLevel(playerid);
}

stock Justice_GetJailSeconds(playerid)
{
    return Character_GetJailSecondsLeft(playerid);
}

stock bool:Justice_IsJailed(playerid)
{
    return (Character_GetJailSecondsLeft(playerid) > 0);
}

stock Justice_GetJailTypeByWantedLevel(wanted_level)
{
    if (wanted_level <= 5)  return _:JAIL_TYPE_KPZ;
    if (wanted_level <= 25) return _:JAIL_TYPE_STATE_PRISON;
    return _:JAIL_TYPE_FEDERAL_SUPERMAX;
}

stock Justice_GetSentenceSeconds(role_id, wanted_level)
{
    new seconds = wanted_level * JUSTICE_SENTENCE_SECONDS_PER_LEVEL;
    // Подпольный оружейник (роль №16) получает двойной срок за нелегальный оборот оружия
    if (role_id == ROLE_ID_GUNRUNNER)
    {
        seconds *= 2;
    }
    return seconds;
}

stock Justice_AddWantedLevel(playerid, delta, const reason[], actor_char_id = 0)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid) || delta == 0)
    {
        return 0;
    }

    new current = Character_GetWantedLevel(playerid);
    new appliedDelta = delta;

    // Сын Депутата (роль №25): розыск до 10 уровня растет вдвое медленнее
    if (delta > 0 &&
        Character_GetRoleId(playerid) == ROLE_ID_DEPUTY_SON &&
        (current + delta) <= 10)
    {
        appliedDelta = (delta + 1) / 2;
    }

    new newLevel = current + appliedDelta;
    if (newLevel < 0) newLevel = 0;
    if (newLevel > JUSTICE_MAX_WANTED_LEVEL) newLevel = JUSTICE_MAX_WANTED_LEVEL;

    if (newLevel == current)
    {
        return 0;
    }

    Character_SetWantedLevel(playerid, newLevel);
    Character_ResetActivePlaySeconds(playerid);

    new msg[256];
    if (newLevel > current)
    {
        format(msg, sizeof(msg),
            "Уровень розыска повышен: %d / 100. Причина: %s",
            newLevel, reason);
        SendClientMessage(playerid, COLOR_UI_WARNING, msg);
    }
    else
    {
        format(msg, sizeof(msg),
            "Уровень розыска снижен: %d / 100. Причина: %s",
            newLevel, reason);
        SendClientMessage(playerid, COLOR_UI_INFO, msg);
    }

    new const actualActor = (actor_char_id > 0) ? actor_char_id : Character_GetId(playerid);
    Audit_Log(actualActor, "WANTED_CHANGE", "JUSTICE", "CHARACTER",
        0, newLevel - current, reason);
    return 1;
}

stock Justice_SetWantedLevel(playerid, wanted_level, const reason[], actor_char_id = 0)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }
    if (wanted_level < 0) wanted_level = 0;
    if (wanted_level > JUSTICE_MAX_WANTED_LEVEL) wanted_level = JUSTICE_MAX_WANTED_LEVEL;

    new const oldLevel = Character_GetWantedLevel(playerid);
    Character_SetWantedLevel(playerid, wanted_level);
    Character_ResetActivePlaySeconds(playerid);

    new const actualActor = (actor_char_id > 0) ? actor_char_id : Character_GetId(playerid);
    Audit_Log(actualActor, "WANTED_SET", "JUSTICE", "CHARACTER",
        0, wanted_level - oldLevel, reason);
    return 1;
}

stock Justice_ReleasePlayer(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }

    new const E_JAIL_TYPE:jailType = Character_GetJailType(playerid);
    new const jailIndex = Internal_GetJailIndex(jailType);
    Character_SetJailState(playerid, 0, JAIL_TYPE_NONE, true);
    Character_ResetActivePlaySeconds(playerid);
    Survival_SetCuffed(playerid, false);

    new const releaseIndex = (jailIndex >= 0) ? jailIndex : 0;
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    Utils_SetPlayerPos(
        playerid,
        sReleasePositions[releaseIndex][0],
        sReleasePositions[releaseIndex][1],
        sReleasePositions[releaseIndex][2]);
    SetCameraBehindPlayer(playerid);

    SendClientMessage(playerid, COLOR_UI_SUCCESS,
        "Срок заключения истек. Вы освобождены и можете вернуться к обычной жизни.");
    Audit_Log(Character_GetId(playerid), "JAIL_RELEASE", "JUSTICE", "CHARACTER", 0, 0,
        "Освобождение после отбытия срока");
    return 1;
}

// Административная отправка в КПЗ/деморган (Фаза 10). Проверка RBAC выполняется в mod_admin.
stock Justice_AdminJail(playerid, seconds, const reason[])
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid) || seconds <= 0)
    {
        return 0;
    }

    Character_SetJailState(playerid, seconds, JAIL_TYPE_KPZ, true);
    Survival_SetCuffed(playerid, false);
    Internal_TeleportToJail(playerid);

    new msg[192];
    format(msg, sizeof(msg),
        "Администратор отправил вас в КПЗ на %d минут. Причина: %s", (seconds / 60) + 1, reason);
    SendClientMessage(playerid, COLOR_UI_ERROR, msg);
    Audit_Log(Character_GetId(playerid), "ADMIN_JAIL", "JUSTICE", "CHARACTER", 0, seconds, reason);
    return 1;
}

stock bool:Justice_ArrestPlayer(actorid, targetid)
{
    if (actorid < 0 || actorid >= MAX_PLAYERS || targetid < 0 || targetid >= MAX_PLAYERS)
    {
        return false;
    }
    if (!Character_IsLoaded(actorid) || !Character_IsLoaded(targetid))
    {
        return false;
    }
    if (actorid == targetid)
    {
        return false;
    }
    if (!Internal_IsLawEnforcementActor(actorid))
    {
        SendClientMessage(actorid, COLOR_UI_ERROR,
            "Арест может проводить только сотрудник правоохранительного органа с правом выдачи ордеров.");
        return false;
    }
    if (Character_GetJailSecondsLeft(actorid) > 0)
    {
        SendClientMessage(actorid, COLOR_UI_ERROR, "Заключенный не может проводить аресты.");
        return false;
    }
    if (Utils_GetDistanceBetweenPlayers(actorid, targetid) > JUSTICE_ARREST_DISTANCE)
    {
        SendClientMessage(actorid, COLOR_UI_ERROR, "Задержанный находится слишком далеко.");
        return false;
    }

    new const bool:isRestrained = Survival_IsCuffed(targetid) ||
        (GetPlayerSpecialAction(targetid) == SPECIAL_ACTION_HANDSUP);
    if (!isRestrained)
    {
        SendClientMessage(actorid, COLOR_UI_ERROR,
            "Для ареста задержанный должен быть в наручниках (/cuff) или с поднятыми руками.");
        return false;
    }
    if (Character_GetJailSecondsLeft(targetid) > 0)
    {
        SendClientMessage(actorid, COLOR_UI_ERROR, "Задержанный уже отбывает наказание.");
        return false;
    }

    new const wantedLevel = Character_GetWantedLevel(targetid);
    if (wantedLevel <= 0)
    {
        SendClientMessage(actorid, COLOR_UI_ERROR,
            "У задержанного нет активного розыска: оснований для ареста недостаточно.");
        return false;
    }

    new const sentence = Justice_GetSentenceSeconds(Character_GetRoleId(targetid), wantedLevel);
    new const E_JAIL_TYPE:jailType = E_JAIL_TYPE:Justice_GetJailTypeByWantedLevel(wantedLevel);

    Character_SetJailState(targetid, sentence, jailType, true);
    Character_SetWantedLevel(targetid, 0);
    Character_ResetActivePlaySeconds(targetid);
    Survival_SetCuffed(targetid, true);
    Internal_TeleportToJail(targetid);

    new jailName[48], sentenceText[48];
    Internal_GetJailTitleRu(jailType, jailName, sizeof(jailName));
    Internal_FormatSentence(sentence, sentenceText, sizeof(sentenceText));

    new msg[288];
    format(msg, sizeof(msg),
        "Вы арестованы. Уровень розыска: %d. Назначено наказание: %s в учреждении «%s».",
        wantedLevel, sentenceText, jailName);
    SendClientMessage(targetid, COLOR_UI_ERROR, msg);
    SendClientMessage(targetid, COLOR_UI_INFO,
        "Срок сокращается только активной игрой. Работа на каторге: /labor (не чаще одного раза в минуту).");

    format(msg, sizeof(msg),
        "Арест произведен. Задержанный направлен в «%s» на срок %s.",
        jailName, sentenceText);
    SendClientMessage(actorid, COLOR_UI_SUCCESS, msg);

    new details[192];
    format(details, sizeof(details),
        "Арест: розыск %d, срок %d сек., учреждение %s",
        wantedLevel, sentence, jailName);
    Audit_Log(Character_GetId(actorid), "ARREST", "JUSTICE", "CHARACTER",
        0, sentence, details);
    return true;
}

// Совместимый публичный контракт из TECH_CONTEXT.MD для изменения розыска
stock Char_ModifyWantedLevel(playerid, delta, const reason[])
{
    return Justice_AddWantedLevel(playerid, delta, reason, 0);
}

// =============================================================================
//  5. ХУКИ СИСТЕМНЫХ КОЛБЕКОВ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        sJusticeLastCommandTick[i] = 0;
        sJusticeLastLaborTick[i] = 0;
        sJusticeLastArrestTick[i] = 0;
    }

    printf("%s [Systems/Justice] Шкала розыска 0..100, тюрьмы и Warrant Decay инициализированы.",
        SERVER_LOG_PREFIX);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    sJusticeLastCommandTick[playerid] = 0;
    sJusticeLastLaborTick[playerid] = 0;
    sJusticeLastArrestTick[playerid] = 0;
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    sJusticeLastCommandTick[playerid] = 0;
    sJusticeLastLaborTick[playerid] = 0;
    sJusticeLastArrestTick[playerid] = 0;
    return 1;
}

hook OnPlayerSpawn(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (Character_GetJailSecondsLeft(playerid) > 0)
    {
        Internal_TeleportToJail(playerid);
        Survival_SetCuffed(playerid, true);
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "Вы находитесь в заключении. Срок отбывается только активной игрой, каторга: /labor.");
    }
    return 1;
}

// =============================================================================
//  6. ЕЖЕСЕКУНДНЫЙ ТАЙМЕР: СРОК, КАТОРГА И ЧЕСТНЫЙ WARRANT DECAY
// =============================================================================

task Tick_JusticeSecond[1000]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }

    new const nowTick = GetTickCount();

    foreach (new playerid : Player)
    {
        if (!Character_IsLoaded(playerid))
        {
            continue;
        }

        // AFK-игроки не отбывают срок и не теряют розыск
        if ((nowTick - gLastPlayerPacketTick[playerid]) > JUSTICE_AFK_THRESHOLD_MS)
        {
            continue;
        }

        new const jailSeconds = Character_GetJailSecondsLeft(playerid);
        if (jailSeconds > 0)
        {
            new const newSeconds = jailSeconds - 1;
            if (newSeconds <= 0)
            {
                Justice_ReleasePlayer(playerid);
            }
            else
            {
                new const E_JAIL_TYPE:jailType = Character_GetJailType(playerid);
                new const bool:persist = ((newSeconds % 60) == 0);
                Character_SetJailState(playerid, newSeconds, jailType, persist);

                if ((newSeconds % 300) == 0)
                {
                    new sentenceText[48];
                    Internal_FormatSentence(newSeconds, sentenceText, sizeof(sentenceText));
                    new msg[192];
                    format(msg, sizeof(msg),
                        "До освобождения осталось: %s. Работа на каторге: /labor.",
                        sentenceText);
                    SendClientMessage(playerid, COLOR_UI_INFO, msg);
                }
            }
            continue;
        }

        if (Character_GetJailType(playerid) != JAIL_TYPE_NONE)
        {
            Character_SetJailState(playerid, 0, JAIL_TYPE_NONE, true);
        }

        // Warrant Decay: 3600 секунд активной игры без AFK снижают розыск на 1
        if (Character_GetWantedLevel(playerid) > 0)
        {
            new const activeSeconds = Character_AddActivePlaySeconds(playerid, 1);
            if (activeSeconds >= JUSTICE_DECAY_ACTIVE_SECONDS)
            {
                Character_ResetActivePlaySeconds(playerid);
                Character_SetWantedLevel(playerid, Character_GetWantedLevel(playerid) - 1);

                new msg[192];
                format(msg, sizeof(msg),
                    "Давность преступления снизила уровень розыска до %d / 100.",
                    Character_GetWantedLevel(playerid));
                SendClientMessage(playerid, COLOR_UI_INFO, msg);
                Audit_Log(Character_GetId(playerid), "WARRANT_DECAY", "JUSTICE", "CHARACTER",
                    0, 1, "Естественное снижение уровня розыска за активную игру");
            }
        }
    }
}

// =============================================================================
//  7. КОМАНДЫ (Pawn.CMD)
// =============================================================================

CMD:arrest(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    new const nowTick = GetTickCount();
    if ((nowTick - sJusticeLastCommandTick[playerid]) < JUSTICE_COMMAND_COOLDOWN_MS ||
        (nowTick - sJusticeLastArrestTick[playerid]) < JUSTICE_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "Не так быстро: дождитесь завершения предыдущей операции.");
        return 1;
    }

    new targetid = -1;
    if (strlen(params) > 0)
    {
        new parsed = 0;
        if (!Internal_ParseNonNegativeInt(params, parsed))
        {
            SendClientMessage(playerid, COLOR_UI_INFO, "Использование: /arrest [id игрока]");
            return 1;
        }
        targetid = parsed;
    }
    else
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Использование: /arrest [id игрока]");
        return 1;
    }

    if (targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Игрок не найден в сети.");
        return 1;
    }

    sJusticeLastCommandTick[playerid] = nowTick;
    sJusticeLastArrestTick[playerid] = nowTick;
    Justice_ArrestPlayer(playerid, targetid);
    return 1;
}

CMD:warrant(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_IsLawEnforcementActor(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Выдавать ордера и повышать розыск могут только сотрудники правоохранительных органов.");
        return 1;
    }
    if (Character_GetJailSecondsLeft(playerid) > 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Заключенный не может выдавать ордера.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sJusticeLastCommandTick[playerid]) < JUSTICE_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "Не так быстро: дождитесь завершения предыдущей операции.");
        return 1;
    }
    sJusticeLastCommandTick[playerid] = nowTick;

    new targetid = -1, levels = 0;
    new reason[128];
    if (!Internal_ParseWarrantParams(params, targetid, levels, reason, sizeof(reason)))
    {
        SendClientMessage(playerid, COLOR_UI_INFO,
            "Использование: /warrant [id игрока] [уровни 1..100] [причина]");
        return 1;
    }
    if (targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Игрок не найден в сети.");
        return 1;
    }
    if (targetid == playerid)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Нельзя выдать ордер на самого себя.");
        return 1;
    }
    if (levels <= 0 || levels > JUSTICE_MAX_WANTED_LEVEL)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Уровень розыска должен быть от 1 до 100.");
        return 1;
    }

    Justice_AddWantedLevel(targetid, levels, reason, Character_GetId(playerid));

    new actorName[MAX_PLAYER_NAME + 1], targetName[MAX_PLAYER_NAME + 1];
    Character_GetRpName(playerid, actorName, sizeof(actorName));
    Character_GetRpName(targetid, targetName, sizeof(targetName));

    new msg[288];
    format(msg, sizeof(msg),
        "Сотрудник %s выдал ордер на %s. Уровень розыска: %d / 100. Причина: %s",
        actorName, targetName, Character_GetWantedLevel(targetid), reason);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    SendClientMessage(targetid, COLOR_UI_WARNING,
        "Правоохранительные органы выдали ордер на ваше задержание.");
    return 1;
}

CMD:clearwanted(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_IsLawEnforcementActor(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Снимать розыск могут только сотрудники правоохранительных органов.");
        return 1;
    }

    new targetid = -1;
    new parsed = 0;
    if (strlen(params) > 0 && Internal_ParseNonNegativeInt(params, parsed))
    {
        targetid = parsed;
    }
    else
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Использование: /clearwanted [id игрока]");
        return 1;
    }
    if (targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Игрок не найден в сети.");
        return 1;
    }
    if (targetid == playerid)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Нельзя снять розыск с самого себя этим способом.");
        return 1;
    }

    Justice_SetWantedLevel(targetid, 0, "Розыск снят сотрудником правоохранительных органов",
        Character_GetId(playerid));
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Розыск с игрока снят.");
    SendClientMessage(targetid, COLOR_UI_SUCCESS, "С вас снят розыск.");
    return 1;
}

CMD:sentence(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }

    new const jailSeconds = Character_GetJailSecondsLeft(playerid);
    if (jailSeconds <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Вы не находитесь в заключении.");
        return 1;
    }

    new const E_JAIL_TYPE:jailType = Character_GetJailType(playerid);
    new jailName[48], sentenceText[48], body[512];
    Internal_GetJailTitleRu(jailType, jailName, sizeof(jailName));
    Internal_FormatSentence(jailSeconds, sentenceText, sizeof(sentenceText));

    format(body, sizeof(body),
        "{FFC800}Учреждение:{FFFFFF} %s\n" \
        "{FFC800}Остаток срока:{FFFFFF} %s\n" \
        "{FFC800}Активное время до освобождения:{FFFFFF} только при активной игре без неактивности\n" \
        "{FFC800}Каторжные работы:{FFFFFF} /labor сокращает срок на %d минут\n\n" \
        "Срок отбывается только активной игрой. Время в режиме неактивности не засчитывается.",
        jailName,
        sentenceText,
        JUSTICE_LABOR_REDUCTION_SECONDS / 60);

    ShowPlayerDialog(
        playerid,
        DIALOG_JUSTICE_INFO,
        DIALOG_STYLE_MSGBOX,
        "{FFC800}Ваш срок заключения",
        body,
        "Понятно",
        "Закрыть");
    return 1;
}
alias:sentence("jail");

CMD:labor(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }

    new const jailSeconds = Character_GetJailSecondsLeft(playerid);
    if (jailSeconds <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Каторжные работы доступны только заключенным.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sJusticeLastLaborTick[playerid]) < JUSTICE_LABOR_COOLDOWN_MS)
    {
        new const remaining = (JUSTICE_LABOR_COOLDOWN_MS - (nowTick - sJusticeLastLaborTick[playerid])) / 1000;
        new msg[160];
        format(msg, sizeof(msg),
            "Вы устали. Следующий выход на каторгу возможен через %d сек.", remaining);
        SendClientMessage(playerid, COLOR_UI_WARNING, msg);
        return 1;
    }
    sJusticeLastLaborTick[playerid] = nowTick;

    new const E_JAIL_TYPE:jailType = Character_GetJailType(playerid);
    if (jailSeconds <= JUSTICE_LABOR_REDUCTION_SECONDS)
    {
        Justice_ReleasePlayer(playerid);
        SendClientMessage(playerid, COLOR_UI_SUCCESS,
            "Каторжные работы завершены, срок полностью погашен.");
    }
    else
    {
        new const newSeconds = jailSeconds - JUSTICE_LABOR_REDUCTION_SECONDS;
        Character_SetJailState(playerid, newSeconds, jailType, true);

        new sentenceText[48], msg[224];
        Internal_FormatSentence(newSeconds, sentenceText, sizeof(sentenceText));
        format(msg, sizeof(msg),
            "Вы отработали смену на каторге. Срок сокращен на %d минут. Осталось: %s.",
            JUSTICE_LABOR_REDUCTION_SECONDS / 60, sentenceText);
        SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    }

    Skills_Add(playerid, SKILL_MINING_LOGGING, JUSTICE_DAILY_JOB_SKILL_GAIN);
    Audit_Log(Character_GetId(playerid), "JAIL_LABOR", "JUSTICE", "CHARACTER",
        0, JUSTICE_LABOR_REDUCTION_SECONDS, "Каторжные работы в тюремной зоне");
    return 1;
}

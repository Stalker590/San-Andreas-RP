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
        case JAIL_TYPE_KPZ:              format(output, len, "Police station holding cell");
        case JAIL_TYPE_STATE_PRISON:     format(output, len, "State prison");
        case JAIL_TYPE_FEDERAL_SUPERMAX: format(output, len, "Maximum Security Federal Prison");
        default:                         format(output, len, "Correctional Facility");
    }
    return 1;
}

static stock Internal_FormatSentence(seconds, output[], len = sizeof(output))
{
    if (seconds <= 0)
    {
        format(output, len, "0 hours");
        return 1;
    }
    new const hours = (seconds + 3599) / 3600;
    new const minutes = (seconds % 3600) / 60;
    if (minutes > 0)
    {
        format(output, len, "%d h. %d min.", hours, minutes);
    }
    else
    {
        format(output, len, "%d h.", hours);
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
        format(reason, reasonLen, "Law enforcement officer's decision");
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
            "Wanted level increased: %d / 100. Reason: %s",
            newLevel, reason);
        SendClientMessage(playerid, COLOR_UI_WARNING, msg);
    }
    else
    {
        format(msg, sizeof(msg),
            "Wanted level reduced: %d / 100. Reason: %s",
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
        "The term of imprisonment has expired. You are freed and can return to normal life.");
    Audit_Log(Character_GetId(playerid), "JAIL_RELEASE", "JUSTICE", "CHARACTER", 0, 0,
        "Release after serving time");
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
        "The administrator sent you to the holding cell for %d minutes. Reason: %s", (seconds / 60) + 1, reason);
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
            "An arrest can only be made by a law enforcement officer with the authority to issue warrants.");
        return false;
    }
    if (Character_GetJailSecondsLeft(actorid) > 0)
    {
        SendClientMessage(actorid, COLOR_UI_ERROR, "The prisoner cannot make arrests.");
        return false;
    }
    if (Utils_GetDistanceBetweenPlayers(actorid, targetid) > JUSTICE_ARREST_DISTANCE)
    {
        SendClientMessage(actorid, COLOR_UI_ERROR, "The detainee is too far away.");
        return false;
    }

    new const bool:isRestrained = Survival_IsCuffed(targetid) ||
        (GetPlayerSpecialAction(targetid) == SPECIAL_ACTION_HANDSUP);
    if (!isRestrained)
    {
        SendClientMessage(actorid, COLOR_UI_ERROR,
            "To be arrested, the detainee must be handcuffed (/cuff) or with their hands raised.");
        return false;
    }
    if (Character_GetJailSecondsLeft(targetid) > 0)
    {
        SendClientMessage(actorid, COLOR_UI_ERROR, "The detainee is already serving his sentence.");
        return false;
    }

    new const wantedLevel = Character_GetWantedLevel(targetid);
    if (wantedLevel <= 0)
    {
        SendClientMessage(actorid, COLOR_UI_ERROR,
            "The detainee is not actively wanted: there are insufficient grounds for arrest.");
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
        "You are under arrest. Wanted level: %d. Punishment assigned: %s in the institution \"%s\".",
        wantedLevel, sentenceText, jailName);
    SendClientMessage(targetid, COLOR_UI_ERROR, msg);
    SendClientMessage(targetid, COLOR_UI_INFO,
        "The period is reduced only by active play. Hard labor: /labor (no more than once per minute).");

    format(msg, sizeof(msg),
        "The arrest has been made. The detainee was sent to \"%s\" for a period of %s.",
        jailName, sentenceText);
    SendClientMessage(actorid, COLOR_UI_SUCCESS, msg);

    new details[192];
    format(details, sizeof(details),
        "Arrest: wanted %d, term %d seconds, establishment %s",
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

    printf("%s [Systems/Justice] Wanted scale 0..100, prisons and Warrant Decay initialized.",
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
            "You are in custody. The term is served only by active play, hard labor: /labor.");
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
                        "Remaining until release: %s. Hard labor: /labor.",
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
                    "The recency of the crime has reduced the wanted level to %d / 100.",
                    Character_GetWantedLevel(playerid));
                SendClientMessage(playerid, COLOR_UI_INFO, msg);
                Audit_Log(Character_GetId(playerid), "WARRANT_DECAY", "JUSTICE", "CHARACTER",
                    0, 1, "Natural reduction in wanted level for active play");
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
        SendClientMessage(playerid, COLOR_UI_WARNING, "Not so fast: Wait for the previous operation to complete.");
        return 1;
    }

    new targetid = -1;
    if (strlen(params) > 0)
    {
        new parsed = 0;
        if (!Internal_ParseNonNegativeInt(params, parsed))
        {
            SendClientMessage(playerid, COLOR_UI_INFO, "Usage: /arrest [player id]");
            return 1;
        }
        targetid = parsed;
    }
    else
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Usage: /arrest [player id]");
        return 1;
    }

    if (targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The player was not found online.");
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
            "Only law enforcement officers can issue warrants and increase the wanted list.");
        return 1;
    }
    if (Character_GetJailSecondsLeft(playerid) > 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "A prisoner cannot issue warrants.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sJusticeLastCommandTick[playerid]) < JUSTICE_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "Not so fast: Wait for the previous operation to complete.");
        return 1;
    }
    sJusticeLastCommandTick[playerid] = nowTick;

    new targetid = -1, levels = 0;
    new reason[128];
    if (!Internal_ParseWarrantParams(params, targetid, levels, reason, sizeof(reason)))
    {
        SendClientMessage(playerid, COLOR_UI_INFO,
            "Usage: /warrant [player id] [levels 1..100] [reason]");
        return 1;
    }
    if (targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The player was not found online.");
        return 1;
    }
    if (targetid == playerid)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "You can't issue a warrant against yourself.");
        return 1;
    }
    if (levels <= 0 || levels > JUSTICE_MAX_WANTED_LEVEL)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The wanted level must be from 1 to 100.");
        return 1;
    }

    Justice_AddWantedLevel(targetid, levels, reason, Character_GetId(playerid));

    new actorName[MAX_PLAYER_NAME + 1], targetName[MAX_PLAYER_NAME + 1];
    Character_GetRpName(playerid, actorName, sizeof(actorName));
    Character_GetRpName(targetid, targetName, sizeof(targetName));

    new msg[288];
    format(msg, sizeof(msg),
        "Officer %s issued a warrant for %s. Wanted level: %d / 100. Reason: %s",
        actorName, targetName, Character_GetWantedLevel(targetid), reason);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    SendClientMessage(targetid, COLOR_UI_WARNING,
        "Law enforcement authorities have issued a warrant for your detention.");
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
            "Only law enforcement officers can cancel a search.");
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
        SendClientMessage(playerid, COLOR_UI_INFO, "Usage: /clearwanted [player id]");
        return 1;
    }
    if (targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The player was not found online.");
        return 1;
    }
    if (targetid == playerid)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "You cannot remove the search from yourself in this way.");
        return 1;
    }

    Justice_SetWantedLevel(targetid, 0, "The search was canceled by a law enforcement officer",
        Character_GetId(playerid));
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player's search has been lifted.");
    SendClientMessage(targetid, COLOR_UI_SUCCESS, "The search for you has been lifted.");
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
        SendClientMessage(playerid, COLOR_UI_INFO, "You are not in prison.");
        return 1;
    }

    new const E_JAIL_TYPE:jailType = Character_GetJailType(playerid);
    new jailName[48], sentenceText[48], body[512];
    Internal_GetJailTitleRu(jailType, jailName, sizeof(jailName));
    Internal_FormatSentence(jailSeconds, sentenceText, sizeof(sentenceText));

    format(body, sizeof(body),
        "{FFC800}Institution:{FFFFFF} %s\n" \
        "{FFC800}Remaining term:{FFFFFF} %s\n" \
        "{FFC800}Active time until release:{FFFFFF} only with active play without inactivity\n" \
        "{FFC800}Hard labor:{FFFFFF} /labor reduces the term by %d minutes\n\n" \
        "The term is served only by active play. Time in inactivity mode is not counted.",
        jailName,
        sentenceText,
        JUSTICE_LABOR_REDUCTION_SECONDS / 60);

    ShowPlayerDialog(
        playerid,
        DIALOG_JUSTICE_INFO,
        DIALOG_STYLE_MSGBOX,
        "{FFC800}Your term of imprisonment",
        body,
        "Understood",
        "Close");
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
        SendClientMessage(playerid, COLOR_UI_ERROR, "Hard labor is only available to prisoners.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sJusticeLastLaborTick[playerid]) < JUSTICE_LABOR_COOLDOWN_MS)
    {
        new const remaining = (JUSTICE_LABOR_COOLDOWN_MS - (nowTick - sJusticeLastLaborTick[playerid])) / 1000;
        new msg[160];
        format(msg, sizeof(msg),
            "Are you tired. The next exit to hard labor is possible in %d seconds.", remaining);
        SendClientMessage(playerid, COLOR_UI_WARNING, msg);
        return 1;
    }
    sJusticeLastLaborTick[playerid] = nowTick;

    new const E_JAIL_TYPE:jailType = Character_GetJailType(playerid);
    if (jailSeconds <= JUSTICE_LABOR_REDUCTION_SECONDS)
    {
        Justice_ReleasePlayer(playerid);
        SendClientMessage(playerid, COLOR_UI_SUCCESS,
            "Hard labor has been completed and the term has been fully repaid.");
    }
    else
    {
        new const newSeconds = jailSeconds - JUSTICE_LABOR_REDUCTION_SECONDS;
        Character_SetJailState(playerid, newSeconds, jailType, true);

        new sentenceText[48], msg[224];
        Internal_FormatSentence(newSeconds, sentenceText, sizeof(sentenceText));
        format(msg, sizeof(msg),
            "You worked your shift at hard labor. The period has been reduced by %d minutes. Remaining: %s.",
            JUSTICE_LABOR_REDUCTION_SECONDS / 60, sentenceText);
        SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    }

    Skills_Add(playerid, SKILL_MINING_LOGGING, JUSTICE_DAILY_JOB_SKILL_GAIN);
    Audit_Log(Character_GetId(playerid), "JAIL_LABOR", "JUSTICE", "CHARACTER",
        0, JUSTICE_LABOR_REDUCTION_SECONDS, "Hard labor in a prison zone");
    return 1;
}

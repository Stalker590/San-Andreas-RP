/*
 * =============================================================================
 *  SAN ANDREAS RP — Базовые консольные и ролевые команды (Pawn.CMD)
 *  Файл:      gamemodes/modules/ui/mod_commands.pwn
 *  Пункт:     ROADMAP [4.4] — Базовые консольные и ролевые команды (ui/mod_commands.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_commands_included
    #endinput
#endif
#define _mod_commands_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ РАДИУСОВ ПРОСТРАНСТВЕННОГО ЧАТА И ВЗАИМОДЕЙСТВИЯ
// =============================================================================

#define RP_RADIUS_WHISPER                       (4.0)
#define RP_RADIUS_NORMAL                        (15.0)
#define RP_RADIUS_ACTION                        (18.0)
#define RP_RADIUS_SHOUT                         (32.0)
#define RP_INTERACT_DISTANCE                    (3.0)
#define PICKPOCKET_COOLDOWN_SEC                 (45)

#define COLOR_RP_TALK                           (0xECEFF1FF)
#define COLOR_RP_SHOUT                          (0xFFF59DFF)
#define COLOR_RP_WHISPER                        (0xB0BEC5FF)
#define COLOR_RP_OOC                            (0x90A4AEFF)

// =============================================================================
//  2. ВНУТРЕННЕЕ СОСТОЯНИЕ КУЛДАУНОВ И ПАРСЕРЫ ПАРАМЕТРОВ (static stock)
// =============================================================================

static stock sLastPickpocketTime[MAX_PLAYERS];

/*
 * Извлекает непустую текстовую строку без ведущих пробелов.
 */
static stock bool:Internal_ParseTrimmedText(const params[], output[], maxLen = sizeof(output))
{
    output[0] = '\0';
    new idx = 0;
    while (params[idx] == ' ' || params[idx] == '\t')
    {
        idx++;
    }
    if (params[idx] == '\0')
    {
        return false;
    }
    format(output, maxLen, "%s", params[idx]);
    return (strlen(output) > 0);
}

/*
 * Извлекает одно целое число из строки параметров.
 */
static stock bool:Internal_ParseSingleInt(const params[], &outVal)
{
    new idx = 0;
    while (params[idx] == ' ' || params[idx] == '\t')
    {
        idx++;
    }
    if (params[idx] == '\0')
    {
        return false;
    }
    new start = idx;
    if (params[idx] == '-' || params[idx] == '+')
    {
        idx++;
    }
    if (params[idx] < '0' || params[idx] > '9')
    {
        return false;
    }
    new token[24];
    new tLen = 0;
    while (params[start] != '\0' && params[start] != ' ' && params[start] != '\t' && tLen < sizeof(token) - 1)
    {
        token[tLen++] = params[start++];
    }
    token[tLen] = '\0';
    outVal = strval(token);
    return true;
}

/*
 * Извлекает два целых числа (например: targetid и amount) из строки параметров.
 */
static stock bool:Internal_ParseTwoInts(const params[], &firstVal, &secondVal)
{
    new idx = 0;
    while (params[idx] == ' ' || params[idx] == '\t')
    {
        idx++;
    }
    if (params[idx] < '0' || params[idx] > '9')
    {
        return false;
    }
    new tok1[24];
    new len1 = 0;
    while (params[idx] >= '0' && params[idx] <= '9' && len1 < sizeof(tok1) - 1)
    {
        tok1[len1++] = params[idx++];
    }
    tok1[len1] = '\0';

    while (params[idx] == ' ' || params[idx] == '\t')
    {
        idx++;
    }
    if (params[idx] < '0' || params[idx] > '9')
    {
        return false;
    }
    new tok2[24];
    new len2 = 0;
    while (params[idx] >= '0' && params[idx] <= '9' && len2 < sizeof(tok2) - 1)
    {
        tok2[len2++] = params[idx++];
    }
    tok2[len2] = '\0';

    firstVal = strval(tok1);
    secondVal = strval(tok2);
    return true;
}

/*
 * Возвращает отображаемое РП-имя игрока (с учетом балаклавы/маски и замены '_' на пробел).
 */
static stock Internal_GetRoleplayName(playerid, output[], len = sizeof(output))
{
    if (Survival_IsMasked(playerid))
    {
        format(output, len, "Unknown in mask #%d", 100 + playerid);
        return 1;
    }

    GetPlayerName(playerid, output, len);
    for (new idx = 0; output[idx] != '\0'; idx++)
    {
        if (output[idx] == '_')
        {
            output[idx] = ' ';
        }
    }
    return 1;
}

/*
 * Пространственная рассылка сообщения всем игрокам в заданном радиусе
 * в том же виртуальном мире и интерьере.
 */
stock Commands_SendProximityMessage(playerid, Float:radius, color, const message[])
{
    if (!IsPlayerConnected(playerid))
    {
        return 0;
    }

    new Float:x = 0.0, Float:y = 0.0, Float:z = 0.0;
    GetPlayerPos(playerid, x, y, z);
    new worldId = GetPlayerVirtualWorld(playerid);
    new interiorId = GetPlayerInterior(playerid);

    for (new targetid = 0; targetid < MAX_PLAYERS; targetid++)
    {
        if (!IsPlayerConnected(targetid) || !Character_IsLoaded(targetid))
        {
            continue;
        }
        if (Utils_IsPlayerNearPoint(targetid, radius, x, y, z, interiorId, worldId))
        {
            SendClientMessage(targetid, color, message);
        }
    }
    return 1;
}

/*
 * Списание указанной суммы физических наличных USD (ITEM_ID_CASH_BUNDLE)
 * из Слоя 1 и Слоя 2 инвентаря персонажа.
 */
static stock bool:Internal_RemovePhysicalCash(playerid, amount_usd)
{
    if (amount_usd <= 0 || Character_GetPhysicalCashUsd(playerid) < amount_usd)
    {
        return false;
    }

    new remaining = amount_usd;
    new storages[2];
    storages[0] = Character_GetLayer1Slot(playerid);
    storages[1] = Character_GetLayer2Slot(playerid);

    for (new stIdx = 0; stIdx < 2 && remaining > 0; stIdx++)
    {
        new stSlot = storages[stIdx];
        if (!Storage_IsValidSlot(stSlot))
        {
            continue;
        }

        new itemSlot = Storage_GetFirstItemSlot(stSlot);
        while (itemSlot != INVALID_ITEM_SLOT && remaining > 0)
        {
            new nextSlot = Storage_GetNextItemSlot(itemSlot);
            if (Storage_GetItemDefId(itemSlot) == ITEM_ID_CASH_BUNDLE)
            {
                new stackAmt = Storage_GetItemAmount(itemSlot);
                new takeAmt = (stackAmt > remaining) ? remaining : stackAmt;
                if (Storage_RemoveItem(stSlot, itemSlot, takeAmt))
                {
                    remaining -= takeAmt;
                }
            }
            itemSlot = nextSlot;
        }
    }

    return (remaining == 0);
}

/*
 * Проверка наличия предмета по definition_id в Слое 1 игрока.
 */
static stock bool:Internal_HasItemInLayer1(playerid, def_id)
{
    new layer1 = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1))
    {
        return false;
    }
    new itemSlot = Storage_GetFirstItemSlot(layer1);
    while (itemSlot != INVALID_ITEM_SLOT)
    {
        if (Storage_GetItemDefId(itemSlot) == def_id && Storage_GetItemAmount(itemSlot) > 0)
        {
            return true;
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }
    return false;
}

// =============================================================================
//  3. КОМАНДЫ ИНВЕНТАРЯ, ИНТЕРФЕЙСА И РАЦИИ (/inv, /i, /hud, /radio)
// =============================================================================

CMD:inv(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: Your character has not yet been loaded.");
        return 1;
    }
    Dialogs_OpenInventory(playerid, INV_VIEW_LAYER_1);
    return 1;
}
alias:inv("i");

CMD:hud(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    new bool:nextState = !HUD_IsVisible(playerid);
    HUD_SetVisible(playerid, nextState);
    if (nextState)
    {
        SendClientMessage(playerid, COLOR_SUCCESS, "[UI]: Text survival HUD enabled.");
    }
    else
    {
        SendClientMessage(playerid, COLOR_INFO, "[UI]: Survival text HUD is hidden.");
    }
    return 1;
}

CMD:radio(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_HasItemInLayer1(playerid, ITEM_ID_WALKIE_TALKIE))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Communication]: There is no walkie-talkie in your external inventory (Layer 1)!");
        return 1;
    }

    new freqKhz = 0;
    if (!Internal_ParseSingleInt(params, freqKhz) || freqKhz < 0 || freqKhz > 999999)
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /radio [frequency in kHz, for example 104500, or 0 to turn off]");
        return 1;
    }

    Survival_SetRadioFreqKhz(playerid, freqKhz);
    if (freqKhz == 0)
    {
        SendClientMessage(playerid, COLOR_INFO, "[Communication]: The walkie-talkie is turned off.");
    }
    else
    {
        new msg[128];
        format(msg, sizeof(msg), "[Communication]: You have tuned the radio to the frequency %d.%03d MHz (%d kHz).", freqKhz / 1000, freqKhz % 1000, freqKhz);
        SendClientMessage(playerid, COLOR_SUCCESS, msg);
    }
    return 1;
}

// =============================================================================
//  4. КОМАНДЫ РОЛЕВОЙ ОТЫГРОВКИ (/me, /do, /try, /todo, /b, /s, /w)
// =============================================================================

CMD:me(playerid, params[])
{
    if (!Character_IsLoaded(playerid)) return 1;

    new actionText[128];
    if (!Internal_ParseTrimmedText(params, actionText, sizeof(actionText)) || strlen(actionText) < 2)
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /me [first person action]");
        return 1;
    }

    new rpName[MAX_PLAYER_NAME + 8];
    Internal_GetRoleplayName(playerid, rpName, sizeof(rpName));

    new outMsg[192];
    format(outMsg, sizeof(outMsg), "* %s %s", rpName, actionText);
    Commands_SendProximityMessage(playerid, RP_RADIUS_ACTION, COLOR_RP_ME, outMsg);
    SetPlayerChatBubble(playerid, actionText, COLOR_RP_ME, RP_RADIUS_ACTION, 6000);
    return 1;
}

CMD:do(playerid, params[])
{
    if (!Character_IsLoaded(playerid)) return 1;

    new descText[128];
    if (!Internal_ParseTrimmedText(params, descText, sizeof(descText)) || strlen(descText) < 2)
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /do [describing the environment or effect from a third person]");
        return 1;
    }

    new rpName[MAX_PLAYER_NAME + 8];
    Internal_GetRoleplayName(playerid, rpName, sizeof(rpName));

    new outMsg[192];
    format(outMsg, sizeof(outMsg), "* %s (( %s ))", descText, rpName);
    Commands_SendProximityMessage(playerid, RP_RADIUS_ACTION, COLOR_RP_DO, outMsg);
    SetPlayerChatBubble(playerid, descText, COLOR_RP_DO, RP_RADIUS_ACTION, 6000);
    return 1;
}

CMD:try(playerid, params[])
{
    if (!Character_IsLoaded(playerid)) return 1;

    new attemptText[112];
    if (!Internal_ParseTrimmedText(params, attemptText, sizeof(attemptText)) || strlen(attemptText) < 2)
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /try [attempt to perform an action with a probabilistic outcome]");
        return 1;
    }

    new rpName[MAX_PLAYER_NAME + 8];
    Internal_GetRoleplayName(playerid, rpName, sizeof(rpName));

    new bool:isSuccess = (random(100) < 50);
    new resultTag[32];
    if (isSuccess)
    {
        format(resultTag, sizeof(resultTag), "{66BB6A}[Successful]");
    }
    else
    {
        format(resultTag, sizeof(resultTag), "{EF5350}[Failed]");
    }

    new outMsg[192];
    format(outMsg, sizeof(outMsg), "* %s %s %s", rpName, attemptText, resultTag);
    Commands_SendProximityMessage(playerid, RP_RADIUS_ACTION, COLOR_RP_ME, outMsg);
    return 1;
}

CMD:todo(playerid, params[])
{
    if (!Character_IsLoaded(playerid)) return 1;

    new fullText[144];
    if (!Internal_ParseTrimmedText(params, fullText, sizeof(fullText)) || strlen(fullText) < 3)
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /todo [phrase]*[action]");
        return 1;
    }

    new starPos = strfind(fullText, "*", true);
    if (starPos <= 0 || fullText[starPos + 1] == '\0')
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /todo [phrase]*[action] (separate the phrase and action with an asterisk *)");
        return 1;
    }

    new speechPart[96];
    new actionPart[96];
    strmid(speechPart, fullText, 0, starPos, sizeof(speechPart));
    strmid(actionPart, fullText, starPos + 1, strlen(fullText), sizeof(actionPart));

    new rpName[MAX_PLAYER_NAME + 8];
    Internal_GetRoleplayName(playerid, rpName, sizeof(rpName));

    new outMsg[220];
    format(outMsg, sizeof(outMsg), "- \"%s,\" said %s, {C2A2DA}%s", speechPart, rpName, actionPart);
    Commands_SendProximityMessage(playerid, RP_RADIUS_NORMAL, COLOR_RP_TALK, outMsg);
    SetPlayerChatBubble(playerid, speechPart, COLOR_RP_TALK, RP_RADIUS_NORMAL, 6000);
    return 1;
}

CMD:b(playerid, params[])
{
    if (!Character_IsLoaded(playerid)) return 1;

    new oocText[128];
    if (!Internal_ParseTrimmedText(params, oocText, sizeof(oocText)))
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /b [out-of-game OOC message]");
        return 1;
    }

    new rawName[MAX_PLAYER_NAME + 1];
    GetPlayerName(playerid, rawName, sizeof(rawName));

    new outMsg[192];
    format(outMsg, sizeof(outMsg), "(( %s [%d]: %s ))", rawName, playerid, oocText);
    Commands_SendProximityMessage(playerid, RP_RADIUS_NORMAL, COLOR_RP_OOC, outMsg);
    return 1;
}

CMD:shout(playerid, params[])
{
    if (!Character_IsLoaded(playerid)) return 1;

    new shoutText[128];
    if (!Internal_ParseTrimmedText(params, shoutText, sizeof(shoutText)))
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /s [scream text]");
        return 1;
    }

    new rpName[MAX_PLAYER_NAME + 8];
    Internal_GetRoleplayName(playerid, rpName, sizeof(rpName));

    new outMsg[192];
    format(outMsg, sizeof(outMsg), "%s [%d] shouts: %s!", rpName, playerid, shoutText);
    Commands_SendProximityMessage(playerid, RP_RADIUS_SHOUT, COLOR_RP_SHOUT, outMsg);
    SetPlayerChatBubble(playerid, shoutText, COLOR_RP_SHOUT, RP_RADIUS_SHOUT, 7000);
    ApplyAnimation(playerid, "ON_LOOKERS", "shout_01", 4.1, false, false, false, false, 0, SYNC_ALL);
    return 1;
}
alias:shout("s");

CMD:whisper(playerid, params[])
{
    if (!Character_IsLoaded(playerid)) return 1;

    new whisperText[128];
    if (!Internal_ParseTrimmedText(params, whisperText, sizeof(whisperText)))
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /w [whisper text]");
        return 1;
    }

    new rpName[MAX_PLAYER_NAME + 8];
    Internal_GetRoleplayName(playerid, rpName, sizeof(rpName));

    new outMsg[192];
    format(outMsg, sizeof(outMsg), "%s [%d] whispers: %s", rpName, playerid, whisperText);
    Commands_SendProximityMessage(playerid, RP_RADIUS_WHISPER, COLOR_RP_WHISPER, outMsg);
    return 1;
}
alias:whisper("w");

// =============================================================================
//  5. КОМАНДЫ НАРУЧНИКОВ, ОБЫСКА И КАРМАННОЙ КРАЖИ (/cuff, /frisk, /search, /pickpocket)
// =============================================================================

CMD:cuff(playerid, params[])
{
    if (!Character_IsLoaded(playerid)) return 1;

    new targetid = INVALID_PLAYER_ID;
    if (!Internal_ParseSingleInt(params, targetid) || targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /cuff [player id]");
        return 1;
    }
    if (targetid == playerid)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Bug]: You cannot handcuff yourself.");
        return 1;
    }
    if (Utils_GetDistanceBetweenPlayers(playerid, targetid) > RP_INTERACT_DISTANCE)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: The player is too far away from you.");
        return 1;
    }

    if (!Survival_IsCuffed(targetid))
    {
        if (!Internal_HasItemInLayer1(playerid, ITEM_ID_HANDCUFFS))
        {
            SendClientMessage(playerid, COLOR_ERROR, "[Error]: You don't have steel handcuffs in Layer 1!");
            return 1;
        }
        Survival_SetCuffed(targetid, true);

        new actorName[MAX_PLAYER_NAME + 8];
        new targetName[MAX_PLAYER_NAME + 8];
        Internal_GetRoleplayName(playerid, actorName, sizeof(actorName));
        Internal_GetRoleplayName(targetid, targetName, sizeof(targetName));

        new rpMsg[160];
        format(rpMsg, sizeof(rpMsg), "* %s put %s's hands behind his back and snapped the steel handcuffs.", actorName, targetName);
        Commands_SendProximityMessage(playerid, RP_RADIUS_ACTION, COLOR_RP_ME, rpMsg);
    }
    else
    {
        Survival_SetCuffed(targetid, false);

        new actorName[MAX_PLAYER_NAME + 8];
        new targetName[MAX_PLAYER_NAME + 8];
        Internal_GetRoleplayName(playerid, actorName, sizeof(actorName));
        Internal_GetRoleplayName(targetid, targetName, sizeof(targetName));

        new rpMsg[160];
        format(rpMsg, sizeof(rpMsg), "* %s removed the steel handcuffs from %s's wrists.", actorName, targetName);
        Commands_SendProximityMessage(playerid, RP_RADIUS_ACTION, COLOR_RP_ME, rpMsg);
    }
    return 1;
}

/*
 * /frisk [id] — поверхностный досмотр внешнего снаряжения (Слой 1).
 * Не раскрывает содержимое потайного кармана (Слой 2).
 */
CMD:frisk(playerid, params[])
{
    if (!Character_IsLoaded(playerid)) return 1;
    if (Survival_IsCuffed(playerid))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: You are handcuffed and cannot conduct a search.");
        return 1;
    }

    new targetid = INVALID_PLAYER_ID;
    if (!Internal_ParseSingleInt(params, targetid) || targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /frisk [player id]");
        return 1;
    }
    if (targetid == playerid)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Bug]: Use /inv to view your inventory.");
        return 1;
    }
    if (Utils_GetDistanceBetweenPlayers(playerid, targetid) > RP_INTERACT_DISTANCE)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: The player is too far from you (maximum 3.0 m).");
        return 1;
    }

    new actorName[MAX_PLAYER_NAME + 8];
    new targetName[MAX_PLAYER_NAME + 8];
    Internal_GetRoleplayName(playerid, actorName, sizeof(actorName));
    Internal_GetRoleplayName(targetid, targetName, sizeof(targetName));

    new rpMsg[160];
    format(rpMsg, sizeof(rpMsg), "* %s patted outer clothing and external pockets %s.", actorName, targetName);
    Commands_SendProximityMessage(playerid, RP_RADIUS_ACTION, COLOR_RP_ME, rpMsg);

    Dialogs_OpenSearchTarget(playerid, targetid, false, false);
    return 1;
}

/*
 * /search [id] — полный обыск с доступом к Слою 1 и Слою 2 и правом изъятия предметов.
 * Требует, чтобы цель находилась в наручниках (либо с поднятыми руками).
 * Учитывает перк PERK_HIDE_CASH_CRIME (Роль №3: Ночная Бабочка).
 */
CMD:search(playerid, params[])
{
    if (!Character_IsLoaded(playerid)) return 1;
    if (Survival_IsCuffed(playerid))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: You are handcuffed.");
        return 1;
    }

    new targetid = INVALID_PLAYER_ID;
    if (!Internal_ParseSingleInt(params, targetid) || targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /search [player id]");
        return 1;
    }
    if (targetid == playerid)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: You cannot search yourself.");
        return 1;
    }
    if (Utils_GetDistanceBetweenPlayers(playerid, targetid) > RP_INTERACT_DISTANCE)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: The player is too far from you (maximum 3.0 m).");
        return 1;
    }

    new bool:isTargetRestrained = Survival_IsCuffed(targetid) || (GetPlayerSpecialAction(targetid) == SPECIAL_ACTION_HANDSUP);
    if (!isTargetRestrained)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Search]: For a full search (/search), the target must be handcuffed (/cuff) or with their hands up!");
        return 1;
    }

    // Роль №3 (Ночная Бабочка): прячет наличные в Слое 2 от криминального грабежа без полицейского жетона
    new targetRole = Character_GetRoleId(targetid);
    new actorRole = Character_GetRoleId(playerid);
    new bool:includeLayer2 = true;
    if (Roles_HasPerk(targetRole, PERK_DOUBLE_LAYER2) && !Roles_HasPerk(actorRole, PERK_COP_SENSE))
    {
        includeLayer2 = false;
        SendClientMessage(playerid, COLOR_WARNING, "[Search]: The character skillfully hid the secret pocket (Layer 2) from unprofessional search.");
    }

    new actorName[MAX_PLAYER_NAME + 8];
    new targetName[MAX_PLAYER_NAME + 8];
    Internal_GetRoleplayName(playerid, actorName, sizeof(actorName));
    Internal_GetRoleplayName(targetid, targetName, sizeof(targetName));

    new rpMsg[160];
    format(rpMsg, sizeof(rpMsg), "* %s conducts a thorough search of all %s's pockets and belongings.", actorName, targetName);
    Commands_SendProximityMessage(playerid, RP_RADIUS_ACTION, COLOR_RP_ME, rpMsg);

    Dialogs_OpenSearchTarget(playerid, targetid, includeLayer2, true);
    return 1;
}

/*
 * /pickpocket [id] — скрытная карманная кража из Слоя 1 с учетом навыка SKILL_PICKPOCKETING
 * и перка PERK_SILENT_PICKPOCKET (Роль №22: Уличный Карманник).
 */
CMD:pickpocket(playerid, params[])
{
    if (!Character_IsLoaded(playerid)) return 1;
    if (Survival_IsCuffed(playerid))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: Your hands are handcuffed.");
        return 1;
    }

    new targetid = INVALID_PLAYER_ID;
    if (!Internal_ParseSingleInt(params, targetid) || targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /pickpocket [player id]");
        return 1;
    }
    if (targetid == playerid)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: You can't rob yourself.");
        return 1;
    }
    if (Utils_GetDistanceBetweenPlayers(playerid, targetid) > 2.2)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Pickpocket]: Get close to the victim (no further than 2.2 m).");
        return 1;
    }

    new roleId = Character_GetRoleId(playerid);
    if (Roles_IsValidId(roleId) && gRoleConfigs[roleId - 1][E_ROLE_ZERO_CRIMINAL_SKILLS])
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Role]: Your starting role rules prohibit pickpocketing.");
        return 1;
    }

    new nowTs = gettime();
    if (nowTs - sLastPickpocketTime[playerid] < PICKPOCKET_COOLDOWN_SEC)
    {
        new waitSec = PICKPOCKET_COOLDOWN_SEC - (nowTs - sLastPickpocketTime[playerid]);
        new cdMsg[128];
        format(cdMsg, sizeof(cdMsg), "[Pickpocket]: You recently attempted theft. Wait another %d seconds.", waitSec);
        SendClientMessage(playerid, COLOR_WARNING, cdMsg);
        return 1;
    }
    sLastPickpocketTime[playerid] = nowTs;

    new targetLayer1 = Character_GetLayer1Slot(targetid);
    new actorLayer1 = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(targetLayer1) || !Storage_IsValidSlot(actorLayer1))
    {
        return 1;
    }

    // Ищем пачку наличных или небольшой предмет (до 1500 г) в Слое 1 жертвы
    new stealItemSlot = INVALID_ITEM_SLOT;
    new iter = Storage_GetFirstItemSlot(targetLayer1);
    while (iter != INVALID_ITEM_SLOT)
    {
        new defId = Storage_GetItemDefId(iter);
        if (defId == ITEM_ID_CASH_BUNDLE || Item_GetBaseWeight(defId) <= 1500)
        {
            stealItemSlot = iter;
            if (defId == ITEM_ID_CASH_BUNDLE)
            {
                break;
            }
        }
        iter = Storage_GetNextItemSlot(iter);
    }

    if (stealItemSlot == INVALID_ITEM_SLOT)
    {
        SendClientMessage(playerid, COLOR_GRAY, "[Pickpocket]: There are no small valuables or cash in this victim's outer pockets (Layer 1).");
        return 1;
    }

    new skillVal = Skills_Get(playerid, SKILL_PICKPOCKETING);
    new bool:hasPerk = Roles_HasPerk(roleId, PERK_SILENT_PICKPOCKET);
    new successChance = 30 + (skillVal / 20) + (hasPerk ? 30 : 0);
    if (successChance > 90) successChance = 90;

    new roll = random(100);
    if (roll < successChance)
    {
        new defId = Storage_GetItemDefId(stealItemSlot);
        new availAmt = Storage_GetItemAmount(stealItemSlot);
        new stealAmt = 1;
        if (defId == ITEM_ID_CASH_BUNDLE)
        {
            stealAmt = (availAmt > 250) ? (50 + random(200)) : availAmt;
        }

        new E_STORAGE_RESULT:res = Storage_TransferItem(playerid, targetLayer1, stealItemSlot, actorLayer1, stealAmt, Character_GetId(playerid));
        if (res == STORAGE_RES_OK)
        {
            Skills_Add(playerid, SKILL_PICKPOCKETING, 6);
            Survival_RecalculateEncumbrance(playerid);
            Survival_RecalculateEncumbrance(targetid);

            new itemName[ITEM_DISPLAY_NAME_LEN];
            Item_GetName(defId, itemName, sizeof(itemName));

            new msg[160];
            if (defId == ITEM_ID_CASH_BUNDLE)
            {
                format(msg, sizeof(msg), "[Pickpocket]: You quietly took $%d cash from the victim's outside pocket!", stealAmt);
            }
            else
            {
                format(msg, sizeof(msg), "[Pickpocket]: You quietly took \"%s\" (%d pcs.) from the victim's pocket!", itemName, stealAmt);
            }
            SendClientMessage(playerid, COLOR_SUCCESS, msg);

            new srcTag[32], dstTag[32];
            format(srcTag, sizeof(srcTag), "CHAR_L1:%d", Character_GetId(targetid));
            format(dstTag, sizeof(dstTag), "CHAR_L1:%d", Character_GetId(playerid));
            Audit_Log(
                Character_GetId(playerid),
                "PICKPOCKET_STEAL",
                srcTag,
                dstTag,
                defId,
                stealAmt,
                "Pickpocketing from Layer 1"
            );

            // Если нет перка уличного карманника, есть малый шанс, что жертва заметит пропажу позже
            if (!hasPerk && random(100) < 35)
            {
                SendClientMessage(targetid, COLOR_WARNING, "[Intuition]: It seemed to you that someone had just touched your pocket.");
            }
        }
        else
        {
            SendClientMessage(playerid, COLOR_ERROR, "[Pickpocket]: There is no free space in your hands to hide your stolen goods.");
        }
    }
    else
    {
        Skills_Add(playerid, SKILL_PICKPOCKETING, 2);
        new actorName[MAX_PLAYER_NAME + 8];
        new targetName[MAX_PLAYER_NAME + 8];
        Internal_GetRoleplayName(playerid, actorName, sizeof(actorName));
        Internal_GetRoleplayName(targetid, targetName, sizeof(targetName));

        new alertMsg[160];
        format(alertMsg, sizeof(alertMsg), "* %s noticed %s's hand in his pocket!", targetName, actorName);
        Commands_SendProximityMessage(playerid, RP_RADIUS_NORMAL, COLOR_WARNING, alertMsg);
        SendClientMessage(playerid, COLOR_ERROR, "[Pickpocket]: Bad luck! The victim felt your hand in his pocket.");
    }
    return 1;
}

// =============================================================================
//  6. ПЕРЕДАЧА ФИЗИЧЕСКИХ НАЛИЧНЫХ И ПРЕДМЕТОВ (/pay, /give)
// =============================================================================

static stock Internal_TransferHandCash(playerid, targetid, amount_usd)
{
    if (!Character_IsLoaded(playerid)) return 0;
    if (Survival_IsCuffed(playerid))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: Your hands are handcuffed.");
        return 1;
    }
    if (targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid) || targetid == playerid)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: Please enter a valid recipient near you.");
        return 1;
    }
    if (amount_usd <= 0 || amount_usd > 1000000)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: Transfer amount must be between $1 and $1,000,000.");
        return 1;
    }
    if (Utils_GetDistanceBetweenPlayers(playerid, targetid) > RP_INTERACT_DISTANCE)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Error]: The player is too far from you (maximum 3.0 m).");
        return 1;
    }

    new availCash = Character_GetPhysicalCashUsd(playerid);
    if (availCash < amount_usd)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Cash]: You don't have enough physical banknotes in your inventory!");
        return 1;
    }

    new targetLayer1 = Character_GetLayer1Slot(targetid);
    if (!Storage_IsValidSlot(targetLayer1))
    {
        return 1;
    }

    if (!Internal_RemovePhysicalCash(playerid, amount_usd))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Cash]: Error debiting a stack of banknotes from inventory.");
        return 1;
    }

    new E_STORAGE_RESULT:addRes = Storage_AddItem(
        targetLayer1,
        ITEM_ID_CASH_BUNDLE,
        amount_usd,
        0,
        100.0,
        amount_usd,
        0,
        "USD_CASH"
    );

    if (addRes != STORAGE_RES_OK)
    {
        // Возврат отправителю, если у получателя переполнен инвентарь
        Storage_AddItem(
            Character_GetLayer1Slot(playerid),
            ITEM_ID_CASH_BUNDLE,
            amount_usd,
            0,
            100.0,
            amount_usd,
            0,
            "USD_CASH"
        );
        SendClientMessage(playerid, COLOR_ERROR, "[Cash]: The recipient does not have space in their inventory (Layer 1) for a stack of banknotes.");
        return 1;
    }

    Survival_RecalculateEncumbrance(playerid);
    Survival_RecalculateEncumbrance(targetid);

    new moneyStr[32];
    Utils_FormatMoney(amount_usd, moneyStr, sizeof(moneyStr));

    new actorName[MAX_PLAYER_NAME + 8];
    new targetName[MAX_PLAYER_NAME + 8];
    Internal_GetRoleplayName(playerid, actorName, sizeof(actorName));
    Internal_GetRoleplayName(targetid, targetName, sizeof(targetName));

    new msg[160];
    format(msg, sizeof(msg), "[Cash]: You gave %s cash to player %s [%d].", moneyStr, targetName, targetid);
    SendClientMessage(playerid, COLOR_SUCCESS, msg);

    format(msg, sizeof(msg), "[Cash]: Player %s [%d] gave you %s cash.", actorName, playerid, moneyStr);
    SendClientMessage(targetid, COLOR_SUCCESS, msg);

    format(msg, sizeof(msg), "* %s took out a stack of banknotes and handed it to %s.", actorName, targetName);
    Commands_SendProximityMessage(playerid, RP_RADIUS_ACTION, COLOR_RP_ME, msg);

    new srcTag[32], dstTag[32];
    format(srcTag, sizeof(srcTag), "CHAR_CASH:%d", Character_GetId(playerid));
    format(dstTag, sizeof(dstTag), "CHAR_CASH:%d", Character_GetId(targetid));
    Audit_Log(
        Character_GetId(playerid),
        "CASH_TRANSFER",
        srcTag,
        dstTag,
        ITEM_ID_CASH_BUNDLE,
        amount_usd,
        "Transfer of physical cash from hand to hand"
    );
    return 1;
}

CMD:pay(playerid, params[])
{
    new targetid = INVALID_PLAYER_ID;
    new amount = 0;
    if (!Internal_ParseTwoInts(params, targetid, amount))
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /pay [player id] [cash amount USD]");
        return 1;
    }
    return Internal_TransferHandCash(playerid, targetid, amount);
}

CMD:give(playerid, params[])
{
    new targetid = INVALID_PLAYER_ID;
    new amount = 0;
    if (!Internal_ParseTwoInts(params, targetid, amount))
    {
        SendClientMessage(playerid, COLOR_INFO, "Usage: /give [player id] [USD amount] (to transfer items: /inv -> item -> \"Give to the person nearby\").");
        return 1;
    }
    return Internal_TransferHandCash(playerid, targetid, amount);
}

// =============================================================================
//  7. ПЕРЕХВАТ ОБЫЧНОГО ПРОСТРАНСТВЕННОГО RP-ЧАТА (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    printf("%s [UI/Commands] Registered role and inventory commands (/inv, /i, /me, /do, /try, /todo, /b, /s, /w, /frisk, /search, /pickpocket, /pay, /give).",
        SERVER_LOG_PREFIX);
    return 1;
}

hook OnPlayerText(playerid, text[])
{
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Chat]: You will be able to write in the role-playing chat after entering the game world.");
        return 0;
    }

    new rpName[MAX_PLAYER_NAME + 8];
    Internal_GetRoleplayName(playerid, rpName, sizeof(rpName));

    new chatLine[192];
    format(chatLine, sizeof(chatLine), "- %s [%d] says: %s", rpName, playerid, text);
    Commands_SendProximityMessage(playerid, RP_RADIUS_NORMAL, COLOR_RP_TALK, chatLine);
    SetPlayerChatBubble(playerid, text, COLOR_RP_TALK, RP_RADIUS_NORMAL, 5500);
    return 0;
}

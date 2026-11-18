/*
 * =============================================================================
 *  SAN ANDREAS RP — Модуль аккаунтов, аутентификации bcrypt и сессий безопасности
 *  Файл:      gamemodes/modules/entities/mod_account.pwn
 *  Пункт:     ROADMAP [3.1] — Модуль аккаунтов и безопасности (entities/mod_account.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_account_included
    #endinput
#endif
#define _mod_account_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ, ИДЕНТИФИКАТОРЫ ДИАЛОГОВ И ПАРАМЕТРЫ БЕЗОПАСНОСТИ
// =============================================================================

#define ACCOUNT_PASSWORD_MIN_LEN                (6)
#define ACCOUNT_PASSWORD_MAX_LEN                (32)
#define ACCOUNT_EMAIL_MAX_LEN                   (128)
#define ACCOUNT_BAN_REASON_MAX_LEN              (128)
#define ACCOUNT_IP_MAX_LEN                      (46)
#define ACCOUNT_HWID_MAX_LEN                    (65)
#define ACCOUNT_MAX_LOGIN_ATTEMPTS              (3)

#define DIALOG_ACC_BAN_NOTICE                   (1000)
#define DIALOG_ACC_NONRP_NICK                   (1001)
#define DIALOG_ACC_REGISTER_PASSWORD            (1002)
#define DIALOG_ACC_REGISTER_EMAIL               (1003)
#define DIALOG_ACC_LOGIN_PASSWORD               (1004)

#define MAX_RAM_CACHED_ACCOUNTS                 (128)

// Событие успешной авторизации или завершения регистрации аккаунта
forward OnAccountAuthenticated(playerid, bool:isNewRegistration);

// Событие повторного отображения активного шага создания персонажа после входа в режим наблюдения
forward OnLobbyReshowCharacterWizard(playerid);

// =============================================================================
//  2. СТРУКТУРЫ ДАННЫХ И ИНКАПСУЛИРОВАННОЕ СОСТОЯНИЕ СЕССИЙ (static stock)
// =============================================================================

enum E_ACCOUNT_STATE
{
    ACC_STATE_NONE = 0,
    ACC_STATE_CHECKING_DB,
    ACC_STATE_AWAITING_REGISTER,
    ACC_STATE_AWAITING_EMAIL,
    ACC_STATE_HASHING_PASSWORD,
    ACC_STATE_AWAITING_LOGIN,
    ACC_STATE_VERIFYING_PASSWORD,
    ACC_STATE_AUTHENTICATED,
    ACC_STATE_KICK_PENDING
};

enum E_PLAYER_ACCOUNT
{
    E_ACCOUNT_STATE:E_ACC_STATE,
    E_ACC_DB_ID,
    E_ACC_SESSION_DB_ID,
    E_ACC_BOUND_CHAR_DB_ID,
    E_ACC_USERNAME[MAX_PLAYER_NAME + 1],
    E_ACC_PASSWORD_HASH[BCRYPT_HASH_LENGTH],
    E_ACC_TEMP_PASSWORD[ACCOUNT_PASSWORD_MAX_LEN + 1],
    E_ACC_EMAIL[ACCOUNT_EMAIL_MAX_LEN],
    E_ACC_ADMIN_LEVEL,
    bool:E_ACC_IS_BANNED,
    E_ACC_BAN_REASON[ACCOUNT_BAN_REASON_MAX_LEN],
    E_ACC_BAN_EXPIRES_AT,
    E_ACC_IP[ACCOUNT_IP_MAX_LEN],
    E_ACC_HWID[ACCOUNT_HWID_MAX_LEN],
    E_ACC_LOGIN_ATTEMPTS,
    E_ACC_CONNECTED_UNIX
};

enum E_RAM_ACCOUNT_CACHE
{
    bool:E_RAM_ACC_USED,
    E_RAM_ACC_DB_ID,
    E_RAM_ACC_USERNAME[MAX_PLAYER_NAME + 1],
    E_RAM_ACC_PASSWORD_HASH[BCRYPT_HASH_LENGTH],
    E_RAM_ACC_EMAIL[ACCOUNT_EMAIL_MAX_LEN],
    E_RAM_ACC_ADMIN_LEVEL
};

static stock sPlayerAccounts[MAX_PLAYERS][E_PLAYER_ACCOUNT];
static stock sRamAccountCache[MAX_RAM_CACHED_ACCOUNTS][E_RAM_ACCOUNT_CACHE];
static stock sSyntheticAccountIdSeq = 0;
static stock sSyntheticSessionIdSeq = 0;
static stock sAccountSqlBuffer[1024];

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ И ДИАЛОГИ (static stock)
// =============================================================================

static stock Internal_ResetAccountSlot(playerid)
{
    sPlayerAccounts[playerid][E_ACC_STATE] = ACC_STATE_NONE;
    sPlayerAccounts[playerid][E_ACC_DB_ID] = 0;
    sPlayerAccounts[playerid][E_ACC_SESSION_DB_ID] = 0;
    sPlayerAccounts[playerid][E_ACC_BOUND_CHAR_DB_ID] = 0;
    sPlayerAccounts[playerid][E_ACC_USERNAME][0] = EOS;
    sPlayerAccounts[playerid][E_ACC_PASSWORD_HASH][0] = EOS;
    sPlayerAccounts[playerid][E_ACC_TEMP_PASSWORD][0] = EOS;
    sPlayerAccounts[playerid][E_ACC_EMAIL][0] = EOS;
    sPlayerAccounts[playerid][E_ACC_ADMIN_LEVEL] = 0;
    sPlayerAccounts[playerid][E_ACC_IS_BANNED] = false;
    sPlayerAccounts[playerid][E_ACC_BAN_REASON][0] = EOS;
    sPlayerAccounts[playerid][E_ACC_BAN_EXPIRES_AT] = 0;
    sPlayerAccounts[playerid][E_ACC_IP][0] = EOS;
    sPlayerAccounts[playerid][E_ACC_HWID][0] = EOS;
    sPlayerAccounts[playerid][E_ACC_LOGIN_ATTEMPTS] = 0;
    sPlayerAccounts[playerid][E_ACC_CONNECTED_UNIX] = 0;
}

static stock bool:Internal_ValidateRpNickFormat(const nickname[])
{
    new const len = strlen(nickname);
    if (len < 5 || len > 24)
    {
        return false;
    }

    new Regex:rpRegex = Regex_New("^[A-Z][a-z]{1,11}_[A-Z][a-z]{1,11}$");
    if (rpRegex != Regex:0)
    {
        new const bool:matched = (Regex_Check(nickname, rpRegex) == 1);
        Regex_Delete(rpRegex);
        return matched;
    }

    // Резервная посимвольная проверка при недоступности дескриптора Regex
    new underscorePos = -1;
    for (new i = 0; i < len; i++)
    {
        new const ch = nickname[i];
        if (ch == '_')
        {
            if (underscorePos != -1 || i < 2 || i >= (len - 2))
            {
                return false;
            }
            underscorePos = i;
        }
        else if (i == 0 || i == (underscorePos + 1))
        {
            if (ch < 'A' || ch > 'Z')
            {
                return false;
            }
        }
        else
        {
            if (ch < 'a' || ch > 'z')
            {
                return false;
            }
        }
    }
    return (underscorePos != -1);
}

static stock bool:Internal_ValidateEmailFormat(const email[])
{
    new const len = strlen(email);
    if (len < 5 || len >= ACCOUNT_EMAIL_MAX_LEN)
    {
        return false;
    }

    new atPos = -1;
    new dotPos = -1;
    for (new i = 0; i < len; i++)
    {
        new const ch = email[i];
        if (ch <= ' ' || ch == '\'' || ch == '"' || ch == ';' || ch == '\\')
        {
            return false;
        }
        if (ch == '@')
        {
            if (atPos != -1 || i == 0)
            {
                return false;
            }
            atPos = i;
        }
        else if (ch == '.' && atPos != -1 && i > (atPos + 1))
        {
            dotPos = i;
        }
    }
    return (atPos > 0 && dotPos > (atPos + 1) && dotPos < (len - 1));
}

timer Account_DelayedKickTimer[450](playerid, expectedToken)
{
    if (!Config_ValidatePlayerToken(playerid, expectedToken))
    {
        return;
    }
    Kick(playerid);
}

static stock Internal_KickWithReasonDialog(playerid, dialogId, const title[], const body[])
{
    sPlayerAccounts[playerid][E_ACC_STATE] = ACC_STATE_KICK_PENDING;
    ShowPlayerDialog(playerid, dialogId, DIALOG_STYLE_MSGBOX, title, body, "Close", "");
    defer Account_DelayedKickTimer(playerid, Config_GetPlayerSessionToken(playerid));
}

static stock Internal_ShowRegisterPasswordDialog(playerid, const errorNotice[] = "")
{
    sPlayerAccounts[playerid][E_ACC_STATE] = ACC_STATE_AWAITING_REGISTER;

    new body[640];
    if (errorNotice[0] != EOS)
    {
        format(body, sizeof(body),
            "{FFFFFF}Welcome to the State of San Andreas, {FFC800}%s{FFFFFF}!\n\nThis character name is available for registration.\nThe project is built on a fair market economy, realistic item weight, and complete freedom of action.\n\n{FF4444}Error: %s{FFFFFF}\n\nCreate a strong password to protect your account (%d to %d characters):",
            sPlayerAccounts[playerid][E_ACC_USERNAME],
            errorNotice,
            ACCOUNT_PASSWORD_MIN_LEN,
            ACCOUNT_PASSWORD_MAX_LEN);
    }
    else
    {
        format(body, sizeof(body),
            "{FFFFFF}Welcome to the State of San Andreas, {FFC800}%s{FFFFFF}!\n\nThis character name is available for registration.\nThe project is built on a fair market economy, realistic item weight, and complete freedom of action.\n\nCreate a strong password to protect your account (%d to %d characters):",
            sPlayerAccounts[playerid][E_ACC_USERNAME],
            ACCOUNT_PASSWORD_MIN_LEN,
            ACCOUNT_PASSWORD_MAX_LEN);
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_ACC_REGISTER_PASSWORD,
        DIALOG_STYLE_PASSWORD,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Account Registration (Step 1/2)",
        body,
        "Register",
        "Cancel");
}

static stock Internal_ShowRegisterEmailDialog(playerid, const errorNotice[] = "")
{
    sPlayerAccounts[playerid][E_ACC_STATE] = ACC_STATE_AWAITING_EMAIL;

    new body[576];
    if (errorNotice[0] != EOS)
    {
        format(body, sizeof(body),
            "{FFFFFF}Enter an email address to recover access to your account {FFC800}%s{FFFFFF}.\nIf you do not want to link an email right now, click \"Skip\".\n\n{FF4444}Error: %s{FFFFFF}\n\nEnter a valid email address (for example: player@example.com):",
            sPlayerAccounts[playerid][E_ACC_USERNAME],
            errorNotice);
    }
    else
    {
        format(body, sizeof(body),
            "{FFFFFF}Enter an email address to recover access to your account {FFC800}%s{FFFFFF}.\nIf you do not want to link an email right now, click \"Skip\".\n\nEnter a valid email address (for example: player@example.com):",
            sPlayerAccounts[playerid][E_ACC_USERNAME]);
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_ACC_REGISTER_EMAIL,
        DIALOG_STYLE_INPUT,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Email Linking (Step 2/2)",
        body,
        "Next",
        "Skip");
}

static stock Internal_ShowLoginPasswordDialog(playerid, const errorNotice[] = "")
{
    sPlayerAccounts[playerid][E_ACC_STATE] = ACC_STATE_AWAITING_LOGIN;

    new body[640];
    new const remainingAttempts = ACCOUNT_MAX_LOGIN_ATTEMPTS - sPlayerAccounts[playerid][E_ACC_LOGIN_ATTEMPTS];

    if (errorNotice[0] != EOS)
    {
        format(body, sizeof(body),
            "{FFFFFF}Welcome back to the State of San Andreas, {FFC800}%s{FFFFFF}!\nYour account is registered in the state database.\n\n{FF4444}%s (attempts left: %d of %d){FFFFFF}\n\nEnter your account password to log in:",
            sPlayerAccounts[playerid][E_ACC_USERNAME],
            errorNotice,
            remainingAttempts,
            ACCOUNT_MAX_LOGIN_ATTEMPTS);
    }
    else
    {
        format(body, sizeof(body),
            "{FFFFFF}Welcome back to the State of San Andreas, {FFC800}%s{FFFFFF}!\nYour account is registered in the state database.\n\n{88CCFF}Login attempts available: %d of %d{FFFFFF}\n\nEnter your account password to log in:",
            sPlayerAccounts[playerid][E_ACC_USERNAME],
            remainingAttempts,
            ACCOUNT_MAX_LOGIN_ATTEMPTS);
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_ACC_LOGIN_PASSWORD,
        DIALOG_STYLE_PASSWORD,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Account Login",
        body,
        "Login",
        "Cancel");
}

static stock Internal_FindRamAccountSlot(const username[])
{
    if (username[0] == EOS)
    {
        return -1;
    }

    for (new i = 0; i < MAX_RAM_CACHED_ACCOUNTS; i++)
    {
        if (sRamAccountCache[i][E_RAM_ACC_USED] &&
            strcmp(sRamAccountCache[i][E_RAM_ACC_USERNAME], username, true) == 0)
        {
            return i;
        }
    }
    return -1;
}

static stock Internal_SaveRamAccountCache(playerid)
{
    new slot = Internal_FindRamAccountSlot(sPlayerAccounts[playerid][E_ACC_USERNAME]);
    if (slot == -1)
    {
        for (new i = 0; i < MAX_RAM_CACHED_ACCOUNTS; i++)
        {
            if (!sRamAccountCache[i][E_RAM_ACC_USED])
            {
                slot = i;
                break;
            }
        }
    }
    if (slot == -1)
    {
        slot = 0;
    }

    sRamAccountCache[slot][E_RAM_ACC_USED] = true;
    sRamAccountCache[slot][E_RAM_ACC_DB_ID] = sPlayerAccounts[playerid][E_ACC_DB_ID];
    format(sRamAccountCache[slot][E_RAM_ACC_USERNAME], MAX_PLAYER_NAME + 1, "%s", sPlayerAccounts[playerid][E_ACC_USERNAME]);
    format(sRamAccountCache[slot][E_RAM_ACC_PASSWORD_HASH], BCRYPT_HASH_LENGTH, "%s", sPlayerAccounts[playerid][E_ACC_PASSWORD_HASH]);
    format(sRamAccountCache[slot][E_RAM_ACC_EMAIL], ACCOUNT_EMAIL_MAX_LEN, "%s", sPlayerAccounts[playerid][E_ACC_EMAIL]);
    sRamAccountCache[slot][E_RAM_ACC_ADMIN_LEVEL] = sPlayerAccounts[playerid][E_ACC_ADMIN_LEVEL];
}

static stock Internal_ReshowActiveAuthOrWizardDialog(playerid)
{
    switch (sPlayerAccounts[playerid][E_ACC_STATE])
    {
        case ACC_STATE_AWAITING_REGISTER:
        {
            Internal_ShowRegisterPasswordDialog(playerid);
        }
        case ACC_STATE_AWAITING_EMAIL:
        {
            Internal_ShowRegisterEmailDialog(playerid);
        }
        case ACC_STATE_AWAITING_LOGIN:
        {
            Internal_ShowLoginPasswordDialog(playerid);
        }
        case ACC_STATE_AUTHENTICATED:
        {
            if (sPlayerAccounts[playerid][E_ACC_BOUND_CHAR_DB_ID] <= 0)
            {
                CallLocalFunction("OnLobbyReshowCharacterWizard", "d", playerid);
            }
        }
        default:
        {
        }
    }
}

timer Account_SyncLobbyCameraAndDialog[150](playerid, expectedToken)
{
    if (!Config_ValidatePlayerToken(playerid, expectedToken))
    {
        return;
    }

    if (sPlayerAccounts[playerid][E_ACC_STATE] == ACC_STATE_KICK_PENDING)
    {
        return;
    }

    // Если персонаж уже создан/загружен и привязан к сессии — камера передается игроку
    if (sPlayerAccounts[playerid][E_ACC_STATE] == ACC_STATE_AUTHENTICATED &&
        sPlayerAccounts[playerid][E_ACC_BOUND_CHAR_DB_ID] > 0)
    {
        return;
    }

    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    InterpolateCameraPos(playerid, 1480.0, -1790.0, 58.0, 1480.0, -1715.0, 42.0, 25000, CAMERA_MOVE);
    InterpolateCameraLookAt(playerid, 1480.0, -1768.0, 18.0, 1480.0, -1660.0, 16.0, 25000, CAMERA_MOVE);

    Internal_ReshowActiveAuthOrWizardDialog(playerid);
}

static stock Internal_StartSessionRecord(playerid, bool:isNewRegistration)
{
    sPlayerAccounts[playerid][E_ACC_STATE] = ACC_STATE_AUTHENTICATED;
    sPlayerAccounts[playerid][E_ACC_TEMP_PASSWORD][0] = EOS;

    new const accountDbId = sPlayerAccounts[playerid][E_ACC_DB_ID];

    if (DB_IsConnected() && accountDbId > 0)
    {
        mysql_format(gMySQL, sAccountSqlBuffer, sizeof(sAccountSqlBuffer),
            "UPDATE `accounts` SET `last_ip` = '%e', `last_hwid` = '%e', `last_login_at` = NOW() WHERE `id` = %d;",
            sPlayerAccounts[playerid][E_ACC_IP],
            sPlayerAccounts[playerid][E_ACC_HWID],
            accountDbId);
        mysql_tquery(gMySQL, sAccountSqlBuffer);

        mysql_format(gMySQL, sAccountSqlBuffer, sizeof(sAccountSqlBuffer),
            "INSERT INTO `account_sessions` (`account_id`, `ip_address`, `hwid_hash`) VALUES (%d, '%e', '%e');",
            accountDbId,
            sPlayerAccounts[playerid][E_ACC_IP],
            sPlayerAccounts[playerid][E_ACC_HWID]);
        mysql_tquery(gMySQL, sAccountSqlBuffer, "OnAccountSessionCreatedInDb", "dd",
            playerid, Config_GetPlayerSessionToken(playerid));
    }
    else
    {
        sPlayerAccounts[playerid][E_ACC_SESSION_DB_ID] = ++sSyntheticSessionIdSeq;
    }

    new details[160];
    format(details, sizeof(details), "%s of account %s (ID: %d, IP: %s)",
        isNewRegistration ? ("Registration") : ("Login"),
        sPlayerAccounts[playerid][E_ACC_USERNAME],
        accountDbId,
        sPlayerAccounts[playerid][E_ACC_IP]);

    Audit_Log(
        0,
        isNewRegistration ? ("ACCOUNT_REGISTER") : ("ACCOUNT_LOGIN"),
        sPlayerAccounts[playerid][E_ACC_USERNAME],
        sPlayerAccounts[playerid][E_ACC_IP],
        0,
        1,
        details);

    CallLocalFunction("OnAccountAuthenticated", "dd", playerid, isNewRegistration ? 1 : 0);
}

static stock Internal_BeginPasswordHashing(playerid)
{
    sPlayerAccounts[playerid][E_ACC_STATE] = ACC_STATE_HASHING_PASSWORD;
    bcrypt_hash(
        playerid,
        "OnAccountPasswordHashed",
        sPlayerAccounts[playerid][E_ACC_TEMP_PASSWORD],
        BCRYPT_WORK_FACTOR,
        "d",
        Config_GetPlayerSessionToken(playerid));
}

// =============================================================================
//  4. АСИНХРОННЫЕ КОЛБЕКИ MYSQL И BCRYPT (forward / public)
// =============================================================================

forward OnAccountLookupCompleted(playerid, sessionToken);
public OnAccountLookupCompleted(playerid, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 1;
    }

    new rows = 0;
    cache_get_row_count(rows);

    if (rows <= 0)
    {
        Internal_ShowRegisterPasswordDialog(playerid);
        return 1;
    }

    new accId = 0;
    new adminLevel = 0;
    new isBannedInt = 0;
    new banExpiresUnix = 0;

    cache_get_value_name_int(0, "id", accId);
    cache_get_value_name(0, "password_hash", sPlayerAccounts[playerid][E_ACC_PASSWORD_HASH], BCRYPT_HASH_LENGTH);
    cache_get_value_name(0, "email", sPlayerAccounts[playerid][E_ACC_EMAIL], ACCOUNT_EMAIL_MAX_LEN);
    cache_get_value_name_int(0, "admin_level", adminLevel);
    cache_get_value_name_int(0, "is_banned", isBannedInt);
    cache_get_value_name(0, "ban_reason", sPlayerAccounts[playerid][E_ACC_BAN_REASON], ACCOUNT_BAN_REASON_MAX_LEN);
    cache_get_value_name_int(0, "ban_expires_unix", banExpiresUnix);

    sPlayerAccounts[playerid][E_ACC_DB_ID] = accId;
    sPlayerAccounts[playerid][E_ACC_ADMIN_LEVEL] = adminLevel;
    sPlayerAccounts[playerid][E_ACC_IS_BANNED] = (isBannedInt != 0);
    sPlayerAccounts[playerid][E_ACC_BAN_EXPIRES_AT] = banExpiresUnix;

    new const nowUnix = gettime();
    if (sPlayerAccounts[playerid][E_ACC_IS_BANNED])
    {
        if (banExpiresUnix > 0 && banExpiresUnix <= nowUnix)
        {
            // Автоматическое снятие истекшей временной блокировки
            sPlayerAccounts[playerid][E_ACC_IS_BANNED] = false;
            if (DB_IsConnected() && accId > 0)
            {
                mysql_format(gMySQL, sAccountSqlBuffer, sizeof(sAccountSqlBuffer),
                    "UPDATE `accounts` SET `is_banned` = 0, `ban_reason` = NULL, `ban_expires_at` = NULL WHERE `id` = %d;",
                    accId);
                mysql_tquery(gMySQL, sAccountSqlBuffer);
            }
        }
        else
        {
            new banMsg[512];
            new banReasonText[ACCOUNT_BAN_REASON_MAX_LEN];
            if (sPlayerAccounts[playerid][E_ACC_BAN_REASON][0] != EOS)
            {
                format(banReasonText, sizeof(banReasonText), "%s", sPlayerAccounts[playerid][E_ACC_BAN_REASON]);
            }
            else
            {
                format(banReasonText, sizeof(banReasonText), "Violation of server rules");
            }

            if (banExpiresUnix > nowUnix)
            {
                new const hoursLeft = ((banExpiresUnix - nowUnix) / 3600) + 1;
                format(banMsg, sizeof(banMsg),
                    "{FF4444}Access to the server is temporarily restricted!{FFFFFF}\n\nAccount: {FFC800}%s{FFFFFF}\nBan reason: {FFAA00}%s{FFFFFF}\nTime remaining: {88CCFF}~%d h.{FFFFFF}\nYour IP address: {AFAFAF}%s{FFFFFF}",
                    sPlayerAccounts[playerid][E_ACC_USERNAME],
                    banReasonText,
                    hoursLeft,
                    sPlayerAccounts[playerid][E_ACC_IP]);
            }
            else
            {
                format(banMsg, sizeof(banMsg),
                    "{FF4444}Your account or hardware has been permanently blocked!{FFFFFF}\n\nAccount: {FFC800}%s{FFFFFF}\nBan reason: {FFAA00}%s{FFFFFF}\nYour IP address: {AFAFAF}%s{FFFFFF}",
                    sPlayerAccounts[playerid][E_ACC_USERNAME],
                    banReasonText,
                    sPlayerAccounts[playerid][E_ACC_IP]);
            }

            Internal_KickWithReasonDialog(
                playerid,
                DIALOG_ACC_BAN_NOTICE,
                "{FF4444}SAN ANDREAS RP {FFFFFF}| Access Blocked",
                banMsg);
            return 1;
        }
    }

    // Если запрос вернул чужую запись по совпадению заблокированного IP/HWID, но сам ник еще не создан:
    new loadedUsername[MAX_PLAYER_NAME + 1];
    cache_get_value_name(0, "username", loadedUsername, sizeof(loadedUsername));
    if (strcmp(loadedUsername, sPlayerAccounts[playerid][E_ACC_USERNAME], true) != 0)
    {
        sPlayerAccounts[playerid][E_ACC_DB_ID] = 0;
        sPlayerAccounts[playerid][E_ACC_PASSWORD_HASH][0] = EOS;
        Internal_ShowRegisterPasswordDialog(playerid);
        return 1;
    }

    Internal_ShowLoginPasswordDialog(playerid);
    return 1;
}

forward OnAccountPasswordHashed(playerid, sessionToken);
public OnAccountPasswordHashed(playerid, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 1;
    }

    bcrypt_get_hash(sPlayerAccounts[playerid][E_ACC_PASSWORD_HASH], BCRYPT_HASH_LENGTH);
    sPlayerAccounts[playerid][E_ACC_TEMP_PASSWORD][0] = EOS;

    if (strlen(sPlayerAccounts[playerid][E_ACC_PASSWORD_HASH]) < 55)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "A system error occurred while hashing your password. Please try again.");
        Internal_ShowRegisterPasswordDialog(playerid, "bcrypt hash generation error.");
        return 1;
    }

    if (DB_IsConnected())
    {
        if (sPlayerAccounts[playerid][E_ACC_EMAIL][0] != EOS)
        {
            mysql_format(gMySQL, sAccountSqlBuffer, sizeof(sAccountSqlBuffer),
                "INSERT INTO `accounts` (`username`, `password_hash`, `email`, `reg_ip`, `last_ip`, `last_hwid`) VALUES ('%e', '%e', '%e', '%e', '%e', '%e');",
                sPlayerAccounts[playerid][E_ACC_USERNAME],
                sPlayerAccounts[playerid][E_ACC_PASSWORD_HASH],
                sPlayerAccounts[playerid][E_ACC_EMAIL],
                sPlayerAccounts[playerid][E_ACC_IP],
                sPlayerAccounts[playerid][E_ACC_IP],
                sPlayerAccounts[playerid][E_ACC_HWID]);
        }
        else
        {
            mysql_format(gMySQL, sAccountSqlBuffer, sizeof(sAccountSqlBuffer),
                "INSERT INTO `accounts` (`username`, `password_hash`, `email`, `reg_ip`, `last_ip`, `last_hwid`) VALUES ('%e', '%e', NULL, '%e', '%e', '%e');",
                sPlayerAccounts[playerid][E_ACC_USERNAME],
                sPlayerAccounts[playerid][E_ACC_PASSWORD_HASH],
                sPlayerAccounts[playerid][E_ACC_IP],
                sPlayerAccounts[playerid][E_ACC_IP],
                sPlayerAccounts[playerid][E_ACC_HWID]);
        }

        mysql_tquery(gMySQL, sAccountSqlBuffer, "OnAccountRegisteredInDb", "dd",
            playerid, sessionToken);
    }
    else
    {
        sPlayerAccounts[playerid][E_ACC_DB_ID] = ++sSyntheticAccountIdSeq;
        Internal_SaveRamAccountCache(playerid);
        SendClientMessage(playerid, COLOR_UI_SUCCESS,
            "Your account has been registered successfully! Moving on to character creation...");
        Internal_StartSessionRecord(playerid, true);
    }
    return 1;
}

forward OnAccountRegisteredInDb(playerid, sessionToken);
public OnAccountRegisteredInDb(playerid, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 1;
    }

    new const insertedId = cache_insert_id();
    sPlayerAccounts[playerid][E_ACC_DB_ID] = (insertedId > 0) ? insertedId : (++sSyntheticAccountIdSeq);
    Internal_SaveRamAccountCache(playerid);

    SendClientMessage(playerid, COLOR_UI_SUCCESS,
        "Your account has been successfully registered in the state database! Moving on to character creation...");
    Internal_StartSessionRecord(playerid, true);
    return 1;
}

forward OnAccountPasswordVerified(playerid, bool:success, sessionToken);
public OnAccountPasswordVerified(playerid, bool:success, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 1;
    }

    if (!success)
    {
        sPlayerAccounts[playerid][E_ACC_LOGIN_ATTEMPTS]++;
        if (sPlayerAccounts[playerid][E_ACC_LOGIN_ATTEMPTS] >= ACCOUNT_MAX_LOGIN_ATTEMPTS)
        {
            new kickBody[384];
            format(kickBody, sizeof(kickBody),
                "{FF4444}The limit of incorrect password attempts has been exceeded (%d of %d).{FFFFFF}\n\nThe connection to the server has been closed to protect account {FFC800}%s{FFFFFF}.\nThe unauthorized login attempt has been recorded in the security log.",
                sPlayerAccounts[playerid][E_ACC_LOGIN_ATTEMPTS],
                ACCOUNT_MAX_LOGIN_ATTEMPTS,
                sPlayerAccounts[playerid][E_ACC_USERNAME]);

            Audit_Log(
                0,
                "LOGIN_BRUTEFORCE_KICK",
                sPlayerAccounts[playerid][E_ACC_USERNAME],
                sPlayerAccounts[playerid][E_ACC_IP],
                0,
                sPlayerAccounts[playerid][E_ACC_LOGIN_ATTEMPTS],
                "Disconnected after 3 failed password attempts in a row");

            Internal_KickWithReasonDialog(
                playerid,
                DIALOG_ACC_BAN_NOTICE,
                "{FF4444}SAN ANDREAS RP {FFFFFF}| Account Protection",
                kickBody);
            return 1;
        }

        Internal_ShowLoginPasswordDialog(playerid, "Incorrect password!");
        return 1;
    }

    SendClientMessage(playerid, COLOR_UI_SUCCESS,
        "Login successful! Loading your character data...");
    Internal_StartSessionRecord(playerid, false);
    return 1;
}

forward OnAccountSessionCreatedInDb(playerid, sessionToken);
public OnAccountSessionCreatedInDb(playerid, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 1;
    }

    new const sessionDbId = cache_insert_id();
    if (sessionDbId > 0)
    {
        sPlayerAccounts[playerid][E_ACC_SESSION_DB_ID] = sessionDbId;
        if (sPlayerAccounts[playerid][E_ACC_BOUND_CHAR_DB_ID] > 0 && DB_IsConnected())
        {
            mysql_format(gMySQL, sAccountSqlBuffer, sizeof(sAccountSqlBuffer),
                "UPDATE `account_sessions` SET `char_id` = %d WHERE `id` = %d;",
                sPlayerAccounts[playerid][E_ACC_BOUND_CHAR_DB_ID],
                sessionDbId);
            mysql_tquery(gMySQL, sAccountSqlBuffer);
        }
    }
    return 1;
}

// =============================================================================
//  5. ПУБЛИЧНЫЙ API МОДУЛЯ АККАУНТОВ (Account_*)
// =============================================================================

stock bool:Account_IsLogged(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return false;
    }
    return (sPlayerAccounts[playerid][E_ACC_STATE] == ACC_STATE_AUTHENTICATED);
}

stock Account_GetId(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    return sPlayerAccounts[playerid][E_ACC_DB_ID];
}

stock Account_GetSessionDbId(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    return sPlayerAccounts[playerid][E_ACC_SESSION_DB_ID];
}

stock Account_GetAdminLevel(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    return sPlayerAccounts[playerid][E_ACC_ADMIN_LEVEL];
}

stock Account_SetAdminLevel(playerid, admin_level)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    if (admin_level < 0)
    {
        admin_level = 0;
    }
    sPlayerAccounts[playerid][E_ACC_ADMIN_LEVEL] = admin_level;

    if (DB_IsConnected() && sPlayerAccounts[playerid][E_ACC_DB_ID] > 0)
    {
        mysql_format(gMySQL, sAccountSqlBuffer, sizeof(sAccountSqlBuffer),
            "UPDATE `accounts` SET `admin_level` = %d WHERE `id` = %d;",
            admin_level,
            sPlayerAccounts[playerid][E_ACC_DB_ID]);
        mysql_tquery(gMySQL, sAccountSqlBuffer);
    }
    return 1;
}

stock Account_BindSessionCharId(playerid, char_db_id)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || char_db_id <= 0)
    {
        return 0;
    }

    sPlayerAccounts[playerid][E_ACC_BOUND_CHAR_DB_ID] = char_db_id;
    new const sessionDbId = sPlayerAccounts[playerid][E_ACC_SESSION_DB_ID];

    if (DB_IsConnected() && sessionDbId > 0)
    {
        mysql_format(gMySQL, sAccountSqlBuffer, sizeof(sAccountSqlBuffer),
            "UPDATE `account_sessions` SET `char_id` = %d WHERE `id` = %d;",
            char_db_id,
            sessionDbId);
        mysql_tquery(gMySQL, sAccountSqlBuffer);
    }
    return 1;
}

stock Account_GetUsername(playerid, output[], len = sizeof(output))
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        output[0] = EOS;
        return 0;
    }
    format(output, len, "%s", sPlayerAccounts[playerid][E_ACC_USERNAME]);
    return 1;
}

stock Account_GetIp(playerid, output[], len = sizeof(output))
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        output[0] = EOS;
        return 0;
    }
    format(output, len, "%s", sPlayerAccounts[playerid][E_ACC_IP]);
    return 1;
}

stock Account_GetHwid(playerid, output[], len = sizeof(output))
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        output[0] = EOS;
        return 0;
    }
    format(output, len, "%s", sPlayerAccounts[playerid][E_ACC_HWID]);
    return 1;
}

// =============================================================================
//  6. СИСТЕМНЫЕ ХУКИ И ОБРАБОТЧИКИ ДИАЛОГОВ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        Internal_ResetAccountSlot(i);
    }

    for (new r = 0; r < MAX_RAM_CACHED_ACCOUNTS; r++)
    {
        sRamAccountCache[r][E_RAM_ACC_USED] = false;
        sRamAccountCache[r][E_RAM_ACC_DB_ID] = 0;
        sRamAccountCache[r][E_RAM_ACC_USERNAME][0] = EOS;
        sRamAccountCache[r][E_RAM_ACC_PASSWORD_HASH][0] = EOS;
        sRamAccountCache[r][E_RAM_ACC_EMAIL][0] = EOS;
        sRamAccountCache[r][E_RAM_ACC_ADMIN_LEVEL] = 0;
    }

    new const bool:validSample = Internal_ValidateRpNickFormat("Donald_Trump");
    new const bool:invalidSample = !Internal_ValidateRpNickFormat("bad_nick_123");

    printf("%s [Entities/Account] Account and session module initialized (RP nickname regex: %s, bcrypt cost = %d).",
        SERVER_LOG_PREFIX,
        (validSample && invalidSample) ? ("OK") : ("ERROR"),
        BCRYPT_WORK_FACTOR);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    Internal_ResetAccountSlot(playerid);

    GetPlayerName(playerid, sPlayerAccounts[playerid][E_ACC_USERNAME], MAX_PLAYER_NAME + 1);
    GetPlayerIp(playerid, sPlayerAccounts[playerid][E_ACC_IP], ACCOUNT_IP_MAX_LEN);
    GPCI(playerid, sPlayerAccounts[playerid][E_ACC_HWID], ACCOUNT_HWID_MAX_LEN);
    sPlayerAccounts[playerid][E_ACC_CONNECTED_UNIX] = gettime();

    // Базовый профиль спавна на случай перехода из режима наблюдения
    SetSpawnInfo(playerid, NO_TEAM, 26, 1742.90, -1862.40, 13.57, 0.0);

    // Очистка чата при входе и вывод приветственного заголовка
    for (new line = 0; line < 15; line++)
    {
        SendClientMessage(playerid, -1, " ");
    }
    SendClientMessage(playerid, COLOR_SERVER_GOLD,
        "Welcome to SAN ANDREAS RP | Fair market, honest physics and survival!");

    // 1. Валидация формата RP-ника First_Last через Pawn.Regex
    if (!Internal_ValidateRpNickFormat(sPlayerAccounts[playerid][E_ACC_USERNAME]))
    {
        new rejectMsg[512];
        format(rejectMsg, sizeof(rejectMsg),
            "{FF4444}Invalid roleplay name format (Non-RP nickname)!{FFFFFF}\n\nYour current nickname: {FFC800}%s{FFFFFF}\n\nThe server enforces a strict American name standard in the format {66CC66}First_Last{FFFFFF} using Latin characters.\nExamples of valid names: {88CCFF}Donald_Trump{FFFFFF}, {88CCFF}John_Gotti{FFFFFF}, {88CCFF}Arthur_Morgan{FFFFFF}.\n\nPlease change your name in the SA-MP / open.mp launcher and reconnect.",
            sPlayerAccounts[playerid][E_ACC_USERNAME]);

        Internal_KickWithReasonDialog(
            playerid,
            DIALOG_ACC_NONRP_NICK,
            "{FF4444}SAN ANDREAS RP {FFFFFF}| Character Name Format",
            rejectMsg);
        return 1;
    }

    // 2. Асинхронная проверка аккаунта и бана по нику, IP и HWID (или поиск в RAM-кеше)
    sPlayerAccounts[playerid][E_ACC_STATE] = ACC_STATE_CHECKING_DB;

    if (DB_IsConnected())
    {
        mysql_format(gMySQL, sAccountSqlBuffer, sizeof(sAccountSqlBuffer),
            "SELECT `id`, `username`, `password_hash`, IFNULL(`email`, '') AS `email`, `admin_level`, `is_banned`, IFNULL(`ban_reason`, '') AS `ban_reason`, IFNULL(UNIX_TIMESTAMP(`ban_expires_at`), 0) AS `ban_expires_unix` FROM `accounts` WHERE `username` = '%e' OR (`is_banned` = 1 AND (`last_ip` = '%e' OR (`last_hwid` IS NOT NULL AND `last_hwid` != '' AND `last_hwid` = '%e'))) ORDER BY (`username` = '%e') DESC, `is_banned` DESC LIMIT 1;",
            sPlayerAccounts[playerid][E_ACC_USERNAME],
            sPlayerAccounts[playerid][E_ACC_IP],
            sPlayerAccounts[playerid][E_ACC_HWID],
            sPlayerAccounts[playerid][E_ACC_USERNAME]);

        mysql_tquery(gMySQL, sAccountSqlBuffer, "OnAccountLookupCompleted", "dd",
            playerid, Config_GetPlayerSessionToken(playerid));
    }
    else
    {
        new const ramSlot = Internal_FindRamAccountSlot(sPlayerAccounts[playerid][E_ACC_USERNAME]);
        if (ramSlot != -1)
        {
            sPlayerAccounts[playerid][E_ACC_DB_ID] = sRamAccountCache[ramSlot][E_RAM_ACC_DB_ID];
            format(sPlayerAccounts[playerid][E_ACC_PASSWORD_HASH], BCRYPT_HASH_LENGTH, "%s", sRamAccountCache[ramSlot][E_RAM_ACC_PASSWORD_HASH]);
            format(sPlayerAccounts[playerid][E_ACC_EMAIL], ACCOUNT_EMAIL_MAX_LEN, "%s", sRamAccountCache[ramSlot][E_RAM_ACC_EMAIL]);
            sPlayerAccounts[playerid][E_ACC_ADMIN_LEVEL] = sRamAccountCache[ramSlot][E_RAM_ACC_ADMIN_LEVEL];
            Internal_ShowLoginPasswordDialog(playerid);
        }
        else
        {
            Internal_ShowRegisterPasswordDialog(playerid);
        }
    }
    return 1;
}

hook OnPlayerRequestClass(playerid, classid)
{
    #pragma unused classid
    if (sPlayerAccounts[playerid][E_ACC_STATE] == ACC_STATE_KICK_PENDING)
    {
        TogglePlayerSpectating(playerid, true);
        return 0;
    }

    // Пока персонаж не создан / не загружен, переводим игрока в режим наблюдения (скрываем << >> Spawn)
    if (sPlayerAccounts[playerid][E_ACC_STATE] != ACC_STATE_AUTHENTICATED ||
        sPlayerAccounts[playerid][E_ACC_BOUND_CHAR_DB_ID] <= 0)
    {
        TogglePlayerSpectating(playerid, true);
        defer Account_SyncLobbyCameraAndDialog(playerid, Config_GetPlayerSessionToken(playerid));
        return 0;
    }
    return 1;
}

hook OnPlayerRequestSpawn(playerid)
{
    if (sPlayerAccounts[playerid][E_ACC_STATE] != ACC_STATE_AUTHENTICATED ||
        sPlayerAccounts[playerid][E_ACC_BOUND_CHAR_DB_ID] <= 0)
    {
        TogglePlayerSpectating(playerid, true);
        defer Account_SyncLobbyCameraAndDialog(playerid, Config_GetPlayerSessionToken(playerid));
        return Y_HOOKS_BREAK_RETURN_0;
    }
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    new const sessionDbId = sPlayerAccounts[playerid][E_ACC_SESSION_DB_ID];
    new const charDbId = sPlayerAccounts[playerid][E_ACC_BOUND_CHAR_DB_ID];

    if (DB_IsConnected() && sessionDbId > 0)
    {
        if (charDbId > 0)
        {
            mysql_format(gMySQL, sAccountSqlBuffer, sizeof(sAccountSqlBuffer),
                "UPDATE `account_sessions` SET `char_id` = %d, `disconnected_at` = NOW(), `disconnect_reason` = %d WHERE `id` = %d;",
                charDbId,
                reason,
                sessionDbId);
        }
        else
        {
            mysql_format(gMySQL, sAccountSqlBuffer, sizeof(sAccountSqlBuffer),
                "UPDATE `account_sessions` SET `disconnected_at` = NOW(), `disconnect_reason` = %d WHERE `id` = %d;",
                reason,
                sessionDbId);
        }
        mysql_tquery(gMySQL, sAccountSqlBuffer);
    }

    Internal_ResetAccountSlot(playerid);
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused listitem
    switch (dialogid)
    {
        case DIALOG_ACC_BAN_NOTICE, DIALOG_ACC_NONRP_NICK:
        {
            Kick(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ACC_REGISTER_PASSWORD:
        {
            if (!response)
            {
                SendClientMessage(playerid, COLOR_UI_WARNING,
                    "You declined account registration. See you in the State of San Andreas!");
                defer Account_DelayedKickTimer(playerid, Config_GetPlayerSessionToken(playerid));
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const passLen = strlen(inputtext);
            if (passLen < ACCOUNT_PASSWORD_MIN_LEN || passLen > ACCOUNT_PASSWORD_MAX_LEN)
            {
                Internal_ShowRegisterPasswordDialog(
                    playerid,
                    "Password length must be between 6 and 32 characters!");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            for (new i = 0; i < passLen; i++)
            {
                if (inputtext[i] < 33 || inputtext[i] == '%')
                {
                    Internal_ShowRegisterPasswordDialog(
                        playerid,
                        "The password must not contain spaces or control characters!");
                    return Y_HOOKS_BREAK_RETURN_1;
                }
            }

            format(sPlayerAccounts[playerid][E_ACC_TEMP_PASSWORD], ACCOUNT_PASSWORD_MAX_LEN + 1, "%s", inputtext);
            Internal_ShowRegisterEmailDialog(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ACC_REGISTER_EMAIL:
        {
            if (!response)
            {
                // Игрок нажал «Пропустить» — регистрируем без E-Mail
                sPlayerAccounts[playerid][E_ACC_EMAIL][0] = EOS;
                Internal_BeginPasswordHashing(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            if (inputtext[0] == EOS)
            {
                sPlayerAccounts[playerid][E_ACC_EMAIL][0] = EOS;
                Internal_BeginPasswordHashing(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            if (!Internal_ValidateEmailFormat(inputtext))
            {
                Internal_ShowRegisterEmailDialog(
                    playerid,
                    "Invalid email address format!");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            format(sPlayerAccounts[playerid][E_ACC_EMAIL], ACCOUNT_EMAIL_MAX_LEN, "%s", inputtext);
            Internal_BeginPasswordHashing(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ACC_LOGIN_PASSWORD:
        {
            if (!response)
            {
                SendClientMessage(playerid, COLOR_UI_WARNING,
                    "You interrupted the login procedure. The connection has been closed.");
                defer Account_DelayedKickTimer(playerid, Config_GetPlayerSessionToken(playerid));
                return Y_HOOKS_BREAK_RETURN_1;
            }

            if (strlen(inputtext) < 1)
            {
                Internal_ShowLoginPasswordDialog(playerid, "The password field cannot be empty!");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            sPlayerAccounts[playerid][E_ACC_STATE] = ACC_STATE_VERIFYING_PASSWORD;
            bcrypt_verify(
                playerid,
                "OnAccountPasswordVerified",
                inputtext,
                sPlayerAccounts[playerid][E_ACC_PASSWORD_HASH],
                "d",
                Config_GetPlayerSessionToken(playerid));
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_0;
}

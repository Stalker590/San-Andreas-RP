/*
 * =============================================================================
 *  SAN ANDREAS RP ó ƒËÌ‡ÏË˜ÂÒÍ‡ˇ ‡‰ÏËÌ-ÒËÒÚÂÏ‡, RBAC-‡Ì„Ë Ë ‡Û‰ËÚ
 *  ‘‡ÈÎ:      gamemodes/modules/systems/mod_admin.pwn
 *  œÛÌÍÚ:     ROADMAP [10.1] ó ¡ƒ Ë ˇ‰Ó RBAC, ÒËÒÚÂÏÌ‡ˇ Root-ÓÎ¸
 *   Ó‰ËÓ‚Í‡: Windows-1251 (CP1251) ·ÂÁ BOM
 * =============================================================================
 */

#if defined _mod_admin_included
    #endinput
#endif
#define _mod_admin_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1.  ŒÕ—“¿Õ“€ RBAC, œ”À€ œ¿Ãﬂ“» » œ≈–≈◊»—À≈Õ»≈ –¿«–≈ÿ≈Õ»…
// =============================================================================

#define MAX_ADMIN_ROLES                         (64)
#define MAX_ADMIN_ROLE_NAME                     (48)
#define MAX_ADMIN_PERMISSIONS                   (64)
#define ADMIN_PERM_TOTAL                        (51)
#define ADMIN_INVALID_ROLE                      (-1)
#define ADMIN_PERMISSION_KEY_LEN                (48)
#define ADMIN_PERMISSION_NAME_LEN               (64)
#define ADMIN_PERMISSION_CATEGORY_LEN           (32)

enum E_ADMIN_PERM
{
    ADMIN_PERM_NONE = 0,
    ADMIN_PERM_PANEL_ACCESS,
    ADMIN_PERM_HELP_ACCESS,
    ADMIN_PERM_MANAGE_ADMINS,
    ADMIN_PERM_MANAGE_ROLES,
    ADMIN_PERM_VIEW_AUDIT,
    ADMIN_PERM_VIEW_ANTICHEAT,
    ADMIN_PERM_PLAYER_TELEPORT,
    ADMIN_PERM_PLAYER_GET_HERE,
    ADMIN_PERM_PLAYER_SPECTATE,
    ADMIN_PERM_PLAYER_FREEZE,
    ADMIN_PERM_PLAYER_SLAP,
    ADMIN_PERM_PLAYER_SET_STATS,
    ADMIN_PERM_PLAYER_SET_SKIN,
    ADMIN_PERM_PLAYER_KICK,
    ADMIN_PERM_PLAYER_BAN,
    ADMIN_PERM_PLAYER_UNBAN,
    ADMIN_PERM_PLAYER_MUTE,
    ADMIN_PERM_PLAYER_WARN,
    ADMIN_PERM_PLAYER_JAIL,
    ADMIN_PERM_PLAYER_SET_WANTED,
    ADMIN_PERM_ORG_SET_LEADER,
    ADMIN_PERM_ORG_SET_MEMBER,
    ADMIN_PERM_ORG_MANAGE_RANKS,
    ADMIN_PERM_CHAR_SET_LEVEL,
    ADMIN_PERM_CHAR_SET_EXP,
    ADMIN_PERM_CHAR_SET_SKILLS,
    ADMIN_PERM_CHAR_SET_LICENSES,
    ADMIN_PERM_CHAR_SET_STATUS,
    ADMIN_PERM_ECON_GIVE_CASH,
    ADMIN_PERM_ECON_SET_BANK,
    ADMIN_PERM_ECON_CLEAR_DEBT,
    ADMIN_PERM_ECON_ISSUE_DEBT,
    ADMIN_PERM_INV_VIEW,
    ADMIN_PERM_INV_GIVE_ITEM,
    ADMIN_PERM_INV_EDIT_ITEM,
    ADMIN_PERM_INV_CLEAR,
    ADMIN_PERM_PROP_GIVE,
    ADMIN_PERM_PROP_REMOVE,
    ADMIN_PERM_VEH_SPAWN,
    ADMIN_PERM_VEH_DELETE,
    ADMIN_PERM_VEH_KEYS,
    ADMIN_PERM_VEH_REFUEL,
    ADMIN_PERM_VEH_REPAIR,
    ADMIN_PERM_VEH_TELEPORT,
    ADMIN_PERM_WORLD_TELEPORT,
    ADMIN_PERM_WORLD_WEATHER,
    ADMIN_PERM_WORLD_TIME,
    ADMIN_PERM_WORLD_ANNOUNCE,
    ADMIN_PERM_SERVER_SAVE,
    ADMIN_PERM_SERVER_RESTART,
    ADMIN_PERM_COUNT
};

enum E_PUNISHMENT_TYPE
{
    PUNISHMENT_MUTE = 0,
    PUNISHMENT_WARN,
    PUNISHMENT_DEMORGAN,
    PUNISHMENT_BAN_TEMP,
    PUNISHMENT_BAN_PERM
};

enum E_ADMIN_PERM_META
{
    E_APM_KEY[ADMIN_PERMISSION_KEY_LEN],
    E_APM_NAME[ADMIN_PERMISSION_NAME_LEN],
    E_APM_CATEGORY[ADMIN_PERMISSION_CATEGORY_LEN]
};

enum E_ADMIN_ROLE_DATA
{
    bool:E_AR_VALID,
    E_AR_DB_ID,
    E_AR_NAME[MAX_ADMIN_ROLE_NAME],
    E_AR_LEVEL,
    bool:E_AR_IS_ROOT,
    bool:E_AR_IS_SYSTEM
};

// =============================================================================
//  2. »Õ ¿œ—”À»–Œ¬¿ÕÕŒ≈ —Œ—“ŒﬂÕ»≈ RBAC (static stock)
// =============================================================================

static stock sAdminRoles[MAX_ADMIN_ROLES][E_ADMIN_ROLE_DATA];
static stock sAdminRolePerms[MAX_ADMIN_ROLES][MAX_ADMIN_PERMISSIONS];
static stock sAdminRoleCount = 0;
static stock sNextAdminRoleDbId = 1;

static stock sPlayerAdminRole[MAX_PLAYERS];
static stock bool:sPlayerAdminLoaded[MAX_PLAYERS];
static stock sPlayerMuteUntil[MAX_PLAYERS];
static stock sPlayerWarnCount[MAX_PLAYERS];

static stock sAdminSqlBuffer[768];

static stock const sAdminPermMeta[ADMIN_PERM_TOTAL][E_ADMIN_PERM_META] =
{
    { "", "No right", "Official" },
    { "ADMIN_PANEL_ACCESS", "Access to the admin panel", "Access" },
    { "ADMIN_HELP_ACCESS", "Access help /ahelp", "Access" },
    { "MANAGE_ADMINS", "Appointment and removal of administrators", "Access" },
    { "MANAGE_ROLES", "Creating and setting up admin roles", "Access" },
    { "VIEW_AUDIT", "Viewing the Audit Log", "Access" },
    { "VIEW_ANTICHEAT", "View anti-cheat statistics", "Access" },
    { "PLAYER_TELEPORT", "Teleport to player (/goto)", "Players" },
    { "PLAYER_GET_HERE", "Teleport player to yourself (/gethere)", "Players" },
    { "PLAYER_SPECTATE", "Player tracking (/sp)", "Players" },
    { "PLAYER_FREEZE", "Freezing and unfreezing a player", "Players" },
    { "PLAYER_SLAP", "Player slap", "Players" },
    { "PLAYER_SET_STATS", "HP, Armor and Physiology Changes", "Players" },
    { "PLAYER_SET_SKIN", "Changing player skin", "Players" },
    { "PLAYER_KICK", "Kick and quiet kick", "Players" },
    { "PLAYER_BAN", "Temporary and permanent ban", "Players" },
    { "PLAYER_UNBAN", "Unban account", "Players" },
    { "PLAYER_MUTE", "Mute player", "Players" },
    { "PLAYER_WARN", "Issuing a warning", "Players" },
    { "PLAYER_JAIL", "Admin jail (demorgan)", "Players" },
    { "PLAYER_SET_WANTED", "Changing your wanted level", "Players" },
    { "ORG_SET_LEADER", "Appointment of an organization leader", "Factions" },
    { "ORG_SET_MEMBER", "Appointment of an organization member", "Factions" },
    { "ORG_MANAGE_RANKS", "Organization rank management", "Factions" },
    { "CHAR_SET_LEVEL", "Changing Character Level", "Character" },
    { "CHAR_SET_EXP", "Changing Character Experience", "Character" },
    { "CHAR_SET_SKILLS", "Changing Character Skills", "Character" },
    { "CHAR_SET_LICENSES", "License management", "Character" },
    { "CHAR_SET_STATUS", "Changing a Character's Status", "Character" },
    { "ECON_GIVE_CASH", "Cash issuance and withdrawal", "Economics" },
    { "ECON_SET_BANK", "Change in bank balance", "Economics" },
    { "ECON_CLEAR_DEBT", "Repay bank debt", "Economics" },
    { "ECON_ISSUE_DEBT", "Give bank debt", "Economics" },
    { "INV_VIEW", "View Inventory and Storage", "Inventory" },
    { "INV_GIVE_ITEM", "Issue of items", "Inventory" },
    { "INV_EDIT_ITEM", "Editing Items", "Inventory" },
    { "INV_CLEAR", "Clearing Inventory", "Inventory" },
    { "PROP_GIVE", "Give property", "Property" },
    { "PROP_REMOVE", "Confiscate property", "Property" },
    { "VEH_SPAWN", "Vehicle spawn", "Vehicle" },
    { "VEH_DELETE", "Removing and respawning vehicles", "Vehicle" },
    { "VEH_KEYS", "Give vehicle keys", "Vehicle" },
    { "VEH_REFUEL", "Refueling vehicles", "Vehicle" },
    { "VEH_REPAIR", "Vehicle repair", "Vehicle" },
    { "VEH_TELEPORT", "Vehicle teleport", "Vehicle" },
    { "WORLD_TELEPORT", "Teleport by coordinates and worlds", "world" },
    { "WORLD_WEATHER", "Change of weather", "world" },
    { "WORLD_TIME", "Change of time of day", "world" },
    { "WORLD_ANNOUNCE", "Global announcements", "world" },
    { "SERVER_SAVE", "Emergency database saving", "Server" },
    { "SERVER_RESTART", "Restarting the server", "Server" }
};

// =============================================================================
//  3. ¬Õ”“–≈ÕÕ»≈ ‘”Õ ÷»» –ŒÀ≈… » »√–Œ Œ¬
// =============================================================================

static stock Internal_FindRoleIndexByDbId(role_db_id)
{
    if (role_db_id <= 0)
    {
        return ADMIN_INVALID_ROLE;
    }
    for (new i = 0; i < sAdminRoleCount; i++)
    {
        if (sAdminRoles[i][E_AR_VALID] && sAdminRoles[i][E_AR_DB_ID] == role_db_id)
        {
            return i;
        }
    }
    return ADMIN_INVALID_ROLE;
}

static stock Internal_FindRoleIndexByName(const name[])
{
    for (new i = 0; i < sAdminRoleCount; i++)
    {
        if (sAdminRoles[i][E_AR_VALID] && !strcmp(sAdminRoles[i][E_AR_NAME], name, true))
        {
            return i;
        }
    }
    return ADMIN_INVALID_ROLE;
}

static stock Internal_AddRoleToPool(db_id, const name[], level, bool:is_root, bool:is_system)
{
    new slot = ADMIN_INVALID_ROLE;
    for (new i = 0; i < sAdminRoleCount; i++)
    {
        if (!sAdminRoles[i][E_AR_VALID])
        {
            slot = i;
            break;
        }
    }
    if (slot == ADMIN_INVALID_ROLE)
    {
        if (sAdminRoleCount >= MAX_ADMIN_ROLES)
        {
            return ADMIN_INVALID_ROLE;
        }
        slot = sAdminRoleCount;
        sAdminRoleCount++;
    }

    sAdminRoles[slot][E_AR_VALID] = true;
    sAdminRoles[slot][E_AR_DB_ID] = db_id;
    format(sAdminRoles[slot][E_AR_NAME], MAX_ADMIN_ROLE_NAME, "%s", name);
    sAdminRoles[slot][E_AR_LEVEL] = level;
    sAdminRoles[slot][E_AR_IS_ROOT] = is_root;
    sAdminRoles[slot][E_AR_IS_SYSTEM] = is_system;

    for (new p = 0; p < MAX_ADMIN_PERMISSIONS; p++)
    {
        sAdminRolePerms[slot][p] = is_root;
    }

    if (db_id >= sNextAdminRoleDbId)
    {
        sNextAdminRoleDbId = db_id + 1;
    }
    return slot;
}

static stock Internal_FindPlayerByAccountId(account_id)
{
    if (account_id <= 0)
    {
        return INVALID_PLAYER_ID;
    }
    foreach (new playerid : Player)
    {
        if (Account_IsLogged(playerid) && Account_GetId(playerid) == account_id)
        {
            return playerid;
        }
    }
    return INVALID_PLAYER_ID;
}

static stock Internal_ApplyRoleToOnline(account_id, role_db_id)
{
    new const playerid = Internal_FindPlayerByAccountId(account_id);
    if (playerid == INVALID_PLAYER_ID)
    {
        return 0;
    }
    sPlayerAdminRole[playerid] = Internal_FindRoleIndexByDbId(role_db_id);
    sPlayerAdminLoaded[playerid] = true;
    return 1;
}

// =============================================================================
//  4. œ”¡À»◊Õ€… API RBAC
// =============================================================================

stock Admin_ResetRuntime()
{
    sAdminRoleCount = 0;
    sNextAdminRoleDbId = 1;
    for (new i = 0; i < MAX_ADMIN_ROLES; i++)
    {
        sAdminRoles[i][E_AR_VALID] = false;
        for (new p = 0; p < MAX_ADMIN_PERMISSIONS; p++)
        {
            sAdminRolePerms[i][p] = false;
        }
    }
    for (new p = 0; p < MAX_PLAYERS; p++)
    {
        sPlayerAdminRole[p] = ADMIN_INVALID_ROLE;
        sPlayerAdminLoaded[p] = false;
        sPlayerMuteUntil[p] = 0;
        sPlayerWarnCount[p] = 0;
    }
    return 1;
}

stock Admin_LoadRoles()
{
    Admin_ResetRuntime();

    if (!DB_IsConnected())
    {
        Internal_AddRoleToPool(1, "Root administrator", 100, true, true);
        printf("%s [Systems/Admin] MySQL is unavailable: the built-in Root role (RAM) is activated.",
            SERVER_LOG_PREFIX);
        return 1;
    }

    new const Cache:roleCache = mysql_query(gMySQL,
        "SELECT `id`, `name`, `level`, `is_root`, `is_system` FROM `admin_roles` ORDER BY `level` DESC, `id` ASC;",
        true);

    if (cache_is_valid(roleCache))
    {
        new rowCount = 0;
        cache_get_row_count(rowCount);
        for (new row = 0; row < rowCount; row++)
        {
            new dbId, level, isRoot, isSystem;
            new name[MAX_ADMIN_ROLE_NAME];
            cache_get_value_name_int(row, "id", dbId);
            cache_get_value_name(row, "name", name, sizeof(name));
            cache_get_value_name_int(row, "level", level);
            cache_get_value_name_int(row, "is_root", isRoot);
            cache_get_value_name_int(row, "is_system", isSystem);
            Internal_AddRoleToPool(dbId, name, level, (isRoot != 0), (isSystem != 0));
        }
        cache_delete(roleCache);
    }

    if (Admin_GetRootRoleDbId() == 0)
    {
        new rootRoleId = 1;
        if (Internal_FindRoleIndexByDbId(rootRoleId) != ADMIN_INVALID_ROLE)
        {
            rootRoleId = sNextAdminRoleDbId++;
        }
        Internal_AddRoleToPool(rootRoleId, "Root administrator", 100, true, true);
    }

    new const Cache:permCache = mysql_query(gMySQL,
        "SELECT `role_id`, `permission_key`, `is_allowed` FROM `admin_role_permissions`;",
        true);

    if (cache_is_valid(permCache))
    {
        new rowCount = 0;
        cache_get_row_count(rowCount);
        for (new row = 0; row < rowCount; row++)
        {
            new roleDbId, allowed;
            new key[ADMIN_PERMISSION_KEY_LEN];
            cache_get_value_name_int(row, "role_id", roleDbId);
            cache_get_value_name(row, "permission_key", key, sizeof(key));
            cache_get_value_name_int(row, "is_allowed", allowed);

            new const roleIndex = Internal_FindRoleIndexByDbId(roleDbId);
            if (roleIndex == ADMIN_INVALID_ROLE || sAdminRoles[roleIndex][E_AR_IS_ROOT])
            {
                continue;
            }

            for (new p = 1; p < _:ADMIN_PERM_COUNT; p++)
            {
                if (!strcmp(sAdminPermMeta[p][E_APM_KEY], key, true))
                {
                    sAdminRolePerms[roleIndex][p] = (allowed != 0);
                    break;
                }
            }
        }
        cache_delete(permCache);
    }

    printf("%s [Systems/Admin] Loaded admin roles: %d (Root: %s).",
        SERVER_LOG_PREFIX,
        sAdminRoleCount,
        (Admin_GetRootRoleDbId() > 0) ? ("Yes") : ("No"));
    return 1;
}

stock Admin_GetRootRoleDbId()
{
    for (new i = 0; i < sAdminRoleCount; i++)
    {
        if (sAdminRoles[i][E_AR_VALID] && sAdminRoles[i][E_AR_IS_ROOT])
        {
            return sAdminRoles[i][E_AR_DB_ID];
        }
    }
    return 0;
}

stock Admin_GetRoleDbIdByIndex(index)
{
    if (index < 0 || index >= sAdminRoleCount || !sAdminRoles[index][E_AR_VALID])
    {
        return 0;
    }
    return sAdminRoles[index][E_AR_DB_ID];
}

stock Admin_GetRoleNameByDbId(role_db_id, output[], len = sizeof(output))
{
    output[0] = EOS;
    new const index = Internal_FindRoleIndexByDbId(role_db_id);
    if (index == ADMIN_INVALID_ROLE)
    {
        return 0;
    }
    format(output, len, "%s", sAdminRoles[index][E_AR_NAME]);
    return 1;
}

stock Admin_GetRoleLevelByDbId(role_db_id)
{
    new const index = Internal_FindRoleIndexByDbId(role_db_id);
    if (index == ADMIN_INVALID_ROLE)
    {
        return 0;
    }
    return sAdminRoles[index][E_AR_LEVEL];
}

stock Admin_IsRoot(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sPlayerAdminLoaded[playerid])
    {
        return 0;
    }
    new const index = sPlayerAdminRole[playerid];
    if (index == ADMIN_INVALID_ROLE)
    {
        return 0;
    }
    return sAdminRoles[index][E_AR_IS_ROOT] ? 1 : 0;
}

stock bool:Admin_HasPermission(playerid, E_ADMIN_PERM:perm)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !IsPlayerConnected(playerid))
    {
        return false;
    }
    if (!sPlayerAdminLoaded[playerid] || !Account_IsLogged(playerid))
    {
        return false;
    }

    new const index = sPlayerAdminRole[playerid];
    if (index == ADMIN_INVALID_ROLE || !sAdminRoles[index][E_AR_VALID])
    {
        return false;
    }
    if (sAdminRoles[index][E_AR_IS_ROOT])
    {
        return true;
    }
    if (_:perm <= 0 || _:perm >= _:ADMIN_PERM_COUNT)
    {
        return false;
    }
    return (sAdminRolePerms[index][_:perm] != 0);
}

stock Admin_GetRoleName(playerid, output[], len = sizeof(output))
{
    output[0] = EOS;
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sPlayerAdminLoaded[playerid])
    {
        return 0;
    }
    new const index = sPlayerAdminRole[playerid];
    if (index == ADMIN_INVALID_ROLE)
    {
        return 0;
    }
    format(output, len, "%s", sAdminRoles[index][E_AR_NAME]);
    return 1;
}

stock Admin_GetRoleLevel(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sPlayerAdminLoaded[playerid])
    {
        return 0;
    }
    new const index = sPlayerAdminRole[playerid];
    if (index == ADMIN_INVALID_ROLE)
    {
        return 0;
    }
    return sAdminRoles[index][E_AR_LEVEL];
}

stock Admin_GetPlayerRoleDbId(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sPlayerAdminLoaded[playerid])
    {
        return 0;
    }
    new const index = sPlayerAdminRole[playerid];
    if (index == ADMIN_INVALID_ROLE)
    {
        return 0;
    }
    return sAdminRoles[index][E_AR_DB_ID];
}

stock Admin_GetPermissionKey(E_ADMIN_PERM:perm, output[], len = sizeof(output))
{
    output[0] = EOS;
    if (_:perm <= 0 || _:perm >= _:ADMIN_PERM_COUNT)
    {
        return 0;
    }
    new idx = _:perm;
    format(output, len, "%s", sAdminPermMeta[idx][E_APM_KEY]);
    return 1;
}

stock Admin_GetPermissionNameRu(E_ADMIN_PERM:perm, output[], len = sizeof(output))
{
    output[0] = EOS;
    if (_:perm <= 0 || _:perm >= _:ADMIN_PERM_COUNT)
    {
        return 0;
    }
    new idx = _:perm;
    format(output, len, "%s", sAdminPermMeta[idx][E_APM_NAME]);
    return 1;
}

stock Admin_GetPermissionCategoryRu(E_ADMIN_PERM:perm, output[], len = sizeof(output))
{
    output[0] = EOS;
    if (_:perm <= 0 || _:perm >= _:ADMIN_PERM_COUNT)
    {
        return 0;
    }
    new idx = _:perm;
    format(output, len, "%s", sAdminPermMeta[idx][E_APM_CATEGORY]);
    return 1;
}

stock Admin_GetRolePermission(role_db_id, E_ADMIN_PERM:perm)
{
    new const index = Internal_FindRoleIndexByDbId(role_db_id);
    if (index == ADMIN_INVALID_ROLE || _:perm <= 0 || _:perm >= _:ADMIN_PERM_COUNT)
    {
        return 0;
    }
    if (sAdminRoles[index][E_AR_IS_ROOT])
    {
        return 1;
    }
    return sAdminRolePerms[index][_:perm] ? 1 : 0;
}

stock Admin_GetRoleCount()
{
    return sAdminRoleCount;
}

timer Admin_DelayedKick[250](playerid, sessionToken)
{
    if (Config_ValidatePlayerToken(playerid, sessionToken))
    {
        Kick(playerid);
    }
}

// =============================================================================
//  5. ¿”ƒ»“ » Õ¿ ¿«¿Õ»ﬂ
// =============================================================================

stock Admin_Audit(playerid, target_account_id, target_char_id, const action[], item_def_id, amount, const details[])
{
    new admin_account_id = 0;
    new actor_char_id = 0;
    if (playerid >= 0 && playerid < MAX_PLAYERS)
    {
        if (Account_IsLogged(playerid)) admin_account_id = Account_GetId(playerid);
        if (Character_IsLoaded(playerid)) actor_char_id = Character_GetId(playerid);
    }
    return Audit_LogAdmin(admin_account_id, target_account_id, target_char_id, actor_char_id,
        action, "ADMIN_PANEL", "PLAYER", item_def_id, amount, details);
}

stock Admin_LogDenied(playerid, const action[], const details[])
{
    #pragma unused action
    new admin_account_id = 0;
    new actor_char_id = 0;
    if (playerid >= 0 && playerid < MAX_PLAYERS)
    {
        if (Account_IsLogged(playerid)) admin_account_id = Account_GetId(playerid);
        if (Character_IsLoaded(playerid)) actor_char_id = Character_GetId(playerid);
    }
    return Audit_LogAdmin(admin_account_id, 0, 0, actor_char_id, "ADMIN_DENIED",
        "ADMIN_PANEL", "ACCESS", 0, 0, details);
}

stock bool:Admin_IsMuted(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return false;
    }
    if (sPlayerMuteUntil[playerid] == 0)
    {
        return false;
    }
    if (sPlayerMuteUntil[playerid] <= gettime())
    {
        sPlayerMuteUntil[playerid] = 0;
        return false;
    }
    return true;
}

stock Admin_GetMuteSecondsLeft(playerid)
{
    if (!Admin_IsMuted(playerid))
    {
        return 0;
    }
    return sPlayerMuteUntil[playerid] - gettime();
}

stock Admin_Unmute(playerid, target_playerid)
{
    if (target_playerid < 0 || target_playerid >= MAX_PLAYERS || !Character_IsLoaded(target_playerid))
    {
        return 0;
    }
    sPlayerMuteUntil[target_playerid] = 0;
    new const target_account_id = Account_GetId(target_playerid);
    if (target_account_id > 0 && DB_IsConnected())
    {
        new const admin_account_id = Account_IsLogged(playerid) ? Account_GetId(playerid) : 0;
        if (admin_account_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "UPDATE `admin_punishments` SET `is_active` = 0, `revoked_by_account_id` = %d, `revoked_at` = NOW() WHERE `target_account_id` = %d AND `punishment_type` = 'MUTE' AND `is_active` = 1;",
                admin_account_id, target_account_id);
        }
        else
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "UPDATE `admin_punishments` SET `is_active` = 0, `revoked_at` = NOW() WHERE `target_account_id` = %d AND `punishment_type` = 'MUTE' AND `is_active` = 1;",
                target_account_id);
        }
        mysql_tquery(gMySQL, sAdminSqlBuffer);
    }
    SendClientMessage(target_playerid, COLOR_UI_INFO, "The administrator has removed the mutt from you.");
    Admin_Audit(playerid, target_account_id, Character_GetId(target_playerid), "ADMIN_UNMUTE", 0, 0, "Mute removal");
    return 1;
}

stock Admin_GetWarnCount(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return sPlayerWarnCount[playerid];
}

stock bool:Admin_BanAccount(playerid, target_account_id, minutes, const reason[])
{
    if (target_account_id <= 0)
    {
        return false;
    }

    new admin_account_id = Account_IsLogged(playerid) ? Account_GetId(playerid) : 0;
    new target_char_id = 0;
    new const target_playerid = Internal_FindPlayerByAccountId(target_account_id);
    if (target_playerid != INVALID_PLAYER_ID && Character_IsLoaded(target_playerid))
    {
        target_char_id = Character_GetId(target_playerid);
    }

    if (minutes > 0)
    {
        mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
            "UPDATE `accounts` SET `is_banned` = 1, `ban_reason` = '%e', `ban_expires_at` = DATE_ADD(NOW(), INTERVAL %d MINUTE) WHERE `id` = %d;",
            reason, minutes, target_account_id);
        mysql_tquery(gMySQL, sAdminSqlBuffer);

        if (target_char_id > 0 && admin_account_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `target_char_id`, `admin_account_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) VALUES (%d, %d, %d, 'BAN_TEMP', '%e', DATE_ADD(NOW(), INTERVAL %d MINUTE), 1);",
                target_account_id, target_char_id, admin_account_id, reason, minutes);
        }
        else if (target_char_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `target_char_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) VALUES (%d, %d, 'BAN_TEMP', '%e', DATE_ADD(NOW(), INTERVAL %d MINUTE), 1);",
                target_account_id, target_char_id, reason, minutes);
        }
        else if (admin_account_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `admin_account_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) VALUES (%d, %d, 'BAN_TEMP', '%e', DATE_ADD(NOW(), INTERVAL %d MINUTE), 1);",
                target_account_id, admin_account_id, reason, minutes);
        }
        else
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) VALUES (%d, 'BAN_TEMP', '%e', DATE_ADD(NOW(), INTERVAL %d MINUTE), 1);",
                target_account_id, reason, minutes);
        }
        mysql_tquery(gMySQL, sAdminSqlBuffer);

        if (target_playerid != INVALID_PLAYER_ID)
        {
            new msg[192];
            format(msg, sizeof(msg),
                "You are banned for %d minutes. Reason: %s", minutes, reason);
            SendClientMessage(target_playerid, COLOR_UI_ERROR, msg);
            defer Admin_DelayedKick(target_playerid, Config_GetPlayerSessionToken(target_playerid));
        }
    }
    else
    {
        mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
            "UPDATE `accounts` SET `is_banned` = 1, `ban_reason` = '%e', `ban_expires_at` = NULL WHERE `id` = %d;",
            reason, target_account_id);
        mysql_tquery(gMySQL, sAdminSqlBuffer);

        if (target_char_id > 0 && admin_account_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `target_char_id`, `admin_account_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) VALUES (%d, %d, %d, 'BAN_PERM', '%e', NULL, 1);",
                target_account_id, target_char_id, admin_account_id, reason);
        }
        else if (target_char_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `target_char_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) VALUES (%d, %d, 'BAN_PERM', '%e', NULL, 1);",
                target_account_id, target_char_id, reason);
        }
        else if (admin_account_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `admin_account_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) VALUES (%d, %d, 'BAN_PERM', '%e', NULL, 1);",
                target_account_id, admin_account_id, reason);
        }
        else
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) VALUES (%d, 'BAN_PERM', '%e', NULL, 1);",
                target_account_id, reason);
        }
        mysql_tquery(gMySQL, sAdminSqlBuffer);

        if (target_playerid != INVALID_PLAYER_ID)
        {
            SendClientMessage(target_playerid, COLOR_UI_ERROR,
                "You are banned forever. The reason is indicated in the administration log.");
            defer Admin_DelayedKick(target_playerid, Config_GetPlayerSessionToken(target_playerid));
        }
    }

    Admin_Audit(playerid, target_account_id, target_char_id, "ADMIN_BAN", 0, minutes, reason);
    return true;
}

stock bool:Admin_UnbanAccount(playerid, target_account_id)
{
    if (target_account_id <= 0)
    {
        return false;
    }
    new const admin_account_id = Account_IsLogged(playerid) ? Account_GetId(playerid) : 0;

    mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
        "UPDATE `accounts` SET `is_banned` = 0, `ban_reason` = NULL, `ban_expires_at` = NULL WHERE `id` = %d;",
        target_account_id);
    mysql_tquery(gMySQL, sAdminSqlBuffer);

    if (admin_account_id > 0)
    {
        mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
            "UPDATE `admin_punishments` SET `is_active` = 0, `revoked_by_account_id` = %d, `revoked_at` = NOW() WHERE `target_account_id` = %d AND `is_active` = 1 AND `punishment_type` IN ('BAN_TEMP', 'BAN_PERM');",
            admin_account_id, target_account_id);
    }
    else
    {
        mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
            "UPDATE `admin_punishments` SET `is_active` = 0, `revoked_at` = NOW() WHERE `target_account_id` = %d AND `is_active` = 1 AND `punishment_type` IN ('BAN_TEMP', 'BAN_PERM');",
            target_account_id);
    }
    mysql_tquery(gMySQL, sAdminSqlBuffer);

    Admin_Audit(playerid, target_account_id, 0, "ADMIN_UNBAN", 0, 0, "Removing a ban");
    return true;
}

stock Admin_Punish(playerid, target_playerid, E_PUNISHMENT_TYPE:type, const reason[], duration_sec)
{
    if (target_playerid < 0 || target_playerid >= MAX_PLAYERS || !IsPlayerConnected(target_playerid))
    {
        return 0;
    }
    if (!Character_IsLoaded(target_playerid))
    {
        return 0;
    }

    new const target_account_id = Account_GetId(target_playerid);
    new const target_char_id = Character_GetId(target_playerid);
    new const admin_account_id = Account_IsLogged(playerid) ? Account_GetId(playerid) : 0;

    if (target_account_id <= 0)
    {
        return 0;
    }

    if (type == PUNISHMENT_BAN_TEMP || type == PUNISHMENT_BAN_PERM)
    {
        return Admin_BanAccount(playerid, target_account_id, (type == PUNISHMENT_BAN_PERM) ? 0 : (duration_sec / 60), reason) ? 1 : 0;
    }

    if (type == PUNISHMENT_MUTE)
    {
        sPlayerMuteUntil[target_playerid] = gettime() + ((duration_sec > 0) ? duration_sec : 300);
        SendClientMessage(target_playerid, COLOR_UI_ERROR, "You have been issued a mute. The reason was given by the administrator.");
    }
    else if (type == PUNISHMENT_WARN)
    {
        sPlayerWarnCount[target_playerid]++;
        new msg[160];
        format(msg, sizeof(msg), "You have received a warning (%d). Reason: %s",
            sPlayerWarnCount[target_playerid], reason);
        SendClientMessage(target_playerid, COLOR_UI_WARNING, msg);
    }
    else if (type == PUNISHMENT_DEMORGAN)
    {
        Justice_AdminJail(target_playerid, duration_sec, reason);
    }

    new typeName[24];
    if (type == PUNISHMENT_MUTE) format(typeName, sizeof(typeName), "MUTE");
    else if (type == PUNISHMENT_WARN) format(typeName, sizeof(typeName), "WARN");
    else format(typeName, sizeof(typeName), "DEMORGAN");
    if (duration_sec > 0)
    {
        if (admin_account_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `target_char_id`, `admin_account_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) VALUES (%d, %d, %d, '%e', '%e', DATE_ADD(NOW(), INTERVAL %d SECOND), 1);",
                target_account_id, target_char_id, admin_account_id, typeName, reason, duration_sec);
        }
        else
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `target_char_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) VALUES (%d, %d, '%e', '%e', DATE_ADD(NOW(), INTERVAL %d SECOND), 1);",
                target_account_id, target_char_id, typeName, reason, duration_sec);
        }
    }
    else
    {
        if (admin_account_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `target_char_id`, `admin_account_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) VALUES (%d, %d, %d, '%e', '%e', NULL, 1);",
                target_account_id, target_char_id, admin_account_id, typeName, reason);
        }
        else
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `target_char_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) VALUES (%d, %d, '%e', '%e', NULL, 1);",
                target_account_id, target_char_id, typeName, reason);
        }
    }
    mysql_tquery(gMySQL, sAdminSqlBuffer);

    Admin_Audit(playerid, target_account_id, target_char_id, "ADMIN_PUNISH", 0, duration_sec, reason);
    return 1;
}

// =============================================================================
//  6. ”œ–¿¬À≈Õ»≈ –ŒÀﬂÃ» » —Œ—“¿¬ŒÃ
// =============================================================================

stock Admin_CreateRole(playerid, const name[], level)
{
    if (!Admin_HasPermission(playerid, ADMIN_PERM_MANAGE_ROLES))
    {
        Admin_LogDenied(playerid, "ADMIN_ROLE_CREATE", "Insufficient MANAGE_ROLES rights");
        return 0;
    }
    if (strlen(name) < 2 || level < 1 || level > 99 || Internal_FindRoleIndexByName(name) != ADMIN_INVALID_ROLE)
    {
        return 0;
    }
    if (!Admin_IsRoot(playerid) && level >= Admin_GetRoleLevel(playerid))
    {
        Admin_LogDenied(playerid, "ADMIN_ROLE_CREATE", "You cannot create a role at your level or higher");
        return 0;
    }
    if (sAdminRoleCount >= MAX_ADMIN_ROLES)
    {
        return 0;
    }

    new const role_db_id = sNextAdminRoleDbId++;
    new const index = Internal_AddRoleToPool(role_db_id, name, level, false, false);
    if (index == ADMIN_INVALID_ROLE)
    {
        return 0;
    }

    if (DB_IsConnected())
    {
        new const admin_account_id = Account_IsLogged(playerid) ? Account_GetId(playerid) : 0;
        if (admin_account_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_roles` (`id`, `name`, `level`, `is_root`, `is_system`, `permissions_mask`, `created_by_account_id`) VALUES (%d, '%e', %d, 0, 0, 0, %d);",
                role_db_id, name, level, admin_account_id);
        }
        else
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_roles` (`id`, `name`, `level`, `is_root`, `is_system`, `permissions_mask`, `created_by_account_id`) VALUES (%d, '%e', %d, 0, 0, 0, NULL);",
                role_db_id, name, level);
        }
        mysql_tquery(gMySQL, sAdminSqlBuffer);
    }

    new details[160];
    format(details, sizeof(details), "The admin role ì%sî has been created (level %d)", name, level);
    Admin_Audit(playerid, 0, 0, "ADMIN_ROLE_CREATE", 0, level, details);
    return role_db_id;
}

stock Admin_DeleteRole(playerid, role_db_id)
{
    if (!Admin_HasPermission(playerid, ADMIN_PERM_MANAGE_ROLES))
    {
        Admin_LogDenied(playerid, "ADMIN_ROLE_DELETE", "Insufficient MANAGE_ROLES rights");
        return 0;
    }
    new const index = Internal_FindRoleIndexByDbId(role_db_id);
    if (index == ADMIN_INVALID_ROLE || sAdminRoles[index][E_AR_IS_ROOT] || sAdminRoles[index][E_AR_IS_SYSTEM])
    {
        return 0;
    }
    if (!Admin_IsRoot(playerid) && sAdminRoles[index][E_AR_LEVEL] >= Admin_GetRoleLevel(playerid))
    {
        Admin_LogDenied(playerid, "ADMIN_ROLE_DELETE", "You cannot delete a role at your level or higher");
        return 0;
    }

    new roleName[MAX_ADMIN_ROLE_NAME];
    format(roleName, sizeof(roleName), "%s", sAdminRoles[index][E_AR_NAME]);
    sAdminRoles[index][E_AR_VALID] = false;
    for (new p = 0; p < MAX_ADMIN_PERMISSIONS; p++)
    {
        sAdminRolePerms[index][p] = false;
    }

    if (DB_IsConnected())
    {
        mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
            "UPDATE `accounts` SET `admin_role_id` = NULL WHERE `admin_role_id` = %d;", role_db_id);
        mysql_tquery(gMySQL, sAdminSqlBuffer);
        mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
            "DELETE FROM `admin_roles` WHERE `id` = %d AND `is_root` = 0 AND `is_system` = 0;", role_db_id);
        mysql_tquery(gMySQL, sAdminSqlBuffer);
    }

    foreach (new target : Player)
    {
        if (sPlayerAdminRole[target] == index)
        {
            sPlayerAdminRole[target] = ADMIN_INVALID_ROLE;
        }
    }

    new details[160];
    format(details, sizeof(details), "Administrator role ì%sî (id %d) was deleted", roleName, role_db_id);
    Admin_Audit(playerid, 0, 0, "ADMIN_ROLE_DELETE", 0, role_db_id, details);
    return 1;
}

stock Admin_SetRolePermission(playerid, role_db_id, E_ADMIN_PERM:perm, bool:allowed)
{
    if (!Admin_HasPermission(playerid, ADMIN_PERM_MANAGE_ROLES))
    {
        Admin_LogDenied(playerid, "ADMIN_ROLE_PERM", "Insufficient MANAGE_ROLES rights");
        return 0;
    }
    new const index = Internal_FindRoleIndexByDbId(role_db_id);
    if (index == ADMIN_INVALID_ROLE || _:perm <= 0 || _:perm >= _:ADMIN_PERM_COUNT)
    {
        return 0;
    }
    if (sAdminRoles[index][E_AR_IS_ROOT])
    {
        return 0;
    }
    if (!Admin_IsRoot(playerid))
    {
        if (sAdminRoles[index][E_AR_LEVEL] >= Admin_GetRoleLevel(playerid))
        {
            Admin_LogDenied(playerid, "ADMIN_ROLE_PERM", "You cannot change the permissions of a role of your level or higher.");
            return 0;
        }
        if (allowed && !Admin_HasPermission(playerid, perm))
        {
            Admin_LogDenied(playerid, "ADMIN_ROLE_PERM", "You cannot give away a right that you do not have yourself.");
            return 0;
        }
    }

    sAdminRolePerms[index][_:perm] = allowed ? 1 : 0;

    if (DB_IsConnected())
    {
        new key[ADMIN_PERMISSION_KEY_LEN];
        Admin_GetPermissionKey(perm, key, sizeof(key));
        mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
            "INSERT INTO `admin_role_permissions` (`role_id`, `permission_key`, `is_allowed`) VALUES (%d, '%e', %d) ON DUPLICATE KEY UPDATE `is_allowed` = VALUES(`is_allowed`);",
            role_db_id, key, allowed ? 1 : 0);
        mysql_tquery(gMySQL, sAdminSqlBuffer);
    }

    new details[160];
    new const permIndex = _:perm;
    format(details, sizeof(details), "Role %d: right %s = %s", role_db_id,
        sAdminPermMeta[permIndex][E_APM_KEY], allowed ? ("allowed") : ("prohibited"));
    Admin_Audit(playerid, 0, 0, "ADMIN_ROLE_PERM", 0, _:perm, details);
    return 1;
}

stock Admin_AssignRole(playerid, target_account_id, role_db_id)
{
    if (!Admin_HasPermission(playerid, ADMIN_PERM_MANAGE_ADMINS))
    {
        Admin_LogDenied(playerid, "ADMIN_ROLE_ASSIGN", "Insufficient MANAGE_ADMINS rights");
        return 0;
    }
    if (target_account_id <= 0)
    {
        return 0;
    }

    if (role_db_id <= 0)
    {
        new const target_playerid = Internal_FindPlayerByAccountId(target_account_id);
        if (target_playerid != INVALID_PLAYER_ID && Admin_IsRoot(target_playerid))
        {
            Admin_LogDenied(playerid, "ADMIN_ROLE_ASSIGN", "The root role cannot be removed through the admin panel");
            return 0;
        }
    }

    if (role_db_id > 0)
    {
        new const index = Internal_FindRoleIndexByDbId(role_db_id);
        if (index == ADMIN_INVALID_ROLE)
        {
            return 0;
        }
        if (sAdminRoles[index][E_AR_IS_ROOT] && !Admin_IsRoot(playerid))
        {
            Admin_LogDenied(playerid, "ADMIN_ROLE_ASSIGN", "Only Root can assign the Root role");
            return 0;
        }
        if (!Admin_IsRoot(playerid) && sAdminRoles[index][E_AR_LEVEL] > Admin_GetRoleLevel(playerid))
        {
            Admin_LogDenied(playerid, "ADMIN_ROLE_ASSIGN", "You cannot assign a role higher than your level");
            return 0;
        }
    }

    if (DB_IsConnected())
    {
        if (role_db_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "UPDATE `accounts` SET `admin_role_id` = %d WHERE `id` = %d;",
                role_db_id, target_account_id);
        }
        else
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "UPDATE `accounts` SET `admin_role_id` = NULL WHERE `id` = %d;",
                target_account_id);
        }
        mysql_tquery(gMySQL, sAdminSqlBuffer);
    }

    Internal_ApplyRoleToOnline(target_account_id, (role_db_id > 0) ? role_db_id : 0);

    new details[160];
    format(details, sizeof(details), "Account %d: assigned admin role %d", target_account_id, role_db_id);
    Admin_Audit(playerid, target_account_id, 0, "ADMIN_ROLE_ASSIGN", 0, role_db_id, details);
    return 1;
}

stock Admin_RemoveRole(playerid, target_account_id)
{
    return Admin_AssignRole(playerid, target_account_id, 0);
}

stock bool:Admin_BanOffline(playerid, const field[], const value[], minutes, const reason[])
{
    if (strlen(value) < 2)
    {
        return false;
    }
    new column[16];
    if (!strcmp(field, "nick", true)) format(column, sizeof(column), "username");
    else if (!strcmp(field, "ip", true)) format(column, sizeof(column), "last_ip");
    else if (!strcmp(field, "hwid", true)) format(column, sizeof(column), "last_hwid");
    else return false;

    new admin_account_id = Account_IsLogged(playerid) ? Account_GetId(playerid) : 0;
    if (minutes > 0)
    {
        mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
            "UPDATE `accounts` SET `is_banned` = 1, `ban_reason` = '%e', `ban_expires_at` = DATE_ADD(NOW(), INTERVAL %d MINUTE) WHERE `%e` = '%e';",
            reason, minutes, column, value);
        mysql_tquery(gMySQL, sAdminSqlBuffer);

        if (admin_account_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `admin_account_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) SELECT `id`, %d, 'BAN_TEMP', '%e', DATE_ADD(NOW(), INTERVAL %d MINUTE), 1 FROM `accounts` WHERE `%e` = '%e';",
                admin_account_id, reason, minutes, column, value);
        }
        else
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) SELECT `id`, 'BAN_TEMP', '%e', DATE_ADD(NOW(), INTERVAL %d MINUTE), 1 FROM `accounts` WHERE `%e` = '%e';",
                reason, minutes, column, value);
        }
        mysql_tquery(gMySQL, sAdminSqlBuffer);
    }
    else
    {
        mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
            "UPDATE `accounts` SET `is_banned` = 1, `ban_reason` = '%e', `ban_expires_at` = NULL WHERE `%e` = '%e';",
            reason, column, value);
        mysql_tquery(gMySQL, sAdminSqlBuffer);

        if (admin_account_id > 0)
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `admin_account_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) SELECT `id`, %d, 'BAN_PERM', '%e', NULL, 1 FROM `accounts` WHERE `%e` = '%e';",
                admin_account_id, reason, column, value);
        }
        else
        {
            mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
                "INSERT INTO `admin_punishments` (`target_account_id`, `punishment_type`, `reason`, `expires_at`, `is_active`) SELECT `id`, 'BAN_PERM', '%e', NULL, 1 FROM `accounts` WHERE `%e` = '%e';",
                reason, column, value);
        }
        mysql_tquery(gMySQL, sAdminSqlBuffer);
    }

    new details[192];
    format(details, sizeof(details), "Offline ban by %s ì%sî on %d min.: %s", field, value, minutes, reason);
    Admin_Audit(playerid, 0, 0, "ADMIN_BAN_OFFLINE", 0, minutes, details);
    return true;
}

stock bool:Admin_UnbanByUsername(playerid, const username[])
{
    if (strlen(username) < 2)
    {
        return false;
    }
    new admin_account_id = Account_IsLogged(playerid) ? Account_GetId(playerid) : 0;

    mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
        "UPDATE `accounts` SET `is_banned` = 0, `ban_reason` = NULL, `ban_expires_at` = NULL WHERE `username` = '%e';",
        username);
    mysql_tquery(gMySQL, sAdminSqlBuffer);

    if (admin_account_id > 0)
    {
        mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
            "UPDATE `admin_punishments` AS p JOIN `accounts` AS a ON a.`id` = p.`target_account_id` SET p.`is_active` = 0, p.`revoked_by_account_id` = %d, p.`revoked_at` = NOW() WHERE a.`username` = '%e' AND p.`is_active` = 1 AND p.`punishment_type` IN ('BAN_TEMP', 'BAN_PERM');",
            admin_account_id, username);
    }
    else
    {
        mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
            "UPDATE `admin_punishments` AS p JOIN `accounts` AS a ON a.`id` = p.`target_account_id` SET p.`is_active` = 0, p.`revoked_at` = NOW() WHERE a.`username` = '%e' AND p.`is_active` = 1 AND p.`punishment_type` IN ('BAN_TEMP', 'BAN_PERM');",
            username);
    }
    mysql_tquery(gMySQL, sAdminSqlBuffer);

    new details[128];
    format(details, sizeof(details), "Unban account \"%s\"", username);
    Admin_Audit(playerid, 0, 0, "ADMIN_UNBAN_OFFLINE", 0, 0, details);
    return true;
}

// =============================================================================
//  7. «¿√–”« ¿ –ŒÀ» » Õ¿ ¿«¿Õ»… œ–» ¬’Œƒ≈
// =============================================================================

stock Admin_LoadPlayerRole(playerid)
{
    sPlayerAdminRole[playerid] = ADMIN_INVALID_ROLE;
    sPlayerAdminLoaded[playerid] = false;
    sPlayerMuteUntil[playerid] = 0;
    sPlayerWarnCount[playerid] = 0;

    new const account_id = Account_GetId(playerid);
    if (account_id <= 0 || !DB_IsConnected())
    {
        sPlayerAdminLoaded[playerid] = true;
        return 0;
    }

    mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
        "SELECT IFNULL(`admin_role_id`, 0) AS `role_id` FROM `accounts` WHERE `id` = %d LIMIT 1;",
        account_id);
    mysql_tquery(gMySQL, sAdminSqlBuffer, "OnAdminRoleLookup", "dd",
        playerid, Config_GetPlayerSessionToken(playerid));
    return 1;
}

forward OnAdminRoleLookup(playerid, sessionToken);
public OnAdminRoleLookup(playerid, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 0;
    }

    new rows = 0;
    cache_get_row_count(rows);
    if (rows <= 0)
    {
        sPlayerAdminLoaded[playerid] = true;
        Admin_LoadPunishments(playerid);
        return 1;
    }

    new role_db_id = 0;
    cache_get_value_name_int(0, "role_id", role_db_id);
    sPlayerAdminRole[playerid] = Internal_FindRoleIndexByDbId(role_db_id);
    sPlayerAdminLoaded[playerid] = true;

    Admin_LoadPunishments(playerid);
    return 1;
}

stock Admin_LoadPunishments(playerid)
{
    new const account_id = Account_GetId(playerid);
    if (account_id <= 0 || !DB_IsConnected())
    {
        return 0;
    }
    mysql_format(gMySQL, sAdminSqlBuffer, sizeof(sAdminSqlBuffer),
        "SELECT `punishment_type`, IFNULL(UNIX_TIMESTAMP(`expires_at`), 0) AS `expires_unix` FROM `admin_punishments` WHERE `target_account_id` = %d AND `is_active` = 1 AND (`expires_at` IS NULL OR `expires_at` > NOW());",
        account_id);
    mysql_tquery(gMySQL, sAdminSqlBuffer, "OnAdminPunishmentsLoaded", "dd",
        playerid, Config_GetPlayerSessionToken(playerid));
    return 1;
}

forward OnAdminPunishmentsLoaded(playerid, sessionToken);
public OnAdminPunishmentsLoaded(playerid, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 0;
    }

    new rows = 0;
    cache_get_row_count(rows);
    sPlayerMuteUntil[playerid] = 0;
    sPlayerWarnCount[playerid] = 0;

    for (new row = 0; row < rows; row++)
    {
        new typeStr[16], expiresUnix = 0;
        cache_get_value_name(row, "punishment_type", typeStr, sizeof(typeStr));
        cache_get_value_name_int(row, "expires_unix", expiresUnix);

        if (!strcmp(typeStr, "MUTE", true))
        {
            sPlayerMuteUntil[playerid] = (expiresUnix > 0) ? expiresUnix : (gettime() + 86400);
        }
        else if (!strcmp(typeStr, "WARN", true))
        {
            sPlayerWarnCount[playerid]++;
        }
    }
    return 1;
}

// =============================================================================
//  8. ’” »
// =============================================================================

hook OnGameModeInit()
{
    Admin_ResetRuntime();
    Admin_LoadRoles();
    return 1;
}

hook OnPlayerConnect(playerid)
{
    sPlayerAdminRole[playerid] = ADMIN_INVALID_ROLE;
    sPlayerAdminLoaded[playerid] = false;
    sPlayerMuteUntil[playerid] = 0;
    sPlayerWarnCount[playerid] = 0;
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    sPlayerAdminRole[playerid] = ADMIN_INVALID_ROLE;
    sPlayerAdminLoaded[playerid] = false;
    sPlayerMuteUntil[playerid] = 0;
    sPlayerWarnCount[playerid] = 0;
    return 1;
}

hook OnAccountAuthenticated(playerid, bool:isNewRegistration)
{
    #pragma unused isNewRegistration
    Admin_LoadPlayerRole(playerid);
    return 1;
}

hook OnPlayerSpawn(playerid)
{
    if (!sPlayerAdminLoaded[playerid] && Account_IsLogged(playerid))
    {
        Admin_LoadPlayerRole(playerid);
    }
    return 1;
}

hook OnPlayerText(playerid, text[])
{
    #pragma unused text
    if (Admin_IsMuted(playerid))
    {
        new msg[192];
        format(msg, sizeof(msg),
            "You are deprived of the right to write to the chat for another %d seconds. The reason for the mute was specified by the administrator.",
            Admin_GetMuteSecondsLeft(playerid));
        SendClientMessage(playerid, COLOR_UI_ERROR, msg);
        return Y_HOOKS_BREAK_RETURN_0;
    }
    return 1;
}

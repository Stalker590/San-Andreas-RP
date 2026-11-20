/*
 * =============================================================================
 *  SAN ANDREAS RP ó ÃÌÓ„ÓÙÛÌÍˆËÓÌ‡Î¸Ì‡ˇ ‡‰ÏËÌ-Ô‡ÌÂÎ¸, /ahelp Ë HUD ÒÎÂÊÍË
 *  ‘‡ÈÎ:      gamemodes/modules/ui/mod_admin_panel.pwn
 *  œÛÌÍÚ˚:    ROADMAP [10.2], [10.3], [10.4]
 *   Ó‰ËÓ‚Í‡: Windows-1251 (CP1251) ·ÂÁ BOM
 * =============================================================================
 */

#if defined _mod_admin_panel_included
    #endinput
#endif
#define _mod_admin_panel_included

#include <YSI_Coding\y_hooks>

forward bool:AC_AreIntegrationTestsPassed();
forward AdminReports_GetActiveCount();
forward AdminReports_OpenQueueDialog(playerid);
timer Admin_DelayedRestart[250]()
{
    SendRconCommand("gmx");
}

// =============================================================================
//  1. ƒ»¿ÀŒ√», À»Ã»“€  ŒÃ¿Õƒ » œ≈–≈◊»—À≈Õ»ﬂ ƒ≈…—“¬»…
// =============================================================================

#define DIALOG_ADMIN_MAIN                       (2000)
#define DIALOG_ADMIN_TARGETS                    (2001)
#define DIALOG_ADMIN_PLAYER_ACTIONS             (2002)
#define DIALOG_ADMIN_INPUT                      (2003)
#define DIALOG_ADMIN_ITEM_INPUT                 (2004)
#define DIALOG_ADMIN_CONFIRM                    (2005)
#define DIALOG_ADMIN_ORGS                       (2006)
#define DIALOG_ADMIN_ORG_RANKS                  (2007)
#define DIALOG_ADMIN_VEHICLES                   (2008)
#define DIALOG_ADMIN_WORLD                      (2009)
#define DIALOG_ADMIN_ROLES                      (2010)
#define DIALOG_ADMIN_ROLE_ACTIONS               (2011)
#define DIALOG_ADMIN_ROLE_PERMS                 (2012)
#define DIALOG_ADMIN_ROLE_INPUT                 (2013)
#define DIALOG_ADMIN_ROLE_OFFLINE               (2014)
#define DIALOG_ADMIN_AUDIT                      (2015)
#define DIALOG_ADMIN_ANTICHEAT                  (2016)
#define DIALOG_ADMIN_PROPERTIES                 (2017)
#define DIALOG_ADMIN_HELP                       (2018)
#define DIALOG_ADMIN_SKILLS                     (2019)
#define DIALOG_ADMIN_ECONOMY                    (2020)
#define DIALOG_ADMIN_INVENTORY                  (2021)

#define MAX_ADMIN_MENU_ROWS                     (80)
#define MAX_ADMIN_TARGET_ROWS                   (128)
#define MAX_ADMIN_PROPERTY_ROWS                 (64)
#define MAX_ADMIN_DIALOG_BUFFER                 (8192)
#define ADMIN_COMMAND_COOLDOWN_MS               (300)

enum E_ADMIN_MAIN_ACTION
{
    AM_MAIN_NONE = 0,
    AM_MAIN_PLAYERS,
    AM_MAIN_ORGS,
    AM_MAIN_ECONOMY,
    AM_MAIN_INVENTORY,
    AM_MAIN_VEHICLES,
    AM_MAIN_WORLD,
    AM_MAIN_ROLES,
    AM_MAIN_AUDIT,
    AM_MAIN_ANTICHEAT,
    AM_MAIN_SPECTATE,
    AM_MAIN_REPORTS
};

enum E_ADMIN_PLAYER_ACTION
{
    AP_ACTION_NONE = 0,
    AP_TELEPORT,
    AP_GET_HERE,
    AP_SPECTATE,
    AP_FREEZE,
    AP_SLAP,
    AP_SET_HP,
    AP_SET_ARMOUR,
    AP_SET_HUNGER,
    AP_SET_THIRST,
    AP_SET_STAMINA,
    AP_SET_STRESS,
    AP_SET_SKIN,
    AP_KICK,
    AP_QUIET_KICK,
    AP_BAN_TEMP,
    AP_BAN_PERM,
    AP_MUTE,
    AP_WARN,
    AP_JAIL,
    AP_SET_WANTED,
    AP_SET_LEVEL,
    AP_SET_EXP,
    AP_SKILLS,
    AP_LICENSES,
    AP_CASH,
    AP_BANK,
    AP_DEBT,
    AP_INVENTORY,
    AP_CLEAR_INV,
    AP_GIVE_ITEM,
    AP_VEH_SPAWN,
    AP_VEH_KEYS,
    AP_ORG,
    AP_PROPERTY
};

enum E_ADMIN_ECON_ACTION
{
    AE_ACTION_NONE = 0,
    AE_CASH,
    AE_BANK,
    AE_DEBT,
    AE_CLEAR_DEBT
};

enum E_ADMIN_INV_ACTION
{
    AI_ACTION_NONE = 0,
    AI_VIEW,
    AI_GIVE,
    AI_CLEAR
};

enum E_ADMIN_VEH_ACTION
{
    AV_ACTION_NONE = 0,
    AV_SPAWN_SELF,
    AV_SPAWN_TARGET,
    AV_KEYS_TARGET,
    AV_REPAIR,
    AV_REFUEL,
    AV_FLIP,
    AV_DESPAWN,
    AV_RESPAWN,
    AV_TELEPORT
};

enum E_ADMIN_WORLD_ACTION
{
    AW_ACTION_NONE = 0,
    AW_TELEPORT,
    AW_WEATHER,
    AW_TIME,
    AW_ANNOUNCE,
    AW_SAVE,
    AW_AUDIT,
    AW_ANTICHEAT,
    AW_RESTART
};

enum E_ADMIN_ROLE_ACTION
{
    AR_ACTION_NONE = 0,
    AR_PERMISSIONS,
    AR_DELETE,
    AR_ASSIGN_ONLINE,
    AR_ASSIGN_OFFLINE,
    AR_REMOVE
};

enum E_ADMIN_TARGET_MODE
{
    ATM_NONE = 0,
    ATM_PLAYER_ACTIONS,
    ATM_ECONOMY,
    ATM_INVENTORY,
    ATM_ORG_TARGET,
    ATM_VEH_SPAWN,
    ATM_VEH_KEYS,
    ATM_SPECTATE,
    ATM_TELEPORT,
    ATM_GET_HERE,
    ATM_ROLE_ASSIGN,
    ATM_ROLE_REMOVE,
    ATM_PROPERTY
};

enum E_ADMIN_INPUT_ACTION
{
    AI_INPUT_NONE = 0,
    AI_INPUT_HP,
    AI_INPUT_ARMOUR,
    AI_INPUT_HUNGER,
    AI_INPUT_THIRST,
    AI_INPUT_STAMINA,
    AI_INPUT_STRESS,
    AI_INPUT_SKIN,
    AI_INPUT_BAN_TEMP,
    AI_INPUT_BAN_PERM,
    AI_INPUT_MUTE,
    AI_INPUT_WARN,
    AI_INPUT_JAIL,
    AI_INPUT_WANTED,
    AI_INPUT_LEVEL,
    AI_INPUT_EXP,
    AI_INPUT_CASH,
    AI_INPUT_BANK,
    AI_INPUT_DEBT,
    AI_INPUT_VEH_MODEL,
    AI_INPUT_WEATHER,
    AI_INPUT_TIME,
    AI_INPUT_ANNOUNCE,
    AI_INPUT_TP,
    AI_INPUT_ROLE_OFFLINE,
    AI_INPUT_SKILL_VALUE
};

enum E_ADMIN_CONFIRM_ACTION
{
    AC_ACTION_NONE = 0,
    AC_CLEAR_INVENTORY,
    AC_DELETE_ROLE,
    AC_CLEAR_PROPERTY,
    AC_RESTART_SERVER
};

// =============================================================================
//  2. —Œ—“ŒﬂÕ»≈ UI, HUD —À≈∆ » » Ã¿œœ»Õ√» ƒ»¿ÀŒ√Œ¬
// =============================================================================

static stock sAdminMenuAction[MAX_PLAYERS][MAX_ADMIN_MENU_ROWS];
static stock sAdminMenuCount[MAX_PLAYERS];

static stock sAdminTarget[MAX_PLAYERS];
static stock E_ADMIN_TARGET_MODE:sAdminTargetMode[MAX_PLAYERS];
static stock sAdminTargets[MAX_PLAYERS][MAX_ADMIN_TARGET_ROWS];
static stock sAdminTargetCount[MAX_PLAYERS];

static stock sAdminPendingAction[MAX_PLAYERS];
static stock sAdminPendingTarget[MAX_PLAYERS];
static stock sAdminPendingRole[MAX_PLAYERS];
static stock sAdminPendingOrg[MAX_PLAYERS];
static stock sAdminPendingProperty[MAX_PLAYERS];
static stock sAdminPendingSkill[MAX_PLAYERS];
static stock E_ADMIN_CONFIRM_ACTION:sAdminConfirmAction[MAX_PLAYERS];

static stock sAdminRoleList[MAX_PLAYERS][MAX_ADMIN_ROLES + 1];
static stock sAdminPermList[MAX_PLAYERS][MAX_ADMIN_PERMISSIONS];
static stock sAdminOrgList[MAX_PLAYERS][32];
static stock sAdminRankList[MAX_PLAYERS][MAX_ORG_RANKS];
static stock sAdminPropertyList[MAX_PLAYERS][MAX_ADMIN_PROPERTY_ROWS];

static stock bool:sAdminSpectating[MAX_PLAYERS];
static stock sAdminSpectateTarget[MAX_PLAYERS];
static stock Float:sAdminSavedX[MAX_PLAYERS];
static stock Float:sAdminSavedY[MAX_PLAYERS];
static stock Float:sAdminSavedZ[MAX_PLAYERS];
static stock sAdminSavedInterior[MAX_PLAYERS];
static stock sAdminSavedVW[MAX_PLAYERS];
static stock bool:sAdminFrozen[MAX_PLAYERS];

static stock PlayerText:sAdminHudBox[MAX_PLAYERS];
static stock PlayerText:sAdminHudInfo[MAX_PLAYERS];
static stock PlayerText:sAdminHudFreeze[MAX_PLAYERS];
static stock PlayerText:sAdminHudSlap[MAX_PLAYERS];
static stock PlayerText:sAdminHudKick[MAX_PLAYERS];
static stock PlayerText:sAdminHudClose[MAX_PLAYERS];

static stock sAdminLastCommandTick[MAX_PLAYERS];

// =============================================================================
//  3. œ¿–—≈–€, ”“»À»“€ » œ–Œ¬≈– ¿ œ–¿¬
// =============================================================================

static stock bool:Internal_NextToken(const src[], &pos, out[], len)
{
    out[0] = EOS;
    new i = pos;
    while (src[i] == ' ' || src[i] == '\t') i++;
    if (src[i] == EOS)
    {
        pos = i;
        return false;
    }

    new j = 0;
    while (src[i] != EOS && src[i] != ' ' && src[i] != '\t')
    {
        if (j < (len - 1))
        {
            out[j++] = src[i];
        }
        i++;
    }
    out[j] = EOS;
    pos = i;
    return true;
}

static stock Internal_GetRest(const src[], pos, out[], len)
{
    out[0] = EOS;
    new i = pos;
    while (src[i] == ' ' || src[i] == '\t') i++;
    if (src[i] == EOS)
    {
        return 0;
    }
    strmid(out, src, i, strlen(src), len);
    return 1;
}

static stock bool:Internal_CommandCooldown(playerid)
{
    new const now = GetTickCount();
    if (sAdminLastCommandTick[playerid] != 0 &&
        (now - sAdminLastCommandTick[playerid]) < ADMIN_COMMAND_COOLDOWN_MS)
    {
        return false;
    }
    sAdminLastCommandTick[playerid] = now;
    return true;
}

static stock bool:AdminPanel_Require(playerid, E_ADMIN_PERM:perm, const action[])
{
    if (Admin_HasPermission(playerid, perm))
    {
        return true;
    }
    SendClientMessage(playerid, COLOR_UI_ERROR, "Insufficient rights for this action.");
    Admin_LogDenied(playerid, action, "RBAC failure: insufficient rights");
    return false;
}

static stock bool:AdminPanel_HasRange(playerid, first, last)
{
    for (new p = first; p <= last; p++)
    {
        if (Admin_HasPermission(playerid, E_ADMIN_PERM:p))
        {
            return true;
        }
    }
    return false;
}

static stock AdminPanel_ResetMenu(playerid)
{
    sAdminMenuCount[playerid] = 0;
    for (new i = 0; i < MAX_ADMIN_MENU_ROWS; i++)
    {
        sAdminMenuAction[playerid][i] = 0;
    }
}

static stock AdminPanel_AddAction(playerid, body[], size, action, const label[])
{
    if (sAdminMenuCount[playerid] >= MAX_ADMIN_MENU_ROWS)
    {
        return 0;
    }
    sAdminMenuAction[playerid][sAdminMenuCount[playerid]] = action;
    sAdminMenuCount[playerid]++;

    new line[192];
    format(line, sizeof(line), "%d. %s\n", sAdminMenuCount[playerid], label);
    strcat(body, line, size);
    return 1;
}

static stock bool:AdminPanel_ValidTarget(playerid, target)
{
    if (target < 0 || target >= MAX_PLAYERS || target == INVALID_PLAYER_ID)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The player was not found or has already left the game.");
        return false;
    }
    if (!IsPlayerConnected(target) || !Character_IsLoaded(target))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The player has not yet loaded a character.");
        return false;
    }
    return true;
}

static stock AdminPanel_GetTargetName(target, output[], len = sizeof(output))
{
    output[0] = EOS;
    if (target < 0 || target >= MAX_PLAYERS) return 0;
    if (Character_IsLoaded(target))
    {
        return Character_GetRpName(target, output, len);
    }
    GetPlayerName(target, output, len);
    return 1;
}

static stock AdminPanel_SendAudit(playerid, target, const action[], item_def_id, amount, const details[])
{
    new target_account_id = (target >= 0 && target < MAX_PLAYERS) ? Account_GetId(target) : 0;
    new target_char_id = (target >= 0 && target < MAX_PLAYERS) ? Character_GetId(target) : 0;
    return Admin_Audit(playerid, target_account_id, target_char_id, action, item_def_id, amount, details);
}

// =============================================================================
//  4. √À¿¬ÕŒ≈ Ã≈Õﬁ » Õ¿¬»√¿÷»ﬂ
// =============================================================================

static stock AdminPanel_ShowMain(playerid)
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PANEL_ACCESS, "APANEL_OPEN"))
    {
        return 0;
    }

    AdminPanel_ResetMenu(playerid);
    new body[MAX_ADMIN_DIALOG_BUFFER];
    strcat(body, "#\tSection\tDescription\n", sizeof(body));

    if (AdminPanel_HasRange(playerid, _:ADMIN_PERM_PLAYER_TELEPORT, _:ADMIN_PERM_PLAYER_SET_WANTED) ||
        Admin_HasPermission(playerid, ADMIN_PERM_PROP_GIVE) ||
        Admin_HasPermission(playerid, ADMIN_PERM_PROP_REMOVE))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AM_MAIN_PLAYERS, "Players\tOnline player management");
    }
    if (AdminPanel_HasRange(playerid, _:ADMIN_PERM_ORG_SET_LEADER, _:ADMIN_PERM_ORG_MANAGE_RANKS))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AM_MAIN_ORGS, "Factions\tFactions and ranks");
    }
    if (AdminPanel_HasRange(playerid, _:ADMIN_PERM_ECON_GIVE_CASH, _:ADMIN_PERM_ECON_ISSUE_DEBT))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AM_MAIN_ECONOMY, "Economy\tCash, bank and debt");
    }
    if (AdminPanel_HasRange(playerid, _:ADMIN_PERM_INV_VIEW, _:ADMIN_PERM_INV_CLEAR))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AM_MAIN_INVENTORY, "Inventory\tItems and storage");
    }
    if (AdminPanel_HasRange(playerid, _:ADMIN_PERM_VEH_SPAWN, _:ADMIN_PERM_VEH_TELEPORT))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AM_MAIN_VEHICLES, "Vehicle\tSpawn, keys and repairs");
    }
    if (AdminPanel_HasRange(playerid, _:ADMIN_PERM_WORLD_TELEPORT, _:ADMIN_PERM_SERVER_RESTART))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AM_MAIN_WORLD, "World and server\tWeather, time, announcements and database");
    }
    if (AdminPanel_HasRange(playerid, _:ADMIN_PERM_MANAGE_ADMINS, _:ADMIN_PERM_MANAGE_ROLES))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AM_MAIN_ROLES, "Admin Roles\tRBAC ranks and administrators");
    }
    if (Admin_HasPermission(playerid, ADMIN_PERM_VIEW_AUDIT))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AM_MAIN_AUDIT, "Audit\tLatest administrative actions");
    }
    if (Admin_HasPermission(playerid, ADMIN_PERM_VIEW_ANTICHEAT))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AM_MAIN_ANTICHEAT, "Anti-cheat\tViolation statistics");
    }
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_SPECTATE))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AM_MAIN_SPECTATE, "Spectate\tHUD-panel /sp");
    }
    if (Admin_HasPermission(playerid, ADMIN_PERM_PANEL_ACCESS) || Admin_IsRoot(playerid))
    {
        new repRow[128];
        format(repRow, sizeof(repRow), "Player Reports (%d)\tIncoming /report tickets & /ans", AdminReports_GetActiveCount());
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AM_MAIN_REPORTS, repRow);
    }

    if (sAdminMenuCount[playerid] == 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Your role does not have any admin panel sections available.");
        return 0;
    }

    new title[128];
    new roleName[64];
    Admin_GetRoleName(playerid, roleName, sizeof(roleName));
    format(title, sizeof(title), "Admin panel - %s (level %d)", roleName, Admin_GetRoleLevel(playerid));
    ShowPlayerDialog(playerid, DIALOG_ADMIN_MAIN, DIALOG_STYLE_TABLIST_HEADERS, title, body, "Select", "Close");
    return 1;
}

static stock AdminPanel_ShowTargets(playerid, E_ADMIN_TARGET_MODE:mode, const title[])
{
    sAdminTargetMode[playerid] = mode;
    sAdminTargetCount[playerid] = 0;

    new body[MAX_ADMIN_DIALOG_BUFFER];
    strcat(body, "#\tPlayer\tID\tLevel\n", sizeof(body));

    foreach (new target : Player)
    {
        if (sAdminTargetCount[playerid] >= MAX_ADMIN_TARGET_ROWS)
        {
            break;
        }
        if (!IsPlayerConnected(target) || !Character_IsLoaded(target))
        {
            continue;
        }
        new name[MAX_PLAYER_NAME + 1];
        AdminPanel_GetTargetName(target, name, sizeof(name));
        sAdminTargets[playerid][sAdminTargetCount[playerid]] = target;
        sAdminTargetCount[playerid]++;

        new line[160];
        format(line, sizeof(line), "%d\t%s\t%d\t%d\n",
            sAdminTargetCount[playerid], name, target, Character_GetLevel(target));
        strcat(body, line, sizeof(body));
    }

    if (sAdminTargetCount[playerid] == 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "There are no players on the server with a loaded character.");
        return 0;
    }

    ShowPlayerDialog(playerid, DIALOG_ADMIN_TARGETS, DIALOG_STYLE_TABLIST_HEADERS, title, body, "Select", "Back");
    return 1;
}

static stock AdminPanel_ShowPlayerActions(playerid)
{
    new const target = sAdminTarget[playerid];
    if (!AdminPanel_ValidTarget(playerid, target))
    {
        return 0;
    }

    AdminPanel_ResetMenu(playerid);
    new body[MAX_ADMIN_DIALOG_BUFFER];
    strcat(body, "#\tAction\n", sizeof(body));

    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_TELEPORT))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_TELEPORT, "Teleport to player (/goto)");
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_GET_HERE))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_GET_HERE, "Teleport player to yourself (/gethere)");
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_SPECTATE))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SPECTATE, "Player tracking (/sp)");
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_FREEZE))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_FREEZE, "Freeze / defrost");
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_SLAP))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SLAP, "Slap (knock down)");
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_SET_STATS))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SET_HP, "Set HP");
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SET_ARMOUR, "Set armor");
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SET_HUNGER, "Set hunger");
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SET_THIRST, "Set thirst");
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SET_STAMINA, "Set Stamina");
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SET_STRESS, "Set stress");
    }
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_SET_SKIN))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SET_SKIN, "Change skin");
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_KICK))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_KICK, "Kick with a reason");
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_QUIET_KICK, "Quiet kick");
    }
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_BAN))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_BAN_TEMP, "Temporary ban");
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_BAN_PERM, "Permanent ban");
    }
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_MUTE))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_MUTE, "Mute");
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_WARN))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_WARN, "Warning (warn)");
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_JAIL))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_JAIL, "Admin jail (demorgan)");
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_SET_WANTED))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SET_WANTED, "Set wanted level");
    if (Admin_HasPermission(playerid, ADMIN_PERM_CHAR_SET_LEVEL))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SET_LEVEL, "Set character level");
    if (Admin_HasPermission(playerid, ADMIN_PERM_CHAR_SET_EXP))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SET_EXP, "Set Experience (EXP)");
    if (Admin_HasPermission(playerid, ADMIN_PERM_CHAR_SET_SKILLS))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_SKILLS, "Skills editor (/skills)");
    if (Admin_HasPermission(playerid, ADMIN_PERM_CHAR_SET_LICENSES))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_LICENSES, "Issue/withdraw a weapons license");
    if (Admin_HasPermission(playerid, ADMIN_PERM_ECON_GIVE_CASH))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_CASH, "Issue/withdraw cash");
    if (Admin_HasPermission(playerid, ADMIN_PERM_ECON_SET_BANK))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_BANK, "Set bank balance");
    if (Admin_HasPermission(playerid, ADMIN_PERM_ECON_ISSUE_DEBT))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_DEBT, "Set bank debt");
    if (Admin_HasPermission(playerid, ADMIN_PERM_INV_VIEW))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_INVENTORY, "Open player inventory");
    if (Admin_HasPermission(playerid, ADMIN_PERM_INV_CLEAR))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_CLEAR_INV, "Clear inventory");
    if (Admin_HasPermission(playerid, ADMIN_PERM_INV_GIVE_ITEM))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_GIVE_ITEM, "Give out item");
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_SPAWN))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_VEH_SPAWN, "Spawn a vehicle for a player");
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_KEYS))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_VEH_KEYS, "Give out keys to the nearest car");
    if (Admin_HasPermission(playerid, ADMIN_PERM_ORG_SET_LEADER) || Admin_HasPermission(playerid, ADMIN_PERM_ORG_SET_MEMBER))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_ORG, "Assign to organization");
    if (Admin_HasPermission(playerid, ADMIN_PERM_PROP_GIVE))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AP_PROPERTY, "Give out property");

    if (sAdminMenuCount[playerid] == 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Your role has no available actions for this player.");
        return 0;
    }

    new name[MAX_PLAYER_NAME + 1], title[128];
    AdminPanel_GetTargetName(target, name, sizeof(name));
    format(title, sizeof(title), "Player %s (ID %d)", name, target);
    ShowPlayerDialog(playerid, DIALOG_ADMIN_PLAYER_ACTIONS, DIALOG_STYLE_TABLIST_HEADERS, title, body, "Select", "Back");
    return 1;
}

static stock AdminPanel_ShowEconomyActions(playerid)
{
    new const target = sAdminTarget[playerid];
    if (!AdminPanel_ValidTarget(playerid, target)) return 0;

    AdminPanel_ResetMenu(playerid);
    new body[2048];
    strcat(body, "#\tAction\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_ECON_GIVE_CASH))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AE_CASH, "Issue/withdraw cash");
    if (Admin_HasPermission(playerid, ADMIN_PERM_ECON_SET_BANK))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AE_BANK, "Set bank balance");
    if (Admin_HasPermission(playerid, ADMIN_PERM_ECON_ISSUE_DEBT) || Admin_HasPermission(playerid, ADMIN_PERM_ECON_CLEAR_DEBT))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AE_DEBT, "Set bank debt");
    if (Admin_HasPermission(playerid, ADMIN_PERM_ECON_CLEAR_DEBT))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AE_CLEAR_DEBT, "Pay off bank debt");

    ShowPlayerDialog(playerid, DIALOG_ADMIN_ECONOMY, DIALOG_STYLE_TABLIST_HEADERS,
        "Player Economy", body, "Select", "Back");
    return 1;
}

static stock AdminPanel_ShowInventoryActions(playerid)
{
    new const target = sAdminTarget[playerid];
    if (!AdminPanel_ValidTarget(playerid, target)) return 0;

    AdminPanel_ResetMenu(playerid);
    new body[1024];
    strcat(body, "#\tAction\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_INV_VIEW))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AI_VIEW, "Open inventory and storage");
    if (Admin_HasPermission(playerid, ADMIN_PERM_INV_GIVE_ITEM))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AI_GIVE, "Give out item");
    if (Admin_HasPermission(playerid, ADMIN_PERM_INV_CLEAR))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AI_CLEAR, "Clear inventory");

    ShowPlayerDialog(playerid, DIALOG_ADMIN_INVENTORY, DIALOG_STYLE_TABLIST_HEADERS,
        "Player Inventory", body, "Select", "Back");
    return 1;
}

static stock AdminPanel_ShowVehicles(playerid)
{
    AdminPanel_ResetMenu(playerid);
    new body[2048];
    strcat(body, "#\tAction\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_SPAWN))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AV_SPAWN_SELF, "Spawn a vehicle for yourself");
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AV_SPAWN_TARGET, "Spawn a vehicle for a player");
    }
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_KEYS))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AV_KEYS_TARGET, "Give the keys to the player");
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_REPAIR))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AV_REPAIR, "Repair nearby vehicle");
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_REFUEL))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AV_REFUEL, "Refuel the nearest vehicle");
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_REPAIR))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AV_FLIP, "Overturn the nearest vehicle");
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_DELETE))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AV_DESPAWN, "Remove nearby vehicle");
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AV_RESPAWN, "Return the vehicle to spawn");
    }
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_TELEPORT))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AV_TELEPORT, "Teleport vehicle to yourself");

    ShowPlayerDialog(playerid, DIALOG_ADMIN_VEHICLES, DIALOG_STYLE_TABLIST_HEADERS,
        "Vehicle management", body, "Select", "Back");
    return 1;
}

static stock AdminPanel_ShowWorld(playerid)
{
    AdminPanel_ResetMenu(playerid);
    new body[2048];
    strcat(body, "#\tAction\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_WORLD_TELEPORT))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AW_TELEPORT, "Teleport by coordinates");
    if (Admin_HasPermission(playerid, ADMIN_PERM_WORLD_WEATHER))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AW_WEATHER, "Change the weather");
    if (Admin_HasPermission(playerid, ADMIN_PERM_WORLD_TIME))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AW_TIME, "Change time of day");
    if (Admin_HasPermission(playerid, ADMIN_PERM_WORLD_ANNOUNCE))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AW_ANNOUNCE, "Global Announcement (/ao)");
    if (Admin_HasPermission(playerid, ADMIN_PERM_SERVER_SAVE))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AW_SAVE, "Emergency database saving");
    if (Admin_HasPermission(playerid, ADMIN_PERM_VIEW_AUDIT))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AW_AUDIT, "Audit log");
    if (Admin_HasPermission(playerid, ADMIN_PERM_VIEW_ANTICHEAT))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AW_ANTICHEAT, "Anti-cheat statistics");
    if (Admin_HasPermission(playerid, ADMIN_PERM_SERVER_RESTART))
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AW_RESTART, "Restart server");

    ShowPlayerDialog(playerid, DIALOG_ADMIN_WORLD, DIALOG_STYLE_TABLIST_HEADERS,
        "World and server", body, "Select", "Back");
    return 1;
}

static stock AdminPanel_ShowRoles(playerid)
{
    if (!Admin_HasPermission(playerid, ADMIN_PERM_MANAGE_ROLES) &&
        !Admin_HasPermission(playerid, ADMIN_PERM_MANAGE_ADMINS))
    {
        AdminPanel_Require(playerid, ADMIN_PERM_MANAGE_ROLES, "ADMIN_ROLES_OPEN");
        return 0;
    }

    new body[MAX_ADMIN_DIALOG_BUFFER];
    strcat(body, "#\tRole\tLevel\tType\n", sizeof(body));
    new rows = 0;
    for (new i = 0; i < Admin_GetRoleCount() && rows < MAX_ADMIN_ROLES; i++)
    {
        new roleDb = Admin_GetRoleDbIdByIndex(i);
        if (roleDb <= 0) continue;

        new name[MAX_ADMIN_ROLE_NAME];
        Admin_GetRoleNameByDbId(roleDb, name, sizeof(name));
        sAdminRoleList[playerid][rows] = roleDb;
        rows++;

        new line[160], type[32];
        if (roleDb == Admin_GetRootRoleDbId()) format(type, sizeof(type), "Root");
        else format(type, sizeof(type), "Custom");
        format(line, sizeof(line), "%d\t%s\t%d\t%s\n", rows, name, Admin_GetRoleLevelByDbId(roleDb), type);
        strcat(body, line, sizeof(body));
    }

    sAdminRoleList[playerid][rows] = 0;
    if (Admin_HasPermission(playerid, ADMIN_PERM_MANAGE_ROLES))
    {
        new line[128];
        format(line, sizeof(line), "%d. Create a new admin role\n", rows + 1);
        strcat(body, line, sizeof(body));
    }

    ShowPlayerDialog(playerid, DIALOG_ADMIN_ROLES, DIALOG_STYLE_TABLIST_HEADERS,
        "Admin Roles and Staff", body, "Select", "Back");
    return 1;
}

static stock AdminPanel_ShowRoleActions(playerid)
{
    new const roleDb = sAdminPendingRole[playerid];
    if (roleDb <= 0) return 0;

    new name[MAX_ADMIN_ROLE_NAME];
    Admin_GetRoleNameByDbId(roleDb, name, sizeof(name));

    AdminPanel_ResetMenu(playerid);
    new body[2048];
    strcat(body, "#\tAction\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_MANAGE_ROLES))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AR_PERMISSIONS, "Role Permission Matrix");
        if (roleDb != Admin_GetRootRoleDbId())
        {
            AdminPanel_AddAction(playerid, body, sizeof(body), _:AR_DELETE, "Delete custom role");
        }
    }
    if (Admin_HasPermission(playerid, ADMIN_PERM_MANAGE_ADMINS))
    {
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AR_ASSIGN_ONLINE, "Assign a role to an online player");
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AR_ASSIGN_OFFLINE, "Assign a role to an offline account");
        AdminPanel_AddAction(playerid, body, sizeof(body), _:AR_REMOVE, "Remove the admin role from a player");
    }

    new title[160];
    format(title, sizeof(title), "Role: %s", name);
    ShowPlayerDialog(playerid, DIALOG_ADMIN_ROLE_ACTIONS, DIALOG_STYLE_TABLIST_HEADERS,
        title, body, "Select", "Back");
    return 1;
}

static stock AdminPanel_ShowRolePermissions(playerid)
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_MANAGE_ROLES, "ADMIN_ROLE_PERMS"))
    {
        return 0;
    }
    new const roleDb = sAdminPendingRole[playerid];
    if (roleDb <= 0) return 0;
    if (roleDb == Admin_GetRootRoleDbId())
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "The Root role has all rights and does not need to be configured.");
        return 0;
    }

    new body[MAX_ADMIN_DIALOG_BUFFER];
    strcat(body, "#\tRight\tCategory\tStatus\n", sizeof(body));
    new rows = 0;
    for (new p = _:ADMIN_PERM_PANEL_ACCESS; p < _:ADMIN_PERM_COUNT; p++)
    {
        new permName[ADMIN_PERMISSION_NAME_LEN], category[ADMIN_PERMISSION_CATEGORY_LEN];
        Admin_GetPermissionNameRu(E_ADMIN_PERM:p, permName, sizeof(permName));
        Admin_GetPermissionCategoryRu(E_ADMIN_PERM:p, category, sizeof(category));
        sAdminPermList[playerid][rows] = p;
        rows++;

        new line[192];
        format(line, sizeof(line), "%d\t%s\t%s\t%s\n",
            rows, permName, category,
            Admin_GetRolePermission(roleDb, E_ADMIN_PERM:p) ? ("Allowed") : ("Prohibited"));
        strcat(body, line, sizeof(body));
    }

    new title[160], roleName[MAX_ADMIN_ROLE_NAME];
    Admin_GetRoleNameByDbId(roleDb, roleName, sizeof(roleName));
    format(title, sizeof(title), "Role rights: %s", roleName);
    ShowPlayerDialog(playerid, DIALOG_ADMIN_ROLE_PERMS, DIALOG_STYLE_TABLIST_HEADERS,
        title, body, "Switch", "Back");
    return 1;
}

static stock AdminPanel_ShowOrgs(playerid)
{
    new body[4096];
    strcat(body, "#\tOrganization\tTag\tRanks\n", sizeof(body));
    new rows = 0;
    for (new orgId = 1; orgId <= 21 && rows < 32; orgId++)
    {
        new name[ORG_NAME_LEN], tag[ORG_TAG_LEN];
        if (!Organizations_GetName(orgId, name, sizeof(name))) continue;
        Organizations_GetTag(orgId, tag, sizeof(tag));
        sAdminOrgList[playerid][rows] = orgId;
        rows++;
        new line[192];
        format(line, sizeof(line), "%d\t%s\t%s\t%d\n", rows, name, tag, Organizations_GetRankCount(orgId));
        strcat(body, line, sizeof(body));
    }
    ShowPlayerDialog(playerid, DIALOG_ADMIN_ORGS, DIALOG_STYLE_TABLIST_HEADERS,
        "State factions", body, "Select", "Back");
    return 1;
}

static stock AdminPanel_ShowOrgRanks(playerid)
{
    new const orgId = sAdminPendingOrg[playerid];
    if (orgId <= 0) return 0;

    new body[4096], name[ORG_NAME_LEN];
    Organizations_GetName(orgId, name, sizeof(name));
    strcat(body, "#\tPosition\tHierarchy\tSalary\n", sizeof(body));

    new rows = 0, rankCount = Organizations_GetRankCount(orgId);
    for (new r = 0; r < rankCount && rows < MAX_ORG_RANKS; r++)
    {
        new title[ORG_RANK_TITLE_LEN];
        Organizations_GetRankTitle(orgId, r, title, sizeof(title));
        sAdminRankList[playerid][rows] = r;
        rows++;
        new line[192];
        format(line, sizeof(line), "%d\t%s\t%d\t%d\n",
            rows, title, Organizations_GetRankOrder(orgId, r), Organizations_GetRankSalary(orgId, r));
        strcat(body, line, sizeof(body));
    }

    if (rows == 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The organization does not have ranks configured.");
        return 0;
    }

    new title[160];
    format(title, sizeof(title), "Organization: %s", name);
    ShowPlayerDialog(playerid, DIALOG_ADMIN_ORG_RANKS, DIALOG_STYLE_TABLIST_HEADERS,
        title, body, "Assign", "Back");
    return 1;
}

static stock AdminPanel_ShowProperties(playerid)
{
    new body[MAX_ADMIN_DIALOG_BUFFER];
    strcat(body, "#\tID\tType\tOwner\n", sizeof(body));
    new rows = 0;
    for (new slot = 0; slot < MAX_PROPERTIES && rows < MAX_ADMIN_PROPERTY_ROWS; slot++)
    {
        new const dbId = Properties_GetDbId(slot);
        if (dbId <= 0) continue;

        new typeName[PROPERTY_TYPE_NAME_LEN];
        Properties_GetTypeNameRu(dbId, typeName, sizeof(typeName));
        sAdminPropertyList[playerid][rows] = dbId;
        rows++;

        new line[160];
        format(line, sizeof(line), "%d\t%d\t%s\t%d\n", rows, dbId, typeName, Properties_GetOwnerCharId(dbId));
        strcat(body, line, sizeof(body));
    }

    if (rows == 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "There is no busy property in the world.");
        return 0;
    }

    ShowPlayerDialog(playerid, DIALOG_ADMIN_PROPERTIES, DIALOG_STYLE_TABLIST_HEADERS,
        "Property: given to the player", body, "Issue", "Back");
    return 1;
}

static stock AdminPanel_ShowSkills(playerid)
{
    new const target = sAdminTarget[playerid];
    if (!AdminPanel_ValidTarget(playerid, target)) return 0;

    new body[MAX_ADMIN_DIALOG_BUFFER];
    strcat(body, "#\tSkill\tCategory\tValue\n", sizeof(body));
    for (new s = 0; s < TOTAL_SKILL_TYPES; s++)
    {
        new skillName[SKILL_DISPLAY_NAME_LEN], category[SKILL_CATEGORY_NAME_LEN];
        Skills_GetNameRu(E_SKILL_TYPE:s, skillName, sizeof(skillName));
        Skills_GetCategoryRu(E_SKILL_TYPE:s, category, sizeof(category));
        new line[192];
        format(line, sizeof(line), "%d\t%s\t%s\t%d\n",
            s + 1, skillName, category, Skills_Get(target, E_SKILL_TYPE:s));
        strcat(body, line, sizeof(body));
    }

    new name[MAX_PLAYER_NAME + 1], title[160];
    AdminPanel_GetTargetName(target, name, sizeof(name));
    format(title, sizeof(title), "Skills: %s", name);
    ShowPlayerDialog(playerid, DIALOG_ADMIN_SKILLS, DIALOG_STYLE_TABLIST_HEADERS,
        title, body, "Edit", "Back");
    return 1;
}

static stock AdminPanel_ShowInput(playerid, E_ADMIN_INPUT_ACTION:action, const caption[], const hint[])
{
    sAdminPendingAction[playerid] = _:action;
    sAdminPendingTarget[playerid] = sAdminTarget[playerid];
    ShowPlayerDialog(playerid, DIALOG_ADMIN_INPUT, DIALOG_STYLE_INPUT, caption, hint, "Apply", "Cancel");
    return 1;
}

static stock AdminPanel_ShowItemInput(playerid)
{
    new const target = sAdminTarget[playerid];
    if (!AdminPanel_ValidTarget(playerid, target)) return 0;
    sAdminPendingTarget[playerid] = target;
    ShowPlayerDialog(playerid, DIALOG_ADMIN_ITEM_INPUT, DIALOG_STYLE_INPUT,
        "Item Issue",
        "Enter: item_def_id quantity strength ammo meta_int1 meta_int2 meta_str\nExample: 23 1 100.0 0 0 0 No_tag",
        "Issue", "Cancel");
    return 1;
}

static stock AdminPanel_ShowConfirm(playerid, E_ADMIN_CONFIRM_ACTION:action, const caption[], const body[])
{
    sAdminConfirmAction[playerid] = action;
    ShowPlayerDialog(playerid, DIALOG_ADMIN_CONFIRM, DIALOG_STYLE_MSGBOX, caption, body, "Confirm", "Cancel");
    return 1;
}

// =============================================================================
//  5. »—œŒÀÕ≈Õ»≈ ƒ≈…—“¬»…
// =============================================================================

static stock Internal_ClearInventory(target)
{
    new slots[2];
    slots[0] = Character_GetLayer1Slot(target);
    slots[1] = Character_GetLayer2Slot(target);
    for (new s = 0; s < 2; s++)
    {
        if (!Storage_IsValidSlot(slots[s])) continue;
        new item = Storage_GetFirstItemSlot(slots[s]);
        while (item != INVALID_STORAGE_ITEM_SLOT)
        {
            new const next = Storage_GetNextItemSlot(item);
            new const amount = Storage_GetItemAmount(item);
            if (amount > 0)
            {
                Storage_RemoveItem(slots[s], item, amount);
            }
            item = next;
        }
    }
    Character_SyncLayer1Weapons(target);
    return 1;
}

static stock bool:Internal_ParseAccountId(const input[], &accountId)
{
    accountId = strval(input);
    return (accountId > 0);
}

static stock AdminPanel_ApplyVehicleNearest(playerid, E_ADMIN_VEH_ACTION:action)
{
    new slot = Vehicle_AdminGetNearestSlot(playerid, 12.0);
    if (slot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "There is no vehicle nearby within a radius of 12 meters.");
        return 0;
    }

    switch (action)
    {
        case AV_REPAIR:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_REPAIR, "ADMIN_VEH_REPAIR")) return 0;
            Vehicle_AdminRepair(slot);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "The vehicle has been completely renovated.");
            AdminPanel_SendAudit(playerid, playerid, "ADMIN_VEH_REPAIR", 0, Vehicle_GetDbId(slot), "Vehicle repair");
        }
        case AV_REFUEL:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_REFUEL, "ADMIN_VEH_REFUEL")) return 0;
            Vehicle_AdminRefuel(slot);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "The vehicle is fueled to a full tank.");
            AdminPanel_SendAudit(playerid, playerid, "ADMIN_VEH_REFUEL", 0, Vehicle_GetDbId(slot), "Refueling vehicles");
        }
        case AV_FLIP:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_REPAIR, "ADMIN_VEH_FLIP")) return 0;
            Vehicle_AdminFlip(slot);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "The vehicle is overturned.");
            AdminPanel_SendAudit(playerid, playerid, "ADMIN_VEH_FLIP", 0, Vehicle_GetDbId(slot), "Flip vehicle");
        }
        case AV_DESPAWN:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_DELETE, "ADMIN_VEH_DESPAWN")) return 0;
            new const dbId = Vehicle_GetDbId(slot);
            Vehicle_AdminDespawn(slot);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "Vehicle has been removed from the world. Return: /vehrespawn.");
            AdminPanel_SendAudit(playerid, playerid, "ADMIN_VEH_DESPAWN", 0, dbId, "Removing vehicles from the world");
        }
        case AV_RESPAWN:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_DELETE, "ADMIN_VEH_RESPAWN")) return 0;
            Vehicle_AdminRespawn(slot);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "The vehicle has been returned to the spawn point.");
            AdminPanel_SendAudit(playerid, playerid, "ADMIN_VEH_RESPAWN", 0, Vehicle_GetDbId(slot), "Vehicle respawn");
        }
        case AV_TELEPORT:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_TELEPORT, "ADMIN_VEH_TELEPORT")) return 0;
            new Float:x, Float:y, Float:z, Float:a;
            GetPlayerPos(playerid, x, y, z);
            GetPlayerFacingAngle(playerid, a);
            x += (floatsin(-a, degrees) * 3.0);
            y += (floatcos(-a, degrees) * 3.0);
            new const runtime = Vehicle_GetRuntimeId(slot);
            if (runtime != INVALID_VEHICLE_ID)
            {
                SetVehiclePos(runtime, x, y, z);
                SetVehicleZAngle(runtime, a);
            }
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "The vehicle has been teleported to you.");
            AdminPanel_SendAudit(playerid, playerid, "ADMIN_VEH_TELEPORT", 0, Vehicle_GetDbId(slot), "Vehicle teleport");
        }
    }
    return 1;
}

// =============================================================================
//  6. —À≈∆ ¿ /sp » HUD
// =============================================================================

static stock AdminPanel_CreateSpectateHud(playerid)
{
    sAdminHudBox[playerid] = CreatePlayerTextDraw(playerid, 10.0, 118.0, " ");
    PlayerTextDrawLetterSize(playerid, sAdminHudBox[playerid], 0.0, 0.0);
    PlayerTextDrawTextSize(playerid, sAdminHudBox[playerid], 290.0, 110.0);
    PlayerTextDrawAlignment(playerid, sAdminHudBox[playerid], TEXT_DRAW_ALIGN_LEFT);
    PlayerTextDrawColour(playerid, sAdminHudBox[playerid], 0);
    PlayerTextDrawSetShadow(playerid, sAdminHudBox[playerid], 0);
    PlayerTextDrawSetOutline(playerid, sAdminHudBox[playerid], 0);
    PlayerTextDrawBackgroundColour(playerid, sAdminHudBox[playerid], 0x00000000);
    PlayerTextDrawFont(playerid, sAdminHudBox[playerid], TEXT_DRAW_FONT_1);
    PlayerTextDrawSetProportional(playerid, sAdminHudBox[playerid], true);
    PlayerTextDrawUseBox(playerid, sAdminHudBox[playerid], true);
    PlayerTextDrawBoxColour(playerid, sAdminHudBox[playerid], 0x000000AA);

    sAdminHudInfo[playerid] = CreatePlayerTextDraw(playerid, 16.0, 122.0, " ");
    PlayerTextDrawLetterSize(playerid, sAdminHudInfo[playerid], 0.23, 0.9);
    PlayerTextDrawTextSize(playerid, sAdminHudInfo[playerid], 280.0, 0.0);
    PlayerTextDrawAlignment(playerid, sAdminHudInfo[playerid], TEXT_DRAW_ALIGN_LEFT);
    PlayerTextDrawColour(playerid, sAdminHudInfo[playerid], 0xFFFFFFFF);
    PlayerTextDrawSetShadow(playerid, sAdminHudInfo[playerid], 0);
    PlayerTextDrawSetOutline(playerid, sAdminHudInfo[playerid], 1);
    PlayerTextDrawBackgroundColour(playerid, sAdminHudInfo[playerid], 0x00000000);
    PlayerTextDrawFont(playerid, sAdminHudInfo[playerid], TEXT_DRAW_FONT_1);
    PlayerTextDrawSetProportional(playerid, sAdminHudInfo[playerid], true);
    PlayerTextDrawUseBox(playerid, sAdminHudInfo[playerid], false);

    sAdminHudFreeze[playerid] = CreatePlayerTextDraw(playerid, 16.0, 196.0, "Freeze");
    PlayerTextDrawLetterSize(playerid, sAdminHudFreeze[playerid], 0.2, 0.8);
    PlayerTextDrawTextSize(playerid, sAdminHudFreeze[playerid], 96.0, 18.0);
    PlayerTextDrawAlignment(playerid, sAdminHudFreeze[playerid], TEXT_DRAW_ALIGN_LEFT);
    PlayerTextDrawColour(playerid, sAdminHudFreeze[playerid], 0xFFFFFFFF);
    PlayerTextDrawSetShadow(playerid, sAdminHudFreeze[playerid], 0);
    PlayerTextDrawSetOutline(playerid, sAdminHudFreeze[playerid], 1);
    PlayerTextDrawBackgroundColour(playerid, sAdminHudFreeze[playerid], 0x00000000);
    PlayerTextDrawFont(playerid, sAdminHudFreeze[playerid], TEXT_DRAW_FONT_1);
    PlayerTextDrawSetProportional(playerid, sAdminHudFreeze[playerid], true);
    PlayerTextDrawUseBox(playerid, sAdminHudFreeze[playerid], true);
    PlayerTextDrawBoxColour(playerid, sAdminHudFreeze[playerid], 0x1E88E5AA);
    PlayerTextDrawSetSelectable(playerid, sAdminHudFreeze[playerid], true);

    sAdminHudSlap[playerid] = CreatePlayerTextDraw(playerid, 118.0, 196.0, "Slap");
    PlayerTextDrawLetterSize(playerid, sAdminHudSlap[playerid], 0.2, 0.8);
    PlayerTextDrawTextSize(playerid, sAdminHudSlap[playerid], 70.0, 18.0);
    PlayerTextDrawAlignment(playerid, sAdminHudSlap[playerid], TEXT_DRAW_ALIGN_LEFT);
    PlayerTextDrawColour(playerid, sAdminHudSlap[playerid], 0xFFFFFFFF);
    PlayerTextDrawSetShadow(playerid, sAdminHudSlap[playerid], 0);
    PlayerTextDrawSetOutline(playerid, sAdminHudSlap[playerid], 1);
    PlayerTextDrawBackgroundColour(playerid, sAdminHudSlap[playerid], 0x00000000);
    PlayerTextDrawFont(playerid, sAdminHudSlap[playerid], TEXT_DRAW_FONT_1);
    PlayerTextDrawSetProportional(playerid, sAdminHudSlap[playerid], true);
    PlayerTextDrawUseBox(playerid, sAdminHudSlap[playerid], true);
    PlayerTextDrawBoxColour(playerid, sAdminHudSlap[playerid], 0xFB8C00AA);
    PlayerTextDrawSetSelectable(playerid, sAdminHudSlap[playerid], true);

    sAdminHudKick[playerid] = CreatePlayerTextDraw(playerid, 194.0, 196.0, "Kick");
    PlayerTextDrawLetterSize(playerid, sAdminHudKick[playerid], 0.2, 0.8);
    PlayerTextDrawTextSize(playerid, sAdminHudKick[playerid], 56.0, 18.0);
    PlayerTextDrawAlignment(playerid, sAdminHudKick[playerid], TEXT_DRAW_ALIGN_LEFT);
    PlayerTextDrawColour(playerid, sAdminHudKick[playerid], 0xFFFFFFFF);
    PlayerTextDrawSetShadow(playerid, sAdminHudKick[playerid], 0);
    PlayerTextDrawSetOutline(playerid, sAdminHudKick[playerid], 1);
    PlayerTextDrawBackgroundColour(playerid, sAdminHudKick[playerid], 0x00000000);
    PlayerTextDrawFont(playerid, sAdminHudKick[playerid], TEXT_DRAW_FONT_1);
    PlayerTextDrawSetProportional(playerid, sAdminHudKick[playerid], true);
    PlayerTextDrawUseBox(playerid, sAdminHudKick[playerid], true);
    PlayerTextDrawBoxColour(playerid, sAdminHudKick[playerid], 0xE53935AA);
    PlayerTextDrawSetSelectable(playerid, sAdminHudKick[playerid], true);

    sAdminHudClose[playerid] = CreatePlayerTextDraw(playerid, 256.0, 196.0, "Close");
    PlayerTextDrawLetterSize(playerid, sAdminHudClose[playerid], 0.2, 0.8);
    PlayerTextDrawTextSize(playerid, sAdminHudClose[playerid], 44.0, 18.0);
    PlayerTextDrawAlignment(playerid, sAdminHudClose[playerid], TEXT_DRAW_ALIGN_LEFT);
    PlayerTextDrawColour(playerid, sAdminHudClose[playerid], 0xFFFFFFFF);
    PlayerTextDrawSetShadow(playerid, sAdminHudClose[playerid], 0);
    PlayerTextDrawSetOutline(playerid, sAdminHudClose[playerid], 1);
    PlayerTextDrawBackgroundColour(playerid, sAdminHudClose[playerid], 0x00000000);
    PlayerTextDrawFont(playerid, sAdminHudClose[playerid], TEXT_DRAW_FONT_1);
    PlayerTextDrawSetProportional(playerid, sAdminHudClose[playerid], true);
    PlayerTextDrawUseBox(playerid, sAdminHudClose[playerid], true);
    PlayerTextDrawBoxColour(playerid, sAdminHudClose[playerid], 0x555555AA);
    PlayerTextDrawSetSelectable(playerid, sAdminHudClose[playerid], true);
    return 1;
}

static stock AdminPanel_DestroySpectateHud(playerid)
{
    if (sAdminHudBox[playerid] != INVALID_PLAYER_TEXT_DRAW) PlayerTextDrawDestroy(playerid, sAdminHudBox[playerid]);
    if (sAdminHudInfo[playerid] != INVALID_PLAYER_TEXT_DRAW) PlayerTextDrawDestroy(playerid, sAdminHudInfo[playerid]);
    if (sAdminHudFreeze[playerid] != INVALID_PLAYER_TEXT_DRAW) PlayerTextDrawDestroy(playerid, sAdminHudFreeze[playerid]);
    if (sAdminHudSlap[playerid] != INVALID_PLAYER_TEXT_DRAW) PlayerTextDrawDestroy(playerid, sAdminHudSlap[playerid]);
    if (sAdminHudKick[playerid] != INVALID_PLAYER_TEXT_DRAW) PlayerTextDrawDestroy(playerid, sAdminHudKick[playerid]);
    if (sAdminHudClose[playerid] != INVALID_PLAYER_TEXT_DRAW) PlayerTextDrawDestroy(playerid, sAdminHudClose[playerid]);
    sAdminHudBox[playerid] = INVALID_PLAYER_TEXT_DRAW;
    sAdminHudInfo[playerid] = INVALID_PLAYER_TEXT_DRAW;
    sAdminHudFreeze[playerid] = INVALID_PLAYER_TEXT_DRAW;
    sAdminHudSlap[playerid] = INVALID_PLAYER_TEXT_DRAW;
    sAdminHudKick[playerid] = INVALID_PLAYER_TEXT_DRAW;
    sAdminHudClose[playerid] = INVALID_PLAYER_TEXT_DRAW;
    return 1;
}

static stock AdminPanel_UpdateSpectateHud(playerid)
{
    if (!sAdminSpectating[playerid]) return 0;
    new const target = sAdminSpectateTarget[playerid];
    if (!IsPlayerConnected(target) || !Character_IsLoaded(target))
    {
        AdminPanel_StopSpectate(playerid, true);
        return 0;
    }

    new name[MAX_PLAYER_NAME + 1];
    AdminPanel_GetTargetName(target, name, sizeof(name));

    new Float:hp, Float:armour, Float:x, Float:y, Float:z;
    GetPlayerHealth(target, hp);
    GetPlayerArmour(target, armour);
    GetPlayerPos(target, x, y, z);

    new vehicleId = GetPlayerVehicleID(target);
    new info[512];
    format(info, sizeof(info),
        "Spectate: %s (ID %d)~n~HP: %.0f | Armor: %.0f | Ping: %d ms~n~Vehicle: %d | X: %.1f Y: %.1f Z: %.1f~n~Interior: %d | Virtual world: %d",
        name, target, hp, armour, GetPlayerPing(target), vehicleId, x, y, z,
        GetPlayerInterior(target), GetPlayerVirtualWorld(target));
    PlayerTextDrawSetString(playerid, sAdminHudInfo[playerid], info);
    return 1;
}

static stock AdminPanel_StartSpectate(playerid, target)
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SPECTATE, "ADMIN_SPECTATE"))
    {
        return 0;
    }
    if (!AdminPanel_ValidTarget(playerid, target))
    {
        return 0;
    }
    if (target == playerid)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "You can't look after yourself.");
        return 0;
    }

    GetPlayerPos(playerid, sAdminSavedX[playerid], sAdminSavedY[playerid], sAdminSavedZ[playerid]);
    sAdminSavedInterior[playerid] = GetPlayerInterior(playerid);
    sAdminSavedVW[playerid] = GetPlayerVirtualWorld(playerid);

    sAdminSpectating[playerid] = true;
    sAdminSpectateTarget[playerid] = target;
    TogglePlayerSpectating(playerid, true);
    PlayerSpectatePlayer(playerid, target, SPECTATE_MODE_NORMAL);

    PlayerTextDrawShow(playerid, sAdminHudBox[playerid]);
    PlayerTextDrawShow(playerid, sAdminHudInfo[playerid]);
    PlayerTextDrawShow(playerid, sAdminHudFreeze[playerid]);
    PlayerTextDrawShow(playerid, sAdminHudSlap[playerid]);
    PlayerTextDrawShow(playerid, sAdminHudKick[playerid]);
    PlayerTextDrawShow(playerid, sAdminHudClose[playerid]);
    SelectTextDraw(playerid, 0xFFC800FF);
    AdminPanel_UpdateSpectateHud(playerid);

    new name[MAX_PLAYER_NAME + 1], msg[160];
    AdminPanel_GetTargetName(target, name, sizeof(name));
    format(msg, sizeof(msg), "Spectate started: %s (ID %d). The exit is the \"Close\" button.", name, target);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    AdminPanel_SendAudit(playerid, target, "ADMIN_SPECTATE_START", 0, 0, "Start of spectating");
    return 1;
}

static stock AdminPanel_StopSpectate(playerid, bool:notify)
{
    if (!sAdminSpectating[playerid])
    {
        return 0;
    }

    PlayerTextDrawHide(playerid, sAdminHudBox[playerid]);
    PlayerTextDrawHide(playerid, sAdminHudInfo[playerid]);
    PlayerTextDrawHide(playerid, sAdminHudFreeze[playerid]);
    PlayerTextDrawHide(playerid, sAdminHudSlap[playerid]);
    PlayerTextDrawHide(playerid, sAdminHudKick[playerid]);
    PlayerTextDrawHide(playerid, sAdminHudClose[playerid]);
    CancelSelectTextDraw(playerid);

    new const target = sAdminSpectateTarget[playerid];
    sAdminSpectating[playerid] = false;
    sAdminSpectateTarget[playerid] = INVALID_PLAYER_ID;

    if (IsPlayerConnected(playerid))
    {
        TogglePlayerSpectating(playerid, false);
        SetPlayerInterior(playerid, sAdminSavedInterior[playerid]);
        SetPlayerVirtualWorld(playerid, sAdminSavedVW[playerid]);
        Utils_SetPlayerPos(playerid, sAdminSavedX[playerid], sAdminSavedY[playerid], sAdminSavedZ[playerid]);
        SetCameraBehindPlayer(playerid);
    }

    if (notify)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Spectate completed.");
    }
    AdminPanel_SendAudit(playerid, target, "ADMIN_SPECTATE_STOP", 0, 0, "Ending spectating");
    return 1;
}

// =============================================================================
//  7. ¿”ƒ»“ » ¿Õ“»◊»“
// =============================================================================

static stock AdminPanel_ShowAudit(playerid)
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_VIEW_AUDIT, "ADMIN_AUDIT_VIEW"))
    {
        return 0;
    }
    if (!DB_IsConnected())
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The database is unavailable and the audit log is temporarily unavailable.");
        return 0;
    }

    mysql_tquery(gMySQL,
        "SELECT `id`, IFNULL(`admin_account_id`, 0) AS `admin_id`, IFNULL(`target_account_id`, 0) AS `target_id`, `action_type`, `details`, `created_at` FROM `audit_logs` ORDER BY `id` DESC LIMIT 25;",
        "OnAdminAuditLoaded", "dd", playerid, Config_GetPlayerSessionToken(playerid));
    return 1;
}

forward OnAdminAuditLoaded(playerid, sessionToken);
public OnAdminAuditLoaded(playerid, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 0;
    }

    new rows = 0;
    cache_get_row_count(rows);
    if (rows <= 0)
    {
        ShowPlayerDialog(playerid, DIALOG_ADMIN_AUDIT, DIALOG_STYLE_MSGBOX,
            "Audit log", "There are no entries.", "Close", "");
        return 1;
    }

    new body[MAX_ADMIN_DIALOG_BUFFER];
    body[0] = EOS;
    for (new row = 0; row < rows; row++)
    {
        new adminId = 0, targetId = 0;
        new action[48], details[AUDIT_DETAILS_MAX_LEN + 1], created[32];
        cache_get_value_name_int(row, "admin_id", adminId);
        cache_get_value_name_int(row, "target_id", targetId);
        cache_get_value_name(row, "action_type", action, sizeof(action));
        cache_get_value_name(row, "details", details, sizeof(details));
        cache_get_value_name(row, "created_at", created, sizeof(created));

        new line[256];
        format(line, sizeof(line), "[%s] %s | admin: %d | target: %d | %s\n",
            created, action, adminId, targetId, details);
        strcat(body, line, sizeof(body));
        if (strlen(body) > (MAX_ADMIN_DIALOG_BUFFER - 300))
        {
            break;
        }
    }

    ShowPlayerDialog(playerid, DIALOG_ADMIN_AUDIT, DIALOG_STYLE_MSGBOX,
        "Audit log (last 25)", body, "Close", "");
    return 1;
}

static stock AdminPanel_ShowAnticheat(playerid)
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_VIEW_ANTICHEAT, "ADMIN_ANTICHEAT_VIEW"))
    {
        return 0;
    }

    new body[1024];
    format(body, sizeof(body),
        "Total packages checked: %d\nViolations recorded: %d\nAnticheat kicks: %d\nAnticheat bans: %d\nIntegration tests: %s",
        AC_GetPacketsChecked(), AC_GetTotalViolations(), AC_GetTotalKicks(), AC_GetTotalBans(),
        AC_AreIntegrationTestsPassed() ? ("passed") : ("failed"));
    ShowPlayerDialog(playerid, DIALOG_ADMIN_ANTICHEAT, DIALOG_STYLE_MSGBOX,
        "Anti-cheat: statistics", body, "Close", "");
    return 1;
}

// =============================================================================
//  8. —œ–¿¬ ¿ /ahelp
// =============================================================================

static stock AdminPanel_ShowHelp(playerid)
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_HELP_ACCESS, "AHELP_OPEN"))
    {
        return 0;
    }

    new body[MAX_ADMIN_DIALOG_BUFFER];
    body[0] = EOS;
    strcat(body, "Administrative commands:\n\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PANEL_ACCESS)) strcat(body, "/apanel - main menu of the admin panel\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_TELEPORT)) strcat(body, "/goto [id] - teleport to player\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_GET_HERE)) strcat(body, "/gethere [id] - teleport the player to himself\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_SPECTATE)) strcat(body, "/sp [id] - spectating with HUD panel\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_FREEZE)) strcat(body, "/freeze [id] | /unfreeze [id] - freezing\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_SLAP)) strcat(body, "/slap [id] - slap\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_SET_STATS)) strcat(body, "/setstat [id] [hp|armour|hunger|thirst|stamina|stress] [value]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_SET_SKIN)) strcat(body, "/setskin [id] [skin]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_KICK)) strcat(body, "/kick [id] [reason] | /quietkick [id]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_BAN)) strcat(body, "/ban [id] [minutes] [reason] (0 = forever) | /banoff nick|ip|hwid [value] [minutes] [reason]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_UNBAN)) strcat(body, "/unban [account_id|nickname]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_MUTE)) strcat(body, "/mute [id] [minutes] [reason]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_WARN)) strcat(body, "/warn [id] [reason]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_JAIL)) strcat(body, "/jail [id] [minutes] [reason] | /release [id]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_SET_STATS)) strcat(body, "/setaddiction [id] [0-100]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_CHAR_SET_STATUS)) strcat(body, "/setck [id] [0|1] | /setcitizen [id] [0|1] | /setssn [id] [SSN]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_MUTE)) strcat(body, "/unmute [id]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PLAYER_SET_WANTED)) strcat(body, "/setwanted [id] [0-100]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_CHAR_SET_LEVEL)) strcat(body, "/setlevel [id] [level]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_CHAR_SET_EXP)) strcat(body, "/setexp [id] [seconds]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_CHAR_SET_SKILLS)) strcat(body, "/skills [id] - skill editor\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_CHAR_SET_LICENSES)) strcat(body, "/setlicenses [id] - issue/withdraw a license\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_ECON_GIVE_CASH)) strcat(body, "/setcash [id] [amount] - issue/withdraw cash\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_ECON_SET_BANK)) strcat(body, "/setbank [id] [amount]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_ECON_ISSUE_DEBT) || Admin_HasPermission(playerid, ADMIN_PERM_ECON_CLEAR_DEBT)) strcat(body, "/setdebt [id] [amount]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_ORG_SET_LEADER) || Admin_HasPermission(playerid, ADMIN_PERM_ORG_SET_MEMBER)) strcat(body, "/setleader [id] [org_id] | /setfrac [id] [org_id] [rank]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_INV_VIEW)) strcat(body, "/setinv [id] - player inventory\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_INV_GIVE_ITEM)) strcat(body, "/giveitem [id] [item_id] [quantity] [strength] [ammo] [meta1] [meta2]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_INV_CLEAR)) strcat(body, "/clearinv [id]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PROP_GIVE)) strcat(body, "/propgive [id] [property_id] - issue property\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PROP_REMOVE)) strcat(body, "/propclear [property_id] - withdraw property\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PROP_GIVE)) strcat(body, "/bizgive [id] [enterprise_id] - issue enterprise\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PROP_REMOVE)) strcat(body, "/bizclear [enterprise_id] - withdraw enterprise\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_PROP_GIVE)) strcat(body, "/bizlist - list of enterprises\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_SPAWN)) strcat(body, "/veh [model] [id?]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_KEYS)) strcat(body, "/vehkeys [id?]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_REPAIR)) strcat(body, "/vfix | /vflip\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_REFUEL)) strcat(body, "/vfuel\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_DELETE)) strcat(body, "/vehdespawn | /vehrespawn\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_VEH_TELEPORT)) strcat(body, "/vehtp\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_WORLD_TELEPORT)) strcat(body, "/atp [x] [y] [z]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_WORLD_WEATHER)) strcat(body, "/weather [id]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_WORLD_TIME)) strcat(body, "/time [0-23]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_WORLD_ANNOUNCE)) strcat(body, "/ao [text]\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_SERVER_SAVE)) strcat(body, "/asave - emergency saving of the database\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_VIEW_AUDIT)) strcat(body, "/alog - audit log\n", sizeof(body));
    if (Admin_HasPermission(playerid, ADMIN_PERM_MANAGE_ADMINS)) strcat(body, "/arole [account_id] [role_id] (0 = remove role)\n", sizeof(body));
    strcat(body, "/ahelp - this help\n", sizeof(body));

    ShowPlayerDialog(playerid, DIALOG_ADMIN_HELP, DIALOG_STYLE_MSGBOX,
        "Admin Help", body, "Close", "");
    return 1;
}

// =============================================================================
//  9. Œ¡–¿¡Œ“◊» » ƒ»¿ÀŒ√Œ¬
// =============================================================================

static stock AdminPanel_HandlePlayerAction(playerid, E_ADMIN_PLAYER_ACTION:action)
{
    new const target = sAdminTarget[playerid];
    if (!AdminPanel_ValidTarget(playerid, target)) return 0;

    new msg[192];
    switch (action)
    {
        case AP_ACTION_NONE: return 0;
        case AP_TELEPORT:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_TELEPORT, "ADMIN_GOTO")) return 0;
            new Float:x, Float:y, Float:z;
            GetPlayerPos(target, x, y, z);
            SetPlayerInterior(playerid, GetPlayerInterior(target));
            SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(target));
            Utils_SetPlayerPos(playerid, x + 1.0, y + 1.0, z);
            SetCameraBehindPlayer(playerid);
            AC_MarkServerTeleport(playerid, 3000);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "You are teleported to the player.");
            AdminPanel_SendAudit(playerid, target, "ADMIN_GOTO", 0, 0, "Teleport administrator to player");
        }
        case AP_GET_HERE:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_GET_HERE, "ADMIN_GETHERE")) return 0;
            new Float:x, Float:y, Float:z;
            GetPlayerPos(playerid, x, y, z);
            SetPlayerInterior(target, GetPlayerInterior(playerid));
            SetPlayerVirtualWorld(target, GetPlayerVirtualWorld(playerid));
            Utils_SetPlayerPos(target, x + 1.0, y + 1.0, z);
            AC_MarkServerTeleport(target, 3000);
            SendClientMessage(target, COLOR_UI_INFO, "The administrator teleported you to his place.");
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player is teleported to you.");
            AdminPanel_SendAudit(playerid, target, "ADMIN_GETHERE", 0, 0, "Teleport player to administrator");
        }
        case AP_SPECTATE:
        {
            return AdminPanel_StartSpectate(playerid, target);
        }
        case AP_FREEZE:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_FREEZE, "ADMIN_FREEZE")) return 0;
            sAdminFrozen[target] = !sAdminFrozen[target];
            TogglePlayerControllable(target, !sAdminFrozen[target]);
            format(msg, sizeof(msg), "Player %s.", sAdminFrozen[target] ? ("frozen") : ("defrosted"));
            SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
            SendClientMessage(target, COLOR_UI_WARNING, sAdminFrozen[target] ? "The administrator has frozen you." : "The administrator has unfrozen you.");
            AdminPanel_SendAudit(playerid, target, "ADMIN_FREEZE", 0, sAdminFrozen[target] ? 1 : 0, "Changing player freeze");
        }
        case AP_SLAP:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SLAP, "ADMIN_SLAP")) return 0;
            new Float:hp;
            GetPlayerHealth(target, hp);
            SetPlayerHealth(target, (hp > 5.0) ? (hp - 5.0) : 1.0);
            SetPlayerVelocity(target, 0.0, 0.0, 6.0);
            SendClientMessage(target, COLOR_UI_WARNING, "The administrator slapped you.");
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "The slap is completed.");
            AdminPanel_SendAudit(playerid, target, "ADMIN_SLAP", 0, 5, "Player slap");
        }
        case AP_SET_HP: return AdminPanel_ShowInput(playerid, AI_INPUT_HP, "Player HP", "Enter a new HP value (0-100):");
        case AP_SET_ARMOUR: return AdminPanel_ShowInput(playerid, AI_INPUT_ARMOUR, "Player armor", "Enter a new armor value (0-100):");
        case AP_SET_HUNGER: return AdminPanel_ShowInput(playerid, AI_INPUT_HUNGER, "Player hunger", "Enter hunger value (0-100):");
        case AP_SET_THIRST: return AdminPanel_ShowInput(playerid, AI_INPUT_THIRST, "Player's Thirst", "Enter thirst value (0-100):");
        case AP_SET_STAMINA: return AdminPanel_ShowInput(playerid, AI_INPUT_STAMINA, "Player Stamina", "Enter stamina value (0-100):");
        case AP_SET_STRESS: return AdminPanel_ShowInput(playerid, AI_INPUT_STRESS, "Player stress", "Enter stress value (0-100):");
        case AP_SET_SKIN: return AdminPanel_ShowInput(playerid, AI_INPUT_SKIN, "Player skin", "Enter skin ID (1-311, except 74):");
        case AP_KICK:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_KICK, "ADMIN_KICK")) return 0;
            AdminPanel_SendAudit(playerid, target, "ADMIN_KICK", 0, 0, "Player kick");
            SendClientMessage(target, COLOR_UI_ERROR, "You have been kicked by an administrator.");
            defer Admin_DelayedKick(target, Config_GetPlayerSessionToken(target));
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player has been kicked.");
        }
        case AP_QUIET_KICK:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_KICK, "ADMIN_QUIETKICK")) return 0;
            AdminPanel_SendAudit(playerid, target, "ADMIN_QUIETKICK", 0, 0, "Quiet player kick");
            defer Admin_DelayedKick(target, Config_GetPlayerSessionToken(target));
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player has been kicked without public notice.");
        }
        case AP_BAN_TEMP: return AdminPanel_ShowInput(playerid, AI_INPUT_BAN_TEMP, "Temporary ban", "Enter: minutes reason\nExample: 60 Insult to the administration");
        case AP_BAN_PERM: return AdminPanel_ShowInput(playerid, AI_INPUT_BAN_PERM, "Permanent ban", "Enter the reason for the permanent ban:");
        case AP_MUTE: return AdminPanel_ShowInput(playerid, AI_INPUT_MUTE, "Mute player", "Enter mute minutes and reason:\nExample: 30 Flood in general chat");
        case AP_WARN: return AdminPanel_ShowInput(playerid, AI_INPUT_WARN, "Warning", "Enter the reason for the warning:");
        case AP_JAIL: return AdminPanel_ShowInput(playerid, AI_INPUT_JAIL, "Admin prison", "Enter jail duration in minutes and the reason:\nExample: 15 Inappropriate behavior");
        case AP_SET_WANTED: return AdminPanel_ShowInput(playerid, AI_INPUT_WANTED, "Wanted level", "Enter your wanted level (0-100):");
        case AP_SET_LEVEL: return AdminPanel_ShowInput(playerid, AI_INPUT_LEVEL, "Character level", "Enter new level (1-1000):");
        case AP_SET_EXP: return AdminPanel_ShowInput(playerid, AI_INPUT_EXP, "Character Experience", "Enter the number of seconds of experience:");
        case AP_SKILLS:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_CHAR_SET_SKILLS, "ADMIN_SKILLS")) return 0;
            return AdminPanel_ShowSkills(playerid);
        }
        case AP_LICENSES:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_CHAR_SET_LICENSES, "ADMIN_LICENSES")) return 0;
            new const bool:banned = Character_IsWeaponLicenseBanned(target);
            Character_SetWeaponLicenseBanned(target, !banned);
            format(msg, sizeof(msg), "Weapons license %s.", banned ? ("restored") : ("seized"));
            SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
            SendClientMessage(target, COLOR_UI_WARNING, banned ? "Your gun license has been reinstated." : "Your gun license has been seized by the administrator.");
            AdminPanel_SendAudit(playerid, target, "ADMIN_LICENSE", 0, banned ? 1 : 0, msg);
        }
        case AP_CASH: return AdminPanel_ShowInput(playerid, AI_INPUT_CASH, "Cash", "Enter the amount: positive number - issue, negative number - withdraw:");
        case AP_BANK: return AdminPanel_ShowInput(playerid, AI_INPUT_BANK, "Bank balance", "Enter new bank balance USD:");
        case AP_DEBT: return AdminPanel_ShowInput(playerid, AI_INPUT_DEBT, "Bank debt", "Enter new bank debt USD:");
        case AP_INVENTORY:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_INV_VIEW, "ADMIN_INV_VIEW")) return 0;
            Dialogs_OpenSearchTarget(playerid, target, true, true);
            AdminPanel_SendAudit(playerid, target, "ADMIN_INV_VIEW", 0, 0, "Opening a player's inventory");
        }
        case AP_CLEAR_INV:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_INV_CLEAR, "ADMIN_INV_CLEAR")) return 0;
            sAdminPendingTarget[playerid] = target;
            AdminPanel_ShowConfirm(playerid, AC_CLEAR_INVENTORY, "Clearing Inventory", "Remove all items from both layers of a player's inventory?");
        }
        case AP_GIVE_ITEM:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_INV_GIVE_ITEM, "ADMIN_INV_GIVE")) return 0;
            return AdminPanel_ShowItemInput(playerid);
        }
        case AP_VEH_SPAWN:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_SPAWN, "ADMIN_VEH_SPAWN")) return 0;
            return AdminPanel_ShowInput(playerid, AI_INPUT_VEH_MODEL, "Vehicle spawn", "Enter the vehicle model (for example, 411):");
        }
        case AP_VEH_KEYS:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_KEYS, "ADMIN_VEH_KEYS")) return 0;
            new slot = Vehicle_AdminGetNearestSlot(target, 12.0);
            if (slot < 0)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "There is no vehicle near the player.");
                return 0;
            }
            if (!Vehicle_AdminIssueKey(target, slot))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to issue keys: the player's inventory is full.");
                return 0;
            }
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "The keys to the vehicle are given to the player.");
            SendClientMessage(target, COLOR_UI_INFO, "The administrator gave you the keys to the vehicle.");
            AdminPanel_SendAudit(playerid, target, "ADMIN_VEH_KEYS", 0, Vehicle_GetDbId(slot), "Give vehicle keys");
        }
        case AP_ORG:
        {
            if (!Admin_HasPermission(playerid, ADMIN_PERM_ORG_SET_LEADER) &&
                !Admin_HasPermission(playerid, ADMIN_PERM_ORG_SET_MEMBER))
            {
                AdminPanel_Require(playerid, ADMIN_PERM_ORG_SET_MEMBER, "ADMIN_ORG_SET");
                return 0;
            }
            sAdminPendingTarget[playerid] = target;
            AdminPanel_ShowOrgs(playerid);
        }
        case AP_PROPERTY:
        {
            if (!AdminPanel_Require(playerid, ADMIN_PERM_PROP_GIVE, "ADMIN_PROP_GIVE")) return 0;
            sAdminPendingTarget[playerid] = target;
            AdminPanel_ShowProperties(playerid);
        }
    }
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid < DIALOG_ADMIN_MAIN || dialogid > DIALOG_ADMIN_INVENTORY)
    {
        return 1;
    }

    switch (dialogid)
    {
        case DIALOG_ADMIN_MAIN:
        {
            if (!response || listitem < 0 || listitem >= sAdminMenuCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            switch (E_ADMIN_MAIN_ACTION:sAdminMenuAction[playerid][listitem])
            {
                case AM_MAIN_NONE: {}
                case AM_MAIN_PLAYERS: AdminPanel_ShowTargets(playerid, ATM_PLAYER_ACTIONS, "Select a player");
                case AM_MAIN_ORGS: AdminPanel_ShowTargets(playerid, ATM_ORG_TARGET, "Select a player to assign");
                case AM_MAIN_ECONOMY: AdminPanel_ShowTargets(playerid, ATM_ECONOMY, "Economy: Select Player");
                case AM_MAIN_INVENTORY: AdminPanel_ShowTargets(playerid, ATM_INVENTORY, "Inventory: Select a player");
                case AM_MAIN_VEHICLES: AdminPanel_ShowVehicles(playerid);
                case AM_MAIN_WORLD: AdminPanel_ShowWorld(playerid);
                case AM_MAIN_ROLES: AdminPanel_ShowRoles(playerid);
                case AM_MAIN_AUDIT: AdminPanel_ShowAudit(playerid);
                case AM_MAIN_ANTICHEAT: AdminPanel_ShowAnticheat(playerid);
                case AM_MAIN_SPECTATE: AdminPanel_ShowTargets(playerid, ATM_SPECTATE, "Spectate: Select Player");
                case AM_MAIN_REPORTS: AdminReports_OpenQueueDialog(playerid);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_TARGETS:
        {
            if (!response)
            {
                AdminPanel_ShowMain(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sAdminTargetCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const target = sAdminTargets[playerid][listitem];
            if (!AdminPanel_ValidTarget(playerid, target))
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            sAdminTarget[playerid] = target;

            switch (sAdminTargetMode[playerid])
            {
                case ATM_PLAYER_ACTIONS: AdminPanel_ShowPlayerActions(playerid);
                case ATM_ECONOMY: AdminPanel_ShowEconomyActions(playerid);
                case ATM_INVENTORY: AdminPanel_ShowInventoryActions(playerid);
                case ATM_ORG_TARGET:
                {
                    sAdminPendingTarget[playerid] = target;
                    AdminPanel_ShowOrgs(playerid);
                }
                case ATM_VEH_SPAWN:
                {
                    sAdminPendingTarget[playerid] = target;
                    AdminPanel_ShowInput(playerid, AI_INPUT_VEH_MODEL, "Vehicle spawn for player", "Enter the vehicle model (for example, 411):");
                }
                case ATM_VEH_KEYS:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_KEYS, "ADMIN_VEH_KEYS")) return Y_HOOKS_BREAK_RETURN_1;
                    new slot = Vehicle_AdminGetNearestSlot(target, 12.0);
                    if (slot < 0)
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "There is no vehicle near the player.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    Vehicle_AdminIssueKey(target, slot);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The keys are given to the player.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_VEH_KEYS", 0, Vehicle_GetDbId(slot), "Give vehicle keys");
                }
                case ATM_SPECTATE: AdminPanel_StartSpectate(playerid, target);
                case ATM_ROLE_ASSIGN:
                {
                    new const roleDb = sAdminPendingRole[playerid];
                    if (Admin_AssignRole(playerid, Account_GetId(target), roleDb))
                    {
                        SendClientMessage(playerid, COLOR_UI_SUCCESS, "The admin role is assigned to the player.");
                    }
                    else
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to assign role.");
                    }
                }
                case ATM_ROLE_REMOVE:
                {
                    if (Admin_RemoveRole(playerid, Account_GetId(target)))
                    {
                        SendClientMessage(playerid, COLOR_UI_SUCCESS, "The admin role has been removed from the player.");
                    }
                }
                case ATM_PROPERTY:
                {
                    AdminPanel_ShowProperties(playerid);
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_PLAYER_ACTIONS:
        {
            if (!response)
            {
                AdminPanel_ShowTargets(playerid, ATM_PLAYER_ACTIONS, "Select a player");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sAdminMenuCount[playerid]) return Y_HOOKS_BREAK_RETURN_1;
            AdminPanel_HandlePlayerAction(playerid, E_ADMIN_PLAYER_ACTION:sAdminMenuAction[playerid][listitem]);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_ECONOMY:
        {
            if (!response)
            {
                AdminPanel_ShowTargets(playerid, ATM_ECONOMY, "Economy: Select Player");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sAdminMenuCount[playerid]) return Y_HOOKS_BREAK_RETURN_1;
            switch (E_ADMIN_ECON_ACTION:sAdminMenuAction[playerid][listitem])
            {
                case AE_ACTION_NONE: {}
                case AE_CASH: AdminPanel_ShowInput(playerid, AI_INPUT_CASH, "Cash", "Enter the amount: positive number - issue, negative number - withdraw:");
                case AE_BANK: AdminPanel_ShowInput(playerid, AI_INPUT_BANK, "Bank balance", "Enter new bank balance USD:");
                case AE_DEBT: AdminPanel_ShowInput(playerid, AI_INPUT_DEBT, "Bank debt", "Enter new bank debt USD:");
                case AE_CLEAR_DEBT:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_ECON_CLEAR_DEBT, "ADMIN_ECON_CLEAR_DEBT")) return Y_HOOKS_BREAK_RETURN_1;
                    new const target = sAdminTarget[playerid];
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    Character_SetBankDebtUsd(target, 0);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The bank debt has been repaid.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_ECON_CLEAR_DEBT", 0, 0, "Repay bank debt");
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_INVENTORY:
        {
            if (!response)
            {
                AdminPanel_ShowTargets(playerid, ATM_INVENTORY, "Inventory: Select a player");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sAdminMenuCount[playerid]) return Y_HOOKS_BREAK_RETURN_1;
            switch (E_ADMIN_INV_ACTION:sAdminMenuAction[playerid][listitem])
            {
                case AI_ACTION_NONE: {}
                case AI_VIEW:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_INV_VIEW, "ADMIN_INV_VIEW")) return Y_HOOKS_BREAK_RETURN_1;
                    Dialogs_OpenSearchTarget(playerid, sAdminTarget[playerid], true, true);
                    AdminPanel_SendAudit(playerid, sAdminTarget[playerid], "ADMIN_INV_VIEW", 0, 0, "Opening a player's inventory");
                }
                case AI_GIVE:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_INV_GIVE_ITEM, "ADMIN_INV_GIVE")) return Y_HOOKS_BREAK_RETURN_1;
                    AdminPanel_ShowItemInput(playerid);
                }
                case AI_CLEAR:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_INV_CLEAR, "ADMIN_INV_CLEAR")) return Y_HOOKS_BREAK_RETURN_1;
                    sAdminPendingTarget[playerid] = sAdminTarget[playerid];
                    AdminPanel_ShowConfirm(playerid, AC_CLEAR_INVENTORY, "Clearing Inventory", "Remove all items from both layers of a player's inventory?");
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_VEHICLES:
        {
            if (!response) { AdminPanel_ShowMain(playerid); return Y_HOOKS_BREAK_RETURN_1; }
            if (listitem < 0 || listitem >= sAdminMenuCount[playerid]) return Y_HOOKS_BREAK_RETURN_1;
            switch (E_ADMIN_VEH_ACTION:sAdminMenuAction[playerid][listitem])
            {
                case AV_ACTION_NONE: {}
                case AV_SPAWN_SELF:
                {
                    sAdminTarget[playerid] = playerid;
                    AdminPanel_ShowInput(playerid, AI_INPUT_VEH_MODEL, "Vehicle spawn", "Enter the vehicle model (for example, 411):");
                }
                case AV_SPAWN_TARGET: AdminPanel_ShowTargets(playerid, ATM_VEH_SPAWN, "Who should spawn the vehicle?");
                case AV_KEYS_TARGET: AdminPanel_ShowTargets(playerid, ATM_VEH_KEYS, "Who should I give the keys to?");
                case AV_REPAIR, AV_REFUEL, AV_FLIP, AV_DESPAWN, AV_RESPAWN, AV_TELEPORT:
                    AdminPanel_ApplyVehicleNearest(playerid, E_ADMIN_VEH_ACTION:sAdminMenuAction[playerid][listitem]);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_WORLD:
        {
            if (!response) { AdminPanel_ShowMain(playerid); return Y_HOOKS_BREAK_RETURN_1; }
            if (listitem < 0 || listitem >= sAdminMenuCount[playerid]) return Y_HOOKS_BREAK_RETURN_1;
            switch (E_ADMIN_WORLD_ACTION:sAdminMenuAction[playerid][listitem])
            {
                case AW_ACTION_NONE: {}
                case AW_TELEPORT: AdminPanel_ShowInput(playerid, AI_INPUT_TP, "Teleport by coordinates", "Enter coordinates: X Y Z\nExample: 1481.0 -1771.0 18.8");
                case AW_WEATHER: AdminPanel_ShowInput(playerid, AI_INPUT_WEATHER, "weather", "Enter weather ID (0-20):");
                case AW_TIME: AdminPanel_ShowInput(playerid, AI_INPUT_TIME, "Time of day", "Enter hour (0-23):");
                case AW_ANNOUNCE: AdminPanel_ShowInput(playerid, AI_INPUT_ANNOUNCE, "Global announcement", "Enter ad text:");
                case AW_SAVE:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_SERVER_SAVE, "ADMIN_SERVER_SAVE")) return Y_HOOKS_BREAK_RETURN_1;
                    DB_FlushAllDirtySync();
                    Audit_FlushBufferSync();
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Emergency database saving completed.");
                    AdminPanel_SendAudit(playerid, playerid, "ADMIN_SERVER_SAVE", 0, 0, "Emergency database saving");
                }
                case AW_AUDIT: AdminPanel_ShowAudit(playerid);
                case AW_ANTICHEAT: AdminPanel_ShowAnticheat(playerid);
                case AW_RESTART:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_SERVER_RESTART, "ADMIN_SERVER_RESTART")) return Y_HOOKS_BREAK_RETURN_1;
                    AdminPanel_ShowConfirm(playerid, AC_RESTART_SERVER, "Restarting the server", "Are you sure you want to restart the server? All players will be disconnected.");
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_ORGS:
        {
            if (!response) { AdminPanel_ShowTargets(playerid, ATM_ORG_TARGET, "Select a player to assign"); return Y_HOOKS_BREAK_RETURN_1; }
            if (listitem < 0 || listitem >= 32) return Y_HOOKS_BREAK_RETURN_1;
            new const orgId = sAdminOrgList[playerid][listitem];
            if (orgId <= 0) return Y_HOOKS_BREAK_RETURN_1;
            sAdminPendingOrg[playerid] = orgId;
            AdminPanel_ShowOrgRanks(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_ORG_RANKS:
        {
            if (!response) { AdminPanel_ShowOrgs(playerid); return Y_HOOKS_BREAK_RETURN_1; }
            if (listitem < 0 || listitem >= MAX_ORG_RANKS) return Y_HOOKS_BREAK_RETURN_1;
            new const target = sAdminPendingTarget[playerid];
            if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;

            new const orgId = sAdminPendingOrg[playerid];
            new const rankIndex = sAdminRankList[playerid][listitem];
            new const rankDb = Organizations_GetRankDbId(orgId, rankIndex);
            new const rankOrder = Organizations_GetRankOrder(orgId, rankIndex);
            new highestOrder = 0;
            for (new r = 0; r < Organizations_GetRankCount(orgId); r++)
            {
                if (Organizations_GetRankOrder(orgId, r) > highestOrder) highestOrder = Organizations_GetRankOrder(orgId, r);
            }
            if (rankOrder >= highestOrder)
            {
                if (!AdminPanel_Require(playerid, ADMIN_PERM_ORG_SET_LEADER, "ADMIN_ORG_LEADER")) return Y_HOOKS_BREAK_RETURN_1;
            }
            else
            {
                if (!AdminPanel_Require(playerid, ADMIN_PERM_ORG_SET_MEMBER, "ADMIN_ORG_MEMBER")) return Y_HOOKS_BREAK_RETURN_1;
            }
            if (rankDb <= 0 || !Organizations_GrantMembership(target, orgId, rankDb))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to assign player to organization.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new orgName[ORG_NAME_LEN], rankTitle[ORG_RANK_TITLE_LEN], msg[256];
            Organizations_GetName(orgId, orgName, sizeof(orgName));
            Organizations_GetRankTitle(orgId, rankIndex, rankTitle, sizeof(rankTitle));
            format(msg, sizeof(msg), "Player assigned: %s - %s.", orgName, rankTitle);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
            SendClientMessage(target, COLOR_UI_INFO, "The administrator has assigned you to a position in the organization.");
            AdminPanel_SendAudit(playerid, target, "ADMIN_ORG_SET", 0, orgId, msg);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_PROPERTIES:
        {
            if (!response) { AdminPanel_ShowPlayerActions(playerid); return Y_HOOKS_BREAK_RETURN_1; }
            if (listitem < 0 || listitem >= MAX_ADMIN_PROPERTY_ROWS) return Y_HOOKS_BREAK_RETURN_1;
            new const dbId = sAdminPropertyList[playerid][listitem];
            new const target = sAdminPendingTarget[playerid];
            if (dbId <= 0 || !AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
            if (!AdminPanel_Require(playerid, ADMIN_PERM_PROP_GIVE, "ADMIN_PROP_GIVE")) return Y_HOOKS_BREAK_RETURN_1;
            if (Properties_AdminAssign(dbId, Character_GetId(target)))
            {
                SendClientMessage(playerid, COLOR_UI_SUCCESS, "The property has been issued to the player.");
                SendClientMessage(target, COLOR_UI_INFO, "The administrator has given you the property.");
                AdminPanel_SendAudit(playerid, target, "ADMIN_PROP_GIVE", 0, dbId, "Give property");
            }
            else
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to release property.");
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_SKILLS:
        {
            if (!response) { AdminPanel_ShowPlayerActions(playerid); return Y_HOOKS_BREAK_RETURN_1; }
            if (listitem < 0 || listitem >= TOTAL_SKILL_TYPES) return Y_HOOKS_BREAK_RETURN_1;
            if (!AdminPanel_Require(playerid, ADMIN_PERM_CHAR_SET_SKILLS, "ADMIN_SKILLS")) return Y_HOOKS_BREAK_RETURN_1;
            sAdminPendingSkill[playerid] = listitem;
            sAdminPendingAction[playerid] = _:AI_INPUT_SKILL_VALUE;
            sAdminPendingTarget[playerid] = sAdminTarget[playerid];
            new skillName[SKILL_DISPLAY_NAME_LEN];
            Skills_GetNameRu(E_SKILL_TYPE:listitem, skillName, sizeof(skillName));
            new title[128];
            format(title, sizeof(title), "Skill: %s", skillName);
            ShowPlayerDialog(playerid, DIALOG_ADMIN_INPUT, DIALOG_STYLE_INPUT, title,
                "Enter a new skill value (0-1000):", "Apply", "Cancel");
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_ROLES:
        {
            if (!response) { AdminPanel_ShowMain(playerid); return Y_HOOKS_BREAK_RETURN_1; }
            if (listitem < 0 || listitem > MAX_ADMIN_ROLES) return Y_HOOKS_BREAK_RETURN_1;
            new const roleDb = sAdminRoleList[playerid][listitem];
            if (roleDb <= 0)
            {
                if (!AdminPanel_Require(playerid, ADMIN_PERM_MANAGE_ROLES, "ADMIN_ROLE_CREATE")) return Y_HOOKS_BREAK_RETURN_1;
                ShowPlayerDialog(playerid, DIALOG_ADMIN_ROLE_INPUT, DIALOG_STYLE_INPUT,
                    "Creating an admin role", "Enter the role name and level separated by a vertical bar:\nExample: Moderator|10",
                    "Create", "Cancel");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            sAdminPendingRole[playerid] = roleDb;
            AdminPanel_ShowRoleActions(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_ROLE_ACTIONS:
        {
            if (!response) { AdminPanel_ShowRoles(playerid); return Y_HOOKS_BREAK_RETURN_1; }
            if (listitem < 0 || listitem >= sAdminMenuCount[playerid]) return Y_HOOKS_BREAK_RETURN_1;
            switch (E_ADMIN_ROLE_ACTION:sAdminMenuAction[playerid][listitem])
            {
                case AR_ACTION_NONE: {}
                case AR_PERMISSIONS: AdminPanel_ShowRolePermissions(playerid);
                case AR_DELETE:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_MANAGE_ROLES, "ADMIN_ROLE_DELETE")) return Y_HOOKS_BREAK_RETURN_1;
                    AdminPanel_ShowConfirm(playerid, AC_DELETE_ROLE, "Delete a role", "Delete the selected custom role? All its administrators will lose their rights.");
                }
                case AR_ASSIGN_ONLINE:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_MANAGE_ADMINS, "ADMIN_ROLE_ASSIGN")) return Y_HOOKS_BREAK_RETURN_1;
                    AdminPanel_ShowTargets(playerid, ATM_ROLE_ASSIGN, "Who should I assign the role to?");
                }
                case AR_ASSIGN_OFFLINE:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_MANAGE_ADMINS, "ADMIN_ROLE_ASSIGN")) return Y_HOOKS_BREAK_RETURN_1;
                    ShowPlayerDialog(playerid, DIALOG_ADMIN_ROLE_OFFLINE, DIALOG_STYLE_INPUT,
                        "Assigning a role to an offline account", "Enter your account_id:", "Assign", "Cancel");
                }
                case AR_REMOVE:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_MANAGE_ADMINS, "ADMIN_ROLE_REMOVE")) return Y_HOOKS_BREAK_RETURN_1;
                    AdminPanel_ShowTargets(playerid, ATM_ROLE_REMOVE, "Who should I remove the admin role from?");
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_ROLE_PERMS:
        {
            if (!response) { AdminPanel_ShowRoleActions(playerid); return Y_HOOKS_BREAK_RETURN_1; }
            if (listitem < 0 || listitem >= MAX_ADMIN_PERMISSIONS) return Y_HOOKS_BREAK_RETURN_1;
            new const perm = sAdminPermList[playerid][listitem];
            if (perm <= _:ADMIN_PERM_NONE || perm >= _:ADMIN_PERM_COUNT) return Y_HOOKS_BREAK_RETURN_1;
            new const roleDb = sAdminPendingRole[playerid];
            new const bool:newValue = !Admin_GetRolePermission(roleDb, E_ADMIN_PERM:perm);
            if (Admin_SetRolePermission(playerid, roleDb, E_ADMIN_PERM:perm, newValue))
            {
                AdminPanel_ShowRolePermissions(playerid);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_ROLE_INPUT:
        {
            if (!response) { AdminPanel_ShowRoles(playerid); return Y_HOOKS_BREAK_RETURN_1; }
            new name[MAX_ADMIN_ROLE_NAME], levelStr[16];
            new const sep = strfind(inputtext, "|", true);
            if (sep <= 0)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Format: Title|Level. Example: Moderator|10");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            strmid(name, inputtext, 0, sep, sizeof(name));
            strmid(levelStr, inputtext, sep + 1, strlen(inputtext), sizeof(levelStr));
            new const level = strval(levelStr);
            if (Admin_CreateRole(playerid, name, level) > 0)
            {
                SendClientMessage(playerid, COLOR_UI_SUCCESS, "The admin role has been created.");
                AdminPanel_ShowRoles(playerid);
            }
            else
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to create role: check name, level (1-99) and uniqueness.");
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_ROLE_OFFLINE:
        {
            if (!response) { AdminPanel_ShowRoles(playerid); return Y_HOOKS_BREAK_RETURN_1; }
            new accountId = 0;
            if (!Internal_ParseAccountId(inputtext, accountId))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Invalid account_id.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (Admin_AssignRole(playerid, accountId, sAdminPendingRole[playerid]))
            {
                SendClientMessage(playerid, COLOR_UI_SUCCESS, "The role is assigned to the offline account.");
            }
            else
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to assign role.");
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_CONFIRM:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            switch (sAdminConfirmAction[playerid])
            {
                case AC_ACTION_NONE: {}
                case AC_CLEAR_INVENTORY:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_INV_CLEAR, "ADMIN_INV_CLEAR")) return Y_HOOKS_BREAK_RETURN_1;
                    new const target = sAdminPendingTarget[playerid];
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    Internal_ClearInventory(target);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player's inventory has been cleared.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_INV_CLEAR", 0, 0, "Complete inventory clearing");
                }
                case AC_DELETE_ROLE:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_MANAGE_ROLES, "ADMIN_ROLE_DELETE")) return Y_HOOKS_BREAK_RETURN_1;
                    if (Admin_DeleteRole(playerid, sAdminPendingRole[playerid]))
                    {
                        SendClientMessage(playerid, COLOR_UI_SUCCESS, "The admin role has been removed.");
                    }
                    else
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "This role cannot be deleted.");
                    }
                    AdminPanel_ShowRoles(playerid);
                }
                case AC_CLEAR_PROPERTY:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PROP_REMOVE, "ADMIN_PROP_REMOVE")) return Y_HOOKS_BREAK_RETURN_1;
                    if (Properties_AdminClear(sAdminPendingProperty[playerid]))
                    {
                        SendClientMessage(playerid, COLOR_UI_SUCCESS, "The property has been confiscated into state ownership.");
                        AdminPanel_SendAudit(playerid, playerid, "ADMIN_PROP_REMOVE", 0, sAdminPendingProperty[playerid], "Confiscate property");
                    }
                }
                case AC_RESTART_SERVER:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_SERVER_RESTART, "ADMIN_SERVER_RESTART")) return Y_HOOKS_BREAK_RETURN_1;
                    AdminPanel_SendAudit(playerid, playerid, "ADMIN_SERVER_RESTART", 0, 0, "Restarting the server by the administrator");
                    SendClientMessageToAll(COLOR_UI_WARNING, "The server is restarted by command from the administration.");
                    defer Admin_DelayedRestart();
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_INPUT:
        {
            if (!response) return Y_HOOKS_BREAK_RETURN_1;
            new const target = sAdminPendingTarget[playerid];
            new const E_ADMIN_INPUT_ACTION:action = E_ADMIN_INPUT_ACTION:sAdminPendingAction[playerid];
            new msg[256];

            switch (action)
            {
                case AI_INPUT_NONE: {}
                case AI_INPUT_HP:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SET_STATS, "ADMIN_SET_STATS")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    Character_SetHP(target, floatstr(inputtext));
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Player HP has been updated.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_HP", 0, floatround(floatstr(inputtext)), "Change HP");
                }
                case AI_INPUT_ARMOUR:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SET_STATS, "ADMIN_SET_STATS")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    Character_SetArmour(target, floatstr(inputtext));
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Player armor has been updated.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_ARMOUR", 0, floatround(floatstr(inputtext)), "Changing armor");
                }
                case AI_INPUT_HUNGER:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SET_STATS, "ADMIN_SET_STATS")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    Character_SetHunger(target, floatstr(inputtext));
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Player hunger has been updated.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_HUNGER", 0, floatround(floatstr(inputtext)), "Change in hunger");
                }
                case AI_INPUT_THIRST:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SET_STATS, "ADMIN_SET_STATS")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    Character_SetThirst(target, floatstr(inputtext));
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player's thirst has been updated.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_THIRST", 0, floatround(floatstr(inputtext)), "Change in thirst");
                }
                case AI_INPUT_STAMINA:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SET_STATS, "ADMIN_SET_STATS")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    Character_SetStamina(target, floatstr(inputtext));
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player's stamina has been updated.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_STAMINA", 0, floatround(floatstr(inputtext)), "Changing Stamina");
                }
                case AI_INPUT_STRESS:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SET_STATS, "ADMIN_SET_STATS")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    Character_SetStress(target, floatstr(inputtext));
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Player stress has been updated.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_STRESS", 0, floatround(floatstr(inputtext)), "Change in stress");
                }
                case AI_INPUT_SKIN:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SET_SKIN, "ADMIN_SET_SKIN")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    new const skin = strval(inputtext);
                    if (skin < 1 || skin > 311 || skin == 74)
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "Invalid skin ID.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    Character_AdminSetSkin(target, skin);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player's skin has been changed.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_SKIN", 0, skin, "Change skin");
                }
                case AI_INPUT_BAN_TEMP:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_BAN, "ADMIN_BAN")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    new pos = 0, tok[32], reason[128];
                    Internal_NextToken(inputtext, pos, tok, sizeof(tok));
                    new const minutes = strval(tok);
                    Internal_GetRest(inputtext, pos, reason, sizeof(reason));
                    Admin_BanAccount(playerid, Account_GetId(target), minutes, reason);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "A temporary ban has been issued.");
                }
                case AI_INPUT_BAN_PERM:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_BAN, "ADMIN_BAN")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    Admin_BanAccount(playerid, Account_GetId(target), 0, inputtext);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "A permanent ban has been issued.");
                }
                case AI_INPUT_MUTE:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_MUTE, "ADMIN_MUTE")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    new pos = 0, tok[32], reason[128];
                    Internal_NextToken(inputtext, pos, tok, sizeof(tok));
                    new const minutes = strval(tok);
                    Internal_GetRest(inputtext, pos, reason, sizeof(reason));
                    Admin_Punish(playerid, target, PUNISHMENT_MUTE, reason, minutes * 60);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Mute issued.");
                }
                case AI_INPUT_WARN:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_WARN, "ADMIN_WARN")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    Admin_Punish(playerid, target, PUNISHMENT_WARN, inputtext, 0);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "A warning has been issued.");
                }
                case AI_INPUT_JAIL:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_JAIL, "ADMIN_JAIL")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    new pos = 0, tok[32], reason[128];
                    Internal_NextToken(inputtext, pos, tok, sizeof(tok));
                    new const minutes = strval(tok);
                    Internal_GetRest(inputtext, pos, reason, sizeof(reason));
                    Admin_Punish(playerid, target, PUNISHMENT_DEMORGAN, reason, minutes * 60);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player was sent to the holding cell.");
                }
                case AI_INPUT_WANTED:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SET_WANTED, "ADMIN_WANTED")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    new const level = strval(inputtext);
                    if (level < 0 || level > 100) { SendClientMessage(playerid, COLOR_UI_ERROR, "Range: 0-100."); return Y_HOOKS_BREAK_RETURN_1; }
                    Justice_SetWantedLevel(target, level, "Administrative change in search", Character_GetId(playerid));
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Wanted level updated.");
                }
                case AI_INPUT_LEVEL:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_CHAR_SET_LEVEL, "ADMIN_LEVEL")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    new const level = strval(inputtext);
                    Character_SetLevel(target, level);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Character level has been updated.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_LEVEL", 0, level, "Level change");
                }
                case AI_INPUT_EXP:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_CHAR_SET_EXP, "ADMIN_EXP")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    new const exp = strval(inputtext);
                    Character_SetExpSeconds(target, exp);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Character experience has been updated.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_EXP", 0, exp, "Changing Experience");
                }
                case AI_INPUT_CASH:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_ECON_GIVE_CASH, "ADMIN_CASH")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    new const amount = strval(inputtext);
                    new bool:ok = false;
                    if (amount >= 0) ok = Character_AddPhysicalCashUsd(target, amount);
                    else ok = Character_RemovePhysicalCashUsd(target, -amount);
                    if (ok)
                    {
                        format(msg, sizeof(msg), "Cash %s: %d USD.", (amount >= 0) ? ("issued") : ("confiscated"), (amount >= 0) ? amount : -amount);
                        SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
                        AdminPanel_SendAudit(playerid, target, "ADMIN_CASH", 0, amount, msg);
                    }
                    else SendClientMessage(playerid, COLOR_UI_ERROR, "Operation failed: check inventory space or amount.");
                }
                case AI_INPUT_BANK:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_ECON_SET_BANK, "ADMIN_BANK")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    if (!Character_HasBankAccount(target)) { SendClientMessage(playerid, COLOR_UI_ERROR, "The player does not have a bank account."); return Y_HOOKS_BREAK_RETURN_1; }
                    new const amount = strval(inputtext);
                    if (amount < 0) { SendClientMessage(playerid, COLOR_UI_ERROR, "The amount cannot be negative."); return Y_HOOKS_BREAK_RETURN_1; }
                    Character_SetBankBalanceUsd(target, amount);
                    if (DB_IsConnected())
                    {
                        new query[256];
                        mysql_format(gMySQL, query, sizeof(query),
                            "UPDATE `bank_accounts` SET `balance_usd` = %d WHERE `owner_char_id` = %d;",
                            amount, Character_GetId(target));
                        mysql_tquery(gMySQL, query);
                    }
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Bank balance updated.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_BANK", 0, amount, "Setting up a bank balance");
                }
                case AI_INPUT_DEBT:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_ECON_ISSUE_DEBT, "ADMIN_DEBT")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    new const amount = strval(inputtext);
                    if (amount < 0) { SendClientMessage(playerid, COLOR_UI_ERROR, "The amount cannot be negative."); return Y_HOOKS_BREAK_RETURN_1; }
                    Character_SetBankDebtUsd(target, amount);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Bank debt updated.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_DEBT", 0, amount, "Setting up bank debt");
                }
                case AI_INPUT_VEH_MODEL:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_SPAWN, "ADMIN_VEH_SPAWN")) return Y_HOOKS_BREAK_RETURN_1;
                    new const target2 = (sAdminPendingTarget[playerid] > 0) ? sAdminPendingTarget[playerid] : playerid;
                    if (!AdminPanel_ValidTarget(playerid, target2)) return Y_HOOKS_BREAK_RETURN_1;
                    new const model = strval(inputtext);
                    if (model < 400 || model > 611) { SendClientMessage(playerid, COLOR_UI_ERROR, "The model should be in the range 400-611."); return Y_HOOKS_BREAK_RETURN_1; }
                    new slot = Vehicle_CreateForPlayer(target2, model, 0, false);
                    if (slot < 0) { SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to spawn the vehicle."); return Y_HOOKS_BREAK_RETURN_1; }
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The vehicle has been spawned, the keys have been given to the player.");
                    AdminPanel_SendAudit(playerid, target2, "ADMIN_VEH_SPAWN", 0, model, "Vehicle spawn");
                }
                case AI_INPUT_WEATHER:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_WORLD_WEATHER, "ADMIN_WEATHER")) return Y_HOOKS_BREAK_RETURN_1;
                    new const weather = strval(inputtext);
                    if (weather < 0 || weather > 20) { SendClientMessage(playerid, COLOR_UI_ERROR, "Weather ID: 0-20."); return Y_HOOKS_BREAK_RETURN_1; }
                    SetWeather(weather);
                    format(msg, sizeof(msg), "Weather changed: %d.", weather);
                    SendClientMessageToAll(COLOR_UI_INFO, msg);
                    AdminPanel_SendAudit(playerid, playerid, "ADMIN_WEATHER", 0, weather, msg);
                }
                case AI_INPUT_TIME:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_WORLD_TIME, "ADMIN_TIME")) return Y_HOOKS_BREAK_RETURN_1;
                    new const hour = strval(inputtext);
                    if (hour < 0 || hour > 23) { SendClientMessage(playerid, COLOR_UI_ERROR, "Hour: 0-23."); return Y_HOOKS_BREAK_RETURN_1; }
                    SetWorldTime(hour);
                    format(msg, sizeof(msg), "Time of day changed: %02d:00.", hour);
                    SendClientMessageToAll(COLOR_UI_INFO, msg);
                    AdminPanel_SendAudit(playerid, playerid, "ADMIN_TIME", 0, hour, msg);
                }
                case AI_INPUT_ANNOUNCE:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_WORLD_ANNOUNCE, "ADMIN_ANNOUNCE")) return Y_HOOKS_BREAK_RETURN_1;
                    format(msg, sizeof(msg), "[Staff announcement] %s", inputtext);
                    SendClientMessageToAll(COLOR_SERVER_GOLD, msg);
                    AdminPanel_SendAudit(playerid, playerid, "ADMIN_ANNOUNCE", 0, 0, inputtext);
                }
                case AI_INPUT_TP:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_WORLD_TELEPORT, "ADMIN_WORLD_TP")) return Y_HOOKS_BREAK_RETURN_1;
                    new Float:x, Float:y, Float:z;
                    if (!Utils_ParseCoords(inputtext, x, y, z)) { SendClientMessage(playerid, COLOR_UI_ERROR, "Format: X Y Z. Example: 1481.0 -1771.0 18.8"); return Y_HOOKS_BREAK_RETURN_1; }
                    Utils_SetPlayerPos(playerid, x, y, z);
                    AC_MarkServerTeleport(playerid, 3000);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Teleport completed.");
                    AdminPanel_SendAudit(playerid, playerid, "ADMIN_WORLD_TP", 0, 0, inputtext);
                }
                case AI_INPUT_ROLE_OFFLINE:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_MANAGE_ADMINS, "ADMIN_ROLE_ASSIGN")) return Y_HOOKS_BREAK_RETURN_1;
                    new accountId = 0;
                    if (!Internal_ParseAccountId(inputtext, accountId)) { SendClientMessage(playerid, COLOR_UI_ERROR, "Invalid account_id."); return Y_HOOKS_BREAK_RETURN_1; }
                    if (Admin_AssignRole(playerid, accountId, sAdminPendingRole[playerid])) SendClientMessage(playerid, COLOR_UI_SUCCESS, "The role has been assigned.");
                    else SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to assign role.");
                }
                case AI_INPUT_SKILL_VALUE:
                {
                    if (!AdminPanel_Require(playerid, ADMIN_PERM_CHAR_SET_SKILLS, "ADMIN_SKILLS")) return Y_HOOKS_BREAK_RETURN_1;
                    if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;
                    new const value = strval(inputtext);
                    if (value < 0 || value > 1000) { SendClientMessage(playerid, COLOR_UI_ERROR, "Skill: 0-1000."); return Y_HOOKS_BREAK_RETURN_1; }
                    new const skill = sAdminPendingSkill[playerid];
                    Skills_Set(target, E_SKILL_TYPE:skill, value, true);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Skill updated.");
                    AdminPanel_SendAudit(playerid, target, "ADMIN_SKILLS", 0, value, "Change skill");
                    AdminPanel_ShowSkills(playerid);
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_ITEM_INPUT:
        {
            if (!response) return Y_HOOKS_BREAK_RETURN_1;
            if (!AdminPanel_Require(playerid, ADMIN_PERM_INV_GIVE_ITEM, "ADMIN_INV_GIVE")) return Y_HOOKS_BREAK_RETURN_1;
            new const target = sAdminPendingTarget[playerid];
            if (!AdminPanel_ValidTarget(playerid, target)) return Y_HOOKS_BREAK_RETURN_1;

            new pos = 0, tok[64];
            new itemId, amount, ammo, meta1, meta2;
            new Float:durability;
            new metaStr[STORAGE_ITEM_META_STR_LEN];

            Internal_NextToken(inputtext, pos, tok, sizeof(tok)); itemId = strval(tok);
            Internal_NextToken(inputtext, pos, tok, sizeof(tok)); amount = strval(tok);
            Internal_NextToken(inputtext, pos, tok, sizeof(tok)); durability = floatstr(tok);
            Internal_NextToken(inputtext, pos, tok, sizeof(tok)); ammo = strval(tok);
            Internal_NextToken(inputtext, pos, tok, sizeof(tok)); meta1 = strval(tok);
            Internal_NextToken(inputtext, pos, tok, sizeof(tok)); meta2 = strval(tok);
            Internal_GetRest(inputtext, pos, metaStr, sizeof(metaStr));

            if (!Item_IsValid(itemId) || amount <= 0)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Invalid item_def_id or quantity.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (durability <= 0.0 || durability > 100.0) durability = 100.0;

            new outSlot = INVALID_STORAGE_ITEM_SLOT;
            new const E_STORAGE_RESULT:result = Storage_AddItem(
                Character_GetLayer1Slot(target), itemId, amount, ammo, durability, meta1, meta2, metaStr, outSlot);
            if (result != STORAGE_RES_OK)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to issue item: inventory is full or limits have been exceeded.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new itemName[64];
            Item_GetName(itemId, itemName, sizeof(itemName));
            new details[192];
            format(details, sizeof(details), "Issue of item %s x%d", itemName, amount);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, details);
            AdminPanel_SendAudit(playerid, target, "ADMIN_GIVE_ITEM", itemId, amount, details);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_AUDIT, DIALOG_ADMIN_ANTICHEAT, DIALOG_ADMIN_HELP:
        {
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return 1;
}
// =============================================================================
//  10. HUD-“¿…Ã≈–,  À» » » ’” »
// =============================================================================

task AdminSpectateUpdate[1000]()
{
    foreach (new playerid : Player)
    {
        if (sAdminSpectating[playerid])
        {
            AdminPanel_UpdateSpectateHud(playerid);
        }
    }
}

hook OnPlayerClickPlayerTextDraw(playerid, PlayerText:playertextid)
{
    if (!sAdminSpectating[playerid])
    {
        return 1;
    }
    new const target = sAdminSpectateTarget[playerid];
    if (!AdminPanel_ValidTarget(playerid, target))
    {
        AdminPanel_StopSpectate(playerid, true);
        return 1;
    }

    if (playertextid == sAdminHudFreeze[playerid])
    {
        if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_FREEZE, "ADMIN_FREEZE")) return 1;
        sAdminFrozen[target] = !sAdminFrozen[target];
        TogglePlayerControllable(target, !sAdminFrozen[target]);
        AdminPanel_SendAudit(playerid, target, "ADMIN_FREEZE", 0, sAdminFrozen[target] ? 1 : 0, "Freeze HUD button");
        return 1;
    }
    if (playertextid == sAdminHudSlap[playerid])
    {
        if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SLAP, "ADMIN_SLAP")) return 1;
        new Float:hp;
        GetPlayerHealth(target, hp);
        SetPlayerHealth(target, (hp > 5.0) ? (hp - 5.0) : 1.0);
        SetPlayerVelocity(target, 0.0, 0.0, 6.0);
        AdminPanel_SendAudit(playerid, target, "ADMIN_SLAP", 0, 5, "Slap HUD button");
        return 1;
    }
    if (playertextid == sAdminHudKick[playerid])
    {
        if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_KICK, "ADMIN_KICK")) return 1;
        AdminPanel_SendAudit(playerid, target, "ADMIN_KICK", 0, 0, "HUD kick button");
        AdminPanel_StopSpectate(playerid, false);
        defer Admin_DelayedKick(target, Config_GetPlayerSessionToken(target));
        SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player has been kicked.");
        return 1;
    }
    if (playertextid == sAdminHudClose[playerid])
    {
        AdminPanel_StopSpectate(playerid, true);
        return 1;
    }
    return 1;
}

hook OnPlayerConnect(playerid)
{
    sAdminMenuCount[playerid] = 0;
    sAdminTarget[playerid] = INVALID_PLAYER_ID;
    sAdminTargetMode[playerid] = ATM_NONE;
    sAdminPendingAction[playerid] = 0;
    sAdminPendingTarget[playerid] = INVALID_PLAYER_ID;
    sAdminPendingRole[playerid] = 0;
    sAdminPendingOrg[playerid] = 0;
    sAdminPendingProperty[playerid] = 0;
    sAdminPendingSkill[playerid] = 0;
    sAdminConfirmAction[playerid] = AC_ACTION_NONE;
    sAdminSpectating[playerid] = false;
    sAdminSpectateTarget[playerid] = INVALID_PLAYER_ID;
    sAdminFrozen[playerid] = false;
    sAdminLastCommandTick[playerid] = 0;
    AdminPanel_CreateSpectateHud(playerid);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    if (sAdminSpectating[playerid])
    {
        AdminPanel_StopSpectate(playerid, false);
    }
    AdminPanel_DestroySpectateHud(playerid);
    sAdminTarget[playerid] = INVALID_PLAYER_ID;
    sAdminSpectateTarget[playerid] = INVALID_PLAYER_ID;
    sAdminFrozen[playerid] = false;
    return 1;
}

hook OnPlayerSpawn(playerid)
{
    sAdminFrozen[playerid] = false;
    TogglePlayerControllable(playerid, true);
    if (sAdminSpectating[playerid])
    {
        AdminPanel_StopSpectate(playerid, false);
    }
    return 1;
}

// =============================================================================
//  11.  ŒÃ¿Õƒ€ ¿ƒÃ»Õ»—“–¿÷»» (Pawn.CMD)
// =============================================================================

stock bool:AdminPanel_TryOpenSkillsEditor(playerid, const params[])
{
    if (!Admin_HasPermission(playerid, ADMIN_PERM_CHAR_SET_SKILLS))
    {
        return false;
    }
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok)))
    {
        return false;
    }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target))
    {
        return false;
    }
    sAdminTarget[playerid] = target;
    AdminPanel_ShowSkills(playerid);
    return true;
}

CMD:apanel(playerid, params[])
{
    #pragma unused params
    if (!Internal_CommandCooldown(playerid)) return 1;
    AdminPanel_ShowMain(playerid);
    return 1;
}

CMD:ahelp(playerid, params[])
{
    #pragma unused params
    if (!Internal_CommandCooldown(playerid)) return 1;
    AdminPanel_ShowHelp(playerid);
    return 1;
}
alias:ahelp("ah");

CMD:goto(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_TELEPORT, "ADMIN_GOTO")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /goto [id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;

    new Float:x, Float:y, Float:z;
    GetPlayerPos(target, x, y, z);
    SetPlayerInterior(playerid, GetPlayerInterior(target));
    SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(target));
    Utils_SetPlayerPos(playerid, x + 1.0, y + 1.0, z);
    SetCameraBehindPlayer(playerid);
    AC_MarkServerTeleport(playerid, 3000);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Teleport to the player is completed.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_GOTO", 0, 0, "Teleport to player");
    return 1;
}

alias:goto("tp");

CMD:gethere(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_GET_HERE, "ADMIN_GETHERE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /gethere [id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    SetPlayerInterior(target, GetPlayerInterior(playerid));
    SetPlayerVirtualWorld(target, GetPlayerVirtualWorld(playerid));
    Utils_SetPlayerPos(target, x + 1.0, y + 1.0, z);
    AC_MarkServerTeleport(target, 3000);
    SendClientMessage(target, COLOR_UI_INFO, "The administrator teleported you to his place.");
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player is teleported to you.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_GETHERE", 0, 0, "Teleport player to administrator");
    return 1;
}

CMD:sp(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SPECTATE, "ADMIN_SPECTATE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /sp [id]"); return 1; }
    AdminPanel_StartSpectate(playerid, strval(tok));
    return 1;
}

alias:sp("re", "recon");

CMD:freeze(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_FREEZE, "ADMIN_FREEZE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /freeze [id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    sAdminFrozen[target] = true;
    TogglePlayerControllable(target, false);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player is frozen.");
    SendClientMessage(target, COLOR_UI_WARNING, "The administrator has frozen you.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_FREEZE", 0, 1, "Freezing a player");
    return 1;
}

CMD:unfreeze(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_FREEZE, "ADMIN_FREEZE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /unfreeze [id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    sAdminFrozen[target] = false;
    TogglePlayerControllable(target, true);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player is unfrozen.");
    SendClientMessage(target, COLOR_UI_INFO, "The administrator has unfrozen you.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_UNFREEZE", 0, 0, "Unfreezing a player");
    return 1;
}

CMD:slap(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SLAP, "ADMIN_SLAP")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /slap [id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    new Float:hp;
    GetPlayerHealth(target, hp);
    SetPlayerHealth(target, (hp > 5.0) ? (hp - 5.0) : 1.0);
    SetPlayerVelocity(target, 0.0, 0.0, 6.0);
    SendClientMessage(target, COLOR_UI_WARNING, "The administrator slapped you.");
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The slap is completed.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_SLAP", 0, 5, "Player slap");
    return 1;
}

CMD:setstat(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SET_STATS, "ADMIN_SET_STATS")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[32];
    new target, Float:value;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setstat [id] [hp|armour|hunger|thirst|stamina|stress] [value]"); return 1; }
    target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    new stat[24];
    if (!Internal_NextToken(params, pos, stat, sizeof(stat))) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    value = floatstr(tok);

    if (!strcmp(stat, "hp", true)) Character_SetHP(target, value);
    else if (!strcmp(stat, "armour", true)) Character_SetArmour(target, value);
    else if (!strcmp(stat, "hunger", true)) Character_SetHunger(target, value);
    else if (!strcmp(stat, "thirst", true)) Character_SetThirst(target, value);
    else if (!strcmp(stat, "stamina", true)) Character_SetStamina(target, value);
    else if (!strcmp(stat, "stress", true)) Character_SetStress(target, value);
    else { SendClientMessage(playerid, COLOR_UI_ERROR, "Unknown parameter. Available: hp, armor, hunger, thirst, stamina, stress."); return 1; }

    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Player stat has been updated.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_STATS", 0, floatround(value), stat);
    return 1;
}

CMD:setskin(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SET_SKIN, "ADMIN_SET_SKIN")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setskin [id] [skin]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const skin = strval(tok);
    if (skin < 1 || skin > 311 || skin == 74) { SendClientMessage(playerid, COLOR_UI_ERROR, "Invalid skin ID."); return 1; }
    Character_AdminSetSkin(target, skin);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player's skin has been changed.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_SKIN", 0, skin, "Change skin");
    return 1;
}

CMD:kick(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_KICK, "ADMIN_KICK")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24], reason[128];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /kick [id] [reason]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    Internal_GetRest(params, pos, reason, sizeof(reason));
    if (reason[0] == EOS) format(reason, sizeof(reason), "Violation of server rules");
    new msg[192];
    format(msg, sizeof(msg), "You have been kicked by an administrator. Reason: %s", reason);
    SendClientMessage(target, COLOR_UI_ERROR, msg);
    AdminPanel_SendAudit(playerid, target, "ADMIN_KICK", 0, 0, reason);
    defer Admin_DelayedKick(target, Config_GetPlayerSessionToken(target));
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player has been kicked.");
    return 1;
}

CMD:quietkick(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_KICK, "ADMIN_QUIETKICK")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /quietkick [id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    AdminPanel_SendAudit(playerid, target, "ADMIN_QUIETKICK", 0, 0, "Quiet kick");
    defer Admin_DelayedKick(target, Config_GetPlayerSessionToken(target));
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Player kicked without notice.");
    return 1;
}

CMD:ban(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_BAN, "ADMIN_BAN")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[32], reason[128];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /ban [id] [minutes] [reason] (0 = forever)"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const minutes = strval(tok);
    Internal_GetRest(params, pos, reason, sizeof(reason));
    if (reason[0] == EOS) format(reason, sizeof(reason), "Violation of server rules");
    Admin_BanAccount(playerid, Account_GetId(target), minutes, reason);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, (minutes > 0) ? "A temporary ban has been issued." : "A permanent ban has been issued.");
    return 1;
}

CMD:banoff(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_BAN, "ADMIN_BAN_OFFLINE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, field[16], value[64], tok[32], reason[128];
    if (!Internal_NextToken(params, pos, field, sizeof(field))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /banoff nick|ip|hwid [value] [minutes] [reason]"); return 1; }
    if (!Internal_NextToken(params, pos, value, sizeof(value))) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const minutes = strval(tok);
    Internal_GetRest(params, pos, reason, sizeof(reason));
    if (reason[0] == EOS) format(reason, sizeof(reason), "Violation of server rules");
    if (!Admin_BanOffline(playerid, field, value, minutes, reason)) { SendClientMessage(playerid, COLOR_UI_ERROR, "Invalid field. Available: nick, ip, hwid."); return 1; }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Offline ban applied.");
    return 1;
}

CMD:unban(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_UNBAN, "ADMIN_UNBAN")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[64];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /unban [account_id|nickname]"); return 1; }
    new const accountId = strval(tok);
    if (accountId > 0) Admin_UnbanAccount(playerid, accountId);
    else if (!Admin_UnbanByUsername(playerid, tok)) { SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to unban account."); return 1; }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The account is unbanned.");
    return 1;
}

CMD:mute(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_MUTE, "ADMIN_MUTE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[32], reason[128];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /mute [id] [minutes] [reason]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const minutes = strval(tok);
    Internal_GetRest(params, pos, reason, sizeof(reason));
    if (reason[0] == EOS) format(reason, sizeof(reason), "Violation of chat rules");
    Admin_Punish(playerid, target, PUNISHMENT_MUTE, reason, minutes * 60);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Mute issued.");
    return 1;
}

CMD:warn(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_WARN, "ADMIN_WARN")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24], reason[128];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /warn [id] [reason]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    Internal_GetRest(params, pos, reason, sizeof(reason));
    if (reason[0] == EOS) format(reason, sizeof(reason), "Violation of server rules");
    Admin_Punish(playerid, target, PUNISHMENT_WARN, reason, 0);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "A warning has been issued.");
    return 1;
}

CMD:jail(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_JAIL, "ADMIN_JAIL")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[32], reason[128];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /jail [id] [minutes] [reason]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const minutes = strval(tok);
    Internal_GetRest(params, pos, reason, sizeof(reason));
    if (reason[0] == EOS) format(reason, sizeof(reason), "Violation of server rules");
    Admin_Punish(playerid, target, PUNISHMENT_DEMORGAN, reason, minutes * 60);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player was sent to the holding cell.");
    return 1;
}

CMD:setwanted(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SET_WANTED, "ADMIN_WANTED")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setwanted [id] [0-100]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const level = strval(tok);
    if (level < 0 || level > 100) { SendClientMessage(playerid, COLOR_UI_ERROR, "Range: 0-100."); return 1; }
    Justice_SetWantedLevel(target, level, "Administrative change in search", Character_GetId(playerid));
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Wanted level updated.");
    return 1;
}

CMD:setlevel(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_CHAR_SET_LEVEL, "ADMIN_LEVEL")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setlevel [id] [level]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const level = strval(tok);
    Character_SetLevel(target, level);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Character level has been updated.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_LEVEL", 0, level, "Level change");
    return 1;
}

CMD:setexp(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_CHAR_SET_EXP, "ADMIN_EXP")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setexp [id] [seconds]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const exp = strval(tok);
    Character_SetExpSeconds(target, exp);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Character experience has been updated.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_EXP", 0, exp, "Changing Experience");
    return 1;
}

CMD:setlicenses(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_CHAR_SET_LICENSES, "ADMIN_LICENSES")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setlicenses [id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    new const bool:banned = Character_IsWeaponLicenseBanned(target);
    Character_SetWeaponLicenseBanned(target, !banned);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, banned ? "The license has been restored." : "The license has been revoked.");
    SendClientMessage(target, COLOR_UI_INFO, banned ? "Your gun license has been reinstated." : "Your gun license has been seized by the administrator.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_LICENSE", 0, banned ? 1 : 0, "Change of weapon license");
    return 1;
}

CMD:setcash(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_ECON_GIVE_CASH, "ADMIN_CASH")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setcash [id] [amount]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const amount = strval(tok);
    new bool:ok;
    if (amount >= 0) ok = Character_AddPhysicalCashUsd(target, amount);
    else ok = Character_RemovePhysicalCashUsd(target, -amount);
    if (!ok) { SendClientMessage(playerid, COLOR_UI_ERROR, "The operation was not completed."); return 1; }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, (amount >= 0) ? "Cash has been issued." : "Cash was seized.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_CASH", 0, amount, "Cash change");
    return 1;
}

CMD:setbank(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_ECON_SET_BANK, "ADMIN_BANK")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setbank [id] [amount]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Character_HasBankAccount(target)) { SendClientMessage(playerid, COLOR_UI_ERROR, "The player does not have a bank account."); return 1; }
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const amount = strval(tok);
    if (amount < 0) { SendClientMessage(playerid, COLOR_UI_ERROR, "The amount cannot be negative."); return 1; }
    Character_SetBankBalanceUsd(target, amount);
    if (DB_IsConnected())
    {
        new query[256];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `bank_accounts` SET `balance_usd` = %d WHERE `owner_char_id` = %d;",
            amount, Character_GetId(target));
        mysql_tquery(gMySQL, query);
    }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Bank balance updated.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_BANK", 0, amount, "Setting up a bank balance");
    return 1;
}

CMD:setdebt(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_ECON_ISSUE_DEBT, "ADMIN_DEBT")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setdebt [id] [amount]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const amount = strval(tok);
    if (amount < 0) { SendClientMessage(playerid, COLOR_UI_ERROR, "The amount cannot be negative."); return 1; }
    Character_SetBankDebtUsd(target, amount);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Bank debt updated.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_DEBT", 0, amount, "Setting up bank debt");
    return 1;
}

CMD:setleader(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_ORG_SET_LEADER, "ADMIN_ORG_LEADER")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setleader [id] [org_id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const orgId = strval(tok);
    if (!Organizations_IsValid(orgId)) { SendClientMessage(playerid, COLOR_UI_ERROR, "Organization not found."); return 1; }

    new bestRank = 0, bestOrder = -1;
    for (new r = 0; r < Organizations_GetRankCount(orgId); r++)
    {
        if (Organizations_GetRankOrder(orgId, r) > bestOrder)
        {
            bestOrder = Organizations_GetRankOrder(orgId, r);
            bestRank = r;
        }
    }
    new const rankDb = Organizations_GetRankDbId(orgId, bestRank);
    if (!Organizations_GrantMembership(target, orgId, rankDb)) { SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to assign leader."); return 1; }
    new orgName[ORG_NAME_LEN], rankTitle[ORG_RANK_TITLE_LEN], msg[256];
    Organizations_GetName(orgId, orgName, sizeof(orgName));
    Organizations_GetRankTitle(orgId, bestRank, rankTitle, sizeof(rankTitle));
    format(msg, sizeof(msg), "The player is designated as the leader: %s (%s).", orgName, rankTitle);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    SendClientMessage(target, COLOR_UI_INFO, "The administrator has appointed you as the leader of the organization.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_ORG_LEADER", 0, orgId, msg);
    return 1;
}

CMD:setfrac(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_ORG_SET_MEMBER, "ADMIN_ORG_MEMBER")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setfrac [id] [org_id] [rank]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const orgId = strval(tok);
    if (!Organizations_IsValid(orgId)) { SendClientMessage(playerid, COLOR_UI_ERROR, "Organization not found."); return 1; }
    new rankIndex = 0;
    if (Internal_NextToken(params, pos, tok, sizeof(tok))) rankIndex = strval(tok);
    if (rankIndex < 0 || rankIndex >= Organizations_GetRankCount(orgId)) { SendClientMessage(playerid, COLOR_UI_ERROR, "Invalid rank index."); return 1; }
    new const rankDb = Organizations_GetRankDbId(orgId, rankIndex);
    if (!Organizations_GrantMembership(target, orgId, rankDb)) { SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to assign player."); return 1; }
    new orgName[ORG_NAME_LEN], rankTitle[ORG_RANK_TITLE_LEN], msg[256];
    Organizations_GetName(orgId, orgName, sizeof(orgName));
    Organizations_GetRankTitle(orgId, rankIndex, rankTitle, sizeof(rankTitle));
    format(msg, sizeof(msg), "Player assigned: %s - %s.", orgName, rankTitle);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    SendClientMessage(target, COLOR_UI_INFO, "The administrator has assigned you to a position in the organization.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_ORG_SET", 0, orgId, msg);
    return 1;
}

CMD:setinv(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_INV_VIEW, "ADMIN_INV_VIEW")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setinv [id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    Dialogs_OpenSearchTarget(playerid, target, true, true);
    AdminPanel_SendAudit(playerid, target, "ADMIN_INV_VIEW", 0, 0, "Opening a player's inventory");
    return 1;
}

CMD:giveitem(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_INV_GIVE_ITEM, "ADMIN_INV_GIVE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[48];
    new target, itemId, amount, ammo, meta1, meta2;
    new Float:durability;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /giveitem [id] [item_id] [quantity] [durability] [ammo] [meta1] [meta2]"); return 1; }
    target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    Internal_NextToken(params, pos, tok, sizeof(tok)); itemId = strval(tok);
    Internal_NextToken(params, pos, tok, sizeof(tok)); amount = strval(tok);
    Internal_NextToken(params, pos, tok, sizeof(tok)); durability = floatstr(tok);
    Internal_NextToken(params, pos, tok, sizeof(tok)); ammo = strval(tok);
    Internal_NextToken(params, pos, tok, sizeof(tok)); meta1 = strval(tok);
    Internal_NextToken(params, pos, tok, sizeof(tok)); meta2 = strval(tok);

    if (!Item_IsValid(itemId) || amount <= 0) { SendClientMessage(playerid, COLOR_UI_ERROR, "Invalid item_def_id or quantity."); return 1; }
    if (durability <= 0.0 || durability > 100.0) durability = 100.0;

    new outSlot = INVALID_STORAGE_ITEM_SLOT;
    new const E_STORAGE_RESULT:result = Storage_AddItem(
        Character_GetLayer1Slot(target), itemId, amount, ammo, durability, meta1, meta2, "", outSlot);
    if (result != STORAGE_RES_OK) { SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to issue item."); return 1; }

    new itemName[64], details[192];
    Item_GetName(itemId, itemName, sizeof(itemName));
    format(details, sizeof(details), "Issue of item %s x%d", itemName, amount);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, details);
    AdminPanel_SendAudit(playerid, target, "ADMIN_GIVE_ITEM", itemId, amount, details);
    return 1;
}

CMD:clearinv(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_INV_CLEAR, "ADMIN_INV_CLEAR")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /clearinv [id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    Internal_ClearInventory(target);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player's inventory has been cleared.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_INV_CLEAR", 0, 0, "Complete inventory clearing");
    return 1;
}

CMD:veh(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_SPAWN, "ADMIN_VEH_SPAWN")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /veh [model] [id?]"); return 1; }
    new const model = strval(tok);
    if (model < 400 || model > 611) { SendClientMessage(playerid, COLOR_UI_ERROR, "The model should be in the range 400-611."); return 1; }
    new target = playerid;
    if (Internal_NextToken(params, pos, tok, sizeof(tok)))
    {
        target = strval(tok);
        if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    }
    new slot = Vehicle_CreateForPlayer(target, model, 0, false);
    if (slot < 0) { SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to spawn the vehicle."); return 1; }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The vehicle has been spawned, the keys have been issued.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_VEH_SPAWN", 0, model, "Vehicle spawn");
    return 1;
}

CMD:vehkeys(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_KEYS, "ADMIN_VEH_KEYS")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    new target = playerid;
    if (Internal_NextToken(params, pos, tok, sizeof(tok)))
    {
        target = strval(tok);
        if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    }
    new slot = Vehicle_AdminGetNearestSlot(target, 12.0);
    if (slot < 0) { SendClientMessage(playerid, COLOR_UI_ERROR, "There is no vehicle near the player."); return 1; }
    if (!Vehicle_AdminIssueKey(target, slot)) { SendClientMessage(playerid, COLOR_UI_ERROR, "The player's inventory is full."); return 1; }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The keys to the vehicle have been issued.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_VEH_KEYS", 0, Vehicle_GetDbId(slot), "Issuing keys");
    return 1;
}

CMD:vfuel(playerid, params[])
{
    #pragma unused params
    if (!Internal_CommandCooldown(playerid)) return 1;
    AdminPanel_ApplyVehicleNearest(playerid, AV_REFUEL);
    return 1;
}

CMD:vfix(playerid, params[])
{
    #pragma unused params
    if (!Internal_CommandCooldown(playerid)) return 1;
    AdminPanel_ApplyVehicleNearest(playerid, AV_REPAIR);
    return 1;
}

CMD:vflip(playerid, params[])
{
    #pragma unused params
    if (!Internal_CommandCooldown(playerid)) return 1;
    AdminPanel_ApplyVehicleNearest(playerid, AV_FLIP);
    return 1;
}

CMD:vehdespawn(playerid, params[])
{
    #pragma unused params
    if (!Internal_CommandCooldown(playerid)) return 1;
    AdminPanel_ApplyVehicleNearest(playerid, AV_DESPAWN);
    return 1;
}

CMD:vehrespawn(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_VEH_DELETE, "ADMIN_VEH_RESPAWN")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    new slot = -1;
    if (Internal_NextToken(params, pos, tok, sizeof(tok)))
    {
        new const dbId = strval(tok);
        if (dbId > 0) slot = Vehicle_FindSlotByDbId(dbId);
    }
    if (slot < 0) slot = Vehicle_AdminGetNearestSlot(playerid, 12.0);
    if (slot < 0) { SendClientMessage(playerid, COLOR_UI_ERROR, "Vehicle not found. Specify /vehrespawn [db_id]."); return 1; }
    Vehicle_AdminRespawn(slot);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The vehicle has been returned to the spawn point.");
    AdminPanel_SendAudit(playerid, playerid, "ADMIN_VEH_RESPAWN", 0, Vehicle_GetDbId(slot), "Vehicle respawn");
    return 1;
}

CMD:vehtp(playerid, params[])
{
    #pragma unused params
    if (!Internal_CommandCooldown(playerid)) return 1;
    AdminPanel_ApplyVehicleNearest(playerid, AV_TELEPORT);
    return 1;
}

CMD:weather(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_WORLD_WEATHER, "ADMIN_WEATHER")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[16];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /weather [0-20]"); return 1; }
    new const weather = strval(tok);
    if (weather < 0 || weather > 20) { SendClientMessage(playerid, COLOR_UI_ERROR, "Weather ID: 0-20."); return 1; }
    SetWeather(weather);
    new msg[128];
    format(msg, sizeof(msg), "The weather was changed by the administrator: %d.", weather);
    SendClientMessageToAll(COLOR_UI_INFO, msg);
    AdminPanel_SendAudit(playerid, playerid, "ADMIN_WEATHER", 0, weather, msg);
    return 1;
}

CMD:time(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_WORLD_TIME, "ADMIN_TIME")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[16];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /time [0-23]"); return 1; }
    new const hour = strval(tok);
    if (hour < 0 || hour > 23) { SendClientMessage(playerid, COLOR_UI_ERROR, "Hour: 0-23."); return 1; }
    SetWorldTime(hour);
    new msg[128];
    format(msg, sizeof(msg), "The time of day was changed by the administrator: %02d:00.", hour);
    SendClientMessageToAll(COLOR_UI_INFO, msg);
    AdminPanel_SendAudit(playerid, playerid, "ADMIN_TIME", 0, hour, msg);
    return 1;
}

CMD:ao(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_WORLD_ANNOUNCE, "ADMIN_ANNOUNCE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    if (params[0] == EOS) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /ao [text]"); return 1; }
    new msg[256];
    format(msg, sizeof(msg), "[Staff announcement] %s", params);
    SendClientMessageToAll(COLOR_SERVER_GOLD, msg);
    AdminPanel_SendAudit(playerid, playerid, "ADMIN_ANNOUNCE", 0, 0, params);
    return 1;
}

CMD:atp(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_WORLD_TELEPORT, "ADMIN_WORLD_TP")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new Float:x, Float:y, Float:z;
    if (!Utils_ParseCoords(params, x, y, z)) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /atp [x] [y] [z]"); return 1; }
    Utils_SetPlayerPos(playerid, x, y, z);
    AC_MarkServerTeleport(playerid, 3000);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Teleport to coordinates completed.");
    AdminPanel_SendAudit(playerid, playerid, "ADMIN_WORLD_TP", 0, 0, params);
    return 1;
}

CMD:alog(playerid, params[])
{
    #pragma unused params
    if (!Internal_CommandCooldown(playerid)) return 1;
    AdminPanel_ShowAudit(playerid);
    return 1;
}

CMD:asave(playerid, params[])
{
    #pragma unused params
    if (!AdminPanel_Require(playerid, ADMIN_PERM_SERVER_SAVE, "ADMIN_SERVER_SAVE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    DB_FlushAllDirtySync();
    Audit_FlushBufferSync();
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Emergency database saving completed.");
    AdminPanel_SendAudit(playerid, playerid, "ADMIN_SERVER_SAVE", 0, 0, "Emergency database saving");
    return 1;
}

CMD:propgive(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PROP_GIVE, "ADMIN_PROP_GIVE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /propgive [id] [property_id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const propertyDbId = strval(tok);
    if (!Properties_IsValid(propertyDbId)) { SendClientMessage(playerid, COLOR_UI_ERROR, "The property was not found."); return 1; }
    if (!Properties_AdminAssign(propertyDbId, Character_GetId(target))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to release property."); return 1; }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The property has been issued to the player.");
    SendClientMessage(target, COLOR_UI_INFO, "The administrator has given you the property.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_PROP_GIVE", 0, propertyDbId, "Give property");
    return 1;
}

CMD:propclear(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PROP_REMOVE, "ADMIN_PROP_REMOVE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /propclear [property_id]"); return 1; }
    new const propertyDbId = strval(tok);
    if (!Properties_IsValid(propertyDbId)) { SendClientMessage(playerid, COLOR_UI_ERROR, "The property was not found."); return 1; }
    if (!Properties_AdminClear(propertyDbId)) { SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to seize the property."); return 1; }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The property has been confiscated into state ownership.");
    AdminPanel_SendAudit(playerid, playerid, "ADMIN_PROP_REMOVE", 0, propertyDbId, "Confiscate property");
    return 1;
}

CMD:bizgive(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PROP_GIVE, "ADMIN_BIZ_GIVE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /bizgive [id] [enterprise_id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const enterpriseDbId = strval(tok);
    if (!Enterprise_AdminAssignByDbId(enterpriseDbId, Character_GetId(target))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Business not found."); return 1; }
    new bizName[64], details[160];
    Enterprise_GetNameByDbId(enterpriseDbId, bizName, sizeof(bizName));
    format(details, sizeof(details), "Give the enterprise \"%s\" (id %d)", bizName, enterpriseDbId);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The enterprise is given to the player.");
    SendClientMessage(target, COLOR_UI_INFO, "The administrator gave you the enterprise.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_BIZ_GIVE", 0, enterpriseDbId, details);
    return 1;
}

CMD:bizclear(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PROP_REMOVE, "ADMIN_BIZ_CLEAR")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /bizclear [enterprise_id]"); return 1; }
    new const enterpriseDbId = strval(tok);
    if (!Enterprise_AdminClearByDbId(enterpriseDbId)) { SendClientMessage(playerid, COLOR_UI_ERROR, "Business not found."); return 1; }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The enterprise was returned to the ownerless fund.");
    AdminPanel_SendAudit(playerid, playerid, "ADMIN_BIZ_CLEAR", 0, enterpriseDbId, "Confiscate an enterprise");
    return 1;
}

CMD:bizlist(playerid, params[])
{
    #pragma unused params
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PROP_GIVE, "ADMIN_BIZ_LIST")) return 1;
    new count = Enterprise_GetCount();
    new msg[144];
    format(msg, sizeof(msg), "Enterprises (total %d):", count);
    SendClientMessage(playerid, COLOR_UI_INFO, msg);
    for (new i = 0; i < count && i < 20; i++)
    {
        new const dbId = Enterprise_GetDbIdByIndex(i);
        if (dbId <= 0) continue;
        new name[64];
        Enterprise_GetNameByDbId(dbId, name, sizeof(name));
        format(msg, sizeof(msg), "ID %d - %s", dbId, name);
        SendClientMessage(playerid, COLOR_UI_INFO, msg);
    }
    return 1;
}

CMD:setcitizen(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_CHAR_SET_STATUS, "ADMIN_SET_CITIZEN")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setcitizen [id] [0=immigrant|1=citizen]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const value = strval(tok);
    if (value != 0 && value != 1) { SendClientMessage(playerid, COLOR_UI_ERROR, "Value: 0 or 1."); return 1; }
    Character_SetCitizenship(target, (value == 1) ? CITIZENSHIP_CITIZEN : CITIZENSHIP_IMMIGRANT);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, value ? "The character received US citizenship." : "The character has been transferred to immigrant status.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_CITIZEN", 0, value, "Change of citizenship");
    return 1;
}

CMD:setssn(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_CHAR_SET_STATUS, "ADMIN_SET_SSN")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24], ssn[16];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setssn [id] [XXX-XX-XXXX]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, ssn, sizeof(ssn))) return 1;
    if (strlen(ssn) != 11) { SendClientMessage(playerid, COLOR_UI_ERROR, "The SSN must be in the format XXX-XX-XXXX."); return 1; }
    Character_SetSSN(target, ssn);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Character SSN has been updated.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_SSN", 0, 0, "Change SSN");
    return 1;
}

CMD:unmute(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_MUTE, "ADMIN_UNMUTE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /unmute [id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    Admin_Unmute(playerid, target);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The mute has been removed.");
    return 1;
}

CMD:setaddiction(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_SET_STATS, "ADMIN_SET_ADDICTION")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setaddiction [id] [0-100]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const value = strval(tok);
    if (value < 0 || value > 100) { SendClientMessage(playerid, COLOR_UI_ERROR, "Range: 0-100."); return 1; }
    Character_SetAddiction(target, float(value));
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Dependency level updated.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_ADDICTION", 0, value, "Change dependency");
    return 1;
}

CMD:release(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_PLAYER_JAIL, "ADMIN_RELEASE")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /release [id]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Justice_ReleasePlayer(target)) { SendClientMessage(playerid, COLOR_UI_ERROR, "The player is not imprisoned."); return 1; }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The player has been released from custody.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_RELEASE", 0, 0, "Early release");
    return 1;
}

CMD:setck(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_CHAR_SET_STATUS, "ADMIN_SET_CK")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[24];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /setck [id] [0|1]"); return 1; }
    new const target = strval(tok);
    if (!AdminPanel_ValidTarget(playerid, target)) return 1;
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const value = strval(tok);
    if (value != 0 && value != 1) { SendClientMessage(playerid, COLOR_UI_ERROR, "CK value: 0 or 1."); return 1; }
    Character_SetCkDead(target, value == 1);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, value ? "Permanent Death (CK) applied." : "CK removed.");
    AdminPanel_SendAudit(playerid, target, "ADMIN_SET_CK", 0, value, "Changing the CK flag");
    return 1;
}

CMD:arole(playerid, params[])
{
    if (!AdminPanel_Require(playerid, ADMIN_PERM_MANAGE_ADMINS, "ADMIN_ROLE_ASSIGN")) return 1;
    if (!Internal_CommandCooldown(playerid)) return 1;
    new pos = 0, tok[32];
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) { SendClientMessage(playerid, COLOR_UI_ERROR, "Usage: /arole [account_id] [role_id] (0 = remove role)"); return 1; }
    new const accountId = strval(tok);
    if (!Internal_NextToken(params, pos, tok, sizeof(tok))) return 1;
    new const roleDb = strval(tok);
    if (accountId <= 0) { SendClientMessage(playerid, COLOR_UI_ERROR, "Invalid account_id."); return 1; }
    if (Admin_AssignRole(playerid, accountId, roleDb)) SendClientMessage(playerid, COLOR_UI_SUCCESS, "The admin role has been updated.");
    else SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to change role: check permissions and role level.");
    return 1;
}


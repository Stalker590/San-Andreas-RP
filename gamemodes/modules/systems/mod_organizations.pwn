/*
 * =============================================================================
 *  SAN ANDREAS RP — Унифицированный движок организаций, RBAC и казны-сейфы
 *  Файл:      gamemodes/modules/systems/mod_organizations.pwn
 *  Пункт:     ROADMAP [7.2] — Унифицированный движок организаций и RBAC
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_organizations_included
    #endinput
#endif
#define _mod_organizations_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ ОРГАНИЗАЦИЙ, ПРАВ ДОСТУПА И ДИАЛОГОВ
// =============================================================================

#define ORG_NAME_LEN                            (64)
#define ORG_TAG_LEN                             (8)
#define ORG_RANK_TITLE_LEN                      (48)
#define MAX_ORG_RANKS                           (20)
#define ORG_MAX_LIST_ROWS                       (32)
#define ORG_MAX_MEMBER_ROWS                     (50)
#define ORG_MAX_MENU_ACTIONS                    (10)
#define ORG_DIALOG_BUFFER_LEN                   (4096)
#define ORG_VAULT_UNLOCK_MS                     (45000)
#define ORG_COMMAND_COOLDOWN_MS                 (500)
#define ORG_VAULT_HEIST_COOLDOWN_MS             (5000)
#define ORG_CREATE_COST_UNREGISTERED_USD        (250000)
#define ORG_CREATE_COST_CORP_USD                (500000)
#define ORG_CREATE_COST_STATE_USD               (2000000)
#define ORG_CREATE_DISCOUNT_PERCENT             (25)
#define ORG_VAULT_DEFAULT_WEIGHT_G              (5000000)
#define ORG_VAULT_DEFAULT_VOLUME_ML             (5000000)
#define ORG_PERM_FULL_MASK                      (63)
#define ORG_GOVERNMENT_DB_ID                    (1)
#define ORG_FBI_DB_ID                            (9)
#define ORG_CIA_DB_ID                            (10)
#define ITEM_ID_SATCHEL_CHARGE                  (29)
#define ITEM_ID_SAFE_LOCKPICK_SET               (45)

#define DIALOG_ORG_MAIN                         (1500)
#define DIALOG_ORG_LIST                         (1501)
#define DIALOG_ORG_INFO                         (1502)
#define DIALOG_ORG_RANKS                        (1503)
#define DIALOG_ORG_RANK_EDIT                    (1504)
#define DIALOG_ORG_RANK_PERMS                   (1505)
#define DIALOG_ORG_RANK_TITLE_INPUT             (1506)
#define DIALOG_ORG_RANK_SALARY_INPUT            (1507)
#define DIALOG_ORG_MEMBERS                      (1508)
#define DIALOG_ORG_MEMBER_ACTIONS               (1509)
#define DIALOG_ORG_PROMOTE                      (1510)
#define DIALOG_ORG_BANK                         (1511)
#define DIALOG_ORG_BANK_AMOUNT                  (1512)
#define DIALOG_ORG_RADIO_INPUT                  (1513)
#define DIALOG_ORG_CREATE_STATUS                (1514)
#define DIALOG_ORG_CREATE_NAME                  (1515)
#define DIALOG_ORG_CREATE_TAG                   (1516)

// Матрица прав RBAC организации (битовая маска в organization_ranks.permissions_mask)
enum E_ORG_PERM (<<= 1)
{
    ORG_PERM_NONE = 0,
    ORG_PERM_RADIO = 1,
    ORG_PERM_FLEET,
    ORG_PERM_ARMORY,
    ORG_PERM_HIRE,
    ORG_PERM_BANK,
    ORG_PERM_RANKS
};

enum E_ORG_MENU_ACTION
{
    ORG_MENU_NONE = 0,
    ORG_MENU_INFO,
    ORG_MENU_RANKS,
    ORG_MENU_RANK_BUILDER,
    ORG_MENU_MEMBERS,
    ORG_MENU_VAULT,
    ORG_MENU_BANK,
    ORG_MENU_RADIO,
    ORG_MENU_CHARTER,
    ORG_MENU_LEAVE
};

enum E_ORG_RANK_ACTION
{
    ORG_RANK_ACTION_NONE = 0,
    ORG_RANK_ACTION_TITLE,
    ORG_RANK_ACTION_SALARY,
    ORG_RANK_ACTION_PERMS,
    ORG_RANK_ACTION_DELETE
};

enum E_ORG_MEMBER_ACTION
{
    ORG_MEMBER_ACTION_NONE = 0,
    ORG_MEMBER_ACTION_PROMOTE,
    ORG_MEMBER_ACTION_FIRE,
    ORG_MEMBER_ACTION_BACK
};

enum E_ORG_BANK_ACTION
{
    ORG_BANK_ACTION_NONE = 0,
    ORG_BANK_ACTION_DEPOSIT,
    ORG_BANK_ACTION_WITHDRAW
};

enum E_ORG_DATA
{
    bool:E_ORG_VALID,
    E_ORG_DB_ID,
    E_ORG_NAME[ORG_NAME_LEN],
    E_ORG_TAG[ORG_TAG_LEN],
    E_ORG_LEGAL_STATUS:E_ORG_STATUS,
    bool:E_ORG_IS_PERMANENT,
    E_ORG_CHARTER_FLAGS,
    E_ORG_VAULT_DB_ID,
    E_ORG_VAULT_SLOT,
    E_ORG_BANK_BALANCE_USD,
    bool:E_ORG_BANK_FROZEN,
    E_ORG_RADIO_FREQ,
    Float:E_ORG_HQ_X,
    Float:E_ORG_HQ_Y,
    Float:E_ORG_HQ_Z,
    E_ORG_RANK_COUNT
};

enum E_ORG_RANK_DATA
{
    bool:E_ORG_RANK_VALID,
    E_ORG_RANK_DB_ID,
    E_ORG_RANK_ORDER,
    E_ORG_RANK_TITLE[ORG_RANK_TITLE_LEN],
    E_ORG_RANK_SALARY_USD,
    E_ORG_RANK_PERMISSIONS
};

enum E_BUILTIN_ORG
{
    E_BORG_ID,
    E_BORG_NAME[ORG_NAME_LEN],
    E_BORG_TAG[ORG_TAG_LEN],
    E_ORG_LEGAL_STATUS:E_BORG_STATUS,
    E_BORG_CHARTER_FLAGS,
    E_BORG_VAULT_DB_ID,
    E_BORG_BANK_BALANCE_USD,
    E_BORG_RADIO_FREQ,
    Float:E_BORG_HQ_X,
    Float:E_BORG_HQ_Y,
    Float:E_BORG_HQ_Z
};

// =============================================================================
//  2. ИНКАПСУЛИРОВАННЫЕ ПУЛЫ ОРГАНИЗАЦИЙ, ДОЛЖНОСТЕЙ И СОСТОЯНИЙ (static stock)
// =============================================================================

static stock sOrgs[MAX_ORGANIZATIONS][E_ORG_DATA];
static stock sOrgRanks[MAX_ORGANIZATIONS][MAX_ORG_RANKS][E_ORG_RANK_DATA];
new Iterator:OrganizationIter<MAX_ORGANIZATIONS>;

static stock sNextOrgDbId = 1;
static stock sNextRankDbId = 1;

static stock E_ORG_MENU_ACTION:sOrgMenuAction[MAX_PLAYERS][ORG_MAX_MENU_ACTIONS];
static stock sOrgMenuActionCount[MAX_PLAYERS];
static stock sOrgListRowMap[MAX_PLAYERS][ORG_MAX_LIST_ROWS];
static stock sOrgListRowCount[MAX_PLAYERS];
static stock sOrgRankRowMap[MAX_PLAYERS][MAX_ORG_RANKS];
static stock sOrgRankRowCount[MAX_PLAYERS];
static stock sOrgRankEditIndex[MAX_PLAYERS];
static stock sOrgPermRankIndex[MAX_PLAYERS];
static stock sOrgMemberCharId[MAX_PLAYERS][ORG_MAX_MEMBER_ROWS];
static stock sOrgMemberRankId[MAX_PLAYERS][ORG_MAX_MEMBER_ROWS];
static stock sOrgMemberName[MAX_PLAYERS][ORG_MAX_MEMBER_ROWS][MAX_PLAYER_NAME + 1];
static stock sOrgMemberCount[MAX_PLAYERS];
static stock sOrgPendingMember[MAX_PLAYERS];
static stock sOrgPendingMemberCharId[MAX_PLAYERS];
static stock sOrgInputRankIndex[MAX_PLAYERS];
static stock sOrgBankAction[MAX_PLAYERS];
static stock sOrgCreateStatus[MAX_PLAYERS];
static stock sOrgCreateName[MAX_PLAYERS][ORG_NAME_LEN];
static stock sOrgCreateTag[MAX_PLAYERS][ORG_TAG_LEN];
static stock sOrgDialogBuffer[ORG_DIALOG_BUFFER_LEN];
static stock sOrgLastCommandTick[MAX_PLAYERS];
static stock sOrgLastHeistTick[MAX_PLAYERS];
static stock sOrgVaultUnlockUntil[MAX_ORGANIZATIONS];
static stock sOrgVaultUnlockedBy[MAX_ORGANIZATIONS];

static stock const sBuiltinOrgs[21][E_BUILTIN_ORG] =
{
    { 1,  "Правительство штата Сан-Андреас", "GOV",   ORG_STATUS_STATE_AGENCY,  5,  1,  100000000, 100100, 1481.0,  -1771.0, 18.8 },
    { 2,  "Полицейский департамент Лос-Сантоса", "LSPD", ORG_STATUS_STATE_AGENCY, 23, 2,  5000000,  101100, 1554.9,  -1675.6, 16.2 },
    { 3,  "Полицейский департамент Сан-Фиерро", "SFPD", ORG_STATUS_STATE_AGENCY, 23, 3, 5000000, 102100, -1605.5, 710.8,   13.9 },
    { 4,  "Полицейский департамент Лас-Вентураса", "LVPD", ORG_STATUS_STATE_AGENCY, 23, 4, 5000000, 103100, 2287.0, 2431.8, 10.8 },
    { 5,  "Департамент Шерифа округа", "SASD", ORG_STATUS_STATE_AGENCY, 23, 5, 4500000, 104100, 627.6,  -571.8, 17.9 },
    { 6,  "Национальная Гвардия Лос-Сантоса", "LSA", ORG_STATUS_STATE_AGENCY, 3, 6, 8000000, 105100, 2728.5, -2451.4, 17.6 },
    { 7,  "Военно-морские силы Сан-Фиерро", "SFA", ORG_STATUS_STATE_AGENCY, 3, 7, 8000000, 106100, -1346.8, 492.4, 11.2 },
    { 8,  "Военный гарнизон Зоны 69", "LVA", ORG_STATUS_STATE_AGENCY, 3, 8, 10000000, 107100, 213.8, 1872.5, 13.1 },
    { 9,  "Федеральное бюро расследований", "FBI", ORG_STATUS_STATE_AGENCY, 31, 9, 12000000, 108100, -2442.2, 502.3, 30.1 },
    { 10, "Центральное разведывательное управление", "CIA", ORG_STATUS_STATE_AGENCY, 63, 10, 15000000, 109100, 1245.5, -764.2, 92.1 },
    { 11, "Иммиграционная и таможенная служба", "ICE", ORG_STATUS_STATE_AGENCY, 23, 11, 4000000, 110100, 55.6, -1531.9, 5.1 },
    { 12, "Департамент здравоохранения и скорой помощи", "EMS", ORG_STATUS_STATE_AGENCY, 1, 12, 6000000, 112100, 1172.8, -1323.4, 15.4 },
    { 13, "ЧВК «Блэквотер Сан-Андреас»", "PMC", ORG_STATUS_PRIVATE_CORP, 3, 13, 7500000, 200100, 2504.3, 2772.9, 10.8 },
    { 14, "Управление портов и логистики", "PORT", ORG_STATUS_STATE_AGENCY, 17, 14, 10000000, 201100, 2746.1, -2437.2, 13.6 },
    { 15, "Телерадиокомпания Сан-Андреас", "NEWS", ORG_STATUS_PRIVATE_CORP, 1, 15, 2500000, 202100, 777.8, -1330.2, 13.5 },
    { 16, "Семьи Гроув-Стрит", "GROVE", ORG_STATUS_UNREGISTERED, 0, 16, 0, 420100, 2495.3, -1690.7, 14.8 },
    { 17, "Банда Баллас", "BALLAS", ORG_STATUS_UNREGISTERED, 0, 17, 0, 420200, 2000.2, -1114.1, 27.1 },
    { 18, "Лос-Сантос Вагос", "VAGOS", ORG_STATUS_UNREGISTERED, 0, 18, 0, 420300, 2808.5, -1176.9, 25.4 },
    { 19, "Варриос Лос-Ацтекас", "AZTEC", ORG_STATUS_UNREGISTERED, 0, 19, 0, 420400, 1882.4, -2023.7, 13.5 },
    { 20, "Синдикат Триад Сан-Фиерро", "TRIAD", ORG_STATUS_UNREGISTERED, 0, 20, 0, 420500, -2172.6, 680.1, 55.2 },
    { 21, "Криминальная семья Лас-Вентураса", "MAFIA", ORG_STATUS_UNREGISTERED, 0, 21, 0, 420600, 2196.4, 1677.1, 12.4 }
};

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (static stock)
// =============================================================================

static stock Internal_ParseLegalStatus(const statusStr[])
{
    if (!strcmp(statusStr, "PRIVATE_CORP", true)) return _:ORG_STATUS_PRIVATE_CORP;
    if (!strcmp(statusStr, "STATE_AGENCY", true)) return _:ORG_STATUS_STATE_AGENCY;
    return _:ORG_STATUS_UNREGISTERED;
}

stock Organizations_GetStatusString(E_ORG_LEGAL_STATUS:status, output[], len = sizeof(output))
{
    switch (status)
    {
        case ORG_STATUS_UNREGISTERED: format(output, len, "UNREGISTERED");
        case ORG_STATUS_PRIVATE_CORP: format(output, len, "PRIVATE_CORP");
        case ORG_STATUS_STATE_AGENCY: format(output, len, "STATE_AGENCY");
        default:                      format(output, len, "UNREGISTERED");
    }
    return 1;
}

stock Organizations_GetStatusTitleRu(E_ORG_LEGAL_STATUS:status, output[], len = sizeof(output))
{
    switch (status)
    {
        case ORG_STATUS_UNREGISTERED: format(output, len, "Незарегистрированная группировка");
        case ORG_STATUS_PRIVATE_CORP: format(output, len, "Частная корпорация");
        case ORG_STATUS_STATE_AGENCY: format(output, len, "Государственное ведомство");
        default:                      format(output, len, "Неизвестный статус");
    }
    return 1;
}

static stock bool:Internal_OrgNameExists(const name[])
{
    foreach (new slot : OrganizationIter)
    {
        if (sOrgs[slot][E_ORG_VALID] && !strcmp(sOrgs[slot][E_ORG_NAME], name, true))
        {
            return true;
        }
    }
    return false;
}

static stock bool:Internal_OrgTagExists(const tag[])
{
    foreach (new slot : OrganizationIter)
    {
        if (sOrgs[slot][E_ORG_VALID] && !strcmp(sOrgs[slot][E_ORG_TAG], tag, true))
        {
            return true;
        }
    }
    return false;
}

static stock bool:Internal_IsValidOrgTag(const tag[])
{
    for (new i = 0, len = strlen(tag); i < len; i++)
    {
        new const ch = tag[i];
        if (!((ch >= 'A' && ch <= 'Z') ||
              (ch >= 'a' && ch <= 'z') ||
              (ch >= '0' && ch <= '9') ||
              ch == '_' || ch == '-'))
        {
            return false;
        }
    }
    return true;
}

static stock Internal_FindPlayerByCharId(char_db_id)
{
    if (char_db_id <= 0)
    {
        return INVALID_PLAYER_ID;
    }
    foreach (new playerid : Player)
    {
        if (Character_IsLoaded(playerid) && Character_GetId(playerid) == char_db_id)
        {
            return playerid;
        }
    }
    return INVALID_PLAYER_ID;
}

static stock Internal_ResetOrganizationSlot(org_slot)
{
    sOrgs[org_slot][E_ORG_VALID] = false;
    sOrgs[org_slot][E_ORG_DB_ID] = 0;
    sOrgs[org_slot][E_ORG_NAME][0] = EOS;
    sOrgs[org_slot][E_ORG_TAG][0] = EOS;
    sOrgs[org_slot][E_ORG_STATUS] = ORG_STATUS_UNREGISTERED;
    sOrgs[org_slot][E_ORG_IS_PERMANENT] = false;
    sOrgs[org_slot][E_ORG_CHARTER_FLAGS] = 0;
    sOrgs[org_slot][E_ORG_VAULT_DB_ID] = 0;
    sOrgs[org_slot][E_ORG_VAULT_SLOT] = INVALID_STORAGE_SLOT;
    sOrgs[org_slot][E_ORG_BANK_BALANCE_USD] = 0;
    sOrgs[org_slot][E_ORG_BANK_FROZEN] = false;
    sOrgs[org_slot][E_ORG_RADIO_FREQ] = 0;
    sOrgs[org_slot][E_ORG_HQ_X] = 0.0;
    sOrgs[org_slot][E_ORG_HQ_Y] = 0.0;
    sOrgs[org_slot][E_ORG_HQ_Z] = 0.0;
    sOrgs[org_slot][E_ORG_RANK_COUNT] = 0;

    for (new r = 0; r < MAX_ORG_RANKS; r++)
    {
        sOrgRanks[org_slot][r][E_ORG_RANK_VALID] = false;
        sOrgRanks[org_slot][r][E_ORG_RANK_DB_ID] = 0;
        sOrgRanks[org_slot][r][E_ORG_RANK_ORDER] = 0;
        sOrgRanks[org_slot][r][E_ORG_RANK_TITLE][0] = EOS;
        sOrgRanks[org_slot][r][E_ORG_RANK_SALARY_USD] = 0;
        sOrgRanks[org_slot][r][E_ORG_RANK_PERMISSIONS] = 0;
    }
    return 1;
}

static stock Internal_AddOrganization(
    db_id,
    const name[],
    const tag[],
    E_ORG_LEGAL_STATUS:status,
    bool:is_permanent,
    charter_flags,
    vault_db_id,
    bank_balance,
    bool:bank_frozen,
    radio_freq,
    Float:hq_x,
    Float:hq_y,
    Float:hq_z)
{
    if (db_id <= 0)
    {
        return INVALID_STORAGE_SLOT;
    }

    new existing = Organizations_FindByDbId(db_id);
    if (existing >= 0)
    {
        return existing;
    }

    new const slot = Iter_Free(OrganizationIter);
    if (slot == INVALID_ITERATOR_SLOT)
    {
        printf("%s [Systems/Organizations] [ERROR] Пул организаций переполнен (MAX_ORGANIZATIONS = %d).",
            SERVER_LOG_PREFIX, MAX_ORGANIZATIONS);
        return -1;
    }

    Iter_Add(OrganizationIter, slot);
    Internal_ResetOrganizationSlot(slot);

    sOrgs[slot][E_ORG_VALID] = true;
    sOrgs[slot][E_ORG_DB_ID] = db_id;
    format(sOrgs[slot][E_ORG_NAME], ORG_NAME_LEN, "%s", name);
    format(sOrgs[slot][E_ORG_TAG], ORG_TAG_LEN, "%s", tag);
    sOrgs[slot][E_ORG_STATUS] = status;
    sOrgs[slot][E_ORG_IS_PERMANENT] = is_permanent;
    sOrgs[slot][E_ORG_CHARTER_FLAGS] = charter_flags;
    sOrgs[slot][E_ORG_VAULT_DB_ID] = vault_db_id;
    sOrgs[slot][E_ORG_BANK_BALANCE_USD] = bank_balance;
    sOrgs[slot][E_ORG_BANK_FROZEN] = bank_frozen;
    sOrgs[slot][E_ORG_RADIO_FREQ] = radio_freq;
    sOrgs[slot][E_ORG_HQ_X] = hq_x;
    sOrgs[slot][E_ORG_HQ_Y] = hq_y;
    sOrgs[slot][E_ORG_HQ_Z] = hq_z;

    new vaultSlot = Storage_FindByDbId(vault_db_id);
    if (vaultSlot == INVALID_STORAGE_SLOT && vault_db_id > 0)
    {
        vaultSlot = Storage_Create(
            STORAGE_ORG_VAULT,
            db_id,
            ORG_VAULT_DEFAULT_WEIGHT_G,
            ORG_VAULT_DEFAULT_VOLUME_ML,
            true,
            3,
            hq_x, hq_y, hq_z,
            0,
            0,
            0,
            vault_db_id);
    }
    sOrgs[slot][E_ORG_VAULT_SLOT] = vaultSlot;
    return slot;
}

static stock Internal_AddRank(org_slot, rank_db_id, rank_order, const title[], salary, permissions)
{
    if (!sOrgs[org_slot][E_ORG_VALID] || sOrgs[org_slot][E_ORG_RANK_COUNT] >= MAX_ORG_RANKS)
    {
        return -1;
    }
    if (Organizations_GetRankIndexByDbId(org_slot, rank_db_id) >= 0)
    {
        return -1;
    }

    new count = sOrgs[org_slot][E_ORG_RANK_COUNT];
    new insertAt = count;
    for (new i = 0; i < count; i++)
    {
        if (rank_order < sOrgRanks[org_slot][i][E_ORG_RANK_ORDER])
        {
            insertAt = i;
            break;
        }
    }

    for (new i = count; i > insertAt; i--)
    {
        sOrgRanks[org_slot][i] = sOrgRanks[org_slot][i - 1];
    }

    sOrgRanks[org_slot][insertAt][E_ORG_RANK_VALID] = true;
    sOrgRanks[org_slot][insertAt][E_ORG_RANK_DB_ID] = rank_db_id;
    sOrgRanks[org_slot][insertAt][E_ORG_RANK_ORDER] = rank_order;
    format(sOrgRanks[org_slot][insertAt][E_ORG_RANK_TITLE], ORG_RANK_TITLE_LEN, "%s", title);
    sOrgRanks[org_slot][insertAt][E_ORG_RANK_SALARY_USD] = salary;
    sOrgRanks[org_slot][insertAt][E_ORG_RANK_PERMISSIONS] = permissions;
    sOrgs[org_slot][E_ORG_RANK_COUNT] = count + 1;
    return insertAt;
}

static stock Internal_SeedDefaultRanks(org_slot)
{
    if (!sOrgs[org_slot][E_ORG_VALID] || sOrgs[org_slot][E_ORG_RANK_COUNT] > 0)
    {
        return 0;
    }

    new const E_ORG_LEGAL_STATUS:status = sOrgs[org_slot][E_ORG_STATUS];
    new const bool:isState = (status == ORG_STATUS_STATE_AGENCY);
    new const bool:isCorp = (status == ORG_STATUS_PRIVATE_CORP);

    new const rankTitles[5][ORG_RANK_TITLE_LEN] =
    {
        "Стажер", "Сотрудник", "Специалист", "Заместитель руководителя", "Руководитель"
    };
    new const rankTitlesCrime[5][ORG_RANK_TITLE_LEN] =
    {
        "Новичок", "Боец", "Авторитет", "Правая рука", "Лидер"
    };
    new const rankPerms[5] = { 3, 7, 15, 31, 63 };

    for (new r = 0; r < 5; r++)
    {
        new salary = 0;
        if (isState)
        {
            new const stateSalary[5] = { 800, 1200, 1700, 2500, 3500 };
            salary = stateSalary[r];
        }
        else if (isCorp)
        {
            new const corpSalary[5] = { 700, 1100, 1600, 2400, 3200 };
            salary = corpSalary[r];
        }

        Internal_AddRank(
            org_slot,
            sNextRankDbId++,
            r + 1,
            (status == ORG_STATUS_UNREGISTERED) ? rankTitlesCrime[r] : rankTitles[r],
            salary,
            rankPerms[r]);
    }
    return 1;
}

static stock Internal_SeedBuiltinOrganizations()
{
    for (new i = 0; i < sizeof(sBuiltinOrgs); i++)
    {
        new const slot = Internal_AddOrganization(
            sBuiltinOrgs[i][E_BORG_ID],
            sBuiltinOrgs[i][E_BORG_NAME],
            sBuiltinOrgs[i][E_BORG_TAG],
            sBuiltinOrgs[i][E_BORG_STATUS],
            true,
            sBuiltinOrgs[i][E_BORG_CHARTER_FLAGS],
            sBuiltinOrgs[i][E_BORG_VAULT_DB_ID],
            sBuiltinOrgs[i][E_BORG_BANK_BALANCE_USD],
            false,
            sBuiltinOrgs[i][E_BORG_RADIO_FREQ],
            sBuiltinOrgs[i][E_BORG_HQ_X],
            sBuiltinOrgs[i][E_BORG_HQ_Y],
            sBuiltinOrgs[i][E_BORG_HQ_Z]);

        if (slot >= 0)
        {
            Internal_SeedDefaultRanks(slot);
        }
    }

    if (sNextOrgDbId < 22)
    {
        sNextOrgDbId = 22;
    }
    return 1;
}

static stock Internal_LoadOrganizationsSync()
{
    if (!DB_IsConnected())
    {
        Internal_SeedBuiltinOrganizations();
        printf("%s [Systems/Organizations] База недоступна: загружены 21 системная фракция из встроенного реестра.",
            SERVER_LOG_PREFIX);
        return 0;
    }

    new const Cache:maxCache = mysql_query(gMySQL,
        "SELECT (SELECT IFNULL(MAX(`id`), 0) FROM `organizations`) AS `max_org`, (SELECT IFNULL(MAX(`id`), 0) FROM `organization_ranks`) AS `max_rank`;",
        true);
    if (cache_is_valid(maxCache))
    {
        new maxOrgId = 0, maxRankId = 0;
        cache_get_value_name_int(0, "max_org", maxOrgId);
        cache_get_value_name_int(0, "max_rank", maxRankId);
        sNextOrgDbId = maxOrgId + 1;
        sNextRankDbId = maxRankId + 1;
        cache_delete(maxCache);
    }

    new const Cache:orgCache = mysql_query(gMySQL,
        "SELECT `id`, `name`, `tag`, `legal_status`, `is_permanent`, `charter_flags`, `vault_storage_id`, `bank_balance_usd`, `is_bank_frozen`, `radio_freq`, `hq_x`, `hq_y`, `hq_z` FROM `organizations` ORDER BY `id` ASC;",
        true);

    if (cache_is_valid(orgCache))
    {
        new rows = 0;
        cache_get_row_count(rows);
        for (new r = 0; r < rows; r++)
        {
            new orgId, isPermanentInt, flags, vaultDbId, bankBalance, frozenInt, radioFreq;
            new Float:hqX, Float:hqY, Float:hqZ;
            new name[ORG_NAME_LEN], tag[ORG_TAG_LEN], statusStr[24];

            cache_get_value_name_int(r, "id", orgId);
            cache_get_value_name(r, "name", name, sizeof(name));
            cache_get_value_name(r, "tag", tag, sizeof(tag));
            cache_get_value_name(r, "legal_status", statusStr, sizeof(statusStr));
            cache_get_value_name_int(r, "is_permanent", isPermanentInt);
            cache_get_value_name_int(r, "charter_flags", flags);
            cache_get_value_name_int(r, "vault_storage_id", vaultDbId);
            cache_get_value_name_int(r, "bank_balance_usd", bankBalance);
            cache_get_value_name_int(r, "is_bank_frozen", frozenInt);
            cache_get_value_name_int(r, "radio_freq", radioFreq);
            cache_get_value_name_float(r, "hq_x", hqX);
            cache_get_value_name_float(r, "hq_y", hqY);
            cache_get_value_name_float(r, "hq_z", hqZ);

            Internal_AddOrganization(
                orgId,
                name,
                tag,
                E_ORG_LEGAL_STATUS:Internal_ParseLegalStatus(statusStr),
                (isPermanentInt != 0),
                flags,
                vaultDbId,
                bankBalance,
                (frozenInt != 0),
                radioFreq,
                hqX, hqY, hqZ);
        }
        cache_delete(orgCache);
    }

    new const Cache:rankCache = mysql_query(gMySQL,
        "SELECT `id`, `org_id`, `rank_order`, `title`, `salary_usd`, `permissions_mask` FROM `organization_ranks` ORDER BY `org_id` ASC, `rank_order` ASC;",
        true);

    if (cache_is_valid(rankCache))
    {
        new rows = 0;
        cache_get_row_count(rows);
        for (new r = 0; r < rows; r++)
        {
            new rankId, orgId, rankOrder, salary;
            new permissions;
            new title[ORG_RANK_TITLE_LEN];

            cache_get_value_name_int(r, "id", rankId);
            cache_get_value_name_int(r, "org_id", orgId);
            cache_get_value_name_int(r, "rank_order", rankOrder);
            cache_get_value_name(r, "title", title, sizeof(title));
            cache_get_value_name_int(r, "salary_usd", salary);
            cache_get_value_name_int(r, "permissions_mask", permissions);

            new const orgSlot = Organizations_FindByDbId(orgId);
            if (orgSlot >= 0)
            {
                Internal_AddRank(orgSlot, rankId, rankOrder, title, salary, permissions);
            }
        }
        cache_delete(rankCache);
    }

    if (Iter_Count(OrganizationIter) == 0)
    {
        Internal_SeedBuiltinOrganizations();
        printf("%s [Systems/Organizations] Таблица organizations пуста: применен встроенный реестр 21 фракции.",
            SERVER_LOG_PREFIX);
    }
    else
    {
        foreach (new orgSlot : OrganizationIter)
        {
            if (sOrgs[orgSlot][E_ORG_VALID] && sOrgs[orgSlot][E_ORG_RANK_COUNT] == 0)
            {
                Internal_SeedDefaultRanks(orgSlot);
            }
        }
    }
    return 1;
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API ОРГАНИЗАЦИЙ (Organizations_* / Org_*)
// =============================================================================

stock Organizations_FindByDbId(org_db_id)
{
    if (org_db_id <= 0)
    {
        return -1;
    }
    foreach (new slot : OrganizationIter)
    {
        if (sOrgs[slot][E_ORG_VALID] && sOrgs[slot][E_ORG_DB_ID] == org_db_id)
        {
            return slot;
        }
    }
    return -1;
}

stock Organizations_FindByTag(const tag[])
{
    foreach (new slot : OrganizationIter)
    {
        if (sOrgs[slot][E_ORG_VALID] && !strcmp(sOrgs[slot][E_ORG_TAG], tag, true))
        {
            return slot;
        }
    }
    return -1;
}

stock Organizations_IsValid(org_db_id)
{
    return (Organizations_FindByDbId(org_db_id) >= 0);
}

stock Organizations_GetName(org_db_id, output[], len = sizeof(output))
{
    output[0] = EOS;
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        return 0;
    }
    format(output, len, "%s", sOrgs[slot][E_ORG_NAME]);
    return 1;
}

stock Organizations_GetTag(org_db_id, output[], len = sizeof(output))
{
    output[0] = EOS;
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        return 0;
    }
    format(output, len, "%s", sOrgs[slot][E_ORG_TAG]);
    return 1;
}

stock E_ORG_LEGAL_STATUS:Organizations_GetLegalStatus(org_db_id)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        return ORG_STATUS_UNREGISTERED;
    }
    return sOrgs[slot][E_ORG_STATUS];
}

stock Organizations_GetCharterFlags(org_db_id)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        return 0;
    }
    return sOrgs[slot][E_ORG_CHARTER_FLAGS];
}

stock bool:Organizations_HasCharterFlag(org_db_id, E_CHARTER_FLAGS:flag)
{
    return ((Organizations_GetCharterFlags(org_db_id) & _:flag) != 0);
}

stock Organizations_GetBankBalance(org_db_id)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        return 0;
    }
    return sOrgs[slot][E_ORG_BANK_BALANCE_USD];
}

stock bool:Organizations_IsBankFrozen(org_db_id)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        return false;
    }
    return sOrgs[slot][E_ORG_BANK_FROZEN];
}

// Полномочия в правовом поле: официальный статус и право выдачи ордеров
stock bool:Organizations_CanActInLegalField(org_db_id)
{
    return (Organizations_GetLegalStatus(org_db_id) != ORG_STATUS_UNREGISTERED &&
            Organizations_HasCharterFlag(org_db_id, FLAG_ISSUE_WARRANTS));
}

// Полномочия вне внутреннего законодательства (санкционированные операции ЦРУ)
stock bool:Organizations_CanActExtralegally(org_db_id)
{
    return Organizations_HasCharterFlag(org_db_id, FLAG_EXTRALEGAL_OPS);
}

stock Organizations_GetRadioFreq(org_db_id)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        return 0;
    }
    return sOrgs[slot][E_ORG_RADIO_FREQ];
}

stock Organizations_GetRankCount(org_db_id)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        return 0;
    }
    return sOrgs[slot][E_ORG_RANK_COUNT];
}

stock Organizations_GetRankIndexByDbId(org_slot, rank_db_id)
{
    if (org_slot < 0 || org_slot >= MAX_ORGANIZATIONS || rank_db_id <= 0)
    {
        return -1;
    }
    for (new r = 0; r < sOrgs[org_slot][E_ORG_RANK_COUNT]; r++)
    {
        if (sOrgRanks[org_slot][r][E_ORG_RANK_VALID] &&
            sOrgRanks[org_slot][r][E_ORG_RANK_DB_ID] == rank_db_id)
        {
            return r;
        }
    }
    return -1;
}

stock Organizations_GetRankDbId(org_db_id, rank_index)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0 || rank_index < 0 || rank_index >= sOrgs[slot][E_ORG_RANK_COUNT])
    {
        return 0;
    }
    return sOrgRanks[slot][rank_index][E_ORG_RANK_DB_ID];
}

stock Organizations_GetRankTitle(org_db_id, rank_index, output[], len = sizeof(output))
{
    output[0] = EOS;
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0 || rank_index < 0 || rank_index >= sOrgs[slot][E_ORG_RANK_COUNT])
    {
        return 0;
    }
    format(output, len, "%s", sOrgRanks[slot][rank_index][E_ORG_RANK_TITLE]);
    return 1;
}

stock Organizations_GetRankOrder(org_db_id, rank_index)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0 || rank_index < 0 || rank_index >= sOrgs[slot][E_ORG_RANK_COUNT])
    {
        return 0;
    }
    return sOrgRanks[slot][rank_index][E_ORG_RANK_ORDER];
}

stock Organizations_GetRankSalary(org_db_id, rank_index)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0 || rank_index < 0 || rank_index >= sOrgs[slot][E_ORG_RANK_COUNT])
    {
        return 0;
    }
    return sOrgRanks[slot][rank_index][E_ORG_RANK_SALARY_USD];
}

stock Organizations_GetRankPermissions(org_db_id, rank_index)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0 || rank_index < 0 || rank_index >= sOrgs[slot][E_ORG_RANK_COUNT])
    {
        return 0;
    }
    return sOrgRanks[slot][rank_index][E_ORG_RANK_PERMISSIONS];
}

stock bool:Organizations_PlayerHasPermission(playerid, E_ORG_PERM:perm)
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
    new const orgSlot = Organizations_FindByDbId(orgId);
    if (orgSlot < 0)
    {
        return false;
    }
    new const rankIndex = Organizations_GetRankIndexByDbId(orgSlot, Character_GetOrgRankId(playerid));
    if (rankIndex < 0)
    {
        return false;
    }
    return ((sOrgRanks[orgSlot][rankIndex][E_ORG_RANK_PERMISSIONS] & _:perm) != 0);
}

stock bool:Organizations_HasPermission(char_id, org_id, E_ORG_PERM:perm)
{
    new const playerid = Internal_FindPlayerByCharId(char_id);
    if (playerid == INVALID_PLAYER_ID)
    {
        return false;
    }
    if (Character_GetOrgId(playerid) != org_id)
    {
        return false;
    }
    return Organizations_PlayerHasPermission(playerid, perm);
}

// Совместимый публичный контракт из TECH_CONTEXT.MD: Org_HasPermission(char_id, org_id, perm)
stock bool:Org_HasPermission(char_id, org_id, E_ORG_PERM:perm)
{
    return Organizations_HasPermission(char_id, org_id, perm);
}

stock Organizations_GetPlayerRankOrder(playerid)
{
    new const orgId = Character_GetOrgId(playerid);
    new const orgSlot = Organizations_FindByDbId(orgId);
    if (orgSlot < 0)
    {
        return 0;
    }
    new const rankIndex = Organizations_GetRankIndexByDbId(orgSlot, Character_GetOrgRankId(playerid));
    if (rankIndex < 0)
    {
        return 0;
    }
    return sOrgRanks[orgSlot][rankIndex][E_ORG_RANK_ORDER];
}

stock bool:Organizations_AddBankBalance(org_db_id, amount)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0 || amount <= 0)
    {
        return false;
    }

    sOrgs[slot][E_ORG_BANK_BALANCE_USD] += amount;
    if (DB_IsConnected())
    {
        new query[192];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `organizations` SET `bank_balance_usd` = `bank_balance_usd` + %d WHERE `id` = %d;",
            amount, org_db_id);
        mysql_tquery(gMySQL, query);
    }
    return true;
}

stock bool:Organizations_TakeBankBalance(org_db_id, amount)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0 || amount <= 0 || sOrgs[slot][E_ORG_BANK_FROZEN])
    {
        return false;
    }
    if (sOrgs[slot][E_ORG_BANK_BALANCE_USD] < amount)
    {
        return false;
    }

    sOrgs[slot][E_ORG_BANK_BALANCE_USD] -= amount;
    if (DB_IsConnected())
    {
        new query[224];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `organizations` SET `bank_balance_usd` = `bank_balance_usd` - %d WHERE `id` = %d AND `bank_balance_usd` >= %d AND `is_bank_frozen` = 0;",
            amount, org_db_id, amount);
        mysql_tquery(gMySQL, query);
    }
    return true;
}

stock Organizations_SetBankFrozen(org_db_id, bool:frozen)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        return 0;
    }
    sOrgs[slot][E_ORG_BANK_FROZEN] = frozen;
    if (DB_IsConnected())
    {
        new query[160];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `organizations` SET `is_bank_frozen` = %d WHERE `id` = %d;",
            frozen ? 1 : 0, org_db_id);
        mysql_tquery(gMySQL, query);
    }
    return 1;
}

stock Organizations_SetCharterFlag(org_db_id, E_CHARTER_FLAGS:flag, bool:enabled)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0 || _:flag == 0)
    {
        return 0;
    }

    new flags = sOrgs[slot][E_ORG_CHARTER_FLAGS];
    if (enabled)
    {
        flags |= _:flag;
    }
    else
    {
        flags &= ~_:flag;
    }
    sOrgs[slot][E_ORG_CHARTER_FLAGS] = flags;

    if (DB_IsConnected())
    {
        new query[160];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `organizations` SET `charter_flags` = %d WHERE `id` = %d;",
            flags, org_db_id);
        mysql_tquery(gMySQL, query);
    }
    return 1;
}

stock Organizations_SetLegalStatus(org_db_id, E_ORG_LEGAL_STATUS:status)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        return 0;
    }
    sOrgs[slot][E_ORG_STATUS] = status;
    if (DB_IsConnected())
    {
        new statusStr[24], query[160];
        Organizations_GetStatusString(status, statusStr, sizeof(statusStr));
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `organizations` SET `legal_status` = '%e' WHERE `id` = %d;",
            statusStr, org_db_id);
        mysql_tquery(gMySQL, query);
    }
    return 1;
}

stock Organizations_GetVaultStorage(org_db_id)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        return INVALID_STORAGE_SLOT;
    }

    new vaultSlot = sOrgs[slot][E_ORG_VAULT_SLOT];
    if (Storage_IsValidSlot(vaultSlot))
    {
        return vaultSlot;
    }

    vaultSlot = Storage_FindByDbId(sOrgs[slot][E_ORG_VAULT_DB_ID]);
    if (vaultSlot == INVALID_STORAGE_SLOT && sOrgs[slot][E_ORG_VAULT_DB_ID] > 0)
    {
        vaultSlot = Storage_Create(
            STORAGE_ORG_VAULT,
            org_db_id,
            ORG_VAULT_DEFAULT_WEIGHT_G,
            ORG_VAULT_DEFAULT_VOLUME_ML,
            true,
            3,
            sOrgs[slot][E_ORG_HQ_X],
            sOrgs[slot][E_ORG_HQ_Y],
            sOrgs[slot][E_ORG_HQ_Z],
            0,
            0,
            0,
            sOrgs[slot][E_ORG_VAULT_DB_ID]);
    }
    sOrgs[slot][E_ORG_VAULT_SLOT] = vaultSlot;
    return vaultSlot;
}

stock Organizations_GetVaultDbId(org_db_id)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        return 0;
    }
    return sOrgs[slot][E_ORG_VAULT_DB_ID];
}

stock Organizations_NotifyMembers(org_db_id, const message[])
{
    foreach (new playerid : Player)
    {
        if (Character_IsLoaded(playerid) && Character_GetOrgId(playerid) == org_db_id)
        {
            SendClientMessage(playerid, COLOR_UI_INFO, message);
        }
    }
    return 1;
}

stock Organizations_GrantMembership(playerid, org_db_id, rank_db_id)
{
    if (!Character_IsLoaded(playerid) || !Organizations_IsValid(org_db_id))
    {
        return 0;
    }
    Character_SetOrgMembership(playerid, org_db_id, rank_db_id);
    return 1;
}

stock Organizations_RevokeMembership(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }
    Character_SetOrgMembership(playerid, 0, 0);
    return 1;
}

// Начисление налоговых поступлений в казну Правительства (вызывается из mod_banking)
public Organizations_AddGovernmentFunds(amount, const details[])
{
    if (amount <= 0)
    {
        return 0;
    }
    if (!Organizations_AddBankBalance(ORG_GOVERNMENT_DB_ID, amount))
    {
        return 0;
    }
    Audit_Log(0, "GOV_TAX", "ECONOMY", "GOVERNMENT_BANK", 0, amount, details);
    return 1;
}

// Уведомление аналитиков ФБР и ЦРУ о подозрительной финансовой активности
public Organizations_SendFinancialAlert(source_org_id, actor_char_id, amount, const details[])
{
    #pragma unused source_org_id
    new const fbiSlot = Organizations_FindByTag("FBI");
    new const ciaSlot = Organizations_FindByTag("CIA");
    if (fbiSlot < 0 && ciaSlot < 0)
    {
        return 0;
    }

    foreach (new playerid : Player)
    {
        if (!Character_IsLoaded(playerid))
        {
            continue;
        }
        new const orgId = Character_GetOrgId(playerid);
        if (orgId == ORG_FBI_DB_ID || orgId == ORG_CIA_DB_ID)
        {
            new alert[256];
            format(alert, sizeof(alert),
                "[Финансовая аналитика] Подозрительная операция на %d USD. %s",
                amount, details);
            SendClientMessage(playerid, COLOR_UI_WARNING, alert);
        }
    }

    Audit_Log(actor_char_id, "FIN_ALERT", "BANK", "FBI_CIA", 0, amount, details);
    return 1;
}

static stock Internal_GetEntryRankIndex(org_slot)
{
    if (org_slot < 0 || sOrgs[org_slot][E_ORG_RANK_COUNT] <= 0)
    {
        return -1;
    }
    for (new r = 0; r < sOrgs[org_slot][E_ORG_RANK_COUNT]; r++)
    {
        if (sOrgRanks[org_slot][r][E_ORG_RANK_VALID] &&
            !strcmp(sOrgRanks[org_slot][r][E_ORG_RANK_TITLE], "Сотрудник организации", false))
        {
            return r;
        }
    }
    return 0;
}

static stock Internal_GetHighestRankIndex(org_slot)
{
    if (org_slot < 0 || sOrgs[org_slot][E_ORG_RANK_COUNT] <= 0)
    {
        return -1;
    }
    return sOrgs[org_slot][E_ORG_RANK_COUNT] - 1;
}

static stock Internal_CanManageOrganization(playerid, E_ORG_PERM:perm)
{
    if (!Organizations_PlayerHasPermission(playerid, perm))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Недостаточно прав: ваша должность не имеет соответствующего разрешения.");
        return 0;
    }
    return 1;
}

static stock bool:Internal_OrgCommandAllowed(playerid)
{
    new const nowTick = GetTickCount();
    if ((nowTick - sOrgLastCommandTick[playerid]) < ORG_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "Не так быстро: дождитесь завершения предыдущей операции.");
        return false;
    }
    sOrgLastCommandTick[playerid] = nowTick;
    return true;
}

static stock bool:Internal_ParsePositiveInt(const input[], &outValue)
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
    return (outValue > 0);
}

static stock Internal_ParseInts(const params[], values[], maxValues)
{
    new count = 0;
    new i = 0;
    new const len = strlen(params);

    while (i < len && count < maxValues)
    {
        while (i < len && params[i] == ' ')
        {
            i++;
        }
        if (i >= len)
        {
            break;
        }

        new sign = 1;
        if (params[i] == '-')
        {
            sign = -1;
            i++;
        }
        new value = 0;
        new digits = 0;
        while (i < len && params[i] >= '0' && params[i] <= '9')
        {
            value = (value * 10) + (params[i] - '0');
            i++;
            digits++;
        }
        if (digits == 0)
        {
            break;
        }
        values[count++] = value * sign;
    }
    return count;
}

static stock Internal_PlayerHasItemInLayer1(playerid, def_id)
{
    new const layer1 = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1))
    {
        return 0;
    }
    new itemSlot = Storage_GetFirstItemSlot(layer1);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        if (Storage_GetItemDefId(itemSlot) == def_id)
        {
            return 1;
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }
    return 0;
}

static stock Internal_FormatRadioFreq(freq, output[], len = sizeof(output))
{
    if (freq <= 0)
    {
        format(output, len, "не настроена");
    }
    else
    {
        format(output, len, "%d.%d МГц", freq / 1000, (freq % 1000) / 100);
    }
    return 1;
}

// =============================================================================
//  5. ИНТЕРФЕЙС УПРАВЛЕНИЯ ОРГАНИЗАЦИЕЙ
// =============================================================================

static stock Internal_ShowOrgList(playerid)
{
    new rowCount = 0;
    sOrgDialogBuffer[0] = '\0';
    strcat(sOrgDialogBuffer, "Создать новую организацию\n", sizeof(sOrgDialogBuffer));

    foreach (new slot : OrganizationIter)
    {
        if (!sOrgs[slot][E_ORG_VALID] || rowCount >= (ORG_MAX_LIST_ROWS - 1))
        {
            continue;
        }

        new statusName[48];
        Organizations_GetStatusTitleRu(sOrgs[slot][E_ORG_STATUS], statusName, sizeof(statusName));

        new row[192];
        format(row, sizeof(row), "[%s] %s | %s\n",
            sOrgs[slot][E_ORG_TAG], sOrgs[slot][E_ORG_NAME], statusName);
        if ((strlen(sOrgDialogBuffer) + strlen(row)) >= sizeof(sOrgDialogBuffer))
        {
            break;
        }
        strcat(sOrgDialogBuffer, row, sizeof(sOrgDialogBuffer));
        sOrgListRowMap[playerid][rowCount + 1] = sOrgs[slot][E_ORG_DB_ID];
        rowCount++;
    }

    sOrgListRowCount[playerid] = rowCount + 1;
    sOrgListRowMap[playerid][0] = 0;

    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_LIST,
        DIALOG_STYLE_LIST,
        "{FFC800}Реестр организаций штата Сан-Андреас",
        sOrgDialogBuffer,
        "Выбрать",
        "Закрыть");
    return 1;
}

static stock Internal_ShowOrgInfo(playerid, org_db_id)
{
    new const slot = Organizations_FindByDbId(org_db_id);
    if (slot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Организация не найдена.");
        return 0;
    }

    new statusName[48], radioText[32], bankText[32];
    Organizations_GetStatusTitleRu(sOrgs[slot][E_ORG_STATUS], statusName, sizeof(statusName));
    Internal_FormatRadioFreq(sOrgs[slot][E_ORG_RADIO_FREQ], radioText, sizeof(radioText));
    Utils_FormatMoney(sOrgs[slot][E_ORG_BANK_BALANCE_USD], bankText);

    new body[768];
    format(body, sizeof(body),
        "{FFC800}Название:{FFFFFF} %s\n" \
        "{FFC800}Тег:{FFFFFF} %s\n" \
        "{FFC800}Правовой статус:{FFFFFF} %s\n" \
        "{FFC800}Системная фракция:{FFFFFF} %s\n" \
        "{FFC800}Флаги хартии:{FFFFFF} %d\n" \
        "{FFC800}Радиочастота:{FFFFFF} %s\n" \
        "{FFC800}Штаб-квартира:{FFFFFF} %.1f, %.1f, %.1f\n" \
        "{FFC800}Безналичный счет:{FFFFFF} %s (%s)\n" \
        "{FFC800}Должностей в иерархии:{FFFFFF} %d",
        sOrgs[slot][E_ORG_NAME],
        sOrgs[slot][E_ORG_TAG],
        statusName,
        sOrgs[slot][E_ORG_IS_PERMANENT] ? ("да") : ("нет"),
        sOrgs[slot][E_ORG_CHARTER_FLAGS],
        radioText,
        sOrgs[slot][E_ORG_HQ_X], sOrgs[slot][E_ORG_HQ_Y], sOrgs[slot][E_ORG_HQ_Z],
        bankText,
        sOrgs[slot][E_ORG_BANK_FROZEN] ? ("заморожен") : ("активен"),
        sOrgs[slot][E_ORG_RANK_COUNT]);

    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_INFO,
        DIALOG_STYLE_MSGBOX,
        "{FFC800}Карточка организации",
        body,
        "Закрыть",
        "");
    return 1;
}

static stock Internal_ShowOrgMenu(playerid)
{
    new const orgId = Character_GetOrgId(playerid);
    if (orgId <= 0)
    {
        Internal_ShowOrgList(playerid);
        return 0;
    }

    new const slot = Organizations_FindByDbId(orgId);
    if (slot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Ваша организация не найдена в реестре.");
        return 0;
    }

    new count = 0;
    sOrgDialogBuffer[0] = '\0';
    strcat(sOrgDialogBuffer, "Информация об организации\n", sizeof(sOrgDialogBuffer));
    sOrgMenuAction[playerid][count++] = ORG_MENU_INFO;

    strcat(sOrgDialogBuffer, "Иерархия должностей и матрица прав доступа\n", sizeof(sOrgDialogBuffer));
    sOrgMenuAction[playerid][count++] = ORG_MENU_RANKS;

    if (Organizations_PlayerHasPermission(playerid, ORG_PERM_RANKS))
    {
        strcat(sOrgDialogBuffer, "Конструктор должностей и подразделений\n", sizeof(sOrgDialogBuffer));
        sOrgMenuAction[playerid][count++] = ORG_MENU_RANK_BUILDER;

        strcat(sOrgDialogBuffer, "Юридический статус и хартия\n", sizeof(sOrgDialogBuffer));
        sOrgMenuAction[playerid][count++] = ORG_MENU_CHARTER;
    }

    if (Organizations_PlayerHasPermission(playerid, ORG_PERM_HIRE))
    {
        strcat(sOrgDialogBuffer, "Список сотрудников и управление кадрами\n", sizeof(sOrgDialogBuffer));
        sOrgMenuAction[playerid][count++] = ORG_MENU_MEMBERS;
    }

    if (Organizations_PlayerHasPermission(playerid, ORG_PERM_ARMORY))
    {
        strcat(sOrgDialogBuffer, "Открыть бронированную казну-сейф\n", sizeof(sOrgDialogBuffer));
        sOrgMenuAction[playerid][count++] = ORG_MENU_VAULT;
    }

    if (Organizations_PlayerHasPermission(playerid, ORG_PERM_BANK))
    {
        strcat(sOrgDialogBuffer, "Безналичный счет организации\n", sizeof(sOrgDialogBuffer));
        sOrgMenuAction[playerid][count++] = ORG_MENU_BANK;
    }

    if (Organizations_PlayerHasPermission(playerid, ORG_PERM_RADIO))
    {
        strcat(sOrgDialogBuffer, "Настройка радиочастоты\n", sizeof(sOrgDialogBuffer));
        sOrgMenuAction[playerid][count++] = ORG_MENU_RADIO;
    }

    strcat(sOrgDialogBuffer, "Покинуть организацию\n", sizeof(sOrgDialogBuffer));
    sOrgMenuAction[playerid][count++] = ORG_MENU_LEAVE;

    sOrgMenuActionCount[playerid] = count;

    new caption[160];
    format(caption, sizeof(caption),
        "{FFC800}%s [%s] {FFFFFF}| Панель управления",
        sOrgs[slot][E_ORG_NAME], sOrgs[slot][E_ORG_TAG]);
    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_MAIN,
        DIALOG_STYLE_LIST,
        caption,
        sOrgDialogBuffer,
        "Выбрать",
        "Закрыть");
    return 1;
}

static stock Internal_ShowRankList(playerid, bool:editMode)
{
    new const orgId = Character_GetOrgId(playerid);
    new const slot = Organizations_FindByDbId(orgId);
    if (slot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Организация не найдена.");
        return 0;
    }

    new count = 0;
    sOrgDialogBuffer[0] = '\0';
    for (new r = sOrgs[slot][E_ORG_RANK_COUNT] - 1; r >= 0; r--)
    {
        if (!sOrgRanks[slot][r][E_ORG_RANK_VALID] || count >= MAX_ORG_RANKS)
        {
            continue;
        }
        new row[192];
        format(row, sizeof(row), "%d. %s | оклад: %d USD | права: %d\n",
            sOrgRanks[slot][r][E_ORG_RANK_ORDER],
            sOrgRanks[slot][r][E_ORG_RANK_TITLE],
            sOrgRanks[slot][r][E_ORG_RANK_SALARY_USD],
            sOrgRanks[slot][r][E_ORG_RANK_PERMISSIONS]);
        if ((strlen(sOrgDialogBuffer) + strlen(row)) >= sizeof(sOrgDialogBuffer))
        {
            break;
        }
        strcat(sOrgDialogBuffer, row, sizeof(sOrgDialogBuffer));
        sOrgRankRowMap[playerid][count++] = r;
    }
    sOrgRankRowCount[playerid] = count;

    if (count == 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "В организации еще нет настроенных должностей.");
        return 0;
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_RANKS,
        DIALOG_STYLE_LIST,
        editMode ? ("{FFC800}Конструктор должностей организации") : ("{FFC800}Иерархия должностей организации"),
        sOrgDialogBuffer,
        editMode ? ("Изменить") : ("Закрыть"),
        "Назад");
    return 1;
}

static stock Internal_ShowRankEdit(playerid, rank_index)
{
    new const orgId = Character_GetOrgId(playerid);
    new const slot = Organizations_FindByDbId(orgId);
    if (slot < 0 || rank_index < 0 || rank_index >= sOrgs[slot][E_ORG_RANK_COUNT])
    {
        return 0;
    }

    sOrgRankEditIndex[playerid] = rank_index;

    new body[512];
    format(body, sizeof(body),
        "{FFC800}Должность:{FFFFFF} %s\n" \
        "{FFC800}Порядок в иерархии:{FFFFFF} %d\n" \
        "{FFC800}Оклад:{FFFFFF} %d USD\n" \
        "{FFC800}Маска прав доступа:{FFFFFF} %d\n\n" \
        "1 — рация, 2 — автопарк, 4 — оружейка и склад, 8 — найм и увольнение, 16 — казна и банк, 32 — управление рангами.",
        sOrgRanks[slot][rank_index][E_ORG_RANK_TITLE],
        sOrgRanks[slot][rank_index][E_ORG_RANK_ORDER],
        sOrgRanks[slot][rank_index][E_ORG_RANK_SALARY_USD],
        sOrgRanks[slot][rank_index][E_ORG_RANK_PERMISSIONS]);

    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_RANK_EDIT,
        DIALOG_STYLE_LIST,
        "{FFC800}Редактирование должности",
        "Изменить название должности\n" \
        "Изменить оклад\n" \
        "Настроить права доступа должности\n" \
        "Удалить должность",
        "Выбрать",
        "Назад");
    return 1;
}

static stock Internal_ShowRankPermissions(playerid, rank_index)
{
    new const orgId = Character_GetOrgId(playerid);
    new const slot = Organizations_FindByDbId(orgId);
    if (slot < 0 || rank_index < 0 || rank_index >= sOrgs[slot][E_ORG_RANK_COUNT])
    {
        return 0;
    }

    sOrgPermRankIndex[playerid] = rank_index;
    new const mask = sOrgRanks[slot][rank_index][E_ORG_RANK_PERMISSIONS];

    new body[512];
    format(body, sizeof(body),
        "%s рация и управление связью\n" \
        "%s доступ к автопарку\n" \
        "%s доступ к оружейке и складу\n" \
        "%s найм, увольнение и повышение\n" \
        "%s доступ к казне и банковскому счету\n" \
        "%s управление должностями и хартией",
        (mask & _:ORG_PERM_RADIO) ? ("[X]") : ("[ ]"),
        (mask & _:ORG_PERM_FLEET) ? ("[X]") : ("[ ]"),
        (mask & _:ORG_PERM_ARMORY) ? ("[X]") : ("[ ]"),
        (mask & _:ORG_PERM_HIRE) ? ("[X]") : ("[ ]"),
        (mask & _:ORG_PERM_BANK) ? ("[X]") : ("[ ]"),
        (mask & _:ORG_PERM_RANKS) ? ("[X]") : ("[ ]"));

    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_RANK_PERMS,
        DIALOG_STYLE_LIST,
        "{FFC800}Матрица прав должности",
        body,
        "Переключить",
        "Назад");
    return 1;
}

static stock Internal_ShowMemberActions(playerid)
{
    new const memberIndex = sOrgPendingMember[playerid];
    if (memberIndex < 0 || memberIndex >= sOrgMemberCount[playerid])
    {
        return 0;
    }

    new body[384];
    format(body, sizeof(body),
        "{FFC800}Сотрудник:{FFFFFF} %s\n" \
        "{FFC800}Идентификатор персонажа:{FFFFFF} %d\n\n" \
        "Выберите кадровое действие.",
        sOrgMemberName[playerid][memberIndex],
        sOrgMemberCharId[playerid][memberIndex]);

    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_MEMBER_ACTIONS,
        DIALOG_STYLE_LIST,
        "{FFC800}Управление сотрудником",
        body,
        "Выбрать",
        "Назад");
    return 1;
}

static stock Internal_ShowPromotionRanks(playerid)
{
    new const orgId = Character_GetOrgId(playerid);
    new const slot = Organizations_FindByDbId(orgId);
    if (slot < 0)
    {
        return 0;
    }

    sOrgDialogBuffer[0] = '\0';
    new count = 0;
    for (new r = sOrgs[slot][E_ORG_RANK_COUNT] - 1; r >= 0; r--)
    {
        if (!sOrgRanks[slot][r][E_ORG_RANK_VALID] || count >= MAX_ORG_RANKS)
        {
            continue;
        }
        new row[128];
        format(row, sizeof(row), "%d. %s\n",
            sOrgRanks[slot][r][E_ORG_RANK_ORDER],
            sOrgRanks[slot][r][E_ORG_RANK_TITLE]);
        if ((strlen(sOrgDialogBuffer) + strlen(row)) >= sizeof(sOrgDialogBuffer))
        {
            break;
        }
        strcat(sOrgDialogBuffer, row, sizeof(sOrgDialogBuffer));
        sOrgRankRowMap[playerid][count++] = r;
    }
    sOrgRankRowCount[playerid] = count;

    if (count == 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "Нет доступных должностей для назначения.");
        return 0;
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_PROMOTE,
        DIALOG_STYLE_LIST,
        "{FFC800}Назначение на должность",
        sOrgDialogBuffer,
        "Назначить",
        "Назад");
    return 1;
}

static stock Internal_ShowBankMenu(playerid)
{
    new const orgId = Character_GetOrgId(playerid);
    if (!Organizations_IsValid(orgId))
    {
        return 0;
    }
    if (!Organizations_HasCharterFlag(orgId, FLAG_CAN_BANK))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "У вашей организации нет права на безналичный банковский счет (отсутствует право на банковский счет).");
        return 0;
    }
    if (Organizations_IsBankFrozen(orgId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Банковский счет организации заморожен по решению суда или ФБР.");
        return 0;
    }

    new balanceStr[32];
    Utils_FormatMoney(Organizations_GetBankBalance(orgId), balanceStr);

    new body[256];
    format(body, sizeof(body),
        "{FFC800}Баланс организации:{FFFFFF} %s\n\n" \
        "1. Пополнить счет с личного банковского счета\n" \
        "2. Снять средства на личный банковский счет",
        balanceStr);

    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_BANK,
        DIALOG_STYLE_LIST,
        "{FFC800}Безналичный счет организации",
        body,
        "Выбрать",
        "Назад");
    return 1;
}

static stock Internal_ShowRadioInput(playerid)
{
    new freqText[32];
    Internal_FormatRadioFreq(Organizations_GetRadioFreq(Character_GetOrgId(playerid)), freqText, sizeof(freqText));

    new body[256];
    format(body, sizeof(body),
        "Текущая частота: %s.\n\n" \
        "Введите новую частоту в килогерцах: от 100000 до 999900.\n" \
        "Например, 100100 соответствует частоте 100.1 МГц.",
        freqText);
    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_RADIO_INPUT,
        DIALOG_STYLE_INPUT,
        "{FFC800}Настройка радиочастоты организации",
        body,
        "Сохранить",
        "Отмена");
    return 1;
}

static stock Internal_ShowCharterHelp(playerid)
{
    SendClientMessage(playerid, COLOR_UI_INFO,
        "Хартия организации: /orgcharter [id] [флаг] [1/0]. Флаги: 1 — банк, 2 — тяжелое оружие, 4 — ордера,");
    SendClientMessage(playerid, COLOR_UI_INFO,
        "8 — прослушка, 16 — пограничный контроль, 32 — операции вне правового поля. Доступно Правительству.");
    return 1;
}

static stock Internal_CreateRankDialog(playerid)
{
    if (!Internal_CanManageOrganization(playerid, ORG_PERM_RANKS))
    {
        return 0;
    }
    new const orgId = Character_GetOrgId(playerid);
    new const slot = Organizations_FindByDbId(orgId);
    if (slot < 0)
    {
        return 0;
    }
    if (sOrgs[slot][E_ORG_RANK_COUNT] >= MAX_ORG_RANKS)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Достигнут предел в 20 должностей организации.");
        return 0;
    }

    // Новая должность всегда становится низшей в иерархии,
    // поэтому существующие порядковые номера сдвигаются на единицу вверх.
    for (new r = 0; r < sOrgs[slot][E_ORG_RANK_COUNT]; r++)
    {
        sOrgRanks[slot][r][E_ORG_RANK_ORDER]++;
        if (DB_IsConnected())
        {
            new shiftQuery[192];
            mysql_format(gMySQL, shiftQuery, sizeof(shiftQuery),
                "UPDATE `organization_ranks` SET `rank_order` = %d WHERE `id` = %d;",
                sOrgRanks[slot][r][E_ORG_RANK_ORDER],
                sOrgRanks[slot][r][E_ORG_RANK_DB_ID]);
            mysql_pquery(gMySQL, shiftQuery);
        }
    }

    new const rankOrder = 1;
    new const rankId = sNextRankDbId++;
    new const rankIndex = Internal_AddRank(
        slot,
        rankId,
        rankOrder,
        "Новая должность",
        0,
        _:ORG_PERM_RADIO);

    if (rankIndex < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось создать должность.");
        return 0;
    }

    if (DB_IsConnected())
    {
        new query[320];
        mysql_format(gMySQL, query, sizeof(query),
            "INSERT INTO `organization_ranks` (`id`, `org_id`, `rank_order`, `title`, `salary_usd`, `permissions_mask`) VALUES (%d, %d, %d, '%e', 0, %d);",
            rankId, orgId, rankOrder, "Новая должность", _:ORG_PERM_RADIO);
        mysql_pquery(gMySQL, query);
    }

    Audit_Log(Character_GetId(playerid), "ORG_RANK_CREATE", "ORG", "ORG_RANK", 0, rankOrder, "Создана новая должность");
    Internal_ShowRankEdit(playerid, rankIndex);
    return 1;
}

static stock Internal_DeleteRank(playerid, rank_index)
{
    if (!Internal_CanManageOrganization(playerid, ORG_PERM_RANKS))
    {
        return 0;
    }
    new const orgId = Character_GetOrgId(playerid);
    new const slot = Organizations_FindByDbId(orgId);
    if (slot < 0 || rank_index < 0 || rank_index >= sOrgs[slot][E_ORG_RANK_COUNT])
    {
        return 0;
    }
    if (sOrgs[slot][E_ORG_RANK_COUNT] <= 1)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Нельзя удалить последнюю должность организации.");
        return 0;
    }
    if (rank_index == Internal_GetHighestRankIndex(slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Нельзя удалить высшую должность руководителя.");
        return 0;
    }

    new const rankDbId = sOrgRanks[slot][rank_index][E_ORG_RANK_DB_ID];
    new const rankOrder = sOrgRanks[slot][rank_index][E_ORG_RANK_ORDER];

    for (new i = rank_index; i < sOrgs[slot][E_ORG_RANK_COUNT] - 1; i++)
    {
        sOrgRanks[slot][i] = sOrgRanks[slot][i + 1];
    }
    sOrgs[slot][E_ORG_RANK_COUNT]--;

    // Снимаем удаленную должность у сотрудников, находящихся в сети
    foreach (new memberPlayer : Player)
    {
        if (Character_IsLoaded(memberPlayer) &&
            Character_GetOrgId(memberPlayer) == orgId &&
            Character_GetOrgRankId(memberPlayer) == rankDbId)
        {
            Character_SetOrgMembership(memberPlayer, orgId, 0);
            SendClientMessage(memberPlayer, COLOR_UI_WARNING,
                "Ваша должность была упразднена руководством организации.");
        }
    }

    if (DB_IsConnected())
    {
        new query[384];
        mysql_format(gMySQL, query, sizeof(query),
            "START TRANSACTION; UPDATE `characters` SET `org_rank_id` = NULL WHERE `org_rank_id` = %d; DELETE FROM `organization_ranks` WHERE `id` = %d; COMMIT;",
            rankDbId, rankDbId);
        mysql_tquery(gMySQL, query);
    }

    Audit_Log(Character_GetId(playerid), "ORG_RANK_DELETE", "ORG", "ORG_RANK", 0, rankOrder, "Удалена должность организации");
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Должность удалена. Сотрудники переведены в резерв без должности.");
    Internal_ShowRankList(playerid, true);
    return 1;
}

static stock Internal_ApplyRankTitle(playerid, rank_index, const title[])
{
    if (!Internal_CanManageOrganization(playerid, ORG_PERM_RANKS))
    {
        return 0;
    }
    if (title[0] == EOS || strlen(title) >= ORG_RANK_TITLE_LEN)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Название должности не должно быть пустым и длиннее 47 символов.");
        return 0;
    }

    new const orgId = Character_GetOrgId(playerid);
    new const slot = Organizations_FindByDbId(orgId);
    if (slot < 0 || rank_index < 0 || rank_index >= sOrgs[slot][E_ORG_RANK_COUNT])
    {
        return 0;
    }

    format(sOrgRanks[slot][rank_index][E_ORG_RANK_TITLE], ORG_RANK_TITLE_LEN, "%s", title);
    if (DB_IsConnected())
    {
        new query[256];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `organization_ranks` SET `title` = '%e' WHERE `id` = %d;",
            title, sOrgRanks[slot][rank_index][E_ORG_RANK_DB_ID]);
        mysql_tquery(gMySQL, query);
    }

    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Название должности обновлено.");
    Internal_ShowRankEdit(playerid, rank_index);
    return 1;
}

static stock Internal_ApplyRankSalary(playerid, rank_index, salary)
{
    if (!Internal_CanManageOrganization(playerid, ORG_PERM_RANKS))
    {
        return 0;
    }
    if (salary < 0 || salary > 1000000)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Оклад должен быть в пределах от 0 до 1 000 000 USD.");
        return 0;
    }

    new const orgId = Character_GetOrgId(playerid);
    new const slot = Organizations_FindByDbId(orgId);
    if (slot < 0 || rank_index < 0 || rank_index >= sOrgs[slot][E_ORG_RANK_COUNT])
    {
        return 0;
    }

    sOrgRanks[slot][rank_index][E_ORG_RANK_SALARY_USD] = salary;
    if (DB_IsConnected())
    {
        new query[192];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `organization_ranks` SET `salary_usd` = %d WHERE `id` = %d;",
            salary, sOrgRanks[slot][rank_index][E_ORG_RANK_DB_ID]);
        mysql_tquery(gMySQL, query);
    }

    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Оклад должности обновлен.");
    Internal_ShowRankEdit(playerid, rank_index);
    return 1;
}

static stock Internal_ToggleRankPermission(playerid, rank_index, permission)
{
    if (!Internal_CanManageOrganization(playerid, ORG_PERM_RANKS))
    {
        return 0;
    }
    new const orgId = Character_GetOrgId(playerid);
    new const slot = Organizations_FindByDbId(orgId);
    if (slot < 0 || rank_index < 0 || rank_index >= sOrgs[slot][E_ORG_RANK_COUNT])
    {
        return 0;
    }

    new mask = sOrgRanks[slot][rank_index][E_ORG_RANK_PERMISSIONS];
    if (mask & permission)
    {
        mask &= ~permission;
    }
    else
    {
        mask |= permission;
    }
    sOrgRanks[slot][rank_index][E_ORG_RANK_PERMISSIONS] = mask;

    if (DB_IsConnected())
    {
        new query[192];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `organization_ranks` SET `permissions_mask` = %d WHERE `id` = %d;",
            mask, sOrgRanks[slot][rank_index][E_ORG_RANK_DB_ID]);
        mysql_tquery(gMySQL, query);
    }

    Internal_ShowRankPermissions(playerid, rank_index);
    return 1;
}

static stock Internal_CreateOrganizationFlow(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }
    new const E_ORG_LEGAL_STATUS:status = E_ORG_LEGAL_STATUS:sOrgCreateStatus[playerid];
    new const actorOrg = Character_GetOrgId(playerid);

    if (status == ORG_STATUS_STATE_AGENCY)
    {
        if (actorOrg != ORG_GOVERNMENT_DB_ID || Organizations_GetPlayerRankOrder(playerid) < 5)
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "Государственное ведомство может учредить только действующий губернатор штата.");
            return 0;
        }
    }
    else if (actorOrg > 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Сначала покиньте текущую организацию.");
        return 0;
    }

    if (Internal_OrgNameExists(sOrgCreateName[playerid]) ||
        Internal_OrgTagExists(sOrgCreateTag[playerid]))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Организация с таким названием или тегом уже существует в реестре.");
        return 0;
    }

    new cost = ORG_CREATE_COST_UNREGISTERED_USD;
    if (status == ORG_STATUS_PRIVATE_CORP)
    {
        cost = ORG_CREATE_COST_CORP_USD;
    }
    else if (status == ORG_STATUS_STATE_AGENCY)
    {
        cost = ORG_CREATE_COST_STATE_USD;
    }

    if (status == ORG_STATUS_PRIVATE_CORP && Roles_HasPerk(Character_GetRoleId(playerid), PERK_CORP_DISCOUNT_25))
    {
        cost = cost - ((cost * ORG_CREATE_DISCOUNT_PERCENT) / 100);
    }

    if (status == ORG_STATUS_STATE_AGENCY)
    {
        if (Organizations_IsBankFrozen(ORG_GOVERNMENT_DB_ID) ||
            Organizations_GetBankBalance(ORG_GOVERNMENT_DB_ID) < cost)
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "В казне Правительства недостаточно средств для учреждения ведомства.");
            return 0;
        }
    }
    else
    {
        if (!Banking_HasAccount(playerid))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR, "Для оплаты регистрации нужен личный банковский счет.");
            return 0;
        }
        if (Banking_IsFrozen(playerid))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR, "Ваш банковский счет заморожен: оплата регистрации невозможна.");
            return 0;
        }
        if (Banking_GetBalance(playerid) < cost)
        {
            SendClientMessage(playerid, COLOR_UI_ERROR, "На банковском счете недостаточно средств для регистрации.");
            return 0;
        }
    }

    if (Iter_Free(OrganizationIter) == INVALID_ITERATOR_SLOT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Реестр организаций переполнен. Обратитесь к администрации.");
        return 0;
    }

    new Float:hqX, Float:hqY, Float:hqZ;
    GetPlayerPos(playerid, hqX, hqY, hqZ);

    new const newOrgId = sNextOrgDbId;
    new const orgSlot = Internal_AddOrganization(
        newOrgId,
        sOrgCreateName[playerid],
        sOrgCreateTag[playerid],
        status,
        false,
        (status == ORG_STATUS_UNREGISTERED) ? 0 : _:FLAG_CAN_BANK,
        0,
        0,
        false,
        0,
        hqX, hqY, hqZ);

    if (orgSlot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось создать организацию: внутренний предел пула.");
        return 0;
    }

    // Создаем физическую казну-сейф для новой организации
    new const vaultSlot = Storage_Create(
        STORAGE_ORG_VAULT,
        newOrgId,
        ORG_VAULT_DEFAULT_WEIGHT_G,
        ORG_VAULT_DEFAULT_VOLUME_ML,
        true,
        3,
        hqX, hqY, hqZ,
        0,
        0);
    if (vaultSlot == INVALID_STORAGE_SLOT)
    {
        Iter_Remove(OrganizationIter, orgSlot);
        Internal_ResetOrganizationSlot(orgSlot);
        SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось создать казну организации.");
        return 0;
    }

    sOrgs[orgSlot][E_ORG_VAULT_SLOT] = vaultSlot;
    sOrgs[orgSlot][E_ORG_VAULT_DB_ID] = Storage_GetDbId(vaultSlot);

    new const memberRankId = sNextRankDbId++;
    new const memberRankIndex = Internal_AddRank(
        orgSlot,
        memberRankId,
        1,
        "Сотрудник организации",
        1000,
        _:ORG_PERM_RADIO | _:ORG_PERM_FLEET);
    if (memberRankIndex < 0)
    {
        Storage_DestroyExpiredOrEmpty(vaultSlot);
        Iter_Remove(OrganizationIter, orgSlot);
        Internal_ResetOrganizationSlot(orgSlot);
        SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось создать базовую должность организации.");
        return 0;
    }

    new const leaderRankId = sNextRankDbId++;
    new const leaderRankIndex = Internal_AddRank(
        orgSlot,
        leaderRankId,
        2,
        "Лидер организации",
        5000,
        ORG_PERM_FULL_MASK);
    if (leaderRankIndex < 0)
    {
        Storage_DestroyExpiredOrEmpty(vaultSlot);
        Iter_Remove(OrganizationIter, orgSlot);
        Internal_ResetOrganizationSlot(orgSlot);
        SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось создать должность лидера.");
        return 0;
    }

    if (DB_IsConnected())
    {
        new statusStr[24];
        Organizations_GetStatusString(status, statusStr, sizeof(statusStr));

        new query[768];
        mysql_format(gMySQL, query, sizeof(query),
            "INSERT INTO `organizations` (`id`, `name`, `tag`, `legal_status`, `is_permanent`, `charter_flags`, `vault_storage_id`, `bank_balance_usd`, `is_bank_frozen`, `radio_freq`, `hq_x`, `hq_y`, `hq_z`) VALUES (%d, '%e', '%e', '%e', 0, %d, %d, 0, 0, 0, %.2f, %.2f, %.2f);",
            newOrgId,
            sOrgCreateName[playerid],
            sOrgCreateTag[playerid],
            statusStr,
            sOrgs[orgSlot][E_ORG_CHARTER_FLAGS],
            sOrgs[orgSlot][E_ORG_VAULT_DB_ID],
            sOrgs[orgSlot][E_ORG_HQ_X],
            sOrgs[orgSlot][E_ORG_HQ_Y],
            sOrgs[orgSlot][E_ORG_HQ_Z]);
        mysql_pquery(gMySQL, query);

        mysql_format(gMySQL, query, sizeof(query),
            "INSERT INTO `organization_ranks` (`id`, `org_id`, `rank_order`, `title`, `salary_usd`, `permissions_mask`) VALUES (%d, %d, 1, '%e', 1000, %d);",
            memberRankId, newOrgId, "Сотрудник организации", _:ORG_PERM_RADIO | _:ORG_PERM_FLEET);
        mysql_pquery(gMySQL, query);

        mysql_format(gMySQL, query, sizeof(query),
            "INSERT INTO `organization_ranks` (`id`, `org_id`, `rank_order`, `title`, `salary_usd`, `permissions_mask`) VALUES (%d, %d, 2, '%e', 5000, %d);",
            leaderRankId, newOrgId, "Лидер организации", ORG_PERM_FULL_MASK);
        mysql_pquery(gMySQL, query);
    }

    if (status == ORG_STATUS_STATE_AGENCY)
    {
        Organizations_TakeBankBalance(ORG_GOVERNMENT_DB_ID, cost);
    }
    else
    {
        Banking_DebitAccount(playerid, cost, "Регистрация организации");
    }
    Character_SetOrgMembership(playerid, newOrgId, leaderRankId);
    sNextOrgDbId++;

    new amountStr[32], msg[256];
    Utils_FormatMoney(cost, amountStr);
    format(msg, sizeof(msg),
        "Организация «%s» [%s] успешно зарегистрирована. Стоимость: %s. Вы назначены лидером.",
        sOrgCreateName[playerid], sOrgCreateTag[playerid], amountStr);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new details[192];
    format(details, sizeof(details), "Создана организация #%d «%s»", newOrgId, sOrgCreateName[playerid]);
    Audit_Log(Character_GetId(playerid), "ORG_CREATE", "CHARACTER", "ORG", 0, cost, details);
    return 1;
}

static stock Internal_ShowCreateStatus(playerid)
{
    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_CREATE_STATUS,
        DIALOG_STYLE_LIST,
        "{FFC800}Регистрация новой организации",
        "Незарегистрированная группировка (250 000 USD)\n" \
        "Частная корпорация с банковским счетом (500 000 USD)\n" \
        "Государственное ведомство (2 000 000 USD, только для Правительства)",
        "Выбрать",
        "Отмена");
    return 1;
}

static stock Internal_ShowCreateName(playerid)
{
    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_CREATE_NAME,
        DIALOG_STYLE_INPUT,
        "{FFC800}Название организации",
        "Введите полное название организации (до 63 символов).\n" \
        "Название будет отображаться в реестре и на панели управления.",
        "Далее",
        "Отмена");
    return 1;
}

static stock Internal_ShowCreateTag(playerid)
{
    new body[256];
    format(body, sizeof(body),
        "Организация: %s\n\n" \
        "Введите короткий тег организации (до 7 символов, латиница или цифры).\n" \
        "Тег используется в рации и списках сотрудников.",
        sOrgCreateName[playerid]);
    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_CREATE_TAG,
        DIALOG_STYLE_INPUT,
        "{FFC800}Тег организации",
        body,
        "Зарегистрировать",
        "Отмена");
    return 1;
}

static stock Internal_LoadMembers(playerid)
{
    new const orgId = Character_GetOrgId(playerid);
    if (orgId <= 0)
    {
        return 0;
    }
    if (!DB_IsConnected())
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "Список сотрудников доступен только при подключенной базе данных.");
        return 0;
    }

    new query[512];
    mysql_format(gMySQL, query, sizeof(query),
        "SELECT c.`id` AS `char_id`, c.`rp_name`, IFNULL(c.`org_rank_id`, 0) AS `rank_id`, IFNULL(r.`title`, 'Без должности') AS `rank_title`, IFNULL(r.`rank_order`, 0) AS `rank_order` FROM `characters` c LEFT JOIN `organization_ranks` r ON r.`id` = c.`org_rank_id` WHERE c.`org_id` = %d AND c.`is_ck_dead` = 0 ORDER BY `rank_order` DESC, c.`rp_name` ASC LIMIT %d;",
        orgId,
        ORG_MAX_MEMBER_ROWS);
    mysql_tquery(gMySQL, query, "OnOrgMembersLoaded", "dd",
        playerid,
        Config_GetPlayerSessionToken(playerid));
    return 1;
}

static stock bool:Internal_CanFreezeOrgBank(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return false;
    }
    new const actorOrg = Character_GetOrgId(playerid);
    new const actorRank = Organizations_GetPlayerRankOrder(playerid);

    if (actorOrg == ORG_GOVERNMENT_DB_ID && actorRank >= 5)
    {
        return true;
    }
    if (actorOrg == ORG_FBI_DB_ID && actorRank >= 4 &&
        Organizations_CanActInLegalField(ORG_FBI_DB_ID))
    {
        return true;
    }
    if (actorOrg == ORG_CIA_DB_ID && actorRank >= 4 &&
        Organizations_CanActExtralegally(ORG_CIA_DB_ID))
    {
        return true;
    }
    return false;
}

static stock Internal_FindNearestOrgVault(playerid, Float:maxRadius, &orgDbId)
{
    orgDbId = 0;
    if (!IsPlayerConnected(playerid))
    {
        return -1;
    }

    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    new const vw = GetPlayerVirtualWorld(playerid);
    new const interior = GetPlayerInterior(playerid);

    new bestSlot = -1;
    new Float:bestDist = maxRadius;

    foreach (new orgSlot : OrganizationIter)
    {
        if (!sOrgs[orgSlot][E_ORG_VALID])
        {
            continue;
        }
        new const vaultSlot = Organizations_GetVaultStorage(sOrgs[orgSlot][E_ORG_DB_ID]);
        if (!Storage_IsValidSlot(vaultSlot))
        {
            continue;
        }

        new Float:vx, Float:vy, Float:vz;
        new vInterior, vVw;
        if (!Storage_GetWorldPosition(vaultSlot, vx, vy, vz, vInterior, vVw))
        {
            continue;
        }
        if (vInterior != interior || vVw != vw)
        {
            continue;
        }

        new const Float:dist = Utils_GetDistance3D(px, py, pz, vx, vy, vz);
        if (dist <= bestDist)
        {
            bestDist = dist;
            bestSlot = orgSlot;
        }
    }

    if (bestSlot >= 0)
    {
        orgDbId = sOrgs[bestSlot][E_ORG_DB_ID];
    }
    return bestSlot;
}

static stock Internal_ExecuteVaultHeist(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }
    if (Survival_IsCuffed(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Вы скованы наручниками и не можете взламывать сейф.");
        return 0;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sOrgLastHeistTick[playerid]) < ORG_VAULT_HEIST_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "Инструмент остывает: подождите несколько секунд.");
        return 0;
    }
    sOrgLastHeistTick[playerid] = nowTick;

    new orgDbId = 0;
    new const orgSlot = Internal_FindNearestOrgVault(playerid, STORAGE_INTERACT_DISTANCE, orgDbId);
    if (orgSlot < 0 || !Organizations_IsValid(orgDbId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Рядом нет бронированной казны организации.");
        return 0;
    }

    new const vaultSlot = Organizations_GetVaultStorage(orgDbId);
    if (!Storage_IsValidSlot(vaultSlot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Хранилище казны повреждено и недоступно.");
        return 0;
    }
    if (!Storage_GetIsLocked(vaultSlot))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "Казна уже открыта. Забирайте содержимое.");
        return 0;
    }

    new const hasExplosive = Internal_PlayerHasItemInLayer1(playerid, ITEM_ID_SATCHEL_CHARGE);
    new const hasLockpick = Internal_PlayerHasItemInLayer1(playerid, ITEM_ID_SAFE_LOCKPICK_SET);
    if (!hasExplosive && !hasLockpick)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Для взлома казны нужен взрывпакет с детонатором или набор отмычек.");
        return 0;
    }

    new const lockLevel = Storage_GetLockLevel(vaultSlot);
    new chance = 0;
    if (hasExplosive)
    {
        chance = 35 + (Skills_Get(playerid, SKILL_DEMOLITIONS) / 20) - (lockLevel * 3);
        if (chance > 95)
        {
            chance = 95;
        }
    }
    else
    {
        chance = 15 + (Skills_Get(playerid, SKILL_SAFE_CRACKING) / 15) - (lockLevel * 4);
        if (chance > 85)
        {
            chance = 85;
        }
    }
    if (chance < 5)
    {
        chance = 5;
    }

    new Float:vx, Float:vy, Float:vz;
    new vInterior, vVw;
    Storage_GetWorldPosition(vaultSlot, vx, vy, vz, vInterior, vVw);

    if (random(100) >= chance)
    {
        if (hasLockpick)
        {
            Forensics_CreateLockpickScratch(Character_GetId(playerid), vx, vy, vz, vInterior, vVw);
        }
        else
        {
            Forensics_CreateFingerprint(Character_GetId(playerid), vx, vy, vz, vInterior, vVw);
        }

        Character_SetWantedLevel(playerid,
            Character_GetWantedLevel(playerid) + 5);
        Character_ResetActivePlaySeconds(playerid);
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Замок выстоял! Сработала скрытая сигнализация, а на месте остались следы взлома.");
        Audit_Log(Character_GetId(playerid), "ORG_VAULT_HEIST_FAIL", "CHARACTER", "ORG_VAULT",
            0, 0, "Неудачная попытка взлома казны организации");
        return 0;
    }

    if (hasExplosive)
    {
        new const layer1 = Character_GetLayer1Slot(playerid);
        Storage_RemoveItemInTree(layer1, ITEM_ID_SATCHEL_CHARGE, 1);
    }

    Storage_SetLocked(vaultSlot, false);

    new const layer1 = Character_GetLayer1Slot(playerid);
    new moved = 0;
    new itemSlot = Storage_GetFirstItemSlot(vaultSlot);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        new const nextItemSlot = Storage_GetNextItemSlot(itemSlot);
        new const amount = Storage_GetItemAmount(itemSlot);
        if (Storage_TransferItem(playerid, vaultSlot, itemSlot, layer1, amount) == STORAGE_RES_OK)
        {
            moved++;
        }
        itemSlot = nextItemSlot;
    }

    Storage_SetLocked(vaultSlot, true);

    new orgName[ORG_NAME_LEN];
    Organizations_GetName(orgDbId, orgName, sizeof(orgName));

    new msg[256];
    if (moved > 0)
    {
        format(msg, sizeof(msg),
            "Казна организации «%s» вскрыта! Вы вынесли %d стек(ов) имущества.",
            orgName, moved);
        SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    }
    else
    {
        format(msg, sizeof(msg),
            "Казна организации «%s» вскрыта, но в ней нет имущества или ваш инвентарь переполнен.",
            orgName);
        SendClientMessage(playerid, COLOR_UI_WARNING, msg);
    }

    new alarm[192];
    format(alarm, sizeof(alarm),
        "[Тревога] Казна организации «%s» была вскрыта посторонним лицом!", orgName);
    Organizations_NotifyMembers(orgDbId, alarm);

    Character_SetWantedLevel(playerid, Character_GetWantedLevel(playerid) + 10);
    Character_ResetActivePlaySeconds(playerid);

    new details[192];
    format(details, sizeof(details), "Взлом казны организации #%d, вынесено стеков: %d", orgDbId, moved);
    Audit_Log(Character_GetId(playerid), "ORG_VAULT_HEIST", "ORG_VAULT", "CHARACTER",
        0, moved, details);
    return 1;
}

static stock Internal_OpenOrgVault(playerid)
{
    new const orgId = Character_GetOrgId(playerid);
    if (orgId <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Вы не состоите в организации.");
        return 0;
    }
    if (!Organizations_PlayerHasPermission(playerid, ORG_PERM_ARMORY))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "У вашей должности нет доступа к оружейке и казне.");
        return 0;
    }

    new const orgSlot = Organizations_FindByDbId(orgId);
    new const vaultSlot = Organizations_GetVaultStorage(orgId);
    if (orgSlot < 0 || !Storage_IsValidSlot(vaultSlot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Казна организации недоступна.");
        return 0;
    }

    Storage_SetLocked(vaultSlot, false);
    if (!Dialogs_OpenExternalContainer(playerid, vaultSlot))
    {
        Storage_SetLocked(vaultSlot, true);
        return 0;
    }

    sOrgVaultUnlockUntil[orgSlot] = GetTickCount() + ORG_VAULT_UNLOCK_MS;
    sOrgVaultUnlockedBy[orgSlot] = playerid;
    return 1;
}

// =============================================================================
//  6. АСИНХРОННЫЕ SQL-КОЛБЕКИ (forward / public)
// =============================================================================

forward OnOrgMembersLoaded(playerid, sessionToken);
public OnOrgMembersLoaded(playerid, sessionToken)
{
    if (!IsPlayerConnected(playerid) || !Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 0;
    }
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    sOrgMemberCount[playerid] = 0;
    new rows = 0;
    cache_get_row_count(rows);
    if (rows <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "В организации пока нет сотрудников.");
        return 1;
    }

    new dialogBody[ORG_DIALOG_BUFFER_LEN];
    dialogBody[0] = '\0';

    new count = 0;
    for (new r = 0; r < rows && count < ORG_MAX_MEMBER_ROWS; r++)
    {
        new charId, rankId, rankOrder;
        new name[MAX_PLAYER_NAME + 1], rankTitle[ORG_RANK_TITLE_LEN];

        cache_get_value_name_int(r, "char_id", charId);
        cache_get_value_name(r, "rp_name", name, sizeof(name));
        cache_get_value_name_int(r, "rank_id", rankId);
        cache_get_value_name(r, "rank_title", rankTitle, sizeof(rankTitle));
        cache_get_value_name_int(r, "rank_order", rankOrder);

        sOrgMemberCharId[playerid][count] = charId;
        sOrgMemberRankId[playerid][count] = rankId;
        format(sOrgMemberName[playerid][count], MAX_PLAYER_NAME + 1, "%s", name);
        count++;

        new row[192];
        format(row, sizeof(row), "%s | %s | ранг %d\n", name, rankTitle, rankOrder);
        if ((strlen(dialogBody) + strlen(row)) >= sizeof(dialogBody))
        {
            break;
        }
        strcat(dialogBody, row, sizeof(dialogBody));
    }
    sOrgMemberCount[playerid] = count;

    ShowPlayerDialog(
        playerid,
        DIALOG_ORG_MEMBERS,
        DIALOG_STYLE_LIST,
        "{FFC800}Сотрудники организации",
        dialogBody,
        "Управлять",
        "Назад");
    return 1;
}

// =============================================================================
//  7. ХУКИ СИСТЕМНЫХ КОЛБЕКОВ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_ORGANIZATIONS; i++)
    {
        Internal_ResetOrganizationSlot(i);
        sOrgVaultUnlockUntil[i] = 0;
        sOrgVaultUnlockedBy[i] = INVALID_PLAYER_ID;
    }
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        sOrgMenuActionCount[i] = 0;
        sOrgListRowCount[i] = 0;
        sOrgRankRowCount[i] = 0;
        sOrgRankEditIndex[i] = -1;
        sOrgPermRankIndex[i] = -1;
        sOrgMemberCount[i] = 0;
        sOrgPendingMember[i] = -1;
        sOrgPendingMemberCharId[i] = 0;
        sOrgInputRankIndex[i] = -1;
        sOrgBankAction[i] = _:ORG_BANK_ACTION_NONE;
        sOrgCreateStatus[i] = _:ORG_STATUS_UNREGISTERED;
        sOrgCreateName[i][0] = EOS;
        sOrgCreateTag[i][0] = EOS;
        sOrgLastCommandTick[i] = 0;
        sOrgLastHeistTick[i] = 0;
    }

    Internal_LoadOrganizationsSync();

    printf("%s [Systems/Organizations] Загружено организаций: %d, должностей: суммарно по реестру.",
        SERVER_LOG_PREFIX, Iter_Count(OrganizationIter));
    return 1;
}

hook OnPlayerConnect(playerid)
{
    sOrgMenuActionCount[playerid] = 0;
    sOrgListRowCount[playerid] = 0;
    sOrgRankRowCount[playerid] = 0;
    sOrgRankEditIndex[playerid] = -1;
    sOrgPermRankIndex[playerid] = -1;
    sOrgMemberCount[playerid] = 0;
    sOrgPendingMember[playerid] = -1;
    sOrgPendingMemberCharId[playerid] = 0;
    sOrgInputRankIndex[playerid] = -1;
    sOrgBankAction[playerid] = _:ORG_BANK_ACTION_NONE;
    sOrgCreateStatus[playerid] = _:ORG_STATUS_UNREGISTERED;
    sOrgCreateName[playerid][0] = EOS;
    sOrgCreateTag[playerid][0] = EOS;
    sOrgLastCommandTick[playerid] = 0;
    sOrgLastHeistTick[playerid] = 0;
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    sOrgMenuActionCount[playerid] = 0;
    sOrgListRowCount[playerid] = 0;
    sOrgRankRowCount[playerid] = 0;
    sOrgMemberCount[playerid] = 0;
    sOrgPendingMember[playerid] = -1;
    sOrgPendingMemberCharId[playerid] = 0;
    sOrgInputRankIndex[playerid] = -1;
    sOrgBankAction[playerid] = _:ORG_BANK_ACTION_NONE;
    sOrgCreateName[playerid][0] = EOS;
    sOrgCreateTag[playerid][0] = EOS;

    foreach (new orgSlot : OrganizationIter)
    {
        if (sOrgVaultUnlockedBy[orgSlot] == playerid)
        {
            new const vaultSlot = sOrgs[orgSlot][E_ORG_VAULT_SLOT];
            if (Storage_IsValidSlot(vaultSlot))
            {
                Storage_SetLocked(vaultSlot, true);
            }
            sOrgVaultUnlockUntil[orgSlot] = 0;
            sOrgVaultUnlockedBy[orgSlot] = INVALID_PLAYER_ID;
        }
    }
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch (dialogid)
    {
        case DIALOG_ORG_LIST:
        {
            if (!response || listitem < 0 || listitem >= sOrgListRowCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new const orgId = sOrgListRowMap[playerid][listitem];
            if (orgId <= 0)
            {
                Internal_ShowCreateStatus(playerid);
            }
            else
            {
                Internal_ShowOrgInfo(playerid, orgId);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_MAIN:
        {
            if (!response || listitem < 0 || listitem >= sOrgMenuActionCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const E_ORG_MENU_ACTION:action = sOrgMenuAction[playerid][listitem];
            switch (action)
            {
                case ORG_MENU_NONE:
                {
                    return Y_HOOKS_BREAK_RETURN_1;
                }
                case ORG_MENU_INFO:
                {
                    Internal_ShowOrgInfo(playerid, Character_GetOrgId(playerid));
                }
                case ORG_MENU_RANKS:
                {
                    Internal_ShowRankList(playerid, false);
                }
                case ORG_MENU_RANK_BUILDER:
                {
                    Internal_CreateRankDialog(playerid);
                }
                case ORG_MENU_MEMBERS:
                {
                    Internal_LoadMembers(playerid);
                }
                case ORG_MENU_VAULT:
                {
                    Internal_OpenOrgVault(playerid);
                }
                case ORG_MENU_BANK:
                {
                    Internal_ShowBankMenu(playerid);
                }
                case ORG_MENU_RADIO:
                {
                    if (Internal_CanManageOrganization(playerid, ORG_PERM_RADIO))
                    {
                        Internal_ShowRadioInput(playerid);
                    }
                }
                case ORG_MENU_CHARTER:
                {
                    Internal_ShowCharterHelp(playerid);
                }
                case ORG_MENU_LEAVE:
                {
                    new const orgId = Character_GetOrgId(playerid);
                    if (orgId > 0 && Organizations_GetPlayerRankOrder(playerid) >= 5)
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR,
                            "Лидер не может покинуть организацию. Передайте руководство или расформируйте структуру.");
                    }
                    else
                    {
                        Organizations_RevokeMembership(playerid);
                        SendClientMessage(playerid, COLOR_UI_SUCCESS, "Вы покинули организацию.");
                        Audit_Log(Character_GetId(playerid), "ORG_LEAVE", "CHARACTER", "ORG", 0, 0,
                            "Выход из организации");
                    }
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_RANKS:
        {
            if (!response)
            {
                Internal_ShowOrgMenu(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sOrgRankRowCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (!Organizations_PlayerHasPermission(playerid, ORG_PERM_RANKS))
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ShowRankEdit(playerid, sOrgRankRowMap[playerid][listitem]);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_RANK_EDIT:
        {
            if (!response)
            {
                Internal_ShowRankList(playerid, true);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new const rankIndex = sOrgRankEditIndex[playerid];
            switch (listitem)
            {
                case 0:
                {
                    sOrgInputRankIndex[playerid] = rankIndex;
                    new title[ORG_RANK_TITLE_LEN];
                    new const orgSlot = Organizations_FindByDbId(Character_GetOrgId(playerid));
                    if (orgSlot >= 0 && rankIndex >= 0 && rankIndex < sOrgs[orgSlot][E_ORG_RANK_COUNT])
                    {
                        format(title, sizeof(title), "%s", sOrgRanks[orgSlot][rankIndex][E_ORG_RANK_TITLE]);
                    }
                    else
                    {
                        title[0] = EOS;
                    }
                    new body[256];
                    format(body, sizeof(body),
                        "Введите новое название должности.\nТекущее название: %s.",
                        title);
                    ShowPlayerDialog(playerid, DIALOG_ORG_RANK_TITLE_INPUT, DIALOG_STYLE_INPUT,
                        "{FFC800}Название должности", body, "Сохранить", "Отмена");
                }
                case 1:
                {
                    sOrgInputRankIndex[playerid] = rankIndex;
                    ShowPlayerDialog(playerid, DIALOG_ORG_RANK_SALARY_INPUT, DIALOG_STYLE_INPUT,
                        "{FFC800}Оклад должности",
                        "Введите новый оклад должности в USD (целое число от 0 до 1 000 000).",
                        "Сохранить",
                        "Отмена");
                }
                case 2:
                {
                    Internal_ShowRankPermissions(playerid, rankIndex);
                }
                case 3:
                {
                    Internal_DeleteRank(playerid, rankIndex);
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_RANK_PERMS:
        {
            if (!response)
            {
                Internal_ShowRankEdit(playerid, sOrgPermRankIndex[playerid]);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new permissions[6] = { 1, 2, 4, 8, 16, 32 };
            if (listitem < 0 || listitem >= 6)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ToggleRankPermission(playerid, sOrgPermRankIndex[playerid], permissions[listitem]);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_RANK_TITLE_INPUT:
        {
            if (!response)
            {
                Internal_ShowRankEdit(playerid, sOrgInputRankIndex[playerid]);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ApplyRankTitle(playerid, sOrgInputRankIndex[playerid], inputtext);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_RANK_SALARY_INPUT:
        {
            if (!response)
            {
                Internal_ShowRankEdit(playerid, sOrgInputRankIndex[playerid]);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new salary = 0;
            if (!Internal_ParsePositiveInt(inputtext, salary) && strcmp(inputtext, "0") != 0)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Введите корректное целое число USD.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (strcmp(inputtext, "0") == 0)
            {
                salary = 0;
            }
            Internal_ApplyRankSalary(playerid, sOrgInputRankIndex[playerid], salary);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_MEMBERS:
        {
            if (!response)
            {
                Internal_ShowOrgMenu(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sOrgMemberCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            sOrgPendingMember[playerid] = listitem;
            sOrgPendingMemberCharId[playerid] = sOrgMemberCharId[playerid][listitem];
            Internal_ShowMemberActions(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_MEMBER_ACTIONS:
        {
            if (!response)
            {
                Internal_LoadMembers(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            switch (listitem)
            {
                case 0:
                {
                    Internal_ShowPromotionRanks(playerid);
                }
                case 1:
                {
                    new const memberCharId = sOrgPendingMemberCharId[playerid];
                    new const targetPlayer = Internal_FindPlayerByCharId(memberCharId);
                    if (targetPlayer == INVALID_PLAYER_ID)
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "Сотрудник должен находиться в сети для увольнения.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    if (!Internal_CanManageOrganization(playerid, ORG_PERM_HIRE))
                    {
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    if (targetPlayer == playerid)
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "Нельзя уволить самого себя.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    if (Utils_GetDistanceBetweenPlayers(playerid, targetPlayer) > STORAGE_INTERACT_DISTANCE)
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "Сотрудник находится слишком далеко.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    if (Character_GetOrgId(targetPlayer) != Character_GetOrgId(playerid))
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "Сотрудник уже не состоит в вашей организации.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    if (Organizations_GetPlayerRankOrder(playerid) <= Organizations_GetPlayerRankOrder(targetPlayer))
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "Нельзя уволить сотрудника равного или более высокого ранга.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }

                    Organizations_RevokeMembership(targetPlayer);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Сотрудник уволен из организации.");
                    SendClientMessage(targetPlayer, COLOR_UI_WARNING, "Вы были уволены из организации.");
                    Audit_Log(Character_GetId(playerid), "ORG_FIRE", "ORG", "CHARACTER",
                        0, 0, "Увольнение сотрудника организации");
                    Internal_LoadMembers(playerid);
                }
                case 2:
                {
                    Internal_LoadMembers(playerid);
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_PROMOTE:
        {
            if (!response)
            {
                Internal_ShowMemberActions(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sOrgRankRowCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (!Internal_CanManageOrganization(playerid, ORG_PERM_HIRE))
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const memberCharId = sOrgPendingMemberCharId[playerid];
            new const targetPlayer = Internal_FindPlayerByCharId(memberCharId);
            if (targetPlayer == INVALID_PLAYER_ID)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Сотрудник должен находиться в сети.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (targetPlayer == playerid)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Нельзя изменить собственную должность.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (Utils_GetDistanceBetweenPlayers(playerid, targetPlayer) > STORAGE_INTERACT_DISTANCE)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Сотрудник находится слишком далеко.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const orgId = Character_GetOrgId(playerid);
            new const orgSlot = Organizations_FindByDbId(orgId);
            new const rankIndex = sOrgRankRowMap[playerid][listitem];
            if (orgSlot < 0 || rankIndex < 0 || rankIndex >= sOrgs[orgSlot][E_ORG_RANK_COUNT])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const actorOrder = Organizations_GetPlayerRankOrder(playerid);
            new const targetOrder = Organizations_GetPlayerRankOrder(targetPlayer);
            new const newOrder = sOrgRanks[orgSlot][rankIndex][E_ORG_RANK_ORDER];
            if (actorOrder <= targetOrder)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Нельзя повысить сотрудника равного или более высокого ранга.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (newOrder >= actorOrder)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Нельзя назначить должность не ниже собственной.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            Character_SetOrgMembership(
                targetPlayer,
                orgId,
                sOrgRanks[orgSlot][rankIndex][E_ORG_RANK_DB_ID]);

            new msg[192];
            format(msg, sizeof(msg), "Вы назначены на должность: %s.",
                sOrgRanks[orgSlot][rankIndex][E_ORG_RANK_TITLE]);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "Должность сотрудника обновлена.");
            SendClientMessage(targetPlayer, COLOR_UI_SUCCESS, msg);

            Audit_Log(Character_GetId(playerid), "ORG_PROMOTE", "ORG", "CHARACTER",
                0, newOrder, "Изменение должности сотрудника");
            Internal_LoadMembers(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_BANK:
        {
            if (!response)
            {
                Internal_ShowOrgMenu(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (!Internal_CanManageOrganization(playerid, ORG_PERM_BANK))
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            switch (listitem)
            {
                case 0:
                {
                    sOrgBankAction[playerid] = _:ORG_BANK_ACTION_DEPOSIT;
                    ShowPlayerDialog(playerid, DIALOG_ORG_BANK_AMOUNT, DIALOG_STYLE_INPUT,
                        "{FFC800}Пополнение счета организации",
                        "Введите сумму USD для перевода с личного банковского счета на счет организации.",
                        "Перевести",
                        "Отмена");
                }
                case 1:
                {
                    sOrgBankAction[playerid] = _:ORG_BANK_ACTION_WITHDRAW;
                    ShowPlayerDialog(playerid, DIALOG_ORG_BANK_AMOUNT, DIALOG_STYLE_INPUT,
                        "{FFC800}Снятие средств организации",
                        "Введите сумму USD для перевода со счета организации на ваш личный банковский счет.",
                        "Перевести",
                        "Отмена");
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_BANK_AMOUNT:
        {
            if (!response)
            {
                Internal_ShowBankMenu(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new amount = 0;
            if (!Internal_ParsePositiveInt(inputtext, amount))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Введите корректную сумму цифрами.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const orgId = Character_GetOrgId(playerid);
            if (sOrgBankAction[playerid] == _:ORG_BANK_ACTION_DEPOSIT)
            {
                if (!Banking_DebitAccount(playerid, amount, "Пополнение счета организации"))
                {
                    SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось списать средства с личного счета.");
                    return Y_HOOKS_BREAK_RETURN_1;
                }
                Organizations_AddBankBalance(orgId, amount);
                SendClientMessage(playerid, COLOR_UI_SUCCESS, "Счет организации пополнен.");
                Audit_Log(Character_GetId(playerid), "ORG_BANK_DEPOSIT", "CHARACTER_BANK", "ORG_BANK",
                    0, amount, "Пополнение счета организации");
            }
            else if (sOrgBankAction[playerid] == _:ORG_BANK_ACTION_WITHDRAW)
            {
                if (!Organizations_TakeBankBalance(orgId, amount))
                {
                    SendClientMessage(playerid, COLOR_UI_ERROR, "На счете организации недостаточно средств.");
                    return Y_HOOKS_BREAK_RETURN_1;
                }
                if (!Banking_CreditAccount(playerid, amount, "Снятие средств организации"))
                {
                    Organizations_AddBankBalance(orgId, amount);
                    SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось зачислить средства на личный счет.");
                    return Y_HOOKS_BREAK_RETURN_1;
                }
                SendClientMessage(playerid, COLOR_UI_SUCCESS, "Средства переведены на ваш личный счет.");
                Audit_Log(Character_GetId(playerid), "ORG_BANK_WITHDRAW", "ORG_BANK", "CHARACTER_BANK",
                    0, amount, "Снятие средств организации");
            }
            sOrgBankAction[playerid] = _:ORG_BANK_ACTION_NONE;
            Internal_ShowBankMenu(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_RADIO_INPUT:
        {
            if (!response)
            {
                Internal_ShowOrgMenu(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new freq = 0;
            if (!Internal_ParsePositiveInt(inputtext, freq) || freq < 100000 || freq > 999900)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "Частота должна быть целым числом от 100000 до 999900 килогерц.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (!Internal_CanManageOrganization(playerid, ORG_PERM_RADIO))
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const orgId = Character_GetOrgId(playerid);
            new const orgSlot = Organizations_FindByDbId(orgId);
            if (orgSlot < 0)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            sOrgs[orgSlot][E_ORG_RADIO_FREQ] = freq;
            if (DB_IsConnected())
            {
                new query[160];
                mysql_format(gMySQL, query, sizeof(query),
                    "UPDATE `organizations` SET `radio_freq` = %d WHERE `id` = %d;",
                    freq, orgId);
                mysql_tquery(gMySQL, query);
            }

            new freqText[32], msg[160];
            Internal_FormatRadioFreq(freq, freqText, sizeof(freqText));
            format(msg, sizeof(msg), "Радиочастота организации настроена: %s.", freqText);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
            Audit_Log(Character_GetId(playerid), "ORG_RADIO", "ORG", "ORG_RADIO", 0, freq,
                "Изменение радиочастоты организации");
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_CREATE_STATUS:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem > 2)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            sOrgCreateStatus[playerid] = listitem;
            Internal_ShowCreateName(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_CREATE_NAME:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (strlen(inputtext) < 3 || strlen(inputtext) >= ORG_NAME_LEN)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Название должно содержать от 3 до 63 символов.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            format(sOrgCreateName[playerid], ORG_NAME_LEN, "%s", inputtext);
            Internal_ShowCreateTag(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ORG_CREATE_TAG:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (strlen(inputtext) < 2 || strlen(inputtext) >= ORG_TAG_LEN)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Тег должен содержать от 2 до 7 символов.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (!Internal_IsValidOrgTag(inputtext))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "Тег может содержать только латинские буквы, цифры, дефис и подчеркивание.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            format(sOrgCreateTag[playerid], ORG_TAG_LEN, "%s", inputtext);
            Internal_CreateOrganizationFlow(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_1;
}

// =============================================================================
//  8. ТАЙМЕР ОБСЛУЖИВАНИЯ ЗАМКОВ КАЗНЫ
// =============================================================================

task Tick_OrganizationsVaultRelock[5000]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }

    new const nowTick = GetTickCount();
    foreach (new orgSlot : OrganizationIter)
    {
        if (sOrgVaultUnlockUntil[orgSlot] == 0)
        {
            continue;
        }
        if (nowTick < sOrgVaultUnlockUntil[orgSlot])
        {
            continue;
        }

        new const vaultSlot = sOrgs[orgSlot][E_ORG_VAULT_SLOT];
        if (Storage_IsValidSlot(vaultSlot))
        {
            Storage_SetLocked(vaultSlot, true);
        }
        sOrgVaultUnlockUntil[orgSlot] = 0;
        sOrgVaultUnlockedBy[orgSlot] = INVALID_PLAYER_ID;
    }
}

// =============================================================================
//  9. КОМАНДЫ (Pawn.CMD)
// =============================================================================

CMD:org(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_OrgCommandAllowed(playerid))
    {
        return 1;
    }

    if (Character_GetOrgId(playerid) <= 0)
    {
        Internal_ShowOrgList(playerid);
    }
    else
    {
        Internal_ShowOrgMenu(playerid);
    }
    return 1;
}

CMD:orginvite(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_OrgCommandAllowed(playerid))
    {
        return 1;
    }
    if (!Internal_CanManageOrganization(playerid, ORG_PERM_HIRE))
    {
        return 1;
    }

    new values[2];
    if (Internal_ParseInts(params, values, 2) < 1)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Использование: /orginvite [id игрока]");
        return 1;
    }

    new const targetid = values[0];
    if (targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Игрок не найден в сети.");
        return 1;
    }
    if (targetid == playerid)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Нельзя пригласить самого себя.");
        return 1;
    }
    if (Utils_GetDistanceBetweenPlayers(playerid, targetid) > STORAGE_INTERACT_DISTANCE)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Игрок находится слишком далеко.");
        return 1;
    }
    if (Character_GetOrgId(targetid) > 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Игрок уже состоит в другой организации.");
        return 1;
    }

    new const orgId = Character_GetOrgId(playerid);
    new const orgSlot = Organizations_FindByDbId(orgId);
    new const rankIndex = Internal_GetEntryRankIndex(orgSlot);
    if (orgSlot < 0 || rankIndex < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "В организации нет настроенных должностей.");
        return 1;
    }

    new const rankDbId = sOrgRanks[orgSlot][rankIndex][E_ORG_RANK_DB_ID];
    Organizations_GrantMembership(targetid, orgId, rankDbId);

    new orgName[ORG_NAME_LEN], rankTitle[ORG_RANK_TITLE_LEN];
    Organizations_GetName(orgId, orgName, sizeof(orgName));
    Organizations_GetRankTitle(orgId, rankIndex, rankTitle, sizeof(rankTitle));

    new msg[224];
    format(msg, sizeof(msg), "Вы приняты в организацию «%s» на должность %s.", orgName, rankTitle);
    SendClientMessage(targetid, COLOR_UI_SUCCESS, msg);
    format(msg, sizeof(msg), "Игрок принят в организацию на должность %s.", rankTitle);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    Audit_Log(Character_GetId(playerid), "ORG_INVITE", "ORG", "CHARACTER",
        0, Character_GetId(targetid), "Прием сотрудника в организацию");
    return 1;
}

CMD:orgfire(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_OrgCommandAllowed(playerid))
    {
        return 1;
    }
    if (!Internal_CanManageOrganization(playerid, ORG_PERM_HIRE))
    {
        return 1;
    }

    new values[2];
    if (Internal_ParseInts(params, values, 2) < 1)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Использование: /orgfire [id игрока]");
        return 1;
    }

    new const targetid = values[0];
    if (targetid < 0 || targetid >= MAX_PLAYERS || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Игрок не найден в сети.");
        return 1;
    }
    if (targetid == playerid)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Нельзя уволить самого себя.");
        return 1;
    }
    if (Utils_GetDistanceBetweenPlayers(playerid, targetid) > STORAGE_INTERACT_DISTANCE)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Игрок находится слишком далеко.");
        return 1;
    }
    if (Character_GetOrgId(targetid) != Character_GetOrgId(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Игрок не состоит в вашей организации.");
        return 1;
    }
    if (Organizations_GetPlayerRankOrder(playerid) <= Organizations_GetPlayerRankOrder(targetid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Нельзя уволить сотрудника равного или более высокого ранга.");
        return 1;
    }

    Organizations_RevokeMembership(targetid);
    SendClientMessage(targetid, COLOR_UI_WARNING, "Вы были уволены из организации.");
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "Сотрудник уволен.");

    Audit_Log(Character_GetId(playerid), "ORG_FIRE", "ORG", "CHARACTER",
        0, Character_GetId(targetid), "Увольнение сотрудника организации");
    return 1;
}

CMD:orgvault(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_OrgCommandAllowed(playerid))
    {
        return 1;
    }
    Internal_OpenOrgVault(playerid);
    return 1;
}

CMD:orgbank(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_OrgCommandAllowed(playerid))
    {
        return 1;
    }
    if (!Internal_CanManageOrganization(playerid, ORG_PERM_BANK))
    {
        return 1;
    }
    Internal_ShowBankMenu(playerid);
    return 1;
}

CMD:orgradio(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_OrgCommandAllowed(playerid))
    {
        return 1;
    }
    if (!Internal_CanManageOrganization(playerid, ORG_PERM_RADIO))
    {
        return 1;
    }
    Internal_ShowRadioInput(playerid);
    return 1;
}

CMD:vaultbreak(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    Internal_ExecuteVaultHeist(playerid);
    return 1;
}
alias:vaultbreak("crackvault");

CMD:orgcharter(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_OrgCommandAllowed(playerid))
    {
        return 1;
    }
    if (Character_GetOrgId(playerid) != ORG_GOVERNMENT_DB_ID || Organizations_GetPlayerRankOrder(playerid) < 5)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Изменять хартии организаций может только действующий губернатор штата.");
        return 1;
    }

    new values[3];
    if (Internal_ParseInts(params, values, 3) < 3)
    {
        Internal_ShowCharterHelp(playerid);
        return 1;
    }

    new const orgId = values[0];
    new const flagValue = values[1];
    new const enabled = values[2];
    if (!Organizations_IsValid(orgId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Организация не найдена.");
        return 1;
    }
    if (flagValue != 1 && flagValue != 2 && flagValue != 4 && flagValue != 8 && flagValue != 16 && flagValue != 32)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Недопустимый флаг хартии.");
        return 1;
    }

    Organizations_SetCharterFlag(orgId, E_CHARTER_FLAGS:flagValue, (enabled != 0));

    new msg[192];
    format(msg, sizeof(msg),
        "Флаг хартии %d организации #%d %s.",
        flagValue, orgId, (enabled != 0) ? ("выдан") : ("отозван"));
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    Audit_Log(Character_GetId(playerid), "ORG_CHARTER", "GOVERNMENT", "ORG",
        0, flagValue, (enabled != 0) ? ("Выдача флага хартии") : ("Отзыв флага хартии"));
    return 1;
}

CMD:orgstatus(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_OrgCommandAllowed(playerid))
    {
        return 1;
    }
    if (Character_GetOrgId(playerid) != ORG_GOVERNMENT_DB_ID || Organizations_GetPlayerRankOrder(playerid) < 5)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Изменять правовой статус организаций может только действующий губернатор штата.");
        return 1;
    }

    new values[2];
    if (Internal_ParseInts(params, values, 2) < 2)
    {
        SendClientMessage(playerid, COLOR_UI_INFO,
            "Использование: /orgstatus [id] [1-незарегистрированная, 2-корпорация, 3-госведомство]");
        return 1;
    }

    new const orgId = values[0];
    new const statusValue = values[1];
    if (!Organizations_IsValid(orgId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Организация не найдена.");
        return 1;
    }
    if (statusValue < 1 || statusValue > 3)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Недопустимый правовой статус.");
        return 1;
    }

    Organizations_SetLegalStatus(orgId, E_ORG_LEGAL_STATUS:(statusValue - 1));

    new statusTitle[48], msg[192];
    Organizations_GetStatusTitleRu(E_ORG_LEGAL_STATUS:(statusValue - 1), statusTitle, sizeof(statusTitle));
    format(msg, sizeof(msg), "Правовой статус организации #%d изменен: %s.", orgId, statusTitle);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    Audit_Log(Character_GetId(playerid), "ORG_STATUS", "GOVERNMENT", "ORG",
        0, statusValue, "Изменение правового статуса организации");
    return 1;
}

CMD:orgfreeze(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_OrgCommandAllowed(playerid))
    {
        return 1;
    }
    if (!Internal_CanFreezeOrgBank(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Заморозить счет организации могут только Правительство, ФБР или ЦРУ с соответствующими полномочиями.");
        return 1;
    }

    new values[2];
    if (Internal_ParseInts(params, values, 2) < 2)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Использование: /orgfreeze [id организации] [1/0]");
        return 1;
    }

    new const orgId = values[0];
    if (!Organizations_IsValid(orgId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Организация не найдена.");
        return 1;
    }

    Organizations_SetBankFrozen(orgId, (values[1] != 0));

    new msg[192];
    format(msg, sizeof(msg), "Банковский счет организации #%d %s.",
        orgId, (values[1] != 0) ? ("заморожен") : ("разморожен"));
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    format(msg, sizeof(msg), "[Финансы] Банковский счет вашей организации %s.",
        (values[1] != 0) ? ("заморожен по решению следствия") : ("разморожен"));
    Organizations_NotifyMembers(orgId, msg);

    Audit_Log(Character_GetId(playerid), "ORG_FREEZE", "GOVERNMENT", "ORG_BANK",
        0, values[1], "Изменение режима заморозки банковского счета организации");
    return 1;
}

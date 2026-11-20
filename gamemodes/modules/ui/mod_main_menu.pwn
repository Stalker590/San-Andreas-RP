/*
 * =============================================================================
 *  SAN ANDREAS RP Ч √лавное меню персонажа (/mm),  одекс команд (/help),
 *                   GPS-навигатор (/gps), Ќастройки (/settings) и –епорты (/report)
 *  ‘айл:      gamemodes/modules/ui/mod_main_menu.pwn
 *  ‘аза:      ROADMAP [12.1, 12.3, 12.4] Ч ≈дина€ система взаимодействи€ (Command-First UX)
 *   одировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_main_menu_included
    #endinput
#endif
#define _mod_main_menu_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1.  ќЌ—“јЌ“џ »ƒ≈Ќ“»‘» ј“ќ–ќ¬ ƒ»јЋќ√ќ¬ (/mm, /help, /report, /settings, /gps)
// =============================================================================

#define DIALOG_MM_ROOT                          (2100)
#define DIALOG_MM_STATS_CARD                    (2101)
#define DIALOG_MM_SKILLS_CATEGORIES             (2102)
#define DIALOG_MM_SKILLS_LIST                   (2103)
#define DIALOG_MM_HELP_CATEGORIES               (2104)
#define DIALOG_MM_HELP_CONTENT                  (2105)
#define DIALOG_MM_REPORT_INPUT                  (2106)
#define DIALOG_MM_SETTINGS_LIST                 (2107)
#define DIALOG_MM_PASS_OLD                      (2108)
#define DIALOG_MM_PASS_NEW                      (2109)
#define DIALOG_MM_GPS_CATEGORIES                (2110)
#define DIALOG_MM_GPS_LOCATIONS                 (2111)
#define DIALOG_ADMIN_REPORTS_LIST               (2112)
#define DIALOG_ADMIN_REPORT_ACTIONS             (2113)
#define DIALOG_ADMIN_REPORT_REPLY               (2114)

#define MAX_ADMIN_REPORTS                       (64)
#define MAX_REPORT_TEXT_LEN                     (144)
#define REPORT_SUBMIT_COOLDOWN_SEC              (60)
#define MM_ACTION_COOLDOWN_MS                   (300)
#define MAX_GPS_POINTS                          (20)
#define MAX_MM_DIALOG_ROWS                      (32)

// =============================================================================
//  2. ѕ≈–≈„»—Ћ≈Ќ»я » »Ќ јѕ—”Ћ»–ќ¬јЌЌџ≈ ћј——»¬џ —ќ—“ќяЌ»я (static stock)
// =============================================================================

enum E_MM_ROOT_ITEM
{
    MM_ROOT_NONE = 0,
    MM_ROOT_STATS,
    MM_ROOT_SKILLS,
    MM_ROOT_HELP,
    MM_ROOT_REPORT,
    MM_ROOT_SETTINGS,
    MM_ROOT_GPS,
    MM_ROOT_ACT,
    MM_ROOT_INV
};

enum E_GPS_CATEGORY
{
    GPS_CAT_GOV_CIVIC = 0,
    GPS_CAT_LAW_EMERGENCY,
    GPS_CAT_PORTS_TRADE,
    GPS_CAT_PRIMARY_JOBS,
    GPS_CAT_INDUSTRY_SHOPS,
    GPS_CAT_CLEAR
};

enum E_GPS_POINT_DATA
{
    E_GPS_CATEGORY:E_GPS_CAT,
    E_GPS_NAME[56],
    E_GPS_CMD_HINT[32],
    Float:E_GPS_X,
    Float:E_GPS_Y,
    Float:E_GPS_Z
};

enum E_ADMIN_REPORT_ENTRY
{
    bool:E_REP_ACTIVE,
    E_REP_ID,
    E_REP_SENDER_PLAYERID,
    E_REP_SENDER_ACCOUNT_ID,
    E_REP_SENDER_CHAR_ID,
    E_REP_SENDER_NAME[MAX_PLAYER_NAME + 1],
    E_REP_TEXT[MAX_REPORT_TEXT_LEN],
    E_REP_CREATED_UNIX
};

static stock const sGpsCatalog[MAX_GPS_POINTS][E_GPS_POINT_DATA] =
{
    // 1. √осударственные учреждени€, банки и автосалоны (GPS_CAT_GOV_CIVIC)
    { GPS_CAT_GOV_CIVIC,      "State Capitol & City Hall (Los Santos)", "/org /showpass",  1481.0,  -1771.0, 18.8 },
    { GPS_CAT_GOV_CIVIC,      "Central Bank of Los Santos",             "/bank /atm",      1461.5,  -1012.5, 26.8 },
    { GPS_CAT_GOV_CIVIC,      "San Fierro Financial Bank Branch",       "/bank /atm",     -1981.5,    137.3, 27.7 },
    { GPS_CAT_GOV_CIVIC,      "Las Venturas Commercial Bank Branch",    "/bank /atm",      2134.2,   1990.1, 10.8 },
    { GPS_CAT_GOV_CIVIC,      "Los Santos Auto Dealership",             "/vbuy /cars",     2135.0,   1398.0, 10.8 },
    { GPS_CAT_GOV_CIVIC,      "San Fierro Auto Showroom",               "/vbuy /cars",    -1980.0,    120.0, 27.7 },

    // 2. Ёкстренные службы и правоохранительные органы (GPS_CAT_LAW_EMERGENCY)
    { GPS_CAT_LAW_EMERGENCY,  "All Saints General Hospital (EMS LS)",   "/triage /treat",  1172.8,  -1323.4, 15.4 },
    { GPS_CAT_LAW_EMERGENCY,  "Los Santos Police Department (LSPD HQ)", "/arrest /warrant",1554.9,  -1675.6, 16.2 },
    { GPS_CAT_LAW_EMERGENCY,  "San Fierro Police Department (SFPD HQ)", "/arrest /warrant",-1605.5,   710.8, 13.9 },
    { GPS_CAT_LAW_EMERGENCY,  "Las Venturas Police Dept (LVPD HQ)",     "/arrest /warrant",2287.0,   2431.8, 10.8 },
    { GPS_CAT_LAW_EMERGENCY,  "County Sheriff's Department (SASD)",     "/arrest /warrant", 627.6,   -571.8, 17.9 },
    { GPS_CAT_LAW_EMERGENCY,  "FBI Field Office (San Fierro)",          "/wiretap /ev",   -2442.2,    502.3, 30.1 },

    // 3. “орговые порты и логистические терминалы (GPS_CAT_PORTS_TRADE)
    { GPS_CAT_PORTS_TRADE,    "Port of Los Santos (Ocean Docks)",       "/port /contracts",2746.1,  -2437.2, 13.6 },
    { GPS_CAT_PORTS_TRADE,    "Port of San Fierro (Easter Basin)",      "/port /contracts",-1510.0,   490.0,  7.1 },
    { GPS_CAT_PORTS_TRADE,    "Las Venturas Freight Terminal",          "/port /contracts",2115.2,    920.1, 10.8 },

    // 4. ѕервична€ добыча сырь€: шахта, нефтевышка, лесопилка, ферма (GPS_CAT_PRIMARY_JOBS)
    { GPS_CAT_PRIMARY_JOBS,   "Hunter Quarry Iron Mine",                "/mine /deliver",   595.4,    872.6,-42.5 },
    { GPS_CAT_PRIMARY_JOBS,   "Octane Springs Oil Field",               "/mine /deliver",   261.2,   1411.8, 10.6 },
    { GPS_CAT_PRIMARY_JOBS,   "Angel Pine Logging Complex",             "/mine /deliver",  -533.8,   -179.4, 78.4 },
    { GPS_CAT_PRIMARY_JOBS,   "Flint County Grain Farm",                "/mine /deliver",  -382.1,  -1426.3, 25.7 },

    // 5. «аводы, переработка и торговл€ (GPS_CAT_INDUSTRY_SHOPS)
    { GPS_CAT_INDUSTRY_SHOPS, "Ocean Docks Steel Mill & Foundry",       "/craft /market",  2180.5,  -2253.8, 13.5 }
};

static stock sAdminReports[MAX_ADMIN_REPORTS][E_ADMIN_REPORT_ENTRY];
static stock sNextReportSeqId = 1;

static stock E_MM_ROOT_ITEM:sPlayerMmRootMap[MAX_PLAYERS][12];
static stock sPlayerMmRootCount[MAX_PLAYERS];

static stock sPlayerSkillCatMap[MAX_PLAYERS][8];
static stock sPlayerHelpCatMap[MAX_PLAYERS][10];
static stock sPlayerGpsPointMap[MAX_PLAYERS][MAX_GPS_POINTS];
static stock sPlayerGpsPointCount[MAX_PLAYERS];
static stock bool:sPlayerGpsActive[MAX_PLAYERS];

static stock bool:sPlayerHintsEnabled[MAX_PLAYERS];
static stock bool:sPlayerTimestampHint[MAX_PLAYERS];
static stock sPlayerPendingNewPass[MAX_PLAYERS][36];
static stock sPlayerLastReportUnix[MAX_PLAYERS];
static stock sPlayerLastMmTick[MAX_PLAYERS];

static stock sAdminReportListMap[MAX_PLAYERS][MAX_ADMIN_REPORTS];
static stock sAdminReportListCount[MAX_PLAYERS];
static stock sAdminSelectedReportSlot[MAX_PLAYERS];
static stock sMmEmptyCmdParams[4];

// =============================================================================
//  3. ¬Ќ”“–≈ЌЌ»≈ ¬—ѕќћќ√ј“≈Ћ№Ќџ≈ ‘”Ќ ÷»» (static stock)
// =============================================================================

static stock Internal_ResetPlayerMmState(playerid)
{
    sPlayerMmRootCount[playerid] = 0;
    sPlayerGpsPointCount[playerid] = 0;
    sPlayerGpsActive[playerid] = false;
    sPlayerHintsEnabled[playerid] = true;
    sPlayerTimestampHint[playerid] = true;
    sPlayerPendingNewPass[playerid][0] = '\0';
    sPlayerLastReportUnix[playerid] = 0;
    sPlayerLastMmTick[playerid] = 0;
    sAdminReportListCount[playerid] = 0;
    sAdminSelectedReportSlot[playerid] = -1;
}

static stock bool:Internal_CheckMmCooldown(playerid)
{
    new const nowTick = GetTickCount();
    if ((nowTick - sPlayerLastMmTick[playerid]) < MM_ACTION_COOLDOWN_MS)
    {
        return false;
    }
    sPlayerLastMmTick[playerid] = nowTick;
    return true;
}

static stock Internal_GetActiveReportCount()
{
    new count = 0;
    for (new i = 0; i < MAX_ADMIN_REPORTS; i++)
    {
        if (sAdminReports[i][E_REP_ACTIVE])
        {
            count++;
        }
    }
    return count;
}

static stock Internal_FindReportSlotById(report_id)
{
    if (report_id <= 0)
    {
        return -1;
    }
    for (new i = 0; i < MAX_ADMIN_REPORTS; i++)
    {
        if (sAdminReports[i][E_REP_ACTIVE] && sAdminReports[i][E_REP_ID] == report_id)
        {
            return i;
        }
    }
    return -1;
}

static stock Internal_NotifyAdminsNewReport(slot)
{
    if (slot < 0 || slot >= MAX_ADMIN_REPORTS || !sAdminReports[slot][E_REP_ACTIVE])
    {
        return 0;
    }

    new alert1[192], alert2[192];
    format(alert1, sizeof(alert1),
        "{FFAA00}[Report #%d] {FFFFFF}From %s [ID %d | Char #%d]: {FFF59D}%s",
        sAdminReports[slot][E_REP_ID],
        sAdminReports[slot][E_REP_SENDER_NAME],
        sAdminReports[slot][E_REP_SENDER_PLAYERID],
        sAdminReports[slot][E_REP_SENDER_CHAR_ID],
        sAdminReports[slot][E_REP_TEXT]);
    format(alert2, sizeof(alert2),
        "{FFAA00}[Report Queue] {88CCFF}Active tickets: %d. Use /reports, /ans [id] [reply] or /apanel -> Reports.",
        Internal_GetActiveReportCount());

    foreach (new adminId : Player)
    {
        if (!IsPlayerConnected(adminId) || !Character_IsLoaded(adminId))
        {
            continue;
        }
        if (Admin_HasPermission(adminId, ADMIN_PERM_PANEL_ACCESS) || Admin_IsRoot(adminId))
        {
            SendClientMessage(adminId, COLOR_UI_WARNING, alert1);
            SendClientMessage(adminId, COLOR_UI_INFO, alert2);
        }
    }
    return 1;
}

// =============================================================================
//  4. –ј«ƒ≈Ћџ √Ћј¬Ќќ√ќ ћ≈Ќё (/mm): —“ј“»—“» ј, Ќј¬џ », /help, /gps, /settings
// =============================================================================

/*
 * 4.1. ѕолна€ карточка статистики персонажа (/stats и раздел 1 в /mm)
 */
stock MainMenu_ShowCharacterStats(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Stats]: Your character has not yet been loaded.");
        return 0;
    }

    new rpName[MAX_PLAYER_NAME + 1], roleName[48], ssnBuf[20], ibanBuf[24];
    Character_GetRpName(playerid, rpName, sizeof(rpName));
    Roles_GetNameRu(Character_GetRoleId(playerid), roleName, sizeof(roleName));
    Character_GetSSN(playerid, ssnBuf, sizeof(ssnBuf));
    if (ssnBuf[0] == '\0')
    {
        format(ssnBuf, sizeof(ssnBuf), "Not Assigned");
    }
    Character_GetBankIban(playerid, ibanBuf, sizeof(ibanBuf));
    if (ibanBuf[0] == '\0')
    {
        format(ibanBuf, sizeof(ibanBuf), "No Bank Account");
    }

    new orgName[64], rankTitle[48];
    new const orgId = Character_GetOrgId(playerid);
    new const rankId = Character_GetOrgRankId(playerid);
    if (orgId > 0 && Organizations_IsValid(orgId))
    {
        Organizations_GetName(orgId, orgName, sizeof(orgName));
        new const orgSlot = Organizations_FindByDbId(orgId);
        new const rankIdx = (orgSlot >= 0) ? Organizations_GetRankIndexByDbId(orgSlot, rankId) : -1;
        if (rankIdx >= 0)
        {
            Organizations_GetRankTitle(orgId, rankIdx, rankTitle, sizeof(rankTitle));
        }
        else
        {
            format(rankTitle, sizeof(rankTitle), "Member");
        }
    }
    else
    {
        format(orgName, sizeof(orgName), "None (Unaffiliated Civilian)");
        format(rankTitle, sizeof(rankTitle), "N/A");
    }

    new const cleanUsd = Banking_GetPhysicalCash(playerid, CURRENCY_USD, CASH_FLAG_CLEAN);
    new const dirtyUsd = Banking_GetPhysicalCash(playerid, CURRENCY_USD, CASH_FLAG_DIRTY);
    new const eurCash = Banking_GetPhysicalCash(playerid, CURRENCY_EUR, -1);
    new const cnyCash = Banking_GetPhysicalCash(playerid, CURRENCY_CNY, -1);

    new cleanUsdStr[32], dirtyUsdStr[32], bankStr[32], debtStr[32];
    Utils_FormatMoney(cleanUsd, cleanUsdStr, sizeof(cleanUsdStr));
    Utils_FormatMoney(dirtyUsd, dirtyUsdStr, sizeof(dirtyUsdStr));
    Utils_FormatMoney(Character_GetBankBalanceUsd(playerid), bankStr, sizeof(bankStr));
    Utils_FormatMoney(Character_GetBankDebtUsd(playerid), debtStr, sizeof(debtStr));

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    new const layer2Slot = Character_GetLayer2Slot(playerid);

    new const l1W = Storage_IsValidSlot(layer1Slot) ? Storage_GetCurrentWeight(layer1Slot) : 0;
    new const l1MaxW = Survival_GetMaxCarryWeightGrams(playerid);
    new const l1V = Storage_IsValidSlot(layer1Slot) ? Storage_GetCurrentVolume(layer1Slot) : 0;
    new const l1MaxV = Storage_IsValidSlot(layer1Slot) ? Storage_GetMaxVolume(layer1Slot) : DEFAULT_PLAYER_LAYER1_VOLUME_ML;

    new const l2W = Storage_IsValidSlot(layer2Slot) ? Storage_GetCurrentWeight(layer2Slot) : 0;
    new const l2MaxW = Storage_IsValidSlot(layer2Slot) ? Storage_GetMaxWeight(layer2Slot) : DEFAULT_PLAYER_LAYER2_WEIGHT_G;
    new const l2V = Storage_IsValidSlot(layer2Slot) ? Storage_GetCurrentVolume(layer2Slot) : 0;
    new const l2MaxV = Storage_IsValidSlot(layer2Slot) ? Storage_GetMaxVolume(layer2Slot) : DEFAULT_PLAYER_LAYER2_VOLUME_ML;

    new const wantedLvl = Character_GetWantedLevel(playerid);
    new const decayLeft = 3600 - (Character_GetActivePlaySeconds(playerid) % 3600);

    static body[2048];
    format(body, sizeof(body),
        "{FFC800}1. Identity & Legal Profile:{FFFFFF}\n" \
        "- RP Name: {88CCFF}%s{FFFFFF} | Account ID: {88CCFF}#%d{FFFFFF} | Character ID: {88CCFF}#%d{FFFFFF}\n" \
        "- Level: {66CC66}%d{FFFFFF} (Active Playtime: %d / 36000 sec) | Formula Age: {66CC66}%d years{FFFFFF} (17 + Level)\n" \
        "- Citizenship: %s | Social Security Number (SSN): {88CCFF}%s{FFFFFF}\n" \
        "- Starting Archetype: {FFC800}%s (#%d){FFFFFF}\n" \
        "- Faction / Organization: {88CCFF}%s{FFFFFF} | Rank: {FFFFFF}%s\n" \
        "- Wanted Level: {FF4444}%d / 100{FFFFFF} (Next active decay -1 in: %d sec) | Jail Left: %d sec\n\n" \
        "{FFC800}2. Multi-Currency Cash & Banking:{FFFFFF}\n" \
        "- Clean Cash (USD): {66CC66}%s{FFFFFF} | Unmarked / Dirty Cash (USD): {FF8A65}%s{FFFFFF}\n" \
        "- Foreign Banknotes: {81D4FA}%d EUR{FFFFFF} | {FFD54F}%d CNY{FFFFFF}\n" \
        "- Bank Account (IBAN): {88CCFF}%s{FFFFFF} | Balance: {66CC66}%s{FFFFFF} | Credit Debt: {FFAA00}%s{FFFFFF}\n\n" \
        "{FFC800}3. Physiology & Dual-Layer Storage Physics:{FFFFFF}\n" \
        "- Health: {66CC66}%.1f HP{FFFFFF} | Armor: {81D4FA}%.1f%%{FFFFFF} | Stamina: {66CC66}%.1f%%{FFFFFF}\n" \
        "- Hunger: {FFD54F}%.1f%%{FFFFFF} | Thirst: {81D4FA}%.1f%%{FFFFFF} | Stress: {FFAB91}%.1f%%{FFFFFF} | Addiction: {CE93D8}%.1f%%{FFFFFF}\n" \
        "- Layer 1 (Outer Gear): {88CCFF}%d.%02d / %d.%02d kg{FFFFFF} | Volume: {88CCFF}%d.%02d / %d.%02d L{FFFFFF}\n" \
        "- Layer 2 (Concealed): {88CCFF}%d.%02d / %d.%02d kg{FFFFFF} | Volume: {88CCFF}%d.%02d / %d.%02d L{FFFFFF}",
        rpName, Account_GetId(playerid), Character_GetId(playerid),
        Character_GetLevel(playerid), Character_GetExpSeconds(playerid), Character_GetAge(playerid),
        (Character_GetCitizenship(playerid) == CITIZENSHIP_CITIZEN) ? ("{66CC66}US Citizen{FFFFFF}") : ("{FFAA00}Immigrant{FFFFFF}"),
        ssnBuf,
        roleName, Character_GetRoleId(playerid),
        orgName, rankTitle,
        wantedLvl, decayLeft, Character_GetJailSecondsLeft(playerid),
        cleanUsdStr, dirtyUsdStr,
        eurCash, cnyCash,
        ibanBuf, bankStr, debtStr,
        Character_GetHP(playerid), Character_GetArmour(playerid), Character_GetStamina(playerid),
        Character_GetHunger(playerid), Character_GetThirst(playerid), Character_GetStress(playerid), Character_GetAddiction(playerid),
        l1W / 1000, (l1W % 1000) / 10, l1MaxW / 1000, (l1MaxW % 1000) / 10,
        l1V / 1000, (l1V % 1000) / 10, l1MaxV / 1000, (l1MaxV % 1000) / 10,
        l2W / 1000, (l2W % 1000) / 10, l2MaxW / 1000, (l2MaxW % 1000) / 10,
        l2V / 1000, (l2V % 1000) / 10, l2MaxV / 1000, (l2MaxV % 1000) / 10
    );

    ShowPlayerDialog(
        playerid,
        DIALOG_MM_STATS_CARD,
        DIALOG_STYLE_MSGBOX,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Character Statistics (/stats)",
        body,
        "Main Menu",
        "Close"
    );
    return 1;
}

/*
 * 4.2. ѕросмотр 41 навыка по 5 категори€м и перков выбранной роли (/skills в /mm)
 */
stock MainMenu_ShowSkillsHub(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    new roleName[48];
    Roles_GetNameRu(Character_GetRoleId(playerid), roleName, sizeof(roleName));

    static body[768];
    body[0] = '\0';
    strcat(body, "Category\tSkills Count\tScale\n", sizeof(body));
    strcat(body, "1. {FFD54F}Full 41-Skill Matrix (All Categories)\t41 Skills\t0..1000\n", sizeof(body));
    strcat(body, "2. Weapon & Combat Mastery\t18 Skills\t0..1000\n", sizeof(body));
    strcat(body, "3. Physical Conditioning & Vehicles\t7 Skills\t0..1000\n", sizeof(body));
    strcat(body, "4. Criminal & Subterfuge Arts\t6 Skills\t0..1000\n", sizeof(body));
    strcat(body, "5. Industrial Crafting & Extraction\t5 Skills\t0..1000\n", sizeof(body));
    strcat(body, "6. Medicine, Forensics & Survival\t5 Skills\t0..1000\n", sizeof(body));

    new roleRow[160];
    format(roleRow, sizeof(roleRow),
        "7. {81D4FA}Starting Role Archetype & Perks (%s)\tRole #%d\tPerks / Debuffs\n",
        roleName, Character_GetRoleId(playerid));
    strcat(body, roleRow, sizeof(body));

    for (new i = 0; i < 7; i++)
    {
        sPlayerSkillCatMap[playerid][i] = i;
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_MM_SKILLS_CATEGORIES,
        DIALOG_STYLE_TABLIST_HEADERS,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Skills & Role Perks (/skills)",
        body,
        "View",
        "Main Menu"
    );
    return 1;
}

static stock Internal_ShowSkillCategorySlice(playerid, categoryIdx)
{
    if (categoryIdx == 0)
    {
        Skills_ShowDialog(playerid);
        return 1;
    }
    if (categoryIdx == 6)
    {
        new card[1280];
        Roles_FormatDetailedCardRu(Character_GetRoleId(playerid), card, sizeof(card));
        ShowPlayerDialog(
            playerid,
            DIALOG_MM_SKILLS_LIST,
            DIALOG_STYLE_MSGBOX,
            "{FFC800}SAN ANDREAS RP {FFFFFF}| Starting Role Perks & Modifiers (/roleinfo)",
            card,
            "Back",
            "Close"
        );
        return 1;
    }

    new firstIdx = 0, lastIdx = 17;
    new catTitle[64];
    switch (categoryIdx)
    {
        case 1: { firstIdx = 0;  lastIdx = 17; format(catTitle, sizeof(catTitle), "Weapon & Combat Mastery (18 Skills)"); }
        case 2: { firstIdx = 18; lastIdx = 24; format(catTitle, sizeof(catTitle), "Physical & Vehicle Skills (7 Skills)"); }
        case 3: { firstIdx = 25; lastIdx = 30; format(catTitle, sizeof(catTitle), "Criminal & Subterfuge Skills (6 Skills)"); }
        case 4: { firstIdx = 31; lastIdx = 35; format(catTitle, sizeof(catTitle), "Industrial & Crafting Skills (5 Skills)"); }
        case 5: { firstIdx = 36; lastIdx = 40; format(catTitle, sizeof(catTitle), "Medical, Forensics & Survival (5 Skills)"); }
    }

    static body[2048];
    body[0] = '\0';
    strcat(body, "Skill Name\tDomain\tCurrent / Max Ceiling\n", sizeof(body));

    new skName[48], skCat[32], row[160];
    for (new s = firstIdx; s <= lastIdx; s++)
    {
        new const E_SKILL_TYPE:sk = E_SKILL_TYPE:s;
        new const val = Skills_Get(playerid, sk);
        new const cap = Skills_GetCap(playerid, sk);
        Skills_GetNameRu(sk, skName, sizeof(skName));
        Skills_GetCategoryRu(sk, skCat, sizeof(skCat));

        format(row, sizeof(row), "%s\t%s\t%d / %d\n", skName, skCat, val, cap);
        strcat(body, row, sizeof(body));
    }

    new header[128];
    format(header, sizeof(header), "{FFC800}Skills Matrix {FFFFFF}| %s", catTitle);

    ShowPlayerDialog(
        playerid,
        DIALOG_MM_SKILLS_LIST,
        DIALOG_STYLE_TABLIST_HEADERS,
        header,
        body,
        "Back",
        "Close"
    );
    return 1;
}

/*
 * 4.3. ѕолный структурированный  одекс команд и механик сервера (/help)
 */
stock MainMenu_ShowHelpCodex(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    new orgLabel[64];
    new const orgId = Character_GetOrgId(playerid);
    if (orgId > 0 && Organizations_IsValid(orgId))
    {
        Organizations_GetTag(orgId, orgLabel, sizeof(orgLabel));
    }
    else
    {
        format(orgLabel, sizeof(orgLabel), "Civilian / Custom Org");
    }

    static body[1024];
    body[0] = '\0';
    strcat(body, "Section\tPrimary Commands\tFocus\n", sizeof(body));
    strcat(body, "1. Core Controls & Mobile Hotkeys\t/act (Y), /inv (N), /mm (H/LALT)\tPC & Mobile UX\n", sizeof(body));
    strcat(body, "2. Roleplay & Proximity Chat\t/me, /do, /try, /todo, /b, /s, /w\tIC/OOC & IDs\n", sizeof(body));
    strcat(body, "3. Inventory, Survival & Medical\t/inv, /give, /pay, /triage, /treat, /ck\t2-Layer & Trauma\n", sizeof(body));
    strcat(body, "4. Vehicles & Real Estate\t/engine, /lock, /trunk, /house, /garage\tKeys, Fuel & Theft\n", sizeof(body));
    strcat(body, "5. Telecom, SIM Cards & Radio\t/phone, /call, /sms, /radio, /sim\tPhones & Walkie-Talkie\n", sizeof(body));
    strcat(body, "6. Jobs, Crafting, Ports & Economy\t/mine, /craft, /biz, /port, /bank\tZero-Faucet Loop\n", sizeof(body));

    new facRow[160];
    format(facRow, sizeof(facRow),
        "7. {81D4FA}Your Faction & Law Enforcement (%s)\t/org, /cuff, /search, /arrest, /ev\tDynamic Faction Guide\n",
        orgLabel);
    strcat(body, facRow, sizeof(body));

    for (new i = 0; i < 7; i++)
    {
        sPlayerHelpCatMap[playerid][i] = i;
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_MM_HELP_CATEGORIES,
        DIALOG_STYLE_TABLIST_HEADERS,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Server Help & Command Codex (/help)",
        body,
        "Read",
        "Main Menu"
    );
    return 1;
}

static stock Internal_ShowHelpCategoryPage(playerid, categoryIdx)
{
    static body[3072];
    body[0] = '\0';
    new title[128];

    switch (categoryIdx)
    {
        case 0: // 1. Core Controls & Hotkeys
        {
            format(title, sizeof(title), "{FFC800}Command Codex {FFFFFF}| 1. Core Controls & Hotkeys");
            strcat(body,
                "{FFC800}Command-First & Mobile-Ready Control Architecture:{FFFFFF}\n" \
                "Every single mechanic on San Andreas RP has a chat command so PC and Mobile (Android/iOS)\n" \
                "players enjoy 100% feature parity. Hardware keys act as instant shortcuts:\n\n" \
                "{66CC66}- Key [Y] or /act (/interact):{FFFFFF} Scans 3.0m around you for nearby players, vehicles,\n" \
                "  dropped items, corpses, doors, workbenches, ports, banks, faction vaults and forensic traces.\n" \
                "{66CC66}- Key [N] or /inv (/i):{FFFFFF} Opens your Dual-Layer Inventory (Layer 1 Outer + Layer 2 Concealed).\n" \
                "{66CC66}- Key [H] / [LALT] or /mm (/menu):{FFFFFF} Opens the Character Main Menu, Stats, Skills, GPS & Reports.\n\n" \
                "{FFC800}Essential Navigation & Utility Commands:{FFFFFF}\n" \
                "- {88CCFF}/mm{FFFFFF} (or {88CCFF}/menu{FFFFFF}) Ч Open the Central Character Menu\n" \
                "- {88CCFF}/act{FFFFFF} (or {88CCFF}/interact{FFFFFF}) Ч Open Context Environment & Player Interaction Scanner\n" \
                "- {88CCFF}/inv{FFFFFF} (or {88CCFF}/i{FFFFFF}) Ч Open Dual-Layer Inventory (grams & milliliters physics)\n" \
                "- {88CCFF}/stats{FFFFFF} Ч View full character biography, finances, weights and physiology\n" \
                "- {88CCFF}/skills{FFFFFF} Ч View 41-Skill Matrix (0..1000) and starting role perks ({88CCFF}/roleinfo{FFFFFF})\n" \
                "- {88CCFF}/gps{FFFFFF} Ч Set a map waypoint to hospitals, police, ports, mines, banks or clear route\n" \
                "- {88CCFF}/report [text]{FFFFFF} (or {88CCFF}/ask{FFFFFF}) Ч Submit an inquiry or rule-violation report to staff\n" \
                "- {88CCFF}/settings{FFFFFF} (or {88CCFF}/hud{FFFFFF}) Ч Toggle survival text HUD, hints and change account password",
                sizeof(body));
        }
        case 1: // 2. Roleplay & Chat Commands
        {
            format(title, sizeof(title), "{FFC800}Command Codex {FFFFFF}| 2. Roleplay & Chat Commands");
            strcat(body,
                "{FFC800}Proximity Roleplay & Communication Commands:{FFFFFF}\n" \
                "English is the official language of server UI and state institutions, while players have\n" \
                "complete freedom to communicate in any language in IC/OOC chats.\n\n" \
                "- {88CCFF}/me [action]{FFFFFF} Ч First-person visible physical action (18m radius + 3D bubble)\n" \
                "- {88CCFF}/do [description]{FFFFFF} Ч Third-person environment or state description (18m radius)\n" \
                "- {88CCFF}/try [attempt]{FFFFFF} Ч Probabilistic action attempt with {66BB6A}[Successful]{FFFFFF} / {EF5350}[Failed]{FFFFFF} outcome\n" \
                "- {88CCFF}/todo [speech]*[action]{FFFFFF} Ч Speak a phrase while performing an action simultaneously\n" \
                "- {88CCFF}/s [text]{FFFFFF} (or {88CCFF}/shout{FFFFFF}) Ч Shout loudly across a 32m radius\n" \
                "- {88CCFF}/w [text]{FFFFFF} (or {88CCFF}/whisper{FFFFFF}) Ч Quiet whisper within a close 4m radius\n" \
                "- {88CCFF}/b [text]{FFFFFF} Ч Out-of-Character (OOC) local proximity chat (15m radius)\n\n" \
                "{FFC800}Personal Documents & Identification:{FFFFFF}\n" \
                "- {88CCFF}/showpass [id]{FFFFFF} (or {88CCFF}/pass{FFFFFF}) Ч Present your State of San Andreas Passport & SSN\n" \
                "- {88CCFF}/showlic [id]{FFFFFF} (or {88CCFF}/lic{FFFFFF}) Ч Present your Firearms License, Vehicle Title & Bank Card",
                sizeof(body));
        }
        case 2: // 3. Inventory, Survival & Medical
        {
            format(title, sizeof(title), "{FFC800}Command Codex {FFFFFF}| 3. Inventory, Survival & Medical");
            strcat(body,
                "{FFC800}Dual-Layer Inventory & Weapon Ammo Physics:{FFFFFF}\n" \
                "- {88CCFF}Layer 1 (External):{FFFFFF} Pockets, vests and backpacks ({88CCFF}NESTED_BAG{FFFFFF}, max depth 2). 100% dropped into\n" \
                "  a lootable {FF8A65}CORPSE_LOOT{FFFFFF} container upon death (PK).\n" \
                "- {88CCFF}Layer 2 (Concealed):{FFFFFF} Passports, bank cards, keys, phones and equipped outfits. Preserved on PK.\n" \
                "- {88CCFF}/inv{FFFFFF} (or {88CCFF}/i{FFFFFF}) Ч Manage items, equip outfits, open backpacks, drop or transfer items\n" \
                "- {88CCFF}/pay [id] [amount]{FFFFFF} (or {88CCFF}/give [id] [amount]{FFFFFF}) Ч Hand over physical USD banknotes\n" \
                "- {88CCFF}/unload{FFFFFF} Ч Unload or split rounds between firearms (no separate ammo items exist)\n" \
                "- {88CCFF}/combine{FFFFFF} Ч Consolidate rounds between two identical firearms (recalculates mass in grams)\n\n" \
                "{FFC800}Zonal Trauma, Bleeding & PK / CK Medicine:{FFFFFF}\n" \
                "- {88CCFF}/triage [id]{FFFFFF} Ч Inspect a patient's head, torso, limb fractures, pain shock and bleeding\n" \
                "- {88CCFF}/treat [id]{FFFFFF} Ч Apply Sterile Bandage (venous), Tourniquet (arterial 90s timer), Morphine or Surgery\n" \
                "- {88CCFF}/frisk [id]{FFFFFF} Ч Pat down a player's outer Layer 1 gear\n" \
                "- {88CCFF}/search [id]{FFFFFF} Ч Full search of Layer 1 + Layer 2 with item seizure (target cuffed or hands up)\n" \
                "- {88CCFF}/pickpocket [id]{FFFFFF} Ч Attempt stealth theft from Layer 1 based on {FFC800}PICKPOCKETING{FFFFFF} skill\n" \
                "- {88CCFF}/ck{FFFFFF} Ч Voluntary irreversible Character Kill (permanent death of character)",
                sizeof(body));
        }
        case 3: // 4. Vehicles & Real Estate
        {
            format(title, sizeof(title), "{FFC800}Command Codex {FFFFFF}| 4. Vehicles & Real Estate");
            strcat(body,
                "{FFC800}Vehicles, Physical Keys, Fuel Types & Grand Theft Auto:{FFFFFF}\n" \
                "- {88CCFF}/engine{FFFFFF} (or {88CCFF}/vengine{FFFFFF}, {88CCFF}/en{FFFFFF}) Ч Start or stop vehicle engine (requires physical key or hotwire)\n" \
                "- {88CCFF}/lock{FFFFFF} (or {88CCFF}/vlock{FFFFFF}) Ч Lock or unlock vehicle doors with a matching physical key\n" \
                "- {88CCFF}/trunk{FFFFFF} Ч Open vehicle trunk storage (300L cars up to 100+ tons for freight trucks)\n" \
                "- {88CCFF}/glovebox{FFFFFF} Ч Open vehicle cabin glove compartment (5-10L)\n" \
                "- {88CCFF}/refuel{FFFFFF} Ч Refuel at a gas station or from a 20L canister ({88CCFF}REGULAR{FFFFFF}, {88CCFF}DIESEL{FFFFFF}, {88CCFF}JET_FUEL{FFFFFF})\n" \
                "- {88CCFF}/repair{FFFFFF} Ч Repair engine & body using a Mechanic's Wrench Kit\n" \
                "- {88CCFF}/vstats{FFFFFF} Ч Inspect vehicle plate, fuel level, engine & body condition\n" \
                "- {88CCFF}/vkey{FFFFFF} Ч Craft a duplicate physical vehicle key | {88CCFF}/vbuy{FFFFFF} ({88CCFF}/cars{FFFFFF}) Ч Buy at dealership\n" \
                "- {88CCFF}/lockpick{FFFFFF} Ч Pick vehicle or property door lock | {88CCFF}/breakwindow{FFFFFF} Ч Smash car window (leaves DNA/glass)\n" \
                "- {88CCFF}/hotwire{FFFFFF} Ч Hotwire ignition wires | {88CCFF}/chopshop{FFFFFF} ({88CCFF}/chop{FFFFFF}) Ч Dismantle stolen car for parts\n\n" \
                "{FFC800}Real Estate, Utilities & Garages:{FFFFFF}\n" \
                "- {88CCFF}/house{FFFFFF} (or {88CCFF}/property{FFFFFF}, {88CCFF}/prop{FFFFFF}, {88CCFF}/rent{FFFFFF}) Ч Enter/exit property, buy, rent or open home stash\n" \
                "- {88CCFF}/plock{FFFFFF} Ч Lock or unlock property door | {88CCFF}/propertykey{FFFFFF} Ч Order duplicate house key\n" \
                "- {88CCFF}/paybills{FFFFFF} (or {88CCFF}/payutils{FFFFFF}) Ч Pay electricity & water utility bills\n" \
                "- {88CCFF}/vpark{FFFFFF} Ч Store vehicle in property garage | {88CCFF}/garage{FFFFFF} ({88CCFF}/vunpark{FFFFFF}) Ч Retrieve vehicle from garage\n" \
                "- {88CCFF}/kickdoor{FFFFFF} Ч Breach locked property door with one kick (Ex-SWAT role perk)",
                sizeof(body));
        }
        case 4: // 5. Telecom & Radio
        {
            format(title, sizeof(title), "{FFC800}Command Codex {FFFFFF}| 5. Telecom, SIM Cards & Radio");
            strcat(body,
                "{FFC800}Smartphones, Untraceable Burner Phones & Radio Frequencies:{FFFFFF}\n" \
                "- Legal SIM cards are registered to the buyer's {88CCFF}SSN{FFFFFF} upon purchase. Disposable {FFAB91}Burner Phones{FFFFFF}\n" \
                "  have no SSN registration and keep callers anonymous from standard billing lookups.\n\n" \
                "- {88CCFF}/phone{FFFFFF} (or {88CCFF}/tel{FFFFFF}) Ч Open mobile phone terminal (check number, call, SMS, SIM status)\n" \
                "- {88CCFF}/call [number]{FFFFFF} Ч Dial a phone number or answer/hang up an active call\n" \
                "- {88CCFF}/sms [number] [text]{FFFFFF} Ч Send an instant text message to another phone number\n" \
                "- {88CCFF}/sim{FFFFFF} Ч Purchase a new SIM card at a retail store\n" \
                "- {88CCFF}/insertsim [slot]{FFFFFF} Ч Insert a SIM card into your phone | {88CCFF}/ejectsim{FFFFFF} Ч Remove active SIM card\n" \
                "- {88CCFF}/radio [freq kHz]{FFFFFF} Ч Tune your Walkie-Talkie frequency (e.g. {88CCFF}104500{FFFFFF} for 104.500 MHz, 0 = OFF)\n" \
                "- {88CCFF}/r [message]{FFFFFF} Ч Transmit a voice message over your currently tuned radio frequency\n\n" \
                "{FFC800}Intelligence & Counter-Surveillance (FBI / CIA Charter):{FFFFFF}\n" \
                "- {88CCFF}/wiretap [number]{FFFFFF} Ч Place a target phone number under federal wiretap surveillance\n" \
                "- {88CCFF}/radioscan{FFFFFF} Ч Scan active Walkie-Talkie frequencies in the area",
                sizeof(body));
        }
        case 5: // 6. Jobs, Crafting, Ports & Economy
        {
            format(title, sizeof(title), "{FFC800}Command Codex {FFFFFF}| 6. Jobs, Crafting, Ports & Economy");
            strcat(body,
                "{FFC800}Zero-Faucet Production, Global Ports & Banking:{FFFFFF}\n" \
                "No items or dollars spawn out of thin air. Workers are paid strictly from the enterprise's\n" \
                "{66CC66}reserve_usd{FFFFFF}, and port exports split revenue {FFC800}90% Owner / 5% Trucker / 5% State Tariff{FFFFFF}.\n\n" \
                "- {88CCFF}/mine{FFFFFF} (or {88CCFF}/work{FFFFFF}) Ч Extract iron ore, crude oil, timber or grain at a primary site\n" \
                "- {88CCFF}/deliver{FFFFFF} Ч Deliver extracted raw materials to the enterprise warehouse for cash wages\n" \
                "- {88CCFF}/craft{FFFFFF} Ч Smelt steel, refine fuel/plastic or assemble weapons & gear at a workbench\n" \
                "- {88CCFF}/biz{FFFFFF} (or {88CCFF}/enterprise{FFFFFF}) Ч Manage owned enterprise reserves, wages and retail goods\n" \
                "- {88CCFF}/market{FFFFFF} Ч View or post enterprise B2B buy/sell commodity orders\n" \
                "- {88CCFF}/auction{FFFFFF} Ч Bid on unowned state enterprises at auction\n" \
                "- {88CCFF}/port{FFFFFF} Ч Access Port of LS, SF or LV import/export commodity terminal\n" \
                "- {88CCFF}/contracts{FFFFFF} (or {88CCFF}/contract{FFFFFF}) Ч Browse & accept freight trucking logistics contracts\n" \
                "- {88CCFF}/cargo{FFFFFF} Ч Load or unload contracted freight boxes into a truck trunk\n" \
                "- {88CCFF}/bank{FFFFFF} (or {88CCFF}/atm{FFFFFF}) Ч Open bank account, deposit/withdraw clean USD, transfer by IBAN, exchange EUR/CNY\n" \
                "- {88CCFF}/cash{FFFFFF} Ч Inspect clean vs. dirty banknotes in your pockets\n" \
                "- {88CCFF}/launder{FFFFFF} (or {88CCFF}/wash{FFFFFF}) Ч Launder dirty cash through a cash-intensive business (15-25% tax)",
                sizeof(body));
        }
        case 6: // 7. Dynamic Faction & Law Enforcement Commands
        {
            new const orgId = Character_GetOrgId(playerid);
            new orgName[64], orgTag[16];
            if (orgId > 0 && Organizations_IsValid(orgId))
            {
                Organizations_GetName(orgId, orgName, sizeof(orgName));
                Organizations_GetTag(orgId, orgTag, sizeof(orgTag));
            }
            else
            {
                format(orgName, sizeof(orgName), "No Active Organization");
                format(orgTag, sizeof(orgTag), "NONE");
            }

            format(title, sizeof(title), "{FFC800}Command Codex {FFFFFF}| 7. Faction & Law Commands (%s)", orgTag);
            new headerBlock[512];
            format(headerBlock, sizeof(headerBlock),
                "{FFC800}Your Current Affiliation:{FFFFFF} {88CCFF}%s [%s]{FFFFFF}\n\n" \
                "{FFC800}Universal Organization & Syndicate Commands:{FFFFFF}\n" \
                "- {88CCFF}/org{FFFFFF} Ч Open Organization Control Panel (ranks, RBAC permissions, members, create org)\n" \
                "- {88CCFF}/orginvite [id]{FFFFFF} Ч Invite a player into your organization | {88CCFF}/orgfire [id]{FFFFFF} Ч Dismiss member\n" \
                "- {88CCFF}/orgvault{FFFFFF} Ч Open your faction's physical treasury safe ({88CCFF}ORG_VAULT{FFFFFF})\n" \
                "- {88CCFF}/orgbank{FFFFFF} Ч Manage corporate bank account | {88CCFF}/orgradio{FFFFFF} Ч Set faction radio frequency\n" \
                "- {88CCFF}/vaultbreak{FFFFFF} ({88CCFF}/crackvault{FFFFFF}) Ч Breach a faction safe using satchel charges or lockpicks\n\n",
                orgName, orgTag);
            strcat(body, headerBlock, sizeof(body));

            strcat(body,
                "{FFC800}Law Enforcement, Justice, Forensics & Government Commands:{FFFFFF}\n" \
                "- {88CCFF}/cuff [id]{FFFFFF} / {88CCFF}/uncuff [id]{FFFFFF} Ч Apply or remove Steel Handcuffs\n" \
                "- {88CCFF}/frisk [id]{FFFFFF} Ч Pat down Layer 1 | {88CCFF}/search [id]{FFFFFF} Ч Full Layer 1 + Layer 2 search & seizure\n" \
                "- {88CCFF}/warrant [id] [levels] [reason]{FFFFFF} Ч Issue wanted level (1..100 scale)\n" \
                "- {88CCFF}/clearwanted [id]{FFFFFF} Ч Clear suspect's wanted level\n" \
                "- {88CCFF}/arrest [id]{FFFFFF} Ч Book suspect into KPZ (1-5), State Prison (6-25) or Supermax (26-100)\n" \
                "- {88CCFF}/sentence [id] [minutes]{FFFFFF} Ч Judicial court sentencing | {88CCFF}/labor{FFFFFF} Ч Prison mining labor (-sentence)\n" \
                "- {88CCFF}/evidence{FFFFFF} ({88CCFF}/ev{FFFFFF}) Ч Scan crime scene for bullet casings, blood DNA, glass & lockpick marks\n" \
                "- {88CCFF}/wiretap [number]{FFFFFF} & {88CCFF}/radioscan{FFFFFF} Ч FBI / CIA communications interception\n" \
                "- {88CCFF}/orgcharter{FFFFFF}, {88CCFF}/orgstatus{FFFFFF}, {88CCFF}/orgfreeze{FFFFFF} Ч State Government charter & treasury regulation",
                sizeof(body));
        }
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_MM_HELP_CONTENT,
        DIALOG_STYLE_MSGBOX,
        title,
        body,
        "Back to Codex",
        "Close"
    );
    return 1;
}

/*
 * 4.4. ќбращение к администрации (/report и /ask)
 */
stock MainMenu_ShowReportDialog(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    new const nowUnix = gettime();
    if ((nowUnix - sPlayerLastReportUnix[playerid]) < REPORT_SUBMIT_COOLDOWN_SEC)
    {
        new const waitSec = REPORT_SUBMIT_COOLDOWN_SEC - (nowUnix - sPlayerLastReportUnix[playerid]);
        new msg[144];
        format(msg, sizeof(msg),
            "[Report]: Please wait %d sec. before submitting another ticket to the administration.",
            waitSec);
        SendClientMessage(playerid, COLOR_UI_WARNING, msg);
        return 0;
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_MM_REPORT_INPUT,
        DIALOG_STYLE_INPUT,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Contact Administration (/report)",
        "{FFFFFF}Describe your question, technical issue, or rule-violation report in detail:\n" \
        "{AFAFAF}(Include target player IDs and circumstances. Cooldown: 60 seconds){FFFFFF}",
        "Submit",
        "Back"
    );
    return 1;
}

static stock Internal_SubmitPlayerReport(playerid, const rawText[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    new const nowUnix = gettime();
    if ((nowUnix - sPlayerLastReportUnix[playerid]) < REPORT_SUBMIT_COOLDOWN_SEC)
    {
        new const waitSec = REPORT_SUBMIT_COOLDOWN_SEC - (nowUnix - sPlayerLastReportUnix[playerid]);
        new msg[144];
        format(msg, sizeof(msg),
            "[Report]: You can send a new report in %d seconds.",
            waitSec);
        SendClientMessage(playerid, COLOR_UI_WARNING, msg);
        return 0;
    }

    new cleanText[MAX_REPORT_TEXT_LEN];
    new idx = 0;
    while (rawText[idx] == ' ' || rawText[idx] == '\t')
    {
        idx++;
    }
    format(cleanText, sizeof(cleanText), "%s", rawText[idx]);

    new const textLen = strlen(cleanText);
    if (textLen < 4 || textLen > 130)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Report]: Report text must be between 4 and 130 characters long.");
        return 0;
    }

    // »щем свободный слот в очереди репортов (или перезаписываем самый старый)
    new freeSlot = -1;
    new oldestSlot = 0;
    new oldestTime = 0x7FFFFFFF;

    for (new i = 0; i < MAX_ADMIN_REPORTS; i++)
    {
        if (!sAdminReports[i][E_REP_ACTIVE])
        {
            freeSlot = i;
            break;
        }
        if (sAdminReports[i][E_REP_CREATED_UNIX] < oldestTime)
        {
            oldestTime = sAdminReports[i][E_REP_CREATED_UNIX];
            oldestSlot = i;
        }
    }
    if (freeSlot < 0)
    {
        freeSlot = oldestSlot;
    }

    new const repId = sNextReportSeqId++;
    sAdminReports[freeSlot][E_REP_ACTIVE] = true;
    sAdminReports[freeSlot][E_REP_ID] = repId;
    sAdminReports[freeSlot][E_REP_SENDER_PLAYERID] = playerid;
    sAdminReports[freeSlot][E_REP_SENDER_ACCOUNT_ID] = Account_GetId(playerid);
    sAdminReports[freeSlot][E_REP_SENDER_CHAR_ID] = Character_GetId(playerid);
    Character_GetRpName(playerid, sAdminReports[freeSlot][E_REP_SENDER_NAME], MAX_PLAYER_NAME + 1);
    format(sAdminReports[freeSlot][E_REP_TEXT], MAX_REPORT_TEXT_LEN, "%s", cleanText);
    sAdminReports[freeSlot][E_REP_CREATED_UNIX] = nowUnix;

    sPlayerLastReportUnix[playerid] = nowUnix;

    new confirmMsg[192];
    format(confirmMsg, sizeof(confirmMsg),
        "[Report #%d]: Your ticket has been sent to the administration: \"%s\"",
        repId, cleanText);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, confirmMsg);

    Internal_NotifyAdminsNewReport(freeSlot);

    Audit_Log(
        Character_GetId(playerid),
        "PLAYER_REPORT_SUBMIT",
        "CHARACTER",
        "ADMIN_QUEUE",
        0,
        repId,
        cleanText
    );
    return 1;
}

/*
 * 4.5. Ќастройки интерфейса и смена парол€ аккаунта (/settings)
 */
stock MainMenu_ShowSettings(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    static body[512];
    body[0] = '\0';
    strcat(body, "Setting Option\tCurrent Status\n", sizeof(body));

    new row[144];
    format(row, sizeof(row), "1. Survival Text HUD Display (/hud)\t%s\n",
        HUD_IsVisible(playerid) ? ("{66CC66}ENABLED{FFFFFF}") : ("{FF4444}HIDDEN{FFFFFF}"));
    strcat(body, row, sizeof(body));

    format(row, sizeof(row), "2. Context Interaction Hints for Newcomers\t%s\n",
        sPlayerHintsEnabled[playerid] ? ("{66CC66}ENABLED{FFFFFF}") : ("{AFAFAF}DISABLED{FFFFFF}"));
    strcat(body, row, sizeof(body));

    format(row, sizeof(row), "3. Chat Timestamp & Layout Advice\t%s\n",
        sPlayerTimestampHint[playerid] ? ("{81D4FA}ACTIVE{FFFFFF}") : ("{AFAFAF}MUTED{FFFFFF}"));
    strcat(body, row, sizeof(body));

    strcat(body, "4. {FFD54F}Change Account Password (bcrypt cost = 12)\tSecurity >>\n", sizeof(body));

    ShowPlayerDialog(
        playerid,
        DIALOG_MM_SETTINGS_LIST,
        DIALOG_STYLE_TABLIST_HEADERS,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Interface & Account Settings (/settings)",
        body,
        "Toggle / Open",
        "Main Menu"
    );
    return 1;
}

/*
 * 4.6. GPS-навигатор по ключевым локаци€м штата (/gps)
 */
stock MainMenu_ShowGpsCategories(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    static body[640];
    body[0] = '\0';
    strcat(body, "Location Category\tDestinations\n", sizeof(body));
    strcat(body, "1. Civic Centers, Banks & Auto Dealerships\tCity Hall, LS/SF/LV Banks, Showrooms\n", sizeof(body));
    strcat(body, "2. Hospitals, Police & Federal Agencies\tEMS Hospital, LSPD, SFPD, LVPD, SASD, FBI\n", sizeof(body));
    strcat(body, "3. Global Trade Ports & Freight Hubs\tPort of LS, Port of SF, LV Freight Terminal\n", sizeof(body));
    strcat(body, "4. Primary Extraction Sites (Jobs)\tIron Quarry, Oil Field, Sawmill, Grain Farm\n", sizeof(body));
    strcat(body, "5. Industrial Plants & Metallurgy\tOcean Docks Steel Mill & Processing\n", sizeof(body));
    strcat(body, "6. {FF8A65}Disable Active GPS Waypoint\tClear Map Checkpoint\n", sizeof(body));

    ShowPlayerDialog(
        playerid,
        DIALOG_MM_GPS_CATEGORIES,
        DIALOG_STYLE_TABLIST_HEADERS,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| State GPS Navigator (/gps)",
        body,
        "Select",
        "Main Menu"
    );
    return 1;
}

static stock Internal_ShowGpsCategoryPoints(playerid, E_GPS_CATEGORY:cat)
{
    if (cat == GPS_CAT_CLEAR)
    {
        DisablePlayerCheckpoint(playerid);
        sPlayerGpsActive[playerid] = false;
        SendClientMessage(playerid, COLOR_UI_INFO, "[GPS]: Active route waypoint has been cleared from your radar.");
        return 1;
    }

    sPlayerGpsPointCount[playerid] = 0;
    new Float:px = 0.0, Float:py = 0.0, Float:pz = 0.0;
    GetPlayerPos(playerid, px, py, pz);

    static body[1536];
    body[0] = '\0';
    strcat(body, "Destination\tCommands\tDistance\n", sizeof(body));

    for (new i = 0; i < MAX_GPS_POINTS; i++)
    {
        if (sGpsCatalog[i][E_GPS_CAT] != cat)
        {
            continue;
        }

        new const Float:dist = Utils_GetDistance3D(
            px, py, pz,
            sGpsCatalog[i][E_GPS_X],
            sGpsCatalog[i][E_GPS_Y],
            sGpsCatalog[i][E_GPS_Z]);

        new row[160];
        format(row, sizeof(row), "%s\t{88CCFF}%s{FFFFFF}\t%.0f m\n",
            sGpsCatalog[i][E_GPS_NAME],
            sGpsCatalog[i][E_GPS_CMD_HINT],
            dist);
        strcat(body, row, sizeof(body));

        sPlayerGpsPointMap[playerid][sPlayerGpsPointCount[playerid]++] = i;
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_MM_GPS_LOCATIONS,
        DIALOG_STYLE_TABLIST_HEADERS,
        "{FFC800}State GPS Navigator {FFFFFF}| Select Destination",
        body,
        "Set Route",
        "Back"
    );
    return 1;
}

// =============================================================================
//  5. ѕ”ЅЋ»„Ќџ… API √Ћј¬Ќќ√ќ ћ≈Ќё (/mm) » ќ„≈–≈ƒ» –≈ѕќ–“ќ¬ (/apanel)
// =============================================================================

stock MainMenu_Open(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Menu]: Complete character login before opening the Main Menu.");
        return 0;
    }

    sPlayerMmRootCount[playerid] = 0;

    static body[1024];
    body[0] = '\0';
    strcat(body, "Section\tShortcut Command\tDescription\n", sizeof(body));

    sPlayerMmRootMap[playerid][sPlayerMmRootCount[playerid]++] = MM_ROOT_STATS;
    strcat(body, "1. Character Statistics\t/stats\tBiography, SSN, cash, bank, weights & vitals\n", sizeof(body));

    sPlayerMmRootMap[playerid][sPlayerMmRootCount[playerid]++] = MM_ROOT_SKILLS;
    strcat(body, "2. Skills & Role Perks\t/skills\t41-skill matrix (0..1000) & archetype perks\n", sizeof(body));

    sPlayerMmRootMap[playerid][sPlayerMmRootCount[playerid]++] = MM_ROOT_HELP;
    strcat(body, "3. Server Help & Command Codex\t/help\tComplete handbook of commands & faction guides\n", sizeof(body));

    sPlayerMmRootMap[playerid][sPlayerMmRootCount[playerid]++] = MM_ROOT_REPORT;
    strcat(body, "4. Contact Administration\t/report\tAsk a question or report a rule violation\n", sizeof(body));

    sPlayerMmRootMap[playerid][sPlayerMmRootCount[playerid]++] = MM_ROOT_SETTINGS;
    strcat(body, "5. Interface & Account Settings\t/settings\tToggle HUD, hints & change account password\n", sizeof(body));

    sPlayerMmRootMap[playerid][sPlayerMmRootCount[playerid]++] = MM_ROOT_GPS;
    strcat(body, "6. GPS & Key Locations\t/gps\tSet radar waypoint to jobs, ports, banks & HQ\n", sizeof(body));

    sPlayerMmRootMap[playerid][sPlayerMmRootCount[playerid]++] = MM_ROOT_ACT;
    strcat(body, "7. {81D4FA}Context Interaction Scanner\t/act (Key Y)\tInteract with nearby players, vehicles & world\n", sizeof(body));

    sPlayerMmRootMap[playerid][sPlayerMmRootCount[playerid]++] = MM_ROOT_INV;
    strcat(body, "8. {FFD54F}Dual-Layer Inventory\t/inv (Key N)\tOpen Layer 1 (Outer) & Layer 2 (Secret Pocket)\n", sizeof(body));

    new rpName[MAX_PLAYER_NAME + 1], header[128];
    Character_GetRpName(playerid, rpName, sizeof(rpName));
    format(header, sizeof(header),
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Main Menu Ч %s [ID %d]",
        rpName, playerid);

    ShowPlayerDialog(
        playerid,
        DIALOG_MM_ROOT,
        DIALOG_STYLE_TABLIST_HEADERS,
        header,
        body,
        "Select",
        "Close"
    );
    return 1;
}

stock AdminReports_GetActiveCount()
{
    return Internal_GetActiveReportCount();
}

stock AdminReports_OpenQueueDialog(playerid)
{
    if (!Admin_HasPermission(playerid, ADMIN_PERM_PANEL_ACCESS) && !Admin_IsRoot(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Insufficient permissions to view the report queue.");
        Admin_LogDenied(playerid, "ADMIN_REPORTS_VIEW", "RBAC failure: insufficient rights");
        return 0;
    }

    sAdminReportListCount[playerid] = 0;

    static body[3072];
    body[0] = '\0';
    strcat(body, "Ticket #\tPlayer [ID]\tAge (sec)\tMessage Preview\n", sizeof(body));

    new const nowUnix = gettime();
    for (new i = 0; i < MAX_ADMIN_REPORTS; i++)
    {
        if (!sAdminReports[i][E_REP_ACTIVE])
        {
            continue;
        }

        new const ageSec = nowUnix - sAdminReports[i][E_REP_CREATED_UNIX];
        new row[224];
        format(row, sizeof(row), "#%d\t%s [%d]\t%ds ago\t%.64s\n",
            sAdminReports[i][E_REP_ID],
            sAdminReports[i][E_REP_SENDER_NAME],
            sAdminReports[i][E_REP_SENDER_PLAYERID],
            ageSec,
            sAdminReports[i][E_REP_TEXT]);
        strcat(body, row, sizeof(body));

        sAdminReportListMap[playerid][sAdminReportListCount[playerid]++] = i;
    }

    if (sAdminReportListCount[playerid] == 0)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "[Reports]: The player report queue is currently empty.");
        return 0;
    }

    new title[128];
    format(title, sizeof(title),
        "{FFC800}Admin Panel {FFFFFF}| Active Player Reports (%d)",
        sAdminReportListCount[playerid]);

    ShowPlayerDialog(
        playerid,
        DIALOG_ADMIN_REPORTS_LIST,
        DIALOG_STYLE_TABLIST_HEADERS,
        title,
        body,
        "Manage",
        "Close"
    );
    return 1;
}

static stock Internal_ShowAdminReportActions(playerid, slot)
{
    if (slot < 0 || slot >= MAX_ADMIN_REPORTS || !sAdminReports[slot][E_REP_ACTIVE])
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Reports]: This ticket has already been handled or closed.");
        AdminReports_OpenQueueDialog(playerid);
        return 0;
    }

    sAdminSelectedReportSlot[playerid] = slot;

    new title[128];
    format(title, sizeof(title),
        "Report #%d from %s [ID %d]",
        sAdminReports[slot][E_REP_ID],
        sAdminReports[slot][E_REP_SENDER_NAME],
        sAdminReports[slot][E_REP_SENDER_PLAYERID]);

    new body[512];
    format(body, sizeof(body),
        "1. {66CC66}Reply to Player & Resolve Ticket (/ans){FFFFFF}\n" \
        "2. {81D4FA}Spectate Sender (/sp %d){FFFFFF}\n" \
        "3. {FFD54F}Teleport to Sender (/goto %d){FFFFFF}\n" \
        "4. {EF5350}Close / Dismiss Ticket Without Reply{FFFFFF}",
        sAdminReports[slot][E_REP_SENDER_PLAYERID],
        sAdminReports[slot][E_REP_SENDER_PLAYERID]);

    ShowPlayerDialog(
        playerid,
        DIALOG_ADMIN_REPORT_ACTIONS,
        DIALOG_STYLE_LIST,
        title,
        body,
        "Select",
        "Back"
    );
    return 1;
}

// =============================================================================
//  6. ј—»Ќ’–ќЌЌџ≈  ќЋЅ≈ » —ћ≈Ќџ ѕј–ќЋя (bcrypt_verify / bcrypt_hash)
// =============================================================================

forward OnMmOldPasswordVerified(playerid, bool:success, sessionToken);
public OnMmOldPasswordVerified(playerid, bool:success, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 1;
    }
    if (!success)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Security]: Current password verification failed! Password change aborted.");
        Audit_Log(Character_GetId(playerid), "ACCOUNT_PASS_CHANGE_FAIL", "ACCOUNT", "SECURITY",
            0, Account_GetId(playerid), "Failed current password check in /settings");
        return 1;
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_MM_PASS_NEW,
        DIALOG_STYLE_PASSWORD,
        "{FFC800}Account Security {FFFFFF}| Enter New Password (Step 2/2)",
        "{66CC66}Current password verified.{FFFFFF}\n\n" \
        "Enter a new password for your account (6 to 32 characters, no spaces):",
        "Update",
        "Cancel"
    );
    return 1;
}

forward OnMmNewPasswordHashed(playerid, sessionToken);
public OnMmNewPasswordHashed(playerid, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 1;
    }

    new newHash[BCRYPT_HASH_LENGTH];
    bcrypt_get_hash(newHash, sizeof(newHash));
    sPlayerPendingNewPass[playerid][0] = '\0';

    if (!Account_UpdatePasswordHash(playerid, newHash))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Security]: Failed to update password hash. Please try again.");
        return 1;
    }

    SendClientMessage(playerid, COLOR_UI_SUCCESS,
        "[Security]: Your account password has been successfully updated (bcrypt cost = 12).");
    Audit_Log(Character_GetId(playerid), "ACCOUNT_PASS_CHANGED", "ACCOUNT", "SECURITY",
        0, Account_GetId(playerid), "Player changed account password via /settings");
    return 1;
}

// =============================================================================
//  7. —»—“≈ћЌџ≈ ’” » (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_ADMIN_REPORTS; i++)
    {
        sAdminReports[i][E_REP_ACTIVE] = false;
        sAdminReports[i][E_REP_ID] = 0;
        sAdminReports[i][E_REP_SENDER_PLAYERID] = INVALID_PLAYER_ID;
        sAdminReports[i][E_REP_SENDER_ACCOUNT_ID] = 0;
        sAdminReports[i][E_REP_SENDER_CHAR_ID] = 0;
        sAdminReports[i][E_REP_SENDER_NAME][0] = '\0';
        sAdminReports[i][E_REP_TEXT][0] = '\0';
        sAdminReports[i][E_REP_CREATED_UNIX] = 0;
    }
    for (new p = 0; p < MAX_PLAYERS; p++)
    {
        Internal_ResetPlayerMmState(p);
    }

    printf("%s [UI/MainMenu] Phase 12 Command-First Main Menu (/mm), Help Codex (/help), GPS (/gps) and Reports (/report) initialized.",
        SERVER_LOG_PREFIX);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    Internal_ResetPlayerMmState(playerid);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    for (new i = 0; i < MAX_ADMIN_REPORTS; i++)
    {
        if (sAdminReports[i][E_REP_ACTIVE] && sAdminReports[i][E_REP_SENDER_PLAYERID] == playerid)
        {
            sAdminReports[i][E_REP_ACTIVE] = false;
        }
    }
    Internal_ResetPlayerMmState(playerid);
    return 1;
}

hook OnPlayerEnterCheckpoint(playerid)
{
    if (sPlayerGpsActive[playerid])
    {
        DisablePlayerCheckpoint(playerid);
        sPlayerGpsActive[playerid] = false;
        GameTextForPlayer(playerid, "~g~DESTINATION REACHED", 2500, 3);
        SendClientMessage(playerid, COLOR_UI_SUCCESS, "[GPS]: You have arrived at your destination.");
    }
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch (dialogid)
    {
        case DIALOG_MM_ROOT:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sPlayerMmRootCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            switch (sPlayerMmRootMap[playerid][listitem])
            {
                case MM_ROOT_STATS:    MainMenu_ShowCharacterStats(playerid);
                case MM_ROOT_SKILLS:   MainMenu_ShowSkillsHub(playerid);
                case MM_ROOT_HELP:     MainMenu_ShowHelpCodex(playerid);
                case MM_ROOT_REPORT:   MainMenu_ShowReportDialog(playerid);
                case MM_ROOT_SETTINGS: MainMenu_ShowSettings(playerid);
                case MM_ROOT_GPS:      MainMenu_ShowGpsCategories(playerid);
                case MM_ROOT_ACT:      Dialogs_OpenActMenu(playerid);
                case MM_ROOT_INV:      Dialogs_OpenInventory(playerid, INV_VIEW_LAYER_1);
                default: {}
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_MM_STATS_CARD:
        {
            if (response)
            {
                MainMenu_Open(playerid);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_MM_SKILLS_CATEGORIES:
        {
            if (!response)
            {
                MainMenu_Open(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= 7)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ShowSkillCategorySlice(playerid, sPlayerSkillCatMap[playerid][listitem]);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_MM_SKILLS_LIST:
        {
            if (response)
            {
                MainMenu_ShowSkillsHub(playerid);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_MM_HELP_CATEGORIES:
        {
            if (!response)
            {
                MainMenu_Open(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= 7)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ShowHelpCategoryPage(playerid, sPlayerHelpCatMap[playerid][listitem]);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_MM_HELP_CONTENT:
        {
            if (response)
            {
                MainMenu_ShowHelpCodex(playerid);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_MM_REPORT_INPUT:
        {
            if (!response)
            {
                MainMenu_Open(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_SubmitPlayerReport(playerid, inputtext);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_MM_SETTINGS_LIST:
        {
            if (!response)
            {
                MainMenu_Open(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            switch (listitem)
            {
                case 0:
                {
                    pc_cmd_hud(playerid, sMmEmptyCmdParams);
                    MainMenu_ShowSettings(playerid);
                }
                case 1:
                {
                    sPlayerHintsEnabled[playerid] = !sPlayerHintsEnabled[playerid];
                    SendClientMessage(playerid, COLOR_UI_INFO,
                        sPlayerHintsEnabled[playerid]
                            ? ("[Settings]: Context interaction hints for newcomers are now ENABLED.")
                            : ("[Settings]: Context interaction hints for newcomers are now DISABLED."));
                    MainMenu_ShowSettings(playerid);
                }
                case 2:
                {
                    sPlayerTimestampHint[playerid] = !sPlayerTimestampHint[playerid];
                    SendClientMessage(playerid, COLOR_UI_INFO,
                        "[Settings]: Use client command /timestamp and /pagesize [10-20] to customize chat timestamps and line count.");
                    MainMenu_ShowSettings(playerid);
                }
                case 3:
                {
                    ShowPlayerDialog(
                        playerid,
                        DIALOG_MM_PASS_OLD,
                        DIALOG_STYLE_PASSWORD,
                        "{FFC800}Account Security {FFFFFF}| Verify Current Password (Step 1/2)",
                        "{FFFFFF}Enter your current account password to authorize a password change:",
                        "Verify",
                        "Back"
                    );
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_MM_PASS_OLD:
        {
            if (!response)
            {
                MainMenu_ShowSettings(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (strlen(inputtext) < 1)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Security]: Current password cannot be empty.");
                MainMenu_ShowSettings(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new currentHash[BCRYPT_HASH_LENGTH];
            Account_GetPasswordHash(playerid, currentHash, sizeof(currentHash));
            bcrypt_verify(
                playerid,
                "OnMmOldPasswordVerified",
                inputtext,
                currentHash,
                "d",
                Config_GetPlayerSessionToken(playerid)
            );
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_MM_PASS_NEW:
        {
            if (!response)
            {
                MainMenu_ShowSettings(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new const passLen = strlen(inputtext);
            if (passLen < 6 || passLen > 32)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Security]: New password must be between 6 and 32 characters.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            for (new i = 0; i < passLen; i++)
            {
                if (inputtext[i] < 33 || inputtext[i] == '%')
                {
                    SendClientMessage(playerid, COLOR_UI_ERROR, "[Security]: Password must not contain spaces or control characters.");
                    return Y_HOOKS_BREAK_RETURN_1;
                }
            }
            format(sPlayerPendingNewPass[playerid], sizeof(sPlayerPendingNewPass[]), "%s", inputtext);
            bcrypt_hash(
                playerid,
                "OnMmNewPasswordHashed",
                sPlayerPendingNewPass[playerid],
                BCRYPT_WORK_FACTOR,
                "d",
                Config_GetPlayerSessionToken(playerid)
            );
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_MM_GPS_CATEGORIES:
        {
            if (!response)
            {
                MainMenu_Open(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem > 5)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ShowGpsCategoryPoints(playerid, E_GPS_CATEGORY:listitem);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_MM_GPS_LOCATIONS:
        {
            if (!response)
            {
                MainMenu_ShowGpsCategories(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sPlayerGpsPointCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new const gpsIdx = sPlayerGpsPointMap[playerid][listitem];
            if (gpsIdx < 0 || gpsIdx >= MAX_GPS_POINTS)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            SetPlayerCheckpoint(
                playerid,
                sGpsCatalog[gpsIdx][E_GPS_X],
                sGpsCatalog[gpsIdx][E_GPS_Y],
                sGpsCatalog[gpsIdx][E_GPS_Z],
                4.5
            );
            sPlayerGpsActive[playerid] = true;

            new msg[160];
            format(msg, sizeof(msg),
                "[GPS]: Waypoint set to \"%s\". Useful commands on arrival: %s",
                sGpsCatalog[gpsIdx][E_GPS_NAME],
                sGpsCatalog[gpsIdx][E_GPS_CMD_HINT]);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_REPORTS_LIST:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sAdminReportListCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ShowAdminReportActions(playerid, sAdminReportListMap[playerid][listitem]);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_REPORT_ACTIONS:
        {
            if (!response)
            {
                AdminReports_OpenQueueDialog(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new const slot = sAdminSelectedReportSlot[playerid];
            if (slot < 0 || slot >= MAX_ADMIN_REPORTS || !sAdminReports[slot][E_REP_ACTIVE])
            {
                SendClientMessage(playerid, COLOR_UI_WARNING, "[Reports]: Ticket is no longer active.");
                AdminReports_OpenQueueDialog(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const senderId = sAdminReports[slot][E_REP_SENDER_PLAYERID];
            switch (listitem)
            {
                case 0:
                {
                    new prompt[384];
                    format(prompt, sizeof(prompt),
                        "{FFC800}Ticket #%d from %s [ID %d]:{FFFFFF}\n\"%s\"\n\nEnter your official response to the player:",
                        sAdminReports[slot][E_REP_ID],
                        sAdminReports[slot][E_REP_SENDER_NAME],
                        senderId,
                        sAdminReports[slot][E_REP_TEXT]);
                    ShowPlayerDialog(
                        playerid,
                        DIALOG_ADMIN_REPORT_REPLY,
                        DIALOG_STYLE_INPUT,
                        "Reply to Player Report (/ans)",
                        prompt,
                        "Send Reply",
                        "Back"
                    );
                }
                case 1:
                {
                    new arg[16];
                    format(arg, sizeof(arg), "%d", senderId);
                    pc_cmd_sp(playerid, arg);
                }
                case 2:
                {
                    new arg[16];
                    format(arg, sizeof(arg), "%d", senderId);
                    pc_cmd_goto(playerid, arg);
                }
                case 3:
                {
                    new const repId = sAdminReports[slot][E_REP_ID];
                    new const targetAcc = sAdminReports[slot][E_REP_SENDER_ACCOUNT_ID];
                    new const targetChar = sAdminReports[slot][E_REP_SENDER_CHAR_ID];
                    sAdminReports[slot][E_REP_ACTIVE] = false;

                    if (IsPlayerConnected(senderId) && Character_IsLoaded(senderId) &&
                        Character_GetId(senderId) == targetChar)
                    {
                        new notice[144];
                        format(notice, sizeof(notice),
                            "[Report #%d]: Your ticket was reviewed and closed by an administrator.",
                            repId);
                        SendClientMessage(senderId, COLOR_UI_INFO, notice);
                    }

                    new details[128];
                    format(details, sizeof(details), "Closed report #%d", repId);
                    Admin_Audit(playerid, targetAcc, targetChar, "ADMIN_REPORT_CLOSE", 0, repId, details);
                    SendClientMessage(playerid, COLOR_UI_SUCCESS, "[Reports]: Ticket closed.");
                    AdminReports_OpenQueueDialog(playerid);
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ADMIN_REPORT_REPLY:
        {
            new const slot = sAdminSelectedReportSlot[playerid];
            if (!response)
            {
                if (slot >= 0 && slot < MAX_ADMIN_REPORTS && sAdminReports[slot][E_REP_ACTIVE])
                {
                    Internal_ShowAdminReportActions(playerid, slot);
                }
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (slot < 0 || slot >= MAX_ADMIN_REPORTS || !sAdminReports[slot][E_REP_ACTIVE])
            {
                SendClientMessage(playerid, COLOR_UI_WARNING, "[Reports]: Ticket is no longer active.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (strlen(inputtext) < 2)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Reports]: Reply text is too short.");
                Internal_ShowAdminReportActions(playerid, slot);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const repId = sAdminReports[slot][E_REP_ID];
            new const senderId = sAdminReports[slot][E_REP_SENDER_PLAYERID];
            new const targetAcc = sAdminReports[slot][E_REP_SENDER_ACCOUNT_ID];
            new const targetChar = sAdminReports[slot][E_REP_SENDER_CHAR_ID];
            sAdminReports[slot][E_REP_ACTIVE] = false;

            new adminName[MAX_PLAYER_NAME + 1];
            GetPlayerName(playerid, adminName, sizeof(adminName));

            if (IsPlayerConnected(senderId) && Character_IsLoaded(senderId) &&
                Character_GetId(senderId) == targetChar)
            {
                new replyMsg[224];
                format(replyMsg, sizeof(replyMsg),
                    "{66CC66}[Admin Reply to Report #%d] %s [%d]: {FFFFFF}%s",
                    repId, adminName, playerid, inputtext);
                SendClientMessage(senderId, COLOR_UI_SUCCESS, replyMsg);
            }

            new confirmAdmin[224];
            format(confirmAdmin, sizeof(confirmAdmin),
                "{66CC66}[Report #%d Resolved] {FFFFFF}You replied to %s [%d]: %s",
                repId, sAdminReports[slot][E_REP_SENDER_NAME], senderId, inputtext);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, confirmAdmin);

            new auditBuf[192];
            format(auditBuf, sizeof(auditBuf), "Reply to report #%d: %.120s", repId, inputtext);
            Admin_Audit(playerid, targetAcc, targetChar, "ADMIN_REPORT_REPLY", 0, repId, auditBuf);
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_0;
}

// =============================================================================
//  8.  ќћјЌƒџ (/mm, /menu, /help, /report, /ask, /settings, /gps, /reports, /ans)
// =============================================================================

CMD:mm(playerid, params[])
{
    #pragma unused params
    if (!Internal_CheckMmCooldown(playerid))
    {
        return 1;
    }
    MainMenu_Open(playerid);
    return 1;
}
alias:mm("menu", "mainmenu");

CMD:help(playerid, params[])
{
    #pragma unused params
    if (!Internal_CheckMmCooldown(playerid))
    {
        return 1;
    }
    MainMenu_ShowHelpCodex(playerid);
    return 1;
}
alias:help("commands", "cmds", "codex", "faq");

CMD:report(playerid, params[])
{
    if (!Internal_CheckMmCooldown(playerid))
    {
        return 1;
    }
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Report]: Complete character login first.");
        return 1;
    }

    new idx = 0;
    while (params[idx] == ' ' || params[idx] == '\t')
    {
        idx++;
    }
    if (params[idx] == '\0')
    {
        MainMenu_ShowReportDialog(playerid);
        return 1;
    }

    Internal_SubmitPlayerReport(playerid, params[idx]);
    return 1;
}
alias:report("ask", "rep");

CMD:settings(playerid, params[])
{
    #pragma unused params
    if (!Internal_CheckMmCooldown(playerid))
    {
        return 1;
    }
    MainMenu_ShowSettings(playerid);
    return 1;
}

CMD:gps(playerid, params[])
{
    if (!Internal_CheckMmCooldown(playerid))
    {
        return 1;
    }
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!strcmp(params, "off", true) || !strcmp(params, "clear", true))
    {
        Internal_ShowGpsCategoryPoints(playerid, GPS_CAT_CLEAR);
        return 1;
    }
    MainMenu_ShowGpsCategories(playerid);
    return 1;
}
alias:gps("nav");

CMD:reports(playerid, params[])
{
    #pragma unused params
    if (!Internal_CheckMmCooldown(playerid))
    {
        return 1;
    }
    AdminReports_OpenQueueDialog(playerid);
    return 1;
}

CMD:ans(playerid, params[])
{
    if (!Admin_HasPermission(playerid, ADMIN_PERM_PANEL_ACCESS) && !Admin_IsRoot(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Insufficient permissions for this command.");
        Admin_LogDenied(playerid, "ADMIN_ANS", "RBAC failure: insufficient rights");
        return 1;
    }
    if (!Internal_CheckMmCooldown(playerid))
    {
        return 1;
    }

    new i = 0;
    while (params[i] == ' ' || params[i] == '\t') i++;
    if (params[i] < '0' || params[i] > '9')
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Usage: /ans [player_id or report_id] [response text]");
        return 1;
    }

    new idTok[16];
    new j = 0;
    while (params[i] >= '0' && params[i] <= '9' && j < sizeof(idTok) - 1)
    {
        idTok[j++] = params[i++];
    }
    idTok[j] = '\0';

    while (params[i] == ' ' || params[i] == '\t') i++;
    if (params[i] == '\0')
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Usage: /ans [player_id or report_id] [response text]");
        return 1;
    }

    new const numId = strval(idTok);
    new slot = Internal_FindReportSlotById(numId);
    if (slot < 0)
    {
        for (new s = 0; s < MAX_ADMIN_REPORTS; s++)
        {
            if (sAdminReports[s][E_REP_ACTIVE] && sAdminReports[s][E_REP_SENDER_PLAYERID] == numId)
            {
                slot = s;
                break;
            }
        }
    }

    new adminName[MAX_PLAYER_NAME + 1];
    GetPlayerName(playerid, adminName, sizeof(adminName));

    if (slot >= 0)
    {
        new const repId = sAdminReports[slot][E_REP_ID];
        new const senderId = sAdminReports[slot][E_REP_SENDER_PLAYERID];
        new const targetAcc = sAdminReports[slot][E_REP_SENDER_ACCOUNT_ID];
        new const targetChar = sAdminReports[slot][E_REP_SENDER_CHAR_ID];
        sAdminReports[slot][E_REP_ACTIVE] = false;

        if (IsPlayerConnected(senderId) && Character_IsLoaded(senderId))
        {
            new msg[224];
            format(msg, sizeof(msg),
                "{66CC66}[Admin Reply to Report #%d] %s [%d]: {FFFFFF}%s",
                repId, adminName, playerid, params[i]);
            SendClientMessage(senderId, COLOR_UI_SUCCESS, msg);
        }

        new confirm[224];
        format(confirm, sizeof(confirm),
            "{66CC66}[Report #%d Resolved] {FFFFFF}Replied to %s [%d]: %s",
            repId, sAdminReports[slot][E_REP_SENDER_NAME], senderId, params[i]);
        SendClientMessage(playerid, COLOR_UI_SUCCESS, confirm);

        new auditDetails[192];
        format(auditDetails, sizeof(auditDetails), "Reply to report #%d: %.120s", repId, params[i]);
        Admin_Audit(playerid, targetAcc, targetChar, "ADMIN_REPORT_REPLY", 0, repId, auditDetails);
        return 1;
    }

    // ≈сли активного тикета нет Ч пр€мой ответ онлайн-игроку по ID
    if (numId < 0 || numId >= MAX_PLAYERS || !IsPlayerConnected(numId) || !Character_IsLoaded(numId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Reports]: Active ticket or online player with that ID was not found.");
        return 1;
    }

    new directMsg[224];
    format(directMsg, sizeof(directMsg),
        "{66CC66}[Message from Administrator %s (%d)]: {FFFFFF}%s",
        adminName, playerid, params[i]);
    SendClientMessage(numId, COLOR_UI_SUCCESS, directMsg);

    new targetName[MAX_PLAYER_NAME + 1];
    Character_GetRpName(numId, targetName, sizeof(targetName));
    format(directMsg, sizeof(directMsg),
        "{66CC66}[Admin PM to %s (%d)]: {FFFFFF}%s",
        targetName, numId, params[i]);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, directMsg);

    new auditDetails[192];
    format(auditDetails, sizeof(auditDetails), "Direct answer to player: %.120s", params[i]);
    Admin_Audit(playerid, Account_GetId(numId), Character_GetId(numId), "ADMIN_DIRECT_ANSWER", 0, 0, auditDetails);
    return 1;
}
alias:ans("pm", "ar");

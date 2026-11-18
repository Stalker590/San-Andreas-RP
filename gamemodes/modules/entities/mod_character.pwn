/*
 * =============================================================================
 *  SAN ANDREAS RP — Модуль персонажа, мастера создания и двухслойного инвентаря
 *  Файл:      gamemodes/modules/entities/mod_character.pwn
 *  Пункт:     ROADMAP [3.4] — Модуль персонажа и двухслойный инвентарь
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_character_included
    #endinput
#endif
#define _mod_character_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ, ИДЕНТИФИКАТОРЫ ДИАЛОГОВ И ФОРМУЛЫ ПРОГРЕССИИ
// =============================================================================

#define CHAR_BASE_AGE_OFFSET                    (17)
#define CHAR_AgeFromLevel(%0)                   (CHAR_BASE_AGE_OFFSET + (%0))

#define LEVEL_UP_ACTIVE_SECONDS                 (36000) // 10 часов активного онлайна = +1 Level (+1 год возраста)
#define WARRANT_DECAY_ACTIVE_SECONDS            (3600)  // 1 час активной игры = -1 уровень розыска
#define AFK_INACTIVE_THRESHOLD_MS               (90000) // Порог неактивности (90 сек без сетевых пакетов)
#define ROLE_SELECT_DIALOG_BUFFER_SIZE          (4096)  // Буфер ShowPlayerDialog для всех 25 ролей без обрезания

#define DIALOG_CHAR_SELECT_GENDER               (1030)
#define DIALOG_CHAR_SELECT_RACE                 (1031)
#define DIALOG_CHAR_SELECT_SKIN                 (1032)
#define DIALOG_CHAR_SELECT_ROLE_LIST            (1033)
#define DIALOG_CHAR_CONFIRM_ROLE                (1034)
#define DIALOG_CHAR_STATS_VIEW                  (1035)
#define DIALOG_CHAR_ROLE_INFO                   (1036)

enum E_CHAR_GENDER
{
    CHAR_GENDER_NONE = 0,
    CHAR_GENDER_MALE = 1,
    CHAR_GENDER_FEMALE = 2
};

enum E_CHAR_RACE
{
    CHAR_RACE_NONE = 0,
    CHAR_RACE_CAUCASIAN = 1,
    CHAR_RACE_AFRO = 2,
    CHAR_RACE_LATINO = 3,
    CHAR_RACE_ASIAN = 4
};

enum E_JAIL_TYPE
{
    JAIL_TYPE_NONE = 0,
    JAIL_TYPE_KPZ,
    JAIL_TYPE_STATE_PRISON,
    JAIL_TYPE_FEDERAL_SUPERMAX
};

// =============================================================================
//  2. СТРУКТУРЫ ДАННЫХ ПЕРСОНАЖА И БУФЕРЫ СОСТОЯНИЯ (static stock)
// =============================================================================

enum E_CHARACTER_DATA
{
    bool:E_CHAR_LOADED,
    bool:E_CHAR_IS_DIRTY,
    E_CHAR_DB_ID,
    E_CHAR_ACCOUNT_ID,
    E_CHAR_RP_NAME[MAX_PLAYER_NAME + 1],
    E_CHAR_GENDER:E_CHAR_GENDER_VAL,
    E_CHAR_RACE:E_CHAR_RACE_VAL,
    E_CHAR_ROLE_ID,
    E_CHAR_LEVEL,
    E_CHAR_EXP_SECONDS,
    E_CITIZENSHIP_TYPE:E_CHAR_CITIZENSHIP,
    E_CHAR_SSN[SSN_STRING_LENGTH],
    E_CHAR_SKIN_ID,

    // Физиология и выживание
    Float:E_CHAR_HP,
    Float:E_CHAR_ARMOUR,
    Float:E_CHAR_HUNGER,
    Float:E_CHAR_THIRST,
    Float:E_CHAR_STAMINA,
    Float:E_CHAR_STRESS,
    Float:E_CHAR_ADDICTION,
    E_CHAR_LAST_DRUG_AT,

    // Правовой статус
    E_CHAR_WANTED_LEVEL,
    E_CHAR_ACTIVE_PLAY_SECONDS,
    E_CHAR_JAIL_SECONDS_LEFT,
    E_JAIL_TYPE:E_CHAR_JAIL_KIND,
    bool:E_CHAR_WEAPON_LIC_BANNED,
    bool:E_CHAR_IS_CK_DEAD,

    // Двухслойная система хранилищ персонажа (ID в БД и слоты в пуле RAM)
    E_CHAR_LAYER1_DB_ID,
    E_CHAR_LAYER2_DB_ID,
    E_CHAR_LAYER1_SLOT,
    E_CHAR_LAYER2_SLOT,

    // Гардероб: активный (надетый) комплект одежды и счетчик незавершенных загрузок
    E_CHAR_EQUIPPED_OUTFIT_DB_ID,
    E_CHAR_INVENTORY_PENDING_LOADS,

    // Финансы и организация
    E_CHAR_ORG_ID,
    E_CHAR_ORG_RANK_ID,
    E_CHAR_BANK_ACC_DB_ID,
    E_CHAR_BANK_IBAN[IBAN_STRING_LENGTH],
    E_CHAR_BANK_BALANCE_USD,
    bool:E_CHAR_BANK_FROZEN,
    E_CHAR_BANK_DEBT_USD,

    // Позиция в мире
    Float:E_CHAR_POS_X,
    Float:E_CHAR_POS_Y,
    Float:E_CHAR_POS_Z,
    Float:E_CHAR_POS_A,
    E_CHAR_INTERIOR,
    E_CHAR_VW,

    // Временный выбор скина на этапе конструктора (0 = каноничный скин роли)
    E_CHAR_WIZARD_CUSTOM_SKIN,
    E_CHAR_WIZARD_STEP,
    bool:E_CHAR_SPAWN_APPLIED
};

static stock sCharacters[MAX_PLAYERS][E_CHARACTER_DATA];
static stock sSyntheticCharDbIdSeq = 0;
static stock sSyntheticBankAccDbIdSeq = 0;
static stock sCharSqlBuffer[2048];
static stock sRoleListDialogBuffer[ROLE_SELECT_DIALOG_BUFFER_SIZE];

// Серверный маппинг строк диалога выбора роли (защита от подмены listitem по разделу 7.1 AGENTS.md)
static stock sWizardRoleRowMap[MAX_PLAYERS][MAX_STARTER_ROLES];
static stock sWizardRoleRowCount[MAX_PLAYERS];

// Подборка стартовых казуальных скинов по полу и расе [gender 0..1][race 0..3][3 варианта]
static stock const sCasualSkins[2][4][3] =
{
    // Мужские скины (Европеоидная, Афроамериканская, Латиноамериканская, Азиатская)
    {
        { 26,  29,  101 },
        { 21,  24,  18  },
        { 47,  48,  184 },
        { 57,  58,  120 }
    },
    // Женские скины (Европеоидная, Афроамериканская, Латиноамериканская, Азиатская)
    {
        { 93,  91,  192 },
        { 13,  69,  195 },
        { 41,  56,  214 },
        { 141, 169, 263 }
    }
};

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ И ФОРМАТИРОВАНИЕ (static stock)
// =============================================================================

static stock Internal_ResetCharacterSlot(playerid)
{
    sCharacters[playerid][E_CHAR_LOADED] = false;
    sCharacters[playerid][E_CHAR_IS_DIRTY] = false;
    sCharacters[playerid][E_CHAR_DB_ID] = 0;
    sCharacters[playerid][E_CHAR_ACCOUNT_ID] = 0;
    sCharacters[playerid][E_CHAR_RP_NAME][0] = EOS;
    sCharacters[playerid][E_CHAR_GENDER_VAL] = CHAR_GENDER_MALE;
    sCharacters[playerid][E_CHAR_RACE_VAL] = CHAR_RACE_CAUCASIAN;
    sCharacters[playerid][E_CHAR_ROLE_ID] = 5;
    sCharacters[playerid][E_CHAR_LEVEL] = 1;
    sCharacters[playerid][E_CHAR_EXP_SECONDS] = 0;
    sCharacters[playerid][E_CHAR_CITIZENSHIP] = CITIZENSHIP_CITIZEN;
    sCharacters[playerid][E_CHAR_SSN][0] = EOS;
    sCharacters[playerid][E_CHAR_SKIN_ID] = 26;

    sCharacters[playerid][E_CHAR_HP] = 100.0;
    sCharacters[playerid][E_CHAR_ARMOUR] = 0.0;
    sCharacters[playerid][E_CHAR_HUNGER] = 100.0;
    sCharacters[playerid][E_CHAR_THIRST] = 100.0;
    sCharacters[playerid][E_CHAR_STAMINA] = 100.0;
    sCharacters[playerid][E_CHAR_STRESS] = 0.0;
    sCharacters[playerid][E_CHAR_ADDICTION] = 0.0;
    sCharacters[playerid][E_CHAR_LAST_DRUG_AT] = 0;

    sCharacters[playerid][E_CHAR_WANTED_LEVEL] = 0;
    sCharacters[playerid][E_CHAR_ACTIVE_PLAY_SECONDS] = 0;
    sCharacters[playerid][E_CHAR_JAIL_SECONDS_LEFT] = 0;
    sCharacters[playerid][E_CHAR_JAIL_KIND] = JAIL_TYPE_NONE;
    sCharacters[playerid][E_CHAR_WEAPON_LIC_BANNED] = false;
    sCharacters[playerid][E_CHAR_IS_CK_DEAD] = false;

    sCharacters[playerid][E_CHAR_LAYER1_DB_ID] = 0;
    sCharacters[playerid][E_CHAR_LAYER2_DB_ID] = 0;
    sCharacters[playerid][E_CHAR_LAYER1_SLOT] = INVALID_STORAGE_SLOT;
    sCharacters[playerid][E_CHAR_LAYER2_SLOT] = INVALID_STORAGE_SLOT;
    sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID] = 0;
    sCharacters[playerid][E_CHAR_INVENTORY_PENDING_LOADS] = 0;

    sCharacters[playerid][E_CHAR_ORG_ID] = 0;
    sCharacters[playerid][E_CHAR_ORG_RANK_ID] = 0;
    sCharacters[playerid][E_CHAR_BANK_ACC_DB_ID] = 0;
    sCharacters[playerid][E_CHAR_BANK_IBAN][0] = EOS;
    sCharacters[playerid][E_CHAR_BANK_BALANCE_USD] = 0;
    sCharacters[playerid][E_CHAR_BANK_FROZEN] = false;
    sCharacters[playerid][E_CHAR_BANK_DEBT_USD] = 0;

    sCharacters[playerid][E_CHAR_POS_X] = 1742.90;
    sCharacters[playerid][E_CHAR_POS_Y] = -1862.40;
    sCharacters[playerid][E_CHAR_POS_Z] = 13.57;
    sCharacters[playerid][E_CHAR_POS_A] = 0.0;
    sCharacters[playerid][E_CHAR_INTERIOR] = 0;
    sCharacters[playerid][E_CHAR_VW] = 0;
    sCharacters[playerid][E_CHAR_WIZARD_CUSTOM_SKIN] = 0;
    sCharacters[playerid][E_CHAR_WIZARD_STEP] = 0;
    sCharacters[playerid][E_CHAR_SPAWN_APPLIED] = false;

    sWizardRoleRowCount[playerid] = 0;
    for (new r = 0; r < MAX_STARTER_ROLES; r++)
    {
        sWizardRoleRowMap[playerid][r] = (r + 1);
    }
}

static stock Internal_GetRaceTitleRu(E_CHAR_RACE:race, output[], len = sizeof(output))
{
    switch (race)
    {
        case CHAR_RACE_CAUCASIAN: format(output, len, "Caucasian");
        case CHAR_RACE_AFRO:      format(output, len, "African American");
        case CHAR_RACE_LATINO:    format(output, len, "Latin American");
        case CHAR_RACE_ASIAN:     format(output, len, "Asian");
        default:                  format(output, len, "Caucasian");
    }
}

static stock Internal_JailTypeToString(E_JAIL_TYPE:jailType, output[], len = sizeof(output))
{
    switch (jailType)
    {
        case JAIL_TYPE_KPZ:              format(output, len, "KPZ");
        case JAIL_TYPE_STATE_PRISON:     format(output, len, "STATE_PRISON");
        case JAIL_TYPE_FEDERAL_SUPERMAX: format(output, len, "FEDERAL_SUPERMAX");
        default:                         format(output, len, "NONE");
    }
}

static stock E_JAIL_TYPE:Internal_ParseJailType(const jailStr[])
{
    if (!strcmp(jailStr, "KPZ", true))              return JAIL_TYPE_KPZ;
    if (!strcmp(jailStr, "STATE_PRISON", true))     return JAIL_TYPE_STATE_PRISON;
    if (!strcmp(jailStr, "FEDERAL_SUPERMAX", true)) return JAIL_TYPE_FEDERAL_SUPERMAX;
    return JAIL_TYPE_NONE;
}

static stock Internal_BuildCharDirtyUpdateQuery(playerid, output[], len = sizeof(output))
{
    output[0] = EOS;
    new const charDbId = sCharacters[playerid][E_CHAR_DB_ID];
    if (charDbId <= 0)
    {
        return 0;
    }

    if (IsPlayerConnected(playerid) && sCharacters[playerid][E_CHAR_LOADED])
    {
        new Float:currX, Float:currY, Float:currZ, Float:currA;
        GetPlayerPos(playerid, currX, currY, currZ);
        GetPlayerFacingAngle(playerid, currA);

        if (currX != 0.0 || currY != 0.0)
        {
            sCharacters[playerid][E_CHAR_POS_X] = currX;
            sCharacters[playerid][E_CHAR_POS_Y] = currY;
            sCharacters[playerid][E_CHAR_POS_Z] = currZ;
            sCharacters[playerid][E_CHAR_POS_A] = currA;
            sCharacters[playerid][E_CHAR_INTERIOR] = GetPlayerInterior(playerid);
            sCharacters[playerid][E_CHAR_VW] = GetPlayerVirtualWorld(playerid);
        }

        new Float:currHp, Float:currArmour;
        GetPlayerHealth(playerid, currHp);
        GetPlayerArmour(playerid, currArmour);
        if (currHp > 0.0)
        {
            sCharacters[playerid][E_CHAR_HP] = currHp;
            sCharacters[playerid][E_CHAR_ARMOUR] = currArmour;
        }
    }

    new jailStr[20];
    Internal_JailTypeToString(sCharacters[playerid][E_CHAR_JAIL_KIND], jailStr);

    new orgSql[16], rankSql[16];
    if (sCharacters[playerid][E_CHAR_ORG_ID] > 0)
        format(orgSql, sizeof(orgSql), "%d", sCharacters[playerid][E_CHAR_ORG_ID]);
    else
        format(orgSql, sizeof(orgSql), "NULL");

    if (sCharacters[playerid][E_CHAR_ORG_RANK_ID] > 0)
        format(rankSql, sizeof(rankSql), "%d", sCharacters[playerid][E_CHAR_ORG_RANK_ID]);
    else
        format(rankSql, sizeof(rankSql), "NULL");

    mysql_format(gMySQL, output, len,
        "UPDATE `characters` SET `level` = %d, `exp_seconds` = %d, `skin_id` = %d, `fighting_style` = %d, `hp` = %.2f, `armour` = %.2f, `hunger` = %.2f, `thirst` = %.2f, `stamina` = %.2f, `stress` = %.2f, `addiction_level` = %.2f, `last_drug_at` = %d, `wanted_level` = %d, `active_play_seconds` = %d, `jail_seconds_left` = %d, `jail_type` = '%e', `weapon_license_banned` = %d, `org_id` = %s, `org_rank_id` = %s, `bank_debt_usd` = %d, `pos_x` = %.3f, `pos_y` = %.3f, `pos_z` = %.3f, `pos_a` = %.3f, `interior` = %d, `virtual_world` = %d WHERE `id` = %d;",
        sCharacters[playerid][E_CHAR_LEVEL],
        sCharacters[playerid][E_CHAR_EXP_SECONDS],
        sCharacters[playerid][E_CHAR_SKIN_ID],
        _:Skills_GetFightingStyle(playerid),
        sCharacters[playerid][E_CHAR_HP],
        sCharacters[playerid][E_CHAR_ARMOUR],
        sCharacters[playerid][E_CHAR_HUNGER],
        sCharacters[playerid][E_CHAR_THIRST],
        sCharacters[playerid][E_CHAR_STAMINA],
        sCharacters[playerid][E_CHAR_STRESS],
        sCharacters[playerid][E_CHAR_ADDICTION],
        sCharacters[playerid][E_CHAR_LAST_DRUG_AT],
        sCharacters[playerid][E_CHAR_WANTED_LEVEL],
        sCharacters[playerid][E_CHAR_ACTIVE_PLAY_SECONDS],
        sCharacters[playerid][E_CHAR_JAIL_SECONDS_LEFT],
        jailStr,
        sCharacters[playerid][E_CHAR_WEAPON_LIC_BANNED] ? 1 : 0,
        orgSql,
        rankSql,
        sCharacters[playerid][E_CHAR_BANK_DEBT_USD],
        sCharacters[playerid][E_CHAR_POS_X],
        sCharacters[playerid][E_CHAR_POS_Y],
        sCharacters[playerid][E_CHAR_POS_Z],
        sCharacters[playerid][E_CHAR_POS_A],
        sCharacters[playerid][E_CHAR_INTERIOR],
        sCharacters[playerid][E_CHAR_VW],
        charDbId);
    return 1;
}

// =============================================================================
//  4. ПОШАГОВЫЙ МАСТЕР СОЗДАНИЯ ПЕРСОНАЖА НА РУССКОМ ЯЗЫКЕ (static stock)
// =============================================================================

static stock Internal_ShowWizardStep1Gender(playerid)
{
    sCharacters[playerid][E_CHAR_WIZARD_STEP] = 1;
    ShowPlayerDialog(
        playerid,
        DIALOG_CHAR_SELECT_GENDER,
        DIALOG_STYLE_LIST,
        "{FFC800}Character Creation (Step 1/4) {FFFFFF}| Gender selection",
        "{88CCFF}1.{FFFFFF} Male\n" \
        "{FF88CC}2.{FFFFFF} Female",
        "Next",
        "Cancel");
}

static stock Internal_ShowWizardStep2Race(playerid)
{
    sCharacters[playerid][E_CHAR_WIZARD_STEP] = 2;
    ShowPlayerDialog(
        playerid,
        DIALOG_CHAR_SELECT_RACE,
        DIALOG_STYLE_LIST,
        "{FFC800}Character Creation (Step 2/4) {FFFFFF}| Ethnic origin",
        "{FFFFFF}1. Caucasian\n" \
        "{FFFFFF}2. African American\n" \
        "{FFFFFF}3. Latin American\n" \
        "{FFFFFF}4. Asian",
        "Next",
        "Back");
}

static stock Internal_ShowWizardStep3Skin(playerid)
{
    sCharacters[playerid][E_CHAR_WIZARD_STEP] = 3;
    new const genderIdx = (sCharacters[playerid][E_CHAR_GENDER_VAL] == CHAR_GENDER_FEMALE) ? 1 : 0;
    new raceIdx = _:sCharacters[playerid][E_CHAR_RACE_VAL] - 1;
    if (raceIdx < 0 || raceIdx > 3)
    {
        raceIdx = 0;
    }

    new body[512];
    format(body, sizeof(body),
        "{FFC800}Automatic canonical image of the selected role{FFFFFF}\n" \
        "Casual clothing set No. 1 (Skin ID %d)\n" \
        "Casual clothing set No. 2 (Skin ID %d)\n" \
        "Casual clothing set No. 3 (Skin ID %d)",
        sCasualSkins[genderIdx][raceIdx][0],
        sCasualSkins[genderIdx][raceIdx][1],
        sCasualSkins[genderIdx][raceIdx][2]);

    ShowPlayerDialog(
        playerid,
        DIALOG_CHAR_SELECT_SKIN,
        DIALOG_STYLE_LIST,
        "{FFC800}Character Creation (Step 3/4) {FFFFFF}| Starting appearance",
        body,
        "Next",
        "Back");
}

static stock Internal_ShowWizardStep4RoleList(playerid)
{
    sCharacters[playerid][E_CHAR_WIZARD_STEP] = 4;

    sWizardRoleRowCount[playerid] = 0;
    for (new r = 1; r <= MAX_STARTER_ROLES; r++)
    {
        if (Roles_IsValidId(r))
        {
            sWizardRoleRowMap[playerid][sWizardRoleRowCount[playerid]++] = r;
        }
    }

    Roles_BuildSelectionTableRu(
        sRoleListDialogBuffer,
        sizeof(sRoleListDialogBuffer));

    ShowPlayerDialog(
        playerid,
        DIALOG_CHAR_SELECT_ROLE_LIST,
        DIALOG_STYLE_TABLIST_HEADERS,
        "{FFC800}Character Creation (Step 4/4) {FFFFFF}| Choose from 25 starting roles",
        sRoleListDialogBuffer,
        "Select",
        "Back");
}

static stock Internal_ShowWizardStep5ConfirmRole(playerid, role_id)
{
    sCharacters[playerid][E_CHAR_WIZARD_STEP] = 5;
    sCharacters[playerid][E_CHAR_ROLE_ID] = role_id;

    new roleCard[1280];
    Roles_FormatDetailedCardRu(role_id, roleCard);

    new raceName[32];
    Internal_GetRaceTitleRu(sCharacters[playerid][E_CHAR_RACE_VAL], raceName);

    new const resolvedSkin = (sCharacters[playerid][E_CHAR_WIZARD_CUSTOM_SKIN] > 0)
        ? sCharacters[playerid][E_CHAR_WIZARD_CUSTOM_SKIN]
        : Roles_GetDefaultSkin(role_id, _:sCharacters[playerid][E_CHAR_GENDER_VAL]);

    new fullDialog[1792];
    format(fullDialog, sizeof(fullDialog),
        "{FFFFFF}Character name: {FFC800}%s{FFFFFF} | Gender: %s | Origin: %s\n" \
        "Fixed starting level: {88CCFF}1 level {FFFFFF} | Age according to the formula (17 + Level): {88CCFF}18 years {FFFFFF} | Skin ID: {88CCFF}%d{FFFFFF}\n" \
        "--------------------------------------------------------------------------------\n" \
        "%s\n" \
        "{AFAFAF}Confirm the choice of role for character creation and spawn in the game world.{FFFFFF}",
        sCharacters[playerid][E_CHAR_RP_NAME],
        (sCharacters[playerid][E_CHAR_GENDER_VAL] == CHAR_GENDER_FEMALE) ? ("Female") : ("Male"),
        raceName,
        resolvedSkin,
        roleCard);

    ShowPlayerDialog(
        playerid,
        DIALOG_CHAR_CONFIRM_ROLE,
        DIALOG_STYLE_MSGBOX,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Confirmation of biography and starting role",
        fullDialog,
        "Start game",
        "To the list");
}

// =============================================================================
//  5. СОЗДАНИЕ И ЗАГРУЗКА ПЕРСОНАЖА, ПРИМЕНЕНИЕ РОЛИ И СПАВН
// =============================================================================

static stock Internal_CalculateLayerLimitsForRole(
    role_id,
    &layer1MaxWeightG,
    &layer1MaxVolumeMl,
    &layer2MaxWeightG,
    &layer2MaxVolumeMl)
{
    layer1MaxWeightG = DEFAULT_PLAYER_LAYER1_WEIGHT_G + Roles_GetWeightBonusGrams(role_id);
    if (layer1MaxWeightG < 10000)
    {
        layer1MaxWeightG = 10000;
    }
    layer1MaxVolumeMl = DEFAULT_PLAYER_LAYER1_VOLUME_ML;

    if (Roles_HasPerk(role_id, PERK_DOUBLE_LAYER2))
    {
        layer2MaxWeightG = DEFAULT_PLAYER_LAYER2_WEIGHT_G * 2;
        layer2MaxVolumeMl = DEFAULT_PLAYER_LAYER2_VOLUME_ML * 2;
    }
    else
    {
        layer2MaxWeightG = DEFAULT_PLAYER_LAYER2_WEIGHT_G;
        layer2MaxVolumeMl = DEFAULT_PLAYER_LAYER2_VOLUME_ML;
    }
}

static stock Internal_FinalizeCharacterCreation(playerid)
{
    new const roleId = sCharacters[playerid][E_CHAR_ROLE_ID];
    new const genderInt = _:sCharacters[playerid][E_CHAR_GENDER_VAL];

    // 1. Фиксация автоматических параметров по разделу 10 GDD
    sCharacters[playerid][E_CHAR_LEVEL] = 1;
    sCharacters[playerid][E_CHAR_EXP_SECONDS] = 0;
    sCharacters[playerid][E_CHAR_CITIZENSHIP] = Roles_GetCitizenship(roleId);

    if (sCharacters[playerid][E_CHAR_CITIZENSHIP] == CITIZENSHIP_CITIZEN)
    {
        Utils_GenerateSSN(sCharacters[playerid][E_CHAR_SSN], SSN_STRING_LENGTH);
    }
    else
    {
        sCharacters[playerid][E_CHAR_SSN][0] = EOS;
    }

    if (sCharacters[playerid][E_CHAR_WIZARD_CUSTOM_SKIN] > 0)
    {
        sCharacters[playerid][E_CHAR_SKIN_ID] = sCharacters[playerid][E_CHAR_WIZARD_CUSTOM_SKIN];
    }
    else
    {
        sCharacters[playerid][E_CHAR_SKIN_ID] = Roles_GetDefaultSkin(roleId, genderInt);
    }

    sCharacters[playerid][E_CHAR_HP] = Roles_GetStartHp(roleId);
    sCharacters[playerid][E_CHAR_ARMOUR] = Roles_GetStartArmour(roleId);
    sCharacters[playerid][E_CHAR_HUNGER] = 100.0;
    sCharacters[playerid][E_CHAR_THIRST] = 100.0;
    sCharacters[playerid][E_CHAR_STAMINA] = 100.0;
    sCharacters[playerid][E_CHAR_STRESS] = 0.0;
    sCharacters[playerid][E_CHAR_ADDICTION] = Roles_GetStartAddiction(roleId);
    sCharacters[playerid][E_CHAR_LAST_DRUG_AT] = (sCharacters[playerid][E_CHAR_ADDICTION] > 0.0) ? gettime() : 0;

    sCharacters[playerid][E_CHAR_WANTED_LEVEL] = Roles_GetStartWanted(roleId);
    sCharacters[playerid][E_CHAR_ACTIVE_PLAY_SECONDS] = 0;
    sCharacters[playerid][E_CHAR_JAIL_SECONDS_LEFT] = 0;
    sCharacters[playerid][E_CHAR_JAIL_KIND] = JAIL_TYPE_NONE;
    sCharacters[playerid][E_CHAR_WEAPON_LIC_BANNED] = Roles_HasPerk(roleId, PERK_NO_WEAPON_LIC);
    sCharacters[playerid][E_CHAR_IS_CK_DEAD] = false;
    sCharacters[playerid][E_CHAR_BANK_DEBT_USD] = Roles_GetStartDebtUsd(roleId);

    new Float:spawnX, Float:spawnY, Float:spawnZ, Float:spawnA;
    new spawnInt = 0, spawnVw = 0;
    Roles_GetSpawnPos(roleId, spawnX, spawnY, spawnZ, spawnA, spawnInt, spawnVw);

    sCharacters[playerid][E_CHAR_POS_X] = spawnX;
    sCharacters[playerid][E_CHAR_POS_Y] = spawnY;
    sCharacters[playerid][E_CHAR_POS_Z] = spawnZ;
    sCharacters[playerid][E_CHAR_POS_A] = spawnA;
    sCharacters[playerid][E_CHAR_INTERIOR] = spawnInt;
    sCharacters[playerid][E_CHAR_VW] = spawnVw;

    // 2. Создание двух персональных хранилищ (Слой 1 и Слой 2)
    new layer1MaxW, layer1MaxV, layer2MaxW, layer2MaxV;
    Internal_CalculateLayerLimitsForRole(roleId, layer1MaxW, layer1MaxV, layer2MaxW, layer2MaxV);

    new const layer1Slot = Storage_Create(
        STORAGE_PLAYER_LAYER1,
        Account_GetId(playerid),
        layer1MaxW,
        layer1MaxV);

    new const layer2Slot = Storage_Create(
        STORAGE_PLAYER_LAYER2,
        Account_GetId(playerid),
        layer2MaxW,
        layer2MaxV);

    sCharacters[playerid][E_CHAR_LAYER1_SLOT] = layer1Slot;
    sCharacters[playerid][E_CHAR_LAYER2_SLOT] = layer2Slot;
    sCharacters[playerid][E_CHAR_LAYER1_DB_ID] = Storage_GetDbId(layer1Slot);
    sCharacters[playerid][E_CHAR_LAYER2_DB_ID] = Storage_GetDbId(layer2Slot);

    // 3. Создание банковского счета (если Гражданин США и нет религиозного запрета Сектанта)
    if (sCharacters[playerid][E_CHAR_CITIZENSHIP] == CITIZENSHIP_CITIZEN &&
        !Roles_HasPerk(roleId, PERK_FIRE_RESIST_50))
    {
        Utils_GenerateIBAN(sCharacters[playerid][E_CHAR_BANK_IBAN], IBAN_STRING_LENGTH);
        sCharacters[playerid][E_CHAR_BANK_BALANCE_USD] = Roles_GetStartBankUsd(roleId);
        sCharacters[playerid][E_CHAR_BANK_FROZEN] = false;
        sCharacters[playerid][E_CHAR_BANK_ACC_DB_ID] = ++sSyntheticBankAccDbIdSeq;
    }
    else
    {
        sCharacters[playerid][E_CHAR_BANK_ACC_DB_ID] = 0;
        sCharacters[playerid][E_CHAR_BANK_IBAN][0] = EOS;
        sCharacters[playerid][E_CHAR_BANK_BALANCE_USD] = 0;
    }

    // 4. Применение шаблона роли: матрица навыков, паспорт, карта, одежда, кэш и снаряжение
    Roles_ApplyTemplate(
        playerid,
        roleId,
        layer1Slot,
        layer2Slot,
        sCharacters[playerid][E_CHAR_SSN],
        sCharacters[playerid][E_CHAR_BANK_ACC_DB_ID],
        sCharacters[playerid][E_CHAR_SKIN_ID]);

    // 5. Немедленная привязка идентификатора сессии и сохранение нового персонажа в БД в единой связке
    sCharacters[playerid][E_CHAR_WIZARD_STEP] = 0;
    sCharacters[playerid][E_CHAR_DB_ID] = ++sSyntheticCharDbIdSeq;
    Account_BindSessionCharId(playerid, sCharacters[playerid][E_CHAR_DB_ID]);
    Skills_BindCharacterId(playerid, sCharacters[playerid][E_CHAR_DB_ID]);

    if (DB_IsConnected())
    {
        new ssnSql[32];
        if (sCharacters[playerid][E_CHAR_SSN][0] != EOS)
        {
            mysql_format(gMySQL, ssnSql, sizeof(ssnSql), "'%e'", sCharacters[playerid][E_CHAR_SSN]);
        }
        else
        {
            format(ssnSql, sizeof(ssnSql), "NULL");
        }

        mysql_format(gMySQL, sCharSqlBuffer, sizeof(sCharSqlBuffer),
            "INSERT INTO `characters` (`account_id`, `rp_name`, `gender`, `race`, `role_id`, `level`, `exp_seconds`, `citizenship`, `ssn`, `skin_id`, `fighting_style`, `hp`, `armour`, `hunger`, `thirst`, `stamina`, `stress`, `addiction_level`, `last_drug_at`, `wanted_level`, `weapon_license_banned`, `layer1_storage_id`, `layer2_storage_id`, `bank_debt_usd`, `pos_x`, `pos_y`, `pos_z`, `pos_a`, `interior`, `virtual_world`) VALUES (%d, '%e', %d, %d, %d, 1, 0, '%e', %s, %d, %d, %.2f, %.2f, 100.0, 100.0, 100.0, 0.0, %.2f, %d, %d, %d, %d, %d, %d, %.3f, %.3f, %.3f, %.3f, %d, %d);",
            Account_GetId(playerid),
            sCharacters[playerid][E_CHAR_RP_NAME],
            _:sCharacters[playerid][E_CHAR_GENDER_VAL],
            _:sCharacters[playerid][E_CHAR_RACE_VAL],
            roleId,
            (sCharacters[playerid][E_CHAR_CITIZENSHIP] == CITIZENSHIP_CITIZEN) ? ("CITIZEN") : ("IMMIGRANT"),
            ssnSql,
            sCharacters[playerid][E_CHAR_SKIN_ID],
            _:Skills_GetFightingStyle(playerid),
            sCharacters[playerid][E_CHAR_HP],
            sCharacters[playerid][E_CHAR_ARMOUR],
            sCharacters[playerid][E_CHAR_ADDICTION],
            sCharacters[playerid][E_CHAR_LAST_DRUG_AT],
            sCharacters[playerid][E_CHAR_WANTED_LEVEL],
            sCharacters[playerid][E_CHAR_WEAPON_LIC_BANNED] ? 1 : 0,
            sCharacters[playerid][E_CHAR_LAYER1_DB_ID],
            sCharacters[playerid][E_CHAR_LAYER2_DB_ID],
            sCharacters[playerid][E_CHAR_BANK_DEBT_USD],
            spawnX,
            spawnY,
            spawnZ,
            spawnA,
            spawnInt,
            spawnVw);

        mysql_tquery(gMySQL, sCharSqlBuffer, "OnCharacterCreatedInDb", "dd",
            playerid, Config_GetPlayerSessionToken(playerid));
    }

    sCharacters[playerid][E_CHAR_LOADED] = true;
    Character_SpawnPlayerInWorld(playerid, true);
}

// =============================================================================
//  6. АСИНХРОННЫЕ КОЛБЕКИ ЗАГРУЗКИ И СОЗДАНИЯ ПЕРСОНАЖА (forward / public)
// =============================================================================

public OnLobbyReshowCharacterWizard(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !IsPlayerConnected(playerid))
    {
        return 0;
    }
    if (sCharacters[playerid][E_CHAR_LOADED] || !Account_IsLogged(playerid))
    {
        return 0;
    }

    switch (sCharacters[playerid][E_CHAR_WIZARD_STEP])
    {
        case 2: Internal_ShowWizardStep2Race(playerid);
        case 3: Internal_ShowWizardStep3Skin(playerid);
        case 4: Internal_ShowWizardStep4RoleList(playerid);
        case 5: Internal_ShowWizardStep5ConfirmRole(playerid, sCharacters[playerid][E_CHAR_ROLE_ID]);
        default: Internal_ShowWizardStep1Gender(playerid);
    }
    return 1;
}

public OnAccountAuthenticated(playerid, bool:isNewRegistration)
{
    Internal_ResetCharacterSlot(playerid);

    sCharacters[playerid][E_CHAR_ACCOUNT_ID] = Account_GetId(playerid);
    Account_GetUsername(playerid, sCharacters[playerid][E_CHAR_RP_NAME], MAX_PLAYER_NAME + 1);

    if (DB_IsConnected() && sCharacters[playerid][E_CHAR_ACCOUNT_ID] > 0 && !isNewRegistration)
    {
        mysql_format(gMySQL, sCharSqlBuffer, sizeof(sCharSqlBuffer),
            "SELECT `id`, `gender`, `race`, `role_id`, `level`, `exp_seconds`, `citizenship`, IFNULL(`ssn`, '') AS `ssn`, `skin_id`, `fighting_style`, `hp`, `armour`, `hunger`, `thirst`, `stamina`, `stress`, `addiction_level`, `last_drug_at`, `wanted_level`, `active_play_seconds`, `jail_seconds_left`, `jail_type`, `weapon_license_banned`, `layer1_storage_id`, `layer2_storage_id`, IFNULL(`org_id`, 0) AS `org_id`, IFNULL(`org_rank_id`, 0) AS `org_rank_id`, `bank_debt_usd`, `pos_x`, `pos_y`, `pos_z`, `pos_a`, `interior`, `virtual_world` FROM `characters` WHERE `account_id` = %d AND `is_ck_dead` = 0 ORDER BY `id` DESC LIMIT 1;",
            sCharacters[playerid][E_CHAR_ACCOUNT_ID]);

        mysql_tquery(gMySQL, sCharSqlBuffer, "OnCharacterQueryLoaded", "dd",
            playerid, Config_GetPlayerSessionToken(playerid));
    }
    else
    {
        SendClientMessage(playerid, COLOR_UI_INFO,
            "Choose your character's gender, origin, appearance, and one of 25 starting roles.");
        Internal_ShowWizardStep1Gender(playerid);
    }
    return 1;
}

forward OnCharacterQueryLoaded(playerid, sessionToken);
public OnCharacterQueryLoaded(playerid, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 1;
    }

    new rows = 0;
    cache_get_row_count(rows);

    if (rows <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_INFO,
            "You don't have an active character yet. Complete the short hero creation questionnaire.");
        Internal_ShowWizardStep1Gender(playerid);
        return 1;
    }

    new charDbId = 0;
    new genderInt = 1, raceInt = 1, roleId = 5, level = 1, expSeconds = 0;
    new skinId = 26, fightStyleInt = 4;
    new wantedLevel = 0, activePlaySec = 0, jailSecLeft = 0, wepLicBannedInt = 0;
    new layer1DbId = 0, layer2DbId = 0, orgId = 0, orgRankId = 0, bankDebtUsd = 0;
    new interior = 0, vw = 0, lastDrugAt = 0;
    new citizenshipStr[16], jailTypeStr[24];

    cache_get_value_name_int(0, "id", charDbId);
    cache_get_value_name_int(0, "gender", genderInt);
    cache_get_value_name_int(0, "race", raceInt);
    cache_get_value_name_int(0, "role_id", roleId);
    cache_get_value_name_int(0, "level", level);
    cache_get_value_name_int(0, "exp_seconds", expSeconds);
    cache_get_value_name(0, "citizenship", citizenshipStr, sizeof(citizenshipStr));
    cache_get_value_name(0, "ssn", sCharacters[playerid][E_CHAR_SSN], SSN_STRING_LENGTH);
    cache_get_value_name_int(0, "skin_id", skinId);
    cache_get_value_name_int(0, "fighting_style", fightStyleInt);

    cache_get_value_name_float(0, "hp", sCharacters[playerid][E_CHAR_HP]);
    cache_get_value_name_float(0, "armour", sCharacters[playerid][E_CHAR_ARMOUR]);
    cache_get_value_name_float(0, "hunger", sCharacters[playerid][E_CHAR_HUNGER]);
    cache_get_value_name_float(0, "thirst", sCharacters[playerid][E_CHAR_THIRST]);
    cache_get_value_name_float(0, "stamina", sCharacters[playerid][E_CHAR_STAMINA]);
    cache_get_value_name_float(0, "stress", sCharacters[playerid][E_CHAR_STRESS]);
    cache_get_value_name_float(0, "addiction_level", sCharacters[playerid][E_CHAR_ADDICTION]);
    cache_get_value_name_int(0, "last_drug_at", lastDrugAt);

    cache_get_value_name_int(0, "wanted_level", wantedLevel);
    cache_get_value_name_int(0, "active_play_seconds", activePlaySec);
    cache_get_value_name_int(0, "jail_seconds_left", jailSecLeft);
    cache_get_value_name(0, "jail_type", jailTypeStr, sizeof(jailTypeStr));
    cache_get_value_name_int(0, "weapon_license_banned", wepLicBannedInt);

    cache_get_value_name_int(0, "layer1_storage_id", layer1DbId);
    cache_get_value_name_int(0, "layer2_storage_id", layer2DbId);
    cache_get_value_name_int(0, "org_id", orgId);
    cache_get_value_name_int(0, "org_rank_id", orgRankId);
    cache_get_value_name_int(0, "bank_debt_usd", bankDebtUsd);

    cache_get_value_name_float(0, "pos_x", sCharacters[playerid][E_CHAR_POS_X]);
    cache_get_value_name_float(0, "pos_y", sCharacters[playerid][E_CHAR_POS_Y]);
    cache_get_value_name_float(0, "pos_z", sCharacters[playerid][E_CHAR_POS_Z]);
    cache_get_value_name_float(0, "pos_a", sCharacters[playerid][E_CHAR_POS_A]);
    cache_get_value_name_int(0, "interior", interior);
    cache_get_value_name_int(0, "virtual_world", vw);

    sCharacters[playerid][E_CHAR_DB_ID] = charDbId;
    sCharacters[playerid][E_CHAR_GENDER_VAL] = E_CHAR_GENDER:genderInt;
    sCharacters[playerid][E_CHAR_RACE_VAL] = E_CHAR_RACE:raceInt;
    sCharacters[playerid][E_CHAR_ROLE_ID] = Roles_IsValidId(roleId) ? roleId : 5;
    sCharacters[playerid][E_CHAR_LEVEL] = (level >= 1) ? level : 1;
    sCharacters[playerid][E_CHAR_EXP_SECONDS] = expSeconds;
    sCharacters[playerid][E_CHAR_CITIZENSHIP] = (!strcmp(citizenshipStr, "IMMIGRANT", true))
        ? CITIZENSHIP_IMMIGRANT
        : CITIZENSHIP_CITIZEN;
    sCharacters[playerid][E_CHAR_SKIN_ID] = skinId;
    sCharacters[playerid][E_CHAR_LAST_DRUG_AT] = lastDrugAt;
    sCharacters[playerid][E_CHAR_WANTED_LEVEL] = wantedLevel;
    sCharacters[playerid][E_CHAR_ACTIVE_PLAY_SECONDS] = activePlaySec;
    sCharacters[playerid][E_CHAR_JAIL_SECONDS_LEFT] = jailSecLeft;
    sCharacters[playerid][E_CHAR_JAIL_KIND] = Internal_ParseJailType(jailTypeStr);
    sCharacters[playerid][E_CHAR_WEAPON_LIC_BANNED] = (wepLicBannedInt != 0);
    sCharacters[playerid][E_CHAR_LAYER1_DB_ID] = layer1DbId;
    sCharacters[playerid][E_CHAR_LAYER2_DB_ID] = layer2DbId;
    sCharacters[playerid][E_CHAR_ORG_ID] = orgId;
    sCharacters[playerid][E_CHAR_ORG_RANK_ID] = orgRankId;
    sCharacters[playerid][E_CHAR_BANK_DEBT_USD] = bankDebtUsd;
    sCharacters[playerid][E_CHAR_INTERIOR] = interior;
    sCharacters[playerid][E_CHAR_VW] = vw;

    // 1. Привязка сессии и применение потолков навыков от роли
    Account_BindSessionCharId(playerid, charDbId);
    Roles_ApplySkillsOnly(playerid, sCharacters[playerid][E_CHAR_ROLE_ID]);
    Skills_SetFightingStyle(playerid, FIGHT_STYLE:fightStyleInt, true);

    // 2. Асинхронная загрузка навыков из character_skills
    Skills_LoadFromDB(playerid, charDbId);

    // 3. Загрузка Слоя 1 и Слоя 2 инвентаря в пул хранилищ
    new layer1MaxW, layer1MaxV, layer2MaxW, layer2MaxV;
    Internal_CalculateLayerLimitsForRole(
        sCharacters[playerid][E_CHAR_ROLE_ID],
        layer1MaxW, layer1MaxV, layer2MaxW, layer2MaxV);

    sCharacters[playerid][E_CHAR_INVENTORY_PENDING_LOADS] = 0;

    if (layer1DbId > 0)
    {
        new const loadedLayer1 = Storage_Load(
            layer1DbId,
            STORAGE_PLAYER_LAYER1,
            charDbId,
            layer1MaxW,
            layer1MaxV);
        if (loadedLayer1 != INVALID_STORAGE_SLOT)
        {
            sCharacters[playerid][E_CHAR_LAYER1_SLOT] = loadedLayer1;
            if (!Storage_AreItemsReady(loadedLayer1))
            {
                sCharacters[playerid][E_CHAR_INVENTORY_PENDING_LOADS]++;
            }
        }
    }
    if (sCharacters[playerid][E_CHAR_LAYER1_SLOT] == INVALID_STORAGE_SLOT)
    {
        sCharacters[playerid][E_CHAR_LAYER1_SLOT] = Storage_Create(
            STORAGE_PLAYER_LAYER1, charDbId, layer1MaxW, layer1MaxV, false, 0, 0.0, 0.0, 0.0, 0, 0, 0, layer1DbId);
    }

    if (layer2DbId > 0)
    {
        new const loadedLayer2 = Storage_Load(
            layer2DbId,
            STORAGE_PLAYER_LAYER2,
            charDbId,
            layer2MaxW,
            layer2MaxV);
        if (loadedLayer2 != INVALID_STORAGE_SLOT)
        {
            sCharacters[playerid][E_CHAR_LAYER2_SLOT] = loadedLayer2;
            if (!Storage_AreItemsReady(loadedLayer2))
            {
                sCharacters[playerid][E_CHAR_INVENTORY_PENDING_LOADS]++;
            }
        }
    }
    if (sCharacters[playerid][E_CHAR_LAYER2_SLOT] == INVALID_STORAGE_SLOT)
    {
        sCharacters[playerid][E_CHAR_LAYER2_SLOT] = Storage_Create(
            STORAGE_PLAYER_LAYER2, charDbId, layer2MaxW, layer2MaxV, false, 0, 0.0, 0.0, 0.0, 0, 0, 0, layer2DbId);
    }

    // 4. Загрузка банковского счета персонажа
    mysql_format(gMySQL, sCharSqlBuffer, sizeof(sCharSqlBuffer),
        "SELECT `id`, `iban`, `balance_usd`, `is_frozen` FROM `bank_accounts` WHERE `owner_char_id` = %d ORDER BY `id` ASC LIMIT 1;",
        charDbId);
    mysql_tquery(gMySQL, sCharSqlBuffer, "OnCharacterBankLoaded", "dd",
        playerid, sessionToken);

    sCharacters[playerid][E_CHAR_LOADED] = true;
    Character_SyncInventorySkin(playerid);
    Character_SpawnPlayerInWorld(playerid, false);
    return 1;
}

forward OnCharacterBankLoaded(playerid, sessionToken);
public OnCharacterBankLoaded(playerid, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 1;
    }

    new rows = 0;
    cache_get_row_count(rows);
    if (rows <= 0)
    {
        return 1;
    }

    new bankAccId = 0, balanceUsd = 0, isFrozenInt = 0;
    cache_get_value_name_int(0, "id", bankAccId);
    cache_get_value_name(0, "iban", sCharacters[playerid][E_CHAR_BANK_IBAN], IBAN_STRING_LENGTH);
    cache_get_value_name_int(0, "balance_usd", balanceUsd);
    cache_get_value_name_int(0, "is_frozen", isFrozenInt);

    sCharacters[playerid][E_CHAR_BANK_ACC_DB_ID] = bankAccId;
    sCharacters[playerid][E_CHAR_BANK_BALANCE_USD] = balanceUsd;
    sCharacters[playerid][E_CHAR_BANK_FROZEN] = (isFrozenInt != 0);
    return 1;
}

forward OnCharacterCreatedInDb(playerid, sessionToken);
public OnCharacterCreatedInDb(playerid, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 1;
    }

    new const insertedCharId = cache_insert_id();
    sCharacters[playerid][E_CHAR_DB_ID] = (insertedCharId > 0) ? insertedCharId : (++sSyntheticCharDbIdSeq);

    Account_BindSessionCharId(playerid, sCharacters[playerid][E_CHAR_DB_ID]);
    Skills_BindCharacterId(playerid, sCharacters[playerid][E_CHAR_DB_ID]);

    // 1. Создание строки 41 навыка в character_skills
    Skills_InsertInitialRow(playerid, sCharacters[playerid][E_CHAR_DB_ID]);

    // 2. Создание строки медицинских зон тела в character_injuries
    if (DB_IsConnected())
    {
        mysql_format(gMySQL, sCharSqlBuffer, sizeof(sCharSqlBuffer),
            "INSERT INTO `character_injuries` (`char_id`) VALUES (%d) ON DUPLICATE KEY UPDATE `head_hp` = 100;",
            sCharacters[playerid][E_CHAR_DB_ID]);
        mysql_tquery(gMySQL, sCharSqlBuffer);

        // 3. Обновление owner_id у хранилищ Слоя 1 и Слоя 2 на реальный ID персонажа
        if (sCharacters[playerid][E_CHAR_LAYER1_DB_ID] > 0 && sCharacters[playerid][E_CHAR_LAYER2_DB_ID] > 0)
        {
            mysql_format(gMySQL, sCharSqlBuffer, sizeof(sCharSqlBuffer),
                "UPDATE `storages` SET `owner_id` = %d WHERE `id` IN (%d, %d);",
                sCharacters[playerid][E_CHAR_DB_ID],
                sCharacters[playerid][E_CHAR_LAYER1_DB_ID],
                sCharacters[playerid][E_CHAR_LAYER2_DB_ID]);
            mysql_tquery(gMySQL, sCharSqlBuffer);
        }

        // 4. Запись банковского счета в bank_accounts (если открыт)
        if (sCharacters[playerid][E_CHAR_BANK_IBAN][0] != EOS)
        {
            mysql_format(gMySQL, sCharSqlBuffer, sizeof(sCharSqlBuffer),
                "INSERT INTO `bank_accounts` (`iban`, `owner_char_id`, `balance_usd`, `is_frozen`) VALUES ('%e', %d, %d, 0);",
                sCharacters[playerid][E_CHAR_BANK_IBAN],
                sCharacters[playerid][E_CHAR_DB_ID],
                sCharacters[playerid][E_CHAR_BANK_BALANCE_USD]);
            mysql_tquery(gMySQL, sCharSqlBuffer);
        }
    }

    new roleName[48], details[192], ssnText[20];
    Roles_GetNameRu(sCharacters[playerid][E_CHAR_ROLE_ID], roleName);
    if (sCharacters[playerid][E_CHAR_SSN][0] != EOS)
        format(ssnText, sizeof(ssnText), "%s", sCharacters[playerid][E_CHAR_SSN]);
    else
        format(ssnText, sizeof(ssnText), "IMMIGRANT");

    format(details, sizeof(details),
        "Character %s created (ID: %d, Role #%d: %s, SSN: %s)",
        sCharacters[playerid][E_CHAR_RP_NAME],
        sCharacters[playerid][E_CHAR_DB_ID],
        sCharacters[playerid][E_CHAR_ROLE_ID],
        roleName,
        ssnText);

    Audit_Log(
        sCharacters[playerid][E_CHAR_DB_ID],
        "CHAR_CREATE",
        sCharacters[playerid][E_CHAR_RP_NAME],
        roleName,
        0,
        sCharacters[playerid][E_CHAR_ROLE_ID],
        details);
    return 1;
}

// =============================================================================
//  7. ПУБЛИЧНЫЙ API МОДУЛЯ ПЕРСОНАЖА (Character_*)
// =============================================================================

stock bool:Character_IsLoaded(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return false;
    }
    return sCharacters[playerid][E_CHAR_LOADED];
}

stock bool:Character_IsAlive(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !IsPlayerConnected(playerid))
    {
        return false;
    }

    new const PLAYER_STATE:playerState = GetPlayerState(playerid);
    return (playerState != PLAYER_STATE_NONE &&
            playerState != PLAYER_STATE_WASTED &&
            playerState != PLAYER_STATE_SPECTATING);
}

stock Character_GetId(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    return sCharacters[playerid][E_CHAR_DB_ID];
}

stock Character_GetRoleId(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    return sCharacters[playerid][E_CHAR_ROLE_ID];
}

stock Character_GetLevel(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 1;
    }
    return sCharacters[playerid][E_CHAR_LEVEL];
}

stock Character_GetAge(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 18;
    }
    return CHAR_AgeFromLevel(sCharacters[playerid][E_CHAR_LEVEL]);
}

stock E_CITIZENSHIP_TYPE:Character_GetCitizenship(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return CITIZENSHIP_CITIZEN;
    }
    return sCharacters[playerid][E_CHAR_CITIZENSHIP];
}

stock Character_GetSSN(playerid, output[], len = sizeof(output))
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        output[0] = EOS;
        return 0;
    }
    format(output, len, "%s", sCharacters[playerid][E_CHAR_SSN]);
    return 1;
}

stock Character_GetRpName(playerid, output[], len = sizeof(output))
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        output[0] = EOS;
        return 0;
    }
    format(output, len, "%s", sCharacters[playerid][E_CHAR_RP_NAME]);
    return 1;
}

stock Character_GetLayer1Slot(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return INVALID_STORAGE_SLOT;
    }
    return sCharacters[playerid][E_CHAR_LAYER1_SLOT];
}

stock Character_GetLayer2Slot(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return INVALID_STORAGE_SLOT;
    }
    return sCharacters[playerid][E_CHAR_LAYER2_SLOT];
}

stock Character_GetUnderwearSkin(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return SKIN_UNDERWEAR_MALE;
    }
    return (sCharacters[playerid][E_CHAR_GENDER_VAL] == CHAR_GENDER_FEMALE)
        ? SKIN_UNDERWEAR_FEMALE
        : SKIN_UNDERWEAR_MALE;
}

static stock bool:Internal_IsValidOutfitSkin(skinId)
{
    return (skinId >= 1 && skinId <= 311 && skinId != 74);
}

// Проверяет, входит ли хранилище (включая вложенные сумки) во владение игрока.
static stock bool:Internal_DoesStorageBelongToPlayer(playerid, storage_slot)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Storage_IsValidSlot(storage_slot))
    {
        return false;
    }

    new currentSlot = storage_slot;
    new hops = 0;
    while (Storage_IsValidSlot(currentSlot) && hops <= MAX_NESTING_DEPTH + 1)
    {
        if (currentSlot == sCharacters[playerid][E_CHAR_LAYER1_SLOT] ||
            currentSlot == sCharacters[playerid][E_CHAR_LAYER2_SLOT])
        {
            return true;
        }
        currentSlot = Storage_GetParentSlot(currentSlot);
        hops++;
    }
    return false;
}

stock Character_FindPlayerByStorageSlot(storage_slot)
{
    if (!Storage_IsValidSlot(storage_slot))
    {
        return INVALID_PLAYER_ID;
    }

    foreach (new p : Player)
    {
        if (sCharacters[p][E_CHAR_LOADED] &&
            Internal_DoesStorageBelongToPlayer(p, storage_slot))
        {
            return p;
        }
    }
    return INVALID_PLAYER_ID;
}

// Единая точка применения скина: RAM, модель игрока и сохранение в characters.skin_id.
static stock Internal_ApplyPlayerSkin(playerid, skinId, bool:persist)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }

    if (!Internal_IsValidOutfitSkin(skinId))
    {
        skinId = Character_GetUnderwearSkin(playerid);
    }

    new const bool:skinChanged = (sCharacters[playerid][E_CHAR_SKIN_ID] != skinId);
    sCharacters[playerid][E_CHAR_SKIN_ID] = skinId;

    // SetPlayerSkin пересоздает модель и сбрасывает клиентскую интерполяцию.
    // Вызываем его только при фактической смене скина; OnPlayerSpawn отдельно
    // применяет актуальную модель после респавна.
    if (IsPlayerConnected(playerid) && skinChanged)
    {
        SetPlayerSkin(playerid, skinId);
    }

    if (persist && skinChanged &&
        DB_IsConnected() &&
        sCharacters[playerid][E_CHAR_DB_ID] > 0)
    {
        mysql_format(gMySQL, sCharSqlBuffer, sizeof(sCharSqlBuffer),
            "UPDATE `characters` SET `skin_id` = %d WHERE `id` = %d;",
            skinId,
            sCharacters[playerid][E_CHAR_DB_ID]);
        mysql_tquery(gMySQL, sCharSqlBuffer);
    }
    return skinId;
}

// Рекурсивный поиск надетого комплекта одежды во всех хранилищах игрока.
static stock Internal_ScanEquippedOutfits(
    playerid,
    storage_slot,
    depth,
    &selectedSlot,
    &selectedDbId)
{
    if (!Storage_IsValidSlot(storage_slot) || depth > (MAX_NESTING_DEPTH + 1))
    {
        return 0;
    }

    new itemSlot = Storage_GetFirstItemSlot(storage_slot);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        new const defId = Storage_GetItemDefId(itemSlot);

        if (defId == ITEM_ID_CLOTHING_OUTFIT &&
            Storage_GetItemMetaInt2(itemSlot) == CLOTHING_STATE_EQUIPPED)
        {
            new const itemDbId = Storage_GetItemDbId(itemSlot);
            new const bool:isTracked = (
                sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID] > 0 &&
                itemDbId == sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID]);

            if (isTracked)
            {
                // Отслеживаемый предмет имеет приоритет над любыми дублями.
                selectedSlot = itemSlot;
                selectedDbId = itemDbId;
            }
            else if (selectedSlot == INVALID_STORAGE_ITEM_SLOT)
            {
                selectedSlot = itemSlot;
                selectedDbId = itemDbId;
            }
        }

        new const nestedSlot = Storage_GetItemNestedSlot(itemSlot);
        if (Storage_IsValidSlot(nestedSlot))
        {
            Internal_ScanEquippedOutfits(playerid, nestedSlot, depth + 1, selectedSlot, selectedDbId);
        }

        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }
    return 1;
}

// Сбрасывает флаг «надето» у всех комплектов, кроме выбранного (repair duplicates).
static stock Internal_ClearDuplicateOutfits(storage_slot, keep_item_slot, depth)
{
    if (!Storage_IsValidSlot(storage_slot) || depth > (MAX_NESTING_DEPTH + 1))
    {
        return 0;
    }

    new itemSlot = Storage_GetFirstItemSlot(storage_slot);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        if (Storage_GetItemDefId(itemSlot) == ITEM_ID_CLOTHING_OUTFIT &&
            Storage_GetItemMetaInt2(itemSlot) == CLOTHING_STATE_EQUIPPED &&
            itemSlot != keep_item_slot)
        {
            Storage_SetItemMetaInt2(itemSlot, CLOTHING_STATE_BAG);
        }

        new const nestedSlot = Storage_GetItemNestedSlot(itemSlot);
        if (Storage_IsValidSlot(nestedSlot))
        {
            Internal_ClearDuplicateOutfits(nestedSlot, keep_item_slot, depth + 1);
        }

        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }
    return 1;
}

static stock Internal_ClearAllEquippedOutfits(playerid)
{
    Internal_ClearDuplicateOutfits(
        sCharacters[playerid][E_CHAR_LAYER1_SLOT],
        INVALID_STORAGE_ITEM_SLOT,
        0);
    Internal_ClearDuplicateOutfits(
        sCharacters[playerid][E_CHAR_LAYER2_SLOT],
        INVALID_STORAGE_ITEM_SLOT,
        0);
    return 1;
}

stock bool:Character_IsOutfitItemEquipped(playerid, item_slot)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS ||
        !Storage_IsValidItemSlot(item_slot) ||
        Storage_GetItemDefId(item_slot) != ITEM_ID_CLOTHING_OUTFIT)
    {
        return false;
    }

    if (sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID] > 0)
    {
        return (Storage_GetItemDbId(item_slot) == sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID]);
    }
    return (Storage_GetItemMetaInt2(item_slot) == CLOTHING_STATE_EQUIPPED);
}

stock Character_UndressToUnderwear(playerid, bool:notify = true)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }

    Internal_ClearAllEquippedOutfits(playerid);
    sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID] = 0;
    Internal_ApplyPlayerSkin(playerid, Character_GetUnderwearSkin(playerid), true);

    if (notify && IsPlayerConnected(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Wardrobe]: The worn set of clothes is removed. You were left in your underwear.");
    }
    return 1;
}

// Перенаправление скина при уходе надетого предмета из владения игрока.
forward OnStorageLostEquippedClothing(src_slot, item_slot, dst_slot);
public OnStorageLostEquippedClothing(src_slot, item_slot, dst_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }

    new const itemDbId = Storage_GetItemDbId(item_slot);
    new srcPlayer = INVALID_PLAYER_ID;

    // 1. Надежный поиск по ID предмета (работает даже для вложенных сумок).
    foreach (new p : Player)
    {
        if (sCharacters[p][E_CHAR_LOADED] &&
            sCharacters[p][E_CHAR_EQUIPPED_OUTFIT_DB_ID] > 0 &&
            sCharacters[p][E_CHAR_EQUIPPED_OUTFIT_DB_ID] == itemDbId)
        {
            srcPlayer = p;
            break;
        }
    }

    // 2. Резервный поиск по хранилищу-источнику.
    if (srcPlayer == INVALID_PLAYER_ID)
    {
        srcPlayer = Character_FindPlayerByStorageSlot(src_slot);
    }

    if (srcPlayer == INVALID_PLAYER_ID)
    {
        return 1;
    }

    // Перемещение между собственными слоями/сумками не снимает одежду.
    new const dstPlayer = Character_FindPlayerByStorageSlot(dst_slot);
    if (dstPlayer == srcPlayer && Storage_IsValidSlot(dst_slot))
    {
        return 0;
    }

    sCharacters[srcPlayer][E_CHAR_EQUIPPED_OUTFIT_DB_ID] = 0;
    Internal_ApplyPlayerSkin(srcPlayer, Character_GetUnderwearSkin(srcPlayer), true);

    if (IsPlayerConnected(srcPlayer))
    {
        SendClientMessage(srcPlayer, COLOR_UI_WARNING,
            "[Wardrobe]: A set of clothes has left your inventory. You were left in your underwear.");
    }
    return 1;
}

// Пересчитывает надетую одежду по фактическому содержимому инвентаря.
// Пока слои не загружены из БД (pending > 0), скин из БД не перезаписывается.
stock Character_SyncInventorySkin(playerid, bool:force = false)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS ||
        !IsPlayerConnected(playerid) ||
        !sCharacters[playerid][E_CHAR_LOADED])
    {
        return 0;
    }

    if (!force && sCharacters[playerid][E_CHAR_INVENTORY_PENDING_LOADS] > 0)
    {
        return sCharacters[playerid][E_CHAR_SKIN_ID];
    }

    // Если отслеживаемый комплект уехал вместе с сумкой/контейнером в чужое владение,
    // снимаем с него флаг «Надето», чтобы новый владелец не надел одежду автоматически.
    if (sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID] > 0)
    {
        new const trackedSlot = Storage_FindItemSlotByDbId(
            sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID]);
        if (trackedSlot != INVALID_STORAGE_ITEM_SLOT &&
            !Internal_DoesStorageBelongToPlayer(
                playerid,
                Storage_GetItemStorageSlot(trackedSlot)))
        {
            if (Storage_GetItemDefId(trackedSlot) == ITEM_ID_CLOTHING_OUTFIT &&
                Storage_GetItemMetaInt2(trackedSlot) == CLOTHING_STATE_EQUIPPED)
            {
                Storage_SetItemMetaInt2(trackedSlot, CLOTHING_STATE_BAG);
            }
            sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID] = 0;
        }
    }

    new selectedSlot = INVALID_STORAGE_ITEM_SLOT;
    new selectedDbId = 0;

    Internal_ScanEquippedOutfits(
        playerid,
        sCharacters[playerid][E_CHAR_LAYER1_SLOT],
        0,
        selectedSlot,
        selectedDbId);
    Internal_ScanEquippedOutfits(
        playerid,
        sCharacters[playerid][E_CHAR_LAYER2_SLOT],
        0,
        selectedSlot,
        selectedDbId);

    if (selectedSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        // Надетым считается ровно один комплект; остальные дубли переводятся в сумку.
        Internal_ClearDuplicateOutfits(
            sCharacters[playerid][E_CHAR_LAYER1_SLOT],
            selectedSlot,
            0);
        Internal_ClearDuplicateOutfits(
            sCharacters[playerid][E_CHAR_LAYER2_SLOT],
            selectedSlot,
            0);

        sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID] = selectedDbId;

        new skinId = Storage_GetItemMetaInt1(selectedSlot);
        if (!Internal_IsValidOutfitSkin(skinId))
        {
            skinId = Character_GetUnderwearSkin(playerid);
        }
        return Internal_ApplyPlayerSkin(playerid, skinId, true);
    }

    // Нет надетой одежды: базовый скин нижнего белья по полу персонажа.
    sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID] = 0;
    return Internal_ApplyPlayerSkin(playerid, Character_GetUnderwearSkin(playerid), true);
}

// Надеть / снять выбранный комплект одежды (вызывается из /inv -> «Использовать»).
stock Character_WearOutfitItem(playerid, item_slot)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS ||
        !IsPlayerConnected(playerid) ||
        !sCharacters[playerid][E_CHAR_LOADED])
    {
        return 0;
    }

    if (!Storage_IsValidItemSlot(item_slot) ||
        Storage_GetItemDefId(item_slot) != ITEM_ID_CLOTHING_OUTFIT)
    {
        return 0;
    }

    if (!Internal_DoesStorageBelongToPlayer(playerid, Storage_GetItemStorageSlot(item_slot)))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Wardrobe]: This set of clothes is not in your inventory.");
        return 0;
    }

    new const itemDbId = Storage_GetItemDbId(item_slot);

    if (Character_IsOutfitItemEquipped(playerid, item_slot))
    {
        Storage_SetItemMetaInt2(item_slot, CLOTHING_STATE_BAG);
        sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID] = 0;
        Internal_ApplyPlayerSkin(playerid, Character_GetUnderwearSkin(playerid), true);
        SendClientMessage(playerid, COLOR_UI_INFO,
            "[Wardrobe]: You took off your set of clothes and put them in your bag.");
        return 1;
    }

    // Активным может быть только один комплект: снимаем все остальные.
    Internal_ClearAllEquippedOutfits(playerid);

    Storage_SetItemMetaInt2(item_slot, CLOTHING_STATE_EQUIPPED);
    sCharacters[playerid][E_CHAR_EQUIPPED_OUTFIT_DB_ID] = itemDbId;

    new skinId = Storage_GetItemMetaInt1(item_slot);
    if (!Internal_IsValidOutfitSkin(skinId))
    {
        skinId = Character_GetUnderwearSkin(playerid);
    }
    Internal_ApplyPlayerSkin(playerid, skinId, true);

    SendClientMessage(playerid, COLOR_UI_SUCCESS,
        "[Wardrobe]: You are wearing the selected set of clothes. It is marked with the status “Equipped”.");
    return 1;
}

// Уведомление от модуля хранилищ о завершении загрузки конкретного слоя.
forward OnCharacterInventoryStorageReady(storage_slot);
public OnCharacterInventoryStorageReady(storage_slot)
{
    new const playerid = Character_FindPlayerByStorageSlot(storage_slot);
    if (playerid == INVALID_PLAYER_ID)
    {
        return 0;
    }

    if (sCharacters[playerid][E_CHAR_INVENTORY_PENDING_LOADS] > 0)
    {
        sCharacters[playerid][E_CHAR_INVENTORY_PENDING_LOADS]--;
    }

    if (sCharacters[playerid][E_CHAR_INVENTORY_PENDING_LOADS] == 0)
    {
        Character_SyncInventorySkin(playerid, true);
        Character_SyncLayer1Weapons(playerid);
        CallLocalFunction("OnPlayerHudNeedsUpdate", "d", playerid);
    }
    return 1;
}


// Формула максимальной грузоподъемности из раздела 4.1 ROADMAP:
// W_max = 25000 + (Skill_MUSCLE * 35) + Delta_role
stock Character_GetMaxCarryWeightGrams(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return DEFAULT_PLAYER_LAYER1_WEIGHT_G;
    }

    new const muscleSkill = Skills_Get(playerid, SKILL_MUSCLE);
    new const roleDeltaG = Roles_GetWeightBonusGrams(sCharacters[playerid][E_CHAR_ROLE_ID]);
    new maxWeightG = DEFAULT_PLAYER_LAYER1_WEIGHT_G + (muscleSkill * 35) + roleDeltaG;

    if (maxWeightG < 10000)
    {
        maxWeightG = 10000;
    }
    return maxWeightG;
}

// Подсчет физического баланса наличных USD в Слое 1 и Слое 2
stock Character_GetPhysicalCashUsd(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }

    new totalCashUsd = 0;
    new slots[2];
    slots[0] = sCharacters[playerid][E_CHAR_LAYER1_SLOT];
    slots[1] = sCharacters[playerid][E_CHAR_LAYER2_SLOT];

    for (new s = 0; s < 2; s++)
    {
        if (!Storage_IsValidSlot(slots[s]))
        {
            continue;
        }
        new currItem = Storage_GetFirstItemSlot(slots[s]);
        while (currItem != INVALID_STORAGE_ITEM_SLOT)
        {
            if (Storage_GetItemDefId(currItem) == ITEM_ID_CASH_BUNDLE &&
                Storage_GetItemMetaInt2(currItem) == CURRENCY_USD)
            {
                totalCashUsd += Storage_GetItemAmount(currItem);
            }
            currItem = Storage_GetNextItemSlot(currItem);
        }
    }
    return totalCashUsd;
}

// Выдача физических наличных USD в Слой 1 персонажа (пачки банкнот ITEM_ID_CASH_BUNDLE)
stock bool:Character_AddPhysicalCashUsd(playerid, amount_usd, cash_flag = CASH_FLAG_CLEAN)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || amount_usd <= 0 || !Character_IsLoaded(playerid))
    {
        return false;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        return false;
    }

    new const cashWeightG = Item_CalculateInstanceWeight(ITEM_ID_CASH_BUNDLE, amount_usd);
    new const cashVolumeMl = Item_CalculateInstanceVolume(ITEM_ID_CASH_BUNDLE, amount_usd);
    if ((Storage_GetCurrentWeight(layer1Slot) + cashWeightG) > Storage_GetMaxWeight(layer1Slot) ||
        (Storage_GetCurrentVolume(layer1Slot) + cashVolumeMl) > Storage_GetMaxVolume(layer1Slot))
    {
        return false;
    }

    new remaining = amount_usd;
    new added = 0;
    while (remaining > 0)
    {
        new const chunk = (remaining > 10000) ? 10000 : remaining;
        new outItemSlot = INVALID_STORAGE_ITEM_SLOT;
        new const E_STORAGE_RESULT:result = Storage_AddItem(
            layer1Slot,
            ITEM_ID_CASH_BUNDLE,
            chunk,
            0,
            100.0,
            cash_flag,
            CURRENCY_USD,
            "",
            outItemSlot
        );

        if (result != STORAGE_RES_OK)
        {
            if (added > 0)
            {
                Storage_RemoveItemInTree(layer1Slot, ITEM_ID_CASH_BUNDLE, added);
            }
            return false;
        }

        added += chunk;
        remaining -= chunk;
    }
    return true;
}

// Списание указанной суммы физических наличных USD из Слоя 1 и Слоя 2 персонажа
stock bool:Character_RemovePhysicalCashUsd(playerid, amount_usd)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || amount_usd <= 0 || !Character_IsLoaded(playerid))
    {
        return false;
    }
    if (Character_GetPhysicalCashUsd(playerid) < amount_usd)
    {
        return false;
    }

    new remaining = amount_usd;
    new storageSlots[2];
    storageSlots[0] = Character_GetLayer1Slot(playerid);
    storageSlots[1] = Character_GetLayer2Slot(playerid);

    for (new stIdx = 0; stIdx < 2 && remaining > 0; stIdx++)
    {
        new const storageSlot = storageSlots[stIdx];
        if (!Storage_IsValidSlot(storageSlot))
        {
            continue;
        }

        new itemSlot = Storage_GetFirstItemSlot(storageSlot);
        while (itemSlot != INVALID_STORAGE_ITEM_SLOT && remaining > 0)
        {
            new const nextItemSlot = Storage_GetNextItemSlot(itemSlot);
            if (Storage_GetItemDefId(itemSlot) == ITEM_ID_CASH_BUNDLE)
            {
                new const stackAmount = Storage_GetItemAmount(itemSlot);
                new const takeAmount = (stackAmount > remaining) ? remaining : stackAmount;
                if (Storage_RemoveItem(storageSlot, itemSlot, takeAmount))
                {
                    remaining -= takeAmount;
                }
            }
            itemSlot = nextItemSlot;
        }
    }

    return (remaining == 0);
}

stock Character_GetOrgId(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }
    return sCharacters[playerid][E_CHAR_ORG_ID];
}

stock Character_GetOrgRankId(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }
    return sCharacters[playerid][E_CHAR_ORG_RANK_ID];
}

stock Character_GetBankBalanceUsd(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    return sCharacters[playerid][E_CHAR_BANK_BALANCE_USD];
}

stock Character_GetBankDebtUsd(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    return sCharacters[playerid][E_CHAR_BANK_DEBT_USD];
}

// Проверка наличия действующего банковского счета (IBAN открыт и не пуст)
stock bool:Character_HasBankAccount(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return false;
    }
    return (sCharacters[playerid][E_CHAR_BANK_IBAN][0] != EOS);
}

// Копирование IBAN персонажа в буфер вызывающего модуля
stock Character_GetBankIban(playerid, output[], len = sizeof(output))
{
    if (output[0] != EOS)
    {
        output[0] = EOS;
    }
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }
    format(output, len, "%s", sCharacters[playerid][E_CHAR_BANK_IBAN]);
    return 1;
}

// Идентификатор записи банковского счета в таблице bank_accounts
stock Character_GetBankAccountDbId(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }
    return sCharacters[playerid][E_CHAR_BANK_ACC_DB_ID];
}

// Состояние заморозки банковского счета по решению суда или ФБР
stock bool:Character_IsBankFrozen(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return false;
    }
    return sCharacters[playerid][E_CHAR_BANK_FROZEN];
}

// Регистрация нового банковского счета в оперативной памяти персонажа
stock Character_SetBankAccount(playerid, const iban[], balance, bool:frozen, account_db_id)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }

    format(sCharacters[playerid][E_CHAR_BANK_IBAN], IBAN_STRING_LENGTH, "%s", iban);
    sCharacters[playerid][E_CHAR_BANK_BALANCE_USD] = balance;
    sCharacters[playerid][E_CHAR_BANK_FROZEN] = frozen;
    sCharacters[playerid][E_CHAR_BANK_ACC_DB_ID] = account_db_id;
    return 1;
}

// Обновление безналичного баланса в RAM (запись в bank_accounts выполняет mod_banking)
stock Character_SetBankBalanceUsd(playerid, amount)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }
    if (amount < 0)
    {
        amount = 0;
    }
    sCharacters[playerid][E_CHAR_BANK_BALANCE_USD] = amount;
    return 1;
}

// Изменение флага заморозки счета в RAM (синхронизация с bank_accounts в mod_banking)
stock Character_SetBankFrozen(playerid, bool:frozen)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }
    sCharacters[playerid][E_CHAR_BANK_FROZEN] = frozen;
    return 1;
}

// Назначение или снятие членства в организации (немедленная запись в characters)
stock Character_SetOrgMembership(playerid, org_id, rank_id)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }

    if (org_id < 0) org_id = 0;
    if (rank_id < 0) rank_id = 0;
    if (org_id == 0)
    {
        rank_id = 0;
    }

    sCharacters[playerid][E_CHAR_ORG_ID] = org_id;
    sCharacters[playerid][E_CHAR_ORG_RANK_ID] = rank_id;

    if (DB_IsConnected() && sCharacters[playerid][E_CHAR_DB_ID] > 0)
    {
        new query[192];
        if (org_id > 0 && rank_id > 0)
        {
            mysql_format(gMySQL, query, sizeof(query),
                "UPDATE `characters` SET `org_id` = %d, `org_rank_id` = %d WHERE `id` = %d;",
                org_id, rank_id, sCharacters[playerid][E_CHAR_DB_ID]);
        }
        else
        {
            mysql_format(gMySQL, query, sizeof(query),
                "UPDATE `characters` SET `org_id` = NULL, `org_rank_id` = NULL WHERE `id` = %d;",
                sCharacters[playerid][E_CHAR_DB_ID]);
        }
        // pquery сохраняет порядок после INSERT organizations/organization_ranks
        mysql_pquery(gMySQL, query);
    }
    return 1;
}

// Остаток срока заключения в секундах активного онлайна
stock Character_GetJailSecondsLeft(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }
    return sCharacters[playerid][E_CHAR_JAIL_SECONDS_LEFT];
}

// Текущий тип исправительного учреждения
stock E_JAIL_TYPE:Character_GetJailType(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return JAIL_TYPE_NONE;
    }
    return sCharacters[playerid][E_CHAR_JAIL_KIND];
}

// Установка срока и учреждения заключения с немедленной синхронизацией в БД
stock Character_SetJailState(playerid, seconds, E_JAIL_TYPE:jail_type, bool:persist = true)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }
    if (seconds < 0)
    {
        seconds = 0;
    }
    if (seconds == 0)
    {
        jail_type = JAIL_TYPE_NONE;
    }

    sCharacters[playerid][E_CHAR_JAIL_SECONDS_LEFT] = seconds;
    sCharacters[playerid][E_CHAR_JAIL_KIND] = jail_type;

    if (persist && DB_IsConnected() && sCharacters[playerid][E_CHAR_DB_ID] > 0)
    {
        new jailStr[24];
        new query[192];
        Internal_JailTypeToString(jail_type, jailStr, sizeof(jailStr));
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `characters` SET `jail_seconds_left` = %d, `jail_type` = '%e' WHERE `id` = %d;",
            seconds, jailStr, sCharacters[playerid][E_CHAR_DB_ID]);
        mysql_tquery(gMySQL, query);
    }
    return 1;
}

// Счетчик активного (не AFK) времени для честного Warrant Decay
stock Character_GetActivePlaySeconds(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }
    return sCharacters[playerid][E_CHAR_ACTIVE_PLAY_SECONDS];
}

stock Character_AddActivePlaySeconds(playerid, delta)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid) || delta <= 0)
    {
        return 0;
    }
    sCharacters[playerid][E_CHAR_ACTIVE_PLAY_SECONDS] += delta;
    return sCharacters[playerid][E_CHAR_ACTIVE_PLAY_SECONDS];
}

stock Character_ResetActivePlaySeconds(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }
    sCharacters[playerid][E_CHAR_ACTIVE_PLAY_SECONDS] = 0;
    return 1;
}

stock Character_GetWantedLevel(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    return sCharacters[playerid][E_CHAR_WANTED_LEVEL];
}

stock Character_SetWantedLevel(playerid, wanted_level)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    if (wanted_level < 0) wanted_level = 0;
    if (wanted_level > 100) wanted_level = 100;

    sCharacters[playerid][E_CHAR_WANTED_LEVEL] = wanted_level;

    // Визуальные звезды GTA SA (0..6) пропорционально 100-уровневой шкале
    if (IsPlayerConnected(playerid))
    {
        new stars = 0;
        if (wanted_level >= 51)      stars = 6;
        else if (wanted_level >= 26) stars = 5;
        else if (wanted_level >= 15) stars = 4;
        else if (wanted_level >= 6)  stars = 3;
        else if (wanted_level >= 3)  stars = 2;
        else if (wanted_level >= 1)  stars = 1;
        SetPlayerWantedLevel(playerid, stars);
    }

    Character_MarkDirty(playerid);
    return 1;
}

stock Character_SetCkDead(playerid, bool:ck_dead)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }

    sCharacters[playerid][E_CHAR_IS_CK_DEAD] = ck_dead;
    if (DB_IsConnected() && sCharacters[playerid][E_CHAR_DB_ID] > 0)
    {
        new query[160];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `characters` SET `is_ck_dead` = %d WHERE `id` = %d;",
            ck_dead ? 1 : 0,
            sCharacters[playerid][E_CHAR_DB_ID]);
        mysql_tquery(gMySQL, query);
    }
    return 1;
}

stock Float:Character_GetHunger(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 100.0;
    return sCharacters[playerid][E_CHAR_HUNGER];
}

stock Character_SetHunger(playerid, Float:value)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (value < 0.0) value = 0.0;
    if (value > 100.0) value = 100.0;
    sCharacters[playerid][E_CHAR_HUNGER] = value;
    Character_MarkDirty(playerid);
    return 1;
}

stock Float:Character_GetThirst(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 100.0;
    return sCharacters[playerid][E_CHAR_THIRST];
}

stock Character_SetThirst(playerid, Float:value)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (value < 0.0) value = 0.0;
    if (value > 100.0) value = 100.0;
    sCharacters[playerid][E_CHAR_THIRST] = value;
    Character_MarkDirty(playerid);
    return 1;
}

stock Float:Character_GetStress(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0.0;
    return sCharacters[playerid][E_CHAR_STRESS];
}

stock Character_SetStress(playerid, Float:value)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (value < 0.0) value = 0.0;
    if (value > 100.0) value = 100.0;
    sCharacters[playerid][E_CHAR_STRESS] = value;
    Character_MarkDirty(playerid);
    return 1;
}

stock Float:Character_GetAddiction(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0.0;
    return sCharacters[playerid][E_CHAR_ADDICTION];
}

stock Character_SetAddiction(playerid, Float:value)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (value < 0.0) value = 0.0;
    if (value > 100.0) value = 100.0;
    sCharacters[playerid][E_CHAR_ADDICTION] = value;
    Character_MarkDirty(playerid);
    return 1;
}

stock Character_MarkDirty(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sCharacters[playerid][E_CHAR_LOADED])
    {
        return 0;
    }

    sCharacters[playerid][E_CHAR_IS_DIRTY] = true;
    if (DB_IsConnected() && sCharacters[playerid][E_CHAR_DB_ID] > 0)
    {
        new query[1024];
        if (Internal_BuildCharDirtyUpdateQuery(playerid, query, sizeof(query)))
        {
            DB_EnqueueDirtyQuery(DIRTY_ENTITY_CHARACTER, sCharacters[playerid][E_CHAR_DB_ID], query);
        }
    }
    return 1;
}

// =============================================================================
//  АДМИНИСТРАТИВНЫЕ СЕТТЕРЫ (Фаза 10): HP, броня, стамина, уровень, EXP, долг
// =============================================================================

stock Float:Character_GetHP(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 100.0;
    return sCharacters[playerid][E_CHAR_HP];
}

stock Character_SetHP(playerid, Float:value)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sCharacters[playerid][E_CHAR_LOADED]) return 0;
    if (value < 0.0) value = 0.0;
    if (value > 100.0) value = 100.0;
    sCharacters[playerid][E_CHAR_HP] = value;
    if (IsPlayerConnected(playerid))
    {
        SetPlayerHealth(playerid, value);
    }
    Character_MarkDirty(playerid);
    return 1;
}

stock Float:Character_GetArmour(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0.0;
    return sCharacters[playerid][E_CHAR_ARMOUR];
}

stock Character_SetArmour(playerid, Float:value)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sCharacters[playerid][E_CHAR_LOADED]) return 0;
    if (value < 0.0) value = 0.0;
    if (value > 100.0) value = 100.0;
    sCharacters[playerid][E_CHAR_ARMOUR] = value;
    if (IsPlayerConnected(playerid))
    {
        SetPlayerArmour(playerid, value);
    }
    Character_MarkDirty(playerid);
    return 1;
}

stock Float:Character_GetStamina(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 100.0;
    return sCharacters[playerid][E_CHAR_STAMINA];
}

stock Character_SetStamina(playerid, Float:value)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sCharacters[playerid][E_CHAR_LOADED]) return 0;
    if (value < 0.0) value = 0.0;
    if (value > 100.0) value = 100.0;
    sCharacters[playerid][E_CHAR_STAMINA] = value;
    Character_MarkDirty(playerid);
    return 1;
}

stock Character_GetExpSeconds(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return sCharacters[playerid][E_CHAR_EXP_SECONDS];
}

stock Character_SetExpSeconds(playerid, seconds)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sCharacters[playerid][E_CHAR_LOADED]) return 0;
    if (seconds < 0) seconds = 0;
    sCharacters[playerid][E_CHAR_EXP_SECONDS] = seconds;
    Character_MarkDirty(playerid);
    return 1;
}

stock Character_SetLevel(playerid, level)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sCharacters[playerid][E_CHAR_LOADED]) return 0;
    if (level < 1) level = 1;
    if (level > 1000) level = 1000;
    sCharacters[playerid][E_CHAR_LEVEL] = level;
    if (IsPlayerConnected(playerid))
    {
        SetPlayerScore(playerid, level);
    }
    Character_MarkDirty(playerid);
    return 1;
}

stock Character_SetBankDebtUsd(playerid, amount)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sCharacters[playerid][E_CHAR_LOADED]) return 0;
    if (amount < 0) amount = 0;
    sCharacters[playerid][E_CHAR_BANK_DEBT_USD] = amount;
    Character_MarkDirty(playerid);
    return 1;
}

stock Character_SetCitizenship(playerid, E_CITIZENSHIP_TYPE:citizenship)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sCharacters[playerid][E_CHAR_LOADED]) return 0;
    if (citizenship != CITIZENSHIP_CITIZEN && citizenship != CITIZENSHIP_IMMIGRANT) return 0;
    sCharacters[playerid][E_CHAR_CITIZENSHIP] = citizenship;
    if (DB_IsConnected() && sCharacters[playerid][E_CHAR_DB_ID] > 0)
    {
        new query[192];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `characters` SET `citizenship` = '%e' WHERE `id` = %d;",
            (citizenship == CITIZENSHIP_CITIZEN) ? ("CITIZEN") : ("IMMIGRANT"),
            sCharacters[playerid][E_CHAR_DB_ID]);
        mysql_tquery(gMySQL, query);
    }
    return 1;
}

stock Character_SetSSN(playerid, const ssn[])
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sCharacters[playerid][E_CHAR_LOADED]) return 0;
    format(sCharacters[playerid][E_CHAR_SSN], SSN_STRING_LENGTH, "%s", ssn);
    if (DB_IsConnected() && sCharacters[playerid][E_CHAR_DB_ID] > 0)
    {
        new query[192];
        if (ssn[0] == EOS)
        {
            mysql_format(gMySQL, query, sizeof(query),
                "UPDATE `characters` SET `ssn` = NULL WHERE `id` = %d;",
                sCharacters[playerid][E_CHAR_DB_ID]);
        }
        else
        {
            mysql_format(gMySQL, query, sizeof(query),
                "UPDATE `characters` SET `ssn` = '%e' WHERE `id` = %d;",
                ssn, sCharacters[playerid][E_CHAR_DB_ID]);
        }
        mysql_tquery(gMySQL, query);
    }
    return 1;
}

stock Character_SetWeaponLicenseBanned(playerid, bool:banned)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sCharacters[playerid][E_CHAR_LOADED]) return 0;
    sCharacters[playerid][E_CHAR_WEAPON_LIC_BANNED] = banned;
    Character_MarkDirty(playerid);
    return 1;
}

stock bool:Character_IsWeaponLicenseBanned(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return sCharacters[playerid][E_CHAR_WEAPON_LIC_BANNED];
}

stock Character_AdminSetSkin(playerid, skinId)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sCharacters[playerid][E_CHAR_LOADED]) return 0;
    return Internal_ApplyPlayerSkin(playerid, skinId, true);
}

// Синхронизация оружия в руках игрока с предметами в Слое 1 (и бронежилета)
stock Character_SyncLayer1Weapons(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !IsPlayerConnected(playerid))
    {
        return 0;
    }

    new const layer1Slot = sCharacters[playerid][E_CHAR_LAYER1_SLOT];
    if (!Storage_IsValidSlot(layer1Slot))
    {
        return 0;
    }

    ResetPlayerWeapons(playerid);

    new currItem = Storage_GetFirstItemSlot(layer1Slot);
    while (currItem != INVALID_STORAGE_ITEM_SLOT)
    {
        new const defId = Storage_GetItemDefId(currItem);
        new const gtaWeaponId = Item_GetGtaWeaponId(defId);

        if (gtaWeaponId > 0)
        {
            if (Item_GetCategory(defId) == ITEM_CAT_FIREARM)
            {
                // Пустой ствол остается физическим предметом в инвентаре ("0 M4"),
                // но не выдается клиенту до объединения боезапаса (/unload, /combine).
                new ammo = Storage_GetItemAmmo(currItem);
                if (ammo <= 0)
                {
                    currItem = Storage_GetNextItemSlot(currItem);
                    continue;
                }
                GivePlayerWeapon(playerid, WEAPON:gtaWeaponId, ammo);
            }
            else
            {
                new ammo = Storage_GetItemAmount(currItem);
                if (ammo <= 0) ammo = 1;
                GivePlayerWeapon(playerid, WEAPON:gtaWeaponId, ammo);
            }
        }
        else if (defId == 40 && sCharacters[playerid][E_CHAR_ARMOUR] < 10.0)
        {
            // Тяжелый бронежилет в Слое 1
            new const Float:armorDurability = Storage_GetItemDurability(currItem);
            sCharacters[playerid][E_CHAR_ARMOUR] = armorDurability;
            SetPlayerArmour(playerid, armorDurability);
        }

        currItem = Storage_GetNextItemSlot(currItem);
    }
    return 1;
}

timer Character_FinalizeSpawnTimer[120](playerid, expectedToken)
{
    if (!Config_ValidatePlayerToken(playerid, expectedToken) || !sCharacters[playerid][E_CHAR_LOADED])
    {
        return;
    }

    if (!sCharacters[playerid][E_CHAR_SPAWN_APPLIED])
    {
        SetSpawnInfo(
            playerid,
            NO_TEAM,
            sCharacters[playerid][E_CHAR_SKIN_ID],
            sCharacters[playerid][E_CHAR_POS_X],
            sCharacters[playerid][E_CHAR_POS_Y],
            sCharacters[playerid][E_CHAR_POS_Z],
            sCharacters[playerid][E_CHAR_POS_A]);
        SpawnPlayer(playerid);
    }
    // Камера уже выставлена в OnPlayerSpawn. Повторный SetCameraBehindPlayer
    // через 120 мс сбрасывал клиентскую интерполяцию поворота.
}

// Пятисекундный сторож загрузки инвентаря: не позволяет навсегда остаться
// в нижнем белье и без оружия, если асинхронный ответ MySQL задержался.
timer Character_InventorySyncTimer[500](playerid, expectedToken, attempt)
{
    if (!Config_ValidatePlayerToken(playerid, expectedToken) || !sCharacters[playerid][E_CHAR_LOADED])
    {
        return;
    }

    if (sCharacters[playerid][E_CHAR_INVENTORY_PENDING_LOADS] <= 0)
    {
        Character_SyncInventorySkin(playerid, true);
        Character_SyncLayer1Weapons(playerid);
        return;
    }

    if (attempt >= 10)
    {
        sCharacters[playerid][E_CHAR_INVENTORY_PENDING_LOADS] = 0;
        Character_SyncInventorySkin(playerid, true);
        Character_SyncLayer1Weapons(playerid);
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Inventory]: Loading took too long. Check your connection and sign in again.");
        return;
    }

    defer Character_InventorySyncTimer(playerid, expectedToken, attempt + 1);
}

stock Character_SpawnPlayerInWorld(playerid, bool:isFirstCreation = false)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !IsPlayerConnected(playerid))
    {
        return 0;
    }

    sCharacters[playerid][E_CHAR_WIZARD_STEP] = 0;
    sCharacters[playerid][E_CHAR_SPAWN_APPLIED] = false;

    // Если инвентарь еще грузится, остаемся на скине из БД и применим одежду после загрузки.
    Character_SyncInventorySkin(playerid);

    // Обновляем максимальный вес Слоя 1 по текущей формуле мускулатуры и роли
    new const layer1Slot = sCharacters[playerid][E_CHAR_LAYER1_SLOT];
    if (Storage_IsValidSlot(layer1Slot))
    {
        Storage_SetMaxLimits(
            layer1Slot,
            Character_GetMaxCarryWeightGrams(playerid),
            Storage_GetMaxVolume(layer1Slot));
    }

    SetSpawnInfo(
        playerid,
        NO_TEAM,
        sCharacters[playerid][E_CHAR_SKIN_ID],
        sCharacters[playerid][E_CHAR_POS_X],
        sCharacters[playerid][E_CHAR_POS_Y],
        sCharacters[playerid][E_CHAR_POS_Z],
        sCharacters[playerid][E_CHAR_POS_A]);

    if (GetPlayerState(playerid) == PLAYER_STATE_SPECTATING)
    {
        TogglePlayerSpectating(playerid, false);
        defer Character_FinalizeSpawnTimer(playerid, Config_GetPlayerSessionToken(playerid));
    }
    else
    {
        SpawnPlayer(playerid);
        defer Character_FinalizeSpawnTimer(playerid, Config_GetPlayerSessionToken(playerid));
    }

    if (isFirstCreation)
    {
        new roleName[48], cashStr[32], bankStr[32], ssnDisplay[20];
        Roles_GetNameRu(sCharacters[playerid][E_CHAR_ROLE_ID], roleName);
        Utils_FormatMoney(Character_GetPhysicalCashUsd(playerid), cashStr);
        Utils_FormatMoney(sCharacters[playerid][E_CHAR_BANK_BALANCE_USD], bankStr);
        if (sCharacters[playerid][E_CHAR_SSN][0] != EOS)
            format(ssnDisplay, sizeof(ssnDisplay), "%s", sCharacters[playerid][E_CHAR_SSN]);
        else
            format(ssnDisplay, sizeof(ssnDisplay), "Missing");

        new msg[160];
        SendClientMessage(playerid, COLOR_SERVER_GOLD,
            "==========================================================================");
        format(msg, sizeof(msg),
            "Character %s has been created successfully! Role: \"%s\" | Age: %d years (Level %d).",
            sCharacters[playerid][E_CHAR_RP_NAME],
            roleName,
            Character_GetAge(playerid),
            sCharacters[playerid][E_CHAR_LEVEL]);
        SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

        format(msg, sizeof(msg),
            "Status: %s | SSN: %s | Cash: %s | Bank: %s.",
            (sCharacters[playerid][E_CHAR_CITIZENSHIP] == CITIZENSHIP_CITIZEN) ? ("US citizen") : ("Immigrant"),
            ssnDisplay,
            cashStr,
            bankStr);
        SendClientMessage(playerid, COLOR_UI_INFO, msg);
        SendClientMessage(playerid, COLOR_UI_INFO,
            "Use /stats to view your passport and status, /skills for the skills matrix.");
        SendClientMessage(playerid, COLOR_SERVER_GOLD,
            "==========================================================================");
    }
    return 1;
}

stock Character_ShowStatsDialog(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sCharacters[playerid][E_CHAR_LOADED])
    {
        return 0;
    }

    new roleName[48], raceName[32], cashStr[32], bankStr[32], debtStr[32], ssnDisplay[20], ibanDisplay[24];
    Roles_GetNameRu(sCharacters[playerid][E_CHAR_ROLE_ID], roleName);
    Internal_GetRaceTitleRu(sCharacters[playerid][E_CHAR_RACE_VAL], raceName);
    Utils_FormatMoney(Character_GetPhysicalCashUsd(playerid), cashStr);
    Utils_FormatMoney(sCharacters[playerid][E_CHAR_BANK_BALANCE_USD], bankStr);
    Utils_FormatMoney(sCharacters[playerid][E_CHAR_BANK_DEBT_USD], debtStr);

    if (sCharacters[playerid][E_CHAR_SSN][0] != EOS)
        format(ssnDisplay, sizeof(ssnDisplay), "%s", sCharacters[playerid][E_CHAR_SSN]);
    else
        format(ssnDisplay, sizeof(ssnDisplay), "Not assigned");

    if (sCharacters[playerid][E_CHAR_BANK_IBAN][0] != EOS)
        format(ibanDisplay, sizeof(ibanDisplay), "%s", sCharacters[playerid][E_CHAR_BANK_IBAN]);
    else
        format(ibanDisplay, sizeof(ibanDisplay), "No account");

    new const layer1Slot = sCharacters[playerid][E_CHAR_LAYER1_SLOT];
    new const layer2Slot = sCharacters[playerid][E_CHAR_LAYER2_SLOT];

    new const l1WeightG = Storage_IsValidSlot(layer1Slot) ? Storage_GetCurrentWeight(layer1Slot) : 0;
    new const l1MaxWeightG = Character_GetMaxCarryWeightGrams(playerid);
    new const l2WeightG = Storage_IsValidSlot(layer2Slot) ? Storage_GetCurrentWeight(layer2Slot) : 0;
    new const l2MaxWeightG = Storage_IsValidSlot(layer2Slot) ? Storage_GetMaxWeight(layer2Slot) : DEFAULT_PLAYER_LAYER2_WEIGHT_G;

    new body[1280];
    format(body, sizeof(body),
        "{FFC800}1. Legal profile and biography:{FFFFFF}\n" \
        "• First and Last Name: {88CCFF}%s{FFFFFF} (Character ID: %d)\n" \
        "• Level in the state: {66CC66}%d level {FFFFFF} (Progress: %d / %d sec.) | Age: {66CC66}%d years {FFFFFF}\n" \
        "• Gender: %s | Origin: %s | Starting role: {FFC800}%s (#%d){FFFFFF}\n" \
        "• Citizenship: %s | SSN: {88CCFF}%s{FFFFFF}\n" \
        "• Wanted level: {FF4444}%d / 100{FFFFFF} (Decreased after: %d sec.)\n\n" \
        "{FFC800}2. Finance and Banking:{FFFFFF}\n" \
        "• Cash in Pockets (USD): {66CC66}%s{FFFFFF}\n" \
        "• Bank account IBAN: {88CCFF}%s{FFFFFF} | Balance: {66CC66}%s{FFFFFF}\n" \
        "• Credit debt: {FFAA00}%s{FFFFFF}\n\n" \
        "{FFC800}3. Physiology and double-layer storage:{FFFFFF}\n" \
        "• Health: %.1f HP | Armor: %.1f%% | Hunger: %.1f%% | Thirst: %.1f%% | Stress: %.1f%%\n" \
        "• Layer 1 (Outer): {88CCFF}%d.%02d / %d.%02d kg{FFFFFF} | Layer 2 (Secret): {88CCFF}%d.%02d / %d.%02d kg{FFFFFF}",
        sCharacters[playerid][E_CHAR_RP_NAME],
        sCharacters[playerid][E_CHAR_DB_ID],
        sCharacters[playerid][E_CHAR_LEVEL],
        sCharacters[playerid][E_CHAR_EXP_SECONDS],
        LEVEL_UP_ACTIVE_SECONDS,
        Character_GetAge(playerid),
        (sCharacters[playerid][E_CHAR_GENDER_VAL] == CHAR_GENDER_FEMALE) ? ("Female") : ("Male"),
        raceName,
        roleName,
        sCharacters[playerid][E_CHAR_ROLE_ID],
        (sCharacters[playerid][E_CHAR_CITIZENSHIP] == CITIZENSHIP_CITIZEN) ? ("US citizen") : ("Immigrant"),
        ssnDisplay,
        sCharacters[playerid][E_CHAR_WANTED_LEVEL],
        WARRANT_DECAY_ACTIVE_SECONDS - sCharacters[playerid][E_CHAR_ACTIVE_PLAY_SECONDS],
        cashStr,
        ibanDisplay,
        bankStr,
        debtStr,
        sCharacters[playerid][E_CHAR_HP],
        sCharacters[playerid][E_CHAR_ARMOUR],
        sCharacters[playerid][E_CHAR_HUNGER],
        sCharacters[playerid][E_CHAR_THIRST],
        sCharacters[playerid][E_CHAR_STRESS],
        GRAMS_TO_KG(l1WeightG), (GRAMS_REMAINDER(l1WeightG) / 10),
        GRAMS_TO_KG(l1MaxWeightG), (GRAMS_REMAINDER(l1MaxWeightG) / 10),
        GRAMS_TO_KG(l2WeightG), (GRAMS_REMAINDER(l2WeightG) / 10),
        GRAMS_TO_KG(l2MaxWeightG), (GRAMS_REMAINDER(l2MaxWeightG) / 10));

    ShowPlayerDialog(
        playerid,
        DIALOG_CHAR_STATS_VIEW,
        DIALOG_STYLE_MSGBOX,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Personal file and character statistics",
        body,
        "Skills",
        "Close");
    return 1;
}

// =============================================================================
//  8. СИСТЕМНЫЕ ХУКИ, ТАЙМЕР ПРОГРЕССИИ И КОМАНДЫ (y_hooks, y_timers, Pawn.CMD)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        Internal_ResetCharacterSlot(i);
    }

    // Самопроверка применения шаблона роли №6 (Боевой Ветеран: 200 M4) и №3 (Уличная Проститутка: удвоенный Слой 2)
    new l1W, l1V, l2W, l2V;
    Internal_CalculateLayerLimitsForRole(3, l1W, l1V, l2W, l2V);
    new const bool:doubleLayer2Ok = (l2W == (DEFAULT_PLAYER_LAYER2_WEIGHT_G * 2));
    new const bool:ageFormulaOk = (CHAR_AgeFromLevel(1) == 18 && CHAR_AgeFromLevel(5) == 22);

    // Самотест выполняется исключительно в RAM: synthetic DB ID = 0 и
    // ram_only = true полностью исключают INSERT в storages/storage_items.
    new const testL1 = Storage_Create(STORAGE_PLAYER_LAYER1, 0, DEFAULT_PLAYER_LAYER1_WEIGHT_G, DEFAULT_PLAYER_LAYER1_VOLUME_ML, false, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, true);
    new const testL2 = Storage_Create(STORAGE_PLAYER_LAYER2, 0, DEFAULT_PLAYER_LAYER2_WEIGHT_G, DEFAULT_PLAYER_LAYER2_VOLUME_ML, false, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, true);
    Roles_ApplyTemplate(0, 6, testL1, testL2, "900-11-2233", 1, 287);
    new const vetM4Skill = Skills_Get(0, SKILL_M4);
    new const vetL1Weight = Storage_GetCurrentWeight(testL1);
    Storage_Unload(testL1);
    Storage_Unload(testL2);
    Skills_ResetDefaults(0);

    printf("%s [Entities/Character] Character module initialized (Age(1)=18: %s | Layer 2 role #3 (%d g): %s | Veteran M4=%d, Weight of Layer 1=%d g).",
        SERVER_LOG_PREFIX,
        ageFormulaOk ? ("OK") : ("ERROR"),
        l2W,
        doubleLayer2Ok ? ("OK") : ("ERROR"),
        vetM4Skill,
        vetL1Weight);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    Internal_ResetCharacterSlot(playerid);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    if (sCharacters[playerid][E_CHAR_LOADED])
    {
        if (DB_IsConnected() && sCharacters[playerid][E_CHAR_DB_ID] > 0)
        {
            if (Internal_BuildCharDirtyUpdateQuery(playerid, sCharSqlBuffer, sizeof(sCharSqlBuffer)))
            {
                mysql_tquery(gMySQL, sCharSqlBuffer);
            }
            Skills_SaveAllAsync(playerid);
        }

        if (Storage_IsValidSlot(sCharacters[playerid][E_CHAR_LAYER1_SLOT]))
        {
            Storage_Unload(sCharacters[playerid][E_CHAR_LAYER1_SLOT]);
        }
        if (Storage_IsValidSlot(sCharacters[playerid][E_CHAR_LAYER2_SLOT]))
        {
            Storage_Unload(sCharacters[playerid][E_CHAR_LAYER2_SLOT]);
        }
    }

    Internal_ResetCharacterSlot(playerid);
    return 1;
}

hook OnPlayerRequestClass(playerid, classid)
{
    #pragma unused classid
    if (sCharacters[playerid][E_CHAR_LOADED])
    {
        Character_SyncInventorySkin(playerid);
        SetSpawnInfo(
            playerid,
            NO_TEAM,
            sCharacters[playerid][E_CHAR_SKIN_ID],
            sCharacters[playerid][E_CHAR_POS_X],
            sCharacters[playerid][E_CHAR_POS_Y],
            sCharacters[playerid][E_CHAR_POS_Z],
            sCharacters[playerid][E_CHAR_POS_A]);
        SpawnPlayer(playerid);
        return 1;
    }
    return 0;
}

hook OnPlayerSpawn(playerid)
{
    if (!sCharacters[playerid][E_CHAR_LOADED])
    {
        TogglePlayerSpectating(playerid, true);
        return 1;
    }

    sCharacters[playerid][E_CHAR_SPAWN_APPLIED] = true;
    if (sCharacters[playerid][E_CHAR_HP] < 10.0)
    {
        sCharacters[playerid][E_CHAR_HP] = 100.0;
    }

    // При каждом респавне применяется актуальный надетый скин, а не стартовый.
    Character_SyncInventorySkin(playerid);
    SetPlayerSkin(playerid, sCharacters[playerid][E_CHAR_SKIN_ID]);
    SetPlayerInterior(playerid, sCharacters[playerid][E_CHAR_INTERIOR]);
    SetPlayerVirtualWorld(playerid, sCharacters[playerid][E_CHAR_VW]);
    Utils_SetPlayerPos(
        playerid,
        sCharacters[playerid][E_CHAR_POS_X],
        sCharacters[playerid][E_CHAR_POS_Y],
        sCharacters[playerid][E_CHAR_POS_Z]);
    SetPlayerFacingAngle(playerid, sCharacters[playerid][E_CHAR_POS_A]);
    SetCameraBehindPlayer(playerid);

    SetPlayerHealth(playerid, sCharacters[playerid][E_CHAR_HP]);
    SetPlayerArmour(playerid, sCharacters[playerid][E_CHAR_ARMOUR]);

    Skills_SyncNative(playerid);
    Character_SyncLayer1Weapons(playerid);
    Character_SetWantedLevel(playerid, sCharacters[playerid][E_CHAR_WANTED_LEVEL]);

    if (sCharacters[playerid][E_CHAR_INVENTORY_PENDING_LOADS] > 0)
    {
        defer Character_InventorySyncTimer(playerid, Config_GetPlayerSessionToken(playerid), 0);
    }
    return 1;
}

// Ежесекундный учет активного времени игры: прогрессия уровня (10 ч = +1 год) и Warrant Decay (1 ч = -1 розыск)
task Character_SecondProgressionTask[1000]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }

    new const nowTick = GetTickCount();

    foreach (new playerid : Player)
    {
        if (!sCharacters[playerid][E_CHAR_LOADED])
        {
            continue;
        }

        // Проверка активности игрока (исключение AFK-накрутки таймеров)
        if ((nowTick - gLastPlayerPacketTick[playerid]) > AFK_INACTIVE_THRESHOLD_MS)
        {
            continue;
        }

        // 1. Прогрессия уровня и возраста (10 часов = 36000 секунд = +1 Level / +1 год возраста)
        sCharacters[playerid][E_CHAR_EXP_SECONDS]++;
        if (sCharacters[playerid][E_CHAR_EXP_SECONDS] >= LEVEL_UP_ACTIVE_SECONDS)
        {
            sCharacters[playerid][E_CHAR_EXP_SECONDS] -= LEVEL_UP_ACTIVE_SECONDS;
            sCharacters[playerid][E_CHAR_LEVEL]++;

            new msg[144];
            format(msg, sizeof(msg),
                "Congratulations! You have lived another year in the state of San Andreas. Your level: %d (Age: %d years).",
                sCharacters[playerid][E_CHAR_LEVEL],
                Character_GetAge(playerid));
            SendClientMessage(playerid, COLOR_SERVER_GOLD, msg);
            SetPlayerScore(playerid, sCharacters[playerid][E_CHAR_LEVEL]);
            Character_MarkDirty(playerid);
        }

    }
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused inputtext
    switch (dialogid)
    {
        case DIALOG_CHAR_SELECT_GENDER:
        {
            if (!response)
            {
                Internal_ShowWizardStep1Gender(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            sCharacters[playerid][E_CHAR_GENDER_VAL] = (listitem == 1)
                ? CHAR_GENDER_FEMALE
                : CHAR_GENDER_MALE;
            Internal_ShowWizardStep2Race(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_CHAR_SELECT_RACE:
        {
            if (!response)
            {
                Internal_ShowWizardStep1Gender(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new const E_CHAR_RACE:selectedRace = E_CHAR_RACE:(listitem + 1);
            sCharacters[playerid][E_CHAR_RACE_VAL] = selectedRace;
            Internal_ShowWizardStep3Skin(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_CHAR_SELECT_SKIN:
        {
            if (!response)
            {
                Internal_ShowWizardStep2Race(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            if (listitem == 0)
            {
                sCharacters[playerid][E_CHAR_WIZARD_CUSTOM_SKIN] = 0;
            }
            else
            {
                new const genderIdx = (sCharacters[playerid][E_CHAR_GENDER_VAL] == CHAR_GENDER_FEMALE) ? 1 : 0;
                new raceIdx = _:sCharacters[playerid][E_CHAR_RACE_VAL] - 1;
                if (raceIdx < 0 || raceIdx > 3) raceIdx = 0;

                new skinChoice = listitem - 1;
                if (skinChoice < 0 || skinChoice > 2) skinChoice = 0;
                sCharacters[playerid][E_CHAR_WIZARD_CUSTOM_SKIN] = sCasualSkins[genderIdx][raceIdx][skinChoice];
            }

            Internal_ShowWizardStep4RoleList(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_CHAR_SELECT_ROLE_LIST:
        {
            if (!response)
            {
                Internal_ShowWizardStep3Skin(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            if (listitem < 0 || listitem >= sWizardRoleRowCount[playerid])
            {
                Internal_ShowWizardStep4RoleList(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const chosenRoleId = sWizardRoleRowMap[playerid][listitem];
            if (!Roles_IsValidId(chosenRoleId))
            {
                Internal_ShowWizardStep4RoleList(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            Internal_ShowWizardStep5ConfirmRole(playerid, chosenRoleId);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_CHAR_CONFIRM_ROLE:
        {
            if (!response)
            {
                Internal_ShowWizardStep4RoleList(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            Internal_FinalizeCharacterCreation(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_CHAR_STATS_VIEW:
        {
            if (response)
            {
                Skills_ShowDialog(playerid);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_0;
}

CMD:stats(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Your character has not yet been loaded. Complete authorization or hero creation.");
        return 1;
    }
    Character_ShowStatsDialog(playerid);
    return 1;
}
alias:stats("mm");

CMD:roleinfo(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "First complete character creation.");
        return 1;
    }

    new card[1280];
    Roles_FormatDetailedCardRu(sCharacters[playerid][E_CHAR_ROLE_ID], card);
    ShowPlayerDialog(
        playerid,
        DIALOG_CHAR_ROLE_INFO,
        DIALOG_STYLE_MSGBOX,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Description of your starting role",
        card,
        "Close",
        "");
    return 1;
}

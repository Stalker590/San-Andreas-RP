/*
 * =============================================================================
 *  SAN ANDREAS RP — Добыча сырья, реестр предприятий и система крафта
 *  Файл:      gamemodes/modules/systems/mod_crafting.pwn
 *  Пункт:     ROADMAP [6.1] — Добыча сырья и система крафта (systems/mod_crafting.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_crafting_included
    #endinput
#endif
#define _mod_crafting_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ, ТАЙМЕРЫ И ИДЕНТИФИКАТОРЫ ДИАЛОГОВ
// =============================================================================

#define MAX_CRAFT_RECIPES                       (256)
#define MAX_CRAFT_RECIPE_INPUTS                 (6)
#define MAX_VISIBLE_CRAFT_RECIPES               (128)
#define CRAFT_DIALOG_BUFFER_LEN                 (16384)
#define ENTERPRISE_WORK_RADIUS                  (45.0)
#define ENTERPRISE_DELIVERY_RADIUS              (3.5)
#define ENTERPRISE_LABEL_DRAW_DISTANCE          (45.0)
#define ENTERPRISE_LABEL_STREAM_DISTANCE        (150.0)
#define CRAFT_COMMAND_COOLDOWN_MS               (450)
#define CRAFT_MINING_COOLDOWN_MS                (4000)
#define CRAFT_JOB_MAX_INPUTS                    (MAX_CRAFT_RECIPE_INPUTS)

#define DIALOG_CRAFT_RECIPES                    (1300)

#define INVALID_ENTERPRISE_ID                   (-1)
#define INVALID_CRAFT_RECIPE_SLOT               (-1)

#define TOTAL_FALLBACK_RECIPES                  (69)
#define TOTAL_FALLBACK_RECIPE_INPUTS            (166)
#define TOTAL_BUILTIN_ENTERPRISES               (16)

// =============================================================================
//  2. ТИПЫ ПРЕДПРИЯТИЙ, ВЕРСТАКОВ И СТРУКТУРЫ ДАННЫХ
// =============================================================================

enum E_ENTERPRISE_TYPE
{
    ENTERPRISE_NONE = 0,
    ENTERPRISE_MINE_ORE,
    ENTERPRISE_OIL_RIG,
    ENTERPRISE_SAWMILL,
    ENTERPRISE_FARM,
    ENTERPRISE_REFINERY,
    ENTERPRISE_METALLURGY,
    ENTERPRISE_FACTORY,
    ENTERPRISE_RETAIL_SHOP,
    ENTERPRISE_GAS_STATION,
    ENTERPRISE_CHOP_SHOP
};

enum E_ENTERPRISE_OWNERSHIP
{
    ENTERPRISE_OWN_STATE = 0,
    ENTERPRISE_OWN_PRIVATE,
    ENTERPRISE_OWN_UNOWNED
};

enum E_CRAFT_STATION
{
    CRAFT_STATION_NONE = 0,
    CRAFT_STATION_HAND,
    CRAFT_STATION_WORKBENCH_WEAPON,
    CRAFT_STATION_WORKBENCH_CHEM,
    CRAFT_STATION_FACTORY_REFINERY,
    CRAFT_STATION_FACTORY_METALLURGY,
    CRAFT_STATION_FACTORY_ASSEMBLY
};

enum E_ENTERPRISE_DATA
{
    bool:E_ENT_VALID,
    E_ENT_DB_ID,
    E_ENT_NAME[64],
    E_ENTERPRISE_TYPE:E_ENT_TYPE,
    E_ENTERPRISE_OWNERSHIP:E_ENT_OWNERSHIP,
    E_ENT_OWNER_CHAR_ID,
    E_ENT_OWNER_ORG_ID,
    E_ENT_WAREHOUSE_DB_ID,
    E_ENT_WAREHOUSE_SLOT,
    E_ENT_RESERVE_USD,
    E_ENT_WAGE_PER_KG_USD,
    Float:E_ENT_POS_X,
    Float:E_ENT_POS_Y,
    Float:E_ENT_POS_Z,
    E_ENT_AUCTION_PRICE_USD
};

enum E_CRAFT_RECIPE
{
    bool:E_RECIPE_VALID,
    E_RECIPE_DB_ID,
    E_RECIPE_OUTPUT_ITEM_ID,
    E_RECIPE_OUTPUT_AMOUNT,
    E_CRAFT_STATION:E_RECIPE_STATION,
    E_SKILL_TYPE:E_RECIPE_SKILL,
    E_RECIPE_MIN_SKILL_LEVEL,
    E_RECIPE_TIME_SEC,
    E_RECIPE_INPUT_COUNT,
    E_RECIPE_INPUT_ITEM_ID[MAX_CRAFT_RECIPE_INPUTS],
    E_RECIPE_INPUT_AMOUNT[MAX_CRAFT_RECIPE_INPUTS]
};

enum E_CRAFT_JOB
{
    bool:E_JOB_ACTIVE,
    E_JOB_TOKEN,
    E_JOB_RECIPE_SLOT,
    E_JOB_OUTPUT_AMOUNT,
    E_JOB_INPUT_COUNT,
    E_JOB_INPUT_ITEM_ID[CRAFT_JOB_MAX_INPUTS],
    E_JOB_INPUT_AMOUNT[CRAFT_JOB_MAX_INPUTS],
    Float:E_JOB_POS_X,
    Float:E_JOB_POS_Y,
    Float:E_JOB_POS_Z,
    E_JOB_INTERIOR,
    E_JOB_VW
};

enum E_FALLBACK_RECIPE
{
    E_FR_DB_ID,
    E_FR_OUTPUT_ITEM_ID,
    E_FR_OUTPUT_AMOUNT,
    E_CRAFT_STATION:E_FR_STATION,
    E_SKILL_TYPE:E_FR_SKILL,
    E_FR_MIN_SKILL,
    E_FR_TIME_SEC
};

// =============================================================================
//  3. ИНКАПСУЛИРОВАННЫЕ ПУЛЫ ДАННЫХ (static stock)
// =============================================================================

static stock sEnterprises[MAX_ENTERPRISES][E_ENTERPRISE_DATA];
new Iterator:EnterpriseIter<MAX_ENTERPRISES>;
static stock STREAMER_TAG_3D_TEXT_LABEL:sEnterpriseLabel[MAX_ENTERPRISES];

static stock sRecipes[MAX_CRAFT_RECIPES][E_CRAFT_RECIPE];
static stock Iterator:RecipeIter<MAX_CRAFT_RECIPES>;

static stock sCraftJob[MAX_PLAYERS][E_CRAFT_JOB];
static stock sCraftDialogRecipeMap[MAX_PLAYERS][MAX_VISIBLE_CRAFT_RECIPES];
static stock sCraftDialogRecipeCount[MAX_PLAYERS];
static stock sLastCraftCommandTick[MAX_PLAYERS];
static stock sLastMiningTick[MAX_PLAYERS];
static stock sCraftDialogBuffer[CRAFT_DIALOG_BUFFER_LEN];

// Этилонные таблицы для автономного режима (когда MySQL недоступен)
static stock const sBuiltinEnterprises[TOTAL_BUILTIN_ENTERPRISES][E_ENTERPRISE_DATA] =
{
    { true, 1,  "Hunter Quarry Iron Mine",           ENTERPRISE_MINE_ORE,   ENTERPRISE_OWN_STATE,   0, 1,  22, INVALID_STORAGE_SLOT, 1500000, 14, 595.4,  872.6,  -42.5, 0 },
    { true, 2,  "Octane Springs Oil Field",        ENTERPRISE_OIL_RIG,    ENTERPRISE_OWN_STATE,   0, 1,  23, INVALID_STORAGE_SLOT, 1500000, 16, 261.2,  1411.8, 10.6,  0 },
    { true, 3,  "Angel Pine Logging Complex",    ENTERPRISE_SAWMILL,    ENTERPRISE_OWN_STATE,   0, 1,  24, INVALID_STORAGE_SLOT, 1000000, 12, -533.8, -179.4, 78.4,  0 },
    { true, 4,  "Flint County Grain Farm",      ENTERPRISE_FARM,       ENTERPRISE_OWN_STATE,   0, 1,  25, INVALID_STORAGE_SLOT, 1000000, 10, -382.1, -1426.3, 25.7, 0 },
    { true, 5,  "Green Palms Oil Refinery",       ENTERPRISE_REFINERY,   ENTERPRISE_OWN_STATE,   0, 1,  26, INVALID_STORAGE_SLOT, 2500000, 8,  248.4,  1396.2, 10.6,  0 },
    { true, 6,  "Ocean Docks Steel Mill",         ENTERPRISE_METALLURGY, ENTERPRISE_OWN_STATE,   0, 1,  27, INVALID_STORAGE_SLOT, 2500000, 10, 2180.5, -2253.8, 13.5, 0 },
    { true, 7,  "Easter Basin Assembly Plant",                 ENTERPRISE_FACTORY,    ENTERPRISE_OWN_UNOWNED, 0, 0,  28, INVALID_STORAGE_SLOT, 1200000, 12, -1042.6, -664.2, 32.0, 850000 },
    { true, 8,  "Idlewood 24/7 Supermarket",                       ENTERPRISE_RETAIL_SHOP, ENTERPRISE_OWN_UNOWNED, 0, 0,  29, INVALID_STORAGE_SLOT, 400000,  5,  1352.3, -1759.2, 13.5, 250000 },
    { true, 9,  "Juniper Hill 24/7 Supermarket",                 ENTERPRISE_RETAIL_SHOP, ENTERPRISE_OWN_UNOWNED, 0, 0,  30, INVALID_STORAGE_SLOT, 400000,  5,  -2442.6, 754.8, 35.2,  250000 },
    { true, 10, "Las Venturas Creek Trading House",               ENTERPRISE_RETAIL_SHOP, ENTERPRISE_OWN_UNOWNED, 0, 0,  31, INVALID_STORAGE_SLOT, 400000,  5,  2194.2, 1991.0, 12.3,  275000 },
    { true, 11, "Idlewood Gas Station",                    ENTERPRISE_GAS_STATION, ENTERPRISE_OWN_UNOWNED, 0, 0,  32, INVALID_STORAGE_SLOT, 600000,  5,  1940.1, -1772.9, 13.4, 350000 },
    { true, 12, "Easter Basin Gas Station",               ENTERPRISE_GAS_STATION, ENTERPRISE_OWN_UNOWNED, 0, 0,  33, INVALID_STORAGE_SLOT, 600000,  5,  -1676.3, 413.2, 7.2,   350000 },
    { true, 13, "Emerald Isle Gas Station",          ENTERPRISE_GAS_STATION, ENTERPRISE_OWN_UNOWNED, 0, 0,  34, INVALID_STORAGE_SLOT, 600000,  5,  2115.2, 920.1, 10.8,  375000 },
    { true, 14, "East Los Santos Chop Shop",          ENTERPRISE_CHOP_SHOP,   ENTERPRISE_OWN_PRIVATE, 0, 19, 35, INVALID_STORAGE_SLOT, 300000,  8,  2403.5, -1406.2, 24.0, 0 },
    { true, 15, "Doherty Underground Garage",                      ENTERPRISE_CHOP_SHOP,   ENTERPRISE_OWN_PRIVATE, 0, 20, 36, INVALID_STORAGE_SLOT, 350000,  8,  -2051.8, 178.4, 28.8,  0 },
    { true, 16, "Redsands West Chop Shop",                   ENTERPRISE_CHOP_SHOP,   ENTERPRISE_OWN_PRIVATE, 0, 21, 37, INVALID_STORAGE_SLOT, 400000,  8,  1658.4, 2196.1, 10.8, 0 }
};

static stock const sFallbackRecipeMeta[TOTAL_FALLBACK_RECIPES][E_FALLBACK_RECIPE] =
{
    { 1, 82, 1, CRAFT_STATION_FACTORY_METALLURGY, SKILL_METALLURGY, 0, 10 },
    { 2, 83, 2, CRAFT_STATION_FACTORY_METALLURGY, SKILL_METALLURGY, 100, 8 },
    { 3, 84, 2, CRAFT_STATION_FACTORY_METALLURGY, SKILL_METALLURGY, 150, 8 },
    { 4, 85, 5, CRAFT_STATION_FACTORY_METALLURGY, SKILL_METALLURGY, 0, 6 },
    { 5, 86, 1, CRAFT_STATION_FACTORY_REFINERY, SKILL_CHEMISTRY, 50, 10 },
    { 6, 87, 2, CRAFT_STATION_WORKBENCH_CHEM, SKILL_CHEMISTRY, 200, 12 },
    { 7, 88, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_MINING_LOGGING, 0, 6 },
    { 8, 89, 2, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_SURVIVALISM, 0, 8 },
    { 9, 90, 5, CRAFT_STATION_FACTORY_REFINERY, SKILL_CHEMISTRY, 0, 15 },
    { 10, 82, 6, CRAFT_STATION_FACTORY_METALLURGY, SKILL_METALLURGY, 300, 45 },
    { 11, 1, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 50, 8 },
    { 12, 2, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_MECHANICS, 50, 10 },
    { 13, 3, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_MECHANICS, 100, 10 },
    { 14, 4, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 50, 8 },
    { 15, 5, 1, CRAFT_STATION_HAND, SKILL_SURVIVALISM, 0, 8 },
    { 16, 6, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_MECHANICS, 0, 10 },
    { 17, 7, 1, CRAFT_STATION_HAND, SKILL_SURVIVALISM, 0, 6 },
    { 18, 8, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 400, 20 },
    { 19, 9, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_MECHANICS, 350, 25 },
    { 20, 10, 1, CRAFT_STATION_HAND, SKILL_SURVIVALISM, 0, 6 },
    { 21, 13, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 150, 15 },
    { 22, 14, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 250, 18 },
    { 23, 15, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 350, 20 },
    { 24, 16, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 300, 22 },
    { 25, 17, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 200, 12 },
    { 26, 18, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 550, 28 },
    { 27, 19, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 300, 18 },
    { 28, 20, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 280, 18 },
    { 29, 21, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 450, 24 },
    { 30, 22, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 600, 30 },
    { 31, 23, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 650, 32 },
    { 32, 24, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 400, 22 },
    { 33, 25, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 750, 40 },
    { 34, 26, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_DEMOLITIONS, 400, 15 },
    { 35, 27, 1, CRAFT_STATION_WORKBENCH_CHEM, SKILL_CHEMISTRY, 250, 12 },
    { 36, 28, 1, CRAFT_STATION_HAND, SKILL_SURVIVALISM, 100, 8 },
    { 37, 29, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_DEMOLITIONS, 650, 25 },
    { 38, 30, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_DEMOLITIONS, 800, 45 },
    { 39, 31, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_DEMOLITIONS, 900, 60 },
    { 40, 32, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_MECHANICS, 700, 40 },
    { 41, 33, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_GUNSMITHING, 950, 90 },
    { 42, 34, 1, CRAFT_STATION_WORKBENCH_CHEM, SKILL_CHEMISTRY, 100, 8 },
    { 43, 35, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_MECHANICS, 150, 12 },
    { 44, 37, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_MECHANICS, 500, 20 },
    { 45, 39, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_SURVIVALISM, 300, 18 },
    { 46, 40, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 350, 20 },
    { 47, 41, 1, CRAFT_STATION_HAND, SKILL_SURVIVALISM, 100, 12 },
    { 48, 42, 1, CRAFT_STATION_HAND, SKILL_SURVIVALISM, 50, 10 },
    { 49, 43, 1, CRAFT_STATION_HAND, SKILL_SURVIVALISM, 0, 5 },
    { 50, 44, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_MECHANICS, 200, 12 },
    { 51, 45, 2, CRAFT_STATION_HAND, SKILL_LOCKPICKING, 100, 8 },
    { 52, 46, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_MECHANICS, 250, 15 },
    { 53, 47, 1, CRAFT_STATION_WORKBENCH_WEAPON, SKILL_GUNSMITHING, 300, 15 },
    { 54, 48, 1, CRAFT_STATION_FACTORY_REFINERY, SKILL_MECHANICS, 0, 10 },
    { 55, 49, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_MECHANICS, 200, 14 },
    { 56, 53, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_MECHANICS, 300, 15 },
    { 57, 54, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_MINING_LOGGING, 0, 10 },
    { 58, 55, 1, CRAFT_STATION_WORKBENCH_CHEM, SKILL_FORENSICS, 250, 18 },
    { 59, 56, 1, CRAFT_STATION_WORKBENCH_CHEM, SKILL_FIRST_AID, 150, 10 },
    { 60, 57, 1, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_SURGERY, 400, 18 },
    { 61, 58, 2, CRAFT_STATION_HAND, SKILL_FIRST_AID, 0, 5 },
    { 62, 59, 1, CRAFT_STATION_HAND, SKILL_FIRST_AID, 50, 6 },
    { 63, 60, 2, CRAFT_STATION_WORKBENCH_CHEM, SKILL_CHEMISTRY, 350, 14 },
    { 64, 61, 2, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_SURVIVALISM, 0, 5 },
    { 65, 62, 2, CRAFT_STATION_FACTORY_ASSEMBLY, SKILL_SURVIVALISM, 100, 8 },
    { 66, 63, 2, CRAFT_STATION_HAND, SKILL_SURVIVALISM, 0, 5 },
    { 67, 64, 1, CRAFT_STATION_WORKBENCH_CHEM, SKILL_CHEMISTRY, 100, 10 },
    { 68, 66, 3, CRAFT_STATION_WORKBENCH_CHEM, SKILL_CHEMISTRY, 500, 25 },
    { 69, 67, 1, CRAFT_STATION_WORKBENCH_CHEM, SKILL_CHEMISTRY, 200, 15 }
};

static stock const sFallbackRecipeInputs[TOTAL_FALLBACK_RECIPE_INPUTS][3] =
{
    { 1, 77, 2 },
    { 1, 76, 1 },
    { 2, 77, 1 },
    { 3, 77, 1 },
    { 4, 77, 1 },
    { 5, 76, 2 },
    { 6, 81, 1 },
    { 6, 76, 1 },
    { 7, 78, 1 },
    { 8, 80, 1 },
    { 8, 79, 1 },
    { 9, 76, 6 },
    { 10, 77, 10 },
    { 10, 76, 2 },
    { 11, 82, 1 },
    { 12, 82, 1 },
    { 12, 86, 1 },
    { 13, 86, 1 },
    { 13, 82, 1 },
    { 14, 82, 1 },
    { 14, 86, 1 },
    { 15, 88, 2 },
    { 16, 82, 2 },
    { 16, 88, 1 },
    { 17, 88, 1 },
    { 18, 82, 2 },
    { 18, 89, 1 },
    { 19, 82, 3 },
    { 19, 86, 2 },
    { 19, 84, 2 },
    { 20, 88, 1 },
    { 20, 85, 1 },
    { 21, 82, 1 },
    { 21, 83, 1 },
    { 21, 84, 1 },
    { 21, 87, 1 },
    { 22, 13, 1 },
    { 22, 82, 1 },
    { 22, 86, 1 },
    { 23, 82, 2 },
    { 23, 83, 2 },
    { 23, 87, 2 },
    { 24, 82, 3 },
    { 24, 88, 1 },
    { 24, 83, 1 },
    { 24, 87, 2 },
    { 25, 16, 1 },
    { 25, 85, 1 },
    { 26, 82, 4 },
    { 26, 86, 1 },
    { 26, 83, 2 },
    { 26, 87, 3 },
    { 27, 82, 2 },
    { 27, 83, 2 },
    { 27, 84, 1 },
    { 27, 87, 2 },
    { 28, 82, 2 },
    { 28, 83, 1 },
    { 28, 86, 1 },
    { 28, 87, 2 },
    { 29, 82, 3 },
    { 29, 86, 1 },
    { 29, 84, 2 },
    { 29, 87, 2 },
    { 30, 82, 4 },
    { 30, 88, 1 },
    { 30, 83, 2 },
    { 30, 87, 3 },
    { 31, 82, 3 },
    { 31, 86, 2 },
    { 31, 83, 2 },
    { 31, 84, 2 },
    { 31, 87, 3 },
    { 32, 82, 3 },
    { 32, 88, 2 },
    { 32, 83, 1 },
    { 32, 87, 2 },
    { 33, 82, 6 },
    { 33, 83, 2 },
    { 33, 84, 2 },
    { 33, 87, 3 },
    { 34, 82, 1 },
    { 34, 87, 2 },
    { 34, 83, 1 },
    { 35, 82, 1 },
    { 35, 81, 1 },
    { 36, 64, 1 },
    { 36, 90, 1 },
    { 36, 89, 1 },
    { 37, 86, 2 },
    { 37, 87, 4 },
    { 37, 81, 2 },
    { 38, 82, 6 },
    { 38, 87, 5 },
    { 38, 83, 2 },
    { 39, 82, 8 },
    { 39, 87, 6 },
    { 39, 86, 3 },
    { 40, 82, 6 },
    { 40, 90, 5 },
    { 40, 84, 2 },
    { 41, 82, 15 },
    { 41, 84, 8 },
    { 41, 83, 6 },
    { 41, 87, 8 },
    { 42, 82, 1 },
    { 42, 81, 1 },
    { 43, 82, 3 },
    { 43, 81, 2 },
    { 43, 79, 2 },
    { 44, 86, 2 },
    { 44, 84, 1 },
    { 45, 89, 6 },
    { 45, 86, 2 },
    { 45, 85, 2 },
    { 46, 89, 4 },
    { 46, 82, 4 },
    { 47, 89, 3 },
    { 47, 86, 1 },
    { 48, 89, 3 },
    { 48, 85, 1 },
    { 49, 89, 1 },
    { 50, 82, 1 },
    { 50, 83, 1 },
    { 50, 85, 1 },
    { 51, 83, 1 },
    { 51, 85, 2 },
    { 52, 82, 3 },
    { 52, 86, 1 },
    { 53, 82, 2 },
    { 53, 83, 2 },
    { 53, 84, 2 },
    { 54, 82, 3 },
    { 54, 90, 20 },
    { 55, 82, 3 },
    { 55, 86, 1 },
    { 56, 86, 1 },
    { 56, 85, 2 },
    { 57, 82, 2 },
    { 57, 88, 1 },
    { 58, 86, 2 },
    { 58, 81, 2 },
    { 59, 89, 2 },
    { 59, 81, 1 },
    { 59, 79, 1 },
    { 60, 82, 2 },
    { 60, 89, 2 },
    { 60, 81, 1 },
    { 61, 89, 1 },
    { 62, 89, 1 },
    { 62, 86, 1 },
    { 63, 86, 1 },
    { 63, 81, 2 },
    { 64, 79, 2 },
    { 64, 86, 1 },
    { 65, 80, 2 },
    { 65, 79, 1 },
    { 65, 86, 1 },
    { 66, 80, 1 },
    { 66, 79, 1 },
    { 67, 80, 2 },
    { 67, 79, 2 },
    { 68, 81, 3 },
    { 68, 79, 1 },
    { 69, 80, 1 },
    { 69, 81, 1 }
};

// =============================================================================
//  4. ВНУТРЕННИЕ ФУНКЦИИ РЕЕСТРА ПРЕДПРИЯТИЙ (static stock)
// =============================================================================

static stock Internal_ResetEnterprise(enterprise_id)
{
    sEnterprises[enterprise_id][E_ENT_VALID] = false;
    sEnterprises[enterprise_id][E_ENT_DB_ID] = 0;
    sEnterprises[enterprise_id][E_ENT_NAME][0] = '\0';
    sEnterprises[enterprise_id][E_ENT_TYPE] = ENTERPRISE_NONE;
    sEnterprises[enterprise_id][E_ENT_OWNERSHIP] = ENTERPRISE_OWN_UNOWNED;
    sEnterprises[enterprise_id][E_ENT_OWNER_CHAR_ID] = 0;
    sEnterprises[enterprise_id][E_ENT_OWNER_ORG_ID] = 0;
    sEnterprises[enterprise_id][E_ENT_WAREHOUSE_DB_ID] = 0;
    sEnterprises[enterprise_id][E_ENT_WAREHOUSE_SLOT] = INVALID_STORAGE_SLOT;
    sEnterprises[enterprise_id][E_ENT_RESERVE_USD] = 0;
    sEnterprises[enterprise_id][E_ENT_WAGE_PER_KG_USD] = 0;
    sEnterprises[enterprise_id][E_ENT_POS_X] = 0.0;
    sEnterprises[enterprise_id][E_ENT_POS_Y] = 0.0;
    sEnterprises[enterprise_id][E_ENT_POS_Z] = 0.0;
    sEnterprises[enterprise_id][E_ENT_AUCTION_PRICE_USD] = 0;
}

static stock Internal_ParseEnterpriseType(const typeStr[])
{
    if (!strcmp(typeStr, "MINE_ORE", true))    return _:ENTERPRISE_MINE_ORE;
    if (!strcmp(typeStr, "OIL_RIG", true))     return _:ENTERPRISE_OIL_RIG;
    if (!strcmp(typeStr, "SAWMILL", true))     return _:ENTERPRISE_SAWMILL;
    if (!strcmp(typeStr, "FARM", true))        return _:ENTERPRISE_FARM;
    if (!strcmp(typeStr, "REFINERY", true))    return _:ENTERPRISE_REFINERY;
    if (!strcmp(typeStr, "METALLURGY", true))  return _:ENTERPRISE_METALLURGY;
    if (!strcmp(typeStr, "FACTORY", true))     return _:ENTERPRISE_FACTORY;
    if (!strcmp(typeStr, "RETAIL_SHOP", true)) return _:ENTERPRISE_RETAIL_SHOP;
    if (!strcmp(typeStr, "GAS_STATION", true)) return _:ENTERPRISE_GAS_STATION;
    if (!strcmp(typeStr, "CHOP_SHOP", true))   return _:ENTERPRISE_CHOP_SHOP;
    return _:ENTERPRISE_NONE;
}

static stock Internal_ParseOwnership(const ownerStr[])
{
    if (!strcmp(ownerStr, "STATE", true))   return _:ENTERPRISE_OWN_STATE;
    if (!strcmp(ownerStr, "PRIVATE", true)) return _:ENTERPRISE_OWN_PRIVATE;
    return _:ENTERPRISE_OWN_UNOWNED;
}

static stock E_CRAFT_STATION:Internal_ParseStationType(const stationStr[])
{
    if (!strcmp(stationStr, "HAND", true))               return CRAFT_STATION_HAND;
    if (!strcmp(stationStr, "WORKBENCH_WEAPON", true))   return CRAFT_STATION_WORKBENCH_WEAPON;
    if (!strcmp(stationStr, "WORKBENCH_CHEM", true))     return CRAFT_STATION_WORKBENCH_CHEM;
    if (!strcmp(stationStr, "FACTORY_REFINERY", true))   return CRAFT_STATION_FACTORY_REFINERY;
    if (!strcmp(stationStr, "FACTORY_METALLURGY", true)) return CRAFT_STATION_FACTORY_METALLURGY;
    if (!strcmp(stationStr, "FACTORY_ASSEMBLY", true))   return CRAFT_STATION_FACTORY_ASSEMBLY;
    return CRAFT_STATION_NONE;
}

static stock Internal_GetEnterpriseTypeTitleRu(E_ENTERPRISE_TYPE:type, output[], len = sizeof(output))
{
    switch (type)
    {
        case ENTERPRISE_MINE_ORE:    format(output, len, "Ore quarry");
        case ENTERPRISE_OIL_RIG:     format(output, len, "Oil production");
        case ENTERPRISE_SAWMILL:     format(output, len, "Sawmill");
        case ENTERPRISE_FARM:        format(output, len, "Farm");
        case ENTERPRISE_REFINERY:    format(output, len, "Oil refining");
        case ENTERPRISE_METALLURGY:  format(output, len, "Metallurgy");
        case ENTERPRISE_FACTORY:     format(output, len, "Assembly plant");
        case ENTERPRISE_RETAIL_SHOP: format(output, len, "Retail store");
        case ENTERPRISE_GAS_STATION: format(output, len, "Gas station");
        case ENTERPRISE_CHOP_SHOP:   format(output, len, "Auto disassembly");
        default:                     format(output, len, "Enterprise");
    }
    return 1;
}

static stock Internal_GetOwnershipTitleRu(E_ENTERPRISE_OWNERSHIP:ownership, output[], len = sizeof(output))
{
    switch (ownership)
    {
        case ENTERPRISE_OWN_STATE:   format(output, len, "State");
        case ENTERPRISE_OWN_PRIVATE: format(output, len, "Private");
        default:                     format(output, len, "Unowned");
    }
    return 1;
}

static stock Internal_GetStationTitleRu(E_CRAFT_STATION:station, output[], len = sizeof(output))
{
    switch (station)
    {
        case CRAFT_STATION_HAND:                format(output, len, "Handmade");
        case CRAFT_STATION_WORKBENCH_WEAPON:    format(output, len, "Weapon workbench");
        case CRAFT_STATION_WORKBENCH_CHEM:      format(output, len, "Chemical workbench");
        case CRAFT_STATION_FACTORY_REFINERY:    format(output, len, "Oil refining");
        case CRAFT_STATION_FACTORY_METALLURGY:  format(output, len, "Metallurgical shop");
        case CRAFT_STATION_FACTORY_ASSEMBLY:    format(output, len, "Assembly shop");
        default:                                format(output, len, "Workbench");
    }
    return 1;
}

static stock bool:Internal_IsPrimaryEnterpriseType(E_ENTERPRISE_TYPE:type)
{
    switch (type)
    {
        case ENTERPRISE_MINE_ORE, ENTERPRISE_OIL_RIG, ENTERPRISE_SAWMILL, ENTERPRISE_FARM:
        {
            return true;
        }
    }
    return false;
}

static stock Internal_GetPrimaryResourceItem(E_ENTERPRISE_TYPE:type)
{
    switch (type)
    {
        case ENTERPRISE_MINE_ORE: return 77; // Железная руда
        case ENTERPRISE_OIL_RIG:  return 76; // Сырая нефть
        case ENTERPRISE_SAWMILL:  return 78; // Древесина-кругляк
        case ENTERPRISE_FARM:     return 80; // Зерно и мука
    }
    return 0;
}

static stock Internal_GetRequiredToolItem(E_ENTERPRISE_TYPE:type)
{
    switch (type)
    {
        case ENTERPRISE_MINE_ORE: return 54; // Шахтерская кирка
        case ENTERPRISE_OIL_RIG:  return 48; // Канистра с бензином
        case ENTERPRISE_SAWMILL:  return 9;  // Бензопила
    }
    return 0;
}

static stock Internal_GetExtractionSkillRequirement(E_ENTERPRISE_TYPE:type)
{
    switch (type)
    {
        case ENTERPRISE_MINE_ORE: return 50;
        case ENTERPRISE_OIL_RIG:  return 100;
        case ENTERPRISE_SAWMILL:  return 50;
    }
    return 0;
}

static stock bool:Internal_IsStationAllowedForEnterprise(E_ENTERPRISE_TYPE:type, E_CRAFT_STATION:station)
{
    switch (type)
    {
        case ENTERPRISE_MINE_ORE, ENTERPRISE_OIL_RIG, ENTERPRISE_SAWMILL, ENTERPRISE_FARM:
        {
            return (station == CRAFT_STATION_HAND);
        }
        case ENTERPRISE_REFINERY:
        {
            return (station == CRAFT_STATION_FACTORY_REFINERY ||
                    station == CRAFT_STATION_WORKBENCH_CHEM ||
                    station == CRAFT_STATION_HAND);
        }
        case ENTERPRISE_METALLURGY:
        {
            return (station == CRAFT_STATION_FACTORY_METALLURGY ||
                    station == CRAFT_STATION_HAND);
        }
        case ENTERPRISE_FACTORY:
        {
            return (station == CRAFT_STATION_FACTORY_ASSEMBLY ||
                    station == CRAFT_STATION_WORKBENCH_WEAPON ||
                    station == CRAFT_STATION_WORKBENCH_CHEM ||
                    station == CRAFT_STATION_HAND);
        }
        case ENTERPRISE_CHOP_SHOP:
        {
            return (station == CRAFT_STATION_WORKBENCH_WEAPON);
        }
    }
    return false;
}

static stock Internal_RefreshEnterpriseLabel(enterprise_id)
{
    if (enterprise_id < 0 || enterprise_id >= MAX_ENTERPRISES ||
        !sEnterprises[enterprise_id][E_ENT_VALID])
    {
        return 0;
    }

    if (sEnterpriseLabel[enterprise_id] != STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID)
    {
        DestroyDynamic3DTextLabel(sEnterpriseLabel[enterprise_id]);
        sEnterpriseLabel[enterprise_id] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
    }

    new labelText[256];
    new typeTitle[32];
    new ownerTitle[32];

    Internal_GetEnterpriseTypeTitleRu(sEnterprises[enterprise_id][E_ENT_TYPE], typeTitle, sizeof(typeTitle));
    Internal_GetOwnershipTitleRu(sEnterprises[enterprise_id][E_ENT_OWNERSHIP], ownerTitle, sizeof(ownerTitle));

    format(labelText, sizeof(labelText),
        "%s\n%s | %s\nSalary: $%d/kg\nTeams: /mine /deliver /craft /market /enterprise",
        sEnterprises[enterprise_id][E_ENT_NAME],
        typeTitle,
        ownerTitle,
        sEnterprises[enterprise_id][E_ENT_WAGE_PER_KG_USD]);

    if (sEnterprises[enterprise_id][E_ENT_OWNERSHIP] == ENTERPRISE_OWN_UNOWNED &&
        sEnterprises[enterprise_id][E_ENT_AUCTION_PRICE_USD] > 0)
    {
        new auctionLine[64];
        format(auctionLine, sizeof(auctionLine), "\nAuction: /auction ($%d)",
            sEnterprises[enterprise_id][E_ENT_AUCTION_PRICE_USD]);
        strcat(labelText, auctionLine, sizeof(labelText));
    }

    sEnterpriseLabel[enterprise_id] = CreateDynamic3DTextLabel(
        labelText,
        COLOR_UI_INFO,
        sEnterprises[enterprise_id][E_ENT_POS_X],
        sEnterprises[enterprise_id][E_ENT_POS_Y],
        sEnterprises[enterprise_id][E_ENT_POS_Z] + 2.0,
        ENTERPRISE_LABEL_DRAW_DISTANCE,
        INVALID_PLAYER_ID,
        INVALID_VEHICLE_ID,
        0,
        0, 0, -1,
        ENTERPRISE_LABEL_STREAM_DISTANCE
    );
    return 1;
}

static stock Internal_CreateEnterpriseLabels()
{
    foreach (new enterpriseId : EnterpriseIter)
    {
        if (sEnterprises[enterpriseId][E_ENT_VALID])
        {
            Internal_RefreshEnterpriseLabel(enterpriseId);
        }
    }
}

static stock Internal_LoadBuiltinEnterprises()
{
    for (new i = 0; i < TOTAL_BUILTIN_ENTERPRISES; i++)
    {
        new const slotId = Iter_Free(EnterpriseIter);
        if (slotId == INVALID_ITERATOR_SLOT)
        {
            break;
        }
        Iter_Add(EnterpriseIter, slotId);
        sEnterprises[slotId] = sBuiltinEnterprises[i];
        sEnterprises[slotId][E_ENT_WAREHOUSE_SLOT] = INVALID_STORAGE_SLOT;
    }
}

static stock Internal_LoadEnterprisesSync()
{
    Iter_Init(EnterpriseIter);
    for (new i = 0; i < MAX_ENTERPRISES; i++)
    {
        Internal_ResetEnterprise(i);
        sEnterpriseLabel[i] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
    }

    if (!DB_IsConnected())
    {
        Internal_LoadBuiltinEnterprises();
        printf("%s [Systems/Crafting] MySQL is unavailable: the built-in enterprise registry is loaded (%d entries).",
            SERVER_LOG_PREFIX, TOTAL_BUILTIN_ENTERPRISES);
        return TOTAL_BUILTIN_ENTERPRISES;
    }

    // Разрешенный синхронный запрос строго внутри OnGameModeInit
    new const Cache:cache = mysql_query(gMySQL,
        "SELECT `id`, `name`, `enterprise_type`, `ownership`, IFNULL(`owner_char_id`, 0) AS `owner_char`, IFNULL(`owner_org_id`, 0) AS `owner_org`, `warehouse_storage_id`, `reserve_usd`, `wage_per_kg_usd`, `pos_x`, `pos_y`, `pos_z`, IFNULL(`auction_price_usd`, 0) AS `auction_price` FROM `enterprises` ORDER BY `id` ASC;",
        true);

    if (!cache_is_valid(cache))
    {
        Internal_LoadBuiltinEnterprises();
        printf("%s [Systems/Crafting] [WARN] Failed to read enterprises: embedded registry loaded.",
            SERVER_LOG_PREFIX);
        return TOTAL_BUILTIN_ENTERPRISES;
    }

    new rowCount = 0;
    cache_get_row_count(rowCount);
    new loadedCount = 0;

    for (new row = 0; row < rowCount; row++)
    {
        new const slotId = Iter_Free(EnterpriseIter);
        if (slotId == INVALID_ITERATOR_SLOT)
        {
            break;
        }

        new name[64], typeStr[24], ownershipStr[16];
        cache_get_value_name(row, "name", name, sizeof(name));
        cache_get_value_name(row, "enterprise_type", typeStr, sizeof(typeStr));
        cache_get_value_name(row, "ownership", ownershipStr, sizeof(ownershipStr));

        Internal_ResetEnterprise(slotId);
        Iter_Add(EnterpriseIter, slotId);

        sEnterprises[slotId][E_ENT_VALID] = true;
        cache_get_value_name_int(row, "id", sEnterprises[slotId][E_ENT_DB_ID]);
        format(sEnterprises[slotId][E_ENT_NAME], 64, "%s", name);
        sEnterprises[slotId][E_ENT_TYPE] = E_ENTERPRISE_TYPE:Internal_ParseEnterpriseType(typeStr);
        sEnterprises[slotId][E_ENT_OWNERSHIP] = E_ENTERPRISE_OWNERSHIP:Internal_ParseOwnership(ownershipStr);
        cache_get_value_name_int(row, "owner_char", sEnterprises[slotId][E_ENT_OWNER_CHAR_ID]);
        cache_get_value_name_int(row, "owner_org", sEnterprises[slotId][E_ENT_OWNER_ORG_ID]);
        cache_get_value_name_int(row, "warehouse_storage_id", sEnterprises[slotId][E_ENT_WAREHOUSE_DB_ID]);
        cache_get_value_name_int(row, "reserve_usd", sEnterprises[slotId][E_ENT_RESERVE_USD]);
        cache_get_value_name_int(row, "wage_per_kg_usd", sEnterprises[slotId][E_ENT_WAGE_PER_KG_USD]);
        cache_get_value_name_float(row, "pos_x", sEnterprises[slotId][E_ENT_POS_X]);
        cache_get_value_name_float(row, "pos_y", sEnterprises[slotId][E_ENT_POS_Y]);
        cache_get_value_name_float(row, "pos_z", sEnterprises[slotId][E_ENT_POS_Z]);
        cache_get_value_name_int(row, "auction_price", sEnterprises[slotId][E_ENT_AUCTION_PRICE_USD]);

        loadedCount++;
    }
    cache_delete(cache);

    // Склады предприятий загружаются модулем хранилищ; при необходимости догружаем.
    foreach (new enterpriseId : EnterpriseIter)
    {
        new const warehouseSlot = Storage_FindByDbId(sEnterprises[enterpriseId][E_ENT_WAREHOUSE_DB_ID]);
        if (warehouseSlot != INVALID_STORAGE_SLOT)
        {
            sEnterprises[enterpriseId][E_ENT_WAREHOUSE_SLOT] = warehouseSlot;
        }
    }

    printf("%s [Systems/Crafting] Business registry loaded from MySQL (records: %d).",
        SERVER_LOG_PREFIX, loadedCount);
    return loadedCount;
}

static stock Internal_ResetRecipe(recipe_slot)
{
    sRecipes[recipe_slot][E_RECIPE_VALID] = false;
    sRecipes[recipe_slot][E_RECIPE_DB_ID] = 0;
    sRecipes[recipe_slot][E_RECIPE_OUTPUT_ITEM_ID] = 0;
    sRecipes[recipe_slot][E_RECIPE_OUTPUT_AMOUNT] = 0;
    sRecipes[recipe_slot][E_RECIPE_STATION] = CRAFT_STATION_NONE;
    sRecipes[recipe_slot][E_RECIPE_SKILL] = MAX_SKILL_TYPES;
    sRecipes[recipe_slot][E_RECIPE_MIN_SKILL_LEVEL] = 0;
    sRecipes[recipe_slot][E_RECIPE_TIME_SEC] = 1;
    sRecipes[recipe_slot][E_RECIPE_INPUT_COUNT] = 0;
    for (new i = 0; i < MAX_CRAFT_RECIPE_INPUTS; i++)
    {
        sRecipes[recipe_slot][E_RECIPE_INPUT_ITEM_ID][i] = 0;
        sRecipes[recipe_slot][E_RECIPE_INPUT_AMOUNT][i] = 0;
    }
}

static stock Internal_AddRecipeInput(recipe_slot, item_def_id, amount)
{
    new const inputCount = sRecipes[recipe_slot][E_RECIPE_INPUT_COUNT];
    if (inputCount < 0 || inputCount >= MAX_CRAFT_RECIPE_INPUTS)
    {
        return 0;
    }
    sRecipes[recipe_slot][E_RECIPE_INPUT_ITEM_ID][inputCount] = item_def_id;
    sRecipes[recipe_slot][E_RECIPE_INPUT_AMOUNT][inputCount] = amount;
    sRecipes[recipe_slot][E_RECIPE_INPUT_COUNT] = inputCount + 1;
    return 1;
}

static stock Internal_AddRecipe(
    dbId,
    outputItemId,
    outputAmount,
    E_CRAFT_STATION:station,
    E_SKILL_TYPE:skill,
    minSkill,
    craftTimeSec)
{
    new const recipeSlot = Iter_Free(RecipeIter);
    if (recipeSlot == INVALID_ITERATOR_SLOT)
    {
        return INVALID_CRAFT_RECIPE_SLOT;
    }

    Iter_Add(RecipeIter, recipeSlot);
    Internal_ResetRecipe(recipeSlot);

    sRecipes[recipeSlot][E_RECIPE_VALID] = true;
    sRecipes[recipeSlot][E_RECIPE_DB_ID] = dbId;
    sRecipes[recipeSlot][E_RECIPE_OUTPUT_ITEM_ID] = outputItemId;
    sRecipes[recipeSlot][E_RECIPE_OUTPUT_AMOUNT] = outputAmount;
    sRecipes[recipeSlot][E_RECIPE_STATION] = station;
    sRecipes[recipeSlot][E_RECIPE_SKILL] = skill;
    sRecipes[recipeSlot][E_RECIPE_MIN_SKILL_LEVEL] = minSkill;
    sRecipes[recipeSlot][E_RECIPE_TIME_SEC] = (craftTimeSec > 0) ? craftTimeSec : 1;
    return recipeSlot;
}

static stock Internal_SeedFallbackRecipes()
{
    for (new i = 0; i < MAX_CRAFT_RECIPES; i++)
    {
        Internal_ResetRecipe(i);
    }
    Iter_Init(RecipeIter);

    for (new idx = 0; idx < TOTAL_FALLBACK_RECIPES; idx++)
    {
        new const recipeSlot = Internal_AddRecipe(
            sFallbackRecipeMeta[idx][E_FR_DB_ID],
            sFallbackRecipeMeta[idx][E_FR_OUTPUT_ITEM_ID],
            sFallbackRecipeMeta[idx][E_FR_OUTPUT_AMOUNT],
            sFallbackRecipeMeta[idx][E_FR_STATION],
            sFallbackRecipeMeta[idx][E_FR_SKILL],
            sFallbackRecipeMeta[idx][E_FR_MIN_SKILL],
            sFallbackRecipeMeta[idx][E_FR_TIME_SEC]);

        if (recipeSlot == INVALID_CRAFT_RECIPE_SLOT)
        {
            break;
        }
    }

    for (new i = 0; i < TOTAL_FALLBACK_RECIPE_INPUTS; i++)
    {
        new const recipeDbId = sFallbackRecipeInputs[i][0];
        foreach (new recipeSlot : RecipeIter)
        {
            if (sRecipes[recipeSlot][E_RECIPE_DB_ID] == recipeDbId)
            {
                Internal_AddRecipeInput(recipeSlot, sFallbackRecipeInputs[i][1], sFallbackRecipeInputs[i][2]);
                break;
            }
        }
    }
    return 1;
}

static stock Internal_LoadRecipesSync()
{
    for (new i = 0; i < MAX_CRAFT_RECIPES; i++)
    {
        Internal_ResetRecipe(i);
    }
    Iter_Init(RecipeIter);

    if (!DB_IsConnected())
    {
        Internal_SeedFallbackRecipes();
        printf("%s [Systems/Crafting] MySQL is unavailable: the built-in set of recipes has been loaded (%d pcs.).",
            SERVER_LOG_PREFIX, TOTAL_FALLBACK_RECIPES);
        return TOTAL_FALLBACK_RECIPES;
    }

    // Разрешенный синхронный запрос строго внутри OnGameModeInit
    new const Cache:recipeCache = mysql_query(gMySQL,
        "SELECT `id`, `output_item_id`, `output_amount`, `station_type`, IFNULL(`required_skill`, '') AS `required_skill`, `min_skill_level`, `craft_time_sec` FROM `craft_recipes` ORDER BY `id` ASC;",
        true);

    if (!cache_is_valid(recipeCache))
    {
        Internal_SeedFallbackRecipes();
        printf("%s [Systems/Crafting] [WARN] Failed to read craft_recipes: built-in set loaded.",
            SERVER_LOG_PREFIX);
        return TOTAL_FALLBACK_RECIPES;
    }

    new recipeRows = 0;
    cache_get_row_count(recipeRows);
    new loadedRecipes = 0;

    for (new row = 0; row < recipeRows; row++)
    {
        new dbId, outputItemId, outputAmount, minSkill, craftTime;
        new stationStr[24], skillStr[32];

        cache_get_value_name_int(row, "id", dbId);
        cache_get_value_name_int(row, "output_item_id", outputItemId);
        cache_get_value_name_int(row, "output_amount", outputAmount);
        cache_get_value_name(row, "station_type", stationStr, sizeof(stationStr));
        cache_get_value_name(row, "required_skill", skillStr, sizeof(skillStr));
        cache_get_value_name_int(row, "min_skill_level", minSkill);
        cache_get_value_name_int(row, "craft_time_sec", craftTime);

        new const recipeSlot = Internal_AddRecipe(
            dbId,
            outputItemId,
            outputAmount,
            Internal_ParseStationType(stationStr),
            Skills_FindByColumnName(skillStr),
            minSkill,
            craftTime);

        if (recipeSlot != INVALID_CRAFT_RECIPE_SLOT)
        {
            loadedRecipes++;
        }
    }
    cache_delete(recipeCache);

    // Загрузка входных ингредиентов
    new const Cache:inputCache = mysql_query(gMySQL,
        "SELECT `recipe_id`, `input_item_id`, `input_amount` FROM `craft_recipe_inputs` ORDER BY `recipe_id` ASC;",
        true);

    if (cache_is_valid(inputCache))
    {
        new inputRows = 0;
        cache_get_row_count(inputRows);

        for (new row = 0; row < inputRows; row++)
        {
            new recipeDbId, inputItemId, inputAmount;
            cache_get_value_name_int(row, "recipe_id", recipeDbId);
            cache_get_value_name_int(row, "input_item_id", inputItemId);
            cache_get_value_name_int(row, "input_amount", inputAmount);

            foreach (new recipeSlot : RecipeIter)
            {
                if (sRecipes[recipeSlot][E_RECIPE_DB_ID] == recipeDbId)
                {
                    Internal_AddRecipeInput(recipeSlot, inputItemId, inputAmount);
                    break;
                }
            }
        }
        cache_delete(inputCache);
    }

    printf("%s [Systems/Crafting] Crafting recipes loaded from MySQL (recipes: %d).",
        SERVER_LOG_PREFIX, loadedRecipes);
    return loadedRecipes;
}

// =============================================================================
//  5. ПУБЛИЧНЫЙ API РЕЕСТРА ПРЕДПРИЯТИЙ (Enterprise_*)
// =============================================================================

stock bool:Enterprise_IsValid(enterprise_id)
{
    return (enterprise_id >= 0 && enterprise_id < MAX_ENTERPRISES &&
            sEnterprises[enterprise_id][E_ENT_VALID]);
}

stock Enterprise_GetDbId(enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return 0;
    }
    return sEnterprises[enterprise_id][E_ENT_DB_ID];
}

stock Enterprise_FindByDbId(db_enterprise_id)
{
    if (db_enterprise_id <= 0)
    {
        return INVALID_ENTERPRISE_ID;
    }
    foreach (new enterpriseId : EnterpriseIter)
    {
        if (sEnterprises[enterpriseId][E_ENT_VALID] &&
            sEnterprises[enterpriseId][E_ENT_DB_ID] == db_enterprise_id)
        {
            return enterpriseId;
        }
    }
    return INVALID_ENTERPRISE_ID;
}

stock Enterprise_GetName(enterprise_id, output[], len = sizeof(output))
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        output[0] = '\0';
        return 0;
    }
    format(output, len, "%s", sEnterprises[enterprise_id][E_ENT_NAME]);
    return 1;
}

stock E_ENTERPRISE_TYPE:Enterprise_GetType(enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return ENTERPRISE_NONE;
    }
    return sEnterprises[enterprise_id][E_ENT_TYPE];
}

stock E_ENTERPRISE_OWNERSHIP:Enterprise_GetOwnership(enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return ENTERPRISE_OWN_UNOWNED;
    }
    return sEnterprises[enterprise_id][E_ENT_OWNERSHIP];
}

stock Enterprise_GetOwnerCharId(enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return 0;
    }
    return sEnterprises[enterprise_id][E_ENT_OWNER_CHAR_ID];
}

stock Enterprise_GetWarehouseDbId(enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return 0;
    }
    return sEnterprises[enterprise_id][E_ENT_WAREHOUSE_DB_ID];
}

stock Enterprise_GetWarehouseSlot(enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return INVALID_STORAGE_SLOT;
    }

    new slotId = sEnterprises[enterprise_id][E_ENT_WAREHOUSE_SLOT];
    if (Storage_IsValidSlot(slotId))
    {
        return slotId;
    }

    slotId = Storage_FindByDbId(sEnterprises[enterprise_id][E_ENT_WAREHOUSE_DB_ID]);
    if (slotId == INVALID_STORAGE_SLOT && DB_IsConnected())
    {
        slotId = Storage_Load(
            sEnterprises[enterprise_id][E_ENT_WAREHOUSE_DB_ID],
            STORAGE_ENTERPRISE_WAREHOUSE,
            Enterprise_GetDbId(enterprise_id),
            100000000,
            100000000);
    }

    sEnterprises[enterprise_id][E_ENT_WAREHOUSE_SLOT] = slotId;
    return slotId;
}

stock Enterprise_GetReserve(enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return 0;
    }
    return sEnterprises[enterprise_id][E_ENT_RESERVE_USD];
}

// Административная выдача предприятия игроку (Фаза 10). Проверка RBAC — в mod_admin.
stock bool:Enterprise_AdminAssignByDbId(db_enterprise_id, owner_char_id)
{
    new const slot = Enterprise_FindByDbId(db_enterprise_id);
    if (slot == INVALID_ENTERPRISE_ID || owner_char_id <= 0)
    {
        return false;
    }

    sEnterprises[slot][E_ENT_OWNERSHIP] = ENTERPRISE_OWN_PRIVATE;
    sEnterprises[slot][E_ENT_OWNER_CHAR_ID] = owner_char_id;
    sEnterprises[slot][E_ENT_OWNER_ORG_ID] = 0;
    sEnterprises[slot][E_ENT_AUCTION_PRICE_USD] = 0;

    if (DB_IsConnected())
    {
        new query[256];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `enterprises` SET `ownership` = 'PRIVATE', `owner_char_id` = %d, `owner_org_id` = NULL, `auction_price_usd` = NULL WHERE `id` = %d;",
            owner_char_id, db_enterprise_id);
        mysql_tquery(gMySQL, query);
    }
    return true;
}

stock bool:Enterprise_AdminClearByDbId(db_enterprise_id)
{
    new const slot = Enterprise_FindByDbId(db_enterprise_id);
    if (slot == INVALID_ENTERPRISE_ID)
    {
        return false;
    }

    sEnterprises[slot][E_ENT_OWNERSHIP] = ENTERPRISE_OWN_UNOWNED;
    sEnterprises[slot][E_ENT_OWNER_CHAR_ID] = 0;
    sEnterprises[slot][E_ENT_OWNER_ORG_ID] = 0;
    sEnterprises[slot][E_ENT_AUCTION_PRICE_USD] = 0;

    if (DB_IsConnected())
    {
        new query[256];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `enterprises` SET `ownership` = 'UNOWNED', `owner_char_id` = NULL, `owner_org_id` = NULL, `auction_price_usd` = NULL WHERE `id` = %d;",
            db_enterprise_id);
        mysql_tquery(gMySQL, query);
    }
    return true;
}

stock Enterprise_GetNameByDbId(db_enterprise_id, output[], len = sizeof(output))
{
    output[0] = EOS;
    new const slot = Enterprise_FindByDbId(db_enterprise_id);
    if (slot == INVALID_ENTERPRISE_ID)
    {
        return 0;
    }
    return Enterprise_GetName(slot, output, len);
}

stock Enterprise_GetCount()
{
    new count = 0;
    foreach (new slot : EnterpriseIter)
    {
        if (sEnterprises[slot][E_ENT_VALID]) count++;
    }
    return count;
}

stock Enterprise_GetDbIdByIndex(index)
{
    new current = 0;
    foreach (new slot : EnterpriseIter)
    {
        if (!sEnterprises[slot][E_ENT_VALID]) continue;
        if (current == index) return sEnterprises[slot][E_ENT_DB_ID];
        current++;
    }
    return 0;
}

stock Enterprise_AddReserve(enterprise_id, amount)
{
    if (!Enterprise_IsValid(enterprise_id) || amount <= 0)
    {
        return 0;
    }

    sEnterprises[enterprise_id][E_ENT_RESERVE_USD] += amount;

    if (DB_IsConnected())
    {
        new query[192];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `enterprises` SET `reserve_usd` = `reserve_usd` + %d WHERE `id` = %d;",
            amount,
            sEnterprises[enterprise_id][E_ENT_DB_ID]);
        mysql_tquery(gMySQL, query);
    }
    return 1;
}

stock bool:Enterprise_TakeReserve(enterprise_id, amount)
{
    if (!Enterprise_IsValid(enterprise_id) || amount <= 0)
    {
        return false;
    }
    if (sEnterprises[enterprise_id][E_ENT_RESERVE_USD] < amount)
    {
        return false;
    }

    sEnterprises[enterprise_id][E_ENT_RESERVE_USD] -= amount;

    if (DB_IsConnected())
    {
        new query[224];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `enterprises` SET `reserve_usd` = `reserve_usd` - %d WHERE `id` = %d AND `reserve_usd` >= %d;",
            amount,
            sEnterprises[enterprise_id][E_ENT_DB_ID],
            amount);
        mysql_tquery(gMySQL, query);
    }
    return true;
}

stock Enterprise_GetWagePerKg(enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return 0;
    }
    return sEnterprises[enterprise_id][E_ENT_WAGE_PER_KG_USD];
}

stock Enterprise_SetWagePerKg(enterprise_id, wageUsd)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return 0;
    }
    if (wageUsd < 1)
    {
        wageUsd = 1;
    }
    if (wageUsd > 1000)
    {
        wageUsd = 1000;
    }

    sEnterprises[enterprise_id][E_ENT_WAGE_PER_KG_USD] = wageUsd;
    Internal_RefreshEnterpriseLabel(enterprise_id);

    if (DB_IsConnected())
    {
        new query[160];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `enterprises` SET `wage_per_kg_usd` = %d WHERE `id` = %d;",
            wageUsd,
            sEnterprises[enterprise_id][E_ENT_DB_ID]);
        mysql_tquery(gMySQL, query);
    }
    return 1;
}

stock Enterprise_GetAuctionPrice(enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return 0;
    }
    return sEnterprises[enterprise_id][E_ENT_AUCTION_PRICE_USD];
}

stock Enterprise_GetPos(enterprise_id, &Float:x, &Float:y, &Float:z)
{
    x = 0.0;
    y = 0.0;
    z = 0.0;
    if (!Enterprise_IsValid(enterprise_id))
    {
        return 0;
    }
    x = sEnterprises[enterprise_id][E_ENT_POS_X];
    y = sEnterprises[enterprise_id][E_ENT_POS_Y];
    z = sEnterprises[enterprise_id][E_ENT_POS_Z];
    return 1;
}

stock bool:Enterprise_IsOwnedByPlayer(playerid, enterprise_id)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return false;
    }
    if (!Enterprise_IsValid(enterprise_id))
    {
        return false;
    }
    if (Enterprise_GetOwnership(enterprise_id) != ENTERPRISE_OWN_PRIVATE)
    {
        return false;
    }

    new const ownerCharId = Enterprise_GetOwnerCharId(enterprise_id);
    if (ownerCharId > 0)
    {
        return (ownerCharId == Character_GetId(playerid));
    }

    new const ownerOrgId = sEnterprises[enterprise_id][E_ENT_OWNER_ORG_ID];
    if (ownerOrgId > 0)
    {
        return (ownerOrgId == Character_GetOrgId(playerid));
    }
    return false;
}

stock Enterprise_SetPrivateOwner(enterprise_id, owner_char_id)
{
    if (!Enterprise_IsValid(enterprise_id) || owner_char_id <= 0)
    {
        return 0;
    }

    sEnterprises[enterprise_id][E_ENT_OWNERSHIP] = ENTERPRISE_OWN_PRIVATE;
    sEnterprises[enterprise_id][E_ENT_OWNER_CHAR_ID] = owner_char_id;
    sEnterprises[enterprise_id][E_ENT_OWNER_ORG_ID] = 0;
    sEnterprises[enterprise_id][E_ENT_AUCTION_PRICE_USD] = 0;
    Internal_RefreshEnterpriseLabel(enterprise_id);

    if (DB_IsConnected())
    {
        new query[192];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `enterprises` SET `ownership` = 'PRIVATE', `owner_char_id` = %d, `owner_org_id` = NULL, `auction_price_usd` = NULL WHERE `id` = %d AND `ownership` = 'UNOWNED';",
            owner_char_id,
            sEnterprises[enterprise_id][E_ENT_DB_ID]);
        mysql_tquery(gMySQL, query);
    }
    return 1;
}

stock Enterprise_FindNearest(playerid, Float:radius)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !IsPlayerConnected(playerid))
    {
        return INVALID_ENTERPRISE_ID;
    }
    if (GetPlayerInterior(playerid) != 0 || GetPlayerVirtualWorld(playerid) != 0)
    {
        return INVALID_ENTERPRISE_ID;
    }

    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);

    new bestEnterprise = INVALID_ENTERPRISE_ID;
    new Float:bestDistance = radius + 0.001;

    foreach (new enterpriseId : EnterpriseIter)
    {
        if (!sEnterprises[enterpriseId][E_ENT_VALID])
        {
            continue;
        }

        new const Float:dx = px - sEnterprises[enterpriseId][E_ENT_POS_X];
        new const Float:dy = py - sEnterprises[enterpriseId][E_ENT_POS_Y];
        new const Float:dz = pz - sEnterprises[enterpriseId][E_ENT_POS_Z];
        new const Float:distance = floatsqroot((dx * dx) + (dy * dy));

        if (distance <= bestDistance && (dz > -60.0 && dz < 60.0))
        {
            bestDistance = distance;
            bestEnterprise = enterpriseId;
        }
    }
    return bestEnterprise;
}

stock bool:Enterprise_IsPlayerNearWarehouse(playerid, enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return false;
    }
    return Utils_IsPlayerNearPoint(
        playerid,
        ENTERPRISE_DELIVERY_RADIUS,
        sEnterprises[enterprise_id][E_ENT_POS_X],
        sEnterprises[enterprise_id][E_ENT_POS_Y],
        sEnterprises[enterprise_id][E_ENT_POS_Z]);
}

stock Enterprise_GetTypeTitleRu(E_ENTERPRISE_TYPE:type, output[], len = sizeof(output))
{
    return Internal_GetEnterpriseTypeTitleRu(type, output, len);
}

stock Enterprise_GetOwnershipTitleRu(E_ENTERPRISE_OWNERSHIP:ownership, output[], len = sizeof(output))
{
    return Internal_GetOwnershipTitleRu(ownership, output, len);
}

// =============================================================================
//  6. ВНУТРЕННИЕ ФУНКЦИИ ДОБЫЧИ И ПЕРЕДАЧИ СЫРЬЯ (static stock)
// =============================================================================

static stock Internal_MoveItemTreeToStorage(
    playerid,
    storage_slot,
    target_slot,
    def_id,
    max_amount,
    depth = 0)
{
    if (!Storage_IsValidSlot(storage_slot) || !Storage_IsValidSlot(target_slot) ||
        max_amount <= 0 || depth > MAX_NESTING_DEPTH)
    {
        return 0;
    }

    new remaining = max_amount;
    new itemSlot = Storage_GetFirstItemSlot(storage_slot);

    while (itemSlot != INVALID_STORAGE_ITEM_SLOT && remaining > 0)
    {
        new const nextItemSlot = Storage_GetNextItemSlot(itemSlot);
        new const itemDefId = Storage_GetItemDefId(itemSlot);

        if (itemDefId == def_id)
        {
            new const itemAmount = Storage_GetItemAmount(itemSlot);
            new const takeAmount = (itemAmount < remaining) ? itemAmount : remaining;

            if (takeAmount > 0 &&
                Storage_TransferItem(
                    playerid,
                    storage_slot,
                    itemSlot,
                    target_slot,
                    takeAmount,
                    Character_GetId(playerid)) == STORAGE_RES_OK)
            {
                remaining -= takeAmount;
            }
        }
        else
        {
            new const nestedSlot = Storage_GetItemNestedSlot(itemSlot);
            if (Storage_IsValidSlot(nestedSlot) && depth < MAX_NESTING_DEPTH)
            {
                new const movedAmount = Internal_MoveItemTreeToStorage(
                    playerid,
                    nestedSlot,
                    target_slot,
                    def_id,
                    remaining,
                    depth + 1);
                if (movedAmount > 0)
                {
                    remaining -= movedAmount;
                }
            }
        }
        itemSlot = nextItemSlot;
    }

    return (max_amount - remaining);
}

static stock Internal_GetWeaponInitialAmmo(item_def_id)
{
    new const gtaWeaponId = Item_GetGtaWeaponId(item_def_id);
    switch (gtaWeaponId)
    {
        case 22: return 17; // Пистолет 9mm
        case 23: return 17; // Пистолет с глушителем
        case 24: return 7;  // Desert Eagle
        case 25: return 8;  // Помповый дробовик
        case 26: return 2;  // Обрез
        case 27: return 8;  // SPAS-12
        case 28: return 32; // Micro Uzi
        case 29: return 30; // MP5
        case 30: return 30; // AK-47
        case 31: return 30; // M4
        case 32: return 32; // Tec-9
        case 33: return 10; // Охотничья винтовка
        case 34: return 10; // Снайперская винтовка
    }
    return 0;
}

static stock Internal_DropItemsToWorld(
    playerid,
    const itemIds[],
    const amounts[],
    count,
    Float:x,
    Float:y,
    Float:z,
    interior,
    virtualWorld,
    const reason[])
{
    if (count <= 0)
    {
        return 0;
    }

    new const dropSlot = Storage_CreateWorldDrop(x, y, z, interior, virtualWorld, itemIds[0]);
    if (dropSlot == INVALID_STORAGE_SLOT)
    {
        printf("%s [Systems/Crafting] [ERROR] Failed to create WORLD_DROP to return items (%s).",
            SERVER_LOG_PREFIX, reason);
        return 0;
    }

    new droppedCount = 0;
    for (new i = 0; i < count; i++)
    {
        if (itemIds[i] <= 0 || amounts[i] <= 0)
        {
            continue;
        }
        if (itemIds[i] == ITEM_ID_CASH_BUNDLE)
        {
            new remainingCash = amounts[i];
            while (remainingCash > 0)
            {
                new const chunk = (remainingCash > 10000) ? 10000 : remainingCash;
                new outCashSlot = INVALID_STORAGE_ITEM_SLOT;
                if (Storage_AddItem(dropSlot, ITEM_ID_CASH_BUNDLE, chunk, 0, 100.0, 0, 0, "", outCashSlot) != STORAGE_RES_OK)
                {
                    break;
                }
                remainingCash -= chunk;
            }
            droppedCount++;
        }
        else
        {
            new outItemSlot = INVALID_STORAGE_ITEM_SLOT;
            if (Storage_AddItem(dropSlot, itemIds[i], amounts[i], 0, 100.0, 0, 0, "", outItemSlot) == STORAGE_RES_OK)
            {
                droppedCount++;
            }
        }
    }

    if (playerid >= 0 && playerid < MAX_PLAYERS && IsPlayerConnected(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "Items have been returned to the ground near you: continue working or pick them up.");
    }
    return droppedCount;
}

static stock Internal_ClearCraftJob(playerid)
{
    sCraftJob[playerid][E_JOB_ACTIVE] = false;
    sCraftJob[playerid][E_JOB_TOKEN] = 0;
    sCraftJob[playerid][E_JOB_RECIPE_SLOT] = INVALID_CRAFT_RECIPE_SLOT;
    sCraftJob[playerid][E_JOB_OUTPUT_AMOUNT] = 0;
    sCraftJob[playerid][E_JOB_INPUT_COUNT] = 0;
    for (new i = 0; i < CRAFT_JOB_MAX_INPUTS; i++)
    {
        sCraftJob[playerid][E_JOB_INPUT_ITEM_ID][i] = 0;
        sCraftJob[playerid][E_JOB_INPUT_AMOUNT][i] = 0;
    }
}

static stock Internal_RefundCraftJob(playerid)
{
    if (!sCraftJob[playerid][E_JOB_ACTIVE])
    {
        return 0;
    }

    new itemIds[CRAFT_JOB_MAX_INPUTS];
    new amounts[CRAFT_JOB_MAX_INPUTS];
    new count = sCraftJob[playerid][E_JOB_INPUT_COUNT];

    for (new i = 0; i < count && i < CRAFT_JOB_MAX_INPUTS; i++)
    {
        itemIds[i] = sCraftJob[playerid][E_JOB_INPUT_ITEM_ID][i];
        amounts[i] = sCraftJob[playerid][E_JOB_INPUT_AMOUNT][i];
    }

    new const Float:x = sCraftJob[playerid][E_JOB_POS_X];
    new const Float:y = sCraftJob[playerid][E_JOB_POS_Y];
    new const Float:z = sCraftJob[playerid][E_JOB_POS_Z];
    new const interior = sCraftJob[playerid][E_JOB_INTERIOR];
    new const virtualWorld = sCraftJob[playerid][E_JOB_VW];

    Internal_ClearCraftJob(playerid);

    return Internal_DropItemsToWorld(
        playerid, itemIds, amounts, count, x, y, z, interior, virtualWorld,
        "return of interrupted crafting ingredients");
}

// =============================================================================
//  7. АСИНХРОННОЕ ЗАВЕРШЕНИЕ КРАФТА (forward / public)
// =============================================================================

forward OnCraftingJobComplete(playerid, token);
public OnCraftingJobComplete(playerid, token)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    if (!sCraftJob[playerid][E_JOB_ACTIVE] || sCraftJob[playerid][E_JOB_TOKEN] != token)
    {
        return 0;
    }

    new const recipeSlot = sCraftJob[playerid][E_JOB_RECIPE_SLOT];
    new const outputAmount = sCraftJob[playerid][E_JOB_OUTPUT_AMOUNT];
    new const Float:x = sCraftJob[playerid][E_JOB_POS_X];
    new const Float:y = sCraftJob[playerid][E_JOB_POS_Y];
    new const Float:z = sCraftJob[playerid][E_JOB_POS_Z];
    new const interior = sCraftJob[playerid][E_JOB_INTERIOR];
    new const virtualWorld = sCraftJob[playerid][E_JOB_VW];

    if (recipeSlot < 0 || recipeSlot >= MAX_CRAFT_RECIPES || !sRecipes[recipeSlot][E_RECIPE_VALID])
    {
        Internal_RefundCraftJob(playerid);
        return 0;
    }

    if (!IsPlayerConnected(playerid) ||
        !Config_ValidatePlayerToken(playerid, sCraftJob[playerid][E_JOB_TOKEN]) ||
        !Character_IsLoaded(playerid))
    {
        Internal_RefundCraftJob(playerid);
        return 0;
    }

    new const outputItemId = sRecipes[recipeSlot][E_RECIPE_OUTPUT_ITEM_ID];
    new const outputItemAmount = (outputAmount > 0) ? outputAmount : sRecipes[recipeSlot][E_RECIPE_OUTPUT_AMOUNT];
    new const layer1Slot = Character_GetLayer1Slot(playerid);

    new outItemSlot = INVALID_STORAGE_ITEM_SLOT;
    new bool:delivered = false;
    new weaponSerial = 0;
    if (Item_GetGtaWeaponId(outputItemId) >= 22)
    {
        weaponSerial = Utils_GenerateWeaponSerial();
    }

    if (Storage_IsValidSlot(layer1Slot))
    {
        new const E_STORAGE_RESULT:result = Storage_AddItem(
            layer1Slot,
            outputItemId,
            outputItemAmount,
            Internal_GetWeaponInitialAmmo(outputItemId),
            100.0,
            0,
            weaponSerial,
            "",
            outItemSlot);
        delivered = (result == STORAGE_RES_OK);
    }

    if (!delivered)
    {
        new itemIds[1];
        new amounts[1];
        itemIds[0] = outputItemId;
        amounts[0] = outputItemAmount;
        Internal_DropItemsToWorld(
            playerid, itemIds, amounts, 1, x, y, z, interior, virtualWorld,
            "Inventory overflow when crafting is completed");
    }

    new itemName[64];
    Item_GetName(outputItemId, itemName);

    if (delivered)
    {
        new msg[160];
        format(msg, sizeof(msg), "[Production]: Ready: %s (Quantity: %d). The item has been added to inventory.",
            itemName, outputItemAmount);
        SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    }
    else
    {
        new msg[160];
        format(msg, sizeof(msg), "[Production]: Ready: %s (Quantity: %d). The inventory is full, the item is thrown to the ground.",
            itemName, outputItemAmount);
        SendClientMessage(playerid, COLOR_UI_WARNING, msg);
    }

    // Прокачка профильного навыка
    new const E_SKILL_TYPE:skillType = sRecipes[recipeSlot][E_RECIPE_SKILL];
    if (skillType >= SKILL_MELEE_BLUNT && skillType < MAX_SKILL_TYPES)
    {
        Skills_Add(playerid, skillType, 3);
    }

    new auditDetails[160];
    format(auditDetails, sizeof(auditDetails),
        "Craft the item '%s' (quantity: %d) at the workbench. Recipe #%d.",
        itemName, outputItemAmount, sRecipes[recipeSlot][E_RECIPE_DB_ID]);
    Audit_Log(
        Character_GetId(playerid),
        "CRAFT",
        "WORKBENCH",
        "PLAYER_LAYER1",
        outputItemId,
        outputItemAmount,
        auditDetails);

    Internal_ClearCraftJob(playerid);
    return 1;
}

// =============================================================================
//  8. КОМАНДЫ ДОБЫЧИ, СДАЧИ СЫРЬЯ И КРАФТА (Pawn.CMD)
// =============================================================================

CMD:mine(playerid, params[])
{
    #pragma unused params

    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Loot]: Your character has not yet been loaded.");
        return 1;
    }
    if (!Character_IsAlive(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Loot]: A dead character cannot work.");
        return 1;
    }
    if (IsPlayerInAnyVehicle(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Loot]: Get out of the vehicle to work.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sLastMiningTick[playerid]) < CRAFT_MINING_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Production]: The tool is cooling down. Wait a few seconds.");
        return 1;
    }

    new const enterpriseId = Enterprise_FindNearest(playerid, ENTERPRISE_WORK_RADIUS);
    if (enterpriseId == INVALID_ENTERPRISE_ID)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Mining]: Approach a mine, oil rig, sawmill or farm.");
        return 1;
    }

    new const E_ENTERPRISE_TYPE:type = Enterprise_GetType(enterpriseId);
    if (!Internal_IsPrimaryEnterpriseType(type))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Extraction]: Primary extraction of raw materials is not carried out here.");
        return 1;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Loot]: Inventory unavailable.");
        return 1;
    }

    new const requiredSkill = Internal_GetExtractionSkillRequirement(type);
    new const playerSkill = Skills_Get(playerid, SKILL_MINING_LOGGING);
    if (playerSkill < requiredSkill)
    {
        new msg[160];
        format(msg, sizeof(msg),
            "[Mining]: Insufficient mining and logging skill: required %d, you have %d.",
            requiredSkill, playerSkill);
        SendClientMessage(playerid, COLOR_UI_ERROR, msg);
        return 1;
    }

    new const requiredTool = Internal_GetRequiredToolItem(type);
    if (requiredTool > 0 && Storage_CountItemInTree(layer1Slot, requiredTool) <= 0)
    {
        new toolName[64];
        Item_GetName(requiredTool, toolName);
        new msg[160];
        format(msg, sizeof(msg), "[Extraction]: To work you need a tool: %s.", toolName);
        SendClientMessage(playerid, COLOR_UI_ERROR, msg);
        return 1;
    }

    new const resourceItemId = Internal_GetPrimaryResourceItem(type);
    if (resourceItemId <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Extraction]: There is no resource available at this facility.");
        return 1;
    }

    new baseYield = 5 + (playerSkill / 200);
    if (Roles_HasPerk(Character_GetRoleId(playerid), PERK_MINING_YIELD_35))
    {
        baseYield = (baseYield * 135) / 100;
    }
    if (baseYield < 1)
    {
        baseYield = 1;
    }

    new outItemSlot = INVALID_STORAGE_ITEM_SLOT;
    new const E_STORAGE_RESULT:addResult = Storage_AddItem(
        layer1Slot,
        resourceItemId,
        baseYield,
        0,
        100.0,
        0,
        0,
        "",
        outItemSlot);

    if (addResult != STORAGE_RES_OK)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Loot]: Inventory is full. Free up space or put raw materials into storage.");
        return 1;
    }

    sLastMiningTick[playerid] = nowTick;
    Skills_Add(playerid, SKILL_MINING_LOGGING, 4);

    new itemName[64], weightStr[32], msg[192];
    Item_GetName(resourceItemId, itemName);
    Utils_FormatWeightGrams(Item_CalculateInstanceWeight(resourceItemId, baseYield), weightStr);
    format(msg, sizeof(msg),
        "[Loot]: You have mined %s (quantity: %d, weight: %s). Skill: %d.",
        itemName, baseYield, weightStr, Skills_Get(playerid, SKILL_MINING_LOGGING));
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    return 1;
}
alias:mine("work");

CMD:deliver(playerid, params[])
{
    #pragma unused params

    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Warehouse]: Your character has not yet been loaded.");
        return 1;
    }
    if (!Character_IsAlive(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Warehouse]: A dead character cannot donate raw materials.");
        return 1;
    }

    new const enterpriseId = Enterprise_FindNearest(playerid, ENTERPRISE_DELIVERY_RADIUS);
    if (enterpriseId == INVALID_ENTERPRISE_ID)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Warehouse]: Go close to the company's warehouse to hand over raw materials.");
        return 1;
    }

    new const E_ENTERPRISE_TYPE:type = Enterprise_GetType(enterpriseId);
    if (!Internal_IsPrimaryEnterpriseType(type))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Warehouse]: This company does not accept primary raw materials on a piece rate basis.");
        return 1;
    }

    new const warehouseSlot = Enterprise_GetWarehouseSlot(enterpriseId);
    if (!Storage_IsValidSlot(warehouseSlot) || !Storage_AreItemsReady(warehouseSlot))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Warehouse]: The company's warehouse is still loading. Repeat in a second.");
        return 1;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Warehouse]: Inventory unavailable.");
        return 1;
    }

    new const resourceItemId = Internal_GetPrimaryResourceItem(type);
    new const availableAmount = Storage_CountItemInTree(layer1Slot, resourceItemId);
    if (resourceItemId <= 0 || availableAmount <= 0)
    {
        new itemName[64];
        Item_GetName(resourceItemId, itemName);
        new msg[160];
        format(msg, sizeof(msg), "[Warehouse]: You do not have products from this company (%s).", itemName);
        SendClientMessage(playerid, COLOR_UI_ERROR, msg);
        return 1;
    }

    new const deliveredWeightG = Item_CalculateInstanceWeight(resourceItemId, availableAmount);
    new const wagePerKg = Enterprise_GetWagePerKg(enterpriseId);
    new const payoutUsd = (deliveredWeightG * wagePerKg) / 1000;

    if (payoutUsd <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Warehouse]: The lot is too small to pay out. Get more raw materials.");
        return 1;
    }

    if (Enterprise_GetReserve(enterpriseId) < payoutUsd)
    {
        new msg[192];
        format(msg, sizeof(msg),
            "[Warehouse]: There are not enough funds in the company's cash register. $%d required, $%d available.",
            payoutUsd, Enterprise_GetReserve(enterpriseId));
        SendClientMessage(playerid, COLOR_UI_ERROR, msg);
        return 1;
    }

    // Проверка места под наличные с учетом выгрузки сырья
    new const cashWeightG = Item_CalculateInstanceWeight(ITEM_ID_CASH_BUNDLE, payoutUsd);
    new const cashVolumeMl = Item_CalculateInstanceVolume(ITEM_ID_CASH_BUNDLE, payoutUsd);
    new const finalWeightG = Storage_GetCurrentWeight(layer1Slot) - deliveredWeightG + cashWeightG;
    new const finalVolumeMl = Storage_GetCurrentVolume(layer1Slot) -
        Item_CalculateInstanceVolume(resourceItemId, availableAmount) + cashVolumeMl;

    if (finalWeightG > Storage_GetMaxWeight(layer1Slot) ||
        finalVolumeMl > Storage_GetMaxVolume(layer1Slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Warehouse]: After payment, cash will not be placed in inventory. Submit a smaller batch.");
        return 1;
    }

    new const movedAmount = Internal_MoveItemTreeToStorage(
        playerid,
        layer1Slot,
        warehouseSlot,
        resourceItemId,
        availableAmount);

    if (movedAmount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Warehouse]: Failed to move raw materials to warehouse. Try again.");
        return 1;
    }

    new const actualWeightG = Item_CalculateInstanceWeight(resourceItemId, movedAmount);
    new actualPayoutUsd = (actualWeightG * wagePerKg) / 1000;
    if (actualPayoutUsd > Enterprise_GetReserve(enterpriseId))
    {
        actualPayoutUsd = Enterprise_GetReserve(enterpriseId);
    }

    if (actualPayoutUsd > 0)
    {
        if (!Character_AddPhysicalCashUsd(playerid, actualPayoutUsd, CASH_FLAG_CLEAN))
        {
            new Float:px, Float:py, Float:pz;
            GetPlayerPos(playerid, px, py, pz);
            new cashIds[1];
            new cashAmounts[1];
            cashIds[0] = ITEM_ID_CASH_BUNDLE;
            cashAmounts[0] = actualPayoutUsd;
            Internal_DropItemsToWorld(
                playerid, cashIds, cashAmounts, 1, px, py, pz,
                GetPlayerInterior(playerid), GetPlayerVirtualWorld(playerid),
                "salary payment in cash");
            SendClientMessage(playerid, COLOR_UI_WARNING,
                "[Warehouse]: Cash did not fit into inventory and was issued in a separate stack on the ground.");
        }
        Enterprise_TakeReserve(enterpriseId, actualPayoutUsd);
    }

    Skills_Add(playerid, SKILL_MINING_LOGGING, 2);

    new itemName[64], weightStr[32], msg[224];
    Item_GetName(resourceItemId, itemName);
    Utils_FormatWeightGrams(actualWeightG, weightStr);
    format(msg, sizeof(msg),
        "[Stock]: Accepted %s: %d pcs. (%s). $%d was accrued from the company's cash register.",
        itemName, movedAmount, weightStr, actualPayoutUsd);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new auditDetails[192];
    format(auditDetails, sizeof(auditDetails),
        "Delivery of raw materials '%s' (quantity: %d, weight: %d g) to the warehouse of the enterprise #%d. Payout: $%d.",
        itemName, movedAmount, actualWeightG, Enterprise_GetDbId(enterpriseId), actualPayoutUsd);
    Audit_Log(
        Character_GetId(playerid),
        "RAW_DELIVERY",
        "PLAYER_LAYER1",
        "ENTERPRISE_WAREHOUSE",
        resourceItemId,
        movedAmount,
        auditDetails);
    return 1;
}

CMD:craft(playerid, params[])
{
    #pragma unused params

    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Crafting]: Your character has not yet been loaded.");
        return 1;
    }
    if (!Character_IsAlive(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Crafting]: A dead character cannot work at a workbench.");
        return 1;
    }
    if (IsPlayerInAnyVehicle(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Crafting]: Get out of the vehicle to work at the workbench.");
        return 1;
    }
    if (sCraftJob[playerid][E_JOB_ACTIVE])
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Crafting]: You are already completing a production order.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sLastCraftCommandTick[playerid]) < CRAFT_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Craft]: Not so fast. Wait a moment.");
        return 1;
    }
    sLastCraftCommandTick[playerid] = nowTick;

    new const enterpriseId = Enterprise_FindNearest(playerid, ENTERPRISE_WORK_RADIUS);
    if (enterpriseId == INVALID_ENTERPRISE_ID)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Crafting]: Go to a factory, metallurgy, refinery or auto dismantling station.");
        return 1;
    }

    new const E_ENTERPRISE_TYPE:enterpriseType = Enterprise_GetType(enterpriseId);

    new rowLine[256];
    new outputName[64];
    new stationTitle[32];
    new skillName[48];
    new skillValue, requiredSkill, timeSec;

    sCraftDialogBuffer[0] = '\0';
    sCraftDialogRecipeCount[playerid] = 0;

    new const layer1Slot = Character_GetLayer1Slot(playerid);

    foreach (new recipeSlot : RecipeIter)
    {
        if (!sRecipes[recipeSlot][E_RECIPE_VALID])
        {
            continue;
        }

        new const E_CRAFT_STATION:recipeStation = sRecipes[recipeSlot][E_RECIPE_STATION];
        if (!Internal_IsStationAllowedForEnterprise(enterpriseType, recipeStation))
        {
            continue;
        }

        if (sCraftDialogRecipeCount[playerid] >= MAX_VISIBLE_CRAFT_RECIPES)
        {
            break;
        }

        requiredSkill = sRecipes[recipeSlot][E_RECIPE_MIN_SKILL_LEVEL];
        skillValue = 0;
        if (sRecipes[recipeSlot][E_RECIPE_SKILL] >= SKILL_MELEE_BLUNT &&
            sRecipes[recipeSlot][E_RECIPE_SKILL] < MAX_SKILL_TYPES)
        {
            skillValue = Skills_Get(playerid, sRecipes[recipeSlot][E_RECIPE_SKILL]);
            Skills_GetNameRu(sRecipes[recipeSlot][E_RECIPE_SKILL], skillName, sizeof(skillName));
        }
        else
        {
            format(skillName, sizeof(skillName), "Without skill");
        }

        Item_GetName(sRecipes[recipeSlot][E_RECIPE_OUTPUT_ITEM_ID], outputName);
        Internal_GetStationTitleRu(recipeStation, stationTitle, sizeof(stationTitle));
        timeSec = sRecipes[recipeSlot][E_RECIPE_TIME_SEC];

        new const bool:skillOk = (skillValue >= requiredSkill);
        new inputSummary[160];
        inputSummary[0] = '\0';

        for (new inputIdx = 0; inputIdx < sRecipes[recipeSlot][E_RECIPE_INPUT_COUNT]; inputIdx++)
        {
            new inputItemName[64];
            Item_GetName(sRecipes[recipeSlot][E_RECIPE_INPUT_ITEM_ID][inputIdx], inputItemName);
            new const haveAmount = Storage_CountItemInTree(
                layer1Slot, sRecipes[recipeSlot][E_RECIPE_INPUT_ITEM_ID][inputIdx]);
            new part[96];
            format(part, sizeof(part), "%s %d/%d; ",
                inputItemName,
                haveAmount,
                sRecipes[recipeSlot][E_RECIPE_INPUT_AMOUNT][inputIdx]);
            strcat(inputSummary, part, sizeof(inputSummary));
        }

        format(rowLine, sizeof(rowLine),
            "%s%s | %s | %d sec | %s %d/%d | raw material: %s",
            skillOk ? ("") : ("[UNAVAILABLE]"),
            outputName,
            stationTitle,
            timeSec,
            skillName,
            skillValue,
            requiredSkill,
            inputSummary);

        strcat(sCraftDialogBuffer, rowLine, sizeof(sCraftDialogBuffer));
        strcat(sCraftDialogBuffer, "\n", sizeof(sCraftDialogBuffer));
        sCraftDialogRecipeMap[playerid][sCraftDialogRecipeCount[playerid]++] = recipeSlot;
    }

    if (sCraftDialogRecipeCount[playerid] <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Crafting]: There are no recipes available for this craft.");
        return 1;
    }

    new title[96];
    new enterpriseName[64];
    Enterprise_GetName(enterpriseId, enterpriseName);
    format(title, sizeof(title), "Production: %s", enterpriseName);
    ShowPlayerDialog(
        playerid,
        DIALOG_CRAFT_RECIPES,
        DIALOG_STYLE_LIST,
        title,
        sCraftDialogBuffer,
        "Make",
        "Close");
    return 1;
}

// =============================================================================
//  9. ОБРАБОТКА ДИАЛОГОВ КРАФТА
// =============================================================================

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid != DIALOG_CRAFT_RECIPES)
    {
        return Y_HOOKS_CONTINUE_RETURN_0;
    }
    if (!Character_IsAlive(playerid))
    {
        return Y_HOOKS_BREAK_RETURN_1;
    }

    #pragma unused inputtext

    if (!response)
    {
        return Y_HOOKS_BREAK_RETURN_1;
    }
    if (!Character_IsLoaded(playerid) || IsPlayerInAnyVehicle(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Crafting]: Action not available.");
        return Y_HOOKS_BREAK_RETURN_1;
    }
    if (listitem < 0 || listitem >= sCraftDialogRecipeCount[playerid] ||
        listitem >= MAX_VISIBLE_CRAFT_RECIPES)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Crafting]: Incorrect recipe selection.");
        return Y_HOOKS_BREAK_RETURN_1;
    }

    new const recipeSlot = sCraftDialogRecipeMap[playerid][listitem];
    if (recipeSlot < 0 || recipeSlot >= MAX_CRAFT_RECIPES || !sRecipes[recipeSlot][E_RECIPE_VALID])
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Craft]: Recipe not found.");
        return Y_HOOKS_BREAK_RETURN_1;
    }

    new const enterpriseId = Enterprise_FindNearest(playerid, ENTERPRISE_WORK_RADIUS);
    if (enterpriseId == INVALID_ENTERPRISE_ID ||
        !Internal_IsStationAllowedForEnterprise(
            Enterprise_GetType(enterpriseId),
            sRecipes[recipeSlot][E_RECIPE_STATION]))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Crafting]: You have moved away from the workbench or this workshop does not fulfill the selected recipe.");
        return Y_HOOKS_BREAK_RETURN_1;
    }

    if (sCraftJob[playerid][E_JOB_ACTIVE])
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Crafting]: You are already completing a production order.");
        return Y_HOOKS_BREAK_RETURN_1;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Crafting]: Inventory not available.");
        return Y_HOOKS_BREAK_RETURN_1;
    }

    new const E_SKILL_TYPE:skillType = sRecipes[recipeSlot][E_RECIPE_SKILL];
    new const skillValue = (skillType >= SKILL_MELEE_BLUNT && skillType < MAX_SKILL_TYPES)
        ? Skills_Get(playerid, skillType)
        : 0;

    if (skillValue < sRecipes[recipeSlot][E_RECIPE_MIN_SKILL_LEVEL])
    {
        new msg[192];
        format(msg, sizeof(msg),
            "[Crafting]: Insufficient skill: required %d, you have %d.",
            sRecipes[recipeSlot][E_RECIPE_MIN_SKILL_LEVEL], skillValue);
        SendClientMessage(playerid, COLOR_UI_ERROR, msg);
        return Y_HOOKS_BREAK_RETURN_1;
    }

    // Проверка и расчет входных ингредиентов с перком оружейника
    new requiredAmounts[MAX_CRAFT_RECIPE_INPUTS];
    new const bool:hasGunsmithPerk = Roles_HasPerk(Character_GetRoleId(playerid), PERK_FIELD_GUNSMITH);

    for (new i = 0; i < sRecipes[recipeSlot][E_RECIPE_INPUT_COUNT]; i++)
    {
        new needed = sRecipes[recipeSlot][E_RECIPE_INPUT_AMOUNT][i];
        if (hasGunsmithPerk && sRecipes[recipeSlot][E_RECIPE_STATION] == CRAFT_STATION_WORKBENCH_WEAPON)
        {
            needed = ((needed * 3) + 3) / 4;
            if (needed < 1)
            {
                needed = 1;
            }
        }
        requiredAmounts[i] = needed;

        new const haveAmount = Storage_CountItemInTree(
            layer1Slot, sRecipes[recipeSlot][E_RECIPE_INPUT_ITEM_ID][i]);
        if (haveAmount < needed)
        {
            new itemName[64];
            Item_GetName(sRecipes[recipeSlot][E_RECIPE_INPUT_ITEM_ID][i], itemName);
            new msg[192];
            format(msg, sizeof(msg),
                "[Crafting]: Not enough raw materials: %s (need %d, have %d).",
                itemName, needed, haveAmount);
            SendClientMessage(playerid, COLOR_UI_ERROR, msg);
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }

    new const bool:layer1WasLocked = Storage_IsMutexLocked(layer1Slot);
    if (!Storage_AcquireMutex(layer1Slot, playerid))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Crafting]: Inventory is occupied by another action. Close the inventory window and repeat.");
        return Y_HOOKS_BREAK_RETURN_1;
    }

    new consumedAmounts[MAX_CRAFT_RECIPE_INPUTS];
    new bool:consumeFailed = false;

    for (new i = 0; i < sRecipes[recipeSlot][E_RECIPE_INPUT_COUNT]; i++)
    {
        new const consumed = Storage_RemoveItemInTree(
            layer1Slot, sRecipes[recipeSlot][E_RECIPE_INPUT_ITEM_ID][i], requiredAmounts[i]);
        consumedAmounts[i] = consumed;
        if (consumed < requiredAmounts[i])
        {
            consumeFailed = true;
            break;
        }
    }

    if (consumeFailed)
    {
        // Возврат уже списанных ингредиентов в инвентарь
        for (new i = 0; i < sRecipes[recipeSlot][E_RECIPE_INPUT_COUNT]; i++)
        {
            if (consumedAmounts[i] <= 0)
            {
                continue;
            }
            new outItemSlot = INVALID_STORAGE_ITEM_SLOT;
            Storage_AddItem(
                layer1Slot,
                sRecipes[recipeSlot][E_RECIPE_INPUT_ITEM_ID][i],
                consumedAmounts[i],
                0, 100.0, 0, 0, "", outItemSlot);
        }

        if (!layer1WasLocked)
        {
            Storage_ReleaseMutex(layer1Slot);
        }
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Craft]: Failed to write off raw materials. The operation was cancelled, the ingredients were returned.");
        return Y_HOOKS_BREAK_RETURN_1;
    }

    if (!layer1WasLocked)
    {
        Storage_ReleaseMutex(layer1Slot);
    }

    // Формирование задания и запуск таймера производства
    Internal_ClearCraftJob(playerid);
    sCraftJob[playerid][E_JOB_ACTIVE] = true;
    sCraftJob[playerid][E_JOB_TOKEN] = Config_GetPlayerSessionToken(playerid);
    sCraftJob[playerid][E_JOB_RECIPE_SLOT] = recipeSlot;
    sCraftJob[playerid][E_JOB_INPUT_COUNT] = sRecipes[recipeSlot][E_RECIPE_INPUT_COUNT];

    for (new i = 0; i < sRecipes[recipeSlot][E_RECIPE_INPUT_COUNT]; i++)
    {
        sCraftJob[playerid][E_JOB_INPUT_ITEM_ID][i] = sRecipes[recipeSlot][E_RECIPE_INPUT_ITEM_ID][i];
        sCraftJob[playerid][E_JOB_INPUT_AMOUNT][i] = requiredAmounts[i];
    }

    new outputAmount = sRecipes[recipeSlot][E_RECIPE_OUTPUT_AMOUNT];
    if (sRecipes[recipeSlot][E_RECIPE_STATION] == CRAFT_STATION_WORKBENCH_CHEM &&
        Roles_HasPerk(Character_GetRoleId(playerid), PERK_CHEM_YIELD_40))
    {
        outputAmount = (outputAmount * 140) / 100;
        if (outputAmount < 1)
        {
            outputAmount = 1;
        }
    }
    sCraftJob[playerid][E_JOB_OUTPUT_AMOUNT] = outputAmount;

    GetPlayerPos(
        playerid,
        sCraftJob[playerid][E_JOB_POS_X],
        sCraftJob[playerid][E_JOB_POS_Y],
        sCraftJob[playerid][E_JOB_POS_Z]);
    sCraftJob[playerid][E_JOB_INTERIOR] = GetPlayerInterior(playerid);
    sCraftJob[playerid][E_JOB_VW] = GetPlayerVirtualWorld(playerid);

    new craftTimeSec = sRecipes[recipeSlot][E_RECIPE_TIME_SEC];
    new const speedBonus = skillValue / 10;
    if (speedBonus > 0)
    {
        craftTimeSec = (craftTimeSec * 100) / (100 + speedBonus);
    }
    if (craftTimeSec < 1)
    {
        craftTimeSec = 1;
    }

    new const token = sCraftJob[playerid][E_JOB_TOKEN];
    SetTimerEx("OnCraftingJobComplete", craftTimeSec * 1000, false, "dd", playerid, token);

    new outputName[64], msg[192];
    Item_GetName(sRecipes[recipeSlot][E_RECIPE_OUTPUT_ITEM_ID], outputName);
    format(msg, sizeof(msg),
        "[Crafting]: Order started: %s (quantity: %d). Production time: %d sec.",
        outputName, outputAmount, craftTimeSec);
    SendClientMessage(playerid, COLOR_UI_INFO, msg);
    return Y_HOOKS_BREAK_RETURN_1;
}

// =============================================================================
//  9.1. МОСТЫ ДЛЯ MOD_VEHICLES (АЗС И ШРОТЫ)
// =============================================================================

public bool:Vehicles_FindGasStation(playerid, &enterprise_slot, &warehouse_slot)
{
    enterprise_slot = INVALID_ENTERPRISE_ID;
    warehouse_slot = INVALID_STORAGE_SLOT;

    new const ent = Enterprise_FindNearest(playerid, 10.0);
    if (ent == INVALID_ENTERPRISE_ID)
    {
        return false;
    }
    if (Enterprise_GetType(ent) != ENTERPRISE_GAS_STATION)
    {
        return false;
    }

    enterprise_slot = ent;
    warehouse_slot = Enterprise_GetWarehouseSlot(ent);
    return true;
}

public bool:Vehicles_FindChopShop(playerid, Float:radius, &enterprise_slot, &warehouse_slot)
{
    enterprise_slot = INVALID_ENTERPRISE_ID;
    warehouse_slot = INVALID_STORAGE_SLOT;

    new const ent = Enterprise_FindNearest(playerid, radius);
    if (ent == INVALID_ENTERPRISE_ID)
    {
        return false;
    }
    if (Enterprise_GetType(ent) != ENTERPRISE_CHOP_SHOP)
    {
        return false;
    }

    enterprise_slot = ent;
    warehouse_slot = Enterprise_GetWarehouseSlot(ent);
    return true;
}

// =============================================================================
// 10. СИСТЕМНЫЕ ХУКИ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    new const loadedEnterprises = Internal_LoadEnterprisesSync();
    new const loadedRecipes = Internal_LoadRecipesSync();

    Internal_CreateEnterpriseLabels();

    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        sCraftJob[i][E_JOB_ACTIVE] = false;
        sCraftDialogRecipeCount[i] = 0;
        sLastCraftCommandTick[i] = 0;
        sLastMiningTick[i] = 0;
    }

    printf("%s [Systems/Crafting] Production module launched (enterprises: %d, recipes: %d).",
        SERVER_LOG_PREFIX, loadedEnterprises, loadedRecipes);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason

    if (sCraftJob[playerid][E_JOB_ACTIVE])
    {
        Internal_RefundCraftJob(playerid);
    }

    sCraftDialogRecipeCount[playerid] = 0;
    sLastCraftCommandTick[playerid] = 0;
    sLastMiningTick[playerid] = 0;
    return 1;
}

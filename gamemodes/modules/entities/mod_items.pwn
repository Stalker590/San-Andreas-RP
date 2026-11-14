/*
 * =============================================================================
 *  SAN ANDREAS RP — Реестр определений предметов и физика массы/объема
 *  Файл:      gamemodes/modules/entities/mod_items.pwn
 *  Пункт:     ROADMAP [2.1] — Реестр определений предметов (entities/mod_items.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_items_included
    #endinput
#endif
#define _mod_items_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ И СТРУКТУРЫ ОПРЕДЕЛЕНИЙ ПРЕДМЕТОВ (enum & static stock)
// =============================================================================

#define ITEM_CODE_NAME_LEN                      (48)
#define ITEM_DISPLAY_NAME_LEN                   (64)
#define TOTAL_SEED_ITEM_DEFS                    (91)

enum E_ITEM_DEF
{
    bool:E_ITEM_VALID,
    E_ITEM_ID,
    E_ITEM_CODE_NAME[ITEM_CODE_NAME_LEN],
    E_ITEM_DISPLAY_NAME[ITEM_DISPLAY_NAME_LEN],
    E_ITEM_CATEGORY:E_ITEM_CAT,
    E_ITEM_BASE_WEIGHT_G,
    E_ITEM_BASE_VOLUME_ML,
    bool:E_ITEM_STACKABLE,
    E_ITEM_MAX_STACK,
    E_ITEM_GTA_WEAPON_ID,
    E_ITEM_AMMO_WEIGHT_G,
    E_ITEM_INNER_MAX_WEIGHT_G,
    E_ITEM_INNER_MAX_VOLUME_ML,
    bool:E_ITEM_CAN_LAYER2
};

// Главный кеш определений предметов в оперативной памяти O(1) по ID (1..MAX_ITEM_DEFS-1)
static stock sItemDefs[MAX_ITEM_DEFS][E_ITEM_DEF];
static stock sLoadedItemDefsCount = 0;

// Эталонная встроенная таблица всех 91 предметов из sql/002_seed_data.sql
static stock const sBuiltinItemDefs[TOTAL_SEED_ITEM_DEFS][E_ITEM_DEF] =
{
    // А. Ближний бой и инструменты (ID 1..12)
    { true, 1,  "MELEE_BRASS_KNUCKLES", "Кастет",                             ITEM_CAT_MELEE,             300,   200,   false, 1,     1,  0,    0,     0,     true  },
    { true, 2,  "MELEE_GOLF_CLUB",      "Клюшка для гольфа",                  ITEM_CAT_MELEE,             900,   1500,  false, 1,     2,  0,    0,     0,     false },
    { true, 3,  "MELEE_NIGHTSTICK",     "Полицейская дубинка",                ITEM_CAT_MELEE,             700,   800,   false, 1,     3,  0,    0,     0,     false },
    { true, 4,  "MELEE_KNIFE",          "Боевой нож",                         ITEM_CAT_MELEE,             400,   300,   false, 1,     4,  0,    0,     0,     true  },
    { true, 5,  "MELEE_BASEBALL_BAT",   "Бейсбольная бита",                   ITEM_CAT_MELEE,             1200,  2000,  false, 1,     5,  0,    0,     0,     false },
    { true, 6,  "MELEE_SHOVEL",         "Штыковая лопата",                    ITEM_CAT_MELEE,             2500,  4000,  false, 1,     6,  0,    0,     0,     false },
    { true, 7,  "MELEE_POOL_CUE",       "Бильярдный кий",                     ITEM_CAT_MELEE,             600,   1500,  false, 1,     7,  0,    0,     0,     false },
    { true, 8,  "MELEE_KATANA",         "Катана",                             ITEM_CAT_MELEE,             1800,  2500,  false, 1,     8,  0,    0,     0,     false },
    { true, 9,  "MELEE_CHAINSAW",       "Бензопила",                          ITEM_CAT_MELEE,             6500,  7000,  false, 1,     9,  0,    0,     0,     false },
    { true, 10, "MELEE_CANE",           "Трость",                             ITEM_CAT_MELEE,             800,   1200,  false, 1,     15, 0,    0,     0,     false },
    { true, 11, "MELEE_FLOWERS",        "Букет цветов",                       ITEM_CAT_MELEE,             300,   1000,  false, 1,     14, 0,    0,     0,     false },
    { true, 12, "MELEE_DILDO",          "Игрушка из секс-шопа",               ITEM_CAT_MELEE,             500,   500,   false, 1,     10, 0,    0,     0,     false },

    // Б. Огнестрельное оружие без отдельных предметов патронов (ID 13..25)
    { true, 13, "WEAPON_PISTOL_9MM",    "Пистолет 9mm",                       ITEM_CAT_FIREARM,           1100,  1000,  false, 1,     22, 8,    0,     0,     false },
    { true, 14, "WEAPON_SILENCED_9MM",  "Пистолет 9mm с глушителем",          ITEM_CAT_FIREARM,           1300,  1500,  false, 1,     23, 8,    0,     0,     false },
    { true, 15, "WEAPON_DESERT_EAGLE",  "Пистолет Desert Eagle",              ITEM_CAT_FIREARM,           2000,  1500,  false, 1,     24, 20,   0,     0,     false },
    { true, 16, "WEAPON_PUMP_SHOTGUN",  "Помповый дробовик",                  ITEM_CAT_FIREARM,           3600,  4000,  false, 1,     25, 45,   0,     0,     false },
    { true, 17, "WEAPON_SAWNOFF",       "Обрез двустволки",                   ITEM_CAT_FIREARM,           2200,  2500,  false, 1,     26, 45,   0,     0,     false },
    { true, 18, "WEAPON_SPAS12",        "Боевой дробовик SPAS-12",            ITEM_CAT_FIREARM,           4400,  4500,  false, 1,     27, 45,   0,     0,     false },
    { true, 19, "WEAPON_MICRO_UZI",     "Пистолет-пулемет Micro Uzi",         ITEM_CAT_FIREARM,           1500,  1500,  false, 1,     28, 8,    0,     0,     false },
    { true, 20, "WEAPON_TEC9",          "Пистолет-пулемет Tec-9",             ITEM_CAT_FIREARM,           1400,  1500,  false, 1,     32, 8,    0,     0,     false },
    { true, 21, "WEAPON_MP5",           "Пистолет-пулемет MP5",               ITEM_CAT_FIREARM,           2900,  3000,  false, 1,     29, 8,    0,     0,     false },
    { true, 22, "WEAPON_AK47",          "Автомат AK-47",                      ITEM_CAT_FIREARM,           4300,  4500,  false, 1,     30, 16,   0,     0,     false },
    { true, 23, "WEAPON_M4",            "Штурмовая винтовка M4",              ITEM_CAT_FIREARM,           3400,  4000,  false, 1,     31, 12,   0,     0,     false },
    { true, 24, "WEAPON_COUNTRY_RIFLE", "Охотничья винтовка",                 ITEM_CAT_FIREARM,           3800,  4500,  false, 1,     33, 24,   0,     0,     false },
    { true, 25, "WEAPON_SNIPER_RIFLE",  "Снайперская винтовка",               ITEM_CAT_FIREARM,           6500,  6000,  false, 1,     34, 26,   0,     0,     false },

    // В. Тяжелое, метательное и спецсредства (ID 26..39)
    { true, 26, "HEAVY_GRENADE",        "Граната осколочная",                 ITEM_CAT_HEAVY_THROWABLE,   600,   500,   false, 1,     16, 0,    0,     0,     false },
    { true, 27, "HEAVY_TEARGAS",        "Шашка слезоточивого газа",           ITEM_CAT_HEAVY_THROWABLE,   500,   500,   false, 1,     17, 0,    0,     0,     false },
    { true, 28, "HEAVY_MOLOTOV",        "Коктейль Молотова",                  ITEM_CAT_HEAVY_THROWABLE,   800,   800,   false, 1,     18, 0,    0,     0,     false },
    { true, 29, "HEAVY_SATCHEL_CHARGE", "Взрывпакет с детонатором",           ITEM_CAT_HEAVY_THROWABLE,   3000,  2500,  false, 1,     39, 0,    0,     0,     false },
    { true, 30, "HEAVY_RPG7",           "Гранатомет РПГ-7",                   ITEM_CAT_HEAVY_THROWABLE,   7000,  12000, false, 1,     35, 2200, 0,     0,     false },
    { true, 31, "HEAVY_HS_ROCKET",      "ПЗРК с тепловым наведением",         ITEM_CAT_HEAVY_THROWABLE,   10500, 15000, false, 1,     36, 3000, 0,     0,     false },
    { true, 32, "HEAVY_FLAMETHROWER",   "Ранцевый огнемет",                   ITEM_CAT_HEAVY_THROWABLE,   12000, 14000, false, 1,     37, 100,  0,     0,     false },
    { true, 33, "HEAVY_MINIGUN",        "Шестиствольный пулемет Миниган",     ITEM_CAT_HEAVY_THROWABLE,   38000, 25000, false, 1,     38, 12,   0,     0,     false },
    { true, 34, "SPEC_SPRAYCAN",        "Перцовый баллончик",                 ITEM_CAT_HEAVY_THROWABLE,   500,   500,   false, 1,     41, 1,    0,     0,     false },
    { true, 35, "SPEC_FIRE_EXT",        "Порошковый огнетушитель",            ITEM_CAT_HEAVY_THROWABLE,   6000,  5000,  false, 1,     42, 5,    0,     0,     false },
    { true, 36, "SPEC_CAMERA",          "Зеркальный фотоаппарат",             ITEM_CAT_HEAVY_THROWABLE,   900,   1000,  false, 1,     43, 1,    0,     0,     false },
    { true, 37, "SPEC_NV_GOGGLES",      "Прибор ночного видения",             ITEM_CAT_HEAVY_THROWABLE,   800,   1000,  false, 1,     44, 0,    0,     0,     false },
    { true, 38, "SPEC_THERMAL_GOGGLES", "Тепловизионные очки",                ITEM_CAT_HEAVY_THROWABLE,   1000,  1200,  false, 1,     45, 0,    0,     0,     false },
    { true, 39, "SPEC_PARACHUTE",       "Десантный парашют",                  ITEM_CAT_HEAVY_THROWABLE,   11000, 15000, false, 1,     46, 0,    0,     0,     false },

    // Г. Снаряжение, инструменты и электроника (ID 40..55)
    { true, 40, "GEAR_BODY_ARMOR",      "Тяжелый бронежилет",                 ITEM_CAT_GEAR_ELECTRONICS,  6500,  8000,  false, 1,     0,  0,    0,     0,     false },
    { true, 41, "GEAR_BACKPACK",        "Туристический рюкзак",               ITEM_CAT_GEAR_ELECTRONICS,  1500,  2000,  false, 1,     0,  0,    25000, 35000, false },
    { true, 42, "GEAR_DUFFLE_BAG",      "Спортивная сумка",                   ITEM_CAT_GEAR_ELECTRONICS,  1200,  2500,  false, 1,     0,  0,    35000, 45000, false },
    { true, 43, "GEAR_BALACLAVA",       "Тактическая балаклава",              ITEM_CAT_GEAR_ELECTRONICS,  200,   300,   false, 1,     0,  0,    0,     0,     true  },
    { true, 44, "GEAR_HANDCUFFS",       "Стальные наручники",                 ITEM_CAT_GEAR_ELECTRONICS,  500,   400,   true,  10,    0,  0,    0,     0,     false },
    { true, 45, "TOOL_LOCKPICK_SET",    "Набор отмычек",                      ITEM_CAT_GEAR_ELECTRONICS,  300,   300,   true,  20,    0,  0,    0,     0,     true  },
    { true, 46, "TOOL_WRENCH_KIT",      "Ящик автомеханика с ключами",        ITEM_CAT_GEAR_ELECTRONICS,  4500,  3500,  false, 1,     0,  0,    10000, 8000,  false },
    { true, 47, "TOOL_GUNSMITH_KIT",    "Набор оружейника",                   ITEM_CAT_GEAR_ELECTRONICS,  2500,  2000,  false, 1,     0,  0,    0,     0,     false },
    { true, 48, "TOOL_FUEL_CANISTER",   "Канистра с бензином 20 л",           ITEM_CAT_GEAR_ELECTRONICS,  16000, 20000, false, 1,     0,  0,    0,     0,     false },
    { true, 49, "TOOL_BOLT_CUTTERS",    "Гидравлический болторез",            ITEM_CAT_GEAR_ELECTRONICS,  3200,  2500,  false, 1,     0,  0,    0,     0,     false },
    { true, 50, "ELEC_MOBILE_PHONE",    "Смартфон",                           ITEM_CAT_GEAR_ELECTRONICS,  200,   200,   false, 1,     0,  0,    0,     0,     true  },
    { true, 51, "ELEC_BURNER_PHONE",    "Одноразовый телефон",                ITEM_CAT_GEAR_ELECTRONICS,  150,   100,   false, 1,     0,  0,    0,     0,     true  },
    { true, 52, "ELEC_SIM_CARD",        "SIM-карта сотовой связи",            ITEM_CAT_GEAR_ELECTRONICS,  10,    10,    false, 1,     0,  0,    0,     0,     true  },
    { true, 53, "ELEC_WALKIE_TALKIE",   "Портативная рация",                  ITEM_CAT_GEAR_ELECTRONICS,  600,   700,   false, 1,     0,  0,    0,     0,     false },
    { true, 54, "TOOL_MINING_PICKAXE",  "Шахтерская кирка",                   ITEM_CAT_GEAR_ELECTRONICS,  3800,  3000,  false, 1,     0,  0,    0,     0,     false },
    { true, 55, "TOOL_FORENSICS_KIT",   "Чемодан криминалиста",               ITEM_CAT_GEAR_ELECTRONICS,  2000,  2500,  false, 1,     0,  0,    0,     0,     false },

    // Д. Медицина, еда, напитки и нелегал (ID 56..67)
    { true, 56, "MED_FIRST_AID_KIT",    "Аптечка первой помощи",              ITEM_CAT_MEDICAL_FOOD,      1500,  2000,  true,  10,    0,  0,    0,     0,     false },
    { true, 57, "MED_SURGICAL_KIT",     "Полевой хирургический набор",        ITEM_CAT_MEDICAL_FOOD,      2200,  2500,  false, 1,     0,  0,    0,     0,     false },
    { true, 58, "MED_BANDAGE",          "Стерильный бинт",                    ITEM_CAT_MEDICAL_FOOD,      100,   100,   true,  50,    0,  0,    0,     0,     true  },
    { true, 59, "MED_TOURNIQUET",       "Кровоостанавливающий жгут",          ITEM_CAT_MEDICAL_FOOD,      200,   200,   true,  20,    0,  0,    0,     0,     true  },
    { true, 60, "MED_MORPHINE_SYRINGE", "Шприц-тюбик с морфином",             ITEM_CAT_MEDICAL_FOOD,      100,   100,   true,  20,    0,  0,    0,     0,     true  },
    { true, 61, "FOOD_WATER_BOTTLE",    "Бутылка питьевой воды 1 л",          ITEM_CAT_MEDICAL_FOOD,      1000,  1000,  true,  20,    0,  0,    0,     0,     false },
    { true, 62, "FOOD_MRE_RATION",      "Армейский сухпаек MRE",              ITEM_CAT_MEDICAL_FOOD,      800,   1000,  true,  20,    0,  0,    0,     0,     false },
    { true, 63, "FOOD_FASTFOOD_BURGER", "Горячий бургер",                     ITEM_CAT_MEDICAL_FOOD,      400,   500,   true,  20,    0,  0,    0,     0,     false },
    { true, 64, "FOOD_LIQUOR_BOTTLE",   "Бутылка виски",                      ITEM_CAT_MEDICAL_FOOD,      1200,  1000,  true,  20,    0,  0,    0,     0,     false },
    { true, 65, "FOOD_CIGARETTE_PACK",  "Пачка сигарет",                      ITEM_CAT_MEDICAL_FOOD,      50,    50,    true,  50,    0,  0,    0,     0,     true  },
    { true, 66, "ILLEGAL_HARD_DRUG",    "Доза метамфетамина",                 ITEM_CAT_ILLEGAL,           50,    50,    true,  100,   0,  0,    0,     0,     false },
    { true, 67, "ILLEGAL_WEED_PACK",    "Брикет марихуаны",                   ITEM_CAT_ILLEGAL,           1000,  1000,  true,  50,    0,  0,    0,     0,     false },

    // Е. Документы, валюта и промышленные товарные партии (ID 68..75)
    { true, 68, "DOC_PASSPORT_ID",      "Паспорт гражданина",                 ITEM_CAT_DOCUMENT_CURRENCY, 50,    50,    false, 1,     0,  0,    0,     0,     true  },
    { true, 69, "DOC_WEAPON_LICENSE",   "Лицензия на ношение оружия",         ITEM_CAT_DOCUMENT_CURRENCY, 20,    20,    false, 1,     0,  0,    0,     0,     true  },
    { true, 70, "DOC_VEHICLE_TITLE",    "Техпаспорт транспортного средства",  ITEM_CAT_DOCUMENT_CURRENCY, 20,    20,    false, 1,     0,  0,    0,     0,     true  },
    { true, 71, "DOC_BANK_CARD",        "Банковская дебетовая карта",         ITEM_CAT_DOCUMENT_CURRENCY, 10,    10,    false, 1,     0,  0,    0,     0,     true  },
    { true, 72, "ITEM_PHYSICAL_KEYS",   "Связка ключей от замка",             ITEM_CAT_DOCUMENT_CURRENCY, 100,   50,    false, 1,     0,  0,    0,     0,     true  },
    { true, 73, "CURR_CASH_BUNDLE",     "Пачка банкнот наличными",            ITEM_CAT_DOCUMENT_CURRENCY, 500,   400,   true,  10000, 0,  0,    0,     0,     false },
    { true, 74, "RAW_COMMODITY_UNIT",   "Партия первичного сырья",            ITEM_CAT_RAW,               1000,  1000,  true,  5000,  0,  0,    0,     0,     false },
    { true, 75, "INT_PROCESSED_METAL",  "Партия промышленного проката",       ITEM_CAT_INTERMEDIATE,      1000,  800,   true,  5000,  0,  0,    0,     0,     false },

    // Ж. Базовое сырье нулевого уровня цепочки (ID 76..81)
    { true, 76, "RAW_CRUDE_OIL",        "Сырая нефть",                        ITEM_CAT_RAW,               1000,  1000,  true,  10000, 0,  0,    0,     0,     false },
    { true, 77, "RAW_IRON_ORE",         "Железная руда",                      ITEM_CAT_RAW,               1000,  1000,  true,  10000, 0,  0,    0,     0,     false },
    { true, 78, "RAW_WOOD_LOG",         "Древесина-кругляк",                  ITEM_CAT_RAW,               1000,  1000,  true,  10000, 0,  0,    0,     0,     false },
    { true, 79, "RAW_TECH_WATER",       "Сырая техническая вода",             ITEM_CAT_RAW,               1000,  1000,  true,  10000, 0,  0,    0,     0,     false },
    { true, 80, "RAW_GRAIN_FLOUR",      "Зерно и пекарская мука",             ITEM_CAT_RAW,               1000,  1000,  true,  10000, 0,  0,    0,     0,     false },
    { true, 81, "RAW_CHEM_PRECURSORS",  "Химические реактивы и сера",         ITEM_CAT_RAW,               1000,  1000,  true,  5000,  0,  0,    0,     0,     false },

    // З. Промежуточные заводские компоненты первого уровня (ID 82..90)
    { true, 82, "INT_STEEL_SHEET",      "Листовой стальной прокат",           ITEM_CAT_INTERMEDIATE,      1000,  800,   true,  5000,  0,  0,    0,     0,     false },
    { true, 83, "INT_SPRINGS_PINS",     "Закаленные пружины и штифты",        ITEM_CAT_INTERMEDIATE,      500,   300,   true,  5000,  0,  0,    0,     0,     false },
    { true, 84, "INT_BEARINGS",         "Прецизионные подшипники",            ITEM_CAT_INTERMEDIATE,      200,   100,   true,  5000,  0,  0,    0,     0,     false },
    { true, 85, "INT_NAILS_FASTENERS",  "Гвозди и стальной крепеж",           ITEM_CAT_INTERMEDIATE,      100,   50,    true,  5000,  0,  0,    0,     0,     false },
    { true, 86, "INT_SYNTH_PLASTIC",    "Гранулы синтетического пластика",    ITEM_CAT_INTERMEDIATE,      1000,  1200,  true,  5000,  0,  0,    0,     0,     false },
    { true, 87, "INT_GUNPOWDER",        "Бездымный оружейный порох",          ITEM_CAT_INTERMEDIATE,      500,   500,   true,  5000,  0,  0,    0,     0,     false },
    { true, 88, "INT_WOOD_PLANKS",      "Строганые древесные доски",          ITEM_CAT_INTERMEDIATE,      1000,  1000,  true,  5000,  0,  0,    0,     0,     false },
    { true, 89, "INT_TEXTILE_FABRIC",   "Плотное текстильное полотно",        ITEM_CAT_INTERMEDIATE,      500,   800,   true,  5000,  0,  0,    0,     0,     false },
    { true, 90, "INT_REFINED_FUEL",     "Очищенное моторное топливо",         ITEM_CAT_INTERMEDIATE,      1000,  1000,  true,  10000, 0,  0,    0,     0,     false },

    // И. Комплект одежды / Внешний скин персонажа (ID 91)
    { true, 91, "GEAR_CLOTHING_OUTFIT", "Комплект верхней одежды",            ITEM_CAT_GEAR_ELECTRONICS,  3000,  3000,  false, 1,     0,  0,    0,     0,     true  }
};

// =============================================================================
//  2. ВНУТРЕННИЕ ФУНКЦИИ ЗАГРУЗКИ И ПАРСИНГА КАТЕГОРИЙ (static stock)
// =============================================================================

static stock E_ITEM_CATEGORY:Internal_ParseItemCategory(const catStr[])
{
    if (!strcmp(catStr, "RAW", true))               return ITEM_CAT_RAW;
    if (!strcmp(catStr, "INTERMEDIATE", true))      return ITEM_CAT_INTERMEDIATE;
    if (!strcmp(catStr, "MELEE", true))             return ITEM_CAT_MELEE;
    if (!strcmp(catStr, "FIREARM", true))           return ITEM_CAT_FIREARM;
    if (!strcmp(catStr, "HEAVY_THROWABLE", true))   return ITEM_CAT_HEAVY_THROWABLE;
    if (!strcmp(catStr, "GEAR_ELECTRONICS", true))  return ITEM_CAT_GEAR_ELECTRONICS;
    if (!strcmp(catStr, "MEDICAL_FOOD", true))      return ITEM_CAT_MEDICAL_FOOD;
    if (!strcmp(catStr, "ILLEGAL", true))           return ITEM_CAT_ILLEGAL;
    if (!strcmp(catStr, "DOCUMENT_CURRENCY", true)) return ITEM_CAT_DOCUMENT_CURRENCY;
    return ITEM_CAT_NONE;
}

static stock Internal_SeedBuiltinItemDefinitions()
{
    for (new i = 0; i < MAX_ITEM_DEFS; i++)
    {
        sItemDefs[i][E_ITEM_VALID] = false;
    }

    sLoadedItemDefsCount = 0;
    for (new idx = 0; idx < TOTAL_SEED_ITEM_DEFS; idx++)
    {
        new const defId = sBuiltinItemDefs[idx][E_ITEM_ID];
        if (defId <= 0 || defId >= MAX_ITEM_DEFS)
        {
            continue;
        }
        sItemDefs[defId] = sBuiltinItemDefs[idx];
        sLoadedItemDefsCount++;
    }
}

static stock Internal_LoadItemDefinitionsFromDbSync()
{
    // Сначала заполняем эталонный кеш из встроенного реестра
    Internal_SeedBuiltinItemDefinitions();

    if (!DB_IsConnected())
    {
        return sLoadedItemDefsCount;
    }

    // Разрешенный синхронный запрос строго внутри OnGameModeInit (по TECH_CONTEXT.MD 1.1)
    new const Cache:result = mysql_query(gMySQL,
        "SELECT `id`, `code_name`, `display_name`, `category`, `base_weight_g`, `base_volume_ml`, `is_stackable`, `max_stack`, `gta_weapon_id`, `ammo_unit_weight_g`, `inner_max_weight_g`, `inner_max_volume_ml`, `can_layer2` FROM `item_definitions` ORDER BY `id` ASC;",
        true);

    if (!cache_is_valid(result))
    {
        return sLoadedItemDefsCount;
    }

    new rows = 0;
    cache_get_row_count(rows);

    if (rows > 0)
    {
        for (new i = 0; i < MAX_ITEM_DEFS; i++)
        {
            sItemDefs[i][E_ITEM_VALID] = false;
        }
        sLoadedItemDefsCount = 0;

        new defId;
        new catStr[32];
        new isStackableInt;
        new canLayer2Int;

        for (new r = 0; r < rows; r++)
        {
            cache_get_value_name_int(r, "id", defId);
            if (defId <= 0 || defId >= MAX_ITEM_DEFS)
            {
                continue;
            }

            sItemDefs[defId][E_ITEM_VALID] = true;
            sItemDefs[defId][E_ITEM_ID] = defId;
            cache_get_value_name(r, "code_name", sItemDefs[defId][E_ITEM_CODE_NAME], ITEM_CODE_NAME_LEN);
            cache_get_value_name(r, "display_name", sItemDefs[defId][E_ITEM_DISPLAY_NAME], ITEM_DISPLAY_NAME_LEN);
            cache_get_value_name(r, "category", catStr, sizeof(catStr));
            sItemDefs[defId][E_ITEM_CAT] = Internal_ParseItemCategory(catStr);

            cache_get_value_name_int(r, "base_weight_g", sItemDefs[defId][E_ITEM_BASE_WEIGHT_G]);
            cache_get_value_name_int(r, "base_volume_ml", sItemDefs[defId][E_ITEM_BASE_VOLUME_ML]);
            cache_get_value_name_int(r, "is_stackable", isStackableInt);
            cache_get_value_name_int(r, "max_stack", sItemDefs[defId][E_ITEM_MAX_STACK]);
            cache_get_value_name_int(r, "gta_weapon_id", sItemDefs[defId][E_ITEM_GTA_WEAPON_ID]);
            cache_get_value_name_int(r, "ammo_unit_weight_g", sItemDefs[defId][E_ITEM_AMMO_WEIGHT_G]);
            cache_get_value_name_int(r, "inner_max_weight_g", sItemDefs[defId][E_ITEM_INNER_MAX_WEIGHT_G]);
            cache_get_value_name_int(r, "inner_max_volume_ml", sItemDefs[defId][E_ITEM_INNER_MAX_VOLUME_ML]);
            cache_get_value_name_int(r, "can_layer2", canLayer2Int);

            sItemDefs[defId][E_ITEM_STACKABLE] = (isStackableInt != 0);
            sItemDefs[defId][E_ITEM_CAN_LAYER2] = (canLayer2Int != 0);
            sLoadedItemDefsCount++;
        }
    }

    cache_delete(result);
    return sLoadedItemDefsCount;
}

// =============================================================================
//  3. ПУБЛИЧНЫЙ API РЕЕСТРА ПРЕДМЕТОВ (Item_*)
// =============================================================================

stock bool:Item_IsValid(def_id)
{
    if (def_id <= 0 || def_id >= MAX_ITEM_DEFS)
    {
        return false;
    }
    return sItemDefs[def_id][E_ITEM_VALID];
}

stock Item_GetName(def_id, output[], len = sizeof(output))
{
    if (!Item_IsValid(def_id))
    {
        format(output, len, "Неизвестный предмет");
        return 0;
    }
    format(output, len, "%s", sItemDefs[def_id][E_ITEM_DISPLAY_NAME]);
    return 1;
}

stock Item_GetCodeName(def_id, output[], len = sizeof(output))
{
    if (!Item_IsValid(def_id))
    {
        format(output, len, "UNKNOWN_ITEM");
        return 0;
    }
    format(output, len, "%s", sItemDefs[def_id][E_ITEM_CODE_NAME]);
    return 1;
}

stock E_ITEM_CATEGORY:Item_GetCategory(def_id)
{
    if (!Item_IsValid(def_id))
    {
        return ITEM_CAT_NONE;
    }
    return sItemDefs[def_id][E_ITEM_CAT];
}

stock Item_GetBaseWeight(def_id)
{
    if (!Item_IsValid(def_id))
    {
        return 0;
    }
    return sItemDefs[def_id][E_ITEM_BASE_WEIGHT_G];
}

stock Item_GetBaseVolume(def_id)
{
    if (!Item_IsValid(def_id))
    {
        return 0;
    }
    return sItemDefs[def_id][E_ITEM_BASE_VOLUME_ML];
}

stock bool:Item_IsStackable(def_id)
{
    if (!Item_IsValid(def_id))
    {
        return false;
    }
    return sItemDefs[def_id][E_ITEM_STACKABLE];
}

stock Item_GetMaxStack(def_id)
{
    if (!Item_IsValid(def_id))
    {
        return 1;
    }
    if (def_id == ITEM_ID_CASH_BUNDLE)
    {
        return 100000000;
    }
    return sItemDefs[def_id][E_ITEM_MAX_STACK];
}

stock Item_GetAmmoUnitWeight(def_id)
{
    if (!Item_IsValid(def_id))
    {
        return 0;
    }
    return sItemDefs[def_id][E_ITEM_AMMO_WEIGHT_G];
}

stock bool:Item_IsContainer(def_id)
{
    if (!Item_IsValid(def_id))
    {
        return false;
    }
    return (sItemDefs[def_id][E_ITEM_INNER_MAX_WEIGHT_G] > 0 &&
            sItemDefs[def_id][E_ITEM_INNER_MAX_VOLUME_ML] > 0);
}

stock Item_GetInnerMaxWeight(def_id)
{
    if (!Item_IsValid(def_id))
    {
        return 0;
    }
    return sItemDefs[def_id][E_ITEM_INNER_MAX_WEIGHT_G];
}

stock Item_GetInnerMaxVolume(def_id)
{
    if (!Item_IsValid(def_id))
    {
        return 0;
    }
    return sItemDefs[def_id][E_ITEM_INNER_MAX_VOLUME_ML];
}

stock bool:Item_CanStoreInLayer2(def_id)
{
    if (!Item_IsValid(def_id))
    {
        return false;
    }
    return sItemDefs[def_id][E_ITEM_CAN_LAYER2];
}

stock Item_GetGtaWeaponId(def_id)
{
    if (!Item_IsValid(def_id))
    {
        return 0;
    }
    return sItemDefs[def_id][E_ITEM_GTA_WEAPON_ID];
}

// Расчет массы одного экземпляра с учетом боезапаса (в граммах, строго INT):
// W_instance = N_amount * W_base + N_ammo * W_round
// Для наличных банкнот (ITEM_ID_CASH_BUNDLE) 1 пачка ($1,000) весит 500 г (0.5 кг)
stock Item_CalculateInstanceWeight(def_id, amount, ammo_count = 0)
{
    if (!Item_IsValid(def_id) || amount <= 0)
    {
        return 0;
    }
    if (def_id == ITEM_ID_CASH_BUNDLE)
    {
        new const bundles = (amount + 999) / 1000;
        return (bundles * sItemDefs[def_id][E_ITEM_BASE_WEIGHT_G]);
    }
    new const safeAmmo = (ammo_count > 0) ? ammo_count : 0;
    new const baseWeight = sItemDefs[def_id][E_ITEM_BASE_WEIGHT_G] * amount;
    new const ammoWeight = sItemDefs[def_id][E_ITEM_AMMO_WEIGHT_G] * safeAmmo;
    return (baseWeight + ammoWeight);
}

// Расчет объема одного экземпляра предмета (в миллилитрах, строго INT)
stock Item_CalculateInstanceVolume(def_id, amount)
{
    if (!Item_IsValid(def_id) || amount <= 0)
    {
        return 0;
    }
    if (def_id == ITEM_ID_CASH_BUNDLE)
    {
        new const bundles = (amount + 999) / 1000;
        return (bundles * sItemDefs[def_id][E_ITEM_BASE_VOLUME_ML]);
    }
    return (sItemDefs[def_id][E_ITEM_BASE_VOLUME_ML] * amount);
}

// Выбор 3D-модели объекта GTA SA для отображения выброшенного предмета на земле (WORLD_DROP)
stock Item_GetWorldObjectModel(def_id)
{
    if (!Item_IsValid(def_id))
    {
        return 1271;
    }
    switch (sItemDefs[def_id][E_ITEM_CAT])
    {
        case ITEM_CAT_FIREARM, ITEM_CAT_HEAVY_THROWABLE:
        {
            return 2061; // Оружейный кейс / боевой ящик
        }
        case ITEM_CAT_MEDICAL_FOOD:
        {
            return 11738; // Медицинская сумка / паек
        }
        case ITEM_CAT_DOCUMENT_CURRENCY:
        {
            return (def_id == ITEM_ID_CASH_BUNDLE) ? 1212 : 1271;
        }
        case ITEM_CAT_GEAR_ELECTRONICS:
        {
            if (def_id == ITEM_ID_BACKPACK || def_id == ITEM_ID_DUFFLE_BAG)
            {
                return 1550; // Спортивная сумка / вещмешок
            }
            return 1271;
        }
    }
    return 1271; // Деревянный ящик / коробка для сырья и деталей
}

stock Item_GetLoadedCount()
{
    return sLoadedItemDefsCount;
}

// =============================================================================
//  4. СИСТЕМНЫЕ ХУКИ И САМОПРОВЕРКА ФИЗИКИ ВЕСА (hook OnGameModeInit)
// =============================================================================

hook OnGameModeInit()
{
    new const startTick = GetTickCount();
    new const count = Internal_LoadItemDefinitionsFromDbSync();
    new const elapsedMs = GetTickCount() - startTick;

    // Контрольный тест из DoD 2.1: "200 M4" (ID 23, 1 ствол + 200 патронов по 12 г = 5800 г)
    new const m4TestWeightG = Item_CalculateInstanceWeight(23, 1, 200);
    new m4Name[ITEM_DISPLAY_NAME_LEN];
    Item_GetName(23, m4Name);

    printf("%s [Entities/Items] Загружено %d определений предметов в RAM за %d мс.",
        SERVER_LOG_PREFIX, count, elapsedMs);
    printf("%s [Entities/Items] Контроль физики веса: '200 %s' = %d г (эталон: 5800 г) [%s].",
        SERVER_LOG_PREFIX,
        m4Name,
        m4TestWeightG,
        (m4TestWeightG == 5800) ? ("УСПЕШНО") : ("ОШИБКА"));
    return 1;
}

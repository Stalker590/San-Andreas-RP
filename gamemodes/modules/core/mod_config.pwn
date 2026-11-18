/*
 * =============================================================================
 *  SAN ANDREAS RP — Модуль глобальных констант, пулов, перечислений и макросов
 *  Файл:      gamemodes/modules/core/mod_config.pwn
 *  Пункт:     ROADMAP [1.1] — Модуль констант и конфигурации (core/mod_config.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_config_included
    #endinput
#endif
#define _mod_config_included

// =============================================================================
//  1. КОНСТАНТЫ ЛИМИТОВ СТАТИЧЕСКИХ ПУЛОВ И СТРУКТУР ДАННЫХ
// =============================================================================

#define MAX_ACTIVE_STORAGES                     (16384)
#define MAX_STORAGE_ITEMS                       (131072)
#define MAX_ITEM_DEFS                           (128)
#define MAX_ORGANIZATIONS                       (256)
#define MAX_ENTERPRISES                         (512)
#define MAX_VEHICLES_SERVER                     (4096)
#define MAX_PROPERTIES                          (4096)

#define MAX_NESTING_DEPTH                       (2)
#define INVALID_STORAGE_SLOT                    (-1)
#define INVALID_STORAGE_ITEM_SLOT               (-1)

// Дистанции взаимодействия и параметры хранилищ
#define STORAGE_INTERACT_DISTANCE               (3.5)
#define WORLD_DROP_INTERACT_RADIUS              (2.0)
#define WORLD_DROP_STREAM_DISTANCE              (60.0)
#define WORLD_DROP_LABEL_DISTANCE               (8.0)
#define STORAGE_MUTEX_TIMEOUT_MS                (10000)

// Стандартное время жизни полевых контейнеров (TTL в секундах)
#define TTL_CORPSE_LOOT_SECONDS                 (1200)
#define TTL_WORLD_DROP_SECONDS                  (3600)

// Базовые лимиты карманов персонажа по умолчанию (в граммах и миллилитрах)
#define DEFAULT_PLAYER_LAYER1_WEIGHT_G          (25000)
#define DEFAULT_PLAYER_LAYER1_VOLUME_ML         (30000)
#define DEFAULT_PLAYER_LAYER2_WEIGHT_G          (5000)
#define DEFAULT_PLAYER_LAYER2_VOLUME_ML         (5000)

// Коды калибров и ключевых предметов из мастер-реестра (ID 1..91)
#define ITEM_ID_BACKPACK                        (41)
#define ITEM_ID_DUFFLE_BAG                      (42)
#define ITEM_ID_WRENCH_KIT                      (46)
#define ITEM_ID_PASSPORT                        (68)
#define ITEM_ID_WEAPON_LICENSE                  (69)
#define ITEM_ID_VEHICLE_TITLE                   (70)
#define ITEM_ID_BANK_CARD                       (71)
#define ITEM_ID_PHYSICAL_KEYS                   (72)
#define ITEM_ID_CASH_BUNDLE                     (73)
#define ITEM_ID_CLOTHING_OUTFIT                 (91)

// Номиналы валют для предмета ITEM_ID_CASH_BUNDLE (meta_int2)
#define CURRENCY_USD                            (1)
#define CURRENCY_EUR                            (2)
#define CURRENCY_CNY                            (3)

// Флаги чистоты наличных денег (meta_int1)
#define CASH_FLAG_CLEAN                         (0)
#define CASH_FLAG_DIRTY                         (1)

// Состояния комплекта одежды ITEM_ID_CLOTHING_OUTFIT (meta_int2)
#define CLOTHING_STATE_BAG                      (0)
#define CLOTHING_STATE_EQUIPPED                 (1)

// Базовые скины нижнего белья при отсутствии одежды
#define SKIN_UNDERWEAR_MALE                     (252)
#define SKIN_UNDERWEAR_FEMALE                   (140)

// Цветовая палитра системных сообщений (RGBA)
#define COLOR_UI_ERROR                          (0xFF4444FF)
#define COLOR_UI_WARNING                        (0xFFAA00FF)
#define COLOR_UI_SUCCESS                        (0x66CC66FF)
#define COLOR_UI_INFO                           (0x88CCFFFF)
#define COLOR_UI_ROLEPLAY_ME                    (0xC2A2DAFF)
#define COLOR_UI_LABEL_DROP                     (0xFFEE88FF)
#define COLOR_UI_LABEL_CORPSE                   (0xFF6666FF)

// URL фонового аудиопотока экрана входа, регистрации и создания персонажа
#define LOGIN_AUDIO_STREAM_URL                  "http://127.0.0.1:8090/login_theme.mp3"

// =============================================================================
//  2. МАКРОСЫ КОНВЕРТАЦИИ ЦЕЛОЧИСЛЕННЫХ ЕДИНИЦ ФИЗИКИ (БЕЗ FLOAT)
// =============================================================================

#define KG_TO_GRAMS(%0)                         ((%0) * 1000)
#define GRAMS_TO_KG(%0)                         ((%0) / 1000)
#define GRAMS_REMAINDER(%0)                     ((%0) % 1000)

#define LITERS_TO_ML(%0)                        ((%0) * 1000)
#define ML_TO_LITERS(%0)                        ((%0) / 1000)
#define ML_REMAINDER(%0)                        ((%0) % 1000)

// =============================================================================
//  3. ПЕРЕЧИСЛЕНИЯ (ENUM) СИСТЕМНЫХ СУЩНОСТЕЙ И БИТОВЫХ МАСОК
// =============================================================================

// Классификация полиморфных хранилищ (соответствует ENUM в таблице storages)
enum E_STORAGE_TYPE
{
    STORAGE_NONE = 0,
    STORAGE_PLAYER_LAYER1,
    STORAGE_PLAYER_LAYER2,
    STORAGE_VEHICLE_GLOVEBOX,
    STORAGE_VEHICLE_TRUNK,
    STORAGE_PROPERTY_STASH,
    STORAGE_ORG_VAULT,
    STORAGE_ENTERPRISE_WAREHOUSE,
    STORAGE_NESTED_BAG,
    STORAGE_WORLD_DROP,
    STORAGE_CORPSE_LOOT
};

// Категории предметов (соответствует ENUM в таблице item_definitions)
enum E_ITEM_CATEGORY
{
    ITEM_CAT_NONE = 0,
    ITEM_CAT_RAW,
    ITEM_CAT_INTERMEDIATE,
    ITEM_CAT_MELEE,
    ITEM_CAT_FIREARM,
    ITEM_CAT_HEAVY_THROWABLE,
    ITEM_CAT_GEAR_ELECTRONICS,
    ITEM_CAT_MEDICAL_FOOD,
    ITEM_CAT_ILLEGAL,
    ITEM_CAT_DOCUMENT_CURRENCY
};

// Юридический статус организации (таблица organizations)
enum E_ORG_LEGAL_STATUS
{
    ORG_STATUS_UNREGISTERED = 0,
    ORG_STATUS_PRIVATE_CORP,
    ORG_STATUS_STATE_AGENCY
};

// Битовая маска государственных лицензий и полномочий организаций (charter_flags)
enum E_CHARTER_FLAGS (<<= 1)
{
    FLAG_CHARTER_NONE = 0,
    FLAG_CAN_BANK = 1,
    FLAG_LEGAL_HEAVY_WEAPONS,
    FLAG_ISSUE_WARRANTS,
    FLAG_WIRETAP,
    FLAG_BORDER_CONTROL,
    FLAG_EXTRALEGAL_OPS
};

// Зоны повреждений тела в GTA SA / open.mp (OnPlayerTakeDamage bodypart)
enum E_BODY_PART
{
    BODY_PART_TORSO = 3,
    BODY_PART_GROIN = 4,
    BODY_PART_LEFT_ARM = 5,
    BODY_PART_RIGHT_ARM = 6,
    BODY_PART_LEFT_LEG = 7,
    BODY_PART_RIGHT_LEG = 8,
    BODY_PART_HEAD = 9
};

// Типы кровотечений (таблица character_injuries)
enum E_BLEEDING_TYPE
{
    BLEEDING_NONE = 0,
    BLEEDING_VENOUS,
    BLEEDING_ARTERIAL
};

// Битовая маска переломов конечностей и ребер (fracture_flags)
enum E_FRACTURE_FLAGS (<<= 1)
{
    FRACTURE_NONE = 0,
    FRACTURE_LEFT_ARM = 1,
    FRACTURE_RIGHT_ARM,
    FRACTURE_LEFT_LEG,
    FRACTURE_RIGHT_LEG,
    FRACTURE_RIBS
};

// Типы моторного и авиационного горючего (таблица vehicles)
enum E_FUEL_TYPE
{
    FUEL_REGULAR = 0,
    FUEL_DIESEL,
    FUEL_JET_FUEL
};

// Типы сущностей в очереди отложенного сохранения Dirty-Flag
enum E_DIRTY_ENTITY_TYPE
{
    DIRTY_ENTITY_NONE = 0,
    DIRTY_ENTITY_CHARACTER,
    DIRTY_ENTITY_VEHICLE,
    DIRTY_ENTITY_ENTERPRISE,
    DIRTY_ENTITY_STORAGE,
    DIRTY_ENTITY_INJURY
};

// =============================================================================
//  4. ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ЯДРА (ПО СТАНДАРТУ AGENTS.MD РАЗДЕЛ 8)
// =============================================================================

// Глобальный дескриптор пула соединений MySQL R41-4+
new MySQL:gMySQL = MYSQL_INVALID_HANDLE;

// Счетчик поколений сессий слота игрока для защиты асинхронных SQL-запросов от Race Condition
new gPlayerSessionToken[MAX_PLAYERS];

// Метка времени последнего сетевого пакета игрока (для анти-AFK и Warrant Decay)
new gLastPlayerPacketTick[MAX_PLAYERS];

// =============================================================================
//  5. ПУБЛИЧНЫЙ API МОДУЛЯ КОНФИГУРАЦИИ (Config_*)
// =============================================================================

stock Config_GetPlayerSessionToken(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    return gPlayerSessionToken[playerid];
}

stock bool:Config_ValidatePlayerToken(playerid, expectedToken)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return false;
    }
    if (!IsPlayerConnected(playerid))
    {
        return false;
    }
    return (gPlayerSessionToken[playerid] == expectedToken);
}

stock Config_StorageTypeToString(E_STORAGE_TYPE:type, output[], len = sizeof(output))
{
    switch (type)
    {
        case STORAGE_PLAYER_LAYER1:        format(output, len, "PLAYER_LAYER1");
        case STORAGE_PLAYER_LAYER2:        format(output, len, "PLAYER_LAYER2");
        case STORAGE_VEHICLE_GLOVEBOX:     format(output, len, "VEHICLE_GLOVEBOX");
        case STORAGE_VEHICLE_TRUNK:        format(output, len, "VEHICLE_TRUNK");
        case STORAGE_PROPERTY_STASH:       format(output, len, "PROPERTY_STASH");
        case STORAGE_ORG_VAULT:            format(output, len, "ORG_VAULT");
        case STORAGE_ENTERPRISE_WAREHOUSE: format(output, len, "ENTERPRISE_WAREHOUSE");
        case STORAGE_NESTED_BAG:           format(output, len, "NESTED_BAG");
        case STORAGE_WORLD_DROP:           format(output, len, "WORLD_DROP");
        case STORAGE_CORPSE_LOOT:          format(output, len, "CORPSE_LOOT");
        default:                           format(output, len, "PLAYER_LAYER1");
    }
    return 1;
}

stock E_STORAGE_TYPE:Config_ParseStorageType(const typeStr[])
{
    if (!strcmp(typeStr, "PLAYER_LAYER1", true))        return STORAGE_PLAYER_LAYER1;
    if (!strcmp(typeStr, "PLAYER_LAYER2", true))        return STORAGE_PLAYER_LAYER2;
    if (!strcmp(typeStr, "VEHICLE_GLOVEBOX", true))     return STORAGE_VEHICLE_GLOVEBOX;
    if (!strcmp(typeStr, "VEHICLE_TRUNK", true))        return STORAGE_VEHICLE_TRUNK;
    if (!strcmp(typeStr, "PROPERTY_STASH", true))       return STORAGE_PROPERTY_STASH;
    if (!strcmp(typeStr, "ORG_VAULT", true))            return STORAGE_ORG_VAULT;
    if (!strcmp(typeStr, "ENTERPRISE_WAREHOUSE", true)) return STORAGE_ENTERPRISE_WAREHOUSE;
    if (!strcmp(typeStr, "NESTED_BAG", true))           return STORAGE_NESTED_BAG;
    if (!strcmp(typeStr, "WORLD_DROP", true))           return STORAGE_WORLD_DROP;
    if (!strcmp(typeStr, "CORPSE_LOOT", true))          return STORAGE_CORPSE_LOOT;
    return STORAGE_NONE;
}

stock Config_GetStorageTypeTitleRu(E_STORAGE_TYPE:type, output[], len = sizeof(output))
{
    switch (type)
    {
        case STORAGE_PLAYER_LAYER1:        format(output, len, "Outer pockets and vest (Layer 1)");
        case STORAGE_PLAYER_LAYER2:        format(output, len, "Hidden pockets (Layer 2)");
        case STORAGE_VEHICLE_GLOVEBOX:     format(output, len, "Vehicle glovebox");
        case STORAGE_VEHICLE_TRUNK:        format(output, len, "Vehicle trunk");
        case STORAGE_PROPERTY_STASH:       format(output, len, "Property storage cabinet");
        case STORAGE_ORG_VAULT:            format(output, len, "Organization armored vault");
        case STORAGE_ENTERPRISE_WAREHOUSE: format(output, len, "Enterprise warehouse");
        case STORAGE_NESTED_BAG:           format(output, len, "Portable bag / backpack");
        case STORAGE_WORLD_DROP:           format(output, len, "Ground items / stash");
        case STORAGE_CORPSE_LOOT:          format(output, len, "Corpse looting");
        default:                           format(output, len, "Unknown storage");
    }
    return 1;
}

// =============================================================================
//  6. СИСТЕМНЫЕ ХУКИ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        gPlayerSessionToken[i] = 1;
        gLastPlayerPacketTick[i] = 0;
    }
    printf("%s [Core/Config] Constant module initialized (MAX_ACTIVE_STORAGES = %d, MAX_STORAGE_ITEMS = %d).",
        SERVER_LOG_PREFIX, MAX_ACTIVE_STORAGES, MAX_STORAGE_ITEMS);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    gPlayerSessionToken[playerid]++;
    if (gPlayerSessionToken[playerid] <= 0)
    {
        gPlayerSessionToken[playerid] = 1;
    }
    gLastPlayerPacketTick[playerid] = GetTickCount();
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    gPlayerSessionToken[playerid]++;
    gLastPlayerPacketTick[playerid] = 0;
    return 1;
}

hook OnPlayerUpdate(playerid)
{
    gLastPlayerPacketTick[playerid] = GetTickCount();
    return 1;
}

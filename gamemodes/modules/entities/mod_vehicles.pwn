/*
 * =============================================================================
 *  SAN ANDREAS RP — Транспорт, топливо, ключи, угон и нелегальные шроты
 *  Файл:      gamemodes/modules/entities/mod_vehicles.pwn
 *  Пункты:    ROADMAP [8.1] — Транспорт, топливо и обслуживание
 *             ROADMAP [8.2] — Угон транспорта и нелегальные шроты
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_vehicles_included
    #endinput
#endif
#define _mod_vehicles_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ, ДИАЛОГИ И КАТАЛОГ ТРАНСПОРТА
// =============================================================================

#define DIALOG_VEHICLE_BUY                      (1700)
#define DIALOG_VEHICLE_REFUEL_TYPE              (1701)
#define DIALOG_VEHICLE_REFUEL_AMOUNT            (1702)
#define DIALOG_VEHICLE_HOTWIRE                  (1703)
#define DIALOG_VEHICLE_CHOP_CONFIRM             (1704)
#define DIALOG_VEHICLE_UNPARK                   (1705)

#define VEHICLE_CATALOG_SIZE                    (14)
#define VEHICLE_MODEL_NAME_LEN                  (48)
#define VEHICLE_PLATE_LEN                       (12)
#define VEHICLE_VIN_LEN                         (18)
#define VEHICLE_COMMAND_COOLDOWN_MS             (500)
#define VEHICLE_HOTWIRE_COOLDOWN_MS             (4000)
#define VEHICLE_INTERACT_RADIUS                 (4.0)
#define VEHICLE_REFUEL_RADIUS                   (10.0)
#define VEHICLE_CHOP_RADIUS                     (12.0)
#define VEHICLE_DEALERSHIP_RADIUS               (10.0)
#define VEHICLE_GARAGE_RADIUS                   (12.0)

#define VEHICLE_GLOVEBOX_WEIGHT_G               (10000)
#define VEHICLE_GLOVEBOX_VOLUME_ML              (10000)
#define VEHICLE_DEFAULT_TRUNK_WEIGHT_G          (300000)
#define VEHICLE_DEFAULT_TRUNK_VOLUME_ML         (300000)
#define VEHICLE_BIKE_TRUNK_WEIGHT_G             (20000)
#define VEHICLE_BIKE_TRUNK_VOLUME_ML            (20000)

#define VEHICLE_DEFAULT_MAX_FUEL_ML             (60000)
#define VEHICLE_TRUCK_MAX_FUEL_ML               (200000)
#define VEHICLE_TANKER_MAX_FUEL_ML              (300000)
#define VEHICLE_FUEL_WARN_INTERVAL_SECONDS      (15)

#define VEHICLE_FUEL_PRICE_REGULAR_USD          (3)
#define VEHICLE_FUEL_PRICE_DIESEL_USD           (4)
#define VEHICLE_FUEL_PRICE_JET_USD              (6)

#define VEHICLE_KEY_COPY_COST_USD               (100)
#define VEHICLE_REPAIR_BASE_HP                  (250)
#define VEHICLE_REPAIR_SKILL_DIVISOR            (2)
#define VEHICLE_TOWING_SPEED_LIMIT              (55.0)

#define VEHICLE_DEALERSHIP_COUNT                (3)
#define VEHICLE_DEALERSHIP_NAME_LEN             (48)

#define ITEM_ID_VEHICLE_KEY                     (ITEM_ID_PHYSICAL_KEYS)
#define ITEM_ID_FUEL_CANISTER                   (48)
#define VEHICLE_INVALID_ENTERPRISE              (-1)
#define ITEM_ID_REFINED_FUEL                    (90)
#define ITEM_ID_STEEL_SHEET                     (82)
#define ITEM_ID_SPRINGS_PINS                    (83)
#define ITEM_ID_BEARINGS                        (84)

// Контракты с модулем недвижимости
forward bool:Properties_TryLockpickNearest(playerid);
forward bool:Properties_GetNearestOwnedGarage(playerid, &property_db_id, &capacity);
forward bool:Properties_GetExteriorPos(property_db_id, &Float:x, &Float:y, &Float:z, &Float:a);

// Контракты с модулями, подключаемыми после entities/mod_vehicles.pwn
forward bool:Vehicles_FindGasStation(playerid, &enterprise_slot, &warehouse_slot);
forward bool:Vehicles_FindChopShop(playerid, Float:radius, &enterprise_slot, &warehouse_slot);
forward Enterprise_AddReserve(enterprise_id, amount);
forward bool:Banking_DebitAccount(playerid, amount, const reason[]);
forward Banking_GetBalance(playerid);
forward Dialogs_OpenExternalContainer(playerid, ext_storage_slot);
forward Forensics_CreateBrokenGlass(suspect_char_id, Float:x, Float:y, Float:z, interior, virtual_world);
forward Forensics_CreateBloodDna(suspect_char_id, Float:x, Float:y, Float:z, interior, virtual_world);
forward Forensics_CreateLockpickScratch(suspect_char_id, Float:x, Float:y, Float:z, interior, virtual_world);
forward bool:Vehicle_RetrieveFromGarage(slot, Float:x, Float:y, Float:z, Float:a);

// =============================================================================
//  2. ПЕРЕЧИСЛЕНИЯ, КАТАЛОГ И ИНКАПСУЛИРОВАННЫЕ ПУЛЫ (static stock)
// =============================================================================

enum E_VEHICLE_OWNER_TYPE
{
    VEHICLE_OWNER_NONE = 0,
    VEHICLE_OWNER_CHARACTER,
    VEHICLE_OWNER_ORGANIZATION,
    VEHICLE_OWNER_STATE_FLEET
};

enum E_VEHICLE_CATALOG_DATA
{
    E_VC_MODEL,
    E_VC_NAME[VEHICLE_MODEL_NAME_LEN],
    E_VC_PRICE_USD,
    E_FUEL_TYPE:E_VC_FUEL,
    E_VC_MAX_FUEL_ML
};

enum E_VEHICLE_DATA
{
    bool:E_VEH_VALID,
    E_VEH_DB_ID,
    E_VEH_MODEL,
    E_VEH_VIN[VEHICLE_VIN_LEN],
    E_VEH_PLATE[VEHICLE_PLATE_LEN],
    E_VEHICLE_OWNER_TYPE:E_VEH_OWNER_TYPE,
    E_VEH_OWNER_ID,
    E_FUEL_TYPE:E_VEH_FUEL_TYPE,
    E_VEH_FUEL_ML,
    E_VEH_MAX_FUEL_ML,
    Float:E_VEH_ENGINE_HP,
    Float:E_VEH_BODY_HP,
    E_VEH_MILEAGE_METERS,
    E_VEH_GLOVEBOX_DB_ID,
    E_VEH_TRUNK_DB_ID,
    E_VEH_GLOVEBOX_SLOT,
    E_VEH_TRUNK_SLOT,
    E_VEH_COLOR1,
    E_VEH_COLOR2,
    Float:E_VEH_POS_X,
    Float:E_VEH_POS_Y,
    Float:E_VEH_POS_Z,
    Float:E_VEH_POS_A,
    Float:E_VEH_SPAWN_X,
    Float:E_VEH_SPAWN_Y,
    Float:E_VEH_SPAWN_Z,
    Float:E_VEH_SPAWN_A,
    E_VEH_GARAGE_PROPERTY_ID,
    E_VEH_RUNTIME_ID,
    bool:E_VEH_LOCKED,
    bool:E_VEH_WINDOW_BROKEN,
    bool:E_VEH_HOTWIRED,
    bool:E_VEH_ENGINE_ON,
    bool:E_VEH_FUEL_WARNED,
    E_VEH_LAST_PERSIST_TICK
};

static stock sVehicles[MAX_VEHICLES_SERVER][E_VEHICLE_DATA];
new Iterator:VehicleDataIter<MAX_VEHICLES_SERVER>;
static stock sRuntimeVehicleSlot[MAX_VEHICLES_SERVER];
static stock sNextVehicleDbId = 1;

static stock sVehicleLastCommandTick[MAX_PLAYERS];
static stock sVehicleLastHotwireTick[MAX_PLAYERS];
static stock sVehicleRefuelStation[MAX_PLAYERS];
static stock sVehicleRefuelWarehouse[MAX_PLAYERS];
static stock sVehicleRefuelSlot[MAX_PLAYERS];
static stock E_FUEL_TYPE:sVehicleRefuelType[MAX_PLAYERS];
static stock sVehicleHotwireAnswer[MAX_PLAYERS];
static stock sVehicleChopVehicle[MAX_PLAYERS];
static stock sVehicleChopEnterprise[MAX_PLAYERS];
static stock sVehicleChopWarehouse[MAX_PLAYERS];
static stock sVehicleGarageProperty[MAX_PLAYERS];
static stock sVehicleUnparkRowMap[MAX_PLAYERS][32];
static stock sVehicleUnparkRowCount[MAX_PLAYERS];
static stock STREAMER_TAG_3D_TEXT_LABEL:sDealershipLabel[VEHICLE_DEALERSHIP_COUNT];

static stock const sVehicleCatalog[VEHICLE_CATALOG_SIZE][E_VEHICLE_CATALOG_DATA] =
{
    { 400, "Лендсталкер",       25000,  FUEL_REGULAR, VEHICLE_DEFAULT_MAX_FUEL_ML },
    { 410, "Манана",            18000,  FUEL_REGULAR, VEHICLE_DEFAULT_MAX_FUEL_ML },
    { 429, "Банши",             95000,  FUEL_REGULAR, VEHICLE_DEFAULT_MAX_FUEL_ML },
    { 411, "Инфернус",          250000, FUEL_REGULAR, VEHICLE_DEFAULT_MAX_FUEL_ML },
    { 522, "Мотоцикл NRG-500",  60000,  FUEL_REGULAR, 40000 },
    { 461, "Мотоцикл PCJ-600",  45000,  FUEL_REGULAR, 40000 },
    { 466, "Глендейл",          20000,  FUEL_REGULAR, VEHICLE_DEFAULT_MAX_FUEL_ML },
    { 492, "Гринвуд",           22000,  FUEL_REGULAR, VEHICLE_DEFAULT_MAX_FUEL_ML },
    { 500, "Меса",              35000,  FUEL_REGULAR, VEHICLE_DEFAULT_MAX_FUEL_ML },
    { 554, "Йосемити",          40000,  FUEL_DIESEL,  VEHICLE_TRUCK_MAX_FUEL_ML },
    { 403, "Грузовик Лайнер",   120000, FUEL_DIESEL,  VEHICLE_TRUCK_MAX_FUEL_ML },
    { 414, "Фургон Мул",        90000,  FUEL_DIESEL,  VEHICLE_TRUCK_MAX_FUEL_ML },
    { 456, "Фургон Янки",       80000,  FUEL_DIESEL,  VEHICLE_TRUCK_MAX_FUEL_ML },
    { 514, "Топливная цистерна",180000, FUEL_DIESEL,  VEHICLE_TANKER_MAX_FUEL_ML }
};

static stock const Float:sVehicleDealerships[VEHICLE_DEALERSHIP_COUNT][3] =
{
    { 2135.0, 1398.0, 10.8 },       // Автосалон Лос-Сантоса
    { -1980.0, 120.0, 27.7 },       // Автосалон Сан-Фиерро
    { 2145.0, 1400.0, 10.8 }        // Автосалон Лас-Вентураса
};

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (static stock)
// =============================================================================

static stock Internal_GetOwnerTypeString(E_VEHICLE_OWNER_TYPE:ownerType, output[], len = sizeof(output))
{
    switch (ownerType)
    {
        case VEHICLE_OWNER_CHARACTER:   format(output, len, "CHARACTER");
        case VEHICLE_OWNER_ORGANIZATION: format(output, len, "ORGANIZATION");
        case VEHICLE_OWNER_STATE_FLEET: format(output, len, "STATE_FLEET");
        default:                        format(output, len, "STATE_FLEET");
    }
    return 1;
}

static stock E_VEHICLE_OWNER_TYPE:Internal_ParseOwnerType(const ownerStr[])
{
    if (!strcmp(ownerStr, "CHARACTER", true))   return VEHICLE_OWNER_CHARACTER;
    if (!strcmp(ownerStr, "ORGANIZATION", true)) return VEHICLE_OWNER_ORGANIZATION;
    return VEHICLE_OWNER_STATE_FLEET;
}

static stock Internal_GetFuelTypeString(E_FUEL_TYPE:fuelType, output[], len = sizeof(output))
{
    switch (fuelType)
    {
        case FUEL_REGULAR:  format(output, len, "REGULAR");
        case FUEL_DIESEL:   format(output, len, "DIESEL");
        case FUEL_JET_FUEL: format(output, len, "JET_FUEL");
        default:            format(output, len, "REGULAR");
    }
    return 1;
}

static stock E_FUEL_TYPE:Internal_ParseFuelType(const fuelStr[])
{
    if (!strcmp(fuelStr, "DIESEL", true))   return FUEL_DIESEL;
    if (!strcmp(fuelStr, "JET_FUEL", true)) return FUEL_JET_FUEL;
    return FUEL_REGULAR;
}

static stock Internal_GetFuelTitleRu(E_FUEL_TYPE:fuelType, output[], len = sizeof(output))
{
    switch (fuelType)
    {
        case FUEL_REGULAR:  format(output, len, "Бензин (Regular)");
        case FUEL_DIESEL:   format(output, len, "Дизельное топливо");
        case FUEL_JET_FUEL: format(output, len, "Авиационный керосин");
        default:            format(output, len, "Неизвестное топливо");
    }
    return 1;
}

static stock Internal_GetFuelPriceUsd(E_FUEL_TYPE:fuelType)
{
    switch (fuelType)
    {
        case FUEL_REGULAR:  return VEHICLE_FUEL_PRICE_REGULAR_USD;
        case FUEL_DIESEL:   return VEHICLE_FUEL_PRICE_DIESEL_USD;
        case FUEL_JET_FUEL: return VEHICLE_FUEL_PRICE_JET_USD;
    }
    return VEHICLE_FUEL_PRICE_REGULAR_USD;
}

static stock Internal_GetFuelTypeFromCatalog(model_id, &E_FUEL_TYPE:fuelType, &maxFuelMl)
{
    for (new i = 0; i < VEHICLE_CATALOG_SIZE; i++)
    {
        if (sVehicleCatalog[i][E_VC_MODEL] == model_id)
        {
            fuelType = sVehicleCatalog[i][E_VC_FUEL];
            maxFuelMl = sVehicleCatalog[i][E_VC_MAX_FUEL_ML];
            return 1;
        }
    }
    fuelType = FUEL_REGULAR;
    maxFuelMl = VEHICLE_DEFAULT_MAX_FUEL_ML;
    return 0;
}

static stock Internal_GetCatalogName(model_id, output[], len = sizeof(output))
{
    output[0] = EOS;
    for (new i = 0; i < VEHICLE_CATALOG_SIZE; i++)
    {
        if (sVehicleCatalog[i][E_VC_MODEL] == model_id)
        {
            format(output, len, "%s", sVehicleCatalog[i][E_VC_NAME]);
            return 1;
        }
    }
    format(output, len, "Транспортное средство (модель %d)", model_id);
    return 0;
}

static stock const sTrunkCapacities[10][2] =
{
    { 403, 32000 }, { 414, 12000 }, { 455, 22000 }, { 456, 15000 }, { 498, 10000 },
    { 499, 20000 }, { 514, 30000 }, { 515, 30000 }, { 524, 25000 }, { 525, 8000 }
};

static stock Internal_GetTrunkCapacity(model_id, &weightG, &volumeMl)
{
    for (new i = 0; i < 10; i++)
    {
        if (sTrunkCapacities[i][0] == model_id)
        {
            weightG = sTrunkCapacities[i][1] * 1000;
            volumeMl = sTrunkCapacities[i][1] * 1000;
            return 1;
        }
    }

    if (model_id == 461 || model_id == 462 || model_id == 463 || model_id == 468 ||
        model_id == 471 || model_id == 521 || model_id == 522 || model_id == 523 ||
        model_id == 581 || model_id == 586 || model_id == 509 || model_id == 510 ||
        model_id == 481)
    {
        weightG = VEHICLE_BIKE_TRUNK_WEIGHT_G;
        volumeMl = VEHICLE_BIKE_TRUNK_VOLUME_ML;
        return 1;
    }

    weightG = VEHICLE_DEFAULT_TRUNK_WEIGHT_G;
    volumeMl = VEHICLE_DEFAULT_TRUNK_VOLUME_ML;
    return 1;
}

static stock Internal_ResetVehicleSlot(slot)
{
    sVehicles[slot][E_VEH_VALID] = false;
    sVehicles[slot][E_VEH_DB_ID] = 0;
    sVehicles[slot][E_VEH_MODEL] = 0;
    sVehicles[slot][E_VEH_VIN][0] = EOS;
    sVehicles[slot][E_VEH_PLATE][0] = EOS;
    sVehicles[slot][E_VEH_OWNER_TYPE] = VEHICLE_OWNER_NONE;
    sVehicles[slot][E_VEH_OWNER_ID] = 0;
    sVehicles[slot][E_VEH_FUEL_TYPE] = FUEL_REGULAR;
    sVehicles[slot][E_VEH_FUEL_ML] = 0;
    sVehicles[slot][E_VEH_MAX_FUEL_ML] = VEHICLE_DEFAULT_MAX_FUEL_ML;
    sVehicles[slot][E_VEH_ENGINE_HP] = 1000.0;
    sVehicles[slot][E_VEH_BODY_HP] = 1000.0;
    sVehicles[slot][E_VEH_MILEAGE_METERS] = 0;
    sVehicles[slot][E_VEH_GLOVEBOX_DB_ID] = 0;
    sVehicles[slot][E_VEH_TRUNK_DB_ID] = 0;
    sVehicles[slot][E_VEH_GLOVEBOX_SLOT] = INVALID_STORAGE_SLOT;
    sVehicles[slot][E_VEH_TRUNK_SLOT] = INVALID_STORAGE_SLOT;
    sVehicles[slot][E_VEH_COLOR1] = 1;
    sVehicles[slot][E_VEH_COLOR2] = 1;
    sVehicles[slot][E_VEH_POS_X] = 0.0;
    sVehicles[slot][E_VEH_POS_Y] = 0.0;
    sVehicles[slot][E_VEH_POS_Z] = 0.0;
    sVehicles[slot][E_VEH_POS_A] = 0.0;
    sVehicles[slot][E_VEH_SPAWN_X] = 0.0;
    sVehicles[slot][E_VEH_SPAWN_Y] = 0.0;
    sVehicles[slot][E_VEH_SPAWN_Z] = 0.0;
    sVehicles[slot][E_VEH_SPAWN_A] = 0.0;
    sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID] = 0;
    sVehicles[slot][E_VEH_RUNTIME_ID] = INVALID_VEHICLE_ID;
    sVehicles[slot][E_VEH_LOCKED] = false;
    sVehicles[slot][E_VEH_WINDOW_BROKEN] = false;
    sVehicles[slot][E_VEH_HOTWIRED] = false;
    sVehicles[slot][E_VEH_ENGINE_ON] = false;
    sVehicles[slot][E_VEH_FUEL_WARNED] = false;
    sVehicles[slot][E_VEH_LAST_PERSIST_TICK] = 0;
    return 1;
}

static stock Internal_FindSlotByRuntime(vehicleid)
{
    if (vehicleid <= 0 || vehicleid >= MAX_VEHICLES_SERVER || !IsValidVehicle(vehicleid))
    {
        return -1;
    }
    new const slot = sRuntimeVehicleSlot[vehicleid];
    if (slot >= 0 && slot < MAX_VEHICLES_SERVER &&
        sVehicles[slot][E_VEH_VALID] &&
        sVehicles[slot][E_VEH_RUNTIME_ID] == vehicleid)
    {
        return slot;
    }
    return -1;
}

stock Vehicle_GetRuntimeId(slot)
{
    if (slot < 0 || slot >= MAX_VEHICLES_SERVER || !sVehicles[slot][E_VEH_VALID])
    {
        return INVALID_VEHICLE_ID;
    }
    return sVehicles[slot][E_VEH_RUNTIME_ID];
}

stock bool:Vehicle_IsValidSlot(slot)
{
    return (slot >= 0 && slot < MAX_VEHICLES_SERVER && sVehicles[slot][E_VEH_VALID]);
}

stock Vehicle_GetDbId(slot)
{
    if (!Vehicle_IsValidSlot(slot))
    {
        return 0;
    }
    return sVehicles[slot][E_VEH_DB_ID];
}

stock Vehicle_GetModel(slot)
{
    if (!Vehicle_IsValidSlot(slot))
    {
        return 0;
    }
    return sVehicles[slot][E_VEH_MODEL];
}

stock Vehicle_GetOwnerCharId(slot)
{
    if (!Vehicle_IsValidSlot(slot) || sVehicles[slot][E_VEH_OWNER_TYPE] != VEHICLE_OWNER_CHARACTER)
    {
        return 0;
    }
    return sVehicles[slot][E_VEH_OWNER_ID];
}

static stock Internal_EnsureStorage(slot, bool:isTrunk)
{
    if (!Vehicle_IsValidSlot(slot))
    {
        return INVALID_STORAGE_SLOT;
    }

    new weightG, volumeMl;
    if (isTrunk)
    {
        new existing = sVehicles[slot][E_VEH_TRUNK_SLOT];
        if (Storage_IsValidSlot(existing))
        {
            return existing;
        }

        Internal_GetTrunkCapacity(sVehicles[slot][E_VEH_MODEL], weightG, volumeMl);
        new dbId = sVehicles[slot][E_VEH_TRUNK_DB_ID];
        new created = INVALID_STORAGE_SLOT;
        if (dbId > 0)
        {
            created = Storage_FindByDbId(dbId);
        }
        if (created != INVALID_STORAGE_SLOT)
        {
            sVehicles[slot][E_VEH_TRUNK_SLOT] = created;
            return created;
        }
        if (dbId > 0)
        {
            created = Storage_Create(
                STORAGE_VEHICLE_TRUNK,
                0,
                weightG,
                volumeMl,
                false,
                0,
                sVehicles[slot][E_VEH_SPAWN_X],
                sVehicles[slot][E_VEH_SPAWN_Y],
                sVehicles[slot][E_VEH_SPAWN_Z],
                0,
                0,
                0,
                dbId);
        }
        else
        {
            created = Storage_Create(
                STORAGE_VEHICLE_TRUNK,
                0,
                weightG,
                volumeMl,
                false,
                0,
                sVehicles[slot][E_VEH_SPAWN_X],
                sVehicles[slot][E_VEH_SPAWN_Y],
                sVehicles[slot][E_VEH_SPAWN_Z]);
            if (created != INVALID_STORAGE_SLOT)
            {
                sVehicles[slot][E_VEH_TRUNK_DB_ID] = Storage_GetDbId(created);
            }
        }
        sVehicles[slot][E_VEH_TRUNK_SLOT] = created;
        return created;
    }

    new existing = sVehicles[slot][E_VEH_GLOVEBOX_SLOT];
    if (Storage_IsValidSlot(existing))
    {
        return existing;
    }

    new dbId = sVehicles[slot][E_VEH_GLOVEBOX_DB_ID];
    new created = INVALID_STORAGE_SLOT;
    if (dbId > 0)
    {
        created = Storage_FindByDbId(dbId);
    }
    if (created != INVALID_STORAGE_SLOT)
    {
        sVehicles[slot][E_VEH_GLOVEBOX_SLOT] = created;
        return created;
    }
    if (dbId > 0)
    {
        created = Storage_Create(
            STORAGE_VEHICLE_GLOVEBOX,
            0,
            VEHICLE_GLOVEBOX_WEIGHT_G,
            VEHICLE_GLOVEBOX_VOLUME_ML,
            false,
            0,
            sVehicles[slot][E_VEH_SPAWN_X],
            sVehicles[slot][E_VEH_SPAWN_Y],
            sVehicles[slot][E_VEH_SPAWN_Z],
            0,
            0,
            0,
            dbId);
    }
    else
    {
        created = Storage_Create(
            STORAGE_VEHICLE_GLOVEBOX,
            0,
            VEHICLE_GLOVEBOX_WEIGHT_G,
            VEHICLE_GLOVEBOX_VOLUME_ML,
            false,
            0,
            sVehicles[slot][E_VEH_SPAWN_X],
            sVehicles[slot][E_VEH_SPAWN_Y],
            sVehicles[slot][E_VEH_SPAWN_Z]);
        if (created != INVALID_STORAGE_SLOT)
        {
            sVehicles[slot][E_VEH_GLOVEBOX_DB_ID] = Storage_GetDbId(created);
        }
    }
    sVehicles[slot][E_VEH_GLOVEBOX_SLOT] = created;
    return created;
}

stock Vehicle_GetTrunkSlot(slot)
{
    if (!Vehicle_IsValidSlot(slot))
    {
        return INVALID_STORAGE_SLOT;
    }
    return Internal_EnsureStorage(slot, true);
}

stock Vehicle_GetGloveboxSlot(slot)
{
    if (!Vehicle_IsValidSlot(slot))
    {
        return INVALID_STORAGE_SLOT;
    }
    return Internal_EnsureStorage(slot, false);
}

static stock Internal_ApplyVehicleParams(slot)
{
    if (!Vehicle_IsValidSlot(slot))
    {
        return 0;
    }
    new const vid = sVehicles[slot][E_VEH_RUNTIME_ID];
    if (vid == INVALID_VEHICLE_ID || !IsValidVehicle(vid))
    {
        return 0;
    }

    new engine = sVehicles[slot][E_VEH_ENGINE_ON] ? 1 : 0;
    new doors = sVehicles[slot][E_VEH_LOCKED] ? 1 : 0;
    SetVehicleParamsEx(vid, engine, 0, 0, doors, 0, 0, 0);
    return 1;
}

static stock Vehicle_SpawnSlot(slot)
{
    if (!Vehicle_IsValidSlot(slot))
    {
        return 0;
    }
    if (sVehicles[slot][E_VEH_RUNTIME_ID] != INVALID_VEHICLE_ID &&
        IsValidVehicle(sVehicles[slot][E_VEH_RUNTIME_ID]))
    {
        return 1;
    }

    new const vid = CreateVehicle(
        sVehicles[slot][E_VEH_MODEL],
        sVehicles[slot][E_VEH_SPAWN_X],
        sVehicles[slot][E_VEH_SPAWN_Y],
        sVehicles[slot][E_VEH_SPAWN_Z],
        sVehicles[slot][E_VEH_SPAWN_A],
        sVehicles[slot][E_VEH_COLOR1],
        sVehicles[slot][E_VEH_COLOR2],
        -1);

    if (vid == INVALID_VEHICLE_ID)
    {
        return 0;
    }

    sVehicles[slot][E_VEH_RUNTIME_ID] = vid;
    if (vid >= 0 && vid < MAX_VEHICLES_SERVER)
    {
        sRuntimeVehicleSlot[vid] = slot;
    }

    SetVehicleNumberPlate(vid, sVehicles[slot][E_VEH_PLATE]);
    new Float:bodyHealth = sVehicles[slot][E_VEH_BODY_HP];
    if (bodyHealth < 1.0) bodyHealth = 1.0;
    if (bodyHealth > 1000.0) bodyHealth = 1000.0;
    SetVehicleHealth(vid, bodyHealth);

    sVehicles[slot][E_VEH_LOCKED] = (sVehicles[slot][E_VEH_OWNER_TYPE] != VEHICLE_OWNER_STATE_FLEET);
    sVehicles[slot][E_VEH_ENGINE_ON] = false;
    sVehicles[slot][E_VEH_HOTWIRED] = false;
    sVehicles[slot][E_VEH_FUEL_WARNED] = false;

    new glovebox = Internal_EnsureStorage(slot, false);
    new trunk = Internal_EnsureStorage(slot, true);
    if (Storage_IsValidSlot(glovebox) && Storage_GetOwnerId(glovebox) != vid)
    {
        Storage_SetOwnerId(glovebox, vid);
    }
    if (Storage_IsValidSlot(trunk) && Storage_GetOwnerId(trunk) != vid)
    {
        Storage_SetOwnerId(trunk, vid);
    }

    Internal_ApplyVehicleParams(slot);
    return 1;
}

stock Vehicle_DespawnSlot(slot)
{
    if (!Vehicle_IsValidSlot(slot))
    {
        return 0;
    }
    new const vid = sVehicles[slot][E_VEH_RUNTIME_ID];
    if (vid != INVALID_VEHICLE_ID && IsValidVehicle(vid))
    {
        DestroyVehicle(vid);
    }
    if (vid >= 0 && vid < MAX_VEHICLES_SERVER)
    {
        sRuntimeVehicleSlot[vid] = -1;
    }
    sVehicles[slot][E_VEH_RUNTIME_ID] = INVALID_VEHICLE_ID;
    sVehicles[slot][E_VEH_ENGINE_ON] = false;
    sVehicles[slot][E_VEH_HOTWIRED] = false;
    return 1;
}

stock Vehicle_SaveSlot(slot)
{
    if (!Vehicle_IsValidSlot(slot))
    {
        return 0;
    }

    new const vid = sVehicles[slot][E_VEH_RUNTIME_ID];
    if (vid != INVALID_VEHICLE_ID && IsValidVehicle(vid))
    {
        new Float:x, Float:y, Float:z, Float:a, Float:health;
        GetVehiclePos(vid, x, y, z);
        GetVehicleZAngle(vid, a);
        if (GetVehicleHealth(vid, health))
        {
            sVehicles[slot][E_VEH_BODY_HP] = health;
        }
        sVehicles[slot][E_VEH_POS_X] = x;
        sVehicles[slot][E_VEH_POS_Y] = y;
        sVehicles[slot][E_VEH_POS_Z] = z;
        sVehicles[slot][E_VEH_POS_A] = a;
    }

    sVehicles[slot][E_VEH_LAST_PERSIST_TICK] = GetTickCount();

    if (DB_IsConnected())
    {
        new fuelStr[16], garageSql[16];
        Internal_GetFuelTypeString(sVehicles[slot][E_VEH_FUEL_TYPE], fuelStr, sizeof(fuelStr));
        if (sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID] > 0)
        {
            format(garageSql, sizeof(garageSql), "%d", sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID]);
        }
        else
        {
            format(garageSql, sizeof(garageSql), "NULL");
        }

        new query[768];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `vehicles` SET `fuel_ml` = %d, `max_fuel_ml` = %d, `engine_hp` = %.2f, `body_hp` = %.2f, `mileage_meters` = %d, `garage_property_id` = %s, `pos_x` = %.3f, `pos_y` = %.3f, `pos_z` = %.3f, `pos_a` = %.3f WHERE `id` = %d;",
            sVehicles[slot][E_VEH_FUEL_ML],
            sVehicles[slot][E_VEH_MAX_FUEL_ML],
            sVehicles[slot][E_VEH_ENGINE_HP],
            sVehicles[slot][E_VEH_BODY_HP],
            sVehicles[slot][E_VEH_MILEAGE_METERS],
            garageSql,
            sVehicles[slot][E_VEH_POS_X],
            sVehicles[slot][E_VEH_POS_Y],
            sVehicles[slot][E_VEH_POS_Z],
            sVehicles[slot][E_VEH_POS_A],
            sVehicles[slot][E_VEH_DB_ID]);
        mysql_tquery(gMySQL, query);
    }
    return 1;
}

static stock bool:Internal_PlayerHasItemDef(playerid, def_id)
{
    new slots[2];
    slots[0] = Character_GetLayer1Slot(playerid);
    slots[1] = Character_GetLayer2Slot(playerid);

    for (new s = 0; s < 2; s++)
    {
        if (!Storage_IsValidSlot(slots[s]))
        {
            continue;
        }
        new itemSlot = Storage_GetFirstItemSlot(slots[s]);
        while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
        {
            if (Storage_GetItemDefId(itemSlot) == def_id)
            {
                return true;
            }
            itemSlot = Storage_GetNextItemSlot(itemSlot);
        }
    }
    return false;
}

static stock bool:Internal_PlayerHasVehicleKey(playerid, slot)
{
    if (!Vehicle_IsValidSlot(slot))
    {
        return false;
    }

    new const dbId = sVehicles[slot][E_VEH_DB_ID];
    if (dbId <= 0)
    {
        return false;
    }

    new slots[2];
    slots[0] = Character_GetLayer1Slot(playerid);
    slots[1] = Character_GetLayer2Slot(playerid);

    for (new s = 0; s < 2; s++)
    {
        if (!Storage_IsValidSlot(slots[s]))
        {
            continue;
        }
        new itemSlot = Storage_GetFirstItemSlot(slots[s]);
        while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
        {
            if (Storage_GetItemDefId(itemSlot) == ITEM_ID_VEHICLE_KEY &&
                Storage_GetItemMetaInt1(itemSlot) == dbId)
            {
                return true;
            }
            itemSlot = Storage_GetNextItemSlot(itemSlot);
        }
    }
    return false;
}

stock bool:Vehicle_PlayerHasKey(playerid, slot)
{
    return Internal_PlayerHasVehicleKey(playerid, slot);
}

static stock bool:Internal_IssueKey(playerid, slot, bool:notify)
{
    if (!Vehicle_IsValidSlot(slot))
    {
        return false;
    }

    new layer1 = Character_GetLayer1Slot(playerid);
    new layer2 = Character_GetLayer2Slot(playerid);
    new targetStorage = layer1;
    if (!Storage_IsValidSlot(targetStorage))
    {
        targetStorage = layer2;
    }
    if (!Storage_IsValidSlot(targetStorage))
    {
        return false;
    }

    new keyMeta[32];
    format(keyMeta, sizeof(keyMeta), "AUTO-%s", sVehicles[slot][E_VEH_PLATE]);
    new outItem = INVALID_STORAGE_ITEM_SLOT;
    new E_STORAGE_RESULT:result = Storage_AddItem(
        targetStorage,
        ITEM_ID_VEHICLE_KEY,
        1,
        0,
        100.0,
        sVehicles[slot][E_VEH_DB_ID],
        0,
        keyMeta,
        outItem);

    if (result != STORAGE_RES_OK && Storage_IsValidSlot(layer2) && targetStorage != layer2)
    {
        result = Storage_AddItem(
            layer2,
            ITEM_ID_VEHICLE_KEY,
            1,
            0,
            100.0,
            sVehicles[slot][E_VEH_DB_ID],
            0,
            keyMeta,
            outItem);
    }

    if (result == STORAGE_RES_OK && notify)
    {
        SendClientMessage(playerid, COLOR_UI_SUCCESS,
            "Ключи от транспортного средства выданы и помещены в инвентарь.");
    }
    return (result == STORAGE_RES_OK);
}

static stock Internal_GetNearestVehicle(playerid, Float:radius, &runtimeVehicle, &slot)
{
    runtimeVehicle = INVALID_VEHICLE_ID;
    slot = -1;

    if (!IsPlayerConnected(playerid))
    {
        return 0;
    }

    if (IsPlayerInAnyVehicle(playerid))
    {
        new const vid = GetPlayerVehicleID(playerid);
        new const ridingSlot = Internal_FindSlotByRuntime(vid);
        if (ridingSlot >= 0)
        {
            runtimeVehicle = vid;
            slot = ridingSlot;
            return 1;
        }
    }

    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);

    new bestSlot = -1;
    new bestVehicle = INVALID_VEHICLE_ID;
    new Float:bestDistance = radius + 0.001;

    foreach (new vehicleSlot : VehicleDataIter)
    {
        if (!sVehicles[vehicleSlot][E_VEH_VALID])
        {
            continue;
        }
        new const vid = sVehicles[vehicleSlot][E_VEH_RUNTIME_ID];
        if (vid == INVALID_VEHICLE_ID || !IsValidVehicle(vid))
        {
            continue;
        }

        new Float:vx, Float:vy, Float:vz;
        GetVehiclePos(vid, vx, vy, vz);
        new const Float:dist = Utils_GetDistance3D(px, py, pz, vx, vy, vz);
        if (dist <= bestDistance)
        {
            bestDistance = dist;
            bestVehicle = vid;
            bestSlot = vehicleSlot;
        }
    }

    runtimeVehicle = bestVehicle;
    slot = bestSlot;
    return (bestSlot >= 0);
}

static stock Internal_GetNearestOwnedVehicle(playerid, Float:radius, &slot)
{
    slot = -1;
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    new const charId = Character_GetId(playerid);
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    new Float:bestDistance = radius + 0.001;

    foreach (new vehicleSlot : VehicleDataIter)
    {
        if (!sVehicles[vehicleSlot][E_VEH_VALID] ||
            sVehicles[vehicleSlot][E_VEH_OWNER_TYPE] != VEHICLE_OWNER_CHARACTER ||
            sVehicles[vehicleSlot][E_VEH_OWNER_ID] != charId)
        {
            continue;
        }
        new const vid = sVehicles[vehicleSlot][E_VEH_RUNTIME_ID];
        if (vid == INVALID_VEHICLE_ID || !IsValidVehicle(vid))
        {
            continue;
        }
        new Float:vx, Float:vy, Float:vz;
        GetVehiclePos(vid, vx, vy, vz);
        new const Float:dist = Utils_GetDistance3D(px, py, pz, vx, vy, vz);
        if (dist <= bestDistance)
        {
            bestDistance = dist;
            slot = vehicleSlot;
        }
    }
    return (slot >= 0);
}

static stock bool:Internal_PlayerNearDealership(playerid)
{
    for (new i = 0; i < VEHICLE_DEALERSHIP_COUNT; i++)
    {
        if (Utils_IsPlayerNearPoint(playerid, VEHICLE_DEALERSHIP_RADIUS,
            sVehicleDealerships[i][0], sVehicleDealerships[i][1], sVehicleDealerships[i][2]))
        {
            return true;
        }
    }
    return false;
}

// Вспомогательная функция для диалогов суммы топлива
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

static stock Internal_CommandAllowed(playerid)
{
    new const nowTick = GetTickCount();
    if ((nowTick - sVehicleLastCommandTick[playerid]) < VEHICLE_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "Не так быстро: дождитесь завершения предыдущей операции.");
        return false;
    }
    sVehicleLastCommandTick[playerid] = nowTick;
    return true;
}

static stock Internal_AddVehicle(
    db_id,
    model_id,
    const vin[],
    const plate[],
    E_VEHICLE_OWNER_TYPE:ownerType,
    owner_id,
    E_FUEL_TYPE:fuelType,
    fuel_ml,
    max_fuel_ml,
    Float:engine_hp,
    Float:body_hp,
    mileage,
    glovebox_db_id,
    trunk_db_id,
    color1,
    color2,
    Float:pos_x,
    Float:pos_y,
    Float:pos_z,
    Float:pos_a,
    garage_property_id)
{
    new const slot = Iter_Free(VehicleDataIter);
    if (slot == INVALID_ITERATOR_SLOT)
    {
        return -1;
    }

    Iter_Add(VehicleDataIter, slot);
    Internal_ResetVehicleSlot(slot);

    sVehicles[slot][E_VEH_VALID] = true;
    sVehicles[slot][E_VEH_DB_ID] = db_id;
    sVehicles[slot][E_VEH_MODEL] = model_id;
    format(sVehicles[slot][E_VEH_VIN], VEHICLE_VIN_LEN, "%s", vin);
    format(sVehicles[slot][E_VEH_PLATE], VEHICLE_PLATE_LEN, "%s", plate);
    sVehicles[slot][E_VEH_OWNER_TYPE] = ownerType;
    sVehicles[slot][E_VEH_OWNER_ID] = owner_id;
    sVehicles[slot][E_VEH_FUEL_TYPE] = fuelType;
    sVehicles[slot][E_VEH_FUEL_ML] = fuel_ml;
    sVehicles[slot][E_VEH_MAX_FUEL_ML] = max_fuel_ml;
    sVehicles[slot][E_VEH_ENGINE_HP] = engine_hp;
    sVehicles[slot][E_VEH_BODY_HP] = body_hp;
    sVehicles[slot][E_VEH_MILEAGE_METERS] = mileage;
    sVehicles[slot][E_VEH_GLOVEBOX_DB_ID] = glovebox_db_id;
    sVehicles[slot][E_VEH_TRUNK_DB_ID] = trunk_db_id;
    sVehicles[slot][E_VEH_COLOR1] = color1;
    sVehicles[slot][E_VEH_COLOR2] = color2;
    sVehicles[slot][E_VEH_POS_X] = pos_x;
    sVehicles[slot][E_VEH_POS_Y] = pos_y;
    sVehicles[slot][E_VEH_POS_Z] = pos_z;
    sVehicles[slot][E_VEH_POS_A] = pos_a;
    sVehicles[slot][E_VEH_SPAWN_X] = pos_x;
    sVehicles[slot][E_VEH_SPAWN_Y] = pos_y;
    sVehicles[slot][E_VEH_SPAWN_Z] = pos_z;
    sVehicles[slot][E_VEH_SPAWN_A] = pos_a;
    sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID] = garage_property_id;
    sVehicles[slot][E_VEH_RUNTIME_ID] = INVALID_VEHICLE_ID;
    return slot;
}

static stock Internal_GeneratePlate(output[], len = sizeof(output))
{
    new candidate[VEHICLE_PLATE_LEN];
    for (new attempt = 0; attempt < 50; attempt++)
    {
        format(candidate, sizeof(candidate), "SA-%d", 1000 + random(9000));
        new bool:exists = false;
        foreach (new slot : VehicleDataIter)
        {
            if (sVehicles[slot][E_VEH_VALID] && !strcmp(sVehicles[slot][E_VEH_PLATE], candidate, true))
            {
                exists = true;
                break;
            }
        }
        if (!exists)
        {
            format(output, len, "%s", candidate);
            return 1;
        }
    }
    format(output, len, "SA-%d", 1000 + random(9000));
    return 1;
}

static stock Internal_InsertVehicleDb(slot)
{
    if (!Vehicle_IsValidSlot(slot) || !DB_IsConnected())
    {
        return 0;
    }

    new ownerStr[24], fuelStr[24], garageSql[16];
    Internal_GetOwnerTypeString(sVehicles[slot][E_VEH_OWNER_TYPE], ownerStr, sizeof(ownerStr));
    Internal_GetFuelTypeString(sVehicles[slot][E_VEH_FUEL_TYPE], fuelStr, sizeof(fuelStr));
    if (sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID] > 0)
    {
        format(garageSql, sizeof(garageSql), "%d", sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID]);
    }
    else
    {
        format(garageSql, sizeof(garageSql), "NULL");
    }

    new query[896];
    mysql_format(gMySQL, query, sizeof(query),
        "INSERT INTO `vehicles` (`id`, `model_id`, `vin`, `plate`, `owner_type`, `owner_id`, `fuel_type`, `fuel_ml`, `max_fuel_ml`, `engine_hp`, `body_hp`, `mileage_meters`, `glovebox_storage_id`, `trunk_storage_id`, `color1`, `color2`, `pos_x`, `pos_y`, `pos_z`, `pos_a`, `garage_property_id`) VALUES (%d, %d, '%e', '%e', '%e', %d, '%e', %d, %d, %.2f, %.2f, %d, %d, %d, %d, %d, %.3f, %.3f, %.3f, %.3f, %s);",
        sVehicles[slot][E_VEH_DB_ID],
        sVehicles[slot][E_VEH_MODEL],
        sVehicles[slot][E_VEH_VIN],
        sVehicles[slot][E_VEH_PLATE],
        ownerStr,
        sVehicles[slot][E_VEH_OWNER_ID],
        fuelStr,
        sVehicles[slot][E_VEH_FUEL_ML],
        sVehicles[slot][E_VEH_MAX_FUEL_ML],
        sVehicles[slot][E_VEH_ENGINE_HP],
        sVehicles[slot][E_VEH_BODY_HP],
        sVehicles[slot][E_VEH_MILEAGE_METERS],
        sVehicles[slot][E_VEH_GLOVEBOX_DB_ID],
        sVehicles[slot][E_VEH_TRUNK_DB_ID],
        sVehicles[slot][E_VEH_COLOR1],
        sVehicles[slot][E_VEH_COLOR2],
        sVehicles[slot][E_VEH_POS_X],
        sVehicles[slot][E_VEH_POS_Y],
        sVehicles[slot][E_VEH_POS_Z],
        sVehicles[slot][E_VEH_POS_A],
        garageSql);
    mysql_pquery(gMySQL, query);
    return 1;
}

stock Vehicle_CreateForPlayer(playerid, model_id, price_usd, bool:chargePlayer = true)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return -1;
    }
    if (chargePlayer && price_usd > 0 &&
        Banking_GetBalance(playerid) < price_usd &&
        Character_GetPhysicalCashUsd(playerid) < price_usd)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Недостаточно средств: оплата возможна с банковского счета или наличными.");
        return -1;
    }
    if (Iter_Free(VehicleDataIter) == INVALID_ITERATOR_SLOT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Пул транспорта переполнен.");
        return -1;
    }

    new E_FUEL_TYPE:fuelType;
    new maxFuelMl;
    Internal_GetFuelTypeFromCatalog(model_id, fuelType, maxFuelMl);

    new const slot = Iter_Free(VehicleDataIter);
    Iter_Add(VehicleDataIter, slot);
    Internal_ResetVehicleSlot(slot);

    new vin[VEHICLE_VIN_LEN], plate[VEHICLE_PLATE_LEN];
    Utils_GenerateVIN(vin, sizeof(vin));
    Internal_GeneratePlate(plate, sizeof(plate));

    new Float:px, Float:py, Float:pz, Float:pa;
    GetPlayerPos(playerid, px, py, pz);
    GetPlayerFacingAngle(playerid, pa);
    px += (floatsin(-pa, degrees) * 6.0);
    py += (floatcos(-pa, degrees) * 6.0);

    sVehicles[slot][E_VEH_VALID] = true;
    sVehicles[slot][E_VEH_DB_ID] = sNextVehicleDbId++;
    sVehicles[slot][E_VEH_MODEL] = model_id;
    format(sVehicles[slot][E_VEH_VIN], VEHICLE_VIN_LEN, "%s", vin);
    format(sVehicles[slot][E_VEH_PLATE], VEHICLE_PLATE_LEN, "%s", plate);
    sVehicles[slot][E_VEH_OWNER_TYPE] = VEHICLE_OWNER_CHARACTER;
    sVehicles[slot][E_VEH_OWNER_ID] = Character_GetId(playerid);
    sVehicles[slot][E_VEH_FUEL_TYPE] = fuelType;
    sVehicles[slot][E_VEH_FUEL_ML] = maxFuelMl;
    sVehicles[slot][E_VEH_MAX_FUEL_ML] = maxFuelMl;
    sVehicles[slot][E_VEH_ENGINE_HP] = 1000.0;
    sVehicles[slot][E_VEH_BODY_HP] = 1000.0;
    sVehicles[slot][E_VEH_MILEAGE_METERS] = 0;
    sVehicles[slot][E_VEH_COLOR1] = 1 + random(120);
    sVehicles[slot][E_VEH_COLOR2] = 1 + random(120);
    sVehicles[slot][E_VEH_POS_X] = px;
    sVehicles[slot][E_VEH_POS_Y] = py;
    sVehicles[slot][E_VEH_POS_Z] = pz;
    sVehicles[slot][E_VEH_POS_A] = pa;
    sVehicles[slot][E_VEH_SPAWN_X] = px;
    sVehicles[slot][E_VEH_SPAWN_Y] = py;
    sVehicles[slot][E_VEH_SPAWN_Z] = pz;
    sVehicles[slot][E_VEH_SPAWN_A] = pa;
    sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID] = 0;
    sVehicles[slot][E_VEH_RUNTIME_ID] = INVALID_VEHICLE_ID;

    Internal_EnsureStorage(slot, false);
    Internal_EnsureStorage(slot, true);

    if (chargePlayer && price_usd > 0)
    {
        if (!Banking_DebitAccount(playerid, price_usd, "Покупка транспортного средства"))
        {
            if (!Character_RemovePhysicalCashUsd(playerid, price_usd))
            {
                Internal_ResetVehicleSlot(slot);
                Iter_Remove(VehicleDataIter, slot);
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "Недостаточно средств: оплата возможна с банковского счета или наличными.");
                return -1;
            }
        }
    }

    Internal_InsertVehicleDb(slot);
    Vehicle_SpawnSlot(slot);
    new const bool:keyIssued = Internal_IssueKey(playerid, slot, false);

    new modelName[VEHICLE_MODEL_NAME_LEN], msg[256];
    Internal_GetCatalogName(model_id, modelName, sizeof(modelName));
    if (keyIssued)
    {
        format(msg, sizeof(msg),
            "Вы приобрели «%s» с номером %s. Ключи находятся в инвентаре.",
            modelName, sVehicles[slot][E_VEH_PLATE]);
    }
    else
    {
        format(msg, sizeof(msg),
            "Вы приобрели «%s» с номером %s. В инвентаре нет места для ключей: изготовьте их через /vkey.",
            modelName, sVehicles[slot][E_VEH_PLATE]);
    }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    Audit_Log(Character_GetId(playerid), "VEHICLE_BUY", "BANK", "VEHICLE", 0, price_usd,
        "Покупка личного транспортного средства");
    return slot;
}

stock Vehicle_StoreInGarage(slot, property_db_id)
{
    if (!Vehicle_IsValidSlot(slot) || property_db_id <= 0)
    {
        return 0;
    }
    sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID] = property_db_id;
    Vehicle_SaveSlot(slot);
    Vehicle_DespawnSlot(slot);
    return 1;
}

stock Vehicle_ReleaseGarage(property_db_id, Float:x, Float:y, Float:z, Float:a)
{
    if (property_db_id <= 0)
    {
        return 0;
    }
    new released = 0;
    foreach (new slot : VehicleDataIter)
    {
        if (sVehicles[slot][E_VEH_VALID] &&
            sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID] == property_db_id)
        {
            new const Float:offset = 3.0 + (released * 3.0);
            Vehicle_RetrieveFromGarage(slot, x + offset, y + offset, z, a);
            sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID] = 0;
            Vehicle_SaveSlot(slot);
            released++;
        }
    }
    return released;
}

stock Vehicle_CountInGarage(property_db_id)
{
    new count = 0;
    foreach (new slot : VehicleDataIter)
    {
        if (sVehicles[slot][E_VEH_VALID] &&
            sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID] == property_db_id)
        {
            count++;
        }
    }
    return count;
}

stock Vehicle_GetGarageList(property_db_id, owner_char_id, rows[], maxRows)
{
    new count = 0;
    foreach (new slot : VehicleDataIter)
    {
        if (!sVehicles[slot][E_VEH_VALID] ||
            sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID] != property_db_id ||
            sVehicles[slot][E_VEH_OWNER_TYPE] != VEHICLE_OWNER_CHARACTER ||
            sVehicles[slot][E_VEH_OWNER_ID] != owner_char_id)
        {
            continue;
        }
        if (count >= maxRows)
        {
            break;
        }
        rows[count++] = slot;
    }
    return count;
}

stock bool:Vehicle_RetrieveFromGarage(slot, Float:x, Float:y, Float:z, Float:a)
{
    if (!Vehicle_IsValidSlot(slot))
    {
        return false;
    }
    sVehicles[slot][E_VEH_GARAGE_PROPERTY_ID] = 0;
    sVehicles[slot][E_VEH_SPAWN_X] = x;
    sVehicles[slot][E_VEH_SPAWN_Y] = y;
    sVehicles[slot][E_VEH_SPAWN_Z] = z;
    sVehicles[slot][E_VEH_SPAWN_A] = a;
    Vehicle_SaveSlot(slot);
    return (Vehicle_SpawnSlot(slot) != 0);
}

static stock Internal_OpenBuyDialog(playerid)
{
    if (!Internal_PlayerNearDealership(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Автосалон находится в другом районе. Подойдите к стойке продаж.");
        return 0;
    }

    new body[2048];
    body[0] = '\0';
    new row[128], priceStr[32];
    for (new i = 0; i < VEHICLE_CATALOG_SIZE; i++)
    {
        Utils_FormatMoney(sVehicleCatalog[i][E_VC_PRICE_USD], priceStr);
        new fuelTitle[32];
        Internal_GetFuelTitleRu(sVehicleCatalog[i][E_VC_FUEL], fuelTitle, sizeof(fuelTitle));
        format(row, sizeof(row), "%s | %s | %s\n",
            sVehicleCatalog[i][E_VC_NAME], fuelTitle, priceStr);
        if ((strlen(body) + strlen(row)) >= sizeof(body))
        {
            break;
        }
        strcat(body, row, sizeof(body));
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_VEHICLE_BUY,
        DIALOG_STYLE_LIST,
        "{FFC800}Автосалон Сан-Андреаса {FFFFFF}| Каталог транспорта",
        body,
        "Купить",
        "Отмена");
    return 1;
}

static stock Internal_StartRefuel(playerid)
{
    new station = VEHICLE_INVALID_ENTERPRISE;
    new warehouse = INVALID_STORAGE_SLOT;
    new const bool:atStation = Vehicles_FindGasStation(playerid, station, warehouse);
    new const bool:hasCanister = Internal_PlayerHasItemDef(playerid, ITEM_ID_FUEL_CANISTER);

    if (!atStation && !hasCanister)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Для заправки нужна АЗС или канистра с топливом в инвентаре.");
        return 0;
    }

    new runtimeVehicle, slot;
    if (!Internal_GetNearestVehicle(playerid, VEHICLE_INTERACT_RADIUS, runtimeVehicle, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Рядом нет транспортного средства для заправки.");
        return 0;
    }

    sVehicleRefuelStation[playerid] = station;
    sVehicleRefuelWarehouse[playerid] = warehouse;
    sVehicleRefuelSlot[playerid] = slot;

    new body[512];
    format(body, sizeof(body),
        "Текущий уровень топлива: %d / %d мл.\n" \
        "Выберите тип топлива. Неверный тип повредит двигатель!\n\n" \
        "Бензин Regular — %d USD/л\n" \
        "Дизельное топливо — %d USD/л\n" \
        "Авиационный керосин — %d USD/л",
        sVehicles[slot][E_VEH_FUEL_ML],
        sVehicles[slot][E_VEH_MAX_FUEL_ML],
        VEHICLE_FUEL_PRICE_REGULAR_USD,
        VEHICLE_FUEL_PRICE_DIESEL_USD,
        VEHICLE_FUEL_PRICE_JET_USD);

    ShowPlayerDialog(
        playerid,
        DIALOG_VEHICLE_REFUEL_TYPE,
        DIALOG_STYLE_LIST,
        "{FFC800}Заправка транспортного средства",
        body,
        "Выбрать",
        "Отмена");
    return 1;
}

static stock Internal_ApplyRefuel(playerid, liters)
{
    if (liters <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Количество литров должно быть положительным.");
        return 0;
    }

    new const slot = sVehicleRefuelSlot[playerid];
    if (!Vehicle_IsValidSlot(slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Транспортное средство больше недоступно.");
        return 0;
    }

    new const E_FUEL_TYPE:fuelType = sVehicleRefuelType[playerid];
    new const maxFuel = sVehicles[slot][E_VEH_MAX_FUEL_ML];
    new const currentFuel = sVehicles[slot][E_VEH_FUEL_ML];
    if (currentFuel >= maxFuel)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "Топливный бак уже полон.");
        return 0;
    }

    new const acceptedLiters = (liters > (maxFuel - currentFuel)) ? (maxFuel - currentFuel) : liters;

    // 1. Заправка из личной канистры (20 л бензина) не требует денег и АЗС
    new layer1 = Character_GetLayer1Slot(playerid);
    new canisterLiters = 0;
    new canisterItem = INVALID_STORAGE_ITEM_SLOT;
    if (Storage_IsValidSlot(layer1))
    {
        new itemSlot = Storage_GetFirstItemSlot(layer1);
        while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
        {
            if (Storage_GetItemDefId(itemSlot) == ITEM_ID_FUEL_CANISTER)
            {
                canisterItem = itemSlot;
                canisterLiters = Storage_GetItemAmount(itemSlot) * 20;
                break;
            }
            itemSlot = Storage_GetNextItemSlot(itemSlot);
        }
    }

    if (canisterItem != INVALID_STORAGE_ITEM_SLOT && canisterLiters > 0)
    {
        new const fromCanister = (acceptedLiters > canisterLiters) ? canisterLiters : acceptedLiters;
        if (fromCanister > 0)
        {
            new const canistersToUse = (fromCanister + 19) / 20;
            Storage_RemoveItem(layer1, canisterItem, canistersToUse);
            sVehicles[slot][E_VEH_FUEL_ML] += fromCanister;
            Internal_HandleWrongFuel(playerid, slot, FUEL_REGULAR);
            Vehicle_SaveSlot(slot);

            new msg[192];
            format(msg, sizeof(msg),
                "Вы залили %d л топлива из канистры. В баке: %d / %d мл.",
                fromCanister, sVehicles[slot][E_VEH_FUEL_ML], maxFuel);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
            return 1;
        }
    }

    // 2. Покупка топлива со склада АЗС (Zero-Faucet: топливо списывается со склада)
    new const station = sVehicleRefuelStation[playerid];
    if (station == VEHICLE_INVALID_ENTERPRISE)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Автозаправочная станция недоступна.");
        return 0;
    }

    new const warehouse = sVehicleRefuelWarehouse[playerid];
    if (!Storage_IsValidSlot(warehouse))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Склад автозаправочной станции недоступен.");
        return 0;
    }
    if (Storage_CountItemInTree(warehouse, ITEM_ID_REFINED_FUEL) < acceptedLiters)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "На автозаправочной станции закончилось топливо. Сообщите владельцу предприятия.");
        return 0;
    }

    new const price = Internal_GetFuelPriceUsd(fuelType);
    new const totalCost = acceptedLiters * price;
    if (Character_GetPhysicalCashUsd(playerid) < totalCost)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Недостаточно наличных для оплаты заправки.");
        return 0;
    }

    if (!Character_RemovePhysicalCashUsd(playerid, totalCost))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось оплатить заправку.");
        return 0;
    }
    if (Storage_RemoveItemInTree(warehouse, ITEM_ID_REFINED_FUEL, acceptedLiters) <= 0)
    {
        Character_AddPhysicalCashUsd(playerid, totalCost);
        SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось списать топливо со склада АЗС.");
        return 0;
    }

    Enterprise_AddReserve(station, totalCost);
    sVehicles[slot][E_VEH_FUEL_ML] += acceptedLiters;
    Internal_HandleWrongFuel(playerid, slot, fuelType);
    Vehicle_SaveSlot(slot);

    new msg[224];
    format(msg, sizeof(msg),
        "Заправка выполнена: %d л за %d USD. В баке: %d / %d мл.",
        acceptedLiters, totalCost, sVehicles[slot][E_VEH_FUEL_ML], maxFuel);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    Audit_Log(Character_GetId(playerid), "VEHICLE_REFUEL", "CASH", "ENTERPRISE_WAREHOUSE",
        ITEM_ID_REFINED_FUEL, totalCost, "Заправка транспортного средства на АЗС");
    return 1;
}

static stock Internal_HandleWrongFuel(playerid, slot, E_FUEL_TYPE:usedFuel)
{
    if (sVehicles[slot][E_VEH_FUEL_TYPE] == usedFuel)
    {
        return 1;
    }

    sVehicles[slot][E_VEH_ENGINE_HP] -= 300.0;
    if (sVehicles[slot][E_VEH_ENGINE_HP] < 0.0)
    {
        sVehicles[slot][E_VEH_ENGINE_HP] = 0.0;
    }
    sVehicles[slot][E_VEH_ENGINE_ON] = false;
    Internal_ApplyVehicleParams(slot);

    SendClientMessage(playerid, COLOR_UI_ERROR,
        "Вы залили неподходящее топливо! Двигатель поврежден, автомобиль заглох.");
    Audit_Log(Character_GetId(playerid), "VEHICLE_WRONG_FUEL", "FUEL", "VEHICLE",
        0, 0, "Заправка двигателя неподходящим типом топлива");
    return 1;
}

static stock Internal_ShowHotwireDialog(playerid)
{
    if (!IsPlayerInAnyVehicle(playerid) || GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Для скрутки проводов нужно сидеть за рулем.");
        return 0;
    }

    new const vid = GetPlayerVehicleID(playerid);
    new const slot = Internal_FindSlotByRuntime(vid);
    if (slot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Этот транспорт не поддается скрутке проводов.");
        return 0;
    }
    if (Internal_PlayerHasVehicleKey(playerid, slot))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "У вас есть ключ: скрутка проводов не требуется.");
        return 0;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sVehicleLastHotwireTick[playerid]) < VEHICLE_HOTWIRE_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "Провода остывают: подождите несколько секунд.");
        return 0;
    }

    sVehicleHotwireAnswer[playerid] = random(4);
    ShowPlayerDialog(
        playerid,
        DIALOG_VEHICLE_HOTWIRE,
        DIALOG_STYLE_LIST,
        "{FFC800}Скрутка проводов зажигания",
        "Соединить красный и желтый провода\n" \
        "Соединить синий и зеленый провода\n" \
        "Соединить черный и оранжевый провода\n" \
        "Соединить белый и коричневый провода",
        "Попробовать",
        "Отмена");
    return 1;
}

static stock Internal_ExecuteChop(playerid)
{
    new const enterprise = sVehicleChopEnterprise[playerid];
    if (enterprise == VEHICLE_INVALID_ENTERPRISE)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Вы находитесь не на авторазборке.");
        return 0;
    }

    new const slot = sVehicleChopVehicle[playerid];
    if (!Vehicle_IsValidSlot(slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Транспортное средство не найдено.");
        return 0;
    }

    new const vid = sVehicles[slot][E_VEH_RUNTIME_ID];
    if (vid == INVALID_VEHICLE_ID || !IsValidVehicle(vid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Транспортное средство уже недоступно.");
        return 0;
    }

    new const warehouse = sVehicleChopWarehouse[playerid];
    if (!Storage_IsValidSlot(warehouse))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Склад авторазборки недоступен.");
        return 0;
    }

    new const model = sVehicles[slot][E_VEH_MODEL];
    new const bool:isTruck = (model == 403 || model == 414 || model == 455 || model == 456 ||
        model == 498 || model == 499 || model == 514 || model == 515 || model == 524 || model == 525);

    new steel = isTruck ? (18 + random(8)) : (4 + random(4));
    new springs = isTruck ? (6 + random(3)) : (1 + random(2));
    new bearings = isTruck ? (5 + random(3)) : (1 + random(2));
    new outItem = INVALID_STORAGE_ITEM_SLOT;

    new steelLeft = steel;
    new springsLeft = springs;
    new bearingsLeft = bearings;

    if (Storage_AddItem(warehouse, ITEM_ID_STEEL_SHEET, steel, 0, 100.0, 0, 0, "", outItem) == STORAGE_RES_OK)
    {
        steelLeft = 0;
    }
    if (Storage_AddItem(warehouse, ITEM_ID_SPRINGS_PINS, springs, 0, 100.0, 0, 0, "", outItem) == STORAGE_RES_OK)
    {
        springsLeft = 0;
    }
    if (Storage_AddItem(warehouse, ITEM_ID_BEARINGS, bearings, 0, 100.0, 0, 0, "", outItem) == STORAGE_RES_OK)
    {
        bearingsLeft = 0;
    }

    if (steelLeft > 0 || springsLeft > 0 || bearingsLeft > 0)
    {
        new Float:x, Float:y, Float:z;
        GetVehiclePos(vid, x, y, z);
        new drop = Storage_CreateWorldDrop(x, y, z, 0, 0, ITEM_ID_STEEL_SHEET);
        if (drop != INVALID_STORAGE_SLOT)
        {
            if (steelLeft > 0)
                Storage_AddItem(drop, ITEM_ID_STEEL_SHEET, steelLeft, 0, 100.0, 0, 0, "", outItem);
            if (springsLeft > 0)
                Storage_AddItem(drop, ITEM_ID_SPRINGS_PINS, springsLeft, 0, 100.0, 0, 0, "", outItem);
            if (bearingsLeft > 0)
                Storage_AddItem(drop, ITEM_ID_BEARINGS, bearingsLeft, 0, 100.0, 0, 0, "", outItem);
        }
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "Склад авторазборки переполнен: часть деталей выгружена на землю.");
    }

    new const dbId = sVehicles[slot][E_VEH_DB_ID];
    new plate[VEHICLE_PLATE_LEN];
    format(plate, sizeof(plate), "%s", sVehicles[slot][E_VEH_PLATE]);
    new const glovebox = sVehicles[slot][E_VEH_GLOVEBOX_SLOT];
    new const trunk = sVehicles[slot][E_VEH_TRUNK_SLOT];
    new const gloveboxDbId = sVehicles[slot][E_VEH_GLOVEBOX_DB_ID];
    new const trunkDbId = sVehicles[slot][E_VEH_TRUNK_DB_ID];

    Vehicle_DespawnSlot(slot);
    if (Storage_IsValidSlot(glovebox))
    {
        Storage_Unload(glovebox);
    }
    if (Storage_IsValidSlot(trunk))
    {
        Storage_Unload(trunk);
    }

    if (DB_IsConnected() && dbId > 0)
    {
        new query[320];
        if (gloveboxDbId > 0 && trunkDbId > 0)
        {
            mysql_format(gMySQL, query, sizeof(query),
                "START TRANSACTION; DELETE FROM `vehicles` WHERE `id` = %d; DELETE FROM `storages` WHERE `id` IN (%d, %d); COMMIT;",
                dbId, gloveboxDbId, trunkDbId);
        }
        else
        {
            mysql_format(gMySQL, query, sizeof(query),
                "DELETE FROM `vehicles` WHERE `id` = %d;", dbId);
        }
        mysql_tquery(gMySQL, query);
    }

    Iter_Remove(VehicleDataIter, slot);
    Internal_ResetVehicleSlot(slot);

    Character_SetWantedLevel(playerid, Character_GetWantedLevel(playerid) + 5);
    Character_ResetActivePlaySeconds(playerid);

    new msg[256];
    format(msg, sizeof(msg),
        "Автомобиль %s разобран. Получено: стальной прокат — %d, пружины — %d, подшипники — %d.",
        plate, steel, springs, bearings);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    Audit_Log(Character_GetId(playerid), "VEHICLE_CHOP", "VEHICLE", "ENTERPRISE_WAREHOUSE",
        0, steel + springs + bearings, "Разборка угнанного транспорта на запчасти");
    return 1;
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API ТРАНСПОРТА
// =============================================================================

stock Vehicle_GetNearestSlot(playerid, Float:radius)
{
    new runtimeVehicle, slot;
    if (!Internal_GetNearestVehicle(playerid, radius, runtimeVehicle, slot))
    {
        return -1;
    }
    return slot;
}

stock bool:Vehicle_PlayerHasAnyKey(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return false;
    }
    new slots[2];
    slots[0] = Character_GetLayer1Slot(playerid);
    slots[1] = Character_GetLayer2Slot(playerid);
    for (new s = 0; s < 2; s++)
    {
        if (!Storage_IsValidSlot(slots[s]))
        {
            continue;
        }
        new itemSlot = Storage_GetFirstItemSlot(slots[s]);
        while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
        {
            if (Storage_GetItemDefId(itemSlot) == ITEM_ID_VEHICLE_KEY &&
                Storage_GetItemMetaInt1(itemSlot) > 0)
            {
                return true;
            }
            itemSlot = Storage_GetNextItemSlot(itemSlot);
        }
    }
    return false;
}

// =============================================================================
//  5. АСИНХРОННЫЕ SQL-КОЛБЕКИ И ЗАГРУЗКА (forward / public)
// =============================================================================

static stock Internal_LoadVehiclesSync()
{
    if (!DB_IsConnected())
    {
        printf("%s [Entities/Vehicles] База недоступна: транспорт будет создаваться по мере покупки.",
            SERVER_LOG_PREFIX);
        return 0;
    }

    new const Cache:maxCache = mysql_query(gMySQL,
        "SELECT IFNULL(MAX(`id`), 0) AS `max_id` FROM `vehicles`;",
        true);
    if (cache_is_valid(maxCache))
    {
        new maxId = 0;
        cache_get_value_name_int(0, "max_id", maxId);
        sNextVehicleDbId = maxId + 1;
        cache_delete(maxCache);
    }

    new const Cache:vehicleCache = mysql_query(gMySQL,
        "SELECT `id`, `model_id`, `vin`, `plate`, `owner_type`, `owner_id`, `fuel_type`, `fuel_ml`, `max_fuel_ml`, `engine_hp`, `body_hp`, `mileage_meters`, `glovebox_storage_id`, `trunk_storage_id`, `color1`, `color2`, `pos_x`, `pos_y`, `pos_z`, `pos_a`, IFNULL(`garage_property_id`, 0) AS `garage_id` FROM `vehicles` ORDER BY `id` ASC;",
        true);

    if (!cache_is_valid(vehicleCache))
    {
        return 0;
    }

    new rows = 0;
    cache_get_row_count(rows);
    for (new r = 0; r < rows; r++)
    {
        new dbId, modelId, ownerId, fuelMl, maxFuelMl, mileage, gloveboxDbId, trunkDbId, color1, color2, garageId;
        new Float:engineHp, Float:bodyHp, Float:posX, Float:posY, Float:posZ, Float:posA;
        new vin[VEHICLE_VIN_LEN], plate[VEHICLE_PLATE_LEN], ownerStr[24], fuelStr[24];

        cache_get_value_name_int(r, "id", dbId);
        cache_get_value_name_int(r, "model_id", modelId);
        cache_get_value_name(r, "vin", vin, sizeof(vin));
        cache_get_value_name(r, "plate", plate, sizeof(plate));
        cache_get_value_name(r, "owner_type", ownerStr, sizeof(ownerStr));
        cache_get_value_name_int(r, "owner_id", ownerId);
        cache_get_value_name(r, "fuel_type", fuelStr, sizeof(fuelStr));
        cache_get_value_name_int(r, "fuel_ml", fuelMl);
        cache_get_value_name_int(r, "max_fuel_ml", maxFuelMl);
        cache_get_value_name_float(r, "engine_hp", engineHp);
        cache_get_value_name_float(r, "body_hp", bodyHp);
        cache_get_value_name_int(r, "mileage_meters", mileage);
        cache_get_value_name_int(r, "glovebox_storage_id", gloveboxDbId);
        cache_get_value_name_int(r, "trunk_storage_id", trunkDbId);
        cache_get_value_name_int(r, "color1", color1);
        cache_get_value_name_int(r, "color2", color2);
        cache_get_value_name_float(r, "pos_x", posX);
        cache_get_value_name_float(r, "pos_y", posY);
        cache_get_value_name_float(r, "pos_z", posZ);
        cache_get_value_name_float(r, "pos_a", posA);
        cache_get_value_name_int(r, "garage_id", garageId);

        new const slot = Internal_AddVehicle(
            dbId, modelId, vin, plate,
            Internal_ParseOwnerType(ownerStr), ownerId,
            Internal_ParseFuelType(fuelStr), fuelMl, maxFuelMl,
            engineHp, bodyHp, mileage,
            gloveboxDbId, trunkDbId, color1, color2,
            posX, posY, posZ, posA, garageId);

        if (slot >= 0 && garageId == 0)
        {
            Vehicle_SpawnSlot(slot);
        }
    }
    cache_delete(vehicleCache);
    return 1;
}

// =============================================================================
//  6. ХУКИ СИСТЕМНЫХ КОЛБЕКОВ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_VEHICLES_SERVER; i++)
    {
        Internal_ResetVehicleSlot(i);
        sRuntimeVehicleSlot[i] = -1;
    }
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        sVehicleLastCommandTick[i] = 0;
        sVehicleLastHotwireTick[i] = 0;
        sVehicleRefuelStation[i] = VEHICLE_INVALID_ENTERPRISE;
        sVehicleRefuelWarehouse[i] = INVALID_STORAGE_SLOT;
        sVehicleRefuelSlot[i] = -1;
        sVehicleRefuelType[i] = FUEL_REGULAR;
        sVehicleHotwireAnswer[i] = -1;
        sVehicleChopVehicle[i] = -1;
        sVehicleChopEnterprise[i] = VEHICLE_INVALID_ENTERPRISE;
        sVehicleChopWarehouse[i] = INVALID_STORAGE_SLOT;
        sVehicleGarageProperty[i] = 0;
        sVehicleUnparkRowCount[i] = 0;
    }

    for (new i = 0; i < VEHICLE_DEALERSHIP_COUNT; i++)
    {
        sDealershipLabel[i] = CreateDynamic3DTextLabel(
            "Автосалон Сан-Андреаса\nКаталог: /vbuy",
            COLOR_UI_INFO,
            sVehicleDealerships[i][0],
            sVehicleDealerships[i][1],
            sVehicleDealerships[i][2] + 1.2,
            20.0,
            INVALID_PLAYER_ID,
            INVALID_VEHICLE_ID,
            0,
            0, 0, -1,
            80.0);
    }

    Internal_LoadVehiclesSync();
    printf("%s [Entities/Vehicles] Загружено транспортных средств: %d.",
        SERVER_LOG_PREFIX, Iter_Count(VehicleDataIter));
    return 1;
}

hook OnGameModeExit()
{
    foreach (new slot : VehicleDataIter)
    {
        if (sVehicles[slot][E_VEH_VALID])
        {
            Vehicle_SaveSlot(slot);
        }
    }
    return 1;
}

hook OnPlayerConnect(playerid)
{
    sVehicleLastCommandTick[playerid] = 0;
    sVehicleLastHotwireTick[playerid] = 0;
    sVehicleRefuelStation[playerid] = VEHICLE_INVALID_ENTERPRISE;
    sVehicleRefuelWarehouse[playerid] = INVALID_STORAGE_SLOT;
    sVehicleRefuelSlot[playerid] = -1;
    sVehicleRefuelType[playerid] = FUEL_REGULAR;
    sVehicleHotwireAnswer[playerid] = -1;
    sVehicleChopVehicle[playerid] = -1;
    sVehicleChopEnterprise[playerid] = VEHICLE_INVALID_ENTERPRISE;
    sVehicleChopWarehouse[playerid] = INVALID_STORAGE_SLOT;
    sVehicleGarageProperty[playerid] = 0;
    sVehicleUnparkRowCount[playerid] = 0;
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    new const vid = GetPlayerVehicleID(playerid);
    if (vid != 0)
    {
        new const drivingSlot = Internal_FindSlotByRuntime(vid);
        if (drivingSlot >= 0)
        {
            Vehicle_SaveSlot(drivingSlot);
        }
    }
    sVehicleChopVehicle[playerid] = -1;
    sVehicleChopEnterprise[playerid] = VEHICLE_INVALID_ENTERPRISE;
    sVehicleChopWarehouse[playerid] = INVALID_STORAGE_SLOT;
    sVehicleGarageProperty[playerid] = 0;
    sVehicleUnparkRowCount[playerid] = 0;
    return 1;
}

hook OnPlayerStateChange(playerid, PLAYER_STATE:newstate, PLAYER_STATE:oldstate)
{
    if (newstate == PLAYER_STATE_DRIVER)
    {
        new const vid = GetPlayerVehicleID(playerid);
        new const slot = Internal_FindSlotByRuntime(vid);
        if (slot < 0)
        {
            return 1;
        }

        if (sVehicles[slot][E_VEH_HOTWIRED] || Internal_PlayerHasVehicleKey(playerid, slot))
        {
            if (sVehicles[slot][E_VEH_FUEL_ML] <= 0)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "В топливном баке нет топлива.");
                sVehicles[slot][E_VEH_ENGINE_ON] = false;
            }
            else if (sVehicles[slot][E_VEH_ENGINE_HP] <= 0.0)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Двигатель вышел из строя. Требуется ремонт.");
                sVehicles[slot][E_VEH_ENGINE_ON] = false;
            }
            else
            {
                sVehicles[slot][E_VEH_ENGINE_ON] = true;
            }
        }
        else
        {
            sVehicles[slot][E_VEH_ENGINE_ON] = false;
            SendClientMessage(playerid, COLOR_UI_WARNING,
                "Ключа нет: двигатель не заводится. Скрутите провода командой /hotwire.");
        }
        Internal_ApplyVehicleParams(slot);
    }
    else if (oldstate == PLAYER_STATE_DRIVER && newstate != PLAYER_STATE_DRIVER)
    {
        new const vid = GetPlayerVehicleID(playerid);
        new const slot = Internal_FindSlotByRuntime(vid);
        if (slot >= 0)
        {
            sVehicles[slot][E_VEH_HOTWIRED] = false;
            sVehicles[slot][E_VEH_ENGINE_ON] = false;
            Internal_ApplyVehicleParams(slot);
            Vehicle_SaveSlot(slot);
        }
    }
    return 1;
}

hook OnPlayerExitVehicle(playerid, vehicleid)
{
    new const slot = Internal_FindSlotByRuntime(vehicleid);
    if (slot >= 0)
    {
        sVehicles[slot][E_VEH_HOTWIRED] = false;
        sVehicles[slot][E_VEH_ENGINE_ON] = false;
        Internal_ApplyVehicleParams(slot);
        Vehicle_SaveSlot(slot);
    }
    return 1;
}

// =============================================================================
//  7. ТАЙМЕР: РАСХОД ТОПЛИВА, ИЗНОС, БОНУС АВТОМЕХАНИКА
// =============================================================================

task Tick_VehicleSecond[1000]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }

    new const nowTick = GetTickCount();

    foreach (new slot : VehicleDataIter)
    {
        if (!sVehicles[slot][E_VEH_VALID])
        {
            continue;
        }
        new const vid = sVehicles[slot][E_VEH_RUNTIME_ID];
        if (vid == INVALID_VEHICLE_ID || !IsValidVehicle(vid))
        {
            continue;
        }

        new const driver = GetVehicleDriver(vid);
        if (driver == INVALID_PLAYER_ID || !Character_IsLoaded(driver))
        {
            continue;
        }

        // Server-authoritative: без физического ключа или скрутки проводов двигатель запрещен
        if (!sVehicles[slot][E_VEH_HOTWIRED] && !Internal_PlayerHasVehicleKey(driver, slot))
        {
            if (sVehicles[slot][E_VEH_ENGINE_ON])
            {
                sVehicles[slot][E_VEH_ENGINE_ON] = false;
                Internal_ApplyVehicleParams(slot);
                SendClientMessage(driver, COLOR_UI_ERROR,
                    "Двигатель заглох: нет физического ключа и скрутки проводов.");
            }
        }

        new Float:vx, Float:vy, Float:vz;
        if (!GetVehicleVelocity(vid, vx, vy, vz))
        {
            continue;
        }

        new const Float:speed = floatsqroot((vx * vx) + (vy * vy) + (vz * vz)) * 180.0;
        if (speed > 1.0)
        {
            sVehicles[slot][E_VEH_MILEAGE_METERS] += floatround(speed * 0.2778);

            if (sVehicles[slot][E_VEH_ENGINE_ON] && sVehicles[slot][E_VEH_FUEL_ML] > 0)
            {
                new burnRate = 2 + floatround(speed / 20.0);
                if (sVehicles[slot][E_VEH_FUEL_TYPE] == FUEL_DIESEL)
                {
                    burnRate *= 2;
                }
                else if (sVehicles[slot][E_VEH_FUEL_TYPE] == FUEL_JET_FUEL)
                {
                    burnRate *= 3;
                }
                if (Roles_HasPerk(Character_GetRoleId(driver), PERK_TRUCKER_BONUS_20))
                {
                    burnRate = (burnRate * 85) / 100;
                }
                if (burnRate < 1)
                {
                    burnRate = 1;
                }

                sVehicles[slot][E_VEH_FUEL_ML] -= burnRate;
                if (sVehicles[slot][E_VEH_FUEL_ML] <= 0)
                {
                    sVehicles[slot][E_VEH_FUEL_ML] = 0;
                    sVehicles[slot][E_VEH_ENGINE_ON] = false;
                    Internal_ApplyVehicleParams(slot);
                    if (!sVehicles[slot][E_VEH_FUEL_WARNED])
                    {
                        sVehicles[slot][E_VEH_FUEL_WARNED] = true;
                        SendClientMessage(driver, COLOR_UI_ERROR,
                            "Топливо закончилось. Двигатель заглох. Заправьтесь на АЗС.");
                    }
                }
                else
                {
                    sVehicles[slot][E_VEH_FUEL_WARNED] = false;
                }

                sVehicles[slot][E_VEH_ENGINE_HP] -= (0.01 + (speed / 10000.0));
                if (sVehicles[slot][E_VEH_ENGINE_HP] <= 0.0)
                {
                    sVehicles[slot][E_VEH_ENGINE_HP] = 0.0;
                    sVehicles[slot][E_VEH_ENGINE_ON] = false;
                    Internal_ApplyVehicleParams(slot);
                    SendClientMessage(driver, COLOR_UI_ERROR,
                        "Двигатель полностью изношен. Требуется ремонт в автомастерской.");
                }
            }

            if (Roles_HasPerk(Character_GetRoleId(driver), PERK_SPEED_BONUS_10) && speed < VEHICLE_TOWING_SPEED_LIMIT)
            {
                new KEY:keys;
                new updown, leftright;
                GetPlayerKeys(driver, keys, updown, leftright);
                if (updown & KEY_UP)
                {
                    SetVehicleVelocity(vid, vx * 1.01, vy * 1.01, vz * 1.01);
                }
            }
        }

        new Float:health;
        if (GetVehicleHealth(vid, health))
        {
            sVehicles[slot][E_VEH_BODY_HP] = health;
        }

        if ((nowTick - sVehicles[slot][E_VEH_LAST_PERSIST_TICK]) > 60000)
        {
            Vehicle_SaveSlot(slot);
        }
    }
}

// =============================================================================
//  8. ДИАЛОГИ (OnDialogResponse)
// =============================================================================

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch (dialogid)
    {
        case DIALOG_VEHICLE_BUY:
        {
            if (!response || listitem < 0 || listitem >= VEHICLE_CATALOG_SIZE)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (!Internal_PlayerNearDealership(playerid))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Вы отошли от автосалона.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new const price = sVehicleCatalog[listitem][E_VC_PRICE_USD];
            if (Banking_GetBalance(playerid) < price &&
                Character_GetPhysicalCashUsd(playerid) < price)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Недостаточно средств для покупки.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Vehicle_CreateForPlayer(playerid, sVehicleCatalog[listitem][E_VC_MODEL], price, true);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_VEHICLE_REFUEL_TYPE:
        {
            if (!response || listitem < 0 || listitem > 2)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            sVehicleRefuelType[playerid] = E_FUEL_TYPE:listitem;
            new const slot = sVehicleRefuelSlot[playerid];
            if (!Vehicle_IsValidSlot(slot))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Транспортное средство недоступно.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new fuelTitle[32];
            Internal_GetFuelTitleRu(sVehicleRefuelType[playerid], fuelTitle, sizeof(fuelTitle));
            new body[320];
            format(body, sizeof(body),
                "Топливо: %s\n" \
                "Цена: %d USD за литр\n" \
                "В баке: %d / %d мл\n\n" \
                "Введите количество литров для заправки.",
                fuelTitle,
                Internal_GetFuelPriceUsd(sVehicleRefuelType[playerid]),
                sVehicles[slot][E_VEH_FUEL_ML],
                sVehicles[slot][E_VEH_MAX_FUEL_ML]);
            ShowPlayerDialog(playerid, DIALOG_VEHICLE_REFUEL_AMOUNT, DIALOG_STYLE_INPUT,
                "{FFC800}Количество топлива", body, "Заправить", "Отмена");
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_VEHICLE_REFUEL_AMOUNT:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new liters = 0;
            if (!Internal_ParsePositiveInt(inputtext, liters))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Введите корректное количество литров.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ApplyRefuel(playerid, liters);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_VEHICLE_HOTWIRE:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (!IsPlayerInAnyVehicle(playerid) || GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Вы уже не за рулем.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new const vid = GetPlayerVehicleID(playerid);
            new const slot = Internal_FindSlotByRuntime(vid);
            if (slot < 0)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            sVehicleLastHotwireTick[playerid] = GetTickCount();
            if (listitem == sVehicleHotwireAnswer[playerid])
            {
                sVehicles[slot][E_VEH_HOTWIRED] = true;
                sVehicles[slot][E_VEH_ENGINE_ON] = (sVehicles[slot][E_VEH_FUEL_ML] > 0 && sVehicles[slot][E_VEH_ENGINE_HP] > 0.0);
                Internal_ApplyVehicleParams(slot);
                Skills_Add(playerid, SKILL_HOTWIRING, 2);
                SendClientMessage(playerid, COLOR_UI_SUCCESS,
                    "Провода соединены! Двигатель завелся, можно ехать.");
                Audit_Log(Character_GetId(playerid), "VEHICLE_HOTWIRE", "VEHICLE", "CHARACTER",
                    0, 1, "Успешная скрутка проводов зажигания");
            }
            else
            {
                new Float:health;
                GetPlayerHealth(playerid, health);
                SetPlayerHealth(playerid, health - 10.0);
                Skills_Add(playerid, SKILL_HOTWIRING, 1);
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "Вас ударило током! Провода соединены неверно, попробуйте другую комбинацию.");
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_VEHICLE_CHOP_CONFIRM:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ExecuteChop(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_VEHICLE_UNPARK:
        {
            if (!response || listitem < 0 || listitem >= sVehicleUnparkRowCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new const slot = sVehicleUnparkRowMap[playerid][listitem];
            new const propertyDbId = sVehicleGarageProperty[playerid];
            new Float:x, Float:y, Float:z, Float:a;
            if (!Properties_GetExteriorPos(propertyDbId, x, y, z, a))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось определить адрес гаража.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (Vehicle_RetrieveFromGarage(slot, x + 3.0, y + 3.0, z, a))
            {
                SendClientMessage(playerid, COLOR_UI_SUCCESS, "Транспорт выехал из гаража.");
            }
            else
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось выгнать транспорт из гаража.");
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_1;
}

// =============================================================================
//  9. КОМАНДЫ (Pawn.CMD)
// =============================================================================

CMD:vbuy(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }
    Internal_OpenBuyDialog(playerid);
    return 1;
}
alias:vbuy("cars");

CMD:vstats(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }

    new runtimeVehicle, slot;
    if (!Internal_GetNearestVehicle(playerid, 8.0, runtimeVehicle, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Рядом нет транспортного средства.");
        return 1;
    }

    new modelName[VEHICLE_MODEL_NAME_LEN], ownerName[48];
    Internal_GetCatalogName(sVehicles[slot][E_VEH_MODEL], modelName, sizeof(modelName));
    switch (sVehicles[slot][E_VEH_OWNER_TYPE])
    {
        case VEHICLE_OWNER_CHARACTER:    format(ownerName, sizeof(ownerName), "персонаж #%d", sVehicles[slot][E_VEH_OWNER_ID]);
        case VEHICLE_OWNER_ORGANIZATION: format(ownerName, sizeof(ownerName), "организация #%d", sVehicles[slot][E_VEH_OWNER_ID]);
        default:                         format(ownerName, sizeof(ownerName), "государственный автопарк");
    }

    new fuelTitle[32];
    Internal_GetFuelTitleRu(sVehicles[slot][E_VEH_FUEL_TYPE], fuelTitle, sizeof(fuelTitle));
    new msg[256];
    format(msg, sizeof(msg),
        "[Транспорт] %s | Номер: %s | Владелец: %s | Топливо: %d / %d мл (%s) | Двигатель: %.0f ед. | Кузов: %.0f ед.",
        modelName, sVehicles[slot][E_VEH_PLATE], ownerName,
        sVehicles[slot][E_VEH_FUEL_ML], sVehicles[slot][E_VEH_MAX_FUEL_ML], fuelTitle,
        sVehicles[slot][E_VEH_ENGINE_HP], sVehicles[slot][E_VEH_BODY_HP]);
    SendClientMessage(playerid, COLOR_UI_INFO, msg);
    return 1;
}

CMD:vkey(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }

    new runtimeVehicle, slot;
    if (!Internal_GetNearestVehicle(playerid, 8.0, runtimeVehicle, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Рядом нет транспортного средства.");
        return 1;
    }

    new const bool:hasKey = Internal_PlayerHasVehicleKey(playerid, slot);
    new const bool:isOwner = (sVehicles[slot][E_VEH_OWNER_TYPE] == VEHICLE_OWNER_CHARACTER &&
        sVehicles[slot][E_VEH_OWNER_ID] == Character_GetId(playerid));
    if (!hasKey && !isOwner)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Вы не владелец и не имеете ключа от этого транспорта.");
        return 1;
    }
    if (!Internal_PlayerHasItemDef(playerid, ITEM_ID_WRENCH_KIT) &&
        Skills_Get(playerid, SKILL_MECHANICS) < 300)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Для изготовления дубликата нужен ящик автомеханика или навык механики не ниже 300.");
        return 1;
    }
    if (Character_GetPhysicalCashUsd(playerid) < VEHICLE_KEY_COPY_COST_USD)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Недостаточно наличных для оплаты дубликата ключей.");
        return 1;
    }
    if (!Character_RemovePhysicalCashUsd(playerid, VEHICLE_KEY_COPY_COST_USD))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось оплатить изготовление ключей.");
        return 1;
    }

    if (Internal_IssueKey(playerid, slot, true))
    {
        Audit_Log(Character_GetId(playerid), "VEHICLE_KEY_COPY", "CHARACTER", "VEHICLE",
            0, VEHICLE_KEY_COPY_COST_USD, "Изготовление дубликата ключей");
    }
    else
    {
        Character_AddPhysicalCashUsd(playerid, VEHICLE_KEY_COPY_COST_USD);
        SendClientMessage(playerid, COLOR_UI_ERROR, "В инвентаре нет места для дубликата ключей.");
    }
    return 1;
}

CMD:vlock(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }

    new runtimeVehicle, slot;
    if (!Internal_GetNearestVehicle(playerid, 8.0, runtimeVehicle, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Рядом нет транспортного средства.");
        return 1;
    }
    if (!Internal_PlayerHasVehicleKey(playerid, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Для управления замком нужен физический ключ.");
        return 1;
    }

    sVehicles[slot][E_VEH_LOCKED] = !sVehicles[slot][E_VEH_LOCKED];
    Internal_ApplyVehicleParams(slot);
    Vehicle_SaveSlot(slot);

    if (sVehicles[slot][E_VEH_LOCKED])
    {
        SendClientMessage(playerid, COLOR_UI_SUCCESS, "Вы заперли транспортное средство.");
    }
    else
    {
        SendClientMessage(playerid, COLOR_UI_SUCCESS, "Вы отперли транспортное средство.");
    }
    return 1;
}

CMD:vengine(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!IsPlayerInAnyVehicle(playerid) || GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Вы должны сидеть за рулем.");
        return 1;
    }

    new const vid = GetPlayerVehicleID(playerid);
    new const slot = Internal_FindSlotByRuntime(vid);
    if (slot < 0)
    {
        return 1;
    }
    if (!Internal_PlayerHasVehicleKey(playerid, slot) && !sVehicles[slot][E_VEH_HOTWIRED])
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Нет ключа. Двигатель не заводится.");
        return 1;
    }
    if (sVehicles[slot][E_VEH_FUEL_ML] <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "В баке нет топлива.");
        return 1;
    }
    if (sVehicles[slot][E_VEH_ENGINE_HP] <= 0.0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Двигатель вышел из строя.");
        return 1;
    }

    sVehicles[slot][E_VEH_ENGINE_ON] = !sVehicles[slot][E_VEH_ENGINE_ON];
    Internal_ApplyVehicleParams(slot);
    if (sVehicles[slot][E_VEH_ENGINE_ON])
    {
        SendClientMessage(playerid, COLOR_UI_SUCCESS, "Двигатель заведен.");
    }
    else
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Двигатель заглушен.");
    }
    return 1;
}

CMD:trunk(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    new runtimeVehicle, slot;
    if (!Internal_GetNearestVehicle(playerid, 5.0, runtimeVehicle, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Рядом нет транспортного средства.");
        return 1;
    }
    if (sVehicles[slot][E_VEH_LOCKED] && !Internal_PlayerHasVehicleKey(playerid, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Багажник заперт. Нужен ключ или взлом.");
        return 1;
    }
    new const trunk = Vehicle_GetTrunkSlot(slot);
    if (!Storage_IsValidSlot(trunk))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Багажник недоступен.");
        return 1;
    }
    Dialogs_OpenExternalContainer(playerid, trunk);
    return 1;
}

CMD:glovebox(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    new runtimeVehicle, slot;
    if (!Internal_GetNearestVehicle(playerid, 5.0, runtimeVehicle, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Рядом нет транспортного средства.");
        return 1;
    }
    if (sVehicles[slot][E_VEH_LOCKED] && !Internal_PlayerHasVehicleKey(playerid, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Бардачок заперт. Нужен ключ.");
        return 1;
    }
    new const glovebox = Vehicle_GetGloveboxSlot(slot);
    if (!Storage_IsValidSlot(glovebox))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Бардачок недоступен.");
        return 1;
    }
    Dialogs_OpenExternalContainer(playerid, glovebox);
    return 1;
}

CMD:refuel(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }
    Internal_StartRefuel(playerid);
    return 1;
}

CMD:repair(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }

    new runtimeVehicle, slot;
    if (!Internal_GetNearestVehicle(playerid, 5.0, runtimeVehicle, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Рядом нет транспортного средства.");
        return 1;
    }
    if (!Internal_PlayerHasItemDef(playerid, ITEM_ID_WRENCH_KIT))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Для ремонта нужен ящик автомеханика с ключами.");
        return 1;
    }
    if (sVehicles[slot][E_VEH_ENGINE_HP] >= 1000.0 && sVehicles[slot][E_VEH_BODY_HP] >= 1000.0)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Транспорт не нуждается в ремонте.");
        return 1;
    }

    new repairAmount = VEHICLE_REPAIR_BASE_HP + (Skills_Get(playerid, SKILL_MECHANICS) / VEHICLE_REPAIR_SKILL_DIVISOR);
    if (Roles_HasPerk(Character_GetRoleId(playerid), PERK_SPEED_BONUS_10))
    {
        repairAmount *= 2;
    }

    sVehicles[slot][E_VEH_ENGINE_HP] += repairAmount;
    if (sVehicles[slot][E_VEH_ENGINE_HP] > 1000.0)
    {
        sVehicles[slot][E_VEH_ENGINE_HP] = 1000.0;
    }
    sVehicles[slot][E_VEH_BODY_HP] += repairAmount;
    if (sVehicles[slot][E_VEH_BODY_HP] > 1000.0)
    {
        sVehicles[slot][E_VEH_BODY_HP] = 1000.0;
    }
    if (sVehicles[slot][E_VEH_RUNTIME_ID] != INVALID_VEHICLE_ID)
    {
        SetVehicleHealth(sVehicles[slot][E_VEH_RUNTIME_ID], sVehicles[slot][E_VEH_BODY_HP]);
    }
    Vehicle_SaveSlot(slot);
    Skills_Add(playerid, SKILL_MECHANICS, 1);

    new msg[192];
    format(msg, sizeof(msg),
        "Ремонт выполнен. Двигатель: %.0f ед., кузов: %.0f ед.",
        sVehicles[slot][E_VEH_ENGINE_HP], sVehicles[slot][E_VEH_BODY_HP]);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    Audit_Log(Character_GetId(playerid), "VEHICLE_REPAIR", "CHARACTER", "VEHICLE",
        0, repairAmount, "Полевой ремонт транспортного средства");
    return 1;
}

CMD:lockpick(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }

    new runtimeVehicle, slot;
    if (Internal_GetNearestVehicle(playerid, VEHICLE_INTERACT_RADIUS, runtimeVehicle, slot))
    {
        if (!sVehicles[slot][E_VEH_LOCKED])
        {
            SendClientMessage(playerid, COLOR_UI_WARNING, "Замок этого транспорта уже открыт.");
            return 1;
        }
        if (Internal_PlayerHasVehicleKey(playerid, slot))
        {
            SendClientMessage(playerid, COLOR_UI_WARNING, "У вас есть ключ: взлом не требуется.");
            return 1;
        }

        new chance = 20 + (Skills_Get(playerid, SKILL_LOCKPICKING) / 12);
        if (Roles_HasPerk(Character_GetRoleId(playerid), PERK_LOCKPICK_BONUS_35))
        {
            chance += 35;
        }
        if (chance > 90) chance = 90;

        if (random(100) < chance)
        {
            sVehicles[slot][E_VEH_LOCKED] = false;
            Internal_ApplyVehicleParams(slot);
            Skills_Add(playerid, SKILL_LOCKPICKING, 2);
            SendClientMessage(playerid, COLOR_UI_SUCCESS,
                "Замок двери вскрыт! Теперь можно проникнуть в салон и скрутить провода.");
            Audit_Log(Character_GetId(playerid), "VEHICLE_LOCKPICK", "VEHICLE", "CHARACTER",
                0, 1, "Успешное вскрытие замка транспортного средства");
        }
        else
        {
            new Float:vx, Float:vy, Float:vz;
            GetVehiclePos(runtimeVehicle, vx, vy, vz);
            Forensics_CreateLockpickScratch(Character_GetId(playerid), vx, vy, vz, 0, 0);
            Skills_Add(playerid, SKILL_LOCKPICKING, 1);
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "Замок не поддался, на двери остались следы отмычки.");
        }
        return 1;
    }

    // Если рядом нет автомобиля — пробуем дверь недвижимости
    Properties_TryLockpickNearest(playerid);
    return 1;
}

CMD:breakwindow(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }
    if (IsPlayerInAnyVehicle(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Выйдите из транспорта перед разбитием стекла.");
        return 1;
    }

    new runtimeVehicle, slot;
    if (!Internal_GetNearestVehicle(playerid, VEHICLE_INTERACT_RADIUS, runtimeVehicle, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Рядом нет транспортного средства.");
        return 1;
    }
    if (sVehicles[slot][E_VEH_WINDOW_BROKEN])
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "Стекло этого автомобиля уже разбито.");
        return 1;
    }

    sVehicles[slot][E_VEH_WINDOW_BROKEN] = true;
    sVehicles[slot][E_VEH_LOCKED] = false;
    Internal_ApplyVehicleParams(slot);

    new Float:vx, Float:vy, Float:vz;
    GetVehiclePos(runtimeVehicle, vx, vy, vz);
    Forensics_CreateBrokenGlass(Character_GetId(playerid), vx, vy, vz, 0, 0);
    Forensics_CreateBloodDna(Character_GetId(playerid), vx, vy, vz, 0, 0);

    SendClientMessage(playerid, COLOR_UI_SUCCESS,
        "Вы разбили стекло и открыли дверь изнутри. На месте остались осколки и следы крови.");
    Audit_Log(Character_GetId(playerid), "VEHICLE_BREAK_WINDOW", "VEHICLE", "CHARACTER",
        0, 1, "Разбитие стекла транспортного средства");
    return 1;
}

CMD:hotwire(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    Internal_ShowHotwireDialog(playerid);
    return 1;
}

CMD:chop(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }

    new enterprise = VEHICLE_INVALID_ENTERPRISE;
    new warehouse = INVALID_STORAGE_SLOT;
    if (!Vehicles_FindChopShop(playerid, VEHICLE_CHOP_RADIUS, enterprise, warehouse))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Вы находитесь не на нелегальной авторазборке.");
        return 1;
    }

    new runtimeVehicle, slot;
    if (!Internal_GetNearestVehicle(playerid, VEHICLE_INTERACT_RADIUS, runtimeVehicle, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Рядом нет угнанного транспорта для разборки.");
        return 1;
    }
    if (IsPlayerInAnyVehicle(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Выйдите из автомобиля перед разборкой.");
        return 1;
    }

    sVehicleChopVehicle[playerid] = slot;
    sVehicleChopEnterprise[playerid] = enterprise;
    sVehicleChopWarehouse[playerid] = warehouse;

    new modelName[VEHICLE_MODEL_NAME_LEN];
    Internal_GetCatalogName(sVehicles[slot][E_VEH_MODEL], modelName, sizeof(modelName));
    new body[360];
    format(body, sizeof(body),
        "Вы собираетесь разобрать «%s» (номер %s) на запчасти.\n\n" \
        "Транспорт будет уничтожен, а детали поступят на склад авторазборки.\n" \
        "Продолжить?",
        modelName, sVehicles[slot][E_VEH_PLATE]);
    ShowPlayerDialog(playerid, DIALOG_VEHICLE_CHOP_CONFIRM, DIALOG_STYLE_MSGBOX,
        "{FFC800}Подтверждение разборки транспорта", body, "Разобрать", "Отмена");
    return 1;
}

CMD:vpark(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }
    if (IsPlayerInAnyVehicle(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Выйдите из транспорта перед постановкой в гараж.");
        return 1;
    }

    new propertyDbId = 0, garageCapacity = 0;
    if (!Properties_GetNearestOwnedGarage(playerid, propertyDbId, garageCapacity))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Вы должны находиться у собственного гаража или дома с гаражом.");
        return 1;
    }
    if (Vehicle_CountInGarage(propertyDbId) >= garageCapacity)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Гараж переполнен.");
        return 1;
    }

    new slot = -1;
    if (!Internal_GetNearestOwnedVehicle(playerid, VEHICLE_GARAGE_RADIUS, slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Рядом нет вашего транспортного средства.");
        return 1;
    }

    new plate[VEHICLE_PLATE_LEN];
    format(plate, sizeof(plate), "%s", sVehicles[slot][E_VEH_PLATE]);
    Vehicle_StoreInGarage(slot, propertyDbId);
    new msg[192];
    format(msg, sizeof(msg), "Транспорт %s помещен в гараж.", plate);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    Audit_Log(Character_GetId(playerid), "VEHICLE_GARAGE_STORE", "VEHICLE", "PROPERTY",
        0, 1, "Помещение транспорта в гараж");
    return 1;
}

CMD:vunpark(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }

    new propertyDbId = 0, garageCapacity = 0;
    if (!Properties_GetNearestOwnedGarage(playerid, propertyDbId, garageCapacity))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Вы должны находиться у собственного гаража или дома с гаражом.");
        return 1;
    }

    new rows[32];
    new const count = Vehicle_GetGarageList(propertyDbId, Character_GetId(playerid), rows, 32);
    if (count <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "В этом гараже нет вашего транспорта.");
        return 1;
    }

    sVehicleGarageProperty[playerid] = propertyDbId;
    sVehicleUnparkRowCount[playerid] = count;

    new body[1024];
    body[0] = '\0';
    for (new i = 0; i < count; i++)
    {
        sVehicleUnparkRowMap[playerid][i] = rows[i];
        new modelName[VEHICLE_MODEL_NAME_LEN], row[128];
        Internal_GetCatalogName(sVehicles[rows[i]][E_VEH_MODEL], modelName, sizeof(modelName));
        format(row, sizeof(row), "%s | номер %s\n", modelName, sVehicles[rows[i]][E_VEH_PLATE]);
        if ((strlen(body) + strlen(row)) >= sizeof(body))
        {
            break;
        }
        strcat(body, row, sizeof(body));
    }

    ShowPlayerDialog(playerid, DIALOG_VEHICLE_UNPARK, DIALOG_STYLE_LIST,
        "{FFC800}Транспорт в гараже", body, "Выехать", "Отмена");
    return 1;
}


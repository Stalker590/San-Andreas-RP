/*
 * =============================================================================
 *  SAN ANDREAS RP — Биржа логистики, грузоперевозки и перехват грузов
 *  Файл:      gamemodes/modules/systems/mod_logistics.pwn
 *  Пункт:     ROADMAP [6.4] — Биржа логистики и грузоперевозок (systems/mod_logistics.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_logistics_included
    #endinput
#endif
#define _mod_logistics_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ, ДИАЛОГИ И ПАРАМЕТРЫ ГРУЗОПЕРЕВОЗОК
// =============================================================================

#define MAX_LOGISTICS_CONTRACTS                 (512)
#define MAX_LOGISTICS_DIALOG_ROWS               (96)
#define LOGISTICS_DIALOG_BUFFER_LEN             (24576)

#define LOGISTICS_HUB_RADIUS                    (20.0)
#define LOGISTICS_LOAD_RADIUS                   (3.5)
#define LOGISTICS_TRUCK_RADIUS                  (8.0)
#define LOGISTICS_COMMAND_COOLDOWN_MS           (400)
#define LOGISTICS_RATE_PER_KG_USD               (3)
#define LOGISTICS_MAX_OPEN_PER_SOURCE           (3)
#define LOGISTICS_AUTO_CONTRACT_AMOUNT          (1000)
#define LOGISTICS_AUTO_CONTRACTS_PER_TICK       (3)
#define LOGISTICS_BLACK_MARKET_PERCENT          (55)

#define DIALOG_LOGISTICS_CONTRACTS              (1340)

#define INVALID_CONTRACT_SLOT                   (-1)

#define TOTAL_TRUCK_MODELS                      (10)

// =============================================================================
//  2. СТРУКТУРЫ КОНТРАКТОВ И СОСТОЯНИЕ (static stock)
// =============================================================================

enum E_LOGISTICS_STATUS
{
    CONTRACT_STATUS_OPEN = 0,
    CONTRACT_STATUS_IN_TRANSIT,
    CONTRACT_STATUS_COMPLETED,
    CONTRACT_STATUS_HIJACKED
};

enum E_LOGISTICS_CONTRACT
{
    bool:E_CONTRACT_VALID,
    E_CONTRACT_DB_ID,
    E_CONTRACT_SOURCE_ENT_DB_ID,
    E_CONTRACT_DEST_TYPE,
    E_CONTRACT_DEST_ID,
    E_CONTRACT_ITEM_DEF_ID,
    E_CONTRACT_AMOUNT,
    E_CONTRACT_TOTAL_WEIGHT_G,
    E_CONTRACT_TRUCKER_CHAR_ID,
    E_LOGISTICS_STATUS:E_CONTRACT_STATUS,
    E_CONTRACT_CREATED_AT
};

// =============================================================================
//  3. ИНКАПСУЛИРОВАННЫЕ ПУЛЫ И КАРТА БАГАЖНИКОВ (static stock)
// =============================================================================

static stock sContracts[MAX_LOGISTICS_CONTRACTS][E_LOGISTICS_CONTRACT];
static stock Iterator:ContractIter<MAX_LOGISTICS_CONTRACTS>;
static stock sNextContractDbId = 1;

static stock sVehicleTrunkSlot[MAX_VEHICLES_SERVER];
static stock sContractVehicle[MAX_LOGISTICS_CONTRACTS];

static stock sContractDialogRowMap[MAX_PLAYERS][MAX_LOGISTICS_DIALOG_ROWS];
static stock sContractDialogRowCount[MAX_PLAYERS];
static stock sLastLogisticsCommandTick[MAX_PLAYERS];
static stock sLogisticsDialogBuffer[LOGISTICS_DIALOG_BUFFER_LEN];

static stock const sTruckCapacities[TOTAL_TRUCK_MODELS][2] =
{
    { 403, 32000 }, // Linerunner
    { 414, 12000 }, // Mule
    { 455, 22000 }, // Flatbed
    { 456, 15000 }, // Yankee
    { 498, 10000 }, // Boxville
    { 499, 20000 }, // Benson
    { 514, 30000 }, // Tanker
    { 515, 30000 }, // Roadtrain
    { 524, 25000 }, // Cement Truck
    { 525, 8000  }  // Tow Truck
};

// =============================================================================
//  4. ВНУТРЕННИЕ ФУНКЦИИ КОНТРАКТОВ (static stock)
// =============================================================================

static stock Internal_ResetContract(contract_slot)
{
    sContracts[contract_slot][E_CONTRACT_VALID] = false;
    sContracts[contract_slot][E_CONTRACT_DB_ID] = 0;
    sContracts[contract_slot][E_CONTRACT_SOURCE_ENT_DB_ID] = 0;
    sContracts[contract_slot][E_CONTRACT_DEST_TYPE] = 0;
    sContracts[contract_slot][E_CONTRACT_DEST_ID] = 0;
    sContracts[contract_slot][E_CONTRACT_ITEM_DEF_ID] = 0;
    sContracts[contract_slot][E_CONTRACT_AMOUNT] = 0;
    sContracts[contract_slot][E_CONTRACT_TOTAL_WEIGHT_G] = 0;
    sContracts[contract_slot][E_CONTRACT_TRUCKER_CHAR_ID] = 0;
    sContracts[contract_slot][E_CONTRACT_STATUS] = CONTRACT_STATUS_OPEN;
    sContracts[contract_slot][E_CONTRACT_CREATED_AT] = 0;
    sContractVehicle[contract_slot] = 0;
}

static stock Internal_GetStatusName(E_LOGISTICS_STATUS:status, output[], len = sizeof(output))
{
    switch (status)
    {
        case CONTRACT_STATUS_OPEN:       format(output, len, "OPEN");
        case CONTRACT_STATUS_IN_TRANSIT: format(output, len, "IN_TRANSIT");
        case CONTRACT_STATUS_COMPLETED:  format(output, len, "COMPLETED");
        case CONTRACT_STATUS_HIJACKED:   format(output, len, "HIJACKED");
        default:                         format(output, len, "OPEN");
    }
    return 1;
}

static stock E_LOGISTICS_STATUS:Internal_ParseStatus(const statusStr[])
{
    if (!strcmp(statusStr, "IN_TRANSIT", true)) return CONTRACT_STATUS_IN_TRANSIT;
    if (!strcmp(statusStr, "COMPLETED", true))  return CONTRACT_STATUS_COMPLETED;
    if (!strcmp(statusStr, "HIJACKED", true))   return CONTRACT_STATUS_HIJACKED;
    return CONTRACT_STATUS_OPEN;
}

static stock Internal_AddContract(
    dbId,
    sourceEnterpriseDbId,
    destType,
    destId,
    itemDefId,
    amount,
    totalWeightG,
    truckerCharId,
    E_LOGISTICS_STATUS:status,
    createdAt)
{
    new const contractSlot = Iter_Free(ContractIter);
    if (contractSlot == INVALID_ITERATOR_SLOT)
    {
        return INVALID_CONTRACT_SLOT;
    }

    Iter_Add(ContractIter, contractSlot);
    Internal_ResetContract(contractSlot);

    sContracts[contractSlot][E_CONTRACT_VALID] = true;
    sContracts[contractSlot][E_CONTRACT_DB_ID] = dbId;
    sContracts[contractSlot][E_CONTRACT_SOURCE_ENT_DB_ID] = sourceEnterpriseDbId;
    sContracts[contractSlot][E_CONTRACT_DEST_TYPE] = destType;
    sContracts[contractSlot][E_CONTRACT_DEST_ID] = destId;
    sContracts[contractSlot][E_CONTRACT_ITEM_DEF_ID] = itemDefId;
    sContracts[contractSlot][E_CONTRACT_AMOUNT] = amount;
    sContracts[contractSlot][E_CONTRACT_TOTAL_WEIGHT_G] = totalWeightG;
    sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID] = truckerCharId;
    sContracts[contractSlot][E_CONTRACT_STATUS] = status;
    sContracts[contractSlot][E_CONTRACT_CREATED_AT] = createdAt;

    if (dbId >= sNextContractDbId)
    {
        sNextContractDbId = dbId + 1;
    }
    return contractSlot;
}

static stock Internal_UpdateContractDb(contract_slot)
{
    if (contract_slot < 0 || contract_slot >= MAX_LOGISTICS_CONTRACTS ||
        !sContracts[contract_slot][E_CONTRACT_VALID] || !DB_IsConnected())
    {
        return 0;
    }

    new statusStr[16];
    Internal_GetStatusName(sContracts[contract_slot][E_CONTRACT_STATUS], statusStr, sizeof(statusStr));

    new query[320];
    if (sContracts[contract_slot][E_CONTRACT_TRUCKER_CHAR_ID] > 0)
    {
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `logistics_contracts` SET `amount` = %d, `total_weight_g` = %d, `trucker_char_id` = %d, `status` = '%e' WHERE `id` = %d;",
            sContracts[contract_slot][E_CONTRACT_AMOUNT],
            sContracts[contract_slot][E_CONTRACT_TOTAL_WEIGHT_G],
            sContracts[contract_slot][E_CONTRACT_TRUCKER_CHAR_ID],
            statusStr,
            sContracts[contract_slot][E_CONTRACT_DB_ID]);
    }
    else
    {
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `logistics_contracts` SET `amount` = %d, `total_weight_g` = %d, `trucker_char_id` = NULL, `status` = '%e' WHERE `id` = %d;",
            sContracts[contract_slot][E_CONTRACT_AMOUNT],
            sContracts[contract_slot][E_CONTRACT_TOTAL_WEIGHT_G],
            statusStr,
            sContracts[contract_slot][E_CONTRACT_DB_ID]);
    }
    mysql_tquery(gMySQL, query);
    return 1;
}

static stock Internal_LoadContractsSync()
{
    for (new i = 0; i < MAX_LOGISTICS_CONTRACTS; i++)
    {
        Internal_ResetContract(i);
    }
    Iter_Init(ContractIter);
    sNextContractDbId = 1;

    for (new vehicleId = 0; vehicleId < MAX_VEHICLES_SERVER; vehicleId++)
    {
        sVehicleTrunkSlot[vehicleId] = INVALID_STORAGE_SLOT;
    }

    if (!DB_IsConnected())
    {
        printf("%s [Systems/Logistics] MySQL недоступен: контракты будут создаваться в оперативной памяти.",
            SERVER_LOG_PREFIX);
        return 0;
    }

    // Разрешенный синхронный запрос строго внутри OnGameModeInit:
    // поднимаем счетчик ID выше максимального ID всех (включая завершенные) контрактов.
    new const Cache:maxIdCache = mysql_query(gMySQL,
        "SELECT IFNULL(MAX(`id`), 0) AS `max_id` FROM `logistics_contracts`;",
        true);
    if (cache_is_valid(maxIdCache))
    {
        new maxContractId = 0;
        cache_get_value_name_int(0, "max_id", maxContractId);
        if (maxContractId >= sNextContractDbId)
        {
            sNextContractDbId = maxContractId + 1;
        }
        cache_delete(maxIdCache);
    }

    // Разрешенный синхронный запрос строго внутри OnGameModeInit
    new const Cache:cache = mysql_query(gMySQL,
        "SELECT `id`, `source_ent_id`, `dest_type`, `dest_id`, `item_def_id`, `amount`, `total_weight_g`, IFNULL(`trucker_char_id`, 0) AS `trucker`, `status`, UNIX_TIMESTAMP(`created_at`) AS `created_ts` FROM `logistics_contracts` WHERE `status` IN ('OPEN', 'IN_TRANSIT') ORDER BY `id` ASC;",
        true);

    if (!cache_is_valid(cache))
    {
        printf("%s [Systems/Logistics] [WARN] Не удалось прочитать logistics_contracts.",
            SERVER_LOG_PREFIX);
        return 0;
    }

    new rowCount = 0;
    cache_get_row_count(rowCount);
    new loadedContracts = 0;

    for (new row = 0; row < rowCount; row++)
    {
        new dbId, sourceEntId, destId, itemDefId, amount, totalWeightG, truckerCharId, createdAt;
        new destTypeStr[16], statusStr[16];

        cache_get_value_name_int(row, "id", dbId);
        cache_get_value_name_int(row, "source_ent_id", sourceEntId);
        cache_get_value_name(row, "dest_type", destTypeStr, sizeof(destTypeStr));
        cache_get_value_name_int(row, "dest_id", destId);
        cache_get_value_name_int(row, "item_def_id", itemDefId);
        cache_get_value_name_int(row, "amount", amount);
        cache_get_value_name_int(row, "total_weight_g", totalWeightG);
        cache_get_value_name_int(row, "trucker", truckerCharId);
        cache_get_value_name(row, "status", statusStr, sizeof(statusStr));
        cache_get_value_name_int(row, "created_ts", createdAt);

        new const destType = (!strcmp(destTypeStr, "PORT", true))
            ? LOGISTICS_DEST_PORT
            : LOGISTICS_DEST_ENTERPRISE;

        if (Internal_AddContract(
                dbId,
                sourceEntId,
                destType,
                destId,
                itemDefId,
                amount,
                totalWeightG,
                truckerCharId,
                Internal_ParseStatus(statusStr),
                createdAt) != INVALID_CONTRACT_SLOT)
        {
            loadedContracts++;
        }
    }
    cache_delete(cache);

    printf("%s [Systems/Logistics] Контракты загружены из MySQL (активных: %d).",
        SERVER_LOG_PREFIX, loadedContracts);
    return loadedContracts;
}

static stock Internal_LoadExistingTrunksSync()
{
    for (new vehicleId = 0; vehicleId < MAX_VEHICLES_SERVER; vehicleId++)
    {
        sVehicleTrunkSlot[vehicleId] = INVALID_STORAGE_SLOT;
    }

    if (!DB_IsConnected())
    {
        return 0;
    }

    // Очистка пустых грузовых отсеков, созданных более 7 дней назад
    new const Cache:cleanupCache = mysql_query(gMySQL,
        "DELETE s FROM `storages` s LEFT JOIN `storage_items` si ON si.`storage_id` = s.`id` WHERE s.`storage_type` = 'VEHICLE_TRUNK' AND si.`id` IS NULL AND s.`created_at` < DATE_SUB(NOW(), INTERVAL 7 DAY);");
    if (cache_is_valid(cleanupCache))
    {
        cache_delete(cleanupCache);
    }

    // Разрешенный синхронный запрос строго внутри OnGameModeInit
    new const Cache:cache = mysql_query(gMySQL,
        "SELECT `id`, `owner_id`, `max_weight_g`, `max_volume_ml` FROM `storages` WHERE `storage_type` = 'VEHICLE_TRUNK' ORDER BY `id` DESC LIMIT 256;",
        true);

    if (!cache_is_valid(cache))
    {
        return 0;
    }

    new rowCount = 0;
    cache_get_row_count(rowCount);
    new loadedTrunks = 0;

    for (new row = 0; row < rowCount; row++)
    {
        new dbId, ownerId, maxWeightG, maxVolumeMl;
        cache_get_value_name_int(row, "id", dbId);
        cache_get_value_name_int(row, "owner_id", ownerId);
        cache_get_value_name_int(row, "max_weight_g", maxWeightG);
        cache_get_value_name_int(row, "max_volume_ml", maxVolumeMl);

        if (ownerId > 0 && ownerId < MAX_VEHICLES_SERVER)
        {
            new const trunkSlot = Storage_Load(
                dbId,
                STORAGE_VEHICLE_TRUNK,
                ownerId,
                maxWeightG,
                maxVolumeMl);
            if (trunkSlot != INVALID_STORAGE_SLOT)
            {
                if (!Storage_IsValidSlot(sVehicleTrunkSlot[ownerId]))
                {
                    sVehicleTrunkSlot[ownerId] = trunkSlot;
                }
                loadedTrunks++;
            }
        }
    }
    cache_delete(cache);
    return loadedTrunks;
}

// =============================================================================
//  5. ВНУТРЕННИЕ ФУНКЦИИ ТРАНСПОРТА И БАГАЖНИКОВ (static stock)
// =============================================================================

static stock bool:Internal_GetTruckCapacity(vehicle_model, &maxWeightG, &maxVolumeMl)
{
    maxWeightG = 0;
    maxVolumeMl = 0;

    for (new i = 0; i < TOTAL_TRUCK_MODELS; i++)
    {
        if (sTruckCapacities[i][0] == vehicle_model)
        {
            maxWeightG = sTruckCapacities[i][1] * 1000;
            maxVolumeMl = sTruckCapacities[i][1] * 1000;
            return true;
        }
    }
    return false;
}

static stock Internal_FindVehicleTrunkSlot(vehicleid)
{
    if (vehicleid <= 0 || vehicleid >= MAX_VEHICLES_SERVER)
    {
        return INVALID_STORAGE_SLOT;
    }

    new slotId = sVehicleTrunkSlot[vehicleid];
    if (Storage_IsValidSlot(slotId))
    {
        return slotId;
    }

    foreach (new storageSlot : StorageIter)
    {
        if (Storage_GetType(storageSlot) == STORAGE_VEHICLE_TRUNK &&
            Storage_GetOwnerId(storageSlot) == vehicleid)
        {
            sVehicleTrunkSlot[vehicleid] = storageSlot;
            return storageSlot;
        }
    }
    return INVALID_STORAGE_SLOT;
}

stock Logistics_GetVehicleTrunkSlot(vehicleid)
{
    if (vehicleid <= 0 || vehicleid >= MAX_VEHICLES_SERVER)
    {
        return INVALID_STORAGE_SLOT;
    }
    if (!IsValidVehicle(vehicleid))
    {
        return INVALID_STORAGE_SLOT;
    }

    new slotId = Internal_FindVehicleTrunkSlot(vehicleid);
    if (slotId != INVALID_STORAGE_SLOT)
    {
        return slotId;
    }

    new maxWeightG, maxVolumeMl;
    if (!Internal_GetTruckCapacity(GetVehicleModel(vehicleid), maxWeightG, maxVolumeMl))
    {
        return INVALID_STORAGE_SLOT;
    }

    new Float:x, Float:y, Float:z;
    GetVehiclePos(vehicleid, x, y, z);

    slotId = Storage_Create(
        STORAGE_VEHICLE_TRUNK,
        vehicleid,
        maxWeightG,
        maxVolumeMl,
        false,
        0,
        x, y, z,
        0,
        0,
        0);

    if (slotId == INVALID_STORAGE_SLOT)
    {
        return INVALID_STORAGE_SLOT;
    }

    sVehicleTrunkSlot[vehicleid] = slotId;
    return slotId;
}

static stock Internal_GetPlayerDriverVehicle(playerid)
{
    if (!IsPlayerInAnyVehicle(playerid))
    {
        return 0;
    }
    if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
    {
        return 0;
    }
    return GetPlayerVehicleID(playerid);
}

static stock Internal_GetActiveContractSlot(playerid, bool:inTransitOnly)
{
    if (!Character_IsLoaded(playerid))
    {
        return INVALID_CONTRACT_SLOT;
    }

    new const charId = Character_GetId(playerid);
    foreach (new contractSlot : ContractIter)
    {
        if (!sContracts[contractSlot][E_CONTRACT_VALID])
        {
            continue;
        }
        if (sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID] != charId)
        {
            continue;
        }
        if (inTransitOnly && sContracts[contractSlot][E_CONTRACT_STATUS] != CONTRACT_STATUS_IN_TRANSIT)
        {
            continue;
        }
        if (sContracts[contractSlot][E_CONTRACT_STATUS] != CONTRACT_STATUS_OPEN &&
            sContracts[contractSlot][E_CONTRACT_STATUS] != CONTRACT_STATUS_IN_TRANSIT)
        {
            continue;
        }
        return contractSlot;
    }
    return INVALID_CONTRACT_SLOT;
}

static stock Internal_IsPortDestination(dest_id)
{
    return (dest_id >= 1 && dest_id <= 3);
}

static stock Internal_GetDestinationName(contract_slot, output[], len = sizeof(output))
{
    if (contract_slot < 0 || contract_slot >= MAX_LOGISTICS_CONTRACTS ||
        !sContracts[contract_slot][E_CONTRACT_VALID])
    {
        format(output, len, "Неизвестно");
        return 0;
    }

    if (sContracts[contract_slot][E_CONTRACT_DEST_TYPE] == LOGISTICS_DEST_PORT)
    {
        Ports_GetPortNameRu(sContracts[contract_slot][E_CONTRACT_DEST_ID], output, len);
    }
    else
    {
        new const destEnterpriseSlot = Enterprise_FindByDbId(sContracts[contract_slot][E_CONTRACT_DEST_ID]);
        if (Enterprise_IsValid(destEnterpriseSlot))
        {
            Enterprise_GetName(destEnterpriseSlot, output, len);
        }
        else
        {
            format(output, len, "Предприятие #%d", sContracts[contract_slot][E_CONTRACT_DEST_ID]);
        }
    }
    return 1;
}

static stock Internal_CountOpenContractsForSource(sourceEnterpriseDbId)
{
    new count = 0;
    foreach (new contractSlot : ContractIter)
    {
        if (!sContracts[contractSlot][E_CONTRACT_VALID])
        {
            continue;
        }
        if (sContracts[contractSlot][E_CONTRACT_SOURCE_ENT_DB_ID] != sourceEnterpriseDbId)
        {
            continue;
        }
        if (sContracts[contractSlot][E_CONTRACT_STATUS] == CONTRACT_STATUS_OPEN ||
            sContracts[contractSlot][E_CONTRACT_STATUS] == CONTRACT_STATUS_IN_TRANSIT)
        {
            count++;
        }
    }
    return count;
}

static stock Internal_ContractAlreadyExists(sourceEnterpriseDbId, item_def_id)
{
    foreach (new contractSlot : ContractIter)
    {
        if (!sContracts[contractSlot][E_CONTRACT_VALID])
        {
            continue;
        }
        if (sContracts[contractSlot][E_CONTRACT_SOURCE_ENT_DB_ID] == sourceEnterpriseDbId &&
            sContracts[contractSlot][E_CONTRACT_ITEM_DEF_ID] == item_def_id &&
            (sContracts[contractSlot][E_CONTRACT_STATUS] == CONTRACT_STATUS_OPEN ||
             sContracts[contractSlot][E_CONTRACT_STATUS] == CONTRACT_STATUS_IN_TRANSIT))
        {
            return true;
        }
    }
    return false;
}

static stock Internal_FinishContractProgression(contract_slot)
{
    if (contract_slot < 0 || contract_slot >= MAX_LOGISTICS_CONTRACTS)
    {
        return 0;
    }

    if (sContracts[contract_slot][E_CONTRACT_AMOUNT] <= 0)
    {
        sContracts[contract_slot][E_CONTRACT_STATUS] = CONTRACT_STATUS_COMPLETED;
        sContracts[contract_slot][E_CONTRACT_AMOUNT] = 0;
        sContracts[contract_slot][E_CONTRACT_TOTAL_WEIGHT_G] = 0;
        Internal_UpdateContractDb(contract_slot);
        Internal_ResetContract(contract_slot);
        Iter_Remove(ContractIter, contract_slot);
        return 1;
    }

    sContracts[contract_slot][E_CONTRACT_STATUS] = CONTRACT_STATUS_OPEN;
    sContracts[contract_slot][E_CONTRACT_TRUCKER_CHAR_ID] = 0;
    Internal_UpdateContractDb(contract_slot);
    return 1;
}

static stock Internal_GetBlackMarketPrice(item_def_id)
{
    if (!Item_IsValid(item_def_id))
    {
        return 0;
    }

    new bestPortPrice = 0;
    for (new portId = 1; portId <= 3; portId++)
    {
        new const sellPrice = Ports_GetSellPrice(portId, item_def_id);
        if (sellPrice > bestPortPrice)
        {
            bestPortPrice = sellPrice;
        }
    }

    if (bestPortPrice > 0)
    {
        new price = (bestPortPrice * LOGISTICS_BLACK_MARKET_PERCENT) / 100;
        return (price > 0) ? price : 1;
    }

    new const baseWeight = Item_GetBaseWeight(item_def_id);
    switch (Item_GetCategory(item_def_id))
    {
        case ITEM_CAT_FIREARM, ITEM_CAT_HEAVY_THROWABLE, ITEM_CAT_ILLEGAL:
        {
            new price = baseWeight / 10;
            return (price > 0) ? price : 1;
        }
    }

    new price = baseWeight / 50;
    return (price > 0) ? price : 1;
}

static stock bool:Internal_IsBlackMarketItem(item_def_id)
{
    if (!Item_IsValid(item_def_id) || item_def_id == ITEM_ID_CASH_BUNDLE)
    {
        return false;
    }

    switch (Item_GetCategory(item_def_id))
    {
        case ITEM_CAT_RAW, ITEM_CAT_INTERMEDIATE, ITEM_CAT_MELEE, ITEM_CAT_FIREARM,
             ITEM_CAT_HEAVY_THROWABLE, ITEM_CAT_ILLEGAL:
        {
            return true;
        }
    }
    return false;
}

// =============================================================================
//  6. ПУБЛИЧНЫЙ API СОЗДАНИЯ КОНТРАКТОВ И ЭКСПОРТА
// =============================================================================

stock bool:Logistics_CreateContract(source_ent_id, dest_type, dest_id, item_def_id, amount, create_by_char_id)
{
    if (source_ent_id <= 0 || dest_id <= 0 || amount <= 0 || amount > 100000 ||
        !Item_IsValid(item_def_id))
    {
        return false;
    }
    if (dest_type != LOGISTICS_DEST_ENTERPRISE && dest_type != LOGISTICS_DEST_PORT)
    {
        return false;
    }

    new const sourceEnterpriseSlot = Enterprise_FindByDbId(source_ent_id);
    if (!Enterprise_IsValid(sourceEnterpriseSlot))
    {
        return false;
    }

    new const warehouseSlot = Enterprise_GetWarehouseSlot(sourceEnterpriseSlot);
    if (!Storage_IsValidSlot(warehouseSlot) || !Storage_AreItemsReady(warehouseSlot))
    {
        return false;
    }

    new const availableAmount = Storage_CountItemInTree(warehouseSlot, item_def_id);
    if (availableAmount < amount)
    {
        return false;
    }

    if (dest_type == LOGISTICS_DEST_ENTERPRISE)
    {
        if (!Enterprise_IsValid(Enterprise_FindByDbId(dest_id)))
        {
            return false;
        }
    }
    else
    {
        if (!Internal_IsPortDestination(dest_id) || Ports_GetSellPrice(dest_id, item_def_id) <= 0)
        {
            return false;
        }
    }

    new const totalWeightG = Item_CalculateInstanceWeight(item_def_id, amount);
    new const contractDbId = sNextContractDbId;
    new const contractSlot = Internal_AddContract(
        contractDbId,
        source_ent_id,
        dest_type,
        dest_id,
        item_def_id,
        amount,
        totalWeightG,
        0,
        CONTRACT_STATUS_OPEN,
        gettime());

    if (contractSlot == INVALID_CONTRACT_SLOT)
    {
        return false;
    }

    if (DB_IsConnected())
    {
        new query[384];
        mysql_format(gMySQL, query, sizeof(query),
            "INSERT INTO `logistics_contracts` (`id`, `source_ent_id`, `dest_type`, `dest_id`, `item_def_id`, `amount`, `total_weight_g`, `trucker_char_id`, `status`) VALUES (%d, %d, '%e', %d, %d, %d, %d, NULL, 'OPEN');",
            contractDbId,
            source_ent_id,
            (dest_type == LOGISTICS_DEST_PORT) ? ("PORT") : ("ENTERPRISE"),
            dest_id,
            item_def_id,
            amount,
            totalWeightG);
        mysql_tquery(gMySQL, query);
    }

    new sourceName[64], destName[64], itemName[64], auditDetails[224];
    Enterprise_GetName(sourceEnterpriseSlot, sourceName);
    Internal_GetDestinationName(contractSlot, destName, sizeof(destName));
    Item_GetName(item_def_id, itemName);
    format(auditDetails, sizeof(auditDetails),
        "Создан контракт #%d: %s (кол-во: %d, вес: %d г) из '%s' в '%s'.",
        contractDbId, itemName, amount, totalWeightG, sourceName, destName);
    Audit_Log(
        create_by_char_id,
        "CONTRACT_CREATE",
        "ENTERPRISE_WAREHOUSE",
        "LOGISTICS_CONTRACT",
        item_def_id,
        amount,
        auditDetails);

    return true;
}

stock Logistics_UnloadAtPort(playerid, port_id)
{
    if (!Character_IsLoaded(playerid) || port_id < 1 || port_id > 3)
    {
        return 0;
    }
    if (Ports_FindNearestPort(playerid, LOGISTICS_TRUCK_RADIUS) != port_id)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Подгоните фуру ближе к портовому терминалу.");
        return 0;
    }

    new const vehicleId = Internal_GetPlayerDriverVehicle(playerid);
    if (vehicleId <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Вы должны находиться за рулем грузовика.");
        return 0;
    }

    new const contractSlot = Internal_GetActiveContractSlot(playerid, true);
    if (contractSlot == INVALID_CONTRACT_SLOT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: У вас нет активного контракта в пути.");
        return 0;
    }
    if (sContracts[contractSlot][E_CONTRACT_DEST_TYPE] != LOGISTICS_DEST_PORT ||
        sContracts[contractSlot][E_CONTRACT_DEST_ID] != port_id)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Этот контракт оформлен на другой порт.");
        return 0;
    }

    new const trunkSlot = Logistics_GetVehicleTrunkSlot(vehicleId);
    if (!Storage_IsValidSlot(trunkSlot) || !Storage_AreItemsReady(trunkSlot))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Логистика]: Грузовой отсек недоступен или еще загружается.");
        return 0;
    }

    new const itemDefId = sContracts[contractSlot][E_CONTRACT_ITEM_DEF_ID];
    new amount = Storage_CountItemInTree(trunkSlot, itemDefId);
    if (amount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: В кузове нет груза по контракту.");
        return 0;
    }
    if (amount > sContracts[contractSlot][E_CONTRACT_AMOUNT])
    {
        amount = sContracts[contractSlot][E_CONTRACT_AMOUNT];
    }

    if (!Storage_AcquireMutex(trunkSlot, playerid))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Логистика]: Кузов занят другим действием.");
        return 0;
    }
    new const removedAmount = Storage_RemoveItemInTree(trunkSlot, itemDefId, amount);
    Storage_ReleaseMutex(trunkSlot);

    if (removedAmount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Не удалось выгрузить груз из кузова.");
        return 0;
    }

    new const E_LOGISTICS_STATUS:oldStatus = sContracts[contractSlot][E_CONTRACT_STATUS];
    new const oldTrucker = sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID];

    new const revenue = Ports_SellCargoToPort(
        playerid,
        port_id,
        itemDefId,
        removedAmount,
        sContracts[contractSlot][E_CONTRACT_SOURCE_ENT_DB_ID],
        sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID]);

    if (revenue <= 0)
    {
        // Возврат груза в кузов при отказе порта
        new outItemSlot = INVALID_STORAGE_ITEM_SLOT;
        Storage_AddItem(trunkSlot, itemDefId, removedAmount, 0, 100.0, 0, 0, "", outItemSlot);
        sContracts[contractSlot][E_CONTRACT_STATUS] = oldStatus;
        sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID] = oldTrucker;
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Порт отказал в приеме груза. Груз возвращен в кузов.");
        return 0;
    }

    new const deliveredWeightG = Item_CalculateInstanceWeight(itemDefId, removedAmount);
    sContracts[contractSlot][E_CONTRACT_AMOUNT] -= removedAmount;
    sContracts[contractSlot][E_CONTRACT_TOTAL_WEIGHT_G] -= deliveredWeightG;
    if (sContracts[contractSlot][E_CONTRACT_TOTAL_WEIGHT_G] < 0)
    {
        sContracts[contractSlot][E_CONTRACT_TOTAL_WEIGHT_G] = 0;
    }

    new itemName[64], msg[192];
    Item_GetName(itemDefId, itemName);
    format(msg, sizeof(msg),
        "[Логистика]: Выгружено в порт: %s (количество: %d). Выручка: $%d.",
        itemName, removedAmount, revenue);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    sContractVehicle[contractSlot] = 0;
    Internal_FinishContractProgression(contractSlot);
    return 1;
}

// =============================================================================
//  7. ВНУТРЕННИЕ ОПЕРАЦИИ КОМАНД /cargo
// =============================================================================

static stock Internal_LoadCargo(playerid)
{
    new const vehicleId = Internal_GetPlayerDriverVehicle(playerid);
    if (vehicleId <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Сядьте за руль грузового автомобиля.");
        return 0;
    }

    new maxWeightG, maxVolumeMl;
    if (!Internal_GetTruckCapacity(GetVehicleModel(vehicleId), maxWeightG, maxVolumeMl))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Логистика]: Этот транспорт не предназначен для грузоперевозок.");
        return 0;
    }

    new const contractSlot = Internal_GetActiveContractSlot(playerid, false);
    if (contractSlot == INVALID_CONTRACT_SLOT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Логистика]: Сначала возьмите контракт командой /contracts.");
        return 0;
    }
    if (sContracts[contractSlot][E_CONTRACT_STATUS] != CONTRACT_STATUS_OPEN)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Логистика]: Груз по этому контракту уже находится в пути.");
        return 0;
    }

    new const sourceEnterpriseSlot = Enterprise_FindByDbId(
        sContracts[contractSlot][E_CONTRACT_SOURCE_ENT_DB_ID]);
    if (!Enterprise_IsValid(sourceEnterpriseSlot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Предприятие-отправитель не найдено.");
        return 0;
    }
    if (!Enterprise_IsPlayerNearWarehouse(playerid, sourceEnterpriseSlot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Логистика]: Подгоните фуру вплотную к складу предприятия-отправителя.");
        return 0;
    }

    new const warehouseSlot = Enterprise_GetWarehouseSlot(sourceEnterpriseSlot);
    if (!Storage_IsValidSlot(warehouseSlot) || !Storage_AreItemsReady(warehouseSlot))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Логистика]: Склад еще загружается. Повторите через секунду.");
        return 0;
    }

    new const trunkSlot = Logistics_GetVehicleTrunkSlot(vehicleId);
    if (!Storage_IsValidSlot(trunkSlot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Не удалось подготовить грузовой отсек фуры.");
        return 0;
    }
    if (!Storage_AreItemsReady(trunkSlot))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Логистика]: Грузовой отсек еще загружается. Повторите через секунду.");
        return 0;
    }

    if (Storage_GetCurrentWeight(trunkSlot) > 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Логистика]: Кузов не пуст. Сначала разгрузите предыдущий груз.");
        return 0;
    }

    new const itemDefId = sContracts[contractSlot][E_CONTRACT_ITEM_DEF_ID];
    new const warehouseAmount = Storage_CountItemInTree(warehouseSlot, itemDefId);
    if (warehouseAmount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: На складе нет груза по контракту.");
        return 0;
    }

    new loadAmount = sContracts[contractSlot][E_CONTRACT_AMOUNT];
    if (loadAmount > warehouseAmount)
    {
        loadAmount = warehouseAmount;
    }

    // Ограничение по свободной грузоподъемности кузова
    new const unitWeightG = Item_CalculateInstanceWeight(itemDefId, 1);
    new const unitVolumeMl = Item_CalculateInstanceVolume(itemDefId, 1);
    new const freeWeightG = Storage_GetMaxWeight(trunkSlot) - Storage_GetCurrentWeight(trunkSlot);
    new const freeVolumeMl = Storage_GetMaxVolume(trunkSlot) - Storage_GetCurrentVolume(trunkSlot);
    if (unitWeightG > 0)
    {
        new const capacityAmount = freeWeightG / unitWeightG;
        if (loadAmount > capacityAmount)
        {
            loadAmount = capacityAmount;
        }
    }
    if (unitVolumeMl > 0)
    {
        new const volumeCapacityAmount = freeVolumeMl / unitVolumeMl;
        if (loadAmount > volumeCapacityAmount)
        {
            loadAmount = volumeCapacityAmount;
        }
    }
    if (loadAmount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Грузоподъемность кузова исчерпана.");
        return 0;
    }

    new movedAmount = 0;
    new itemSlot = Storage_GetFirstItemSlot(warehouseSlot);
    new remaining = loadAmount;

    while (itemSlot != INVALID_STORAGE_ITEM_SLOT && remaining > 0)
    {
        new const nextItemSlot = Storage_GetNextItemSlot(itemSlot);
        if (Storage_GetItemDefId(itemSlot) == itemDefId)
        {
            new const itemAmount = Storage_GetItemAmount(itemSlot);
            new const takeAmount = (itemAmount < remaining) ? itemAmount : remaining;
            if (takeAmount > 0 &&
                Storage_TransferItem(
                    playerid,
                    warehouseSlot,
                    itemSlot,
                    trunkSlot,
                    takeAmount,
                    Character_GetId(playerid)) == STORAGE_RES_OK)
            {
                remaining -= takeAmount;
                movedAmount += takeAmount;
            }
        }
        itemSlot = nextItemSlot;
    }

    if (movedAmount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Не удалось загрузить груз в кузов.");
        return 0;
    }

    sContracts[contractSlot][E_CONTRACT_STATUS] = CONTRACT_STATUS_IN_TRANSIT;
    sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID] = Character_GetId(playerid);
    Internal_UpdateContractDb(contractSlot);
    sContractVehicle[contractSlot] = vehicleId;

    new itemName[64], weightStr[32], msg[224];
    Item_GetName(itemDefId, itemName);
    Utils_FormatWeightGrams(Item_CalculateInstanceWeight(itemDefId, movedAmount), weightStr);
    format(msg, sizeof(msg),
        "[Логистика]: Погружено в фуру: %s (количество: %d, вес: %s). Следуйте к точке разгрузки.",
        itemName, movedAmount, weightStr);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new auditDetails[192];
    format(auditDetails, sizeof(auditDetails),
        "Погрузка по контракту #%d: %s (кол-во: %d, вес: %d г) в транспорт #%d.",
        sContracts[contractSlot][E_CONTRACT_DB_ID], itemName, movedAmount,
        Item_CalculateInstanceWeight(itemDefId, movedAmount), vehicleId);
    Audit_Log(
        Character_GetId(playerid),
        "CONTRACT_LOAD",
        "ENTERPRISE_WAREHOUSE",
        "VEHICLE_TRUNK",
        itemDefId,
        movedAmount,
        auditDetails);
    return 1;
}

static stock Internal_AddGovernmentBalance(amountUsd)
{
    if (amountUsd <= 0 || !DB_IsConnected())
    {
        return 0;
    }

    new query[192];
    mysql_format(gMySQL, query, sizeof(query),
        "UPDATE `organizations` SET `bank_balance_usd` = `bank_balance_usd` + %d WHERE `id` = 1;",
        amountUsd);
    mysql_tquery(gMySQL, query);
    return 1;
}

static stock Internal_UnloadCargoAtEnterprise(playerid)
{
    new const vehicleId = Internal_GetPlayerDriverVehicle(playerid);
    if (vehicleId <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Вы должны находиться за рулем фуры.");
        return 0;
    }

    new const contractSlot = Internal_GetActiveContractSlot(playerid, true);
    if (contractSlot == INVALID_CONTRACT_SLOT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Нет активного контракта в пути.");
        return 0;
    }
    if (sContracts[contractSlot][E_CONTRACT_DEST_TYPE] != LOGISTICS_DEST_ENTERPRISE)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Этот контракт оформлен на порт.");
        return 0;
    }

    new const destEnterpriseSlot = Enterprise_FindByDbId(sContracts[contractSlot][E_CONTRACT_DEST_ID]);
    if (!Enterprise_IsValid(destEnterpriseSlot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Предприятие-получатель не найдено.");
        return 0;
    }
    if (!Enterprise_IsPlayerNearWarehouse(playerid, destEnterpriseSlot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Логистика]: Подгоните фуру вплотную к складу получателя.");
        return 0;
    }

    new const warehouseSlot = Enterprise_GetWarehouseSlot(destEnterpriseSlot);
    if (!Storage_IsValidSlot(warehouseSlot) || !Storage_AreItemsReady(warehouseSlot))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Логистика]: Склад получателя еще загружается.");
        return 0;
    }

    new const trunkSlot = Logistics_GetVehicleTrunkSlot(vehicleId);
    if (!Storage_IsValidSlot(trunkSlot) || !Storage_AreItemsReady(trunkSlot))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Логистика]: Грузовой отсек недоступен или еще загружается.");
        return 0;
    }

    new const itemDefId = sContracts[contractSlot][E_CONTRACT_ITEM_DEF_ID];
    new amount = Storage_CountItemInTree(trunkSlot, itemDefId);
    if (amount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: В кузове нет груза по контракту.");
        return 0;
    }
    if (amount > sContracts[contractSlot][E_CONTRACT_AMOUNT])
    {
        amount = sContracts[contractSlot][E_CONTRACT_AMOUNT];
    }

    new const deliveredWeightG = Item_CalculateInstanceWeight(itemDefId, amount);
    new feeUsd = (deliveredWeightG * LOGISTICS_RATE_PER_KG_USD) / 1000;
    if (feeUsd > 0 && Roles_HasPerk(Character_GetRoleId(playerid), PERK_TRUCKER_BONUS_20))
    {
        feeUsd = (feeUsd * 120) / 100;
    }
    if (feeUsd <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Партия слишком мала для оплаты перевозки.");
        return 0;
    }

    new const buyPricePerUnit = Economy_GetBuyRawPrice(destEnterpriseSlot, itemDefId);
    new const sourceEnterpriseDbId = sContracts[contractSlot][E_CONTRACT_SOURCE_ENT_DB_ID];
    if (buyPricePerUnit <= 0 && Enterprise_GetDbId(destEnterpriseSlot) != sourceEnterpriseDbId)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Логистика]: У получателя нет активного закупочного ордера на этот товар. Разгрузка отклонена.");
        return 0;
    }

    new goodsValueUsd = 0;
    if (buyPricePerUnit > 0)
    {
        if (amount > (2000000000 / buyPricePerUnit))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Слишком большая стоимость партии для расчета.");
            return 0;
        }
        goodsValueUsd = buyPricePerUnit * amount;
    }

    if (Enterprise_GetReserve(destEnterpriseSlot) < (feeUsd + goodsValueUsd))
    {
        new msg[224];
        format(msg, sizeof(msg),
            "[Логистика]: В кассе получателя недостаточно средств. Нужно $%d (товар $%d + доставка $%d).",
            goodsValueUsd + feeUsd, goodsValueUsd, feeUsd);
        SendClientMessage(playerid, COLOR_UI_ERROR, msg);
        return 0;
    }

    new movedAmount = 0;
    new itemSlot = Storage_GetFirstItemSlot(trunkSlot);
    new remaining = amount;

    while (itemSlot != INVALID_STORAGE_ITEM_SLOT && remaining > 0)
    {
        new const nextItemSlot = Storage_GetNextItemSlot(itemSlot);
        if (Storage_GetItemDefId(itemSlot) == itemDefId)
        {
            new const itemAmount = Storage_GetItemAmount(itemSlot);
            new const takeAmount = (itemAmount < remaining) ? itemAmount : remaining;
            if (takeAmount > 0 &&
                Storage_TransferItem(
                    playerid,
                    trunkSlot,
                    itemSlot,
                    warehouseSlot,
                    takeAmount,
                    Character_GetId(playerid)) == STORAGE_RES_OK)
            {
                remaining -= takeAmount;
                movedAmount += takeAmount;
            }
        }
        itemSlot = nextItemSlot;
    }

    if (movedAmount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Логистика]: Не удалось выгрузить груз (склад переполнен или занят).");
        return 0;
    }

    new const actualWeightG = Item_CalculateInstanceWeight(itemDefId, movedAmount);
    new actualFeeUsd = (actualWeightG * LOGISTICS_RATE_PER_KG_USD) / 1000;
    if (actualFeeUsd > 0 && Roles_HasPerk(Character_GetRoleId(playerid), PERK_TRUCKER_BONUS_20))
    {
        actualFeeUsd = (actualFeeUsd * 120) / 100;
    }
    new actualGoodsValueUsd = 0;
    if (buyPricePerUnit > 0 && movedAmount <= (2000000000 / buyPricePerUnit))
    {
        actualGoodsValueUsd = buyPricePerUnit * movedAmount;
    }
    if ((actualFeeUsd + actualGoodsValueUsd) > Enterprise_GetReserve(destEnterpriseSlot))
    {
        actualFeeUsd = Enterprise_GetReserve(destEnterpriseSlot);
        actualGoodsValueUsd = 0;
    }

    if (actualFeeUsd > 0)
    {
        if (!Character_AddPhysicalCashUsd(playerid, actualFeeUsd, CASH_FLAG_CLEAN))
        {
            new Float:x, Float:y, Float:z;
            GetPlayerPos(playerid, x, y, z);
            new const dropSlot = Storage_CreateWorldDrop(
                x, y, z,
                GetPlayerInterior(playerid),
                GetPlayerVirtualWorld(playerid),
                ITEM_ID_CASH_BUNDLE);
            if (dropSlot != INVALID_STORAGE_SLOT)
            {
                new remainingCash = actualFeeUsd;
                while (remainingCash > 0)
                {
                    new const chunk = (remainingCash > 10000) ? 10000 : remainingCash;
                    new outItemSlot = INVALID_STORAGE_ITEM_SLOT;
                    if (Storage_AddItem(dropSlot, ITEM_ID_CASH_BUNDLE, chunk, 0, 100.0,
                            CASH_FLAG_CLEAN, CURRENCY_USD, "", outItemSlot) != STORAGE_RES_OK)
                    {
                        break;
                    }
                    remainingCash -= chunk;
                }
            }
            SendClientMessage(playerid, COLOR_UI_WARNING,
                "[Логистика]: Оплата не поместилась в инвентарь и выдана на земле.");
        }
        Enterprise_TakeReserve(destEnterpriseSlot, actualFeeUsd);
    }

    if (actualGoodsValueUsd > 0)
    {
        new const sourceEnterpriseSlot = Enterprise_FindByDbId(
            sContracts[contractSlot][E_CONTRACT_SOURCE_ENT_DB_ID]);
        if (Enterprise_IsValid(sourceEnterpriseSlot) &&
            Enterprise_GetOwnership(sourceEnterpriseSlot) != ENTERPRISE_OWN_STATE)
        {
            Enterprise_AddReserve(sourceEnterpriseSlot, actualGoodsValueUsd);
        }
        else
        {
            Internal_AddGovernmentBalance(actualGoodsValueUsd);
        }
        Enterprise_TakeReserve(destEnterpriseSlot, actualGoodsValueUsd);
    }

    sContracts[contractSlot][E_CONTRACT_AMOUNT] -= movedAmount;
    sContracts[contractSlot][E_CONTRACT_TOTAL_WEIGHT_G] -= actualWeightG;
    if (sContracts[contractSlot][E_CONTRACT_TOTAL_WEIGHT_G] < 0)
    {
        sContracts[contractSlot][E_CONTRACT_TOTAL_WEIGHT_G] = 0;
    }

    new itemName[64], destName[64], msg[224];
    Item_GetName(itemDefId, itemName);
    Enterprise_GetName(destEnterpriseSlot, destName);
    format(msg, sizeof(msg),
        "[Логистика]: Доставлено в «%s»: %s (количество: %d). Оплата доставки: $%d, стоимость товара: $%d.",
        destName, itemName, movedAmount, actualFeeUsd, actualGoodsValueUsd);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new auditDetails[224];
    format(auditDetails, sizeof(auditDetails),
        "Разгрузка по контракту #%d: %s (кол-во: %d, вес: %d г) в '%s'. Водителю: $%d, товар: $%d.",
        sContracts[contractSlot][E_CONTRACT_DB_ID], itemName, movedAmount, actualWeightG,
        destName, actualFeeUsd, actualGoodsValueUsd);
    Audit_Log(
        Character_GetId(playerid),
        "CONTRACT_UNLOAD",
        "VEHICLE_TRUNK",
        "ENTERPRISE_WAREHOUSE",
        itemDefId,
        movedAmount,
        auditDetails);

    sContractVehicle[contractSlot] = 0;
    Internal_FinishContractProgression(contractSlot);
    return 1;
}

static stock Internal_HijackNearestTruck(playerid)
{
    if (IsPlayerInAnyVehicle(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Для перехвата груза выйдите из автомобиля.");
        return 0;
    }
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);

    new nearestVehicle = 0;
    new Float:bestDistance = LOGISTICS_TRUCK_RADIUS + 0.001;

    for (new vehicleId = 1; vehicleId < MAX_VEHICLES_SERVER; vehicleId++)
    {
        if (!IsValidVehicle(vehicleId))
        {
            continue;
        }

        new Float:vx, Float:vy, Float:vz;
        GetVehiclePos(vehicleId, vx, vy, vz);
        new const Float:distance = Utils_GetDistance3D(px, py, pz, vx, vy, vz);
        if (distance < bestDistance)
        {
            bestDistance = distance;
            nearestVehicle = vehicleId;
        }
    }

    if (nearestVehicle <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Рядом нет грузового автомобиля.");
        return 0;
    }

    new Float:vx, Float:vy, Float:vz;
    GetVehicleVelocity(nearestVehicle, vx, vy, vz);
    new const Float:speed = floatsqroot((vx * vx) + (vy * vy) + (vz * vz)) * 180.0;
    if (speed > 8.0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Фура движется слишком быстро для перехвата.");
        return 0;
    }

    new const trunkSlot = Internal_FindVehicleTrunkSlot(nearestVehicle);
    if (!Storage_IsValidSlot(trunkSlot) || !Storage_AreItemsReady(trunkSlot) ||
        Storage_GetCurrentWeight(trunkSlot) <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: В кузове этой фуры нет груза.");
        return 0;
    }

    new contractSlot = INVALID_CONTRACT_SLOT;
    foreach (new candidateSlot : ContractIter)
    {
        if (!sContracts[candidateSlot][E_CONTRACT_VALID] ||
            sContracts[candidateSlot][E_CONTRACT_STATUS] != CONTRACT_STATUS_IN_TRANSIT)
        {
            continue;
        }
        if (sContractVehicle[candidateSlot] == nearestVehicle)
        {
            contractSlot = candidateSlot;
            break;
        }
    }

    if (contractSlot == INVALID_CONTRACT_SLOT)
    {
        // После перезапуска сервера привязка контракт-транспорт теряется:
        // сопоставляем по типу груза, фактически находящемуся в кузове.
        foreach (new candidateSlot : ContractIter)
        {
            if (!sContracts[candidateSlot][E_CONTRACT_VALID] ||
                sContracts[candidateSlot][E_CONTRACT_STATUS] != CONTRACT_STATUS_IN_TRANSIT)
            {
                continue;
            }
            if (Storage_CountItemInTree(
                    trunkSlot, sContracts[candidateSlot][E_CONTRACT_ITEM_DEF_ID]) > 0)
            {
                contractSlot = candidateSlot;
                break;
            }
        }
    }

    new const bool:hasContract = (contractSlot != INVALID_CONTRACT_SLOT);
    new itemDefId = 0;

    if (hasContract)
    {
        if (sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID] == Character_GetId(playerid))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "[Логистика]: Нельзя перехватить собственный груз. Доставьте его по контракту.");
            return 0;
        }
        itemDefId = sContracts[contractSlot][E_CONTRACT_ITEM_DEF_ID];
    }
    else
    {
        // Бесхозный груз в кузове (например, после перезапуска сервера)
        // также может быть физически выгружен и сбыт на черном рынке.
        new const firstItemSlot = Storage_GetFirstItemSlot(trunkSlot);
        if (firstItemSlot != INVALID_STORAGE_ITEM_SLOT)
        {
            itemDefId = Storage_GetItemDefId(firstItemSlot);
        }
    }

    new const cargoAmount = Storage_CountItemInTree(trunkSlot, itemDefId);
    if (itemDefId <= 0 || cargoAmount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Груз в кузове не найден.");
        return 0;
    }

    if (hasContract)
    {
        sContracts[contractSlot][E_CONTRACT_STATUS] = CONTRACT_STATUS_HIJACKED;
        Internal_UpdateContractDb(contractSlot);
        sContractVehicle[contractSlot] = 0;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    new movedAmount = 0;

    if (Storage_IsValidSlot(layer1Slot))
    {
        new const unitWeightG = Item_CalculateInstanceWeight(itemDefId, 1);
        new const unitVolumeMl = Item_CalculateInstanceVolume(itemDefId, 1);

        new itemSlot = Storage_GetFirstItemSlot(trunkSlot);
        while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
        {
            new const nextItemSlot = Storage_GetNextItemSlot(itemSlot);
            if (Storage_GetItemDefId(itemSlot) == itemDefId)
            {
                new const itemAmount = Storage_GetItemAmount(itemSlot);
                new const freeWeightG = Storage_GetMaxWeight(layer1Slot) - Storage_GetCurrentWeight(layer1Slot);
                new const freeVolumeMl = Storage_GetMaxVolume(layer1Slot) - Storage_GetCurrentVolume(layer1Slot);
                new fitAmount = itemAmount;

                if (unitWeightG > 0 && (freeWeightG / unitWeightG) < fitAmount)
                {
                    fitAmount = freeWeightG / unitWeightG;
                }
                if (unitVolumeMl > 0 && (freeVolumeMl / unitVolumeMl) < fitAmount)
                {
                    fitAmount = freeVolumeMl / unitVolumeMl;
                }
                if (fitAmount <= 0)
                {
                    break;
                }

                if (Storage_TransferItem(
                        playerid,
                        trunkSlot,
                        itemSlot,
                        layer1Slot,
                        fitAmount,
                        Character_GetId(playerid)) == STORAGE_RES_OK)
                {
                    movedAmount += fitAmount;
                }
                else
                {
                    break;
                }
            }
            itemSlot = nextItemSlot;
        }
    }

    new itemName[64], msg[224];
    Item_GetName(itemDefId, itemName);
    if (movedAmount <= 0)
    {
        format(msg, sizeof(msg),
            "[Логистика]: Контракт перехвачен, но груз (%s) не поместился в инвентарь. Часть осталась в кузове.",
            itemName);
    }
    else
    {
        format(msg, sizeof(msg),
            "[Логистика]: Контракт перехвачен! Вы забрали %s (количество: %d).",
            itemName, movedAmount);
    }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new auditDetails[224];
    if (hasContract)
    {
        format(auditDetails, sizeof(auditDetails),
            "Перехват контракта #%d: %s (кол-во: %d) из транспорта #%d.",
            sContracts[contractSlot][E_CONTRACT_DB_ID], itemName, movedAmount, nearestVehicle);
    }
    else
    {
        format(auditDetails, sizeof(auditDetails),
            "Вскрытие бесхозной фуры #%d: %s (кол-во: %d).",
            nearestVehicle, itemName, movedAmount);
    }
    Audit_Log(
        Character_GetId(playerid),
        "CONTRACT_HIJACK",
        "VEHICLE_TRUNK",
        "PLAYER_LAYER1",
        itemDefId,
        movedAmount,
        auditDetails);
    return 1;
}

static stock Internal_SellStolenGoods(playerid)
{
    new const shopEnterpriseSlot = Enterprise_FindNearest(playerid, LOGISTICS_LOAD_RADIUS);
    if (!Enterprise_IsValid(shopEnterpriseSlot) ||
        Enterprise_GetType(shopEnterpriseSlot) != ENTERPRISE_CHOP_SHOP)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Черный рынок]: Подойдите вплотную к авторазборке, чтобы продать товар.");
        return 0;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Черный рынок]: Инвентарь недоступен.");
        return 0;
    }

    new const bool:layer1WasLocked = Storage_IsMutexLocked(layer1Slot);
    if (!Storage_AcquireMutex(layer1Slot, playerid))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Черный рынок]: Инвентарь занят другим действием.");
        return 0;
    }

    new totalValue = 0;
    new totalAmount = 0;
    new itemSlot = Storage_GetFirstItemSlot(layer1Slot);

    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        new const nextItemSlot = Storage_GetNextItemSlot(itemSlot);
        new const itemDefId = Storage_GetItemDefId(itemSlot);

        if (Internal_IsBlackMarketItem(itemDefId))
        {
            new const price = Internal_GetBlackMarketPrice(itemDefId);
            new const itemAmount = Storage_GetItemAmount(itemSlot);
            new availableReserve = Enterprise_GetReserve(shopEnterpriseSlot) - totalValue;

            if (availableReserve > 0 && price > 0)
            {
                new sellAmount = availableReserve / price;
                if (sellAmount > itemAmount)
                {
                    sellAmount = itemAmount;
                }
                if (sellAmount > 0 && Storage_RemoveItem(layer1Slot, itemSlot, sellAmount))
                {
                    totalAmount += sellAmount;
                    totalValue += price * sellAmount;
                }
            }
        }
        itemSlot = nextItemSlot;
    }

    if (!layer1WasLocked)
    {
        Storage_ReleaseMutex(layer1Slot);
    }

    if (totalValue <= 0 || totalAmount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Черный рынок]: Нет товара для сбыта или касса авторазборки пуста.");
        return 0;
    }

    if (!Character_AddPhysicalCashUsd(playerid, totalValue, CASH_FLAG_DIRTY))
    {
        new Float:x, Float:y, Float:z;
        GetPlayerPos(playerid, x, y, z);
        new const dropSlot = Storage_CreateWorldDrop(
            x, y, z,
            GetPlayerInterior(playerid),
            GetPlayerVirtualWorld(playerid),
            ITEM_ID_CASH_BUNDLE);
        if (dropSlot != INVALID_STORAGE_SLOT)
        {
            new remainingCash = totalValue;
            while (remainingCash > 0)
            {
                new const chunk = (remainingCash > 10000) ? 10000 : remainingCash;
                new outItemSlot = INVALID_STORAGE_ITEM_SLOT;
                if (Storage_AddItem(dropSlot, ITEM_ID_CASH_BUNDLE, chunk, 0, 100.0,
                        CASH_FLAG_DIRTY, CURRENCY_USD, "", outItemSlot) != STORAGE_RES_OK)
                {
                    break;
                }
                remainingCash -= chunk;
            }
        }
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Черный рынок]: Грязные деньги не поместились в инвентарь и выданы на земле.");
    }

    Enterprise_TakeReserve(shopEnterpriseSlot, totalValue);

    new msg[192];
    format(msg, sizeof(msg),
        "[Черный рынок]: Вы сбыли %d единиц товара за $%d грязными наличными.",
        totalAmount, totalValue);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new auditDetails[192];
    format(auditDetails, sizeof(auditDetails),
        "Сбыт краденого товара на авторазборке #%d: %d единиц за $%d (грязные деньги).",
        Enterprise_GetDbId(shopEnterpriseSlot), totalAmount, totalValue);
    Audit_Log(
        Character_GetId(playerid),
        "BLACK_MARKET_SALE",
        "PLAYER_LAYER1",
        "ENTERPRISE_RESERVE",
        0,
        totalValue,
        auditDetails);
    return 1;
}

static stock Internal_ReturnCargoToSource(playerid)
{
    new const vehicleId = Internal_GetPlayerDriverVehicle(playerid);
    if (vehicleId <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Вы должны находиться за рулем фуры.");
        return 0;
    }

    new const contractSlot = Internal_GetActiveContractSlot(playerid, true);
    if (contractSlot == INVALID_CONTRACT_SLOT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Нет активного контракта в пути.");
        return 0;
    }

    new const sourceEnterpriseSlot = Enterprise_FindByDbId(
        sContracts[contractSlot][E_CONTRACT_SOURCE_ENT_DB_ID]);
    if (!Enterprise_IsValid(sourceEnterpriseSlot) ||
        !Enterprise_IsPlayerNearWarehouse(playerid, sourceEnterpriseSlot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Логистика]: Вернуть груз можно только на складе предприятия-отправителя.");
        return 0;
    }

    new const warehouseSlot = Enterprise_GetWarehouseSlot(sourceEnterpriseSlot);
    if (!Storage_IsValidSlot(warehouseSlot) || !Storage_AreItemsReady(warehouseSlot))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Логистика]: Склад отправителя еще загружается.");
        return 0;
    }

    new const trunkSlot = Logistics_GetVehicleTrunkSlot(vehicleId);
    if (!Storage_IsValidSlot(trunkSlot) || !Storage_AreItemsReady(trunkSlot) ||
        Storage_GetCurrentWeight(trunkSlot) <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: В кузове нет груза для возврата.");
        return 0;
    }

    new const movedItems = Storage_TransferAllItems(
        trunkSlot,
        warehouseSlot,
        Character_GetId(playerid));

    if (movedItems <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Логистика]: Не удалось вернуть груз на склад (склад переполнен или занят).");
        return 0;
    }

    if (Storage_GetCurrentWeight(trunkSlot) <= 0)
    {
        sContracts[contractSlot][E_CONTRACT_STATUS] = CONTRACT_STATUS_OPEN;
        sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID] = 0;
        sContractVehicle[contractSlot] = 0;
        Internal_UpdateContractDb(contractSlot);
        SendClientMessage(playerid, COLOR_UI_SUCCESS,
            "[Логистика]: Груз возвращен на склад отправителя. Контракт снова свободен.");
    }
    else
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Логистика]: Часть груза возвращена, остаток остается в кузове.");
    }

    new auditDetails[192];
    format(auditDetails, sizeof(auditDetails),
        "Возврат груза по контракту #%d на склад отправителя (позиций: %d).",
        sContracts[contractSlot][E_CONTRACT_DB_ID], movedItems);
    Audit_Log(
        Character_GetId(playerid),
        "CONTRACT_RETURN",
        "VEHICLE_TRUNK",
        "ENTERPRISE_WAREHOUSE",
        0,
        movedItems,
        auditDetails);
    return 1;
}

static stock Internal_CancelContract(playerid)
{
    new const contractSlot = Internal_GetActiveContractSlot(playerid, false);
    if (contractSlot == INVALID_CONTRACT_SLOT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: У вас нет закрепленного контракта.");
        return 0;
    }
    if (sContracts[contractSlot][E_CONTRACT_STATUS] == CONTRACT_STATUS_IN_TRANSIT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Логистика]: Нельзя отказаться от контракта с грузом в кузове. Сначала разгрузите его.");
        return 0;
    }

    sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID] = 0;
    Internal_UpdateContractDb(contractSlot);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "[Логистика]: Контракт освобожден.");
    return 1;
}

// =============================================================================
//  8. ЕЖЕМИНУТНАЯ АВТОГЕНЕРАЦИЯ КОНТРАКТОВ (вызывается из Tick_Minute)
// =============================================================================

static stock Internal_AbortOpenContract(contract_slot)
{
    if (contract_slot < 0 || contract_slot >= MAX_LOGISTICS_CONTRACTS ||
        !sContracts[contract_slot][E_CONTRACT_VALID])
    {
        return 0;
    }
    if (sContracts[contract_slot][E_CONTRACT_STATUS] != CONTRACT_STATUS_OPEN)
    {
        return 0;
    }

    if (DB_IsConnected())
    {
        new query[128];
        mysql_format(gMySQL, query, sizeof(query),
            "DELETE FROM `logistics_contracts` WHERE `id` = %d AND `status` = 'OPEN';",
            sContracts[contract_slot][E_CONTRACT_DB_ID]);
        mysql_tquery(gMySQL, query);
    }

    Internal_ResetContract(contract_slot);
    Iter_Remove(ContractIter, contract_slot);
    return 1;
}

static stock Internal_CleanupStaleContracts()
{
    new staleContracts[64];
    new staleCount = 0;

    foreach (new contractSlot : ContractIter)
    {
        if (!sContracts[contractSlot][E_CONTRACT_VALID] ||
            sContracts[contractSlot][E_CONTRACT_STATUS] != CONTRACT_STATUS_OPEN)
        {
            continue;
        }
        if (staleCount >= 64)
        {
            break;
        }

        new bool:isStale = false;
        if (sContracts[contractSlot][E_CONTRACT_DEST_TYPE] == LOGISTICS_DEST_PORT)
        {
            if (Ports_GetSellPrice(
                    sContracts[contractSlot][E_CONTRACT_DEST_ID],
                    sContracts[contractSlot][E_CONTRACT_ITEM_DEF_ID]) <= 0)
            {
                isStale = true;
            }
        }
        else
        {
            new const destEnterpriseSlot = Enterprise_FindByDbId(
                sContracts[contractSlot][E_CONTRACT_DEST_ID]);
            if (!Enterprise_IsValid(destEnterpriseSlot))
            {
                isStale = true;
            }
            else if (Enterprise_GetDbId(destEnterpriseSlot) !=
                     sContracts[contractSlot][E_CONTRACT_SOURCE_ENT_DB_ID] &&
                     Economy_GetBuyRawPrice(
                         destEnterpriseSlot,
                         sContracts[contractSlot][E_CONTRACT_ITEM_DEF_ID]) <= 0)
            {
                isStale = true;
            }
        }

        if (isStale)
        {
            staleContracts[staleCount++] = contractSlot;
        }
    }

    for (new i = 0; i < staleCount; i++)
    {
        Internal_AbortOpenContract(staleContracts[i]);
    }
    return staleCount;
}

stock Logistics_TickMinute()
{
    Internal_CleanupStaleContracts();

    if (Main_IsServerShuttingDown())
    {
        return 0;
    }

    if (Iter_Count(ContractIter) >= (MAX_LOGISTICS_CONTRACTS - 16))
    {
        return 0;
    }

    new createdContracts = 0;

    foreach (new enterpriseId : EnterpriseIter)
    {
        if (createdContracts >= LOGISTICS_AUTO_CONTRACTS_PER_TICK)
        {
            break;
        }
        if (!Enterprise_IsValid(enterpriseId))
        {
            continue;
        }

        new const E_ENTERPRISE_TYPE:enterpriseType = Enterprise_GetType(enterpriseId);
        new const bool:isPrimary = (
            enterpriseType == ENTERPRISE_MINE_ORE ||
            enterpriseType == ENTERPRISE_OIL_RIG ||
            enterpriseType == ENTERPRISE_SAWMILL ||
            enterpriseType == ENTERPRISE_FARM);
        new const bool:isIndustrial = (
            enterpriseType == ENTERPRISE_REFINERY ||
            enterpriseType == ENTERPRISE_METALLURGY ||
            enterpriseType == ENTERPRISE_FACTORY);

        if (!isPrimary && !isIndustrial)
        {
            continue;
        }

        // Автоматические контракты формируются только для государственных
        // предприятий. Частный владелец создает контракты самостоятельно.
        if (Enterprise_GetOwnership(enterpriseId) != ENTERPRISE_OWN_STATE)
        {
            continue;
        }

        new const sourceDbId = Enterprise_GetDbId(enterpriseId);
        if (Internal_CountOpenContractsForSource(sourceDbId) >= LOGISTICS_MAX_OPEN_PER_SOURCE)
        {
            continue;
        }

        new const warehouseSlot = Enterprise_GetWarehouseSlot(enterpriseId);
        if (!Storage_IsValidSlot(warehouseSlot) || !Storage_AreItemsReady(warehouseSlot))
        {
            continue;
        }

        new itemDefId = 0;
        new stockAmount = 0;
        new destType = 0;
        new destId = 0;

        if (isPrimary)
        {
            switch (enterpriseType)
            {
                case ENTERPRISE_MINE_ORE: itemDefId = 77;
                case ENTERPRISE_OIL_RIG:  itemDefId = 76;
                case ENTERPRISE_SAWMILL:  itemDefId = 78;
                case ENTERPRISE_FARM:     itemDefId = 80;
            }
            if (itemDefId <= 0 || Internal_ContractAlreadyExists(sourceDbId, itemDefId))
            {
                continue;
            }

            stockAmount = Storage_CountItemInTree(warehouseSlot, itemDefId);
            if (stockAmount < 200)
            {
                continue;
            }

            new const destEnterpriseSlot = Economy_FindBuyRawOrderForItem(itemDefId, enterpriseId);
            if (Enterprise_IsValid(destEnterpriseSlot))
            {
                // Защита государственных и частных шахт от закупок по демпинговой цене:
                // автоматический контракт принимает ордер не ниже 60% лучшей портовой цены.
                new const orderPrice = Economy_GetBuyRawPrice(destEnterpriseSlot, itemDefId);
                new const portFloorPrice = (Ports_GetBestSellPrice(itemDefId) * 60) / 100;
                new const plannedAmount = (stockAmount > LOGISTICS_AUTO_CONTRACT_AMOUNT) ? LOGISTICS_AUTO_CONTRACT_AMOUNT : stockAmount;
                new const requiredBuyerReserve = plannedAmount * (orderPrice + LOGISTICS_RATE_PER_KG_USD);
                if (orderPrice > 0 &&
                    orderPrice >= portFloorPrice &&
                    requiredBuyerReserve > 0 &&
                    Enterprise_GetReserve(destEnterpriseSlot) >= requiredBuyerReserve)
                {
                    destType = LOGISTICS_DEST_ENTERPRISE;
                    destId = Enterprise_GetDbId(destEnterpriseSlot);
                }
                else
                {
                    new const bestPort = Ports_FindBestExportPort(itemDefId);
                    if (bestPort > 0)
                    {
                        destType = LOGISTICS_DEST_PORT;
                        destId = bestPort;
                    }
                }
            }
            else
            {
                new const bestPort = Ports_FindBestExportPort(itemDefId);
                if (bestPort > 0)
                {
                    destType = LOGISTICS_DEST_PORT;
                    destId = bestPort;
                }
            }
        }
        else
        {
            // Промышленные предприятия экспортируют готовую продукцию в порты.
            for (new defId = 1; defId < MAX_ITEM_DEFS; defId++)
            {
                if (!Item_IsValid(defId) || Internal_ContractAlreadyExists(sourceDbId, defId))
                {
                    continue;
                }

                new const currentStock = Storage_CountItemInTree(warehouseSlot, defId);
                if (currentStock < 200)
                {
                    continue;
                }

                new const bestPort = Ports_FindBestExportPort(defId);
                if (bestPort <= 0)
                {
                    continue;
                }

                itemDefId = defId;
                stockAmount = currentStock;
                destType = LOGISTICS_DEST_PORT;
                destId = bestPort;
                break;
            }
            if (itemDefId <= 0)
            {
                continue;
            }
        }

        new amount = (stockAmount > LOGISTICS_AUTO_CONTRACT_AMOUNT) ? LOGISTICS_AUTO_CONTRACT_AMOUNT : stockAmount;
        if (destType == 0 || destId <= 0 || amount <= 0)
        {
            continue;
        }

        if (Logistics_CreateContract(sourceDbId, destType, destId, itemDefId, amount, 0))
        {
            createdContracts++;
        }
    }

    return createdContracts;
}

// =============================================================================
//  9. КОМАНДЫ БИРЖИ ЛОГИСТИКИ (Pawn.CMD)
// =============================================================================

CMD:contracts(playerid, params[])
{
    #pragma unused params

    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Ваш персонаж еще не загружен.");
        return 1;
    }
    if (!Character_IsAlive(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Мертвый персонаж не может работать с грузом.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sLastLogisticsCommandTick[playerid]) < LOGISTICS_COMMAND_COOLDOWN_MS)
    {
        return 1;
    }
    sLastLogisticsCommandTick[playerid] = nowTick;

    sLogisticsDialogBuffer[0] = '\0';
    sContractDialogRowCount[playerid] = 0;

    foreach (new contractSlot : ContractIter)
    {
        if (!sContracts[contractSlot][E_CONTRACT_VALID] ||
            sContracts[contractSlot][E_CONTRACT_STATUS] != CONTRACT_STATUS_OPEN)
        {
            continue;
        }
        if (sContractDialogRowCount[playerid] >= MAX_LOGISTICS_DIALOG_ROWS)
        {
            break;
        }

        new sourceName[64], destName[64], itemName[64], rowLine[224];
        new const sourceEnterpriseSlot = Enterprise_FindByDbId(
            sContracts[contractSlot][E_CONTRACT_SOURCE_ENT_DB_ID]);
        if (Enterprise_IsValid(sourceEnterpriseSlot))
        {
            Enterprise_GetName(sourceEnterpriseSlot, sourceName);
        }
        else
        {
            format(sourceName, sizeof(sourceName), "Предприятие #%d",
                sContracts[contractSlot][E_CONTRACT_SOURCE_ENT_DB_ID]);
        }

        Internal_GetDestinationName(contractSlot, destName, sizeof(destName));
        Item_GetName(sContracts[contractSlot][E_CONTRACT_ITEM_DEF_ID], itemName);

        format(rowLine, sizeof(rowLine),
            "#%d | %s -> %s | %s | количество: %d | вес: %d кг | %s",
            sContracts[contractSlot][E_CONTRACT_DB_ID],
            sourceName,
            destName,
            itemName,
            sContracts[contractSlot][E_CONTRACT_AMOUNT],
            sContracts[contractSlot][E_CONTRACT_TOTAL_WEIGHT_G] / 1000,
            (sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID] > 0) ? ("закреплен") : ("свободен"));

        strcat(sLogisticsDialogBuffer, rowLine, sizeof(sLogisticsDialogBuffer));
        strcat(sLogisticsDialogBuffer, "\n", sizeof(sLogisticsDialogBuffer));
        sContractDialogRowMap[playerid][sContractDialogRowCount[playerid]++] = contractSlot;
    }

    if (sContractDialogRowCount[playerid] <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Логистика]: Свободных контрактов нет. Они появляются автоматически по мере накопления сырья.");
        return 1;
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_LOGISTICS_CONTRACTS,
        DIALOG_STYLE_LIST,
        "Биржа грузоперевозок",
        sLogisticsDialogBuffer,
        "Взять контракт",
        "Закрыть");
    return 1;
}
alias:contracts("contract");

CMD:cargo(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Ваш персонаж еще не загружен.");
        return 1;
    }
    if (!Character_IsAlive(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Мертвый персонаж не может работать с грузом.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sLastLogisticsCommandTick[playerid]) < LOGISTICS_COMMAND_COOLDOWN_MS)
    {
        return 1;
    }
    sLastLogisticsCommandTick[playerid] = nowTick;

    if (params[0] == '\0')
    {
        SendClientMessage(playerid, COLOR_UI_INFO,
            "[Логистика]: Команды: /cargo load (погрузка), unload (разгрузка), return (возврат), hijack (перехват), sell (сбыт), cancel (отмена).");
        return 1;
    }

    if (!strcmp(params, "load", true))
    {
        Internal_LoadCargo(playerid);
    }
    else if (!strcmp(params, "unload", true))
    {
        new const contractSlot = Internal_GetActiveContractSlot(playerid, true);
        if (contractSlot == INVALID_CONTRACT_SLOT)
        {
            SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Нет активного контракта в пути.");
            return 1;
        }

        if (sContracts[contractSlot][E_CONTRACT_DEST_TYPE] == LOGISTICS_DEST_PORT)
        {
            Logistics_UnloadAtPort(playerid, sContracts[contractSlot][E_CONTRACT_DEST_ID]);
        }
        else
        {
            Internal_UnloadCargoAtEnterprise(playerid);
        }
    }
    else if (!strcmp(params, "return", true))
    {
        Internal_ReturnCargoToSource(playerid);
    }
    else if (!strcmp(params, "hijack", true))
    {
        Internal_HijackNearestTruck(playerid);
    }
    else if (!strcmp(params, "sell", true))
    {
        Internal_SellStolenGoods(playerid);
    }
    else if (!strcmp(params, "cancel", true))
    {
        Internal_CancelContract(playerid);
    }
    else
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Логистика]: Неизвестное действие. Доступно: load — погрузка, unload — разгрузка, return — возврат, hijack — перехват, sell — сбыт, cancel — отмена.");
    }
    return 1;
}

// =============================================================================
// 10. ОБРАБОТКА ДИАЛОГОВ ЛОГИСТИКИ
// =============================================================================

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid != DIALOG_LOGISTICS_CONTRACTS)
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
    if (!Character_IsLoaded(playerid))
    {
        return Y_HOOKS_BREAK_RETURN_1;
    }
    if (listitem < 0 || listitem >= sContractDialogRowCount[playerid] ||
        listitem >= MAX_LOGISTICS_DIALOG_ROWS)
    {
        return Y_HOOKS_BREAK_RETURN_1;
    }

    new const contractSlot = sContractDialogRowMap[playerid][listitem];
    if (contractSlot < 0 || contractSlot >= MAX_LOGISTICS_CONTRACTS ||
        !sContracts[contractSlot][E_CONTRACT_VALID] ||
        sContracts[contractSlot][E_CONTRACT_STATUS] != CONTRACT_STATUS_OPEN)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Контракт больше недоступен.");
        return Y_HOOKS_BREAK_RETURN_1;
    }

    new const charId = Character_GetId(playerid);
    if (sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID] != 0 &&
        sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID] != charId)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Логистика]: Этот контракт уже закреплен за другим водителем.");
        return Y_HOOKS_BREAK_RETURN_1;
    }

    foreach (new otherSlot : ContractIter)
    {
        if (otherSlot == contractSlot || !sContracts[otherSlot][E_CONTRACT_VALID])
        {
            continue;
        }
        if (sContracts[otherSlot][E_CONTRACT_TRUCKER_CHAR_ID] == charId &&
            (sContracts[otherSlot][E_CONTRACT_STATUS] == CONTRACT_STATUS_OPEN ||
             sContracts[otherSlot][E_CONTRACT_STATUS] == CONTRACT_STATUS_IN_TRANSIT))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "[Логистика]: У вас уже есть активный контракт. Сначала завершите или отмените его.");
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }

    sContracts[contractSlot][E_CONTRACT_TRUCKER_CHAR_ID] = charId;
    Internal_UpdateContractDb(contractSlot);

    new itemName[64], msg[192];
    Item_GetName(sContracts[contractSlot][E_CONTRACT_ITEM_DEF_ID], itemName);
    format(msg, sizeof(msg),
        "[Логистика]: Контракт #%d закреплен за вами. Груз: %s (количество: %d).",
        sContracts[contractSlot][E_CONTRACT_DB_ID], itemName, sContracts[contractSlot][E_CONTRACT_AMOUNT]);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    SendClientMessage(playerid, COLOR_UI_INFO,
        "[Логистика]: Подгоните фуру к складу отправителя и введите /cargo load.");
    return Y_HOOKS_BREAK_RETURN_1;
}

// =============================================================================
// 11. СИСТЕМНЫЕ ХУКИ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    new const loadedContracts = Internal_LoadContractsSync();
    new const loadedTrunks = Internal_LoadExistingTrunksSync();

    for (new i = 0; i < MAX_LOGISTICS_CONTRACTS; i++)
    {
        sContractVehicle[i] = 0;
    }
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        sContractDialogRowCount[i] = 0;
        sLastLogisticsCommandTick[i] = 0;
    }

    printf("%s [Systems/Logistics] Модуль логистики запущен (контрактов: %d, багажников: %d).",
        SERVER_LOG_PREFIX, loadedContracts, loadedTrunks);
    return 1;
}

hook OnVehicleDeath(vehicleid, killerid)
{
    #pragma unused killerid

    if (vehicleid <= 0 || vehicleid >= MAX_VEHICLES_SERVER)
    {
        return 1;
    }
    if (Main_IsServerShuttingDown())
    {
        return 1;
    }

    new const trunkSlot = Internal_FindVehicleTrunkSlot(vehicleid);
    if (!Storage_IsValidSlot(trunkSlot) || !Storage_AreItemsReady(trunkSlot) ||
        Storage_GetCurrentWeight(trunkSlot) <= 0)
    {
        return 1;
    }

    // Контракт, привязанный к уничтоженной фуре, больше не может быть выполнен.
    new contractsToRemove[MAX_LOGISTICS_CONTRACTS];
    new removeCount = 0;
    new linkedContractSlot = INVALID_CONTRACT_SLOT;
    new sourceWarehouseSlot = INVALID_STORAGE_SLOT;

    // Восстановление связи контракта с фурой после перезапуска сервера:
    // ищем контракт в пути по типу груза, фактически находящемуся в кузове.
    new const probeItemSlot = Storage_GetFirstItemSlot(trunkSlot);
    new probeItemDefId = 0;
    if (probeItemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        probeItemDefId = Storage_GetItemDefId(probeItemSlot);
    }

    new bool:cargoMatchAssigned = false;
    foreach (new contractSlot : ContractIter)
    {
        if (!sContracts[contractSlot][E_CONTRACT_VALID] ||
            sContracts[contractSlot][E_CONTRACT_STATUS] != CONTRACT_STATUS_IN_TRANSIT)
        {
            continue;
        }

        new const bool:linkedByVehicle = (sContractVehicle[contractSlot] == vehicleid);
        new const bool:linkedByCargo = (
            !cargoMatchAssigned &&
            probeItemDefId > 0 &&
            sContracts[contractSlot][E_CONTRACT_ITEM_DEF_ID] == probeItemDefId);

        if (!linkedByVehicle && !linkedByCargo)
        {
            continue;
        }
        if (linkedByCargo)
        {
            cargoMatchAssigned = true;
        }

        if (linkedContractSlot == INVALID_CONTRACT_SLOT)
        {
            linkedContractSlot = contractSlot;
        }
        sContracts[contractSlot][E_CONTRACT_STATUS] = CONTRACT_STATUS_HIJACKED;
        Internal_UpdateContractDb(contractSlot);
        if (removeCount < MAX_LOGISTICS_CONTRACTS)
        {
            contractsToRemove[removeCount++] = contractSlot;
        }
    }

    if (linkedContractSlot != INVALID_CONTRACT_SLOT)
    {
        new const sourceEnterpriseSlot = Enterprise_FindByDbId(
            sContracts[linkedContractSlot][E_CONTRACT_SOURCE_ENT_DB_ID]);
        if (Enterprise_IsValid(sourceEnterpriseSlot))
        {
            new const warehouseSlot = Enterprise_GetWarehouseSlot(sourceEnterpriseSlot);
            if (Storage_IsValidSlot(warehouseSlot) && Storage_AreItemsReady(warehouseSlot))
            {
                sourceWarehouseSlot = warehouseSlot;
            }
        }
    }

    new returnedItems = 0;
    if (sourceWarehouseSlot != INVALID_STORAGE_SLOT)
    {
        returnedItems = Storage_TransferAllItems(trunkSlot, sourceWarehouseSlot, 0);
    }

    for (new i = 0; i < removeCount; i++)
    {
        Internal_ResetContract(contractsToRemove[i]);
        Iter_Remove(ContractIter, contractsToRemove[i]);
    }

    new Float:x, Float:y, Float:z;
    GetVehiclePos(vehicleid, x, y, z);

    new droppedItems = 0;
    if (Storage_GetCurrentWeight(trunkSlot) > 0)
    {
        for (new dropIndex = 0; dropIndex < 10; dropIndex++)
        {
            if (Storage_GetCurrentWeight(trunkSlot) <= 0)
            {
                break;
            }

            new const dropSlot = Storage_CreateWorldDrop(
                x, y, z,
                0,
                GetVehicleVirtualWorld(vehicleid),
                0);
            if (dropSlot == INVALID_STORAGE_SLOT)
            {
                break;
            }

            new const movedItems = Storage_TransferAllItems(trunkSlot, dropSlot, 0);
            droppedItems += movedItems;
            if (movedItems <= 0)
            {
                break;
            }
        }
    }

    if (returnedItems > 0)
    {
        printf("%s [Systems/Logistics] Груз уничтоженного транспорта #%d (%d позиций) возвращен на склад отправителя.",
            SERVER_LOG_PREFIX, vehicleid, returnedItems);
        Audit_Log(
            0,
            "VEHICLE_CARGO_RETURN",
            "VEHICLE_TRUNK",
            "ENTERPRISE_WAREHOUSE",
            0,
            returnedItems,
            "Груз уничтоженного транспорта возвращен на склад предприятия-отправителя");
    }

    if (droppedItems > 0)
    {
        printf("%s [Systems/Logistics] Остаток груза уничтоженного транспорта #%d (%d позиций) выброшен на землю.",
            SERVER_LOG_PREFIX, vehicleid, droppedItems);
        Audit_Log(
            0,
            "VEHICLE_CARGO_DROP",
            "VEHICLE_TRUNK",
            "WORLD_DROP",
            0,
            droppedItems,
            "Остаток груза уничтоженного транспорта перенесен в WORLD_DROP");
    }
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason

    sContractDialogRowCount[playerid] = 0;
    sLastLogisticsCommandTick[playerid] = 0;
    return 1;
}

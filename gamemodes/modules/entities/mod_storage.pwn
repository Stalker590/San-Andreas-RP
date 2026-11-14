forward OnStorageLostEquippedClothing(src_slot, item_slot, dst_slot);
/*
 * =============================================================================
 *  SAN ANDREAS RP — Универсальное полиморфное хранилище, мьютексы и мировые дропы
 *  Файл:      gamemodes/modules/entities/mod_storage.pwn
 *  Пункты:    ROADMAP [2.2, 2.3, 2.4] — Ядро хранилищ, рекурсивный вес, WORLD_DROP
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_storage_included
    #endinput
#endif
#define _mod_storage_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ, КОДЫ РЕЗУЛЬТАТОВ И ПАРАМЕТРЫ ПУЛОВ ХРАНИЛИЩ
// =============================================================================

#define STORAGE_ITEM_META_STR_LEN               (32)
#define STORAGE_SQL_TX_BUFFER_LEN               (2048)

#define DEFAULT_WORLD_DROP_MAX_WEIGHT_G         (200000)
#define DEFAULT_WORLD_DROP_MAX_VOLUME_ML        (250000)
#define DEFAULT_CORPSE_MAX_WEIGHT_G             (150000)
#define DEFAULT_CORPSE_MAX_VOLUME_ML            (180000)
#define CORPSE_WORLD_OBJECT_MODEL               (2907)

// Коды возврата операций перемещения и модификации хранилищ
enum E_STORAGE_RESULT
{
    STORAGE_RES_OK = 0,
    STORAGE_RES_INVALID_SLOT,
    STORAGE_RES_INVALID_ITEM,
    STORAGE_RES_TOO_FAR,
    STORAGE_RES_MUTEX_BUSY,
    STORAGE_RES_LOCKED,
    STORAGE_RES_LAYER2_FORBIDDEN,
    STORAGE_RES_NESTING_LIMIT,
    STORAGE_RES_WEIGHT_EXCEEDED,
    STORAGE_RES_VOLUME_EXCEEDED,
    STORAGE_RES_POOL_FULL
};

// =============================================================================
//  2. СТРУКТУРЫ ДАННЫХ И ИНКАПСУЛИРОВАННЫЕ ПУЛЫ В RAM (static stock)
// =============================================================================

enum E_STORAGE_DATA
{
    bool:E_STORAGE_VALID,
    E_STORAGE_DB_ID,
    E_STORAGE_TYPE:E_STORAGE_KIND,
    E_STORAGE_OWNER_ID,
    E_STORAGE_MAX_WEIGHT_G,
    E_STORAGE_MAX_VOLUME_ML,
    bool:E_STORAGE_IS_LOCKED,
    E_STORAGE_LOCK_LEVEL,
    Float:E_STORAGE_POS_X,
    Float:E_STORAGE_POS_Y,
    Float:E_STORAGE_POS_Z,
    E_STORAGE_INTERIOR,
    E_STORAGE_VW,
    E_STORAGE_EXPIRES_AT,
    E_STORAGE_FIRST_ITEM_SLOT,
    E_STORAGE_PARENT_SLOT,
    E_STORAGE_ACTIVE_VIEWER,
    STREAMER_TAG_OBJECT:E_STORAGE_OBJECT_ID,
    STREAMER_TAG_3D_TEXT_LABEL:E_STORAGE_LABEL_ID,
    STREAMER_TAG_AREA:E_STORAGE_AREA_ID,
    bool:E_STORAGE_IS_DIRTY
};

enum E_STORAGE_ITEM_DATA
{
    bool:E_SITEM_VALID,
    E_SITEM_DB_ID,
    E_SITEM_STORAGE_SLOT,
    E_SITEM_NEXT_IN_STORAGE,
    E_SITEM_DEF_ID,
    E_SITEM_AMOUNT,
    Float:E_SITEM_DURABILITY,
    E_SITEM_AMMO_COUNT,
    E_SITEM_NESTED_STORAGE_DB_ID,
    E_SITEM_NESTED_STORAGE_SLOT,
    E_SITEM_META_INT1,
    E_SITEM_META_INT2,
    E_SITEM_META_STR[STORAGE_ITEM_META_STR_LEN]
};

static stock sStorages[MAX_ACTIVE_STORAGES][E_STORAGE_DATA];
static stock sStorageItems[MAX_STORAGE_ITEMS][E_STORAGE_ITEM_DATA];

// Глобальные итераторы активных хранилищ и экземпляров предметов (O(1))
new Iterator:StorageIter<MAX_ACTIVE_STORAGES>;
new Iterator:StorageItemIter<MAX_STORAGE_ITEMS>;

// Мьютексы транзакций для защиты от дюпа при конкурентном доступе
static stock bool:sStorageMutex[MAX_ACTIVE_STORAGES];
static stock sStorageMutexOwner[MAX_ACTIVE_STORAGES];
static stock sStorageMutexTick[MAX_ACTIVE_STORAGES];

// Флаги асинхронной загрузки содержимого хранилищ из MySQL
static stock bool:sStorageItemsLoadStarted[MAX_ACTIVE_STORAGES];
static stock bool:sStorageItemsReady[MAX_ACTIVE_STORAGES];

// Временный буфер для формирования атомарных SQL-пакетов
static stock sStorageSqlTxBuffer[STORAGE_SQL_TX_BUFFER_LEN];
static stock sSyntheticStorageDbIdSeq = 100000;
static stock sSyntheticItemDbIdSeq = 500000;

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ СПИСКОВ И СТРИМЕРА (static stock)
// =============================================================================

static stock Internal_ResetStorageSlot(slot_id)
{
    sStorages[slot_id][E_STORAGE_VALID] = false;
    sStorages[slot_id][E_STORAGE_DB_ID] = 0;
    sStorages[slot_id][E_STORAGE_KIND] = STORAGE_NONE;
    sStorages[slot_id][E_STORAGE_OWNER_ID] = 0;
    sStorages[slot_id][E_STORAGE_MAX_WEIGHT_G] = 0;
    sStorages[slot_id][E_STORAGE_MAX_VOLUME_ML] = 0;
    sStorages[slot_id][E_STORAGE_IS_LOCKED] = false;
    sStorages[slot_id][E_STORAGE_LOCK_LEVEL] = 0;
    sStorages[slot_id][E_STORAGE_POS_X] = 0.0;
    sStorages[slot_id][E_STORAGE_POS_Y] = 0.0;
    sStorages[slot_id][E_STORAGE_POS_Z] = 0.0;
    sStorages[slot_id][E_STORAGE_INTERIOR] = 0;
    sStorages[slot_id][E_STORAGE_VW] = 0;
    sStorages[slot_id][E_STORAGE_EXPIRES_AT] = 0;
    sStorages[slot_id][E_STORAGE_FIRST_ITEM_SLOT] = INVALID_STORAGE_ITEM_SLOT;
    sStorages[slot_id][E_STORAGE_PARENT_SLOT] = INVALID_STORAGE_SLOT;
    sStorages[slot_id][E_STORAGE_ACTIVE_VIEWER] = INVALID_PLAYER_ID;
    sStorages[slot_id][E_STORAGE_OBJECT_ID] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
    sStorages[slot_id][E_STORAGE_LABEL_ID] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
    sStorages[slot_id][E_STORAGE_AREA_ID] = STREAMER_TAG_AREA:INVALID_STREAMER_ID;
    sStorages[slot_id][E_STORAGE_IS_DIRTY] = false;

    sStorageMutex[slot_id] = false;
    sStorageMutexOwner[slot_id] = INVALID_PLAYER_ID;
    sStorageMutexTick[slot_id] = 0;

    sStorageItemsLoadStarted[slot_id] = false;
    sStorageItemsReady[slot_id] = false;
}

static stock Internal_ResetStorageItemSlot(item_slot)
{
    sStorageItems[item_slot][E_SITEM_VALID] = false;
    sStorageItems[item_slot][E_SITEM_DB_ID] = 0;
    sStorageItems[item_slot][E_SITEM_STORAGE_SLOT] = INVALID_STORAGE_SLOT;
    sStorageItems[item_slot][E_SITEM_NEXT_IN_STORAGE] = INVALID_STORAGE_ITEM_SLOT;
    sStorageItems[item_slot][E_SITEM_DEF_ID] = 0;
    sStorageItems[item_slot][E_SITEM_AMOUNT] = 0;
    sStorageItems[item_slot][E_SITEM_DURABILITY] = 100.0;
    sStorageItems[item_slot][E_SITEM_AMMO_COUNT] = 0;
    sStorageItems[item_slot][E_SITEM_NESTED_STORAGE_DB_ID] = 0;
    sStorageItems[item_slot][E_SITEM_NESTED_STORAGE_SLOT] = INVALID_STORAGE_SLOT;
    sStorageItems[item_slot][E_SITEM_META_INT1] = 0;
    sStorageItems[item_slot][E_SITEM_META_INT2] = 0;
    sStorageItems[item_slot][E_SITEM_META_STR][0] = '\0';
}

static stock Internal_LinkItemToStorageList(storage_slot, item_slot)
{
    sStorageItems[item_slot][E_SITEM_STORAGE_SLOT] = storage_slot;
    sStorageItems[item_slot][E_SITEM_NEXT_IN_STORAGE] = sStorages[storage_slot][E_STORAGE_FIRST_ITEM_SLOT];
    sStorages[storage_slot][E_STORAGE_FIRST_ITEM_SLOT] = item_slot;

    new const nestedSlot = sStorageItems[item_slot][E_SITEM_NESTED_STORAGE_SLOT];
    if (nestedSlot >= 0 && nestedSlot < MAX_ACTIVE_STORAGES && sStorages[nestedSlot][E_STORAGE_VALID])
    {
        sStorages[nestedSlot][E_STORAGE_PARENT_SLOT] = storage_slot;
    }
}

static stock Internal_UnlinkItemFromStorageList(storage_slot, item_slot)
{
    new prevSlot = INVALID_STORAGE_ITEM_SLOT;
    new currSlot = sStorages[storage_slot][E_STORAGE_FIRST_ITEM_SLOT];

    while (currSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        if (currSlot == item_slot)
        {
            if (prevSlot == INVALID_STORAGE_ITEM_SLOT)
            {
                sStorages[storage_slot][E_STORAGE_FIRST_ITEM_SLOT] = sStorageItems[currSlot][E_SITEM_NEXT_IN_STORAGE];
            }
            else
            {
                sStorageItems[prevSlot][E_SITEM_NEXT_IN_STORAGE] = sStorageItems[currSlot][E_SITEM_NEXT_IN_STORAGE];
            }
            sStorageItems[currSlot][E_SITEM_NEXT_IN_STORAGE] = INVALID_STORAGE_ITEM_SLOT;
            sStorageItems[currSlot][E_SITEM_STORAGE_SLOT] = INVALID_STORAGE_SLOT;
            return 1;
        }
        prevSlot = currSlot;
        currSlot = sStorageItems[currSlot][E_SITEM_NEXT_IN_STORAGE];
    }
    return 0;
}

static stock Internal_DestroyStorageStreamerEntities(slot_id)
{
    if (sStorages[slot_id][E_STORAGE_OBJECT_ID] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
    {
        if (IsValidDynamicObject(sStorages[slot_id][E_STORAGE_OBJECT_ID]))
        {
            DestroyDynamicObject(sStorages[slot_id][E_STORAGE_OBJECT_ID]);
        }
        sStorages[slot_id][E_STORAGE_OBJECT_ID] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
    }

    if (sStorages[slot_id][E_STORAGE_LABEL_ID] != STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID)
    {
        if (IsValidDynamic3DTextLabel(sStorages[slot_id][E_STORAGE_LABEL_ID]))
        {
            DestroyDynamic3DTextLabel(sStorages[slot_id][E_STORAGE_LABEL_ID]);
        }
        sStorages[slot_id][E_STORAGE_LABEL_ID] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
    }

    if (sStorages[slot_id][E_STORAGE_AREA_ID] != STREAMER_TAG_AREA:INVALID_STREAMER_ID)
    {
        if (IsValidDynamicArea(sStorages[slot_id][E_STORAGE_AREA_ID]))
        {
            DestroyDynamicArea(sStorages[slot_id][E_STORAGE_AREA_ID]);
        }
        sStorages[slot_id][E_STORAGE_AREA_ID] = STREAMER_TAG_AREA:INVALID_STREAMER_ID;
    }
}

static stock Internal_SpawnWorldDropVisuals(slot_id, model_id, const label_text[], label_color)
{
    Internal_DestroyStorageStreamerEntities(slot_id);

    new const Float:x = sStorages[slot_id][E_STORAGE_POS_X];
    new const Float:y = sStorages[slot_id][E_STORAGE_POS_Y];
    new const Float:z = sStorages[slot_id][E_STORAGE_POS_Z];
    new const vw = sStorages[slot_id][E_STORAGE_VW];
    new const interior = sStorages[slot_id][E_STORAGE_INTERIOR];

    sStorages[slot_id][E_STORAGE_OBJECT_ID] = CreateDynamicObject(
        model_id,
        x, y, z - 0.85,
        0.0, 0.0, 0.0,
        vw, interior, -1,
        WORLD_DROP_STREAM_DISTANCE
    );

    sStorages[slot_id][E_STORAGE_LABEL_ID] = CreateDynamic3DTextLabel(
        label_text,
        label_color,
        x, y, z - 0.25,
        WORLD_DROP_LABEL_DISTANCE,
        INVALID_PLAYER_ID,
        INVALID_VEHICLE_ID,
        1,
        vw, interior, -1,
        WORLD_DROP_STREAM_DISTANCE
    );

    sStorages[slot_id][E_STORAGE_AREA_ID] = CreateDynamicSphere(
        x, y, z,
        WORLD_DROP_INTERACT_RADIUS,
        vw, interior, -1
    );

    if (sStorages[slot_id][E_STORAGE_AREA_ID] != STREAMER_TAG_AREA:INVALID_STREAMER_ID)
    {
        Streamer_SetIntData(STREAMER_TYPE_AREA, sStorages[slot_id][E_STORAGE_AREA_ID], E_STREAMER_EXTRA_ID, slot_id);
    }
}

static stock bool:Internal_HasWorldPosition(E_STORAGE_TYPE:type)
{
    switch (type)
    {
        case STORAGE_PROPERTY_STASH,
             STORAGE_ORG_VAULT,
             STORAGE_ENTERPRISE_WAREHOUSE,
             STORAGE_WORLD_DROP,
             STORAGE_CORPSE_LOOT:
        {
            return true;
        }
    }
    return false;
}

static stock bool:Internal_ValidatePlayerStorageDistance(playerid, slot_id)
{
    if (playerid == INVALID_PLAYER_ID)
    {
        return true;
    }
    if (!IsPlayerConnected(playerid))
    {
        return false;
    }

    // Если хранилище является вложенной сумкой — проверяем дистанцию до родительского хранилища
    new rootSlot = slot_id;
    new hops = 0;
    while (sStorages[rootSlot][E_STORAGE_PARENT_SLOT] != INVALID_STORAGE_SLOT && hops < MAX_NESTING_DEPTH)
    {
        rootSlot = sStorages[rootSlot][E_STORAGE_PARENT_SLOT];
        hops++;
    }

    new const E_STORAGE_TYPE:rootType = sStorages[rootSlot][E_STORAGE_KIND];
    if (!Internal_HasWorldPosition(rootType))
    {
        return true;
    }

    if (sStorages[rootSlot][E_STORAGE_POS_X] == 0.0 &&
        sStorages[rootSlot][E_STORAGE_POS_Y] == 0.0 &&
        sStorages[rootSlot][E_STORAGE_POS_Z] == 0.0)
    {
        return true;
    }

    return Utils_IsPlayerNearPoint(
        playerid,
        STORAGE_INTERACT_DISTANCE,
        sStorages[rootSlot][E_STORAGE_POS_X],
        sStorages[rootSlot][E_STORAGE_POS_Y],
        sStorages[rootSlot][E_STORAGE_POS_Z],
        sStorages[rootSlot][E_STORAGE_INTERIOR],
        sStorages[rootSlot][E_STORAGE_VW]
    );
}

static stock bool:Internal_CanStackItems(item_slot_a, def_id, Float:durability, meta_int1, meta_int2, const meta_str[])
{
    if (!Item_IsStackable(def_id))
    {
        return false;
    }
    if (sStorageItems[item_slot_a][E_SITEM_DEF_ID] != def_id)
    {
        return false;
    }
    if (sStorageItems[item_slot_a][E_SITEM_NESTED_STORAGE_SLOT] != INVALID_STORAGE_SLOT)
    {
        return false;
    }
    if (floatabs(sStorageItems[item_slot_a][E_SITEM_DURABILITY] - durability) > 0.01)
    {
        return false;
    }
    if (sStorageItems[item_slot_a][E_SITEM_META_INT1] != meta_int1 ||
        sStorageItems[item_slot_a][E_SITEM_META_INT2] != meta_int2)
    {
        return false;
    }
    if (strcmp(sStorageItems[item_slot_a][E_SITEM_META_STR], meta_str, false) != 0)
    {
        return false;
    }
    return true;
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API ЧАСТИ 1 [2.2]: ПУЛЫ, ЗАГРУЗКА И МЬЮТЕКСЫ (Storage_*)
// =============================================================================

stock bool:Storage_IsValidSlot(slot_id)
{
    if (slot_id < 0 || slot_id >= MAX_ACTIVE_STORAGES)
    {
        return false;
    }
    return sStorages[slot_id][E_STORAGE_VALID];
}

stock bool:Storage_IsValidItemSlot(item_slot)
{
    if (item_slot < 0 || item_slot >= MAX_STORAGE_ITEMS)
    {
        return false;
    }
    return sStorageItems[item_slot][E_SITEM_VALID];
}

stock Storage_FindByDbId(db_storage_id)
{
    if (db_storage_id <= 0)
    {
        return INVALID_STORAGE_SLOT;
    }
    foreach (new slot : StorageIter)
    {
        if (sStorages[slot][E_STORAGE_VALID] && sStorages[slot][E_STORAGE_DB_ID] == db_storage_id)
        {
            return slot;
        }
    }
    return INVALID_STORAGE_SLOT;
}

stock Storage_GetDbId(slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return 0;
    }
    return sStorages[slot_id][E_STORAGE_DB_ID];
}

stock E_STORAGE_TYPE:Storage_GetType(slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return STORAGE_NONE;
    }
    return sStorages[slot_id][E_STORAGE_KIND];
}

stock Storage_GetOwnerId(slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return 0;
    }
    return sStorages[slot_id][E_STORAGE_OWNER_ID];
}

stock Storage_GetMaxWeight(slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return 0;
    }
    return sStorages[slot_id][E_STORAGE_MAX_WEIGHT_G];
}

stock Storage_GetMaxVolume(slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return 0;
    }
    return sStorages[slot_id][E_STORAGE_MAX_VOLUME_ML];
}

stock Storage_SetMaxLimits(slot_id, max_weight_g, max_volume_ml)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return 0;
    }
    sStorages[slot_id][E_STORAGE_MAX_WEIGHT_G] = max_weight_g;
    sStorages[slot_id][E_STORAGE_MAX_VOLUME_ML] = max_volume_ml;
    sStorages[slot_id][E_STORAGE_IS_DIRTY] = true;
    return 1;
}

stock Storage_GetFirstItemSlot(slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return INVALID_STORAGE_ITEM_SLOT;
    }
    return sStorages[slot_id][E_STORAGE_FIRST_ITEM_SLOT];
}

stock Storage_GetNextItemSlot(item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return INVALID_STORAGE_ITEM_SLOT;
    }
    return sStorageItems[item_slot][E_SITEM_NEXT_IN_STORAGE];
}

stock Storage_GetItemDefId(item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }
    return sStorageItems[item_slot][E_SITEM_DEF_ID];
}

stock Storage_GetItemAmount(item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }
    return sStorageItems[item_slot][E_SITEM_AMOUNT];
}

stock Storage_GetItemAmmo(item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }
    return sStorageItems[item_slot][E_SITEM_AMMO_COUNT];
}

stock Float:Storage_GetItemDurability(item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0.0;
    }
    return sStorageItems[item_slot][E_SITEM_DURABILITY];
}

stock Storage_GetItemNestedSlot(item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return INVALID_STORAGE_SLOT;
    }
    return sStorageItems[item_slot][E_SITEM_NESTED_STORAGE_SLOT];
}

stock Storage_GetItemMetaInt1(item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }
    return sStorageItems[item_slot][E_SITEM_META_INT1];
}

stock Storage_GetItemMetaInt2(item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }
    return sStorageItems[item_slot][E_SITEM_META_INT2];
}

stock Storage_GetItemDbId(item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }
    return sStorageItems[item_slot][E_SITEM_DB_ID];
}

stock Storage_GetItemStorageSlot(item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return INVALID_STORAGE_SLOT;
    }
    return sStorageItems[item_slot][E_SITEM_STORAGE_SLOT];
}

stock Storage_FindItemSlotByDbId(db_id)
{
    if (db_id <= 0)
    {
        return INVALID_STORAGE_ITEM_SLOT;
    }

    foreach (new itemSlot : StorageItemIter)
    {
        if (sStorageItems[itemSlot][E_SITEM_VALID] &&
            sStorageItems[itemSlot][E_SITEM_DB_ID] == db_id)
        {
            return itemSlot;
        }
    }
    return INVALID_STORAGE_ITEM_SLOT;
}

stock Storage_GetParentSlot(slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return INVALID_STORAGE_SLOT;
    }
    return sStorages[slot_id][E_STORAGE_PARENT_SLOT];
}

stock bool:Storage_AreItemsReady(slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return false;
    }
    return sStorageItemsReady[slot_id];
}

stock Storage_SetItemMetaInt2(item_slot, value)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }
    sStorageItems[item_slot][E_SITEM_META_INT2] = value;
    if (DB_IsConnected() && sStorageItems[item_slot][E_SITEM_DB_ID] > 0)
    {
        mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
            "UPDATE `storage_items` SET `meta_int2` = %d WHERE `id` = %d;",
            value,
            sStorageItems[item_slot][E_SITEM_DB_ID]);
        mysql_tquery(gMySQL, sStorageSqlTxBuffer);
    }
    return 1;
}

// Атомарное обновление боезапаса и износа ствола (одна SQL-запись на вызов)
stock Storage_UpdateWeaponState(item_slot, ammo_count, Float:durability, bool:persist = false)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }
    if (ammo_count < 0)
    {
        ammo_count = 0;
    }
    if (durability < 0.0)
    {
        durability = 0.0;
    }
    if (durability > 100.0)
    {
        durability = 100.0;
    }

    sStorageItems[item_slot][E_SITEM_AMMO_COUNT] = ammo_count;
    sStorageItems[item_slot][E_SITEM_DURABILITY] = durability;

    if (persist && DB_IsConnected() && sStorageItems[item_slot][E_SITEM_DB_ID] > 0)
    {
        mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
            "UPDATE `storage_items` SET `ammo_count` = %d, `durability` = %.2f WHERE `id` = %d;",
            ammo_count,
            durability,
            sStorageItems[item_slot][E_SITEM_DB_ID]);
        mysql_tquery(gMySQL, sStorageSqlTxBuffer);
    }
    return 1;
}

stock Storage_GetItemMetaStr(item_slot, output[], len = sizeof(output))
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        if (len > 0)
        {
            output[0] = '\0';
        }
        return 0;
    }
    format(output, len, "%s", sStorageItems[item_slot][E_SITEM_META_STR]);
    return 1;
}

// Проверка состояния мьютекса хранилища с автоматическим сбросом по таймауту
stock bool:Storage_IsMutexLocked(slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return false;
    }
    if (!sStorageMutex[slot_id])
    {
        return false;
    }
    if ((GetTickCount() - sStorageMutexTick[slot_id]) > STORAGE_MUTEX_TIMEOUT_MS)
    {
        sStorageMutex[slot_id] = false;
        sStorageMutexOwner[slot_id] = INVALID_PLAYER_ID;
        sStorageMutexTick[slot_id] = 0;
        return false;
    }
    return true;
}

// Захват транзакционного мьютекса хранилища
stock bool:Storage_AcquireMutex(slot_id, playerid = INVALID_PLAYER_ID)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return false;
    }
    if (Storage_IsMutexLocked(slot_id))
    {
        if (playerid != INVALID_PLAYER_ID && sStorageMutexOwner[slot_id] == playerid)
        {
            sStorageMutexTick[slot_id] = GetTickCount();
            return true;
        }
        return false;
    }
    sStorageMutex[slot_id] = true;
    sStorageMutexOwner[slot_id] = playerid;
    sStorageMutexTick[slot_id] = GetTickCount();
    return true;
}

// Освобождение транзакционного мьютекса хранилища
stock Storage_ReleaseMutex(slot_id)
{
    if (slot_id < 0 || slot_id >= MAX_ACTIVE_STORAGES)
    {
        return 0;
    }
    sStorageMutex[slot_id] = false;
    sStorageMutexOwner[slot_id] = INVALID_PLAYER_ID;
    sStorageMutexTick[slot_id] = 0;
    return 1;
}

// Открытие хранилища игроком с блокировкой от одновременного доступа второго игрока (DoD 2.2)
stock bool:Storage_OpenForPlayer(playerid, slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return false;
    }

    if (!Internal_ValidatePlayerStorageDistance(playerid, slot_id))
    {
        if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "Вы находитесь слишком далеко от выбранного хранилища.");
        }
        return false;
    }

    if (!Storage_AcquireMutex(slot_id, playerid))
    {
        if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "Хранилище сейчас используется другим игроком.");
        }
        return false;
    }

    sStorages[slot_id][E_STORAGE_ACTIVE_VIEWER] = playerid;
    return true;
}

stock Storage_CloseForPlayer(playerid, slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return 0;
    }
    if (sStorageMutexOwner[slot_id] == playerid || sStorages[slot_id][E_STORAGE_ACTIVE_VIEWER] == playerid)
    {
        sStorages[slot_id][E_STORAGE_ACTIVE_VIEWER] = INVALID_PLAYER_ID;
        Storage_ReleaseMutex(slot_id);
    }
    return 1;
}

// Выгрузка хранилища и всех его предметов из RAM (без удаления из БД)
stock bool:Storage_Unload(slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return false;
    }
    if (Storage_IsMutexLocked(slot_id))
    {
        return false;
    }

    new currItem = sStorages[slot_id][E_STORAGE_FIRST_ITEM_SLOT];
    while (currItem != INVALID_STORAGE_ITEM_SLOT)
    {
        new const nextItem = sStorageItems[currItem][E_SITEM_NEXT_IN_STORAGE];
        new const nestedSlot = sStorageItems[currItem][E_SITEM_NESTED_STORAGE_SLOT];

        if (nestedSlot != INVALID_STORAGE_SLOT && Storage_IsValidSlot(nestedSlot))
        {
            Storage_Unload(nestedSlot);
        }

        Internal_ResetStorageItemSlot(currItem);
        Iter_Remove(StorageItemIter, currItem);
        currItem = nextItem;
    }

    Internal_DestroyStorageStreamerEntities(slot_id);
    Internal_ResetStorageSlot(slot_id);
    Iter_Remove(StorageIter, slot_id);
    return true;
}

// =============================================================================
//  5. ПУБЛИЧНЫЙ API ЧАСТИ 2 [2.3]: РЕКУРСИВНАЯ ФИЗИКА ВЕСА И ТРАНСФЕРЫ
// =============================================================================

// Определение текущей глубины вложенности хранилища (0 = корневое, 1 = рюкзак в кармане, 2 = предел)
stock Storage_GetNestingDepth(slot_id)
{
    new depth = 0;
    new curr = slot_id;
    while (Storage_IsValidSlot(curr) &&
           sStorages[curr][E_STORAGE_PARENT_SLOT] != INVALID_STORAGE_SLOT &&
           depth < (MAX_NESTING_DEPTH + 1))
    {
        curr = sStorages[curr][E_STORAGE_PARENT_SLOT];
        depth++;
    }
    return depth;
}

// Рекурсивный расчет общей массы хранилища в граммах (MAX_NESTING_DEPTH = 2):
// W_storage(S) = sum [ N_i * W_base(i) + N_ammo(i) * W_round(i) + W_nested(i) ]
stock Storage_GetCurrentWeight(slot_id, depth = 0)
{
    if (!Storage_IsValidSlot(slot_id) || depth > MAX_NESTING_DEPTH)
    {
        return 0;
    }

    new totalWeightG = 0;
    new currItem = sStorages[slot_id][E_STORAGE_FIRST_ITEM_SLOT];

    while (currItem != INVALID_STORAGE_ITEM_SLOT)
    {
        if (sStorageItems[currItem][E_SITEM_VALID])
        {
            new const defId = sStorageItems[currItem][E_SITEM_DEF_ID];
            new const amount = sStorageItems[currItem][E_SITEM_AMOUNT];
            new const ammo = sStorageItems[currItem][E_SITEM_AMMO_COUNT];

            totalWeightG += Item_CalculateInstanceWeight(defId, amount, ammo);

            new const nestedSlot = sStorageItems[currItem][E_SITEM_NESTED_STORAGE_SLOT];
            if (nestedSlot != INVALID_STORAGE_SLOT && depth < MAX_NESTING_DEPTH)
            {
                totalWeightG += Storage_GetCurrentWeight(nestedSlot, depth + 1);
            }
        }
        currItem = sStorageItems[currItem][E_SITEM_NEXT_IN_STORAGE];
    }
    return totalWeightG;
}

// Рекурсивный расчет общего занимаемого объема хранилища в миллилитрах
stock Storage_GetCurrentVolume(slot_id, depth = 0)
{
    if (!Storage_IsValidSlot(slot_id) || depth > MAX_NESTING_DEPTH)
    {
        return 0;
    }

    new totalVolumeMl = 0;
    new currItem = sStorages[slot_id][E_STORAGE_FIRST_ITEM_SLOT];

    while (currItem != INVALID_STORAGE_ITEM_SLOT)
    {
        if (sStorageItems[currItem][E_SITEM_VALID])
        {
            new const defId = sStorageItems[currItem][E_SITEM_DEF_ID];
            new const amount = sStorageItems[currItem][E_SITEM_AMOUNT];

            totalVolumeMl += Item_CalculateInstanceVolume(defId, amount);
        }
        currItem = sStorageItems[currItem][E_SITEM_NEXT_IN_STORAGE];
    }
    return totalVolumeMl;
}

// Создание нового хранилища в пуле RAM и в таблице storages
stock Storage_Create(
    E_STORAGE_TYPE:type,
    owner_id,
    max_weight_g,
    max_volume_ml,
    bool:is_locked = false,
    lock_level = 0,
    Float:pos_x = 0.0,
    Float:pos_y = 0.0,
    Float:pos_z = 0.0,
    interior = 0,
    virtual_world = 0,
    ttl_seconds = 0,
    existing_db_id = 0)
{
    new const slot_id = Iter_Free(StorageIter);
    if (slot_id == INVALID_ITERATOR_SLOT)
    {
        printf("%s [Entities/Storage] [ERROR] Пул хранилищ MAX_ACTIVE_STORAGES (%d) переполнен!",
            SERVER_LOG_PREFIX, MAX_ACTIVE_STORAGES);
        return INVALID_STORAGE_SLOT;
    }

    Iter_Add(StorageIter, slot_id);
    Internal_ResetStorageSlot(slot_id);

    sStorages[slot_id][E_STORAGE_VALID] = true;
    sStorages[slot_id][E_STORAGE_DB_ID] = (existing_db_id > 0) ? existing_db_id : (++sSyntheticStorageDbIdSeq);
    sStorages[slot_id][E_STORAGE_KIND] = type;
    sStorages[slot_id][E_STORAGE_OWNER_ID] = owner_id;
    sStorages[slot_id][E_STORAGE_MAX_WEIGHT_G] = max_weight_g;
    sStorages[slot_id][E_STORAGE_MAX_VOLUME_ML] = max_volume_ml;
    sStorages[slot_id][E_STORAGE_IS_LOCKED] = is_locked;
    sStorages[slot_id][E_STORAGE_LOCK_LEVEL] = lock_level;
    sStorages[slot_id][E_STORAGE_POS_X] = pos_x;
    sStorages[slot_id][E_STORAGE_POS_Y] = pos_y;
    sStorages[slot_id][E_STORAGE_POS_Z] = pos_z;
    sStorages[slot_id][E_STORAGE_INTERIOR] = interior;
    sStorages[slot_id][E_STORAGE_VW] = virtual_world;
    sStorages[slot_id][E_STORAGE_EXPIRES_AT] = (ttl_seconds > 0) ? (gettime() + ttl_seconds) : 0;
    // Новое хранилище не требует чтения из БД: его содержимое формируется синхронно.
    sStorageItemsReady[slot_id] = (existing_db_id <= 0);

    if (existing_db_id <= 0 && DB_IsConnected())
    {
        new typeStr[24];
        new expiresSql[64];
        Config_StorageTypeToString(type, typeStr);

        if (ttl_seconds > 0)
        {
            format(expiresSql, sizeof(expiresSql), "DATE_ADD(NOW(), INTERVAL %d SECOND)", ttl_seconds);
        }
        else
        {
            format(expiresSql, sizeof(expiresSql), "NULL");
        }

        mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
            "INSERT INTO `storages` (`id`, `storage_type`, `owner_id`, `max_weight_g`, `max_volume_ml`, `is_locked`, `lock_level`, `pos_x`, `pos_y`, `pos_z`, `interior`, `virtual_world`, `expires_at`) VALUES (%d, '%e', %d, %d, %d, %d, %d, %.3f, %.3f, %.3f, %d, %d, %s);",
            sStorages[slot_id][E_STORAGE_DB_ID],
            typeStr,
            owner_id,
            max_weight_g,
            max_volume_ml,
            is_locked ? 1 : 0,
            lock_level,
            pos_x,
            pos_y,
            pos_z,
            interior,
            virtual_world,
            expiresSql);

        // ID выделен заранее: последующие INSERT предметов и персонажа уже видят эту строку.
        mysql_tquery(gMySQL, sStorageSqlTxBuffer);
    }

    return slot_id;
}

// Добавление предмета в хранилище с проверкой массы, объема, Layer 2 и автосозданием NESTED_BAG для рюкзаков
stock E_STORAGE_RESULT:Storage_AddItem(
    storage_slot,
    def_id,
    amount,
    ammo_count = 0,
    Float:durability = 100.0,
    meta_int1 = 0,
    meta_int2 = 0,
    const meta_str[] = "",
    &out_item_slot = INVALID_STORAGE_ITEM_SLOT,
    existing_item_db_id = 0,
    existing_nested_storage_db_id = 0)
{
    out_item_slot = INVALID_STORAGE_ITEM_SLOT;

    if (!Storage_IsValidSlot(storage_slot))
    {
        return STORAGE_RES_INVALID_SLOT;
    }
    if (!Item_IsValid(def_id) || amount <= 0)
    {
        return STORAGE_RES_INVALID_ITEM;
    }

    // Проверка запрета помещения неразрешенных предметов в потайной Слой 2
    if (sStorages[storage_slot][E_STORAGE_KIND] == STORAGE_PLAYER_LAYER2 && !Item_CanStoreInLayer2(def_id))
    {
        return STORAGE_RES_LAYER2_FORBIDDEN;
    }

    // Проверка глубины вложенности для предметов-контейнеров (рюкзаков/сумок)
    new const bool:isContainerItem = Item_IsContainer(def_id);
    if (isContainerItem)
    {
        new const currentDepth = Storage_GetNestingDepth(storage_slot);
        if ((currentDepth + 1) >= MAX_NESTING_DEPTH)
        {
            return STORAGE_RES_NESTING_LIMIT;
        }
    }

    new const addedWeightG = Item_CalculateInstanceWeight(def_id, amount, ammo_count);
    new const addedVolumeMl = Item_CalculateInstanceVolume(def_id, amount);

    new const currentWeightG = Storage_GetCurrentWeight(storage_slot);
    new const currentVolumeMl = Storage_GetCurrentVolume(storage_slot);

    if ((currentWeightG + addedWeightG) > sStorages[storage_slot][E_STORAGE_MAX_WEIGHT_G])
    {
        return STORAGE_RES_WEIGHT_EXCEEDED;
    }
    if ((currentVolumeMl + addedVolumeMl) > sStorages[storage_slot][E_STORAGE_MAX_VOLUME_ML])
    {
        return STORAGE_RES_VOLUME_EXCEEDED;
    }

    // Попытка слияния стака для стакуемых предметов
    if (Item_IsStackable(def_id) && !isContainerItem)
    {
        new const maxStack = Item_GetMaxStack(def_id);
        new curr = sStorages[storage_slot][E_STORAGE_FIRST_ITEM_SLOT];
        while (curr != INVALID_STORAGE_ITEM_SLOT)
        {
            if (Internal_CanStackItems(curr, def_id, durability, meta_int1, meta_int2, meta_str) &&
                (sStorageItems[curr][E_SITEM_AMOUNT] + amount) <= maxStack)
            {
                sStorageItems[curr][E_SITEM_AMOUNT] += amount;
                out_item_slot = curr;

                if (existing_item_db_id <= 0 && DB_IsConnected() && sStorageItems[curr][E_SITEM_DB_ID] > 0)
                {
                    mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
                        "UPDATE `storage_items` SET `amount` = %d WHERE `id` = %d;",
                        sStorageItems[curr][E_SITEM_AMOUNT],
                        sStorageItems[curr][E_SITEM_DB_ID]);
                    mysql_tquery(gMySQL, sStorageSqlTxBuffer);
                }
                return STORAGE_RES_OK;
            }
            curr = sStorageItems[curr][E_SITEM_NEXT_IN_STORAGE];
        }
    }

    new const itemSlot = Iter_Free(StorageItemIter);
    if (itemSlot == INVALID_ITERATOR_SLOT)
    {
        return STORAGE_RES_POOL_FULL;
    }

    Iter_Add(StorageItemIter, itemSlot);
    Internal_ResetStorageItemSlot(itemSlot);

    sStorageItems[itemSlot][E_SITEM_VALID] = true;
    sStorageItems[itemSlot][E_SITEM_DB_ID] = (existing_item_db_id > 0) ? existing_item_db_id : (++sSyntheticItemDbIdSeq);
    sStorageItems[itemSlot][E_SITEM_DEF_ID] = def_id;
    sStorageItems[itemSlot][E_SITEM_AMOUNT] = amount;
    sStorageItems[itemSlot][E_SITEM_DURABILITY] = durability;
    sStorageItems[itemSlot][E_SITEM_AMMO_COUNT] = ammo_count;
    sStorageItems[itemSlot][E_SITEM_META_INT1] = meta_int1;
    sStorageItems[itemSlot][E_SITEM_META_INT2] = meta_int2;
    format(sStorageItems[itemSlot][E_SITEM_META_STR], STORAGE_ITEM_META_STR_LEN, "%s", meta_str);

    // Если предмет является переносным контейнером (рюкзак, сумка, ящик) — создаем для него дочернее хранилище NESTED_BAG
    if (isContainerItem)
    {
        new nestedSlot = INVALID_STORAGE_SLOT;
        if (existing_nested_storage_db_id > 0)
        {
            nestedSlot = Storage_FindByDbId(existing_nested_storage_db_id);
        }
        if (nestedSlot == INVALID_STORAGE_SLOT)
        {
            nestedSlot = Storage_Create(
                STORAGE_NESTED_BAG,
                sStorageItems[itemSlot][E_SITEM_DB_ID],
                Item_GetInnerMaxWeight(def_id),
                Item_GetInnerMaxVolume(def_id),
                false,
                0,
                0.0, 0.0, 0.0, 0, 0, 0,
                existing_nested_storage_db_id
            );
        }

        if (nestedSlot != INVALID_STORAGE_SLOT)
        {
            sStorages[nestedSlot][E_STORAGE_PARENT_SLOT] = storage_slot;
            sStorageItems[itemSlot][E_SITEM_NESTED_STORAGE_SLOT] = nestedSlot;
            sStorageItems[itemSlot][E_SITEM_NESTED_STORAGE_DB_ID] = sStorages[nestedSlot][E_STORAGE_DB_ID];
        }
    }

    Internal_LinkItemToStorageList(storage_slot, itemSlot);
    out_item_slot = itemSlot;

    if (existing_item_db_id <= 0 && DB_IsConnected() && sStorages[storage_slot][E_STORAGE_DB_ID] > 0)
    {
        new nestedSql[24];
        if (sStorageItems[itemSlot][E_SITEM_NESTED_STORAGE_DB_ID] > 0)
        {
            format(nestedSql, sizeof(nestedSql), "%d", sStorageItems[itemSlot][E_SITEM_NESTED_STORAGE_DB_ID]);
        }
        else
        {
            format(nestedSql, sizeof(nestedSql), "NULL");
        }

        mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
            "INSERT INTO `storage_items` (`id`, `storage_id`, `item_def_id`, `amount`, `durability`, `ammo_count`, `nested_storage_id`, `meta_int1`, `meta_int2`, `meta_str`) VALUES (%d, %d, %d, %d, %.2f, %d, %s, %d, %d, '%e');",
            sStorageItems[itemSlot][E_SITEM_DB_ID],
            sStorages[storage_slot][E_STORAGE_DB_ID],
            def_id,
            amount,
            durability,
            ammo_count,
            nestedSql,
            meta_int1,
            meta_int2,
            meta_str);

        // ID предмета выделен заранее; коллбек не нужен и не может перезаписать его чужим ID.
        mysql_tquery(gMySQL, sStorageSqlTxBuffer);
    }

    return STORAGE_RES_OK;
}

// Удаление или уменьшение количества предмета в хранилище
stock bool:Storage_RemoveItem(storage_slot, item_slot, amount)
{
    if (!Storage_IsValidSlot(storage_slot) || !Storage_IsValidItemSlot(item_slot) || amount <= 0)
    {
        return false;
    }
    if (sStorageItems[item_slot][E_SITEM_STORAGE_SLOT] != storage_slot)
    {
        return false;
    }

    if (amount < sStorageItems[item_slot][E_SITEM_AMOUNT])
    {
        sStorageItems[item_slot][E_SITEM_AMOUNT] -= amount;
        if (DB_IsConnected() && sStorageItems[item_slot][E_SITEM_DB_ID] > 0)
        {
            mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
                "UPDATE `storage_items` SET `amount` = %d WHERE `id` = %d;",
                sStorageItems[item_slot][E_SITEM_AMOUNT],
                sStorageItems[item_slot][E_SITEM_DB_ID]);
            mysql_tquery(gMySQL, sStorageSqlTxBuffer);
        }
        return true;
    }

    new const itemDbId = sStorageItems[item_slot][E_SITEM_DB_ID];
    new const nestedSlot = sStorageItems[item_slot][E_SITEM_NESTED_STORAGE_SLOT];
    new const itemDefId = sStorageItems[item_slot][E_SITEM_DEF_ID];
    new const itemMeta2 = sStorageItems[item_slot][E_SITEM_META_INT2];

    if (itemDefId == ITEM_ID_CLOTHING_OUTFIT && itemMeta2 == CLOTHING_STATE_EQUIPPED)
    {
        CallLocalFunction("OnStorageLostEquippedClothing", "ddd", storage_slot, item_slot, INVALID_STORAGE_SLOT);
    }

    Internal_UnlinkItemFromStorageList(storage_slot, item_slot);
    if (nestedSlot != INVALID_STORAGE_SLOT && Storage_IsValidSlot(nestedSlot))
    {
        Storage_Unload(nestedSlot);
    }

    Internal_ResetStorageItemSlot(item_slot);
    Iter_Remove(StorageItemIter, item_slot);

    if (DB_IsConnected() && itemDbId > 0)
    {
        mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
            "DELETE FROM `storage_items` WHERE `id` = %d;",
            itemDbId);
        mysql_tquery(gMySQL, sStorageSqlTxBuffer);
    }
    return true;
}

// Атомарное перемещение предмета между двумя хранилищами (DoD 2.3 + все 7 шагов TECH_CONTEXT.MD 3.1)
stock E_STORAGE_RESULT:Storage_TransferItem(
    playerid,
    src_slot,
    item_slot,
    dst_slot,
    amount,
    actor_char_id = 0)
{
    // 1. Проверка валидности хранилищ, предмета и дистанции (<= 3.5 м)
    if (!Storage_IsValidSlot(src_slot) || !Storage_IsValidSlot(dst_slot) || src_slot == dst_slot)
    {
        return STORAGE_RES_INVALID_SLOT;
    }
    if (!Storage_IsValidItemSlot(item_slot) ||
        sStorageItems[item_slot][E_SITEM_STORAGE_SLOT] != src_slot ||
        amount <= 0 ||
        amount > sStorageItems[item_slot][E_SITEM_AMOUNT])
    {
        return STORAGE_RES_INVALID_ITEM;
    }

    if (sStorages[src_slot][E_STORAGE_IS_LOCKED] || sStorages[dst_slot][E_STORAGE_IS_LOCKED])
    {
        if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "Операция отклонена: хранилище заперто на замок.");
        }
        return STORAGE_RES_LOCKED;
    }

    if (!Internal_ValidatePlayerStorageDistance(playerid, src_slot) ||
        !Internal_ValidatePlayerStorageDistance(playerid, dst_slot))
    {
        if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "Вы слишком далеко от хранилища для перемещения предмета.");
        }
        return STORAGE_RES_TOO_FAR;
    }

    // 2. Проверка и захват мьютексов обоих хранилищ (защита от дюпа)
    new const bool:srcWasOwnedByPlayer = (
        Storage_IsMutexLocked(src_slot) &&
        playerid != INVALID_PLAYER_ID &&
        sStorageMutexOwner[src_slot] == playerid
    );
    new const bool:dstWasOwnedByPlayer = (
        Storage_IsMutexLocked(dst_slot) &&
        playerid != INVALID_PLAYER_ID &&
        sStorageMutexOwner[dst_slot] == playerid
    );

    if (!Storage_AcquireMutex(src_slot, playerid))
    {
        if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "Исходное хранилище сейчас используется другим игроком.");
        }
        return STORAGE_RES_MUTEX_BUSY;
    }

    if (!Storage_AcquireMutex(dst_slot, playerid))
    {
        if (!srcWasOwnedByPlayer)
        {
            Storage_ReleaseMutex(src_slot);
        }
        if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "Целевое хранилище сейчас используется другим игроком.");
        }
        return STORAGE_RES_MUTEX_BUSY;
    }

    new const defId = sStorageItems[item_slot][E_SITEM_DEF_ID];
    new const itemAmmo = sStorageItems[item_slot][E_SITEM_AMMO_COUNT];
    new const Float:itemDurability = sStorageItems[item_slot][E_SITEM_DURABILITY];
    new const nestedSlot = sStorageItems[item_slot][E_SITEM_NESTED_STORAGE_SLOT];
    new const metaInt1 = sStorageItems[item_slot][E_SITEM_META_INT1];
    new const metaInt2 = sStorageItems[item_slot][E_SITEM_META_INT2];

    // 3. Проверка разрешения can_layer2 для потайного Слоя 2
    if (sStorages[dst_slot][E_STORAGE_KIND] == STORAGE_PLAYER_LAYER2 && !Item_CanStoreInLayer2(defId))
    {
        if (!srcWasOwnedByPlayer) Storage_ReleaseMutex(src_slot);
        if (!dstWasOwnedByPlayer) Storage_ReleaseMutex(dst_slot);

        if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "Этот предмет слишком крупный для потайных карманов (Слой 2).");
        }
        return STORAGE_RES_LAYER2_FORBIDDEN;
    }

    // 4. Проверка глубины вложенности контейнеров (MAX_NESTING_DEPTH = 2) и запрет самовложения
    if (nestedSlot != INVALID_STORAGE_SLOT)
    {
        if (dst_slot == nestedSlot || sStorages[dst_slot][E_STORAGE_PARENT_SLOT] == nestedSlot)
        {
            if (!srcWasOwnedByPlayer) Storage_ReleaseMutex(src_slot);
            if (!dstWasOwnedByPlayer) Storage_ReleaseMutex(dst_slot);
            return STORAGE_RES_NESTING_LIMIT;
        }

        new const dstDepth = Storage_GetNestingDepth(dst_slot);
        new const hasInnerItems = (
            Storage_IsValidSlot(nestedSlot) &&
            sStorages[nestedSlot][E_STORAGE_FIRST_ITEM_SLOT] != INVALID_STORAGE_ITEM_SLOT
        );
        if ((dstDepth + 1) >= MAX_NESTING_DEPTH || (hasInnerItems && (dstDepth + 2) > MAX_NESTING_DEPTH))
        {
            if (!srcWasOwnedByPlayer) Storage_ReleaseMutex(src_slot);
            if (!dstWasOwnedByPlayer) Storage_ReleaseMutex(dst_slot);

            if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "Нельзя вкладывать контейнеры глубже допустимого предела (максимум 2 уровня).");
            }
            return STORAGE_RES_NESTING_LIMIT;
        }
    }

    // 5. Расчет перемещаемой массы и объема (включая внутреннее содержимое рюкзака)
    new transferWeightG = Item_CalculateInstanceWeight(defId, amount, (amount == sStorageItems[item_slot][E_SITEM_AMOUNT]) ? itemAmmo : 0);
    new const transferVolumeMl = Item_CalculateInstanceVolume(defId, amount);

    if (nestedSlot != INVALID_STORAGE_SLOT && Storage_IsValidSlot(nestedSlot))
    {
        transferWeightG += Storage_GetCurrentWeight(nestedSlot, 1);
    }

    // Если dst_slot не является родительским контейнером для src_slot, проверяем лимиты массы и объема dst_slot
    new const bool:movingInsideSameRootHierarchy = (sStorages[src_slot][E_STORAGE_PARENT_SLOT] == dst_slot);
    if (!movingInsideSameRootHierarchy)
    {
        new const dstCurrWeightG = Storage_GetCurrentWeight(dst_slot);
        new const dstCurrVolumeMl = Storage_GetCurrentVolume(dst_slot);

        if ((dstCurrWeightG + transferWeightG) > sStorages[dst_slot][E_STORAGE_MAX_WEIGHT_G])
        {
            if (!srcWasOwnedByPlayer) Storage_ReleaseMutex(src_slot);
            if (!dstWasOwnedByPlayer) Storage_ReleaseMutex(dst_slot);

            if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "Перемещение отклонено: превышен лимит максимального веса целевого хранилища.");
            }
            return STORAGE_RES_WEIGHT_EXCEEDED;
        }

        if ((dstCurrVolumeMl + transferVolumeMl) > sStorages[dst_slot][E_STORAGE_MAX_VOLUME_ML])
        {
            if (!srcWasOwnedByPlayer) Storage_ReleaseMutex(src_slot);
            if (!dstWasOwnedByPlayer) Storage_ReleaseMutex(dst_slot);

            if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "Перемещение отклонено: недостаточно свободного объема в целевом хранилище.");
            }
            return STORAGE_RES_VOLUME_EXCEEDED;
        }
    }

    // Если dst_slot сам вложен в родительский контейнер — проверяем лимит массы родителя
    new const dstParentSlot = sStorages[dst_slot][E_STORAGE_PARENT_SLOT];
    if (dstParentSlot != INVALID_STORAGE_SLOT && dstParentSlot != src_slot && Storage_IsValidSlot(dstParentSlot))
    {
        if ((Storage_GetCurrentWeight(dstParentSlot) + transferWeightG) > sStorages[dstParentSlot][E_STORAGE_MAX_WEIGHT_G])
        {
            if (!srcWasOwnedByPlayer) Storage_ReleaseMutex(src_slot);
            if (!dstWasOwnedByPlayer) Storage_ReleaseMutex(dst_slot);
            return STORAGE_RES_WEIGHT_EXCEEDED;
        }
    }

    // 6. Мутация состояния в RAM (слияние стаков, разделение стака или полный перенос узла)
    new mergedDstItemSlot = INVALID_STORAGE_ITEM_SLOT;
    if (Item_IsStackable(defId) && nestedSlot == INVALID_STORAGE_SLOT)
    {
        new const maxStack = Item_GetMaxStack(defId);
        new currDst = sStorages[dst_slot][E_STORAGE_FIRST_ITEM_SLOT];
        while (currDst != INVALID_STORAGE_ITEM_SLOT)
        {
            if (Internal_CanStackItems(currDst, defId, itemDurability, metaInt1, metaInt2, sStorageItems[item_slot][E_SITEM_META_STR]) &&
                (sStorageItems[currDst][E_SITEM_AMOUNT] + amount) <= maxStack)
            {
                mergedDstItemSlot = currDst;
                break;
            }
            currDst = sStorageItems[currDst][E_SITEM_NEXT_IN_STORAGE];
        }
    }

    new const srcItemDbId = sStorageItems[item_slot][E_SITEM_DB_ID];
    new const srcStorageDbId = sStorages[src_slot][E_STORAGE_DB_ID];
    new const dstStorageDbId = sStorages[dst_slot][E_STORAGE_DB_ID];

    if (mergedDstItemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        sStorageItems[mergedDstItemSlot][E_SITEM_AMOUNT] += amount;
        new const dstMergedDbId = sStorageItems[mergedDstItemSlot][E_SITEM_DB_ID];
        new const dstNewAmount = sStorageItems[mergedDstItemSlot][E_SITEM_AMOUNT];

        if (amount == sStorageItems[item_slot][E_SITEM_AMOUNT])
        {
            Internal_UnlinkItemFromStorageList(src_slot, item_slot);
            Internal_ResetStorageItemSlot(item_slot);
            Iter_Remove(StorageItemIter, item_slot);

            if (DB_IsConnected() && srcItemDbId > 0 && dstMergedDbId > 0)
            {
                mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
                    "START TRANSACTION; UPDATE `storage_items` SET `amount` = %d WHERE `id` = %d; DELETE FROM `storage_items` WHERE `id` = %d; COMMIT;",
                    dstNewAmount, dstMergedDbId, srcItemDbId);
                mysql_tquery(gMySQL, sStorageSqlTxBuffer);
            }
        }
        else
        {
            sStorageItems[item_slot][E_SITEM_AMOUNT] -= amount;
            new const srcNewAmount = sStorageItems[item_slot][E_SITEM_AMOUNT];

            if (DB_IsConnected() && srcItemDbId > 0 && dstMergedDbId > 0)
            {
                mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
                    "START TRANSACTION; UPDATE `storage_items` SET `amount` = %d WHERE `id` = %d; UPDATE `storage_items` SET `amount` = %d WHERE `id` = %d; COMMIT;",
                    srcNewAmount, srcItemDbId, dstNewAmount, dstMergedDbId);
                mysql_tquery(gMySQL, sStorageSqlTxBuffer);
            }
        }
    }
    else if (amount == sStorageItems[item_slot][E_SITEM_AMOUNT])
    {
        // Полный перенос экземпляра предмета из src_slot в dst_slot за O(1)
        new bool:clothingWasEquipped = false;
        if (defId == ITEM_ID_CLOTHING_OUTFIT && metaInt2 == CLOTHING_STATE_EQUIPPED)
        {
            if (CallLocalFunction("OnStorageLostEquippedClothing", "ddd", src_slot, item_slot, dst_slot) == 1)
            {
                clothingWasEquipped = true;
                sStorageItems[item_slot][E_SITEM_META_INT2] = CLOTHING_STATE_BAG;
            }
        }

        Internal_UnlinkItemFromStorageList(src_slot, item_slot);
        Internal_LinkItemToStorageList(dst_slot, item_slot);

        if (DB_IsConnected() && srcItemDbId > 0 && dstStorageDbId > 0)
        {
            if (clothingWasEquipped)
            {
                mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
                    "START TRANSACTION; UPDATE `storage_items` SET `storage_id` = %d, `meta_int2` = %d WHERE `id` = %d; COMMIT;",
                    dstStorageDbId, CLOTHING_STATE_BAG, srcItemDbId);
            }
            else
            {
                mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
                    "START TRANSACTION; UPDATE `storage_items` SET `storage_id` = %d WHERE `id` = %d; COMMIT;",
                    dstStorageDbId, srcItemDbId);
            }
            mysql_tquery(gMySQL, sStorageSqlTxBuffer);
        }
    }
    else
    {
        // Разделение стака: уменьшаем в src_slot и создаем новую запись в dst_slot
        new const newItemSlot = Iter_Free(StorageItemIter);
        if (newItemSlot == INVALID_ITERATOR_SLOT)
        {
            if (!srcWasOwnedByPlayer) Storage_ReleaseMutex(src_slot);
            if (!dstWasOwnedByPlayer) Storage_ReleaseMutex(dst_slot);
            return STORAGE_RES_POOL_FULL;
        }

        sStorageItems[item_slot][E_SITEM_AMOUNT] -= amount;
        new const srcRemainingAmount = sStorageItems[item_slot][E_SITEM_AMOUNT];

        Iter_Add(StorageItemIter, newItemSlot);
        Internal_ResetStorageItemSlot(newItemSlot);

        sStorageItems[newItemSlot][E_SITEM_VALID] = true;
        sStorageItems[newItemSlot][E_SITEM_DB_ID] = ++sSyntheticItemDbIdSeq;
        sStorageItems[newItemSlot][E_SITEM_DEF_ID] = defId;
        sStorageItems[newItemSlot][E_SITEM_AMOUNT] = amount;
        sStorageItems[newItemSlot][E_SITEM_DURABILITY] = itemDurability;
        sStorageItems[newItemSlot][E_SITEM_AMMO_COUNT] = 0;
        sStorageItems[newItemSlot][E_SITEM_META_INT1] = metaInt1;
        sStorageItems[newItemSlot][E_SITEM_META_INT2] = metaInt2;
        format(sStorageItems[newItemSlot][E_SITEM_META_STR], STORAGE_ITEM_META_STR_LEN,
            "%s", sStorageItems[item_slot][E_SITEM_META_STR]);

        Internal_LinkItemToStorageList(dst_slot, newItemSlot);

        if (DB_IsConnected() && srcItemDbId > 0 && dstStorageDbId > 0)
        {
            mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
                "START TRANSACTION; UPDATE `storage_items` SET `amount` = %d WHERE `id` = %d; INSERT INTO `storage_items` (`storage_id`, `item_def_id`, `amount`, `durability`, `ammo_count`, `meta_int1`, `meta_int2`, `meta_str`) VALUES (%d, %d, %d, %.2f, 0, %d, %d, '%e'); COMMIT;",
                srcRemainingAmount,
                srcItemDbId,
                dstStorageDbId,
                defId,
                amount,
                itemDurability,
                metaInt1,
                metaInt2,
                sStorageItems[newItemSlot][E_SITEM_META_STR]);
            mysql_tquery(gMySQL, sStorageSqlTxBuffer);
        }
    }

    // Запись транзакции перемещения в аудит-лог (Инвариант 9 AGENTS.MD)
    new srcEntityTag[48], dstEntityTag[48], auditDetails[160], itemName[64];
    Item_GetName(defId, itemName);
    format(srcEntityTag, sizeof(srcEntityTag), "STORAGE_%d", srcStorageDbId);
    format(dstEntityTag, sizeof(dstEntityTag), "STORAGE_%d", dstStorageDbId);
    format(auditDetails, sizeof(auditDetails),
        "Перемещение предмета '%s' (кол-во: %d, вес: %d г) из хранилища #%d в #%d",
        itemName, amount, transferWeightG, srcStorageDbId, dstStorageDbId);

    Audit_Log(actor_char_id, "ITEM_MOVE", srcEntityTag, dstEntityTag, defId, amount, auditDetails);

    // 7. Освобождение мьютексов (если они не удерживались открытым окном диалога этого же игрока)
    if (!srcWasOwnedByPlayer)
    {
        Storage_ReleaseMutex(src_slot);
    }
    if (!dstWasOwnedByPlayer)
    {
        Storage_ReleaseMutex(dst_slot);
    }

    return STORAGE_RES_OK;
}

// Мгновенный перенос 100% содержимого из одного хранилища в другое (для PK: PLAYER_LAYER1 -> CORPSE_LOOT)
stock Storage_TransferAllItems(src_slot, dst_slot, actor_char_id = 0)
{
    if (!Storage_IsValidSlot(src_slot) || !Storage_IsValidSlot(dst_slot) || src_slot == dst_slot)
    {
        return 0;
    }

    new movedItems = 0;
    new currItem = sStorages[src_slot][E_STORAGE_FIRST_ITEM_SLOT];

    while (currItem != INVALID_STORAGE_ITEM_SLOT)
    {
        new const nextItem = sStorageItems[currItem][E_SITEM_NEXT_IN_STORAGE];
        new const amount = sStorageItems[currItem][E_SITEM_AMOUNT];

        if (Storage_TransferItem(INVALID_PLAYER_ID, src_slot, currItem, dst_slot, amount, actor_char_id) == STORAGE_RES_OK)
        {
            movedItems++;
        }
        currItem = nextItem;
    }
    return movedItems;
}

// =============================================================================
//  6. ПУБЛИЧНЫЙ API ЧАСТИ 3 [2.4]: ПОЛЕВЫЕ ХРАНИЛИЩА WORLD_DROP И CORPSE_LOOT
// =============================================================================

// Создание мирового контейнера (выброшенный предмет / лесной тайник) с 3D-объектом и DynamicArea
stock Storage_CreateWorldDrop(
    Float:x,
    Float:y,
    Float:z,
    interior,
    virtual_world,
    primary_item_def_id = 0,
    ttl_seconds = TTL_WORLD_DROP_SECONDS)
{
    new const slot_id = Storage_Create(
        STORAGE_WORLD_DROP,
        0,
        DEFAULT_WORLD_DROP_MAX_WEIGHT_G,
        DEFAULT_WORLD_DROP_MAX_VOLUME_ML,
        false,
        0,
        x, y, z,
        interior,
        virtual_world,
        ttl_seconds
    );

    if (slot_id == INVALID_STORAGE_SLOT)
    {
        return INVALID_STORAGE_SLOT;
    }

    new const modelId = Item_GetWorldObjectModel(primary_item_def_id);
    new labelText[144];

    if (Item_IsValid(primary_item_def_id))
    {
        new itemName[64];
        Item_GetName(primary_item_def_id, itemName);
        format(labelText, sizeof(labelText),
            "Предмет на земле: %s\nНажмите [Y] для взаимодействия",
            itemName);
    }
    else
    {
        format(labelText, sizeof(labelText),
            "Полевой схрон / сброшенные вещи\nНажмите [Y] для взаимодействия");
    }

    Internal_SpawnWorldDropVisuals(slot_id, modelId, labelText, COLOR_UI_LABEL_DROP);
    return slot_id;
}

// Создание контейнера трупа погибшего персонажа (CORPSE_LOOT, TTL = 20 минут)
stock Storage_CreateCorpseLoot(
    victim_char_id,
    const victim_name[],
    Float:x,
    Float:y,
    Float:z,
    interior,
    virtual_world,
    ttl_seconds = TTL_CORPSE_LOOT_SECONDS)
{
    new const slot_id = Storage_Create(
        STORAGE_CORPSE_LOOT,
        victim_char_id,
        DEFAULT_CORPSE_MAX_WEIGHT_G,
        DEFAULT_CORPSE_MAX_VOLUME_ML,
        false,
        0,
        x, y, z,
        interior,
        virtual_world,
        ttl_seconds
    );

    if (slot_id == INVALID_STORAGE_SLOT)
    {
        return INVALID_STORAGE_SLOT;
    }

    new labelText[144];
    format(labelText, sizeof(labelText),
        "Тело погибшего: %s\nНажмите [Y] для обыска",
        (victim_name[0] != '\0') ? victim_name : "Неизвестный");

    Internal_SpawnWorldDropVisuals(slot_id, CORPSE_WORLD_OBJECT_MODEL, labelText, COLOR_UI_LABEL_CORPSE);
    return slot_id;
}

// Поиск ближайшего полевого хранилища (WORLD_DROP / CORPSE_LOOT) в радиусе 2.0 м от игрока
stock Storage_FindNearestWorldContainer(playerid, Float:max_radius = WORLD_DROP_INTERACT_RADIUS)
{
    if (!IsPlayerConnected(playerid))
    {
        return INVALID_STORAGE_SLOT;
    }

    new const vw = GetPlayerVirtualWorld(playerid);
    new const interior = GetPlayerInterior(playerid);
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);

    new bestSlot = INVALID_STORAGE_SLOT;
    new Float:bestDist = max_radius;

    foreach (new slot : StorageIter)
    {
        if (!sStorages[slot][E_STORAGE_VALID])
        {
            continue;
        }
        new const E_STORAGE_TYPE:kind = sStorages[slot][E_STORAGE_KIND];
        if (kind != STORAGE_WORLD_DROP && kind != STORAGE_CORPSE_LOOT)
        {
            continue;
        }
        if (sStorages[slot][E_STORAGE_VW] != vw || sStorages[slot][E_STORAGE_INTERIOR] != interior)
        {
            continue;
        }

        new const Float:dist = Utils_GetDistance3D(
            px, py, pz,
            sStorages[slot][E_STORAGE_POS_X],
            sStorages[slot][E_STORAGE_POS_Y],
            sStorages[slot][E_STORAGE_POS_Z]
        );
        if (dist <= bestDist)
        {
            bestDist = dist;
            bestSlot = slot;
        }
    }

    return bestSlot;
}

// Полное удаление хранилища из RAM, стримера и БД (используется сборщиком мусора TTL)
stock bool:Storage_DestroyExpiredOrEmpty(slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return false;
    }
    if (Storage_IsMutexLocked(slot_id))
    {
        return false;
    }

    new const dbId = sStorages[slot_id][E_STORAGE_DB_ID];
    Storage_Unload(slot_id);

    if (DB_IsConnected() && dbId > 0)
    {
        mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
            "DELETE FROM `storages` WHERE `id` = %d;",
            dbId);
        mysql_tquery(gMySQL, sStorageSqlTxBuffer);
    }
    return true;
}

// =============================================================================
//  7. ЗАГРУЗКА СИСТЕМНЫХ ХРАНИЛИЩ ИЗ БД И АСИНХРОННЫЕ КОЛБЕКИ
// =============================================================================

// Загрузка конкретного хранилища из БД по его db_storage_id (асинхронно во время игры)
// Асинхронная загрузка хранилища: слот в RAM создается сразу, чтобы вызывающий
// код получил валидный идентификатор, а заголовок и предметы догружаются из БД.
// Возвращает слот RAM либо INVALID_STORAGE_SLOT.
stock Storage_Load(
    db_storage_id,
    E_STORAGE_TYPE:expected_type = STORAGE_NONE,
    owner_id = 0,
    max_weight_g = 0,
    max_volume_ml = 0)
{
    if (db_storage_id <= 0)
    {
        return INVALID_STORAGE_SLOT;
    }

    new const existingSlot = Storage_FindByDbId(db_storage_id);
    if (existingSlot != INVALID_STORAGE_SLOT)
    {
        return existingSlot;
    }

    if (!DB_IsConnected())
    {
        return INVALID_STORAGE_SLOT;
    }

    new const slot_id = Storage_Create(
        expected_type,
        owner_id,
        max_weight_g,
        max_volume_ml,
        false,
        0,
        0.0, 0.0, 0.0,
        0,
        0,
        0,
        db_storage_id);

    if (slot_id == INVALID_STORAGE_SLOT)
    {
        return INVALID_STORAGE_SLOT;
    }

    // Сразу помечаем слот как «загружается», чтобы повторный вызов не создал дубль.
    sStorageItemsReady[slot_id] = false;

    mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
        "SELECT `id`, `storage_type`, `owner_id`, `max_weight_g`, `max_volume_ml`, `is_locked`, `lock_level`, IFNULL(`pos_x`, 0.0) AS `px`, IFNULL(`pos_y`, 0.0) AS `py`, IFNULL(`pos_z`, 0.0) AS `pz`, `interior`, `virtual_world`, IFNULL(UNIX_TIMESTAMP(`expires_at`), 0) AS `exp_ts` FROM `storages` WHERE `id` = %d LIMIT 1;",
        db_storage_id);
    mysql_tquery(gMySQL, sStorageSqlTxBuffer, "OnStorageHeaderLoaded", "d", db_storage_id);
    return slot_id;
}

static stock Internal_LoadPersistentStoragesOnInitSync()
{
    if (!DB_IsConnected())
    {
        return 0;
    }

    // Синхронно поднимаем счетчики синтетических ID выше реальных MAX(id),
    // чтобы после перезапуска сервера новые строки не конфликтовали по PRIMARY KEY.
    new const Cache:maxIdCache = mysql_query(gMySQL,
        "SELECT (SELECT IFNULL(MAX(`id`), 0) FROM `storages`) AS `max_storage`, (SELECT IFNULL(MAX(`id`), 0) FROM `storage_items`) AS `max_item`;",
        true);
    if (cache_is_valid(maxIdCache))
    {
        new maxStorageId = 0, maxItemId = 0;
        cache_get_value_name_int(0, "max_storage", maxStorageId);
        cache_get_value_name_int(0, "max_item", maxItemId);
        if (maxStorageId > sSyntheticStorageDbIdSeq)
        {
            sSyntheticStorageDbIdSeq = maxStorageId;
        }
        if (maxItemId > sSyntheticItemDbIdSeq)
        {
            sSyntheticItemDbIdSeq = maxItemId;
        }
        cache_delete(maxIdCache);
    }

    // Разрешенный синхронный запрос строго внутри OnGameModeInit (загрузка казн фракций и складов предприятий)
    new const Cache:storageCache = mysql_query(gMySQL,
        "SELECT `id`, `storage_type`, `owner_id`, `max_weight_g`, `max_volume_ml`, `is_locked`, `lock_level`, IFNULL(`pos_x`, 0.0) AS `px`, IFNULL(`pos_y`, 0.0) AS `py`, IFNULL(`pos_z`, 0.0) AS `pz`, `interior`, `virtual_world`, IFNULL(UNIX_TIMESTAMP(`expires_at`), 0) AS `exp_ts` FROM `storages` WHERE `storage_type` IN ('ORG_VAULT', 'ENTERPRISE_WAREHOUSE', 'NESTED_BAG') ORDER BY `id` ASC;",
        true);

    if (!cache_is_valid(storageCache))
    {
        return 0;
    }

    new storageRows = 0;
    cache_get_row_count(storageRows);
    new loadedStorages = 0;

    for (new r = 0; r < storageRows; r++)
    {
        new dbId, ownerId, maxWeightG, maxVolumeMl, isLockedInt, lockLevel, interior, vw, expTs;
        new Float:px, Float:py, Float:pz;
        new typeStr[32];

        cache_get_value_name_int(r, "id", dbId);
        cache_get_value_name(r, "storage_type", typeStr, sizeof(typeStr));
        cache_get_value_name_int(r, "owner_id", ownerId);
        cache_get_value_name_int(r, "max_weight_g", maxWeightG);
        cache_get_value_name_int(r, "max_volume_ml", maxVolumeMl);
        cache_get_value_name_int(r, "is_locked", isLockedInt);
        cache_get_value_name_int(r, "lock_level", lockLevel);
        cache_get_value_name_float(r, "px", px);
        cache_get_value_name_float(r, "py", py);
        cache_get_value_name_float(r, "pz", pz);
        cache_get_value_name_int(r, "interior", interior);
        cache_get_value_name_int(r, "virtual_world", vw);
        cache_get_value_name_int(r, "exp_ts", expTs);

        new const slot = Storage_Create(
            Config_ParseStorageType(typeStr),
            ownerId,
            maxWeightG,
            maxVolumeMl,
            (isLockedInt != 0),
            lockLevel,
            px, py, pz,
            interior,
            vw,
            0,
            dbId
        );

        if (slot != INVALID_STORAGE_SLOT)
        {
            sStorages[slot][E_STORAGE_EXPIRES_AT] = expTs;
            if (dbId > sSyntheticStorageDbIdSeq)
            {
                sSyntheticStorageDbIdSeq = dbId;
            }
            loadedStorages++;
        }
    }
    cache_delete(storageCache);

    // Синхронная загрузка предметов для загруженных постоянных хранилищ
    new const Cache:itemCache = mysql_query(gMySQL,
        "SELECT `id`, `storage_id`, `item_def_id`, `amount`, `durability`, `ammo_count`, IFNULL(`nested_storage_id`, 0) AS `nested_id`, `meta_int1`, `meta_int2`, IFNULL(`meta_str`, '') AS `mstr` FROM `storage_items` ORDER BY `id` ASC;",
        true);

    if (cache_is_valid(itemCache))
    {
        new itemRows = 0;
        cache_get_row_count(itemRows);

        for (new i = 0; i < itemRows; i++)
        {
            new itemDbId, storageDbId, defId, amount, ammoCount, nestedDbId, meta1, meta2;
            new Float:durability;
            new metaStr[STORAGE_ITEM_META_STR_LEN];

            cache_get_value_name_int(i, "id", itemDbId);
            cache_get_value_name_int(i, "storage_id", storageDbId);
            cache_get_value_name_int(i, "item_def_id", defId);
            cache_get_value_name_int(i, "amount", amount);
            cache_get_value_name_float(i, "durability", durability);
            cache_get_value_name_int(i, "ammo_count", ammoCount);
            cache_get_value_name_int(i, "nested_id", nestedDbId);
            cache_get_value_name_int(i, "meta_int1", meta1);
            cache_get_value_name_int(i, "meta_int2", meta2);
            cache_get_value_name(i, "mstr", metaStr, sizeof(metaStr));

            new const storageSlot = Storage_FindByDbId(storageDbId);
            if (storageSlot != INVALID_STORAGE_SLOT)
            {
                new outItemSlot;
                Storage_AddItem(
                    storageSlot,
                    defId,
                    amount,
                    ammoCount,
                    durability,
                    meta1,
                    meta2,
                    metaStr,
                    outItemSlot,
                    itemDbId,
                    nestedDbId
                );
                if (itemDbId > sSyntheticItemDbIdSeq)
                {
                    sSyntheticItemDbIdSeq = itemDbId;
                }
            }
        }
        cache_delete(itemCache);
    }

    // Все постоянные хранилища, загруженные синхронно на старте, уже готовы.
    foreach (new storageSlot : StorageIter)
    {
        if (sStorages[storageSlot][E_STORAGE_VALID] &&
            sStorages[storageSlot][E_STORAGE_DB_ID] > 0)
        {
            sStorageItemsReady[storageSlot] = true;
        }
    }

    return loadedStorages;
}

forward OnStorageCreatedInDb(slot_id);
public OnStorageCreatedInDb(slot_id)
{
    if (!Storage_IsValidSlot(slot_id))
    {
        return 0;
    }
    new const insertId = cache_insert_id();
    if (insertId > 0)
    {
        sStorages[slot_id][E_STORAGE_DB_ID] = insertId;
    }
    return 1;
}

forward OnStorageItemInsertedInDb(item_slot);
public OnStorageItemInsertedInDb(item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }
    new const insertId = cache_insert_id();
    if (insertId > 0)
    {
        sStorageItems[item_slot][E_SITEM_DB_ID] = insertId;
    }
    return 1;
}

forward OnStorageHeaderLoaded(requested_db_id);
public OnStorageHeaderLoaded(requested_db_id)
{
    #pragma unused requested_db_id
    new rows = 0;
    cache_get_row_count(rows);
    if (rows <= 0)
    {
        // Заголовок отсутствует: слот мог быть создан по локальным данным.
        new const orphanSlot = Storage_FindByDbId(requested_db_id);
        if (orphanSlot != INVALID_STORAGE_SLOT)
        {
            sStorageItemsReady[orphanSlot] = true;
            CallLocalFunction("OnCharacterInventoryStorageReady", "d", orphanSlot);
        }
        return 0;
    }

    new dbId, ownerId, maxWeightG, maxVolumeMl, isLockedInt, lockLevel, interior, vw, expTs;
    new Float:px, Float:py, Float:pz;
    new typeStr[32];

    cache_get_value_name_int(0, "id", dbId);
    cache_get_value_name(0, "storage_type", typeStr, sizeof(typeStr));
    cache_get_value_name_int(0, "owner_id", ownerId);
    cache_get_value_name_int(0, "max_weight_g", maxWeightG);
    cache_get_value_name_int(0, "max_volume_ml", maxVolumeMl);
    cache_get_value_name_int(0, "is_locked", isLockedInt);
    cache_get_value_name_int(0, "lock_level", lockLevel);
    cache_get_value_name_float(0, "px", px);
    cache_get_value_name_float(0, "py", py);
    cache_get_value_name_float(0, "pz", pz);
    cache_get_value_name_int(0, "interior", interior);
    cache_get_value_name_int(0, "virtual_world", vw);
    cache_get_value_name_int(0, "exp_ts", expTs);

    new slot = Storage_FindByDbId(dbId);
    if (slot == INVALID_STORAGE_SLOT)
    {
        slot = Storage_Create(
            Config_ParseStorageType(typeStr),
            ownerId,
            maxWeightG,
            maxVolumeMl,
            (isLockedInt != 0),
            lockLevel,
            px, py, pz,
            interior,
            vw,
            0,
            dbId
        );
    }

    if (slot == INVALID_STORAGE_SLOT)
    {
        return 0;
    }

    // Авторитетные данные заголовка из БД применяются к уже созданному слоту.
    sStorages[slot][E_STORAGE_KIND] = Config_ParseStorageType(typeStr);
    sStorages[slot][E_STORAGE_OWNER_ID] = ownerId;
    sStorages[slot][E_STORAGE_MAX_WEIGHT_G] = maxWeightG;
    sStorages[slot][E_STORAGE_MAX_VOLUME_ML] = maxVolumeMl;
    sStorages[slot][E_STORAGE_IS_LOCKED] = (isLockedInt != 0);
    sStorages[slot][E_STORAGE_LOCK_LEVEL] = lockLevel;
    sStorages[slot][E_STORAGE_POS_X] = px;
    sStorages[slot][E_STORAGE_POS_Y] = py;
    sStorages[slot][E_STORAGE_POS_Z] = pz;
    sStorages[slot][E_STORAGE_INTERIOR] = interior;
    sStorages[slot][E_STORAGE_VW] = vw;
    sStorages[slot][E_STORAGE_EXPIRES_AT] = expTs;

    // Запрос предметов отправляется строго один раз на слот.
    if (sStorageItemsLoadStarted[slot])
    {
        return 1;
    }
    sStorageItemsLoadStarted[slot] = true;

    mysql_format(gMySQL, sStorageSqlTxBuffer, sizeof(sStorageSqlTxBuffer),
        "SELECT `id`, `item_def_id`, `amount`, `durability`, `ammo_count`, IFNULL(`nested_storage_id`, 0) AS `nested_id`, `meta_int1`, `meta_int2`, IFNULL(`meta_str`, '') AS `mstr` FROM `storage_items` WHERE `storage_id` = %d ORDER BY `id` ASC;",
        dbId);
    mysql_tquery(gMySQL, sStorageSqlTxBuffer, "OnStorageItemsLoaded", "dd", slot, dbId);
    return 1;
}

forward OnStorageItemsLoaded(storage_slot, expected_db_id);
public OnStorageItemsLoaded(storage_slot, expected_db_id)
{
    if (!Storage_IsValidSlot(storage_slot) || sStorages[storage_slot][E_STORAGE_DB_ID] != expected_db_id)
    {
        return 0;
    }

    if (sStorageItemsReady[storage_slot])
    {
        return 1;
    }

    new rows = 0;
    cache_get_row_count(rows);

    for (new i = 0; i < rows; i++)
    {
        new itemDbId, defId, amount, ammoCount, nestedDbId, meta1, meta2;
        new Float:durability;
        new metaStr[STORAGE_ITEM_META_STR_LEN];

        cache_get_value_name_int(i, "id", itemDbId);
        cache_get_value_name_int(i, "item_def_id", defId);
        cache_get_value_name_int(i, "amount", amount);
        cache_get_value_name_float(i, "durability", durability);
        cache_get_value_name_int(i, "ammo_count", ammoCount);
        cache_get_value_name_int(i, "nested_id", nestedDbId);
        cache_get_value_name_int(i, "meta_int1", meta1);
        cache_get_value_name_int(i, "meta_int2", meta2);
        cache_get_value_name(i, "mstr", metaStr, sizeof(metaStr));

        new outItemSlot;
        Storage_AddItem(
            storage_slot,
            defId,
            amount,
            ammoCount,
            durability,
            meta1,
            meta2,
            metaStr,
            outItemSlot,
            itemDbId,
            nestedDbId
        );
    }

    sStorageItemsReady[storage_slot] = true;

    // Модуль персонажа пересчитывает надетую одежду после загрузки слоя.
    CallLocalFunction("OnCharacterInventoryStorageReady", "d", storage_slot);
    return 1;
}

// =============================================================================
//  8. САМОТЕСТИРОВАНИЕ МОДУЛЯ ХРАНИЛИЩ ПРИ СТАРТЕ (DoD 2.2, 2.3, 2.4)
// =============================================================================

static stock Internal_RunStorageSelfTests()
{
    // Тест 1 (DoD 2.2): Блокировка второго игрока мьютексом при одновременном открытии хранилища
    new const testPocketSlot = Storage_Create(
        STORAGE_PLAYER_LAYER1,
        999901,
        DEFAULT_PLAYER_LAYER1_WEIGHT_G,
        DEFAULT_PLAYER_LAYER1_VOLUME_ML,
        false, 0, 0.0, 0.0, 0.0, 0, 0, 0, 999901
    );
    new const testTrunkSlot = Storage_Create(
        STORAGE_VEHICLE_TRUNK,
        999902,
        10000,
        10000,
        false, 0, 0.0, 0.0, 0.0, 0, 0, 0, 999902
    );

    new const bool:firstLockOk = Storage_AcquireMutex(testPocketSlot, 1);
    new const bool:secondLockBlocked = !Storage_AcquireMutex(testPocketSlot, 2);
    Storage_ReleaseMutex(testPocketSlot);

    // Тест 2 (DoD 2.3): Помещение рюкзака (ID 41, 1500 г) в карман и укладка внутрь рюкзака 200 M4 (ID 23, 5800 г)
    new backpackItemSlot = INVALID_STORAGE_ITEM_SLOT;
    Storage_AddItem(testPocketSlot, ITEM_ID_BACKPACK, 1, 0, 100.0, 0, 0, "", backpackItemSlot, 999911, 999903);
    new const nestedBagSlot = Storage_GetItemNestedSlot(backpackItemSlot);

    new m4ItemSlot = INVALID_STORAGE_ITEM_SLOT;
    if (nestedBagSlot != INVALID_STORAGE_SLOT)
    {
        Storage_AddItem(nestedBagSlot, 23, 1, 200, 100.0, 0, 777001, "SERIAL_TEST_M4", m4ItemSlot, 999912, 0);
    }

    // Рекурсивный вес кармана должен составлять: 1500 г (рюкзак) + 5800 г (200 M4 внутри рюкзака) = 7300 г
    new const totalPocketWeightG = Storage_GetCurrentWeight(testPocketSlot);
    new const bool:recursiveWeightOk = (totalPocketWeightG == 7300);

    // Проверка отклонения переполнения багажника (лимит 10 000 г: пытаемся добавить канистру 16 000 г)
    new dummySlot = INVALID_STORAGE_ITEM_SLOT;
    new const E_STORAGE_RESULT:overflowRes = Storage_AddItem(testTrunkSlot, 48, 1, 0, 100.0, 0, 0, "", dummySlot, 999913, 0);
    new const bool:overflowRejectedOk = (overflowRes == STORAGE_RES_WEIGHT_EXCEEDED);

    // Тест 3 (DoD 2.4): Создание и удаление полевого контейнера WORLD_DROP со streamer-объектом
    new const dropSlot = Storage_CreateWorldDrop(1481.0, -1771.0, 18.8, 0, 0, 23, 60);
    new const bool:worldDropOk = (
        dropSlot != INVALID_STORAGE_SLOT &&
        sStorages[dropSlot][E_STORAGE_OBJECT_ID] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID &&
        sStorages[dropSlot][E_STORAGE_AREA_ID] != STREAMER_TAG_AREA:INVALID_STREAMER_ID
    );

    // Очистка тестовых хранилищ
    if (dropSlot != INVALID_STORAGE_SLOT)
    {
        Storage_Unload(dropSlot);
    }
    Storage_Unload(testPocketSlot);
    Storage_Unload(testTrunkSlot);

    printf("%s [Entities/Storage] Самопроверка: MutexLock=%s | Рекурсивный вес рюкзака (7300 г == %d г)=%s | Защита перегруза=%s | WorldDrop=%s.",
        SERVER_LOG_PREFIX,
        (firstLockOk && secondLockBlocked) ? ("ОК") : ("ОШИБКА"),
        totalPocketWeightG,
        recursiveWeightOk ? ("ОК") : ("ОШИБКА"),
        overflowRejectedOk ? ("ОК") : ("ОШИБКА"),
        worldDropOk ? ("ОК") : ("ОШИБКА"));
}

// =============================================================================
//  9. ФОНОВЫЕ ТАЙМЕРЫ СБОРЩИКА МУСОРА TTL И ТАЙМАУТОВ МЬЮТЕКСОВ (y_timers)
// =============================================================================

// Секундный контроль зависших мьютексов хранилищ
task Tick_StorageMutexWatchdog[1000]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }

    new const nowTick = GetTickCount();
    foreach (new slot : StorageIter)
    {
        if (sStorageMutex[slot] && ((nowTick - sStorageMutexTick[slot]) > STORAGE_MUTEX_TIMEOUT_MS))
        {
            sStorageMutex[slot] = false;
            sStorageMutexOwner[slot] = INVALID_PLAYER_ID;
            sStorageMutexTick[slot] = 0;
        }
    }
}

// Ежеминутный сборщик мусора (DoD 2.4): удаление просроченных WORLD_DROP и CORPSE_LOOT
task Tick_StorageGarbageCollector[60000]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }

    new const nowTs = gettime();
    new expiredSlots[64];
    new expiredCount = 0;

    foreach (new slot : StorageIter)
    {
        if (!sStorages[slot][E_STORAGE_VALID])
        {
            continue;
        }

        new const E_STORAGE_TYPE:kind = sStorages[slot][E_STORAGE_KIND];
        if (kind != STORAGE_WORLD_DROP && kind != STORAGE_CORPSE_LOOT)
        {
            continue;
        }

        if (sStorages[slot][E_STORAGE_EXPIRES_AT] > 0 &&
            sStorages[slot][E_STORAGE_EXPIRES_AT] <= nowTs &&
            !Storage_IsMutexLocked(slot))
        {
            if (expiredCount < sizeof(expiredSlots))
            {
                expiredSlots[expiredCount++] = slot;
            }
        }
    }

    for (new i = 0; i < expiredCount; i++)
    {
        Storage_DestroyExpiredOrEmpty(expiredSlots[i]);
    }

    if (expiredCount > 0)
    {
        printf("%s [Entities/Storage] Сборщик мусора очистил %d просроченных полевых контейнеров.",
            SERVER_LOG_PREFIX, expiredCount);
    }
}

// =============================================================================
//  10. СИСТЕМНЫЕ ХУКИ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    Iter_Init(StorageIter);
    Iter_Init(StorageItemIter);

    for (new i = 0; i < MAX_ACTIVE_STORAGES; i++)
    {
        Internal_ResetStorageSlot(i);
    }
    for (new j = 0; j < MAX_STORAGE_ITEMS; j++)
    {
        Internal_ResetStorageItemSlot(j);
    }

    new const loadedCount = Internal_LoadPersistentStoragesOnInitSync();
    printf("%s [Entities/Storage] Загружено %d постоянных хранилищ из БД.",
        SERVER_LOG_PREFIX, loadedCount);

    Internal_RunStorageSelfTests();
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    // При выходе или краше игрока немедленно освобождаем все удерживаемые им мьютексы хранилищ
    foreach (new slot : StorageIter)
    {
        if (sStorageMutexOwner[slot] == playerid || sStorages[slot][E_STORAGE_ACTIVE_VIEWER] == playerid)
        {
            sStorages[slot][E_STORAGE_ACTIVE_VIEWER] = INVALID_PLAYER_ID;
            Storage_ReleaseMutex(slot);
        }
    }
    return 1;
}

hook OnPlayerEnterDynamicArea(playerid, STREAMER_TAG_AREA:areaid)
{
    foreach (new slot : StorageIter)
    {
        if (sStorages[slot][E_STORAGE_VALID] && sStorages[slot][E_STORAGE_AREA_ID] == areaid)
        {
            if (sStorages[slot][E_STORAGE_KIND] == STORAGE_CORPSE_LOOT)
            {
                SendClientMessage(playerid, COLOR_UI_INFO,
                    "Рядом обнаружено тело погибшего. Нажмите клавишу [Y], чтобы осмотреть вещи.");
            }
            else if (sStorages[slot][E_STORAGE_KIND] == STORAGE_WORLD_DROP)
            {
                SendClientMessage(playerid, COLOR_UI_INFO,
                    "Рядом находятся выброшенные предметы. Нажмите клавишу [Y] для взаимодействия.");
            }
            break;
        }
    }
    return 1;
}

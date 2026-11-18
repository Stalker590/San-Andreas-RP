/*
 * =============================================================================
 *  SAN ANDREAS RP ó ”Ô‡‚ÎÂÌËÂ ÔÂ‰ÔËˇÚËˇÏË, Ï‡„‡ÁËÌ‡ÏË Ë ‡ÛÍˆËÓÌ‡ÏË
 *  ‘‡ÈÎ:      gamemodes/modules/systems/mod_economy.pwn
 *  œÛÌÍÚ:     ROADMAP [6.2] ó ”Ô‡‚ÎÂÌËÂ ÔÂ‰ÔËˇÚËˇÏË Ë ‡ÛÍˆËÓÌ‡ÏË (systems/mod_economy.pwn)
 *   Ó‰ËÓ‚Í‡: Windows-1251 (CP1251) ·ÂÁ BOM
 * =============================================================================
 */

#if defined _mod_economy_included
    #endinput
#endif
#define _mod_economy_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1.  ŒÕ—“¿Õ“€, ƒ»¿ÀŒ√» » Œ¡Ÿ»≈ »ƒ≈Õ“»‘» ¿“Œ–€ ÀŒ√»—“» »
// =============================================================================

#define MAX_MARKET_ORDERS                       (1024)
#define MAX_ECONOMY_DIALOG_ROWS                 (96)
#define ECONOMY_DIALOG_BUFFER_LEN               (24576)
#define ECONOMY_MENU_MAX_ACTIONS                (12)
#define ECONOMY_PANEL_RADIUS                    (15.0)
#define ECONOMY_TRADE_RADIUS                    (3.5)
#define ECONOMY_COMMAND_COOLDOWN_MS             (350)

#define LOGISTICS_DEST_ENTERPRISE               (1)
#define LOGISTICS_DEST_PORT                     (2)

#define DIALOG_ECONOMY_MENU                     (1310)
#define DIALOG_ECONOMY_INFO                     (1311)
#define DIALOG_ECONOMY_ITEM_SELECT              (1312)
#define DIALOG_ECONOMY_INPUT_PRICE              (1313)
#define DIALOG_ECONOMY_INPUT_TARGET             (1314)
#define DIALOG_ECONOMY_INPUT_AMOUNT             (1315)
#define DIALOG_ECONOMY_ORDERS                   (1316)
#define DIALOG_ECONOMY_MARKET                   (1317)
#define DIALOG_ECONOMY_AUCTION                  (1318)
#define DIALOG_ECONOMY_CONTRACT_DEST            (1319)
#define ECONOMY_CONTRACT_MAX_DESTS              (4)

#define TOTAL_BUILTIN_MARKET_ORDERS             (18)

// =============================================================================
//  2. —“–” “”–€ Œ–ƒ≈–Œ¬ » —Œ—“ŒﬂÕ»≈ ƒ»¿ÀŒ√Œ¬
// =============================================================================

enum E_MARKET_ORDER_TYPE
{
    MARKET_ORDER_BUY_RAW = 0,
    MARKET_ORDER_SELL_PRODUCT
};

enum E_MARKET_ORDER_DATA
{
    bool:E_ORDER_VALID,
    E_ORDER_DB_ID,
    E_ORDER_ENTERPRISE_ID,
    E_MARKET_ORDER_TYPE:E_ORDER_TYPE,
    E_ORDER_ITEM_DEF_ID,
    E_ORDER_PRICE_PER_UNIT_USD,
    E_ORDER_TARGET_AMOUNT,
    E_ORDER_FULFILLED_AMOUNT
};

enum E_ECONOMY_ACTION
{
    ECON_ACTION_NONE = 0,
    ECON_ACTION_INFO,
    ECON_ACTION_SET_BUY_ORDER,
    ECON_ACTION_SET_SELL_ORDER,
    ECON_ACTION_DEPOSIT,
    ECON_ACTION_WITHDRAW,
    ECON_ACTION_SET_WAGE,
    ECON_ACTION_MANAGE_ORDERS,
    ECON_ACTION_CREATE_CONTRACT,
    ECON_ACTION_WITHDRAW_GOODS,
    ECON_ACTION_MARKET_TRADE,
    ECON_ACTION_AUCTION
};

// =============================================================================
//  3. »Õ ¿œ—”À»–Œ¬¿ÕÕ€≈ œ”À€ » —Œ—“ŒﬂÕ»≈ »√–Œ Œ¬ (static stock)
// =============================================================================

static stock sMarketOrders[MAX_MARKET_ORDERS][E_MARKET_ORDER_DATA];
static stock Iterator:MarketOrderIter<MAX_MARKET_ORDERS>;
static stock sNextMarketOrderDbId = 1;

static stock sEconomyPendingEnterprise[MAX_PLAYERS];
static stock E_ECONOMY_ACTION:sEconomyPendingAction[MAX_PLAYERS];
static stock sEconomyPendingItem[MAX_PLAYERS];
static stock sEconomyPendingPrice[MAX_PLAYERS];
static stock sEconomyPendingOrderSlot[MAX_PLAYERS];
static stock sEconomyPendingAmount[MAX_PLAYERS];
static stock sEconomyContractDestType[MAX_PLAYERS][ECONOMY_CONTRACT_MAX_DESTS];
static stock sEconomyContractDestId[MAX_PLAYERS][ECONOMY_CONTRACT_MAX_DESTS];
static stock sEconomyContractDestCount[MAX_PLAYERS];
static stock sEconomyItemRowMap[MAX_PLAYERS][MAX_ECONOMY_DIALOG_ROWS];
static stock sEconomyOrderRowMap[MAX_PLAYERS][MAX_ECONOMY_DIALOG_ROWS];
static stock sEconomyRowCount[MAX_PLAYERS];
static stock E_ECONOMY_ACTION:sEconomyMenuAction[MAX_PLAYERS][ECONOMY_MENU_MAX_ACTIONS];
static stock sEconomyMenuActionCount[MAX_PLAYERS];
static stock sLastEconomyCommandTick[MAX_PLAYERS];
static stock sEconomyDialogBuffer[ECONOMY_DIALOG_BUFFER_LEN];

static stock const sBuiltinMarketOrders[TOTAL_BUILTIN_MARKET_ORDERS][E_MARKET_ORDER_DATA] =
{
    { true, 1, 5, MARKET_ORDER_BUY_RAW, 76, 20, 5000, 0 },
    { true, 2, 6, MARKET_ORDER_BUY_RAW, 77, 18, 5000, 0 },
    { true, 3, 6, MARKET_ORDER_BUY_RAW, 76, 20, 2000, 0 },
    { true, 4, 7, MARKET_ORDER_BUY_RAW, 82, 48, 3000, 0 },
    { true, 5, 7, MARKET_ORDER_BUY_RAW, 86, 36, 2000, 0 },
    { true, 6, 7, MARKET_ORDER_BUY_RAW, 88, 22, 2000, 0 },
    { true, 7, 11, MARKET_ORDER_BUY_RAW, 90, 28, 4000, 0 },
    { true, 8, 12, MARKET_ORDER_BUY_RAW, 90, 28, 4000, 0 },
    { true, 9, 13, MARKET_ORDER_BUY_RAW, 90, 28, 4000, 0 },
    { true, 10, 5, MARKET_ORDER_SELL_PRODUCT, 90, 32, 5000, 0 },
    { true, 11, 5, MARKET_ORDER_SELL_PRODUCT, 86, 40, 2000, 0 },
    { true, 12, 6, MARKET_ORDER_SELL_PRODUCT, 82, 52, 3000, 0 },
    { true, 13, 6, MARKET_ORDER_SELL_PRODUCT, 83, 30, 2000, 0 },
    { true, 14, 6, MARKET_ORDER_SELL_PRODUCT, 84, 24, 2000, 0 },
    { true, 15, 8, MARKET_ORDER_SELL_PRODUCT, 61, 15, 500, 0 },
    { true, 16, 8, MARKET_ORDER_SELL_PRODUCT, 63, 25, 500, 0 },
    { true, 17, 8, MARKET_ORDER_SELL_PRODUCT, 58, 30, 300, 0 },
    { true, 18, 8, MARKET_ORDER_SELL_PRODUCT, 41, 180, 100, 0 }
};

// ÃÓ‰ÛÎ¸ ÎÓ„ËÒÚËÍË ÔÓ‰ÍÎ˛˜‡ÂÚÒˇ ÔÓÁÊÂ: Ó·˙ˇ‚ÎˇÂÏ ÔÛ·ÎË˜Ì˚È API Á‡‡ÌÂÂ.
forward bool:Logistics_CreateContract(source_ent_id, dest_type, dest_id, item_def_id, amount, create_by_char_id);
forward Ports_FindBestExportPort(item_def_id);
forward Ports_GetBestSellPrice(item_def_id);
forward Ports_GetPortNameRu(port_id, output[], len = sizeof(output));
forward Ports_GetSellPrice(port_id, item_def_id);
forward Economy_FindBuyRawOrderForItem(item_def_id, exclude_enterprise_id = 0);
forward Economy_GetOrderCount();
forward Economy_GetBuyRawPrice(enterprise_id, item_def_id);
forward Economy_GetOrderPrice(order_slot);
forward Economy_GetOrderItem(order_slot);
forward Economy_GetOrderEnterprise(order_slot);

// =============================================================================
//  4. ¬Õ”“–≈ÕÕ»≈ ‘”Õ ÷»» «¿√–”« » Œ–ƒ≈–Œ¬ (static stock)
// =============================================================================

static stock Internal_ResetMarketOrder(order_slot)
{
    sMarketOrders[order_slot][E_ORDER_VALID] = false;
    sMarketOrders[order_slot][E_ORDER_DB_ID] = 0;
    sMarketOrders[order_slot][E_ORDER_ENTERPRISE_ID] = 0;
    sMarketOrders[order_slot][E_ORDER_TYPE] = MARKET_ORDER_BUY_RAW;
    sMarketOrders[order_slot][E_ORDER_ITEM_DEF_ID] = 0;
    sMarketOrders[order_slot][E_ORDER_PRICE_PER_UNIT_USD] = 0;
    sMarketOrders[order_slot][E_ORDER_TARGET_AMOUNT] = 0;
    sMarketOrders[order_slot][E_ORDER_FULFILLED_AMOUNT] = 0;
}

static stock Internal_AddMarketOrder(
    dbId,
    enterpriseId,
    E_MARKET_ORDER_TYPE:orderType,
    itemDefId,
    pricePerUnit,
    targetAmount,
    fulfilledAmount)
{
    if (!Enterprise_IsValid(enterpriseId))
    {
        return -1;
    }

    new const orderSlot = Iter_Free(MarketOrderIter);
    if (orderSlot == INVALID_ITERATOR_SLOT)
    {
        return -1;
    }

    Iter_Add(MarketOrderIter, orderSlot);
    Internal_ResetMarketOrder(orderSlot);

    sMarketOrders[orderSlot][E_ORDER_VALID] = true;
    sMarketOrders[orderSlot][E_ORDER_DB_ID] = dbId;
    sMarketOrders[orderSlot][E_ORDER_ENTERPRISE_ID] = enterpriseId;
    sMarketOrders[orderSlot][E_ORDER_TYPE] = orderType;
    sMarketOrders[orderSlot][E_ORDER_ITEM_DEF_ID] = itemDefId;
    sMarketOrders[orderSlot][E_ORDER_PRICE_PER_UNIT_USD] = pricePerUnit;
    sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT] = targetAmount;
    sMarketOrders[orderSlot][E_ORDER_FULFILLED_AMOUNT] = fulfilledAmount;

    if (dbId >= sNextMarketOrderDbId)
    {
        sNextMarketOrderDbId = dbId + 1;
    }
    return orderSlot;
}

static stock Internal_SeedBuiltinMarketOrders()
{
    for (new i = 0; i < MAX_MARKET_ORDERS; i++)
    {
        Internal_ResetMarketOrder(i);
    }
    Iter_Init(MarketOrderIter);
    sNextMarketOrderDbId = 1;

    for (new i = 0; i < TOTAL_BUILTIN_MARKET_ORDERS; i++)
    {
        new const enterpriseSlot = Enterprise_FindByDbId(
            sBuiltinMarketOrders[i][E_ORDER_ENTERPRISE_ID]);
        if (!Enterprise_IsValid(enterpriseSlot))
        {
            continue;
        }

        new const orderSlot = Internal_AddMarketOrder(
            sBuiltinMarketOrders[i][E_ORDER_DB_ID],
            enterpriseSlot,
            sBuiltinMarketOrders[i][E_ORDER_TYPE],
            sBuiltinMarketOrders[i][E_ORDER_ITEM_DEF_ID],
            sBuiltinMarketOrders[i][E_ORDER_PRICE_PER_UNIT_USD],
            sBuiltinMarketOrders[i][E_ORDER_TARGET_AMOUNT],
            sBuiltinMarketOrders[i][E_ORDER_FULFILLED_AMOUNT]);

        if (orderSlot < 0)
        {
            break;
        }
    }
}

static stock Internal_LoadMarketOrdersSync()
{
    for (new i = 0; i < MAX_MARKET_ORDERS; i++)
    {
        Internal_ResetMarketOrder(i);
    }
    Iter_Init(MarketOrderIter);
    sNextMarketOrderDbId = 1;

    if (!DB_IsConnected())
    {
        Internal_SeedBuiltinMarketOrders();
        printf("%s [Systems/Economy] MySQL is unavailable: the built-in order set (%d records) is loaded.",
            SERVER_LOG_PREFIX, TOTAL_BUILTIN_MARKET_ORDERS);
        return TOTAL_BUILTIN_MARKET_ORDERS;
    }

    // –‡ÁÂ¯ÂÌÌ˚È ÒËÌıÓÌÌ˚È Á‡ÔÓÒ ÒÚÓ„Ó ‚ÌÛÚË OnGameModeInit
    new const Cache:cache = mysql_query(gMySQL,
        "SELECT `id`, `enterprise_id`, `order_type`, `item_def_id`, `price_per_unit_usd`, `target_amount`, `fulfilled_amount` FROM `enterprise_market_orders` ORDER BY `id` ASC;",
        true);

    if (!cache_is_valid(cache))
    {
        Internal_SeedBuiltinMarketOrders();
        printf("%s [Systems/Economy] [WARN] Failed to read enterprise_market_orders: built-in set loaded.",
            SERVER_LOG_PREFIX);
        return TOTAL_BUILTIN_MARKET_ORDERS;
    }

    new rowCount = 0;
    cache_get_row_count(rowCount);
    new loadedOrders = 0;

    for (new row = 0; row < rowCount; row++)
    {
        new dbId, enterpriseId, itemDefId, price, target, fulfilled;
        new typeStr[20];

        cache_get_value_name_int(row, "id", dbId);
        cache_get_value_name_int(row, "enterprise_id", enterpriseId);
        cache_get_value_name(row, "order_type", typeStr, sizeof(typeStr));
        cache_get_value_name_int(row, "item_def_id", itemDefId);
        cache_get_value_name_int(row, "price_per_unit_usd", price);
        cache_get_value_name_int(row, "target_amount", target);
        cache_get_value_name_int(row, "fulfilled_amount", fulfilled);

        new const E_MARKET_ORDER_TYPE:orderType =
            (!strcmp(typeStr, "SELL_PRODUCT", true)) ? MARKET_ORDER_SELL_PRODUCT : MARKET_ORDER_BUY_RAW;

        new const enterpriseSlot = Enterprise_FindByDbId(enterpriseId);
        if (!Enterprise_IsValid(enterpriseSlot))
        {
            continue;
        }

        if (Internal_AddMarketOrder(dbId, enterpriseSlot, orderType, itemDefId, price, target, fulfilled) >= 0)
        {
            loadedOrders++;
        }
    }
    cache_delete(cache);

    printf("%s [Systems/Economy] Exchange orders loaded from MySQL (records: %d).",
        SERVER_LOG_PREFIX, loadedOrders);
    return loadedOrders;
}

// =============================================================================
//  5. ¬Õ”“–≈ÕÕ»≈ ¬—œŒÃŒ√¿“≈À‹Õ€≈ ‘”Õ ÷»» › ŒÕŒÃ» » (static stock)
// =============================================================================

static stock bool:Internal_ParsePositiveInt(const input[], &outValue)
{
    outValue = 0;
    new idx = 0;
    while (input[idx] == ' ' || input[idx] == '\t')
    {
        idx++;
    }
    if (input[idx] == '\0')
    {
        return false;
    }

    new foundDigit = 0;
    while (input[idx] >= '0' && input[idx] <= '9')
    {
        outValue = (outValue * 10) + (input[idx] - '0');
        if (outValue > 2000000000)
        {
            return false;
        }
        foundDigit = 1;
        idx++;
    }

    while (input[idx] == ' ' || input[idx] == '\t')
    {
        idx++;
    }
    return (foundDigit == 1 && input[idx] == '\0');
}

static stock Internal_DropCashToWorld(playerid, amountUsd)
{
    if (amountUsd <= 0)
    {
        return 0;
    }

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    new const dropSlot = Storage_CreateWorldDrop(
        x, y, z,
        GetPlayerInterior(playerid),
        GetPlayerVirtualWorld(playerid),
        ITEM_ID_CASH_BUNDLE);
    if (dropSlot == INVALID_STORAGE_SLOT)
    {
        return 0;
    }

    new remaining = amountUsd;
    while (remaining > 0)
    {
        new const chunk = (remaining > 10000) ? 10000 : remaining;
        new outItemSlot = INVALID_STORAGE_ITEM_SLOT;
        new const E_STORAGE_RESULT:result = Storage_AddItem(
            dropSlot,
            ITEM_ID_CASH_BUNDLE,
            chunk,
            0,
            100.0,
            CASH_FLAG_CLEAN,
            CURRENCY_USD,
            "",
            outItemSlot);
        if (result != STORAGE_RES_OK)
        {
            return 0;
        }
        remaining -= chunk;
    }

    SendClientMessage(playerid, COLOR_UI_WARNING,
        "The cash did not fit into inventory and was issued in a separate bundle on the ground.");
    return 1;
}

static stock Internal_MoveStorageItemToPlayer(
    playerid,
    source_slot,
    def_id,
    max_amount,
    &movedAmount)
{
    movedAmount = 0;
    if (!Storage_IsValidSlot(source_slot) || max_amount <= 0)
    {
        return 0;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        return 0;
    }

    new remaining = max_amount;
    new itemSlot = Storage_GetFirstItemSlot(source_slot);

    while (itemSlot != INVALID_STORAGE_ITEM_SLOT && remaining > 0)
    {
        new const nextItemSlot = Storage_GetNextItemSlot(itemSlot);
        if (Storage_GetItemDefId(itemSlot) == def_id)
        {
            new const itemAmount = Storage_GetItemAmount(itemSlot);
            new const takeAmount = (itemAmount < remaining) ? itemAmount : remaining;

            if (takeAmount > 0 &&
                Storage_TransferItem(
                    playerid,
                    source_slot,
                    itemSlot,
                    layer1Slot,
                    takeAmount,
                    Character_GetId(playerid)) == STORAGE_RES_OK)
            {
                remaining -= takeAmount;
            }
        }
        itemSlot = nextItemSlot;
    }

    movedAmount = max_amount - remaining;
    return movedAmount;
}

static stock Internal_MovePlayerItemToStorage(
    playerid,
    source_slot,
    target_slot,
    def_id,
    max_amount,
    depth = 0)
{
    if (!Storage_IsValidSlot(source_slot) || !Storage_IsValidSlot(target_slot) ||
        max_amount <= 0 || depth > MAX_NESTING_DEPTH)
    {
        return 0;
    }

    new remaining = max_amount;
    new itemSlot = Storage_GetFirstItemSlot(source_slot);

    while (itemSlot != INVALID_STORAGE_ITEM_SLOT && remaining > 0)
    {
        new const nextItemSlot = Storage_GetNextItemSlot(itemSlot);
        if (Storage_GetItemDefId(itemSlot) == def_id)
        {
            new const itemAmount = Storage_GetItemAmount(itemSlot);
            new const takeAmount = (itemAmount < remaining) ? itemAmount : remaining;

            if (takeAmount > 0 &&
                Storage_TransferItem(
                    playerid,
                    source_slot,
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
                new const nestedMoved = Internal_MovePlayerItemToStorage(
                    playerid,
                    nestedSlot,
                    target_slot,
                    def_id,
                    remaining,
                    depth + 1);
                if (nestedMoved > 0)
                {
                    remaining -= nestedMoved;
                }
            }
        }
        itemSlot = nextItemSlot;
    }

    return (max_amount - remaining);
}

static stock Internal_IsTradeableItem(def_id)
{
    if (!Item_IsValid(def_id) || def_id == ITEM_ID_CASH_BUNDLE)
    {
        return false;
    }

    switch (Item_GetCategory(def_id))
    {
        case ITEM_CAT_NONE, ITEM_CAT_DOCUMENT_CURRENCY:
        {
            return false;
        }
        case ITEM_CAT_RAW, ITEM_CAT_INTERMEDIATE, ITEM_CAT_MELEE, ITEM_CAT_FIREARM,
             ITEM_CAT_HEAVY_THROWABLE, ITEM_CAT_GEAR_ELECTRONICS, ITEM_CAT_MEDICAL_FOOD,
             ITEM_CAT_ILLEGAL:
        {
            return true;
        }
    }
    return false;
}

static stock Internal_GetCategoryTitleRu(E_ITEM_CATEGORY:category, output[], len = sizeof(output))
{
    switch (category)
    {
        case ITEM_CAT_RAW:              format(output, len, "Raw materials");
        case ITEM_CAT_INTERMEDIATE:     format(output, len, "Industry");
        case ITEM_CAT_MELEE:            format(output, len, "Melee");
        case ITEM_CAT_FIREARM:          format(output, len, "Weapons");
        case ITEM_CAT_HEAVY_THROWABLE:  format(output, len, "Heavy Ordnance");
        case ITEM_CAT_GEAR_ELECTRONICS: format(output, len, "Equipment");
        case ITEM_CAT_MEDICAL_FOOD:     format(output, len, "Medicine and food");
        case ITEM_CAT_ILLEGAL:          format(output, len, "Illegal goods");
        default:                        format(output, len, "Product");
    }
    return 1;
}

static stock Internal_CountActiveOrdersForEnterprise(enterpriseId)
{
    new count = 0;
    foreach (new orderSlot : MarketOrderIter)
    {
        if (sMarketOrders[orderSlot][E_ORDER_VALID] &&
            sMarketOrders[orderSlot][E_ORDER_ENTERPRISE_ID] == enterpriseId &&
            sMarketOrders[orderSlot][E_ORDER_FULFILLED_AMOUNT] < sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT])
        {
            count++;
        }
    }
    return count;
}

static stock Internal_AddOrderFulfilled(order_slot, deltaAmount)
{
    if (order_slot < 0 || order_slot >= MAX_MARKET_ORDERS ||
        !sMarketOrders[order_slot][E_ORDER_VALID] || deltaAmount <= 0)
    {
        return 0;
    }

    sMarketOrders[order_slot][E_ORDER_FULFILLED_AMOUNT] += deltaAmount;

    if (DB_IsConnected())
    {
        new query[192];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `enterprise_market_orders` SET `fulfilled_amount` = `fulfilled_amount` + %d WHERE `id` = %d;",
            deltaAmount,
            sMarketOrders[order_slot][E_ORDER_DB_ID]);
        mysql_tquery(gMySQL, query);
    }
    return 1;
}

static stock Internal_ShowEnterpriseInfo(playerid, enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Object not found.");
        return 0;
    }

    new name[64], typeTitle[32], ownerTitle[32];
    new body[1024];
    new warehouseSlot = Enterprise_GetWarehouseSlot(enterprise_id);

    Enterprise_GetName(enterprise_id, name);
    Enterprise_GetTypeTitleRu(Enterprise_GetType(enterprise_id), typeTitle, sizeof(typeTitle));
    Enterprise_GetOwnershipTitleRu(Enterprise_GetOwnership(enterprise_id), ownerTitle, sizeof(ownerTitle));

    new stockInfo[128];
    if (Storage_IsValidSlot(warehouseSlot))
    {
        new weightStr[32], volumeStr[32];
        Utils_FormatWeightGrams(Storage_GetCurrentWeight(warehouseSlot), weightStr);
        Utils_FormatVolumeMl(Storage_GetCurrentVolume(warehouseSlot), volumeStr);
        format(stockInfo, sizeof(stockInfo), "In stock: %s, %s", weightStr, volumeStr);
    }
    else
    {
        format(stockInfo, sizeof(stockInfo), "Warehouse temporarily unavailable");
    }

    format(body, sizeof(body),
        "Name: %s\nType: %s\nForm of ownership: %s\nWorking capital: $%d\nSalary per 1 kg of production: $%d\n%s\nActive orders: %d",
        name,
        typeTitle,
        ownerTitle,
        Enterprise_GetReserve(enterprise_id),
        Enterprise_GetWagePerKg(enterprise_id),
        stockInfo,
        Internal_CountActiveOrdersForEnterprise(enterprise_id));

    if (Enterprise_GetOwnership(enterprise_id) == ENTERPRISE_OWN_UNOWNED &&
        Enterprise_GetAuctionPrice(enterprise_id) > 0)
    {
        new auctionLine[96];
        format(auctionLine, sizeof(auctionLine), "\nAuction buyout price: $%d",
            Enterprise_GetAuctionPrice(enterprise_id));
        strcat(body, auctionLine, sizeof(body));
    }

    ShowPlayerDialog(playerid, DIALOG_ECONOMY_INFO, DIALOG_STYLE_MSGBOX, "Enterprise", body, "Understood", "");
    return 1;
}

static stock Internal_ShowEnterpriseMenu(playerid, enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return 0;
    }

    new name[64], menu[1024];
    Enterprise_GetName(enterprise_id, name);

    sEconomyPendingEnterprise[playerid] = enterprise_id;
    sEconomyMenuActionCount[playerid] = 0;
    menu[0] = '\0';

    format(menu, sizeof(menu),
        "%s\n%s\n",
        "Company information",
        "Open trading floor (orders)");

    sEconomyMenuAction[sEconomyMenuActionCount[playerid]++] = ECON_ACTION_INFO;
    sEconomyMenuAction[sEconomyMenuActionCount[playerid]++] = ECON_ACTION_MARKET_TRADE;

    if (Enterprise_IsOwnedByPlayer(playerid, enterprise_id))
    {
        strcat(menu, "Set the purchase price for raw materials\n", sizeof(menu));
        sEconomyMenuAction[sEconomyMenuActionCount[playerid]++] = ECON_ACTION_SET_BUY_ORDER;

        strcat(menu, "Set the selling price for products\n", sizeof(menu));
        sEconomyMenuAction[sEconomyMenuActionCount[playerid]++] = ECON_ACTION_SET_SELL_ORDER;

        strcat(menu, "Replenish working capital\n", sizeof(menu));
        sEconomyMenuAction[sEconomyMenuActionCount[playerid]++] = ECON_ACTION_DEPOSIT;

        strcat(menu, "Withdraw working capital\n", sizeof(menu));
        sEconomyMenuAction[sEconomyMenuActionCount[playerid]++] = ECON_ACTION_WITHDRAW;

        strcat(menu, "Set the salary for 1 kg of production\n", sizeof(menu));
        sEconomyMenuAction[sEconomyMenuActionCount[playerid]++] = ECON_ACTION_SET_WAGE;

        strcat(menu, "Order management\n", sizeof(menu));
        sEconomyMenuAction[sEconomyMenuActionCount[playerid]++] = ECON_ACTION_MANAGE_ORDERS;

        strcat(menu, "Create a freight contract\n", sizeof(menu));
        sEconomyMenuAction[sEconomyMenuActionCount[playerid]++] = ECON_ACTION_CREATE_CONTRACT;

        strcat(menu, "Take goods from warehouse\n", sizeof(menu));
        sEconomyMenuAction[sEconomyMenuActionCount[playerid]++] = ECON_ACTION_WITHDRAW_GOODS;
    }

    new title[96];
    format(title, sizeof(title), "Company: %s", name);
    ShowPlayerDialog(
        playerid,
        DIALOG_ECONOMY_MENU,
        DIALOG_STYLE_LIST,
        title,
        menu,
        "Select",
        "Close");
    return 1;
}

static stock Internal_ShowItemSelection(playerid, enterprise_id, E_ECONOMY_ACTION:action)
{
    new const bool:buyOrder = (action == ECON_ACTION_SET_BUY_ORDER);

    sEconomyDialogBuffer[0] = '\0';
    sEconomyRowCount[playerid] = 0;

    for (new defId = 1; defId < MAX_ITEM_DEFS; defId++)
    {
        if (!Item_IsValid(defId) || defId == ITEM_ID_CASH_BUNDLE)
        {
            continue;
        }

        new const E_ITEM_CATEGORY:category = Item_GetCategory(defId);
        if (buyOrder)
        {
            if (category != ITEM_CAT_RAW && category != ITEM_CAT_INTERMEDIATE)
            {
                continue;
            }
        }
        else
        {
            if (!Internal_IsTradeableItem(defId))
            {
                continue;
            }
        }

        if (sEconomyRowCount[playerid] >= MAX_ECONOMY_DIALOG_ROWS)
        {
            break;
        }

        if (action == ECON_ACTION_CREATE_CONTRACT || action == ECON_ACTION_WITHDRAW_GOODS)
        {
            new const warehouseSlot = Enterprise_GetWarehouseSlot(enterprise_id);
            if (!Storage_IsValidSlot(warehouseSlot) ||
                Storage_CountItemInTree(warehouseSlot, defId) <= 0)
            {
                continue;
            }
        }

        new itemName[64], categoryTitle[32], rowLine[128];
        Item_GetName(defId, itemName);
        Internal_GetCategoryTitleRu(category, categoryTitle, sizeof(categoryTitle));

        if (action == ECON_ACTION_CREATE_CONTRACT || action == ECON_ACTION_WITHDRAW_GOODS)
        {
            new const warehouseSlot = Enterprise_GetWarehouseSlot(enterprise_id);
            format(rowLine, sizeof(rowLine), "%s | %s | in stock: %d pcs.",
                itemName, categoryTitle, Storage_CountItemInTree(warehouseSlot, defId));
        }
        else
        {
            format(rowLine, sizeof(rowLine), "%s | %s", itemName, categoryTitle);
        }

        strcat(sEconomyDialogBuffer, rowLine, sizeof(sEconomyDialogBuffer));
        strcat(sEconomyDialogBuffer, "\n", sizeof(sEconomyDialogBuffer));
        sEconomyItemRowMap[playerid][sEconomyRowCount[playerid]++] = defId;
    }

    if (sEconomyRowCount[playerid] <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Business]: There are no products available for this action.");
        return 0;
    }

    sEconomyPendingEnterprise[playerid] = enterprise_id;
    sEconomyPendingAction[playerid] = action;

    new title[96];
    switch (action)
    {
        case ECON_ACTION_SET_BUY_ORDER:      format(title, sizeof(title), "Purchasing raw materials: select product");
        case ECON_ACTION_SET_SELL_ORDER:     format(title, sizeof(title), "Selling products: select a product");
        case ECON_ACTION_CREATE_CONTRACT:    format(title, sizeof(title), "Contract: select cargo from warehouse");
        case ECON_ACTION_WITHDRAW_GOODS:     format(title, sizeof(title), "Warehouse: select the item to receive");
        default:                             format(title, sizeof(title), "Select product");
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_ECONOMY_ITEM_SELECT,
        DIALOG_STYLE_LIST,
        title,
        sEconomyDialogBuffer,
        "Select",
        "Cancel");
    return 1;
}

static stock Internal_ShowOrdersManagement(playerid, enterprise_id)
{
    sEconomyDialogBuffer[0] = '\0';
    sEconomyRowCount[playerid] = 0;

    foreach (new orderSlot : MarketOrderIter)
    {
        if (!sMarketOrders[orderSlot][E_ORDER_VALID] ||
            sMarketOrders[orderSlot][E_ORDER_ENTERPRISE_ID] != enterprise_id)
        {
            continue;
        }
        if (sEconomyRowCount[playerid] >= MAX_ECONOMY_DIALOG_ROWS)
        {
            break;
        }

        new itemName[64], typeTitle[24], rowLine[160];
        Item_GetName(sMarketOrders[orderSlot][E_ORDER_ITEM_DEF_ID], itemName);
        if (sMarketOrders[orderSlot][E_ORDER_TYPE] == MARKET_ORDER_BUY_RAW)
        {
            format(typeTitle, sizeof(typeTitle), "PURCHASE");
        }
        else
        {
            format(typeTitle, sizeof(typeTitle), "SALE");
        }

        format(rowLine, sizeof(rowLine),
            "%s | %s | $%d/piece | %d/%d | [DELETE]",
            typeTitle,
            itemName,
            sMarketOrders[orderSlot][E_ORDER_PRICE_PER_UNIT_USD],
            sMarketOrders[orderSlot][E_ORDER_FULFILLED_AMOUNT],
            sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT]);

        strcat(sEconomyDialogBuffer, rowLine, sizeof(sEconomyDialogBuffer));
        strcat(sEconomyDialogBuffer, "\n", sizeof(sEconomyDialogBuffer));
        sEconomyOrderRowMap[playerid][sEconomyRowCount[playerid]++] = orderSlot;
    }

    if (sEconomyRowCount[playerid] <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Enterprise]: This enterprise has no orders.");
        return 0;
    }

    sEconomyPendingEnterprise[playerid] = enterprise_id;
    ShowPlayerDialog(
        playerid,
        DIALOG_ECONOMY_ORDERS,
        DIALOG_STYLE_LIST,
        "Order management",
        sEconomyDialogBuffer,
        "Delete",
        "Back");
    return 1;
}

static stock Internal_ShowMarket(playerid, enterprise_id)
{
    sEconomyDialogBuffer[0] = '\0';
    sEconomyRowCount[playerid] = 0;

    foreach (new orderSlot : MarketOrderIter)
    {
        if (!sMarketOrders[orderSlot][E_ORDER_VALID] ||
            sMarketOrders[orderSlot][E_ORDER_ENTERPRISE_ID] != enterprise_id)
        {
            continue;
        }
        if (sMarketOrders[orderSlot][E_ORDER_FULFILLED_AMOUNT] >= sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT])
        {
            continue;
        }
        if (sEconomyRowCount[playerid] >= MAX_ECONOMY_DIALOG_ROWS)
        {
            break;
        }

        new itemName[64], rowLine[192];
        Item_GetName(sMarketOrders[orderSlot][E_ORDER_ITEM_DEF_ID], itemName);

        if (sMarketOrders[orderSlot][E_ORDER_TYPE] == MARKET_ORDER_SELL_PRODUCT)
        {
            new const warehouseSlot = Enterprise_GetWarehouseSlot(enterprise_id);
            new stockAmount = 0;
            if (Storage_IsValidSlot(warehouseSlot))
            {
                stockAmount = Storage_CountItemInTree(
                    warehouseSlot, sMarketOrders[orderSlot][E_ORDER_ITEM_DEF_ID]);
            }
            format(rowLine, sizeof(rowLine),
                "[BUY] %s | $%d/piece | in stock: %d | left: %d",
                itemName,
                sMarketOrders[orderSlot][E_ORDER_PRICE_PER_UNIT_USD],
                stockAmount,
                sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT] -
                    sMarketOrders[orderSlot][E_ORDER_FULFILLED_AMOUNT]);
        }
        else
        {
            format(rowLine, sizeof(rowLine),
                "[SELL] %s | $%d/piece | needed: %d",
                itemName,
                sMarketOrders[orderSlot][E_ORDER_PRICE_PER_UNIT_USD],
                sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT] -
                    sMarketOrders[orderSlot][E_ORDER_FULFILLED_AMOUNT]);
        }

        strcat(sEconomyDialogBuffer, rowLine, sizeof(sEconomyDialogBuffer));
        strcat(sEconomyDialogBuffer, "\n", sizeof(sEconomyDialogBuffer));
        sEconomyOrderRowMap[playerid][sEconomyRowCount[playerid]++] = orderSlot;
    }

    if (sEconomyRowCount[playerid] <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Trading floor]: All orders are filled or missing.");
        return 0;
    }

    sEconomyPendingEnterprise[playerid] = enterprise_id;
    ShowPlayerDialog(
        playerid,
        DIALOG_ECONOMY_MARKET,
        DIALOG_STYLE_LIST,
        "Trading hall of the enterprise",
        sEconomyDialogBuffer,
        "Select",
        "Close");
    return 1;
}

static stock Internal_CreateOrUpdateOrder(
    playerid,
    enterprise_id,
    E_MARKET_ORDER_TYPE:orderType,
    itemDefId,
    pricePerUnit,
    targetAmount)
{
    if (!Enterprise_IsValid(enterprise_id) || !Item_IsValid(itemDefId) ||
        pricePerUnit <= 0 || targetAmount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Incorrect order parameters.");
        return 0;
    }

    // ≈ÒÎË Ú‡ÍÓÈ Ó‰Â ÛÊÂ ÂÒÚ¸ ó Ó·ÌÓ‚ÎˇÂÏ ˆÂÌÛ Ë ˆÂÎ¸
    foreach (new orderSlot : MarketOrderIter)
    {
        if (sMarketOrders[orderSlot][E_ORDER_VALID] &&
            sMarketOrders[orderSlot][E_ORDER_ENTERPRISE_ID] == enterprise_id &&
            sMarketOrders[orderSlot][E_ORDER_TYPE] == orderType &&
            sMarketOrders[orderSlot][E_ORDER_ITEM_DEF_ID] == itemDefId)
        {
            sMarketOrders[orderSlot][E_ORDER_PRICE_PER_UNIT_USD] = pricePerUnit;
            if (targetAmount > sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT])
            {
                sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT] = targetAmount;
            }

            if (DB_IsConnected())
            {
                new query[224];
                mysql_format(gMySQL, query, sizeof(query),
                    "UPDATE `enterprise_market_orders` SET `price_per_unit_usd` = %d, `target_amount` = %d WHERE `id` = %d;",
                    pricePerUnit,
                    sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT],
                    sMarketOrders[orderSlot][E_ORDER_DB_ID]);
                mysql_tquery(gMySQL, query);
            }

            new auditDetails[192];
            format(auditDetails, sizeof(auditDetails),
                "Order #%d updated: product %d, price $%d, target %d.",
                sMarketOrders[orderSlot][E_ORDER_DB_ID], itemDefId,
                pricePerUnit, sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT]);
            Audit_Log(
                Character_GetId(playerid),
                "ORDER_UPDATE",
                "ENTERPRISE",
                "MARKET_ORDER",
                itemDefId,
                sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT],
                auditDetails);

            SendClientMessage(playerid, COLOR_UI_SUCCESS, "[Enterprise]: Order updated.");
            return 1;
        }
    }

    new const dbId = sNextMarketOrderDbId;
    new const orderSlot = Internal_AddMarketOrder(
        dbId,
        enterprise_id,
        orderType,
        itemDefId,
        pricePerUnit,
        targetAmount,
        0);

    if (orderSlot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: The order pool is full.");
        return 0;
    }

    if (DB_IsConnected())
    {
        new query[320];
        mysql_format(gMySQL, query, sizeof(query),
            "INSERT INTO `enterprise_market_orders` (`id`, `enterprise_id`, `order_type`, `item_def_id`, `price_per_unit_usd`, `target_amount`, `fulfilled_amount`) VALUES (%d, %d, '%e', %d, %d, %d, 0);",
            dbId,
            Enterprise_GetDbId(enterprise_id),
            (orderType == MARKET_ORDER_BUY_RAW) ? ("BUY_RAW") : ("SELL_PRODUCT"),
            itemDefId,
            pricePerUnit,
            targetAmount);
        mysql_tquery(gMySQL, query);
    }

    new auditDetails[192];
    format(auditDetails, sizeof(auditDetails),
        "Order #%d was created: product %d, price $%d, target %d.",
        dbId, itemDefId, pricePerUnit, targetAmount);
    Audit_Log(
        Character_GetId(playerid),
        "ORDER_CREATE",
        "ENTERPRISE",
        "MARKET_ORDER",
        itemDefId,
        targetAmount,
        auditDetails);

    SendClientMessage(playerid, COLOR_UI_SUCCESS, "[Enterprise]: A new order has been created.");
    return 1;
}

static stock Internal_ExecuteMarketPurchase(playerid, order_slot, requestedAmount)
{
    if (order_slot < 0 || order_slot >= MAX_MARKET_ORDERS || !sMarketOrders[order_slot][E_ORDER_VALID])
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading floor]: Order not found.");
        return 0;
    }

    new const enterpriseId = sMarketOrders[order_slot][E_ORDER_ENTERPRISE_ID];
    new const itemDefId = sMarketOrders[order_slot][E_ORDER_ITEM_DEF_ID];
    if (sMarketOrders[order_slot][E_ORDER_TYPE] != MARKET_ORDER_SELL_PRODUCT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading Floor]: This order is not intended for the sale of goods.");
        return 0;
    }
    if (!Enterprise_IsPlayerNearWarehouse(playerid, enterpriseId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Shopping Hall]: Move close to the store's warehouse.");
        return 0;
    }

    new const warehouseSlot = Enterprise_GetWarehouseSlot(enterpriseId);
    if (!Storage_IsValidSlot(warehouseSlot) || !Storage_AreItemsReady(warehouseSlot))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Trading floor]: The warehouse is still loading. Repeat in a second.");
        return 0;
    }

    new amount = requestedAmount;
    new const remainingTarget = sMarketOrders[order_slot][E_ORDER_TARGET_AMOUNT] -
        sMarketOrders[order_slot][E_ORDER_FULFILLED_AMOUNT];
    if (amount > remainingTarget)
    {
        amount = remainingTarget;
    }

    new const stockAmount = Storage_CountItemInTree(warehouseSlot, itemDefId);
    if (amount > stockAmount)
    {
        amount = stockAmount;
    }
    if (amount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading area]: This item is out of stock.");
        return 0;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading Room]: Inventory unavailable.");
        return 0;
    }

    // Œ„‡ÌË˜ÂÌËÂ Ô‡ÚËË Ò‚Ó·Ó‰ÌÓÈ „ÛÁÓÔÓ‰˙ÂÏÌÓÒÚ¸˛ Ë Ó·˙ÂÏÓÏ ËÌ‚ÂÌÚ‡ˇ
    new const unitWeightG = Item_CalculateInstanceWeight(itemDefId, 1);
    new const unitVolumeMl = Item_CalculateInstanceVolume(itemDefId, 1);
    new const freeWeightG = Storage_GetMaxWeight(layer1Slot) - Storage_GetCurrentWeight(layer1Slot);
    new const freeVolumeMl = Storage_GetMaxVolume(layer1Slot) - Storage_GetCurrentVolume(layer1Slot);
    if (unitWeightG > 0)
    {
        new const fitByWeight = freeWeightG / unitWeightG;
        if (amount > fitByWeight)
        {
            amount = fitByWeight;
        }
    }
    if (unitVolumeMl > 0)
    {
        new const fitByVolume = freeVolumeMl / unitVolumeMl;
        if (amount > fitByVolume)
        {
            amount = fitByVolume;
        }
    }
    if (amount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Shopping area]: The product does not fit into inventory. Make room.");
        return 0;
    }

    new const pricePerUnit = sMarketOrders[order_slot][E_ORDER_PRICE_PER_UNIT_USD];
    if (pricePerUnit <= 0 || amount > (2000000000 / pricePerUnit))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading room]: The transaction amount is too large.");
        return 0;
    }
    new const totalCost = pricePerUnit * amount;
    if (Character_GetPhysicalCashUsd(playerid) < totalCost)
    {
        new msg[160];
        format(msg, sizeof(msg), "[Trading floor]: Not enough cash. Need $%d.", totalCost);
        SendClientMessage(playerid, COLOR_UI_ERROR, msg);
        return 0;
    }

    new itemName[64];
    Item_GetName(itemDefId, itemName);

    new const bool:cashRemoved = Character_RemovePhysicalCashUsd(playerid, totalCost);
    if (!cashRemoved)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading room]: Failed to write off cash.");
        return 0;
    }

    new movedAmount = 0;
    Internal_MoveStorageItemToPlayer(playerid, warehouseSlot, itemDefId, amount, movedAmount);

    if (movedAmount <= 0)
    {
        Character_AddPhysicalCashUsd(playerid, totalCost, CASH_FLAG_CLEAN);
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Trading floor]: Failed to issue goods (inventory is full). The money has been returned.");
        return 0;
    }

    if (movedAmount < amount)
    {
        new const refund = pricePerUnit * (amount - movedAmount);
        Character_AddPhysicalCashUsd(playerid, refund, CASH_FLAG_CLEAN);
    }

    new const actualCost = pricePerUnit * movedAmount;
    Enterprise_AddReserve(enterpriseId, actualCost);
    Internal_AddOrderFulfilled(order_slot, movedAmount);

    new msg[192];
    format(msg, sizeof(msg),
        "[Trading Room]: You bought %s (quantity: %d) for $%d.",
        itemName, movedAmount, actualCost);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new auditDetails[192];
    format(auditDetails, sizeof(auditDetails),
        "Purchase of product '%s' (quantity: %d) in the store of the company #%d for $%d.",
        itemName, movedAmount, Enterprise_GetDbId(enterpriseId), actualCost);
    Audit_Log(
        Character_GetId(playerid),
        "SHOP_PURCHASE",
        "ENTERPRISE_WAREHOUSE",
        "PLAYER_LAYER1",
        itemDefId,
        movedAmount,
        auditDetails);
    return 1;
}

static stock Internal_ExecuteMarketSale(playerid, order_slot, requestedAmount)
{
    if (order_slot < 0 || order_slot >= MAX_MARKET_ORDERS || !sMarketOrders[order_slot][E_ORDER_VALID])
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading floor]: Order not found.");
        return 0;
    }

    new const enterpriseId = sMarketOrders[order_slot][E_ORDER_ENTERPRISE_ID];
    new const itemDefId = sMarketOrders[order_slot][E_ORDER_ITEM_DEF_ID];
    if (sMarketOrders[order_slot][E_ORDER_TYPE] != MARKET_ORDER_BUY_RAW)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading Floor]: This order does not accept raw materials.");
        return 0;
    }
    if (!Enterprise_IsPlayerNearWarehouse(playerid, enterpriseId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading floor]: Come close to the enterprise warehouse.");
        return 0;
    }

    new const warehouseSlot = Enterprise_GetWarehouseSlot(enterpriseId);
    if (!Storage_IsValidSlot(warehouseSlot) || !Storage_AreItemsReady(warehouseSlot))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Trading floor]: The warehouse is still loading. Repeat in a second.");
        return 0;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading Room]: Inventory unavailable.");
        return 0;
    }

    new amount = requestedAmount;
    new const remainingTarget = sMarketOrders[order_slot][E_ORDER_TARGET_AMOUNT] -
        sMarketOrders[order_slot][E_ORDER_FULFILLED_AMOUNT];
    if (amount > remainingTarget)
    {
        amount = remainingTarget;
    }

    new const playerAmount = Storage_CountItemInTree(layer1Slot, itemDefId);
    if (amount > playerAmount)
    {
        amount = playerAmount;
    }
    if (amount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading room]: You do not have this product.");
        return 0;
    }

    new const pricePerUnit = sMarketOrders[order_slot][E_ORDER_PRICE_PER_UNIT_USD];
    if (pricePerUnit <= 0 || amount > (2000000000 / pricePerUnit))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading room]: The transaction amount is too large.");
        return 0;
    }
    new const payout = pricePerUnit * amount;
    if (Enterprise_GetReserve(enterpriseId) < payout)
    {
        new msg[160];
        format(msg, sizeof(msg),
            "[Trading floor]: There are not enough funds in the company's cash register. Need $%d, available $%d.",
            payout, Enterprise_GetReserve(enterpriseId));
        SendClientMessage(playerid, COLOR_UI_ERROR, msg);
        return 0;
    }

    new itemName[64];
    Item_GetName(itemDefId, itemName);

    new const movedAmount = Internal_MovePlayerItemToStorage(
        playerid, layer1Slot, warehouseSlot, itemDefId, amount, 0);

    if (movedAmount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading floor]: Failed to transfer the goods to the warehouse.");
        return 0;
    }

    new const actualPayout = pricePerUnit * movedAmount;
    if (!Character_AddPhysicalCashUsd(playerid, actualPayout, CASH_FLAG_CLEAN))
    {
        Internal_DropCashToWorld(playerid, actualPayout);
    }
    Enterprise_TakeReserve(enterpriseId, actualPayout);
    Internal_AddOrderFulfilled(order_slot, movedAmount);

    new msg[192];
    format(msg, sizeof(msg),
        "[Trading Room]: You sold %s (quantity: %d) for $%d.",
        itemName, movedAmount, actualPayout);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new auditDetails[192];
    format(auditDetails, sizeof(auditDetails),
        "Sale of raw materials '%s' (quantity: %d) to enterprise #%d for $%d.",
        itemName, movedAmount, Enterprise_GetDbId(enterpriseId), actualPayout);
    Audit_Log(
        Character_GetId(playerid),
        "ORDER_SELL",
        "PLAYER_LAYER1",
        "ENTERPRISE_WAREHOUSE",
        itemDefId,
        movedAmount,
        auditDetails);
    return 1;
}

static stock Internal_ExecuteAuctionBuyout(playerid, enterprise_id)
{
    if (!Enterprise_IsValid(enterprise_id))
    {
        return 0;
    }
    if (Enterprise_GetOwnership(enterprise_id) != ENTERPRISE_OWN_UNOWNED)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Auction]: The enterprise already has an owner.");
        return 0;
    }

    new const price = Enterprise_GetAuctionPrice(enterprise_id);
    if (price <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Auction]: The redemption price has not been set.");
        return 0;
    }
    if (Character_GetPhysicalCashUsd(playerid) < price)
    {
        new msg[160];
        format(msg, sizeof(msg), "[Auction]: Not enough cash. Requires $%d.", price);
        SendClientMessage(playerid, COLOR_UI_ERROR, msg);
        return 0;
    }
    if (!Character_RemovePhysicalCashUsd(playerid, price))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Auction]: Cash debit failed.");
        return 0;
    }

    if (!Enterprise_SetPrivateOwner(enterprise_id, Character_GetId(playerid)))
    {
        Character_AddPhysicalCashUsd(playerid, price, CASH_FLAG_CLEAN);
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Auction]: Property registration error. The money has been returned.");
        return 0;
    }

    if (DB_IsConnected())
    {
        new query[192];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `organizations` SET `bank_balance_usd` = `bank_balance_usd` + %d WHERE `id` = 1;",
            price);
        mysql_tquery(gMySQL, query);
    }

    new enterpriseName[64];
    Enterprise_GetName(enterprise_id, enterpriseName);

    new msg[192];
    format(msg, sizeof(msg),
        "[Auction]: Congratulations! You purchased the enterprise ì%sî for $%d.",
        enterpriseName, price);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new auditDetails[192];
    format(auditDetails, sizeof(auditDetails),
        "Auction purchase of the enterprise '%s' (#%d) for $%d in favor of the state treasury.",
        enterpriseName, Enterprise_GetDbId(enterprise_id), price);
    Audit_Log(
        Character_GetId(playerid),
        "AUCTION_BUY",
        "GOVERNMENT_TREASURY",
        "ENTERPRISE",
        0,
        price,
        auditDetails);
    return 1;
}

static stock Internal_CreateContractToDestination(
    playerid,
    enterprise_id,
    item_def_id,
    amount,
    dest_type,
    dest_id)
{
    if (!Enterprise_IsValid(enterprise_id) || !Enterprise_IsOwnedByPlayer(playerid, enterprise_id))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: You are not the owner of this business.");
        return 0;
    }
    if (!Item_IsValid(item_def_id) || amount <= 0 || amount > 100000)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Incorrect cargo for the contract.");
        return 0;
    }

    if (!Logistics_CreateContract(
            Enterprise_GetDbId(enterprise_id),
            dest_type,
            dest_id,
            item_def_id,
            amount,
            Character_GetId(playerid)))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Enterprise]: Failed to create contract (no cargo in warehouse or pool full).");
        return 0;
    }

    new itemName[64], destName[64], msg[192];
    Item_GetName(item_def_id, itemName);
    if (dest_type == LOGISTICS_DEST_PORT)
    {
        Ports_GetPortNameRu(dest_id, destName, sizeof(destName));
        format(msg, sizeof(msg),
            "[Enterprise]: Export contract created: %s (quantity: %d) -> %s.",
            itemName, amount, destName);
    }
    else
    {
        new const destEnterpriseSlot = Enterprise_FindByDbId(dest_id);
        if (Enterprise_IsValid(destEnterpriseSlot))
        {
            Enterprise_GetName(destEnterpriseSlot, destName);
        }
        else
        {
            format(destName, sizeof(destName), "Enterprise #%d", dest_id);
        }
        format(msg, sizeof(msg),
            "[Enterprise]: Contract created: %s (quantity: %d) -> %s.",
            itemName, amount, destName);
    }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    return 1;
}

static stock Internal_ShowContractDestinations(playerid, enterprise_id, item_def_id, amount)
{
    new const destEnterpriseSlot = Economy_FindBuyRawOrderForItem(item_def_id, enterprise_id);
    sEconomyContractDestCount[playerid] = 0;

    new rowLine[128];
    sEconomyDialogBuffer[0] = '\0';

    if (Enterprise_IsValid(destEnterpriseSlot))
    {
        new destName[64];
        Enterprise_GetName(destEnterpriseSlot, destName);
        sEconomyContractDestType[playerid][sEconomyContractDestCount[playerid]] = LOGISTICS_DEST_ENTERPRISE;
        sEconomyContractDestId[playerid][sEconomyContractDestCount[playerid]] = Enterprise_GetDbId(destEnterpriseSlot);
        format(rowLine, sizeof(rowLine), "Buying company: %s", destName);
        strcat(sEconomyDialogBuffer, rowLine, sizeof(sEconomyDialogBuffer));
        strcat(sEconomyDialogBuffer, "\n", sizeof(sEconomyDialogBuffer));
        sEconomyContractDestCount[playerid]++;
    }

    new portName[48];
    for (new portId = 1; portId <= 3; portId++)
    {
        if (Ports_GetSellPrice(portId, item_def_id) <= 0)
        {
            continue;
        }
        if (sEconomyContractDestCount[playerid] >= ECONOMY_CONTRACT_MAX_DESTS)
        {
            break;
        }

        Ports_GetPortNameRu(portId, portName, sizeof(portName));
        sEconomyContractDestType[playerid][sEconomyContractDestCount[playerid]] = LOGISTICS_DEST_PORT;
        sEconomyContractDestId[playerid][sEconomyContractDestCount[playerid]] = portId;
        format(rowLine, sizeof(rowLine), "Port: %s", portName);
        strcat(sEconomyDialogBuffer, rowLine, sizeof(sEconomyDialogBuffer));
        strcat(sEconomyDialogBuffer, "\n", sizeof(sEconomyDialogBuffer));
        sEconomyContractDestCount[playerid]++;
    }

    if (sEconomyContractDestCount[playerid] <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Enterprise]: There is no purchase order or port quotation for this product.");
        return 0;
    }

    sEconomyPendingEnterprise[playerid] = enterprise_id;
    sEconomyPendingItem[playerid] = item_def_id;
    sEconomyPendingAmount[playerid] = amount;

    if (sEconomyContractDestCount[playerid] == 1)
    {
        return Internal_CreateContractToDestination(
            playerid,
            enterprise_id,
            item_def_id,
            amount,
            sEconomyContractDestType[playerid][0],
            sEconomyContractDestId[playerid][0]);
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_ECONOMY_CONTRACT_DEST,
        DIALOG_STYLE_LIST,
        "Where to deliver the goods?",
        sEconomyDialogBuffer,
        "Create a contract",
        "Cancel");
    return 1;
}

static stock Internal_HandleInputAmount(playerid, amount)
{
    new const enterpriseId = sEconomyPendingEnterprise[playerid];
    if (!Enterprise_IsValid(enterpriseId))
    {
        return 0;
    }

    switch (sEconomyPendingAction[playerid])
    {
        case ECON_ACTION_DEPOSIT:
        {
            if (!Enterprise_IsOwnedByPlayer(playerid, enterpriseId))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: You are not the owner of this business.");
                return 0;
            }
            if (Character_GetPhysicalCashUsd(playerid) < amount)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: There is not enough cash to replenish the cash register.");
                return 0;
            }
            if (!Character_RemovePhysicalCashUsd(playerid, amount))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Cash debit failed.");
                return 0;
            }
            Enterprise_AddReserve(enterpriseId, amount);

            new msg[160];
            format(msg, sizeof(msg), "[Enterprise]: Working capital replenished by $%d. At the box office: $%d.",
                amount, Enterprise_GetReserve(enterpriseId));
            SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

            new auditDetails[160];
            format(auditDetails, sizeof(auditDetails),
                "Replenishment of working capital of the enterprise #%d by $%d.",
                Enterprise_GetDbId(enterpriseId), amount);
            Audit_Log(
                Character_GetId(playerid),
                "ENTERPRISE_DEPOSIT",
                "PLAYER_LAYER1",
                "ENTERPRISE_RESERVE",
                0,
                amount,
                auditDetails);
            return 1;
        }

        case ECON_ACTION_WITHDRAW:
        {
            if (!Enterprise_IsOwnedByPlayer(playerid, enterpriseId))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: You are not the owner of this business.");
                return 0;
            }
            if (Enterprise_GetReserve(enterpriseId) < amount)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: There are not enough funds in the cash register.");
                return 0;
            }
            if (!Character_AddPhysicalCashUsd(playerid, amount, CASH_FLAG_CLEAN))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "[Enterprise]: Cash is not placed in inventory. Withdraw a smaller amount.");
                return 0;
            }
            Enterprise_TakeReserve(enterpriseId, amount);

            new msg[160];
            format(msg, sizeof(msg), "[Enterprise]: You withdrew $%d from the cash register. Remaining: $%d.",
                amount, Enterprise_GetReserve(enterpriseId));
            SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

            new auditDetails[160];
            format(auditDetails, sizeof(auditDetails),
                "Withdrawal of $%d from the working capital of enterprise #%d.",
                amount, Enterprise_GetDbId(enterpriseId));
            Audit_Log(
                Character_GetId(playerid),
                "ENTERPRISE_WITHDRAW",
                "ENTERPRISE_RESERVE",
                "PLAYER_LAYER1",
                0,
                amount,
                auditDetails);
            return 1;
        }

        case ECON_ACTION_SET_WAGE:
        {
            if (!Enterprise_IsOwnedByPlayer(playerid, enterpriseId))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: You are not the owner of this business.");
                return 0;
            }
            Enterprise_SetWagePerKg(enterpriseId, amount);

            new msg[160];
            format(msg, sizeof(msg), "[Enterprise]: Salary for 1 kg of production is set: $%d.",
                Enterprise_GetWagePerKg(enterpriseId));
            SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

            new auditDetails[160];
            format(auditDetails, sizeof(auditDetails),
                "The salary per 1 kg at the enterprise #%d has been changed: $%d.",
                Enterprise_GetDbId(enterpriseId), Enterprise_GetWagePerKg(enterpriseId));
            Audit_Log(
                Character_GetId(playerid),
                "WAGE_CHANGE",
                "ENTERPRISE",
                "PAYROLL",
                0,
                Enterprise_GetWagePerKg(enterpriseId),
                auditDetails);
            return 1;
        }

        case ECON_ACTION_CREATE_CONTRACT:
        {
            if (!Enterprise_IsOwnedByPlayer(playerid, enterpriseId))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: You are not the owner of this business.");
                return 0;
            }
            new const itemDefId = sEconomyPendingItem[playerid];
            if (!Item_IsValid(itemDefId) || amount <= 0 || amount > 100000)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "[Enterprise]: Incorrect cargo for the contract (valid from 1 to 100,000 units).");
                return 0;
            }

            return Internal_ShowContractDestinations(playerid, enterpriseId, itemDefId, amount);
        }

        case ECON_ACTION_WITHDRAW_GOODS:
        {
            if (!Enterprise_IsOwnedByPlayer(playerid, enterpriseId))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: You are not the owner of this business.");
                return 0;
            }
            if (!Enterprise_IsPlayerNearWarehouse(playerid, enterpriseId))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Get close to the warehouse.");
                return 0;
            }
            new const itemDefId = sEconomyPendingItem[playerid];
            new const warehouseSlot = Enterprise_GetWarehouseSlot(enterpriseId);
            if (!Item_IsValid(itemDefId) || !Storage_IsValidSlot(warehouseSlot) ||
                !Storage_AreItemsReady(warehouseSlot))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Warehouse unavailable.");
                return 0;
            }

            new stockAmount = Storage_CountItemInTree(warehouseSlot, itemDefId);
            if (amount > stockAmount)
            {
                amount = stockAmount;
            }
            if (amount <= 0)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: This item is out of stock.");
                return 0;
            }

            new const layer1Slot = Character_GetLayer1Slot(playerid);
            if (!Storage_IsValidSlot(layer1Slot))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Inventory unavailable.");
                return 0;
            }

            new const unitWeightG = Item_CalculateInstanceWeight(itemDefId, 1);
            new const unitVolumeMl = Item_CalculateInstanceVolume(itemDefId, 1);
            new const freeWeightG = Storage_GetMaxWeight(layer1Slot) - Storage_GetCurrentWeight(layer1Slot);
            new const freeVolumeMl = Storage_GetMaxVolume(layer1Slot) - Storage_GetCurrentVolume(layer1Slot);
            if (unitWeightG > 0 && amount > (freeWeightG / unitWeightG))
            {
                amount = freeWeightG / unitWeightG;
            }
            if (unitVolumeMl > 0 && amount > (freeVolumeMl / unitVolumeMl))
            {
                amount = freeVolumeMl / unitVolumeMl;
            }
            if (amount <= 0)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "[Enterprise]: Item does not fit into inventory. Make room.");
                return 0;
            }

            new movedAmount = 0;
            Internal_MoveStorageItemToPlayer(playerid, warehouseSlot, itemDefId, amount, movedAmount);
            if (movedAmount <= 0)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Failed to receive goods from warehouse.");
                return 0;
            }

            new itemName[64], msg[192];
            Item_GetName(itemDefId, itemName);
            format(msg, sizeof(msg),
                "[Enterprise]: Received from warehouse: %s (Quantity: %d).",
                itemName, movedAmount);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

            new auditDetails[192];
            format(auditDetails, sizeof(auditDetails),
                "Receipt of goods '%s' (quantity: %d) from the warehouse of enterprise #%d by the owner.",
                itemName, movedAmount, Enterprise_GetDbId(enterpriseId));
            Audit_Log(
                Character_GetId(playerid),
                "ENTERPRISE_WITHDRAW_GOODS",
                "ENTERPRISE_WAREHOUSE",
                "PLAYER_LAYER1",
                itemDefId,
                movedAmount,
                auditDetails);
            return 1;
        }

        case ECON_ACTION_MARKET_TRADE:
        {
            new const orderSlot = sEconomyPendingOrderSlot[playerid];
            if (orderSlot < 0 || orderSlot >= MAX_MARKET_ORDERS)
            {
                return 0;
            }
            if (sMarketOrders[orderSlot][E_ORDER_TYPE] == MARKET_ORDER_SELL_PRODUCT)
            {
                return Internal_ExecuteMarketPurchase(playerid, orderSlot, amount);
            }
            return Internal_ExecuteMarketSale(playerid, orderSlot, amount);
        }
    }
    return 0;
}

static stock Internal_FinishOrderCreation(playerid, targetAmount)
{
    new const enterpriseId = sEconomyPendingEnterprise[playerid];
    new const itemDefId = sEconomyPendingItem[playerid];
    new const price = sEconomyPendingPrice[playerid];

    if (!Enterprise_IsValid(enterpriseId) || !Item_IsValid(itemDefId) ||
        price <= 0 || targetAmount <= 0 ||
        !Enterprise_IsOwnedByPlayer(playerid, enterpriseId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Incorrect order parameters or no owner rights.");
        return 0;
    }

    new const E_MARKET_ORDER_TYPE:orderType =
        (sEconomyPendingAction[playerid] == ECON_ACTION_SET_BUY_ORDER)
            ? MARKET_ORDER_BUY_RAW
            : MARKET_ORDER_SELL_PRODUCT;

    return Internal_CreateOrUpdateOrder(playerid, enterpriseId, orderType, itemDefId, price, targetAmount);
}

// =============================================================================
//  6. œ”¡À»◊Õ€… API Œ–ƒ≈–Œ¬ (Economy_*)
// =============================================================================

stock Economy_GetOrderCount()
{
    return Iter_Count(MarketOrderIter);
}

stock Economy_FindBuyRawOrderForItem(item_def_id, exclude_enterprise_id = 0)
{
    foreach (new orderSlot : MarketOrderIter)
    {
        if (!sMarketOrders[orderSlot][E_ORDER_VALID])
        {
            continue;
        }
        if (sMarketOrders[orderSlot][E_ORDER_TYPE] != MARKET_ORDER_BUY_RAW)
        {
            continue;
        }
        if (sMarketOrders[orderSlot][E_ORDER_ITEM_DEF_ID] != item_def_id)
        {
            continue;
        }
        if (sMarketOrders[orderSlot][E_ORDER_ENTERPRISE_ID] == exclude_enterprise_id)
        {
            continue;
        }
        if (sMarketOrders[orderSlot][E_ORDER_FULFILLED_AMOUNT] >= sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT])
        {
            continue;
        }
        return sMarketOrders[orderSlot][E_ORDER_ENTERPRISE_ID];
    }
    return INVALID_ENTERPRISE_ID;
}

stock Economy_GetBuyRawPrice(enterprise_id, item_def_id)
{
    foreach (new orderSlot : MarketOrderIter)
    {
        if (!sMarketOrders[orderSlot][E_ORDER_VALID])
        {
            continue;
        }
        if (sMarketOrders[orderSlot][E_ORDER_ENTERPRISE_ID] != enterprise_id ||
            sMarketOrders[orderSlot][E_ORDER_TYPE] != MARKET_ORDER_BUY_RAW ||
            sMarketOrders[orderSlot][E_ORDER_ITEM_DEF_ID] != item_def_id)
        {
            continue;
        }
        return sMarketOrders[orderSlot][E_ORDER_PRICE_PER_UNIT_USD];
    }
    return 0;
}

stock Economy_GetOrderPrice(order_slot)
{
    if (order_slot < 0 || order_slot >= MAX_MARKET_ORDERS || !sMarketOrders[order_slot][E_ORDER_VALID])
    {
        return 0;
    }
    return sMarketOrders[order_slot][E_ORDER_PRICE_PER_UNIT_USD];
}

stock Economy_GetOrderItem(order_slot)
{
    if (order_slot < 0 || order_slot >= MAX_MARKET_ORDERS || !sMarketOrders[order_slot][E_ORDER_VALID])
    {
        return 0;
    }
    return sMarketOrders[order_slot][E_ORDER_ITEM_DEF_ID];
}

stock Economy_GetOrderEnterprise(order_slot)
{
    if (order_slot < 0 || order_slot >= MAX_MARKET_ORDERS || !sMarketOrders[order_slot][E_ORDER_VALID])
    {
        return INVALID_ENTERPRISE_ID;
    }
    return sMarketOrders[order_slot][E_ORDER_ENTERPRISE_ID];
}

// =============================================================================
//  7.  ŒÃ¿Õƒ€ ”œ–¿¬À≈Õ»ﬂ » “Œ–√Œ¬À» (Pawn.CMD)
// =============================================================================

CMD:enterprise(playerid, params[])
{
    #pragma unused params

    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Your character has not yet been loaded.");
        return 1;
    }
    if (!Character_IsAlive(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: A dead character cannot run a business.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sLastEconomyCommandTick[playerid]) < ECONOMY_COMMAND_COOLDOWN_MS)
    {
        return 1;
    }
    sLastEconomyCommandTick[playerid] = nowTick;

    new const enterpriseId = Enterprise_FindNearest(playerid, ECONOMY_PANEL_RADIUS);
    if (enterpriseId == INVALID_ENTERPRISE_ID)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Enterprise]: Approach the enterprise building to open the control panel.");
        return 1;
    }

    Internal_ShowEnterpriseMenu(playerid, enterpriseId);
    return 1;
}
alias:enterprise("biz");

CMD:market(playerid, params[])
{
    #pragma unused params

    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading Room]: Your character has not yet been loaded.");
        return 1;
    }
    if (!Character_IsAlive(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading Hall]: A dead character cannot trade.");
        return 1;
    }

    new const enterpriseId = Enterprise_FindNearest(playerid, ECONOMY_TRADE_RADIUS);
    if (enterpriseId == INVALID_ENTERPRISE_ID)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Shopping Hall]: Move close to the warehouse of a store or business.");
        return 1;
    }

    Internal_ShowMarket(playerid, enterpriseId);
    return 1;
}

CMD:auction(playerid, params[])
{
    #pragma unused params

    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Auction]: Your character has not yet been uploaded.");
        return 1;
    }
    if (!Character_IsAlive(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Auction]: A dead character cannot participate in the auction.");
        return 1;
    }

    new const enterpriseId = Enterprise_FindNearest(playerid, ECONOMY_PANEL_RADIUS);
    if (enterpriseId == INVALID_ENTERPRISE_ID)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Auction]: Approach a business that is up for sale.");
        return 1;
    }

    if (Enterprise_GetOwnership(enterpriseId) != ENTERPRISE_OWN_UNOWNED)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Auction]: This business already has an owner.");
        return 1;
    }

    new const price = Enterprise_GetAuctionPrice(enterpriseId);
    if (price <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Auction]: This business is not up for auction.");
        return 1;
    }

    new enterpriseName[64], body[512];
    Enterprise_GetName(enterpriseId, enterpriseName);
    format(body, sizeof(body),
        "Enterprise: %s\nBuyout price: $%d\nYour cash: $%d\n\nConfirm your purchase. The funds will go to the state treasury.",
        enterpriseName,
        price,
        Character_GetPhysicalCashUsd(playerid));

    sEconomyPendingEnterprise[playerid] = enterpriseId;
    ShowPlayerDialog(
        playerid,
        DIALOG_ECONOMY_AUCTION,
        DIALOG_STYLE_MSGBOX,
        "Auction of enterprises",
        body,
        "Redeem",
        "Cancel");
    return 1;
}

// =============================================================================
//  8. Œ¡–¿¡Œ“ ¿ ƒ»¿ÀŒ√Œ¬ › ŒÕŒÃ» »
// =============================================================================

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid >= DIALOG_ECONOMY_MENU && dialogid <= DIALOG_ECONOMY_CONTRACT_DEST &&
        !Character_IsAlive(playerid))
    {
        return Y_HOOKS_BREAK_RETURN_1;
    }

    switch (dialogid)
    {
        case DIALOG_ECONOMY_MENU:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sEconomyMenuActionCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const E_ECONOMY_ACTION:action = sEconomyMenuAction[playerid][listitem];
            new const enterpriseId = sEconomyPendingEnterprise[playerid];
            if (!Enterprise_IsValid(enterpriseId))
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            switch (action)
            {
                case ECON_ACTION_INFO:
                {
                    Internal_ShowEnterpriseInfo(playerid, enterpriseId);
                }
                case ECON_ACTION_MARKET_TRADE:
                {
                    if (!Enterprise_IsPlayerNearWarehouse(playerid, enterpriseId))
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR,
                            "[Trading floor]: Come close to the enterprise warehouse.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    Internal_ShowMarket(playerid, enterpriseId);
                }
                case ECON_ACTION_SET_BUY_ORDER, ECON_ACTION_SET_SELL_ORDER, ECON_ACTION_CREATE_CONTRACT, ECON_ACTION_WITHDRAW_GOODS:
                {
                    if (!Enterprise_IsOwnedByPlayer(playerid, enterpriseId))
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: You are not the owner of this business.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    if (action == ECON_ACTION_WITHDRAW_GOODS &&
                        !Enterprise_IsPlayerNearWarehouse(playerid, enterpriseId))
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR,
                            "[Enterprise]: Move close to the warehouse to pick up the goods.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    Internal_ShowItemSelection(playerid, enterpriseId, action);
                }
                case ECON_ACTION_DEPOSIT, ECON_ACTION_WITHDRAW, ECON_ACTION_SET_WAGE:
                {
                    if (!Enterprise_IsOwnedByPlayer(playerid, enterpriseId))
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: You are not the owner of this business.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    sEconomyPendingAction[playerid] = action;

                    new title[96];
                    if (action == ECON_ACTION_DEPOSIT)
                    {
                        format(title, sizeof(title), "Replenishment of the cash register. Enter amount in USD");
                    }
                    else if (action == ECON_ACTION_WITHDRAW)
                    {
                        format(title, sizeof(title), "Withdrawal from the cash register. Enter amount in USD");
                    }
                    else
                    {
                        format(title, sizeof(title), "Salary for 1 kg of production. Enter amount in USD");
                    }

                    ShowPlayerDialog(
                        playerid,
                        DIALOG_ECONOMY_INPUT_AMOUNT,
                        DIALOG_STYLE_INPUT,
                        title,
                        "Enter a positive integer:",
                        "Confirm",
                        "Cancel");
                }
                case ECON_ACTION_MANAGE_ORDERS:
                {
                    if (!Enterprise_IsOwnedByPlayer(playerid, enterpriseId))
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: You are not the owner of this business.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    Internal_ShowOrdersManagement(playerid, enterpriseId);
                }
                case ECON_ACTION_NONE, ECON_ACTION_AUCTION:
                {
                    return Y_HOOKS_BREAK_RETURN_1;
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ECONOMY_ITEM_SELECT:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sEconomyRowCount[playerid])
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Incorrect product selection.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const enterpriseId = sEconomyPendingEnterprise[playerid];
            if (!Enterprise_IsValid(enterpriseId) || !Enterprise_IsOwnedByPlayer(playerid, enterpriseId))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: You are not the owner of this business.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const itemDefId = sEconomyItemRowMap[playerid][listitem];
            if (!Item_IsValid(itemDefId))
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            sEconomyPendingItem[playerid] = itemDefId;

            if (sEconomyPendingAction[playerid] == ECON_ACTION_CREATE_CONTRACT)
            {
                ShowPlayerDialog(
                    playerid,
                    DIALOG_ECONOMY_INPUT_AMOUNT,
                    DIALOG_STYLE_INPUT,
                    "Contract of carriage",
                    "Enter the number of cargo units to be transported:",
                    "Next",
                    "Cancel");
            }
            else if (sEconomyPendingAction[playerid] == ECON_ACTION_WITHDRAW_GOODS)
            {
                ShowPlayerDialog(
                    playerid,
                    DIALOG_ECONOMY_INPUT_AMOUNT,
                    DIALOG_STYLE_INPUT,
                    "Receiving goods from the warehouse",
                    "Enter the number of product units:",
                    "Get",
                    "Cancel");
            }
            else
            {
                new itemName[64], title[128];
                Item_GetName(itemDefId, itemName);
                format(title, sizeof(title), "%s: unit price", itemName);
                ShowPlayerDialog(
                    playerid,
                    DIALOG_ECONOMY_INPUT_PRICE,
                    DIALOG_STYLE_INPUT,
                    title,
                    "Enter the price per unit in USD:",
                    "Next",
                    "Cancel");
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ECONOMY_INPUT_PRICE:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new price = 0;
            if (!Internal_ParsePositiveInt(inputtext, price) || price <= 0 || price > 1000000)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Price must be an integer between 1 and 1,000,000.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            sEconomyPendingPrice[playerid] = price;
            ShowPlayerDialog(
                playerid,
                DIALOG_ECONOMY_INPUT_TARGET,
                DIALOG_STYLE_INPUT,
                "Target quantity",
                "Enter how many units of the product you want to buy or sell:",
                "Create order",
                "Cancel");
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ECONOMY_INPUT_TARGET:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new target = 0;
            if (!Internal_ParsePositiveInt(inputtext, target) || target <= 0 || target > 1000000)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Quantity must be between 1 and 1,000,000.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            Internal_FinishOrderCreation(playerid, target);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ECONOMY_INPUT_AMOUNT:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new amount = 0;
            if (!Internal_ParsePositiveInt(inputtext, amount) || amount <= 0)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: Enter a positive integer.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            Internal_HandleInputAmount(playerid, amount);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ECONOMY_ORDERS:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sEconomyRowCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const enterpriseId = sEconomyPendingEnterprise[playerid];
            if (!Enterprise_IsValid(enterpriseId) || !Enterprise_IsOwnedByPlayer(playerid, enterpriseId))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: You are not the owner of this business.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const orderSlot = sEconomyOrderRowMap[playerid][listitem];
            if (orderSlot < 0 || orderSlot >= MAX_MARKET_ORDERS || !sMarketOrders[orderSlot][E_ORDER_VALID])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (sMarketOrders[orderSlot][E_ORDER_ENTERPRISE_ID] != enterpriseId)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Enterprise]: This order belongs to another enterprise.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            if (DB_IsConnected())
            {
                new query[128];
                mysql_format(gMySQL, query, sizeof(query),
                    "DELETE FROM `enterprise_market_orders` WHERE `id` = %d;",
                    sMarketOrders[orderSlot][E_ORDER_DB_ID]);
                mysql_tquery(gMySQL, query);
            }

            new auditDetails[160];
            format(auditDetails, sizeof(auditDetails),
                "Order #%d of enterprise #%d has been removed.",
                sMarketOrders[orderSlot][E_ORDER_DB_ID],
                Enterprise_GetDbId(enterpriseId));
            Audit_Log(
                Character_GetId(playerid),
                "ORDER_DELETE",
                "MARKET_ORDER",
                "ENTERPRISE",
                sMarketOrders[orderSlot][E_ORDER_ITEM_DEF_ID],
                sMarketOrders[orderSlot][E_ORDER_TARGET_AMOUNT],
                auditDetails);

            Iter_Remove(MarketOrderIter, orderSlot);
            Internal_ResetMarketOrder(orderSlot);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "[Enterprise]: The order has been deleted.");
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ECONOMY_MARKET:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sEconomyRowCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const enterpriseId = sEconomyPendingEnterprise[playerid];
            new const orderSlot = sEconomyOrderRowMap[playerid][listitem];
            if (!Enterprise_IsValid(enterpriseId) ||
                orderSlot < 0 || orderSlot >= MAX_MARKET_ORDERS ||
                !sMarketOrders[orderSlot][E_ORDER_VALID] ||
                sMarketOrders[orderSlot][E_ORDER_ENTERPRISE_ID] != enterpriseId)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (!Enterprise_IsPlayerNearWarehouse(playerid, enterpriseId))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Trading floor]: You are too far from the warehouse.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            sEconomyPendingAction[playerid] = ECON_ACTION_MARKET_TRADE;
            sEconomyPendingOrderSlot[playerid] = orderSlot;

            new itemName[64], body[256];
            Item_GetName(sMarketOrders[orderSlot][E_ORDER_ITEM_DEF_ID], itemName);
            format(body, sizeof(body),
                "Product: %s\nPrice: $%d per unit\nEnter quantity:",
                itemName,
                sMarketOrders[orderSlot][E_ORDER_PRICE_PER_UNIT_USD]);

            ShowPlayerDialog(
                playerid,
                DIALOG_ECONOMY_INPUT_AMOUNT,
                DIALOG_STYLE_INPUT,
                "Trading room",
                body,
                "Confirm",
                "Cancel");
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ECONOMY_CONTRACT_DEST:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sEconomyContractDestCount[playerid] ||
                listitem >= ECONOMY_CONTRACT_MAX_DESTS)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const enterpriseId = sEconomyPendingEnterprise[playerid];
            if (!Enterprise_IsValid(enterpriseId) || !Enterprise_IsOwnedByPlayer(playerid, enterpriseId))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Business]: You are not the owner of this business.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            Internal_CreateContractToDestination(
                playerid,
                enterpriseId,
                sEconomyPendingItem[playerid],
                sEconomyPendingAmount[playerid],
                sEconomyContractDestType[playerid][listitem],
                sEconomyContractDestId[playerid][listitem]);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_ECONOMY_AUCTION:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (!Enterprise_IsValid(sEconomyPendingEnterprise[playerid]))
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ExecuteAuctionBuyout(playerid, sEconomyPendingEnterprise[playerid]);
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_0;
}

// =============================================================================
//  9. —»—“≈ÃÕ€≈ ’” » (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    new const loadedOrders = Internal_LoadMarketOrdersSync();

    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        sEconomyPendingEnterprise[i] = INVALID_ENTERPRISE_ID;
        sEconomyPendingAction[i] = ECON_ACTION_NONE;
        sEconomyPendingItem[i] = 0;
        sEconomyPendingPrice[i] = 0;
        sEconomyPendingOrderSlot[i] = -1;
        sEconomyPendingAmount[i] = 0;
        sEconomyContractDestCount[i] = 0;
        sEconomyRowCount[i] = 0;
        sEconomyMenuActionCount[i] = 0;
        sLastEconomyCommandTick[i] = 0;
    }

    printf("%s [Systems/Economy] Economy module launched (orders: %d).",
        SERVER_LOG_PREFIX, loadedOrders);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason

    sEconomyPendingEnterprise[playerid] = INVALID_ENTERPRISE_ID;
    sEconomyPendingAction[playerid] = ECON_ACTION_NONE;
    sEconomyPendingItem[playerid] = 0;
    sEconomyPendingPrice[playerid] = 0;
    sEconomyPendingOrderSlot[playerid] = -1;
    sEconomyPendingAmount[playerid] = 0;
    sEconomyContractDestCount[playerid] = 0;
    sEconomyRowCount[playerid] = 0;
    sEconomyMenuActionCount[playerid] = 0;
    sLastEconomyCommandTick[playerid] = 0;
    return 1;
}

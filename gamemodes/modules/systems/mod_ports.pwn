/*
 * =============================================================================
 *  SAN ANDREAS RP — Глобальные торговые хабы и порты LS / SF / LV
 *  Файл:      gamemodes/modules/systems/mod_ports.pwn
 *  Пункт:     ROADMAP [6.3] — Глобальные торговые хабы и порты (systems/mod_ports.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_ports_included
    #endinput
#endif
#define _mod_ports_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ, ПОРТЫ И ДИАЛОГИ
// =============================================================================

#define MAX_PORT_TERMINALS                      (3)
#define MAX_PORT_QUOTES                         (MAX_PORT_TERMINALS * MAX_ITEM_DEFS)
#define MAX_PORT_DIALOG_ROWS                    (96)
#define PORT_DIALOG_BUFFER_LEN                  (8192)
#define PORT_INTERACT_RADIUS                    (25.0)
#define PORT_COMMAND_COOLDOWN_MS                (400)
#define PORT_LABEL_DRAW_DISTANCE                (60.0)
#define PORT_LABEL_STREAM_DISTANCE              (180.0)

#define PORT_SPREAD_MIN_PERCENT                 (0.12)
#define PORT_PRICE_CLAMP_MIN                    (0.35)
#define PORT_PRICE_CLAMP_MAX                    (3.00)
#define PORT_EXPORT_OWNER_PERCENT               (90)
#define PORT_EXPORT_TRUCKER_PERCENT             (5)
#define PORT_TRUCKER_PERK_BONUS_PERCENT         (20)
#define PORT_AUTHORITY_ORG_ID                   (14)
#define PORT_GOVERNMENT_ORG_ID                  (1)

#define TOTAL_BUILTIN_PORT_QUOTES               (54)

#define DIALOG_PORT_MENU                        (1330)
#define DIALOG_PORT_QUOTES                      (1331)
#define DIALOG_PORT_IMPORT_ITEM                 (1332)
#define DIALOG_PORT_IMPORT_AMOUNT               (1333)

// =============================================================================
//  2. СТРУКТУРЫ КОТИРОВОК И СОСТОЯНИЕ ДИАЛОГОВ
// =============================================================================

enum E_PORT_QUOTE_DATA
{
    bool:E_QUOTE_VALID,
    E_QUOTE_PORT_ID,
    E_QUOTE_ITEM_DEF_ID,
    E_QUOTE_REF_PRICE_USD,
    E_QUOTE_CURRENT_STOCK,
    E_QUOTE_TARGET_STOCK,
    Float:E_QUOTE_SPREAD,
    E_QUOTE_BUY_PRICE_USD,
    E_QUOTE_SELL_PRICE_USD
};

// =============================================================================
//  3. ИНКАПСУЛИРОВАННЫЕ ПУЛЫ И СТАТИЧЕСКИЕ ТЕРМИНАЛЫ (static stock)
// =============================================================================

static stock sPortQuotes[MAX_PORT_QUOTES][E_PORT_QUOTE_DATA];
static stock Iterator:PortQuoteIter<MAX_PORT_QUOTES>;

static stock sPortDialogItemMap[MAX_PLAYERS][MAX_PORT_DIALOG_ROWS];
static stock sPortDialogRowCount[MAX_PLAYERS];
static stock sPortPendingPort[MAX_PLAYERS];
static stock sPortPendingItem[MAX_PLAYERS];
static stock sLastPortCommandTick[MAX_PLAYERS];
static stock STREAMER_TAG_3D_TEXT_LABEL:sPortLabel[MAX_PORT_TERMINALS];
static stock sPortDialogBuffer[PORT_DIALOG_BUFFER_LEN];

static stock const Float:sPortPositions[MAX_PORT_TERMINALS][3] =
{
    { 2746.1, -2437.2, 13.6 }, // Порт Лос-Сантоса (Ocean Docks)
    { -1510.0, 490.0, 7.1 },   // Порт Сан-Фиерро (Easter Basin)
    { 2115.2, 920.1, 10.8 }    // Железнодорожный хаб Лас-Вентураса
};

static stock const sBuiltinPortQuotes[TOTAL_BUILTIN_PORT_QUOTES][E_PORT_QUOTE_DATA] =
{
    { true, 1, 76, 22, 12000, 10000, 0.12 },
    { true, 1, 77, 20, 10000, 10000, 0.12 },
    { true, 1, 78, 16, 10000, 10000, 0.12 },
    { true, 1, 79, 8, 15000, 15000, 0.12 },
    { true, 1, 80, 14, 12000, 10000, 0.12 },
    { true, 1, 81, 45, 6000, 8000, 0.12 },
    { true, 1, 82, 55, 8000, 10000, 0.12 },
    { true, 1, 83, 32, 6000, 6000, 0.12 },
    { true, 1, 84, 26, 6000, 6000, 0.12 },
    { true, 1, 85, 12, 10000, 10000, 0.12 },
    { true, 1, 86, 42, 9000, 10000, 0.12 },
    { true, 1, 87, 68, 4000, 5000, 0.12 },
    { true, 1, 88, 25, 8000, 8000, 0.12 },
    { true, 1, 89, 28, 7500, 8000, 0.12 },
    { true, 1, 90, 34, 15000, 15000, 0.12 },
    { true, 1, 48, 650, 1000, 1000, 0.12 },
    { true, 1, 56, 120, 2000, 2000, 0.12 },
    { true, 1, 62, 45, 5000, 5000, 0.12 },
    { true, 2, 76, 24, 9000, 10000, 0.12 },
    { true, 2, 77, 19, 11000, 10000, 0.12 },
    { true, 2, 78, 15, 12000, 10000, 0.12 },
    { true, 2, 79, 8, 15000, 15000, 0.12 },
    { true, 2, 80, 16, 9000, 10000, 0.12 },
    { true, 2, 81, 40, 9000, 8000, 0.12 },
    { true, 2, 82, 54, 10000, 10000, 0.12 },
    { true, 2, 83, 30, 7000, 6000, 0.12 },
    { true, 2, 84, 24, 7500, 6000, 0.12 },
    { true, 2, 85, 12, 10000, 10000, 0.12 },
    { true, 2, 86, 38, 11000, 10000, 0.12 },
    { true, 2, 87, 65, 5000, 5000, 0.12 },
    { true, 2, 88, 24, 9000, 8000, 0.12 },
    { true, 2, 89, 26, 9000, 8000, 0.12 },
    { true, 2, 90, 36, 13000, 15000, 0.12 },
    { true, 2, 50, 280, 1500, 1500, 0.12 },
    { true, 2, 53, 220, 1500, 1500, 0.12 },
    { true, 2, 55, 340, 800, 1000, 0.12 },
    { true, 3, 76, 20, 14000, 10000, 0.12 },
    { true, 3, 77, 18, 14000, 10000, 0.12 },
    { true, 3, 78, 19, 7000, 10000, 0.12 },
    { true, 3, 79, 10, 10000, 15000, 0.12 },
    { true, 3, 80, 17, 8000, 10000, 0.12 },
    { true, 3, 81, 44, 7000, 8000, 0.12 },
    { true, 3, 82, 58, 7500, 10000, 0.12 },
    { true, 3, 83, 34, 5500, 6000, 0.12 },
    { true, 3, 84, 28, 5500, 6000, 0.12 },
    { true, 3, 85, 13, 9000, 10000, 0.12 },
    { true, 3, 86, 40, 10000, 10000, 0.12 },
    { true, 3, 87, 70, 4500, 5000, 0.12 },
    { true, 3, 88, 28, 6500, 8000, 0.12 },
    { true, 3, 89, 30, 7000, 8000, 0.12 },
    { true, 3, 90, 32, 16000, 15000, 0.12 },
    { true, 3, 46, 260, 1200, 1200, 0.12 },
    { true, 3, 54, 150, 1500, 1500, 0.12 },
    { true, 3, 64, 40, 3000, 3000, 0.12 }
};

// Модуль логистики подключается позже: объявляем публичный API заранее.
forward Logistics_UnloadAtPort(playerid, port_id);

// =============================================================================
//  4. ВНУТРЕННИЕ ФУНКЦИИ ПОРТОВ И КОТИРОВОК (static stock)
// =============================================================================

stock Ports_GetPortNameRu(port_id, output[], len = sizeof(output))
{
    switch (port_id)
    {
        case 1: format(output, len, "Port of Los Santos");
        case 2: format(output, len, "Port of San Fierro");
        case 3: format(output, len, "Las Venturas Freight Hub");
        default: format(output, len, "Commercial port");
    }
    return 1;
}

stock bool:Ports_GetPortPos(port_id, &Float:x, &Float:y, &Float:z)
{
    x = 0.0;
    y = 0.0;
    z = 0.0;
    if (port_id < 1 || port_id > MAX_PORT_TERMINALS)
    {
        return false;
    }
    x = sPortPositions[port_id - 1][0];
    y = sPortPositions[port_id - 1][1];
    z = sPortPositions[port_id - 1][2];
    return true;
}

stock Ports_FindNearestPort(playerid, Float:radius)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !IsPlayerConnected(playerid))
    {
        return 0;
    }
    if (GetPlayerInterior(playerid) != 0 || GetPlayerVirtualWorld(playerid) != 0)
    {
        return 0;
    }

    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);

    new bestPort = 0;
    new Float:bestDistance = radius + 0.001;

    for (new portId = 1; portId <= MAX_PORT_TERMINALS; portId++)
    {
        new const Float:dx = px - sPortPositions[portId - 1][0];
        new const Float:dy = py - sPortPositions[portId - 1][1];
        new const Float:dz = pz - sPortPositions[portId - 1][2];
        new const Float:distance = floatsqroot((dx * dx) + (dy * dy));

        if (distance <= bestDistance && dz > -25.0 && dz < 25.0)
        {
            bestDistance = distance;
            bestPort = portId;
        }
    }
    return bestPort;
}

static stock Internal_ResetPortQuote(quote_slot)
{
    sPortQuotes[quote_slot][E_QUOTE_VALID] = false;
    sPortQuotes[quote_slot][E_QUOTE_PORT_ID] = 0;
    sPortQuotes[quote_slot][E_QUOTE_ITEM_DEF_ID] = 0;
    sPortQuotes[quote_slot][E_QUOTE_REF_PRICE_USD] = 0;
    sPortQuotes[quote_slot][E_QUOTE_CURRENT_STOCK] = 0;
    sPortQuotes[quote_slot][E_QUOTE_TARGET_STOCK] = 0;
    sPortQuotes[quote_slot][E_QUOTE_SPREAD] = PORT_SPREAD_MIN_PERCENT;
    sPortQuotes[quote_slot][E_QUOTE_BUY_PRICE_USD] = 0;
    sPortQuotes[quote_slot][E_QUOTE_SELL_PRICE_USD] = 0;
}

static stock Internal_RecalculateQuote(quote_slot)
{
    if (quote_slot < 0 || quote_slot >= MAX_PORT_QUOTES || !sPortQuotes[quote_slot][E_QUOTE_VALID])
    {
        return 0;
    }

    new const Float:target = float(sPortQuotes[quote_slot][E_QUOTE_TARGET_STOCK]);
    new const Float:current = float(sPortQuotes[quote_slot][E_QUOTE_CURRENT_STOCK] + 1);
    new Float:ratio = target / current;

    if (ratio < PORT_PRICE_CLAMP_MIN)
    {
        ratio = PORT_PRICE_CLAMP_MIN;
    }
    if (ratio > PORT_PRICE_CLAMP_MAX)
    {
        ratio = PORT_PRICE_CLAMP_MAX;
    }

    new Float:spread = sPortQuotes[quote_slot][E_QUOTE_SPREAD];
    if (spread < PORT_SPREAD_MIN_PERCENT)
    {
        spread = PORT_SPREAD_MIN_PERCENT;
    }
    if (spread > 0.50)
    {
        spread = 0.50;
    }

    new const Float:midPrice = float(sPortQuotes[quote_slot][E_QUOTE_REF_PRICE_USD]) * ratio;
    new const buyPrice = floatround(midPrice * (1.0 + spread), floatround_ceil);
    new const sellPrice = floatround(midPrice * (1.0 - spread), floatround_floor);

    sPortQuotes[quote_slot][E_QUOTE_BUY_PRICE_USD] = (buyPrice > 0) ? buyPrice : 1;
    sPortQuotes[quote_slot][E_QUOTE_SELL_PRICE_USD] = (sellPrice > 0) ? sellPrice : 1;
    return 1;
}

static stock Internal_AddPortQuote(
    port_id,
    item_def_id,
    refPrice,
    currentStock,
    targetStock,
    Float:spread)
{
    new const quoteSlot = Iter_Free(PortQuoteIter);
    if (quoteSlot == INVALID_ITERATOR_SLOT)
    {
        return -1;
    }

    Iter_Add(PortQuoteIter, quoteSlot);
    Internal_ResetPortQuote(quoteSlot);

    sPortQuotes[quoteSlot][E_QUOTE_VALID] = true;
    sPortQuotes[quoteSlot][E_QUOTE_PORT_ID] = port_id;
    sPortQuotes[quoteSlot][E_QUOTE_ITEM_DEF_ID] = item_def_id;
    sPortQuotes[quoteSlot][E_QUOTE_REF_PRICE_USD] = refPrice;
    sPortQuotes[quoteSlot][E_QUOTE_CURRENT_STOCK] = currentStock;
    sPortQuotes[quoteSlot][E_QUOTE_TARGET_STOCK] = targetStock;
    sPortQuotes[quoteSlot][E_QUOTE_SPREAD] = spread;

    Internal_RecalculateQuote(quoteSlot);
    return quoteSlot;
}

static stock Internal_SeedBuiltinPortQuotes()
{
    for (new i = 0; i < MAX_PORT_QUOTES; i++)
    {
        Internal_ResetPortQuote(i);
    }
    Iter_Init(PortQuoteIter);

    for (new i = 0; i < TOTAL_BUILTIN_PORT_QUOTES; i++)
    {
        new const quoteSlot = Internal_AddPortQuote(
            sBuiltinPortQuotes[i][E_QUOTE_PORT_ID],
            sBuiltinPortQuotes[i][E_QUOTE_ITEM_DEF_ID],
            sBuiltinPortQuotes[i][E_QUOTE_REF_PRICE_USD],
            sBuiltinPortQuotes[i][E_QUOTE_CURRENT_STOCK],
            sBuiltinPortQuotes[i][E_QUOTE_TARGET_STOCK],
            sBuiltinPortQuotes[i][E_QUOTE_SPREAD]);

        if (quoteSlot < 0)
        {
            break;
        }
    }
}

static stock Internal_LoadPortQuotesSync()
{
    for (new i = 0; i < MAX_PORT_QUOTES; i++)
    {
        Internal_ResetPortQuote(i);
    }
    Iter_Init(PortQuoteIter);

    if (!DB_IsConnected())
    {
        Internal_SeedBuiltinPortQuotes();
        printf("%s [Systems/Ports] MySQL unavailable: built-in port quotes loaded (%d entries).",
            SERVER_LOG_PREFIX, TOTAL_BUILTIN_PORT_QUOTES);
        return TOTAL_BUILTIN_PORT_QUOTES;
    }

    // Разрешенный синхронный запрос строго внутри OnGameModeInit
    new const Cache:cache = mysql_query(gMySQL,
        "SELECT `port_id`, `item_def_id`, `ref_price_usd`, `current_stock`, `target_stock`, `spread_percent` FROM `port_market_quotes` ORDER BY `port_id` ASC, `item_def_id` ASC;",
        true);

    if (!cache_is_valid(cache))
    {
        Internal_SeedBuiltinPortQuotes();
        printf("%s [Systems/Ports] [WARN] Failed to read port_market_quotes: embedded quotes loaded.",
            SERVER_LOG_PREFIX);
        return TOTAL_BUILTIN_PORT_QUOTES;
    }

    new rowCount = 0;
    cache_get_row_count(rowCount);
    new loadedQuotes = 0;

    for (new row = 0; row < rowCount; row++)
    {
        new portId, itemDefId, refPrice, currentStock, targetStock;
        new Float:spread;

        cache_get_value_name_int(row, "port_id", portId);
        cache_get_value_name_int(row, "item_def_id", itemDefId);
        cache_get_value_name_int(row, "ref_price_usd", refPrice);
        cache_get_value_name_int(row, "current_stock", currentStock);
        cache_get_value_name_int(row, "target_stock", targetStock);
        cache_get_value_name_float(row, "spread_percent", spread);

        if (Internal_AddPortQuote(portId, itemDefId, refPrice, currentStock, targetStock, spread) >= 0)
        {
            loadedQuotes++;
        }
    }
    cache_delete(cache);

    printf("%s [Systems/Ports] Port quotes loaded from MySQL (entries: %d).",
        SERVER_LOG_PREFIX, loadedQuotes);
    return loadedQuotes;
}

static stock Internal_FindQuoteSlot(port_id, item_def_id)
{
    foreach (new quoteSlot : PortQuoteIter)
    {
        if (sPortQuotes[quoteSlot][E_QUOTE_VALID] &&
            sPortQuotes[quoteSlot][E_QUOTE_PORT_ID] == port_id &&
            sPortQuotes[quoteSlot][E_QUOTE_ITEM_DEF_ID] == item_def_id)
        {
            return quoteSlot;
        }
    }
    return -1;
}

static stock Internal_SaveQuoteStock(quote_slot)
{
    if (quote_slot < 0 || quote_slot >= MAX_PORT_QUOTES || !sPortQuotes[quote_slot][E_QUOTE_VALID])
    {
        return 0;
    }
    if (!DB_IsConnected())
    {
        return 0;
    }

    new query[192];
    mysql_format(gMySQL, query, sizeof(query),
        "UPDATE `port_market_quotes` SET `current_stock` = %d WHERE `port_id` = %d AND `item_def_id` = %d;",
        sPortQuotes[quote_slot][E_QUOTE_CURRENT_STOCK],
        sPortQuotes[quote_slot][E_QUOTE_PORT_ID],
        sPortQuotes[quote_slot][E_QUOTE_ITEM_DEF_ID]);
    mysql_tquery(gMySQL, query);
    return 1;
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

static stock Internal_AddOrganizationBalance(org_id, amountUsd)
{
    if (amountUsd <= 0 || !DB_IsConnected())
    {
        return 0;
    }

    new query[192];
    mysql_format(gMySQL, query, sizeof(query),
        "UPDATE `organizations` SET `bank_balance_usd` = `bank_balance_usd` + %d WHERE `id` = %d;",
        amountUsd,
        org_id);
    mysql_tquery(gMySQL, query);
    return 1;
}

static stock Internal_ExecutePortImport(playerid, port_id, item_def_id, requestedAmount)
{
    new const quoteSlot = Internal_FindQuoteSlot(port_id, item_def_id);
    if (quoteSlot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Port]: This item is not traded in this port.");
        return 0;
    }

    new amount = requestedAmount;
    new const stockAmount = sPortQuotes[quoteSlot][E_QUOTE_CURRENT_STOCK];
    if (amount > stockAmount)
    {
        amount = stockAmount;
    }
    if (amount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Port]: The port warehouse does not have this item.");
        return 0;
    }

    new const buyPrice = sPortQuotes[quoteSlot][E_QUOTE_BUY_PRICE_USD];
    if (buyPrice <= 0 || amount > (2000000000 / buyPrice))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Port]: The transaction amount is too large.");
        return 0;
    }
    new const totalCost = buyPrice * amount;
    if (Character_GetPhysicalCashUsd(playerid) < totalCost)
    {
        new msg[160];
        format(msg, sizeof(msg), "[Port]: Not enough cash. Requires $%d.", totalCost);
        SendClientMessage(playerid, COLOR_UI_ERROR, msg);
        return 0;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Port]: Inventory unavailable.");
        return 0;
    }

    new const addedWeightG = Item_CalculateInstanceWeight(item_def_id, amount);
    new const addedVolumeMl = Item_CalculateInstanceVolume(item_def_id, amount);
    new const cashWeightG = Item_CalculateInstanceWeight(ITEM_ID_CASH_BUNDLE, totalCost);
    new const cashVolumeMl = Item_CalculateInstanceVolume(ITEM_ID_CASH_BUNDLE, totalCost);
    new baseWeightG = Storage_GetCurrentWeight(layer1Slot);
    new baseVolumeMl = Storage_GetCurrentVolume(layer1Slot);
    if (baseWeightG < cashWeightG)
    {
        baseWeightG = cashWeightG;
    }
    if (baseVolumeMl < cashVolumeMl)
    {
        baseVolumeMl = cashVolumeMl;
    }
    new const finalWeightG = baseWeightG - cashWeightG + addedWeightG;
    new const finalVolumeMl = baseVolumeMl - cashVolumeMl + addedVolumeMl;

    if (finalWeightG > Storage_GetMaxWeight(layer1Slot) ||
        finalVolumeMl > Storage_GetMaxVolume(layer1Slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Port]: The batch does not fit into inventory. Reduce the quantity.");
        return 0;
    }

    if (!Character_RemovePhysicalCashUsd(playerid, totalCost))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Port]: Cash debit failed.");
        return 0;
    }

    new outItemSlot = INVALID_STORAGE_ITEM_SLOT;
    new const E_STORAGE_RESULT:addResult = Storage_AddItem(
        layer1Slot,
        item_def_id,
        amount,
        0,
        100.0,
        0,
        0,
        "",
        outItemSlot);

    if (addResult != STORAGE_RES_OK)
    {
        Character_AddPhysicalCashUsd(playerid, totalCost, CASH_FLAG_CLEAN);
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Port]: Failed to issue the item. The money has been returned.");
        return 0;
    }

    sPortQuotes[quoteSlot][E_QUOTE_CURRENT_STOCK] -= amount;
    Internal_RecalculateQuote(quoteSlot);
    Internal_SaveQuoteStock(quoteSlot);
    Internal_AddOrganizationBalance(PORT_AUTHORITY_ORG_ID, totalCost);

    new itemName[64];
    Item_GetName(item_def_id, itemName);

    new msg[192];
    format(msg, sizeof(msg),
        "[Port]: Import completed: %s (quantity: %d) for $%d. Balance in port: %d.",
        itemName, amount, totalCost, sPortQuotes[quoteSlot][E_QUOTE_CURRENT_STOCK]);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new portName[48], auditDetails[192];
    Ports_GetPortNameRu(port_id, portName, sizeof(portName));
    format(auditDetails, sizeof(auditDetails),
        "Import '%s' (Qty: %d) via %s for $%d. The proceeds are credited to the port authority.",
        itemName, amount, portName, totalCost);
    Audit_Log(
        Character_GetId(playerid),
        "PORT_IMPORT",
        "PORT_STOCK",
        "PLAYER_LAYER1",
        item_def_id,
        amount,
        auditDetails);
    return 1;
}

// =============================================================================
//  5. ПУБЛИЧНЫЙ API КОТИРОВОК И ЭКСПОРТА (Ports_*)
// =============================================================================

stock Ports_GetBuyPrice(port_id, item_def_id)
{
    new const quoteSlot = Internal_FindQuoteSlot(port_id, item_def_id);
    if (quoteSlot < 0)
    {
        return 0;
    }
    return sPortQuotes[quoteSlot][E_QUOTE_BUY_PRICE_USD];
}

stock Ports_GetSellPrice(port_id, item_def_id)
{
    new const quoteSlot = Internal_FindQuoteSlot(port_id, item_def_id);
    if (quoteSlot < 0)
    {
        return 0;
    }
    return sPortQuotes[quoteSlot][E_QUOTE_SELL_PRICE_USD];
}

stock Ports_GetStock(port_id, item_def_id)
{
    new const quoteSlot = Internal_FindQuoteSlot(port_id, item_def_id);
    if (quoteSlot < 0)
    {
        return 0;
    }
    return sPortQuotes[quoteSlot][E_QUOTE_CURRENT_STOCK];
}

stock Ports_GetBestSellPrice(item_def_id)
{
    new bestPrice = 0;
    foreach (new quoteSlot : PortQuoteIter)
    {
        if (!sPortQuotes[quoteSlot][E_QUOTE_VALID] ||
            sPortQuotes[quoteSlot][E_QUOTE_ITEM_DEF_ID] != item_def_id)
        {
            continue;
        }
        if (sPortQuotes[quoteSlot][E_QUOTE_SELL_PRICE_USD] > bestPrice)
        {
            bestPrice = sPortQuotes[quoteSlot][E_QUOTE_SELL_PRICE_USD];
        }
    }
    return bestPrice;
}

stock Ports_FindBestExportPort(item_def_id)
{
    new bestPort = 0;
    new bestPrice = 0;

    foreach (new quoteSlot : PortQuoteIter)
    {
        if (!sPortQuotes[quoteSlot][E_QUOTE_VALID] ||
            sPortQuotes[quoteSlot][E_QUOTE_ITEM_DEF_ID] != item_def_id)
        {
            continue;
        }

        new const sellPrice = sPortQuotes[quoteSlot][E_QUOTE_SELL_PRICE_USD];
        if (sellPrice > bestPrice)
        {
            bestPrice = sellPrice;
            bestPort = sPortQuotes[quoteSlot][E_QUOTE_PORT_ID];
        }
    }
    return bestPort;
}

stock Ports_SellCargoToPort(playerid, port_id, item_def_id, amount, source_ent_id, trucker_char_id)
{
    if (amount <= 0 || !Item_IsValid(item_def_id))
    {
        return 0;
    }

    new const quoteSlot = Internal_FindQuoteSlot(port_id, item_def_id);
    if (quoteSlot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Port]: This item is not accepted at this port.");
        return 0;
    }

    new const sellPrice = sPortQuotes[quoteSlot][E_QUOTE_SELL_PRICE_USD];
    if (sellPrice <= 0 || amount > (2000000000 / sellPrice))
    {
        return 0;
    }
    new const totalRevenue = sellPrice * amount;
    if (totalRevenue <= 0)
    {
        return 0;
    }

    new ownerShare = (totalRevenue * PORT_EXPORT_OWNER_PERCENT) / 100;
    new truckerShare = (totalRevenue * PORT_EXPORT_TRUCKER_PERCENT) / 100;
    new taxShare = totalRevenue - ownerShare - truckerShare;

    // Бонус роли «Король Трассы»: +20% к доле дальнобойщика из резерва заказчика
    new const sourceEnterpriseSlot = Enterprise_FindByDbId(source_ent_id);
    new bonusShare = 0;
    if (trucker_char_id > 0 && Enterprise_IsValid(sourceEnterpriseSlot))
    {
        if (Character_IsLoaded(playerid) &&
            Character_GetId(playerid) == trucker_char_id &&
            Roles_HasPerk(Character_GetRoleId(playerid), PERK_TRUCKER_BONUS_20))
        {
            bonusShare = (truckerShare * PORT_TRUCKER_PERK_BONUS_PERCENT) / 100;
            if (bonusShare > 0 && !Enterprise_TakeReserve(sourceEnterpriseSlot, bonusShare))
            {
                bonusShare = 0;
            }
        }
    }
    truckerShare += bonusShare;

    // Обновление физического запаса порта и котировки
    sPortQuotes[quoteSlot][E_QUOTE_CURRENT_STOCK] += amount;
    Internal_RecalculateQuote(quoteSlot);
    Internal_SaveQuoteStock(quoteSlot);

    // Доля владельца предприятия / государственного бюджета
    if (ownerShare > 0)
    {
        if (Enterprise_IsValid(sourceEnterpriseSlot) &&
            Enterprise_GetOwnership(sourceEnterpriseSlot) != ENTERPRISE_OWN_STATE)
        {
            Enterprise_AddReserve(sourceEnterpriseSlot, ownerShare);
        }
        else
        {
            Internal_AddOrganizationBalance(PORT_GOVERNMENT_ORG_ID, ownerShare);
        }
    }

    // Доля дальнобойщика
    if (truckerShare > 0 && trucker_char_id > 0 && playerid >= 0 && playerid < MAX_PLAYERS &&
        IsPlayerConnected(playerid) && Character_IsLoaded(playerid) &&
        Character_GetId(playerid) == trucker_char_id)
    {
        if (!Character_AddPhysicalCashUsd(playerid, truckerShare, CASH_FLAG_CLEAN))
        {
            Internal_DropCashToWorld(playerid, truckerShare);
        }
    }
    else if (truckerShare > 0)
    {
        Internal_AddOrganizationBalance(PORT_GOVERNMENT_ORG_ID, truckerShare);
    }

    // Экспортная пошлина в казну штата
    if (taxShare > 0)
    {
        Internal_AddOrganizationBalance(PORT_GOVERNMENT_ORG_ID, taxShare);
    }

    new itemName[64], portName[48];
    Item_GetName(item_def_id, itemName);
    Ports_GetPortNameRu(port_id, portName, sizeof(portName));

    new msg[224];
    format(msg, sizeof(msg),
        "[Port]: Export %s (quantity: %d) via %s. Revenue: $%d (owner $%d, driver $%d, toll $%d).",
        itemName, amount, portName, totalRevenue, ownerShare, truckerShare, taxShare);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new auditDetails[224];
    format(auditDetails, sizeof(auditDetails),
        "Export '%s' (Qty: %d) via %s. Revenue $%d: owner $%d, trucker $%d, toll $%d.",
        itemName, amount, portName, totalRevenue, ownerShare, truckerShare, taxShare);
    Audit_Log(
        trucker_char_id,
        "PORT_EXPORT",
        "ENTERPRISE_WAREHOUSE",
        "PORT_STOCK",
        item_def_id,
        amount,
        auditDetails);

    return totalRevenue;
}

// =============================================================================
//  6. ЕЖЕМИНУТНОЕ ОБНОВЛЕНИЕ КОТИРОВОК (вызывается из Tick_Minute)
// =============================================================================

stock Ports_TickMinute()
{
    if (Main_IsServerShuttingDown())
    {
        return 0;
    }

    new updatedQuotes = 0;
    foreach (new quoteSlot : PortQuoteIter)
    {
        if (sPortQuotes[quoteSlot][E_QUOTE_VALID])
        {
            Internal_RecalculateQuote(quoteSlot);
            updatedQuotes++;
        }
    }
    return updatedQuotes;
}

// =============================================================================
//  7. ДИАЛОГИ ПОРТА
// =============================================================================

static stock Internal_ShowPortQuotes(playerid, port_id)
{
    new portName[48];
    sPortDialogBuffer[0] = '\0';
    Ports_GetPortNameRu(port_id, portName, sizeof(portName));

    new quoteCount = 0;
    foreach (new quoteSlot : PortQuoteIter)
    {
        if (!sPortQuotes[quoteSlot][E_QUOTE_VALID] ||
            sPortQuotes[quoteSlot][E_QUOTE_PORT_ID] != port_id)
        {
            continue;
        }

        new itemName[64], rowLine[192];
        Item_GetName(sPortQuotes[quoteSlot][E_QUOTE_ITEM_DEF_ID], itemName);
        format(rowLine, sizeof(rowLine),
            "%s | purchase: $%d | sale: $%d | stock: %d / target: %d",
            itemName,
            sPortQuotes[quoteSlot][E_QUOTE_BUY_PRICE_USD],
            sPortQuotes[quoteSlot][E_QUOTE_SELL_PRICE_USD],
            sPortQuotes[quoteSlot][E_QUOTE_CURRENT_STOCK],
            sPortQuotes[quoteSlot][E_QUOTE_TARGET_STOCK]);

        strcat(sPortDialogBuffer, rowLine, sizeof(sPortDialogBuffer));
        strcat(sPortDialogBuffer, "\n", sizeof(sPortDialogBuffer));
        quoteCount++;
    }

    if (quoteCount <= 0)
    {
        format(sPortDialogBuffer, sizeof(sPortDialogBuffer), "The port \"%s\" currently has no active quotes.", portName);
    }

    new title[96];
    format(title, sizeof(title), "Quotes: %s", portName);
    ShowPlayerDialog(playerid, DIALOG_PORT_QUOTES, DIALOG_STYLE_MSGBOX, title, sPortDialogBuffer, "Understood", "");
    return 1;
}

static stock Internal_ShowPortImportItems(playerid, port_id)
{
    new portName[48];
    sPortDialogBuffer[0] = '\0';
    sPortDialogRowCount[playerid] = 0;
    Ports_GetPortNameRu(port_id, portName, sizeof(portName));

    foreach (new quoteSlot : PortQuoteIter)
    {
        if (!sPortQuotes[quoteSlot][E_QUOTE_VALID] ||
            sPortQuotes[quoteSlot][E_QUOTE_PORT_ID] != port_id ||
            sPortQuotes[quoteSlot][E_QUOTE_CURRENT_STOCK] <= 0)
        {
            continue;
        }
        if (sPortDialogRowCount[playerid] >= MAX_PORT_DIALOG_ROWS)
        {
            break;
        }

        new itemName[64], rowLine[160];
        Item_GetName(sPortQuotes[quoteSlot][E_QUOTE_ITEM_DEF_ID], itemName);
        format(rowLine, sizeof(rowLine),
            "%s | import price: $%d | in stock: %d",
            itemName,
            sPortQuotes[quoteSlot][E_QUOTE_BUY_PRICE_USD],
            sPortQuotes[quoteSlot][E_QUOTE_CURRENT_STOCK]);

        strcat(sPortDialogBuffer, rowLine, sizeof(sPortDialogBuffer));
        strcat(sPortDialogBuffer, "\n", sizeof(sPortDialogBuffer));
        sPortDialogItemMap[playerid][sPortDialogRowCount[playerid]++] =
            sPortQuotes[quoteSlot][E_QUOTE_ITEM_DEF_ID];
    }

    if (sPortDialogRowCount[playerid] <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Port]: The port warehouse is empty.");
        return 0;
    }

    sPortPendingPort[playerid] = port_id;
    new title[96];
    format(title, sizeof(title), "Import via %s", portName);
    ShowPlayerDialog(
        playerid,
        DIALOG_PORT_IMPORT_ITEM,
        DIALOG_STYLE_LIST,
        title,
        sPortDialogBuffer,
        "Select",
        "Cancel");
    return 1;
}

static stock Internal_ShowPortMenu(playerid, port_id)
{
    new portName[48], body[512];
    Ports_GetPortNameRu(port_id, portName, sizeof(portName));
    format(body, sizeof(body),
        "1. Port quotes \n2. Import of goods\n3. Hand over cargo from a truck (export)\n4. Port information");

    sPortPendingPort[playerid] = port_id;
    new title[96];
    format(title, sizeof(title), "%s", portName);
    ShowPlayerDialog(playerid, DIALOG_PORT_MENU, DIALOG_STYLE_LIST, title, body, "Select", "Close");
    return 1;
}

// =============================================================================
//  8. КОМАНДА /port И ОБРАБОТКА ДИАЛОГОВ
// =============================================================================

CMD:port(playerid, params[])
{
    #pragma unused params

    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Port]: Your character has not yet been loaded.");
        return 1;
    }
    if (!Character_IsAlive(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Port]: A dead character cannot handle cargo.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sLastPortCommandTick[playerid]) < PORT_COMMAND_COOLDOWN_MS)
    {
        return 1;
    }
    sLastPortCommandTick[playerid] = nowTick;

    new const portId = Ports_FindNearestPort(playerid, PORT_INTERACT_RADIUS);
    if (portId <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Port]: Go to the port terminal in Los Santos, San Fierro or Las Venturas.");
        return 1;
    }

    Internal_ShowPortMenu(playerid, portId);
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid >= DIALOG_PORT_MENU && dialogid <= DIALOG_PORT_IMPORT_AMOUNT &&
        !Character_IsAlive(playerid))
    {
        return Y_HOOKS_BREAK_RETURN_1;
    }

    switch (dialogid)
    {
        case DIALOG_PORT_MENU:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const portId = sPortPendingPort[playerid];
            if (portId < 1 || portId > MAX_PORT_TERMINALS)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            switch (listitem)
            {
                case 0:
                {
                    Internal_ShowPortQuotes(playerid, portId);
                }
                case 1:
                {
                    Internal_ShowPortImportItems(playerid, portId);
                }
                case 2:
                {
                    Logistics_UnloadAtPort(playerid, portId);
                }
                case 3:
                {
                    new portName[48], body[512];
                    Ports_GetPortNameRu(portId, portName, sizeof(portName));
                    format(body, sizeof(body),
                        "Port: %s\n\nExport cargo is accepted here.\nImport is paid in cash, export proceeds are divided 90%% / 5%% / 5%%.\nFor export, load the cargo under the contract and drive the truck to the terminal.",
                        portName);
                    ShowPlayerDialog(playerid, DIALOG_PORT_QUOTES, DIALOG_STYLE_MSGBOX, "Port information", body, "Understood", "");
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_PORT_IMPORT_ITEM:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sPortDialogRowCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const portId = sPortPendingPort[playerid];
            new const itemDefId = sPortDialogItemMap[playerid][listitem];
            if (portId < 1 || portId > MAX_PORT_TERMINALS || !Item_IsValid(itemDefId))
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            sPortPendingItem[playerid] = itemDefId;

            new itemName[64], body[256];
            Item_GetName(itemDefId, itemName);
            format(body, sizeof(body),
                "Product: %s\nImport price: $%d per unit\nEnter quantity:",
                itemName,
                Ports_GetBuyPrice(portId, itemDefId));

            ShowPlayerDialog(
                playerid,
                DIALOG_PORT_IMPORT_AMOUNT,
                DIALOG_STYLE_INPUT,
                "Import of goods",
                body,
                "Buy",
                "Cancel");
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_PORT_IMPORT_AMOUNT:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new amount = 0;
            new idx = 0;
            while (inputtext[idx] == ' ' || inputtext[idx] == '\t')
            {
                idx++;
            }
            if (inputtext[idx] < '0' || inputtext[idx] > '9')
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Port]: Enter a positive integer.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            while (inputtext[idx] >= '0' && inputtext[idx] <= '9')
            {
                amount = (amount * 10) + (inputtext[idx] - '0');
                if (amount > 2000000000)
                {
                    SendClientMessage(playerid, COLOR_UI_ERROR, "[Port]: Number too large.");
                    return Y_HOOKS_BREAK_RETURN_1;
                }
                idx++;
            }
            while (inputtext[idx] == ' ' || inputtext[idx] == '\t')
            {
                idx++;
            }
            if (amount <= 0 || inputtext[idx] != '\0')
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "[Port]: Enter a positive integer.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            Internal_ExecutePortImport(playerid, sPortPendingPort[playerid], sPortPendingItem[playerid], amount);
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_0;
}

// =============================================================================
//  9. СИСТЕМНЫЕ ХУКИ (y_hooks)
// =============================================================================

static stock Internal_CreatePortLabels()
{
    new portName[48], labelText[192];
    for (new portIndex = 0; portIndex < MAX_PORT_TERMINALS; portIndex++)
    {
        Ports_GetPortNameRu(portIndex + 1, portName, sizeof(portName));
        format(labelText, sizeof(labelText),
            "%s\nImport and Export Terminal\nEnter /port to open",
            portName);

        sPortLabel[portIndex] = CreateDynamic3DTextLabel(
            labelText,
            COLOR_UI_INFO,
            sPortPositions[portIndex][0],
            sPortPositions[portIndex][1],
            sPortPositions[portIndex][2] + 2.0,
            PORT_LABEL_DRAW_DISTANCE,
            INVALID_PLAYER_ID,
            INVALID_VEHICLE_ID,
            0,
            0, 0, -1,
            PORT_LABEL_STREAM_DISTANCE);
    }
}

hook OnGameModeInit()
{
    new const loadedQuotes = Internal_LoadPortQuotesSync();
    Internal_CreatePortLabels();

    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        sPortDialogRowCount[i] = 0;
        sPortPendingPort[i] = 0;
        sPortPendingItem[i] = 0;
        sLastPortCommandTick[i] = 0;
    }

    printf("%s [Systems/Ports] The ports module is running (quotes: %d).",
        SERVER_LOG_PREFIX, loadedQuotes);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason

    sPortDialogRowCount[playerid] = 0;
    sPortPendingPort[playerid] = 0;
    sPortPendingItem[playerid] = 0;
    sLastPortCommandTick[playerid] = 0;
    return 1;
}

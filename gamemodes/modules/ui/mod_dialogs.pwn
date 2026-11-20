/*
 * =============================================================================
 *  SAN ANDREAS RP — Единый диалоговый маршрутизатор, инвентарь и клавиша Y
 *  Файл:      gamemodes/modules/ui/mod_dialogs.pwn
 *  Пункт:     ROADMAP [4.3] — Единый диалоговый маршрутизатор и инвентарь (ui/mod_dialogs.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_dialogs_included
    #endinput
#endif
#define _mod_dialogs_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ ИДЕНТИФИКАТОРОВ ДИАЛОГОВ ИНВЕНТАРЯ И КОНТЕКСТНОГО МЕНЮ (1100..1119)
// =============================================================================

#define DIALOG_INV_MAIN_LIST                    (1100)
#define DIALOG_INV_ITEM_ACTIONS                 (1101)
#define DIALOG_INV_INPUT_AMOUNT                 (1102)
#define DIALOG_INV_EXTERNAL_CONTAINER           (1103)
#define DIALOG_INV_CONTEXT_MENU_Y               (1104)
#define DIALOG_INV_SEARCH_INSPECT               (1105)
#define DIALOG_ACT_PLAYER_CARD                  (1106)
#define DIALOG_ACT_PAY_INPUT                    (1107)

#define MAX_DIALOG_INV_ROWS                     (64)
#define MAX_ACT_MENU_ROWS                       (48)
#define CONTEXT_INTERACT_RADIUS_M               (3.0)
#define KEYBIND_INTERACT_COOLDOWN_MS            (350)

forward MainMenu_Open(playerid);
forward pc_cmd_inv(playerid, params[]);
forward pc_cmd_showpass(playerid, params[]);
forward pc_cmd_showlic(playerid, params[]);
forward pc_cmd_frisk(playerid, params[]);
forward pc_cmd_search(playerid, params[]);
forward pc_cmd_pickpocket(playerid, params[]);
forward pc_cmd_cuff(playerid, params[]);
forward pc_cmd_uncuff(playerid, params[]);
forward pc_cmd_pay(playerid, params[]);
forward pc_cmd_mm(playerid, params[]);

enum E_ACT_ENTRY_TYPE
{
    ACT_ENTRY_NONE = 0,
    ACT_ENTRY_PLAYER,
    ACT_ENTRY_VEH_ENGINE,
    ACT_ENTRY_VEH_LOCK,
    ACT_ENTRY_VEH_TRUNK,
    ACT_ENTRY_VEH_GLOVEBOX,
    ACT_ENTRY_VEH_REFUEL,
    ACT_ENTRY_VEH_REPAIR,
    ACT_ENTRY_VEH_LOCKPICK,
    ACT_ENTRY_VEH_BREAKWINDOW,
    ACT_ENTRY_VEH_HOTWIRE,
    ACT_ENTRY_VEH_CHOP,
    ACT_ENTRY_VEH_PARK,
    ACT_ENTRY_VEH_UNPARK,
    ACT_ENTRY_VEH_BUY,
    ACT_ENTRY_WORLD_CONTAINER,
    ACT_ENTRY_PROPERTY_MENU,
    ACT_ENTRY_PROPERTY_LOCK,
    ACT_ENTRY_PROPERTY_PAYBILLS,
    ACT_ENTRY_PROPERTY_LOCKPICK,
    ACT_ENTRY_PROPERTY_KICKDOOR,
    ACT_ENTRY_ENT_MINE,
    ACT_ENTRY_ENT_DELIVER,
    ACT_ENTRY_ENT_CRAFT,
    ACT_ENTRY_ENT_BIZ,
    ACT_ENTRY_ENT_MARKET,
    ACT_ENTRY_PORT_MENU,
    ACT_ENTRY_CONTRACTS,
    ACT_ENTRY_BANK_MENU,
    ACT_ENTRY_LAUNDER_MENU,
    ACT_ENTRY_ORG_VAULT,
    ACT_ENTRY_VAULT_BREACH,
    ACT_ENTRY_FORENSICS,
    ACT_ENTRY_SELF_INV,
    ACT_ENTRY_SELF_MM
};

enum E_ACT_PLAYER_OP
{
    ACT_PL_NONE = 0,
    ACT_PL_GIVE_ITEM,
    ACT_PL_PAY_CASH,
    ACT_PL_SHOW_PASS,
    ACT_PL_SHOW_LIC,
    ACT_PL_TRIAGE,
    ACT_PL_TREAT,
    ACT_PL_FRISK,
    ACT_PL_SEARCH,
    ACT_PL_PICKPOCKET,
    ACT_PL_CUFF,
    ACT_PL_UNCUFF,
    ACT_PL_ARREST
};

enum E_INV_VIEW_MODE
{
    INV_VIEW_LAYER_1 = 0,
    INV_VIEW_LAYER_2,
    INV_VIEW_NESTED_BAG
};

enum E_INV_PENDING_OP
{
    INV_OP_NONE = 0,
    INV_OP_SPLIT_STACK,
    INV_OP_MOVE_TO_OTHER_LAYER,
    INV_OP_MOVE_TO_EXTERNAL,
    INV_OP_DROP_TO_GROUND,
    INV_OP_TAKE_FROM_EXTERNAL
};

// =============================================================================
//  2. СОСТОЯНИЕ СЕССИИ ИНВЕНТАРЯ И ВНЕШНЕГО ХРАНИЛИЩА ИГРОКА (static stock)
// =============================================================================

static stock E_INV_VIEW_MODE:sPlayerInvViewMode[MAX_PLAYERS];
static stock sPlayerActiveStorageSlot[MAX_PLAYERS];
static stock sPlayerExternalStorageSlot[MAX_PLAYERS];
static stock sPlayerNestedBagSlot[MAX_PLAYERS];
static stock sPlayerSelectedItemSlot[MAX_PLAYERS];
static stock E_INV_PENDING_OP:sPlayerPendingOp[MAX_PLAYERS];

// Отображение строк таблицы диалога в слоты предметов (row -> item_slot или специальный код)
#define INV_ROW_SWITCH_LAYER_1                  (-10)
#define INV_ROW_SWITCH_LAYER_2                  (-11)
#define INV_ROW_OPEN_EXTERNAL                   (-12)

static stock sPlayerDialogRowMap[MAX_PLAYERS][MAX_DIALOG_INV_ROWS];
static stock sPlayerDialogRowCount[MAX_PLAYERS];

// Состояние обыска (/frisk и /search)
static stock sPlayerSearchTarget[MAX_PLAYERS];
static stock bool:sPlayerSearchAllowConfiscate[MAX_PLAYERS];
static stock bool:sPlayerSearchIncludeLayer2[MAX_PLAYERS];
static stock sPlayerSearchStorageMap[MAX_PLAYERS][MAX_DIALOG_INV_ROWS];

// Серверный маппинг контекстного меню /act (защита от подмены listitem)
static stock E_ACT_ENTRY_TYPE:sPlayerActTypeMap[MAX_PLAYERS][MAX_ACT_MENU_ROWS];
static stock sPlayerActTargetMap[MAX_PLAYERS][MAX_ACT_MENU_ROWS];
static stock sPlayerActRowCount[MAX_PLAYERS];
static stock sPlayerActSelectedPlayer[MAX_PLAYERS];
static stock E_ACT_PLAYER_OP:sPlayerActPlayerOpMap[MAX_PLAYERS][16];
static stock sPlayerActPlayerOpCount[MAX_PLAYERS];
static stock sPlayerLastKeybindTick[MAX_PLAYERS];
static stock sDialogEmptyCmdParams[4];

// =============================================================================
//  3. ВНУТРЕННИЕ ФУНКЦИИ СБРОСА И ОБЕСПЕЧЕНИЯ ВЛОЖЕННОГО КОНТЕЙНЕРА
// =============================================================================

static stock Dialogs_ResetPlayerState(playerid)
{
    if (sPlayerExternalStorageSlot[playerid] != INVALID_STORAGE_SLOT)
    {
        Storage_CloseForPlayer(playerid, sPlayerExternalStorageSlot[playerid]);
    }
    if (sPlayerNestedBagSlot[playerid] != INVALID_STORAGE_SLOT)
    {
        Storage_CloseForPlayer(playerid, sPlayerNestedBagSlot[playerid]);
    }

    sPlayerInvViewMode[playerid] = INV_VIEW_LAYER_1;
    sPlayerActiveStorageSlot[playerid] = INVALID_STORAGE_SLOT;
    sPlayerExternalStorageSlot[playerid] = INVALID_STORAGE_SLOT;
    sPlayerNestedBagSlot[playerid] = INVALID_STORAGE_SLOT;
    sPlayerSelectedItemSlot[playerid] = INVALID_ITEM_SLOT;
    sPlayerPendingOp[playerid] = INV_OP_NONE;
    sPlayerDialogRowCount[playerid] = 0;
    sPlayerSearchTarget[playerid] = INVALID_PLAYER_ID;
    sPlayerSearchAllowConfiscate[playerid] = false;
    sPlayerSearchIncludeLayer2[playerid] = false;
    sPlayerActRowCount[playerid] = 0;
    sPlayerActSelectedPlayer[playerid] = INVALID_PLAYER_ID;
    sPlayerActPlayerOpCount[playerid] = 0;
}

static stock Internal_MergeSimilarStacks(storage_slot, item_slot)
{
    if (!Storage_IsValidSlot(storage_slot) || !Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }

    new defId = Storage_GetItemDefId(item_slot);
    if (!Item_IsStackable(defId))
    {
        return 0;
    }

    new maxStack = Item_GetMaxStack(defId);
    new curAmt = Storage_GetItemAmount(item_slot);
    if (curAmt >= maxStack)
    {
        return 0;
    }

    new mergedTotal = 0;
    new iter = Storage_GetFirstItemSlot(storage_slot);
    while (iter != INVALID_ITEM_SLOT)
    {
        new nextIter = Storage_GetNextItemSlot(iter);
        if (iter != item_slot && Storage_GetItemDefId(iter) == defId)
        {
            new otherAmt = Storage_GetItemAmount(iter);
            new spaceLeft = maxStack - curAmt;
            if (spaceLeft <= 0)
            {
                break;
            }
            new takeAmt = (otherAmt > spaceLeft) ? spaceLeft : otherAmt;
            if (takeAmt > 0)
            {
                new Float:dura = Storage_GetItemDurability(item_slot);
                new meta1 = Storage_GetItemMetaInt1(item_slot);
                new meta2 = Storage_GetItemMetaInt2(item_slot);
                new metaStr[ITEM_META_STR_LEN];
                Storage_GetItemMetaStr(item_slot, metaStr, sizeof(metaStr));

                if (Storage_RemoveItem(storage_slot, iter, takeAmt))
                {
                    Storage_AddItem(storage_slot, defId, takeAmt, 0, dura, meta1, meta2, metaStr);
                    curAmt += takeAmt;
                    mergedTotal += takeAmt;
                }
            }
        }
        iter = nextIter;
    }
    return mergedTotal;
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API ОТКРЫТИЯ ИНВЕНТАРЯ, ХРАНИЛИЩ И ОБЫСКА (stock)
// =============================================================================

/*
 * Открывает табличный диалог инвентаря игрока (/inv, /i).
 */
stock Dialogs_OpenInventory(playerid, E_INV_VIEW_MODE:viewMode = INV_VIEW_LAYER_1)
{
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Your character has not yet been loaded.");
        return 0;
    }

    new layer1Slot = Character_GetLayer1Slot(playerid);
    new layer2Slot = Character_GetLayer2Slot(playerid);

    new targetStorage = layer1Slot;
    if (viewMode == INV_VIEW_LAYER_2)
    {
        targetStorage = layer2Slot;
    }
    else if (viewMode == INV_VIEW_NESTED_BAG && Storage_IsValidSlot(sPlayerNestedBagSlot[playerid]))
    {
        targetStorage = sPlayerNestedBagSlot[playerid];
    }
    else
    {
        viewMode = INV_VIEW_LAYER_1;
        targetStorage = layer1Slot;
    }

    if (!Storage_IsValidSlot(targetStorage))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Error accessing inventory container.");
        return 0;
    }

    if (!Storage_AreItemsReady(targetStorage))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Inventory]: Inventory is still loading. Repeat the command after a moment.");
        return 0;
    }

    // Синхронизируем лимит веса Слоя 1 перед показом
    Survival_RecalculateEncumbrance(playerid);

    sPlayerInvViewMode[playerid] = viewMode;
    sPlayerActiveStorageSlot[playerid] = targetStorage;
    sPlayerDialogRowCount[playerid] = 0;

    new curWeightG  = Storage_GetCurrentWeight(targetStorage);
    new maxWeightG  = Storage_GetMaxWeight(targetStorage);
    new curVolumeMl = Storage_GetCurrentVolume(targetStorage);
    new maxVolumeMl = Storage_GetMaxVolume(targetStorage);

    new titleBuf[144];
    if (viewMode == INV_VIEW_LAYER_1)
    {
        format(
            titleBuf,
            sizeof(titleBuf),
            "Inventory: Layer 1 (External) | Weight: %d.%02d/%d.%02d kg | Volume: %d.%02d/%d.%02d l",
            curWeightG / 1000, (curWeightG % 1000) / 10,
            maxWeightG / 1000, (maxWeightG % 1000) / 10,
            curVolumeMl / 1000, (curVolumeMl % 1000) / 10,
            maxVolumeMl / 1000, (maxVolumeMl % 1000) / 10
        );
    }
    else if (viewMode == INV_VIEW_LAYER_2)
    {
        format(
            titleBuf,
            sizeof(titleBuf),
            "Inventory: Layer 2 (Secret) | Weight: %d.%02d/%d.%02d kg | Volume: %d.%02d/%d.%02d l",
            curWeightG / 1000, (curWeightG % 1000) / 10,
            maxWeightG / 1000, (maxWeightG % 1000) / 10,
            curVolumeMl / 1000, (curVolumeMl % 1000) / 10,
            maxVolumeMl / 1000, (maxVolumeMl % 1000) / 10
        );
    }
    else
    {
        format(
            titleBuf,
            sizeof(titleBuf),
            "Backpack/Bag (Nested) | Weight: %d.%02d/%d.%02d kg | Volume: %d.%02d/%d.%02d l",
            curWeightG / 1000, (curWeightG % 1000) / 10,
            maxWeightG / 1000, (maxWeightG % 1000) / 10,
            curVolumeMl / 1000, (curVolumeMl % 1000) / 10,
            maxVolumeMl / 1000, (maxVolumeMl % 1000) / 10
        );
    }

    static dialogBody[3584];
    dialogBody[0] = '\0';
    strcat(dialogBody, "Item / Action\tQty / Pat.\tCondition\tWeight (kg)\tVolume (l)\n", sizeof(dialogBody));

    // Первая строка: быстрое переключение между Слоем 1 и Слоем 2
    if (viewMode == INV_VIEW_LAYER_1)
    {
        new l2W = Storage_IsValidSlot(layer2Slot) ? Storage_GetCurrentWeight(layer2Slot) : 0;
        new l2MaxW = Storage_IsValidSlot(layer2Slot) ? Storage_GetMaxWeight(layer2Slot) : 2000;
        new switchRow[160];
        format(
            switchRow,
            sizeof(switchRow),
            "{FFD54F}>> Switch: Layer 2 (Secret Pocket)\t-\t-\t%d.%02d/%d.%02d\t-\n",
            l2W / 1000, (l2W % 1000) / 10,
            l2MaxW / 1000, (l2MaxW % 1000) / 10
        );
        strcat(dialogBody, switchRow, sizeof(dialogBody));
        sPlayerDialogRowMap[playerid][sPlayerDialogRowCount[playerid]++] = INV_ROW_SWITCH_LAYER_2;
    }
    else
    {
        new l1W = Storage_IsValidSlot(layer1Slot) ? Storage_GetCurrentWeight(layer1Slot) : 0;
        new l1MaxW = Storage_IsValidSlot(layer1Slot) ? Storage_GetMaxWeight(layer1Slot) : 25000;
        new switchRow[160];
        format(
            switchRow,
            sizeof(switchRow),
            "{FFD54F}<< Return: Layer 1 (External Inventory)\t-\t-\t%d.%02d/%d.%02d\t-\n",
            l1W / 1000, (l1W % 1000) / 10,
            l1MaxW / 1000, (l1MaxW % 1000) / 10
        );
        strcat(dialogBody, switchRow, sizeof(dialogBody));
        sPlayerDialogRowMap[playerid][sPlayerDialogRowCount[playerid]++] = INV_ROW_SWITCH_LAYER_1;
    }

    // Если рядом есть внешнее хранилище / предмет на земле — строка быстрого перехода
    new nearContainer = Storage_FindNearestWorldContainer(playerid, CONTEXT_INTERACT_RADIUS_M);
    if (Storage_IsValidSlot(nearContainer))
    {
        sPlayerExternalStorageSlot[playerid] = nearContainer;
        new extW = Storage_GetCurrentWeight(nearContainer);
        new extRow[160];
        format(
            extRow,
            sizeof(extRow),
            "{81D4FA}[Open nearest storage / package nearby]\t-\t-\t%d.%02d kg\t-\n",
            extW / 1000, (extW % 1000) / 10
        );
        strcat(dialogBody, extRow, sizeof(dialogBody));
        sPlayerDialogRowMap[playerid][sPlayerDialogRowCount[playerid]++] = INV_ROW_OPEN_EXTERNAL;
    }

    // Перечисление всех предметов в текущем выбранном слое/контейнере
    new itemSlot = Storage_GetFirstItemSlot(targetStorage);
    while (itemSlot != INVALID_ITEM_SLOT && sPlayerDialogRowCount[playerid] < MAX_DIALOG_INV_ROWS)
    {
        new defId = Storage_GetItemDefId(itemSlot);
        new amount = Storage_GetItemAmount(itemSlot);
        new ammo = Storage_GetItemAmmo(itemSlot);
        new Float:dura = Storage_GetItemDurability(itemSlot);
        new nestedSlot = Storage_GetItemNestedSlot(itemSlot);

        new itemName[ITEM_DISPLAY_NAME_LEN];
        Item_GetName(defId, itemName, sizeof(itemName));

        new statusStr[32];
        if (defId == ITEM_ID_CLOTHING_OUTFIT)
        {
            new const outfitSkin = Storage_GetItemMetaInt1(itemSlot);
            format(itemName, sizeof(itemName), "Clothes set (skin %d)", outfitSkin);
            if (Character_IsOutfitItemEquipped(playerid, itemSlot))
            {
                format(statusStr, sizeof(statusStr), "{66CC66}Equipped{FFFFFF}");
            }
            else
            {
                format(statusStr, sizeof(statusStr), "{AFAFAF}In bag{FFFFFF}");
            }
        }
        else
        {
            format(statusStr, sizeof(statusStr), "%d%%", floatround(dura, floatround_round));
        }

        new totalWeightG = Item_CalculateInstanceWeight(defId, amount, ammo);
        new totalVolumeMl = Item_CalculateInstanceVolume(defId, amount);
        if (Storage_IsValidSlot(nestedSlot))
        {
            totalWeightG += Storage_GetCurrentWeight(nestedSlot);
        }

        new qtyStr[32];
        if (Item_GetGtaWeaponId(defId) >= 22)
        {
            format(qtyStr, sizeof(qtyStr), "%d pcs. (%d rds.)", amount, ammo);
        }
        else if (defId == ITEM_ID_CASH_BUNDLE)
        {
            format(qtyStr, sizeof(qtyStr), "$%d", amount);
        }
        else
        {
            format(qtyStr, sizeof(qtyStr), "%d pcs.", amount);
        }

        new rowLine[192];
        format(
            rowLine,
            sizeof(rowLine),
            "%s\t%s\t%s\t%d.%02d\t%d.%02d\n",
            itemName,
            qtyStr,
            statusStr,
            totalWeightG / 1000, (totalWeightG % 1000) / 10,
            totalVolumeMl / 1000, (totalVolumeMl % 1000) / 10
        );
        strcat(dialogBody, rowLine, sizeof(dialogBody));
        sPlayerDialogRowMap[playerid][sPlayerDialogRowCount[playerid]++] = itemSlot;

        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_INV_MAIN_LIST,
        DIALOG_STYLE_TABLIST_HEADERS,
        titleBuf,
        dialogBody,
        "Action",
        "Close"
    );
    return 1;
}

/*
 * Открывает диалог взаимодействия с внешним контейнером (WORLD_DROP, CORPSE_LOOT, багажник, сейф).
 */
stock Dialogs_OpenExternalContainer(playerid, ext_storage_slot)
{
    if (!Character_IsLoaded(playerid) || !Storage_IsValidSlot(ext_storage_slot))
    {
        return 0;
    }

    if (!Storage_OpenForPlayer(playerid, ext_storage_slot))
    {
        SendClientMessage(playerid, COLOR_WARNING, "[Storage]: This container is currently occupied by another player. Wait a second.");
        return 0;
    }

    sPlayerExternalStorageSlot[playerid] = ext_storage_slot;
    sPlayerDialogRowCount[playerid] = 0;

    new E_STORAGE_TYPE:stType = Storage_GetType(ext_storage_slot);
    new typeTitle[48];
    switch (stType)
    {
        case STORAGE_WORLD_DROP:  format(typeTitle, sizeof(typeTitle), "Bundle on the ground");
        case STORAGE_CORPSE_LOOT: format(typeTitle, sizeof(typeTitle), "Belongings of the deceased (Corpse)");
        case STORAGE_NESTED_BAG:  format(typeTitle, sizeof(typeTitle), "Inserted bag/backpack");
        default:                  format(typeTitle, sizeof(typeTitle), "External storage");
    }

    new curW = Storage_GetCurrentWeight(ext_storage_slot);
    new maxW = Storage_GetMaxWeight(ext_storage_slot);
    new curV = Storage_GetCurrentVolume(ext_storage_slot);
    new maxV = Storage_GetMaxVolume(ext_storage_slot);

    new header[144];
    format(
        header,
        sizeof(header),
        "%s | Weight: %d.%02d/%d.%02d kg | Volume: %d.%02d/%d.%02d l",
        typeTitle,
        curW / 1000, (curW % 1000) / 10,
        maxW / 1000, (maxW % 1000) / 10,
        curV / 1000, (curV % 1000) / 10,
        maxV / 1000, (maxV % 1000) / 10
    );

    static body[3584];
    body[0] = '\0';
    strcat(body, "Item in container\tQty/Pat.\tCondition\tWeight (kg)\tVolume (l)\n", sizeof(body));

    // Первая строка — вернуться в собственный инвентарь, чтобы положить предмет сюда
    strcat(body, "{FFD54F}<< Open your inventory (Place item)\t-\t-\t-\t-\n", sizeof(body));
    sPlayerDialogRowMap[playerid][sPlayerDialogRowCount[playerid]++] = INV_ROW_SWITCH_LAYER_1;

    new itemSlot = Storage_GetFirstItemSlot(ext_storage_slot);
    while (itemSlot != INVALID_ITEM_SLOT && sPlayerDialogRowCount[playerid] < MAX_DIALOG_INV_ROWS)
    {
        new defId = Storage_GetItemDefId(itemSlot);
        new amount = Storage_GetItemAmount(itemSlot);
        new ammo = Storage_GetItemAmmo(itemSlot);
        new Float:dura = Storage_GetItemDurability(itemSlot);

        new itemName[ITEM_DISPLAY_NAME_LEN];
        Item_GetName(defId, itemName, sizeof(itemName));

        new statusStr[32];
        if (defId == ITEM_ID_CLOTHING_OUTFIT)
        {
            new const outfitSkin = Storage_GetItemMetaInt1(itemSlot);
            format(itemName, sizeof(itemName), "Clothes set (skin %d)", outfitSkin);
            format(statusStr, sizeof(statusStr), "{AFAFAF}In bag{FFFFFF}");
        }
        else
        {
            format(statusStr, sizeof(statusStr), "%d%%", floatround(dura, floatround_round));
        }

        new totalW = Item_CalculateInstanceWeight(defId, amount, ammo);
        new totalV = Item_CalculateInstanceVolume(defId, amount);

        new qtyStr[32];
        if (Item_GetGtaWeaponId(defId) >= 22)
        {
            format(qtyStr, sizeof(qtyStr), "%d pcs. (%d rds.)", amount, ammo);
        }
        else if (defId == ITEM_ID_CASH_BUNDLE)
        {
            format(qtyStr, sizeof(qtyStr), "$%d", amount);
        }
        else
        {
            format(qtyStr, sizeof(qtyStr), "%d pcs.", amount);
        }

        new line[192];
        format(
            line,
            sizeof(line),
            "%s\t%s\t%s\t%d.%02d\t%d.%02d\n",
            itemName,
            qtyStr,
            statusStr,
            totalW / 1000, (totalW % 1000) / 10,
            totalV / 1000, (totalV % 1000) / 10
        );
        strcat(body, line, sizeof(body));
        sPlayerDialogRowMap[playerid][sPlayerDialogRowCount[playerid]++] = itemSlot;

        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_INV_EXTERNAL_CONTAINER,
        DIALOG_STYLE_TABLIST_HEADERS,
        header,
        body,
        "Pick up",
        "Close"
    );
    return 1;
}

/*
 * Открывает диалог досмотра (/frisk) или полного обыска (/search) целевого игрока.
 */
stock Dialogs_OpenSearchTarget(actorid, targetid, bool:includeLayer2, bool:allowConfiscate)
{
    if (!Character_IsLoaded(actorid) || !Character_IsLoaded(targetid))
    {
        return 0;
    }

    sPlayerSearchTarget[actorid] = targetid;
    sPlayerSearchIncludeLayer2[actorid] = includeLayer2;
    sPlayerSearchAllowConfiscate[actorid] = allowConfiscate;
    sPlayerDialogRowCount[actorid] = 0;

    static body[3584];
    body[0] = '\0';
    strcat(body, "Layer\tItem\tQty/Pat.\tSerial No./Info\tWeight (kg)\n", sizeof(body));

    new storages[2];
    storages[0] = Character_GetLayer1Slot(targetid);
    storages[1] = includeLayer2 ? Character_GetLayer2Slot(targetid) : INVALID_STORAGE_SLOT;

    for (new sIdx = 0; sIdx < 2; sIdx++)
    {
        new stSlot = storages[sIdx];
        if (!Storage_IsValidSlot(stSlot))
        {
            continue;
        }

        new layerLabel[20];
        if (sIdx == 0)
        {
            format(layerLabel, sizeof(layerLabel), "Layer 1 (External)");
        }
        else
        {
            format(layerLabel, sizeof(layerLabel), "Layer 2 (Cache)");
        }

        new itemSlot = Storage_GetFirstItemSlot(stSlot);
        while (itemSlot != INVALID_ITEM_SLOT && sPlayerDialogRowCount[actorid] < MAX_DIALOG_INV_ROWS)
        {
            new defId = Storage_GetItemDefId(itemSlot);
            new amount = Storage_GetItemAmount(itemSlot);
            new ammo = Storage_GetItemAmmo(itemSlot);
            new itemW = Item_CalculateInstanceWeight(defId, amount, ammo);

            new itemName[ITEM_DISPLAY_NAME_LEN];
            Item_GetName(defId, itemName, sizeof(itemName));
            if (defId == ITEM_ID_CLOTHING_OUTFIT)
            {
                new const outfitSkin = Storage_GetItemMetaInt1(itemSlot);
                format(itemName, sizeof(itemName), "Clothes set (skin %d)", outfitSkin);
            }

            new metaStr[ITEM_META_STR_LEN];
            Storage_GetItemMetaStr(itemSlot, metaStr, sizeof(metaStr));
            if (defId == ITEM_ID_CLOTHING_OUTFIT)
            {
                if (Character_IsOutfitItemEquipped(targetid, itemSlot))
                {
                    format(metaStr, sizeof(metaStr), "{66CC66}Equipped{FFFFFF}");
                }
                else
                {
                    format(metaStr, sizeof(metaStr), "{AFAFAF}In bag{FFFFFF}");
                }
            }
            else if (metaStr[0] == '\0')
            {
                format(metaStr, sizeof(metaStr), "-");
            }

            new qtyBuf[32];
            if (defId == ITEM_ID_CASH_BUNDLE)
            {
                format(qtyBuf, sizeof(qtyBuf), "$%d", amount);
            }
            else if (Item_GetGtaWeaponId(defId) >= 22)
            {
                format(qtyBuf, sizeof(qtyBuf), "%d pcs. (%d p.)", amount, ammo);
            }
            else
            {
                format(qtyBuf, sizeof(qtyBuf), "%d pcs.", amount);
            }

            new rowLine[192];
            format(
                rowLine,
                sizeof(rowLine),
                "%s\t%s\t%s\t%s\t%d.%02d\n",
                layerLabel,
                itemName,
                qtyBuf,
                metaStr,
                itemW / 1000, (itemW % 1000) / 10
            );
            strcat(body, rowLine, sizeof(body));

            new rowIdx = sPlayerDialogRowCount[actorid]++;
            sPlayerDialogRowMap[actorid][rowIdx] = itemSlot;
            sPlayerSearchStorageMap[actorid][rowIdx] = stSlot;

            itemSlot = Storage_GetNextItemSlot(itemSlot);
        }
    }

    if (sPlayerDialogRowCount[actorid] == 0)
    {
        strcat(body, "-\tNothing was found during inspection\t-\t-\t0.00\n", sizeof(body));
    }

    new targetName[MAX_PLAYER_NAME + 1];
    GetPlayerName(targetid, targetName, sizeof(targetName));

    new title[128];
    if (allowConfiscate)
    {
        format(title, sizeof(title), "Full search: %s [%d] (Confiscation available)", targetName, targetid);
    }
    else
    {
        format(title, sizeof(title), "Surface inspection (Layer 1): %s [%d]", targetName, targetid);
    }

    new actionBtn[24];
    if (allowConfiscate)
    {
        format(actionBtn, sizeof(actionBtn), "Seize");
    }
    else
    {
        format(actionBtn, sizeof(actionBtn), "Ok");
    }

    ShowPlayerDialog(
        actorid,
        DIALOG_INV_SEARCH_INSPECT,
        DIALOG_STYLE_TABLIST_HEADERS,
        title,
        body,
        actionBtn,
        "Close"
    );
    return 1;
}

// =============================================================================
//  5. ОБРАБОТЧИКИ КОНТЕКСТНОЙ КЛАВИШИ KEY_YES (Y) И ДИАЛОГОВ ИНВЕНТАРЯ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        sPlayerExternalStorageSlot[i] = INVALID_STORAGE_SLOT;
        sPlayerNestedBagSlot[i] = INVALID_STORAGE_SLOT;
        Dialogs_ResetPlayerState(i);
    }
    printf("%s [UI/Dialogs] Inventory dialog router (Layer 1/Layer 2/NESTED_BAG) and Y keys (2.5m) initialized.",
        SERVER_LOG_PREFIX);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    sPlayerExternalStorageSlot[playerid] = INVALID_STORAGE_SLOT;
    sPlayerNestedBagSlot[playerid] = INVALID_STORAGE_SLOT;
    Dialogs_ResetPlayerState(playerid);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    Dialogs_ResetPlayerState(playerid);
    return 1;
}

static stock Internal_AddActRow(
    playerid,
    body[],
    bodySize,
    E_ACT_ENTRY_TYPE:entryType,
    targetId,
    const category[],
    const objectLabel[],
    const actionLabel[])
{
    if (sPlayerActRowCount[playerid] >= MAX_ACT_MENU_ROWS)
    {
        return 0;
    }

    new const idx = sPlayerActRowCount[playerid];
    sPlayerActTypeMap[playerid][idx] = entryType;
    sPlayerActTargetMap[playerid][idx] = targetId;
    sPlayerActRowCount[playerid]++;

    new line[192];
    format(line, sizeof(line), "%s	%s	%s
", category, objectLabel, actionLabel);
    strcat(body, line, bodySize);
    return 1;
}

static stock Internal_ShowActPlayerCard(playerid, targetid)
{
    if (targetid == INVALID_PLAYER_ID || !IsPlayerConnected(targetid) || !Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Interaction]: The selected player is no longer available.");
        return 0;
    }
    if (Utils_GetDistanceBetweenPlayers(playerid, targetid) > CONTEXT_INTERACT_RADIUS_M + 0.5)
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Interaction]: The player moved too far away (maximum 3.0 m).");
        return 0;
    }

    sPlayerActSelectedPlayer[playerid] = targetid;
    sPlayerActPlayerOpCount[playerid] = 0;

    static body[1024];
    body[0] = '\0';
    strcat(body, "Action	Command Shortcut
", sizeof(body));

    sPlayerActPlayerOpMap[playerid][sPlayerActPlayerOpCount[playerid]++] = ACT_PL_GIVE_ITEM;
    strcat(body, "1. Hand over an item from inventory	/inv -> Pass nearby
", sizeof(body));

    sPlayerActPlayerOpMap[playerid][sPlayerActPlayerOpCount[playerid]++] = ACT_PL_PAY_CASH;
    strcat(body, "2. Hand over physical cash (USD)	/pay [id] [amount]
", sizeof(body));

    sPlayerActPlayerOpMap[playerid][sPlayerActPlayerOpCount[playerid]++] = ACT_PL_SHOW_PASS;
    strcat(body, "3. Show Passport / State ID	/showpass [id]
", sizeof(body));

    sPlayerActPlayerOpMap[playerid][sPlayerActPlayerOpCount[playerid]++] = ACT_PL_SHOW_LIC;
    strcat(body, "4. Show Licenses & Certificates	/showlic [id]
", sizeof(body));

    sPlayerActPlayerOpMap[playerid][sPlayerActPlayerOpCount[playerid]++] = ACT_PL_TRIAGE;
    strcat(body, "5. Medical Triage (Inspect injuries)	/triage [id]
", sizeof(body));

    sPlayerActPlayerOpMap[playerid][sPlayerActPlayerOpCount[playerid]++] = ACT_PL_TREAT;
    strcat(body, "6. Provide First Aid / Surgery	/treat [id]
", sizeof(body));

    sPlayerActPlayerOpMap[playerid][sPlayerActPlayerOpCount[playerid]++] = ACT_PL_FRISK;
    strcat(body, "7. Pat down outer gear (Layer 1)	/frisk [id]
", sizeof(body));

    sPlayerActPlayerOpMap[playerid][sPlayerActPlayerOpCount[playerid]++] = ACT_PL_SEARCH;
    strcat(body, "8. Full Search & Seizure (Layer 1 + Layer 2)	/search [id]
", sizeof(body));

    sPlayerActPlayerOpMap[playerid][sPlayerActPlayerOpCount[playerid]++] = ACT_PL_PICKPOCKET;
    strcat(body, "9. Attempt stealth pickpocket	/pickpocket [id]
", sizeof(body));

    if (!Survival_IsCuffed(targetid))
    {
        sPlayerActPlayerOpMap[playerid][sPlayerActPlayerOpCount[playerid]++] = ACT_PL_CUFF;
        strcat(body, "10. Put on Steel Handcuffs	/cuff [id]
", sizeof(body));
    }
    else
    {
        sPlayerActPlayerOpMap[playerid][sPlayerActPlayerOpCount[playerid]++] = ACT_PL_UNCUFF;
        strcat(body, "10. Remove Steel Handcuffs	/uncuff [id]
", sizeof(body));
    }

    sPlayerActPlayerOpMap[playerid][sPlayerActPlayerOpCount[playerid]++] = ACT_PL_ARREST;
    strcat(body, "11. Law Enforcement Arrest	/arrest [id]
", sizeof(body));

    new targetName[MAX_PLAYER_NAME + 1];
    Character_GetRpName(targetid, targetName, sizeof(targetName));

    new title[128];
    format(title, sizeof(title), "Player Interaction: %s [ID %d]", targetName, targetid);

    ShowPlayerDialog(
        playerid,
        DIALOG_ACT_PLAYER_CARD,
        DIALOG_STYLE_TABLIST_HEADERS,
        title,
        body,
        "Execute",
        "Back"
    );
    return 1;
}

/*
 * Контекстный сканер окружения /act (и клавиша Y).
 * Сканирует радиус 3.0 м вокруг игрока: ближайшие игроки, транспорт (внутри/снаружи),
 * мировые контейнеры (CORPSE_LOOT, WORLD_DROP), двери недвижимости, предприятия,
 * портовые терминалы, банки, сейфы организаций и физические улики.
 */
stock Dialogs_OpenActMenu(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Interaction]: Your character has not yet been loaded.");
        return 0;
    }
    if (Survival_IsCuffed(playerid))
    {
        SendClientMessage(playerid, COLOR_ERROR, "[Interaction]: Your hands are handcuffed!");
        return 0;
    }
    if (Character_GetJailSecondsLeft(playerid) > 0)
    {
        SendClientMessage(playerid, COLOR_WARNING, "[Interaction]: Most context actions are restricted while serving a prison sentence (/labor is available).");
    }

    sPlayerActRowCount[playerid] = 0;

    static body[3584];
    body[0] = '\0';
    strcat(body, "Category	Target / Object	Available Action (Command)
", sizeof(body));

    // 1. Ближайшие игроки в радиусе 3.0 м
    foreach (new targetid : Player)
    {
        if (targetid == playerid || !Character_IsLoaded(targetid))
        {
            continue;
        }
        new const Float:dist = Utils_GetDistanceBetweenPlayers(playerid, targetid);
        if (dist <= CONTEXT_INTERACT_RADIUS_M)
        {
            new rpName[MAX_PLAYER_NAME + 1], targetLabel[64];
            Character_GetRpName(targetid, rpName, sizeof(rpName));
            format(targetLabel, sizeof(targetLabel), "%s [ID %d] (%.1fm)", rpName, targetid, dist);
            Internal_AddActRow(
                playerid, body, sizeof(body),
                ACT_ENTRY_PLAYER, targetid,
                "{81D4FA}[Player]",
                targetLabel,
                "Open Player Interaction Menu >>"
            );
        }
    }

    // 2. Транспорт (внутри салона или в радиусе 3.0 м снаружи)
    new const vehSlot = Vehicle_GetNearestSlot(playerid, CONTEXT_INTERACT_RADIUS_M + 0.5);
    if (Vehicle_IsValidSlot(vehSlot))
    {
        new modelName[32], plate[16], vehLabel[64];
        Vehicle_GetSlotModelName(vehSlot, modelName, sizeof(modelName));
        Vehicle_GetSlotPlate(vehSlot, plate, sizeof(plate));
        format(vehLabel, sizeof(vehLabel), "%s [%s]", modelName, plate);

        new const bool:isLocked = Vehicle_IsSlotLocked(vehSlot);
        new const bool:isEngineOn = Vehicle_IsSlotEngineOn(vehSlot);
        new const bool:inVeh = IsPlayerInAnyVehicle(playerid);

        if (inVeh && GetPlayerState(playerid) == PLAYER_STATE_DRIVER)
        {
            Internal_AddActRow(
                playerid, body, sizeof(body),
                ACT_ENTRY_VEH_ENGINE, vehSlot,
                "{FFD54F}[Vehicle]",
                vehLabel,
                isEngineOn ? ("Stop Engine (/engine)") : ("Start Engine (/engine)")
            );
            if (!isEngineOn)
            {
                Internal_AddActRow(
                    playerid, body, sizeof(body),
                    ACT_ENTRY_VEH_HOTWIRE, vehSlot,
                    "{FFD54F}[Vehicle]",
                    vehLabel,
                    "Hotwire Ignition Wires (/hotwire)"
                );
            }
        }

        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_VEH_LOCK, vehSlot,
            "{FFD54F}[Vehicle]",
            vehLabel,
            isLocked ? ("Unlock Doors (/lock)") : ("Lock Doors (/lock)")
        );
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_VEH_TRUNK, vehSlot,
            "{FFD54F}[Vehicle]",
            vehLabel,
            "Open Vehicle Trunk (/trunk)"
        );
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_VEH_GLOVEBOX, vehSlot,
            "{FFD54F}[Vehicle]",
            vehLabel,
            "Open Glove Compartment (/glovebox)"
        );
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_VEH_REFUEL, vehSlot,
            "{FFD54F}[Vehicle]",
            vehLabel,
            "Refuel Tank (/refuel)"
        );

        if (!inVeh)
        {
            Internal_AddActRow(
                playerid, body, sizeof(body),
                ACT_ENTRY_VEH_REPAIR, vehSlot,
                "{FFD54F}[Vehicle]",
                vehLabel,
                "Field Repair with Wrench Kit (/repair)"
            );
            if (isLocked)
            {
                Internal_AddActRow(
                    playerid, body, sizeof(body),
                    ACT_ENTRY_VEH_LOCKPICK, vehSlot,
                    "{FFAB91}[Vehicle Crime]",
                    vehLabel,
                    "Pick Door Lock (/lockpick)"
                );
                Internal_AddActRow(
                    playerid, body, sizeof(body),
                    ACT_ENTRY_VEH_BREAKWINDOW, vehSlot,
                    "{FFAB91}[Vehicle Crime]",
                    vehLabel,
                    "Smash Window (/breakwindow)"
                );
            }
            if (Vehicle_IsNearChopShop(playerid, 14.0))
            {
                Internal_AddActRow(
                    playerid, body, sizeof(body),
                    ACT_ENTRY_VEH_CHOP, vehSlot,
                    "{FFAB91}[Chop Shop]",
                    vehLabel,
                    "Dismantle Vehicle for Parts (/chopshop)"
                );
            }
        }
    }

    if (Vehicle_IsNearDealership(playerid))
    {
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_VEH_BUY, 0,
            "{66CC66}[Dealership]",
            "Auto Dealership Showroom",
            "Browse & Purchase Vehicles (/vbuy)"
        );
    }

    // 3. Мировые контейнеры на земле (CORPSE_LOOT, WORLD_DROP) в радиусе 3.0 м
    new const nearContainer = Storage_FindNearestWorldContainer(playerid, CONTEXT_INTERACT_RADIUS_M);
    if (Storage_IsValidSlot(nearContainer))
    {
        sPlayerExternalStorageSlot[playerid] = nearContainer;
        new const E_STORAGE_TYPE:stType = Storage_GetType(nearContainer);
        if (stType == STORAGE_CORPSE_LOOT)
        {
            Internal_AddActRow(
                playerid, body, sizeof(body),
                ACT_ENTRY_WORLD_CONTAINER, nearContainer,
                "{FF8A65}[Corpse Loot]",
                "Deceased Person's Belongings",
                "Search & Loot Corpse Container"
            );
        }
        else
        {
            Internal_AddActRow(
                playerid, body, sizeof(body),
                ACT_ENTRY_WORLD_CONTAINER, nearContainer,
                "{81D4FA}[World Drop]",
                "Dropped Package / Stash",
                "Inspect & Pick Up Items"
            );
        }
    }

    // 4. Недвижимость и гаражи (внутри или у двери в радиусе 3.0 м)
    new propDbId = Properties_GetInsideDbId(playerid);
    if (propDbId <= 0)
    {
        Properties_GetNearestProperty(playerid, CONTEXT_INTERACT_RADIUS_M + 0.5, propDbId);
    }
    if (propDbId > 0)
    {
        new propType[32], propLabel[64];
        Properties_GetTypeNameRu(propDbId, propType, sizeof(propType));
        format(propLabel, sizeof(propLabel), "%s #%d", propType, propDbId);

        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_PROPERTY_MENU, propDbId,
            "{AED581}[Real Estate]",
            propLabel,
            "Open Property Menu (/house)"
        );
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_PROPERTY_LOCK, propDbId,
            "{AED581}[Real Estate]",
            propLabel,
            "Toggle Property Door Lock (/plock)"
        );
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_PROPERTY_PAYBILLS, propDbId,
            "{AED581}[Real Estate]",
            propLabel,
            "Pay Utility Bills (/paybills)"
        );
        if (!Properties_IsPlayerInside(playerid))
        {
            Internal_AddActRow(
                playerid, body, sizeof(body),
                ACT_ENTRY_PROPERTY_LOCKPICK, propDbId,
                "{FFAB91}[Burglary]",
                propLabel,
                "Pick Property Door Lock (/lockpick)"
            );
            if (Character_GetRoleId(playerid) == 24)
            {
                Internal_AddActRow(
                    playerid, body, sizeof(body),
                    ACT_ENTRY_PROPERTY_KICKDOOR, propDbId,
                    "{FFAB91}[SWAT Breach]",
                    propLabel,
                    "Breach Door with One Kick (/kickdoor)"
                );
            }
            Internal_AddActRow(
                playerid, body, sizeof(body),
                ACT_ENTRY_VEH_PARK, propDbId,
                "{AED581}[Garage]",
                propLabel,
                "Park Vehicle in Garage (/vpark)"
            );
            Internal_AddActRow(
                playerid, body, sizeof(body),
                ACT_ENTRY_VEH_UNPARK, propDbId,
                "{AED581}[Garage]",
                propLabel,
                "Retrieve Vehicle from Garage (/garage)"
            );
        }
    }

    // 5. Предприятия, шахты, заводы, магазины и АЗС
    new const nearEnt = Enterprise_FindNearest(playerid, 15.0);
    if (nearEnt != INVALID_ENTERPRISE_ID)
    {
        new entName[64];
        Enterprise_GetName(nearEnt, entName, sizeof(entName));
        new const E_ENTERPRISE_TYPE:entType = Enterprise_GetType(nearEnt);

        if (entType == ENTERPRISE_MINE_ORE || entType == ENTERPRISE_OIL_RIG ||
            entType == ENTERPRISE_SAWMILL || entType == ENTERPRISE_FARM)
        {
            Internal_AddActRow(
                playerid, body, sizeof(body),
                ACT_ENTRY_ENT_MINE, nearEnt,
                "{FFB74D}[Extraction]",
                entName,
                "Extract Raw Resources (/mine)"
            );
            Internal_AddActRow(
                playerid, body, sizeof(body),
                ACT_ENTRY_ENT_DELIVER, nearEnt,
                "{FFB74D}[Extraction]",
                entName,
                "Deliver Raw Material to Warehouse (/deliver)"
            );
        }
        else if (entType == ENTERPRISE_REFINERY || entType == ENTERPRISE_METALLURGY ||
                 entType == ENTERPRISE_FACTORY || entType == ENTERPRISE_CHOP_SHOP)
        {
            Internal_AddActRow(
                playerid, body, sizeof(body),
                ACT_ENTRY_ENT_CRAFT, nearEnt,
                "{FFB74D}[Production]",
                entName,
                "Open Crafting & Processing Bench (/craft)"
            );
        }

        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_ENT_BIZ, nearEnt,
            "{FFB74D}[Enterprise]",
            entName,
            "Enterprise Desk & Shop (/biz)"
        );
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_ENT_MARKET, nearEnt,
            "{FFB74D}[Enterprise]",
            entName,
            "Supply & Buy/Sell Orders (/market)"
        );
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_LAUNDER_MENU, nearEnt,
            "{CE93D8}[Cash Register]",
            entName,
            "Money Laundering Desk (/launder)"
        );
    }

    // 6. Портовые терминалы LS / SF / LV
    new const nearPort = Ports_FindNearestPort(playerid, 25.0);
    if (nearPort > 0)
    {
        new portName[48];
        Ports_GetPortNameRu(nearPort, portName, sizeof(portName));
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_PORT_MENU, nearPort,
            "{4FC3F7}[Port Hub]",
            portName,
            "Import/Export Terminal (/port)"
        );
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_CONTRACTS, nearPort,
            "{4FC3F7}[Logistics]",
            portName,
            "Freight Contracts Exchange (/contracts)"
        );
    }

    // 7. Отделения банков и банкоматы
    if (Banking_IsPlayerNearBranch(playerid))
    {
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_BANK_MENU, 0,
            "{66BB6A}[Banking]",
            "Bank Branch / ATM Terminal",
            "Open Banking Operations (/bank)"
        );
    }

    // 8. Физический сейф организации (ORG_VAULT) в радиусе 3.5 м
    new vaultOrgId = 0;
    if (Organizations_FindNearestVault(playerid, 3.5, vaultOrgId) >= 0 && vaultOrgId > 0)
    {
        new orgName[64];
        Organizations_GetName(vaultOrgId, orgName, sizeof(orgName));
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_ORG_VAULT, vaultOrgId,
            "{BA68C8}[Faction Vault]",
            orgName,
            "Access Organization Vault (/orgvault)"
        );
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_VAULT_BREACH, vaultOrgId,
            "{EF5350}[Vault Heist]",
            orgName,
            "Breach Vault Safe (/vaultbreak)"
        );
    }

    // 9. Криминалистические улики поблизости (в радиусе 12.0 м)
    new const nearEvidenceCount = Forensics_CountNearbyEvidence(playerid, 12.0);
    if (nearEvidenceCount > 0)
    {
        new evLabel[48];
        format(evLabel, sizeof(evLabel), "Crime Scene (%d trace(s) within 12m)", nearEvidenceCount);
        Internal_AddActRow(
            playerid, body, sizeof(body),
            ACT_ENTRY_FORENSICS, nearEvidenceCount,
            "{FFF176}[Forensics]",
            evLabel,
            "Inspect & Collect Evidence (/evidence)"
        );
    }

    // 10. Базовые быстрые действия персонажа (всегда доступны)
    Internal_AddActRow(
        playerid, body, sizeof(body),
        ACT_ENTRY_SELF_INV, 0,
        "{ECEFF1}[Self]",
        "Dual-Layer Inventory (Key N)",
        "Open Personal Inventory (/inv)"
    );
    Internal_AddActRow(
        playerid, body, sizeof(body),
        ACT_ENTRY_SELF_MM, 0,
        "{ECEFF1}[Self]",
        "Main Menu & Codex (Key H / LALT)",
        "Open Character Menu & Help (/mm)"
    );

    ShowPlayerDialog(
        playerid,
        DIALOG_INV_CONTEXT_MENU_Y,
        DIALOG_STYLE_TABLIST_HEADERS,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Context Interaction Scanner (/act | Key Y)",
        body,
        "Select",
        "Close"
    );
    return 1;
}

CMD:act(playerid, params[])
{
    #pragma unused params
    Dialogs_OpenActMenu(playerid);
    return 1;
}
alias:act("interact", "action");

/*
 * Единый обработчик горячих клавиш (Command-First & Keybind-Wrapper, Фаза 12):
 * - KEY_YES (Y)            -> вызывает cmd_act (/act — контекстное меню взаимодействия)
 * - KEY_NO (N)             -> вызывает cmd_inv (/inv — двухслойный инвентарь)
 * - KEY_CTRL_BACK (H) /
 *   KEY_WALK (LALT пешком) -> вызывает MainMenu_Open (/mm — главное меню персонажа)
 */
hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }

    new const bool:pressedY = ((newkeys & KEY_YES) != KEY:0) && ((oldkeys & KEY_YES) == KEY:0);
    new const bool:pressedN = ((newkeys & KEY_NO) != KEY:0) && ((oldkeys & KEY_NO) == KEY:0);
    new const bool:pressedH = ((newkeys & KEY_CTRL_BACK) != KEY:0) && ((oldkeys & KEY_CTRL_BACK) == KEY:0);
    new const bool:pressedAlt = (GetPlayerState(playerid) == PLAYER_STATE_ONFOOT) &&
                                ((newkeys & KEY_WALK) != KEY:0) && ((oldkeys & KEY_WALK) == KEY:0);

    if (!pressedY && !pressedN && !pressedH && !pressedAlt)
    {
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sPlayerLastKeybindTick[playerid]) < KEYBIND_INTERACT_COOLDOWN_MS)
    {
        return 1;
    }
    sPlayerLastKeybindTick[playerid] = nowTick;

    if (pressedY)
    {
        pc_cmd_act(playerid, sDialogEmptyCmdParams);
        return 1;
    }
    if (pressedN)
    {
        pc_cmd_inv(playerid, sDialogEmptyCmdParams);
        return 1;
    }
    if (pressedH || pressedAlt)
    {
        pc_cmd_mm(playerid, sDialogEmptyCmdParams);
        return 1;
    }
    return 1;
}

static stock Internal_ShowItemActionMenu(playerid, item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }

    sPlayerSelectedItemSlot[playerid] = item_slot;
    new defId = Storage_GetItemDefId(item_slot);
    new amount = Storage_GetItemAmount(item_slot);

    new itemName[ITEM_DISPLAY_NAME_LEN];
    Item_GetName(defId, itemName, sizeof(itemName));

    new title[128];
    format(title, sizeof(title), "Item: %s (%d pcs.)", itemName, amount);

    new actions[512];
    actions[0] = '\0';
    if (defId == ITEM_ID_CLOTHING_OUTFIT)
    {
        if (Storage_GetItemMetaInt2(item_slot) == CLOTHING_STATE_EQUIPPED)
        {
            strcat(actions, "1. {FFC800}Remove and put in bag{FFFFFF}\n", sizeof(actions));
        }
        else
        {
            strcat(actions, "1. {66CC66}Put on {FFFFFF}\n", sizeof(actions));
        }
    }
    else
    {
        strcat(actions, "1. Use/Equip\n", sizeof(actions));
    }
    strcat(actions, "2. Open (for enclosed backpack/bag)\n", sizeof(actions));
    strcat(actions, "3. Split / Combine pack\n", sizeof(actions));
    strcat(actions, "4. Transfer to another layer (Layer 1 <-> Layer 2)\n", sizeof(actions));
    strcat(actions, "5. Transfer to external storage\n", sizeof(actions));
    strcat(actions, "6. Drop onto the ground\n", sizeof(actions));
    strcat(actions, "7. Pass it to the person nearby", sizeof(actions));

    ShowPlayerDialog(
        playerid,
        DIALOG_INV_ITEM_ACTIONS,
        DIALOG_STYLE_LIST,
        title,
        actions,
        "Select",
        "Back"
    );
    return 1;
}

static stock Internal_ExecutePendingItemOp(playerid, amount)
{
    new srcSlot = sPlayerActiveStorageSlot[playerid];
    new itemSlot = sPlayerSelectedItemSlot[playerid];
    new E_INV_PENDING_OP:op = sPlayerPendingOp[playerid];
    sPlayerPendingOp[playerid] = INV_OP_NONE;

    if (op == INV_OP_TAKE_FROM_EXTERNAL)
    {
        new extSlot = sPlayerExternalStorageSlot[playerid];
        new dstLayer1 = Character_GetLayer1Slot(playerid);
        if (!Storage_IsValidSlot(extSlot) || !Storage_IsValidItemSlot(itemSlot) || !Storage_IsValidSlot(dstLayer1))
        {
            return 0;
        }

        new avail = Storage_GetItemAmount(itemSlot);
        if (amount <= 0 || amount > avail) amount = avail;

        new E_STORAGE_RESULT:res = Storage_TransferItem(playerid, extSlot, itemSlot, dstLayer1, amount, Character_GetId(playerid));
        if (res == STORAGE_RES_OK)
        {
            Storage_DestroyExpiredOrEmpty(extSlot);
            Character_SyncLayer1Weapons(playerid);
            Character_SyncInventorySkin(playerid);
            Survival_RecalculateEncumbrance(playerid);
            SendClientMessage(playerid, COLOR_SUCCESS, "[Inventory]: The item has been moved to your external inventory (Layer 1).");
        }
        else if (res == STORAGE_RES_WEIGHT_EXCEEDED)
        {
            SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Insufficient carrying capacity! Layer 1 weight limit exceeded.");
        }
        else if (res == STORAGE_RES_VOLUME_EXCEEDED)
        {
            SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: There is not enough free capacity (liters) in inventory.");
        }
        else
        {
            SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Failed to move item (container restriction code).");
        }

        if (Storage_IsValidSlot(extSlot))
        {
            Dialogs_OpenExternalContainer(playerid, extSlot);
        }
        else
        {
            sPlayerExternalStorageSlot[playerid] = INVALID_STORAGE_SLOT;
            Dialogs_OpenInventory(playerid, INV_VIEW_LAYER_1);
        }
        return 1;
    }

    if (!Storage_IsValidSlot(srcSlot) || !Storage_IsValidItemSlot(itemSlot))
    {
        return 0;
    }

    new avail = Storage_GetItemAmount(itemSlot);
    if (amount <= 0 || amount > avail)
    {
        amount = avail;
    }

    switch (op)
    {
        case INV_OP_SPLIT_STACK:
        {
            new defId = Storage_GetItemDefId(itemSlot);
            if (!Item_IsStackable(defId) || avail <= 1 || amount >= avail)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Specify a quantity less than the current pack size to split.");
                Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                return 1;
            }
            new Float:dura = Storage_GetItemDurability(itemSlot);
            new meta1 = Storage_GetItemMetaInt1(itemSlot);
            new meta2 = Storage_GetItemMetaInt2(itemSlot);
            new metaStr[ITEM_META_STR_LEN];
            Storage_GetItemMetaStr(itemSlot, metaStr, sizeof(metaStr));

            if (Storage_RemoveItem(srcSlot, itemSlot, amount))
            {
                Storage_AddItem(srcSlot, defId, amount, 0, dura, meta1, meta2, metaStr);
                SendClientMessage(playerid, COLOR_SUCCESS, "[Inventory]: The pack has been successfully divided into two parts.");
            }
            Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
        }
        case INV_OP_MOVE_TO_OTHER_LAYER:
        {
            new layer1 = Character_GetLayer1Slot(playerid);
            new layer2 = Character_GetLayer2Slot(playerid);
            new dstSlot = (srcSlot == layer1) ? layer2 : layer1;

            new E_STORAGE_RESULT:res = Storage_TransferItem(playerid, srcSlot, itemSlot, dstSlot, amount, Character_GetId(playerid));
            if (res == STORAGE_RES_OK)
            {
                Character_SyncLayer1Weapons(playerid);
                Character_SyncInventorySkin(playerid);
                Survival_RecalculateEncumbrance(playerid);
                SendClientMessage(playerid, COLOR_SUCCESS, "[Inventory]: The item has been successfully moved to another inventory layer.");
            }
            else if (res == STORAGE_RES_LAYER2_FORBIDDEN)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: This item is too large for a secret pocket (Layer 2)!");
            }
            else if (res == STORAGE_RES_WEIGHT_EXCEEDED)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Target layer weight limit exceeded!");
            }
            else if (res == STORAGE_RES_VOLUME_EXCEEDED)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Target layer volume limit exceeded!");
            }
            else
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Move rejected by inventory system.");
            }
            Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
        }
        case INV_OP_MOVE_TO_EXTERNAL:
        {
            new extSlot = sPlayerExternalStorageSlot[playerid];
            if (!Storage_IsValidSlot(extSlot))
            {
                extSlot = Storage_FindNearestWorldContainer(playerid, CONTEXT_INTERACT_RADIUS_M);
            }
            if (!Storage_IsValidSlot(extSlot))
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: There is no open external storage nearby (2.5m radius).");
                Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                return 1;
            }

            new E_STORAGE_RESULT:res = Storage_TransferItem(playerid, srcSlot, itemSlot, extSlot, amount, Character_GetId(playerid));
            if (res == STORAGE_RES_OK)
            {
                Character_SyncLayer1Weapons(playerid);
                Character_SyncInventorySkin(playerid);
                Survival_RecalculateEncumbrance(playerid);
                SendClientMessage(playerid, COLOR_SUCCESS, "[Inventory]: The item has been moved to external storage.");
            }
            else if (res == STORAGE_RES_NESTING_LIMIT)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: It is prohibited to place a bag/container inside another bag!");
            }
            else
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Storage space is insufficient by weight or volume.");
            }
            Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
        }
        case INV_OP_DROP_TO_GROUND:
        {
            new Float:x = 0.0, Float:y = 0.0, Float:z = 0.0;
            GetPlayerPos(playerid, x, y, z);
            new worldId = GetPlayerVirtualWorld(playerid);
            new interiorId = GetPlayerInterior(playerid);

            new dropSlot = Storage_FindNearestWorldContainer(playerid, 1.8);
            if (!Storage_IsValidSlot(dropSlot) || Storage_GetType(dropSlot) != STORAGE_WORLD_DROP)
            {
                dropSlot = Storage_CreateWorldDrop(x, y, z, worldId, interiorId);
            }

            if (!Storage_IsValidSlot(dropSlot))
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: The limit of world containers on earth has been reached.");
                Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                return 1;
            }

            new E_STORAGE_RESULT:res = Storage_TransferItem(playerid, srcSlot, itemSlot, dropSlot, amount, Character_GetId(playerid));
            if (res == STORAGE_RES_OK)
            {
                ApplyAnimation(playerid, "BOMBER", "BOM_Plant", 4.1, false, false, false, false, 0, SYNC_ALL);
                Character_SyncLayer1Weapons(playerid);
                Character_SyncInventorySkin(playerid);
                Survival_RecalculateEncumbrance(playerid);
                SendClientMessage(playerid, COLOR_INFO, "[Inventory]: You placed an item on the ground.");
            }
            else
            {
                Storage_DestroyExpiredOrEmpty(dropSlot);
                SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Failed to throw item on the ground.");
            }
            Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
        }
        default:
        {
        }
    }
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch (dialogid)
    {
        case DIALOG_INV_CONTEXT_MENU_Y:
        {
            if (!response) return Y_HOOKS_BREAK_RETURN_1;
            if (listitem < 0 || listitem >= sPlayerActRowCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (Survival_IsCuffed(playerid))
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Interaction]: Your hands are handcuffed!");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const E_ACT_ENTRY_TYPE:entryType = sPlayerActTypeMap[playerid][listitem];
            new const targetVal = sPlayerActTargetMap[playerid][listitem];

            switch (entryType)
            {
                case ACT_ENTRY_PLAYER:
                {
                    Internal_ShowActPlayerCard(playerid, targetVal);
                }
                case ACT_ENTRY_VEH_ENGINE:      pc_cmd_vengine(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VEH_LOCK:        pc_cmd_vlock(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VEH_TRUNK:       pc_cmd_trunk(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VEH_GLOVEBOX:    pc_cmd_glovebox(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VEH_REFUEL:      pc_cmd_refuel(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VEH_REPAIR:      pc_cmd_repair(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VEH_LOCKPICK:    pc_cmd_lockpick(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VEH_BREAKWINDOW: pc_cmd_breakwindow(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VEH_HOTWIRE:     pc_cmd_hotwire(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VEH_CHOP:        pc_cmd_chop(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VEH_PARK:        pc_cmd_vpark(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VEH_UNPARK:      pc_cmd_vunpark(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VEH_BUY:         pc_cmd_vbuy(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_WORLD_CONTAINER:
                {
                    new const nearSlot = Storage_FindNearestWorldContainer(playerid, CONTEXT_INTERACT_RADIUS_M);
                    if (Storage_IsValidSlot(nearSlot))
                    {
                        Dialogs_OpenExternalContainer(playerid, nearSlot);
                    }
                    else
                    {
                        SendClientMessage(playerid, COLOR_WARNING, "[Interaction]: The container nearby is no longer available.");
                    }
                }
                case ACT_ENTRY_PROPERTY_MENU:     pc_cmd_property(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_PROPERTY_LOCK:     pc_cmd_plock(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_PROPERTY_PAYBILLS: pc_cmd_payutils(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_PROPERTY_LOCKPICK: pc_cmd_lockpick(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_PROPERTY_KICKDOOR: pc_cmd_kickdoor(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_ENT_MINE:          pc_cmd_mine(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_ENT_DELIVER:       pc_cmd_deliver(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_ENT_CRAFT:         pc_cmd_craft(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_ENT_BIZ:           pc_cmd_enterprise(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_ENT_MARKET:        pc_cmd_market(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_PORT_MENU:         pc_cmd_port(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_CONTRACTS:         pc_cmd_contracts(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_BANK_MENU:         pc_cmd_bank(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_LAUNDER_MENU:      pc_cmd_launder(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_ORG_VAULT:         pc_cmd_orgvault(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_VAULT_BREACH:      pc_cmd_vaultbreak(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_FORENSICS:         pc_cmd_evidence(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_SELF_INV:          pc_cmd_inv(playerid, sDialogEmptyCmdParams);
                case ACT_ENTRY_SELF_MM:           pc_cmd_mm(playerid, sDialogEmptyCmdParams);
                default: {}
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ACT_PLAYER_CARD:
        {
            if (!response)
            {
                Dialogs_OpenActMenu(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sPlayerActPlayerOpCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const targetid = sPlayerActSelectedPlayer[playerid];
            if (targetid == INVALID_PLAYER_ID || !IsPlayerConnected(targetid) || !Character_IsLoaded(targetid))
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Interaction]: The target player has disconnected.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (Utils_GetDistanceBetweenPlayers(playerid, targetid) > CONTEXT_INTERACT_RADIUS_M + 0.5)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Interaction]: The target player is too far away (maximum 3.0 m).");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new argBuf[16];
            format(argBuf, sizeof(argBuf), "%d", targetid);

            switch (sPlayerActPlayerOpMap[playerid][listitem])
            {
                case ACT_PL_GIVE_ITEM:
                {
                    Dialogs_OpenInventory(playerid, INV_VIEW_LAYER_1);
                    SendClientMessage(playerid, COLOR_INFO, "[Tip]: Click on any item in your inventory and select '7. Pass it to the person nearby'.");
                }
                case ACT_PL_PAY_CASH:
                {
                    new targetName[MAX_PLAYER_NAME + 1], prompt[256];
                    Character_GetRpName(targetid, targetName, sizeof(targetName));
                    format(prompt, sizeof(prompt),
                        "Enter the amount of physical cash (USD) to hand over to %s [ID %d]:
(Your current pocket cash: $%d)",
                        targetName, targetid, Character_GetPhysicalCashUsd(playerid));
                    ShowPlayerDialog(
                        playerid,
                        DIALOG_ACT_PAY_INPUT,
                        DIALOG_STYLE_INPUT,
                        "Hand Over Cash (/pay)",
                        prompt,
                        "Pay",
                        "Back"
                    );
                }
                case ACT_PL_SHOW_PASS:  pc_cmd_showpass(playerid, argBuf);
                case ACT_PL_SHOW_LIC:   pc_cmd_showlic(playerid, argBuf);
                case ACT_PL_TRIAGE:     pc_cmd_triage(playerid, argBuf);
                case ACT_PL_TREAT:      pc_cmd_treat(playerid, argBuf);
                case ACT_PL_FRISK:      pc_cmd_frisk(playerid, argBuf);
                case ACT_PL_SEARCH:     pc_cmd_search(playerid, argBuf);
                case ACT_PL_PICKPOCKET: pc_cmd_pickpocket(playerid, argBuf);
                case ACT_PL_CUFF:       pc_cmd_cuff(playerid, argBuf);
                case ACT_PL_UNCUFF:     pc_cmd_uncuff(playerid, argBuf);
                case ACT_PL_ARREST:     pc_cmd_arrest(playerid, argBuf);
                default: {}
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_ACT_PAY_INPUT:
        {
            new const targetid = sPlayerActSelectedPlayer[playerid];
            if (!response)
            {
                if (targetid != INVALID_PLAYER_ID && IsPlayerConnected(targetid) && Character_IsLoaded(targetid))
                {
                    Internal_ShowActPlayerCard(playerid, targetid);
                }
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new const amount = strval(inputtext);
            if (amount <= 0)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Cash]: Please enter a positive USD amount.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new payParams[32];
            format(payParams, sizeof(payParams), "%d %d", targetid, amount);
            pc_cmd_pay(playerid, payParams);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_INV_MAIN_LIST:
        {
            if (!response)
            {
                if (Storage_IsValidSlot(sPlayerNestedBagSlot[playerid]))
                {
                    Storage_CloseForPlayer(playerid, sPlayerNestedBagSlot[playerid]);
                    sPlayerNestedBagSlot[playerid] = INVALID_STORAGE_SLOT;
                }
                return Y_HOOKS_BREAK_RETURN_1;
            }

            if (listitem < 0 || listitem >= sPlayerDialogRowCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new mappedCode = sPlayerDialogRowMap[playerid][listitem];
            if (mappedCode == INV_ROW_SWITCH_LAYER_2)
            {
                Dialogs_OpenInventory(playerid, INV_VIEW_LAYER_2);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (mappedCode == INV_ROW_SWITCH_LAYER_1)
            {
                Dialogs_OpenInventory(playerid, INV_VIEW_LAYER_1);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (mappedCode == INV_ROW_OPEN_EXTERNAL)
            {
                new nearSlot = Storage_FindNearestWorldContainer(playerid, CONTEXT_INTERACT_RADIUS_M);
                if (Storage_IsValidSlot(nearSlot))
                {
                    Dialogs_OpenExternalContainer(playerid, nearSlot);
                }
                else
                {
                    SendClientMessage(playerid, COLOR_WARNING, "[Inventory]: The container nearby is no longer available.");
                    Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                }
                return Y_HOOKS_BREAK_RETURN_1;
            }

            if (Storage_IsValidItemSlot(mappedCode))
            {
                Internal_ShowItemActionMenu(playerid, mappedCode);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_INV_ITEM_ACTIONS:
        {
            if (!response)
            {
                Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new itemSlot = sPlayerSelectedItemSlot[playerid];
            new srcSlot = sPlayerActiveStorageSlot[playerid];
            if (!Storage_IsValidSlot(srcSlot) || !Storage_IsValidItemSlot(itemSlot))
            {
                Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new defId = Storage_GetItemDefId(itemSlot);
            new amount = Storage_GetItemAmount(itemSlot);

            switch (listitem)
            {
                case 0: // 1. Использовать / Экипировать
                {
                    Survival_UseInventoryItem(playerid, srcSlot, itemSlot);
                    Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                }
                case 1: // 2. Открыть (для вложенного рюкзака / сумки)
                {
                    if (!Item_IsContainer(defId))
                    {
                        SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: This item is not a bag, backpack or container.");
                        Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    new nestedSlot = Storage_GetItemNestedSlot(itemSlot);
                    if (!Storage_IsValidSlot(nestedSlot))
                    {
                        SendClientMessage(playerid, COLOR_WARNING, "[Inventory]: The interior of this bag is empty or has not yet been initialized.");
                        Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    sPlayerNestedBagSlot[playerid] = nestedSlot;
                    Storage_OpenForPlayer(playerid, nestedSlot);
                    Dialogs_OpenInventory(playerid, INV_VIEW_NESTED_BAG);
                }
                case 2: // 3. Разделить / Объединить пачку
                {
                    if (!Item_IsStackable(defId))
                    {
                        SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: This item cannot be stacked.");
                        Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    new merged = Internal_MergeSimilarStacks(srcSlot, itemSlot);
                    if (merged > 0)
                    {
                        SendClientMessage(playerid, COLOR_SUCCESS, "[Inventory]: Similar item packs are combined.");
                        Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    if (amount <= 1)
                    {
                        SendClientMessage(playerid, COLOR_GRAY, "[Inventory]: There is only 1 piece in a pack, division is not possible.");
                        Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    sPlayerPendingOp[playerid] = INV_OP_SPLIT_STACK;
                    ShowPlayerDialog(
                        playerid,
                        DIALOG_INV_INPUT_AMOUNT,
                        DIALOG_STYLE_INPUT,
                        "Separating a stack of items",
                        "Enter the number of units to be separated into a new pack:",
                        "Separate",
                        "Cancel"
                    );
                }
                case 3: // 4. Переложить в другой слой (Слой 1 <-> Слой 2)
                {
                    if (amount > 1)
                    {
                        sPlayerPendingOp[playerid] = INV_OP_MOVE_TO_OTHER_LAYER;
                        ShowPlayerDialog(
                            playerid,
                            DIALOG_INV_INPUT_AMOUNT,
                            DIALOG_STYLE_INPUT,
                            "Moving between inventory layers",
                            "Enter the number of units to move to another layer:",
                            "Rearrange",
                            "Cancel"
                        );
                    }
                    else
                    {
                        sPlayerPendingOp[playerid] = INV_OP_MOVE_TO_OTHER_LAYER;
                        Internal_ExecutePendingItemOp(playerid, 1);
                    }
                }
                case 4: // 5. Переложить во внешнее хранилище
                {
                    if (amount > 1)
                    {
                        sPlayerPendingOp[playerid] = INV_OP_MOVE_TO_EXTERNAL;
                        ShowPlayerDialog(
                            playerid,
                            DIALOG_INV_INPUT_AMOUNT,
                            DIALOG_STYLE_INPUT,
                            "Moving to external storage",
                            "Enter the number of units to move into the nearby container:",
                            "Rearrange",
                            "Cancel"
                        );
                    }
                    else
                    {
                        sPlayerPendingOp[playerid] = INV_OP_MOVE_TO_EXTERNAL;
                        Internal_ExecutePendingItemOp(playerid, 1);
                    }
                }
                case 5: // 6. Выбросить на землю
                {
                    if (amount > 1)
                    {
                        sPlayerPendingOp[playerid] = INV_OP_DROP_TO_GROUND;
                        ShowPlayerDialog(
                            playerid,
                            DIALOG_INV_INPUT_AMOUNT,
                            DIALOG_STYLE_INPUT,
                            "Throw an item on the ground",
                            "Enter the number of units you want to drop on the ground:",
                            "Throw away",
                            "Cancel"
                        );
                    }
                    else
                    {
                        sPlayerPendingOp[playerid] = INV_OP_DROP_TO_GROUND;
                        Internal_ExecutePendingItemOp(playerid, 1);
                    }
                }
                case 6: // 7. Передать человеку рядом
                {
                    new nearestId = INVALID_PLAYER_ID;
                    new Float:minDist = 999.0;
                    foreach (new targetid : Player)
                    {
                        if (targetid == playerid || !Character_IsLoaded(targetid)) continue;
                        new Float:dist = Utils_GetDistanceBetweenPlayers(playerid, targetid);
                        if (dist <= 3.0 && dist < minDist)
                        {
                            minDist = dist;
                            nearestId = targetid;
                        }
                    }

                    if (nearestId == INVALID_PLAYER_ID)
                    {
                        SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: There are no players nearby to transfer the item (up to 3.0 m).");
                        Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                        return Y_HOOKS_BREAK_RETURN_1;
                    }

                    new targetLayer1 = Character_GetLayer1Slot(nearestId);
                    if (!Storage_IsValidSlot(targetLayer1))
                    {
                        SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Error accessing recipient's inventory.");
                        Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                        return Y_HOOKS_BREAK_RETURN_1;
                    }

                    new E_STORAGE_RESULT:res = Storage_TransferItem(playerid, srcSlot, itemSlot, targetLayer1, 1, Character_GetId(playerid));
                    if (res == STORAGE_RES_OK)
                    {
                        Character_SyncLayer1Weapons(playerid);
                        Character_SyncLayer1Weapons(nearestId);
                        Character_SyncInventorySkin(playerid);
                        Character_SyncInventorySkin(nearestId);
                        Survival_RecalculateEncumbrance(playerid);
                        Survival_RecalculateEncumbrance(nearestId);

                        new actorName[MAX_PLAYER_NAME + 8];
                        new targetName[MAX_PLAYER_NAME + 8];
                        new itemNameBuf[ITEM_DISPLAY_NAME_LEN];
                        Item_GetName(defId, itemNameBuf, sizeof(itemNameBuf));
                        GetPlayerName(playerid, actorName, sizeof(actorName));
                        GetPlayerName(nearestId, targetName, sizeof(targetName));

                        new alertMsg[128];
                        format(alertMsg, sizeof(alertMsg), "[Transfer]: You passed \"%s\" to player %s.", itemNameBuf, targetName);
                        SendClientMessage(playerid, COLOR_SUCCESS, alertMsg);

                        format(alertMsg, sizeof(alertMsg), "[Transmission]: You received \"%s\" from %s.", itemNameBuf, actorName);
                        SendClientMessage(nearestId, COLOR_SUCCESS, alertMsg);
                    }
                    else if (res == STORAGE_RES_WEIGHT_EXCEEDED)
                    {
                        SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: The recipient's inventory is full by weight.");
                    }
                    else if (res == STORAGE_RES_VOLUME_EXCEEDED)
                    {
                        SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: The recipient does not have enough space in terms of volume (liters).");
                    }
                    else
                    {
                        SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Failed to transfer item.");
                    }
                    Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_INV_INPUT_AMOUNT:
        {
            if (!response)
            {
                sPlayerPendingOp[playerid] = INV_OP_NONE;
                Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new qty = strval(inputtext);
            if (qty <= 0)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Inventory]: Please enter a valid positive number.");
                Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ExecutePendingItemOp(playerid, qty);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_INV_EXTERNAL_CONTAINER:
        {
            new extSlot = sPlayerExternalStorageSlot[playerid];
            if (!response)
            {
                if (Storage_IsValidSlot(extSlot))
                {
                    Storage_CloseForPlayer(playerid, extSlot);
                }
                sPlayerExternalStorageSlot[playerid] = INVALID_STORAGE_SLOT;
                return Y_HOOKS_BREAK_RETURN_1;
            }

            if (listitem < 0 || listitem >= sPlayerDialogRowCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new mapped = sPlayerDialogRowMap[playerid][listitem];
            if (mapped == INV_ROW_SWITCH_LAYER_1)
            {
                Dialogs_OpenInventory(playerid, INV_VIEW_LAYER_1);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            if (Storage_IsValidSlot(extSlot) && Storage_IsValidItemSlot(mapped))
            {
                sPlayerSelectedItemSlot[playerid] = mapped;
                new avail = Storage_GetItemAmount(mapped);
                if (avail > 1)
                {
                    sPlayerPendingOp[playerid] = INV_OP_TAKE_FROM_EXTERNAL;
                    ShowPlayerDialog(
                        playerid,
                        DIALOG_INV_INPUT_AMOUNT,
                        DIALOG_STYLE_INPUT,
                        "Pick up an item from storage",
                        "Enter the number of units you want to take into Layer 1:",
                        "Pick up",
                        "Cancel"
                    );
                }
                else
                {
                    sPlayerPendingOp[playerid] = INV_OP_TAKE_FROM_EXTERNAL;
                    Internal_ExecutePendingItemOp(playerid, 1);
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_INV_SEARCH_INSPECT:
        {
            if (!response || !sPlayerSearchAllowConfiscate[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new targetid = sPlayerSearchTarget[playerid];
            if (targetid == INVALID_PLAYER_ID || !Character_IsLoaded(targetid))
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Search]: The player being searched has left the server.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (Utils_GetDistanceBetweenPlayers(playerid, targetid) > 3.5)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Search]: The player is too far from you.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sPlayerDialogRowCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new itemSlot = sPlayerDialogRowMap[playerid][listitem];
            new srcStorage = sPlayerSearchStorageMap[playerid][listitem];
            new actorLayer1 = Character_GetLayer1Slot(playerid);

            if (!Storage_IsValidSlot(srcStorage) || !Storage_IsValidItemSlot(itemSlot) || !Storage_IsValidSlot(actorLayer1))
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new defId = Storage_GetItemDefId(itemSlot);
            new amount = Storage_GetItemAmount(itemSlot);
            new itemName[ITEM_DISPLAY_NAME_LEN];
            Item_GetName(defId, itemName, sizeof(itemName));

            new E_STORAGE_RESULT:res = Storage_TransferItem(playerid, srcStorage, itemSlot, actorLayer1, amount, Character_GetId(playerid));
            if (res == STORAGE_RES_OK)
            {
                Character_SyncLayer1Weapons(targetid);
                Character_SyncLayer1Weapons(playerid);
                Character_SyncInventorySkin(targetid);
                Character_SyncInventorySkin(playerid);
                Survival_RecalculateEncumbrance(targetid);
                Survival_RecalculateEncumbrance(playerid);

                new msg[160];
                format(msg, sizeof(msg), "[Search]: You seized \"%s\" (%d pcs.) from the detainee.", itemName, amount);
                SendClientMessage(playerid, COLOR_SUCCESS, msg);

                format(msg, sizeof(msg), "[Search]: During the search, \"%s\" (%d pcs.) was confiscated from you.", itemName, amount);
                SendClientMessage(targetid, COLOR_WARNING, msg);

                Dialogs_OpenSearchTarget(playerid, targetid, sPlayerSearchIncludeLayer2[playerid], true);
            }
            else
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Search]: There is not enough space in your inventory (Layer 1) to retrieve the item.");
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_0;
}

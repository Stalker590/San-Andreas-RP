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

#define MAX_DIALOG_INV_ROWS                     (64)
#define CONTEXT_INTERACT_RADIUS_M               (2.5)

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
        SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Ваш персонаж еще не загружен.");
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
        SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Ошибка доступа к контейнеру инвентаря.");
        return 0;
    }

    if (!Storage_AreItemsReady(targetStorage))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Инвентарь]: Инвентарь еще загружается. Повторите команду через мгновение.");
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
            "Инвентарь: Слой 1 (Внешний) | Вес: %d.%02d/%d.%02d кг | Объем: %d.%02d/%d.%02d л",
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
            "Инвентарь: Слой 2 (Потайной) | Вес: %d.%02d/%d.%02d кг | Объем: %d.%02d/%d.%02d л",
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
            "Рюкзак / Сумка (Вложенный) | Вес: %d.%02d/%d.%02d кг | Объем: %d.%02d/%d.%02d л",
            curWeightG / 1000, (curWeightG % 1000) / 10,
            maxWeightG / 1000, (maxWeightG % 1000) / 10,
            curVolumeMl / 1000, (curVolumeMl % 1000) / 10,
            maxVolumeMl / 1000, (maxVolumeMl % 1000) / 10
        );
    }

    static dialogBody[3584];
    dialogBody[0] = '\0';
    strcat(dialogBody, "Предмет / Действие\tКол-во / Патр.\tСостояние\tВес (кг)\tОбъем (л)\n", sizeof(dialogBody));

    // Первая строка: быстрое переключение между Слоем 1 и Слоем 2
    if (viewMode == INV_VIEW_LAYER_1)
    {
        new l2W = Storage_IsValidSlot(layer2Slot) ? Storage_GetCurrentWeight(layer2Slot) : 0;
        new l2MaxW = Storage_IsValidSlot(layer2Slot) ? Storage_GetMaxWeight(layer2Slot) : 2000;
        new switchRow[160];
        format(
            switchRow,
            sizeof(switchRow),
            "{FFD54F}>> Переключить: Слой 2 (Потайной карман)\t-\t-\t%d.%02d/%d.%02d\t-\n",
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
            "{FFD54F}<< Вернуться: Слой 1 (Внешний инвентарь)\t-\t-\t%d.%02d/%d.%02d\t-\n",
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
            "{81D4FA}[Открыть ближайшее хранилище / сверток рядом]\t-\t-\t%d.%02d кг\t-\n",
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
            format(itemName, sizeof(itemName), "Комплект одежды (скин %d)", outfitSkin);
            if (Character_IsOutfitItemEquipped(playerid, itemSlot))
            {
                format(statusStr, sizeof(statusStr), "{66CC66}Надето{FFFFFF}");
            }
            else
            {
                format(statusStr, sizeof(statusStr), "{AFAFAF}В сумке{FFFFFF}");
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
            format(qtyStr, sizeof(qtyStr), "%d шт. (%d патр.)", amount, ammo);
        }
        else if (defId == ITEM_ID_CASH_BUNDLE)
        {
            format(qtyStr, sizeof(qtyStr), "$%d", amount);
        }
        else
        {
            format(qtyStr, sizeof(qtyStr), "%d шт.", amount);
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
        "Действие",
        "Закрыть"
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
        SendClientMessage(playerid, COLOR_WARNING, "[Хранилище]: Этот контейнер сейчас занят другим игроком. Подождите секунду.");
        return 0;
    }

    sPlayerExternalStorageSlot[playerid] = ext_storage_slot;
    sPlayerDialogRowCount[playerid] = 0;

    new E_STORAGE_TYPE:stType = Storage_GetType(ext_storage_slot);
    new typeTitle[48];
    switch (stType)
    {
        case STORAGE_WORLD_DROP:  format(typeTitle, sizeof(typeTitle), "Сверток на земле");
        case STORAGE_CORPSE_LOOT: format(typeTitle, sizeof(typeTitle), "Вещи погибшего (Труп)");
        case STORAGE_NESTED_BAG:  format(typeTitle, sizeof(typeTitle), "Вложенная сумка / рюкзак");
        default:                  format(typeTitle, sizeof(typeTitle), "Внешнее хранилище");
    }

    new curW = Storage_GetCurrentWeight(ext_storage_slot);
    new maxW = Storage_GetMaxWeight(ext_storage_slot);
    new curV = Storage_GetCurrentVolume(ext_storage_slot);
    new maxV = Storage_GetMaxVolume(ext_storage_slot);

    new header[144];
    format(
        header,
        sizeof(header),
        "%s | Вес: %d.%02d/%d.%02d кг | Объем: %d.%02d/%d.%02d л",
        typeTitle,
        curW / 1000, (curW % 1000) / 10,
        maxW / 1000, (maxW % 1000) / 10,
        curV / 1000, (curV % 1000) / 10,
        maxV / 1000, (maxV % 1000) / 10
    );

    static body[3584];
    body[0] = '\0';
    strcat(body, "Предмет в контейнере\tКол-во / Патр.\tСостояние\tВес (кг)\tОбъем (л)\n", sizeof(body));

    // Первая строка — вернуться в собственный инвентарь, чтобы положить предмет сюда
    strcat(body, "{FFD54F}<< Открыть свой инвентарь (Положить предмет)\t-\t-\t-\t-\n", sizeof(body));
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
            format(itemName, sizeof(itemName), "Комплект одежды (скин %d)", outfitSkin);
            format(statusStr, sizeof(statusStr), "{AFAFAF}В сумке{FFFFFF}");
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
            format(qtyStr, sizeof(qtyStr), "%d шт. (%d патр.)", amount, ammo);
        }
        else if (defId == ITEM_ID_CASH_BUNDLE)
        {
            format(qtyStr, sizeof(qtyStr), "$%d", amount);
        }
        else
        {
            format(qtyStr, sizeof(qtyStr), "%d шт.", amount);
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
        "Забрать",
        "Закрыть"
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
    strcat(body, "Слой\tПредмет\tКол-во / Патр.\tСерийный № / Инфо\tВес (кг)\n", sizeof(body));

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
            format(layerLabel, sizeof(layerLabel), "Слой 1 (Внеш.)");
        }
        else
        {
            format(layerLabel, sizeof(layerLabel), "Слой 2 (Тайник)");
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
                format(itemName, sizeof(itemName), "Комплект одежды (скин %d)", outfitSkin);
            }

            new metaStr[ITEM_META_STR_LEN];
            Storage_GetItemMetaStr(itemSlot, metaStr, sizeof(metaStr));
            if (defId == ITEM_ID_CLOTHING_OUTFIT)
            {
                if (Character_IsOutfitItemEquipped(targetid, itemSlot))
                {
                    format(metaStr, sizeof(metaStr), "{66CC66}Надето{FFFFFF}");
                }
                else
                {
                    format(metaStr, sizeof(metaStr), "{AFAFAF}В сумке{FFFFFF}");
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
                format(qtyBuf, sizeof(qtyBuf), "%d шт. (%d п.)", amount, ammo);
            }
            else
            {
                format(qtyBuf, sizeof(qtyBuf), "%d шт.", amount);
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
        strcat(body, "-\tПри досмотре ничего не обнаружено\t-\t-\t0.00\n", sizeof(body));
    }

    new targetName[MAX_PLAYER_NAME + 1];
    GetPlayerName(targetid, targetName, sizeof(targetName));

    new title[128];
    if (allowConfiscate)
    {
        format(title, sizeof(title), "Полный обыск: %s [%d] (Изъятие доступно)", targetName, targetid);
    }
    else
    {
        format(title, sizeof(title), "Поверхностный досмотр (Слой 1): %s [%d]", targetName, targetid);
    }

    new actionBtn[24];
    if (allowConfiscate)
    {
        format(actionBtn, sizeof(actionBtn), "Изъять");
    }
    else
    {
        format(actionBtn, sizeof(actionBtn), "Ок");
    }

    ShowPlayerDialog(
        actorid,
        DIALOG_INV_SEARCH_INSPECT,
        DIALOG_STYLE_TABLIST_HEADERS,
        title,
        body,
        actionBtn,
        "Закрыть"
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
    printf("%s [UI/Dialogs] Диалоговый маршрутизатор инвентаря (Слой 1/Слой 2/NESTED_BAG) и клавиши Y (2.5 м) инициализирован.",
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

/*
 * Контекстная клавиша KEY_YES (Y): сканирует радиус 2.5 м вокруг игрока
 * (лежащие свертки WORLD_DROP, вещи погибшего CORPSE_LOOT, хранилища)
 * и открывает русскоязычное меню контекстного взаимодействия.
 */
hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }

    if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES))
    {
        if (Survival_IsCuffed(playerid))
        {
            SendClientMessage(playerid, COLOR_ERROR, "[Действие]: Ваши руки скованы наручниками!");
            return 1;
        }

        new nearSlot = Storage_FindNearestWorldContainer(playerid, CONTEXT_INTERACT_RADIUS_M);
        sPlayerExternalStorageSlot[playerid] = nearSlot;

        new menuStr[512];
        menuStr[0] = '\0';
        strcat(menuStr, "1. Открыть личный инвентарь — Слой 1 (Внешний)\n", sizeof(menuStr));
        strcat(menuStr, "2. Открыть потайной карман — Слой 2 (Скрытый)\n", sizeof(menuStr));

        if (Storage_IsValidSlot(nearSlot))
        {
            new E_STORAGE_TYPE:stType = Storage_GetType(nearSlot);
            if (stType == STORAGE_CORPSE_LOOT)
            {
                strcat(menuStr, "3. {FFAB91}Обыскать вещи погибшего рядом (2.5 м)\n", sizeof(menuStr));
            }
            else
            {
                strcat(menuStr, "3. {81D4FA}Осмотреть сверток / контейнер рядом (2.5 м)\n", sizeof(menuStr));
            }
        }
        else
        {
            strcat(menuStr, "3. {90A4AE}Поблизости нет предметов на земле (2.5 м)\n", sizeof(menuStr));
        }

        strcat(menuStr, "4. Карточка персонажа и паспортные данные (/stats)\n", sizeof(menuStr));
        strcat(menuStr, "5. Навыки и характеристики персонажа (/skills)", sizeof(menuStr));

        ShowPlayerDialog(
            playerid,
            DIALOG_INV_CONTEXT_MENU_Y,
            DIALOG_STYLE_LIST,
            "Контекстное меню взаимодействия (Клавиша Y)",
            menuStr,
            "Выбрать",
            "Закрыть"
        );
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
    format(title, sizeof(title), "Предмет: %s (%d шт.)", itemName, amount);

    new actions[512];
    actions[0] = '\0';
    if (defId == ITEM_ID_CLOTHING_OUTFIT)
    {
        if (Storage_GetItemMetaInt2(item_slot) == CLOTHING_STATE_EQUIPPED)
        {
            strcat(actions, "1. {FFC800}Снять и убрать в сумку{FFFFFF}\n", sizeof(actions));
        }
        else
        {
            strcat(actions, "1. {66CC66}Надеть на себя{FFFFFF}\n", sizeof(actions));
        }
    }
    else
    {
        strcat(actions, "1. Использовать / Экипировать\n", sizeof(actions));
    }
    strcat(actions, "2. Открыть (для вложенного рюкзака / сумки)\n", sizeof(actions));
    strcat(actions, "3. Разделить / Объединить пачку\n", sizeof(actions));
    strcat(actions, "4. Переложить в другой слой (Слой 1 <-> Слой 2)\n", sizeof(actions));
    strcat(actions, "5. Переложить во внешнее хранилище\n", sizeof(actions));
    strcat(actions, "6. Выбросить на землю\n", sizeof(actions));
    strcat(actions, "7. Передать человеку рядом", sizeof(actions));

    ShowPlayerDialog(
        playerid,
        DIALOG_INV_ITEM_ACTIONS,
        DIALOG_STYLE_LIST,
        title,
        actions,
        "Выбрать",
        "Назад"
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
            SendClientMessage(playerid, COLOR_SUCCESS, "[Инвентарь]: Предмет перемещен в ваш внешний инвентарь (Слой 1).");
        }
        else if (res == STORAGE_RES_WEIGHT_EXCEEDED)
        {
            SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Недостаточно грузоподъемности! Превышен лимит веса Слоя 1.");
        }
        else if (res == STORAGE_RES_VOLUME_EXCEEDED)
        {
            SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: В инвентаре недостаточно свободного объема (литров).");
        }
        else
        {
            SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Не удалось переместить предмет (код ограничения контейнера).");
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
                SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Укажите количество меньше текущего размера пачки для разделения.");
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
                SendClientMessage(playerid, COLOR_SUCCESS, "[Инвентарь]: Пачка успешно разделена на две части.");
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
                SendClientMessage(playerid, COLOR_SUCCESS, "[Инвентарь]: Предмет успешно переложен в другой слой инвентаря.");
            }
            else if (res == STORAGE_RES_LAYER2_FORBIDDEN)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Этот предмет слишком крупный для потайного кармана (Слой 2)!");
            }
            else if (res == STORAGE_RES_WEIGHT_EXCEEDED)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Превышен лимит веса целевого слоя!");
            }
            else if (res == STORAGE_RES_VOLUME_EXCEEDED)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Превышен лимит объема целевого слоя!");
            }
            else
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Перемещение отклонено системой инвентаря.");
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
                SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Рядом нет открытого внешнего хранилища (радиус 2.5 м).");
                Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                return 1;
            }

            new E_STORAGE_RESULT:res = Storage_TransferItem(playerid, srcSlot, itemSlot, extSlot, amount, Character_GetId(playerid));
            if (res == STORAGE_RES_OK)
            {
                Character_SyncLayer1Weapons(playerid);
                Character_SyncInventorySkin(playerid);
                Survival_RecalculateEncumbrance(playerid);
                SendClientMessage(playerid, COLOR_SUCCESS, "[Инвентарь]: Предмет переложен во внешнее хранилище.");
            }
            else if (res == STORAGE_RES_NESTING_LIMIT)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Запрещено вкладывать сумку/контейнер внутрь другой сумки!");
            }
            else
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: В хранилище недостаточно места по весу или объему.");
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
                SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Достигнут лимит мировых контейнеров на земле.");
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
                SendClientMessage(playerid, COLOR_INFO, "[Инвентарь]: Вы положили предмет на землю.");
            }
            else
            {
                Storage_DestroyExpiredOrEmpty(dropSlot);
                SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Не удалось выбросить предмет на землю.");
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
            switch (listitem)
            {
                case 0: Dialogs_OpenInventory(playerid, INV_VIEW_LAYER_1);
                case 1: Dialogs_OpenInventory(playerid, INV_VIEW_LAYER_2);
                case 2:
                {
                    new nearSlot = Storage_FindNearestWorldContainer(playerid, CONTEXT_INTERACT_RADIUS_M);
                    if (Storage_IsValidSlot(nearSlot))
                    {
                        Dialogs_OpenExternalContainer(playerid, nearSlot);
                    }
                    else
                    {
                        SendClientMessage(playerid, COLOR_GRAY, "[Осмотр]: В радиусе 2.5 метров нет лежащих предметов или открытых хранилищ.");
                    }
                }
                case 3: Character_ShowStatsDialog(playerid);
                case 4: Skills_ShowDialog(playerid);
            }
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
                    SendClientMessage(playerid, COLOR_WARNING, "[Инвентарь]: Контейнер рядом больше недоступен.");
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
                        SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Этот предмет не является сумкой, рюкзаком или контейнером.");
                        Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    new nestedSlot = Storage_GetItemNestedSlot(itemSlot);
                    if (!Storage_IsValidSlot(nestedSlot))
                    {
                        SendClientMessage(playerid, COLOR_WARNING, "[Инвентарь]: Внутреннее отделение этой сумки пусто или еще не инициализировано.");
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
                        SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Этот предмет не складывается в пачки.");
                        Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    new merged = Internal_MergeSimilarStacks(srcSlot, itemSlot);
                    if (merged > 0)
                    {
                        SendClientMessage(playerid, COLOR_SUCCESS, "[Инвентарь]: Однотипные пачки предмета объединены.");
                        Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    if (amount <= 1)
                    {
                        SendClientMessage(playerid, COLOR_GRAY, "[Инвентарь]: В пачке всего 1 шт., разделение невозможно.");
                        Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    sPlayerPendingOp[playerid] = INV_OP_SPLIT_STACK;
                    ShowPlayerDialog(
                        playerid,
                        DIALOG_INV_INPUT_AMOUNT,
                        DIALOG_STYLE_INPUT,
                        "Разделение пачки предметов",
                        "Введите количество единиц, которое нужно отделить в новую пачку:",
                        "Отделить",
                        "Отмена"
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
                            "Перемещение между слоями инвентаря",
                            "Введите количество единиц для перемещения в другой слой:",
                            "Переложить",
                            "Отмена"
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
                            "Перемещение во внешнее хранилище",
                            "Введите количество единиц для перемещения в контейнер рядом:",
                            "Переложить",
                            "Отмена"
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
                            "Выбросить предмет на землю",
                            "Введите количество единиц, которое вы хотите выбросить на землю:",
                            "Выбросить",
                            "Отмена"
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
                        SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Поблизости нет игроков для передачи предмета (до 3.0 м).");
                        Dialogs_OpenInventory(playerid, sPlayerInvViewMode[playerid]);
                        return Y_HOOKS_BREAK_RETURN_1;
                    }

                    new targetLayer1 = Character_GetLayer1Slot(nearestId);
                    if (!Storage_IsValidSlot(targetLayer1))
                    {
                        SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Ошибка доступа к инвентарю получателя.");
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
                        format(alertMsg, sizeof(alertMsg), "[Передача]: Вы передали «%s» игроку %s.", itemNameBuf, targetName);
                        SendClientMessage(playerid, COLOR_SUCCESS, alertMsg);

                        format(alertMsg, sizeof(alertMsg), "[Передача]: Вы получили «%s» от %s.", itemNameBuf, actorName);
                        SendClientMessage(nearestId, COLOR_SUCCESS, alertMsg);
                    }
                    else if (res == STORAGE_RES_WEIGHT_EXCEEDED)
                    {
                        SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: У получателя переполнен инвентарь по весу.");
                    }
                    else if (res == STORAGE_RES_VOLUME_EXCEEDED)
                    {
                        SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: У получателя недостаточно места по объему (литров).");
                    }
                    else
                    {
                        SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Не удалось передать предмет.");
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
                SendClientMessage(playerid, COLOR_ERROR, "[Инвентарь]: Введите корректное положительное число.");
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
                        "Забрать предмет из хранилища",
                        "Введите количество единиц, которое вы хотите забрать в Слой 1:",
                        "Забрать",
                        "Отмена"
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
                SendClientMessage(playerid, COLOR_ERROR, "[Обыск]: Обыскиваемый игрок покинул сервер.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (Utils_GetDistanceBetweenPlayers(playerid, targetid) > 3.5)
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Обыск]: Игрок находится слишком далеко от вас.");
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
                format(msg, sizeof(msg), "[Обыск]: Вы изъяли «%s» (%d шт.) у задержанного.", itemName, amount);
                SendClientMessage(playerid, COLOR_SUCCESS, msg);

                format(msg, sizeof(msg), "[Обыск]: При обыске у вас изъяли «%s» (%d шт.).", itemName, amount);
                SendClientMessage(targetid, COLOR_WARNING, msg);

                Dialogs_OpenSearchTarget(playerid, targetid, sPlayerSearchIncludeLayer2[playerid], true);
            }
            else
            {
                SendClientMessage(playerid, COLOR_ERROR, "[Обыск]: В вашем инвентаре (Слой 1) недостаточно места для изъятия предмета.");
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_0;
}

/*
 * =============================================================================
 *  SAN ANDREAS RP — Оружейная физика без отдельных предметов патронов
 *  Файл:      gamemodes/modules/systems/mod_weapons.pwn
 *  Пункт:     ROADMAP [5.1] — Оружейная логика без отдельных патронов
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_weapons_included
    #endinput
#endif
#define _mod_weapons_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ ОРУЖЕЙНОЙ СИСТЕМЫ
// =============================================================================

#define WEAPON_MAX_AMMO_COUNT                   (9999)
#define WEAPON_JAM_BLOCK_MS                     (1500)
#define WEAPON_COMMAND_COOLDOWN_MS              (400)
#define WEAPON_DURABILITY_WEAR_PER_SHOT         (0.05)
#define WEAPON_JAM_DURABILITY_THRESHOLD         (30.0)
#define WEAPON_JAM_CHANCE_PER_POINT             (80)
#define WEAPON_SKILL_GROW_CHANCE_PERCENT        (12)
#define WEAPON_HUD_REFRESH_AMMO_STEP            (10)
#define WEAPON_PERSIST_AMMO_STEP                (5)
#define WEAPON_SLOT_CACHE_SIZE                  (47)

// =============================================================================
//  2. ИНКАПСУЛИРОВАННОЕ СОСТОЯНИЕ ОРУЖЕЙНЫХ СЛОТОВ (static stock)
// =============================================================================

// Кэш соответствия GTA-слота оружия (ID 0..46) экземпляру предмета в Слое 1
static stock sWeaponItemSlot[MAX_PLAYERS][WEAPON_SLOT_CACHE_SIZE];

// Серверная блокировка стрельбы после заклинивания затвора
static stock sWeaponJamUntil[MAX_PLAYERS];
static stock sLastJamNoticeTick[MAX_PLAYERS];

// Антифлуд команд /unload и /combine
static stock sLastWeaponCommandTick[MAX_PLAYERS];

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (static stock)
// =============================================================================

stock bool:Weapons_IsTrackedFirearm(weaponid)
{
    return (weaponid >= 22 && weaponid <= 34);
}

static stock E_SKILL_TYPE:Internal_GetSkillForWeapon(WEAPON:weaponid)
{
    switch (_:weaponid)
    {
        case 22: return SKILL_PISTOL;
        case 23: return SKILL_PISTOL_SILENCED;
        case 24: return SKILL_DESERT_EAGLE;
        case 25: return SKILL_SHOTGUN;
        case 26: return SKILL_SAWNOFF_SHOTGUN;
        case 27: return SKILL_SPAS12_SHOTGUN;
        case 28: return SKILL_MICRO_UZI;
        case 29: return SKILL_MP5;
        case 30: return SKILL_AK47;
        case 31: return SKILL_M4;
        case 32: return SKILL_TEC9;
        case 33: return SKILL_COUNTRY_RIFLE;
        case 34: return SKILL_SNIPER_RIFLE;
        case 35, 36, 37, 38: return SKILL_HEAVY_ORDNANCE;
        case 16, 17, 18, 39: return SKILL_THROWABLES;
        case 4, 8: return SKILL_MELEE_BLADED;
        case 6, 9: return SKILL_HEAVY_TOOLS;
    }
    return SKILL_MELEE_BLUNT;
}

// Поиск экземпляра оружия в Слое 1 с валидацией кэша и требованием боезапаса
static stock Internal_FindItemSlotForWeapon(playerid, WEAPON:weaponid, bool:requireAmmo)
{
    new const wid = _:weaponid;
    if (playerid < 0 || playerid >= MAX_PLAYERS || wid < 0 || wid >= WEAPON_SLOT_CACHE_SIZE)
    {
        return INVALID_STORAGE_ITEM_SLOT;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        return INVALID_STORAGE_ITEM_SLOT;
    }

    // Сканирование Слоя 1: выбираем последний экземпляр, как это делает
    // Character_SyncLayer1Weapons при последовательном GivePlayerWeapon.
    // Кэш обновляется, но не является источником истины: предмет мог быть
    // перемещен, объединен или изъят другим модулем.
    new foundSlot = INVALID_STORAGE_ITEM_SLOT;
    new itemSlot = Storage_GetFirstItemSlot(layer1Slot);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        if (Item_GetGtaWeaponId(Storage_GetItemDefId(itemSlot)) == wid &&
            (!requireAmmo || Storage_GetItemAmmo(itemSlot) > 0))
        {
            foundSlot = itemSlot;
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }

    sWeaponItemSlot[playerid][wid] = foundSlot;
    return foundSlot;
}

// Поиск второго экземпляра того же оружия для /unload
static stock Internal_FindSecondSameWeapon(playerid, def_id, src_item_slot)
{
    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        return INVALID_STORAGE_ITEM_SLOT;
    }

    new itemSlot = Storage_GetFirstItemSlot(layer1Slot);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        if (itemSlot != src_item_slot &&
            Storage_GetItemDefId(itemSlot) == def_id &&
            Storage_GetItemNestedSlot(itemSlot) == INVALID_STORAGE_SLOT)
        {
            return itemSlot;
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }
    return INVALID_STORAGE_ITEM_SLOT;
}

// Пространственная отыгровка /me для свидетелей заклинивания
static stock Internal_SendProximityRoleplay(playerid, const action[])
{
    new actorName[MAX_PLAYER_NAME + 1];
    GetPlayerName(playerid, actorName, sizeof(actorName));
    for (new idx = 0; actorName[idx] != EOS; idx++)
    {
        if (actorName[idx] == '_')
        {
            actorName[idx] = ' ';
        }
    }

    new Float:x = 0.0, Float:y = 0.0, Float:z = 0.0;
    GetPlayerPos(playerid, x, y, z);
    new const worldId = GetPlayerVirtualWorld(playerid);
    new const interiorId = GetPlayerInterior(playerid);

    new message[192];
    format(message, sizeof(message), "* %s %s", actorName, action);

    foreach (new targetid : Player)
    {
        if (!Character_IsLoaded(targetid))
        {
            continue;
        }
        if (Utils_IsPlayerNearPoint(targetid, 12.0, x, y, z, interiorId, worldId))
        {
            SendClientMessage(targetid, COLOR_UI_ROLEPLAY_ME, message);
        }
    }
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API ОРУЖЕЙНОЙ СИСТЕМЫ (Weapons_*)
// =============================================================================

stock Weapons_SyncPlayer(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }

    for (new slotIdx = 0; slotIdx < WEAPON_SLOT_CACHE_SIZE; slotIdx++)
    {
        sWeaponItemSlot[playerid][slotIdx] = INVALID_STORAGE_ITEM_SLOT;
    }

    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        return 0;
    }

    new itemSlot = Storage_GetFirstItemSlot(layer1Slot);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        new const gtaWeaponId = Item_GetGtaWeaponId(Storage_GetItemDefId(itemSlot));
        if (gtaWeaponId > 0 && gtaWeaponId < WEAPON_SLOT_CACHE_SIZE)
        {
            sWeaponItemSlot[playerid][gtaWeaponId] = itemSlot;
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }
    return 1;
}

stock Weapons_GetItemSlot(playerid, WEAPON:weaponid, bool:require_ammo = true)
{
    return Internal_FindItemSlotForWeapon(playerid, weaponid, require_ammo);
}

// Гарантирует наличие уникального серийного номера ствола (meta_int2)
stock Weapons_EnsureWeaponSerial(item_slot)
{
    if (!Storage_IsValidItemSlot(item_slot))
    {
        return 0;
    }

    new serial = Storage_GetItemMetaInt2(item_slot);
    if (serial <= 0)
    {
        serial = Utils_GenerateWeaponSerial();
        Storage_SetItemMetaInt2(item_slot, serial);
    }
    return serial;
}

stock bool:Weapons_IsJammed(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return false;
    }
    return (GetTickCount() < sWeaponJamUntil[playerid]);
}

stock Weapons_GetDurability(playerid, WEAPON:weaponid)
{
    new const itemSlot = Internal_FindItemSlotForWeapon(playerid, weaponid, false);
    if (itemSlot == INVALID_STORAGE_ITEM_SLOT)
    {
        return 0;
    }
    return floatround(Storage_GetItemDurability(itemSlot));
}

// =============================================================================
//  5. ХУКИ СИСТЕМНЫХ СОБЫТИЙ (y_hooks)
// =============================================================================

hook OnPlayerConnect(playerid)
{
    for (new slotIdx = 0; slotIdx < WEAPON_SLOT_CACHE_SIZE; slotIdx++)
    {
        sWeaponItemSlot[playerid][slotIdx] = INVALID_STORAGE_ITEM_SLOT;
    }
    sWeaponJamUntil[playerid] = 0;
    sLastJamNoticeTick[playerid] = 0;
    sLastWeaponCommandTick[playerid] = 0;
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    for (new slotIdx = 0; slotIdx < WEAPON_SLOT_CACHE_SIZE; slotIdx++)
    {
        sWeaponItemSlot[playerid][slotIdx] = INVALID_STORAGE_ITEM_SLOT;
    }
    sWeaponJamUntil[playerid] = 0;
    sLastJamNoticeTick[playerid] = 0;
    sLastWeaponCommandTick[playerid] = 0;
    return 1;
}

hook OnPlayerSpawn(playerid)
{
    Weapons_SyncPlayer(playerid);
    return 1;
}

hook OnPlayerWeaponShot(playerid, WEAPON:weaponid, BULLET_HIT_TYPE:hittype, hitid, Float:fX, Float:fY, Float:fZ)
{
    #pragma unused hittype, hitid, fX, fY, fZ

    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }

    // Метательное, холодное и спецсредства не расходуют ammo_count
    if (!Weapons_IsTrackedFirearm(_:weaponid))
    {
        return 1;
    }

    new const nowTick = GetTickCount();

    // Затвор заклинен: сервер отклоняет выстрел до истечения таймера
    if (nowTick < sWeaponJamUntil[playerid])
    {
        if ((nowTick - sLastJamNoticeTick[playerid]) >= 800)
        {
            sLastJamNoticeTick[playerid] = nowTick;
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "[Оружие]: Затвор заклинило. Передерните его и повторите попытку через мгновение.");
        }
        return 0;
    }

    new const itemSlot = Internal_FindItemSlotForWeapon(playerid, weaponid, true);
    if (itemSlot == INVALID_STORAGE_ITEM_SLOT)
    {
        // Server-Authoritative: оружия нет в Слое 1 — выстрел блокируется
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Античит]: В вашем инвентаре отсутствует это оружие. Выстрел заблокирован.");
        return 0;
    }

    new ammo = Storage_GetItemAmmo(itemSlot);
    if (ammo <= 0)
    {
        SetPlayerAmmo(playerid, weaponid, 0);
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Оружие]: Боезапас этого ствола исчерпан. Объедините патроны командой /combine.");
        return 0;
    }

    // Износ: 0.05% за выстрел, снижается навыком владения (до -50%) и перком Ветерана (-30%)
    new Float:durability = Storage_GetItemDurability(itemSlot);
    new const skillValue = Skills_Get(playerid, Internal_GetSkillForWeapon(weaponid));
    new Float:wear = WEAPON_DURABILITY_WEAR_PER_SHOT * (1.0 - (float(skillValue) / 2000.0));
    if (Roles_HasPerk(Character_GetRoleId(playerid), PERK_RIFLE_WEAR_MINUS_30))
    {
        wear *= 0.70;
    }
    durability -= wear;
    if (durability < 0.0)
    {
        durability = 0.0;
    }

    ammo--;
    if (ammo < 0)
    {
        ammo = 0;
    }

    // Заклинивание рассчитывается до записи нового состояния
    new bool:jammed = false;
    if (durability < WEAPON_JAM_DURABILITY_THRESHOLD)
    {
        new const jamChance = floatround((WEAPON_JAM_DURABILITY_THRESHOLD - durability) * WEAPON_JAM_CHANCE_PER_POINT);
        if (random(10000) < jamChance)
        {
            jammed = true;
        }
    }

    new const bool:persist = (ammo <= 0) || (jammed) || ((ammo % WEAPON_PERSIST_AMMO_STEP) == 0);
    Storage_UpdateWeaponState(itemSlot, ammo, durability, persist);
    Weapons_EnsureWeaponSerial(itemSlot);

    if (ammo <= 0)
    {
        SetPlayerAmmo(playerid, weaponid, 0);
    }

    // Прокачка профильного навыка за результативные выстрелы
    if (random(100) < WEAPON_SKILL_GROW_CHANCE_PERCENT)
    {
        Skills_Add(playerid, Internal_GetSkillForWeapon(weaponid), 1);
    }

    if ((ammo % WEAPON_HUD_REFRESH_AMMO_STEP) == 0)
    {
        CallLocalFunction("OnPlayerHudNeedsUpdate", "d", playerid);
    }

    if (jammed)
    {
        sWeaponJamUntil[playerid] = nowTick + WEAPON_JAM_BLOCK_MS;
        sLastJamNoticeTick[playerid] = nowTick;

        Internal_SendProximityRoleplay(playerid, "передергивает затвор заклинившего оружия.");
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Оружие]: Патрон перекосило, затвор заклинило! Стрельба заблокирована на 1.5 секунды.");
        return 0;
    }

    return 1;
}

// =============================================================================
//  6. КОМАНДЫ РАЗРЯДКИ И ОБЪЕДИНЕНИЯ БОЕЗАПАСА
// =============================================================================

CMD:unload(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Оружие]: Ваш персонаж еще не загружен.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sLastWeaponCommandTick[playerid]) < WEAPON_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Оружие]: Не так быстро. Подождите мгновение.");
        return 1;
    }
    sLastWeaponCommandTick[playerid] = nowTick;

    new const WEAPON:heldWeapon = GetPlayerWeapon(playerid);
    if (!Weapons_IsTrackedFirearm(_:heldWeapon))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Оружие]: Возьмите в руки огнестрельное оружие, чтобы разделить его боезапас.");
        return 1;
    }

    new const srcItemSlot = Internal_FindItemSlotForWeapon(playerid, heldWeapon, true);
    if (srcItemSlot == INVALID_STORAGE_ITEM_SLOT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Оружие]: Этот ствол не найден в вашем инвентаре.");
        return 1;
    }

    new const ammo = Storage_GetItemAmmo(srcItemSlot);
    if (ammo <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Оружие]: В этом стволе нет патронов.");
        return 1;
    }

    new const defId = Storage_GetItemDefId(srcItemSlot);
    new const dstItemSlot = Internal_FindSecondSameWeapon(playerid, defId, srcItemSlot);
    if (dstItemSlot == INVALID_STORAGE_ITEM_SLOT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Оружие]: Для разрядки нужен второй такой же ствол в инвентаре. Патроны не существуют отдельным предметом.");
        return 1;
    }

    new amount = (params[0] != EOS) ? strval(params) : (ammo / 2);
    if (amount <= 0)
    {
        amount = 1;
    }
    if (amount > ammo)
    {
        amount = ammo;
    }

    new const dstAmmo = Storage_GetItemAmmo(dstItemSlot);
    new const newSrcAmmo = ammo - amount;
    new const newDstAmmo = dstAmmo + amount;

    Storage_UpdateWeaponState(srcItemSlot, newSrcAmmo, Storage_GetItemDurability(srcItemSlot), true);
    Storage_UpdateWeaponState(dstItemSlot, newDstAmmo, Storage_GetItemDurability(dstItemSlot), true);
    Weapons_EnsureWeaponSerial(srcItemSlot);
    Weapons_EnsureWeaponSerial(dstItemSlot);

    Character_SyncLayer1Weapons(playerid);
    Survival_RecalculateEncumbrance(playerid);
    CallLocalFunction("OnPlayerHudNeedsUpdate", "d", playerid);

    new itemName[ITEM_DISPLAY_NAME_LEN];
    Item_GetName(defId, itemName, sizeof(itemName));
    new message[192];
    format(message, sizeof(message),
        "[Оружие]: Вы разрядили %d патрон(ов) из «%s» во второй такой же ствол (осталось: %d / %d).",
        amount, itemName, newSrcAmmo, newDstAmmo);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, message);

    new details[192];
    format(details, sizeof(details),
        "Разрядка ствола: перенесено %d патрон(ов) между двумя экземплярами '%s'",
        amount, itemName);
    Audit_Log(Character_GetId(playerid), "WEAPON_AMMO", "PLAYER_LAYER1", "PLAYER_LAYER1",
        defId, amount, details);
    return 1;
}

CMD:combine(playerid, params[])
{
    #pragma unused params

    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Оружие]: Ваш персонаж еще не загружен.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sLastWeaponCommandTick[playerid]) < WEAPON_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Оружие]: Не так быстро. Подождите мгновение.");
        return 1;
    }
    sLastWeaponCommandTick[playerid] = nowTick;

    new const WEAPON:heldWeapon = GetPlayerWeapon(playerid);
    if (!Weapons_IsTrackedFirearm(_:heldWeapon))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Оружие]: Возьмите в руки огнестрельное оружие, чтобы объединить боезапас.");
        return 1;
    }

    new const dstItemSlot = Internal_FindItemSlotForWeapon(playerid, heldWeapon, true);
    if (dstItemSlot == INVALID_STORAGE_ITEM_SLOT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Оружие]: Этот ствол не найден в вашем инвентаре.");
        return 1;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Оружие]: Ошибка доступа к Слою 1 инвентаря.");
        return 1;
    }

    new const defId = Storage_GetItemDefId(dstItemSlot);
    new heldAmmo = Storage_GetItemAmmo(dstItemSlot);
    new totalMoved = 0;
    new mergedWeapons = 0;

    new itemSlot = Storage_GetFirstItemSlot(layer1Slot);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        if (itemSlot != dstItemSlot &&
            Storage_GetItemDefId(itemSlot) == defId &&
            Storage_GetItemNestedSlot(itemSlot) == INVALID_STORAGE_SLOT)
        {
            new const otherAmmo = Storage_GetItemAmmo(itemSlot);
            if (otherAmmo > 0)
            {
                new const freeCapacity = WEAPON_MAX_AMMO_COUNT - heldAmmo;
                new transfer = otherAmmo;
                if (transfer > freeCapacity)
                {
                    transfer = freeCapacity;
                }

                if (transfer > 0)
                {
                    heldAmmo += transfer;
                    totalMoved += transfer;
                    mergedWeapons++;
                    Storage_UpdateWeaponState(itemSlot, otherAmmo - transfer, Storage_GetItemDurability(itemSlot), true);
                }
            }
            Weapons_EnsureWeaponSerial(itemSlot);
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }

    if (totalMoved <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Оружие]: Второго ствола с патронами той же модели не найдено, либо боезапас уже заполнен.");
        return 1;
    }

    Storage_UpdateWeaponState(dstItemSlot, heldAmmo, Storage_GetItemDurability(dstItemSlot), true);
    Weapons_EnsureWeaponSerial(dstItemSlot);

    Character_SyncLayer1Weapons(playerid);
    Survival_RecalculateEncumbrance(playerid);
    CallLocalFunction("OnPlayerHudNeedsUpdate", "d", playerid);

    new itemName[ITEM_DISPLAY_NAME_LEN];
    Item_GetName(defId, itemName, sizeof(itemName));
    new message[192];
    format(message, sizeof(message),
        "[Оружие]: Вы объединили боезапас %d ствол(ов) «%s»: перенесено %d патрон(ов), итог — %d.",
        mergedWeapons, itemName, totalMoved, heldAmmo);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, message);

    new details[192];
    format(details, sizeof(details),
        "Объединение боезапаса '%s': перенесено %d патрон(ов) из %d стволов",
        itemName, totalMoved, mergedWeapons);
    Audit_Log(Character_GetId(playerid), "WEAPON_AMMO", "PLAYER_LAYER1", "PLAYER_LAYER1",
        defId, totalMoved, details);
    return 1;
}

// =============================================================================
//  7. ИНИЦИАЛИЗАЦИЯ И САМОПРОВЕРКА (hook OnGameModeInit)
// =============================================================================

hook OnGameModeInit()
{
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        for (new slotIdx = 0; slotIdx < WEAPON_SLOT_CACHE_SIZE; slotIdx++)
        {
            sWeaponItemSlot[playerid][slotIdx] = INVALID_STORAGE_ITEM_SLOT;
        }
        sWeaponJamUntil[playerid] = 0;
        sLastJamNoticeTick[playerid] = 0;
        sLastWeaponCommandTick[playerid] = 0;
    }

    // Контрольная формула DoD 5.1: 200 патронов M4 = 2.4 кг боезапаса
    new const m4AmmoWeight = Item_GetAmmoUnitWeight(23) * 200;
    printf("%s [Systems/Weapons] Оружейная физика инициализирована (200 патронов M4 = %d г: %s).",
        SERVER_LOG_PREFIX,
        m4AmmoWeight,
        (m4AmmoWeight == 2400) ? ("УСПЕШНО") : ("ОШИБКА"));
    return 1;
}

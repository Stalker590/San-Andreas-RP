/*
 * =============================================================================
 *  SAN ANDREAS RP — Физиология выживания, метаболизм, ломка и перегруз
 *  Файл:      gamemodes/modules/systems/mod_survival.pwn
 *  Пункт:     ROADMAP [4.1] — Физиология выживания и перегруз (systems/mod_survival.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_survival_included
    #endinput
#endif
#define _mod_survival_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ ФИЗИОЛОГИИ, МЕТАБОЛИЗМА И ИДЕНТИФИКАТОРОВ ПРЕДМЕТОВ
// =============================================================================

#if !defined COLOR_ERROR
    #define COLOR_ERROR                         (COLOR_UI_ERROR)
#endif
#if !defined COLOR_WARNING
    #define COLOR_WARNING                       (COLOR_UI_WARNING)
#endif
#if !defined COLOR_SUCCESS
    #define COLOR_SUCCESS                       (COLOR_UI_SUCCESS)
#endif
#if !defined COLOR_INFO
    #define COLOR_INFO                          (COLOR_UI_INFO)
#endif
#if !defined COLOR_GRAY
    #define COLOR_GRAY                          (0x90A4AEFF)
#endif
#if !defined COLOR_RP_ME
    #define COLOR_RP_ME                         (COLOR_UI_ROLEPLAY_ME)
#endif
#if !defined COLOR_RP_DO
    #define COLOR_RP_DO                         (0x9575CDFF)
#endif
#if !defined INVALID_ITEM_SLOT
    #define INVALID_ITEM_SLOT                   (INVALID_STORAGE_ITEM_SLOT)
#endif
#if !defined ITEM_META_STR_LEN
    #define ITEM_META_STR_LEN                   (STORAGE_ITEM_META_STR_LEN)
#endif

#define SURVIVAL_BASE_HUNGER_DRAIN_MIN          (0.45)
#define SURVIVAL_BASE_THIRST_DRAIN_MIN          (0.65)
#define SURVIVAL_STARVATION_HP_DAMAGE           (3.0)
#define SURVIVAL_DEHYDRATION_HP_DAMAGE          (4.0)
#define SURVIVAL_BLEEDING_HP_DAMAGE             (3.5)
#define SURVIVAL_WITHDRAWAL_HP_DAMAGE           (4.0)
#define SURVIVAL_WITHDRAWAL_MINUTES_LIMIT       (40)
#define SURVIVAL_ADDICTION_THRESHOLD            (35.0)
#define SURVIVAL_OVERWEIGHT_NOTIFY_COOLDOWN_MS  (4000)

// Предметы экипировки, медицины, еды и электроники из реестра mod_items.pwn
#define ITEM_ID_BODY_ARMOR                      (40)
#define ITEM_ID_BACKPACK                        (41)
#define ITEM_ID_DUFFLE_BAG                      (42)
#define ITEM_ID_BALACLAVA                       (43)
#define ITEM_ID_HANDCUFFS                       (44)
#define ITEM_ID_WALKIE_TALKIE                   (53)
#define ITEM_ID_FIRST_AID_KIT                   (56)
#define ITEM_ID_SURGICAL_KIT                    (57)
#define ITEM_ID_BANDAGE                         (58)
#define ITEM_ID_TOURNIQUET                      (59)
#define ITEM_ID_MORPHINE_SYRINGE                (60)
#define ITEM_ID_WATER_BOTTLE                    (61)
#define ITEM_ID_MRE_RATION                      (62)
#define ITEM_ID_FASTFOOD_BURGER                 (63)
#define ITEM_ID_LIQUOR_BOTTLE                   (64)
#define ITEM_ID_CIGARETTE_PACK                  (65)
#define ITEM_ID_HARD_DRUG_METH                  (66)
#define ITEM_ID_WEED_PACK                       (67)
#define ITEM_ID_PASSPORT                        (68)
#define ITEM_ID_WEAPON_LICENSE                  (69)
#define ITEM_ID_CLOTHING_OUTFIT                 (91)

// =============================================================================
//  2. ВНУТРЕННЕЕ СОСТОЯНИЕ ИГРОКОВ В ОПЕРАТИВНОЙ ПАМЯТИ (static stock)
// =============================================================================

static stock bool:sPlayerBleeding[MAX_PLAYERS];
static stock bool:sPlayerInWithdrawal[MAX_PLAYERS];
static stock bool:sPlayerCuffed[MAX_PLAYERS];
static stock bool:sPlayerMasked[MAX_PLAYERS];
static stock sMinutesSinceLastDose[MAX_PLAYERS];
static stock sPlayerRadioFreqKhz[MAX_PLAYERS];
static stock sLastOverweightWarnTick[MAX_PLAYERS];

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ЗОН И МЕТАБОЛИЗМА
// =============================================================================

static stock Survival_ResetPlayerRuntime(playerid)
{
    sPlayerBleeding[playerid] = false;
    sPlayerInWithdrawal[playerid] = false;
    sPlayerCuffed[playerid] = false;
    sPlayerMasked[playerid] = false;
    sMinutesSinceLastDose[playerid] = 0;
    sPlayerRadioFreqKhz[playerid] = 0;
    sLastOverweightWarnTick[playerid] = 0;
}

/*
 * Проверка нахождения игрока в пределах крупных мегаполисов (LS, SF, LV)
 * Используется для перка PERK_FOREST_RUNNER (Роль №19: Реднек-Браконьер).
 */
static stock bool:Internal_IsPlayerInMajorCity(playerid)
{
    if (GetPlayerInterior(playerid) != 0)
    {
        return true;
    }

    new Float:x = 0.0, Float:y = 0.0, Float:z = 0.0;
    GetPlayerPos(playerid, x, y, z);

    // Мегаполис Лос-Сантос
    if (x >= 750.0 && x <= 2950.0 && y >= -2700.0 && y <= -750.0)
    {
        return true;
    }
    // Мегаполис Сан-Фиерро
    if (x >= -2950.0 && x <= -1200.0 && y >= -600.0 && y <= 1550.0)
    {
        return true;
    }
    // Мегаполис Лас-Вентурас
    if (x >= 850.0 && x <= 2950.0 && y >= 600.0 && y <= 2950.0)
    {
        return true;
    }
    return false;
}

static stock Internal_NotifyHudRefresh(playerid)
{
    CallLocalFunction("OnPlayerHudNeedsUpdate", "d", playerid);
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API ГРУЗОПОДЪЕМНОСТИ, СТАТУСОВ И ВЫЖИВАНИЯ (stock)
// =============================================================================

/*
 * Возвращает максимальный переносимый вес персонажа в граммах:
 * W_max = 25000 + (Skill_MUSCLE * 35) + Delta_role
 */
stock Survival_GetMaxCarryWeightGrams(playerid)
{
    return Character_GetMaxCarryWeightGrams(playerid);
}

/*
 * Возвращает текущий вес внешнего инвентаря (Слой 1) персонажа в граммах,
 * включая рекурсивную массу вложенного рюкзака/сумки и заряженных патронов.
 */
stock Survival_GetCarryWeightGrams(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }
    new layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        return 0;
    }
    return Storage_GetCurrentWeight(layer1Slot);
}

/*
 * Проверяет, превышен ли лимит грузоподъемности персонажа (W_layer1 > W_max).
 */
stock bool:Survival_IsOverweight(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return false;
    }
    new currentWeight = Survival_GetCarryWeightGrams(playerid);
    new maxWeight = Survival_GetMaxCarryWeightGrams(playerid);
    return (currentWeight > maxWeight);
}

stock bool:Survival_IsBleeding(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return sPlayerBleeding[playerid];
}

stock Survival_SetBleeding(playerid, bool:bleeding)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    sPlayerBleeding[playerid] = bleeding;
    Internal_NotifyHudRefresh(playerid);
    return 1;
}

stock bool:Survival_IsInWithdrawal(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return sPlayerInWithdrawal[playerid];
}

stock bool:Survival_IsCuffed(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return sPlayerCuffed[playerid];
}

stock Survival_SetCuffed(playerid, bool:cuffed)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    sPlayerCuffed[playerid] = cuffed;
    if (cuffed)
    {
        SetPlayerSpecialAction(playerid, SPECIAL_ACTION_CUFFED);
    }
    else
    {
        SetPlayerSpecialAction(playerid, SPECIAL_ACTION_NONE);
    }
    Internal_NotifyHudRefresh(playerid);
    return 1;
}

stock bool:Survival_IsMasked(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return sPlayerMasked[playerid];
}

stock Survival_GetRadioFreqKhz(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return sPlayerRadioFreqKhz[playerid];
}

stock Survival_SetRadioFreqKhz(playerid, freq_khz)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (freq_khz < 0) freq_khz = 0;
    if (freq_khz > 999999) freq_khz = 999999;
    sPlayerRadioFreqKhz[playerid] = freq_khz;
    Internal_NotifyHudRefresh(playerid);
    return 1;
}

/*
 * Пересчитывает лимит веса Слоя 1 на основе силы и роли, проверяет перегруз
 * и уведомляет текстовый HUD об изменении состояния.
 */
stock Survival_RecalculateEncumbrance(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    new maxWeight = Character_GetMaxCarryWeightGrams(playerid);
    new layer1Slot = Character_GetLayer1Slot(playerid);
    if (Storage_IsValidSlot(layer1Slot))
    {
        Storage_SetMaxLimits(layer1Slot, maxWeight, Storage_GetMaxVolume(layer1Slot));
    }

    Internal_NotifyHudRefresh(playerid);
    return 1;
}

/*
 * Применение расходника, экипировки или предмета из инвентаря игрока.
 * Возвращает true, если предмет был успешно использован.
 */
stock bool:Survival_UseInventoryItem(playerid, storage_slot, item_slot)
{
    if (!Character_IsLoaded(playerid))
    {
        return false;
    }
    if (!Storage_IsValidSlot(storage_slot) || !Storage_IsValidItemSlot(item_slot))
    {
        return false;
    }

    new defId = Storage_GetItemDefId(item_slot);
    if (!Item_IsValid(defId))
    {
        return false;
    }

    // Медицинский модуль проверяет совместимость предмета с текущей травмой
    if (CallLocalFunction("Medical_CanUseMedicalItem", "dd", playerid, defId) == 0)
    {
        return false;
    }

    new roleId = Character_GetRoleId(playerid);
    new Float:hp = 100.0;
    new Float:armour = 0.0;
    GetPlayerHealth(playerid, hp);
    GetPlayerArmour(playerid, armour);

    new Float:maxAllowedHp = Roles_HasPerk(roleId, PERK_DRUG_BOOST_25X) ? 135.0 : 100.0;
    if (Roles_HasPerk(roleId, PERK_SILENT_PICKPOCKET) && maxAllowedHp > 85.0)
    {
        maxAllowedHp = 85.0;
    }

    switch (defId)
    {
        case ITEM_ID_WATER_BOTTLE:
        {
            if (!Storage_RemoveItem(storage_slot, item_slot, 1))
            {
                return false;
            }
            new Float:gain = Roles_HasPerk(roleId, PERK_NO_POISON) ? 55.0 : 45.0;
            Character_SetThirst(playerid, Character_GetThirst(playerid) + gain);
            ApplyAnimation(playerid, "VENDING", "VEND_Drink2_P", 4.1, false, false, false, false, 0, SYNC_ALL);
            SendClientMessage(playerid, COLOR_SUCCESS, "[Survival]: Drank drinking water (+45% thirst quencher).");
            Survival_RecalculateEncumbrance(playerid);
            return true;
        }
        case ITEM_ID_MRE_RATION:
        {
            if (!Storage_RemoveItem(storage_slot, item_slot, 1))
            {
                return false;
            }
            new Float:hungerGain = Roles_HasPerk(roleId, PERK_NO_POISON) ? 75.0 : 60.0;
            Character_SetHunger(playerid, Character_GetHunger(playerid) + hungerGain);
            Character_SetThirst(playerid, Character_GetThirst(playerid) + 15.0);
            ApplyAnimation(playerid, "FOOD", "EAT_Burger", 4.1, false, false, false, false, 0, SYNC_ALL);
            SendClientMessage(playerid, COLOR_SUCCESS, "[Survival]: You ate MRE army rations (+60% hunger, +15% water).");
            Survival_RecalculateEncumbrance(playerid);
            return true;
        }
        case ITEM_ID_FASTFOOD_BURGER:
        {
            if (!Storage_RemoveItem(storage_slot, item_slot, 1))
            {
                return false;
            }
            new Float:hungerGain = Roles_HasPerk(roleId, PERK_NO_POISON) ? 45.0 : 35.0;
            Character_SetHunger(playerid, Character_GetHunger(playerid) + hungerGain);
            ApplyAnimation(playerid, "FOOD", "EAT_Burger", 4.1, false, false, false, false, 0, SYNC_ALL);
            SendClientMessage(playerid, COLOR_SUCCESS, "[Survival]: You snacked on a hot burger (+35% hunger).");
            Survival_RecalculateEncumbrance(playerid);
            return true;
        }
        case ITEM_ID_LIQUOR_BOTTLE:
        {
            if (!Storage_RemoveItem(storage_slot, item_slot, 1))
            {
                return false;
            }
            Character_SetThirst(playerid, Character_GetThirst(playerid) + 15.0);
            Character_SetStress(playerid, Character_GetStress(playerid) - 30.0);
            new currentDrunk = GetPlayerDrunkLevel(playerid);
            SetPlayerDrunkLevel(playerid, currentDrunk + 3000);
            ApplyAnimation(playerid, "VENDING", "VEND_Drink2_P", 4.1, false, false, false, false, 0, SYNC_ALL);
            SendClientMessage(playerid, COLOR_INFO, "[Survival]: You drank whiskey (-30% stress, slight intoxication).");
            Survival_RecalculateEncumbrance(playerid);
            return true;
        }
        case ITEM_ID_CIGARETTE_PACK:
        {
            if (!Storage_RemoveItem(storage_slot, item_slot, 1))
            {
                return false;
            }
            Character_SetStress(playerid, Character_GetStress(playerid) - 20.0);
            SetPlayerSpecialAction(playerid, SPECIAL_ACTION_SMOKE_CIGGY);
            SendClientMessage(playerid, COLOR_INFO, "[Survival]: Light a cigarette (-20% stress level).");
            Survival_RecalculateEncumbrance(playerid);
            return true;
        }
        case ITEM_ID_BANDAGE, ITEM_ID_TOURNIQUET:
        {
            if (!Storage_RemoveItem(storage_slot, item_slot, 1))
            {
                return false;
            }
            CallLocalFunction("Medical_OnItemUsed", "dd", playerid, defId);
            sPlayerBleeding[playerid] = false;
            new Float:healAmount = (defId == ITEM_ID_TOURNIQUET) ? 20.0 : 15.0;
            if (Roles_HasPerk(roleId, PERK_CHEM_YIELD_40))
            {
                healAmount *= 1.4;
            }
            hp += healAmount;
            if (hp > maxAllowedHp) hp = maxAllowedHp;
            SetPlayerHealth(playerid, hp);
            ApplyAnimation(playerid, "BOMBER", "BOM_Plant", 4.1, false, false, false, false, 0, SYNC_ALL);
            SendClientMessage(playerid, COLOR_SUCCESS, "[Medicine]: The bleeding has been stopped and the wound has been bandaged.");
            Survival_RecalculateEncumbrance(playerid);
            return true;
        }
        case ITEM_ID_FIRST_AID_KIT, ITEM_ID_SURGICAL_KIT:
        {
            if (!Storage_RemoveItem(storage_slot, item_slot, 1))
            {
                return false;
            }
            CallLocalFunction("Medical_OnItemUsed", "dd", playerid, defId);
            sPlayerBleeding[playerid] = false;
            new Float:healAmount = (defId == ITEM_ID_SURGICAL_KIT) ? 65.0 : 45.0;
            if (Roles_HasPerk(roleId, PERK_FAST_REVIVE) || Roles_HasPerk(roleId, PERK_CHEM_YIELD_40))
            {
                healAmount *= 1.4;
            }
            hp += healAmount;
            if (hp > maxAllowedHp) hp = maxAllowedHp;
            SetPlayerHealth(playerid, hp);
            Skills_Add(playerid, SKILL_FIRST_AID, 5);
            ApplyAnimation(playerid, "BOMBER", "BOM_Plant", 4.1, false, false, false, false, 0, SYNC_ALL);
            SendClientMessage(playerid, COLOR_SUCCESS, "[Medicine]: You have provided yourself with medical care and restored your health.");
            Survival_RecalculateEncumbrance(playerid);
            return true;
        }
        case ITEM_ID_MORPHINE_SYRINGE:
        {
            if (!Storage_RemoveItem(storage_slot, item_slot, 1))
            {
                return false;
            }
            CallLocalFunction("Medical_OnItemUsed", "dd", playerid, defId);
            sMinutesSinceLastDose[playerid] = 0;
            sPlayerInWithdrawal[playerid] = false;
            SetPlayerDrunkLevel(playerid, 0);

            new Float:healBoost = Roles_HasPerk(roleId, PERK_DRUG_BOOST_25X) ? 50.0 : 25.0;
            hp += healBoost;
            if (hp > maxAllowedHp) hp = maxAllowedHp;
            SetPlayerHealth(playerid, hp);

            Character_SetStress(playerid, Character_GetStress(playerid) - 45.0);
            Character_SetAddiction(playerid, Character_GetAddiction(playerid) + 6.0);
            SendClientMessage(playerid, COLOR_SUCCESS, "[Medicine]: You administered a syringe tube of morphine. Pain and withdrawal symptoms are relieved.");
            Survival_RecalculateEncumbrance(playerid);
            return true;
        }
        case ITEM_ID_HARD_DRUG_METH, ITEM_ID_WEED_PACK:
        {
            if (!Storage_RemoveItem(storage_slot, item_slot, 1))
            {
                return false;
            }
            CallLocalFunction("Medical_OnItemUsed", "dd", playerid, defId);
            sMinutesSinceLastDose[playerid] = 0;
            sPlayerInWithdrawal[playerid] = false;
            SetPlayerDrunkLevel(playerid, 0);

            new Float:baseHpGain = (defId == ITEM_ID_HARD_DRUG_METH) ? 20.0 : 12.0;
            if (Roles_HasPerk(roleId, PERK_DRUG_BOOST_25X))
            {
                baseHpGain *= 2.5;
            }
            hp += baseHpGain;
            if (hp > maxAllowedHp) hp = maxAllowedHp;
            SetPlayerHealth(playerid, hp);

            Character_SetStress(playerid, 0.0);
            new Float:addictDelta = (defId == ITEM_ID_HARD_DRUG_METH) ? 12.0 : 4.0;
            Character_SetAddiction(playerid, Character_GetAddiction(playerid) + addictDelta);

            if (Roles_HasPerk(roleId, PERK_DRUG_BOOST_25X))
            {
                SendClientMessage(playerid, COLOR_WARNING, "[Chemistry]: The “Street Junkie” perk gave 2.5x income! Health increased above normal (up to 135 HP).");
            }
            else
            {
                SendClientMessage(playerid, COLOR_WARNING, "[Chemistry]: You have consumed a substance. Withdrawal and stress subsided, but addiction grew.");
            }
            Survival_RecalculateEncumbrance(playerid);
            return true;
        }
        case ITEM_ID_BODY_ARMOR:
        {
            new Float:itemDurability = Storage_GetItemDurability(item_slot);
            if (!Storage_RemoveItem(storage_slot, item_slot, 1))
            {
                return false;
            }
            new Float:targetArmour = itemDurability;
            if (Roles_HasPerk(roleId, PERK_ARMOR_BONUS_20))
            {
                targetArmour = (targetArmour * 1.2 > 120.0) ? 120.0 : (targetArmour * 1.2);
            }
            SetPlayerArmour(playerid, targetArmour);
            SendClientMessage(playerid, COLOR_SUCCESS, "[Equipment]: You are wearing heavy body armor.");
            Survival_RecalculateEncumbrance(playerid);
            return true;
        }
        case ITEM_ID_BALACLAVA:
        {
            sPlayerMasked[playerid] = !sPlayerMasked[playerid];
            if (sPlayerMasked[playerid])
            {
                for (new i = 0; i < MAX_PLAYERS; i++)
                {
                    if (IsPlayerConnected(i))
                    {
                        ShowPlayerNameTagForPlayer(i, playerid, false);
                    }
                }
                SendClientMessage(playerid, COLOR_INFO, "[Equipment]: You are wearing a tactical balaclava. Your face is hidden.");
            }
            else
            {
                for (new i = 0; i < MAX_PLAYERS; i++)
                {
                    if (IsPlayerConnected(i))
                    {
                        ShowPlayerNameTagForPlayer(i, playerid, true);
                    }
                }
                SendClientMessage(playerid, COLOR_INFO, "[Equipment]: You have removed your tactical balaclava.");
            }
            Internal_NotifyHudRefresh(playerid);
            return true;
        }
        case ITEM_ID_WALKIE_TALKIE:
        {
            if (sPlayerRadioFreqKhz[playerid] == 0)
            {
                sPlayerRadioFreqKhz[playerid] = 104500;
                SendClientMessage(playerid, COLOR_SUCCESS, "[Communication]: The walkie-talkie is on 104.500 MHz (104500 kHz).");
            }
            else
            {
                sPlayerRadioFreqKhz[playerid] = 0;
                SendClientMessage(playerid, COLOR_INFO, "[Communication]: The walkie-talkie is turned off.");
            }
            Internal_NotifyHudRefresh(playerid);
            return true;
        }
        case ITEM_ID_CLOTHING_OUTFIT:
        {
            Character_WearOutfitItem(playerid, item_slot);
            return true;
        }
        case ITEM_ID_PASSPORT:
        {
            Character_ShowStatsDialog(playerid);
            return true;
        }
    }

    // Если это оружие GTA — синхронизируем слоты оружия Слоя 1
    if (Item_GetGtaWeaponId(defId) > 0)
    {
        Character_SyncLayer1Weapons(playerid);
        SendClientMessage(playerid, COLOR_INFO, "[Weapons]: Outer layer weapon equipment is synchronized.");
        return true;
    }

    SendClientMessage(playerid, COLOR_GRAY, "[Inventory]: This item is used through special interaction or crafting.");
    return false;
}

// =============================================================================
//  5. МИНУТНЫЙ ТАЙМЕР ФИЗИОЛОГИИ ВЫЖИВАНИЯ, СТРЕССА И ЛОМКИ (y_timers)
// =============================================================================

task Survival_MinuteTask[60000]()
{
    if (Main_IsServerShuttingDown())
    {
        return 1;
    }

    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (!IsPlayerConnected(playerid) || !Character_IsLoaded(playerid))
        {
            continue;
        }

        new PLAYER_STATE:pState = GetPlayerState(playerid);
        if (pState == PLAYER_STATE_NONE || pState == PLAYER_STATE_WASTED || pState == PLAYER_STATE_SPECTATING)
        {
            continue;
        }

        new roleId = Character_GetRoleId(playerid);
        new Float:hungerDrain = SURVIVAL_BASE_HUNGER_DRAIN_MIN;
        new Float:thirstDrain = SURVIVAL_BASE_THIRST_DRAIN_MIN;
        new Float:stressDelta = 0.0;

        // Роль №1 (Бомж-Выживальщик): -60% к расходу голода и жажды
        if (Roles_HasPerk(roleId, PERK_LOW_METABOLISM_60))
        {
            hungerDrain *= 0.40;
            thirstDrain *= 0.40;
        }

        // Роль №21 (Качок-Вышибала): ускоренный метаболизм (x1.5 расход еды и воды)
        if (Roles_HasPerk(roleId, PERK_HIGH_METABOLISM))
        {
            hungerDrain *= 1.50;
            thirstDrain *= 1.50;
        }

        // Выносливость снижает базовый метаболический износ до 20%
        new enduranceSkill = Skills_Get(playerid, SKILL_STAMINA);
        if (enduranceSkill > 0)
        {
            new Float:enduranceFactor = 1.0 - (float(enduranceSkill) / 5000.0);
            hungerDrain *= enduranceFactor;
            thirstDrain *= enduranceFactor;
        }

        // Роль №19 (Реднек-Браконьер): в мегаполисах копится стресс, за городом -30% расхода сил
        if (Roles_HasPerk(roleId, PERK_FOREST_RUNNER))
        {
            if (Internal_IsPlayerInMajorCity(playerid))
            {
                stressDelta += 1.5;
            }
            else
            {
                hungerDrain *= 0.70;
                thirstDrain *= 0.70;
                stressDelta -= 1.0;
            }
        }

        // Проверка перегруза: W_layer1 > W_max увеличивает расход воды и сытости пропорционально массе
        new currentWeight = Survival_GetCarryWeightGrams(playerid);
        new maxWeight = Survival_GetMaxCarryWeightGrams(playerid);
        if (currentWeight > maxWeight && maxWeight > 0)
        {
            new Float:overloadRatio = float(currentWeight - maxWeight) / float(maxWeight);
            if (overloadRatio > 1.5) overloadRatio = 1.5;
            hungerDrain *= (1.0 + overloadRatio);
            thirstDrain *= (1.0 + overloadRatio * 1.25);
            stressDelta += 0.8;
        }

        new Float:newHunger = Character_GetHunger(playerid) - hungerDrain;
        new Float:newThirst = Character_GetThirst(playerid) - thirstDrain;
        new Float:newStress = Character_GetStress(playerid) + stressDelta;

        Character_SetHunger(playerid, newHunger);
        Character_SetThirst(playerid, newThirst);
        Character_SetStress(playerid, newStress);

        new Float:hp = 100.0;
        GetPlayerHealth(playerid, hp);
        new Float:totalHpDamage = 0.0;

        // Предупреждения и урон от истощения / обезвоживания
        if (Character_GetHunger(playerid) <= 0.0)
        {
            totalHpDamage += SURVIVAL_STARVATION_HP_DAMAGE;
            SendClientMessage(playerid, COLOR_ERROR, "[Survival]: You are suffering from extreme exhaustion! Find food quickly.");
        }
        else if (Character_GetHunger(playerid) < 15.0)
        {
            SendClientMessage(playerid, COLOR_WARNING, "[Survival]: A strong feeling of hunger reminds you.");
        }

        if (Character_GetThirst(playerid) <= 0.0)
        {
            totalHpDamage += SURVIVAL_DEHYDRATION_HP_DAMAGE;
            SendClientMessage(playerid, COLOR_ERROR, "[Survival]: Critical dehydration! Drink water immediately.");
        }
        else if (Character_GetThirst(playerid) < 15.0)
        {
            SendClientMessage(playerid, COLOR_WARNING, "[Survival]: You are extremely thirsty.");
        }

        // Кровотечение
        if (sPlayerBleeding[playerid])
        {
            totalHpDamage += SURVIVAL_BLEEDING_HP_DAMAGE;
            SendClientMessage(playerid, COLOR_ERROR, "[Medicine]: You're losing blood! Use a sterile bandage or tourniquet.");
        }

        // Таймер наркотической зависимости и ломки (каждые 40 минут без дозы)
        new Float:addiction = Character_GetAddiction(playerid);
        if (Roles_HasPerk(roleId, PERK_WITHDRAWAL_40M) || addiction >= SURVIVAL_ADDICTION_THRESHOLD)
        {
            sMinutesSinceLastDose[playerid]++;
            if (sMinutesSinceLastDose[playerid] >= SURVIVAL_WITHDRAWAL_MINUTES_LIMIT)
            {
                sPlayerInWithdrawal[playerid] = true;
                totalHpDamage += SURVIVAL_WITHDRAWAL_HP_DAMAGE;
                Character_SetStress(playerid, Character_GetStress(playerid) + 4.0);
                SetPlayerDrunkLevel(playerid, 4500);
                SendClientMessage(playerid, COLOR_ERROR, "[Addiction]: Severe drug withdrawal has begun! Hands are shaking, health is declining.");
            }
            else if (sMinutesSinceLastDose[playerid] == SURVIVAL_WITHDRAWAL_MINUTES_LIMIT - 5)
            {
                SendClientMessage(playerid, COLOR_WARNING, "[Addiction]: The body requires a new dose. In 5 minutes withdrawal will begin.");
            }
        }
        else
        {
            sPlayerInWithdrawal[playerid] = false;
        }

        // Уведомление о стрессе в мегаполисе для Реднека
        if (Roles_HasPerk(roleId, PERK_FOREST_RUNNER) && Character_GetStress(playerid) >= 75.0)
        {
            SendClientMessage(playerid, COLOR_WARNING, "[Psyche]: The noise of the metropolis puts pressure on you (high stress). Get out of the city into the forest or district.");
        }

        if (totalHpDamage > 0.0 && hp > 1.0)
        {
            new Float:updatedHp = hp - totalHpDamage;
            if (updatedHp < 1.0) updatedHp = 1.0;
            SetPlayerHealth(playerid, updatedHp);
        }

        Internal_NotifyHudRefresh(playerid);
    }
    return 1;
}

// =============================================================================
//  6. ПЕРЕХВАТЧИКИ СОБЫТИЙ ДВИЖКА (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        Survival_ResetPlayerRuntime(i);
    }

    // Самопроверка формулы грузоподъемности W_max = 25000 + (Skill_MUSCLE * 35) + Delta_role
    // Для Роли №13 (Портовый Грузчик, бонус +5000 г) при Skill_MUSCLE = 600:
    // W_max = 25000 + 21000 + 5000 = 51000 г (51.00 кг)
    new role13Bonus = Roles_GetWeightBonusGrams(13);
    new calcWMax = DEFAULT_PLAYER_LAYER1_WEIGHT_G + (600 * 35) + role13Bonus;
    printf("%s [Systems/Survival] Physiology, overload and withdrawal module initialized (Self-test W_max role #13 = %d r: %s).",
        SERVER_LOG_PREFIX,
        calcWMax,
        (calcWMax == 51000) ? "OK" : "ERROR");
    return 1;
}

hook OnPlayerConnect(playerid)
{
    Survival_ResetPlayerRuntime(playerid);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    Survival_ResetPlayerRuntime(playerid);
    return 1;
}

/*
 * Блокировка спринта при перегрузе (W_layer1 > W_max) и принудительный переход на шаг.
 */
hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    #pragma unused oldkeys
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }

    if ((newkeys & KEY_SPRINT) && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
    {
        if (Survival_IsOverweight(playerid))
        {
            ApplyAnimation(playerid, "PED", "WALK_player", 4.1, false, true, true, false, 600, SYNC_ALL);
            Character_SetThirst(playerid, Character_GetThirst(playerid) - 0.15);

            new nowTick = GetTickCount();
            if (nowTick - sLastOverweightWarnTick[playerid] >= SURVIVAL_OVERWEIGHT_NOTIFY_COOLDOWN_MS)
            {
                sLastOverweightWarnTick[playerid] = nowTick;
                new curW = Survival_GetCarryWeightGrams(playerid);
                new maxW = Survival_GetMaxCarryWeightGrams(playerid);
                new msg[144];
                format(msg, sizeof(msg),
                    "[Overload]: Equipment weight (%d.%02d / %d.%02d kg) exceeds the limit! Running is impossible.",
                    curW / 1000, (curW % 1000) / 10,
                    maxW / 1000, (maxW % 1000) / 10);
                SendClientMessage(playerid, COLOR_WARNING, msg);
                Internal_NotifyHudRefresh(playerid);
            }
        }
    }
    return 1;
}

/*
 * Серверный расчет урона, кровотечений, переломов и болевого шока полностью
 * перенесен в mod_medical.pwn (ROADMAP 5.2). Модуль выживания больше не
 * перехватывает OnPlayerTakeDamage, чтобы исключить двойной урон и двойное
 * начисление кровотечения.
 */

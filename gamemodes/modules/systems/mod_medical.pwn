/*
 * =============================================================================
 *  SAN ANDREAS RP — Медицина: зональные травмы, кровотечения, PK и CK
 *  Файл:      gamemodes/modules/systems/mod_medical.pwn
 *  Пункты:    ROADMAP [5.2, 5.3] — Медицина PK/CK (systems/mod_medical.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_medical_included
    #endinput
#endif
#define _mod_medical_included

#include <YSI_Coding\y_hooks>

// Публичные точки интеграции с mod_survival (вызываются через CallLocalFunction)
forward Medical_CanUseMedicalItem(playerid, def_id);
forward Medical_OnItemUsed(playerid, def_id);

// =============================================================================
//  1. КОНСТАНТЫ МЕДИЦИНЫ, ИДЕНТИФИКАТОРЫ ДИАЛОГОВ И ПРЕДМЕТОВ
// =============================================================================

#define DIALOG_MEDICAL_TRIAGE                   (1200)
#define DIALOG_MEDICAL_CK_CONFIRM               (1201)

#define MED_HEAD_MULTIPLIER                     (3.5)
#define MED_ARMOUR_ABSORB_PERCENT               (0.65)
#define MED_FRACTURE_HP_THRESHOLD               (30)
#define MED_RIBS_HP_THRESHOLD                   (25)
#define MED_VENOUS_DAMAGE                       (1.0)
#define MED_VENOUS_INTERVAL_SEC                 (5)
#define MED_ARTERIAL_DAMAGE                     (3.0)
#define MED_ARTERIAL_INTERVAL_SEC               (2)
#define MED_ARTERIAL_DEATH_SECONDS              (90)
#define MED_ARTERIAL_WARNING_SECONDS            (30)
#define MED_BLEEDING_DAMAGE_THRESHOLD_VENOUS    (25.0)
#define MED_BLEEDING_DAMAGE_THRESHOLD_ARTERIAL  (55.0)
#define MED_PAIN_SHOCK_THRESHOLD                (35.0)
#define MED_FRACTURE_NOTIFY_COOLDOWN_MS         (4000)
#define MED_SURGERY_SKILL_REQUIRED              (300)
#define MED_INJURY_SAVE_INTERVAL_SEC            (5)

#define HOSPITAL_LS_X                           (1172.5)
#define HOSPITAL_LS_Y                           (-1323.5)
#define HOSPITAL_LS_Z                           (13.5)
#define HOSPITAL_LS_A                           (270.0)

#if !defined ITEM_ID_FIRST_AID_KIT
    #define ITEM_ID_FIRST_AID_KIT               (56)
#endif
#if !defined ITEM_ID_SURGICAL_KIT
    #define ITEM_ID_SURGICAL_KIT                (57)
#endif
#if !defined ITEM_ID_BANDAGE
    #define ITEM_ID_BANDAGE                     (58)
#endif
#if !defined ITEM_ID_TOURNIQUET
    #define ITEM_ID_TOURNIQUET                  (59)
#endif
#if !defined ITEM_ID_MORPHINE_SYRINGE
    #define ITEM_ID_MORPHINE_SYRINGE            (60)
#endif
#if !defined ITEM_ID_HARD_DRUG_METH
    #define ITEM_ID_HARD_DRUG_METH              (66)
#endif
#if !defined ITEM_ID_WEED_PACK
    #define ITEM_ID_WEED_PACK                   (67)
#endif
#if !defined ITEM_ID_WEAPON_LICENSE
    #define ITEM_ID_WEAPON_LICENSE              (69)
#endif
#if !defined ITEM_ID_BANK_CARD
    #define ITEM_ID_BANK_CARD                   (71)
#endif

// =============================================================================
//  2. СТРУКТУРА ТРАВМ И ИНКАПСУЛИРОВАННОЕ СОСТОЯНИЕ (static stock)
// =============================================================================

enum E_INJURY_DATA
{
    bool:E_INJ_LOADED,
    bool:E_INJ_LOADING,
    E_INJ_CHAR_DB_ID,
    E_INJ_HEAD_HP,
    E_INJ_TORSO_HP,
    E_INJ_LEFT_ARM_HP,
    E_INJ_RIGHT_ARM_HP,
    E_INJ_LEFT_LEG_HP,
    E_INJ_RIGHT_LEG_HP,
    E_BLEEDING_TYPE:E_INJ_BLEEDING,
    E_INJ_ARTERIAL_TIMER,
    bool:E_INJ_PAIN_SHOCK,
    bool:E_INJ_TOURNIQUET,
    E_INJ_FRACTURES
};

static stock sInjuries[MAX_PLAYERS][E_INJURY_DATA];
static stock sBleedTick[MAX_PLAYERS];
static stock sInjurySaveTick[MAX_PLAYERS];
static stock bool:sPainShockApplied[MAX_PLAYERS];
static stock bool:sDeathHandled[MAX_PLAYERS];
static stock sLastFractureNoticeTick[MAX_PLAYERS];
static stock sMedicalSqlBuffer[1024];
static stock sLastMedicalCommandTick[MAX_PLAYERS];

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (static stock)
// =============================================================================

static stock Internal_BleedingTypeToString(E_BLEEDING_TYPE:type, output[], len = sizeof(output))
{
    switch (type)
    {
        case BLEEDING_VENOUS:   format(output, len, "VENOUS");
        case BLEEDING_ARTERIAL: format(output, len, "ARTERIAL");
        default:                format(output, len, "NONE");
    }
    return 1;
}

static stock E_BLEEDING_TYPE:Internal_ParseBleedingType(const typeStr[])
{
    if (!strcmp(typeStr, "VENOUS", true))   return BLEEDING_VENOUS;
    if (!strcmp(typeStr, "ARTERIAL", true)) return BLEEDING_ARTERIAL;
    return BLEEDING_NONE;
}

static stock Internal_GetBleedingNameRu(E_BLEEDING_TYPE:type, output[], len = sizeof(output))
{
    switch (type)
    {
        case BLEEDING_VENOUS:   format(output, len, "venous");
        case BLEEDING_ARTERIAL: format(output, len, "arterial");
        default:                format(output, len, "missing");
    }
    return 1;
}

static stock Internal_BuildFractureText(fractureFlags, output[], len = sizeof(output))
{
    output[0] = EOS;
    if (fractureFlags == 0)
    {
        format(output, len, "No");
        return 1;
    }

    if (fractureFlags & _:FRACTURE_LEFT_ARM)  strcat(output, "left hand;", len);
    if (fractureFlags & _:FRACTURE_RIGHT_ARM) strcat(output, "right hand;", len);
    if (fractureFlags & _:FRACTURE_LEFT_LEG)  strcat(output, "left leg;", len);
    if (fractureFlags & _:FRACTURE_RIGHT_LEG) strcat(output, "right leg;", len);
    if (fractureFlags & _:FRACTURE_RIBS)      strcat(output, "ribs;", len);

    if (output[0] == EOS)
    {
        format(output, len, "No");
    }
    return 1;
}

static stock Internal_ResetInjuries(playerid)
{
    sInjuries[playerid][E_INJ_HEAD_HP] = 100;
    sInjuries[playerid][E_INJ_TORSO_HP] = 100;
    sInjuries[playerid][E_INJ_LEFT_ARM_HP] = 100;
    sInjuries[playerid][E_INJ_RIGHT_ARM_HP] = 100;
    sInjuries[playerid][E_INJ_LEFT_LEG_HP] = 100;
    sInjuries[playerid][E_INJ_RIGHT_LEG_HP] = 100;
    sInjuries[playerid][E_INJ_BLEEDING] = BLEEDING_NONE;
    sInjuries[playerid][E_INJ_ARTERIAL_TIMER] = 0;
    sInjuries[playerid][E_INJ_PAIN_SHOCK] = false;
    sInjuries[playerid][E_INJ_TOURNIQUET] = false;
    sInjuries[playerid][E_INJ_FRACTURES] = 0;
    sBleedTick[playerid] = 0;
    sInjurySaveTick[playerid] = 0;
}

static stock Internal_ResetRuntime(playerid)
{
    sInjuries[playerid][E_INJ_LOADED] = false;
    sInjuries[playerid][E_INJ_LOADING] = false;
    sInjuries[playerid][E_INJ_CHAR_DB_ID] = 0;
    Internal_ResetInjuries(playerid);
    sPainShockApplied[playerid] = false;
    sDeathHandled[playerid] = false;
    sLastFractureNoticeTick[playerid] = 0;
    sLastMedicalCommandTick[playerid] = 0;
}

static stock Internal_SaveInjuries(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    if (!sInjuries[playerid][E_INJ_LOADED])
    {
        return 0;
    }

    new const charDbId = sInjuries[playerid][E_INJ_CHAR_DB_ID];
    if (charDbId <= 0 || !DB_IsConnected())
    {
        return 0;
    }

    new bleedingStr[16];
    Internal_BleedingTypeToString(sInjuries[playerid][E_INJ_BLEEDING], bleedingStr, sizeof(bleedingStr));

    mysql_format(gMySQL, sMedicalSqlBuffer, sizeof(sMedicalSqlBuffer),
        "UPDATE `character_injuries` SET `head_hp` = %d, `torso_hp` = %d, `left_arm_hp` = %d, `right_arm_hp` = %d, `left_leg_hp` = %d, `right_leg_hp` = %d, `bleeding_type` = '%e', `arterial_timer_sec` = %d, `pain_shock` = %d, `fracture_flags` = %d WHERE `char_id` = %d;",
        sInjuries[playerid][E_INJ_HEAD_HP],
        sInjuries[playerid][E_INJ_TORSO_HP],
        sInjuries[playerid][E_INJ_LEFT_ARM_HP],
        sInjuries[playerid][E_INJ_RIGHT_ARM_HP],
        sInjuries[playerid][E_INJ_LEFT_LEG_HP],
        sInjuries[playerid][E_INJ_RIGHT_LEG_HP],
        bleedingStr,
        sInjuries[playerid][E_INJ_ARTERIAL_TIMER],
        sInjuries[playerid][E_INJ_PAIN_SHOCK] ? 1 : 0,
        sInjuries[playerid][E_INJ_FRACTURES],
        charDbId);

    DB_EnqueueDirtyQuery(DIRTY_ENTITY_INJURY, charDbId, sMedicalSqlBuffer);
    return 1;
}

static stock Internal_NotifyHud(playerid)
{
    CallLocalFunction("OnPlayerHudNeedsUpdate", "d", playerid);
}

static stock Internal_HealPlayer(playerid, Float:amount)
{
    if (!IsPlayerConnected(playerid) || amount <= 0.0)
    {
        return 0;
    }

    new const roleId = Character_GetRoleId(playerid);
    new Float:maxHp = 100.0;
    if (Roles_HasPerk(roleId, PERK_DRUG_BOOST_25X))
    {
        maxHp = 135.0;
    }
    else if (Roles_HasPerk(roleId, PERK_SILENT_PICKPOCKET))
    {
        maxHp = 85.0;
    }

    new Float:hp = 100.0;
    GetPlayerHealth(playerid, hp);
    hp += amount;
    if (hp > maxHp)
    {
        hp = maxHp;
    }
    SetPlayerHealth(playerid, hp);
    return 1;
}

static stock bool:Internal_HasItemInLayer1(playerid, def_id)
{
    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        return false;
    }

    new itemSlot = Storage_GetFirstItemSlot(layer1Slot);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        if (Storage_GetItemDefId(itemSlot) == def_id && Storage_GetItemAmount(itemSlot) > 0)
        {
            return true;
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }
    return false;
}

static stock bool:Internal_ConsumeItem(playerid, def_id)
{
    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        return false;
    }

    new itemSlot = Storage_GetFirstItemSlot(layer1Slot);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        if (Storage_GetItemDefId(itemSlot) == def_id && Storage_GetItemAmount(itemSlot) > 0)
        {
            if (Storage_RemoveItem(layer1Slot, itemSlot, 1))
            {
                Survival_RecalculateEncumbrance(playerid);
                Internal_NotifyHud(playerid);
                return true;
            }
            return false;
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }
    return false;
}

static stock Internal_RemoveAllItemsByDef(playerid, def_id)
{
    new storages[2];
    storages[0] = Character_GetLayer1Slot(playerid);
    storages[1] = Character_GetLayer2Slot(playerid);

    for (new stIdx = 0; stIdx < 2; stIdx++)
    {
        if (!Storage_IsValidSlot(storages[stIdx]))
        {
            continue;
        }
        new itemSlot = Storage_GetFirstItemSlot(storages[stIdx]);
        while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
        {
            new const nextSlot = Storage_GetNextItemSlot(itemSlot);
            if (Storage_GetItemDefId(itemSlot) == def_id)
            {
                Storage_RemoveItem(storages[stIdx], itemSlot, Storage_GetItemAmount(itemSlot));
            }
            itemSlot = nextSlot;
        }
    }
}

static stock Internal_StartBleeding(playerid, E_BLEEDING_TYPE:type)
{
    if (type == BLEEDING_NONE || sInjuries[playerid][E_INJ_BLEEDING] == BLEEDING_ARTERIAL)
    {
        return 0;
    }
    if (sInjuries[playerid][E_INJ_BLEEDING] == type)
    {
        return 0;
    }

    sInjuries[playerid][E_INJ_BLEEDING] = type;
    sInjuries[playerid][E_INJ_TOURNIQUET] = false;
    sBleedTick[playerid] = 0;

    if (type == BLEEDING_ARTERIAL)
    {
        sInjuries[playerid][E_INJ_ARTERIAL_TIMER] = MED_ARTERIAL_DEATH_SECONDS;
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Medicine]: Arterial bleeding! You have 90 seconds to apply a tourniquet or die.");
    }
    else
    {
        sInjuries[playerid][E_INJ_ARTERIAL_TIMER] = 0;
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Medicine]: Venous bleeding has opened. Dress the wound with a bandage or first aid kit.");
    }

    Internal_SaveInjuries(playerid);
    Internal_NotifyHud(playerid);
    return 1;
}

static stock Internal_StopBleeding(playerid, bool:tourniquetApplied)
{
    sInjuries[playerid][E_INJ_BLEEDING] = BLEEDING_NONE;
    sInjuries[playerid][E_INJ_ARTERIAL_TIMER] = 0;
    sInjuries[playerid][E_INJ_TOURNIQUET] = tourniquetApplied;
    sBleedTick[playerid] = 0;
    Internal_SaveInjuries(playerid);
    Internal_NotifyHud(playerid);
    return 1;
}

static stock Internal_NotifyFracture(playerid, const bodyName[])
{
    new const nowTick = GetTickCount();
    if ((nowTick - sLastFractureNoticeTick[playerid]) < MED_FRACTURE_NOTIFY_COOLDOWN_MS)
    {
        return 0;
    }
    sLastFractureNoticeTick[playerid] = nowTick;

    new message[160];
    format(message, sizeof(message),
        "[Medicine]: You have a fracture (%s). Surgical assistance is needed (Field Surgery skill at least 300).",
        bodyName);
    SendClientMessage(playerid, COLOR_UI_ERROR, message);
    return 1;
}

static stock Internal_DropHeldWeapon(playerid)
{
    new const WEAPON:heldWeapon = GetPlayerWeapon(playerid);
    if (!Weapons_IsTrackedFirearm(_:heldWeapon))
    {
        return 0;
    }

    new const itemSlot = Weapons_GetItemSlot(playerid, heldWeapon, true);
    if (itemSlot == INVALID_STORAGE_ITEM_SLOT)
    {
        return 0;
    }

    new const srcStorage = Storage_GetItemStorageSlot(itemSlot);
    if (!Storage_IsValidSlot(srcStorage))
    {
        return 0;
    }

    new Float:x = 0.0, Float:y = 0.0, Float:z = 0.0;
    GetPlayerPos(playerid, x, y, z);

    new const dropSlot = Storage_CreateWorldDrop(
        x, y, z,
        GetPlayerInterior(playerid),
        GetPlayerVirtualWorld(playerid),
        Storage_GetItemDefId(itemSlot));
    if (!Storage_IsValidSlot(dropSlot))
    {
        return 0;
    }

    new const amount = Storage_GetItemAmount(itemSlot);
    if (Storage_TransferItem(playerid, srcStorage, itemSlot, dropSlot, amount, Character_GetId(playerid)) != STORAGE_RES_OK)
    {
        Storage_DestroyExpiredOrEmpty(dropSlot);
        return 0;
    }

    Character_SyncLayer1Weapons(playerid);
    Survival_RecalculateEncumbrance(playerid);

    SendClientMessage(playerid, COLOR_UI_ERROR,
        "[Medicine]: From the shock of pain and a broken arm, you dropped your weapon to the ground.");
    Internal_NotifyHud(playerid);
    return 1;
}

static stock Internal_ApplyBodyPartDamage(playerid, bodypart, Float:damage)
{
    new damageInt = floatround(damage);
    if (damageInt < 1)
    {
        damageInt = 1;
    }

    switch (bodypart)
    {
        case (_:BODY_PART_HEAD):
        {
            new zoneHp = sInjuries[playerid][E_INJ_HEAD_HP] - damageInt;
            if (zoneHp < 0) zoneHp = 0;
            sInjuries[playerid][E_INJ_HEAD_HP] = zoneHp;
        }
        case (_:BODY_PART_LEFT_ARM):
        {
            new zoneHp = sInjuries[playerid][E_INJ_LEFT_ARM_HP] - damageInt;
            if (zoneHp < 0) zoneHp = 0;
            sInjuries[playerid][E_INJ_LEFT_ARM_HP] = zoneHp;

            if (zoneHp < MED_FRACTURE_HP_THRESHOLD &&
                (sInjuries[playerid][E_INJ_FRACTURES] & _:FRACTURE_LEFT_ARM) == 0)
            {
                sInjuries[playerid][E_INJ_FRACTURES] |= _:FRACTURE_LEFT_ARM;
                Internal_NotifyFracture(playerid, "left hand");
                Internal_DropHeldWeapon(playerid);
            }
        }
        case (_:BODY_PART_RIGHT_ARM):
        {
            new zoneHp = sInjuries[playerid][E_INJ_RIGHT_ARM_HP] - damageInt;
            if (zoneHp < 0) zoneHp = 0;
            sInjuries[playerid][E_INJ_RIGHT_ARM_HP] = zoneHp;

            if (zoneHp < MED_FRACTURE_HP_THRESHOLD &&
                (sInjuries[playerid][E_INJ_FRACTURES] & _:FRACTURE_RIGHT_ARM) == 0)
            {
                sInjuries[playerid][E_INJ_FRACTURES] |= _:FRACTURE_RIGHT_ARM;
                Internal_NotifyFracture(playerid, "right hand");
                Internal_DropHeldWeapon(playerid);
            }
        }
        case (_:BODY_PART_LEFT_LEG):
        {
            new zoneHp = sInjuries[playerid][E_INJ_LEFT_LEG_HP] - damageInt;
            if (zoneHp < 0) zoneHp = 0;
            sInjuries[playerid][E_INJ_LEFT_LEG_HP] = zoneHp;

            if (zoneHp < MED_FRACTURE_HP_THRESHOLD &&
                (sInjuries[playerid][E_INJ_FRACTURES] & _:FRACTURE_LEFT_LEG) == 0)
            {
                sInjuries[playerid][E_INJ_FRACTURES] |= _:FRACTURE_LEFT_LEG;
                Internal_NotifyFracture(playerid, "left leg");
            }
        }
        case (_:BODY_PART_RIGHT_LEG):
        {
            new zoneHp = sInjuries[playerid][E_INJ_RIGHT_LEG_HP] - damageInt;
            if (zoneHp < 0) zoneHp = 0;
            sInjuries[playerid][E_INJ_RIGHT_LEG_HP] = zoneHp;

            if (zoneHp < MED_FRACTURE_HP_THRESHOLD &&
                (sInjuries[playerid][E_INJ_FRACTURES] & _:FRACTURE_RIGHT_LEG) == 0)
            {
                sInjuries[playerid][E_INJ_FRACTURES] |= _:FRACTURE_RIGHT_LEG;
                Internal_NotifyFracture(playerid, "right leg");
            }
        }
        default:
        {
            new zoneHp = sInjuries[playerid][E_INJ_TORSO_HP] - damageInt;
            if (zoneHp < 0) zoneHp = 0;
            sInjuries[playerid][E_INJ_TORSO_HP] = zoneHp;

            if (zoneHp < MED_RIBS_HP_THRESHOLD &&
                (sInjuries[playerid][E_INJ_FRACTURES] & _:FRACTURE_RIBS) == 0)
            {
                sInjuries[playerid][E_INJ_FRACTURES] |= _:FRACTURE_RIBS;
                Internal_NotifyFracture(playerid, "ribs");
            }
        }
    }

    Internal_SaveInjuries(playerid);
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API МЕДИЦИНЫ (Medical_*)
// =============================================================================

stock Medical_EnsureInjuriesLoaded(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !IsPlayerConnected(playerid))
    {
        return 0;
    }
    if (sInjuries[playerid][E_INJ_LOADED] || sInjuries[playerid][E_INJ_LOADING])
    {
        return 1;
    }
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    new const charDbId = Character_GetId(playerid);
    if (charDbId <= 0)
    {
        return 0;
    }

    Internal_ResetInjuries(playerid);
    sInjuries[playerid][E_INJ_CHAR_DB_ID] = charDbId;

    if (!DB_IsConnected())
    {
        sInjuries[playerid][E_INJ_LOADED] = true;
        return 1;
    }

    sInjuries[playerid][E_INJ_LOADING] = true;
    mysql_format(gMySQL, sMedicalSqlBuffer, sizeof(sMedicalSqlBuffer),
        "SELECT `head_hp`, `torso_hp`, `left_arm_hp`, `right_arm_hp`, `left_leg_hp`, `right_leg_hp`, `bleeding_type`, `arterial_timer_sec`, `pain_shock`, `fracture_flags` FROM `character_injuries` WHERE `char_id` = %d LIMIT 1;",
        charDbId);
    mysql_tquery(gMySQL, sMedicalSqlBuffer, "OnMedicalInjuriesLoaded", "dd",
        playerid, Config_GetPlayerSessionToken(playerid));
    return 1;
}

stock bool:Medical_IsBleeding(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return false;
    }
    return (sInjuries[playerid][E_INJ_BLEEDING] != BLEEDING_NONE);
}

stock E_BLEEDING_TYPE:Medical_GetBleedingType(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return BLEEDING_NONE;
    }
    return sInjuries[playerid][E_INJ_BLEEDING];
}

stock Medical_GetArterialSeconds(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    return sInjuries[playerid][E_INJ_ARTERIAL_TIMER];
}

stock Medical_GetFractureFlags(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    return sInjuries[playerid][E_INJ_FRACTURES];
}

stock bool:Medical_HasFracture(playerid, E_FRACTURE_FLAGS:flag)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return false;
    }
    return ((sInjuries[playerid][E_INJ_FRACTURES] & _:flag) != 0);
}

stock bool:Medical_IsPainShock(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return false;
    }
    return sInjuries[playerid][E_INJ_PAIN_SHOCK];
}

stock Medical_GetZoneHp(playerid, bodypart)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    switch (bodypart)
    {
        case (_:BODY_PART_HEAD):      return sInjuries[playerid][E_INJ_HEAD_HP];
        case (_:BODY_PART_LEFT_ARM):  return sInjuries[playerid][E_INJ_LEFT_ARM_HP];
        case (_:BODY_PART_RIGHT_ARM): return sInjuries[playerid][E_INJ_RIGHT_ARM_HP];
        case (_:BODY_PART_LEFT_LEG):  return sInjuries[playerid][E_INJ_LEFT_LEG_HP];
        case (_:BODY_PART_RIGHT_LEG): return sInjuries[playerid][E_INJ_RIGHT_LEG_HP];
    }
    return sInjuries[playerid][E_INJ_TORSO_HP];
}

// Вызывается из mod_survival перед списанием медицинского предмета
public Medical_CanUseMedicalItem(playerid, def_id)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 1;
    }
    if (!sInjuries[playerid][E_INJ_LOADED])
    {
        return 1;
    }

    if (sInjuries[playerid][E_INJ_BLEEDING] == BLEEDING_ARTERIAL)
    {
        if (def_id == ITEM_ID_BANDAGE || def_id == ITEM_ID_FIRST_AID_KIT)
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "[Medicine]: A bandage or first aid kit will not stop arterial bleeding. Apply a hemostatic tourniquet!");
            return 0;
        }
        if (def_id == ITEM_ID_SURGICAL_KIT && !sInjuries[playerid][E_INJ_TOURNIQUET])
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "[Medical]: Before surgical stabilization, apply a tourniquet first!");
            return 0;
        }
    }
    return 1;
}

// Вызывается из mod_survival после успешного применения медицинского предмета
public Medical_OnItemUsed(playerid, def_id)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !sInjuries[playerid][E_INJ_LOADED])
    {
        return 0;
    }

    switch (def_id)
    {
        case ITEM_ID_BANDAGE:
        {
            if (sInjuries[playerid][E_INJ_BLEEDING] == BLEEDING_VENOUS)
            {
                Internal_StopBleeding(playerid, false);
                SendClientMessage(playerid, COLOR_UI_SUCCESS,
                    "[Medicine]: You stopped venous bleeding with a sterile bandage.");
            }
        }
        case ITEM_ID_TOURNIQUET:
        {
            if (sInjuries[playerid][E_INJ_BLEEDING] != BLEEDING_NONE)
            {
                new const bool:wasArterial = (sInjuries[playerid][E_INJ_BLEEDING] == BLEEDING_ARTERIAL);
                Internal_StopBleeding(playerid, wasArterial);
                if (wasArterial)
                {
                    SendClientMessage(playerid, COLOR_UI_WARNING,
                        "[Medicine]: A tourniquet has been applied and the bleeding has stopped. Requires surgical stabilization (Field Surgery skill 300+).");
                }
                else
                {
                    SendClientMessage(playerid, COLOR_UI_SUCCESS,
                        "[Medicine]: You applied a tourniquet and stopped the bleeding.");
                }
            }
        }
        case ITEM_ID_FIRST_AID_KIT:
        {
            if (sInjuries[playerid][E_INJ_BLEEDING] == BLEEDING_VENOUS)
            {
                Internal_StopBleeding(playerid, false);
                SendClientMessage(playerid, COLOR_UI_SUCCESS,
                    "[Medicine]: You stopped the bleeding and treated the wound with a first aid kit.");
            }
        }
        case ITEM_ID_SURGICAL_KIT:
        {
            if (Skills_Get(playerid, SKILL_SURGERY) >= MED_SURGERY_SKILL_REQUIRED)
            {
                Internal_StopBleeding(playerid, false);
                sInjuries[playerid][E_INJ_FRACTURES] = 0;
                Internal_SaveInjuries(playerid);
                SendClientMessage(playerid, COLOR_UI_SUCCESS,
                    "[Medicine]: You performed a field operation: the bleeding was stopped, the fractures were fixed.");
            }
            else
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "[Medicine]: Surgical stabilization requires a Field Surgery skill of at least 300.");
            }
        }
        case ITEM_ID_MORPHINE_SYRINGE, ITEM_ID_HARD_DRUG_METH, ITEM_ID_WEED_PACK:
        {
            if (sInjuries[playerid][E_INJ_PAIN_SHOCK])
            {
                sInjuries[playerid][E_INJ_PAIN_SHOCK] = false;
                sPainShockApplied[playerid] = false;
                SetPlayerDrunkLevel(playerid, 0);
                Internal_SaveInjuries(playerid);
                SendClientMessage(playerid, COLOR_UI_SUCCESS,
                    "[Medicine]: Pain shock relieved. The effect of the drug is temporary.");
            }
        }
    }

    Internal_NotifyHud(playerid);
    return 1;
}

stock Medical_ShowTriageDialog(viewerid, targetid)
{
    if (viewerid < 0 || viewerid >= MAX_PLAYERS || targetid < 0 || targetid >= MAX_PLAYERS)
    {
        return 0;
    }
    Medical_EnsureInjuriesLoaded(targetid);
    if (!sInjuries[targetid][E_INJ_LOADED])
    {
        SendClientMessage(viewerid, COLOR_UI_WARNING,
            "[Medical]: The patient's medical record is still loading. Repeat the command after a moment.");
        return 0;
    }

    new targetName[MAX_PLAYER_NAME + 1];
    Character_GetRpName(targetid, targetName, sizeof(targetName));

    new bleedingName[32];
    Internal_GetBleedingNameRu(sInjuries[targetid][E_INJ_BLEEDING], bleedingName, sizeof(bleedingName));

    new fractureText[96];
    Internal_BuildFractureText(sInjuries[targetid][E_INJ_FRACTURES], fractureText, sizeof(fractureText));

    new title[144];
    format(title, sizeof(title), "Medical examination: %s", targetName);

    new body[1400];
    format(body, sizeof(body),
        "{FFC800}Zonal damage:{FFFFFF}\n" \
        "• Head: %d%%\n" \
        "• Torso: %d%%\n" \
        "• Left hand: %d%%\n" \
        "• Right hand: %d%%\n" \
        "• Left leg: %d%%\n" \
        "• Right leg: %d%%\n\n" \
        "{FFC800} Clinical picture: {FFFFFF}\n" \
        "• Bleeding: %s\n" \
        "• Before death: %d sec.\n" \
        "• Tourniquet applied: %s\n" \
        "• Pain shock: %s\n" \
        "• Fractures: %s\n\n" \
        "{90A4AE}Treat: /treat [id]. For arterial bleeding you need a tourniquet, then a surgical kit.{FFFFFF}",
        sInjuries[targetid][E_INJ_HEAD_HP],
        sInjuries[targetid][E_INJ_TORSO_HP],
        sInjuries[targetid][E_INJ_LEFT_ARM_HP],
        sInjuries[targetid][E_INJ_RIGHT_ARM_HP],
        sInjuries[targetid][E_INJ_LEFT_LEG_HP],
        sInjuries[targetid][E_INJ_RIGHT_LEG_HP],
        bleedingName,
        sInjuries[targetid][E_INJ_ARTERIAL_TIMER],
        sInjuries[targetid][E_INJ_TOURNIQUET] ? ("Yes") : ("No"),
        sInjuries[targetid][E_INJ_PAIN_SHOCK] ? ("Yes") : ("No"),
        fractureText);

    ShowPlayerDialog(viewerid, DIALOG_MEDICAL_TRIAGE, DIALOG_STYLE_MSGBOX, title, body, "Understood", "");
    return 1;
}

stock Medical_ApplyCharacterKill(playerid, actor_char_id, const reason[])
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }

    new const charDbId = Character_GetId(playerid);
    if (charDbId <= 0)
    {
        return 0;
    }

    new victimName[MAX_PLAYER_NAME + 1];
    Character_GetRpName(playerid, victimName, sizeof(victimName));

    Internal_RemoveAllItemsByDef(playerid, ITEM_ID_WEAPON_LICENSE);
    Internal_RemoveAllItemsByDef(playerid, ITEM_ID_BANK_CARD);

    if (DB_IsConnected())
    {
        mysql_format(gMySQL, sMedicalSqlBuffer, sizeof(sMedicalSqlBuffer),
            "UPDATE `characters` SET `is_ck_dead` = 1, `hp` = 0, `armour` = 0, `weapon_license_banned` = 1 WHERE `id` = %d;",
            charDbId);
        mysql_tquery(gMySQL, sMedicalSqlBuffer);

        mysql_format(gMySQL, sMedicalSqlBuffer, sizeof(sMedicalSqlBuffer),
            "DELETE FROM `bank_accounts` WHERE `owner_char_id` = %d;",
            charDbId);
        mysql_tquery(gMySQL, sMedicalSqlBuffer);
    }

    new details[255];
    format(details, sizeof(details),
        "Permanent death of the character %s (ID %d). Reason: %s. Bank accounts and licenses were cancelled.",
        victimName, charDbId, reason);
    Audit_Log((actor_char_id > 0) ? actor_char_id : charDbId, "CHARACTER_KILL", "CHARACTER", "CHARACTER",
        0, 1, details);

    SendClientMessage(playerid, COLOR_UI_ERROR,
        "[Permanent Death]: Your character is dead forever. Bank accounts and licenses were cancelled.");

    defer Medical_CkKickTimer(playerid, Config_GetPlayerSessionToken(playerid));
    return 1;
}

// =============================================================================
//  5. АСИНХРОННЫЕ КОЛБЕКИ МЕДИЦИНЫ (forward / public)
// =============================================================================

forward OnMedicalInjuriesLoaded(playerid, sessionToken);
public OnMedicalInjuriesLoaded(playerid, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 0;
    }

    sInjuries[playerid][E_INJ_LOADING] = false;

    // Игрок погиб до завершения загрузки: запоздавший ответ БД не должен
    // вернуть сброшенные травмы и запустить кровотечение у трупа.
    if (sDeathHandled[playerid])
    {
        sInjuries[playerid][E_INJ_LOADED] = true;
        return 1;
    }

    new rows = 0;
    cache_get_row_count(rows);

    if (rows <= 0)
    {
        sInjuries[playerid][E_INJ_LOADED] = true;
        if (DB_IsConnected())
        {
            new const charDbId = sInjuries[playerid][E_INJ_CHAR_DB_ID];
            if (charDbId > 0)
            {
                mysql_format(gMySQL, sMedicalSqlBuffer, sizeof(sMedicalSqlBuffer),
                    "INSERT INTO `character_injuries` (`char_id`) VALUES (%d) ON DUPLICATE KEY UPDATE `char_id` = `char_id`;",
                    charDbId);
                mysql_tquery(gMySQL, sMedicalSqlBuffer);
            }
        }
        return 1;
    }

    new bleedingStr[16];
    new painShockInt = 0;

    cache_get_value_name_int(0, "head_hp", sInjuries[playerid][E_INJ_HEAD_HP]);
    cache_get_value_name_int(0, "torso_hp", sInjuries[playerid][E_INJ_TORSO_HP]);
    cache_get_value_name_int(0, "left_arm_hp", sInjuries[playerid][E_INJ_LEFT_ARM_HP]);
    cache_get_value_name_int(0, "right_arm_hp", sInjuries[playerid][E_INJ_RIGHT_ARM_HP]);
    cache_get_value_name_int(0, "left_leg_hp", sInjuries[playerid][E_INJ_LEFT_LEG_HP]);
    cache_get_value_name_int(0, "right_leg_hp", sInjuries[playerid][E_INJ_RIGHT_LEG_HP]);
    cache_get_value_name(0, "bleeding_type", bleedingStr, sizeof(bleedingStr));
    cache_get_value_name_int(0, "arterial_timer_sec", sInjuries[playerid][E_INJ_ARTERIAL_TIMER]);
    cache_get_value_name_int(0, "pain_shock", painShockInt);
    cache_get_value_name_int(0, "fracture_flags", sInjuries[playerid][E_INJ_FRACTURES]);

    sInjuries[playerid][E_INJ_BLEEDING] = Internal_ParseBleedingType(bleedingStr);
    sInjuries[playerid][E_INJ_PAIN_SHOCK] = (painShockInt != 0);
    sInjuries[playerid][E_INJ_LOADED] = true;

    if (sInjuries[playerid][E_INJ_BLEEDING] == BLEEDING_ARTERIAL)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Medical]: Your medical record has been uploaded. You have active arterial bleeding!");
        if (sInjuries[playerid][E_INJ_ARTERIAL_TIMER] <= 0)
        {
            sInjuries[playerid][E_INJ_ARTERIAL_TIMER] = MED_ARTERIAL_DEATH_SECONDS;
        }
    }
    return 1;
}

// =============================================================================
//  6. ХУКИ СИСТЕМНЫХ СОБЫТИЙ (y_hooks)
// =============================================================================

hook OnPlayerConnect(playerid)
{
    Internal_ResetRuntime(playerid);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    Internal_SaveInjuries(playerid);
    Internal_ResetRuntime(playerid);
    return 1;
}

hook OnPlayerSpawn(playerid)
{
    sDeathHandled[playerid] = false;
    sPainShockApplied[playerid] = false;
    sLastFractureNoticeTick[playerid] = 0;
    Medical_EnsureInjuriesLoaded(playerid);
    return 1;
}

// Серверный расчет урона: множители по зонам, броня, кровотечения и переломы
hook OnPlayerTakeDamage(playerid, issuerid, Float:amount, WEAPON:weaponid, bodypart)
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (amount <= 0.0)
    {
        return 1;
    }

    Medical_EnsureInjuriesLoaded(playerid);

    new const roleId = Character_GetRoleId(playerid);
    new Float:finalDamage = amount;
    new Float:injuryDamage = amount;

    // Перк «Сектант»: -50% урона от огня (огнемет и коктейль Молотова)
    if (Roles_HasPerk(roleId, PERK_FIRE_RESIST_50) && (_:weaponid == 18 || _:weaponid == 37))
    {
        finalDamage *= 0.50;
    }

    // Голова: множитель x3.5
    if (bodypart == (_:BODY_PART_HEAD))
    {
        finalDamage *= MED_HEAD_MULTIPLIER;
        injuryDamage *= MED_HEAD_MULTIPLIER;
    }

    new Float:armour = 0.0;
    GetPlayerArmour(playerid, armour);
    new const bool:hadArmour = (armour > 0.0);

    if (armour > 0.0)
    {
        new Float:absorbed = finalDamage * MED_ARMOUR_ABSORB_PERCENT;
        if (absorbed > armour)
        {
            absorbed = armour;
        }
        armour -= absorbed;
        finalDamage -= absorbed;
        SetPlayerArmour(playerid, armour);
    }

    if (finalDamage < 0.0)
    {
        finalDamage = 0.0;
    }

    new Float:hp = 100.0;
    GetPlayerHealth(playerid, hp);
    new Float:newHp = hp - finalDamage;

    // Выстрел в голову без шлема/брони — мгновенная смерть
    if (bodypart == (_:BODY_PART_HEAD) && !hadArmour)
    {
        newHp = 0.0;
    }

    Internal_ApplyBodyPartDamage(playerid, bodypart, injuryDamage);

    // Порог кровотечений: > 25 HP — венозное, > 55 HP — артериальное
    if (finalDamage > MED_BLEEDING_DAMAGE_THRESHOLD_ARTERIAL)
    {
        Internal_StartBleeding(playerid, BLEEDING_ARTERIAL);
    }
    else if (finalDamage > MED_BLEEDING_DAMAGE_THRESHOLD_VENOUS)
    {
        Internal_StartBleeding(playerid, BLEEDING_VENOUS);
    }

    // Болевой шок (кроме роли с иммунитетом)
    if (!Roles_HasPerk(roleId, PERK_SHOCK_IMMUNE) &&
        (finalDamage >= MED_PAIN_SHOCK_THRESHOLD || bodypart == (_:BODY_PART_HEAD)))
    {
        sInjuries[playerid][E_INJ_PAIN_SHOCK] = true;
    }

    // Роль «Качок-Вышибала»: сбивает с ног ударом кулака
    if (issuerid != INVALID_PLAYER_ID && Character_IsLoaded(issuerid) &&
        _:weaponid == 0 && Roles_HasPerk(Character_GetRoleId(issuerid), PERK_HIGH_METABOLISM))
    {
        ApplyAnimation(playerid, "PED", "FALL_back", 4.1, false, true, true, false, 1200, SYNC_ALL);
    }

    if (newHp < 0.0)
    {
        newHp = 0.0;
    }
    SetPlayerHealth(playerid, newHp);

    Internal_SaveInjuries(playerid);
    Internal_NotifyHud(playerid);

    // Полностью блокируем нативный урон и дальнейшие хуки: HP рассчитан сервером
    return ~0;
}

// Мгновенная смерть (PK): тело превращается в контейнер CORPSE_LOOT
hook OnPlayerDeath(playerid, killerid, reason)
{
    #pragma unused killerid, reason

    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (sDeathHandled[playerid])
    {
        return 1;
    }
    sDeathHandled[playerid] = true;

    Medical_EnsureInjuriesLoaded(playerid);

    new Float:x = 0.0, Float:y = 0.0, Float:z = 0.0;
    GetPlayerPos(playerid, x, y, z);

    new victimName[MAX_PLAYER_NAME + 1];
    Character_GetRpName(playerid, victimName, sizeof(victimName));

    new const corpseSlot = Storage_CreateCorpseLoot(
        Character_GetId(playerid),
        victimName,
        x, y, z,
        GetPlayerInterior(playerid),
        GetPlayerVirtualWorld(playerid),
        TTL_CORPSE_LOOT_SECONDS);

    if (Storage_IsValidSlot(corpseSlot))
    {
        new const layer1Slot = Character_GetLayer1Slot(playerid);
        if (Storage_IsValidSlot(layer1Slot))
        {
            new const moved = Storage_TransferAllItems(layer1Slot, corpseSlot, Character_GetId(playerid));
            if (moved <= 0)
            {
                SendClientMessage(playerid, COLOR_UI_WARNING,
                    "[Death]: Your outer inventory layer was empty.");
            }
        }
    }
    else
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Death]: Failed to create corpse container. Contact the administration.");
    }

    Character_SyncLayer1Weapons(playerid);

    Internal_ResetInjuries(playerid);
    sInjuries[playerid][E_INJ_LOADED] = true;
    Internal_SaveInjuries(playerid);
    sPainShockApplied[playerid] = false;
    SetPlayerDrunkLevel(playerid, 0);

    Character_MarkDirty(playerid);

    SendClientMessage(playerid, COLOR_UI_ERROR,
        "[Death]: You are dead. All outer layer items remain in your corpse for 20 minutes.");
    SendClientMessage(playerid, COLOR_UI_INFO,
        "[Death]: Documents, phone, bank card and secret layer are saved. You will wake up in a Los Santos hospital.");

    defer Medical_HospitalRespawn(playerid, Config_GetPlayerSessionToken(playerid));
    return 1;
}

// =============================================================================
//  7. ТАЙМЕРЫ КРОВОТЕЧЕНИЙ, БОЛИ И РЕСПАВНА (y_timers)
// =============================================================================

timer Medical_CkKickTimer[2000](playerid, expectedToken)
{
    if (!Config_ValidatePlayerToken(playerid, expectedToken))
    {
        return;
    }
    Kick(playerid);
}

timer Medical_HospitalRespawn[4000](playerid, expectedToken)
{
    if (!Config_ValidatePlayerToken(playerid, expectedToken))
    {
        return;
    }
    if (!Character_IsLoaded(playerid))
    {
        return;
    }
    if (GetPlayerState(playerid) != PLAYER_STATE_WASTED)
    {
        sDeathHandled[playerid] = false;
        return;
    }

    SpawnPlayer(playerid);
    defer Medical_HospitalRelocate(playerid, expectedToken);
}

timer Medical_HospitalRelocate[750](playerid, expectedToken)
{
    if (!Config_ValidatePlayerToken(playerid, expectedToken))
    {
        return;
    }
    if (!Character_IsLoaded(playerid) || GetPlayerState(playerid) == PLAYER_STATE_WASTED)
    {
        return;
    }

    Utils_SetPlayerPos(playerid, HOSPITAL_LS_X, HOSPITAL_LS_Y, HOSPITAL_LS_Z);
    SetPlayerFacingAngle(playerid, HOSPITAL_LS_A);
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerCameraPos(playerid, HOSPITAL_LS_X - 3.0, HOSPITAL_LS_Y - 3.0, HOSPITAL_LS_Z + 2.0);
    SetPlayerCameraLookAt(playerid, HOSPITAL_LS_X, HOSPITAL_LS_Y, HOSPITAL_LS_Z, CAMERA_CUT);
    SetPlayerHealth(playerid, 100.0);
    SetPlayerArmour(playerid, 0.0);
    SetCameraBehindPlayer(playerid);
    ClearAnimations(playerid, SYNC_ALL);
    Character_MarkDirty(playerid);

    SendClientMessage(playerid, COLOR_UI_INFO,
        "[Hospital]: You have been stabilized. Health is restored, the outer layer of inventory is lost.");
    Internal_NotifyHud(playerid);
}

task Medical_SecondTask[1000]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }

    foreach (new playerid : Player)
    {
        if (!Character_IsLoaded(playerid) || !sInjuries[playerid][E_INJ_LOADED])
        {
            continue;
        }

        new const PLAYER_STATE:playerState = GetPlayerState(playerid);
        if (playerState == PLAYER_STATE_NONE || playerState == PLAYER_STATE_WASTED ||
            playerState == PLAYER_STATE_SPECTATING)
        {
            continue;
        }

        new Float:hp = 100.0;
        GetPlayerHealth(playerid, hp);
        if (hp <= 0.0)
        {
            continue;
        }

        new Float:damage = 0.0;

        if (sInjuries[playerid][E_INJ_BLEEDING] == BLEEDING_VENOUS)
        {
            sBleedTick[playerid]++;
            if ((sBleedTick[playerid] % MED_VENOUS_INTERVAL_SEC) == 0)
            {
                damage += MED_VENOUS_DAMAGE;
            }
        }
        else if (sInjuries[playerid][E_INJ_BLEEDING] == BLEEDING_ARTERIAL)
        {
            sBleedTick[playerid]++;
            if ((sBleedTick[playerid] % MED_ARTERIAL_INTERVAL_SEC) == 0)
            {
                damage += MED_ARTERIAL_DAMAGE;
            }

            if (sInjuries[playerid][E_INJ_ARTERIAL_TIMER] > 0)
            {
                sInjuries[playerid][E_INJ_ARTERIAL_TIMER]--;

                if (sInjuries[playerid][E_INJ_ARTERIAL_TIMER] == MED_ARTERIAL_WARNING_SECONDS)
                {
                    SendClientMessage(playerid, COLOR_UI_ERROR,
                        "[Medicine]: 30 seconds left until death from arterial bleeding! Apply a tourniquet immediately!");
                }

                if (sInjuries[playerid][E_INJ_ARTERIAL_TIMER] <= 0)
                {
                    SendClientMessage(playerid, COLOR_UI_ERROR,
                        "[Medicine]: Arterial bleeding proved fatal. You bled to death.");
                    SetPlayerHealth(playerid, 0.0);
                    continue;
                }
            }
        }

        if (damage > 0.0)
        {
            new Float:newHp = hp - damage;
            if (newHp < 0.0)
            {
                newHp = 0.0;
            }
            SetPlayerHealth(playerid, newHp);
        }

        if (sInjuries[playerid][E_INJ_PAIN_SHOCK] && !sPainShockApplied[playerid])
        {
            sPainShockApplied[playerid] = true;
            SetPlayerDrunkLevel(playerid, 3500);
            SendClientMessage(playerid, COLOR_UI_WARNING,
                "[Medicine]: Painful shock. Hands are shaking, the image is floating. Use the morphine syringe.");
        }

        sInjurySaveTick[playerid]++;
        if ((sInjurySaveTick[playerid] % MED_INJURY_SAVE_INTERVAL_SEC) == 0)
        {
            Internal_SaveInjuries(playerid);
        }

        if ((sBleedTick[playerid] % 10) == 0)
        {
            Internal_NotifyHud(playerid);
        }
    }
}

// =============================================================================
//  8. БЛОКИРОВКА БЕГА И ПРЫЖКОВ ПРИ ПЕРЕЛОМЕ НОГ
// =============================================================================

timer Medical_LegFractureJumpBlock[250](playerid, expectedToken)
{
    if (!Config_ValidatePlayerToken(playerid, expectedToken))
    {
        return;
    }
    if (Character_IsLoaded(playerid))
    {
        TogglePlayerControllable(playerid, true);
    }
}

hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    #pragma unused oldkeys

    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }

    new const fractureFlags = sInjuries[playerid][E_INJ_FRACTURES];
    if ((fractureFlags & (_:FRACTURE_LEFT_LEG | _:FRACTURE_RIGHT_LEG)) == 0)
    {
        return 1;
    }

    if ((newkeys & KEY_SPRINT) && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
    {
        ApplyAnimation(playerid, "PED", "WALK_player", 4.1, false, true, true, false, 600, SYNC_ALL);
        Internal_NotifyFracture(playerid, "leg");
    }

    if ((newkeys & KEY_JUMP) && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
    {
        TogglePlayerControllable(playerid, false);
        defer Medical_LegFractureJumpBlock(playerid, Config_GetPlayerSessionToken(playerid));
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Medicine]: A broken leg prevents me from jumping. Wait for the surgeon's help.");
    }
    return 1;
}

// =============================================================================
//  9. КОМАНДЫ МЕДИЦИНСКОГО ОСМОТРА, ЛЕЧЕНИЯ И ДОБРОВОЛЬНОГО CK
// =============================================================================

static stock Internal_ParseTarget(playerid, const params[], &targetid)
{
    targetid = playerid;
    if (params[0] == EOS)
    {
        return 1;
    }

    new const parsedId = strval(params);
    if (parsedId < 0 || parsedId >= MAX_PLAYERS || !IsPlayerConnected(parsedId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Medicine]: The specified player was not found on the server.");
        return 0;
    }
    targetid = parsedId;
    return 1;
}

static stock bool:Internal_CheckMedicalCommandCooldown(playerid)
{
    new const nowTick = GetTickCount();
    if ((nowTick - sLastMedicalCommandTick[playerid]) < 400)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Medicine]: Not so fast. Wait a moment.");
        return false;
    }
    sLastMedicalCommandTick[playerid] = nowTick;
    return true;
}

CMD:triage(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Medicine]: Your character has not yet been loaded.");
        return 1;
    }
    if (!Internal_CheckMedicalCommandCooldown(playerid))
    {
        return 1;
    }

    new targetid = playerid;
    if (!Internal_ParseTarget(playerid, params, targetid))
    {
        return 1;
    }
    if (!Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Medicine]: The specified player's character has not yet been loaded.");
        return 1;
    }
    if (targetid != playerid && Utils_GetDistanceBetweenPlayers(playerid, targetid) > STORAGE_INTERACT_DISTANCE)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Medical]: The patient is too far away (maximum 3.5 meters).");
        return 1;
    }

    Medical_ShowTriageDialog(playerid, targetid);
    return 1;
}

CMD:treat(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Medicine]: Your character has not yet been loaded.");
        return 1;
    }
    if (!Internal_CheckMedicalCommandCooldown(playerid))
    {
        return 1;
    }

    new targetid = playerid;
    if (!Internal_ParseTarget(playerid, params, targetid))
    {
        return 1;
    }
    if (!Character_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Medicine]: The specified player's character has not yet been loaded.");
        return 1;
    }
    if (targetid != playerid && Utils_GetDistanceBetweenPlayers(playerid, targetid) > STORAGE_INTERACT_DISTANCE)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Medical]: The patient is too far away (maximum 3.5 meters).");
        return 1;
    }

    // Лечение другого человека требует базового навыка первой помощи
    // либо наличия профессиональной аптечки в Слое 1.
    if (targetid != playerid &&
        Skills_Get(playerid, SKILL_FIRST_AID) < 100 &&
        !Internal_HasItemInLayer1(playerid, ITEM_ID_FIRST_AID_KIT))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Medicine]: To treat other people, you need a First Aid skill of 100+ or a first aid kit.");
        return 1;
    }

    Medical_EnsureInjuriesLoaded(targetid);
    if (!sInjuries[targetid][E_INJ_LOADED])
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Medical]: The patient's medical record is still loading.");
        return 1;
    }

    new Float:targetHp = 100.0;
    GetPlayerHealth(targetid, targetHp);
    if (targetHp <= 0.0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Medical]: The patient is dead. Conventional medications will no longer help him.");
        return 1;
    }

    new bool:treatmentApplied = false;
    new bool:surgeryApplied = false;
    new const doctorCharId = Character_GetId(playerid);

    // 1. Артериальное кровотечение: сначала жгут, затем хирургическая стабилизация
    if (sInjuries[targetid][E_INJ_BLEEDING] == BLEEDING_ARTERIAL)
    {
        if (!sInjuries[targetid][E_INJ_TOURNIQUET])
        {
            if (Internal_ConsumeItem(playerid, ITEM_ID_TOURNIQUET))
            {
                Internal_StopBleeding(targetid, true);
                treatmentApplied = true;
                SendClientMessage(playerid, COLOR_UI_SUCCESS,
                    "[Medicine]: You have applied a tourniquet. The bleeding has stopped.");
                if (targetid != playerid)
                {
                    SendClientMessage(targetid, COLOR_UI_INFO,
                        "[Medicine]: A tourniquet has been applied to you. Surgical stabilization is required.");
                }
            }
            else
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "[Medicine]: Arterial bleeding requires a tourniquet!");
            }
        }

        if (sInjuries[targetid][E_INJ_TOURNIQUET])
        {
            if (Skills_Get(playerid, SKILL_SURGERY) < MED_SURGERY_SKILL_REQUIRED)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "[Medicine]: Surgical stabilization requires a Field Surgery skill of at least 300.");
            }
            else if (Internal_ConsumeItem(playerid, ITEM_ID_SURGICAL_KIT))
            {
                Internal_StopBleeding(targetid, false);
                sInjuries[targetid][E_INJ_FRACTURES] = 0;
                Internal_SaveInjuries(targetid);
                Internal_HealPlayer(targetid, 50.0);
                treatmentApplied = true;
                surgeryApplied = true;
                Skills_Add(playerid, SKILL_SURGERY, 8);
                SendClientMessage(playerid, COLOR_UI_SUCCESS,
                    "[Medical]: You stabilized a patient with a surgical kit. Vascular bleeding has completely stopped.");
                if (targetid != playerid)
                {
                    SendClientMessage(targetid, COLOR_UI_SUCCESS,
                        "[Medicine]: The surgeon has stabilized your condition and restored your health.");
                }
            }
            else
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "[Medical]: A field surgical kit is required for stabilization.");
            }
        }
    }
    // 2. Венозное кровотечение: бинт или аптечка
    else if (sInjuries[targetid][E_INJ_BLEEDING] == BLEEDING_VENOUS)
    {
        if (Internal_ConsumeItem(playerid, ITEM_ID_BANDAGE))
        {
            Internal_StopBleeding(targetid, false);
            Internal_HealPlayer(targetid, 15.0);
            treatmentApplied = true;
            SendClientMessage(playerid, COLOR_UI_SUCCESS,
                "[Medicine]: You bandaged a venous bleed with a sterile bandage.");
        }
        else if (Internal_ConsumeItem(playerid, ITEM_ID_FIRST_AID_KIT))
        {
            Internal_StopBleeding(targetid, false);
            Internal_HealPlayer(targetid, 45.0);
            treatmentApplied = true;
            SendClientMessage(playerid, COLOR_UI_SUCCESS,
                "[Medicine]: You stopped the bleeding and treated the wound with a first aid kit.");
        }
        else
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "[Medicine]: To stop venous bleeding, you need a bandage or first aid kit.");
        }
    }

    // 3. Болевой шок: шприц с морфином
    if (sInjuries[targetid][E_INJ_PAIN_SHOCK])
    {
        if (Internal_ConsumeItem(playerid, ITEM_ID_MORPHINE_SYRINGE))
        {
            sInjuries[targetid][E_INJ_PAIN_SHOCK] = false;
            sPainShockApplied[targetid] = false;
            SetPlayerDrunkLevel(targetid, 0);
            Internal_SaveInjuries(targetid);
            treatmentApplied = true;
            SendClientMessage(playerid, COLOR_UI_SUCCESS,
                "[Medicine]: You relieved a patient's pain shock with a syringe tube of morphine.");
        }
    }

    // 4. Переломы: хирургический набор и навык SURGERY >= 300
    if (sInjuries[targetid][E_INJ_FRACTURES] != 0 && !surgeryApplied)
    {
        if (Skills_Get(playerid, SKILL_SURGERY) < MED_SURGERY_SKILL_REQUIRED)
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "[Medicine]: Fractures can only be treated by a surgeon with a Field Surgery skill of 300+.");
        }
        else if (Internal_ConsumeItem(playerid, ITEM_ID_SURGICAL_KIT))
        {
            sInjuries[targetid][E_INJ_FRACTURES] = 0;
            Internal_SaveInjuries(targetid);
            Internal_HealPlayer(targetid, 30.0);
            treatmentApplied = true;
            surgeryApplied = true;
            Skills_Add(playerid, SKILL_SURGERY, 8);
            SendClientMessage(playerid, COLOR_UI_SUCCESS,
                "[Medicine]: You performed surgical fixation of fractures. The patient can move normally.");
        }
        else
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "[Medical]: A field surgical kit is required to fix fractures.");
        }
    }

    if (!treatmentApplied)
    {
        if (sInjuries[targetid][E_INJ_BLEEDING] == BLEEDING_NONE &&
            sInjuries[targetid][E_INJ_FRACTURES] == 0 &&
            !sInjuries[targetid][E_INJ_PAIN_SHOCK])
        {
            SendClientMessage(playerid, COLOR_UI_INFO,
                "[Medical]: The patient has no injuries requiring immediate treatment.");
        }
        else
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "[Medicine]: There are no suitable medications in your inventory to treat these injuries.");
        }
        return 1;
    }

    Skills_Add(playerid, SKILL_FIRST_AID, 3);

    new details[255];
    new targetName[MAX_PLAYER_NAME + 1];
    Character_GetRpName(targetid, targetName, sizeof(targetName));
    format(details, sizeof(details),
        "Medical care for patient %s (ID %d). Surgery: %s.",
        targetName, Character_GetId(targetid), surgeryApplied ? ("Yes") : ("No"));
    Audit_Log(doctorCharId, "MEDICAL_TREAT", "CHARACTER", "CHARACTER", 0, 0, details);

    Internal_NotifyHud(targetid);
    return 1;
}

CMD:ck(playerid, params[])
{
    #pragma unused params

    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Permanent Death]: Your character has not yet been loaded.");
        return 1;
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_MEDICAL_CK_CONFIRM,
        DIALOG_STYLE_INPUT,
        "{FF4444}Permanent character death (CK)",
        "ATTENTION! This action is irreversible.\n\n" \
        "The character will be deleted permanently: bank accounts and licenses will be cancelled,\n" \
        "and it will no longer be possible to log in with this character.\n\n" \
        "To confirm, enter the word: CONFIRM",
        "Die forever",
        "Cancel");
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused listitem

    switch (dialogid)
    {
        case DIALOG_MEDICAL_TRIAGE:
        {
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_MEDICAL_CK_CONFIRM:
        {
            if (!response)
            {
                SendClientMessage(playerid, COLOR_UI_INFO,
                    "[Permanent Death]: You have refused the CK procedure. The character is saved.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            if (strcmp(inputtext, "CONFIRM", true) != 0)
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "[Permanent Death]: Incorrect confirmation. Enter the word CONFIRM in capital letters.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            Medical_ApplyCharacterKill(playerid, 0, "Voluntary permanent death by command /ck");
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_0;
}

// =============================================================================
//  10. ИНИЦИАЛИЗАЦИЯ И САМОПРОВЕРКА (hook OnGameModeInit)
// =============================================================================

hook OnGameModeInit()
{
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        Internal_ResetRuntime(playerid);
    }

    printf("%s [Systems/Medical] Zone Trauma, PK/CK and Bleeding Module initialized (Arterial Bleeding Threshold: %d sec).",
        SERVER_LOG_PREFIX, MED_ARTERIAL_DEATH_SECONDS);
    return 1;
}

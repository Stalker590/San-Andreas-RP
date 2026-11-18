/*
 * =============================================================================
 *  SAN ANDREAS RP ó “ÂÎÂÙÓÌËˇ, SIM-Í‡Ú˚, ‡ˆËË Ë ‡‰ËÓÔÂÂı‚‡Ú
 *  ‘‡ÈÎ:      gamemodes/modules/systems/mod_telecom.pwn
 *  œÛÌÍÚ:     ROADMAP [8.4] ó “ÂÎÂÙÓÌËˇ, Burner-ÚÛ·ÍË Ë ‡‰ËÓÔÂÂı‚‡Ú
 *   Ó‰ËÓ‚Í‡: Windows-1251 (CP1251) ·ÂÁ BOM
 * =============================================================================
 */

#if defined _mod_telecom_included
    #endinput
#endif
#define _mod_telecom_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1.  ŒÕ—“¿Õ“€, ƒ»¿ÀŒ√» » “≈À≈ ŒÃÃ”Õ» ¿÷»ŒÕÕ€≈ “Œ◊ »
// =============================================================================

#define DIALOG_PHONE_MAIN                       (1900)
#define DIALOG_PHONE_CALL_NUMBER                (1901)
#define DIALOG_PHONE_SMS_NUMBER                 (1902)
#define DIALOG_PHONE_SMS_TEXT                   (1903)
#define DIALOG_SIM_BUY                          (1904)
#define DIALOG_PHONE_INFO                       (1905)

#define MAX_TELECOM_SIMS                        (1024)
#define PHONE_NUMBER_LEN                        (13)
#define SIM_SSN_LEN                             (13)
#define TELECOM_COMMAND_COOLDOWN_MS             (500)
#define TELECOM_SHOP_RADIUS                     (8.0)
#define TELECOM_SHOP_COUNT                      (3)
#define TELECOM_SMS_TEXT_LEN                    (128)
#define TELECOM_LEGAL_SIM_PRICE_USD             (100)
#define TELECOM_BURNER_SIM_PRICE_USD            (250)
#define TELECOM_RADIO_MIN_FREQ_KHZ              (100000)
#define TELECOM_RADIO_MAX_FREQ_KHZ              (999900)
#define TELECOM_WIRETAP_MIN_RANK                (2)

#define ITEM_ID_MOBILE_PHONE                    (50)
#define ITEM_ID_BURNER_PHONE                    (51)
#define ITEM_ID_SIM_CARD                        (52)
#define ITEM_ID_WALKIE_TALKIE                   (53)

// =============================================================================
//  2. œ≈–≈◊»—À≈Õ»ﬂ, œ”À€ SIM » —Œ—“ŒﬂÕ»≈ (static stock)
// =============================================================================

enum E_SIM_DATA
{
    bool:E_SIM_VALID,
    E_SIM_PHONE[PHONE_NUMBER_LEN],
    E_SIM_ITEM_DB_ID,
    E_SIM_REGISTERED_SSN[SIM_SSN_LEN],
    bool:E_SIM_IS_WIRETAPPED,
    E_SIM_WIRETAP_ORG_ID
};

enum E_PHONE_MENU_ACTION
{
    PHONE_MENU_NONE = 0,
    PHONE_MENU_CALL,
    PHONE_MENU_SMS,
    PHONE_MENU_INSERT_SIM,
    PHONE_MENU_EJECT_SIM,
    PHONE_MENU_INFO
};

static stock sSims[MAX_TELECOM_SIMS][E_SIM_DATA];
new Iterator:SimIter<MAX_TELECOM_SIMS>;

static stock E_PHONE_MENU_ACTION:sPhoneMenuAction[MAX_PLAYERS][8];
static stock sPhoneMenuActionCount[MAX_PLAYERS];
static stock sPhonePendingNumber[MAX_PLAYERS][PHONE_NUMBER_LEN];
static stock sPhoneLastCommandTick[MAX_PLAYERS];
static stock STREAMER_TAG_3D_TEXT_LABEL:sTelecomShopLabel[TELECOM_SHOP_COUNT];

static stock const Float:sTelecomShops[TELECOM_SHOP_COUNT][3] =
{
    { 1352.3, -1759.2, 13.5 },
    { -1981.5, 137.3, 27.7 },
    { 2134.2, 1990.1, 10.8 }
};

// =============================================================================
//  3. ¬Õ”“–≈ÕÕ»≈ ¬—œŒÃŒ√¿“≈À‹Õ€≈ ‘”Õ ÷»» (static stock)
// =============================================================================

static stock Internal_GeneratePhoneNumber(output[], len = sizeof(output))
{
    new candidate[PHONE_NUMBER_LEN];
    for (new attempt = 0; attempt < 100; attempt++)
    {
        format(candidate, sizeof(candidate), "%03d-%03d-%04d",
            200 + random(700), random(1000), random(10000));
        if (Internal_FindSimByPhone(candidate) < 0)
        {
            format(output, len, "%s", candidate);
            return 1;
        }
    }
    format(output, len, "%03d-%03d-%04d",
        200 + random(700), random(1000), random(10000));
    return 1;
}

static stock Internal_ResetSimSlot(slot)
{
    sSims[slot][E_SIM_VALID] = false;
    sSims[slot][E_SIM_PHONE][0] = EOS;
    sSims[slot][E_SIM_ITEM_DB_ID] = 0;
    sSims[slot][E_SIM_REGISTERED_SSN][0] = EOS;
    sSims[slot][E_SIM_IS_WIRETAPPED] = false;
    sSims[slot][E_SIM_WIRETAP_ORG_ID] = 0;
    return 1;
}

static stock Internal_FindSimByPhone(const phone[])
{
    foreach (new slot : SimIter)
    {
        if (sSims[slot][E_SIM_VALID] && !strcmp(sSims[slot][E_SIM_PHONE], phone, false))
        {
            return slot;
        }
    }
    return -1;
}

static stock Internal_FindSimByItemDbId(item_db_id)
{
    if (item_db_id <= 0)
    {
        return -1;
    }
    foreach (new slot : SimIter)
    {
        if (sSims[slot][E_SIM_VALID] && sSims[slot][E_SIM_ITEM_DB_ID] == item_db_id)
        {
            return slot;
        }
    }
    return -1;
}

static stock Internal_AddSim(const phone[], item_db_id, const ssn[], bool:wiretapped, wiretap_org_id)
{
    if (Internal_FindSimByPhone(phone) >= 0)
    {
        return -1;
    }

    new const slot = Iter_Free(SimIter);
    if (slot == INVALID_ITERATOR_SLOT)
    {
        return -1;
    }

    Iter_Add(SimIter, slot);
    Internal_ResetSimSlot(slot);
    sSims[slot][E_SIM_VALID] = true;
    format(sSims[slot][E_SIM_PHONE], PHONE_NUMBER_LEN, "%s", phone);
    sSims[slot][E_SIM_ITEM_DB_ID] = item_db_id;
    format(sSims[slot][E_SIM_REGISTERED_SSN], SIM_SSN_LEN, "%s", ssn);
    sSims[slot][E_SIM_IS_WIRETAPPED] = wiretapped;
    sSims[slot][E_SIM_WIRETAP_ORG_ID] = wiretap_org_id;
    return slot;
}

static stock bool:Internal_PlayerNearTelecomShop(playerid)
{
    for (new i = 0; i < TELECOM_SHOP_COUNT; i++)
    {
        if (Utils_IsPlayerNearPoint(playerid, TELECOM_SHOP_RADIUS,
            sTelecomShops[i][0], sTelecomShops[i][1], sTelecomShops[i][2]))
        {
            return true;
        }
    }
    return false;
}

static stock bool:Internal_CommandAllowed(playerid)
{
    new const nowTick = GetTickCount();
    if ((nowTick - sPhoneLastCommandTick[playerid]) < TELECOM_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "Not so fast: Wait for the previous operation to complete.");
        return false;
    }
    sPhoneLastCommandTick[playerid] = nowTick;
    return true;
}

static stock Internal_GetPhoneItem(playerid, &phone_item_slot, &phone_storage_slot)
{
    phone_item_slot = INVALID_STORAGE_ITEM_SLOT;
    phone_storage_slot = INVALID_STORAGE_SLOT;

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
            new const defId = Storage_GetItemDefId(itemSlot);
            if (defId == ITEM_ID_MOBILE_PHONE || defId == ITEM_ID_BURNER_PHONE)
            {
                phone_item_slot = itemSlot;
                phone_storage_slot = slots[s];
                return 1;
            }
            itemSlot = Storage_GetNextItemSlot(itemSlot);
        }
    }
    return 0;
}

static stock Internal_GetSimItemByNumber(playerid, const phone[], &sim_item_slot, &sim_storage_slot)
{
    sim_item_slot = INVALID_STORAGE_ITEM_SLOT;
    sim_storage_slot = INVALID_STORAGE_SLOT;

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
            if (Storage_GetItemDefId(itemSlot) == ITEM_ID_SIM_CARD)
            {
                new itemPhone[PHONE_NUMBER_LEN];
                Storage_GetItemMetaStr(itemSlot, itemPhone, sizeof(itemPhone));
                if (!strcmp(itemPhone, phone, false))
                {
                    sim_item_slot = itemSlot;
                    sim_storage_slot = slots[s];
                    return 1;
                }
            }
            itemSlot = Storage_GetNextItemSlot(itemSlot);
        }
    }
    return 0;
}

static stock Internal_GetFirstFreeSimItem(playerid, &sim_item_slot, &sim_storage_slot)
{
    sim_item_slot = INVALID_STORAGE_ITEM_SLOT;
    sim_storage_slot = INVALID_STORAGE_SLOT;

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
            if (Storage_GetItemDefId(itemSlot) == ITEM_ID_SIM_CARD)
            {
                new itemPhone[PHONE_NUMBER_LEN];
                Storage_GetItemMetaStr(itemSlot, itemPhone, sizeof(itemPhone));
                if (itemPhone[0] != EOS)
                {
                    sim_item_slot = itemSlot;
                    sim_storage_slot = slots[s];
                    return 1;
                }
            }
            itemSlot = Storage_GetNextItemSlot(itemSlot);
        }
    }
    return 0;
}

static stock bool:Internal_ActivePhone(
    playerid,
    phone_out[],
    phone_len,
    &sim_item_slot,
    &phone_item_slot,
    &bool:is_legal,
    ssn_out[],
    ssn_len)
{
    phone_out[0] = EOS;
    ssn_out[0] = EOS;
    is_legal = false;
    sim_item_slot = INVALID_STORAGE_ITEM_SLOT;
    phone_item_slot = INVALID_STORAGE_ITEM_SLOT;

    new phoneStorage = INVALID_STORAGE_SLOT;
    if (!Internal_GetPhoneItem(playerid, phone_item_slot, phoneStorage))
    {
        return false;
    }

    new phoneNumber[PHONE_NUMBER_LEN];
    Storage_GetItemMetaStr(phone_item_slot, phoneNumber, sizeof(phoneNumber));
    if (phoneNumber[0] == EOS)
    {
        return false;
    }

    new simStorage = INVALID_STORAGE_SLOT;
    if (!Internal_GetSimItemByNumber(playerid, phoneNumber, sim_item_slot, simStorage))
    {
        return false;
    }

    is_legal = (Storage_GetItemMetaInt1(sim_item_slot) == 1);

    new simSlot = Internal_FindSimByPhone(phoneNumber);
    if (simSlot >= 0)
    {
        format(ssn_out, ssn_len, "%s", sSims[simSlot][E_SIM_REGISTERED_SSN]);
        is_legal = (sSims[simSlot][E_SIM_REGISTERED_SSN][0] != EOS);
    }

    format(phone_out, phone_len, "%s", phoneNumber);
    return true;
}

static stock Internal_GetPlayerPhoneNumber(playerid, output[], len = sizeof(output))
{
    output[0] = EOS;
    new phoneItem = INVALID_STORAGE_ITEM_SLOT;
    new phoneStorage = INVALID_STORAGE_SLOT;
    if (!Internal_GetPhoneItem(playerid, phoneItem, phoneStorage))
    {
        return 0;
    }
    Storage_GetItemMetaStr(phoneItem, output, len);
    return 1;
}

static stock Internal_FindPlayerByPhone(const phone[], &char_db_id)
{
    char_db_id = 0;
    foreach (new playerid : Player)
    {
        if (!Character_IsLoaded(playerid))
        {
            continue;
        }

        new number[PHONE_NUMBER_LEN], ssn[SIM_SSN_LEN];
        new simItem = INVALID_STORAGE_ITEM_SLOT;
        new phoneItem = INVALID_STORAGE_ITEM_SLOT;
        new bool:isLegal = false;
        if (!Internal_ActivePhone(playerid, number, sizeof(number),
            simItem, phoneItem, isLegal, ssn, sizeof(ssn)))
        {
            continue;
        }
        if (!strcmp(number, phone, false))
        {
            char_db_id = Character_GetId(playerid);
            return playerid;
        }
    }
    return INVALID_PLAYER_ID;
}

static stock Internal_FormatCallerIdentity(playerid, const phone[], bool:isLegal, const ssn[], output[], len = sizeof(output))
{
    new name[MAX_PLAYER_NAME + 1];
    Character_GetRpName(playerid, name, sizeof(name));

    if (isLegal && ssn[0] != EOS)
    {
        format(output, len, "%s, phone %s, SSN %s", name, phone, ssn);
    }
    else
    {
        format(output, len, "anonymous caller, phone %s", phone);
    }
    return 1;
}

static stock Internal_NotifyWiretap(org_id, const message[])
{
    if (org_id <= 0)
    {
        return 0;
    }
    foreach (new playerid : Player)
    {
        if (Character_IsLoaded(playerid) && Character_GetOrgId(playerid) == org_id)
        {
            SendClientMessage(playerid, COLOR_UI_WARNING, message);
        }
    }
    return 1;
}

static stock Internal_LogCall(
    actor_char_id,
    const action_type[],
    const caller_phone[],
    const target_phone[],
    bool:caller_legal,
    const caller_ssn[],
    const details[])
{
    new logDetails[220];
    if (caller_legal && caller_ssn[0] != EOS)
    {
        format(logDetails, sizeof(logDetails),
            "Subscriber %s (SSN %s) -> %s. %s",
            caller_phone, caller_ssn, target_phone, details);
    }
    else
    {
        format(logDetails, sizeof(logDetails),
            "Anonymous subscriber %s -> %s. SSN=ANONYMOUS. %s",
            caller_phone, target_phone, details);
    }
    Audit_Log(actor_char_id, action_type, caller_phone, target_phone, 0, 0, logDetails);
    return 1;
}

static stock Internal_PlaceCall(playerid, const number[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    new callerPhone[PHONE_NUMBER_LEN], callerSsn[SIM_SSN_LEN];
    new simItem = INVALID_STORAGE_ITEM_SLOT, phoneItem = INVALID_STORAGE_ITEM_SLOT;
    new bool:callerLegal = false;
    if (!Internal_ActivePhone(playerid, callerPhone, sizeof(callerPhone),
        simItem, phoneItem, callerLegal, callerSsn, sizeof(callerSsn)))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "There is no active SIM card. Insert SIM into your phone via /phone.");
        return 0;
    }
    if (strlen(number) != 12)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The phone number must contain 12 characters in the format 555-123-4567.");
        return 0;
    }
    if (Internal_FindSimByPhone(number) < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The subscriber with this number was not found on the network.");
        return 0;
    }

    new targetCharId = 0;
    new const targetPlayer = Internal_FindPlayerByPhone(number, targetCharId);
    if (targetPlayer == INVALID_PLAYER_ID)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The subscriber's device is turned off or is out of network coverage.");
        return 0;
    }
    if (targetPlayer == playerid)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "You can't call yourself.");
        return 0;
    }

    new callerIdentity[160];
    Internal_FormatCallerIdentity(playerid, callerPhone, callerLegal, callerSsn, callerIdentity, sizeof(callerIdentity));

    new msg[256];
    format(msg, sizeof(msg), "[Phone] Calling you: %s.", callerIdentity);
    SendClientMessage(targetPlayer, COLOR_UI_INFO, msg);
    format(msg, sizeof(msg), "[Phone] You have dialed number %s. The subscriber answers.", number);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    Internal_LogCall(Character_GetId(playerid), "CALL", callerPhone, number,
        callerLegal, callerSsn, "Phone call");

    new callerSim = Internal_FindSimByPhone(callerPhone);
    new targetSim = Internal_FindSimByPhone(number);
    if (callerSim >= 0 && sSims[callerSim][E_SIM_IS_WIRETAPPED])
    {
        new tapMsg[256];
        format(tapMsg, sizeof(tapMsg), "[Whisper] %s -> %s.", callerIdentity, number);
        Internal_NotifyWiretap(sSims[callerSim][E_SIM_WIRETAP_ORG_ID], tapMsg);
    }
    if (targetSim >= 0 && sSims[targetSim][E_SIM_IS_WIRETAPPED])
    {
        new tapMsg[256];
        format(tapMsg, sizeof(tapMsg), "[Whisper] Incoming to %s from %s.", number, callerIdentity);
        Internal_NotifyWiretap(sSims[targetSim][E_SIM_WIRETAP_ORG_ID], tapMsg);
    }
    return 1;
}

static stock Internal_SendSms(playerid, const number[], const text[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }
    if (text[0] == EOS)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The message text cannot be empty.");
        return 0;
    }

    new callerPhone[PHONE_NUMBER_LEN], callerSsn[SIM_SSN_LEN];
    new simItem = INVALID_STORAGE_ITEM_SLOT, phoneItem = INVALID_STORAGE_ITEM_SLOT;
    new bool:callerLegal = false;
    if (!Internal_ActivePhone(playerid, callerPhone, sizeof(callerPhone),
        simItem, phoneItem, callerLegal, callerSsn, sizeof(callerSsn)))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "There is no active SIM card. Insert SIM into your phone via /phone.");
        return 0;
    }

    new targetCharId = 0;
    new const targetPlayer = Internal_FindPlayerByPhone(number, targetCharId);
    if (targetPlayer == INVALID_PLAYER_ID)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The subscriber is unavailable.");
        return 0;
    }
    if (targetPlayer == playerid)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "You cannot send SMS to yourself.");
        return 0;
    }

    new callerIdentity[160];
    Internal_FormatCallerIdentity(playerid, callerPhone, callerLegal, callerSsn, callerIdentity, sizeof(callerIdentity));

    new msg[256];
    format(msg, sizeof(msg), "[SMS] %s: %s", callerIdentity, text);
    SendClientMessage(targetPlayer, COLOR_UI_INFO, msg);
    format(msg, sizeof(msg), "[SMS] Message sent to %s.", number);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    Internal_LogCall(Character_GetId(playerid), "SMS", callerPhone, number,
        callerLegal, callerSsn, text);

    new callerSim = Internal_FindSimByPhone(callerPhone);
    new targetSim = Internal_FindSimByPhone(number);
    if (callerSim >= 0 && sSims[callerSim][E_SIM_IS_WIRETAPPED])
    {
        new tapMsg[256];
        format(tapMsg, sizeof(tapMsg), "[SMS Listening] %s -> %s: %s", callerIdentity, number, text);
        Internal_NotifyWiretap(sSims[callerSim][E_SIM_WIRETAP_ORG_ID], tapMsg);
    }
    if (targetSim >= 0 && sSims[targetSim][E_SIM_IS_WIRETAPPED])
    {
        new tapMsg[256];
        format(tapMsg, sizeof(tapMsg), "[SMS Wiretapping] Incoming to %s from %s: %s", number, callerIdentity, text);
        Internal_NotifyWiretap(sSims[targetSim][E_SIM_WIRETAP_ORG_ID], tapMsg);
    }
    return 1;
}

static stock Internal_InsertSim(playerid)
{
    new phoneItem = INVALID_STORAGE_ITEM_SLOT;
    new phoneStorage = INVALID_STORAGE_SLOT;
    if (!Internal_GetPhoneItem(playerid, phoneItem, phoneStorage))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "You don't have a mobile phone.");
        return 0;
    }

    new currentNumber[PHONE_NUMBER_LEN];
    Storage_GetItemMetaStr(phoneItem, currentNumber, sizeof(currentNumber));
    if (currentNumber[0] != EOS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "The phone already has a SIM card installed.");
        return 0;
    }

    new simItem = INVALID_STORAGE_ITEM_SLOT;
    new simStorage = INVALID_STORAGE_SLOT;
    if (!Internal_GetFirstFreeSimItem(playerid, simItem, simStorage))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "There is no SIM card in inventory.");
        return 0;
    }

    new simNumber[PHONE_NUMBER_LEN];
    Storage_GetItemMetaStr(simItem, simNumber, sizeof(simNumber));
    Storage_SetItemMetaStr(phoneItem, simNumber);
    Storage_SetItemMetaInt1(phoneItem, Storage_GetItemDbId(simItem));
    Storage_SetItemMetaInt2(phoneItem, 0);

    new msg[192];
    format(msg, sizeof(msg), "SIM card %s is installed in the phone.", simNumber);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    return 1;
}

static stock Internal_EjectSim(playerid)
{
    new phoneItem = INVALID_STORAGE_ITEM_SLOT;
    new phoneStorage = INVALID_STORAGE_SLOT;
    if (!Internal_GetPhoneItem(playerid, phoneItem, phoneStorage))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "You don't have a mobile phone.");
        return 0;
    }

    new currentNumber[PHONE_NUMBER_LEN];
    Storage_GetItemMetaStr(phoneItem, currentNumber, sizeof(currentNumber));
    if (currentNumber[0] == EOS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "The phone does not have a SIM card.");
        return 0;
    }

    Storage_SetItemMetaStr(phoneItem, "");
    Storage_SetItemMetaInt1(phoneItem, 0);
    Storage_SetItemMetaInt2(phoneItem, 0);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, "The SIM card has been removed from the phone.");
    return 1;
}

static stock Internal_ShowPhoneMenu(playerid)
{
    new phoneItem = INVALID_STORAGE_ITEM_SLOT;
    new phoneStorage = INVALID_STORAGE_SLOT;
    if (!Internal_GetPhoneItem(playerid, phoneItem, phoneStorage))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "You don't have a mobile phone.");
        return 0;
    }

    new phoneNumber[PHONE_NUMBER_LEN];
    Storage_GetItemMetaStr(phoneItem, phoneNumber, sizeof(phoneNumber));

    new count = 0;
    new body[512];
    body[0] = '\0';
    strcat(body, "Call subscriber\n", sizeof(body));
    sPhoneMenuAction[playerid][count++] = PHONE_MENU_CALL;
    strcat(body, "Send SMS\n", sizeof(body));
    sPhoneMenuAction[playerid][count++] = PHONE_MENU_SMS;
    if (phoneNumber[0] == EOS)
    {
        strcat(body, "Insert SIM card\n", sizeof(body));
        sPhoneMenuAction[playerid][count++] = PHONE_MENU_INSERT_SIM;
    }
    else
    {
        strcat(body, "Remove SIM card\n", sizeof(body));
        sPhoneMenuAction[playerid][count++] = PHONE_MENU_EJECT_SIM;
        strcat(body, "Subscriber information\n", sizeof(body));
        sPhoneMenuAction[playerid][count++] = PHONE_MENU_INFO;
    }
    sPhoneMenuActionCount[playerid] = count;

    new caption[160];
    if (phoneNumber[0] == EOS)
    {
        format(caption, sizeof(caption), "{FFC800}Phone {FFFFFF}| SIM card not installed");
    }
    else
    {
        format(caption, sizeof(caption), "{FFC800}Phone {FFFFFF}| Number: %s", phoneNumber);
    }

    ShowPlayerDialog(playerid, DIALOG_PHONE_MAIN, DIALOG_STYLE_LIST, caption, body,
        "Select", "Close");
    return 1;
}

static stock Internal_ShowPhoneInfo(playerid)
{
    new phoneNumber[PHONE_NUMBER_LEN], ssn[SIM_SSN_LEN];
    new simItem = INVALID_STORAGE_ITEM_SLOT, phoneItem = INVALID_STORAGE_ITEM_SLOT;
    new bool:isLegal = false;
    if (!Internal_ActivePhone(playerid, phoneNumber, sizeof(phoneNumber),
        simItem, phoneItem, isLegal, ssn, sizeof(ssn)))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "There is no active SIM card.");
        return 0;
    }

    new body[384];
    format(body, sizeof(body),
        "{FFC800}Number:{FFFFFF} %s\n" \
        "{FFC800}SIM type:{FFFFFF} %s\n" \
        "{FFC800}Registration:{FFFFFF} %s\n" \
        "{FFC800}Subscriber:{FFFFFF} %s",
        phoneNumber,
        isLegal ? ("Legal, linked to SSN") : ("Disposable anonymous SIM card"),
        isLegal ? (ssn[0] != EOS ? ssn : "no data available") : ("anonymously"),
        (isLegal ? ("disclosed in FBI billing") : ("completely anonymous")));
    ShowPlayerDialog(playerid, DIALOG_PHONE_INFO, DIALOG_STYLE_MSGBOX,
        "{FFC800}Subscriber information", body, "Understood", "Close");
    return 1;
}

static stock Internal_BuySimDialog(playerid)
{
    if (!Internal_PlayerNearTelecomShop(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "You can buy a SIM card at a mobile phone store.");
        return 0;
    }

    new body[384];
    format(body, sizeof(body),
        "Legal SIM card - %d USD\n" \
        "Linked to your SSN. Calls are visible in FBI billing.\n\n" \
        "Disposable anonymous SIM card - %d USD\n" \
        "No registration required. Completely anonymous and can be thrown away after use.",
        TELECOM_LEGAL_SIM_PRICE_USD,
        TELECOM_BURNER_SIM_PRICE_USD);
    ShowPlayerDialog(playerid, DIALOG_SIM_BUY, DIALOG_STYLE_LIST,
        "{FFC800}Cellular communication salon", body, "Buy", "Cancel");
    return 1;
}

static stock Internal_PurchaseSim(playerid, bool:legal)
{
    if (!Internal_PlayerNearTelecomShop(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "You have walked away from the cell phone store.");
        return 0;
    }

    new ssn[SIM_SSN_LEN];
    if (legal)
    {
        if (Character_GetCitizenship(playerid) != CITIZENSHIP_CITIZEN)
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "A legal SIM card is issued only to US citizens with an SSN.");
            return 0;
        }
        Character_GetSSN(playerid, ssn, sizeof(ssn));
        if (ssn[0] == EOS)
        {
            SendClientMessage(playerid, COLOR_UI_ERROR, "Your SSN could not be determined.");
            return 0;
        }
    }
    else
    {
        ssn[0] = EOS;
    }

    new const price = legal ? TELECOM_LEGAL_SIM_PRICE_USD : TELECOM_BURNER_SIM_PRICE_USD;
    if (Character_GetPhysicalCashUsd(playerid) < price)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "There is not enough cash to purchase a SIM card.");
        return 0;
    }
    if (!Character_RemovePhysicalCashUsd(playerid, price))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to pay for SIM card.");
        return 0;
    }

    new phone[PHONE_NUMBER_LEN];
    Internal_GeneratePhoneNumber(phone, sizeof(phone));

    new layer1 = Character_GetLayer1Slot(playerid);
    new layer2 = Character_GetLayer2Slot(playerid);
    new targetStorage = Storage_IsValidSlot(layer1) ? layer1 : layer2;
    if (!Storage_IsValidSlot(targetStorage))
    {
        Character_AddPhysicalCashUsd(playerid, price);
        SendClientMessage(playerid, COLOR_UI_ERROR, "There is no room for a SIM card in the inventory.");
        return 0;
    }

    new simMeta[PHONE_NUMBER_LEN];
    format(simMeta, sizeof(simMeta), "%s", phone);
    new outItem = INVALID_STORAGE_ITEM_SLOT;
    new E_STORAGE_RESULT:result = Storage_AddItem(
        targetStorage,
        ITEM_ID_SIM_CARD,
        1,
        0,
        100.0,
        legal ? 1 : 0,
        0,
        simMeta,
        outItem);

    if (result != STORAGE_RES_OK && Storage_IsValidSlot(layer2) && targetStorage != layer2)
    {
        result = Storage_AddItem(
            layer2,
            ITEM_ID_SIM_CARD,
            1,
            0,
            100.0,
            legal ? 1 : 0,
            0,
            simMeta,
            outItem);
    }
    if (result != STORAGE_RES_OK)
    {
        Character_AddPhysicalCashUsd(playerid, price);
        SendClientMessage(playerid, COLOR_UI_ERROR, "There is no room for a SIM card in the inventory.");
        return 0;
    }

    new const itemDbId = Storage_GetItemDbId(outItem);
    Internal_AddSim(phone, itemDbId, ssn, false, 0);

    if (DB_IsConnected())
    {
        new query[384];
        if (!legal)
        {
            mysql_format(gMySQL, query, sizeof(query),
                "INSERT INTO `telecom_sims` (`phone_number`, `sim_item_id`, `registered_ssn`, `is_wiretapped`, `wiretap_org_id`) VALUES ('%e', %d, NULL, 0, NULL);",
                phone, itemDbId);
        }
        else
        {
            mysql_format(gMySQL, query, sizeof(query),
                "INSERT INTO `telecom_sims` (`phone_number`, `sim_item_id`, `registered_ssn`, `is_wiretapped`, `wiretap_org_id`) VALUES ('%e', %d, '%e', 0, NULL);",
                phone, itemDbId, ssn);
        }
        mysql_tquery(gMySQL, query);
    }

    new msg[224];
    format(msg, sizeof(msg),
        "SIM card %s purchased. Type: %s. Insert it into your phone via /phone.",
        phone, legal ? ("legal") : ("disposable Burner"));
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    Audit_Log(Character_GetId(playerid), legal ? "SIM_BUY_LEGAL" : "SIM_BUY_BURNER",
        "CASH", "SIM", 0, price, legal ? "Buying a legal SIM card" : "Buying an anonymous SIM card");
    return 1;
}

// =============================================================================
//  4. ¿—»Õ’–ŒÕÕ€≈ SQL- ŒÀ¡≈ » » «¿√–”« ¿
// =============================================================================

static stock Internal_LoadSimsSync()
{
    if (!DB_IsConnected())
    {
        printf("%s [Systems/Telecom] Database not available: SIM cards will be created upon purchase.",
            SERVER_LOG_PREFIX);
        return 0;
    }

    new const Cache:simCache = mysql_query(gMySQL,
        "SELECT `phone_number`, `sim_item_id`, IFNULL(`registered_ssn`, '') AS `ssn`, `is_wiretapped`, IFNULL(`wiretap_org_id`, 0) AS `org_id` FROM `telecom_sims` ORDER BY `phone_number` ASC;",
        true);
    if (!cache_is_valid(simCache))
    {
        return 0;
    }

    new rows = 0;
    cache_get_row_count(rows);
    for (new r = 0; r < rows; r++)
    {
        new phone[PHONE_NUMBER_LEN], ssn[SIM_SSN_LEN];
        new simItemId, wiretapped, orgId;
        cache_get_value_name(r, "phone_number", phone, sizeof(phone));
        cache_get_value_name_int(r, "sim_item_id", simItemId);
        cache_get_value_name(r, "ssn", ssn, sizeof(ssn));
        cache_get_value_name_int(r, "is_wiretapped", wiretapped);
        cache_get_value_name_int(r, "org_id", orgId);
        Internal_AddSim(phone, simItemId, ssn, (wiretapped != 0), orgId);
    }
    cache_delete(simCache);
    return 1;
}

// =============================================================================
//  5. ’” » —»—“≈ÃÕ€’  ŒÀ¡≈ Œ¬ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_TELECOM_SIMS; i++)
    {
        Internal_ResetSimSlot(i);
    }
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        sPhoneMenuActionCount[i] = 0;
        sPhonePendingNumber[i][0] = EOS;
        sPhoneLastCommandTick[i] = 0;
    }

    for (new i = 0; i < TELECOM_SHOP_COUNT; i++)
    {
        sTelecomShopLabel[i] = CreateDynamic3DTextLabel(
            "Mobile phone store\nSIM cards: /sim",
            COLOR_UI_INFO,
            sTelecomShops[i][0],
            sTelecomShops[i][1],
            sTelecomShops[i][2] + 1.2,
            20.0,
            INVALID_PLAYER_ID,
            INVALID_VEHICLE_ID,
            0,
            0, 0, -1,
            80.0);
    }

    Internal_LoadSimsSync();
    printf("%s [Systems/Telecom] Loaded SIM cards: %d.", SERVER_LOG_PREFIX, Iter_Count(SimIter));
    return 1;
}

hook OnPlayerConnect(playerid)
{
    sPhoneMenuActionCount[playerid] = 0;
    sPhonePendingNumber[playerid][0] = EOS;
    sPhoneLastCommandTick[playerid] = 0;
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    sPhoneMenuActionCount[playerid] = 0;
    sPhonePendingNumber[playerid][0] = EOS;
    return 1;
}

// =============================================================================
//  3.1. ¬—œŒÃŒ√¿“≈À‹Õ€≈ œ–Œ¬≈– » ƒÀﬂ  ŒÃ¿Õƒ
// =============================================================================

static stock bool:Internal_PlayerHasWalkieTalkie(playerid)
{
    new const layer1 = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1))
    {
        return false;
    }
    new itemSlot = Storage_GetFirstItemSlot(layer1);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        if (Storage_GetItemDefId(itemSlot) == ITEM_ID_WALKIE_TALKIE)
        {
            return true;
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }
    return false;
}

static stock bool:Internal_ParseNumber(const input[], &outValue)
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
        outValue = (outValue * 10) + (input[i] - '0');
        if (outValue > 200000000)
        {
            return false;
        }
    }
    return (outValue > 0);
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch (dialogid)
    {
        case DIALOG_PHONE_MAIN:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sPhoneMenuActionCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const E_PHONE_MENU_ACTION:action = sPhoneMenuAction[playerid][listitem];
            switch (action)
            {
                case PHONE_MENU_NONE:
                {
                    return Y_HOOKS_BREAK_RETURN_1;
                }
                case PHONE_MENU_CALL:
                {
                    ShowPlayerDialog(playerid, DIALOG_PHONE_CALL_NUMBER, DIALOG_STYLE_INPUT,
                        "{FFC800}Outgoing call",
                        "Enter the subscriber's number in the format 555-123-4567.",
                        "Call",
                        "Cancel");
                }
                case PHONE_MENU_SMS:
                {
                    ShowPlayerDialog(playerid, DIALOG_PHONE_SMS_NUMBER, DIALOG_STYLE_INPUT,
                        "{FFC800}Sending SMS",
                        "Enter the subscriber's number in the format 555-123-4567.",
                        "Next",
                        "Cancel");
                }
                case PHONE_MENU_INSERT_SIM:
                {
                    Internal_InsertSim(playerid);
                    Internal_ShowPhoneMenu(playerid);
                }
                case PHONE_MENU_EJECT_SIM:
                {
                    Internal_EjectSim(playerid);
                    Internal_ShowPhoneMenu(playerid);
                }
                case PHONE_MENU_INFO:
                {
                    Internal_ShowPhoneInfo(playerid);
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_PHONE_CALL_NUMBER:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new number[PHONE_NUMBER_LEN];
            format(number, sizeof(number), "%s", inputtext);
            Internal_PlaceCall(playerid, number);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_PHONE_SMS_NUMBER:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            format(sPhonePendingNumber[playerid], PHONE_NUMBER_LEN, "%s", inputtext);
            ShowPlayerDialog(playerid, DIALOG_PHONE_SMS_TEXT, DIALOG_STYLE_INPUT,
                "{FFC800}SMS text",
                "Enter your message text (up to 128 characters).",
                "Send",
                "Cancel");
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_PHONE_SMS_TEXT:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new text[TELECOM_SMS_TEXT_LEN];
            format(text, sizeof(text), "%s", inputtext);
            Internal_SendSms(playerid, sPhonePendingNumber[playerid], text);
            sPhonePendingNumber[playerid][0] = EOS;
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_SIM_BUY:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_PurchaseSim(playerid, (listitem == 0));
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_1;
}

// =============================================================================
//  6.  ŒÃ¿Õƒ€ (Pawn.CMD)
// =============================================================================

CMD:phone(playerid, params[])
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
    Internal_ShowPhoneMenu(playerid);
    return 1;
}
alias:phone("tel");

CMD:sim(playerid, params[])
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
    Internal_BuySimDialog(playerid);
    return 1;
}

CMD:insertsim(playerid, params[])
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
    Internal_InsertSim(playerid);
    return 1;
}

CMD:ejectsim(playerid, params[])
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
    Internal_EjectSim(playerid);
    return 1;
}

CMD:call(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }
    if (strlen(params) == 0)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Usage: /call [number in the format 555-123-4567]");
        return 1;
    }
    Internal_PlaceCall(playerid, params);
    return 1;
}

CMD:sms(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }

    new number[PHONE_NUMBER_LEN];
    new text[TELECOM_SMS_TEXT_LEN];
    if (strlen(params) < 14)
    {
        SendClientMessage(playerid, COLOR_UI_INFO,
            "Usage: /sms [number 555-123-4567] [message text]");
        return 1;
    }

    strmid(number, params, 0, 12, sizeof(number));
    new start = 12;
    while (params[start] == ' ')
    {
        start++;
    }
    strmid(text, params, start, strlen(params), sizeof(text));
    if (text[0] == EOS)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The message text cannot be empty.");
        return 1;
    }
    Internal_SendSms(playerid, number, text);
    return 1;
}

CMD:wiretap(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }
    if (!Organizations_HasCharterFlag(Character_GetOrgId(playerid), FLAG_WIRETAP) ||
        Organizations_GetPlayerRankOrder(playerid) < TELECOM_WIRETAP_MIN_RANK)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Wiretapping is only available to FBI or CIA agents with the WIRETAP flag.");
        return 1;
    }

    new phone[PHONE_NUMBER_LEN];
    new action = -1;
    new const len = strlen(params);

    // –‡Á·Ó ÙÓÏ‡Ú‡: /wiretap 555-123-4567 1
    if (len < 15)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Usage: /wiretap [number] [1 enable / 0 disable]");
        return 1;
    }
    strmid(phone, params, 0, 12, sizeof(phone));
    new pos = 12;
    while (pos < len && params[pos] == ' ')
    {
        pos++;
    }
    if (pos < len && (params[pos] == '0' || params[pos] == '1'))
    {
        action = params[pos] - '0';
    }
    if (action < 0)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Usage: /wiretap [number] [1 enable / 0 disable]");
        return 1;
    }

    new const simSlot = Internal_FindSimByPhone(phone);
    if (simSlot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "No SIM card with this number was found.");
        return 1;
    }

    new const orgId = Character_GetOrgId(playerid);
    sSims[simSlot][E_SIM_IS_WIRETAPPED] = (action == 1);
    sSims[simSlot][E_SIM_WIRETAP_ORG_ID] = (action == 1) ? orgId : 0;

    if (DB_IsConnected())
    {
        new query[320];
        if (action == 1)
        {
            mysql_format(gMySQL, query, sizeof(query),
                "UPDATE `telecom_sims` SET `is_wiretapped` = 1, `wiretap_org_id` = %d WHERE `phone_number` = '%e';",
                orgId, phone);
        }
        else
        {
            mysql_format(gMySQL, query, sizeof(query),
                "UPDATE `telecom_sims` SET `is_wiretapped` = 0, `wiretap_org_id` = NULL WHERE `phone_number` = '%e';",
                phone);
        }
        mysql_tquery(gMySQL, query);
    }

    new msg[192];
    format(msg, sizeof(msg), "Wiretap number %s %s.", phone, (action == 1) ? ("included") : ("off"));
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    Audit_Log(Character_GetId(playerid), action == 1 ? "WIRETAP_ON" : "WIRETAP_OFF",
        "ORG", "SIM", 0, action, "Manage wiretapping of a telephone number");
    return 1;
}

CMD:radioscan(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_CommandAllowed(playerid))
    {
        return 1;
    }
    if (!Internal_PlayerHasWalkieTalkie(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "To scan, you need a walkie-talkie.");
        return 1;
    }
    if (!Organizations_HasCharterFlag(Character_GetOrgId(playerid), FLAG_WIRETAP))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Frequency scanning is only available to agents with the WIRETAP flag.");
        return 1;
    }

    new freq = 0;
    if (!Internal_ParseNumber(params, freq) || freq < TELECOM_RADIO_MIN_FREQ_KHZ || freq > TELECOM_RADIO_MAX_FREQ_KHZ)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Usage: /radioscan [frequency in kHz, for example 104500]");
        return 1;
    }

    new found = 0;
    foreach (new target : Player)
    {
        if (target == playerid || !Character_IsLoaded(target))
        {
            continue;
        }
        if (!Internal_PlayerHasWalkieTalkie(target))
        {
            continue;
        }
        if (Survival_GetRadioFreqKhz(target) != freq)
        {
            continue;
        }

        new name[MAX_PLAYER_NAME + 1], msg[192];
        Character_GetRpName(target, name, sizeof(name));
        format(msg, sizeof(msg), "[Scanner] Subscriber %s operates on the frequency %d.%03d MHz.",
            name, freq / 1000, freq % 1000);
        SendClientMessage(playerid, COLOR_UI_WARNING, msg);
        found++;
    }

    if (found == 0)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "No one was detected on the specified frequency.");
    }
    else
    {
        new summary[128];
        format(summary, sizeof(summary), "[Scanner] Subscribers detected: %d.", found);
        SendClientMessage(playerid, COLOR_UI_INFO, summary);
    }

    Audit_Log(Character_GetId(playerid), "RADIO_SCAN", "ORG", "RADIO", 0, freq,
        "Radio Frequency Scanning");
    return 1;
}

CMD:r(playerid, params[])
{
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    if (!Internal_PlayerHasWalkieTalkie(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "There is no walkie talkie in Layer 1.");
        return 1;
    }
    if (params[0] == EOS)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "Usage: /r [message to radio]");
        return 1;
    }

    new const freq = Survival_GetRadioFreqKhz(playerid);
    if (freq <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The radio is turned off. Set the frequency with the /radio command.");
        return 1;
    }

    new name[MAX_PLAYER_NAME + 1], msg[256];
    Character_GetRpName(playerid, name, sizeof(name));
    format(msg, sizeof(msg), "[Talkie %d.%03d] %s: %s", freq / 1000, freq % 1000, name, params);

    new listeners = 0;
    foreach (new target : Player)
    {
        if (target == playerid || !Character_IsLoaded(target))
        {
            continue;
        }
        if (!Internal_PlayerHasWalkieTalkie(target))
        {
            continue;
        }
        if (Survival_GetRadioFreqKhz(target) != freq)
        {
            continue;
        }
        SendClientMessage(target, COLOR_UI_INFO, msg);
        listeners++;
    }

    new ownMsg[256];
    format(ownMsg, sizeof(ownMsg), "[Talkie %d.%03d] You: %s (hear: %d)",
        freq / 1000, freq % 1000, params, listeners);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, ownMsg);
    return 1;
}


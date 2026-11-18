/*
 * =============================================================================
 *  SAN ANDREAS RP ó ÕÂ‰‚ËÊËÏÓÒÚ¸, Á‡ÏÍË, ÍÓÏÏÛÌ‡Î¸Ì˚Â ÔÎ‡ÚÂÊË Ë „‡‡ÊË
 *  ‘‡ÈÎ:      gamemodes/modules/entities/mod_properties.pwn
 *  œÛÌÍÚ:     ROADMAP [8.3] ó ÕÂ‰‚ËÊËÏÓÒÚ¸, Á‡ÏÍË Ë ÍÓÏÏÛÌ‡Î¸Ì˚Â ÔÎ‡ÚÂÊË
 *   Ó‰ËÓ‚Í‡: Windows-1251 (CP1251) ·ÂÁ BOM
 * =============================================================================
 */

#if defined _mod_properties_included
    #endinput
#endif
#define _mod_properties_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1.  ŒÕ—“¿Õ“€, ƒ»¿ÀŒ√», “»œ€ »  ŒÃÃ”Õ¿À‹Õ€≈ “¿–»‘€
// =============================================================================

#define DIALOG_PROPERTY_MAIN                    (1800)
#define DIALOG_PROPERTY_CONFIRM                 (1801)
#define DIALOG_PROPERTY_INFO                    (1802)

#define PROPERTY_TYPE_NAME_LEN                  (48)
#define PROPERTY_ADDRESS_LEN                    (64)
#define PROPERTY_MAX_MENU_ACTIONS               (12)
#define PROPERTY_COMMAND_COOLDOWN_MS            (500)
#define PROPERTY_INTERACT_RADIUS                (4.0)
#define PROPERTY_GARAGE_RADIUS                  (12.0)
#define PROPERTY_LABEL_DRAW_DISTANCE            (18.0)
#define PROPERTY_LABEL_STREAM_DISTANCE          (80.0)

#define PROPERTY_BILLING_INTERVAL_SECONDS       (3600)
#define PROPERTY_UTILITY_DISCONNECT_LIMIT_USD   (500)
#define PROPERTY_UTILITY_CONFISCATE_LIMIT_USD   (5000)
#define PROPERTY_RENT_FRACTION_HOURS            (24)

#define PROPERTY_STORAGE_TRAILER_WEIGHT_G       (30000)
#define PROPERTY_STORAGE_TRAILER_VOLUME_ML      (40000)
#define PROPERTY_STORAGE_APARTMENT_WEIGHT_G     (60000)
#define PROPERTY_STORAGE_APARTMENT_VOLUME_ML    (90000)
#define PROPERTY_STORAGE_HOUSE_WEIGHT_G         (180000)
#define PROPERTY_STORAGE_HOUSE_VOLUME_ML        (260000)
#define PROPERTY_STORAGE_MANSION_WEIGHT_G       (500000)
#define PROPERTY_STORAGE_MANSION_VOLUME_ML      (800000)
#define PROPERTY_STORAGE_COMMERCIAL_WEIGHT_G    (120000)
#define PROPERTY_STORAGE_COMMERCIAL_VOLUME_ML   (220000)
#define PROPERTY_STORAGE_WAREHOUSE_WEIGHT_G     (5000000)
#define PROPERTY_STORAGE_WAREHOUSE_VOLUME_ML    (10000000)
#define PROPERTY_STORAGE_GARAGE_WEIGHT_G        (120000)
#define PROPERTY_STORAGE_GARAGE_VOLUME_ML       (220000)

#define PROPERTY_INTERIOR_ID                    (2)
#define PROPERTY_INTERIOR_X                     (225.8)
#define PROPERTY_INTERIOR_Y                     (1022.5)
#define PROPERTY_INTERIOR_Z                     (1084.0)
#define PROPERTY_VIRTUAL_WORLD_BASE             (1000)

#define ROLE_ID_EX_SWAT                         (24)

#define PROPERTY_MAX_LIST_ROWS                  (32)

#define PROPERTY_KEY_COPY_COST_USD              (150)

//  ÓÌÚ‡ÍÚ˚ Ò ÏÓ‰ÛÎˇÏË, ÔÓ‰ÍÎ˛˜‡ÂÏ˚ÏË ÔÓÒÎÂ entities/mod_properties.pwn
forward bool:Banking_DebitAccount(playerid, amount, const reason[]);
forward bool:Banking_CreditAccount(playerid, amount, const reason[]);
forward Banking_GetBalance(playerid);
forward Dialogs_OpenExternalContainer(playerid, ext_storage_slot);
forward Forensics_CreateLockpickScratch(suspect_char_id, Float:x, Float:y, Float:z, interior, virtual_world);

// =============================================================================
//  2. œ≈–≈◊»—À≈Õ»ﬂ, ÿ¿¡ÀŒÕ€ » œ”À€ (static stock)
// =============================================================================

enum E_PROPERTY_TYPE
{
    PROPERTY_TYPE_NONE = 0,
    PROPERTY_TYPE_TRAILER,
    PROPERTY_TYPE_APARTMENT,
    PROPERTY_TYPE_HOUSE,
    PROPERTY_TYPE_MANSION,
    PROPERTY_TYPE_COMMERCIAL,
    PROPERTY_TYPE_WAREHOUSE,
    PROPERTY_TYPE_GARAGE
};

enum E_PROPERTY_OWNERSHIP
{
    PROPERTY_OWN_STATE_FOR_SALE = 0,
    PROPERTY_OWN_STATE_FOR_RENT,
    PROPERTY_OWN_PRIVATE
};

enum E_PROPERTY_MENU_ACTION
{
    PROPERTY_MENU_NONE = 0,
    PROPERTY_MENU_INFO,
    PROPERTY_MENU_ENTER,
    PROPERTY_MENU_EXIT,
    PROPERTY_MENU_BUY,
    PROPERTY_MENU_RENT,
    PROPERTY_MENU_STORAGE,
    PROPERTY_MENU_PAY_UTILS,
    PROPERTY_MENU_LOCK,
    PROPERTY_MENU_GARAGE
};

enum E_PROPERTY_CONFIRM_ACTION
{
    PROPERTY_CONFIRM_NONE = 0,
    PROPERTY_CONFIRM_BUY,
    PROPERTY_CONFIRM_RENT
};

enum E_PROPERTY_DATA
{
    bool:E_PROP_VALID,
    E_PROP_DB_ID,
    E_PROPERTY_TYPE:E_PROP_TYPE,
    E_PROPERTY_OWNERSHIP:E_PROP_OWNERSHIP,
    E_PROP_OWNER_CHAR_ID,
    E_PROP_OWNER_ORG_ID,
    E_PROP_PRICE_USD,
    E_PROP_RENT_PER_DAY_USD,
    E_PROP_UTILITY_DEBT_USD,
    bool:E_PROP_UTILITIES_ACTIVE,
    E_PROP_LOCK_LEVEL,
    bool:E_PROP_IS_LOCKED,
    E_PROP_STORAGE_DB_ID,
    E_PROP_STORAGE_SLOT,
    E_PROP_GARAGE_CAPACITY,
    Float:E_PROP_EXT_X,
    Float:E_PROP_EXT_Y,
    Float:E_PROP_EXT_Z,
    Float:E_PROP_EXT_A,
    Float:E_PROP_INT_X,
    Float:E_PROP_INT_Y,
    Float:E_PROP_INT_Z,
    E_PROP_INTERIOR_ID,
    E_PROP_VIRTUAL_WORLD,
    STREAMER_TAG_3D_TEXT_LABEL:E_PROP_LABEL,
    bool:E_PROP_IS_RENTED
};

enum E_BUILTIN_PROPERTY
{
    E_PROPERTY_TYPE:E_BP_TYPE,
    E_BP_PRICE_USD,
    E_BP_RENT_PER_DAY_USD,
    E_BP_GARAGE_CAPACITY,
    Float:E_BP_EXT_X,
    Float:E_BP_EXT_Y,
    Float:E_BP_EXT_Z,
    Float:E_BP_EXT_A
};

static stock sProperties[MAX_PROPERTIES][E_PROPERTY_DATA];
new Iterator:PropertyIter<MAX_PROPERTIES>;
static stock sNextPropertyDbId = 1;

static stock E_PROPERTY_MENU_ACTION:sPropertyMenuAction[MAX_PLAYERS][PROPERTY_MAX_MENU_ACTIONS];
static stock sPropertyMenuActionCount[MAX_PLAYERS];
static stock sPropertyPendingDbId[MAX_PLAYERS];
static stock E_PROPERTY_CONFIRM_ACTION:sPropertyConfirmAction[MAX_PLAYERS];
static stock sPropertyInsideDbId[MAX_PLAYERS];
static stock sPropertyLastCommandTick[MAX_PLAYERS];
static stock sPropertyBillingCounter = 0;

static stock const sBuiltinProperties[12][E_BUILTIN_PROPERTY] =
{
    { PROPERTY_TYPE_TRAILER,    15000,   0,     0, 2222.0,  -1150.0, 25.8,  0.0 },
    { PROPERTY_TYPE_APARTMENT,  80000,   0,     0, 2233.0,  -1159.0, 25.8,  90.0 },
    { PROPERTY_TYPE_HOUSE,      250000,  0,     2, 2495.0,  -1690.0, 14.8,  180.0 },
    { PROPERTY_TYPE_MANSION,    2000000, 0,     4, 2800.0,  -1170.0, 25.5,  270.0 },
    { PROPERTY_TYPE_COMMERCIAL, 500000,  0,     0, 1352.0,  -1759.0, 13.5,  0.0 },
    { PROPERTY_TYPE_WAREHOUSE,  1000000, 0,     0, 2403.0,  -1406.0, 24.0,  0.0 },
    { PROPERTY_TYPE_GARAGE,     150000,  0,     3, 1940.0,  -1772.0, 13.4,  0.0 },
    { PROPERTY_TYPE_HOUSE,      0,      1500,  2, -1981.0, 137.0,   27.7,  90.0 },
    { PROPERTY_TYPE_APARTMENT,  0,      800,   0, 2134.0,  1990.0,  10.8,  180.0 },
    { PROPERTY_TYPE_TRAILER,    0,      300,   0, -382.0,  -1426.0, 25.7,  270.0 },
    { PROPERTY_TYPE_COMMERCIAL, 0,      2500,  0, 1658.0,  2196.0,  10.8,  0.0 },
    { PROPERTY_TYPE_GARAGE,     0,      500,   2, -1676.0, 413.0,   7.2,   0.0 }
};

// =============================================================================
//  3. ¬Õ”“–≈ÕÕ»≈ ¬—œŒÃŒ√¿“≈À‹Õ€≈ ‘”Õ ÷»» (static stock)
// =============================================================================

static stock Internal_GetTypeString(E_PROPERTY_TYPE:propType, output[], len = sizeof(output))
{
    switch (propType)
    {
        case PROPERTY_TYPE_TRAILER:    format(output, len, "TRAILER");
        case PROPERTY_TYPE_APARTMENT:  format(output, len, "APARTMENT");
        case PROPERTY_TYPE_HOUSE:      format(output, len, "HOUSE");
        case PROPERTY_TYPE_MANSION:    format(output, len, "MANSION");
        case PROPERTY_TYPE_COMMERCIAL: format(output, len, "COMMERCIAL");
        case PROPERTY_TYPE_WAREHOUSE:  format(output, len, "WAREHOUSE");
        case PROPERTY_TYPE_GARAGE:     format(output, len, "GARAGE");
        default:                       format(output, len, "TRAILER");
    }
    return 1;
}

static stock E_PROPERTY_TYPE:Internal_ParseType(const typeStr[])
{
    if (!strcmp(typeStr, "APARTMENT", true))  return PROPERTY_TYPE_APARTMENT;
    if (!strcmp(typeStr, "HOUSE", true))      return PROPERTY_TYPE_HOUSE;
    if (!strcmp(typeStr, "MANSION", true))    return PROPERTY_TYPE_MANSION;
    if (!strcmp(typeStr, "COMMERCIAL", true)) return PROPERTY_TYPE_COMMERCIAL;
    if (!strcmp(typeStr, "WAREHOUSE", true))  return PROPERTY_TYPE_WAREHOUSE;
    if (!strcmp(typeStr, "GARAGE", true))     return PROPERTY_TYPE_GARAGE;
    return PROPERTY_TYPE_TRAILER;
}

static stock Internal_GetOwnershipString(E_PROPERTY_OWNERSHIP:ownership, output[], len = sizeof(output))
{
    switch (ownership)
    {
        case PROPERTY_OWN_STATE_FOR_RENT: format(output, len, "STATE_FOR_RENT");
        case PROPERTY_OWN_PRIVATE:        format(output, len, "PRIVATE");
        default:                          format(output, len, "STATE_FOR_SALE");
    }
    return 1;
}

static stock E_PROPERTY_OWNERSHIP:Internal_ParseOwnership(const ownershipStr[])
{
    if (!strcmp(ownershipStr, "STATE_FOR_RENT", true)) return PROPERTY_OWN_STATE_FOR_RENT;
    if (!strcmp(ownershipStr, "PRIVATE", true))        return PROPERTY_OWN_PRIVATE;
    return PROPERTY_OWN_STATE_FOR_SALE;
}

stock Properties_GetTypeTitleRu(E_PROPERTY_TYPE:propType, output[], len = sizeof(output))
{
    switch (propType)
    {
        case PROPERTY_TYPE_TRAILER:    format(output, len, "Trailer");
        case PROPERTY_TYPE_APARTMENT:  format(output, len, "Apartment");
        case PROPERTY_TYPE_HOUSE:      format(output, len, "House");
        case PROPERTY_TYPE_MANSION:    format(output, len, "Mansion");
        case PROPERTY_TYPE_COMMERCIAL: format(output, len, "Commercial space");
        case PROPERTY_TYPE_WAREHOUSE:  format(output, len, "Warehouse");
        case PROPERTY_TYPE_GARAGE:     format(output, len, "Garage");
        default:                       format(output, len, "Unknown object");
    }
    return 1;
}

static stock Internal_GetPropertyLabelText(property_db_id, output[], len = sizeof(output))
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        output[0] = EOS;
        return 0;
    }

    new typeName[PROPERTY_TYPE_NAME_LEN], priceStr[32], rentStr[32];
    Properties_GetTypeTitleRu(sProperties[slot][E_PROP_TYPE], typeName, sizeof(typeName));
    Utils_FormatMoney(sProperties[slot][E_PROP_PRICE_USD], priceStr);
    Utils_FormatMoney(sProperties[slot][E_PROP_RENT_PER_DAY_USD], rentStr);

    if (sProperties[slot][E_PROP_OWNERSHIP] == PROPERTY_OWN_PRIVATE)
    {
        format(output, len,
            "%s #%d\nPrivate property\n/property",
            typeName, property_db_id);
    }
    else if (sProperties[slot][E_PROP_OWNERSHIP] == PROPERTY_OWN_STATE_FOR_RENT)
    {
        format(output, len,
            "%s #%d\nRent: %s per day\n/property",
            typeName, property_db_id, rentStr);
    }
    else
    {
        format(output, len,
            "%s #%d\nPrice: %s\n/property",
            typeName, property_db_id, priceStr);
    }
    return 1;
}

static stock Internal_RefreshLabel(property_db_id)
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        return 0;
    }
    if (sProperties[slot][E_PROP_LABEL] == STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID)
    {
        return 0;
    }

    new text[256];
    Internal_GetPropertyLabelText(property_db_id, text, sizeof(text));
    UpdateDynamic3DTextLabelText(sProperties[slot][E_PROP_LABEL], COLOR_UI_INFO, text);
    return 1;
}

static stock Internal_GetStorageLimits(E_PROPERTY_TYPE:propType, &weightG, &volumeMl)
{
    switch (propType)
    {
        case PROPERTY_TYPE_TRAILER:
        {
            weightG = PROPERTY_STORAGE_TRAILER_WEIGHT_G;
            volumeMl = PROPERTY_STORAGE_TRAILER_VOLUME_ML;
        }
        case PROPERTY_TYPE_APARTMENT:
        {
            weightG = PROPERTY_STORAGE_APARTMENT_WEIGHT_G;
            volumeMl = PROPERTY_STORAGE_APARTMENT_VOLUME_ML;
        }
        case PROPERTY_TYPE_HOUSE:
        {
            weightG = PROPERTY_STORAGE_HOUSE_WEIGHT_G;
            volumeMl = PROPERTY_STORAGE_HOUSE_VOLUME_ML;
        }
        case PROPERTY_TYPE_MANSION:
        {
            weightG = PROPERTY_STORAGE_MANSION_WEIGHT_G;
            volumeMl = PROPERTY_STORAGE_MANSION_VOLUME_ML;
        }
        case PROPERTY_TYPE_COMMERCIAL:
        {
            weightG = PROPERTY_STORAGE_COMMERCIAL_WEIGHT_G;
            volumeMl = PROPERTY_STORAGE_COMMERCIAL_VOLUME_ML;
        }
        case PROPERTY_TYPE_WAREHOUSE:
        {
            weightG = PROPERTY_STORAGE_WAREHOUSE_WEIGHT_G;
            volumeMl = PROPERTY_STORAGE_WAREHOUSE_VOLUME_ML;
        }
        default:
        {
            weightG = PROPERTY_STORAGE_GARAGE_WEIGHT_G;
            volumeMl = PROPERTY_STORAGE_GARAGE_VOLUME_ML;
        }
    }
    return 1;
}

static stock Internal_GetUtilityHourlyUsd(E_PROPERTY_TYPE:propType)
{
    switch (propType)
    {
        case PROPERTY_TYPE_NONE:       return 10;
        case PROPERTY_TYPE_TRAILER:    return 5;
        case PROPERTY_TYPE_APARTMENT:  return 15;
        case PROPERTY_TYPE_HOUSE:      return 30;
        case PROPERTY_TYPE_MANSION:    return 100;
        case PROPERTY_TYPE_COMMERCIAL: return 40;
        case PROPERTY_TYPE_WAREHOUSE:  return 80;
        case PROPERTY_TYPE_GARAGE:     return 20;
    }
    return 10;
}

static stock Internal_GetLockLevel(E_PROPERTY_TYPE:propType)
{
    switch (propType)
    {
        case PROPERTY_TYPE_NONE:       return 1;
        case PROPERTY_TYPE_MANSION:    return 4;
        case PROPERTY_TYPE_WAREHOUSE:  return 3;
        case PROPERTY_TYPE_COMMERCIAL: return 3;
        case PROPERTY_TYPE_HOUSE:      return 2;
        case PROPERTY_TYPE_APARTMENT:  return 2;
        case PROPERTY_TYPE_GARAGE:     return 2;
        case PROPERTY_TYPE_TRAILER:    return 1;
    }
    return 1;
}

static stock Internal_ResetPropertySlot(slot)
{
    sProperties[slot][E_PROP_VALID] = false;
    sProperties[slot][E_PROP_DB_ID] = 0;
    sProperties[slot][E_PROP_TYPE] = PROPERTY_TYPE_NONE;
    sProperties[slot][E_PROP_OWNERSHIP] = PROPERTY_OWN_STATE_FOR_SALE;
    sProperties[slot][E_PROP_OWNER_CHAR_ID] = 0;
    sProperties[slot][E_PROP_OWNER_ORG_ID] = 0;
    sProperties[slot][E_PROP_PRICE_USD] = 0;
    sProperties[slot][E_PROP_RENT_PER_DAY_USD] = 0;
    sProperties[slot][E_PROP_UTILITY_DEBT_USD] = 0;
    sProperties[slot][E_PROP_UTILITIES_ACTIVE] = true;
    sProperties[slot][E_PROP_LOCK_LEVEL] = 1;
    sProperties[slot][E_PROP_IS_LOCKED] = true;
    sProperties[slot][E_PROP_STORAGE_DB_ID] = 0;
    sProperties[slot][E_PROP_STORAGE_SLOT] = INVALID_STORAGE_SLOT;
    sProperties[slot][E_PROP_GARAGE_CAPACITY] = 0;
    sProperties[slot][E_PROP_EXT_X] = 0.0;
    sProperties[slot][E_PROP_EXT_Y] = 0.0;
    sProperties[slot][E_PROP_EXT_Z] = 0.0;
    sProperties[slot][E_PROP_EXT_A] = 0.0;
    sProperties[slot][E_PROP_INT_X] = PROPERTY_INTERIOR_X;
    sProperties[slot][E_PROP_INT_Y] = PROPERTY_INTERIOR_Y;
    sProperties[slot][E_PROP_INT_Z] = PROPERTY_INTERIOR_Z;
    sProperties[slot][E_PROP_INTERIOR_ID] = PROPERTY_INTERIOR_ID;
    sProperties[slot][E_PROP_VIRTUAL_WORLD] = 0;
    sProperties[slot][E_PROP_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
    sProperties[slot][E_PROP_IS_RENTED] = false;
    return 1;
}

stock Properties_FindByDbId(property_db_id)
{
    if (property_db_id <= 0)
    {
        return -1;
    }
    foreach (new slot : PropertyIter)
    {
        if (sProperties[slot][E_PROP_VALID] && sProperties[slot][E_PROP_DB_ID] == property_db_id)
        {
            return slot;
        }
    }
    return -1;
}

stock bool:Properties_IsValid(property_db_id)
{
    return (Properties_FindByDbId(property_db_id) >= 0);
}

stock Properties_GetDbId(slot)
{
    if (slot < 0 || slot >= MAX_PROPERTIES || !sProperties[slot][E_PROP_VALID])
    {
        return 0;
    }
    return sProperties[slot][E_PROP_DB_ID];
}

static stock Internal_AddProperty(
    db_id,
    E_PROPERTY_TYPE:propType,
    E_PROPERTY_OWNERSHIP:ownership,
    owner_char_id,
    owner_org_id,
    price_usd,
    rent_per_day_usd,
    utility_debt_usd,
    bool:utilities_active,
    lock_level,
    bool:is_locked,
    storage_db_id,
    garage_capacity,
    Float:ext_x,
    Float:ext_y,
    Float:ext_z,
    Float:ext_a,
    interior_id,
    virtual_world)
{
    new const slot = Iter_Free(PropertyIter);
    if (slot == INVALID_ITERATOR_SLOT)
    {
        return -1;
    }

    Iter_Add(PropertyIter, slot);
    Internal_ResetPropertySlot(slot);

    sProperties[slot][E_PROP_VALID] = true;
    sProperties[slot][E_PROP_DB_ID] = db_id;
    sProperties[slot][E_PROP_TYPE] = propType;
    sProperties[slot][E_PROP_OWNERSHIP] = ownership;
    sProperties[slot][E_PROP_OWNER_CHAR_ID] = owner_char_id;
    sProperties[slot][E_PROP_OWNER_ORG_ID] = owner_org_id;
    sProperties[slot][E_PROP_PRICE_USD] = price_usd;
    sProperties[slot][E_PROP_RENT_PER_DAY_USD] = rent_per_day_usd;
    sProperties[slot][E_PROP_UTILITY_DEBT_USD] = utility_debt_usd;
    sProperties[slot][E_PROP_UTILITIES_ACTIVE] = utilities_active;
    sProperties[slot][E_PROP_LOCK_LEVEL] = lock_level;
    sProperties[slot][E_PROP_IS_LOCKED] = is_locked;
    sProperties[slot][E_PROP_GARAGE_CAPACITY] = garage_capacity;
    sProperties[slot][E_PROP_EXT_X] = ext_x;
    sProperties[slot][E_PROP_EXT_Y] = ext_y;
    sProperties[slot][E_PROP_EXT_Z] = ext_z;
    sProperties[slot][E_PROP_EXT_A] = ext_a;
    sProperties[slot][E_PROP_INT_X] = PROPERTY_INTERIOR_X;
    sProperties[slot][E_PROP_INT_Y] = PROPERTY_INTERIOR_Y;
    sProperties[slot][E_PROP_INT_Z] = PROPERTY_INTERIOR_Z;
    sProperties[slot][E_PROP_INTERIOR_ID] = interior_id;
    sProperties[slot][E_PROP_VIRTUAL_WORLD] = virtual_world;
    sProperties[slot][E_PROP_IS_RENTED] = (rent_per_day_usd > 0 && price_usd <= 0);

    new weightG, volumeMl;
    Internal_GetStorageLimits(propType, weightG, volumeMl);

    new storageSlot = INVALID_STORAGE_SLOT;
    if (storage_db_id > 0)
    {
        storageSlot = Storage_FindByDbId(storage_db_id);
    }
    if (storageSlot != INVALID_STORAGE_SLOT)
    {
        sProperties[slot][E_PROP_STORAGE_SLOT] = storageSlot;
    }
    else if (storage_db_id > 0)
    {
        storageSlot = Storage_Create(
            STORAGE_PROPERTY_STASH,
            db_id,
            weightG,
            volumeMl,
            false,
            lock_level,
            PROPERTY_INTERIOR_X,
            PROPERTY_INTERIOR_Y,
            PROPERTY_INTERIOR_Z,
            interior_id,
            virtual_world,
            0,
            storage_db_id);
    }
    else
    {
        storageSlot = Storage_Create(
            STORAGE_PROPERTY_STASH,
            db_id,
            weightG,
            volumeMl,
            false,
            lock_level,
            PROPERTY_INTERIOR_X,
            PROPERTY_INTERIOR_Y,
            PROPERTY_INTERIOR_Z,
            interior_id,
            virtual_world);
        if (storageSlot != INVALID_STORAGE_SLOT)
        {
            sProperties[slot][E_PROP_STORAGE_DB_ID] = Storage_GetDbId(storageSlot);
        }
    }
    sProperties[slot][E_PROP_STORAGE_SLOT] = storageSlot;

    new labelText[256];
    Internal_GetPropertyLabelText(db_id, labelText, sizeof(labelText));
    sProperties[slot][E_PROP_LABEL] = CreateDynamic3DTextLabel(
        labelText,
        COLOR_UI_INFO,
        ext_x, ext_y, ext_z + 1.0,
        PROPERTY_LABEL_DRAW_DISTANCE,
        INVALID_PLAYER_ID,
        INVALID_VEHICLE_ID,
        0,
        0, 0, -1,
        PROPERTY_LABEL_STREAM_DISTANCE);
    return slot;
}

static stock Internal_InsertPropertyDb(slot)
{
    if (slot < 0 || slot >= MAX_PROPERTIES || !sProperties[slot][E_PROP_VALID] || !DB_IsConnected())
    {
        return 0;
    }

    new typeStr[24], ownershipStr[24], ownerCharSql[16], ownerOrgSql[16];
    Internal_GetTypeString(sProperties[slot][E_PROP_TYPE], typeStr, sizeof(typeStr));
    Internal_GetOwnershipString(sProperties[slot][E_PROP_OWNERSHIP], ownershipStr, sizeof(ownershipStr));
    if (sProperties[slot][E_PROP_OWNER_CHAR_ID] > 0)
        format(ownerCharSql, sizeof(ownerCharSql), "%d", sProperties[slot][E_PROP_OWNER_CHAR_ID]);
    else
        format(ownerCharSql, sizeof(ownerCharSql), "NULL");
    if (sProperties[slot][E_PROP_OWNER_ORG_ID] > 0)
        format(ownerOrgSql, sizeof(ownerOrgSql), "%d", sProperties[slot][E_PROP_OWNER_ORG_ID]);
    else
        format(ownerOrgSql, sizeof(ownerOrgSql), "NULL");

    new query[896];
    mysql_format(gMySQL, query, sizeof(query),
        "INSERT INTO `properties` (`id`, `prop_type`, `ownership`, `owner_char_id`, `owner_org_id`, `purchase_price_usd`, `rent_per_day_usd`, `utility_debt_usd`, `utilities_active`, `lock_level`, `is_locked`, `storage_id`, `garage_capacity`, `ext_x`, `ext_y`, `ext_z`, `int_x`, `int_y`, `int_z`, `interior_id`, `virtual_world`) VALUES (%d, '%e', '%e', %s, %s, %d, %d, %d, %d, %d, %d, %d, %d, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %d, %d);",
        sProperties[slot][E_PROP_DB_ID],
        typeStr,
        ownershipStr,
        ownerCharSql,
        ownerOrgSql,
        sProperties[slot][E_PROP_PRICE_USD],
        sProperties[slot][E_PROP_RENT_PER_DAY_USD],
        sProperties[slot][E_PROP_UTILITY_DEBT_USD],
        sProperties[slot][E_PROP_UTILITIES_ACTIVE] ? 1 : 0,
        sProperties[slot][E_PROP_LOCK_LEVEL],
        sProperties[slot][E_PROP_IS_LOCKED] ? 1 : 0,
        sProperties[slot][E_PROP_STORAGE_DB_ID],
        sProperties[slot][E_PROP_GARAGE_CAPACITY],
        sProperties[slot][E_PROP_EXT_X],
        sProperties[slot][E_PROP_EXT_Y],
        sProperties[slot][E_PROP_EXT_Z],
        sProperties[slot][E_PROP_INT_X],
        sProperties[slot][E_PROP_INT_Y],
        sProperties[slot][E_PROP_INT_Z],
        sProperties[slot][E_PROP_INTERIOR_ID],
        sProperties[slot][E_PROP_VIRTUAL_WORLD]);
    mysql_pquery(gMySQL, query);
    return 1;
}

static stock Internal_SeedBuiltinProperties()
{
    for (new i = 0; i < sizeof(sBuiltinProperties); i++)
    {
        new const dbId = i + 1;
        new const E_PROPERTY_OWNERSHIP:ownership = (sBuiltinProperties[i][E_BP_PRICE_USD] > 0)
            ? PROPERTY_OWN_STATE_FOR_SALE
            : PROPERTY_OWN_STATE_FOR_RENT;

        new const slot = Internal_AddProperty(
            dbId,
            sBuiltinProperties[i][E_BP_TYPE],
            ownership,
            0,
            0,
            sBuiltinProperties[i][E_BP_PRICE_USD],
            sBuiltinProperties[i][E_BP_RENT_PER_DAY_USD],
            0,
            true,
            Internal_GetLockLevel(sBuiltinProperties[i][E_BP_TYPE]),
            true,
            0,
            sBuiltinProperties[i][E_BP_GARAGE_CAPACITY],
            sBuiltinProperties[i][E_BP_EXT_X],
            sBuiltinProperties[i][E_BP_EXT_Y],
            sBuiltinProperties[i][E_BP_EXT_Z],
            sBuiltinProperties[i][E_BP_EXT_A],
            PROPERTY_INTERIOR_ID,
            PROPERTY_VIRTUAL_WORLD_BASE + dbId);

        if (slot >= 0)
        {
            Internal_InsertPropertyDb(slot);
        }
    }

    if (sNextPropertyDbId < (sizeof(sBuiltinProperties) + 1))
    {
        sNextPropertyDbId = sizeof(sBuiltinProperties) + 1;
    }
    return 1;
}

static stock Internal_LoadPropertiesSync()
{
    if (!DB_IsConnected())
    {
        Internal_SeedBuiltinProperties();
        printf("%s [Entities/Properties] The database is unavailable: the built-in registry of 12 objects has been loaded.",
            SERVER_LOG_PREFIX);
        return 0;
    }

    new const Cache:maxCache = mysql_query(gMySQL,
        "SELECT IFNULL(MAX(`id`), 0) AS `max_id` FROM `properties`;",
        true);
    if (cache_is_valid(maxCache))
    {
        new maxId = 0;
        cache_get_value_name_int(0, "max_id", maxId);
        sNextPropertyDbId = maxId + 1;
        cache_delete(maxCache);
    }

    new const Cache:propCache = mysql_query(gMySQL,
        "SELECT `id`, `prop_type`, `ownership`, IFNULL(`owner_char_id`, 0) AS `owner_char`, IFNULL(`owner_org_id`, 0) AS `owner_org`, `purchase_price_usd`, `rent_per_day_usd`, `utility_debt_usd`, `utilities_active`, `lock_level`, `is_locked`, `storage_id`, `garage_capacity`, `ext_x`, `ext_y`, `ext_z`, `int_x`, `int_y`, `int_z`, `interior_id`, `virtual_world` FROM `properties` ORDER BY `id` ASC;",
        true);

    if (cache_is_valid(propCache))
    {
        new rows = 0;
        cache_get_row_count(rows);
        for (new r = 0; r < rows; r++)
        {
            new dbId, ownerChar, ownerOrg, price, rent, debt, utilitiesInt, lockLevel, lockedInt, storageDbId, garageCapacity;
            new interiorId, vw;
            new Float:extX, Float:extY, Float:extZ, Float:intX, Float:intY, Float:intZ;
            new typeStr[24], ownershipStr[24];

            cache_get_value_name_int(r, "id", dbId);
            cache_get_value_name(r, "prop_type", typeStr, sizeof(typeStr));
            cache_get_value_name(r, "ownership", ownershipStr, sizeof(ownershipStr));
            cache_get_value_name_int(r, "owner_char", ownerChar);
            cache_get_value_name_int(r, "owner_org", ownerOrg);
            cache_get_value_name_int(r, "purchase_price_usd", price);
            cache_get_value_name_int(r, "rent_per_day_usd", rent);
            cache_get_value_name_int(r, "utility_debt_usd", debt);
            cache_get_value_name_int(r, "utilities_active", utilitiesInt);
            cache_get_value_name_int(r, "lock_level", lockLevel);
            cache_get_value_name_int(r, "is_locked", lockedInt);
            cache_get_value_name_int(r, "storage_id", storageDbId);
            cache_get_value_name_int(r, "garage_capacity", garageCapacity);
            cache_get_value_name_float(r, "ext_x", extX);
            cache_get_value_name_float(r, "ext_y", extY);
            cache_get_value_name_float(r, "ext_z", extZ);
            cache_get_value_name_float(r, "int_x", intX);
            cache_get_value_name_float(r, "int_y", intY);
            cache_get_value_name_float(r, "int_z", intZ);
            cache_get_value_name_int(r, "interior_id", interiorId);
            cache_get_value_name_int(r, "virtual_world", vw);

            new const slot = Internal_AddProperty(
                dbId,
                Internal_ParseType(typeStr),
                Internal_ParseOwnership(ownershipStr),
                ownerChar, ownerOrg,
                price, rent,
                debt, (utilitiesInt != 0),
                lockLevel, (lockedInt != 0),
                storageDbId, garageCapacity,
                extX, extY, extZ, 0.0,
                interiorId, vw);

            if (slot >= 0)
            {
                sProperties[slot][E_PROP_INT_X] = intX;
                sProperties[slot][E_PROP_INT_Y] = intY;
                sProperties[slot][E_PROP_INT_Z] = intZ;
            }
        }
        cache_delete(propCache);
    }

    if (Iter_Count(PropertyIter) == 0)
    {
        Internal_SeedBuiltinProperties();
        printf("%s [Entities/Properties] The properties table is empty: the built-in registry is applied.",
            SERVER_LOG_PREFIX);
    }
    return 1;
}

// =============================================================================
//  4. œ”¡À»◊Õ€… API Õ≈ƒ¬»∆»ÃŒ—“»
// =============================================================================

stock Properties_GetNearestProperty(playerid, Float:radius, &property_db_id)
{
    property_db_id = 0;
    if (!IsPlayerConnected(playerid))
    {
        return -1;
    }

    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);

    new bestSlot = -1;
    new Float:bestDistance = radius + 0.001;

    foreach (new slot : PropertyIter)
    {
        if (!sProperties[slot][E_PROP_VALID])
        {
            continue;
        }
        new const Float:dist = Utils_GetDistance3D(px, py, pz,
            sProperties[slot][E_PROP_EXT_X],
            sProperties[slot][E_PROP_EXT_Y],
            sProperties[slot][E_PROP_EXT_Z]);
        if (dist <= bestDistance)
        {
            bestDistance = dist;
            bestSlot = slot;
        }
    }

    if (bestSlot >= 0)
    {
        property_db_id = sProperties[bestSlot][E_PROP_DB_ID];
    }
    return bestSlot;
}

stock bool:Properties_GetExteriorPos(property_db_id, &Float:x, &Float:y, &Float:z, &Float:a)
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        x = 0.0;
        y = 0.0;
        z = 0.0;
        a = 0.0;
        return false;
    }
    x = sProperties[slot][E_PROP_EXT_X];
    y = sProperties[slot][E_PROP_EXT_Y];
    z = sProperties[slot][E_PROP_EXT_Z];
    a = sProperties[slot][E_PROP_EXT_A];
    return true;
}

stock bool:Properties_GetInteriorPos(property_db_id, &Float:x, &Float:y, &Float:z, &interior, &virtual_world)
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        x = 0.0;
        y = 0.0;
        z = 0.0;
        interior = 0;
        virtual_world = 0;
        return false;
    }
    x = sProperties[slot][E_PROP_INT_X];
    y = sProperties[slot][E_PROP_INT_Y];
    z = sProperties[slot][E_PROP_INT_Z];
    interior = sProperties[slot][E_PROP_INTERIOR_ID];
    virtual_world = sProperties[slot][E_PROP_VIRTUAL_WORLD];
    return true;
}

stock bool:Properties_PlayerHasKey(playerid, property_db_id)
{
    if (!Character_IsLoaded(playerid))
    {
        return false;
    }
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
            if (Storage_GetItemDefId(itemSlot) == ITEM_ID_PHYSICAL_KEYS &&
                Storage_GetItemMetaInt2(itemSlot) == property_db_id)
            {
                return true;
            }
            itemSlot = Storage_GetNextItemSlot(itemSlot);
        }
    }
    return false;
}

stock bool:Properties_IsOwner(playerid, property_db_id)
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0 || !Character_IsLoaded(playerid))
    {
        return false;
    }
    return (sProperties[slot][E_PROP_OWNERSHIP] == PROPERTY_OWN_PRIVATE &&
        sProperties[slot][E_PROP_OWNER_CHAR_ID] == Character_GetId(playerid));
}

stock bool:Properties_GetNearestOwnedGarage(playerid, &property_db_id, &capacity)
{
    property_db_id = 0;
    capacity = 0;
    if (!Character_IsLoaded(playerid))
    {
        return false;
    }

    new nearestDbId = 0;
    new const nearestSlot = Properties_GetNearestProperty(playerid, PROPERTY_GARAGE_RADIUS, nearestDbId);
    if (nearestSlot < 0)
    {
        return false;
    }
    if (sProperties[nearestSlot][E_PROP_GARAGE_CAPACITY] <= 0)
    {
        return false;
    }
    if (!Properties_IsOwner(playerid, nearestDbId))
    {
        return false;
    }

    property_db_id = nearestDbId;
    capacity = sProperties[nearestSlot][E_PROP_GARAGE_CAPACITY];
    return true;
}

static stock bool:Internal_PlayerHasPropertyKeyOrOwner(playerid, property_db_id)
{
    return (Properties_IsOwner(playerid, property_db_id) || Properties_PlayerHasKey(playerid, property_db_id));
}

static stock bool:Internal_CommandAllowed(playerid)
{
    new const nowTick = GetTickCount();
    if ((nowTick - sPropertyLastCommandTick[playerid]) < PROPERTY_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "Not so fast: Wait for the previous operation to complete.");
        return false;
    }
    sPropertyLastCommandTick[playerid] = nowTick;
    return true;
}

static stock Internal_IssuePropertyKey(playerid, property_db_id)
{
    new const layer1 = Character_GetLayer1Slot(playerid);
    new const layer2 = Character_GetLayer2Slot(playerid);
    new targetStorage = Storage_IsValidSlot(layer1) ? layer1 : layer2;
    if (!Storage_IsValidSlot(targetStorage))
    {
        return false;
    }

    new keyMeta[64];
    format(keyMeta, sizeof(keyMeta), "PROPERTY-%d", property_db_id);
    new outItem = INVALID_STORAGE_ITEM_SLOT;
    new E_STORAGE_RESULT:result = Storage_AddItem(
        targetStorage,
        ITEM_ID_PHYSICAL_KEYS,
        1,
        0,
        100.0,
        0,
        property_db_id,
        keyMeta,
        outItem);

    if (result != STORAGE_RES_OK && Storage_IsValidSlot(layer2) && targetStorage != layer2)
    {
        result = Storage_AddItem(
            layer2,
            ITEM_ID_PHYSICAL_KEYS,
            1,
            0,
            100.0,
            0,
            property_db_id,
            keyMeta,
            outItem);
    }
    return (result == STORAGE_RES_OK);
}

static stock Internal_UpdatePropertyDb(slot)
{
    if (slot < 0 || slot >= MAX_PROPERTIES || !sProperties[slot][E_PROP_VALID] || !DB_IsConnected())
    {
        return 0;
    }

    new ownershipStr[24], ownerCharSql[16], ownerOrgSql[16];
    Internal_GetOwnershipString(sProperties[slot][E_PROP_OWNERSHIP], ownershipStr, sizeof(ownershipStr));
    if (sProperties[slot][E_PROP_OWNER_CHAR_ID] > 0)
        format(ownerCharSql, sizeof(ownerCharSql), "%d", sProperties[slot][E_PROP_OWNER_CHAR_ID]);
    else
        format(ownerCharSql, sizeof(ownerCharSql), "NULL");
    if (sProperties[slot][E_PROP_OWNER_ORG_ID] > 0)
        format(ownerOrgSql, sizeof(ownerOrgSql), "%d", sProperties[slot][E_PROP_OWNER_ORG_ID]);
    else
        format(ownerOrgSql, sizeof(ownerOrgSql), "NULL");

    new query[640];
    mysql_format(gMySQL, query, sizeof(query),
        "UPDATE `properties` SET `ownership` = '%e', `owner_char_id` = %s, `owner_org_id` = %s, `utility_debt_usd` = %d, `utilities_active` = %d, `is_locked` = %d, `garage_capacity` = %d WHERE `id` = %d;",
        ownershipStr,
        ownerCharSql,
        ownerOrgSql,
        sProperties[slot][E_PROP_UTILITY_DEBT_USD],
        sProperties[slot][E_PROP_UTILITIES_ACTIVE] ? 1 : 0,
        sProperties[slot][E_PROP_IS_LOCKED] ? 1 : 0,
        sProperties[slot][E_PROP_GARAGE_CAPACITY],
        sProperties[slot][E_PROP_DB_ID]);
    mysql_tquery(gMySQL, query);
    return 1;
}

static stock Internal_OpenPropertyMenu(playerid, property_db_id)
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The property was not found.");
        return 0;
    }

    new count = 0;
    new body[1024];
    body[0] = '\0';

    if (sPropertyInsideDbId[playerid] == property_db_id)
    {
        strcat(body, "Object information\n", sizeof(body));
        sPropertyMenuAction[playerid][count++] = PROPERTY_MENU_INFO;
        strcat(body, "Open home storage\n", sizeof(body));
        sPropertyMenuAction[playerid][count++] = PROPERTY_MENU_STORAGE;
        strcat(body, "Pay utilities\n", sizeof(body));
        sPropertyMenuAction[playerid][count++] = PROPERTY_MENU_PAY_UTILS;
        strcat(body, "Lock or unlock the door\n", sizeof(body));
        sPropertyMenuAction[playerid][count++] = PROPERTY_MENU_LOCK;
        if (sProperties[slot][E_PROP_GARAGE_CAPACITY] > 0)
        {
            strcat(body, "Garage management (/vpark, /vunpark)\n", sizeof(body));
            sPropertyMenuAction[playerid][count++] = PROPERTY_MENU_GARAGE;
        }
        strcat(body, "Go outside\n", sizeof(body));
        sPropertyMenuAction[playerid][count++] = PROPERTY_MENU_EXIT;
    }
    else
    {
        strcat(body, "Object information\n", sizeof(body));
        sPropertyMenuAction[playerid][count++] = PROPERTY_MENU_INFO;
        strcat(body, "Go inside\n", sizeof(body));
        sPropertyMenuAction[playerid][count++] = PROPERTY_MENU_ENTER;
        if (sProperties[slot][E_PROP_OWNERSHIP] == PROPERTY_OWN_STATE_FOR_SALE)
        {
            strcat(body, "Buy object\n", sizeof(body));
            sPropertyMenuAction[playerid][count++] = PROPERTY_MENU_BUY;
        }
        else if (sProperties[slot][E_PROP_OWNERSHIP] == PROPERTY_OWN_STATE_FOR_RENT)
        {
            strcat(body, "Rent an object\n", sizeof(body));
            sPropertyMenuAction[playerid][count++] = PROPERTY_MENU_RENT;
        }
        strcat(body, "Check the lock and signs of forced entry\n", sizeof(body));
        sPropertyMenuAction[playerid][count++] = PROPERTY_MENU_LOCK;
    }

    sPropertyMenuActionCount[playerid] = count;
    sPropertyPendingDbId[playerid] = property_db_id;

    new typeName[PROPERTY_TYPE_NAME_LEN], caption[160];
    Properties_GetTypeTitleRu(sProperties[slot][E_PROP_TYPE], typeName, sizeof(typeName));
    format(caption, sizeof(caption),
        "{FFC800}%s #%d {FFFFFF}| Property", typeName, property_db_id);

    ShowPlayerDialog(playerid, DIALOG_PROPERTY_MAIN, DIALOG_STYLE_LIST, caption, body,
        "Select", "Close");
    return 1;
}

static stock Internal_ShowPropertyInfo(playerid, property_db_id)
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        return 0;
    }

    new typeName[PROPERTY_TYPE_NAME_LEN], priceStr[32], rentStr[32], debtStr[32], ownerText[64];
    Properties_GetTypeTitleRu(sProperties[slot][E_PROP_TYPE], typeName, sizeof(typeName));
    Utils_FormatMoney(sProperties[slot][E_PROP_PRICE_USD], priceStr);
    Utils_FormatMoney(sProperties[slot][E_PROP_RENT_PER_DAY_USD], rentStr);
    Utils_FormatMoney(sProperties[slot][E_PROP_UTILITY_DEBT_USD], debtStr);

    if (sProperties[slot][E_PROP_OWNERSHIP] == PROPERTY_OWN_PRIVATE)
    {
        if (sProperties[slot][E_PROP_IS_RENTED])
            format(ownerText, sizeof(ownerText), "rented by character #%d", sProperties[slot][E_PROP_OWNER_CHAR_ID]);
        else
            format(ownerText, sizeof(ownerText), "owned by character #%d", sProperties[slot][E_PROP_OWNER_CHAR_ID]);
    }
    else if (sProperties[slot][E_PROP_OWNERSHIP] == PROPERTY_OWN_STATE_FOR_RENT)
    {
        format(ownerText, sizeof(ownerText), "government lease");
    }
    else
    {
        format(ownerText, sizeof(ownerText), "government sale");
    }

    new body[896];
    format(body, sizeof(body),
        "{FFC800}Object type:{FFFFFF} %s\n" \
        "{FFC800}Status:{FFFFFF} %s\n" \
        "{FFC800}Purchase price:{FFFFFF} %s\n" \
        "{FFC800}Rent per day:{FFFFFF} %s\n" \
        "{FFC800}Utility debt:{FFFFFF} %s\n" \
        "{FFC800}Communications:{FFFFFF} %s\n" \
        "{FFC800}Castle:{FFFFFF} difficulty %d, %s\n" \
        "{FFC800}Garage:{FFFFFF} %d spaces\n" \
        "{FFC800}Input:{FFFFFF} %.1f, %.1f, %.1f",
        typeName, ownerText, priceStr, rentStr, debtStr,
        sProperties[slot][E_PROP_UTILITIES_ACTIVE] ? ("connected") : ("disconnected for debt"),
        sProperties[slot][E_PROP_LOCK_LEVEL],
        sProperties[slot][E_PROP_IS_LOCKED] ? ("locked") : ("open"),
        sProperties[slot][E_PROP_GARAGE_CAPACITY],
        sProperties[slot][E_PROP_EXT_X],
        sProperties[slot][E_PROP_EXT_Y],
        sProperties[slot][E_PROP_EXT_Z]);

    ShowPlayerDialog(playerid, DIALOG_PROPERTY_INFO, DIALOG_STYLE_MSGBOX,
        "{FFC800}Object information", body, "Back", "Close");
    return 1;
}

static stock bool:Internal_PlayerCanAfford(playerid, amount)
{
    if (Banking_GetBalance(playerid) >= amount)
    {
        return true;
    }
    return (Character_GetPhysicalCashUsd(playerid) >= amount);
}

static stock bool:Internal_ChargePlayer(playerid, amount, const reason[])
{
    if (amount <= 0)
    {
        return true;
    }
    if (Banking_DebitAccount(playerid, amount, reason))
    {
        return true;
    }
    return Character_RemovePhysicalCashUsd(playerid, amount);
}

static stock Internal_AcquireProperty(playerid, property_db_id, bool:rent)
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        return 0;
    }
    if (sProperties[slot][E_PROP_OWNERSHIP] == PROPERTY_OWN_PRIVATE)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The property is already privately owned.");
        return 0;
    }

    new cost = rent ? sProperties[slot][E_PROP_RENT_PER_DAY_USD] : sProperties[slot][E_PROP_PRICE_USD];
    if (!rent &&
        (sProperties[slot][E_PROP_TYPE] == PROPERTY_TYPE_COMMERCIAL ||
         sProperties[slot][E_PROP_TYPE] == PROPERTY_TYPE_WAREHOUSE) &&
        Roles_HasPerk(Character_GetRoleId(playerid), PERK_CORP_DISCOUNT_25))
    {
        cost = cost - ((cost * 25) / 100);
    }
    if (cost <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "The cost of the object has not been determined.");
        return 0;
    }
    if (!Internal_PlayerCanAfford(playerid, cost))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "There are not enough funds to decorate the property.");
        return 0;
    }
    if (!Internal_ChargePlayer(playerid, cost, "Buying or renting property"))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to pay for the transaction.");
        return 0;
    }

    sProperties[slot][E_PROP_OWNERSHIP] = PROPERTY_OWN_PRIVATE;
    sProperties[slot][E_PROP_OWNER_CHAR_ID] = Character_GetId(playerid);
    sProperties[slot][E_PROP_OWNER_ORG_ID] = 0;
    sProperties[slot][E_PROP_UTILITY_DEBT_USD] = 0;
    sProperties[slot][E_PROP_UTILITIES_ACTIVE] = true;
    sProperties[slot][E_PROP_IS_RENTED] = rent;
    sProperties[slot][E_PROP_IS_LOCKED] = false;
    Internal_UpdatePropertyDb(slot);
    Internal_RefreshLabel(property_db_id);
    Internal_IssuePropertyKey(playerid, property_db_id);

    new typeName[PROPERTY_TYPE_NAME_LEN], costStr[32], msg[256];
    Properties_GetTypeTitleRu(sProperties[slot][E_PROP_TYPE], typeName, sizeof(typeName));
    Utils_FormatMoney(cost, costStr);
    format(msg, sizeof(msg),
        "The transaction is completed: %s #%d %s for %s. The keys are in inventory.",
        typeName, property_db_id, rent ? ("rented") : ("purchased"), costStr);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    Audit_Log(Character_GetId(playerid),
        rent ? "PROPERTY_RENT" : "PROPERTY_BUY",
        "BANK", "PROPERTY", 0, cost,
        rent ? "Renting a property" : "Purchasing a property");
    return 1;
}

static stock Internal_EnterProperty(playerid, property_db_id)
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        return 0;
    }
    if (sProperties[slot][E_PROP_IS_LOCKED] && !Internal_PlayerHasPropertyKeyOrOwner(playerid, property_db_id))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "The door is locked. You need a key, lockpicking (/lockpick) or knocking down the door.");
        return 0;
    }

    sPropertyInsideDbId[playerid] = property_db_id;
    Utils_SetPlayerPos(playerid,
        sProperties[slot][E_PROP_INT_X],
        sProperties[slot][E_PROP_INT_Y],
        sProperties[slot][E_PROP_INT_Z]);
    SetPlayerInterior(playerid, sProperties[slot][E_PROP_INTERIOR_ID]);
    SetPlayerVirtualWorld(playerid, sProperties[slot][E_PROP_VIRTUAL_WORLD]);
    SetCameraBehindPlayer(playerid);

    new typeName[PROPERTY_TYPE_NAME_LEN], msg[192];
    Properties_GetTypeTitleRu(sProperties[slot][E_PROP_TYPE], typeName, sizeof(typeName));
    format(msg, sizeof(msg), "You have entered the object \"%s #%d\".", typeName, property_db_id);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    return 1;
}

static stock Internal_ExitProperty(playerid)
{
    new const propertyDbId = sPropertyInsideDbId[playerid];
    if (propertyDbId <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "You are not inside the property.");
        return 0;
    }
    new const slot = Properties_FindByDbId(propertyDbId);
    if (slot < 0)
    {
        sPropertyInsideDbId[playerid] = 0;
        return 0;
    }

    Utils_SetPlayerPos(playerid,
        sProperties[slot][E_PROP_EXT_X],
        sProperties[slot][E_PROP_EXT_Y],
        sProperties[slot][E_PROP_EXT_Z]);
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    SetCameraBehindPlayer(playerid);
    sPropertyInsideDbId[playerid] = 0;
    SendClientMessage(playerid, COLOR_UI_INFO, "You went outside.");
    return 1;
}

static stock Internal_OpenPropertyStorage(playerid, property_db_id)
{
    if (sPropertyInsideDbId[playerid] != property_db_id)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Storage is only accessible within the object.");
        return 0;
    }
    if (!Internal_PlayerHasPropertyKeyOrOwner(playerid, property_db_id))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "You do not have access to this object's storage.");
        return 0;
    }

    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        return 0;
    }
    new storageSlot = sProperties[slot][E_PROP_STORAGE_SLOT];
    if (!Storage_IsValidSlot(storageSlot))
    {
        storageSlot = Storage_FindByDbId(sProperties[slot][E_PROP_STORAGE_DB_ID]);
        sProperties[slot][E_PROP_STORAGE_SLOT] = storageSlot;
    }
    if (!Storage_IsValidSlot(storageSlot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Object storage is unavailable.");
        return 0;
    }

    Dialogs_OpenExternalContainer(playerid, storageSlot);
    return 1;
}

static stock Internal_PayUtilities(playerid, property_db_id)
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        return 0;
    }
    if (!Internal_PlayerHasPropertyKeyOrOwner(playerid, property_db_id))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Only the owner or tenant can pay the bills.");
        return 0;
    }

    new const debt = sProperties[slot][E_PROP_UTILITY_DEBT_USD];
    if (debt <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "There is no debt for utility services.");
        if (!sProperties[slot][E_PROP_UTILITIES_ACTIVE])
        {
            sProperties[slot][E_PROP_UTILITIES_ACTIVE] = true;
            Internal_UpdatePropertyDb(slot);
            SendClientMessage(playerid, COLOR_UI_SUCCESS, "Communications are connected again.");
        }
        return 1;
    }
    if (!Internal_PlayerCanAfford(playerid, debt))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "There are insufficient funds to pay off the debt.");
        return 0;
    }
    if (!Internal_ChargePlayer(playerid, debt, "Payment of utilities"))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to pay utilities.");
        return 0;
    }

    sProperties[slot][E_PROP_UTILITY_DEBT_USD] = 0;
    sProperties[slot][E_PROP_UTILITIES_ACTIVE] = true;
    Internal_UpdatePropertyDb(slot);

    new debtStr[32], msg[192];
    Utils_FormatMoney(debt, debtStr);
    format(msg, sizeof(msg), "The utility debt %s has been repaid. Communications are connected.", debtStr);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    Audit_Log(Character_GetId(playerid), "PROPERTY_UTILITIES", "BANK", "PROPERTY", 0, debt,
        "Payment of utilities for the property");
    return 1;
}

static stock Internal_ConfiscateProperty(slot)
{
    if (slot < 0 || slot >= MAX_PROPERTIES || !sProperties[slot][E_PROP_VALID])
    {
        return 0;
    }

    new const oldOwner = sProperties[slot][E_PROP_OWNER_CHAR_ID];
    new const propertyDbId = sProperties[slot][E_PROP_DB_ID];
    Vehicle_ReleaseGarage(propertyDbId,
        sProperties[slot][E_PROP_EXT_X],
        sProperties[slot][E_PROP_EXT_Y],
        sProperties[slot][E_PROP_EXT_Z],
        sProperties[slot][E_PROP_EXT_A]);
    sProperties[slot][E_PROP_OWNERSHIP] = (sProperties[slot][E_PROP_RENT_PER_DAY_USD] > 0)
        ? PROPERTY_OWN_STATE_FOR_RENT
        : PROPERTY_OWN_STATE_FOR_SALE;
    sProperties[slot][E_PROP_OWNER_CHAR_ID] = 0;
    sProperties[slot][E_PROP_OWNER_ORG_ID] = 0;
    sProperties[slot][E_PROP_UTILITY_DEBT_USD] = 0;
    sProperties[slot][E_PROP_UTILITIES_ACTIVE] = true;
    sProperties[slot][E_PROP_IS_LOCKED] = true;
    sProperties[slot][E_PROP_IS_RENTED] = false;
    Internal_UpdatePropertyDb(slot);
    Internal_RefreshLabel(propertyDbId);

    foreach (new playerid : Player)
    {
        if (Character_IsLoaded(playerid) && Character_GetId(playerid) == oldOwner)
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "Your property has been confiscated by the state for long-term failure to pay utility bills.");
            break;
        }
    }

    Audit_Log(oldOwner, "PROPERTY_CONFISCATE", "PROPERTY", "STATE", 0, 0,
        "State confiscation of an object for debts");
    return 1;
}

// =============================================================================
//  ¿ƒÃ»Õ»—“–¿“»¬ÕŒ≈ ”œ–¿¬À≈Õ»≈ Õ≈ƒ¬»∆»ÃŒ—“‹ﬁ (‘‡Á‡ 10)
// =============================================================================

stock Properties_GetOwnerCharId(property_db_id)
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        return 0;
    }
    return sProperties[slot][E_PROP_OWNER_CHAR_ID];
}

stock Properties_GetTypeNameRu(property_db_id, output[], len = sizeof(output))
{
    output[0] = EOS;
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        return 0;
    }
    return Properties_GetTypeTitleRu(sProperties[slot][E_PROP_TYPE], output, len);
}

stock bool:Properties_AdminAssign(property_db_id, owner_char_id)
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0 || owner_char_id <= 0)
    {
        return false;
    }

    sProperties[slot][E_PROP_OWNERSHIP] = PROPERTY_OWN_PRIVATE;
    sProperties[slot][E_PROP_OWNER_CHAR_ID] = owner_char_id;
    sProperties[slot][E_PROP_OWNER_ORG_ID] = 0;
    sProperties[slot][E_PROP_UTILITY_DEBT_USD] = 0;
    sProperties[slot][E_PROP_UTILITIES_ACTIVE] = true;
    sProperties[slot][E_PROP_IS_RENTED] = false;
    sProperties[slot][E_PROP_IS_LOCKED] = false;
    Internal_UpdatePropertyDb(slot);
    Internal_RefreshLabel(property_db_id);

    foreach (new playerid : Player)
    {
        if (Character_IsLoaded(playerid) && Character_GetId(playerid) == owner_char_id)
        {
            Internal_IssuePropertyKey(playerid, property_db_id);
            break;
        }
    }
    return true;
}

stock bool:Properties_AdminClear(property_db_id)
{
    new const slot = Properties_FindByDbId(property_db_id);
    if (slot < 0)
    {
        return false;
    }

    Vehicle_ReleaseGarage(property_db_id,
        sProperties[slot][E_PROP_EXT_X],
        sProperties[slot][E_PROP_EXT_Y],
        sProperties[slot][E_PROP_EXT_Z],
        sProperties[slot][E_PROP_EXT_A]);
    sProperties[slot][E_PROP_OWNERSHIP] = (sProperties[slot][E_PROP_RENT_PER_DAY_USD] > 0)
        ? PROPERTY_OWN_STATE_FOR_RENT
        : PROPERTY_OWN_STATE_FOR_SALE;
    sProperties[slot][E_PROP_OWNER_CHAR_ID] = 0;
    sProperties[slot][E_PROP_OWNER_ORG_ID] = 0;
    sProperties[slot][E_PROP_UTILITY_DEBT_USD] = 0;
    sProperties[slot][E_PROP_UTILITIES_ACTIVE] = true;
    sProperties[slot][E_PROP_IS_LOCKED] = true;
    sProperties[slot][E_PROP_IS_RENTED] = false;
    Internal_UpdatePropertyDb(slot);
    Internal_RefreshLabel(property_db_id);
    return true;
}

stock Properties_GetNearestDbId(playerid, Float:radius)
{
    new propertyDbId = 0;
    if (Properties_GetNearestProperty(playerid, radius, propertyDbId))
    {
        return propertyDbId;
    }
    return 0;
}

static stock Internal_RunPropertyBilling()
{
    foreach (new slot : PropertyIter)
    {
        if (!sProperties[slot][E_PROP_VALID] || sProperties[slot][E_PROP_OWNERSHIP] != PROPERTY_OWN_PRIVATE)
        {
            continue;
        }

        new const utility = Internal_GetUtilityHourlyUsd(sProperties[slot][E_PROP_TYPE]);
        new const rent = sProperties[slot][E_PROP_IS_RENTED]
            ? (sProperties[slot][E_PROP_RENT_PER_DAY_USD] / PROPERTY_RENT_FRACTION_HOURS)
            : 0;
        sProperties[slot][E_PROP_UTILITY_DEBT_USD] += utility + rent;

        if (sProperties[slot][E_PROP_UTILITY_DEBT_USD] > PROPERTY_UTILITY_CONFISCATE_LIMIT_USD)
        {
            Internal_ConfiscateProperty(slot);
            continue;
        }

        if (sProperties[slot][E_PROP_UTILITY_DEBT_USD] > PROPERTY_UTILITY_DISCONNECT_LIMIT_USD &&
            sProperties[slot][E_PROP_UTILITIES_ACTIVE])
        {
            sProperties[slot][E_PROP_UTILITIES_ACTIVE] = false;
            Internal_UpdatePropertyDb(slot);

            foreach (new playerid : Player)
            {
                if (Character_IsLoaded(playerid) &&
                    Character_GetId(playerid) == sProperties[slot][E_PROP_OWNER_CHAR_ID])
                {
                    SendClientMessage(playerid, COLOR_UI_ERROR,
                        "Utilities turned off electricity and water due to debt. Pay your invoice: /property.");
                    break;
                }
            }
        }

        Internal_UpdatePropertyDb(slot);
    }
}

// =============================================================================
//  5. œ”¡À»◊Õ¿ﬂ œ–Œ¬≈– ¿ ¬«ÀŒÃ¿ ƒ¬≈–≈… (‚˚Á˚‚‡ÂÚÒˇ ËÁ /lockpick)
// =============================================================================

public bool:Properties_TryLockpickNearest(playerid)
{
    new propertyDbId = 0;
    new const slot = Properties_GetNearestProperty(playerid, PROPERTY_INTERACT_RADIUS, propertyDbId);
    if (slot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "There is no door or vehicle nearby to break into.");
        return false;
    }
    if (!sProperties[slot][E_PROP_IS_LOCKED])
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "The door to this facility is already open.");
        return false;
    }
    if (Internal_PlayerHasPropertyKeyOrOwner(playerid, propertyDbId))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "You have the key: no hacking required.");
        return false;
    }

    new chance = 18 + (Skills_Get(playerid, SKILL_LOCKPICKING) / 14);
    if (Roles_HasPerk(Character_GetRoleId(playerid), PERK_LOCKPICK_BONUS_35))
    {
        chance += 35;
    }
    chance -= (sProperties[slot][E_PROP_LOCK_LEVEL] * 5);
    if (chance > 90) chance = 90;
    if (chance < 5) chance = 5;

    if (random(100) < chance)
    {
        sProperties[slot][E_PROP_IS_LOCKED] = false;
        Internal_UpdatePropertyDb(slot);
        Skills_Add(playerid, SKILL_LOCKPICKING, 2);
        SendClientMessage(playerid, COLOR_UI_SUCCESS,
            "The door lock has been opened! You can get inside with the /property command.");
        Audit_Log(Character_GetId(playerid), "PROPERTY_LOCKPICK", "PROPERTY", "CHARACTER",
            0, 1, "Successfully opening a door lock");
        return true;
    }

    Forensics_CreateLockpickScratch(Character_GetId(playerid),
        sProperties[slot][E_PROP_EXT_X],
        sProperties[slot][E_PROP_EXT_Y],
        sProperties[slot][E_PROP_EXT_Z],
        0, 0);
    Skills_Add(playerid, SKILL_LOCKPICKING, 1);
    SendClientMessage(playerid, COLOR_UI_ERROR,
        "The lock did not budge, and characteristic scratches remained on the door.");
    return false;
}

// =============================================================================
//  6. ƒ»¿ÀŒ√» »  ŒÃ¿Õƒ€
// =============================================================================

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused inputtext
    switch (dialogid)
    {
        case DIALOG_PROPERTY_MAIN:
        {
            if (!response || listitem < 0 || listitem >= sPropertyMenuActionCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const E_PROPERTY_MENU_ACTION:action = sPropertyMenuAction[playerid][listitem];
            new const propertyDbId = sPropertyPendingDbId[playerid];
            switch (action)
            {
                case PROPERTY_MENU_NONE:
                {
                    return Y_HOOKS_BREAK_RETURN_1;
                }
                case PROPERTY_MENU_INFO:
                {
                    Internal_ShowPropertyInfo(playerid, propertyDbId);
                }
                case PROPERTY_MENU_ENTER:
                {
                    Internal_EnterProperty(playerid, propertyDbId);
                }
                case PROPERTY_MENU_EXIT:
                {
                    Internal_ExitProperty(playerid);
                }
                case PROPERTY_MENU_BUY:
                {
                    new const slot = Properties_FindByDbId(propertyDbId);
                    if (slot < 0)
                    {
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    new priceStr[32];
                    Utils_FormatMoney(sProperties[slot][E_PROP_PRICE_USD], priceStr);
                    new body[256];
                    format(body, sizeof(body),
                        "Do you want to buy an object for %s?\nAfter the purchase, the keys will be issued to the inventory.",
                        priceStr);
                    sPropertyConfirmAction[playerid] = PROPERTY_CONFIRM_BUY;
                    sPropertyPendingDbId[playerid] = propertyDbId;
                    ShowPlayerDialog(playerid, DIALOG_PROPERTY_CONFIRM, DIALOG_STYLE_MSGBOX,
                        "{FFC800}Purchase Confirmation", body, "Buy", "Cancel");
                }
                case PROPERTY_MENU_RENT:
                {
                    new const slot = Properties_FindByDbId(propertyDbId);
                    if (slot < 0)
                    {
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    new rentStr[32];
                    Utils_FormatMoney(sProperties[slot][E_PROP_RENT_PER_DAY_USD], rentStr);
                    new body[256];
                    format(body, sizeof(body),
                        "The rent of the object will be %s per day.\nThe first payment is debited immediately.",
                        rentStr);
                    sPropertyConfirmAction[playerid] = PROPERTY_CONFIRM_RENT;
                    sPropertyPendingDbId[playerid] = propertyDbId;
                    ShowPlayerDialog(playerid, DIALOG_PROPERTY_CONFIRM, DIALOG_STYLE_MSGBOX,
                        "{FFC800}Rental confirmation", body, "Rent", "Cancel");
                }
                case PROPERTY_MENU_STORAGE:
                {
                    Internal_OpenPropertyStorage(playerid, propertyDbId);
                }
                case PROPERTY_MENU_PAY_UTILS:
                {
                    Internal_PayUtilities(playerid, propertyDbId);
                }
                case PROPERTY_MENU_LOCK:
                {
                    new const slot = Properties_FindByDbId(propertyDbId);
                    if (slot < 0)
                    {
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    if (!Internal_PlayerHasPropertyKeyOrOwner(playerid, propertyDbId))
                    {
                        SendClientMessage(playerid, COLOR_UI_ERROR, "To operate a lock you need a key or possession.");
                        return Y_HOOKS_BREAK_RETURN_1;
                    }
                    sProperties[slot][E_PROP_IS_LOCKED] = !sProperties[slot][E_PROP_IS_LOCKED];
                    Internal_UpdatePropertyDb(slot);
                    if (sProperties[slot][E_PROP_IS_LOCKED])
                        SendClientMessage(playerid, COLOR_UI_SUCCESS, "The door is locked.");
                    else
                        SendClientMessage(playerid, COLOR_UI_SUCCESS, "The door is unlocked.");
                }
                case PROPERTY_MENU_GARAGE:
                {
                    SendClientMessage(playerid, COLOR_UI_INFO,
                        "For a garage, use /vpark - place vehicles, /vunpark - drive vehicles out.");
                }
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_PROPERTY_CONFIRM:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new const propertyDbId = sPropertyPendingDbId[playerid];
            new const E_PROPERTY_CONFIRM_ACTION:action = sPropertyConfirmAction[playerid];
            sPropertyConfirmAction[playerid] = PROPERTY_CONFIRM_NONE;
            if (action == PROPERTY_CONFIRM_BUY)
            {
                Internal_AcquireProperty(playerid, propertyDbId, false);
            }
            else if (action == PROPERTY_CONFIRM_RENT)
            {
                Internal_AcquireProperty(playerid, propertyDbId, true);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_PROPERTY_INFO:
        {
            if (response)
            {
                Internal_OpenPropertyMenu(playerid, sPropertyPendingDbId[playerid]);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_1;
}

hook OnPlayerConnect(playerid)
{
    sPropertyMenuActionCount[playerid] = 0;
    sPropertyPendingDbId[playerid] = 0;
    sPropertyConfirmAction[playerid] = PROPERTY_CONFIRM_NONE;
    sPropertyInsideDbId[playerid] = 0;
    sPropertyLastCommandTick[playerid] = 0;
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    sPropertyMenuActionCount[playerid] = 0;
    sPropertyPendingDbId[playerid] = 0;
    sPropertyInsideDbId[playerid] = 0;
    return 1;
}

hook OnPlayerSpawn(playerid)
{
    sPropertyInsideDbId[playerid] = 0;
    if (!Character_IsLoaded(playerid) || !IsPlayerConnected(playerid))
    {
        return 1;
    }

    // ¬ÓÒÒÚ‡ÌÓ‚ÎÂÌËÂ ÒÓÒÚÓˇÌËˇ ÔÓÒÎÂ ÔÂÂÁ‡ıÓ‰‡ ‚ÌÛÚË ËÌÚÂ¸Â‡ ÌÂ‰‚ËÊËÏÓÒÚË
    new const vw = GetPlayerVirtualWorld(playerid);
    if (vw < PROPERTY_VIRTUAL_WORLD_BASE)
    {
        return 1;
    }

    foreach (new slot : PropertyIter)
    {
        if (!sProperties[slot][E_PROP_VALID])
        {
            continue;
        }
        if (sProperties[slot][E_PROP_VIRTUAL_WORLD] == vw &&
            sProperties[slot][E_PROP_INTERIOR_ID] == GetPlayerInterior(playerid))
        {
            sPropertyInsideDbId[playerid] = sProperties[slot][E_PROP_DB_ID];
            SendClientMessage(playerid, COLOR_UI_INFO,
                "You are inside the property. To exit, use /property.");
            break;
        }
    }
    return 1;
}

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_PROPERTIES; i++)
    {
        Internal_ResetPropertySlot(i);
    }
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        sPropertyMenuActionCount[i] = 0;
        sPropertyPendingDbId[i] = 0;
        sPropertyConfirmAction[i] = PROPERTY_CONFIRM_NONE;
        sPropertyInsideDbId[i] = 0;
        sPropertyLastCommandTick[i] = 0;
    }
    sPropertyBillingCounter = 0;

    Internal_LoadPropertiesSync();
    printf("%s [Entities/Properties] Loaded property entities: %d.",
        SERVER_LOG_PREFIX, Iter_Count(PropertyIter));
    return 1;
}

task Tick_PropertyBilling[60000]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }
    sPropertyBillingCounter++;
    if (sPropertyBillingCounter < (PROPERTY_BILLING_INTERVAL_SECONDS / 60))
    {
        return;
    }
    sPropertyBillingCounter = 0;
    Internal_RunPropertyBilling();
}

CMD:property(playerid, params[])
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

    if (sPropertyInsideDbId[playerid] > 0)
    {
        Internal_OpenPropertyMenu(playerid, sPropertyInsideDbId[playerid]);
        return 1;
    }

    new propertyDbId = 0;
    new const slot = Properties_GetNearestProperty(playerid, PROPERTY_INTERACT_RADIUS, propertyDbId);
    if (slot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_INFO,
            "There is no property nearby. Approach the door or find the object using the 3D marker.");
        return 1;
    }

    Internal_OpenPropertyMenu(playerid, propertyDbId);
    return 1;
}
alias:property("prop");

CMD:payutils(playerid, params[])
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

    new propertyDbId = sPropertyInsideDbId[playerid];
    if (propertyDbId <= 0)
    {
        new const slot = Properties_GetNearestProperty(playerid, PROPERTY_INTERACT_RADIUS, propertyDbId);
        if (slot < 0)
        {
            SendClientMessage(playerid, COLOR_UI_ERROR, "Approach the property.");
            return 1;
        }
    }
    Internal_PayUtilities(playerid, propertyDbId);
    return 1;
}

CMD:kickdoor(playerid, params[])
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
    if (Character_GetRoleId(playerid) != ROLE_ID_EX_SWAT)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Only a former SWAT commando can knock down doors with one blow.");
        return 1;
    }

    new propertyDbId = 0;
    new const slot = Properties_GetNearestProperty(playerid, PROPERTY_INTERACT_RADIUS, propertyDbId);
    if (slot < 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "There is no property door nearby.");
        return 1;
    }
    if (!sProperties[slot][E_PROP_IS_LOCKED])
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "The door is already open.");
        return 1;
    }

    sProperties[slot][E_PROP_IS_LOCKED] = false;
    Internal_UpdatePropertyDb(slot);
    SendClientMessage(playerid, COLOR_UI_SUCCESS,
        "You knocked down the door with one blow! The facility is open for entry.");
    Audit_Log(Character_GetId(playerid), "PROPERTY_KICK_DOOR", "CHARACTER", "PROPERTY", 0, 1,
        "Knocking down a property door as a SWAT");
    return 1;
}

CMD:plock(playerid, params[])
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

    new propertyDbId = sPropertyInsideDbId[playerid];
    if (propertyDbId <= 0)
    {
        new const slot = Properties_GetNearestProperty(playerid, PROPERTY_INTERACT_RADIUS, propertyDbId);
        if (slot < 0)
        {
            SendClientMessage(playerid, COLOR_UI_ERROR, "Approach the property.");
            return 1;
        }
    }
    if (!Internal_PlayerHasPropertyKeyOrOwner(playerid, propertyDbId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "To operate a lock you need a key or possession.");
        return 1;
    }

    new const slot = Properties_FindByDbId(propertyDbId);
    if (slot < 0)
    {
        return 1;
    }
    sProperties[slot][E_PROP_IS_LOCKED] = !sProperties[slot][E_PROP_IS_LOCKED];
    Internal_UpdatePropertyDb(slot);
    if (sProperties[slot][E_PROP_IS_LOCKED])
        SendClientMessage(playerid, COLOR_UI_SUCCESS, "The facility door is locked.");
    else
        SendClientMessage(playerid, COLOR_UI_SUCCESS, "The facility door is unlocked.");
    return 1;
}

CMD:propertykey(playerid, params[])
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

    new propertyDbId = sPropertyInsideDbId[playerid];
    if (propertyDbId <= 0)
    {
        new const slot = Properties_GetNearestProperty(playerid, PROPERTY_INTERACT_RADIUS, propertyDbId);
        if (slot < 0)
        {
            SendClientMessage(playerid, COLOR_UI_ERROR, "Approach the property.");
            return 1;
        }
    }
    if (!Properties_IsOwner(playerid, propertyDbId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Only the owner can order a duplicate key.");
        return 1;
    }
    if (Character_GetPhysicalCashUsd(playerid) < PROPERTY_KEY_COPY_COST_USD)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Insufficient cash for duplicate keys.");
        return 1;
    }
    if (!Character_RemovePhysicalCashUsd(playerid, PROPERTY_KEY_COPY_COST_USD))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Failed to pay for duplicate keys.");
        return 1;
    }
    if (!Internal_IssuePropertyKey(playerid, propertyDbId))
    {
        Character_AddPhysicalCashUsd(playerid, PROPERTY_KEY_COPY_COST_USD);
        SendClientMessage(playerid, COLOR_UI_ERROR, "There is no room for keys in the inventory.");
        return 1;
    }

    SendClientMessage(playerid, COLOR_UI_SUCCESS, "A duplicate of the object keys has been issued.");
    Audit_Log(Character_GetId(playerid), "PROPERTY_KEY_COPY", "CHARACTER", "PROPERTY",
        0, PROPERTY_KEY_COPY_COST_USD, "Making a duplicate of property keys");
    return 1;
}

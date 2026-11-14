/*
 * =============================================================================
 *  SAN ANDREAS RP — Криминалистика и физические улики
 *  Файл:      gamemodes/modules/systems/mod_forensics.pwn
 *  Пункт:     ROADMAP [5.4] — Система криминалистики и физических улик
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_forensics_included
    #endinput
#endif
#define _mod_forensics_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ КРИМИНАЛИСТИКИ
// =============================================================================

#define MAX_FORENSIC_EVIDENCE                   (512)
#define MAX_COLLECTED_EVIDENCE                  (32)
#define FORENSIC_SCAN_RADIUS                    (12.0)
#define FORENSIC_COLLECT_RADIUS                 (5.0)
#define FORENSIC_LABEL_DISTANCE                 (18.0)
#define FORENSIC_STREAM_DISTANCE                (90.0)
#define FORENSIC_CASING_COOLDOWN_MS             (2500)
#define FORENSIC_COMMAND_COOLDOWN_MS            (400)
#define FORENSIC_FORENSICS_SKILL_REQUIRED       (300)

#define TTL_BULLET_CASING                       (2700)
#define TTL_BLOOD_DNA                           (1800)
#define TTL_BROKEN_GLASS                        (1800)
#define TTL_LOCKPICK_SCRATCH                    (1800)
#define TTL_FINGERPRINT                         (1800)

#define EVIDENCE_INVALID_SLOT                   (-1)

#define DIALOG_FORENSICS_MENU                   (1220)
#define DIALOG_FORENSICS_SCAN                   (1221)
#define DIALOG_FORENSICS_COLLECTED              (1222)
#define DIALOG_FORENSICS_BALLISTICS             (1223)

#define FORENSIC_MAX_EVIDENCE_ROWS              (32)

#if !defined ITEM_ID_FORENSICS_KIT
    #define ITEM_ID_FORENSICS_KIT               (55)
#endif

// =============================================================================
//  2. ТИПЫ УЛИК, СТРУКТУРА ПУЛА И ИНКАПСУЛИРОВАННОЕ СОСТОЯНИЕ (static stock)
// =============================================================================

enum E_EVIDENCE_TYPE
{
    EVIDENCE_NONE = 0,
    EVIDENCE_BULLET_CASING,
    EVIDENCE_BLOOD_DNA,
    EVIDENCE_BROKEN_GLASS,
    EVIDENCE_LOCKPICK_SCRATCH,
    EVIDENCE_FINGERPRINT
};

enum E_FORENSIC_EVIDENCE_DATA
{
    bool:E_FE_VALID,
    E_EVIDENCE_TYPE:E_FE_TYPE,
    E_FE_SUSPECT_CHAR_ID,
    E_FE_WEAPON_SERIAL,
    Float:E_FE_X,
    Float:E_FE_Y,
    Float:E_FE_Z,
    E_FE_INTERIOR,
    E_FE_VW,
    E_FE_EXPIRES_AT,
    E_FE_DB_ID,
    STREAMER_TAG_3D_TEXT_LABEL:E_FE_LABEL,
    STREAMER_TAG_AREA:E_FE_AREA
};

static stock sEvidence[MAX_FORENSIC_EVIDENCE][E_FORENSIC_EVIDENCE_DATA];
new Iterator:sEvidenceIter<MAX_FORENSIC_EVIDENCE>;

static stock sCollectedSerials[MAX_PLAYERS][MAX_COLLECTED_EVIDENCE];
static stock sCollectedCount[MAX_PLAYERS];
static stock sCollectedOtherCount[MAX_PLAYERS];
static stock sLastCasingTick[MAX_PLAYERS];
static stock sLastEvidenceCommandTick[MAX_PLAYERS];
static stock bool:sBloodEvidenceCreated[MAX_PLAYERS];

static stock sEvidenceRowMap[MAX_PLAYERS][FORENSIC_MAX_EVIDENCE_ROWS];
static stock sEvidenceRowCount[MAX_PLAYERS];
static stock sForensicSqlBuffer[1024];
static stock sEvidenceGeneration[MAX_FORENSIC_EVIDENCE];

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (static stock)
// =============================================================================

static stock Internal_EvidenceTypeToString(E_EVIDENCE_TYPE:type, output[], len = sizeof(output))
{
    switch (type)
    {
        case EVIDENCE_NONE:            format(output, len, "BULLET_CASING");
        case EVIDENCE_BULLET_CASING:   format(output, len, "BULLET_CASING");
        case EVIDENCE_BLOOD_DNA:       format(output, len, "BLOOD_DNA");
        case EVIDENCE_BROKEN_GLASS:    format(output, len, "BROKEN_GLASS");
        case EVIDENCE_LOCKPICK_SCRATCH: format(output, len, "LOCKPICK_SCRATCH");
        case EVIDENCE_FINGERPRINT:     format(output, len, "FINGERPRINT");
        default:                       format(output, len, "BULLET_CASING");
    }
    return 1;
}

static stock E_EVIDENCE_TYPE:Internal_ParseEvidenceType(const typeStr[])
{
    if (!strcmp(typeStr, "BULLET_CASING", true))    return EVIDENCE_BULLET_CASING;
    if (!strcmp(typeStr, "BLOOD_DNA", true))        return EVIDENCE_BLOOD_DNA;
    if (!strcmp(typeStr, "BROKEN_GLASS", true))     return EVIDENCE_BROKEN_GLASS;
    if (!strcmp(typeStr, "LOCKPICK_SCRATCH", true)) return EVIDENCE_LOCKPICK_SCRATCH;
    if (!strcmp(typeStr, "FINGERPRINT", true))      return EVIDENCE_FINGERPRINT;
    return EVIDENCE_NONE;
}

static stock Internal_GetEvidenceTitleRu(E_EVIDENCE_TYPE:type, output[], len = sizeof(output))
{
    switch (type)
    {
        case EVIDENCE_BULLET_CASING:    format(output, len, "Стреляная гильза");
        case EVIDENCE_BLOOD_DNA:        format(output, len, "Пятно крови");
        case EVIDENCE_BROKEN_GLASS:     format(output, len, "Осколки разбитого стекла");
        case EVIDENCE_LOCKPICK_SCRATCH: format(output, len, "Царапина от отмычки");
        case EVIDENCE_FINGERPRINT:      format(output, len, "Отпечаток пальца");
        default:                        format(output, len, "Неизвестная улика");
    }
    return 1;
}

static stock Internal_GetEvidenceColor(E_EVIDENCE_TYPE:type)
{
    switch (type)
    {
        case EVIDENCE_NONE:             return 0xFFFFFFFF;
        case EVIDENCE_BULLET_CASING:    return 0xFFD24AFF;
        case EVIDENCE_BLOOD_DNA:        return 0xFF4444FF;
        case EVIDENCE_BROKEN_GLASS:     return 0x66CCFFFF;
        case EVIDENCE_LOCKPICK_SCRATCH: return 0xFFAA00FF;
        case EVIDENCE_FINGERPRINT:      return 0xC2A2DAFF;
    }
    return 0xFFFFFFFF;
}

static stock Internal_BuildEvidenceDetails(E_EVIDENCE_TYPE:type, suspect_char_id, weapon_serial, output[], len = sizeof(output))
{
    switch (type)
    {
        case EVIDENCE_BULLET_CASING:
        {
            if (weapon_serial > 0)
            {
                format(output, len, "Сер. № %d", weapon_serial);
            }
            else
            {
                format(output, len, "Серийный номер стерт");
            }
        }
        case EVIDENCE_BLOOD_DNA:
        {
            if (suspect_char_id > 0)
            {
                format(output, len, "ДНК подозреваемого #%d", suspect_char_id);
            }
            else
            {
                format(output, len, "ДНК не установлена");
            }
        }
        case EVIDENCE_LOCKPICK_SCRATCH:
        {
            if (suspect_char_id > 0)
            {
                format(output, len, "След оставлен персонажем #%d", suspect_char_id);
            }
            else
            {
                format(output, len, "След от инструмента");
            }
        }
        default:
        {
            if (suspect_char_id > 0)
            {
                format(output, len, "Подозреваемый #%d", suspect_char_id);
            }
            else
            {
                format(output, len, "Данные не установлены");
            }
        }
    }
    return 1;
}

static stock Internal_ResetEvidenceSlot(slot_id)
{
    sEvidenceGeneration[slot_id]++;
    sEvidence[slot_id][E_FE_VALID] = false;
    sEvidence[slot_id][E_FE_TYPE] = EVIDENCE_NONE;
    sEvidence[slot_id][E_FE_SUSPECT_CHAR_ID] = 0;
    sEvidence[slot_id][E_FE_WEAPON_SERIAL] = 0;
    sEvidence[slot_id][E_FE_X] = 0.0;
    sEvidence[slot_id][E_FE_Y] = 0.0;
    sEvidence[slot_id][E_FE_Z] = 0.0;
    sEvidence[slot_id][E_FE_INTERIOR] = 0;
    sEvidence[slot_id][E_FE_VW] = 0;
    sEvidence[slot_id][E_FE_EXPIRES_AT] = 0;
    sEvidence[slot_id][E_FE_DB_ID] = 0;
    sEvidence[slot_id][E_FE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
    sEvidence[slot_id][E_FE_AREA] = STREAMER_TAG_AREA:INVALID_STREAMER_ID;
}

static stock Internal_DestroyEvidenceVisuals(slot_id)
{
    if (sEvidence[slot_id][E_FE_LABEL] != STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID)
    {
        if (IsValidDynamic3DTextLabel(sEvidence[slot_id][E_FE_LABEL]))
        {
            DestroyDynamic3DTextLabel(sEvidence[slot_id][E_FE_LABEL]);
        }
        sEvidence[slot_id][E_FE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
    }

    if (sEvidence[slot_id][E_FE_AREA] != STREAMER_TAG_AREA:INVALID_STREAMER_ID)
    {
        if (IsValidDynamicArea(sEvidence[slot_id][E_FE_AREA]))
        {
            DestroyDynamicArea(sEvidence[slot_id][E_FE_AREA]);
        }
        sEvidence[slot_id][E_FE_AREA] = STREAMER_TAG_AREA:INVALID_STREAMER_ID;
    }
}

static stock Internal_SpawnEvidenceVisuals(slot_id)
{
    Internal_DestroyEvidenceVisuals(slot_id);

    new title[64];
    new details[96];
    new labelText[256];

    Internal_GetEvidenceTitleRu(sEvidence[slot_id][E_FE_TYPE], title, sizeof(title));
    Internal_BuildEvidenceDetails(
        sEvidence[slot_id][E_FE_TYPE],
        sEvidence[slot_id][E_FE_SUSPECT_CHAR_ID],
        sEvidence[slot_id][E_FE_WEAPON_SERIAL],
        details,
        sizeof(details));

    new remainingSec = sEvidence[slot_id][E_FE_EXPIRES_AT] - gettime();
    if (remainingSec < 0)
    {
        remainingSec = 0;
    }

    format(labelText, sizeof(labelText),
        "Улика: %s\n%s\nСрок хранения: %d мин.\nОсмотр: /evidence",
        title, details, (remainingSec + 59) / 60);

    sEvidence[slot_id][E_FE_LABEL] = CreateDynamic3DTextLabel(
        labelText,
        Internal_GetEvidenceColor(sEvidence[slot_id][E_FE_TYPE]),
        sEvidence[slot_id][E_FE_X],
        sEvidence[slot_id][E_FE_Y],
        sEvidence[slot_id][E_FE_Z] + 0.20,
        FORENSIC_LABEL_DISTANCE,
        INVALID_PLAYER_ID,
        INVALID_VEHICLE_ID,
        1,
        sEvidence[slot_id][E_FE_VW],
        sEvidence[slot_id][E_FE_INTERIOR],
        -1,
        FORENSIC_STREAM_DISTANCE);

    sEvidence[slot_id][E_FE_AREA] = CreateDynamicSphere(
        sEvidence[slot_id][E_FE_X],
        sEvidence[slot_id][E_FE_Y],
        sEvidence[slot_id][E_FE_Z],
        2.0,
        sEvidence[slot_id][E_FE_VW],
        sEvidence[slot_id][E_FE_INTERIOR],
        -1);

    if (sEvidence[slot_id][E_FE_AREA] != STREAMER_TAG_AREA:INVALID_STREAMER_ID)
    {
        Streamer_SetIntData(STREAMER_TYPE_AREA, sEvidence[slot_id][E_FE_AREA], E_STREAMER_EXTRA_ID, slot_id);
    }
}

static stock Internal_DestroyEvidence(slot_id, bool:deleteFromDb)
{
    if (slot_id < 0 || slot_id >= MAX_FORENSIC_EVIDENCE || !sEvidence[slot_id][E_FE_VALID])
    {
        return 0;
    }

    new const dbId = sEvidence[slot_id][E_FE_DB_ID];
    Internal_DestroyEvidenceVisuals(slot_id);
    Internal_ResetEvidenceSlot(slot_id);
    Iter_Remove(sEvidenceIter, slot_id);

    if (deleteFromDb && dbId > 0 && DB_IsConnected())
    {
        mysql_format(gMySQL, sForensicSqlBuffer, sizeof(sForensicSqlBuffer),
            "DELETE FROM `forensic_evidence` WHERE `id` = %d;",
            dbId);
        mysql_tquery(gMySQL, sForensicSqlBuffer);
    }
    return 1;
}

static stock bool:Internal_CanInvestigate(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return false;
    }
    if (Skills_Get(playerid, SKILL_FORENSICS) >= FORENSIC_FORENSICS_SKILL_REQUIRED)
    {
        return true;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        return false;
    }

    new itemSlot = Storage_GetFirstItemSlot(layer1Slot);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        if (Storage_GetItemDefId(itemSlot) == ITEM_ID_FORENSICS_KIT && Storage_GetItemAmount(itemSlot) > 0)
        {
            return true;
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }
    return false;
}

static stock Internal_AddCollectedSerial(playerid, serial)
{
    if (serial <= 0)
    {
        return 0;
    }
    for (new idx = 0; idx < sCollectedCount[playerid]; idx++)
    {
        if (sCollectedSerials[playerid][idx] == serial)
        {
            return 0;
        }
    }
    if (sCollectedCount[playerid] >= MAX_COLLECTED_EVIDENCE)
    {
        return 0;
    }
    sCollectedSerials[playerid][sCollectedCount[playerid]] = serial;
    sCollectedCount[playerid]++;
    return 1;
}

stock bool:Forensics_IsSerialCollected(playerid, serial)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || serial <= 0)
    {
        return false;
    }
    for (new idx = 0; idx < sCollectedCount[playerid]; idx++)
    {
        if (sCollectedSerials[playerid][idx] == serial)
        {
            return true;
        }
    }
    return false;
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API КРИМИНАЛИСТИКИ (Forensics_*)
// =============================================================================

stock Forensics_CreateEvidence(
    E_EVIDENCE_TYPE:type,
    suspect_char_id,
    weapon_serial,
    Float:x,
    Float:y,
    Float:z,
    interior,
    virtual_world,
    ttl_seconds = TTL_BROKEN_GLASS)
{
    if (type == EVIDENCE_NONE)
    {
        return EVIDENCE_INVALID_SLOT;
    }

    new const slot_id = Iter_Free(sEvidenceIter);
    if (slot_id == INVALID_ITERATOR_SLOT)
    {
        printf("%s [Systems/Forensics] [WARN] Пул улик MAX_FORENSIC_EVIDENCE (%d) переполнен.",
            SERVER_LOG_PREFIX, MAX_FORENSIC_EVIDENCE);
        return EVIDENCE_INVALID_SLOT;
    }

    if (ttl_seconds < 60)
    {
        ttl_seconds = 60;
    }

    Iter_Add(sEvidenceIter, slot_id);
    Internal_ResetEvidenceSlot(slot_id);
    new const generation = sEvidenceGeneration[slot_id];

    sEvidence[slot_id][E_FE_VALID] = true;
    sEvidence[slot_id][E_FE_TYPE] = type;
    sEvidence[slot_id][E_FE_SUSPECT_CHAR_ID] = (suspect_char_id > 0) ? suspect_char_id : 0;
    sEvidence[slot_id][E_FE_WEAPON_SERIAL] = (weapon_serial > 0) ? weapon_serial : 0;
    sEvidence[slot_id][E_FE_X] = x;
    sEvidence[slot_id][E_FE_Y] = y;
    sEvidence[slot_id][E_FE_Z] = z;
    sEvidence[slot_id][E_FE_INTERIOR] = interior;
    sEvidence[slot_id][E_FE_VW] = virtual_world;
    sEvidence[slot_id][E_FE_EXPIRES_AT] = gettime() + ttl_seconds;

    Internal_SpawnEvidenceVisuals(slot_id);

    if (DB_IsConnected())
    {
        new typeStr[24];
        new suspectSql[16];
        new serialSql[24];
        Internal_EvidenceTypeToString(type, typeStr, sizeof(typeStr));

        if (sEvidence[slot_id][E_FE_SUSPECT_CHAR_ID] > 0)
        {
            format(suspectSql, sizeof(suspectSql), "%d", sEvidence[slot_id][E_FE_SUSPECT_CHAR_ID]);
        }
        else
        {
            format(suspectSql, sizeof(suspectSql), "NULL");
        }

        if (sEvidence[slot_id][E_FE_WEAPON_SERIAL] > 0)
        {
            format(serialSql, sizeof(serialSql), "%d", sEvidence[slot_id][E_FE_WEAPON_SERIAL]);
        }
        else
        {
            format(serialSql, sizeof(serialSql), "NULL");
        }

        mysql_format(gMySQL, sForensicSqlBuffer, sizeof(sForensicSqlBuffer),
            "INSERT INTO `forensic_evidence` (`evidence_type`, `suspect_char_id`, `weapon_serial`, `pos_x`, `pos_y`, `pos_z`, `interior`, `virtual_world`, `expires_at`) VALUES ('%e', %s, %s, %.3f, %.3f, %.3f, %d, %d, DATE_ADD(NOW(), INTERVAL %d SECOND));",
            typeStr,
            suspectSql,
            serialSql,
            x, y, z,
            interior,
            virtual_world,
            ttl_seconds);

        mysql_tquery(gMySQL, sForensicSqlBuffer, "OnForensicEvidenceInserted", "dd", slot_id, generation);
    }

    return slot_id;
}

stock Forensics_CreateBulletCasing(suspect_char_id, weapon_serial, Float:x, Float:y, Float:z, interior, virtual_world)
{
    return Forensics_CreateEvidence(EVIDENCE_BULLET_CASING, suspect_char_id, weapon_serial,
        x, y, z, interior, virtual_world, TTL_BULLET_CASING);
}

stock Forensics_CreateBloodDna(suspect_char_id, Float:x, Float:y, Float:z, interior, virtual_world)
{
    return Forensics_CreateEvidence(EVIDENCE_BLOOD_DNA, suspect_char_id, 0,
        x, y, z, interior, virtual_world, TTL_BLOOD_DNA);
}

stock Forensics_CreateBrokenGlass(suspect_char_id, Float:x, Float:y, Float:z, interior, virtual_world)
{
    return Forensics_CreateEvidence(EVIDENCE_BROKEN_GLASS, suspect_char_id, 0,
        x, y, z, interior, virtual_world, TTL_BROKEN_GLASS);
}

stock Forensics_CreateLockpickScratch(suspect_char_id, Float:x, Float:y, Float:z, interior, virtual_world)
{
    return Forensics_CreateEvidence(EVIDENCE_LOCKPICK_SCRATCH, suspect_char_id, 0,
        x, y, z, interior, virtual_world, TTL_LOCKPICK_SCRATCH);
}

stock Forensics_CreateFingerprint(suspect_char_id, Float:x, Float:y, Float:z, interior, virtual_world)
{
    return Forensics_CreateEvidence(EVIDENCE_FINGERPRINT, suspect_char_id, 0,
        x, y, z, interior, virtual_world, TTL_FINGERPRINT);
}

stock Forensics_GetActiveCount()
{
    new count = 0;
    foreach (new slot : sEvidenceIter)
    {
        if (sEvidence[slot][E_FE_VALID])
        {
            count++;
        }
    }
    return count;
}

// =============================================================================
//  5. АСИНХРОННЫЕ SQL-КОЛБЕКИ И ЗАГРУЗКА УЛИК (forward / public / static stock)
// =============================================================================

forward OnForensicEvidenceInserted(slot_id, generation);
public OnForensicEvidenceInserted(slot_id, generation)
{
    if (slot_id < 0 || slot_id >= MAX_FORENSIC_EVIDENCE)
    {
        return 0;
    }
    if (sEvidenceGeneration[slot_id] != generation)
    {
        return 0;
    }
    if (!sEvidence[slot_id][E_FE_VALID] || sEvidence[slot_id][E_FE_DB_ID] > 0)
    {
        return 0;
    }

    new const insertedId = cache_insert_id();
    if (insertedId > 0)
    {
        sEvidence[slot_id][E_FE_DB_ID] = insertedId;
    }
    return 1;
}

static stock Internal_StartLoadActiveEvidence()
{
    if (!DB_IsConnected())
    {
        return 0;
    }

    // Обе операции выполняются асинхронно: блокирующий mysql_query во время
    // игровой сессии запрещен (AGENTS.MD, раздел 5.2).
    mysql_tquery(gMySQL, "DELETE FROM `forensic_evidence` WHERE `expires_at` <= NOW();");
    mysql_tquery(gMySQL,
        "SELECT `id`, `evidence_type`, IFNULL(`suspect_char_id`, 0) AS `suspect_char_id`, IFNULL(`weapon_serial`, 0) AS `weapon_serial`, `pos_x`, `pos_y`, `pos_z`, `interior`, `virtual_world`, GREATEST(TIMESTAMPDIFF(SECOND, NOW(), `expires_at`), 1) AS `ttl_remaining` FROM `forensic_evidence` WHERE `expires_at` > NOW() ORDER BY `id` ASC LIMIT 512;",
        "OnForensicEvidenceLoadComplete");
    return 1;
}

forward OnForensicEvidenceLoadComplete();
public OnForensicEvidenceLoadComplete()
{
    new rows = 0;
    cache_get_row_count(rows);
    if (rows <= 0)
    {
        return 1;
    }

    new loaded = 0;
    new typeStr[24];
    new ttlRemaining = 0;

    for (new row = 0; row < rows; row++)
    {
        new const slot_id = Iter_Free(sEvidenceIter);
        if (slot_id == INVALID_ITERATOR_SLOT)
        {
            break;
        }

        Iter_Add(sEvidenceIter, slot_id);
        Internal_ResetEvidenceSlot(slot_id);

        cache_get_value_name(row, "evidence_type", typeStr, sizeof(typeStr));
        cache_get_value_name_int(row, "id", sEvidence[slot_id][E_FE_DB_ID]);
        cache_get_value_name_int(row, "suspect_char_id", sEvidence[slot_id][E_FE_SUSPECT_CHAR_ID]);
        cache_get_value_name_int(row, "weapon_serial", sEvidence[slot_id][E_FE_WEAPON_SERIAL]);
        cache_get_value_name_float(row, "pos_x", sEvidence[slot_id][E_FE_X]);
        cache_get_value_name_float(row, "pos_y", sEvidence[slot_id][E_FE_Y]);
        cache_get_value_name_float(row, "pos_z", sEvidence[slot_id][E_FE_Z]);
        cache_get_value_name_int(row, "interior", sEvidence[slot_id][E_FE_INTERIOR]);
        cache_get_value_name_int(row, "virtual_world", sEvidence[slot_id][E_FE_VW]);
        cache_get_value_name_int(row, "ttl_remaining", ttlRemaining);

        sEvidence[slot_id][E_FE_VALID] = true;
        sEvidence[slot_id][E_FE_TYPE] = Internal_ParseEvidenceType(typeStr);
        sEvidence[slot_id][E_FE_EXPIRES_AT] = gettime() + ((ttlRemaining > 0) ? ttlRemaining : 60);

        Internal_SpawnEvidenceVisuals(slot_id);
        loaded++;
    }

    printf("%s [Systems/Forensics] Загружено активных улик из БД: %d.",
        SERVER_LOG_PREFIX, loaded);
    return 1;
}

// =============================================================================
//  6. ДИАЛОГИ ОСМОТРА, СБОРА И БАЛЛИСТИЧЕСКОЙ СВЕРКИ (static stock)
// =============================================================================

static stock Internal_OpenEvidenceMenu(playerid)
{
    new nearCount = 0;
    new const vw = GetPlayerVirtualWorld(playerid);
    new const interior = GetPlayerInterior(playerid);
    new Float:px = 0.0, Float:py = 0.0, Float:pz = 0.0;
    GetPlayerPos(playerid, px, py, pz);

    foreach (new slot : sEvidenceIter)
    {
        if (!sEvidence[slot][E_FE_VALID] ||
            sEvidence[slot][E_FE_VW] != vw ||
            sEvidence[slot][E_FE_INTERIOR] != interior)
        {
            continue;
        }
        if (Utils_GetDistance3D(px, py, pz,
            sEvidence[slot][E_FE_X], sEvidence[slot][E_FE_Y], sEvidence[slot][E_FE_Z]) <= FORENSIC_SCAN_RADIUS)
        {
            nearCount++;
        }
    }

    new body[512];
    format(body, sizeof(body),
        "1. Осмотреть улики поблизости (%d)\n" \
        "2. Пакет вещдоков (%d гильз, %d прочих)\n" \
        "3. Сверить серийные номера стволов",
        nearCount,
        sCollectedCount[playerid],
        sCollectedOtherCount[playerid]);

    ShowPlayerDialog(playerid, DIALOG_FORENSICS_MENU, DIALOG_STYLE_LIST,
        "Криминалистический терминал", body, "Выбрать", "Закрыть");
    return 1;
}

static stock Internal_OpenEvidenceScan(playerid)
{
    new const vw = GetPlayerVirtualWorld(playerid);
    new const interior = GetPlayerInterior(playerid);
    new Float:px = 0.0, Float:py = 0.0, Float:pz = 0.0;
    GetPlayerPos(playerid, px, py, pz);

    new body[4096];
    format(body, sizeof(body), "Улика\tРасстояние\tДанные\n");
    sEvidenceRowCount[playerid] = 0;

    foreach (new slot : sEvidenceIter)
    {
        if (sEvidenceRowCount[playerid] >= FORENSIC_MAX_EVIDENCE_ROWS)
        {
            break;
        }
        if (!sEvidence[slot][E_FE_VALID] ||
            sEvidence[slot][E_FE_VW] != vw ||
            sEvidence[slot][E_FE_INTERIOR] != interior)
        {
            continue;
        }

        new const Float:distance = Utils_GetDistance3D(px, py, pz,
            sEvidence[slot][E_FE_X], sEvidence[slot][E_FE_Y], sEvidence[slot][E_FE_Z]);
        if (distance > FORENSIC_SCAN_RADIUS)
        {
            continue;
        }

        new title[64];
        new details[96];
        new line[192];
        Internal_GetEvidenceTitleRu(sEvidence[slot][E_FE_TYPE], title, sizeof(title));
        Internal_BuildEvidenceDetails(sEvidence[slot][E_FE_TYPE],
            sEvidence[slot][E_FE_SUSPECT_CHAR_ID],
            sEvidence[slot][E_FE_WEAPON_SERIAL],
            details, sizeof(details));

        format(line, sizeof(line), "%s\t%.1f м\t%s\n", title, distance, details);
        strcat(body, line, sizeof(body));

        sEvidenceRowMap[playerid][sEvidenceRowCount[playerid]] = slot;
        sEvidenceRowCount[playerid]++;
    }

    if (sEvidenceRowCount[playerid] <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Криминалистика]: В радиусе 12 метров не обнаружено физических улик.");
        Internal_OpenEvidenceMenu(playerid);
        return 0;
    }

    ShowPlayerDialog(playerid, DIALOG_FORENSICS_SCAN, DIALOG_STYLE_TABLIST_HEADERS,
        "Осмотр места происшествия", body, "Собрать", "Назад");
    return 1;
}

static stock Internal_OpenCollectedEvidence(playerid)
{
    if (sCollectedCount[playerid] <= 0 && sCollectedOtherCount[playerid] <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_INFO,
            "[Криминалистика]: Ваш пакет вещдоков пока пуст.");
        return 0;
    }

    new body[2048];
    format(body, sizeof(body),
        "{FFC800}Пакет вещдоков:{FFFFFF}\n" \
        "• Гильз с серийными номерами: %d\n" \
        "• Прочих улик: %d\n\n" \
        "{FFC800}Серийные номера изъятых гильз:{FFFFFF}\n",
        sCollectedCount[playerid],
        sCollectedOtherCount[playerid]);

    if (sCollectedCount[playerid] <= 0)
    {
        strcat(body, "• Серийные номера не зафиксированы\n", sizeof(body));
    }
    else
    {
        for (new idx = 0; idx < sCollectedCount[playerid]; idx++)
        {
            new line[64];
            format(line, sizeof(line), "• Серийный номер: %d\n", sCollectedSerials[playerid][idx]);
            strcat(body, line, sizeof(body));
        }
    }

    strcat(body, "\n{90A4AE}Сверка с изъятыми стволами: пункт 3 главного меню.{FFFFFF}", sizeof(body));
    ShowPlayerDialog(playerid, DIALOG_FORENSICS_COLLECTED, DIALOG_STYLE_MSGBOX,
        "Пакет вещдоков", body, "Понятно", "");
    return 1;
}

static stock Internal_OpenBallisticsCheck(playerid)
{
    if (sCollectedCount[playerid] <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Криминалистика]: В пакете вещдоков нет гильз с серийными номерами для сверки.");
        return 0;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Криминалистика]: Ошибка доступа к вашему инвентарю.");
        return 0;
    }

    new body[2048];
    format(body, sizeof(body), "{FFC800}Баллистическая сверка:{FFFFFF}\n\n");

    new matches = 0;
    new checkedWeapons = 0;
    new itemSlot = Storage_GetFirstItemSlot(layer1Slot);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        new const defId = Storage_GetItemDefId(itemSlot);
        if (Item_GetGtaWeaponId(defId) > 0)
        {
            new const serial = Storage_GetItemMetaInt2(itemSlot);
            if (serial > 0)
            {
                checkedWeapons++;
                if (Forensics_IsSerialCollected(playerid, serial))
                {
                    new itemName[ITEM_DISPLAY_NAME_LEN];
                    new line[192];
                    Item_GetName(defId, itemName, sizeof(itemName));
                    format(line, sizeof(line),
                        "{FF4444}СОВПАДЕНИЕ:{FFFFFF} ствол «%s» (сер. № %d) соответствует изъятой гильзе.\n",
                        itemName, serial);
                    strcat(body, line, sizeof(body));
                    matches++;
                }
            }
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }

    if (checkedWeapons <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "[Криминалистика]: В вашем инвентаре нет оружия с читаемым серийным номером.");
        return 0;
    }

    if (matches <= 0)
    {
        strcat(body, "{66CC66}Совпадений не обнаружено.{FFFFFF}\n", sizeof(body));
    }

    new summary[96];
    format(summary, sizeof(summary), "\nПроверено стволов: %d. Совпадений: %d.", checkedWeapons, matches);
    strcat(body, summary, sizeof(body));

    ShowPlayerDialog(playerid, DIALOG_FORENSICS_BALLISTICS, DIALOG_STYLE_MSGBOX,
        "Баллистическая экспертиза", body, "Понятно", "");
    return 1;
}

static stock Internal_CollectEvidence(playerid, slot_id)
{
    if (slot_id < 0 || slot_id >= MAX_FORENSIC_EVIDENCE || !sEvidence[slot_id][E_FE_VALID])
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Криминалистика]: Улика уже недоступна.");
        return 0;
    }

    if (sEvidence[slot_id][E_FE_VW] != GetPlayerVirtualWorld(playerid) ||
        sEvidence[slot_id][E_FE_INTERIOR] != GetPlayerInterior(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Криминалистика]: Улика находится в другом измерении.");
        return 0;
    }

    new Float:px = 0.0, Float:py = 0.0, Float:pz = 0.0;
    GetPlayerPos(playerid, px, py, pz);
    if (Utils_GetDistance3D(px, py, pz,
        sEvidence[slot_id][E_FE_X], sEvidence[slot_id][E_FE_Y], sEvidence[slot_id][E_FE_Z]) > FORENSIC_COLLECT_RADIUS)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Криминалистика]: Подойдите ближе (не более 5 метров), чтобы собрать улику.");
        return 0;
    }

    new title[64];
    new details[96];
    Internal_GetEvidenceTitleRu(sEvidence[slot_id][E_FE_TYPE], title, sizeof(title));
    Internal_BuildEvidenceDetails(sEvidence[slot_id][E_FE_TYPE],
        sEvidence[slot_id][E_FE_SUSPECT_CHAR_ID],
        sEvidence[slot_id][E_FE_WEAPON_SERIAL],
        details, sizeof(details));

    new const E_EVIDENCE_TYPE:evidenceType = sEvidence[slot_id][E_FE_TYPE];
    new const suspectId = sEvidence[slot_id][E_FE_SUSPECT_CHAR_ID];
    new const serial = sEvidence[slot_id][E_FE_WEAPON_SERIAL];

    Internal_DestroyEvidence(slot_id, true);

    if (evidenceType == EVIDENCE_BULLET_CASING && serial > 0)
    {
        Internal_AddCollectedSerial(playerid, serial);
    }
    else
    {
        sCollectedOtherCount[playerid]++;
    }

    new message[224];
    format(message, sizeof(message),
        "[Криминалистика]: Вы изъяли улику «%s» (%s) в пакет вещдоков.", title, details);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, message);

    // Автоматическая сверка гильзы со стволами, находящимися при криминалисте
    if (evidenceType == EVIDENCE_BULLET_CASING && serial > 0)
    {
        new const layer1Slot = Character_GetLayer1Slot(playerid);
        if (Storage_IsValidSlot(layer1Slot))
        {
            new itemSlot = Storage_GetFirstItemSlot(layer1Slot);
            while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
            {
                new const defId = Storage_GetItemDefId(itemSlot);
                if (Item_GetGtaWeaponId(defId) > 0 && Storage_GetItemMetaInt2(itemSlot) == serial)
                {
                    new itemName[ITEM_DISPLAY_NAME_LEN];
                    Item_GetName(defId, itemName, sizeof(itemName));
                    new matchMessage[224];
                    format(matchMessage, sizeof(matchMessage),
                        "[Баллистика]: Серийный номер гильзы совпадает со стволом «%s» в вашем инвентаре!",
                        itemName);
                    SendClientMessage(playerid, COLOR_UI_ERROR, matchMessage);
                }
                itemSlot = Storage_GetNextItemSlot(itemSlot);
            }
        }
    }

    new auditDetails[255];
    format(auditDetails, sizeof(auditDetails),
        "Изъята улика '%s' (%s). Подозреваемый: %d, серийный номер: %d.",
        title, details, suspectId, serial);
    Audit_Log(Character_GetId(playerid), "EVIDENCE_COLLECT", "FORENSIC_EVIDENCE", "PLAYER_LAYER2",
        0, 1, auditDetails);

    Internal_OpenEvidenceScan(playerid);
    return 1;
}

// =============================================================================
//  7. ХУКИ СОБЫТИЙ И ТАЙМЕРЫ (y_hooks / y_timers)
// =============================================================================

hook OnPlayerConnect(playerid)
{
    sCollectedCount[playerid] = 0;
    sCollectedOtherCount[playerid] = 0;
    sLastCasingTick[playerid] = 0;
    sLastEvidenceCommandTick[playerid] = 0;
    sBloodEvidenceCreated[playerid] = false;
    sEvidenceRowCount[playerid] = 0;

    for (new idx = 0; idx < MAX_COLLECTED_EVIDENCE; idx++)
    {
        sCollectedSerials[playerid][idx] = 0;
    }
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    sCollectedCount[playerid] = 0;
    sCollectedOtherCount[playerid] = 0;
    sLastCasingTick[playerid] = 0;
    sLastEvidenceCommandTick[playerid] = 0;
    sBloodEvidenceCreated[playerid] = false;
    sEvidenceRowCount[playerid] = 0;
    return 1;
}

hook OnPlayerWeaponShot(playerid, WEAPON:weaponid, BULLET_HIT_TYPE:hittype, hitid, Float:fX, Float:fY, Float:fZ)
{
    #pragma unused hittype, hitid, fX, fY, fZ

    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }

    new const wid = _:weaponid;
    // Гильзы остаются только от огнестрела без глушителя
    if (wid < 22 || wid > 34 || wid == 23)
    {
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sLastCasingTick[playerid]) < FORENSIC_CASING_COOLDOWN_MS)
    {
        return 1;
    }

    new const itemSlot = Weapons_GetItemSlot(playerid, weaponid, true);
    if (itemSlot == INVALID_STORAGE_ITEM_SLOT)
    {
        return 1;
    }

    new const serial = Weapons_EnsureWeaponSerial(itemSlot);
    new Float:x = 0.0, Float:y = 0.0, Float:z = 0.0;
    GetPlayerPos(playerid, x, y, z);

    Forensics_CreateBulletCasing(
        Character_GetId(playerid),
        serial,
        x, y, z,
        GetPlayerInterior(playerid),
        GetPlayerVirtualWorld(playerid));

    sLastCasingTick[playerid] = nowTick;
    return 1;
}

task Forensics_SecondTask[1000]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }

    foreach (new playerid : Player)
    {
        if (!Character_IsLoaded(playerid))
        {
            continue;
        }

        new const bool:isBleeding = Medical_IsBleeding(playerid);
        if (isBleeding && !sBloodEvidenceCreated[playerid])
        {
            new Float:x = 0.0, Float:y = 0.0, Float:z = 0.0;
            GetPlayerPos(playerid, x, y, z);

            Forensics_CreateBloodDna(
                Character_GetId(playerid),
                x, y, z,
                GetPlayerInterior(playerid),
                GetPlayerVirtualWorld(playerid));

            sBloodEvidenceCreated[playerid] = true;
            SendClientMessage(playerid, COLOR_UI_WARNING,
                "[Криминалистика]: Кровотечение оставляет физический след на земле. Улика сохранится 30 минут.");
        }
        else if (!isBleeding)
        {
            sBloodEvidenceCreated[playerid] = false;
        }
    }
}

task Forensics_CleanupTask[60000]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }

    new const nowTick = gettime();
    foreach (new slot : sEvidenceIter)
    {
        if (!sEvidence[slot][E_FE_VALID])
        {
            continue;
        }
        if (sEvidence[slot][E_FE_EXPIRES_AT] <= nowTick)
        {
            Internal_DestroyEvidence(slot, true);
        }
    }

    if (DB_IsConnected())
    {
        mysql_tquery(gMySQL, "DELETE FROM `forensic_evidence` WHERE `expires_at` <= NOW();");
    }
}

// =============================================================================
//  8. КОМАНДА КРИМИНАЛИСТИЧЕСКОГО ОСМОТРА
// =============================================================================

CMD:evidence(playerid, params[])
{
    #pragma unused params

    if (!Character_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "[Криминалистика]: Ваш персонаж еще не загружен.");
        return 1;
    }

    new const nowTick = GetTickCount();
    if ((nowTick - sLastEvidenceCommandTick[playerid]) < FORENSIC_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "[Криминалистика]: Не так быстро.");
        return 1;
    }
    sLastEvidenceCommandTick[playerid] = nowTick;

    if (!Internal_CanInvestigate(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "[Криминалистика]: Для осмотра улик нужен набор криминалиста или навык «Криминалистика» не ниже 300.");
        return 1;
    }

    Internal_OpenEvidenceMenu(playerid);
    return 1;
}

alias:evidence("ev");

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused inputtext

    switch (dialogid)
    {
        case DIALOG_FORENSICS_MENU:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            switch (listitem)
            {
                case 0: Internal_OpenEvidenceScan(playerid);
                case 1: Internal_OpenCollectedEvidence(playerid);
                case 2: Internal_OpenBallisticsCheck(playerid);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_FORENSICS_SCAN:
        {
            if (!response)
            {
                Internal_OpenEvidenceMenu(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (listitem < 0 || listitem >= sEvidenceRowCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (!Internal_CanInvestigate(playerid))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "[Криминалистика]: У вас больше нет доступа к криминалистическому оборудованию.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            Internal_CollectEvidence(playerid, sEvidenceRowMap[playerid][listitem]);
            return Y_HOOKS_BREAK_RETURN_1;
        }
        case DIALOG_FORENSICS_COLLECTED, DIALOG_FORENSICS_BALLISTICS:
        {
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_0;
}

// =============================================================================
//  9. ИНИЦИАЛИЗАЦИЯ И САМОПРОВЕРКА (hook OnGameModeInit)
// =============================================================================

hook OnGameModeInit()
{
    Iter_Init(sEvidenceIter);

    for (new slot_id = 0; slot_id < MAX_FORENSIC_EVIDENCE; slot_id++)
    {
        Internal_ResetEvidenceSlot(slot_id);
    }

    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        sCollectedCount[playerid] = 0;
        sCollectedOtherCount[playerid] = 0;
        sLastCasingTick[playerid] = 0;
        sLastEvidenceCommandTick[playerid] = 0;
        sBloodEvidenceCreated[playerid] = false;
        sEvidenceRowCount[playerid] = 0;
    }

    printf("%s [Systems/Forensics] Криминалистика инициализирована (TTL гильз: %d мин.). Загрузка активных улик отложена до готовности БД.",
        SERVER_LOG_PREFIX, TTL_BULLET_CASING / 60);

    // Загрузка выполняется после завершения OnGameModeInit, когда mod_database
    // уже установил соединение с MySQL.
    defer Forensics_LoadActiveEvidenceTask();
    return 1;
}

timer Forensics_LoadActiveEvidenceTask[1000]()
{
    Internal_StartLoadActiveEvidence();
}

/*
 * =============================================================================
 *  SAN ANDREAS RP ó ÃÓ‰ÛÎ¸ ‡Û‰ËÚ‡ Ë Ô‡ÍÂÚÌÓ„Ó ÎÓ„ËÓ‚‡ÌËˇ Ú‡ÌÁ‡ÍˆËÈ
 *  ‘‡ÈÎ:      gamemodes/modules/core/mod_audit.pwn
 *  œÛÌÍÚ:     ROADMAP [1.4] ó ÃÓ‰ÛÎ¸ ‡Û‰ËÚ‡ Ë ÎÓ„Ó‚ Ú‡ÌÁ‡ÍˆËÈ (core/mod_audit.pwn)
 *   Ó‰ËÓ‚Í‡: Windows-1251 (CP1251) ·ÂÁ BOM
 * =============================================================================
 */

#if defined _mod_audit_included
    #endinput
#endif
#define _mod_audit_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1.  ŒÕ—“¿Õ“€ » œ¿–¿Ã≈“–€ œ¿ ≈“ÕŒ√Œ ¡”‘≈–¿ ¿”ƒ»“¿
// =============================================================================

#define AUDIT_BUFFER_CAPACITY                   (50)
#define AUDIT_ACTION_TYPE_LEN                   (33)
#define AUDIT_ENTITY_NAME_LEN                   (49)
#define AUDIT_DETAILS_MAX_LEN                   (256)
#define AUDIT_BATCH_QUERY_MAX_LEN               (8192)
#define AUDIT_LOCAL_FALLBACK_FILE               "audit_fallback.log"

// =============================================================================
//  2. œ≈–≈◊»—À≈Õ»ﬂ » »Õ ¿œ—”À»–Œ¬¿ÕÕ€≈ Ã¿——»¬€ —Œ—“ŒﬂÕ»ﬂ (static stock)
// =============================================================================

enum E_AUDIT_RECORD
{
    bool:E_AUDIT_USED,
    E_AUDIT_ACTOR_CHAR_ID,
    E_AUDIT_ADMIN_ACCOUNT_ID,
    E_AUDIT_TARGET_ACCOUNT_ID,
    E_AUDIT_TARGET_CHAR_ID,
    E_AUDIT_ACTION_TYPE[AUDIT_ACTION_TYPE_LEN],
    E_AUDIT_SOURCE_ENTITY[AUDIT_ENTITY_NAME_LEN],
    E_AUDIT_TARGET_ENTITY[AUDIT_ENTITY_NAME_LEN],
    E_AUDIT_ITEM_DEF_ID,
    E_AUDIT_AMOUNT,
    E_AUDIT_DETAILS[AUDIT_DETAILS_MAX_LEN],
    E_AUDIT_TIMESTAMP
};

static stock sAuditBuffer[AUDIT_BUFFER_CAPACITY][E_AUDIT_RECORD];
static stock sAuditBufferCount = 0;
static stock sTotalAuditEventsLogged = 0;
static stock sAuditBatchSqlBuffer[AUDIT_BATCH_QUERY_MAX_LEN];

// =============================================================================
//  3. ¬Õ”“–≈ÕÕ»≈ ¬—œŒÃŒ√¿“≈À‹Õ€≈ ‘”Õ ÷»» (static stock)
// =============================================================================

static stock Internal_WriteAuditFallbackLine(slot)
{
    new File:logFile = fopen(AUDIT_LOCAL_FALLBACK_FILE, io_append);
    if (!logFile)
    {
        return 0;
    }

    new line[512];
    format(line, sizeof(line),
        "[ts=%d] actor=%d | admin=%d | target_acc=%d | target_char=%d | action=%s | src=%s | dst=%s | item=%d | amount=%d | details=%s\r\n",
        sAuditBuffer[slot][E_AUDIT_TIMESTAMP],
        sAuditBuffer[slot][E_AUDIT_ACTOR_CHAR_ID],
        sAuditBuffer[slot][E_AUDIT_ADMIN_ACCOUNT_ID],
        sAuditBuffer[slot][E_AUDIT_TARGET_ACCOUNT_ID],
        sAuditBuffer[slot][E_AUDIT_TARGET_CHAR_ID],
        sAuditBuffer[slot][E_AUDIT_ACTION_TYPE],
        sAuditBuffer[slot][E_AUDIT_SOURCE_ENTITY],
        sAuditBuffer[slot][E_AUDIT_TARGET_ENTITY],
        sAuditBuffer[slot][E_AUDIT_ITEM_DEF_ID],
        sAuditBuffer[slot][E_AUDIT_AMOUNT],
        sAuditBuffer[slot][E_AUDIT_DETAILS]);

    fwrite(logFile, line);
    fclose(logFile);
    return 1;
}

static stock Internal_FlushAuditBufferToDb()
{
    if (sAuditBufferCount <= 0)
    {
        return 0;
    }

    new const countToFlush = sAuditBufferCount;

    if (!DB_IsConnected())
    {
        for (new i = 0; i < countToFlush; i++)
        {
            if (sAuditBuffer[i][E_AUDIT_USED])
            {
                Internal_WriteAuditFallbackLine(i);
                sAuditBuffer[i][E_AUDIT_USED] = false;
            }
        }
        sAuditBufferCount = 0;
        return countToFlush;
    }

    sAuditBatchSqlBuffer[0] = '\0';
    strcat(sAuditBatchSqlBuffer,
        "INSERT INTO `audit_logs` (`actor_char_id`, `admin_account_id`, `target_account_id`, `target_char_id`, `action_type`, `source_entity`, `target_entity`, `item_def_id`, `amount`, `details`) VALUES ",
        sizeof(sAuditBatchSqlBuffer));

    new rowSql[640];
    new actorSql[24];
    new adminSql[24];
    new targetAccSql[24];
    new targetCharSql[24];
    new itemSql[24];
    new appendedRows = 0;

    for (new i = 0; i < countToFlush; i++)
    {
        if (!sAuditBuffer[i][E_AUDIT_USED])
        {
            continue;
        }

        if (sAuditBuffer[i][E_AUDIT_ACTOR_CHAR_ID] > 0)
        {
            format(actorSql, sizeof(actorSql), "%d", sAuditBuffer[i][E_AUDIT_ACTOR_CHAR_ID]);
        }
        else
        {
            format(actorSql, sizeof(actorSql), "NULL");
        }

        if (sAuditBuffer[i][E_AUDIT_ADMIN_ACCOUNT_ID] > 0)
        {
            format(adminSql, sizeof(adminSql), "%d", sAuditBuffer[i][E_AUDIT_ADMIN_ACCOUNT_ID]);
        }
        else
        {
            format(adminSql, sizeof(adminSql), "NULL");
        }

        if (sAuditBuffer[i][E_AUDIT_TARGET_ACCOUNT_ID] > 0)
        {
            format(targetAccSql, sizeof(targetAccSql), "%d", sAuditBuffer[i][E_AUDIT_TARGET_ACCOUNT_ID]);
        }
        else
        {
            format(targetAccSql, sizeof(targetAccSql), "NULL");
        }

        if (sAuditBuffer[i][E_AUDIT_TARGET_CHAR_ID] > 0)
        {
            format(targetCharSql, sizeof(targetCharSql), "%d", sAuditBuffer[i][E_AUDIT_TARGET_CHAR_ID]);
        }
        else
        {
            format(targetCharSql, sizeof(targetCharSql), "NULL");
        }

        if (sAuditBuffer[i][E_AUDIT_ITEM_DEF_ID] > 0)
        {
            format(itemSql, sizeof(itemSql), "%d", sAuditBuffer[i][E_AUDIT_ITEM_DEF_ID]);
        }
        else
        {
            format(itemSql, sizeof(itemSql), "NULL");
        }

        mysql_format(gMySQL, rowSql, sizeof(rowSql),
            "%s(%s, %s, %s, %s, '%e', '%e', '%e', %s, %d, '%e')",
            (appendedRows > 0) ? (", ") : (""),
            actorSql,
            adminSql,
            targetAccSql,
            targetCharSql,
            sAuditBuffer[i][E_AUDIT_ACTION_TYPE],
            sAuditBuffer[i][E_AUDIT_SOURCE_ENTITY],
            sAuditBuffer[i][E_AUDIT_TARGET_ENTITY],
            itemSql,
            sAuditBuffer[i][E_AUDIT_AMOUNT],
            sAuditBuffer[i][E_AUDIT_DETAILS]);

        strcat(sAuditBatchSqlBuffer, rowSql, sizeof(sAuditBatchSqlBuffer));
        sAuditBuffer[i][E_AUDIT_USED] = false;
        appendedRows++;
    }

    sAuditBufferCount = 0;

    if (appendedRows > 0)
    {
        strcat(sAuditBatchSqlBuffer, ";", sizeof(sAuditBatchSqlBuffer));
        mysql_tquery(gMySQL, sAuditBatchSqlBuffer, "OnAuditBatchInserted", "d", appendedRows);
    }

    return appendedRows;
}

// =============================================================================
//  4. œ”¡À»◊Õ€… API ÃŒƒ”Àﬂ ¿”ƒ»“¿ (Audit_*)
// =============================================================================

stock Audit_LogAdmin(
    admin_account_id,
    target_account_id,
    target_char_id,
    actor_char_id,
    const action_type[],
    const source[],
    const target[],
    item_def_id,
    amount,
    const details[])
{
    if (sAuditBufferCount >= AUDIT_BUFFER_CAPACITY)
    {
        Internal_FlushAuditBufferToDb();
    }

    new const slot = sAuditBufferCount;
    if (slot < 0 || slot >= AUDIT_BUFFER_CAPACITY)
    {
        return 0;
    }

    sAuditBuffer[slot][E_AUDIT_USED] = true;
    sAuditBuffer[slot][E_AUDIT_ACTOR_CHAR_ID] = (actor_char_id > 0) ? actor_char_id : 0;
    sAuditBuffer[slot][E_AUDIT_ADMIN_ACCOUNT_ID] = (admin_account_id > 0) ? admin_account_id : 0;
    sAuditBuffer[slot][E_AUDIT_TARGET_ACCOUNT_ID] = (target_account_id > 0) ? target_account_id : 0;
    sAuditBuffer[slot][E_AUDIT_TARGET_CHAR_ID] = (target_char_id > 0) ? target_char_id : 0;
    format(sAuditBuffer[slot][E_AUDIT_ACTION_TYPE], AUDIT_ACTION_TYPE_LEN, "%s", action_type);
    format(sAuditBuffer[slot][E_AUDIT_SOURCE_ENTITY], AUDIT_ENTITY_NAME_LEN, "%s", source);
    format(sAuditBuffer[slot][E_AUDIT_TARGET_ENTITY], AUDIT_ENTITY_NAME_LEN, "%s", target);
    sAuditBuffer[slot][E_AUDIT_ITEM_DEF_ID] = (item_def_id > 0) ? item_def_id : 0;
    sAuditBuffer[slot][E_AUDIT_AMOUNT] = amount;
    format(sAuditBuffer[slot][E_AUDIT_DETAILS], AUDIT_DETAILS_MAX_LEN, "%s", details);
    sAuditBuffer[slot][E_AUDIT_TIMESTAMP] = gettime();

    sAuditBufferCount++;
    sTotalAuditEventsLogged++;

    if (sAuditBufferCount >= AUDIT_BUFFER_CAPACITY)
    {
        Internal_FlushAuditBufferToDb();
    }
    return 1;
}

stock Audit_Log(
    actor_char_id,
    const action_type[],
    const source[],
    const target[],
    item_def_id,
    amount,
    const details[])
{
    return Audit_LogAdmin(0, 0, 0, actor_char_id, action_type, source, target, item_def_id, amount, details);
}

stock Audit_FlushBufferSync()
{
    new const flushed = Internal_FlushAuditBufferToDb();
    printf("%s [Core/Audit] The audit buffer is synchronized (records reset: %d, total for session: %d).",
        SERVER_LOG_PREFIX, flushed, sTotalAuditEventsLogged);
    return flushed;
}

stock Audit_GetTotalLoggedCount()
{
    return sTotalAuditEventsLogged;
}

// =============================================================================
//  5. ¿—»Õ’–ŒÕÕ€≈ SQL- ŒÀ¡≈ » (forward / public)
// =============================================================================

forward OnAuditBatchInserted(insertedCount);
public OnAuditBatchInserted(insertedCount)
{
    #pragma unused insertedCount
    return 1;
}

// =============================================================================
//  6. œ≈–»Œƒ»◊≈— »… “¿…Ã≈– œ¿ ≈“ÕŒ√Œ —¡–Œ—¿  ¿∆ƒ€≈ 5 —≈ ”Õƒ (y_timers)
// =============================================================================

task Tick_AuditBufferFlush[5000]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }
    if (sAuditBufferCount > 0)
    {
        Internal_FlushAuditBufferToDb();
    }
}

// =============================================================================
//  7. —»—“≈ÃÕ€≈ ’” » (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    sAuditBufferCount = 0;
    sTotalAuditEventsLogged = 0;
    for (new i = 0; i < AUDIT_BUFFER_CAPACITY; i++)
    {
        sAuditBuffer[i][E_AUDIT_USED] = false;
    }

    Audit_Log(
        0,
        "SERVER_STARTUP",
        "CORE_ENGINE",
        "AUDIT_SUBSYSTEM",
        0,
        1,
        "Initializing the SAN ANDREAS RP transaction audit subsystem"
    );

    printf("%s [Core/Audit] The audit subsystem has been initialized (batch buffer capacity: %d records / 5 sec).",
        SERVER_LOG_PREFIX, AUDIT_BUFFER_CAPACITY);
    return 1;
}

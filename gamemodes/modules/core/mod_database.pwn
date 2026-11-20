/*
 * =============================================================================
 *  SAN ANDREAS RP — Асинхронный слой СУБД MySQL и очередь паттерна Dirty-Flag
 *  Файл:      gamemodes/modules/core/mod_database.pwn
 *  Пункт:     ROADMAP [1.3, 11.3] — Асинхронный слой БД, паттерн Dirty-Flag и .env / mysql.ini
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_database_included
    #endinput
#endif
#define _mod_database_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ И ПАРАМЕТРЫ ОЧЕРЕДИ ОТЛОЖЕННОГО СОХРАНЕНИЯ (DIRTY-FLAG)
// =============================================================================

#define DB_DEFAULT_HOST                         "127.0.0.1"
#define DB_DEFAULT_USER                         "sarp_server"
#define DB_DEFAULT_PASSWORD                     "change_me_in_production"
#define DB_DEFAULT_DATABASE                     "san_andreas_rp"
#define DB_DEFAULT_PORT                         (3306)
#define DB_DEFAULT_POOL_SIZE                    (12)
#define DB_CONFIG_FILE_NAME                     "mysql.ini"

#define MAX_DIRTY_QUEUE_ENTRIES                 (1024)
// 2048 ячеек: строка UPDATE characters содержит 26 полей и при 512
// обрывалась на `interior` (SQL ERROR #1064 в OnDatabaseDirtyQueryFlushed).
#define DIRTY_QUERY_MAX_LEN                     (2048)
#define DIRTY_FLUSH_BATCH_LIMIT                 (20)

// =============================================================================
//  2. ПЕРЕЧИСЛЕНИЯ И ИНКАПСУЛИРОВАННЫЕ МАССИВЫ СОСТОЯНИЯ (static stock)
// =============================================================================

enum E_DIRTY_QUEUE_ENTRY
{
    bool:E_DIRTY_ACTIVE,
    E_DIRTY_ENTITY_TYPE:E_DIRTY_TYPE,
    E_DIRTY_ENTITY_ID,
    E_DIRTY_QUEUED_AT,
    E_DIRTY_SQL_QUERY[DIRTY_QUERY_MAX_LEN]
};

static stock sDirtyQueue[MAX_DIRTY_QUEUE_ENTRIES][E_DIRTY_QUEUE_ENTRY];
static stock Iterator:sDirtyQueueIter<MAX_DIRTY_QUEUE_ENTRIES>;
static stock bool:sDatabaseConnected = false;
static stock bool:sBatchFlushInProgress = false;

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (static stock)
// =============================================================================

static stock Internal_TrimLineEndings(str[])
{
    new len = strlen(str);
    while (len > 0 && (str[len - 1] == '\r' || str[len - 1] == '\n' || str[len - 1] == ' ' || str[len - 1] == '\t'))
    {
        str[--len] = '\0';
    }

    new start = 0;
    while (str[start] == ' ' || str[start] == '\t')
    {
        start++;
    }
    if (start > 0)
    {
        new i = 0;
        while (str[start + i] != '\0')
        {
            str[i] = str[start + i];
            i++;
        }
        str[i] = '\0';
        len = i;
    }

    if (len >= 2)
    {
        if ((str[0] == '"' && str[len - 1] == '"') || (str[0] == '\'' && str[len - 1] == '\''))
        {
            for (new j = 0; j < len - 2; j++)
            {
                str[j] = str[j + 1];
            }
            str[len - 2] = '\0';
        }
    }
}

static stock Internal_LoadDbConfigFromIni(
    host[], hostLen,
    user[], userLen,
    pass[], passLen,
    db[], dbLen,
    &port,
    &poolSize)
{
    format(host, hostLen, "%s", DB_DEFAULT_HOST);
    format(user, userLen, "%s", DB_DEFAULT_USER);
    format(pass, passLen, "%s", DB_DEFAULT_PASSWORD);
    format(db, dbLen, "%s", DB_DEFAULT_DATABASE);
    port = DB_DEFAULT_PORT;
    poolSize = MYSQL_ASYNC_POOL_THREADS;

    if (!fexist(DB_CONFIG_FILE_NAME))
    {
        return 0;
    }

    new File:cfgFile = fopen(DB_CONFIG_FILE_NAME, io_read);
    if (!cfgFile)
    {
        return 0;
    }

    new line[256];
    while (fread(cfgFile, line, sizeof(line)))
    {
        Internal_TrimLineEndings(line);
        if (line[0] == '\0' || line[0] == '#' || line[0] == ';' || line[0] == '[')
        {
            continue;
        }

        new const eqPos = strfind(line, "=", false);
        if (eqPos <= 0)
        {
            continue;
        }

        new key[64];
        new val[192];
        strmid(key, line, 0, eqPos, sizeof(key));
        strmid(val, line, eqPos + 1, strlen(line), sizeof(val));
        Internal_TrimLineEndings(key);
        Internal_TrimLineEndings(val);

        if (!strcmp(key, "hostname", true) || !strcmp(key, "host", true) || !strcmp(key, "MYSQL_HOST", true))
        {
            format(host, hostLen, "%s", val);
        }
        else if (!strcmp(key, "username", true) || !strcmp(key, "user", true) || !strcmp(key, "MYSQL_USER", true))
        {
            format(user, userLen, "%s", val);
        }
        else if (!strcmp(key, "password", true) || !strcmp(key, "pass", true) || !strcmp(key, "MYSQL_PASSWORD", true))
        {
            format(pass, passLen, "%s", val);
        }
        else if (!strcmp(key, "database", true) || !strcmp(key, "db", true) || !strcmp(key, "MYSQL_DATABASE", true))
        {
            format(db, dbLen, "%s", val);
        }
        else if (!strcmp(key, "port", true) || !strcmp(key, "server_port", true) || !strcmp(key, "MYSQL_PORT", true))
        {
            new const parsedPort = strval(val);
            if (parsedPort > 0 && parsedPort <= 65535)
            {
                port = parsedPort;
            }
        }
        else if (!strcmp(key, "pool_size", true) || !strcmp(key, "MYSQL_POOL_SIZE", true))
        {
            new const parsedPool = strval(val);
            if (parsedPool >= 1 && parsedPool <= 64)
            {
                poolSize = parsedPool;
            }
        }
    }

    fclose(cfgFile);
    return 1;
}

static stock Internal_ConnectDatabase()
{
    new host[64], user[64], pass[128], db[64];
    new port = DB_DEFAULT_PORT;
    new poolSize = MYSQL_ASYNC_POOL_THREADS;

    new const hasIniFile = Internal_LoadDbConfigFromIni(
        host, sizeof(host),
        user, sizeof(user),
        pass, sizeof(pass),
        db, sizeof(db),
        port,
        poolSize
    );

    if (hasIniFile && fexist(DB_CONFIG_FILE_NAME))
    {
        gMySQL = mysql_connect_file(DB_CONFIG_FILE_NAME);
    }

    if (!hasIniFile || gMySQL == MYSQL_INVALID_HANDLE || mysql_errno(gMySQL) != 0)
    {
        new const MySQLOpt:opt = mysql_init_options();
        if (opt != MySQLOpt:0)
        {
            mysql_set_option(opt, AUTO_RECONNECT, true);
            mysql_set_option(opt, MULTI_STATEMENTS, true);
            mysql_set_option(opt, POOL_SIZE, poolSize);
            mysql_set_option(opt, SERVER_PORT, port);
        }

        gMySQL = mysql_connect(host, user, pass, db, opt);
    }

    new const errno = mysql_errno(gMySQL);

    if (gMySQL != MYSQL_INVALID_HANDLE && errno == 0)
    {
        mysql_set_charset("cp1251", gMySQL);
        sDatabaseConnected = true;

        new activeCharset[32];
        mysql_get_charset(activeCharset, sizeof(activeCharset), gMySQL);
        printf("%s [Core/Database] Successful connection to the DBMS %s@%s:%d/%s (client encoding: %s, threads: %d).",
            SERVER_LOG_PREFIX, user, host, port, db, activeCharset, poolSize);
    }
    else
    {
        sDatabaseConnected = false;
        printf("%s [Core/Database] [WARN] MySQL DBMS is unavailable (error code: %d). Offline RAM mode is activated.",
            SERVER_LOG_PREFIX, errno);
    }
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API МОДУЛЯ БАЗЫ ДАННЫХ И DIRTY-FLAG (DB_*)
// =============================================================================

stock bool:DB_IsConnected()
{
    return (sDatabaseConnected && gMySQL != MYSQL_INVALID_HANDLE && mysql_errno(gMySQL) == 0);
}

// Добавление или коалесценция (слияние) UPDATE-запроса для грязной сущности (Character, Vehicle, Enterprise, Storage)
stock bool:DB_EnqueueDirtyQuery(E_DIRTY_ENTITY_TYPE:entityType, entityId, const updateQuery[])
{
    if (entityType == DIRTY_ENTITY_NONE || entityId <= 0 || updateQuery[0] == '\0')
    {
        return false;
    }

    // Если сущность уже есть в очереди — обновляем её SQL-запрос на месте (дедупликация запросов)
    foreach (new slot : sDirtyQueueIter)
    {
        if (sDirtyQueue[slot][E_DIRTY_ACTIVE] &&
            sDirtyQueue[slot][E_DIRTY_TYPE] == entityType &&
            sDirtyQueue[slot][E_DIRTY_ENTITY_ID] == entityId)
        {
            format(sDirtyQueue[slot][E_DIRTY_SQL_QUERY], DIRTY_QUERY_MAX_LEN, "%s", updateQuery);
            sDirtyQueue[slot][E_DIRTY_QUEUED_AT] = gettime();
            return true;
        }
    }

    new const freeSlot = Iter_Free(sDirtyQueueIter);
    if (freeSlot == INVALID_ITERATOR_SLOT)
    {
        printf("%s [Core/Database] [WARN] Dirty-Flag queue is full (%d)! An emergency reset is in progress.",
            SERVER_LOG_PREFIX, MAX_DIRTY_QUEUE_ENTRIES);
        DB_FlushDirtyBatch(DIRTY_FLUSH_BATCH_LIMIT);

        new const retrySlot = Iter_Free(sDirtyQueueIter);
        if (retrySlot == INVALID_ITERATOR_SLOT)
        {
            return false;
        }
        Iter_Add(sDirtyQueueIter, retrySlot);
        sDirtyQueue[retrySlot][E_DIRTY_ACTIVE] = true;
        sDirtyQueue[retrySlot][E_DIRTY_TYPE] = entityType;
        sDirtyQueue[retrySlot][E_DIRTY_ENTITY_ID] = entityId;
        sDirtyQueue[retrySlot][E_DIRTY_QUEUED_AT] = gettime();
        format(sDirtyQueue[retrySlot][E_DIRTY_SQL_QUERY], DIRTY_QUERY_MAX_LEN, "%s", updateQuery);
        return true;
    }

    Iter_Add(sDirtyQueueIter, freeSlot);
    sDirtyQueue[freeSlot][E_DIRTY_ACTIVE] = true;
    sDirtyQueue[freeSlot][E_DIRTY_TYPE] = entityType;
    sDirtyQueue[freeSlot][E_DIRTY_ENTITY_ID] = entityId;
    sDirtyQueue[freeSlot][E_DIRTY_QUEUED_AT] = gettime();
    format(sDirtyQueue[freeSlot][E_DIRTY_SQL_QUERY], DIRTY_QUERY_MAX_LEN, "%s", updateQuery);
    return true;
}

// Порционная отправка до maxQueries запросов из очереди Dirty-Flag (не более 20 за 100 мс)
stock DB_FlushDirtyBatch(maxQueries = DIRTY_FLUSH_BATCH_LIMIT)
{
    new flushedCount = 0;
    new slotsToRemove[DIRTY_FLUSH_BATCH_LIMIT];
    new removeCount = 0;

    foreach (new slot : sDirtyQueueIter)
    {
        if (flushedCount >= maxQueries || removeCount >= DIRTY_FLUSH_BATCH_LIMIT)
        {
            break;
        }

        if (sDirtyQueue[slot][E_DIRTY_ACTIVE] && sDirtyQueue[slot][E_DIRTY_SQL_QUERY][0] != '\0')
        {
            if (DB_IsConnected())
            {
                mysql_tquery(gMySQL, sDirtyQueue[slot][E_DIRTY_SQL_QUERY], "OnDatabaseDirtyQueryFlushed", "dd",
                    _:sDirtyQueue[slot][E_DIRTY_TYPE],
                    sDirtyQueue[slot][E_DIRTY_ENTITY_ID]);
            }
            sDirtyQueue[slot][E_DIRTY_ACTIVE] = false;
            sDirtyQueue[slot][E_DIRTY_SQL_QUERY][0] = '\0';
            slotsToRemove[removeCount++] = slot;
            flushedCount++;
        }
    }

    for (new i = 0; i < removeCount; i++)
    {
        Iter_Remove(sDirtyQueueIter, slotsToRemove[i]);
    }
    return flushedCount;
}

// Экстренный полный сброс всех накопленных Dirty-Flag сущностей при остановке сервера
stock DB_FlushAllDirtySync()
{
    new totalFlushed = 0;
    foreach (new slot : sDirtyQueueIter)
    {
        if (sDirtyQueue[slot][E_DIRTY_ACTIVE] && sDirtyQueue[slot][E_DIRTY_SQL_QUERY][0] != '\0')
        {
            if (DB_IsConnected())
            {
                mysql_tquery(gMySQL, sDirtyQueue[slot][E_DIRTY_SQL_QUERY]);
            }
            sDirtyQueue[slot][E_DIRTY_ACTIVE] = false;
            sDirtyQueue[slot][E_DIRTY_SQL_QUERY][0] = '\0';
            totalFlushed++;
        }
    }
    Iter_Clear(sDirtyQueueIter);

    if (DB_IsConnected())
    {
        new pending = mysql_unprocessed_queries(gMySQL);
        if (pending > 0)
        {
            printf("%s [Core/Database] Waiting for %d background SQL transactions to complete before closing the pool...",
                SERVER_LOG_PREFIX, pending);
        }
    }

    printf("%s [Core/Database] Forced save of Dirty-Flag queue (updated entities: %d).",
        SERVER_LOG_PREFIX, totalFlushed);
    return totalFlushed;
}

stock DB_GetPendingDirtyCount()
{
    return Iter_Count(sDirtyQueueIter);
}

// =============================================================================
//  5. АСИНХРОННЫЕ SQL-КОЛБЕКИ И ОБРАБОТЧИК ОШИБОК (forward / public)
// =============================================================================

forward OnDatabaseDirtyQueryFlushed(entityType, entityId);
public OnDatabaseDirtyQueryFlushed(entityType, entityId)
{
    #pragma unused entityType, entityId
    return 1;
}

public OnQueryError(errorid, const error[], const callback[], const query[], MySQL:handle)
{
    #pragma unused handle
    printf("%s [SQL ERROR #%d] Callback: '%s' | Error: %s | Request: %s",
        SERVER_LOG_PREFIX,
        errorid,
        (callback[0] != '\0') ? callback : "none",
        error,
        query);
    return 1;
}

// =============================================================================
//  6. ТАЙМЕРЫ РАСПРЕДЕЛЕННОГО СБРОСА DIRTY-FLAG (y_timers)
// =============================================================================

// Плавная разгрузка очереди пачками по 20 запросов с интервалом 100 мс
timer OnDatabaseDirtyBatchSlice[100]()
{
    if (Main_IsServerShuttingDown())
    {
        sBatchFlushInProgress = false;
        return;
    }

    DB_FlushDirtyBatch(DIRTY_FLUSH_BATCH_LIMIT);
    if (Iter_Count(sDirtyQueueIter) > 0)
    {
        defer OnDatabaseDirtyBatchSlice();
    }
    else
    {
        sBatchFlushInProgress = false;
    }
}

// Ежеминутный запуск распределенного сохранения всех измененных сущностей
task Tick_DatabaseDirtyFlush[60000]()
{
    if (Main_IsServerShuttingDown())
    {
        return;
    }
    if (Iter_Count(sDirtyQueueIter) > 0 && !sBatchFlushInProgress)
    {
        sBatchFlushInProgress = true;
        defer OnDatabaseDirtyBatchSlice();
    }
}

// =============================================================================
//  7. СИСТЕМНЫЕ ХУКИ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    Iter_Init(sDirtyQueueIter);
    for (new i = 0; i < MAX_DIRTY_QUEUE_ENTRIES; i++)
    {
        sDirtyQueue[i][E_DIRTY_ACTIVE] = false;
        sDirtyQueue[i][E_DIRTY_TYPE] = DIRTY_ENTITY_NONE;
        sDirtyQueue[i][E_DIRTY_ENTITY_ID] = 0;
        sDirtyQueue[i][E_DIRTY_QUEUED_AT] = 0;
        sDirtyQueue[i][E_DIRTY_SQL_QUERY][0] = '\0';
    }
    Internal_ConnectDatabase();
    return 1;
}

hook OnGameModeExit()
{
    if (gMySQL != MYSQL_INVALID_HANDLE)
    {
        mysql_close(gMySQL);
        gMySQL = MYSQL_INVALID_HANDLE;
        sDatabaseConnected = false;
    }
    return 1;
}

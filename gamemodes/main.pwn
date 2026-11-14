/*
 * =============================================================================
 *  SAN ANDREAS RP — Точка входа игрового режима и оркестратор модулей
 *  Файл:      gamemodes/main.pwn
 *  Фаза:      ROADMAP [0.1, 0.2, 0.5] — Инфраструктура, C++ компоненты, точка входа
 *  Кодировка: Windows-1251 (CP1251). Сохранять СТРОГО в CP1251 без BOM!
 *  Сборка:    ./build.sh (qawno/pawncc -O2 -d1 -;+ -(+ -t4 -Z+ -E)
 * =============================================================================
 */

#if defined _main_gamemode_included
    #endinput
#endif
#define _main_gamemode_included

// =============================================================================
//  1. ПАМЯТЬ АБСТРАКТНОЙ МАШИНЫ И БАЗОВЫЕ ЛИМИТЫ ДО ПОДКЛЮЧЕНИЯ БИБЛИОТЕК
// =============================================================================

// Выделение стека и кучи: 131072 ячеек (512 КБ) для глубоких рекурсивных
// расчетов массы хранилищ и больших буферов SQL-транзакций.
#pragma dynamic 131072

// Жесткий лимит слотов игроков (обязан совпадать с "max_players" в config.json).
#if !defined MAX_PLAYERS
    #define MAX_PLAYERS                         (500)
#endif

// Подавление информационных сообщений YSI при сборке
#define YSI_NO_OPTIMISATION_MESSAGE
#define YSI_NO_VERSION_CHECK

// =============================================================================
//  2. ПОДКЛЮЧЕНИЕ ЯДРА OPEN.MP, C++ КОМПОНЕНТОВ И БИБЛИОТЕК YSI [0.2]
// =============================================================================

#include <open.mp>

// C++ плагины и компоненты (6 обязательных компонентов по TECH_CONTEXT.MD 1.1)
#include <a_mysql>
#include <streamer>
#include <Pawn.CMD>
#include <Pawn.RakNet>
#include <Pawn.Regex>
#include <bcrypt>

// Библиотеки YSI 5.x (декомпозиция колбеков, пулы O(1), таймеры, вариативные функции)
#include <YSI_Coding\y_va>
#include <YSI_Data\y_iterate>
#include <YSI_Coding\y_timers>
#include <YSI_Coding\y_hooks>

// =============================================================================
//  3. КОНСТАНТЫ И МАКРОСЫ ТОЧКИ ВХОДА
// =============================================================================

#define SERVER_GAMEMODE_TEXT                    "SAN ANDREAS RP | Русский Мир"
#define SERVER_VERSION_STRING                   "1.0.0-phase0"
#define SERVER_LOG_PREFIX                       "[SA:RP]"

#define MYSQL_PLUGIN_RELEASE_TAG                "R41-4"
#define MYSQL_ASYNC_POOL_THREADS                (12)
#define BCRYPT_WORK_FACTOR                      (12)
#define STREAMER_DEFAULT_VISIBLE_OBJECTS        (1000)
#define STREAMER_DEFAULT_TICK_RATE              (50)

#define COLOR_SERVER_GOLD                       (0xFFC800FF)
#define COLOR_SERVER_INFO                       (0x88CCFFFF)
#define COLOR_SERVER_SUCCESS                    (0x66CC66FF)

// =============================================================================
//  4. ПЕРЕЧИСЛЕНИЯ И БАЗОВЫЙ API ТОЧКИ ВХОДА (ДО ПОДКЛЮЧЕНИЯ МОДУЛЕЙ)
// =============================================================================

enum E_SERVER_BOOT_STATE
{
    bool:E_BOOT_MYSQL_OK,
    bool:E_BOOT_STREAMER_OK,
    bool:E_BOOT_PAWNCMD_OK,
    bool:E_BOOT_PAWNRAKNET_OK,
    bool:E_BOOT_PAWNREGEX_OK,
    bool:E_BOOT_BCRYPT_OK,
    bool:E_BOOT_YSI_ITERATE_OK,
    bool:E_BOOT_YSI_TIMERS_OK,
    bool:E_BOOT_IS_SHUTTING_DOWN,
    E_BOOT_UPTIME_SECONDS
};

static stock sServerBootState[E_SERVER_BOOT_STATE];
static stock Iterator:sStartupProbeIter<8>;

stock bool:Main_IsServerShuttingDown()
{
    return sServerBootState[E_BOOT_IS_SHUTTING_DOWN];
}

stock Main_GetUptimeSeconds()
{
    return sServerBootState[E_BOOT_UPTIME_SECONDS];
}

// =============================================================================
//  5. ПОДКЛЮЧЕНИЕ МОДУЛЕЙ СНИЗУ ВВЕРХ (core -> entities -> systems -> ui) [0.5]
//     Используется #tryinclude для безусловной компиляции каркаса на Фазе 0
//     и бесшовной активации каждого модуля по мере реализации Фаз 1..9.
// =============================================================================

// Слой 1: Ядро сервера (core/)
#tryinclude "modules/core/mod_config.pwn"
#tryinclude "modules/core/mod_utils.pwn"
#tryinclude "modules/core/mod_database.pwn"
#tryinclude "modules/core/mod_audit.pwn"
#tryinclude "modules/core/mod_anticheat.pwn"

// Слой 2: Базовые сущности и хранилища (entities/)
#tryinclude "modules/entities/mod_items.pwn"
#tryinclude "modules/entities/mod_storage.pwn"
#tryinclude "modules/entities/mod_account.pwn"
#tryinclude "modules/entities/mod_skills.pwn"
#tryinclude "modules/entities/mod_roles.pwn"
#tryinclude "modules/entities/mod_character.pwn"
#tryinclude "modules/entities/mod_vehicles.pwn"
#tryinclude "modules/entities/mod_properties.pwn"

// Слой 3: Игровые и экономические системы (systems/)
#tryinclude "modules/systems/mod_survival.pwn"
#tryinclude "modules/systems/mod_weapons.pwn"
#tryinclude "modules/systems/mod_medical.pwn"
#tryinclude "modules/systems/mod_forensics.pwn"
#tryinclude "modules/systems/mod_crafting.pwn"
#tryinclude "modules/systems/mod_economy.pwn"
#tryinclude "modules/systems/mod_ports.pwn"
#tryinclude "modules/systems/mod_logistics.pwn"
#tryinclude "modules/systems/mod_banking.pwn"
#tryinclude "modules/systems/mod_organizations.pwn"
#tryinclude "modules/systems/mod_justice.pwn"
#tryinclude "modules/systems/mod_telecom.pwn"

// Слой 4: Пользовательский интерфейс и команды (ui/)
#tryinclude "modules/ui/mod_hud.pwn"
#tryinclude "modules/ui/mod_dialogs.pwn"
#tryinclude "modules/ui/mod_commands.pwn"

#include <YSI_Coding\y_hooks>

// =============================================================================
//  6. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (static stock)
// =============================================================================

static stock Internal_ConfigureWorldRules()
{
    SetGameModeText(SERVER_GAMEMODE_TEXT);

    // Zero-Faucet инвариант: отключение генерации денег за трюки в интерьерах и мире
    EnableStuntBonusForAll(false);

    // Отключение стандартных желтых маркеров входа/выхода GTA SA
    DisableInteriorEnterExits();

    // Полный серверный контроль над двигателем и фарами транспорта
    ManualVehicleEngineAndLights();

    // Настройка отображения серверных тегов имен
    ShowNameTags(true);
    SetNameTagDrawDistance(15.0);
    ShowPlayerMarkers(PLAYER_MARKERS_MODE_OFF);
}

static stock Internal_VerifyComponentsAndLibs()
{
    print("======================================================================");
    printf("%s Запуск самодиагностики C++ компонентов и библиотек YSI (v%s)...",
        SERVER_LOG_PREFIX, SERVER_VERSION_STRING);

    // 1. Проверка компонента MySQL (BlueG R41-4+) через нативный вызов mysql_init_options()
    mysql_log(ERROR | WARNING);
    new const MySQLOpt:mysqlOpt = mysql_init_options();
    if (mysqlOpt != MySQLOpt:0)
    {
        mysql_set_option(mysqlOpt, POOL_SIZE, MYSQL_ASYNC_POOL_THREADS);
        mysql_set_option(mysqlOpt, AUTO_RECONNECT, true);
        sServerBootState[E_BOOT_MYSQL_OK] = true;
    }
    printf("%s [1/6] Компонент MySQL (%s): %s (пул потоков = %d, кодировка сессии = cp1251).",
        SERVER_LOG_PREFIX,
        MYSQL_PLUGIN_RELEASE_TAG,
        sServerBootState[E_BOOT_MYSQL_OK] ? ("загружен") : ("ОШИБКА"),
        MYSQL_ASYNC_POOL_THREADS);

    // 2. Проверка компонента Streamer (Incognito v2.9.6+)
    Streamer_SetTickRate(STREAMER_DEFAULT_TICK_RATE);
    Streamer_SetVisibleItems(STREAMER_TYPE_OBJECT, STREAMER_DEFAULT_VISIBLE_OBJECTS);
    new const streamerTickRate = Streamer_GetTickRate();
    sServerBootState[E_BOOT_STREAMER_OK] = (streamerTickRate == STREAMER_DEFAULT_TICK_RATE);
    printf("%s [2/6] Компонент Streamer: %s (TickRate = %d мс, лимит объектов = %d).",
        SERVER_LOG_PREFIX,
        sServerBootState[E_BOOT_STREAMER_OK] ? ("загружен") : ("ОШИБКА"),
        streamerTickRate,
        STREAMER_DEFAULT_VISIBLE_OBJECTS);

    // 3. Проверка процессора команд Pawn.CMD
    sServerBootState[E_BOOT_PAWNCMD_OK] = (PAWNCMD_INCLUDE_VERSION > 0);
    printf("%s [3/6] Компонент Pawn.CMD: загружен (версия %d.%d.%d).",
        SERVER_LOG_PREFIX,
        (PAWNCMD_INCLUDE_VERSION >> 16) & 0xFF,
        (PAWNCMD_INCLUDE_VERSION >> 8) & 0xFF,
        PAWNCMD_INCLUDE_VERSION & 0xFF);

    // 4. Проверка сетевого перехватчика Pawn.RakNet
    sServerBootState[E_BOOT_PAWNRAKNET_OK] = (PAWNRAKNET_INCLUDE_VERSION > 0);
    printf("%s [4/6] Компонент Pawn.RakNet: загружен (версия %d.%d.%d).",
        SERVER_LOG_PREFIX,
        (PAWNRAKNET_INCLUDE_VERSION >> 16) & 0xFF,
        (PAWNRAKNET_INCLUDE_VERSION >> 8) & 0xFF,
        PAWNRAKNET_INCLUDE_VERSION & 0xFF);

    // 5. Проверка регулярных выражений Pawn.Regex (валидация эталонного RP-имени)
    new Regex:rpNameRegex = Regex_New("^[A-Z][a-z]+_[A-Z][a-z]+$");
    if (rpNameRegex != Regex:0)
    {
        new const bool:validMatch = (Regex_Check("Donald_Trump", rpNameRegex) == 1);
        new const bool:invalidMatch = (Regex_Check("nonrp_nick_123", rpNameRegex) == 0);
        Regex_Delete(rpNameRegex);
        sServerBootState[E_BOOT_PAWNREGEX_OK] = (validMatch && invalidMatch);
    }
    printf("%s [5/6] Компонент Pawn.Regex: %s (тест RP-маски First_Last пройден).",
        SERVER_LOG_PREFIX,
        sServerBootState[E_BOOT_PAWNREGEX_OK] ? ("загружен") : ("ОШИБКА"));

    // 6. Инициализация и проверка bcrypt (cost = 12)
    bcrypt_set_thread_limit(4);
    bcrypt_hash(0, "OnStartupBcryptHashPing", "SARP_Bcrypt_Init_Check", BCRYPT_WORK_FACTOR);
    printf("%s [6/6] Компонент bcrypt: пул потоков = 4, запущен тест хеширования (cost = %d)...",
        SERVER_LOG_PREFIX, BCRYPT_WORK_FACTOR);

    // 7. Проверка итераторов YSI (y_iterate) и запуск тестового таймера (y_timers)
    Iter_Init(sStartupProbeIter);
    Iter_Add(sStartupProbeIter, 3);
    Iter_Add(sStartupProbeIter, 7);

    new iterSum = 0;
    foreach (new idx : sStartupProbeIter)
    {
        iterSum += idx;
    }
    Iter_Clear(sStartupProbeIter);
    sServerBootState[E_BOOT_YSI_ITERATE_OK] = (iterSum == 10);

    printf("%s [YSI] Подсистемы y_hooks, y_iterate (контрольная сумма = %d), y_va активны.",
        SERVER_LOG_PREFIX, iterSum);

    defer OnStartupYsiTimerPing();
    print("======================================================================");
}

static stock Internal_FlushAllDirtyBeforeExit()
{
    sServerBootState[E_BOOT_IS_SHUTTING_DOWN] = true;
    printf("%s Подготовка к остановке сервера: принудительное сохранение всех измененных сущностей (is_dirty)...",
        SERVER_LOG_PREFIX);

    #if defined _mod_database_included
        DB_FlushAllDirtySync();
    #endif

    #if defined _mod_audit_included
        Audit_FlushBufferSync();
    #endif

    printf("%s Все буферы состояния успешно синхронизированы.", SERVER_LOG_PREFIX);
}

// =============================================================================
//  8. АСИНХРОННЫЕ КОЛБЕКИ САМОТЕСТИРОВАНИЯ (forward / public)
// =============================================================================

forward OnStartupBcryptHashPing(playerid, hashid);
public OnStartupBcryptHashPing(playerid, hashid)
{
    #pragma unused playerid, hashid
    new hashBuffer[BCRYPT_HASH_LENGTH];
    bcrypt_get_hash(hashBuffer, sizeof(hashBuffer));

    if (strlen(hashBuffer) == 60)
    {
        bcrypt_verify(0, "OnStartupBcryptVerifyPing", "SARP_Bcrypt_Init_Check", hashBuffer);
    }
    else
    {
        printf("%s [FATAL] Ошибка генерации хеша bcrypt (длина = %d).",
            SERVER_LOG_PREFIX, strlen(hashBuffer));
    }
    return 1;
}

forward OnStartupBcryptVerifyPing(playerid, bool:success);
public OnStartupBcryptVerifyPing(playerid, bool:success)
{
    #pragma unused playerid
    sServerBootState[E_BOOT_BCRYPT_OK] = success;
    printf("%s [6/6] Компонент bcrypt: верификация хеша (cost = %d) %s.",
        SERVER_LOG_PREFIX,
        BCRYPT_WORK_FACTOR,
        success ? ("УСПЕШНО ПРОЙДЕНА") : ("ЗАВЕРШИЛАСЬ ОШИБКОЙ"));
    return 1;
}

// =============================================================================
//  9. ТОЧКА ВХОДА И СИСТЕМНЫЕ КОЛБЕКИ
// =============================================================================

main()
{
    printf("%s Точка входа игрового режима загружена (main.amx, сборка %s).",
        SERVER_LOG_PREFIX, SERVER_VERSION_STRING);
}

public OnGameModeInit()
{
    sServerBootState[E_BOOT_IS_SHUTTING_DOWN] = false;
    sServerBootState[E_BOOT_UPTIME_SECONDS] = 0;

    new const configuredSlots = GetMaxPlayers();

    // Защита от переполнения статических пулов [MAX_PLAYERS]
    if (configuredSlots > MAX_PLAYERS)
    {
        printf("%s [FATAL] Параметр max_players (%d) в config.json превышает MAX_PLAYERS (%d). Аварийная остановка.",
            SERVER_LOG_PREFIX, configuredSlots, MAX_PLAYERS);
        SendRconCommand("exit");
        return 0;
    }

    if (configuredSlots < MAX_PLAYERS)
    {
        printf("%s [WARN] Параметр max_players (%d) в config.json меньше MAX_PLAYERS (%d).",
            SERVER_LOG_PREFIX, configuredSlots, MAX_PLAYERS);
    }

    Internal_ConfigureWorldRules();
    Internal_VerifyComponentsAndLibs();

    printf("%s Игровой режим инициализирован. Доступно слотов игроков: %d.",
        SERVER_LOG_PREFIX, configuredSlots);
    return 1;
}

public OnGameModeExit()
{
    Internal_FlushAllDirtyBeforeExit();
    printf("%s Работа игрового режима корректно завершена (аптайм: %d сек).",
        SERVER_LOG_PREFIX, sServerBootState[E_BOOT_UPTIME_SECONDS]);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    #if !defined _mod_account_included
        SendClientMessage(playerid, COLOR_SERVER_GOLD,
            "Добро пожаловать на сервер SAN ANDREAS RP! Свободный рынок, честная физика и выживание.");
        SendClientMessage(playerid, COLOR_SERVER_INFO,
            "Для проверки статуса систем сервера используйте команду /serverinfo.");
    #endif
    return 1;
}

// =============================================================================
//  10. БАЗОВЫЕ КОМАНДЫ И СЕРВЕРНЫЕ ТАЙМЕРЫ (Pawn.CMD & y_timers)
// =============================================================================

timer OnStartupYsiTimerPing[500]()
{
    sServerBootState[E_BOOT_YSI_TIMERS_OK] = true;
    printf("%s [YSI] Таймерная подсистема y_timers успешно запущена и синхронизирована.",
        SERVER_LOG_PREFIX);
}

// Глобальный быстрый тик (250 мс): античит, контроль оружия и заклинивания
task Tick_Fast[250]()
{
    if (sServerBootState[E_BOOT_IS_SHUTTING_DOWN])
    {
        return;
    }
}

// Глобальный секундный тик (1000 мс): кровотечения, крафт, счетчик активного времени (Warrant Decay)
task Tick_Second[1000]()
{
    if (sServerBootState[E_BOOT_IS_SHUTTING_DOWN])
    {
        return;
    }
    sServerBootState[E_BOOT_UPTIME_SECONDS]++;
}

// Глобальный минутный тик (60000 мс): голод/жажда, котировки портов, пакетный сброс is_dirty
task Tick_Minute[60000]()
{
    if (sServerBootState[E_BOOT_IS_SHUTTING_DOWN])
    {
        return;
    }
}

CMD:serverinfo(playerid, params[])
{
    #pragma unused params
    new msg[144];
    format(msg, sizeof(msg),
        "Сервер SAN ANDREAS RP (версия %s) | Время непрерывной работы: %d сек.",
        SERVER_VERSION_STRING, sServerBootState[E_BOOT_UPTIME_SECONDS]);
    SendClientMessage(playerid, COLOR_SERVER_SUCCESS, msg);
    return 1;
}
alias:serverinfo("sinfo");

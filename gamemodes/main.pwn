/*
 * =============================================================================
 *  SAN ANDREAS RP — точка входа игрового режима
 *  Файл:      gamemodes/main.pwn
 *  Пункт:     ROADMAP [0.1] — базовая инфраструктура сборки
 *  Кодировка: Windows-1251 (CP1251). Сохранять ТОЛЬКО в CP1251!
 *  Сборка:    ./build.sh  (pawncc -O2 -d1, флаги из qawno/pawn.cfg)
 *
 *  Порядок подключения модулей (core -> entities -> systems -> ui)
 *  формируется в пункте [0.5]. Каталоги модулей:
 *      gamemodes/modules/core/
 *      gamemodes/modules/entities/
 *      gamemodes/modules/systems/
 *      gamemodes/modules/ui/
 * =============================================================================
 */

// -----------------------------------------------------------------------------
//  Память абстрактной машины: стек + куча = 131072 ячеек (512 КБ).
//  Необходимо для крупных SQL-буферов и рекурсивных обходов хранилищ.
// -----------------------------------------------------------------------------
#pragma dynamic 131072

// -----------------------------------------------------------------------------
//  Число слотов игроков. ОБЯЗАНО совпадать с "max_players" в config.json.
//  Должно быть объявлено ДО подключения <open.mp> и любых библиотек YSI.
// -----------------------------------------------------------------------------
#define MAX_PLAYERS                     (500)

#include <open.mp>

// -----------------------------------------------------------------------------
//  Константы точки входа
// -----------------------------------------------------------------------------
#define SERVER_GAMEMODE_TEXT            "Ролевая игра"
#define SERVER_LOG_PREFIX               "[SA:RP]"
#define COLOR_SERVER_NOTICE             (0xFFC800FF)

// -----------------------------------------------------------------------------
//  Точка входа скрипта
// -----------------------------------------------------------------------------
main()
{
    print(SERVER_LOG_PREFIX " Gamemode entry point loaded (main.amx).");
}

// -----------------------------------------------------------------------------
//  Системные колбеки
// -----------------------------------------------------------------------------
public OnGameModeInit()
{
    new const configuredSlots = GetMaxPlayers();

    // Защита от выхода за границы всех массивов [MAX_PLAYERS]:
    // если в config.json слотов больше, чем скомпилировано, сервер
    // немедленно останавливается, а не работает с повреждением памяти.
    if (configuredSlots > MAX_PLAYERS)
    {
        printf(SERVER_LOG_PREFIX "[FATAL] config.json max_players (%d) exceeds compiled MAX_PLAYERS (%d). Shutting down.", configuredSlots, MAX_PLAYERS);
        SendRconCommand("exit");
        return 0;
    }

    if (configuredSlots < MAX_PLAYERS)
    {
        printf(SERVER_LOG_PREFIX "[WARN] config.json max_players (%d) is lower than compiled MAX_PLAYERS (%d).", configuredSlots, MAX_PLAYERS);
    }

    SetGameModeText(SERVER_GAMEMODE_TEXT);

    // Zero-Faucet: трюковые бонусы создают деньги "из воздуха" — запрещены
    // независимо от значения "use_stunt_bonuses" в config.json.
    EnableStuntBonusForAll(false);

    printf(SERVER_LOG_PREFIX " Gamemode initialized. Player slots: %d.", configuredSlots);
    return 1;
}

public OnGameModeExit()
{
    print(SERVER_LOG_PREFIX " Gamemode shutdown completed.");
    return 1;
}

public OnPlayerConnect(playerid)
{
    SendClientMessage(playerid, COLOR_SERVER_NOTICE, "Добро пожаловать на сервер SAN ANDREAS RP! Игровой режим находится в разработке.");
    return 1;
}

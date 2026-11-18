/*
 * =============================================================================
 *  SAN ANDREAS RP — Текстовый HUD выживания и статусов персонажа
 *  Файл:      gamemodes/modules/ui/mod_hud.pwn
 *  Пункт:     ROADMAP [4.2] — Текстовый HUD (ui/mod_hud.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_hud_included
    #endinput
#endif
#define _mod_hud_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ ПОЗИЦИОНИРОВАНИЯ И ОФОРМЛЕНИЯ ТЕКСТОВОГО HUD
// =============================================================================

#define HUD_PANEL_POS_X                         (630.0)
#define HUD_PANEL_POS_Y                         (392.0)
#define HUD_LETTER_WIDTH                        (0.19)
#define HUD_LETTER_HEIGHT                       (0.88)
#define HUD_TEXT_COLOR                          (0xECEFF1FF)
#define HUD_SHADOW_COLOR                        (0x000000CC)

// =============================================================================
//  2. СОСТОЯНИЕ PLAYER TEXTDRAW В ОПЕРАТИВНОЙ ПАМЯТИ (static stock)
// =============================================================================

static stock PlayerText:sPlayerHudTextDraw[MAX_PLAYERS];
static stock bool:sPlayerHudVisible[MAX_PLAYERS];
static stock sPlayerLastHudCache[MAX_PLAYERS][256];

// =============================================================================
//  3. ВНУТРЕННИЕ ФУНКЦИИ СОЗДАНИЯ, УНИЧТОЖЕНИЯ И ФОРМАТИРОВАНИЯ HUD
// =============================================================================

static stock Internal_CreatePlayerHud(playerid)
{
    if (sPlayerHudTextDraw[playerid] != INVALID_PLAYER_TEXT_DRAW)
    {
        PlayerTextDrawDestroy(playerid, sPlayerHudTextDraw[playerid]);
        sPlayerHudTextDraw[playerid] = INVALID_PLAYER_TEXT_DRAW;
    }

    new PlayerText:td = CreatePlayerTextDraw(
        playerid,
        HUD_PANEL_POS_X,
        HUD_PANEL_POS_Y,
        "Weight: 0.0 / 25.0 kg~n~Hunger: 100% | Thirst: 100%~n~Status: NORMAL~n~Wanted: 0/100 | Radio: OFF"
    );

    if (td != INVALID_PLAYER_TEXT_DRAW)
    {
        PlayerTextDrawAlignment(playerid, td, TEXT_DRAW_ALIGN_RIGHT);
        PlayerTextDrawFont(playerid, td, TEXT_DRAW_FONT_1);
        PlayerTextDrawLetterSize(playerid, td, HUD_LETTER_WIDTH, HUD_LETTER_HEIGHT);
        PlayerTextDrawColour(playerid, td, HUD_TEXT_COLOR);
        PlayerTextDrawBackgroundColour(playerid, td, HUD_SHADOW_COLOR);
        PlayerTextDrawSetOutline(playerid, td, 1);
        PlayerTextDrawSetShadow(playerid, td, 0);
        PlayerTextDrawSetProportional(playerid, td, true);
    }

    sPlayerHudTextDraw[playerid] = td;
    sPlayerLastHudCache[playerid][0] = '\0';
}

static stock Internal_DestroyPlayerHud(playerid)
{
    if (sPlayerHudTextDraw[playerid] != INVALID_PLAYER_TEXT_DRAW)
    {
        PlayerTextDrawDestroy(playerid, sPlayerHudTextDraw[playerid]);
        sPlayerHudTextDraw[playerid] = INVALID_PLAYER_TEXT_DRAW;
    }
    sPlayerHudVisible[playerid] = false;
    sPlayerLastHudCache[playerid][0] = '\0';
}

static stock Internal_BuildStatusFlags(playerid, output[], len = sizeof(output))
{
    output[0] = '\0';
    new count = 0;

    if (Survival_IsOverweight(playerid))
    {
        strcat(output, "~r~OVERWEIGHT", len);
        count++;
    }
    if (Medical_IsBleeding(playerid))
    {
        if (count > 0) strcat(output, " ~w~| ", len);
        strcat(output, "~r~BLEEDING", len);
        count++;
    }
    if (Survival_IsInWithdrawal(playerid))
    {
        if (count > 0) strcat(output, " ~w~| ", len);
        strcat(output, "~p~WITHDRAWAL", len);
        count++;
    }
    if (Survival_IsCuffed(playerid))
    {
        if (count > 0) strcat(output, " ~w~| ", len);
        strcat(output, "~y~HANDCUFFED", len);
        count++;
    }

    if (count == 0)
    {
        strcat(output, "~g~NORMAL", len);
    }
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API СОБЫТИЙНОГО ОБНОВЛЕНИЯ HUD (stock & public)
// =============================================================================

/*
 * Событийное обновление HUD игрока. Вызывается только при изменении массы,
 * голода/жажды, получении урона, переключении рации или изменении розыска.
 * Не отправляет сетевой пакет, если итоговая строка не изменилась.
 */
stock HUD_RefreshPlayer(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    if (!IsPlayerConnected(playerid) || !Character_IsLoaded(playerid))
    {
        return 0;
    }

    if (sPlayerHudTextDraw[playerid] == INVALID_PLAYER_TEXT_DRAW)
    {
        Internal_CreatePlayerHud(playerid);
    }
    if (sPlayerHudTextDraw[playerid] == INVALID_PLAYER_TEXT_DRAW)
    {
        return 0;
    }

    new curWeightG = Survival_GetCarryWeightGrams(playerid);
    new maxWeightG = Survival_GetMaxCarryWeightGrams(playerid);
    new hungerPct  = floatround(Character_GetHunger(playerid), floatround_round);
    new thirstPct  = floatround(Character_GetThirst(playerid), floatround_round);
    new wantedLvl  = Character_GetWantedLevel(playerid);
    new radioKhz   = Survival_GetRadioFreqKhz(playerid);

    if (hungerPct < 0) hungerPct = 0;
    if (hungerPct > 100) hungerPct = 100;
    if (thirstPct < 0) thirstPct = 0;
    if (thirstPct > 100) thirstPct = 100;

    new statusBuf[96];
    Internal_BuildStatusFlags(playerid, statusBuf, sizeof(statusBuf));

    new radioBuf[32];
    if (radioKhz > 0)
    {
        format(radioBuf, sizeof(radioBuf), "%d.%03d MHz", radioKhz / 1000, radioKhz % 1000);
    }
    else
    {
        format(radioBuf, sizeof(radioBuf), "OFF");
    }

    new hudString[256];
    format(
        hudString,
        sizeof(hudString),
        "Weight: %d.%d / %d.%d kg~n~Hunger: %d%% | Thirst: %d%%~n~Status: %s~w~~n~Wanted: %d/100 | Radio: %s",
        curWeightG / 1000, (curWeightG % 1000) / 100,
        maxWeightG / 1000, (maxWeightG % 1000) / 100,
        hungerPct,
        thirstPct,
        statusBuf,
        wantedLvl,
        radioBuf
    );

    // Защита от лишних сетевых пакетов: обновляем TextDraw только при фактическом изменении текста
    if (strcmp(sPlayerLastHudCache[playerid], hudString, false) != 0 || !sPlayerHudVisible[playerid])
    {
        format(sPlayerLastHudCache[playerid], sizeof(sPlayerLastHudCache[]), "%s", hudString);
        PlayerTextDrawSetString(playerid, sPlayerHudTextDraw[playerid], hudString);

        if (sPlayerHudVisible[playerid])
        {
            PlayerTextDrawShow(playerid, sPlayerHudTextDraw[playerid]);
        }
    }
    return 1;
}

stock HUD_SetVisible(playerid, bool:visible)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    if (sPlayerHudTextDraw[playerid] == INVALID_PLAYER_TEXT_DRAW)
    {
        if (!visible) return 1;
        Internal_CreatePlayerHud(playerid);
    }

    sPlayerHudVisible[playerid] = visible;
    if (visible)
    {
        sPlayerLastHudCache[playerid][0] = '\0';
        HUD_RefreshPlayer(playerid);
        PlayerTextDrawShow(playerid, sPlayerHudTextDraw[playerid]);
    }
    else
    {
        PlayerTextDrawHide(playerid, sPlayerHudTextDraw[playerid]);
    }
    return 1;
}

stock bool:HUD_IsVisible(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return sPlayerHudVisible[playerid];
}

forward OnPlayerHudNeedsUpdate(playerid);
public OnPlayerHudNeedsUpdate(playerid)
{
    if (sPlayerHudVisible[playerid])
    {
        HUD_RefreshPlayer(playerid);
    }
    return 1;
}

// =============================================================================
//  5. ПЕРЕХВАТЧИКИ СОБЫТИЙ ДВИЖКА (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        sPlayerHudTextDraw[i] = INVALID_PLAYER_TEXT_DRAW;
        sPlayerHudVisible[i] = false;
        sPlayerLastHudCache[i][0] = '\0';
    }
    printf("%s [UI/HUD] Survival text HUD module initialized (event-based update without timer spam: OK).",
        SERVER_LOG_PREFIX);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    sPlayerHudTextDraw[playerid] = INVALID_PLAYER_TEXT_DRAW;
    sPlayerHudVisible[playerid] = false;
    sPlayerLastHudCache[playerid][0] = '\0';
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    Internal_DestroyPlayerHud(playerid);
    return 1;
}

hook OnPlayerSpawn(playerid)
{
    if (Character_IsLoaded(playerid))
    {
        HUD_SetVisible(playerid, true);
    }
    return 1;
}

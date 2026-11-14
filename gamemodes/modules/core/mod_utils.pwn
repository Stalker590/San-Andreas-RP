/*
 * =============================================================================
 *  SAN ANDREAS RP — Модуль математических, строковых утилит и крипто-генераторов
 *  Файл:      gamemodes/modules/core/mod_utils.pwn
 *  Пункт:     ROADMAP [1.2] — Модуль утилит и генераторов (core/mod_utils.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_utils_included
    #endinput
#endif
#define _mod_utils_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ И ИНКАПСУЛИРОВАННОЕ СОСТОЯНИЕ ЭНТРОПИИ (static stock)
// =============================================================================

#define SSN_STRING_LENGTH                       (12)
#define VIN_STRING_LENGTH                       (18)
#define IBAN_STRING_LENGTH                      (21)

static stock sEntropyState = 0x5A17C9E3;
static stock sSerialSequence = 100000;

static stock const sVinAlphabet[] = "0123456789ABCDEFGHJKLMNPRSTUVWXYZ";
static stock const sBankBranchCodes[][] =
{
    "LSBK",
    "SFBK",
    "LVBK",
    "FEDR"
};

// =============================================================================
//  2. ВНУТРЕННИЕ ФУНКЦИИ ГЕНЕРАЦИИ ЭНТРОПИИ (static stock)
// =============================================================================

static stock Internal_NextEntropyWord()
{
    // Смешивание аппаратного тика, времени UNIX и сдвигового регистра Xorshift32
    new seed = sEntropyState ^ GetTickCount() ^ gettime() ^ (++sSerialSequence * 2654435761);
    if (seed == 0)
    {
        seed = 0x6D2B79F5;
    }
    seed ^= (seed << 13);
    seed ^= (seed >>> 17);
    seed ^= (seed << 5);
    sEntropyState = seed;
    return (seed & 0x7FFFFFFF);
}

static stock Internal_RandomRange(minVal, maxVal)
{
    if (maxVal <= minVal)
    {
        return minVal;
    }
    new const span = (maxVal - minVal) + 1;
    return minVal + (Internal_NextEntropyWord() % span);
}

// =============================================================================
//  3. ПУБЛИЧНЫЙ API ГЕНЕРАТОРОВ ИДЕНТИФИКАТОРОВ (Utils_Generate*)
// =============================================================================

// Генерация номера социального страхования США в формате XXX-XX-XXXX
stock Utils_GenerateSSN(output[], len = sizeof(output))
{
    new const area = Internal_RandomRange(100, 899);
    new const group = Internal_RandomRange(10, 99);
    new const serial = Internal_RandomRange(1000, 9999);

    format(output, len, "%03d-%02d-%04d", area, group, serial);
    return 1;
}

// Генерация 17-символьного VIN-кода транспорта (стандарт ISO 3779 без I, O, Q)
stock Utils_GenerateVIN(output[], len = sizeof(output))
{
    if (len < VIN_STRING_LENGTH)
    {
        if (len > 0)
        {
            output[0] = '\0';
        }
        return 0;
    }

    // Префикс страны и завода Сан-Андреас: "1SA"
    output[0] = '1';
    output[1] = 'S';
    output[2] = 'A';

    new const alphabetLen = sizeof(sVinAlphabet) - 1;
    for (new i = 3; i < 17; i++)
    {
        new const idx = Internal_NextEntropyWord() % alphabetLen;
        output[i] = sVinAlphabet[idx];
    }
    output[17] = '\0';
    return 1;
}

// Генерация банковского счета IBAN в формате SA00XXXX00000000 (16 символов)
stock Utils_GenerateIBAN(output[], len = sizeof(output))
{
    new const checkDigits = Internal_RandomRange(10, 99);
    new const branchIdx = Internal_NextEntropyWord() % sizeof(sBankBranchCodes);
    new const part1 = Internal_RandomRange(1000, 9999);
    new const part2 = Internal_RandomRange(1000, 9999);

    format(output, len, "SA%02d%s%04d%04d",
        checkDigits,
        sBankBranchCodes[branchIdx],
        part1,
        part2);
    return 1;
}

// Генерация уникального серийного номера огнестрельного оружия
stock Utils_GenerateWeaponSerial()
{
    new const timePart = (gettime() & 0x000FFFFF);
    new const seqPart = (++sSerialSequence & 0x03FF);
    new const serial = (timePart * 1000) + seqPart;
    return (serial > 0) ? serial : (Internal_RandomRange(1000000, 2000000000));
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API ГЕОМЕТРИИ И ДИСТАНЦИЙ (Utils_*)
// =============================================================================

stock Float:Utils_GetDistance3D(Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2)
{
    new const Float:dx = (x1 - x2);
    new const Float:dy = (y1 - y2);
    new const Float:dz = (z1 - z2);
    return floatsqroot((dx * dx) + (dy * dy) + (dz * dz));
}

stock bool:Utils_IsPlayerNearPoint(playerid, Float:radius, Float:x, Float:y, Float:z, interior = -1, virtualWorld = -1)
{
    if (!IsPlayerConnected(playerid))
    {
        return false;
    }
    if (interior != -1 && GetPlayerInterior(playerid) != interior)
    {
        return false;
    }
    if (virtualWorld != -1 && GetPlayerVirtualWorld(playerid) != virtualWorld)
    {
        return false;
    }
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    return (Utils_GetDistance3D(px, py, pz, x, y, z) <= radius);
}

stock Float:Utils_GetDistanceBetweenPlayers(playerid, targetid)
{
    if (!IsPlayerConnected(playerid) || !IsPlayerConnected(targetid))
    {
        return 99999.0;
    }
    if (GetPlayerInterior(playerid) != GetPlayerInterior(targetid) ||
        GetPlayerVirtualWorld(playerid) != GetPlayerVirtualWorld(targetid))
    {
        return 99999.0;
    }
    new Float:x1, Float:y1, Float:z1;
    new Float:x2, Float:y2, Float:z2;
    GetPlayerPos(playerid, x1, y1, z1);
    GetPlayerPos(targetid, x2, y2, z2);
    return Utils_GetDistance3D(x1, y1, z1, x2, y2, z2);
}

// =============================================================================
//  5. ПУБЛИЧНЫЙ API ФОРМАТИРОВАНИЯ И ПАРСИНГА (Utils_Format* / Utils_Parse*)
// =============================================================================

// Форматирование целой суммы в долларах с разделителями тысяч: $1,250,000
stock Utils_FormatMoney(amountUsd, output[], len = sizeof(output))
{
    new rawDigits[24];
    new bool:isNegative = (amountUsd < 0);
    new absVal = isNegative ? (-amountUsd) : amountUsd;

    format(rawDigits, sizeof(rawDigits), "%d", absVal);
    new const digitCount = strlen(rawDigits);

    new formatted[32];
    new outIdx = 0;

    if (isNegative && outIdx < (sizeof(formatted) - 1))
    {
        formatted[outIdx++] = '-';
    }
    if (outIdx < (sizeof(formatted) - 1))
    {
        formatted[outIdx++] = '$';
    }

    for (new i = 0; i < digitCount && outIdx < (sizeof(formatted) - 1); i++)
    {
        if (i > 0 && ((digitCount - i) % 3 == 0) && outIdx < (sizeof(formatted) - 1))
        {
            formatted[outIdx++] = ',';
        }
        formatted[outIdx++] = rawDigits[i];
    }
    formatted[outIdx] = '\0';

    format(output, len, "%s", formatted);
    return 1;
}

// Форматирование целочисленной массы из граммов в килограммы: "5.80 кг"
stock Utils_FormatWeightGrams(weightGrams, output[], len = sizeof(output))
{
    new const safeGrams = (weightGrams < 0) ? 0 : weightGrams;
    new const kgWhole = GRAMS_TO_KG(safeGrams);
    new const kgHundredths = (GRAMS_REMAINDER(safeGrams) / 10);
    format(output, len, "%d.%02d кг", kgWhole, kgHundredths);
    return 1;
}

// Форматирование целочисленного объема из миллилитров в литры: "4.00 л"
stock Utils_FormatVolumeMl(volumeMl, output[], len = sizeof(output))
{
    new const safeMl = (volumeMl < 0) ? 0 : volumeMl;
    new const litersWhole = ML_TO_LITERS(safeMl);
    new const litersHundredths = (ML_REMAINDER(safeMl) / 10);
    format(output, len, "%d.%02d л", litersWhole, litersHundredths);
    return 1;
}

// Парсинг строки координат вида "1481.0 -1771.0 18.8" или "1481.0, -1771.0, 18.8"
stock bool:Utils_ParseCoords(const input[], &Float:x, &Float:y, &Float:z)
{
    new token[32];
    new const len = strlen(input);
    new pos = 0;
    new found = 0;
    new Float:coords[3];

    while (pos < len && found < 3)
    {
        while (pos < len && (input[pos] == ' ' || input[pos] == ',' || input[pos] == '\t'))
        {
            pos++;
        }
        if (pos >= len)
        {
            break;
        }
        new tIdx = 0;
        while (pos < len && input[pos] != ' ' && input[pos] != ',' && input[pos] != '\t' && tIdx < (sizeof(token) - 1))
        {
            token[tIdx++] = input[pos++];
        }
        token[tIdx] = '\0';
        if (tIdx > 0)
        {
            coords[found++] = floatstr(token);
        }
    }

    if (found < 3)
    {
        return false;
    }
    x = coords[0];
    y = coords[1];
    z = coords[2];
    return true;
}

// =============================================================================
//  6. МОДУЛЬНЫЕ ТЕСТЫ ПРИ ЗАПУСКЕ (hook OnGameModeInit)
// =============================================================================

hook OnGameModeInit()
{
    new ssn1[SSN_STRING_LENGTH], ssn2[SSN_STRING_LENGTH];
    new vin1[VIN_STRING_LENGTH], vin2[VIN_STRING_LENGTH];
    new iban1[IBAN_STRING_LENGTH];
    new moneyStr[24];

    Utils_GenerateSSN(ssn1);
    Utils_GenerateSSN(ssn2);
    Utils_GenerateVIN(vin1);
    Utils_GenerateVIN(vin2);
    Utils_GenerateIBAN(iban1);
    Utils_FormatMoney(1250000, moneyStr);

    new const serial1 = Utils_GenerateWeaponSerial();
    new const serial2 = Utils_GenerateWeaponSerial();

    new const bool:testsPassed = (
        strlen(ssn1) == 11 &&
        strlen(vin1) == 17 &&
        strlen(iban1) == 16 &&
        strcmp(vin1, vin2, false) != 0 &&
        serial1 != serial2 &&
        !strcmp(moneyStr, "$1,250,000", false)
    );

    printf("%s [Core/Utils] Генераторы проверены (%s): SSN=%s, VIN=%s, IBAN=%s, Serial=%d, Money=%s.",
        SERVER_LOG_PREFIX,
        testsPassed ? ("УСПЕШНО") : ("ОШИБКА"),
        ssn1, vin1, iban1, serial1, moneyStr);
    return 1;
}

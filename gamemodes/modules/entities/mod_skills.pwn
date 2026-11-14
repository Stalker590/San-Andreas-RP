/*
 * =============================================================================
 *  SAN ANDREAS RP — Матрица 41 навыка персонажа (0..1000) и нативная синхронизация
 *  Файл:      gamemodes/modules/entities/mod_skills.pwn
 *  Пункт:     ROADMAP [3.2] — Матрица 40+ навыков (entities/mod_skills.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_skills_included
    #endinput
#endif
#define _mod_skills_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ И ПЕРЕЧИСЛЕНИЕ 41 НАВЫКА ПЕРСОНАЖА (E_SKILL_TYPE)
// =============================================================================

#define SKILL_MIN_VALUE                         (0)
#define SKILL_MAX_VALUE                         (1000)
#define TOTAL_SKILL_TYPES                       (41)
#define SKILL_COL_NAME_LEN                      (24)
#define SKILL_DISPLAY_NAME_LEN                  (48)
#define SKILL_CATEGORY_NAME_LEN                 (28)
#define SKILL_SQL_BUFFER_LEN                    (2048)

#define DIALOG_SKILLS_OVERVIEW                  (1020)

enum E_SKILL_TYPE
{
    // 1. Оружейные навыки (18 шт., индексы 0..17)
    SKILL_MELEE_BLUNT = 0,          // Ударно-дробящее оружие (биты, дубинки, кастеты)
    SKILL_MELEE_BLADED,             // Клинковое оружие (ножи, катана)
    SKILL_HEAVY_TOOLS,              // Тяжелый инструмент (лопата, бензопила, лом)
    SKILL_PISTOL,                   // Пистолет 9mm (Colt 45) — WEAPONSKILL_PISTOL
    SKILL_PISTOL_SILENCED,          // Пистолет с глушителем — WEAPONSKILL_PISTOL_SILENCED
    SKILL_DESERT_EAGLE,             // Крупнокалиберный Desert Eagle — WEAPONSKILL_DESERT_EAGLE
    SKILL_SHOTGUN,                  // Помповый дробовик — WEAPONSKILL_SHOTGUN
    SKILL_SAWNOFF_SHOTGUN,          // Обрез двустволки — WEAPONSKILL_SAWNOFF_SHOTGUN
    SKILL_SPAS12_SHOTGUN,           // Боевой дробовик SPAS-12 — WEAPONSKILL_SPAS12_SHOTGUN
    SKILL_MICRO_UZI,                // Пистолет-пулемет Micro Uzi — WEAPONSKILL_MICRO_UZI
    SKILL_TEC9,                     // Пистолет-пулемет Tec-9 (серверный + нативный Uzi)
    SKILL_MP5,                      // Тактический ПП MP5 — WEAPONSKILL_MP5
    SKILL_AK47,                     // Автомат Калашникова AK-47 — WEAPONSKILL_AK47
    SKILL_M4,                       // Штурмовая винтовка M4 — WEAPONSKILL_M4
    SKILL_COUNTRY_RIFLE,            // Охотничья винтовка без оптики
    SKILL_SNIPER_RIFLE,             // Снайперская винтовка — WEAPONSKILL_SNIPERRIFLE
    SKILL_HEAVY_ORDNANCE,           // Тяжелое вооружение (РПГ-7, ПЗРК, огнемет, миниган)
    SKILL_THROWABLES,               // Метательное оружие и спецсредства (гранаты, Молотов)

    // 2. Физические и транспортные навыки (7 шт., индексы 18..24)
    SKILL_STAMINA,                  // Выносливость и дыхание при беге
    SKILL_MUSCLE,                   // Мускулатура (влияет на грузоподъемность W_max и удар)
    SKILL_DRIVING,                  // Вождение легкового и грузового автотранспорта
    SKILL_BIKE,                     // Управление мотоциклами и байками
    SKILL_CYCLING,                  // Управление велосипедами
    SKILL_FLYING,                   // Пилотирование самолетов и вертолетов
    SKILL_LUNG_CAPACITY,            // Объем легких при задержке дыхания под водой

    // 3. Криминальные прикладные навыки (6 шт., индексы 25..30)
    SKILL_LOCKPICKING,              // Вскрытие механических замков отмычками (/lockpick)
    SKILL_HOTWIRING,                // Скрутка проводов зажигания при угоне (/hotwire)
    SKILL_SAFE_CRACKING,            // Взлом бронированных сейфов и хранилищ
    SKILL_PICKPOCKETING,            // Карманные кражи из Слоя 1
    SKILL_DEMOLITIONS,              // Подрывное дело, установка СВУ и детонаторов
    SKILL_STEALTH,                  // Скрытность, бесшумное передвижение и маскировка

    // 4. Ремесло, индустрия и техника (5 шт., индексы 31..35)
    SKILL_MECHANICS,                // Автомеханика, диагностика и кузовной ремонт
    SKILL_GUNSMITHING,              // Оружейное дело, сборка и обслуживание стволов
    SKILL_CHEMISTRY,                // Химический синтез, фармацевтика и варка
    SKILL_MINING_LOGGING,           // Горнорудное дело, нефтедобыча и лесозаготовка
    SKILL_METALLURGY,               // Металлургия, литье стали и штамповка деталей

    // 5. Медицина, криминалистика и выживание (5 шт., индексы 36..40)
    SKILL_FIRST_AID,                // Первая доврачебная помощь и перевязка
    SKILL_SURGERY,                  // Полевая и госпитальная хирургия
    SKILL_SURVIVALISM,              // Автономное выживание, охота и полевая кухня
    SKILL_FORENSICS,                // Криминалистика, баллистика и сбор улик
    SKILL_CHARISMA_BARTER,          // Харизма, торговля и дипломатия

    MAX_SKILL_TYPES                 // Всего: 41 навык
};

// =============================================================================
//  2. ТАБЛИЦА МЕТАДАННЫХ 41 НАВЫКА И СОСТОЯНИЕ ИГРОКОВ (static stock)
// =============================================================================

enum E_SKILL_META_INFO
{
    E_SKILL_TYPE:E_SMETA_ID,
    E_SMETA_SQL_COL[SKILL_COL_NAME_LEN],
    E_SMETA_NAME_RU[SKILL_DISPLAY_NAME_LEN],
    E_SMETA_CATEGORY_RU[SKILL_CATEGORY_NAME_LEN],
    E_SMETA_DEFAULT_VAL,
    E_SMETA_NATIVE_WEAPONSKILL      // -1 если навык чисто серверный, иначе 0..10 (WEAPONSKILL_*)
};

static stock const sSkillMetaTable[TOTAL_SKILL_TYPES][E_SKILL_META_INFO] =
{
    // 1. Оружейные навыки (0..17)
    { SKILL_MELEE_BLUNT,        "melee_blunt",      "Дробящее оружие",              "Оружие",       0,   -1 },
    { SKILL_MELEE_BLADED,       "melee_bladed",     "Клинковое оружие",             "Оружие",       0,   -1 },
    { SKILL_HEAVY_TOOLS,        "heavy_tools",      "Тяжелый инструмент",           "Оружие",       0,   -1 },
    { SKILL_PISTOL,             "pistol",           "Пистолет 9mm",                 "Оружие",       0,   0  },
    { SKILL_PISTOL_SILENCED,    "pistol_silenced",  "Пистолет с глушителем",        "Оружие",       0,   1  },
    { SKILL_DESERT_EAGLE,       "desert_eagle",     "Пистолет Desert Eagle",        "Оружие",       0,   2  },
    { SKILL_SHOTGUN,            "shotgun",          "Помповый дробовик",            "Оружие",       0,   3  },
    { SKILL_SAWNOFF_SHOTGUN,    "sawnoff_shotgun",  "Обрез двустволки",             "Оружие",       0,   4  },
    { SKILL_SPAS12_SHOTGUN,     "spas12_shotgun",   "Боевой дробовик SPAS-12",      "Оружие",       0,   5  },
    { SKILL_MICRO_UZI,          "micro_uzi",        "Пистолет-пулемет Micro Uzi",   "Оружие",       0,   6  },
    { SKILL_TEC9,               "tec9_skill",       "Пистолет-пулемет Tec-9",       "Оружие",       0,   -1 },
    { SKILL_MP5,                "mp5",              "Пистолет-пулемет MP5",         "Оружие",       0,   7  },
    { SKILL_AK47,               "ak47",             "Автомат AK-47",                "Оружие",       0,   8  },
    { SKILL_M4,                 "m4",               "Штурмовая винтовка M4",        "Оружие",       0,   9  },
    { SKILL_COUNTRY_RIFLE,      "country_rifle",    "Охотничья винтовка",           "Оружие",       0,   -1 },
    { SKILL_SNIPER_RIFLE,       "sniper_rifle",     "Снайперская винтовка",         "Оружие",       0,   10 },
    { SKILL_HEAVY_ORDNANCE,     "heavy_ordnance",   "Тяжелое вооружение",           "Оружие",       0,   -1 },
    { SKILL_THROWABLES,         "throwables",       "Метательное и спецсредства",   "Оружие",       0,   -1 },

    // 2. Физические и транспортные навыки (18..24)
    { SKILL_STAMINA,            "stamina",          "Выносливость",                 "Физиология",   100, -1 },
    { SKILL_MUSCLE,             "muscle",           "Мускулатура и сила",           "Физиология",   100, -1 },
    { SKILL_DRIVING,            "driving_skill",    "Вождение автомобиля",          "Транспорт",    100, -1 },
    { SKILL_BIKE,               "bike_skill",       "Управление мотоциклом",        "Транспорт",    100, -1 },
    { SKILL_CYCLING,            "cycling_skill",    "Управление велосипедом",       "Транспорт",    100, -1 },
    { SKILL_FLYING,             "flying_skill",     "Пилотирование авиации",        "Транспорт",    0,   -1 },
    { SKILL_LUNG_CAPACITY,      "lung_capacity",    "Объем легких под водой",       "Физиология",   100, -1 },

    // 3. Криминальные навыки (25..30)
    { SKILL_LOCKPICKING,        "lockpicking",      "Взлом замков отмычками",       "Криминал",     0,   -1 },
    { SKILL_HOTWIRING,          "hotwiring",        "Угон и скрутка проводов",      "Криминал",     0,   -1 },
    { SKILL_SAFE_CRACKING,      "safe_cracking",    "Медвежатник (взлом сейфов)",   "Криминал",     0,   -1 },
    { SKILL_PICKPOCKETING,      "pickpocketing",    "Карманные кражи",              "Криминал",     0,   -1 },
    { SKILL_DEMOLITIONS,        "demolitions",      "Подрывное дело и СВУ",         "Криминал",     0,   -1 },
    { SKILL_STEALTH,            "stealth",          "Скрытность и маскировка",      "Криминал",     0,   -1 },

    // 4. Ремесло и техника (31..35)
    { SKILL_MECHANICS,          "mechanics",        "Автомеханика и ремонт",        "Ремесло",      0,   -1 },
    { SKILL_GUNSMITHING,        "gunsmithing",      "Оружейное ремесло",            "Ремесло",      0,   -1 },
    { SKILL_CHEMISTRY,          "chemistry",        "Химия и фармацевтика",         "Ремесло",      0,   -1 },
    { SKILL_MINING_LOGGING,     "mining_logging",   "Горное дело и лесоповал",      "Ремесло",      0,   -1 },
    { SKILL_METALLURGY,         "metallurgy",       "Металлургия и прокат",         "Ремесло",      0,   -1 },

    // 5. Медицина и выживание (36..40)
    { SKILL_FIRST_AID,          "first_aid",        "Первая медицинская помощь",    "Медицина",     0,   -1 },
    { SKILL_SURGERY,            "surgery",          "Полевая хирургия",             "Медицина",     0,   -1 },
    { SKILL_SURVIVALISM,        "survivalism",      "Автономное выживание",         "Выживание",    0,   -1 },
    { SKILL_FORENSICS,          "forensics",        "Криминалистика и улики",       "Следствие",    0,   -1 },
    { SKILL_CHARISMA_BARTER,    "charisma_barter",  "Харизма и торговля",           "Социум",       0,   -1 }
};

static stock sPlayerSkills[MAX_PLAYERS][TOTAL_SKILL_TYPES];
static stock sPlayerSkillCaps[MAX_PLAYERS][TOTAL_SKILL_TYPES];
static stock FIGHT_STYLE:sPlayerFightingStyle[MAX_PLAYERS];
static stock sPlayerSkillCharDbId[MAX_PLAYERS];
static stock sSkillsSqlBuffer[SKILL_SQL_BUFFER_LEN];

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (static stock)
// =============================================================================

static stock Internal_ClampSkillValue(value, maxCap)
{
    if (maxCap < SKILL_MIN_VALUE)
    {
        maxCap = SKILL_MIN_VALUE;
    }
    if (maxCap > SKILL_MAX_VALUE)
    {
        maxCap = SKILL_MAX_VALUE;
    }
    if (value < SKILL_MIN_VALUE)
    {
        return SKILL_MIN_VALUE;
    }
    if (value > maxCap)
    {
        return maxCap;
    }
    return value;
}

static stock Internal_FormatFightingStyleRu(FIGHT_STYLE:style, output[], len = sizeof(output))
{
    switch (style)
    {
        case FIGHT_STYLE_BOXING:    format(output, len, "Классический бокс");
        case FIGHT_STYLE_KUNGFU:    format(output, len, "Кунг-фу");
        case FIGHT_STYLE_KNEEHEAD:  format(output, len, "Уличный клинч (колено в голову)");
        case FIGHT_STYLE_GRABKICK:  format(output, len, "Захват и добивание ногой");
        case FIGHT_STYLE_ELBOW:     format(output, len, "Удары локтями");
        default:                    format(output, len, "Стандартный уличный бой");
    }
}

static stock Internal_BuildSkillsUpdateQuery(playerid, char_db_id, output[], len = sizeof(output))
{
    output[0] = EOS;
    if (char_db_id <= 0)
    {
        return 0;
    }

    new pos = format(output, len, "UPDATE `character_skills` SET ");
    for (new i = 0; i < _:MAX_SKILL_TYPES; i++)
    {
        pos += format(
            output[pos],
            len - pos,
            "%s`%s` = %d",
            (i == 0) ? ("") : (", "),
            sSkillMetaTable[i][E_SMETA_SQL_COL],
            sPlayerSkills[playerid][i]);
    }
    format(output[pos], len - pos, " WHERE `char_id` = %d;", char_db_id);
    return 1;
}

// =============================================================================
//  4. АСИНХРОННЫЕ КОЛБЕКИ ЗАГРУЗКИ НАВЫКОВ ИЗ БД (forward / public)
// =============================================================================

forward OnCharacterSkillsLoaded(playerid, char_db_id, sessionToken);
public OnCharacterSkillsLoaded(playerid, char_db_id, sessionToken)
{
    if (!Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 1;
    }

    sPlayerSkillCharDbId[playerid] = char_db_id;

    new rows = 0;
    cache_get_row_count(rows);

    if (rows <= 0)
    {
        // Если строка навыков еще не создана — создаем ее со значениями по умолчанию/шаблона
        Skills_InsertInitialRow(playerid, char_db_id);
        Skills_SyncNative(playerid);
        return 1;
    }

    for (new i = 0; i < _:MAX_SKILL_TYPES; i++)
    {
        new loadedVal = sSkillMetaTable[i][E_SMETA_DEFAULT_VAL];
        cache_get_value_name_int(0, sSkillMetaTable[i][E_SMETA_SQL_COL], loadedVal);
        sPlayerSkills[playerid][i] = Internal_ClampSkillValue(loadedVal, sPlayerSkillCaps[playerid][i]);
    }

    Skills_SyncNative(playerid);
    return 1;
}

// =============================================================================
//  5. ПУБЛИЧНЫЙ API МАТРИЦЫ НАВЫКОВ (Skills_*)
// =============================================================================

stock Skills_ResetDefaults(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }

    sPlayerSkillCharDbId[playerid] = 0;
    sPlayerFightingStyle[playerid] = FIGHT_STYLE_NORMAL;

    for (new i = 0; i < _:MAX_SKILL_TYPES; i++)
    {
        sPlayerSkillCaps[playerid][i] = SKILL_MAX_VALUE;
        sPlayerSkills[playerid][i] = sSkillMetaTable[i][E_SMETA_DEFAULT_VAL];
    }
    return 1;
}

stock Skills_BindCharacterId(playerid, char_db_id)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    sPlayerSkillCharDbId[playerid] = char_db_id;
    return 1;
}

stock Skills_SyncNative(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !IsPlayerConnected(playerid))
    {
        return 0;
    }

    // Синхронизация всех 11 нативных оружейных скиллов движка GTA SA (0..999)
    SetPlayerSkillLevel(playerid, WEAPONSKILL_PISTOL,          sPlayerSkills[playerid][_:SKILL_PISTOL]);
    SetPlayerSkillLevel(playerid, WEAPONSKILL_PISTOL_SILENCED, sPlayerSkills[playerid][_:SKILL_PISTOL_SILENCED]);
    SetPlayerSkillLevel(playerid, WEAPONSKILL_DESERT_EAGLE,    sPlayerSkills[playerid][_:SKILL_DESERT_EAGLE]);
    SetPlayerSkillLevel(playerid, WEAPONSKILL_SHOTGUN,         sPlayerSkills[playerid][_:SKILL_SHOTGUN]);
    SetPlayerSkillLevel(playerid, WEAPONSKILL_SAWNOFF_SHOTGUN, sPlayerSkills[playerid][_:SKILL_SAWNOFF_SHOTGUN]);
    SetPlayerSkillLevel(playerid, WEAPONSKILL_SPAS12_SHOTGUN,  sPlayerSkills[playerid][_:SKILL_SPAS12_SHOTGUN]);

    // Для слота ПП (Micro Uzi / Tec-9) берем максимум или профильный навык
    new uziNativeLevel = sPlayerSkills[playerid][_:SKILL_MICRO_UZI];
    if (sPlayerSkills[playerid][_:SKILL_TEC9] > uziNativeLevel)
    {
        uziNativeLevel = sPlayerSkills[playerid][_:SKILL_TEC9];
    }
    SetPlayerSkillLevel(playerid, WEAPONSKILL_MICRO_UZI,       uziNativeLevel);
    SetPlayerSkillLevel(playerid, WEAPONSKILL_MP5,             sPlayerSkills[playerid][_:SKILL_MP5]);
    SetPlayerSkillLevel(playerid, WEAPONSKILL_AK47,            sPlayerSkills[playerid][_:SKILL_AK47]);
    SetPlayerSkillLevel(playerid, WEAPONSKILL_M4,              sPlayerSkills[playerid][_:SKILL_M4]);
    SetPlayerSkillLevel(playerid, WEAPONSKILL_SNIPERRIFLE,     sPlayerSkills[playerid][_:SKILL_SNIPER_RIFLE]);

    // Синхронизация рукопашного стиля боя GTA SA
    SetPlayerFightingStyle(playerid, sPlayerFightingStyle[playerid]);
    return 1;
}

stock Skills_Get(playerid, E_SKILL_TYPE:skill)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    if (_:skill < 0 || _:skill >= _:MAX_SKILL_TYPES)
    {
        return 0;
    }
    return sPlayerSkills[playerid][_:skill];
}

stock Skills_GetCap(playerid, E_SKILL_TYPE:skill)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return SKILL_MAX_VALUE;
    }
    if (_:skill < 0 || _:skill >= _:MAX_SKILL_TYPES)
    {
        return SKILL_MAX_VALUE;
    }
    return sPlayerSkillCaps[playerid][_:skill];
}

stock Skills_SetCap(playerid, E_SKILL_TYPE:skill, maxCap)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    if (_:skill < 0 || _:skill >= _:MAX_SKILL_TYPES)
    {
        return 0;
    }

    if (maxCap < SKILL_MIN_VALUE) maxCap = SKILL_MIN_VALUE;
    if (maxCap > SKILL_MAX_VALUE) maxCap = SKILL_MAX_VALUE;

    sPlayerSkillCaps[playerid][_:skill] = maxCap;
    if (sPlayerSkills[playerid][_:skill] > maxCap)
    {
        sPlayerSkills[playerid][_:skill] = maxCap;
    }
    return 1;
}

stock Skills_CapAllWeaponSkills(playerid, maxCap)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    for (new i = _:SKILL_MELEE_BLUNT; i <= _:SKILL_THROWABLES; i++)
    {
        Skills_SetCap(playerid, E_SKILL_TYPE:i, maxCap);
        sPlayerSkills[playerid][i] = Internal_ClampSkillValue(sPlayerSkills[playerid][i], maxCap);
    }
    return 1;
}

stock Skills_CapAllCriminalSkills(playerid, maxCap)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    for (new i = _:SKILL_LOCKPICKING; i <= _:SKILL_STEALTH; i++)
    {
        Skills_SetCap(playerid, E_SKILL_TYPE:i, maxCap);
        sPlayerSkills[playerid][i] = Internal_ClampSkillValue(sPlayerSkills[playerid][i], maxCap);
    }
    return 1;
}

stock Skills_Set(playerid, E_SKILL_TYPE:skill, value, bool:syncAndSave = true)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    if (_:skill < 0 || _:skill >= _:MAX_SKILL_TYPES)
    {
        return 0;
    }

    new const clamped = Internal_ClampSkillValue(value, sPlayerSkillCaps[playerid][_:skill]);
    sPlayerSkills[playerid][_:skill] = clamped;

    if (syncAndSave)
    {
        if (sSkillMetaTable[_:skill][E_SMETA_NATIVE_WEAPONSKILL] != -1 || skill == SKILL_TEC9)
        {
            Skills_SyncNative(playerid);
        }

        if (sPlayerSkillCharDbId[playerid] > 0 && DB_IsConnected())
        {
            new updateQuery[160];
            mysql_format(gMySQL, updateQuery, sizeof(updateQuery),
                "UPDATE `character_skills` SET `%s` = %d WHERE `char_id` = %d;",
                sSkillMetaTable[_:skill][E_SMETA_SQL_COL],
                clamped,
                sPlayerSkillCharDbId[playerid]);
            mysql_tquery(gMySQL, updateQuery);
        }
    }
    return clamped;
}

stock Skills_Add(playerid, E_SKILL_TYPE:skill, delta)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    if (_:skill < 0 || _:skill >= _:MAX_SKILL_TYPES || delta == 0)
    {
        return Skills_Get(playerid, skill);
    }

    new const oldVal = sPlayerSkills[playerid][_:skill];
    new const maxCap = sPlayerSkillCaps[playerid][_:skill];
    new const newVal = Internal_ClampSkillValue(oldVal + delta, maxCap);

    if (newVal == oldVal)
    {
        return oldVal;
    }

    sPlayerSkills[playerid][_:skill] = newVal;

    if (sSkillMetaTable[_:skill][E_SMETA_NATIVE_WEAPONSKILL] != -1 || skill == SKILL_TEC9)
    {
        Skills_SyncNative(playerid);
    }

    // Уведомление игрока при достижении нового десятка или сотни единиц мастерства
    if (delta > 0 && IsPlayerConnected(playerid) && ((newVal / 25) > (oldVal / 25) || newVal == maxCap))
    {
        new msg[144];
        format(msg, sizeof(msg),
            "Навык «%s» повышен до %d / %d ед.",
            sSkillMetaTable[_:skill][E_SMETA_NAME_RU],
            newVal,
            maxCap);
        SendClientMessage(playerid, COLOR_UI_INFO, msg);
    }

    if (sPlayerSkillCharDbId[playerid] > 0 && DB_IsConnected())
    {
        new updateQuery[160];
        mysql_format(gMySQL, updateQuery, sizeof(updateQuery),
            "UPDATE `character_skills` SET `%s` = %d WHERE `char_id` = %d;",
            sSkillMetaTable[_:skill][E_SMETA_SQL_COL],
            newVal,
            sPlayerSkillCharDbId[playerid]);
        mysql_tquery(gMySQL, updateQuery);
    }

    return newVal;
}

stock FIGHT_STYLE:Skills_GetFightingStyle(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return FIGHT_STYLE_NORMAL;
    }
    return sPlayerFightingStyle[playerid];
}

stock Skills_SetFightingStyle(playerid, FIGHT_STYLE:style, bool:syncNative = true)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    sPlayerFightingStyle[playerid] = style;
    if (syncNative && IsPlayerConnected(playerid))
    {
        SetPlayerFightingStyle(playerid, style);
    }
    return 1;
}

stock Skills_GetNameRu(E_SKILL_TYPE:skill, output[], len = sizeof(output))
{
    if (_:skill < 0 || _:skill >= _:MAX_SKILL_TYPES)
    {
        format(output, len, "Неизвестный навык");
        return 0;
    }
    format(output, len, "%s", sSkillMetaTable[_:skill][E_SMETA_NAME_RU]);
    return 1;
}

stock Skills_GetCategoryRu(E_SKILL_TYPE:skill, output[], len = sizeof(output))
{
    if (_:skill < 0 || _:skill >= _:MAX_SKILL_TYPES)
    {
        format(output, len, "Общее");
        return 0;
    }
    format(output, len, "%s", sSkillMetaTable[_:skill][E_SMETA_CATEGORY_RU]);
    return 1;
}

stock Skills_GetColumnName(E_SKILL_TYPE:skill, output[], len = sizeof(output))
{
    if (_:skill < 0 || _:skill >= _:MAX_SKILL_TYPES)
    {
        output[0] = EOS;
        return 0;
    }
    format(output, len, "%s", sSkillMetaTable[_:skill][E_SMETA_SQL_COL]);
    return 1;
}

stock E_SKILL_TYPE:Skills_FindByColumnName(const colName[])
{
    if (colName[0] == EOS)
    {
        return MAX_SKILL_TYPES;
    }
    for (new i = 0; i < _:MAX_SKILL_TYPES; i++)
    {
        if (!strcmp(sSkillMetaTable[i][E_SMETA_SQL_COL], colName, true))
        {
            return E_SKILL_TYPE:i;
        }
    }
    return MAX_SKILL_TYPES;
}

stock Skills_InsertInitialRow(playerid, char_db_id)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || char_db_id <= 0)
    {
        return 0;
    }

    sPlayerSkillCharDbId[playerid] = char_db_id;

    if (!DB_IsConnected())
    {
        return 1;
    }

    sSkillsSqlBuffer[0] = EOS;
    new pos = format(sSkillsSqlBuffer, sizeof(sSkillsSqlBuffer),
        "INSERT INTO `character_skills` (`char_id`");

    for (new i = 0; i < _:MAX_SKILL_TYPES; i++)
    {
        pos += format(
            sSkillsSqlBuffer[pos],
            sizeof(sSkillsSqlBuffer) - pos,
            ", `%s`",
            sSkillMetaTable[i][E_SMETA_SQL_COL]);
    }

    pos += format(
        sSkillsSqlBuffer[pos],
        sizeof(sSkillsSqlBuffer) - pos,
        ") VALUES (%d",
        char_db_id);

    for (new i = 0; i < _:MAX_SKILL_TYPES; i++)
    {
        pos += format(
            sSkillsSqlBuffer[pos],
            sizeof(sSkillsSqlBuffer) - pos,
            ", %d",
            sPlayerSkills[playerid][i]);
    }

    format(
        sSkillsSqlBuffer[pos],
        sizeof(sSkillsSqlBuffer) - pos,
        ") ON DUPLICATE KEY UPDATE `stamina` = VALUES(`stamina`), `muscle` = VALUES(`muscle`);");

    mysql_tquery(gMySQL, sSkillsSqlBuffer);
    return 1;
}

stock Skills_LoadFromDB(playerid, char_db_id)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || char_db_id <= 0)
    {
        return 0;
    }

    sPlayerSkillCharDbId[playerid] = char_db_id;

    if (!DB_IsConnected())
    {
        Skills_SyncNative(playerid);
        return 1;
    }

    mysql_format(gMySQL, sSkillsSqlBuffer, sizeof(sSkillsSqlBuffer),
        "SELECT * FROM `character_skills` WHERE `char_id` = %d LIMIT 1;",
        char_db_id);

    mysql_tquery(gMySQL, sSkillsSqlBuffer, "OnCharacterSkillsLoaded", "ddd",
        playerid, char_db_id, Config_GetPlayerSessionToken(playerid));
    return 1;
}

stock Skills_SaveAllAsync(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return 0;
    }
    new const charDbId = sPlayerSkillCharDbId[playerid];
    if (charDbId <= 0 || !DB_IsConnected())
    {
        return 0;
    }

    if (Internal_BuildSkillsUpdateQuery(playerid, charDbId, sSkillsSqlBuffer, sizeof(sSkillsSqlBuffer)))
    {
        mysql_tquery(gMySQL, sSkillsSqlBuffer);
    }
    return 1;
}

stock Skills_ShowDialog(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !IsPlayerConnected(playerid))
    {
        return 0;
    }

    new dialogBody[3584];
    new fightStyleName[40];
    Internal_FormatFightingStyleRu(sPlayerFightingStyle[playerid], fightStyleName);

    new pos = format(dialogBody, sizeof(dialogBody),
        "Навык персонажа\tКатегория\tУровень / Потолок\n\
        {FFC800}Стиль рукопашного боя{FFFFFF}\t{AFAFAF}Боевое искусство{FFFFFF}\t{66CC66}%s{FFFFFF}\n",
        fightStyleName);

    for (new i = 0; i < _:MAX_SKILL_TYPES; i++)
    {
        new const val = sPlayerSkills[playerid][i];
        new const cap = sPlayerSkillCaps[playerid][i];

        new colorHex[10];
        if (cap == 0)
        {
            format(colorHex, sizeof(colorHex), "{FF4444}");
        }
        else if (val >= 750)
        {
            format(colorHex, sizeof(colorHex), "{66CC66}");
        }
        else if (val >= 350)
        {
            format(colorHex, sizeof(colorHex), "{FFC800}");
        }
        else
        {
            format(colorHex, sizeof(colorHex), "{FFFFFF}");
        }

        pos += format(
            dialogBody[pos],
            sizeof(dialogBody) - pos,
            "{FFFFFF}%s\t{AFAFAF}%s\t%s%d / %d{FFFFFF}\n",
            sSkillMetaTable[i][E_SMETA_NAME_RU],
            sSkillMetaTable[i][E_SMETA_CATEGORY_RU],
            colorHex,
            val,
            cap);
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_SKILLS_OVERVIEW,
        DIALOG_STYLE_TABLIST_HEADERS,
        "{FFC800}SAN ANDREAS RP {FFFFFF}| Матрица навыков персонажа (41 навык)",
        dialogBody,
        "Закрыть",
        "");
    return 1;
}

// =============================================================================
//  6. СИСТЕМНЫЕ ХУКИ И КОМАНДЫ (y_hooks & Pawn.CMD)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        Skills_ResetDefaults(i);
    }

    // Самопроверка матрицы 41 навыка
    Skills_ResetDefaults(0);
    Skills_Set(0, SKILL_AK47, 950, false);
    Skills_Set(0, SKILL_LOCKPICKING, 750, false);
    new const akCheck = Skills_Get(0, SKILL_AK47);
    new const lockCheck = Skills_Get(0, SKILL_LOCKPICKING);
    Skills_ResetDefaults(0);

    printf("%s [Entities/Skills] Матрица %d навыков инициализирована (тест AK47=%d, LOCKPICKING=%d: %s).",
        SERVER_LOG_PREFIX,
        _:MAX_SKILL_TYPES,
        akCheck,
        lockCheck,
        (akCheck == 950 && lockCheck == 750) ? ("УСПЕШНО") : ("ОШИБКА"));
    return 1;
}

hook OnPlayerConnect(playerid)
{
    Skills_ResetDefaults(playerid);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    Skills_ResetDefaults(playerid);
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused playerid, response, listitem, inputtext
    if (dialogid == DIALOG_SKILLS_OVERVIEW)
    {
        return Y_HOOKS_BREAK_RETURN_1;
    }
    return Y_HOOKS_CONTINUE_RETURN_0;
}

CMD:skills(playerid, params[])
{
    #pragma unused params
    if (!Account_IsLogged(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Для просмотра матрицы навыков необходимо авторизоваться на сервере.");
        return 1;
    }
    Skills_ShowDialog(playerid);
    return 1;
}
alias:skills("myskills");

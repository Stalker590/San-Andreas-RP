/*
 * =============================================================================
 *  SAN ANDREAS RP — Конфигуратор 25 стартовых ролей, перков и стартовых наборов
 *  Файл:      gamemodes/modules/entities/mod_roles.pwn
 *  Пункт:     ROADMAP [3.3] — Конфигуратор 25 стартовых ролей (entities/mod_roles.pwn)
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_roles_included
    #endinput
#endif
#define _mod_roles_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ, СТАТУС ГРАЖДАНСТВА И БИТОВАЯ МАСКА УНИКАЛЬНЫХ ПЕРКОВ РОЛЕЙ
// =============================================================================

#define MAX_STARTER_ROLES                       (25)
#define MAX_ROLE_SKILL_BONUSES                  (5)
#define MAX_ROLE_STARTER_ITEMS                  (6)
#define ROLE_TITLE_MAX_LEN                      (44)
#define ROLE_SUBTITLE_MAX_LEN                   (48)
#define ROLE_DESC_MAX_LEN                       (256)
#define ROLE_SELECTION_DIALOG_BUFFER_SIZE       (4096)

enum E_CITIZENSHIP_TYPE
{
    CITIZENSHIP_NONE = 0,
    CITIZENSHIP_CITIZEN = 1,        // Гражданин США (выдается SSN, паспорт, банковский счет)
    CITIZENSHIP_IMMIGRANT = 2       // Негражданин / Иммигрант (без SSN, риск депортации ICE)
};

// Битовая маска уникальных пожизненных перков и дебаффов 25 ролей (раздел 9 GDD)
enum E_ROLE_PERK_FLAGS (<<= 1)
{
    PERK_NONE                       = 0,
    PERK_LOW_METABOLISM_60          = 1,    // №1 Бомж: -60% расхода еды и воды
    PERK_NO_POISON                  = 2,    // №1 Бомж: иммунитет к пищевым отравлениям и -50% внимания копов
    PERK_DRUG_BOOST_25X             = 4,    // №2 Наркоман: наркотики действуют в 2.5 раза дольше и лечат +35 HP
    PERK_WITHDRAWAL_40M             = 8,    // №2 Наркоман: ломка каждые 40 минут без дозы
    PERK_DOUBLE_LAYER2              = 16,   // №3 Проститутка: потайной Слой 2 увеличен в 2 раза
    PERK_SHOCK_IMMUNE               = 32,   // №4 Психопат: иммунитет к болевому шоку и контузии
    PERK_NO_WEAPON_LIC              = 64,   // №4 Психопат: пожизненный запрет на лицензию на оружие
    PERK_TAX_DISCOUNT_20            = 128,  // №5 Гражданский: -20% налоги/комиссии и +20% к зарплате госработ
    PERK_RIFLE_WEAR_MINUS_30        = 256,  // №6 Ветеран: -30% износ винтовок, но контузия от взрывов вдвое дольше
    PERK_FAST_DEMOLITION            = 512,  // №7 Подрывник: быстрый взлом электроники и установка взрывчатки
    PERK_SPEED_BONUS_10             = 1024, // №8 Автомеханик: +10 км/ч к макс. скорости авто, ремонт в 2 раза быстрее
    PERK_LOCKPICK_BONUS_35          = 2048, // №9 Хулиган: +35% шанс успешного вскрытия замков /lockpick
    PERK_CORP_DISCOUNT_25           = 4096, // №10 Олигарх: -25% стоимость регистрации корпораций и покупки коммерции
    PERK_COP_SENSE                  = 8192, // №11 Отставной Коп: видит улики без приборов, +30% наценка черного рынка
    PERK_FAST_REVIVE                = 16384,// №12 Хирург: поднимает из PK в 2 раза быстрее и сразу с 50 HP
    PERK_CONTAINER_LOOT_20          = 32768,// №13 Грузчик: +20% шанс редкого товара в портовых контейнерах
    PERK_TRUCKER_BONUS_20           = 65536,// №14 Дальнобойщик: +20% оплата за грузы и -15% расход топлива
    PERK_CHEM_YIELD_40              = 131072,// №15 Варщик: +40% выхода препаратов/наркотиков, x2 урон взрыва лабы
    PERK_FIELD_GUNSMITH             = 262144,// №16 Оружейник: ремонт стволов в поле, -25% металла при сборке
    PERK_NO_BIKE_FALL               = 524288,// №17 Байкер: повышенная устойчивость на мотоциклах
    PERK_RADAR_STEALTH_50           = 1048576,// №18 Пилот: радары копов засекают на 50% ближе
    PERK_FOREST_RUNNER              = 2097152,// №19 Реднек: -30% расхода стамины вне городов, стресс в мегаполисах
    PERK_MINING_YIELD_35            = 4194304,// №20 Шахтер: +35% к добыче руды и леса
    PERK_HIGH_METABOLISM            = 8388608,// №21 Качок: сбивает с ног 1 ударом, расход еды/воды в 1.5 раза выше
    PERK_SILENT_PICKPOCKET          = 16777216,// №22 Карманник: незаметная кража из Слоя 1, сниженный запас HP
    PERK_FIRE_RESIST_50             = 33554432,// №23 Сектант: -50% урона от огня, +30% радиус Молотова, запрет банков
    PERK_ARMOR_BONUS_20             = 67108864,// №24 Спецназовец: +20% прочности брони, выбивание дверей с 1 удара
    PERK_FINE_WANTED_HALF           = 134217728// №25 Сын Депутата: штрафы и розыск до 10 режутся вдвое
};

// =============================================================================
//  2. СТРУКТУРЫ ШАБЛОНА РОЛИ И КОНСТАНТНАЯ ТАБЛИЦА 25 РОЛЕЙ (gRoleConfigs)
// =============================================================================

enum E_ROLE_TEMPLATE
{
    E_ROLE_ID,                                  // 1..25
    E_ROLE_NAME_RU[ROLE_TITLE_MAX_LEN],         // Русское название роли
    E_ROLE_SUBTITLE[ROLE_SUBTITLE_MAX_LEN],     // Русский ролевой архетип / подзаголовок для UI
    E_ROLE_DESC_RU[ROLE_DESC_MAX_LEN],          // Краткое описание бонусов и минусов для UI
    E_CITIZENSHIP_TYPE:E_ROLE_CITIZENSHIP,      // CITIZEN или IMMIGRANT
    E_ROLE_START_CASH_USD,                      // Стартовые наличные USD в Слое 1
    E_ROLE_START_BANK_USD,                      // Стартовый безналичный баланс в банке
    E_ROLE_START_DEBT_USD,                      // Стартовый банковский долг
    E_ROLE_START_WANTED,                        // Стартовый уровень розыска (0..100)
    Float:E_ROLE_START_HP,                      // Стартовый запас здоровья HP
    Float:E_ROLE_START_ARMOUR,                  // Стартовая броня
    Float:E_ROLE_START_ADDICTION,               // Стартовый уровень зависимости (0.0..100.0)
    E_ROLE_WEIGHT_BONUS_G,                      // Модификатор грузоподъемности в граммах (-10000..+25000)
    FIGHT_STYLE:E_ROLE_FIGHT_STYLE,             // Рукопашный стиль боя
    E_ROLE_SKIN_MALE,                           // Каноничный мужской скин роли
    E_ROLE_SKIN_FEMALE,                         // Каноничный женский скин роли
    bool:E_ROLE_ZERO_WEAPON_SKILLS,             // Запрет на прокачку оружия (потолок 0)
    bool:E_ROLE_ZERO_CRIMINAL_SKILLS,           // Запрет на прокачку криминала (потолок 0)
    E_SKILL_TYPE:E_ROLE_CAP_SKILL_TYPE,         // Ограничиваемый навык (или MAX_SKILL_TYPES)
    E_ROLE_CAP_SKILL_MAX,                       // Максимальный потолок для E_ROLE_CAP_SKILL_TYPE
    E_ROLE_PERK_FLAGS:E_ROLE_PERKS,             // Битовая маска уникальных перков
    Float:E_ROLE_SPAWN_X,                       // Лор-точка спавна X
    Float:E_ROLE_SPAWN_Y,                       // Лор-точка спавна Y
    Float:E_ROLE_SPAWN_Z,                       // Лор-точка спавна Z
    Float:E_ROLE_SPAWN_A,                       // Угол поворота A
    E_ROLE_SPAWN_INTERIOR,                      // Интерьер спавна
    E_ROLE_SPAWN_VW,                            // Виртуальный мир спавна

    // До 5 профильных бонусов к навыкам при создании
    E_SKILL_TYPE:E_ROLE_SKILL_1, E_ROLE_SKILL_VAL_1,
    E_SKILL_TYPE:E_ROLE_SKILL_2, E_ROLE_SKILL_VAL_2,
    E_SKILL_TYPE:E_ROLE_SKILL_3, E_ROLE_SKILL_VAL_3,
    E_SKILL_TYPE:E_ROLE_SKILL_4, E_ROLE_SKILL_VAL_4,
    E_SKILL_TYPE:E_ROLE_SKILL_5, E_ROLE_SKILL_VAL_5,

    // До 6 стартовых предметов из реестра item_definitions (ID, кол-во, патроны в стволе)
    E_ROLE_ITEM_ID_1, E_ROLE_ITEM_AMT_1, E_ROLE_ITEM_AMMO_1,
    E_ROLE_ITEM_ID_2, E_ROLE_ITEM_AMT_2, E_ROLE_ITEM_AMMO_2,
    E_ROLE_ITEM_ID_3, E_ROLE_ITEM_AMT_3, E_ROLE_ITEM_AMMO_3,
    E_ROLE_ITEM_ID_4, E_ROLE_ITEM_AMT_4, E_ROLE_ITEM_AMMO_4,
    E_ROLE_ITEM_ID_5, E_ROLE_ITEM_AMT_5, E_ROLE_ITEM_AMMO_5,
    E_ROLE_ITEM_ID_6, E_ROLE_ITEM_AMT_6, E_ROLE_ITEM_AMMO_6
};

static stock sRoleInitCheckBuffer[ROLE_SELECTION_DIALOG_BUFFER_SIZE];

// Полная константная таблица всех 25 стартовых ролей из раздела 9 GDD
stock const gRoleConfigs[MAX_STARTER_ROLES][E_ROLE_TEMPLATE] =
{
    // 1. Бомж-Выживальщик
    {
        1, "Бомж-Выживальщик", "Обитатель подворотен",
        "Выносливость 700, Выживание 850, Скрытность 600. Расход еды и воды снижен на 60%, иммунитет к отравлениям. Минус: оружейные навыки заблокированы (0).",
        CITIZENSHIP_CITIZEN, 10, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_NORMAL, 78, 77,
        true, false, MAX_SKILL_TYPES, 1000,
        PERK_LOW_METABOLISM_60 | PERK_NO_POISON,
        2066.50, -1703.20, 14.15, 90.0, 0, 0,
        SKILL_STAMINA, 700, SKILL_SURVIVALISM, 850, SKILL_STEALTH, 600, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        61, 1, 0,   64, 1, 0,   65, 1, 0,   0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 2. Наркоман
    {
        2, "Наркоман", "Уличный торчок",
        "Выносливость 800, Скрытность 500. Препараты действуют в 2.5 раза дольше и восстанавливают +35 HP, снимая болевой шок. Минус: тяжелая ломка каждые 40 минут.",
        CITIZENSHIP_CITIZEN, 45, 0, 0, 0, 100.0, 0.0, 65.0, 0, FIGHT_STYLE_NORMAL, 137, 64,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_DRUG_BOOST_25X | PERK_WITHDRAWAL_40M,
        2165.40, -1675.10, 15.08, 180.0, 0, 0,
        SKILL_STAMINA, 800, SKILL_STEALTH, 500, SKILL_MELEE_BLADED, 400, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        66, 3, 0,   67, 2, 0,   4, 1, 0,    0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 3. Уличная Проститутка
    {
        3, "Уличная Проститутка", "Ночная бабочка",
        "Харизма 750, Карманные кражи 500. Пистолет 9mm (15 патр.). Потайной Слой 2 увеличен в 2 раза (не виден при обычном досмотре). Минус: Мускулатура не выше 300.",
        CITIZENSHIP_CITIZEN, 350, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_NORMAL, 249, 244,
        false, false, SKILL_MUSCLE, 300,
        PERK_DOUBLE_LAYER2,
        2122.80, -1784.60, 13.55, 0.0, 0, 0,
        SKILL_CHARISMA_BARTER, 750, SKILL_PICKPOCKETING, 500, SKILL_PISTOL, 300, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        50, 1, 0,   65, 1, 0,   13, 1, 15,  52, 1, 0,   0, 0, 0,    0, 0, 0
    },

    // 4. Конченый Психопат
    {
        4, "Конченый Психопат", "Отмороженный маньяк",
        "Мускулатура 1000, Скрытность 700, стиль боя Колено в голову. Полный иммунитет к болевому шоку и контузии. Минус: пожизненный запрет на лицензию на оружие.",
        CITIZENSHIP_CITIZEN, 150, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_KNEEHEAD, 160, 198,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_SHOCK_IMMUNE | PERK_NO_WEAPON_LIC,
        1278.40, 297.20, 19.55, 270.0, 0, 0,
        SKILL_MUSCLE, 1000, SKILL_STEALTH, 700, SKILL_MELEE_BLUNT, 800, SKILL_HEAVY_TOOLS, 800, MAX_SKILL_TYPES, 0,
        6, 1, 0,    1, 1, 0,    43, 1, 0,   0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 5. Обычный Гражданский
    {
        5, "Обычный Гражданский", "Законопослушный житель",
        "Харизма 500, Вождение 500. Стартовый рюкзак, смартфон, карта и $1,500. Скидка 20% на налоги и +20% к зарплате на госработах. Минус: криминальные навыки = 0.",
        CITIZENSHIP_CITIZEN, 1500, 500, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_NORMAL, 26, 93,
        false, true, MAX_SKILL_TYPES, 1000,
        PERK_TAX_DISCOUNT_20,
        1742.90, -1862.40, 13.57, 0.0, 0, 0,
        SKILL_CHARISMA_BARTER, 500, SKILL_DRIVING, 500, SKILL_STAMINA, 350, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        50, 1, 0,   41, 1, 0,   63, 2, 0,   61, 1, 0,   52, 1, 0,   0, 0, 0
    },

    // 6. Боевой Ветеран
    {
        6, "Боевой Ветеран", "Ветеран горячих точек",
        "Винтовка M4 (200 патр.) с лицензией, нож, сухпаек. Навыки: M4 900, Пистолет 700, Выносливость 850, Выживание 600. Износ винтовок -30%. Минус: долгая контузия.",
        CITIZENSHIP_CITIZEN, 400, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_KUNGFU, 287, 191,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_RIFLE_WEAR_MINUS_30,
        2288.20, -82.40, 26.48, 180.0, 0, 0,
        SKILL_M4, 900, SKILL_PISTOL, 700, SKILL_STAMINA, 850, SKILL_SURVIVALISM, 600, MAX_SKILL_TYPES, 0,
        23, 1, 200, 69, 1, 0,   4, 1, 0,    62, 1, 0,   0, 0, 0,    0, 0, 0
    },

    // 7. Джихадист-Подрывник
    {
        7, "Джихадист-Подрывник", "Радикальный подрывник",
        "Автомат AK-47 (150 патр. без лицензии), взрывпакет с детонатором, болторез, балаклава. Навыки: AK-47 950, Подрывное дело 1000, Оружейник 650. Минус: старт с 5 уровнем розыска.",
        CITIZENSHIP_IMMIGRANT, 100, 0, 0, 5, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_NORMAL, 220, 190,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_FAST_DEMOLITION,
        -312.60, 2224.80, 42.48, 90.0, 0, 0,
        SKILL_AK47, 950, SKILL_DEMOLITIONS, 1000, SKILL_GUNSMITHING, 650, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        22, 1, 150, 43, 1, 0,   29, 1, 1,   49, 1, 0,   0, 0, 0,    0, 0, 0
    },

    // 8. Подпольный Автомеханик
    {
        8, "Подпольный Автомеханик", "Гаражный мастер",
        "Автомеханика 1000, Вождение 1000, Угон (скрутка проводов) 800. Ящик с ключами и канистра 20 л. Бонус +10 км/ч к скорости авто и быстрый ремонт. Минус: Выносливость макс. 400.",
        CITIZENSHIP_CITIZEN, 650, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_NORMAL, 50, 69,
        false, false, SKILL_STAMINA, 400,
        PERK_SPEED_BONUS_10,
        2481.60, -2117.30, 13.54, 0.0, 0, 0,
        SKILL_MECHANICS, 1000, SKILL_DRIVING, 1000, SKILL_HOTWIRING, 800, SKILL_HEAVY_TOOLS, 500, MAX_SKILL_TYPES, 0,
        46, 1, 0,   48, 1, 0,   6, 1, 0,    0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 9. Уличный Хулиган
    {
        9, "Уличный Хулиган", "Районный громила",
        "Взлом замков 750, Угон 650, Пистолет 450, стиль боя Бокс. Бита, нож, отмычки и марихуана. Шанс взлома замков выше на +35%. Минус: начальная наркозависимость.",
        CITIZENSHIP_CITIZEN, 120, 0, 0, 0, 100.0, 0.0, 25.0, 0, FIGHT_STYLE_BOXING, 105, 195,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_LOCKPICK_BONUS_35,
        2495.30, -1687.40, 13.51, 90.0, 0, 0,
        SKILL_LOCKPICKING, 750, SKILL_HOTWIRING, 650, SKILL_PISTOL, 450, SKILL_MELEE_BLUNT, 600, MAX_SKILL_TYPES, 0,
        5, 1, 0,    4, 1, 0,    45, 2, 0,   67, 1, 0,   0, 0, 0,    0, 0, 0
    },

    // 10. Олигарх-Эмигрант
    {
        10, "Олигарх-Эмигрант", "Беглый магнат",
        "Стартовый капитал $20,000 наличными, деловой костюм, смартфон, сумка-портфель. Харизма 950. Скидка 25% на регистрацию корпораций и покупку бизнеса. Минус: статус негражданина.",
        CITIZENSHIP_IMMIGRANT, 20000, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_NORMAL, 147, 150,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_CORP_DISCOUNT_25,
        1685.60, -2238.50, 13.54, 180.0, 0, 0,
        SKILL_CHARISMA_BARTER, 950, SKILL_DRIVING, 600, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        50, 1, 0,   68, 1, 0,   42, 1, 0,   52, 1, 0,   0, 0, 0,    0, 0, 0
    },

    // 11. Отставной Коп
    {
        11, "Отставной Коп", "Опальный детектив",
        "Пистолет 9mm (60 патр.) с лицензией, стальные наручники, рация. Навыки: Пистолет 850, Дробовик 700, Криминалистика 850. Видит улики без спецприборов. Минус: +30% цены на черном рынке.",
        CITIZENSHIP_CITIZEN, 1200, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_BOXING, 165, 141,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_COP_SENSE,
        1481.20, -1741.80, 13.54, 0.0, 0, 0,
        SKILL_PISTOL, 850, SKILL_SHOTGUN, 700, SKILL_FORENSICS, 850, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        13, 1, 60,  69, 1, 0,   44, 1, 0,   53, 1, 0,   0, 0, 0,    0, 0, 0
    },

    // 12. Полевой Мясник-Хирург
    {
        12, "Полевой Мясник-Хирург", "Лишенный лицензии хирург",
        "Хирургия 1000, Первая помощь 1000. Хирургический набор, аптечки, бинты, жгуты, морфин и $3,000. Реанимирует в 2 раза быстрее и сразу с 50 HP. Минус: Мускулатура 150 (-10 кг веса).",
        CITIZENSHIP_CITIZEN, 3000, 0, 0, 0, 100.0, 0.0, 0.0, -10000, FIGHT_STYLE_NORMAL, 70, 91,
        false, false, SKILL_MUSCLE, 150,
        PERK_FAST_REVIVE,
        1177.80, -1323.50, 14.08, 270.0, 0, 0,
        SKILL_SURGERY, 1000, SKILL_FIRST_AID, 1000, SKILL_CHEMISTRY, 500, SKILL_MUSCLE, 150, MAX_SKILL_TYPES, 0,
        57, 1, 0,   56, 2, 0,   58, 5, 0,   59, 3, 0,   60, 3, 0,   4, 1, 0
    },

    // 13. Грузчик-Контрабандист
    {
        13, "Грузчик-Контрабандист", "Портовый докер",
        "Мускулатура 750, Скрытность 600, Взлом замков 500. На +20% выше шанс обнаружить редкий товар или оружие в портовых контейнерах. Минус: частые проверки таможни.",
        CITIZENSHIP_CITIZEN, 250, 0, 0, 0, 100.0, 0.0, 0.0, 5000, FIGHT_STYLE_NORMAL, 16, 131,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_CONTAINER_LOOT_20,
        2745.10, -2453.20, 13.86, 90.0, 0, 0,
        SKILL_MUSCLE, 750, SKILL_STEALTH, 600, SKILL_LOCKPICKING, 500, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        2, 1, 0,    61, 2, 0,   45, 1, 0,   0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 14. Король Трассы
    {
        14, "Король Трассы", "Дальнобойщик-магистральщик",
        "Вождение 950, Автомеханика 500. Рация, канистра 20 л, сухпаек и $2,000. Бонус +20% к оплате за контракты грузоперевозок и -15% расхода топлива. Минус: оружейные скиллы = 0.",
        CITIZENSHIP_CITIZEN, 2000, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_NORMAL, 202, 198,
        true, false, MAX_SKILL_TYPES, 1000,
        PERK_TRUCKER_BONUS_20,
        -78.50, -1136.40, 1.07, 180.0, 0, 0,
        SKILL_DRIVING, 950, SKILL_MECHANICS, 500, SKILL_STAMINA, 600, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        53, 1, 0,   48, 1, 0,   65, 2, 0,   62, 2, 0,   0, 0, 0,    0, 0, 0
    },

    // 15. Варщик-Амфетаминщик
    {
        15, "Варщик-Амфетаминщик", "Подпольный химик",
        "Химия 1000, Обрез 500. Обрез двустволки (14 патр.), прекурсоры, 2 дозы метамфетамина и $1,800. Выход готовых препаратов и наркотиков +40%. Минус: двойной урон при взрыве лабы.",
        CITIZENSHIP_CITIZEN, 1800, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_NORMAL, 144, 157,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_CHEM_YIELD_40,
        -2092.40, -2465.20, 30.62, 0.0, 0, 0,
        SKILL_CHEMISTRY, 1000, SKILL_SAWNOFF_SHOTGUN, 500, SKILL_SURVIVALISM, 400, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        81, 3, 0,   66, 2, 0,   17, 1, 14,  0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 16. Подпольный Оружейник
    {
        16, "Подпольный Оружейник", "Торговец оружием",
        "Оружейное дело 1000, Пистолет с глушителем 800, Металлургия 600. Пистолет с глушителем (45 патр.), набор оружейника, балаклава и $3,500. Экономия 25% металла при сборке.",
        CITIZENSHIP_CITIZEN, 3500, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_NORMAL, 29, 192,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_FIELD_GUNSMITH,
        -2026.50, 156.80, 29.03, 90.0, 0, 0,
        SKILL_GUNSMITHING, 1000, SKILL_PISTOL_SILENCED, 800, SKILL_METALLURGY, 600, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        14, 1, 45,  47, 1, 0,   43, 1, 0,   0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 17. Однопроцентник на Харлее
    {
        17, "Однопроцентник на Харлее", "Кочевник мотоклуба",
        "Мотоциклы 1000, Обрез 750, Автомеханика 550, стиль боя Захват и удар ногой. Обрез (20 патр.), кастет, виски. Повышенная устойчивость на байке. Минус: Вождение авто макс. 400.",
        CITIZENSHIP_CITIZEN, 350, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_GRABKICK, 100, 246,
        false, false, SKILL_DRIVING, 400,
        PERK_NO_BIKE_FALL,
        661.40, -573.20, 16.33, 180.0, 0, 0,
        SKILL_BIKE, 1000, SKILL_SAWNOFF_SHOTGUN, 750, SKILL_MECHANICS, 550, SKILL_MELEE_BLUNT, 650, MAX_SKILL_TYPES, 0,
        17, 1, 20,  64, 2, 0,   1, 1, 0,    0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 18. Опальный Пилот Картеля
    {
        18, "Опальный Пилот Картеля", "Контрабандный летчик",
        "Пилотирование 1000, Выживание 650. Парашют, рация, 2 брикета марихуаны и $1,500. Радары ПВО/полиции засекают на 50% ближе. Минус: банковский долг $10,000.",
        CITIZENSHIP_IMMIGRANT, 1500, 0, 10000, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_NORMAL, 61, 141,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_RADAR_STEALTH_50,
        414.20, 2533.60, 19.14, 180.0, 0, 0,
        SKILL_FLYING, 1000, SKILL_SURVIVALISM, 650, SKILL_STEALTH, 500, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        39, 1, 1,   53, 1, 0,   67, 2, 0,   0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 19. Реднек-Браконьер
    {
        19, "Реднек-Браконьер", "Болотный охотник",
        "Помповый дробовик (30 патр.), нож, канистра 20 л. Навыки: Дробовик 850, Снайперские винтовки 650, Выживание 900, Скрытность 750. Экономия стамины в лесах. Минус: стресс в городах.",
        CITIZENSHIP_CITIZEN, 600, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_NORMAL, 158, 157,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_FOREST_RUNNER,
        -688.40, -1954.20, 8.95, 0.0, 0, 0,
        SKILL_SHOTGUN, 850, SKILL_SNIPER_RIFLE, 650, SKILL_SURVIVALISM, 900, SKILL_STEALTH, 750, SKILL_COUNTRY_RIFLE, 850,
        16, 1, 30,  4, 1, 0,    48, 1, 0,   0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 20. Шахтер-Стахановец
    {
        20, "Шахтер-Стахановец", "Горнорабочий забоя",
        "Горное дело и лесоповал 1000, Мускулатура 900, Металлургия 500. Шахтерская кирка, лопата, сухпаек. Выработка руды и дерева +35%, лимит переносимого веса +15 кг.",
        CITIZENSHIP_CITIZEN, 400, 0, 0, 0, 100.0, 0.0, 0.0, 15000, FIGHT_STYLE_NORMAL, 27, 131,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_MINING_YIELD_35,
        816.40, 856.70, 12.78, 90.0, 0, 0,
        SKILL_MINING_LOGGING, 1000, SKILL_MUSCLE, 900, SKILL_METALLURGY, 500, SKILL_HEAVY_TOOLS, 750, MAX_SKILL_TYPES, 0,
        54, 1, 0,   6, 1, 0,    62, 2, 0,   0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 21. Качок-Вышибала
    {
        21, "Качок-Вышибала", "Стероидный громила",
        "Мускулатура 1000, стиль боя Бокс. Кастет, бейсбольная бита, 3 бутылки воды. Бонус +25 кг к максимальному переносимому весу, сокрушительный удар. Минус: расход еды и воды в 1.5 раза выше.",
        CITIZENSHIP_CITIZEN, 500, 0, 0, 0, 100.0, 0.0, 0.0, 25000, FIGHT_STYLE_BOXING, 18, 92,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_HIGH_METABOLISM,
        664.20, -1864.50, 5.46, 0.0, 0, 0,
        SKILL_MUSCLE, 1000, SKILL_MELEE_BLUNT, 850, SKILL_STAMINA, 800, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        1, 1, 0,    5, 1, 0,    61, 3, 0,   0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 22. Беспризорный Карманник
    {
        22, "Беспризорный Карманник", "Уличный щипач",
        "Карманные кражи 950, Взлом замков 800, Велосипеды 1000, Выносливость 950. Отмычки и перцовый баллончик. Незаметная кража из Слоя 1. Минус: хрупкое телосложение (65 HP).",
        CITIZENSHIP_CITIZEN, 80, 0, 0, 0, 65.0, 0.0, 0.0, -3000, FIGHT_STYLE_ELBOW, 22, 56,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_SILENT_PICKPOCKET,
        1872.40, -1382.60, 13.57, 180.0, 0, 0,
        SKILL_PICKPOCKETING, 950, SKILL_LOCKPICKING, 800, SKILL_CYCLING, 1000, SKILL_STAMINA, 950, SKILL_STEALTH, 700,
        45, 3, 0,   34, 1, 500, 0, 0, 0,    0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 23. Сектант-Фанатик
    {
        23, "Сектант-Фанатик", "Проповедник культа",
        "Выживание 850, Подрывное дело 600, Метательное 750. 2 коктейля Молотова, лопата, балаклава. Защита -50% от урона огнем. Минус: полный религиозный запрет на банковские счета.",
        CITIZENSHIP_CITIZEN, 200, 0, 0, 0, 100.0, 0.0, 0.0, 0, FIGHT_STYLE_NORMAL, 68, 197,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_FIRE_RESIST_50,
        -1061.50, -1195.80, 129.21, 270.0, 0, 0,
        SKILL_SURVIVALISM, 850, SKILL_DEMOLITIONS, 600, SKILL_THROWABLES, 750, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        28, 1, 2,   6, 1, 0,    43, 1, 0,   0, 0, 0,    0, 0, 0,    0, 0, 0
    },

    // 24. Бывший Спецназовец SWAT
    {
        24, "Бывший Спецназовец SWAT", "Штурмовик спецназа",
        "ПП MP5 (120 патр.) с лицензией, тяжелый бронежилет, балаклава. Навыки: MP5 950, Боевой дробовик 800, Первая помощь 600. Прочность брони +20%, выбивание дверей с 1 удара.",
        CITIZENSHIP_CITIZEN, 900, 0, 0, 0, 100.0, 100.0, 0.0, 0, FIGHT_STYLE_KUNGFU, 285, 191,
        false, false, MAX_SKILL_TYPES, 1000,
        PERK_ARMOR_BONUS_20,
        389.60, -1816.40, 7.83, 0.0, 0, 0,
        SKILL_MP5, 950, SKILL_SPAS12_SHOTGUN, 800, SKILL_FIRST_AID, 600, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        21, 1, 120, 69, 1, 0,   40, 1, 0,   43, 1, 0,   0, 0, 0,    0, 0, 0
    },

    // 25. Сын Депутата
    {
        25, "Сын Депутата", "Золотая молодежь",
        "На банковской карте $12,000 + $500 наличными, смартфон, сигареты. Харизма 900, Вождение 700. Штрафы и розыск до 10 уровня режутся вдвое. Минус: Мускулатура 100, запрет грязных работ.",
        CITIZENSHIP_CITIZEN, 500, 12000, 0, 0, 100.0, 0.0, 0.0, -5000, FIGHT_STYLE_NORMAL, 299, 12,
        false, false, SKILL_MUSCLE, 100,
        PERK_FINE_WANTED_HALF,
        692.10, -1108.50, 44.02, 180.0, 0, 0,
        SKILL_CHARISMA_BARTER, 900, SKILL_DRIVING, 700, SKILL_MUSCLE, 100, MAX_SKILL_TYPES, 0, MAX_SKILL_TYPES, 0,
        50, 1, 0,   65, 1, 0,   52, 1, 0,   0, 0, 0,    0, 0, 0,    0, 0, 0
    }
};

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (static stock)
// =============================================================================

static stock Internal_IssueStarterItem(
    role_idx,
    layer1_slot,
    layer2_slot,
    def_id,
    amount,
    ammo_count)
{
    #pragma unused role_idx
    if (!Item_IsValid(def_id) || amount <= 0)
    {
        return 0;
    }

    new metaInt1 = 0;
    new metaInt2 = 0;
    new metaStr[32];
    metaStr[0] = EOS;

    // Если выдается огнестрельное оружие — генерируем уникальный 64-битный серийный номер ствола
    if (Item_GetCategory(def_id) == ITEM_CAT_FIREARM)
    {
        metaInt2 = Utils_GenerateWeaponSerial();
        format(metaStr, sizeof(metaStr), "SN-%d", metaInt2);
    }

    // Если предмет помещается в потайной Слой 2 (документы, телефон, лицензия, отмычки) — пробуем Слой 2, иначе Слой 1
    new targetSlot = layer1_slot;
    if (Item_CanStoreInLayer2(def_id) &&
        def_id != 1 && def_id != 4 &&
        Storage_IsValidSlot(layer2_slot))
    {
        targetSlot = layer2_slot;
    }

    new itemSlot = INVALID_STORAGE_ITEM_SLOT;
    new E_STORAGE_RESULT:res = Storage_AddItem(
        targetSlot,
        def_id,
        amount,
        ammo_count,
        100.0,
        metaInt1,
        metaInt2,
        metaStr,
        itemSlot);

    if (res != STORAGE_RES_OK && targetSlot != layer1_slot && Storage_IsValidSlot(layer1_slot))
    {
        Storage_AddItem(
            layer1_slot,
            def_id,
            amount,
            ammo_count,
            100.0,
            metaInt1,
            metaInt2,
            metaStr,
            itemSlot);
    }
    return 1;
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API КОНФИГУРАТОРА РОЛЕЙ (Roles_*)
// =============================================================================

stock bool:Roles_IsValidId(role_id)
{
    return (role_id >= 1 && role_id <= MAX_STARTER_ROLES);
}

stock Roles_GetNameRu(role_id, output[], len = sizeof(output))
{
    if (!Roles_IsValidId(role_id))
    {
        format(output, len, "Неизвестная роль");
        return 0;
    }
    format(output, len, "%s", gRoleConfigs[role_id - 1][E_ROLE_NAME_RU]);
    return 1;
}

stock Roles_GetSubtitle(role_id, output[], len = sizeof(output))
{
    if (!Roles_IsValidId(role_id))
    {
        output[0] = EOS;
        return 0;
    }
    format(output, len, "%s", gRoleConfigs[role_id - 1][E_ROLE_SUBTITLE]);
    return 1;
}

stock Roles_GetDescriptionRu(role_id, output[], len = sizeof(output))
{
    if (!Roles_IsValidId(role_id))
    {
        output[0] = EOS;
        return 0;
    }
    format(output, len, "%s", gRoleConfigs[role_id - 1][E_ROLE_DESC_RU]);
    return 1;
}

stock E_CITIZENSHIP_TYPE:Roles_GetCitizenship(role_id)
{
    if (!Roles_IsValidId(role_id))
    {
        return CITIZENSHIP_CITIZEN;
    }
    return gRoleConfigs[role_id - 1][E_ROLE_CITIZENSHIP];
}

stock Roles_GetStartCashUsd(role_id)
{
    if (!Roles_IsValidId(role_id))
    {
        return 0;
    }
    return gRoleConfigs[role_id - 1][E_ROLE_START_CASH_USD];
}

stock Roles_GetStartBankUsd(role_id)
{
    if (!Roles_IsValidId(role_id))
    {
        return 0;
    }
    return gRoleConfigs[role_id - 1][E_ROLE_START_BANK_USD];
}

stock Roles_GetStartDebtUsd(role_id)
{
    if (!Roles_IsValidId(role_id))
    {
        return 0;
    }
    return gRoleConfigs[role_id - 1][E_ROLE_START_DEBT_USD];
}

stock Roles_GetStartWanted(role_id)
{
    if (!Roles_IsValidId(role_id))
    {
        return 0;
    }
    return gRoleConfigs[role_id - 1][E_ROLE_START_WANTED];
}

stock Float:Roles_GetStartHp(role_id)
{
    if (!Roles_IsValidId(role_id))
    {
        return 100.0;
    }
    return gRoleConfigs[role_id - 1][E_ROLE_START_HP];
}

stock Float:Roles_GetStartArmour(role_id)
{
    if (!Roles_IsValidId(role_id))
    {
        return 0.0;
    }
    return gRoleConfigs[role_id - 1][E_ROLE_START_ARMOUR];
}

stock Float:Roles_GetStartAddiction(role_id)
{
    if (!Roles_IsValidId(role_id))
    {
        return 0.0;
    }
    return gRoleConfigs[role_id - 1][E_ROLE_START_ADDICTION];
}

stock Roles_GetWeightBonusGrams(role_id)
{
    if (!Roles_IsValidId(role_id))
    {
        return 0;
    }
    return gRoleConfigs[role_id - 1][E_ROLE_WEIGHT_BONUS_G];
}

stock FIGHT_STYLE:Roles_GetFightingStyle(role_id)
{
    if (!Roles_IsValidId(role_id))
    {
        return FIGHT_STYLE_NORMAL;
    }
    return gRoleConfigs[role_id - 1][E_ROLE_FIGHT_STYLE];
}

stock Roles_GetDefaultSkin(role_id, gender)
{
    if (!Roles_IsValidId(role_id))
    {
        return (gender == 2) ? 93 : 26;
    }
    return (gender == 2)
        ? gRoleConfigs[role_id - 1][E_ROLE_SKIN_FEMALE]
        : gRoleConfigs[role_id - 1][E_ROLE_SKIN_MALE];
}

stock E_ROLE_PERK_FLAGS:Roles_GetPerksMask(role_id)
{
    if (!Roles_IsValidId(role_id))
    {
        return PERK_NONE;
    }
    return gRoleConfigs[role_id - 1][E_ROLE_PERKS];
}

stock bool:Roles_HasPerk(role_id, E_ROLE_PERK_FLAGS:perk)
{
    if (!Roles_IsValidId(role_id))
    {
        return false;
    }
    return ((gRoleConfigs[role_id - 1][E_ROLE_PERKS] & perk) != PERK_NONE);
}

stock Roles_GetSpawnPos(
    role_id,
    &Float:x,
    &Float:y,
    &Float:z,
    &Float:a,
    &interior,
    &virtual_world)
{
    if (!Roles_IsValidId(role_id))
    {
        x = 1742.90;
        y = -1862.40;
        z = 13.57;
        a = 0.0;
        interior = 0;
        virtual_world = 0;
        return 0;
    }

    new const idx = role_id - 1;
    x = gRoleConfigs[idx][E_ROLE_SPAWN_X];
    y = gRoleConfigs[idx][E_ROLE_SPAWN_Y];
    z = gRoleConfigs[idx][E_ROLE_SPAWN_Z];
    a = gRoleConfigs[idx][E_ROLE_SPAWN_A];
    interior = gRoleConfigs[idx][E_ROLE_SPAWN_INTERIOR];
    virtual_world = gRoleConfigs[idx][E_ROLE_SPAWN_VW];
    return 1;
}

// Применение ограничений и стартовых навыков роли к матрице навыков игрока
stock Roles_ApplySkillsOnly(playerid, role_id)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Roles_IsValidId(role_id))
    {
        return 0;
    }

    new const idx = role_id - 1;
    Skills_ResetDefaults(playerid);

    if (gRoleConfigs[idx][E_ROLE_ZERO_WEAPON_SKILLS])
    {
        Skills_CapAllWeaponSkills(playerid, 0);
    }
    if (gRoleConfigs[idx][E_ROLE_ZERO_CRIMINAL_SKILLS])
    {
        Skills_CapAllCriminalSkills(playerid, 0);
    }
    if (gRoleConfigs[idx][E_ROLE_CAP_SKILL_TYPE] != MAX_SKILL_TYPES)
    {
        Skills_SetCap(
            playerid,
            gRoleConfigs[idx][E_ROLE_CAP_SKILL_TYPE],
            gRoleConfigs[idx][E_ROLE_CAP_SKILL_MAX]);
    }

    if (gRoleConfigs[idx][E_ROLE_SKILL_1] != MAX_SKILL_TYPES)
        Skills_Set(playerid, gRoleConfigs[idx][E_ROLE_SKILL_1], gRoleConfigs[idx][E_ROLE_SKILL_VAL_1], false);
    if (gRoleConfigs[idx][E_ROLE_SKILL_2] != MAX_SKILL_TYPES)
        Skills_Set(playerid, gRoleConfigs[idx][E_ROLE_SKILL_2], gRoleConfigs[idx][E_ROLE_SKILL_VAL_2], false);
    if (gRoleConfigs[idx][E_ROLE_SKILL_3] != MAX_SKILL_TYPES)
        Skills_Set(playerid, gRoleConfigs[idx][E_ROLE_SKILL_3], gRoleConfigs[idx][E_ROLE_SKILL_VAL_3], false);
    if (gRoleConfigs[idx][E_ROLE_SKILL_4] != MAX_SKILL_TYPES)
        Skills_Set(playerid, gRoleConfigs[idx][E_ROLE_SKILL_4], gRoleConfigs[idx][E_ROLE_SKILL_VAL_4], false);
    if (gRoleConfigs[idx][E_ROLE_SKILL_5] != MAX_SKILL_TYPES)
        Skills_Set(playerid, gRoleConfigs[idx][E_ROLE_SKILL_5], gRoleConfigs[idx][E_ROLE_SKILL_VAL_5], false);

    Skills_SetFightingStyle(playerid, gRoleConfigs[idx][E_ROLE_FIGHT_STYLE], true);
    Skills_SyncNative(playerid);
    return 1;
}

// Полное применение шаблона роли: навыки, лимиты, паспорт, карта, одежда, наличные и стартовый инвентарь
stock Roles_ApplyTemplate(
    playerid,
    role_id,
    layer1_slot = INVALID_STORAGE_SLOT,
    layer2_slot = INVALID_STORAGE_SLOT,
    const ssn_str[] = "",
    bank_account_db_id = 0,
    skin_id = 0)
{
    if (!Roles_IsValidId(role_id))
    {
        return 0;
    }

    new const idx = role_id - 1;
    Roles_ApplySkillsOnly(playerid, role_id);

    if (!Storage_IsValidSlot(layer1_slot) || !Storage_IsValidSlot(layer2_slot))
    {
        return 1;
    }

    new dummyItemSlot = INVALID_STORAGE_ITEM_SLOT;

    // 1. Выдача паспорта гражданина США в потайной Слой 2 (если статус CITIZEN)
    if (gRoleConfigs[idx][E_ROLE_CITIZENSHIP] == CITIZENSHIP_CITIZEN && ssn_str[0] != EOS)
    {
        Storage_AddItem(
            layer2_slot,
            ITEM_ID_PASSPORT,
            1,
            0,
            100.0,
            1,
            role_id,
            ssn_str,
            dummyItemSlot);
    }

    // 2. Выдача банковской дебетовой карты в потайной Слой 2 (если открыт банковский счет)
    if (bank_account_db_id > 0 && !Roles_HasPerk(role_id, PERK_FIRE_RESIST_50))
    {
        new cardMetaStr[32];
        format(cardMetaStr, sizeof(cardMetaStr), "BANK-ACC-%d", bank_account_db_id);
        Storage_AddItem(
            layer2_slot,
            ITEM_ID_BANK_CARD,
            1,
            0,
            100.0,
            bank_account_db_id,
            CURRENCY_USD,
            cardMetaStr,
            dummyItemSlot);
    }

    // 3. Выдача комплекта верхней одежды (скина) в потайной Слой 2
    new const resolvedSkin = (skin_id > 0) ? skin_id : gRoleConfigs[idx][E_ROLE_SKIN_MALE];
    new outfitStr[32];
    format(outfitStr, sizeof(outfitStr), "SKIN-%d", resolvedSkin);
    Storage_AddItem(
        layer2_slot,
        ITEM_ID_CLOTHING_OUTFIT,
        1,
        0,
        100.0,
        resolvedSkin,
        CLOTHING_STATE_EQUIPPED,
        outfitStr,
        dummyItemSlot);

    // 4. Выдача стартовых наличных долларов США (USD) в Слой 1
    new const startCashUsd = gRoleConfigs[idx][E_ROLE_START_CASH_USD];
    if (startCashUsd > 0)
    {
        Storage_AddItem(
            layer1_slot,
            ITEM_ID_CASH_BUNDLE,
            startCashUsd,
            0,
            100.0,
            CASH_FLAG_CLEAN,
            CURRENCY_USD,
            "USD",
            dummyItemSlot);
    }

    // 5. Выдача всех 6 слотов стартового снаряжения по шаблону роли
    Internal_IssueStarterItem(
        idx, layer1_slot, layer2_slot,
        gRoleConfigs[idx][E_ROLE_ITEM_ID_1],
        gRoleConfigs[idx][E_ROLE_ITEM_AMT_1],
        gRoleConfigs[idx][E_ROLE_ITEM_AMMO_1]);

    Internal_IssueStarterItem(
        idx, layer1_slot, layer2_slot,
        gRoleConfigs[idx][E_ROLE_ITEM_ID_2],
        gRoleConfigs[idx][E_ROLE_ITEM_AMT_2],
        gRoleConfigs[idx][E_ROLE_ITEM_AMMO_2]);

    Internal_IssueStarterItem(
        idx, layer1_slot, layer2_slot,
        gRoleConfigs[idx][E_ROLE_ITEM_ID_3],
        gRoleConfigs[idx][E_ROLE_ITEM_AMT_3],
        gRoleConfigs[idx][E_ROLE_ITEM_AMMO_3]);

    Internal_IssueStarterItem(
        idx, layer1_slot, layer2_slot,
        gRoleConfigs[idx][E_ROLE_ITEM_ID_4],
        gRoleConfigs[idx][E_ROLE_ITEM_AMT_4],
        gRoleConfigs[idx][E_ROLE_ITEM_AMMO_4]);

    Internal_IssueStarterItem(
        idx, layer1_slot, layer2_slot,
        gRoleConfigs[idx][E_ROLE_ITEM_ID_5],
        gRoleConfigs[idx][E_ROLE_ITEM_AMT_5],
        gRoleConfigs[idx][E_ROLE_ITEM_AMMO_5]);

    Internal_IssueStarterItem(
        idx, layer1_slot, layer2_slot,
        gRoleConfigs[idx][E_ROLE_ITEM_ID_6],
        gRoleConfigs[idx][E_ROLE_ITEM_AMT_6],
        gRoleConfigs[idx][E_ROLE_ITEM_AMMO_6]);

    return 1;
}

// Формирование полного табличного списка 25 ролей для DIALOG_STYLE_TABLIST_HEADERS (до 4096 символов)
stock Roles_BuildSelectionTableRu(output[], len = sizeof(output))
{
    if (len <= 0)
    {
        return 0;
    }

    output[0] = EOS;
    strcat(output, "№ и название роли\tСтатус гражданства\tСтартовый капитал\n", len);

    new builtRows = 0;
    new rowLine[192];
    new cashStr[32];
    new extraStr[32];
    new moneySummary[64];

    for (new i = 0; i < MAX_STARTER_ROLES; i++)
    {
        new const roleId = gRoleConfigs[i][E_ROLE_ID];
        if (!Roles_IsValidId(roleId) || gRoleConfigs[i][E_ROLE_NAME_RU][0] == EOS)
        {
            continue;
        }

        new const E_CITIZENSHIP_TYPE:cit = gRoleConfigs[i][E_ROLE_CITIZENSHIP];
        new const cash = gRoleConfigs[i][E_ROLE_START_CASH_USD];
        new const bank = gRoleConfigs[i][E_ROLE_START_BANK_USD];
        new const debt = gRoleConfigs[i][E_ROLE_START_DEBT_USD];

        Utils_FormatMoney(cash, cashStr, sizeof(cashStr));

        if (bank > 0)
        {
            Utils_FormatMoney(bank, extraStr, sizeof(extraStr));
            format(moneySummary, sizeof(moneySummary), "%s нал. + %s банк", cashStr, extraStr);
        }
        else if (debt > 0)
        {
            Utils_FormatMoney(debt, extraStr, sizeof(extraStr));
            format(moneySummary, sizeof(moneySummary), "%s нал. (долг %s)", cashStr, extraStr);
        }
        else
        {
            format(moneySummary, sizeof(moneySummary), "%s наличными", cashStr);
        }

        format(
            rowLine,
            sizeof(rowLine),
            "{FFC800}#%02d{FFFFFF} %s\t%s\t{66CC66}%s{FFFFFF}\n",
            roleId,
            gRoleConfigs[i][E_ROLE_NAME_RU],
            (cit == CITIZENSHIP_CITIZEN) ? ("{66CC66}Гражданин США{FFFFFF}") : ("{FFAA00}Иммигрант{FFFFFF}"),
            moneySummary);

        strcat(output, rowLine, len);
        builtRows++;
    }
    return builtRows;
}

// Форматирование подробной карточки роли на русском языке для диалога выбора роли
stock Roles_FormatDetailedCardRu(role_id, output[], len = sizeof(output))
{
    if (!Roles_IsValidId(role_id))
    {
        output[0] = EOS;
        return 0;
    }

    new const idx = role_id - 1;
    new cashStr[32], bankStr[32], debtStr[32];
    Utils_FormatMoney(gRoleConfigs[idx][E_ROLE_START_CASH_USD], cashStr);
    Utils_FormatMoney(gRoleConfigs[idx][E_ROLE_START_BANK_USD], bankStr);
    if (gRoleConfigs[idx][E_ROLE_START_DEBT_USD] > 0)
    {
        Utils_FormatMoney(gRoleConfigs[idx][E_ROLE_START_DEBT_USD], debtStr);
    }
    else
    {
        format(debtStr, sizeof(debtStr), "Отсутствует");
    }

    new itemsLine[512];
    itemsLine[0] = EOS;

    new itemIds[6];
    itemIds[0] = gRoleConfigs[idx][E_ROLE_ITEM_ID_1];
    itemIds[1] = gRoleConfigs[idx][E_ROLE_ITEM_ID_2];
    itemIds[2] = gRoleConfigs[idx][E_ROLE_ITEM_ID_3];
    itemIds[3] = gRoleConfigs[idx][E_ROLE_ITEM_ID_4];
    itemIds[4] = gRoleConfigs[idx][E_ROLE_ITEM_ID_5];
    itemIds[5] = gRoleConfigs[idx][E_ROLE_ITEM_ID_6];

    new itemAmts[6];
    itemAmts[0] = gRoleConfigs[idx][E_ROLE_ITEM_AMT_1];
    itemAmts[1] = gRoleConfigs[idx][E_ROLE_ITEM_AMT_2];
    itemAmts[2] = gRoleConfigs[idx][E_ROLE_ITEM_AMT_3];
    itemAmts[3] = gRoleConfigs[idx][E_ROLE_ITEM_AMT_4];
    itemAmts[4] = gRoleConfigs[idx][E_ROLE_ITEM_AMT_5];
    itemAmts[5] = gRoleConfigs[idx][E_ROLE_ITEM_AMT_6];

    new itemAmmos[6];
    itemAmmos[0] = gRoleConfigs[idx][E_ROLE_ITEM_AMMO_1];
    itemAmmos[1] = gRoleConfigs[idx][E_ROLE_ITEM_AMMO_2];
    itemAmmos[2] = gRoleConfigs[idx][E_ROLE_ITEM_AMMO_3];
    itemAmmos[3] = gRoleConfigs[idx][E_ROLE_ITEM_AMMO_4];
    itemAmmos[4] = gRoleConfigs[idx][E_ROLE_ITEM_AMMO_5];
    itemAmmos[5] = gRoleConfigs[idx][E_ROLE_ITEM_AMMO_6];

    new itemRow[128];
    for (new k = 0; k < 6; k++)
    {
        if (itemIds[k] > 0 && Item_IsValid(itemIds[k]))
        {
            new itemName[64];
            Item_GetName(itemIds[k], itemName);
            if (itemAmmos[k] > 0)
            {
                format(
                    itemRow,
                    sizeof(itemRow),
                    "  • %s (заряжено: %d патр.)\n",
                    itemName,
                    itemAmmos[k]);
            }
            else
            {
                format(
                    itemRow,
                    sizeof(itemRow),
                    "  • %s (x%d)\n",
                    itemName,
                    itemAmts[k]);
            }
            strcat(itemsLine, itemRow, sizeof(itemsLine));
        }
    }

    format(output, len,
        "{FFC800}Роль №%d: %s (%s){FFFFFF}\n\n" \
        "{88CCFF}Юридический статус:{FFFFFF} %s\n" \
        "{88CCFF}Стартовые наличные:{FFFFFF} {66CC66}%s{FFFFFF} | {88CCFF}На банковском счете:{FFFFFF} {66CC66}%s{FFFFFF}\n" \
        "{88CCFF}Банковский долг:{FFFFFF} %s | {88CCFF}Стартовый розыск:{FFFFFF} %d ур.\n\n" \
        "{FFC800}Особенности, бонусы и ограничения роли:{FFFFFF}\n" \
        "%s\n\n" \
        "{FFC800}Стартовое снаряжение в инвентаре:{FFFFFF}\n" \
        "%s",
        gRoleConfigs[idx][E_ROLE_ID],
        gRoleConfigs[idx][E_ROLE_NAME_RU],
        gRoleConfigs[idx][E_ROLE_SUBTITLE],
        (gRoleConfigs[idx][E_ROLE_CITIZENSHIP] == CITIZENSHIP_CITIZEN)
            ? ("{66CC66}Гражданин США (выдается паспорт, SSN и счет в банке){FFFFFF}")
            : ("{FFAA00}Иммигрант / Негражданин (без SSN, вне реестра ICE){FFFFFF}"),
        cashStr,
        bankStr,
        debtStr,
        gRoleConfigs[idx][E_ROLE_START_WANTED],
        gRoleConfigs[idx][E_ROLE_DESC_RU],
        itemsLine);
    return 1;
}

// =============================================================================
//  5. СИСТЕМНЫЕ ХУКИ И САМОПРОВЕРКА 25 РОЛЕЙ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    new validRolesCount = 0;
    for (new i = 0; i < MAX_STARTER_ROLES; i++)
    {
        if (gRoleConfigs[i][E_ROLE_ID] == (i + 1) && gRoleConfigs[i][E_ROLE_NAME_RU][0] != EOS)
        {
            validRolesCount++;
        }
    }

    new const builtRows = Roles_BuildSelectionTableRu(
        sRoleInitCheckBuffer,
        sizeof(sRoleInitCheckBuffer));
    new const tableLen = strlen(sRoleInitCheckBuffer);

    printf("%s [Entities/Roles] Загружено %d из %d стартовых ролей (от '%s' до '%s', таблица диалога: %d строк, %d симв.) [%s].",
        SERVER_LOG_PREFIX,
        validRolesCount,
        MAX_STARTER_ROLES,
        gRoleConfigs[0][E_ROLE_NAME_RU],
        gRoleConfigs[MAX_STARTER_ROLES - 1][E_ROLE_NAME_RU],
        builtRows,
        tableLen,
        (validRolesCount == MAX_STARTER_ROLES && builtRows == MAX_STARTER_ROLES && tableLen > 1000) ? ("УСПЕШНО") : ("ОШИБКА"));
    return 1;
}

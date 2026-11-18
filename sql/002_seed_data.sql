-- =============================================================================
--  SAN ANDREAS RP — Наполнение справочников мира и стартовой экономики
--  Файл:        sql/002_seed_data.sql
--  Пункт:       ROADMAP [0.4] — Наполнение справочников мира (Seed Data)
--  Кодировка:   utf8mb4 / utf8mb4_unicode_ci
--  Описание:    1. Справочник предметов item_definitions (91 предмет: 1..75 + 76..91)
--               2. Рецепты переработки и сборки craft_recipes + craft_recipe_inputs (69 рецептов)
--               3. Казны-хранилища storages (1..21 ORG_VAULT, 22..37 ENTERPRISE_WAREHOUSE)
--               4. 21 постоянная фракция organizations + 105 должностей organization_ranks
--               5. Стартовые предприятия enterprises + биржевые ордера enterprise_market_orders
--               6. Котировки глобальных портов port_market_quotes (LS, SF, LV)
--               7. Стартовый капитал (Seed Money) и материальные резервы в хранилищах
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET FOREIGN_KEY_CHECKS = 0;

USE `san_andreas_rp`;

-- Очистка справочников перед повторным накатом
TRUNCATE TABLE `logistics_contracts`;
TRUNCATE TABLE `port_market_quotes`;
TRUNCATE TABLE `enterprise_market_orders`;
TRUNCATE TABLE `enterprises`;
TRUNCATE TABLE `organization_ranks`;
TRUNCATE TABLE `organizations`;
TRUNCATE TABLE `craft_recipe_inputs`;
TRUNCATE TABLE `craft_recipes`;
TRUNCATE TABLE `storage_items`;
TRUNCATE TABLE `storages`;
TRUNCATE TABLE `item_definitions`;

-- =============================================================================
--  1. СПРАВОЧНИК ПРЕДМЕТОВ (item_definitions) — 91 ПОЗИЦИЯ
--     ID 1..75:  Мастер-реестр из раздела 8.2 GDD (точная привязка ID: 72=Ключи, 73=Кэш и т.д.)
--     ID 76..81: 6 видов базового сырья из раздела 8.0 GDD
--     ID 82..90: 9 промежуточных компонентов из раздела 8.1 GDD
--     ID 91:     Физический предмет одежды / скина (3000 г, Слой 2)
-- =============================================================================

INSERT INTO `item_definitions` (
    `id`, `code_name`, `display_name`, `category`,
    `base_weight_g`, `base_volume_ml`, `is_stackable`, `max_stack`,
    `gta_weapon_id`, `ammo_unit_weight_g`, `inner_max_weight_g`, `inner_max_volume_ml`, `can_layer2`
) VALUES
-- -----------------------------------------------------------------------------
--  А. Ближний бой и инструменты (ID 1..12)
-- -----------------------------------------------------------------------------
(1,  'MELEE_BRASS_KNUCKLES', 'Brass Knuckles',                        'MELEE',            300,   200,   0, 1,    1,  0,    0,     0,     1),
(2,  'MELEE_GOLF_CLUB',      'Golf Club',             'MELEE',            900,   1500,  0, 1,    2,  0,    0,     0,     0),
(3,  'MELEE_NIGHTSTICK',     'Police Nightstick',           'MELEE',            700,   800,   0, 1,    3,  0,    0,     0,     0),
(4,  'MELEE_KNIFE',          'Combat Knife',                    'MELEE',            400,   300,   0, 1,    4,  0,    0,     0,     1),
(5,  'MELEE_BASEBALL_BAT',   'Baseball Bat',              'MELEE',            1200,  2000,  0, 1,    5,  0,    0,     0,     0),
(6,  'MELEE_SHOVEL',         'Shovel',               'MELEE',            2500,  4000,  0, 1,    6,  0,    0,     0,     0),
(7,  'MELEE_POOL_CUE',       'Pool Cue',                'MELEE',            600,   1500,  0, 1,    7,  0,    0,     0,     0),
(8,  'MELEE_KATANA',         'Katana',                        'MELEE',            1800,  2500,  0, 1,    8,  0,    0,     0,     0),
(9,  'MELEE_CHAINSAW',       'Chainsaw',                     'MELEE',            6500,  7000,  0, 1,    9,  0,    0,     0,     0),
(10, 'MELEE_CANE',           'Cane',                        'MELEE',            800,   1200,  0, 1,    15, 0,    0,     0,     0),
(11, 'MELEE_FLOWERS',        'Bouquet of Flowers',                  'MELEE',            300,   1000,  0, 1,    14, 0,    0,     0,     0),
(12, 'MELEE_DILDO',          'Adult Toy',          'MELEE',            500,   500,   0, 1,    10, 0,    0,     0,     0),

-- -----------------------------------------------------------------------------
--  Б. Огнестрельное оружие (ID 13..25) — без отдельных предметов патронов
-- -----------------------------------------------------------------------------
(13, 'WEAPON_PISTOL_9MM',    '9mm Pistol',                  'FIREARM',          1100,  1000,  0, 1,    22, 8,    0,     0,     0),
(14, 'WEAPON_SILENCED_9MM',  'Silenced 9mm Pistol',     'FIREARM',          1300,  1500,  0, 1,    23, 8,    0,     0,     0),
(15, 'WEAPON_DESERT_EAGLE',  'Desert Eagle',         'FIREARM',          2000,  1500,  0, 1,    24, 20,   0,     0,     0),
(16, 'WEAPON_PUMP_SHOTGUN',  'Pump Shotgun',             'FIREARM',          3600,  4000,  0, 1,    25, 45,   0,     0,     0),
(17, 'WEAPON_SAWNOFF',       'Sawed-off Shotgun',              'FIREARM',          2200,  2500,  0, 1,    26, 45,   0,     0,     0),
(18, 'WEAPON_SPAS12',        'Combat Shotgun SPAS-12',       'FIREARM',          4400,  4500,  0, 1,    27, 45,   0,     0,     0),
(19, 'WEAPON_MICRO_UZI',     'Micro Uzi',    'FIREARM',          1500,  1500,  0, 1,    28, 8,    0,     0,     0),
(20, 'WEAPON_TEC9',          'Tec-9',        'FIREARM',          1400,  1500,  0, 1,    32, 8,    0,     0,     0),
(21, 'WEAPON_MP5',           'MP5',          'FIREARM',          2900,  3000,  0, 1,    29, 8,    0,     0,     0),
(22, 'WEAPON_AK47',          'AK-47 Assault Rifle',                 'FIREARM',          4300,  4500,  0, 1,    30, 16,   0,     0,     0),
(23, 'WEAPON_M4',            'M4 Assault Rifle',         'FIREARM',          3400,  4000,  0, 1,    31, 12,   0,     0,     0),
(24, 'WEAPON_COUNTRY_RIFLE', 'Hunting Rifle',            'FIREARM',          3800,  4500,  0, 1,    33, 24,   0,     0,     0),
(25, 'WEAPON_SNIPER_RIFLE',  'Sniper Rifle',          'FIREARM',          6500,  6000,  0, 1,    34, 26,   0,     0,     0),

-- -----------------------------------------------------------------------------
--  В. Тяжелое, метательное и спецсредства (ID 26..39)
-- -----------------------------------------------------------------------------
(26, 'HEAVY_GRENADE',        'Frag Grenade',            'HEAVY_THROWABLE',  600,   500,   0, 1,    16, 0,    0,     0,     0),
(27, 'HEAVY_TEARGAS',        'Tear Gas',      'HEAVY_THROWABLE',  500,   500,   0, 1,    17, 0,    0,     0,     0),
(28, 'HEAVY_MOLOTOV',        'Molotov Cocktail',             'HEAVY_THROWABLE',  800,   800,   0, 1,    18, 0,    0,     0,     0),
(29, 'HEAVY_SATCHEL_CHARGE', 'Satchel Charge',      'HEAVY_THROWABLE',  3000,  2500,  0, 1,    39, 0,    0,     0,     0),
(30, 'HEAVY_RPG7',           'RPG-7',              'HEAVY_THROWABLE',  7000,  12000, 0, 1,    35, 2200, 0,     0,     0),
(31, 'HEAVY_HS_ROCKET',      'Heat-seeking SAM Launcher',    'HEAVY_THROWABLE',  10500, 15000, 0, 1,    36, 3000, 0,     0,     0),
(32, 'HEAVY_FLAMETHROWER',   'Flamethrower',              'HEAVY_THROWABLE',  12000, 14000, 0, 1,    37, 100,  0,     0,     0),
(33, 'HEAVY_MINIGUN',        'Minigun','HEAVY_THROWABLE',  38000, 25000, 0, 1,    38, 12,   0,     0,     0),
(34, 'SPEC_SPRAYCAN',        'Pepper Spray',            'HEAVY_THROWABLE',  500,   500,   0, 1,    41, 1,    0,     0,     0),
(35, 'SPEC_FIRE_EXT',        'Fire Extinguisher',       'HEAVY_THROWABLE',  6000,  5000,  0, 1,    42, 5,    0,     0,     0),
(36, 'SPEC_CAMERA',          'Camera',        'HEAVY_THROWABLE',  900,   1000,  0, 1,    43, 1,    0,     0,     0),
(37, 'SPEC_NV_GOGGLES',      'Night Vision Goggles',        'HEAVY_THROWABLE',  800,   1000,  0, 1,    44, 0,    0,     0,     0),
(38, 'SPEC_THERMAL_GOGGLES', 'Thermal Goggles',           'HEAVY_THROWABLE',  1000,  1200,  0, 1,    45, 0,    0,     0,     0),
(39, 'SPEC_PARACHUTE',       'Parachute',             'HEAVY_THROWABLE',  11000, 15000, 0, 1,    46, 0,    0,     0,     0),

-- -----------------------------------------------------------------------------
--  Г. Снаряжение, инструменты и электроника (ID 40..55)
-- -----------------------------------------------------------------------------
(40, 'GEAR_BODY_ARMOR',      'Heavy Body Armor',            'GEAR_ELECTRONICS', 6500,  8000,  0, 1,    0,  0,    0,     0,     0),
(41, 'GEAR_BACKPACK',        'Hiking Backpack',          'GEAR_ELECTRONICS', 1500,  2000,  0, 1,    0,  0,    25000, 35000, 0),
(42, 'GEAR_DUFFLE_BAG',      'Duffle Bag',              'GEAR_ELECTRONICS', 1200,  2500,  0, 1,    0,  0,    35000, 45000, 0),
(43, 'GEAR_BALACLAVA',       'Tactical Balaclava',         'GEAR_ELECTRONICS', 200,   300,   0, 1,    0,  0,    0,     0,     1),
(44, 'GEAR_HANDCUFFS',       'Steel Handcuffs',            'GEAR_ELECTRONICS', 500,   400,   1, 10,   0,  0,    0,     0,     0),
(45, 'TOOL_LOCKPICK_SET',    'Lockpick Set',                 'GEAR_ELECTRONICS', 300,   300,   1, 20,   0,  0,    0,     0,     1),
(46, 'TOOL_WRENCH_KIT',      'Mechanic''s Wrench Kit',   'GEAR_ELECTRONICS', 4500,  3500,  0, 1,    0,  0,    10000, 8000,  0),
(47, 'TOOL_GUNSMITH_KIT',    'Gunsmith Kit',              'GEAR_ELECTRONICS', 2500,  2000,  0, 1,    0,  0,    0,     0,     0),
(48, 'TOOL_FUEL_CANISTER',   '20L Fuel Canister',      'GEAR_ELECTRONICS', 16000, 20000, 0, 1,    0,  0,    0,     0,     0),
(49, 'TOOL_BOLT_CUTTERS',    'Bolt Cutters',       'GEAR_ELECTRONICS', 3200,  2500,  0, 1,    0,  0,    0,     0,     0),
(50, 'ELEC_MOBILE_PHONE',    'Smartphone',                      'GEAR_ELECTRONICS', 200,   200,   0, 1,    0,  0,    0,     0,     1),
(51, 'ELEC_BURNER_PHONE',    'Burner Phone',           'GEAR_ELECTRONICS', 150,   100,   0, 1,    0,  0,    0,     0,     1),
(52, 'ELEC_SIM_CARD',        'SIM Card',       'GEAR_ELECTRONICS', 10,    10,    0, 1,    0,  0,    0,     0,     1),
(53, 'ELEC_WALKIE_TALKIE',   'Walkie-Talkie',             'GEAR_ELECTRONICS', 600,   700,   0, 1,    0,  0,    0,     0,     0),
(54, 'TOOL_MINING_PICKAXE',  'Mining Pickaxe',              'GEAR_ELECTRONICS', 3800,  3000,  0, 1,    0,  0,    0,     0,     0),
(55, 'TOOL_FORENSICS_KIT',   'Forensics Kit',          'GEAR_ELECTRONICS', 2000,  2500,  0, 1,    0,  0,    0,     0,     0),

-- -----------------------------------------------------------------------------
--  Д. Медицина, еда, напитки и нелегал (ID 56..67)
-- -----------------------------------------------------------------------------
(56, 'MED_FIRST_AID_KIT',    'First Aid Kit',         'MEDICAL_FOOD',     1500,  2000,  1, 10,   0,  0,    0,     0,     0),
(57, 'MED_SURGICAL_KIT',     'Surgical Kit',   'MEDICAL_FOOD',     2200,  2500,  0, 1,    0,  0,    0,     0,     0),
(58, 'MED_BANDAGE',          'Sterile Bandage',               'MEDICAL_FOOD',     100,   100,   1, 50,   0,  0,    0,     0,     1),
(59, 'MED_TOURNIQUET',       'Tourniquet',     'MEDICAL_FOOD',     200,   200,   1, 20,   0,  0,    0,     0,     1),
(60, 'MED_MORPHINE_SYRINGE', 'Morphine Syringe',        'MEDICAL_FOOD',     100,   100,   1, 20,   0,  0,    0,     0,     1),
(61, 'FOOD_WATER_BOTTLE',    '1L Water Bottle',     'MEDICAL_FOOD',     1000,  1000,  1, 20,   0,  0,    0,     0,     0),
(62, 'FOOD_MRE_RATION',      'Military MRE Ration',         'MEDICAL_FOOD',     800,   1000,  1, 20,   0,  0,    0,     0,     0),
(63, 'FOOD_FASTFOOD_BURGER', 'Hot Burger',                'MEDICAL_FOOD',     400,   500,   1, 20,   0,  0,    0,     0,     0),
(64, 'FOOD_LIQUOR_BOTTLE',   'Whiskey Bottle',                 'MEDICAL_FOOD',     1200,  1000,  1, 20,   0,  0,    0,     0,     0),
(65, 'FOOD_CIGARETTE_PACK',  'Cigarette Pack',                 'MEDICAL_FOOD',     50,    50,    1, 50,   0,  0,    0,     0,     1),
(66, 'ILLEGAL_HARD_DRUG',    'Methamphetamine Dose',            'ILLEGAL',          50,    50,    1, 100,  0,  0,    0,     0,     0),
(67, 'ILLEGAL_WEED_PACK',    'Marijuana Brick',              'ILLEGAL',          1000,  1000,  1, 50,   0,  0,    0,     0,     0),

-- -----------------------------------------------------------------------------
--  Е. Документы, валюта и промышленные товарные партии (ID 68..75)
-- -----------------------------------------------------------------------------
(68, 'DOC_PASSPORT_ID',      'Passport / ID',            'DOCUMENT_CURRENCY',50,    50,    0, 1,    0,  0,    0,     0,     1),
(69, 'DOC_WEAPON_LICENSE',   'Weapon License',    'DOCUMENT_CURRENCY',20,    20,    0, 1,    0,  0,    0,     0,     1),
(70, 'DOC_VEHICLE_TITLE',    'Vehicle Title','DOCUMENT_CURRENCY',20, 20,    0, 1,    0,  0,    0,     0,     1),
(71, 'DOC_BANK_CARD',        'Bank Debit Card',    'DOCUMENT_CURRENCY',10,    10,    0, 1,    0,  0,    0,     0,     1),
(72, 'ITEM_PHYSICAL_KEYS',   'Set of Keys',        'DOCUMENT_CURRENCY',100,   50,    0, 1,    0,  0,    0,     0,     1),
(73, 'CURR_CASH_BUNDLE',     'Cash Bundle',       'DOCUMENT_CURRENCY',500,   400,   1, 10000,0,  0,    0,     0,     0),
(74, 'RAW_COMMODITY_UNIT',   'Raw Commodity Unit',       'RAW',              1000,  1000,  1, 5000, 0,  0,    0,     0,     0),
(75, 'INT_PROCESSED_METAL',  'Processed Metal Unit',  'INTERMEDIATE',     1000,  800,   1, 5000, 0,  0,    0,     0,     0),

-- -----------------------------------------------------------------------------
--  Ж. Базовое сырье нулевого уровня цепочки (ID 76..81, раздел 8.0 GDD)
-- -----------------------------------------------------------------------------
(76, 'RAW_CRUDE_OIL',        'Crude Oil',                   'RAW',              1000,  1000,  1, 10000,0,  0,    0,     0,     0),
(77, 'RAW_IRON_ORE',         'Iron Ore',                 'RAW',              1000,  1000,  1, 10000,0,  0,    0,     0,     0),
(78, 'RAW_WOOD_LOG',         'Raw Log',             'RAW',              1000,  1000,  1, 10000,0,  0,    0,     0,     0),
(79, 'RAW_TECH_WATER',       'Raw Water',        'RAW',              1000,  1000,  1, 10000,0,  0,    0,     0,     0),
(80, 'RAW_GRAIN_FLOUR',      'Grain and Flour',        'RAW',              1000,  1000,  1, 10000,0,  0,    0,     0,     0),
(81, 'RAW_CHEM_PRECURSORS',  'Chemical Precursors',    'RAW',              1000,  1000,  1, 5000, 0,  0,    0,     0,     0),

-- -----------------------------------------------------------------------------
--  З. Промежуточные заводские компоненты первого уровня (ID 82..90, раздел 8.1 GDD)
-- -----------------------------------------------------------------------------
(82, 'INT_STEEL_SHEET',      'Steel Sheet',      'INTERMEDIATE',     1000,  800,   1, 5000, 0,  0,    0,     0,     0),
(83, 'INT_SPRINGS_PINS',     'Springs and Pins',   'INTERMEDIATE',     500,   300,   1, 5000, 0,  0,    0,     0,     0),
(84, 'INT_BEARINGS',         'Bearings',       'INTERMEDIATE',     200,   100,   1, 5000, 0,  0,    0,     0,     0),
(85, 'INT_NAILS_FASTENERS',  'Nails and Fasteners',      'INTERMEDIATE',     100,   50,    1, 5000, 0,  0,    0,     0,     0),
(86, 'INT_SYNTH_PLASTIC',    'Synthetic Plastic','INTERMEDIATE',    1000,  1200,  1, 5000, 0,  0,    0,     0,     0),
(87, 'INT_GUNPOWDER',        'Smokeless Gunpowder',     'INTERMEDIATE',     500,   500,   1, 5000, 0,  0,    0,     0,     0),
(88, 'INT_WOOD_PLANKS',      'Planks',     'INTERMEDIATE',     1000,  1000,  1, 5000, 0,  0,    0,     0,     0),
(89, 'INT_TEXTILE_FABRIC',   'Fabric',   'INTERMEDIATE',     500,   800,   1, 5000, 0,  0,    0,     0,     0),
(90, 'INT_REFINED_FUEL',     'Refined Fuel',    'INTERMEDIATE',     1000,  1000,  1, 10000,0,  0,    0,     0,     0),

-- -----------------------------------------------------------------------------
--  И. Комплект одежды / Внешний скин персонажа (ID 91, 3 кг, раздел 3 GDD)
-- -----------------------------------------------------------------------------
(91, 'GEAR_CLOTHING_OUTFIT', 'Clothing Outfit',       'GEAR_ELECTRONICS', 3000,  3000,  0, 1,    0,  0,    0,     0,     1);

-- =============================================================================
--  2. РЕЦЕПТЫ ПЕРЕРАБОТКИ И КРАФТА (craft_recipes + craft_recipe_inputs)
-- =============================================================================

INSERT INTO `craft_recipes` (
    `id`, `output_item_id`, `output_amount`, `station_type`,
    `required_skill`, `min_skill_level`, `craft_time_sec`
) VALUES
-- Заводская переработка сырья в промежуточные компоненты (1..10)
(1,  82, 1,  'FACTORY_METALLURGY', 'metallurgy',     0,   10), -- Листовой стальной прокат
(2,  83, 2,  'FACTORY_METALLURGY', 'metallurgy',     100, 8),  -- Пружины и штифты
(3,  84, 2,  'FACTORY_METALLURGY', 'metallurgy',     150, 8),  -- Подшипники
(4,  85, 5,  'FACTORY_METALLURGY', 'metallurgy',     0,   6),  -- Гвозди и крепеж
(5,  86, 1,  'FACTORY_REFINERY',   'chemistry',      50,  10), -- Синтетический пластик
(6,  87, 2,  'WORKBENCH_CHEM',     'chemistry',      200, 12), -- Оружейный порох
(7,  88, 1,  'FACTORY_ASSEMBLY',   'mining_logging', 0,   6),  -- Обработанные доски
(8,  89, 2,  'FACTORY_ASSEMBLY',   'survivalism',    0,   8),  -- Текстильное полотно
(9,  90, 5,  'FACTORY_REFINERY',   'chemistry',      0,   15), -- Очищенное топливо (малая партия)
(10, 82, 6,  'FACTORY_METALLURGY', 'metallurgy',     300, 45), -- Промышленная плавка стали (10 руды -> 6 стали)

-- Ближний бой и инструменты (11..20)
(11, 1,  1,  'WORKBENCH_WEAPON',   'gunsmithing',    50,  8),  -- Кастет
(12, 2,  1,  'FACTORY_ASSEMBLY',   'mechanics',      50,  10), -- Клюшка для гольфа
(13, 3,  1,  'FACTORY_ASSEMBLY',   'mechanics',      100, 10), -- Полицейская дубинка
(14, 4,  1,  'WORKBENCH_WEAPON',   'gunsmithing',    50,  8),  -- Боевой нож
(15, 5,  1,  'HAND',               'survivalism',    0,   8),  -- Бейсбольная бита
(16, 6,  1,  'FACTORY_ASSEMBLY',   'mechanics',      0,   10), -- Штыковая лопата
(17, 7,  1,  'HAND',               'survivalism',    0,   6),  -- Бильярдный кий
(18, 8,  1,  'WORKBENCH_WEAPON',   'gunsmithing',    400, 20), -- Катана
(19, 9,  1,  'FACTORY_ASSEMBLY',   'mechanics',      350, 25), -- Бензопила
(20, 10, 1,  'HAND',               'survivalism',    0,   6),  -- Трость

-- Огнестрельное оружие с первичным боекомплектом (21..33)
(21, 13, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    150, 15), -- Пистолет 9mm
(22, 14, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    250, 18), -- Пистолет 9mm с глушителем
(23, 15, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    350, 20), -- Пистолет Desert Eagle
(24, 16, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    300, 22), -- Помповый дробовик
(25, 17, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    200, 12), -- Обрез двустволки
(26, 18, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    550, 28), -- Боевой дробовик SPAS-12
(27, 19, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    300, 18), -- Micro Uzi
(28, 20, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    280, 18), -- Tec-9
(29, 21, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    450, 24), -- MP5
(30, 22, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    600, 30), -- Автомат AK-47
(31, 23, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    650, 32), -- Штурмовая винтовка M4
(32, 24, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    400, 22), -- Охотничья винтовка
(33, 25, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    750, 40), -- Снайперская винтовка

-- Тяжелое вооружение, взрывчатка и спецсредства (34..45)
(34, 26, 1,  'WORKBENCH_WEAPON',   'demolitions',    400, 15), -- Граната осколочная
(35, 27, 1,  'WORKBENCH_CHEM',     'chemistry',      250, 12), -- Шашка слезоточивого газа
(36, 28, 1,  'HAND',               'survivalism',    100, 8),  -- Коктейль Молотова
(37, 29, 1,  'WORKBENCH_WEAPON',   'demolitions',    650, 25), -- Взрывпакет с детонатором
(38, 30, 1,  'WORKBENCH_WEAPON',   'demolitions',    800, 45), -- Гранатомет РПГ-7
(39, 31, 1,  'FACTORY_ASSEMBLY',   'demolitions',    900, 60), -- ПЗРК
(40, 32, 1,  'WORKBENCH_WEAPON',   'mechanics',      700, 40), -- Огнемет
(41, 33, 1,  'FACTORY_ASSEMBLY',   'gunsmithing',    950, 90), -- Миниган
(42, 34, 1,  'WORKBENCH_CHEM',     'chemistry',      100, 8),  -- Перцовый баллончик
(43, 35, 1,  'FACTORY_ASSEMBLY',   'mechanics',      150, 12), -- Огнетушитель
(44, 37, 1,  'FACTORY_ASSEMBLY',   'mechanics',      500, 20), -- Прибор ночного видения
(45, 39, 1,  'FACTORY_ASSEMBLY',   'survivalism',    300, 18), -- Десантный парашют

-- Снаряжение, инструменты и электроника (46..58)
(46, 40, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    350, 20), -- Тяжелый бронежилет
(47, 41, 1,  'HAND',               'survivalism',    100, 12), -- Туристический рюкзак
(48, 42, 1,  'HAND',               'survivalism',    50,  10), -- Спортивная сумка
(49, 43, 1,  'HAND',               'survivalism',    0,   5),  -- Тактическая балаклава
(50, 44, 1,  'FACTORY_ASSEMBLY',   'mechanics',      200, 12), -- Стальные наручники
(51, 45, 2,  'HAND',               'lockpicking',    100, 8),  -- Набор отмычек
(52, 46, 1,  'FACTORY_ASSEMBLY',   'mechanics',      250, 15), -- Ящик автомеханика
(53, 47, 1,  'WORKBENCH_WEAPON',   'gunsmithing',    300, 15), -- Набор оружейника
(54, 48, 1,  'FACTORY_REFINERY',   'mechanics',      0,   10), -- Канистра с бензином 20 л
(55, 49, 1,  'FACTORY_ASSEMBLY',   'mechanics',      200, 14), -- Гидравлический болторез
(56, 53, 1,  'FACTORY_ASSEMBLY',   'mechanics',      300, 15), -- Портативная рация
(57, 54, 1,  'FACTORY_ASSEMBLY',   'mining_logging', 0,   10), -- Шахтерская кирка
(58, 55, 1,  'WORKBENCH_CHEM',     'forensics',      250, 18), -- Чемодан криминалиста

-- Медицина, продовольствие и нелегальные вещества (59..69)
(59, 56, 1,  'WORKBENCH_CHEM',     'first_aid',      150, 10), -- Аптечка первой помощи
(60, 57, 1,  'FACTORY_ASSEMBLY',   'surgery',        400, 18), -- Полевой хирургический набор
(61, 58, 2,  'HAND',               'first_aid',      0,   5),  -- Стерильный бинт
(62, 59, 1,  'HAND',               'first_aid',      50,  6),  -- Кровоостанавливающий жгут
(63, 60, 2,  'WORKBENCH_CHEM',     'chemistry',      350, 14), -- Шприц-тюбик с морфином
(64, 61, 2,  'FACTORY_ASSEMBLY',   'survivalism',    0,   5),  -- Бутылка питьевой воды 1 л
(65, 62, 2,  'FACTORY_ASSEMBLY',   'survivalism',    100, 8),  -- Армейский сухпаек MRE
(66, 63, 2,  'HAND',               'survivalism',    0,   5),  -- Горячий бургер
(67, 64, 1,  'WORKBENCH_CHEM',     'chemistry',      100, 10), -- Бутылка виски
(68, 66, 3,  'WORKBENCH_CHEM',     'chemistry',      500, 25), -- Доза метамфетамина
(69, 67, 1,  'WORKBENCH_CHEM',     'chemistry',      200, 15); -- Брикет марихуаны

INSERT INTO `craft_recipe_inputs` (`recipe_id`, `input_item_id`, `input_amount`) VALUES
-- Заводская переработка (1..10)
(1,  77, 2), (1,  76, 1),              -- Стальной прокат: 2 руды + 1 нефть
(2,  77, 1),                           -- Пружины и штифты: 1 руда
(3,  77, 1),                           -- Подшипники: 1 руда
(4,  77, 1),                           -- Гвозди и крепеж: 1 руда
(5,  76, 2),                           -- Синтетический пластик: 2 нефти
(6,  81, 1), (6,  76, 1),              -- Оружейный порох: 1 хим. реактивы + 1 нефть
(7,  78, 1),                           -- Доски: 1 древесина-кругляк
(8,  80, 1), (8,  79, 1),              -- Ткань: 1 растительное сырье + 1 вода
(9,  76, 6),                           -- 5 л очищенного топлива: 6 л сырой нефти
(10, 77, 10), (10, 76, 2),             -- Промышленная плавка: 10 руды + 2 нефти -> 6 стали

-- Ближний бой (11..20)
(11, 82, 1),                           -- Кастет: 1 стальной прокат
(12, 82, 1), (12, 86, 1),              -- Клюшка для гольфа: 1 сталь + 1 пластик
(13, 86, 1), (13, 82, 1),              -- Полицейская дубинка: 1 пластик + 1 сталь
(14, 82, 1), (14, 86, 1),              -- Боевой нож: 1 сталь + 1 пластик
(15, 88, 2),                           -- Бейсбольная бита: 2 доски
(16, 82, 2), (16, 88, 1),              -- Лопата: 2 стали + 1 доска
(17, 88, 1),                           -- Бильярдный кий: 1 доска
(18, 82, 2), (18, 89, 1),              -- Катана: 2 стали + 1 ткань
(19, 82, 3), (19, 86, 2), (19, 84, 2), -- Бензопила: 3 стали + 2 пластика + 2 подшипника
(20, 88, 1), (20, 85, 1),              -- Трость: 1 доска + 1 крепеж

-- Огнестрельное оружие (21..33)
(21, 82, 1), (21, 83, 1), (21, 84, 1), (21, 87, 1), -- Пистолет 9mm
(22, 13, 1), (22, 82, 1), (22, 86, 1),              -- Пистолет 9mm с глушителем
(23, 82, 2), (23, 83, 2), (23, 87, 2),              -- Desert Eagle
(24, 82, 3), (24, 88, 1), (24, 83, 1), (24, 87, 2), -- Помповый дробовик
(25, 16, 1), (25, 85, 1),                           -- Обрез из помпового дробовика
(26, 82, 4), (26, 86, 1), (26, 83, 2), (26, 87, 3), -- SPAS-12
(27, 82, 2), (27, 83, 2), (27, 84, 1), (27, 87, 2), -- Micro Uzi
(28, 82, 2), (28, 83, 1), (28, 86, 1), (28, 87, 2), -- Tec-9
(29, 82, 3), (29, 86, 1), (29, 84, 2), (29, 87, 2), -- MP5
(30, 82, 4), (30, 88, 1), (30, 83, 2), (30, 87, 3), -- AK-47
(31, 82, 3), (31, 86, 2), (31, 83, 2), (31, 84, 2), (31, 87, 3), -- M4
(32, 82, 3), (32, 88, 2), (32, 83, 1), (32, 87, 2), -- Охотничья винтовка
(33, 82, 6), (33, 83, 2), (33, 84, 2), (33, 87, 3), -- Снайперская винтовка

-- Тяжелое вооружение и спецсредства (34..45)
(34, 82, 1), (34, 87, 2), (34, 83, 1),              -- Граната осколочная
(35, 82, 1), (35, 81, 1),                           -- Слезоточивый газ
(36, 64, 1), (36, 90, 1), (36, 89, 1),              -- Коктейль Молотова
(37, 86, 2), (37, 87, 4), (37, 81, 2),              -- Взрывпакет с детонатором
(38, 82, 6), (38, 87, 5), (38, 83, 2),              -- РПГ-7
(39, 82, 8), (39, 87, 6), (39, 86, 3),              -- ПЗРК
(40, 82, 6), (40, 90, 5), (40, 84, 2),              -- Огнемет
(41, 82, 15),(41, 84, 8), (41, 83, 6), (41, 87, 8), -- Миниган
(42, 82, 1), (42, 81, 1),                           -- Перцовый баллончик
(43, 82, 3), (43, 81, 2), (43, 79, 2),              -- Огнетушитель
(44, 86, 2), (44, 84, 1),                           -- Прибор ночного видения
(45, 89, 6), (45, 86, 2), (45, 85, 2),              -- Парашют

-- Снаряжение и инструменты (46..58)
(46, 89, 4), (46, 82, 4),                           -- Тяжелый бронежилет
(47, 89, 3), (47, 86, 1),                           -- Туристический рюкзак
(48, 89, 3), (48, 85, 1),                           -- Спортивная сумка
(49, 89, 1),                                        -- Тактическая балаклава
(50, 82, 1), (50, 83, 1), (50, 85, 1),              -- Стальные наручники
(51, 83, 1), (51, 85, 2),                           -- Набор отмычек
(52, 82, 3), (52, 86, 1),                           -- Ящик автомеханика
(53, 82, 2), (53, 83, 2), (53, 84, 2),              -- Набор оружейника
(54, 82, 3), (54, 90, 20),                          -- Канистра с бензином 20 л
(55, 82, 3), (55, 86, 1),                           -- Гидравлический болторез
(56, 86, 1), (56, 85, 2),                           -- Портативная рация
(57, 82, 2), (57, 88, 1),                           -- Шахтерская кирка
(58, 86, 2), (58, 81, 2),                           -- Чемодан криминалиста

-- Медицина, еда и нелегал (59..69)
(59, 89, 2), (59, 81, 1), (59, 79, 1),              -- Аптечка первой помощи
(60, 82, 2), (60, 89, 2), (60, 81, 1),              -- Хирургический набор
(61, 89, 1),                                        -- Стерильный бинт
(62, 89, 1), (62, 86, 1),                           -- Кровоостанавливающий жгут
(63, 86, 1), (63, 81, 2),                           -- Шприц с морфином
(64, 79, 2), (64, 86, 1),                           -- Бутылка питьевой воды
(65, 80, 2), (65, 79, 1), (65, 86, 1),              -- Армейский сухпаек MRE
(66, 80, 1), (66, 79, 1),                           -- Горячий бургер
(67, 80, 2), (67, 79, 2),                           -- Бутылка виски
(68, 81, 3), (68, 79, 1),                           -- Доза метамфетамина
(69, 80, 1), (69, 81, 1);                           -- Брикет марихуаны

-- =============================================================================
--  3. КАЗНЫ ОРГАНИЗАЦИЙ И СКЛАДЫ ПРЕДПРИЯТИЙ (storages)
--     ID 1..21:  Физические бронированные сейфы 21 постоянной фракции (ORG_VAULT)
--     ID 22..37: Промышленные склады 16 стартовых предприятий (ENTERPRISE_WAREHOUSE)
-- =============================================================================

INSERT INTO `storages` (
    `id`, `storage_type`, `owner_id`, `max_weight_g`, `max_volume_ml`,
    `is_locked`, `lock_level`, `pos_x`, `pos_y`, `pos_z`, `interior`, `virtual_world`
) VALUES
-- Бронированные казны 21 системной фракции (ID 1..21)
(1,  'ORG_VAULT', 1,  10000000, 10000000, 1, 5, 1481.0,  -1771.0, 18.8,  0, 0), -- 1. Правительство штата
(2,  'ORG_VAULT', 2,  5000000,  5000000,  1, 5, 1554.9,  -1675.6, 16.2,  0, 0), -- 2. LSPD
(3,  'ORG_VAULT', 3,  5000000,  5000000,  1, 5, -1605.5, 710.8,   13.9,  0, 0), -- 3. SFPD
(4,  'ORG_VAULT', 4,  5000000,  5000000,  1, 5, 2287.0,  2431.8,  10.8,  0, 0), -- 4. LVPD
(5,  'ORG_VAULT', 5,  5000000,  5000000,  1, 5, 627.6,   -571.8,  17.9,  0, 0), -- 5. SASD
(6,  'ORG_VAULT', 6,  15000000, 15000000, 1, 5, 2728.5,  -2451.4, 17.6,  0, 0), -- 6. LSa
(7,  'ORG_VAULT', 7,  15000000, 15000000, 1, 5, -1346.8, 492.4,   11.2,  0, 0), -- 7. SFA
(8,  'ORG_VAULT', 8,  20000000, 20000000, 1, 5, 213.8,   1872.5,  13.1,  0, 0), -- 8. LV Army (Зона 69)
(9,  'ORG_VAULT', 9,  8000000,  8000000,  1, 5, -2442.2, 502.3,   30.1,  0, 0), -- 9. FBI
(10, 'ORG_VAULT', 10, 8000000,  8000000,  1, 5, 1245.5,  -764.2,  92.1,  0, 0), -- 10. CIA
(11, 'ORG_VAULT', 11, 5000000,  5000000,  1, 5, 55.6,    -1531.9, 5.1,   0, 0), -- 11. ICE
(12, 'ORG_VAULT', 12, 5000000,  5000000,  1, 4, 1172.8,  -1323.4, 15.4,  0, 0), -- 12. EMS
(13, 'ORG_VAULT', 13, 10000000, 10000000, 1, 5, 2504.3,  2772.9,  10.8,  0, 0), -- 13. PMC
(14, 'ORG_VAULT', 14, 25000000, 25000000, 1, 5, 2746.1,  -2437.2, 13.6,  0, 0), -- 14. Port Authority
(15, 'ORG_VAULT', 15, 3000000,  3000000,  1, 3, 777.8,   -1330.2, 13.5,  0, 0), -- 15. SAN News
(16, 'ORG_VAULT', 16, 4000000,  4000000,  1, 4, 2495.3,  -1690.7, 14.8,  0, 0), -- 16. Grove Street Families
(17, 'ORG_VAULT', 17, 4000000,  4000000,  1, 4, 2000.2,  -1114.1, 27.1,  0, 0), -- 17. Ballas Gang
(18, 'ORG_VAULT', 18, 4000000,  4000000,  1, 4, 2808.5,  -1176.9, 25.4,  0, 0), -- 18. Los Santos Vagos
(19, 'ORG_VAULT', 19, 4000000,  4000000,  1, 4, 1882.4,  -2023.7, 13.5,  0, 0), -- 19. Varrios Los Aztecas
(20, 'ORG_VAULT', 20, 6000000,  6000000,  1, 5, -2172.6, 680.1,   55.2,  0, 0), -- 20. Триады Сан-Фиерро
(21, 'ORG_VAULT', 21, 8000000,  8000000,  1, 5, 2196.4,  1677.1,  12.4,  0, 0), -- 21. Мафия Лас-Вентураса

-- Промышленные склады стартовых предприятий (ID 22..37)
(22, 'ENTERPRISE_WAREHOUSE', 1,  100000000, 100000000, 0, 2, 595.4,   872.6,   -42.5, 0, 0), -- 1. Карьер Хaro-Крик (MINE_ORE)
(23, 'ENTERPRISE_WAREHOUSE', 2,  100000000, 100000000, 0, 2, 261.2,   1411.8,  10.6,  0, 0), -- 2. Нефтепромысел Октан-Спрингс (OIL_RIG)
(24, 'ENTERPRISE_WAREHOUSE', 3,  80000000,  80000000,  0, 2, -533.8,  -179.4,  78.4,  0, 0), -- 3. Лесопилка Эйнджел-Пайн (SAWMILL)
(25, 'ENTERPRISE_WAREHOUSE', 4,  60000000,  60000000,  0, 2, -382.1,  -1426.3, 25.7,  0, 0), -- 4. Агроферма Флинт-Каунти (FARM)
(26, 'ENTERPRISE_WAREHOUSE', 5,  120000000, 120000000, 0, 3, 248.4,   1396.2,  10.6,  0, 0), -- 5. Нефтеперерабатывающий завод Грин-Палмс (REFINERY)
(27, 'ENTERPRISE_WAREHOUSE', 6,  120000000, 120000000, 0, 3, 2180.5,  -2253.8, 13.5,  0, 0), -- 6. Металлургический комбинат Оушен-Докс (METALLURGY)
(28, 'ENTERPRISE_WAREHOUSE', 7,  90000000,  90000000,  0, 4, -1042.6, -664.2,  32.0,  0, 0), -- 7. Завод точного машиностроения Истер-Бейсин (FACTORY)
(29, 'ENTERPRISE_WAREHOUSE', 8,  20000000,  20000000,  0, 3, 1352.3,  -1759.2, 13.5,  0, 0), -- 8. Универмаг Айдлвуд 24/7 (RETAIL_SHOP)
(30, 'ENTERPRISE_WAREHOUSE', 9,  20000000,  20000000,  0, 3, -2442.6, 754.8,   35.2,  0, 0), -- 9. Супермаркет Джунипер-Хилл (RETAIL_SHOP)
(31, 'ENTERPRISE_WAREHOUSE', 10, 20000000,  20000000,  0, 3, 2194.2,  1991.0,  12.3,  0, 0), -- 10. Торговый центр Лас-Вентураса (RETAIL_SHOP)
(32, 'ENTERPRISE_WAREHOUSE', 11, 80000000,  80000000,  0, 2, 1940.1,  -1772.9, 13.4,  0, 0), -- 11. АЗС Айдлвуд (GAS_STATION)
(33, 'ENTERPRISE_WAREHOUSE', 12, 80000000,  80000000,  0, 2, -1676.3, 413.2,   7.2,   0, 0), -- 12. АЗС Истер-Бейсин (GAS_STATION)
(34, 'ENTERPRISE_WAREHOUSE', 13, 80000000,  80000000,  0, 2, 2115.2,  920.1,   10.8,  0, 0), -- 13. АЗС Изумрудный Остров (GAS_STATION)
(35, 'ENTERPRISE_WAREHOUSE', 14, 40000000,  40000000,  1, 4, 2403.5,  -1406.2, 24.0,  0, 0), -- 14. Авторазборка Восточного Лос-Сантоса (CHOP_SHOP)
(36, 'ENTERPRISE_WAREHOUSE', 15, 40000000,  40000000,  1, 4, -2051.8, 178.4,   28.8,  0, 0), -- 15. Теневой гараж Доэрти (CHOP_SHOP)
(37, 'ENTERPRISE_WAREHOUSE', 16, 40000000,  40000000,  1, 4, 1658.4,  2196.1,  10.8,  0, 0); -- 16. Разборка Рэдсэндс-Уэст (CHOP_SHOP)

-- =============================================================================
--  4. 21 ПОСТОЯННАЯ ФРАКЦИЯ (organizations) И ИХ ДОЛЖНОСТИ (organization_ranks)
--     Битовая маска charter_flags (раздел 3.6 TECH_CONTEXT.MD):
--       0x01 (1)  = FLAG_CAN_BANK
--       0x02 (2)  = FLAG_LEGAL_HEAVY_WEAPONS
--       0x04 (4)  = FLAG_ISSUE_WARRANTS
--       0x08 (8)  = FLAG_WIRETAP
--       0x10 (16) = FLAG_BORDER_CONTROL
--       0x20 (32) = FLAG_EXTRALEGAL_OPS
-- =============================================================================

INSERT INTO `organizations` (
    `id`, `name`, `tag`, `legal_status`, `is_permanent`, `charter_flags`,
    `vault_storage_id`, `bank_balance_usd`, `is_bank_frozen`, `radio_freq`,
    `hq_x`, `hq_y`, `hq_z`
) VALUES
-- Группа 1: Правительство и государственные силовые структуры (1..11)
(1,  'State Government of San Andreas',       'GOV',    'STATE_AGENCY', 1, 5,  1,  100000000, 0, 100100, 1481.0,  -1771.0, 18.8),
(2,  'Los Santos Police Department',   'LSPD',   'STATE_AGENCY', 1, 23, 2,  5000000,   0, 101100, 1554.9,  -1675.6, 16.2),
(3,  'San Fierro Police Department',    'SFPD',   'STATE_AGENCY', 1, 23, 3,  5000000,   0, 102100, -1605.5, 710.8,   13.9),
(4,  'Las Venturas Police Department', 'LVPD',   'STATE_AGENCY', 1, 23, 4,  5000000,   0, 103100, 2287.0,  2431.8,  10.8),
(5,  'County Sheriff''s Department',             'SASD',   'STATE_AGENCY', 1, 23, 5,  4500000,   0, 104100, 627.6,   -571.8,  17.9),
(6,  'Los Santos National Guard',      'LSA',    'STATE_AGENCY', 1, 3,  6,  8000000,   0, 105100, 2728.5,  -2451.4, 17.6),
(7,  'San Fierro Naval Forces',        'SFA',    'STATE_AGENCY', 1, 3,  7,  8000000,   0, 106100, -1346.8, 492.4,   11.2),
(8,  'Area 69 Military Garrison','LVA',    'STATE_AGENCY', 1, 3,  8,  10000000,  0, 107100, 213.8,   1872.5,  13.1),
(9,  'Federal Bureau of Investigation',        'FBI',    'STATE_AGENCY', 1, 31, 9,  12000000,  0, 108100, -2442.2, 502.3,   30.1),
(10, 'Central Intelligence Agency','CIA',   'STATE_AGENCY', 1, 63, 10, 15000000,  0, 109100, 1245.5,  -764.2,  92.1),
(11, 'Immigration and Customs Enforcement',    'ICE',    'STATE_AGENCY', 1, 23, 11, 4000000,   0, 110100, 55.6,    -1531.9, 5.1),

-- Группа 2: Экстренные службы и медицина (12)
(12, 'Department of Health and Emergency Services', 'EMS', 'STATE_AGENCY', 1, 1, 12, 6000000, 0, 112100, 1172.8,  -1323.4, 15.4),

-- Группа 3: Легальные корпорации, ЧВК и инфраструктура (13..15)
(13, 'Blackwater San Andreas PMC',           'PMC',    'PRIVATE_CORP', 1, 3,  13, 7500000,   0, 200100, 2504.3,  2772.9,  10.8),
(14, 'Port Authority and Logistics',         'PORT',   'STATE_AGENCY', 1, 17, 14, 10000000,  0, 201100, 2746.1,  -2437.2, 13.6),
(15, 'San Andreas News Network',         'NEWS',   'PRIVATE_CORP', 1, 1,  15, 2500000,   0, 202100, 777.8,   -1330.2, 13.5),

-- Группа 4: Канонические уличные банды и криминальные синдикаты (16..21)
(16, 'Grove Street Families',                     'GROVE',  'UNREGISTERED', 1, 0,  16, 0,         0, 420100, 2495.3,  -1690.7, 14.8),
(17, 'Ballas Gang',                          'BALLAS', 'UNREGISTERED', 1, 0,  17, 0,         0, 420200, 2000.2,  -1114.1, 27.1),
(18, 'Los Santos Vagos',                      'VAGOS',  'UNREGISTERED', 1, 0,  18, 0,         0, 420300, 2808.5,  -1176.9, 25.4),
(19, 'Varrios Los Aztecas',                   'AZTEC',  'UNREGISTERED', 1, 0,  19, 0,         0, 420400, 1882.4,  -2023.7, 13.5),
(20, 'San Fierro Triad Syndicate',             'TRIAD',  'UNREGISTERED', 1, 0,  20, 0,         0, 420500, -2172.6, 680.1,   55.2),
(21, 'Las Venturas Crime Family',      'MAFIA',  'UNREGISTERED', 1, 0,  21, 0,         0, 420600, 2196.4,  1677.1,  12.4);

-- Иерархия должностей (organization_ranks) для всех 21 постоянных фракций (по 5 базовых рангов)
-- Маска прав RBAC (permissions_mask):
--   1=Доступ к рации, 2=Автопарк, 4=Оружейная/Склад, 8=Прием/Увольнение, 16=Казна/Банк, 32=Управление рангами, 63=Полный доступ лидера
INSERT INTO `organization_ranks` (`org_id`, `rank_order`, `title`, `salary_usd`, `permissions_mask`) VALUES
-- 1. Правительство штата
(1,  1, 'Executive Secretary',             800,  3),
(1,  2, 'Tax Service Inspector',     1200, 7),
(1,  3, 'State Federal Judge',        2200, 15),
(1,  4, 'Lieutenant Governor',                3000, 31),
(1,  5, 'Governor of San Andreas',   4500, 63),

-- 2. LSPD
(2,  1, 'Academy Cadet',                 600,  3),
(2,  2, 'Patrol Officer',              1100, 7),
(2,  3, 'Detective, Investigations Division',  1600, 7),
(2,  4, 'Precinct Captain',                2400, 31),
(2,  5, 'Chief of Los Santos Police',        3500, 63),

-- 3. SFPD
(3,  1, 'Academy Cadet',                 600,  3),
(3,  2, 'Patrol Officer',              1100, 7),
(3,  3, 'Port District Inspector',        1600, 7),
(3,  4, 'Police Captain',                2400, 31),
(3,  5, 'Chief of San Fierro Police',         3500, 63),

-- 4. LVPD
(4,  1, 'Academy Cadet',                 600,  3),
(4,  2, 'Patrol Officer',              1100, 7),
(4,  3, 'Gaming Control Investigator',   1600, 7),
(4,  4, 'Police Captain',                2400, 31),
(4,  5, 'Chief of Las Venturas Police',      3500, 63),

-- 5. SASD
(5,  1, 'Sheriff''s Department Intern',     600,  3),
(5,  2, 'Deputy Sheriff',                1100, 7),
(5,  3, 'County Senior Ranger',        1600, 7),
(5,  4, 'Undersheriff',                     2400, 31),
(5,  5, 'Sheriff of San Andreas County',       3500, 63),

-- 6. LSa
(6,  1, 'Guardsman',                700,  3),
(6,  2, 'Motorized Infantry Sergeant',             1200, 7),
(6,  3, 'Logistics Lieutenant',            1700, 7),
(6,  4, 'Garrison Colonel',            2500, 31),
(6,  5, 'National Guard General',   3600, 63),

-- 7. SFA
(7,  1, 'Coast Guard Seaman',        700,  3),
(7,  2, 'Fleet Petty Officer',                 1200, 7),
(7,  3, 'Naval Aviation Lieutenant',      1700, 7),
(7,  4, 'Captain First Rank',          2500, 31),
(7,  5, 'Admiral of the San Fierro Fleet',       3600, 63),

-- 8. LV Army (Зона 69)
(8,  1, 'Perimeter Guard',       750,  3),
(8,  2, 'Missile Battalion Sergeant',    1300, 7),
(8,  3, 'Classified Sector Officer',      1900, 7),
(8,  4, 'Deputy Commander of Area 69', 2700, 31),
(8,  5, 'Commander of Area 69',              3800, 63),

-- 9. FBI
(9,  1, 'FBI Junior Agent',              1200, 7),
(9,  2, 'FBI Special Agent',          1800, 7),
(9,  3, 'FBI Senior Investigator',        2400, 15),
(9,  4, 'Deputy Office Director',    3200, 31),
(9,  5, 'Director of the FBI Field Office',    4200, 63),

-- 10. CIA
(10, 1, 'Station Analyst',           1400, 7),
(10, 2, 'CIA Operations Officer',      2000, 7),
(10, 3, 'Foreign Operations Handler',    2700, 15),
(10, 4, 'Deputy Station Chief',       3500, 31),
(10, 5, 'CIA Station Chief',            4500, 63),

-- 11. ICE
(11, 1, 'Checkpoint Inspector',                  700,  3),
(11, 2, 'Customs Inspection Officer',    1150, 7),
(11, 3, 'Immigration Investigator',1600, 7),
(11, 4, 'Border Sector Chief', 2300, 31),
(11, 5, 'ICE Customs Commissioner', 3300, 63),

-- 12. EMS
(12, 1, 'Paramedic',         700,  3),
(12, 2, 'Critical Care Paramedic',1150,7),
(12, 3, 'Trauma Surgeon',             1750, 7),
(12, 4, 'Department Head',          2400, 31),
(12, 5, 'EMS Chief Medical Officer',  3400, 63),

-- 13. PMC
(13, 1, 'Security Contract Recruit',       900,  3),
(13, 2, 'Convoy Escort Operator',     1400, 7),
(13, 3, 'Assault Team Leader',      2000, 7),
(13, 4, 'Chief of Operations',   2800, 31),
(13, 5, 'PMC Executive Director',    3800, 63),

-- 14. Port Authority
(14, 1, 'Dock Dispatcher',              700,  3),
(14, 2, 'Terminal Customs Logistician',    1100, 7),
(14, 3, 'Senior Freight Inspector',       1600, 15),
(14, 4, 'Deputy Port Director',   2300, 31),
(14, 5, 'Port Director General',    3300, 63),

-- 15. SAN News
(15, 1, 'Newsroom Intern',                550,  3),
(15, 2, 'Crime Reporter', 950, 3),
(15, 3, 'Live Broadcast Anchor',          1400, 7),
(15, 4, 'Broadcast Editor-in-Chief',           2000, 31),
(15, 5, 'SAN News Executive Producer',  2900, 63),

-- 16. Grove Street Families
(16, 1, 'Street Hustler',                  0,    1),
(16, 2, 'Block Soldier',                  0,    3),
(16, 3, 'Senior Gangster',               0,    7),
(16, 4, 'Neighborhood Right Hand',             0,    31),
(16, 5, 'Leader of Grove Street Families',        0,    63),

-- 17. Ballas Gang
(17, 1, 'Corner Runner',                 0,    1),
(17, 2, 'Block Shooter',               0,    3),
(17, 3, 'Corner Boss',           0,    7),
(17, 4, 'Idlewood Authority',             0,    31),
(17, 5, 'Ballas Gang Leader',           0,    63),

-- 18. Los Santos Vagos
(18, 1, 'Barrio Rookie',                 0,    1),
(18, 2, 'Street Soldier',                   0,    3),
(18, 3, 'Arms Smuggler',           0,    7),
(18, 4, 'Cartel Advisor',               0,    31),
(18, 5, 'Padre of Los Santos Vagos',         0,    63),

-- 19. Varrios Los Aztecas
(19, 1, 'Junior Racer',                 0,    1),
(19, 2, 'Little Mexico Soldier',         0,    3),
(19, 3, 'Auto Syndicate Mechanic',          0,    7),
(19, 4, 'Neighborhood Veteran',               0,    31),
(19, 5, 'Jefe of Varrios Los Aztecas',       0,    63),

-- 20. Триады Сан-Фиерро
(20, 1, 'Chinatown Street Fighter',        0,    1),
(20, 2, 'Syndicate Enforcer',          0,    3),
(20, 3, 'Red Pole',                   0,    7),
(20, 4, 'Lodge Vanguard',                  0,    31),
(20, 5, 'Dragon Head of the Triads',           0,    63),

-- 21. Мафия Лас-Вентураса
(21, 1, 'Family Associate',               0,    1),
(21, 2, 'Family Soldier',                   0,    3),
(21, 3, 'Caporegime',                    0,    7),
(21, 4, 'Consigliere',                     0,    31),
(21, 5, 'Don of the Crime Family',         0,    63);

-- =============================================================================
--  5. СТАРТОВЫЕ ПРЕДПРИЯТИЯ (enterprises) И ОРДЕРА (enterprise_market_orders)
-- =============================================================================

INSERT INTO `enterprises` (
    `id`, `name`, `enterprise_type`, `ownership`, `owner_char_id`, `owner_org_id`,
    `warehouse_storage_id`, `reserve_usd`, `wage_per_kg_usd`,
    `pos_x`, `pos_y`, `pos_z`, `auction_price_usd`
) VALUES
-- Первичные добывающие предприятия (1..4, финансируются государством на старте)
(1,  'Hunter Quarry Iron Mine',     'MINE_ORE',    'STATE',   NULL, 1,    22, 1500000, 14, 595.4,   872.6,   -42.5, NULL),
(2,  'Octane Springs Oil Field', 'OIL_RIG',     'STATE',   NULL, 1,    23, 1500000, 16, 261.2,   1411.8,  10.6,  NULL),
(3,  'Angel Pine Logging Complex', 'SAWMILL', 'STATE',   NULL, 1,    24, 1000000, 12, -533.8,  -179.4,  78.4,  NULL),
(4,  'Flint County Grain Farm','FARM',       'STATE',   NULL, 1,    25, 1000000, 10, -382.1,  -1426.3, 25.7,  NULL),

-- Промышленные перерабатывающие заводы (5..7)
(5,  'Green Palms Oil Refinery','REFINERY',    'STATE',   NULL, 1,    26, 2500000, 8,  248.4,   1396.2,  10.6,  NULL),
(6,  'Ocean Docks Steel Mill',  'METALLURGY',  'STATE',   NULL, 1,    27, 2500000, 10, 2180.5,  -2253.8, 13.5,  NULL),
(7,  'Easter Basin Assembly Plant',          'FACTORY',     'UNOWNED', NULL, NULL, 28, 1200000, 12, -1042.6, -664.2,  32.0,  850000),

-- Розничные магазины и АЗС (8..13)
(8,  'Idlewood 24/7 Supermarket',                'RETAIL_SHOP', 'UNOWNED', NULL, NULL, 29, 400000,  5,  1352.3,  -1759.2, 13.5,  250000),
(9,  'Juniper Hill 24/7 Supermarket',          'RETAIL_SHOP', 'UNOWNED', NULL, NULL, 30, 400000,  5,  -2442.6, 754.8,   35.2,  250000),
(10, 'Las Venturas Creek Trading House',        'RETAIL_SHOP', 'UNOWNED', NULL, NULL, 31, 400000,  5,  2194.2,  1991.0,  12.3,  275000),
(11, 'Idlewood Gas Station',             'GAS_STATION', 'UNOWNED', NULL, NULL, 32, 600000,  5,  1940.1,  -1772.9, 13.4,  350000),
(12, 'Easter Basin Gas Station',        'GAS_STATION', 'UNOWNED', NULL, NULL, 33, 600000,  5,  -1676.3, 413.2,   7.2,   350000),
(13, 'Emerald Isle Gas Station',   'GAS_STATION', 'UNOWNED', NULL, NULL, 34, 600000,  5,  2115.2,  920.1,   10.8,  375000),

-- Нелегальные авторазборки / шроты (14..16)
(14, 'East Los Santos Chop Shop',   'CHOP_SHOP',   'PRIVATE', NULL, 19,   35, 300000,  8,  2403.5,  -1406.2, 24.0,  NULL),
(15, 'Doherty Underground Garage',               'CHOP_SHOP',   'PRIVATE', NULL, 20,   36, 350000,  8,  -2051.8, 178.4,   28.8,  NULL),
(16, 'Redsands West Chop Shop',            'CHOP_SHOP',   'PRIVATE', NULL, 21,   37, 400000,  8,  1658.4,  2196.1,  10.8,  NULL);

-- Стартовые биржевые ордера заводов и магазинов (enterprise_market_orders)
INSERT INTO `enterprise_market_orders` (
    `id`, `enterprise_id`, `order_type`, `item_def_id`, `price_per_unit_usd`, `target_amount`, `fulfilled_amount`
) VALUES
-- Закупка сырья заводами (BUY_RAW)
(1,  5,  'BUY_RAW',      76, 20,  5000, 0), -- НПЗ закупает Сырую нефть
(2,  6,  'BUY_RAW',      77, 18,  5000, 0), -- Металлургический комбинат закупает Железную руду
(3,  6,  'BUY_RAW',      76, 20,  2000, 0), -- Металлургический комбинат закупает Сырую нефть
(4,  7,  'BUY_RAW',      82, 48,  3000, 0), -- Сборочный завод закупает Листовой стальной прокат
(5,  7,  'BUY_RAW',      86, 36,  2000, 0), -- Сборочный завод закупает Синтетический пластик
(6,  7,  'BUY_RAW',      88, 22,  2000, 0), -- Сборочный завод закупает Строганые доски
(7,  11, 'BUY_RAW',      90, 28,  4000, 0), -- АЗС Айдлвуд закупает Очищенное топливо
(8,  12, 'BUY_RAW',      90, 28,  4000, 0), -- АЗС Истер-Бейсин закупает Очищенное топливо
(9,  13, 'BUY_RAW',      90, 28,  4000, 0), -- АЗС Изумрудный Остров закупает Очищенное топливо

-- Продажа готовой продукции заводами и магазинами (SELL_PRODUCT)
(10, 5,  'SELL_PRODUCT', 90, 32,  5000, 0), -- НПЗ продает Очищенное моторное топливо
(11, 5,  'SELL_PRODUCT', 86, 40,  2000, 0), -- НПЗ продает Гранулы пластика
(12, 6,  'SELL_PRODUCT', 82, 52,  3000, 0), -- Металлургия продает Листовой стальной прокат
(13, 6,  'SELL_PRODUCT', 83, 30,  2000, 0), -- Металлургия продает Пружины и штифты
(14, 6,  'SELL_PRODUCT', 84, 24,  2000, 0), -- Металлургия продает Подшипники
(15, 8,  'SELL_PRODUCT', 61, 15,  500,  0), -- 24/7 Айдлвуд: Бутылка воды 1 л
(16, 8,  'SELL_PRODUCT', 63, 25,  500,  0), -- 24/7 Айдлвуд: Горячий бургер
(17, 8,  'SELL_PRODUCT', 58, 30,  300,  0), -- 24/7 Айдлвуд: Стерильный бинт
(18, 8,  'SELL_PRODUCT', 41, 180, 100,  0); -- 24/7 Айдлвуд: Туристический рюкзак

-- =============================================================================
--  6. КОТИРОВКИ ГЛОБАЛЬНЫХ ТОРГОВЫХ ХАБОВ (port_market_quotes)
--     port_id: 1 = Порт Лос-Сантоса (Ocean Docks)
--              2 = Порт Сан-Фиерро (Easter Basin)
--              3 = Железнодорожный и авиационный хаб Лас-Вентураса
-- =============================================================================

INSERT INTO `port_market_quotes` (
    `port_id`, `item_def_id`, `ref_price_usd`, `current_stock`, `target_stock`, `spread_percent`
) VALUES
-- Порт 1: Лос-Сантос (Специализация: нефть, топливо, продовольствие, товары широкого потребления)
(1, 76, 22,   12000, 10000, 0.12), -- Сырая нефть
(1, 77, 20,   10000, 10000, 0.12), -- Железная руда
(1, 78, 16,   10000, 10000, 0.12), -- Древесина-кругляк
(1, 79, 8,    15000, 15000, 0.12), -- Сырая техническая вода
(1, 80, 14,   12000, 10000, 0.12), -- Зерно и мука
(1, 81, 45,   6000,  8000,  0.12), -- Химические реактивы и сера
(1, 82, 55,   8000,  10000, 0.12), -- Листовой стальной прокат
(1, 83, 32,   6000,  6000,  0.12), -- Закаленные пружины и штифты
(1, 84, 26,   6000,  6000,  0.12), -- Прецизионные подшипники
(1, 85, 12,   10000, 10000, 0.12), -- Гвозди и стальной крепеж
(1, 86, 42,   9000,  10000, 0.12), -- Гранулы синтетического пластика
(1, 87, 68,   4000,  5000,  0.12), -- Бездымный оружейный порох
(1, 88, 25,   8000,  8000,  0.12), -- Строганые древесные доски
(1, 89, 28,   7500,  8000,  0.12), -- Текстильное полотно
(1, 90, 34,   15000, 15000, 0.12), -- Очищенное моторное топливо
(1, 48, 650,  1000,  1000,  0.12), -- Канистра с бензином 20 л
(1, 56, 120,  2000,  2000,  0.12), -- Аптечка первой помощи
(1, 62, 45,   5000,  5000,  0.12), -- Армейский сухпаек MRE

-- Порт 2: Сан-Фиерро (Специализация: машиностроение, электроника, химия, импорт из Азии)
(2, 76, 24,   9000,  10000, 0.12), -- Сырая нефть
(2, 77, 19,   11000, 10000, 0.12), -- Железная руда
(2, 78, 15,   12000, 10000, 0.12), -- Древесина-кругляк
(2, 79, 8,    15000, 15000, 0.12), -- Сырая техническая вода
(2, 80, 16,   9000,  10000, 0.12), -- Зерно и мука
(2, 81, 40,   9000,  8000,  0.12), -- Химические реактивы и сера
(2, 82, 54,   10000, 10000, 0.12), -- Листовой стальной прокат
(2, 83, 30,   7000,  6000,  0.12), -- Закаленные пружины и штифты
(2, 84, 24,   7500,  6000,  0.12), -- Прецизионные подшипники
(2, 85, 12,   10000, 10000, 0.12), -- Гвозди и стальной крепеж
(2, 86, 38,   11000, 10000, 0.12), -- Гранулы синтетического пластика
(2, 87, 65,   5000,  5000,  0.12), -- Бездымный оружейный порох
(2, 88, 24,   9000,  8000,  0.12), -- Строганые древесные доски
(2, 89, 26,   9000,  8000,  0.12), -- Текстильное полотно
(2, 90, 36,   13000, 15000, 0.12), -- Очищенное моторное топливо
(2, 50, 280,  1500,  1500,  0.12), -- Смартфон
(2, 53, 220,  1500,  1500,  0.12), -- Портативная рация
(2, 55, 340,  800,   1000,  0.12), -- Чемодан криминалиста

-- Порт 3: Лас-Вентурас (Специализация: тяжелая металлургия, нефтепродукты, снабжение пустыни)
(3, 76, 20,   14000, 10000, 0.12), -- Сырая нефть
(3, 77, 18,   14000, 10000, 0.12), -- Железная руда
(3, 78, 19,   7000,  10000, 0.12), -- Древесина-кругляк
(3, 79, 10,   10000, 15000, 0.12), -- Сырая техническая вода
(3, 80, 17,   8000,  10000, 0.12), -- Зерно и мука
(3, 81, 44,   7000,  8000,  0.12), -- Химические реактивы и сера
(3, 82, 58,   7500,  10000, 0.12), -- Листовой стальной прокат
(3, 83, 34,   5500,  6000,  0.12), -- Закаленные пружины и штифты
(3, 84, 28,   5500,  6000,  0.12), -- Прецизионные подшипники
(3, 85, 13,   9000,  10000, 0.12), -- Гвозди и стальной крепеж
(3, 86, 40,   10000, 10000, 0.12), -- Гранулы синтетического пластика
(3, 87, 70,   4500,  5000,  0.12), -- Бездымный оружейный порох
(3, 88, 28,   6500,  8000,  0.12), -- Строганые древесные доски
(3, 89, 30,   7000,  8000,  0.12), -- Текстильное полотно
(3, 90, 32,   16000, 15000, 0.12), -- Очищенное моторное топливо
(3, 46, 260,  1200,  1200,  0.12), -- Ящик автомеханика с ключами
(3, 54, 150,  1500,  1500,  0.12), -- Шахтерская кирка
(3, 64, 40,   3000,  3000,  0.12); -- Бутылка виски

-- =============================================================================
--  7. НАЧАЛЬНОЕ НАПОЛНЕНИЕ КАЗН ОРГАНИЗАЦИЙ И СКЛАДОВ ПРЕДПРИЯТИЙ (storage_items)
--     meta_int1 = 0 (CLEAN_CASH), meta_int2 = 1 (USD) для item_def_id = 73
-- =============================================================================

INSERT INTO `storage_items` (
    `storage_id`, `item_def_id`, `amount`, `durability`, `ammo_count`,
    `nested_storage_id`, `meta_int1`, `meta_int2`, `meta_str`
) VALUES
-- 1. Физическая казна Правительства штата (Seed Money наличными + бланки)
(1,  73, 10000, 100.0, 0,   NULL, 0, 1, 'FEDERAL_RESERVE_SEED_USD'),
(1,  68, 100,   100.0, 0,   NULL, 0, 0, 'GOV_BLANK_PASSPORT'),
(1,  69, 100,   100.0, 0,   NULL, 0, 0, 'GOV_BLANK_WEAPON_LIC'),

-- 2..5. Арсеналы полиции и шерифов (LSPD, SFPD, LVPD, SASD)
(2,  23, 10,    100.0, 180, NULL, 0, 100001, 'LSPD_ARMORY_M4'),
(2,  13, 15,    100.0, 60,  NULL, 0, 100002, 'LSPD_ARMORY_9MM'),
(2,  40, 20,    100.0, 0,   NULL, 0, 0,      'LSPD_ARMORY_VEST'),
(2,  44, 10,    100.0, 0,   NULL, 0, 0,      'LSPD_ARMORY_CUFFS'),
(3,  23, 10,    100.0, 180, NULL, 0, 200001, 'SFPD_ARMORY_M4'),
(3,  13, 15,    100.0, 60,  NULL, 0, 200002, 'SFPD_ARMORY_9MM'),
(3,  40, 20,    100.0, 0,   NULL, 0, 0,      'SFPD_ARMORY_VEST'),
(4,  23, 10,    100.0, 180, NULL, 0, 300001, 'LVPD_ARMORY_M4'),
(4,  13, 15,    100.0, 60,  NULL, 0, 300002, 'LVPD_ARMORY_9MM'),
(4,  40, 20,    100.0, 0,   NULL, 0, 0,      'LVPD_ARMORY_VEST'),
(5,  16, 10,    100.0, 40,  NULL, 0, 400001, 'SASD_ARMORY_SHOTGUN'),
(5,  13, 15,    100.0, 60,  NULL, 0, 400002, 'SASD_ARMORY_9MM'),
(5,  40, 20,    100.0, 0,   NULL, 0, 0,      'SASD_ARMORY_VEST'),

-- 6..11. Армия, ФБР, ЦРУ, Таможня ICE
(6,  23, 25,    100.0, 240, NULL, 0, 500001, 'LSA_ARMORY_M4'),
(7,  23, 25,    100.0, 240, NULL, 0, 600001, 'SFA_ARMORY_M4'),
(8,  23, 30,    100.0, 240, NULL, 0, 700001, 'LVA_ARMORY_M4'),
(9,  21, 15,    100.0, 150, NULL, 0, 800001, 'FBI_ARMORY_MP5'),
(9,  55, 10,    100.0, 0,   NULL, 0, 0,      'FBI_FORENSICS_KIT'),
(10, 14, 15,    100.0, 60,  NULL, 0, 900001, 'CIA_SILENCED_9MM'),
(11, 21, 10,    100.0, 120, NULL, 0, 910001, 'ICE_ARMORY_MP5'),

-- 12. Медицинский резерв EMS
(12, 56, 50,    100.0, 0,   NULL, 0, 0,      'EMS_MEDKITS'),
(12, 57, 15,    100.0, 0,   NULL, 0, 0,      'EMS_SURGICAL_KITS'),
(12, 58, 100,   100.0, 0,   NULL, 0, 0,      'EMS_BANDAGES'),
(12, 59, 50,    100.0, 0,   NULL, 0, 0,      'EMS_TOURNIQUETS'),
(12, 60, 50,    100.0, 0,   NULL, 0, 0,      'EMS_MORPHINE'),

-- 16..21. Сейфы криминальных синдикатов
(16, 73, 50,    100.0, 0,   NULL, 1, 1,      'GROVE_STASH_CASH'),
(17, 73, 50,    100.0, 0,   NULL, 1, 1,      'BALLAS_STASH_CASH'),
(18, 73, 50,    100.0, 0,   NULL, 1, 1,      'VAGOS_STASH_CASH'),
(19, 73, 50,    100.0, 0,   NULL, 1, 1,      'AZTECAS_STASH_CASH'),
(20, 73, 100,   100.0, 0,   NULL, 1, 3,      'TRIADS_STASH_CNY'),
(21, 73, 120,   100.0, 0,   NULL, 1, 1,      'LV_MAFIA_STASH_USD'),

-- Стартовые товарные запасы на складах предприятий (ID хранилищ 22..34)
(22, 77, 1500,  100.0, 0,   NULL, 0, 0,      'INITIAL_IRON_ORE'),
(23, 76, 1500,  100.0, 0,   NULL, 0, 0,      'INITIAL_CRUDE_OIL'),
(24, 78, 1200,  100.0, 0,   NULL, 0, 0,      'INITIAL_WOOD_LOGS'),
(25, 80, 1200,  100.0, 0,   NULL, 0, 0,      'INITIAL_GRAIN_FLOUR'),
(26, 90, 2500,  100.0, 0,   NULL, 0, 0,      'INITIAL_REFINED_FUEL'),
(26, 86, 800,   100.0, 0,   NULL, 0, 0,      'INITIAL_PLASTIC'),
(27, 82, 1200,  100.0, 0,   NULL, 0, 0,      'INITIAL_STEEL_SHEETS'),
(27, 83, 600,   100.0, 0,   NULL, 0, 0,      'INITIAL_SPRINGS'),
(27, 84, 600,   100.0, 0,   NULL, 0, 0,      'INITIAL_BEARINGS'),
(29, 61, 200,   100.0, 0,   NULL, 0, 0,      'SHOP_LS_WATER'),
(29, 63, 200,   100.0, 0,   NULL, 0, 0,      'SHOP_LS_BURGERS'),
(29, 58, 100,   100.0, 0,   NULL, 0, 0,      'SHOP_LS_BANDAGES'),
(30, 61, 200,   100.0, 0,   NULL, 0, 0,      'SHOP_SF_WATER'),
(30, 63, 200,   100.0, 0,   NULL, 0, 0,      'SHOP_SF_BURGERS'),
(31, 61, 200,   100.0, 0,   NULL, 0, 0,      'SHOP_LV_WATER'),
(31, 63, 200,   100.0, 0,   NULL, 0, 0,      'SHOP_LV_BURGERS'),
(32, 90, 5000,  100.0, 0,   NULL, 0, 0,      'GAS_LS_FUEL_RESERVE'),
(33, 90, 5000,  100.0, 0,   NULL, 0, 0,      'GAS_SF_FUEL_RESERVE'),
(34, 90, 5000,  100.0, 0,   NULL, 0, 0,      'GAS_LV_FUEL_RESERVE');

-- Запись в аудит-лог о первичной эмиссии Seed Money Правительства штата
INSERT INTO `audit_logs` (
    `actor_char_id`, `action_type`, `source_entity`, `target_entity`,
    `item_def_id`, `amount`, `details`
) VALUES (
    NULL, 'SEED_GENESIS', 'SYSTEM_TREASURY', 'ORG_1_GOVERNMENT',
    73, 100000000, 'Initial seeding of the state reserve (Seed Money) during database deployment'
);

SET FOREIGN_KEY_CHECKS = 1;

# SAN ANDREAS RP — Technical Architecture & System Specification (`TECH_CONTEXT.MD`)

**Версия документа:** 1.0.0  
**Платформа:** open.mp Server v1.6.7+ (Linux x86/x64 Native)  
**Основной язык разработки:** Pawn (`qawno` compiler с оптимизацией `-O2 -d1`) + C++ Components SDK  
**Язык пользовательского интерфейса:** Русский (`Windows-1251 / CP1251` для клиентских строк Pawn)  
**СУБД:** MySQL 8.0+ / MariaDB 10.11+ (InnoDB, UTF8MB4, асинхронный пул соединений)  
**Архітектурний / Архитектурный стиль:** Модульный монолит с событийно-ориентированной шиной (`y_hooks`), строгой инкапсуляцией состояния и авторитетным сервером (Server-Authoritative).

---

## 1. Системная архитектура и технологический стек

### 1.1. Конфигурация ядра сервера (`config.json` и C++ компоненты)
Сервер работает как однопоточный игровой цикл (`main thread` для игровой логики Pawn) в сочетании с многопоточными C++ компонентами для сетевого ввода/вывода и работы с БД:

1. **`omp-server` (Core Engine v1.6.7+):** Управление сущностями мира, синхронизацией игроков, транспорта, нативными колбеками и кастомными моделями (`models/`).
2. **`mysql` (BlueG R41-4+):** Асинхронное выполнение SQL-запросов (`mysql_tquery`, `mysql_pquery`) в фоновом пуле из 12 потоков. Блокирующие запросы (`mysql_query`) **строго запрещены** во время активной игровой сессии (разрешены только на этапе `OnGameModeInit` при загрузке статических справочников). При инициализации соединения обязательно устанавливается кодировка клиента `mysql_set_charset(gMySQL, "cp1251")`.
3. **`streamer` (Incognito Streamer v2.9.6+):** Динамический стриминг объектов, пикапов, 3D-текстов и сферических/полигональных зон (`DynamicArea`) для шахт, портов, таможенных КПП, мест преступлений и выброшенных предметов.
4. **`Pawn.CMD`:** Быстрый процессор команд на основе хеш-таблиц с поддержкой флагов доступа и псевдонимов (`alias`).
5. **`Pawn.RakNet`:** Перехват и валидация сырых пакетов (`RPC` и `Packet`) на уровне сети (античит на оружие, патроны, телепорт, подмену скорости транспорта, фейковые выстрелы).
6. **`Pawn.Regex`:** Валидация входных данных (RP-ники формата `First_Last`, номера телефонов, номера SSN).
7. **`bcrypt`:** Асинхронное хеширование паролей (cost factor = `12`).
8. **`YSI-Includes` (`y_hooks`, `y_iterate`, `y_timers`, `y_va`):** Декомпозиция колбеков без монолитных файлов, пулы ітераторов $O(1)$ вместо циклов `for (new i = 0; i < MAX_PLAYERS; i++)`.

### 1.2. Файловая структура репозитория (`Server/`)

```text
Server/
├── components/                 # C++ плагины и компоненты open.mp (.so / .dll)
├── models/                     # Кастомные .dff/.txd модели (авто, скины, предметы)
├── scriptfiles/                # Локальные кеш-файлы, гео-данные зон, резервные дампы
├── config.json                 # Конфигурация open.mp (порти, лимиты, арты, логирование)
├── CONTEXT_OF_PROJECT.md       # Геймдизайн-документ (GDD)
├── TECH_CONTEXT.MD             # Текущая техническая спецификация
├── ROADMAP.md                  # Пошаговый инженерный план сборки
├── AGENTS.MD                   # Регламент и стандарты работы для ИИ-агентов
└── gamemodes/
    ├── main.pwn                # Точка входа: подключение библиотек и модулей
    └── modules/
        ├── core/               # Ядро, константы, конфигурация, БД, логер, античит
        │   ├── mod_config.pwn
        │   ├── mod_database.pwn
        │   ├── mod_utils.pwn
        │   ├── mod_audit.pwn
        │   └── mod_anticheat.pwn
        ├── entities/           # Базовые сущности и управление данными
        │   ├── mod_account.pwn
        │   ├── mod_character.pwn
        │   ├── mod_roles.pwn
        │   ├── mod_skills.pwn
        │   ├── mod_storage.pwn
        │   ├── mod_items.pwn
        │   ├── mod_vehicles.pwn
        │   └── mod_properties.pwn
        ├── systems/            # Игровые и бизнес-системы
        │   ├── mod_survival.pwn
        │   ├── mod_medical.pwn
        │   ├── mod_weapons.pwn
        │   ├── mod_crafting.pwn
        │   ├── mod_economy.pwn
        │   ├── mod_ports.pwn
        │   ├── mod_logistics.pwn
        │   ├── mod_banking.pwn
        │   ├── mod_organizations.pwn
        │   ├── mod_justice.pwn
        │   ├── mod_forensics.pwn
        │   └── mod_telecom.pwn
        └── ui/                 # Текстовый интерфейс (Text-First, 100% Русский)
            ├── mod_dialogs.pwn
            ├── mod_commands.pwn
            └── mod_hud.pwn
```

### 1.3. Правила межмодульного взаимодействия (Архитектурные контракты)
1. **Инкапсуляция состояния:** Массивы данных модуля (например, `gPlayerData[MAX_PLAYERS][E_PLAYER_DATA]`) объявляются как `static stock` внутри своего модуля. Другие модули не имеют прямого доступа к внутренним массивам.
2. **Публичный API:** Взаимодействие происходит исключительно через публичные функции с префиксом модуля:
   - `Storage_GiveItem(storage_id, item_def_id, amount, ammo, ...)`
   - `Char_ModifyWantedLevel(playerid, delta, reason[])`
   - `Org_HasPermission(char_id, org_id, E_ORG_PERM:perm)`
3. **Событийная модель (`y_hooks`):** Каждый модуль подписывается на системные события (`hook OnPlayerConnect`, `hook OnPlayerDisconnect`, `hook OnPlayerWeaponShot`, `hook OnPlayerKeyStateChange`) независимо.
4. **Серверные тики (`y_timers`):**
   - `Tick_Fast (250 ms)`: Проверка античита, состояния оружия в руках, заклинивания, позиций транспорта.
   - `Tick_Second (1000 ms)`: Кровотечения, таймер шока, заправка авто, крафт/добыча, счетчик активного онлайна (без AFK) для снятия розыска.
   - `Tick_Minute (60000 ms)`: Голод, жажда, перегруз (Encumbrance), обновление котировок в портах, автосохранение измененных сущностей (`dirty flag`), очистка просроченных улик.

---

## 2. Полная реляционная схема базы данных (MySQL / MariaDB)

Все таблицы используют движок `InnoDB`, кодировку `utf8mb4_unicode_ci` и строгую целостность внешних ключей (`FOREIGN KEY`). Масса всегда хранится в **граммах (`INT UNSIGNED`)**, объем — в **миллилитрах (`INT UNSIGNED`)**, деньги — в **центах (`BIGINT`)** или целых единицах валюты, чтобы избежать погрешностей чисел с плавающей запятой (`FLOAT`).

### 2.1. Аккаунты и сессии безопасности

```sql
CREATE TABLE `accounts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `username` VARCHAR(32) NOT NULL,
    `password_hash` CHAR(60) NOT NULL,
    `email` VARCHAR(128) DEFAULT NULL,
    `admin_level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `is_banned` TINYINT(1) NOT NULL DEFAULT 0,
    `ban_reason` VARCHAR(255) DEFAULT NULL,
    `ban_expires_at` DATETIME DEFAULT NULL,
    `reg_ip` VARCHAR(45) NOT NULL,
    `last_ip` VARCHAR(45) NOT NULL,
    `last_hwid` VARCHAR(64) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_login_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_accounts_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `account_sessions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NOT NULL,
    `char_id` INT UNSIGNED DEFAULT NULL,
    `ip_address` VARCHAR(45) NOT NULL,
    `hwid_hash` VARCHAR(64) DEFAULT NULL,
    `connected_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `disconnected_at` DATETIME DEFAULT NULL,
    `disconnect_reason` TINYINT UNSIGNED DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_sessions_account` (`account_id`),
    CONSTRAINT `fk_sessions_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2.2. Персонажи, навыки и медицинское состояние

```sql
CREATE TABLE `characters` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NOT NULL,
    `rp_name` VARCHAR(24) NOT NULL,
    `gender` TINYINT UNSIGNED NOT NULL COMMENT '1=Male, 2=Female',
    `race` TINYINT UNSIGNED NOT NULL,
    `role_id` TINYINT UNSIGNED NOT NULL COMMENT '1..25 (25 стартовых ролей)',
    `level` SMALLINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Возраст персонажа = 17 + level',
    `exp_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    `citizenship` ENUM('CITIZEN', 'IMMIGRANT') NOT NULL DEFAULT 'CITIZEN',
    `ssn` CHAR(11) DEFAULT NULL COMMENT 'Формат XXX-XX-XXXX, NULL для нелегалов',
    `skin_id` INT UNSIGNED NOT NULL,
    `fighting_style` TINYINT UNSIGNED NOT NULL DEFAULT 4,
    
    -- Физиология и выживание
    `hp` FLOAT NOT NULL DEFAULT 100.0,
    `armour` FLOAT NOT NULL DEFAULT 0.0,
    `hunger` FLOAT NOT NULL DEFAULT 100.0,
    `thirst` FLOAT NOT NULL DEFAULT 100.0,
    `stamina` FLOAT NOT NULL DEFAULT 100.0,
    `stress` FLOAT NOT NULL DEFAULT 0.0,
    `addiction_level` FLOAT NOT NULL DEFAULT 0.0,
    `last_drug_at` INT UNSIGNED NOT NULL DEFAULT 0,
    
    -- Правовой и криминальный статус
    `wanted_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Шкала 0..100',
    `active_play_seconds` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Счетчик для Warrant Decay (3600с = -1)',
    `jail_seconds_left` INT UNSIGNED NOT NULL DEFAULT 0,
    `jail_type` ENUM('NONE', 'KPZ', 'STATE_PRISON', 'FEDERAL_SUPERMAX') NOT NULL DEFAULT 'NONE',
    `weapon_license_banned` TINYINT(1) NOT NULL DEFAULT 0,
    `is_ck_dead` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = Перманентная смерть (CK)',
    
    -- Хранилища персонажа (Двухслойная система)
    `layer1_storage_id` BIGINT UNSIGNED NOT NULL COMMENT 'Внешний слой (выпадает при смерти)',
    `layer2_storage_id` BIGINT UNSIGNED NOT NULL COMMENT 'Внутренний потайной слой (сохраняется)',
    
    -- Финансы и фракция
    `org_id` INT UNSIGNED DEFAULT NULL,
    `org_rank_id` INT UNSIGNED DEFAULT NULL,
    `bank_debt_usd` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    
    -- Позиция в мире
    `pos_x` FLOAT NOT NULL,
    `pos_y` FLOAT NOT NULL,
    `pos_z` FLOAT NOT NULL,
    `pos_a` FLOAT NOT NULL,
    `interior` INT NOT NULL DEFAULT 0,
    `virtual_world` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_characters_name` (`rp_name`),
    UNIQUE KEY `uk_characters_ssn` (`ssn`),
    KEY `idx_characters_account` (`account_id`),
    CONSTRAINT `fk_characters_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Широкая таблиця навыков (0..1000) для загрузки за O(1) одной строкой
CREATE TABLE `character_skills` (
    `char_id` INT UNSIGNED NOT NULL,
    -- Оружейные навыки
    `melee_blunt` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `melee_bladed` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `heavy_tools` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `pistol` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `pistol_silenced` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `desert_eagle` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `shotgun` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `sawnoff_shotgun` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `spas12_shotgun` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `micro_uzi` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `tec9_skill` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `mp5` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `ak47` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `m4` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `country_rifle` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `sniper_rifle` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `heavy_ordnance` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `throwables` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    -- Физические и транспортные
    `stamina` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    `muscle` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    `driving_skill` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    `bike_skill` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    `cycling_skill` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    `flying_skill` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `lung_capacity` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    -- Криминальные
    `lockpicking` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `hotwiring` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `safe_cracking` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `pickpocketing` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `demolitions` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `stealth` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    -- Ремесло и техника
    `mechanics` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `gunsmithing` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `chemistry` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `mining_logging` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `metallurgy` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    -- Медицина и выживание
    `first_aid` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `surgery` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `survivalism` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `forensics` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `charisma_barter` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`char_id`),
    CONSTRAINT `fk_skills_char` FOREIGN KEY (`char_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Детальное состояние травм по зонам тела
CREATE TABLE `character_injuries` (
    `char_id` INT UNSIGNED NOT NULL,
    `head_hp` TINYINT UNSIGNED NOT NULL DEFAULT 100,
    `torso_hp` TINYINT UNSIGNED NOT NULL DEFAULT 100,
    `left_arm_hp` TINYINT UNSIGNED NOT NULL DEFAULT 100,
    `right_arm_hp` TINYINT UNSIGNED NOT NULL DEFAULT 100,
    `left_leg_hp` TINYINT UNSIGNED NOT NULL DEFAULT 100,
    `right_leg_hp` TINYINT UNSIGNED NOT NULL DEFAULT 100,
    `bleeding_type` ENUM('NONE', 'VENOUS', 'ARTERIAL') NOT NULL DEFAULT 'NONE',
    `arterial_timer_sec` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `pain_shock` TINYINT(1) NOT NULL DEFAULT 0,
    `fracture_flags` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Битовая маска: 1=L_Arm, 2=R_Arm, 4=L_Leg, 8=R_Leg, 16=Ribs',
    PRIMARY KEY (`char_id`),
    CONSTRAINT `fk_injuries_char` FOREIGN KEY (`char_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2.3. Универсальная архитектура предметов, хранилищ и крафта

```sql
-- Статический справочник предметов (75+ записей, кешируется в RAM при старте)
CREATE TABLE `item_definitions` (
    `id` SMALLINT UNSIGNED NOT NULL,
    `code_name` VARCHAR(48) NOT NULL,
    `display_name` VARCHAR(64) NOT NULL COMMENT 'Русское название предмета для UI',
    `category` ENUM('RAW', 'INTERMEDIATE', 'MELEE', 'FIREARM', 'HEAVY_THROWABLE', 'GEAR_ELECTRONICS', 'MEDICAL_FOOD', 'ILLEGAL', 'DOCUMENT_CURRENCY') NOT NULL,
    `base_weight_g` INT UNSIGNED NOT NULL COMMENT 'Базовая масса 1 ед. в граммах',
    `base_volume_ml` INT UNSIGNED NOT NULL COMMENT 'Базовый объем 1 ед. в мл',
    `is_stackable` TINYINT(1) NOT NULL DEFAULT 1,
    `max_stack` INT UNSIGNED NOT NULL DEFAULT 1000,
    `gta_weapon_id` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 если не оружие GTA SA',
    `ammo_unit_weight_g` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Масса 1 патрона в граммах (напр. 12г для 5.56)',
    `inner_max_weight_g` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Если > 0, предмет является переносным контейнером (рюкзак)',
    `inner_max_volume_ml` INT UNSIGNED NOT NULL DEFAULT 0,
    `can_layer2` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = разрешено класть в потайной Слой 2',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_item_code` (`code_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Полиморфная сущность Storage (карманы, багажники, цистерны, сейфы, трупы, схроны)
CREATE TABLE `storages` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `storage_type` ENUM(
        'PLAYER_LAYER1', 'PLAYER_LAYER2',
        'VEHICLE_GLOVEBOX', 'VEHICLE_TRUNK',
        'PROPERTY_STASH', 'ORG_VAULT',
        'ENTERPRISE_WAREHOUSE', 'NESTED_BAG',
        'WORLD_DROP', 'CORPSE_LOOT'
    ) NOT NULL,
    `owner_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'ID владельца в зависимости от storage_type',
    `max_weight_g` BIGINT UNSIGNED NOT NULL,
    `max_volume_ml` BIGINT UNSIGNED NOT NULL,
    `is_locked` TINYINT(1) NOT NULL DEFAULT 0,
    `lock_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0..5 сложность взлома',
    `pos_x` FLOAT DEFAULT NULL,
    `pos_y` FLOAT DEFAULT NULL,
    `pos_z` FLOAT DEFAULT NULL,
    `interior` INT NOT NULL DEFAULT 0,
    `virtual_world` INT NOT NULL DEFAULT 0,
    `expires_at` DATETIME DEFAULT NULL COMMENT 'TTL для трупов и выброшенных предметов',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_storage_owner` (`storage_type`, `owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Экземпляры предметов внутри хранилищ
CREATE TABLE `storage_items` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `storage_id` BIGINT UNSIGNED NOT NULL,
    `item_def_id` SMALLINT UNSIGNED NOT NULL,
    `amount` INT UNSIGNED NOT NULL DEFAULT 1,
    `durability` FLOAT NOT NULL DEFAULT 100.0 COMMENT '0.0..100.0 состояние износа',
    `ammo_count` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Количество патронов внутри ствола',
    `nested_storage_id` BIGINT UNSIGNED DEFAULT NULL COMMENT 'Ссылка на внутреннее хранилище рюкзака/сумки',
    `meta_int1` BIGINT DEFAULT 0 COMMENT 'Напр. ID авто/дома для ключа, или ID банковского счета',
    `meta_int2` BIGINT DEFAULT 0 COMMENT 'Напр. серийный номер оружия или номинал валюты (1=USD, 2=EUR, 3=CNY)',
    `meta_str` VARCHAR(64) DEFAULT NULL COMMENT 'Напр. SSN на паспорте, номер телефона на SIM',
    PRIMARY KEY (`id`),
    KEY `idx_sitems_storage` (`storage_id`),
    CONSTRAINT `fk_sitems_storage` FOREIGN KEY (`storage_id`) REFERENCES `storages` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_sitems_def` FOREIGN KEY (`item_def_id`) REFERENCES `item_definitions` (`id`),
    CONSTRAINT `fk_sitems_nested` FOREIGN KEY (`nested_storage_id`) REFERENCES `storages` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Рецепты крафта и заводской переработки
CREATE TABLE `craft_recipes` (
    `id` SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `output_item_id` SMALLINT UNSIGNED NOT NULL,
    `output_amount` INT UNSIGNED NOT NULL DEFAULT 1,
    `station_type` ENUM('HAND', 'WORKBENCH_WEAPON', 'WORKBENCH_CHEM', 'FACTORY_REFINERY', 'FACTORY_METALLURGY', 'FACTORY_ASSEMBLY') NOT NULL,
    `required_skill` VARCHAR(32) DEFAULT NULL,
    `min_skill_level` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `craft_time_sec` SMALLINT UNSIGNED NOT NULL DEFAULT 5,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_recipe_out` FOREIGN KEY (`output_item_id`) REFERENCES `item_definitions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `craft_recipe_inputs` (
    `recipe_id` SMALLINT UNSIGNED NOT NULL,
    `input_item_id` SMALLINT UNSIGNED NOT NULL,
    `input_amount` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`recipe_id`, `input_item_id`),
    CONSTRAINT `fk_rinput_recipe` FOREIGN KEY (`recipe_id`) REFERENCES `craft_recipes` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_rinput_item` FOREIGN KEY (`input_item_id`) REFERENCES `item_definitions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2.4. Унифицированный движок организаций (Банды, Корпорации, Госструктуры)

```sql
CREATE TABLE `organizations` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(64) NOT NULL,
    `tag` VARCHAR(8) NOT NULL,
    `legal_status` ENUM('UNREGISTERED', 'PRIVATE_CORP', 'STATE_AGENCY') NOT NULL DEFAULT 'UNREGISTERED',
    `is_permanent` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = Core системная фракция (21 шт), не удаляется',
    `charter_flags` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Битовая маска гос. лицензий и полномочий',
    `vault_storage_id` BIGINT UNSIGNED NOT NULL COMMENT 'Физическая бронированная казна-хранилище',
    `bank_balance_usd` BIGINT NOT NULL DEFAULT 0 COMMENT 'Безналичный счет (только CORP/STATE)',
    `is_bank_frozen` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Заморозка счета по решению суда/ФБР',
    `radio_freq` INT UNSIGNED NOT NULL DEFAULT 0,
    `hq_x` FLOAT NOT NULL DEFAULT 0.0,
    `hq_y` FLOAT NOT NULL DEFAULT 0.0,
    `hq_z` FLOAT NOT NULL DEFAULT 0.0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_org_name` (`name`),
    CONSTRAINT `fk_org_vault` FOREIGN KEY (`vault_storage_id`) REFERENCES `storages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `organization_ranks` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `org_id` INT UNSIGNED NOT NULL,
    `rank_order` TINYINT UNSIGNED NOT NULL COMMENT '1..20 иерархия',
    `title` VARCHAR(48) NOT NULL,
    `salary_usd` INT UNSIGNED NOT NULL DEFAULT 0,
    `permissions_mask` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Матрица RBAC прав',
    PRIMARY KEY (`id`),
    KEY `idx_ranks_org` (`org_id`),
    CONSTRAINT `fk_ranks_org` FOREIGN KEY (`org_id`) REFERENCES `organizations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2.5. Zero-Faucet экономика, предприятия, порты и логистика

```sql
CREATE TABLE `enterprises` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(64) NOT NULL,
    `enterprise_type` ENUM('MINE_ORE', 'OIL_RIG', 'SAWMILL', 'FARM', 'REFINERY', 'METALLURGY', 'FACTORY', 'RETAIL_SHOP', 'GAS_STATION', 'CHOP_SHOP') NOT NULL,
    `ownership` ENUM('STATE', 'PRIVATE', 'UNOWNED') NOT NULL DEFAULT 'UNOWNED',
    `owner_char_id` INT UNSIGNED DEFAULT NULL,
    `owner_org_id` INT UNSIGNED DEFAULT NULL,
    `warehouse_storage_id` BIGINT UNSIGNED NOT NULL,
    `reserve_usd` BIGINT NOT NULL DEFAULT 0 COMMENT 'Оборотный капитал предприятия',
    `wage_per_kg_usd` INT UNSIGNED NOT NULL DEFAULT 5,
    `pos_x` FLOAT NOT NULL,
    `pos_y` FLOAT NOT NULL,
    `pos_z` FLOAT NOT NULL,
    `auction_price_usd` BIGINT UNSIGNED DEFAULT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_ent_storage` FOREIGN KEY (`warehouse_storage_id`) REFERENCES `storages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Биржевые ордера предприятий на закупку сырья и продажу продукции
CREATE TABLE `enterprise_market_orders` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `enterprise_id` INT UNSIGNED NOT NULL,
    `order_type` ENUM('BUY_RAW', 'SELL_PRODUCT') NOT NULL,
    `item_def_id` SMALLINT UNSIGNED NOT NULL,
    `price_per_unit_usd` INT UNSIGNED NOT NULL,
    `target_amount` INT UNSIGNED NOT NULL,
    `fulfilled_amount` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_orders_ent` (`enterprise_id`),
    CONSTRAINT `fk_orders_ent` FOREIGN KEY (`enterprise_id`) REFERENCES `enterprises` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_orders_item` FOREIGN KEY (`item_def_id`) REFERENCES `item_definitions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Глобальные торговые хабы (Порты LS, SF, LV)
CREATE TABLE `port_market_quotes` (
    `port_id` TINYINT UNSIGNED NOT NULL COMMENT '1=LS Port, 2=SF Port, 3=LV Rail/Air Hub',
    `item_def_id` SMALLINT UNSIGNED NOT NULL,
    `ref_price_usd` INT UNSIGNED NOT NULL COMMENT 'Эталонная цена',
    `current_stock` BIGINT UNSIGNED NOT NULL DEFAULT 10000,
    `target_stock` BIGINT UNSIGNED NOT NULL DEFAULT 10000,
    `spread_percent` FLOAT NOT NULL DEFAULT 0.12 COMMENT '12% спред покупки/продажи',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`port_id`, `item_def_id`),
    CONSTRAINT `fk_port_item` FOREIGN KEY (`item_def_id`) REFERENCES `item_definitions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Контракты дальнобойщиков
CREATE TABLE `logistics_contracts` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `source_ent_id` INT UNSIGNED NOT NULL,
    `dest_type` ENUM('ENTERPRISE', 'PORT') NOT NULL,
    `dest_id` INT UNSIGNED NOT NULL,
    `item_def_id` SMALLINT UNSIGNED NOT NULL,
    `amount` INT UNSIGNED NOT NULL,
    `total_weight_g` BIGINT UNSIGNED NOT NULL,
    `trucker_char_id` INT UNSIGNED DEFAULT NULL,
    `status` ENUM('OPEN', 'IN_TRANSIT', 'COMPLETED', 'HIJACKED') NOT NULL DEFAULT 'OPEN',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2.6. Транспорт, недвижимость, банки, телеком и криминалистика

```sql
CREATE TABLE `vehicles` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `model_id` INT UNSIGNED NOT NULL,
    `vin` CHAR(17) NOT NULL,
    `plate` VARCHAR(12) NOT NULL,
    `owner_type` ENUM('CHARACTER', 'ORGANIZATION', 'STATE_FLEET') NOT NULL,
    `owner_id` INT UNSIGNED NOT NULL,
    `fuel_type` ENUM('REGULAR', 'DIESEL', 'JET_FUEL') NOT NULL DEFAULT 'REGULAR',
    `fuel_ml` INT UNSIGNED NOT NULL DEFAULT 50000,
    `max_fuel_ml` INT UNSIGNED NOT NULL DEFAULT 60000,
    `engine_hp` FLOAT NOT NULL DEFAULT 1000.0,
    `body_hp` FLOAT NOT NULL DEFAULT 1000.0,
    `panels_dmg` INT NOT NULL DEFAULT 0,
    `doors_dmg` INT NOT NULL DEFAULT 0,
    `lights_dmg` INT NOT NULL DEFAULT 0,
    `tires_dmg` INT NOT NULL DEFAULT 0,
    `mileage_meters` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `glovebox_storage_id` BIGINT UNSIGNED NOT NULL,
    `trunk_storage_id` BIGINT UNSIGNED NOT NULL,
    `color1` SMALLINT NOT NULL DEFAULT 1,
    `color2` SMALLINT NOT NULL DEFAULT 1,
    `pos_x` FLOAT NOT NULL,
    `pos_y` FLOAT NOT NULL,
    `pos_z` FLOAT NOT NULL,
    `pos_a` FLOAT NOT NULL,
    `garage_property_id` INT UNSIGNED DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_veh_vin` (`vin`),
    CONSTRAINT `fk_veh_glovebox` FOREIGN KEY (`glovebox_storage_id`) REFERENCES `storages` (`id`),
    CONSTRAINT `fk_veh_trunk` FOREIGN KEY (`trunk_storage_id`) REFERENCES `storages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `properties` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `prop_type` ENUM('TRAILER', 'APARTMENT', 'HOUSE', 'MANSION', 'COMMERCIAL', 'WAREHOUSE', 'GARAGE') NOT NULL,
    `ownership` ENUM('STATE_FOR_SALE', 'STATE_FOR_RENT', 'PRIVATE') NOT NULL DEFAULT 'STATE_FOR_SALE',
    `owner_char_id` INT UNSIGNED DEFAULT NULL,
    `owner_org_id` INT UNSIGNED DEFAULT NULL,
    `purchase_price_usd` BIGINT UNSIGNED NOT NULL,
    `rent_per_day_usd` INT UNSIGNED NOT NULL DEFAULT 0,
    `utility_debt_usd` INT UNSIGNED NOT NULL DEFAULT 0,
    `utilities_active` TINYINT(1) NOT NULL DEFAULT 1,
    `lock_level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `is_locked` TINYINT(1) NOT NULL DEFAULT 1,
    `storage_id` BIGINT UNSIGNED NOT NULL,
    `garage_capacity` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `ext_x` FLOAT NOT NULL,
    `ext_y` FLOAT NOT NULL,
    `ext_z` FLOAT NOT NULL,
    `int_x` FLOAT NOT NULL,
    `int_y` FLOAT NOT NULL,
    `int_z` FLOAT NOT NULL,
    `interior_id` INT NOT NULL DEFAULT 0,
    `virtual_world` INT NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_prop_storage` FOREIGN KEY (`storage_id`) REFERENCES `storages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `bank_accounts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `iban` VARCHAR(20) NOT NULL,
    `owner_char_id` INT UNSIGNED NOT NULL,
    `balance_usd` BIGINT NOT NULL DEFAULT 0,
    `is_frozen` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_bank_iban` (`iban`),
    CONSTRAINT `fk_bank_char` FOREIGN KEY (`owner_char_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `telecom_sims` (
    `phone_number` VARCHAR(12) NOT NULL,
    `sim_item_id` BIGINT UNSIGNED NOT NULL,
    `registered_ssn` CHAR(11) DEFAULT NULL COMMENT 'NULL для одноразовых Burner SIM',
    `is_wiretapped` TINYINT(1) NOT NULL DEFAULT 0,
    `wiretap_org_id` INT UNSIGNED DEFAULT NULL,
    PRIMARY KEY (`phone_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `forensic_evidence` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `evidence_type` ENUM('BULLET_CASING', 'BLOOD_DNA', 'BROKEN_GLASS', 'LOCKPICK_SCRATCH', 'FINGERPRINT') NOT NULL,
    `suspect_char_id` INT UNSIGNED DEFAULT NULL,
    `weapon_serial` BIGINT DEFAULT NULL,
    `pos_x` FLOAT NOT NULL,
    `pos_y` FLOAT NOT NULL,
    `pos_z` FLOAT NOT NULL,
    `interior` INT NOT NULL DEFAULT 0,
    `virtual_world` INT NOT NULL DEFAULT 0,
    `expires_at` DATETIME NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_evidence_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `audit_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `actor_char_id` INT UNSIGNED DEFAULT NULL,
    `action_type` VARCHAR(32) NOT NULL COMMENT 'ITEM_MOVE, CASH_TRANSFER, CRAFT, PORT_EXPORT, ADMIN_CMD',
    `source_entity` VARCHAR(48) NOT NULL,
    `target_entity` VARCHAR(48) NOT NULL,
    `item_def_id` SMALLINT UNSIGNED DEFAULT NULL,
    `amount` BIGINT NOT NULL,
    `details` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_audit_actor` (`actor_char_id`),
    KEY `idx_audit_time` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 3. Детальная архитектура программных модулей

### 3.1. Модуль `mod_storage` и `mod_items` (Универсальная предметизация)
Это центральный модуль сервера. Все карманы, бардачки, багажники, сейфы, заводы, трупы и закопанные в лесу ящики работают через единый пул хранилищ.

* **Структуры данных в памяти (RAM):**
  * `MAX_ACTIVE_STORAGES = 16384` (потоковые хранилища: онлайн-игроки, заспавненные авто, сейфы, дропы).
  * `MAX_STORAGE_ITEMS = 131072` (пул экземпляров предметов с индексированием через `y_iterate`).
  * `bool:gStorageMutex[MAX_ACTIVE_STORAGES]` — флаг блокировки транзакции для защиты от дюпа при одновременном открытии багажника или трупа двумя игроками.

* **Алгоритм рекурсивного расчета массы (`Storage_GetTotalWeight`):**
  Поскольку рюкзаки и сумки являются предметами, содержащими `nested_storage_id`, общая масса рассчитывается рекурсивно с ограничением глубины вложенности `MAX_NESTING_DEPTH = 2`:
  $$W_{\text{storage}}(S) = \sum_{i \in S} \left[ N_i \times W_{\text{base}}(i) + N_{\text{ammo}}(i) \times W_{\text{round}}(i) + W_{\text{nested}}(i) \right]$$
  где $W_{\text{nested}}(i) = W_{\text{storage}}(\text{nested\_id})$ если предмет является контейнером, иначе $0$.

* **Алгоритм перемещения предмета (`Storage_TransferItem`):**
  1. Проверка валидности `src_storage` и `dst_storage` и физической дистанции игрока до обоих хранилищ ($\le 3.5\text{ м}$).
  2. Проверка `gStorageMutex[src]` и `gStorageMutex[dst]`. Если хотя бы один занят — отказ (`"Хранилище сейчас используется другим игроком"`).
  3. Захват мьютексов: `gStorageMutex[src] = true; gStorageMutex[dst] = true;`.
  4. Если `dst_storage` имеет тип `PLAYER_LAYER2`, проверка `ItemDef[item_id][can_layer2] == true`.
  5. Проверка лимитов массы и объема `dst_storage`:
     $$W_{\text{current}}(\text{dst}) + W_{\text{transfer}} \le W_{\text{max}}(\text{dst}), \quad V_{\text{current}}(\text{dst}) + V_{\text{transfer}} \le V_{\text{max}}(\text{dst})$$
  6. Обновление состояния в RAM, запись в `audit_logs`, отправка атомарного пакета SQL-запросов (`START TRANSACTION; UPDATE/DELETE/INSERT storage_items; COMMIT;`).
  7. Освобождение мьютексов.

### 3.2. Модуль `mod_weapons` (Оружие без отдельных патронов)
* **Логика интеграции с GTA SA / open.mp:**
  * В базе данных и инвентаре **не существует** предметов «патроны». Оружие хранится как экземпляр `item_def_id` (например, `M4`) с полем `ammo_count = 200`.
  * Масса предмета динамическая: $W = 3400 + (200 \times 12) = 5800\text{ г}$ ($5.8\text{ кг}$).
  * При экипировке ствола из Слоя 1 в слот рук сервер вызывает `GivePlayerWeapon(playerid, gta_weapon_id, ammo_count)` и фиксирует серверный счетчик `gPlayerSlotAmmo[playerid][slot] = ammo_count`.
  * **Синхронизация выстрелов (`OnPlayerWeaponShot`):** Каждый выстрел декрементирует `gPlayerSlotAmmo` и уменьшает `durability` ствола на $0.05\% \times (1 - \text{Skill}_{\text{weapon}}/2000)$. Если `durability < 30.0`, с вероятностью $(30.0 - \text{durability}) \times 0.8\%$ происходит **заклинивание** (`TogglePlayerControllable` на 1.5 сек + `/me` отыгровка).
  * **Команды `/unload` и `/combine`:** Позволяют пересыпать патроны между двумя одинаковыми стволами с мгновенным перерасчетом массы обоих предметов.

### 3.3. Модуль `mod_survival` и `mod_roles` (25 ролей, прогрессия и перегруз)
* **Формула возраста и уровня:** $\text{Age} = 17 + \text{Level}$. Повышение уровня происходит каждые 10 часов чистого игрового времени.
* **Расчет максимальной грузоподъемности ($W_{\text{max}}$ в граммах):**
  $$W_{\text{max}} = 25000 + (\text{Skill}_{\text{MUSCLE}} \times 35) + \Delta_{\text{role}}$$
  (Например, при `MUSCLE = 1000` лимит составляет $60\text{ кг}$, а для роли «Качок-Вышибала» $\Delta_{\text{role}} = +25000\text{ г} \Rightarrow 85\text{ кг}$).
* **Штрафы за перегруз (Encumbrance):**
  Коэффициент нагрузки $R = \frac{W_{\text{layer1}}}{W_{\text{max}}}$. Если $R > 1.0$:
  * Блокируется спринт (перехват клавиши `KEY_SPRINT` в `OnPlayerKeyStateChange` с анимацией усталости).
  * Расход голода и жажды умножается на коэффициент $K_{\text{drain}} = 1.0 + 1.5 \times (R - 1.0)$.
  * Увеличивается разброс при стрельбе.
* **Движок 25 стартовых ролей (`mod_roles`):**
  Конфигурация всех 25 ролей хранится в константном массиве `gRoleConfigs[25][E_ROLE_TEMPLATE]`, определяющем: `citizenship`, `start_cash_usd`, `start_bank_usd`, `start_debt_usd`, `start_wanted`, `spawn_xyz`, массив стартовых навыков, массив стартовых предметов и битовую маску перков (`PERK_NO_POISON`, `PERK_DOUBLE_LAYER2`, `PERK_NO_BIKE_FALL`, `PERK_COP_SENSE` и др.).

### 3.4. Модуль `mod_medical` (Травмы, кровотечения, PK и CK)
* **Обработка входящего урона (`OnPlayerTakeDamage`):**
  Сервер определяет `bodypart` (`3=Torso, 4=Groin, 5=LeftArm, 6=RightArm, 7=LeftLeg, 8=RightLeg, 9=Head`):
  * **Голова (`9`):** Множник урона $\times 3.5$. Если без шлема — мгновенный летальный исход или критический нокаут.
  * **Конечности (`5..8`):** При падении здоровья конечности ниже $30\%$ накладывается перелом (`fracture_flags`): для ног — блокировка прыжков и бега; для рук — принудительное выпадение оружия из рук на землю (`WORLD_DROP`).
  * **Кровотечения:** Урон на $> 25\text{ HP}$ одним выстрелом вызывает венозное кровотечение ($-1\text{ HP}$ каждые 5 сек, останавливается `Bandage`). Урон на $> 55\text{ HP}$ вызывает артериальное кровотечение ($-3\text{ HP}$ каждые 2 сек, требует наложения жгута `Tourniquet` в течение 90 сек, иначе смерть).
* **Мгновенная смерть тела (Instant Death / PK):**
  При падении общего `HP <= 0.0`:
  1. В точке смерти $(X, Y, Z)$ создается новое хранилище типа `CORPSE_LOOT` с привязанным актором/объектом трупа и 3D-текстом (TTL = 20 минут).
  2. Все предметы из `PLAYER_LAYER1` игрока мгновенно переносятся в `CORPSE_LOOT`.
  3. Предметы из `PLAYER_LAYER2` (паспорт, карты, телефон, надетая одежда) **остаются** у игрока, а сам игрок отправляется на респавн в больницу.
* **Перманентная смерть (CK):** Выполняется администратором/судьей/агентом ЦРУ с соответствующим флагом: устанавливает `is_ck_dead = 1`, блокирует выбор персонажа на экране входа.

### 3.5. Модуль `mod_economy`, `mod_ports` и `mod_logistics` (Zero-Faucet цикл)
* **Принцип отсутствия «кранов»:** Ни один доллар или килограмм ресурса не генерируется из воздуха (кроме начального `Seed Money` в казне правительства штата).
* **Динамическое ценообразование в портах (`mod_ports`):**
  Каждую минуту сервис пересчитывает цены для каждого товара $i$ в портах LS, SF и LV в зависимости от текущего запаса $Q_{\text{curr}}$ и целевого запаса $Q_{\text{target}}$:
  $$P_{\text{mid}}(i) = P_{\text{ref}}(i) \times \text{clamp}\left(\frac{Q_{\text{target}}(i)}{Q_{\text{curr}}(i) + 1}, \; 0.35, \; 3.00\right)$$
  Цена импорта (покупки игроком в порту) и экспорта (продажи игроком в порт) со спредом $\delta = 0.12$:
  $$P_{\text{buy}} = \lceil P_{\text{mid}} \times (1 + \delta) \rceil, \quad P_{\text{sell}} = \lfloor P_{\text{mid}} \times (1 - \delta) \rfloor$$
* **Формула распределения экспортной выручки (`90 / 5 / 5`):**
  При сдаче партии товара общей стоимостью $V_{\text{total}} = N \times P_{\text{sell}}$ в порт:
  * **Владельцу предприятия / Госбюджету:** $V_{\text{owner}} = \lfloor V_{\text{total}} \times 0.90 \rfloor$
  * **Дальнобойщику (оплата логистики):** $V_{\text{trucker}} = \lfloor V_{\text{total}} \times 0.05 \rfloor$ (для роли *Король Трассы* действует бонус $+20\%$, выплачиваемый из резерва заказчика).
  * **Государственная экспортная пошлина в казну штата:** $V_{\text{tax}} = V_{\text{total}} - V_{\text{owner}} - V_{\text{trucker}}$ ($\approx 5\%$).

### 3.6. Модуль `mod_organizations` и `mod_justice` (Фракции, 100-уровневый розыск и криминалистика)
* **Единый движок организаций:**
  Любая структура (от уличной группировки до ФБР, ЦРУ или Частной военной компании) описывается одной записью в `organizations`. Поведение определяется через `legal_status` и битовую маску `charter_flags`:
  * `FLAG_CAN_BANK` (0x01) — право иметь безналичный счет.
  * `FLAG_LEGAL_HEAVY_WEAPONS` (0x02) — разрешение на штурмовое вооружение (Госструктуры + ЧВК по госконтракту).
  * `FLAG_ISSUE_WARRANTS` (0x04) — право выдавать судебные ордера и обыскивать Слой 2.
  * `FLAG_WIRETAP` (0x08) — право прослушивать звонки, SMS и сканировать радиочастоты (ФБР/ЦРУ).
  * `FLAG_BORDER_CONTROL` (0x10) — право проверять SSN и багажники на КПП (ICE/Полиция).
  * `FLAG_EXTRALEGAL_OPS` (0x20) — санкционированные операции вне внутреннего законодательства (ЦРУ).
* **100-уровневая система розыска и Warrant Decay:**
  * Диапазон: `0..100`. При аресте срок заключения равен $\text{WantedLevel} \times 3600\text{ секунд}$ (1 уровень = 1 реальный час онлайна), который можно сократить работой на тюремной шахте/лесопилке.
  * **Warrant Decay:** В таймере `Tick_Second` проверяется, не находится ли игрок в AFK (`GetTickCount() - gLastPlayerPacketTick[playerid] < 15000`). Если игрок активен, инкрементируется `active_play_seconds`. Когда `active_play_seconds >= 3600` и `wanted_level > 0`, счетчик сбрасывается в `0`, а `wanted_level` уменьшается на `1`.
* **Физические улики (`mod_forensics`):**
  * Выстрел без глушителя создает запись `BULLET_CASING` в точке стрелка с привязкой к `weapon_serial` (TTL = 45 мин).
  * Разбитие стекла авто (`/breakwindow`) создает `BROKEN_GLASS` и `BLOOD_DNA` (если игрок без перчаток) в точке авто (TTL = 30 мин).
  * Неудачный `/lockpick` создает `LOCKPICK_SCRATCH` на двери/замке (TTL = 30 мин).
  * Игроки с навыком `FORENSICS >= 300` и предметом `Forensics Kit` (или ролью *Отставной Коп*) видят 3D-маркеры улик и могут собрать их в пакет для судебной экспертизы.

---

## 4. Критические игровые пайплайны (Потоки данных)

### 4.1. Пайплайн подключения и создания персонажа (25 ролей)

```text
[Client Connect]
       │
       ▼
[mod_account]: Проверка IP/HWID банов -> Асинхронный SELECT из `accounts`
       │
       ├──► (Аккаунт существует) ──► Диалог пароля ──► bcrypt_verify() ──► Выбор персонажа
       │
       └──► (Новый аккаунт) ──► Регистрация ──► Мастер создания персонажа:
                                                1. Ввод RP-имени (Regex: ^[A-Z][a-z]+_[A-Z][a-z]+$)
                                                2. Выбор пола, расы, базового скина
                                                3. Выбор одной из 25 ролей (`mod_roles`)
                                                       │
                                                       ▼
                                          [Атомарная SQL-транзакція / транзакция]:
                                          - INSERT `storages` (Layer 1 & Layer 2)
                                          - INSERT `characters` (Age=18, Level=1, Citizenship)
                                          - INSERT `character_skills` (шаблон роли)
                                          - INSERT `character_injuries` (100% HP)
                                          - INSERT `storage_items` (стартовый лут роли)
                                          - INSERT `bank_accounts` (если CITIZEN)
                                                       │
                                                       ▼
                                          [Spawn на лор-точке роли]
```

### 4.2. Поток транзакции отмывания денег (Money Laundering Pipeline)
1. Криминальный игрок имеет в `PLAYER_LAYER1` пачки нелегальной наличности (`item_def_id = 73`, `meta_int2 = 1 [USD]`, `meta_int1 = 1 [DIRTY_FLAG]`).
2. Игрок передает грязную наличность владельцу легального бизнеса (автомойка, бар, АЗС, казино) или вносит в кассу своего предприятия.
3. Владелец бизнеса запускает операцию легализации через кассовый аппарат предприятия (`ENTERPRISE_WAREHOUSE` $\rightarrow$ `bank_accounts`).
4. Система удерживает налог на прибыль ($15\% - 25\%$), переводит остаток на безналичный счет `bank_accounts` и создает запись в `audit_logs` с коэффициентом подозрительности (если дневной оборот бизнеса превышает средний по штату в 3 раза, ФБР/Минфин получает автоматическое уведомление о финансовой аномалии).

---

## 5. Текстовый интерфейс (Text-First UI) и стандарты команд

Интерфейс построен по принципу минимализма, скорости и **100% русскоязычной локализации**:

1. **Язык и кодировка UI:**
   * Все тексты, отображаемые игроку (заголовки и строки диалогов `ShowPlayerDialog`, кнопки `Выбрать`/`Закрыть`, сообщения `SendClientMessage`, `GameText`, `3DTextLabel`, названия предметов `display_name` и названия ролей), пишутся **исключительно на русском языке** без англицизмов там, где есть нормальный русский термин (например: *«Багажник»*, а не *«Trunk»*; *«Штурмовая винтовка M4»*, а не *«M4»*).
   * Все `.pwn` исходники с кириллицей сохраняются в кодировке **`Windows-1251` (`CP1251`)**, а в `mod_database.pwn` при старте вызывается `mysql_set_charset(gMySQL, "cp1251")` для корректного обмена кириллицей между сервером open.mp и MySQL.
2. **Контекстная клавиша взаимодействия (`KEY_YES` / `Y` или `KEY_WALK` / `LALT`):**
   Сканирует радиус $2.5\text{ м}$ вокруг игрока (открытый багажник, труп, выброшенный предмет, верстак, вход в здание, капот авто) и открывает единое контекстное диалоговое окно `DIALOG_STYLE_TABLIST_HEADERS`.
3. **Ключевые консольные команды (`Pawn.CMD`):**
   * `/inv` (`/i`) — открытие двухслойного инвентаря (Слой 1 + Слой 2) в табличном диалоге с отображением текущей массы ($\text{кг}$) и объема ($\text{л}$).
   * `/trunk` / `/glovebox` — прямой доступ к хранилищам транспорта.
   * `/frisk [id]` / `/search [id]` — обыск игрока (раскрывает Слой 1; при наличии наручников или ордера раскрывает также Слой 2).
   * `/lockpick` / `/hotwire` — мини-игра в текстовом диалоге/таймере на взлом замков и скрутку проводов зажигания (результат зависит от навыков `LOCKPICKING` / `HOTWIRING` и износа отмычек).
   * `/triage [id]` / `/treat [id]` — медицинский осмотр травм по зонам тела и применение бинтов, жгутов, морфина или хирургического набора.
   * `/org` — панель управления организацией (иерархия, настройка битовой маски прав RBAC, аудит сейфа, частота рации).
   * `/me`, `/do`, `/try`, `/todo` — ролевые команды с системной валидацией действий.

---

## 6. Безопасность, Античит и Эксплуатация (DevOps)

### 6.1. Многоуровневый античит (`mod_anticheat` + `Pawn.RakNet`)
* **Защита оружия и патронов:** Любое оружие, появившееся в слотах игрока на клиенте, но отсутствующее в серверном массиве `gPlayerEquippedWeapon[playerid]`, мгновенно блокируется через пакет `RPC_GivePlayerWeapon` / `OnPlayerUpdate`, а событие логируется в `audit_logs`.
* **Защита координат и скорости:** Проверка дельты перемещения игрока за тик (`250 ms`) с учетом состояния в авто, падения с парашютом или телепорта сервером (`gPlayerExpectedTeleport[playerid]`).
* **Серверный контроль здоровья и брони:** Клиентское значение HP/Armour игнорируется; урон рассчитывается исключительно сервером в `OnPlayerTakeDamage` и принудительно синхронизируется через `SetPlayerHealth` / `SetPlayerArmour`.

### 6.2. Стратегия сохранения данных и резервного копирования
* **Dirty-Flag Pattern:** Каждая сущность в памяти (`Character`, `Vehicle`, `Enterprise`, `Storage`) имеет булев флаг `is_dirty`. Ежеминутный тик сохраняет в БД **только** те сущности, у которых `is_dirty == true`, распределяя запросы равномерно по кадрам, чтобы избежать фризов.
* **Критические операции:** Перемещение предметов между хранилищами, покупка/продажа имущества, банковские переводы и изменение состава организации сохраняются в БД **мгновенно** в рамках SQL-транзакции.
* **Резервное копирование на Linux:** Cron-скрипт каждые 6 часов выполняет `mysqldump --single-transaction --quick` с ротацией архивов за последние 14 суток.
# SAN ANDREAS RP — Technical Architecture & System Specification (`TECH_CONTEXT.MD`)

**Версия документа:** 1.1.0  
**Платформа:** open.mp Server v1.6.7+ (Linux x86/x64 Native)  
**Основной язык разработки:** Pawn (`qawno` compiler с оптимизацией `-O2 -d1`) + C++ Components SDK  
**Язык пользовательского интерфейса:** Английский (`Windows-1251 / CP1251` для клиентских строк Pawn; игроки могут свободно общаться в чатах на любом языке)  
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
        │   ├── mod_telecom.pwn
        │   └── mod_admin.pwn       # RBAC-ядро, роли, наказания и аудит админ-действий
        └── ui/                 # Текстовый интерфейс (Text-First, 100% English UI)
            ├── mod_dialogs.pwn
            ├── mod_commands.pwn
            ├── mod_hud.pwn
            └── mod_admin_panel.pwn # /apanel, /ahelp, /sp-HUD и многоуровневые диалоги
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
    `admin_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'LEGACY: устаревший уровень, не используется для проверки доступа',
    `admin_role_id` INT UNSIGNED DEFAULT NULL COMMENT 'Активная админ-роль; NULL = нет прав. Логический FK на admin_roles.id',
    `is_banned` TINYINT(1) NOT NULL DEFAULT 0,
    `ban_reason` VARCHAR(255) DEFAULT NULL,
    `ban_expires_at` DATETIME DEFAULT NULL,
    `reg_ip` VARCHAR(45) NOT NULL,
    `last_ip` VARCHAR(45) NOT NULL,
    `last_hwid` VARCHAR(64) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_login_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_accounts_username` (`username`),
    KEY `idx_accounts_admin_role` (`admin_role_id`)
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
    `display_name` VARCHAR(64) NOT NULL COMMENT 'Английское название предмета для UI',
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
    `admin_account_id` INT UNSIGNED DEFAULT NULL COMMENT 'ID админ-аккаунта (для ADMIN_* действий)',
    `target_account_id` INT UNSIGNED DEFAULT NULL COMMENT 'ID аккаунта-цели',
    `target_char_id` INT UNSIGNED DEFAULT NULL COMMENT 'ID персонажа-цели',
    `action_type` VARCHAR(32) NOT NULL COMMENT 'ITEM_MOVE, CASH_TRANSFER, CRAFT, PORT_EXPORT, ADMIN_CMD, ADMIN_BAN, ADMIN_GIVE_ITEM, ADMIN_ROLE_CHANGE',
    `source_entity` VARCHAR(48) NOT NULL,
    `target_entity` VARCHAR(48) NOT NULL,
    `item_def_id` SMALLINT UNSIGNED DEFAULT NULL,
    `amount` BIGINT NOT NULL,
    `details` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_audit_actor` (`actor_char_id`),
    KEY `idx_audit_admin` (`admin_account_id`),
    KEY `idx_audit_target` (`target_account_id`, `target_char_id`),
    KEY `idx_audit_time` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2.7. Динамическая административная система, RBAC-ранги и наказания (Фаза 10)

Базовый набор из 22 таблиц сохраняется; миграция `sql/003_admin_rbac.sql` (Фаза 10) дополняет `accounts` (колонка `admin_role_id`) и `audit_logs` (поля администратора и цели) обратно совместимыми колонками и добавляет административный контур: `admin_roles`, `admin_role_permissions` и `admin_punishments`. Поле `accounts.admin_level` остается только как legacy-совместимость и **не участвует** в проверках доступа.

```sql
-- Динамические административные роли. По умолчанию создается только Root (level = 100, is_root = 1)
CREATE TABLE `admin_roles` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(48) NOT NULL COMMENT 'Английское название ранга для UI',
    `level` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1..99 для кастомных ролей; 100 для Root. Только сортировка/отображение',
    `is_root` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = Root-администратор, полный обход RBAC',
    `is_system` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = системная роль, запрещено удалять',
    `permissions_mask` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Битовая маска быстрых разрешений',
    `chat_color_hex` CHAR(6) NOT NULL DEFAULT 'FFFFFF' COMMENT 'Цвет ника в админ-чате',
    `created_by_account_id` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_admin_roles_name` (`name`),
    KEY `idx_admin_roles_root` (`is_root`),
    CONSTRAINT `fk_admin_roles_creator` FOREIGN KEY (`created_by_account_id`) REFERENCES `accounts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Строковые (гранулярные) разрешения роли: одна запись = один permission_key
CREATE TABLE `admin_role_permissions` (
    `role_id` INT UNSIGNED NOT NULL,
    `permission_key` VARCHAR(48) NOT NULL COMMENT 'ADMIN_PANEL_ACCESS, MANAGE_ADMINS, PLAYER_BAN, INV_GIVE_ITEM, ...',
    `is_allowed` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1 = разрешено, 0 = явный запрет',
    PRIMARY KEY (`role_id`, `permission_key`),
    CONSTRAINT `fk_admin_perm_role` FOREIGN KEY (`role_id`) REFERENCES `admin_roles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Журнал административных наказаний (мут, варн, деморган, временный/постоянный бан)
CREATE TABLE `admin_punishments` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `target_account_id` INT UNSIGNED NOT NULL,
    `target_char_id` INT UNSIGNED DEFAULT NULL,
    `admin_account_id` INT UNSIGNED DEFAULT NULL,
    `punishment_type` ENUM('MUTE', 'WARN', 'DEMORGAN', 'BAN_TEMP', 'BAN_PERM') NOT NULL,
    `reason` VARCHAR(255) NOT NULL,
    `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` DATETIME DEFAULT NULL COMMENT 'NULL для перманентных наказаний',
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `revoked_by_account_id` INT UNSIGNED DEFAULT NULL,
    `revoked_at` DATETIME DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_punish_target` (`target_account_id`, `is_active`),
    KEY `idx_punish_expires` (`expires_at`),
    CONSTRAINT `fk_punish_target` FOREIGN KEY (`target_account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_punish_admin` FOREIGN KEY (`admin_account_id`) REFERENCES `accounts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

> **Важно:** `accounts.admin_role_id` ссылается на `admin_roles.id` логически (без `FOREIGN KEY`), чтобы избежать циклической зависимости при создании таблиц. Целостность обеспечивается серверным API `Admin_AssignRole` и проверкой существования роли перед `UPDATE accounts SET admin_role_id = ...`.

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

### 3.1.1. Гардероб персонажа и комплекты одежды
* **Предмет одежды:** `ITEM_ID_CLOTHING_OUTFIT` (ID 91). В `meta_int1` хранится ID модели скина (`1..311`, кроме `74`), в `meta_int2` — состояние: `CLOTHING_STATE_BAG = 0` («В сумке») или `CLOTHING_STATE_EQUIPPED = 1` («Надето»).
* **Единственный активный комплект:** в инвентаре персонажа может находиться произвольное количество комплектов одежды, но флаг `CLOTHING_STATE_EQUIPPED` разрешен ровно у одного. При надевании нового комплекта предыдущий автоматически переводится в `CLOTHING_STATE_BAG`.
* **Зеркало скина:** `characters.skin_id` всегда отражает модель надетого комплекта. Если надетой одежды нет, сервер применяет базовый скин нижнего белья по полу персонажа (`252` — мужской, `140` — женский).
* **Потеря надетого комплекта:** при выбросе (`WORLD_DROP`), передаче другому игроку, изъятии при обыске или удалении предмета модуль `mod_storage` вызывает `OnStorageLostEquippedClothing`. Модуль персонажа сверяет `storage_items.id` с `E_CHAR_EQUIPPED_OUTFIT_DB_ID`, мгновенно снимает одежду, применяет скин нижнего белья и сохраняет его в БД.
* **Порядок асинхронной загрузки:** слоты Слоя 1 и Слоя 2 создаются в RAM синхронно (`Storage_Load`), после чего из MySQL последовательно загружаются заголовок и предметы. До завершения загрузки (`E_CHAR_INVENTORY_PENDING_LOADS > 0`) модуль персонажа не перезаписывает `skin_id`, чтобы запоздавший ответ БД не затёр надетый скин.
* **Респавн:** `OnPlayerSpawn` вызывает `Character_SyncInventorySkin`, поэтому после смерти и повторного появления применяется актуальный надетый скин, а не стартовый скин класса.

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

### 3.7. Модули `mod_admin` и `mod_admin_panel` (динамический RBAC и админ-панель, Фаза 10)
Административный контур разделен на два модуля: **`systems/mod_admin.pwn`** (серверное RBAC-ядро, хранение ролей, проверка прав, наказания и аудит) и **`ui/mod_admin_panel.pwn`** (многоуровневые диалоги `/apanel`, `/ahelp`, HUD-панель `/sp`). UI-модуль не имеет права самостоятельно изменять состояние мира — он только собирает параметры и вызывает публичный API `Admin_*`.

* **Структуры данных в RAM:**
  * `MAX_ADMIN_ROLES = 64`; `MAX_ADMIN_PERMISSIONS = 64`.
  * `static stock sAdminRoles[MAX_ADMIN_ROLES][E_ADMIN_ROLE];`
  * `static stock sAdminRolePerms[MAX_ADMIN_ROLES][MAX_ADMIN_PERMISSIONS];` (кэш «role_id → permission_key → bool»).
  * `static stock sPlayerAdminRole[MAX_PLAYERS];` (индекс роли в пуле, `-1` = нет прав).
  * `static stock sPlayerAdminPermCache[MAX_PLAYERS][MAX_ADMIN_PERMISSIONS];` (пересчитывается при входе, смене роли и `/apanel`).
  * `static stock sPlayerSpectateTarget[MAX_PLAYERS];`, `sPlayerApanelPage[MAX_PLAYERS];`, `sPlayerAdminDialogMap[MAX_PLAYERS][MAX_APANEL_ITEMS];` — состояние UI и защита от подмены `listitem`.
  * `permissions_mask` (`BIGINT UNSIGNED`) не помещается в 32-битную ячейку Pawn: читать его через `cache_get_value_name` в строку или двумя 32-битными половинами. Источником истины остаются строковые `admin_role_permissions`; маска служит только быстрым кэшем.

* **Перечисление разрешений (`E_ADMIN_PERM`):** `ADMIN_PERM_PANEL_ACCESS`, `ADMIN_PERM_HELP_ACCESS`, `ADMIN_PERM_MANAGE_ADMINS`, `ADMIN_PERM_MANAGE_ROLES`, `ADMIN_PERM_VIEW_AUDIT`, `ADMIN_PERM_VIEW_ANTICHEAT`, `ADMIN_PERM_PLAYER_TELEPORT`, `ADMIN_PERM_PLAYER_GET_HERE`, `ADMIN_PERM_PLAYER_SPECTATE`, `ADMIN_PERM_PLAYER_FREEZE`, `ADMIN_PERM_PLAYER_SLAP`, `ADMIN_PERM_PLAYER_SET_STATS`, `ADMIN_PERM_PLAYER_SET_SKIN`, `ADMIN_PERM_PLAYER_KICK`, `ADMIN_PERM_PLAYER_BAN`, `ADMIN_PERM_PLAYER_UNBAN`, `ADMIN_PERM_PLAYER_MUTE`, `ADMIN_PERM_PLAYER_WARN`, `ADMIN_PERM_PLAYER_JAIL`, `ADMIN_PERM_PLAYER_SET_WANTED`, `ADMIN_PERM_ORG_SET_LEADER`, `ADMIN_PERM_ORG_SET_MEMBER`, `ADMIN_PERM_ORG_MANAGE_RANKS`, `ADMIN_PERM_CHAR_SET_LEVEL`, `ADMIN_PERM_CHAR_SET_EXP`, `ADMIN_PERM_CHAR_SET_SKILLS`, `ADMIN_PERM_CHAR_SET_LICENSES`, `ADMIN_PERM_CHAR_SET_STATUS`, `ADMIN_PERM_ECON_GIVE_CASH`, `ADMIN_PERM_ECON_SET_BANK`, `ADMIN_PERM_ECON_CLEAR_DEBT`, `ADMIN_PERM_ECON_ISSUE_DEBT`, `ADMIN_PERM_INV_VIEW`, `ADMIN_PERM_INV_GIVE_ITEM`, `ADMIN_PERM_INV_EDIT_ITEM`, `ADMIN_PERM_INV_CLEAR`, `ADMIN_PERM_PROP_GIVE`, `ADMIN_PERM_PROP_REMOVE`, `ADMIN_PERM_VEH_SPAWN`, `ADMIN_PERM_VEH_DELETE`, `ADMIN_PERM_VEH_KEYS`, `ADMIN_PERM_VEH_REFUEL`, `ADMIN_PERM_VEH_REPAIR`, `ADMIN_PERM_VEH_TELEPORT`, `ADMIN_PERM_WORLD_TELEPORT`, `ADMIN_PERM_WORLD_WEATHER`, `ADMIN_PERM_WORLD_TIME`, `ADMIN_PERM_WORLD_ANNOUNCE`, `ADMIN_PERM_SERVER_SAVE`, `ADMIN_PERM_SERVER_RESTART`.

* **Публичный API RBAC:**
  * `Admin_LoadRoles()` — блокирующая загрузка `admin_roles` и `admin_role_permissions` в RAM **только** в `OnGameModeInit`.
  * `Admin_IsRoot(playerid)` — `true`, если у аккаунта `admin_roles.is_root = 1`.
  * `Admin_HasPermission(playerid, E_ADMIN_PERM:perm)` — единственная точка проверки; сначала `Admin_IsRoot`, затем кэш роли.
  * `Admin_GetRoleName(playerid, dest[], size)`, `Admin_GetRoleLevel(playerid)` — только для отображения и сортировки, не для доступа.
  * `Admin_AssignRole(admin_playerid, target_account_id, role_id)`, `Admin_RemoveRole(admin_playerid, target_account_id)` — смены состава с проверкой `MANAGE_ADMINS`.
  * `Admin_CreateRole(admin_playerid, name[], level)`, `Admin_DeleteRole(admin_playerid, role_id)`, `Admin_SetRolePermission(admin_playerid, role_id, permission_key[], bool:allowed)` — управление ролями с проверкой `MANAGE_ROLES`; Root-роль и `is_system = 1` удалить нельзя.
  * `Admin_Punish(admin_playerid, target_account_id, E_PUNISHMENT:type, reason[], duration_sec)` — мут, варн, деморган, временный/постоянный бан; пишет `admin_punishments` и `audit_logs`.
  * `Admin_Audit(admin_playerid, target_id, action_type[], details[])` — единая обертка над `Audit_Log`, заполняющая `admin_account_id`, `target_account_id`, `target_char_id`, тип и параметры действия.

* **Пайплайн выполнения админ-команды (обязательный):**
  1. Проверить `IsPlayerConnected` и активную сессию администратора; проверить, что администратор не в наручниках/не в тюрьме, если действие этого требует.
  2. Вызвать `Admin_HasPermission(playerid, perm)`; при отказе — сообщение на английском и запись `ADMIN_DENIED` в `audit_logs` (без выполнения действия).
  3. Провалидировать цель: существование `target_account_id`/`char_id`, диапазоны сумм, количеств, `item_def_id` (0..91+), координат и интервалов времени.
  4. Выполнить действие через публичный API соответствующего модуля (`Storage_GiveItem`, `Char_ModifyWantedLevel`, `Org_SetRank`, `Vehicle_SpawnTemporary`, `Survival_SetHunger` и т.д.), не дублируя его внутреннюю логику.
  5. Вызвать `Admin_Audit(...)` с точными параметрами (до/после) и отправить подтверждение администратору.
  6. Для оффлайн-целей — выполнить асинхронный `UPDATE`/`INSERT` с проверкой `gPlayerSessionToken` и факта, что аккаунт не перешел другому игроку.

* **Root-роль и первичная инициализация:** `sql/003_admin_rbac.sql` создает единственную запись `admin_roles (name = 'Root Administrator', level = 100, is_root = 1, is_system = 1, permissions_mask = 0xFFFFFFFFFFFFFFFF)`. Для Root `Admin_HasPermission` всегда возвращает `true`, поэтому отдельные строки в `admin_role_permissions` не требуются. Кастомные роли создаются только через `Admin_CreateRole` и по умолчанию не имеют ни одного права.

* **Наказания и баны:** мут/варн/деморган хранятся в `admin_punishments`; временный и перманентный бан дополнительно выставляют `accounts.is_banned`, `ban_reason`, `ban_expires_at`. Оффлайн-бан по нику/IP/HWID выполняется асинхронно и обязательно логируется. Разбан снимает `is_banned = 0`, обнуляет `ban_expires_at` и помечает запись `admin_punishments` как `is_active = 0`.

* **Слежка `/sp`:** сервер запоминает `sPlayerSpectateTarget[playerid]`, переключает камеру (`TogglePlayerSpectating` / `PlayerSpectatePlayer`) и раз в `Tick_Fast` обновляет HUD-панель: имя, ID, HP, броня, пинг, текущий транспорт, координаты, интерьер и виртуальный мир. Кнопки действий в HUD вызывают те же RBAC-проверенные команды, что и `/apanel`. Выход из слежки восстанавливает камеру и состояние игрока.

* **Инварианты:** ни один админ-модуль не читает и не пишет `accounts.admin_level` для проверки доступа; UI-строки — только английский язык в `Windows-1251`; все привилегированные операции — только через `Admin_HasPermission` + `Admin_Audit`.

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

## 5. Текстовый интерфейс (Text-First UI), архитектура Command-First и стандарты команд (Фаза 12)

Интерфейс построен по принципу минимализма, скорости, **100% англоязычной локализации (English UI)** и полной доступности для игроков с ПК и мобильных клиентов (`Command-First & Keybind-Wrapper`):

1. **Язык и кодировка UI:**
   * Все тексты, отображаемые игроку (заголовки и строки диалогов `ShowPlayerDialog`, кнопки `Select`/`Close`, сообщения `SendClientMessage`, `GameText`, `3DTextLabel`, названия предметов `display_name`, названия ролей, рангов и фракций, интерфейс `/mm`, `/help`, `/apanel` и `/ahelp`), пишутся **исключительно на грамотном, естественном RP-английском языке** (например: *«Trunk»*, *«M4 assault rifle»*).
   * **Официальный рабочий язык** государственных организаций, правительства, судов, полиции, армии, СМИ и всех правовых процедур — **английский язык**.
   * **Свобода общения в RP:** игрокам разрешено свободно общаться в IC/OOC-чатах на любом другом языке по собственному желанию; искусственные скриптовые запреты, мут-фильтры и автобаны за использование иных языков недопустимы.
   * Все `.pwn` исходники с кириллицей (комментарии, сообщения игроков) сохраняются в кодировке **`Windows-1251` (`CP1251`)**, а в `mod_database.pwn` при старте вызывается `mysql_set_charset("cp1251", gMySQL)` для корректного обмена английским интерфейсом и кириллицей между сервером open.mp и MySQL.

2. **Архитектурный паттерн `Command-First & Keybind-Wrapper` (`ui/mod_dialogs.pwn`, `ui/mod_commands.pwn`, `ui/mod_main_menu.pwn`):**
   * Ни одна игровая механика не привязана эксклюзивно к аппаратной клавише. Каждое действие имеет собственную консольную команду `CMD:` (`Pawn.CMD`) и короткие алиасы для комфортного ввода с мобильных клиентов (Android/iOS).
   * Перехватчик `OnPlayerKeyStateChange` в `ui/mod_dialogs.pwn` не содержит бизнес-логики, а выступает тонкой оберткой с антифлуд-кулдауном (`KEYBIND_INTERACT_COOLDOWN_MS = 350 ms`):
     * **`KEY_YES` (`Y`)** $\rightarrow$ вызывает `pc_cmd_act` (`/act`, `/interact`) — контекстный сканер окружения и игроков в радиусе $3.0\text{ м}$.
     * **`KEY_NO` (`N`)** $\rightarrow$ вызывает `pc_cmd_inv` (`/inv`, `/i`) — двухслойный инвентарь (`Layer 1` + `Layer 2`).
     * **`KEY_CTRL_BACK` (`H`) / `KEY_WALK` (`LALT` пешком)** $\rightarrow$ вызывает `pc_cmd_mm` (`/mm`, `/menu`) — главное меню персонажа и навигации (с учетом аппаратного ограничения GTA SA / `open.mp`, где стандартный `OnPlayerKeyStateChange` не передает произвольную клавишу `M`).

3. **Контекстный сканер окружения `/act` (`Dialogs_OpenActMenu` в `ui/mod_dialogs.pwn`):**
   * Сканирует радиус $3.0\text{ м}$ вокруг игрока и динамически формирует окно `DIALOG_STYLE_TABLIST_HEADERS` с серверным маппингом каждой строки в `sPlayerActTypeMap[MAX_PLAYERS][MAX_ACT_MENU_ROWS]` и `sPlayerActTargetMap[MAX_PLAYERS][MAX_ACT_MENU_ROWS]` (полная защита от подмены `listitem`):
     * **Ближайшие игроки:** открытие карточки взаимодействия с выбранным игроком (`DIALOG_ACT_PLAYER_CARD`: передать предмет через `/inv`, передать наличные `/pay`, показать паспорт `/showpass` и лицензии `/showlic`, осмотреть ранения `/triage`, оказать медпомощь `/treat`, поверхностный досмотр `/frisk`, полный обыск `/search`, карманная кража `/pickpocket`, надеть/снять наручники `/cuff` / `/uncuff`, провести арест `/arrest`).
     * **Транспорт (в салоне или рядом):** двигатель `/engine` (`/vengine`), замки дверей `/lock` (`/vlock`), багажник `/trunk`, бардачок `/glovebox`, заправка `/refuel`, полевой ремонт `/repair`, взлом замка `/lockpick`, разбитие стекла `/breakwindow`, скрутка проводов `/hotwire`, разборка на шроте `/chopshop` (`/chop`), автосалон `/vbuy` (`/cars`).
     * **Мировые объекты, недвижимость, экономика и криминалистика:** лут трупа (`CORPSE_LOOT`) и предметов на земле (`WORLD_DROP`), управление домом/арендой `/house` (`/property`, `/rent`), замок двери `/plock`, оплата коммуналки `/paybills` (`/payutils`), гараж `/vpark` и `/garage` (`/vunpark`), выбивание двери `/kickdoor`, добыча сырья `/mine` и сдача на склад `/deliver`, крафт `/craft`, управление предприятием `/biz` и ордерами `/market`, портовый терминал `/port`, контракты логистики `/contracts`, банк/банкомат `/bank` (`/atm`), отмывание денег `/launder`, сейф фракции `/orgvault` и его взлом `/vaultbreak`, осмотр улик `/evidence` (`/ev`).

4. **Главное меню персонажа `/mm`, Кодекс команд `/help`, GPS `/gps` и система репортов `/report` (`ui/mod_main_menu.pwn`):**
   * **`Character Statistics` (`/stats`):** RP-имя, Account ID, Character ID, уровень, возраст ($\text{Age} = 17 + \text{Level}$), гражданство (`US Citizen` / `Immigrant`), SSN, чистые и грязные наличные (`USD`, `EUR`, `CNY`), банковский счет (`IBAN`), баланс, долг, розыск (`0..100`) и таймер `Warrant Decay`, фракция и должность, масса (`kg`) и объем (`L`) Слоя 1 и Слоя 2, показатели HP, брони, стамины, голода, жажды, стресса и зависимости.
   * **`Skills & Role Perks` (`/skills`, `/roleinfo`):** просмотр всех 41 навыков (`0..1000`) в общей таблице или по 5 профильным категориям, а также подробная карточка перков и модификаторов выбранной из 25 стартовых ролей.
   * **`Server Help & Command Codex` (`/help`, `/commands`, `/cmds`, `/faq`):** многостраничный справочник по 7 категориям (*Core Controls & Hotkeys*, *Roleplay & Chat*, *Inventory, Survival & Medical*, *Vehicles & Real Estate*, *Telecom & Radio*, *Jobs, Crafting, Ports & Economy*, а также динамический раздел *Your Faction & Law Enforcement*, адаптирующийся под текущую организацию игрока).
   * **`Contact Administration` (`/report`, `/ask`) и интеграция с `/apanel`:** очередь тикетов `sAdminReports[MAX_ADMIN_REPORTS]` с кулдауном `60 сек` от спама, мгновенным уведомлением онлайн-администраторов, разделом `Player Reports` в `/apanel` (`/reports`) и ответом игроку через диалог или команду `/ans [id] [text]` (с переходом в `/sp`, `/goto` или закрытием тикета и обязательной записью в `Admin_Audit`).
   * **`Interface & Account Settings` (`/settings`):** переключение текстового HUD выживания (`/hud`), подсказок для новичков, параметров чата и двухэтапная смена пароля аккаунта (`bcrypt_verify` старого пароля $\rightarrow$ `bcrypt_hash` нового пароля с `cost = 12` и сохранением в `accounts.password_hash`).
   * **`GPS & Key Locations` (`/gps`, `/nav`):** установка чекпоинта на радаре до 20 ключевых точек штата по 5 категориям (мэрия, банки, автосалоны, больница, полицейские департаменты, ФБР, порты LS/SF/LV, шахта, нефтевышка, лесопилка, ферма, металлургический завод) с автоматическим снятием маршрута при прибытии (`OnPlayerEnterCheckpoint`).

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

### 6.3. Административный RBAC, аудит и защита от эскалации привилегий (Фаза 10)
* **Единая точка авторизации:** любая админ-команда, диалог или HUD-кнопка обязаны вызывать `Admin_HasPermission(playerid, perm)`. Проверки `admin_level >= X`, `IsPlayerAdmin` и прямые сравнения `admin_role_id` в бизнес-логике **запрещены**; допускается только `Admin_IsRoot(playerid)` как встроенный обход внутри самой функции проверки.
* **Защита от эскалации:** назначать роли может только обладатель `MANAGE_ADMINS`; редактировать матрицу прав — только `MANAGE_ROLES`. Роль не может выдать другой роли право, которым не обладает сама (кроме Root). Запрещено удалять Root-роль, снимать последнего Root-администратора и менять `is_root`/`is_system` через игровой UI.
* **Аудит:** каждое действие, изменяющее состояние (выдача/изъятие предметов и денег, бан, мут, варн, деморган, смена скина/статов/навыков/лицензий, выдача транспорта и ключей, изменение ролей), пишется в `audit_logs` через `Admin_Audit` с `admin_account_id`, `target_account_id`, `target_char_id`, `action_type`, `details` и результатом. Отказ в доступе также логируется как `ADMIN_DENIED`.
* **Асинхронность и гонки:** оффлайн-операции выполняются через `mysql_tquery` с проверкой `gPlayerSessionToken` и повторной валидацией `target_account_id` перед `COMMIT`; для онлайн-целей запрещено доверять `playerid` без сверки `account_id`/`char_id`.
* **Кодировка и UI:** все тексты админ-панели, `/ahelp`, HUD `/sp`, причин наказаний и объявлений — грамотный английский язык; официальный язык госструктур и правовых процедур — английский; игроки сохраняют свободу общения в чатах на любом языке. Исходники `.pwn` в `Windows-1251`, соединение БД с `cp1251`.

### 6.4. Контейнеризированная инфраструктура: Multi-Stage Docker, Docker Compose, `.env` и Volumes (Фаза 11)
* **Двухэтапная сборка (`Dockerfile`):**
  * **Stage 1 (`builder`):** На базе `debian:bookworm-slim` с архитектурой `i386` (`libc6:i386`, `libstdc++6:i386`, `libgcc-s1:i386`) запускает `./build.sh`: проверяет отсутствие UTF-8 / BOM во всех `.pwn`/`.inc` файлах (контроль `Windows-1251 / CP1251`) и компилирует `gamemodes/main.pwn` в `gamemodes/main.amx` через `qawno/pawncc` с флагами `-O2 -d1 -;+ -(+ -t4 -Z+ -E` (сборка прерывается при любом `warning` или `error`).
  * **Stage 2 (`runtime`):** Чистый продакшн-образ без исходного кода `.pwn`, компилятора `qawno` и артефактов сборки. Содержит только бинарник `omp-server`, `log-core.so`, `components/`, `plugins/`, `models/`, `scriptfiles/`, `config.json`, `docker-entrypoint.sh` и скомпилированный `gamemodes/main.amx`. Сервер работает от непривилегированного пользователя `ompuser` (`UID 1000`, `GID 1000`).
* **Динамическая инициализация (`docker-entrypoint.sh`):**
  * Перед стартом `./omp-server` скрипт с флагами `set -euo pipefail` подставляет переменные окружения (`OMP_SERVER_NAME`, `OMP_LANGUAGE`, `OMP_MAX_PLAYERS`, `OMP_PORT`, `OMP_RCON_ENABLE`, `OMP_RCON_PASSWORD` и др.) в `config.json` через `jq` без нарушения структуры JSON.
  * Автоматически генерирует `scriptfiles/mysql.ini` и `./mysql.ini` (с правами `0600`) из переменных `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_POOL_SIZE`. Модуль `mod_database.pwn` подключается через `mysql_connect_file("mysql.ini")` с фолбэком на `mysql_connect` + `mysql_init_options()`, после чего принудительно устанавливает `mysql_set_charset("cp1251", gMySQL)` и пул из `12` потоков.
  * Ожидает готовности СУБД через `mysqladmin ping` / `mariadb-admin ping` и передает управление `exec ./omp-server` (PID 1) для штатного перехвата `SIGTERM` и сброса `DB_FlushAllDirtySync()` в `OnGameModeExit`.
* **Оркестрация и сетевая изоляция (`docker-compose.yml`):**
  * Сервис `db` (`mariadb:10.11`, кодировка `utf8mb4_unicode_ci`) и `omp-server` объединены во внутреннюю изолированную bridge-сеть `sar_network` (`sar_net`). Порт СУБД `3306` не публикуется наружу хоста; наружу пробрасываются только игровые порты `${OMP_PORT:-7777}:7777/udp` и `${OMP_PORT:-7777}:7777/tcp`.
  * Сервис `omp-server` запускается строго после прохождения `healthcheck` (`mariadb-admin ping`) у контейнера `db` (`depends_on: db: condition: service_healthy`) с лимитами файловых дескрипторов `ulimits.nofile = 65535`.
* **Персистентные Volumes и автоинициализация БД:**
  * `sar_mysql_data:/var/lib/mysql` — именованный Docker volume для физического хранения таблиц InnoDB.
  * `./sql/001_schema.sql`, `./sql/002_seed_data.sql`, `./sql/003_admin_rbac.sql`, `./sql/004_english_localization_update.sql` монтируются в `/docker-entrypoint-initdb.d/` (`:ro`) и автоматически накатываются в алфавитном порядке при первом старте чистой БД.
  * `./scriptfiles:/opt/omp-server/scriptfiles`, `./logs:/opt/omp-server/logs`, `./backups:/backups` — персистентные bind-тома для данных сервера, логов и резервных копий.
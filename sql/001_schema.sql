-- =============================================================================
--  SAN ANDREAS RP — Полная реляционная схема базы данных (MySQL 8.0+ / MariaDB 10.11+)
--  Файл:        sql/001_schema.sql
--  Пункт:       ROADMAP [0.3] — Развертывание полной схемы базы данных (22 таблицы)
--  Движок:      InnoDB
--  Кодировка:   utf8mb4 / utf8mb4_unicode_ci
--  Примечание:  Масса хранится в граммах (INT/BIGINT UNSIGNED),
--               объем — в миллилитрах (INT/BIGINT UNSIGNED),
--               деньги — в целых единицах валюты (INT/BIGINT).
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CREATE DATABASE IF NOT EXISTS `san_andreas_rp`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE `san_andreas_rp`;

-- Сброс таблиц при чистом развертывании (в обратном порядке зависимостей)
DROP TABLE IF EXISTS `audit_logs`;
DROP TABLE IF EXISTS `forensic_evidence`;
DROP TABLE IF EXISTS `telecom_sims`;
DROP TABLE IF EXISTS `bank_accounts`;
DROP TABLE IF EXISTS `vehicles`;
DROP TABLE IF EXISTS `properties`;
DROP TABLE IF EXISTS `logistics_contracts`;
DROP TABLE IF EXISTS `port_market_quotes`;
DROP TABLE IF EXISTS `enterprise_market_orders`;
DROP TABLE IF EXISTS `enterprises`;
DROP TABLE IF EXISTS `organization_ranks`;
DROP TABLE IF EXISTS `organizations`;
DROP TABLE IF EXISTS `craft_recipe_inputs`;
DROP TABLE IF EXISTS `craft_recipes`;
DROP TABLE IF EXISTS `storage_items`;
DROP TABLE IF EXISTS `character_injuries`;
DROP TABLE IF EXISTS `character_skills`;
DROP TABLE IF EXISTS `characters`;
DROP TABLE IF EXISTS `storages`;
DROP TABLE IF EXISTS `item_definitions`;
DROP TABLE IF EXISTS `account_sessions`;
DROP TABLE IF EXISTS `accounts`;

-- =============================================================================
--  ГРУППА 1: АККАУНТЫ И СЕССИИ БЕЗОПАСНОСТИ (2 таблицы)
-- =============================================================================

-- 1. Таблица аккаунтов игроков
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Таблица истории сессий и подключений
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
--  ГРУППА 2: УНИВЕРСАЛЬНАЯ АРХИТЕКТУРА ПРЕДМЕТОВ, ХРАНИЛИЩ И КРАФТА (5 таблиц)
-- =============================================================================

-- 3. Статический справочник предметов (кешируется в RAM при старте сервера)
CREATE TABLE `item_definitions` (
    `id` SMALLINT UNSIGNED NOT NULL,
    `code_name` VARCHAR(48) NOT NULL,
    `display_name` VARCHAR(64) NOT NULL COMMENT 'English item name for UI',
    `category` ENUM(
        'RAW',
        'INTERMEDIATE',
        'MELEE',
        'FIREARM',
        'HEAVY_THROWABLE',
        'GEAR_ELECTRONICS',
        'MEDICAL_FOOD',
        'ILLEGAL',
        'DOCUMENT_CURRENCY'
    ) NOT NULL,
    `base_weight_g` INT UNSIGNED NOT NULL COMMENT 'Base weight of 1 unit in grams',
    `base_volume_ml` INT UNSIGNED NOT NULL COMMENT 'Base volume of 1 unit in ml',
    `is_stackable` TINYINT(1) NOT NULL DEFAULT 1,
    `max_stack` INT UNSIGNED NOT NULL DEFAULT 1000,
    `gta_weapon_id` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 if not a GTA SA weapon',
    `ammo_unit_weight_g` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Weight of 1 round in grams (e.g. 12 g for 5.56)',
    `inner_max_weight_g` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'If > 0, the item is a portable container (backpack)',
    `inner_max_volume_ml` INT UNSIGNED NOT NULL DEFAULT 0,
    `can_layer2` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = allowed in secret Layer 2',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_item_code` (`code_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Полиморфная сущность Storage (карманы, багажники, цистерны, сейфы, трупы, схроны)
CREATE TABLE `storages` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `storage_type` ENUM(
        'PLAYER_LAYER1', 'PLAYER_LAYER2',
        'VEHICLE_GLOVEBOX', 'VEHICLE_TRUNK',
        'PROPERTY_STASH', 'ORG_VAULT',
        'ENTERPRISE_WAREHOUSE', 'NESTED_BAG',
        'WORLD_DROP', 'CORPSE_LOOT'
    ) NOT NULL,
    `owner_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Owner ID depending on storage_type',
    `max_weight_g` BIGINT UNSIGNED NOT NULL,
    `max_volume_ml` BIGINT UNSIGNED NOT NULL,
    `is_locked` TINYINT(1) NOT NULL DEFAULT 0,
    `lock_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0..5 lockpicking difficulty',
    `pos_x` FLOAT DEFAULT NULL,
    `pos_y` FLOAT DEFAULT NULL,
    `pos_z` FLOAT DEFAULT NULL,
    `interior` INT NOT NULL DEFAULT 0,
    `virtual_world` INT NOT NULL DEFAULT 0,
    `expires_at` DATETIME DEFAULT NULL COMMENT 'TTL for corpses and dropped items',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_storage_owner` (`storage_type`, `owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Экземпляры предметов внутри хранилищ
CREATE TABLE `storage_items` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `storage_id` BIGINT UNSIGNED NOT NULL,
    `item_def_id` SMALLINT UNSIGNED NOT NULL,
    `amount` INT UNSIGNED NOT NULL DEFAULT 1,
    `durability` FLOAT NOT NULL DEFAULT 100.0 COMMENT '0.0..100.0 wear condition',
    `ammo_count` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Number of rounds inside the barrel',
    `nested_storage_id` BIGINT UNSIGNED DEFAULT NULL COMMENT 'Reference to the nested backpack/bag storage',
    `meta_int1` BIGINT DEFAULT 0 COMMENT 'E.g. vehicle/property ID for a key, or bank account ID',
    `meta_int2` BIGINT DEFAULT 0 COMMENT 'E.g. weapon serial number or currency denomination (1=USD, 2=EUR, 3=CNY)',
    `meta_str` VARCHAR(64) DEFAULT NULL COMMENT 'E.g. SSN on a passport, phone number on a SIM',
    PRIMARY KEY (`id`),
    KEY `idx_sitems_storage` (`storage_id`),
    KEY `idx_sitems_def` (`item_def_id`),
    KEY `idx_sitems_nested` (`nested_storage_id`),
    CONSTRAINT `fk_sitems_storage` FOREIGN KEY (`storage_id`) REFERENCES `storages` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_sitems_def` FOREIGN KEY (`item_def_id`) REFERENCES `item_definitions` (`id`),
    CONSTRAINT `fk_sitems_nested` FOREIGN KEY (`nested_storage_id`) REFERENCES `storages` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. Рецепты крафта и заводской переработки
CREATE TABLE `craft_recipes` (
    `id` SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `output_item_id` SMALLINT UNSIGNED NOT NULL,
    `output_amount` INT UNSIGNED NOT NULL DEFAULT 1,
    `station_type` ENUM(
        'HAND',
        'WORKBENCH_WEAPON',
        'WORKBENCH_CHEM',
        'FACTORY_REFINERY',
        'FACTORY_METALLURGY',
        'FACTORY_ASSEMBLY'
    ) NOT NULL,
    `required_skill` VARCHAR(32) DEFAULT NULL,
    `min_skill_level` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `craft_time_sec` SMALLINT UNSIGNED NOT NULL DEFAULT 5,
    PRIMARY KEY (`id`),
    KEY `idx_recipe_out` (`output_item_id`),
    CONSTRAINT `fk_recipe_out` FOREIGN KEY (`output_item_id`) REFERENCES `item_definitions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. Входные ингредиенты рецептов крафта
CREATE TABLE `craft_recipe_inputs` (
    `recipe_id` SMALLINT UNSIGNED NOT NULL,
    `input_item_id` SMALLINT UNSIGNED NOT NULL,
    `input_amount` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`recipe_id`, `input_item_id`),
    KEY `idx_rinput_item` (`input_item_id`),
    CONSTRAINT `fk_rinput_recipe` FOREIGN KEY (`recipe_id`) REFERENCES `craft_recipes` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_rinput_item` FOREIGN KEY (`input_item_id`) REFERENCES `item_definitions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
--  ГРУППА 3: УНИФИЦИРОВАННЫЙ ДВИЖОК ОРГАНИЗАЦИЙ (2 таблицы)
-- =============================================================================

-- 8. Организации (Банды, Корпорации, ЧВК, Госструктуры)
CREATE TABLE `organizations` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(64) NOT NULL,
    `tag` VARCHAR(8) NOT NULL,
    `legal_status` ENUM('UNREGISTERED', 'PRIVATE_CORP', 'STATE_AGENCY') NOT NULL DEFAULT 'UNREGISTERED',
    `is_permanent` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = Core permanent faction (21), cannot be deleted',
    `charter_flags` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Bitmask of state licenses and powers',
    `vault_storage_id` BIGINT UNSIGNED NOT NULL COMMENT 'Physical armored treasury storage',
    `bank_balance_usd` BIGINT NOT NULL DEFAULT 0 COMMENT 'Bank account (CORP/STATE only)',
    `is_bank_frozen` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Account freeze by court/FBI decision',
    `radio_freq` INT UNSIGNED NOT NULL DEFAULT 0,
    `hq_x` FLOAT NOT NULL DEFAULT 0.0,
    `hq_y` FLOAT NOT NULL DEFAULT 0.0,
    `hq_z` FLOAT NOT NULL DEFAULT 0.0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_org_name` (`name`),
    KEY `idx_org_vault` (`vault_storage_id`),
    CONSTRAINT `fk_org_vault` FOREIGN KEY (`vault_storage_id`) REFERENCES `storages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. Должности и матрица прав RBAC организаций
CREATE TABLE `organization_ranks` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `org_id` INT UNSIGNED NOT NULL,
    `rank_order` TINYINT UNSIGNED NOT NULL COMMENT '1..20 hierarchy',
    `title` VARCHAR(48) NOT NULL,
    `salary_usd` INT UNSIGNED NOT NULL DEFAULT 0,
    `permissions_mask` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'RBAC permission matrix',
    PRIMARY KEY (`id`),
    KEY `idx_ranks_org` (`org_id`),
    CONSTRAINT `fk_ranks_org` FOREIGN KEY (`org_id`) REFERENCES `organizations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
--  ГРУППА 4: ПЕРСОНАЖИ, НАВЫКИ И МЕДИЦИНСКОЕ СОСТОЯНИЕ (3 таблицы)
-- =============================================================================

-- 10. Персонажи игроков
CREATE TABLE `characters` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NOT NULL,
    `rp_name` VARCHAR(24) NOT NULL,
    `gender` TINYINT UNSIGNED NOT NULL COMMENT '1=Male, 2=Female',
    `race` TINYINT UNSIGNED NOT NULL,
    `role_id` TINYINT UNSIGNED NOT NULL COMMENT '1..25 (25 starting roles)',
    `level` SMALLINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Character age = 17 + level',
    `exp_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    `citizenship` ENUM('CITIZEN', 'IMMIGRANT') NOT NULL DEFAULT 'CITIZEN',
    `ssn` CHAR(11) DEFAULT NULL COMMENT 'Format XXX-XX-XXXX, NULL for illegal immigrants',
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
    `wanted_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Scale 0..100',
    `active_play_seconds` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Warrant Decay counter (3600s = -1)',
    `jail_seconds_left` INT UNSIGNED NOT NULL DEFAULT 0,
    `jail_type` ENUM('NONE', 'KPZ', 'STATE_PRISON', 'FEDERAL_SUPERMAX') NOT NULL DEFAULT 'NONE',
    `weapon_license_banned` TINYINT(1) NOT NULL DEFAULT 0,
    `is_ck_dead` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = Permanent death (CK)',

    -- Хранилища персонажа (Двухслойная система)
    `layer1_storage_id` BIGINT UNSIGNED NOT NULL COMMENT 'Outer layer (drops on death)',
    `layer2_storage_id` BIGINT UNSIGNED NOT NULL COMMENT 'Inner secret layer (persists)',

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
    KEY `idx_characters_org` (`org_id`),
    CONSTRAINT `fk_characters_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_characters_layer1` FOREIGN KEY (`layer1_storage_id`) REFERENCES `storages` (`id`),
    CONSTRAINT `fk_characters_layer2` FOREIGN KEY (`layer2_storage_id`) REFERENCES `storages` (`id`),
    CONSTRAINT `fk_characters_org` FOREIGN KEY (`org_id`) REFERENCES `organizations` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_characters_orgrank` FOREIGN KEY (`org_rank_id`) REFERENCES `organization_ranks` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. Широкая таблица навыков (0..1000) для загрузки за O(1) одной строкой (41 навык)
CREATE TABLE `character_skills` (
    `char_id` INT UNSIGNED NOT NULL,
    -- Оружейные навыки (18)
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
    -- Физические и транспортные (7)
    `stamina` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    `muscle` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    `driving_skill` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    `bike_skill` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    `cycling_skill` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    `flying_skill` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `lung_capacity` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    -- Криминальные (6)
    `lockpicking` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `hotwiring` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `safe_cracking` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `pickpocketing` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `demolitions` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `stealth` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    -- Ремесло и техника (5)
    `mechanics` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `gunsmithing` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `chemistry` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `mining_logging` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `metallurgy` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    -- Медицина и выживание (5)
    `first_aid` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `surgery` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `survivalism` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `forensics` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `charisma_barter` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`char_id`),
    CONSTRAINT `fk_skills_char` FOREIGN KEY (`char_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 12. Детальное состояние травм по зонам тела
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
    `fracture_flags` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Bitmask: 1=L_Arm, 2=R_Arm, 4=L_Leg, 8=R_Leg, 16=Ribs',
    PRIMARY KEY (`char_id`),
    CONSTRAINT `fk_injuries_char` FOREIGN KEY (`char_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
--  ГРУППА 5: ZERO-FAUCET ЭКОНОМИКА, ПРЕДПРИЯТИЯ, ПОРТЫ И ЛОГИСТИКА (4 таблицы)
-- =============================================================================

-- 13. Предприятия (шахты, вышки, лесопилки, фермы, заводы, магазины, АЗС, шроты)
CREATE TABLE `enterprises` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(64) NOT NULL,
    `enterprise_type` ENUM(
        'MINE_ORE',
        'OIL_RIG',
        'SAWMILL',
        'FARM',
        'REFINERY',
        'METALLURGY',
        'FACTORY',
        'RETAIL_SHOP',
        'GAS_STATION',
        'CHOP_SHOP'
    ) NOT NULL,
    `ownership` ENUM('STATE', 'PRIVATE', 'UNOWNED') NOT NULL DEFAULT 'UNOWNED',
    `owner_char_id` INT UNSIGNED DEFAULT NULL,
    `owner_org_id` INT UNSIGNED DEFAULT NULL,
    `warehouse_storage_id` BIGINT UNSIGNED NOT NULL,
    `reserve_usd` BIGINT NOT NULL DEFAULT 0 COMMENT 'Enterprise working capital',
    `wage_per_kg_usd` INT UNSIGNED NOT NULL DEFAULT 5,
    `pos_x` FLOAT NOT NULL,
    `pos_y` FLOAT NOT NULL,
    `pos_z` FLOAT NOT NULL,
    `auction_price_usd` BIGINT UNSIGNED DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_ent_storage` (`warehouse_storage_id`),
    KEY `idx_ent_owner_char` (`owner_char_id`),
    KEY `idx_ent_owner_org` (`owner_org_id`),
    CONSTRAINT `fk_ent_storage` FOREIGN KEY (`warehouse_storage_id`) REFERENCES `storages` (`id`),
    CONSTRAINT `fk_ent_owner_char` FOREIGN KEY (`owner_char_id`) REFERENCES `characters` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_ent_owner_org` FOREIGN KEY (`owner_org_id`) REFERENCES `organizations` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 14. Биржевые ордера предприятий на закупку сырья и продажу продукции
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
    KEY `idx_orders_item` (`item_def_id`),
    CONSTRAINT `fk_orders_ent` FOREIGN KEY (`enterprise_id`) REFERENCES `enterprises` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_orders_item` FOREIGN KEY (`item_def_id`) REFERENCES `item_definitions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 15. Глобальные торговые хабы (Порты LS, SF, LV)
CREATE TABLE `port_market_quotes` (
    `port_id` TINYINT UNSIGNED NOT NULL COMMENT '1=LS Port, 2=SF Port, 3=LV Rail/Air Hub',
    `item_def_id` SMALLINT UNSIGNED NOT NULL,
    `ref_price_usd` INT UNSIGNED NOT NULL COMMENT 'Reference price',
    `current_stock` BIGINT UNSIGNED NOT NULL DEFAULT 10000,
    `target_stock` BIGINT UNSIGNED NOT NULL DEFAULT 10000,
    `spread_percent` FLOAT NOT NULL DEFAULT 0.12 COMMENT '12% buy/sell spread',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`port_id`, `item_def_id`),
    KEY `idx_port_item` (`item_def_id`),
    CONSTRAINT `fk_port_item` FOREIGN KEY (`item_def_id`) REFERENCES `item_definitions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 16. Контракты дальнобойщиков
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
    PRIMARY KEY (`id`),
    KEY `idx_logistics_source` (`source_ent_id`),
    KEY `idx_logistics_trucker` (`trucker_char_id`),
    CONSTRAINT `fk_logistics_source` FOREIGN KEY (`source_ent_id`) REFERENCES `enterprises` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_logistics_item` FOREIGN KEY (`item_def_id`) REFERENCES `item_definitions` (`id`),
    CONSTRAINT `fk_logistics_trucker` FOREIGN KEY (`trucker_char_id`) REFERENCES `characters` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
--  ГРУППА 6: ИМУЩЕСТВО, ТРАНСПОРТ, БАНКИ, ТЕЛЕКОМ, УЛИКИ И АУДИТ (6 таблиц)
-- =============================================================================

-- 17. Недвижимость (жилая, коммерческая, склады, гаражи)
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
    KEY `idx_prop_storage` (`storage_id`),
    KEY `idx_prop_owner_char` (`owner_char_id`),
    KEY `idx_prop_owner_org` (`owner_org_id`),
    CONSTRAINT `fk_prop_storage` FOREIGN KEY (`storage_id`) REFERENCES `storages` (`id`),
    CONSTRAINT `fk_prop_owner_char` FOREIGN KEY (`owner_char_id`) REFERENCES `characters` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_prop_owner_org` FOREIGN KEY (`owner_org_id`) REFERENCES `organizations` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 18. Транспортные средства
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
    KEY `idx_veh_owner` (`owner_type`, `owner_id`),
    KEY `idx_veh_garage` (`garage_property_id`),
    CONSTRAINT `fk_veh_glovebox` FOREIGN KEY (`glovebox_storage_id`) REFERENCES `storages` (`id`),
    CONSTRAINT `fk_veh_trunk` FOREIGN KEY (`trunk_storage_id`) REFERENCES `storages` (`id`),
    CONSTRAINT `fk_veh_garage` FOREIGN KEY (`garage_property_id`) REFERENCES `properties` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 19. Банковские счета персонажей
CREATE TABLE `bank_accounts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `iban` VARCHAR(20) NOT NULL,
    `owner_char_id` INT UNSIGNED NOT NULL,
    `balance_usd` BIGINT NOT NULL DEFAULT 0,
    `is_frozen` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_bank_iban` (`iban`),
    KEY `idx_bank_owner` (`owner_char_id`),
    CONSTRAINT `fk_bank_char` FOREIGN KEY (`owner_char_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 20. Телекоммуникации и SIM-карты
CREATE TABLE `telecom_sims` (
    `phone_number` VARCHAR(12) NOT NULL,
    `sim_item_id` BIGINT UNSIGNED NOT NULL,
    `registered_ssn` CHAR(11) DEFAULT NULL COMMENT 'NULL for disposable burner SIMs',
    `is_wiretapped` TINYINT(1) NOT NULL DEFAULT 0,
    `wiretap_org_id` INT UNSIGNED DEFAULT NULL,
    PRIMARY KEY (`phone_number`),
    KEY `idx_sim_item` (`sim_item_id`),
    KEY `idx_sim_wiretap_org` (`wiretap_org_id`),
    CONSTRAINT `fk_sim_item` FOREIGN KEY (`sim_item_id`) REFERENCES `storage_items` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_sim_wiretap_org` FOREIGN KEY (`wiretap_org_id`) REFERENCES `organizations` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 21. Криминалистические физические улики
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
    KEY `idx_evidence_expires` (`expires_at`),
    KEY `idx_evidence_suspect` (`suspect_char_id`),
    CONSTRAINT `fk_evidence_suspect` FOREIGN KEY (`suspect_char_id`) REFERENCES `characters` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 22. Аудит-логи критических операций
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

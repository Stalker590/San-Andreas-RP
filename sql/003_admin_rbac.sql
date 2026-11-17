-- =============================================================================
--  SAN ANDREAS RP — Фаза 10: динамическая админ-система, RBAC-ранги и аудит
--  Файл:        sql/003_admin_rbac.sql
--  Пункт:       ROADMAP [10.1] — БД и ядро RBAC, системная Root-роль
--  Кодировка:   utf8mb4 / utf8mb4_unicode_ci
--  Описание:    1. Таблицы admin_roles, admin_role_permissions, admin_punishments
--               2. Колонка accounts.admin_role_id (логическая связь с admin_roles)
--               3. Расширение audit_logs полями администратора и цели
--               4. Единственная системная роль Root-администратор (level = 100)
--  Совместимость: скрипт идемпотентен для MySQL 8.0+ / MariaDB 10.11+
-- =============================================================================

SET NAMES utf8mb4;
SET @db_name := DATABASE();

-- -----------------------------------------------------------------------------
--  1. ДИНАМИЧЕСКИЕ АДМИНИСТРАТИВНЫЕ РОЛИ
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `admin_roles` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(48) NOT NULL COMMENT 'Русское название ранга для UI',
    `level` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1..99 кастомные; 100 Root. Только сортировка',
    `is_root` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = Root-администратор, полный обход RBAC',
    `is_system` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = системная роль, запрещено удалять',
    `permissions_mask` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Битовая маска быстрых разрешений',
    `chat_color_hex` CHAR(6) NOT NULL DEFAULT 'FFFFFF',
    `created_by_account_id` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_admin_roles_name` (`name`),
    KEY `idx_admin_roles_root` (`is_root`),
    CONSTRAINT `fk_admin_roles_creator` FOREIGN KEY (`created_by_account_id`)
        REFERENCES `accounts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_role_permissions` (
    `role_id` INT UNSIGNED NOT NULL,
    `permission_key` VARCHAR(48) NOT NULL COMMENT 'ADMIN_PANEL_ACCESS, MANAGE_ADMINS, PLAYER_BAN, ...',
    `is_allowed` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`role_id`, `permission_key`),
    CONSTRAINT `fk_admin_perm_role` FOREIGN KEY (`role_id`)
        REFERENCES `admin_roles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  2. ЖУРНАЛ НАКАЗАНИЙ (МУТ, ВАРН, ДЕМОРГАН, БАНЫ)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `admin_punishments` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `target_account_id` INT UNSIGNED NOT NULL,
    `target_char_id` INT UNSIGNED DEFAULT NULL,
    `admin_account_id` INT UNSIGNED DEFAULT NULL,
    `punishment_type` ENUM('MUTE', 'WARN', 'DEMORGAN', 'BAN_TEMP', 'BAN_PERM') NOT NULL,
    `reason` VARCHAR(255) NOT NULL,
    `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` DATETIME DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `revoked_by_account_id` INT UNSIGNED DEFAULT NULL,
    `revoked_at` DATETIME DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_punish_target` (`target_account_id`, `is_active`),
    KEY `idx_punish_expires` (`expires_at`),
    CONSTRAINT `fk_punish_target` FOREIGN KEY (`target_account_id`)
        REFERENCES `accounts` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_punish_admin` FOREIGN KEY (`admin_account_id`)
        REFERENCES `accounts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  3. АДДИТИВНЫЕ КОЛОНКИ ACCOUNTS И AUDIT_LOGS
-- -----------------------------------------------------------------------------
SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'accounts' AND COLUMN_NAME = 'admin_role_id') = 0,
    'ALTER TABLE `accounts` ADD COLUMN `admin_role_id` INT UNSIGNED DEFAULT NULL COMMENT ''Активная админ-роль; NULL = нет прав'' AFTER `admin_level`',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'accounts' AND INDEX_NAME = 'idx_accounts_admin_role') = 0,
    'ALTER TABLE `accounts` ADD KEY `idx_accounts_admin_role` (`admin_role_id`)',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'audit_logs' AND COLUMN_NAME = 'admin_account_id') = 0,
    'ALTER TABLE `audit_logs` ADD COLUMN `admin_account_id` INT UNSIGNED DEFAULT NULL COMMENT ''ID админ-аккаунта'' AFTER `actor_char_id`',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'audit_logs' AND COLUMN_NAME = 'target_account_id') = 0,
    'ALTER TABLE `audit_logs` ADD COLUMN `target_account_id` INT UNSIGNED DEFAULT NULL COMMENT ''ID аккаунта-цели'' AFTER `admin_account_id`',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'audit_logs' AND COLUMN_NAME = 'target_char_id') = 0,
    'ALTER TABLE `audit_logs` ADD COLUMN `target_char_id` INT UNSIGNED DEFAULT NULL COMMENT ''ID персонажа-цели'' AFTER `target_account_id`',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'audit_logs' AND INDEX_NAME = 'idx_audit_admin') = 0,
    'ALTER TABLE `audit_logs` ADD KEY `idx_audit_admin` (`admin_account_id`)',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'audit_logs' AND INDEX_NAME = 'idx_audit_target') = 0,
    'ALTER TABLE `audit_logs` ADD KEY `idx_audit_target` (`target_account_id`, `target_char_id`)',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
--  4. ЕДИНСТВЕННАЯ СИСТЕМНАЯ ROOT-РОЛЬ
--      level = 100, is_root = 1, is_system = 1, полная битовая маска.
--      Отдельные строки admin_role_permissions для Root не требуются:
--      Admin_HasPermission всегда возвращает true при is_root = 1.
-- -----------------------------------------------------------------------------
INSERT INTO `admin_roles`
    (`name`, `level`, `is_root`, `is_system`, `permissions_mask`, `chat_color_hex`)
SELECT 'Root-администратор', 100, 1, 1, 18446744073709551615, 'FFD700'
WHERE NOT EXISTS (SELECT 1 FROM `admin_roles` WHERE `is_root` = 1);

-- Защита от случайного дублирования Root-роли на уровне приложения дополняется
-- проверкой в Admin_CreateRole/Admin_AssignRole (Pawn).

-- -----------------------------------------------------------------------------
--  5. НАЗНАЧЕНИЕ ROOT-РОЛИ ПЕРВОМУ АДМИНИСТРАТОРУ (выполняется вручную)
--     После наката миграции назначьте Root-роль нужному аккаунту:
--     UPDATE `accounts`
--        SET `admin_role_id` = (SELECT `id` FROM `admin_roles` WHERE `is_root` = 1 LIMIT 1)
--      WHERE `username` = 'Имя_Аккаунта';
-- -----------------------------------------------------------------------------

-- =============================================================================
--  SAN ANDREAS RP — SQL-инварианты фазы 9.2 (нагрузочное и балансовое тестирование)
--  Каждая строка результата: check_name + violations.
--  Ожидаемый результат: violations = 0 для всех проверок.
--  Запуск: mysql --batch --skip-column-names < tests/phase9_invariants.sql
-- =============================================================================

SELECT 'negative_enterprise_reserve' AS check_name, COUNT(*) AS violations
FROM enterprises WHERE reserve_usd < 0
UNION ALL
SELECT 'negative_bank_balance', COUNT(*) FROM bank_accounts WHERE balance_usd < 0
UNION ALL
SELECT 'invalid_wanted_level', COUNT(*) FROM characters WHERE wanted_level > 100
UNION ALL
SELECT 'invalid_character_level', COUNT(*) FROM characters WHERE level < 1
UNION ALL
SELECT 'nonpositive_item_amount', COUNT(*) FROM storage_items WHERE amount <= 0
UNION ALL
SELECT 'nonpositive_item_weight', COUNT(*) FROM item_definitions WHERE base_weight_g <= 0
UNION ALL
SELECT 'orphan_storage_items', COUNT(*)
FROM storage_items si LEFT JOIN storages s ON s.id = si.storage_id WHERE s.id IS NULL
UNION ALL
SELECT 'orphan_character_layer1', COUNT(*)
FROM characters c LEFT JOIN storages s ON s.id = c.layer1_storage_id WHERE s.id IS NULL
UNION ALL
SELECT 'orphan_character_layer2', COUNT(*)
FROM characters c LEFT JOIN storages s ON s.id = c.layer2_storage_id WHERE s.id IS NULL
UNION ALL
SELECT 'duplicate_weapon_serials', COUNT(*)
FROM (
    SELECT meta_int2 FROM storage_items
    WHERE meta_int2 > 0 AND ammo_count > 0
    GROUP BY meta_int2 HAVING COUNT(*) > 1
) duplicates
UNION ALL
SELECT 'invalid_port_spread', COUNT(*)
FROM port_market_quotes WHERE spread_percent < 0 OR spread_percent > 0.5
UNION ALL
SELECT 'zero_storage_limits', COUNT(*)
FROM storages WHERE max_weight_g = 0 OR max_volume_ml = 0
UNION ALL
SELECT 'organization_without_vault', COUNT(*)
FROM organizations o LEFT JOIN storages s ON s.id = o.vault_storage_id WHERE s.id IS NULL
UNION ALL
SELECT 'enterprise_without_warehouse', COUNT(*)
FROM enterprises e LEFT JOIN storages s ON s.id = e.warehouse_storage_id WHERE s.id IS NULL
UNION ALL
SELECT 'negative_vehicle_fuel', COUNT(*) FROM vehicles WHERE fuel_ml < 0 OR max_fuel_ml <= 0;

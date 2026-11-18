-- =============================================================================
--  SAN ANDREAS RP — Идемпотентная миграция локализации справочников на английский
--  Файл:        sql/004_english_localization_update.sql
--  Кодировка:   utf8mb4 / utf8mb4_unicode_ci
--  Описание:    1. Обновление item_definitions.display_name (все 91 предмет)
--               2. Обновление organizations.name (все 21 постоянная фракция)
--               3. Обновление organization_ranks.title (все 105+ должностей)
--               4. Обновление enterprises.name (все 16 стартовых предприятий)
--               5. Обновление системной роли Root Administrator в admin_roles
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `san_andreas_rp`;

START TRANSACTION;

-- -----------------------------------------------------------------------------
--  1. ПРЕДМЕТЫ (item_definitions.display_name — 91 позиция)
-- -----------------------------------------------------------------------------
UPDATE `item_definitions` SET `display_name` = 'Brass Knuckles' WHERE `id` = 1 OR `code_name` = 'MELEE_BRASS_KNUCKLES';
UPDATE `item_definitions` SET `display_name` = 'Golf Club' WHERE `id` = 2 OR `code_name` = 'MELEE_GOLF_CLUB';
UPDATE `item_definitions` SET `display_name` = 'Police Nightstick' WHERE `id` = 3 OR `code_name` = 'MELEE_NIGHTSTICK';
UPDATE `item_definitions` SET `display_name` = 'Combat Knife' WHERE `id` = 4 OR `code_name` = 'MELEE_KNIFE';
UPDATE `item_definitions` SET `display_name` = 'Baseball Bat' WHERE `id` = 5 OR `code_name` = 'MELEE_BASEBALL_BAT';
UPDATE `item_definitions` SET `display_name` = 'Shovel' WHERE `id` = 6 OR `code_name` = 'MELEE_SHOVEL';
UPDATE `item_definitions` SET `display_name` = 'Pool Cue' WHERE `id` = 7 OR `code_name` = 'MELEE_POOL_CUE';
UPDATE `item_definitions` SET `display_name` = 'Katana' WHERE `id` = 8 OR `code_name` = 'MELEE_KATANA';
UPDATE `item_definitions` SET `display_name` = 'Chainsaw' WHERE `id` = 9 OR `code_name` = 'MELEE_CHAINSAW';
UPDATE `item_definitions` SET `display_name` = 'Cane' WHERE `id` = 10 OR `code_name` = 'MELEE_CANE';
UPDATE `item_definitions` SET `display_name` = 'Bouquet of Flowers' WHERE `id` = 11 OR `code_name` = 'MELEE_FLOWERS';
UPDATE `item_definitions` SET `display_name` = 'Adult Toy' WHERE `id` = 12 OR `code_name` = 'MELEE_DILDO';
UPDATE `item_definitions` SET `display_name` = '9mm Pistol' WHERE `id` = 13 OR `code_name` = 'WEAPON_PISTOL_9MM';
UPDATE `item_definitions` SET `display_name` = 'Silenced 9mm Pistol' WHERE `id` = 14 OR `code_name` = 'WEAPON_SILENCED_9MM';
UPDATE `item_definitions` SET `display_name` = 'Desert Eagle' WHERE `id` = 15 OR `code_name` = 'WEAPON_DESERT_EAGLE';
UPDATE `item_definitions` SET `display_name` = 'Pump Shotgun' WHERE `id` = 16 OR `code_name` = 'WEAPON_PUMP_SHOTGUN';
UPDATE `item_definitions` SET `display_name` = 'Sawed-off Shotgun' WHERE `id` = 17 OR `code_name` = 'WEAPON_SAWNOFF';
UPDATE `item_definitions` SET `display_name` = 'Combat Shotgun SPAS-12' WHERE `id` = 18 OR `code_name` = 'WEAPON_SPAS12';
UPDATE `item_definitions` SET `display_name` = 'Micro Uzi' WHERE `id` = 19 OR `code_name` = 'WEAPON_MICRO_UZI';
UPDATE `item_definitions` SET `display_name` = 'Tec-9' WHERE `id` = 20 OR `code_name` = 'WEAPON_TEC9';
UPDATE `item_definitions` SET `display_name` = 'MP5' WHERE `id` = 21 OR `code_name` = 'WEAPON_MP5';
UPDATE `item_definitions` SET `display_name` = 'AK-47 Assault Rifle' WHERE `id` = 22 OR `code_name` = 'WEAPON_AK47';
UPDATE `item_definitions` SET `display_name` = 'M4 Assault Rifle' WHERE `id` = 23 OR `code_name` = 'WEAPON_M4';
UPDATE `item_definitions` SET `display_name` = 'Hunting Rifle' WHERE `id` = 24 OR `code_name` = 'WEAPON_COUNTRY_RIFLE';
UPDATE `item_definitions` SET `display_name` = 'Sniper Rifle' WHERE `id` = 25 OR `code_name` = 'WEAPON_SNIPER_RIFLE';
UPDATE `item_definitions` SET `display_name` = 'Frag Grenade' WHERE `id` = 26 OR `code_name` = 'HEAVY_GRENADE';
UPDATE `item_definitions` SET `display_name` = 'Tear Gas' WHERE `id` = 27 OR `code_name` = 'HEAVY_TEARGAS';
UPDATE `item_definitions` SET `display_name` = 'Molotov Cocktail' WHERE `id` = 28 OR `code_name` = 'HEAVY_MOLOTOV';
UPDATE `item_definitions` SET `display_name` = 'Satchel Charge' WHERE `id` = 29 OR `code_name` = 'HEAVY_SATCHEL_CHARGE';
UPDATE `item_definitions` SET `display_name` = 'RPG-7' WHERE `id` = 30 OR `code_name` = 'HEAVY_RPG7';
UPDATE `item_definitions` SET `display_name` = 'Heat-seeking SAM Launcher' WHERE `id` = 31 OR `code_name` = 'HEAVY_HS_ROCKET';
UPDATE `item_definitions` SET `display_name` = 'Flamethrower' WHERE `id` = 32 OR `code_name` = 'HEAVY_FLAMETHROWER';
UPDATE `item_definitions` SET `display_name` = 'Minigun' WHERE `id` = 33 OR `code_name` = 'HEAVY_MINIGUN';
UPDATE `item_definitions` SET `display_name` = 'Pepper Spray' WHERE `id` = 34 OR `code_name` = 'SPEC_SPRAYCAN';
UPDATE `item_definitions` SET `display_name` = 'Fire Extinguisher' WHERE `id` = 35 OR `code_name` = 'SPEC_FIRE_EXT';
UPDATE `item_definitions` SET `display_name` = 'Camera' WHERE `id` = 36 OR `code_name` = 'SPEC_CAMERA';
UPDATE `item_definitions` SET `display_name` = 'Night Vision Goggles' WHERE `id` = 37 OR `code_name` = 'SPEC_NV_GOGGLES';
UPDATE `item_definitions` SET `display_name` = 'Thermal Goggles' WHERE `id` = 38 OR `code_name` = 'SPEC_THERMAL_GOGGLES';
UPDATE `item_definitions` SET `display_name` = 'Parachute' WHERE `id` = 39 OR `code_name` = 'SPEC_PARACHUTE';
UPDATE `item_definitions` SET `display_name` = 'Heavy Body Armor' WHERE `id` = 40 OR `code_name` = 'GEAR_BODY_ARMOR';
UPDATE `item_definitions` SET `display_name` = 'Hiking Backpack' WHERE `id` = 41 OR `code_name` = 'GEAR_BACKPACK';
UPDATE `item_definitions` SET `display_name` = 'Duffle Bag' WHERE `id` = 42 OR `code_name` = 'GEAR_DUFFLE_BAG';
UPDATE `item_definitions` SET `display_name` = 'Tactical Balaclava' WHERE `id` = 43 OR `code_name` = 'GEAR_BALACLAVA';
UPDATE `item_definitions` SET `display_name` = 'Steel Handcuffs' WHERE `id` = 44 OR `code_name` = 'GEAR_HANDCUFFS';
UPDATE `item_definitions` SET `display_name` = 'Lockpick Set' WHERE `id` = 45 OR `code_name` = 'TOOL_LOCKPICK_SET';
UPDATE `item_definitions` SET `display_name` = 'Mechanic''s Wrench Kit' WHERE `id` = 46 OR `code_name` = 'TOOL_WRENCH_KIT';
UPDATE `item_definitions` SET `display_name` = 'Gunsmith Kit' WHERE `id` = 47 OR `code_name` = 'TOOL_GUNSMITH_KIT';
UPDATE `item_definitions` SET `display_name` = '20L Fuel Canister' WHERE `id` = 48 OR `code_name` = 'TOOL_FUEL_CANISTER';
UPDATE `item_definitions` SET `display_name` = 'Bolt Cutters' WHERE `id` = 49 OR `code_name` = 'TOOL_BOLT_CUTTERS';
UPDATE `item_definitions` SET `display_name` = 'Smartphone' WHERE `id` = 50 OR `code_name` = 'ELEC_MOBILE_PHONE';
UPDATE `item_definitions` SET `display_name` = 'Burner Phone' WHERE `id` = 51 OR `code_name` = 'ELEC_BURNER_PHONE';
UPDATE `item_definitions` SET `display_name` = 'SIM Card' WHERE `id` = 52 OR `code_name` = 'ELEC_SIM_CARD';
UPDATE `item_definitions` SET `display_name` = 'Walkie-Talkie' WHERE `id` = 53 OR `code_name` = 'ELEC_WALKIE_TALKIE';
UPDATE `item_definitions` SET `display_name` = 'Mining Pickaxe' WHERE `id` = 54 OR `code_name` = 'TOOL_MINING_PICKAXE';
UPDATE `item_definitions` SET `display_name` = 'Forensics Kit' WHERE `id` = 55 OR `code_name` = 'TOOL_FORENSICS_KIT';
UPDATE `item_definitions` SET `display_name` = 'First Aid Kit' WHERE `id` = 56 OR `code_name` = 'MED_FIRST_AID_KIT';
UPDATE `item_definitions` SET `display_name` = 'Surgical Kit' WHERE `id` = 57 OR `code_name` = 'MED_SURGICAL_KIT';
UPDATE `item_definitions` SET `display_name` = 'Sterile Bandage' WHERE `id` = 58 OR `code_name` = 'MED_BANDAGE';
UPDATE `item_definitions` SET `display_name` = 'Tourniquet' WHERE `id` = 59 OR `code_name` = 'MED_TOURNIQUET';
UPDATE `item_definitions` SET `display_name` = 'Morphine Syringe' WHERE `id` = 60 OR `code_name` = 'MED_MORPHINE_SYRINGE';
UPDATE `item_definitions` SET `display_name` = '1L Water Bottle' WHERE `id` = 61 OR `code_name` = 'FOOD_WATER_BOTTLE';
UPDATE `item_definitions` SET `display_name` = 'Military MRE Ration' WHERE `id` = 62 OR `code_name` = 'FOOD_MRE_RATION';
UPDATE `item_definitions` SET `display_name` = 'Hot Burger' WHERE `id` = 63 OR `code_name` = 'FOOD_FASTFOOD_BURGER';
UPDATE `item_definitions` SET `display_name` = 'Whiskey Bottle' WHERE `id` = 64 OR `code_name` = 'FOOD_LIQUOR_BOTTLE';
UPDATE `item_definitions` SET `display_name` = 'Cigarette Pack' WHERE `id` = 65 OR `code_name` = 'FOOD_CIGARETTE_PACK';
UPDATE `item_definitions` SET `display_name` = 'Methamphetamine Dose' WHERE `id` = 66 OR `code_name` = 'ILLEGAL_HARD_DRUG';
UPDATE `item_definitions` SET `display_name` = 'Marijuana Brick' WHERE `id` = 67 OR `code_name` = 'ILLEGAL_WEED_PACK';
UPDATE `item_definitions` SET `display_name` = 'Passport / ID' WHERE `id` = 68 OR `code_name` = 'DOC_PASSPORT_ID';
UPDATE `item_definitions` SET `display_name` = 'Weapon License' WHERE `id` = 69 OR `code_name` = 'DOC_WEAPON_LICENSE';
UPDATE `item_definitions` SET `display_name` = 'Vehicle Title' WHERE `id` = 70 OR `code_name` = 'DOC_VEHICLE_TITLE';
UPDATE `item_definitions` SET `display_name` = 'Bank Debit Card' WHERE `id` = 71 OR `code_name` = 'DOC_BANK_CARD';
UPDATE `item_definitions` SET `display_name` = 'Set of Keys' WHERE `id` = 72 OR `code_name` = 'ITEM_PHYSICAL_KEYS';
UPDATE `item_definitions` SET `display_name` = 'Cash Bundle' WHERE `id` = 73 OR `code_name` = 'CURR_CASH_BUNDLE';
UPDATE `item_definitions` SET `display_name` = 'Raw Commodity Unit' WHERE `id` = 74 OR `code_name` = 'RAW_COMMODITY_UNIT';
UPDATE `item_definitions` SET `display_name` = 'Processed Metal Unit' WHERE `id` = 75 OR `code_name` = 'INT_PROCESSED_METAL';
UPDATE `item_definitions` SET `display_name` = 'Crude Oil' WHERE `id` = 76 OR `code_name` = 'RAW_CRUDE_OIL';
UPDATE `item_definitions` SET `display_name` = 'Iron Ore' WHERE `id` = 77 OR `code_name` = 'RAW_IRON_ORE';
UPDATE `item_definitions` SET `display_name` = 'Raw Log' WHERE `id` = 78 OR `code_name` = 'RAW_WOOD_LOG';
UPDATE `item_definitions` SET `display_name` = 'Raw Water' WHERE `id` = 79 OR `code_name` = 'RAW_TECH_WATER';
UPDATE `item_definitions` SET `display_name` = 'Grain and Flour' WHERE `id` = 80 OR `code_name` = 'RAW_GRAIN_FLOUR';
UPDATE `item_definitions` SET `display_name` = 'Chemical Precursors' WHERE `id` = 81 OR `code_name` = 'RAW_CHEM_PRECURSORS';
UPDATE `item_definitions` SET `display_name` = 'Steel Sheet' WHERE `id` = 82 OR `code_name` = 'INT_STEEL_SHEET';
UPDATE `item_definitions` SET `display_name` = 'Springs and Pins' WHERE `id` = 83 OR `code_name` = 'INT_SPRINGS_PINS';
UPDATE `item_definitions` SET `display_name` = 'Bearings' WHERE `id` = 84 OR `code_name` = 'INT_BEARINGS';
UPDATE `item_definitions` SET `display_name` = 'Nails and Fasteners' WHERE `id` = 85 OR `code_name` = 'INT_NAILS_FASTENERS';
UPDATE `item_definitions` SET `display_name` = 'Synthetic Plastic' WHERE `id` = 86 OR `code_name` = 'INT_SYNTH_PLASTIC';
UPDATE `item_definitions` SET `display_name` = 'Smokeless Gunpowder' WHERE `id` = 87 OR `code_name` = 'INT_GUNPOWDER';
UPDATE `item_definitions` SET `display_name` = 'Planks' WHERE `id` = 88 OR `code_name` = 'INT_WOOD_PLANKS';
UPDATE `item_definitions` SET `display_name` = 'Fabric' WHERE `id` = 89 OR `code_name` = 'INT_TEXTILE_FABRIC';
UPDATE `item_definitions` SET `display_name` = 'Refined Fuel' WHERE `id` = 90 OR `code_name` = 'INT_REFINED_FUEL';
UPDATE `item_definitions` SET `display_name` = 'Clothing Outfit' WHERE `id` = 91 OR `code_name` = 'GEAR_CLOTHING_OUTFIT';

-- -----------------------------------------------------------------------------
--  2. ПОСТОЯННЫЕ ОРГАНИЗАЦИИ (organizations.name — 21 фракция)
-- -----------------------------------------------------------------------------
UPDATE `organizations` SET `name` = 'State Government of San Andreas' WHERE `id` = 1;
UPDATE `organizations` SET `name` = 'Los Santos Police Department' WHERE `id` = 2;
UPDATE `organizations` SET `name` = 'San Fierro Police Department' WHERE `id` = 3;
UPDATE `organizations` SET `name` = 'Las Venturas Police Department' WHERE `id` = 4;
UPDATE `organizations` SET `name` = 'County Sheriff''s Department' WHERE `id` = 5;
UPDATE `organizations` SET `name` = 'Los Santos National Guard' WHERE `id` = 6;
UPDATE `organizations` SET `name` = 'San Fierro Naval Forces' WHERE `id` = 7;
UPDATE `organizations` SET `name` = 'Area 69 Military Garrison' WHERE `id` = 8;
UPDATE `organizations` SET `name` = 'Federal Bureau of Investigation' WHERE `id` = 9;
UPDATE `organizations` SET `name` = 'Central Intelligence Agency' WHERE `id` = 10;
UPDATE `organizations` SET `name` = 'Immigration and Customs Enforcement' WHERE `id` = 11;
UPDATE `organizations` SET `name` = 'Department of Health and Emergency Services' WHERE `id` = 12;
UPDATE `organizations` SET `name` = 'Blackwater San Andreas PMC' WHERE `id` = 13;
UPDATE `organizations` SET `name` = 'Port Authority and Logistics' WHERE `id` = 14;
UPDATE `organizations` SET `name` = 'San Andreas News Network' WHERE `id` = 15;
UPDATE `organizations` SET `name` = 'Grove Street Families' WHERE `id` = 16;
UPDATE `organizations` SET `name` = 'Ballas Gang' WHERE `id` = 17;
UPDATE `organizations` SET `name` = 'Los Santos Vagos' WHERE `id` = 18;
UPDATE `organizations` SET `name` = 'Varrios Los Aztecas' WHERE `id` = 19;
UPDATE `organizations` SET `name` = 'San Fierro Triad Syndicate' WHERE `id` = 20;
UPDATE `organizations` SET `name` = 'Las Venturas Crime Family' WHERE `id` = 21;

-- -----------------------------------------------------------------------------
--  3. ДОЛЖНОСТИ ОРГАНИЗАЦИЙ (organization_ranks.title — 105+ должностей)
-- -----------------------------------------------------------------------------
UPDATE `organization_ranks` SET `title` = 'Executive Secretary' WHERE `id` = 1 OR (`org_id` = 1 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Tax Service Inspector' WHERE `id` = 2 OR (`org_id` = 1 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'State Federal Judge' WHERE `id` = 3 OR (`org_id` = 1 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Lieutenant Governor' WHERE `id` = 4 OR (`org_id` = 1 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Governor of San Andreas' WHERE `id` = 5 OR (`org_id` = 1 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Academy Cadet' WHERE `id` = 6 OR (`org_id` = 2 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Patrol Officer' WHERE `id` = 7 OR (`org_id` = 2 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Detective, Investigations Division' WHERE `id` = 8 OR (`org_id` = 2 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Precinct Captain' WHERE `id` = 9 OR (`org_id` = 2 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Chief of Los Santos Police' WHERE `id` = 10 OR (`org_id` = 2 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Academy Cadet' WHERE `id` = 11 OR (`org_id` = 3 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Patrol Officer' WHERE `id` = 12 OR (`org_id` = 3 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Port District Inspector' WHERE `id` = 13 OR (`org_id` = 3 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Police Captain' WHERE `id` = 14 OR (`org_id` = 3 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Chief of San Fierro Police' WHERE `id` = 15 OR (`org_id` = 3 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Academy Cadet' WHERE `id` = 16 OR (`org_id` = 4 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Patrol Officer' WHERE `id` = 17 OR (`org_id` = 4 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Gaming Control Investigator' WHERE `id` = 18 OR (`org_id` = 4 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Police Captain' WHERE `id` = 19 OR (`org_id` = 4 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Chief of Las Venturas Police' WHERE `id` = 20 OR (`org_id` = 4 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Sheriff''s Department Intern' WHERE `id` = 21 OR (`org_id` = 5 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Deputy Sheriff' WHERE `id` = 22 OR (`org_id` = 5 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'County Senior Ranger' WHERE `id` = 23 OR (`org_id` = 5 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Undersheriff' WHERE `id` = 24 OR (`org_id` = 5 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Sheriff of San Andreas County' WHERE `id` = 25 OR (`org_id` = 5 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Guardsman' WHERE `id` = 26 OR (`org_id` = 6 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Motorized Infantry Sergeant' WHERE `id` = 27 OR (`org_id` = 6 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Logistics Lieutenant' WHERE `id` = 28 OR (`org_id` = 6 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Garrison Colonel' WHERE `id` = 29 OR (`org_id` = 6 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'National Guard General' WHERE `id` = 30 OR (`org_id` = 6 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Coast Guard Seaman' WHERE `id` = 31 OR (`org_id` = 7 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Fleet Petty Officer' WHERE `id` = 32 OR (`org_id` = 7 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Naval Aviation Lieutenant' WHERE `id` = 33 OR (`org_id` = 7 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Captain First Rank' WHERE `id` = 34 OR (`org_id` = 7 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Admiral of the San Fierro Fleet' WHERE `id` = 35 OR (`org_id` = 7 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Perimeter Guard' WHERE `id` = 36 OR (`org_id` = 8 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Missile Battalion Sergeant' WHERE `id` = 37 OR (`org_id` = 8 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Classified Sector Officer' WHERE `id` = 38 OR (`org_id` = 8 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Deputy Commander of Area 69' WHERE `id` = 39 OR (`org_id` = 8 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Commander of Area 69' WHERE `id` = 40 OR (`org_id` = 8 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'FBI Junior Agent' WHERE `id` = 41 OR (`org_id` = 9 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'FBI Special Agent' WHERE `id` = 42 OR (`org_id` = 9 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'FBI Senior Investigator' WHERE `id` = 43 OR (`org_id` = 9 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Deputy Office Director' WHERE `id` = 44 OR (`org_id` = 9 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Director of the FBI Field Office' WHERE `id` = 45 OR (`org_id` = 9 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Station Analyst' WHERE `id` = 46 OR (`org_id` = 10 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'CIA Operations Officer' WHERE `id` = 47 OR (`org_id` = 10 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Foreign Operations Handler' WHERE `id` = 48 OR (`org_id` = 10 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Deputy Station Chief' WHERE `id` = 49 OR (`org_id` = 10 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'CIA Station Chief' WHERE `id` = 50 OR (`org_id` = 10 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Checkpoint Inspector' WHERE `id` = 51 OR (`org_id` = 11 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Customs Inspection Officer' WHERE `id` = 52 OR (`org_id` = 11 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Immigration Investigator' WHERE `id` = 53 OR (`org_id` = 11 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Border Sector Chief' WHERE `id` = 54 OR (`org_id` = 11 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'ICE Customs Commissioner' WHERE `id` = 55 OR (`org_id` = 11 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Paramedic' WHERE `id` = 56 OR (`org_id` = 12 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Critical Care Paramedic' WHERE `id` = 57 OR (`org_id` = 12 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Trauma Surgeon' WHERE `id` = 58 OR (`org_id` = 12 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Department Head' WHERE `id` = 59 OR (`org_id` = 12 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'EMS Chief Medical Officer' WHERE `id` = 60 OR (`org_id` = 12 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Security Contract Recruit' WHERE `id` = 61 OR (`org_id` = 13 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Convoy Escort Operator' WHERE `id` = 62 OR (`org_id` = 13 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Assault Team Leader' WHERE `id` = 63 OR (`org_id` = 13 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Chief of Operations' WHERE `id` = 64 OR (`org_id` = 13 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'PMC Executive Director' WHERE `id` = 65 OR (`org_id` = 13 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Dock Dispatcher' WHERE `id` = 66 OR (`org_id` = 14 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Terminal Customs Logistician' WHERE `id` = 67 OR (`org_id` = 14 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Senior Freight Inspector' WHERE `id` = 68 OR (`org_id` = 14 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Deputy Port Director' WHERE `id` = 69 OR (`org_id` = 14 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Port Director General' WHERE `id` = 70 OR (`org_id` = 14 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Newsroom Intern' WHERE `id` = 71 OR (`org_id` = 15 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Crime Reporter' WHERE `id` = 72 OR (`org_id` = 15 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Live Broadcast Anchor' WHERE `id` = 73 OR (`org_id` = 15 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Broadcast Editor-in-Chief' WHERE `id` = 74 OR (`org_id` = 15 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'SAN News Executive Producer' WHERE `id` = 75 OR (`org_id` = 15 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Street Hustler' WHERE `id` = 76 OR (`org_id` = 16 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Block Soldier' WHERE `id` = 77 OR (`org_id` = 16 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Senior Gangster' WHERE `id` = 78 OR (`org_id` = 16 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Neighborhood Right Hand' WHERE `id` = 79 OR (`org_id` = 16 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Leader of Grove Street Families' WHERE `id` = 80 OR (`org_id` = 16 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Corner Runner' WHERE `id` = 81 OR (`org_id` = 17 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Block Shooter' WHERE `id` = 82 OR (`org_id` = 17 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Corner Boss' WHERE `id` = 83 OR (`org_id` = 17 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Idlewood Authority' WHERE `id` = 84 OR (`org_id` = 17 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Ballas Gang Leader' WHERE `id` = 85 OR (`org_id` = 17 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Barrio Rookie' WHERE `id` = 86 OR (`org_id` = 18 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Street Soldier' WHERE `id` = 87 OR (`org_id` = 18 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Arms Smuggler' WHERE `id` = 88 OR (`org_id` = 18 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Cartel Advisor' WHERE `id` = 89 OR (`org_id` = 18 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Padre of Los Santos Vagos' WHERE `id` = 90 OR (`org_id` = 18 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Junior Racer' WHERE `id` = 91 OR (`org_id` = 19 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Little Mexico Soldier' WHERE `id` = 92 OR (`org_id` = 19 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Auto Syndicate Mechanic' WHERE `id` = 93 OR (`org_id` = 19 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Neighborhood Veteran' WHERE `id` = 94 OR (`org_id` = 19 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Jefe of Varrios Los Aztecas' WHERE `id` = 95 OR (`org_id` = 19 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Chinatown Street Fighter' WHERE `id` = 96 OR (`org_id` = 20 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Syndicate Enforcer' WHERE `id` = 97 OR (`org_id` = 20 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Red Pole' WHERE `id` = 98 OR (`org_id` = 20 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Lodge Vanguard' WHERE `id` = 99 OR (`org_id` = 20 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Dragon Head of the Triads' WHERE `id` = 100 OR (`org_id` = 20 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Family Associate' WHERE `id` = 101 OR (`org_id` = 21 AND `rank_order` = 1 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Family Soldier' WHERE `id` = 102 OR (`org_id` = 21 AND `rank_order` = 2 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Caporegime' WHERE `id` = 103 OR (`org_id` = 21 AND `rank_order` = 3 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Consigliere' WHERE `id` = 104 OR (`org_id` = 21 AND `rank_order` = 4 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'Don of the Crime Family' WHERE `id` = 105 OR (`org_id` = 21 AND `rank_order` = 5 AND `id` <= 105);
UPDATE `organization_ranks` SET `title` = 'CIA Director' WHERE `title` = 'Директор ЦРУ';
UPDATE `organization_ranks` SET `title` = 'New Position' WHERE `title` = 'Новая должность';

-- -----------------------------------------------------------------------------
--  4. ПРЕДПРИЯТИЯ (enterprises.name — 16 стартовых предприятий)
-- -----------------------------------------------------------------------------
UPDATE `enterprises` SET `name` = 'Hunter Quarry Iron Mine' WHERE `id` = 1;
UPDATE `enterprises` SET `name` = 'Octane Springs Oil Field' WHERE `id` = 2;
UPDATE `enterprises` SET `name` = 'Angel Pine Logging Complex' WHERE `id` = 3;
UPDATE `enterprises` SET `name` = 'Flint County Grain Farm' WHERE `id` = 4;
UPDATE `enterprises` SET `name` = 'Green Palms Oil Refinery' WHERE `id` = 5;
UPDATE `enterprises` SET `name` = 'Ocean Docks Steel Mill' WHERE `id` = 6;
UPDATE `enterprises` SET `name` = 'Easter Basin Assembly Plant' WHERE `id` = 7;
UPDATE `enterprises` SET `name` = 'Idlewood 24/7 Supermarket' WHERE `id` = 8;
UPDATE `enterprises` SET `name` = 'Juniper Hill 24/7 Supermarket' WHERE `id` = 9;
UPDATE `enterprises` SET `name` = 'Las Venturas Creek Trading House' WHERE `id` = 10;
UPDATE `enterprises` SET `name` = 'Idlewood Gas Station' WHERE `id` = 11;
UPDATE `enterprises` SET `name` = 'Easter Basin Gas Station' WHERE `id` = 12;
UPDATE `enterprises` SET `name` = 'Emerald Isle Gas Station' WHERE `id` = 13;
UPDATE `enterprises` SET `name` = 'East Los Santos Chop Shop' WHERE `id` = 14;
UPDATE `enterprises` SET `name` = 'Doherty Underground Garage' WHERE `id` = 15;
UPDATE `enterprises` SET `name` = 'Redsands West Chop Shop' WHERE `id` = 16;

-- -----------------------------------------------------------------------------
--  5. СИСТЕМНАЯ РОЛЬ ROOT ADMINISTRATOR (admin_roles)
-- -----------------------------------------------------------------------------
UPDATE `admin_roles` SET `name` = 'Root Administrator' WHERE `is_root` = 1 OR `name` = 'Root-администратор';

COMMIT;

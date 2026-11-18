<img width="1997" height="2015" alt="SanAndreas" src="https://github.com/user-attachments/assets/aae9927c-ec9f-408d-bf56-abce1bdb595d" />

<div align="center">

**Hardcore Text-First Multiplayer Roleplay Sandbox on Native `open.mp`**  
*Libertarian Capitalism • Integer Physics • Dual-Layer Inventory • Dynamic RBAC*

[![Platform](https://img.shields.io/badge/Platform-open.mp%20v1.6.7%2B-1E293B?style=flat-square)](https://open.mp)
[![Language](https://img.shields.io/badge/Language-Pawn%20%2F%20C%2B%2B-0F766E?style=flat-square)](#)
[![Database](https://img.shields.io/badge/Database-MariaDB%2010.11%2B%20%2F%20MySQL%208.0-2563EB?style=flat-square)](#)
[![UI Language](https://img.shields.io/badge/Primary%20UI-English%20(CP1251%20Multilingual%20Chat)-4F46E5?style=flat-square)](#)
[![Architecture](https://img.shields.io/badge/Architecture-Modular%20Monolith%20%2F%20Server--Authoritative-059669?style=flat-square)](#)

</div>

---

## Overview

**San Andreas RP** is a server-authoritative, text-first roleplay sandbox built for **open.mp (v1.6.7+)** on Linux. Set in the State of San Andreas under a laissez-faire capitalist framework, the server replaces artificial script restrictions and "green zones" with **physical consequences, integer-based weight/volume physics, and a closed-loop Zero-Faucet economy**.

* **Primary Server & Official Language:** English is the primary language of the server UI, government agencies, courts, law enforcement, military, and official procedures — while players retain **full freedom of choice** to communicate in any language (including Cyrillic) in IC/OOC chats via native `Windows-1251` (`CP1251`) encoding.
* **No Artificial Faction Locks:** Any player can use handcuffs, radios, lockpicks, surgical kits, or explosives regardless of faction membership; the difference lies in supply chains, legal charters, and law enforcement consequences.

---

## Core Gameplay Systems

### 1. Polymorphic `Storage` & Dual-Layer Inventory
Every pocket, backpack, glovebox, vehicle trunk, enterprise warehouse, faction vault, corpse, and buried forest stash runs on a single polymorphic `Storage` engine governed by **exact mass (grams)** and **volume (milliliters)**:
* **Layer 1 (Outer Gear):** Hands, pockets, tactical vests, and backpacks. **100% dropped on death** as a lootable `CORPSE_LOOT` container (`TTL = 20 min`).
* **Layer 2 (Concealed Pockets):** Passports (`SSN`), bank cards, keys, phones, and equipped outfits (`ITEM_ID 91`). **Preserved on normal death (PK)** and accessible to law enforcement only via court warrant or arrest (`/search`).
* **Nested Containers (`NESTED_BAG`):** Backpacks and duffle bags are physical items with internal storage pools (`MAX_NESTING_DEPTH = 2`) whose total weight dynamically recalculates based on contents.
* **Encumbrance:** Exceeding personal weight capacity (`25 kg + MUSCLE * 35g + role bonus`) disables sprinting, increases weapon recoil, and accelerates hunger/thirst drain.

### 2. Weapon Physics Without Separate Ammo Items
* Individual "ammo box" items do not exist. Firearms are stored as physical instances (`item_def_id`) with an internal `ammo_count` and `durability`.
* **Dynamic Mass:** Every fired round reduces the weapon's physical mass in real time (e.g., an M4 weighs `3.4 kg` empty and `5.8 kg` loaded with `200` rounds of `5.56mm` at `12g` per round).
* **Weapon Jamming & Maintenance:** Firing degrades durability; below `30%`, weapons risk jamming mid-firefight and require field maintenance or gunsmith repair kits (`/unload`, `/combine`).

### 3. Zero-Faucet Economy, Ports & Logistics
* **Conservation of Matter & Capital:** No items or dollars spawn out of thin air (outside initial government `Seed Money`). Every bullet, plate, or vehicle part starts as raw ore, crude oil, timber, or grain extracted by players.
* **Enterprise-Driven Supply Chains:** Workers are paid per kilogram strictly from the enterprise's `reserve_usd`. Factory owners set buy/sell market orders based on live port quotes.
* **Global Trade Hubs (LS, SF, LV Ports):** Dynamic supply-and-demand pricing with a `12%` spread and automatic **`90 / 5 / 5`** export revenue split (`90%` enterprise owner, `5%` trucker logistics payout, `5%` state export tariff).
* **Multi-Currency & Money Laundering:** Barter with `USD`, `EUR`, and `CNY` cash bundles. Dirty cash (`DIRTY_FLAG`) is rejected by ATMs and must be laundered through cash-intensive businesses (car washes, bars, gas stations, casinos) at a `15–25%` tax rate — triggering FBI/Treasury anomaly alerts if daily turnover spikes `3x` above state average.

### 4. Zonal Trauma, PK / CK & Forensics
* **Server-Authoritative Damage:** Headshots (`3.5x` multiplier), limb fractures (arm hits force weapon drops; leg hits cause limping and disable jumping), venous vs. arterial bleeding (`90s` countdown requiring a tourniquet and surgery), and pain shock.
* **Physical Crime Scene Evidence:** Unsuppressed gunfire leaves serial-linked `BULLET_CASING` entities; broken vehicle windows without gloves leave `BROKEN_GLASS` and `BLOOD_DNA`; failed lockpicks leave `LOCKPICK_SCRATCH` markers collectible with a `Forensics Kit`.

### 5. Unified Organization Engine, 100-Level Wanted & Wiretapping
* **21 Permanent Core Factions + Custom Player Orgs:** Government, `LSPD`, `SFPD`, `LVPD`, `SASD`, `LSa`, `SFA`, `LV Army`, `FBI`, `CIA`, `ICE`, `EMS`, `PMC`, `Port Authority`, `SAN News`, and 6 canonical criminal syndicates (`Grove`, `Ballas`, `Vagos`, `Aztecas`, `Triads`, `LV Mafia`), plus player-created corporations and gangs.
* **Physical Faction Vaults (`ORG_VAULT`):** Faction treasuries store physical cash, weapons, and commodities that can be breached with satchel charges or lockpicks.
* **100-Level Wanted Scale & Active Warrant Decay:** `1 Wanted Level = 1 real hour` in `KPZ`, `State Prison`, or `Federal Supermax` (reducible via prison labor). Every `3,600s` of non-AFK active playtime automatically decays wanted level by `1`.
* **Telecom & Surveillance:** SSN-registered SIM cards vs. untraceable `Burner Phones`, tunable `100.0–999.9 MHz` walkie-talkies, and `FBI`/`CIA` wiretaps & frequency scanners.

### 6. 25 Starting Roles & 41-Skill Matrix
* Players start at `Level 1` (`Age = 17 + Level = 18`) and pick from **25 distinct starting archetypes** (from *Gutter Rat* and *Long-Haul Trucker* to *Disbarred Surgeon*, *1% Outlaw Biker*, *Ex-SWAT Breacher*, and *Spoiled Trust-Fund Kid*), each with custom citizenship (`CITIZEN` / `IMMIGRANT`), perks, debuffs, lore spawn points, and 41 native + custom skills (`0–1000`).

### 7. Dynamic RBAC Admin System (`/apanel`)
* Replaces hardcoded numeric admin levels with database-driven roles (`admin_roles`, `admin_role_permissions`, `admin_punishments`).
* Ships with a single immutable **`Root Administrator`** system role (`level = 100`, `is_root = 1`) capable of creating custom staff ranks, configuring granular permission matrices, managing online/offline admins, spectating (`/sp` with live HUD), spawning items/vehicles/keys, and auditing every privileged action in `audit_logs`.

---

## Technical Architecture

```text
Server/
├── components/                 # Native C++ plugins (mysql, streamer, Pawn.CMD, Pawn.RakNet, Pawn.Regex, bcrypt)
├── models/                     # Custom .dff / .txd assets
├── scriptfiles/                # Local caches & geo-zone definitions
├── sql/
│   ├── 001_schema.sql          # Core 22-table InnoDB relational schema
│   ├── 002_seed_data.sql       # 75+ items, craft recipes, 21 core factions, port quotes
│   └── 003_admin_rbac.sql      # Dynamic RBAC roles, permissions & punishments (Phase 10)
├── config.json                 # open.mp v1.6.7+ server configuration
└── gamemodes/
    ├── main.pwn                # Entry point & deterministic module include order
    └── modules/
        ├── core/               # mod_config, mod_database (Dirty-Flag), mod_utils, mod_audit, mod_anticheat
        ├── entities/           # mod_account, mod_character, mod_roles, mod_skills, mod_storage, mod_items, mod_vehicles, mod_properties
        ├── systems/            # mod_survival, mod_medical, mod_weapons, mod_crafting, mod_economy, mod_ports, mod_logistics, mod_banking, mod_organizations, mod_justice, mod_forensics, mod_telecom, mod_admin
        └── ui/                 # mod_dialogs, mod_commands, mod_hud, mod_admin_panel
```

### Engineering Highlights
* **Async MySQL Pool & `Dirty-Flag` Persistence:** 12-thread non-blocking `mysql_tquery` execution with session generation tokens (`gPlayerSessionToken`) to prevent slot-reuse race conditions, batched minute-tick `Dirty-Flag` flushes, and synchronous shutdown persistence (`DB_FlushAllDirtySync`).
* **Anti-Dupe Mutexes:** Transactional locking (`gStorageMutex`) across concurrent storage interactions.
* **Packet-Level Anti-Cheat (`Pawn.RakNet`):** Real-time interception of `OnFoot` (`207`), `InCar` (`200`), and `Aim` (`203`) packets to block weapon/ammo injection, teleportation, speedhacks, and NOP damage.

---

## Getting Started

### Prerequisites
* **OS:** Linux x86/x64 (Debian, Ubuntu, Arch/CachyOS, Fedora)
* **Server:** `omp-server` v1.6.7+
* **Database:** MariaDB 10.11+ or MySQL 8.0+
* **Compiler:** `pawncc` (`qawno`) with YSI-Includes (`y_hooks`, `y_iterate`, `y_timers`, `y_va`)

### 1. Database Setup
```bash
sudo mariadb -e "CREATE DATABASE san_andreas_rp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb san_andreas_rp < sql/001_schema.sql
sudo mariadb san_andreas_rp < sql/002_seed_data.sql
sudo mariadb san_andreas_rp < sql/003_admin_rbac.sql
```

### 2. Build & Run
1. Configure your MySQL credentials in your local `.env` / database config (`cp1251` client charset is enforced automatically on connect).
2. Compile the gamemode (`-O2 -d1`, preserving `Windows-1251` source encoding):
   ```bash
   ./build.sh
   ```
3. Launch the server:
   ```bash
   ./omp-server
   ```

### 3. Granting Root Administrator Access
After registering your account in-game, assign the system `Root Administrator` role in MariaDB:
```sql
UPDATE accounts
SET admin_role_id = (SELECT id FROM admin_roles WHERE is_root = 1 LIMIT 1)
WHERE username = 'Your_Name';
```
Use `/apanel` or `/ahelp` in-game to configure staff roles, spawn items/vehicles, and manage server systems.

---

## Project Documentation

* [`CONTEXT_OF_PROJECT.md`](CONTEXT_OF_PROJECT.md) — Full Game Design Document (GDD), item registry, 25 roles & 21 core factions.
* [`TECH_CONTEXT.MD`](TECH_CONTEXT.MD) — Relational database DDL, module contracts, formulas & RBAC specifications.
* [`ROADMAP.md`](ROADMAP.md) — Engineering implementation plan across Phases 0–10.
* [`AGENTS.MD`](AGENTS.MD) — Engineering standards, Pawn invariants & AI agent workflow rules.

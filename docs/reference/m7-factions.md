# M7 faction evidence (China, GLA, USA additions)

Status: **SOURCE/CONFIG EVIDENCE, NOT MEASURED** (2026-11-06). Read for the [M7 design](../superpowers/specs/2026-11-06-m7-factions-design.md). Values are config, not runtime measurements; the [parity harness](zero-hour-parity-harness.md) measures them at planning or per stop gate.

Sources: EA source `CnC_Generals_Zero_Hour` at `0a05454` (`GeneralsMD/Code/GameEngine/`); INI from the root `INIZH.big` (hash pinned in [installation](installation.md)); `PatchINI.big` only overrides `windowtransitions.ini` (menu animations), so no gameplay override. INI files have CRLF line endings. OpenRA at `9636b63eae` for the faction-model comparison. Per-unit stats (cost, HP, armor, weapon) not listed here are extracted at planning.

## How the reference games model factions

- **Zero Hour:** a faction is a `PlayerTemplate` (`playertemplate.ini`: `Side`, `StartingBuilding`, `StartingUnit0`, sciences). Each object carries `Side`, a `KindOf` flag set (`DOZER HARVESTER SALVAGER INFANTRY …`) and behaviour modules. What a builder or producer can make is its `CommandSet` plus `Prerequisites`; GLA has no power because `GLAWorkerCommandSet` lists no power plant. Game logic barely branches on side: only AI build lists (`Source/GameLogic/AI/AIPlayer.cpp:202`), stats, scripts and a debug spawner (`Source/GameLogic/System/GameLogic.cpp:3097`). Shared behaviour is reused: `ChinookAIUpdate : SupplyTruckAIUpdate`; `WorkerAIUpdate : DozerAIInterface, SupplyTruckAIInterface`; `TunnelContain` and `TransportContain` both derive from `OpenContain`.
- **OpenRA:** `FactionInfo` (`OpenRA.Game/Traits/World/Faction.cs`: name, internal name, side) plus `StartingUnits@…` per faction (`mods/ra/rules/world.yaml`); actors are trait compositions; faction-only items via `ProvidesPrerequisite` with `Factions:` and `~vehicles.soviet` prerequisites (needed there for captured buildings and sub-factions, which Wargrid does not have). The bot lists every faction's units and skips what it cannot build (`mods/ra/rules/ai.yaml` `UnitBuilderBotModule`).

## Start and structures (`factionbuilding.ini`, `commandset.ini`)

- Start: every faction gets its Command Center plus one builder (USA and China `…VehicleDozer`, GLA `GLAInfantryWorker`). Command Centers: $2000, 45 s, 5000 HP, no power; they train the builder.
- China Power Plant $1000, 10 s, +10 power, 1500 HP. GLA Supply Stash $1500, 10 s, 2000 HP, trains Workers. GLA Arms Dealer $2500, 15 s, 2000 HP. Patriot Battery $1000, 25 s, −3 power, 1000 HP. Gattling Cannon $1200, 25 s, −3 power, 1000 HP.
- Trained per building (CommandSet audit): USA barracks 5, war factory 8, airfield 4, supply center Chinook, command center Dozer; China barracks 4, war factory 9, airfield 2, supply center Supply Truck, command center Dozer; GLA barracks 7, arms dealer 11, supply stash and command center Worker.

## Construction and gathering

- USA and China Dozers: same `DozerAIUpdate` values (repair 2 %/s, bored after 5 s).
- GLA Worker (`glainfantry.ini`): infantry, $200, 3 s; `KindOf … INFANTRY SALVAGER DOZER HARVESTER`; `WorkerAIUpdate` with `MaxBoxes 1`, `SupplyWarehouseActionDelay 150` ms per box, repair 2 %/s.
- China Supply Truck (`chinavehicle.ini`): $600, 10 s, 300 HP, `MaxBoxes 4`, `SupplyWarehouseActionDelay 1000` ms per box, scan distance 700. USA Chinook: existing M3 collector.
- GLA rebuild holes: every GLA building has `RebuildHoleExposeDie` (Arms Dealer, Barracks, Black Market, Command Center, Palace, Scud Storm, Stinger Site, Supply Stash, Tunnel Network). `GLAHole` (`RebuildHoleBehavior`): spawns a `GLAInfantryWorker` after 20 s that rebuilds the building; the hole regains 0.5 % of its max health per second; tunnel hole 500 HP.

## Signature mechanics

- **Horde** (`HordeUpdate`): Red Guard, Tank Hunter, Battlemaster. Battlemaster: `Count 5` of the exact same type within `Radius 75`, allies only, recheck every 1000 ms, `RubOffRadius 150`, grants the `HORDE` weapon bonus. Bonus size and the Red Guard / Tank Hunter values: extract at planning.
- **Salvage** (`crate.ini`, `CreateCrateDie.cpp:96–168`, `SalvageCrateCollide.cpp`): a vehicle drops a `SalvageCrate` (100 %) when killed by a `SALVAGER` unit whose owner has `SCIENCE_GLA`; infantry and buildings drop none. The crate is visible to GLA only and lasts 30–35 s. Pickup by a `SALVAGER`: a `WEAPON_SALVAGER` not yet at `CRATEUPGRADE_TWO` gets its next weapon set (100 %); otherwise 25 % level-up, 75 % $25–75. Weapon salvagers: Scorpion, Technical (and other GLA vehicles); money salvagers: Rebel, RPG Trooper, Worker. Wargrid has no veterancy, so the level branch needs a decision.
- **Gattling ramp-up** (`weapon.ini`): Gattling Tank gun 15 damage, range 150, 400 ms; 2× rate after 2 shots on the same target, 3× after 6, lost after 1000 ms without firing. Gattling Cannon 10 damage, range 225, 250 ms; 2× after 1, 3× after 5, coast 2000 ms. Both have separate anti-air guns (out of scope, no air combat).
- **Containers:** Humvee `TransportContain Slots 5`, Technical 5 (`glavehicle.ini:4827`). Tunnel Network (`factionbuilding.ini`): $800, 15 s, needs Barracks, 1000 HP, own gun `TunnelNetworkGun` (15 small arms, range 175, 250 ms), spawns 2 `GLAInfantryTunnelDefender` once on completion, heals occupants to full in 5 s; one shared network per player, `MaxTunnelCapacity 10` (`gamedata.ini`).
- **RPG Trooper** is `GLAInfantryTunnelDefender` (barracks button `Command_ConstructGLAInfantryRPGTrooper`, `commandbutton.ini:3110`).
- **Rockets and shells** (for the instant-hit decision): Missile Defender, Tank Hunter, RPG Trooper range 175, projectile speed 600; Crusader, Battlemaster, Scorpion range 150, speed 400.
- **Junk Repair** (later): GLA vehicle `AutoHealBehavior` is triggered only by `Upgrade_GLAJunkRepair` (2 HP/s; upgrade $2000, 60 s).

## Rest of the roster (for the batches after M7)

After M7: 32 ground units (USA 9, China 9, GLA 14) and 6 aircraft (USA Raptor, Comanche, Aurora, Stealth Fighter; China MiG, Helix; GLA none). Stealth (`StealthUpdate`) on 10 of the 32 plus the Rebel camouflage upgrade; detectors include Dozers and the Worker. Artillery minimum / maximum range: Tomahawk 100 / 350, Inferno 50 / 300, Nuke Cannon 150 / 350, Scud 200 / 350, all travelling projectiles.

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

## Per-unit values extracted at planning (config, 2026-11-06)

Status: **SOURCE/CONFIG, NOT MEASURED.** Read from the root `INIZH.big` (hash pinned in [installation](installation.md)) and the EA source at `0a05454` (`GeneralsMD/Code/GameEngine/`). INI paths below are inside `data\ini\`. The defeat rule, ROF, heal and rub-off readings are interpretations of the source; the [parity harness](zero-hour-parity-harness.md) has not measured them.

### Scaling rule (from M6, `tools/check_reference.py`, `economy_definitions.gd`, `combat_definitions.gd`)

- 25 world units per cell; 30 ticks per second. Distances, speeds, accelerations, `MinTurnSpeed`, splash radius ÷ 25; BuildTime × 30; HP and damage × 1000; cost and power as-is; turn rate in °/s ÷ 30 per tick.
- Weapon delay `ceil(ms × 30 / 1000)` (`Weapon.cpp:407-408`). Exception: the Ranger rifle uses the measured 4/4/22 (commit `0730fe3`).
- Unit radius: cylinder `major / 25`, box `sqrt(major² + minor²) / 25`. Building footprints are Wargrid's own grid choice, not converted.

### Objects (cost / build seconds / HP / armor / vision / locomotor / geometry / weapons / other)

| Object (file:line) | Cost | Build s | HP | Armor | Vision | Locomotor (`locomotor.ini`) | Geometry | Weapon / other |
|---|---|---|---|---|---|---|---|---|
| AmericaVehicleDozer (`americavehicle.ini:1599`) | 1000 | 5 | 250 | DozerArmor | 200 | :3530 wheels 30 / 90 / 30 / 50 / 25 | BOX 15×10 | none; holds 5 |
| AmericaVehicleChinook (`americaair.ini:2108`) | 1200 | 10 | 300 | ChinookArmor | 300 | :2226 air 150 / 180 / 60 / 100 | BOX 20×6 | MaxBoxes 8, warehouse 1200 ms/box, center 2900 ms (2256-2259) |
| AmericaInfantryRanger (`americainfantry.ini:527`) | 225 | 5 | 180 | HumanArmor | 100 | BasicHuman :6 legs 20 / 500 / 100 / 100 | CYL 7 | RangerAdvancedCombatRifle |
| AmericaInfantryMissileDefender (`:1074`) | 300 | 5 | 100 | HumanArmor | 150 | MissileDefenderLoc :23 = BasicHuman | CYL 7 | MissileDefenderMissileWeapon |
| AmericaVehicleHumvee (`americavehicle.ini:3`) | 700 | 10 | 240 | HumveeArmor | 150 | :1848 wheels 60 / 180 / 1000 / 1000 / 20 | BOX 14×7 | HumveeGun; holds 5 infantry, 100 % damage to passengers, passengers fire (171-178) |
| AmericaTankCrusader (`:1371`) | 900 | 10 | 480 | TankArmor | 150 | :479 treads 30 / 180 / 1000 / 1000 | BOX 15×10 | CrusaderTankGun |
| AmericaPatriotBattery (`factionbuilding.ini:28472`) | 1000 | 25 | 1000 | BaseDefenseArmor | 360 | – | CYL 12 | Patriot Missile (+ assist, + air); POWERED, −3 power; no `MP_COUNT_FOR_VICTORY` |
| AmericaCommandCenter (`:166`) | 2000 | 45 | 5000 | StructureArmorTough | 300 | – | BOX 60×70 | none; `MP_COUNT_FOR_VICTORY` |
| ChinaVehicleDozer (`chinavehicle.ini:2116`) | 1000 | 5 | 250 | DozerArmor | 150 | :3562 treads 30 / 90 / 30 / 50 / 0 | BOX 17×10 | none; holds 5 |
| ChinaVehicleSupplyTruck (`:1938`) | 600 | 10 | 300 | TruckArmor | 150 | :1054 wheels 40 / 90 / 240 / 50 / 15 | BOX 17×7 | MaxBoxes 4, warehouse 1000 ms, center 400 ms, scan 700 (2051-2054) |
| ChinaInfantryRedguard (`chinainfantry.ini:3`) | 300 per **2** | 10 | 120 | HumanArmor | 100 | :193 25 / 500 / 100 / 150 | CYL 7 | RedguardMachineGun; Horde (321-330); `QuantityModifier` 2 (`factionbuilding.ini:23987`) |
| ChinaInfantryTankHunter (`:851`) | 300 | 5 | 100 | HumanArmor | 150 | MissileDefenderLoc | CYL 10 | ChinaInfantryTankHunterMissileLauncher; Horde (1034-1043) |
| ChinaTankBattleMaster (`chinavehicle.ini:3`) | 800 | 10 | 400 | TankArmor | 150 | :695 25 / 180 / 1000 / 1000 | BOX 13×9 | BattleMasterTankGun; Horde (113-122) |
| ChinaTankGattling (`:1701`) | 800 | 10 | 300 | AntiAirVehicle | 150 | :947 40 / 180 / 1000 / 1000 | BOX 15×10 | GattlingTankGun (+ air) |
| ChinaGattlingCannon (`factionbuilding.ini:30670`) | 1200 | 25 | 1000 | BaseDefenseArmor | 360 | – | BOX 8×8 | GattlingBuildingGun (+ air); POWERED, −3; no `MP_COUNT_FOR_VICTORY` |
| ChinaCommandCenter (`:2772`) | 2000 | 45 | 5000 | StructureArmorTough | 300 | – | BOX 60×63 | `MP_COUNT_FOR_VICTORY` |
| ChinaPowerPlant (`:17074`) | 1000 | 10 | 1500 | StructureArmor | 200 | – | BOX 27×34 | +10 power |
| ChinaSupplyCenter (`:20689`) | 1500 | 10 | 2000 | StructureArmor | 200 | – | BOX 52×47 | needs ChinaPowerPlant, −1 power; spawns 1 free truck |
| ChinaBarracks (`:23378`) | 500 | 10 | 1000 | StructureArmor | 200 | – | BOX 36×44 | no prerequisite |
| ChinaWarFactory (`:26807`) | 2000 | 15 | 2000 | StructureArmor | 200 | – | BOX 57×61 | needs ChinaSupplyCenter, −1 power |
| GLAInfantryWorker (`glainfantry.ini:3490`) | 200 | 3 | 100 | HumanArmor | 100 | FastHuman :58 25 / 500 / 100 / 100 | CYL 10 | MaxBoxes 1, both delays 150 ms, scan 700, repair 2 %/s (3756-3764); SALVAGER DOZER HARVESTER |
| GLAInfantryRebel (`:3`) | 150 | 5 | 120 | HumanArmor | 150 | BasicHuman | CYL 10 | GLARebelMachineGun; SALVAGER |
| GLAInfantryTunnelDefender (`:718`) (RPG Trooper) | 300 | 5 | 100 | HumanArmor | 150 | MissileDefenderLoc | CYL 10 | TunnelDefenderRocketWeapon; SALVAGER |
| GLAVehicleTechnical (`glavehicle.ini:4407`, chassis `:4440`) | 500 | 5 | 180 | TruckArmor | 150 | :2082 wheels 90 / 180 / 100 / 50 / 20 | BOX 18×9 | MG / Cannon / RPG by salvage tier; holds 5, 10 % damage to passengers (4827-4830); WEAPON_SALVAGER |
| GLATankScorpion (`:3`) | 600 | 7 | 370 | TankArmor | 125 | :552 40 / 180 / 1000 / 1000 | BOX 14×9 | ScorpionTankGun / PlusOne; WEAPON_SALVAGER |
| GLATunnelNetwork (`factionbuilding.ini:14663`) | 800 | 15 | 1000 | StructureArmor | 200 | – | CYL 25 | TunnelNetworkGun; needs GLABarracks; no `MP_COUNT_FOR_VICTORY` |
| GLACommandCenter (`:1336`) | 2000 | 45 | 5000 | StructureArmorTough | 300 | – | BOX 65×65 | `MP_COUNT_FOR_VICTORY` |
| GLASupplyStash (`:19355`) | 1500 | 10 | 2000 | StructureArmor | 200 | – | BOX 36×35 | spawns 1 free Worker |
| GLABarracks (`:21987`) | 500 | 10 | 1000 | StructureArmor | 200 | – | BOX 42×52 | prerequisite commented out (22567-22569) |
| GLAArmsDealer (`:25030`) | 2500 | 15 | 2000 | StructureArmor | 200 | – | BOX 40×62 | needs GLASupplyStash |
| GLAHole (`:12`) | – | – | 500 (set by the dead building) | StructureArmor | 50 | – | copies the dead building | REBUILD_HOLE STRUCTURE `MP_COUNT_FOR_VICTORY` |

Locomotor columns: speed / turn °/s / acceleration / braking / `MinTurnSpeed`, in Zero Hour units. USA reference rows (`factionbuilding.ini`): Barracks `:21337` $600, 10 s, 1000 HP; War Factory `:24041` $2000, 15 s, 2000 HP, −1 power, needs Supply Center; Supply Center `:17996` $2000, 10 s, 2000 HP, −1, needs Power Plant; Power Plant `:3858` $800, 10 s, 800 HP, +5.

### Weapons (`weapon.ini` line)

All have `RadiusDamageAffects = ALLIES ENEMIES NEUTRALS`. `PLAYER_UPGRADE DAMAGE 125%` entries are out of scope.

| Weapon | Damage | Type | Range | Delay ms | Clip / reload ms | Radius | Other |
|---|---|---|---|---|---|---|---|
| RangerAdvancedCombatRifle :729 | 5 | SMALL_ARMS | 100 | 100 | 3 / 700 | 0 | instant; measured 4/4/22 ticks |
| MissileDefenderMissileWeapon :770 | 40 | INFANTRY_MISSILE | 175 | 1000 | 0 | 5 | scatter vs infantry 10, speed 600 |
| HumveeGun :601 | 10 | COMANCHE_VULCAN | 150 | 200 | 0 | 0 | speed 600 |
| CrusaderTankGun :325 | 60 | ARMOR_PIERCING | 150 | 2000 | 0 | 5 | scatter vs infantry 10, speed 400 |
| PatriotMissileWeapon :1939 | 30 | EXPLOSION | 225 | 250 | 4 / 2000 | 5 | AntiGround, assist range 200, scatter vs infantry 10 |
| PatriotMissileAssistWeapon :1996 | 25 | EXPLOSION | 450 | 250 | 4 / 1000 | 5 | fires on targets another Patriot marked |
| RedguardMachineGun :1037 | 15 | SMALL_ARMS | 100 | 1000 | 0 | 0 | instant |
| ChinaInfantryTankHunterMissileLauncher :2454 | 40 | INFANTRY_MISSILE | 175 | 1000 | 0 | 5 | min range 5, scatter 10, speed 600 |
| BattleMasterTankGun :296 | 60 | ARMOR_PIERCING | 150 | 2000 | 0 | 5 | scatter 10, speed 400 |
| GattlingTankGun :1114 | 15 | GATTLING | 150 | 400 | 0 | 0 | ContinuousFire One 2 / Two 6 / Coast 1000; 200 % / 300 % rate |
| GattlingBuildingGun :1168 | 10 | GATTLING | 225 | 250 | 0 | 0 | ContinuousFire One 1 / Two 5 / Coast 2000; 200 % / 300 % rate |
| GLARebelMachineGun :976 | 5 | SMALL_ARMS | 100 | 100 | 3 / 700 | 0 | same as the Ranger rifle |
| TunnelDefenderRocketWeapon :2021 | 40 | INFANTRY_MISSILE | 175 | 1000 | 0 | 5 | min range 5, speed 600 |
| TechnicalMachineGunWeapon :2576 | 10 | GATTLING | 150 | 200 | 0 | 0 | instant |
| TechnicalCannonWeapon :504 | 45 | GATTLING | 150 | 1000 | 0 | 25 | scatter 10, speed 300 |
| TechnicalRPGWeapon :2595 | 50 | EXPLOSION | 150 | 1000 | 0 | 5 | min range 5, no speed field |
| ScorpionTankGun :102 | 20 | ARMOR_PIERCING | 150 | 1000 | 0 | 5 | speed 400 |
| ScorpionTankGunPlusOne :164 | 25 | ARMOR_PIERCING | 150 | 1000 | 0 | 5 | speed 400 |
| Scorpion missile weapons :133 / :195 | 100 (+80 secondary, radius 25) | EXPLOSION | 150 | 200 | 1 or 2 / 15000 | 5 | min range 40; upgrade only, out of scope |
| TunnelNetworkGun :551 | 15 | SMALL_ARMS | 175 | 250 | 0 | 0 | speed 600 |

### Armor (`armor.ini`; percent per damage type, default 100)

| Armor | SMALL_ARMS | ARMOR_PIERCING | INFANTRY_MISSILE | GATTLING | EXPLOSION | COMANCHE_VULCAN |
|---|---|---|---|---|---|---|
| HumanArmor :48 | 100 | 10 | 10 | 100 | 100 | 100 |
| TankArmor :124 | 25 | 100 | 100 | 10 | 100 | 25 |
| DozerArmor :145 | 25 | 100 | 100 | 10 | 100 | 25 |
| TruckArmor :188 | 50 | 100 | 50 | 50 | 100 | 50 |
| AntiAirVehicle :208 | 50 | 100 | 50 | 50 | 100 | 50 |
| HumveeArmor :251 | 50 | 100 | 50 | 50 | 100 | 50 |
| ChinookArmor :513 (DEFAULT 50) | 50 | 50 | 25 | 50 | 50 | 50 |
| StructureArmor :562 | 50 | 100 | 50 | 10 | 100 | 50 |
| StructureArmorTough :587 | 50 | 100 | 50 | 10 | 80 | 50 |
| BaseDefenseArmor :664 | 50 | 100 | 25 | 25 | 100 | 50 |

Damage type names match case-insensitively (`Source/Common/INI/INI.cpp:1633`).

### Findings

- **Defeat rule.** `GameLogic.cpp:1630` sets `VICTORY_NOBUILDINGS` unconditionally. `hasSinglePlayerBeenDefeated` (`VictoryConditions.cpp:274-305`) then only runs `Team::hasAnyBuildings(MP_COUNT_FOR_VICTORY)` (`Source/Common/RTS/Team.cpp:1711-1726`), which adds STRUCTURE to the mask and needs both bits (`BitFlags.h:247`). A player survives while one living, non-destroyed object has STRUCTURE and `MP_COUNT_FOR_VICTORY`; a foundation counts. Units never count, so contained units are irrelevant. On defeat `killPlayer` empties containers and kills the rest (`Player.cpp:2055+`). Counting: all Command Centers, power plant, supply center, barracks, war factory, GLA Supply Stash, Barracks, Arms Dealer, and `GLAHole` with all reskins (including `GLAHoleTunnelNetwork`). Not counting: Patriot, Gattling Cannon, Tunnel Network. A hole counts while hidden during its rebuild.
- **Ground docking** (`DockUpdate.cpp`, `AIDock.cpp`, `SupplyWarehouseDockUpdate.cpp`, `SupplyCenterDockUpdate.cpp`).
  - One active docker per dock (`m_activeDocker`, `DockUpdate.h:150`).
  - With `NumberApproachPositions -1` (ChinaSupplyCenter, GLASupplyStash, SupplyDock) the queue has no bones: each approach spot is the dock centre plus a unit vector toward the collector times half the major radius, then `findPositionAround` (`DockUpdate.cpp:446-487`). Waiting units hold their spot and move up when the slot ahead frees (`DockUpdate.cpp:187-232`). `AllowsPassthrough No` for those three.
  - Timing (`AIDock.cpp:574-636`): the collector waits its action delay before every `action()`. A warehouse gives 1 box per call, and the call after it is full ends the dock, so a full load takes (MaxBoxes + 1) × delay: truck 5 × 1000 ms, Worker 2 × 150 ms. A center deposits everything after one delay (truck 400 ms, Worker 150 ms). `ValuePerSupplyBox = 75` (`gamedata.ini:248`).
  - `SupplyWarehouse` `NumberApproachPositions 9`, 400 boxes (`civilianbuilding.ini:404-406`); `SupplyDock` 400 boxes (`:502-512`); `SupplyPile` 5 positions, 150 boxes (`:552`).
- **Tunnel network** (`TunnelTracker.cpp`, `TunnelContain.cpp`, `SpawnBehavior.cpp`).
  - When the last tunnel dies or is sold, occupants are deleted with `destroyObject`, no death effects (`TunnelTracker.cpp:211-247`). With another tunnel left they move to the first remaining one.
  - One shared list per player, `MaxTunnelCapacity 10` (`gamedata.ini:268`). Every non-aircraft unit may enter, vehicles included (`TunnelTracker.cpp:156-175`).
  - Heal: max HP ÷ 150 frames per occupant (`TimeForFullHeal 5000`, `factionbuilding.ini:15093`; `TunnelTracker.cpp:249-297`). Every tunnel's `update()` calls the heal (`TunnelContain.cpp:465-483`), so the rate may scale with the tunnel count (reading, not measured).
  - Two `GLAInfantryTunnelDefender` spawn once, after construction, never for a rebuild from a hole (`factionbuilding.ini:15104-15110`; `SpawnBehavior.cpp:826-845`).
- **Salvage** (`crate.ini:119-124,185,199-211`; `CreateCrateDie.cpp:174-229`; `SalvageCrateCollide.cpp:75-120`).
  - Every roster vehicle drops it when killed by a SALVAGER whose owner has `SCIENCE_GLA`. The crate falls within 5 units of the wreck (else 125), belongs to no player, is visible to GLA only, and lives 30000–35000 ms.
  - Pickup needs `SCIENCE_GLA`. A weapon salvager below `CRATEUPGRADE_TWO` takes its next weapon set (100 %, no roll). Otherwise a trainable unit below Heroic has a 25 % chance of a level, else $25–75. The Worker is not trainable, so it always gets money.
  - Technical: MG → TechnicalCannonWeapon → TechnicalRPGWeapon (`glavehicle.ini:4690-4700`). Scorpion without the rocket upgrade: ScorpionTankGun → PlusOne at tier one, no further change at tier two (`:110-138`).
- **Rebuild hole** (`factionbuilding.ini:12-161`; `RebuildHoleExposeDie.cpp:132-189`; `RebuildHoleBehavior.cpp:188-339`; `WorkerAIUpdate.cpp:396-410`).
  - `WorkerRespawnDelay 20000` ms, `HoleHealthRegen%PerSecond 0.5`; every building's `HoleMaxHealth` is 500. The hole appears only if the building was finished and its owner is still active.
  - After 600 frames an unselectable Worker spawns and rebuilds for free; if it or the half-built building dies the timer restarts. When done, hole and Worker are deleted.
- **Horde** (`HordeUpdate.cpp:86-112,259-345`; `gamedata.ini:319-320`). A member needs at least Count − 1 others with a HordeUpdate and matching KindOf within Radius (edge to edge). Infantry re-check every UpdateRate; vehicles when more than UpdateRate frames have passed (every 31). Bonus `HORDE RATE_OF_FIRE 150%`; `NATIONALISM 125%` needs an upgrade (out of scope). Delay = floor(frames ÷ bonus) (`Weapon.cpp:499-514`). Red Guard and Tank Hunter: Count 5, Radius 30, KindOf INFANTRY, ExactMatch No, so they count toward each other. Battlemaster: Count 5, Radius 75, VEHICLE, ExactMatch Yes.
- **Gattling ramp-up** (`FiringTracker.cpp:110-160`). The fast steps start when consecutive shots are greater than ContinuousFireOne or Two. A target switch within the coast time keeps the count. Cool-down starts at the next possible shot plus the coast.
- **Command Centers** have no WeaponSet and do not fire. They train Dozers ($1000, 5 s) and Workers ($200, 3 s). Starts: `playertemplate.ini:46-129`.

### Gate 2 planning findings (2026-11-06)

Status: **SOURCE/CONFIG, NOT MEASURED.** EA source `0a05454` (paths under `GeneralsMD/Code/GameEngine/Source`); INI decoded from the pinned root `INIZH.big` with `tools/check_reference.py` `load_archive` (scratch dump, not tracked).

- **Horde cadence** (`GameLogic/Object/Update/HordeUpdate.cpp:170-171,277,344`): the first update wakes `GameLogicRandomValue(1, UpdateRate)` frames after creation. Infantry re-check every `UpdateRate` (30 frames); vehicles run every frame but re-check only when `frame > last + UpdateRate`, so every 31 frames.
- **Horde filter** (`HordeUpdate.cpp:86-112`): the other object needs its own HordeUpdate, the KindOf mask, the exact template when `ExactMatch`, `ALLIES` relationship, and the same on/off-map state. Range is `Radius` from the bounding sphere (edge to edge).
- **Rub-off** (`HordeUpdate.cpp:290-315`): a unit with fewer than `Count − 1` qualifying neighbours is still in the horde if one of the neighbours found inside `Radius` is a true member and its centre lies within `RubOffRadius`. INI: Red Guard and Tank Hunter `RubOffRadius 60`, `Radius 30`; Battlemaster `150` and `75`. Each `Radius` plus both bounding radii stays below the `RubOffRadius` (Red Guard 44, Tank Hunter 50, Battlemaster about 107), so the rule comes down to "a true member among the counted neighbours".
- **Rate-of-fire bonus** (`GameLogic/Object/Weapon.cpp:499-522`): both the shot delay and the clip reload are `floor(frames / bonus)`. `gamedata.ini:319` `HORDE RATE_OF_FIRE 150%`. When a bonus condition changes, `Object::setWeaponBonusCondition` (`Object.cpp:4674-4684`) calls `onWeaponBonusChange` (`Weapon.cpp:1955-1985`). If the weapon is between shots or reloading, that call restarts the wait from the current frame with the new delay.
- **Gattling ramp** (`GameLogic/Object/FiringTracker.cpp:84-160,256-346`): `shotFired` runs after the shot's delay is set.
  - It adds 1 to the shot count on the same target, or on a new target before the cool-down frame; otherwise the count resets to 1.
  - It sets the cool-down frame to the possible next shot frame (old rate) plus the coast.
  - It then changes level: none to MEAN when count > One; MEAN to FAST when count > Two; MEAN back to none when count < One; FAST back to none when count < Two. Every drop goes straight to none and resets the count and the target.
  - The level change restarts the current delay (see the bonus item above), so the shot that crosses a threshold already waits the faster delay.
  - Once the frame passes the cool-down frame, `update` cools down.
  - INI `weapon.ini`: `GattlingTankGun` `CONTINUOUS_FIRE_MEAN RATE_OF_FIRE 200%`, `CONTINUOUS_FIRE_FAST 300%`, not cumulative (the INI comment says so); `GattlingBuildingGun` the same. This closes the FiringTracker gap below.
- **Full load** (`GameLogic/AI/AIDock.cpp:574-636`, `GameLogic/Object/Update/DockUpdate/SupplyWarehouseDockUpdate.cpp:93-136`): the collector waits its delay before every `action()`, and the action fails once the collector is full or the pile is empty, so a load takes (boxes taken + 1) × delay. This confirms the earlier reading. M3 departs from it on purpose for the Chinook ([M3 evidence](m3-economy.md), "M3 intentionally departs at capacity").
- **Boneless dock positions** (`GameLogic/Object/Update/DockUpdate/DockUpdate.cpp:446-487`): the spot is the dock centre plus the unit vector toward the collector times half the major radius, then `findPositionAround` up to 100 units, reachable for that collector. `ChinaSupplyCenter`, `SupplyDock` and `SupplyPileSmall` are boneless (`NumberApproachPositions = -1`); `SupplyWarehouse` has 9 bones, `SupplyPile` 5.
- **China INI rows** (`object/factionbuilding.ini`, `object/chinavehicle.ini`, `object/chinainfantry.ini`, `locomotor.ini`, `weapon.ini`):
  - Barracks `EnergyProduction 0`, no prerequisite. Gattling Cannon prerequisite ChinaPowerPlant, idle scan 250 / 250 ms.
  - Locomotors (speed / turn / accel / brake / min turn): SupplyTruck 40 / 90 / 240 / 50 / 15; Redguard 25 / 500 / 100 / 150 / 0; GattlingTank 40 / 180 / 1000 / 1000 / 0; BattleMaster 25 / 180 / 1000 / 1000 / 0; ChinaVehicleDozer 30 / 90 / 30 / 50 / 0.
  - Weapons: `GattlingTankGun` delay 400 ms, `GattlingBuildingGun` 250 ms. `ChinaInfantryTankHunterMissileLauncher` equals the Missile Defender weapon apart from `MinimumAttackRange 5` (out of scope). `BattleMasterTankGun` equals `CrusaderTankGun`.
  - Armor: `TruckArmor` and `AntiAirVehicle` equal `HumveeArmor` in every listed column.

### Gaps

- ~~Whether FiringTracker runs before or after the next delay is computed~~: closed above (gate 2 planning).
- Not read: OpenContain enter and exit details, turret behaviour, the CommandSet lists (listed above in the audit), the low-power effect on POWERED defences beyond the flag.
- `TechnicalRPGWeapon` has no `WeaponSpeed`; the Patriot's `WeaponSpeed 1` defers to its missile locomotor.

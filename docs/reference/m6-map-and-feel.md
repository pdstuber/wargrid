# M6: map format, terrain, range, splash, locomotor and Chinook evidence

Status: **SOURCE READ (level 0), 2026-11-05; INI and map read in M6 Task 1 the same day.** Read-only research for M6 planning; nothing here changes a Wargrid value by itself. Decisions live in the [M6 design](../superpowers/specs/2026-11-05-m6-teams-full-map-design.md).

Sources:
- Zero Hour source fork `../GeneralsGameCode-macOS` at `eb595cfc9` (branch `wargrid-parity`); paths below are relative to it. Not diffed against upstream `../GeneralsGameCode`.
- EA map sources `~/projects/CnC_Modding_Support` at `3aad8e4` (GPL v3 with EA additional terms, `LICENSE.md`): `Zero Hour/Maps/official/Twilight Flame/Twilight Flame.map` (400,412 bytes) and `.tga` preview.
- Retail root `INIZH.big` (pinned hash) read in M6 Task 1 with `tools/check_reference.py` `load_archive`; values with file and block are in the [M6 Values table](m6-verification.md#values-table).
- Measured values come from the [parity spike](zero-hour-parity-spike.md) (source build, level 2).

## Map file format

- Container: magic `EAR\0`, int32 LE uncompressed size at +4, RefPack stream at +8 (`Core/Libraries/Source/Compression/CompressionManager.cpp` 125, 220–227, 301–305). Decoder: `Core/Libraries/Source/Compression/EAC/refdecode.cpp` 73–183. Twilight Flame header bytes `45 41 52 00 4e b5 3e 00 10 fb …`: uncompressed 4,109,646 bytes.
- Chunk file (`GeneralsMD/Code/GameEngine/Source/Common/System/DataChunk.cpp`): TOC `CkMp`, int32 count, per entry `uint8 len, name, uint32 id` (541–575); chunk header `uint32 id, uint16 version, int32 size` (731–749); ASCII string = uint16 len + bytes, Unicode = uint16 len + UTF-16 (962–978); Dict = uint16 count, per pair `int32 keyAndType` (low byte type BOOL/INT/REAL/ASCII/UNICODE, `>>8` TOC name id) (917–958, `Include/Common/Dict.h` 74–78).
- Chunks (`Core/GameEngineDevice/Source/W3DDevice/GameClient/WorldHeightMap.cpp` 498–512): `HeightMapData`, `BlendTileData`, `WorldInfo`, `ObjectsList`, `PolygonTriggers`, `SidesList`, `GlobalLighting`.
- `HeightMapData` (857–909): width, height, border size (v≥3), boundaries (v≥4), then w×h bytes row-major. `MAP_XY_FACTOR` = 10 world units per sample, `MAP_HEIGHT_SCALE` = 10/16 = 0.625 units per byte (`Core/GameEngine/Include/Common/MapObject.h` 57–58).
- Playable area: world (0,0) is the inner border corner; extent `0 … boundary × 10` (`GeneralsMD/Code/GameEngineDevice/Source/W3DDevice/GameLogic/W3DTerrainLogic.cpp` 178–196; `BaseHeightMap.cpp` 899–900).
- `ObjectsList` (`WorldHeightMap.cpp` 1218–1275): per object `float x, y, z, angle; int32 flags; template name; Dict`. Waypoints carry dict INT `waypointID` and `waypointName`; start positions are `Player_N_Start`, 1-based (`GeneralsMD/Code/GameEngine/Source/Common/INI/INIMapCache.cpp` 177).
- `PolygonTriggers` (`GeneralsMD/Code/GameEngine/Source/GameLogic/Map/PolygonTrigger.cpp` 135+): water areas carry `isWater`.
- No existing tool dumps a map to text; `Core/Tools/Compress` only decompresses.

## Terrain passability

- Pathfinder cell = 10 units (`Core/GameEngine/Include/GameLogic/AIPathfind.h` 491). `classifyMapCell` (`Core/GameEngine/Source/GameLogic/AI/AIPathfind.cpp` 4696–4728): CLIFF from the cell's cliff bit, WATER if any corner is under water, OBSTACLE only from objects; 4804–4855 dilate cliffs by one cell and add a "pinched" ring.
- **Cliff bits are painted**: for `BlendTileData` v≥7 they are read from the file (`WorldHeightMap.cpp` 1074–1086); only older files derive them from heights with `maxZ − minZ > 9.8` over the 4 corners (59, 2289–2305). Deriving cliffs from heights alone may not match the game.
- **`BlendTileData` layout** (`WorldHeightMap.cpp` 1038–1089): int32 `dataSize` (= w × h), then int16 arrays of `dataSize` each: tiles, blend tiles, extra blend tiles (v≥6), cliff-info indices (v≥5); then the cliff bits, `h` rows of `byteWidth` bytes, cell (x, y) = bit `x & 7` of byte `y × byteWidth + (x >> 3)` (`getCliffState`, 700–706). `byteWidth` = `(w + 1) / 8` in v7 (a known wrong length) and `(w + 7) / 8` in v8. Bit (x, y) is the sample cell between samples x..x+1, y..y+1; world (wx, wy) maps to sample cell (wx/10 + border, wy/10 + border) (`BaseHeightMap.cpp` 1247–1260). Twilight Flame is v8, 630 wide, 79 bytes per row.
- Water comes from water polygon triggers, not from heights (`GeneralsMD/Code/GameEngine/Source/GameLogic/Map/TerrainLogic.cpp` 2135–2160). Twilight Flame has 17 polygon triggers and none is water or river.
- Not converted, by class (M6 Task 1 decode): 320 trees, 7 rock clusters and 36 small rocks, 4 `KandaharBridge`, 8 `TechOilDerrick`, `TechOilRefinery`, `TechReinforcementPad`, `QuonsetHut01`, 2 `WoodTower`, 18 `DirtRoad`, 141 ambient sound objects. Fidelity gap: whether the rock clusters and civilian buildings block a route in Zero Hour was not checked; at the 50 % rule all open cells form one component without them and without the bridges.

## Attack range (edge-to-edge)

- `ATTACK_RANGE_CALC_TYPE = FROM_BOUNDINGSPHERE_2D` (`GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Weapon.cpp` 79–83); `getAttackRange` = `AttackRange × bonus − 2.5` (454–463); distance = `max(0, centre distance − rA − rB)` (`PartitionManager.cpp` 806–853); bounding radius = `majorRadius` for sphere/cylinder, `√(major² + minor²)` for a box (`Common/System/Geometry.cpp` 489–512).
- Formula: fire when `centre distance − rA − rB ≤ AttackRange − 2.5`.
- **Matches the measured maxima with the real geometry** (Task 1): Ranger CYLINDER r 7, Dozer and Crusader BOX 15 × 10 (bounding radius 18.03). Ranger vs Dozer 97.5 + 7 + 18.03 = 122.5 (measured 122); Crusader vs Dozer 147.5 + 18.03 + 18.03 = 183.6 (measured 183).

## Splash

- `dealDamageInternal` (`Weapon.cpp` 1327+): radius = max(primary, secondary); victims by bounding-sphere distance (90); **step function, no falloff**: inside `PrimaryDamageRadius` → `PrimaryDamage`, else `SecondaryDamage` (1524).
- `RadiusDamageAffects` defaults to `ALLIES|ENEMIES|NEUTRALS` (211, 290): by default splash hits own units. The primary victim ignores the mask (1404).
- `CrusaderTankGun` (INI, Task 1): `PrimaryDamage 60`, `PrimaryDamageRadius 5`, no secondary fields (defaults 0), `RadiusDamageAffects = ALLIES ENEMIES NEUTRALS`, `ScatterRadiusVsInfantry = 10`. Measured: 9 splash hits of 6 HP on neighbours 15 units apart.
- **Scatter explains the measured splash.** Against infantry the weapon adds `ScatterRadiusVsInfantry` to its scatter radius, picks a random distance 0…radius and a random angle, and launches the shell at that ground point instead of at the unit (`Weapon.cpp` 959–1001, 1133–1136). The detonation then damages everything whose bounding sphere is within 5 units of the point (`DAMAGE_RANGE_CALC_TYPE = FROM_BOUNDINGSPHERE_3D`, 90). My arithmetic, 3D (ground impact to the victim's centre at half its height): the aimed Ranger is always inside (√(10² + 6.5²) − 7 ≈ 4.93 ≤ 5, margin 0.07), a neighbour 15 units away only when the shell lands towards it. Without scatter, a 5-unit radius reaches only victims whose centre is within about 10 units (infantry) or 23 units (BOX 15 × 10) of the target's centre.

## Locomotor

- Fields `Speed`, `TurnRate`, `Acceleration`, `Braking`, `MinSpeed`, `MinTurnSpeed` (`GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Locomotor.cpp` 441–451), converted per frame; turning clamps to `TurnRate` per frame (2127–2203).
- Treads (1158–1269): `goalSpeed = (1 − min(|angle error| / 45°, 1)) × desired`, so at ≥ 45° off-heading a tank turns in place; inside 2 cells of the goal with > 2.25° error it uses 0.6 × speed; acceleration and braking capped to reach goal speed exactly.
- Wheels (1272+): cannot turn in place; turn speed `max(MinTurnSpeed, maxSpeed/4)` when error > 9°; reverse/3-point-turn logic (1306–1327). Measured Dozer "turns while driving".
- Legs (1608–1701, Task 1): turns toward the goal at `TurnRate` (`locoUpdate_moveTowardsAngle`), goal speed `(1 − min(|angle error| / 45°, 1)) × desired` (same rule as treads, without treads' 0.6 near-goal slowdown); inside `calcSlowDownDist` (`(v − MinSpeed)² / (2 × Braking) × 1.05`, 81–92) of the goal it brakes to `MinSpeed`; acceleration and braking capped to reach goal speed exactly. Optional wander offset when `WanderWidthFactor ≠ 0`. Measured: Ranger 180° turn then move, 11 frames.
- Order to first movement: command processed, path queued and serviced in the same frame's AI update (`GameLogic.cpp` ~3790, 3881; `AIStates.cpp` 1780–1786); source supports 1–2 frames, measured 3 frames. Re-path within 3 frames delays the next path request by 1 s (`AIUpdate.cpp` 500–503). Network run-ahead not checked.

## Chinook supply scenario (why no money arrived)

Ranked candidates, none tested:
1. **Supply centre never registered.** `SupplyCenterCreate` registers in `onBuildComplete()` only (`GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Create/SupplyCenterCreate.cpp` 59–77); map load, starting buildings and dozers call it (`GameLogic.cpp` 527, 1964, 3636), a raw harness spawn does not. Most likely, since the harness spawns `AmericaSupplyCenter` directly.
2. Truck stays IDLE unless forced into WANTING (`SupplyTruckAIUpdate.cpp` 402–409; set by `SupplyCenterProductionExitUpdate.cpp` 130, `Player.cpp` 2356, `SupplyWarehouseDockUpdate.cpp` 160).
3. Centre and Chinook need the exact same controlling player (`Common/RTS/ActionManager.cpp` 243–247).
4. Under construction, sold or dead blocks transfer (215–226).
5. Chinook carrying passengers is unavailable (`ChinookAIUpdate.cpp` 1016–1026).
6. Warehouse boxes from INI `StartingBoxes` (unread) or script (`SupplyWarehouseDockUpdate.cpp` 58, 72, 173).
7. Dock bones need a drawable (`DockUpdate.cpp` 492–538).
8. Human player: dock must not be shrouded (`ActionManager.cpp` 268–275).

Deposit: `SupplyCenterDockUpdate::action` (101–126), box value `m_baseValuePerSupplyBox` default 100 (`GlobalData.cpp` 785), overridable by GameData `ValuePerSupplyBox` (unread).

## Not checked

SidesList teams, start-unit placement at game start, whether rock clusters or civilian buildings block Zero Hour routes on Twilight Flame, network run-ahead, upstream diffs. Read in M6 Task 1: Legs locomotor, `BlendTileData` layout, Twilight Flame template names, border and boundary (see the [verification file](m6-verification.md)).

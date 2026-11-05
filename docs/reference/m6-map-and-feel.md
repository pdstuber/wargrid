# M6: map format, terrain, range, splash, locomotor and Chinook evidence

Status: **SOURCE READ (level 0), 2026-11-05.** Read-only research for M6 planning; nothing here changes a Wargrid value by itself. Decisions live in the [M6 design](../superpowers/specs/2026-11-05-m6-teams-full-map-design.md).

Sources:
- Zero Hour source fork `../GeneralsGameCode-macOS` at `eb595cfc9` (branch `wargrid-parity`); paths below are relative to it. Not diffed against upstream `../GeneralsGameCode`.
- EA map sources `~/projects/CnC_Modding_Support` at `3aad8e4` (GPL v3 with EA additional terms, `LICENSE.md`): `Zero Hour/Maps/official/Twilight Flame/Twilight Flame.map` (400,412 bytes) and `.tga` preview.
- Retail INI (`INIZH.big`) is **not** read here; every INI field named below is unread.
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
- Water comes from water polygon triggers, not from heights (`GeneralsMD/Code/GameEngine/Source/GameLogic/Map/TerrainLogic.cpp` 2135–2160).

## Attack range (edge-to-edge)

- `ATTACK_RANGE_CALC_TYPE = FROM_BOUNDINGSPHERE_2D` (`GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Weapon.cpp` 79–83); `getAttackRange` = `AttackRange × bonus − 2.5` (454–463); distance = `max(0, centre distance − rA − rB)` (`PartitionManager.cpp` 806–853); bounding radius = `majorRadius` for sphere/cylinder, `√(major² + minor²)` for a box (`Common/System/Geometry.cpp` 489–512).
- Formula: fire when `centre distance − rA − rB ≤ AttackRange − 2.5`.
- **Consistent with the measured maxima (my arithmetic, geometry unread):** Ranger 122 = 100 − 2.5 + 7 + 17.5 and Crusader 183 = 150 − 2.5 + 18 + 17.5, if the Dozer box is about 15 × 9.6 (radius 17.5) and the Crusader box about 15 × 10 (radius 18). Geometry INI fields unread.

## Splash

- `dealDamageInternal` (`Weapon.cpp` 1327+): radius = max(primary, secondary); victims by bounding-sphere distance (90); **step function, no falloff**: inside `PrimaryDamageRadius` → `PrimaryDamage`, else `SecondaryDamage` (1524).
- `RadiusDamageAffects` defaults to `ALLIES|ENEMIES|NEUTRALS` (211, 290): by default splash hits own units. The primary victim ignores the mask (1404).
- Crusader values unread (Weapon INI, presumably `CrusaderTankGun`: `PrimaryDamage`, `PrimaryDamageRadius`, `SecondaryDamage`, `SecondaryDamageRadius`, `RadiusDamageAffects`). Measured: 9 splash hits of 6 HP on neighbours 15 units apart.

## Locomotor

- Fields `Speed`, `TurnRate`, `Acceleration`, `Braking`, `MinSpeed`, `MinTurnSpeed` (`GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Locomotor.cpp` 441–451), converted per frame; turning clamps to `TurnRate` per frame (2127–2203).
- Treads (1158–1269): `goalSpeed = (1 − min(|angle error| / 45°, 1)) × desired`, so at ≥ 45° off-heading a tank turns in place; inside 2 cells of the goal with > 2.25° error it uses 0.6 × speed; acceleration and braking capped to reach goal speed exactly.
- Wheels (1272+): cannot turn in place; turn speed `max(MinTurnSpeed, maxSpeed/4)` when error > 9°; reverse/3-point-turn logic (1306–1327). Measured Dozer "turns while driving".
- Legs (1608): **not read.** Measured: Ranger 180° turn then move, 11 frames.
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

Legs locomotor, SidesList teams, start-unit placement at game start, `BlendTileData` layout (where the cliff bits sit), object template names on Twilight Flame, map border size and boundary of Twilight Flame, network run-ahead, upstream diffs.

# M7 placement rules: Zero Hour vs Wargrid

Research note, 2026-11-07. Labels: source-read = read in code or INI; formula = derived from source-read values; unverified = not checked.

Source: `electronicarts/CnC_Generals_Zero_Hour` rev `0a05454`, `GeneralsMD/Code/GameEngine/Source/`. INI values from the root `INIZH.big` (hash pinned in [installation](installation.md)), extracted in memory/scratch only, nothing copied into the repo. INI paths below are inside that archive (`Data\INI\...`).

Units: Wargrid cell = 25 ZH world units (`tools/check_reference.py` `UNITS_PER_CELL`). ZH's own grids are different: terrain tile `MAP_XY_FACTOR` = 10 units, pathfind cell 10 units (not 25). `GeometryMajorRadius`/`MinorRadius` of a BOX are half-extents (full size = 2x), consistent with the SupplyDock "4 x 5" in [m7-economy-parity](m7-economy-parity.md).

## Entry point

`BuildAssistant::isLocationLegalToBuild` (`Common/System/BuildAssistant.cpp:908-1068`), called by the placement ghost (`GameClient/InGameUI.cpp:1478`), the click (`PlaceEventTranslator.cpp:120,225`) and again when the dozer starts (`DozerAIUpdate.cpp:1680`, `WorkerAIUpdate.cpp:386`, only `SHROUD_REVEALED`). Human flags: `TERRAIN_RESTRICTIONS | CLEAR_PATH | NO_OBJECT_OVERLAP | SHROUD_REVEALED | IGNORE_STEALTHED`. `NO_ENEMY_OBJECT_OVERLAP` is AI-only (`AIPlayer.cpp:536,610`). Codes: LBC_RESTRICTED_TERRAIN, LBC_SHROUD, LBC_OBJECTS_IN_THE_WAY, LBC_TOO_CLOSE_TO_SUPPLIES, LBC_NO_CLEAR_PATH, LBC_NOT_FLAT_ENOUGH, LBC_GENERIC_FAILURE.

## Answer to the user's question

- Distinct supply rule exists: yes, only for Supply Centers (all three factions). `KindOf CANNOT_BUILD_NEAR_SUPPLIES` is set on exactly the supply-economy buildings (`AmericaSupplyCenter`, `ChinaSupplyCenter`, `GLASupplyStash` and the general variants; `factionbuilding.ini:18740,19918,21247`). Barracks, factories, power, defences do not carry it.
- Value: `SupplyBuildBorder = 20.0` (`GameData.ini:252`, "min dist you can put a supply center from a supply source"). Rule (source-read, `BuildAssistant.cpp:968-996`): for any `SUPPLY_SOURCE` object (SupplyWarehouse, SupplyDock, SupplyPile, SupplyPileSmall) within range, expand its geometry by 20 on every side and refuse if the depot's footprint overlaps that. So a free gap of 20 units = 0.8 cell between depot footprint and pile footprint (box vs box; rotation-aware). There is no extra "enemy supplies" or own-supplies distinction; it is any source object.
- Other structures: no enemy- or own-clearance distance. They only may not overlap (see table), plus a 25-unit unit-exit lane for factory-type buildings.

## Rule table

| # | Rule | ZH value (source) | Wargrid today | Match? | Proposed change (data-driven) |
|---|---|---|---|---|---|
| 1 | Depot vs supply source gap | 20 units = 0.8 cell, all supply sources, only objects with `CANNOT_BUILD_NEAR_SUPPLIES` (source-read: `BuildAssistant.cpp:968-996`, `GameData.ini:252`). Centre to centre along the pile's half-extent: USA depot 114 units (4.56 cells), China 122 (4.88), GLA stash 106 (4.24), unverified; the API accepted the stash at 90 | implemented: row key `supply_clearance` 1 on the three depot rows (0.8 rounded UP, never closer than ZH); `footprint_error` in `construction.gd` rejects cells within that Chebyshev ring of any source footprint (`SOURCE_FOOTPRINT` 4x5) | yes | none |
| 2 | Edge-of-map margin | 30 units = 1.2 cell from any footprint sample point, all buildings (source-read: `BuildAssistant.cpp:536-545`, `GameData.ini:251`) | implemented: `BUILD_EDGE_MARGIN` 1 cell in `definitions.gd` (1.2 rounded DOWN to keep maps playable; user choice; 2 also passes both maps) | partial (1 vs 1.2 cells) | user ruling open: 2 cells |
| 3 | Object overlap | footprint box vs every non-NO_COLLIDE object; immobile objects (all structures, any owner) block; enemy objects block; disabled objects block; friendly mobile units are pushed away, not a blocker (source-read: `isLocationClearOfObjects`, `BuildAssistant.cpp:666-772`). Mines/inert/removable props are ignored. Piles are NO_COLLIDE (`civilianbuilding.ini:79,207,257,296`) so rule 1 is what keeps depots off them | any own/enemy building or source cell is non-walkable; ANY ground unit or destination on the footprint rejects the placement (`footprint_error`, "Footprint covers ground unit or destination") | partly: Wargrid is stricter on units | Keep Wargrid's stricter unit rule unless the user wants ZH push-away (needs a sim command to move friendlies; not data-only). Note only, no change proposed. |
| 4 | Factory exit lane | `FactoryExitWidth = 25` units = 1 cell on CommandCenters, Barracks, WarFactories, Airfields, ArmsDealer (source-read: INI `factionbuilding.ini:1328,2048,3847,8330,21979,22655,24034,25022,25892,27844`; `BuildAssistant.cpp:775-900`). A 25-unit-wide strip in front of the building (`NaturalRallyPoint` side, local +X, rotated by placement angle, from the edge of the geometry) must not overlap any immobile object; also the other building's own exit strip. Not on supply depots, power, defences. China/USA Airfield: USA has it, China airfield has none | none; builders and exits use the perimeter approach and units spawn at free cells | no | Row key `exit_lane` (cells; 1 on factory-type rows). In Wargrid footprints have no orientation, so: reject if the 1-cell strip on the exit side is blocked by another building/source. Needs the exit side defined in data (each row `exit_side`). Defer: Wargrid already finds exit cells dynamically, so the lane only prevents walled-in factories. |
| 5 | Extra bib width | `FactoryExtraBibWidth = 25` (1 cell) only on GLA Tunnel Network / Sneak Attack Tunnel (`factionbuilding.ini:32877,33039` and general variants) (source-read). Widens the object's no-overlap box by 25 units each side | n/a | n/a | One row key `placement_margin` (cells, FRC tunnel hub only). Optional: FRC (`frc_defence` = Tunnel Hub). Lowest priority. |
| 6 | Skirmish AI padding | AI-only: `myExtraWidth` = 3 pathfind cells (30 units) around its own placements (source-read: `BuildAssistant.cpp:788-796`) | Wargrid AI has its own site search (not read here) | n/a | AI placement picker may pad by 1 cell; not a rule for humans. |
| 7 | Terrain: walkable ground | footprint sampled every 10 units: water, cliff, impassable cells reject (`checkSampleBuildLocation`, `BuildAssistant.cpp:495-525`); bridge layer rejected (`:1022-1032`) | `is_walkable` on each cell | match (equivalent) | none |
| 8 | Slope | height range over the footprint must be <= `AllowedHeightVariationForBuilding = 10.0` (`GameData.ini:256`), LBC_NOT_FLAT_ENOUGH (source-read) | Wargrid maps are 2D grid with no height | no analogue | none; the map converter already flattens. Unverified whether converted maps lose placeable ground because of it. |
| 9 | Shroud / fog | target cell must be CELLSHROUD_CLEAR for the placing player (human flag only; `BuildAssistant.cpp:925-939`, first check on purpose) | no fog of war in simulation (`rg fog` finds only vision ranges) | no, N/A | If fog is ever added, add it as the first check. Not now. |
| 10 | Clear path | builder (non-structure) must have a quick path to the spot (`BuildAssistant.cpp:998-1013`, LBC_NO_CLEAR_PATH) | `approach` returns null -> "No reachable builder approach" (`construction.gd:65-75`) | match | none |
| 11 | Re-check at start | dozer re-runs the legality check on arrival with only the shroud flag, so a once-valid foundation is not re-rejected for overlap (source-read: `DozerAIUpdate.cpp:1680`) | not compared | unverified | none |
| 12 | Gap between neighbouring buildings | none. Boxes are tested for overlap only; touching boxes are legal, except exit lanes (rule 4) and bib (rule 5). Footprints are free boxes, not tile snapped (placement angle is arbitrary in 90-degree steps in the UI, ZH footprint `iterateFootprint` samples at 10 units) | cell-snapped; touching legal | match, aside from lane | none |
| 13 | Line building | `KINDOF_LINEBUILD` only on walls, wall hubs, moat, checkpoint, GLA trap, burning barrier (`factionbuilding.ini` 27906-31928); tiled by object size, `MaxLineBuildObjects = 50` (`GameData.ini:267`), chain stops at the first illegal tile (`BuildAssistant.cpp:1114-1215`) | no wall building in Wargrid | n/a | none until a wall/fence unit exists |
| 14 | Rally / garrison | `NaturalRallyPoint` is placed at `GeometryMajorRadius` on the exit side (INI comment "must always match GeometryMajorRadius"); no placement impact | n/a | n/a | none |

## Scale caveat

ZH footprints are larger than Wargrid's cell footprints: Command Center 120 x 140 units (about 5 x 6 cells) vs Wargrid 3 x 3; Barracks 110 x 90 (4 x 4) vs 2 x 2; Supply Center 88 x 90 (3.5 x 3.6) vs 3 x 3 (formula from `GeometryMajorRadius`/`MinorRadius`, INI above). Gaps in cells should not be scaled up by this ratio; the user's decision to match the pile footprint (4 x 5) makes rule 1 the relevant one because that is what controlled how far depots sit from piles.

## What Wargrid lacks (most important first)

1. Depot vs pile gap (rule 1): ZH requires 20 units (0.8 cell) between a supply-center footprint and a source footprint. Wargrid allows touching.
2. Edge margin (rule 2): ZH forbids building within 30 units (1.2 cell) of the map edge. Wargrid allows the last cell.
3. Factory exit lane (rule 4): ZH needs 25 units clear in front of factory-type buildings. Wargrid has no lane.
4. Unit push-away (rule 3): ZH moves friendly units off a footprint; Wargrid refuses. Wargrid is stricter, not a bug.

Not verified: skirmish AI site search in Wargrid (only the ZH rules above); effect of rule 2 on the converted maps' start slots; exact orientation sign convention of the ZH exit strip beyond the `cos/sin(angle)` offset at `BuildAssistant.cpp:806-810`.

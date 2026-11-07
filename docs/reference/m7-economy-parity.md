# M7 economy parity vs Zero Hour (research, 2026-11-07)

Status: research only, no game file changed. Labels: **source-read** (INI/C++ read), **formula** (derived here), **map-decoded** (retail `.map` object list), **unverified**. Nothing measured in the parity harness (not run: the cycle is fully determined by the INI delays plus path length, and dock-approach overhead is not measurable without a layout fixture).

## Provenance

- Retail INI: root `INIZH.big` of `~/CnC/run/Command & Conquer Generals - Zero Hour/`, loaded with `tools/check_reference.py` `load_archive` (pinned SHA-256 check passed), extracted to scratch only. Paths below are `Data\INI\...` inside it.
- C++: `~/projects/CnC_Generals_Zero_Hour` @ `0a05454`.
- Map: `~/projects/CnC_Modding_Support` @ `3aad8e4`, `Zero Hour/Maps/official/Tournament Desert/Tournament Desert.map`, decoded with `tools/zh_map/convert.py` `load` (objects and property dicts).
- Branch `spike-more-maps` (read with `git show`, not checked out) already converted Tournament Desert to `dry_wells.json` and documented it in `docs/reference/more-maps.md`.

## What the branch already established vs what I verified

| Claim | Branch `spike-more-maps` | Verified here |
|---|---|---|
| `SupplyDock` 400 boxes, `SupplyPileSmall` 50, no per-object override in the map | stated | re-verified: `object/civilianbuilding.ini:427,505-506` (Dock 400), `:570,606` (PileSmall 50, `DeleteWhenEmpty`); decoded property dicts of all 16 supply objects carry no box key; the map has no script chunk (chunks: HeightMapData, BlendTileData, WorldInfo, SidesList, ObjectsList, PolygonTriggers, GlobalLighting, WaypointsList) and no money/cash/supply strings besides the object names |
| Box counts carried over | yes: `dry_wells.json` sources 4x400 + 150/150/100/50/50/50/50 | confirmed. The converter on `main` (`BOXES = {"SupplyDock": 400}`) only knows `SupplyDock`; `SupplyPileSmall` exists only on the branch. `ashfall.json` (Twilight Flame) has 12 sources x 400, i.e. docks only |
| Piles merged | "Piles closer than one 3x3 footprint merge into one source, boxes added" | this is a departure, not parity: see item 2 |
| Starting money | not touched (`START_CREDITS = 10000` unchanged, `skirmish.gd:9`) | see item 1 |

## 1. Starting money

- ZH: `PlayerTemplate` `StartMoney = 0` for every faction (`playertemplate.ini:50,84,118`). The skirmish/LAN value comes from the game options: `MultiplayerStartingMoneyChoice` 5000 / **10000 (`Default = Yes`)** / 20000 / 50000 (`multiplayer.ini:92-107`), default `DefaultStartingCash = 10000` (`gamedata.ini:440`), used by `GameInfo.cpp:322,1022` (source-read). Same for every faction. The Tournament Desert map sets no money (no script chunk).
- Wargrid: `START_CREDITS = 10000` (`skirmish.gd:10`), used by `Skirmish.create` for both seats (offline and online, same function) and `debug/team_match.gd:17`. `combat_workload.gd` benchmark layouts use 0 credits (no economy in them). Scripted matches go through `Skirmish.create`/`MapData.create` (credits taken from the seat dict).
- Match: **yes, all factions and modes**. Only gap: no 5000/20000/50000 choice (not requested).

## 2. Supply piles

| Item | ZH (source) | Wargrid | Match |
|---|---|---|---|
| Box value | `ValuePerSupplyBox = 75` (`gamedata.ini:248`) | `box_value` 75 in `usa.gd`/`china.gd`/`frc.gd` `collects` | yes |
| Upgrades to box value | none: `Upgrade_AmericaSupplyLines` only boosts crates (`crate.ini:551`, `civilianbuilding.ini:25111`); no `SupplyBoxValue` upgrade key found in retail INI | none | yes (formula/source-read) |
| Dock `SupplyDock` | 400 boxes, boneless (`NumberApproachPositions -1`), one active docker (`DockUpdate.h:150`) | 400 (ashfall, branch maps) | yes |
| `SupplyPileSmall` | 50 boxes, boneless, deleted when empty | branch: 50 | yes on the branch, **absent on `main`** (converter ignores it) |
| `SupplyPile` / `SupplyWarehouse` | 150 / 400 boxes, 5 / 9 approach positions (not on Tournament Desert) | not converted | n/a |
| Tournament Desert piles (map-decoded) | 4 `SupplyDock` (2 start docks `SupplyDockNorth/South`, 2 corner docks) + 12 `SupplyPileSmall` in two clusters (6 at x~1300-1540,y~1190-1450; 6 at x~490-760,y~1230-1460) = 1600 + 600 = 2200 boxes | branch `dry_wells.json`: 11 sources, 2200 boxes (the 12 piles became 7 sources) | boxes yes; **pile count no** |
| Piles per start | 1 `SupplyDock` per start base (North 1408,2547 / South 633,127) | seat start vs nearest source: Chebyshev 19 / 16 (converter report) | roughly |
| Pile size on map | `SupplyDock` geometry BOX 50 x 61 (`civilianbuilding.ini:509-512`), i.e. 4 x 5 cells at 25 units | `SOURCE_FOOTPRINT` 3 x 3 (`definitions.gd:9`) | no (smaller) |
| Concurrency | each pile is its own dock with its own single active docker; small piles in a cluster serve several collectors in parallel | one `active_collector_id` per source; merged clusters (up to 6 piles into one source) serve one collector | **no** |

Proposed: unmerge small piles into separate 50-box sources (or cap merge at one pile), add `SupplyPileSmall: 50` to `BOXES` on `main` when the branch lands.

## 3. Collection speed

ZH constants (source-read): `americaair.ini:2256-2259` Chinook `MaxBoxes 8`, `SupplyCenterActionDelay 2900`, `SupplyWarehouseActionDelay 1200`, scan 700; `chinavehicle.ini:2051-2054` Truck 4 / 400 / 1000 / 700; `glainfantry.ini:3760-3764` Worker 1 / 150 / 150 / 700. Speeds: Chinook air 150, SupplyTruck wheels 40, FastHuman 25 units/s (`m7-factions.md` locomotor table; cell = 25 units, so 6 / 1.6 / 1.0 cells/s). Depot docks: `AmericaSupplyCenter` 9 approach bones (`factionbuilding.ini:18781`); `ChinaSupplyCenter` and `GLASupplyStash` boneless (`:19975`, `:21289`). Timing rule (`AIDock.cpp:574-636`, per `m7-factions.md`): wait the delay before every action; warehouse gives 1 box per action; the action after full fails and ends the dock, so full load = (MaxBoxes + 1) x delay; centre deposits everything after one delay. One active docker per dock. Starting units: every faction starts with only Command Center + Dozer/Worker (`playertemplate.ini:60-61,94-95,128-129`); Supply Center spawns one free Chinook, Supply Center one free Truck, Stash one free Worker (`SpawnBehavior` OneShot).

Credits per minute for one collector, formula only: `60 x capacity x 75 / (2d/v + load + unload)`, d = dock-to-dock path in cells. Excludes acceleration, turning, approach-bone flying and queueing (ZH real values are lower; unverified magnitude).

| collector | d | ZH formula | Wargrid formula |
|---|---|---|---|
| USA Chinook (load ZH 9 x 1.2 = 10.8 s, WG 8 x 1.2 = 9.6 s, unload 2.9 s) | 1 | 2565 | 2805 |
| | 6 | 2293 | 2483 |
| | 12 | 2034 | 2182 |
| | 30 | 1519 | 1600 |
| China Truck (load 5.0 s, unload 0.4 s) | 1 | 2707 | 2707 |
| | 6 | 1395 | 1395 |
| | 12 | 882 | 882 |
| | 30 | 420 | 420 |
| GLA Worker / FRC Laborer (load 0.3 s, unload 0.15 s; WG 5+5 / 5 ticks) | 1 | 1837 | 1800 |
| | 6 | 361 | 360 |
| | 12 | 184 | 184 |
| | 30 | 74 | 74 |

Wargrid ground collectors already take (boxes + 1) x delay (`supply_collection.gd`, comment "Zero Hour waits one more delay after the last box"); the air collector departs at capacity (M3 shortcut, 1 delay shorter, +9 % at d=1, +1 s per cycle). Per-collector rates match; what differs is the geometry.

### The FRC Laborer at distance 1 (user playtest)

- Wargrid: laborer cycle is 5 (box) + 5 (extra delay) + 5 (unload) = 15 ticks + about 2 x 1 cell at 1 cell/s = about 2.3 s, i.e. about 1800 credits/min from one laborer at d=1 (formula above). A Dry Wells small pile is 50 boxes = 3750 credits, so it drains in about 2 min; a 150-box merged cluster in about 6 min; with several laborers on a cluster still one at a time. Starting 10,000 + about 10,000 in a few minutes is therefore consistent with the formula (formula, not reproduced).
- ZH: the same arithmetic gives about 1840/min at d=1, so the rate is not the discrepancy. What ZH does not allow is d=1: the dock spot is the pile centre plus a unit vector toward the collector times half the major radius (`DockUpdate.cpp:446-487`, boneless): a `SupplyDock` major radius 50 puts the approach spot 25 units out, and the Stash (BOX 36 x 35, major 18 per m7-factions.md) has its own spot about 9 units from its centre. Building and pile footprints cannot overlap, so a pile touching a Stash sits at least about 50 + 18 = 68 units (2.7 cells) centre to centre, about 1.7-2 cells walk between approach spots, and the worker does walk (it is not stationary; it stands only during the 150 ms actions). ZH piles normally lie 15-20 cells from the start (converter report supply Chebyshev 14-19), where the rate is about 150-250 credits/min per worker (formula, d=12-30 gives 74-184).
- So the playtest symptom is a placement/footprint effect: on Wargrid maps the converted piles can be within 1 cell of a cache, and small piles are merged. Not a rate bug.

## 4. Per-faction table

| item | ZH value (source) | Wargrid value (file) | match? | proposed change |
|---|---|---|---|---|
| Start money, all | 10000 (`gamedata.ini:440`, `multiplayer.ini:98`) | 10000 (`skirmish.gd:10`) | yes | none |
| Box value, all | 75 (`gamedata.ini:248`) | 75 (`usa.gd:7`, `china.gd:5`, `frc.gd:6`) | yes | none |
| Dock 400 / small pile 50 | `civilianbuilding.ini` | 400 yes; 50 only on branch | partial | land branch handling; add to `BOXES` |
| Merged small piles | separate docks | merged sources (branch) | no | unmerge |
| Pile footprint | 4 x 5 cells | 3 x 3 | no | footprint or min-distance decision (user) |
| Start unit | USA Dozer / China Dozer / GLA Worker (`playertemplate.ini`) | `usa_builder` / `china_builder` / `frc_builder` (collects) | yes | none |
| USA collector | Chinook 1 free per Supply Center; 8 boxes; 1200 ms/box; centre 2900 ms; 6 cells/s | `usa_collector` boxes 8, load 36, unload 87, speed 6.0; spawns_on_complete (`usa.gd:7,13`) | yes except departs at capacity (1 delay early) | optional: add the extra delay for air |
| China collector | Truck 1 free; 4 boxes; 1000 / 400 ms; 1.6 cells/s | `china_collector` boxes 4, load 30, unload 12, speed 1.6 (`china.gd:5`) | yes | none |
| FRC collector (GLA Worker) | Worker 1 free from Stash; 1 box; 150 / 150 ms; 1.0 cells/s | `frc_builder` boxes 1, load 5, unload 5, speed 1.0; spawns_on_complete (`frc.gd:6,11`) | yes | none |
| Collectors per player at start | 0 (USA/China) / 1 Worker (GLA, also the builder) | 0 / 0 / 1 builder | yes | none |
| Bot collector count | AI builds more over time | FRC bot builds up to `LABORERS = 7` (`skirmish.gd:19`) | n/a (bot) | note, not ZH-derived |
| Dock concurrency | one active docker per dock; depot docks: Supply Center 9 approach bones, Stash/China centre boneless | one active collector per source/depot; queueing by `_ahead` | yes for single dock | none |
| Depot dock position | boneless: centre + half major radius toward collector | `supply_collection.gd` footprint-edge cells | approximate | unverified |
| Scan distance | 700 units = 28 cells for automatic warehouse search (explicit dock order ignores it) | all-map search | no (M3 choice) | optional |

## Mismatch list (most important first)

1. Small-pile merge on the branch (concurrency and pile count differ from Tournament Desert).
2. `main` converter ignores `SupplyPileSmall` (only docks), so a main-based Tournament Desert loses 600 boxes.
3. Pile/depot minimum distance (footprint 3 x 3 vs 4 x 5, adjacent placement): causes the d=1 laborer loop.
4. Air collector departs at capacity (small, known).
5. Search radius 28 cells not used (small).

## Blocking / unverified

- Real cycle times include approach, turn and queue overhead (not measured; parity harness not run). Pile centre to dock spot geometry for Stash and Dock is formula only.
- No selectable starting-money options in Wargrid (not requested).
- `skirmish.json` piles 200 -> 400 boxes (the `SupplyDock` value) after the parity economy starved Fm1: [m7-fm1-decision](m7-fm1-decision.md).

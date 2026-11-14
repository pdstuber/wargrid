# Simulation reference review (2026-11-12)

Research only: no production code, test, benchmark definition or budget changed. Wargrid tree: branch `spike-net-optimizations` at `4b444a2` (6 commits behind `main` `c2c2dbf`; the difference is dock-parity tooling and docs, no simulation file). Reviewed with the user on 2026-11-13: decisions and corrections in [Review 2026-11-13](#review-2026-11-13); corrections are also marked in place. Host for every measured row: the Mac mini (Apple M6, macOS, Godot 4.7.2.stable.official `ed1daf0bf`), headless.

Labels: **code** (read in source at the revision named), **measured** (run today, command and log named, or an existing Wargrid evidence note, cited), **derived** (arithmetic on code and measured figures), **estimate** (not measured), **docs** (a comment or document in a repo, quoted). Line numbers are at the revisions below.

| Repo | Revision | Licence (if adaptation were ever considered) |
|---|---|---|
| Wargrid | `4b444a2` | GPL-3.0-or-later |
| OpenRA | `b4d95a5671` (2026-11-08) | GPL-3.0 |
| RecoilEngine | `a0240a9b5c` (2026-11-04) | GPL-2.0-or-later (file headers, e.g. `rts/System/Sync/DumpState.cpp:1`) |
| Beyond-All-Reason | `a31aa1c194` (2026-11-12) | "GPL v2", per-file licences may differ (`LICENSE.md:1-3`); an "or later" grant must be checked per file before any reuse into GPL-3.0 |
| 0ad | `136720dada` (2026-11-12) | GPL-2.0-or-later (`CCmpUnitMotionManager.h:4-7`) |
| warzone2100 | `b904885ff` (2026-11-11) | GPL-2.0-or-later |
| permafrost-engine | `083a99ca` (2026-10-07) | GPL-3.0-or-later plus a linking exception |
| CnC_Generals_Zero_Hour | `0a05454` (paths below are under `GeneralsMD/Code/GameEngine/`) | GPL-3.0 plus EA's additional terms |

Nothing below needs ported code. Every recommendation is a mechanism that can be written from its description. Wargrid's porting rule (AGENTS.md, "Reference handling") applies unchanged if that ever changes.

**Beyond All Reason and Recoil are one data point for engine behaviour.** BAR is a game: 309 Lua gadgets at the top of `luarules/gadgets/` (344 counting subfolders) plus unit and map data, running on the Recoil engine. Movement, pathing, targeting, the spatial index and sync checking are Recoil's C++. BAR selects Recoil's QTPFS pathfinder (`gamedata/modrules.lua:98`) and tunes engine parameters. So BAR counts as evidence only for configuration and game-level rules, never as a second confirmation of a Recoil algorithm.

Permafrost was evaluated in full on 2026-11-10 (`~/projects/wargrid-overnight-work/engines/permafrost-engine.md`). That evaluation is cited here, not redone. Its verdict stands: good to read for pathing and crowd ideas, unusable as code (no lockstep, no browser build, no macOS).

## 1. Executive conclusion

1. **Wargrid's simulation has the right shape. Do not restructure it after any reference engine.** All five lockstep references (Permafrost has no lockstep) use the same skeleton Wargrid has: a fixed-rate deterministic tick, commands applied in a canonical order, one seeded RNG, a state hash compared between peers. Wargrid's split between simulation and presentation is cleaner than in any reference. The simulation is plain `RefCounted` code with no scene nodes, a test-enforced interface and no wall clock. Recoil updates a drawer inside its simulation frame (`rts/Game/Game.cpp:1810`, `CUnitDrawer::UpdateGhostedBuildings`). 0 A.D.'s simulation components handle render messages (`CCmpRangeManager.cpp:848`, `MT_RenderSubmit`). OpenRA traits mix tick and render interfaces on one object.
2. **The main cost is still the per-unit constant in GDScript Dictionaries, which earlier Wargrid work had already shown** ([performance next](performance-next.md) §4-5). The references do not change that conclusion. They run the same per-unit work every tick in compiled code. What they add is **algorithmic structure Wargrid lacks**. Most of it is in movement and pathing, which the next movement package (P5) rewrites anyway.
3. **Today's worst ticks have three measured causes, and every reference has a standard mechanism against each** (measured today, §3.3):
   - Synchronised splash volleys (`combat_fire` 10-24 ms on the contact row) hit a linear scan over every object per splash shot (`combat.gd:511-521`). A probe today put 8.8 of 10.3 ms (19.8 of 23.3 ms in warm-up) in that scan. The code already flags this as a shortcut. The references all answer area queries from a spatial index.
   - Path bursts (`service_paths` 7.1 ms on the team match): up to 8 synchronous A* searches per tick, however long. Today's grid search costs 0.057 ms p50, 0.53 p95 and 1.64 max per long route on Ashfall (pathing spike, `route_today`), so 8 long routes in one tick reach 4-13 ms (derived): the cap counts requests, not work. Zero Hour budgets searched cells per frame. Recoil, 0 A.D. and Warzone 2100 compute paths away from the requesting tick and deliver them at a fixed later tick.
   - All bots decide on the same tick from one full snapshot (`opponent.decide` 7.6 ms on the team match). Recoil and Warzone 2100 stagger per-unit slow work by id (Recoil's team update, by contrast, runs every team on the same frame, `TeamHandler.cpp:146-154`).
4. **Path search: five of the six engines use a coarser graph first** (Warzone 2100 is the exception). Recoil's QTPFS (a quadtree of rectangles, BAR's choice); OpenRA's 10×10 abstract regions as the A* heuristic; 0 A.D.'s hierarchical regions with jump point search on the long range; Permafrost's portal graph; Zero Hour's hierarchical zone path that then restricts the cell search (`AIPathfind.cpp:6399-6407`). That supports the 2026-11-10 pathing spike's proposal for P5: a rectangle navmesh as the base method, measured 11× cheaper at p50 than the 2×-finer octile grid P5 plans. It is not a fix for today's burst: today's coarser grid is cheaper per route (0.057 ms p50) than the mesh with straightening (0.164 ms). **Group orders share work.** Warzone 2100 searches backwards from the goal and continues the same search for every unit with that destination (`src/astar.cpp:22-40`; corrected 2026-11-13: the first unit's search runs forward from its source, later units with the same goal continue a stored backward search).
5. **Moving units are soft in the three engines whose code was traced** (0 A.D., Recoil, Permafrost); Zero Hour's separate "moving" and "fixed" cell flags point the same way but were not traced; Warzone 2100 not checked. 0 A.D. pushes overlapping movers apart in fixed point (`CCmpUnitMotion_System.cpp:63-110`). Recoil resolves unit collisions by pushing (`GroundMoveType.cpp:2787`, `HandleUnitCollisions`, with a per-unit-type `pushResistant` flag, `:502`), in a parallel detect and serial apply pass (`GroundMoveSystem.cpp:105-140`). Permafrost blocks only stationary units. Zero Hour marks cells as "moving" or "fixed" separately (`AIPathfind.h:271-273`). OpenRA is the exception: cell occupancy with sub-cells, close to Wargrid's avoidance spike rules that jammed packed moves. This is a design input for the avoidance work, not a measurement.
6. **Wargrid detects desyncs well and localises them poorly.** A digest every 30 ticks plus one snapshot at the mismatch tells you that a desync happened, but not which tick or field caused it. OpenRA hashes every network frame (`Network/OrderManager.cs:272`, interval `:332`) and keeps detailed reports of the last 7 of them (`SyncReport.cs:25`). Warzone 2100 keeps a 12-tick text log (`sync_debug.cpp:297`). Recoil keeps a checksum running over every synced assignment, plus history. 0 A.D. can re-create a second simulation from serialized state and compare the two every turn, which catches state the snapshot misses (`Simulation2.cpp:400-470`). A per-tick core hash ring and a restore twin are cheap. They also make the planned packed-array storage change safe.
7. **Do not adopt:** fixed-point maths now, an ECS or component framework, parallel work inside a tick, a lower global tick rate, a whole-engine port, or reading the reference code into Wargrid. Reasons are in §8.

## 2. Top five improvements (ranked by expected value)

| # | Improvement | Problem it solves (evidence) | Confidence | Size | Trace re-pin |
|---|---|---|---|---|---|
| 1 | **Index-backed area queries**: splash victims and other "all objects within r" scans read the tick's spatial index instead of every object | contact row `combat_fire` worst ticks 10.4 ms (sample) and 21-24 ms (warm-up), measured; the splash scan is 8.8 of those 10.3 ms and 19.8 of 23.3 ms in warm-up (zone maxima, measured by a probe today in a scratch copy of `4b444a2` with one profiler zone around the `splash_victims` call (no other change; `sh tools/run_profile.sh`, exit 0, load 1.16-1.42)) | High (measured) | S-M (one function plus a small index built after movement; the plan's grid is lazy and stale by fire time, §5.1) | no, if the result is sorted by id as today |
| 2 | **Path service with deferred, deterministic delivery and a work budget** (movement package P5): a request at tick T gets its route at T+k in request order; the budget counts searched nodes, not requests | team match `service_paths` worst tick 7.1 ms, measured; today's search 1.64 ms max per long route (pathing spike `route_today`), so 8 per tick reach 13 ms (derived); P5's planned finer grid costs 1.78 ms p50 and 6.7 ms p95 per route (spike method A) | High (Recoil, 0 A.D., Warzone 2100 and Zero Hour all do a variant) | M, inside P5 | yes (route timing) |
| 3 | **Coarse search graph with Wargrid's own tie-breaks, plus goal sharing for group orders**: the pathing spike's rectangle mesh as base, the grid as reference; one backward search per (goal, size class, tick) shared by a group | A* cost and Godot `AStarGrid2D` tie-breaks a port must copy (determinism rules, "Couplings") | Medium-high (converging evidence; the GDScript cost of an own search over about 700 rectangles is not measured) | M-L, inside P5 | yes |
| 4 | **Desync localisation**: a ring buffer of the per-tick core hash (`core_check` already exists) plus a restore twin test (restore from snapshot at tick N, run both, compare every tick) | desync reports localise only to a 30-tick window; hidden state outside the snapshot (`_terrain_cache`, navigation `_snapshot_cache`, bot memory by design) is untested | High (four references do some variant; cost is an estimate) | S-M, tooling and tests | no |
| 5 | **Stagger slow per-seat work by seat id**: bot decisions on `tick % 30 == seat offset`, not on the same tick for every bot | team match `opponent.decide` 7.6 ms on one tick, measured | High | S | yes (bot command ticks) |

Ranked lower but planned in the same packages: soft movers with hard stationary blockers (§5.6, avoidance work); a shared spatial index in packed arrays rebuilt each tick (§5.5, with the D1 storage work); split rates for target choice (§5.7, already decided by the user, evidence below says its gain is bounded).

Roadmap order (§7): #1 and the hash ring from #4 come first, together, because both are cheap and re-pin nothing; the ring is also the oracle for every later change that touches state.

## 3. Current Wargrid assessment

### 3.1 How it works (code, `4b444a2`)

- **State**: one `Simulation` object (`game/scripts/simulation/simulation.gd`, 864 lines; the simulation folder is about 3,880 lines in 26 `.gd` files). Per unit one `Dictionary` with nested `Array`/`Dictionary` fields (`_entities`, `:33`). Buildings, sources and players are Dictionaries keyed by id. No scene nodes.
- **Tick**: `step()` (`:503`) is called explicitly by the caller (scene, lockstep, benchmark). Fixed order: apply due commands, sorted ids, combat plan, construction, production, supply, path service, movement plus containers plus horde bonus plus salvage, combat fire, match evaluation. Simulation rate 30 per second.
- **Entities and systems**: static functions per system (`combat.gd`, `supply_collection.gd`, `horde.gd` and others) operating on the shared Dictionaries. That is a hand-written "systems over a shared store" shape without a framework. It fits the code size.
- **Commands**: `issue_command()` (`:155`) validates and queues; `_apply_orders()` (`:333`) applies those due this tick, sorted by (tick, player, sequence). Online: `lockstep.advance` → `issue_command` → `step()` (the simulation/network seam; transport and relay are in the [netplay review](netplay-reference-review.md)).
- **Movement and pathing**: Godot `AStarGrid2D`, 4-neighbour, Manhattan, one cell per building cell (`grid_navigation.gd:5-23`). Queue served first in, first out, at most `PATH_REQUESTS_PER_TICK = 8` searches per tick, synchronously (`simulation.gd:19`, `:464-469`). Moving units overlap; groups get distinct destination cells (`destination_allocation.gd`).
- **Combat**: `Combat.plan` walks every armed unit every tick (`combat.gd:93`). Only the enemy scan runs on an 8-tick cadence staggered by id (`:125`). The target grid is rebuilt lazily on the first scan of each tick (`_grid`, `_build_grid`, `:161`, `:295`). Fire resolves a volley as collect-then-apply: damage is summed, then dead units are removed in id order (`fire`, `:352-385`). That is already the "compute, then apply in order" pattern the references use for parallel work.
- **Spatial queries**: four separate structures, each built differently: the combat target grid (8-cell Dictionary buckets per owner, every tick); the horde bucket grid (`horde.gd:54`, its own cell size, rebuilt when due); `_unavailable_cells` (scan of all entities per move order, `simulation.gd:318`); and `splash_victims` (no index, scan of all objects per splash shot, `combat.gd:512`).
- **Determinism**: rules in force and partly enforced by `tools/test_sim_math.py` ([determinism rules](determinism-rules.md)). Floats with `sqrt` only, one xorshift RNG in the snapshot, sorted command and snapshot order. Digest today: `state.hash()` plus `core_check` every 30 ticks (`state_hash.gd`, `lockstep.gd:35`). Checks: CI replay traces on Linux, Windows and macOS, golden series in tests, one manual browser-against-native match.
- **Godot couplings in the simulation** (code): `AStarGrid2D` (tie-breaks unread), `Vector2` float32 rounding at 89 construction sites, `Dictionary.hash()` in the live digest, Godot's PCG32 for start spots, and `Profiler` reading `Time` (debug only, not behaviour).

### 3.2 What is already good

- Commands, RNG, ordering and maths rules are explicit and partly enforced. Most references rely on convention: OpenRA has 86 `[Sync]` attributes in `OpenRA.Mods.Common` and hashes only the marked fields (plus actors, synced effects and its RNG).
- Volley resolution is order-independent by construction (collect damage, then apply). Recoil and 0 A.D. need explicit per-entity buffers to get the same property.
- Path requests are already queued and capped. The cap counts requests rather than work, which is the problem in §5.2.
- Measurement culture: profile zones per system, worst-tick lines, a performance ledger with budgets that are not loosened. No reference has a gate like this. Recoil and 0 A.D. have profilers, not budgets.
- The interface is small and test-enforced (`tools/test_sim_boundary.py`). That is the precondition for engine independence, and Wargrid already has it.

### 3.3 What limits it (measured today)

`sh tools/run_benchmark.sh`, exit 0, load 1.17-1.56: `BUDGET EXCEEDED open hordes300 (regression ceilings held)`. Combat open p95 1.845 / p99 2.192 against 1.82 / 3.64, hordes300 p95 2.816 / p99 3.296 (both stress rows, inside ceilings; accepted). Worst ticks: contact 11.197 ms (tick 420), hordes300 7.559, dense 3.176, open 2.966; lockstep overhead p99 0.066 ms. Logs (private, kept with the working notes): `simulation-reference-logs/`: `bench.log`, `profile.log`, and for the splash probe `splash-profile.log` plus `splash-probe.diff` (the only change in the probe copy).

`sh tools/run_profile.sh`, exit 0, load 1.43-1.65 (`profile.log`). Mean / p95 / max ms per tick:

| Zone | skirmish3v3 (goal row) | team match | contact | hordes300 |
|---|---|---|---|---|
| `step` | 0.699 / 1.302 / 1.665 | 1.078 / 1.937 / **9.369** | 0.436 / 1.157 / **11.356** | 1.984 / 2.855 / 7.662 |
| `step.combat_plan` | 0.368 (53 %) | 0.405 (38 %) | 0.246 (56 %) | 0.796 (40 %) |
| `step.advance` | 0.121 (17 %) | 0.319 (30 %) | 0.057 | 0.955 (48 %) |
| `step.combat_fire` | 0.172 / 0.416 / 0.812 | 0.130 / 0.417 / 2.202 | 0.106 / 0.235 / **10.426** | 0.137 / 0.340 / 5.506 |
| `combat.build_grid` | 0.060 (9 %) | 0.102 (9 %) | 0.012 | 0.171 (9 %) |
| `opponent.decide` | | 0.127 / 0 / **7.589** | | |
| `step.service_paths` | 0.001 / 0.001 / 0.085 | 0.017 / 0.011 / **7.149** | | 0.004 / 0.034 / 0.062 |
| `view.batch` (presentation, outside `step`) | 0.360 | 0.666 | 0.218 | 1.421 |

The contact row's slow-tick list shows `combat_fire` at 21.985, 22.041, 23.716, 14.207 and 13.206 ms in warm-up on ticks 0, 60, 120, 180 and 240, then about 10 ms every 60 ticks. The cannon's `delay_ticks` is 60 (`definitions/shared.gd:16`), so the tanks fire synchronised volleys. These agree with the 2026-11-11 profile within a few percent.

Measured against suspected:

| Limit | Status |
|---|---|
| Per-unit Dictionary cost (`combat_plan`, `advance`, snapshot, view batch) | measured (performance next §4.1, §5.3: 1.4-1.6x from packed arrays on a real neighbour workload) |
| Splash scan O(splash shots × objects) is the contact worst tick | **measured**: zone `combat.splash_scan` max 8.804 ms against `combat_fire` max 10.324 (sample) and 19.842 against 23.332 (warm-up) on the contact row; team match 1.425 against 2.186; mean share small everywhere (3-7 % of `step`). Zone maxima are reported per zone; both fall on volley ticks. The remaining 1.5-3.5 ms of a volley tick (shot and damage Dictionaries, deaths, removal) was not split further |
| Path bursts set the team match's other worst tick | measured: `service_paths` max 7.149 ms. That the cause is long routes, not 8 short ones, is suspected (the zone does not count searched cells) |
| Bot decisions on one tick | measured: `opponent.decide` max 7.589 ms, all bot seats on `tick % 30 == 0` (`skirmish.gd:11`, `:67-72`) |
| Target-grid rebuild per tick | measured share 9 %; whether incremental beats a packed rebuild is untested (§5.5) |
| Allocation pressure | suspected only: `unit.position = [x, y]` per move (`simulation.gd:623`), `route.slice(1)` per waypoint (`:617`), per-tick result Dictionaries. GDScript reference-counts, so there is no GC pause to fear; the cost is per allocation, and the ledger shows allocation-heavy rows scale worse in WebAssembly (F 6.2-6.5 against 5.0-5.2) |

## 4. Reference implementation findings

### 4.1 Comparison table

| Area | Wargrid | Recoil (BAR) | OpenRA | 0 A.D. | Warzone 2100 | Zero Hour |
|---|---|---|---|---|---|---|
| Sim rate | 30/s | 30/s (`GlobalConstants.h:52`) | 25/s at default speed | 5/s: 200 ms turns (`TurnManager.h:63`) | 10/s (`lib/gamelib/gtime.h:39`) | 30/s |
| Numbers | float64 plus float32 `Vector2`, strict rules | float plus `streflop` libm, sync checker | integers (`WPos`, `WAngle` lookup tables) | fixed point `CFixed` 15.16 (`maths/Fixed.h:375`) | integers, integer trig tables (`lib/framework/trig.h:33-40`) | float |
| Target choice cadence | scan every 8 ticks, staggered; bookkeeping every tick | `SlowUpdateWeapons` every 15 frames, unit list split in 15 slices (`UnitHandler.cpp:348-376`); retry on an existing target only every 65 frames (`Weapon.cpp:730`) | random 3-8 ticks from the synced RNG, idle actors only (`AutoTarget.cs:80-83`, `:277-304`) | range queries every turn, reporting only added and removed entities (`CCmpRangeManager.cpp:1185-1245`) | once per second, staggered by id (`ai.cpp:1238`, `action.h:117`) | Patriot idle scan 250 ms (retail data, quoted at Wargrid `combat.gd:386-387`) |
| Spatial index | target grid rebuilt per tick plus 3 other structures | persistent quad field, updated when a unit's quads change (`QuadField.cpp:525-549`), checked every 3 frames per unit (`UnitHandler.cpp:406`, `ModInfo.cpp:43`) | persistent bins of 10 cells, remove plus add on move (`ActorMap.cs:25`, `:598-601`) | persistent subdivision, `Move` on position change (`CCmpRangeManager.cpp:653`) | rebuilt once per update at a fixed point (`loop.cpp:648-651`) | |
| Path search | `AStarGrid2D`, cell grid, synchronous, 8 per tick | QTPFS quadtree, searched off-thread, joined at the start of the next frame (`QTPFS/PathManager.cpp:826-829`, `:1166`) | A* on cells with an abstract-graph heuristic (10×10 regions) (`HierarchicalPathFinder.cs:21-100`) | jump point search plus hierarchical regions; short-range vertex search; async between turns, results posted at turn start (`CCmpPathfinder.cpp:126-131`, `:840-893`) | backward A* per destination, contexts reused within a tick, 30 kept (`astar.cpp:22-40`) | hierarchical zone path, then a restricted cell search (`AIPathfind.cpp:6399-6407`); no new request after 5,000 searched cells per frame (`:1103`, `:5923-5935`) |
| Moving units | overlap; distinct destination cells | pushed apart, collision events applied serially | cell occupancy with sub-cells | soft pushing, fixed point | | cells marked goal, moving, fixed (`AIPathfind.h:271-273`) |
| Parallel sim work | none (inside-tick threads measured 2-3 %, dropped) | yes: read phases parallel, writes to per-unit event lists, applied serially (`GroundMoveSystem.cpp:32-140`) | none | range queries and paths on workers; outputs in index-addressed slots, applied in order (`CCmpRangeManager.cpp:1194-1200`) | path jobs on threads, one thread per "cohort" so reuse stays deterministic (`fpath.cpp:291-294`) | none |
| Desync detection | digest every 30 ticks; snapshot plus command log at mismatch | running checksum of synced assignments, history buffer, state dump (`System/Sync/SyncChecker.h:11-49`) | `SyncHash` every network frame over `[Sync]` fields, detailed reports for the last 7 (`World.cs:482-513`, `OrderManager.cs:272`, `SyncReport.cs:25`) | quick hash every turn (positions), full hash about every 10 s in multiplayer (`TurnManager.cpp:252-260`); serialization and rejoin twin tests (`ComponentManagerSerialization.cpp:106-125`, `Simulation2.cpp:400-470`) | syncDebug text log ring of 12 ticks plus backtraces (`sync_debug.cpp:297`) | |

### 4.2 Execution model

- **Fixed order, explicit phases, deferred structural changes.** OpenRA ticks actors in id order (a `SortedDictionary`, `World.cs:33`), then traits, then effects, and runs queued add and remove actions at frame end (`World.cs:383`, `:453-454`). Recoil gives units created during the loop their first update next frame (`UnitHandler.cpp:397-399`). Wargrid instead filters `ids` and `armed` after construction when units were removed mid-step (`simulation.gd:535-537`). That is correct today, but ad hoc. Only worth changing if a bug appears; not recommended on its own.
- **Slow updates in slices.** Recoil's `SlowUpdateUnits` handles `activeUnits.size() / 15 + 1` units per frame, wrapping every 15 frames (`UnitHandler.cpp:348-366`). Every unit's slow work therefore happens once per half second and the cost is flat across frames. Wargrid's equivalent today is the 8-tick scan stagger (`combat.gd:125`); the bot decision is not staggered.
- **Count-driven, deterministic rate degradation.** BAR's `unit_continuous_aim.lua:21-60` lowers a unit type's re-aim time from the engine's 15 frames and raises it by one frame for every N units of that type a team has built. Because the trigger is a synced count, the degradation is deterministic. That is the cleanest form of "decide less often when there are many units" seen in this review; the idea fits a horde mode.
- **Sim rate.** 0 A.D. at 5 Hz and Warzone 2100 at 10 Hz show that low decision rates with drawing in between are viable. Zero Hour and Recoil run at 30. This supports the user's split-rates decision (movement and fire at 30, decisions slower) over a lower global rate. 0 A.D.'s 200 ms turn also sets its command latency, and Wargrid should not copy that.

### 4.3 Large-scale performance

- **Parallel compute, ordered apply.** Recoil's ground movement runs plan and position updates and collision detection in `for_mt` loops, keeps the writes that touch many synced variables single-threaded ("These two sections are ST due to the numerous synced vars being changed", `GroundMoveSystem.cpp:56`), and stores collision outcomes in each unit's own event component. Those are drained in registry order (`issue_events`, `:23-29`, `:126-140`). 0 A.D. runs all range queries on workers and writes each query's messages into a vector slot indexed by query order ("Important: The order of messages must be fully deterministic", `CCmpRangeManager.cpp:1194-1200`). For Wargrid this is the shape a Rust kernel should take (flat arrays in, per-unit outputs out, applied in id order), not a reason to add threads.
- **Diffs instead of rescans.** 0 A.D.'s range manager keeps each query's last match and posts only added and removed entities (`CCmpRangeManager.cpp:1240-1245`). Unit AI reacts to those messages instead of scanning. In GDScript the diff costs a sorted set difference per query, so it beats rescanning only when queries are much rarer than changes. Not recommended for the goal row (§5.7).
- **Pooled query buffers.** Recoil's quad field hands out per-thread reusable vectors (`QuadField.h:178`, `:263`). 0 A.D. keeps result buffers per worker (`CCmpRangeManager.cpp:523-524`). The Wargrid analogue is reusing packed arrays in hot loops, part of D1.
- **Incremental map updates with a cap.** QTPFS processes at most 16 damaged map blocks per frame for each layer (`PathManager.cpp:843-856`). Permafrost caps field rebuilds per tick (permafrost evaluation §2). Wargrid replaces blocked cells synchronously when a building lands. The pathing spike measured 7.7 ms for a building change at fine resolution on the grid (10.3 ms is its derived upper bound for the mesh), so P5 needs the same cap.

### 4.4 Pathfinding and group movement

- **Delivery fixed by ticks, usually deferred.** Recoil starts searches at the end of `PathManager::Update` in frame N and joins them at its start in frame N+1 (`PathManager.cpp:826-829`, `:1162-1169`; `SyncUpdatedPathsSystem.cpp:39-41`). 0 A.D. computes paths between turns and posts results at turn start, with a same-turn cap (`CCmpPathfinder.cpp:126-131`, `:840-893`). Warzone 2100 lets a droid wait in `MOVEWAITROUTE` and collects on its next update ("collecting it now would wait on a worker that has barely started", `fpath.cpp:578-585`). OpenRA searches synchronously, and 0 A.D. also computes a capped batch inside the turn. What all of them share is that *when* a path arrives is a function of ticks, never of thread timing. That makes the work movable (inline, sliced over ticks, onto a worker, into a kernel) **only if the search inputs are frozen**: Recoil runs the systems that change the map after the join ("Systems following here can make changes that would otherwise break active searches", `PathManager.cpp:830-831`). A route computed but not yet delivered is simulation state and must be in the snapshot.
- **Work budget, not request budget.** Zero Hour starts no new request once 5,000 cells have been searched this frame; a started search always finishes (`AIPathfind.cpp:1103`, `:5923-5935`). Wargrid's cap of 8 requests treats a 3-cell route and a 300-cell route alike. With `AStarGrid2D` the searched-cell count is not visible; an own search over the rectangle mesh would expose it.
- **Coarse graphs.** QTPFS is a quadtree of rectangles (`rts/Sim/Path/QTPFS/NodeLayer.cpp`, `Node.cpp`), the same family as the pathing spike's method B. OpenRA keeps cell-level A* but replaces the straight-line heuristic with an abstract path over 10×10 regions, and keeps those regions up to date when immovable actors change ("Maintains a hierarchy of abstract graphs that provide a more accurate heuristic", `HierarchicalPathFinder.cs:21-26`). It also says the benefit is lost around moving blockers (`:84-96`). 0 A.D. and OpenRA both keep connected-domain labels to answer "reachable?" without a search. Wargrid already has these (`grid_navigation.gd` `_components`).
- **Goal sharing.** Warzone 2100's A* runs from the destination, so later units with the same goal continue the stored search until they are reached (`astar.cpp:22-40`; corrected 2026-11-13: the first search in a tick runs source to destination, the backward search starts with the second unit). Contexts are dropped every tick (`:671-673`). Its threads warn that results "may slightly differ depending on whether an existing PathfindContext is reused versus starting from scratch" and therefore pin every cohort to one thread (`fpath.cpp:291-294`). **For Wargrid: sharing changes results, so "cache-on equals cache-off" will fail by design. The sharing rule itself must be specified: which units share a search is a function of (goal, size class, tick, request order) only, and a work budget must cut at a point that depends only on that order.**

### 4.5 Collision and density

- 0 A.D. pushing: per 20 m square and its neighbours, n² inside a square, damped by "pressure" so dense crowds settle ("I have tested grid sizes from 10 up to 80 and overall it made little difference to the performance, mostly, I suspect, because pushing is generally dwarfed by regular motion costs", `CCmpUnitMotion_System.cpp:64-72`).
- Recoil: collision detection parallel, crush and collision events applied serially (`GroundMoveSystem.cpp:105-140`).
- Permafrost: stationary units stamp blocker tiles; moving units avoid each other with velocity obstacles; waiting units wake on a freed-cell counter.
- Zero Hour: per-cell `UNIT_GOAL`, `UNIT_PRESENT_MOVING`, `UNIT_PRESENT_FIXED` (`AIPathfind.h:271-273`), which suggests its pathfinder tells movers and parked units apart (flags read in the header only, not traced).
- OpenRA: hard cell occupancy with sub-cells; units wait or nudge.

### 4.6 Determinism

- **Numbers**: three of the five lockstep engines use integers or fixed point (OpenRA, 0 A.D., Warzone 2100). Recoil and Zero Hour keep floats; Recoil and makes libm deterministic with `streflop` (`rts/lib/streflop`) plus a runtime sync checker. Wargrid's choice (floats, `sqrt` only, no FMA, no relaxed SIMD) is the Recoil route without the libm problem, because it uses no libm functions. WebAssembly arithmetic is IEEE except NaN bit patterns and relaxed SIMD, both already banned. Floats stay sound for native plus browser; integers only with a port, as the user decided on 2026-11-09.
- **Random**: OpenRA's `SharedRandom` is in the hash (`World.cs:503`). 0 A.D. replaces JavaScript's `Math.random` with the simulation RNG (`scriptinterface/Interface.cpp:477-495`). Wargrid already has its RNG in the snapshot.
- **Localisation**: see conclusion 6. 0 A.D.'s quick hash checks positions, the RNG and the next entity id so it can run every turn ("fast enough to run every turn but will typically detect any out-of-syncs fairly soon", `ComponentManagerSerialization.cpp:112-117`). `core_check` (id, owner, hp, position, credits) is close but has no RNG and quantises floats.
- **Serialization twin**: 0 A.D.'s serialization test builds a secondary simulation from the primary's serialized state at turn N and compares hashes each turn; the rejoin test does the same from a saved turn (`Simulation2.cpp:400-470`, replay switches `ps/Replay.cpp:256-267`). It finds state that lives outside serialization. Wargrid has known state outside the snapshot (`_terrain_cache`, navigation `_snapshot_cache`, profiler counters; bot memory by design) and has no test that a restored simulation continues identically. The user moved the restore round-trip test into the movement milestone (design answers, "Golden order").

### 4.7 Architecture and engine independence

- No reference has a simulation that runs outside its engine binary without the engine's own types. Recoil's sim uses `float3`, `CUnit` pointers and calls drawer code. OpenRA's sim is C# traits on `Actor`, but its rendering traits live on the same objects. 0 A.D.'s simulation2 is the most separable: components, messages, its own serializer, a headless replay mode (`ps/Replay.cpp:197-286`). Even so, it routes render messages through the same component manager.
- 0 A.D. tried an AI worker on its own thread and gave up: "copying the game-state every turn proved difficult and rather slow itself" (`CCmpAIManager.cpp:97-103`). The TODO says off-thread work should return "after a distinct # of simulation turns (to maintain determinism)" (`:104-106`). This is direct evidence for the risk the worker-thread design names as unmeasured: the hand-off, not the compute.
- Wargrid's remaining couplings are few and named (§3.1). The ones that block a frontend swap or a port are `AStarGrid2D` (its tie-breaks are behaviour) and `Dictionary.hash()` (the specified own digest replaces it). `Vector2` float32 rounding is a port obligation, not a blocker.

## 5. Detailed recommendations

Each item: reference, Wargrid code, problem, benefit, cost, risks, validation, smaller alternative. Category in the heading.

### 5.1 Index-backed splash queries — **Adopt soon**

- **Reference**: every engine answers area damage from its spatial index (Recoil quad field, OpenRA `FindActorsInCircle` over `ActorMap` bins, `WorldUtils.cs:69-75`; 0 A.D. subdivision; Warzone 2100 `gridStartIterate`).
- **Wargrid code**: `combat.gd:511` (the shortcut comment: "scans every object per cannon shot; grid it if cannon shots x objects shows in the ledger"; corrected 2026-11-13: every weapon with `primary_radius > 0` splashes, `combat.gd:366` and `:410`: also rocket, battery, both light tank guns and the pickup cannon and rocket, `definitions/shared.gd`; the battery is a defence and splashes through `Combat.fire_defences`, which runs after `fire` has removed its dead), `splash_victims` `:512-521`, caller `_splash` `:494-502`, grid `_build_grid` `:295`.
- **Problem**: O(splash shots × all objects) per tick. 100 cannon tanks on a 60-tick reload fire in the same tick, and each shot walks every unit and building with several Dictionary lookups. Measured: 8.8 ms of a 10.3 ms `combat_fire` worst tick on the contact row, 19.8 of 23.3 in warm-up; about 48 and 109 ms on the target (derived, × 5.5).
- **Benefit**: the scan becomes O(shots × objects near the impact). With a blast radius of 0.2 (cannon, `definitions/shared.gd:16`) or the infantry blast, the query window is at most ±2.72 (blast plus `MAX_TARGET_RADIUS`), so at most a 2×2 block of 8-cell grid cells per shot (derived). (Corrected 2026-11-13: the pickup cannon's infantry blast is 1.853, so its window is ±4.05 and can touch 3 × 3 grid cells.) Expected: most of the 8.8 ms goes (estimate; the grid lookup per shot is not free in GDScript).
- **Cost**: small to medium. Today's grid cannot be reused as it stands (see Risks). The grid holds ground units and buildings by owner. Splash needs all owners (allies, enemies, neutrals), so the query walks the cells of all owners within `radius + MAX_TARGET_RADIUS`. Air units and passengers are already excluded from the grid, which matches the filter in `splash_victims`.
- **Risks**: the victim list must stay sorted by id (it is, `:520`), so no trace change is expected. Buildings span several cells; deduplicate by id. Today's grid is the wrong source: it is built lazily inside `plan` only when some unit scans (`combat.gd:94`, `:161-166`; on 56 % of contact ticks), `fire` cannot reach it, it is built before construction, production and container exits (units spawned or unloaded this tick are missing), and its record cache keeps plan-time positions. Widening the window does not cover new units. **Build the splash index from live positions after movement, right before `Combat.fire` (`simulation.gd:562`), only on ticks with a splash shot. A stale index silently changes who gets hit.**
- **Validation**: the contact row's `combat_fire` max and the warm-up slow ticks before and after; all combat replay traces unchanged (`run_tests.sh`, CI `godot-replays`); a test with a unit that moves into the blast radius on the firing tick.
- **Smaller alternative**: none smaller that fixes the cause. Desynchronising volleys (random first delay) spreads the cost but changes behaviour and still costs O(shots × objects) per second.

### 5.2 Path service: deferred delivery and a work budget — **Adopt in P5**

- **Reference**: §4.4 (Recoil, 0 A.D., Warzone 2100 deferred delivery; Zero Hour cell budget).
- **Wargrid code**: `simulation.gd:19` (`PATH_REQUESTS_PER_TICK`), `_service_paths` `:464-469`, `_assign_route` `:572`, `grid_navigation.gd:108` (`route`), the combat repath callers (`combat.gd` `_approach`, `REPATH_TICKS`).
- **Problem**: one tick can run 8 full-map searches. The team match worst tick includes 7.1 ms in `service_paths` (measured); on the target that is about 39 ms (derived, × F = 5.5), longer than a tick. P5's finer grid would make each search about 30× more expensive at p50 (1.78 against 0.057 ms, pathing spike), so the cap matters more after P5, not less.
- **Shape**: `request_path(unit, goal)` records the request with its tick. The service processes requests in (request tick, unit id) order until a node budget is used up, and makes results visible at a fixed point: the next tick's movement phase at the earliest, never earlier than T+1, even if computed in the same tick. A unit waiting for a route keeps its status `path_pending` (it exists today). With a fixed delivery tick, the same code can later run on the worker thread or in a kernel.
- **Benefit**: bounds the path share of every tick (estimate: to the budget). Makes the cost independent of how long the requested routes are.
- **Cost**: medium. Needs a search whose work can be counted and stopped, so not `AStarGrid2D.get_id_path`, which is one call (an own search over the rectangle mesh, §5.3). A budget that a single search can exceed needs either resumable searches or a rule such as "a search that starts always finishes; stop starting new ones once the budget is spent" (simpler, bounded by one worst route, and what Zero Hour does, `AIPathfind.cpp:5923-5935`).
- **Frozen inputs**: a search spread over ticks must see the map as of its request, or map changes must apply only at a fixed phase after delivery (Recoil's order, §4.4). Undelivered routes go into the snapshot.
- **Risks**: adds at least one tick before a unit starts moving. Counting Wargrid's existing 2-tick start delay from standstill (`START_DELAY_TICKS`, `simulation.gd:20`, `:580`) from the request instead of from route assignment keeps the total unchanged for units starting from rest; a moving unit that is re-ordered keeps its old route for that tick. Likely invisible (estimate; check in the P5 playtest). Re-pins traces.
- **Validation**: a new benchmark row "group order across Ashfall" (§6, X2): max tick and `service_paths` p99 before and after, routes equal to the reference grid search where both find one, digests equal across platforms.
- **Smaller alternative, worth doing before P5**: keep `AStarGrid2D` and today's grid, lower the cap to 2-3 requests per tick, or count route length (cells) against a per-tick budget. Today's searches are cheap (0.057 ms p50), so this bounds the burst at little cost, at the price of slower group starts (each unit in a 30-unit group waits up to 10-15 ticks; estimate).

### 5.3 Coarse search graph with own tie-breaks, plus goal sharing — **Spike first (inside P5)**

- **Reference**: §4.4. Pathing spike method B (branch `spike-pathing`, `docs/reference/pathing-timing-spike.md` there): rectangle mesh p50 0.164 ms against grid 1.777 ms per long route (measured 2026-11-10), about 700-760 rectangles against about 145,000 cells.
- **Wargrid code**: `grid_navigation.gd` as a whole; `destination_allocation.gd` (reachability via components stays).
- **Problem**: cost per long route (§5.2) and engine coupling: `AStarGrid2D` and `AStar2D` tie-breaks are Godot's and unread, so a port or a Godot upgrade can change paths silently (determinism rules, "Couplings").
- **Shape**: rectangle mesh per size class as the search graph; search written in typed GDScript with an explicit tie-break (f, then g, then node index). A search over about 700 nodes is small enough that GDScript speed may be acceptable (estimate, unmeasured). Then a funnel or line-of-sight straightening as in the spike. For a group order: one backward search from the goal per (goal cell, size class, tick), shared by every unit of the order (Warzone 2100's idea, reduced to a per-order cache that is dropped at the end of the tick).
- **Benefit**: against P5's finer grid, about 11× cheaper per route at p50 including straightening, and about 57× for the search alone (1.19 against 0.021 ms; measured, engine C++ for both searches). Straightening is 87 % of B's time, so a slower own GDScript search costs less than it seems. Also engine-independent tie-breaks and a natural work counter for §5.2. Against today's coarser grid it is not cheaper.
- **Risks**: the spike measured straightening as 87 % of B's route time, so the search is not the main cost. Incremental mesh updates when buildings land are unmeasured. Paths are up to 29 % longer in the worst case (measured). Feel must be checked behind the P5 toggle.
- **Validation**: X3 in §6: GDScript search time p50 and p95 over the spike's 200 pairs, against `AStar2D` on the same mesh. Route lengths within a stated tolerance of the grid reference.
- **Smaller alternative**: Zero Hour's route (`AIPathfind.cpp:6399-6407`): a hierarchical zone path first, then the cell search restricted to the passable zones. Keep the cell grid and `AStarGrid2D` but restrict its region to a corridor from the coarse path. It keeps today's behaviour closest, but keeps the Godot tie-break coupling.

### 5.4 Desync localisation: per-tick core hash ring and a restore twin — **Adopt soon**

- **Reference**: §4.6 (OpenRA per network frame plus 7 detailed reports, Warzone 2100 12-tick log, 0 A.D. quick hash and serialization twin, Recoil checksum history).
- **Wargrid code**: `state_hash.gd` `core_check`; `lockstep.gd` (`_hash_interval`, `desync_report`); `simulation.gd` `_snapshot`; tests `test_skirmish_match.gd` `S1_CORE_SERIES`.
- **Problem**: a desync is found up to 30 ticks late and the report holds one snapshot, so the first diverging tick and field must be found by hand. No test shows that a simulation restored from a snapshot continues identically.
- **Shape**: (a) the simulation keeps a ring of the last 64 per-tick hashes over the `core_check` fields plus `rng` (corrected 2026-11-13: `core_check` covers only units and player credits, `state_hash.gd:16-27`; the ring must also cover buildings, sources and the RNG, since the snapshot keeps them separately, `simulation.gd:665-666`), computed from live state at the end of `step()` without a snapshot, hashing floats by their raw bits (`core_check` quantises them as `floori(value * 1024.0)`, `state_hash.gd:31`, so a sub-1/1024 divergence would stay invisible for ticks). The desync report includes the ring, so a diff names the first tick a covered field differs. Sending a per-tick hash over the wire is a network question; leave it to the netplay work. (b) A test-only restore: `Simulation.from_snapshot(snapshot)` (or the movement milestone's schema) at tick N, step both copies 600 ticks with the same commands, compare `core_check` every tick and the full digest at the end. It runs on the golden scenarios.
- **Benefit**: desync triage goes from a 30-tick window to one tick; hidden-state bugs show up in CI before they show up in a friend's match. It is also the oracle for D1 (packed-array storage): run old and new storage side by side and compare per tick.
- **Cost**: (a) one pass over entities per tick, comparable to `step.ids` (0.008-0.039 ms on the rows above; estimate by analogy, measure). (b) the restore path is the real work and belongs with the movement milestone's unit schema, as the user decided.
- **Risks**: none for match behaviour: (a) reads state only. The ring must not enter the snapshot.
- **Validation**: (a) cost per tick on team match and hordes300 (X4); an injected change to a covered field at tick T must show as the first difference at T (fields outside the hash are found only by the twin and the 30-tick digest). (b) the twin passes on all golden scenarios; a deliberately unsnapshotted field makes it fail.
- **Smaller alternative**: lower the hash interval from 30 to 5 ticks in test runs only. Cheap, but it still does not name the field.

### 5.5 One spatial index per tick, in packed arrays — **Spike first (with D1)**

- **Reference**: Recoil, OpenRA and 0 A.D. keep a persistent index and update it on moves. Warzone 2100 rebuilds once per update at one fixed point, shared by all readers until the next one (`loop.cpp:648-651`). Both work; which is cheaper in GDScript is the open question.
- **Wargrid code**: `combat.gd` `_build_grid`/`_bucket`/`_nearest`; `horde.gd` `_bucket`; `simulation.gd` `_unavailable_cells`; `combat.gd` `splash_victims`.
- **Problem**: four structures, three of them Dictionary-of-Array with `Vector2i` keys, rebuilt by different rules; 9 % of `step` for the target grid alone (measured).
- **Shape**: once per tick after movement, a counting sort of ground objects by cell into two packed arrays (`cell_start: PackedInt32Array`, `ids: PackedInt32Array`), owner and position columns beside them. Every reader uses it. This is what the ledger's recommendation 4 ("persistent grid with incremental updates") aims at, with the opposite update policy.
- **Why rebuild, not incremental, as the first candidate**: an incremental index pays Dictionary work for every moved unit on every tick and has its own invalidation bugs; a packed rebuild is one linear pass and cannot go stale. Recoil reduces incremental cost by checking quads only every 3 frames per unit (`UnitHandler.cpp:406`). Wargrid could not copy that without giving up exact queries.
- **Benefit**: estimate only: the 9 % target-grid share shrinks, the horde bucket and `_unavailable_cells` passes disappear, and splash becomes indexed (§5.1).
- **Risks**: result order must stay "ascending id" wherever it is used for tie-breaks (`_nearest` already breaks ties by id, `combat.gd:347`). Re-pins nothing if queries return the same sets.
- **Validation**: X5: three variants (today, packed rebuild, Dictionary incremental) on hordes300 and team match; `combat.build_grid` plus `combat.nearest` zone means; digests equal.
- **Smaller alternative**: §5.1 alone, on today's grid.

### 5.6 Soft movers, hard stationary blockers — **Spike first (avoidance work)**

- **Reference**: §4.5. Traced in 0 A.D., Recoil and Permafrost (Zero Hour's flags suggest it); OpenRA is the counterexample.
- **Wargrid code**: today none (movers overlap); the avoidance spike prototypes on branch `spike-avoidance`.
- **Problem**: the user wants units to go around each other (user, 2026-11-07); every spike round so far missed the +0.5 ms p95 cap or jammed packed 300-unit moves.
- **Shape (design input, not a design)**: a parked unit blocks its cell for path search and for movers; a moving unit only pushes and is pushed (0 A.D.-style, per-cell neighbours from §5.5's index, with pressure damping so crowds settle); waiting units wake when a cell frees (Permafrost's counter).
- **Benefit**: no measurement exists for Wargrid. 0 A.D.'s comment says pushing is "dwarfed by regular motion costs" in C++; in GDScript the n²-per-cell loop is the same shape as the horde spike's separation loop: 69 % of a 2.24 ms tick for 1,000 agents (measured, performance next §5.3).
- **Risks**: float push accumulation is order-sensitive. Recoil's shape: each unit gathers the pushes on itself into its own force during the parallel pass (`GroundMoveType.cpp` `forceFromMovingCollidees`), so every unit writes only itself and neighbours are iterated in index order. Cost may again miss the cap in GDScript, which makes this the most likely first native-kernel candidate.
- **Validation**: the avoidance spike's own rows (packed and split 300-unit moves finish, p95 cost inside the cap), plus "units just stood there" counts in the P5 playtest.
- **Smaller alternative**: keep overlap during travel and resolve only at arrival (today's destination allocation), which is what main does.

### 5.7 Split rates for target choice — **already decided; scope it narrowly**

- **Reference**: Recoil 15 frames, OpenRA 3-8 ticks, Warzone 2100 1 s, 0 A.D. per 200 ms turn.
- **Wargrid code**: `combat.gd` `plan` `:93-147`.
- **Finding**: Wargrid already scans for new targets on an 8-tick stagger. The per-tick part of `combat_plan` (53 % of `step` on the goal row) is keeping the current target: record lookup, hostility, range, engage or chase. The references also do that every tick (OpenRA's attack activity, Recoil's weapon `Update`). Running it less often changes how quickly a unit reacts to a target leaving range, which is feel. So split rates can cut only part of `combat_plan`; the earlier deferral experiment found little (ledger 2f/2k, quoted in performance next §6 E).
- **Recommendation**: apply split rates to the decisions the references also slow down (rescans, retaliation joins, return-home scans), keep per-tick target keeping, and expect the per-unit constant to come from D1 storage, not from cadence. Validation: `combat_plan` zone and the M4 combat feel checks.

### 5.8 Stagger bot decisions by seat — **Adopt soon**

- **Reference**: Recoil's per-unit slow-update slices (`UnitHandler.cpp:348-366`); Warzone 2100's per-droid stagger (`ai.cpp:1238`). Recoil's team update is not staggered (`TeamHandler.cpp:146-154`).
- **Wargrid code**: `skirmish.gd:11` (`DECISION_TICKS = 30`), `issue_opponents` `:67-72` (one `snapshot()` and every bot on `tick % 30 == 0`).
- **Problem**: `opponent.decide` max 7.589 ms on one tick of the team match (measured).
- **Shape**: bot seat k decides on `tick % 30 == k % 30`, each with its own snapshot or, better, with the view rows plus the few fields bots read.
- **Benefit**: the shared `snapshot()` is about 1.0 ms of the 7.6 ms (team match `snapshot` max 1.029 ms), so with one snapshot per seat the worst bot tick falls to about 2.3 ms (derived, if decision cost splits evenly). (Corrected 2026-11-13: the team match has six bot seats, so (7.589 − 1.029) / 6 + 1.029 ≈ 2.1 ms; and a full `snapshot()` per seat means six snapshots per 30 ticks instead of one, about +0.09 ms on the mean tick at the snapshot zone's mean of about 0.53 ms per call (+0.17 ms at its 1.029 ms maximum). Each staggered bot needs a state no older than its own decision tick, or one snapshot reused across the window (a few ticks stale for later seats); a light per-bot state avoids both.) The spike is offline and on the client that hosts a bot; each netplay client runs only its own seat's bot.
- **Risks**: changes bot command ticks, so re-pins team-match traces and `TEAM_CORE_SERIES` (corrected 2026-11-13: the 1v1 bot, seat 2, moves too, so 1v1 skirmish traces re-pin as well). In netplay each client runs only its own seat's bot (design answers, "Bot memory"), so no cross-client effect.
- **Validation**: team match `opponent.decide` max and `step` max; bot behaviour tests unchanged apart from tick offsets.
- **Smaller alternative**: none smaller.

## 6. Benchmark and validation plan

Each experiment isolates one hypothesis, runs headless on the Mac mini, records load, and ends in a ledger row or an evidence note. No budget, ceiling or benchmark definition changes; new rows are report-only until the user makes them gates.

| # | Hypothesis | Experiment | Acceptance |
|---|---|---|---|
| X1 | Splash scans cause the contact worst ticks | one profiler zone around `splash_victims` on the contact row (**done today**, §3.3) | confirmed: 8.8 of 10.3 ms (sample), 19.8 of 23.3 ms (warm-up). After §5.1: contact `combat_fire` max below 2 ms (proposal) and every replay trace unchanged |
| X2 | Path bursts are long routes, and a node budget bounds them | new report-only row: 3 seats each order 60 units across Ashfall on the same tick; count searched nodes per tick (own search) or route length (today) | `service_paths` max and `step` max before and after; with the budget, no tick's path work exceeds the budget plus one route; digests equal on macOS, Linux, Windows |
| X3 | An own GDScript search over the rectangle mesh is fast enough | the pathing spike's 200 pairs, own search against `AStar2D` on the same mesh | p95 per route under the share P5 assigns to pathing (to be set in the P5 plan); routes equal or same length |
| X4 | A per-tick core hash ring is nearly free | `core_check` over live state every tick on team match and hordes300 | mean under 3 % of `step` mean (proposal); injected one-field change found at its tick |
| X5 | Packed rebuild beats both today's grid and an incremental Dictionary grid | three variants, same queries, hordes300 and team match | `combat.build_grid` + `combat.nearest` mean; equal digests |
| X6 | No system is superlinear in unit count | scaling row: the combat open layout at 50, 100, 200, 400, 800 units; `step` mean, p99, max per size | zones whose time grows faster than the unit count are listed (splash and `_unavailable_cells` are the expected ones) |
| X7 | Native and browser digests stay equal | the golden scenarios in the Firefox web bench (today manual) | all digest lines equal; one CI job later, only if cheap |

Practices worth taking from the references:

- **Worst tick with its tick index and zone, per row.** Already there (`PROFILE_SLOW`). Keep reporting warm-up separately: the contact row's worst ticks (21-27 ms) are in warm-up and the gate does not see them.
- **Profile at the level of a slice.** Recoil times every phase of ground movement separately (`GroundMoveSystem.cpp` `SCOPED_TIMER` per stage). Wargrid's `step.advance` mixes movement, containers, horde bonus and salvage; split that zone before P5 so its gain can be attributed.
- **Replays as benchmarks.** 0 A.D. replays a recorded match headless and checks the recorded hashes (`ps/Replay.cpp:286-320`). Wargrid's team match and replay traces already do this. Add one recorded real playtest match (P1 feedback runs) as a row, because synthetic layouts miss late-game shapes.
- **Allocation**: GDScript has no per-script allocation counter. A report-only row of `Performance.get_monitor(Performance.MEMORY_STATIC)` before and after 1,800 ticks would catch leaks, not churn. Whether that monitor reports in release builds is unverified. Churn is better measured indirectly through the WebAssembly factor per row, which the ledger already does.
- **Machines**: the Steam Deck is paused (user, 2026-11-11). Every target number here is Mac × F = 5.5, derived.

## 7. Proposed roadmap

Low risk first; each step is started by the user and has its own measurement. It fits the agreed order (golden scenarios after movement, interpolation rework, `SimPump`, worker only after a browser measurement).

1. **Now, no re-pin**: X1 (done today, §6), then §5.1 index-backed splash. X4 and §5.4 (a), the core hash ring. Split the `step.advance` zone. One ledger row.
2. **Small re-pin batch** (one re-pin for both): §5.8 bot staggering, and the smaller alternative from §5.2 (lower request cap or a cell budget on today's grid), which bounds today's 7.1 ms burst cheaply.
3. **P5 movement and pathing** (packages): §5.2 deferred delivery with a node budget, §5.3 rectangle mesh with own search (X3 first), goal sharing for group orders, capped incremental mesh updates, X2 as its benchmark row. Movement state in packed arrays (D1) as already decided. §5.4 (b) restore twin with the new unit schema.
4. **Avoidance**, on P5's columns: §5.6, with §5.5 (packed per-tick index, X5) as its neighbour query. First native-kernel candidate if the push loop misses its cap in GDScript.
5. **Combat on columns** with split rates scoped as in §5.7, together with the next combat re-pin.
6. **Later**: worker thread per its design; kernels only under systems measured hot; diff-based range queries only if a horde mode makes scans dominant.

## 8. Rejected approaches

| Approach | Seen in | Why not for Wargrid |
|---|---|---|
| Fixed-point maths now | OpenRA, 0 A.D., Warzone 2100 | Wargrid's float rules already give bit-equal native and browser digests (measured on 8 workloads, ledger); converting re-pins everything and costs readability in GDScript. Revisit only with a native port, as decided (user, 2026-11-09). |
| `streflop`-style deterministic libm | Recoil | Wargrid bans every libm function except `sqrt`, which is exact in IEEE 754. Nothing to fix. |
| ECS or component framework (EnTT, 0 A.D.'s component manager, OpenRA traits) | Recoil, 0 A.D., OpenRA | Their frameworks serve hundreds of thousands of lines, mods and scripting. At 3,900 lines a framework adds indirection without a measured win; packed columns per system (D1) get the data-layout benefit without one. Blueprint §11 already says not to prebuild an ECS. |
| Parallel work inside a tick | Recoil, 0 A.D., Warzone 2100 | measured 2-3 % at 4 threads, a loss at 2 (ledger "Technology findings"); the browser build would need threads and cross-origin isolation for it. The "compute, then apply in order" shape is still worth keeping for kernels. |
| Lower global sim rate (5-10 Hz) | 0 A.D., Warzone 2100 | the user chose split rates; 30 Hz matches Zero Hour's feel and keeps command latency low. |
| Diff-based range queries everywhere | 0 A.D. | needs a sorted set difference per query per turn; it pays when queries are rare and populations large. On the goal row the scan (`combat.nearest`) is under 6 % of `step` (measured). |
| GPU or compute-shader movement | Permafrost | not deterministic across devices; WebGL has no compute path. |
| Persistent per-tick path cache across ticks | Warzone 2100 (within a tick only), Permafrost (LRU fields) | correctness depends on invalidation; a cache whose hits change results is a determinism hazard (Warzone 2100's own warning, §4.4). Only the per-order, per-tick sharing in §5.3. |
| Hard cell occupancy for movers | OpenRA | matches the avoidance spike rules that jammed packed moves; the other engines avoid it. |
| AI on its own thread with a state copy | 0 A.D. (tried, abandoned) | copying state per decision was the blocker there, and Wargrid's bot already pays a full `snapshot()` per decision. Stagger first (§5.8). |
| Whole port to Rust or C++, or adopting an engine | | prior Wargrid work (native spike, performance next) shows a step-by-step route to the same gain; no reference engine runs in the browser with lockstep and a scene engine Wargrid could keep. |

## 9. Evidence trail

| Recommendation | Reference evidence (code) | Wargrid evidence |
|---|---|---|
| 5.1 splash index | OpenRA `WorldUtils.cs:69-75`; Recoil `QuadField.cpp:152-170` | `combat.gd:511-521`; contact `combat_fire` max 10.426 ms, warm-up 21-24 ms (measured today); splash zone probe today: `combat.splash_scan` max 8.804 / 19.842 ms |
| 5.2 deferred paths, work budget | Recoil `QTPFS/PathManager.cpp:826-837`, `:1117-1169`, `Systems/SyncUpdatedPathsSystem.cpp:39-41`; 0 A.D. `CCmpPathfinder.cpp:126-131`, `:840-893`; Warzone 2100 `fpath.cpp:570-600`; Zero Hour `AIPathfind.cpp:1103`, `:5927` | `simulation.gd:19`, `:464-469`; team match `service_paths` max 7.149 ms (measured today) |
| 5.3 coarse graph, goal sharing | Recoil QTPFS (`rts/Sim/Path/QTPFS/`), BAR `gamedata/modrules.lua:98`; OpenRA `HierarchicalPathFinder.cs:21-100`; 0 A.D. `helpers/HierarchicalPathfinder.h`, `LongPathfinder.h:271`; Zero Hour `AIPathfind.cpp:6399-6407`; Warzone 2100 `astar.cpp:22-40`, `:671-673`, `fpath.cpp:291-294` | pathing spike (branch `spike-pathing`) §3, §8; `grid_navigation.gd:5-23`, `:108-127` |
| 5.4 desync localisation | OpenRA `World.cs:482-513`, `Network/SyncReport.cs:25-59`; Warzone 2100 `lib/netplay/sync_debug.cpp:297`; Recoil `System/Sync/SyncChecker.h:11-49`; 0 A.D. `ComponentManagerSerialization.cpp:106-125`, `Simulation2.cpp:400-470`, `ps/Replay.cpp:256-267` | `state_hash.gd:16-27`, `lockstep.gd:35`, determinism rules "State digest" |
| 5.5 per-tick packed index | Warzone 2100 `loop.cpp:648-651`; Recoil `QuadField.cpp:525-549`; OpenRA `ActorMap.cs:598-601`; 0 A.D. `CCmpRangeManager.cpp:653-686` | `combat.gd:295-314`, `horde.gd:54-62`, `simulation.gd:318-331`; `combat.build_grid` 9 % of `step` (measured) |
| 5.6 soft movers | 0 A.D. `CCmpUnitMotion_System.cpp:63-110`; Recoil `GroundMoveSystem.cpp:105-140`; Zero Hour `AIPathfind.h:271-273`; Permafrost evaluation §2 | avoidance spike (branch `spike-avoidance`); performance next §5.3 |
| 5.7 split rates scope | Recoil `UnitHandler.cpp:348-376`, `Weapon.cpp:730`, `:793-829`; OpenRA `AutoTarget.cs:80-83`, `:277-304`; Warzone 2100 `ai.cpp:1238`, `action.h:117`; BAR `luarules/gadgets/unit_continuous_aim.lua:21-60` | `combat.gd:93-147`; `combat_plan` 53 % of `step` on skirmish3v3 (measured) |
| 5.8 bot stagger | Recoil `UnitHandler.cpp:348-366`; Warzone 2100 `ai.cpp:1238` | `skirmish.gd:11`, `:67-72`; `opponent.decide` max 7.589 ms (measured) |
| No AI thread with state copy | 0 A.D. `CCmpAIManager.cpp:97-106` | worker-thread design §2 "hand-off: gap" |

## 10. Not verified

- No reference engine was built or run; every reference statement is from reading source at the revision named. No reference performance number is quoted because none is committed in those repositories for the mechanisms discussed.
- The Zero Hour cell flags were read only in the header; how the pathfinder uses `UNIT_PRESENT_MOVING` against `UNIT_PRESENT_FIXED` was not traced.
- OpenRA's actor-occupancy behaviour (waiting, nudging) is described from general knowledge of its `Mobile`/`Locomotor` design, not traced in this review.
- QTPFS's node structure was identified by file names and the quadtree terminology in `PathManager.cpp` (`QTNode::MAX_DEPTH`, `:670-675`), not read in full.
- No Steam Deck, no browser run today; every target figure is Mac × F = 5.5.
- `Performance.MEMORY_STATIC` in release builds: unverified.
- The hordes300 row's `combat_fire` worst tick (5.4 ms) has no splash weapon behind it; its cause was not investigated.
- Cost estimates for §5.4 (a), §5.5 and §5.8 are unmeasured.

## Review 2026-11-13

Reviewed with the user against `main` (no simulation file changed since `4b444a2`). Decisions: [design answers](design-answers-2026-11-08.md#simulation-reference-review-user-2026-11-13).

**Implemented 2026-11-13 night (local branch `sim-quick-wins`, not pushed):** §5.1 splash index, §5.4 (a) hash ring with `desync_bisect.py`, X6 scaling row and the `step.advance` zone split; evidence in the [verification file](sim-quick-wins-verification.md). X1 (contact `combat_fire` max below 2 ms) is not met: 2.711 ms. The ring pushed combat `dense` p95 to 1.832 ms (budget 1.82) even with a cheaper `_tick_hash`: accepted as an exceeded row (user, 2026-11-14).

**Where the items went.** Sim quick wins package (rough rest of [packages](../packages.md), no re-pin): §5.1 splash index, §5.4 (a) per-tick hash ring with wider coverage plus the desync bisect tool (moved there from Relay guards), the `step.advance` zone split, X6 scaling row, a profiler pass on the hordes300 `combat_fire` worst tick. Flatter worst ticks package (one re-pin): §5.8 bot stagger with a light per-bot state, §5.2's smaller alternative (path cap by route cells, Zero Hour style). Movement design inputs (design answers): §5.2 deferred delivery with a node budget, §5.3 own search with explicit tie-breaks (X3 first), goal sharing, capped mesh updates. Avoidance design inputs: §5.6 soft movers, §5.5 packed per-tick index (X5). §5.7 split rates scoped to scans. X7 with the golden scenarios after movement; a recorded playtest match as a row with P5's canary rider. §5.4 (b) restore twin stays in the movement milestone (user, earlier). §8's rejections agreed.

**Claims re-checked in code:** the splash scan and id sort (`combat.gd:511-521`); cannon `delay_ticks` 60 and blast radii (`definitions/shared.gd`), the ±2.72 window for the default infantry blast (`INFANTRY_BLAST` 0.52 plus `MAX_TARGET_RADIUS` 2.2; the pickup cannon needs ±4.05); the step order that makes the lazy combat grid stale for splash (grid in `plan` before construction, production, path service and movement; `fire` after movement); `PATH_REQUESTS_PER_TICK` 8 and `_service_paths`; one shared snapshot and every bot on `tick % 30 == 0`; `core_check` quantising floats to 1/1024; 89 `Vector2(` sites; 864 and 3,880 lines in 26 files. Every measured figure matches the logs; profiler zones are summed per tick before the maximum (`profiler.gd`). Reference citations spot-checked: Zero Hour's 5,000-cell budget (a started search finishes) and cell flags, Recoil's slow-update slices, unstaggered team update and single-threaded synced writes, OpenRA's 3-8 tick scan and 7 sync reports, Warzone 2100's goal sharing, 0 A.D.'s abandoned AI thread.

**Corrections** (marked in place): bot stagger about 2.1 ms with six seats, a full snapshot per seat raises the mean tick by about 0.09 ms (up to 0.17), and the 1v1 traces re-pin too; the hash ring must cover buildings, sources and the RNG (it is one combined hash per tick, not the per-subsystem sync rings the netplay review deferred); every weapon with a blast radius splashes, the pickup cannon's window is ±4.05, and the index must also serve `fire_defences`; Warzone 2100's first search runs forward.

**Still unverified:** as in §10; also whether both splash maxima fall on the same tick (both are volley-tick maxima, the probe did not log tick indexes per zone).

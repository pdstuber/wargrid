# Performance spike: profiling zones and hotspots (2026-11-05)

Status: **MEASURED; FOLDED INTO M6 TASK 11 (user, 2026-11-05)**. Branch `spike-performance` on `781ab5a`. Tasks 1, 3a, 3b, 4a, 4b, 4d and 5 below are M6 Task 11 sub-tasks 11a–11h in the [M6 plan](../superpowers/plans/2026-11-05-m6-teams-full-map.md), with exact code and tests. Task 4c was replaced there by a replay-safe variant: shared read-only map lists (11d), which keep the hash. Task 11e (one bot snapshot shared per decision tick) is new, from M6 Task 1's Ashfall costs. User approvals: incremental navigation, shared bot snapshot, cached map lists. Not approved: combat bins (6). Deferred: static terrain batch (2), because big-map presentation is out of M6 scope, and live-state presentation (L). Budgets and the slowdown factor F = 6 come from the [performance ledger](performance.md); nothing here changes them.

## Method

- **Zones**: `game/scripts/debug/profiler.gd`. Each zone is a `Profiler.begin()` / `Profiler.end(&"name", t)` pair, off by default (one bool check). Zones are inclusive and dotted (`step.combat_plan`). Results per tick go through `timing_stats.gd`. Single calls of 1 ms or more are logged with their tick number. Ideas from OpenRA `PerfHistory` / `PerfTickLogger` (`OpenRA.Game/Support/`) and Recoil `SCOPED_TIMER` (`rts/System/TimeProfiler.{h,cpp}`).
- **Headless**: `sh tools/run_profile.sh`, which reports only and never gates. It runs 7 scenarios: 300 warm-up ticks plus 1800 measured unpaced ticks, then the full scripted skirmish match to its end (tick 9939). Each tick also performs the scene's plumbing: one `snapshot()` (two for the skirmish match, as `base_main._refresh` does) and `WorldView.set_state` on an off-tree view.
- **Large probe**: `CombatWorkload.create_large()`, synthetic and not Ashfall. It is a 196×196 map with 8×8 blocks every 20 cells (4,032 cells, 10.5 % blocked). Each owner has 3 lanes of 60 units that attack-move across. At ticks 600 and 1200 an 8×8 obstacle is added and removed through `_replace_union`, the same path as a building placement or death. The armies never meet within 2100 ticks, so this measures the approach only. `GridNavigation`'s size assert was raised from 64 to 256 for it.
- **Rendered**: `sh tools/run_game.sh res://scenes/movement_benchmark.tscn -- --profile` runs the normal open and dense legs, plus a 196×196 leg, with zones on. Run once, `vsync=off`, 1280×720, zoom 0.5.
- **Native**: `/usr/bin/sample` for 8 s during the large workload. The official Godot binary is stripped, so only libc symbols resolve.
- **Machine**: Apple M6, Godot 4.7.2 official, Compatibility renderer. The first runs overlapped with another game on the machine and were discarded. All numbers below come from the idle reruns.

### Disabled overhead

On the idle rerun with the zones compiled in but off, `sh tools/run_benchmark.sh` passes. Movement p95 is 1.587 / 1.615 ms, against the ledger's last rows of 1.573 / 1.611 (inside the ±0.03 noise). The other p95 values: combat open 1.634, dense 2.155, contact 0.739, skirmish3v3 0.856 ms. Lockstep p99 is 0.069 ms.

## Measurements (ms per tick unless noted; dev machine)

| Scenario | step mean (p95) | snapshot | view copy | view sort | biggest step zone |
|---|---|---|---|---|---|
| movement open, 300 units | 0.33 (0.37) | 0.50 | 0.70 | 0.59 | `advance` 0.24 (72 %) |
| movement dense | 0.34 (0.39) | 0.54 | 0.73 | 0.62 | `advance` 0.25 (71 %) |
| combat contact | 0.37 (0.79) | 0.07 | 0.08 | 0.14 | `combat_plan` 0.17 (45 %) |
| combat skirmish3v3 | 0.55 (0.90) | 0.16 | 0.19 | 0.21 | `combat_plan` 0.30 (55 %) |
| combat open | 0.97 (1.72) | 0.33 | 0.43 | 0.38 | `combat_plan` 0.63 (65 %), of it `nearest` 0.19 |
| skirmish match, 69 entities peak | 0.20 (0.30) | 0.13 (2 per tick) | 0.07 | 0.06 | `combat_plan` 0.09 |
| **large 196×196, 360 units** | 1.24 (1.33) | **2.33** | **3.21** | 0.75 | `combat_plan` 0.68, `advance` 0.40 |

Plumbing (snapshot + view copy + sort) is 1.79 ms at 64×64 against the 0.83 ms ledger budget, and **6.29 ms at 196×196**, about 38 ms at F = 6, which is more than a whole 33 ms tick. Snapshot cost at 196×196 grows with the map, not the units: every tick copies the static map's blocked and terrain cells as `[x, y]` arrays.

### Spikes (single tick)

| What | Where | Max |
|---|---|---|
| `Allocation.assign` sort, six 60-unit attack-move groups | large tick 0 | **566 ms** (549 of it in the sort), about 3.4 s at F = 6 |
| same, six groups | skirmish3v3 tick 0 | 52 ms |
| same, one 300-unit move | movement, each leg | 9.6 ms |
| allocation from combat (retaliation or go-home) | contact, inside `combat_fire` | 22.5 ms |
| navigation rebuild (`replace`), of it components 70 | large, obstacle add or remove | **73.8 ms** |
| fresh `Navigation.new` (what `Construction.preview` builds per placement, twice per build) | large, scratch split | 72 ms |
| `navigation.build` on 48×32 | skirmish match, placement | 7.8 ms |
| `opponent.decide`, one seat | skirmish match, decision tick | 2.5 ms (six seats at M6: about 15 ms, unmeasured) |

Scratch split of the 70 ms component rebuild at 196×196: re-sorting the region's shuffled cell list with `_cell_before` takes about 44 ms. The real input is in flood-fill order, so the true share is unmeasured, probably similar.

### Rendered (one run)

| Leg | frame interval p50 / p95 (ms) | draw calls | `_draw` mean (ms) | of it terrain |
|---|---|---|---|---|
| open 64×64 | 1.49 / 4.71 | 603 | 0.48 | 0.03 |
| dense 64×64 | 1.76 / 5.75 | 747 | 0.88 | 0.42 |
| **196×196** | **198 / 241 (about 5 fps)** | **4,755** | **10.26** | **9.60** |

At 196×196 the CPU side of `_draw` costs about 10 ms. Most of the rest of the 198 ms frame is presumably the renderer working through about 4,000 per-cell terrain polygons plus 394 grid lines; I have not split it. The sim kept pace (backlog under 2 ticks).

Native sample: about 38 % of active main-thread samples are `malloc`/`free`/`memset`, which fits the deep-copy churn.

### Not a problem today

- A* stays cheap: `get_id_path` start to start at 196×196 takes 0.02 ms (185 points), and the `route` zone peaks at 0.54 ms per tick under the 8-per-tick cap. Hierarchical pathing (OpenRA `HierarchicalPathFinder`, Recoil QTPFS) and path sharing are not needed yet.
- Lockstep encode, decode and hash: p99 0.069 ms.

## Proposed tasks (ranked by impact at M6 scale)

Proposals as measured on 2026-11-05; for their current status, see the status line above. The savings are estimates unless they say measured.

| # | Task | Evidence | Idea and source | Replay / hash risk | Pin | Size |
|---|---|---|---|---|---|---|
| 1 | **Allocation without a full-component sort** (ledger P4) | 566 ms at 196×196 tick 0; 9.6 ms per 300-unit order; 22.5 ms combat spike | Yield candidate cells lazily in `_before` order by expanding Chebyshev rings around the target cell. Sort only the current ring, and stop once the next ring's minimum distance exceeds the worst taken candidate. Expected work about units × ring cells instead of C log C (C ≈ 34k). | None if the goals are identical | Property test: old vs new goals on seeded maps and groups; counter for cells examined with a ceiling | M |
| 2 | **Static terrain drawn as one batch** | 196×196: about 5 fps, 4,755 draw calls, terrain `_draw` 9.6 ms; dense: 0.42 ms | Build one mesh (or a baked texture) for blocked cells plus the grid when the map changes; draw it with one `draw_mesh` on a separate terrain node that does not redraw per tick. OpenRA `TerrainSpriteLayer`: one static vertex buffer, dirty rows only. Off-screen unit culling later (OpenRA `ScreenMap`). | None (presentation) | Headless: terrain `_draw` count stays 1 across 10 `set_state`; rendered rerun | S–M |
| 3a | **Component lists without `sort_custom`** | 70 ms rebuild at 196×196, about 44 ms of it sort (scratch, shuffled input) | Label cells by flood fill as now, then fill each component's list in one row-major pass. Same order with no comparator. | None (N7 pins row-major order) | N7 unchanged; counter or zone ceiling | S |
| 3b | **Incremental navigation on placement and death** | `Navigation.new` 72 ms at 196×196, twice per build; 7.8 ms on 48×32 | Change only the cells that changed (`set_point_solid`). Recompute components only when connectivity can change (OpenRA dirty blocks, `HierarchicalPathFinder.cs` 588–637). Let the preview test reachability without building a whole grid. | Moderate: placement rejection paths | `navigation_builds()` plus a new cell-update counter | M |
| 4a | **View takes the snapshot without a deep copy** | Largest single zone in movement: 0.70 ms per tick (2.1× step); 3.21 ms at 196×196 | `snapshot()` already returns a private copy. Drop `duplicate(true)` in `WorldView.set_state`. Changes the V1 contract "set_state copies": callers must not mutate after handing it over (today only HUD reads follow). | None (presentation) | V1 rewritten to the new contract | S |
| 4b | **One snapshot per refresh** | skirmish: 2.03 snapshots per tick | Make `base_main._refresh`'s first snapshot the one passed to `super._refresh` instead of a second call. | None | Snapshot calls per tick in a scene test | S |
| 4c | **Static map out of the per-tick snapshot** | Snapshot 0.50 ms at 64×64 vs 2.33 ms at 196×196 with similar unit counts | Snapshot carries a map version. Blocked and terrain cells come from a separate accessor when the version changes. | **Changes `state.hash()` digest** (`PINNED`), snapshot node ceilings and replay fixtures; both netplay peers need the same build | `PINNED` re-pin and node ceilings, user-approved | M |
| 4d | **Depth sort on packed integer keys** | 0.59 ms per tick for 300 units | Sort a `PackedInt64Array` of `depth_key << 32 | index` natively, then reorder. OpenRA `WorldRenderer.cs` 25, 163–168. Skip the sort when no unit moved. | None | V-test on draw order unchanged | S |
| 5 | **Cache per-kind definition lookups** | `advance` is 72 % of a movement tick | `Definitions.unit(kind)` builds a Dictionary literal per moving unit per tick. Same for `Definitions.building` in `distance_squared`, and `CombatDefinitions.weapon/profile` per shot. Cache per kind like `Combat._reach_by_kind`. | None (same values) | Replay and suite unchanged; zone before and after | S |
| 6 | **Combat planning detail** | `combat_plan` is 55–65 % of combat step; `build_grid` about 10 %, `nearest` about 20 % | First add zones inside the per-unit loop. Persistent bins updated on move (OpenRA `ActorMap`, Recoil `QuadField` with `MayHaveEnemyUnits` early-out) would remove `build_grid` only. | Low to moderate | `combat_work` ceiling | S (zones), M (bins) |
| L | Presentation reads live state | All plumbing rows | Render from the live simulation (read-only) plus previous and current positions per unit. Recoil `preFrameTra` interpolation, OpenRA renders the live world. Snapshot stays for hash and replay only. Also enables 60 fps interpolated motion. | Low for sim; large refactor of scenes and tests | Scene tests | L |

Named only, out of scope: Dictionary entities to struct-of-arrays storage (touches every system and every trace).

Suggested order: 1, 3a, 4a, 4b, 5 (small and replay-safe), then 2 with a rendered rerun, then 3b and 4c (need approval: hash and placement paths), then 6. Expected effect, unmeasured: 1 and 3a remove the M6 freezes; 4a+4b+4d cut 64×64 plumbing from 1.79 to about 0.6 ms (snapshot only); 2 should bring 196×196 rendering back to the 64×64 range.

## Not done

- Ashfall itself: the large map is synthetic. Six seats and teams do not exist yet; the large probe uses two owners.
- Large fight: the armies never met within 2100 ticks.
- Renderer-side split of the 196×196 frame (GPU vs canvas batching); one rendered run only.
- `Construction.preview` at 196×196 was not run through a real build command; the 72 ms is the scratch `Navigation.new` split.
- Native symbols: the binary is stripped.
- The skirmish scene itself was not rendered under profiling.

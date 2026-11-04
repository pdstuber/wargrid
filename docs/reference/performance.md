# Performance ledger

Status: **TARGET-DERIVED BUDGETS PROPOSED; TWO OF FOUR CURRENTLY EXCEEDED; TWO COMBAT STRESS LAYOUTS EXCEEDED (REPORT-ONLY); EXISTING GATES UNCHANGED**. One place to track performance across milestones for a low-end target, including a browser (WebAssembly) build. Measurements on this Mac are weak evidence for that target; this note makes the assumption explicit and replaceable.

## Target device (assumption, not measured)

- **Slowdown factor F = 6** relative to the development machine (Apple M6, 12 cores). This is a chosen planning number, not a measurement. Replace it with the factor from a real web export under Chrome CPU throttling or on real low-end hardware as soon as one exists; every derived budget below is `target budget ÷ F`. I have no data on how GDScript performs under WebAssembly, and render/GPU slowdown need not equal CPU slowdown.
- Simulation 30 Hz: a tick is 33.3 ms. Render goal 60 fps: 16.7 ms.

## Budgets

Existing gates (unchanged, in `game/benchmarks/run_movement.gd` and the rendered probe): sim-only tick p95 ≤ 8 ms and p99 ≤ 16 ms on the development machine; rendered frame p95 ≤ 16.7 ms. The sim gate is about 5× looser than the current cost, so it does not protect a low-end target.

| Metric | Share chosen on target | Target budget | Dev-machine budget (÷F) | Current (dev machine) | Status |
|---|---|---:|---:|---:|---|
| Sim-only tick p95 (300 units moving, includes command allocation) | 30% of a tick | 10 ms | 1.67 ms | 1.50 open / 1.53 dense | passes, about 9–10% margin (headless benchmark 2026-11-03) |
| Sim-only tick p99 | 60% of a tick | 20 ms | 3.3 ms | 1.57 / 1.60 | passes |
| Presentation plumbing per tick (`snapshot` + view deep copy + sort) | 15% of a tick | 5 ms | 0.83 ms | about 1.9 ms (0.69 + 0.67 + 0.57, scratch probe, not a repo tool yet); snapshot size is gated by node count below | **exceeded** |
| Rendered frame interval p95 (300 units, vsync off, includes tick frames) | full frame | 16.7 ms | 2.8 ms | 4.1 open / 6.5 dense | **exceeded** |
| Lockstep overhead per tick p99 (`finish_tick` + `receive`: encode, decode, digest on hash ticks; excludes sim step and snapshot) | 10% of a tick | 3.3 ms | 0.55 ms | 0.060 (contact) | passes |

Watch items, no gate: worst sim tick 7.8 ms on the dev machine (command ticks, path queue burst), which would be about 47 ms on the target, longer than a tick. Dense-map worst rendered frame 19.5 ms.

### Known M4 combat cost risks (found by code review 2026-11-03, unmeasured)

Both risks come from the Tasks 1–4 code (`game/scripts/simulation/combat.gd`). Neither is fixed. Task 9a's `contact`/`open` layouts are the measurement. Fixes need user approval.

1. **Full enemy rescan (confirmed by the scratch spike in History: 12.5–15.3 ms p95).** A guard or attack-move unit with no valid in-range target scans every enemy object every tick (`Combat._nearest`). Retaining a valid target skips the scan, but approaching armies have none. Cost grows as armed units × enemy objects: 150 v 150 advancing is about 22,500 distance checks per tick, and `combat_work()` counts them. The plan names a candidate fix: a coarse grid index for acquisition.
2. **Attack-move halt/resume thrash.** A halted attack-move unit resumes when its target leaves range or dies, through `_assign_move` → `Allocation.assign`. Resumes are batched to one call per goal group per tick, but each call costs 2.2–2.4 ms on 48×32 and 6.0–6.3 ms on 64×64 ([envelope](m4-scenario-envelope.md)): about 1.3–3.8× the whole 1.67 ms p95 budget. A fight at a range boundary can trigger a call on many ticks. Plan Task 4c adds `allocation_calls()` so 9a can report how often this happens. Candidate fixes, not designed: a short resume cooldown, or resuming toward the previous destination without reallocation.
**Decision 2026-11-03 (user approved P1 and P2; implementation is plan step 4d, assigned to Sonnet):**
- **P1: throttled acquisition.** 15-tick staggered rescans for untargeted units; immediate on spawn, order or target loss.
- **P2: halted attack-move units keep their slot.** They resume without `Allocation.assign`.
- **Source basis:** Zero Hour `MoodAttackCheckRate` (default 2 s, `AIUpdate.cpp` 89, 4566–4576), immediate retarget on loss (`AIStates.cpp` 3617–3641), and attack-move re-pathing to its existing goal (`AIStates.cpp` 3661–3664), at revision `0a05454`.
- **Scratch prototype results (reverted, not in tree):**

| change | contact p95 | open p95 | open ticks with an allocation pass |
|---|---|---|---|
| before | 12.5 ms | 15.3 ms | n/a |
| P1 | 1.31 ms | 6.6 ms | 119, about 7.5 ms each |
| P1 + P2 | 1.41 ms | 1.69 ms | 1 |

- **Remaining:**
  - `open` sits at the 1.67 ms line; 300 moving units alone cost about 1.58 ms.
  - Worst tick, about 28 ms: the initial attack-move command allocation, outside Task 9a's 300-tick warmup, but about 170 ms at F = 6.
  - Further options, not approved:
    - P3: grid index for acquisition.
    - P4: ring-expansion `Allocation.assign` instead of a full component sort. P4 also helps M2 command ticks but touches replay-compared M2 code.

3. **Mass pursuit spike (Grok review).** `_firing_cell` scans the target's range box (rifle about 9×9 cells, cannon about 13×13, plus a building's footprint). If 150 units get `attack` in one tick, or their chase destinations are invalidated on the same 15-tick beat, that is about 25,000 cell tests in one tick, on top of the existing command-tick path burst. Unmeasured; it shows up as `combat_work()` max in Task 9a.

Derived budgets are proposals. Do not loosen a budget or the factor to make a row pass; either optimize, or ask the user to change the target. M4 snapshots add combat fields, so plumbing will grow; the cheapest fix is probably to stop copying the whole state twice per tick (not designed).

## History

All rows: this Mac, Godot 4.7.2, Compatibility renderer, 64×64 map, 300 units, unpaced headless unless noted. Sources are the linked notes; scratch logs are outside the repo.

| When / milestone | Metric | Open | Dense | Source |
|---|---|---|---|---|
| M3 final (before `303006b`) | sim-only tick p50 / p95 / p99 / max (ms) | 0.950 / 1.452 / 1.495 / 7.803 | — / 1.487 / 1.548 / 7.789 | [M3 verification](m3-verification.md) |
| 2026-11-03 before terrain fix | rendered frame p95; frames in 60 s; backlog | 320 ms; 205; growing (140 ticks) | 340 ms; 189; growing (244 ticks) | [M2 verification](m2-verification.md) |
| 2026-11-03 terrain fix, vsync on | rendered frame p95; backlog | 19.6 ms; none | 19.5 ms; none | same |
| 2026-11-03 terrain fix, vsync off (benchmark disables it) | rendered frame p50 / p95 / p99 / max (ms) | 1.2 / 4.1 / 6.4 / 13.1 | 1.6 / 6.5 / 10.2 / 19.5 | same |
| 2026-11-03 headless benchmark after terrain/speed changes | sim-only tick p50 / p95 / p99 / max (ms) | 0.979 / 1.500 / 1.573 / 8.031 | 1.007 / 1.526 / 1.601 / 8.058 | `sh tools/run_benchmark.sh`, `BUDGET PASS` both |
| 2026-11-03 same run | in-scene tick p95 (step + plumbing + label) | 4.56 ms | 4.79 ms | same |
| 2026-11-03 scratch headless probe | step / snapshot / view copy / sort p50 | 0.32 / 0.69 / 0.67 / 0.57 ms | 0.33 / 0.72 / 0.68 / 0.58 ms | same |
| 2026-11-03 scratch spike (no combat) | `Allocation.assign` ms per call, 20 / 150 units | 48×32: 2.18 / 2.41; 64×64: 5.98 / 6.25 | same | [M4 envelope](m4-scenario-envelope.md) |
| 2026-11-03 scratch spike | ticks units wait for routes after one building is removed (150 moving) | 19 | — | same |

| 2026-11-03 M4 Task 1 (uncommitted, `m4-combat`) | snapshot node ceiling at step 38 (`hp`, `max_hp`, `combat` per unit = +6; `combat_events`, `match` root = +4) | 81,285 (was 79,481); busiest unit 328 (was 322) | 82,149 (was 80,345) | `test_snapshot_size_ceiling`, ceilings raised deliberately |
| 2026-11-03 M4 Tasks 1–4 (uncommitted) | sim-only tick p50 / p95 / p99 / max (ms) | 1.038 / 1.559 / 1.627 / 8.198 | 1.064 / 1.592 / 1.652 / 8.013 | `sh tools/run_benchmark.sh`, `BENCHMARK PASSED 2`; budget 1.67 passes, margin ~5% |
| 2026-11-03 M4 scratch spike after Task 4 (not the Task 9a tool) | 150 v 150 (100 infantry + 50 tanks per side, 10-wide blocks), 64×64 empty map, 2100 unpaced ticks, sim-only tick p50 / p95 / max (ms); `combat_work` per tick | contact (blocks 3 cells apart, guard): 11.7 / 12.5 / 27.9; ~37,500 checks per tick | open (attack-move across the map): 5.8 / 15.3 / 33.6; 45,000 checks per tick while approaching | scratch `combat_spike.gd`, outside the repo; **7.5–9× over the 1.67 ms budget, and also over the old 8 ms dev gate**; confirms risk 1 below |

| 2026-11-03 M4 Task 9a combat benchmark (uncommitted working tree on `m4-combat` at `e8e5401`; Apple M6, Godot 4.7.2, headless, 300 warmup + 1800 measured unpaced ticks) | sim-only tick p50 / p95 / p99 / max (ms), budget p95 ≤ 1.67, p99 ≤ 3.3 | open: 0.642 / 1.600 / 1.813 / 2.404 PASS; dense: 0.480 / 1.638 / 2.332 / 2.906 PASS | contact: 0.165 / 0.540 / 0.785 / 1.502 PASS | `sh tools/run_benchmark.sh`, `COMBAT BENCHMARK PASSED 3` |
| same run | snapshot cost p50 / p95 / p99 (ms; reported, outside the sim gate) | open 0.321 / 0.820 / 0.870; dense 0.280 / 0.824 / 0.890 | contact (final layout) about 0.07 / 0.19 / 0.21 | same |
| same run | `combat_work` p50 / p95 / max per tick; `allocation_calls` | open 792 / 3,004 / 5,383; dense 530 / 3,334 / 7,613; allocations 0 | contact 204 / 732 / 3,260; allocations 0 | same; tick-0 peak in `contact` is 45,300 checks (every unit scans once, inside warmup), pinned by `test_combat_work_ceiling` |
| same run | shots; deaths; units alive start → end | open 4,773; 152; 300 → 148. dense 5,848; 191; 300 → 109 | contact 7,804; 232; 300 → 68 | first shot at tick 299 (open), 284 (dense), 0 (contact) |
| same run, **warm-up ticks 0–299, not gated** | sim-only tick p50 / p95 / p99 / max (ms) | open 1.614 / 1.662 / 1.705 / **27.557**; dense 1.624 / 1.679 / 1.747 / **27.471** | contact 0.522 / 1.074 / **3.414** / **16.018** | same runner, `warmup_tick_ms`; open/dense warm-up includes the approach with 300 units walking, tick 0 includes the two 150-unit attack-move orders; contact warm-up holds almost the whole fight |
| 2026-11-03 M4 rendered rerun after the WorldView changes (uncommitted `m4-combat`; Apple M6; Compatibility renderer; 1280×720, zoom 0.5, `vsync=off`; headless sibling run idle) | rendered frame interval p50 / p95 / p99 / max (ms); tick p95; engine draw calls; backlog | open 1.455 / 3.979 / 6.615 / 16.876; tick p95 4.687; 603 draw calls; cumulative lag 0.09 ticks after 60 s | dense 1.678 / 5.162 / 7.945 / 12.080; tick p95 4.941; 747 draw calls; lag 0.06 ticks | `sh tools/run_game.sh res://scenes/movement_benchmark.tscn`, `RENDERED BENCHMARK PASSED 2`, exit 0, zero `ERROR`; first draw-call reading; frame p95 passes the 16.7 ms line; the 6× low-end assumption is not applied to this row |
| 2026-11-04 M4.1 rendered rerun (`m4.1-polish` ee9e63c; Apple M6; Compatibility renderer; 1280×720, zoom 0.5, `vsync=off`) | rendered frame interval p50 / p95 / p99 / max (ms); tick p95; engine draw calls | open 1.236 / 3.649 / 6.262 / 10.823; tick p95 4.734; 603 draw calls | dense 1.575 / 5.195 / 8.562 / 17.108; tick p95 5.080; 747 draw calls | `sh tools/run_game.sh res://scenes/movement_benchmark.tscn`, both legs `RENDERED COMPLETE`, 300 arrived; frame p95 passes the 16.7 ms line (fast Mac, low-end 6× not applied); skirmish scene opened 300 frames, exit 0, zero `ERROR`. Rendered skirmish presentation (rally marker, enemy line, pile labels) was not viewed by a person |
| 2026-11-03 M4 skirmish-scene plumbing (committed `023e0ae`; Apple M6, headless scratch probe driving `skirmish.tscn`'s own `_step_simulation` and `_refresh`, both players on the opponent policy, 7,671 ticks to a terminal state, peak 41 entities) | per tick p50 / p95 / p99 / max (ms): step+opponent; refresh (snapshot, view copy, HUD); total | 0.168 / 0.225 / 0.348 / **19.17**; 0.146 / 0.208 / 0.220 / 0.479; 0.322 / 0.402 / 0.520 / **19.23** | | scratch probe outside the repo; at the assumed 6× slowdown typical ticks are about 2.4 ms, the spike about 115 ms |
| same probe | spike cause: ticks 0, 420, 870, 1350 (one building placed per player). `GridNavigation` construction or `replace_blocked_cells` costs 2.4 ms on 48×32 and 7.0 ms on 64×64; one `build` command triggers it four times (`preview_build` at issue, `_validate` again when due, `Construction.place` → `preview`, then `rebuild_navigation`), about 9.6 ms per placement | — | — | M3-era code path, not introduced by M4; building deaths pay one rebuild each; `BaseMain._update_preview` calls `preview_build` on every mouse move while placing, so placement mode costs 2.4 ms per motion event (about 14 ms at 6×). **Not fixed; reported for a user decision.** |
| 2026-11-03 placement fix (uncommitted on top of `023e0ae`) | same skirmish plumbing probe: step+opponent max; spike ticks | **11.0 ms** max (was 19.2); placement ticks 9.5–11.0 ms (two placements each) | | due-time build check skipped (placement re-checks once), placement reuses its preview grid as the live grid (`navigation_builds()`: 4 → 2 per build, `test_build_navigation_cost`), hover preview recomputed only when the cell or tick changes (`test_preview_hover_cost`); suite 137 / 103,906, benchmarks pass. Remaining per placement: one grid at issue plus one at placement, about 4.8 ms here, about 29 ms at 6× |
| same run | movement benchmark (unchanged workload) sim-only p95 (ms) | open 1.573, dense 1.611 | | `BENCHMARK PASSED 2` |

Reading the M4 rows (superseded for combat by the M4.1 section below): all three combat layouts pass the headless budget, but `open` (1.600 vs 1.67) and `dense` (1.638 vs 1.67) have only 4% and 2% margin (run-to-run noise is about ±0.03 ms), and the movement benchmark has about the same. The final `contact` layout (3 columns × 50 rows per side, tanks and infantry interleaved, fronts 2 cells apart, so rifles and cannons both fire from tick 0) resolves most of the fight inside the 300 warm-up ticks (232 deaths), so its gated window is light; the warm-up numbers above are the real contact cost, and they exceed the p99 budget (3.3 ms) and spike to 16–28 ms on tick 0. Those spikes are outside the gate by the plan's fixed window. The budget already assumes the 6× slower target, so there is no headroom for further per-tick combat work. The timed window excludes the tick-0 scan spike (45,300 checks). The rendered movement benchmark was rerun after the WorldView changes and passes (row above); the Skirmish scene itself (HP bars, cues, labels under combat) has not been rendered under load. Unmeasured: plumbing in the Skirmish scene (opponent decision and snapshot each tick), web export, other machines. Not checked: the review's moving-target-chase and unreachable-attack layouts (not built).

### M4.1 combat benchmark (scan, cadence 8)

Tree: `m4.1-polish` after the Task 7 commits plus the Task 8 working tree (committed with this row). Apple M6, Godot 4.7.2, headless, 300 warm-up + 1800 measured unpaced ticks, rebuilt 8-cell grid scan, `REPATH_TICKS = 8`. Budgets unchanged: p95 <= 1.67 ms, p99 <= 3.3 ms.

| Layout | tick p50 / p95 / p99 / max (ms) | Status |
|---|---|---|
| `contact` (gated) | 0.147 / 0.454 / 0.630 / 1.446 | PASS |
| `skirmish3v3` (gated, 35 units per owner per lane, 210 units) | 0.333 / 0.754 / 0.996 / 1.449 | PASS, about 2.2x headroom on p95 |
| `open` (150 v 150, report-only stress) | 0.860 / 1.891 / 3.383 / 4.859 | **exceeded** against 1.67 p95 (p99 passes) |
| `dense` (150 v 150, report-only stress) | 0.686 / 2.243 / 3.684 / 8.225 | **exceeded** against 1.67 p95 and 3.3 p99 |

- **Stress ceilings** (user decision 2026-11-03): `open` p95 / p99 <= 2.05 / 3.86, `dense` <= 2.52 / 4.02 ms, pinned in `run_combat.gd` as the worst of 13 runs + 5% (run-to-run noise up to 0.06 ms p95 and 0.3 ms p99 on `open`/`dense`); the benchmark fails above them. Raising one needs user approval and a new row.
- **Cadence** (user approved measuring 8 first, 2026-11-04; 3 runs each, p95 / p99): `contact` 0.451-0.463 / 0.624-0.637 (15: 0.448-0.454 / 0.624-0.630); `skirmish3v3` 0.742-0.769 / 0.963-0.988 (15: 0.729-0.830 / 1.058-1.497); `open` 1.832-1.866 / 3.381-3.472 (15: 1.845-1.870 / 3.365-3.524); `dense` 2.259-2.278 / 3.591-3.705 (15: 1.959-2.021 / 3.208-3.286). Both gated layouts pass at 8, so 8 is kept (matches retail `MoodAttackCheckRate` 250 ms); `dense` p95 rises about 0.3 ms, which is why its ceiling is 2.52. The grid is on in every row; a no-grid `skirmish3v3` run was not repeated at Task 8 (Task 1 spike: 0.769 / 0.849 without the scan, 0.810 / 0.997 with scan and grid at cadence 15).
- **Mechanics inside the window**: scans that acquire a target beyond weapon reach (`scan_chases`), warm-up / window: `open` 54 / 2,876, `dense` 72 / 2,878, `skirmish3v3` 82 / 529, `contact` 102 / 62. The benchmark fails a layout (other than `contact`) with zero in the window. Mutation (scan radius set back to weapon reach in a scratch copy): `Combat benchmark never chased inside the timed window for open`, exit 1.
- **Warm-up spikes (not gated)**: max tick 16.7 ms (`open`), 16.1 (`dense`), 10.0 (`contact`), **35.7 ms (`skirmish3v3`, tick-0 `attack_move` allocation for six groups)**; about 215 ms at F = 6.
- **Rally spawn spike (own row, no gate)**: 20 consecutive single-unit `_assign_move` calls on the 48x32 skirmish map take 1.91-2.03 ms each (Task 1 scratch measurement, not repeated), about 12 ms at F = 6 on the tick a unit spawns.
- **Machine-independent**: `contact` peak `combat_work` 22,704 (was 45,300 before the grid), ceiling in `test_combat_work_ceiling` lowered to 23,900.
- Rendered rerun pending (asked once at Task 9, batched with the playtest).

## Rule per milestone

A milestone exit gate is not met until: `sh tools/run_benchmark.sh` passes, the rendered benchmark was rerun if presentation changed (`sh tools/run_game.sh res://scenes/movement_benchmark.tscn`, header must show `vsync=off`), and this ledger has a new History row with measured values against the budget table, with the machine named. Missing or exceeded rows are reported as exceeded, never as passed.

## Machine-independent counters

Wall-clock numbers vary with hardware; these do not, so they can gate in ordinary headless tests.

| Counter | Where | Current | State |
|---|---|---|---|
| Snapshot size in nodes (each dictionary key, value and array element counts 1) for the 300-unit workload at its peak, 38 steps into leg 0 | `test_snapshot_size_ceiling` in `test_benchmark.gd` | open 79,481; dense 80,345 (peak, after 38 steps); busiest unit 322 | **gated ceiling.** The snapshot is deep-copied twice per tick, so growth is plumbing cost. A change that adds fields fails the test; raise the ceiling deliberately and add a History row. M4's added unit fields will trip it by design (Task1). |
| Path queue peak and drain after a 300-unit group command | printed by both benchmarks | peak 292, drain 38 ticks | reported, not gated beyond the existing 3000-tick leg limit and the 8-queries-per-tick cap |
| Engine draw calls per rendered frame (`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`) | `movement_benchmark.gd` `RENDERED SAMPLE ... draw_calls` | earlier scratch probe: about 601 | added 2026-11-03, **no rendered run yet with the benchmark print**; renderer batching dependent, so only comparable on one renderer |
| Combat target checks per tick | planned in M4 Task9a | — | not implemented |

Not feasible or not done:

- **Canvas commands per frame, in tests.** No headless API reports them (the dummy renderer reports zero draw calls) and `draw_*` methods cannot be overridden to count. The terrain regression is covered by the rendered benchmark instead.
- **A\* node expansions.** Navigation uses Godot's built-in `AStarGrid2D.get_id_path`, which exposes no work counter; counting would mean reimplementing it. The 8-queries-per-tick cap plus the queue figures above are the available proxies. Worst command-tick spike (7.8 ms on the dev machine) is probably this work, unproven.

## Not covered yet

CI does not run any benchmark; trend logging on the Linux/Windows/macOS runners (slower than the dev machine) is a candidate. A web export under CPU throttling would replace F with a measurement.
| 2026-11-04 M5 Task 8 lockstep benchmark (`m5-online`, Apple M6, headless, `contact` layout, 300 warmup + 1800 sample ticks, delay 4, hash every 30) | lockstep overhead per tick p50 / p95 / p99 / max (ms); snapshot on the 60 hash ticks p50 / p95 / p99 (ms, reported, presentation cost) | 0.007 / 0.014 / 0.060 / 0.164; 0.059 / 0.140 / 0.179 | | `sh tools/run_benchmark.sh`, `LOCKSTEP BUDGET PASS`, `LOCKSTEP BENCHMARK PASSED 1`; window asserts 60 hash ticks and a non-empty packet in all 60 thirty-tick windows; 32 of 300 units alive at end. Two instances, one sim stepped; peer-side digest not timed. Rendered rerun pending user approval (batch with Task 10) |

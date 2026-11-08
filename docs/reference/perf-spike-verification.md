# Performance spike verification

Handoff: [performance-spike-prompt.txt](../performance-spike-prompt.txt). Ledger: [performance.md](performance.md). Dated evidence rows below the record are append-only.

```text
Resume record (updated 2026-11-07 23:30)
Branch / base commit / working-tree state: main / 7c9d615 (2b bce4b79, 2c f62cf70, 2e dropped 7c9d615 all committed) / uncommitted: game/tests/test_combat.gd (RAD rename), docs/reference/performance.md (2e row moved), this file (2f design, Task 2g)
Last green task / next incomplete task: Task 2d (Horde.step, uncommitted, acceptance green, see '2d result'); before it Task 2h (A1 lazy records, uncommitted in game/scripts/simulation/combat.gd, acceptance green, team match +0.5-1 % marginal, see "2h result") / then Task 2d scratch profiling of `advance.horde`, then post-removal plan / `firing_cell` profiling; 2f-B NOT recommended
Changed paths since last commit: game/tests/test_combat.gd, docs/reference/performance.md, this file
Last command / cases / checks / failures / exit / marker: accept.sh bce4b79 PASS (suite 484 cases / 136037 checks / 0 failures); A/B bench_ab.sh 3 rounds exit 0 ALLDONE
Known red case or blocker: none. Report-only rows exceeded: combat open, dense, hordes300
Approved decisions, pre-authorizations used, deferred gates: user invoked the spike 2026-11-07; works on main; local commits after green checkpoints pre-authorized; no push/PR/merge/fly/Sprite/window without approval; host = this Mac only (user). Decisions of 2026-11-07 evening: BM6 retune approved together with 2e; 2f approved with a version bump and a ZH AIUpdate comparison; second round for 2d and per-cell enemy counts; hordes300 "improved, still exceeded" is acceptable; C++/GDExtension NOT investigated (user decision); threads PoC local first, fly web deploy allowed for the threaded-web test only, Safari failure is not a blocker, a Chromium-based browser (e.g. Vivaldi, not installed yet) is acceptable for the Chrome check; Steam Deck check tomorrow; user asleep, run all approved work, pausing only on a stop condition
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: Workstream 2 round 2 gate review (2i BLOCKED: post-removal extras and `advance.move` profiled, no fix above the A/A spread; see '2i result')
```

## Evidence

| Date | Tree | Host | What | Result |
|------|------|------|------|--------|
| 2026-11-07 | deec14d | Apple M6 | start check | load 1.70 / 1.33 / 1.48; ZH parity process pid 50629 running (not ours) |
| 2026-11-07 | deec14d + game/benchmarks/run_calibration.gd (uncommitted) | Apple M6 | calibration 2 min, ZH pid 50629 alive at start (0.7 % CPU, gone by end), Codex app-server daemons idle, WoW/Battle.net not running | load 1.26 start / 1.29 end; per-minute p50 0.698 / 0.699, p95 0.719, p99 0.730, max 1.07 / 0.97 ms |
| 2026-11-07 | deec14d + run_calibration.gd (uncommitted) | Apple M6 | calibration 2 min, apps closed by user, ZH killed, only idle Codex daemons | load 1.26 start / 1.43 end; per-minute p50 0.693 / 0.695, p95 0.712 / 0.715, p99 0.722 / 0.725, max 1.25 / 0.81 ms; p99 within 4.3 % of p50 |
| 2026-11-07 | deec14d | MacBook Air | clone moved to deec14d detached (was m7-factions 11672f4) and script scp-copied (uncommitted); 12 min run started at load 3.38, killed after about 1 min by user decision; Air dropped, partial run discarded, clone left as is | no numbers |
| 2026-11-07 | 3ffa26c + run_profile.gd/run_profile.sh edits (uncommitted) | Apple M6 | Task 1a: profile `-- new`; combat_dense units 300->97, combat_hordes300 400->292 (deaths inside window), team_match hit 45000-tick cap ongoing, peak 160; lint+warnings exit 0 | exit 0, PROFILE COMPLETE 3; load 1.27 |
| 2026-11-07 | 20a4d06 (git archive) | Apple M6 | Task 1b/1c baseline: 3x movement, combat, lockstep, team match, 1x profile; run_calibration/run_profile edits not in the archive | all exit 0, no BUSY; load 1.16-1.30 for movement/combat/lockstep/team1; team2 end load 2.12 (only run over 2.0, team3 start 2.12, end 1.62); table below |
| 2026-11-07 | e11b2fe (git archive) + scratch run_bucket.gd | Apple M6 | Task 1d bucket measurement: open, dense, hordes300 one at a time, no godot/ZH process before each | exit 0 x3; load 1.75 start / 1.76 end (22:16); table in the finding |
| 2026-11-07 | e11b2fe-equivalent HEAD c683426 (git archive) + scratch sub-zones, `_nearest` counters, `run_2a.gd` | Apple M6 | Task 2a: open, dense, hordes300 one at a time, headless, profiler on, no godot/ZH process before each (pgrep empty), 22:25; the scratch copy was not linted or run through the suite (Task 2a keeps no code) | exit 0 x3, `TWO_A COMPLETE`; load 1.56 start / 1.40 end; result below |
| 2026-11-07 | HEAD c17e88d + Task 2b working tree (uncommitted) vs git archive of c17e88d | Apple M6 | Task 2b acceptance: suite, lint, warnings, 4 traces cmp, netplay, team match, A/B A B A B A B of run_movement.gd and run_combat.gd (headless), no godot/ZH process before | suite 483 cases / 136034 checks / 0 failures (base 482 / 136033 with traces); lint, warnings exit 0; traces identical (1200, 1200, 1200, 100 rows); netplay match PASSED tick 8400; team match exit 0 `cap tick=45000 winner=null units_peak=160`; load 1.82 start / 1.69 end; table in '2b result' |
| 2026-11-07 | HEAD bce4b79 + Task 2c working tree (uncommitted) vs git archive of bce4b79 | Apple M6 | Task 2c acceptance via scratchpad accept.sh and bench_ab.sh: suite, lint, warnings, 4 traces cmp, pins, netplay, team match, A/B A B A B A B of run_movement.gd and run_combat.gd (headless), no godot/ZH process before | suite 484 cases / 136037 checks / 0 failures (base 483 / 136034); lint, warnings exit 0; traces identical; 7 pin lines equal; netplay match PASSED tick 8400; team match exit 0 `cap tick=45000 winner=null units_peak=160`; load 1.93 start / 1.25 end; table in '2c result' |
| 2026-11-08 | HEAD c3e1e91 + Task 2d working tree (uncommitted) vs git archive of c3e1e91 | Apple M6 | Task 2d acceptance via accept.sh and bench_ab.sh (3 rounds, plus a second 3-round combat run), team match and lockstep A B A B A B by hand; no godot process before | suite 485 cases / 136039 checks / 0 failures (base 484 / 136037); lint, warnings exit 0; traces identical; 7 pin lines equal; netplay match PASSED tick 8400; team match exit 0 cap line; load 1.5; table in '2d result' |

## Workstream 1 finding (baseline, 2026-11-07, 20a4d06, Apple M6, 3 runs each)

Budget p95 / p99 1.82 / 3.64 ms. Cells: median of 3 (spread = max - min over the 3 runs). Logs were in the scratchpad, not in the repo.

| Row | p50 | p95 (spread) | p99 (spread) | max | Verdict |
|-----|-----|--------------|--------------|-----|---------|
| movement open | 1.519 | 1.587 (0.025) | 1.766 (0.021) | 4.868 | pass |
| movement dense | 1.532 | 1.577 (0.012) | 1.788 (0.039) | 4.999 | pass |
| combat open | 1.556 | **2.763** (0.027) | **3.661** (0.029) | 4.674 | exceeded (p95 +52 %; p99 at the line: 3.661 vs 3.64, within the 0.029 spread); ceiling 3.05 / 4.23 holds |
| combat dense | 1.197 | **3.106** (0.044) | **4.659** (0.027) | 5.804 | exceeded (p95 +71 %, p99 +28 %); ceiling 3.31 / 5.01 holds |
| combat contact | 0.266 | 1.191 (0.014) | 1.720 (0.016) | 11.801 | pass (max 11.7-11.9 ms repeats in all runs: deterministic, unexplained) |
| combat skirmish3v3 | 0.592 | 1.426 (0.015) | 1.615 (0.011) | 1.893 | pass |
| combat transports | 0.768 | 1.467 (0.014) | 1.799 (0.015) | 2.392 | pass (the 1.85 seen loaded is gone) |
| combat defences | 0.097 | 0.956 (0.007) | 2.490 (0.043) | 2.997 | pass |
| combat docks | 0.773 | 0.879 (0.006) | 0.905 (0.005) | 0.956 | pass |
| combat hordes300 | 3.837 | **5.563** (0.036) | **7.050** (0.071) | 9.753 | exceeded (p95 3.1x, p99 1.9x; report-only, no ceiling) |
| combat ramp | 0.138 | 0.761 (0.008) | 1.444 (0.016) | 2.298 | pass |
| combat frc | 0.248 | 0.948 (0.009) | 1.273 (0.005) | 2.584 | pass |
| lockstep overhead | 0.009 | 0.016 (0.000) | 0.067 (0.002) | 0.163 | pass (limit 0.6 p99) |
| team match (45000 ticks, Ashfall, 3 factions) | 0.570 / 0.571 / 0.575 | 1.401 / 1.407 / 1.428 (0.027) | 2.887 / 2.897 / 2.915 (0.028) | 10.27-10.31 | pass at 1.82 / 3.64 |

Spread is under 0.075 ms on every row: all three runs agree, so a fix has to beat about 0.05 ms to be real. Load was 1.16-1.30 except around team2 (2.12 at its end), whose numbers sit inside the team1/team3 values, so no run is discarded.

Team match: the earlier "exceeded" (1.842 / 4.07 and 2.028 / 4.302, G3.5, loaded host) does not reproduce on a quieter host: p95 1.40-1.43, p99 2.89-2.92, p50 0.57 (was 0.742 / 0.793). Both gaps (p95 -23 %, p50 -23 %) are probably host load plus the economy rework; not separated, no bisect. Worst tick 10.27-10.31 ms (earlier 11.3-12.5); that max is the `TEAM TIMING` wall time of `TeamMatch.step` and its tick is not in any log (no per-tick output; the profiler's top-ten step ticks top out at 7.5 ms in the window and 8.4 ms at tick 0), so which tick it is stays unverified (tick 0 is the candidate). The profiler is on for the whole match including warmup ticks 0-299 (tick 0 step 8.4-8.5 ms, `apply_orders` 8.25 ms), so the timing includes profiler overhead. The cap is still hit (`winner=null`, `units_peak=160`).

Team match worst ticks (team1.log, profiler on; tick numbers are Profiler-relative, sim tick = number + 300; in-window step max 7.5 ms): tick 5430 `step.service_paths` 6.3 ms (A* 6.0 ms, `navigation.astar` max); ticks 90 and 480 `step.apply_orders` 5.6-5.8 ms (a command tick with a path batch); ticks 5104-5107 steps of 5-6 ms. Single-tick spikes in the top ten, all path planning or order application, none in combat (`PROFILE_SLOW_COUNT` 5874 in team1.log, 5998 in profile.log, different runs; threshold not checked). Not a budget problem (p99 passes); matters only for the max / frame hitch.

Top zones from `profile.log` (one profiler-on run, mean ms and share of the `step` mean; the `snapshot` zone is presentation plumbing, reported not targeted):

| Row | step mean (p50 / p95 / max) | 1 | 2 | 3 | Reading |
|-----|-----------------------------|---|---|---|---------|
| combat open | 1.599 (1.564 / 2.784 / 4.735) | `step.combat_plan` 0.994 (62 %, p50 0.92, p95 1.99, max 4.12) | `combat.nearest` 0.501 (31 %, 17.65 calls / tick, p50 0.395, p95 1.26, max 2.70) | `step.advance` 0.396 (25 %, p50 0.31, p95 0.70) | the average 1.6 ms is under 1.82; the p95 miss is the tail: p95 2.78 comes from `combat_plan` / `nearest` (p95 about 2x the p50); units die inside the window (open 300->124, dense 300->97, hordes 400->292), so the tail may be the early high-population phase (see the bucket table); the A/A spread (<0.075) shows run determinism only |
| combat dense | 1.505 (1.205 / 3.119 / 5.818) | `step.combat_plan` 0.995 (66 %, p50 0.72, p95 2.40, max 5.22) | `combat.nearest` 0.607 (40 %, 16.87 calls / tick, p50 0.242, p95 1.71, max 4.41) | `step.advance` 0.341 (23 %) | average 1.5 ms is inside the budget; the p95 miss is the `nearest` tail (p95 7x its p50) |
| hordes300 | 3.926 (3.869 / 5.621 / 9.792) | `step.combat_plan` 2.062 (53 %, p50 1.91, p95 3.25) | `step.advance` 1.631 (42 %, p50 1.63, p95 2.21) | `combat.nearest` 1.407 (36 %, 37.97 calls / tick, p50 1.32, p95 2.25) | flat average cost: the p50 alone (3.8) is 2x the budget; `advance` (movement) is a big share here (1.63 ms, 42 %: must be in the Workstream 2 task list, Task 2d covers it) |

Note: `combat.nearest` is nested inside `combat_plan`; shares overlap. The first tick of each case costs 10-14 ms (`combat_plan` 6.5-10.7 plus `apply_orders` 3.0, warm-up cache fill), not in the sample window.

When each failing row regressed (ledger, different loads and trees, no bisect): combat open p95 1.634 (2026-11-05 spike) -> 2.404 (M6 Task 13, 9310a2f) -> 2.72-2.80 (M7 gate 1, 7293c91 / 8f9b3cb, stable through 067bf58 and e2d48fc at 2.75-2.76) -> 2.763 now. combat dense 2.155 -> 3.07-3.15 over the same steps -> 3.106 now. So open has two steps: M6 (teams, full map; +0.77) and M7 gate 1 (factions; +0.3); dense was not measured at M6 (performance.md:137), so only the combined 2.155 -> 3.07-3.15 is known; 3.2-3.6 readings in later rows were host load (G3.5 load 2.7-3.5, post-economy load 3.18). Today's quiet numbers equal the gate-1 level, i.e. nothing regressed since gate 1. hordes300 was first recorded at 6.9 / 8.2 (G3.5, loaded) and 5.57 / 7.10 (98bf150); today 5.563 / 7.05, same level.

Gap (a), step time against units alive (scratch measurement, 2026-11-07 22:16, one run per layout, HEAD e11b2fe via git archive with a scratch-only `run_bucket.gd`, headless, profiler off, load 1.64-1.76, no other godot/ZH process; step ms per 300-tick bucket; ticks 0-299 are warm-up, the benchmark window starts at 300; p95 of 300 samples):

| Ticks | open alive (mean) | open mean / p95 | dense alive | dense mean / p95 | hordes300 alive | hordes300 mean / p95 |
|-------|------|-----------|-----|-----------|-----|-----------|
| 0-299 | 300 | 1.99 / 2.03 | 300 | 2.04 / 2.18 | 400 | 3.66 / 3.96 |
| 300-599 | 283 | 2.19 / 2.98 | 264 | 2.09 / 2.99 | 400 | 3.66 / 3.99 |
| 600-899 | 237 | 2.09 / 2.83 | 226 | 2.56 / 3.51 | 395 | 4.55 / 5.44 |
| 900-1199 | 196 | 2.11 / 3.05 | 168 | 2.18 / 4.29 | 356 | 4.97 / 6.72 |
| 1200-1499 | 146 | 1.35 / 2.77 | 104 | 0.91 / 2.00 | 309 | 4.38 / 6.25 |
| 1500-1799 | 126 | 0.90 / 1.11 | 97 | 0.60 / 0.67 | 292 | 3.25 / 3.95 |
| 1800-2099 | 124 | 0.78 / 0.91 | 97 | 0.55 / 0.63 | 292 | 2.43 / 2.85 |

Reading: the mean is about 6-7 microseconds per alive unit and tick on open / dense (1.99 / 300, 0.78 / 124, 0.55 / 97) and 8-9 on hordes300, so the cost scales with unit count, and before any contact (ticks 0-299, 300 alive) the mean is already about 2.0 ms, above the 1.82 p95 budget. The p95 miss is not a late tail: it sits in the high-population fighting phase (ticks 300-1500, p95 2.8-4.3, p95 / p50 about 1.4-2) and vanishes once fights end and the population has fallen (p95 under 1.2 from tick 1500). So both: a per-unit-count scaling floor, plus a fight-phase tail (death-triggered rescans) on top; the quiet late half of the window dilutes the window p50. Single run per layout, no A/A repeat.

Conclusion for the next step: the three failing rows share one cause, `step.combat_plan` with `combat.nearest` (31-40 % of the step, 17-38 calls a tick, a heavy p95 tail on open / dense); `step.advance` is the second block, large only on hordes300. Passing rows do not need work. The ceilings and budgets are unchanged.

## Workstream 2 tasks (Opus expansion, 2026-11-07, read against 20a4d06)

Code facts the tasks rest on (read, not measured):

- `Combat._nearest` (game/scripts/simulation/combat.gd:295-310) returns the minimum over the total order (distance, id) of every hostile candidate in its bucket window, so its result does not depend on iteration order; a building repeated in several buckets has the same (distance, id) and cannot win twice. Any change that keeps the candidate set a superset of the in-radius set and the distance expressions verbatim keeps the target, hence the traces.
- `sim._combat_work` counts only hostile candidates (combat.gd:303-304) plus `_in_range` calls and ring window cells. BM6 (game/tests/test_benchmark.gd:177-184) pins the contact tick-0 peak in (16000, 18500]. Skipping friendly candidates leaves it unchanged; examining fewer hostile ones lowers it.
- The grid (`_build_grid`, combat.gd:276-287, `GRID_CELL` 8) mixes all owners. Every friendly unit in the window costs one `hostile()` call (two `team_of` lookups, simulation.gd:75) before it is rejected. hordes300: militia reach scan, window 3.9 + 0.28 + 2.2 = 6.4 cells, i.e. 2-3 x 2-3 buckets inside a packed block of 300 friendlies. 38 calls / tick = 300 / `REPATH_TICKS` 8, at 37 µs per call: that is friendly rejection while marching, before contact.
- Tail on open / dense: a death calls `object_removed` (combat.gd:536-546), which sets `repath_tick = tick` and `retarget = true` for every human attack-mover on that target. All of them rescan on the same tick at `scan_reach` = vision x 2.2 (tank 13.2, rifle 8.8 cells; centre scan, 4-5 x 4-5 buckets covering both blocks) instead of weapon reach. Hypothesis: volley ticks make the p95 / p99 tail.
- Per candidate and per engaged unit, `edge_gap` -> `_gap_at` (combat.gd:44-50) calls `CombatDefinitions.radius` twice (combat_definitions.gd:16-20: `Registry.kind` takes up to 4 dictionary lookups, plus `building_view` for buildings) and `Definitions.building` up to twice. An engaged unit pays `edge_gap` up to three times a tick (`_left_range`, `_engage`/`_in_range`, `fire`).
- `combat.build_grid`, `step.ids` and `step.rates` are each under 0.035 ms mean (M7 gate 1, m7-verification-archive-gate1.md:15). A persistent shared grid for combat, horde, containers and docks would only remove that build cost, and M6 did not approve combat bins. Not proposed.
- Float trap: `Vector2` is float32 and the scalar code is float64. Every moved expression stays in its current form (no `Vector2` <-> scalar rewrites, no `length()` for `sqrt(dx*dx+dy*dy)`).

Per-task acceptance (every kept fix), on one tree, logged here with that tree:
suite 0 failures, case count >= 482 + new cases; `sh tools/run_lint.sh` and `sh tools/run_warnings.sh` exit 0; the four traces (`WARGRID_REPLAY_TRACE`, `WARGRID_ECONOMY_REPLAY_TRACE`, `WARGRID_COMBAT_REPLAY_TRACE`, `WARGRID_TEAM_REPLAY_TRACE`) written by the suite on the working tree and on a git archive of the round base, `cmp` identical; pins unchanged (S1 8501 / 8576069817585818203, Cs1 26359, Fm1 23534 winner 1, TB3 020f659e77ee6c20, TB4 7692526877276561850, H1 01e256834bdd4dfb, all inside the suite); `sh tools/run_netplay.sh match` PASSED at terminal tick 8400; `sh tools/run_team_match.sh` exit 0 with `TEAM MATCH cap tick=45000 winner=null units_peak=160`; for 2b-2d also the `combat_work=` summary of `run_combat.gd` identical A vs B on every layout (a second oracle). Timing: movement, combat, lockstep and team match, 3 runs A B A B A B from git archives, quiet Mac, load at start and end. The affected row must improve by more than its A/A spread (max - min of the 3 A runs that day, about 0.03-0.07 ms in Workstream 1), and no other row may get worse by more than its spread. Before / after go here, plus a ledger row in performance.md. Every Godot call uses `timeout: 600000`. Round base = the commit that closes Workstream 1 (the profile cases are already in 20a4d06; e11b2fe and later are docs only).

### Task 2a: measure before fixing (no kept fix, report-only)

- Target: `step.advance` block (simulation.gd:539-552) and `_nearest` (combat.gd:295).
- Do: add Profiler sub-zones `advance.move` (loop 542-545), `advance.containers`, `advance.horde`, `advance.salvage`, `advance.moved` (pattern of 505-552, off by default). In a scratch git-archive copy only (not committed), count per `_nearest` call the candidates iterated, the hostile ones and the scan kind (reach / scan_reach / passenger / return), plus deaths per tick, on open, dense and hordes300. Then one `run_profile.sh` run.
- Confirms or refutes: H1, friendly candidates are most of the `_nearest` loop (expected over 80 % on hordes300); H2, the `nearest` p95 ticks are the ticks after a death (retarget at scan_reach); H3, the biggest `advance.*` share on hordes300 (suspect `advance.horde`: `_cell_size` + `_bucket` over all 300 members nearly every tick, horde.gd:15-45).
- Acceptance: lint, warnings, suite (zones only, traces cmp-identical). If H1 is refuted, stop and re-plan 2b with Opus.

### Task 2b: per-owner target grid in `_nearest` (kept fix 1)

- Target: `_build_grid` / `_bucket` / `_nearest` (combat.gd:276-310); callers `plan` 114, `_plan_passenger` 151, `_plan_return` 629 unchanged.
- Design: bucket per owner, `{owner: {Vector2i: Array}}`. Build in the same entity-then-building order with the same filters. In `_nearest`, call `hostile(sim, unit.owner, owner)` once per owner key and skip non-hostile owners whole. Same `GRID_CELL`, same window, same `units_only`, distance and tie-break code. Drop the `grid.get(key, [])` empty-array allocation (`has` or a shared empty const). Hoist `CombatDefinitions.radius(unit.kind)` only inside the `edge` branch, because `_plan_return`'s scout has no `kind`.
- Why trace-identical: argmin over a total order is order-independent; the candidate set per call is the old set minus non-hostile objects, which the old loop rejected anyway; `_combat_work` is unchanged because friendlies were never counted.
- Proof, test first: a characterization case in game/tests/test_combat.gd, green on the old code and kept. It holds a test-local copy of the current `_build_grid` + `_nearest` as the oracle, builds 200 seeded random states (3-7 owners incl. shared teams and an owner without a player (team 0), units, air units, passengers, 1x1-3x3 buildings, a masked rebuild site), and asserts that the new `_nearest` returns the same id and the same `_combat_work` delta as the oracle for edge / centre / units_only scans. Reviewer check: the case fails if team-0 or same-owner handling, the tie-break or a bucket bound changes.
- Expected gain (estimate): hordes300 `nearest` 1.41 -> under 0.3 ms (p50 about -1 ms); open / dense `nearest` mean and tail minus their friendly share (perhaps -0.2 to -0.6 ms p95). Probably not enough alone for open / dense.
- Risk: low. Only one code path; argmin proof plus the oracle case.

### Task 2c: per-kind radius and building centre without repeated lookups (kept fix 2)

- Target: `CombatDefinitions.radius` (combat_definitions.gd:16), `_gap_at` (combat.gd:47-50), `distance_squared` (37-42), `_victim_centre` (551-553); used by `_nearest`, `_left_range`, `_engage`, `fire`, `Horde._level`, `Salvage._taker`.
- Design: memoize radius per kind in a Registry cache next to `_profile_cache`, cleared in `_reset()` (definitions.gd:113) so test kinds stay correct. In `_gap_at`, one `has("origin")` and one `Definitions.building` call. Same float expressions, same types.
- Proof, test first: a case asserting that `CombatDefinitions.radius` equals the uncached formula for every Registry kind and for a test kind added and then cleared (red only if the cache misses `_reset`). Equivalence comes from cmp-identical traces and `combat_work` summaries.
- Expected gain (estimate): 0.1-0.4 ms on open / dense p50 and p95 (about 3 edge_gap per engaged unit per tick x 300 units); small on hordes300.
- Risk: low. The only failure mode is a stale cache with test kinds, which the case covers.
| 2026-11-08 | ac1b7d4 via git archive, scratch `ws2i` (profiler zones, not linted) | Apple M6 | Task 2i profiling, open / dense / hordes300 one at a time, headless, no godot process before; no repo code changed | exit 0 x3 `TWO_F0 COMPLETE`; BLOCKED, see '2i result' |

### Task 2d: largest `advance.*` sub-zone on hordes300 (kept fix 3, design fixed after 2a)

- Target: decided by 2a. Current suspect is `Horde.step` (horde.gd:15-27): it collects members from all armed ids and rebuilds `_cell_size` (a `Registry.kind` + `radius` per member) and `_bucket` over every member on every tick that has any due check, which is nearly every tick with 300 militia at rate 30. Alternatives: `Containers.step` (containers.gd:65-74, a full entity scan per tick) or `_advance` allocations (simulation.gd:591-610: `route.slice(1)`, a new position array per tick).
- Design rule: same values in the same order. Compute `_cell_size` inputs once per kind instead of once per member; the bucket still holds every member (neighbours need it). No change to `horde_tick`, rate or `next_random` draws.
- Proof: test_horde.gd horde-check counts and levels unchanged, plus a characterization case (old vs new `_level` on seeded packed blocks) if the bucketing changes; traces cmp-identical.
- Expected gain (estimate, after 2a): 0.3-0.8 ms on hordes300 `advance` (1.63 now).
- Risk: low to moderate. Horde levels feed fire delays, so the traces catch any slip.

Stop after 2d (three kept fixes): full re-baseline of every row on the round tree, a finding in this file, then the gate review.

### Task 2e: nearest-first bucket order with early exit (next round, NOT a kept fix without approval)

- Target: `_nearest` window loop (combat.gd:300-302).
- Design: visit buckets in rings around the unit's bucket and stop once the next ring's minimum possible distance exceeds the best so far (or `GRID_CELL` 4). Same targets by the argmin argument, so the traces are identical.
- Why not kept now: fewer hostile candidates means a lower `_combat_work`, so BM6's lower bound (16000) will probably fail. Retuning BM6 is a cost-counter test change (not a pin) and needs the user's approval plus a ledger row. Do it only if open / dense still miss after 2b-2d.
- Expected gain: the retarget-burst tail (13.2-cell scans) shrinks to the nearest few buckets, perhaps -0.3 to -0.8 ms p95 on open / dense. Risk: low for behaviour, moderate for review (ring bound arithmetic); the oracle case from 2b covers it.

### Task 2f: retarget scan scheduling (NOT a kept fix: re-pin)

- Spreading the death-tick retarget burst over several ticks (`object_removed`, combat.gd:536-541, `repath_tick = tick`) or narrowing `scan_reach` changes which tick a unit acquires a target. Every trace and pin moves, so this needs a separate user-approved re-pin and a Zero Hour comparison (`AIUpdate` scan timing). Listed for the gate recommendation only; not to be started in this workstream.

## 2a result (2026-11-07, HEAD c683426 via git archive, Apple M6, headless, profiler on, one run per layout, load 1.4-1.6)

Scratch only: `advance.*` sub-zones in `step.advance`, per `_nearest` call counters (friendly = rejected by `hostile()`, hostile = the rest), a removal tick marker in `object_removed`, and `run_2a.gd` (300 warm-up ticks, 1800 sampled). Logs in the scratchpad (`ws2a/{open,dense,hordes300}.log`), not in the repo. Zone means match the Workstream 1 profile (open `step` 1.59, `nearest` 0.51; dense 1.49 / 0.61; hordes300 3.88 / 1.40), so the sub-zones did not distort it.

H1 confirmed. Share of `_nearest` loop candidates that are non-hostile (all scan kinds): open 87.0 % (91.7 candidates per reach call, 89.8 % friendly; scan_reach 156 per call, 68.7 %), dense 85.5 % (reach 88.6 %, scan_reach 66.8 %), hordes300 97.3 % (211 candidates per call, reach 97.7 %, scan_reach 90.3 %, return 87.5 %). Skipping non-hostile owners removes 85-97 % of the loop iterations; `_combat_work` is unaffected because friendlies are never counted.

H2 confirmed, strongly. Ticks following a removal (previous tick had at least one `object_removed`) are 7.8 % of ticks on open, 8.2 % on dense, 5.7 % on hordes300. Of the 91 `combat.nearest` p95 ticks: open 84 (92 %), dense 68 (75 %), hordes300 84 (92 %) follow a removal; the `step` p95 ticks: open 77 of 91, dense 69, hordes300 75. `nearest` mean after a removal against other ticks: open 1.42 vs 0.43 ms, dense 1.82 vs 0.50, hordes300 2.73 vs 1.32. Calls per tick after / other: open 33.5 / 16.3, dense 36.8 / 15.1, hordes300 50.1 / 37.4. Candidates per call on the post-removal scan_reach rescans are 131-143 (open, dense) against 91-115 for reach calls: retarget bursts are more calls and wider scans. So the p95 tail is the death-triggered rescan burst; the friendly share applies inside it too (open 74 %, dense 71.6 %, hordes300 92.8 % of candidates after removal).

H3 confirmed. hordes300 `step.advance` 1.608 ms mean splits: `advance.horde` 0.981 (61 % of advance, 25.3 % of step; p95 1.53), `advance.move` 0.485 (30 %), `containers` 0.060, `moved` 0.046, `before` 0.033, `salvage` 0.0003. On open / dense `advance` is 0.39 / 0.34 ms, mostly `move` (0.29 / 0.25), `horde` only 0.02: Task 2d is a hordes300-only gain and can be skipped if only open / dense matter.

Recommendation: Task 2b (skip non-hostile owners whole in `_nearest`) is justified: it targets 85-97 % of the loop and the retarget burst. Estimate caveat: open / dense `nearest` is 0.5-0.6 ms mean, so removing about 85 % of the iterations (the `hostile()` call cost, not the distance work) is bounded by that; the p95 gain is not yet measured. Task 2d target: `Horde.step`.

## 2b result (2026-11-07, working tree on c17e88d vs git archive of c17e88d, Apple M6, load 1.82 start / 1.69 end)

Kept fix 1: `_build_grid` buckets per owner (`{owner: {Vector2i: Array}}`), `_nearest` calls `hostile()` once per owner and skips non-hostile owners whole; same window, distance expressions and (distance, id) argmin; `combat_work` unchanged. New case `test_nearest_matches_oracle` (N1, game/tests/test_combat.gd): 200 seeded states (3-7 owners, shared teams, team-0 owners, ground and air units, passengers, 2x2 and 3x3 buildings, one masked site), every unit scanned in edge / centre / units_only modes (7896 scans), old `_build_grid` + `_nearest` copy as oracle, same id and same `_combat_work` delta. It passed on the old code (483 cases, 0 failures, before the change); with the tie-break flipped (`<` to `>`) it fails with 308 mismatches (6 failures overall), mutation reverted.

Acceptance: suite 483 cases / 136034 checks / 0 failures (base 482 / 136033; pins S1, Cs1, Fm1, TB3, TB4, H1 are inside the suite and unchanged); lint and warnings exit 0; four traces cmp-identical to the base archive; netplay match PASSED at tick 8400; team match exit 0 with the expected line; `combat_work=` summary of `run_combat.gd` identical A vs B on every layout; BM6 passes in the suite.

A/B median of 3 runs each (ms), A = base, B = Task 2b, A/A spread = max - min of the 3 A runs:

| Row | p50 A / B | p95 A / B | p99 A / B | A/A spread p50 / p95 / p99 |
|-----|-----------|-----------|-----------|----------------------------|
| combat open | 1.565 / 1.343 | 2.776 / 2.203 | 3.669 / 2.598 | 0.007 / 0.024 / 0.046 |
| combat dense | 1.199 / 1.119 | 3.087 / 2.390 | 4.642 / 2.945 | 0.003 / 0.005 / 0.096 |
| combat hordes300 | 3.845 / 2.712 | 5.563 / 4.107 | 7.017 / 4.754 | 0.008 / 0.027 / 0.058 |
| movement open | 1.526 / 1.526 | 1.613 / 1.609 | 1.775 / 1.777 | 0.010 / 0.009 / 0.025 |
| movement dense | 1.541 / 1.537 | 1.589 / 1.596 | 1.800 / 1.788 | 0.010 / 0.016 / 0.017 |

Movement rows: differences are below the spread, noise (the change does not touch movement). Other combat rows (A -> B p95): contact 1.203 -> 1.198, skirmish3v3 1.436 -> 1.370, transports 1.470 -> 1.287, defences 0.958 -> 0.883, docks 0.880 -> 0.723, ramp 0.760 -> 0.693, frc 0.948 -> 0.918; none worse beyond its spread. Open / dense / hordes300 still exceed the 1.82 / 3.64 budget (report-only, ceilings untouched). Logs in the scratchpad (`ab/`), not in the repo. Lockstep and team-match timing runs were not repeated; team match was run for its exit line only. performance.md ledger row not written (coordinator decides).

## 2c result (2026-11-07, working tree on bce4b79 vs git archive of bce4b79, Apple M6, load 1.93 start / 1.25 end)

Kept fix 2: `CombatDefinitions.radius` memoizes per kind in `Registry.radius_cache` (cleared in `Registry._reset`, so `add_test_kind` / `clear_test_kinds` cannot leave it stale); `_gap_at` branches once on `has("origin")` and calls `Definitions.building` once. Same float expressions. New case `test_radius_cache` (RAD1-RAD3, game/tests/test_combat.gd): cached radius equals the formula for every Registry kind, a test kind re-added with another radius is not stale, and `clear_test_kinds` drops the entry. Mutation-checked in Task 2g: removing `radius_cache = {}` from `Registry._reset` turns RAD2 and RAD3 red; a cached value + 0.001 turns RAD1 red (37 mismatches). A first draft of `_gap_at` read `target.position` for buildings and broke 34 checks (buildings carry no `position`); the suite caught it, fixed before the numbers below.

Acceptance: suite 484 cases / 136037 checks / 0 failures (base 483 / 136034); lint and warnings exit 0; four traces cmp-identical to the base archive; 7 pin lines equal to base; netplay match PASSED at tick 8400; team match exit 0 with the expected line; `combat_work=` identical A vs B on open, dense, hordes300.

A/B median of 3 runs (ms), spreads are max - min of the runs of that arm:

| Row | p50 A / B | p95 A / B | p99 A / B | A/A spread p50 / p95 / p99 |
|-----|-----------|-----------|-----------|----------------------------|
| combat open | 1.333 / 1.312 | 2.170 / 2.111 | 2.584 / 2.525 | 0.008 / 0.017 / 0.053 |
| combat dense | 1.123 / 1.089 | 2.379 / 2.284 | 2.935 / 2.845 | 0.015 / 0.023 / 0.034 |
| combat hordes300 | 2.699 / 2.614 | 4.069 / 3.921 | 4.733 / 4.569 | 0.015 / 0.018 / 0.070 |
| movement open | 1.526 / 1.520 | 1.588 / 1.589 | 1.766 / 1.755 | 0.018 / 0.025 / 0.011 |
| movement dense | 1.537 / 1.526 | 1.579 / 1.577 | 1.788 / 1.790 | 0.018 / 0.020 / 0.018 |

Gain is real (beyond spread in all combat percentiles) but far below the 0.1-0.4 ms estimate: 0.02-0.09 ms p50, 0.06-0.15 ms p95. Movement differences are within spread. Rows still exceed the budget (report-only). Logs in the scratchpad (`ab2c/`), not in the repo. Lockstep and team-match timing were not rerun.

## 2g result (2026-11-07, round-1 gate fixes, HEAD 7c9d615 vs git archive of c17e88d, Apple M6, load 1.95 start / 1.50 end)

Radius-cache cases renamed RAD1-RAD3 (RC1-RC3 are the retaliate labels). Mutations, each reverted (`git diff` shows only test and doc edits): removing `radius_cache = {}` in `Registry._reset` -> RAD2 and RAD3 red; cached value + 0.001 -> RAD1 red (37 mismatches); `_nearest` x-window bound `- 1.0` -> N1 red (600 mismatches); air filter dropped in `_build_grid` -> N1 red (7599 mismatches). The air kind in N1 is `usa_collector` (class air), so N1 already covers the filter; no test extension needed.

A/B of the kept fixes 2b+2c (A = c17e88d, B = HEAD, A B A B A B, 3 rounds, headless, profiler on), median (A/A spread = max - min of A):

| Row | A | B | A/A spread |
|-----|---|---|------------|
| team match p50 / p95 / p99 ms | 0.571 / 1.408 / 2.903 | 0.563 / 1.337 / 2.868 | 0.002 / 0.008 / 0.011 |
| lockstep overhead p50 / p95 / p99 ms | 0.009 / 0.016 / 0.066 | 0.009 / 0.016 / 0.070 | 0.001 / 0.001 / 0.000 |

Both teams end `TEAM MATCH cap tick=45000 winner=null units_peak=160`. Team match is faster beyond spread (p95 -0.07 ms). Lockstep p99 B is 0.004 ms above A (B runs 0.070 / 0.066 / 0.070, spread 0.004; far below the 0.6 budget, lockstep does not run the combat code).

## 2e result (2026-11-07, working tree on f62cf70 vs git archive of f62cf70, Apple M6, load 1.46 start / 1.31 end) - BLOCKED, not kept

Tried: `_nearest` visits target-grid buckets in Chebyshev rings around the unit's bucket (hostile owners collected once, ring loop outside the owner loop) and stops when the lower bound of the next ring (distance to the outer edge of the ring square, minus unit and `MAX_TARGET_RADIUS` in edge mode, minus a 0.01 margin, squared in centre mode) is strictly above the best distance. Test first: N1 extended to 6527 scans (200 states, 1/6 of entities and 1/8 of buildings erased, 2213 scans with the radius set exactly to a target's distance, dead units), id equal to the mixed-grid oracle, plus N2 (never more targets examined than the full window). Mutation check: ring bound off by one cell (`(ux + ring + 1)`) turns N1 red (17 mismatches; S1 and Cs1 pins also fail); changing the margin to +0.5 stayed green (margin not covered by the test). Suite 484 / 136038 / 0 failures, four traces cmp-identical, 7 pins equal, lint, warnings, netplay match and team match all passed on the tree (accept.sh).

Result: `combat_work` p95 falls only 12 % (open 1381 -> 1206, dense 1522 -> 1387, hordes300 unchanged 1279; tick-0 peak in BM6 'contact' 18168 -> 17676), because hostiles sit in the first rings and the friendly share was already removed by 2b. A/B median of 3 (ms), A = f62cf70, B = 2e:

| Row | p50 A / B | p95 A / B | p99 A / B | A/A spread p50 / p95 / p99 |
|-----|-----------|-----------|-----------|----------------------------|
| combat open | 1.311 / 1.328 | 2.108 / 2.119 | 2.541 / 2.469 | 0.005 / 0.008 / 0.031 |
| combat dense | 1.081 / 1.097 | 2.271 / 2.289 | 2.826 / 2.839 | 0.012 / 0.030 / 0.031 |
| combat hordes300 | 2.599 / 2.638 | 3.899 / 3.930 | 4.525 / 4.599 | 0.002 / 0.026 / 0.043 |
| movement open | 1.514 / 1.521 | 1.582 / 1.593 | 1.766 / 1.775 | 0.000 / 0.025 / 0.042 |
| movement dense | 1.530 / 1.530 | 1.573 / 1.577 | 1.778 / 1.799 | 0.009 / 0.009 / 0.030 |

No p95 gain beyond the spread; combat rows are slightly slower (ring bookkeeping outweighs the saved checks). The fix is NOT kept: code, tests and the BM6 retune were reverted (BM6 floor stays 16000, no retune needed; patch in the scratchpad `2e-blocked.patch`). Recommendation: drop 2e; the remaining tail is the retarget burst (2f, re-pin) not the candidate loop. Lockstep and team-match timing not run (no tree kept).

## 2f design (Opus, 2026-11-07, read against 7c9d615; nothing run, no benchmark)

Sources read: combat.gd 93-147, 169-178, 283-324, 550-560 on 7c9d615; simulation.gd 398-402, 446-454, 517, 554, 735-746; Zero Hour EA tree `~/projects/CnC_Generals_Zero_Hour` at `0a05454d8574207440a5fb15241b98ad0b435590`, paths under `GeneralsMD/Code/GameEngine/`; retail values from [M5.1 acquisition](m5.1-acquisition.md) (AIData.ini, not re-read); Recoil / OpenRA notes in the session scratchpad (`openra-recoil-targeting.md`, not in the repo; OpenRA 9636b63eae, Recoil a0240a9b5c).

### What Zero Hour does on a target loss (Code, not run)

- Attack-move: when the inner attack machine goes idle (target dead), `AIAttackMoveToState::update` sets `forceRetargetThisFrame` (`Source/GameLogic/AI/AIStates.cpp:3602, 3620`) and calls `getNextMoodTarget(!forceRetargetThisFrame, false)` (`:3641`). With `calledByAI` false the rate limit is skipped (`Source/GameLogic/Object/Update/AIUpdate.cpp:4564-4577`) and so is the human `WITHIN_ATTACK_RANGE` filter (`:4628-4630`); the range is vision x GuardOuter (`:4581`). So Zero Hour retargets on the same frame at full scan range: Wargrid's `retarget` + `scan_reach` burst is source-faithful, one tick later.
- Idle (Wargrid `guard`, also AI): the attack state returns to `AI_IDLE`, whose `onEnter` calls `resetNextMoodCheckTime` (`AIStates.cpp:1322`) = now + `ForceIdleMSEC` (`AIUpdate.cpp:4467-4471`; retail 67 ms = 3 ticks), then every `MoodAttackCheckRate` with a ±50 % first jitter (`AIUpdate.cpp:4566-4576`).
- Neither path spreads the burst: every attacker of the dead target rescans on the same frame (attack-move) or 3 frames later (idle). Spreading is a Wargrid departure. Precedent: the M4.1 `stop` ruling already moved re-acquire to the next phase tick, citing `resetNextMoodCheckTime` (session-notes.md:156, simulation.gd:402).

### A. Trace-preserving reductions

- Rescan only the units whose target died (target-to-attackers index): no gain. `object_removed` (combat.gd:551-552) already touches only units with `target_id == id`, which is what the spec and Zero Hour require. An index would only replace the O(entities) loop per removal (outside `combat.nearest`) and needs upkeep at every `target_id` write (plan, `_set_intent`, retaliation, defences): more code than the loop costs. Preserves traces, not worth it.
- Reuse per-tick scan results for units in the same bucket with the same filter: not provable. The result is the (distance, id) argmin from the unit's exact position; two units in one 8-cell bucket can get different targets. Only units with identical position, team class, kind, mode and radius are provably equal; held cells keep units in distinct cells, so this almost never fires.
- Dedupe of burst rescans: none is redundant (each is position-specific, see above).
- Cheaper scan window (fewer candidates): already refuted by 2e (candidates -12 %, no p95 gain; hostiles sit in the first rings).
- Remaining trace-preserving lever: the constant cost per candidate. Today each hostile candidate costs about five static calls (`edge_gap`, `_gap_at`, two `CombatDefinitions.radius`, `_gap_between`) and about ten dictionary reads (`unit.position[i]`, `unit.kind`, `target.has("origin")`, `target.position[i]`, `target.kind`, radius cache). Design A1: `_build_grid` stores per bucket one flat record per target, computed once per tick (id, centre x / y as today's float64 expressions, target radius, building bounds `origin` and `origin + footprint` as float64, the `Vector2` position for centre scans, a building flag); `_nearest` inlines `maxf(0.0, sqrt(dx * dx + dy * dy) - ra - rb)` with `ra` hoisted and keeps `- ra - rb` order, and keeps `Vector2` (float32) only where `distance_squared` uses it today. Traces: identical, because the candidate set, the `_combat_work` increment per candidate, the (distance, id) argmin and every float expression (same operands, same operation order, same float32 conversion points) are unchanged; values computed once per tick equal the per-call values because nothing in `plan` moves a unit or building (positions change in `advance` and `Containers.step`; `_stop_unit` and `_approach` only touch route, status and the path queue). Proof: the N1 oracle case (game/tests/test_combat.gd) is the proof, plus traces and `combat_work` A vs B. It is a kept fix round 2 item, not a re-pin.
- Expected gain A1 (unmeasured; 2c's estimate was 4x too high): 0.1-0.3 ms on burst ticks, so open p95 2.11 -> about 1.85-2.0, dense 2.28 -> about 2.0-2.15, hordes300 3.92 -> about 3.7-3.8. Probably not enough alone.

### B. Re-pin: phase-deferred retarget after a target loss

Rule (one change, everything else stays): a unit whose target is removed rescans at its next phase tick, `tick + REPATH_TICKS - (tick + id) % REPATH_TICKS` (1-8 ticks later, the formula already used by the periodic scan, `stop` and `_approach`), instead of the next tick; a halted attack-move unit waiting for that rescan holds (no march resume, no path request); orders (`_set_intent`, repath_tick = tick) and the left-range retarget (combat.gd:113-114) stay immediate. Scan interval: `REPATH_TICKS` 8 stays (retail infantry `MoodAttackCheckRate` 250 ms, ledger performance.md:101); no new constant, no RNG, no new state field (H1 and the snapshot schema must not move).

Code (about four lines): `object_removed` sets `repath_tick` with the phase formula and sets `retarget` for every attack-move unit (AI too; for AI `retarget` changes neither radius nor edge mode, combat.gd:121, 170); line 114 also sets `repath_tick = sim._tick`; line 118 drops `or combat.retarget` (the bypass is then redundant for line 114 and must not fire for removals); the resume branch (line 141) adds `and not combat.retarget`. `retarget` is still cleared after the scan (line 123) and by `_set_intent`, so a scan that finds nothing resumes the march on that tick, as today on tick + 1.

Feel against Zero Hour (departure, to be recorded): attack-move retarget 0 frames in ZH -> 1-8 ticks; idle 3 ticks in ZH -> 1-8 ticks. The delay is hidden while the weapon reloads: tank delay 60 ticks, rifle clip reload 21; only a rifle mid-clip (delay 3) loses up to 5 ticks per kill, under 1 % of its fire time against 180 HP infantry (36 rifle hits per kill). An out-of-reach new target starts its approach up to 7 ticks later. Fallback if the comparison fails: clamp to `min(phase tick, max(tick + 1, next_fire_tick))`, which keeps every in-reach follow-up shot on today's tick but spreads rifle bursts less (most rifle killers then rescan at kill + 3).

Expected gain (unmeasured; 2a numbers are pre-2b): the post-removal excess (about +17 `_nearest` calls per removal tick, 33.5 vs 16.3, plus the approaches and path requests they trigger) is spread over 8 ticks; post-removal ticks are 5.7-8.2 % of ticks, so today they own the p95. Estimate open p95 2.11 -> 1.75-1.9, dense 2.28 -> 1.85-2.0, hordes300 3.92 -> 3.6-3.8 (its p50 2.61 is over budget anyway), p99 open / dense already pass; team match, contact, skirmish3v3 small. Not a guaranteed pass.

Traces and pins: expected to move and to be re-pinned with old -> new value and the reason "2f phase-deferred retarget" (test comment one line, plus a row here): `WARGRID_COMBAT_REPLAY_TRACE`, `WARGRID_TEAM_REPLAY_TRACE`, S1 8501 / 8576069817585818203, Cs1 26359, Fm1 23534, TB3 020f659e77ee6c20, TB4 7692526877276561850, netplay terminal tick 8400, the team-match line, `combat_work=` summaries. Must stay identical (a move is a stop and needs an explanation): `WARGRID_REPLAY_TRACE`, `WARGRID_ECONOMY_REPLAY_TRACE` (if they contain no removal, else explain), H1 01e256834bdd4dfb (one step, no removal), BM6 contact tick-0 peak (tick 0 has no removal). A changed winner (Fm1 winner 1, S1 / Cs1 outcome) is a stop: report it, do not re-pin silently. Tests whose expectations encode the next-tick retarget and will need re-wording (grep, not run): test_combat.gd `test_removed_target_rescans`, `test_human_attack_move_post_kill_rescan`, `test_rescan_same_tick_orders`, L1 (line 425, `next_fire_tick == 4` and `target_id == second`), A5-A7 (lines 932-988), RC4 (line 1165) and test_combat_navigation.gd `test_guard_retarget`; each change is recorded, never widened.

Version bump: the only build guard is the `build` string = `application/config/version` (game/project.godot:5, now `0.7.0-dev`), sent in `hello` (launcher.gd:74, net/headless_client.gd:68-69) and compared by the relay (relay/room.go:139, `build mismatch`). Bump it to `0.7.0-dev.1` in the 2f commit; it stays a prerelease (`-`), so `tools/release_version.py` and `tools/deploy_web.sh test` accept it, and the deployed test web build (`0.7.0-dev`, pre-2f) can no longer share a room with it. `Wire.PROTOCOL` (net/wire.gd:3) is the wire format, fixed by `protocol/vectors`: unchanged. Replays: there is no versioned replay file; the only replay input is the netplay command log (`--command-log` / `--replay-log`, headless_client.gd:181, 200-220), written and replayed by one `tools/run_netplay.sh` run of one tree. Stamping it would need a header message type that `Wire.decode` rejects today (`protocol/vectors/invalid_unknown_type.json`): not proposed. Runtime backstop stays the lockstep hash check (net/lockstep.gd:198, `ended_desync`).

Netplay and WASM: integer tick arithmetic on `tick` and `id` only, no float, no RNG, no thread, so native and WASM agree as today; rerun `sh tools/run_netplay.sh match` (new terminal tick re-pinned) and the affected scenarios; CI compare-replays checks cross-platform equality on the new tree.

Tasks (test first; Sonnet medium; acceptance as Workstream 2 except that the listed traces and pins move by re-pin):
- 2f.0 measure (report-only, scratch git archive of HEAD, no kept code, quiet host, one run per layout, profiler on): on open, dense, hordes300 split the post-removal ticks into `combat.nearest`, `combat.firing_cell`, `step.service_paths`, `fire` and `object_removed`; then prototype A1 and B in two scratch copies and record `step` p95 / p99 and `combat.nearest` per layout. Decides which of A1 / B to build and whether 2f is worth it.
- 2f.1 Zero Hour reference (parity harness, headless, `-noaudio`, measured (source build)): Rangers and Crusaders attack-moving into a defending group; per kill, frames from the target's death to the killer's next shot (`lastShotFrame`, `health`), attack-move and idle. Wargrid values from the same fixture on the current tree and on the 2f tree. Feel acceptance: mean follow-up latency within ZH + 4 ticks, max within ZH + `REPATH_TICKS`, shots per tick in open / dense within 2 % of today, same winners.
- 2f.2 tests (red on today's code, Sonnet medium or higher): R1 "a unit whose target is removed rescans at its next phase tick, not on the next tick" (two units of different phase lose one target; scan ticks equal the formula); R2 "a halted attack-move unit waiting for its rescan does not resume marching" (status idle, not in `_path_queue`, `allocation_calls` 0 until the scan tick; resumes on that tick if nothing is found); R3 "an order on a waiting unit scans on the order tick" and "a target leaving weapon range still rescans in the same plan" (green today, guard the exceptions); R4 "a tank's follow-up shot on an in-reach target keeps today's tick". Same-tick cases against removal: order on the removal tick and on a waiting tick, removal by container entry (containers.gd:118), retaliate (`_go_home` keeps `RETURN_SCAN_TICKS`), attack mode (-> guard, phase rescan), mutual kill, a second removal while waiting (`repath_tick` recomputed from the later tick). Reviewer names per test the production line that turns it red.
- 2f.3 implement the four lines, re-word the tests listed above (recorded), re-pin, bump `config/version`, A/B timing as Workstream 2, ledger row, and record the departure (ZH 0 / 3 ticks -> 1-8 ticks, with the 2f.1 numbers) here and in the blueprint (re-pin approved by the user 2026-11-07; the departure wording is new and needs their sign-off).
- If A1 is chosen too: a separate kept fix with its own trace-identical acceptance, landed and measured before 2f.3, so the re-pin diff carries only the rule change.

### C. Recommendation

Run 2f.0 first (cheap, decisive, no code kept). Then A1 before B if 2f.0 shows the per-candidate cost is most of the burst `combat.nearest` (kept fix, no re-pin, no feel risk). Then B with the Zero Hour comparison. Honest expectation: A1 alone does not reach 1.82 on open or dense; B alone probably brings open near the line (about 1.75-1.9) and leaves dense slightly over (about 1.85-2.0); A1 + B together have a fair chance on both; hordes300 stays exceeded on p95 and p99 (p50 2.61) until 2d and more. p99 3.64 already passes on open and dense.

## 2f.0 result (2026-11-07, HEAD 96ef6ca via git archive, scratch copies in scratchpad `ws2f0`, Apple M6, load 2.0 start / 1.25 end; nothing kept in the repo)

Zone split (report-only, profiler on, 300 warm-up + 1800 sampled ticks, mean ms per tick; "after" = previous tick had a removal, 5.7-8.2 % of ticks; per-call fit `t = a + b * candidates` with the timer inside `_nearest`, so timer-inclusive):

| Layout / class | step | plan | nearest | build_grid | firing_cell | service_paths | fire | advance | object_removed |
|----------------|------|------|---------|------------|-------------|---------------|------|---------|----------------|
| open other | 1.18 | 0.62 | 0.17 | 0.09 | 0.01 | 0.00 | 0.12 | 0.39 | 0.00 |
| open after | 1.96 | 1.29 | 0.54 | 0.10 | 0.17 | 0.01 | 0.20 | 0.39 | 0.00 |
| dense other | 0.99 | 0.53 | 0.19 | 0.07 | 0.00 | 0.00 | 0.09 | 0.33 | 0.00 |
| dense after | 2.11 | 1.46 | 0.74 | 0.09 | 0.15 | 0.01 | 0.21 | 0.37 | 0.01 |
| hordes300 other | 2.53 | 0.82 | 0.22 | 0.16 | 0.02 | 0.00 | 0.10 | 1.52 | 0.00 |
| hordes300 after | 3.89 | 1.83 | 0.64 | 0.16 | 0.37 | 0.03 | 0.23 | 1.70 | 0.04 |

Per call: 71-91 % of `_nearest` time is per-candidate cost (b about 0.93-0.95 us per candidate on the removal-free scans; the post-removal mix has b 0.34-0.43 us but 20-41 candidates per call against 4-11), the fixed per-call part a is 1.1-3.4 us. `build_grid` is constant (0.07-0.16 ms, same after and other, so not part of the tail). The post-removal excess over other ticks is about +0.8 (open), +1.1 (dense), +1.4 (hordes300) ms: nearest +0.37 / +0.55 / +0.42, firing_cell +0.15 / +0.15 / +0.35, the rest plan bookkeeping and fire.

A1 (flat per-target records built in `_build_grid`, same float expressions inline in `_nearest`; the scout in `_plan_return` has no `kind`, so the unit radius is read only in edge mode - a first draft read it always and turned RS1, Fm1, Cs1 red): suite 484 cases / 136037 checks / 0 failures; all four traces cmp-identical to HEAD; `combat_work` identical. A/B median of 3 (A = HEAD, B = A1, A/A spread in ms):

| Row | p50 A / B | p95 A / B | p99 A / B |
|-----|-----------|-----------|-----------|
| open | 1.306 / 1.322 (noise) | 2.099 / 1.958 (-0.14) | 2.533 / 2.280 (-0.25) |
| dense | 1.081 / 1.082 | 2.270 / 1.921 (-0.35) | 2.817 / 2.180 (-0.64) |
| hordes300 | 2.598 / 2.764 (+0.17 slower) | 3.908 / 3.740 (-0.17) | 4.594 / 4.234 (-0.36) |

B (design rule: phase-deferred retarget after a target loss, hold attack-move units; four lines) fails 26 checks: M1 (3), B1 (8), A3 (3), A7, A8 (2), R1, S1 (2), Fm1, Cs1, TB3, TB4. Traces: `WARGRID_REPLAY_TRACE` MOVES (first difference at tick 320; the design expected it to stay identical, so it needs an explanation), combat and team traces move, economy stays. Pinned winners unchanged (Fm1 1, S1 1, Cs1 2) but ticks move (Fm1 16621, S1 12330, Cs1 24879, TB3 f95ee411007d11be, TB4 5487475243737389530, S1 series 1507712663628559348). `combat_work` p95 falls (open 1381 -> 1056, dense 1522 -> 1288) but p50 rises (193 -> 351, 116 -> 262, 73 -> 376): the deferral concentrates rescans on phase ticks. A/B, B alone: open p95 2.112 -> 2.372, p99 2.555 -> 3.545, max 3.2 -> 5.9; dense p95 2.284 -> 2.465, p99 2.818 -> 4.170, max 3.6 -> 7.4; hordes300 p95 3.904 -> 4.775, p99 4.549 -> 8.182. A1+B: open p95 2.110 -> 2.345, p99 2.543 -> 3.573; dense p95 2.275 -> 2.169, p99 2.827 -> 3.951; hordes300 p95 3.895 -> 4.715, p99 4.558 -> 8.121. B is slower on every row beyond the A/A spread (spread 0.01-0.07), the tail moves from removal ticks to phase ticks and is worse. Not tested: the clamped fallback (`min(phase tick, max(tick + 1, next_fire_tick))`) and a per-id spread of the deferred tick; the cause of the p99 rise (mass rescans plus approaches on one phase tick, unprofiled) is a hypothesis.

Budget 1.82 / 3.64: A1 alone p95 open 1.958, dense 1.921, hordes300 3.740 (all still over 1.82, p99 open and dense pass). Nothing reaches 1.82 on p95. Recommendation: implement A1 (kept fix, trace-identical, -0.14 to -0.35 ms p95); do not build B as designed; if the tail is pursued further, profile the remaining post-removal ticks (plan bookkeeping and `firing_cell`, +0.3 to +0.5 ms) instead. Logs: scratchpad `ws2f0/{meas.*.log,ab_a1,ab_b,ab_ab,suite*.log}`.

## 2h result (2026-11-08, working tree on f7ce33f vs git archive of f7ce33f, Apple M6, load 1.0-2.3; A1 as a kept fix, lazy per-bucket records)

Change: `game/scripts/simulation/combat.gd` only. `_build_grid` stores target dictionaries per bucket as `[targets, null]`; `_nearest` builds the flat records (`_records`, `_record`: id, centre, radius, building flag, position, bounds) on the bucket's first scan of the tick; same float expressions inline, unit radius read only in edge mode (the `_plan_return` scout has no `kind`). N1 (`test_nearest_matches_oracle`) is the spec; no test added.

Mutations (scratch copy, each turns N1 red, 7896 scans): building clamp bound +0.5 (40 mismatches); edge without target radius (537); building centre `size.x * 0.4` (53); centre-scan position offset (64); `units_only` filter inert (2325); lazy path: records skip the first target (7837), records built from one target only (6264).

Acceptance (accept.sh f7ce33f): suite 484 cases / 136037 checks / 0 failures (base same), four traces cmp-identical, 7 pin lines equal, lint and warnings pass (103 files), netplay match PASSED tick 8400, team match exit 0 with the cap line, `combat_work` identical. A/B numbers are in the ledger row: open p95 2.107 -> 1.906, dense 2.273 -> 1.836, hordes300 3.902 -> 3.604, p50 faster on all three.

Eager variant (records for all targets in `_build_grid`) dropped: same open / dense gains but team match p50 0.564 -> 0.638, p95 1.344 -> 1.445 (build_grid 0.066 -> 0.132 ms with 2.15 scans per tick); a 5-element unit record did not help (0.124).

Lazy variant on the team match (3 runs each, A/B): p50 0.564 / 0.564 / 0.565 -> 0.568 / 0.570 / 0.566, p95 1.337 / 1.336 / 1.341 -> 1.347 / 1.344 / 1.347, wall 47.81 / 47.81 / 47.86 s -> 48.00 / 48.07 / 47.93 s; build_grid 0.0659 -> 0.0691 ms. About +0.5 % to +1 %, marginally above the A/A spread (p50 0.001). Lockstep p99 0.065-0.066 -> 0.065-0.072 (noise). Logs: scratchpad `tools/runs/ab-2h`, `ab-2h-lazy`, `accept-2h`, `mut2h`.

## 2d result (2026-11-08, working tree on c3e1e91 vs git archive of c3e1e91, Apple M6, load 1.5)

Scratch profile (`Profiler` zones inside `Horde.step`, hordes300, 300 warm-up + 1800 ticks): `step.advance` 1.543 ms, of which `h.level` 0.588 (9.8 checks per tick, about 60 us each), `h.size` (`_cell_size`) 0.147, `h.bucket` 0.078, `h.members` 0.074. So the suspected per-tick rebuild is 0.30 ms; the neighbourhood count in `_level` is the largest part.

Change (`game/scripts/simulation/horde.gd` only): `_level` returns 2 as soon as `near` reaches `count - 1` (the old code returned 2 at that count regardless of `rubbed`, and `near` never decreases), plus `if need <= 0: return 2` for the degenerate count; `_cell_size` reads each kind once (`max` is order-independent). Same float expressions, no change to `horde_tick`, rate or `next_random`. Scratch result: `h.level` 0.588 -> 0.224, `h.size` 0.147 -> 0.020, `step.advance` 1.543 -> 1.048.

Test: `test_horde_step_matches_oracle` (H9) in `test_horde.gd` holds a copy of the old step (levels and due ticks, no delay restart) and compares it with `Horde.step` on 660 random states (220 worlds x 3 rounds: 0, 1, 2, 6, 25, 60 units; four owners in three teams; horde and non-horde kinds; contained units; random levels and due ticks; units spawned and removed between rounds; 3278 level-2 units). Mutations (scratch copy, each turns H9 red): `need + 1` early exit (161 mismatches), early exit returns 1 (172), `need = count - 2` (177), kind dedupe keeps only the first kind (44).

Acceptance (accept.sh c3e1e91): suite 485 cases / 136039 checks / 0 failures (base 484 / 136037), four traces cmp-identical, 7 pin lines equal, lint and warnings pass (103 files), netplay match PASSED tick 8400, team match exit 0 with the cap line. A/B numbers are in the ledger row; logs in scratchpad `tools/runs/ab-2d`, `ab-2d-r2`, `accept-2d`, `t2d`, `ws2d`.

Open: dense combat p50 reads +0.005 to +0.010 (two 3-round runs), flagged 'slower'; Horde.step does 0 horde checks there (profile: `horde_checks 0` on open and dense), so the change cannot add work; treated as layout noise, not proven.

`advance.move` (not fixed here): 0.49 ms on hordes300 and 0.29 on open / dense (2a); not re-profiled. Candidates remain `route.slice(1)` and the new position array per moving unit per tick in `_advance` (simulation.gd).

## 2i result (2026-11-08, ac1b7d4 via git archive, scratch copy `ws2i`, Apple M6, headless, profiler on, 300 warm-up + 1800 ticks) - BLOCKED, not kept

Mean ms per tick, "after" = previous tick had a removal (open 7.8 %, dense 8.2 %, hordes300 5.7 % of ticks); "other" in brackets:

| Candidate | open | dense | hordes300 | Recoverable |
|-----------|------|-------|-----------|-------------|
| `_hold_cells` (inside `firing_cell`, once per tick that has an approach) | 0.072 [0.006] | 0.059 [0.000] | 0.159 [0.013] | only by removing the set; inlining the cell floor gives 0.013 / - / 0.027 |
| `_firing_cell` ring loop (about 108 / 63 cells per call, 19 / 36 `component_at` calls) | 0.097 | 0.091 | 0.216 | about 0 (a ring centre without `Vector2(cell)` + add changed nothing measurable) |
| plan bookkeeping excess after removal (plan - nearest - build_grid - engage - pre) | +0.06 | +0.07 | +0.1 | no single item; `pre` 0.17, `engage` rest 0.15 |
| `_advance` rest (`route.slice(1)`, new position array), every tick | 0.063 | 0.055 | 0.105 (timer-inclusive, about 146 / 126 / 246 moving units per tick) | at most 0.03; the new position array cannot go because `before[id]` aliases it |
| `Locomotion.step` (every tick) | 0.213 | 0.186 | 0.350 | heading factor and turn are float-exact into speed; no trace-preserving shortcut found |

Best prototype recovers about 0.015 ms on post-removal ticks (6-8 % of ticks), so p95 moves at most that much against a gap of 0.09 ms (open 1.91 vs 1.82) and an A/A spread of 0.01-0.07; the hordes300 gap is 0.9 ms. No fix kept, no A/B run, no suite run (nothing changed in the repo). Not tried: replacing the per-tick `held.cells` set by an entity-grid occupancy lookup (the only way to remove `hold_cells`), and a persistent set maintained across ticks; both change more than one function and need an Opus design first. Logs: scratchpad `ws2i/prof*.log`.

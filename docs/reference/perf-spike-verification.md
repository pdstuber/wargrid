# Performance spike verification

Handoff: [performance-spike-prompt.txt](../performance-spike-prompt.txt). Ledger: [performance.md](performance.md). Dated evidence rows below the record are append-only.

```text
Resume record (updated 2026-11-08 00:00)
Branch / base commit / working-tree state: main / bce4b79 (Task 2b committed) / uncommitted: game/scripts/simulation/combat.gd, combat_definitions.gd, definitions/definitions.gd, game/tests/test_combat.gd (Task 2c), this file, docs/reference/performance.md (ledger rows 2b and 2c)
Last green task / next incomplete task: Task 2c (cached radius per kind, see '2c result'; awaits coordinator commit) / Task 2d (`Horde.step`, H3 confirmed)
Changed paths since last commit: game/scripts/simulation/combat.gd, combat_definitions.gd, definitions/definitions.gd, game/tests/test_combat.gd, this file, docs/reference/performance.md
Last command / cases / checks / failures / exit / marker: accept.sh bce4b79 PASS (suite 484 cases / 136037 checks / 0 failures); A/B bench_ab.sh 3 rounds exit 0 ALLDONE
Known red case or blocker: none. Report-only rows exceeded: combat open, dense, hordes300
Approved decisions, pre-authorizations used, deferred gates: user invoked the spike 2026-11-07; works on main; local commits after green checkpoints pre-authorized; no push/PR/merge/fly/Sprite/window without approval; host = this Mac only (user). Decisions of 2026-11-07 evening: BM6 retune approved together with 2e; 2f approved with a version bump and a ZH AIUpdate comparison; second round for 2d and per-cell enemy counts; hordes300 "improved, still exceeded" is acceptable; C++/GDExtension NOT investigated (user decision); threads PoC local first, fly web deploy allowed for the threaded-web test only, Safari failure is not a blocker, a Chromium-based browser (e.g. Vivaldi, not installed yet) is acceptable for the Chrome check; Steam Deck check tomorrow; user asleep, run all approved work, pausing only on a stop condition
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: commit Task 2c, then dispatch Task 2d (`Horde.step`)
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

## 2c result (2026-11-08, working tree on bce4b79 vs git archive of bce4b79, Apple M6, load 1.93 start / 1.25 end)

Kept fix 2: `CombatDefinitions.radius` memoizes per kind in `Registry.radius_cache` (cleared in `Registry._reset`, so `add_test_kind` / `clear_test_kinds` cannot leave it stale); `_gap_at` branches once on `has("origin")` and calls `Definitions.building` once. Same float expressions. New case `test_radius_cache` (RC1-RC3, game/tests/test_combat.gd): cached radius equals the formula for every Registry kind, a test kind re-added with another radius is not stale, and `clear_test_kinds` drops the entry. Not mutation-checked (the `_reset` line was not removed to see RC2 go red). A first draft of `_gap_at` read `target.position` for buildings and broke 34 checks (buildings carry no `position`); the suite caught it, fixed before the numbers below.

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

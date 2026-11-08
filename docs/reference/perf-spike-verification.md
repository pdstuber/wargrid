# Performance spike verification

Handoff: [performance-spike-prompt.txt](../performance-spike-prompt.txt). Ledger: [performance.md](performance.md). Dated evidence rows below the record are append-only.

```text
Resume record (updated 2026-11-08)
Branch / base commit / working-tree state: perf-spike / HEAD 10c524e / clean before Task 5e; Task 5e edits docs and `game/tests/test_benchmark.gd` (BM10 label) only, uncommitted. Nothing pushed, not merged
Last green task / next incomplete task: Workstreams 1-5 done (5a, 5b, 5d done; 5c skipped as a coordinator decision, see '5b result'); Task 5e write-up done (performance.md 'Post-M7 performance spike (2026-11)') / the user's ultra review, then the Steam Deck F = 5.5 re-check with the user (native and Firefox), then the user decides merge
Changed paths since last commit: docs/reference/perf-spike-verification.md, docs/reference/performance.md, README.md, AGENTS.md, game/tests/test_benchmark.gd (label BM9 -> BM10)
Last command / cases / checks / failures / exit / marker: Task 5e acceptance on HEAD 10c524e plus the label edit, see the 5e evidence row (suite, lint, warnings, netplay match, team match); then Task 6 jobs A-E (HEAD 003e66c, scratch `ws6`, docs only changed): all exit 0, `accept.sh 20a4d06` PASS, `run_benchmark.sh` exit 0, see '6 results'
Known red case or blocker: none. Report-only rows exceeded: combat open, dense, hordes300 (no budget or ceiling changed). 2i BLOCKED (no fix above the A/A spread). R1 not reproduced at load up to 2.8, cause unproven
Approved decisions, pre-authorizations used, deferred gates: user invoked the spike 2026-11-07; local commits after green checkpoints pre-authorized; no push/PR/merge/fly/Sprite/window without approval; host = this Mac only (user). Decisions of 2026-11-07 evening: BM6 retune approved together with 2e; 2f approved with a version bump and a ZH AIUpdate comparison; second round for 2d and per-cell enemy counts; hordes300 "improved, still exceeded" is acceptable; C++/GDExtension NOT investigated (user decision); threads PoC local first, fly web deploy allowed for the threaded-web test only (done, rolled back), Safari failure is not a blocker, a Chromium-based browser is acceptable for the Chrome check; Steam Deck check pending with the user
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: user runs the ultra review of branch perf-spike; then the Steam Deck F = 5.5 re-check with the user (ledger how-to); merge and push only on the user's word
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
| 2026-11-07 | HEAD 96ef6ca via git archive, scratch copies `ws2f0` (not linted, nothing kept) | Apple M6 | Task 2f.0: zone split of post-removal ticks (profiler on, 300 warm-up + 1800 ticks), prototypes A1 (flat records) and B (phase-deferred retarget), A/B 3 rounds | exit 0; B fails 26 checks and is slower on every row, A1 kept later as 2h; load 2.0 start / 1.25 end; table in '2f.0 result' |
| 2026-11-08 | HEAD f7ce33f + Task 2h working tree (uncommitted) vs git archive of f7ce33f | Apple M6 | Task 2h acceptance via accept.sh and bench_ab.sh (3 rounds), team match and lockstep A B A B A B by hand; no godot process before | suite 484 cases / 136037 checks / 0 failures; lint, warnings exit 0; traces identical; 7 pin lines equal; netplay match PASSED tick 8400; team match exit 0 cap line; load 1.0-2.3; movement dense p99 +0.014 flagged 'slower' by the tool (within the spread of B's runs); table in '2h result' |
| 2026-11-08 | HEAD c3e1e91 + Task 2d working tree (uncommitted) vs git archive of c3e1e91 | Apple M6 | Task 2d acceptance via accept.sh and bench_ab.sh (3 rounds, plus a second 3-round combat run), team match and lockstep A B A B A B by hand; no godot process before | suite 485 cases / 136039 checks / 0 failures (base 484 / 136037); lint, warnings exit 0; traces identical; 7 pin lines equal; netplay match PASSED tick 8400; team match exit 0 cap line; load 1.5; table in '2d result' |
| 2026-11-08 | HEAD 740dbe4 + Task 2j working tree (uncommitted) vs git archive of 740dbe4, 3-tree A/B with f7ce33f | Apple M6 | Task 2j acceptance via accept.sh and a 3-round interleaved A/B (team match, combat, movement, lockstep); no godot process before | suite 485 cases / 136039 checks / 0 failures; lint, warnings exit 0; traces identical; 7 pin lines equal; netplay match PASSED tick 8400; team match exit 0 cap line; load 1.1-2.3; table in '2j result' |
| 2026-11-08 | ac1b7d4 via git archive, scratch `ws2i` (profiler zones, not linted) | Apple M6 | Task 2i profiling, open / dense / hordes300 one at a time, headless, no godot process before; no repo code changed | exit 0 x3, scratch script printed `TWO_F0 COMPLETE removals=1800` (reused 2f.0 script name; no 2i marker exists); BLOCKED, see '2i result' |
| 2026-11-08 | HEAD ffa787f via git archive, scratch copies `ws2k` | Apple M6 | Task 2k: B (phase-deferred retarget) rebuilt fairly, suite, 3 traces, A/B A B A B A B (headless), feel proxy; nothing kept in the repo | exit 0; B1 and B2 each fail 20 checks (7 re-pins), p95 -0.02 to -0.04 open / dense, p50 +0.03 to +0.11, acquisition +3 ticks mean; replay, combat and team traces move; recommendation: drop B; load 1.2-1.7; see '2k result' |
| 2026-11-08 | 9a340bf (A) vs 9a340bf with `git revert --no-commit f6ed04f a1dfb03` (B), scratch clone | Apple M6 | R1: rendered `movement_benchmark.tscn -- --profile`, 3 runs per tree, A B A B A B, vsync=off, one window at a time, no other godot/browser | exit 0 x6; open tick p95 A 2.65-2.73, B 2.65-3.34; 0 of 1800 ticks over 8 ms in every run; ~10 ms tail not reproduced at load 1.4-2.8, cause unproven; see 'R1 result' |
| 2026-11-08 | 0aac476 (R2: base 297d43e + working tree) vs scratch copy of the tree without the cache | Apple M6 | R2: new `ashfall` layout, structure layer cache, rendered A B A B A B (vsync=off, 1280x720, zoom 0.5, `-- --profile`); suite and 4 traces by hand; netplay match and team match NOT run (presentation-only change, no sim file touched: documented deviation) | suite 486 cases / 136044 checks / 0 failures; lint, warnings exit 0; four traces cmp identical; `RENDERED BENCHMARK PASSED 4` x6; ashfall frame p95 2.89-3.02 ms; load 1.4-3.3; see 'R2 result' |
| 2026-11-08 | 0aac476 via git archive + groups g1-g5 (committed as 3ff3d07), scratch `ws4` | Apple M6 | Workstream 4: selective typing, `bench_ab.sh` 3 rounds A B A B A B per group, team match 3 runs per arm, `accept.sh`; no godot process before each | suite 486 / 136044 / 0 failures; lint, warnings (104 files) exit 0; four traces cmp identical, 7 pins equal, netplay match tick 8400, team match `cap tick=45000 winner=null units_peak=160`; `ACCEPT: PASS`; load 1.1-1.5; see 'Workstream 4 result' |
| 2026-11-08 | 3ff3d07 + scratch patch (5a.patch), scratch copy `w5a/game` | Apple M6, Firefox 159, Vivaldi (Chrome/156) | Task 5a: threaded web bench export, atomics cost, relay under COEP, `DIGEST` lines; 12 timed web runs + 1 boot run, fresh profiles, one window at a time, pgrep empty before each | all `BENCH DONE` / `BENCH POSTED` / `RELAY OK`; 8 `DIGEST` lines equal across native editor, native release, no-threads web, threaded web; Firefox atomics cost +4.7 % combat open p50, +8.3 % dense, Vivaldi about 0; load 1.2-2.1; see '5a result' |
| 2026-11-08 | base f371616 (git archive, scratch `ws5b`), PoC patch not applied to the tree | Apple M6 headless | Task 5b: native parallel PoC (`advance.move`, speculative `_nearest`), P1-P4, suite, 4 traces, netplay, team match in both modes, A/B timing at 4 and 2 threads | suite 491 / 136065 / 0 failures serial and parallel (base 487 / 136046); traces equal; netplay tick 8400; team match cap line; step 1 gain 2-3 % at 4 threads, loss at 2, step 2 slower everywhere; load 3.2 at start, 1.5 at end; see '5b result' |
| 2026-11-08 | db2178f via git archive, scratch `ws5d`, deployed to `wargrid-web-test` (approved) | Apple M6, Firefox 159, Vivaldi | Task 5d: threaded `Web` preset with COOP/COEP in `web/sws.toml`, `deploy_web.sh test`, headers on 18 responses, boot in both browsers, rollback | COOP and COEP on all 18 responses, `crossOriginIsolated=true`, Godot banner "multi-threaded" in both; rolled back (release v5), `/health` 200; relay not checked from the fly origin; see '5d result' |
| 2026-11-08 | f371616 (enemy spawns out of asserts in `combat_workload.gd`, new case BM10) acceptance, run on HEAD 10c524e plus the BM9 -> BM10 label edit in `test_benchmark.gd` and docs | Apple M6 | Task 5e: `sh tools/run_tests.sh`, `run_lint.sh`, `run_warnings.sh`, `run_netplay.sh match`, `run_team_match.sh`, one Godot process at a time | suite CASES 487 / CHECKS 136039 / FAILURES 0 (same 487 cases as the 5b base; 136039 without the trace variables); lint `Success: no problems found`; warnings 104 files exit 0; netplay match terminal tick 8400 `NETPLAY PASSED`; team match exit 0 `TEAM MATCH cap tick=45000 winner=null units_peak=160`; load 1.65 start / 1.49 end |
| 2026-11-08 | HEAD 003e66c (git archive) vs 20a4d06, scratch `ws6` | Apple M6, headless | Task 6 jobs A-E: team match profiler off/on, contact max series, macOS Bench release export, full re-baseline, `run_benchmark.sh`; one Godot process at a time, pgrep empty and load <= 2.5 before each run | all exit 0; `accept.sh 20a4d06` PASS (suite 487 / 136046 / 0 failures vs base 482 / 136033, 4 traces cmp-identical, 7 pins equal, netplay tick 8400, team cap line); `run_benchmark.sh` exit 0; load 1.2-2.2; see '6 results' |

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

## 2k result (2026-11-08, HEAD ffa787f via git archive, scratch copies `ws2k` in the scratchpad, Apple M6, headless, load 1.2-1.7; nothing kept in the repo) - B re-tested fairly

The 2f.0 prototype was unfair: it added `and not combat.retarget` to the resume branch, so a waiting attack-mover fell through to `elif not moving` and was demoted to guard (goal lost after its first kill). Rebuilt: the hold is its own branch (`elif combat.retarget: pass`, before the resume and the demotion), `object_removed` sets `retarget` for every attack-move unit and `repath_tick` to the phase tick (B1: `tick + 8 - (tick + id) % 8`; B2: `min(phase, max(tick + 1, next_fire_tick))`), the left-range retarget also sets `repath_tick = tick`, line 118 drops `or combat.retarget`.

Suite (HEAD 485 cases / 136039 checks / 0 failures): B1 20 failures, B2 20 failures, same checks in both: A7 (retarget cleared once served), S1 (vanished chaser rescans at once; pinned outcome; core series), M1 (resumes goal), A3, A8 (2), B1 test (8, "resumes toward its unchanged slot": next-tick resume, a designed hold), Fm1, TB3, TB4, Cs1 (pinned outcomes). All encode the next-tick retarget or the pinned tick. Winners unchanged: Fm1 1 (HEAD 23534 -> B1 16621, B2 19267, ended tick), S1 1 (8501 -> 8611 / 8468), Cs1 2 (26359 -> 24879 / 25789). TB3 f95ee411007d11be (B1) / b52617a2526a43e1 (B2), TB4 5487475243737389530 / 9151850056622992091. Traces: economy identical; replay MOVES at tick 321 (first changed line), combat (line 201) and team (line 37) move. The replay move is explained: the world has guard units killing each other near tick 320, and the snapshot hash includes `repath_tick` (unit 9: 320 -> 327, unit 12: 320 -> 324 under B1), so behaviour is guard-only but the hashed state differs; the design's "replay trace stays identical" was wrong. Team match cap run: winner null at tick 45000 on all three, `units_peak` 160 -> 162.

A/B (3 rounds A B A B A B, headless, medians, A/A spread 0.003-0.04 ms; budget 1.82 / 3.64):

| Row | HEAD p95 | B1 p95 | B2 p95 | HEAD p99 | B1 p99 | B2 p99 |
|-----|----------|--------|--------|----------|--------|--------|
| open | 1.908 | 1.871 (-0.04) | 1.887 (-0.02) | 2.255 | 2.111 (-0.14) | 2.197 (-0.05) |
| dense | 1.837 | 1.805 (-0.03) | 1.797 (-0.04) | 2.156 | 2.043 (-0.11) | 2.066 (-0.08) |
| hordes300 | 2.959 | 2.924 (noise) | 2.930 (-0.03) | 3.444 | 3.202 (-0.24) | 3.154 (-0.30) |

p50 slower: open +0.05 / +0.03, dense +0.11 / +0.10 (the deferral moves rescans onto phase ticks), hordes300 +0.04 / 0. Dense max falls 3.18 -> 2.43 / 2.40. movement open / dense: noise. `combat_work` p95 falls (open 1381 -> 1072 / 1031, dense 1522 -> 1366 / 1244), p50 rises. (HEAD numbers sit below the 2f.0 table because A1, 2j and 2h landed since; B1 / B2 are against the same HEAD.)

Feel proxy (scratch `run_feel.gd`, 300 warm-up + 1800 ticks, per attacker of a removed target; acquisition = ticks from the death event to a non-null `target_id`, ticks to the next shot capped at 30 for the NEAR column):

| Layout | HEAD acquisition mean / max | B1 | B2 | HEAD NEAR shot mean | B1 | B2 |
|--------|-----------------------------|----|----|---------------------|----|----|
| open | 1.02 / 2 | 4.52 / 16 | 4.16 / 16 | 12.9 | 13.8 | 12.8 |
| dense | 1.03 / 4 | 4.52 / 30 | 4.02 / 16 | 10.6 | 12.6 | 11.6 |
| hordes300 | 2.73 / 60 | 5.32 / 60 | 5.64 / 60 | 16.0 | 16.7 | 15.9 |

Acquisition is +3.0 to +3.5 ticks mean (p95 8) in B1 and +3.1 to +3.4 in B2 against HEAD; the clamp barely helps because most rifle killers are mid-clip with next_fire_tick a few ticks away. Against Zero Hour (0-3 ticks, not yet measured here): mean ZH + 4 holds only if ZH mean >= about 1; max ZH + 8 (11) is exceeded by the 16 maxima (a second removal while waiting, or a long delay). Shot latency overall is dominated by approach walks (mean 27-60), so only the NEAR column is informative: +0.9 / +2.0 (B1), -0.1 / +1.0 (B2). Not measured: the Zero Hour fixture itself (2f.1), a per-id spread.

Result: B fairly built is about -0.03 to -0.04 ms on p95 (open / dense), -0.05 to -0.14 on p99, p50 +0.03 to +0.11; it reaches 1.82 only on dense (1.805 / 1.797, within 0.02 of HEAD's 1.837) and not on open (1.871 / 1.887). The 2f.0 slowdown was the unfair prototype. Cost: 20 failing checks to re-word and 7 re-pins, a mean +3 tick retarget delay. Recommendation: drop B (gain is below what the re-pin and the feel departure justify); the open p95 gap of 0.05-0.09 ms is not closed by it. Logs: scratchpad `ws2k/{suite.*.log,feel.*.txt,ab_b1,ab_b2,ab_b1.out,ab_b2.out}`.

## 2h result (2026-11-08, working tree on f7ce33f vs git archive of f7ce33f, Apple M6, load 1.0-2.3; A1 as a kept fix, lazy per-bucket records)

Change: `game/scripts/simulation/combat.gd` only. `_build_grid` stores target dictionaries per bucket as `[targets, null]`; `_nearest` builds the flat records (`_records`, `_record`: id, centre, radius, building flag, position, bounds) on the bucket's first scan of the tick; same float expressions inline, unit radius read only in edge mode (the `_plan_return` scout has no `kind`). N1 (`test_nearest_matches_oracle`) is the spec; no test added.

Mutations (scratch copy, each turns N1 red, 7896 scans): building clamp bound +0.5 (40 mismatches); edge without target radius (537); building centre `size.x * 0.4` (53); centre-scan position offset (64); `units_only` filter inert (2325); lazy path: records skip the first target (7837), records built from one target only (6264).

Acceptance (accept.sh f7ce33f): suite 484 cases / 136037 checks / 0 failures (base same), four traces cmp-identical, 7 pin lines equal, lint and warnings pass (103 files), netplay match PASSED tick 8400, team match exit 0 with the cap line, `combat_work` identical. A/B numbers are in the ledger row: open p95 2.107 -> 1.906, dense 2.273 -> 1.836, hordes300 3.902 -> 3.604, p50 faster on all three.

Eager variant (records for all targets in `_build_grid`) dropped: same open / dense gains but team match p50 0.564 -> 0.638, p95 1.344 -> 1.445 (build_grid 0.066 -> 0.132 ms with 2.15 scans per tick); a 5-element unit record did not help (0.124).

Lazy variant on the team match (3 runs each, A/B): p50 0.564 / 0.564 / 0.565 -> 0.568 / 0.570 / 0.566, p95 1.337 / 1.336 / 1.341 -> 1.347 / 1.344 / 1.347, wall 47.81 / 47.81 / 47.86 s -> 48.00 / 48.07 / 47.93 s; build_grid 0.0659 -> 0.0691 ms. About +0.5 % to +1 %, marginally above the A/A spread (p50 0.001). Lockstep p99 0.065-0.066 -> 0.065-0.072 (noise). Logs: scratchpad `tools/runs/ab-2h`, `ab-2h-lazy`, `accept-2h`, `mut2h`.

## 2j result (2026-11-08, working tree on 740dbe4, A/B against f7ce33f (before c3e1e91) and HEAD, Apple M6, headless, load 1.1-2.3)

Round 2 gate finding: c3e1e91 cost the team match +0.7 % because `_build_grid` allocated a `[[], null]` wrapper per bucket (build_grid 0.0659 -> 0.0691 ms). Change (`game/scripts/simulation/combat.gd` only): buckets are plain target arrays again; `grid[owner]` is `[cells, records]` (one wrapper per owner), and `_nearest` fills `records[key]` on the bucket's first scan of the tick. Same float expressions, same `_combat_work`.

Mutations (scratch copy, N1 red, 7896 scans): records skip the first target (skipfirst: 7837 mismatches, the suite also hung past 5 min and was killed); records built from one target only (6264); side dictionary keyed `Vector2i(x, 0)` so buckets collide (5749).

3 rounds, P = f7ce33f, H = HEAD (740dbe4), W = working tree, interleaved P H W per script (median [min-max]), ms:

| Row | P | H | W |
|-----|---|---|---|
| team p50 | 0.565 [0.564-0.566] | 0.566 [0.566-0.567] | 0.561 [0.561-0.564] |
| team p95 | 1.339 | 1.339 | 1.331 [1.322-1.333] |
| team p99 | 2.886 | 2.880 | 2.876 |
| open p95 | 2.110 | 1.906 | 1.903 |
| dense p95 | 2.290 | 1.841 | 1.840 |
| hordes300 p95 | 3.902 | 2.954 | 2.962 |
| movement open / dense p95 | 1.585 / 1.577 | 1.583 / 1.573 | 1.589 / 1.582 |
| lockstep p99 | 0.067 | 0.068 | 0.066 |

All other combat layouts (contact, defences, docks, frc, ramp, skirmish3v3, transports) equal or better than P on W within the spread. The team match is now not worse than before c3e1e91 (p50 -0.004, p95 -0.008) and the open / dense gains hold. Team-match wall time was not measured in this run (p50 / p95 / p99 from the benchmark's `TEAM TIMING`, profiler on). Logs: scratchpad `ab2j`, `mut2j`, `tools/runs/accept-2j`.

Acceptance (accept.sh 740dbe4): suite 485 cases / 136039 checks / 0 failures, four traces cmp-identical, 7 pin lines equal, lint and warnings pass (103 files), netplay match PASSED tick 8400, team match exit 0 with the cap line.

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

Best prototype recovers about 0.015 ms on post-removal ticks (6-8 % of ticks), so p95 moves at most that much against a gap of 0.09 ms (open 1.91 vs 1.82) and an A/A spread of 0.01-0.07; the hordes300 gap is 1.14 ms (p95 2.957 vs 1.82). No fix kept, no A/B run, no suite run (nothing changed in the repo). Not tried: replacing the per-tick `held.cells` set by an entity-grid occupancy lookup (the only way to remove `hold_cells`), and a persistent set maintained across ticks; both change more than one function and need an Opus design first. Logs: scratchpad `ws2i/prof*.log`.

## R1 result (2026-11-08, A = git archive of 9a340bf, B = 9a340bf with `git revert --no-commit f6ed04f a1dfb03` in a scratch clone, Apple M6, rendered, vsync=off, load 1.4-2.8)

Revert: f6ed04f is a test-only change; a1dfb03 reverted with conflicts only in `docs/reference/performance.md` and `game/tests/test_view.gd` (took HEAD for both, irrelevant to the benchmark). B differs from A in `world_view.gd` (terrain drawn inline again) and lacks `terrain_view.gd`. Run `movement_benchmark.tscn -- --profile` 3x each, interleaved A B A B A B, one window at a time, no other godot/browser process before each run (the B1 pre-check shows only the waiting shell). Raw output in scratchpad `A1..A3.out`, `B1..B3.out`.

Rendered tick_ms (ms), runs 1/2/3:

| layout | tree | p50 | p95 | p99 | max |
|---|---|---|---|---|---|
| open | A | 2.50 / 2.54 / 2.55 | 2.73 / 2.65 / 2.68 | 3.04 / 2.84 / 2.90 | 6.8-6.9 |
| open | B | 3.04 / 2.60 / 2.54 | 3.34 / 2.77 / 2.65 | 3.50 / 2.96 / 2.84 | 6.8-7.8 |
| dense | A | 2.54 / 2.58 / 2.57 | 2.72 / 2.78 / 2.65 | 2.97 / 3.00 / 2.91 | 6.9-7.0 |
| dense | B | 2.65 / 2.65 / 2.59 | 3.11 / 2.82 / 2.70 | 3.17 / 2.98 / 2.95 | 7.0 |
| large_196 | A | 4.17 / 3.19 / 3.13 | 4.90 / 3.48 / 3.24 | 4.98 / 3.86 / 3.59 | 4.0-5.2 |
| large_196 | B | 3.68 / 3.66 / 3.65 | 4.01 / 4.01 / 4.00 | 4.06 / 4.07 / 4.11 | 4.7-5.0 |

Ticks over 8 ms: 0 of 1800 in every run (largest max 7.79 ms, B1 open; the 6.8-7.8 maxima are the two command ticks). Per-zone draw (A vs B, open/dense): draw 1.16 vs 1.20 / 1.16 vs 1.55 ms; draw.units 1.08 both; draw.terrain exists only in B (0.03 open, 0.40 dense). Draw calls per frame on large_196: A 6, B 4037 (frame interval p50 0.4-0.8 ms vs 95 ms).

### R1 finding

Not reproduced. On a quiet host the rendered open and dense tick p95 is 2.65-2.78 ms on A (current tree) in all three runs, not about 10 ms, and the terrain cache is not the cause: B (no cache) is equal or slightly worse (dense draw +0.4 ms, large_196 tick p50 3.7 vs 3.1-4.2, with 4037 draw calls and a 95 ms frame interval). Not reproduced at load up to 2.8; cause unproven. The earlier 10 ms tail was one run per tree on a loaded host (load 2.0-4.7) and may have been host load, but this was not shown: no run here reproduced it, so a1dfb03 is not shown to be the cause and not cleared for loads above 2.8. No fix proposed; keep a1dfb03. The large_196 A numbers vary between runs (p50 3.13-4.17, frame p95 0.45-2.84), so host noise on that layout is about 1 ms. R1 closed as not reproduced (3 runs per tree, same conclusion each).

## R2 result (2026-11-08, base 297d43e, A = scratch copy of the tree with the new layout and no cache, B = working tree with the structure layer, Apple M6, rendered, vsync=off, 1280x720, zoom 0.5, `-- --profile`)

Layout: `movement_benchmark.tscn` now runs open, dense, **ashfall**, horde (then large_196 with `--profile`). Ashfall = `game/data/maps/ashfall.json` (194x187, 3,669 blocked cells, 12 supply sources) with 300 move-only units (combat nulled like open/dense) starting at x 4-23, y 107-121 and moving between (41.5, 136.5) and (11.5, 111.5), plus seat 1's six base buildings (`usa_power_plant`, `supply_center`, `barracks`, `factory`, `command_center`, `defence` at the map slots). Camera on the base. Deterministic, no randomness; two legs settle at tick 891 and 2653 (headless check). Helpers: `movement_workload.gd` `_ashfall`, `issue_leg` takes an anchors array (default unchanged).

Runs (interleaved A1 B1 A2 B2 A3 B3, one window at a time, no other godot process; load average at start / end A 1.4/2.3, 3.3/1.9, 2.4/1.7; B 1.7/3.3, 1.9/2.4, 1.7/2.2). Tick / frame interval in ms, p50 / p95 / p99:

| layout | A (3 runs) | B (3 runs) |
|---|---|---|
| ashfall tick | 2.44 / 2.71-2.72 / 2.86-2.91 | 2.46-2.48 / 2.73-2.75 / 2.87-2.96 |
| ashfall frame | 0.835-0.839 / 2.90-3.02 / 5.16-5.18 | 0.835-0.836 / 2.89-2.93 / 4.69-4.70 |
| open frame | 0.55-0.59 / 1.62-2.15 / 4.26-4.38 | 0.50-0.60 / 1.40-2.16 / 4.23-4.41 |
| dense frame | 0.60 / 2.10-2.16 / 4.38-4.41 | 0.60 / 2.13-2.15 / 4.41-4.43 |
| large_196 frame | 0.80 / 2.57-2.96 / 5.24-7.22 | 0.80 / 2.96 / 5.25-5.27 |
| horde frame | 0.86-0.96 / 3.51-4.03 / 7.84-9.55 | 0.87-0.96 / 3.57-4.08 / 7.85-8.04 |
| tick p95 open / dense / large_196 / horde | 2.63-2.65 / 2.63-2.66 / 3.25-3.28 / 4.72-4.83 | 2.64-2.70 / 2.65-2.68 / 3.27-3.29 / 4.74-4.80 |

Draw calls p50: ashfall 45, open 5, dense 6, horde 222-229, large_196 6. All six runs exit 0, `RENDERED BENCHMARK PASSED 4`, `RENDERED PROFILE COMPLETE`, no `ERROR`.

Audit (tree A, per tick means, ms; `_draw` runs once per tick because `set_state` calls `queue_redraw`, frames in between replay the recorded commands): `draw` 1.57 = `draw.units` 1.05-1.06 (300 rects, health bars, then four more per-unit passes: crate, order, heading and horde marks, each recomputing `_vehicle_bounds`) + `draw.structures` 0.43-0.44 + `draw.overlays` 0.08. Around it `snapshot` 1.47, `view.copy` 0.08, `view.points` 0.08, `view.sort` 0.05. `draw.structures` is 28 % of `draw`, and 0.0005 ms on open/dense/large_196/horde (no buildings or piles), so it is an Ashfall effect. Cause: 12 piles x 2 `draw_string`, 6 glyphs, and `pile_lines` scanning all entities once per source (12 x 300). Not exercised by this layout (no selection, no combat, no hints): health bars of hurt units, hint rings, shot and target lines, focus boxes, order marks beyond idle ones; `draw.overlays` is 0.08 empty. They were not cached; they change with the tick and have no number here.

Change: `draw_structures()` (sources, buildings, glyphs, health, pile labels) now draws into a child `Structures` layer (`structure_layer.gd`, `show_behind_parent`, after `Terrain`, so the order terrain < structures < units/previews is unchanged). `set_state` builds a flat key (source id/origin/boxes/collector/waiting count/selected, building id/owner/kind/origin/completed/work/builder/hp/max_hp/selected) and calls `queue_redraw()` on the layer only when it differs from the last key. Waiting counts come from one entity pass (`_waiting_counts`) instead of one per source; `pile_lines` keeps its signature. Shared draw helpers (`_draw_footprint`, `_draw_label`, `_draw_glyph`, `_draw_health`) draw on `_canvas` (self, or the layer during `draw_structures`). Key cost `view.structures_key` 0.036 ms. Test V12 (`test_view.gd`): layer draws once, stays cached across ten ticks, redraws on selection and on a new building.

Result: `draw` 1.57 -> 1.14 ms (-0.43 ms, `draw.structures` has 0 calls in the 60 s window), but the frame interval and tick p95 do not improve beyond the A/A spread (frame p95 A 2.90-3.02, B 2.89-2.93; tick p95 +0.02-0.03 from the key cost). So the recording cost is not on the path that sets the frame interval here (the 45 retained draw calls still render every frame); the gain is CPU headroom per tick on a slower device, not a measured frame gain. Remaining Ashfall cost vs the small maps is rendering 45 draw calls (frame p50 0.84 vs 0.55-0.60) and `draw.units` 1.05 ms, which is the same on every layout. Candidate not done: one pass over entities in `_draw` instead of five (`_vehicle_bounds` is computed in `_draw`, `heading_marks`, `horde_marks`), about 0.3-0.5 ms by estimate (unmeasured).

Assertion (new, not an existing budget; nothing existing was loosened): `ASHFALL_FRAME_P95_MS` in `movement_benchmark.gd`, first 4.5 (worst measured frame p95 3.02 ms plus about 50 %), tightened to 3.3 on 2026-11-08 by the user's decision after the gate review (4.5 allowed 48 % over the 3.04 ms budget; Ashfall's own spread is 0.13 ms). The line is a regression guard for the large map, not the 16.7 ms frame line; with the 6x low-end assumption it would not hold. The failing direction of the assertion was not exercised (no run with a lowered ceiling). A rendered rerun at 3.3 is pending.

Acceptance: suite 486 cases (485 + V12) / 136044 checks / 0 failures / exit 0; `sh tools/run_lint.sh`, `sh tools/run_warnings.sh` exit 0; `WARGRID_REPLAY_TRACE`, economy, combat and team traces `cmp` identical against a git archive of 297d43e (1200 / 1200 / 1200 / 100 lines); the scratchpad `accept.sh` of earlier tasks was not available in this session, so this was done by hand (suite on both trees with the four trace variables). Netplay and team match not run (presentation only, no sim file touched). Raw output in scratchpad `A1..A3.out`, `B1..B3.out`.

## Workstream 4 result (2026-11-08, base 0aac476 via git archive, scratch copies in scratchpad `ws4`, Apple M6, headless, `bench_ab.sh` 3 rounds A B A B A B per group, no godot process before each run, load 1.1-1.5)

Method: for each hot function the typing was read first. The simulation code is already typed on the numbers (`float`/`int` locals, typed params and returns). What stayed Variant: values read from entity Dictionaries (`unit.position[0]`, `unit.combat.x`, `unit.owner`), `Array` elements (`rec[1]`, `waypoint[0]`), `for ... in range()` loop variables, `best: Variant` sentinels and the `_navigation: RefCounted` handle (dynamic calls). Each group got explicit types (typed local per Dictionary/Array read, `for x: int`, `Array` locals before indexing, int/Vector2i sentinel plus `found` flag instead of `Variant` null) and no other change. Group trees: g1 `Combat._nearest/_build_grid/_bucket`, g2 `Combat.plan/_approach/_hold_cells/_firing_cell`, g3 `Horde.step/_cell/_bucket/_level`, g4a `Locomotion.step/_desired/_route_length_until`, g4b `Simulation._advance`, g5 `_navigation: Navigation` (typed handle, 2 lines). A/A (base vs base): p50 delta -0.005 to +0.011, p95 -0.019 to +0.002, spread per tree 0.001-0.042 ms (largest hordes300 p95).

Median delta B - A (ms), p50 / p95, "<" = beats the spread (delta larger than the larger of the two spreads):

| Group | combat open | combat dense | hordes300 | movement open | movement dense | Verdict |
|---|---|---|---|---|---|---|
| A/A | -0.005 / -0.004 | -0.007 / +0.001 | -0.004 / -0.019 | +0.011 / 0.000 | +0.009 / +0.002 | spread |
| g1 nearest, build_grid | +0.002 / +0.001 | -0.009 / +0.003 | -0.001 / +0.003 | +0.005 / +0.004 | +0.001 / +0.008 | noise, not kept |
| g2 plan, approach, firing_cell | -0.003 / -0.001 | -0.010 / +0.003 | +0.010 / -0.038 (spread 0.04) | -0.002 / 0.000 | +0.001 / +0.001 | noise, not kept |
| g3 Horde | +0.004 / +0.013 | +0.002 / -0.008 | -0.047 / -0.059 < | -0.001 / -0.001 | -0.003 / 0.000 | kept (hordes300 only) |
| g4a Locomotion | -0.021 / -0.027 < | -0.013 / -0.026 < | -0.046 / -0.037 < | -0.037 / -0.052 < | -0.038 / -0.041 < | kept |
| g4b _advance | -0.019 / -0.019 < | -0.011 / -0.019 < | -0.029 / -0.037 < | -0.033 / -0.026 < | -0.036 / -0.038 < | kept |
| g5 typed navigation handle | +0.002 / +0.003 | -0.001 / -0.003 | +0.005 / -0.005 | -0.010 / -0.011 | -0.011 / -0.012 | below the spread (movement delta 0.7 %, B spread 0.017), not kept |
| g3+g4a+g4b combined | -0.042 / -0.048 < | -0.029 / -0.053 < | -0.138 / -0.156 < | -0.082 / -0.083 < | -0.082 / -0.087 < | kept |

Why g1 and g2 did nothing: the cost sits in the Dictionary lookups, `Vector2i` keys and the `sim._combat_work` property write, which typing does not remove; the locals g1 added were already typed. g3 and g4 pay because their inner loops did arithmetic on Variants (`waypoint[0] - x`, `other.position[0] - unit.position[0]`) and read `kind_def.*` Dictionary values several times per call; typed locals turn those into float instructions.

Team match (45000 ticks, profiler on, 3 runs A B A B A B, `run_team_match.gd`): p50 base 0.561 / 0.568 / 0.563, kept 0.550 / 0.550 / 0.549; p95 base 1.331 / 1.344 / 1.337, kept 1.303 / 1.307 / 1.303; not worse (about -2.3 %). `combat_work` identical in every A/B pair.

Kept (uncommitted): `horde.gd` (`step`, `_cell`, `_bucket`, `_level`), `locomotion.gd` (`step`, `_desired`, `_route_length_until`), `simulation.gd` (`_advance`: a local `route` written back to `unit.route` after each `slice(1)`, so `before[id]` aliasing is unchanged). No behaviour change, so no new test (the existing suite and traces are the proof). Acceptance: scratchpad `accept.sh HEAD`: suite 486 / 136044 / 0 failures on both trees, four traces cmp identical, 7 pins equal, lint, warnings (104 files), netplay match tick 8400, team match `cap tick=45000 winner=null units_peak=160`: `ACCEPT: PASS`. Perf budgets unchanged; combat open / dense / hordes300 stay report-only exceeded (hordes300 p95 2.977 -> 2.821).

Do the 1,044 `unsafe_*` findings relate to the hot paths? Partly in count, not in cost. With `unsafe_property_access`, `unsafe_method_access` and `unsafe_call_argument` as errors on the base tree: `combat.gd` 186 findings (80 inside lines 93-350, i.e. `plan` to `_nearest`), `horde.gd` 18, `locomotion.gd` 15, `simulation.gd` 147 (4 in `_advance`, 11 in `_assign_route`), `grid_navigation.gd` 7. So the hot functions hold about 125 findings (12 % of 1,044), mostly Variant Dictionary reads passed to typed parameters. The finding count does not predict gain: `_nearest` and `plan` hold the most and gained nothing when typed, while the 18 + 15 + 4 findings in Horde, Locomotion and `_advance` hold all the gain. Making the findings zero (Task 3) is therefore not a performance task; the profitable conversions are the ones where a Variant sits in float arithmetic inside a per-unit or per-neighbour loop. A* (`AStarGrid2D.get_id_path`) is native; `service_paths` has no typed-arithmetic loop, so nothing was tried there beyond g5.

Not done: g5 (below spread), `plan` body hoists (g2), Variant sentinels elsewhere (`Supply`, `Construction`, not hot in the workloads). Raw output: scratchpad `ws4/res_*.txt`, `ws4/run_*`, `ws4/tm4.*.out`, `ws4/accept/table.txt`.

## Workstream 5 tasks (Opus plan, 2026-11-08, read against 3ff3d07; nothing run)

Inputs: the [spike prompt](../performance-spike-prompt.txt) item 5, the threads research brief of 2026-11-07 (scratchpad `threads-gdext-brief.md`, not in the repo; threads part only, GDExtension dropped by the user), the 2a, 2f.0, 2i and Workstream 4 results above. User decisions (2026-11-08): a threaded web build is acceptable if Firefox and a Chromium browser (Vivaldi, `/Applications/Vivaldi.app`) work; Safari failure is not a blocker; the game is only served from the user's own fly static server, so COOP/COEP embedding limits do not matter; a fly deploy of the web app for the threaded-web test is approved (not the relay, not a release; ask for anything else); the wss relay must work under COEP, checked in a browser; native and WASM agree bit for bit; windows allowed (non-interactive, display on); a single-threaded build stays buildable.

### Parallel share re-estimated from the current profile

Latest zone split is the 2i scratch profile on ac1b7d4 (after the lazy flat records, before 2j and the Workstream 4 typing; profiler on, timer-inclusive), mean ms per tick, other ticks / post-removal ticks (the p95 ticks):

| Zone | open | dense | hordes300 |
|---|---|---|---|
| step | 1.19 / 1.83 | 0.95 / 1.83 | 2.07 / 3.14 |
| `combat.nearest` | 0.089 / 0.30 | 0.079 / 0.36 | 0.117 / 0.31 |
| `advance` (whole) | 0.39 / 0.39 | 0.33 / 0.37 | 1.04 / 1.14 |
| `advance.move` (Locomotion 0.21 + `_advance` rest 0.06 on open; 0.49 on hordes300 in 2a) | about 0.27 | about 0.24 | about 0.45 |

Workstream 4 then cut `advance.move` by about 0.03-0.08 ms (g4a + g4b). Parallel share f, with the rest of `plan` (claims, `_path_queue` order), `fire`, salvage, apply_orders (command order, RNG), `service_paths` (one shared `AStarGrid2D`, "two or more threads on the same AStar object causes corruption") and `Horde.step` (sequential `next_random`, `h.level` only 0.22 ms after 2d) kept serial:

- `_nearest` alone: f about 0.06-0.09 of the mean step (0.09-0.12 ms), 0.10-0.19 on post-removal ticks. Ceiling at 4 workers (Deck 4c/8t, web `godot_pool_size` 4): 1.05-1.07x mean, 1.08-1.17x on the p95 ticks.
- `advance.move` alone: f about 0.18-0.21 every tick (open about 0.22, hordes300 about 0.42 ms after Workstream 4). Ceiling 1.16-1.19x. It is the larger and simpler target: each moving unit writes only its own Dictionary (`position`, `heading`, `speed`, `route`, `status`, `order`), no RNG, no counters, no Profiler, no lazy cache except `Definitions.unit` (prewarm); route and waypoint arrays are created per unit (`_assign_route`, `_frozen(target.duplicate())`), so the read-only `Array::operator[]` temp is not shared between threads if no two units share an array (to be asserted, P4 below).
- Both: f about 0.25-0.30 mean, 0.28-0.31 on post-removal ticks; ceiling 1.23-1.29x at 4 workers. Realistic after two dispatches per tick (20-50 us each, unmeasured), one GDScript lambda call per element and refcount contention: about 1.05-1.15x native, less on web after the atomics cost. Team match (p50 0.55 ms, 2.15 scans per tick): dispatch alone is 4-9 % of its tick, so expect no gain or a loss without a size threshold. On the M6 the only row within reach is combat open p95 (1.865 vs 1.82); hordes300 (2.82) is not.

So the PoC is `advance.move` first, `_nearest` second, behind one flag. Expected verdict stays "safe but not worth it" unless 5b shows at least about 10 % on open / dense p50 and p95.

Shared mechanics for all tasks:
- One flag `Simulation.parallel` (static, default false): native from env `WARGRID_PARALLEL=1` (suite, netplay, benchmarks), web bench from `location.search` containing `parallel=1` (`JavaScriptBridge.eval`). Effective only when `OS.has_feature("threads")`, so single-threaded web runs the serial path unchanged. The shipped `Web` preset stays `variant/thread_support=false`.
- Web driver (scratchpad script, not in the repo): per run check `pgrep -fl 'godot|generalszh|firefox|Vivaldi'` is empty of our processes, record `uptime`, start `python3 -I tools/serve_web_bench.py <export dir> <results dir> <port>` (one port per build), launch the browser on a fresh profile, wait with Monitor until a new `web-*.log` in the results dir contains `BENCH DONE`, kill only the launched browser pid, record `uptime`. Firefox: `/Applications/Firefox.app/Contents/MacOS/firefox -no-remote -new-instance -profile <scratch profile> <url>`, `user.js` with `devtools.console.stdout.content`, `browser.shell.checkDefaultBrowser` false, `browser.aboutwelcome.enabled` false. Vivaldi: `/Applications/Vivaldi.app/Contents/MacOS/Vivaldi --user-data-dir=<scratch profile> --no-first-run --no-default-browser-check --enable-logging=stderr <url>` (console lines go to stderr; flag behaviour not verified). The window stays in front (the bench yields to the browser every 30 ticks; a hidden tab is throttled). Safari, optional: `open -a Safari <url>`, results through `/result`, close only that tab with `osascript`; Safari uses the user's own profile.
- Quiet host as in the prompt (no other Godot, suite, parity sweep or benchmark; load at start and end). A/B interleaved, 3 runs per arm, median and spread; a difference below the A/A spread is noise.

### Task 5a: threaded web bench export, atomics cost and relay under COEP (no parallel code)

- Files: `game/export_presets.cfg` (new preset `Web Bench Threads`, a copy of `Web Bench` with `variant/thread_support=true`, export path `../build/web-bench-threads/index.html`; `Web Bench` and `Web` unchanged), `game/benchmarks/bench_runner.gd`: (1) `DIGEST <workload> tick=<n> <StateHash.digest(sim.snapshot())>` after every workload; (2) `hordes300` added to the combat list (PoC target row); (3) the BENCH header also prints `threads=OS.has_feature("threads")` and `parallel=`; (4) on web only, a relay check after `BENCH DONE`: two `RelayTransport`s to the launcher's default `wss://wargrid-relay-jvm.fly.dev/ws`, the first sends `hello` with `match ""` and build `bench-relay-check` (an unmatched build string, so no player can join), the second joins the returned match code, wait for both `welcome` and `start` (10 s timeout), close both, emit `RELAY OK` or `RELAY FAILED <ready state / last message>`; reuse `Wire` and `RelayTransport`, no new protocol code.
- Commands: `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`; `sh tools/export_build.sh "Web Bench" build/web-bench/index.html`; `sh tools/export_build.sh "Web Bench Threads" build/web-bench-threads/index.html`; native reference `godot --headless --path game --script res://benchmarks/bench_runner.gd` and `sh tools/export_build.sh "macOS Bench" build/macos/WargridBench.app` then its binary `--headless`; web runs through the driver: Firefox A B A B A B (A = no-threads, B = threads), then Vivaldi the same; Safari one B run (optional, not a blocker).
- Pass: lint, warnings exit 0; both exports build; in Firefox and Vivaldi the threaded page reports `cross_origin_isolated=true`, `threads=true`, `BENCH DONE`, `BENCH POSTED`, `RELAY OK`; every `DIGEST` line identical across native editor, native release, no-threads web and threaded web in both browsers. Result: atomics cost = median B - A per row (p50 / p95 / p99) with the A/A spread, per browser.
- Expected: both browsers boot the threaded build (the official 4.7.2 `web_release.zip` thread template is installed); relay OK (WebSocket requests use mode "websocket", which COEP's CORP check does not apply to; unverified until this run); digests equal; atomics cost a few percent (unmeasured, could be 0-10 %).
- Risks: native vs WASM digest mismatch is a pre-existing open item (README); `HTTPRequest` POST inside a threaded build; Firefox or Vivaldi throttling when the window loses focus; the production relay sees two short-lived connections (same relay the test app uses); Safari may hang or fail (recorded, not a blocker).
- Needs a window: yes (browsers). Fly deploy: no. Quiet host: yes for the A/B timing; not for the boot and relay check.
- Stop early: (1) any `DIGEST` mismatch between native and no-threads web: pre-existing lockstep defect, a stop condition, ask before anything else; (2) the threaded build does not boot, or `RELAY FAILED`, in Firefox or Vivaldi: web threads infeasible, skip 5b-5d, go to 5e (native already passes the Deck budgets, so native-only threads close no row); (3) atomics cost above about 10 % of the step p50 on combat open or dense in both browsers (half the 4-worker ceiling, so no realistic PoC gain can pay for it): skip 5c, run 5b only if the user wants the native number. A cost above the A/A spread but below that line does not stop the plan: the user's stricter rule ("slower beyond the spread") would discard a possible net gain before measuring it; the coordinator asks the user which rule applies if the cost falls between.

### Task 5b: native proof of concept, parallel `advance.move` then speculative `_nearest`

- Files: `game/scripts/simulation/simulation.gd` (flag; in `step`, when parallel and at least `MIN_PARALLEL` moving units: prewarm `Definitions.unit(kind)` for each kind present, collect the moving unit Dictionaries in ascending id order, `WorkerThreadPool.add_group_task(func(i: int) -> void: _advance(moving[i]), moving.size(), -1, true)` then `wait_for_group_task_completion`; the `speed = 0.0` branch stays on the main thread), `game/scripts/simulation/combat.gd` (step 2 only: in parallel mode `_build_grid` fills the flat records eagerly, because the lazy `records[key] = ...` insert would be a Dictionary-resize race; prewarm `_reach_by_kind`, `Registry` caches and `radius_cache` for every kind present; collect the units that may scan this tick by an own-state superset predicate (brief A5 step 1); a pre-sized `Array` of slots `[result, work]` filled by a group task calling a pure `_nearest` without `sim._combat_work` and without Profiler; each sequential call site uses the slot only if its arguments (radius, units_only, edge) match and adds the slot's `work` to `sim._combat_work` on consumption, else calls inline), new suite `game/tests/test_parallel.gd` registered like the others, the benchmark scripts print `parallel_dispatches=` and fail when parallel is on and the count in the timed window is 0.
- Tests (spec first, mid tier or higher): P1 serial and parallel sims side by side, `StateHash.digest` and `combat_work` equal every tick for 2100 ticks on combat open, dense, hordes300 and a team-match prefix; P2 with step 2, every consumed slot equals the inline `_nearest` result and work; P3 hordes300 run 10 times in parallel mode, one final digest (race smoke test); P4 no two moving units share a `route` or waypoint array (`is_same`) on those workloads, the precondition of step 1. Each must go red on a mutation (for example the group task skipping the last element, or a slot consumed with mismatched arguments).
- Commands: `sh tools/run_tests.sh` with and without `WARGRID_PARALLEL=1` (same counts, 0 failures), the four trace variables in both modes and against a git archive of the base, `cmp`; 7 pins; `WARGRID_PARALLEL=1 sh tools/run_netplay.sh match` (tick 8400); `WARGRID_PARALLEL=1 sh tools/run_team_match.sh` (cap line); lint, warnings. Timing in git-archive scratch copies with an `override.cfg` setting `threading/worker_pool/max_threads=4` (Deck and web pool) and once at the default pool size: `run_combat.gd` (open, dense, hordes300), `run_movement.gd`, `run_team_match.gd`, serial vs parallel A B A B A B; a scratch micro-benchmark of an empty 300-element group task (p50 / p99 dispatch plus wait). Step 1 and step 2 measured separately.
- Pass: suite, traces, pins, netplay, team match identical in serial and parallel mode and equal to base; P1-P4 green and mutation-checked; speedup reported per row including dispatch and wait (the `step` zone wraps both).
- Expected: identical results; step 1 a few percent on combat open / dense and movement rows, more on hordes300; step 2 at most 1-3 % of the mean, more on p95; team match flat or slower below the threshold.
- Risks: a race that only shows as a rare digest drift (P3 and the suite in both modes are the net, not proof); GDScript lambda overhead per element larger than the work per unit (open has about 146 moving units); eager records cost the team match (+0.066 ms build_grid in 2h); the M6 has more cores than the Deck, so only the 4-thread numbers count.
- Needs a window: no. Fly: no. Quiet host: yes for timing.
- Stop early: step p50 and p95 gain at 4 threads below the A/A spread on combat open, dense and hordes300 for both steps: record "safe but not worth it" with the numbers, keep the PoC as a scratchpad patch (not committed), skip 5c, go to 5d only for question (a) if 5a passed, else 5e. Any trace, pin or digest difference between modes: stop condition.

### Task 5c: threaded web run of the PoC (digests and net gain)

- Files: none new; `bench_runner.gd` sets `Simulation.parallel` from the URL.
- Commands: `sh tools/export_build.sh "Web Bench Threads" build/web-bench-threads/index.html` and `"Web Bench"` on the 5b tree; driver runs per browser, interleaved A (no-threads), B (threads, parallel off, URL without the flag), C (threads, `?parallel=1`), 3 rounds, Firefox then Vivaldi.
- Pass: `DIGEST` lines in A, B and C in both browsers equal to native serial and native parallel (5b); `parallel_dispatches` > 0 in C; `RELAY OK`. Result: C vs A (the number that matters: net gain over today's live build) and C vs B, per row, with spreads.
- Expected: digests equal; C vs A smaller than the native gain by the 5a atomics cost; likely within a few percent of A.
- Risks: `wait_for_group_task_completion` busy-waits on the browser main thread (`proxy_to_pthread` off); Emscripten pool 8 vs Godot pool 4, a worker created on demand may need the main thread to yield (deadlock risk, unverified); `OS.get_processor_count()` is capped at 2 on web, so nothing may size work by it (`tasks_needed = -1`).
- Needs a window: yes. Fly: no. Quiet host: yes.
- Stop early: C not faster than A beyond the spread on combat open and dense in both browsers: "not worth it on web", recommend no threads, go to 5d only for question (a), then 5e. A digest mismatch: stop condition.

### Task 5d: threaded web build on the fly test app (approved deploy)

- Decision: use the existing separate app `wargrid-web-test` (`https://wargrid-web-test.fly.dev`) through `sh tools/deploy_web.sh test` (main carries `0.7.0-dev`, which the script requires and which keeps test clients out of production rooms on the shared relay). Production `wargrid-web` and the relay are not touched.
- Files (working tree only, reverted after the check unless 5e recommends keeping them): `game/export_presets.cfg` `Web` preset `variant/thread_support=true`; `web/sws.toml` adds `Cross-Origin-Opener-Policy = "same-origin"` and `Cross-Origin-Embedder-Policy = "require-corp"` to the existing `source = "**"` header block. The PoC flag stays off in the game build.
- Commands: local image check first (`container build -t wargrid-web web` after the export, run it, `curl -sI` on `/`, `/index.js`, `/index.wasm` with `Accept-Encoding: br`: both headers on every file including the precompressed responses, unverified for SWS); then `sh tools/deploy_web.sh test`; `curl -sI https://wargrid-web-test.fly.dev/` and `/index.wasm` for the headers; Firefox and Vivaldi on fresh profiles with console capture (pass: the Godot banner, no cross-origin isolation or `SharedArrayBuffer` error; a threaded Godot page refuses to start without isolation, so booting is the evidence); Safari `open -a Safari` (result only by a screenshot or the user's look: ask first, batched; not a blocker). A browser-to-browser match through the relay on this origin needs clicks: offer it to the user, do not drive it.
- Rollback: revert the two working-tree edits and run `sh tools/deploy_web.sh test` again (single-threaded), or redeploy the previous image from `fly releases -a wargrid-web-test --image`. Cost: one remote build and the suspend-on-idle `shared-cpu-1x` 256 MB machine already budgeted for the test app, cents.
- Pass: headers present on fly; Firefox and Vivaldi boot the threaded build; rollback done (or kept on the user's word), `/health` OK.
- Risks: SWS static-compression path not applying the advanced headers to `.br` / `.gz` responses; Safari failing (recorded); the test app left threaded by mistake (check `curl -sI` after rollback shows no COEP).
- Needs a window: yes. Fly deploy: yes (approved for this app only). Quiet host: no.
- Skip: if 5a failed to boot or relay in Firefox or Vivaldi.

### Task 5e: write-up and recommendation

- Files: `docs/reference/performance.md` (threads section answering (a), (b), (c) of the prompt plus ledger rows for 5a / 5b / 5c), this file (results, resume record), README "Browser build" only if a header or preset change is kept.
- Content: atomics cost per browser, native and web speedup per row with spreads and dispatch cost, digest table (also closes or keeps the README open item "floats in WASM versus native" with the evidence), browser matrix (Firefox, Vivaldi, Safari), relay under COEP, fly result and rollback state, which stages are not parallel and why. Recommendation per item: keep the `Web Bench Threads` preset and the `DIGEST` / relay lines (cheap, they test the native-WASM agreement) or drop them; PoC code committed only if 5b and 5c both beat the spread with a margin; the live site stays single-threaded unless the user decides otherwise after this write-up (a production deploy needs its own approval).
- Pass: links and labels checked; no budget or ceiling changed. Needs a window, fly or a quiet host: no.

## 5a result (2026-11-08, base 3ff3d07 + scratch patch, Apple M6, Firefox 159 and Vivaldi (Chrome/156), fresh profiles, one window at a time)

Scratch copy `w5a/game` (patch `w5a/5a.patch`, tracked tree untouched): preset `Web Bench Threads` (copy of `Web Bench`, `thread_support=true`), `bench_runner.gd` with `DIGEST` lines after every workload, `hordes300` in the combat list, `threads=` in the header and a two-`RelayTransport` check against `wss://wargrid-relay-jvm.fly.dev/ws` (build `bench-relay-check`, second client joins the returned code, waits for `welcome` and `start` on both, then `RELAY OK`). Served by `tools/serve_web_bench.py` (COOP/COEP) on 127.0.0.1; driver and logs in scratchpad `w5a/` (`driver.py`, `analyze.py`, `results/`).

- Finding, fixed in the scratch patch only: `combat_workload.gd` lines 127, 144, 177 spawned enemies inside `assert(sim.spawn(...) > 0)`. Release exports strip asserts, so in a release build (macOS Bench, web) `hordes300` had no enemy riflemen (`alive_end=300`) and its digest differed from the editor's (`f474bd792358b14b` vs `816e76bc1461ee53`). Not a lockstep defect; same side-effect-in-assert shape as `run_combat.gd` should be checked. The patch calls `spawn` outside `assert`; real repo fix is open.
- Fix landed in the tracked tree (commit f371616): `combat_workload.gd` spawns into a typed local, then asserts it; new case `BM10` (`test_benchmark.gd`, `test_workload_asserts_pure`; BM9 belongs to `test_horde_render_layout`) fails if a workload `assert` holds a `sim.` call (red before the fix). Only these 3 lines were impure of 43 `assert(` in `game/`. Debug traces and `run_combat.gd` deterministic fields (21 lines) identical to HEAD archive. The `hordes300`, `frc` and `horde_render` workloads had lost their enemies in release builds, so their digests and any release-build or web numbers for those three change (enemies now exist): rebaseline them.
- Digests: native editor, native release (macOS Bench), no-threads web and threaded web in Firefox and Vivaldi (13 web runs): all 8 `DIGEST` lines equal (e.g. `combat-open 93af489106268f6d`, `combat-hordes300 816e76bc1461ee53`, `team tick=45000 6625b5e7fd299d99`). No STOP.
- Boot and relay: threaded build boots in both browsers (`cross_origin_isolated=true`, `threads=true`, `BENCH DONE`, `BENCH POSTED`, `RELAY OK`: websocket connects and matches two clients under COEP). Firefox and Vivaldi no-threads build also `RELAY OK`.
- Host: `pgrep` for godot/generalszh/firefox/Vivaldi empty before every run; load 1.2-2.1 during the runs (this Mac's usual background, not idle). Runs 113-131 s each.
- Atomics cost, median(B threads) - median(A no-threads), 3 runs per arm, A/A spread = max-min of A. Combat rows ms:

| Browser | Row | p50 A / B (cost) | p95 A / B (cost) | p99 A / B (cost) | A/A spread p50 / p95 / p99 |
|---|---|---|---|---|---|
| Firefox | combat open | 1.740 / 1.821 (+4.7 %) | 3.500 / 3.599 (+2.8 %) | 5.240 / 5.380 (+2.7 %) | 0.02 / 0.16 / 0.54 |
| Firefox | combat dense | 1.440 / 1.560 (+8.3 %) | 2.580 / 2.679 (+3.8 %) | 3.000 / 3.139 (+4.6 %) | 0.00 / 0.02 / 0.04 |
| Firefox | hordes300 | 2.780 / 2.901 (+4.4 %) | 4.020 / 4.180 (+4.0 %) | 4.780 / 4.920 (+2.9 %) | 0.00 / 0.10 / 0.06 |
| Vivaldi | combat open | 1.650 / 1.655 (+0.3 %) | 2.545 / 2.546 (0.0 %) | 3.000 / 3.010 (+0.3 %) | 0.01 / 0.005 / 0.04 |
| Vivaldi | combat dense | 1.375 / 1.385 (+0.7 %) | 2.430 / 2.431 (0.0 %) | 2.840 / 2.826 (-0.5 %) | 0.01 / 0.01 / 0.02 |
| Vivaldi | hordes300 | 2.650 / 2.644 (-0.2 %) | 3.830 / 3.820 (-0.3 %) | 4.485 / 4.510 (+0.6 %) | 0.025 / 0.03 / 0.015 |

Other rows (movement, contact, skirmish3v3, team): Firefox +2.6 % to +7.1 % p50, Vivaldi within +-1.3 %. Full table: `python3 -I w5a/analyze.py`. Firefox rounds timers to 0.02 ms (cross-origin isolated), so its spreads are quantised.
- Stop rules: (3) cost above about 10 % of p50 on combat open or dense in both browsers: not met (Firefox +4.7 / +8.3 %, Vivaldi about 0). Firefox is above the A/A spread but below 10 %, Vivaldi within the spread: the case the plan leaves to the coordinator and the user (strict rule "slower beyond the spread" would reject threads for Firefox). The plan says to ask the user which rule applies; no answer is recorded, so no rule was confirmed and 5b ran under the plan's own reading (a cost under about 10 % does not stop the plan). Boot/relay stop (2) not triggered, so 5d is not skipped.
- Safari: not tested (user decision: not a blocker; ask the user if a look is wanted).
- Native editor / release timings in `w5a/native-*.log` are not comparable (headless, different build).

## 5b result (2026-11-08, base f371616, Apple M6 headless, scratch copy `ws5b` of a git archive; tracked tree untouched)

PoC patch (scratchpad `5b.patch`, not committed, not applied): `WARGRID_PARALLEL=1|move|scan` (default off, identical serial code path); step 1 `Simulation._advance_parallel` (moving units in id order, `Definitions.unit` prewarm, group task, `MIN_PARALLEL` 32, `WARGRID_PARALLEL_MIN`); step 2 `Combat._speculate` (eager records, `radius` prewarm, slots `[unit, radius, edge, result, work]`, `_nearest_slot` without counter or Profiler, `_scan_or_slot` consumes a slot only if radius and edge match and adds its work in call order). Suite `test_parallel.gd` (P1-P4, 19 checks) plus the benchmarks `ab.gd` and `dispatch.gd`, all scratch.

- Digests (no STOP): P1 `StateHash.digest(snapshot)` and `_combat_work` equal every tick for 2100 ticks on combat open, dense, hordes300 and a team-match prefix (`min_parallel` 4 to force dispatch); P2 176 895 consumed slots equal the inline `_nearest` result and work, 0 mismatches; P3 10 parallel hordes300 runs (1000 ticks) equal the serial digest; P4 no shared route, position, heading or first-three waypoint arrays (`is_same`, sampled). Mutations red: group task one element short (9 failures), slot consumed with a halved radius and the argument check removed (8 failures, P2 32 070 mismatches).
- Suite: base 487 cases / 136 046 checks, scratch serial and `WARGRID_PARALLEL=1` 491 / 136 065 (+4 cases, +19 checks = P1-P4), 0 failures, exit 0. The four replay traces (replay, economy, combat, team) `cmp`-identical across base, scratch serial and scratch parallel. The 7 pins are suite cases, green in both modes. `WARGRID_PARALLEL=1 run_netplay.sh match`: terminal tick 8400, passed. `WARGRID_PARALLEL=1 run_team_match.sh`: `TEAM MATCH cap tick=45000 winner=null units_peak=160`. `run_lint.sh` and `run_warnings.sh` (104 files) clean on the PoC.
- Timing: `ab.gd` (sim.step only, 300 warmup + 1800 samples; team 3000 ticks of the match start; movement dense with legs), `override.cfg` `max_threads` 4 and 2, 3 rounds, arms serial / move / scan / both interleaved per layout, median, A/A spread = max-min of the 3 serial runs. Host: no other godot/browser (`pgrep`), but load average 3.2 at start (just after the suite), 1.5 at end: not an idle host; spreads are small anyway. Delta vs serial median, ms (%):

| Row (4 threads) | p50 A / spread | step 1 move p50 / p95 / p99 | step 2 scan p50 / p95 / p99 | both p95 |
|---|---|---|---|---|
| combat open | 1.215 / 0.007 | -0.040 (-3.3) / -0.036 (-1.9) / -0.042 (-1.9) | +0.097 (+8.0) / +0.152 (+8.2) / +0.134 | +0.097 (+5.2) |
| combat dense | 1.010 / 0.017 | -0.009 (-0.9) / -0.043 (-2.4) / -0.019 | +0.077 (+7.6) / +0.146 (+8.1) / +0.052 | +0.097 (+5.4) |
| hordes300 | 1.947 / 0.011 | -0.069 (-3.5) / -0.070 (-2.5) / -0.068 | +0.347 (+17.8) / +0.186 (+6.6) / +0.190 | +0.091 (+3.2) |
| team match start | 0.274 / 0.003 | +0.002 / +0.001 / +0.014 | +0.011 (+4.0) / +0.020 (+3.0) / +0.035 | +0.023 (+3.5) |
| movement dense | 0.646 / 0.002 | -0.089 (-13.8) / -0.101 (-14.9) / -0.118 (-13.5) | +0.001 | -0.098 (-14.5) |

A/A p95 spreads: 0.004-0.017 ms (p99 up to 0.048). At 2 threads step 1 is a loss: open +0.036 / +0.040 / +0.038, dense +0.023 / +0.046 / +0.038, hordes300 +0.060 / +0.074 / +0.051, movement dense +0.050 / +0.047 (+7-8 %), team flat; step 2 +7-18 % everywhere, both worse still.
- Dispatch (empty-ish group task, 2000 rounds, add + wait): 4 threads p50 / p99 10 / 18 us (n=32), 20 / 29 us (n=150), 34 / 43 us (n=300); 2 threads 7 / 13, 15 / 23, 30 / 35 us. Dispatch is not the blocker; the lambda call per element, refcount traffic and (step 2) the eager records are.
- Verdict: step 2 (speculative `_nearest`) is slower on every row, drop it. Step 1 (`advance.move`) clears the written bar on 4 threads (gain beyond the A/A spread on open, dense, hordes300 p95, team match not worse) but by 0.04-0.07 ms (2-3 %), 14 % only on movement dense; at 2 threads it loses. Native only; the web atomics cost from 5a (Firefox +3-8 %) is larger than the step 1 gain, so a threaded web build is expected to lose. That expectation is measured for Firefox only: Vivaldi's atomics cost was about 0 (within the spread), so a Vivaldi net gain of 2-3 % is possible and was not measured. No budget or ceiling changed, no row closed (combat open p95 1.862 vs 1.82 stays exceeded).
- Task 5c (threaded web run of the PoC) skipped: coordinator decision. Step 1 did beat the A/A spread, but the gain of 2-3 % is far below the 10 % bar the plan set for continuing, and it loses at 2 threads. The web net gain is therefore unmeasured, not shown to be negative.
- Scope of "safe": native only, M6 only (12 cores, not the Deck), P4 (no shared route or waypoint arrays) sampled, not exhaustive, and the load average was 3.2 at the start of the timing. Native against WASM agreement in parallel mode was never measured (5a compared serial digests only).

## 5d result (2026-11-08, base db2178f, scratch copy `ws5d` of a git archive; tracked tree untouched)

- Edits (scratch only): `Web` preset `variant/thread_support=true`, `web/sws.toml` COOP `same-origin` + COEP `require-corp` in the `**` block. `sh tools/deploy_web.sh test` to `wargrid-web-test` (2m43s incl. remote build; release v4).
- Headers: `curl -sI` with `Accept-Encoding` identity / br / gzip on `/`, `/index.html`, `/index.js`, `/index.wasm`, `/index.pck`, `/index.audio.worklet.js`: COOP and COEP present on all 18 responses, including the precompressed `.br` / `.gz` ones (the 5d risk did not occur).
- Firefox 159 and Vivaldi (Chromium), fresh profiles, one at a time, no interaction (driven over BiDi / CDP): `crossOriginIsolated=true`, `SharedArrayBuffer` defined, Godot 4.7.2 banner "Build configuration: Emscripten 4.0.20, multi-threaded", canvas created, title "Wargrid". Not driven: a browser-to-browser match on this origin (needs clicks). Relay: only `wss://wargrid-relay-jvm.fly.dev/ws` opens from node; the websocket-under-COEP check is the 5a `RELAY OK` result (same build, local COOP/COEP server), not repeated from the fly origin.
- Safari not tested. To check: `crossOriginIsolated` in the web inspector, boot to the menu, no `SharedArrayBuffer` error, a match through the relay, audio worklet, cost against the single-threaded build.
- Rollback: `sh tools/deploy_web.sh test` from a clean `git archive HEAD` (release v5): no COOP/COEP on `/` or `/index.wasm`, `/health` 200. Cost: two remote builds plus the idle-suspending shared-cpu-1x test machine, cents. Production `wargrid-web` and the relay not touched. Browsers and helper scripts stopped.

## Gap closure CPU-light tasks T0a-T0f (2026-11-08, HEAD 43bf48e plus uncommitted docs, Apple M6, no Godot process run, reading only)

Plan: [spike gap closure](../superpowers/plans/2026-11-08-spike-gap-closure.md). Edits: `performance.md` (narrow text fixes), the plan's gate table (G9, G14, G15). No file under `game/` or `tools/` changed (a benchmark job was running in the tree). No budget, ceiling or guard value changed, no verdict flipped.

### T0a claims audit

| Claim | Finding | Action |
|---|---|---|
| "Existing gates ... rendered probe: frame p95 ≤ 16.7 ms" | **False.** `rg` over `game/` finds no 16.7 gate; `movement_benchmark.gd` asserts only the Ashfall guard (line 168, `ASHFALL_FRAME_P95_MS` 3.3) plus workload checks. 16.7 ms is the render goal. History rows saying "frame p95 passes the 16.7 ms line" compared by hand and stay as history | text fixed |
| movement "1.59 / 1.58, 13 % margin" | stale: WS4 gave 1.501 / 1.487 (ledger row Workstream 4) | cell updated, margin about 17 % |
| counters table "combat target checks: not implemented" | stale: `combat_work()` is gated by BM6 and BM6b in `test_benchmark.gd` | row replaced |
| counters table snapshot "79,481 / 80,345 / 322" | stale: ceilings are 84,119 / 84,983 / 336 (`test_benchmark.gd:88`, M6 Tasks 8-9) | row replaced; the plan's G15 value (82,703 / 83,567) was also stale, fixed |
| plumbing 0.91 "current about 1.9" | 2026-11-03 scratch probe; R2 Ashfall profile gives 1.68, which counts the snapshot twice (harness `settled()`); one snapshot gives 0.87 (T10 design, P0) | both values, labelled |
| R2 "passes 3.04 by 0.02" | holds only for `--profile` runs; one unprofiled run gave 0.506 | labelled; verdict open until U3 |
| rec 1 ranked first | its design says do not build | marked in the text; re-rank is T6 |
| rec 3 "0.3-0.5 ms" | unlabelled estimate | labelled "not measured" |
| "release 18-20 % faster" | 2026-11-06, before the fixes and f371616 | dated; Job C re-measures |
| cumulative 20a4d06 to WS4 numbers | different days and loads | left as is, Job D replaces them (T1) |
| `TEAM TIMING` includes the profiler | confirmed in code: `run_team_match.gd` sets `Profiler.enabled = true` before the loop, so the printed p95 / p99 are profiler-on | Job A quantifies; not edited |
| Gate-inventory G1-G8, G10, G13, G14 locations and values | all confirmed: `run_movement.gd:74` (8 / 16), `run_combat.gd:10-12` (ceilings 3.05 / 4.23 and 3.31 / 5.01, budget 1.82 / 3.64), `run_lockstep.gd:11` 0.6, `movement_benchmark.gd:10` 3.3, `test_benchmark.gd:183` (16000, 18500], `:197` ≤ 1500, `run_benchmark.sh` PASS counts 2 and 1. `transports`, `defences`, `ramp`, `frc`, `hordes300`, `docks` are report-only (early return before any budget check) | none |

No claim found that would flip a pass or fail verdict.

### T0b gate inventory

Inventory table corrected in place: G9 (no such gate, ledger text fixed), G14 (confirmed), G15 (84,119 / 84,983, busiest 336). The rendered 16.7 ms gate does not exist.

### T0c bound for per-cell, per-team counts (rec 2)

Code (`combat.gd` `_nearest`): per call, per owner in the grid, `hostile()` is checked first; then each window cell costs one `cells.has(Vector2i)`. Per-team counts replace the per-owner `has` with one lookup per cell, so the saving is (hostile owners - 1) lookups per window cell per call, and 0 on a layout with one hostile owner: `open`, `dense`, `contact`, `hordes300` (2 owners), which are the failing rows. Only the team match (3v3) and `skirmish3v3` have 2-3 hostile owners, and both pass 1.82 / 3.64 already. Friendly-owner iteration (the 85-90 % non-hostile candidates of 2a) is a different cost and is not touched by per-cell counts. The per-lookup cost was not measured (estimate only), so the bound is stated as 0 on every failing row and unquantified on two passing rows. Result: not attempted, not on a failing row; Q4 not needed.

### T0d CI guard design

Written into `performance.md` "Not covered yet" (already gated: BM5, BM6, BM6b; add path-queue peak and a `_nearest` call counter; wall-clock rows trend-only). No workflow edited.

### T0e rebaseline check after f371616

Confirmed by `rg`: committed `bench_runner.gd:28-29` runs movement open and dense and combat open, dense, contact, skirmish3v3 only. No committed release or web number for `hordes300`, `frc` or `horde_render` predates f371616 (the F = 5.5 rows and the 5a rows: the 5a `hordes300` numbers came from a scratch patch that already spawned enemies outside `assert`, digests equal to the editor's). Nothing to rebaseline; the "rebaseline" remaining-work item is rewritten in `performance.md` to "no F for hordes300 yet".

Deferred edit (not applied; U1 and Q6 need it; apply after the benchmark job ends, then run lint and warnings), `game/benchmarks/bench_runner.gd` line 29:

```diff
-	for layout: String in ["open", "dense", "contact", "skirmish3v3"]: await _combat(layout)
+	for layout: String in ["open", "dense", "contact", "skirmish3v3", "hordes300"]: await _combat(layout)
```

`_combat` (line 51) is generic over `CombatWorkload.create(layout)`, so no other change is needed.

### T0f scratch scripts (parse-checked with `sh -n` only, never run)

Directory `/private/tmp/claude-501/-Users-pdstuber-projects-wargrid/f3d3e9b0-7fed-4adb-93af-49de839b7d31/scratchpad/ws8/`: `scale_workload.gd` and `run_scale.gd` (Q2: total units and owner count via user args, 128x96 map, spawn failures recorded), `run_mem.gd` (Q3: `MEMORY_STATIC`, `OBJECT_COUNT`, node count every 300 ticks on `hordes300` or the team match), `batch.sh` (Q1 x10 combat + movement, 10 team runs, Q2 units 150-600 and owners 2-6, Q3; ws6 guard; one STOP line per failed job). Each Godot script calls `quit(0)` on its only path. Not included: Q2 on 20a4d06, Q4 (T0c says not needed), Q6, Q5, Q7, Q8. The batch copies the three scripts into a git-archive copy given as argument; GDScript files in `game/` root are scratch only.

## 7 results (Deck native) (2026-11-08, HEAD 70fa93d via git archive, Steam Deck, headless, native editor build; web half not run)

- Setup: `git archive HEAD` to `~/wargrid-f55/tree`, Godot 4.7.2 `ed1daf0bf` Linux zip checked against the CI SHA-256 `cadd3204...5329e4` (OK), run as a `systemd-run --user` unit, jobs strictly one after another with 20 s gaps. Method as in 'Target factor measurement (2026-11-06)': `bench_runner.gd` (movement open/dense, combat open/dense/contact/skirmish3v3, team match with profiler) plus `run_combat.gd` for `hordes300` and `run_lockstep.gd`, 300 warm-up + 1800 samples, 3 runs each (team match 45000 ticks, ended at the cap, not a terminal state).
- Host: ACAD 1 at the start and end of every job; load average (1 min) 0.34-1.86 at job edges (1.86 right after the suite, 0.5-1.4 before benches); Steam client and its webhelpers were running (idle, not touched), no godot or firefox process before or after. Not a fully quiet device.
- Reproduction: suite 487 cases / 136046 checks / 0 failures (Mac HEAD: same). The four traces, `cmp`-identical to the Mac's from the earlier quiet run (`scratchpad/tr/*-head.tsv`): replay `c06ae74939594bb8`, economy `eda7de05a7919065`, combat `111b69234c7215ef`, team `84a9ece1c60ba7b1` (first 16 hex of SHA-256).
- Deck median of 3 (range of the 3 runs for p95 in brackets), ms:

| Row | p50 | p95 | p99 | max | Mac WS4 p95 | F p95 (provisional) |
|---|---|---|---|---|---|---|
| movement open | 5.891 | 6.566 [6.351-6.652] | 7.209 | 17.326 | 1.501 | 4.37 |
| movement dense | 6.087 | 6.544 [6.452-6.681] | 7.403 | 18.274 | 1.487 | 4.40 |
| combat open | 4.424 | 6.869 [6.788-6.937] | 8.131 | 10.532 | 1.865 | 3.68 |
| combat dense | 3.530 | 6.614 [6.412-6.625] | 7.649 | 11.066 | 1.796 | 3.68 |
| combat contact | 0.867 | 4.030 [4.016-4.114] | 5.694 | 37.343 | n/a | n/a |
| combat skirmish3v3 | 1.929 | 4.577 [4.470-4.578] | 5.108 | 5.728 | n/a | n/a |
| hordes300 (run_combat) | 7.393 | 10.658 [10.593-10.681] | 12.496 | 26.763 | 2.821 | 3.78 |
| team match | 2.084 | 4.780 [4.776-4.857] | 10.581 | 34.097 | 1.303 | 3.67 (see below) |
| lockstep overhead | 0.033 | 0.076 | 0.229 | 0.787 | n/a | 2026-11-06 Mac 0.067 p99 gives 3.4 |

- `run_combat.gd` open / dense p95 6.850 / 6.524 agree with `bench_runner` within 1.5 %.
- F (provisional): p95 Deck / Mac Workstream 4 numbers is 3.7-4.4, below 5.5 (2026-11-06 native editor: 3.5-4.2; movement rows are higher now because the Mac sim got faster by about 5 % while the Deck did not drop as much). Caveat: the Mac team-match 1.303 comes from the Workstream 4 profile run, not the 2026-11-06 bench_runner window (Mac 2.411 p95 then), so the team F is not comparable until the Mac re-baseline job runs `bench_runner` the same way. Final F waits for that.
- Against the target budgets (10 / 20 ms) on native editor build: every row passes except `hordes300` p95 10.66 (report-only row, 6.6 % over). Team match p99 10.6 (was 20.4 on 2026-11-06). Worst ticks: team match 34 ms (about one 33.3 ms tick), `contact` 37 ms (deterministic warm-up spike, cf. open item above).
- Would run for the Firefox half (needs a window and the user's OK): `sh tools/export_build.sh "Web Bench" build/web-bench/index.html` (Mac), copy `build/web-bench` and `tools/serve_web_bench.py` to a folder under `~` on the Deck, `systemd-run --user python3 -I serve_web_bench.py build/web-bench build/web-results`, then `systemd-run --user flatpak run org.mozilla.firefox http://127.0.0.1:8060/` with the tab in front, 3 runs (fresh profile), `crossOriginIsolated` true; the page posts the log to `/result`. Note `bench_runner.gd` in the web build does not include `hordes300` unless added.
- Cleanup: removed `~/wargrid-f55`, `~/.local/share/godot/app_userdata/Wargrid`, the empty `export_templates`, `~/.cache/godot`, `~/.config/godot` (all created by this run at 07:45); `HearthSpike` untouched. Raw logs: scratchpad `deck-out/` and `deck-tr/`.

## 6 results (2026-11-08, HEAD 003e66c and 20a4d06 via git archive, scratch copies `ws6` in the scratchpad, Apple M6, headless; nothing changed in the repo; 3 runs per arm, A B A B A B; load 1.2-1.6 at every start, no godot process before each run)

### A. Team match, profiler on vs off (item 4)

Scratch archive of HEAD with only `run_team_match.gd` changed: `Profiler.enabled = false` for the whole run, `TEAM TIMING` samples from tick 300 on, worst tick logged (A = unmodified, B = scratch). All 6 runs end `TEAM MATCH cap tick=45000 winner=null units_peak=160`.

| Arm (median of 3, spread) | p50 | p95 | p99 | max |
|---|---|---|---|---|
| A profiler on, ticks 0-44999 | 0.551 (0.006) | 1.301 (0.015) | 2.863 (0.039) | 10.199 (0.143) |
| B profiler off, ticks 300-44999 | 0.550 (0.004) | 1.310 (0.007) | 2.860 (0.023) | 10.175 (0.116) |

B with the warm-up kept (`TEAM TIMING_ALL`): p95 1.299 / 1.306 / 1.305, max 10.077 / 10.191 / 10.175. The profiler costs nothing measurable in this run (zones are one bool check when off, and the harness only enables it for the 300 warm-up ticks report). Worst tick: 5730 in all 3 runs (10.1-10.2 ms), deterministic.

### B. Contact layout max (item 5)

Scratch runner `run_b.gd` (per-tick `step_us` with tick index, `snapshot()` untimed after, 2100 ticks, 3 plain runs plus one profiled run). Top ticks are identical in all runs: tick 0 27 ms (before the timed window), then every 60 ticks: 120 = 25.1, 60 = 23.8, 180 = 15.8, 240 = 14.4, 420 = 11.3, 360 = 10.9, 300 = 10.8 ms, then 480 = 6.1, 540 = 5.2, 600 = 5.1; 11 ticks over 5 ms, all others 1.6 ms or less. The timed window starts at tick 300, so its max (11.2-11.4, the ledger's 11.8 with the other build state) is tick 420, and tick 300 and 360 follow it. Zone at tick 420 (profiled run): `step.combat_fire` 10.2 of 11.2 ms, `combat_plan` 0.74, `snapshot` 0.50. Same zone on every top tick (21.9, 23.2, 21.8, 14.1, 13.1 ms at ticks 0, 120, 60, 180, 240). Explained: the contact layout is two blocks that start in range, so every unit fires on the same 60-tick reload cadence; the volley ticks are `combat_fire` (damage, death handling) over all armed units, and the cost falls as units die (alive_end 24). It is a synchronised-volley spike by design of the layout, not a rescan or a stray outlier. Not fixed (report-only row, no code changed).

### C. Release export (item 9)

`GODOT_BIN=godot sh tools/export_build.sh "macOS Bench" ...` from git archives of 20a4d06 and HEAD; export templates 4.7.2.stable match the editor (4.7.2.stable.official), exit 0 for both. The binary is `WargridBench.app/Contents/MacOS/Wargrid`; the run prints `debug_build=false`; the editor `bench_runner.gd` run prints `debug_build=true`. Per round: release 20a4d06, release HEAD, editor HEAD (the three-way A B A B A B). Median of 3, ms (spread at most 0.03 on p95):

| Row p95 (p99) | release 20a4d06 | release HEAD | editor HEAD | release / editor (HEAD) |
|---|---|---|---|---|
| movement open | 1.340 (1.490) | 1.266 (1.370) | 1.521 (1.660) | 0.83 (0.83) |
| movement dense | 1.325 (1.506) | 1.256 (1.425) | 1.499 (1.695) | 0.84 (0.84) |
| combat open | 2.231 (2.948) | 1.521 (1.813) | 1.866 (2.209) | 0.82 (0.82) |
| combat dense | 2.504 (3.722) | 1.464 (1.710) | 1.802 (2.113) | 0.81 (0.81) |
| combat contact | 0.985 (1.433) | 0.936 (1.322) | 1.152 (1.601) | 0.81 (0.83) |
| combat skirmish3v3 | 1.180 (1.329) | 1.072 (1.198) | 1.298 (1.459) | 0.83 (0.82) |
| team match (profiler on) | 1.167 (2.399) | 1.067 (2.365) | 1.305 (2.859) | 0.82 (0.83) |

Max (ms): team match 9.55 / 9.52 / 10.25, contact 9.67 / 9.05 / 11.26. Release builds are 17-19 % faster than the editor build (matches the 2026-11-06 18-20 %), and the HEAD gains over 20a4d06 carry into the release build (combat open p95 -32 %, dense -42 %). The bench runner (30-tick chunks, `snapshot()` untimed) reproduces the benchmark scripts within about 2 %.

### D. Re-baseline 20a4d06 (A) vs HEAD (B), `bench_ab.sh` 3 rounds A B A B A B, editor build

median of 3 (A/A spread across the 3 runs in brackets), ms; verdict is the tool's (delta against the larger spread):

| Row | p50 A -> B | p95 A -> B | p99 A -> B | max A -> B |
|---|---|---|---|---|
| movement open | 1.525 -> 1.443 | 1.617 (0.049) -> 1.519 (0.010) faster | 1.824 -> 1.659 | 4.86 -> 4.92 noise |
| movement dense | 1.535 -> 1.447 | 1.597 (0.086) -> 1.507 (0.022) faster | 1.819 (1.700, one outlier) -> 1.696 noise | 5.04 -> 4.99 noise |
| combat open | 1.551 -> 1.217 | 2.751 (0.035) -> 1.868 (0.021), -0.883 | 3.656 -> 2.204, -1.452 | 4.65 -> 3.00 |
| combat dense | 1.194 -> 1.022 | 3.083 (0.042) -> 1.808 (0.013), -1.275 | 4.626 -> 2.107, -2.519 | 5.80 -> 3.23 |
| combat hordes300 | 3.818 -> 1.942 | 5.552 (0.093) -> 2.838 (0.039), -2.714 | 7.048 -> 3.371 (B spread 0.657), -3.677 | 9.72 -> 7.56 |
| lockstep overhead | 0.009 -> 0.009 | 0.016 -> 0.016 | 0.067 -> 0.066 | 0.162 -> 0.161 |
| team match (profiler on) | 0.571 -> 0.550 | 1.409 (0.010) -> 1.308 (0.003) | 2.892 -> 2.855 | 10.39 -> 10.26 |

`combat_work` IDENTICAL for open, dense and hordes300 in all runs. hordes300: `alive_start=400 alive_end=292` on both trees in the editor, i.e. enemies exist on both (the `f371616` workload fix matters only when asserts are stripped, in a release build, where the 20a4d06 workload spawned no enemies; the Task 6 release rows above do not include hordes300, so no release comparison exists for that row). Team match cap line on all 6 runs. Lockstep p99 0.066-0.070 against the 0.6 limit, `PASS` on all 6.

Worst of the 3 HEAD runs and +5 % (the existing ceiling rule), p95 / p99:

| Row | worst p95 | +5 % | worst p99 | +5 % | current ceiling p95 / p99 |
|---|---|---|---|---|---|
| combat open | 1.878 | 1.97 | 2.204 | 2.31 | 3.05 / 4.23 |
| combat dense | 1.810 | 1.90 | 2.140 | 2.25 | 3.31 / 5.01 |
| combat hordes300 | 2.871 | 3.01 | 3.982 (one outlier run; the other two 3.325, 3.371) | 4.18 (3.54 without the outlier) | none |

Recommendation input only (no ceiling changed): the open and dense ceilings sit about 55-75 % above the HEAD worst-of-3, so they no longer guard against a regression of less than that; tightening needs the user's approval and more than 3 runs.

### E. `sh tools/run_benchmark.sh` on HEAD in the repo tree (docs uncommitted, no code change)

Exit 0 (not 1: open 1.887 / 2.212 and dense 1.809 / 2.137 are above the 1.82 / 3.64 budget on p95 only but below their report-only ceilings, so `COMBAT STRESS PASS`), `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1` and `LOCKSTEP BUDGET PASS p99 0.066 ms` printed (the lockstep line is reached). movement open / dense p95 1.506 / 1.482, hordes300 2.840 / 3.301. Load 1.5-1.8.

### Check on both trees

`accept.sh 20a4d06` (working tree copy vs archive): suite CASES 487 / CHECKS 136046 / FAILURES 0 (base 482 / 136033), four replay traces cmp-identical, 7 pin lines equal, lint `Success: no problems found`, warnings 104 files, netplay match tick 8400, team match cap line: `ACCEPT: PASS`. No trace or pin differs between the archives.

# Sim quick wins verification

```text
Resume record (updated 2026-11-13 night: Task 6 green)
Branch / base commit / working-tree state: sim-quick-wins / 00778f3 (Task 5 commit) / Task 6 edits uncommitted
Last green task / next incomplete task: Task 6 / Task 7
Changed paths since last commit: game/scripts/net/lockstep.gd, game/scripts/net/headless_client.gd, game/scripts/online_main.gd, game/tests/test_lockstep.gd, tools/desync_diff.py, tools/test_desync_diff.py, tools/run_netplay.sh, docs/reference/sim-quick-wins-verification.md
Last command / cases / checks / failures / exit / marker: full suite with traces (*-t6.tsv) / 857 / 144247 / 0 / exit 0 / TESTS PASSED 144247; sh tools/run_checks.sh CHECKS PASSED 5; run_netplay.sh perturb NETPLAY PASSED, match NETPLAY PASSED terminal tick 9129 (logs t6-suite.log, t6-checks.log, t6-perturb.log, t6-match.log)
Known red case or blocker: none; plan approved 2026-11-13 (user, all seven questions answered, see the plan)
Approved decisions, pre-authorizations used, deferred gates: package note "Sim quick wins" (user, 2026-11-13); local commits per GREEN task only if the night run handoff grants them
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: Task 7 (oracle ring log, tools/desync_bisect.py), in the worktree ~/projects/wargrid-wt-simwins
```

Plan: [Sim quick wins plan](../superpowers/plans/2026-11-13-sim-quick-wins.md). Spec: `docs/packages.md` package note "Sim quick wins"; `docs/reference/simulation-reference-review.md` §5.1, §5.4 (a), §6, "Review 2026-11-13". Logs: `~/projects/wargrid-overnight-work/sim-quick-wins/logs/` (outside the repository).

## Tasks

| Task | What | Model | Status |
|---|---|---|---|
| 0 | Baseline: worktree, import, suite and traces, pins, profile and benchmark before | Sonnet | green |
| 1 | Profiler zones: `step.advance` split, `combat.splash` | Sonnet | green |
| 2 | Scaling row runner; "before" run | Sonnet | green |
| 3 | Splash index (SI1-SI4 first) | Sonnet | green |
| 4 | After the index: profile and scaling rerun | Sonnet | green |
| 5 | Per-tick hash ring (HR1-HR3) | Sonnet | green |
| 6 | Ring in the desync report; `desync_diff.py`; netplay `perturb` | Sonnet | green |
| 7 | Oracle ring log; `tools/desync_bisect.py` | Sonnet | not started |
| 8 | Docs and package gate (ledger row) | Sonnet | not started |
| 9 | Fresh-context branch review, one fix round, `/ponytail-review` | Opus (high) | not started |

## Baseline (Task 0)

| Item | Value |
|---|---|
| Tree | `~/projects/wargrid-wt-simwins`, branch `sim-quick-wins`, `4ed3534` (main), clean before Task 0 edits |
| `uptime` at start / end | suite: load 1.24 1.38 1.49 at start (22:38), 2.37 1.70 1.60 at end (22:39). profile 2.26 / 1.36; benchmark 1.42 / 1.30 (alone, no other godot/generalszh processes) |
| Full suite: wall seconds, CASES, CHECKS, exit | 53 s, 850, 144212, 0 (TESTS PASSED 144212) |
| Trace files (`replay`, `economy`, `combat`, `team` `-before.tsv`), line counts | 1200 / 1200 / 1200 / 100 (in `$L`, outside the repository) |
| Anchor drift against the plan | Simulation files live in `game/scripts/simulation/`. `combat.gd`: `fire` :352, `fire_defences` :389, `_splash` :495, `splash_victims` :512 (plan 511 was the shortcut comment, now :511 still), `_build_grid` :295, `GRID_CELL` 8, `MAX_TARGET_RADIUS` 2.2: no drift. `simulation.gd`: `step` :503, `step.advance` end :561, `fire`/`fire_defences` :563-564, `remove_object` :772: no drift. `core_check` :16 (plan :16-27). `lockstep.gd` `desync_report` :176, `headless_client.gd` `_replay_oracle` :221, `_state_row` :248, `run_netplay.sh` `perturb)` :118, `combat_workload.gd` `_block` :46: no drift |
| Profile: contact `step.combat_fire` max (sample / warm-up) | 10.410 / 23.589 ms |
| Profile: hordes300 `step.combat_fire` max | 5.521 ms |
| Profile: team match `step` mean / max | 1.2975 / 10.579 ms (`step.advance` mean 0.4137; `step.combat_fire` max 2.476) |
| Benchmark (`PERF_RECORD=0`): contact, open, hordes300 `WORST TICK`; combat rows p95 / p99 | Plain `sh tools/run_benchmark.sh` (branch, does not record). WORST TICK: contact 11.342 ms (tick 420), open 2.971 (546), hordes300 7.573 (776). p95 / p99 ms: open 1.873 / 2.216, dense 1.808 / 2.118, contact 1.16 / 1.621, skirmish3v3 1.305 / 1.464, transports 1.074 / 1.169, defences 0.794 / 2.095, docks 0.561 / 0.58, hordes300 2.849 / 3.35, ramp 0.648 / 1.223, frc 0.831 / 1.155. Lines: `BUDGET EXCEEDED open hordes300 (regression ceilings held)` (accepted); also `COMBAT STRESS PASS` lines for open, dense, hordes300 above 1.82/3.64 with regression ceilings held |

## Pinned values (checked at Tasks 0, 1, 3, 5, 8)

| # | Pin | Expected (on `4bd8711`) | Task 0 (base tree) | Task 1 | Task 3 | Task 5 | Task 8 |
|---|---|---|---|---|---|---|---|
| V1 | `FINAL_DIGEST` | `3958ceaab11986af` | `3958ceaab11986af` (matches) | unchanged (suite green) | unchanged (suite green, Task 3 tree) | unchanged (suite green, Task 5 tree) | |
| V2 | `TEAM_CORE_SERIES` | `8513092129969516499` | `8513092129969516499` (matches) | unchanged (suite green) | unchanged (suite green, Task 3 tree) | unchanged (suite green, Task 5 tree) | |
| V3 | `S1_CORE_SERIES` | `4004499097874677431` | `4004499097874677431` (matches) | unchanged (suite green) | unchanged (suite green) | unchanged (suite green, Task 5 tree) | |
| V4 | `PINNED`, `EXPECTED_DIGEST`, `SS6_PINNED` | unchanged | `01e256834bdd4dfb`, `7c7fbc8d…48a9e7`, `SS6_PINNED` unchanged (suite green) | unchanged (suite green) | unchanged (suite green) | unchanged (suite green, Task 5 tree) | |
| V5 | four traces | byte-identical to `*-before.tsv` | four `-before.tsv` recorded (1200/1200/1200/100 lines) | `cmp` silent for all four against `*-before.tsv` (`*-t1.tsv`, same line counts) | `cmp` silent for all four against `*-before.tsv` with the index (`*-t3.tsv`, 1200/1200/1200/100) | `cmp` silent for all four against `*-before.tsv` with the ring (`*-t5.tsv`, 1200/1200/1200/100) | |
| V6 | netplay match terminal tick | `9129` | `9129` present in `run_netplay.sh:91` (not run) | — | — | — (Task 6: `match terminal tick 9129`, NETPLAY PASSED match 15.8 s) | |
| V7 | `run_team_match.sh` | `won tick=39497 winner=2 units_peak=271` | `won tick=39497 winner=2 units_peak=271` present in `run_team_match.sh:13` (not run) | — | — | `PROFILE_END team_match ticks=39497 status=won peak_entities=271` in the profile run (`units_peak` line is Task 8's) | |
| V8 | `git diff main -- game/tests \| rg '^-\s*const'` | empty | — | — | — | — | |

## Splash before/after (Tasks 1 and 4)

| Item | Task 1 (before) | Task 4 (after) |
|---|---|---|
| Tree, `uptime` start / end | `~/projects/wargrid-wt-simwins`, `sim-quick-wins`, Task 1 edits on `4227325`; load 2.01 (22:48) / 2.09 (22:50), profile run alone (a first run overlapped `run_checks.sh`, load 3.47, discarded) | `sim-quick-wins` on `0840a2e` (Task 3 commit), clean; load 2.29 (23:01) / 1.80 (23:03), alone (no other godot/generalszh process) |
| contact `combat.splash` mean / max (sample) | 0.0295 / 8.850 ms (0.38 calls per tick) | 0.0041 / 0.854 ms (0.38 calls per tick) |
| contact `combat.splash` max (warm-up) | 20.017 ms (mean 0.2750, 1.45 calls per tick) | 2.429 ms (mean 0.0342, 1.45 calls per tick) |
| contact `combat.splash_index` mean / max / calls per tick | — | sample 0.0011 / 0.151 ms / 0.03; warm-up 0.0035 / 0.227 ms / 0.02 (zone is inside `combat.splash`) |
| contact `step.combat_fire` max (sample / warm-up) | 10.495 / 23.601 ms | 2.711 / 5.947 ms |
| contact `step` max | 11.410 ms (sample), 27.187 ms (warm-up) | 3.638 ms (sample), 9.607 ms (warm-up) |
| team match `combat.splash` max; `step.combat_fire` max | 1.896 ms (mean 0.0408, 0.24 calls per tick); 2.510 ms | 0.450 ms (mean 0.0363, 0.24 calls per tick; `splash_index` mean 0.0340, max 0.280, 0.18 calls per tick); 2.242 ms (`step` mean 1.2909, max 10.744) |
| hordes300 `step.combat_fire` max (no splash weapon; expect unchanged) | 5.445 ms (no `combat.splash` zone fired) | 5.430 ms (unchanged; no `combat.splash` zone fired) |
| X1 proposal: contact `combat_fire` max below 2 ms | — | not met: 2.711 ms (sample), 5.947 ms (warm-up). Down from 10.495 / 23.601 ms; remaining max is not splash (splash max 0.854 ms) |

Review reference (probe zone, `4b444a2`): contact splash 8.804 of 10.324 ms (sample), 19.842 of 23.332 ms (warm-up); team match 1.425 of 2.186 ms.

## `step.advance` split (Task 1)

| Scenario | `step.advance` mean | `advance.move` | `advance.containers` | `advance.horde` | `advance.salvage` |
|---|---|---|---|---|---|
| skirmish3v3 | 0.1220 | 0.0593 | 0.0201 | 0.0178 | 0.0003 |
| team match | 0.4157 | 0.2585 | 0.0348 | 0.0661 | 0.0134 |
| hordes300 | 0.9538 | 0.4276 | 0.0608 | 0.3851 | 0.0003 |
| contact | 0.0586 | 0.0238 | 0.0098 | 0.0106 | 0.0003 |

Means in ms from `$L/t1-profile.log`. The four parts sum to 82-95 % of `step.advance`; the rest is the `before`/`moved` bookkeeping. Hordes300 `step.advance` is half of `step` (move 0.43, horde 0.39 ms).

## Scaling before/after (Tasks 2 and 4; report-only)

| Units (total) | step mean / p99 / max before | after | shots in window | `combat.splash` mean before / after |
|---|---|---|---|---|
| 50 | 0.1505 / 0.3440 / 0.477 | 0.1516 / 0.3540 / 0.484 | 1330 (114 splash calls) | 0.0016 / 0.0023 |
| 100 | 0.3861 / 0.7070 / 0.998 | 0.3872 / 0.6980 / 0.957 | 1702 (253) | 0.0066 / 0.0073 |
| 200 | 0.7579 / 1.3550 / 1.646 | 0.7653 / 1.3010 / 1.677 | 3473 (467) | 0.0248 / 0.0275 |
| 400 | 1.4613 / 2.9280 / 3.577 | 1.4581 / 2.6100 / 3.144 | 9624 (989) | 0.0918 / 0.0827 |
| 800 | 3.7858 / 6.6310 / 9.480 | 3.6055 / 5.7050 / 6.684 | 15709 (2547) | 0.5040 / 0.3123 |

| | Before | After |
|---|---|---|
| `SCALING_SUPERLINEAR` | `combat.retaliate,combat.nearest,step.combat_fire,combat.splash` | `combat.splash_index,combat.retaliate,combat.nearest,step.combat_fire,combat.splash` (`splash_index` is the new zone, inside `combat.splash`) |
| `combat.splash` growth ratios | 4.05, 3.74, 3.70, 5.49 (per doubling, 50 to 800 units; ideal 2.0) | 3.22, 3.78, 3.01, 3.78 (`combat.splash_index` 3.54, 3.92, 3.11, 3.80: the index build is 0.2666 of splash 0.3123 ms at 800 units, so splash is still superlinear; whole `step` 2.55, 1.98, 1.91, 2.47) |
| 800-unit size alone, seconds (long sweep check) | 8.2 s wall (whole sweep of five sizes: a few seconds more; far from the 15-minute rule) | — |

## Hash ring (Task 5)

| Item | Value |
|---|---|
| Probe: equal content, equal `hash()`; one-bit change differs; two processes same value | Yes: separately built equal `PackedInt64Array`s both 3080131851; one flipped float bit changes it (1722488638 against 2202494623); a second process printed the same values (`$L/t5-probe1.log`, `t5-probe2.log`; script `$L/t5-probe.gd`) |
| Probe: µs per `_tick_hash` call, team match at tick 6000 / hordes300 | 62.2 µs (205 entities) / 100.3 µs (tick 100), 1000 calls each |
| Hash path used (engine `hash()` or FNV fallback) | Engine `hash()` (probe passed, no fallback) |
| `step.hash_ring` mean and share of `step` mean: team match / hordes300 (proposal: under 3 %) | team match 0.0557 of 1.3490 ms = 4.1 %; hordes300 0.0828 of 2.0742 ms = 4.0 % (above the 3 % proposal: recorded, not a stop). Other rows: movement_open 10.8 %, movement_dense 10.7 %, combat_contact 4.2 %, skirmish3v3 4.0 %, combat_open 3.8 %, large_196 5.1 %, skirmish_match 6.6 %. A flat 0.02 to 0.09 ms per tick, so the share is high on cheap steps. Profile run alone, but load was 3.32 at the start (just after the suite and checks) and 1.97 at the end (`$L/t5-uptime-*.txt`); `$L/t5-profile.log` |
| Tests (`test_lockstep.gd`) | HR1: 9 mutations (unit x by 1e-9, unit hp, unit owner, building hp, building work, production head work, source boxes, player credits, rng), each first visible at row 51. HR2: shape. HR3: not in the snapshot. Red on the stub: `WARGRID_TEST_ONLY=test_hash_ring` CASES 3 CHECKS 23 FAILURES 11 (HR1 nine mutations plus two HR2 checks; HR3 passes on the stub as planned; `$L/t5-red.log`). Green: 3 / 23 / 0. HR3 scratch mutation (`"hash_ring":hash_ring()` in `_snapshot`): FAIL HR3 snapshot keys ["hash_ring"], reverted (`git diff --stat`: only the planned files). Production head work is exercised by enqueueing a `usa_builder` entry (paid_cost 0) at tick 50 in both worlds, because no queue is alive there otherwise |

## Desync report ring (Task 6)

| Item | Value |
|---|---|
| Red | `WARGRID_TEST_ONLY=test_desync_detected`: script error (`desync_report` takes 0 arguments), `FAIL L6 rings first differ at tick -1 (want 41)`; `test_desync_diff.py` ImportError on `ring_divergence` (`$L/t6-red.log`) |
| Green | `test_lockstep` 17 / 89 / 0, `test_skirmish` 74 / 335 / 0 (SK23 unchanged), `run_python_checks.sh` PYTHON TESTS PASSED |
| Netplay `perturb` | NETPLAY PASSED, output `ring diverges at tick 41` then `snapshot.players[1].credits: 9200 != 9201`; reports in `$L/t6-perturb/` |
| Netplay `match` | NETPLAY PASSED, `match terminal tick 9129` (V6 holds); `$L/t6-match/` |
| Full suite (traces `*-t6.tsv`) | 857 / 144247 / 0, TESTS PASSED, exit 0; four traces `cmp` silent against `*-before.tsv`; V8 empty; `run_checks.sh` CHECKS PASSED 5 |
| Report with no ring | `ring_divergence` returns `None`; `first_difference` and exit codes untouched (a ring-only difference with equal log and snapshot still prints `IDENTICAL`, exit 0) |

## Unverifiable at night (for the morning)

- CI on Linux and Windows (`godot-replays` traces with the index and the ring), `sh tools/compare_local_traces.sh <run id>` for macOS: need a pushed branch (push needs approval).
- Browser: the ring's engine `hash()` on wasm against native (reported only, never compared live, so no match can end on it); one browser-against-native session or the web bench is a morning item.
- Rendered benchmark: not needed (presentation unchanged); confirm `git diff main -- game/scripts/presentation game/scenes` is empty.
- The hordes300 fix goes to Flatter worst ticks (plan Question 6, user 2026-11-13); evidence in [hordes300 combat_fire](hordes300-combat-fire.md).
- Commands the night permissions refused, each with its exact text (filled in by the run). Tasks 1 and 2: none.

## Evidence rows (append-only)

- 2026-11-13 night, plan writing (backup 1 of the Tighter gates run), tree `~/projects/wargrid` `main` `4bd8711` clean, read-only (no suite, no benchmark, no profile, no Godot run). Read: `docs/packages.md` package note; simulation review §3.3, §5.1, §5.4, §6, "Review 2026-11-13"; `AGENTS.md`; `docs/milestone-prompt.md`; `docs/night-run.md` coordinator rules; `docs/reference/sim-interface.md`; `docs/reference/determinism-rules.md`. Code anchors checked on `4bd8711`: `combat.gd` `fire` `:352-385`, `fire_defences` `:389-421`, `_splash` `:495-502`, `splash_victims` `:511-521`, `_build_grid` `:295`, `GRID_CELL` 8, `MAX_TARGET_RADIUS` 2.2; `simulation.gd` `step` `:503-570` (advance zone `:548-561`, `fire` and `fire_defences` `:563-564`), `remove_object` `:772-792`; `containers.gd` `_release` `:174-190`; `rebuild_holes.gd` `_open` `:48-53`; `state_hash.gd` `core_check` `:16-27`; `lockstep.gd` `desync_report` `:176-177`; `headless_client.gd` desync write `:216`, `_replay_oracle` `:221-246`, `_state_row` `:248-258` (`JSON.stringify(state)` at `:257`, not full precision); `online_main.gd` `_report` `:108-111`; `run_netplay.sh` `perturb` `:118-132`; `combat_workload.gd` `create` `:8-44`, `_block` `:46-56`; `test_lockstep.gd` harness `:52-66`, L6 `:240-255`. Findings: (1) removals in `fire` can add splash victims before `fire_defences` (ejected passengers, opened rebuild holes), so the plan gives `fire_defences` its own index (Question 1); (2) largest victim radius today 2.12 (3 × 3 footprint), so the ±4.05 window holds, and the index takes the reach from the objects it holds; (3) `Lockstep.desync_report` callers: `headless_client.gd`, `online_main.gd`, `test_lockstep.gd`, `test_skirmish.gd` SK23 (no simulation; hence the optional parameter); (4) the hordes300 `combat_fire` worst-tick profiler pass was already done the same night (`~/projects/wargrid-overnight-work/tighter-gates/hordes300-combat-fire.md`). Not verified: whether `hash()` of packed arrays is content-based and stable across processes (Task 5 probe); the per-tick ring cost (estimate only); every SI2 / SI4 geometry (tuned in Task 3).
- 2026-11-13 night, Task 1 (profiler zones), tree `~/projects/wargrid-wt-simwins` `sim-quick-wins` on `4227325`, edits to `simulation.gd` `step` (four `advance.*` zones) and `combat.gd` `_splash` (`combat.splash` zone around `splash_victims`). Red: `rg -c 'zone=(advance\.|combat\.splash)'` on `t0-profile.log` printed nothing. Full suite (traces to `*-t1.tsv`): CASES 850 CHECKS 144212 FAILURES 0, TESTS PASSED, exit 0, 53 s; four traces `cmp` silent against `*-before.tsv`. `run_lint.sh` exit 0, `run_warnings.sh` WARNINGS CHECKED 161 FILES, `run_checks.sh` CHECKS PASSED 5. `run_profile.sh` PROFILE COMPLETE 10, exit 0: `advance.move/containers/horde/salvage` in all scenarios, `combat.splash` in the splash scenarios (11 zone rows). Splash zone is 8.850 of 10.495 ms (contact sample) and 20.017 of 23.601 ms (warm-up), the same order as the probe in review §3.3. No other godot/generalszh process was running; nothing left running.
- 2026-11-13 night, Task 2 (scaling row runner, "before"), tree `~/projects/wargrid-wt-simwins` `sim-quick-wins` on `eabf59c`, edits: `combat_workload.gd` (`create(layout, per_side = 150)`, `_block` takes `per_side`; 150 places today's units), `profiler.gd` (`zone_names()`; named so it does not shadow the local `zones` in `report`), new `game/benchmarks/run_scaling.gd` and `tools/run_scaling.sh`. 800 units alone: 8.2 s. Red: counting only shots with `tick < 0` made the runner exit 1 with `SCALING units=50: no shot inside the timed window (shots=0 splash_calls=114)`; reverted. Before run alone (`uptime` 1.71 at start, 1.70 at end, no other godot/generalszh process): exit 0, `SCALING COMPLETE 5`, `$L/t2-scaling.log`. Every size had shots and splash calls in the window. `assign_move.unavailable` did not appear (orders only at tick 0, inside the warm-up). Superlinear zones (last two doublings both above 2.2): `combat.retaliate`, `combat.nearest`, `step.combat_fire`, `combat.splash` (splash step mean 0.5040 ms at 800 units, 13 % of the step mean). Full suite with traces to `*-t2.tsv`: CASES 850 CHECKS 144212 FAILURES 0, TESTS PASSED, exit 0; four traces `cmp` silent against `*-before.tsv`. `run_checks.sh` CHECKS PASSED 5 (lint, warnings, Python, shell, public). `run_benchmark.sh` and `run_profile.sh` untouched.
- 2026-11-13 night, Task 3 (splash index), tree `~/projects/wargrid-wt-simwins` `sim-quick-wins` on `ca69ab6`, edits: `combat.gd` (`_splash_index`, `_centre_cell`, `SPLASH_SLACK`, `splash_victims` takes an optional index, `_splash` takes the box, `fire` and `fire_defences` each own a lazy box, `shortcut:` comment removed), `test_combat.gd` (SI1-SI3, `Profiler` preload), `test_defences.gd` (SI4). No `CASE_SECONDS` entry (SI1 under 1 s: whole `WARGRID_TEST_ONLY` run 1.1 s). Red on today's code (`combat.gd` unchanged): `test_combat` CASES 82 CHECKS 2639 FAILURES 1 (only SI3, 4 splash ticks and 0 builds; SI1 12000 queries 0 mismatches and SI2 pass against the full scan), `test_defences` FAILURES 0 (SI4 passes against the full scan). Green with the index: `test_combat` 82 / 2639 / 0, `test_defences` 19 / 109 / 0. Mutations (each reverted, `git diff --stat` afterwards shows only combat.gd, test_combat.gd, test_defences.gd): (a) `window = radius`: SI1 135 mismatches of 12000; (b) index built before `_apply_orders()` and used by `fire`: SI2 fails (no hit on the unloaded passenger; SI3 also red, 200 builds); (c) `fire_defences` reusing `fire`'s box: SI4 fails (no splash on the hole, the removed barracks named; other defence cases hit script errors on stale records); (d) eager build at the top of `fire`: SI3 fails (4 splash ticks, 200 builds). Full suite with traces to `*-t3.tsv`: CASES 854 CHECKS 144223 FAILURES 0, TESTS PASSED, exit 0; four traces `cmp` silent against `*-before.tsv` (1200/1200/1200/100); V1-V4 pass in the suite; `git diff main -- game/tests | rg '^-\s*const'` empty. `run_checks.sh` CHECKS PASSED 5 (lint, warnings, Python, shell, public). Logs `$L/t3-*`. Not verified: speed gain (Task 4).
- 2026-11-13 night, Task 4 (profile and scaling rerun after the index), tree `~/projects/wargrid-wt-simwins` `sim-quick-wins` on `0840a2e` (Task 3 commit), no repository file changed except this one. Run alone one after the other (no godot/generalszh process before either run); `uptime` 2.29 (23:01) before the profile, 1.80 after, 1.73 before the scaling run, 1.78 after. `sh tools/run_profile.sh`: exit 0, PROFILE COMPLETE 10 (`$L/t4-profile.log`). `sh tools/run_scaling.sh`: exit 0, SCALING COMPLETE 5 (`$L/t4-scaling.log`). Result: contact `combat.splash` max 8.850 to 0.854 ms (sample), 20.017 to 2.429 ms (warm-up); contact `step.combat_fire` max 10.495 to 2.711 ms (sample), 23.601 to 5.947 ms (warm-up); contact `step` max 11.410 to 3.638 ms; hordes300 `combat_fire` max 5.445 to 5.430 ms (unchanged, as expected); team match `combat.splash` max 1.896 to 0.450 ms. X1 (contact `combat_fire` max below 2 ms): not met (2.711 ms), report only. Scaling: 800-unit step mean 3.7858 to 3.6055 ms (max 9.480 to 6.684), 400 units 1.4613 to 1.4581; `combat.splash` mean at 800 units 0.5040 to 0.3123 ms, still superlinear (ratios 3.22, 3.78, 3.01, 3.78) because the index build (`combat.splash_index`, 0.2666 ms at 800 units) grows like 3.1 to 3.9 per doubling; the whole `step` is near linear (2.55, 1.98, 1.91, 2.47). Not verified: a second run for noise (single run each, report-only).
- 2026-11-13 night, Task 5 (per-tick hash ring), tree `~/projects/wargrid-wt-simwins` `sim-quick-wins` on `3a2d330`, edits: `simulation.gd` (`StateHash` preload, `HASH_RING_SIZE`, `_hash_ring`, `step.hash_ring` zone, `_tick_hash`, `hash_ring()`), `test_lockstep.gd` (HR1-HR3), `sim-interface.md` (one line). Probe first: engine `hash()` is content-based and stable across two processes, so no FNV fallback. Red on the stub, green, HR3 mutation as in the Hash ring table. Full suite with traces to `*-t5.tsv`: CASES 857 CHECKS 144246 FAILURES 0, TESTS PASSED, exit 0, 55 s; four traces `cmp` silent against `*-before.tsv`; V1-V4 pass in the suite; V8 empty. `run_checks.sh` CHECKS PASSED 5. `run_profile.sh` PROFILE COMPLETE 10, exit 0. No command refused. Not verified: the ring's wasm and cross-platform values (reported only, morning item); benchmark budgets with the ring (Task 8 gate; team match and hordes300 pay about 0.06 and 0.08 ms per tick).
- 2026-11-13 night, Task 6 (ring in the desync report), tree `~/projects/wargrid-wt-simwins` `sim-quick-wins` on `00778f3`, edits: `lockstep.gd` (`desync_report(sim = null)` adds `hash_ring`), `headless_client.gd` and `online_main.gd` (pass the simulation), `desync_diff.py` (`ring_divergence`, printed before the field path), `test_desync_diff.py`, `run_netplay.sh` perturb (requires `ring diverges at tick 41` and a non-empty ring per seat), `test_lockstep.gd` (L6 ring check). Results in the Desync report ring table. No command refused; no godot/generalszh process left running (pgrep empty after the netplay runs). Not verified: the `perturb` ring tick on another platform.

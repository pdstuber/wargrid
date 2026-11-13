# Sim quick wins verification

```text
Resume record (updated 2026-11-13 night: Task 0 green)
Branch / base commit / working-tree state: sim-quick-wins / 4ed3534 (main) / only this verification file modified
Last green task / next incomplete task: Task 0 / Task 1
Changed paths since last commit: docs/reference/sim-quick-wins-verification.md
Last command / cases / checks / failures / exit / marker: sh tools/run_benchmark.sh / n/a / n/a / 0 / exit 0, BENCHMARK PASSED 2, COMBAT BENCHMARK PASSED 10, LOCKSTEP BENCHMARK PASSED 1 (suite before: CASES 850 CHECKS 144212 FAILURES 0, TESTS PASSED, exit 0)
Known red case or blocker: none; plan approved 2026-11-13 (user, all seven questions answered, see the plan)
Approved decisions, pre-authorizations used, deferred gates: package note "Sim quick wins" (user, 2026-11-13); local commits per GREEN task only if the night run handoff grants them
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: Task 1 (profiler zones), in the worktree ~/projects/wargrid-wt-simwins
```

Plan: [Sim quick wins plan](../superpowers/plans/2026-11-13-sim-quick-wins.md). Spec: `docs/packages.md` package note "Sim quick wins"; `docs/reference/simulation-reference-review.md` §5.1, §5.4 (a), §6, "Review 2026-11-13". Logs: `~/projects/wargrid-overnight-work/sim-quick-wins/logs/` (outside the repository).

## Tasks

| Task | What | Model | Status |
|---|---|---|---|
| 0 | Baseline: worktree, import, suite and traces, pins, profile and benchmark before | Sonnet | green |
| 1 | Profiler zones: `step.advance` split, `combat.splash` | Sonnet | not started |
| 2 | Scaling row runner; "before" run | Sonnet | not started |
| 3 | Splash index (SI1-SI4 first) | Sonnet | not started |
| 4 | After the index: profile and scaling rerun | Sonnet | not started |
| 5 | Per-tick hash ring (HR1-HR3) | Sonnet | not started |
| 6 | Ring in the desync report; `desync_diff.py`; netplay `perturb` | Sonnet | not started |
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
| V1 | `FINAL_DIGEST` | `3958ceaab11986af` | `3958ceaab11986af` (matches) | | | | |
| V2 | `TEAM_CORE_SERIES` | `8513092129969516499` | `8513092129969516499` (matches) | | | | |
| V3 | `S1_CORE_SERIES` | `4004499097874677431` | `4004499097874677431` (matches) | | | | |
| V4 | `PINNED`, `EXPECTED_DIGEST`, `SS6_PINNED` | unchanged | `01e256834bdd4dfb`, `7c7fbc8d…48a9e7`, `SS6_PINNED` unchanged (suite green) | | | | |
| V5 | four traces | byte-identical to `*-before.tsv` | four `-before.tsv` recorded (1200/1200/1200/100 lines) | | | | |
| V6 | netplay match terminal tick | `9129` | `9129` present in `run_netplay.sh:91` (not run) | — | — | — | |
| V7 | `run_team_match.sh` | `won tick=39497 winner=2 units_peak=271` | `won tick=39497 winner=2 units_peak=271` present in `run_team_match.sh:13` (not run) | — | — | — | |
| V8 | `git diff main -- game/tests \| rg '^-\s*const'` | empty | — | — | — | — | |

## Splash before/after (Tasks 1 and 4)

| Item | Task 1 (before) | Task 4 (after) |
|---|---|---|
| Tree, `uptime` start / end | | |
| contact `combat.splash` mean / max (sample) | | |
| contact `combat.splash` max (warm-up) | | |
| contact `combat.splash_index` mean / max / calls per tick | — | |
| contact `step.combat_fire` max (sample / warm-up) | | |
| contact `step` max | | |
| team match `combat.splash` max; `step.combat_fire` max | | |
| hordes300 `step.combat_fire` max (no splash weapon; expect unchanged) | | |
| X1 proposal: contact `combat_fire` max below 2 ms | — | met / not met |

Review reference (probe zone, `4b444a2`): contact splash 8.804 of 10.324 ms (sample), 19.842 of 23.332 ms (warm-up); team match 1.425 of 2.186 ms.

## `step.advance` split (Task 1)

| Scenario | `step.advance` mean | `advance.move` | `advance.containers` | `advance.horde` | `advance.salvage` |
|---|---|---|---|---|---|
| skirmish3v3 | | | | | |
| team match | | | | | |
| hordes300 | | | | | |
| contact | | | | | |

## Scaling before/after (Tasks 2 and 4; report-only)

| Units (total) | step mean / p99 / max before | after | shots in window | `combat.splash` mean before / after |
|---|---|---|---|---|
| 50 | | | | |
| 100 | | | | |
| 200 | | | | |
| 400 | | | | |
| 800 | | | | |

| | Before | After |
|---|---|---|
| `SCALING_SUPERLINEAR` | | |
| `combat.splash` growth ratios | | |
| 800-unit size alone, seconds (long sweep check) | | — |

## Hash ring (Task 5)

| Item | Value |
|---|---|
| Probe: equal content, equal `hash()`; one-bit change differs; two processes same value | |
| Probe: µs per `_tick_hash` call, team match at tick 6000 / hordes300 | |
| Hash path used (engine `hash()` or FNV fallback) | |
| `step.hash_ring` mean and share of `step` mean: team match / hordes300 (proposal: under 3 %) | |

## Unverifiable at night (for the morning)

- CI on Linux and Windows (`godot-replays` traces with the index and the ring), `sh tools/compare_local_traces.sh <run id>` for macOS: need a pushed branch (push needs approval).
- Browser: the ring's engine `hash()` on wasm against native (reported only, never compared live, so no match can end on it); one browser-against-native session or the web bench is a morning item.
- Rendered benchmark: not needed (presentation unchanged); confirm `git diff main -- game/scripts/presentation game/scenes` is empty.
- The hordes300 fix goes to Flatter worst ticks (plan Question 6, user 2026-11-13); evidence in [hordes300 combat_fire](hordes300-combat-fire.md).
- Commands the night permissions refused, each with its exact text (filled in by the run).

## Evidence rows (append-only)

- 2026-11-13 night, plan writing (backup 1 of the Tighter gates run), tree `~/projects/wargrid` `main` `4bd8711` clean, read-only (no suite, no benchmark, no profile, no Godot run). Read: `docs/packages.md` package note; simulation review §3.3, §5.1, §5.4, §6, "Review 2026-11-13"; `AGENTS.md`; `docs/milestone-prompt.md`; `docs/night-run.md` coordinator rules; `docs/reference/sim-interface.md`; `docs/reference/determinism-rules.md`. Code anchors checked on `4bd8711`: `combat.gd` `fire` `:352-385`, `fire_defences` `:389-421`, `_splash` `:495-502`, `splash_victims` `:511-521`, `_build_grid` `:295`, `GRID_CELL` 8, `MAX_TARGET_RADIUS` 2.2; `simulation.gd` `step` `:503-570` (advance zone `:548-561`, `fire` and `fire_defences` `:563-564`), `remove_object` `:772-792`; `containers.gd` `_release` `:174-190`; `rebuild_holes.gd` `_open` `:48-53`; `state_hash.gd` `core_check` `:16-27`; `lockstep.gd` `desync_report` `:176-177`; `headless_client.gd` desync write `:216`, `_replay_oracle` `:221-246`, `_state_row` `:248-258` (`JSON.stringify(state)` at `:257`, not full precision); `online_main.gd` `_report` `:108-111`; `run_netplay.sh` `perturb` `:118-132`; `combat_workload.gd` `create` `:8-44`, `_block` `:46-56`; `test_lockstep.gd` harness `:52-66`, L6 `:240-255`. Findings: (1) removals in `fire` can add splash victims before `fire_defences` (ejected passengers, opened rebuild holes), so the plan gives `fire_defences` its own index (Question 1); (2) largest victim radius today 2.12 (3 × 3 footprint), so the ±4.05 window holds, and the index takes the reach from the objects it holds; (3) `Lockstep.desync_report` callers: `headless_client.gd`, `online_main.gd`, `test_lockstep.gd`, `test_skirmish.gd` SK23 (no simulation; hence the optional parameter); (4) the hordes300 `combat_fire` worst-tick profiler pass was already done the same night (`~/projects/wargrid-overnight-work/tighter-gates/hordes300-combat-fire.md`). Not verified: whether `hash()` of packed arrays is content-based and stable across processes (Task 5 probe); the per-tick ring cost (estimate only); every SI2 / SI4 geometry (tuned in Task 3).

# Sim quick wins verification

```text
Resume record (updated 2026-11-13 evening: plan approved and moved into the repository; not started)
Branch / base commit / working-tree state: sim-quick-wins (not created) / main at run time (plan written against 4bd8711) / n/a
Last green task / next incomplete task: none / Task 0
Changed paths since last commit: none
Last command / cases / checks / failures / exit / marker: none
Known red case or blocker: none; plan approved 2026-11-13 (user, all seven questions answered, see the plan)
Approved decisions, pre-authorizations used, deferred gates: package note "Sim quick wins" (user, 2026-11-13); local commits per GREEN task only if the night run handoff grants them
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: Task 0, when the user starts the night package
```

Plan: [Sim quick wins plan](../superpowers/plans/2026-11-13-sim-quick-wins.md). Spec: `docs/packages.md` package note "Sim quick wins"; `docs/reference/simulation-reference-review.md` §5.1, §5.4 (a), §6, "Review 2026-11-13". Logs: `~/projects/wargrid-overnight-work/sim-quick-wins/logs/` (outside the repository).

## Tasks

| Task | What | Model | Status |
|---|---|---|---|
| 0 | Baseline: worktree, import, suite and traces, pins, profile and benchmark before | Sonnet | not started |
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
| Tree | |
| `uptime` at start / end | |
| Full suite: wall seconds, CASES, CHECKS, exit | |
| Trace files (`replay`, `economy`, `combat`, `team` `-before.tsv`), line counts | |
| Anchor drift against the plan | |
| Profile: contact `step.combat_fire` max (sample / warm-up) | |
| Profile: hordes300 `step.combat_fire` max | |
| Profile: team match `step` mean / max | |
| Benchmark (`PERF_RECORD=0`): contact, open, hordes300 `WORST TICK`; combat rows p95 / p99 | |

## Pinned values (checked at Tasks 0, 1, 3, 5, 8)

| # | Pin | Expected (on `4bd8711`) | Task 0 (base tree) | Task 1 | Task 3 | Task 5 | Task 8 |
|---|---|---|---|---|---|---|---|
| V1 | `FINAL_DIGEST` | `3958ceaab11986af` | | | | | |
| V2 | `TEAM_CORE_SERIES` | `8513092129969516499` | | | | | |
| V3 | `S1_CORE_SERIES` | `4004499097874677431` | | | | | |
| V4 | `PINNED`, `EXPECTED_DIGEST`, `SS6_PINNED` | unchanged | | | | | |
| V5 | four traces | byte-identical to `*-before.tsv` | | | | | |
| V6 | netplay match terminal tick | `9129` | | — | — | — | |
| V7 | `run_team_match.sh` | `won tick=39497 winner=2 units_peak=271` | | — | — | — | |
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

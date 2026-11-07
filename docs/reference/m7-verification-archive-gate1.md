# M7 verification archive: Gate 1 (base rows, performance time box, results, review fixes, CI)

Moved verbatim from [m7-verification.md](m7-verification.md).

## Base rows (tree: m7-factions, M7 Task 0 working tree, Apple M6, idle-ish)

- Suite: 278 cases / 112,742 checks / 0 failures, twice.
- `run_benchmark.sh` exit 1: `open` HEADLESS p95 1.96 / p99 2.244 (pass), `dense` HEADLESS p95 1.953 / p99 2.227 (pass); combat stress `open` p95 2.897 / p99 4.027 against budget 1.82 / 3.64 and ceiling 2.05 / 3.86: exceeded, run stops there so `dense` is not reported.
- `run_team_match.sh` exit 0: `TEAM TIMING` n 20425, p50 1.433, p95 3.196, p99 6.958, max 16.423 (budget 1.82 / 3.64: exceeded).
- bench runner combat: open p95 3.466 / p99 4.75; dense p95 3.838 / p99 5.668; contact 1.318 / 2.173; skirmish3v3 1.633 / 2.077 (single run, runner is noisier than `run_combat.gd`).

## Task 1 (performance time box)

- `run_combat.gd` now prints every layout and fails once at the end (`open` and `dense` both print).
- Profile (`run_profile.sh`, combat_open p95 ms): `step` 2.784, `step.combat_plan` 2.027, `combat.nearest` 1.288 (17.65 calls/tick), `step.advance` 0.652, `step.combat_fire` 0.375. `skirmish_match` p95: `step.combat_plan` 0.267, `combat.nearest` 0.106, `step.advance` 0.104; `step.ids`, rates and `combat.build_grid` are each under 0.035 ms mean.
- None of the plan's three candidates (`step.ids`, `step.rates`, `combat.build_grid`) targets the top zone (`combat_plan` / `combat.nearest`). The plan says: no candidate for the top zone means stop. Ruling: zero fixes kept, no trace risk taken.
- Stress rows at this tree: `open` p95 2.773 / p99 3.813, `dense` p95 3.113 / p99 4.774 (budget 1.82 / 3.64, ceilings open 2.05 / 3.86, dense 2.52 / 4.02): exceeded. `contact` 1.152 / 1.623 and `skirmish3v3` 1.379 / 1.635 inside budget. Team match `TEAM TIMING` p95 3.196 exceeded (Task 0 row).
- Gate-1 proposal: `combat.nearest` is the real cost; a speedup there is a candidate for a later user-approved time box, not trace-preserving by default. Stress ceilings stay.

## Task 11 (gate 1) results (tree: m7-factions 7293c91 + uncommitted parity tooling/docs, Apple M6)

- Suite 318 / 112,988 / 0, exit 0. Lint, warnings pass. `python3 -m unittest discover -s tools`: 39 OK. `run_conformance.sh`: CONFORMANCE PASSED 33.
- Trace check: replay, economy, combat and team traces at 7293c91 are `cmp`-identical to a clean worktree at 2a71a6d (Task 9); suites 318/112,995 vs 312/112,983, both 0 failures (counts differ with traces on). Traces vs pre-M7 base are not comparable (kind-string rename, armed scout car, command center).
- Netplay: match (terminal tick 8257), kill, stall, silent, spike, perturb, version: all PASSED.
- `run_team_match.sh` exit 0: won tick=23816 winner=2; TEAM TIMING n 23816, p50 1.2, p95 2.412, p99 6.169, max 12.932 (budget 1.82 / 3.64: exceeded; base 3.196 / 6.958).
- `run_benchmark.sh` exit 1 (stops at combat stress, as at base; lockstep run alone afterwards, exit 0). Machine: no World of Warcraft process; Battle.net launcher and Codex renderer were running (about 20 % CPU), a stale headless Godot (pid 38232, idle) from a scratch script was present.
  - movement open p95/p99 1.691 / 1.889, dense 1.738 / 2.06 (PASS).
  - combat stress open 2.798 / 3.716 and dense 3.152 / 4.75: exceed the 1.82 / 3.64 budget and the ceilings (open 2.05 / 3.86, dense 2.52 / 4.02); base open 2.897 / 4.027. Not loosened.
  - contact 1.191 / 1.665 PASS, skirmish3v3 1.406 / 1.588 PASS.
  - transports (new, report-only): p95 1.504 / p99 1.802, 180 passenger shots in window, within budget; defences (new, report-only): p95 2.87 / p99 3.251, 590 defence shots, p95 over 1.82. `Containers.step` has no separate counter (cost is inside these totals; `run_profile.sh` not run).
  - lockstep overhead p99 0.071 ms (limit 0.6) PASS.
- Rendered benchmark: run later, see "Rendered China layout".

### Provisional pins against window and cause

S1 `TERMINAL_TICK` 7731 inside floor 7000..17999, TICK_LIMIT 18000, winner 1 (armed scout car, Task 8). Team match won tick 23816, winner 2, inside cap 45000 (result won). Netplay `match` 8257 inside the S1 window. `PINNED`, `FINAL_DIGEST`, `TEAM_CORE_SERIES`, `S1_CORE_SERIES`: each row above names its causing task; no pin moved in Tasks 9 and 10 (traces identical to Task 9). All confirmed.

### Parity (measured, source build, fork branch wargrid-parity; traces `~/CnC/parity/traces` untouched, new run in scratch)

New scenarios added in `tools/zh_parity/{parity,analyze}.py` (self-test OK): `move_/turn_/range_/reach_` for `rocket` (AmericaInfantryMissileDefender) and `scout` (AmericaVehicleHumvee), `range_/reach_battery` (AmericaPatriotBattery). Reruns of Ranger, Crusader, Dozer equal the stored rows exactly (reach 122 / 183, ranges 115.45 / 181.52, Dozer turn 102 frames).

| scenario | metric | measured | Wargrid | verdict |
|---|---|---|---|---|
| move_rocket | top speed | 20.0 | 20 | PASS |
| move_scout | top speed (peak) | 60.09 (66.7) | 75 | FAIL: Wargrid 3.0 cells/s, ZH 2.4 |
| turn_rocket | turn rate | 500 deg/s, 11 frame start delay | 500 | feel |
| turn_scout | turn rate | 180 deg/s, 37 frames; 20-27 u/s while turning, then 60 | 180, min_turn_speed 0.8 cells/s (20) | feel, matches |
| range_rocket / reach_rocket | first shot / farthest fire | 186.6 / 197 | 175 | +22 |
| range_scout / reach_scout | first shot / farthest fire | 178.8 / 183 | 150 | +33 |
| range_battery / reach_battery | - | 0 shots (also with a spawned power plant) | 225 | not measurable |

The +22 (infantry attacker) and +33 (vehicle attacker) offsets equal the Ranger (122 vs 100) and Crusader (183 vs 150) offsets against the same Dozer target: target and attacker geometry, not a range error. INI `AttackRange` 175 / 150 / 225 (HumveeGun, MissileDefenderMissileWeapon, PatriotMissileWeapon) equals Wargrid. Dozer mid-turn slowdown: `turn_dozer` speed falls to 1.1 u/s at frame 76 (frames 70-80: 6.0 to 4.5), a reverse/3-point-turn dip well under `min_turn_speed.builder` 25 u/s; the Humvee trace has no dip at frames 70-80 (steady 60.1 u/s until braking).

Decision list (no value changed; user decides):
1. Scout car speed 3.0 cells/s vs ZH cruise 2.4 (60 u/s): lower to 2.4 or keep? Needs a values-table cause check (INI speed unchecked here).
2. Battery cadence 8,8,8,60 stays formula-only: Patriot never fires in the harness (unpowered or anti-air only, unverified). Options: leave, or investigate the API (power/targeting) in a separate harness task.
3. Dozer mid-turn dip to about 1 u/s vs Wargrid min turn speed 25 u/s: feel difference, candidate for the playtest.
4. Rocket/scout/battery ranges: no change (geometry offsets as for Ranger/Crusader).

### Patriot probe

Measured (source build), 2026-11-06, `tools/zh_parity/probe_patriot.py` and `parity.py` (`power_for` spawns an `AmericaPowerPlant` beside a battery in `fire`/`reach`).

- Cause of "never fires": no power. `AmericaPatriotBattery` has KindOf `POWERED`, `EnergyProduction -3`; a lone spawn gives `/resources` production 0 / consumption 3 and 0 shots in 200 frames (`a0`). With one spawned plant (production 5 / consumption 3, no construction step needed) it fires at once. Attempts 1 and 2 yielded shots, 3-6 not needed.
- Auto-acquire (no order) and `attack_target` both work against an enemy Dozer at gap 150: 12 shots in 400 frames, first at order+3.
- Burst `burst_battery` (GLA Command Center, gap 200, plant present): lastShotFrame 11, 19, 27, 35, 95, 103, 111, 119, 179 ...: intervals 8, 8, 8, 60, repeating, clip 4. Equals Wargrid `battery` (`delay_ticks 8`, `clip_size 4`, `reload_ticks 60`); `analyze.py` prints `8,8,8` only because it ends the pattern at the first reload gap, so its `8,8,8,60` expectation reads FAIL; metric wording, not a cadence difference.
- Reach `reach_battery`: farthest idle firing gap 252 (fires at 252, not at 253) vs INI/Wargrid range 225 (9 cells). Offset +27 centre to centre, same kind as Ranger +22 and Crusader +33 (target and attacker footprint); analyze FAIL at tolerance 10 is the geometry offset, no value change.
- `range_battery` still 0 shots: the battery is IMMOBILE, the 300 gap is out of range and an attack order cannot make it approach. Not a power issue; scenario is ill-posed for a building (use `reach_battery`).
- Not tried: assist weapon with two Patriots (`a5_two` exists, not run), air target; unneeded.


## Gate 1 review fixes (tree: m7-factions f6ceb9b + uncommitted, Apple M6)

- Fixed test-first (each test seen red first, mutation noted): finding 1 bot filters contained units in `_attack`/`_defend` (D3, red by reverting skirmish.gd); finding 3 passengers sorted by id on boarding (CT10, red by `append`); finding 4 `_free_slots` ignores the command's own live ids (CT11, red before the fix); finding 7 `_can_join` parenthesised (not reachable by a unit test: a passenger's intent is always guard, behaviour unchanged; precedence only).
- Finding 2, user ruling 2026-11-06 FIX NOW: building attackers trigger retaliation (`fire_defences` calls `_retaliate_trigger` before deaths; the trigger measures from the building centre). DF6 red first (reverting combat.gd), human infantry at 6.0 and 7.9 cells retaliate, at 8.5 stay in guard. No pin moved from this.
- Test gaps: DF7 keep-current-target, DF8 splash, DF9 ignores air and contained, DF10 deaths after all shots (all four seen red by scratch mutations of combat.gd: skip validity check, drop the splash line, drop the air/contained filter in `valid_target`, remove the dead target inside the loop); F5 asserts FactionRow width <= 520 (red with a 1400 px minimum size).
- Scout speed: `check_reference.py` against the retail INIZH.big: Humvee locomotor 2.4 cells/s (60 u/s), matches the parity row; set to 2.4. S1 7685 (not past 8000; floor stays 7000), team match won tick 30687 winner 1, netplay match 7817.
- Suite 326 / 134,257 / 0, exit 0, TESTS PASSED 134257 (check count rose from 113,0xx: not investigated beyond the slower scout car lengthening per-tick scripted matches). Lint, warnings, unittest 39 pass. run_netplay match, run_team_match pass. No benchmarks run.
- Finding 8 CLOSED (user ruling 2026-11-06: throttle like Zero Hour and OpenRA). Retail Patriot `AmericaPatriotBattery` (INIZH.big `data\ini\object\factionbuilding.ini`, TurretAI): MinIdleScanInterval = MaxIdleScanInterval = 250 ms = 8 ticks at 30/s (ceil, as `ms_to_ticks`). `Combat.DEFENCE_SCAN_TICKS` = 8, fixed, so no RNG draw (min equals max). A defence without a valid target scans only when `combat.scan_tick` is due; the key exists only after the first scan (inside the gate-1 building `combat` record, no new snapshot field outside the list). `fire_defences` returns early when no completed armed building exists and sorts only armed ids. Tests DF11 (scan count <= 11 in 80 ticks, mid-interval target shot at next scan, tick 8; both red before), DF12 (acquired target kept, no rescan; guard), DF13 (identical runs, identical shot ticks). DF1-DF10 unchanged and green. No pin moved (the bot never builds defences): suite 329 / 134,261 / 0, exit 0, TESTS PASSED 134261; lint, warnings, ruff, mypy (two stale annotation errors in tools fixed), unittest 39, netplay match 7817, team match won tick 30687 winner 1 pass. No benchmarks run; the `defences` layout needs the coordinator's rerun.
- Open for gate 2 (plan outline carries them): finding 5 `setup_seat` placement unchecked online; finding 6 `build_order()` / `unit_for()` read `DEFAULT_FACTION` instead of the seat faction.
- Plan/design: "Snapshot fields added at gate 1" now states the as-built keys (present only while set).

## CI evidence at gate 1 (2026-11-06)

- Run 42292961869 on 3a31be0: Linux and Windows Godot jobs failed on `BM5 transports: 20 full cars against 100 riflemen` in the exported suite only. Cause: `combat_workload.gd` `_transports()` spawned the 100 enemy riflemen inside `assert(...)`, which exported release builds strip. Fixed in f44f081 (spawn bound to a variable first); the local headless run never failed because asserts are active there. No other call inside an `assert` in game scripts, benchmarks or tests (searched).
- Run 42295509369 on f44f081: all jobs green, including compare-replays. `sh tools/compare_local_traces.sh 42295509369` on macOS: REPLAYS MATCHED for replay, economy, combat (1200 each), team (100) and netplay (278).

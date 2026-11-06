# M7 verification

Plan: [M7 plan](../superpowers/plans/2026-11-06-m7-factions.md). Design: [M7 design](../superpowers/specs/2026-11-06-m7-factions-design.md). Evidence: [M7 factions](m7-factions.md).

## Resume record

```text
Resume record (updated 2026-11-06, Task 4 done)
Branch / base commit / working-tree state: m7-factions at 6a7a6c9 plus the Task 4 commit "Read capabilities instead of kind ids"; tree clean after it
Last green task / next incomplete task: Task 4 (capability reads) / Task 5 (Command Center, seat faction, Zero Hour survival, bot builder); each task runs in a fresh subagent (milestone prompt "Unattended run", 2026-11-06), which covers the plan's checkpoint restarts
Changed paths since last commit: none after the Task 4 commit
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh, 283 cases / 112,759 checks / 5 failures (F1, F2, F4 and one incomplete case, all test_factions.gd, owners Tasks 5-6), exit 1; the four replay traces equal the Task 3 run byte for byte; python3 -m unittest discover -s tools: OK (guard without allow-list); run_lint.sh and run_warnings.sh pass; run_netplay.sh match terminal tick 8242
Known red case or blocker: test_factions.gd F1-F4 until Tasks 5-6
Approved decisions, pre-authorizations used, deferred gates: local commit per green task (milestone prompt); D1 definition-dict pins kept via legacy projections (user, 2026-11-06, answer "Legacy projection")
Usage so far: not recorded
Next exact action: Task 5. Before the change run the four traced suites into a fresh dir; Task 5 re-pins provisionally what it moves.
```

## Pins at base

`TERMINAL_TICK` 8286, `TICK_LIMIT` 10800, `S1_CORE_SERIES` 3600881543542644697 (`test_skirmish_match.gd`); `PINNED` 6374674a4bdd4dfb (`test_state_hash.gd`); `FINAL_DIGEST` 234f0b14453bc6c6 and new `TEAM_CORE_SERIES` 1490497313643459296 (`test_team_match.gd`); `TEAM_TICK_CAP` 27000; netplay `match` 8242; BM6 18500 / 16000; stress ceilings `run_combat.gd:10`.

## Pin changes

| test | assertion | old → new | cause |
|---|---|---|---|
| test_map | MP5 presets count | 9 → 10 | Web preset added in `b60edca`; base `main` was red on this one check before M7 (Task 0) |
| test_team_match | TB4 `TEAM_CORE_SERIES` | new, 1490497313643459296 | Task 0 |
| test_state_hash | H1 `PINNED` | 6374674a4bdd4dfb → 4b52b4564bdd4dfb | Task 3 rename |
| test_team_match | TB3 `FINAL_DIGEST` | 234f0b14453bc6c6 → 6a389cd2453bc6c6 | Task 3 rename |
| test_base_scene, test_skirmish_scene | Bs5 queue label, E1 enemy line | `tank` → `usa_tank` in the text | Task 3 rename (labels show the kind id until Task 7 display names) |

## Departures and deferrals

- Base suite was 277 cases / 112,748 checks / 1 failure (MP5 count, above), not the plan's 277 / 112,744 / 0.

- Task 3: `MapData.slot` and its start validation read `slots[kind.trim_prefix("usa_")]` because map slot keys are roles (`power_plant`, `supply_center`, `barracks`, `factory`) while kinds are `usa_*`. The plan left this bridge open; Task 4's `slot` field replaces it. Traces differ from the pre-rename run only because the state hash covers kind strings; core series, terminal tick (S1, team), BM6 and netplay 8242 are unchanged.

- Task 4: `Economy.unit()` / `Economy.building()` / `Combat.profile()` return cached legacy-shaped views built from the merged rows in `definitions/usa.gd` (`Registry.unit_view` etc.), so the D1 dict pins and `is_same` identity stay unchanged (user decision, 2026-11-06). The views can go when the pins are rewritten on purpose.
- Task 4: `usa_power_plant.counts_for_victory` is false to keep today's survival rule (a power plant never counted); Task 5 flips it to Zero Hour's rule. `Simulation.spawn` defaults an empty kind to `Registry.DEFAULT_SPAWN` (52 callers rely on the old default); `Skirmish.BUILD_ORDER` / `UNIT_FOR` became `build_order()` / `unit_for()`; `faction.start_building` is empty until Task 5. Hotkey build menus in `base_main.gd` / `skirmish_main.gd` keep their kind literals until Task 7 (outside the guarded directories).
- Test sharding (workflow change before Task 5, user 2026-11-06, not M7 scope): `run_tests.sh` runs the cases in up to 4 parallel `--shard=i/n` processes (`WARGRID_TEST_SHARDS`, `1` = one process); new `test_runner.gd` adds 3 cases / 5 checks (286 cases). `test_team_match.gd` was 100 s of 135 s (prefix case 55 s, core series 44 s), so cases are sharded, not suites. Same tree: one process 124 s, 4 shards 66 s, 8 shards 68 s; totals, sorted FAIL lines and all four traces identical. Check counts differ with traces on (112,764) and off (112,757) because trace writes are checked; that is the source of earlier 112,752 vs 112,759 drift.
- Task 4 performance risk: air checks in `_build_grid` and friends are now `Registry.air_kinds.has(kind)` instead of a string compare; no benchmark run yet (WoW-skew question open, benchmarks wait for the user to quit it).

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

## Values table

Cadence, measured (source build, `~/CnC/parity/traces`, 2026-11-06):

| scenario | metric | formula | measured | Wargrid uses |
|---|---|---|---|---|
| `rof_rocket` | shot interval | 30 | 30 | 30 |
| `rof_scout` | shot interval | 6 | 6 | 6 |
| `burst_battery` | burst pattern | 8,8,8,60 | 0 shots in 600 frames | formula 8 / clip 4 / reload 60 (battery could not be measured; spawned without a power plant, so likely dark from the POWERED flag, not verified) |

Gate-1 rows (cost, ticks, max_hp, armor, vision, radius, weapon, other) are the plan's Task 2 table, unchanged: no measured gap, so formula delays stand. Armor percentages and footprints as in the plan's Task 2 tables.

# M7 verification

Plan: [M7 plan](../superpowers/plans/2026-11-06-m7-factions.md). Design: [M7 design](../superpowers/specs/2026-11-06-m7-factions-design.md). Evidence: [M7 factions](m7-factions.md).

## Resume record

```text
Resume record (updated 2026-11-06, gate 1 review fixes done, uncommitted)
Branch / base commit / working-tree state: m7-factions at 7293c91 (Task 10 committed); Task 11 changes uncommitted
Last green task / next incomplete task: gate 1 review fixes green (see 'Gate 1 review fixes' below) / user playtest, rendered benchmark
Changed paths since last commit: tools/zh_parity/{parity,analyze}.py, docs/reference/{m7-verification,performance}.md
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh, 326 cases / 134,257 / 0, exit 0, TESTS PASSED 134257 (after review fixes); lint, warnings, unittest (39), conformance (33), netplay x7, team match pass; run_benchmark.sh exit 1 (combat stress open/dense exceeded their ceilings, as at base)
Known red case or blocker: none (benchmark ceilings exceeded: reported, not loosened)
Approved decisions, pre-authorizations used, deferred gates: user ruling 2026-11-06: the bot does not build usa_defence; stress ceiling re-pin and rendered benchmark need the user
Usage so far: not recorded
Next exact action: gate review (Opus high, fresh context), then user playtest (offline and online) and the rendered benchmark (ask first), then STOP: gate 2 is an outline (Opus planning session expands it with playtest findings in).
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
| test_skirmish_match | S1 `TERMINAL_TICK` | 8286 → 9267 | Task 5 (window 8000-17999) |
| test_skirmish_match | S1 `TICK_LIMIT` | 10800 → 18000 | Task 5 (user window) |
| test_skirmish_match | S1 `S1_CORE_SERIES` | 3600881543542644697 → 5002559116398996570 | Task 5 (series covers TERMINAL_TICK + 1 ticks) |
| test_team_match | TB4 `TEAM_CORE_SERIES` | 1490497313643459296 → 5307413438668649372 | Task 5 |
| test_team_match | TB3 `FINAL_DIGEST` | 6a389cd2453bc6c6 → 0ef885e10e0de507 | Task 5 |
| test_team_match | TB3 completed buildings per seat | 4 → 5 | Task 5 (command center) |
| run_netplay.sh | `match` terminal tick | 8242 → 9373 | Task 5 |
| run_netplay.sh | `match` terminal tick | 9373 → 9166 | Task 6 (online ids shift: sources take ids 1-2, units follow at tick 4; inside window) |
| test_skirmish_scene | H1 build line | `1/2/3/4 build` (skirmish), `1/2/3 build` (base) → `1-9: menu` (both) | Task 7 (spec: hint drops the key list) |
| test_base_scene, test_skirmish_scene | Bs5 queue label, E1 enemy line, K4 HUD line | kind id → display name (`Cancel Battle Tank (90%)`, `Enemy (P2) Battle Tank #`) | Task 7 display names |
| debug/team_match.gd | `TEAM_TICK_CAP` | 27000 → 45000 | Task 5 (user window); match ends won, winner 1, tick 37074 |
| test_skirmish_match | S1 `TERMINAL_TICK`, window floor | 9267 → 7731; `terminal >= 8000` → `>= 7000` | Task 8 (armed scout car; user ruling 2026-11-06: floor 7000, upper 17999, TICK_LIMIT 18000, winner 1) |
| test_skirmish_match | S1 `S1_CORE_SERIES` | 5002559116398996570 → 1045294977236534214 | Task 8 |
| test_team_match | TB3 `FINAL_DIGEST`; TB4 `TEAM_CORE_SERIES` | 0ef885e10e0de507 → 4666c566ff0cf70d; 5307413438668649372 → 6345485798033620804 | Task 8 |
| test_state_hash | H1 `PINNED` | 4b52b4564bdd4dfb → 01e256834bdd4dfb | Task 8 (default spawn kind is now armed) |
| run_netplay.sh | `match` terminal tick | 9166 → 8257 | Task 8 |
| test_combat, test_simulation | D1 legacy vehicle weapon, C1/C11 snapshots | weapon "" → scout_gun; combat null → guard record | Task 8 (scout car armed) |

| test_skirmish_match | S1 `TERMINAL_TICK`; `S1_CORE_SERIES` | 7731 → 7685 (floor 7000 kept, below 8000); 1045294977236534214 → 2374153302354515980 | parity (scout speed 3.0 → 2.4 cells/s) |
| test_team_match | TB3 `FINAL_DIGEST`; TB4 `TEAM_CORE_SERIES` | 4666c566ff0cf70d → 12ab49191b88eb61; 6345485798033620804 → 3361446751695866624 | parity (scout speed); team match now won tick 30687, winner 1 (was tick 23816, winner 2), inside cap 45000 |
| run_netplay.sh | `match` terminal tick | 8257 → 7817 | parity (scout speed); inside the S1 window |
| test_economy | E1 scout car speed | 3.0 → 2.4 | parity (scout speed); `check_reference.py` now reports a match, its speed departure entry removed |
| test_movement, test_benchmark | M1-M9, BM3, BM5 ceilings | unchanged numbers; run with the scout car at 3.0 via `Economy.run_legacy_speed` | the pins were written for the 3.0 prototype speed; the movement benchmark workload itself now runs the 2.4 scout car (not rerun) |

| test_base_scene | M1 builder menu | + `5: Missile Battery $1000` | Task 10 |

## Departures and deferrals

- Base suite was 277 cases / 112,748 checks / 1 failure (MP5 count, above), not the plan's 277 / 112,744 / 0.

- Task 3: `MapData.slot` and its start validation read `slots[kind.trim_prefix("usa_")]` because map slot keys are roles (`power_plant`, `supply_center`, `barracks`, `factory`) while kinds are `usa_*`. The plan left this bridge open; Task 4's `slot` field replaces it. Traces differ from the pre-rename run only because the state hash covers kind strings; core series, terminal tick (S1, team), BM6 and netplay 8242 are unchanged.

- Task 4: `Economy.unit()` / `Economy.building()` / `Combat.profile()` return cached legacy-shaped views built from the merged rows in `definitions/usa.gd` (`Registry.unit_view` etc.), so the D1 dict pins and `is_same` identity stay unchanged (user decision, 2026-11-06). The views can go when the pins are rewritten on purpose.
- Task 4: `usa_power_plant.counts_for_victory` is false to keep today's survival rule (a power plant never counted); Task 5 flips it to Zero Hour's rule. `Simulation.spawn` defaults an empty kind to `Registry.DEFAULT_SPAWN` (52 callers rely on the old default); `Skirmish.BUILD_ORDER` / `UNIT_FOR` became `build_order()` / `unit_for()`; `faction.start_building` is empty until Task 5. Hotkey build menus in `base_main.gd` / `skirmish_main.gd` keep their kind literals until Task 7 (outside the guarded directories).
- Test sharding (workflow change before Task 5, user 2026-11-06, not M7 scope): `run_tests.sh` runs the cases in up to 4 parallel `--shard=i/n` processes (`WARGRID_TEST_SHARDS`, `1` = one process); new `test_runner.gd` adds 3 cases / 5 checks (286 cases). `test_team_match.gd` was 100 s of 135 s (prefix case 55 s, core series 44 s), so cases are sharded, not suites. Same tree: one process 124 s, 4 shards 66 s, 8 shards 68 s; totals, sorted FAIL lines and all four traces identical. Check counts differ with traces on (112,764) and off (112,757) because trace writes are checked; that is the source of earlier 112,752 vs 112,759 drift.
- Task 4 performance risk: air checks in `_build_grid` and friends are now `Registry.air_kinds.has(kind)` instead of a string compare; no benchmark run yet (WoW-skew question open, benchmarks wait for the user to quit it).

- Task 5: ids become builder 1, command center 2, builder 3, command center 4, sources 5-6 (`setup_seat` runs per seat in order). `usa_power_plant.counts_for_victory` now true (Zero Hour rule). `structure_tough` armor added to `shared.gd` with the `structure` percentages (the plan's explosion column is not modelled yet). `setup_seat` writes int origins and a default rally (the command center produces). Seats without a `faction` in `MapData.create` still get the legacy builder-only start. The bot queues its faction's `start_unit` at the first idle completed building that produces it when it owns no builder.
- Task 5 test changes (setup or semantics, not tolerance): builder-only survival setups now use `EconomyFixture.add_completed` (test_teams TM3/TM8/TM9/TM10, test_team_match TB1/TB2, test_combat S7 `_last_builder_world`, test_factions F1 steps one tick so the placed foundation exists); ids and removals shifted to the command centers/builder 3 in test_skirmish (K1, O1, A3 now includes the command center as producer target, M0 rewritten: a foundation now keeps a seat alive), test_skirmish_scene (K2, K4), test_online_scene (N1, N4), test_map (MP3), test_replay (R4 removes seat 2's command center at tick 1000 to end the match), test_production (R5). S7 intent changed: unit deaths never end a match while the team owns buildings; the team-out case removes the barracks.
- Task 5 cadence: new tests B1, B2, C2, S2 passed on first run (written with the implementation, not observed red).

- Task 6: online `Skirmish.create(true, "human", {})` defers seat setup (`MapData.create` seat key `defer`), so supply sources take entity ids 1-2 and the seats follow (builder 3, command center 4, builder 5, command center 6). `launcher.gd` unchanged: `online_main.setup` takes an optional `faction` (default from `Skirmish.default_faction()`), the launcher selector is Task 7. The headless client reads `--faction`. `match_over()` is now won or draw; `step()` evaluates only while `ongoing`.
- Task 6 test changes: test_factions F4 rewritten (the plan's "third slot" is the same lockstep tick as the first two, so setup would end at tick 4; seat 2 now chooses at tick 5, its earlier stops are checked as rejected); test_wire COMMAND_TYPES gains `choose_faction` (test_lockstep L4 keeps its 11-type 121-pair matrix, not extended); test_online_scene feeds the peer's `choose_faction`, entity ids shifted (N1, N4), `_own_commands` ignores `choose_faction`. Red seen first for F3, F4, W0 and T1/T2 (new `test_choose_faction_same_tick_cases`); W1 and the N-tests broke on first implementation and were fixed (missing validator branch, test setup).

- Task 7: number keys follow the build menu order (`builds` list), so key 3 is now Barracks and key 4 Vehicle Factory (were Factory/Barracks); the base scene gains key 4. With nothing or a non-builder selected, the menu shows the local faction's `start_unit` builds so keys still say "Choose one builder". Launcher has one `FactionRow` (Own, Opponent); online uses Own only, Opponent is ignored there. `SkirmishMain.factions` static carries the offline choice. Bot still builds the default faction (Task 8 lists). New tests M1-M5 (base scene), F5 (launcher).

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

- Task 8: armed scout car took S1 to 7731 (below 8000); user ruling 2026-11-06 widened the floor to 7000. Fixtures that compare whole entity dicts over time (M1, M6, RP2, G7, movement workload for BM5) set `combat = null` on their default-kind units, because an armed idle unit's `repath_tick` advances; no assertion weakened. New tests S8 (rocket scatter, damage table) and B3 (bot cycle), red first. Bot: `unit_for(producer, owned)` picks the fewest-owned kind, ties by list order; armor rows gained `infantry_missile`, `explosion`, `rapid_fire`, `base_defense`.

- Task 9: snapshot shape departs from the plan's "container_id: int, 0 when outside" and "passengers" on every container: both keys exist only while set (`container_id` on a passenger, `passengers` on a loaded container, erased when empty). A key on every entity moves every full-snapshot trace and `PINNED`, which the stop condition forbids; readers use `.has("container_id")` / `.get("passengers", [])`. Gate reviewer: decide whether to keep or to re-pin with the literal fields.
- Task 9: the enter intent is `unit.order = {"type":"enter","target","target_id"}` (no new entity key; `enter_id` would be outside the gate's snapshot list). `_advance` keeps an enter order on arrival so `Containers.step` can re-path or board; Combat.plan keeps combat mode "move" while a unit is entering. Aircraft cannot enter even when a container lists `air`. `unload` by a non-owner or on a non-container: "Cannot unload this container" (plan named no message). A command naming a passenger via `builder_id` is not caught (only `entity_ids`).
- Task 9 `_entities` loops changed (skip `container_id`): `Simulation.occupied_cells`, `Simulation._unavailable_cells`, `Simulation.replace_blocked_cells` (unit-cover check), `Combat._hold_cells`, `Combat._build_grid`, `Combat.splash_victims`; the `moved` loop in `Simulation.step` excludes passengers. `Combat._can_join` (retaliation joiners) excludes passengers. `_advance` and `_service_paths` need no change (a passenger's status is "contained"). New loops: `Containers.step` (one pass per tick over `_entities`: copy positions, collect enterers), `Containers._free_slots` and `Containers._release` (per validation and per container death).
- Task 9: transports layout (`combat_workload.gd`, `run_combat.gd`): 20 full scout cars march on 100 riflemen; the headless fixture check saw 180 passenger shots in the timed window (first at tick 479). Report-only, not run under the benchmark script; `run_benchmark.sh` now expects `COMBAT BENCHMARK PASSED 5`.

- Task 10: `Combat.fire_defences` skips `_retaliate_trigger` (a building attacker has no `position`); defences do not trigger retaliation. Building `combat` key exists only on armed buildings (as Task 9's keys). Power for the dark check is summed per owner on demand in `fire_defences` (completed buildings, `power` sum < 0), not read from the snapshot. `Registry.kind(...).powered` read with `.get("powered", false)`. `defences` benchmark layout builds its records directly (`_building` in `combat_workload.gd`),; unmeasured; `run_combat.gd` and `run_benchmark.sh` now expect `PASSED 6`.

- Task 10 option B (planning default, not a user approval): `Skirmish._build` skips a kind whose `counts_for_victory` is false before `ATTACK_TICK`, and sets `ctx.saving` while it cannot afford it so `_produce` holds. Result: S1 terminal 8340 (inside window), team match still `cap tick=45000 winner=null units_peak=237`. Pins S1/TB3/TB4 not re-pinned (got 3012336044666173545 / e065527c29051ac2 / 8977165343545068717). DF5 passes with `Skirmish.create(false)`; O1 reverted to four structures.

- Task 10 ZH evidence (read-only, `~/projects/CnC_Generals_Zero_Hour` @ 0a05454): `GeneralsMD/Code/GameEngine/Source/GameLogic/AI/AISkirmishPlayer.cpp:494-540` picks an enemy *player* (skips `hasAnyObjects()==false`, adds a distance penalty when "another ai is already targeting this guy"), not a structure category; `AIPlayer.cpp:1312-1328` treats `KINDOF_FS_BASE_DEFENSE` / `KINDOF_TECH_BASE_DEFENSE` as hostile-strength terms for special-power drop placement only. Victory: `Common/RTS/Team.cpp:1711` `hasAnyBuildings(kindOf)` (defences carry no victory flag). Not found: any explicit "attack defences" priority; units auto-acquire structures in range. Uncertainty: AI teams are script-driven (ScriptActions), not read. Option 1 (defences as last bot target category) was tried in the sim: no effect (S1 8340, TB3/TB4 values and `cap tick=45000 winner=null` identical) and reverted; hypothesis "defences keep seats alive" is false because defences do not count for victory (probe at 45000: seats 1, 2, 5, 8 still owned power/supply/barracks/factory).

- Task 10 option "one battery per seat" (user ruling 2026-11-06): already true, a no-op. `Skirmish._build` skips any kind the seat owns (`buildings.any(kind == kind)`) and each map has one `defence` slot per seat (skirmish.json and, via the converter, ashfall.json); a lost battery is rebuilt. Team match at tick 45000 (option B tree): team 1 (seats 1, 2, 8) holds `pow sup fac def` / `pow sup def` / `pow sup`, units 23 / 4 / 11; team 2 (seats 4, 5, 6) holds `com pow sup def` / `com pow sup bar def` / `com pow def`, units 4 / 17 / 18. No seat is defeated except none; all six still own a counting building. Blocked: needs a different lever.

- Task 10 "stronger bot waves" (user ruling 2026-11-06): lever 1, the bot attacks only once 15 idle units are ready (`WAVE_SIZE`), plus dropping option B (early defence build, no saving rule). Result: team match still `cap tick=45000 winner=null units_peak=261`; S1 terminal 8899 (in window); the gate also broke D2, A3 x5 and TB1 (small-army bot tests). Reverted. Current tree: option B removed, bot builds the battery last in `build_order` as the plan says, no wave gate. Team match not won inside 45000, pins S1/TB3/TB4 un-re-pinned.

- Task 10 ruling (user, 2026-11-06, after the lever log above): the bot does NOT build `usa_defence`. Plan departure: `build_order` stays at four kinds, `test_bot_builds_defence` is replaced by `test_bot_does_not_build_defence` (bot never builds one, builder `builds` includes it, a human seat can order one). The kind, `defence` slots in skirmish.json / ashfall.json, converter, `fire_defences` and the build menu entry stay. Pre-Task-10 flow restored: no S1, TB3, TB4 or netplay pin moved (S1 7731, TB3/TB4 as Task 8, netplay 8257); team match `won tick=23816 winner=2` inside 45000. Traces for the replay, economy and combat scripted matches should be identical to Task 9 (bot unchanged, no armed buildings); not compared with `cmp` this task. Earlier Task 10 pin rows were reverted.

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
- Rendered benchmark: not run (visible window, needs user approval).

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
- Open, user ruling pending: finding 8 defence scan cost (`Combat._defence_pick` scans all objects per idle defence per tick; the `defences` layout p95 2.87 ms over 1.82); left as is.
- Open for gate 2 (plan outline carries them): finding 5 `setup_seat` placement unchecked online; finding 6 `build_order()` / `unit_for()` read `DEFAULT_FACTION` instead of the seat faction.
- Plan/design: "Snapshot fields added at gate 1" now states the as-built keys (present only while set).

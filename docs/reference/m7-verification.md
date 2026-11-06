# M7 verification

Plan: [M7 plan](../superpowers/plans/2026-11-06-m7-factions.md). Design: [M7 design](../superpowers/specs/2026-11-06-m7-factions-design.md). Evidence: [M7 factions](m7-factions.md).

## Resume record

```text
Resume record (updated 2026-11-06, Task 10 done, uncommitted)
Branch / base commit / working-tree state: m7-factions at 2a71a6d (Task 9 committed); Task 10 changes uncommitted
Last green task / next incomplete task: Task 10 (firing buildings, missile battery, powered defences) / Task 11 (gate 1)
Changed paths since last commit: game/scripts/simulation/{combat,construction,simulation}.gd, definitions/{usa,shared}.gd, game/scripts/debug/combat_workload.gd, game/benchmarks/run_combat.gd, game/data/maps/{skirmish,ashfall}.json, tools/{zh_map/convert.py,zh_map/test_zh_map.py,run_benchmark.sh}, game/tests/{test_defences.gd (new),run_tests,test_benchmark,test_base_scene,economy_fixture}.gd, this file
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh, 318 cases / 112,988 / 0, exit 0, TESTS PASSED 112988; lint, warnings, unittest, netplay match (8257) pass; run_team_match.sh: TEAM MATCH won tick=23816 winner=2
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: user ruling 2026-11-06 (after the lever log below): the bot does not build usa_defence; see Task 10 departures
Usage so far: not recorded
Next exact action: commit Task 10, then Task 11 (gate 1). Benchmarks not run (defences layout unmeasured; run_combat now expects PASSED 6).
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

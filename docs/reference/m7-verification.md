# M7 verification

Plan: [M7 plan](../superpowers/plans/2026-11-06-m7-factions.md). Design: [M7 design](../superpowers/specs/2026-11-06-m7-factions-design.md). Evidence: [M7 factions](m7-factions.md).

## Resume record

```text
Resume record (updated 2026-11-07 evening, after the merge; lines below the next one are the earlier checkpoints, kept)
Branch / base commit / working-tree state: main at 105f8e5 = origin/main (m7-factions fast-forwarded into main and pushed; local m7-factions at 3b6b9f1, origin/m7-factions still at the older 11672f4); clean. Suite on 46bbcb0 (later commits docs only): 482 cases / 136,026 checks / 0, see "Review fixes". CI for 105f8e5 was running at this update; no result recorded.
Last green task / next incomplete task: gates 1 and 2 done; gate 3: G3.1 to G3.4 committed, G3.5 part A (matches, check list, ledger, parity, bot record) green and uncommitted; next: commit it, then the G3.5 gate review (Opus high, then /ponytail-review), push for CI (approval), the user's playtest, M7 exit gate (stop).
Gate 3 review fixes (uncommitted, see that section): combat.gd, containers.gd, world_view.gd, tools/run_team_match.sh, tests test_rebuild_holes, test_tunnels, test_skirmish, test_skirmish_waves, test_skirmish_scene, test_factions (460 cases / 134,967 checks, traces unchanged). Earlier changed paths: game/scripts/simulation/definitions/factions.gd (FRC build_order), game/scripts/debug/team_match.gd (seat factions), game/benchmarks/run_team_match.gd, tools/run_team_match.sh, tools/zh_parity/{parity,analyze}.py, game/tests/{test_skirmish_match, test_factions, test_skirmish, test_team_match}.gd, docs (this file, performance.md, the plan). No new files, no new .uid.
Last command / cases / checks / failures / exit / marker: suite 456 cases / 134,954 checks (traces off) / 0 failures, exit 0, TESTS PASSED (75 s); run_lint.sh, run_warnings.sh, run_python_checks.sh, unittest (52) pass; replay, economy, combat traces cmp-identical to a 5736f56 git archive run, team trace moved; all nine run_netplay.sh PASSED; run_conformance.sh CONFORMANCE PASSED 33; run_team_match.sh twice `TEAM MATCH cap tick=45000 winner=null units_peak=171`; run_benchmark.sh exit 1 (open / dense combat stress exceed their report-only ceilings on a loaded host, see the ledger row).
Gate 3 lean cuts (uncommitted, see that section): rebuild_holes.gd, containers.gd, definitions/definitions.gd; suite 460 / 134,967 / 0, exit 0, TESTS PASSED; lint, warnings pass; four traces cmp-identical to a 385671c git archive run.
Ultrareview fixes (uncommitted, see that section): F1-F9 + F7/F8 applied; suite 468 cases / 134,999 checks (traces on) / 0, exit 0; four traces cmp-identical to a HEAD 8eac2cf git archive run; no pin moved (netplay `match` still 8331).
Known red case or blocker: none. Exceeded, not loosened, accepted by the user until the performance spike: combat stress open / dense, team match p95 / p99, hordes300.
Approved decisions, pre-authorizations used, deferred gates: unchanged, plus the user decisions of 2026-11-07 in the G3.5 record (FRC bot builds the factory before the hub; "won inside 45000" waived for the three-faction match).
Open items: Chinook full-load fairness; M6 shared dock cells (latent); unverified online: China vs USA online, Chrome/Firefox, two WASM clients, hidden tab; Esc menu, enter / unload controls, tunnel and crate marks not played; rendered benchmark pending approval (presentation changed); quiet-host rerun of run_benchmark.sh for the `COMBAT BENCHMARK PASSED 10` line (the same two exceeded rows block it).
Usage so far: not recorded
Economy rework T1/T2 (2026-11-07, uncommitted, see the T1/T2 record at the end): T1 red suite and T2 dock arrival points done; T3 (calibration) and T4 (pins) wait for the pooled ZH measurements.
Next exact action (CI and macOS trace match done, see 'CI and macOS trace match' below): the user's playtest; open rulings in "Review fixes"; then the performance spike (docs/performance-spike-prompt.txt). Earlier text: M7 EXIT GATE REACHED (2026-11-07, 98bf150 plus the ledger row). Open: the user's local merge decision (merge m7-factions to main locally, no push before the playtest; delete the scratch branch m7-ultra-base), push for CI and compare_local_traces.sh after the playtest, rendered benchmark rerun and playtest (batch, ask first), final run_benchmark.sh exit is 1 only because combat stress dense p95 3.335 exceeded its report-only ceiling 3.31 once (comparison runs 3.10-3.22, inside), no re-pin proposed. Then the performance spike (docs/performance-spike-prompt.txt, includes the large-map rendering item) and unit avoidance.
```

## Archives

Moved verbatim from this file on 2026-11-07; the sections below stay live. Evidence rows are append-only; new gate records go in the live file until the gate closes.

- [Gate 1 (base rows, performance time box, results, review fixes, CI)](m7-verification-archive-gate1.md): Base rows; Task 1; Task 11; Gate 1 review fixes; CI evidence at gate 1
- [Research (gate 1 playtest findings, Zero Hour skirmish AI and scripts, bot wave update)](m7-verification-archive-research.md): Gate 1 playtest findings research; ZH skirmish AI vs defensive structures; ZH skirmish scripts decoded; ZH skirmish scripts: other findings for later; Bot wave update
- [Gate 2 (China, G2.x records, review fixes, Esc menu, lean cuts)](m7-verification-archive-gate2.md): G2.0 results; G2.2 record; G2.3 record; G2.4 record; G2.5 record; G2.7 gate-2 results; Gate 2 review fixes; G2.6 record; Rendered China layout; Dock starvation fix; Esc menu; Gate 2 lean cuts
- [Gate 3 (FRC, G3.x records, review fixes, lean cuts, ultrareview, parity harness, rendered rerun)](m7-verification-archive-gate3.md): G3.1 record; G3.2 record; G3.3 record; G3.4 record; G3.5 record; Gate 3 review fixes; Gate 3 planning; F3 overlay; Gate 3 lean cuts; Ultrareview fixes; Parity harness improvements; Rendered rerun
- [Economy rework (playtest findings, T1-T4)](m7-verification-archive-economy.md): Playtest findings; T1/T2 record; T3 record, BLOCKED before T4; T4 record

## User acceptance of exceeded performance rows (2026-11-07)

The user accepts the exceeded rows for now (combat stress open/dense, team match p99, hordes, hordes300, rendered horde x6 estimate). A performance improvement spike follows after M7. The rows stay reported as exceeded; no budget is loosened.

## Gate 2 playtest (user statement 2026-11-07)

User: "all of the points above worked perfect" (the offline China watch list given in the session; power use checked at 20 supply / 11 demand with 2 plants, 3 towers, supply center, factory = matches the data). Not stated: the online items (9-10), the Chinook full-load fairness, dock overlap detail, performance in 100+ unit fights. Findings logged: Esc menu to leave a running game back to the main menu (small task after M7; online leave needs a decision: client-side leave vs forfeit message, a protocol change); `run_game.sh` default scene changed to the launcher (9a8d07d).

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
| test_skirmish_match | S1 `TERMINAL_TICK`; `S1_CORE_SERIES` | 7685 → 9473 (window 7000-17999, winner 1); 2374153302354515980 → 8505231937702596599 | bot wave update |
| test_team_match | TB3 `FINAL_DIGEST`; TB4 `TEAM_CORE_SERIES` | 12ab49191b88eb61 → 6b81119ab5577115; 3361446751695866624 → 6113229322264627267 | bot wave update (team match won tick 33205 winner 1, inside the 45000 cap) |
| run_netplay.sh | `match` terminal tick | 7817 → 8331 | bot wave update; inside the S1 window |
| test_skirmish, test_team_match | D2, D3, A3, TB1 | run the bot until the wave releases (rally, then WAVE_TIMEOUT); A3 expects one shared target and the score order first, second, barracks, plant, depot, command center; D3 the carrier, TB1 any seat-2 object | bot wave update (semantics changed on purpose: shared wave target, score instead of categories; no assertion weakened) |

| test_supply | Su2 capacity, Su4 higher-waiter and equal-depot cases, Gt1 truck load | departs on the last box, truck 120 ticks → one more delay: departs 36 ticks later (cargo 8 at 288, seeking at 324), truck 150 | G2.1 full load | REVERTED: ground-only ruling, old value restored |
| test_skirmish_match | S1 `TERMINAL_TICK`; `S1_CORE_SERIES` | 9473 → 8472 (window 7000-17999, winner 1); 8505231937702596599 → 6003359071183333231 | G2.1 full load | REVERTED: ground-only ruling, old value restored |
| test_team_match | TB3 `FINAL_DIGEST`; TB4 `TEAM_CORE_SERIES` | 6b81119ab5577115 → 28ab7309497cd4a7; 6113229322264627267 → 1719080097601549884 | G2.1 full load; REVERTED (ground-only ruling); was OUTSIDE WINDOW: `run_team_match.sh` now ends at the 45000 cap with no winner (was won tick 33205, winner 1) |
| run_netplay.sh | `match` terminal tick | 8331 → 8285 | G2.1 full load; inside the S1 window | REVERTED: ground-only ruling, old value restored |
| test_state_hash | H1 `PINNED` | unchanged | G2.1 full load; REVERTED (ground-only) |

| test_skirmish_match | Fm1 `FRC_TERMINAL_TICK`; `FRC_WINNER` | new, 10512; new, 2 | G3.5 |
| test_team_match | TB3 `FINAL_DIGEST`; TB4 `TEAM_CORE_SERIES` | 6b81119ab5577115 -> f21dde02dd0e80a7; 6113229322264627267 -> 3691462617852479071 | G3.5 (seats carry usa / china / frc; FRC build order factory before hub; the 3v3 ends at the cap, user waiver 2026-11-07) |

## Departures and deferrals

- **Accepted by the user (2026-11-07), G3.1 Lb2:** asserts no two laborers dock (loading/unloading) on the same position, not literally "no two hold the same `collection.dock` cell". The literal form hit 72/1500 ticks, all with different `target_id` (depot ring and source ring overlap at x=13), i.e. false positives. Probe (read-only scratch copy): removing the `held.has(cell)` check in `_claim_dock` turns relaxed Lb2 red (658 stacked ticks); releasing the claim at admission stays green (benign, `active_collector_id` serialises per target). Same-target literal form: 0 hits clean, 1671 on the mutation, not added.
- **OPEN:** Full load for air collectors (Chinook) is NOT applied, ZH does apply it; applying it moved the 6-seat team match from won 33205 to won 61973 (cap 45000) via ~10% less income. Later check whether this asymmetry is fair (playtest ground vs air economy, or revisit with the M8 bot). Evidence: m7-factions.md Full load.

- Base suite was 277 cases / 112,748 checks / 1 failure (MP5 count, above), not the plan's 277 / 112,744 / 0.

- Task 3: `MapData.slot` and its start validation read `slots[kind.trim_prefix("usa_")]` because map slot keys are roles (`power_plant`, `supply_center`, `barracks`, `factory`) while kinds are `usa_*`. The plan left this bridge open; Task 4's `slot` field replaces it. Traces differ from the pre-rename run only because the state hash covers kind strings; core series, terminal tick (S1, team), BM6 and netplay 8242 are unchanged.

- Task 4: `Economy.unit()` / `Economy.building()` / `Combat.profile()` return cached legacy-shaped views built from the merged rows in `definitions/usa.gd` (`Registry.unit_view` etc.), so the D1 dict pins and `is_same` identity stay unchanged (user decision, 2026-11-06). The views can go when the pins are rewritten on purpose.
- Task 4: `usa_power_plant.counts_for_victory` is false to keep today's survival rule (a power plant never counted); Task 5 flips it to Zero Hour's rule. `Simulation.spawn` defaults an empty kind to `Registry.DEFAULT_SPAWN` (52 callers rely on the old default); `Skirmish.BUILD_ORDER` / `UNIT_FOR` became `build_order()` / `unit_for()`; `faction.start_building` is empty until Task 5. Hotkey build menus in `base_main.gd` / `skirmish_main.gd` keep their kind literals until Task 7 (outside the guarded directories).
- Test sharding (workflow change before Task 5, user 2026-11-06, not M7 scope): `run_tests.sh` runs the cases in up to 4 parallel `--shard=i/n` processes (`WARGRID_TEST_SHARDS`, `1` = one process); new `test_runner.gd` adds 3 cases / 5 checks (286 cases). `test_team_match.gd` was 100 s of 135 s (prefix case 55 s, core series 44 s), so cases are sharded, not suites. Same tree: one process 124 s, 4 shards 66 s, 8 shards 68 s; totals, sorted FAIL lines and all four traces identical. Check counts differ with traces on (112,764) and off (112,757) because trace writes are checked; that is the source of earlier 112,752 vs 112,759 drift.
- Task 4 performance risk: air checks in `_build_grid` and friends are now `Registry.air_kinds.has(kind)` instead of a string compare; no benchmark run yet (load-skew question open, benchmarks wait for a quiet host).

- Task 5: ids become builder 1, command center 2, builder 3, command center 4, sources 5-6 (`setup_seat` runs per seat in order). `usa_power_plant.counts_for_victory` now true (Zero Hour rule). `structure_tough` armor added to `shared.gd` with the `structure` percentages (the plan's explosion column is not modelled yet). `setup_seat` writes int origins and a default rally (the command center produces). Seats without a `faction` in `MapData.create` still get the legacy builder-only start. The bot queues its faction's `start_unit` at the first idle completed building that produces it when it owns no builder.
- Task 5 test changes (setup or semantics, not tolerance): builder-only survival setups now use `EconomyFixture.add_completed` (test_teams TM3/TM8/TM9/TM10, test_team_match TB1/TB2, test_combat S7 `_last_builder_world`, test_factions F1 steps one tick so the placed foundation exists); ids and removals shifted to the command centers/builder 3 in test_skirmish (K1, O1, A3 now includes the command center as producer target, M0 rewritten: a foundation now keeps a seat alive), test_skirmish_scene (K2, K4), test_online_scene (N1, N4), test_map (MP3), test_replay (R4 removes seat 2's command center at tick 1000 to end the match), test_production (R5). S7 intent changed: unit deaths never end a match while the team owns buildings; the team-out case removes the barracks.
- Task 5 cadence: new tests B1, B2, C2, S2 passed on first run (written with the implementation, not observed red).

- Task 6: online `Skirmish.create(true, "human", {})` defers seat setup (`MapData.create` seat key `defer`), so supply sources take entity ids 1-2 and the seats follow (builder 3, command center 4, builder 5, command center 6). `launcher.gd` unchanged: `online_main.setup` takes an optional `faction` (default from `Skirmish.default_faction()`), the launcher selector is Task 7. The headless client reads `--faction`. `match_over()` is now won or draw; `step()` evaluates only while `ongoing`.
- Task 6 test changes: test_factions F4 rewritten (the plan's "third slot" is the same lockstep tick as the first two, so setup would end at tick 4; seat 2 now chooses at tick 5, its earlier stops are checked as rejected); test_wire COMMAND_TYPES gains `choose_faction` (test_lockstep L4 keeps its 11-type 121-pair matrix, not extended); test_online_scene feeds the peer's `choose_faction`, entity ids shifted (N1, N4), `_own_commands` ignores `choose_faction`. Red seen first for F3, F4, W0 and T1/T2 (new `test_choose_faction_same_tick_cases`); W1 and the N-tests broke on first implementation and were fixed (missing validator branch, test setup).

- Task 7: number keys follow the build menu order (`builds` list), so key 3 is now Barracks and key 4 Vehicle Factory (were Factory/Barracks); the base scene gains key 4. With nothing or a non-builder selected, the menu shows the local faction's `start_unit` builds so keys still say "Choose one builder". Launcher has one `FactionRow` (Own, Opponent); online uses Own only, Opponent is ignored there. `SkirmishMain.factions` static carries the offline choice. Bot still builds the default faction (Task 8 lists). New tests M1-M5 (base scene), F5 (launcher).

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

## User sign-offs (2026-11-07, after the economy parity rework)

The user signed off, in one message, on the five items the executor listed: (1) Fm1 outcome 2 -> 1 and its tick 10512 -> 23534; (2) the dropped `hole` event in Fm1's `seen` list (RH1 stays as the coverage; the seat-swapped attempt had no hole either); (3) the team-match cap line `units_peak` 171 -> 160 with winner still null at 45000; (4) the `skirmish.json` piles 200 -> 400 boxes (Zero Hour SupplyDock value, decided by the coordinator while the user was away); (5) the Su2 meaning change (the Chinook holds the dock one more delay, then leaves). Not signed off and still open: the combat stress `open`/`dense` ceilings (exceeded, not re-pinned), the 700-unit automatic search radius, the 30 s clearance timeout, the Chinook x4 trace check, the fork changes F1-F3 for the parity harness, push and merge.

## Review fixes (2026-11-07, tree: m7-factions 4e1ee2d plus uncommitted, Apple M-series)

- Harness: `stop_group` and `Game.close` treat macOS EPERM (a group that is only an unreaped zombie) as gone; `close` unlinks its pidfile in a `finally`; `kill_run` reads and kills the `sweep-parent` pidfiles first, then reads the rest (the remaining window: a job a parent launched before it died). Tests: stop_group on a zombie group (red before the fix) and a dead group, kill_run kills the recorded parent, clears pidfiles and spares a foreign pid.
- Converter: piles are 4x5 (origin = cell - (2, 2), clamped), slots keep the edge margin 1; constants mirror `definitions.gd` (`SOURCE_FOOTPRINT`, `BUILD_EDGE_MARGIN`) and `supply_clearance` 1 (the 1-cell ring around each slot already gives the pile clearance). `ashfall.json` and `skirmish.json` untouched, so re-running the converter would still differ from the hand-shifted ashfall slots. `test_supply.gd` Pl3 now iterates every `res://data/maps/*.json`.
- New tests, mutation-checked: Pl1 corner case (Chebyshev -> Manhattan in `_near_source` now fails 3 checks); Gd10 air arrival admitted ahead of an earlier ground waiter (deleting `if not _is_ground(other): return true` fails it; the older Gd9 never discriminated because its ground waiter stood off its arrival point); Gd11 helicopter on a 3-box pile waits 4 x load delay (early release after the last box fails it). `test_supply_parity.gd` Chinook wording replaced by "helicopter collector".
- Docs: placement/clearance comments, rework plan pruned to Revision 2 plus the root causes, Fm1 decision note folded into the T4 record and deleted, parity docs trimmed, README and AGENTS M7 status updated.
- Checks on this tree: suite 482 cases / 136,026 checks / 0 failures; lint, warnings, python checks pass; `python3 -m unittest discover -s tools` 85 OK. Replay, economy, combat and team traces cmp-identical to a `git archive` of 4e1ee2d (no simulation change).
- Resume: Next exact action: coordinator commits; exit gate otherwise as in the T4 record.

### Open rulings for the user (not decided)

1. Two or more helicopter collectors on one pile lock every ground collector of any owner out permanently (reviewer scratch run: 2 helicopters, an enemy truck earned 0 credits in 20,000 ticks; with 1 helicopter +8,100). True since 8eac2cf; follows from the ruling that air goes first (F4). Zero Hour behaviour for mixed air and ground queues is unverified; suggest measuring 2 Chinooks + 1 truck on one pile with the parity harness before ruling.
2. A rendered benchmark rerun is still required by AGENTS because presentation changed (terrain cache, 4x5 piles, label order, pick_source). Batch it with the playtest; needs the user's go-ahead (opens a window).
3. The edge margin could be 2 cells (closer to Zero Hour's 1.2; the user chose 1; both maps pass at 2).
4. The usa/china load/unload split between pile and depot is a modelling choice: the 5 % parity rows constrain the cycle sum only.


## CI and macOS trace match (2026-11-07, tree: main 105f8e5)

GitHub Actions run 42410911096 on `main` 105f8e5 (pushed with the user's approval): success on Linux, Windows, relay, relay-lint, python-lint, actions-lint, gdscript-lint and compare-replays. `sh tools/compare_local_traces.sh 42410911096` on macOS (Apple M6), exit 0: replay REPLAYS MATCHED 1200, economy 1200, combat 1200, team 100, netplay 281. Pending for the M7 exit gate: the user's playtest (offline FRC; online FRC against China or USA needs a test deploy, which needs the user's approval).

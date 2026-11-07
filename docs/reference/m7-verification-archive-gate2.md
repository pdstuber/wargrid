# M7 verification archive: Gate 2 (China, G2.x records, review fixes, Esc menu, lean cuts)

Moved verbatim from [m7-verification.md](m7-verification.md).

## G2.0 results (tree: m7-factions 8f835c0 + uncommitted G2.0, Apple M6)

- Suite 346 / 134,359 / 0, exit 0, TESTS PASSED 134359 (baseline 344 / 134,353). Lint, warnings pass. All nine `run_netplay.sh` scenarios PASSED, `match` terminal tick 8331 (unchanged).
- Trace check: replay, economy, combat (1200 rows) and team (100 rows) traces `cmp`-identical to a clean worktree at 8f835c0. No pin moved.
- Red seen first: `test_setup_rejects_commands_until_all_chose` (S2). `test_bot_reads_seat_faction` (B4) was written after the bot change, not observed red; its rocket-first and barracks-only expectations differ from the USA list so it would fail on the old code.
- Departures: `Definitions.add_test_faction` lives on the registry (`definitions.gd`; tests' `Registry`), cleared by `clear_test_kinds`. S2 steps one tick after each choice so the start unit exists, and seat 2 chooses at tick 9 (status ongoing at 10). `test_choose_faction_same_tick_cases` (T1) unchanged and green. `Skirmish._faction` replaced `_start_unit`; `skirmish_main._production_kind` reads the local seat's faction from the snapshot.

## G2.2 record

Red first, all six seen red (missing china kinds, faction row, weapon, armor column, menu label): `test_china_start`, `test_china_power_and_prerequisites`, `test_quantity_trains_two`, `test_damage_table_gattling`, `test_bot_plays_china`, `test_build_menu_quantity_label`. Each is a new case; suite 352 → 358 cases.

| test | assertion | old → new | cause |
|---|---|---|---|
| test_online_scene | F5 faction selector text | item 0 `United States` → item 0 `China`, selected item `United States`, 2 items | G2.2 (ids sort, china before usa; default selection stays usa) |
| test_view | I1 every building defines an icon | all buildings → all except `china_defence` | G2.2 (plan: no icon, the view draws the fallback letter) |

Departures and decisions (G2.2):
- `china.gd` display names corrected to the Global Constraints table: `Power Plant`, `Supply Depot` (G2.1 had `Nuclear Reactor`, `Supply Center`).
- `china_rifle_infantry` has `quantity 2` but no `horde` yet (G2.3); `china_tank` and `china_defence` have `weapon ""` (G2.4).
- Quantity spawn: `Production.free_exits` counts walkable, in-bounds, unoccupied perimeter cells; fewer than `quantity` free means no spawn and the entry stays. Quantity 1 and air paths are unchanged, so USA traces did not move.
- Button label comes from `base_main.menu_label` (skirmish shares it), so no `skirmish_main.gd` edit.
- `test_bot_plays_china` runs the bot 4000 ticks and checks first building `china_power_plant`, only `china_` units, at least one combat unit.

## G2.3 record

Red first (stubs for `bonus_delay` and `horde_marks` so the suite compiled; before them the suite did not compile): `test_horde_needs_five`, `test_horde_infantry_mix_counts`, `test_horde_rub_off`, `test_horde_cadence`, `test_horde_allies_only`, `test_horde_change_restarts_delay`, `test_horde_marks`. `test_horde_vehicle_exact_kind` failed only its positive half (5 tanks reach 2); its negative half (4 tanks + a rotary tank stay 0) passes without any horde code, so it was not red. Mutations: removing the container filter fails H6; disabling the restart fails H7 (wrong 4 of 4).

| test | assertion | old → new | cause |
|---|---|---|---|
| run_benchmark.sh, run_combat.gd | `COMBAT BENCHMARK PASSED` | 7 → 8 | G2.3 `hordes` layout |
| run_benchmark.sh, run_combat.gd | `COMBAT BENCHMARK PASSED` | 9 → 10 | gate 2 review fixes, `hordes300` layout |

Benchmark `hordes` (60 militia, 20 medium tanks vs 100 riflemen, Apple M6): p50 1.20 / p95 2.08 / p99 2.83 ms; window `horde_checks` 4662, level-2 peak 75. Report-only (over the 1.82 / 3.64 budget at p95 and under p99; no ceiling pinned, no budget loosened). The `docks` and `hordes` rows are not in the ledger yet.

Departures and decisions (G2.3):
- Resume record said G2.2 uncommitted; HEAD 95094e8 already holds it (record fixed).
- `Combat.bonus_delay(combat, _weapon, ticks)` keeps the plan signature; the weapon is unused until G2.4 adds the ramp branch. `Combat.restart_wait(sim, combat, weapon)` is the shared "bonus change restarts the wait" helper (G2.4 calls it too).
- `horde_checks()` counts units checked (due checks), not pair tests.
- Marker is white, not the owner colour: the unit rectangle is owner-coloured and the mark sits inside it (test requirement), so an owner-coloured diamond would be invisible. Centre is 4 px below the rectangle top, radius 3.
- The horde fields for `china_rifle_infantry`, `china_rocket_infantry`, `china_light_vehicle` were not in G2.2; added here per the values table.
- `Horde.step` skips the whole pass when no armed unit has `horde`; `combat.horde` and `combat.horde_tick` exist only on horde kinds, so USA snapshots are unchanged.
- H7 asserts at least one pending restart (all four flips happen, but infantry re-check and fire both run on a 30-tick cadence, so some flips coincide with the firing tick and nothing is pending then).
- `tools/run_warnings.sh` reads `git ls-files`, so untracked new scripts are skipped until staged; the two new files were checked with `--check-only` by hand.

## G2.4 record

Red first (all six, seen red: 5 crashed on `china_tank` having no combat, `test_rotary_tower_intervals` failed with no shots): `test_rotary_tank_intervals`, `test_rotary_tower_intervals`, `test_ramp_switch_within_coast_keeps_count`, `test_ramp_resets_after_coast`, `test_rotary_tower_dark_when_low_power`, `test_ramp_snapshot_keys_only_on_ramp_weapons`. Red was crash or empty-result, not a pinpoint assertion. No mutation run on the new tests. After implementation one of mine failed on a test bug (R5 expected level 1 at 30 ticks, the tower was already at 2); fixed by checking at 16 ticks.

| test | assertion | old -> new | cause |
|---|---|---|---|
| run_benchmark.sh, run_combat.gd | `COMBAT BENCHMARK PASSED` | 8 -> 9 | G2.4 `ramp` layout |

Benchmark `ramp` (20 rotary tanks, 6 towers vs 100 riflemen, Apple M6): p50 0.137 / p95 0.776 / p99 1.425 ms; window level-2 shots 680. Report-only, within budget. Not in the ledger yet (docks, hordes, ramp rows come at G2.7).

Departures and decisions (G2.4):
- `Combat.bonus_delay` now reads `weapon.ramp.percent[level - 1]`; horde still wins (shortcut comment kept). `_ramp_after_shot` follows the plan algorithm; `restart_wait` reused on level change, including the lazy cool-down.
- Ramp window check counts shots by objects that were at level 2 after the previous tick (shots at level 2), via an id set rebuilt each tick for the `ramp` layout only.
- `ramp` layout: tanks 5x4 attack-move, towers in a column at x=10, 2 plants (supply 20, demand 18).
- R5 uses supply 0 (plants removed) as the dark spell and `remove_object` on the plants.

## G2.5 record (2026-11-07)

- Red first: all new tests failed before the code (unsupported command type, no right-click order). Not seen red individually: the DA4 edge checks after the first one (removed target, removed defence, killed by fire, dark defence); the red run hit script errors (`_last_result` on an empty results array) and aborted that case, so only its first check was seen failing. They are green with the implementation.
- Mutation check on the same-tick cases: apply the order only when the building has no target; DA3 `defence_attack after` and `before` failed (2 failures), restored afterwards.
- Departure: `test_lockstep.gd` `COMMAND_TYPES` gains `defence_attack` as a 12th entry, but the L4 matrix keeps its `/ 11` and `% 11`, so the entry is not exercised there (the plan says the matrix stays 11, as for `choose_faction`, `enter` and `unload`, which are absent from that list). Online coverage of the command is the wire round trip (W0, W1) plus the sim tests.
- Departure: the scene order is a method `_order_defence` in `skirmish_main.gd` that runs before the unit right-click branch; with a selected own armed completed building it submits `defence_attack`, an unreachable pick shows the simulation's "Target out of range". A right-click on ground with a selected defence still does nothing (set_rally does not apply to it).
- Persistence after the target leaves reach is the existing keep-valid-target rule then the 8-tick scan; Zero Hour's behaviour was not verified (as the plan states).
- Netplay `match` still ends at tick 8331 (scenario passed); no pin moved.

## G2.7 gate-2 results (tree: m7-factions e2d48fc + uncommitted G2.7 tests, parity tooling and docs, Apple M6, 2026-11-07)

- New tests: `test_china_skirmish_match` (Cs1): china seat 1 vs usa seat 2, both bots, status won at tick 16258, winner 2 (usa), inside the 45000 cap; horde level 2, ramp level 2, a truck delivery and a pair of `china_rifle_infantry` appearing on one tick all happened before the end. `test_choose_faction_online_china_same_hash` (F4): china/usa, bots from tick 4, 3000 ticks, digests equal every 30 ticks, 100+ rows.
- Pin rows (provisional, cause "G2.7"): test_skirmish_match Cs1 `CHINA_TERMINAL_TICK` new 16258, `CHINA_WINNER` new 2. No existing pin moved.
- Suite 384 / 134,584 / 0, exit 0 (traces on); this tree. Baseline at start 382 / 134,571 (traces off); worktree e2d48fc with traces on: 382 / 134,578 / 0. Lint, warnings (89 files), `run_python_checks.sh`, `python3 -m unittest discover -s tools` (39) pass.
- Trace check: replay, economy, combat, team traces on this tree are `cmp`-identical to a clean worktree at e2d48fc (USA traces unchanged by G2.7; tests only).
- Netplay (this tree): match terminal tick 8331 (unchanged), kill, stall, silent, spike, perturb, version all PASSED. `run_conformance.sh` CONFORMANCE PASSED 33.
- `run_benchmark.sh` exit 0, `COMBAT BENCHMARK PASSED 9`; results in the performance ledger row of 2026-11-07. Exceeded and not loosened: combat stress open 2.764 / 3.656 and dense 3.099 / 4.67 against 1.82 / 3.64 (report-only, inside ceilings); team match p99 5.15 against 3.64 (p95 1.767 inside 1.82). New layouts: docks (stacked_ticks_window 0), hordes (level2_peak_window 75, 4662 checks), ramp (680 level 2 shots), all report-only. Rendered benchmark not run (pending approval).

### Bot wave revisit record (report only, no constant changed)

| match | gate 1 (Task 11) | now |
|---|---|---|
| china vs usa skirmish (2 bots) | n/a | won tick 16258, winner 2 |
| usa mirror skirmish S1 | won tick 7731 winner 1 | won tick 9473 winner 1 (after bot wave update, unchanged since) |
| team match 3v3 | won tick 23816 winner 2 | won tick 33205 winner 1 (unchanged since the bot wave update; all-usa lists) |

The 3v3 team match still has no China seats; the China 1v1 result is the first one with the China lists. `WAVE_MIN` and the rest stay the user's call (M8 research).

### Parity, China (measured (source build), fork branch wargrid-parity; traces `~/CnC/parity/g2`, game `-headless -noaudio`, gate 1 traces untouched)

New scenarios in `tools/zh_parity/{parity,analyze}.py` (self-test OK, python checks pass). Unarmed `ChinaVehicleDozer` and `ChinaVehicleSupplyTruck` have move/turn only (no range/reach). `power_for` now also spawns a `ChinaPowerPlant` for the Gattling cannon.

| scenario | metric | measured | Wargrid | verdict |
|---|---|---|---|---|
| move_redguard / tankhunter | top speed | 25.0 / 20.0 | 25 / 20 | PASS |
| move_battlemaster / gattlingtank | top speed | 25.035 / 40.056 | 25 / 40 | PASS |
| move_cndozer / truck | top speed | 30.0 / 40.056 | 30 / 40 | PASS |
| turn_ (redguard, tankhunter) | turn rate | 500 / 500 deg/s | 500 | feel, matches |
| turn_ (battlemaster, gattlingtank) | turn rate | 180 / 180 deg/s, start delay 24 frames | 180 | feel, matches |
| turn_ (cndozer, truck) | turn rate | 90 / 90 deg/s, 61 / 63 turn frames, start delay 47 / 3 | 90 | feel, matches |
| range_ / reach_redguard | first shot / farthest fire | 115 / 122 | 100 | +22 (as Ranger) |
| range_ / reach_tankhunter | | 196.4 / 200 | 175 | +25 |
| range_ / reach_battlemaster | | 179.5 / 181 | 150 | +31 (Crusader +33) |
| range_ / reach_gattlingtank | | 179.9 / 183 | 150 | +33 |
| reach_gattlingcannon | farthest fire (powered) | 251 | 225 | +26 (Patriot +27) |
| rof_redguard / rof_battlemaster | shot interval | 30 / 60 | 30 / 60 | PASS |
| ramp_gattling_tank | first intervals | 12,12,6,6,6,6,4 (then 4) | 12,12,6,6,6,6,4 | PASS |
| ramp_gattling_cannon | first intervals | 8,4,4,4,4,2,2 | 8,4,4,4,4,2 | PASS (the analyze FAIL is the seventh interval, 2, beyond the expected six) |
| horde_redguard | last interval, five spawned together | 20 (first 36, then 20) | 20 | PASS; the harness can spawn a group |

The range/reach offsets are the same attacker/target geometry as Ranger +22, Crusader +33, Patriot +27; INI ranges equal Wargrid. Gattling tank and cannon ramp cadence and the horde interval equal the formulas exactly.

Decision list (no value changed; user decides):
1. No value departs: all speeds, turn rates, cadences, ramp and horde intervals match.
2. Ranges: +22 to +33 centre-to-centre offsets are geometry, not range errors; no change (as in gate 1).
3. Horde: first shot interval 36 before the bonus applies; Wargrid's first-check timing was not compared here. Feel only, candidate for the playtest.
4. Battlemaster and Gattling tank show a one-frame speed spike (peak 48.8 / 66.7 u/s, accel 1464 / 2000) at the start; cruise equals Wargrid. Feel only.


## Gate 2 review fixes (tree: m7-factions eb3fbed plus uncommitted fixes, Apple M6, 2026-11-07)

Review: Opus, diff 8f835c0..eb3fbed, no critical findings. Red-first run (fixes I1 and I2 absent, I3 counter present, scan still quadratic): 388 cases, 4 failures (Gb1 x2, Q1 rally, H8 pairs 122,816 for 404 checks). Pins, Cs1, F4 and all four traces unchanged.

| finding | ruling |
|---|---|
| I1 stall after cut path | Fixed. `Supply.step`: a ground collector in `flying_*` with status `blocked` releases and retries in 30 ticks. Test `test_ground_truck_recovers_after_blocked_path` (Gb1), seen red. |
| I2 quantity-2 charged for one unit | Fixed. `Production.spawn_unit` places all units first, then `_send_out` assigns rally moves. Test `test_quantity_rally_on_free_exit` (Q1), seen red (1 militia, paid 300, entry dropped). |
| I3 horde scan quadratic | Fixed. `Horde.step` buckets members by cell (size = widest rule radius + 2 * largest unit radius) and `_level` scans the 3x3 block; `Simulation.horde_pairs()` counts candidates. Test `test_horde_pairs_bounded` (H8, 300 spread militia, pairs <= 12 per check), seen red (122,816 / 404). New report-only `hordes300` layout. Results identical (traces, pins). The hordes p95 did not move (2.102 vs 2.083): the scan was not its main cost, so it still **exceeds 1.82**; hordes300 p95 / p99 5.626 / 7.074 exceeds 1.82 / 3.64. Nothing loosened; the cost is the user's call. |
| I4 unwalkable / unreachable ring cells | Test only (`Gd4`): blocked cells and a sealed pocket are skipped, all-blocked ring idles with retry +30. Not red (code was right); mutation check removing the walkable and component filters failed both Gd4 checks, then restored. |
| M1 Gd2 contention | Fixed: trucks at 30.5 and 31.5 both want cell 27,5; checks the second takes 27,4. Not red (extra check on correct code). |
| M2 H3 negative half | Fixed: test-only `test_horde_vehicle` (copy of the medium tank row) via `add_test_kind`; four medium tanks plus one stay 0. Not red. |
| M3 DA3 companions | Fixed: cancel_production, gather, enter, unload now valid (queue entry via `Production.enqueue`, a collector, a scout car and a rifleman); DA3 now also checks the companion result is ok. `choose_faction` dropped: any command other than `choose_faction` is rejected while a match is in setup, so it cannot share a started world with the others. |
| M4 double-click building | Renamed the test to `test_double_click_enemy_or_ground_plain`; it never had a building case, and picking a building needs scene fixture work not worth it here. |
| M7 dead tie-break | Deleted (the ring is already y, x ordered and the compare is strict). |
| M8 `_spawn_on_complete` ignoring -1 | Documented with a `shortcut:` comment (smallest choice); a retry needs new state. Open if a playtest shows a lost truck. |
| M10 analyze.py | `ramp_gattling_cannon` expects `8,4,4,4,4,2,2`. |
| M11 resume record | Updated to the real tree. |

Open minor item, not done (skipped by instruction): M6 a source and a nearby depot can share dock cells (`_claim_dock` only excludes the same target; 0 stacked docked ticks measured, latent).
Closed 2026-11-07: M5 test `test_ground_admit_lowest_id_first` (renamed `test_ground_admit_first_waiter_first` by the dock starvation fix; Gd4 then: lowest id loads before the closer waiter); replacing `_arrival(other,target)` by `center(target)` in the waiting-before scan turns Gd4 red (mutation run, reverted, tree file unchanged), green on HEAD code. M9 measured, no fix: `docks` layout now holds 100 idle riflemen; p95/p99 0.061/0.086 ms before, 0.864/0.899 after, of which the `_admit` scan is about 0.035 ms (0.829 with the loop stubbed out in a scratch run, reverted), under 5% of the step, so not bounded; the cost is the idle units. Suite 390 cases / 134,589 / 0, lint, warnings, benchmark, all nine netplay scenarios, team match (won 33205 winner 1), faction guard pass; no simulation file changed.

Checks on this tree: suite 388 / 134,583 / 0 exit 0 (traces off), 134,590 (traces on); four traces `cmp`-identical to a clean eb3fbed worktree (replay, economy, combat 1200 rows each, team 100); lint, warnings (89 files), `run_python_checks.sh`, unittest discover, `test_faction_guard.py` pass; netplay match 8331, kill, stall, silent, spike, perturb, version PASSED; conformance PASSED 33; `run_benchmark.sh` exit 0, `COMBAT BENCHMARK PASSED 10` (ledger row 2026-11-07 gate-2 review fixes); `run_team_match.sh` won 33205 winner 1. Rendered benchmark not run.

## G2.6 record (2026-11-07, commit e2d48fc)

- Tests (`game/tests/test_scene.gd`): `test_double_click_same_kind_on_screen`, `_alt_whole_map`, `_shift_keeps`, `_ctrl_ignored`, `_enemy_or_ground_plain` (renamed from `_enemy_or_building_plain`, see "Gate 2 review fixes" M4). They run on the prototype scene `main.gd` (no buildings, so the building case is covered by empty ground), 16x16 map, off-screen unit at (14.5, 14.5), camera zoom 2, position (0, 128). Shift double-click unions with the earlier selection.
- Red first: same_kind_on_screen, alt_whole_map, shift_keeps. `ctrl_ignored` and the enemy/ground test passed before the change (they assert the old plain-click behaviour). The reviewer judged ctrl valid by mutation and the enemy/building test vacuous for the feature (not re-verified here).
- Suite after G2.6: 382 cases / 134,571 / 0 (from the commit's resume record). Presentation only; traces not rerun then.

## Rendered China layout

New `horde` leg in `movement_benchmark.gd` (workload `CombatWorkload.create("horde_render")`: 300 China rifle / rocket / light vehicle / tank units attack-move onto 100 USA riflemen). Test first: `test_horde_render_layout` (BM9, 300 units, marks drawn, units moved). Suite on this tree: 389 cases / 134,586 checks / 0 failures, exit 0; lint, warnings (89 files) pass; `run_benchmark.sh` exit 0 (`BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, lockstep 1); no simulation file changed, so traces are unchanged by construction (not re-compared). Rendered run (user-approved, one window, closed on exit 0): `RENDERED BENCHMARK PASSED 3`; horde frame interval p95 4.374 ms (open 0.591, dense 2.584), peak 233 horde marks, marked on 1800 of 1800 ticks, 300 units moved, draw calls p50 222. Numbers and caveats in the performance ledger row of 2026-11-07 (rendered rerun with the `horde` layout). Not viewed by a person (no screenshot). Resume record next action unchanged.

## Dock starvation fix (2026-11-07, tree: m7-factions a081e44 plus uncommitted)

Bug: 3 `china_collector` at a source with a depot 1 cell away (usa depot (10,10), source (14,10)) share ring cells; the lowest-id truck re-entered the same tick it finished and `_admit` preferred the lowest id, so one truck never loaded (loads 20, 19, 0 in 1500 ticks). Fix in `supply_collection.gd` `_ahead`: ground trucks that are waiting go first in the order they began waiting, then arrivals by id; the begin-waiting tick is stored in `remaining_ticks`, which is unused while waiting (no new snapshot field). Air (Chinook) keeps lowest id first, code path unchanged. `_claim_dock` untouched.
Tests: new `Gd5` (`test_ground_dock_no_starvation`, loads min > 0 and max - min <= 8 over 1500 ticks): seen red before the fix ([20, 19, 0]), green after. `Gd4` rewritten as `test_ground_admit_first_waiter_first` (was lowest id loads next; now the truck that began waiting first, intended change).
Checks on this tree: suite 397 cases / 134,606 / 0, TESTS PASSED; replay, economy, combat and team traces cmp-identical to a clean HEAD worktree (no USA trace moved); lint, warnings (91 files), `test_faction_guard.py` pass; all nine netplay scenarios exit 0, `match` terminal tick 8331 unchanged; team match won 33205 winner 1; `run_benchmark.sh` exit 0 (PASSED 2, COMBAT 10, LOCKSTEP 1).
Pin changes: none (Cs1, F4 and all China pins unchanged). Not run: rendered benchmark, CI Linux/Windows traces.


## Esc menu (2026-11-07, tree: m7-factions 72b2ec7 plus uncommitted, Apple M6)

Presentation and shell only; no simulation, `relay/` or `protocol/` file changed (traces unchanged by construction, not re-compared). New `presentation/pause_menu.gd` (Resume / Back to main menu / Quit, "Leave the match?" Leave / Cancel), wired in `main.gd` `_input` so every main inherits it; `UiStyle.hud_theme()`, full-rect dim overlay.
Esc findings: action `deselect` (Esc) already clears selection (`main.gd`), cancels placement and building selection (`base_main.gd`), clears attack-move mode and the inspected enemy (`skirmish_main.gd`), and `skirmish_main` ignores input after match over. The menu opens only when `_escape_pending()` is false (nothing selected, no drag, placement, pending placement, building selection, attack-move or inspect; after match over always false), so those Esc presses behave as before. While open, Esc closes (or leaves the confirmation) and other keys except F3 are swallowed; the overlay blocks mouse. F3 unaffected.
Offline: `_physics_process` returns early while open (tick frozen, resumes after Resume); leave goes straight to the launcher. Online: the sim keeps stepping; Leave asks first, then `_finished = true`, `set_relay_lost()` (this client ends), `transport.close()` once, scene change to the launcher via the injectable `change_scene` Callable; the peer sees the existing `left` ending `ended_left`. A forfeit message is deferred to M9; leaving is a disconnect for the peer. Quit calls `get_tree().quit()` and is not built when `OS.has_feature("web")`.
Tests: `test_pause_menu.gd` (E1-E8, 8 cases). Seen red by mutation (pause off, escape check off, no transport close, confirm off): E1 selection, E2, E5, E6. NOT seen red: E1 attack-move and placement paths, E3, E4 (online keeps stepping), E7 (Quit hidden), E8 (layout at 1280x720 and 1920x1080 against Status/Economy text). Implementation was written before the tests, not test-first.
Checks on this tree: suite 405 cases / 134,654 / 0, exit 0; lint, warnings (91 files), `test_faction_guard.py` pass; `run_benchmark.sh` exit 0 (PASSED 2, COMBAT 10, LOCKSTEP 1); `run_netplay.sh` match, kill, stall, silent, spike, perturb, version, relay-down, relay-term all exit 0. Not run: any window, rendered benchmark, CI.

## Gate 2 lean cuts (2026-11-07, tree: m7-factions db3c16b plus uncommitted, Apple M6)

User decision: apply all five lean review findings; behaviour identical. 11 files, 52 lines added, 88 removed.
1. Benchmark layout `hordes` deleted (`hordes300` kept; same code path at 3x the army); one `_attack_move` helper for the shared layout ending. `COMBAT BENCHMARK PASSED 10` -> `9` in `run_combat.gd` and `run_benchmark.sh`. Historic ledger rows stay; one ledger note added.
2. `add_test_faction` / `_extra_factions` removed; `faction()` is a plain `Factions.FACTIONS.get`. `test_bot_reads_seat_faction` now runs seat 2 on the real china faction (command center plus `china_power_plant`; `china_rifle_infantry` from a `china_barracks`). Seen red by mutation (china mapped to the usa row): both B4 checks fail.
3. `horde_pairs` counter and accessor removed. `test_horde_pairs_bounded` is now `test_horde_spread_all_checked` (every militia checked in 40 ticks). The near-linear pair bound is no longer asserted by a test; only the `hordes300` benchmark shows a quadratic regression. Not mutation-tested (cell grid removal).
4. `supply_collection.gd` loading: one release path (`_load_box` before the check for air, after it for ground; same order and timing as before). Su*, Gt*, Gd* unchanged and green.
5. `analyze.py` and `parity.py`: 6 `move_*` and 6 `turn_*` rows each come from one `CHINA_MOVERS` table. EXPECT keys/order/values and SCENARIOS keys/order/closure contents byte-identical before and after (dump diff); `analyze.py --self-test` OK.
Checks on this tree: suite 405 cases / 134,653 / 0, exit 0 (was 134,654; one pair assert removed); replay, economy, combat and team traces cmp-identical to a clean worktree of the previous HEAD; lint, warnings (93 files), `test_faction_guard.py`, `run_python_checks.sh`, `python3 -m unittest discover -s tools` pass; `run_benchmark.sh` exit 0 (PASSED 2, COMBAT 9, LOCKSTEP 1; hordes300 p95 5.588); all nine netplay scenarios exit 0; team match won 33205 winner 1. Not run: any window, CI.

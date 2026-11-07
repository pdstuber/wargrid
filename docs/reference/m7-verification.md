# M7 verification

Plan: [M7 plan](../superpowers/plans/2026-11-06-m7-factions.md). Design: [M7 design](../superpowers/specs/2026-11-06-m7-factions-design.md). Evidence: [M7 factions](m7-factions.md).

## Resume record

```text
Resume record (updated 2026-11-07, gate 3 review fixes green, uncommitted)
Branch / base commit / working-tree state: m7-factions at 5736f56 (G3.1 to G3.4 committed locally, not pushed) plus uncommitted G3.5 part A. Branch not merged to main; origin/m7-factions is older.
Last green task / next incomplete task: gates 1 and 2 done; gate 3: G3.1 to G3.4 committed, G3.5 part A (matches, check list, ledger, parity, bot record) green and uncommitted; next: commit it, then the G3.5 gate review (Opus high, then /ponytail-review), push for CI (approval), the user's playtest, M7 exit gate (stop).
Gate 3 review fixes (uncommitted, see that section): combat.gd, containers.gd, world_view.gd, tools/run_team_match.sh, tests test_rebuild_holes, test_tunnels, test_skirmish, test_skirmish_waves, test_skirmish_scene, test_factions (460 cases / 134,967 checks, traces unchanged). Earlier changed paths: game/scripts/simulation/definitions/factions.gd (FRC build_order), game/scripts/debug/team_match.gd (seat factions), game/benchmarks/run_team_match.gd, tools/run_team_match.sh, tools/zh_parity/{parity,analyze}.py, game/tests/{test_skirmish_match, test_factions, test_skirmish, test_team_match}.gd, docs (this file, performance.md, the plan). No new files, no new .uid.
Last command / cases / checks / failures / exit / marker: suite 456 cases / 134,954 checks (traces off) / 0 failures, exit 0, TESTS PASSED (75 s); run_lint.sh, run_warnings.sh, run_python_checks.sh, unittest (52) pass; replay, economy, combat traces cmp-identical to a 5736f56 git archive run, team trace moved; all nine run_netplay.sh PASSED; run_conformance.sh CONFORMANCE PASSED 33; run_team_match.sh twice `TEAM MATCH cap tick=45000 winner=null units_peak=171`; run_benchmark.sh exit 1 (open / dense combat stress exceed their report-only ceilings on a loaded host, see the ledger row).
Known red case or blocker: none. Exceeded, not loosened, accepted by the user until the performance spike: combat stress open / dense, team match p95 / p99, hordes300.
Approved decisions, pre-authorizations used, deferred gates: unchanged, plus the user decisions of 2026-11-07 in the G3.5 record (FRC bot builds the factory before the hub; "won inside 45000" waived for the three-faction match).
Open items: Chinook full-load fairness; M6 shared dock cells (latent); unverified online: China vs USA online, Chrome/Firefox, two WASM clients, hidden tab; Esc menu, enter / unload controls, tunnel and crate marks not played; rendered benchmark pending approval (presentation changed); quiet-host rerun of run_benchmark.sh for the `COMBAT BENCHMARK PASSED 10` line (the same two exceeded rows block it).
Usage so far: not recorded
Next exact action: commit G3.5 part A plus the gate 3 review fixes (local, pre-authorized), re-review if the coordinator wants, push for CI (approval).
```

## G3.1 record (2026-11-07, tree: m7-factions b354098 plus uncommitted G3.1, Apple M6)

Red first (tree: tests only plus the `LABORERS` constant): 24 failures across Fr1, Fr2, Lb1, Lb2, Pg2, Fb1, F5. Green after `definitions/frc.gd`, `Frc` in `definitions.gd` (`kind`, `_ids`), `can_rally`, row `frc`, `Production._send_out` exit rule, `Skirmish._produce` laborer rule.
Checks on the same tree: suite 413 cases / 134,726 checks / 0 failures, exit 0, TESTS PASSED (baseline before: 407 / 134,689 / 0); `run_lint.sh` pass; `run_warnings.sh` 95 files pass; `test_faction_guard.py` pass. No tooling touched, python checks not run. USA and China traces not `cmp`-compared separately: every pin (S1 `TERMINAL_TICK`/`S1_CORE_SERIES`, TB3/TB4, Cs1, `PINNED`, netplay-tick constants in the suite) passed unchanged. Benchmarks and netplay not rerun (no USA/China sim path changed).
Departures: (1) `test_laborer_docks_share_fairly` asserts no two laborers docked (loading/unloading) on the same position instead of "no two hold the same `collection.dock`": the literal form fails on 72 of 1500 ticks because a depot ring and a source ring one cell apart share a column of cells, so a laborer bound for the depot and one bound for the source hold the same cell coordinate as dock; 0 stacked docked ticks measured (the known latent M6 item, unchanged). (2) `Skirmish._produce` filters units with `hole_id` from `owned` and `replace_builder` as the plan says; no unit has the key yet. (3) The factory display name is "Vehicle Yard" (Global Constraints table). No launcher.tscn change; F5 width passed.

## G3.2 record (2026-11-07, tree: m7-factions 0c9f6c2 plus uncommitted G3.2, Apple M6)

Red first: with only tests and the suite registration, the suite did not start (parse errors: `Combat.masked`, `RebuildHoles` missing), so every new case was red. Green after `frc.gd` (holes, `rebuild_hole`), `rebuild_holes.gd`, the `remove_object` / `step` / `_validate` hooks, `Construction.place_rebuild` / `cancel` / `preview` / `step`, `Combat.masked` (`valid_target`, `_build_grid`, `splash_victims`), `map_data._start_valid`, bot `_build` / `_attack`, `WorldView` picks.
Tests: `test_rebuild_holes.gd` RH1-RH15 (15 cases, 71 checks), `test_skirmish.gd` Fb2 (`test_bot_leaves_rebuild_alone`, seen red against the old `skirmish.gd` after a kill of the hole laborer was added: "bot builder on the site"), `test_view.gd` V9 (seen red against the old `world_view.gd`) and I1 exempts the three hole kinds. Suite 413 -> 430 cases.
Checks on the same tree: suite 430 / 134,811 (traces on; baseline same way 413 / 134,733) / 0, exit 0, TESTS PASSED; lint pass; warnings 97 files pass; `python3 -m unittest discover -s tools` 52 OK (`test_faction_guard.py` included, no faction id added to guarded code). Four traces (replay, economy, combat, team) `cmp`-identical to a run on 0c9f6c2; every pin passed unchanged. Benchmarks and netplay not rerun: no USA/China sim path changed (every hook is a no-op for kinds without the gate-3 fields); the one new per-tick cost is `RebuildHoles.step` scanning `_buildings` for the `rebuild` key.
Departures (none changes a plan assertion): (1) `Simulation.remove_object` sets `_units_removed` and `step` re-filters `ids` and `armed` after `Construction.step` / `RebuildHoles.step` when set, because `site_completed` removes the laborer after those lists are built (without it `Supply.step` and the advance loop read a missing entity); the flag is not in the snapshot. (2) RH11 forces `respawn_tick` to the current tick after the seat's laborer has built for 120 ticks, because the seat's laborer finishes the barracks (251 ticks left) before the 600-tick timer otherwise. (3) RH1 puts a counting building in the world for the `frc_defence` case: the plan's wording needs a seat that survives, since the Tunnel Hub does not count. (4) RH13 and RH14 use an explicit `attack` order / a shooter south of the hole: an idle rifleman targets the site, not the laborer, so a guard alone would not kill it. (5) The rebuild site's `hp` is full `max_hp` (plan, existing departure).

## G3.3 record (2026-11-07, tree: m7-factions 1b5d9ac plus uncommitted G3.3, Apple M6)

Red first: with only tests and the suite registration, 19 FAIL lines and script errors (`_crates`, FRC kinds and weapons missing) across test_salvage.gd (Sv1-Sv8), S10, CT7, Fb3, V10. Green after `shared.gd` (five weapons, `SALVAGE_CRATE`), four unit rows, `salvage` on the laborer, `produces` of barracks and factory, `units_for`, `initial_combat` tier, `Combat.weapon_of` / `_killers` / `_hp_of` / the `_splash` field reads, `salvage.gd`, `simulation.gd` (`_crates`, snapshot key, `Salvage.step` after `Horde.step`), `WorldView.crate_marks` and its draw.
Tests: `test_salvage.gd` (8 cases) plus `test_damage_table_frc_weapons` (S10), `test_pickup_passengers` (CT7), `test_bot_plays_frc` (Fb3), `test_crate_marks_frc_only` (V10). Suite 430 -> 442 cases.
Checks on the same tree: suite 442 / 134,888 (traces on; baseline same way 430 / 134,811) / 0, exit 0, TESTS PASSED; lint pass; warnings 99 files pass; unittest discover 52 OK (no faction id in guarded code). Four traces `cmp`-identical to a 1b5d9ac run (`git archive` copy); every pin passed unchanged. Benchmarks and netplay not rerun: salvage and the splash fields are no-ops for USA and China kinds; the one new per-tick cost is an `is_empty()` test in `Salvage.step`.
Departures (none changes a plan assertion): (1) `fire_defences` has no `Salvage.on_death` call: a defence killer is a building, which never has `salvage`, so the call could not fire; add it if a defence ever gets the field. (2) The `weapon_of` parameter is `object`, not `record` (a parameter named `record` shadows `Combat.record`, a warning treated as error). (3) `_killers` is fed `_hp_of(sim, dead)` (hp before this tick's damage, dead victims only). (4) A killer that is itself dead and removed earlier in the dead-id order drops no crate (plan wording "killer record still exists", in dead-id order). (5) Sv8 uses the plan's 1.5-cell neighbour with a `usa_rifle_infantry`; the worst scatter could in principle miss it, the seeded run hits 8 of 8.

## G3.4 record (2026-11-07, tree: m7-factions fbbe61d plus uncommitted G3.4, Apple M6)

Red first: with only the new tests and the suite registration, about 40 FAIL lines across test_tunnels.gd (TN1-TN10), Fb4, TU1 and H1. Green after `frc.gd` (hub weapon, `contains`, `spawns_on_complete`), `shared.gd` (`tunnel_gun`), `containers.gd` (`carrier`, `centre`, `shared`, `tunnel`, hub walk / board / unload / heal / `building_removed`), `construction.gd` (`approach` flag), `simulation.gd` (enter branch, `remove_object` hook), `combat.gd` (`_plan_passenger`), `base_main.gd` (right-click enter, `U`, hint).
Tests: `test_tunnels.gd` (10 cases) covering the plan list, `test_bot_builds_tunnel_hub_never_enters` (Fb4), `test_enter_unload_scene` (TU1, scene and layout), H1 expects `U: unload`. Suite 442 -> 454 cases.
Checks on the same tree: suite 454 / 134,948 / 0, exit 0, TESTS PASSED (traces on; baseline same way 442 / 134,888); lint pass; warnings 100 files pass; unittest discover 52 OK (no faction id in guarded code); four traces (replay, economy, combat, team) `cmp`-identical to a fbbe61d `git archive` run, every pin unchanged; `run_netplay.sh` match, kill, stall, silent, spike, perturb, version, relay-down, relay-term all `NETPLAY PASSED`.
Benchmark: the `frc` layout prints `COMBAT FRC tier_start=0 tier_end=1 occupant_hp_rose=true hole_hp_rose=true` and passes in the timed window; tick p50 / p95 / p99 / max 0.271 / 1.033 / 1.484 / 2.985 ms (inside the 1.82 / 3.64 budget; shots 1188, deaths 78). `sh tools/run_benchmark.sh` exits 1 on this host because combat stress `open` (p95 / p99 3.08-3.27 / 4.06-4.24) and `dense` (3.39-3.69 / 4.98-5.34) exceed their report-only ceilings (3.05 / 4.23, 3.31 / 5.01); a fbbe61d copy run back to back gives the same (open 3.095 / 4.016, dense 3.525 / 5.052; load average about 4), so it is host load, not this change. Nothing loosened; the script therefore never prints `COMBAT BENCHMARK PASSED 10` here (script and `run_benchmark.sh` now expect 10). Needs a quiet-host rerun and a ledger row before the M7 exit.
Departures (none changes a plan assertion): (1) `Construction.approach` got a `crowded` flag (default false) that skips the occupied-cell filter; a 1x1 hub has four perimeter cells, so with the filter the fifth of ten walkers found no approach and gave up, which fails "6 at A and 4 at B fill it". Units may share an approach cell since they vanish on boarding. (2) The plan's boarding-tick and unload-plus-death cases are built with a hub at 1 HP and an idle enemy rifleman placed the tick before (an idle guard fires at tick 0), not with a due-tick attack order. (3) `Combat` needed no other change: `_plan_passenger` is the only entity-table read of `container_id`. (4) `U` with a selected container unit or building submits `unload`; with nothing selectable it sets "Select a container".

## G3.5 record (2026-11-07, tree: m7-factions 5736f56 plus uncommitted G3.5, Apple M6)

Matches. Fm1 `test_frc_skirmish_match` (frc seat 1 vs usa seat 2, both bots, cap 45000): won tick 10512, winner 2; a laborer delivery, a hole, two `frc_rocket_infantry` on the tick a hub completed and a crate all happened before the end. Pins `FRC_TERMINAL_TICK` 10512, `FRC_WINNER` 2 (provisional, cause G3.5). F6 `test_choose_faction_online_frc_same_hash` (frc / china, bots from tick 4, digests equal every 30 ticks to 3000) passes. Both written first and run red against placeholders.

Finding 1 (first 3v3 run, TB3 red): seat 6 (frc) had 4 of 5 buildings at tick 3000 and no factory by tick 6000. Cause (probe): the bot's `build` for `frc_factory` was rejected every decision with "Footprint covers ground unit or destination" because the two `frc_rocket_infantry` the hub spawns stand idle at (120.5, 19.5) and (120.5, 18.5), inside the factory footprint; by the time they left, the credits had gone to units. Seat 8 had the same hub but its fighters stood clear of its slot. User decision (2026-11-07): FRC bot build order supply cache, barracks, factory, then the one Tunnel Hub (`factions.gd`). Fb4 changed first and seen red, green after. Only FRC bot behaviour changed; USA and China traces and pins did not move.

Finding 2 (three-faction 3v3, usa + china + frc per team on Ashfall, cap 45000): ends `TEAM MATCH cap tick=45000 winner=null units_peak=171`, also with the cap at 90000 (stable stalemate: seat 8 buildings frozen from tick 44999 to 89999 at Headquarters 81%, hub 86%, vehicle yard 97%; seat 8 units 18 -> 36, team 2 units 29 / 13 / 15 -> 20 / 10 / 15). Per-seat record at 45000: seat 1 usa 0 buildings 1 unit; seat 2 china 0 / 0; seat 8 frc 5 buildings 18 units; seats 4 / 5 / 6 five buildings each, 29 / 13 / 15 units; no holes, no sites, 0 holes reopened (the hole rule is not involved). Diagnosis (read-only probes): seats 1 and 2 die by about tick 32000; from then every team 2 wave targets seat 8 (a live, hittable laborer next to the hub; no stale or masked target), but seat 8 sits 105-160 cells away, so waves of 3-6 units arrive piecemeal and die in the last 25 cells (lead unit ids change every 500-1000 ticks, nearest approach 5.5 cells) against a growing defender army and the hub gun. The same layout with seat 8 as usa or as china (60000 ticks) is also unfinished, so it is not FRC-specific: a generic bot limit (wave size and trickle, no concentration on a far last target). M8 owns wave concentration; no bot constant was changed.

User waiver (2026-11-07): "won inside 45000" is waived for the three-faction match only; the cap stays 45000 and the result is pinned as a cap result. `tools/run_team_match.sh` now requires `^TEAM MATCH cap tick=45000 winner=null units_peak=171$` (a winner, another tick or another peak fails), `run_team_match.gd` returns success for the cap. Fm1 (FRC 1v1, won tick 10512) is the won-match evidence for FRC. TB3 per-seat building check (5 each at tick 3000, now passing unweakened) and "a tank was produced" unchanged. Two runs of `run_team_match.sh`: identical line.

Pin rows (cause G3.5): test_skirmish_match Fm1 `FRC_TERMINAL_TICK` new 10512, `FRC_WINNER` new 2; test_team_match TB3 `FINAL_DIGEST` 6b81119ab5577115 -> f21dde02dd0e80a7, TB4 `TEAM_CORE_SERIES` 6113229322264627267 -> 3691462617852479071. S1, `PINNED`, Cs1, netplay `match` and every other pin unchanged.

Checks (this tree): suite 456 cases / 134,954 checks (traces off; 134,961 with the four trace env vars) / 0 failures, exit 0, TESTS PASSED, 75 s (baseline at start 454 / 134,948 on 5736f56); lint, warnings, `run_python_checks.sh`, unittest discover (52) pass; traces with the four env vars on this tree vs a `git archive` of 5736f56: replay, economy, combat cmp-identical, team moved on purpose; `run_netplay.sh` match, kill, stall, silent, spike, perturb, version, relay-down, relay-term all exit 0; `run_conformance.sh` CONFORMANCE PASSED 33; `run_team_match.sh` twice cap line identical (the script now also pins `units_peak=171`; the match is deterministic), 45000 ticks about 110 s wall (CI timing: the 3v3 is not in the suite, only the 20000-tick prefix of TB3 / TB4 is, so the suite time is unchanged). `run_benchmark.sh` exit 1: movement PASSED 2; combat stress open 3.59 / 4.455 and dense 4.05 / 5.497 exceed their ceilings (host load average 2.7 to 3.5, not quiet; the same two rows exceeded on a 5736f56 copy in G3.4); not loosened, so `COMBAT BENCHMARK PASSED 10` and the lockstep line are not printed. frc layout inside budget (see the ledger). Ledger row added to [performance](performance.md). Rendered benchmark not run.

Departures: (1) FRC bot build order change (user decision above), plan step G3.1 wording "hub after barracks" kept, factory now before the hub. (2) The three-faction match ends at the cap (user waiver). (3) `run_team_match.gd` returns true for the cap result; `tools/run_team_match.sh` expects the pinned cap line. (4) Parity scenarios for the Technical use `GLAVehicleTechnical` directly (spawned fine, no chassis fallback).

### Parity, FRC (measured (source build), fork branch wargrid-parity; traces in scratch, `~/CnC/parity` untouched, game `-headless -noaudio`)

New in `tools/zh_parity/{parity,analyze}.py` (`FRC_MOVERS`, self-test OK, python checks pass): `move_` / `turn_` for worker, rebel, tunneldefender, technical, scorpion; `range_` / `reach_` for the four armed units and `reach_tunnel`; `burst_rebel`, `rof_technical`, `rof_scorpion`, `rof_tunnel`. The laborer's supply cycle is not measured (`supply()` is Chinook-only).

| scenario | metric | measured | Wargrid | verdict |
|---|---|---|---|---|
| move_worker / rebel / tunneldefender | top speed | 25.0 / 20.0 / 20.0 | 25 / 20 / 20 | PASS |
| move_technical | cruise (peak) | 83.33 (90.0) | 90 | PASS within tolerance; cruise is 7% under the Wargrid speed, accel 100, 23 frames to top |
| move_scorpion | cruise (peak) | 40.056 (66.7 one-frame spike) | 40 | PASS (as Battlemaster) |
| turn_ worker / rebel / tunneldefender | turn rate | 500 deg/s, 11 frame start delay | 500 | feel, matches |
| turn_technical / scorpion | turn rate | 180 deg/s (45 / 32 turn frames, start delay 3 / 24) | 180 | feel, matches |
| range_ rebel / tunneldefender / technical / scorpion | first shot | 117.0 / 196.4 / 180.4 / 179.1 | 100 / 175 / 150 / 150 | +17 / +21 / +30 / +29 (geometry as Ranger +22, Crusader +33) |
| reach_ rebel / tunneldefender / technical / scorpion | farthest fire | 125 / 200 / 185 / 182 | 100 / 175 / 150 / 150 | +25 / +25 / +35 / +32 (same geometry) |
| reach_tunnel | farthest fire, no power | 215 | 175 | +40 (building footprint); fires without power: confirmed |
| burst_rebel | burst pattern | 4,4,22 | 3,3,21 | +1 each (inside the plan's +-1; Ranger is 3,3,21) |
| rof_technical / rof_scorpion / rof_tunnel | shot interval | 6 / 30 / 8 | 6 / 30 / 8 | PASS |

### M7 decision list (no value changed; the user decides)

One row per kind or mechanic, USA from Task 11, China from G2.7, FRC from G3.5.

| faction | kind / mechanic | measured (source build) | Wargrid | verdict |
|---|---|---|---|---|
| usa | Ranger / Crusader / Dozer / Missile Defender speed, turn | 20 / 30 / 30 / 20 u/s, turns match | same | match |
| usa | scout car speed | cruise 60.09 (peak 66.7) | 75 (3.0 cells/s), then 60 after parity | decided and changed to 2.4 in Task 8 parity (recorded) |
| usa | ranges Ranger / Crusader / Missile / Scout / Battery | +22 / +33 / +22 / +33 / +27 offsets | 100 / 150 / 175 / 150 / 225 | geometry offsets, no change |
| usa | Patriot cadence | 8,8,8,60 (powered) | 8 / clip 4 / 60 | match |
| usa | Ranger burst, Crusader rof, Missile rof, Scout rof | 3,3,21 / 60 / 30 / 6 | same | match |
| usa | Dozer mid-turn dip | speed falls to about 1 u/s | min turn speed 25 u/s | feel, playtest candidate |
| china | Redguard / Tank Hunter / Battlemaster / Gattling tank / Dozer / Truck speed, turn | 25 / 20 / 25 / 40 / 30 / 40 u/s; turns match | same | match |
| china | ranges Redguard / Tank Hunter / Battlemaster / Gattling tank / cannon | +22 / +25 / +31 / +33 / +26 | 100 / 175 / 150 / 150 / 225 | geometry offsets, no change |
| china | rof Redguard / Battlemaster, Gattling ramps, horde interval | 30 / 60, 12,12,6,6,6,6,4, 8,4,4,4,4,2, 20 | same | match |
| china | horde first interval 36, Battlemaster / Gattling start speed spike | as measured | not compared | feel, playtest candidate |
| frc | Worker / Rebel / Tunnel Defender / Scorpion speed, turn | 25 / 20 / 20 / 40 u/s; 500 / 500 / 500 / 180 deg/s | same | match |
| frc | Technical speed | cruise 83.3, peak 90 | 90 (3.6 cells/s) | within tolerance; cruise 7% under, user may want 83 (3.33 cells/s); no change |
| frc | ranges rebel / tunnel defender / technical / scorpion | +17 / +21 / +30 / +29 offsets | 100 / 175 / 150 / 150 | geometry offsets, no change |
| frc | Tunnel Network reach | 215, fires unpowered | 175 | +40 footprint offset; no power needed confirmed |
| frc | Rebel burst | 4,4,22 | 3,3,21 | +1 per interval (candidate: set 4,4,22 if the user wants exact), no change |
| frc | Technical / Scorpion / Tunnel rof | 6 / 30 / 8 | same | match |
| frc | Laborer supply cycle | not measured (harness supply() is Chinook-only) | 1 box, 75, load 5 / unload 5 | unmeasured |

### Bot record (report only, no constant changed)

| match | gate 1 | gate 2 | now |
|---|---|---|---|
| usa mirror skirmish S1 | won 7731, winner 1 | won 9473, winner 1 | won 9473, winner 1 (unchanged) |
| china vs usa skirmish (Cs1) | n/a | won 16258, winner 2 | won 16258, winner 2 (unchanged) |
| frc vs usa skirmish (Fm1) | n/a | n/a | won 10512, winner 2 (usa) |
| team match 3v3 | won 23816, winner 2 | won 33205, winner 1 (all usa) | cap 45000, no winner (usa + china + frc per team; seat 8 diagnosis above) |

`WAVE_MIN` and the rest unchanged (M8).

## Gate 3 review fixes (2026-11-07, tree: m7-factions f1d69bd plus uncommitted fixes, Apple M6)

Fix subagent for the gate 3 review findings; every fix has a test seen red first (a scratch `WG_ONLY` case filter in `run_tests.gd`, reverted).

- I1 `Combat.fire` / `fire_defences`: the dead loop skips an id whose record is already gone (a dead rebuild site removes its laborer silently first). RH16 `test_site_and_second_laborer_die_together` (red: SCRIPT ERROR plus a second death event; green: one death event, hole unmasked, timer restarted).
- I2 `Containers.enter_error` / `unload_error` reject a container that is itself inside a tunnel (`container_id`). TN11 `test_tunnel_contained_container_rejected` (red: both accepted).
- I3 Fb2 extended and W10 `test_wave_leaves_masked_hole` added (skirmish waves). Mutations, each applied to `skirmish.gd` then reverted: (a) drop the `rebuild.kind` ownership match in `_build` killed by Fb2 "places the next build-order kind soon after the hole opens" (factory tick 1771 instead of 1171); (b) count the rebuild laborer in `_produce` killed by Fb2 "a bot laborer lost while the rebuild laborer works is replaced" (without the fix the replacement waits for the laborer to vanish); (c) drop the masked filter in `_attack` killed by W10 (all eight wave units idle).
- Minor 1 F6 seat 2 is `china` (plan). Minor 3 `run_team_match.sh` pins `units_peak=171` (stable, same line the script prints). Minor 4 `WorldView.pick_entity` skips units with `container_id`, so `pick_object` on an occupied hub returns the hub (TU1 scene check, red first). Drag-select `pick_entities` and `pick_target` still include contained units (not asked; `Combat.valid_target` already rejects them).
- Minor 7 TN12 `test_enter_after_hub_death_same_tick`: an enter validated between a hub's death and the next `Containers.step` raised no error. Green without a fix, kept as a guard.
- Minor 2 check counts: the committed tree gave 456 cases / 134,954 checks with traces off and 134,961 with the trace env vars on; the G3.5 and resume records above are corrected. After these fixes: 460 cases / 134,967 traces off, 134,974 traces on.
- Recorded, not changed (reviewer rulings): minor 5 `_free_cell` falls back to the container centre when no free cell is found (unlikely, accepted); minor 6 an orphaned rebuild site spawns its one-shot units once finished after the hole died (plan says ordinary foundation; Zero Hour source unchecked); minor 8 the rebuild laborer can collect crates (harmless).

Checks on this tree: suite 460 / 134,967 / 0, exit 0, TESTS PASSED; lint, warnings (100 files), `run_python_checks.sh`, unittest discover (52) pass; replay, economy, combat and team traces `cmp`-identical to a `git archive` run of f1d69bd (suite 460 / 134,974 with traces vs 456 / 134,961 at f1d69bd); no pin moved; `run_team_match.sh` exit 0, `TEAM MATCH cap tick=45000 winner=null units_peak=171`. Netplay, conformance and benchmarks not rerun (no relay, protocol or tick-cost change).

## Gate 3 planning (2026-11-07, tree: m7-factions 11672f4, docs only)

Opus (high) planning session; no code, test or benchmark run. Sources re-read for every lead of the planning brief: EA source `0a05454` and the pinned `INIZH.big` (findings with paths in [M7 factions, "Gate 3 planning findings"](m7-factions.md#gate-3-planning-findings-2026-11-07)). Corrections and additions to the brief: the hole regen is at `RebuildHoleBehavior.cpp:306-318` (not ~254-262); a new hole starts at full 500 HP (`setMaxHealth` clips); a cancelled rebuild foundation is killed with no refund in Zero Hour, so `Construction.cancel` routes through `remove_object`. No parity run (G3.5 measures the FRC rows).

Planning questions for gate 3, with the planning default and the user's answer:
1. G3.5 three-faction 3v3: convert `team_match.gd` (seats 1 usa, 2 china, 8 frc against 4 usa, 5 china, 6 frc; TB3/TB4 and the team trace re-pinned) or add a separate match. Default: convert. Answer (user, 2026-11-07): convert, as recommended.
2. G3.4 enter/unload controls (none exist in the HUD): right-click to enter, `U` to unload, hint text. Default: add. Answer (user, 2026-11-07): add, with the hint and the scene / layout tests.
3. G3.3 pickup cannon and rocket against infantry: per-weapon `infantry_blast` 1.853 and `infantry_scatter false`, or the global rule with two departures. Default: per-weapon fields. Answer (user, 2026-11-07): per-weapon `infantry_blast` 1.853 and `infantry_scatter false` on the pickup cannon and rocket only.

Follow-up checks (same day, docs only; details in m7-factions.md "Gate 3 planning findings"): a Command Center laborer walks to the rally point and idles (plan G3.1 exit rule, `can_rally`); riders of a loaded transport stay inside it in a tunnel and are destroyed silently with it; the player may resume a rebuild site only while the hole's laborer is not building it ("Foundation is being rebuilt"); the launcher row fits with the FRC name (measured, 520 px); the frc benchmark layout is scripted by tick (no tuning); `Construction.cancel` has one caller, no trace can move; an unfinished FRC match at the 45000 cap is a pre-agreed stop with three options for the user.

## F3 overlay (2026-11-07, tree: m7-factions 557afa4 plus uncommitted, Apple M6)

Presentation only. `scripts/presentation/perf_overlay.gd` (Label, top-right, hidden by default) is created in `main.gd` `_ready`, so base, skirmish and online all get it; F3 toggles it in `main._unhandled_input`. Shows FPS, frame ms (current / p95 / max over 120 frames), sim step ms (current / p95, `Time.get_ticks_usec` around `_step_simulation()` in `_physics_process`, view layer), units, buildings, tick; online adds command latency p95 and RTT p95 (`_net_line`). Text refreshes 4x per second; rings are preallocated. Moved/removed: nothing. The `Tick:` in the base status line and the debug line of the plain `main.gd` HUD stay (the base one is useful to the player; the main.gd line is its whole test HUD).
Tests: `test_perf_overlay.gd` PO1 summary math, PO2 F3 and hidden default, PO3 layout clear of Status/Economy and inside the viewport, PO4 counts/step timed, PO5 skirmish wired; N9 in `test_online_scene.gd`. Seen red: PO2-PO5 (5 failures before wiring). Not seen red: PO1 (pure function written with the overlay; its first run caught my own wrong expectation 195 vs 194, not a code bug), N9 (added after wiring). A first draft created the Label in a member initializer and leaked at exit (suite exit 1 with 0 failures); now created in `_ready`.
Checks: suite 396 cases / 134,602 / 0, exit 0, TESTS PASSED; lint, warnings (89 files) pass; `run_benchmark.sh` exit 0 (PASSED 2, COMBAT 10, LOCKSTEP 1), run before the leak fix, which touched only view code. No simulation file changed, traces not re-compared. Not viewed on screen.

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

## Gate 1 playtest findings research (2026-11-06)

Read-only research, no code changed. Zero Hour source `~/projects/CnC_Generals_Zero_Hour` (0a05454), paths under `GeneralsMD/Code/GameEngine/Source`; retail INI via `tools/check_reference.py` helpers on `INIZH.big` (read only).

### 1. Double-click select-all-of-type

- ZH confirmed: `GameClient/MessageStream/SelectionXlat.cpp:477` `MSG_MOUSE_LEFT_DOUBLE_CLICK`: ignored when force-attack mode (Ctrl) is on ("Pressing ctrl is disallowed for double clicking"); only a single point (no drag box); picks a selectable drawable under the cursor, `break`s (propagates the click) if none, if `!isMassSelectable()`, or if not `isLocallyControlled()`. Alt held = whole map (`selectMatchingAcrossMap`), else the visible screen (`selectMatchingAcrossScreen`).
- Same type = `ThingTemplate::isEquivalentTo` (`Common/Thing/ThingTemplate.cpp:1478`): same template, same final override, or reskin of each other. Not KindOf. Filter `InGameUI.cpp:173 similarUnitSelection`: own (`isLocallyControlled`), not contained, not already selected, `isMassSelectable`, not off-map, obeys optional max-select cap.
- Structures excluded: `Object::isMassSelectable` = `isSelectable() && !isKindOf(KINDOF_STRUCTURE)` (`GameLogic/Object/Object.cpp:3048`). Double-click on a building does nothing special.
- Shift: "prefer selection mode" re-adds the previous selection after the matching select (`SelectionXlat.cpp:~505-535`). Key `T` (`MSG_META_SELECT_MATCHING_UNITS`, `CommandXlat.cpp:2360` -> `InGameUI::selectUnitsMatchingCurrentSelection`, `InGameUI.cpp:4924`) works on the whole current selection (all its templates), screen first, then whole map if nothing new on screen.
- Double-click time: raw event comes from the OS (`Win32Mouse.cpp:142` `MBS_DoubleClick`), so the system double-click interval; not an INI value. Unverified: exact ms on the retail build.
- Wargrid today: `game/scripts/main.gd:73-117` single click/drag/Shift only; no double-click, no `T`, no type filter. Buildings are selected on the separate `selected_building_id` path in `base_main.gd:200-212`.
- Smallest design: in `_finish_selection` (main.gd), on a second left release within ~0.4 s at the same spot (click, not drag) on an own non-building unit: pick all own, non-contained units of the same `kind` inside the view rect (`_view.pick_entities` with the visible rect); Alt = whole map; Shift keeps `_start_selection`; Ctrl ignored. Presentation only, no sim command. `T` can reuse the same function.
- Open: threshold (0.3-0.5 s); screen-only vs map (ZH: screen, Alt = map); same `kind` only vs reskins (Wargrid kinds are per faction, so `kind` equality is fine).

### 2. Battery manual attack

- ZH confirmed: attack validity is per object, not per KindOf: `CommandXlat.cpp:150-260 canObjectForceAttack`: any selected object with `isAbleToAttack()` may be ordered; vs an object via `getAbleToAttackSpecificObject(ATTACK_NEW_TARGET_FORCED, ...)`; vs ground, IMMOBILE objects are accepted only if `getAbleToUseWeaponAgainstTarget` says the position is in reach (comment: "stationary units that try to force attack in a location beyond their reach"). So a Patriot can be force-targeted at units, buildings (force attack) and ground in range; out of range is rejected (it cannot move). Weapon `AntiGround = Yes`, `AntiAirborne* = No` on `PatriotMissileWeapon` (weapon.ini:1939): that weapon cannot hit air.
- Persistence after the target leaves range: unverified (did not read AIUpdate/TurretAI attack-state exit; `attack_target` parity probe fired at gap 150, no leave-range test). Assume the order ends and auto-acquire resumes.
- Wargrid today: a battery can be selected (any own building, `base_main.gd:203-211`) but selection only drives the production panel. `attack` needs entity ids (`simulation.gd:215-219` `_live_ids`/`_armed`: units only, "Attack requires armed units"); right-click attack (`skirmish_main.gd:90-93`) sends `selected_ids`, which is empty for a building. `fire_defences` (`combat.gd:338`) only auto-picks nearest hostile via `_defence_pick` every 8 ticks and keeps `combat.target_id` while `_defence_target_valid` (in reach). So no manual order exists; no way to pick a target.
- Visualisation: `world_view.gd:251-253` draws every `shot` event as one 2 px yellow line, attacker point to target point, for one frame. Building point = footprint centre on the ground plane (no height offset, unit points are lifted 8 px). 4 shots in 24 ticks = a flicker; the line is short-lived, the same colour for everything, no projectile, no target marker (`world_view.gd:182` only shows a selected unit's target).
- Minimal visual options: (a) keep line but lift the building origin ~20 px and keep it for ~6 ticks (fade); (b) selected building draws a thin line/ring to its current `combat.target_id` (same code as `world_view.gd:182`, one extra branch); (c) small marker (ring) on the target for 8 ticks after each building shot. (b)+(a) is smallest.
- Minimal manual-order change if wanted: allow `building_id` in `attack` (new key, validated in `simulation.gd` as an own, completed, armed building), set `combat.target_id` + a `forced` flag that `_defence_target_valid` already honours in reach; clear when out of reach. Needs same-tick cases (vs destroy, vs power loss) and replay/hash fields. Open: is it worth it (ZH allows it, auto-acquire already covers most use); persistence rule when out of reach (clear vs wait).

### 3. Battery damage

- Retail `PatriotMissileWeapon` (weapon.ini:1939): PrimaryDamage 30, PrimaryDamageRadius 5, ScatterRadiusVsInfantry 10, AttackRange 225, DamageType EXPLOSION, WeaponSpeed 1 (locomotor), `RadiusDamageAffects = ALLIES ENEMIES NEUTRALS`, DelayBetweenShots 250, ClipSize 4, ClipReloadTime 2000, RequestAssistRange 200. `PatriotMissileAssistWeapon` (:1996): 25 dmg, radius 5, range 450, delay 250, clip 4, reload 1000, fires on a target another Patriot marked. `PatriotMissile` locomotor (locomotor.ini) Speed 400 u/s, Accel 450, TurnRate 300, FuelLifetime 10 s.
- Wargrid `battery` (`definitions/shared.gd:18`): 30 dmg, explosion, range 9.0 cells (225), delay 8 ticks (250 ms = 7.5, ceil), clip 4, reload 60 ticks (2000 ms), primary radius 0.2 cell (5 u), infantry scatter 2/3 cell + blast 0.52. Same values as the primary weapon; the parity probe cadence 8,8,8,60 matches.
- Armor: `HumanArmor`, `TankArmor`, `StructureArmor`, `BaseDefenseArmor`, `HumveeArmor` have no EXPLOSION line, so EXPLOSION = 100 % (BaseDefenseArmor `DEFAULT 100%`). Wargrid `ARMOR[*].explosion = 100` (structure_tough 80, helicopter 50: not checked against `StructureArmorTough`/helicopter armor here). No armor gap.
- Splash: `Weapon.cpp:1462` `m_amount = (dist² <= primaryRadiusSqr) ? primaryDamage : secondaryDamage`, so flat damage inside the radius, none outside (secondary 0); no falloff. Wargrid `_hit(... splash=true)` also applies full weapon.damage to everyone in radius, friends included. Equal.
- Effective damage per shot (both): 30 vs infantry, tanks, buildings (100 %); per clip 120 over a cycle of 24 + 60 = 84 ticks (2.8 s): about 43 DPS single target, same in both.
- Real differences: (1) Wargrid is instant hit; ZH missile flies at 400 u/s (13 u/tick, about 17 ticks at 225 range), so moving vehicles can be missed (ZH uses the victim position/lead; unverified how often) and infantry scatter lands after the move. (2) Assist weapon not modelled: with 2+ Patriots in 200 range ZH adds 25 dmg x4 per clip per helper at 1 s reload (about 70 DPS per helper extra); Wargrid is weaker there. (3) Scatter/blast widths scaled with a 25/15 correction (documented, `shared.gd:22`), not re-measured here.
- Verdict: no INI-value mismatch; Wargrid single battery is equal to ZH on paper and slightly stronger against moving targets (instant hit, never dodged), weaker in clusters (no assist). If the playtest felt too strong, likely causes are instant hit plus no visible projectile, not damage numbers. Unverified: ZH unit HP scale vs Wargrid (hp rows checked at gate 0).
- Recommended: do not change damage. Optional: a projectile delay (hit resolved after distance/13 ticks) is a sim change with replay impact; a cheaper fix is the visual of item 2.
- Open for the user: add assist weapon (post M7)? add flight delay? or keep instant hit and only improve visuals?

## ZH skirmish AI vs defensive structures (2026-11-06)

Question: does real ZH skirmish AI deliberately destroy Patriot batteries before sending waves? Source `~/projects/CnC_Generals_Zero_Hour` @ `0a05454`, tree `GeneralsMD/Code/GameEngine/Source/GameLogic` (below `GL/`). Read-only; no game run.

### What the source confirms

- Enemy player choice only: `GL/AI/AISkirmishPlayer.cpp:485-540` `acquireEnemy`: nearest enemy by distance from own base centre to centre of enemy structure bounds; crippled enemy (no units or no build facility) gets distance `HUGE*0.5`; +500 units penalty if another skirmish AI already targets him (no ganging up), -25 if he targets me. Recomputed every 5 s (`getAiEnemy`, :~560) and only while current enemy is not "in bad shape" (:491-494). It picks a PLAYER, never a structure.
- No attack-wave logic in C++. Skirmish AI is script-driven: team templates and scripts (`SKIRMISH_*` actions, `ScriptActions.cpp:1678-1775` `doTeamFollowSkirmishApproachPath`, :5357 `doSkirmishAttackNearestGroupWithValue`) live in the shipped `SkirmishScripts.scb` / map scripts, binary, NOT in this source tree nor in `INIZH.big`. So wave size, "minimum force", target order per team are UNVERIFIED (scripts not read).
- Team readiness (`AI/AIPlayer.cpp:2753-2830` `checkReadyTeams`): a built team is released when all members are idle at the rally point ("allIdle"), or when any member is idle and the team has an action script, or after 60 s anyway (`timeExpired`, "If 60 seconds passed, start anyway"). This is the only rally-before-attack rule in C++. Team size is the template's unit list (script data), unverified.
- Approach: `doTeamFollowSkirmishApproachPath` takes team centre, finds the closest waypoint on path label `<label><enemyMpStartIndex+1>` (:1715-1722), follows it (as team or individually). So attacks go along per-start-position approach paths toward the enemy base, not to a specific building.
- Per-unit target pick (`AI/AI.cpp:586-730` `AI::findClosestEnemy`): unless `ATTACK_BUILDINGS` is passed, buildings are rejected ("never target buildings (unless they can attack)", `PartitionFilterRejectBuildings`, :~600, :648). So ARMED structures (Patriot, bunkers) are always valid targets for hunting units; unarmed ones are not. Without an `AttackPriorityInfo` set it returns the CLOSEST valid enemy (:688-692). With a set (`AIUpdate::getAttackInfo`, set per team/unit by scripts `ScriptActions.cpp:1223-1260`): priority per ThingTemplate, 0 = never attack; effective priority = priority - floor(dist / `AttackPriorityDistanceModifier`), min 1; ties go to higher raw priority (:700-728). Default modifier 100 units (`data\ini\default\aidata.ini`: "AttackPriorityDistanceModifier = 100.0 ;The distance required to reduce attack priority by 1"). Priority sets are script data (`ScriptEngine.cpp:146-218`, `getAttackInfo` :6538), not INI: which ZH sets rank defences is UNVERIFIED.
- Hunt state (`AI/AIStates.cpp:7160-7210`): scan every `ENEMY_SCAN_RATE` for `findClosestEnemy(owner, 9999, CAN_ATTACK, info)` with `AttackUsesLineOfSight=Yes`/`AttackIgnoreInsignificantBuildings=Yes` in aidata.ini; falls back to no-priority hunt when `getUnitsShouldHunt()`. Teams with `m_attackCommonTarget` (template flag, `Common/RTS/Team.cpp:724`) share one victim (`AIStates.cpp:7180-7200`).
- Auto-acquire by AI players: `Object/PartitionManager.cpp:4955-4975`: `m_acquireEnemies` (AI controlled) accepts any enemy; `KINDOF_FS_BASE_DEFENSE` is "Don't reject base defenses" for others.
- `KINDOF_FS_BASE_DEFENSE` / `TECH_BASE_DEFENSE` are used for AI target VALUE only in `AIPlayer.cpp:1288-1345` `getPlayerSuperweaponValue` (superweapon aim: defences and combat units count NEGATIVE when `includeMilitaryUnits` is false, i.e. the AI avoids dropping a superweapon on defended spots). No code scouts for the nearest defence or sends a dedicated defence-clearing force.
- AI building defences: `AISkirmishPlayer.cpp:566-705` `buildAIBaseDefense(Structure)`: front/flank placement ring, +150 units (`SkirmishBaseDefenseExtraDistance`).

### Verdict on the user's claim

Not found in source. C++ gives: pick nearest enemy player, run teams along approach paths, each unit hunts the closest (or script-prioritised) valid enemy, armed structures included. Any "clear the Patriots first" behaviour would come from script attack-priority sets or team scripts in the .scb, which were not read. The observed feel (waves, not trickle) is consistent with the 60 s / allIdle rally gate plus team templates of fixed size, but that is inference, not confirmed.

### Wargrid today (`game/scripts/simulation/skirmish.gd`)

- `ATTACK_TICK 5400` (3 min): after it, every tick-30 decision sends EVERY idle unit (guard mode, no target) individually to `_pick` (:172): first category with any enemy, closest within category: builders, producers, supply receivers, power. Armed non-producer buildings (battery) are NOT in any category, so a unit never chooses a battery; it only fights it when auto-acquire fires on arrival. Units are sent as they become idle, so production trickles in one by one: no wave size, no rally, no regroup. `_defend` only reacts to intruders within `DEFENCE_RADIUS` 10 cells of own buildings.
- Gap vs ZH: (1) no rally/release gate; (2) no armed-structure targeting; (3) no per-unit distance-weighted priority; (4) no player-level enemy selection (fine for 1v1).

### Proposal (smallest rule set to approximate; not a ZH-confirmed number set)

1. Wave gate (ZH `checkReadyTeams` analogue): bot gathers new combat units at a rally point near own base; releases the wave when count >= N (suggest 8, tunable) OR 60 s (1800 ticks) since the wave's first unit, whichever first. Idle units after release join the next wave. This replaces trickling.
2. Targeting (ZH `findClosestEnemy` + priority-minus-distance): replace category order by a score `priority - floor(dist / 100 units = 4 cells)`, min 1, ties to higher priority. Suggested priorities: armed defences (battery) 3 within the path to base, producers 3, builders/supply 2, power 1. Simplest: "any armed enemy structure within ~12 cells of the wave centre is the wave's target before the base categories".
3. Keep per-wave shared target (ZH `m_attackCommonTarget`): all wave units attack the same target id, re-picked when it dies.
4. No scouting, no dedicated siege unit (ZH has none in C++). Optional: do not launch a wave into a lone battery with fewer than the minimum, which rule 1 already covers.

Unverified: ZH wave sizes, script attack-priority sets, whether scripts retarget defences first. To close: decode `SkirmishScripts.scb` from the retail install (not done; outside INIZH.big). Checked on tree `m7-factions` @ `8f95d93`; no tests run (docs only).

## ZH skirmish scripts decoded (2026-11-06)

Closes the "Unverified" line above. Facts below are read from the shipped scripts; "guess" marks anything else. Source of the format: `~/projects/CnC_Generals_Zero_Hour` @ `0a05454`, `GeneralsMD/Code/GameEngine/Source/Common/System/DataChunk.cpp` (table of contents, then chunks `id u32, version u16, size i32`, little-endian), `GameLogic/ScriptEngine/Scripts.cpp` (`ScriptList/ScriptGroup/Script/OrCondition/Condition/ScriptAction/Parameter` readers) and `GameLogic/Map/SidesList.cpp` (`ScriptsPlayers`, `ScriptTeams` dict chunks). No EA text is copied here: only script/team identifiers and numbers.

- **Where**: loose file in the extracted install, not inside a `.big`: `~/CnC/run/Command & Conquer Generals - Zero Hour/Data/Scripts/SkirmishScripts.scb` (2,272,629 bytes, sha256 `8f93862b751f289b052206b87170cc840044cb66660fbf6ae30d5782c1d73776`). `Data/Scripts/Scripts.ini` (action/condition UI names) is not needed: action and condition names are stored in the file. The base-game and `ZH_Generals/` copies are identical to each other (`9eedadc0d8d9...`) and differ from this one; not decoded. `MultiplayerScripts.scb` (10 KB) not read.
- **Decoder**: throwaway `python3 -I` script in the session scratchpad (not in the repo). 14 player lists (empty, `SkirmishAmerica`, `SkirmishChina`, `SkirmishGLA`, 9 generals variants, civilian), about 4,300 scripts and 1,340 team templates, all parsed with no leftover bytes. Raw output stays in the scratchpad.
- **Reading rules** (verified in source): script `delay=N` = re-evaluate every N seconds (30 logic fps, random 0-2 s offset); `COUNTER`/`PLAYER_HAS_CREDITS` operand order is `value cmp counter` for credits (so `1200 < money` means "money above 1200"); `SET_TIMER` is frames, `SET_MILLISECOND_TIMER` is seconds; script flags E/N/H say which difficulty runs it.
- **Structure**: the AI is a counter `_ESCALATION` plus a counter `_ATTACK_WAVE`. Escalation rises by 1 every 10 s (Normal, Hard) or 20 s (Easy) ("USA Time Escalation - N/H/E"); building a Tech Center-type building (`Tech Center` list) adds +10/+20/+30 (E/N/H) and any enemy `Super Weapons` building adds +30 (N) / +50 (H), so the AI speeds up when the enemy techs. A "Wave n Set" script advances `_ATTACK_WAVE` at an escalation threshold; the matching "Execute" script (repeats every `delay` s while that wave is current) raises flag `_LAUNCH_ATTACK` for 1 frame; waiting wave teams react to the flag. The three factions use identical thresholds (checked USA, China, GLA).

### Wave timing (confirmed from scripts, same for USA, China, GLA)

| Difficulty | Escalation per | Wave n starts at escalation (= seconds) | Execute re-eval delay | First launch window |
|---|---|---|---|---|
| Easy | 20 s | 15 (300 s), 50 (1000 s), 100 (2000 s); 3 waves | 210 s | 300-510 s |
| Normal | 10 s | 15 (150 s), 50 (500 s), 75 (750 s), 100 (1000 s); 4 waves | 90 s, 90, 60, 60 | 150-240 s |
| Hard | 10 s | 1 (10 s), 15 (150 s), 25 (250 s), 40 (400 s), 60 (600 s); 5 waves | 30 s, 30, 30, 45, 40 | 10-40 s |

Waves repeat: while a wave number is current, every Execute tick relaunches whatever wave teams are standing at the outer perimeter; destroyed teams are re-queued ("CT - Buildable", `teamProductionPriority` 100-150 for wave teams).

### Wave sizes (confirmed: `ScriptTeams` min-max counts; per team; several teams per wave)

`teamInitialIdleFrames` is a build timeout (`AIPlayer.cpp:3514` `isBuildTimeExpired`): after that many frames (1000 = 33 s, 3000 = 100 s) the team is released with at least its minimum counts. "x-y" below = min-max. Wave teams are produced only once the wave's condition holds (`_USA_1ST_WAVE_N` etc.: Normal escalation >= 5/20/50/80 for waves 1-4; Easy needs a Barracks + escalation >= 5/40/100; Hard needs the `_ALLOW_BUILD` flag and wave number).

- USA Normal: W1 3 Ranger + 3 Humvee (two teams, +1 Sentry Drone & 2 Ranger combat-zone guard); W2 4 Missile Defender + 1 Humvee, 2 Crusader + 1 Paladin + 1 Humvee, 2 Comanche; W3 4 Missile Defender + 1 Humvee, 4 Paladin, 2 Tomahawk, 2 Comanche; W4 6 Missile Defender + 2 Sentry Drone + 2 Humvee, 2-4 Paladin + 2 Avenger, 3 Tomahawk + 1 Microwave tank, 2 Comanche. Roughly 6, 9, 12, 20+ units.
- USA Hard: W1 "Rush" 4 Missile Defender + 2 Crusader (its onCreate is "Attack Hunt": no rally, hunts when built) plus 2 Humvee "Supply Hunters" (priority set `USA Supply Lines Priority`, via the Back path) plus 2 Humvee guard; W2 2 Humvee + 4 MD, 4 Crusader + 1 Humvee, 2 Comanche, 2 Raptor; W3 0-4 Paladin, 0-4 Crusader, 0-2 Raptor, 0-2 Comanche, 0-2 Stealth Fighter; W4 two groups of 0-4 Paladin + 0-1 Avenger, 2x 0-1 Tomahawk, Colonel Burton (Commando raid via the Backdoor path), air; W5 three groups of 2-4 Paladin + Microwave + Avenger, three Tomahawk groups of 0-2, 2-4 Aurora, Burton. Up to about 30-40 units per launch by W5.
- Easy: W1 3 Ranger (USA) / 4 Red Guard (China) / 4 Rebel (GLA); W2 about 5 units; W3 about 6 units.
- China Normal: W1 4 Red Guard + (1 Gattling Tank + 2 Battlemaster); W2 3 Gattling, 2 Battlemaster + ECM + Gattling, 2 MiG; W3 4 Battlemaster, 2 Inferno Cannon, 2 Gattling + ECM, 2 MiG; W4 2-4 Battlemaster + 2 Overlord, 3 Inferno + ECM, 2 Gattling + 2 ECM, 2 MiG. Hard: W1 3 Battlemaster + 2 Hunter + 2 Red Guard; W2 0-5 Battlemaster, 2 Gattling; W3 two groups of 0-5 Battlemaster, 0-4 MiG; W4 0-4 Battlemaster + 0-1 Overlord (x2), Nuke Launcher, Black Lotus; W5 Battlemaster/Overlord/ECM groups, 3 Dragon Tank, 2 Helix, Nuke Launchers (0-2 x3), Black Lotus.
- GLA Normal: W1 2 Scorpion + 2 Tunnel Defender, 4 Scorpion + 2 Quad Cannon; W2 6 Scorpion, 4 Scorpion + 2 Technical + Quad Cannon; W3 2 Quad + 5 Scorpion, 6 Scorpion, 2 Rocket Buggy; W4 2 Quad + 6 Scorpion, 2-8 Scorpion + 2 Quad, 3 Rocket Buggy. Hard: W1 3 Scorpion + Quad, 2 Quad hunters; W2 4 Scorpion + Technical + 5 Tunnel Defender, 0-8 Scorpion; W3-W5 up to 4 instances of 0-8 Scorpion groups, 8 Tunnel Defender + Battle Bus, Scud Launchers, Combat Bike suicide units, Saboteur, Jarmen Kell, Bomb Trucks, Angry Mob.
- Team names above were abbreviated by stripping type prefixes in the table pass; exact unit ids are in the scratchpad dump (`teams.txt`).

### Targeting (confirmed)

- Engine rule (`AI.cpp:683-720` `findClosestEnemy`): a candidate's score is `priority - floor(distance / AttackPriorityDistanceModifier)`, minimum 1; priority 0 is never attacked; ties go to the higher raw priority. The modifier value lives in AIData (not re-read here; the note above assumes 100 units).
- Default set for every Normal/Hard team of all three factions: the `<Faction> Tank Priority` set, applied to the player-team (`<Faction> Default Priority` scripts). Numbers: Spy 30, Tanks 29, **Base Defenses 29**, Artillery 29, Utility (dozers, radar van) 29, Vehicle 28, Anti-Air Vehicle 28, Power 27, Supply Lines (collector units) 27, Tech Center 27, Infantry 27, Base Factories 27, Super Weapons 27, Base Buildings (command centre) 26. Unlisted types default to priority 1 (`ATTACK_PRIORITY_DEFAULT`).
- So defences rank at the top with tanks and artillery, above infantry and every production, power or command building; one Patriot in range beats the Barracks behind it, and 4 cells of extra distance cost 1 point (guess for the divisor).
- Other sets: Infantry teams: Spy 30, Infantry/Artillery/Base Defenses/Tanks/Anti-Air/Vehicle 28, Utility 27, Power/Factories/Super Weapons 20, Command centre 19. Rocket infantry: Tanks 30, AA and Aircraft 29, Base Defenses 28, Supply 28, Utility 27, Power 27. Air: AA and Aircraft 30, Artillery 29, Supply 28, Tanks 25, Power 24, Factories 23, Buildings 22. Stealth air: Base Defenses 30, Power 29, Supply 29. Supply-raid teams: USA Supply Lines 600 / Supply buildings 500 / Tech Buildings 100 / Power 35 (China and GLA: 150 / 148). Power-raid (Aurora): Power 150 (China 32). Tech capture and Raider (dozer hunt): 5000 for `Tech Buildings` / `Utility`. Saboteur: Super Weapons 30, Power 29, Factories 28.
- **Easy** uses `Easy Priority` instead: Base Defenses 45, Tanks 42, Infantry/Spy/AA/Vehicle 40, everything else 1, `Tech Buildings` 0. Easy therefore attacks defences and armies first and only drifts to production when nothing else is near; it never captures tech buildings.
- Objects per list (confirmed): `Base Defenses` = Patriot Battery, Fire Base, Gattling Cannon, Bunker, Stinger Site, Tunnel Network (all three factions' lists contain all of them, plus each general variant); `Artillery` = Tomahawk, Inferno Cannon, Nuke Launcher, Rocket Buggy, Scud Launcher; `Super Weapons` = Particle Cannon Uplink, Nuclear Missile Silo, Scud Storm; `Base Factories` = Barracks, War Factory, Airfield, Arms Dealer; `Base Buildings` = Command Center (and palace/demo trap for GLA); `Supply Lines` = Chinook, Supply Truck, Hacker, Worker.
- Wave teams do not clear defences first by script; they walk the approach path (`SKIRMISH_FOLLOW_APPROACH_PATH` Center/Flank/Backdoor, from the perimeter, `TEAM_HUNT` at the end) and the priority rule above picks Patriots when they come into range. Most wave teams share one target (`teamAttackCommonTarget` is set on many, not on the main wave teams: those hunt individually).

### Rally and launch (confirmed from scripts; C++ release rule from the section above)

- Wave teams are created then `Guard` the own outer perimeter (`USA Guard Base`, `Guard Base Outer`, area `[Skirmish]MyOuterPerimeter`); a hook script fires when `_LAUNCH_ATTACK` is set and the team is inside that area at least partly; no count gate beyond the team's own minimum counts. Hard "Rush" and Supply Hunter teams skip the guard and hunt at once.
- Approach path per team: Center, Flank or Back; later waves are split across all three (e.g. Hard W4/W5 have F, B, C copies).
- Reaction to attackers: `_INVASION_ALERT` flag when enemy unit value in `MyOuterPerimeter` >= 1600 (clears when 0); response teams "Alert Invasion Tanks/Infantry/Light Vehicles" trigger on >= 3 enemy tanks (or AA vehicles) or >= 5 infantry in `MyInnerPerimeter` (up to 5 instances of 0-2 rocket infantry, priority 1000, so they pre-empt production), waves in the base switch to `Base Invaded Hunt` (stop, then hunt). Combat-zone guards run to the outer perimeter and become recruitable when enemy value in the combat zone >= 5000; they hunt when own value in the enemy inner perimeter >= 2000.
- Retreat: no scripted retreat for waves. Transports are left at <25% health; `teamDestroyedThreshold` 0.75-1.0 governs when a team counts as dead and is rebuilt (guess for exact semantics).

### Differences from Wargrid's bot (`game/scripts/simulation/skirmish.gd`)

Wargrid: fixed `ATTACK_TICK 5400` (3 min), then every idle unit individually to the nearest of builders, producers, supply receivers, power; no armed-structure targeting; no wave composition. ZH: time-escalated waves (Normal first launch 150-240 s, Hard 10-40 s, Easy 300+ s), fixed compositions, priority-minus-distance targeting with defences at the top, Hard cheats with resources (below). Wargrid's pre-launch category order is also inverted: ZH production buildings rank below defences, tanks and utility.

### Proposed minimal rule set for Wargrid (numbers labelled)

1. Wave table per difficulty: Normal launches at 150 s, 500 s, 750 s, 1000 s (confirmed); Hard 10 s, 150 s, 250 s, 400 s, 600 s (confirmed); Easy 300 s, 1000 s, 2000 s (confirmed). Convert to ticks at Wargrid's tick rate. Guess: first Normal launch uses the middle of the 150-240 s window, so use 195 s.
2. Wave composition: unit counts per wave from the lists above scaled to Wargrid's roster (Normal W1 about 6 units, W2 about 9, W3 about 12, W4 about 20; confirmed raw numbers, scaling is a guess). Minimum-count release: launch what exists at the timer (confirmed rule: team released at build timeout with at least its minimum).
3. Targeting: score `priority - floor(distance / 4 cells)`, min 1 (priority numbers confirmed, divisor a guess carried over from the section above). Use the Tank set: defences/tanks/artillery/builders 29, vehicles/AA 28, power/supply/infantry/factories 27, command centre 26. Easy bot: defences 45, tanks 42, infantry/vehicles 40, rest 1.
4. Defence build rule for the bot (confirmed shape): first defence after escalation >= 10 (100 s Normal/Hard) when credits > 1200 and a supply centre plus war factory exist; second (flank) at >= 20 (200 s); Hard adds Patriots up to 6 and Fire Bases up to 4 more at >= 40-60 (400-600 s) when credits > 6000-8000 and enemy tech/superweapon grows. Defences are placed on a ring around the base towards approach paths (`AISkirmishPlayer.cpp:566-705`).
5. Invasion alert: enemy value >= 1600 inside the outer perimeter (value = unit cost sum, confirmed) switches all guarding teams to hunt (confirmed).
6. Hard bonus money (confirmed numbers): +10,000 at 50 s, +10,000 at 200 s, +15,000 at 400 s, +20,000 at 750 s (escalation 5/20/40/75), plus 2,200 once for all difficulties; Hard also gets free credits on each Supply Drop (+2,500 each, up to 4), Particle Cannon (+5,000), expansion (+4,000); China Hard gets +2,000 / +4,000 / +5,000 / +7,000 on Gattling / Propaganda Center / Internet Center / Nuke Silo, GLA Hard +1,000..6,000 on tunnels, palace, black markets, Scud Storm. Decide whether Wargrid's Hard cheats this way (user choice; nothing of this is needed for M7 gate 2/3).

## ZH skirmish scripts: other findings for later (2026-11-06)

Compact reference for the user's request. Escalation unit = 10 s on Normal/Hard, 20 s on Easy. "Confirmed" = read from `SkirmishScripts.scb` (USA list unless noted; China and GLA lists have the same structure). Gate/milestone column is a suggestion, not a plan change.

| Topic | What the scripts do | Status | Use at |
|---|---|---|---|
| Build order, USA Normal | `SKIRMISH_BUILD_BUILDING` chain: Power Plant at once (+ Advanced Control Rods upgrade) -> Supply Center (`AI_PLAYER_BUILD_SUPPLY_CENTER`, min source value 10,000) and Barracks after the plant -> War Factory after the supply center -> first defence (Patriot via `BUILD_BASE_DEFENSE_FRONT`) and Fire Base at escalation >= 10 with credits > 1200 -> Airfield at >= 10 with credits >= 2500 -> 2nd defence (flank) at >= 20 -> Strategy Center at >= 30 -> 2nd Power Plant at >= 35 (or 200) -> Supply Drop Zone with credits >= 3000 (second after the first) -> Particle Cannon at >= 100 with credits >= 6000 | confirmed | bot rewrite (post-M7), gate 2 USA reference |
| Build order, USA Hard | Barracks at once; 1st Power Plant with 2 dozers; Supply Center, War Factory after; 2nd War Factory with credits >= 6000; Airfield at >= 10; Patriot "Inner Pat" at >= 35; Strategy Center at >= 30; power plants 2-6 by power ratio below 120% or by escalation (50, 150); each Supply Drop is paid +2,500; with credits >= 30,000 it builds a 2nd War Factory and defences on the flank | confirmed | same |
| Build order, USA Easy | like Normal but 1st defence at >= 10 only after supply center and war factory, no Airfield, 2nd Power Plant at >= 35/200, Strategy Center at >= 40, Particle Cannon at >= 180 | confirmed | easy-bot rules |
| Build order, China | Power Plant -> Supply Center + Barracks -> War Factory -> defences at >= 10 and >= 20 -> Airfield (>= 10, credits >= 2500) -> Propaganda Center at >= 30 -> 2nd Power Plant at >= 35 -> Internet Center (credits >= 3000) -> Nuke Silo at >= 100 (Normal), >= 75 (Hard) with credits >= 6000. Hard adds Bunkers, up to 6 Gattling Cannons then more at >= 40, and 4 Speaker Towers at >= 40 | confirmed | gate 2 (China bot) |
| Build order, GLA | Supply Stash and Barracks at once -> Arms Dealer after the stash -> defences / Tunnel Networks at >= 10 and >= 20 -> Palace at >= 30 -> Black Market (credits >= 3000, twice) -> Scud Storm at >= 100 (Normal), >= 75 (Hard). Hard: 3 Arms Dealers, Tunnels after the barracks, Stinger Sites, 4 Black Markets | confirmed | gate 3 (FRC bot, closest analogue: GLA tunnel/stash style; guess) |
| Power rules | build another Power Plant when power ratio < 120% and no invasion alert and >= 2 (3, 4...) plants; emergency timer 60 s when power is out; "Additional Power Plants" placed at the front when power is out with >= 4-6 plants | confirmed | bot power rule |
| Supply / collectors | Number of collectors is not scripted: engine (`AIPlayer`) trains them per supply center; scripts only pick expansion sites: `AI_PLAYER_BUILD_SUPPLY_CENTER` with min source value 10,000 (home) / 25,000 (expansion). Expansion check every 7 s: enemy has >= 2 supply-line buildings and I have <= 1, or credits >= 7000 with >= 3 and escalation >= 25, or credits >= 12,000 with >= 5 and escalation >= 60; then +4,000 free credits (Normal and Hard), a new supply center plus Patriots near it, a dozer replacement, and a 15 s/600 s/150 s timer before the next check | confirmed (collector count: not decoded) | economy bot |
| Tech-up conditions | Strategy Center / Propaganda Center / Palace need the war factory and escalation >= 30; upgrades are gated on money and buildings (USA: TOW at 2 Humvees + 1500, Composite Armor + Sentry Gun at the Strategy Center + 2000, Advanced Training after Composite Armor + 2500; Chemical Suits only vs GLA with 2000; Laser Missiles at 3 Raptors; Bunker Busters at 2 Stealth Fighters; MOAB with Strategy Center + 4000, Hard) | confirmed | gate 2/3 upgrade lists |
| Defence behaviour | AI builds its own defences (USA Patriot + Fire Base; China Gattling + Bunker; GLA Stinger + Tunnel) on a ring facing the approach paths; Fire Bases get 3 Missile Defender + 1 Ranger garrison squads (Hard, escalation >= 20); 24 garrison squads (P1-P8 x B1-B3) enter map-placed neutral buildings from escalation >= 30 (Normal/Hard) while no invasion alert; no repair or rebuild script found (rebuilding is by the same one-shot build scripts and dozer replacement at credits >= 1000 with < 2 dozers; Hard also at >= 20,000 / 40,000 credits) | confirmed (repair: none found, not decoded in engine) | bot defence rules |
| Base-defence reaction | see "Reaction to attackers" above; also "Guard CZ from Artillery": Comanche guard teams switch to the combat zone when enemy artillery is there and back after | confirmed | gate 2 |
| Harassment / specials | Colonel Burton commando raid via the Backdoor path with the demo-charge ability (Hard W4/W5); Pathfinder/Sentry Drone scouts (priority 50 set); Comanche guards; Hard air waves (Raptor, Stealth Fighter, Aurora); China Black Lotus (W4/W5) and Helix; GLA suicide Combat Bikes, Saboteurs, Bomb Trucks, Angry Mob, Jarmen Kell (Hard W4/W5); Tech Capture teams (2 Ranger, 6 Ranger + 4 Crusader + 2 Humvee "Big") send infantry to capture oil derricks etc. with priority 5000 once a tech building is within 500 of the inner perimeter | confirmed | gate 2/3 optional specials |
| Superweapons and powers | Normal: fires Particle Cannon at once when ready (`SKIRMISH_FIRE_SPECIAL_POWER_AT_MOST_COST` picks the most valuable target); Hard waits for `_LAUNCH_ATTACK`. Same pattern for Daisy Cutter, Spectre Gunship, Spy Satellite; Battle plan Hold-the-Line used at once when a Strategy Center exists. Generals variants (`SkirmishAmericaAirForceGeneral` etc.) have their own lists | confirmed | gate 2/3 power use |
| Difficulty summary | Easy: slower escalation (20 s), 3 waves, 210 s relaunch, Easy priority set, no expansion, no tech capture, no Airfield, no garrisons. Normal: 4 waves, expansion, garrisons. Hard: 5 waves, starts at 10 s, relaunch 30-45 s, ~55,000 bonus credits by 750 s, extra war factories, extra defences | confirmed | difficulty setting |
| Retreat / regroup | No retreat scripts for attack waves; alert and combat-zone rules as above; `Leave Transports` at <25% health | confirmed | |
| Scouting | No scout team; Pathfinder/Sentry Drone priority set only. Waves choose the approach path by start position (`Center/Flank/Backdoor<start+1>`) | confirmed | |
| Per-faction mix (M7 lists) | USA: Ranger, Missile Defender, Humvee, Crusader, Paladin, Tomahawk, Avenger, Microwave, Comanche, Raptor, Stealth Fighter, Aurora, Burton, Pathfinder, Sentry Drone. China: Red Guard, Hunter, Gattling Tank, Battlemaster, Overlord, Inferno Cannon, Nuke Launcher, ECM, MiG, Helix, Dragon Tank, Black Lotus, Troop Crawler, Listening Outpost. GLA: Rebel, Tunnel Defender (RPG), Scorpion, Quad Cannon, Technical, Rocket Buggy, Scud Launcher, Battle Bus, Bomb Truck, Combat Bike terrorist, Saboteur, Jarmen Kell, Angry Mob, Radar Van | confirmed | gates 2 and 3 |

### Could not decode or not checked

- Engine-side rules: collector count per supply center, repair behaviour, `AttackPriorityDistanceModifier` actual value (AIData in the INI set; the root `INIZH.big` `AIData.ini` is a 66-byte stub, the real file was not located), the base-defence template per side (`m_baseDefenseStructure1`), and whether `teamDestroyedThreshold` triggers retreat.
- The nine generals variants (lists 4-12), the Generals base-game and `ZH_Generals` copies, and `MultiplayerScripts.scb` were not read; the USA/China/GLA base lists were.
- Unit counts in the wave table are team templates, not measured battle sizes: how many actually arrive depends on money and build timeouts. No play test or parity-harness run backs this section.
- Checked on tree `m7-factions` @ `9573103`; decoder run once over the whole file; docs only, no game tests run.

## Bot wave update (2026-11-06, user decision: small Pareto improvement, Zero Hour a baseline not a parity goal; the real bot is M8)

Tree: m7-factions 06f570e + uncommitted. `game/scripts/simulation/skirmish.gd`, tests `test_skirmish_waves.gd` (W1-W5, T1-T5, each seen red on the old bot by mutation) plus edited D2/D3/A3/TB1.

- Rule 1, waves: before `ATTACK_TICK` nothing changes. After it, idle armed units walk to the seat's `start.cell` (existing map data; `RALLY_RADIUS` 6 cells). A wave is released when `WAVE_MIN` units idle at the rally, or `WAVE_TIMEOUT` ticks passed since the first unit stood there. Units that arrive later form the next wave. State lives on the sim object (`set_meta`), per seat, not in the snapshot.
- Rule 2, one score: priority minus `floor(distance / 4 cells)`, min 1, highest wins, ties to the lowest id. Priorities come from capability data, no kind or faction ids: armed building 29; vehicle class and builders 28; infantry, receives_supply, power > 0, any other producer 27; building that produces a builder (the HQ) 26; the rest 1.
- Rule 3, one target per wave, re-picked from the wave's centre when it dies or becomes invalid; idle members are re-sent every decision. A wave with no enemy left is dropped.
- Numbers: priorities 29/28/27/26 are from the decoded Normal Tank set (confirmed). Guesses: the 4-cell divisor (ZH 100 units, assumed 25 units per cell), `WAVE_TIMEOUT` 1800 (ZH `checkReadyTeams` 60 s), `RALLY_RADIUS` 6, and `WAVE_MIN`. `WAVE_MIN` 8 (the starting value) leaves the 6-seat team match unfinished at the 45000 cap (ended tick 54974, winner team 2); scratch runs with other values, same tree: 6 / 1800 won 33204 team 1, 8 / 900 won 39370 team 1, 10 / 1200 won 36521 team 2, 5 / 900 won 61243, 12 / 1800 won 59970, 5 / 1800 not done by 65000. The outcome is chaotic in the constant, not monotone; 6 was chosen as the one that keeps the old 60 s timeout and ends inside the cap. S1 with 8: 8384, with 6: 9473 (both window, winner 1).
- Probe (scratch script, not tracked; 10 riflemen behind 3 batteries and 2 power plants, human does nothing else, bot seat 2 on the skirmish map, 30000 ticks): new bot killed 2 of 3 batteries (ticks 6990 and 18989), made 120 combat units, 112 died, no win in 30000 ticks, human riflemen all alive. Old bot at the same ticks: 0 batteries killed, 123 made, 123 died, no win. So the bot now deals with batteries but pays about 55 units per battery.
- The bot still never builds `usa_defence` (user ruling kept).

## CI evidence at gate 1 (2026-11-06)

- Run 42292961869 on 3a31be0: Linux and Windows Godot jobs failed on `BM5 transports: 20 full cars against 100 riflemen` in the exported suite only. Cause: `combat_workload.gd` `_transports()` spawned the 100 enemy riflemen inside `assert(...)`, which exported release builds strip. Fixed in f44f081 (spawn bound to a variable first); the local headless run never failed because asserts are active there. No other call inside an `assert` in game scripts, benchmarks or tests (searched).
- Run 42295509369 on f44f081: all jobs green, including compare-replays. `sh tools/compare_local_traces.sh 42295509369` on macOS: REPLAYS MATCHED for replay, economy, combat (1200 each), team (100) and netplay (278).

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

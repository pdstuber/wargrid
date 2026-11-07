# M7 verification archive: Gate 3 (FRC, G3.x records, review fixes, lean cuts, ultrareview, parity harness, rendered rerun)

Moved verbatim from [m7-verification.md](m7-verification.md).

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

## Gate 3 lean cuts (2026-11-07, tree: m7-factions 385671c plus uncommitted, Apple M6)

Behaviour identical; 3 files, 7 lines added, 6 removed.
1. `rebuild_holes.gd` l.6: unused `Production` preload deleted (nothing in the file or tests reaches it through this file).
2. `containers.gd`: `static func held(sim, host) -> int` extracted; `_free_slots` and `_walk` call it.
3. `definitions/definitions.gd` `can_rally`: typed local `produces` replaces the twice-evaluated `row.get("produces", [])`.
4. Skipped: `Salvage.step` second `is_empty()` check is not redundant, the filter between the two checks can empty `_crates`.
Checks on this tree: suite 460 / 134,967 / 0, exit 0, TESTS PASSED (134,974 with traces on, equal to the 385671c `git archive` run); lint, warnings (100 files) pass; replay, economy, combat and team traces `cmp`-identical to that archive run. Python checks, netplay, benchmarks not rerun (no tooling, relay or tick-cost change).

## Ultrareview fixes (2026-11-07, tree: m7-factions 8eac2cf plus uncommitted, Apple M6)

Baseline at start: 460 cases / 134,967 / 0, exit 0. Every fix has a test seen red first (scratch runner for one case, then the full suite).

| Finding | Verdict | Test (red seen) | Changed |
|---|---|---|---|
| F1 `_result_text` showed Defeat in `setup` | right | `test_match_hud_and_restart` K4 setup check (FAIL before) | `skirmish_main.gd` |
| F2 group command rejected for one boarded member | right; plan line 461 ("Any other command naming a passenger: Unit is inside a transport") does not say a mixed group is rejected whole, CT7 and RH10 (single member) still hold: all-passenger or all-hole groups keep their old error | `test_group_move_skips_passengers`, `test_group_move_skips_late_boarder` (delayed command, member boards before due) | `simulation.gd` (`_commandable`, used in `_validate` and at apply) |
| F3 box select / right-click returned passengers | right | `test_passengers_not_pickable` (View V10) | `world_view.gd` `pick_entities`, `pick_target` |
| F4 mixed air/ground pile deadlock | right | `test_mixed_waiters_do_not_deadlock` (Gd9; nobody loaded in 5 ticks before) | `supply_collection.gd` `_ahead`: air first by id, then ground (waiters by wait tick, arrivals by id); one total order. Only mixed air+ground piles change |
| F5 Salvage skipped when the lower-id killer died in the volley | right | `test_crate_drops_when_killer_dies_same_volley` (Sv9) | `combat.gd` (killer rows captured before removal), `salvage.gd` (`on_death` takes the row) |
| F6 retaliation targeted passengers | right | `test_retaliation_targets_carrier` (CT10: guards that have not noticed the car; 90000 of 180000 passenger HP lost before) | `combat.gd` (`_retaliate_trigger` targets the carrier, `fire` uses `valid_target`) |
| F9 stale scout car DEPARTURE | right | `test_scout_car_weapon_is_compared` (red against old script) | `tools/check_reference.py` (`scout_gun` -> `HumveeGun`, `COMANCHE_VULCAN` -> `rapid_fire`, departure removed), `dump_definitions.gd`, test |
| F7 bot meta on throwaway SeatSim | right | `test_bot_state_survives_seat_wrapper` (SK20) | `seat_sim.gd` (`simulation()`), `skirmish.gd` `_bot` unwraps |
| F8 unknown `--faction` | right | `test_headless_client_rejects_unknown_faction` (SK21); real run: exit 2, "Unknown --faction 'gla'; expected one of: usa, china, frc" | `headless_client.gd` |
| F10 | left: `fire_defences` never calls Salvage, so the duplicated pipeline needed no change | | |

F9 against the real archive (`~/CnC` tarball, pinned hash): `usa_light_vehicle weapon` and the six `scout_gun` rows match HumveeGun. The check still reports FAILED 80 rows / 2 differ: `rifle delay_ticks` 3 vs 4 and `rifle reload_ticks` 21 vs 22 (present before these fixes, not touched here).

Traces and pins: replay, economy, combat and team traces `cmp`-identical to a `git archive` run of 8eac2cf (suite 468 / 134,999 with traces on vs 460 / 134,974 at HEAD). No pin moved. F4 and F7 changed nothing in the pinned runs. Netplay: all nine `run_netplay.sh` scenarios PASSED, `match` terminal tick 8331 unchanged by F7 (inside the S1 window 7000-17999). `run_team_match.sh` exit 0, `TEAM MATCH cap tick=45000 winner=null units_peak=171`. Lint, warnings (100 files), `run_python_checks.sh`, unittest discover (59) pass. Not run: benchmarks, conformance, any window, CI.

Cherry-pick of 2bcc92c (terrain in a cached child node, from `spike-more-maps`) onto `m7-factions` as a1dfb03 (HEAD 741bfda): three keep-both conflicts resolved; the commit's test used the pre-M7 building kind `reactor`, changed to `usa_power_plant` (uncommitted, in `test_view.gd`).
Tree with fix: suite 469 / 134,999, 0 failures, `TESTS PASSED 134999`, exit 0 (741bfda: 468 / 134,999); lint and warnings (101 files) pass; replay, economy, combat and team traces `cmp`-identical to a `git archive` run of 741bfda. Not run: benchmarks, rendered check, conformance, CI.

## Parity harness improvements (2026-11-07, tree: m7-factions e2807e3 plus uncommitted, Apple M-series, Python only)

Plan: [parity-harness-improvements](parity-harness-improvements.md) steps 1-6; the fork was not touched. Ports 4300+ (another agent's game held 4100).

- Changed: `tools/zh_parity/parity.py` (uncapped loop verified as default, per-lane `GEN_USER_DATA`, own process group + cleanup on boot failure, port pre-check, `step()` deadline, names/globs validated up front, atomic trace writes, meta `schema/seed/side/fps_cap/fork/wargrid`, sweep runner `--repeats/--lanes/--timeout/--retries/--list/--kill/--smoke`, `batch=` and `collect_truck_6_b*` deleted), `tools/zh_parity/analyze.py` (`--json`, pooled n/median/min/max/spread, `--report md`, `--same`, `ACCEPTED` verdict, `move_*` Wargrid speeds read from the definition files: `move_scout` is now 60, not 75), new `tools/test_zh_parity.py` (22 tests, red then green; also a CI line), the harness doc and `m7-supply-parity-measured.md` harness note.
- Checks: `sh tools/run_python_checks.sh` passes; `python3 -m unittest discover -s tools` 81 tests OK; `analyze.py --self-test` OK.
- Smoke: `parity.py --smoke` printed `smoke OK 3.5 s` (top speed 30.04, start delay 3).
- Sweeps (scratch dir, not git): 12 jobs (2 reps x 6 scenarios) on 3 lanes in 16 s; rerun launched 0 jobs; killing a game mid-run retried and succeeded; `--kill DIR` left none of that sweep's processes; a second run on a held port failed fast. A fresh `move_crusader` equals the old capped trace under `--same`.
- Supply proof: `collect_truck_u1625` x3 uncapped, pooled 1288.2 credits/min against the measured 1294 (-0.45 %, spread 4.7 %); `collect_truck_6` x3 pooled 1351.1. 6 jobs took 40 s on 3 lanes against about 7 min per capped run before.
- Throughput: 6 `collect_truck_6` jobs took 35 s on 3 lanes and 30 s on 6, so lanes are capped at 6 and the default is cpus/2 (at most 6).
- Waits for the user: fork changes F1 (spawn completes structures like map objects), F2 (`GEN_AUTO_SEED`, Zero Hour faction names) and F3 (idle wait and `pid` in `/healthz`); `probe_patriot.py` deletion; the Wargrid supply script (`wg_supply2.gd`) is still scratch-only; `--wargrid` joins only a JSON file for `collect_*` rows; range/reach `accepted` values are not filled in (mechanism only).

## Rendered rerun (2026-11-07, tree: main 3b6b9f1, Apple M6)

Rendered `movement_benchmark.tscn` passed on HEAD and on two earlier trees (741bfda, b7c9ae3): `RENDERED BENCHMARK PASSED 3`, exit 0, frame p95 under 16.7 ms everywhere. The tick p95 on open and dense is about 10 ms on HEAD (and on b7c9ae3 dense) against about 3 ms before the terrain cache (741bfda); the medians are unchanged. Single runs, cause unexplained, the terrain cache is the suspect; no rendered tick gate; recorded in the ledger. User decision: record and push, the performance spike profiles it. This completes the rendered-rerun item of the exit gate; CI, `compare_local_traces.sh` and the user's playtest are still pending.

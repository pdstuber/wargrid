# M6 verification

Plan: [M6 plan](../superpowers/plans/2026-11-05-m6-teams-full-map.md). Run rules: [milestone prompt](../milestone-prompt.md).

```text
Resume record (updated 2026-11-05, after Task 6)
Branch / base commit / working-tree state: m6-teams-map / eabaa63 / Task 6 committed on top
Last green task / next incomplete task: Task 6 / Task 7 (gate review follows Task 7)
Changed paths since last commit: none
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh, 242 cases, 104,617 checks, 0 failures, exit 0, TESTS PASSED; netplay match/kill/stall/silent/spike/perturb/version all passed
Known red case or blocker: none. Pending: test_maps_load in the CI export job (Review Focus 1); team-*.tsv CI comparison unrun until CI
Approved decisions, pre-authorizations used, deferred gates: as before; local commit per milestone prompt; no push/PR/merge/window/BM6 re-pin without approval
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: start Task 7 (tank splash); baseline 242 cases / 104,617 checks
```

## Task 0: baseline (2026-11-05, tree 9ea11bc + Task 0 test)

- Base tree `9ea11bc`: `sh tools/run_tests.sh` exit 0, `CASES 221 CHECKS 104553 FAILURES 0`, matches the latest record.
- Pins at base:

  | Pin | File | Value |
  |---|---|---|
  | `TERMINAL_TICK` | `test_skirmish_match.gd` | 9938 (winner 1) |
  | netplay s1 end tick | `tools/run_netplay.sh` | 8423 |
  | `PINNED` | `test_state_hash.gd` | `15df35ca15bcc43b` |
  | BM6 ceiling / floor | `test_benchmark.gd` | 15500 / 13000 |
  | `S1_CORE_SERIES` (new) | `test_skirmish_match.gd` | 1224646555515136482 |

- Move gap `g`: infantry at (5,5), `move` to (10,5) issued at tick 0: the first snapshot after one `step()` (tick 1) already shows `moving` and a changed position. `g = 1`, so the plan's start-delay rule (+2) yields the measured 3.

## Task 1: risk spike and source values (2026-11-05, tree 781ab5a, scratch only)

Baseline on `781ab5a`: `sh tools/run_tests.sh` exit 0, `CASES 222 CHECKS 104554 FAILURES 0`, `TESTS PASSED 104554`. `game/` and `tools/` unchanged; probes ran in a scratch copy of `game/` (session scratchpad `t1/`) with `GridNavigation`'s `≤ 64` size assert removed. Sources: fork `eb595cfc9`, CnC_Modding_Support `3aad8e4`, root `INIZH.big` (pinned hash, `load_archive`). Source detail in the [evidence note](m6-map-and-feel.md).

### Values table

One cell = 25 units, one tick = 1/30 s. Damage in Wargrid's ×1000 HP units.

| Name | Wargrid value | Zero Hour value | INI file / block |
|---|---|---|---|
| `radius.infantry` | 0.28 | CYLINDER r 7 → 7 | `object/americainfantry.ini` / Object AmericaInfantryRanger |
| `radius.tank` | 0.7211102550927978 | BOX 15 × 10 → √325 = 18.028 | `object/americavehicle.ini` / Object AmericaTankCrusader |
| `radius.builder` | 0.7211102550927978 | BOX 15 × 10 → 18.028 | `object/americavehicle.ini` / Object AmericaVehicleDozer |
| `radius.vehicle` | 0.6260990336999411 | BOX 14 × 7 → √245 = 15.652 | `object/americavehicle.ini` / Object AmericaVehicleHumvee |
| `radius.collector` | 0.835224520712844 | BOX 20 × 6 → √436 = 20.881 | `object/americaair.ini` / Object AmericaVehicleChinook |
| `accel.infantry` / `brake.infantry` | 4.0 / 4.0 | 100 / 100 u/s² | `locomotor.ini` / Locomotor BasicHumanLocomotor |
| `accel.tank` / `brake.tank` | 40.0 / 40.0 | 1000 / 1000 u/s² | `locomotor.ini` / Locomotor CrusaderLocomotor |
| `accel.builder` / `brake.builder` | 1.2 / 2.0 | 30 / 50 u/s² | `locomotor.ini` / Locomotor AmericaVehicleDozerLocomotor |
| `accel.vehicle` / `brake.vehicle` | 40.0 / 40.0 | 1000 / 1000 u/s² | `locomotor.ini` / Locomotor HumveeLocomotor |
| `accel.collector` / `brake.collector` | 2.4 / 4.0 (unused: air stays instant) | 60 / 100 u/s² | `locomotor.ini` / Locomotor ChinookLocomotor |
| `turn.infantry` | 500 °/s | 500 | BasicHumanLocomotor `TurnRate` |
| `turn.tank` | 180 °/s | 180 | CrusaderLocomotor `TurnRate` |
| `turn.builder` | 90 °/s | 90 | AmericaVehicleDozerLocomotor `TurnRate` |
| `turn.vehicle` | 180 °/s | 180 | HumveeLocomotor `TurnRate` |
| `turn.collector` | 180 °/s (unused) | 180 | ChinookLocomotor `TurnRate` |
| `min_turn_speed.vehicle` | 0.8 cells/s | 20 u/s | HumveeLocomotor `MinTurnSpeed` |
| `min_turn_speed.builder` | 1.0 cells/s | 25 u/s | AmericaVehicleDozerLocomotor `MinTurnSpeed` |
| `cannon.primary_radius` | 0.2 | 5.0 | `weapon.ini` / Weapon CrusaderTankGun `PrimaryDamageRadius` |
| `cannon.secondary_radius` | 0 | unset (default 0, `Weapon.cpp` 258) | Weapon CrusaderTankGun (no field) |
| `cannon.primary_damage` | 60000 | 60.0 | Weapon CrusaderTankGun `PrimaryDamage` |
| `cannon.secondary_damage` | 0 | unset (default 0) | Weapon CrusaderTankGun (no field) |
| `cannon.affects` | allies, enemies, neutrals | `ALLIES ENEMIES NEUTRALS` | Weapon CrusaderTankGun `RadiusDamageAffects` |
| `boxes.SupplyDock` | 400 | 400 (no map override on any of the 12 docks) | `object/civilianbuilding.ini` / Object SupplyDock, SupplyWarehouseDockUpdate `StartingBoxes` |
| `box_value` | 75 (already hard-coded, `supply_collection.gd`) | 75 | `gamedata.ini` / GameData `ValuePerSupplyBox` |

Cross-checks: the measured stationary maxima follow from the real geometry: Ranger vs Dozer 97.5 + 7 + 18.03 = 122.5 (measured 122, 123 needs a move); Crusader vs Dozer 147.5 + 18.03 + 18.03 = 183.6 (measured 183). Task 9's rule with these rates gives the first move of a 180° order at turn 10 (Ranger, 16.67°/tick, legs), turn 23 (Crusader, 6°/tick, treads factor > 0 below 45°) and the end of the start delay (Dozer, wheels), against measured 11, 24 and 3: all within ±1 (hand arithmetic; Task 9's test is the check).

Turning question for Task 9 (design question for the user, raised by the gate review): the plan differs from the source twice. (1) Legs: the plan's factor is 1 only within one tick's turn, else 0; `moveTowardsPositionLegs` uses treads' ramp `1 − min(error / 45°, 1)` ([evidence](m6-map-and-feel.md#locomotor)). (2) Order: the plan turns first and computes the factor from the error after the turn; the source computes the error before the frame's turn (legs: `stdAngleDiff` at `Locomotor.cpp` 1649 before `locoUpdate_moveTowardsAngle` at 1650; treads: `rotateTowardsPosition` returns the pre-rotation `relAngle`, 1178). With the source order and the ramp for both, first move = smallest k with 180 − step × (k − 1) < 45: Ranger 10, Crusader 24 (measured 11, 24). The plan's rules give 10 and 23. Both fit ±1; the source rule needs no legs departure. Not verified: whether Zero Hour moves the unit in the same frame the force is applied (one frame later would give 11 and 25).

### Splash finding (design question for the user)

INI-faithful splash barely exists on Wargrid's grid. `CrusaderTankGun` has only `PrimaryDamageRadius = 5`, no secondary. With the plan's rule (victim when `centre distance − r_victim ≤ 0.2`), a neighbour is hit only when its centre is within 0.48 cells (infantry) or 0.92 cells (tank, builder) of the target's centre. Destination allocation gives one ground unit per cell, so neighbours stand ≥ 1 cell apart and are hit only in passing. The 9 splash hits the parity spike measured come from **scatter**, which the plan does not model: against infantry the shell aims at a random point up to `ScatterRadiusVsInfantry = 10` units off (`Weapon.cpp` 959–1001, launched at the point, not the unit, 1133–1136), and the spike's Rangers stood 15 units apart, not 25. Options: (a) keep the plan (INI values, no scatter): splash is code with almost no effect; (b) add seeded scatter against infantry (randomness in the sim, design change); (c) another rule the user picks. User picked (b) on 2026-11-05. Follow-up found before writing it into the plan: scatter alone still gives no neighbour hits here. The impact lands at most 0.4 cells from the target, so a neighbour one cell away is at least 0.6 cells from it, beyond the 0.48-cell reach (0.2 + 0.28). The measured hits need both scatter and Zero Hour's 15-unit infantry spacing; Wargrid allocates one unit per 25-unit cell. Asked the user again; on 2026-11-05 the user chose scaled scatter: only against infantry targets, scatter 2/3 cell and blast 0.52 cell (Zero Hour's 10-unit scatter and 12-unit reach × 25/15, less the 7-unit Ranger radius). Monte Carlo on a 5-infantry row: Zero Hour geometry 0.361 neighbour hits per shell (measured 0.30), Wargrid with INI values 0.000, scaled 0.359. Resolved in plan Task 7. **Former blocker before Task 7 (resolved by the amendment):** with `secondary_radius` 0, Task 7 as written contradicts itself: its invariant names victims "within the secondary radius", `test_splash_event_flag` names secondary victims, and `test_splash_cluster` at 0.6-cell spacing gets zero hits (0.6 > 0.48), while the design promises that tank shells splash and lists "splash killing an ally and an enemy in one tick".

### Map decode (scratch `decode.py`, `resample.py`)

- Chunk versions: HeightMapData 4, BlendTileData 8, ObjectsList 3, PolygonTriggers 4. Samples 630 × 630, border 70, one boundary 486 × 469 samples = 4860 × 4690 units → **194 × 187 cells** (partial last row/column dropped). Grid row index = world y (a vertical mirror of the Zero Hour view; no cell changes). **Plan correction needed before Task 3:** `test_maps_load` says "196×196 ±4 per side (exact size from Task 1)"; 187 is 9 under 196, so the test must assert exactly 194 × 187.
- Starts (world units → cell): 1 (536.7, 3187.9) → (21, 127); 2 (1733.3, 4204.7) → (69, 168); 3 (3195.9, 4102.6) → (127, 164); 4 (4361.3, 3126.1) → (174, 125); 5 (4426.3, 1630.5) → (177, 65); 6 (3095.3, 538.7) → (123, 21); 7 (1752.5, 538.8) → (70, 21); 8 (460.3, 1679.0) → (18, 67). All on open cells.
- Objects: 81 waypoints, 141 ambient sound objects (16 templates), 18 DirtRoad, 4 KandaharBridge, 12 SupplyDock, 8 TechOilDerrick, 1 TechOilRefinery, 1 TechReinforcementPad, 1 QuonsetHut01, 2 WoodTower, 320 trees (TreeDogwood1/3/4/8), 7 rock clusters, 36 Rocks1–3Brown.
- Supply: each start has one dock 19.8–24.2 cells away (Euclidean); four corner docks are 54–63 cells from the nearest start. The 1v1's builder-to-source distance is about 10 cells. Chebyshev start → dock centre, for Task 2's ≤ 20 rule (gate review arithmetic): 15, 16, 19, 16, 17, 16, 14, 17 for starts 1–8; start 3 has a 1-cell margin.
- Water: 17 polygon triggers, **none** water or river.
- Cliff share 10.16 % of playable samples; at the 50 % rule 3,669 of 36,278 cells (10.11 %) blocked.
- Routes (4-neighbour, open cells): all 28 start pairs connected. Narrowest bottleneck clearance per pair (width `2t − 1` is a Chebyshev lower bound; a diagonal corridor can be narrower across): 3 (≥ 5 cells wide) for every pair touching start 7 or 8 except 7–8 itself; 4 (≥ 7 cells) for most others; 1–2: 6; 7–8: 7. All 32,609 open cells form one component, so no route depends on the four bridges.
- ASCII preview: scratch `t1/preview.txt` (194 × 187, `S` dock, `B` bridge, `o` derrick, digits = starts); the scratchpad is temporary, Task 2's converter regenerates it.
- Structures (`object/factionbuilding.ini`), against Wargrid's half-footprint-diagonal rule (approved design): Barracks BOX 55 × 45 → 71.1 u = 2.84 cells (Wargrid 2 × 2: 1.41); PowerPlant 22 × 30 → 37.2 u = 1.49 (1.41); SupplyCenter 44 × 45 → 62.9 u = 2.52 (3 × 3: 2.12); WarFactory 53 × 60 → 80.1 u = 3.20 (2.12). Barracks and factory get 1.4 and 1.1 cells less edge range against them than in Zero Hour (listed in Departures).
- Speeds are in [Zero Hour verification](zero-hour-verification.md); the legacy `vehicle` keeps 3.0 cells/s (Humvee 2.4), so its wheel factor is max(0.8, 3.0/4)/3.0 = 0.267, not 0.333.

### Costs on Ashfall's blocked cells (194 × 187, scratch `cost_probe.gd`, Apple M6, Godot 4.7.2, headless)

Recurring per-tick work is compared with the sim p95 budget (1.67 ms), per-event spikes with p99 (3.3 ms), snapshot with plumbing (0.83 ms); see the [ledger](performance.md).

| Cost | p50 (max) ms | Share | Ratio | Named candidate fix |
|---|---|---|---|---|
| `GridNavigation.new` (each building preview/placement/death) | 65.1 (65.7) | p99 3.3 | **20×** | incremental navigation around the changed footprint (structure: needs approval) |
| `route` start 1 → 4 / 1 → 2 | 0.149 / 0.008 | p95 1.67 | 0.09× | none needed |
| `Allocation.assign`, 40 units, target at start 4 | 84.8 (85.7) | p99 3.3 | **26×** | bound candidates to cells near the target (ring search) instead of the whole 32,609-cell component |
| `snapshot()`, 246 entities | 0.743 (1.012); 0.466 of it is the terrain lists (48 × 32 empty: 0.002) | plumbing 0.83 | 0.9× per call, 5.4× for six bots | one snapshot per decision tick shared by all bots, or drop the static blocked-cell lists from each copy |
| 6 × `Skirmish.issue_opponent`, opening tick (6 build orders), issue time only | 419.6 (421.6) | p99 3.3 | **127×** | dominated by six `preview_build` navigation builds: same fix as navigation. The due build's `Construction.place` builds the grid again, so the real cost is at least twice this |
| 6 × `issue_opponent`, attack tick (240 units, no credits) | 8.85 (8.94) | p99 3.3 | **2.7×** | shared snapshot (about 4.5 ms of it) |
| `StateHash.digest` | 0.208 (0.216) | lockstep p99 0.55 | 0.4× | none needed |
| `step()` after the six attack orders (gate review rerun, 300 ticks; p50 / p95 / p99 / max 0.720 / 7.361 / 9.085 / 12.939) | p95 7.36, p99 9.09 | p95 1.67, p99 3.3 | **4.4×, 2.75×** | spikes every 8 ticks (0, 8, 16, …): `Combat._approach` sets `repath_tick = tick + REPATH_TICKS` with no stagger (`combat.gd` 151), so every chaser repaths on one tick; the guard path staggers by id (`combat.gd` 79). Candidate: stagger the chase repath by unit id the same way (no new structure; changes traces) |

Every cost over twice its share has a named candidate fix (the `step()` one named after the gate review found it), so no Task 1 stop; the fixes belong to Task 11 after the 3v3 measurement. Hostility in the probe was today's `owner !=` (six seats free-for-all), an upper bound: each bot scans five seats' objects instead of three. The snapshot probe added no supply sources (dead code in `cost_probe.gd`); the allocation probe passed no unavailable cells (negligible).

### Gate review (2026-11-05, fresh-context Opus, uncommitted docs on `781ab5a`)

Reviewer reran the suite (222 / 104,554 / 0), the decode, resample, cost and determinism probes, and checked every Values row against INI. Findings and rulings:
- C1 `step()` row misreported (p50 vs p95, unnamed spike): fixed above.
- I1 turning order and legs rule: accepted, rewritten as a Task 9 design question.
- I2 structure geometry and speeds unrecorded: added above and to Departures.
- I3 Ashfall size breaks Task 3's window: recorded as a plan correction needed.
- I4 splash: recorded as a blocker before Task 7.
- Minor: 3D damage distance labelled in the evidence note; free-for-all upper bound, probe gaps, issue-time label, Chebyshev supply distances, preview lifetime, y orientation and width bound recorded. M7 (accel/brake share a row) ruled cosmetic: each value still has its own name and cell.
- No new tests in Task 1, so the "production change that makes each test fail" rule does not apply.

### Determinism probe (scratch `det_probe.gd`)

- Plan polynomial `angle_between` against `atan2` over 36,000 directions: worst error 0.000095°.
- 10,000 rotations from `[1, 0]` by literal steps (`cos`/`sin` of 500/30, 6 and 3 degrees, 17 digits from Python: 0.9579895123154889 / 0.28680323271109026, 0.99452189536827329 / 0.10452846326765347, 0.99862953475457383 / 0.052335956242943835), normalized with `sqrt`: final headings `Vector2(0.9730449, -0.23061587)`, `Vector2(-0.4999999, -0.86602545)`, `Vector2(-0.49999988, 0.86602545)`; drift 1.1e-7°, 5.7e-6°, 7.2e-6° against `10000 × step mod 360`.
- `Vector2` is single precision in this Godot build: a heading kept in `Vector2` carries about 1e-7 error. Task 8's "within 1e-9" speed check and any heading arithmetic that must match float64 should use `float` scalars, not `Vector2`. Cross-platform comparison is Task 9's CI.

## Departures and deferrals

- Zero Hour's one-cell cliff dilation is not copied.
- Trees, civilian and tech buildings are not converted.
- The Crusader first-frame acceleration lurch is not copied.
- Turrets and turn-to-aim are deferred; firing ignores heading.
- Air (collector) movement is unchanged.
- Ranger cadence 4/4/22 was measured on the source build (VC6 unverified).
- Wheels follow the route instead of arcing or reversing.
- Halts by `stop` and attack-move engagement stay instant (no braking).
- Production exits spawn with heading `[1, 0]`, not facing out of the door.
- Splash against infantry: scatter and blast scaled by 25/15 for Wargrid's spacing (2/3 and 0.52 cells instead of 0.4 and 0.2); vehicle and building targets keep the INI 0.2-cell blast and no scatter.
- Building bounding radius from Wargrid's footprint, not Zero Hour's geometry: barracks 1.41 vs 2.84 cells, factory 2.12 vs 3.20, depot 2.12 vs 2.52, reactor 1.41 vs 1.49.

## Task 2: map converter and Ashfall data (2026-11-05, tree 9ea11bc + Task 2)

`python3 tools/zh_map/test_zh_map.py`: 10 tests OK. Converter run on the real map (`convert.py <map> game/data/maps/ashfall.json`, 2.7 s): 194 x 187, 3,669 blocked cells, 0 water, 8 starts (cells as in Task 1), 12 sources of 400 boxes, every start has all four slots and a source within Chebyshev 20, all 28 pairs connected. Rulings: lost-route/slot/supply checks run in the order slots, supply (per seat), then routes; `notice` text carries EA's copyright line "Copyright 2025 Electronic Arts Inc." as used in its source headers (the map file itself has none); water is a cell centre inside a water polygon (none on this map); report-only tables below, no tolerance.

Route lengths in world units, source grid (10-unit samples) vs resampled (25-unit cells): ratio 0.989 to 1.011 for all 28 pairs (full table: re-run the converter; e.g. 1-2 1622.5 vs 1624.6, 1-4 4194.5 vs 4156.4, 5-6 1785.6 vs 1805.6, 6-7 1340.0 vs 1325.0).

Route widths (Chebyshev clearance t, width >= 2t - 1 cells) for each start and its two nearest starts: 1-2 6, 1-8 3, 2-3 4, 3-4 4, 4-5 4, 5-6 4, 6-7 3, 7-8 7.

Start metrics (resampled routes in world units; buildable = open cells in the 25 x 25 window): every start 625 buildable. Supply Chebyshev distance to the nearest source origin: seats 1-8 = 16, 17, 18, 15, 18, 16, 15, 18. Route length to the nearest other start: 1-2 1625, 2-3 1491, 3-4 1579, 5-6 1806, 6-7 1325, 7-8 1776 (full rows in the converter output). Task 5 picks `TeamMatch.SEATS` with these in view.

## Task 3: map loader (2026-11-05, tree 34a8081 + Task 3)

`sh tools/run_tests.sh`: 228 cases, 104,570 checks, 0 failures (+3 cases, +8 checks from `test_map.gd` vs 225 / 104,562). S1 core series pin unchanged. Rulings: `MapData.load` pushes an error on a bad file, but the red test uses `MapData.parse` (no push) because the runner treats any `ERROR:` line as failure. Converter bug found by the loader's bounds check: the Ashfall source at the south-east edge had origin (188, 185), whose 3x3 footprint ended outside the 187-row map. Converter now clamps source origins into the map (test `test_edge_source_stays_inside_map`); that source is now (188, 184). `SeatSim` forwards `map_data()` so lockstep bots keep working. Unused `Skirmish.SIZE` removed.

## Task 4: seats, teams, team victory (2026-11-05)

- `test_teams.gd` adds 5 cases / 22 checks. Suite 233 cases, 104,592 checks, 0 failures; nine netplay scenarios pass.
- Re-pin: `test_state_hash.gd` / `H1 pinned digest` / `15df35ca15bcc43b` → `5fd6ce7215bcc43b` / Task 4 (snapshot `players[].team`, `players[].alive`).
- Ruling: bots read team from `state.players` (`Skirmish._hostile`), not `Combat.hostile`, because `SeatSim` has no `team_of`.
- Ruling: `add_player` team 0 means "default to seat id" (the plan's `team` ≥ 1 default).
- Gap: `_retaliate_trigger`'s non-hostile-attacker skip is only reachable by friendly fire (Task 7); it is untested until then.
- Gate review (Opus, 505a4ee): no Critical. I1 (winner = team id untested) and I2 (duplicate-seat check vacuous) fixed by `test_winner_is_team_id` and `[1, 1, 2]` in TM9; M1 (`alive` cost in the per-tick rate path) fixed by computing `alive` only in `snapshot()`.
- Gap (I3): the bot team filter (`Skirmish._hostile`) has no test until Task 5's 3v3. Minor M2 (defensive hostility checks in `fire`/`plan` unreachable today) and M3 (world_view right-click on allies; presentation out of scope) noted, not fixed.

## Task 5: bots on Ashfall and the 3v3 harness (2026-11-05, tree 4a37e56 + Task 5)

- `TeamMatch.SEATS` (`game/scripts/debug/team_match.gd`): team 1 = seats 1, 2, 8 (starts (21,127), (69,168), (18,67)); team 2 = seats 4, 5, 6 (starts (174,125), (177,65), (123,21)). Ashfall seats 3 and 7 unused.
- `sh tools/run_team_match.sh` on current mechanics (baseline row, no gate): `TEAM MATCH won tick=19541 winner=1 units_peak=326`; step+bot time per tick p50 1.312 ms, p95 11.129 ms, p99 25.866 ms, max 1052.824 ms (includes the per-tick snapshot the harness takes; cap 27000 not reached).
- Skirmish bot code needed no change: slots and hostile filters were already in place from Tasks 3-4. Mutation check: making `_hostile` ignore teams fails TB1.
- Trace: `WARGRID_TEAM_REPLAY_TRACE` writes 100 rows (tick 0, 30 … 2970); compared with `compare_replays.py --interval 30 --rows 100` in CI and `compare_local_traces.sh`.

## Task 6: edge-to-edge range and Ranger cadence (2026-11-05, tree eabaa63 + Task 6)

- `sh tools/run_tests.sh`: 242 cases, 104,617 checks, 0 failures (+5 cases `test_ranger_fires_at_edge_max`, `test_crusader_fires_at_edge_max`, `test_rifle_cycle_30`, `test_firing_cell_uses_edge`, `test_building_edge_range`). Measured rule outputs: Ranger vs Dozer 4.9011 cells = 122.5 units (measured 122), Crusader vs Dozer 7.3422 = 183.6 (measured 183). Rifle gaps 4, 4, 22.
- Baseline note: the record's 104,606 was a run with `WARGRID_TEAM_REPLAY_TRACE` set (TB3 adds a trace-open check); unset it is 104,605.
- Provisional re-pins (test / assertion / old → new / cause):
  - `test_skirmish_match.gd` / `TERMINAL_TICK` / 9938 → 10368 (winner 1, inside 9000-10799) / Task 6
  - `test_skirmish_match.gd` / `S1_CORE_SERIES` / 1224646555515136482 → 3285391664560676360 / Task 6
  - `tools/run_netplay.sh` / s1 terminal tick / 8423 → 9383 / Task 6 (script logs no winner; winner unverified for netplay s1, S1 skirmish test asserts winner 1)
  - `test_benchmark.gd` / BM6 / ceiling 15500 → 18500, floor 13000 → 16000 (measured 18168) / Task 6; needs user approval at Task 12
  - `PINNED` and R4 unchanged.
- Other assertion changes (geometry encoded centre range): D1 rifle values; R1 outside miss moved to 7.5, R1 building boundary uses the edge maximum; W1/L1 ticks (0,4,8,30,34,38; next fire 30; partial clip 4); G2 enemy at 5 cells; G4 enemy at 5.2 cells (in edge range, an AI guard would no longer approach); A5 decoy at 5.2 cells; A1 asserts `edge_gap <= 3.9`; P2 expected cell [16.5, 9.5], release test spawns the second attacker in the target's row and teleports the first target instead of a move order (a 1-cell move stays inside edge range).
- `run_team_match.sh` after Task 6: `won tick=23162 winner=2 units_peak=316`, step+bot p50 1.692 / p95 11.375 / p99 28.277 ms (baseline row was tick 19541, winner 1); not a gate.
- Design notes: `_nearest(..., edge)` is edge-tested only for the human in-range acquisition; AI scan stays centre-based. `Combat.EDGE_EPS` 1e-6, `RANGE_SLACK` 0.1, `MAX_TARGET_RADIUS` 2.2 (3x3 depot/factory diagonal half is 2.12).

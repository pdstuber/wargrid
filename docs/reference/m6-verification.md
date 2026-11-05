# M6 verification

Plan: [M6 plan](../superpowers/plans/2026-11-05-m6-teams-full-map.md). Run rules: [milestone prompt](../milestone-prompt.md).

```text
Resume record (updated 2026-11-05, after the Task 1 gate)
Branch / base commit / working-tree state: m6-teams-map / 9ea11bc (main) / clean after the Task 1 commit
Last green task / next incomplete task: Task 1 (gate reviewed) / Task 2
Changed paths since last commit: none (Task 1 commit: docs/reference/m6-verification.md, docs/reference/m6-map-and-feel.md)
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh, 222 cases, 104,554 checks, 0 failures, exit 0, TESTS PASSED (tree: 781ab5a, rerun by the gate reviewer with the Task 1 docs)
Known red case or blocker: three user decisions open (Task 1 section): splash rule (blocks Task 7), turning order and legs rule (blocks Task 9), Task 3 map-size assertion (exact 194 x 187, blocks Task 3)
Approved decisions, pre-authorizations used, deferred gates: design approved 2026-11-05; Task 0 and Task 1 local commits and the Task 1 gate review used the milestone pre-authorizations; no push/PR/merge/window/BM6 re-pin without approval
Usage so far (python3 tools/session_usage.py <session files>): Task 1 session 37b12bfa, 50 requests before the review, max context 170,834, output 36,877 (opus)
Next exact action: get the user's answer on the Task 3 size correction (and, before Tasks 7 and 9, the splash and turning questions); then start Task 2 (Sonnet medium session) on this branch
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

INI-faithful splash barely exists on Wargrid's grid. `CrusaderTankGun` has only `PrimaryDamageRadius = 5`, no secondary. With the plan's rule (victim when `centre distance − r_victim ≤ 0.2`), a neighbour is hit only when its centre is within 0.48 cells (infantry) or 0.92 cells (tank, builder) of the target's centre. Destination allocation gives one ground unit per cell, so neighbours stand ≥ 1 cell apart and are hit only in passing. The 9 splash hits the parity spike measured come from **scatter**, which the plan does not model: against infantry the shell aims at a random point up to `ScatterRadiusVsInfantry = 10` units off (`Weapon.cpp` 959–1001, launched at the point, not the unit, 1133–1136), and the spike's Rangers stood 15 units apart, not 25. Options: (a) keep the plan (INI values, no scatter): splash is code with almost no effect; (b) add seeded scatter against infantry (randomness in the sim, design change); (c) another rule the user picks. Not decided here. **Blocker before Task 7:** with `secondary_radius` 0, Task 7 as written contradicts itself: its invariant names victims "within the secondary radius", `test_splash_event_flag` names secondary victims, and `test_splash_cluster` at 0.6-cell spacing gets zero hits (0.6 > 0.48), while the design promises that tank shells splash and lists "splash killing an ally and an enemy in one tick".

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
- Building bounding radius from Wargrid's footprint, not Zero Hour's geometry: barracks 1.41 vs 2.84 cells, factory 2.12 vs 3.20, depot 2.12 vs 2.52, reactor 1.41 vs 1.49.

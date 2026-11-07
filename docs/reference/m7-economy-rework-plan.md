# M7 economy-parity rework: decision record and plan (2026-11-07)

Status: decided by the planning agent (Opus, user away, design decisions delegated); nothing implemented. **[Revision 2 at the end supersedes the parts marked "superseded" below: the end split of rule 3, the provisional values and predictions, the Task 0 stop rule, and the task list.]** Base tree: `m7-factions` b7c9ae3 plus the uncommitted playtest-fix tree (4x5 pile, `supply_clearance` 1, `BUILD_EDGE_MARGIN` 1, moved map piles and fixtures, 6 moved pins not yet re-pinned; see [m7-verification](m7-verification.md) "Playtest findings"). Labels: **measured** (ZH source build, [m7-supply-parity-measured](m7-supply-parity-measured.md), single runs), **Wargrid scratch** (headless `wg_supply.gd` on the playtest tree), **derived** (arithmetic here), **unverified**.

Target (user): one collector's credits/min within 5 % of measured Zero Hour, every faction, at 6, 12, 30 cells and at the closest legal gap. 30 ticks = 30 frames per second; rate = 1800 x credits per cycle / cycle ticks.

## 1. Root causes

Wargrid's INI-derived numbers are right (box value, capacities, action delays, speeds, truck turn/accel/brake). What Wargrid lacks is time Zero Hour spends that is not in the INI. Measured cycle frames (travel / standing at pile / standing at depot) against Wargrid scratch cycles:

| collector | ZH c-c 6 / 12 / 30 cells (measured) | Wargrid today c-c 6.5 / 12.5 / 30.5 (scratch) | missing per cycle |
|---|---|---|---|
| Worker / laborer | 288.5 (125/85/80), 649 (486/85/79), 30 pending | 167, 527, 1607 | 152 ticks, constant |
| Truck | 409 (171/188/50), 629.5 (392/188/50), 1305.5 (1068/188/50) | 338, 564, 1238 | 86 ticks, constant (89/84/86) |
| Chinook | 651 (290/308/56), 730.5 (356/319/56), 30 pending | 443, 503, 683 | 225 ticks, constant beyond 12 cells |

- **Worker (+122 % at 6 cells).** INI actions are 5 + 5 + 5 frames (150 ms rounds up to 5). ZH stands 165 frames per cycle: 75 frames of dock handling at each end (85 - 10 at the pile, 80 - 5 at the stash), not in the INI and absent in Wargrid. Walk: ZH slope 60.08 frames per cell of c-c distance, Wargrid 60.0 (both 1 cell/s), so speed is right. Geometry: ZH one-way walk = c-c - 98 units (fit of 6 and 12); Wargrid ring-cell centres give c-c - 112.5 (depot dock 2.0 cells and pile dock 2.5 cells from the centres), 35 ticks per cycle less walking, cancelled by Wargrid's own 32 ticks of leg overhead (seek tick, path queue, accel). So 152 = 2 x 75 + 2. At c-c 6 Wargrid's cycle is 137 against 288.5: rate +111 %; the doc's +122 % is the mean of the two bracketing rates (808, 1262), which overstates because rate is 1/cycle.
- **Worker at the closest gap.** Pile and depot rings share the single free column at gap 1, so the laborer docks on one cell for both ends: 18.75 ticks per box, 7200/min against ZH 610 (12x). ZH never shares a spot: boneless dock spots are centre + unit vector x half the major radius (pile 25 units, stash 18 units from the centre), always distinct.
- **Truck (+36 % / +16 %).** Wargrid already has ZH's truck kinematics (90 deg/s turn = `turn_cos` cos 3 deg per tick, accel 240 = 9.6, brake 50 = 2.0). Missing: ZH dock handling 38 frames per end (188 - 150, 50 - 12) plus about 10 of geometry. The same 86 ticks over a longer cycle is why the deviation falls with distance. The measured 30-cell row confirms the slope: (1305.5 - 629.5) / 18 = 37.56 frames per cell vs Wargrid 37.5.
- **Chinook (+48 % / +46 %).** 225 = 36 (Wargrid departs at capacity: 8 x 36 load instead of 9 x 36) + 120 (Wargrid air has no acceleration: ZH air locomotor 150 / accel 60 / brake 100 units, so each leg costs v/2a + v/2b = 1.25 + 0.75 s = 60 frames extra once the leg is at least v²/2a + v²/2b = 300 units = 12 cells; at 6 cells the profile is triangular and costs 10 frames less per cycle, derived) + about 70 of handling, turning (180 deg/s) and lift/landing (derived as the remainder). Measured 6 to 12 cells: +79.5 frames, of which the accel model predicts 70 (derived, consistent).
- **Cell mapping.** Travel time does not depend on the 25 units/cell factor, because distances and speeds are both divided by it. The slopes confirm it: worker 60.08 vs 60.0, truck 37.56 vs 37.5 frames per cell. The mapping only moves fixed geometry (footprints, dock offsets, clearance), which the per-row constant absorbs. Calibration rule: compare frames per cell between two ZH distances of at least 12 cells with 2 x 30 / speed; if a pooled slope differs by more than 2 %, change that row's speed (never the mapping, which also scales every combat range). Today no change is needed.
- **The old formula** was right only for the truck because the truck has little unmodelled handling; for the worker and Chinook the handling and acceleration dominate. Do not size anything from it.

## 2. Design (decided)

One constant per collector row plus one geometry rule; no new keys, no faction ids, integer ticks, no new math.

1. **Distinct dock points (code, `supply_collection.gd` `_arrival`).** A ground collector's arrival point is its dock cell centre moved 0.25 cell per axis toward the target footprint (sign of the clamp of the cell into the footprint minus the cell: -1, 0 or 1). At gap 1 the pile and depot points in the shared column are 0.5 cell apart, as ZH's spots are distinct; at every other gap each leg grows by 0.5 cell, which the per-row constant re-absorbs. Claim, hold and queue rules unchanged; air unchanged. Rejected: skipping the cell the unit stands on (gap 1 then behaves like gap 2, laborer 519/min, -15 %); `supply_clearance` 2 (same rate, and stricter than ZH).
2. **Chinook loads like ground (code deletion).** Remove the two air branches in `step` (load-before-check and the early `boxes <= 0` release): every collector waits (boxes + 1) x `load_ticks`, as ZH does. This is the open M3 shortcut; it is part of this rework (question 5) because the calibration would otherwise fold it into the numbers.
3. **Dock handling folded into `load_ticks` / `unload_ticks` (data).** Held while docked, as ZH's dock handling is part of the docking sequence (unverified for ground, see Task 0). Ground split: half of the constant at each end, as ZH's measured standing excess is equal at both ends (worker 75/75, truck 38/38). Chinook split fixed by the 2-collector row: two Chinooks are pile-bound, so the pile time must be 1800 x 600 / 2790 = 387 frames = 9 x 43; the rest goes to the depot. Each faction file gets one comment line saying these are the INI delay plus measured ZH dock handling, pointing here.

*[Superseded by Revision 2: the ground split "half at each end" and the table values below; the Chinook split stands.]*

Provisional values (Task 3 recomputes them by the closed form, the cycle being linear in both values for one collector):

| row | `load_ticks` | `unload_ticks` | added per cycle | note |
|---|---|---|---|---|
| `frc_builder` | 5 -> 35 (2 x 35 = 70) | 5 -> 67 | +122 | 152 minus 30 for the longer legs of rule 1 |
| `china_collector` | 30 -> 37 (5 x 37 = 185) | 12 -> 44 | +67 | 86 minus 2 x 9.4 for rule 1 |
| `usa_collector` | 36 -> 43 (9 x 43 = 387) | 87 -> 213 | +225 | includes +36 of rule 2 |

Unchanged: speeds, capacities, box value 75, starting money, footprints, `supply_clearance` 1, edge margin 1, all-map source search.

Predicted credits/min (derived; ZH interpolated at the Wargrid c-c with the measured slopes, worker 60.08, truck 37.5, Chinook 13.25 below 12 cells and 10 above):

| row | Wargrid today | Wargrid after | ZH | after vs ZH |
|---|---|---|---|---|
| laborer gap 3 (c-c 6.5) | 808 | 423 | 424 | -0.2 % |
| laborer gap 9 (12.5) | 256 | 199 | 199 | 0.0 % |
| laborer gap 27 (30.5) | 84 | 77 | 77 (30 pending) | +0.1 % |
| laborer gap 1 (closest, 4.5) | 7200 | 675 | 610 (one run; median cycle gives 657) | +10.7 % (+2.7 % vs median) |
| truck gap 3 / 9 / 27 | 1598 / 957 / 436 | 1274 / 831 / 408 | 1263 / 833 / 408 | +0.8 / -0.3 / 0.0 % |
| truck gap 1 | 2880 | about 1550 | pending | unverified |
| Chinook gap 3 / 9 / 27 | 2438 / 2147 / 1581 | 1617 / 1484 / 1189 | 1642 / 1468 / 1180 (30 is the accel model, pending) | -1.6 / +1.0 / +0.8 % |
| Chinook gap 1 | 2553 | 1667 | pending (accel model about 1700) | unverified |
| 2 Chinooks, gap 9 | 3743 | 2791 | 2790 | 0.0 % |

The laborer's mid-range rows fit by construction (one constant, three points). The laborer gap-1 row is the weak one: whole-cell docking with one constant gives ZH's linear walk curve at c-c 4.5 (cycle 200), while ZH's own closest run sits on a handling floor (205.5 median, 221.5 mean, 231.5 in a second run at an overlapping spot). Repeats decide (Task 0); no other rule tried gets closer (shared cell +29 %, own-cell skip -15 %).

## 3. Minimum depot-to-pile distance

ZH rule (source-read, [m7-placement-rules](m7-placement-rules.md)): `SupplyBuildBorder` 20 units between footprints, same value for every depot. As centre-to-centre along the pile's 50-unit half-extent: USA Supply Center (half 44) 114 units = 4.56 cells, China (BOX 52 x 47, half 52) 122 = 4.88 cells, GLA stash (half 36) 106 = 4.24 cells. The API accepted the stash at 90 units (3.6 cells), below the rule, so the API path probably skips the border check or the half-extent reading is off (unverified; a first scan even placed it at 30 units, overlapping). Wargrid: 3 x 3 depots, gap 1 cell = 25 units >= 20 for all three, c-c 4.5 cells. Decision: `supply_clearance` stays 1 on all three rows, no per-row values: the ZH rule is a gap, Wargrid honours it, and the close-range rate is floor-dominated (ZH 583-610/min at 30-90 units), so the exact minimum barely moves the target. Depot footprints matching ZH (China 4 x 4) are out of scope.

## 4. Sampling noise

The measured rows are single runs of 5 deposits; the worker's closest run has a median and a mean cycle 8 % apart. Rule:
- Task 0 repeats every gate row 3 times with at least 8 deposits, at the Wargrid-representable distances 162.5 / 312.5 / 762.5 units and the closest legal spot. The reference is the pooled rate (all credits after each run's first deposit / all frames between first and last deposit) with the run spread (max - min) / pooled.
- Gate: Wargrid (deterministic, exact) within 5 % of the pooled reference. A row outside 5 % of the pooled value goes to the user even if it lies inside the runs' range; a row whose spread exceeds 10 % gets 3 more runs before anyone decides on it. The 5 % is never widened.
- Until Task 0 finishes, Tasks 1-3 use the interim references in the table above; Task 4 swaps in the pooled ones.

## 5. Who decides

User: any pin leaving its agreed window or outcome (S1 terminal outside 7000-17999 or winner not 1; Cs1 or Fm1 not won inside the cap, a different winner, or an event in their `seen` list no longer happening; team match winner not null at 45000); the `units_peak` pin in `tools/run_team_match.sh` (stress ceiling); any exceeded performance budget (report, never loosen); a parity row outside 5 % after the repeats (the laborer gap-1 row is the expected one); a Task 0 result that breaks a decision (stop conditions below); air acceleration, depot footprints, a different `supply_clearance`; commit, push, merge.

Executing agent alone: the exact tick values by the closed form and split rule above; fixture positions and literal tick values in existing tests when the assertion keeps its meaning; exact re-pins inside agreed windows and outcomes (S1 tick, Cs1/Fm1 terminal ticks, TB3/TB4 digests and series, netplay terminal tick in `tools/run_netplay.sh`), each recorded old -> new with the tree; harness scenario additions and repeat counts.

## 6. Plan

*[Tasks 1-4 superseded by Revision 2 (3); the acceptance gate below still holds with the Revision 2 rows.]*

Model routing per [AGENTS](../../AGENTS.md): implementation on Sonnet, the gate review on Opus. Intermediate tasks may report GREEN with the pin cases listed as "known moved" in the resume record (the playtest tree is already 6 pins red); Task 4 re-pins once against the final tree. Task 0 runs in the background beside Tasks 1-3.

```text
Task 0: measure the reference rows in ZH (no game code)
Owns: tools/zh_parity/parity.py (scenarios at 162.5/312.5/762.5 units, _0 for chinook and truck,
      deposits >= 8, worker x4), tools/zh_parity/analyze.py (pooled rate, spread),
      docs/reference/m7-supply-parity-measured.md
Invariant: always -headless -noaudio; traces only in scratch; nothing copied from EA into the repo
Boundary: chinook/truck _0 died with "buildObjectNow failed" at frame 13 (r5): order the depot only
          after the builder has existed a frame, as the other scenarios do
Red: analyze.py self-test case for the pooled rate over two runs (fails before the change)
Green: self-test, sh tools/run_python_checks.sh; table rows for 3 x {worker, truck, chinook} x
       {162.5, 312.5, 762.5, closest}, chinook x2 at 312.5, worker x4 at 162.5
Stop: chinook pooled cycle at 762.5 outside 915 +- 5 % (the constant model fails, air acceleration
      needed: design change); worker x4 at 162.5 >= 3.6 x one worker (dock handling is not held,
      the fold in rule 3 is wrong for ground) [SUPERSEDED, Revision 2 (1): the line was miscomputed;
      a held pile caps 4 workers at cycle / pile hold = 3.66x, so 3.66x confirms the fold];
      any pooled slope off by > 2 % (section 1 rule)
[Task 0 done 2026-11-07: pooled rows in m7-supply-parity-measured.md; closest-legal rows dropped,
 worker 762.5 not measurable]

Task 1: red parity suite
Owns: game/tests/test_supply_parity.gd (new), game/tests/run_tests.gd (register)
Invariant: no production change; deterministic; rate defined as in analyze.py
Boundary: layouts depot 3x3 at the west, pile 4x5 east at gaps 1/3/9/27, one collector spawned
          beside the depot and given gather; 2 Chinooks at gap 9; runs long enough for >= 8 deposits
Red: "Ep1-Ep3 <row> gap <g> within 5 % of Zero Hour <ref>/min" for laborer, truck, Chinook at
     gaps 3/9/27 and 1, "Ep4 two Chinooks gap 9 within 5 % of 2790", "Ep5 at gap 1 the laborer's
     pile and depot arrival points are 0.5 cell apart" (all fail today: rates 7200 ... 2553)
Green: n/a (red recorded with the failing values)
Stop: a rate the suite measures differs from the scratch numbers in section 2 by > 2 % (the
      harness and the scratch sim disagree: find out why before Task 2)

Task 2: distinct dock points
Owns: supply_collection.gd _arrival (and one small helper); test_supply.gd fixture positions
Invariant: dock claim, held cells, _ahead order, air paths and all phases unchanged; same-tick
           cases of gather against move, stop, build, salvage and removal of pile, depot or unit
           keep their results (existing Su/Gd/Gt/Lb cases)
Boundary: two laborers in the gap-1 column, one docked at the pile and one at the depot on the
          same cell; corner ring cells (diagonal offset); unit already at the point; pile emptied
          during the half-cell walk; blocked path -> retry
Red: Ep5
Green: Ep5, test_supply, full suite except the known moved pins
Stop: the pathfinder cannot route a move inside one cell (would need a navigation change)

Task 3: cycle calibration
Owns: supply_collection.gd step() (delete the air branches), collects rows and one comment line in
      usa.gd / china.gd / frc.gd, literal ticks in test_supply.gd (Su2 admit/first box/"departs",
      Gt1, Lb1) and any test reading those values
Invariant: (boxes + 1) x load_ticks for every collector; unload once per cycle; box value,
           capacity, speed unchanged; partial loads still take (taken + 1) delays
Boundary: Chinook on a pile emptied by another collector mid-load (now waits its delay, as ZH);
          50-box pile ending a truck load at 2 boxes; laborer interrupted by a build order
Red: Ep1-Ep4
Green: Ep1-Ep4 within 5 % of the interim references (laborer gap 1 reported, see section 2),
       test_supply, full suite except the known moved pins
Stop: one constant per row cannot put the gap 3/9/27 rows within 5 % (the model is wrong)

Task 4: final references, pins, traces, docs
Owns: test_supply_parity.gd references (Task 0 pooled values), pin constants in
      test_skirmish_match.gd, test_team_match.gd, tools/run_netplay.sh, tools/run_team_match.sh;
      docs: m7-verification.md (resume record, evidence rows), m7-supply-parity-measured.md,
      m7-economy-parity.md (pointer: formula superseded by measurement)
Invariant: every pin moves with old (b7c9ae3) -> new recorded; replay trace cmp-identical to a
           git archive run of the base tree (no movement change outside supply)
Boundary: S1 window 7000-17999 winner 1; Cs1 and Fm1 won inside 45000 with their seen events;
          TB3/TB4 digests and series; netplay terminal tick (was 8331, playtest tree 8317);
          team cap result winner null at 45000, units_peak (was 171, playtest tree 175)
Red: the moved pin cases (already red)
Green: full suite, lint, warnings, python checks
Stop: section 5 user list
```

Acceptance gate (all on the final tree, each with the tree recorded): full suite with its marker; `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/run_python_checks.sh`; every parity row within 5 % of the pooled ZH reference or signed off by the user; `sh tools/run_benchmark.sh` with a new ledger row (exceeded budgets reported, accepted until the post-M7 spike, never loosened); replay trace identical to the base; `tools/run_netplay.sh` match, kill, perturb and version scenarios; `sh tools/run_team_match.sh`; one fresh-context Opus gate review (it names, per new test, the production change that makes it fail) and one `/ponytail-review`; then the user's playtest. No rendered rerun needed (no presentation change).

## 7. Unverified and pending

- Measurements still running or failed when this was written: Chinook and worker at 30 cells (r4, running), Chinook and truck closest legal (r5 runs died with "buildObjectNow failed"). Truck 30 arrived during writing: 414/min, cycle 1305.5, used above.
- Chinook 30-cell prediction (915 frames, 1180/min) rests on the acceleration model; a pooled value outside 5 % of it stops Task 0.
- Whether ZH's ground dock handling holds the dock (rule 3 assumes yes); decides how 4+ laborers share a pile, and the FRC bot runs 7. Task 0's worker x4 row decides. [Resolved in Revision 2 (1): held, source-read and measured.]
- The Chinook's folded depot time (213 ticks) makes 4+ Chinooks per depot depot-bound earlier than ZH (derived; bots build none extra). The Chinook also hovers about 7 s at the depot instead of about 3 s.
- The ZH minimum distance for the stash (90 units measured vs 106 by the rule) and the half-extent reading of BOX radii.
- Wargrid scratch numbers are from `wg_supply.gd` in the scratch dir; the gap-2 truck row (276 ticks, 62 ticks per cell to gap 3 instead of 37.5) is unexplained and is not a gate row.

## Revision 2 (2026-11-07, after the pooled measurements)

Status: decided by the Opus decision agent (user away, design delegated); nothing implemented beyond the executing agent's T1/T2. References: pooled ZH rows in [m7-supply-parity-measured](m7-supply-parity-measured.md) (3 runs each). Wargrid numbers marked **scratch-sim** come from a scratch copy of the working tree (T1/T2 applied) with the values below and the air branches deleted, run through `test_supply_parity.gd`'s own `layout` and `rate` (8 deposits per collector after the first); copy and probe in the scratchpad `rev2/`, not in the repo.

### R2.1 Dock model: ZH holds the dock, and so does Wargrid

- **Source-read** (fork `eb595cfc9`, `GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Update/DockUpdate/DockUpdate.cpp`): one `m_activeDocker` per dock. `update()` (line 416) grants it to the first docker whose approach position is reached; `onExitReached` (line 356) clears it. Approach, enter, dock movement, every action delay and the exit move all run under it. The `SupplyDock` is boneless with `NumberApproachPositions -1` (dynamic, unlimited waiting spots; [m7-economy-parity](m7-economy-parity.md) line 33), so waiting is unlimited but service is one at a time. Depots hold the same way. `AIDock.cpp:282`: a waiter gives up after 30 s (900 frames) of waiting for clearance.
- **Measured, consistent with a held pile.** A single-server pile caps n collectors at cycle / hold. Worker: 311 / 85 = 3.66x (measured 3.66x; hold 85 = the 84-frame pile standing). Truck: 651 / 192 = 3.39x (measured 3.39x; standing 188). Chinook x2: 736 / 390 = 1.89x (measured 1.89x). An unheld pile would give about 4.0x for 4 workers. The Task 0 stop line (3.6x) was my arithmetic error: it predicted the held cap wrongly. The finding in the measured note ("dock handling overlaps, not held") is wrong; T4 corrects it there.
- **Wargrid rule = ZH rule.** `active_collector_id` already serialises one collector per source and per depot; nothing changes in the claim/queue code. What is wrong is the held length: the pile hold must be the measured ZH hold (worker 85, truck 192, Chinook 390 frames), which is `(boxes + 1) x load_ticks`. No per-source concurrency limit, no new key.
- **Wargrid today** (T1/T2 tree, scratch-sim): 2 laborers 1371 (2.0x, ZH 855), 4 laborers 2741 (4.0x, ZH 1590: hold is 10 ticks), 2 trucks 1856, 4 trucks 3594 (3.87x; hold 150), 2 and 4 Chinooks 3743 (pile-bound at the 288-tick early-leave hold; ZH 2770 / 3116).
- **Chinook x4 (2.12x) contradicts the single-server cap set by x2 (1.89x)**: no hold value fits both (5 % bands [1.80, 1.98] and [2.01, 2.23] do not overlap). Suspected harness artefact: with 3 waiters at about 390 frames each the 900-frame clearance timeout fires, and a timed-out Chinook re-seeks and can serve another of Killing Fields' map piles (unverified). Decision: calibrate on x2 (the common case: one free plus one bought); the x4 row is reported, not gated, until the traces show where each x4 Chinook loaded.

### R2.2 Revised design (data only, plus the planned air-branch deletion)

1. Dock points: T2 as implemented (`DOCK_SHIFT` 0.25). Kept.
2. Delete the air early-leave (two branches in `step`), as planned: every collector holds `(boxes + 1) x load_ticks` at the pile.
3. Per row: `load_ticks` sets the pile hold to the measured ZH hold; `unload_ticks` takes the rest of the per-cycle constant that brings the single-collector cycle to ZH's. This replaces the half-at-each-end split. No faction ids in code, integer ticks, deterministic.

| row | `load_ticks` | `unload_ticks` | pile hold | per-cycle constant (with INI) |
|---|---|---|---|---|
| `frc_builder` | 5 -> 42 | 5 -> 45 | 84 | 129 |
| `china_collector` | 30 -> 38 | 12 -> 37 | 190 | 227 |
| `usa_collector` | 36 -> 43 | 87 -> 213 | 387 | 600 |

Unchanged: speeds (slopes check: worker 60.1 vs 60, truck 37.8 vs 37.5, Chinook 9.9 vs 10 frames per cell beyond 12 cells, all within 2 %), capacities, box value, footprints, `supply_clearance` 1, all-map source search.

Predicted credits/min against the pooled ZH reference (scratch-sim unless marked; laborer rows with `unload_ticks` 45 are derived from the scratch-sim run at 40, +5 ticks per cycle; the multi-laborer rows are pile-bound and do not move):

| row (units c-c) | Wargrid today | Wargrid after | ZH pooled | after vs ZH |
|---|---|---|---|---|
| laborer 162.5 / 312.5 | 685 / 242 | 434 / 201 (derived) | 434 / 201 | 0.0 / +0.1 % |
| laborer 762.5 | 82 | 77 (derived) | not measured (slope gives 77) | not gated |
| laborer x2 / x4 at 162.5 | 1371 / 2741 | about 868 (derived) / 1602 | 855 / 1590 | +1.5 / +0.8 % |
| truck 162.5 / 312.5 / 762.5 | 1508 / 928 / 429 | 1277 / 835 / 408 | 1294 / 829 / 407 | -1.3 / +0.7 / +0.3 % |
| truck x2 / x4 at 312.5 | 1856 / 3594 | 1669 / 2838 | 1668 / 2814 | +0.1 / +0.9 % |
| Chinook 162.5 / 312.5 / 762.5 | 2438 / 2147 / 1581 | 1617 / 1484 / 1189 | 1646 / 1468 / 1181 | -1.8 / +1.1 / +0.7 % |
| Chinook x2 / x4 at 312.5 | 3743 / 3743 | 2787 / 2787 | 2770 / 3116 | +0.6 / -10.6 % (x4 not gated) |
| gap 1 (112.5): laborer / truck / Chinook | 1753 / 2389 / 2553 | about 707 / 1856 / 1667 | no reference (closest-legal rows dropped) | not gated |

Residual risks: the Chinook x4 row (above); the Chinook hovers about 7 s at the depot instead of ZH's 2 s (the missing acceleration/lift time sits in `unload_ticks`; cosmetic, depot-bound only beyond 3 Chinooks per depot); the laborer and truck depot stands are shorter than ZH's (45 vs 80, 37 vs 50 frames), so a depot saturates later than in ZH (only with 7+ laborers or 13+ trucks per depot); ZH's 30 s clearance timeout is not modelled (waiters never re-seek; matters only with crowded piles and a second pile in reach); truck references carry about +-3 % sweep noise; gap-1 rates have no ZH reference; all economy pins move (single collectors at 162.5 units get 15-37 % slower).

### R2.3 Task list (supersedes section 6 Tasks 0-4; gate unchanged)

```text
T1: red parity suite  [DONE by the executing agent; REDO the references and add the multi rows]
Owns: game/tests/test_supply_parity.gd
Invariant: no production change; rate as today (8 deposits per collector after the first)
Boundary: truck references -> pooled 1294 / 829 / 407; add laborer x2 gap 3 (855), truck x2 / x4
          gap 9 (1668 / 2814); Ep6 becomes an absolute rate (4 laborers gap 3 within 5 % of 1590),
          FOUR_LABORERS_PENDING removed; Chinook x4 gap 9 printed as "reported, not gated, ZH 3116"
          with one passing check; Ep5 kept
Red: Ep1-Ep4, Ep6, new Ep7 (laborer x2, truck x2, truck x4) fail on the T1/T2 tree with the
     "today" values of R2.2
Green: n/a
Stop: a today value differs from R2.2 by > 2 % (find out why before T3)

T2: distinct dock points  [DONE, keep; no redo: Ep5 green, Gd1 fixture only]

T3: calibration
Owns: supply_collection.gd step() (delete the two air branches and the stale comment), collects rows
      in usa.gd / china.gd / frc.gd (R2.2 values, one comment line each: INI delay plus measured
      ZH dock hold, pointing here), literal ticks in test_supply.gd and tests reading them
Invariant: (boxes + 1) x load_ticks for every collector; unload once per cycle; claim, queue,
           _ahead and arrival code unchanged; same-tick cases (gather vs move, stop, build, salvage,
           removal of pile, depot or unit) keep their results
Boundary: Chinook on a pile emptied mid-load waits its delay; 50-box pile ending a truck load at 2;
          laborer interrupted by a build; 2 trucks arriving the same tick (id order)
Red: Ep1-Ep4, Ep6, Ep7
Green: every gated row within 5 % (expect R2.2 within 0.5 %), test_supply, full suite except the
       known moved pins, lint, warnings
Stop: a gated row outside 5 % that a +-2 tick change of that row's unload_ticks cannot fix
      without pushing another row of the same collector out (model wrong: back to Opus)

T4: final pins, harness check, docs
Owns: pin constants (test_skirmish_match.gd, test_team_match.gd, tools/run_netplay.sh,
      tools/run_team_match.sh); m7-verification.md, m7-supply-parity-measured.md (correct the
      "not held" finding, add the Chinook x4 trace check), m7-economy-parity.md pointer
Invariant: every pin old (b7c9ae3) -> new recorded with the tree; replay trace cmp-identical to the
           base; nothing outside supply moves
Boundary: Chinook x4 traces (scratchpad U/rep1..3, read-only): position of each Chinook at each
          load; if any loaded elsewhere than the 400-box dock, record the row as an artefact
Red: the moved pins (already red)
Green: full suite, lint, warnings, python checks, benchmark ledger row, netplay and team scripts
Stop: section 5 user list
```

### R2.4 The 700-unit search radius: deferred

ZH collectors (all three, INI `...ScanDistance 700`, AI players 2x = 1400 units per `SupplyTruckAIUpdate.cpp:238`, `WorkerAIUpdate.cpp:225`) do not start toward a pile beyond the scan. Not folded in: no gated row needs it (the truck and Chinook did start at 762.5, so the effective reference point is unclear, probably the collector's spawn spot, unverified), it is a behaviour rule, not a rate, and it would change which pile bots work on large maps, moving S1/Cs1/Fm1 and the team match beyond a mere re-pin. Proposed for after M7 as a separate small task (one `scan` cells key per collects row, 28 human / 56 bot), user decision. The laborer 762.5 row stays ungated.

### R2.5 Tolerance

The band is 5 % of the pooled value, never widened, never shifted by the noise. A row outside 5 % fails even when the reference's +-3 % (truck) could cover it: it gets 3 more ZH runs pooled with the first 3; still outside, it goes to the user with both numbers. To leave room for that noise, calibration aims each truck row inside +-2 % (R2.2: max 1.3 %). A row inside 5 % passes; its margin is reported when it is above 3 %.

### R2.6 For the user afterwards

Pins leaving their windows or outcomes (S1 7000-17999 winner 1; Cs1/Fm1 won inside 45000 with their seen events; team cap winner null), the `units_peak` ceiling, the Chinook x4 row (artefact or a real 2.12x needing a model change), the 700-unit search (R2.4), the 30 s clearance timeout (not modelled), any exceeded performance budget (reported, accepted until the post-M7 spike), and commit, push, merge.

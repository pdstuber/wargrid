# M7 economy-parity rework: decision record (2026-11-07)

Status: implemented on `m7-factions` (see [m7-verification](m7-verification.md)); this note keeps the root causes, the minimum-distance facts and the final design (Revision 2). Decided by Opus agents with the user away.

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
- **The old formula** was right only for the truck because the truck has little unmodelled handling; for the worker and Chinook the handling and acceleration dominate.

## 3. Minimum depot-to-pile distance

See [m7-placement-rules](m7-placement-rules.md) (rule 1). The API accepted the GLA stash at 90 units (3.6 cells), below the rule's 106; unverified which is right.

## Revision 2: final design (2026-11-07, after the pooled measurements)

Status: decided by the Opus decision agent (user away, design delegated). References: pooled ZH rows in [m7-supply-parity-measured](m7-supply-parity-measured.md) (3 runs each). Wargrid numbers marked **scratch-sim** come from a scratch copy of the working tree (dock-point change applied) with the values below and the air branches deleted, run through `test_supply_parity.gd`'s own `layout` and `rate` (8 deposits per collector after the first); copy and probe in the scratchpad `rev2/`, not in the repo.

### R2.1 Dock model: ZH holds the dock, and so does Wargrid

- **Source-read** (fork `eb595cfc9`, `GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Update/DockUpdate/DockUpdate.cpp`): one `m_activeDocker` per dock. `update()` (line 416) grants it to the first docker whose approach position is reached; `onExitReached` (line 356) clears it. Approach, enter, dock movement, every action delay and the exit move all run under it. The `SupplyDock` is boneless with `NumberApproachPositions -1` (dynamic, unlimited waiting spots; [m7-economy-parity](m7-economy-parity.md) line 33), so waiting is unlimited but service is one at a time. Depots hold the same way. `AIDock.cpp:282`: a waiter gives up after 30 s (900 frames) of waiting for clearance.
- **Measured, consistent with a held pile.** A single-server pile caps n collectors at cycle / hold. Worker: 311 / 85 = 3.66x (measured 3.66x; hold 85 = the 84-frame pile standing). Truck: 651 / 192 = 3.39x (measured 3.39x; standing 188). Chinook x2: 736 / 390 = 1.89x (measured 1.89x). An unheld pile would give about 4.0x for 4 workers. The Task 0 stop line (3.6x) was my arithmetic error: it predicted the held cap wrongly. The finding in the measured note ("dock handling overlaps, not held") is wrong; T4 corrects it there.
- **Wargrid rule = ZH rule.** `active_collector_id` already serialises one collector per source and per depot; nothing changes in the claim/queue code. What is wrong is the held length: the pile hold must be the measured ZH hold (worker 85, truck 192, Chinook 390 frames), which is `(boxes + 1) x load_ticks`. No per-source concurrency limit, no new key.
- **Wargrid today** (dock-point tree, scratch-sim): 2 laborers 1371 (2.0x, ZH 855), 4 laborers 2741 (4.0x, ZH 1590: hold is 10 ticks), 2 trucks 1856, 4 trucks 3594 (3.87x; hold 150), 2 and 4 Chinooks 3743 (pile-bound at the 288-tick early-leave hold; ZH 2770 / 3116).
- **Chinook x4 (2.12x) contradicts the single-server cap set by x2 (1.89x)**: no hold value fits both (5 % bands [1.80, 1.98] and [2.01, 2.23] do not overlap). Suspected harness artefact: with 3 waiters at about 390 frames each the 900-frame clearance timeout fires, and a timed-out Chinook re-seeks and can serve another of Killing Fields' map piles (unverified). Decision: calibrate on x2 (the common case: one free plus one bought); the x4 row is reported, not gated, until the traces show where each x4 Chinook loaded.

### R2.2 Revised design (data only, plus the planned air-branch deletion)

1. Dock points: implemented (`DOCK_SHIFT` 0.25).
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

### R2.4 The 700-unit search radius: deferred

ZH collectors (all three, INI `...ScanDistance 700`, AI players 2x = 1400 units per `SupplyTruckAIUpdate.cpp:238`, `WorkerAIUpdate.cpp:225`) do not start toward a pile beyond the scan. Not folded in: no gated row needs it (the truck and Chinook did start at 762.5, so the effective reference point is unclear, probably the collector's spawn spot, unverified), it is a behaviour rule, not a rate, and it would change which pile bots work on large maps, moving S1/Cs1/Fm1 and the team match beyond a mere re-pin. Proposed for after M7 as a separate small task (one `scan` cells key per collects row, 28 human / 56 bot), user decision. The laborer 762.5 row stays ungated.

### R2.5 Tolerance

The band is 5 % of the pooled value, never widened, never shifted by the noise. A row outside 5 % fails even when the reference's +-3 % (truck) could cover it: it gets 3 more ZH runs pooled with the first 3; still outside, it goes to the user with both numbers. To leave room for that noise, calibration aims each truck row inside +-2 % (R2.2: max 1.3 %). A row inside 5 % passes; its margin is reported when it is above 3 %.

### R2.6 For the user afterwards

Pins leaving their windows or outcomes (S1 7000-17999 winner 1; Cs1/Fm1 won inside 45000 with their seen events; team cap winner null), the `units_peak` ceiling, the Chinook x4 row (artefact or a real 2.12x needing a model change), the 700-unit search (R2.4), the 30 s clearance timeout (not modelled), any exceeded performance budget (reported, accepted until the post-M7 spike), and commit, push, merge.

# Dock-hold experiment: three dock models against Zero Hour (2026-11-12)

Status: measured, evidence only; no default model, game number, gated target or tolerance changed. Follows decision items 1 and 2 of the [faction income parity](faction-income-parity.md#decision-list-for-the-user) note. Labels: **measured (source build, fork a75330d82)** = Zero Hour, median of 3 games per row, fork commit "Expose a dock's active docker to the parity API" (local to the fork checkout, never pushed; logging only, on top of afcaaf198 which produced the opening rows); **measured (Wargrid, branch tree f534670)** = one deterministic headless run per row on the local experiment branch `dock-hold` (not published) (`DOCK` and `INCOME` report lines of `test_dock_models.gd`); arithmetic bounds are labelled as such. The design and plan (`docs/superpowers/specs/2026-11-12-dock-hold-experiment-design.md`, `docs/superpowers/plans/2026-11-12-dock-hold-experiment.md`) live on that local branch (not published) with the variant code, which does not merge.

## The answer

Split closes most of the FRC gap; queue does not. Under the pass rule neither passes: of 22 judging rows hold passes 16, split 17, queue 13. Split lifts the FRC close depot from 1590 to 2085 per minute with 5 workers (Zero Hour 2085) and to 2625 with 7 (2850), and turns re-measured Laborer x4 and Chinook x4 green, but it overshoots USA by 8 % to 13 % (usa2 net +12.6 % close and +7.8 % far, two Chinooks 3000 against 2760) and leaves the far depot where it was (frc7 steady -8.5 %). Queue, fitted to the single-collector rows as specified, runs below hold on every saturated row (frc5 close 1305 against hold's 1590; Zero Hour 2085) because its lock is hold's lock plus the walk in and out; it cannot close the gap without a second parameter (B' in the decision list).

## Scoreboard

Judging rows: 8 openings (net at 600 s and steady rate both within 5 %), 8 single-collector rows, 5 `MULTI` rows plus Chinook x4 on the re-measured steady window. Details in the three tables below.

| model | openings (of 8) | single (of 8) | MULTI + Chinook x4 (of 6) | total (of 22) | fails |
|---|---|---|---|---|---|
| hold (today) | 4 | 8 | 4 | 16 | frc5 close, frc7 close, frc5 far, frc7 far, Laborer x4, Chinook x4 |
| split (A) | 4 | 8 | 5 | 17 | usa2 close, usa2 far, frc7 close, frc7 far, Chinook x2 |
| queue (B) | 2 | 8 | 3 | 13 | usa2 close, usa2 far, china3 close, frc5 close, frc7 close, frc7 far, Laborer x4, truck x4, Chinook x4 |

- No row is a short window (under 450 s) in any model. Two split rows end early because the 400-box pile (30,000 credits) runs dry: usa2 close at 586.4 s (its 600 s net is capped by the pile: gross 30,000 against Zero Hour's 27,000) and Chinook x4 at 572.6 s. Both flagged in the tables.
- Far-depot rows (the design's known risk: A cannot move unsaturated rows): confirmed. Of the unsaturated far rows (china3, frc5, frc7), split leaves the steady rates at hold's (2340, 960, 1290); frc5 far passes on net only by one Laborer delivery (6,900 against hold's 6,825, +75, -5.2 % to -4.2 %), which is the boundary flip that gives split its one-row lead over hold. frc7 far fails under all three models at -8.5 % steady; the residual is not saturation (income note candidate 3) and nothing here explains it. Among those rows queue moves only frc5 far (990 against hold's 960, exactly two Laborer deliveries, 30 per minute over 300 s), which passes there; frc7 far stays 1290.
- Split against hold: gains frc5 close, frc5 far, Laborer x4 and Chinook x4; loses usa2 close, usa2 far and Chinook x2. The net lead of one row rests on the frc5 far flip above.
- Hold fails frc5 far on net by 0.2 points (-5.2 %) while its steady rate (-4.5 %) passes.

## Zero Hour re-measure

**measured (source build, fork a75330d82)**, 3 repeats per row, 600 s, steady window = 300-600 s after the first collector's gather order; the pile never ran dry and no window was short. Old window = first deposit to the Nth (what `test_supply_parity.gd` compares today). Spread over the 3 games at most 3.5 %.

| row | old window | steady (spread) | gated target today | steady against gated |
|---|---|---|---|---|
| Chinook x2, gap 9 | 2770.2 | 2760.0 (0.0 %) | 2770 | -0.4 % |
| Chinook x4, gap 9 | 3115.3 | 3120.0 (0.0 %) | 3116 (reported, not gated) | +0.1 % |
| truck x2, gap 9 | 1680.5 | 1680.0 (0.0 %) | 1668 | +0.7 % |
| truck x4, gap 9 | 2797.5 | 2940.0 (2.0 %) | 2814 | +4.5 % |
| Laborer x2, gap 3 | 857.3 | 870.0 (1.7 %) | 855 | +1.8 % |
| Laborer x4, gap 3 | 1622.1 | 1725.0 (3.5 %) | 1590 | +8.5 % |

Two targets move: Laborer x4 (steady 1725 against 1590; the gated +-5 % ceiling is 1669.5, so it is outside) and truck x4 (2940 against 2814, +4.5 %, still inside tolerance by half a point). The income note's estimate for Laborer x4 was 1650-1740; the measurement lands in it. Laborer x4 is not saturated in Zero Hour (the pile has a docker locked in 55-57 % of the window; x2 28 %), truck x4 and Chinook x4 are (100 %, 96 %); truck x2 is 57 %, Chinook x2 99 %.

### Lock windows (Zero Hour, frames at 30 per second)

Time from the dock grant to the release, per visit, median (n visits). The grant is set when the docker reaches its approach position and cleared at the exit, so the walk in and out is inside it; waiting is outside.

| kind | pile x2 | pile x4 | depot x2 | depot x4 | used |
|---|---|---|---|---|---|
| Laborer | 44 (345) | 44 (673) | 39 (342) | 39 (667) | 44 / 39 (also the x5 and x7 opening reruns: 44 (793), 44 (1057) / 39 (785), 39 (1048); worker x4 is not saturated, so these were rerun at x5 and x7, x7 at 91-93 % saturation) |
| truck | 184 (165) | 184 (284) | 46 (162) | 46 (279) | 184 / 46 |
| Chinook | 394 (135) | 345 (159) | 154 (135) | 153 (150) | 345 / 153 (x4, saturated) |

Against these, hold's stand is its lock: pile (boxes + 1) x `load_ticks` = 84 (Laborer), 190 (truck), 387 (Chinook); depot `unload_ticks` 45, 37, 213. Zero Hour's locked part is 52 % of the Laborer's pile stand and 87 % of its depot stand, 97 % and 124 % for the truck (its depot lock is longer than hold's 37), 89 % and 72 % for the Chinook. Zero Hour's own Chinook lock differs between x2 (394 / 154) and x4 (345 / 153); one value per kind cannot match both.

## The rows, per model

### Eight openings (net at 600 s / steady credits per minute, delta against Zero Hour)

Zero Hour numbers are the medians of the [income note](faction-income-parity.md) tables (**measured (source build, fork afcaaf198)**, not rerun on the new fork commit, which only adds logging). Pass needs both deltas within 5 %.

| opening | Zero Hour | hold | split (A) | queue (B) |
|---|---|---|---|---|
| usa2 close | 23,800 / 2880 | 23,200 (-2.5 %) / 2760 (-4.2 %) **pass** | 26,800 (+12.6 %) / 3142.5 (+9.1 %) **FAIL**, pile empty 586.4 s | 22,000 (-7.6 %) / 2640 (-8.3 %) **FAIL** |
| china3 close | 24,600 / 2880 | 24,000 (-2.4 %) / 2820 (-2.1 %) **pass** | 24,900 (+1.2 %) / 2940 (+2.1 %) **pass** | 23,100 (-6.1 %) / 2700 (-6.2 %) **FAIL** |
| frc5 close | 17,625 / 2085 | 13,125 (-25.5 %) / 1590 (-23.7 %) **FAIL** | 17,400 (-1.3 %) / 2085 (+0.0 %) **pass** | 10,500 (-40.4 %) / 1305 (-37.4 %) **FAIL** |
| frc7 close | 23,750 / 2850 | 12,725 (-46.4 %) / 1590 (-44.2 %) **FAIL** | 21,875 (-7.9 %) / 2625 (-7.9 %) **FAIL** | 9,950 (-58.1 %) / 1290 (-54.7 %) **FAIL** |
| usa2 far | 23,200 / 2760 | 23,200 (+0.0 %) / 2760 (+0.0 %) **pass** | 25,000 (+7.8 %) / 3000 (+8.7 %) **FAIL** | 22,000 (-5.2 %) / 2640 (-4.3 %) **FAIL** |
| china3 far | 20,100 / 2400 | 19,500 (-3.0 %) / 2340 (-2.5 %) **pass** | 19,500 (-3.0 %) / 2340 (-2.5 %) **pass** | 19,500 (-3.0 %) / 2340 (-2.5 %) **pass** |
| frc5 far | 7,200 / 1005 | 6,825 (-5.2 %) / 960 (-4.5 %) **FAIL** | 6,900 (-4.2 %) / 960 (-4.5 %) **pass** | 7,275 (+1.0 %) / 990 (-1.5 %) **pass** |
| frc7 far | 10,400 / 1410 | 9,650 (-7.2 %) / 1290 (-8.5 %) **FAIL** | 9,725 (-6.5 %) / 1290 (-8.5 %) **FAIL** | 9,500 (-8.7 %) / 1290 (-8.5 %) **FAIL** |

Granularity: a delivery in the 300 s window is 15 per minute for a Laborer (1.5 % of frc5 far's 1005), 60 for a truck (2.1 % of 2880), 120 for a Chinook (4.3 % of 2760, 4.2 % of 2880). Split's usa2 far and Chinook x2 misses are two Chinook deliveries (3000 against 2760), not rounding; usa2 close (3142.5 against 2880, about 2.2 deliveries) is also cut short by the empty pile at 586.4 s.

### Single-collector rows (credits per minute; gated today, tolerance 5 %)

Targets from `test_supply_parity.gd` `TARGETS` ([supply parity measured](m7-supply-parity-measured.md)). All 24 cells pass.

| row | Zero Hour | hold | split (A) | queue (B) |
|---|---|---|---|---|
| usa_collector gap 3 | 1646 | 1616.8 (-1.8 %) | 1616.8 (-1.8 %) | 1624.1 (-1.3 %) |
| usa_collector gap 9 | 1468 | 1483.5 (+1.1 %) | 1483.5 (+1.1 %) | 1489.7 (+1.5 %) |
| usa_collector gap 27 | 1181 | 1189.4 (+0.7 %) | 1189.4 (+0.7 %) | 1193.4 (+1.0 %) |
| china_collector gap 3 | 1294 | 1276.6 (-1.3 %) | 1276.6 (-1.3 %) | 1282.7 (-0.9 %) |
| china_collector gap 9 | 829 | 834.6 (+0.7 %) | 834.6 (+0.7 %) | 837.2 (+1.0 %) |
| china_collector gap 27 | 407 | 408.2 (+0.3 %) | 408.2 (+0.3 %) | 408.8 (+0.4 %) |
| frc_builder gap 3 | 434 | 434.1 (+0.0 %) | 434.1 (+0.0 %) | 434.1 (+0.0 %) |
| frc_builder gap 9 | 201 | 201.2 (+0.1 %) | 201.2 (+0.1 %) | 201.2 (+0.1 %) |

Split's lone cycle equals hold's to the digit by construction. Queue's moves by up to 0.5 points (it was recalibrated, below).

### MULTI rows and Chinook x4 (steady window, against the re-measured Zero Hour value)

The old-window numbers are shown for reference and not judged (Wargrid spawns all collectors at tick 0, Zero Hour trains them). Zero Hour old window: 2770.2, 857.3, 1622.1, 1680.5, 2797.5, 3115.3 in the row order below.

| row | Zero Hour steady | hold | split (A) | queue (B) |
|---|---|---|---|---|
| Chinook x2 (usa gap 9) | 2760 | 2760 (+0.0 %) **pass**; old 2787.1 | 3000 (+8.7 %) **FAIL**; old 2967 | 2640 (-4.3 %) **pass**; old 2679.9 |
| Laborer x2 (frc gap 3) | 870 | 870 (+0.0 %) **pass**; old 868.2 | 870 (+0.0 %) **pass**; old 868.2 | 855 (-1.7 %) **pass**; old 868.2 |
| Laborer x4 (frc gap 3) | 1725 | 1605 (-7.0 %) **FAIL**; old 1602.4 | 1650 (-4.3 %) **pass**; old 1736.3 | 1335 (-22.6 %) **FAIL**; old 1336.6 |
| truck x2 (china gap 9) | 1680 | 1680 (+0.0 %) **pass**; old 1669.2 | 1680 (+0.0 %) **pass**; old 1669.2 | 1620 (-3.6 %) **pass**; old 1674.4 |
| truck x4 (china gap 9) | 2940 | 2820 (-4.1 %) **pass**; old 2838.4 | 2880 (-2.0 %) **pass**; old 2915 | 2760 (-6.1 %) **FAIL**; old 2769.2 |
| Chinook x4 (usa gap 9) | 3120 | 2760 (-11.5 %) **FAIL**; old 2787.1 | 3169.9 (+1.6 %) **pass**; old 3155; pile empty 572.6 s | 2640 (-15.4 %) **FAIL**; old 2679.9 |

- Hold's Chinook x4 equals its x2 (2760, old window 2787.1 both): that is hold's per-pile cap for Chinooks (9 x 43 ticks per 600 credits), not a coincidence. Zero Hour x4 is 3120.
- Hold fails Laborer x4 on the steady window (1605 against 1725) while passing its own gated 1590 on the old window; the two are different windows, not a different model.

## How each model works and what it was fitted to

**Hold (today).** One collector holds a pile for its whole stand, (boxes + 1) x `load_ticks`, and a depot for `unload_ticks`. Unchanged; the default and the only model in normal play. On the local branch `dock-hold` (not published), with `dock_model` unset the full suite passes unchanged (every pinned trace and digest identical).

**Split (A).** A stand keeps its length, but only a measured exclusive part locks the target; the lead-in before it is non-exclusive and comes first. The exclusive part is Zero Hour's lock median (table above), rounded to ticks, per kind and dock. The truck depot's lock (46) is longer than its stand (37), so it has no lead-in and keeps today's 37 ticks.

| kind | source: lead + (boxes + 1) x box | depot: lead + work |
|---|---|---|
| Laborer | 40 + 2 x 22 = 84 | 6 + 39 = 45 |
| truck | 5 + 5 x 37 = 190 | 0 + 37 = 37 |
| Chinook | 45 + 9 x 38 = 387 | 60 + 153 = 213 |

**Queue (B).** Wargrid's own approach spots: collectors arrive at an ordered spot (ground: the centre of the collector's own claimed ring cell; air: spots on a ray from the target toward where the collector came from, 1.5 cells apart), the head takes the lock and walks in, works, walks out; the lock is released at the exit spot. Calibration (**measured (Wargrid, branch tree f534670)**; log `~/projects/wargrid-dock-work/queue-calibration.md`, outside the repo): one in-dock time per kind (per box at a pile, per unload at a depot), fitted to the eight single-collector rows only, nothing fitted to multi-collector or opening rows.

| kind | pile, per box | depot | worst single-row error |
|---|---|---|---|
| Laborer | 32 | 35 | 0.1 % |
| truck | 32 | 29 | 1.0 % |
| Chinook | 43 | 208 | 1.5 % |

The first try (hold's own `load_ticks` / `unload_ticks`) failed truck gap 3 (-9.1 %) and Laborer gap 3 (-8.8 %) (truck gap 9, -4.6 %, was inside 5 %), because the lock now also covers the walk in and out. Single rows fix only K = (boxes + 1) x pile box + depot; the split between the two is not identifiable from them, so it keeps hold's `load_ticks` : `unload_ticks` ratio. That ratio is a choice, not a fit, and it drives the multi-collector rows (below).

### Why queue cannot beat hold here

The single-row fit fixes the lone cycle: T_B + L_B = T_H + L_H (T unlocked time, L locked time). B's only unlocked time is the trip to the approach spot, so L_B = L_H + the in/out travel that was unlocked under hold. Lock totals pile + depot, queue against hold: Laborer 173 against 129, truck 259 against 227, Chinook 627 against 600 ticks (Zero Hour: 83, 230, 498). Per-visit single-collector gap 9 (entering + work + leaving, ticks), queue against Zero Hour pile / depot: Laborer 101 / 72 against 44 / 39, truck 195 / 64 against 184 / 46, Chinook 403 / 224 against 345 / 153. At hold's pile : depot ratio B's total lock is never shorter than hold's, so a saturated row cannot rise above hold's there; the built in/out (the own-cell step, 0.25 cell) is already short, so this is close to B's best case. A different ratio moves lock between pile and depot and can lift Chinook rows (below) but not Laborer x4.

Split sensitivity of the unfitted pile : depot split (**arithmetic bounds, not measurements**; bound = box value x boxes x 1800 / pile lock): Laborer x4 at hold's ratio (pile lock 101) bounds at about 1337 (measured run: 1335); at Zero Hour's 44 : 39 ratio (pile lock about 92) about 1470; at an even split (86.5) about 1560, still below hold's 1605. Chinook at an even split (313 per dock) bounds the pile at about 3450. So queue's multi-collector rows hang on an unfitted choice, and none of the plausible choices lifts Laborer x4 above hold.

## Caveats

- **Split's same-tick tie goes by id.** When two collectors leave their lead-in on one tick, the lock goes to the lower id, not air before ground as `_ahead` orders arrivals. Only mixed air/ground docks differ; not measured.
- **Hold's Chinook x4 equals x2** (cap above); the third-Chinook opening (income note item 3) is excluded and would show the same gap.
- **Queue ground does not advance.** The design asks for waiting collectors at ordered approach spots that advance; the built version keeps each collector on its own claimed cell, 0.25 cell back, and the lock covers that short step in and out. By the lock identity above this changes nothing beyond that small added lock time; it is a deviation from the design, not a hidden effect. An advancing queue would mean longer in/out moves, hence a longer lock and lower saturated rates: the built B favours B (the Task 6 review found it fair and favourable to B). Path-service latency is part of entering and leaving time, hence of the lock (a reviewer estimated 1-2 ticks under load; not measured).
- **Queue's pile / depot split is an unfitted choice** (above).
- **One Chinook value per dock cannot match Zero Hour at x2 and x4.** Split uses the x4 lock (345) and overshoots the x2 rows: at the x2 median (394) the pile bound is 600 x 1800 / 394 = about 2740 per minute (**arithmetic bound**), close to Zero Hour's x2 rate (2760). Fitting E per row count would be the per-row tuning the design forbids.
- **Where the code lives.** `SPLIT` and `QUEUE_WORK` are in `game/scripts/experiments/` (local branch `dock-hold`, not published), not under `game/scripts/simulation/definitions/`, because `tools/test_faction_guard.py` rejects kind literals anywhere in the simulation except definitions (capability data). A clean adoption would put them in the definitions as capability data. `dock_queue.gd` uses Vector2 `normalized()` once per seek (determinism rules, "Positions"); experiment-only.
- **Single run per Wargrid row.** The simulation is deterministic; the Zero Hour side is a median of 3 with the spreads above. The rows were produced across branch heads dba769e, 3bf288e and f534670; the hold and split lines are identical on those trees.
- **Window ends differ by a little.** Zero Hour's pile-empty rule ends the window at the last deposit (slightly high rate); Wargrid's `steady_rate` ends it at the last box taken, with cargo still in flight (slightly low). No Zero Hour row emptied its pile, and the affected split rows (usa2 close, Chinook x4) are judged the same either way.
- **Not tested:** a third Chinook, mixed air/ground docks, `bot_collectors_per_supply_center` other than 5, rendered behaviour (headless only; split has no visible queue), the benchmark (variant code does not merge).

## Decision list for the user

Nothing here is decided. Recommendations are the agent's.

1. **Adopt split, adopt queue, or neither.** Hold fails 6 of 22 rows, split 5, queue 9 (scoreboard). Split leads hold by one row, and that rests on the frc5 far boundary flip (+75 net, one delivery). It closes frc5 close (net -1.3 %, steady equal) and Laborer x4 / Chinook x4, but overshoots usa2 (+12.6 % close, +7.8 % far), Chinook x2 (+8.7 %), and still misses frc7 close (-7.9 %) and frc7 far (-8.5 %). Queue fails 4 rows hold passes (usa2 close and far, china3 close, truck x4) and passes 1 hold fails (frc5 far). A clean adoption means rebuilding the model without a switch, with the lock windows as capability data (per kind: lead and exclusive length for source and depot) in `definitions/`, changed pinned economy traces and digests, and a ledger and benchmark row; the variant code is evidence, not a base. *Recommendation:* adopt neither as built. If the FRC gap must close, split is the only candidate worth rebuilding, and the Chinook E (item 5) should be settled first, because it decides the USA overshoot.
2. **B' (a queue fitted to the Zero Hour lock).** Fit B's lock to the measured medians (44 / 39, 184 / 46, 345 / 153) and put the rest of the lone cycle into an unlocked dwell at the approach spot: a second parameter per kind and target, which needs a spec change (the spec allows one in-dock time per kind and target). Expected, not run: it should reproduce split's numbers on saturated rows with a real queue instead of an abstract lead-in (it would lock the truck depot at 46 against split's 37, but the truck pile is the bottleneck, so rows probably match). *Recommendation:* do not; B' lands on split's results for more code and the same Chinook x2 / x4 conflict. Worth it only if a visible queue is wanted for play, which is a presentation decision, not an income one.
3. **New `MULTI` targets on the steady window** (income note item 2, a separate decision): Laborer x4 1590 to 1725, truck x4 2814 to 2940, the others within 1.8 % of today's. Changing them also means the gate must judge the steady window, not the old one (the local branch's (`dock-hold`, not published) `steady_rate` helper does that), and hold then fails Laborer x4 (1605 against 1725, -7.0 %) and Chinook x4 if gated (2760 against 3120): the suite goes red on the default model. *Recommendation:* make the change together with item 1, not before; changing it alone without a dock fix turns the suite red for no gain.
4. **FRC bot collector count** (income note item 4, `bot_collectors_per_supply_center` 5). Zero Hour close depot: 7 workers earn 2850 against 2085 for 5. Wargrid today: 7 adds nothing (net 12,725 against 13,125). Split: 7 beats 5 by 26 % steady (2625 against 2085) and 4,475 net (21,875 against 17,400) for 400 more spent; queue: 7 is no better than 5 (1290 against 1305). *Recommendation:* decide with item 1; keep 5 until a dock model is adopted.
5. **Other rows the numbers show.**
   - Split's USA overshoot: usa2 close net 26,800 against 23,800 (+12.6 %, pile empty at 586.4 s), usa2 far 25,000 against 23,200 (+7.8 %), Chinook x2 steady 3000 against 2760 (+8.7 %). Cause: one Chinook lock for x2 and x4 (caveat above). Options: accept USA 2-Chinook income about 9 % above Zero Hour; a per-row-count lock (the per-row tuning the design forbids); or leave Chinooks on hold with split for Laborers and trucks only (by construction, not run: usa2 and Chinook x2 pass again as in hold, Chinook x4 stays at 2760 against 3120 and fails the rule on that row). *Recommendation:* the last, if split is rebuilt, because Chinook x4 is not an opening (the third Chinook is excluded, user, 2026-11-12) and the other two options trade one parity for another.
   - frc7 close under split, 2625 against 2850 (-7.9 %), and frc7 far under every model, 1290 against 1410 (-8.5 %). Not explained by the lock windows; income note candidates 2 and 3 (dock spots, per-cycle travel) remain untested. *Recommendation:* a separate small investigation of the far-depot cycle length before any adoption; hold, split and queue all have the same lone-cycle match at gap 9 (201 per minute), so the residual shows only with several workers (frc7 far is 184 per worker per minute against Zero Hour's 201).
   - Hold's Chinook cap (2760 for x2 and x4 against 3120): shows only with a third Chinook, which stays out of the opening (user, 2026-11-12). Report only.

6. **Option C: one pile throughput for every collector (research, arithmetic, not run).** Source: an agent research report (OpenRA b4d95a5671, Zero Hour 0a05454, branch tree f534670), kept in the work folder `~/projects/wargrid-dock-work/research-report.md`; the predicted rates and locks below are arithmetic from the measured rows; the OpenRA bullet is code reading and the build-up proxy is interpolation on the net curves. Zero Hour holds a pile about 0.59 to 0.66 ticks per credit for every collector (Laborer 44 / 75, truck 184 / 300, Chinook 345 / 600 at x4 and 394 / 600 at x2). C makes that one constant: pile lock = `ceil(cargo_credits x 184 / 300)` ticks, the rest of today's stand an unlocked lead (lone rates unchanged by construction, lock at most the stand), depot locks as in split. Split is about 90 % of C: C changes only the Chinook pile lock (342 to 369) and the Laborer lock (44 to 46); truck stays 185.
   - Predicted steady rates: usa2 close 2880, china3 close 2880-2940, frc7 close 2730-2905 if the contention loss below is fixed (all within about 4.2 % of Zero Hour's 2880 / 2880 / 2850), frc5 close about 2070, Chinook x2 about 2880 (+4.3 % against the steady 2760, inside the rule narrowly). Cost: usa2 far moves from 0 % (hold) to +4.3 % (2880 against 2760), inside 5 % but worse than today; the cause is that Zero Hour's Chinook lock grows with depot distance (usa2 close implies at most 375 locked frames per visit, far about 391, measured 394) and no constant fits both. Using the x4 Chinook value (345) instead would give locks 352 / 176 / 44 and about +4 % on usa2 close and china3.
   - frc7 under split is not lock-bound: its pile bound is 3039 against 2625 measured, so Wargrid loses about 14 % to worker contention where Zero Hour loses about 6 %. No lock rule fixes that; without the fix frc7 close stays near 2600 under C. Cause not established. Candidates from the code (unverified): a one-tick handoff delay per release, ground interference near the ring cells, the 30-tick retry on `blocked` (probably rare). Next measurement: a per-phase time breakdown (flying, lead, waiting, loading, path pending) for frc7 close and far under split against the lone Laborer, plus a count of blocked releases.
   - OpenRA gives no model: one harvester for all factions (identical data), a short unload-only refinery hold (about 30 ticks plus animations), no source-side lock (ore is claimed per cell), throughput set by dock count. It supports "keep the exclusive window short" and "throughput is a property of the dock".
   - Build-up proxy (income alone repaying a factory plus 5 main tanks after the opening is paid; interpolated on the net curves; not a played build order): Zero Hour 212-236 s per faction; Wargrid today FRC 312-327 s (frc5 312, frc7 327) against USA and China 218-236 s; split frc7 222 s (frc5 257 s). Missing: a played build order, army value per minute, multi-pile maps.
   - *Recommendation:* run C as the next measured experiment before adopting anything; it needs the same harness and one formula in place of split's table. Decide first whether usa2 far may move to +4.3 % (C) or must stay exact (split with Chinooks on hold's lock).

7. **Economy metrics (web research, not applied).** Source: an agent web research report (accessed 2026-11-12), kept in the work folder `~/projects/wargrid-dock-work/web-research-report.md`. Keep net credits at fixed seconds and the 300-600 s steady rate; the field samples the same kind of number (Blizzard's `s2protocol` stats event carries `m_scoreValueMineralsCollectionRate` and `m_scoreValueWorkersActiveCount`). Candidates to add, computed from what the tests already record (per-tick credits, deposits per collector, opening spend, definition costs), except that metrics 1 and 2 need a 1..N collector sweep, of which only the x1, x2 and x4 rows exist:
   1. *Saturated income per dock site and the spend to reach 90 % of it, per faction.* Cap = highest steady rate over 1..N collectors (the multi-collector rows); spend = depot plus collectors needed for 0.9 x cap. Stormgate balances its three asymmetric factions on the cap ("Maximum Luminite income per base across all three factions increased from 600 per minute to 750 per minute", as rendered by a page-fetch tool, not verified verbatim); the spend-to-90 % part is the agent's proposal, not Stormgate's.
   2. *Marginal income per extra collector and its payback.* marginal(n) = steady(n) - steady(n-1); payback(n) = cost / marginal(n) + build time. Liquipedia (secondary): "The first and second workers on a single mineral patch will each collect approximately 40 minerals per minute. The third worker will collect approximately 20 minerals per minute", "The 4th worker will not give you any additional income"; a worker returns its cost "92(±2) seconds after the initial investment is made", "153(±4) seconds" after 2 per patch. Under hold this would show FRC's 6th and 7th worker adding nothing (1590 for 5 and for 7).
   3. *Time to afford a faction-priced basket* (for example a factory plus N standard units): first tick where gross minus opening spend covers the basket cost from definitions; break-even is the empty basket. Answers "pace matches prices"; the basket is a design choice. The build-up proxy in item 6 is a first version.
   - *Recommendation:* add 1 and 2 to the next experiment's report rows; 3 after a basket is chosen.
   - Sources: Stormgate patch 0.2.1, https://devtrackers.gg/stormgate/p/7521168e-stormgate-patch-0-2-1 (original https://steamcommunity.com/games/2012510/announcements/detail/723490878922949424); Blizzard `s2protocol`, https://github.com/Blizzard/s2protocol; StarCraft II mining and payback figures, secondary community wiki flagged by the wiki as outdated for the current time scale, https://liquipedia.net/starcraft2/Mining_Minerals. Spending Quotient was rejected (a player-skill metric, race-biased by its own wiki).

## Reproduce

Zero Hour half (`collect_*_s600`, lock windows in `analyze.py --json`): on main. Wargrid half (variants, `test_dock_models.gd`, `steady_rate`): local branch `dock-hold`, not published. Zero Hour: `python3 -I tools/zh_parity/parity.py --out DIR --repeats 3 --lanes 3 'collect_*_s600'` (headless, silent, fork a75330d82), then `python3 -I tools/zh_parity/analyze.py --json DIR/rep1 DIR/rep2 DIR/rep3`; lock windows from the dock grants in the traces (`lock_windows` in `tools/zh_parity/analyze.py`); the `open_worker_u1625_x5` / `x7` reruns give the Laborer locks. Traces and pooled tables: `~/projects/wargrid-dock-work/zh/` and `zh-open/` (18 + 6 jobs, 0 failed), outside the repository. Wargrid, on branch `dock-hold`: `WARGRID_TEST_ONLY=test_dock_models sh tools/run_tests.sh` prints the `DOCK` and `INCOME` lines for all three models (`WARGRID_DOCK_MODELS=split` for one); the lines behind this note are `~/projects/wargrid-dock-work/wargrid-hold.txt`, `wargrid-split.txt`, `wargrid-queue.txt`.

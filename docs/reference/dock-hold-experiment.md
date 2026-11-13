# Dock-hold experiment: three dock models against Zero Hour (2026-11-12)

Status: measured, evidence only; this experiment changed no default model, game number, gated target or tolerance. Adopted: c1, user 2026-11-12 night; rebuild plan [c1 dock rebuild](../superpowers/plans/2026-11-12-c1-dock-rebuild.md). Follows decision items 1 and 2 of the [faction income parity](faction-income-parity.md#decision-list-for-the-user) note. Labels: **measured (source build, fork a75330d82)** = Zero Hour, median of 3 games per row, fork commit "Expose a dock's active docker to the parity API" (local to the fork checkout, never pushed; logging only, on top of afcaaf198 which produced the opening rows); **measured (Wargrid, branch tree f534670)** = one deterministic headless run per row on the local experiment branch `dock-hold` (not published) (`DOCK` and `INCOME` report lines of `test_dock_models.gd`); arithmetic bounds are labelled as such. The design and plan (`docs/superpowers/specs/2026-11-12-dock-hold-experiment-design.md`, `docs/superpowers/plans/2026-11-12-dock-hold-experiment.md`) live on that local branch (not published) with the variant code, which does not merge.

## The answer

Split closes most of the FRC gap; queue does not. Under the pass rule neither passes: of 22 judging rows hold passes 16, split 17, queue 13. Split lifts the FRC close depot from 1590 to 2085 per minute with 5 workers (Zero Hour 2085) and to 2625 with 7 (2850), and turns re-measured Laborer x4 and Chinook x4 green, but it overshoots USA by 8 % to 13 % (usa2 net +12.6 % close and +7.8 % far, two Chinooks 3000 against 2760) and leaves the far depot where it was (frc7 steady -8.5 %). Queue, fitted to the single-collector rows as specified, runs below hold on every saturated row (frc5 close 1305 against hold's 1590; Zero Hour 2085) because its lock is hold's lock plus the walk in and out; it cannot close the gap without a second parameter (B' in the decision list). Option C (one pile lock per credit for every collector, run 2026-11-12) passes 18 of the 22 rows with the truck constant (c1) and 15 with the Laborer constant (c2); c1 still misses frc7 close (not the lock rule, cause not established) and frc7 far (cause not established), usa2 far on net by 0.2 points and Chinook x4 by 7.7 %, and nothing is decided ([section below](#option-c-and-saturation-2026-11-12)).

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

## Option C and saturation (2026-11-12)

Evidence only; nothing is decided and no default changed. Option C (decision item 6) was built as two more test-only dock models and run through the same 22 rows, plus a 1..8 collector sweep on both sides and a per-phase look at the frc7 shortfall. Labels: **measured (source build, fork a75330d82)** = Zero Hour, median of 3 games; **measured (Wargrid, branch tree 8761f66)** = one deterministic headless run per row on the local branch `dock-hold` (not published; the c1 and c2 lines were saved from the tree that became 4dc7f0e and the sweep file from the tree that became 8761f66; only tests and tooling differ between them, and a rerun after the review fixes, which changed tests, a comment and one tooling check, reproduced every saved line byte for byte); **arithmetic** = computed here from those numbers.

- **Pass count.** Of 22 judging rows: c1 passes 18, split 17, hold 16, c2 15. c1's lead is thin (below).
- **Saturation.** Zero Hour's FRC close-depot income is still rising at 8 workers (3015 per minute); hold stops at 1605 from the 4th, split, c1 and c2 reach 2655 to 2700 at 8. Far-depot Laborers fall 4 to 10 % short of Zero Hour at 7 to 8 under hold, split, c1 and c2 (queue 17.8 % at 8); the lock barely moves that gap.
- **frc7 contention.** Not established. The numbers say it is not queueing at the docks and not the lock rule; it shows up as extra flight time per trip (about 1.3 s over a lone worker's estimated 6.1 s; hold shows +0.8 s too).

### What c1 and c2 are

Split's lead-in plus exclusive-lock mechanics, with the pile lock sized to what a visit earns: per-load box = `round(ceil(cargo credits x r) / loads)` ticks, lock = loads x box, the rest of today's stand an unlocked lead; depot entries as in split. c1 uses r = 184 / 300 (Zero Hour's truck pile lock per credit), c2 uses 44 / 75 (the Laborer's, the median of the three measured ratios). Resulting pile locks (arithmetic from the model tables, loads x per-load ticks): c1 46 (Laborer), 185 (truck), 369 (Chinook); c2 44, 175, 351; split 44, 185, 342. Lone-collector cycles are unchanged by construction. c2 equals split for the Laborer (same table entries after rounding), so every FRC row and curve of c2 is identical to split's; only truck and Chinook differ.

### Pass or fail over the 22 judging rows

**measured (Wargrid, branch tree 8761f66)** against the Zero Hour targets used above (openings from the [income note](faction-income-parity.md), MULTI rows from the re-measured steady window). Cells are delta against Zero Hour in percent, openings as net at 600 s / steady rate, MULTI rows as steady rate; **bold** is outside 5 %. Hold and split are copied from the tables above (the counts re-derive from the saved report lines: 16 and 17).

| row | hold | split | c1 | c2 |
|---|---|---|---|---|
| usa2 close | -2.5 / -4.2 | **+12.6** / **+9.1** (pile empty 586.4 s) | +2.5 / +0.0 | **+10.1** / **+8.3** |
| china3 close | -2.4 / -2.1 | +1.2 / +2.1 | +1.2 / +2.1 | **+7.3** / **+6.3** |
| frc5 close | **-25.5** / **-23.7** | -1.3 / +0.0 | -1.7 / +0.0 | -1.3 / +0.0 |
| frc7 close | **-46.4** / **-44.2** | **-7.9** / **-7.9** | **-9.5** / **-10.5** | **-7.9** / **-7.9** |
| usa2 far | +0.0 / +0.0 | **+7.8** / **+8.7** | **+5.2** / +4.3 | **+7.8** / **+8.7** |
| china3 far | -3.0 / -2.5 | -3.0 / -2.5 | -3.0 / -2.5 | -3.0 / -2.5 |
| frc5 far | **-5.2** / -4.5 | -4.2 / -4.5 | -4.2 / -4.5 | -4.2 / -4.5 |
| frc7 far | **-7.2** / **-8.5** | **-6.5** / **-8.5** | **-6.5** / **-8.5** | **-6.5** / **-8.5** |
| Chinook x2 | +0.0 | **+8.7** | +4.3 | **+8.7** |
| Laborer x2 | +0.0 | +0.0 | +0.0 | +0.0 |
| Laborer x4 | **-7.0** | -4.3 | -4.3 | -4.3 |
| truck x2 | +0.0 | +0.0 | +0.0 | +0.0 |
| truck x4 | -4.1 | -2.0 | -2.0 | **+5.9** (pile empty 589.1 s) |
| Chinook x4 | **-11.5** | +1.6 (pile empty 572.6 s) | **-7.7** | +0.4 (pile empty 587.2 s) |

| model | openings (of 8) | single (of 8) | MULTI + Chinook x4 (of 6) | total (of 22) | fails |
|---|---|---|---|---|---|
| hold | 4 | 8 | 4 | 16 | frc5 close, frc7 close, frc5 far, frc7 far, Laborer x4, Chinook x4 |
| split | 4 | 8 | 5 | 17 | usa2 close, usa2 far, frc7 close, frc7 far, Chinook x2 |
| c1 | 5 | 8 | 5 | **18** | frc7 close, usa2 far (net), frc7 far, Chinook x4 |
| c2 | 3 | 8 | 4 | 15 | usa2 close, china3 close, frc7 close, usa2 far, frc7 far, Chinook x2, truck x4 |

- Single-collector rows: c1 and c2 equal split and hold to the digit (all 32 cells pass, 8 rows x 4 models; lone cycles unchanged).
- Old window (reported, not judged) for Chinook x2, Laborer x2, Laborer x4, truck x2, truck x4, Chinook x4: c1 2922.9, 868.2, 1736.3, 1669.2, 2915.0, 2922.9; c2 2967.0, 868.2, 1736.3, 1669.2, 3081.3, 3074.2.
- c1 against hold gains frc5 close, frc5 far and Laborer x4 and loses usa2 far on net; against split it gains usa2 close and Chinook x2 and loses Chinook x4. Its margins are thin: Chinook x2 +4.3 %, Laborer x4 -4.3 % and frc5 far net -4.2 % pass by under one point (the last by one Laborer delivery, as for split), and usa2 far fails on net by 0.2 points (one Chinook delivery is 600 credits, 2.6 % of that row) while its steady rate passes at +4.3 %. Prediction against measurement (decision item 6): usa2 close 2880 predicted, 2880 measured; china3 close 2880 to 2940, 2940; frc5 close about 2070, 2085; Chinook x2 about 2880, 2880; usa2 far +4.3 %, +4.3 % steady.
- c2 is dominated: against split it gains nothing (split passes every row c2 passes); against c1 it gains only Chinook x4 (+0.4 % against -7.7 %). It overshoots truck x4 and Chinook x2 because 44 / 75 is shorter than the truck's and the Chinook x2 per-credit lock. Two of its judging rows (truck x4, Chinook x4) end early because the pile runs dry (flags in the table); none is short (under 450 s).

### Saturation curves, both sides

Steady credits per minute at n collectors on one pile and one depot, n = 1..8, 300-600 s after the gather order. Zero Hour: **measured (source build, fork a75330d82)**, 3 games per cell, `~/projects/wargrid-dock-work/c/zh/pooled.md` (96 games, 0 failed). Wargrid: **measured (Wargrid, branch tree 8761f66)**, one run per cell, `~/projects/wargrid-dock-work/c/wargrid-sweep.txt` (`WARGRID_DOCK_SWEEP=1`). Mapping: Laborer close = depot at 162.5 (gap 3), Laborer far = 312.5 (gap 9), truck = China at 312.5, Chinook = USA at 312.5. Cap = highest steady rate, n_cap = first n at the cap, n90 = first n at 90 % of the curve's own cap, spend90 = (n90 - 1) x collector cost (200 Laborer, 600 truck, 1200 Chinook; the first is free). Marginal(n) = steady(n) - steady(n-1), payback(n) = cost / (marginal / 60) seconds, build time excluded (**arithmetic**).

Cap (n_cap) / n90 / spend90. `>=` = the curve is still rising or linear at 8, so the cap is a lower bound set by the sweep range (n90 and spend90 inherit it; queue's far curve caps at 7, so it is exempt); `*` = the pile ran dry in the sweep (flag below).

| curve | Zero Hour | hold | split | c1 | c2 | queue |
|---|---|---|---|---|---|---|
| Laborer close | >= 3015 (8) / 7 / 1200 | 1605 (4) / 4 / 600 | >= 2700 (8) / 8 / 1400 | >= 2655 (8) / 7 / 1200 | >= 2700 (8) / 8 / 1400 | 1335 (4) / 3 / 400 |
| Laborer far | >= 1605 (8) / 8 / 1400 | >= 1440 (8) / 7 / 1200 | >= 1485 (8) / 8 / 1400 | >= 1470 (8) / 8 / 1400 | >= 1485 (8) / 8 / 1400 | 1320 (7) / 7 / 1200 |
| truck | 2940 (5) / 4 / 1800 | 2880 (6) / 4 / 1800 | 2940 (8) / 4 / 1800 | 2940 (8) / 4 / 1800 | 3117* (8) / 4 / 1800 | 2820 (5) / 4 / 1800 |
| Chinook | 3120 (4) / 4 / 3600 | 2760 (2) / 2 / 1200 | 3170* (3) / 2 / 1200 | 2880 (2) / 2 / 1200 | 3133* (3) / 2 / 1200 | 2640 (2) / 2 / 1200 |

Per-n marginals and paybacks for every curve are in the evidence files (`c/wargrid-sweep.txt`, `c/zh/pooled.md`). Payback (seconds) at n = 2 and at n90, and the first n whose payback exceeds 120 s (never = 'none by 8'):

| curve | n = 2 | at n90, Zero Hour | at n90, Wargrid models | first n over 120 s |
|---|---|---|---|---|
| Laborer close | 27.6 (all) | 33.3 | hold 40.0, split 38.1, c1 34.8, c2 38.1, queue 27.6 | Zero Hour, split, c2 none; hold 5; c1 8 (400 s); queue 4 |
| Laborer far | 57.1 (Zero Hour), 61.5 (Wargrid) | 57.1 | 66.7 to 80.0 | none, except queue 8 |
| truck | 42.9 (all) | 75.0 | hold 120.0, split 100.0, c1 100.0, c2 60.7, queue 120.0 | 5 in every model |
| Chinook | 54.5 (Zero Hour, hold), 46.2 to 60.0 | 200.0 | hold 54.5, split 46.2, c1 50.0, c2 46.2, queue 60.0 | 3 in every model |

Steady credits per minute per n (Zero Hour / hold / split / c1 / c2 / queue):

| n | Laborer close | Laborer far | truck | Chinook |
|---|---|---|---|---|
| 1 | 435 / 435 / 435 / 435 / 435 / 420 | 195 / 195 / 195 / 195 / 195 / 195 | 840 / 840 / 840 / 840 / 840 / 780 | 1440 each |
| 2 | 870 / 870 / 870 / 870 / 870 / 855 | 405 / 390 / 390 / 390 / 390 / 390 | 1680 / 1680 / 1680 / 1680 / 1680 / 1620 | 2760 / 2760 / 3000 / 2880 / 3000 / 2640 |
| 3 | 1275 / 1305 / 1305 / 1305 / 1305 / 1290 | 600 / 585 / 585 / 585 / 585 / 585 | 2400 / 2520 / 2520 / 2520 / 2520 / 2460 | 2760 / 2760 / 3170* / 2880 / 3133* / 2640 |
| 4 | 1725 / 1605 / 1650 / 1650 / 1650 / 1335 | 795 / 780 / 795 / 795 / 795 / 795 | 2880 / 2820 / 2880 / 2880 / 3113* / 2760 | 3120 / 2760 / 3170* / 2880 / 3133* / 2640 |
| 5 | 2115 / 1605 / 2055 / 2070 / 2055 / 1335 | 990 / 990 / 990 / 1005 / 990 / 1005 | 2940 / 2820 / 2880 / 2880 / 3114* / 2820 | 3120 / 2760 / 3170* / 2880 / 3133* / 2640 |
| 6 | 2475 / 1590 / 2265 / 2280 / 2265 / 1320 | 1200 / 1125 / 1140 / 1125 / 1140 / 1140 | 2940 / 2880 / 2880 / 2880 / 3116* / 2760 | 3000 / 2760 / 3170* / 2880 / 3133* / 2640 |
| 7 | 2835 / 1605 / 2385 / 2625 / 2385 / 1305 | 1395 / 1305 / 1335 / 1320 / 1335 / 1320 | 2940 / 2820 / 2880 / 2880 / 3116* / 2700 | 3120 / 2760 / 3170* / 2880 / 3133* / 2640 |
| 8 | 3015 / 1575 / 2700 / 2655 / 2700 / 1305 | 1605 / 1440 / 1485 / 1470 / 1485 / 1320 | 2940 / 2820 / 2940 / 2940 / 3117* / 2700 | 3120 / 2760 / 3170* / 2880 / 3133* / 2640 |

What the curves say (**arithmetic** on the cells above):

- **Laborer close:** hold's cap is the dock: flat at 1605 from the 4th worker, where Zero Hour has not capped at 8. Split, c1 and c2 move the cap to the sweep edge, 10 to 12 % under Zero Hour at 8 (-10.4 %, -11.9 %, -10.4 %). The close-depot cells for n >= 5 are noisy (below).
- **Laborer far:** hold, split, c1 and c2 do not cap before 8 and sit 4 to 10 % under Zero Hour at 7 and 8 (hold -6.5 % and -10.3 %, split -4.3 % and -7.5 %, c1 -5.4 % and -8.4 %); queue caps at 7 and is 17.8 % under at 8. Changing the lock barely moves it (far x8 goes from -10.3 % under hold to -7.5 % under split); it is the same far-depot gap as frc7 far, so the cause is probably outside the dock (not tested).
- **Truck:** every model has n90 = 4 and spend90 = 1800, as Zero Hour. Split and c1 reach Zero Hour's 2940 at n = 8; c2 overshoots (+6 %, pile empty).
- **Chinook:** Zero Hour needs 4 for its cap (n = 2 is 88.5 % of 3120, so n90 = 4, 3600); every Wargrid curve is already at 90 % of its own cap at 2, so n90 = 2 and spend90 = 1200 whatever the cap (the metric is relative to each curve's own cap). Against Zero Hour's 2760 at x2 and 3120 from x4: c1 +4.3 % and -7.7 %, split and c2 +8.7 % and +1.6 / +0.4 %, hold 0 % and -11.5 %. No single constant fits both, as before.
- **Metric 1 and 2 as reported:** hold's FRC 5th to 7th worker adds nothing (marginal 0, -15, +15), confirming the prediction in item 7; under split, c1 and c2 the 5th to 7th each add 120 to 420.

Flags and honesty:

- **Zero Hour:** no pile emptied in any of the 96 games and no window is short, so no Zero Hour cap is pile-limited.
- **Wargrid, pile empty (read `pile_empty=` in each sweep line; the `saturation` lines do not carry it):** split Chinook n >= 3 at 572.6 s; c2 Chinook n >= 3 at 587.2 s; c2 truck n = 4 to 8 at 589.1, 589.0, 588.9, 588.8 and 588.7 s. All other Wargrid cells keep the 30,000-credit pile to 600 s, no row is short. In those rows the dock-limited rate (3100 to 3170 per minute) drains the pile before 600 s, the steady window is 273 to 289 s instead of 300 s, and the 600 s net is pile-capped. The rate is flat in n: Chinook identical for n >= 3, c2 truck within 5 per minute for n = 4 to 8 (3112.8 to 3117.1; n = 3 is 2520 and does not empty the pile), so the caps `3170*`, `3133*` and `3117*` are the dock's rate. What is not observable is the 600 s net, and n_cap there is only 'smallest n at the pile-capped rate'.
- **Chinook in Zero Hour is quantised:** one delivery is 120 per minute over the 300 s window, so its marginals (0, 360, 0, -120, 120, 0 for n = 3..8) and its 200 s payback at n = 4 are delivery noise, not income; only 'cap near 3120 from n = 4' is stable.
- **Tiny positive marginals read as 'never':** c2 truck n = 5..8 marginals are 1.8, 1.1, 0.7 and 0.7 per minute, paybacks 20,000 to 50,000 s; treat as never, not as a number. Zero Hour truck n_cap = 5 and hold's n_cap = 6 hang on one delivery (60 per minute): truck n_cap is fragile in every model.
- **Zero Hour Laborer close is still bending at 8** (marginal 180 at n = 8 against 360 to 450 before; the three games spread 2955 to 3030) so its cap is a lower bound; **Laborer far is linear to 8** (195 per worker, +-15 per delivery), so its cap, n90 = 8 and spend90 are set by the sweep range, not by the dock.
- **Wargrid close-depot Laborer cells are scenario-sensitive.** The sweep uses the supply-parity layout (all collectors ordered on one tick); the INCOME rows use the opening scenario. Same model, same n = 7: split 2385 in the sweep against 2625 in the frc7 close opening, c2 the same, c1 2625 against 2550, hold 1605 against 1590. Within the sweep split rises by 120 from 6 to 7 and by 315 from 7 to 8. Read close-depot n >= 5 cells to about 10 %; the ordering of c1 and split at frc7 close flips between the two scenarios, so 'c1 is worse than split at frc7 close' is not established. Far-depot cells differ by one or two deliveries (frc7 far: opening 1290, sweep 1335 for split); the sweep shortfall at n = 7 (-4.3 % split, -6.5 % hold) is smaller than the opening's -8.5 %.

### frc7 phase shares: contention, 14 % against 7 %

The shortfall (decision item 6): under split the frc7 close pile bound is 3068 (75 x 1800 / 44) against 2625 measured. Question: what is the extra loss in Wargrid, 14.4 % where Zero Hour loses about 7 %? Here the pile is busy 84.7 % of the time in Wargrid (split) against 91.1 to 92.8 % in Zero Hour (**arithmetic** from phase shares, and **measured (source build, fork a75330d82)** lock occupancy), so idle pile time is about 15 % against 7 to 9 % (against the same bound the Zero Hour traces' own rates, 2760 to 2850, lose 7 to 10 %, 8.6 % at the median 2805; 'about 7 %' uses the income note's 2850; the 3039 in the earlier version of item 6 was a hand figure, see the research report).

Share of worker-ticks, steady window (Zero Hour: frames 300-600 s after the order, 7 workers x 3 games, `~/projects/wargrid-dock-work/c/frc7-zh.md`; Wargrid: the 7 workers of the frc7 close opening in 300-600 s while the pile has boxes, `phases frc7` lines of `~/projects/wargrid-dock-work/c/wargrid-sweep.txt`, **measured (Wargrid, branch tree 8761f66)**; c2 equals split to the digit):

| phase group | Zero Hour | hold | split (= c2) | c1 |
|---|---|---|---|---|
| flying (Zero Hour: speed > 0) | 42.8 | 34.8 | 61.3 | 59.7 |
| - heading to the pile (empty) | 22.2 | 18.2 | 25.7 | 26.1 |
| - heading to the depot (loaded) | 20.6 | 16.6 | 35.6 | 33.6 |
| standing without a lock (lead-in plus waiting) | 32.2 | 43.1 | 15.2 | 16.7 |
| - near the pile | 17.3 | 43.1 | 12.1 | 12.9 |
| - near the depot | 14.9 | 0.0 | 3.1 | 3.8 |
| loading (holds the pile lock) | 13.1 | 14.2 | 12.1 | 12.4 |
| unloading (holds the depot lock) | 11.7 | 7.6 | 10.8 | 10.6 |
| other (seeking; not observable in Zero Hour) | ~0.2 | 0.3 | 0.6 | 0.5 |
| pile busy (7 x loading, arithmetic) | 91.1 to 92.8 (measured occupancy) | 99.4 | 84.7 | 86.8 |
| of the standing share, waiting only | not separable | 43.1 | 2.4 | 4.8 |

Mapping caveats: Zero Hour cannot separate a lead-in from waiting behind another worker (no per-unit state column), so only the sum 'standing' is comparable; Zero Hour 'flying' is speed > 0, which includes pathing wiggle and queue shuffling, Wargrid's is until the unit reaches its arrival cell; the time bases differ (all 9000 frames against ticks while the pile has boxes); loading and unloading are lock shares in Zero Hour (the activeDocker) and exclusive stands in Wargrid.

Per trip, **arithmetic**: Wargrid steady rate / 75 per delivery / 7 workers gives 25.0 trips per worker per 300 s for split (12.0 s per trip), 24.3 for c1 (12.4 s), 15.1 for hold (19.8 s); Zero Hour 26.7 (mean trip 11.2 s; median 11.1 s over 541 gaps). The lone cycle (434.1 per minute in both) is 10.4 s. So contention adds 1.6 s per trip in split, 2.0 s in c1, 0.9 s in Zero Hour (0.7 s on the median trip). In split that is 0.3 s of waiting (2.4 % x 12.0 s) and about 1.3 s of flight (61.3 % x 12.0 s = 7.4 s against an estimated 6.1 s for a lone cycle, the cycle 10.4 s minus the 129-tick stand; not a measurement); c1 is the same (0.6 s waiting, 1.3 s flight). Hold's flight share gives 34.8 % x 19.8 s = 6.9 s, +0.8 s over the same estimate, but its pile is 99 % busy and its shortfall is the long lock.

What this supports and what it does not:

- **Supported:** the extra loss is not queueing at the docks (waiting is 2 to 5 % of a worker's time) and not the lock rule (split with 44 and c1 with 46 show the same pile occupancy and the same extra flight). It appears as about 1.3 s more flying per trip than the estimated lone-worker flight, and the pile sits idle about twice as long as in Zero Hour.
- **Not supported:** a cause. 'Not established.' Candidates from the code (unverified): longer paths or detours around other workers near the ring cells, a one-tick handoff delay per release, path-service latency. Zero Hour has no lone-worker breakdown here either, so whether its flight time also grows with contention is unknown, and the sweep above shows Wargrid's loss moves with the scenario (22 % at n = 7 in the sweep layout against 14 % in the opening).
- **What would settle it:** measured 2026-11-12, see [frc7 gap measurement](#frc7-gap-measurement-2026-11-12): one extra cell walked on one leg per trip.

### frc7 gap measurement (2026-11-12)

**Answer:** the frc7 shortfall is one extra cell walked per trip, not a dock lock rule. With several workers, one leg per trip walks one cell further (+43 ticks, 1.4 s), at gap 3 and gap 9, under hold (far), split and c1. Zero Hour's flight time does not grow with workers. No dock lock model closes frc7 close or far. *Recommendation (agent's):* look for the fix in movement or the arrival and exit cells near the docks. Design: `docs/superpowers/specs/2026-11-12-frc7-gap-design.md`, plan: `docs/superpowers/plans/2026-11-12-frc7-gap.md`, both on local branch `dock-hold` (not published).

Sources: Wargrid **measured (Wargrid, the tree that became d2d992b, for hold, split and the zone columns; c1 rows from the earlier probe state, 6638554 plus a diff with sha256 220aeee8, same gap and leg code)**, `DOCK <model> probe|swap|perturb` lines; Zero Hour **measured (source build, fork a75330d82)**, the existing sweep and `zh-open` traces plus three new `open_worker_u3125_x7` games (user approved, 2026-11-12). Lines, scripts and per-step verdicts: `~/projects/wargrid-dock-work/gap/` (`verdicts.md`, `wargrid-probe.txt`, `wargrid-probe2.txt`, `zh-probe.txt`, `zh-probe-far.txt`, `zh_probe.py`), outside the repository. Ticks and frames are both 1/30 s; per-leg values are medians.

Each candidate, kill check first:

| step | kill check | verdict |
|---|---|---|
| sweep against opening (split frc7 close: 2385 against 2625) | the opening's start positions and gather ticks moved into the sweep world | **explained:** 2625 on the opening's window, so the 240 per minute is the start state (production staggers the starts by 90 ticks). One unit started up to 21 ticks late lands on 2385 exactly: interpretation, not measured: Wargrid has several start-dependent steady states at n = 7. c1 runs the other way (opening 2550, sweep 2625, transplant 2610: 60 off, reported, not judged). Zero Hour's sweep and opening differ by 30 |
| one-tick handoff per release | the pile's free time between two holders while someone waits | **killed on magnitude:** by the plan's letter it survives (contended median 1 tick against Zero Hour's 0), but a worker already waiting takes the pile after a median 0 ticks under split (48 handoffs) and c1, 1 tick under hold: at most 1 tick per handoff against the +50 per trip. Split's idle pile (15.0 %) falls almost wholly (1310 of 1352 ticks) inside the unlocked 40-tick lead of a worker that arrived less than 40 ticks before the release: a symptom of late arrival |
| flight interference | flight ticks per leg, n = 1 against n = 7, both sides | **survives, Wargrid only:** Zero Hour moving per leg, empty / loaded, 74 / 74 to 72 / 70 (close) and 254 / 254 to 253 / 254 (far); lone Wargrid 81 moving against Zero Hour 74 is 7 frames, over the plan's 6-frame cut, but the lone cycles match (311 against 312), so the agent reads it as classification (Wargrid counts 9 flying ticks per leg without movement), not geometry; Wargrid one leg +43 flying ticks (+37 moving), the other unchanged |
| `blocked` 30-tick retries, path latency | count per trip | **killed:** 0 drops, 0 blocked, 0 `path_pending` ticks in every row |
| frc7 far lone travel | lone cycle at gap 9 | **killed:** 671 against 672 |
| frc7 far contention | n = 7 cycle against lone, both sides | **survives:** Wargrid 721 against 671; Zero Hour far opening 672 against 672 (no far contention at all) |

Per trip (split, medians; **arithmetic** for rates):

| scenario | Wargrid cycle | Zero Hour cycle | slow leg, Wargrid against lone | 7 x 75 x 1800 / cycle | measured |
|---|---|---|---|---|---|
| frc7 close opening | 361 | 332 | loaded 140 against 97 | 2618 | 2625 (Zero Hour 2846, measured 2805) |
| sweep close n = 7 | 395 | 330 | empty 193 against 131 (part waiting) | 2392 | 2385 |
| frc7 far opening | 721 | 672 | loaded 320 against 277 | 1311 | 1290 (Zero Hour 1406, measured 1410) |

Where the 43 ticks go (flying ticks split by thirds of the depot-to-pile axis; distance in cells; crowded = flying ticks with another unit within one cell): frc7 close loaded leg 16 / 117 / 0 against lone 16 / 74 / 0, distance 3.5 against 2.5, crowded 60 against 0; frc7 far loaded leg 76 / 125 / 112 against 76 / 125 / 69, distance 9.5 against 8.5, crowded 30. Far and split's sweep close (depot zone 67 against 24 on the empty leg) put the extra in the third next to the dock the worker just left; at gap 3 the pile-side third starts at x = 7.83 against the pile edge at 8, so frc7 close counts the pile end as "mid" and does not locate it. The path is one cell longer at the lone pace (32 moving ticks per cell). The slow leg is the loaded one everywhere except split's sweep close start (empty leg).

- **Supported:** one extra cell on one leg, near its start, at the lone pace, while within 1 cell of another unit (moving or standing; `crowded` does not tell which), costing the whole contention add except about 7 ticks; per-cycle travel without other workers matches Zero Hour.
- **Not established:** whether it is a detour around standing workers or a push by avoidance, and the rule behind it (occupied-cell avoidance in the route, the arrival-cell choice, or the exit cell). Next check: one leaving worker's cells against the standing workers' cells.

## Decision list for the user

Nothing here is decided. Recommendations are the agent's. The user's answers of 2026-11-12 (frc7 first, +5 % USA overshoot acceptable, metrics 1 and 2 as report rows) are in the [design answers](design-answers-2026-11-08.md#dock-option-c-follow-up-user-2026-11-12-night).

1. **Adopt split, adopt queue, or neither.** Hold fails 6 of 22 rows, split 5, queue 9 (scoreboard). Split leads hold by one row, and that rests on the frc5 far boundary flip (+75 net, one delivery). It closes frc5 close (net -1.3 %, steady equal) and Laborer x4 / Chinook x4, but overshoots usa2 (+12.6 % close, +7.8 % far), Chinook x2 (+8.7 %), and still misses frc7 close (-7.9 %) and frc7 far (-8.5 %). Queue fails 4 rows hold passes (usa2 close and far, china3 close, truck x4) and passes 1 hold fails (frc5 far). A clean adoption means rebuilding the model without a switch, with the lock windows as capability data (per kind: lead and exclusive length for source and depot) in `definitions/`, changed pinned economy traces and digests, and a ledger and benchmark row; the variant code is evidence, not a base. *Recommendation:* adopt neither as built. If the FRC gap must close, split is the only candidate worth rebuilding, and the Chinook E (item 5) should be settled first, because it decides the USA overshoot. Updated 2026-11-12: option C was measured (item 6) and c1 passes one row more than split, so it is the candidate to compare against split, not split alone. Adopted: c1, user 2026-11-12 night; rebuild plan [c1 dock rebuild](../superpowers/plans/2026-11-12-c1-dock-rebuild.md).
2. **B' (a queue fitted to the Zero Hour lock).** Fit B's lock to the measured medians (44 / 39, 184 / 46, 345 / 153) and put the rest of the lone cycle into an unlocked dwell at the approach spot: a second parameter per kind and target, which needs a spec change (the spec allows one in-dock time per kind and target). Expected, not run: it should reproduce split's numbers on saturated rows with a real queue instead of an abstract lead-in (it would lock the truck depot at 46 against split's 37, but the truck pile is the bottleneck, so rows probably match). *Recommendation:* do not; B' lands on split's results for more code and the same Chinook x2 / x4 conflict. Worth it only if a visible queue is wanted for play, which is a presentation decision, not an income one.
3. **New `MULTI` targets on the steady window** (income note item 2, a separate decision): Laborer x4 1590 to 1725, truck x4 2814 to 2940, the others within 1.8 % of today's. Changing them also means the gate must judge the steady window, not the old one (the local branch's (`dock-hold`, not published) `steady_rate` helper does that), and hold then fails Laborer x4 (1605 against 1725, -7.0 %) and Chinook x4 if gated (2760 against 3120): the suite goes red on the default model. *Recommendation:* make the change together with item 1, not before; changing it alone without a dock fix turns the suite red for no gain. Adopted: c1, user 2026-11-12 night; rebuild plan [c1 dock rebuild](../superpowers/plans/2026-11-12-c1-dock-rebuild.md).
4. **FRC bot collector count** (income note item 4, `bot_collectors_per_supply_center` 5). Zero Hour close depot: 7 workers earn 2850 against 2085 for 5. Wargrid today: 7 adds nothing (net 12,725 against 13,125). Split: 7 beats 5 by 26 % steady (2625 against 2085) and 4,475 net (21,875 against 17,400) for 400 more spent; queue: 7 is no better than 5 (1290 against 1305). *Recommendation:* decide with item 1; keep 5 until a dock model is adopted.
5. **Other rows the numbers show.**
   - Split's USA overshoot: usa2 close net 26,800 against 23,800 (+12.6 %, pile empty at 586.4 s), usa2 far 25,000 against 23,200 (+7.8 %), Chinook x2 steady 3000 against 2760 (+8.7 %). Cause: one Chinook lock for x2 and x4 (caveat above). Options: accept USA 2-Chinook income about 9 % above Zero Hour; a per-row-count lock (the per-row tuning the design forbids); or leave Chinooks on hold with split for Laborers and trucks only (by construction, not run: usa2 and Chinook x2 pass again as in hold, Chinook x4 stays at 2760 against 3120 and fails the rule on that row). *Recommendation:* the last, if split is rebuilt, because Chinook x4 is not an opening (the third Chinook is excluded, user, 2026-11-12) and the other two options trade one parity for another.
   - frc7 close under split, 2625 against 2850 (-7.9 %), and frc7 far under every model, 1290 against 1410 (-8.5 %). Measured 2026-11-12 ([frc7 gap measurement](#frc7-gap-measurement-2026-11-12)): one extra cell walked per trip on one leg with several workers, not the lock windows or the far-depot travel (lone cycles match). *Recommendation:* find the movement rule behind it before any dock adoption; no dock model changes frc7.
   - Hold's Chinook cap (2760 for x2 and x4 against 3120): shows only with a third Chinook, which stays out of the opening (user, 2026-11-12). Report only.

6. **Option C: one pile throughput for every collector (research, then measured 2026-11-12).** Source: an agent research report (OpenRA b4d95a5671, Zero Hour 0a05454, branch tree f534670), kept in the work folder `~/projects/wargrid-dock-work/research-report.md`; the predicted rates and locks below are arithmetic from the measured rows; the OpenRA bullet is code reading and the build-up proxy is interpolation on the net curves (not recomputed for c1 and c2). Result of the run ([section above](#option-c-and-saturation-2026-11-12), **measured (Wargrid, branch tree 8761f66)**): c1 (184 / 300) passes 18 of 22 rows, split 17, hold 16, c2 (44 / 75) 15; the predictions below held (usa2 close 2880, china3 close 2940, frc5 close 2085, Chinook x2 2880, usa2 far +4.3 % steady) except frc7 close, where contention costs what the next bullet said it would (2550 under c1 against the 2730 to 2905 predicted if fixed). Zero Hour holds a pile about 0.59 to 0.66 ticks per credit for every collector (Laborer 44 / 75, truck 184 / 300, Chinook 345 / 600 at x4 and 394 / 600 at x2). C makes that one constant: per-load box = `round(ceil(cargo_credits x 184 / 300) / loads)` ticks, pile lock = loads x box, the rest of today's stand an unlocked lead (lone rates unchanged by construction, lock at most the stand), depot locks as in split. Split is about 90 % of C: C changes only the Chinook pile lock (342 to 369) and the Laborer lock (44 to 46); truck stays 185.
   - Predicted steady rates: usa2 close 2880, china3 close 2880-2940, frc7 close 2730-2905 if the contention loss below is fixed (all within about 4.2 % of Zero Hour's 2880 / 2880 / 2850), frc5 close about 2070, Chinook x2 about 2880 (+4.3 % against the steady 2760, inside the rule narrowly). Cost: usa2 far moves from 0 % (hold) to +4.3 % (2880 against 2760), inside 5 % but worse than today; the cause is that Zero Hour's Chinook lock grows with depot distance (usa2 close implies at most 375 locked frames per visit, far about 391, measured 394) and no constant fits both. Using the x4 Chinook value (345) instead would give locks 351 / 175 / 44 (Chinook / truck / Laborer, as c2 builds them) and about +4 % on usa2 close and china3.
   - frc7 under split is not lock-bound: its pile bound is 3068 against 2625 measured, so Wargrid loses 14.4 % to worker contention where Zero Hour loses about 7 %. No lock rule fixes that; without the fix frc7 close stays near 2600 under C (measured: c1 2550, c2 2625). Cause measured 2026-11-12 ([frc7 gap measurement](#frc7-gap-measurement-2026-11-12)): one extra cell walked per trip on one leg with several workers (+43 ticks), the same under hold (far), split and c1; the handoff, retries and path latency are ruled out. The rule behind it is not established.
   - OpenRA gives no model: one harvester for all factions (identical data), a short unload-only refinery hold (about 30 ticks plus animations), no source-side lock (ore is claimed per cell), throughput set by dock count. It supports "keep the exclusive window short" and "throughput is a property of the dock".
   - Build-up proxy (income alone repaying a factory plus 5 main tanks after the opening is paid; interpolated on the net curves; not a played build order): Zero Hour 212-236 s per faction; Wargrid today FRC 312-327 s (frc5 312, frc7 327) against USA and China 218-236 s; split frc7 222 s (frc5 257 s). Missing: a played build order, army value per minute, multi-pile maps.
   - *Recommendation (agent's, nothing decided):* if a dock fix is adopted at all, compare c1 with split, not c2: c2 is dominated (it overshoots truck and Chinook x2, 15 of 22), and c1 is one formula instead of split's table but leads split by one row on thin margins (three passes within one point of the limit, usa2 far fails on net by 0.2 points). Neither touches frc7 close and far (-10.5 % and -8.5 % steady under c1); investigate those first (item 5, and the contention measurement above), because they decide whether any dock model is worth the rebuild. The user decides whether usa2 far may move to +4.3 % (c1) or must stay exact (split with Chinooks on hold's lock).

7. **Economy metrics (web research, not applied).** Source: an agent web research report (accessed 2026-11-12), kept in the work folder `~/projects/wargrid-dock-work/web-research-report.md`. Keep net credits at fixed seconds and the 300-600 s steady rate; the field samples the same kind of number (Blizzard's `s2protocol` stats event carries `m_scoreValueMineralsCollectionRate` and `m_scoreValueWorkersActiveCount`). Candidates to add, computed from what the tests already record (per-tick credits, deposits per collector, opening spend, definition costs), except that metrics 1 and 2 need a 1..N collector sweep, of which only the x1, x2 and x4 rows exist:
   1. *Saturated income per dock site and the spend to reach 90 % of it, per faction.* Cap = highest steady rate over 1..N collectors (the multi-collector rows); spend = depot plus collectors needed for 0.9 x cap. Stormgate balances its three asymmetric factions on the cap ("Maximum Luminite income per base across all three factions increased from 600 per minute to 750 per minute", as rendered by a page-fetch tool, not verified verbatim); the spend-to-90 % part is the agent's proposal, not Stormgate's.
   2. *Marginal income per extra collector and its payback.* marginal(n) = steady(n) - steady(n-1); payback(n) = cost / marginal(n) + build time. Liquipedia (secondary): "The first and second workers on a single mineral patch will each collect approximately 40 minerals per minute. The third worker will collect approximately 20 minerals per minute", "The 4th worker will not give you any additional income"; a worker returns its cost "92(±2) seconds after the initial investment is made", "153(±4) seconds" after 2 per patch. Under hold this would show FRC's 6th and 7th worker adding nothing (1590 for 5 and for 7).
   3. *Time to afford a faction-priced basket* (for example a factory plus N standard units): first tick where gross minus opening spend covers the basket cost from definitions; break-even is the empty basket. Answers "pace matches prices"; the basket is a design choice. The build-up proxy in item 6 is a first version.
   - *Result (2026-11-12):* metrics 1 and 2 were computed from a 1..8 sweep on both sides (section above). The cap and n90 separate the models (FRC close: hold caps at 1605 from the 4th worker, Zero Hour is at 3015 and still rising at 8; split, c1 and c2 reach 2655 to 2700), and hold's FRC 5th to 7th worker adds nothing as predicted. Limits: the caps of the two Laborer curves are lower bounds set by the sweep range; n90 and spend90 are relative to each curve's own cap (every Wargrid Chinook curve reads 1200 where Zero Hour reads 3600); Chinook marginals and payback above n = 2 are delivery noise in Zero Hour; tiny positive marginals give paybacks of thousands of seconds, which read as never; Wargrid close-depot cells at n >= 5 move by about 10 % with the scenario.
   - *Recommendation:* keep 1 and 2 as report rows, with the cap, n90 and spend90 per curve and payback only up to n90, and flag a pile that empties; 3 after a basket is chosen.
   - Sources: Stormgate patch 0.2.1, https://devtrackers.gg/stormgate/p/7521168e-stormgate-patch-0-2-1 (original https://steamcommunity.com/games/2012510/announcements/detail/723490878922949424); Blizzard `s2protocol`, https://github.com/Blizzard/s2protocol; StarCraft II mining and payback figures, secondary community wiki flagged by the wiki as outdated for the current time scale, https://liquipedia.net/starcraft2/Mining_Minerals. Spending Quotient was rejected (a player-skill metric, race-biased by its own wiki).

## Reproduce

Zero Hour half (`collect_*_s600`, lock windows in `analyze.py --json`): on main. Wargrid half (variants, `test_dock_models.gd`, `steady_rate`): local branch `dock-hold`, not published. Zero Hour: `python3 -I tools/zh_parity/parity.py --out DIR --repeats 3 --lanes 3 'collect_*_s600'` (headless, silent, fork a75330d82), then `python3 -I tools/zh_parity/analyze.py --json DIR/rep1 DIR/rep2 DIR/rep3`; lock windows from the dock grants in the traces (`lock_windows` in `tools/zh_parity/analyze.py`); the `open_worker_u1625_x5` / `x7` reruns give the Laborer locks. Traces and pooled tables: `~/projects/wargrid-dock-work/zh/` and `zh-open/` (18 + 6 jobs, 0 failed), outside the repository. Wargrid, on branch `dock-hold`: `WARGRID_TEST_ONLY=test_dock_models sh tools/run_tests.sh` prints the `DOCK` and `INCOME` lines for hold, split and queue (`WARGRID_DOCK_MODELS=split` for one; c1 and c2 run only when named: `WARGRID_DOCK_MODELS=hold,split,queue,c1,c2`, or `c1,c2` for just those); the lines behind this note are `~/projects/wargrid-dock-work/wargrid-hold.txt`, `wargrid-split.txt`, `wargrid-queue.txt`. Option C and saturation: `WARGRID_DOCK_SWEEP=1` adds the sweep, saturation and `phases frc7` lines to that run (rebuilding `wargrid-sweep.txt` exactly needs it together with `WARGRID_DOCK_MODELS=hold,split,queue,c1,c2`); the lines are `~/projects/wargrid-dock-work/c/wargrid-c1.txt`, `wargrid-c2.txt` and `c/wargrid-sweep.txt`; Zero Hour sweep and frc7 breakdown: `~/projects/wargrid-dock-work/c/zh/pooled.md` and `c/frc7-zh.md` (`analyze.py --saturation` over the three repeats), outside the repository. frc7 gap (2026-11-12): `WARGRID_DOCK_PROBE=1 WARGRID_DOCK_MODELS=hold,split,c1 WARGRID_TEST_ONLY=test_probe sh tools/run_tests.sh` prints the `swap`, `perturb` and `probe` lines (`game/tests/dock_probe.gd`); Zero Hour side `python3 -I ~/projects/wargrid-dock-work/gap/zh_probe.py TSV...` over `c/zh/rep{1,2,3}/collect_worker_u{1625,3125}_x{1,7}_s600.tsv`, `zh-open/rep{1,2,3}/open_worker_u1625_x7.tsv` and the new `gap/zh-open-far/rep{1,2,3}/open_worker_u3125_x7.tsv` (`parity.py --out ~/projects/wargrid-dock-work/gap/zh-open-far --repeats 3 --lanes 3 open_worker_u3125_x7`).

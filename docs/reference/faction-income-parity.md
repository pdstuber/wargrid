# Faction income parity: Zero Hour against Zero Hour, Wargrid against Zero Hour (2026-11-12)

Status: measured, evidence only; no game number changed. Plan: [faction income parity](../superpowers/plans/2026-11-12-faction-income-parity.md). Labels: **measured (source build, fork afcaaf198)** = Zero Hour, median of 3 games per row; **measured (Wargrid, tree c529912 plus the uncommitted steady-rate change in `game/tests/test_income_openings.gd`)** = one deterministic headless run per row (`INCOME` lines of that test, report only; `game/` simulation code is the same as at 7d319e3). Zero Hour names appear only here as evidence.

## The answers

1. **Is income even between factions in Zero Hour?** At the close depot (162.5 units): yes for three openings. USA 2 Chinooks, China 3 trucks and GLA 7 workers earn 2850 to 2880 per minute (within 1.1 %) and end 600 s with net 23,750 to 24,600 (within 3.6 %). GLA 5 workers earn 2085 per minute and net 17,625, 26 % to 28 % less than the others. At the far depot (312.5 units) not even USA and China are level, and GLA is far behind: net at 600 s is 23,200 (USA), 20,100 (China, 13 % less), 10,400 (7 workers) and 7,200 (5 workers).
2. **Does Wargrid reproduce it?** Net at 600 s (gross: close -22.8 % / -42.0 %, far -4.0 % / -5.8 % for FRC 5 / 7 workers): USA and China, yes for these openings, every row within 3.0 % of Zero Hour (steady rate within 4.2 %, one Chinook delivery in the 300 s window is 4 %). But usa2 (both depots) and china3 (close) run at Wargrid's per-pile cap (candidate 1: the hold of 9 x 43 ticks per Chinook visit and 5 x 38 per truck visit, 2791 and 2842 per minute); Zero Hour's 2-Chinook and 3-truck rates happen to land just above them, so a larger opening would fall short (Chinook x4 2787 against 3116 on record). FRC far depot: 5.2 % and 7.2 % short in net, 4.5 % and 8.5 % in steady rate, borderline. FRC close depot: **no**, net 25.5 % short with 5 workers and 46.4 % short with 7 (steady rate 23.7 % and 44.2 %), and Wargrid earns the same 1590 per minute with 5 and with 7. The gap sits in the dock model above 4 workers; candidates below, nothing decided.

## Setup (both sides)

One 400-box `SupplyDock` pile, depot at 162.5 or 312.5 units centre to centre (Wargrid gaps 3 and 9). Start money 10,000, prerequisite plants complete before t = 0, t = 0 is the depot build order, 30 frames or ticks per second. Openings (count includes the free collector the depot spawns): `usa2` Supply Center + 1 Chinook (3200 spent), `china3` Supply Center + 2 trucks (2700), `frc5` Cache/Stash + start worker + 3 trained (2100), `frc7` + 5 trained (2500). Spend and costs agree on both sides (Wargrid definitions equal the retail INI values listed in the plan). Gross = credits deposited, net = gross minus opening spend, steady = credits per minute from 300 s to 600 s after the order, the same fixed window on both sides (it replaces the first version, which started at the last collector's first deposit and ended on Wargrid at the last deposit). The pile never ran dry inside 600 s in any row, both sides. Zero Hour traces use a random player side (for example a "China" player building the GLA stash), harmless here (spreads at most 3.0 %).

Harness additions this needed: a `dock` verb in the fork (commit afcaaf198, local) because the GLA start worker never gathers on its own after building the stash; the opening scenarios `open_*` in `tools/zh_parity/parity.py` and `opening_curve` in `tools/zh_parity/analyze.py`. Deposits are credited to the collector that stood loaded at the depot longest (position-based; an earlier nearest-to-depot rule credited the wrong collector, which left the numbers but not the per-collector counts right). Trips per collector from the fixed attribution are 49 to 54 per worker in 600 s at the close depot (frc5 50-54, frc7 49-53) and 24 to 26 at the far depot, evenly spread, so every worker delivers in every game.

## Tables

Net credits at fixed seconds after the depot order, steady rate (credits per minute, 300 s to 600 s), time at which net turns positive. The delta rows are Wargrid against Zero Hour.

### Close depot (162.5 units)

| Opening | Source | net 60 s | 120 s | 180 s | 300 s | 600 s | steady per min | break-even s |
|---|---|---|---|---|---|---|---|---|
| usa2 | ZH | -2,000 | 1,000 | 4,000 | 9,400 | 23,800 | 2880 | 99 |
| usa2 | Wargrid | -2,000 | 1,000 | 4,000 | 9,400 | 23,200 | 2760 | 101 |
| | delta | | | | +0.0 % | -2.5 % | -4.2 % | +2 s |
| china3 | ZH | -1,200 | 1,500 | 4,500 | 10,200 | 24,600 | 2880 | 86 |
| china3 | Wargrid | -1,500 | 1,500 | 4,200 | 9,900 | 24,000 | 2820 | 86 |
| | delta | | | | -2.9 % | -2.4 % | -2.1 % | +0 s |
| frc5 | ZH | -1,275 | 900 | 3,000 | 7,125 | 17,625 | 2085 | 94 |
| frc5 | Wargrid | -1,275 | 375 | 1,950 | 5,175 | 13,125 | 1590 | 105 |
| | delta | | | | -27.4 % | -25.5 % | -23.7 % | +11 s |
| frc7 | ZH | -1,600 | 1,175 | 4,025 | 9,650 | 23,750 | 2850 | 94 |
| frc7 | Wargrid | -1,675 | -25 | 1,550 | 4,775 | 12,725 | 1590 | 122 |
| | delta | | | | -50.5 % | -46.4 % | -44.2 % | +28 s |

### Far depot (312.5 units)

| Opening | Source | net 60 s | 120 s | 180 s | 300 s | 600 s | steady per min | break-even s |
|---|---|---|---|---|---|---|---|---|
| usa2 | ZH | -2,000 | 1,000 | 4,000 | 9,400 | 23,200 | 2760 | 102 |
| usa2 | Wargrid | -2,000 | 1,000 | 3,400 | 9,400 | 23,200 | 2760 | 103 |
| | delta | | | | +0.0 % | +0.0 % | +0.0 % | +1 s |
| china3 | ZH | -1,800 | 600 | 3,300 | 7,800 | 20,100 | 2400 | 101 |
| china3 | Wargrid | -1,800 | 600 | 3,000 | 7,800 | 19,500 | 2340 | 103 |
| | delta | | | | +0.0 % | -3.0 % | -2.5 % | +2 s |
| frc5 | ZH | -1,800 | -825 | 225 | 2,250 | 7,200 | 1005 | 164 |
| frc5 | Wargrid | -1,725 | -675 | 150 | 2,025 | 6,825 | 960 | 165 |
| | delta | | | | -10.0 % | -5.2 % | -4.5 % | +1 s |
| frc7 | ZH | -2,200 | -850 | 575 | 3,350 | 10,400 | 1410 | 157 |
| frc7 | Wargrid | -2,050 | -700 | 650 | 3,200 | 9,650 | 1290 | 153 |
| | delta | | | | -4.5 % | -7.2 % | -8.5 % | -4 s |

Reading notes:

- Gross at 600 s, Zero Hour against Wargrid: usa2 27,000 / 26,400 (close), 26,400 / 26,400 (far); china3 27,300 / 26,700, 22,800 / 22,200; frc5 19,725 / 15,225, 9,300 / 8,925; frc7 26,250 / 15,225, 12,900 / 12,150.
- The checkpoints at 60 to 300 s move in whole deliveries (a truck delivery is 300, a Chinook 600, a Laborer 75), so single rows differ by one delivery without meaning anything: gross (not the net shown in the tables) china3 close at 60 s is 1,500 in Zero Hour against 1,200 in Wargrid, usa2 far at 180 s 7,200 against 6,600; "frc far 300 s -10 %" is 3 Laborer deliveries (225) of a small base, the same effect. The 600 s net and the steady rate are the comparison. The steady rate has the same granularity over its 300 s window: one Chinook delivery is 120 per minute (4 %), which is why usa2 close reads -4.2 % with 24 against 23 deliveries.
- Zero Hour spread over the 3 games (max minus min over the median): steady rate at most 3.0 %, gross at 600 s at most 2.0 %, break-even time at most 5.1 %. The one row above 5 % is `china3` close depot break-even (5.1 %, 85.5 s median; steady 2.1 %, gross 1.1 %); Wargrid's 85.9 s sits inside it. Reported, not hidden; it changes no answer.
- Zero Hour traces and the pooled tables: `~/projects/wargrid-income-work/zh/rep{1,2,3}/`, `pooled-zh-v2.txt` (fixed-window steady rate and trips per collector; the first version `pooled-zh.txt` used the first-deposit window), outside the repository (24 jobs, 0 failed). Reproduce: `python3 -I tools/zh_parity/parity.py --out DIR --repeats 3 --lanes 3 'open_*'`, then `python3 -I tools/zh_parity/analyze.py --json DIR/rep1 DIR/rep2 DIR/rep3`. Wargrid: `WARGRID_TEST_ONLY=test_income_openings sh tools/run_tests.sh` prints the `INCOME` lines (suite file passes; full suite on this tree green, exit 0).
- Moving the steady window from "last collector's first deposit" to the fixed 300-600 s changed no answer: Zero Hour moved by up to 2.6 % (usa2 close 2807 to 2880), Wargrid by up to 2.0 % (frc5 far 941 to 960); the net-at-600 s answers stand and the steady deltas shifted by up to 3.5 points (usa2 close -0.7 % to -4.2 %, frc7 far -7.0 % to -8.5 %). The old Zero Hour start was also wrong for another reason (misattributed first deposits); both are fixed.

## What the numbers say beyond the two answers

- **The "7 workers" rule is supported by Zero Hour at the close depot.** `frc7` matches USA and China (steady 2850 against 2880 and 2880, net at 600 s 23,750 against 23,800 and 24,600) and adds 6,125 net over `frc5` for 400 more spent, with the same break-even (94 s). At the far depot 7 beat 5 by 44 % in net at 600 s (10,400 against 7,200), still far below USA and China.
- **Wargrid cannot show that.** At the close depot its `frc7` is below its own `frc5` in net at 600 s (12,725 against 13,125): the two extra workers cost 400 and add nothing, because both rows sit on 1590 per minute. At the far depot Wargrid shows the Zero Hour pattern (`frc7` +41 % net over `frc5`: 9,650 against 6,825; steady ratio 1.34 against 1.40 in Zero Hour).
- **Wargrid bots build 5 collectors per supply center for FRC** (`bot_collectors_per_supply_center` in `game/scripts/simulation/definitions/factions.gd`; USA 2, China 3), the `frc5` row. Two more would add nothing today (above).
- **Zero Hour scales almost linearly per worker.** From the trips per worker (49 to 54 in 600 s close, 24 to 26 far) and the steady rates: 2085 / 5 = 417 and 2850 / 7 = 407 per worker per minute against 434 for a lone worker ([supply parity measured](m7-supply-parity-measured.md)), i.e. 4 % and 6 % contention at 5 and 7 workers. Not a held pile.
- **The earlier "1602 against 1590 up to 4 workers" is a coincidence, and the old Zero Hour x4 figure is the outlier.** Wargrid x4 laborers already sat on the same cap as x5 and x7 (x4 1602, x5 1604, x7 1604 on the first-deposit window): one lone cycle is about 311 ticks and 311 / 84 = 3.7 workers saturate the pile. Wargrid's fixed-window 1590 for x5 and x7 equals the gated Zero Hour x4 number by coincidence, not by the same measurement. The Zero Hour 1590 ([economy archive](m7-verification-archive-economy.md) T3 record, [supply parity measured](m7-supply-parity-measured.md)) came from `collect_*`, whose window runs from the free worker's first deposit to the 32nd deposit (`deposits * collectors`): about 80 s that include the ramp-in of the trained workers (90-frame build each, then the walk). On the four non-builder workers of this sweep's frc5 close traces, that same window gives 1633 / 1621 / 1549 and their 300-600 s rate 1650 / 1665 / 1695, while they share the pile with a fifth worker; so a true Zero Hour x4 steady rate is about 1650 to 1740 (upper bound 4 x 434) and the old window understated it by about 3 to 8 %. The 3.66x reading in `m7-supply-parity-measured.md` ("a held pile fits") is refuted: an x5 rate of 2085 is impossible with an exclusive 84-tick hold, which caps at 1607. The gated target in `test_supply_parity.gd` (MULTI `frc_builder` x4 1590 +-5 %, ceiling 1669.5) is therefore probably too low, and a dock fix that is right could fail it; it is a decision item below, the test is unchanged.

## Candidate causes for the FRC close-depot gap (read from code and INI, not tested, not decided)

Facts first:

- Wargrid FRC close depot: 1590 per minute on the fixed window with 5 workers and with 7 (1604 and 1602 on the first-deposit window with 5, 7 and 4). 1604 per minute is 21.4 deliveries of 75, one per 84 ticks. Zero Hour `frc7` reaches 2850 per minute, one delivery per 47 frames at the pile and at the depot.
- Wargrid serialises per target: one active collector per pile and per depot (`game/scripts/simulation/supply_collection.gd` `_admit`, `target.active_collector_id`, line 146; `_ahead` line 121). The collector holds the pile for `load_ticks` per box, then once more for the "one more delay" after the last box (line 180) before it releases, so a visit holds it (boxes + 1) x `load_ticks`: Laborer 2 x 42 = 84 ticks per 75 credits (1607 per minute), truck 5 x 38 = 190 per 300 (2842), Chinook 9 x 43 = 387 per 600 (2791). Unloading holds the depot `unload_ticks`: Laborer 45 (caps at 3000 per minute).
- Zero Hour also has one active docker per dock (`DockUpdate.cpp` `m_activeDocker`, `update()` lines 415-428 granting at 424, cleared at `onExitReached` lines 355-375, clear at 366; ZH `0a05454`, `~/projects/CnC_Generals_Zero_Hour/GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Update/DockUpdate/`). The exclusive window runs from the clearance grant through MoveToEntry, Dock, ProcessDock and MoveToExit to `onExitReached` (`AIDock.cpp` 53-60, 756); the approach is not exclusive. So serialisation alone is not the difference. A queue of approach positions lets the next docker wait ready: `reserveApproachPosition`, `advanceApproachPosition`, `isClearToAdvance` (lines 136-231).
- Approach positions in the retail INI: `SupplyDock` (the pile) `NumberApproachPositions -1` (`civilianbuilding.ini:504`), China Supply Center `-1` (`factionbuilding.ini:21289`), GLA Supply Stash `-1` (`factionbuilding.ini:19975`), America Supply Center `9` (`factionbuilding.ini:18781`). `-1` is `DYNAMIC_APPROACH_VECTOR_FLAG`: unlimited, a new position is appended per waiting docker (`DockUpdate.cpp:167-180`); a position-less dock biases the position toward the caller (`computeApproachPosition`, around line 456-467; whether the stash has no bones is not verified from source).

Candidates:

1. **Exclusive hold too long (pile and depot).** Wargrid's `load_ticks` 42 and `unload_ticks` 45 for the Laborer were calibrated so that one worker's whole cycle matched Zero Hour (archive T3 record: laborer 5/5 became 42/45; the worker INI delay is 150 ms, `glainfantry.ini:3762-3763`; the lone worker stands about 84 frames at the pile and 79 at the depot, [supply parity measured](m7-supply-parity-measured.md) worker row). Held exclusively per target, the pile stand caps the pile at one delivery per 84 ticks (arithmetic above). Zero Hour's exclusive window per delivery is at most 47 frames (from 2850 per minute). Position probe on the frc5 and frc7 close traces (stationary nearer the pile): 2 or more workers stand at the pile in 45 % and 86 % of occupied frames, the median pile stand is 84 and 91 frames, yet departures from the pile come every 43 to 50 frames; stands overlap and the exclusive part is at most about 44 to 48 frames. What the rest consists of (state transitions, path-request latency) is not established. If the pile hold were shortened, the next cap is the depot hold: Laborer 45 ticks caps at 3000 per minute and Zero Hour `frc7` (2850) is 95 % of that, so Wargrid would still queue hard there. The experiment must therefore treat both holds. Trucks and Chinooks carry the same cost, see "Wargrid per-pile caps" below.
2. **Dock spots.** Wargrid's ring-cell claim with a 0.25-cell offset (`_claim_dock`, `_arrival`, lines 50 and 29-35) against Zero Hour's bone or boneless approach positions. Affects travel length, i.e. the far-depot residual, not the saturation cap.
3. **Far-depot residual (5 % to 9 %).** Not saturation: Wargrid far frc7 over frc5 is 1.34 against 1.40 in Zero Hour, and per worker 192 against 201 per minute at 5 workers (960 / 5 against 1005 / 5): a per-cycle length difference. Not investigated; travel distance or arrival spots are the candidates.

Wargrid per-pile caps (same hold, other collectors): Chinook 9 x 43 ticks per 600 credits gives 2791 per minute, truck 5 x 38 per 300 gives 2842, Laborer 2 x 42 per 75 gives 1607. `usa2` Wargrid is 2760 at both depots (23 deliveries in 300 s, the cap rounded down to whole deliveries) and the archive has the same cap for Chinook x2 and x4 ([economy archive](m7-verification-archive-economy.md) T3: Chinook x4 2787.1 against Zero Hour 3116, report only). `china3` close Wargrid is 2820 against a 2842 cap (archive truck x4 2838 against 2814). USA and China agree with Zero Hour only because Zero Hour's 2-Chinook and 3-truck openings land just above those caps (2880); a third Chinook or fourth truck would show the same gap as FRC. The experiment on candidate 1 will move the `usa2` and `china3` rows too.

Related, not isolated by these rows:

- **Chinook full load.** The open item in [M7 verification](m7-verification.md) (Zero Hour waits for a full load, Wargrid air does not apply it) cannot show here: `usa2` loads full 8-box cargo from a 400-box pile in both games and agrees within 2.5 % in net. The item stays open.

## Decision list for the user

Numbers are Wargrid against Zero Hour at 600 s. Items 1, 2, 3 and 5 are decided (user, 2026-11-12); items 4 and 6 stay open.

1. **FRC close-depot income** (net 13,125 against 17,625 with 5 workers, 12,725 against 23,750 with 7; 1590 per minute in both Wargrid rows on the fixed window). Options: (a) accept as is and keep FRC deliberately slower; (b) a measured experiment on the dock hold, both the pile hold and the depot unload hold (candidate 1), judged against these eight rows plus `test_supply_parity.gd`, no number change until the rows are in; it will also move `usa2` and `china3`, and the third-Chinook opening is where the cap would show; (c) retune FRC `load_ticks` / `unload_ticks` only (cheap, but it would break the single-worker match that is gated today). Recommendation: (b), because (c) trades one parity for another and the gap is a model difference, not a number. **Decided (user, 2026-11-12): (b)**, a measured dock-hold experiment on both holds; no number changes until its rows are in. Before it is judged against `test_supply_parity.gd`, re-measure its Zero Hour x4 target (item 2).
2. **Gated x4 target** (`test_supply_parity.gd` MULTI `frc_builder` x4 1590 +-5 %): probably too low (true Zero Hour x4 about 1650 to 1740, above). Re-measure on a steady window before it constrains item 1; the test is not changed here. **Decided (user, 2026-11-12): re-measure first**; any change of the target is then a separate decision.
3. **Openings as the reference** (user, 2026-11-12, decided): `usa2`, `china3`, `frc5`, `frc7`, no third Chinook. Other openings (for example a third Chinook, excluded by that approval) are another sweep (about 13 minutes of wall time for the Zero Hour side).
4. **Bot collector count for FRC** (`bot_collectors_per_supply_center` 5). If the dock model changes, 7 is the number Zero Hour supports at the close depot; decide with item 1, not before. Today 7 would not help.
5. **Far-depot FRC 5 % to 9 % short.** Accept (borderline, inside what the earlier per-collector parity tolerated) or fold into item 1. Recommendation: fold in; do not chase it separately. **Decided (user, 2026-11-12): folded into item 1.**
6. **Chinook full load** stays open; no row here depends on it. **Harness fork commit** afcaaf198 (the `dock` verb) is local to the fork checkout and not pushed.

# M4 scenario envelope — measured 2026-11-03

Status: **MEASURED ON EXISTING M3 ECONOMY WITH TEMPORARY M4 DEFINITIONS; NO COMBAT**. Informs Task 7 calibration and Task 4/5 cost decisions. It is not a gate and real combat will change army sizes and timing. Machine: Apple M6, Godot 4.7.2, headless. Code state: `main` at `09b6516` plus the uncommitted Step A refactor of `simulation.gd` (behavior-preserving; suite 97 / 101,355).

## Method

Scratch copy of `game/` (outside the repo) with the Task 1 definitions added temporarily: infantry 225 / 150 ticks / speed 0.8, tank 900 / 300 / 1.2, barracks 600 / 300 ticks / 2×2 / no prerequisite. Script: [m4-envelope-spike.gd.txt](m4-envelope-spike.gd.txt) (copy it into a scratch project next to those definitions; not part of the game project). One simulation, 48×32 map, two mirrored players, builders at `(4.5,14.5)` / `(43.5,14.5)`, supply sources at `(5,3)` / `(40,3)` with 200 boxes, 10,000 credits each, fixed sites from the plan (player 2 mirrored about x = 24). Both players follow the opponent policy from the plan through ordinary commands only: every 30 ticks build the next absent of reactor, depot, barracks, factory (resume an unattached foundation first), and queue one infantry per barracks and one tank per factory when affordable and the queue is empty. No army orders: units stay where they spawn.

## Economy timeline (identical for both players; deterministic and symmetric)

| Event | Tick |
|---|---:|
| reactor completed | 400 |
| depot completed (also grants the free collector) | 870 |
| first deposit | 1,285 |
| barracks completed | 1,345 |
| factory completed | 2,000 |

Builder walking adds about 100 to 200 ticks per site on top of the build time, plus up to 30 ticks of decision cadence.

| Tick | Credits | Infantry | Tanks | Source boxes left |
|---:|---:|---:|---:|---:|
| 600 | 7,200 | 0 | 0 | 200 |
| 1,800 | 5,125 | 3 | 0 | 182 |
| 3,000 | 1,975 | 8 | 3 | 160 |
| 5,400 | 475 | 8 | 9 | 112 |
| 7,200 | 775 | 8 | 11 | 78 |
| 9,000 | 3,175 | 8 | 11 | 42 |
| 10,200 | 4,975 | 8 | 11 | 19 |

Income is about 1.33 credits per tick from the single collector (181 boxes in 10,200 ticks); neither source is empty by tick 10,800.

## Findings that change how Task 7 should be written

1. **Production stops by itself at 8 infantry and 11 tanks.** Produced units stay on the producer's perimeter and the queue head waits for a free cell (existing M3 behavior, "blocked exits"). A 2×2 barracks has 8 perimeter cells; the 3×3 factory has 12, minus the cell the idle builder occupies. Credits then pile up (5,575 unspent at tick 10,800). Unless a script relocates units, armies before the first attack are at most 8 infantry + 9 tanks at tick 5,400 and 8 + 11 at tick 9,000.
2. **Armies are tiny, about 19 units per side.** The 5400 opponent attack sends about 17 units. Do not expect 150-unit battles in the scenario; the 150 v 150 workload belongs to the Task 9a benchmark only.
3. **Travel is long relative to the window.** Empty-map front-to-front distance (19 cells, barracks `(14.5,12.5)` to the enemy barracks side `(33.5,12.5)`): infantry 713 ticks, tanks 475 ticks. Real routes around buildings are longer. Infantry are slower than tanks, so a mixed group arrives staggered, tanks first. A human attack starting at 9,000 arrives about 9,500 to 9,750 at the earliest and leaves roughly 1,000 ticks to destroy a builder, depot, barracks and factory before tick 10,799. The plan's calibration range "start within 9000..10500" is infeasible at its upper end; **start 9000..9800 is the workable range** (plan corrected, see Task 7 notes).
4. **No combat unit exists before about tick 1,500 (infantry: barracks done at 1,345 plus 150 ticks of work) and about 2,300 (first tank: factory done at 2,000 plus 300).** An opponent attack order before then has nothing to send; 5,400 is well after both.

## Costs measured for known behaviors (documented, not fixed)

| Measurement | Result |
|---|---|
| Ticks with units waiting for routes after one building or source is removed while 150 units move (64×64 map) | 19 ticks, peak 150 units pending (8 queries per tick) |
| `Allocation.assign` per call, 48×32 map | 2.2 ms (20 units), 2.4 ms (150 units) |
| `Allocation.assign` per call, 64×64 map | 6.0 ms (20 units), 6.3 ms (150 units) |
| Wall time of the 10,800-tick economy run, about 20 entities | `step` 2.4 s total, `snapshot` 0.4 s total (snapshot every tick) |

- Allocation cost is dominated by sorting the whole map component, not by unit count. Calling it once per unit would cost about 150 × 2.4 ms = 360 ms on the 48×32 map. At the assumed 6× slower target ([ledger](performance.md)) a single call is about 14 ms. Resume of attack-move groups must batch by goal.
- A destroyed building (or destroyed source) stalls every moving unit for up to 19 ticks. That is the existing `_replace_union` behavior and will happen in M4 matches; Task 5 and Task 7 should not assert uninterrupted movement through a building death.
- Task 7's loop cost: two worlds with a snapshot per tick are about 2 × (2.4 + 0.4) = 5.6 s plus the deep equality of snapshots, which was not measured. The local suite gate is 30 s total (ledger); measure the first 1,000 ticks of the real scenario before writing the full comparison.

## Not measured

Combat outcomes, the real `Combat` cost, behavior with units relocated off perimeters, obstacle-aware routes between the real base layouts, collector count above one, other maps, other machines.

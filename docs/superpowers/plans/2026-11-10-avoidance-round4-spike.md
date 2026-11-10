# Avoidance Spike Round 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** approved (user, 2026-11-10), running. **Narrowed (user, 2026-11-10):** only `s1` and `s3` are built; Tasks 3 and 4 (`s1x`, `s2`) are skipped because the user decided units will path on a finer grid and drive at any angle (design answers, "After round 3"), which makes the one-cell blocking rules moot. `s3` builds directly on `s1`; measurements compare `r0`, `r1t`, `s1`, `s3`. Evidence only: no design decision, no merge, nothing on `main` but this plan and notes.

**Goal:** Measure whether Zero Hour's goal layout, its crossing rule, a no-room fallback and a column slice make packed group moves finish under the cost cap, and let the user see how each feels.

**Architecture:** Four cumulative variants on top of round 3's R1t, each a mode of `Avoidance` so one tree runs all of them: `s1` (goals laid out front-first, routes requested nearest-first), `s1x` (`s1` plus crossing movers pass after 1 s), `s2` (`s1x` plus goal swap with a standing friend), `s3` (`s2` plus column moves on a shared lane route). Modes `""` and `r1t` must stay byte-identical to round 3's traces, which proves the new code is inert when off.

**Tech Stack:** typed GDScript (Godot 4.7.2 headless), the jam harness `game/benchmarks/run_avoidance.gd`, round 3's helper scripts (`AW3/scripts/`), Python 3 for tables.

**Spec:** [design answers](../../reference/design-answers-2026-11-08.md), "Unit avoidance: behaviour", sub-list "After round 3 (brainstorm)". Evidence the design rests on (outside the repo, read-only): `~/projects/wargrid-overnight-work/avoidance/brainstorm/research.md` (subagent) and `research-main.md` (main session). Rounds 1 to 3: `docs/reference/unit-avoidance-spike.md` on `spike-avoidance`.

**Model routing:** one fresh Sonnet (high) implementer per task; a fresh-context reviewer on the strongest model for the final note; the coordinator makes every commit.

## Global Constraints

- Worktree `~/projects/wargrid-wt-avoid`, branch `spike-avoidance` (head `b3bf208`). Rebase onto current `main` first (docs-only delta). Never switch the main checkout's branch. Local commits per task by the coordinator; subagents never commit; never push or merge.
- `AW4` = `~/projects/wargrid-overnight-work/avoidance/round4` (raw data, logs, trees, scratch checks). Nothing from it goes into the repo. `AW3`, `AW2` and round 1's `AW` are read-only; copy scripts into `AW4/scripts/`.
- No test file changes. Failing suite lines are listed with what changed; the user decides per test before the milestone.
- Cap (user): median-of-3 delta p95 against r0 at most +0.500 ms on all six rows (HEADLESS open and dense with round 3's four-group legs, COMBAT docks, open, dense, `hordes300`); no noise allowance. Never loosen a budget, cap or ceiling; report exceeded values.
- Quiet machine: no World of Warcraft; `uptime` and the WoW check before and after every timed run; a loaded run is repeated, never judged.
- One Godot process at a time (lock directory `AW4/godot.lock`); every suite, benchmark and harness call with output to a file and tool timeout 600000; scratch Godot scripts inside the tree's `game/` (untracked), `quit()` on every path.
- Typed GDScript; `sh tools/run_lint.sh` and `sh tools/run_warnings.sh` pass on every code commit. Known limits get a `# shortcut:` comment.
- `s1x` contradicts the user's "about 5 s" last resort for crossing movers. It is built as a measured variant only; the rule stays the user's to decide after the results.
- Browser only if a variant passes all six native rows, and then stop and ask first. Steam Deck: the user, after a native pass.

## Review Focus

- **Inert when off.** Modes `""` and `r1t` on the final tree give traces byte-identical to `AW3/traces/r0-1` and `AW3/traces/r1t-1` on all 15 scenarios. Checked after every code task.
- **Mechanics fire inside the measured window.** Each cost and jam row reports `reordered`, `cross_passes`, `swaps`, `columns`; a variant row where its own counter is 0 is reported as "mechanic did not run", not as a pass.
- **Like for like.** Next to every cost delta: legs issued and finished (HEADLESS), shots and deaths (COMBAT). A row where the variant does different work than r0 is marked so.
- **Swap keeps the reservation rule.** After every tick of the swap check: destination cells unique, no unit without an order that had one, the same pair never swaps twice in a row.
- **Orders that must not change.** One-unit orders, units with no reachable goal (`null`), air units and a click inside the group behave as on R1t.

---

### Task 1: Setup, mode flags, counters

**Files:**
- Modify: `game/scripts/simulation/avoidance.gd` (`set_mode`, `STATS`), `game/benchmarks/run_avoidance.gd` (print the new counters)
- Create (outside repo): `AW4/context.md` (places and rules, as `AW3/context.md`), `AW4/scripts/*`

**Interfaces:**
- Produces: `Avoidance.goal_order: bool`, `Avoidance.cross_pass: bool`, `Avoidance.swapping: bool`, `Avoidance.columns: bool`, set by `set_mode`: `s1` → goal_order; `s1x` → goal_order, cross_pass; `s2` → those plus swapping; `s3` → goal_order and columns; every other mode → all false. New `STATS` keys `reordered`, `cross_passes`, `swaps`, `columns`, `column_units`.

- [ ] **Step 1:** Rebase `spike-avoidance` onto `main`; record old and new SHAs in `AW4/results/rebase-map.txt`. Conflict: stop.
- [ ] **Step 2:** Add the flags and counters; the harness prints the five counters per scenario line.
- [ ] **Step 3:** Lint and warnings pass. Run the harness with `--mode off` and `--mode r1t` with traces; `diff -r` against `AW3/traces/r0-1` and `AW3/traces/r1t-1` is empty. Any difference: stop.
- [ ] **Step 4:** Coordinator commits "Avoidance round 4: mode flags and counters".

### Task 2: `s1`, Zero Hour goal layout

Zero Hour keeps each unit's offset from the group centre at the goal and gives the nearest units their paths first (`AIGroup.cpp:480-514`, `:1696-1700`, revision `0a05454`). Wargrid today hands cells out by unit id (`destination_allocation.gd:5-49`).

**Files:**
- Modify: `game/scripts/simulation/destination_allocation.gd`, `game/scripts/simulation/simulation.gd` (`_assign_move`, lines 417-445)
- Check (scratch): `AW4/checks/s1_check.gd`

**Interfaces:**
- Produces: `Allocation.reorder(units: Array[Dictionary], goals: Dictionary, target: Vector2) -> Dictionary` (same keys, same goal values, different owners) and `Allocation.nearest_first(units: Array[Dictionary], target: Vector2) -> Array[Dictionary]`.

`reorder`, integers only:

```text
members = units whose goal is not null; n = members.size(); n < 2: return goals unchanged
axis  = n * floor(target) - sum of floor(unit.position)      # Vector2i; (0, 0) becomes (1, 0)
depth(cell) = axis.x * cell.x + axis.y * cell.y              # along the travel direction
side(cell)  = axis.x * cell.y - axis.y * cell.x              # across it
strips = ceil(sqrt(n)); size = ceil(n / strips)
U = members sorted by (side(cell of unit), id)
C = goal values sorted by (side(cell of goal), cell.y, cell.x)
for each strip i: take U[i*size ..] and C[i*size ..] (same index range)
    sort the units by (depth descending, id), the goals by (depth descending, cell.y, cell.x); pair by index
```

So the unit furthest forward in each strip gets the deepest cell of that strip. The set of cells is exactly what `assign` returned.

- [ ] **Step 1: Write `s1_check.gd`** (prints `S1 CHECK PASSED <n>`, exit 1 on a failure): (a) `reorder` returns the same multiset of goal values as `assign` for a 20 x 15 block of 300 units sent 40 cells along +x, and for the same block sent along -y; (b) the result is identical when `units` is shuffled; (c) in both cases no two units of one strip are paired against their order (`depth(u) > depth(v)` with `depth(goal u) < depth(goal v)`); (d) one unit, and a unit whose goal is `null`, come back unchanged; (e) `nearest_first` returns ascending squared cell distance to the target, ties by id.
- [ ] **Step 2:** Run it against stubs that return their input. Expected: (c) and (e) FAIL.
- [ ] **Step 3:** Implement both functions. In `_assign_move`, when `Avoidance.goal_order`: `goals = Allocation.reorder(ground, goals, point)`, count `reordered`, and append ids to `_path_queue` in `nearest_first` order instead of member order.
- [ ] **Step 4:** Check passes; lint, warnings; inert-when-off diff (Task 1 Step 3) empty.
- [ ] **Step 5:** Harness `--mode s1`, all 15 scenarios, twice with traces: identical; write the jam table to `AW4/results/s1-jam.txt` (completion tick, blocked over 150, deadlocks, last resorts, overlap pair-ticks, `orders_dropped`, `reordered`).
- [ ] **Step 6:** Coordinator commits "Avoidance round 4: s1, goals front-first".

### Task 3: `s1x`, crossing movers pass after 1 s

Zero Hour: a unit blocked over one second by a mover that is not heading the same way drives through it (`AIUpdate.cpp:1355-1362`). R1t waits 150 ticks of no progress, then ghosts through everything for 60.

**Files:**
- Modify: `game/scripts/simulation/avoid_yield.gd` (`blocked`), `game/scripts/simulation/avoidance.gd` (`record`, `_guarded`, `_entered`)
- Check (scratch): `AW4/checks/s1x_check.gd`

**Interfaces:**
- Produces: constant `Avoidance.CROSS_PASS_TICKS: int = 30`; record fields `cross_since: int` (0 = none) and `pass_id: int` (0 = none), both plain ints so they are in the snapshot and the hash.

Rule: in `Yield.blocked`, when `Avoidance.cross_pass`, the other unit is moving (not `standing`) and the two headings have a dot product of 0 or less: set `cross_since` to this tick if it is 0; once `tick - cross_since >= CROSS_PASS_TICKS`, set `pass_id` to the other unit's id, clear the wait, count `cross_passes`. `_guarded` treats a blocker whose id equals `pass_id` as absent. `_entered` clears both fields. Standing units, same-direction movers and every other R1t rule are untouched.

- [ ] **Step 1: Write `s1x_check.gd`:** a corridor one cell wide and nine long, a vehicle at each end ordered to the other end. Assert under `s1x`: both arrive, `cross_passes >= 1`, the later arrival tick is at least 100 ticks earlier than under `r1t`, and `last_resorts == 0`. A second case, two vehicles one behind the other heading the same way: `cross_passes == 0`.
- [ ] **Step 2:** Run under `s1` (flag off). Expected: the first case FAILS on `cross_passes` and on the tick difference.
- [ ] **Step 3:** Implement. Check passes; lint, warnings; inert-when-off diff empty; `s1` traces unchanged against Task 2's.
- [ ] **Step 4:** Harness `--mode s1x` twice with traces: identical; jam table to `AW4/results/s1x-jam.txt` with `cross_passes`.
- [ ] **Step 5:** Coordinator commits "Avoidance round 4: s1x, crossing movers pass after 1 s".

### Task 4: `s2`, goal swap with a standing friend

The no-room fallback. A mover blocked by a friend that stands on its own goal trades goals with it; the friend moves on along the mover's route. Unique cells stay, nobody overlaps, no order is given up. Wargrid's own rule; the proven relatives are Zero Hour re-choosing a goal cell (`AIStates.cpp:1664-1668`), OpenRA's chain nudge (`Mobile.cs:394-416`) and Recoil's "goal held by a finished unit" (`GroundMoveType.cpp:292-315`). If it misbehaves, the cited alternative is to re-reserve the nearest free cell within a radius that doubles per failed try up to 8 cells (research.md, P4); that is not built here.

**Files:**
- Modify: `game/scripts/simulation/avoid_yield.gd` (`blocked`), `game/scripts/simulation/avoidance.gd` (new `swap`)
- Check (scratch): `AW4/checks/s2_check.gd`

**Interfaces:**
- Produces: `Avoidance.swap(sim: Simulation, mover: Dictionary, rec: Dictionary, other: Dictionary) -> bool`.

`swap` applies only when all hold: `Avoidance.swapping`; `other.status == "arrived"` and `other` stands on its own destination cell; same `owner`; `not busy(other)`; both are the same class (vehicle or infantry); the mover's order is a plain `move` with a destination; the mover's route has more than one waypoint. Then: `other` takes the mover's destination, a copy of its order and its route without the first waypoint, status `moving`, `move_after = tick + START_DELAY_TICKS`, a cleared avoid record; the mover takes `other`'s old destination, a one-waypoint route to it, and keeps waiting for the cell. Count `swaps`. `Yield.blocked` tries `swap` first in the standing branch, before `sidestep` and `reroute`.

- [ ] **Step 1: Write `s2_check.gd`:** a corridor one cell wide; units B and C are ordered to cells 5 and 6 and settle; then A, at cell 1, is ordered to cell 7. Assert under `s2`: all three `arrived` before tick 600 on cells {5, 6, 7}, `swaps == 2`, overlap pair-ticks 0, `orders_dropped == 0`, destinations unique on every tick. Second case: B is shooting (`busy`): `swaps == 0`. Print what `r1t` does in the first case (ghosts through or never arrives) as a baseline line.
- [ ] **Step 2:** Run under `s1x`. Expected: the first case FAILS on `swaps`.
- [ ] **Step 3:** Implement. Check passes; lint, warnings; inert-when-off diff empty; `s1x` traces unchanged.
- [ ] **Step 4:** Harness `--mode s2` twice with traces: identical; jam table to `AW4/results/s2-jam.txt` with `swaps`.
- [ ] **Step 5:** Coordinator commits "Avoidance round 4: s2, goal swap fallback".

### Task 5: `s3`, column slice

Zero Hour moves a group of at least 3 infantry or 3 vehicles further than 100 world units as a column on one shared route, infantry 3 wide, vehicles 2 wide (`AIGroup.cpp:601`, `:638`, `:688`, `:797`, `:1157`, `:1266`; retail `data\ini\default\aidata.ini:47-49`: `MinInfantryForGroup 3`, `MinVehiclesForGroup 3`, `MinDistanceForGroup 100.0`). 100 world units are 4 Wargrid cells.

**Files:**
- Modify: `game/scripts/simulation/simulation.gd` (`_assign_move`, `_assign_route`, lines 417-445 and 571-582)
- Create: `game/scripts/simulation/avoid_column.gd` (lane building, kept out of `simulation.gd`)
- Check (scratch): `AW4/checks/s3_check.gd`

**Interfaces:**
- Produces: `Column.lanes(navigation: RefCounted, from: Vector2, to: Vector2, count: int) -> Array` (each lane an `Array[Vector2]` route; lane 0 is the trunk from `from` to `to`; the others start and end one cell further across the dominant travel axis and are dropped when their start or end is not walkable in the same component), and `Column.join(navigation: RefCounted, unit_position: Vector2, lane: Array, goal: Vector2) -> Array[Vector2]` (route to the nearest lane waypoint, the lane from there, then a route from the lane's end to the goal; empty when any part is empty).
- Constants in `avoid_column.gd`: `MIN_UNITS: int = 3`, `MIN_DISTANCE_CELLS: int = 4`, `VEHICLE_LANES: int = 2`, `INFANTRY_LANES: int = 3`.

In `_assign_move`, when `Avoidance.columns`: split the ground members by class; for each class with at least `MIN_UNITS` whose centre is at least `MIN_DISTANCE_CELLS` from the target, build the lanes once from the member nearest the centre, give unit `j` of the `nearest_first` order lane `j % lanes`, and remember it in `sim._columns` (keyed by a counter; the unit holds only the key and lane index in `unit.column`). `_assign_route` uses `Column.join` when the unit has `column`, falls back to today's route when `join` is empty, and erases `unit.column`. Count `columns` per group and `column_units` per unit that got a joined route.

- [ ] **Step 1: Write `s3_check.gd`:** 12 vehicles in a 4 x 3 block ordered 30 cells along +x on open ground. Assert under `s3`: `columns == 1`, `column_units == 12`, while more than half are still moving at most 2 distinct `y` cells are in use among units beyond the first 6 cells of travel, all arrive, destinations unique. Second case: 2 vehicles: `columns == 0`. Third case: 12 vehicles ordered 2 cells away: `columns == 0`.
- [ ] **Step 2:** Run under `s2`. Expected: the first case FAILS on `columns`.
- [ ] **Step 3:** Implement, with `# shortcut: column lanes are not in the snapshot between the order and the route build (at most a few ticks); a real version stores them`. Check passes; lint, warnings; inert-when-off diff empty; `s2` traces unchanged.
- [ ] **Step 4:** Harness `--mode s3` twice with traces: identical; jam table to `AW4/results/s3-jam.txt` with `columns`, `column_units`.
- [ ] **Step 5:** Coordinator commits "Avoidance round 4: s3, column slice".

### Task 6: Measurements

**Files:** outside the repo only (`AW4/trees`, `AW4/logs`, `AW4/results`).

- [ ] **Step 1:** Build trees with `mktree.sh`: `r0` (main plus the round 3 legs files, mode `""`), and `r1t`, `s1`, `s1x`, `s2`, `s3` from the final branch commit, each with its mode; a `TREE` file in each.
- [ ] **Step 2: Cost.** Median of 3, interleaved `r0, r1t, s1, s1x, s2, s3` per round (18 runs), six cap rows, p95 and p99, r0 spread, legs issued and finished, shots and deaths, the five counters. Table and per-row verdict to `AW4/results/cost.txt`.
- [ ] **Step 3: Real gate.** `sh tools/run_benchmark.sh` in each variant tree: exit code and first failing line to `AW4/results/bench.txt`; `run_combat.gd` exit codes.
- [ ] **Step 4: Suite** in each variant tree: counts and sorted failing lines to `AW4/results/suite.txt`, each new line (against `r1t`'s 17) with what behaviour changed.
- [ ] **Step 5: Profile** of the cheapest variant that finishes the packed moves (or of `s3` if none does), with the profiler-overhead caveat, to `AW4/results/profile.txt`.
- [ ] **Step 6:** One comparison table to `AW4/results/summary.txt`: per variant the packed and split moves' completion ticks, deadlocks, rows over the cap.

### Task 7: Feel session (needs the user)

Opens game windows: ask the user first and batch everything into one sitting. If the user is away, skip it and say so in the note.

- [ ] **Step 1:** Scratch viewer scene (untracked, inside the tree's `game/`, deleted afterwards): runs one harness scenario in real time at 30 ticks per second, units coloured by moving group, the variant name in the window title, `--audio-driver Dummy`, Esc closes it.
- [ ] **Step 2:** With approval, show `dw_group50` and `move_open` for `r0`, `r1t`, `s2`, `s3`, one window at a time; record the user's words per variant in `AW4/results/feel.txt`.
- [ ] **Step 3 (probe from the friend's playtest):** the same two scenarios on `r0` with eight-direction routes (a scratch copy with `diagonal_mode` changed in `grid_navigation.gd:23`; no avoidance, no measurement). It only answers whether the four-direction staircase is what looks odd.

### Task 8: Note and review

**Files:**
- Modify: `docs/reference/unit-avoidance-spike.md` on `spike-avoidance` (append "# Round 4")

- [ ] **Step 1:** Write the part in round 3's shape: status, where everything lives, commits, what each variant builds with its source citation, checks and inert-when-off evidence, cost table with verdicts and like-for-like marks, real gate, jam table, suite lines, profile, feel notes, what was not done, a recommendation labelled a proposal, open questions (the 5 s against 1 s rule first).
- [ ] **Step 2:** Fresh-context reviewer on the strongest model checks every number against `AW4/results` and the raw logs, the rule descriptions against the diffs, and names for each scratch check the code change that would make it fail. Apply the fixes.
- [ ] **Step 3:** Coordinator commits "Avoidance round 4: evidence note", updates `docs/session-notes.md` on `main`, and stops. Commit on `main`, push and merge wait for the user.

## Stop conditions

Rebase conflict; a difference in the inert-when-off traces; a variant whose two runs differ; a swap that breaks unique destinations and cannot be fixed inside Task 4; anything that would need a test, budget, cap or ceiling changed. Record and stop; questions go to the final summary.

## Not in this plan

Movement in any direction (today routes use four directions on the building grid, `grid_navigation.gd:19-24`; Zero Hour paths on 10-unit cells and smooths the path, `AIPathfind.h:439`, `AIPathfind.cpp:474`): its own design question, to be asked before the avoidance milestone because the blocking rules depend on it. Also not here: factory exit, building-placement move-away, aircraft, fog, "keep formation", multi-cell footprints, standing friends as a route cost with step-aside tunnelling (research.md P3), Recoil-style soft pushing, Steam Deck, a merge.

# frc7 Extra-Cell Spike Implementation Plan

**Status: written 2026-11-12 night for an unattended backup run; open choices settled (user, 2026-11-12): plan and resume record committed on `dock-hold` by the night preparation; a local commit after each GREEN task is pre-authorized, never push; causality check in a throwaway worktree (Task 4); no Zero Hour source read (a caveat). Not run.** Resume record: [extra-cell spike verification](../../reference/extra-cell-spike-verification.md).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Name the rule that makes one leg per trip walk one extra cell (+43 flying ticks, +1.0 cell) when several FRC workers share a dock, or record "not established" with what was ruled out. Evidence only.

**Architecture:** One test-side recorder (`game/tests/dock_cell_trace.gd`) reads `snapshot().entities` every tick: per leg the start cell, the claimed dock cell (`collection.dock`), the first route, the cells other collectors of the same target hold at claim time, walked length and corners. First one slow and one normal trip are dumped tick by tick (cheapest check), then legs are grouped by cell pair over the steady window. Each candidate rule gets a kill check decided on those lines before any supporting number is read.

**Tech Stack:** typed GDScript (Godot 4.7.2), existing test harness (`test_dock_models.gd`, `WARGRID_DOCK_PROBE=1`).

**Spec:** handoff `extra-cell-spike-prompt.txt` (private); user answers [frc7 gap follow-up](../../reference/design-answers-2026-11-08.md#frc7-gap-follow-up-user-2026-11-12-night); evidence so far [frc7 gap measurement](../../reference/dock-hold-experiment.md#frc7-gap-measurement-2026-11-12) and `~/projects/wargrid-dock-work/gap/` (`verdicts.md`, `wargrid-probe2.txt`, `swap.txt`); format and probe of the [frc7 gap plan](2026-11-12-frc7-gap.md).

## Global Constraints

- Evidence only: no fix, no `definitions/` change, no pinned trace or digest change, no game behaviour change. Nothing under `game/scripts/` changes in `~/projects/wargrid-wt-dock`; new code is test-helper code in `game/tests/` only. The one exception is Task 4's throwaway detached worktree (user, 2026-11-12): one stated line of `_claim_dock`, never committed, removed at the task's end.
- Zero Hour's dock-cell choice is not read (user, 2026-11-12); the note lists it as a caveat.
- Tree: branch `dock-hold` in `~/projects/wargrid-wt-dock`, head `d3851e8`, measured as is (split model and its variants, as the gap measurement did). The c1 rebuild (`~/projects/wargrid-wt-c1`, branch `c1-dock-rebuild`) is not merged at night; a re-measure on the rebuilt tree is a morning item, never part of this run. Do not read, build or run anything in `~/projects/wargrid-wt-c1`.
- Judged model: `split`. `hold` and `c1` (dock-hold's variant) are reported, not judged. `queue` is skipped (`probe_models()`).
- New test code uses only the [simulation interface](../../reference/sim-interface.md): `snapshot()` (its `entities` rows: `id`, `kind`, `position`, `status`, `route`, `collection.phase`, `collection.dock`, `collection.target_id`), `view_state()`, `spawn`, commands, `StateHash.digest`. No `sim._*`. `tools/test_sim_boundary.py` enforces it.
- Snapshot entity `route` arrays are shared read-only: read, never mutate.
- Do not touch: `game/scripts/**`, `game/tests/dock_probe.gd` (its `probe` lines are the gap measurement's evidence), `game/tests/test_supply_parity.gd`, `game/tests/test_income_openings.gd`, `game/tests/run_tests.gd`, `tools/**`, `~/projects/wargrid-dock-work/gap/` and `c/` (read only).
- Work folder: `~/projects/wargrid-dock-work/extra-cell/` (logs, lines, verdicts; outside the repository).
- Every Wargrid number names its tree: `dock-hold <git rev-parse --short HEAD at run time>` plus the uncommitted test diff, saved by `cd ~/projects/wargrid-wt-dock && { git diff HEAD -- game/tests; git diff --no-index /dev/null game/tests/dock_cell_trace.gd; } > ~/projects/wargrid-dock-work/extra-cell/trace.diff; shasum -a 256 ~/projects/wargrid-dock-work/extra-cell/trace.diff` (the `--no-index` part only while the file is untracked, i.e. in Task 1; it exits 1 on a difference, which is expected). The line `tree: dock-hold <sha> + trace diff sha256 <hash>` is the first line of every lines file. Code lines below are cited at `d3851e8`; `game/scripts/` does not change on `dock-hold`, so they hold at every later commit of this run.
- Commands run from the worktree root: every Bash call starts `cd ~/projects/wargrid-wt-dock && …` (subagent shells reset their directory). Suite, lint and warnings calls pass `timeout: 600000`, write to a file, are judged by exit code and the summary line (`TESTS PASSED <n>`).
- No Zero Hour game, no `run_game.sh`, no window, no push, merge or PR. Commits (user, 2026-11-12): subagents never commit; after each GREEN the coordinator makes one local commit on `dock-hold` with the task's message below; never in the throwaway worktree; never push.
  - Task 1: `Add a dock cell trace behind WARGRID_DOCK_PROBE` (body: "Reads snapshot rows; simulation and traces unchanged.")
  - Task 2: `Add dock cell pair rows to the dock probe`
  - Task 3: `Record the frc7 extra-cell verdicts in the dock-hold note`
  - Task 4: `Record the extra-cell causality check`
  - Task 5: `Apply the extra-cell review`
- Thresholds in this plan (slow leg = lone flying median + 20 ticks; 0.05 cell; 90 % of slow legs; 6-tick budget cut, the gap plan's cut) are the plan's choices; the reviewer checks them.

## Candidate rules (from the code, tree d3851e8)

| id | candidate | code | kill check (decided first) |
|---|---|---|---|
| R1 | route detours around standing workers | `grid_navigation.gd:108-127` A* on the static grid; solids are terrain, buildings and sources only (`simulation.gd:801-807`); 4-connected, Manhattan (`grid_navigation.gd:21-23`) | killed if, on slow legs, median `route - manhattan` is at most the lone pair's value + 0.05 |
| R2 | push by avoidance (any displacement off the route) | positions are written only by `_advance` along `route` (`simulation.gd:601-624`) and by containers (`containers.gd`, passengers) | killed if every slow pair has `abs(moved_len - route) <= 0.05` and `routes == 1` |
| R3 | arrival-cell choice: Euclidean-nearest ring cell not held by another collector of the same target | `_claim_dock` (`supply_collection.gd:56-72`), ring with corners (`:47-54`), held = any collector with a `dock` for that target, flying or standing | killed if at least 90 % of slow legs end on the lone leg's end cell |
| R4 | exit cell: the leg starts where the worker loaded or unloaded, i.e. the previous leg's R3 cell, shifted by `DOCK_SHIFT` (`_arrival`, `supply_collection.gd:35-41`); first waypoint dropped when behind (`_behind`, `simulation.gd:586-588`). No separate exit spot outside `queue` | killed if at least 90 % of slow legs start on the lone leg's start cell |
| R5 | turns: legs slow to `1 - angle/45` while turning (`locomotion.gd:58-63`), 2-tick start delay (`simulation.gd:20`, `:581`) | killed as a contributor if slow pairs have the lone pair's corner count |
| R6 | target choice (nearest depot or pile, `choose_target`, `supply_collection.gd:84-97`) | killed by construction: one depot and one pile in every scenario (no run) |
| R7 | blocked retries, path latency | killed in the gap measurement: 0 drops, 0 blocked, 0 `path_pending` ticks (cite `gap/verdicts.md` step 4, no run) |
| R8 | admit and wait order (`_admit`, `supply_collection.gd:160-191`) | sets lead, waiting, loading or unloading only, never a flying phase; the loaded leg's standing is 6 both lone and slow (`gap/wargrid-probe2.txt`): killed for flying time (no run) |

Rule established when R1 and R2 are killed, R3 or R4 survives, the budget (Task 3 Step 4) closes the +43 within 6 ticks in split `transplant_g3`, `sweep_g3_n7` and `sweep_g9_n7`, and the causality check (Task 4) confirms it. Otherwise "not established", listing each kill.

## Review Focus

- A leg whose collector never claims a dock (`seeking` to `idle` retry): its pair prints as `none`, never dropped silently (Task 1 test `test_cell_trace_leg_without_dock`).
- A leg re-routed mid-way: `route` is the first route, `routes` counts every `path_pending`-to-`moving` change, so R2 sees it (Task 1 test `test_cell_trace_counts_reroutes`).
- Reading `snapshot()` every tick makes route arrays read-only: the run must stay bit-identical (Task 1 test `test_cell_trace_leaves_the_run_unchanged`).
- Pair lines in dictionary order would differ between runs: sorted by leg kind, count descending, pair text (Task 2 test `test_cell_trace_pair_lines_sorted`).
- A transplant start returning id -1: the trip case fails, never runs with fewer than 7 workers (Task 1 Step 4 check).

---

### Task 1: Cell recorder and one-trip trace (cheapest check). Model: Sonnet

**Files:**
- Create: `game/tests/dock_cell_trace.gd` (typed, `extends RefCounted`, like `dock_probe.gd`); Godot adds `dock_cell_trace.gd.uid` on import, which goes into the Task 1 commit (as `dock_probe.gd.uid` is tracked)
- Modify: `game/tests/test_dock_models.gd` (preload `const CellTrace = preload("res://tests/dock_cell_trace.gd")` beside `Probe`; new cases appended to `cases()`; helpers at the end)
- Output: `~/projects/wargrid-dock-work/extra-cell/trip.txt`

**Interfaces:**
- Consumes (`test_dock_models.gd`, existing): `opening_starts(model) -> Dictionary` (`starts`), `transplant(model, starts) -> Dictionary` (`sim`, `source`, `ids`), `Parity.new().layout(kind, gap, count, model)`, `Openings.new().pile_boxes(view, source)`, `Probe.quantile`, `PROBE_TO_TICK` (18000), `probe_models()`.
- Produces (`dock_cell_trace.gd`):
  - `func _init(keep_trace: bool = false) -> void`
  - `func observe(tick: int, entities: Array) -> void`: `entities` = `snapshot().entities`; only rows with `kind == "frc_builder"` and a non-null `collection` count, all of them as "others".
  - `var legs: Array[Dictionary]`: closed legs only. Keys: `kind` (`"empty"` / `"loaded"`), `id`, `start_tick`, `end_tick`, `start_cell: Vector2i`, `end_cell: Vector2i` (`Vector2i(-1, -1)` without a claim), `target_id`, `route: float` (-1.0 until routed), `corners: int`, `moved_len: float`, `flying: int`, `moved_ticks: int`, `routes: int`, `held: String`, `trace: Array[String]` (filled only with `keep_trace`).
  - `static func route_length(from: Vector2, route: Array) -> float`; `static func corners(from: Vector2, route: Array) -> int` (direction changes between successive segments, dot of unit vectors < 0.999); `static func manhattan(a: Vector2i, b: Vector2i) -> int`.
  - `static func tick_line(tick: int, id: int, entities: Array) -> String`.

Definitions (same leg cut as `dock_probe.gd`): empty leg from the first tick after `unloading` until the tick before `loading`; loaded leg after `loading` until before `unloading`; legs of a unit first seen mid-leg and legs open at the last tick are dropped. `start_cell` = floor of the position on the leg's first tick. `end_cell`, `target_id` and `held` are taken on the first leg tick where `collection.dock != null`: `held` = the other collectors with that `target_id` and a dock, as `x,y:phase` sorted and joined by `;` (empty string when none). `route` and `corners` from the position and `route` on the first leg tick with `status == "moving"`. `routes` = number of `path_pending`-to-`moving` changes in the leg. `flying` = ticks with phase `flying_*`; `moved_ticks` / `moved_len` = ticks with a changed position / summed distance. `tick_line`: `T <tick> <id> <phase> <status> cell=<x>,<y> pos=<%.2f>,<%.2f> dock=<x>,<y or -> | <id>:<phase>:<x>,<y> ...` over every other collector.

- [ ] **Step 1: Write the failing tests** (synthetic entity rows, no simulation; a helper `cell_row(id: int, phase: String, position: Vector2, dock: Variant = null, target: int = 5, status: String = "moving", route: Array = []) -> Dictionary` builds `{id, kind: "frc_builder", position: [x, y], status, route, collection: {phase, dock, target_id}}`)
  - `test_cell_trace_leg_cells`: unit 1 at (5.5, 11.5) on ticks 1-4, dock `[7, 10]` from tick 3 on; `unloading` tick 1; `seeking` tick 2 (dock null); `flying_source` tick 3 status `path_pending`, dock `[7, 10]`; tick 4 status `moving`, route `[[6.5, 11.5], [7.5, 11.5], [7.5, 10.5]]`, position (5.5, 11.5); ticks 5, 6, 7 at (6.5, 11.5), (7.5, 11.5), (7.5, 10.5); `loading` tick 8. Expect one leg: `kind == "empty"`, `start_cell == Vector2i(5, 11)`, `end_cell == Vector2i(7, 10)`, `route == 3.0`, `corners == 1`, `moved_len == 3.0`, `flying == 5`, `moved_ticks == 3`, `routes == 1`, `held == ""`.
  - `test_cell_trace_held_names_other_holders`: as above plus unit 2 `loading` with dock `[7, 11]`, target 5, and unit 3 `unloading` with dock `[5, 11]`, target 9, on every tick → unit 1's leg `held == "7,11:loading"`.
  - `test_cell_trace_leg_without_dock`: a leg whose unit goes `seeking` → `idle` → `flying_source` without a dock until `loading` → `end_cell == Vector2i(-1, -1)`, still in `legs`.
  - `test_cell_trace_drops_partial_legs`: a unit first seen in `flying_source`, and a leg still open at the last tick → `legs.is_empty()`.
  - `test_cell_trace_counts_reroutes`: status `path_pending`, `moving`, `path_pending`, `moving` inside one leg → `routes == 2`, `route` from the first `moving` tick.
  - `test_cell_trace_geometry`: `route_length(Vector2(0, 0), [[1.0, 0.0], [1.0, 1.0]]) == 2.0`, `corners(...)` of it `== 1`, of `[[1.0, 0.0], [2.0, 0.0]]` `== 0`; `manhattan(Vector2i(5, 11), Vector2i(7, 10)) == 3`.
  - `test_cell_trace_keeps_trace_only_when_asked`: with `keep_trace` the leg's `trace.size() == end_tick - start_tick + 1` and its first line starts `T `; without, `trace.is_empty()`.
  - `test_cell_trace_leaves_the_run_unchanged`: two `Parity.new().layout("frc_builder", 3, 7, "split")` sims, 3000 ticks each; one calls `snapshot()` and `observe` every tick → `StateHash.digest(a.snapshot()) == StateHash.digest(b.snapshot())` and its recorder has at least one leg.

- [ ] **Step 2: Run, expect failures**

Run: `cd ~/projects/wargrid-wt-dock && mkdir -p ~/projects/wargrid-dock-work/extra-cell && WARGRID_TEST_ONLY=test_cell_trace sh tools/run_tests.sh > ~/projects/wargrid-dock-work/extra-cell/t1-red.log 2>&1; echo "exit=$?"`
Expected: `exit=1`, missing `dock_cell_trace.gd` (preload error).

- [ ] **Step 3: Implement `dock_cell_trace.gd`** to the interface above. Read `position` as `Vector2(row.position[0], row.position[1])`, cells with `Vector2i(position.floor())`. Read the dock as `row.collection.get("dock")`: the simulation erases the key (`supply_collection.gd:20`), so `.dock` would error on real rows.

- [ ] **Step 4: Add the gated case `test_cell_trip`** (`WARGRID_DOCK_PROBE=1`, else one passing check, as `test_probe_rows`). Split only: `opening_starts("split").starts` → `transplant("split", starts)`; check `not world.ids.has(-1)` and `world.ids.size() == 7`; recorder with `keep_trace`; step to `PROBE_TO_TICK`, observing each tick after 9000 while the pile has boxes. Pick the first closed loaded leg with `flying` in 127..139 (median 133 +-6) as `slow` and the first in 84..96 (90 +-6) as `normal`, so the dump shows a typical leg, not an outlier; also print `DOCK split trip loaded_flying_median=%.1f` over all closed loaded legs (`Probe.quantile`); `runner.check` both legs exist. Print for each: `DOCK split trip <slow|normal> id=<id> start=<x,y> end=<x,y> route=%.2f manhattan=%d corners=%d flying=%d moved_len=%.2f held=<held>`, then its `trace` lines prefixed `DOCK split trip <slow|normal> `.

- [ ] **Step 5: Run green, lint, warnings, boundary**

```
cd ~/projects/wargrid-wt-dock && WARGRID_TEST_ONLY=test_cell sh tools/run_tests.sh > ~/projects/wargrid-dock-work/extra-cell/t1-green.log 2>&1; echo "exit=$?"
cd ~/projects/wargrid-wt-dock && sh tools/run_lint.sh > ~/projects/wargrid-dock-work/extra-cell/t1-lint.log 2>&1; echo "exit=$?"
cd ~/projects/wargrid-wt-dock && sh tools/run_warnings.sh > ~/projects/wargrid-dock-work/extra-cell/t1-warn.log 2>&1; echo "exit=$?"
cd ~/projects/wargrid-wt-dock && sh tools/run_python_checks.sh > ~/projects/wargrid-dock-work/extra-cell/t1-py.log 2>&1; echo "exit=$?"
```
Expected: four `exit=0`; `TESTS PASSED` in the first (`test_cell_trip` passes with one check while ungated).

- [ ] **Step 6: Produce the trip**

Save `trace.diff` and its hash (Global Constraints), then `cd ~/projects/wargrid-wt-dock && WARGRID_DOCK_PROBE=1 WARGRID_TEST_ONLY=test_cell_trip sh tools/run_tests.sh > ~/projects/wargrid-dock-work/extra-cell/trip.log 2>&1; echo "exit=$?"`, then write `trip.txt`: line 1 the tree line (Global Constraints), then `rg '^DOCK split trip' ~/projects/wargrid-dock-work/extra-cell/trip.log`.
Expected: `exit=0`; slow `flying` 133 +-6 and normal 90 +-6 (the frc7 close loaded-leg medians of `gap/wargrid-probe2.txt`: 133 against 90; one leg each, so the 6-tick cut). **STOP and report (BLOCKED)** if either leg is missing or `loaded_flying_median` is outside 133 +-3 (Task 2's `transplant_g3` bound): the harness does not reproduce the gap. Do not interpret the trip; that is Task 3.

- [ ] **Step 7: Update the resume record** in `docs/reference/extra-cell-spike-verification.md` (T1 green, counts, exit, marker, changed paths, `trace.diff` hash) and append a T1 row there.

---

### Task 2: Cell pairs over the steady window. Model: Sonnet

**Files:**
- Modify: `game/tests/dock_cell_trace.gd`, `game/tests/test_dock_models.gd`
- Output: `~/projects/wargrid-dock-work/extra-cell/cells.txt`

**Interfaces:**
- Consumes: Task 1's recorder and `legs`; `transplant`, `opening_starts`, `Parity.layout`, `probe_models()`.
- Produces: `static func pair_lines(model: String, scenario: String, legs: Array[Dictionary]) -> Array[String]` and `static func summary_line(model: String, scenario: String, legs: Array[Dictionary]) -> String` in `dock_cell_trace.gd`.

Line formats (medians by `Probe.quantile(values, 0.5)`, `%.1f` for ticks, `%.2f` for cells; a pair without a claim prints `none` as its end):
- `DOCK <model> cells <scenario> <kind> <sx>,<sy>-><ex>,<ey> legs=%d manhattan=%d flying=%.1f moved_ticks=%.1f route=%.2f moved_len=%.2f corners=%.1f routes=%.1f held=<most common held, ties to the lexically first; - when empty>`; one line per (kind, start_cell, end_cell), sorted by kind (`empty` first), then legs descending, then the pair text.
- `DOCK <model> cells <scenario> summary legs=%d empty_flying=%.1f loaded_flying=%.1f`.

- [ ] **Step 1: Write the failing tests**
  - `test_cell_trace_pair_lines_sorted`: four synthetic legs (two `loaded` (7,11)->(5,11) with flying 90 and 92, one `loaded` (7,10)->(5,11) flying 133, one `empty` (5,11)->(7,11) flying 91) → three lines, in the order `empty`, then `loaded 7,11->5,11 legs=2`, then `loaded 7,10->5,11 legs=1`; the two-leg line has `flying=90.0` (nearest-rank median) and `manhattan=2`.
  - `test_cell_trace_summary_line`: the same legs → `legs=4 empty_flying=91.0 loaded_flying=92.0`.

- [ ] **Step 2: Run, expect failures**

Run: `cd ~/projects/wargrid-wt-dock && WARGRID_TEST_ONLY=test_cell_trace_pair sh tools/run_tests.sh > ~/projects/wargrid-dock-work/extra-cell/t2-red.log 2>&1; echo "exit=$?"` → `exit=1` (missing `pair_lines`).

- [ ] **Step 3: Implement `pair_lines` and `summary_line`.**

- [ ] **Step 4: Add the gated case `test_cell_rows`** (`WARGRID_DOCK_PROBE=1`). Per model in `probe_models()`, five scenarios, each observed on ticks after 9000 up to `PROBE_TO_TICK` while the pile has boxes (the `probe_sweep` window):
  - `sweep_g3_n1`, `sweep_g3_n7`, `sweep_g9_n1`, `sweep_g9_n7`: `Parity.new().layout("frc_builder", gap, n, model)`.
  - `transplant_g3` (the frc7 close opening's start state in the sweep world; split reproduces the opening's rate, `gap/swap.txt`): `transplant(model, opening_starts(model).starts)`; `runner.check` no -1 id.
  - Print `summary_line` then `pair_lines`; `runner.check(legs.size() > 0)`.

- [ ] **Step 5: Run green, lint, warnings, boundary** (the four commands of Task 1 Step 5 with `t2-` log names, `WARGRID_TEST_ONLY=test_cell`). Expected: four `exit=0`, `TESTS PASSED`.

- [ ] **Step 6: Produce the rows**

Save `trace.diff` and its hash again, then (background, `timeout: 600000`): `cd ~/projects/wargrid-wt-dock && WARGRID_DOCK_PROBE=1 WARGRID_DOCK_MODELS=hold,split,c1 WARGRID_TEST_ONLY=test_cell_rows sh tools/run_tests.sh > ~/projects/wargrid-dock-work/extra-cell/cells.log 2>&1; echo "exit=$?"`, then `cells.txt` = tree line + `rg '^DOCK \w+ cells ' ~/projects/wargrid-dock-work/extra-cell/cells.log`.
Expected: `exit=0`. Cross-checks against `gap/wargrid-probe2.txt` (the same leg cut and window): split summary `sweep_g3_n1` 90.0 / 90.0, `sweep_g3_n7` 133.0 / 90.0, `sweep_g9_n1` 270.0 / 270.0, `sweep_g9_n7` 270.0 / 313.0 exactly; hold `sweep_g3_n7` loaded 97.0 exactly; split `transplant_g3` loaded within +-3 of 133. **A miss: STOP and report (BLOCKED)**; the recorder or the harness is wrong, do not proceed.

- [ ] **Step 7: Update the resume record and append a T2 row.**

---

### Task 3: Verdicts and note update. Model: Opus (high)

**Files:**
- Create: `~/projects/wargrid-dock-work/extra-cell/verdicts.md` (tree line first)
- Modify: `docs/reference/dock-hold-experiment.md`: new subsection `### frc7 extra cell (<run date, date +%F>)` directly after the subsection "frc7 gap measurement (2026-11-12)"; in that gap subsection the "Not established" bullet gets one closing sentence pointing to the new subsection; decision item 5 (frc7 bullet) and item 6 (the sentence "The rule behind it is not established.") updated to the result; "Reproduce" gets the Task 1 Step 6 and Task 2 Step 6 commands. Do not rename any heading (anchors are linked from `design-answers-2026-11-08.md` and `faction-income-parity.md`).

**Interfaces:**
- Consumes: `extra-cell/trip.txt` (Task 1), `extra-cell/cells.txt` (Task 2), `gap/verdicts.md`, `gap/wargrid-probe2.txt`, the code lines cited in the candidate table.

Definitions: per scenario and leg kind, the **lone pair** is the pair with the most legs in the n = 1 scenario of the same gap (`sweep_g3_n1` for `sweep_g3_n7` and `transplant_g3`, `sweep_g9_n1` for `sweep_g9_n7`); **slow legs** are pairs whose `flying` median is at least the lone pair's + 20.

- [ ] **Step 1: Read the trip first** (`trip.txt`): where the slow leg's route bends against the normal one, its start and end cell against the normal leg's, and which cells the others held at claim (`held`) and in what phase. Write it as the "Trip" section of `verdicts.md`, observation only.
- [ ] **Step 2: Kill checks, in table order R1 to R8**, each on split's `transplant_g3`, `sweep_g3_n7` and `sweep_g9_n7` lines: kill-check numbers first, verdict (killed / survives / not separable), then supporting numbers, each labelled **measured (Wargrid, the tree line of `cells.txt`)**, **code reading (d3851e8, path:line)** or **arithmetic**. R6 to R8 are cited, not re-run. Hold and c1 lines are reported beside split, not judged.
- [ ] **Step 3: If R3 or R4 survives, name the holder**: the most common `held` phase on the lone cell when a slow leg claimed (standing: `lead_*`, `waiting_*`, `loading`, `unloading`; or flying), and why the slow leg is the loaded one in `transplant_g3` and `sweep_g9_n7` but the empty one in `sweep_g3_n7`. This answers the handoff's "detour around standing workers or push by avoidance" with what the lines show.
- [ ] **Step 4: Budget (arithmetic)** per scenario: `(slow manhattan - lone manhattan) x lone ticks per cell (lone moved_ticks / lone moved_len) + (slow corners - lone corners) x the residual per corner`, residual per corner = `(lone flying - lone moved_ticks) / lone corners` (0 when lone corners is 0; say so in the line), against the measured flying difference (+43 in split `transplant_g3`). Closes within 6 ticks in all three judged scenarios → rule established; else "not established".
- [ ] **Step 5: Write the note subsection.** Lead with the answer in one sentence (the rule with its code lines, or "not established"); then the kill table (candidate, kill check, verdict); the per-scenario numbers; supported / not established bullets as the gap subsection does; caveats: start-dependent n = 7 rates (user, 2026-11-12, stays a caveat), measured on dock-hold's split, not on the c1 rebuild (a morning re-measure), Zero Hour's dock-cell choice not read (user, 2026-11-12). End the subsection with the line `Causality check: pending (Task 4).` for Task 4 to replace. Name the **leading candidate** (R3, R4, R3 and R4, or none: every survivor among R3 and R4) in the resume record's blocker line for Task 4. Point to `~/projects/wargrid-dock-work/extra-cell/` for lines. No recommendation for a fix beyond one *Recommendation (agent's)* line naming where a fix would go.
- [ ] **Step 6: Docs checks.**
```
cd ~/projects/wargrid-wt-dock && rg -n 'dock-hold-experiment.md#' docs
cd ~/projects/wargrid-wt-dock && sh tools/check_public.sh > ~/projects/wargrid-dock-work/extra-cell/t3-public.log 2>&1; echo "exit=$?"
```
Expected: every anchor found resolves to a heading in the note; `exit=0`. Paths home-relative, no hostnames or scratch paths.
- [ ] **Step 7: Full gate on the final tree** (background, `timeout: 600000` each):
```
cd ~/projects/wargrid-wt-dock && sh tools/run_tests.sh > ~/projects/wargrid-dock-work/extra-cell/t3-full.log 2>&1; echo "exit=$?"
cd ~/projects/wargrid-wt-dock && sh tools/run_lint.sh > ~/projects/wargrid-dock-work/extra-cell/t3-lint.log 2>&1; echo "exit=$?"
cd ~/projects/wargrid-wt-dock && sh tools/run_warnings.sh > ~/projects/wargrid-dock-work/extra-cell/t3-warn.log 2>&1; echo "exit=$?"
cd ~/projects/wargrid-wt-dock && { git diff --name-only <base commit from the resume record>; git ls-files --others --exclude-standard; } | rg -v '^(game/tests/|docs/)'; echo "outside=$?"
```
Expected: `TESTS PASSED`, three `exit=0`, `outside=1` (nothing outside tests and docs since the base, committed or not).
- [ ] **Step 8: Update the resume record** (T3 green, verdict in one line) and append a T3 row.

STOP conditions for this task: a kill check that cannot be decided from the lines (needs a new scenario or a code change) → "not separable", never a new probe; any wish to edit `game/scripts/` → park.

---

### Task 4: Causality check in a throwaway worktree (user, 2026-11-12). Model: Opus (high)

**Files:**
- Throwaway (never committed, removed at the end): `~/projects/wargrid-overnight-work/night-2026-11-13/xcell-causality/game/scripts/simulation/supply_collection.gd`
- Modify (in `~/projects/wargrid-wt-dock`): `docs/reference/dock-hold-experiment.md` (the `Causality check: pending (Task 4).` line, and the answer sentence if the result changes it), the verification file
- Output: `~/projects/wargrid-dock-work/extra-cell/causality.diff`, `causality.log`, `causality.txt`, a "Causality" section in `verdicts.md`

**Interfaces:**
- Consumes: the leading candidate in the resume record (Task 3); `cells.txt` lone values (split summary: `sweep_g3_n1` 90 / 90, `sweep_g9_n1` 270 / 270, as cross-checked in Task 2); Task 2's `test_cell_rows`, already committed on `dock-hold` HEAD.

The change tests R3 and R4 at once: both cells come from `_claim_dock`'s exclusion of cells held by other collectors of the same target (R4's start cell is the previous leg's R3 cell). Without the exclusion every collector claims the nearest ring cell; the lock and `_admit` still serialize the dock, so workers share the spot and wait there. The counterfactual's income and queueing are not a model result and are not reported as one.

- [ ] **Step 1: Preconditions.** `git -C ~/projects/wargrid-wt-dock status --short` prints nothing (Task 3 committed), else **STOP (BLOCKED)**, create nothing. Leading candidate `none`: create nothing, replace `Causality check: pending (Task 4).` with `Causality check: not run (neither R3 nor R4 survived).`, do Step 8 and return GREEN. R3, R4 or both: continue.
- [ ] **Step 2: Create the worktree.** `cd ~/projects/wargrid-wt-dock && git worktree add --detach ~/projects/wargrid-overnight-work/night-2026-11-13/xcell-causality HEAD`; record `git -C ~/projects/wargrid-overnight-work/night-2026-11-13/xcell-causality rev-parse --short HEAD`.
- [ ] **Step 3: The one change** (Edit tool, in the throwaway path only), in `_claim_dock` (`supply_collection.gd:65` at `d3851e8`):

```gdscript
# before
		if held.has(cell) or not sim._navigation.is_walkable(centre) or sim._navigation.component_at(centre) != component: continue
# after
		if not sim._navigation.is_walkable(centre) or sim._navigation.component_at(centre) != component: continue
```
Then `git -C ~/projects/wargrid-overnight-work/night-2026-11-13/xcell-causality diff --name-only` must print only `game/scripts/simulation/supply_collection.gd`; save `git -C ~/projects/wargrid-overnight-work/night-2026-11-13/xcell-causality diff > ~/projects/wargrid-dock-work/extra-cell/causality.diff` and its `shasum -a 256`. The before line not found, or another path in the diff: **STOP (BLOCKED)** after Step 7.
- [ ] **Step 4: Measure with the same probe** (background, `timeout: 600000`; the first run in a new worktree imports the project): `cd ~/projects/wargrid-overnight-work/night-2026-11-13/xcell-causality && WARGRID_DOCK_PROBE=1 WARGRID_DOCK_MODELS=hold,split,c1 WARGRID_TEST_ONLY=test_cell_rows sh tools/run_tests.sh > ~/projects/wargrid-dock-work/extra-cell/causality.log 2>&1; echo "exit=$?"`; `causality.txt` = `tree: dock-hold <sha> detached + causality.diff sha256 <hash> (throwaway, never committed)` + `rg '^DOCK \w+ cells ' ~/projects/wargrid-dock-work/extra-cell/causality.log`. A nonzero exit or a script error: the verdict is "not separable (counterfactual run failed: <first error line>)"; go to Step 6.
- [ ] **Step 5: Verdict**, on split `transplant_g3`, `sweep_g3_n7`, `sweep_g9_n7`, for the leg kind that was slow in Task 3 (summary `loaded_flying` or `empty_flying` against the lone 90, 90, 270):
  - **Confirmed:** within lone + 6 in all three, and the lone pair carries at least 90 % of that leg kind's legs.
  - **Killed:** at least lone + 20 in any of the three; the held-cell exclusion does not cause the extra cell there, and the note's answer becomes "not established" for that scenario.
  - **Partial:** anything between; report the numbers per scenario, not a cause.
  Hold and c1 reported beside split, not judged.
- [ ] **Step 6: Record.** A "Causality" section in `verdicts.md` (diff, numbers, verdict). In the note, replace `Causality check: pending (Task 4).` with one short paragraph labelled **measured (Wargrid, throwaway counterfactual: dock-hold <sha> + causality.diff sha256 <hash>, never committed; user approved, 2026-11-12)**, and change the answer sentence if the verdict changes it. Run the docs checks of Task 3 Step 6.
- [ ] **Step 7: Remove the worktree** (also after any STOP from Step 2 on): `git -C ~/projects/wargrid-wt-dock worktree remove --force ~/projects/wargrid-overnight-work/night-2026-11-13/xcell-causality`, then `git -C ~/projects/wargrid-wt-dock worktree list | rg xcell-causality; echo "listed=$?"` → `listed=1`. Then `git -C ~/projects/wargrid-wt-dock status --short` lists only the note and the verification file. Remove denied or `listed=0`: **STOP (BLOCKED)** with "throwaway worktree left at ~/projects/wargrid-overnight-work/night-2026-11-13/xcell-causality, remove in the morning" in the resume record; never commit there.
- [ ] **Step 8: Update the resume record** (T4 green, verdict, worktree removed) and append a T4 row.

STOP conditions for this task: the preconditions of Step 1; the before line not found; a diff outside `supply_collection.gd`; any wish to change a second line or to run another scenario → park. Never commit in the throwaway worktree; never leave it behind.

---

### Task 5: Fresh review (stop gate). Model: Opus (high), fresh context

**Files:** fixes only in the files Tasks 1-4 touched on `dock-hold`.

- [ ] **Step 1: `/ponytail-review` on the run's commits** (`git -C ~/projects/wargrid-wt-dock diff <base commit from the resume record>..HEAD`; over-engineering only); apply cuts; rerun Task 3 Step 7.
- [ ] **Step 2: Fresh Opus reviewer** (one reviewer for the whole diff, no repo-wide search). Give it: that diff, this plan, `extra-cell/verdicts.md`, `trip.txt`, `cells.txt`, `causality.diff`, `causality.txt`, `gap/wargrid-probe2.txt`, and the code ranges cited in the candidate table. Ask: every number in the note traces to a line or an arithmetic step; labels and trees right; the kill checks fair and applied before the supporting numbers; the named rule (if any) follows from R1-R8, the budget and the causality check; per test, the production change that would make it fail.
- [ ] **Step 3: Fix findings**, rerun Task 3 Steps 6-7, record findings and fixes as a T5 row.
- [ ] **Step 4: Update the resume record** (run finished; next action: user reads the note subsection; morning items: re-measure on the c1 rebuild once merged, and the fix design). The coordinator then makes the Task 5 commit, records the gate, notifies the user and ends. Never push.

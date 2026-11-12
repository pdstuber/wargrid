# Dock-Hold Experiment Implementation Plan

**Status: approved by the user 2026-11-12 (subagent-driven run).**

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run rules: [milestone prompt](../../milestone-prompt.md).

**Goal:** Measure Zero Hour's dock lock per visit and the steady multi-collector rates, then report how two Wargrid dock models (A split hold, B approach queue) compare with Zero Hour on every judging row, without changing Wargrid's default model.

**Architecture:** The fork exposes each dock's active docker in `/units`; the harness records it and a 600 s variant of the `collect_*` scenarios; the analyzer turns traces into lock windows and old-window and steady-window rates. On branch `dock-hold` a test-only `Simulation.dock_model` switch selects `hold` (today, default), `split` or `queue` in `supply_collection.gd`; one new report suite prints every judging row per model. A reference note compares them and stops for the user.

**Tech Stack:** C++ (fork `~/projects/GeneralsGameCode-macOS`, branch `wargrid-parity`), Python 3 stdlib (harness), typed GDScript (Godot 4.7.2).

**Spec:** [dock-hold experiment design](../specs/2026-11-12-dock-hold-experiment-design.md) (approved 2026-11-12). Background: [faction income parity](../../reference/faction-income-parity.md).

## Global Constraints

- Evidence only. The default model stays `hold`; with `dock_model` unset the full suite passes unchanged (every pinned trace and digest identical). No change under `game/scripts/simulation/definitions/` or to any gated target or tolerance in `test_supply_parity.gd`.
- Variant code stays on branch `dock-hold` (worktree `~/projects/wargrid-wt-dock`, from `main`). Only Tasks 2 and 7 (harness tooling, note) are meant for `main`: keep them in their own commits so they can be cherry-picked; the merge itself is the user's decision.
- `dock_model` is a plain `var dock_model: String = "hold"` on `Simulation`; set only by tests, never by a command, a scene, a replay or the network. Values: `"hold"`, `"split"`, `"queue"`.
- Zero Hour runs always `-headless -noaudio` through `tools/zh_parity/parity.py`; fork commits are local, never pushed. No EA code, INI data or bone positions copied into Wargrid; B's spots are Wargrid's own.
- Pass rule (spec): the eight opening rows (`usa2`, `china3`, `frc5`, `frc7` x gaps 3 and 9) within 5 % of Zero Hour in net at 600 s and in steady rate; every single-collector row of `test_supply_parity.gd` `TARGETS` within 5 %; the five `MULTI` rows and Chinook x4 within 5 % of the re-measured target on the steady window. Old-window numbers are reported, not judged.
- Steady window: 300-600 s after the first collector's gather order (Zero Hour `meta["order_frame"]`; Wargrid tick of the `gather` command), ending early when the pile is empty; a window ending before 450 s is flagged.
- B's calibration: one in-dock time per collector kind and target, fitted to the single-collector rows only. Nothing fitted to multi-collector or opening rows.
- Simulation code follows the [determinism rules](../../reference/determinism-rules.md) (integer ticks, ordered containers, no wall clock).
- Work folder `~/projects/wargrid-dock-work/` (briefs, traces, pooled tables, reports); outside the repo.

## Review Focus

1. A collector removed (killed, retargeted by a player command, pile deleted) while it holds a lock or stands in a queue: the lock and its queue slot are freed the same tick, nobody waits forever. Tests in Tasks 5 and 6.
2. Two collectors arriving on the same tick at an idle target: exactly one gets the lock, chosen by a stable rule (lower id). Tests in Tasks 5 and 6.
3. Pile empty while collectors wait or hold the lock: waiters leave like today (`_admit` boxes-0 path), the steady window ends at the empty tick on both sides. Zero Hour's `SupplyDock` may not be deleted when empty, so the analyzer detects "empty" from the trace (no deposit after the pile's last box), not only from a `dead` row. Tests in Tasks 2 and 4.
4. A collector told to `stop` or `move` mid-visit under `split` or `queue`: same result as under `hold` (collection disabled, lock released). Test in Task 5 (both models).
5. A lock window in a Zero Hour trace that never closes (game ends mid-visit): dropped from the median, counted in the output. Test in Task 2.

---

### Task 1: Fork exposes the active docker

**Files (fork `~/projects/GeneralsGameCode-macOS`, branch `wargrid-parity`):**
- Modify: `GeneralsMD/Code/GameEngine/Include/GameLogic/Module/DockUpdate.h` (public `ObjectID getActiveDocker() const { return m_activeDocker; }`)
- Modify: `Core/GameEngine/Source/Common/ExternalControl/ExternalControlSystem.cpp` (`/units`: for an object whose `getDockUpdateInterface()` is a `DockUpdate`, add `"activeDocker": <id or 0>`)

**Interfaces:**
- Produces: `/units` entries of docks (pile, supply centers, stash) carry integer `activeDocker` (0 = none).

- [ ] **Step 1:** Implement; rebuild per [harness setup](../../reference/zero-hour-parity-harness.md#setup-once-per-machine) step 3 in the background, log to the work folder; exit 0.
- [ ] **Step 2:** `python3 -I tools/zh_parity/parity.py --smoke` passes (no regression of the API).
- [ ] **Step 3:** Fork commit "Expose a dock's active docker to the parity API" (local; never push). Record the hash in the work folder.

### Task 2: Harness records locks, 600 s collect rows, lock and rate metrics

**Files:**
- Modify: `tools/zh_parity/parity.py` (`Game.record(..., docks=())`: one extra row per dock id per frame, `(frame, dock_id, "lock", "", "", "", "", "", activeDocker)`; `collect(kind, dist, collectors=1, deposits=8, limit=22000, seconds=None)`: with `seconds`, record every collector plus the pile and the depot (both as docks) for `seconds * 30` frames after `order_frame` instead of stopping at `deposits * collectors`; register `collect_<kind>_u<units>_x<n>_s600` for the six re-measure rows: `chinook u3125 x2`, `worker u1625 x2`, `worker u1625 x4`, `truck u3125 x2`, `truck u3125 x4`, `chinook u3125 x4`)
- Modify: `tools/zh_parity/analyze.py` (`lock_windows(rows, dock_id) -> dict`; `collect_rates(meta, rows) -> dict`; a scenario whose name ends `_s600` maps to `collect_rates` merged with `lock_windows` for the pile and the depot in `metrics()`)
- Test: `tools/test_zh_parity.py`

**Interfaces:**
- Produces: `lock_windows(rows, dock_id)` returns `{"median": float | None, "count": int, "open": int, "lengths": list[int]}` (frames from a change of `activeDocker` to a nonzero id until it changes again; `open` = windows still running at the last frame, excluded from `median`). `collect_rates(meta, rows)` returns `{"old_per_min": float, "steady_per_min": float | None, "pile_empty_s": float | None, "window_end_s": float, "short_window": bool}`; `old_per_min` is today's `collecting()` value over the first `8 * collectors` deposits; `steady_per_min` uses 300-600 s after `order_frame`, ended by `pile_empty_s`; `short_window` is `window_end_s < 450`.

- [ ] **Step 1: Failing tests** in `tools/test_zh_parity.py`:
  - `test_lock_windows`: synthetic `lock` rows for dock 9 with `activeDocker` 0,5,5,5,0,6,6,0,7 (frames 1-9) give `lengths == [3, 2]`, `median == 2.5`, `count == 2`, `open == 1`.
  - `test_collect_rates_steady_window`: money rising 75 every 60 frames from frame 100 for 600 s gives `steady_per_min == 75.0` and `old_per_min` equal to `collecting()`'s `credits_per_min` on the same rows.
  - `test_collect_rates_pile_empty`: deposits stop at 500 s and the pile reads 0 boxes from then on (or no deposit follows), so `pile_empty_s == 500.0`, the window ends there and `short_window` is false; stopping at 400 s gives `short_window` true.
- [ ] **Step 2:** `python3 -m unittest discover -s tools -p 'test_zh_parity.py'` fails on the missing functions.
- [ ] **Step 3: Implement** `record(docks=...)`, the `seconds` mode and the `_s600` registrations in `parity.py`; `lock_windows`, `collect_rates` and the `metrics()` mapping in `analyze.py`. Pile empty: the first frame the pile's row is `dead`, else the frame of the last deposit if no deposit follows within 300 frames before the trace ends. Old scenarios keep their names and output.
- [ ] **Step 4:** Tests pass; `sh tools/run_python_checks.sh` exit 0.
- [ ] **Step 5:** One real row end to end in the background: `python3 -I tools/zh_parity/parity.py --out ~/projects/wargrid-dock-work/zh-probe collect_worker_u1625_x4_s600`; `analyze.py --json` shows `lock_windows` with `count > 0` for pile and depot, 4 depositors, `steady_per_min` set.
- [ ] **Step 6:** Commit "Record dock locks and steady collect rates in the parity harness" (tooling only, cherry-pickable).

### Task 3: Zero Hour sweep (decision-free)

**Files:** none in the repo; results in `~/projects/wargrid-dock-work/zh/`.

- [ ] **Step 1:** `python3 -I tools/zh_parity/parity.py --out ~/projects/wargrid-dock-work/zh --repeats 3 --lanes 3 'collect_*_s600'` in the background (18 jobs); `runs.jsonl` shows 18 finished, 0 failed.
- [ ] **Step 2:** `python3 -I tools/zh_parity/analyze.py --json ~/projects/wargrid-dock-work/zh/rep1 ~/projects/wargrid-dock-work/zh/rep2 ~/projects/wargrid-dock-work/zh/rep3 > ~/projects/wargrid-dock-work/zh/pooled.jsonl`; write `pooled.md`: per row old and steady rate (median of 3, spread), pile empty time, short-window flag; per kind and dock the median lock window (pile, depot) from the x4 rows and from x2.
- [ ] **Step 3: Saturation check.** A kind is saturated in its x4 row if the pile's `activeDocker` is nonzero in at least 80 % of frames of the steady window. For a kind that is not, rerun its `open_*` gap-3 rows with locks recorded (`record(docks=...)` added to `opening()` in the same way, as one more tooling-only commit) and take its lock windows from there. Record which source each lock window came from.
- [ ] **Step 4:** Record fork hash, Wargrid commit and trace dirs at the top of `pooled.md`.

### Task 4: Dock-model switch and the report suite (`hold` baseline)

**Files:**
- Modify: `game/scripts/simulation/simulation.gd` (`var dock_model: String = "hold"`)
- Modify: `game/tests/test_income_openings.gd` (`run_opening(name, gap, model: String = "hold")` sets `sim.dock_model`; `report_line` gains ` model=<m>`; existing cases unchanged)
- Modify: `game/tests/test_supply_parity.gd` (`layout(kind, gap, count = 1, model := "hold")`; new `steady_rate(sim, gather_tick: int) -> Dictionary` returning `{"per_min": float, "pile_empty_s": float, "short": bool}` over 300-600 s after the gather tick; gated cases unchanged)
- Create: `game/tests/test_dock_models.gd` (registered in `game/tests/run_tests.gd` `SUITES`)

**Interfaces:**
- Consumes: `run_opening`, `layout`, `rate`, `steady_rate`, `TARGETS`, `MULTI`, `FOUR_HELICOPTERS_GAP_9`.
- Produces: `MODELS := ["hold", "split", "queue"]` in `test_dock_models.gd`; `WARGRID_DOCK_MODELS` env var (comma list, default all) limits which models run; report lines `DOCK <model> single <kind> gap=<g> rate=<f>`, `DOCK <model> multi <kind> gap=<g> x<n> old=<f> steady=<f> pile_empty=<s|-> short=<bool>`, and the `INCOME ... model=<m>` lines.

- [ ] **Step 1: Failing tests** in `test_dock_models.gd`:
  - `test_default_model_is_hold`: `Simulation.new([], Vector2i(8, 8)).dock_model == "hold"`.
  - `test_steady_rate_window`: a `frc_builder` gap-3 x2 layout under `hold` gives `steady_rate(...).per_min` within 2 % of `rate()` (both collectors start at tick 0, so there is no ramp-in to separate the windows) and `short == false`.
  - `test_report_rows`: for each model in `WARGRID_DOCK_MODELS` print every single, multi and opening row; check each row deposits (`rate > 0`). Under `hold` until Tasks 5-6 add models.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=test_dock_models sh tools/run_tests.sh` fails.
- [ ] **Step 3: Implement** the switch, the parameters and `steady_rate`. An unknown `dock_model` value asserts in `supply_collection.gd`'s `step` entry.
- [ ] **Step 4:** Suite file passes; full suite exit 0 with `TESTS PASSED` and the same case and check counts as `main` plus the new suite's; `sh tools/run_lint.sh`, `sh tools/run_warnings.sh` (after `git add -N` of the new file), `sh tools/run_python_checks.sh` exit 0. Save the `hold` report lines to `~/projects/wargrid-dock-work/wargrid-hold.txt`.
- [ ] **Step 5:** Commit "Add a test-only dock model switch and report suite".

### Task 5: Model A, split hold

**Files:**
- Modify: `game/scripts/simulation/supply_collection.gd` (under `sim.dock_model == "split"` only)
- Test: `game/tests/test_dock_models.gd`

**Interfaces:**
- Consumes: Task 3 lock windows; Task 4 switch.
- Produces: `const SPLIT := {kind: {"source": {"lead": int, "box": int}, "depot": {"lead": int, "work": int}}}` in `supply_collection.gd` for `frc_builder`, `china_collector`, `usa_collector`, with `lead + (boxes + 1) * box == (boxes + 1) * load_ticks` and `lead + work == unload_ticks`, `box = round(E_source / (boxes + 1))`, `work = round(E_depot)` from Task 3's median lock windows (E in frames = ticks); where E is at least today's stand, `lead = 0` and the kind keeps today's ticks (reported in the note, not forced); phases `lead_source`, `lead_depot` (non-exclusive; any number of collectors at once), then today's `loading` / `unloading` with the lock.

- [ ] **Step 1: Failing tests:**
  - `test_split_lone_cycle_unchanged`: for each kind in `TARGETS` at gap 3, the first 9 deposit ticks of a lone collector are identical under `hold` and `split`.
  - `test_split_overlaps_lead_in`: two `frc_builder` at a gap-3 pile under `split`: some tick has one collector in `loading` and the other in `lead_source`; no tick has two collectors in `loading` at the same pile.
  - `test_split_same_tick_arrival`: two collectors finishing `lead_source` on the same tick at an idle pile: the lower id gets `loading`, the other waits.
  - `test_split_release_on_removal`: removing the lock holder (`remove_object`) or sending it `stop` lets the waiter start `loading` on the next tick; deleting the pile (`delete_when_empty` source with 1 box) frees all waiters.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=test_dock_models sh tools/run_tests.sh` fails.
- [ ] **Step 3: Implement** `split`: on arrival enter `lead_*` for `lead` ticks without touching `active_collector_id`, then `_admit` as today with `box` / `work` instead of `load_ticks` / `unload_ticks`. `hold` code paths unchanged.
- [ ] **Step 4:** Suite file passes; full suite exit 0 (default `hold`); lint, warnings exit 0. Save `split` report lines to `~/projects/wargrid-dock-work/wargrid-split.txt`.
- [ ] **Step 5:** Commit "Add split-hold dock model (experiment)".

### Task 6: Model B, approach queue (ground and air)

**Files:**
- Create: `game/scripts/simulation/dock_queue.gd` (static functions, called from `supply_collection.gd` under `sim.dock_model == "queue"`)
- Test: `game/tests/test_dock_models.gd`

**Interfaces:**
- Consumes: Task 4 switch; existing `_ring`, `_claim_dock`, `_arrival`, `release`.
- Produces: per target `queue: Array[int]` (collector ids in arrival order; target dictionaries gain the key only under `queue`); phases `queued_source` / `queued_depot` (standing at an approach spot), `entering_*` (moving to the dock spot, locked), `loading` / `unloading` (locked), `leaving_*` (moving to an exit spot, locked); `const QUEUE_WORK := {kind: {"source_box": int, "depot": int}}` calibrated in Step 4. Ground approach spots: free ring cells of the target in ring order; air approach spots: points at 1.5-cell steps on a ray from the target toward the collector's depot, one per queue slot (no cell claims).

- [ ] **Step 1: Failing tests:**
  - `test_queue_fifo`: three `frc_builder` reaching a gap-3 pile on ticks t, t+1, t+2 get the lock in that order; queued collectors stand on distinct cells.
  - `test_queue_lock_covers_moves`: the lock holder's `active_collector_id` is set from `entering_source` until `leaving_source` ends; the next collector starts `entering_source` only after that.
  - `test_queue_air`: two `usa_collector` at a gap-9 pile: the second waits at an air spot while the first is locked; both deposit.
  - `test_queue_same_tick_and_removal`: same-tick arrival orders by lower id; removing the holder, a `stop` to a queued collector, or deleting the pile removes the id from `queue` and frees the lock that tick.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=test_dock_models sh tools/run_tests.sh` fails.
- [ ] **Step 3: Implement** `queue` with placeholder `QUEUE_WORK` equal to today's `load_ticks` / `unload_ticks`; register the new phase names wherever `view_rows.gd` maps phases.
- [ ] **Step 4: Calibrate:** per kind in `TARGETS`, choose `QUEUE_WORK` so the lone single-collector rows at gaps 3 and 9 (and 27 where listed) sit within 5 % of their targets, using only those rows; record each tried value and its rows in `~/projects/wargrid-dock-work/queue-calibration.md`. If no value passes for a kind, stop the task and report (do not tune per row).
- [ ] **Step 5:** Suite file passes; full suite exit 0; lint, warnings exit 0. Save `queue` report lines to `~/projects/wargrid-dock-work/wargrid-queue.txt`.
- [ ] **Step 6:** Commit "Add approach-queue dock model (experiment)".

### Task 7: Comparison note (stop)

**Files:**
- Create: `docs/reference/dock-hold-experiment.md`
- Modify: `docs/reference/faction-income-parity.md` (decision items 1 and 2 link the new note; no number changed)
- Modify: `docs/STATUS.md` (finding F3 links the note)

- [ ] **Step 1:** Note, payoff first: (1) re-measured Zero Hour targets, old against steady window, against today's gated values; (2) lock windows per kind and dock; (3) per model (`hold`, `split`, `queue`) a pass/fail table over every judging row with both numbers and the delta, short windows flagged, far-depot rows called out (the design's known risk: A cannot move unsaturated rows); (4) B's calibration; (5) decision list for the user: adopt `split`, adopt `queue`, neither; new `MULTI` targets (separate decision, design item 2); FRC bot collector count (income note item 4). Labels: **measured (source build, fork <hash>)**, **measured (Wargrid, branch tree <hash>)**.
- [ ] **Step 2:** `sh tools/check_public.sh` passes (after `git add -N`); new links and anchors resolve.
- [ ] **Step 3:** Fresh Opus review of the note against `pooled.md`, the three `wargrid-*.txt` files and the diff of Tasks 4-6 (numbers, claims, pass/fail verdicts, that no gated target or default moved). Fix findings.
- [ ] **Step 4:** Commit "Compare dock models with Zero Hour" (docs only, cherry-pickable). **STOP:** the user decides on adoption, targets and merge.

**Model routing:** this plan by Opus; Tasks 1-6 Sonnet, Task 3 may run on the cheapest tier (commands and a table only, except the saturation check: Sonnet); per-task gate reviews and the Task 7 review Opus. Coordinator posts the Task / What / Status table on every task state change.

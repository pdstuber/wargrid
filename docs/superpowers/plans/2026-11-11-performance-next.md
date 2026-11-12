# Performance Next Implementation Plan

**Status: written 2026-11-11 with the user (wizard answers in the [design answers](../../reference/design-answers-2026-11-08.md#performance-next-user-2026-11-11)); run not started.** The user starts it with "run docs/perf-next-prompt.txt".

> **For agentic workers:** run rules are in the handoff (`perf-next-prompt.txt`, private) and the [milestone prompt](../../milestone-prompt.md). The coordinator reads only "Dispatch". A task subagent reads the handoff once, "Conventions", its own task and the files that task names.

**Goal:** Make a 210-unit 3v3 run smoothly in Firefox on a slow device, and settle the simulation's data layout before the movement milestone, by removing structural waste first: everything in one frame, three Dictionaries per unit per tick, a size-optimised browser build.

**Architecture:** No simulation behaviour changes in this plan. Step and presentation are separated in time (T1) and later by thread (T5, design only). Drawing stops reading the full snapshot and reads a few packed arrays written once per tick (T3, T4). The storage proposal (packed arrays in GDScript system by system, Rust kernels only under hot systems; note section 7) goes to the user at gate 3 with measured numbers.

**Tech stack:** Godot 4.7.2, typed GDScript, the existing benchmarks, profiler zones and web bench tools.

**Evidence and reasoning:** [performance next](../../reference/performance-next.md) (read sections 1, 3, 5, 6 and 8 once). Resume record and rows: `docs/reference/performance-next-verification.md` in the run's worktree (created by T0; it does not exist on `main` yet).

## Conventions

Every task follows these; a task that cannot returns `BLOCKED`.

- **Places.** `MAIN` = `~/projects/wargrid`. `WT` = `~/projects/wargrid-wt-perf` (branch `perf-next`, created by T0 from `main`). All work happens in `WT`; `MAIN` is never edited by this run. The resume record is `WT/docs/reference/performance-next-verification.md`; the coordinator's own git checks run as `git -C WT ...`. `WORK` = `~/projects/wargrid-perf-work` (not tracked; logs, exports, scratch scripts; today's experiment results are already there).
- **Every shell call starts with `cd WT && `.** A subagent's shell returns to `MAIN` after each call. Every log starts with `pwd` and `git rev-parse --short HEAD`.
- **Host.** The Mac mini (Apple M6). No Steam Deck in this run (user, 2026-11-11). Budgets are the ledger's dev-machine values (target ÷ 5.5): simulation tick p95 1.82 ms, plumbing 0.91 ms, rendered frame 3.04 ms. Never change a budget, ceiling, guard or pin; report `EXCEEDED`.
- **Quiet host for timings.** Before every timed run: `uptime` (load under 2.5), the heavy-app `pgrep` check (if running: measure, tag the row "loaded", rerun later), no other Godot, scons or emcc process. Benchmarks run alone, never beside the suite.
- **Comparisons.** At least 3 runs per variant, interleaved (A B A B A B), same tree apart from the variant. Report median and spread (max - min). A difference smaller than the A/A spread is noise and is reported as "no gain".
- **Traces.** Every task in this plan is trace-preserving. After a task: `sh tools/run_tests.sh` green (it contains the replay, pin and digest tests), and for T1 and T4 also the netplay `match` scenario (`sh tools/run_netplay.sh`, read its usage first) as a regression guard; its clients run `headless_client.gd`, so it does not exercise the game scenes' frame loop. A moved pin or digest is a bug in the task, never something to re-pin.
- **Checks before `GREEN`.** `sh tools/run_tests.sh`, `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, each with `timeout: 600000`, output to a file under `WORK/logs/`, read only the summary lines. `sh tools/run_benchmark.sh` alone on a quiet host for tasks that touch `game/scripts/`.
- **Windows.** No task in this plan needs a rendered benchmark before T4's measurement. Task subagents never open a window; a task is `GREEN` on its headless checks. Where a rendered run is named (T4 "Measure"), the coordinator asks the user first and runs it itself.
- **Failure rule.** If a task's pass condition fails, the same subagent diagnoses and tries once more. A second failure returns `BLOCKED`; the coordinator then stops and asks the user.
- **Commits.** T0 asks the user once whether local commits on `perf-next` after each `GREEN` are allowed for this run (never push). If not, changes stay uncommitted in `WT` and each task lists its changed paths. A change that a gate rejects is undone with `git -C WT revert <commit>` (or by restoring the listed paths), never by editing history.
- **Rows.** Every measurement goes into the verification file as a dated row with tree, command, load, and the label measured / inferred / estimate. A task's ledger row (`docs/reference/performance.md`, History) is written at its gate, not per run.
- **Models.** Sonnet 5.5 implements. Opus 5.5 writes designs and task expansions and does the gate reviews. A Sonnet task that meets a design question returns `BLOCKED` with the question, options and a recommendation; it does not decide.
- **Code style.** Typed GDScript, small functions, no comments except a one-line "why", no new abstraction beyond what the task names. New tests use only the [simulation interface](../../reference/sim-interface.md).

## Dispatch

| Task | Model | Depends on | Ends with |
|---|---|---|---|
| T0 worktree, baseline, resume record | coordinator | | rows |
| T1 tick split | Sonnet | T0 | `GREEN` on headless checks |
| T3 view rows probe | Sonnet | T0 | rows, then **stop gate 1** |
| **Stop gate 1** | Opus review, user | T1, T3 | user: playtest the split with the F3 overlay, read the numbers |
| T4 view rows: design (Opus), then implementation (Sonnet) | Opus, Sonnet | gate 1 | **stop gate 2** after the design, `GREEN` after the implementation |
| T5 simulation on a worker thread: design | Opus | T4 done (the worker probe passed on 2026-11-11, note section 5.2) | **stop gate 3** |
| T6 data layout decision note | Opus | T4 done | **stop gate 3** |

T1 and T3 touch different files and may run one after the other without waiting for windows. Nothing after a stop gate starts without the user's explicit go. Not in this plan, each started by the user on its own: the golden scenarios plan, the movement and pathing milestone, split rates and the other trace-moving simulation changes (levers E, F, G of the note), the horde spike's playable scene.

## Tasks

### T0: Worktree, baseline and resume record (coordinator)

The coordinator runs this task itself and may read this task body, the note's section 2 table and the summary lines of the logs it produces.

- [ ] `git -C MAIN status --short` and `git -C MAIN log --oneline -3`. Expected: clean, and `git -C MAIN log --oneline -- docs/perf-next-prompt.txt` shows a commit (the user committed the handoff documents). A dirty tree or uncommitted handoff documents is a blocker: tell the user.
- [ ] If `WT` does not exist: `git -C MAIN worktree add ../wargrid-wt-perf -b perf-next main`. If it exists, use it and read its resume record instead of repeating this task.
- [ ] Ask the user once (AskUserQuestion): "May this run make local commits on branch perf-next after each green task? Nothing is pushed." Record the answer in the resume record.
- [ ] Create `WT/docs/reference/performance-next-verification.md` with the resume record block from `docs/milestone-prompt.md` at the top.
- [ ] Baseline on a quiet host, each alone, output to `WORK/logs/t0-*.log`: `sh tools/run_tests.sh`, `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/run_benchmark.sh`, `sh tools/run_profile.sh`. Record: suite cases / checks / failures and the `TESTS PASSED` marker; the benchmark's summary lines; from the profile (`rg '^PROFILE (combat_skirmish3v3|team_match|combat_hordes300) zone=(step|snapshot|view.batch) ' <log>`) the mean and p95. Compare the means with the note's section 2 table; a difference above 10 % is reported, not explained away.

### T1: Tick split (Sonnet)

**What.** Today `main.gd` `_physics_process` runs `_step_simulation()` and `_refresh()` (snapshot, batch, HUD) in the same frame. At 30 ticks and 60 frames per second every second frame carries all the work and the other one none. After this task the step runs in the physics frame and the refresh in the next rendered frame, as long as idle frames exist between ticks. When they do not (display at or below the tick rate, or between 30 and 60 frames per second), it falls back to today's behaviour and tries again a few seconds later.

**Engine facts (checked in the 4.7.2 source).** In one engine iteration the physics callbacks run first, then `_process`, then drawing; `Engine.get_process_frames()` is incremented only at the end of the iteration (`main/main.cpp:5119`, after physics at `:4977` and process at `:5062`), so `_physics_process` and the following `_process` of the same iteration see the same value.

**Files.** New `game/scripts/presentation/presentation_clock.gd`; `game/scripts/main.gd`; `game/scripts/skirmish_main.gd` (its `_process` at about line 67 does NOT call `super`, and `online_main.gd` inherits it; its `_physics_process` times the tick for the automatic quality pick); `game/scripts/presentation/perf_overlay.gd` (one more number on the F3 overlay); tests in a new `game/tests/test_presentation_clock.gd` (register it the way other suites are registered in `game/tests/run_tests.gd`) and one case in `game/tests/test_skirmish_scene.gd`. `game/scripts/lab/art_lab.gd` extends `Node`, not `main.gd`: leave it alone.

**The clock (implement exactly this behaviour).** `PresentationClock` is a small `RefCounted` with no engine calls, so tests pass frame and tick numbers in:

```gdscript
class_name PresentationClock
extends RefCounted

const RETRY_TICKS := 150

var _pending := false
var _pending_frame := -1
var _last_step_frame := -1
var _immediate_until := 0

# Called after each simulation step. True: refresh now, in this frame.
func stepped(frame_id: int, tick: int) -> bool:
	_last_step_frame = frame_id
	if tick < _immediate_until: return true
	if not _pending:
		_pending = true
		_pending_frame = frame_id
	return false

# Called once per rendered frame. True: refresh now.
func rendered(frame_id: int, tick: int) -> bool:
	if not _pending or _pending_frame == frame_id: return false
	_pending = false
	# shortcut: no idle frame came between two ticks, so splitting cannot help at this frame rate; retry later.
	if _last_step_frame == frame_id: _immediate_until = tick + RETRY_TICKS
	return true
```

What it does, and what the table test pins (S = a frame with a step, I = a frame without; ticks count up by one per step):

| Frames | Refresh happens in | Why |
|---|---|---|
| `S I S I` (60 per second) | every `I` | split works |
| `S I I I S I I I` (120) | the first `I` after each `S` only | one refresh per tick |
| `S S S S` (30) | not in frame 1; in frame 2 from `rendered()`; from frame 3 on in every `S` from `stepped()`, for 150 ticks | fallback to today's behaviour |
| `S S I S S I` (45) | not in frame 1; frame 2 from `rendered()`; then every `S` from `stepped()` for 150 ticks | fallback; no tick's picture is skipped after the first |
| one frame with two steps, then `I` | once, in the `I` | one refresh covers both steps |
| after 150 ticks of fallback at 30 per second | one tick is deferred again and not refreshed in its own frame; the next frame's `rendered()` refreshes (showing the newer tick) and restarts the fallback | the retry costs one skipped picture every 5 seconds |

**Wiring.**

- `main.gd` gets `var _clock := PresentationClock.new()` and one helper, the only place that decides:

```gdscript
func _present_if_due() -> bool:
	if not _clock.rendered(Engine.get_process_frames(), simulation.tick()): return false
	_refresh()
	return true
```

- `main.gd` `_physics_process`: after `_step_simulation()` and the `_perf.record_step(...)` line, replace the direct `_refresh()` with: if `not is_processing()` (nothing will call `_process`; this is how the scene tests drive ticks, they call `set_process(false)` first) or `_clock.stepped(Engine.get_process_frames(), simulation.tick())`: `_refresh()`.
- `main.gd` `_process` and `skirmish_main.gd` `_process`: call `_present_if_due()` as the first statement, before `pan_camera` and `_view.advance_frame()`. Find every other `_process` override in classes that extend `main.gd` with `rg -n 'func _process' game/scripts` and do the same.
- Automatic quality pick: `skirmish_main.gd` `_physics_process` adds the time of `super(delta)` to `_auto_tick_usec` while `_auto_pending`. Keep the pick counting step plus refresh: in `skirmish_main.gd` `_process`, time the `_present_if_due()` call and add the elapsed time to `_auto_tick_usec` under the same condition, but ONLY when it returned true. (Test Q12 in `test_graphics_settings.gd` asserts an exact sample value after a `_physics_process` and a `_process` call; adding even a few microseconds when nothing was refreshed would break it. Its expected value must not change.)
- A new simulation needs a new clock: the fallback is counted in ticks, and a restart sets the tick back to 0. Wherever a scene assigns `simulation` (`rg -n 'simulation = ' game/scripts`), also assign `_clock = PresentationClock.new()`.
- F3 overlay: the clock counts how many refreshes came from `rendered()` (split active) and how many from `stepped()` (fallback); add two read-only counters to the clock, and one short item to the overlay's text, for example `split 97%` (share of the last 300 refreshes that came from `rendered()`). This is what tells the user at gate 1 how often the split is really active on their machine. HUD rule: add a case to `game/tests/test_perf_overlay.gd` for the new text.
- Paused (`_pause.visible and _pauses_sim()`): unchanged; nothing is stepped, and a pending refresh is still presented by `_process`.

**Steps.**

- [ ] Write the failing table test for `PresentationClock` first: feed each frame sequence of the table above as (frame number, steps in that frame) and assert the list of frames in which `stepped()` or `rendered()` returned true. Include the retry row.
- [ ] Implement the clock and the wiring. Run the suite. There are 31 direct `._physics_process(` calls in `game/tests`; they must pass unchanged. If one fails because its scene still has processing enabled and reads the view right after the call, add `set_process(false)` to that test's setup and change nothing else in it; list every such test in your report.
- [ ] Add one scene case to `test_skirmish_scene.gd` that proves the wiring in `skirmish_main.gd` `_process`, driven by real engine frames. Never await `physics_frame` in it (that puts the test inside a physics frame); awaiting `process_frame` is safe, because the tree emits it before the nodes' `_process` of that frame. Shape: scene in the tree, `set_physics_process(false)` so the engine itself does not step the simulation, `set_process(true)`; `await` one `process_frame` to start from a known point; call `scene._physics_process(0.0)` directly and check the view's tick did not advance; `await` one `process_frame` and check it still did not; `await` a second `process_frame` and check it advanced. (How the suite's cases await frames: `rg -n 'process_frame' game/tests | head`.) If reading "the view's tick" needs a seam, add one small read-only accessor, nothing more. This test must fail if `_present_if_due()` is removed from `skirmish_main.gd` `_process`: check that once by removing the call, then restore it.
- [ ] Headless checks green (Conventions). Return `GREEN`.

**How the gain is judged (no rendered benchmark).** The rendered benchmark does not use the clock, and "the larger of two parts is smaller than their sum" is arithmetic, so no window batch is run for T1. Two things are reported at gate 1 instead: from T3's profile, per scenario, the p95 of `step` next to the p95 of the hand-off (`snapshot` plus the `view.*` zones), which is how a tick divides over the two frames (inferred); and from the user's playtest, the F3 overlay's split share, which shows how often the split is active in real play. If the user rejects the feel, the T1 commit is reverted.

**Known limits to report, not fix:** the picture lags the simulation by one frame when the split is active; between 30 and 60 frames per second the split is off most of the time by design; at 60 frames per second a single late frame (two step frames in a row) switches the split off for 150 ticks; the online scene steps through lockstep (`_step_simulation` override), where a stalled tick produces no step and so no refresh, as today.

### T2: (dropped)

The speed-built web template was measured on 2026-11-11: 0-4 % gain, inside the noise, for a 26 % larger download ([note](../../reference/performance-next.md), section 5.1). Nothing to build. The number is kept so later task names stay stable.

### T3: View rows probe (Sonnet)

**Question.** How much of the per-tick hand-off (`snapshot` plus `view.batch`) could disappear if drawing read a few packed arrays instead of the snapshot? A probe, not a feature: scratch code under `WORK/probe-rows/`; nothing from it is kept in `WT` except rows in the verification file.

- [ ] Make a scratch copy of the tree: `mkdir -p WORK/probe-rows/tree && git -C WT archive HEAD | tar -x -C WORK/probe-rows/tree`. All edits of this task happen in that copy.
- [ ] In the copy's `game/scripts/presentation/world_view.gd`, split today's single `view.batch` zone in `set_state` (lines 179-205) into separate profiler zones (pattern: `var zone: int = Profiler.begin()` ... `Profiler.end(&"name", zone)`, as the function already does): `view.objects` around `WorldBatch.objects(_state)`, `view.poses` around `_track_poses(...)` and `_apply_alpha(...)`, `view.visuals` around `_visuals.update(_items)`, and `view.build` around `_rebuild_batch()` (it calls `_batch.build`, the largest part: drawing from rows still has to build the batch). Keep the outer `view.batch` zone so the parts can be checked against its total. Note: `game/benchmarks/run_profile.gd` creates the view without a visual director, so `view.visuals` stays empty there; report it as "not measured headless", do not attach one.
- [ ] In the copy's `simulation.gd` add a scratch method `view_rows() -> Dictionary` that fills, for all units in id order: `id`, `owner`, `hp`, `max_hp`, `target_id` (-1 for none), `kind_index` as `PackedInt32Array`; `x`, `y`, `heading_x`, `heading_y` as `PackedFloat64Array`; `flags` as `PackedByteArray` (bit 0: `combat.horde > 0`, bit 1: has `container_id`). `kind_index` indexes a list of kind names built once and cached. Wrap its body in a profiler zone `view_rows`. Fields to read per unit: `id`, `owner`, `kind`, `position`, `heading` (may be absent: default `[1.0, 0.0]`), `hp`, `max_hp`, `combat` (may be null; `combat.target_id` may be null). Compare with `WorldBatch.objects` and `_item` (`world_batch.gd:91-120`) to confirm nothing a unit's drawing needs is missing; list anything that is.
- [ ] In the copy's `run_profile.gd`, call `sim.view_rows()` once per tick next to the existing `snapshot()` call.
- [ ] Check once that the rows carry the same data: on one tick of `combat_hordes300`, for every unit compare the row values with the snapshot's entity (id, owner, position, heading, hp, max_hp, target id, kind name through the index). Print `ROWS EQUAL <count>` or the first difference.
- [ ] Run the copy's profile 3 times on a quiet host (`cd WORK/probe-rows/tree && sh tools/run_profile.sh > ../run-<n>.log 2>&1`). Report for `combat_skirmish3v3`, `team_match`, `combat_hordes300` and `movement_open` the mean and p95 of: `snapshot`, `view.copy`, `view.sort`, `view.objects`, `view.poses`, `view.build`, `view.batch` (the total of the four before it; say how much of it the parts do not cover), and `view_rows`. Then two sums per scenario: "hand-off today" = `snapshot` + `view.copy` + `view.sort` + `view.batch`; "lower bound from rows" = `view_rows` + `view.sort` + `view.poses` + `view.build` (what remains if drawing needed neither the snapshot copy nor the per-unit item Dictionary; `view.build` is counted at today's cost, although reading rows instead of item Dictionaries may make it cheaper). Say clearly that the second sum is a bound, not a measurement of a finished design.
- [ ] List every per-unit loop over `_state.entities` in `world_view.gd` (`rg -n '_state' game/scripts/presentation/world_view.gd`): function name, and whether it runs per tick (called from `set_state`), per rendered frame (called from `_draw` or `advance_frame`) or per input event (picking, selection). And list every `simulation.snapshot()` call under `game/scripts` outside `simulation/` (32 sites, `rg -n 'snapshot\(\)' game/scripts --glob '!**/simulation/**'`): file, function, what it reads, per tick / per frame / per input event.

**Output.** Rows and the two lists in the verification file. No recommendation beyond the numbers; the design is T4's.

### Stop gate 1

- Opus gate review (fresh context) of the T1 diff and of the T3 numbers: is the clock implemented as written and wired into every `_process` override, do the tests pin the table, is any gate, pin or budget touched, is the probe's `ROWS EQUAL` check real.
- For the user: play a skirmish from `WT` (`cd ~/projects/wargrid-wt-perf && sh tools/run_game.sh`), press F3, and say whether anything feels late and what split share the overlay shows; read the T3 numbers (how a tick divides, and the bound from rows). Then the user says whether the split is kept and whether T4 starts.

### T4: View rows (Opus design, then Sonnet)

- [ ] **Design (Opus).** Input: the T3 rows and lists, note sections 3 and 6 (lever C), `docs/reference/sim-interface.md`, `docs/superpowers/specs/2026-11-08-snapshot-copy-design.md` (what was rejected and why). Write `docs/superpowers/specs/2026-11-12-view-rows-design.md`: the row columns and who owns them; which `world_view.gd` consumers read rows and which keep reading a snapshot taken only on input events; how HUD, selection pruning (`main.gd` `_show`), picking, sound and visual directors get what they need; what stays on `snapshot()` (hash ticks, desync reports, tests); the test plan (the golden output test of the batch must stay green without changing its expected values); the expected gain per row from T3; the task list for Sonnet. The simulation interface note gets the new output. No simulation behaviour change, no trace change.
- [ ] **Stop gate 2:** the user approves the design.
- [ ] **Implementation (Sonnet),** one fresh subagent per design task, test-first, Conventions' checks after each.
- [ ] **Measure:** `sh tools/run_profile.sh` and `sh tools/run_benchmark.sh` before and after, 3 runs each; then the rendered benchmark (the coordinator asks the user first and runs it itself: `sh tools/run_game.sh res://scenes/movement_benchmark.tscn -- --zoom=0.5`, three runs before and three after, report-only because any `--zoom=` argument switches the gates off). Ledger row for the plumbing budget (0.91 ms) per layout.

**Pass.** `snapshot` is no longer called once per tick by the game scenes; the plumbing row improves by more than the spread on every layout; suite, pins, netplay unchanged.

### T5: Simulation on a worker thread, design only (Opus)

The probe passed on 2026-11-11: same tick time on a worker as on the main thread in Firefox, 16.6 ms main-thread frames meanwhile, 4-7 % threaded-build tax, identical digests (note section 5.2). Godot's "Separate" render thread is closed (slower on desktop, not working on the web): do not design around it. Input: `WORK/threads/threads-result.md`, the T4 design (the worker fills the view rows; the main thread swaps buffers), `docs/reference/determinism-rules.md` (ticks stay in order on one thread), the lockstep code in `game/scripts/net/`. Write `docs/superpowers/specs/2026-11-12-worker-thread-design.md`: ownership of the simulation object, command queue in, rows and events out, lockstep and hash ticks, pause, scene change and shutdown, the fallback when a build has no threads (the same pump called on the main thread), how tests keep driving ticks synchronously, the Safari check, the cross-origin isolation headers on the test app first, and a budget proposal re-derived from the new structure with measurements. No implementation in this plan.

### T6: Data layout decision note (Opus)

Input: note sections 5.3, 5.4 and 7 (packed arrays in GDScript give about 1.5x; a Rust kernel on packed arrays gives 34-58x with a hand-off of 0.1-0.4 %), `WORK/horde/` and `WORK/native-columns/result.md`, the T3 and T4 numbers, the native report's formulas (`docs/reference/native-sim-spike.md` section 1: `G_inc = 1 / ((1+T)(1-s) + s/E)` and the joint condition `1/K_lower + p <= 0.455`). Write a section "Decision inputs" into `docs/reference/performance-next.md`: the measured presentation read cost per entity after T4 (`p`); from a fresh `sh tools/run_profile.sh`, which share `s` of the tick of the goal rows (skirmish3v3, team match) and of hordes300 sits in systems that could run as kernels on packed arrays, system by system; what `G_inc` that gives with the measured E and T; the costs still to come (avoidance cap +0.5 ms, fog); and a recommendation between three options: packed arrays in GDScript only, packed arrays plus Rust kernels under named systems, or the whole port. State what would change the recommendation, and what the movement milestone must do so that its code can later take a kernel (flat arrays in, flat arrays out, static tables passed once).

### Stop gate 3

Opus gate review of the T4 implementation and the T5 and T6 documents. For the user: the worker design and budget proposal, and the data layout decision. Ends the run.

## Review focus (gate reviews)

- No pin, digest, budget, ceiling or guard changed anywhere in the diff.
- T1: the clock is the one written above; the tests would fail if the refresh ran in the step frame at 60 frames per second, if a tick's picture were skipped repeatedly at 30 or 45, and if `skirmish_main.gd` `_process` did not present; test Q12's expected value is unchanged.
- T3 and T4: equality (rows against snapshot, batch output before and after) is checked on real data, not asserted; no new per-tick Dictionary per unit sneaks back in.
- Every reported gain names its A/A spread.

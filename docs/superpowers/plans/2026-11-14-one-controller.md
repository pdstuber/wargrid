# One Controller Implementation Plan

**Status:** approved 2026-11-14 (user, kickoff questionnaire; answers in "Decisions (user, 2026-11-14)" at the end), not started. Written 2026-11-13 night as backup 1 of the Sim quick wins night run; refined 2026-11-14 for an unattended run (re-anchored on `35d22b5`, Decision 6 rename, Decision 17 fix tasks 9 and 10, review last). Resume record: [verification file](../../reference/one-controller-verification.md).

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development, task by task. Run rules: `docs/night-run.md` (Coordinator rules) and `docs/milestone-prompt.md` (session start, stop conditions). Resume record: the verification file. Every task subagent also reads "Global Constraints", "Pinned values", "Determinism notes", "Pinned shapes" and "Accepted reorders" (`rg -n '^## ' <plan>`).
>
> **Task numbers:** the kickoff answers named the two fixes "Task 10" and "Task 11" against the draft, where the review was Task 9. With the review moved last the run is Tasks 0-11: **Task 9** F3 during placement, **Task 10** two-tick online frame results, **Task 11** review.

**Goal:** night package 2 "One controller" (FIX-6 of the 2026-11-11 audit; `docs/packages.md:39` and the package note `:84`; design answers "Package review, second pass" and the 2026-11-13 line at `docs/reference/design-answers-2026-11-08.md:505`). The four-level chain `online_main.gd` → `skirmish_main.gd` → `base_main.gd` → `main.gd` becomes one match screen node plus three plain objects: a simulation driver (offline and online implementation), an orders object (input and selection in, command payloads out, placement and attack-move as explicit modes) and a HUD object (still the text label until P2.3a). The M2 and M3 demo scenes go. **No player change through the Task 8 gate; then two small fixes (Tasks 9, 10; Decision 17); no trace re-pin anywhere.**

**Done when** (package note): no script under `game/scripts/` extends another scene controller (`rg -n '^extends "res://scripts/' game/scripts` prints nothing), every pin below holds, and the suite, `sh tools/run_netplay.sh match` and the HUD layout tests pass (Task 8 gate). Then F3 toggles the perf overlay during placement (Task 9) and a two-tick online frame hands every tick's command results to the HUD (Task 10), each test-first, with the same pins and gates rerun; then the review and its fix round (Task 11). The audit's manual offline and online match in a window is a short attended check before P2.3a starts (user, 2026-11-13), not part of this run.

**Architecture:** three objects and direct calls; no event bus, no signals-for-everything, no command layer (audit FIX-6 "Do not"). The screen owns the scene, the tick loop and the wiring (camera, clock, pause menu, perf overlay, playtest overlay, sound, visuals, music, auto quality pick, restart, leave). The driver owns the `Simulation` and how commands reach it. Orders own selection and modes. The HUD owns the labels and buttons and the note line (today's `_error`). The `SimPump` seam stays in Later 3 (user, 2026-11-13); the W, A, S, D change stays in P2.3b.

**Tech stack:** typed GDScript (Godot 4.7.2), POSIX `sh`, Python 3.12 stdlib (asserted rename scripts and one scan script in `$L`, never committed).

**Written against** `main` `35d22b5` (clean; Sim quick wins merged, Decision 15). Drafted on `4ed3534`; every `file:line` anchor was re-checked with `rg -n` on `35d22b5` (2026-11-14). Since `4ed3534` the four controller scripts changed in one line only (`online_main.gd:109`, `_report` now calls `desync_report(simulation)`), so their line anchors hold; drifted anchors elsewhere (`simulation.gd` `issue_command`, `docs/development.md`, guide chapters 4, 10 and 13) are fixed below. Where a line is fragile the anchor names the symbol too; every task re-anchors by symbol (`rg -n 'func <name>'`) and records drift.

## Global Constraints

- **Paths.** Worktree `~/projects/wargrid-wt-onecontrol`, branch `one-controller` from `main` (Task 0 creates both; Decision 19). Logs and scratch files: `~/projects/wargrid-overnight-work/one-controller/logs`. This file is tracked and the repository is public, so it spells both with `~` (`tools/check_public.sh` rejects home paths); **in every command type the absolute path out in full** (the handoff gives it). `$W` below means the absolute worktree path and `$L` the absolute logs path: plan notation, never a shell variable, never `~` in a command or a shell assignment (denied at night, 2026-11-13). Agent shells reset their working directory: start every command with `cd $W && `. Never write logs into the repository. The resume record is the worktree's copy of the verification file.
- Every suite, benchmark, netplay, conformance, lint, warnings and Python-check call: Bash `timeout: 600000`, output to a file in `$L`, judged by exit code plus marker (`TESTS PASSED`, `CHECKS PASSED 5`, `NETPLAY PASSED` or the scenario's last line, `BENCHMARK PASSED 2` / `COMBAT BENCHMARK PASSED 10` / `LOCKSTEP BENCHMARK PASSED 1`). On failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:' <log>`.
- Static gates: `sh tools/run_checks.sh` (lint, warnings, Python, shell, public; `CHECKS PASSED 5`). A fresh worktree needs `godot --headless --path game --import` first; new scripts get `.gd.uid` files from the import, tracked like the others.
- While iterating: `WARGRID_TEST_ONLY=<suite file or case substring> sh tools/run_tests.sh`. The full suite is the gate before GREEN.
- **Command forms** (`<N>` is the task number; "full suite", "traces cmp", "static gates" and "netplay match" in the tasks mean exactly these):
  - filtered: `cd $W && WARGRID_TEST_ONLY=<substring> sh tools/run_tests.sh > $L/t<N>-only.log 2>&1; echo "exit=$?"`
  - full suite: `cd $W && sh tools/run_tests.sh > $L/t<N>-suite.log 2>&1; echo "exit=$?"`; then `rg -n 'TESTS PASSED|^CASES' $L/t<N>-suite.log`
  - full suite with traces: `cd $W && WARGRID_REPLAY_TRACE=$L/replay-t<N>.tsv WARGRID_ECONOMY_REPLAY_TRACE=$L/economy-t<N>.tsv WARGRID_COMBAT_REPLAY_TRACE=$L/combat-t<N>.tsv WARGRID_TEAM_REPLAY_TRACE=$L/team-t<N>.tsv sh tools/run_tests.sh > $L/t<N>-suite.log 2>&1; echo "exit=$?"`
  - traces cmp: `cmp $L/replay-before.tsv $L/replay-t<N>.tsv; echo "exit=$?"`, the same for `economy`, `combat`, `team` (each exit 0, silent)
  - static gates: `cd $W && sh tools/run_checks.sh > $L/t<N>-checks.log 2>&1; echo "exit=$?"` (`CHECKS PASSED 5`)
  - netplay match: `cd $W && sh tools/run_netplay.sh match > $L/t<N>-match.log 2>&1; echo "exit=$?"` (V6: `rg -n '9129|NETPLAY' $L/t<N>-match.log`)
  - V13 add (every task that edits a test file, after its rename if any, before GREEN): `cd $W && python3 $L/v13_check.py $W $L/v13-reasons.txt --add "Task <N>: <reason>" <edited test paths>`; it appends this task's uncommitted removed lines that no applied rename explains; copy the new rows into the verification file's reasons list. Leave out `game/tests/input_script_rows.gd` (new on the branch, so V13 never sees removals in it).
  - HUD layout tests: part of the full suite (`test_hud_layout_and_focus`, `test_result_clear_of_status`, `test_health_bar_clear_of_boxes`, `test_hud_font_size_is_shared` in `test_skirmish_scene.gd`, `test_menu_layout` in `test_pause_menu.gd`, the N3, M6, H6 checks, `test_status_lines_and_layout` in `test_online_scene.gd`); a green full suite with no `FAIL` line covers them, and the task records that it did.
- Allowed at night: `sh tools/run_*.sh`, `sh tools/check_public.sh`, `python3 …`, `godot --headless …`, `git` without push or merge, `git worktree add`. Denied: `git push`, `git merge`, `gh pr`, `fly`, deploys, `sh tools/run_game.sh`, any visible window, any Zero Hour launch.
- Subagents never commit; the coordinator makes the local commits the night run handoff (private notes repository) pre-authorizes: one per GREEN task, two in Task 9 (see there). It records the Task 1 commit and the Task 9 re-pin commit hashes in the resume record's Approved/pre-authorizations line (the bases of V10).
- Model routing: Sonnet for Tasks 0-10 and the Task 11 fix round; Opus (high) only for the Task 11 review and for the diagnosis of any IC1/IC2 difference, trace difference, pin change or unexpected red (Decision 16).
- Edit with the Edit tool or asserted replacements. Access-path renames (Tasks 4, 6, 7) go through a Python script in `$L` that applies each (receiver, member) pattern and asserts its expected count per file before and zero old matches after; any other changed test line is listed in the verification file with its reason. Scratch mutations are reverted with Edit and checked with `git diff --stat`.
- Moves are verbatim: a function that changes owner keeps its body; only receivers change (`_error` → `hud.note`, `selected_ids` → `orders.selected_ids`, `simulation` → `driver.sim` on the screen and `sim` inside a driver, Decision 6). Anything else that changes is in "Pinned shapes" or "Accepted reorders"; a change outside both is a stop. Tasks 9 and 10 are the only behaviour changes, each limited to what its task names.
- Comments: why only, one line. Keep the existing `shortcut:` comment on the auto quality pick (`skirmish_main.gd:121`) and the recorder comment (`skirmish_main.gd:59`, which becomes "Tests swap `driver.sim` directly; …" through the Task 4 rename) with the code they explain.
- New tests use only the simulation interface unless the file is on the `tools/test_sim_boundary.py` allowlist (`test_scene.gd`, `test_skirmish_scene.gd` and `test_announcer.gd` are; `test_online_scene.gd`, `test_perf_overlay.gd`, `test_base_scene.gd` are not). `sh tools/run_checks.sh` runs that check.
- **Don't touch:** `game/scripts/simulation/`, `game/scripts/presentation/`, `game/scripts/net/` (Decision 4), `game/scripts/playtest/`, `game/scripts/lab/` (its `fight.simulation`, `art_lab.gd:46`, is `lab_fight.gd`'s own field, not a match screen), `game/project.godot` (Decision 3), `relay/`, `protocol/`, `game/data/`, `.github/`, every pinned constant and trace below, `game/tests/test_team_match.gd`, `test_skirmish_match.gd`, `test_replay.gd`, `test_state_hash.gd`, `test_lockstep.gd`, `test_factions.gd`, `test_art_lab.gd`, `tools/test_sim_boundary.py` (test file names stay, so its allowlist stays). `.claude/` and the night settings file are the user's.

## Pinned values (none may change; any change is a stop condition)

Read on `35d22b5` (2026-11-14; V1-V7 unchanged since `4ed3534`); Task 0 reads them again from the base tree. A base value that already differs is recorded, not a stop; from then on the recorded value is the pin. Tasks 9 and 10 are controller code only: no trace, digest or pin below may change in them either.

| # | Where | Value | Checked by |
|---|---|---|---|
| V1 | `game/tests/test_team_match.gd:14` `FINAL_DIGEST` | `3958ceaab11986af` | full suite |
| V2 | `test_team_match.gd:16` `TEAM_CORE_SERIES` | `8513092129969516499` | full suite |
| V3 | `test_skirmish_match.gd:12` `S1_CORE_SERIES` | `4004499097874677431` | full suite |
| V4 | `test_state_hash.gd:6` `PINNED` `01e256834bdd4dfb`; `test_view_rows.gd:18` `EXPECTED_DIGEST` `7c7fbc8d…48a9e7`; `test_start_spots.gd:7` `SS6_PINNED` | unchanged | full suite |
| V5 | the four suite traces (`WARGRID_REPLAY_TRACE`, `WARGRID_ECONOMY_REPLAY_TRACE`, `WARGRID_COMBAT_REPLAY_TRACE`, `WARGRID_TEAM_REPLAY_TRACE`) | byte-identical to Task 0's `*-before.tsv` | `cmp` at Tasks 4, 5, 8, 9, 10, 11 |
| V6 | `tools/run_netplay.sh:91` match terminal tick | `9129` | Tasks 4, 8, 9, 10, 11 |
| V7 | `tools/run_team_match.sh:13` | `won tick=39497 winner=2 units_peak=271` | Task 8 |
| V8 | no pinned line changes in tests | `git diff main -- game/tests \| rg '^-\s*const'` prints nothing except the `const` preload lines of Tasks 2, 3, 4 (`test_skirmish.gd:17`) and 5 (each listed) | Tasks 8, 11 |
| V9 | `test_skirmish_scene.gd` `test_hud_summaries_are_pinned` (`:651`) literals | unchanged | full suite |
| V10 | `game/tests/input_script_rows.gd` (Task 1: `IC1_ROWS`, `IC2_ROWS`) | `git diff <Task 1 commit> -- game/tests/input_script_rows.gd` empty through Task 8; from Task 9 on, empty against the Task 9 re-pin commit, whose own diff changes only `perf=false` → `perf=true` in the F3-and-later rows | Tasks 2-11 |
| V11 | check-id census: `rg -o --no-filename '"[A-Z][A-Za-z]?[0-9]+[a-z]? ' game/tests \| sort -u` | Task 0's set minus exactly the Task 3 demo-only list, plus the new ids of each task: `IC1`, `IC2` (Task 1), `OD1`, `OD2` (4), `OR1` (6), `HU1` (7), `PO19` (9), `N27` (10); all eight are unused on `35d22b5` | Tasks 3, 4, 5, 6, 7, 8, 9, 10, 11 |
| V12 | `git diff main -- game/scripts/simulation game/scripts/presentation game/scripts/net game/scripts/playtest game/project.godot` | empty | Tasks 4-11 |
| V11b | label census: `cd $W && rg -o --no-filename '"[A-Z][A-Za-z]?[0-9]+[a-z]? [^"%]*' game/tests \| sort > $L/labels-t<N>.txt` (one line per check label, duplicates kept) | `diff $L/labels-before.txt $L/labels-t3.txt` removes exactly the 11 demo labels (8 S8, 2 S9 in `test_scene.gd`, 1 SD22 `"SD22 %s has no Sound child"` in `test_sound.gd`, which the pattern cuts at `%`) and adds only `IC1`/`IC2` labels; from Task 4 on a diff against the previous task's file only adds lines. Ids alone cannot show this: `"S8 "`, `"S9 "` also label checks in `test_combat.gd:1341-1365` and SD22 keeps its skirmish and online rows | Tasks 0, 3-11 |
| V13 | no silent test change: `cd $W && python3 $L/v13_check.py $W $L/v13-reasons.txt` (Run scripts) prints `V13 OK`: every line removed from `game/tests` against `main` is a rename of the applied Task 4/6/7 rules or is listed, with its reason, in `$L/v13-reasons.txt`, which each task that hand-edits a test fills with `--add` and copies into the verification file's reasons list | Tasks 8, 11 (and at the end of any task that hand-edits a test) |

Budgets: `docs/reference/performance.md`. On `35d22b5` the accepted line is `BUDGET EXCEEDED open dense hordes300 (regression ceilings held)` (open and hordes300 user 2026-11-07; combat dense user 2026-11-14, Sim quick wins verification file); Task 0 reads `main`'s last ledger row and records the base line, and that becomes the accepted line. Any other exceeded row or a broken ceiling (`run_benchmark.sh` exit 1) is a stop. Never loosen a budget, a ceiling or `ASSUMED_SLOWDOWN`.

## Determinism notes (`docs/reference/determinism-rules.md`)

No simulation file changes (V12). The controller decides only what reaches `issue_command` and when, so these stay byte for byte:

- **Command stamping (offline).** `main.gd:286-299` `_submit`: `payload.duplicate(true)`, then `tick` (`command.get("tick", state.tick)`), `player`, `sequence` (max of `last_sequences` + 1), issued through the recorder, `sequence` advanced only on `ok`. Moved verbatim. Payload key order does not reach state: `issue_command` (`simulation.gd:159`) rebuilds the command in a fixed key order (`:164-168`, the `normalized` dictionary) before it enters `pending_commands`, which `state.hash()` reads in insertion order (`state_hash.gd:12`, `determinism-rules.md:13`, `:25`); the recorder's log goes through `Lockstep.log_lines` with sorted keys. So the values (tick, player, sequence, fields) are the contract, not the literal key order.
- **Bot before step (offline).** `skirmish_main.gd:81-84`: `Skirmish.issue_opponent(recorder)` then `simulation.step()` then sound collection, once per physics frame. The bot gets the recorder, never the driver: bot memory is metadata on the `Simulation`, found through `has_method("simulation")` (`skirmish.gd:161-163`); an object without that method would key the memory on itself. The offline driver has a `sim` field and no `simulation()` method, so it must never be passed to `Skirmish`.
- **Lockstep loop (online).** `online_main.gd:50-66` moves into the online driver unchanged: poll and `receive`, relay-lost check, catch-up credit (`CATCH_UP_STEPS` 2, `MAX_CATCH_UP_CREDIT` 4), `advance`, per-tick sound callback, `finish_tick` with a snapshot when `wants_snapshot`. Wall-clock time stays where it is today (`transport.silent(Time.get_ticks_usec())`), outside the simulation.
- **Swapped simulations.** Tests assign the screen's simulation (24 `main.simulation =` on `35d22b5`); the recorder follows it (`skirmish_main.gd:59-62` `_recording`). From Task 4 tests read and assign `main.driver.sim` directly (Decision 6: no forwarding property). `_recording` moves into the offline driver and keeps its `is_same` check against the driver's own field: `if recorder == null or not is_same(recorder.simulation(), sim): recorder = CommandRecorder.new(sim)`, so a test that assigns `main.driver.sim` still gets a recorder on the new simulation. Nothing outside the four chain scripts reads the screen's `simulation` (checked on `35d22b5`: `rg -n '\.simulation\b' game/scripts` hits only `skirmish_main.gd:61` `recorder.simulation()` and `lab/art_lab.gd:46`, the lab's own `fight.simulation`; the playtest overlay gets callables, the recorder and the sound player get the simulation or the player id passed in, the launcher sets statics and calls `setup`).
- **Presentation randomness** (music shuffle, `skirmish_main.gd:39-41`) stays a local `RandomNumberGenerator` on the screen, never the simulation's RNG.

## Pinned shapes

**Files (Decision 11):** `game/scripts/match/match_screen.gd` (`extends Node`), `offline_driver.gd`, `online_driver.gd`, `orders.gd`, `hud.gd` (all `extends RefCounted`). Deleted: `game/scripts/main.gd`, `base_main.gd`, `skirmish_main.gd`, `online_main.gd` (with `.uid`), `game/scenes/main.tscn`, `base.tscn`, `online_skirmish.tscn` (Decision 8). `skirmish.tscn` keeps its name and nodes and attaches `match_screen.gd`.

**Driver (Decision 5: two duck-typed files, no base class; the screen holds `var driver: RefCounted` like `_lockstep: RefCounted` today, `online_main.gd:10`).**

| Member | Offline | Online (from `online_main.gd`) |
|---|---|---|
| `_init` | `(player: int)`, stored as `_player` | `(transport, lockstep, faction)` (today's `setup` minus the seat, which the screen keeps as `local_player`; the unused `seat` parameter went in Task 11c) |
| `var sim: Simulation` | yes | yes |
| `create(map_path, starts, factions, match_seed)` | `Skirmish.create(true, "ai", factions, map_path, starts)` (`skirmish_main.gd:57`); `_sequence = 0`; recorder dropped | `Skirmish.create(true, "human", {}, map_path, starts)` (`:36`); keeps them as `_map_path`, `_seed`, `_starts` for the report (never the parameter names: `shadowed_variable` is an error) |
| `start()` | nothing | `send`, `choose_faction`, `start(sim.snapshot())` (`:28-30`) |
| `step(after_tick: Callable) -> PackedStringArray` | issue_opponent, step, `after_tick.call()`; returns empty | `:51-66` with `after_tick.call()` for `_collect_sound()`; returns the new rejection errors |
| `submit(payload) -> Dictionary` | `main.gd:288-297` body (stamp, recorder, sequence) | `_lockstep.submit(payload)`; `{"ok": true, "error": ""}` |
| `recorder`, `_recording()` | `skirmish_main.gd:25`, `:59-62` with `sim` for `simulation` (see Determinism notes) | n/a |
| `step_results() -> Array` (added in Task 10, not before) | `sim.command_results().duplicate(true)` | every tick advanced in the last `step`, see Task 10 |
| `notice() -> String`, `net_line()`, `latency_line()` | `""` / n/a | `:113-143` |
| `pauses_sim()`, `confirm_leave()`, `can_restart()` | true, false, true | false, true, false |
| `over() -> bool` (playtest context) | `sim.match_over()` | `_finished` (`:70`) |
| `leave()` | nothing | `:45-47` |
| `detach()` (`_exit_tree`) | nothing | `:33` |
| `match_log() -> Dictionary` (`mode`, `factions`, `commands`) | `skirmish_main.gd:72` parts | `online_main.gd:74-75` parts |
| report, latency, desync file, `web`, `download`, `_own_faction` | n/a | `:12-17`, `:88-134`; `_report` keeps `_lockstep.desync_report(sim)` (today `desync_report(simulation)`, `:109`) |

`setup(transport, lockstep, seat, faction)` stays on the screen (launcher and tests call it before `add_child`, `launcher.gd:239-240`, `test_online_scene.gd:43-45`) and creates the online driver; `_ready` creates the offline driver when `setup` did not run (`driver == null`).

**No `simulation` property on the screen (Decision 6).** The screen holds `var driver: RefCounted` and nothing else for the simulation; screen code reads `driver.sim`, driver code reads `sim`, tests read and assign `main.driver.sim`. Before `setup` or `_ready` the driver is null, so `main.driver.sim` there is a `SCRIPT ERROR` (the suite fails on it; `tools/run_tests.sh` greps `SCRIPT ERROR:`). On `35d22b5` no test touches a screen's simulation before that point (Task 0 Step 6 scan re-checks it).

**Screen `_submit` and `_step_simulation` (Task 4), for both drivers.** In Task 4 these pinned forms replace `skirmish_main.gd:91-95` and `:81-84`, because `_sound`, `_playtest`, `_ensure_sound` and `_collect_sound` exist only from `skirmish_main.gd` down; `online_main.gd` `_step_simulation` (`:50-66`) and `_submit` (`:77-83`) are deleted and the online scene inherits them. `main.gd` keeps only the driver half so it still parses: `_submit` = `_show_hint(payload)`, `var result: Dictionary = driver.submit(payload)`, `_error = result.error`, `_refresh()`; `_step_simulation` = `driver.step(func() -> void: pass)`. Task 5 merges the levels into the pinned form.

```gdscript
func _submit(payload: Dictionary) -> void:
	_show_hint(payload)
	var result: Dictionary = driver.submit(payload)
	_error = result.error
	_refresh()
	if not _error.is_empty(): _sound.rejected(_error)
	else: _playtest.observe_command(payload)
	if result.ok: _sound.order(payload)
```

Offline this is `main.gd:286-299` plus `skirmish_main.gd:91-95` unchanged. Online see Accepted reorders R1.

**Screen `_step_simulation` (Task 4, in `skirmish_main.gd`):**

```gdscript
func _step_simulation() -> void:
	var rejected: PackedStringArray = driver.step(_collect_sound)
	if rejected.is_empty(): return
	_ensure_sound()
	for error in rejected: _sound.rejected(error)
	_error = "Rejected: " + rejected[-1]
```

**Input dispatch (Task 5 merges the three `_unhandled_input` levels; Task 6 moves the result into `orders.handle(event)` unchanged).** Order on `35d22b5` (unchanged since `4ed3534`), followed exactly; each helper is today's code block moved verbatim (with `driver.sim` for `simulation` from Task 4):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if driver.sim.match_over() or _playtest.holds_match(): return       # skirmish_main.gd:194-195
	if event.is_action_pressed("deselect"): inspected_id = -1            # :196
	if _placement_kind.is_empty() and _combat_input(event): return      # :197-222 (placement guard, then A, S, attack-move, defence, attack at :200-222)
	_hover(event)                                                        # base_main.gd:178-182
	if _economy_keys(event): return                                      # :183-194 (B, 1-9, E, U)
	if not _placement_kind.is_empty():                                   # :195-206
		_placement_input(event)
		return
	if _building_input(event): return                                    # :207-225 (Esc clears building and pending; right context or rally; left release on own building)
	_selection_input(event)                                              # main.gd:141-173 without the B branch (:148-149, unreachable: base returns on B first)
	if not is_selecting() and not _pending_placement.is_empty():         # base_main.gd:227-230
		var pending: String = _pending_placement
		_pending_placement = ""
		_enter_placement(pending)
```

Merged overrides, same Task: `_finish_selection` = `main.gd:182-204` then `skirmish_main.gd:182-184`; `_enter_placement` = `skirmish_main.gd:140` then `base_main.gd:153-161`; `pan_camera` and `change_zoom` return when `_selecting` or a placement is active (`main.gd:126-138`, `base_main.gd:140-144`); `_escape_pending` = `not driver.sim.match_over() and (_attack_move_mode or inspected_id != -1 or _selecting or not selected_ids.is_empty() or not _placement_kind.is_empty() or selected_building_id != -1 or not _pending_placement.is_empty())` (`skirmish_main.gd:79`, `base_main.gd:30`, `main.gd:87`; no side effects, so the flat `or` is equal). `_input` (`main.gd:95-103`) unchanged. `_process` is `skirmish_main.gd:111-119` (`ui_*` actions); `main.gd:121-124` (`camera_*`) is dropped with the demo. `_physics_process` is `skirmish_main.gd:106-109` wrapping `main.gd:105-114`, with `driver.pauses_sim()` for `_pauses_sim()`. Further merges (call order matters where noted): `_leave` = `driver.leave()` (body of `online_main.gd:45-47`), then `skirmish_main.gd:144-146` (playtest `end_match`, `await`), then `main.gd:90` (`change_scene`), in that order; `_production_kind` = `skirmish_main.gd:102-104` with the `base_main.gd:48-49` body as its fallback; `_hint_point` = `base_main.gd:39-43` with the `main.gd:279-281` body as its fallback; `menu_open` = `_pause.visible or _playtest.holds_match()` (`main.gd:77-78`, `skirmish_main.gd:53-54`); `playtest_context` = `skirmish_main.gd:67-69` with `"over": driver.over()` (`online_main.gd:68-71`); `_note` = `_error + driver.notice()` (`online_main.gd:145-146`; `hud.note + driver.notice()` from Task 7); `_refresh` = the `base_main.gd:67-71` version (`main.gd:231-232` goes); `_restart` = `skirmish_main.gd:149-175` behind `if not driver.can_restart(): return` (`online_main.gd:85-86`); `_exit_tree` = `driver.detach()` (`online_main.gd:32-33`); `_refresh_hud` = `base_main.gd:73-89`, then `skirmish_main.gd:279-290` without its `super` call, then `online_main.gd:150-152` (the M2 `main.gd:260-267` goes).

**`_ready` order (Task 5), kept because the first refresh creates the `Sound` child before `Music` and the playtest overlay:**

0. `if driver == null: driver = OfflineDriver.new(local_player)` (Task 4 puts this as the first line of `main.gd` `_ready`: the pause menu reads `driver.confirm_leave()` at `main.gd:45`, before `:59`).
1. HUD theme on `Status` and `Economy`, `BuildMenu` grid at index 0 (`base_main.gd:18-24`).
2. `main.gd:42-62`: perf overlay, pause menu and its signals, view settings, `local_player`, `driver.create(map_path, starts, factions, match_seed)` at `:59`, clock, camera, first `_refresh()`.
3. `Produce` and `CancelBuild` signals (`base_main.gd:26-27`).
4. `skirmish_main.gd:34-42`: visuals, auto pick, `Restart`, music, playtest overlay.
5. `_perf.extra = driver.net_line` when online (`online_main.gd:27`), then `driver.start()`.

**Orders (Task 6; Decision 7):** a member initializer on the screen, `var orders: RefCounted = Orders.new(self)`, so a screen built with `.new()` and never added to the tree (`test_view.gd:99-106`, V4) still has its orders; `Orders._init(screen)` only stores `_screen` (no `_screen._view` access before `_ready`); holds `selected_ids`, `selected_building_id`, `inspected_id`, the drag fields (`main.gd:21-28`), `_placement_kind`, `_pending_placement`, `_preview_origin`, `_preview_key`, `_attack_move_mode`, `menu`; owns `handle(event)`, the input helpers above, `_matching_ids`, `_selection_input` (without the B branch), `_move`, `_context_order`, `_container`, `_unload_selected`, `_set_rally`, `_produce_selected`, `_cancel_entry`, `_cancel_build`, `_builder`, `_enter_placement`, `_clear_placement`, `_update_preview`, `_update_drag`, `_finish_selection`, `_enemy_at`, `_order_defence`, `_menu_choose`, `_hint_point`, `view_selection()`, `busy()` (selecting or placing, for the camera), `escape_pending()`, `reset()` (restart lines `skirmish_main.gd:156-163`), `prune(state)` (`main.gd:242`, `base_main.gd:69`, `skirmish_main.gd:284`). It calls the screen directly: `_screen._submit`, `_screen._refresh`, `_screen.driver.sim`, `_screen._view`, `_screen._selection_box`, `_screen.change_zoom`, `_screen._perf.toggle`, `_screen.local_player`, `_screen._building` (`base_main.gd:62-65`, also used by the HUD, so it stays on the screen), `_screen._production_kind`, `_screen._playtest.holds_match()`, `_screen.get_viewport()` (`_matching_ids`, `main.gd:207`), and `_screen.hud.note` for local refusals ("Choose one builder", `base_main.gd:154`). `_ground` (`skirmish_main.gd:177-178`, used only by attack-move) moves into `orders.gd`. Any other screen member orders need goes through `_screen.` and is recorded in the verification file.

**HUD (Task 7):** `Hud.new(hud_layer: CanvasLayer, screen: Node)`, created in `_ready` before the first refresh (it needs `$HUD`), with a back-reference like Orders (`_screen.stepped_results`, `_screen.orders`, `_screen.driver`, `_screen._view`, `_screen.local_player`, `_screen._building`, `_screen._production_kind`, `_screen._ensure_sound`, `_screen._sound`); holds `note` (today's `_error`), `_last_result_tick`, `_last_result_sequence`; owns `_refresh_hud(state)` = the merged screen `_refresh_hud` above (`Restart` hidden when `not driver.can_restart()`), called by the screen's `_show` inside the `refresh.hud` zone. Helpers keep their names and signatures (`_refresh_hud(state)`, `_result_text(match_state)`, `_selected_summary(state)`, `_enemy_summary(state)`, `_refresh_menu(kinds)`), because tests call them directly (`test_skirmish_scene.gd:123`, `:130`, `:668`, `:672`; `test_base_scene.gd:342`, `:359`), so the Task 7 rename changes only receivers. It also owns the `Economy` offset (`base_main.gd:71`), `_refresh_menu` (writes `orders.menu` at the moment `base_main.gd:105` writes `_menu` today, so number keys read the last refresh's menu), `_refresh_queue`, `menu_label`, `queue_label` (static), `_menu_kinds`, `_selected_summary`, `_unit_record`, `_collection_suffix`, `_ordinal`, `_inspected`, `_enemy_summary`, `_result_text` (also used by the screen's playtest record; it reads `_screen.driver.sim.team_of(_screen.local_player)`), `reset()`. Buttons call `orders._menu_choose`, `orders._produce_selected`, `orders._cancel_entry`, `orders._cancel_build`. The profiler zones `refresh.selection` and `refresh.hud` (`main.gd:241-247`) keep their names and their place in `_show`.

## Accepted reorders (the only intended order changes; the reviewer checks each)

- **R1, online submit:** `_playtest.observe_command` moves from before `_refresh()` (`online_main.gd:81-82`) to after it, the offline order. `observe_command` (`playtest_overlay.gd:93-94`) only ticks focus-card triggers; `_refresh` reads `view_state` and writes view and labels. No shared state.
- **R2, online rejections:** the rejection sound and `_error` (`online_main.gd:60-65`) come after `_finish()` (`:66`, `:88-92`) instead of before. `_finish` writes the report and latency files and closes the transport; it reads neither.
- **R3, sound update:** `_sound.update(state)` (`skirmish_main.gd:281`) runs after the whole HUD refresh instead of between the economy and match parts. It reads `state` only; the HUD does not read the sound player.
- **R4, inspected prune:** `inspected_id` is cleared in `orders.prune(state)` at the start of `_show` instead of inside `_refresh_hud` (`skirmish_main.gd:284`). `view.set_view` and the economy HUD do not read it; `_view.set_inspected(...)` stays after the HUD refresh.
- **R5, online submit (found by the Task 11a review as m1; agent ruling at night, not a user decision: accept, no code change):** online, the shared `_submit` queues an `error` cue and skips the playtest checklist trigger (`observe_command`) for an order submitted while an own due-time rejection is still waiting for its deferred refresh; offline always behaved so (`skirmish_main.gd:91-95` on `main`). Cost if the ruling is wrong: online error-cue and checklist timing differs slightly from before the branch; presentation only, no simulation or trace effect.

## Frame-order and interaction cases

No new command and no AI rule in this package. The cases a controller change can break, with the test that holds each:

| Case | Expected (today's behaviour) | Test |
|---|---|---|
| Physics frame offline | bot decides on the pre-step tick, then one step | K2 (`test_skirmish_scene.gd:38`) |
| Player order offline | stamped with the current tick, player, next sequence; rejection does not consume a sequence | S2, S3 (ported), IC1 |
| Immediate refusal, then a due result in a later step | refusal persists; a newer own result replaces it; another player's result does not | Bs5, RF8 |
| Two ticks in one online frame | sound collected per tick; `stepped_results` holds the last tick's results through Task 8; from Task 10 every advanced tick's results | SD1, `test_catch_up_is_bounded`, `test_restart_drops_old_stepped_results`; N27 (Task 10) |
| Online stall frame | not a step frame; refresh only when the note changes | `test_stall_frames_are_not_step_frames`, `test_notices_reach_the_hud_while_processing` |
| Menu open | offline pauses the simulation, online does not | E-cases (`test_pause_menu.gd`) |
| Esc chain | drag, selection, placement, building, pending placement, attack-move, inspected enemy are cleared before the menu opens | E1, IC1 |
| Number key during a box drag | placement waits for the release | Bs2 deferred, IC1 |
| F3 during placement | swallowed through Task 8 (base placement branch returns, `base_main.gd:195-206`); from Task 9 toggles the overlay, placement stays (Decision 17) | IC1 (re-pinned in Task 9), PO19 (Task 9) |
| Match over or playtest dialog open | input ignored | `test_match_hud_and_restart`, `test_playtest_overlay.gd` |
| Offline restart | new simulation, sequence 0, every mode, note and result cursor cleared, camera reset | `test_match_hud_and_restart`, `test_restart_*` |
| Test swaps the simulation (`main.driver.sim =` from Task 4) | the recorder follows the new simulation | every swapped scene test; OD1 |
| Seat 2 local player | input, camera and HUD act for player 2 | `test_seat_two_controls_player_two` |

## Review focus

1. Dispatch order: the merged `_unhandled_input` equals the chain for every event class (key, motion, left, right, wheel) in every mode (none, dragging, attack-move, placement, building selected, match over).
2. Moves are verbatim apart from receivers; every reorder is R1-R5.
3. Test edits are access-path changes only, plus the ports of Task 2 and the deletions of Task 3; no assertion weakened, no expectation changed (V9-V11).
4. The bot never receives a driver; recorder and seat wrapper still expose `simulation()`.
5. Audit's second criterion, as a reading only (Decision 18): could the order controls package add an order by touching only `orders.gd` and the HUD hint line?
6. Decision 6 rename: every screen read goes through `driver.sim`, no test touches a screen's simulation before `setup` or `_ready`, the offline driver's `_recording` follows an assigned `driver.sim`, and the rename script's counts match the verification file.
7. Tasks 9 and 10 change only what they name: F3 during placement (and IC1's `perf=` column, nothing else in the re-pin), and the online HUD's view of earlier ticks' results in a multi-tick frame; offline frames hand the HUD exactly what they did before.

## Risks and model routing

Riskiest first: (1) the input dispatch merge (Task 5); guarded by IC1/IC2 and the ported S and Bs cases, all green on the old chain before any extraction (Tasks 1-2). (2) Test rewrites silently weakening checks; guarded by V10, V11 and the asserted rename script. (3) `_ready` and refresh order (Sound child, first refresh before the playtest overlay exists); guarded by SD22 (online and skirmish rows), the HUD layout tests and the pinned order. (4) Online-only paths a headless suite cannot reach (web download, real relay close); `test_online_scene.gd` covers the fakes, the browser is a morning item. (5) The bot memory trap (Determinism notes). (6) The Decision 6 rename touching 205 test reads and 54 production reads in one task (Task 4); guarded by the asserted counts, the pre-tree scan and `SCRIPT ERROR` failing the suite.

| Task | What | Model |
|---|---|---|
| 0 | Baseline: worktree, import, suite and traces, pins, member census, check-id census | Sonnet |
| 1 | Characterisation: IC1 offline and IC2 online input scripts with literal rows | Sonnet |
| 2 | Port the M2 and M3 scene checks onto the match scene (old chain) | Sonnet |
| 3 | Delete the demo scenes and their demo-only checks | Sonnet |
| 4 | Extract the driver (offline, online) | Sonnet |
| 5 | One screen: merge the chain into `match_screen.gd`, delete the four scripts | Sonnet |
| 6 | Extract orders | Sonnet |
| 7 | Extract the HUD | Sonnet |
| 8 | Docs and package gate (ledger row) | Sonnet |
| 9 | F3 toggles the perf overlay during placement (test-first; IC1 re-pin in its own commit) | Sonnet |
| 10 | Two-tick online frame hands every tick's command results to the HUD (characterise, then test-first fix or guard) | Sonnet |
| 11 | Fresh-context branch review (refactor and fixes), one fix round, `/ponytail-review` | **Opus (high)** review; Sonnet fix round |

Any unexpected red, trace difference or pin change goes to an Opus (high) diagnosis first (night run coordinator rules). Haiku is not used: every task has an anchor or order judgement. The run goes straight through Tasks 0-11 (Decision 20); the resume record allows a stop after any GREEN task, and the tree is consistent at each one (the done criterion holds from Task 5 on).

## Run scripts (in `$L`, never committed)

The prep wrote each script below to `$L` byte for byte from this text (2026-11-14); the run uses those files and only fills the `None` counts in the rules files. A missing file is written from its text here. Python 3.12 stdlib; none of them reads game data beyond the test and controller sources.

**`pretree.py`.** Pre-tree scan (Tasks 0, 4-7): no test touches a screen's `simulation`, `driver` or `hud` before `add_child` (`orders` is a member initializer, so it may). Prints `NO-TREE` for screens never added to the tree; exit 1 on any `PRE-TREE` line.

```python
# No test may touch a match screen's driver, simulation or hud before the screen is in the tree (orders is a member initializer).
import pathlib, re, sys

bad = 0
for path in sorted(pathlib.Path(sys.argv[1]).glob("*.gd")):
    lines = path.read_text().split("\n")
    for i, line in enumerate(lines):
        m = re.search(r'var (\w+)\s*(?::\s*\w+)?\s*=\s*(.*(?:instantiate\(\)|_main\.gd"\)\.new\(\)|main\.gd"\)\.new\(\)|match_screen\.gd"\)\.new\(\)|Main\.new\(\)|Screen\.new\(\)))', line)
        if not m:
            continue
        var = m.group(1)
        for j in range(i + 1, min(i + 40, len(lines))):
            if lines[j].startswith("func "):
                print(f"NO-TREE {path.name}:{i + 1} {var}")
                break
            if re.search(rf"add_child\({var}\b", lines[j]):
                break
            if re.search(rf"\b{var}\.(simulation|driver|hud)\b", lines[j]):
                print(f"PRE-TREE {path.name}:{j + 1}: {lines[j].strip()}")
                bad += 1
sys.exit(1 if bad else 0)
```

**`rename.py`.** Asserted rename engine (Tasks 4, 6, 7): `python3 $L/rename.py $W <t4|t6|t7> [--dry]`. Loads `rules_<task>.py` beside it; for each rule, every file in scope with a hit must have an expected count and match it, no old match may be left, `KEEP` counts must not change; writes only when everything passes, then writes `rename-<task>.done`.

```python
import importlib.util, pathlib, re, sys


def rules(task):
    path = pathlib.Path(__file__).resolve().with_name(f"rules_{task}.py")
    spec = importlib.util.spec_from_file_location(path.stem, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.RULES, getattr(module, "KEEP", [])


def scope_files(root, scope, want):
    if scope == "tests":
        return sorted(str(p.relative_to(root)) for p in (root / "game/tests").rglob("*.gd"))
    return sorted(want)


def main():
    root, task, dry = pathlib.Path(sys.argv[1]), sys.argv[2], "--dry" in sys.argv
    rule_list, keep = rules(task)
    texts, bad = {}, 0

    def text(path):
        if path not in texts:
            texts[path] = (root / path).read_text()
        return texts[path]

    for pattern, repl, scope, want in rule_list:
        for path in scope_files(root, scope, want):
            got = len(re.findall(pattern, text(path)))
            if got or path in want:
                ok = got == want.get(path)
                print(f"{'ok ' if ok else 'BAD'} {path} {pattern} found={got} expected={want.get(path)}")
                bad += not ok
            texts[path] = re.sub(pattern, repl, text(path))
            left = len(re.findall(pattern, texts[path]))
            if left:
                print(f"LEFT {path} {pattern} {left}")
                bad += 1
    for path, pattern, expected in keep:
        got = len(re.findall(pattern, text(path)))
        print(f"{'ok ' if got == expected else 'BAD'} KEEP {path} {pattern} found={got} expected={expected}")
        bad += got != expected
    if bad:
        print(f"RENAME FAILED {task} {bad}")
        sys.exit(1)
    changed = [p for p in texts if texts[p] != (root / p).read_text()]
    if not dry:
        for p in changed:
            (root / p).write_text(texts[p])
        pathlib.Path(__file__).resolve().with_name(f"rename-{task}.done").write_text(f"{len(changed)} files\n")
    print(f"RENAME OK {task} files={len(changed)}" + (" (dry)" if dry else ""))


if __name__ == "__main__":
    main()
```

**`rules_t4.py`.** Task 4 rules (Decision 6 and the driver members). The run fills each `None` from the Task 4 Step 3 recount.

```python
# Task 4 (Decision 6). Fill every None with the rg recount of Task 4 Step 3 before the first run.
SCREEN = r"\b(main|skirmish|other)\.simulation\b"
PROD = r"(?<![\w/.])simulation\b(?!/|\.gd)"
RULES = [  # (pattern, replacement, scope, {path: expected count}); scope "tests" scans every game/tests file
    (SCREEN, r"\1.driver.sim", "tests", {
        "game/tests/test_base_scene.gd": None,  # 35d22b5: 67
        "game/tests/test_skirmish_scene.gd": None,  # 49
        "game/tests/test_scene.gd": None,  # 27
        "game/tests/test_online_scene.gd": None,  # 21
        "game/tests/test_playtest_overlay.gd": None,  # 17
        "game/tests/test_order_voice.gd": None,  # 9
        "game/tests/test_pause_menu.gd": None,  # 6
        "game/tests/test_playtest_replay.gd": None,  # 3
        "game/tests/test_sound.gd": None,  # 3
        "game/tests/test_announcer.gd": None,  # 2
        "game/tests/test_perf_overlay.gd": None,  # 1
    }),
    (r"\b(main|skirmish|other)\.(_sequence|_own_faction|web|download)\b", r"\1.driver.\2", "tests", {
        "game/tests/test_skirmish_scene.gd": 2, "game/tests/test_online_scene.gd": 4}),
    (r"\b(main|skirmish|other)\.(notice|latency_line)\(", r"\1.driver.\2(", "tests", {"game/tests/test_online_scene.gd": 4}),
    (PROD, "driver.sim", "paths", {
        "game/scripts/main.gd": 18, "game/scripts/base_main.gd": 10,
        "game/scripts/skirmish_main.gd": 19, "game/scripts/online_main.gd": 7}),
]
KEEP = [  # (path, pattern, count) that must not change
    ("game/tests/test_art_lab.gd", r"\bfight\.simulation\b", 6),
    ("game/tests/test_playtest_replay.gd", r"\brecorder\.simulation\(", 1),
    ("game/scripts/skirmish_main.gd", r"\brecorder\.simulation\(", 1),
    ("game/tests/test_playtest_overlay.gd", r"\boverlay\.(web|download)\b", 3),
]
```

**`rules_t6.py`.** Task 6 rules (orders members).

```python
# Task 6. Fill every None with the rg recount of Task 6 Step 3; add a row for any other test file the recount shows.
ORDERS = r"\b(main|skirmish|other)\.(selected_ids|selected_building_id|inspected_id|_placement_kind|_pending_placement|_attack_move_mode|_selecting|_dragged|_enter_placement|_clear_placement|_produce_selected|_move)\b"
RULES = [
    (ORDERS, r"\1.orders.\2", "tests", {
        "game/tests/test_base_scene.gd": None,  # 35d22b5: 28
        "game/tests/test_online_scene.gd": None,  # 4
        "game/tests/test_pause_menu.gd": None,  # 9
        "game/tests/test_playtest_overlay.gd": None,  # 9
        "game/tests/test_playtest_replay.gd": None,  # 1
        "game/tests/test_scene.gd": None,  # 18
        "game/tests/test_skirmish_scene.gd": None,  # 83
        "game/tests/test_view.gd": None,  # 2
    }),
    (r"\b(main|skirmish|other)\.is_selecting\(", r"\1.orders.is_selecting(", "tests", {"game/tests/test_base_scene.gd": None}),  # 3
    (r"\b(main|skirmish|other)\._view_selection\(", r"\1.orders.view_selection(", "tests", {"game/tests/test_view.gd": None}),  # 2
]
```

**`rules_t7.py`.** Task 7 rules (HUD members).

```python
# Task 7. Fill every None with the rg recount of Task 7 Step 3; add a row for any other test file the recount shows.
RULES = [
    (r"\b(main|skirmish|other)\._error\b", r"\1.hud.note", "tests", {
        "game/tests/test_announcer.gd": None,  # 35d22b5: 2
        "game/tests/test_base_scene.gd": None,  # 6
        "game/tests/test_order_voice.gd": None,  # 4
        "game/tests/test_playtest_overlay.gd": None,  # 10
        "game/tests/test_skirmish_scene.gd": None,  # 18
    }),
    (r"\b(main|skirmish|other)\.(_refresh_menu|_refresh_hud|_selected_summary|_enemy_summary|_result_text|_last_result_tick|_last_result_sequence)\b", r"\1.hud.\2", "tests", {
        "game/tests/test_base_scene.gd": None,  # 2
        "game/tests/test_skirmish_scene.gd": None,  # 9
    }),
]
```

**`v13_check.py`.** V13 (Tasks 1-11): silent test changes. `--add` records a task's hand edits with a reason; the check mode compares against `main`.

```python
# V13: every test line removed against `main` is either a rename (rules_t4/t6/t7) or listed in the reasons file.
# check: python3 v13_check.py <worktree> <reasons file>
# add:   python3 v13_check.py <worktree> <reasons file> --add "<reason>" <path>...  (lists this task's uncommitted non-rename removals)
import pathlib, re, subprocess, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import rename  # noqa: E402


def stages():
    found = []
    for task in ("t4", "t6", "t7"):
        if pathlib.Path(rename.__file__).resolve().with_name(f"rename-{task}.done").exists():  # only renames already applied
            found.append([(pattern, repl) for pattern, repl, scope, _ in rename.rules(task)[0] if scope == "tests"])
    return found


def forms(line, stage_rules):
    seen = [line]
    for rule_set in stage_rules:
        for pattern, repl in rule_set:
            line = re.sub(pattern, repl, line)
        seen.append(line)
    return seen


def diff_lines(root, rev, paths):
    out = subprocess.run(["git", "-C", str(root), "diff", "-U0", rev, "--", *paths], capture_output=True, text=True, check=True).stdout
    minus, plus, path, in_hunk = {}, {}, None, False
    for line in out.split("\n"):
        if line.startswith("diff --git "):
            path, in_hunk = line.split(" b/", 1)[1], False
        elif line.startswith("@@"):
            in_hunk = True
        elif in_hunk and line.startswith("-"):
            minus.setdefault(path, []).append(line[1:])
        elif in_hunk and line.startswith("+"):
            plus.setdefault(path, []).append(line[1:])
    return minus, plus


def unmatched(minus, plus, stage_rules):
    for path, lines in minus.items():
        pool = list(plus.get(path, []))
        for line in lines:
            final = forms(line, stage_rules)[-1]
            if final in pool:
                pool.remove(final)
            else:
                yield path, line


def main():
    root, reasons = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    stage_rules = stages()
    if "--add" in sys.argv:
        i = sys.argv.index("--add")
        reason, paths = sys.argv[i + 1], sys.argv[i + 2:]
        minus, plus = diff_lines(root, "HEAD", paths)
        rows = [f"{path}\t{reason}\t{line}" for path, line in unmatched(minus, plus, stage_rules)]
        with reasons.open("a") as out:
            out.writelines(row + "\n" for row in rows)
        print(f"V13 ADDED {len(rows)} {reason}")
        return
    listed = {}
    if reasons.exists():
        for row in reasons.read_text().split("\n"):
            if row:
                path, _, line = row.split("\t", 2)
                listed.setdefault(path, set()).add(line)
    minus, plus = diff_lines(root, "main", ["game/tests"])
    total = sum(len(lines) for lines in minus.values())
    explained, bad = 0, 0
    for path, line in unmatched(minus, plus, stage_rules):
        if any(form in listed.get(path, set()) for form in forms(line, stage_rules)):
            explained += 1
        else:
            print(f"UNEXPLAINED {path}: {line}")
            bad += 1
    if bad:
        print(f"V13 FAILED {bad}")
        sys.exit(1)
    print(f"V13 OK removed={total} renamed={total - explained} listed={explained}")


if __name__ == "__main__":
    main()
```

**`t9_repin_check.py`.** Task 9 re-pin check.

```python
# Task 9: the uncommitted re-pin of input_script_rows.gd may only turn perf=false into perf=true, on step 10 and later rows.
import re, subprocess, sys

out = subprocess.run(["git", "-C", sys.argv[1], "diff", "-U0", "HEAD", "--", "game/tests/input_script_rows.gd"], capture_output=True, text=True, check=True).stdout
minus = [line[1:] for line in out.split("\n") if line.startswith("-") and not line.startswith("---")]
plus = [line[1:] for line in out.split("\n") if line.startswith("+") and not line.startswith("+++")]
bad = not minus or len(minus) != len(plus)
for old, new in zip(minus, plus):
    step = re.search(r'"(\d+)\|', old)
    if old.count("perf=false") != 1 or old.replace("perf=false", "perf=true") != new or step is None or int(step.group(1)) < 10:
        print(f"BAD\n-{old}\n+{new}")
        bad = True
print(f"REPIN {'FAILED' if bad else 'OK'} rows={len(minus)}")
sys.exit(1 if bad else 0)
```

---

### Task 0: Baseline

```text
Task: record the untouched tree's suite, traces, pins and the two censuses the later tasks assert against.
Owns: the verification file only.
Invariant: no repository file changes.
Boundary: the import must not be inside a timed run.
Red: n/a (measurement).
Green: suite exit 0 with TESTS PASSED; four trace files; census files in $L.
Stop: suite red on the untouched tree; a pin missing from its file; online_main.gd _report is not desync_report(simulation); the pre-tree scan prints a PRE-TREE line.
```

- [ ] **Step 1:** `mkdir -p $L`; `cd <absolute path of ~/projects/wargrid> && git worktree add $W -b one-controller main` (`main` must be `35d22b5` or a later commit that leaves `game/scripts/` unchanged: `git diff --stat 35d22b5 main -- game/scripts game/tests` empty, else record and re-anchor by symbol). The prep commits this plan and the verification file to `main` before the run, so the worktree has both: `cd $W && git ls-files docs/superpowers/plans/2026-11-14-one-controller.md docs/reference/one-controller-verification.md` must print both paths; a missing one is a stop (the resume record would disagree with the tree). Then `cd $W && git status --short` (empty), `cd $W && git log --oneline -1` (recorded), `ls $L` shows the Run scripts (a missing one is written from its text below), `pgrep -fl 'godot|generalszh'` (list, kill nothing), `uptime`.
- [ ] **Step 2 (import):** `cd $W && godot --headless --path game --import > $L/t0-import.log 2>&1; echo "exit=$?"`.
- [ ] **Step 3 (suite with traces):** `cd $W && WARGRID_REPLAY_TRACE=$L/replay-before.tsv WARGRID_ECONOMY_REPLAY_TRACE=$L/economy-before.tsv WARGRID_COMBAT_REPLAY_TRACE=$L/combat-before.tsv WARGRID_TEAM_REPLAY_TRACE=$L/team-before.tsv sh tools/run_tests.sh > $L/t0-suite.log 2>&1; echo "exit=$?"` (Bash `timeout: 600000`). Record CASES, CHECKS, wall seconds; `rg -n 'TESTS PASSED' $L/t0-suite.log`.
- [ ] **Step 4 (pins):** `cd $W && rg -n 'FINAL_DIGEST|TEAM_CORE_SERIES|S1_CORE_SERIES|PINNED|EXPECTED_DIGEST' game/tests`, `cd $W && rg -n '9129' tools/run_netplay.sh`, `cd $W && rg -n 'won tick' tools/run_team_match.sh`; record against the table. `cd $W && rg -n 'desync_report\(' game/scripts`: on `35d22b5` `online_main.gd:109` reads `_lockstep.desync_report(simulation)`; the online driver keeps it as `desync_report(sim)`. `cd $W && rg -n 'BUDGET EXCEEDED' docs/reference/performance.md | tail -3` and the last `docs/reference/perf-history.csv` rows: record the accepted line.
- [ ] **Step 5 (anchors):** re-check by symbol every anchor in "Pinned shapes" (`cd $W && rg -n 'func <name>' game/scripts/main.gd game/scripts/base_main.gd game/scripts/skirmish_main.gd game/scripts/online_main.gd`); record drift (none expected against `35d22b5`).
- [ ] **Step 6 (censuses):** (a) check ids: `cd $W && rg -o --no-filename '"[A-Z][A-Za-z]?[0-9]+[a-z]? ' game/tests | sort -u > $L/ids-before.txt`; confirm `IC1`, `IC2`, `OD1`, `OD2`, `OR1`, `HU1`, `PO19`, `N27` are absent (`rg -n '^"(IC1|IC2|OD1|OD2|OR1|HU1|PO19|N27) $' $L/ids-before.txt` prints nothing). (b) member census: for each member in the rename tables of Tasks 4, 6 and 7, `cd $W && rg -o '\b\w+(\.\w+)?\.<member>\b' game/tests | sort | uniq -c` (receiver and file per hit) into `$L/census-before.txt`; non-controller receivers (launcher, overlay, view, `fight` in `test_art_lab.gd`, `recorder.simulation()`) are marked "not renamed". (c) simulation census (Decision 6): `cd $W && rg -o '\b(main|skirmish|other|fight|recorder)\.simulation\b' game/tests | sort | uniq -c > $L/sim-census-before.txt` and `cd $W && rg -o '\bmain\.simulation\s*=[^=]' game/tests | wc -l`; expected on `35d22b5` in the verification file's census table (194 `main.`, 7 `skirmish.`, 4 `other.`, 6 `fight.`, 1 `recorder.` = 212; 24 assignments). (d) pre-tree scan (Run scripts): `python3 $L/pretree.py $W/game/tests > $L/t0-pretree.log 2>&1; echo "exit=$?"`; expected: exit 0, no `PRE-TREE` line, and `NO-TREE` only for `test_online_scene.gd:317` (N5, reads the script path), `test_skirmish.gd:700` (SK23) and `test_view.gd:99` (V4), none of which reads a simulation. (e) label census (V11b): `cd $W && rg -o --no-filename '"[A-Z][A-Za-z]?[0-9]+[a-z]? [^"%]*' game/tests | sort > $L/labels-before.txt` (3070 lines on `35d22b5`). Record the counts in the verification file; Tasks 4, 6, 7 assert against them.
- [ ] **Step 7:** fill the Baseline section; Task 0 GREEN. No benchmark here: Task 8 compares with `main`'s last ledger row (the controller is not in any timed benchmark: `movement_benchmark.tscn` uses `debug/movement_benchmark.gd`).

---

### Task 1: Characterisation input scripts (IC1, IC2)

```text
Task: two new cases drive a fixed script of input events through today's chain and compare every resulting command and mode row with literal rows.
Owns: game/tests/input_script_rows.gd (new, consts only), game/tests/test_skirmish_scene.gd (IC1 case and its _ic_row helper), game/tests/test_online_scene.gd (IC2 case), game/tests/run_tests.gd (CASE_SECONDS entry only if a case runs over 1 s).
Invariant: no file under game/scripts changes; V1-V9.
Boundary: rows capture stamping (tick, player, sequence), payload fields, and the dispatch result in every mode.
Red: scratch mutations (a) and (b) below each make IC1 fail; (b) also makes IC2 fail.
Green: WARGRID_TEST_ONLY=test_skirmish_scene and =test_online_scene; full suite.
Stop: a row differs between two runs on the same tree (non-deterministic input path: Opus diagnosis).
```

- [ ] **Step 1 (IC1, `test_skirmish_scene.gd`, add to `cases()`):** `test_input_script_offline`. World: `Skirmish.create(false)` plus the objects the steps need, built like `_arena` (`:29-36`), `_pile_world` (`:217`), `test_enter_unload_scene` (`:485`) and `test_defence_attack_scene` (`:465`): own builder, two own tanks, own infantry, own completed barracks, own unfinished site, own loaded container, enemy tank, supply pile. `main.simulation = sim`, `main._refresh()` (Task 4's rename turns `main.simulation` into `main.driver.sim` here and in `_ic_row`). Steps, one row after each (helper `_ic_row(main)` is the only place that names controller members, so Tasks 6-7 rename there only):
  1. box-drag over both tanks; 2. right-click ground; 3. `A`, left press and release on ground; 4. `S`; 5. right-click the enemy tank; 6. start a box drag, press `S` mid-drag, release; 7. `Esc`; 8. `Esc` (menu opens), `Esc` (closes); 9. click the builder, key `1`; 10. `F3` during placement; 11. left release on a free cell; 12. click the barracks, `E`; 13. right-click ground (rally); 14. click the builder, right-click the unfinished site; 15. click the container, `U`; 16. select the infantry, right-click the container; 17. start a box drag, key `1` mid-drag, release; 18. `Esc`, `Esc`; 19. click the enemy tank with nothing selected; 20. right-click the pile with the builder selected; 21. one `main._physics_process(0.0)`.
  Esc (steps 7, 8, 18) goes the way the engine sends it: a helper `_esc_both(main)` builds the event like `_esc` in `test_pause_menu.gd:43-48`, reads `var pass_on: bool = not main._pause.visible and main._escape_pending()` (exactly when `main.gd:95-103` leaves the event unhandled), calls `main._input(event)`, then `main._unhandled_input(event)` if `pass_on`. Other keys and clicks go straight to `main._unhandled_input` through the `BaseScene` helpers.
  Row: `"%d|sel=%s|bld=%d|insp=%d|place=%s|pend=%s|am=%s|esc=%s|menu=%s|perf=%s|%s"` of step, `selected_ids`, `selected_building_id`, `inspected_id`, `_placement_kind`, `_pending_placement`, `_attack_move_mode`, `_escape_pending()`, `menu_open()`, the perf overlay's `visible`, and the commands added to `simulation.snapshot().pending_commands` since the last row, each `JSON.stringify(command)` (sorted keys), joined by `;`. Steps 3, 9, 12 and 19 also append the full `HUD/Status` text.
- [ ] **Step 2 (IC2, `test_online_scene.gd`):** `test_input_script_online` on `_online(runner, 1)` (`:39-49`). The online start world is in faction setup until the tick-4 `choose_faction` (`Skirmish.create(true, "human", {}, …)` defers the seats; `setup_seat` then spawns one start unit and the start building), so before step 1 send `_peer_packets(online.transport, 2, 1, 8)` (`:51-54`) and `_run(online.main, 8)` (`:56-57`) until `main.simulation.snapshot().entities` holds the own start unit; otherwise the build menu is empty and steps 9-11 do nothing. There are no tanks: IC2's "both tanks" means the own start units. Run the IC1 steps whose objects this world has (at least 1, 2, 4, 6, 9, 11 and 17; the task records which ran), with `_peer_packets` and `_run` (`:51-58`) after each step so the frames go out; commands from `_own_commands(transport)` (`:64-68`), same row format.
- [ ] **Step 3 (capture):** before pinning, each case checks that every step did what it is for, as its own `runner.check` (label `"IC1 step %d took effect"`, `IC2` likewise): 1 `sel` holds the units; 2 one `move`; 3 one `attack_move`; 4 one `stop`; 5 one `attack`; 9 `place=` non-empty; 11 one `build`; 12 one `produce`; 13 one `set_rally`; 14 one `resume_build`; 15 one `unload`; 16 one `enter`; 19 `insp=` the enemy id; 20 one `gather`. A step without its effect (a missed click, a wrong cell) is BLOCKED, never pinned. Then run each case once with a scratch print of its rows; paste them as `const IC1_ROWS: PackedStringArray` and `const IC2_ROWS` into `game/tests/input_script_rows.gd` (`extends RefCounted`), **one row per line** (the Task 9 re-pin check pairs lines); remove the print. The check names the first differing index: `"IC1 row %d matches the chain recorded 2026-11-xx, got %s"`. Run twice; identical.
- [ ] **Step 4 (red by mutation, scratch, revert each):** (a) `main.gd:290` (`_submit`): default the tick to `state.tick + 1` → IC1 fails at step 2 (stamping). (b) `skirmish_main.gd:200` (`_unhandled_input`): drop `and not is_selecting()` → IC1 and IC2 fail at step 6. Each run: `cd $W && WARGRID_TEST_ONLY=test_input_script sh tools/run_tests.sh > $L/t1-mut-a.log 2>&1; echo "exit=$?"` (`t1-mut-b.log` for (b)); expected exit 1 and the `IC1 row` failure at the named step. `cd $W && git diff --stat` after the reverts shows only Steps 1-3.
- [ ] **Step 5:** `cd $W && sh tools/run_tests.sh > $L/t1-suite.log 2>&1; echo "exit=$?"` green; `cd $W && sh tools/run_checks.sh > $L/t1-checks.log 2>&1; echo "exit=$?"` (`CHECKS PASSED 5`); append `IC1`, `IC2` to the check-id census. `cd $W && python3 $L/v13_check.py $W $L/v13-reasons.txt --add "Task 1: IC1, IC2 in cases()" game/tests/test_skirmish_scene.gd game/tests/test_online_scene.gd` (only the `cases()` lines should appear). Record whether IC2 ran step 10 (F3): Task 9 re-pins IC2 too if it did.

---

### Task 2: Port the M2 and M3 scene checks onto the match scene

```text
Task: test_scene.gd and test_base_scene.gd run their checks on skirmish.tscn with the demo worlds rebuilt as fixtures, on today's chain.
Owns: game/tests/test_scene.gd, game/tests/test_base_scene.gd, game/tests/test_pause_menu.gd (the Base preload :4 and the Base half of E1, :90), game/tests/test_perf_overlay.gd (:4, :39, :50, :66, :84).
Invariant: every check label and expected value unchanged, except the demo-only checks listed for Task 3 and the three amendments below; no file under game/scripts changes except the null guard below; V1-V10.
Amendments (user, 2026-11-14, after the Task 2 park): (1) skirmish_main.gd:282 reads `var result: String = "" if state.match == null else _result_text(state.match)`: the ported fixtures have no match record (production always has one); carried verbatim by Tasks 5 and 7. (2) S2/S3 right-clicks move off friendly units (on the match screen a right-click on an own Scout Car is an `enter` context order, base_main.gd:212-214): S2 (4.5, 3.5) -> (4.5, 5.5) with its expected target, S2 non-centre (4.25, 3.1) -> (4.25, 6.1), S3 (4.5, 3.5) -> (4.5, 5.5) and (5.5, 3.5) -> (5.5, 5.5); every assertion kept. (3) RF6 takes one warm-up tick before counting: the skirmish bot's decision snapshot on tick 0 (skirmish.gd:68-70) is not a controller snapshot; the ten counted ticks (1-10) hold no decision tick.
Boundary: the skirmish HUD needs a local player record (base_main.gd:57-60 reads state.players[0]); the bot runs on the swapped world each physics frame.
Red: scratch mutation main.gd:191 (`and not _ctrl` dropped) makes the ported G26 Ctrl case fail on skirmish.tscn; base_main.gd:220 deleted alone (`selected_ids.clear()`, so a building selection keeps the units; :219 stays) makes the ported Bs3 case fail.
Green: the four files' suites; full suite.
Stop: a ported check other than the Task 3 list fails on today's chain (report the label and value; never edit the expectation).
```

- [ ] **Step 1 (`test_scene.gd`):** `const Main = preload("res://scenes/skirmish.tscn")` (`:4`); `setup` (`:10`) and `test_driver` (`:151`) install `_m2_world()` (today's `main.gd:250-258` body plus `add_player(1, 0)`), then `main._reset_camera()` and `main._refresh()`. If the bot errors on a world without player 2, add `add_player(2, 0)` and record it.
- [ ] **Step 2 (`test_base_scene.gd`):** `const Base = preload("res://scenes/skirmish.tscn")`; `setup` (`:13`) installs `_m3_world()` (`Fixture.make_world()` plus `add_supply_source(Vector2i(24, 4), 200)`, today's `base_main.gd:32-37`), `_reset_camera()`, `_refresh()`. The helpers `key`, `pointer`, `hover` (`:21-38`) stay; `test_skirmish_scene.gd` uses them (`BaseScene.new()`, 22 places).
- [ ] **Step 3:** `test_pause_menu.gd` (`const Base` `:4`, E1 Base half `:90`) and `test_perf_overlay.gd` use `skirmish.tscn` with `_m3_world()` from the base helper where the case reads the builder. Fixture installs keep the old access path (`main.simulation = …`); Task 4 renames them with the rest.
- [ ] **Step 4:** full suite (`t2`); list every failing check (`rg -n 'FAIL' $L/t2-suite.log`). Expected failures only: S8 (three FAIL labels: "S8 B adds authored obstacle", "S8 occupied toggle rejection reason", "S8 rejected toggle preserves next action"; B obstacle toggle, `main.gd:217-226` is unreachable in the match scene) and S9 ("S9 status counts from the rows match the snapshot ..."; M2 status counts, `main.gd:260-267`), after the Invariant's amendments 1-3. Anything else is the stop above.
- [ ] **Step 5 (red by mutation):** as in the contract, each with a filtered run (`WARGRID_TEST_ONLY=test_scene` for G26, `=test_base_scene` for Bs3) into `$L/t2-mut-g26.log` and `$L/t2-mut-bs3.log`, expected exit 1 with the ported label; revert each, `cd $W && git diff --stat game/scripts` empty.
- [ ] **Step 6:** S8 (`test_obstacle_toggle`) and S9 (`test_status_counts`) go back to the demo until Task 3: `setup(runner, packed = Main)` takes the scene, a `const Demo = preload("res://scenes/main.tscn")` line is added, and only those two cases call `setup(runner, Demo)`; mark them `pending demo removal` in the verification file. Full suite (`t2`) green, static gates. `cd $W && python3 $L/v13_check.py $W $L/v13-reasons.txt --add "Task 2: port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14)" game/tests/test_scene.gd game/tests/test_base_scene.gd game/tests/test_pause_menu.gd game/tests/test_perf_overlay.gd`; read each added row (a changed assertion or expected value is the stop, except the amendment 2 rows: five `test_scene.gd` lines, three clicks, the S2 `distance_to(Vector2(4.5, 3.5))` expected target and the S2 `var target` line) and copy them into the verification file.

---

### Task 3: Delete the demo scenes and demo-only checks

```text
Task: main.tscn and base.tscn go, with the checks that only the demos can satisfy.
Owns: game/scenes/main.tscn, game/scenes/base.tscn (delete), game/tests/test_scene.gd (S8 and S9 cases), game/tests/test_sound.gd (:331 loop).
Invariant: V1-V10; V11 = Task 0 set minus exactly the list below plus IC1, IC2.
Boundary: main.gd and base_main.gd stay until Task 5 (they are still the chain's ancestors).
Red: n/a (deletion; V11 is the check).
Green: full suite; V11.
Stop: anything outside the list needs deleting.
```

- [ ] **Step 1:** delete the two scenes (`cd $W && git rm game/scenes/main.tscn game/scenes/base.tscn`). `test_scene.gd`: remove `test_obstacle_toggle` (`:257` on `35d22b5`, S8), `test_status_counts` (`:283`, S9), their `cases()` entries and the Task 2 `const Demo` line. `test_sound.gd:331-337`: drop the demo-scene loop (SD22 keeps its skirmish and online rows). Demo-only list (verification file): S8 (eight labels), S9 (two labels), the SD22 demo row.
- [ ] **Step 2:** `cd $W && rg -n 'scenes/(main|base)\.tscn' game tools` prints nothing. Full suite (`t3`). V11b: `cd $W && rg -o --no-filename '"[A-Z][A-Za-z]?[0-9]+[a-z]? [^"%]*' game/tests | sort > $L/labels-t3.txt`; `diff $L/labels-before.txt $L/labels-t3.txt` shows exactly the 11 demo labels removed (8 S8, 2 S9, 1 `"SD22 `) and the Task 1 `IC1`/`IC2` labels added, nothing else (the id census alone cannot show it: `S8`, `S9` also label `test_combat.gd` checks and SD22 keeps two rows). `cd $W && python3 $L/v13_check.py $W $L/v13-reasons.txt --add "Task 3: demo-only check deleted" game/tests/test_scene.gd game/tests/test_sound.gd`; copy the rows into the verification file.
---

### Task 4: Extract the driver

```text
Task: offline and online drivers own the simulation and how commands reach it; the chain calls them; the screen's simulation property goes and every reader uses driver.sim (Decision 6).
Owns: game/scripts/match/offline_driver.gd, game/scripts/match/online_driver.gd (new), game/scripts/main.gd, base_main.gd, skirmish_main.gd, online_main.gd (the members in "Pinned shapes: Driver", every simulation read), the access paths in the eleven test files of the rename table (verification file), game/tests/test_skirmish.gd (SK23 construction, :693-708, and const OnlineMain :17).
Invariant: V1-V12; the bot gets the recorder; payload stamping byte for byte; test_art_lab.gd and every recorder.simulation() call unchanged.
Boundary: tests that assign main.driver.sim (the recorder follows); no test touches main.driver before setup or _ready (pre-tree scan); online report keeps desync_report(sim); SK23 builds a driver without a scene.
Red: OD1 and OD2 below fail before the drivers exist (written against stub files whose methods push_error and return defaults).
Green: OD1, OD2, IC1, IC2, test_online_scene, test_skirmish (SK23), test_playtest_overlay, test_pause_menu; pre-tree scan exit 0; full suite with traces; traces cmp; netplay match (V6); static gates; V12.
Stop: IC1 or IC2 differs; a pin moves; a rename count differs from its expected number (stop before writing anything: Opus diagnosis of the census, never an adjusted number).
```

- [ ] **Step 1 (tests, `test_skirmish_scene.gd`):** **OD1 `test_offline_driver_stamps_like_the_scene`:** an `OfflineDriver` on `_arena`'s world for player 1 (`driver.sim = sim`): three `submit` calls (an accepted `stop`, a rejected `attack` on a missing id, an accepted `stop`) give sequences 0, none, 1 and `tick` equal to the snapshot tick, and the two accepted commands reach `driver.sim.snapshot().pending_commands` through the recorder (`"OD1 offline driver stamps tick, player and sequence like main._submit"`). **OD2 `test_offline_driver_bot_memory_on_simulation`:** after `step` at a decision tick, `driver.sim.has_meta(&"skirmish_bot")` and the driver has no meta (`"OD2 bot memory lives on the simulation, not the driver"`). Stubs first; filtered run (`WARGRID_TEST_ONLY=test_offline_driver`) exits 1 and names both checks.
- [ ] **Step 2 (drivers):** write `offline_driver.gd` and `online_driver.gd` from the table: bodies copied verbatim from the chain with `sim` for `simulation`; the offline driver takes `recorder`, `_recording()`, `_issue`, `_sequence` and `_last_issue_ok`'s role (`submit` returns the result); the online driver takes the `online_main.gd` fields `:9-17` and `:113-143`. Only new files in this step.
- [ ] **Step 3 (recount, on this tree):** the rename runs here, after Tasks 2-3 edited `test_scene.gd`, `test_base_scene.gd`, `test_pause_menu.gd`, `test_perf_overlay.gd` and `test_sound.gd`, so its expected counts come from an `rg` recount on this tree; a count may differ from Task 0 only in a file this run edited (Tasks 1-3 add IC1, ports and deletions):
  - tests: `cd $W && rg -o '\b(main|skirmish|other|fight|recorder)\.simulation\b' game/tests | sort | uniq -c > $L/sim-census-t4.txt`. These `rg` counts (an engine independent of the Python `re` in `rename.py`) are the expected numbers. Every file whose count differs from Task 0 must be one this run edited (`cd $W && git diff --stat main -- game/tests`); a differing count in any other file is the stop. Record per file: Task 0, now, edited by which task.
  - driver members: `cd $W && rg -o '\b\w+\.(_sequence|_own_faction|web|download|_lockstep|_report)\b|\b\w+\.(notice|latency_line)\(' game/tests | sort | uniq -c`; expected as on `35d22b5` (Tasks 1-3 do not touch these lines): `test_online_scene.gd` `main._own_faction` 2, `main.notice(` 2, `main.latency_line(` 2, `main.web` 1, `main.download` 1; `test_skirmish_scene.gd` `main._sequence` 2; `test_skirmish.gd` `main._lockstep` 1, `main._report` 1 (SK23, rewritten by hand in Step 6); `overlay.web` 2 and `overlay.download` 1 in `test_playtest_overlay.gd` are the overlay's own and stay.
  - production: `cd $W && rg -oP '(?<![\w/.])simulation\b(?!/|\.gd)' game/scripts/main.gd game/scripts/base_main.gd game/scripts/skirmish_main.gd game/scripts/online_main.gd | sort | uniq -c`; expected (unchanged since `35d22b5`): `main.gd` 19, `base_main.gd` 10, `skirmish_main.gd` 19, `online_main.gd` 7 (55). The pattern skips `res://scripts/simulation/…` paths, `_create_simulation`, `_step_simulation` and `recorder.simulation()`; it includes the `skirmish_main.gd:59` comment, which then reads "Tests swap `driver.sim` directly".
- [ ] **Step 4 (rename, asserted):** replace `main.gd:13` `var simulation: Simulation = Simulation.new()` by `var driver: RefCounted` with the Edit tool (so `main.gd` expects 18). Fill every `None` in `$L/rules_t4.py` (Run scripts) with the Step 3 numbers; add a row for any other test file Step 3 showed. Then `python3 $L/rename.py $W t4 --dry > $L/t4-rename-dry.log 2>&1; echo "exit=$?"` (writes nothing) and `python3 $L/rename.py $W t4 > $L/t4-rename.log 2>&1; echo "exit=$?"`. Exit 0 and `RENAME OK t4` mean every count matched before, no old match is left in any test file or chain script, and the `KEEP` patterns are unchanged; the run also writes `$L/rename-t4.done`, which tells `v13_check.py` that the Task 4 rules now apply. Paste the log's count lines into the verification file.
- [ ] **Step 5 (wire the chain to the driver):** each level keeps parsing on its own (the match statics, `_sound`, `_playtest`, `_ensure_sound` and `_collect_sound` exist only from `skirmish_main.gd` down):
  - `main.gd`: `const OfflineDriver = preload("res://scripts/match/offline_driver.gd")`; first line of `_ready`: `if driver == null: driver = OfflineDriver.new(local_player)` (the pause menu reads `driver.confirm_leave()` at `:45`); `:59` becomes `_create_world()`, with `func _create_world() -> void: pass` in `main.gd`; `_confirm_leave` returns `driver.confirm_leave()`, `_pauses_sim` returns `driver.pauses_sim()`; `_submit` and `_step_simulation` keep only the driver half ("Pinned shapes": `_show_hint`, `driver.submit`, `_error = result.error`, `_refresh()`; `driver.step(func() -> void: pass)`). Delete `main.gd:250-258` (`_create_simulation`, demo-only since Task 3; its world lives on as the Task 2 fixture), `_issue` (`:283-284`), `_sequence`, `_last_issue_ok`.
  - `base_main.gd`: delete `_create_simulation` (`:32-37`, demo-only, now the `_m3_world()` fixture).
  - `skirmish_main.gd`: `_create_simulation` (`:56-57`) becomes `func _create_world() -> void: driver.create(map_path, starts, factions, match_seed)`; `_restart` (`:151`) calls `_create_world()`; `_submit` (`:91-95`) and `_step_simulation` (`:81-84`) become the pinned full forms; `playtest_context` reads `driver.over()`, `playtest_match` builds from `driver.match_log()`; delete `recorder`, `_recording`, `_issue` (`:25`, `:59-65`; now in the offline driver).
  - `online_main.gd`: `setup` builds `OnlineDriver.new(transport, lockstep, seat, faction)` and sets `local_player`; delete `_create_simulation` (`:35-36`), `_confirm_leave`, `_pauses_sim` (`:38-42`), `_step_simulation` (`:50-66`), `playtest_context` and `playtest_match` (`:68-75`, the skirmish versions now read the driver), `_submit` (`:77-83`) and the moved fields and functions (`:9-17`, `:88-143`); `_ready` keeps `super._ready()`, `_perf.extra = driver.net_line`, `driver.start()`; `_leave` = `driver.leave()` then `super()`; `_exit_tree` = `driver.detach()`; `_restart` stays `pass`; `_note` = `_error + driver.notice()`; `_refresh_hud` reads `driver.notice()`.
  - Driver member names: warnings are errors (`gdscript/warnings/shadowed_variable=2`, `game/project.godot:57`), so a driver field never shares a name with a parameter of its methods: the online driver keeps the report settings as `_map_path`, `_starts`, `_seed` (not `map_path`, `starts`, `match_seed`, which are `create`'s parameters) and its `_report` reads those; the offline driver stores `_player`.
- [ ] **Step 6 (SK23, by hand):** `test_skirmish.gd` `test_desync_report_names_map_seed_starts` (`:693-708`): `const OnlineMain` (`:17`) → `const OnlineDriver = preload("res://scripts/match/online_driver.gd")`; the case builds `var driver = OnlineDriver.new(null, Lockstep.new(1, [1, 2] as Array[int]), 1, "usa")`, calls `driver.create(MatchSettings.map_path("ashfall"), MatchSettings.starts("ashfall", 7), {}, 7)` and `var report: Dictionary = driver._report()`. Label unchanged. Changed lines, each listed with its reason: the right-hand side of the `starts` comparison becomes `MatchSettings.starts("ashfall", 7)` (`SkirmishMain.starts` is no longer set, so it would be `[]`); `main.free()` goes (the driver is a `RefCounted`; `free()` on it is an error); the static save and restore lines go (the driver no longer reads the statics). Then `cd $W && python3 $L/v13_check.py $W $L/v13-reasons.txt --add "Task 4: SK23 builds an OnlineDriver (starts from MatchSettings, no free, no statics)" game/tests/test_skirmish.gd` and `--add "Task 4: OD1, OD2 in cases()" game/tests/test_skirmish_scene.gd`.
- [ ] **Step 7 (verify):** `cd $W && rg -nP '(?<![\w/.])simulation\b(?!/|\.gd)' game/scripts/main.gd game/scripts/base_main.gd game/scripts/skirmish_main.gd game/scripts/online_main.gd game/scripts/match` prints nothing (the comment now says `driver.sim`); `cd $W && rg -n '\b(main|skirmish|other)\.simulation\b' game/tests` prints nothing; pre-tree scan `python3 $L/pretree.py $W/game/tests > $L/t4-pretree.log 2>&1; echo "exit=$?"` exit 0 with the same three `NO-TREE` lines. Filtered OD1, OD2, IC1 (`test_input_script`), then full suite with traces (`t4`), traces cmp, netplay match (headless client untouched; a cheap V6 check), static gates, V12, V11 (plus `OD1`, `OD2`), V11b (`labels-t4.txt` against `labels-t3.txt`: additions only), V13 (`V13 OK`).

---

### Task 5: One screen

```text
Task: one match_screen.gd holds what is left of the four scripts; the chain is gone.
Owns: game/scripts/match/match_screen.gd (new), game/scenes/skirmish.tscn (script path), game/scenes/online_skirmish.tscn (delete), game/scripts/launcher.gd (:6, :11, :239), the four chain scripts and their .uid (delete), test preload paths (test_online_scene.gd:4, :10; test_playtest_overlay.gd:5 and test_pause_menu.gd:6 OnlineScene; test_playtest_replay.gd:12; test_skirmish.gd:18 SkirmishMain (:17 became OnlineDriver in Task 4); test_view.gd:99; test_base_scene.gd:248), and the N5 expectation test_online_scene.gd:318 (resource_path == "res://scripts/skirmish_main.gd" → "res://scripts/match/match_screen.gd"; the only expected value this task changes, listed with its reason).
Invariant: V1-V12; "Pinned shapes": input dispatch, merged overrides, _ready order; the static match settings (factions, map_path, starts, match_seed) stay statics on the screen script (Decision 10).
Boundary: launcher sets the statics and then changes scene (offline) or instantiates skirmish.tscn and calls setup (online).
Red: rg -n '^extends "res://scripts/' game/scripts prints three lines before the task and none after.
Green: rg empty; IC1, IC2; every scene suite; full suite; traces cmp.
Stop: IC1 or IC2 differs (Opus diagnosis before any edit to the dispatch).
```

- [ ] **Step 1:** create `match_screen.gd`: constants and fields of the four scripts minus the demo-only ones (`_obstacle_added`, `_base_blocked`, `_toggle_obstacle`, the M2 `_refresh_hud`; the `_create_simulation` overrides went in Task 4); functions merged as pinned; every other function moved verbatim. `skirmish.tscn` script path → `res://scripts/match/match_screen.gd`. `git rm` `online_skirmish.tscn`; `launcher.gd`: `OnlineScene` preloads `skirmish.tscn`, `SkirmishMain` preloads `match_screen.gd` (the const name may stay). Delete the four scripts and their `.uid`. The `_refresh_hud` merge keeps the Task 2 null guard line (`skirmish_main.gd:282`) byte for byte.
- [ ] **Step 2:** test preloads repointed (list in Owns). `test_view.gd:99` V4 builds `match_screen.gd` `.new()` (its `_view_selection` is today's `base_main.gd:51-55`: a selected building wins). `test_base_scene.gd:248` `BaseMain.queue_label` → the screen script until Task 7. `test_online_scene.gd:318` N5 path as in Owns. Then `cd $W && python3 $L/v13_check.py $W $L/v13-reasons.txt --add "Task 5: script and scene paths" <every test file this task edited>` and copy the rows. `cd $W && rg -n 'scripts/(main|base_main|skirmish_main|online_main)\.gd|scenes/(main|base|online_skirmish)\.tscn' game tools .github` prints nothing.
- [ ] **Step 3:** red check (`cd $W && rg -n '^extends "res://scripts/' game/scripts`, three lines before, none after), then filtered IC1 and IC2 (`test_input_script`), the scene suites (`test_scene`, `test_base_scene`, `test_skirmish_scene`, `test_online_scene`, `test_pause_menu`, `test_playtest_overlay`, `test_perf_overlay`, `test_view`), full suite with traces (`t5`), traces cmp, static gates, pre-tree scan exit 0, V11 and V11b (no label lost).

---

### Task 6: Extract orders

```text
Task: orders.gd owns selection, modes and the input-to-payload code; the screen forwards _unhandled_input to it.
Owns: game/scripts/match/orders.gd (new), match_screen.gd, test access paths for orders members, test_skirmish_scene.gd _ic_row only.
Invariant: V1-V12; the dispatch function body moves unchanged; payload literals unchanged.
Boundary: tests that call main._unhandled_input directly (17 uses) keep doing so (the screen forwards).
Red: OR1 fails before orders.gd exists (stub).
Green: OR1, IC1, IC2, scene suites, full suite.
Stop: IC1 or IC2 differs.
```

- [ ] **Step 1 (test, `test_skirmish_scene.gd`):** **OR1 `test_orders_turn_input_into_payloads`:** an `Orders` on a screen with the `_arena` world: a box drag selects both units, a right-click submits one `move` whose `entity_ids` equal `orders.selected_ids` and whose `target` is the clicked ground (`"OR1 orders own the selection and emit the move payload"`). Stub first.
- [ ] **Step 2:** move per "Pinned shapes: Orders". Screen: `var orders: RefCounted = Orders.new(self)` as a member initializer (V4 in `test_view.gd:99-106` builds the screen with `.new()` and never runs `_ready`); `_unhandled_input(event)` → `orders.handle(event)`; `pan_camera` and `change_zoom` gate on `orders.busy()`; `_escape_pending` → `orders.escape_pending()` (keeps the match-over guard); `_restart` calls `orders.reset()`; `_show` calls `orders.prune(state)` where `main.gd:242` pruned (R4).
- [ ] **Step 3 (test paths, asserted):** recount on this tree with `cd $W && rg -o '\b(main|skirmish|other)\.(selected_ids|selected_building_id|inspected_id|_placement_kind|_pending_placement|_attack_move_mode|_selecting|_dragged|_enter_placement|_clear_placement|_produce_selected|_move)\b' game/tests | sort | uniq -c`, the same for `\.is_selecting\(` and `\._view_selection\(` (on `35d22b5` per file: `test_base_scene.gd` 28 + 3 `is_selecting(`, `test_online_scene.gd` 4, `test_pause_menu.gd` 9, `test_playtest_overlay.gd` 9, `test_playtest_replay.gd` 1, `test_scene.gd` 18, `test_skirmish_scene.gd` 83, `test_view.gd` 2 + 2 `_view_selection(`; every receiver is `main` or `skirmish`; IC1, OD1 and the Task 2 ports add to these). A count that differs from `35d22b5` only in a file this run edited is expected; any other difference is the stop. Fill every `None` in `$L/rules_t6.py` (Run scripts; add a row for any other file the recount shows), then `python3 $L/rename.py $W t6 --dry > $L/t6-rename-dry.log 2>&1; echo "exit=$?"` and `python3 $L/rename.py $W t6 > $L/t6-rename.log 2>&1; echo "exit=$?"` (`RENAME OK t6`, writes `$L/rename-t6.done`). Production reads of these members move with their code into `orders.gd`; the screen reads `orders.<member>`. V13 add for the hand edits (`_ic_row`, OR1 in `cases()`).
- [ ] **Step 4:** filtered OR1 (`test_orders_turn`) red against the stub, then green; IC1, IC2; the scene suites; full suite with traces (`t6`), traces cmp; static gates; pre-tree scan exit 0; V11 (plus `OR1`), V11b (additions only), V13.

---

### Task 7: Extract the HUD

```text
Task: hud.gd owns the labels, buttons, menu, queue and the note line.
Owns: game/scripts/match/hud.gd (new), match_screen.gd, orders.gd (refusals write hud.note), test access paths for HUD members, test_skirmish_scene.gd _ic_row only.
Invariant: V1-V12; every HUD string byte for byte (V9, IC1 status rows); profiler zones refresh.selection and refresh.hud keep their names.
Boundary: RF1 and RF6 (one view state per refresh, no snapshot per tick) and the layout tests.
Red: HU1 fails before hud.gd exists (stub).
Green: HU1, IC1, IC2, V9, layout tests (test_hud_layout_and_focus, test_result_clear_of_status, test_health_bar_clear_of_boxes, test_hud_font_size_is_shared, N3, M6, H6, test_menu_layout), full suite.
Stop: any HUD string or layout check differs.
```

- [ ] **Step 1 (test):** **HU1 `test_hud_reads_only_state_and_orders`:** a `Hud` on the scene's `HUD` layer, refreshed from a `view_state()` and an `Orders` with a selected barracks, shows the `Produce` button and the barracks line, and a second refresh with an unrelated player's rejection keeps the note (`"HU1 the HUD shows the selection and keeps the local note"`). Stub first.
- [ ] **Step 2:** move per "Pinned shapes: HUD" (R3 for `_sound.update`). The screen creates `hud = Hud.new($HUD, self)` in `_ready` before the first `_refresh()` (step 2 of the `_ready` order); `_show` calls `hud._refresh_hud(state)` inside the `refresh.hud` zone; `_note()` is `hud.note + driver.notice()`; `_restart` calls `hud.reset()`; `_match_record` uses `hud._result_text(state.match)`. `hud._refresh_hud` keeps the Task 2 null guard (`"" if state.match == null else _result_text(state.match)`).
- [ ] **Step 3 (test paths, asserted):** recount with `cd $W && rg -o '\b(main|skirmish|other)\._error\b' game/tests | sort | uniq -c` and the same for `\.(_refresh_menu|_refresh_hud|_selected_summary|_enemy_summary|_result_text|_last_result_tick|_last_result_sequence)\b` (on `35d22b5`: `_error` 40 in 5 files: `test_announcer.gd` 2 (`skirmish.`), `test_base_scene.gd` 6, `test_order_voice.gd` 4 (`skirmish.`), `test_playtest_overlay.gd` 10, `test_skirmish_scene.gd` 18; the helpers: `test_base_scene.gd` 2, `test_skirmish_scene.gd` 9); same rule for differences as Task 6. Fill `$L/rules_t7.py`, then `python3 $L/rename.py $W t7 --dry > $L/t7-rename-dry.log 2>&1; echo "exit=$?"` and `python3 $L/rename.py $W t7 > $L/t7-rename.log 2>&1; echo "exit=$?"` (`RENAME OK t7`, writes `$L/rename-t7.done`). Receivers change, names do not (`main._error` → `main.hud.note` is the one name change). `test_base_scene.gd:248` (`var BaseMain = load(…)`, `queue_label` `:249-250`) points at `hud.gd` by hand. V13 add for the hand edits (`:248`, HU1 in `cases()`).
- [ ] **Step 4:** filtered HU1 (`test_hud_reads`) red against the stub, then green; IC1, IC2, V9; full suite with traces (`t7`), traces cmp (the layout tests in it); `cd $W && rg -n '^extends "res://scripts/' game/scripts` still empty; static gates; pre-tree scan exit 0 (a `hud` read before `_ready` would show); V11b (additions only), V13; V11 (plus `HU1`).

---

### Task 8: Docs and package gate

```text
Task: docs describe one screen and three objects; the final tree passes every local gate; one ledger row.
Owns: docs/guide/01-big-picture.md, 02-world.md, 03-entities.md, 04-the-tick.md, 05-presentation.md, 07-economy.md, 08-combat.md, 09-ai.md, 10-determinism-and-replays.md, 11-multiplayer.md, 13-testing-and-tooling.md, docs/guide/README.md, docs/development.md, docs/STATUS.md, docs/packages.md (the One controller note, one clause), README.md (generated only), docs/reference/perf-history.csv (benchmark record only), docs/reference/performance.md (one History row), the verification file.
Invariant: V1-V12.
Boundary: load average above 2.5 at the benchmark start (note it, wait with a Monitor until-loop on uptime at most 15 minutes, else morning item).
Red: n/a.
Green: every command below on the final tree, each recorded with the tree it ran on.
Stop: a pin differs; a budget or ceiling newly exceeded.
```

- [ ] **Step 1 (guide):** replace the chain with the screen and its three objects, keeping each chapter's simple-to-complex order (`AGENTS.md`, codebase guide rule), and set each touched chapter's `Checked against` footer to `cd $W && git rev-parse --short HEAD` at the start of this task (and its `Files:` list to the new paths). Places on `35d22b5` (re-found with `cd $W && rg -n 'main\.gd|base_main|skirmish_main|online_main|main\.tscn|base\.tscn|online_skirmish|_step_simulation|_refresh_hud|_submit\b|driver chain' docs/guide`): ch. 1 (`01-big-picture.md`) `:35`, `:37`, `:41`, `:45`, `:50` (trails), `:82-84` (chain diagram becomes screen → driver, orders, HUD), `:90-94` (hooks paragraph and list), `:115-118`, `:122` (scene list loses `base.tscn`, `main.tscn`, `online_skirmish.tscn`), footer `:135`; ch. 2 `:114`, `:190`, footer `:208`; ch. 3 `:146` (`hud._selected_summary`), footer `:199`; ch. 4 `:34`, `:62`, `:64`, `:69`, `:160-162`, footer `:179`; ch. 5 `:9`, `:44`, `:123`, `:143-145`, `:153-154` (scenes; statics now on `match_screen.gd`), `:156` (HUD paragraph: there is now a HUD object), `:157` (Input paragraph: one dispatch in `orders.gd`), `:176`, `:179`, `:197`, `:212-213`, footer `:228`; ch. 7 `:108`, footer `:225`; ch. 8 `:64`, footer `:226`; ch. 9 `:9`, `:34`, `:96`, `:150`, footer `:163`; ch. 10 `:82`, `:143`, footer `:166`; ch. 11 `:13`, `:40`, `:42`, `:46`, `:91` (Pacing: `online_main._step_simulation` → the online driver's `step`), `:202`, footer `:221`; ch. 13 `:78` (`test_scene.gd` and `test_base_scene.gd` now run on the match scene), footer `:246`; `docs/guide/README.md` `:91` (Driver: now the driver object; the screen is the scene script), `:109` (Skirmish), footer `:117`. Tasks 9 and 10 add their one-line behaviour notes to ch. 5 and ch. 11 and refresh those footers again.
- [ ] **Step 2 (notes):** `docs/development.md:52` (controls of the M2 and M3 scenes: development history only) and `:95` drop the `run_game.sh res://scenes/base.tscn` and `res://scenes/main.tscn` lines; `docs/packages.md:84` One controller note: one clause that `net/seat_sim.gd` stays as the headless client's bot adapter (Decision 4); `docs/STATUS.md:24` night 2 row: "implemented on branch `one-controller` (local, not pushed); CI, Windows, browser and the attended offline and online match unverified" (Task 10 adds the two fixes). `performance.md` History: one row, "controller only; no timed benchmark loads the controller; benchmark row for the record". `cd $W && python3 tools/roadmap.py > $L/t8-roadmap.log 2>&1; echo "exit=$?"` and `cd $W && python3 tools/roadmap.py --check >> $L/t8-roadmap.log 2>&1; echo "exit=$?"` exit 0; `cd $W && sh tools/check_public.sh > $L/t8-public.log 2>&1; echo "exit=$?"` exit 0 (`PUBLIC CHECK PASSED`); relative links in changed docs resolve.
- [ ] **Step 3 (gates):** full suite with traces (`final`), traces cmp (V5); static gates; netplay match (V6), then `perturb`, `relay-down`, `relay-term` the same way (`cd $W && sh tools/run_netplay.sh <scenario> > $L/t8-<scenario>.log 2>&1; echo "exit=$?"`, marker `NETPLAY PASSED <scenario>`); `cd $W && sh tools/run_conformance.sh > $L/t8-conformance.log 2>&1; echo "exit=$?"` (`CONFORMANCE PASSED`); `cd $W && sh tools/run_team_match.sh > $L/t8-team.log 2>&1; echo "exit=$?"` (V7); V8, V11, V11b, V12; V13: `cd $W && python3 $L/v13_check.py $W $L/v13-reasons.txt > $L/t8-v13.log 2>&1; echo "exit=$?"` (`V13 OK`; paste its summary line and check the verification file's reasons list holds every listed row); `cd $W && rg -n '^extends "res://scripts/' game/scripts` empty. Each with Bash `timeout: 600000`.
- [ ] **Step 4 (benchmark, alone, last):** `pgrep -fl 'godot|generalszh'` shows none of this run's processes; `uptime` (above 2.5: the Boundary rule); `cd $W && PERF_LABEL="One controller" sh tools/run_benchmark.sh > $L/t8-bench.log 2>&1; echo "exit=$?"` (Bash `timeout: 600000`). Expected markers as in Global Constraints, only the accepted `BUDGET EXCEEDED` line (Task 0). No rendered rerun (Decision 14).
- [ ] **Step 5:** resume record names the morning items ("Unverifiable at night"). This is the refactor gate: "no behaviour change" ends here.

---

### Task 9: F3 toggles the perf overlay during placement

```text
Task: F3 shows and hides the perf overlay while a building placement is active, as it does in every other mode; the placement stays active and no command is issued.
Owns: game/scripts/match/orders.gd (the placement branch only), game/tests/test_perf_overlay.gd (PO19), game/tests/input_script_rows.gd (IC1 re-pin, and IC2 only if it ran step 10), docs/guide/05-presentation.md (one line, footer), the verification file.
Invariant: V1-V9, V11 (plus PO19), V12; every other event class and mode dispatches as before (IC1 and IC2 differ only in the perf= field of the F3 row and later rows).
Boundary: today F3 in placement falls into the placement branch (base_main.gd:195-206, now orders.gd's placement input) and never reaches the toggle (main.gd:141-142, now orders.gd's selection input); match over or an open playtest dialog still ignores F3 (the guard at the top of orders.handle runs first, unchanged).
Red: PO19 fails on the Task 8 tree (overlay stays hidden after F3 in placement).
Green: PO19; IC1, IC2 after the re-pin; full suite with traces, traces cmp; netplay match; static gates.
Stop: the re-pin would change anything but perf= in IC1/IC2; any other check changes; a trace or pin moves.
```

- [ ] **Step 1 (test first, `test_perf_overlay.gd`):** **PO19 `test_f3_toggles_during_placement`:** on `skirmish.tscn` with the `_m3_world()` fixture (Task 2), select the builder, key `1` (placement active), F3 (the file's `_f3(main)` helper, `:19-24`): `HUD/PerfOverlay` visible, the placement kind unchanged, no new entry in `main.driver.sim.snapshot().pending_commands`; second F3 hides it (`"PO19 F3 toggles the overlay during placement and keeps the placement"`). Add to `cases()`. `test_perf_overlay.gd` is not on the boundary allowlist: interface calls only.
- [ ] **Step 2 (red):** `cd $W && WARGRID_TEST_ONLY=test_f3_toggles_during_placement sh tools/run_tests.sh > $L/t9-red.log 2>&1; echo "exit=$?"`: exit 1 with the `PO19` failure. Record the failing line in the verification file (Task 9 row). A pass here is the stop: F3 already works, report BLOCKED.
- [ ] **Step 3 (fix):** in `orders.gd`'s placement input (the branch moved from `base_main.gd:195-206`), first line: the same F3 test as the selection input (`event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3`) calls `_screen._perf.toggle()` and returns. Nothing else in the dispatch changes.
- [ ] **Step 4 (green and re-pin):** PO19 green. IC1 now fails at its F3 row (step 10): expected, that row's `perf=` flips. Re-pin: update `IC1_ROWS` (and `IC2_ROWS` if IC2 ran step 10) by changing `perf=false` to `perf=true` in the F3 row and every later row and nothing else; check with `cd $W && git diff -U0 game/tests/input_script_rows.gd > $L/t9-repin.diff; echo "exit=$?"` (for the record) and `python3 $L/t9_repin_check.py $W > $L/t9-repin.log 2>&1; echo "exit=$?"` (Run scripts; `REPIN OK rows=<n>`: each changed row differs only in `perf=false` → `perf=true` and belongs to step 10 or later). Then IC1, IC2 green. V13 add for PO19 in `cases()` (`game/tests/test_perf_overlay.gd`).
- [ ] **Step 5 (gates):** full suite with traces (`t9`), traces cmp; netplay match (V6); static gates; the HUD layout tests in the suite. Guide ch. 5 Input paragraph (`:157` or its Task 8 successor): one clause "F3 toggles the perf overlay in every mode, placement included"; footer to `git rev-parse --short HEAD`.
- [ ] **Step 6 (commits, coordinator):** two local commits, in this order: (1) the fix, PO19, guide line and verification rows (IC1 is red on this commit at the F3 row only, by design); (2) `game/tests/input_script_rows.gd` alone, subject "Re-pin IC1 F3 rows: F3 now toggles the overlay during placement" plus one line naming Task 9 and Decision 17. The re-pin commit is V10's new base.

---

### Task 10: Every tick's command results reach the HUD in a two-tick online frame

```text
Task: when one online physics frame advances two ticks (catch-up), the HUD sees the command results of both ticks, so an own rejection on the earlier tick is not lost; offline frames hand the HUD exactly what they did before.
Owns: game/scripts/match/online_driver.gd and offline_driver.gd (step_results), game/scripts/match/match_screen.gd (_physics_process append line only), game/tests/test_online_scene.gd (N27), docs/guide/11-multiplayer.md (one line, footer), docs/STATUS.md (night 2 row), the verification file.
Invariant: V1-V12, V11 plus N27; offline stepped_results content per frame unchanged; sound collection per tick unchanged; lockstep rejections (issue-time, online_main.gd:60-65 path) unchanged.
Boundary: today main.gd:113 appends simulation.command_results() once per frame after _step_simulation, and the online loop (online_main.gd:54-59) can advance two ticks before it, so only the last tick's results reach stepped_results; the HUD reads stepped_results + state.command_results (base_main.gd:74), both from the last tick. Issue-time rejections go through Lockstep.rejections() per tick and are not affected. Only a due-time result (simulation.gd step, `_command_results.append`, after `_validate(command, true)` or a placement error) on the earlier tick can be lost.
Red: N27 fails on the Task 9 tree, if Step 1 shows the loss.
Green: N27; IC1, IC2; test_catch_up_is_bounded, test_restart_drops_old_stepped_results, SD1; full suite with traces, traces cmp; netplay match; static gates.
Stop: Step 1 cannot build a two-tick frame with an own due-time rejection on its earlier tick and cannot show why (BLOCKED, Opus diagnosis); a trace or pin moves.
```

- [ ] **Step 1 (characterise first):** write **N27 `test_two_tick_frame_keeps_earlier_results`** in `test_online_scene.gd` on `_online(runner, 1)` (`:39-49`): bank catch-up credit with frames that cannot advance (as `test_catch_up_is_bounded`, `:175`, does), then queue peer packets so the next frame advances two ticks, with an own command whose result is a due-time rejection on the earlier of the two (suggested: after `_online` returns and before the first `_run`, swap in a world with two own builders, `main.driver.sim = …` (it cannot go before the start: `_ready` calls `driver.create`, and there is no forwarding property, Decision 6); the peer packets from `_peer_packets` carry null hashes, so the swapped world raises no desync; then submit two `build` orders on the same footprint in the same tick: both pass issue validation, the second fails in `Construction.place`; any other own due-time rejection is fine). Check: after that frame, `HUD/Status` contains the rejection's error (`"N27 a two-tick frame keeps the earlier tick's own rejection"`), plus a control in the same case: the same orders with one tick per frame show the error. No simulation-private access (`test_online_scene.gd` is not on the boundary allowlist). Run filtered: `cd $W && WARGRID_TEST_ONLY=test_two_tick_frame sh tools/run_tests.sh > $L/t10-char.log 2>&1; echo "exit=$?"`. Record in the verification file which outcome holds:
  - (a) N27's main check fails and the control passes: the loss is real; go on with Steps 2-4 (fix).
  - (b) N27 passes on the Task 9 tree: the result is not lost today (record how it reaches the HUD); keep N27 as a test-only guard, skip Steps 2-3, record "not lost; guard only".
  - (c) the case cannot be built (no own due-time rejection reachable online): BLOCKED to the coordinator with the reason (Opus diagnosis), no guess.
- [ ] **Step 2 (red recorded):** outcome (a): paste the `FAIL` line of `$L/t10-char.log` into the Task 10 row.
- [ ] **Step 3 (fix):** both drivers get `step_results() -> Array` (Pinned shapes: Driver). Offline: `return sim.command_results().duplicate(true)` (today's `main.gd:113` expression). Online: `step` clears `_step_results` at its start and, in the catch-up loop right after a successful `advance` (beside `after_tick.call()`), appends `sim.command_results().duplicate(true)`; `step_results()` returns it. Screen `_physics_process`: `if advanced: stepped_results.append_array(driver.step_results())` in place of the `command_results()` line. Offline: same array as before, every frame. Online one-tick frames: same as before.
- [ ] **Step 4 (green):** V13 add for N27 in `cases()`; N27 green; IC1, IC2, `test_catch_up_is_bounded`, `test_restart_drops_old_stepped_results`, `test_stall_frames_are_not_step_frames`, SD1 green (filtered runs); full suite with traces (`t10`), traces cmp; netplay match (V6); static gates; the HUD layout tests in the suite.
- [ ] **Step 5 (docs):** guide ch. 11 Pacing paragraph (`:91`): one clause "the HUD gets every advanced tick's command results, not only the last"; footer to `git rev-parse --short HEAD`; `docs/STATUS.md:24` night 2 row adds "F3 in placement and two-tick frame results fixed (Tasks 9, 10)" (or "two-tick results: not lost, guard only"); `cd $W && python3 tools/roadmap.py --check > $L/t10-roadmap.log 2>&1; echo "exit=$?"`; `cd $W && sh tools/check_public.sh > $L/t10-public.log 2>&1; echo "exit=$?"`. No new benchmark row: no timed benchmark loads the controller (Task 0 note); the Task 8 row stands.

---

### Task 11: Fresh-context branch review (Opus, high)

- [ ] Three sub-steps, each with its own row in the verification file's task table (11a review, 11b fix round, 11c `/ponytail-review`), so a stop resumes at the first one not green and never reruns a finished review: the review's findings go into the verification file's Review section before 11b starts.
- [ ] **11a:** (tell the reviewer about Task 2 amendment 1, the `state.match == null` guard: if wrong, a null match shows a blank Result instead of a SCRIPT ERROR) one fresh Opus (high) reviewer gets `cd $W && git diff main...HEAD`, the changed paths, this plan's "Review focus", "Pinned shapes", "Accepted reorders", "Frame-order and interaction cases" and "Determinism notes", the verification file, and the instruction to name, per new test (IC1, IC2, OD1, OD2, OR1, HU1, PO19, N27) and per ported check family (S, Bs, G26, E1, PO), the production change that would make it fail. The review covers the refactor (Tasks 0-8) and both fixes (Tasks 9, 10). No repo-wide search.
- [ ] **11b:** one fix round at night (user, 2026-11-14): critical and important findings only, test-first (failing check first, red recorded in the verification file, then the fix, green), by one Sonnet subagent; rerun the affected checks, the full suite with traces (`t11`), traces cmp, netplay match, static gates, V11b, V13 (`V13 OK`, after a V13 add for any test the round edited). Minor findings go to the morning summary as a list, not fixed. A finding that would need a pin, trace or IC row change beyond Task 9's re-pin is a stop condition, not a fix.
- [ ] **11c:** then one `/ponytail-review` pass on the diff (over-engineering only); apply cuts, re-verify (full suite, traces cmp, static gates, V13).

## Decisions this plan relies on

- Package scope, "no behaviour change", no trace re-pin, verify with the suite, `run_netplay.sh match` and the HUD layout tests; the manual match is an attended check before P2.3a (user, 2026-11-13, `docs/packages.md:84`).
- One controller is its own night package before P2.3a; the `SimPump` seam stays in Later 3 (user, 2026-11-13, design answers `:479`).
- Small resumable tasks with a resume record, one or two nights (user, 2026-11-13, design answers `:505`).
- The W, A, S, D change stays in P2.3b (package note).
- Exceeded `open` and `hordes300` rows accepted, never loosened (user, 2026-11-07, performance ledger); combat `dense` accepted as exceeded (user, 2026-11-14, Sim quick wins verification file).
- The kickoff questionnaire answers below (user, 2026-11-14).

## Decisions (user, 2026-11-14, kickoff questionnaire)

All twenty draft questions are answered: the recommendation everywhere except 6 and 17; 15 was already met. The plan text above follows these answers.

1. **Demo scenes `main.tscn` (M2) and `base.tscn` (M3):** deleted; their controls stay in the development history and their checks run on the match scene (Task 2).
2. **Demo-only checks** (S8 obstacle toggle, S9 M2 status counts, the SD22 demo row): deleted with the demos (Task 3).
3. **WASD `camera_*` actions** (`game/project.godot:24-36`) and the S1 binding check: left until P2.3b.
4. **`net/seat_sim.gd`:** kept as it is (the headless client's bot adapter, `headless_client.gd:167`); the package note records why.
5. **Driver shape:** two duck-typed files, no base class, no inheritance.
6. **`simulation` on the screen:** no forwarding property; tests read and assign `main.driver.sim` through one asserted rename (Task 4); no test may touch the simulation before the driver exists; the recorder's `is_same` follows `driver.sim`.
7. **Orders reach the screen** through a back-reference with direct calls.
8. **`online_skirmish.tscn`:** deleted; the launcher instantiates `skirmish.tscn` and calls `setup`.
9. **`skirmish.tscn`** keeps its name.
10. **Match settings statics** stay on the screen script (only the preload path changes).
11. **Folder:** `game/scripts/match/` for the five files.
12. **Accepted reorders R1-R5** count as "no behaviour change"; the reviewer checks each.
13. **Characterisation cases IC1 and IC2** with literal rows are added (Task 1).
14. **Rendered benchmark at the gate:** skipped (the rendered benchmark scene does not load the controller).
15. **Base:** Sim quick wins merged first; met (merged and pushed 2026-11-14, `main` `35d22b5`).
16. **Model routing:** Sonnet for the implementation tasks, Opus (high) only for the review and for diagnosis of any IC difference or unexpected red.
17. **Quirks:** both fixed after the refactor gate, each test-first on the same branch: F3 during placement (Task 9; IC1's F3 row re-pinned in its own commit) and two-tick online frame results (Task 10, characterised first). The refactor itself stays "no behaviour change" through Task 8 (fixing inside the refactor was proposed and declined).
18. **Audit's second done criterion:** a review reading (Review focus 5), not a gate.
19. **Paths:** worktree `~/projects/wargrid-wt-onecontrol`, branch `one-controller` from `main` (Task 0), logs `~/projects/wargrid-overnight-work/one-controller/logs`, written out as absolute paths in every command. The night settings need an Edit allow rule for that worktree (the user's file; the prep writes a proposed copy and a `cp` line).
20. **Nights:** straight through Tasks 0-11; the resume record covers a stop after any GREEN task.

# One controller verification

```text
Resume record (updated 2026-11-14: Task 0 GREEN, not committed)
Branch / base commit / working-tree state: one-controller (worktree ~/projects/wargrid-wt-onecontrol) / main 74950e5 (= 35d22b5 plus the plan commit; game/ unchanged) / only this file modified
Last green task / next incomplete task: Task 0 / Task 1
Changed paths since last commit: docs/reference/one-controller-verification.md
Last command / cases / checks / failures / exit / marker: full suite with traces on 74950e5 / 858 / 144249 / 0 / exit 0 / TESTS PASSED 144249
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: package note "One controller" (user, 2026-11-13); plan "Decisions (user, 2026-11-14)" 1-20; local commits as the night run handoff pre-authorizes (one per GREEN task, two in Task 9); benchmark only in Task 8, alone; Task 1 commit (V10 base): none yet; Task 9 re-pin commit (V10 base from Task 9): none yet
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: Task 1 Step 1 (characterisation input scripts IC1, IC2)
```

Plan: [One controller plan](../superpowers/plans/2026-11-14-one-controller.md). Spec: `docs/packages.md` package note "One controller" (`:84`); design answers "Package review, second pass" (`:474-505`) and "Main branch audit" (`:363-378`); audit FIX-6 and A-1 (kept outside the repository, `~/projects/wargrid-overnight-work/audit-2026-11-11/`). Logs: `~/projects/wargrid-overnight-work/one-controller/logs/` (outside the repository; commands use the absolute path). A stop after any GREEN task resumes at the next row of the task table: the subagent reads this record, checks `git log --oneline -1` and `git status --short` in the worktree against it, and starts that task's Step 1.

## Tasks

| Task | What | Model | Status |
|---|---|---|---|
| 0 | Baseline: worktree, import, suite and traces, pins, member and simulation censuses, pre-tree scan, check-id census | Sonnet | GREEN (uncommitted) |
| 1 | Characterisation: IC1 offline and IC2 online input scripts | Sonnet | not started |
| 2 | Port the M2 and M3 scene checks onto the match scene (old chain) | Sonnet | not started |
| 3 | Delete the demo scenes and demo-only checks | Sonnet | not started |
| 4 | Extract the driver (OD1, OD2); `main.driver.sim` rename (Decision 6) | Sonnet | not started |
| 5 | One screen: merge the chain, delete the four scripts | Sonnet | not started |
| 6 | Extract orders (OR1) | Sonnet | not started |
| 7 | Extract the HUD (HU1) | Sonnet | not started |
| 8 | Docs and package gate (ledger row); end of "no behaviour change" | Sonnet | not started |
| 9 | F3 toggles the perf overlay during placement (PO19; IC1 re-pin commit) | Sonnet | not started |
| 10 | Two-tick online frame results reach the HUD (N27: characterise, then fix or guard) | Sonnet | not started |
| 11a | Fresh-context branch review (refactor and fixes); findings into the Review section | Opus (high) | not started |
| 11b | One fix round: critical and important findings, test-first | Sonnet | not started |
| 11c | `/ponytail-review` of the diff; cuts re-verified | Sonnet | not started |

## Baseline (Task 0)

| Item | Value |
|---|---|
| Tree (`git log --oneline -1`), `main` equals `35d22b5` or `game/` unchanged since | worktree `one-controller` at `74950e5` Plan the One controller run; `git diff --stat 35d22b5 main -- game/scripts game/tests` empty; `git status --short` empty before Task 0 edits |
| `uptime` at start / end | load 2.20 / 2.33 / 1.89 (08:49) / 2.16 / 2.42 / 1.98 (08:51); no godot or generalszh process at start |
| Full suite: wall seconds, CASES, CHECKS, exit | 55 s, CASES 858, CHECKS 144249, FAILURES 0, exit 0, `TESTS PASSED 144249`; import exit 0 beforehand (`t0-import.log`) |
| Trace files (`replay`, `economy`, `combat`, `team` `-before.tsv`), line counts | replay 1200, economy 1200, combat 1200, team 100 |
| `online_main.gd` `_report` reads `desync_report(simulation)` (`:109` on `35d22b5`) | yes, `online_main.gd:109` `_lockstep.desync_report(simulation)` |
| Anchor drift against the plan | none: every `func` anchor of main, base_main, skirmish_main, online_main in Pinned shapes and the Determinism notes found at the planned line; shortcut comment `skirmish_main.gd:121`, recorder comment `:59` as planned |
| Check-id census `$L/ids-before.txt`: count; `IC1`, `IC2`, `OD1`, `OD2`, `OR1`, `HU1`, `PO19`, `N27` absent | 659 ids; all eight absent (`rg` prints nothing, exit 1) |
| Pre-tree scan `$L/t0-pretree.log`: exit, `PRE-TREE` lines, `NO-TREE` lines | exit 0, no `PRE-TREE`; `NO-TREE` `test_online_scene.gd:317`, `test_skirmish.gd:700`, `test_view.gd:99` (as expected) |
| Label census `$L/labels-before.txt`: line count (3070 on `35d22b5`) | 3070 |
| Run scripts present in `$L` (`pretree.py`, `rename.py`, `rules_t4.py`, `rules_t6.py`, `rules_t7.py`, `v13_check.py`, `t9_repin_check.py`) | all seven present |
| Plan and this file tracked on the worktree's base (`git ls-files`) | both listed |
| `BUDGET EXCEEDED` line on `main`'s last ledger row (expected `open dense hordes300`) | `performance.md:135` (Sim quick wins gate): `BUDGET EXCEEDED open dense hordes300 (regression ceilings held)`; accepted line for this run; last `perf-history.csv` row 2026-11-14 `ae09473` |

## Simulation census (Decision 6; Task 0, asserted by the Task 4 rename)

On `35d22b5` by `rg -o '\b(main|skirmish|other|fight|recorder)\.simulation\b' game/tests` (occurrences, not lines): 212 hits, 194 of them `main.simulation`, 24 of those assignments (`main.simulation =`). Renamed: 205 hits in 11 files. Not renamed: `fight.simulation` 6 (`test_art_lab.gd`, the lab's own `lab_fight.gd` field) and `recorder.simulation()` 1 (`test_playtest_replay.gd`, the recorder's method).

| File | Receiver(s) | On `35d22b5` (of them assignments) | Task 0 | Task 2-3 diff +/- | Task 4 recount | Renamed to |
|---|---|---|---|---|---|---|
| `test_base_scene.gd` | `main` | 67 (11) | 67 (main) | | | `main.driver.sim` |
| `test_skirmish_scene.gd` | `main` 45, `other` 4 | 49 (11) | 49 | | | `.driver.sim` |
| `test_scene.gd` | `main` | 27 (0) | 27 | | | `main.driver.sim` |
| `test_online_scene.gd` | `main` (also `online.main`, `web_desync.main`) | 21 (0) | 21 | | | `main.driver.sim` |
| `test_playtest_overlay.gd` | `main` | 17 (2) | 17 | | | `main.driver.sim` |
| `test_order_voice.gd` | `main` 4, `skirmish` 5 | 9 (0) | 9 | | | `.driver.sim` |
| `test_pause_menu.gd` | `main` | 6 (0) | 6 | | | `main.driver.sim` |
| `test_playtest_replay.gd` | `main` | 3 (0) | 3 (+1 `recorder.simulation`, not renamed) | | | `main.driver.sim` |
| `test_sound.gd` | `main` | 3 (0) | 3 | | | `main.driver.sim` |
| `test_announcer.gd` | `skirmish` | 2 (0) | 2 | | | `skirmish.driver.sim` |
| `test_perf_overlay.gd` | `main` | 1 (0) | 1 | | | `main.driver.sim` |
| production `main.gd` / `base_main.gd` / `skirmish_main.gd` / `online_main.gd` | bare `simulation` (pattern in plan Task 4 Step 3) | 19 / 10 / 19 / 7 = 55 (`main.gd:13` is the declaration, removed by hand, so 18 are renamed there) | = 55 (`main.gd:13` is the declaration, removed by hand, so 18 are renamed there) | 19 / 10 / 19 / 7 = 55 (PROD pattern of `rules_t4.py`) | | — | | `driver.sim` (screen), `sim` (driver bodies, Step 2) |

Task 0 totals (`$L/sim-census-before.txt`): 212 hits = `main.` 194, `skirmish.` 7, `other.` 4, `fight.` 6, `recorder.` 1; `main.simulation =` assignments 24 (as expected).

Line counts (`rg -c`) differ from these occurrence counts where a line holds two reads (for example `test_base_scene.gd` 63 lines, `test_online_scene.gd` 16 lines). No production code outside the four chain scripts reads a screen's `simulation` (`rg -n '\.simulation\b' game/scripts`: `skirmish_main.gd:61` `recorder.simulation()`, `lab/art_lab.gd:46` `fight.simulation`).

## Member census (Task 0; asserted by the rename scripts in Tasks 4, 6, 7)

On `35d22b5` (identical to `4ed3534`; `rg -o '\.<member>\b' game/tests`, all receivers; Task 0 splits by receiver):

| Task | Member | Uses / files on `35d22b5` | Screen receivers (Task 0) | Renamed to |
|---|---|---|---|---|
| 4 | `_sequence` | 2 / 1 (`test_skirmish_scene.gd`, offline restart case) | 2 / 1 | `driver._sequence` |
| 4 | `notice()`, `latency_line()` | 2 / 1, 2 / 1 (`test_online_scene.gd`) | 2 / 1, 2 / 1 | `driver.` |
| 4 | `_own_faction` | 2 / 1 | 2 / 1 | `driver._own_faction` |
| 4 | `web`, `download` | 3 / 2, 2 / 2 (screen: `web_desync.main` 1 each in `test_online_scene.gd`; `overlay.web` 2 and `overlay.download` 1 in `test_playtest_overlay.gd` stay) | 3 / 2, 2 / 2 (receivers in `$L/census-before.txt`) | `driver.` |
| 4 | `_lockstep`, `_report` (SK23 construction) | 1 / 1, 1 / 1 | 1 / 1, 1 / 1 | construction rewrite |
| 4 | `simulation` | see the simulation census | | `driver.sim` |
| 6 | `selected_ids` | 85 / 8 | 85 / 8 | `orders.` |
| 6 | `selected_building_id` | 18 / 2 | 18 / 2 | `orders.` |
| 6 | `_placement_kind` | 16 / 3 | 16 / 3 | `orders.` |
| 6 | `_attack_move_mode` | 13 / 3 | 13 / 3 | `orders.` |
| 6 | `inspected_id` | 8 / 1 | 8 / 1 | `orders.` |
| 6 | `_selecting`, `_dragged`, `is_selecting()`, `_enter_placement`, `_clear_placement`, `_produce_selected`, `_move`, `_view_selection`, `_pending_placement` | 2, 2, 3, 2, 2, 3, 3, 2, 0 | 2, 2, 3, 2, 2, 3, 3, 2, 0 (identical) | `orders.` (`view_selection`) |
| 7 | `_error` | 40 / 5 | 40 / 5 | `hud.note` |
| 7 | `_refresh_menu`, `_refresh_hud`, `_selected_summary`, `_enemy_summary`, `_result_text`, `_last_result_tick`, `_last_result_sequence` | 2, 1, 1, 1, 2, 2, 2 | 2, 1, 1, 1, 2, 2, 2 (identical) | `hud.` (`result_text`) |
| 7 | `queue_label`, `menu_label` (statics) | 2 / 1, 0 | 2 / 1, 0 (identical) | `hud.gd` script const |
| stays | `_refresh`, `_submit`, `_unhandled_input` (17 direct calls in 4 files), `_physics_process`, `_process`, `pan_camera`, `change_zoom`, `menu_open`, `_restart`, `playtest_match`, `_sound`, `_view`, `_auto_*`, `local_player`, `stepped_results`, `setup`, `change_scene`, `_reset_camera`, `driver` | | | screen |

Member and simulation counts at Task 0 equal the `35d22b5` expectations in every row (per-receiver output in `$L/census-before.txt`, `$L/sim-census-before.txt`).

## Pinned values (checked at Tasks 0, 4, 5, 8, 9, 10, 11)

| # | Pin | Expected (on `35d22b5`) | Task 0 | Task 4 | Task 5 | Task 8 | Task 9 | Task 10 | Task 11 |
|---|---|---|---|---|---|---|---|---|---|
| V1 | `FINAL_DIGEST` | `3958ceaab11986af` | `3958ceaab11986af` (`test_team_match.gd:14`) | | | | | | |
| V2 | `TEAM_CORE_SERIES` | `8513092129969516499` | `8513092129969516499` (`:16`) | | | | | | |
| V3 | `S1_CORE_SERIES` | `4004499097874677431` | `4004499097874677431` (`test_skirmish_match.gd:12`) | | | | | | |
| V4 | `PINNED`, `EXPECTED_DIGEST`, `SS6_PINNED` | unchanged | `01e256834bdd4dfb` (`test_state_hash.gd:6`); `7c7fbc8d…48a9e7` (`test_view_rows.gd:18`); `SS6_PINNED` present (`test_start_spots.gd:7`) | | | | | | |
| V5 | four traces | byte-identical to `*-before.tsv` | recorded (1200 / 1200 / 1200 / 100 lines) | | | | | | |
| V6 | netplay match terminal tick | `9129` | pin present (`run_netplay.sh:91`); netplay not run in Task 0 | | — | | | | |
| V7 | `run_team_match.sh` | `won tick=39497 winner=2 units_peak=271` | pin present (`:13`) | — | — | | — | — | — |
| V8 | `git diff main -- game/tests \| rg '^-\s*const'` | only the listed preload lines | — | | | | — | — | |
| V9 | `test_hud_summaries_are_pinned` literals | unchanged | present (`test_skirmish_scene.gd:651`), suite green | | | | | | |
| V10 | `input_script_rows.gd` against the Task 1 commit (from Task 9: against the re-pin commit) | no diff | — | | | | re-pin | | |
| V11 | check-id census | Task 0 set minus the demo-only list, plus the new ids so far | 659 ids | | | | | | |
| V12 | simulation, presentation, net, playtest, `project.godot` diff against `main` | empty | — | | | | | | |
| V11b | label census | Task 3: exactly 11 demo labels removed, IC1/IC2 added; later: additions only | 3070 lines | | | | | | |
| V13 | `v13_check.py` | `V13 OK` | — | — | — | | — | — | |

## Characterisation rows (Task 1)

| Item | Value |
|---|---|
| IC1 steps run / rows | |
| IC2 steps run (which IC1 steps the online world allowed; step 10 yes / no) / rows | |
| Two runs identical | |
| Mutation (a) tick default: IC1 first failing row | |
| Mutation (b) `not is_selecting()` guard: IC1 / IC2 first failing row | |
| Task 1 commit (V10 base until Task 9; also in the resume record) | |
| Each step's intended effect checked before pinning (`IC1 step %d took effect`) | |

## Ported checks (Task 2) and demo-only list (Task 3)

Expected on `35d22b5` by reading (Task 2 confirms by running on the old chain):

| File | Families | Fixture on `skirmish.tscn` | Outcome |
|---|---|---|---|
| `test_scene.gd` | S1-S7, G26 | `_m2_world()` (`main.gd:250-258` + `add_player(1, 0)`), `_reset_camera()` | ported |
| `test_scene.gd` | S8 (eight labels: B adds, B removes, move onto toggle cell, occupied setup, occupied rejected, rejection reason, vacate, preserves next action) | — | demo-only, deleted in Task 3 |
| `test_scene.gd` | S9 (move issued, status counts) | — | demo-only (M2 HUD), deleted in Task 3 |
| `test_base_scene.gd` | Bs1-Bs6, H6, RF1, RF5, RF6, RF8, M1-M6 | `_m3_world()` (`Fixture.make_world()` + supply source) | ported |
| `test_pause_menu.gd` | E1 (Base half, `:90`; `const Base` `:4`) | `_m3_world()` | ported |
| `test_perf_overlay.gd` | PO cases on `Base` (`:39`, `:50`, `:66`, `:84`) | `_m3_world()` where the builder is read | ported |
| `test_sound.gd` | SD22 demo row (`:331-337`) | — | demo-only, deleted in Task 3 |
| `test_view.gd` | V4 hook (`:99`) | `main.gd` until Task 5, then `match_screen.gd` | ported in Task 5 |
| `test_online_scene.gd` | N5 script path (`:318`) | — | expectation path changed in Task 5 (reason: the offline scene's script moved) |

| Item | Value |
|---|---|
| Task 2: failing checks on the old chain (expected S8, S9 only) | |
| Task 2: bot needed `add_player(2, 0)` on a fixture world (yes / no) | |
| Task 2: mutations (G26 Ctrl, Bs3 building select) fail the ported check | |
| Task 3: V11 diff equals the demo-only list | |

## Driver, screen, orders, HUD (Tasks 4-7)

| Item | Value |
|---|---|
| Task 4: OD1, OD2 red against stubs, then green | |
| Task 4: rename `$L/t4-rename.log` count lines (paste), exit | |
| Task 4: pre-tree scan after the rename: exit, lines | |
| Task 4: SK23 lines changed: `starts` right-hand side → `MatchSettings.starts("ashfall", 7)` (statics no longer set); `main.free()` removed (`RefCounted`); static save and restore removed (the driver does not read the statics) | |
| Task 4: netplay match terminal tick | |
| Task 5: `rg -n '^extends "res://scripts/' game/scripts` before / after | |
| Task 5: IC1, IC2 unchanged | |
| Task 6: OR1 red, then green; rename script counts asserted | |
| Task 7: HU1 red, then green; layout tests green; rename script counts asserted | |
| Test lines changed other than access paths, ports and deletions (each with its reason) | |

## V13 reasons list (copied from `$L/v13-reasons.txt` after each `--add`)

| Task | File | Reason | Removed line (or count, for a whole deleted case) |
|---|---|---|---|

## Accepted reorders (plan R1-R4; reviewer verdict in Task 11)

| # | Reorder | Reviewer verdict |
|---|---|---|
| R1 | online `observe_command` after `_refresh` | |
| R2 | online rejection sound and note after `_finish` | |
| R3 | `_sound.update` after the whole HUD refresh | |
| R4 | `inspected_id` pruned in `orders.prune` | |

## Gate (Task 8)

| Item | Value |
|---|---|
| Tree, `uptime` start / end | |
| Full suite: CASES, CHECKS, exit; traces `cmp` | |
| `run_checks.sh` marker | |
| Netplay `match` (tick), `perturb`, `relay-down`, `relay-term` | |
| Conformance | |
| Team match line | |
| Benchmark markers; `BUDGET EXCEEDED` line; ledger row recorded | |
| `roadmap.py --check`, `check_public.sh` | |

## Fixes after the gate (Tasks 9, 10; Decision 17)

Both quirks were found by reading on `4ed3534` and are unchanged on `35d22b5`:

- F3 does nothing while a placement is active: the placement branch returns before the selection handler that toggles the overlay (`base_main.gd:195-206`, `main.gd:141-142`).
- An online frame that advances two ticks hands only the last tick's command results to the HUD (`main.gd:112-113` appends once per frame; `online_main.gd:54-59` may advance twice; `base_main.gd:74` reads `stepped_results + state.command_results`). Issue-time rejections reach the HUD per tick through `Lockstep.rejections()` (`online_main.gd:60-65`), so only a due-time result on the earlier tick can be lost; not run yet.

| Item | Value |
|---|---|
| Task 9: PO19 red on the Task 8 tree (failing line) | |
| Task 9: PO19 green; IC1 (and IC2) re-pin diff only `perf=false` → `perf=true` from the F3 row on (`$L/t9-repin.diff`, check script exit) | |
| Task 9: commits (fix, then re-pin) | |
| Task 9: suite, traces `cmp`, netplay match, static gates | |
| Task 10: characterisation outcome (a) lost / (b) not lost, guard only / (c) blocked; how the case was built | |
| Task 10: N27 red (failing line) or "guard only" | |
| Task 10: N27 green; IC1, IC2, catch-up and restart cases; suite, traces `cmp`, netplay match, static gates | |

## Review (Task 11)

| Item | Value |
|---|---|
| 11a reviewer findings: critical / important / minor (count), each with its line | |
| Per new test and ported family: production change that would make it fail | |
| 11b fix round: each finding, red line, green; suite, traces `cmp`, netplay match, static gates, V11b, V13 | |
| 11c `/ponytail-review` cuts and re-verify | |
| Minors for the morning | |

## Unverifiable at night (for the morning)

- CI on Linux and Windows, `sh tools/compare_local_traces.sh <run id>` for macOS: need a pushed branch (push needs approval).
- Browser: the web desync download path (`online_main.gd:97-99`, then the online driver) and the web build of the match screen; covered only by the fake `download` callable in `test_online_scene.gd:140-141`.
- The attended offline and online match in a window, before P2.3a starts (user, 2026-11-13).
- Rendered benchmark: skipped (Decision 14); `movement_benchmark.tscn` does not load the controller.
- Commands the night permissions refused, each with its exact text (filled in by the run).

## Evidence rows (append-only)

- 2026-11-13 night, plan writing (backup 1 of the Sim quick wins run), tree `~/projects/wargrid` `main` `4ed3534` clean, read-only (no suite, no Godot run). Read: `AGENTS.md`; the handoff's BACKUPS item 1; `docs/packages.md` `:39`, `:84`; design answers "Main branch audit" and "Package review, second pass"; audit FIX-6, A-1 and the verification checklist; `docs/milestone-prompt.md`; `docs/night-run.md` Start and Coordinator rules; `docs/reference/determinism-rules.md`; the Sim quick wins plan and verification file (format). Code read in full: `main.gd` (299 lines), `base_main.gd` (294), `skirmish_main.gd` (290), `online_main.gd` (152), `net/seat_sim.gd`, `playtest/command_recorder.gd`, the four scene files. Anchors checked with `rg -n` on `4ed3534`, among them: chain `extends` lines (`base_main.gd:1`, `skirmish_main.gd:1`, `online_main.gd:1`; no other script under `game/scripts` extends a script by path); `main.gd` `_ready` `:41`, `_input` `:95`, `_physics_process` `:105`, `_unhandled_input` `:140`, `_finish_selection` `:182`, `_toggle_obstacle` `:217`, `_show` `:237`, `_create_simulation` `:250`, `_submit` `:286`; `base_main.gd` `_ready` `:17`, `_refresh` `:67`, `_refresh_hud` `:73`, `_enter_placement` `:152`, `_unhandled_input` `:177`; `skirmish_main.gd` statics `:27-30`, `_recording` `:60`, `_step_simulation` `:81`, `_submit` `:91`, `_restart` `:149`, `_unhandled_input` `:193`, `_refresh_hud` `:278`; `online_main.gd` `setup` `:19`, `_step_simulation` `:50`, `_submit` `:77`, `_report` `:108`, `notice` `:136`; `launcher.gd` `:6`, `:11`, `:19`, `:239-240`; `headless_client.gd:167` (`SeatSim`); `skirmish.gd:161-163` (bot memory via `has_method("simulation")`); `simulation.gd:160-164` (commands rebuilt in a fixed key order); pins V1-V7 at the lines in the plan. Findings: (1) `test_base_scene.gd` is also a helper module (`key`, `pointer`, `hover` used 100+ times from `test_skirmish_scene.gd`), so it keeps its name; `test_scene.gd` and `test_skirmish_scene.gd` are on the boundary allowlist (`tools/test_sim_boundary.py:30`, `:32`), so no test file is renamed; (2) the demo worlds can be rebuilt as fixtures inside the match scene, so only S8 and S9 need the demos; (3) the skirmish HUD reads `state.players[0]` (`base_main.gd:57-60`), so the M2 fixture needs a player record; (4) the real online scene never runs a bot, so `seat_sim.gd` is the headless client's adapter, not the online driver's (plan Question 4); (5) the bot keys its memory through `has_method("simulation")`, so no driver may be passed to `Skirmish`; (6) four order changes are needed to merge the chain without split HUD calls (R1-R4), each independent by reading. Not verified: every ported check on `skirmish.tscn` (Task 2 runs them), whether the bot tolerates a world without player 2, which IC1 steps the online start world supports, and the line numbers in guide chapters 4, 10 and 11 after Sim quick wins.
- 2026-11-14, plan refinement after the kickoff questionnaire, tree `~/projects/wargrid` `main` `35d22b5` clean, docs only (no suite, no Godot run). Read: `AGENTS.md`, `docs/night-run.md` Coordinator rules, `docs/milestone-prompt.md` stop conditions, the draft plan with its "Answers (user, 2026-11-14)", the Sim quick wins plan and verification file (format); the four controller scripts in full; `lockstep.gd` `advance` and `desync_report`, `simulation.gd` `issue_command` and the due-command loop, `tools/test_sim_boundary.py`, `tools/run_tests.sh`, `tools/check_public.sh`. Diff `4ed3534..35d22b5` on `game/`: the controller scripts changed only at `online_main.gd:109` (`desync_report(simulation)`); tests changed only in `test_combat.gd`, `test_defences.gd`, `test_lockstep.gd` and `test_playtest_replay.gd` (one case appended). Anchors: every explicit `file:line` in the plan compared between both trees and re-read on `35d22b5`; drifted and fixed: `simulation.gd:160-164` → `issue_command` `:159`, `normalized` `:164-168`; `docs/development.md:50` → `:52` (was the section heading); guide ch. 4 `:33`/`:68`/`:157-159`/`:176` → `:34`/`:69`/`:160-162`/`:179`, ch. 10 `:81`/`:138`/`:160` → `:82`/`:143`/`:166`, ch. 13 footer `:239` → `:246`; added `test_pause_menu.gd:4` (Base preload, Task 2), `test_online_scene.gd:318` (N5 path, Task 5), guide ch. 1 `:37`, `:45`, `:92-94`, ch. 2 `:114`, ch. 4 `:62`, `:64`, ch. 5 `:9`, `:153`, `:156`, README footer `:117`. Counts verified on `35d22b5`: simulation census above (212 / 194 / 24; 205 renamed in 11 files; production 55); member census as in the draft; free check ids `IC1`, `IC2`, `OD1`, `OD2`, `OR1`, `HU1`, `PO19`, `N27`. Scripts run read-only against the tree: the plan's pre-tree scan (exit 0, three `NO-TREE` lines, no `PRE-TREE`; a planted pre-tree read is caught) and the Task 4 rename script in `--dry` mode with the `35d22b5` counts (`RENAME OK`), and for real on a scratch copy (260 `driver.sim` after, no old match left). Not verified: whether an own due-time rejection can be built in a two-tick online frame (Task 10 Step 1 decides), the Task 2 ports on `skirmish.tscn`, and IC2's step set.
- 2026-11-14, readiness review fixes (fresh Opus review: READY AFTER FIXES), tree `main` `35d22b5`, docs only. Applied findings 1, 3-8, 10-14, 16, 17 after checking each against `35d22b5`; 2 and 9 as the coordinator directed; 15 is in the settings copy. Run scripts written to the logs folder from the plan text (byte-identical, checked). Tested outside the repository on a scratch git copy of `game/tests` and `game/scripts`: `rename.py t4` with the `35d22b5` counts (`RENAME OK t4 files=15`), then `v13_check.py` (`V13 OK removed=197 renamed=197 listed=0`; a hand edit of N5 is `UNEXPLAINED` until `--add` lists it, then `V13 OK`; an unlisted V4 edit fails); `rename.py t6`/`t7` dry runs confirm the per-file counts in the rules comments; `pretree.py` exit 0 with three `NO-TREE` lines; label census 3070 lines, of which the demo set is 8 S8, 2 S9, 1 SD22.
- 2026-11-14 night, Task 0 baseline (Sonnet subagent), worktree `one-controller` at `74950e5` (game/ identical to `35d22b5`), load 2.2 to 2.4. Import exit 0; full suite with traces exit 0, 55 s, `CASES 858 CHECKS 144249 FAILURES 0`, `TESTS PASSED 144249`; traces 1200/1200/1200/100 lines; pins and censuses as in the tables above, no drift, no stop condition. Logs in `~/projects/wargrid-overnight-work/one-controller/logs/` (`t0-suite.log`, `t0-import.log`, `t0-pretree.log`, `ids-before.txt`, `labels-before.txt`, `census-before.txt`, `sim-census-before.txt`). Not run in Task 0: lint, warnings, netplay, benchmark.

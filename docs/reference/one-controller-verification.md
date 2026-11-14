# One controller verification

```text
Resume record (updated 2026-11-14: Task 10 GREEN, not committed)
Branch / base commit / working-tree state: one-controller (worktree ~/projects/wargrid-wt-onecontrol) / 71b1180 (Task 9 re-pin commit) / Task 10 files uncommitted
Last green task / next incomplete task: Task 10 (outcome: fix, the loss was real) / Task 11a
Changed paths since last commit: `game/scripts/match/{match_screen,offline_driver,online_driver}.gd` (`step_results`), `game/tests/test_online_scene.gd` (N27), `docs/guide/11-multiplayer.md`, `docs/STATUS.md`, this file
Last command / cases / checks / failures / exit / marker: full suite with traces / `CASES 864 CHECKS 144282 FAILURES 0` / exit 0 / `TESTS PASSED 144282`; four traces cmp exit 0; netplay match 9129 `NETPLAY PASSED match 15.9 s`; `run_checks.sh` `CHECKS PASSED 5`; roadmap --check and check_public exit 0; V1-V9, V12 unmoved, V10 empty against 71b1180, V13 OK
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: package note "One controller" (user, 2026-11-13); plan "Decisions (user, 2026-11-14)" 1-20; local commits as the night run handoff pre-authorizes (one per GREEN task, two in Task 9); benchmark only in Task 8, alone; Task 1 commit (V10 base): f1c6b78; Task 9 fix commit: 1e3b9f7; Task 9 re-pin commit (V10 base from Task 9): 71b1180
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: Task 11a (fresh-context Opus review of the branch), after the coordinator commits Task 10. Morning items are in "Unverifiable at night" below. Tell the Task 11 reviewer: Task 10 changed `step_results` in both drivers and the screen's `_physics_process` append line; the null guard in `hud.gd` `_match_hud` stays (Task 8).
```

Plan: [One controller plan](../superpowers/plans/2026-11-14-one-controller.md). Spec: `docs/packages.md` package note "One controller" (`:84`); design answers "Package review, second pass" (`:474-505`) and "Main branch audit" (`:363-378`); audit FIX-6 and A-1 (kept outside the repository, `~/projects/wargrid-overnight-work/audit-2026-11-11/`). Logs: `~/projects/wargrid-overnight-work/one-controller/logs/` (outside the repository; commands use the absolute path). A stop after any GREEN task resumes at the next row of the task table: the subagent reads this record, checks `git log --oneline -1` and `git status --short` in the worktree against it, and starts that task's Step 1.

## Tasks

| Task | What | Model | Status |
|---|---|---|---|
| 0 | Baseline: worktree, import, suite and traces, pins, member and simulation censuses, pre-tree scan, check-id census | Sonnet | GREEN (uncommitted) |
| 1 | Characterisation: IC1 offline and IC2 online input scripts | Sonnet | GREEN (uncommitted) |
| 2 | Port the M2 and M3 scene checks onto the match scene (old chain) | Sonnet | GREEN (committed 0437bdf) |
| 3 | Delete the demo scenes and demo-only checks | Sonnet | GREEN (uncommitted) |
| 4 | Extract the driver (OD1, OD2); `main.driver.sim` rename (Decision 6) | Sonnet | GREEN (committed 8c5d0d3) |
| 5 | One screen: merge the chain, delete the four scripts | Sonnet | GREEN (uncommitted) |
| 6 | Extract orders (OR1) | Sonnet | GREEN (committed 936e63b) |
| 7 | Extract the HUD (HU1) | Sonnet | GREEN (uncommitted) |
| 8 | Docs and package gate (ledger row); end of "no behaviour change" | Sonnet | GREEN (uncommitted) |
| 9 | F3 toggles the perf overlay during placement (PO19; IC1 re-pin commit) | Sonnet | GREEN (uncommitted) |
| 10 | Two-tick online frame results reach the HUD (N27: characterise, then fix or guard) | Sonnet | GREEN (uncommitted; fix) |
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
| `test_base_scene.gd` | `main` | 67 (11) | 67 (main) | +1 (Task 2) | 68 | `main.driver.sim` |
| `test_skirmish_scene.gd` | `main` 45, `other` 4 | 49 (11) | 49 | +3 (Task 1, IC1) | 52 (`main` 48, `other` 4) | `.driver.sim` |
| `test_scene.gd` | `main` | 27 (0) | 27 | -10 (Tasks 2-3: S8, S9 deleted) | 17 | `main.driver.sim` |
| `test_online_scene.gd` | `main` (also `online.main`, `web_desync.main`) | 21 (0) | 21 | none | 21 | `main.driver.sim` |
| `test_playtest_overlay.gd` | `main` | 17 (2) | 17 | none | 17 | `main.driver.sim` |
| `test_order_voice.gd` | `main` 4, `skirmish` 5 | 9 (0) | 9 | none | 9 | `.driver.sim` |
| `test_pause_menu.gd` | `main` | 6 (0) | 6 | none | 6 | `main.driver.sim` |
| `test_playtest_replay.gd` | `main` | 3 (0) | 3 (+1 `recorder.simulation`, not renamed) | none | 3 | `main.driver.sim` |
| `test_sound.gd` | `main` | 3 (0) | 3 | none | 3 | `main.driver.sim` |
| `test_announcer.gd` | `skirmish` | 2 (0) | 2 | none | 2 | `skirmish.driver.sim` |
| `test_perf_overlay.gd` | `main` | 1 (0) | 1 | none | 1 | `main.driver.sim` |
| production `main.gd` / `base_main.gd` / `skirmish_main.gd` / `online_main.gd` | bare `simulation` (pattern in plan Task 4 Step 3) | 19 / 10 / 19 / 7 = 55 (`main.gd:13` is the declaration, removed by hand, so 18 are renamed there) | = 55 (`main.gd:13` is the declaration, removed by hand, so 18 are renamed there) | 19 / 10 / 19 / 7 = 55 (PROD pattern of `rules_t4.py`) | | — | | `driver.sim` (screen), `sim` (driver bodies, Step 2) |

Task 0 totals (`$L/sim-census-before.txt`): 212 hits = `main.` 194, `skirmish.` 7, `other.` 4, `fight.` 6, `recorder.` 1; `main.simulation =` assignments 24 (as expected).

Task 4 recount (`$L/sim-census-t4.txt`, `rg -o`): 199 renamed hits in 11 files (205 - 10 + 1 + 3), `fight.` 6 and `recorder.` 1 unchanged; every differing file is one Tasks 1-3 edited. The asserted rename (`$L/t4-rename.log`, 23 lines, exit 0, `RENAME OK t4 files=15`): the 11 screen-simulation counts above, `_sequence`/`_own_faction`/`web`/`download` 2 (`test_skirmish_scene.gd`) and 4 (`test_online_scene.gd`), `notice(`/`latency_line(` 4 (`test_online_scene.gd`), production `main.gd` 18, `base_main.gd` 10, `skirmish_main.gd` 19, `online_main.gd` 7, KEEP `fight.simulation` 6, `recorder.simulation(` 1 and 1, `overlay.(web|download)` 3, all `ok`, nothing left.

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
| V1 | `FINAL_DIGEST` | `3958ceaab11986af` | `3958ceaab11986af` (`test_team_match.gd:14`) | `3958ceaab11986af` | | `3958ceaab11986af` | `3958ceaab11986af` | `3958ceaab11986af` | |
| V2 | `TEAM_CORE_SERIES` | `8513092129969516499` | `8513092129969516499` (`:16`) | `8513092129969516499` | | `8513092129969516499` | `8513092129969516499` | `8513092129969516499` | |
| V3 | `S1_CORE_SERIES` | `4004499097874677431` | `4004499097874677431` (`test_skirmish_match.gd:12`) | `4004499097874677431` | | `4004499097874677431` | `4004499097874677431` | `4004499097874677431` | |
| V4 | `PINNED`, `EXPECTED_DIGEST`, `SS6_PINNED` | unchanged | `01e256834bdd4dfb` (`test_state_hash.gd:6`); `7c7fbc8d…48a9e7` (`test_view_rows.gd:18`); `SS6_PINNED` present (`test_start_spots.gd:7`) | unchanged (suite green) | | unchanged (suite green) | unchanged (suite green) | unchanged (suite green) | |
| V5 | four traces | byte-identical to `*-before.tsv` | recorded (1200 / 1200 / 1200 / 100 lines) | `cmp` exit 0 for all four (`replay`, `economy`, `combat`, `team`) | | `cmp` exit 0 for all four (`t8-suite` traces `*-final.tsv`) | `cmp` exit 0 for all four (`*-t9.tsv`) | `cmp` exit 0 for all four (`*-t10.tsv`) | |
| V6 | netplay match terminal tick | `9129` | pin present (`run_netplay.sh:91`); netplay not run in Task 0 | 9129 | — | 9129 (`NETPLAY PASSED match 11.2 s`) | 9129 (`NETPLAY PASSED match 13.1 s`) | 9129 (`NETPLAY PASSED match 15.9 s`) | |
| V7 | `run_team_match.sh` | `won tick=39497 winner=2 units_peak=271` | pin present (`:13`) | — | — | `TEAM MATCH won tick=39497 winner=2 units_peak=271` | — | — | — |
| V8 | `git diff main -- game/tests \| rg '^-\s*const'` | only the listed preload lines | only `base.tscn` x3, `main.tscn`, `OnlineMain` const lines (Tasks 2, 3, 4) | | | only the `const` preload lines of Tasks 2, 3, 4, 5 (11 lines) | same 11 lines | same 11 lines | |
| V9 | `test_hud_summaries_are_pinned` literals | unchanged | present (`test_skirmish_scene.gd:651`), suite green | unchanged (suite green) | | unchanged (suite green) | | unchanged (suite green) | |
| V10 | `input_script_rows.gd` against the Task 1 commit (from Task 9: against the re-pin commit) | no diff | — | empty diff against `f1c6b78` | | empty diff against `f1c6b78` | re-pin: 16 rows, `REPIN OK rows=16` (base becomes the re-pin commit) | empty diff against `71b1180` | |
| V11 | check-id census | Task 0 set minus the demo-only list, plus the new ids so far | 659 ids (Task 3: 661, adds `IC1 `, `IC2 `) | 661 ids + `OD1 `, `OD2 ` = 663 | | 665 ids = 661 + `OD1 `, `OD2 `, `OR1 `, `HU1 `; no id lost | 666 ids = 665 + `PO19 ` | 667 ids = 666 + `N27 ` | |
| V12 | simulation, presentation, net, playtest, `project.godot` diff against `main` | empty | — | empty | | empty | empty | empty | |
| V11b | label census | Task 3: exactly 11 demo labels removed, IC1/IC2 added; later: additions only | 3070 lines (Task 3: 3093) | 3095 lines; diff against `labels-t3.txt` adds exactly the OD1, OD2 labels | | 3097 lines; against `labels-t7.txt` no change; against `labels-before.txt` exactly the 11 demo labels removed | 3100 lines; against `labels-t8.txt` adds only the 3 PO19 labels | 3103 lines; against `labels-t9.txt` adds only the 3 N27 labels | |
| V13 | `v13_check.py` | `V13 OK` | — | `V13 OK removed=266 renamed=188 listed=78` | — | `V13 OK removed=439 renamed=352 listed=87` | `V13 OK removed=440 renamed=352 listed=88` | `V13 OK removed=440 renamed=352 listed=88` (N27 in `cases()` listed in `v13-reasons.txt`) | |

## Characterisation rows (Task 1)

| Item | Value |
|---|---|
| IC1 steps run / rows | all 21 steps / 21 rows (steps 3, 9, 12, 19 carry the `HUD/Status` text; step 21 adds `tick=1`) |
| IC2 steps run (which IC1 steps the online world allowed; step 10 yes / no) / rows | 1, 2, 4, 6, 7, 8, 9, 10, 11, 17, 18 / 11 rows; step 10 (F3 during placement) yes, so Task 9 re-pins IC2 as well; step 9 carries the Status text |
| Two runs identical | yes (captured logs `t1-cap1.log`, `t1-cap2.log` compare equal for both cases) |
| Mutation (a) tick default: IC1 first failing row | row 1 (step 2, `"tick":1` instead of 0); reverted, `git diff --stat` shows no `game/scripts` change |
| Mutation (b) `not is_selecting()` guard: IC1 / IC2 first failing row | IC1 row 5 (step 6, extra `stop`), IC2 row 3 (step 6, extra `stop`); reverted |
| Task 1 commit (V10 base until Task 9; also in the resume record) | f1c6b78 |
| Censuses after Task 1 (V11, V11b) | check ids 661 (659 plus `IC1`, `IC2`); labels 3104 (3070 plus 34 `IC1`/`IC2` labels); pre-tree scan exit 0, `NO-TREE` lines now `test_online_scene.gd:319` (N5, was `:317`: two preload lines added), `test_skirmish.gd:700`, `test_view.gd:99` |
| Each step's intended effect checked before pinning (`IC1 step %d took effect`) | yes, every step has its check (IC1: 21 steps incl. a separate `IC1 step 8 opened the menu`; IC2 likewise); none was missing an effect |

## Ported checks (Task 2) and demo-only list (Task 3)

Expected on `35d22b5` by reading (Task 2 confirms by running on the old chain):

| File | Families | Fixture on `skirmish.tscn` | Outcome |
|---|---|---|---|
| `test_scene.gd` | S1-S7, G26 | `_m2_world()` (`main.gd:250-258` + `add_player(1, 0)`), `_reset_camera()` | ported; S2/S3 right-clicks on empty ground (amendment 2) |
| `test_scene.gd` | S8 (eight labels: B adds, B removes, move onto toggle cell, occupied setup, occupied rejected, rejection reason, vacate, preserves next action) | — | demo-only, deleted in Task 3 (done) |
| `test_scene.gd` | S9 (move issued, status counts) | — | demo-only (M2 HUD), deleted in Task 3 (done) |
| `test_base_scene.gd` | Bs1-Bs6, H6, RF1, RF5, RF6, RF8, M1-M6 | `_m3_world()` (`Fixture.make_world()` + supply source) | ported; RF6 warm-up tick (amendment 3) |
| `test_pause_menu.gd` | E1 (Base half, `:90`; `const Base` `:4`) | `_m3_world()` | ported |
| `test_perf_overlay.gd` | PO cases on `Base` (`:39`, `:50`, `:66`, `:84`) | `_m3_world()` where the builder is read | ported |
| `test_sound.gd` | SD22 demo row (`:331-337`) | — | demo-only, deleted in Task 3 (done) |
| `test_view.gd` | V4 hook (`:99`) | `main.gd` until Task 5, then `match_screen.gd` | ported in Task 5 |
| `test_online_scene.gd` | N5 script path (`:318`) | — | expectation path changed in Task 5 (reason: the offline scene's script moved) |

| Item | Value |
|---|---|
| Task 2: failing checks on the old chain (expected S8, S9 only) | Step 4 full suite after amendments 1-3 (`t2-suite-step4.log`): exit 1, CASES 860, CHECKS 144276, FAILURES 4: the three S8 labels and the S9 `status counts` label; nothing else. First attempt (no null guard, no amendments 2-3) had 16 failures from `_result_text(null)` SCRIPT ERRORs, then S2 (7 labels), S3 "rejection did not consume sequence" and RF6 once the guard was in; the user approved the fixes 2026-11-14 |
| Task 2: bot needed `add_player(2, 0)` on a fixture world (yes / no) | no (a second player made `Bs1 authored economy` fail on `players.size() == 1` and still left the null match; reverted) |
| Task 2: mutations (G26 Ctrl, Bs3 building select) fail the ported check | G26: `main.gd:191` `and not _ctrl` dropped: exit 1, `G26 Ctrl double click is a plain click`; reverted. Bs3 as written (`base_main.gd:220` `selected_ids.clear()` deleted): filtered `test_base_scene` exit 0, NOT red there (the check starts with `selected_ids` empty); the full suite catches it only through `IC1 row 11` (Task 1 characterisation). Substitute mutation `base_main.gd:219` `selected_building_id = building.id` deleted: filtered exit 1, `Bs3 building selection outline`; reverted. `git diff --stat game/scripts` shows only the null guard |
| Task 2: amendments (user, 2026-11-14) | (1) null guard `skirmish_main.gd:282`: kept; carried verbatim by Tasks 5 and 7, told to the Task 11 reviewer. (2) S2/S3 clicks on empty ground (five `test_scene.gd` lines). (3) RF6 warm-up tick (`test_base_scene.gd`, one added line). Step 6 full suite: exit 0, CASES 860, CHECKS 144276, `TESTS PASSED 144276` (equals Task 1); static gates `CHECKS PASSED 5` |
| Task 3: V11 diff equals the demo-only list | Yes. Full suite (`t3-suite.log`): exit 0, CASES 858, CHECKS 144264 (Task 2: 860 / 144276; minus the two S8/S9 cases and 12 checks: 8 S8, 2 S9, 2 SD22 loop iterations), `TESTS PASSED 144264`. `rg -n 'scenes/(main|base)\.tscn' game tools` prints nothing. V11b (`labels-t3.txt`, 3093 lines vs 3070): `diff labels-before labels-t3` removes exactly 11 labels (8 `S8`, 2 `S9`, 1 `"SD22 `) and adds only 34 `IC1`/`IC2` labels. V11 id census: `diff ids-before ids-t3` adds only `IC1 `, `IC2 ` (S8, S9, SD22 stay: other files use them). Static gates `CHECKS PASSED 5`. `v13_check.py --add` for Task 3: 47 removed lines listed (below). `setup(runner, packed = Main)` keeps its unused parameter (Task 5 may drop it with the chain) |

## Driver, screen, orders, HUD (Tasks 4-7)

| Item | Value |
|---|---|
| Task 4: OD1, OD2 red against stubs, then green | red: stub drivers, `t4-red.log` exit 1, `FAIL: OD1 …` and `FAIL: OD2 …`, `CASES 2 CHECKS 2 FAILURES 2`; green: `t4-green-od.log` exit 0, `CASES 2 CHECKS 2 FAILURES 0` (OD2 steps the bare simulation to `Skirmish.ATTACK_TICK` first, because the bot only touches its memory from that tick on) |
| Task 4: rename `$L/t4-rename.log` count lines (paste), exit | exit 0, see the Simulation census section (dry run `t4-rename-dry.log` identical); `rename-t4.done` written |
| Task 4: pre-tree scan after the rename: exit, lines | exit 0, no `PRE-TREE`; `NO-TREE` `test_online_scene.gd:319` (N5) and `test_view.gd:99`; the third (`test_skirmish.gd` SK23) is gone because SK23 now builds a driver, not a screen |
| Task 4: SK23 lines changed: `starts` right-hand side → `MatchSettings.starts("ashfall", 7)` (statics no longer set); `main.free()` removed (`RefCounted`); static save and restore removed (the driver does not read the statics) | done; `const SkirmishMain` in `test_skirmish.gd` stays (now unused; removing it would add a `-const` line outside V8's list) |
| Task 4: netplay match terminal tick | 9129, `NETPLAY PASSED match 16.5 s`, exit 0 (`t4-match.log`) |
| Task 5: `rg -n '^extends "res://scripts/' game/scripts` before / after | before: 3 lines (`base_main.gd:1`, `skirmish_main.gd:1`, `online_main.gd:1`, seen with `rg` before the deletion); after: no output (rg exit 1). `rg -n 'scripts/(main|base_main|skirmish_main|online_main)\.gd|scenes/(main|base|online_skirmish)\.tscn' game tools .github` prints nothing (docs and guide mentions are Task 8) |
| Task 5: IC1, IC2 unchanged | yes: filtered `test_input_script` exit 0, `CASES 2 CHECKS 34 FAILURES 0`, rows file untouched (`git diff f1c6b78 -- game/tests/input_script_rows.gd` empty). Scene suites filtered, all exit 0 and 0 failures: test_scene 14/120, test_base_scene 15/139, test_skirmish_scene 29/173, test_online_scene 32/3692, test_pause_menu 8/332, test_playtest_overlay 18/651, test_perf_overlay 6/13, test_view 61/307 (cases/checks). Full suite with traces (`t5-suite.log`): exit 0, `CASES 860 CHECKS 144273 FAILURES 0`, `TESTS PASSED 144273` (HUD layout tests included, no `FAIL`); replay, economy, combat, team traces `cmp` exit 0; `run_checks.sh` `CHECKS PASSED 5`; netplay match tick 9129 `NETPLAY PASSED match`; pre-tree scan exit 0, `NO-TREE` `test_online_scene.gd:319` and `test_view.gd:99` (unchanged); V11 id census diff vs Task 4 empty; V11b labels diff vs Task 4 empty; V12 diff empty; V8 `-const` lines are only preload lines; V13 OK (removed=275 renamed=188 listed=87) |
| Task 6: OR1 red, then green; rename script counts asserted | red against the stub (`orders.gd` with a no-op `handle`, `t6-red.log`): exit 1, `FAIL: OR1 orders own the selection and emit the move payload`, `CASES 1 CHECKS 1 FAILURES 1`; green (`t6-green-or.log`): exit 0, `CASES 1 CHECKS 1 FAILURES 0`. Recount on this tree (per-file occurrences, `rg -o`): `test_base_scene.gd` 28 (+3 `is_selecting(`), `test_online_scene.gd` 18, `test_pause_menu.gd` 9, `test_playtest_overlay.gd` 9, `test_playtest_replay.gd` 1, `test_scene.gd` 18, `test_skirmish_scene.gd` 98, `test_view.gd` 2 (+2 `_view_selection(`); differences against `35d22b5` only in files Tasks 1-3 edited (IC1 and IC2 add 15 and 14 reads); no other file, no other receiver. Asserted rename (`t6-rename-dry.log`, `t6-rename.log`): every count matched, exit 0, `RENAME OK t6 files=8`, `rename-t6.done` written. Orders members beyond the plan's list: `menu` (was `_menu`, written by `_refresh_menu`, which stays on the screen until Task 7), `_hint_point` and `_menu_choose` (called by the screen's `_show_hint` and the build-menu buttons), `_cancel_entry`/`_cancel_build`/`_produce_selected` (buttons connect to `orders.`); screen members orders calls beyond the plan's list: `_screen._error` (read and written; Task 7 renames), `_screen._inspected(state)` (in `prune`; Task 7 moves it to the HUD). `orders.prune` also holds the `selected_building_id` check that `_refresh` ran before `_show` (R4 neighbour, same state, no reader in between) and the inspected clear that left `_match_hud` (R4). `Construction` preload dropped from the screen (unused). Scene suites filtered, all exit 0 and 0 failures (cases/checks): test_input_script 2/34 (IC1, IC2 unchanged; `git diff f1c6b78 -- game/tests/input_script_rows.gd` empty), test_scene 14/120, test_base_scene 15/139, test_skirmish_scene 30/174, test_online_scene 32/3692, test_pause_menu 8/332, test_playtest_overlay 18/651, test_perf_overlay 6/13, test_view 61/307, test_playtest_replay 8/34, test_order_voice 14/97, test_announcer 20/64, test_sound 24/177. Full suite with traces (`t6-suite.log`): exit 0, `CASES 861 CHECKS 144274 FAILURES 0`, `TESTS PASSED 144274` (HUD layout tests included, no `FAIL`); replay, economy, combat, team traces `cmp` exit 0; `run_checks.sh` `CHECKS PASSED 5` (`t6-checks.log`); netplay match tick 9129 `NETPLAY PASSED match 13.3 s`; pre-tree scan exit 0, `NO-TREE` `test_online_scene.gd:319` and `test_view.gd:99` (unchanged); V11 id census diff vs Task 5: adds exactly `OR1 `; V11b label diff vs Task 5: adds exactly `OR1 orders own the selection and emit the move payload`; V12 diff empty; V10 diff empty; V8 `-const` lines are only preload lines; pins V1-V4, V9 untouched (`git diff` empty for their files); V13 OK (removed=409 renamed=322 listed=87) |
| Task 7: HU1 red, then green; rename script counts asserted | red against the stub (`hud.gd` with a no-op `_refresh_hud`, `t7-red.log`): exit 1, `FAIL: HU1 the HUD shows the selection and keeps the local note`, `CASES 1 CHECKS 2 FAILURES 1`; green (`t7-green-hu.log`): exit 0, `CASES 1 CHECKS 2 FAILURES 0`. HU1 builds a second `Hud` on the scene's `HUD` layer (a barracks selected, Produce hidden first, a player-2 rejection in `stepped_results`) so the stub cannot pass through the screen's own refresh. Recount on this tree: `_error` 40 in 5 files (`test_announcer.gd` 2, `test_base_scene.gd` 6, `test_order_voice.gd` 4, `test_playtest_overlay.gd` 10, `test_skirmish_scene.gd` 18), helpers 11 (`test_base_scene.gd` 2, `test_skirmish_scene.gd` 9); identical to `35d22b5`, no other file or receiver. Asserted rename (`t7-rename-dry.log`, `t7-rename.log`): every count matched, exit 0, `RENAME OK t7 files=5`, `rename-t7.done` written. Hand edit: `test_base_scene.gd` `BaseMain = load(...)` now `hud.gd` (`queue_label` static moved). Screen members the HUD reads beyond the plan's list: `_screen._local_state` (also used by `_production_kind`, stays on the screen). Moved with the HUD: `_build_hint`, `place_economy()` (the `Economy` offset line, called by `_refresh` after `_show` as before); `_status`, `ViewRows` and `View` consts left the screen. `hud` is created in `_ready` right after the `BuildMenu` grid, before the first `_refresh()`; `Produce` and `CancelBuild` signal hookups stay in `_ready` step 3. Orders: `_screen._error` (6) became `_screen.hud.note`, `_screen._inspected` became `_screen.hud._inspected`. Results: IC1, IC2, V9 green (`test_input_script` 2/34, `test_hud_summaries` 1/2); scene suites filtered all exit 0, 0 failures: test_scene 14/120, test_base_scene 15/139, test_skirmish_scene 31/176, test_online_scene 32/3692, test_pause_menu 8/332, test_playtest_overlay 18/651, test_perf_overlay 6/13, test_view 61/307, test_announcer 20/64, test_order_voice 14/97 (cases/checks). Full suite with traces (`t7-suite.log`): exit 0, `CASES 862 CHECKS 144276 FAILURES 0`, `TESTS PASSED 144276` (HUD layout tests included, no `FAIL`); replay, economy, combat, team traces `cmp` exit 0; `run_checks.sh` `CHECKS PASSED 5` (`t7-checks.log`); netplay match tick 9129 `NETPLAY PASSED match` (`t7-match.log`); pre-tree scan exit 0, `NO-TREE` `test_online_scene.gd:319` and `test_view.gd:99` (unchanged); `rg -n '^extends "res://scripts/' game/scripts` empty; V11 id census diff vs Task 6: only `HU1`; V11b label diff vs Task 6: only the `HU1` label added; V12 diff empty; V8 `-const` lines are only preload lines; V13 OK (removed=439 renamed=352 listed=87) |
| Test lines changed other than access paths, ports and deletions (each with its reason) | Task 5: script and scene path preloads repointed (`OnlineScene` in `test_online_scene.gd`, `SkirmishMain` in `test_online_scene.gd`, `test_skirmish.gd`, `test_playtest_replay.gd`; `test_view.gd:99`; `test_base_scene.gd:260`); N5 expected `resource_path` is `res://scripts/match/match_screen.gd` (the plan's one expected-value change); `OnlineScene` const in `test_pause_menu.gd` and `test_playtest_overlay.gd` removed and its use now `Skirmish.instantiate()` (gdlint `duplicated-load` once both consts point at `skirmish.tscn`); `test_scene.gd` `setup(runner, packed = Main)` loses its unused parameter (ledger). Task 4: SK23 (see above); OD1, OD2 added to `cases()` and one `const OfflineDriver` preload; N5 `online.main.MAX_CATCH_UP_CREDIT` becomes `online.main.driver.MAX_CATCH_UP_CREDIT` (the const moved with the lockstep loop; not in the plan's rename tables, found by the filtered `test_online_scene` run) |

## V13 reasons list (copied from `$L/v13-reasons.txt` after each `--add`)

| Task | File | Reason | Removed line (or count, for a whole deleted case) |
|---|---|---|---|
| 1 | `game/tests/test_skirmish_scene.gd` | IC1 added to `cases()` | `return [test_skirmish_ready_and_tick, …, test_hud_summaries_are_pinned]` |
| 1 | `game/tests/test_online_scene.gd` | IC2 added to `cases()` | `return [test_seat_two_controls_player_two, …, test_launcher_reads_no_page_off_web]` |
| 2 | `game/tests/test_base_scene.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `const Base = preload("res://scenes/base.tscn")` |
| 2 | `game/tests/test_pause_menu.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `const Base = preload("res://scenes/base.tscn")` |
| 2 | `game/tests/test_pause_menu.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `main = await _scene(runner, Base)` |
| 2 | `game/tests/test_perf_overlay.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `const Base = preload("res://scenes/base.tscn")` |
| 2 | `game/tests/test_perf_overlay.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `var main = await _scene(runner, Base)` |
| 2 | `game/tests/test_perf_overlay.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `var main = await _scene(runner, Base)` |
| 2 | `game/tests/test_perf_overlay.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `var main = await _scene(runner, Base)` |
| 2 | `game/tests/test_perf_overlay.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `var main = await _scene(runner, Base)` |
| 2 | `game/tests/test_scene.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `const Main = preload("res://scenes/main.tscn")` |
| 2 | `game/tests/test_scene.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `func setup(runner):` |
| 2 | `game/tests/test_scene.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `var main = Main.instantiate()` |
| 2 | `game/tests/test_scene.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `await click(runner, view, Iso.world_to_plane(Vector2(4.5, 3.5)), MOUSE_BUTTON_RIGHT)` |
| 2 | `game/tests/test_scene.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `runner.check(Vector2(cmd.target[0], cmd.target[1]).distance_to(Vector2(4.5, 3.5)) <= 1e-5, "S2 inverse exact target")` |
| 2 | `game/tests/test_scene.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `var target := Vector2(4.25, 3.1)` |
| 2 | `game/tests/test_scene.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `await click(runner, view, Iso.world_to_plane(Vector2(4.5, 3.5)), MOUSE_BUTTON_RIGHT)` |
| 2 | `game/tests/test_scene.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `await click(runner, view, Iso.world_to_plane(Vector2(5.5, 3.5)), MOUSE_BUTTON_RIGHT)` |
| 2 | `game/tests/test_scene.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `var main = await setup(runner)` |
| 2 | `game/tests/test_scene.gd` | port onto skirmish.tscn; S2/S3 clicks on empty ground (amendment 2, user 2026-11-14) | `var main = await setup(runner)` |
| 3 | `game/tests/test_scene.gd` | Task 3: demo-only check deleted | whole cases `test_obstacle_toggle` (S8) and `test_status_counts` (S9), the `const Demo = preload("res://scenes/main.tscn")` line and the two `cases()` entries (one `cases()` line rewritten, the rest deleted; row-by-row in `v13-reasons.txt`) |
| 3 | `game/tests/test_sound.gd` | Task 3: demo-only check deleted | the SD22 demo-scene loop `for path in ["res://scenes/main.tscn", "res://scenes/base.tscn"]:` and its 6 body lines (`:331-337`) |
| 4 | `game/tests/test_skirmish.gd` | SK23 builds an OnlineDriver (starts from MatchSettings, no free, no statics) | 7 lines of `test_desync_report_names_map_seed_starts` (statics save and restore, `OnlineMain.new()`, `main._lockstep =`, `main._report()`, the check line with `SkirmishMain.starts`, `main.free()`) plus `const OnlineMain = preload("res://scripts/online_main.gd")` |
| 4 | `game/tests/test_skirmish_scene.gd` | OD1, OD2 added to `cases()` | `return [test_skirmish_ready_and_tick, …, test_input_script_offline]` |
| 4 | `game/tests/test_online_scene.gd` | N5 reads `MAX_CATCH_UP_CREDIT` from the online driver | `runner.check(tick > 24 and tick <= 24 + online.main.MAX_CATCH_UP_CREDIT, …)` |
| 5 | `game/tests/test_base_scene.gd` | script and scene paths | `var BaseMain = load("res://scripts/base_main.gd")` |
| 5 | `game/tests/test_online_scene.gd` | script and scene paths | `runner.check(offline.get_script().resource_path == "res://scripts/skirmish_main.gd", "N5 Play offline loads the offline skirmish")` |
| 5 | `game/tests/test_scene.gd` | unused packed parameter of setup dropped (ledger) | `var main = packed.instantiate()` |
| 5 | `game/tests/test_scene.gd` | unused packed parameter of setup dropped (ledger) | `if packed == Main: _install_world(main)` |
| 5 | `game/tests/test_view.gd` | script and scene paths | `var main = preload("res://scripts/main.gd").new()` |
| 5 | `game/tests/test_pause_menu.gd` | duplicate scene preload folded into Skirmish (gdlint duplicated-load) | `var main = OnlineScene.instantiate()` |
| 5 | `game/tests/test_playtest_overlay.gd` | duplicate scene preload folded into Skirmish (gdlint duplicated-load) | `var main = OnlineScene.instantiate()` |
| 5 | `game/tests/test_online_scene.gd` | script and scene paths | `const OnlineScene = preload("res://scenes/online_skirmish.tscn")` |
| 5 | `game/tests/test_online_scene.gd` | script and scene paths | `const SkirmishMain = preload("res://scripts/skirmish_main.gd")` |
| 5 | `game/tests/test_pause_menu.gd` | script and scene paths | `const OnlineScene = preload("res://scenes/online_skirmish.tscn")` |
| 5 | `game/tests/test_playtest_overlay.gd` | script and scene paths | `const OnlineScene = preload("res://scenes/online_skirmish.tscn")` |
| 5 | `game/tests/test_playtest_replay.gd` | script and scene paths | `const SkirmishMain = preload("res://scripts/skirmish_main.gd")` |
| 5 | `game/tests/test_scene.gd` | unused packed parameter of setup dropped (ledger) | `func setup(runner, packed = Main):` |
| 5 | `game/tests/test_skirmish.gd` | script and scene paths | `const SkirmishMain = preload("res://scripts/skirmish_main.gd")` |
| 5 | `game/tests/test_pause_menu.gd` | duplicate scene preload folded into Skirmish (gdlint duplicated-load) | `const OnlineScene = preload("res://scenes/online_skirmish.tscn")` |
| 5 | `game/tests/test_playtest_overlay.gd` | duplicate scene preload folded into Skirmish (gdlint duplicated-load) | `const OnlineScene = preload("res://scenes/online_skirmish.tscn")` |
| 6 | `game/tests/test_skirmish_scene.gd` | OR1 added to `cases()` | `return [test_skirmish_ready_and_tick, …, test_offline_driver_bot_memory_on_simulation]` (the Task 4 form; against `main` the Task 1/4 row covers it) |
| 7 | `game/tests/test_base_scene.gd` | `queue_label` moved to the HUD; the test loads `hud.gd` | `var BaseMain = load("res://scripts/match/match_screen.gd")` |
| 7 | `game/tests/test_skirmish_scene.gd` | HU1 added to `cases()`; `Hud` preload added | `return [test_skirmish_ready_and_tick, …, test_orders_turn_input_into_payloads]` (the Task 6 form; against `main` the Task 1/4 row covers it) |
| 10 | `game/tests/test_online_scene.gd` | N27 added to `cases()` | `return [test_seat_two_controls_player_two, …, test_input_script_online]` |

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
| Tree, `uptime` start / end | `one-controller` at `60b6674` (Task 7 commit) plus the uncommitted Task 8 docs diff; `game/` identical to that commit. Suite 10:19 load 2.58 / 2.29 / 2.74 at end; benchmark `uptime` 1.56 / 2.07 / 2.58 at start (10:21), 1.93 / 2.09 / 2.57 at end; no godot or generalszh process before it |
| Full suite: CASES, CHECKS, exit; traces `cmp` | on the final tree with the four traces: `CASES 862 CHECKS 144276 FAILURES 0`, exit 0, `TESTS PASSED 144276` (includes the HUD layout tests; no `FAIL` line); `cmp` against `*-before.tsv` exit 0 for `replay`, `economy`, `combat`, `team` |
| `run_checks.sh` marker | exit 0, `CHECKS PASSED 5` (run again after the performance ledger row below; see the evidence row) |
| Netplay `match` (tick), `perturb`, `relay-down`, `relay-term` | `match terminal tick 9129`, `NETPLAY PASSED match 11.2 s`; `perturb` 2.2 s, `relay-down` 2.6 s, `relay-term` 3.2 s; all exit 0 |
| Conformance | exit 0, `CONFORMANCE PASSED 41` |
| Team match line | exit 0, `TEAM MATCH won tick=39497 winner=2 units_peak=271` (V7) |
| Benchmark markers; `BUDGET EXCEEDED` line; ledger row recorded | `PERF_LABEL="One controller" sh tools/run_benchmark.sh` exit 0: `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1` (p99 0.068 ms), `recorded 13 rows, run 1`; last line `BUDGET EXCEEDED open dense hordes300 (regression ceilings held)` (the accepted line); OVER BUDGET open 1.895 / 2.285, dense 1.867 / 2.210, hordes300 2.911 / 3.439. `perf-history.csv` and the `performance.md` / `README.md` generated blocks recorded by the script; History row added by hand. No rendered rerun (Decision 14) |
| `roadmap.py --check`, `check_public.sh` | `roadmap.py` exit 0 (no README change), `--check` exit 0; `PUBLIC CHECK PASSED` |

## Fixes after the gate (Tasks 9, 10; Decision 17)

Both quirks were found by reading on `4ed3534` and are unchanged on `35d22b5`:

- F3 does nothing while a placement is active: the placement branch returns before the selection handler that toggles the overlay (`base_main.gd:195-206`, `main.gd:141-142`).
- An online frame that advances two ticks hands only the last tick's command results to the HUD (`main.gd:112-113` appends once per frame; `online_main.gd:54-59` may advance twice; `base_main.gd:74` reads `stepped_results + state.command_results`). Issue-time rejections reach the HUD per tick through `Lockstep.rejections()` (`online_main.gd:60-65`), so only a due-time result on the earlier tick can be lost; not run yet.

| Item | Value |
|---|---|
| Task 9: PO19 red on the Task 8 tree (failing line) | `WARGRID_TEST_ONLY=test_f3_toggles_during_placement`, exit 1, `FAIL: PO19 F3 toggles the overlay during placement and keeps the placement`, `CASES 1 CHECKS 3 FAILURES 1` (`t9-red.log`; the "placement is active" check passed) |
| Task 9: PO19 green; IC1 (and IC2) re-pin diff only `perf=false` → `perf=true` from the F3 row on (`$L/t9-repin.diff`, check script exit) | fix: `orders.gd` `_placement_input` first lines toggle `_screen._perf` on F3 and return; PO19 green `CASES 1 CHECKS 3 FAILURES 0`. IC2 ran step 10, so both re-pinned: 12 IC1 rows (steps 10-21) + 4 IC2 rows (10, 11, 17, 18); `t9_repin_check.py` exit 0, `REPIN OK rows=16`; `test_input_script_offline` 21 checks and `test_input_script_online` 13 checks green after the re-pin. Before the re-pin the old rows fail at step 10 only (expected) |
| Task 9: commits (fix, then re-pin) | not yet made; coordinator makes two: (1) `orders.gd`, `test_perf_overlay.gd`, guide ch. 5, this file; (2) `game/tests/input_script_rows.gd` alone (V10's new base) |
| Task 9: suite, traces `cmp`, netplay match, static gates | full suite with the four traces exit 0, `CASES 863 CHECKS 144279 FAILURES 0`, `TESTS PASSED 144279` (+1 case, +3 checks = PO19; HUD layout tests included); `cmp` against `*-before.tsv` exit 0 for `replay`, `economy`, `combat`, `team`; `NETPLAY PASSED match 13.1 s`, `match terminal tick 9129`; `run_checks.sh` exit 0, `CHECKS PASSED 5`; V12 diff empty; V11 666 ids (+`PO19 `); V11b 3100 lines (+3 PO19 labels only); V13 `V13 OK removed=440 renamed=352 listed=88` (the added reason: PO19 in `cases()`). Logs `t9-*.log` |
| Task 10: characterisation outcome (a) lost / (b) not lost, guard only / (c) blocked; how the case was built | (a) lost. N27 on `_online(runner, 1)`, default skirmish world, no swap: two identical `build` orders (builder 3, `usa_power_plant`, origin 10,10) submitted before the first frame go out in the tick-5 packet; both pass issue validation, the second fails at due time in `Construction.place` (`Footprint outside map or overlaps obstacle`). Control: peer packets from the start, 6 one-tick frames, status shows the error. Case: 10 stalled frames (credit banked at tick 4), packets for tick 4 only, one frame (tick 4 to 5, stalls), packets 5..60, one frame advances ticks 5 and 6 (tick 7): the error is on tick 5, the earlier tick |
| Task 10: N27 red (failing line) or "guard only" | `WARGRID_TEST_ONLY=test_two_tick_frame` on the Task 9 tree, exit 1, `FAIL: N27 a two-tick frame keeps the earlier tick's own rejection`, `CASES 1 CHECKS 3 FAILURES 1` (`t10-char.log`; control and fixture checks passed) |
| Task 10: N27 green; IC1, IC2, catch-up and restart cases; suite, traces `cmp`, netplay match, static gates | fix: `step_results()` on both drivers (offline: `sim.command_results().duplicate(true)`; online: cleared at the start of `step`, appended after every advanced tick), screen appends `driver.step_results()` when advanced. N27 `CASES 1 CHECKS 3 FAILURES 0` (`t10-green.log`). Full suite with the four traces exit 0, `CASES 864 CHECKS 144282 FAILURES 0`, `TESTS PASSED 144282` (+1 case, +3 checks = N27; IC1, IC2, catch-up, restart, stall cases and HUD layout tests included); `cmp` exit 0 for `replay`, `economy`, `combat`, `team`; `NETPLAY PASSED match 15.9 s`, `match terminal tick 9129`; `run_checks.sh` exit 0 `CHECKS PASSED 5`; `roadmap.py --check` and `check_public.sh` exit 0. Logs `t10-*.log` |

## Review (Task 11)

| Item | Value |
|---|---|
| 11a reviewer findings: critical / important / minor (count), each with its line | 0 / 0 / 7, listed under "11a findings" below. Fresh Opus reviewer, `git diff 74950e5..HEAD` on `one-controller` at `5739a40` (tree clean before and after; three scratch mutations reverted, `git status --short` empty) |
| Per new test and ported family: production change that would make it fail | see "11a mutation map" below; three run on `5739a40` (N27, placement guard, R4 prune), the rest from the task records or by reading |
| 11b fix round: each finding, red line, green; suite, traces `cmp`, netplay match, static gates, V11b, V13 | |
| 11c `/ponytail-review` cuts and re-verify | |
| Minors for the morning | m1-m7 below (m1 needs a ruling, no code change recommended) |

### 11a findings

No Critical, no Important finding. Minor:

- **m1, online submit: R1 is more than a move** (`game/scripts/match/match_screen.gd:271-278`). The pinned shared `_submit` makes online `observe_command` conditional on `hud.note` being empty after `_refresh()`, and lets online play `_sound.rejected(hud.note)`; `online_main.gd:77-83` always observed and never queued a rejection cue. Scenario: an own due-time rejection lands in a step whose refresh the presentation clock defers to the next rendered frame (`presentation_clock.gd:20-27`); a click in that window makes the submit's `_refresh` consume it, so the online submit queues an `error` cue and skips the focus-card trigger for that command. Offline has always behaved this way (`skirmish_main.gd:91-95` on `main`). Evidence: reading only; no test covers it. Impact: one stray cue and one unticked checklist trigger, rare, presentation only, no simulation or trace effect. Fix: record it as R5 (offline semantics now apply online) in the plan's Accepted reorders; no code change.
- **m2, online desync report fields lost end-to-end coverage** (`game/tests/test_skirmish.gd:693-698`, `game/scripts/match/online_driver.gd:33-36`, `match_screen.gd:126-127`). SK23 now feeds `create` its values directly, so the screen-statics-to-report path is untested: a mutation `_seed = 0` in `online_driver.create` would pass every test (wrong starts or map would still fail the match tests through `Skirmish.create`; the seed is read only by `_report`). Fix: in N2's desync case (`test_online_scene.gd:131-137`) parse `user://desync/desync-seat2.json` and check `seed`, `map`, `starts` against `SkirmishMain` statics before removing it.
- **m3, leftovers for 11c** (dead or one-use indirection): `test_skirmish.gd:18` `const SkirmishMain` unused (kept for V8, ledger); `hud.gd:77-78` `_build_hint()` returns a constant (the old M3 override hook); `match_screen.gd:151-155` `_confirm_leave` and `_pauses_sim` only forward to the driver; `online_driver.gd:28` `_seat` parameter unused. None changes behaviour.
- **m4, profiler zone content shifted** (`match_screen.gd:258-260`, `orders.gd:63-66`): `refresh.selection` now also times the building-id prune and the `hud._inspected` lookup that used to sit in `_refresh` and `refresh.hud`. Names and places kept as pinned; no tool or budget reads these zones (`rg 'refresh\.selection|refresh\.hud' game tools docs` hits only the screen and the plan). Note for anyone comparing old profiles.
- **m5, guide footers name commits before the code they describe**: ch. 5 `docs/guide/05-presentation.md:228` says `eafb131`, but the F3-in-placement line describes `1e3b9f7`; ch. 11 `docs/guide/11-multiplayer.md:221` says `71b1180`, but the "every advanced tick's command results" clause describes `5739a40`. Fix: set both to the branch head at wrap-up.
- **m6, stale paths in working docs**: this file's "Unverifiable at night" cites `online_main.gd:97-99` (now `online_driver.gd:108-110`); `docs/packages.md` One controller note still says "Today `online_main.gd` extends …", true only until the merge. Fix at merge or wrap-up.
- **m7, values captured at create instead of read at use** (`offline_driver.gd:14-21`, `online_driver.gd:33-36`): the offline driver stamps `_player` from `local_player` at `_ready` and logs `_factions` from `create`; the online report uses the `create` arguments, not the statics at report time. Equal today: nothing writes `local_player` after `setup`/`_ready` (`rg 'local_player\s*=' game/scripts game/tests`: only `match_screen.gd:57`, `:85`) and the launcher sets statics before the scene starts. A future offline seat switch would have to rebuild the driver.

Rulings and deviations judged:

- **Null guard** (`hud.gd:68`): acceptable. Production worlds always carry a match (`Skirmish.create`); the guard only turns a future null match into a blank Result label in the HUD. `_match_record` (`match_screen.gd:139`) still calls `hud._result_text(state.match)` unguarded, so the playtest record would still raise on a null match; consistent with "production never null".
- **S2/S3 retargeted clicks, RF6 warm-up tick** (user, 2026-11-14): sound. The M2 scene had no context orders and no bot; on the match scene a right-click on an own Scout Car is an `enter` order and the bot snapshots on tick 0. Every assertion and label is kept; only click points and one warm-up `_physics_process` line differ.
- **Bs3 mutation note**: confirmed by reading: Bs3 starts with `selected_ids` empty, so deleting the building-select `selected_ids.clear()` (`orders.gd:154`) is caught only by IC1 (first difference at step 12, `sel=[]|bld=12`). Acceptable: the full suite is the gate.
- **Task 4 N5/SK23 edits**: N5 `driver.MAX_CATCH_UP_CREDIT` is an access path. SK23's new right-hand side equals the old value (the old test set `SkirmishMain.starts` to the same `MatchSettings.starts("ashfall", 7)`); coverage loss is m2.
- **Task 5 `_refresh_hud` split and removed `OnlineScene` consts**: statements match `base_main.gd:73-89` plus `skirmish_main.gd:279-290` minus the moved prune (R4) and `_sound.update` (R3); the two test files still call `setup(...)` right after `Skirmish.instantiate()` (`test_pause_menu.gd:61-63`, `test_playtest_overlay.gd:73-75`), so they still run the online driver.
- **Task 6 `orders.prune` holds the building-id prune and inspected clear**: the building-id prune moved from `_refresh` before `_show` into `_show` before the selection prune; nothing between reads `selected_building_id` (`_shown_note`, perf counts, split share). Exact.
- **Task 7 HUD reads `_screen._local_state`**: harmless; the helper stays on the screen for `_production_kind`.

Accepted reorders, verdict: **R1** holds as written, plus m1. **R2** exact: `_new_rejections` only reads `Lockstep.rejections()` and advances `_rejections_seen`; `_finish` reads neither the note nor the sound. **R3** exact: `_sound.update(state)` is the last line of `hud._refresh_hud` (`hud.gd:47`), after the notice line and the Restart hide; nothing in between reads the sound player. **R4** exact (see Task 6 ruling above): `_view.set_view` and `_economy_hud` do not read `inspected_id`; `set_inspected` stays in `_match_hud`.

### 11a mutation map

| Test or family | Production mutation that fails it | Evidence |
|---|---|---|
| IC1 | delete `selected_ids.clear()` in building select (`orders.gd:154`); any reorder of `_combat_input`/`_economy_keys`/`_placement_input`/`_building_input` that changes a key or click outcome in the 21 steps | Task 2 run (first difference at step 12) |
| IC2 | `online_driver.submit` calls `sim.issue_command` instead of `_lockstep.submit` (pending and sent rows change) | reading |
| OD1 | `offline_driver.gd:49` `_sequence += 1` without `if result.ok` (second stop gets sequence 2) | reading |
| OD2 | `Skirmish.issue_opponent(self)` in `offline_driver.step` (memory keyed on the driver, then no `issue_command`) | reading; stub red recorded in Task 4 |
| OR1 | `orders.handle` not reaching `_selection_input` or `_move` sending other ids or target | stub red recorded in Task 6 |
| HU1 | drop `result.player == _screen.local_player` in `hud.gd:51` (note becomes "Not yours"), or drop the `_produce.visible` line | reading; stub red recorded in Task 7 |
| PO19 | delete the F3 branch in `orders.gd:126-128` | red on the Task 8 tree (Task 9 record) |
| N27 | `online_driver.gd:61` `_step_results = sim.command_results().duplicate(true)` (last tick only) | **run 2026-11-14 on `5739a40`**: `WARGRID_TEST_ONLY=test_two_tick_frame` exit 1, `FAIL: N27 a two-tick frame keeps the earlier tick's own rejection` (`t11a-mut-n27.log`); reverted |
| K3 (placement guard) | `orders.gd:34` without `_placement_kind.is_empty() and` | **run**: full suite exit 1, only `FAIL: K3 placement mode consumes controls first`, `CASES 864 CHECKS 144275 FAILURES 1` (`t11a-mut-guard.log`); reverted. IC1 alone would not catch it (no A/S/right-click on an enemy during placement) |
| E1 (R4 prune) | delete `orders.gd:66` inspected clear | **run**: full suite exit 1, only `FAIL: E1 dead enemy clears inspection`, `CASES 864 CHECKS 144275 FAILURES 1` (`t11a-mut-r4.log`); reverted |
| S | `orders._selection_input` right-click target without `Iso.plane_to_world` (S2 inverse exact target) | reading |
| Bs | delete `selected_building_id = building.id` (`orders.gd:153`) | Task 2 substitute mutation red |
| G26 | drop `and not _ctrl` (`orders.gd:211`) | Task 2 red (on the chain) |
| PO (playtest) | `menu_open` without `_playtest.holds_match()` (PO1 tick frozen while the note is open) | reading |

The two full-suite mutation runs each failed exactly one check out of 144276 at `CASES 864`, so the unmutated tree is green apart from the mutated line (the Task 10 record shows the full green run).

### 11a verified clean

- No script under `game/scripts` extends another controller (`rg -n '^extends "res://scripts/' game/scripts`: no output). V12 diff (`simulation`, `presentation`, `net`, `playtest`, `project.godot`) empty. V8: every removed test `const` is a preload. V13 `V13 OK removed=440 renamed=352 listed=88` (`t11a-v13.log`); every listed row read: ports, demo deletions, SK23, path repoints, `cases()` lines; no changed expectation outside the plan's lists. Pre-tree scan exit 0 (`NO-TREE` N5 offline launch and `test_view.gd:99` V4 only).
- Task 9 re-pin (`71b1180`): with `perf=` masked, the 16 removed and 16 added rows are byte-identical (IC1 steps 10-21, IC2 steps 10, 11, 17, 18); `git diff 71b1180..HEAD -- game/tests/input_script_rows.gd` empty.
- Dispatch (`orders.handle`) equals the chain for key, motion, left, right and wheel in none, dragging, attack-move, placement, building selected and match over: guard, deselect clears inspected, combat only outside placement, hover, economy keys (B swallowed), placement returns, building input, selection, pending placement; the M2 B branch was unreachable and is gone. `_finish_selection`, `_enter_placement`, `pan_camera`/`change_zoom` (`orders.busy()`), `_escape_pending`, `_leave`, `_restart`, `playtest_context`, `_hint_point`, `_production_kind`, `_input` match the pinned merges.
- `_ready` order matches the pinned list (driver, theme and BuildMenu, `Hud.new`, perf, pause, view settings, `_create_world`, clock, camera, first refresh, Produce/Cancel, visuals, auto pick, Restart, music, playtest, `net_line`, `driver.start()`). `setup` runs before `add_child` in the launcher (`launcher.gd:239-241`) and every online test helper.
- Lifecycle: `orders` (member initializer) and `hud` live as long as the screen and are never replaced (`rg '\.orders = |\.hud = |\.driver = '`: none), so button callables bound to `orders` stay valid across restart; the back-references are plain `Node` fields on `RefCounted` objects, no cycle. `_exit_tree` → `driver.detach()` (offline no-op, online clears `send`).
- Determinism: the driver path reads wall-clock time only in `_transport.silent(Time.get_ticks_usec())`, as before; the Task 10 append reads `sim.command_results()` after `advance`, never writes simulation or lockstep state; no unordered iteration feeds the simulation. Offline `step_results()` is the old `command_results().duplicate(true)` expression, so offline frames hand the HUD the same array.
- The bot gets the recorder (`offline_driver.gd:32`), never the driver; `recorder.simulation()` still exposed.
- Scenes: old `online_skirmish.tscn` differed from `skirmish.tscn` only in the script path and the root node name (`OnlineSkirmish`); nothing references either name (`rg 'OnlineSkirmish|online_skirmish'`: no hit in game, tools, guide, relay, protocol, `.github`).
- Review focus 5: a new order needs `orders.gd` (input branch, payload, mode reset in `reset()`/`escape_pending()`, `_hint_point`) and the hint line in `hud.gd:72`; nothing else.
- Guide: the touched chapters' call chains (`orders.handle → _combat_input → _building_input → _selection_input`, `_step_frame → _step_simulation → driver.step`, `hud._refresh_hud → SoundPlayer.update`) match the code; only the footers in m5 lag.

## Unverifiable at night (for the morning)

- CI on Linux and Windows, `sh tools/compare_local_traces.sh <run id>` for macOS: need a pushed branch (push needs approval).
- Browser: the web desync download path (`online_main.gd:97-99`, then the online driver) and the web build of the match screen; covered only by the fake `download` callable in `test_online_scene.gd:140-141`.
- The attended offline and online match in a window, before P2.3a starts (user, 2026-11-13).
- Rendered benchmark: skipped (Decision 14); `movement_benchmark.tscn` does not load the controller.
- Commands the night permissions refused, each with its exact text: none in Task 8.
- The null guard in `hud.gd` `_match_hud` (`var result: String = "" if state.match == null else _result_text(state.match)`, ruling 2026-11-14) turns a future null-match bug into a blank Result label instead of a script error; for the Task 11 reviewer.
- Guide chapters 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 13 and the guide README were re-pointed to the match screen, `driver`, `orders` and `hud`; their `Checked against` footers now read `60b6674`, which is the Task 7 commit the claims were verified against (code read, no chapter re-measured). Tasks 9 and 10 refresh ch. 5 and ch. 11 again.

## Evidence rows (append-only)

- 2026-11-13 night, plan writing (backup 1 of the Sim quick wins run), tree `~/projects/wargrid` `main` `4ed3534` clean, read-only (no suite, no Godot run). Read: `AGENTS.md`; the handoff's BACKUPS item 1; `docs/packages.md` `:39`, `:84`; design answers "Main branch audit" and "Package review, second pass"; audit FIX-6, A-1 and the verification checklist; `docs/milestone-prompt.md`; `docs/night-run.md` Start and Coordinator rules; `docs/reference/determinism-rules.md`; the Sim quick wins plan and verification file (format). Code read in full: `main.gd` (299 lines), `base_main.gd` (294), `skirmish_main.gd` (290), `online_main.gd` (152), `net/seat_sim.gd`, `playtest/command_recorder.gd`, the four scene files. Anchors checked with `rg -n` on `4ed3534`, among them: chain `extends` lines (`base_main.gd:1`, `skirmish_main.gd:1`, `online_main.gd:1`; no other script under `game/scripts` extends a script by path); `main.gd` `_ready` `:41`, `_input` `:95`, `_physics_process` `:105`, `_unhandled_input` `:140`, `_finish_selection` `:182`, `_toggle_obstacle` `:217`, `_show` `:237`, `_create_simulation` `:250`, `_submit` `:286`; `base_main.gd` `_ready` `:17`, `_refresh` `:67`, `_refresh_hud` `:73`, `_enter_placement` `:152`, `_unhandled_input` `:177`; `skirmish_main.gd` statics `:27-30`, `_recording` `:60`, `_step_simulation` `:81`, `_submit` `:91`, `_restart` `:149`, `_unhandled_input` `:193`, `_refresh_hud` `:278`; `online_main.gd` `setup` `:19`, `_step_simulation` `:50`, `_submit` `:77`, `_report` `:108`, `notice` `:136`; `launcher.gd` `:6`, `:11`, `:19`, `:239-240`; `headless_client.gd:167` (`SeatSim`); `skirmish.gd:161-163` (bot memory via `has_method("simulation")`); `simulation.gd:160-164` (commands rebuilt in a fixed key order); pins V1-V7 at the lines in the plan. Findings: (1) `test_base_scene.gd` is also a helper module (`key`, `pointer`, `hover` used 100+ times from `test_skirmish_scene.gd`), so it keeps its name; `test_scene.gd` and `test_skirmish_scene.gd` are on the boundary allowlist (`tools/test_sim_boundary.py:30`, `:32`), so no test file is renamed; (2) the demo worlds can be rebuilt as fixtures inside the match scene, so only S8 and S9 need the demos; (3) the skirmish HUD reads `state.players[0]` (`base_main.gd:57-60`), so the M2 fixture needs a player record; (4) the real online scene never runs a bot, so `seat_sim.gd` is the headless client's adapter, not the online driver's (plan Question 4); (5) the bot keys its memory through `has_method("simulation")`, so no driver may be passed to `Skirmish`; (6) four order changes are needed to merge the chain without split HUD calls (R1-R4), each independent by reading. Not verified: every ported check on `skirmish.tscn` (Task 2 runs them), whether the bot tolerates a world without player 2, which IC1 steps the online start world supports, and the line numbers in guide chapters 4, 10 and 11 after Sim quick wins.
- 2026-11-14, plan refinement after the kickoff questionnaire, tree `~/projects/wargrid` `main` `35d22b5` clean, docs only (no suite, no Godot run). Read: `AGENTS.md`, `docs/night-run.md` Coordinator rules, `docs/milestone-prompt.md` stop conditions, the draft plan with its "Answers (user, 2026-11-14)", the Sim quick wins plan and verification file (format); the four controller scripts in full; `lockstep.gd` `advance` and `desync_report`, `simulation.gd` `issue_command` and the due-command loop, `tools/test_sim_boundary.py`, `tools/run_tests.sh`, `tools/check_public.sh`. Diff `4ed3534..35d22b5` on `game/`: the controller scripts changed only at `online_main.gd:109` (`desync_report(simulation)`); tests changed only in `test_combat.gd`, `test_defences.gd`, `test_lockstep.gd` and `test_playtest_replay.gd` (one case appended). Anchors: every explicit `file:line` in the plan compared between both trees and re-read on `35d22b5`; drifted and fixed: `simulation.gd:160-164` → `issue_command` `:159`, `normalized` `:164-168`; `docs/development.md:50` → `:52` (was the section heading); guide ch. 4 `:33`/`:68`/`:157-159`/`:176` → `:34`/`:69`/`:160-162`/`:179`, ch. 10 `:81`/`:138`/`:160` → `:82`/`:143`/`:166`, ch. 13 footer `:239` → `:246`; added `test_pause_menu.gd:4` (Base preload, Task 2), `test_online_scene.gd:318` (N5 path, Task 5), guide ch. 1 `:37`, `:45`, `:92-94`, ch. 2 `:114`, ch. 4 `:62`, `:64`, ch. 5 `:9`, `:153`, `:156`, README footer `:117`. Counts verified on `35d22b5`: simulation census above (212 / 194 / 24; 205 renamed in 11 files; production 55); member census as in the draft; free check ids `IC1`, `IC2`, `OD1`, `OD2`, `OR1`, `HU1`, `PO19`, `N27`. Scripts run read-only against the tree: the plan's pre-tree scan (exit 0, three `NO-TREE` lines, no `PRE-TREE`; a planted pre-tree read is caught) and the Task 4 rename script in `--dry` mode with the `35d22b5` counts (`RENAME OK`), and for real on a scratch copy (260 `driver.sim` after, no old match left). Not verified: whether an own due-time rejection can be built in a two-tick online frame (Task 10 Step 1 decides), the Task 2 ports on `skirmish.tscn`, and IC2's step set.
- 2026-11-14, readiness review fixes (fresh Opus review: READY AFTER FIXES), tree `main` `35d22b5`, docs only. Applied findings 1, 3-8, 10-14, 16, 17 after checking each against `35d22b5`; 2 and 9 as the coordinator directed; 15 is in the settings copy. Run scripts written to the logs folder from the plan text (byte-identical, checked). Tested outside the repository on a scratch git copy of `game/tests` and `game/scripts`: `rename.py t4` with the `35d22b5` counts (`RENAME OK t4 files=15`), then `v13_check.py` (`V13 OK removed=197 renamed=197 listed=0`; a hand edit of N5 is `UNEXPLAINED` until `--add` lists it, then `V13 OK`; an unlisted V4 edit fails); `rename.py t6`/`t7` dry runs confirm the per-file counts in the rules comments; `pretree.py` exit 0 with three `NO-TREE` lines; label census 3070 lines, of which the demo set is 8 S8, 2 S9, 1 SD22.
- 2026-11-14 night, Task 0 baseline (Sonnet subagent), worktree `one-controller` at `74950e5` (game/ identical to `35d22b5`), load 2.2 to 2.4. Import exit 0; full suite with traces exit 0, 55 s, `CASES 858 CHECKS 144249 FAILURES 0`, `TESTS PASSED 144249`; traces 1200/1200/1200/100 lines; pins and censuses as in the tables above, no drift, no stop condition. Logs in `~/projects/wargrid-overnight-work/one-controller/logs/` (`t0-suite.log`, `t0-import.log`, `t0-pretree.log`, `ids-before.txt`, `labels-before.txt`, `census-before.txt`, `sim-census-before.txt`). Not run in Task 0: lint, warnings, netplay, benchmark.
- 2026-11-14 night, Task 1 characterisation (Sonnet subagent), worktree `one-controller` at `05d0794`, `game/scripts` untouched. New: `game/tests/input_script_rows.gd` (`IC1_ROWS` 21 lines, `IC2_ROWS` 11 lines), `test_input_script_offline` in `test_skirmish_scene.gd` (helpers `_ic_row`, `_ic_esc`, `_ic_click`, `_ic_box`, `_ic_world`, `_ic_first_difference`), `test_input_script_online` in `test_online_scene.gd` (helpers `_ic_row`, `_ic_esc`, `_ic_plane`, `_ic_first_difference`; it preloads `test_base_scene.gd` for the `key`/`pointer` helpers and sits above `test_launcher_reads_no_page_off_web` so the pre-tree scan output stays the same). IC1 world: own builder is an `frc_builder` (it collects, so the pile step gathers), two `usa_tank`, an `frc_rifle_infantry`, completed `usa_barracks`, unfinished `usa_power_plant` (completed set false), completed `frc_defence` hub with one occupant, one supply pile, enemy `usa_tank`. IC2 ran on seat 1 with the peer packets for ticks 4-200 queued up front; its commands start at sequence 1 (the faction choice is 0). Results: filtered run exit 0 `CASES 2 CHECKS 34`; mutations (a) and (b) red as in the table, reverted; full suite exit 0 `CASES 860 CHECKS 144276 FAILURES 0`, `TESTS PASSED 144276`; `sh tools/run_checks.sh` exit 0 `CHECKS PASSED 5` (lint, warnings, Python, shell, public); `v13_check.py` `V13 OK removed=2 renamed=0 listed=2`. Not run in Task 1: traces comparison (no `game/scripts` change), netplay, benchmark. Logs `t1-*.log` in the logs folder.
- 2026-11-14 night, Task 3 demo deletion (Sonnet subagent), worktree `one-controller` at `0437bdf`. `git rm game/scenes/main.tscn game/scenes/base.tscn`; `test_scene.gd`: S8 and S9 cases, their `cases()` entries and `const Demo` removed; `test_sound.gd`: SD22 demo loop removed. Full suite exit 0, `CASES 858 CHECKS 144264 FAILURES 0`, `TESTS PASSED 144264` (includes the HUD layout tests; no `FAIL` line); `sh tools/run_checks.sh` exit 0, `CHECKS PASSED 5`; V11, V11b and V13 add as in the table above. `game/scripts` untouched. Not run in Task 3: traces comparison (no `game/scripts` change), netplay, benchmark. Logs `t3-*.log`, `labels-t3.txt`, `ids-t3.txt` in the logs folder.
- 2026-11-14 night, Task 4 driver extraction (Sonnet subagent), worktree `one-controller` at `1fc380c`, host load 2.7 to 3.3 (another run's godot processes were active). New: `game/scripts/match/offline_driver.gd`, `online_driver.gd`; OD1, OD2 in `test_skirmish_scene.gd` (red against stubs, then green). Chain wired to the drivers as in Pinned shapes (`_create_world`, pinned `_submit` and `_step_simulation`; online `_ready`/`_leave`/`_exit_tree`/`_note`/`_refresh_hud` call the driver); dead consts `CommandRecorder` and `Lockstep` dropped from `skirmish_main.gd`. Rename `t4` asserted counts matched the `rg` recount. Full suite with traces exit 0, 54 s, `CASES 860 CHECKS 144273 FAILURES 0` (HEAD 4-shard 144264; the +9 is a shard-assignment effect of two added cases, with `WARGRID_TEST_SHARDS=1` HEAD 144264 and now 144266 = +2, and per-file filtered counts equal HEAD except the two OD checks); four traces `cmp` exit 0; `sh tools/run_checks.sh` `CHECKS PASSED 5`; `sh tools/run_netplay.sh match` tick 9129; V12 diff empty; V13 OK. Not run: benchmarks (Task 8), rendered checks.
- 2026-11-14 night, Task 8 docs and package gate (Sonnet subagent), worktree `one-controller` at `60b6674` plus the uncommitted docs diff; `game/` untouched. Guide chapters 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 13 and the guide README now describe one match screen (`match_screen.gd`) with the offline or online driver, `orders.gd` and `hud.gd`; each claim read against `game/scripts/match/` (launcher `setup` path, `_ready` driver choice, `orders.handle` order, `hud._refresh_hud`, `offline_driver._recording`, `online_driver.step`). Notes: `development.md` (demo scene run lines dropped), `packages.md` (one clause on `seat_sim.gd`), `STATUS.md` night 2 row. Gates on the final tree: full suite with traces `CASES 862 CHECKS 144276 FAILURES 0`; four traces `cmp` exit 0; `run_checks.sh` `CHECKS PASSED 5` (twice, the second after the ledger and verification edits); netplay `match` 9129, `perturb`, `relay-down`, `relay-term` passed; `CONFORMANCE PASSED 41`; team match `won tick=39497 winner=2 units_peak=271`; V8, V10, V11 (665 ids), V11b (3097 lines), V12 (empty), V13 (`V13 OK removed=439 renamed=352 listed=87`); `rg -n '^extends "res://scripts/' game/scripts` empty; benchmark as in the Gate table, host load 1.56 at start. Not run: rendered benchmark (Decision 14), CI, browser. Logs `t8-*.log` in the logs folder.

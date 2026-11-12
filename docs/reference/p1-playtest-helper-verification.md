# P1 playtest helper: verification

```text
Resume record (updated 2026-11-12 Task 4 done)
Branch / base commit / working-tree state: p1-playtest-helper / c3634fc (Task 3) / Task 4 implemented, uncommitted (coordinator commits "Add the in-match checklist and marker note")
Last green task / next incomplete task: Task 4 / Task 5
Changed paths since last commit: game/scripts/playtest/playtest_overlay.gd(+.uid), game/scripts/{skirmish_main,online_main}.gd, game/scripts/presentation/pause_menu.gd, game/tests/{test_playtest_overlay.gd(+.uid),test_pause_menu.gd,run_tests.gd}, this file
Last command / cases / checks / failures / exit / marker: full run_tests CASES 779 CHECKS 140121 FAILURES 0, exit 0, TESTS PASSED; lint 0; warnings 149 files 0; run_python_checks 0
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: local commits per task by the coordinator; never push
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: Task 5 (after-match form and leaving)
```

## Evidence rows (append-only)

- 2026-11-12, tree p1-playtest-helper 6402e74 (clean), baseline before Task 1. Log ~/projects/wargrid-p1-work/t1-baseline.log.
  - run_tests: CASES 751 CHECKS 139716 FAILURES 0, TESTS PASSED, exit 0.
- 2026-11-12, tree p1-playtest-helper 6402e74 + uncommitted Task 1, load unmeasured, no game window. Logs ~/projects/wargrid-p1-work/t1-*.log.
  - Red: `WARGRID_TEST_ONLY=test_playtest_replay` with stubbed recorder/state_summary: 9 assertion failures, no parse errors (t1-red.log).
  - test_playtest_replay (7 cases, 31 checks) and test_online_scene (28 cases incl. test_online_playtest_record) green. Offline scene 600 ticks (frc vs china, dry_wells, seed 7, a player move at step 30) replays through the oracle with `--factions` to the recorded end digest; dropping the player's move line changes the digest.
  - Full run_tests: CASES 759 CHECKS 139750 FAILURES 0, TESTS PASSED, exit 0 (baseline 751 / 139716, +8 cases). run_lint exit 0; run_warnings 141 files exit 0.
  - run_netplay (no argument is an error; CI set `match perturb relay-down maps map-mismatch`, script ~/projects/wargrid-p1-work/t1-netplay.sh): branch t1-netplay.log and main t1-netplay-main.log both: match PASSED (terminal tick 9024), perturb PASSED (`snapshot.players[1].credits: 9200 != 9201`), relay-down PASSED, maps PASSED, map-mismatch PASSED. Only differences: wall times, relay-down end ticks (1270/1275 vs 1280/1275) and the maps scenario's random seed/starts, as expected.
  - `git diff main -- game/scripts/simulation` empty.
  - Deviation from the plan text: test_bot_through_recorder_keeps_memory passes attack_tick 0 (the bot only creates its memory on an attack decision, never at tick 0 with the default attack tick). skirmish_main `_issue`/`_step_simulation` go through `_recording()`, which rewraps when a test swaps `simulation` directly.
- 2026-11-12, tree p1-playtest-helper 182ceb1 + uncommitted Task 2, load unmeasured, no game window. Logs ~/projects/wargrid-p1-work/t2-*.log.
  - Red: `WARGRID_TEST_ONLY=test_playtest.gd` with stubbed settings/cards/view and no focus file: 28 assertion failures, no parse errors (t2-red.log).
  - test_playtest (6 cases, 159 checks) and test_online_scene (24 cases, 650 checks) green. Full run_tests: CASES 765 CHECKS 139995 FAILURES 0, TESTS PASSED, exit 0 (Task 1: 759 / 139750). run_lint exit 0; run_warnings 143 files exit 0; run_shell_checks exit 0; run_python_checks all pass.
  - `sh tools/export_build.sh Web ~/projects/wargrid-p1-work/web/index.html` exit 0; `game/build_commit.txt` held `182ceb1-dirty`, is not in `git status --short` (gitignored), and `build_commit.txt` plus `data/playtest/focus.json` appear in the exported pck. The file was removed afterwards.
  - `git diff main -- game/scripts/simulation game/scripts/net` empty.
  - Deviation: `Center/Box` separation 12 to 8 in `launcher.tscn`; the two new controls made the box 738 px tall in the 720 px test viewport (Title and Legal outside), 8 gives 686. The headless test root stays 1280x720 when its size is set to 1920x1080, so both sizes check the same layout. The "corrupt stored switch" boundary is tested with a stored string and a stored number; a malformed settings file prints an engine ERROR that the runner counts as a failure. `ThisBuild` and `FocusPanel` are created whenever the cards load and hidden while the switch is off.
- 2026-11-12, tree p1-playtest-helper 4bab5b0 + uncommitted Task 3, load unmeasured, no game window. Logs ~/projects/wargrid-p1-work/t3-*.log.
  - Red: `WARGRID_TEST_ONLY=test_playtest.gd` with stub MarkerCapture/PlaytestSession: 15 assertion failures, no parse errors (t3-red.log).
  - test_playtest 12 cases, 190 checks green. Full run_tests: CASES 771 CHECKS 140026 FAILURES 0, TESTS PASSED, exit 0 (Task 2: 765 / 139995). run_lint exit 0; run_warnings 147 files exit 0; run_python_checks exit 0. `git diff main -- game/scripts/simulation` empty.
  - Mutation proofs: dropping the `_mirror()` call in `finish_match` fails PT11 (mirror) and PT12 (count after restart, resume) (t3-mut1.log); resizing the caller's image instead of a copy fails PT7 "keeps its size" twice (t3-mut2.log). Both reverted.
  - `PlaytestSession` uses `class_name` (static `dir`/`current` typed as itself); tests and later tasks reference it as a global, no preload const. `open_count` is wired into `FocusCardView` in `launcher.gd`. Corrupt `current.json` is parsed through `JSON.new().parse` so no engine ERROR prints. Pending (unfinished-match) markers are not mirrored; only `finish_match`, `set_comment`, `set_answer`, `set_checked` write `current.json`.
- 2026-11-12, tree p1-playtest-helper c3634fc + uncommitted Task 4, load unmeasured, no game window. Logs ~/projects/wargrid-p1-work/t4-*.log.
  - test_playtest_overlay 8 cases, 57 checks green (t4-run2.log). Full run_tests: CASES 779 CHECKS 140121 FAILURES 0, TESTS PASSED, exit 0 (Task 3: 771 / 140026). run_lint exit 0; run_warnings 149 files exit 0; run_python_checks exit 0. `git diff main -- game/scripts/simulation` empty.
  - Red phase not run: the overlay was written before the suite, so there was no separate red run. The mutation proofs below stand in for it.
  - Mutation proofs (each reverted, files diffed back): Esc no longer closes the note or is handled fails PO4 "Esc closes the note and leaves the pause menu closed" (t4-mut1a.log); no `_text.grab_focus()` plus no `holds_match()` guard in `skirmish_main._unhandled_input` fails the three PO4 typing checks (focus, letters, no command; t4-mut1b.log); capturing after `_dialog.show()` fails PO3 "screenshot is taken before the note is shown, saw [true]" (t4-mut3.log).
  - Layout: `test_overlay_layout` gets a real second size by instantiating the scene inside a `SubViewport` of 1280x720 and 1920x1080 and asserting `get_visible_rect().size` equals it; resizing `runner.root` does not work headless (Task 2). E8 in `test_pause_menu.gd` still resizes `runner.root`, so its two sizes check the same layout; only the new Playtest-button visibility check was added there.
  - Choices: the kind buttons are toggles and Save stays disabled until one is picked; the overlay sits in `$HUD` just below the pause menu; `skirmish_main._unhandled_input` returns while the note is open (so clicking a kind button, which takes focus, cannot turn letters into hotkeys); with the note open ` and N are not handled so they can be typed; `key:<name>` triggers are observed only while no note is open. `web`, `download` and `match_record` are declared on the overlay for Task 5 but unused until then.

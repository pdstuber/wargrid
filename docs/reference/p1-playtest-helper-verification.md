# P1 playtest helper: verification

```text
Resume record (updated 2026-11-12 Task 3 done)
Branch / base commit / working-tree state: p1-playtest-helper / 4bab5b0 (Task 2) / Task 3 implemented, uncommitted (coordinator commits "Capture markers and keep playtest sessions")
Last green task / next incomplete task: Task 3 / Task 4
Changed paths since last commit: game/scripts/launcher.gd, game/scripts/playtest/{marker_capture,playtest_session}.gd(+.uid), game/tests/test_playtest.gd, this file
Last command / cases / checks / failures / exit / marker: full run_tests CASES 771 CHECKS 140026 FAILURES 0, exit 0, TESTS PASSED; lint 0; warnings 147 files 0; run_python_checks 0
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: local commits per task by the coordinator; never push
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: Task 4 (in-match overlay: checklist and marker note)
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

# P1 playtest helper: verification

```text
Resume record (updated 2026-11-12 Task 1 done)
Branch / base commit / working-tree state: p1-playtest-helper / main 6402e74 / Task 1 implemented, uncommitted (coordinator commits "Record offline commands for session replays")
Last green task / next incomplete task: Task 1 / Task 2
Changed paths since last commit: game/scripts/main.gd, skirmish_main.gd, online_main.gd, net/lockstep.gd, net/headless_client.gd, game/scripts/playtest/command_recorder.gd(+.uid), game/tests/test_playtest_replay.gd(+.uid), test_online_scene.gd, run_tests.gd, this file
Last command / cases / checks / failures / exit / marker: full run_tests CASES 759 CHECKS 139750 FAILURES 0, exit 0, TESTS PASSED; lint 0; warnings 141 files 0; netplay CI set (match perturb relay-down maps map-mismatch) all PASSED on the branch and on main
Known red case or blocker: none. run_python_checks: ruff, mypy, test_sim_boundary pass; tools/audio/test_synth.py fails here (no numpy installed; unrelated, no Python changed)
Approved decisions, pre-authorizations used, deferred gates: local commits per task by the coordinator; never push
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: Task 2 (helper switch, build id, focus cards)
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

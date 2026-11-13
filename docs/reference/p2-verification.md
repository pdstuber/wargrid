```text
Resume record (updated 2026-11-13 Task 3c implemented, uncommitted)
Branch / base commit / working-tree state: p2-you-clicked / a86ea6a / worktree ~/projects/wargrid-wt-p2, Task 10b changes uncommitted
Last green task / next incomplete task: Task 10a (committed a86ea6a); Task 10b (all gates green, awaiting the coordinator's commit) / Task 10c (after the user's check C in Firefox), then rest of gate (a) (test deploy, F5 repro, web bench, rendered rerun), then Task 10
Changed paths since last commit: game/scripts/launcher.gd, game/scenes/launcher.tscn, game/tests/test_online_scene.gd, game/tests/test_audio_settings.gd, docs/reference/p2-verification.md
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh / 837 / 143000 / 0 / 0 / TESTS PASSED 143000
Known red case or blocker: none (tools/test_audio_assets.py fixed in Task 9: layout lists voice/units, 12 credit rows)
Approved decisions, pre-authorizations used, deferred gates: spec decisions (user, 2026-11-13) in docs/superpowers/specs/2026-11-13-p2-you-clicked-we-heard-design.md; Piper re-download approved (user, 2026-11-13); local commit per GREEN task (milestone prompt); stop gates (a), (b), (c) not reached
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: coordinator commits Task 9, then the rest of gate (a)
```

Plan: [P2 "You clicked, we heard"](../superpowers/plans/2026-11-13-p2-you-clicked-we-heard.md). Spec: [design](../superpowers/specs/2026-11-13-p2-you-clicked-we-heard-design.md). Scratch and logs: `~/projects/wargrid-p2-work/`.

## Tasks

| Task | What | Status |
|---|---|---|
| 1 | Order voice rule: table and director | done (5c258d7) |
| 2 | Order voice in the game: player, hooks, placeholder WAVs | done (uncommitted) |
| 3 | Launcher sections and Advanced fold | done (uncommitted) |
| 4 | F4 music shuffle, F1 scale legend | done (uncommitted) |
| 5 | Late-game 3v3 canary (report-only) | done (uncommitted) |
| 6 | Browser rider prep: bench lines, two web exports, native run | done (uncommitted) |
| 7 | Voice pipeline and A/B page | done (uncommitted; python checks red only on pre-existing test_audio_assets) |
| 8 | P2 focus card and docs | done (uncommitted) |
| gate (a) | A/B pick, F5 repro on the test app, web bench both builds, rendered rerun | A/B pick done (user, 2026-11-13); rest not started |
| 9 | Picked voices into the game | done (uncommitted) |
| 10a | Pure rules: JoinLink and PlaytestSettings.prerelease | done (a86ea6a) |
| 10b | Launcher: prerelease-only fold, ?code=/?relay=, Copy link | done (uncommitted) |
| 3b | Launcher faction rows | done (uncommitted) |
| 3c | Relay caption | done (uncommitted) |
| 10c | Paste shim (after the user's check C in Firefox) | not started |
| 10d | F5 outcome and docs | not started |
| 11 | Exit checks and ledger row | not started |
| 12 | Gate review and lean pass | not started |
| gate (b) | Focus card playtest | not started |
| 13 | Playtest fixes and findings | not started |
| gate (c) | Push, deploy, merge (each approved) | not started |
| 14 | Recorded playtest match row (after the exit, own commit) | not started |

## Gates

- Per GREEN task: `sh tools/run_tests.sh` (to a file, exit code, timeout 600000), `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/check_public.sh`; `sh tools/run_python_checks.sh` when `tools/` Python changes; `sh tools/run_shell_checks.sh` when a `*.sh` changes; `git diff main -- game/scripts/simulation game/scripts/net` empty (presentation only; the trace and replay tests pass unchanged).
- Exit (Task 11 on the final tree): all of the above; `sh tools/run_netplay.sh match` with its pinned terminal tick; `sh tools/run_benchmark.sh` alone, `uptime` at start and end, plus a new ledger row; rendered benchmark rerun (gate a, repeated at gate b if presentation code changed after it); one substantive review and one `/ponytail-review` (Task 12); CI on Linux and Windows plus `sh tools/compare_local_traces.sh <run id>` (needs a push, gate c); the user's playtest of card `p2-you-clicked` (gate b).
- Report-only, never gating: late-game 3v3 canary (Task 5), browser against native team match per build (Task 6 and gate a), recorded playtest match row (Task 14, after the exit).

## Evidence rows (append-only)

| Task | Check | Tree | Result |
|---|---|---|---|
| 1 | `sh tools/run_tests.sh` baseline before the task | d0cc99d | CASES 808 CHECKS 140940 FAILURES 0, exit 0 |
| 1 | `WARGRID_TEST_ONLY=test_order_voice` RED with the empty table | d0cc99d + uncommitted | assertion failures only (OV1-OV5), no SCRIPT ERROR, exit 1 |
| 1 | full `sh tools/run_tests.sh` GREEN; `run_lint.sh`, `run_warnings.sh`, `check_public.sh` exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty | d0cc99d + uncommitted | CASES 813 CHECKS 141002 FAILURES 0, exit 0 |
| 2 | `WARGRID_TEST_ONLY=test_order_voice` RED (placeholders present, no `_unit_voice`, no hook) | 5c258d7 + uncommitted | CASES 12 CHECKS 88 FAILURES 7 (OV7, OV9-OV12; OV6 and OV8 hold before the code), no parse error, exit 1 |
| 2 | `WARGRID_TEST_ONLY=test_order_voice` GREEN | 5c258d7 + uncommitted | CASES 12 CHECKS 88 FAILURES 0, exit 0 |
| 2 | `test_sound.gd`, `test_announcer`, `test_online_scene`, `test_playtest_overlay` unchanged | 5c258d7 + uncommitted | 24/179, 20/64, 24/650, 17/649 cases/checks, FAILURES 0, exit 0 |
| 2 | full `sh tools/run_tests.sh` GREEN; `run_lint.sh`, `run_warnings.sh`, `check_public.sh` exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty | 5c258d7 + uncommitted | CASES 820 CHECKS 141028 FAILURES 0, exit 0 |
| 3 | `WARGRID_TEST_ONLY=test_launcher_sections` RED (no headers, no Advanced) | f94bb08 + uncommitted | CASES 1 CHECKS 10 FAILURES 10, no SCRIPT ERROR, exit 1 |
| 3 | measured `Center/Box` height at 1280x720 and 1920x1080, fold open, WaitRow and ThisBuild visible, separation 6 | f94bb08 + uncommitted | 738 px (viewport 720: Title and Legal outside), STOP condition |
| 3 | full `sh tools/run_tests.sh` | f94bb08 + uncommitted | CASES 821 CHECKS 142174 FAILURES 4 (N5 and N20 Title/Legal inside 1280x720 only), exit 1; `test_playtest.gd` 14/213, `test_pause_menu` 8/332 FAILURES 0; lint, warnings, check_public exit 0; sim/net diff empty |
| 3 | Status `custom_minimum_size` height 48 -> 24 (user ruling 2026-11-13); measured `Center/Box` at 1280x720 and 1920x1080, fold open, WaitRow and ThisBuild visible | f94bb08 + uncommitted | 714 px (viewport 720), N5 and N20 inside and no overlap; closed fold about 677 px (derived, not measured); Status one-line checks added to N20 (code line, relay lost, three map differ lines) pass |
| 3 | full `sh tools/run_tests.sh` GREEN; `run_lint.sh`, `run_warnings.sh`, `check_public.sh` exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty | f94bb08 + uncommitted | CASES 821 CHECKS 142184 FAILURES 0, exit 0 |
| 4 | `WARGRID_TEST_ONLY=test_audio_settings` and `=test_scale_legend` RED with stubs (`shuffled` returns a copy, `SCALE_LEGEND` const, no label); without stubs the suites fail to parse | cbb8fc3 + uncommitted | audio 12/40 FAILURES 1 (MU1 seeds differ); legend 1/1 FAILURES 1 (PO18); MU2 holds under the identity stub (its checks are order-agnostic), exit 1 |
| 4 | `test_audio_settings` 12/40, `test_scale_legend` 1/2, `test_sound` 24/179, FAILURES 0 | cbb8fc3 + uncommitted | exit 0 |
| 4 | full `sh tools/run_tests.sh` GREEN; `run_lint.sh`, `run_warnings.sh`, `check_public.sh` exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty | cbb8fc3 + uncommitted | CASES 824 CHECKS 142193 FAILURES 0, exit 0 |
| 5 | `WARGRID_TEST_ONLY=test_late_game_layout` RED (unknown layout) | b483f99 + uncommitted | CASES 1 CHECKS 0 FAILURES 2 (assertion on the layout name, `view_state` on Nil), exit 1 |
| 5 | `WARGRID_TEST_ONLY=test_late_game_layout` GREEN | b483f99 + uncommitted | CASES 1 CHECKS 9 FAILURES 0, exit 0 |
| 5 | full `sh tools/run_tests.sh` GREEN; `run_lint.sh`, `run_warnings.sh`, `check_public.sh` exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty; `test_team_match`, `test_replay`, `test_state_hash`, `test_view_rows` unchanged | b483f99 + uncommitted | CASES 825 CHECKS 142202 FAILURES 0, exit 0 |
| 5 | late-game 3v3 canary, one run alone (headless, `run_late_game.gd`, report-only, no budget); no godot or generalszh process before; uptime load averages 2.25 2.33 2.35 before, 2.15 2.31 2.34 after (host under load) | b483f99 + uncommitted | exit 0, `LATE GAME CANARY DONE`; `LATE GAME 3v3 tick_ms={"max":7.575,"n":1800,"p50":1.475,"p95":3.362,"p99":5.581} mean_ms=1.809 shots_window=1666 deaths_window=52 bot_commands_window=94 alive_start=216 alive_end=203` (216 = 210 army + 6 builders); `WORST TICK late_game late_game_3v3 ms=7.575 tick=1560`; PROFILE top five: `step` mean 1.6905 ms (100%), `step.advance` 0.5562 (32.9%), `step.combat_plan` 0.5077 (30.0%), `step.combat_fire` 0.3334 (19.7%), `step.production` 0.1522 (9.0%) |
| 6 | `WARGRID_TEST_ONLY=test_benchmark` RED (`Stats.mean` absent) | 238451d + uncommitted | parse error `Static function "mean()" not found`, suite failed to load, exit 1 |
| 6 | `WARGRID_TEST_ONLY=test_benchmark` GREEN (BM21 registered in `cases()`) | 238451d + uncommitted | CASES 27 CHECKS 1985 FAILURES 0, exit 0 |
| 6 | full `sh tools/run_tests.sh` GREEN; `run_lint.sh`, `run_warnings.sh`, `check_public.sh` exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty; tracked `game/export_presets.cfg` unchanged | 238451d + uncommitted | CASES 826 CHECKS 142204 FAILURES 0, exit 0 |
| 6 | headless export `Web Bench`, single-threaded, to `~/projects/wargrid-p2-work/web-bench/` | 238451d + uncommitted | exit 0; `index.wasm` 39514754 bytes, `index.pck` 13386340 bytes |
| 6 | headless export `Web Bench`, threaded (`variant/thread_support=true` in the scratch copy `~/projects/wargrid-p2-work/threaded-tree` only: `git archive HEAD` plus the three uncommitted game files), to `~/projects/wargrid-p2-work/web-bench-threads/` | 238451d + uncommitted | exit 0, no template error; `index.wasm` 38820072 bytes, `index.pck` 13386268 bytes (pck 72 bytes smaller: scratch tree has no git, so no `build_commit.txt`) |
| 6 | native `bench_runner.gd` run alone (headless; no godot or generalszh process before; uptime load averages 2.50 2.37 2.35 before, 1.64 2.07 2.23 after, host under load) | 238451d + uncommitted | exit 0; `TEAM MATCH won tick=39497`; `TEAM TIMING {"max":16.009,"n":39497,"p50":1.278,"p95":2.317,"p99":7.839}`; `TEAM MEAN ms=1.428`; `WORST TICK bench team ms=16.009 tick=9540`; Firefox runs wait for gate (a) |
| 7 | `sh tools/run_python_checks.sh` RED (mypy: no `UNIT_LINES`, `UNIT_VARIANTS`, `radio`, `TREATMENTS`, `UNIT_PICKS`, no `voice` argument) | 7e9a588 + uncommitted | 8 mypy errors, exit 1 |
| 7 | `sh tools/run_python_checks.sh` after the code: ruff format, ruff check, mypy clean; `test_synth.py` 13 tests OK; `tools/test_audio_assets.py` 3 failures (`units` folder under `voice`, 12 uncredited files) that also occur with Task 7 stashed (log `t7-base.log`): from the Task 2 placeholders, not Task 7 | 7e9a588 + uncommitted | exit 1 (only that file) |
| 7 | invariant: `main`'s `synth.py`/`process.py` and the branch's `synth.py` run on the same SRC, `cmp` of 10 `sfx/*.wav` and 8 `voice/*.wav` | 7e9a588 + uncommitted | 18 of 18 byte-identical; no `voice/units` output while `UNIT_PICKS` is empty |
| 7 | Piper: venv `~/projects/wargrid-sound-work/venv-piper` (Python 3.14), `pip install piper-tts==1.8.0` (onnxruntime 1.32.0); `en_US-{john,norman,bryce}-medium.onnx` at HF revision `e7229f7d33a10e145e109b886d661984201ac3c4` | n/a (outside repo) | exit 0; each `.onnx` 63531379 bytes |
| 7 | model cards at the pinned revision, licence lines | n/a (outside repo) | john, norman and bryce: `* License: public domain` |
| 7 | raw renders `render.py --units` (six texts) for john, norman, bryce; A/B build script: 3 voices x 3 treatments x 6 lines through `TREATMENTS` at `VOICE_LUFS` | n/a (outside repo) | 18 raw WAVs; 54 A/B WAVs, no peak error; `index.html` served on 8061 by `serve_web_bench.py`: `/` 200, a WAV 200, POST `/result` 204; server stopped; page not opened |
| 7 | `sh tools/check_public.sh` | 7e9a588 + uncommitted | exit 0 |
| 7 | pitched-carrier treatments `c1n90`, `c1n140` (`c1n` gains `pitch=110.0`); `run_python_checks.sh`: ruff, mypy, `test_synth.py` (14 tests) pass, only `tools/test_audio_assets.py` fails as before; invariant rerun: `cmp` of 10 `sfx/*.wav` and 8 `voice/*.wav` against `main`'s synth; second A/B page (voice bryce, pitches 90/110/140 Hz per role, announcer check) outside the repo, served on 8062: `/` 200, WAV 200, POST `/result` 204, server stopped | 7424e64 + uncommitted | 18 of 18 byte-identical; `check_public.sh` exit 0 |
| 8 | `WARGRID_TEST_ONLY=test_playtest` RED (new `SHIPPED`, picker count 4, item 1 `p1-frc-economy`, before the json edit) | 066ee03 + uncommitted | CASES 39 CHECKS 896 FAILURES 6 (PT1, PT2, PT6 x2 sizes), no SCRIPT ERROR, exit 1 |
| 8 | `WARGRID_TEST_ONLY=test_playtest` GREEN after prepending the `p2-you-clicked` card | 066ee03 + uncommitted | CASES 39 CHECKS 900 FAILURES 0, exit 0 |
| 8 | full `sh tools/run_tests.sh` GREEN; `run_lint.sh`, `run_warnings.sh`, `check_public.sh` exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty; doc links in the changed docs resolve | 066ee03 + uncommitted (tree 493148536853) | CASES 826 CHECKS 142208 FAILURES 0, exit 0 |
| 9 | gate (a) A/B pick: every role voice `bryce`; treatments infantry `c1n140`, vehicle `c1n90`, worker `c1n`; wording unchanged (user, 2026-11-13) | n/a | `UNIT_PICKS` set from it |
| 9 | RED: `sh tools/run_python_checks.sh` (`test_unit_picks_cover_roles`, `test_every_file_credited`, `test_dotfiles_ignored`); `WARGRID_TEST_ONLY=test_credits` (CR-U, 24 FAIL lines) | 26eb7e5 + uncommitted | both exit 1, no SCRIPT ERROR |
| 9 | `synth.py` render of the 12 unit lines (peak limit not hit): infantry_move_1 -24.0 LUFS / -11.1 dBFS, infantry_move_2 -24.0 / -10.6, infantry_attack_1 -24.0 / -9.4, infantry_attack_2 -24.0 / -7.6, vehicle_move_1 -24.0 / -9.9, vehicle_move_2 -24.0 / -8.3, vehicle_attack_1 -24.0 / -9.7, vehicle_attack_2 -24.0 / -5.1, worker_move_1 -24.0 / -10.9, worker_move_2 -24.0 / -9.7, worker_work_1 -24.0 / -7.6, worker_work_2 -24.0 / -8.5 | 26eb7e5 + uncommitted (stash tree 5956a0235eb9) | exit 0 |
| 9 | invariant: `cmp` of 10 `sfx/*.wav` and 8 `voice/*.wav` against `synth-main-out`; `godot --headless --path game --import` exit 0; `git diff --stat game/audio/voice/units/*.import` | 26eb7e5 + uncommitted (stash tree 5956a0235eb9) | 18 of 18 identical, only the 12 unit WAVs changed, `.import` diff empty |
| 9 | GREEN: `WARGRID_TEST_ONLY=test_credits` 13/200, `=test_order_voice` 12/88 (CASES/CHECKS), FAILURES 0; `sh tools/run_python_checks.sh` | 26eb7e5 + uncommitted (stash tree 5956a0235eb9) | exit 0, exit 0, `PYTHON TESTS PASSED` |
| 9 | full `sh tools/run_tests.sh` GREEN; `run_lint.sh`, `run_warnings.sh`, `check_public.sh` exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty; `git ls-files game/audio` size 13986476 bytes (<= 20000000) | 26eb7e5 + uncommitted (stash tree 5956a0235eb9) | CASES 827 CHECKS 142233 FAILURES 0, exit 0 |
| 10a | `Godot uri_encode` check before the tests: `"wss://x.example/ws".uri_encode()` | 917b4bd | `wss%3A%2F%2Fx.example%2Fws` (matches the plan), `uri_decode` inverts it |
| 10a | `WARGRID_TEST_ONLY=test_join_link` RED (stubs, `prerelease` returns false) | 917b4bd + uncommitted | CASES 6 CHECKS 42 FAILURES 18 (JL1-JL6), no SCRIPT ERROR, exit 1 |
| 10a | `test_join_link` GREEN; `WARGRID_TEST_ONLY=test_playtest.gd` unchanged; full `sh tools/run_tests.sh`; `run_lint.sh`, `run_warnings.sh`, `check_public.sh` exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty | 917b4bd + uncommitted (index tree 330609078ffe) | join_link CASES 6 CHECKS 42 FAILURES 0; test_playtest CASES 14 CHECKS 217 FAILURES 0; full CASES 833 CHECKS 142277 FAILURES 0, exit 0 |
| 10b | `WARGRID_TEST_ONLY=test_online_scene` RED: first with no members (`launcher.prerelease` assignment is a SCRIPT ERROR on the old script, 6 incomplete cases), then with member and `_copy_text` stubs only | a86ea6a + uncommitted | stubs run: CASES 29 CHECKS 2519 FAILURES 7 (N21 x2, N22 x2, N23 x3), no SCRIPT ERROR, exit 1 |
| 10b | `test_online_scene` 29/2519, `test_join_link` 6/42, `test_playtest.gd` 14/217, `test_pause_menu` 8/332, `test_audio_settings` 12/40 (CASES/CHECKS), FAILURES 0 (AS9 gets an explicit `prerelease = true`, same meaning) | a86ea6a + uncommitted | all exit 0 |
| 10b | measured `Center/Box` height (N21 and N20 prints), WaitRow and ThisBuild visible: release (Advanced and RelayUrl hidden) 1280x720 and 1920x1080; prerelease with the fold open at both sizes | a86ea6a + uncommitted | release 640 px; prerelease fold open 714 px (viewport 720; closed prerelease not measured); release layout keeps every `_set_busy` path in the tree |
| 10b | full `sh tools/run_tests.sh` GREEN; `run_lint.sh`, `run_warnings.sh`, `check_public.sh` exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty; `rg JavaScriptBridge game/scripts/launcher.gd` only `_page_value`; no browser, window or JavaScriptBridge call run (web branch untested here) | a86ea6a + uncommitted (index tree 4d7a63a2e3c0, taken before this row) | CASES 837 CHECKS 143000 FAILURES 0, exit 0, TESTS PASSED 143000 |
| 3b | Owner decision 2026-11-13: the spec's "Match row" (faction and map above both sections) becomes a Map row plus one "You" faction selector per play section (`OfflineRow/Own`, `OnlineRow/Own`), independent, plus "Bot" on the offline row; Create moves into `OnlineRow` | 71fb2f3 + uncommitted | spec change recorded here |
| 3b | `WARGRID_TEST_ONLY=test_online_scene` RED (new paths absent; N25 and path-based cases fail with SCRIPT ERROR on null nodes) | 71fb2f3 + uncommitted | exit 1 |
| 3b | `WARGRID_TEST_ONLY=test_online_scene` GREEN with N25 `test_launcher_faction_rows` at 1280x720 and 1920x1080; F5 width check now "box under 600 px" (the Box is 587 px wide, was 520, because the offline row holds two selectors) | 71fb2f3 + uncommitted | CASES 30 CHECKS 3457 FAILURES 0, exit 0 |
| 3b | `test_playtest.gd` 14/217, `test_pause_menu` 8/332, `test_audio_settings` 12/40, `test_join_link` 6/42 | 71fb2f3 + uncommitted | FAILURES 0, exit 0 |
| 3b | measured `Center/Box` height at 1280x720, WaitRow and ThisBuild visible: release (Advanced closed) and prerelease with the fold open | 71fb2f3 + uncommitted | 640 px and 714 px (viewport 720), both unchanged from 10b |
| 3b | full `sh tools/run_tests.sh` GREEN; `run_lint.sh`, `run_warnings.sh`, `check_public.sh` exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty | 71fb2f3 + uncommitted | CASES 838 CHECKS 143938 FAILURES 0, exit 0 |
| 3c | `WARGRID_TEST_ONLY=test_launcher_relay_help` RED (no `RelayHelp`) | c8238cf + uncommitted | CASES 1 CHECKS 2 FAILURES 2, no SCRIPT ERROR, exit 1 |
| 3c | caption added at separation 6, measured `Center/Box` at 1280x720 and 1920x1080, prerelease, fold open, WaitRow and ThisBuild visible | c8238cf + uncommitted | 737 px, over 720: fallback 1 (`Center/Box` separation 6 -> 4) |
| 3c | `WARGRID_TEST_ONLY=test_launcher_relay_help` GREEN (N26) at separation 4 | c8238cf + uncommitted | CASES 1 CHECKS 82 FAILURES 0, exit 0; `Center/Box` prerelease fold open, WaitRow and ThisBuild visible 587 x 703 px (was 714); release with WaitRow and ThisBuild visible 612 px (N21; was 640), 577 px without them; width 587 px |
| 3c | `test_online_scene` 31/3675, `test_playtest.gd` 14/217, `test_pause_menu` 8/332, `test_audio_settings` 12/40, `test_join_link` 6/42 | c8238cf + uncommitted | FAILURES 0, exit 0 |
| 3c | full `sh tools/run_tests.sh` GREEN; `run_lint.sh`, `run_warnings.sh`, `check_public.sh` exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty | c8238cf + uncommitted | CASES 839 CHECKS 144156 FAILURES 0, exit 0 |

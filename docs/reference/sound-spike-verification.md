# Sound spike verification

Handoff: [sound-spike-prompt.txt](../sound-spike-prompt.txt). Plan: [sound spike plan](../superpowers/plans/2026-11-08-sound-spike.md). Evidence: [sound-spike.md](sound-spike.md). Dated sections below the record are append-only.

```text
Resume record (updated 2026-11-08)
Branch / base commit / working-tree state: spike-sound / base main 893332f (HEAD 1520b90) / clean after the ruling commit
Last green task / next incomplete task: Task 4 done (checkpoint restart; uncommitted) / Task 5
Changed paths since last commit: game/default_bus_layout.tres, game/scripts/presentation/sound_cues.gd, sound_director.gd, sound_player.gd, game/scripts/skirmish_main.gd, game/tests/test_sound.gd, this file
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh, CASES 528 CHECKS 136420 FAILURES 0 (136427 with traces), exit 0, TESTS PASSED; lint, warnings exit 0; traces identical
Known red case or blocker: none. Online `rejected()` not wired (lockstep rejections carry no player and the sim result already gives the local error; see Task 4 section). Addendum for Task 6: mute button + key toggling Master (plan Task 6 addendum)
Approved decisions, pre-authorizations used, deferred gates: Gate S passed (user, 2026-11-08); local commits after green checkpoints pre-authorized; no push, merge, window, install or fly without approval; Gate A passed (Max Rate off; MacLeod kept); Gate B and exit pending. Commit message for Task 3: 'Add the sound spike audio and credits'
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: commit Task 4 ("Play battle and UI sounds from per-step events"), then dispatch Task 5
```

## Baseline and trace checks

Task 1, 2026-11-08. Machine load 1.5 to 2.1 (`uptime`), benchmark run alone after suite and netplay. Baseline on `5a6abc9` plus Task 0 docs (no code change) in `$SOUND_WORK/traces/base`: suite CASES 504 CHECKS 136259 FAILURES 0, TESTS PASSED, exit 0; `run_netplay.sh match` PASSED, terminal tick 8400; `run_benchmark.sh` exit 0 (COMBAT BENCHMARK PASSED 10, LOCKSTEP p99 0.066 ms, limit 0.6).

After Task 1 (tree: working tree on `spike-sound`, uncommitted, `$SOUND_WORK/traces/new`): suite CASES 508 CHECKS 136267 FAILURES 0, TESTS PASSED, exit 0 (4 new cases SD1 to SD4, 8 new checks); netplay `match` PASSED, terminal tick 8400; compare_replays: replay, economy, combat REPLAYS MATCHED 1200; team (interval 200, rows 100) MATCHED 100; netplay s1 (interval 30, rows 0) MATCHED 281. Red run before implementation: SD1, SD2, SD3 failed on their messages (SD4 passed because the accessors were already added). Lint exit 0, warnings exit 0 (104 files). Python unchanged.

## Measurements

Task 3, 2026-11-08, base `fe3e8e2` (tree: working tree on `spike-sound`, uncommitted). Web export `index.pck`, `$SOUND_WORK/web-N/`:

| build | index.pck bytes |
|---|---|
| web-0 base, no audio | 1,138,288 |
| web-1 audio, Max Rate off | 12,938,240 |
| web-2 audio, Max Rate 22,050 Hz on sfx and voice | 12,742,288 |

`.godot/imported/*.sample` sums (bytes): Max Rate off sfx 220,782, voice 178,296; on sfx 112,494, voice 90,760. Music (Ogg, passthrough) 11,391,419 imported. Raw files (10 sfx, 8 voice, 5 music) well under 20,000,000. Max Rate restored to off, re-imported. Mono on in every sfx and voice `.import`.

Checks: `test_audio_assets.py` red first (CREDITS.md missing), then 6 tests OK; run_python_checks exit 0; suite CASES 508 CHECKS 136260 FAILURES 0, TESTS PASSED, exit 0 (correction, Gate A review: the trace env vars add checks. Without traces `b355b4a` gives 136252 and `HEAD` 136260, +8 for SD1 to SD4; 136259 (baseline) and 136267 (Task 1) were both run with traces and are consistent with each other); lint exit 0; warnings exit 0. First `--import` after adding audio printed one `ERROR: /root: ... propagate_notification()` and exited 134; the immediate re-import was clean (0 errors, exit 0), later imports and exports clean. Gate A reviewer could not reproduce the crash (3 fresh and 3 incremental imports clean). The full log was not kept; the macOS crash report is `/Users/pdstuber/Library/Logs/DiagnosticReports/Godot-2026-11-08-140114.ips`. The Linux and Windows CI run is pending until approval at Gate B or exit.

## Gate rulings

Gate S, passed (user, 2026-11-08): final effects, voice lines and processed music confirmed by ear. Files committed as heard (`$SOUND_WORK/gate-s`).

Gate A, Max Rate (user, 2026-11-08): accepted the recommendation, Max Rate off for `sfx/` and `voice/` (pck 12,938,240 vs 12,742,288 bytes on; saving under 2 %). Voice A/B at Gate B.

Gate A, MacLeod licence (user, 2026-11-08): keep Hitman and Stay the Course on the incompetech FAQ site-wide CC BY statement; per-track exceptions unverified. Gate A review (Opus): no Critical; Important items fixed in 1520b90 except SD1/drain, left to Task 4.

## Task 4

2026-11-08, tree: working tree on `spike-sound`, uncommitted. Red: with the Task 1 director and player, the suite stopped on parse errors (`MAX_DISTANCE_PX`, `plan()` missing). Green: suite CASES 528 CHECKS 136420 FAILURES 0, TESTS PASSED, exit 0 (20 new cases: SD5 to SD23 and SD1b); lint exit 0; warnings exit 0 (107 files); Python unchanged. SD1 now checks `consumed_ticks()` (steps `update` processed, bounded to 64) and that nothing is left pending; `collect_step` caps pending at 120 steps. Trace check against `$SOUND_WORK/traces/base` (new run `traces/t4.MP1A`, suite 136427 checks with traces): replay, economy, combat MATCHED 1200; team MATCHED 100; netplay `match` PASSED terminal tick 8400, s1 MATCHED 281.

Deviation: `online_main` does not call `rejected()` for lockstep rejections. They carry no player (a peer's failure would beep for the local player) and the local failure already arrives as a command result through `update`. ATTENUATION 0.5 and MAX_DISTANCE_PX 1145.0 live in `sound_player.gd` (Task 1 only measured them). SD22 checks the Sound child but not the log for `ERROR:` (the suite fails on script errors already).

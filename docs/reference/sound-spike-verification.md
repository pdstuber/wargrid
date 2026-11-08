# Sound spike verification

Handoff: [sound-spike-prompt.txt](../sound-spike-prompt.txt). Plan: [sound spike plan](../superpowers/plans/2026-11-08-sound-spike.md). Evidence: [sound-spike.md](sound-spike.md). Dated sections below the record are append-only.

```text
Resume record (updated 2026-11-08)
Branch / base commit / working-tree state: spike-sound / base main 893332f (HEAD 1520b90) / clean after the ruling commit
Last green task / next incomplete task: Task 3 done, Gate A closed / Task 4 (fresh start; checkpoint restart)
Changed paths since last commit: game/audio/** (23 files + .import + CREDITS.md), tools/test_audio_assets.py, .github/workflows/ci.yml, README.md, docs/reference/sound-spike.md, this file
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh, CASES 508 CHECKS 136260 FAILURES 0, exit 0, TESTS PASSED; lint, warnings, python checks exit 0
Known red case or blocker: none. Open for Task 4: `SoundDirector.update()` does not drain `_pending` yet, so SD1 passes only because nothing drains; Task 4 must rewrite SD1 to check the steps `update` actually consumed. MacLeod licence ruled (keep, FAQ). Addendum for Task 6: mute button + key toggling Master (plan Task 6 addendum)
Approved decisions, pre-authorizations used, deferred gates: Gate S passed (user, 2026-11-08); local commits after green checkpoints pre-authorized; no push, merge, window, install or fly without approval; Gate A passed (Max Rate off; MacLeod kept); Gate B and exit pending. Commit message for Task 3: 'Add the sound spike audio and credits'
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: dispatch Task 4
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

# Sound spike verification

Handoff: [sound-spike-prompt.txt](../sound-spike-prompt.txt). Plan: [sound spike plan](../superpowers/plans/2026-11-08-sound-spike.md). Evidence: [sound-spike.md](sound-spike.md). Dated sections below the record are append-only.

```text
Resume record (updated 2026-11-08)
Branch / base commit / working-tree state: spike-sound / base main 893332f / uncommitted fixes on 3126722 (Gate B review findings)
Last green task / next incomplete task: Task 7 done (Steps 1-5 by the user, 2026-11-08; online by tests only) and Step 6 final report written, pushed through 13f7c03; full-branch Opus review fixes local; push and merge to main need the user's confirmation
Changed paths since last commit: game/scripts/online_main.gd, game/scripts/presentation/sound_director.gd, sound_player.gd, game/tests/test_announcer.gd, test_audio_settings.gd, test_online_scene.gd, docs/reference/sound-spike.md, the sound spike spec Goals line, this file
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh (with traces), CASES 558 CHECKS 136835 FAILURES 0, exit 0, TESTS PASSED; lint exit 0; warnings exit 0 (114 files); netplay match PASSED tick 8400; traces in $SOUND_WORK/traces/t6b MATCHED against base (replay, economy, combat 1200; team 100; s1 281)
Known red case or blocker: none. Open: Gate B Step 5 (windowed) and Step 6 (closure). Unverified: panned-camera listener position and voice A/B by ear
Approved decisions, pre-authorizations used, deferred gates: Gate S passed (user, 2026-11-08); local commits after green checkpoints pre-authorized; no push, merge, window, install or fly without approval; Gate A passed (Max Rate off; MacLeod kept); Gate B and exit pending
CI on pushed 5fa614b (2026-11-08): run 42495724976 success, all 11 jobs green (Docker, Godot tests linux and windows, lint, exported builds linux and windows, Compare replays, Relay, Workflows, Python); compare_local_traces.sh 42495724976 exit 0: replay, economy, combat MATCHED 1200, team MATCHED 100, netplay MATCHED 281 (macOS local vs Linux and Windows CI)
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: user: approve push; then CI on the merged tree and merge to main. A friend is playtesting; sound findings from that go to session notes.
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

Task 6 Step 6 measurements, 2026-11-08, HEAD `6e51e07`, headless, load 2.1 to 1.9 (`uptime`), nothing else running. Trace check into `$SOUND_WORK/traces/t6`: suite CASES 552 CHECKS 136809 FAILURES 0 (with traces), TESTS PASSED, exit 0; netplay `match` PASSED, terminal tick 8400; replay, economy, combat MATCHED 1200; team MATCHED 100; netplay s1 MATCHED 281. `run_benchmark.sh` alone: exit 0, BENCHMARK PASSED 2, COMBAT BENCHMARK PASSED 10, LOCKSTEP BENCHMARK PASSED 1, every BUDGET line PASS (same set as baseline), LOCKSTEP p99 0.066 ms (baseline 0.066, limit 0.6). Per-scenario p99 within about 3 % of the baseline `traces/base/bench.log`, no row moved beyond noise, none exceeded. Ledger not edited.

## Gate rulings

Gate S, passed (user, 2026-11-08): final effects, voice lines and processed music confirmed by ear. Files committed as heard (`$SOUND_WORK/gate-s`).

Gate A, Max Rate (user, 2026-11-08): accepted the recommendation, Max Rate off for `sfx/` and `voice/` (pck 12,938,240 vs 12,742,288 bytes on; saving under 2 %). Voice A/B at Gate B.

Gate A, MacLeod licence (user, 2026-11-08): keep Hitman and Stay the Course on the incompetech FAQ site-wide CC BY statement; per-track exceptions unverified. Gate A review (Opus): no Critical; Important items fixed in 1520b90 except SD1/drain, left to Task 4.

Gate B, mix (user, 2026-11-08, by ear): effects -6 dB via bus trim (`EFFECTS_TRIM_DB` in `audio_settings.gd`, slider at 100 % means -6 dB), cannon `gain_db` -3.8 (later raised to -1.5, see below), QOA = raw, falloff curve unchanged.

## Task 4

2026-11-08, tree: working tree on `spike-sound`, uncommitted. Red: with the Task 1 director and player, the suite stopped on parse errors (`MAX_DISTANCE_PX`, `plan()` missing). Green: suite CASES 528 CHECKS 136420 FAILURES 0, TESTS PASSED, exit 0 (20 new cases: SD5 to SD23 and SD1b); lint exit 0; warnings exit 0 (107 files); Python unchanged. SD1 now checks `consumed_ticks()` (steps `update` processed, bounded to 64) and that nothing is left pending; `collect_step` caps pending at 120 steps. Trace check against `$SOUND_WORK/traces/base` (new run `traces/t4.MP1A`, suite 136427 checks with traces): replay, economy, combat MATCHED 1200; team MATCHED 100; netplay `match` PASSED terminal tick 8400, s1 MATCHED 281.

Deviation: `online_main` does not call `rejected()` for lockstep rejections. They carry no player (a peer's failure would beep for the local player) and the local failure already arrives as a command result through `update`. ATTENUATION 0.5 and MAX_DISTANCE_PX 1145.0 live in `sound_player.gd` (Task 1 only measured them). SD22 checks the Sound child but not the log for `ERROR:` (the suite fails on script errors already).

## Task 5

2026-11-08, tree: working tree on `spike-sound`, uncommitted. Tests were written after the implementation, so the red run is a mutation: with the base_under_attack and building_lost cooldowns removed, AN1 and AN2 failed (and four fixture bugs showed up in the same run until `Dictionary.merge(..., true)` was used). Green: suite CASES 544 CHECKS 136465 FAILURES 0, TESTS PASSED, exit 0 (16 new cases AN1 to AN16); lint exit 0; warnings exit 0 (108 files); Python unchanged. Trace check against `$SOUND_WORK/traces/base` (new run `traces/t5`, suite 136472 checks with traces): replay, economy, combat MATCHED 1200; team MATCHED 100; netplay `match` PASSED terminal tick 8400, s1 MATCHED 281.

Notes: `Announcer` is preloaded, no `class_name`. The funds line comes from a failed own result (event tick) or `rejected()` (state tick on the next update); online `rejected()` stays unwired. `insufficient_funds` no longer gives the error beep. Tests use `Definitions` = `economy_definitions.gd` for FRC power data (AN12 checks every `frc_` building draws no power).

## Task 6

2026-11-08, tree: working tree on `spike-sound`, uncommitted. Red: suite stopped on parse errors (`audio_settings.gd` missing); after the files existed AS3 failed three checks (slider `value_changed` does not fire on a node outside the tree, so the test adds it to the root). Green: suite CASES 552 CHECKS 136802 FAILURES 0, TESTS PASSED, exit 0 (8 new cases AS1 to AS8; N5 and E8 extended; N5 passes at 1280x720 and 1920x1080 with the Volume grid); lint exit 0; warnings exit 0 (the new untracked files checked with `--check-only`, no output). Trace check not rerun: presentation only, no simulation file touched. Windowed Gate B (Step 5) not run.

Mute addendum: `M` was free (`rg` over `project.godot` and `game/scripts`: B, E, U, A, S, 1-9, F3 used). The `Mute` toggle button sits in `VolumeSliders` (row "Master"), so launcher and Esc menu get it; `VolumeSliders._unhandled_input` handles `M`, so the key works in every scene that holds the sliders (match: the hidden pause menu; launcher too) and no other script references `AudioSettings` (a second preloader of it made `run_warnings.sh` report 23 resources still in use at exit). Session-only; AS7 and AS8 cover the button, the key, the settings file and the slider values.

Deviations: `MusicPlayer` does not call `play()` under the headless display server (the suite otherwise exits with Ogg playbacks reported as leaked resources, which `run_tests.sh` treats as an error). `run_tests.gd` sets `AudioSettings.path` to a scratch file so the `SoundPlayer` start-up `apply` never reads a developer's real volumes; the unparsable-file case is not tested because Godot logs an `ERROR:` for it, which the suite wrapper fails on (a failed load already gives defaults). Online scenes inherit the match playlist from `skirmish_main`.

## Gate B review fixes

2026-11-08, tree: uncommitted fixes on 3126722. Red first: N6 (online funds rejection not announced) and AN18 (`building_lost` after `defeat`) failed; the other new tests passed against the unchanged code and were proved by mutation (each mutation red, restored): funds line in `_consume`, in `update`, `skirmish_main._submit` rejected call, `online_main` rejected call, `director.reset()` in `_restart` (AN16, AN17), both `_previous_status` guards (AN15, SD19), the low-power edge (AN8, drain past the 3600 tick cooldown), `winner == local_player` (AN8, AN13 with seat id different from team), the `run_tests.gd` settings redirect (AS4).

Changes: `online_main` calls `rejected()` for every new lockstep rejection (every entry is the local seat's, lockstep.gd `if s != _seat: continue`; issue-time failures return before command results, so no double). Victory and defeat clear the announcer queue. AN9 uses real kinds with non-empty queues; AN15 also checks the returned requests; AN16 asserts the voice line. AS4 now checks the redirect itself. AS8 pushes a real `InputEventKey` through `Viewport.push_input`; AS9 covers the launcher and a focused `LineEdit` (the field takes the letter, no mute). `SoundPlayer` does not call `_voice.play()` under the headless display server (a played headless line is reported as a leaked resource at exit once a scene test triggers one). `sound-spike.md`: no `AudioListener2D` exists; the Camera2D-following screen-centre fallback is source-read, zoom-only measured.

Music encode (user, 2026-11-08): keep Ogg Vorbis quality 2 (`oggenc -b 96` maps to -q 2, about 85 kbps, 10.90 MB for 5 tracks). Smaller q1/q0 and larger q5 were measured (scratch listening page) and not adopted; CREDITS wording corrected from "96 kbps". LFS / uncompressed-in-repo / build-time encode rejected: sources are lossy, QOA already encodes at import.

## Gate B windowed run

2026-11-08, HEAD `3a2a216` plus the coordinator's uncommitted `sound_cues.gd` cannon `gain_db` -3.8 (user ruling at Gate B, tank shot equal to a rifle burst). Approval: the user approved the windowed run and was at the PC with sound on. Gate B windowed run executed, verdicts pending from user. Scratch scenes (not in the repo): `$SCRATCH/gate-b/fight.gd`, `ab.gd`, `fight2.gd` (session scratchpad), logs beside them.

- `fight.gd` (real `skirmish.tscn`, 9 steps: centre, edge, 20/30/40 cells, zoom 0.5 and 2, mix with music): exit 0, no `ERROR` except the music-stream leak at exit. Logged distances: centre 0.9, edge 14.3 cells, 20.0, 30.0, 40.0; 1224 shots, 11 deaths.
- `ab.gd` (8 voice lines and cannon, rifle_burst, explosion, IMPORTED QOA then RAW): exit 0, no `ERROR`. No Max Rate A/B (Max Rate off at Gate A).
- `fight2.gd` (5 steps, 15 s, music on for steps 1-2): exit 0; steps and cannon -3.8 logged. Expected attenuation at ATTENUATION 0.5, MAX 1145 px (computed, not measured): 0.9 cells -0.1 dB, 10 cells -1.6 dB, 20 cells -4.3 dB, 30 cells -12.0 dB. Zoom does not enter the listener distance. Each run ended with "N resources still in use at exit" (Ogg/WAV streams of a scratch `SceneTree` script that quits directly), not a game error.
- After the cannon change: suite CASES 558 CHECKS 136828 FAILURES 0, TESTS PASSED, exit 0; lint exit 0; warnings exit 0.
- Verdicts (falloff, zoom, QOA vs raw, mix, tank loudness): pending from user.

Rendered benchmark, 2026-11-08, `sh tools/run_game.sh res://scenes/movement_benchmark.tscn` (Apple M6, Compatibility, 1280x720, zoom 0.5, header `vsync=off`, load 2.0 to 2.1), RENDERED BENCHMARK PASSED 4:

| mode | frame p50 / p95 / p99 / max (ms) | tick p95 (ms) | draw calls | budget |
|---|---|---|---|---|
| open | 0.573 / 1.818 / 3.348 / 9.113 | 1.905 | 5 | 16.7 pass |
| dense | 0.584 / 1.974 / 3.397 / 12.575 | 1.921 | 6 | 16.7 pass |
| ashfall | 0.827 / 2.594 / 5.382 / 13.274 | 2.24 | 45 | 3.04 budget, guard 3.3: pass |
| horde | 0.989 / 11.11 / 19.231 / 26.278 | 9.395 | 239 | reported, not gated; ledger 3.40-3.86 earlier, this run is about 3x higher with cumulative lag 0.75 ticks (not explained; load 2.0 from other sessions; reported, not loosened) |

Performance ledger not edited.

## Task 7 (headless and rendered parts)

2026-11-08, tree: working tree on `spike-sound` at 8520781 plus uncommitted: `release.yml` extras gains `game/audio/CREDITS.md`; `game/tests/test_sound.gd` SD23 calls `AudioSettings.apply(DEFAULTS)` itself (it relied on an earlier case having applied; no isolated mutation run, the suite is sharded); `movement_benchmark.gd` `--sound` mode.

- Step 1: actionlint v1.7.12 exit 0, no output; `python3 tools/test_package_release.py` 6 tests OK.
- Step 2: trace check into `$SOUND_WORK/traces/t7`: suite CASES 559 CHECKS 136840 FAILURES 0 (with traces), TESTS PASSED, exit 0; netplay `match` PASSED tick 8400; replay, economy, combat MATCHED 1200; team MATCHED 100; netplay s1 MATCHED 281. Without trace vars, after the `--sound` edit: CASES 559 CHECKS 136833 FAILURES 0, TESTS PASSED, exit 0. Lint exit 0; warnings exit 0 (114 files); python checks exit 0.
- `--sound` mode: `-- --sound` starts at the horde layout, adds `SoundPlayer(1)` with real rules, `collect_step` after each step, `update` per frame inside the sample window, prints `RENDERED SOUND cues=<n> update_p95_ms=<x>`, fails when cues == 0. No separate red test (benchmark scene, not in the suite); the cues==0 failure path was not exercised.
- `sh tools/run_benchmark.sh` alone (no godot running; uptime 1.46 start, 1.25 end after waiting for load < 1.5): exit 0; BENCHMARK PASSED 2, COMBAT BENCHMARK PASSED 10, LOCKSTEP PASSED 1 (p99 0.066 ms, limit 0.6), every BUDGET line PASS. Headless open tick p95 0.682 / p99 0.84 ms, dense 0.671 / 0.88.
- Rendered `sh tools/run_game.sh res://scenes/movement_benchmark.tscn` (window, sound on, 1280x720, vsync=off, load 1.52 at start, 2.35 at end), RENDERED BENCHMARK PASSED 4, frame p50 / p95 / p99 / max ms: open 0.364 / 0.635 / 3.254 / 8.388; dense 0.591 / 1.929 / 3.645 / 9.884; ashfall 0.829 / 2.725 / 3.893 / 14.526 (guard 3.3 pass); horde 0.84 / 5.766 / 8.239 / 21.215, tick p95 4.95 ms, draw calls p95 238. Earlier Gate B row (load 2.0): open 1.818, dense 1.974, ashfall 2.594, horde 11.11. Horde 5.766 is above the ledger's 3.40-3.86 and below the loaded 11.11: part load, part not explained; reported, not loosened (horde has no gate).
- Rendered `-- --sound` (horde only, load 1.99 start, 2.61 end): exit 0, `RENDERED SOUND cues=1437 update_p95_ms=0.292`; frame p50 / p95 / p99 / max 1.129 / 6.094 / 9.265 / 19.613 ms, tick p95 4.741 (against 5.766 frame p95 without sound in the run above: +0.33 ms, within run-to-run noise at this load). `.pck` growth from Task 3 (1,138,288 to 12,938,240 bytes, Max Rate off). Ledger row not written (not edited by instruction).
- `--sound` failure path proved (2026-11-08, window run alone): `collect_step` disabled by a scratch mutation of `movement_benchmark.gd` line 197, same command printed `ERROR: RENDERED SOUND cues=0`, exit 1; restored by `git checkout` (tree clean again).
- Ledger row written in `performance.md` History (no budget changed). Horde frame p95 5.766 ms is exceeded against the ledger's 3.40-3.86 ms, unexplained. Quiet-host horde rerun not done: load stayed 1.96-2.4 from other sessions (needs under 1.5).
- `/ponytail-review` on `git diff main...HEAD` (audio bytes excluded): no cuts made. Declined: `collected_ticks`, `consumed_ticks`, `pending_step` on `SoundDirector` are only read by tests but those tests (SD1, SD1b, SD3, AN) pin the bounded queues; the per-cue `jitter` and `ui` fields in `CUES` are used (jitter by the director, one cue uses it). No `game/` file changed after the last green suite, so no rerun.
- Not done: Step 4 web check, Step 5 playtest (user), then push and CI approval (Step 6).

- 2026-11-08 later (tree f23fddb, clean): quiet-host horde rerun, full rendered benchmark alone, load 1.51 start / 2.18 end (never under 1.5 for long; marked mildly loaded), RENDERED BENCHMARK PASSED 4: horde frame p95 3.859 ms, tick p95 4.621 ms (ledger row edited). CI run 42494796493 on f23fddb: FAILED. Green: Linux and Windows Tests, Lint, Relay, Workflows, Docker, Tools Python lint and tests. Failed: Exported build (linux) and (windows), both `CASES 559 CHECKS 136823 FAILURES 31`, all in SD5 (`test_sound.gd:115-116`): `FileAccess.file_exists(Cues.path(...))` is false for every sound file in the exported pack (imported `.wav` is remapped, original path absent); fix would be `ResourceLoader.exists`. Not fixed (report only). No Godot --import crash (exit 134 / propagate_notification) in any job; export step itself succeeded. Compare replays skipped, so `compare_local_traces.sh` not run.

- 2026-11-08 SD5 export fix (tree f632214 plus uncommitted `game/tests/test_sound.gd` lines 115-116: `FileAccess.file_exists` -> `ResourceLoader.exists`). Local reproduction with the installed 4.7.2 templates: `macOS Tests` preset exported to the scratchpad, run as CI does (`WARGRID_TEST_EXE`): unfixed CASES 559 CHECKS 136816 FAILURES 31 (all SD5), fixed FAILURES 0, exit 0. Editor suite CASES 559 CHECKS 136833 FAILURES 0; lint and warnings exit 0. Audit of `game/scripts` and `game/tests`: no other `file_exists`/`DirAccess` on imported audio; runtime uses `load()` (remap-aware). Linux/Windows CI exports not rerun here (macOS pack only).

- 2026-11-08 (user): Task 7 Step 4 web check done in Firefox on the local export (`sh tools/export_build.sh Web web/site/index.html`, served on 127.0.0.1:8060, tree 0579236). User verdict: "soundwise everything perfect". Console errors were not reported separately; not inspected by the coordinator. Step 5 playtest (offline and online) still open.

- 2026-11-08 (user): after the web check the USA tank sounded too quiet. Labelled A/B in Firefox (cannon at 0 / -1.5 / -2.5 / -3.8 dB against an unchanged rifle burst); user picked B (0) or D (-1.5). Chose -1.5: `sound_cues.gd` cannon `gain_db` -1.5. Effects bus -6 dB unchanged.
- 2026-11-08 (user, playing): -1.5 dB tank still hard to hear while infantry fire is mixed; tried B (0 dB). `sound_cues.gd` cannon `gain_db` 0.0, pending user verdict.
- 2026-11-08 (user): cannon 0 dB accepted ("very good now"). Zero Hour comparison from retail INI and wav loudness (SoundEffects.ini, ebur128; not heard through a measurement, Miles gain assumed linear): Crusader 90 / -13.5 LUFS, Ranger 60 / -12.6, RedGuard 95 / -21.5, Battlemaster 85 / -10.8; effective tank minus Ranger +2.6 to +3.5 dB, minus RedGuard +7.6 dB. Ours: cannon -26.6 LUFS, rifle_burst -28.9, carbine -31.1 (all gain 0), cannon +2.3 over rifle_burst, +4.5 over carbine. The earlier note's +3.8 (Crusader vs Ranger) was the 90/60 ratio only. User listened to the original windowed, no recording (no loopback device; BlackHole/microphone declined). Wizard rulings: carbine stays 0 dB, no per-shot volume variation, rifle limits stay 4. No further INI-based tuning.
- 2026-11-08 (user): Step 5 playtest marked done (offline by ear; online covered by tests N6 and the rejected() wiring, not heard). A friend is playtesting; their sound findings are open input. Final suite: 559 cases, 136833 checks, 0 failures; lint 0, warnings 0 on 8653dc3.
- 2026-11-08: full-branch Opus review of main...13f7c03 (audio bytes excluded): no Critical. Fixed: deploy_web.sh now ships CREDITS.md and README names it; README test count; SD5 vehicle_death check (the 'has a death cue' check was vacuous); SD22 checks a Music player (mutation: commenting out add_child(music) in skirmish_main.gd fails it). Not fixed: UI click wiring (sound_player.gd:45-46) has no test; M is swallowed while the Esc menu is open (main.gd:88, Mute button works); OpenGameArt licence pages not re-fetched (403). Suite 559 / 136844 / 0 failures; lint and warnings 0. User ruled: no merge to main without his confirmation.
- 2026-11-08: CI run 42510956106 (4d8e4eb) failed only in Tools Python tests (test_deploy_web fixture lacked CREDITS.md after the deploy_web.sh change; python checks had not been run after that edit). Fixed in 251aee8. CI run 42511754481 on 251aee8: success, all jobs green; compare_local_traces.sh: replay, economy, combat MATCHED 1200, team 100, netplay 281. Merge to main waits for the user's confirmation.

# M2 local verification — 2026-11-02

Status: **LOCAL IMPLEMENTATION AND REMOTE MATRIX VERIFIED; POSITIVE USER PLAYABILITY; RENDERED BENCHMARK PASSES WITH VSYNC OFF (frame p95 3.6 / 5.1 ms vs 16.7 ms budget), 19.6 / 19.5 ms WITH VSYNC ON; BACKLOG FIXED (2026-11-03, see end); SIMULATION BUDGETS PASS**. Contracts live in [M2 plan](../superpowers/plans/2026-11-01-m2-groups.md). This is not full M2 acceptance or reference parity. User explicitly accepted risk from deferring remaining M2 visible/play/rendered/backlog gates and kicked off M3 on2026-11-03. [Verified matrix41591616563](https://github.com/pdstuber/wargrid/actions/runs/41591616563), head `4be6b7b`, passed Linux/macOS/Windows and replay comparison. No M3 changes covered by that run; [M3 evidence](m3-verification.md) records current work. No window, screenshot or rendered benchmark launched.

## Recovery and behavioral evidence

Resumed `m2-groups` at `7b70a61` with substantial uncommitted work. Preserved existing tracked/untracked changes. No existing Godot/test/Grok worker was running. Original interruption cause remains unknown; no interrupted review counted as completed.

Fresh baseline `sh tools/run_tests.sh`: **54 cases / 95,914 checks / 42 failures / exit 1**, no success marker, no engine diagnostics. Failures reproduced view picking/order and scene/group-input stubs. Tasks 0–4 retained inherited completion status; this run did not recreate their historical red/mutation evidence. Existing tests remained intact.

Task 5 finished existing implementation in place: copied/sorted view state, inclusive projected-anchor rectangle picking, reverse draw-order click picking, 20-unit scenario, release/Shift selection, drag threshold/cancel/camera freeze, one sorted group command, status counts and occupied-safe B obstruction toggle. First green: **54 cases / 95,946 checks / zero failures / exit 0**, `TESTS PASSED 95946`. Intermediate typed-Array ternary error was diagnosed and fixed with typed clear/assign; assertions unchanged.

Task 6 added statistics, authored fixtures and settlement checks. Minimal stubs failed **57 cases / 96,349 checks / 156 failures / exit 1**, only BM cases. New progression check then exposed float32 accumulation: ten 0.1-unit steps near x=52 failed existing 1e-5 distance/arrival contract. Dedicated M9 64×64 regression also failed before fix: full suite **58 cases / 96,952 checks / six failures / exit 1** (M9 plus dependent BM3 checks). `_advance` now computes position/distance using scalar float coordinates already stored in snapshot arrays. Speed, waypoint logic, tick phases and 1e-5 tolerance unchanged. Regression and full suite then passed **58 / 96,952 / zero failures / exit 0**, `TESTS PASSED 96952`. Old floating-point trace values intentionally change; comparisons remain exact, never rounded.

Inherited assertion migrations remain deliberate M2 changes: snapshot literals add destination/path_queue; C12 checks distinct assigned goals while retaining original anchor, ownership, canonical IDs and movement/copy checks. Scene tests use release selection and expect 20 starts; no single-unit compatibility mode. No assertions removed or tolerances widened during continuation.

## Final headless verification

Engine: `4.7.2.stable.official.ed1daf0bf`. Commands actually executed via test delegate:

| Check | Result |
|---|---|
| `sh tools/run_tests.sh` | 58 cases / 96,953 checks / zero failures / exit 0; `TESTS PASSED 96953` |
| Outside-root absolute wrapper, with `WARGRID_REPLAY_TRACE` | 58 / 96,955 / zero failures / exit 0; `TESTS PASSED 96955` |
| Fresh scratch copy without `.godot`, with trace | Same 58 / 96,955 / zero failures / exit 0 and marker |
| Rosetta x86_64 universal engine wrapper, with trace | Same 58 / 96,955 / zero failures / exit 0 and marker |
| `python3 tools/compare_replays.py <native-outside> <native-fresh> <rosetta>` | Exact digests match all 1,200 sequential ticks in three files; exit 0 |
| `python3 -m unittest discover -s tools -p 'test_compare_replays.py'` | Six tests, `OK`, exit 0 |
| `sh -n tools/run_benchmark.sh` | Exit 0 |
| `godot --headless --path game --quit-after 30` | Exit 0, no diagnostics |
| `git diff --check` | Exit 0 |

Trace output adds two file-write checks, explaining 96,955 versus ordinary 96,953. Fresh-cache copy was `/tmp/wargrid-m2-mutation.6ytyoa_2`; exact scratch names are disposable. Headless import parsed visible probe scripts, but probe scene was never launched. Test runner/wrapper behavior unchanged; historical runner-failure probes were not repeated. New benchmark wrapper follows same checked import/exit/diagnostic/positive-marker pattern.

Raw logs and traces are outside tracked source under `.superpowers/sdd/2026-11-01-m2-groups/`; scratch is not required to run repository. Key logs: `baseline-tests.log`, `task5-green.log`, `task6-red.log`, `task6-precision-red.log`, `task6-precision-green.log`, `post-review-normal.log`, `post-review-outside.log`, `post-review-fresh.log`, `post-review-rosetta.log`, `final-smoke.log`, `final-benchmark-verified.log`.

## Measured simulation workload

Command: `sh tools/run_benchmark.sh`, **exit 0**, `BENCHMARK PASSED 2`, no engine diagnostics. Marker proves two valid workloads completed, separate from hardware budget results. Each layout emitted `BUDGET PASS ... simulation_only`.

Host: Mac mini `Mac18,5`, Apple M6, 12 CPU cores (2 Super / 4 Performance / 6 Efficiency), 32 GB RAM; macOS 27.2 build `26B123`; AC power, `lowpowermode 0`. Same development Mac for both layouts. Engine/build as above. Seed: `none` (authored deterministic workload). No external data/dependencies.

Each layout uses 64×64 map and 300 units. Open map has no solids; dense map has three walls with authored gaps. Exact positions/gaps/anchors live in plan and shared workload rather than duplicated values here. Alternate full group legs after all arrive. Per layout: 300 warmup ticks + 1800 measured ticks = **10 + 60 seconds simulated time, unpaced**. This is not 60 seconds measured wall-clock time. Tick timing includes settlement inspection, any command submission/allocation and simulation step; excludes telemetry snapshots and rendering. Command sample distribution covers all command ticks, including warmup, to expose worst burst. Post-sample drain is excluded from timing percentiles.

Latest measured run:

| Layout | Samples | p50 ms | p95 ms | p99 ms | Max ms | Command samples / max ms |
|---|---:|---:|---:|---:|---:|---:|
| open | 1800 | 0.801 | 1.310 | 1.369 | 7.954 | 3 / 7.954 |
| dense | 1800 | 0.820 | 1.330 | 1.385 | 7.458 | 3 / 7.458 |

Both satisfy proposed simulation p95 ≤8 ms and p99 ≤16 ms on recorded Mac. Worst ticks remain shown. Each layout: post-service path-queue peak 292, initial queue drain 38 ticks, three completed legs after final drain. At timed endpoint all 300 moving, zero pending/blocked/arrived; active motion did not disappear into idle timing. Post-sample drain: 576 ticks. Final: 300 arrived, zero moving/pending/blocked, 300 unique destination cells. Benchmark fails on blocked units, missing samples/destinations or leg exceeding 3000 ticks; no autonomous blocked restart.

Visible probe is implemented in `movement_benchmark.gd` / `movement_benchmark.tscn`: same workload/view, one step per 30 Hz physics callback, 10 wall-clock seconds warmup then 60 sampled per layout, frame intervals separate from tick including snapshot/view refresh, expected resolution 1280×720 and zoom0.5, actual ticks/elapsed and cumulative lag in 10-second windows. **Not executed.** No growing-backlog or rendered p95≤16.7 ms result exists. At this measurement checkpoint, manual playability remained unverified; subsequent user evidence is recorded below.

## Review and remaining gates

Installed Grok read-only M2 review stalled over20 minutes without report; process terminated17:12 CET, exit143. It does not count as completed review. Single fresh-context fallback reviewer (GPT-6 Astra, high reasoning) completed whole-tree M2 review: **no consequential findings; ready for authorized local handoff with acceptance gates pending**. Reviewed connected tracked/untracked simulation, navigation, allocation, presentation, input, benchmarks, replay tooling, CI and tests; no M3 implementation found. No second substantive review. Reviewer did not rerun delegated tests or independently validate hardware measurements.

Review noted S8's preexisting HUD-nonempty assertion alone could not establish obstacle rejection-message quality. Preserved it and added separate exact-reason assertion; scratch mutation clearing only toggle error produced exactly one failure (`S8 occupied toggle rejection reason`): 58 cases / 96,953 checks / exit1. Original production was untouched. Restored scratch and final tree passed normal58/96,953 and all three trace-suite variants58/96,955, zero failures/exit0; exact1200-tick comparison and Python6 tests also passed. No production change followed benchmark measurement. No production change from review. R2 validates hash infrastructure, while identical wrong behavior can pass replay equality; named scenario tests supply gameplay checks.

Final `/ponytail-review` cuts pass performed by executor on same M2 diff, limited to overengineering after substantive review. **No warranted cuts, zero deferred findings.** Fixed authored fixtures, existing helpers and separate debug clocks avoid new frameworks/dependencies; required copied snapshots and boundary validation retained. No second substantive reviewer.

Reviewer declined to judge: visual clarity/resize/play and travel-overlap usability; rendered probe runtime/frame timing/backlog; actual cross-OS CI; retail fidelity; hardware measurements beyond delegated record. These remain explicit pending gates/limits, never passes.

### Test mutation mapping

Inspection-based mappings from completed substantive reviewer; not executed mutation tests. S8 feedback mutation below is separately executed.

| New case | Production mutation expected to fail it |
|---|---|
| G1 allocation | Remove ID sorting, reverse y/x tie order, or replace exact boundary target with center. |
| G2 partial/copy | Permit another member's occupied cell, reuse candidate, ignore unavailable cells or reject zero-coordinate target. |
| G3 thirty arrivals | Share destinations, route through building or stop advancing before arrival. |
| G4 reservations | Ignore cross-owner reservations, permit occupied/reserved spawn or shallow-copy destinations. |
| G5 replacement release | Allocate superseded IDs, release on future submission or retain old applied reservation. |
| G6 partition | Allocate disconnected member or let it consume eligible member's slot. |
| G7 path budget | Service nine requests, reverse FIFO, move waiting units, omit serviced same-tick motion or retry unreachable orders. |
| G8 queued retarget | Keep stale/duplicate queue entries, consume invalid sequence, expose queue alias or starve waiting IDs. |
| G9 queue replay | Return internal queue: caller snapshot mutation alters later execution. |
| RP1 repath | Keep stale route, teleport or retain caller blocker-array alias. |
| RP2 disconnect | Retain disconnected order, auto-revive blocked unit or keep blocked reserved goal active. |
| RP3 validation/future | Apply occupied/outside edit, rebuild on equivalent layout or skip future-target revalidation. |
| RP4 queue replay | Requeue only old pending units, retain routes, change sorted rebuild or expose map/queue aliases. |
| R1 trace | Change tick progression, mutate repeated replay or lose invalid rejection; identical wrong gameplay may still match. |
| R2 exact hash | Round coordinates or omit nested map from hash helper. Infrastructure test. |
| BM1 statistics | Wrong percentile rank, input sorting in place or missing empty/single behavior. |
| BM2 fixtures | Wrong starts/count/map/wall gaps, disconnected anchors or incomplete first group command. |
| BM3 progression | Restart early, count idle/blocked as settled, reuse target/sequence or restore float32 drift. |
| N6 sized map | Retain 16×16 routing/bounds for 64×64. |
| N7 components | Skip gap rebuild, include solids, omit sorting or expose component cells. |
| N8 replacement | Leave removed solids, omit new solids or retain duplicate/noncanonical/input-aliased blockers. |
| M9 far coordinates | Restore float32 accumulation, breaking ten-tick distance/thirty-tick arrival. |
| V2 box/order | Omit normalization/inclusive edges/ownership, alias selection, pick forward or ignore depth. |
| S6 boxes | Wrong canvas transform/reverse drag, Shift replacement, duplicate IDs or multiple commands. |
| S7 drag rules | Select on press, alter threshold/max excursion, allow camera/right order during drag or select after Escape. |
| S8 obstacle toggle | Wrong cells, occupied edit, toggle flip after rejection; added reason assertion detects hidden error. |
| Python matching | Reject valid equal 1200-row input or require wrong format/count. |
| Python divergent tick | Ignore mismatch or report wrong first divergent tick. |
| Python missing file | Silently skip unavailable platform file. |
| Python truncated | Compare shared prefix without requiring all1200 rows. |
| Python invalid tick/digest | Accept duplicate/skipped ticks or nonhex digest. |
| Python three platforms | Accept only two files. |

Historical local checkpoint above preceded publication. Current Linux/Windows/macOS M2 matrix success is linked in status; no new publication performed in M3 task. Same-host native/Rosetta exact replay does not prove cross-OS determinism. Historical successful M1 runs on `7b70a61`: [M1 branch](https://github.com/pdstuber/wargrid/actions/runs/41322464510), [M2 branch baseline](https://github.com/pdstuber/wargrid/actions/runs/41466145349), neither verifies current M2 tree.

[Group reference](group-movement.md), [movement gaps](zero-hour-movement-gaps.md) and [M1 validation](m1-validation.md) preserve `UNVERIFIED_REFERENCE` / historical labels. Distinct goals and eight whole queries differ from EA implementation; no retail runtime parity, physical collision, formation or numeric calibration claim. No new EA source/assets copied. M3 was subsequently explicitly kicked off with deferred-gate risk accepted; current checkpoint linked above.

## User playability confirmation — 2026-11-03

User explicitly reported M2 playability check was positive. Manual playability is supported by this report; no itemized checklist or timing data supplied. Rendered frame-time and real-time backlog measurements remain pending. Earlier deferred/unknown manual labels describe historical checkpoints, not this current evidence. No new agent-launched window or test run.

## Rendered benchmark — 2026-11-03

Two user-authorized visible runs of `sh tools/run_game.sh res://scenes/movement_benchmark.tscn`, Apple M6 (12 cores, 32 GiB), macOS 27.2, Godot 4.7.2, Compatibility renderer over OpenGL-on-Metal, 1280×720, zoom 0.5. Logs are temporary scratch outside the repo.

**Attempt 1: invalid, measured nothing.** `movement_benchmark.gd` passed an untyped `[]` to `WorldView.set_state(…, Array[int])` (bug since M2 commit `a23f697`). Every physics tick raised SCRIPT ERROR after `step()`, so tick counters stayed at 0 and the reported "backlog" (300 ticks per window) was an artifact. The run exited 0 because `run_game.sh` checks no marker. Regression `test_rendered_probe_ticks` (instantiates the benchmark scene, awaits two physics frames, requires the HUD status text) failed red, then passed after typing the empty selection: 96 cases / 101,306 checks / zero failures / exit 0, 4.4 s wall including import.

**Attempt 2: completed, `RENDERED BENCHMARK PASSED 2`, exit 0, zero ERROR lines. Completion does not mean budgets pass.**

| Layout | Rendered frames in 60 s | Frame interval p50 / p95 / max (ms) | Sim tick p95 (ms) | Physics ticks in 60 s (1800 expected) | Cumulative lag after final 10 s window |
|---|---:|---|---:|---:|---:|
| open | 205 | 291.0 / 320.2 / 325.6 | 4.67 | 1640 | 140 ticks |
| dense | 189 | 319.5 / 340.0 / 352.6 | 4.76 | 1512 | 244 ticks |

- **Frame budget (p95 ≤ 16.7 ms) FAILED by about 20×.** About 3 frames per second.
- **Backlog grows:** lag climbs in every 10 s window, and simulated time ran at roughly 0.84–0.91× real time. Cause: Godot runs at most 8 physics steps per rendered frame (default); at about 0.3 s per frame that caps simulation near 27 ticks/s.
- Simulation cost is unchanged and fine (tick p95 under 5 ms, including snapshot and view update), so this is a presentation problem. It does not change the passing headless simulation budgets.

**Investigation (headless, no window; scratch script, not committed).** `_draw` does run headless. Time spent inside `WorldView._draw` (20 redraws, same 300-unit workload): open 3.2 ms, dense 5.5 ms; with the 64×64 terrain loop removed 0.35 ms; terrain polygons only 3.0 ms (open), 4.6 ms (dense); `set_state` (deep copy plus sort) 1.7–1.9 ms. So GDScript-side drawing is a few ms and cannot explain the ~260 ms per frame (frame ≈ 290 ms minus 8 ticks × 3 ms). Remaining cost sits on the renderer side. **Rendered probe (user-approved one-off visible window, same machine, scratch script not committed; vsync off, one forced redraw per frame, 20 frames per variant, default zoom, no camera/HUD):**

| Variant | Frame p50 open / dense (ms) | Time inside `_draw` open / dense (ms) |
|---|---|---|
| current `_draw` | 78.3 / 82.3 | 16.8 / 19.7 |
| terrain only (current loop) | 76.8 / 79.6 | 16.5 / 19.4 |
| terrain polygons only (no outlines) | 42.0 / 44.6 | 10.2 / 12.7 |
| no terrain (units only) | 1.7 / 1.7 | 0.24 / 0.24 |
| candidate: one base polygon, polygons for solid cells only, one `draw_multiline` for the grid | 1.8 / 2.6 | 0.26 / 0.46 |

Finding (measured): the per-tile terrain loop is the cost. About 8,200 canvas commands per redraw, with the renderer side adding roughly 60 ms beyond the time spent in `_draw`; units cost almost nothing. Outlines account for about half. The candidate cuts frame cost by about 30-45× and renders the same terrain (same colors, grid and solid cells) by construction; visual equivalence not yet looked at. Absolute probe numbers (about 80 ms) are lower than the benchmark's 290 ms, which also runs 8 physics steps per frame with `set_state` calls, zoom 0.5, camera and HUD; the gap is unexplained, so the fix must be confirmed by rerunning the real rendered benchmark, not by this probe. Fix applied afterwards; see next section.

**Impact on M3/M4:** the base scene draws the same terrain loop on its smaller map; user reported no visual issues there, but its frame rate was never measured. M4's 48×32 map has 1,536 tiles (37% of 64×64); the same loop would cost about 30 ms per frame by linear scaling of the probe numbers (unmeasured), already beyond the 16.7 ms budget.

### Terrain fix and rerun — 2026-11-03

`WorldView._draw_terrain` now draws one base polygon, polygons for solid cells and one `draw_multiline` for the grid (same colors and cells) instead of two canvas commands per tile. Headless suite after the change: 96 cases / 101,351 checks / zero failures / exit 0 (101,306 before the builder speed change to 1.2, 101,351 after; confirmed by testing the commits separately: the +45 checks come entirely from the builder speed change, most likely per-tick check loops running longer with a slower builder; see [verification plan](zero-hour-verification.md)). Visual equivalence not yet looked at by a person.

Third visible run of the real benchmark, same machine and settings (attempt 3): exit 0, `RENDERED BENCHMARK PASSED 2`, zero ERROR lines.

| Layout | Rendered frames in 60 s | Frame interval p50 / p95 / p99 / max (ms) | Sim tick p95 (ms) | Physics ticks in 60 s | Cumulative lag, final window |
|---|---:|---|---:|---:|---:|
| open | 7,177 | 7.5 / 19.6 / 20.8 / 40.8 | 5.70 | 1800 | +0.07 ticks |
| dense | 7,054 | 8.1 / 19.5 / 21.8 / 28.2 | 4.71 | 1800 | -0.11 ticks |

- **Backlog budget: passes.** All 1800 expected ticks ran; lag stays within ±0.5 ticks in every window.
- **Frame-interval budget (p95 ≤ 16.7 ms): still FAILS by about 3 ms.** Typical frames are fast (p50 about 8 ms). The p95 tail is probably the frames that also run a physics tick (tick 3.4-4.3 ms median including snapshot and view `duplicate(true)` plus redraw), at about one frame in four. Not profiled; vsync quantization on the display's refresh rate could also contribute and is unchecked. Budget unchanged, no tuning.
- Worst command-tick spike 26.6 ms (open): present before the fix, not investigated.

### Frame-tail investigation — 2026-11-03

Question: why does frame p95 stay at 19.5 ms after the terrain fix. Scratch probes only (not committed); same machine, two more user-approved visible windows (the first being the vsync-off terrain probe above, the second a 30 s frame probe on the real benchmark scene, vsync at the project default).

- **Simulation plumbing is cheap and not the tail.** Headless per-tick breakdown over 1,800 ticks, 300 units: `step` p50 0.32 ms (one spike 7.3 ms on a command tick), `snapshot` 0.69 ms, `duplicate(true)` in `set_state` 0.67 ms, entity sort 0.57 ms, `issue_leg` 0.5 ms. About 2.3 ms per tick, 30 ticks/s. M4 snapshots add combat fields, so expect this to grow; unmeasured.
- **The engine reported 60 Hz display, vsync on, scale 2.0, 1280×720; actual frame rate about 120 fps** (3,599 frames in 30 s; 900 of them physics-tick frames).
- **Tick frames dominate the tail.** Frame interval p50/p95/p99: tick frames 17.7 / 20.1 / 21.0 ms; idle frames (no tick, no redraw) 3.3 / 11.1 / 12.2 ms. Splitting at the engine's own `frame_pre_draw` / `frame_post_draw` signals: tick frames spend 13.4 ms (p95 13.9) inside the render submission step, idle frames 3.3 ms. Render CPU time is about 1 ms in both, and the next frame's physics tick (about 4.4 ms) shows up in the following gap. So the extra time is spent waiting, not computing. GPU time is not reported by this renderer (0.00).
- **Likely cause (not proven):** vsync pacing, not drawing cost. Earlier probe with vsync disabled and a forced redraw every frame: the full units-plus-candidate-terrain frame cost 1.8 ms open / 2.6 ms dense. The same content costs 13 ms in a tick frame with vsync on. Not yet tested directly: rerun the benchmark with vsync disabled and compare; also check what a 60 Hz versus 120 Hz display pacing does to "p95 ≤ 16.7 ms" as a budget (with vsync on, the interval is quantized to display refresh multiples, so the budget may not measure render cost at all).
- Monitors `TIME_PROCESS` / `TIME_PHYSICS_PROCESS` update once per second and were useless per frame; probe `script` bucket is zero because `process_frame` fires after physics; neither is evidence.

### Vsync-off rerun — 2026-11-03

Fourth visible run of the real benchmark, `sh tools/run_game.sh --disable-vsync res://scenes/movement_benchmark.tscn` (engine flag; no repo change), same machine and settings. Exit 0, `RENDERED BENCHMARK PASSED 2`, zero ERROR lines. The flag's help says it does not override driver-level vsync enforcement; the numbers below show it took effect.

| Layout | Rendered frames in 60 s | Frame interval p50 / p95 / p99 / max (ms) | Sim tick p95 (ms) | Physics ticks | Cumulative lag, final window |
|---|---:|---|---:|---:|---:|
| open | 46,662 | 1.2 / 3.6 / 6.6 / 14.7 | 4.48 | 1801 | +0.07 ticks |
| dense | 32,890 | 1.5 / 5.1 / 9.0 / 15.8 | 4.73 | 1800 | +0.10 ticks |

- **Frame budget (p95 ≤ 16.7 ms): passes in both layouts with vsync off; max frame 15.8 ms also under 16.7.** Backlog budget passes as before.
- **Conclusion:** the 19.5 ms tail with vsync on was display pacing, not drawing or simulation cost. Likely mechanism, consistent with every measurement but not directly verified: Godot presents a frame only when something redrew, and a presented frame waits for the next vblank, so tick frames (the only ones that redraw) absorb up to one refresh interval, while idle frames skip presenting.
- **Caveats:** one Apple M6 machine, one display. Whether a vsynced run feels smooth was not assessed here (user reported no visual issues in earlier playtests, which ran with vsync on). Linux/Windows and other refresh rates unmeasured.
- **Open decision:** make the benchmark scene disable vsync itself, so the gate measures render cost reproducibly, or keep the default and document the flag. Not changed; the budget text is unchanged.

### Benchmark scene disables vsync itself — 2026-11-03

User decided the rendered benchmark should run without vsync. `movement_benchmark.gd` now calls `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)` in `_ready` and prints `vsync=off` in its header. No automated check: the headless dummy display driver does not report the mode back (a test asserting it failed even after the fix, so it was removed rather than kept unfalsifiable); evidence is the header plus the frame numbers. Suite after the change: 96 cases / 101,351 checks / zero failures / exit 0.

Fifth visible run, plain `sh tools/run_game.sh res://scenes/movement_benchmark.tscn` (no flag), same machine: exit 0, `RENDERED BENCHMARK PASSED 2`, zero ERROR lines, header shows `vsync=off`, physics ticks 1800/1800 per layout, final-window lag +0.10 ticks.

| Layout | Rendered frames in 60 s | Frame interval p50 / p95 / p99 / max (ms) | Sim tick p95 (ms) |
|---|---:|---|---:|
| open | 44,871 | 1.2 / 4.1 / 6.4 / 13.1 | 4.56 |
| dense | 30,005 | 1.6 / 6.5 / 10.2 / 19.5 | 4.79 |

p95 budget (≤ 16.7 ms) passes in both layouts. **Dense max frame 19.5 ms exceeds 16.7 ms** in one frame; the budget is defined on p95, so this is not a failure, but it is recorded. Single machine and display; a fast machine, so margin on slower hardware is unknown.

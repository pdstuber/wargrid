# M2 local verification — 2026-11-02

Status: **LOCAL IMPLEMENTATION AND REMOTE MATRIX VERIFIED; VISIBLE/RENDERED/BACKLOG ACCEPTANCE DEFERRED**. Contracts live in [M2 plan](../superpowers/plans/2026-11-01-m2-groups.md). This is not full M2 acceptance or reference parity. User explicitly accepted risk from deferring remaining M2 visible/play/rendered/backlog gates and kicked off M3 on2026-11-03. [Verified matrix41591616563](https://github.com/pdstuber/wargrid/actions/runs/41591616563), head `4be6b7b`, passed Linux/macOS/Windows and replay comparison. No M3 changes covered by that run; [M3 evidence](m3-verification.md) records current work. No window, screenshot or rendered benchmark launched.

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

Visible probe is implemented in `movement_benchmark.gd` / `movement_benchmark.tscn`: same workload/view, one step per 30 Hz physics callback, 10 wall-clock seconds warmup then 60 sampled per layout, frame intervals separate from tick including snapshot/view refresh, expected resolution 1280×720 and zoom0.5, actual ticks/elapsed and cumulative lag in 10-second windows. **Not executed.** No growing-backlog or rendered p95≤16.7 ms result exists. Group feel, temporary overlap acceptability, pan/zoom/resize and selection legibility remain unverified.

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

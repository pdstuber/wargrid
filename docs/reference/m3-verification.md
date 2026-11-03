# M3 verification — 2026-11-03

Status: **HEADLESS AND CROSS-OS CI VERIFIED; POSITIVE USER PLAYTEST; DETAILED VISIBLE/PERFORMANCE/PARITY GAPS REMAIN**.

## Authorization and inherited gates

User explicitly kicked off M3 on prepared `m3-base-supplies` at `d7acea9` and accepted risk from deferring remaining M2 visible play, rendered-frame and real-time backlog gates: "yeah let's run with the risk recorded". Gates remain pending, never passed. [M2 evidence](m2-verification.md) retains local correctness/review/performance. Parent independently verified [M2 matrix41591616563](https://github.com/pdstuber/wargrid/actions/runs/41591616563), head `4be6b7b`: Linux, macOS, Windows and replay comparison successful. That run covers M2, not M3 changes.

During implementation, user chose headless M3 checks after one batched visible request; no agent window, screenshot or rendering-dependent check was performed. Subsequent publication, user playtest and local merge approval are recorded below. No M4.

## Sequential execution evidence

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Full suites delegated through `sh tools/run_tests.sh`. Table rows are diagnostic-free behavioral red and final green; green requires zero failures, exit0 and positive `TESTS PASSED <checks>` marker. Red exits1 with named expected assertions. Counts are cases/checks/failures.

| Task | Behavioral red | Green | Contract |
|---|---|---|---|
| 0 | baseline only | 58 / 96953 / 0 | inherited M2; Python6/OK/exit0 |
| 1 | 61 / 96976 / 17 | 61 / 96976 / 0 | definitions, players, kinds, copied snapshots |
| 2 | 64 / 96995 / 7 | 64 / 96995 / 0 | variants, stop/final intents, one-tick results |
| 3 | 67 / 97027 / 21 | 67 / 97027 / 0 | .2/tick direct air, ground isolation |
| 4 | 72 / 97053 / 16 | 72 / 97099 / 0 | pure placement, travel/work, pause/resume/cancel |
| 5 | 75 / 97120 / 5 | 75 / 97120 / 0 | completed power/prerequisites, earned integer work |
| 6 | 79 / 97146 / 11 | 79 / 97177 / 0 | paid FIFO, refunds, ready exit, free collector |
| 7 | 83 / 97195 / 6 | 83 / 98524 / 0 | finite stock,36/87 timers, partial loads/conservation |
| 8 | 87 / 98594 / 1 | 87 / 98595 / 0 | interruption/removal;5100-credit integrated ledger |
| 9 | 89 / 98606 / 7 | 89 / 98606 / 0 | economy picking/preview, Main hooks |
| 10 | 94 / 98644 / 32 | 94 / 98645 / 0 | base scene/controls/HUD/due feedback |
| 11 | 95 / 98646 / 1 | 95 / 101100 / 0 | separate1200-row economy replay; both output files enabled |

Raw logs stay in ignored `.superpowers/sdd/2026-11-02-m3-base-supplies/`, named `taskN-red*.log` / `taskN-green*.log`; no runtime/test dependency on scratch/source archives. Initial parser/runtime diagnostic runs are not counted as behavioral red. Typed-array literals across dynamic RefCounted/Node2D calls required explicit typed locals; fixed call sites, never relaxed wrapper diagnostics. Source-stub red tests guard absent records before asserting further state.

Boundary rulings and regression fixes:

- Cn4 cancel at299000 work executes before next work phase; an extra waiting tick completes building and invalidates that cancellation. Separate zero-work case retains duplicate future cancels and one refund.
- E11 exposed canceled same-tick resume releasing prior manual destination while leaving old route. Discard canceled foundation intent before releasing prior task/reservation; unrelated manual movement survives.
- Pre-review E4 surplus-field regression: red95/101102/2 exit1, then green95/101102/0 exit0 marker. Validate only required fields for selected variant, ignore surplus fields and normalize them away, preserving M2 policy. Required-field validation unchanged.
- Bs2 deferred placement/gesture/right-cancel and Bs5 unrelated-player feedback checks pass. Added Cn7 explicit ID-traversal boundary: reactor completion leaves later factory at500 work that tick,1000 more next tick. Pre-review normal suite **95 / 101108 / 0 / exit0**, `TESTS PASSED 101108`, no diagnostics (`task12-capture.log`).

## Exact-state migration and replay

C1 fresh/entities and C11 full-final literals add empty players/buildings/sources/results/terrain, production ID1, and mobile kind/construction/collection fields. Original equality, ordering, position, ownership, route, sequence and copy assertions retained. No old assertions deleted, tolerance changes, stationary mode or legacy mode. Existing M2 scenario remains1200 steps; only additive snapshot fields change its digests.

R3 sets up both worlds through public commands and fixtures, then compares full snapshots at each of1200 measured steps. Trace column1 is scenario-relative index1..1200 because setup advances absolute simulation tick; digest retains full absolute tick. Copied one-credit, one-box and one-work-unit mutations change SHA256; nested queue/cargo/timer/target mutation cannot affect live simulation. `WARGRID_REPLAY_TRACE` retains original movement meaning; `WARGRID_ECONOMY_REPLAY_TRACE` writes separate file, with checked open/write. CI uploads both per-platform traces and runs strict existing three-file comparator separately per scenario. No comparator generalization.

## Headless verification

Final exact production/test tree after review fixes and lean cuts:

| Check | Executed result |
|---|---|
| `sh tools/run_tests.sh` | **95 cases / 101305 checks / 0 failures / exit0**, `TESTS PASSED 101305` |
| Outside-root absolute wrapper with both traces | **95 / 101309 / 0 / exit0**, `TESTS PASSED 101309` |
| Fresh scratch copy without `.godot`, both traces | same95 / 101309 / 0 / exit0 and marker |
| Third independent same-host run, both traces | same95 / 101309 / 0 / exit0 and marker |
| Movement comparator,3 final same-host traces | `REPLAYS MATCHED 1200`, exit0 |
| Economy comparator,3 final same-host traces | `REPLAYS MATCHED 1200`, exit0 |
| `python3 -m unittest discover -s tools -p 'test_compare_replays.py'` | 6 tests, `OK`, exit0 |
| `godot --headless --path game res://scenes/base.tscn --quit-after 30` | exit0, no diagnostics |
| Diff whitespace, local Markdown links, shell syntax | exit0;74 links/9 docs at code-verification checkpoint; final docs-only pass:75 links/9 docs, zero failures/exit0 |
| actionlint v1.7.12 | exit0, no findings; ShellCheck disabled |

All suites emit no engine diagnostics. Both trace outputs add four checked file operations, explaining101309 versus ordinary101305. Final logs: `final-normal.log`, `final-outside.log`, `final-fresh.log`, `final-traces.log`, `final-compare-movement.log`, `final-compare-economy.log`, `final-python.log`, `final-smoke-post-review.log`. Final fresh copy path recorded in ignored `final-fresh-path.txt`; scratch not required by repository.

Runner behavior and wrapper behavior unchanged; only suite registration grows, so historical runner failure probes not repeated. Same-host replay comparison does not establish cross-OS determinism. Subsequent M3 cross-OS matrix evidence is recorded below.

## M2 workload regression

`sh tools/run_benchmark.sh`: exit0, `BENCHMARK PASSED 2`, `BUDGET PASS ... simulation_only` for both layouts, no diagnostics. Same authored M2 workload/thresholds unchanged:64×64,300 units, no seed,300 warmup +1800 measured unpaced ticks/layout, then drain active leg. Sample is10+60 seconds simulated time, not measured wall-clock time. Timing includes settlement inspection/command allocation/step; excludes snapshots/rendering and post-sample drain.

Host confirmed: Mac mini `Mac18,5`, Apple M6,12 CPU cores,32GiB, macOS27.2; AC power, lowpowermode0. Pinned engine as above. Final measurement repeated after dock-admission fix, all review coverage and lean cuts. No production or test changes followed final suite/benchmark verification; subsequent edits are documentation only.

| Layout | n | p50 ms | p95 ms | p99 ms | Max / command max ms | M2 baseline p95 / p99 ms |
|---|---:|---:|---:|---:|---:|---:|
| open | 1800 | 0.950 | 1.452 | 1.495 | 7.803 | 1.310 / 1.369 |
| dense | 1800 | 0.982 | 1.487 | 1.548 | 7.789 | 1.330 / 1.385 |

Both remain below proposed p95≤8ms/p99≤16ms. Timing increased versus M2 baseline; no threshold relaxed. Each layout has3 command samples, queue peak292/drain38 ticks,3 completed legs, timed endpoint300 moving/zero blocked, post-sample drain576 ticks and final300 arrived/300 unique goals. No disappearing motion or blocked restart. No rendering/backlog result inferred.

## Review and stop checkpoint — implementation ready

Installed Grok read-only review produced no substantive report within bounded four-minute attempt; only owned process terminated. It does not count as completed review. Single fresh-context fallback completed connected-code review, with all37 new named cases mapped to production mutations. No second substantive reviewer. Original detailed report remains ignored scratch `review-report.md`.

All six findings resolved in one fix pass:

| Finding | Resolution / evidence |
|---|---|
| Queue Cancel loses press across physics refresh | Retain Button nodes by production entry ID; update text, remove only vanished entries. Bs3 injects real mouse-down, physics refresh, then mouse-up; exactly one stable-entry cancel, no world order. |
| Later waiter bypasses earlier ID after middle-ID release | Before granting empty dock, check lower eligible arrived/waiting IDs. If lower ID already observed occupied slot, later ID remains waiting; lower admits next collection phase with full timer. No second collector transition or admission-tick decrement. Su4 three-collector boundary asserts result. |
| Variant validation matrix | E4 eligible seven-variant missing/wrong/bool fields, fractional origin, ownership, nonincreasing sequence, copied normalized payload and atomic snapshots. |
| Supply choice/recovery | Su4 preference/fallback, exact30 retry, nearest source/depot ID ties and closer enemy/incomplete depot exclusion. Su6 source/depot removal in every flying/waiting/active phase and transfer boundaries, exact surviving credit, active loaded collector death/dock release. |
| Ready queue/prerequisite assertions | P3 reserved-only ready exit, no allocated ID, duplicate future ready-head cancellation/refund once. P4 accepted paid queue completes after prerequisite loss, no refund/second charge. P1 free/paid completion-spawn activation starts next tick. |
| Placement/context/UI assertions | Cn1 terrain/source/building/reserved overlap atomicity, Cn4 nonempty terrain/source preservation/completed cancel, Cn5 isolated space race with sufficient funds. Bs3 Produce signal/E/CancelBuild signal plus real GUI cancel; Bs4 builder resume/active-gesture context guard. |

Review regressions: **95/101112/4 exit1** (`review-red.log`) then **95/101112/0 exit0**, `TESTS PASSED 101112` (`review-green.log`), no diagnostics. Coverage batches1–4 green, latest **95/101305/0 exit0**, `TESTS PASSED 101305`. Existing assertions retained. Final executor-owned `/ponytail-review` was lean-only: removed unused movement constant and unused test preload/binding; no other warranted cuts, no new framework/dependency. Final post-cut normal/outside/fresh/trace/comparator/benchmark/smoke/static verification passed as recorded above. No unresolved substantive review findings.

### Per-test mutation mapping

Reviewer supplied inspection-based mappings, not executed mutation tests. Red/green regressions above separately executed. Added coverage extends original review mapping where stated.


| Case | Production mutation detected |
|---|---|
| E1 `test_definitions` | Change reactor cost800 to801, depot ticks300 to301, collector speed6 to3; reuse mutable building definition after caller changes cost. |
| E2 `test_players_and_kinds` | Permit duplicate player overwrite or allocate ID for unknown kind; make default spawn builder. |
| E3 `test_economy_snapshot_isolation` | Return shared players, collection or terrain arrays; alias constructor terrain input. |
| E4 `test_variant_rejection` | Allow missing stop entity_ids, duplicate IDs, or normalize unrecognized surplus fields into pending. |
| E5 `test_future_results_and_copy` | Apply stop before tick2, alias accepted entity_ids, retain results next tick, expose result array. |
| E6 `test_stop_and_intent_order` | Stop leaves destination/route or later stop fails to replace earlier move; rejected stop mutates state. |
| E7 `test_air_spawn` | Apply ground occupancy/solid restriction to collectors or permit nonfinite/outside spawn. |
| E8 `test_air_and_mixed_move` | Air uses ground path queue or .1 speed; air reserves ground goal; mixed solid target accepted. |
| E9 `test_air_obstacle_isolation` | Reject obstacle over air or repath air after terrain edit. |
| E10 `test_power_rates` | Return500 for zero demand, equality slowdown, or remove800 upper cap. |
| E11 `test_remove_objects` | Unknown removal mutates state; discarded canceled resume clears earlier manual destination; removed future gather target succeeds/allocates ID. |
| E12 `test_economy_loop` | Fail to charge building/vehicle cost, deposit wrong box value, repeat free grant, discard final cargo or omit produced vehicle. |
| Cn1 `test_preview_and_placement` | Charge/mutate in preview, accept insufficient funds/outside/current-unit overlap, choose wrong nearest approach, accept disconnected approach. |
| Cn2 `test_travel_and_work` | Charge at issue rather than execute; delay foundation blocker; grant work during travel/arrival; finish299 instead of300 work ticks. |
| Cn3 `test_pause_resume_builder_loss` | Stop discards work, new builder fails to bind, deleted builder keeps construction progressing. |
| Cn4 `test_cancel_refund` | Refund twice for duplicate due cancel, fail to refund299000 foundation, leave builder/path footprint; refund scenario destruction. |
| Cn5 `test_competing_build_commands` | Escrow at issue, execute both800-credit orders, allocate ID on failed due order, bind builder after later move. |
| Cn6 `test_prerequisites_and_power` | Foundation satisfies reactor prerequisite or supplies5 power; depot fails to unlock factory; repeated removal refunds/mutates. |
| Cn7 `test_construction_power_transition` | Recompute work from elapsed/current duration; use full rate after power loss; recompute rates after earlier reactor completion so later factory gets1000 instead of500 same tick. |
| P1 `test_producer_and_free_collector` | Grant extra collector on every step, disable free collector, accept wrong producer, undercharge collector or alias queue paid_cost. |
| P2 `test_fifo_payment_and_cancel` | Progress both entries, give next head work on completion tick, allow tenth, cancel wrong index or refund twice. |
| P3 `test_blocked_exit` | Spawn through occupied current perimeter, consume ID on failed spawn, advance next head while ready, choose wrong first free cell or duplicate spawn. |
| P4 `test_production_power_and_removal` | Use elapsed duration instead of accumulated work, produce one tick early/late under half rate, omit producer-death1400 refund or refund twice. |
| Su1 `test_source_and_gather_validation` | Permit negative/outside/current-unit source, omit9 footprint cells, accept empty gather or mixed builder/collector gather. |
| Su2 `test_dock_timing` | Decrement admission tick, change36/87 delays, add ninth load interval, pay before unloading or wrong600 amount. |
| Su3 `test_partial_load_and_conservation` | Lose final partial load, negative stock/cargo, create extra box/credit during loop, idle earnings. |
| Su4 `test_dock_competition_and_lookup` | Double-consume last box, leave active dock after completion, create extra75 credit. |
| Su5 `test_collection_interruptions` | Move/stop leaves loop enabled/dock owned, loses positive cargo, invalid mixed replacement changes state, loaded resume chooses source first. |
| Su6 `test_dock_loss_recovery` | Lose cargo on target removal, retain removed target ID, mutate on repeated removal, fail replacement depot delivery, leave dangling ID after final collector removal. |
| V3 `test_economy_picking` | Exclude far footprint edge, fail source pick, prioritize source over collector, crash/return stale hit on empty state. |
| V4 `test_build_preview` | Alias preview array, fail clearing preview, alias Main selection returned by hook. |
| Bs1 `test_base_ready` | Wrong map/initial credits/source/builder, double simulation step, allow base B obstacle, omit credits HUD. |
| Bs2 `test_placement_input` | Wrong pointer transform/snap, allow pan/zoom placement, spend on cancel, leave successful placement mode, send twice per release, enter placement before gesture ends. |
| Bs3 `test_production_ui` | Fail owned building selection/outline, issue duplicate per handler call, cancel wrong entry ID, retain deleted building selection. |
| Bs4 `test_context_orders` | Submit move instead of gather at source; accept mixed context or block ordinary mixed move. |
| Bs5 `test_execution_feedback` | Hide due rejection, overwrite immediate error on plain refresh/unrelated player result, fail clearing error on accepted UI issue. |
| R3 `test_economy_repeatability` | Nondeterministic snapshots between repeated worlds, omit credits/boxes/work from hash, alias nested snapshot collection/queue, omit absolute tick, fail requested file open/write. |

Source/config provenance and deliberate work/geometry/docking changes remain [SOURCE_SUPPORTED / CONFIG_SUPPORTED; RETAIL_UNVERIFIED](m3-economy.md). No retail run, EA source/assets copied or sibling-project dependency. Automated correctness is not play feel, rendered performance or runtime parity.


## Final handoff

Tasks0–12 implementation/headless verification complete. Single substantive review findings resolved; lean pass complete. At the pre-publication checkpoint, visible, remote and parity gates remained pending. Subsequent evidence and authorizations follow; no M4 work. Final documentation-only whitespace/status/link check passed:75 local links across9 changed/new Markdown files, zero failures/exit0, no unresolved current status (`final-docs.log`). Game test results above remain exact code-tree evidence.


## Publication and user playtest — 2026-11-03

Implementation committed and published as `303006b58bbfc83541d5fb44bb34862b86cd36f8` on `m3-base-supplies`. [M3 matrix 41605911340](https://github.com/pdstuber/wargrid/actions/runs/41605911340) completed successfully: Linux, Windows, macOS and compare-replays jobs. Queried run head, conclusion and individual job conclusions with `gh run view`; workflow compares both movement and economy traces. Cross-OS gate passes for these scenarios at this code revision.

Default launcher still selects M2; M3 uses `sh tools/run_game.sh res://scenes/base.tscn`. After receiving that command and playtest steps, user reported “test was looking good”. This is positive user-reported M3 play evidence, without recording, measurements or itemized checklist results; it does not establish every Task 12 visible case. No screenshots or agent-launched windows.

User requested wrap-up and local merge into `main`. Documentation updated to match this evidence; no production code changes. Publishing `main` and any PR require separate approval. Remaining gaps: detailed visible checklist coverage, inherited M2 visible gates, rendered-frame/backlog measurements and retail timing/feel parity. Stop at M3.

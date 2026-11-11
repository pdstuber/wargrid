# Performance next: verification

```text
Resume record (updated 2026-11-11 12:10)
Branch / base commit / working-tree state: perf-next / f8efb98 + this file / T1, runner fix and T3 committed
Last green task / next incomplete task: T3 / Stop gate 1 (review done: PASS with fixes), then T4 if the user starts it
Changed paths since last commit: this file
Last command / cases / checks / failures / exit / marker: full suite on game code of f8efb98: CASES 733 CHECKS 139582 FAILURES 0, exit 0, TESTS PASSED; lint 0; warnings 0
Known red case or blocker: none. Open gate findings: no test for main.gd _present_if_due (base scene) and skirmish auto-pick timing; auto pick may now choose higher quality (p95 sampled per frame)
Approved decisions, pre-authorizations used, deferred gates: user 2026-11-11: local commits on perf-next after each GREEN, never push. Gates 1-3 pending; gate 1 waits for the user's playtest and go.
Usage so far: n/a
Next exact action: wait for the user's gate-1 answer (split kept? T4 starts?). If kept: optionally add the two missing tests, then T4 Opus design.
```

## Evidence rows (append-only)

- 2026-11-11 11:10-11:20, tree perf-next 5f9efee, load 1.1-1.8, no WoW/godot running, measured. Logs ~/projects/wargrid-perf-work/logs/t0-*.log.
  - run_tests: CASES 728 CHECKS 139569 FAILURES 0, TESTS PASSED, exit 0. (Handoff cited 737/139594 from the spike branch with native path; main differs by design, not a mismatch.)
  - run_lint: no problems, exit 0. run_warnings: 137 files, exit 0.
  - run_benchmark: all PASS (BENCHMARK 2, COMBAT 10, LOCKSTEP 1); open/dense/hordes300 stress rows exceed 1.82/3.64 budget but inside ceilings (accepted until spike).
  - run_profile (mean/p95 ms): skirmish3v3 step 0.705/1.313, snapshot 0.321/0.572, view.batch 0.468/0.835; team_match step 1.071/1.929, snapshot 0.507/0.790, view.batch 0.798/1.205; hordes300 step 1.987/2.850, snapshot 0.990/1.172, view.batch 1.742/2.004. Within 10 % of note section 2 (0.70/1.30, 0.32, 0.47; 1.98/2.84, 0.99, 1.74).
- 2026-11-11 11:20-11:35, tree perf-next afd9ac9 + uncommitted T1, load 1.5-1.8, no WoW/godot, measured. Logs ~/projects/wargrid-perf-work/logs/t1-*.log.
  - run_tests: CASES 733 CHECKS 139582 FAILURES 0, TESTS PASSED, exit 0 (+5 cases: 3 clock, RF3 scene, PO6 overlay). No existing `_physics_process` test needed changes.
  - RF3 mutation check: with `_present_if_due()` removed from skirmish_main `_process`, RF3 fails; restored.
  - run_lint exit 0; run_warnings 137 files exit 0; run_benchmark exit 0, same PASS/stress lines as T0 (no gain expected, headless benchmark does not use the clock).
  - run_netplay match: NETPLAY PASSED match 16.3 s, terminal tick 9024, exit 0.
  - Note: partial `WARGRID_TEST_ONLY` runs of scene suites exit 1 with ObjectDB leak warnings and no marker (also for the unchanged test_one_snapshot case); full suite is clean.
- 2026-11-11 11:21-11:30, tree = probe copy of perf-next 577ca06 (git archive) with scratch edits (view.* sub-zones in world_view.gd, Simulation.view_rows(), call in run_profile.gd), load 1.3-1.7, no WoW/godot/scons/emcc, measured. Logs ~/projects/wargrid-perf-work/probe-rows/run-{1,2,3}.log, aggregation agg.py. Ms per tick, median of 3 runs (A/A spread of means <= 0.01 everywhere); single variant, so nothing interleaved.
  - ROWS EQUAL check (rows_equal.gd): hordes300 after 40/150/400 ticks: 400 units, all fields equal (id, owner, x, y, heading, hp, max_hp, target_id, kind name via index, flags), but 0 units had a target there; after 1500 ticks: ROWS EQUAL 294, horde flag set on 279, 40 with a target. Skirmish.create (2 units): equal. Float64 and int values compared with ==.
  - Missing for rows: nothing a unit's WorldBatch._item needs (role/layer/shadow come from kind_index, anchor from x/y, footprint is constant). Other readers of the unit Dictionary that rows do not carry: `veterancy` (_draw_lines, dormant), `collection.phase/target_id` (_waiting_counts), and whatever the HUD reads off snapshot units (orders, status).
  - Per scenario, mean / p95 (spread of mean across runs in brackets):

| zone | skirmish3v3 | team_match | hordes300 | movement_open |
|---|---|---|---|---|
| snapshot | 0.321/0.569 | 0.509/0.795 | 0.988/1.162 | 0.731/0.758 |
| view.copy | 0.039/0.071 | 0.061/0.097 | 0.128/0.151 | 0.078/0.085 |
| view.sort | 0.033/0.057 | 0.044/0.070 | 0.096/0.111 | 0.083/0.086 |
| view.objects | 0.184/0.313 | 0.317/0.462 | 0.519/0.607 | 0.428/0.456 |
| view.poses | 0.065/0.135 | 0.117/0.195 | 0.256/0.312 | 0.243/0.265 |
| view.visuals | not measured headless (0.000) | same | same | same |
| view.build | 0.218/0.373 | 0.366/0.557 | 0.967/1.087 | 0.535/0.553 |
| view.batch (total) | 0.468/0.827 | 0.802/1.214 | 1.744/2.001 | 1.207/1.239 |
| view_rows | 0.077/0.131 | 0.102/0.165 | 0.221/0.258 | 0.166/0.170 |
| hand-off today (snapshot+copy+sort+batch) | 0.862/1.524 | 1.415/2.176 | 2.955/3.425 | 2.099/2.168 |
| lower bound from rows (view_rows+sort+poses+build) | 0.393/0.696 | 0.629/0.987 | 1.539/1.768 | 1.027/1.074 |

  - view.batch minus objects+poses+visuals+build is at most 0.002 ms mean (parts cover it fully). The p95 columns of the two sums add per-zone p95s, so they overstate the p95 of the sum; means are exact. The "lower bound" is a bound, not a measurement of a finished design: view.build counted at today's cost (rows might make it cheaper), view_rows is a scratch loop over the same entity Dictionaries (a design that keeps rows incrementally could cost less), and the bound ignores the HUD and picking readers listed below. Mean saving by the bound: 0.47 ms (54 %), 0.79 ms (56 %), 1.42 ms (48 %), 1.07 ms (51 %).
  - Per-unit loops over `_state.entities` in game/scripts/presentation/world_view.gd (T = per tick, called from set_state; F = per rendered frame via _draw / advance_frame; I = per input event or HUD query):
    - T: set_state (depth_sorted entities, size for _track_poses, line 188/198); _remember_points -> _points_of (576); _refresh_structures -> _waiting_counts (544/456); WorldBatch.objects (called from set_state).
    - F: _draw_rects (406, health bars per unit); _draw_lines -> selected_unit_lines (140), order_marks (343), veterancy chevron loop (422); _draw_focus -> focus_targets (478, 487); _draw_inspected (502); _draw_resume_outline -> resume_candidate (312, 315).
    - I: pick_target (363), pick_entity (374), pick_entities (596), pick_object -> pick_entity (614); resume_candidate also from base_main HUD refresh (per tick when HUD refreshes); pile_lines -> _waiting_counts (539, per source label).
  - simulation.snapshot() calls under game/scripts outside simulation/ (file:line, function, reads, rate):
    - main.gd:61 _reset_camera (map.size; once); :201 _matching_ids (entities; input, double click); :224 _refresh (whole state to _show; per tick); :273 _submit (state; per command, input)
    - base_main.gd:41 _hint_point (building; input); :68 _refresh (state; per tick); :147 _builder (entities; input); :216 _unhandled_input (building pick; input); :233 _context_order, :264 _unload_selected, :274 _set_rally, :281 _produce_selected (state/building; input); 
    - skirmish_main.gd:136 _enemy_at (entities; input, hover/inspect); :173 _order_defence (building; input)
    - online_main.gd:28 (lockstep.start; once); :57 (lockstep.finish_tick, only when wants_snapshot; per tick when asked)
    - net/headless_client.gd:129 start; :159 finish_tick (when wants_snapshot); :243, :247 StateHash.digest (every N ticks); net/seat_sim.gd:13 snapshot() passthrough
    - debug/movement_workload.gd:44 (benchmark setup); debug/combat_workload.gd:36 (setup/settled check); debug/movement_benchmark.gd:129 _begin_layout (once), :164/:168 _physics_process (per tick), :353 _horde_tick (per tick), :424 _large_tick (per tick, into set_state)
    - lab/lab_fight.gd:86 _launch_assault, :91 _order_gather (buildings/state; once per action); lab/art_lab.gd:49 (sim.snapshot, per lab step)
    - Total 32 sites as counted by rg; per-tick game-scene consumers are main.gd:_refresh and base_main.gd:_refresh (plus the scene's own set_state call path), everything else is per input event, setup or net/benchmark.
- 2026-11-11 12:05, tree perf-next 44de1a2 (f8efb98 differs only in docs), load quiet, measured: sh tools/run_tests.sh CASES 733 CHECKS 139582 FAILURES 0, exit 0, TESTS PASSED; run_lint exit 0; run_warnings exit 0. Runner wait 0.1 s still leaked on 3 of 3 partial runs, 0.5 s exit 0 on 3 of 3 (WARGRID_TEST_ONLY=test_one_snapshot). Logs logs/fix-*.log.
- 2026-11-11 gate 1 review (Opus, read-only): PASS with fixes; findings 2 and 3 (missing tests) and 4 (online stall counted in split share) open, nit on the bracket label.

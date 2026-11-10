Resume record (updated 2026-11-10, Task 3 green)
Branch / base commit / working-tree state: spike-art-lab / 7d56851 / Task 3 changes uncommitted (coordinator commits)
Last green task / next incomplete task: Task 3 / Task 4 (lab shapes and decided body look)
Changed paths since last commit: game/scripts/presentation/{world_batch,body_layer}.gd (+.uid), world_view.gd, game/scripts/debug/movement_benchmark.gd, game/tests/{test_world_batch.gd (+.uid),test_view,test_benchmark,test_shapes,run_tests}.gd, docs/reference/art-lab-verification.md
Last command / cases / checks / failures / exit / marker: `sh tools/run_tests.sh` / 629 cases / 137474 checks / 0 failures / exit 0 / TESTS PASSED 137474
Known red case or blocker: none. Draw-call gate is on and passes. Watch: view build adds about 1.3 ms to a 300-unit tick (tick_ms p50 1.57 -> 2.85), Ashfall frame p95 1.15 -> 2.49 (guard 3.3)
Approved decisions, pre-authorizations used, deferred gates: plan approval 2026-11-10 covers Task 3 rendered window (used twice: first run exposed a per-vertex GDScript cost, second run after the Transform2D/cached-colour fix is the recorded one); ceilings fixed 50/50/50/60
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: dispatch Task 4 of docs/superpowers/plans/2026-11-10-art-lab-spike.md

## Evidence rows (append-only)

### 2026-11-10 Task 1: draw-call gate and baseline on main's look (tree: worktree, base 6e0a9f5 plus Task 1 diff)

- Red: `WARGRID_TEST_ONLY=test_draw_call_ceiling` failed (function missing, 0 checks). Green: same case 5 checks pass; full suite 611 cases, 137314 checks, 0 failures, exit 0.
- `draw_call_failure` and `DRAW_CALL_CEILINGS` added; `DRAW_CALLS <layout> max= ceiling= over=` printed per layout, no `_fail` yet (Task 3 turns it on).
- Rendered run (`sh tools/run_game.sh res://scenes/movement_benchmark.tscn`, vsync=off, 1280x720, zoom 0.5). Load before 1.77 / after 3.25 (1 min avg 1.64 -> 1.99 at exit); no WoW process; not tagged.

| Layout | frame p95 ms | draw calls max (p50) | ceiling | over |
|---|---|---|---|---|
| open | 1.848 | 5 (5) | 50 | no |
| dense | 1.181 | 6 (6) | 50 | no |
| ashfall | 1.152 (guard 3.3) | 45 (45) | 60 | no |
| horde | 2.8 (budget 3.04) | 239 (228) | 50 | YES |

- Horde cause (as predicted): each horde mark is its own polygon draw (`world_view.gd:208`); a polygon is always its own GL draw. Task 3 must batch them. Ashfall is 45 of 60: 15 spare.
- Log: ~/projects/wargrid-art-work/t1-render.log (outside repo).

### 2026-11-10 Task 2: shape table and baking (tree: worktree, 77a511f plus Task 2 diff)

- New: `shapes.gd` (roles, parts, slots), `shape_bake.gd` (bucket, cached mesh with points/slots/lifts), `palette.gd` (8 owners, 2 biomes); suite `test_shapes.gd` registered in `run_tests.gd`. Tracked `.gd.uid` files added for each new script.
- `WARGRID_TEST_ONLY=test_shapes`: 6 cases, 132 checks, pass. Lint pass, warnings pass (120 files), full suite 617 cases, 137446 checks, 0 failures, exit 0, TESTS PASSED 137446.
- Test deviation: plan's `test_box_top_face_on_top` says min y about -10 for a 1x1x10 box; a box centred on the anchor has its back corner at -16 px, so the test asserts back corner y = ground corner y minus height (checked on `default_building`, 2x2x14: -32-14) and lifts span 0..14. Intent (top face lifted by height, roof slot on top) kept.
- Red step was not run separately (files written before the first run); first run failed on type errors, fixed.
- Sides: roof-slot boxes use SLOT_SIDE (left) / SLOT_SIDE_DARK (right); other slots colour all faces alike. Placeholder default shapes only; Task 4 adds lab roles.

### 2026-11-10 Task 3: one depth-sorted triangle array (tree: worktree, 7d56851 plus Task 3 diff)

- Red (before production code): `WARGRID_TEST_ONLY=test_world_batch`, `test_gate_fails`, `test_pick_under_roof`, `test_structure_bodies`, `test_building_health`, `test_structures_redraw_only` all exit 1 with "Preload file res://scripts/presentation/world_batch.gd does not exist" (logs `t3-red-*.log`); a first run also showed my own integer-division warnings in the new test, fixed.
- Green: `test_world_batch` 8 cases / 20 checks; full suite 629 cases, 137474 checks, 0 failures, exit 0, TESTS PASSED 137474. Lint and warnings (124 files) pass.
- Built: `WorldBatch` (objects, sort_key, depth_sorted, build, submit), `BodyLayer` child `Bodies` after `Structures`; body rects, air shadow circles, horde-mark polygons and heading ticks no longer drawn by `world_view.gd` (heading shows in the shapes); building health bars moved to the parent's overlay pass and dropped from the structure cache key; gate on via `draw_call_gate` (report-only for `--quality/--zoom/--units/--layout`). Ground footprint polygons, glyphs and labels stay in `Structures` (Task 5).
- Deviations: test_shapes SH3 now bakes with variant 9001 (shared static cache made it order-dependent once another suite baked the same mesh). Building default box is 2x2 whatever the footprint (placeholder until Task 4). First draft appended per vertex in GDScript: tick p50 3.17 ms open and horde frame p95 6.79 ms; replaced by `Transform2D * PackedVector2Array` plus per-owner colour arrays cached on the baked mesh.
- Rendered run (`sh tools/run_game.sh res://scenes/movement_benchmark.tscn`, vsync=off, default shapes). Load 2.63 before, 3.31 after; no WoW process; not tagged. Log `~/projects/wargrid-art-work/t3-render2.log` (first run `t3-render.log`).

| Layout | frame p95 ms (T1 baseline) | draw calls max (p50) (T1 baseline) | ceiling | over | tick_ms p50 (T1) |
|---|---|---|---|---|---|
| open | 0.62 (1.848) | 5 (5) (5) | 50 | no | 2.855 (1.567) |
| dense | 0.644 (1.181) | 6 (6) (6) | 50 | no | 2.896 (1.593) |
| ashfall | 2.493 (1.152), guard 3.3 | 45 (45) (45) | 60 | no | 2.846 (1.541) |
| horde | 0.655 (2.8), budget 3.04 | 6 (5) (239) | 50 | no | 4.538 (3.151) |

- Reading: draw calls pass everywhere, horde 239 -> 6. Frame p95 swings with how many frames hold a tick (fixed 60 s window; frame counts 57k-142k vs 82k-104k), so compare tick_ms too: the view build adds about 1.3 ms per 300-unit tick (open) and about 1.4 ms in horde. Ashfall frame p95 doubled to 2.49 (guard 3.3, 0.8 ms spare): Task 4's richer shapes will eat into that; Task 8 decides. Not loosened.

### Direct snapshot readers left in `world_view.gd` (for the sim interface note)

Functions reading `_state` directly: `set_state`, `_prune_hints`, `_refresh_structures`, `_waiting_counts`, `_remember_points`, `_remember_building_shots`, `resume_candidate`, `order_marks`, `horde_marks`, `crate_marks`, `heading_marks`, `focus_targets`, `battery_target_lines`, `rally_marker`, `pick_target`, `pick_entity`, `pick_entities`, `pick_source`, `pick_object`, `draw_structures`, `_draw`, `_draw_cues`, `_draw_focus`, `_draw_inspected`, `_draw_resume_outline`, `_draw_hints`. New drawing code reads the snapshot only through `WorldBatch.objects()`.

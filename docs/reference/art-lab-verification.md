Resume record (updated 2026-11-10, Task 2 green)
Branch / base commit / working-tree state: spike-art-lab / 77a511f / Task 2 changes uncommitted (coordinator commits)
Last green task / next incomplete task: Task 2 / Task 3 (one depth-sorted triangle array)
Changed paths since last commit: game/scripts/presentation/{shapes,shape_bake,palette}.gd (+.uid), game/tests/test_shapes.gd (+.uid), game/tests/run_tests.gd, docs/reference/art-lab-verification.md
Last command / cases / checks / failures / exit / marker: `sh tools/run_tests.sh` / 617 cases / 137446 checks / 0 failures / exit 0 / TESTS PASSED 137446
Known red case or blocker: none; horde draw calls 239 vs ceiling 50 is expected on main's look (report-only until Task 3)
Approved decisions, pre-authorizations used, deferred gates: plan approval 2026-11-10 covers Task 1 rendered window (used once); ceilings fixed 50/50/50/60
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: dispatch Task 3 of docs/superpowers/plans/2026-11-10-art-lab-spike.md

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

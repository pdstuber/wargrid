Resume record (updated 2026-11-10, Task 8 numbers green, stop gate 2)
Branch / base commit / working-tree state: spike-art-lab / d33fd74 / Task 8 changes uncommitted (coordinator commits)
Last green task / next incomplete task: Task 8 (stop gate 2: Opus gate review, user sees numbers) / Task 9
Changed paths since last commit: game/{export_presets.cfg,project.godot}, game/scripts/debug/{combat_workload,movement_benchmark}.gd, game/scripts/presentation/world_view.gd, game/tests/{test_benchmark,test_map}.gd, docs/reference/{art-lab-verification,performance}.md
Last command / cases / checks / failures / exit / marker: `sh tools/run_tests.sh` / 666 cases / 138316 checks / 0 failures / exit 0 / TESTS PASSED 138316
Known red case or blocker: none. Watch: per-tick presentation about 1.55 ms plus director 0.22 ms in a stress case (see Task 6 row); Ashfall frame p95 guard 3.3 (Task 8)
Approved decisions, pre-authorizations used, deferred gates: plan approval 2026-11-10 covers rendered windows of Tasks 1, 3, 8 only; ceilings fixed 50/50/50/60
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: Opus gate review of Task 8, then show the user the numbers (stop gate 2); then dispatch Task 9 of docs/superpowers/plans/2026-11-10-art-lab-spike.md

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

### 2026-11-10 Task 4: lab shapes and decided body look (tree: worktree, d7693d5 plus Task 4 diff)

- Red (before production code): `WARGRID_TEST_ONLY=test_shapes` and `test_world_batch` both exit 1 with parse errors "Too many arguments for parts()" and "Static function damage_stage() not found" (logs `t4-red-*.log`). Two further red-for-the-right-reason runs: SH8 (roof count) failed until ROOF_DARK sides got their own slot; WB12/13 failed because my test reused one pile origin.
- Green: `test_shapes` 9 cases / 352 checks, `test_world_batch` 14 cases / 44 checks; full suite 638 cases, 137718 checks, 0 failures, exit 0, TESTS PASSED 137718. Lint and warnings (127 files) pass.
- Built: roles `tank_usa/china/frc` (hull + `turret` part pivoting on hull top), `bulldozer`, `infantry` (all infantry classes incl. `frc_builder`), `power_plant`, `war_factory`, `supply_depot`, `supply_source`. `Shapes.parts(role, detail, variant)` is cached; the variant is the mesh variant: building damage stage (0-2), for piles `Shapes.source_variant(boxes, footprint)` packs stack level (steps 1/5/15/40 boxes) and footprint so a small pile bakes inside its own footprint. `WorldBatch.damage_stage` (integer percent, 70 and 35 inclusive), `FLAG_SHADOWS/OUTLINES/EFFECTS`; shadows only with `FLAG_SHADOWS` (units 6 px, air 8 px), `world_view.gd` now passes `FLAG_SHADOWS` so air shadows stay. Mesh and parts caches are keyed by int, not formatted strings.
- Damage looks: stage 1 darker roof with the front quadrant removed; stage 2 adds a `SLOT_GLOW` smoke column in the gap. Roofs are four quadrant boxes (so a corner can go).
- Deviations: `test_turret_pivot_on_hull_top` checks the turret's `SLOT_ROOF` (top face) triangles with lift added back (ground projection) against the pivot, since the raw projection differs from the pivot by the lift and barrel triangles would bias the centroid. `test_building_rises_with_work` would pass on the old default box for height alone, so it also asserts the role is `war_factory`. Non-tank vehicles (scout car, collectors, `china_light_vehicle`) stay `default_vehicle` until Task 4b.
- Per-tick cost (headless scratch timing of `WorldBatch.objects` + `build`, 300 mixed units + 6 factories, detail 1, shadows on, 200 reps; script `~/projects/wargrid-art-work/t4_time.gd`, run as a temporary test script): 1.138 ms before, 1.318 ms after (+0.18 ms; triangles 3448 -> 6400). Still above the ledger's 0.91 ms presentation-plumbing budget, as at Task 3; no new per-vertex GDScript, only cached-array transforms. Rendered window not opened (not pre-approved for Task 4).
- Not checked: how the shapes look (no render), Ashfall frame p95 with the richer shapes (Task 8).

### 2026-11-10 Task 4b: whole roster in the same vocabulary (tree: worktree, f033cef plus Task 4b diff)

- Red: shapes.gd was written first, then reverted to HEAD for the red run (`t4b-red.log`): `WARGRID_TEST_ONLY=test_shapes` exit 1 on assertions, e.g. "SH10 china_collector has a class role (default_vehicle)", "SH10 china_light_vehicle ...", "SH7 usa_rocket_infantry maps to rocket_infantry". Green: `test_shapes` 11 cases / 884 checks; full suite 640 cases, 138250 checks, 0 failures, exit 0, TESTS PASSED 138250. Lint and warnings (127 files) pass.
- New roles: `light_vehicle`, `collector_truck` (`*_collector` wheels), `helicopter` (`usa_collector`; body plus fixed-angle `rotor` part; air layer already comes from `Registry.air_kinds`), `rocket_infantry`, `command_center`, `barracks`, `defence` (fixed base plus `turret` part pivoting on its top), `rubble_1/2/3` (`*_hole_N`, sized from footprint). Every registry kind now maps to a non-default role; defaults stay only as fallback.
- Deviations: `*_rocket_infantry` moved from `infantry` to the new `rocket_infantry` role (Task 4's `test_lab_roles_mapped` expectation updated; `frc_builder` stays `infantry`). `china_light_vehicle` is a treaded Medium Tank with a cannon, so it uses `tank_china` instead of `light_vehicle`. Damage variants apply to command center and barracks (shared slab); defence and rubble ignore them. Defence turret has no aim until Task 6 (heading 0 for buildings).
- Per-tick path untouched (only baked part data changed); timing not re-run. Not checked: how the new shapes look (no render).

### 2026-11-10 Task 5: overlays and terrain look (tree: worktree, 7d34719 plus Task 5 diff)

- Red (stubs returning wrong values, `t5-red.log`): `WARGRID_TEST_ONLY=test_view` exit 1, 20 assertion failures, e.g. "V18 unselected full hp shows no bar", "V19 full is green", "V21 a biome change on the same map redraws the terrain once", "V22 no grid without a preview", "V24 rank 1 is one chevron of two segments". Green: `test_view` 29 cases / 107 checks; full suite 645 cases, 138236 checks, 0 failures, exit 0, TESTS PASSED 138236. Lint pass, warnings pass (127 files).
- Built: `WorldView.health_color` / `shows_health` / `set_biome` / `selected_unit_lines` (4 segments, ground diamond, half width + 4 px, 2:1) / `grid_lines` (only with a build preview) / `veterancy_lines` (placeholder, 4 points per rank); `TerrainView.set_palette`; `Palette.HEALTH_*`; `owner_color` now reads the 8-owner palette. `_draw` order: preview polygons, one rect pass (crates, all bars), one line pass per colour (grid; selection plus order crosses; chevrons), existing focus/cue code, text last. Terrain: ground from `Palette.ground(biome)`, cliffs as an 8 px step (two side faces plus lit top) in one triangle array, sorted back to front; grid removed from the cached terrain. Removed: building glyphs (`_draw_glyph`, icon helpers), `heading_marks`, unit selection rect, tests `test_building_icons` and `test_heading_mark_layout`.
- Labels kept (stop condition, for M7.6): pile text (Boxes / docked / waiting) is shown nowhere else, and the build percent plus "paused" is not in the panel (it shows raw `Work a/b` for the selected building only). Both moved from the cached structure layer to the parent's text pass above the bodies; the structure cache key no longer holds boxes, waiting, work or builder id, so it redraws less. `test_pile_label_drawn_over_buildings` now asserts the canvas (footprint behind, label on the parent) because a parent's `_draw` callback runs before its behind-children's.
- Per-tick/frame cost (headless scratch, `~/projects/wargrid-art-work/t5_time.gd`: 300 mixed units, 30 selected, 6 factories, 1 pile, 100 frames): overlay `_draw` 0.799 ms on 7d34719 -> 0.627 ms (unit bounds are computed only for units that show a bar). `set_state` plus engine frame 6.79 ms both (engine-dominated). `objects()`+`build()` untouched. Draw calls: terrain still one cached draw (the grid line batch is gone from it); overlays now 1 rect run, up to 3 multilines, 1 text run per frame instead of rect/line interleaved per unit; rendered draw-call counts not measured (no window pre-approved).
- Deviations / not checked: `test_selection_is_ground_diamond` cannot assert the old rect outline is gone (draw calls are not observable), it checks the lines' geometry; glyph/heading removal is asserted by absent methods. Water has no map data, so `Palette.water` is unused. Cliffs sit in the terrain layer, so a unit just behind a cliff draws over its step (8 px). Biome 1 is the old tan look from the palette; the A/B candidate comes in Task 9. Look not rendered.

### 2026-11-10 User remark (not a playtest)

- The user watched the Task 3 benchmark window (placeholder default shapes, before the Task 4 lab shapes) and found the new tanks and infantry "pretty good, way better than the current shapes". The Task 4 lab shapes have not been seen on screen yet.
- Same session, user: "when large numbers moved, e.g. in a column, the distances between them seemed a bit small." Two causes, not separated yet: simulation spacing (one unit per 25-unit cell; Zero Hour blocks 1-5 pathing cells of 10 units by radius, goal layout by radius; belongs to the movement and pathing milestone, size classes) and body size against the cell (art; candidate Task 9 A/B variant). Re-check with the Task 4 shapes at Task 8.

### 2026-11-10 Task 6: visual events and local motion (tree: worktree, 1cc5de4 plus Task 6 diff)

- Red (stub director returning empty values, `t6-red.log`): `WARGRID_TEST_ONLY=test_visual` exit 1 on assertions, e.g. "VI1 both ticks consumed, got []", "VI2 three damage records of one attack give one muzzle, got 0", "VI9 muzzle draws with flags 0" (two cases also hit typed-array errors in my test, fixed). Green: `test_visual` 12 cases / 26 checks; full suite 657 cases, 138262 checks, 0 failures, exit 0, TESTS PASSED 138262. Lint pass, warnings pass (127 files).
- Built: `VisualDirector` (collect_step, update, effects, turret_angles, consumed_ticks, reset, `dropped`); `WorldBatch.build(..., marks, effects)` draws muzzle, hit and fade as triangles on both qualities and moves the `turret` part to the director's angle (any role with a turret part, incl. the defence); building items now carry `combat.target_id` so defences aim. `WorldView.set_visuals`; `set_state` runs `update` once per tick value (a refresh from input or a paused tick does not age effects). Drivers: `skirmish_main._collect_sound` (online inherits it, catch-up steps each collect), restart resets; `movement_benchmark` collects on every horde tick regardless of `--sound` and attaches the director to the view for all layouts.
- Removed from `_draw_cues`: unit shot line and death cross. Kept: `battery_target_lines`, `building_shot_lines` and their tests (unchanged, green).
- Per-tick cost (headless scratch `~/projects/wargrid-art-work/t6_time.gd`: 300 mixed units, 6 factories, detail 1, shadows on, 200 reps, worst-case stress: every tank has a moving target, 20 shot events per tick): objects() 0.50 ms, director collect+update 0.22 ms, build 1.05 ms (with 200 live effects and 200 turret angles); same-tick base objects()+build() without visuals 1.38 ms. So +0.39 ms in the stress case (director 0.22, effects and turret buckets 0.17); idle cost is one dictionary insert per object. Above the ledger's 0.91 ms plumbing budget as before; not loosened. Rendered window not opened (not pre-approved for Task 6).
- Deviations / not checked: effect shapes are placeholder diamonds (muzzle yellow, hit orange expanding, fade dark smudge) at cell anchors; how they look is not rendered. Muzzle lasts 4 updates, hit 6, fade 60. Turret cosmetic rate 0.15 rad per tick as confirmed. Review-focus tests 2 and 5 are `test_visual_catch_up_and_stall` and `test_reset_clears_presentation_state`; the online scene's two-step frame is covered by the existing `test_catch_up_collects_every_step` plus the director test, no new scene test.

### 2026-11-10 Task 7: Quality Low/High and zoom detail (tree: worktree, 6443bf1 plus Task 7 diff)

- Red: `WARGRID_TEST_ONLY=test_low_drops` with `flags(LOW)` stubbed to return 1 fails on the assertion "Q1 Low has no flags" (1 failure). First all-suite run of the new file was a parse error (duplicate const), fixed; red done by stub afterwards, not before.
- Green: `test_graphics_settings` 8 cases / 20 checks; layout check added to `test_menu_layout` (quality toggle visible, enclosed, clear of HUD text and other buttons at 1280x720 and 1920x1080). Full suite 665 cases, 138312 checks, 0 failures, exit 0, TESTS PASSED 138312. Lint and warnings (129 files) pass.
- Design: `GraphicsSettings` owns the flag constants (`WorldBatch.FLAG_*` alias them); a first version preloaded `WorldBatch` from it, which made `run_warnings.sh` report "26 resources still in use at exit" for test_pause_menu/test_perf_overlay through the pause menu's preload chain. Low drops shadows and effects (outlines flag is defined but nothing draws outlines yet). Stored quality read at `_ready` (unset = High); `set_zoom` from `change_zoom` and from restart.
- Auto-pick: `skirmish_main` samples `TIME_PROCESS + TIME_PHYSICS_PROCESS` for 120 frames when unset and not headless, saves `pick(p95)`. Not exercised for real (headless only; rendered window not pre-approved for Task 7); `movement_benchmark.gd` does not auto-pick and keeps the View defaults (High, zoom 1.0 -> same as before, plus the unused outlines flag). Online skirmish does not auto-pick (only the offline skirmish scene), noted for the coordinator.
- Per-tick cost (headless `WorldBatch.objects` + `build`, 300 mixed units + 6 factories, zoom 1.0, 200 reps, `~/projects/wargrid-art-work/t7_time.gd`, 3 runs): Low (detail 0, flags 0) 1.13 ms, 3156 triangles; High (detail 1, all flags) 1.37-1.39 ms, 6400 triangles. Task 4 was 1.318 ms for High; the +0.06 ms is run noise, no new per-tick work. Both above the 0.91 ms plumbing budget, as before; reported, not loosened.

### 2026-11-10 Task 8: numbers (tree: worktree, d33fd74 plus Task 8 diff)

- Red: `WARGRID_TEST_ONLY=test_horde_render_500` failed on a missing layout (assert, null `snapshot`, 0 checks; `t8-red.log`). Green: 2 cases / 5 checks. Full suite 666 cases, 138316 checks, 0 failures, exit 0, TESTS PASSED 138316 (two preset-count checks updated 10 -> 11 for the new export preset). Lint and warnings (131 files) pass.
- Built: `CombatWorkload.create("horde_render_500")` (25x16 army, asserted); benchmark args `--quality`, `--zoom`, `--layout`, `--units=500` (report-only, header prints real values, ashfall guard also skipped when report-only); layout sequence and `_advance`; CPU_FRAME line (script / render / setup / total); `WorldView.draw_usec` (two `ticks_usec` per frame); export preset `Web Render Bench` with `wargrid_render_bench` feature and main scene override; web run is report-only, posts lines (and a failure message) to `/result`.
- Bench run: exit 0, no failing BUDGET line. Rendered rows a-d and web: see the performance ledger section "Art lab rendered rows". Row c was first run with a mis-split argument (zsh), rerun correctly; the bad log is `t8-c-bad.log`. The first web attempt posted nothing: the typed layout list came out empty in the browser and the gate path hid the failure; fixed by building the typed array explicitly and posting failures.
- Per-tick (t7_time.gd, 3 runs): Low 1.143-1.152 ms, High 1.401-1.405 ms vs 0.91 ms dev budget: exceeded, unchanged per-tick work.
- No simulation change: `git diff main -- game/scripts/simulation game/scripts/net` empty. Netplay: `match` PASSED terminal tick 9024 (the pin), `maps` PASSED, `perturb` PASSED. CI traces (`compare_local_traces.sh`): pending a user-approved push.
- Not checked: Deck / other browsers; GPU time on WebGL; per-frame native script p95 reads 0 (ticks are 1 % of vsync-off frames), so native CPU_FRAME p95 is not a tick cost, use p99/max. Firefox tabs I opened (2) left open. Load fluctuated 1.3-2.9, no WoW.

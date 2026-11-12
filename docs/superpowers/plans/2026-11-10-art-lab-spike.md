# Art Lab Spike Implementation Plan

**Status: approved by the user 2026-11-10; run not started.** Pre-run check against the code and the ledger folded in the same day (list in the design's status line; two user answers below).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run rules: [milestone prompt](../../milestone-prompt.md) (coordinator plus one fresh subagent per task, no per-task reviewers, one Opus review per stop gate).

**Goal:** The decided geometric 2.5D look for the lab objects in the real game, drawn as one triangle array per tick, measured on native and Web, plus in-game A/B variants for seven world questions.

**Architecture:** A shape table per role is baked once into triangle lists per (role, part, heading bucket, detail). Each tick one adapter turns the snapshot into drawable objects, sorts them by (layer, ground depth, id), appends baked triangles with colours resolved per owner, and submits one `canvas_item_add_triangle_array`. Overlays stay batched rects and lines. A `VisualDirector` beside `SoundDirector` collects events at every step.

**Tech Stack:** Godot 4.7.2, typed GDScript, Compatibility renderer, `RenderingServer`; Python 3 only for the existing `tools/serve_web_bench.py`.

**Spec:** [art lab design](../specs/2026-11-10-art-lab-design.md) (read it fully once). Handoff: art lab prompt (`art-lab-prompt.txt`, private).

**Model routing:** Tasks Sonnet (mid tier); stop-gate reviews Opus (high), fresh context. Verification file and resume record: `docs/reference/art-lab-verification.md` (created in Task 1).

## Global Constraints

- Branch `spike-art-lab` from `main` in worktree `~/projects/wargrid-wt-art` (`git worktree add`, done by the coordinator before Task 1); never switch the main checkout's branch. Every task works, reads its resume record and runs its commands in the worktree. Scratch output: `~/projects/wargrid-art-work`.
- Presentation only: `git diff main -- game/scripts/simulation game/scripts/net` stays empty; replay, hash and trace tests unchanged; no snapshot field added.
- Units: snapshot `position` and building `origin` are in cells; `Iso.world_to_plane` maps one cell to 64x32 screen px at zoom 1. Shape offsets and sizes are in cells, heights in screen px at zoom 1.
- Budgets unchanged: rendered frame p95 3.04 ms (dev machine), `ASHFALL_FRAME_P95_MS` 3.3, F = 5.5. Over budget: report and stop, never loosen.
- Draw-call ceilings (max per frame in the sample window): `open` 50, `dense` 50, `horde` 50, `ashfall` 60. Fixed; never raised to pass. Printed from Task 1, failing a run from Task 3 on: `horde` is at 238-239 on `main` (ledger row 2026-11-08, sound spike Task 7) because each horde mark is its own polygon draw (`world_view.gd:208`).
- Batches: a polygon is always its own GL draw, and a switch between rect and line commands ends a batch (levers note, key finding and "Antialiasing per primitive"). Overlays draw one command type per pass (all bars, then all diamonds), never interleaved per object.
- Draw order: `Terrain`, `Structures` (ground footprints) and `Bodies` are `show_behind_parent` children in that order, then the parent's overlays. Anything that must stay readable over a raised body (building health bars, a label that stays) draws in the overlay pass.
- `HEADING_BUCKETS = 64`. Zoom steps 0.5, 1.0, 2.0 (`main.gd:10`) map to detail 0 (far), 1, 2. Low quality uses detail 0 at every zoom.
- Owner palette: 8 owners (Zero Hour's eight retuned; today only owners 1 and 2 have colours, `world_view.gd:36`). Ground start value `#575C55`. Values are starting points.
- New drawing code (`WorldBatch`, `VisualDirector`, the lab) reads the snapshot only through `WorldBatch.objects()`. `world_view.gd`'s existing picking, overlay and mark readers stay as they are; Task 3 lists them in the verification file for the sim interface note (user, 2026-11-10).
- Lab-only code (A/B variants, lab scene, lab fight) lives under `game/scripts/lab/`, `game/scenes/art_lab.tscn` and `game/tests/test_art_lab.gd`, so a merge can leave it out. Nothing outside those paths names them, except the suite's entry in `run_tests.gd` `SUITES` (dropped again if the merge leaves the lab out).
- Typed GDScript; `sh tools/run_lint.sh`, `sh tools/run_warnings.sh` and `sh tools/run_tests.sh` pass before each GREEN. Every suite, benchmark, netplay and lint call uses `timeout: 600000`; output to a file, read summary lines only. A new script gets a tracked `.gd.uid` file from the import: report it with the changed paths.
- Report-only run: a benchmark run with any non-default `--quality`, `--zoom`, `--units` or `--layout` prints its rows and never calls `_fail` for a budget, ceiling or guard.
- Rendered runs open a window: plan approval covers the rendered benchmark runs in Tasks 1, 3 and 8 (batched per task); the A/B session (Task 9) needs its own approval.

**Confirmed in interview (user, 2026-11-10):** auto Low above frame p95 8.3 ms; Web row measures CPU time per frame; 500-unit report-only horde row; a map label whose value the panel lacks stays and is noted for M7.6; ceilings 50 / 60; Task 3 over a ceiling or the Ashfall guard stops the run; cosmetic turrets at a fixed rate (0.15 rad per tick); health bars include hover; plan approval covers the rendered benchmark windows of Tasks 1, 3 and 8, the A/B window is asked separately.

**Pre-run check (user, 2026-11-10):** the adapter covers the new drawing code only (existing `world_view.gd` readers stay, listed for the interface note); heading ticks are removed, the shapes show heading.

## Review Focus

1. **A unit under a raised roof stays clickable.** A tank behind a factory roof is still picked from its ground bounds, never by the roof's drawn pixels. Test in Task 3 (`test_pick_under_roof`).
2. **A stalled online tick or a catch-up step of two shows each shot exactly once.** Test in Task 6 (`test_visual_catch_up_and_stall`).
3. **A palette or biome change redraws the terrain** even when the map identity is unchanged. Test in Task 5 (`test_biome_change_redraws_terrain`).
4. **A kind added later draws a default box at its real position, and air kinds (`usa_collector` helicopter) draw in the air layer**; nothing crashes or vanishes. Test in Task 2 (`test_unknown_kind_gets_default_role`) and Task 3 (`test_air_kind_draws_above_ground`).
5. **Restart or a new match with reused IDs carries no turret angle, fade or effect from the old match.** Test in Task 6 (`test_reset_clears_presentation_state`).

---

### Task 1: Draw-call gate and baseline

```text
Task: movement_benchmark reports each layout's draw calls against its ceiling; today's numbers recorded.
Owns: game/scripts/debug/movement_benchmark.gd, game/tests/test_benchmark.gd, docs/reference/art-lab-verification.md
Invariant: existing frame and Ashfall guards unchanged.
Boundary: a layout with no ceiling entry fails loudly, not silently passes.
Red: test_draw_call_ceiling fails (function missing).
Green: test_draw_call_ceiling plus full suite; one rendered run on main's look.
Stop: none for a ceiling (horde is expected near 239 on main's look; the gate fails runs from Task 3 on).
```

**Files:** Modify `game/scripts/debug/movement_benchmark.gd`, `game/tests/test_benchmark.gd`. Create `docs/reference/art-lab-verification.md` (resume record block from the milestone prompt, then dated rows).

**Interfaces:** Produces `const DRAW_CALL_CEILINGS: Dictionary = {"open": 50, "dense": 50, "horde": 50, "ashfall": 60}` and `static func draw_call_failure(layout: String, max_calls: float) -> String` (empty string means pass) in `movement_benchmark.gd`.

- [ ] Step 1: In the worktree (created by the coordinator), create the verification file with the resume record.
- [ ] Step 2: Write `test_draw_call_ceiling` in `test_benchmark.gd`: `draw_call_failure("open", 50.0) == ""`, `draw_call_failure("open", 51.0) != ""`, `draw_call_failure("ashfall", 60.0) == ""`, `draw_call_failure("ashfall", 61.0) != ""`, `draw_call_failure("nope", 1.0) != ""`. Add it to `cases()`.
- [ ] Step 3: Run `WARGRID_TEST_ONLY=test_draw_call_ceiling sh tools/run_tests.sh`. Expected: FAIL.
- [ ] Step 4: Implement `draw_call_failure`. Call it in `_finish_layout` and in the horde finish path with `Stats.summary(_draw_calls).max`, and print `DRAW_CALLS <layout> max=<n> ceiling=<c> over=<true|false>` for every layout. Do not `_fail` on it yet: Task 3 turns that on.
- [ ] Step 5: Run the case and then the full suite. Expected: PASS, completion marker.
- [ ] Step 6: Rendered baseline (approved window): `sh tools/run_game.sh res://scenes/movement_benchmark.tscn > ~/projects/wargrid-art-work/t1-render.log 2>&1`, with `uptime` before and after. Record the `RENDERED SAMPLE`, `DRAW_CALLS` and `ASHFALL` lines per layout in the verification file. For each layout over its ceiling, name the draw commands that cause it (expected: horde marks); Task 3 has to batch them.
- [ ] Step 7: GREEN; coordinator commits "Report draw calls against a ceiling per layout".

### Task 2: Shape table and baking

```text
Task: each kind maps to a role; each (role, part, bucket, detail) bakes once into triangles with colour slots.
Owns: game/scripts/presentation/shapes.gd, shape_bake.gd, palette.gd, game/tests/test_shapes.gd, game/tests/run_tests.gd (register suite)
Invariant: baking is pure, deterministic and runs once per process.
Boundary: unknown kind -> default role sized from footprint or class; heading exactly 2*PI -> bucket 0.
Red: test_bucket_wraps fails (class missing).
Green: test_shapes.gd suite.
Stop: none.
```

**Files:** Create `game/scripts/presentation/shapes.gd`, `shape_bake.gd`, `palette.gd`, `game/tests/test_shapes.gd`. Modify `game/tests/run_tests.gd` (add the suite to `SUITES`).

**Interfaces (produces):**
- `Shapes`: `const HEADING_BUCKETS: int = 64`; slot constants `SLOT_ROOF, SLOT_ROOF_DARK, SLOT_SIDE, SLOT_SIDE_DARK, SLOT_MACHINE, SLOT_GLOW, SLOT_OUTLINE, SLOT_SHADOW` (0..7); `static func role(kind: String) -> StringName`; `static func parts(role: StringName, detail: int) -> Array[Dictionary]`. A part is `{name: StringName, angle: StringName (&"heading" | &"turret" | &"fixed"), pivot: Vector3, prims: Array[Dictionary]}`. A prim is `{type: StringName (&"box" | &"cylinder"), offset: Vector3, size: Vector3, slot: int}`, with x and y in cells and z in px.
- Roles in this task: `&"default_vehicle"`, `&"default_infantry"`, `&"default_building"`, `&"default_source"`. Lab roles are added in Task 4. `role()` returns a default for every kind not mapped.
- `ShapeBake`: `static func bucket(angle: float) -> int` (`posmod(roundi(angle / TAU * 64), 64)`); `static func mesh(role: StringName, part: int, bucket: int, detail: int, variant: int = 0) -> Dictionary` returns `{points: PackedVector2Array, slots: PackedByteArray, lifts: PackedFloat32Array}`, triangles relative to the part's ground anchor, cached in a static Dictionary on first request. `lifts` is each vertex's height in px above the ground (already applied in `points`), so Task 4 can scale a rising building at append time without a re-bake. `variant` keys state shapes (damage stage, supply stack level); Task 2 bakes only variant 0. Box: the top face plus the side faces facing the camera for that bucket's rotation. Cylinder: 8 segments at detail 2, 6 at 1, 4 at 0.
- Supply sources have no `kind` in the snapshot (`{id, origin, boxes, active_collector_id}`, optional `footprint`): `WorldBatch.objects()` sets their role, not `Shapes.role()`.
- `Palette`: `static func owner_colors(owner: int) -> PackedColorArray`, 8 entries indexed by slot, owners 1..8 with a grey fallback. `static func ground(biome: int) -> Dictionary` with `{ground, cliff_top, cliff_side, water}` for biome 0 and 1.

- [ ] Step 1: Write the tests in `test_shapes.gd`:
  - `test_bucket_wraps`: `bucket(0.0) == 0`, `bucket(TAU) == 0`, `bucket(-TAU / 64.0) == 63`.
  - `test_box_top_face_on_top`: a 1x1x10 box baked at bucket 0; the triangles' min y is about −10 px from the projected anchor (±0.5); the slot of the topmost triangle is `SLOT_ROOF`.
  - `test_bake_is_cached`: two `mesh()` calls return arrays with equal content, and the bake counter increments once.
  - `test_unknown_kind_gets_default_role`: `role("no_such_kind")` is a default role with non-empty `parts()` (not `usa_collector`: Task 4b gives it a real role).
  - `test_every_registry_kind_has_parts`: every kind in the registry yields non-empty parts at detail 0, 1 and 2.
  - `test_owner_palette_eight`: owners 1..8 give 8 distinct `SLOT_ROOF` colours, and owner 9 gives the grey fallback.
- [ ] Step 2: Run `WARGRID_TEST_ONLY=test_shapes sh tools/run_tests.sh`. Expected: FAIL.
- [ ] Step 3: Implement the three files. Use `Geometry2D.convex_hull` and `Geometry2D.triangulate_polygon` per face at bake time only.
- [ ] Step 4: Run the suite, lint and warnings. Expected: PASS.
- [ ] Step 5: GREEN; coordinator commits "Bake shape tables into triangle lists".

### Task 3: One depth-sorted triangle array (risk spike)

```text
Task: units, raised buildings and sources draw from one sorted triangle array via one canvas item; picking unchanged.
Owns: game/scripts/presentation/world_batch.gd, world_view.gd, structure_layer.gd, game/scripts/debug/movement_benchmark.gd (gate on), game/tests/test_view.gd, test_world_batch.gd, test_benchmark.gd, run_tests.gd
Invariant: every existing pick, box-select, focus, hint and cache test still passes, except V12's "behind parent" assertion, which is replaced. Picking keeps walking a depth-sorted entity list in reverse (front-most first).
Boundary: unit north/south/east/west of a 3x3 factory; air kind over a building; empty state.
Red: test_unit_in_front_of_factory_draws_later fails.
Green: test_world_batch.gd, test_view.gd, full suite; rendered run with default shapes.
Stop: any rendered layout over its draw-call ceiling, or Ashfall over 3.3 ms, with default shapes.
```

**Files:** Create `game/scripts/presentation/world_batch.gd`, `game/tests/test_world_batch.gd`. Modify `world_view.gd` (bodies are no longer `draw_rect`; `_depth_sorted` moves into `WorldBatch`), `structure_layer.gd` (ground footprints only), `game/tests/test_view.gd` (V12), `run_tests.gd`.

**Interfaces:**
- Consumes: `Shapes`, `ShapeBake`, `Palette` (Task 2).
- Produces: `WorldBatch`:
  - `const LAYER_DECAL := 0`, `LAYER_GROUND := 1`, `LAYER_AIR := 2`.
  - `static func objects(state: Dictionary) -> Array[Dictionary]`: the only snapshot reader of the new drawing code. Each item is `{id, kind, owner, role, layer, anchor: Vector2 (cells), footprint: Vector2i, heading: float (from the snapshot's `[x, y]` vector), target_id (from `combat.target_id`, -1 when none), hp, max_hp, rise: float, boxes}`; absent fields default. `rise` is 1.0 when `completed`, else `work / (Definitions.building(kind).ticks * 1000)` as `building_label` computes it (`world_view.gd:93`); the snapshot's `work` is an integer, not a fraction.
  - `static func sort_key(layer: int, anchor: Vector2, id: int) -> int`: layer, then ground depth (`anchor.x + anchor.y` at `DEPTH_SCALE` 1024), then id.
  - `func build(objects: Array[Dictionary], turret_angles: Dictionary, detail: int, flags: int, marks: Array[Vector2] = []) -> void` fills `points: PackedVector2Array` and `colors: PackedColorArray`. `marks` are plane points (today the horde marks) appended as small white diamonds after all bodies.
  - `func submit(item: RID) -> void` makes one `canvas_item_add_triangle_array(item, PackedInt32Array(), points, colors)`, and nothing when `points` is empty.
  - `var triangle_count: int`.
- `WorldView` owns a child Node2D `Bodies` (`show_behind_parent`, added after `Structures`, so it draws over the footprints and under the parent's overlays). `set_state` builds once and queues its redraw; `submit` runs inside its `_draw`, as `terrain_view.gd:39` does, because a node clears its canvas item on every redraw.

- [ ] Step 1: Write the tests.
  - In `test_world_batch.gd`:
    - `test_sort_key_orders_layers_then_depth`: air above ground at any depth; for equal layer, larger `x+y` later; for equal depth, lower id first.
    - `test_unit_in_front_of_factory_draws_later`: a unit at the south and east faces of a 3x3 `usa_factory` sorts after it.
    - `test_unit_behind_factory_draws_earlier`: the same at the north and west faces.
    - `test_air_kind_draws_above_ground`: `usa_collector` over a building is in `LAYER_AIR`.
    - `test_build_one_submission`: 300 objects give `points.size() % 3 == 0`, `colors.size() == points.size()`, and `triangle_count > 0`.
    - `test_empty_state`: no objects give empty arrays, and `submit` does not error.
    - `test_marks_join_the_array`: `build` with 3 marks adds exactly 6 triangles compared with none.
    - `test_rise_from_work`: a building at half of `ticks * 1000` work gives `rise` 0.5, a completed one 1.0.
  - In `test_view.gd`:
    - `test_pick_under_roof`: a tank at the cell north of a factory is picked at its ground anchor `+Vector2(0,-8)`. Clicking inside the factory's drawn roof but outside its ground footprint picks nothing (or the tank where bounds overlap, as today).
    - Replace V12's `show_behind_parent` check with `test_structure_bodies_in_shared_list`: the factory appears in `WorldBatch.objects()`. Keep V12's redraw-count checks for ground footprints.
    - `test_building_health_bar_in_overlay_pass`: a damaged building's bar is drawn by the parent, not by the `Structures` layer (a raised body would cover it there).
  - In `test_benchmark.gd`: `test_gate_fails_over_ceiling`: the finish path fails a default run whose draw calls exceed the ceiling, and a report-only run never does.
- [ ] Step 2: Run them. Expected: FAIL.
- [ ] Step 3: Implement `WorldBatch` and wire it into `WorldView.set_state`. Remove the body `draw_rect` and the building body drawing from `draw_structures()`. Keep `_vehicle_bounds` exactly as it is, since it feeds picking, and keep `_state.entities` depth-sorted: `pick_entity` and `pick_target` walk it in reverse. Move building health bars to the parent's overlay pass. Replace the per-mark `draw_colored_polygon` (`world_view.gd:208`) by `marks` in the array, and the air units' ground `draw_circle` (`:197`, also one polygon draw each) by shadow triangles in it; `horde_marks()` itself stays (benchmark assert, `test_horde_marks`). Glyphs and labels are Task 5's. Turn the draw-call gate on: `_fail` when `draw_call_failure` is non-empty on a default run.
- [ ] Step 3b: Append "Direct snapshot readers left in `world_view.gd`" (function names from `rg -n '_state\.' game/scripts/presentation/world_view.gd`) to the verification file, for the sim interface note.
- [ ] Step 4: Run the full suite, lint and warnings. Expected: PASS.
- [ ] Step 5: Rendered run (approved window, default shapes) to `~/projects/wargrid-art-work/t3-render.log`. Record each layout's `DRAW_CALLS`, frame p95 and Ashfall row, plus `uptime`. If a ceiling or the 3.3 guard is exceeded: stop, report numbers.
- [ ] Step 6: GREEN; coordinator commits "Draw bodies as one depth-sorted triangle array".

### Task 4: Lab shapes and decided body look

```text
Task: lab roles drawn in the decided look; damage, construction and supply states shown by shape.
Owns: shapes.gd, shape_bake.gd, palette.gd, world_batch.gd, test_shapes.gd, test_world_batch.gd
Invariant: picking and draw-call count unchanged by roles (still one array).
Boundary: hp exactly 70 % and 35 %; rise 0 and complete; boxes 0; small pile footprint; frc_builder uses infantry role.
Red: test_lab_roles_mapped fails.
Green: test_shapes.gd, test_world_batch.gd, full suite.
Stop: none.
```

**Interfaces (produces):** `Shapes` roles `&"tank_usa"`, `&"tank_china"`, `&"tank_frc"` (same role silhouette, exaggerated outline differences), `&"bulldozer"` (`usa_builder`, `china_builder`), `&"infantry"` (`*_rifle_infantry`, `*_rocket_infantry`, `frc_builder`; true size), `&"power_plant"` (`usa_power_plant`, `china_power_plant`), `&"war_factory"` (`*_factory`), `&"supply_source"`, `&"supply_depot"` (`*_supply_center`). Tank roles have a `&"turret"` part. `WorldBatch.build` flags: `FLAG_SHADOWS := 1`, `FLAG_OUTLINES := 2`, `FLAG_EFFECTS := 4`. `static func damage_stage(hp: int, max_hp: int) -> int` returns 0 (>70 %), 1 (≤70 %), 2 (≤35 %).

- [ ] Step 1: Write the tests.
  - `test_lab_roles_mapped`: each kind listed above maps to its role, and `frc_builder` maps to `&"infantry"`.
  - `test_damage_stage_edges`: `(70,100)` gives 1, `(71,100)` gives 0, `(35,100)` gives 2, `(36,100)` gives 1, `(0,0)` gives 0.
  - `test_damage_stage_changes_geometry`: a factory at stage 2 has a missing corner (fewer roof triangles than stage 0) plus smoke-column triangles in `SLOT_GLOW` or `SLOT_SIDE_DARK`. Stage 1 is darker roof colours with a missing corner and no smoke.
  - `test_building_rises_with_work`: the roof height at `rise` 0.5 is half of the completed height (±1 px), from `lifts` scaled at append time, with no new bake.
  - `test_supply_stack_shrinks`: the stack level comes from the absolute `boxes` count (the snapshot has no starting amount, so there is no "full"; the step size is the builder's call). Fewer triangles at `boxes` 1 than at a large count, and `boxes` 0 gives the base only. A small pile (`footprint` set) draws inside its own footprint.
  - `test_turret_pivot_on_hull_top`: for every bucket, the turret triangles' centroid stays within 1 px of the hull-top pivot's projection.
  - `test_shadow_only_with_flag`: `SLOT_SHADOW` triangles appear only when `FLAG_SHADOWS` is set.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement. Use calmer, darker owner roofs (sheet values as starting points). Stage looks as in the design; damage stage and stack level are `mesh()` variants. A unit shadow is one small ellipse-like quad under the body on `FLAG_SHADOWS`.
- [ ] Step 4: Run the full suite, lint and warnings. Expected: PASS.
- [ ] Step 5: GREEN; coordinator commits "Draw the lab objects in the decided look".

### Task 4b: Whole roster in the same vocabulary

```text
Task: every registry kind draws in the decided style (coarse, consistent), so no kind looks like a placeholder box.
Owns: shapes.gd, test_shapes.gd
Invariant: lab roles unchanged; still one triangle array; picking unchanged.
Boundary: usa_collector (helicopter, air layer, rotor part), frc_builder (infantry), defences with turrets, FRC with no power plant.
Red: test_no_kind_uses_default_role fails.
Green: test_shapes.gd, test_world_batch.gd, full suite.
Stop: none.
```

**Interfaces (produces):** class roles reusing the lab parts and slots: `&"light_vehicle"`, `&"collector_truck"`, `&"helicopter"` (rotor part with `&"fixed"` angle, air layer), `&"rocket_infantry"` (infantry plus a launcher cue), `&"command_center"`, `&"barracks"`, `&"defence"` (turret part), plus one per remaining building kind sized from its footprint. The default roles stay only as a fallback for kinds added later.

- [ ] Step 1: Write the tests.
  - `test_no_kind_uses_default_role`: every kind in the registry maps to a non-default role.
  - `test_roster_shares_slots`: every role's prims use only `Shapes` slot constants. No literal colours appear in shape data.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement the roles. Keep them coarse: the role silhouette plus one cue per role, nothing per kind beyond the faction outline difference.
- [ ] Step 4: Run the full suite, lint and warnings. Expected: PASS.
- [ ] Step 5: GREEN; coordinator commits "Draw the whole roster in the new vocabulary".

### Task 5: Overlays and terrain look

```text
Task: ground-diamond selection, health bar rule and colours, chevron placeholder, no glyphs, no heading ticks, no map text where the HUD shows it, restyled terrain with two biomes.
Owns: world_view.gd, terrain_view.gd, palette.gd, test_view.gd
Invariant: overlays stay rects/lines/primitives (no per-object polygons), one command type per pass; terrain stays cached.
Boundary: selected and full hp shows a bar; unselected and full hp shows none; hp 0.5 yellow-ish; biome change on the same map.
Red: test_health_bar_rule fails.
Green: test_view.gd, full suite.
Stop: a map label holds information the HUD does not show (keep it, record for M7.6, ask only if unclear).
```

**Interfaces (produces):** `WorldView`: `static func health_color(fraction: float) -> Color` (green 1.0, yellow 0.5, red 0.0, linear between). `static func shows_health(selected: bool, hp: int, max_hp: int, hovered: bool) -> bool` (selected, or damaged, or hovered; hover is answered for M7.6, so it is included). `func set_biome(biome: int) -> void`. `TerrainView`: `func set_palette(colors: Dictionary) -> void` forces a redraw.

- [ ] Step 1: Write the tests.
  - `test_health_bar_rule`: `shows_health(false,100,100,false) == false`, `(true,100,100,false) == true`, `(false,99,100,false) == true`, `(false,100,100,true) == true`.
  - `test_health_color_ends`: 1.0 gives green, 0.5 gives yellow, 0.0 gives red (exact palette values).
  - `test_selection_is_ground_diamond`: a selected unit adds 4 line segments around its ground anchor, and no rect outline.
  - `test_biome_change_redraws_terrain`: the terrain draw count rises by one after `set_biome(1)` on the same map.
  - `test_grid_only_while_placing`: no grid lines without a preview, and grid lines with one. Starting or ending a preview must not redraw the cached terrain (`terrain.draws` unchanged): the grid moves out of `terrain_view.gd`.
  - `test_no_glyphs_or_heading_ticks`: a state with a building and a moving tank draws no glyph and no heading line.
  - `test_chevron_placeholder`: a unit dictionary with a `veterancy` field of 1 draws one chevron mark. Veterancy is not in the snapshot yet, so the test feeds a hand-made dictionary through the overlay function directly.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement. Mid-tone ground `#575C55` for biome 0; biome 1 from the A/B candidate (art direction sheet). Cliffs as a low raised step with a lit top. Water muted blue-grey. Remove the building glyphs (look Q11 a) and the heading ticks (user, 2026-11-10) with their tests (`test_building_icons`, `test_heading_mark_layout`). Remove building and pile labels only where the selection panel already shows the value; adjust the pile-label tests to match. A label that stays moves to the overlay pass, above the bodies.
- [ ] Step 4: Run the full suite, lint and warnings. Expected: PASS.
- [ ] Step 5: GREEN; coordinator commits "Restyle overlays and terrain".

### Task 6: Visual events and local motion

```text
Task: VisualDirector collects events every step; shots, hits, death fades and cosmetic turret aim drawn from it.
Owns: game/scripts/presentation/visual_director.gd, world_view.gd, world_batch.gd, skirmish_main.gd, online_main.gd, movement_benchmark.gd, game/tests/test_visual.gd, run_tests.gd
Invariant: SoundDirector behaviour and tests unchanged; no event drained from sound.
Boundary: two steps per refresh; same tick twice; restart; dead target; unknown id; pause; no target; Low quality.
Red: test_visual_catch_up_and_stall fails.
Green: test_visual.gd, test_sound.gd, full suite.
Stop: none.
```

**Interfaces (produces):** `VisualDirector` (RefCounted):
- `const MAX_PENDING := 8`, `MAX_EFFECTS := 256`, `FADE_TICKS := 60` (2 s at 30 ticks/s), `TURRET_RATE := 0.15` rad per tick (cosmetic; batch A replaces it).
- `func collect_step(tick: int, events: Array[Dictionary], results: Array[Dictionary]) -> void`.
- `func update(objects: Array[Dictionary]) -> void`: consume each pending tick once, keep last-known anchors, age effects, step turret angles toward targets. The target is the object's `target_id` (snapshot `combat.target_id`), not the shot event, so a turret turns before it fires; with no target it turns back to the hull heading at the same rate.
- `func effects() -> Array[Dictionary]`: items `{type: &"muzzle" | &"hit" | &"fade", anchor: Vector2, age: int, id: int}`.
- `func turret_angles() -> Dictionary`, keyed by id, absolute angles (same frame as `heading`).
- `func reset() -> void`.
- `func consumed_ticks() -> Array[int]`.

Call sites: next to `collect_step` in `skirmish_main.gd:44` and `online_main.gd:55`; in `movement_benchmark.gd` on every horde tick regardless of `--sound`. `WorldView` gains `func set_visuals(director: VisualDirector) -> void`.

- [ ] Step 1: Write the tests in `test_visual.gd` (pattern: `test_sound.gd`).
  - `test_visual_catch_up_and_stall`: two steps collected before one update give both ticks' muzzles once. The same tick collected twice gives one set.
  - `test_coalesced_muzzle`: one splash attack with 3 damage records gives one muzzle.
  - `test_unknown_position_skipped`: an event for an id never seen gives no effect and no error.
  - `test_dead_target_hit_at_last_known`: a target removed in the step it is hit gets its hit at its last anchor.
  - `test_fade_lasts_two_seconds`: a death gives a `fade` effect that is gone after 60 updates.
  - `test_reset_clears_presentation_state`: after reset, a reused id has no turret angle and no effects.
  - `test_turret_turns_at_fixed_rate`: a target π/2 away is reached after `ceil((PI/2)/0.15)` updates, not sooner.
  - `test_turret_returns_to_hull`: after the target is cleared, the angle steps back to the hull heading.
  - `test_cues_draw_on_low`: muzzle, hit and fade triangles are built with `flags` 0.
  - `test_pending_bounded`: 20 collects without an update keep at most `MAX_PENDING` (oldest dropped, counted).
  - `test_paused_does_not_age`: no `update` call means no aging (the driver guard is the pause).
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement. Wire the director into the three drivers. Muzzle, hit and fade go in `LAYER_GROUND` as triangles on both qualities: they replace today's shot line and death cross, which every player sees. `FLAG_EFFECTS` gates only extras (the smoke column and what Task 9's variants add). Replace the unit shot line and the death cross in `_draw_cues` with the director's muzzle, hit and fade. `battery_target_lines()` and `building_shot_lines()` keep working; their tests (`test_battery_target_line`, `test_battery_shot_line`) stay green or are rewritten against `effects()`, never deleted.
- [ ] Step 4: Run the full suite (including `test_sound.gd`), lint and warnings. Expected: PASS.
- [ ] Step 5: GREEN; coordinator commits "Collect visual events every simulation step".

### Task 7: Quality Low/High and zoom detail

```text
Task: quality setting stored, auto-picked once, switchable in the pause menu; zoom changes the detail level.
Owns: game/scripts/presentation/graphics_settings.gd, world_view.gd, main.gd (change_zoom notify), pause_menu.gd, game/tests/test_graphics_settings.gd, test_pause_menu.gd, run_tests.gd
Invariant: audio settings in the same file untouched.
Boundary: missing or corrupt settings file; auto-pick runs only once, never headless and never in the benchmark.
Red: test_low_drops_flags fails.
Green: new suite, test_pause_menu.gd (layout), full suite.
Stop: none.
```

**Interfaces (produces):** `GraphicsSettings`:
- `const LOW := 0`, `HIGH := 1`, `AUTO_LOW_P95_MS := 8.3` (half a 60 Hz frame; my call, recorded).
- `static func load_quality() -> int` returns -1 when unset. Reads and writes `AudioSettings.path`, so the tests' scratch redirect (`test_audio_settings.gd:11`) covers it and the real file is never touched.
- `static func save_quality(quality: int) -> void` writes section `graphics`, key `quality` in `user://settings.cfg`.
- `static func pick(frame_p95_ms: float) -> int`.
- `static func flags(quality: int) -> int`: High gives shadows, outlines and effects; Low gives 0.
- `static func detail(quality: int, zoom: float) -> int`: Low gives 0; High gives 0, 1 or 2 for zoom 0.5, 1.0 or 2.0.

`WorldView.set_quality(quality: int)` and `WorldView.set_zoom(zoom: float)`. `main.gd change_zoom` calls `set_zoom`. Auto-pick: the first match with no stored value measures 120 frames on High, then saves `pick(p95)`. The measured value is CPU time per frame (Task 8's Web method), not the frame interval: with vsync on the interval is at least 16.7 ms at 60 Hz and would always pick Low. Skipped when `DisplayServer.get_name() == "headless"` (scene tests) and in `movement_benchmark.gd`. `shortcut: measured at match start on a nearly empty map, so it only catches very slow machines; re-check under load if playtesters report a slow High.`

- [ ] Step 1: Write the tests.
  - `test_low_drops_flags`: `flags(LOW) == 0`, and `flags(HIGH)` has all three flags.
  - `test_detail_by_zoom`: Low at 2.0 gives 0; High at 0.5, 1.0 and 2.0 gives 0, 1 and 2.
  - `test_pick_threshold`: 8.3 gives HIGH and 8.31 gives LOW.
  - `test_settings_round_trip_keeps_audio`: saving the quality keeps the stored audio volumes.
  - `test_corrupt_file_gives_unset`.
  - `test_auto_pick_skipped_headless`: a headless skirmish start with no stored value saves nothing.
  - In `test_pause_menu.gd`, a headless layout test: the quality toggle overlaps no other control or text.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run the full suite, lint and warnings. Expected: PASS.
- [ ] Step 5: GREEN; coordinator commits "Add Low and High graphics quality".

### Task 8: Numbers (stop gate 2)

```text
Task: measured rows for the new look; proof of no simulation change.
Owns: movement_benchmark.gd (500-unit horde variant, quality/zoom/layout args), game/scripts/debug/combat_workload.gd (horde_render_500), export_presets.cfg and project.godot (rendered web preset), docs/reference/art-lab-verification.md, docs/reference/performance.md (rows)
Invariant: budgets, ceilings and guards unchanged.
Boundary: a row over budget is recorded as exceeded, not rerun until it passes.
Red: test_horde_render_500_counts fails (layout missing).
Green: suite; sh tools/run_benchmark.sh; rendered rows; web rows; netplay.
Stop: always (user sees numbers before A/B work).
```

**Interfaces (produces):**
- `CombatWorkload.create("horde_render_500")`: the horde with a 25x16 army, so 400 plus 100 enemies gives 500 units. `assert` this layout in the factory.
- Benchmark user args `-- --quality=low|high` (default high), `-- --zoom=0.5|1|2` (default 0.5), `-- --layout=<name>` (that layout only) and `-- --units=500` (horde only). Any of them makes the run report-only (Global Constraints). The header prints the real values (today it hard-codes `zoom=0.5` and `units=300`, `movement_benchmark.gd:54`).

- [ ] Step 1: Write `test_horde_render_500_counts` in `test_benchmark.gd`: the snapshot has 500 entities, 400 of them owner 1. Run it; expected FAIL; implement; PASS.
- [ ] Step 2: Run `sh tools/run_benchmark.sh` alone, with `uptime` at start and end. Expected: exit 0, or report each failing BUDGET line exactly.
- [ ] Step 3: Rendered rows, in one approved window session, each to `~/projects/wargrid-art-work/t8-*.log`:
  - (a) default High at zoom 0.5, all four layouts, gated;
  - (b) `--quality=low`, report-only;
  - (c) `--zoom=2 --layout=horde`, report-only;
  - (d) `--units=500`, report-only.
  Note the load (the host may be busy; tag rows, rerun when quiet).
- [ ] Step 4: Web: add an export preset `Web Render Bench` with `custom_features="wargrid_render_bench"` and the override `run/main_scene.wargrid_render_bench="res://scenes/movement_benchmark.tscn"` in `project.godot` (as `run/main_loop_type.wargrid_bench` does, `project.godot:13`). The browser passes no user args: on that feature the benchmark runs only `horde` then `ashfall`, prints `vsync=browser` and posts its lines to `/result` as `bench_runner.gd:89-97` does. Measure CPU time per frame (method: my call, recorded in the row) as the sum of the script time the benchmark already takes with `Time.get_ticks_usec()` (tick plus `set_state`, and the `_draw` calls), `RenderingServer.viewport_get_measured_render_time_cpu()` (after `viewport_set_measure_render_time(true)`) and `RenderingServer.get_frame_setup_time_cpu()`: the method the levers note §6 takes from `RenderingServer.xml:4097-4101`. Not `Performance.TIME_PROCESS`: Godot publishes it once a second as the largest frame of that second, it already contains the draw and it leaves out the physics step where the tick runs (4.7-stable `main/main.cpp`, `Main::iteration`). Whether the measured render time works on WebGL is not verified (levers note §6): print the three parts separately, check them natively first, and if the render part reads 0 in Firefox report script time alone and say so in the row. Run in Firefox (`open -a Firefox`). Label the row "CPU frame time, not vsync-off interval"; compare against 3.04 × 5.5. **Correction (2026-11-10, gate 2):** 3.04 × 5.5 is wrong for a Mac Firefox number (F is target / Mac editor): divide it by the Mac Firefox / editor ratio (1.42-1.60) and compare with 3.04, or multiply by the Deck / Mac Firefox ratio (3.5-4.1) and compare with 16.7.
- [ ] Step 5: No simulation change. `git diff main -- game/scripts/simulation game/scripts/net` must be empty. Full suite (replay, hash and trace tests). `sh tools/run_netplay.sh` default scenarios: the same result lines as on main. CI traces (`compare_local_traces.sh`) run only after a user-approved push: record them as pending.
- [ ] Step 6: Write the ledger rows (tree, load, rows a–d, web) and the verification rows.
- [ ] Step 7: Opus gate review (milestone prompt brief), then fix findings test-first. Coordinator commits. **STOP**: show the user the numbers. Exceeded budgets go to the user (performance spike or budget decision).

### Task 9: A/B lab (lab-only files; stop gate 3)

```text
Task: a lab scene with a scripted fight and two variants for each of seven questions, answered by clicks.
Owns: game/scenes/art_lab.tscn, game/scripts/lab/art_lab.gd, game/scripts/lab/ab_variants.gd, game/tests/test_art_lab.gd, run_tests.gd; ~/projects/wargrid-art-work/ab/ (page, outside the repo)
Invariant: no file outside the lab-only paths imports lab code; the fight runs on the unchanged simulation.
Boundary: every variant x {Low, High} draws without error; the fight shows shots, deaths, damage stages 1 and 2, construction and supply pickup inside 60 s.
Red: test_lab_fight_shows_every_state fails.
Green: test_art_lab.gd, full suite, lint, warnings.
Stop: always (A/B session needs the user and a visible window).
```

**Interfaces (produces):**
- `AbVariants`:
  - `const QUESTIONS: Array[StringName] = [&"biome", &"fog", &"shots", &"signature", &"shake", &"hit_flash", &"wrecks"]` (world Q1, Q6, Q7, Q9, Q10, Q11, Q13).
  - `func set_variant(question: StringName, variant: int) -> void` (0 = A, 1 = B).
  - `func apply(view: Node2D, camera: Camera2D) -> void`.
- Variants plug into the existing hooks: biome through `set_biome`; fog as a static mask overlay on the lab only; shots, signature, hit flash and wrecks as extra effect entries from `VisualDirector.effects()`; shake as a camera offset.
- Lab keys: `1`–`7` pick the question, `Tab` switches between variant A and B, `Q` toggles Low/High (`A`, `S`, `B` and `1` are taken in the match scenes; the lab scene must not inherit those handlers). A HUD line shows the question, the variant and the quality.
- `test_lab_fight_shows_every_state`: run the lab fight headless for 1800 ticks, then assert at least one shot event, one death, a building at damage stage 1 and at stage 2, one construction in progress, and one supply pickup.
- `test_every_variant_draws`: for each question × variant × quality, a `set_state` and a draw report no errors, and the bodies draw-call count stays 1.
- Isolation is a command, not a test: `rg -n 'scripts/lab|art_lab' game --glob '!game/scripts/lab/**' --glob '!game/tests/test_art_lab.gd' --glob '!game/scenes/art_lab.tscn'` prints only the `SUITES` entry of `run_tests.gd`. Record its output in Step 4 and again in Task 10.

- [ ] Step 1: Write the two tests. Run them. Expected: FAIL.
- [ ] Step 2: Implement. Build the fight from the public simulation calls (`spawn`, `add_player`, `issue_command`, `add_supply_source`), seeded so it repeats.
- [ ] Step 3: Build the click page at `~/projects/wargrid-art-work/ab/index.html`: one page per question, buttons A, B and "neither", auto-advance. Each click POSTs every answer given so far to `/result`: the server names its files by the second (`serve_web_bench.py:27`), so two quick clicks overwrite each other and the newest file must hold everything. Serve it with `python3 -I tools/serve_web_bench.py ~/projects/wargrid-art-work/ab ~/projects/wargrid-art-work/ab-results`.
- [ ] Step 4: Run the full suite, lint and warnings. GREEN; coordinator commits "Add the art lab A/B scene".
- [ ] Step 5: **STOP** for the user's A/B session: ask for window approval, then open the lab (`sh tools/run_game.sh res://scenes/art_lab.tscn`) and the page in Firefox. The user judges each question on Low and High.

### Task 10: Exit gate

```text
Task: answers recorded, final evidence, reviews.
Owns: docs (blueprint §7 M7.5 look answers, docs/questions/next-m75-art-world.md "Answered" lines, art-lab-verification.md, performance.md, session-notes.md, development.md status line)
Invariant: no budget, ceiling or label changed.
Boundary: an A/B answer of "neither" stays open, not invented.
Red: n/a (docs).
Green: full suite, run_benchmark.sh, rendered rerun on the final tree, lint, warnings, link check.
Stop: always (merge, push and deploy are the user's).
```

- [ ] Step 1: Copy each click result into the question file ("Answered 2026-11-.. (in-game A/B)") and blueprint §7 M7.5. Delete the A/B variants the user rejected, inside the lab-only files only.
- [ ] Step 2: Final tree: full suite, `sh tools/run_benchmark.sh`, a rendered rerun if anything after Task 8 changed presentation, lint, warnings. Record each result with the tree it ran on.
- [ ] Step 3: Opus gate review (fresh context, milestone prompt brief), then `/ponytail-review` on `main..spike-art-lab`. Fix findings test-first.
- [ ] Step 4: **STOP**. The final message reports implemented, verified and pending separately: CI traces after push, the user's merge decision (foundation without `game/scripts/lab/`, `art_lab.tscn`, `test_art_lab.gd` and its `SUITES` entry), and the playtest of the look. It names the next queued step: the sim interface and determinism rules notes, then `run docs/native-sim-spike-prompt.txt`.

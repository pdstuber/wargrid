# Art lab spike design (M7.5 Task 1)

Status: **approved by the user 2026-11-10** (short design plus four changes from a check against later milestones; full doc after the builder check, same day). Pre-run check against the code and the ledger 2026-11-10 (same day, later): adapter scope narrowed and heading ticks removed (both user), horde marks batched, draw-call gate on from Task 3, Low keeps shot cues, auto-pick and Web measure CPU time, "neither" answer; no goal changed. Handoff: art lab prompt (`art-lab-prompt.txt`, private). Decisions it builds on, not re-asked: blueprint §2, §7 M7.5 (scope, look and A/B look answers), §11 "Targets for the new look"; question files `docs/questions/next-m75-art-scope.md`, `next-m75-art-look.md`, `next-m75-art-world.md`, `next-perf-targets.md`. Evidence: [integration note](../../reference/art-godot-integration.md), [perf levers](../../reference/art-perf-levers.md) (lever 3A), [performance ledger](../../reference/performance.md), [art direction](../../art-direction/ART_DIRECTION.md).

(Corrected 2026-11-12: as built, shapes are baked on first use and cached (`shape_bake.gd` `mesh`), not at load. The lab on `main` keeps five A/B questions (`game/scripts/lab/ab_variants.gd` `QUESTIONS`: biome, signature, shake, owner palette, sand tone). It started with 17 (`5fe0a30`) and peaked at 18 (`8f8a80e`); questions were cut in the exit review (`dc2bec0`, 15 left), when the winners became defaults (`6024e7b`, 8 left) and in the lean review (`ab698df`, 5 left). Results: [art lab verification](../../reference/art-lab-verification.md).)

## Intent

Put the chosen geometric 2.5D look into the real game for a few objects. Measure it against the unchanged render budgets on native and Web, and settle the seven world look questions that SVG pages could not settle, using two in-game variants each. Evidence spike: branch `spike-art-lab`, worktree `~/projects/wargrid-wt-art`, scratch output in `~/projects/wargrid-art-work`. Presentation only.

**Goals**
- The lab objects draw in the decided look in skirmish, online and benchmark scenes.
- One triangle array per tick for all raised objects, inside a fixed draw-call ceiling.
- Rendered benchmark rows (native, vsync off) and a Web frame-time measurement of the same scene.
- The user's A/B answers for world Q1, Q6, Q7, Q9, Q10, Q11, Q13, judged on Low and High, recorded by clicks.
- Proof of no simulation change: traces and pins identical to `main`.

**Non-goals:** the rest of the roster's final, detailed shapes (it gets coarse consistent ones), aircraft, add-ons, real fog, travelling shells as simulation objects, turret aiming in simulation, veterancy (placeholder test only), interpolation, threads, HUD changes, merging.

**Anti-goals (a failure even if it works):** any simulation, replay, hash or trace change; a loosened budget, assumed slowdown or assertion; per-polygon `draw_colored_polygon` per unit; changed picking or selection behaviour; cosmetic separation that pushes overlapping units apart; owner colour baked so that palette or ally/enemy colours need a re-bake of shapes.

## Constraints

- Godot 4.7.2, Compatibility renderer, 1280x720, 30 ticks/s; world redrawn once per tick (perf Q5 a).
- Budgets unchanged: rendered frame p95 3.04 ms on the dev machine, Ashfall guard 3.3 ms (`movement_benchmark.gd:11`), F = 5.5. **Ashfall headroom is small:** p95 2.25-2.83 ms on the post-P1 rerun (46020ab, n 2) against 3.04 at 45 draw calls, earlier `--profile` runs 2.89-3.02 (ledger line 267). Horde is already over budget (3.51-4.08 ms, report-only G11). The look is not negotiable (user): an overrun is reported and goes to a performance spike or an explicit budget decision, never loosened.
- The renderer reads only `snapshot()`, `combat_events()` and `command_results()` plus registry and combat definitions (today `world_view.gd:126` reads `CombatDefinitions.weapon`; the approved [interface plan](../plans/2026-11-09-sim-interface-note.md) names the interface but builds no adapter), through one adapter this spike creates. **Scope (user, 2026-11-10):** the new drawing code (bodies, effects, lab) reads only through the adapter; `world_view.gd`'s existing picking, overlay and mark readers (about 30 direct reads) stay untouched and are listed in the verification file for the sim interface note, so a later native core or snapshot format change touches the adapter plus that list.
- Snapshots are read-only. Presentation state (turret angle, effect age, fade timers) lives outside snapshots, hashes and commands, keyed by entity ID, cleared on match reset.

## Approaches

| | Approach | Trade-off | Verdict |
|---|---|---|---|
| A | Shape list per kind, triangulated once at load per (kind, part, heading bucket); per tick all raised objects appended in depth order into one `RenderingServer.canvas_item_add_triangle_array` | one draw call, keeps crisp vectors and the painter's order; CPU cost is about two appends per part per object per tick | **chosen** (scope Q8, Q9; levers 3A) |
| B | Baked texture atlas per kind and heading, drawn as batched rects | batches well, but owner colour needs masks, MBs of memory, blurs under zoom | rejected |
| C | MultiMesh per kind | breaks depth order between kinds in the isometric overlap | rejected |
| — | `draw_colored_polygon` per face | 3,000-7,500 GL draws per frame for 300 units | anti-goal |

## Design

### Shapes
- `shapes.gd`: a data table per presentation role. Each role is a list of **parts** (hull, turret, roof, chimney, ...). Each part is a short list of boxes and cylinders: offset, size, height, colour slot. Each part names its angle source: `heading` (hull), `turret` (presentation angle), or `fixed` (buildings).
- Kind to role mapping is explicit (no inference from weapon data). Faction shape follows kind; owner tint follows owner.
- Lab roles: tank (`usa_tank`, `china_tank`, `frc_tank`, three exaggerated outline variants, look Q6), bulldozer (`usa_builder`, `china_builder`; `frc_builder` is an infantry Laborer and uses the infantry role), infantry (`*_rifle_infantry`, true size), power plant (`usa_power_plant`, `china_power_plant`; FRC has none), war factory (`*_factory`), supply source, supply depot (`*_supply_center`).
- Every other kind gets a coarse role in the same vocabulary (see "Consistent look" below), through the same pipeline, so there is one depth list; a default box sized from footprint or radius remains the fallback for unknown kinds.
- **Colour slots, not colours:** cached triangles carry a slot index (owner roof, owner dark, neutral side, machinery, glow, outline). Colours resolve per owner when appending, from a palette table, so the ally/enemy option, 8 owner colours and later stealth alpha need no re-bake.

### Baking
- At load, each (role, part, bucket) is projected with the existing isometric projection (`isometric.gd`, visual height added above projected ground) and triangulated once into a flat triangle list plus slot list. Box faces: top plus the visible side faces for that bucket.
- **64 heading buckets** (constant, measured in the lab): any-angle movement and slow Zero Hour turn rates make 16 buckets snap visibly.
- Turret parts rotate around a pivot on the hull top, not the ground anchor: lab test at all buckets.
- Detail per zoom step: one shape set per zoom value (0.5, 1.0, 2.0). Far-zoom shapes are also Low quality's shapes at every zoom.

### Drawing
- One ordered list per tick: sort key `(layer, ground depth, id)`. Layers: ground decals, ground objects, air. The lab fills only ground objects (static fog mask and A/B decals are overlays). Batch A hazard fields, later fog ghosts and aircraft need the other layers.
- Units **and** raised buildings share the list. Terrain stays cached. Building ground footprints stay cacheable. The `show_behind_parent` structure layer stops being the building body (integration note §2). The old test that asserts structures behind units is replaced by verified occlusion, and cache checks are kept. Draw order: terrain, ground footprints, bodies, then overlays. What must stay readable over a raised body (building health bars, any label that stays) draws in the overlay pass, not in the cached footprint layer.
- Overlays drawn on top in batched rects and lines: white ground-diamond selection, health bars green-yellow-red when selected or damaged, chevron placeholder, small per-unit shadow on High (in the triangle array, under the body). Heading ticks are removed (user, 2026-11-10): the shapes show heading. Horde marks stay but leave `draw_colored_polygon` (one GL draw each, `world_view.gd:208`): they join the triangle array.
- Picking unchanged: ground footprints for buildings, the existing unit bounds for units. Ground footprint, rendered bounds and selection bounds are three separate concepts; `_vehicle_bounds()` keeps feeding picking.
- Decided look (blueprint §7 M7.5): calmer darker owner roofs, mid-tone ground (starting value #575C55), damage looks at 70 % and 35 % with a static smoke column below 35 %, buildings rise while built, supply stacks shrink, no text on the map, grid only while placing, cliffs as a low step, water muted blue-grey, bodies fade within about 2 s, turrets turn toward the target at a fixed rate (presentation only).
- Motion only from confirmed displacement and heading. No extrapolation, no cosmetic separation.

### Visual events
- A `VisualDirector` beside `SoundDirector`, fed by `collect_step` at every place that already collects sound (`skirmish_main.gd:44`, `online_main.gd:55`). In `movement_benchmark.gd` sound is collected only in `--sound` mode (`:195-197`); the visual director is fed on every horde tick regardless of mode, so effects are inside the timed window. It copies only the event fields it needs, rejects repeated ticks, bounds pending history and active effects, and resets on restart. It never drains the sound queue.
- Events carry no positions; effects use last-known positions of known objects and skip unknown ones.
- Several damage records from one attack coalesce into one muzzle cue.
- Tests: catch-up (two steps before one refresh), repeated tick, restart, dead target, unknown position, pause.

### Quality
- Low and High. Low drops outlines, shadows and extra effects and uses the far-zoom shapes at every zoom. Shot, hit and death cues are not extra: they replace today's shot line and death cross and draw on both.
- Stored in `user://settings.cfg` like the audio settings. On first start it is picked from measured CPU time per frame, the same measure as the Web row (the frame interval cannot be used: with vsync on it never drops below the display's refresh period). Threshold is the builder's call, recorded in the plan. Changeable in settings.

### A/B lab
- A lab scene with a scripted, deterministic fight (shots, deaths, damage stages, construction, supply pickup) on the existing simulation, so every variant shows the same content.
- Keys switch variant A/B per question and Low/High. Questions: map biome (Q1), fog look as a static mask (Q6), shot look on today's instant shots (Q7), signature effects (Q9), camera shake (Q10), hit flash (Q11), wrecks (Q13).
- Answers: a small local server writes each click to a file under `~/projects/wargrid-art-work`. One page per question with A, B and "neither" (stays open), auto-advance, opened with `open -a Firefox`.

### Gates and measurement
- **Draw-call ceilings:** 50 on the 300-unit `open`, `dense` and `horde` layouts, 60 on `ashfall`, asserted in `movement_benchmark.gd` for all four layouts. Task 1 records today's baseline before the look lands, report-only: `horde` is at 238-239 on `main` (ledger row 2026-11-08, sound spike Task 7), almost all horde marks. The ceilings fail a run from Task 3 on, when bodies and marks are batched. The numbers are fixed in the plan and never raised to pass.
- Rendered benchmark, vsync off, the new look on, High quality, zoom 0.5 (as every earlier row): native rows for all four layouts at 300 units (`horde`: 300 plus 100 enemies). `horde` is the only rendered combat layout, so it carries shots, effects and damage looks; its frame budget stays report-only as today (G11). Plus a report-only 500-unit `horde` row (3v3 and batch A will pass 300).
- Low quality: one report-only row per layout at zoom 0.5. One report-only High row at zoom 2.0 on `horde` (largest vertex count per unit).
- Web: the `horde` and `ashfall` scenes in Firefox. Vsync cannot be turned off there, so the measured value is CPU frame time; the method is the builder's call and is named in the row. Compared against budget × F, labelled as a different metric. **Correction (2026-11-10, gate 2):** F is target / Mac editor, so a Mac Firefox number is divided by the Mac Firefox / Mac editor ratio (1.42-1.60) and compared with the 3.04 ms dev budget, or converted to the Deck with the Deck Firefox / Mac Firefox ratio (3.5-4.1) and compared with 16.7 ms; never Mac Firefox against 16.7.
- No simulation change: full suite, `sh tools/run_benchmark.sh`, netplay traces and pins identical to `main`.

### Stop gates
1. Plan approval (user).
2. After the renderer and benchmark numbers (user sees numbers before the A/B work).
3. A/B session (visible windows need approval).
4. Exit: Opus gate review, `/ponytail-review`. Push, merge and deploy wait for the user. Final message names the next queued step: the sim interface and determinism rules notes, then `run docs/native-sim-spike-prompt.txt`.

## Fit with later milestones (checked 2026-11-10)

| Later work | How this design carries it |
|---|---|
| Movement milestone (any angle, size classes, finer grid) | 64 buckets; drawn size per size class; renderer independent of the grid |
| Batch A turrets, add-ons, drones, garrison | parts with their own angle source; the turret source switches from presentation to snapshot |
| Batch A travelling shells, hazard fields | shells become snapshot objects in the same list; hazards in the ground-decal layer; flashes stay events |
| M7.6 HUD | unlimited selection and hover bars are more batched overlay rects; minimap separate |
| M7.9 fog, batch B stealth | renderer draws only the list it is given; ghost buildings come from team state; alpha through colour slots |
| Ally/enemy option, 8 owners | colours resolve at append time |
| Aircraft (Later) | air layer above ground objects, ground shadow |
| Interpolation (High, later) | pre-baked buckets make a per-frame rebuild cheap |
| Native core spike | one snapshot adapter |

Batch B and M9 have no detailed scope yet; "fits" there only means nothing named conflicts.

### Terrain and code quality
- Terrain is restyled in the spike: mid-tone ground, cliffs as a low step, muted water, and the two biome variants (Q1) through a palette change with an explicit terrain redraw (the cache is keyed by map identity). Converter decoration (roads, rocks, tree clusters) is a `tools/zh_map/` change and stays out of the lab; it lands in the rest of M7.5 (user, 2026-11-10: "I do want trees and shit in my map later"). Lab shapes must leave room for decoration objects in the ground-object layer.
- **Outcome (user, 2026-11-10): a mergeable foundation.** The renderer core (shapes, baking, one depth list, visual events, quality setting, draw-call gate) and the decided look are built to merge; the A/B variants and the lab scene live in separate lab-only files that stay on the branch. Merge is decided at the exit gate, only with passing gates or an explicit budget decision by the user. **Consistent look (user, 2026-11-10: "surprise my playtesters with an updated look that is consistent in itself, even though absolutely not complete yet"):** every kind gets a coarse role in the same vocabulary (class silhouettes plus one cue, faction outline differences), so no kind stays a placeholder box; the lab kinds get the full detail. The default box stays only as a fallback for kinds added later. Spike code meets `AGENTS.md`: typed GDScript, lint, warnings and the full suite pass, behaviour tests alongside.

## Risks
1. Ashfall frame p95 has 0.21-0.79 ms headroom on the latest rerun; the new look may exceed it. Horde is already over.
2. Moving building bodies out of the cached structure layer makes them redraw every tick.
3. GDScript append cost per part per object per tick, worst at 500 units.
4. Web frame time is a different metric from native vsync-off intervals.
5. Readability at zoom 0.5 (tank about 15 px wide); judged on screen, not from the sheets.

## Left to the builder
Exact box dimensions and colour values (sheet and mock-up values are starting points), the Low/High auto-pick threshold, the Web CPU frame-time method, the lab fight script, the click server's form (`tools/` style Python, as `serve_web_bench.py`), the A/B variant details within each question's two options, and file names inside `game/scripts/presentation/`.

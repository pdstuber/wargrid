# Art pass: Godot integration findings

Written by GPT with the [art direction](../art-direction/ART_DIRECTION.md) (moved here from `docs/art-direction/GODOT_INTEGRATION.md` on 2026-11-09). Evidence for planning M7.5, not decisions; recheck the cited code before relying on it. The `spike-avoidance` links work only once that branch is pushed.

**Recommendation:** keep Wargrid's centralized 2D drawing and deterministic simulation. Implement the geometric 2.5D style as presentation geometry, with explicit ground anchors, role attachments and a small amount of local animation state. First resolve depth ordering, combat-event delivery and actual screen-size readability. A 3D migration or per-unit scene hierarchy is not justified by this art direction.

Source inspection: 2026-11-09. Game baseline: `spike-design` at `07c3ab65f373212816c1f34e6361e5a9b08cff28`. Avoidance research: `spike-avoidance` at `a9a0e3cd1825bbf05837d3898378d75657d6d345`, inspected in its separate worktree without switching or modifying either branch. Links below pin these revisions. Findings describe code; recommendations remain unimplemented. The thirteen [interview answers](../art-direction/ART_DIRECTION.md#1-authority-and-the-thirteen-decisions) are the starting point (revisable, user 2026-11-09).

## 1. Fit the existing presentation boundary

The current flow is simulation step → snapshot → `WorldView.set_state()` → cached drawing commands. The main driver refreshes after stepping; online play can advance multiple simulation ticks before that refresh. `WorldView` owns the unit drawing and overlays, with cached terrain and structure children. HUD lives on a separate `CanvasLayer`. See [main driver][main], [online driver][online], [world view][view] and [scene][scene].

| Existing boundary | Recommended use |
|---|---|
| `isometric.gd`: ground projection `(32*(x-y), 16*(x+y))` and inverse | Keep projection and ground picking. Add visual height above projected ground; do not move simulation positions to make roofs look right. |
| `world_view.gd`: units, selection, health, headings, effects | Start with explicit geometry for the approved lab roles. Keep owner color, faction shape and damage/selection state separate. |
| `terrain_view.gd`: map-identity cache | Preserve navigation data and cached ground. Biome color belongs to presentation; a palette change needs an explicit redraw even when map identity stays the same. |
| `structure_layer.gd`: cached building/resource drawing | Keep ground footprints cacheable. Raised geometry needs the depth treatment below; production animation cannot rely on the existing cache key. |
| Simulation snapshots and kind registry | Read capabilities and confirmed state. Store recoil, visual aim, effect age and animation phase outside snapshots, state hashes and commands. |

This matches Godot's documented custom-drawing behavior: “the draw commands are cached and remembered”; changes require `queue_redraw()`. Per-frame machinery therefore needs deliberate invalidation, not an assumption that `_draw()` runs every frame. [Godot custom drawing](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html).

`WorldView.set_state()` makes a shallow dictionary copy. Simulation snapshots deep-copy mutable unit fields but share frozen route arrays. Treat every received snapshot as read-only. A small presentation-state dictionary keyed by entity ID is sufficient for a first lab; clear it on match reset because IDs can be reused. Do not add a model framework, dependency or SVG parser. The sheets specify shapes; their page layouts are not runtime assets. [Snapshot implementation][simulation].

## 2. Resolve depth without breaking picking

**Current obstacle:** the entire structure child has `show_behind_parent = true`. Units are sorted by ground depth within the parent, but buildings never interleave with them. A tall factory will therefore appear behind a unit that should pass behind its roof. Enabling `y_sort_enabled` on this node cannot sort individual polygons emitted by one `_draw()` call. Godot describes CanvasItem ordering as “Canvas items are drawn in tree order on their canvas layer.” Its Y sorting applies to CanvasItem nodes. [CanvasItem reference](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html).

For the lab, retain cached terrain and ground footprints, then test one shared ordered draw list for raised buildings and units. Keep stable tie-breaking. A single building anchor may still fail for a long footprint; test all sides of a factory and split front/side faces only where that fixture proves necessary. This trades some whole-building draw-command caching for correct occlusion. Cache reusable local geometry and measure the cost before extending it across the roster. Merely moving the whole structure layer in front reverses the defect.

Define three distinct concepts in the implementation: authoritative ground footprint, rendered bounds including height, and intentional selection/hit bounds. Current `_vehicle_bounds()` also feeds picking and overlays; replacing its rectangle with decorative extents can silently change input. Preserve reverse draw-order selection, building ground-footprint picking, box-selection anchors, owner filtering and hidden-passenger filtering. Keep health bars and focus marks clear of roofs without enlarging collision radii. [Drawing and picking][view]; [existing view tests][view-tests].

Keep generator rotors, factory doors and muzzle attachments attached to the same projected body and depth. `_refresh_structures()` keys building health, completion/work and selection, among other fields; it does not automatically respond to arbitrary animation time or production-queue activity. Derive active state from available gameplay fields and invalidate only the affected presentation. Do not invent a working state merely to animate a reference feature.

## 3. Collect effects at every simulation step

**Current obstacle:** `_draw_cues()` reads the latest snapshot's `combat_events`. Simulation clears its live event array each step. Online catch-up may run two steps before the view refreshes, so effects from the earlier step can disappear. Existing building-shot retention prevents repeated display on a stalled tick; it does not recover omitted ticks. [Simulation][simulation], [view][view], [online driver][online].

Reuse the timing pattern already established for audio: `_collect_sound()` runs after every successful simulation step, and `SoundDirector.collect_step()` copies events, rejects repeated ticks and bounds its pending history. Add an independent visual consumer at that same boundary, including every supported scene driver. Do not drain audio's queue or introduce a general event bus. Copy only needed event data; avoid another full simulation snapshot per step just for effects. [Skirmish driver][skirmish], [sound director][sound].

There is a concrete data limit: shot events contain IDs, tick, damage and splash flags; death events contain an ID and tick. They carry no impact coordinates or independent turret angle. Last-known/current visual records can position effects for known objects, but cannot reconstruct an object born and removed between observed snapshots. Explicitly skip an unknown position in the first slice. If exact placement becomes required, separately design a lightweight event-position capture at the event origin; do not silently read private simulation dictionaries or claim the latest snapshot is lossless. [Combat event construction][combat].

Use hull `heading` for locomotion, and available target positions for cosmetic turret aim, falling back to heading. Replace the fixed building `MUZZLE_LIFT` with role-specific attachment points. Combat resolves damage in simulation; a drawn tracer must not postpone damage or add projectile behavior. Coalesce multiple damage/splash records into a sensible muzzle cue so one attack does not produce a flash per victim.

Bound active effects and pending events; define which low-priority cosmetic cues may be dropped under overload. Consume each captured tick once, reset history on restart, and test disappearance before rendering. Offline pause is currently a driver guard, not a guarantee that all `_process()` callbacks stop. New animation clocks must respect it. Online menus do not pause the match; stalled network ticks must not replay shots or advance units beyond confirmed positions.

## 4. Fit the roster and real viewport

The [project configuration][project] sets 1280 × 720, Compatibility rendering and 30 physics ticks/s. The [camera driver][main] exposes zoom values `0.5`, `1.0`, `2.0`; `change_zoom()` currently changes camera scale only. If geometry detail becomes cached by zoom, notify the presentation and invalidate affected geometry explicitly. Account for viewport scaling as well as camera zoom.

Current tank rectangles are 30 local pixels wide, or 15 pixels at `0.5` zoom before window scaling. The reference sheets' far-view samples are larger illustrations, not proof that recognition survives that footprint. Begin with the real viewport: keep hull/turret/role cues, remove small seams, preserve top-color area and avoid outlining every edge. Decide detail thresholds from measured projected size; do not copy the sheet's illustrative sizes into constants. Eight static headings also do not validate rotation between them.

Map each existing `kind` to a small explicit presentation role/style entry; reuse registry capabilities rather than inferring role from weapon damage type as the current width heuristic does. Faction shape follows kind, while ownership tint follows owner. This preserves faction recognition independently of player color. [Registry][registry], [USA definitions][usa], [FRC definitions][frc].

The roster is not symmetrical: `usa_collector` is a Supply Helicopter; `frc_builder` is an infantry Laborer who also collects; FRC has no power-plant kind. Shared functional language must preserve these differences. A three-faction tank comparison is valid; three identical faction bulldozers or power plants are not an implementation requirement. Additional generic reference roles are visual vocabulary, not approval to add units. Likewise, the proposed palette differs from the existing owner colors and remains an explicit art decision.

## 5. Honor the existing avoidance research

The [avoidance evidence note][avoidance-note] already compares A, Zero Hour-style yielding, and B, OpenRA-style cell reservation. It explicitly records **evidence only, no design decision**, with prototypes not intended for direct merge. The branch's committed mode is empty, retaining existing movement. The [hook and wrapper][avoidance-code] sit inside simulation movement, not presentation.

Reported native p95 deltas against baseline, in milliseconds:

| Research workload | A: yielding | B: reservation |
|---|---:|---:|
| 300-unit open movement | +0.870 | +0.303 |
| 300-unit dense movement | +1.195 | −0.108 |
| `hordes300`, wrapper cost | +0.386 | +0.639 |

These are the existing report's measurements, not new runs. Neither prototype cleanly meets its +0.5 ms cap across these rows. B's movement results are confounded by units giving up; neither solves the packed-arrival scenario. The report proposes further work on A's rules, but its hybrid suggestion is explicitly untested. Art work must not choose an avoidance algorithm or present this as a solved dependency.

Consequences for the renderer:

- Animate travel from confirmed displacement and heading, not merely a nonempty order or route. A blocked unit may retain its order while its position stops. In A, the wrapper can restore position after `_advance()`; do not assume heading alone proves translation. Wheels, tracks and dust should stop when the unit does.
- Keep pose smoothing separate from position authority. If position interpolation is introduced, test stop/start, sidestep and heading changes against recorded movement; never extrapolate through a blocker or conceal a long wait by continuing the model forward. Preserve ground anchors for picking and overlays.
- Do not implement cosmetic separation that pushes overlapping units apart. It would hide the actual avoidance result and move visuals away from selectable positions. Use group/role colors in diagnostic captures, as the research already suggests.
- Do not imply completed speed matching, column group movement, multi-cell vehicle occupancy or crushing kills through animation. The report lists these as unprototyped or incomplete. Keep body width proportional to existing gameplay scale; art approval does not alter radii, reservations or arrival policy.
- Do not depend on `sim._avoid` from the renderer. It is prototype internal state, outside snapshot/hash coverage. Production avoidance needs its own state/serialization decision; cosmetic timers belong outside that state. Sidestep poses can initially use confirmed movement alone.

For later art validation, reuse dock traffic, factory exits, head-on groups and packed arrivals as stress cases. Keep the report's warning that `dw_choke` is a 20-cell-wide crossing, not a verified narrow bottleneck. A genuine narrow-passage fixture needs separate verification. Neither new avoidance measurements nor changes to its research files are part of this package.

## 6. Small implementation sequence and evidence

After game implementation is authorized, use GPT's proposed lab scope (`~/projects/wargrid-art-archive/IMPLEMENTATION_HANDOFF.md`; M7.5 scope questions in [next-m75-art-scope.md](../questions/next-m75-art-scope.md)) in three steps:

1. **Static bodies and input.** One tank, bulldozer, infantry role, plant and factory using existing kinds; compare faction tanks in one hue. Verify actual zooms, all headings, ground anchors, selection and building/unit overlap. Preserve current presentation for baseline captures.
2. **Local motion and effects.** Add only the required recoil, turret aim and active machinery. Collect events per step; cover catch-up, repeated tick, pause, restart, dead targets and missing positions. Compare stationary, blocked and sidestepping movement without changing simulation behavior.
3. **Scale and platform checks.** Run the repository's required tests and comparable rendered workloads, then a combat fixture exercising selection, damaged units, machinery and effects. Record baseline and revised frame/tick costs before widening the roster.

Existing tests provide concrete anchors: [view tests][view-tests] cover depth, picking, headings, passengers and caches; [scene tests][scene-tests] cover camera and transformed input; [sound tests][sound-tests] demonstrate per-step capture, event copies, stalled ticks and restart behavior. Add focused tests for new ordering and event lifecycle logic. If structures cease to be entirely behind units, replace that specific old layer assertion with verified occlusion behavior; retain the cache checks instead of deleting them wholesale.

Keep deterministic traces and snapshot-size limits unchanged. The [performance ledger][performance] distinguishes the 60 fps / 16.7 ms target, the factor-derived 3.04 ms development-machine frame budget, and the separate 3.3 ms Ashfall regression guard in the [rendered benchmark][benchmark]. Passing the guard does not establish the tighter budget or all platforms. The ledger already records limited presentation headroom and exceeded rows; do not treat those as new failures caused by these unimplemented recommendations. Do not add the avoidance delta to rendering numbers as if they measured the same workload.

No new performance result is claimed here. This inspection did not run Godot, replay/network tests, the avoidance harness or target hardware. Installed engine version and real-time behavior remain unverified. Fog-of-war guidance in the art bible is a future acceptance condition: the inspected view does not yet provide the proposed fog system.

[main]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/scripts/main.gd
[online]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/scripts/online_main.gd
[skirmish]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/scripts/skirmish_main.gd
[view]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/scripts/presentation/world_view.gd
[scene]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/scenes/skirmish.tscn
[simulation]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/scripts/simulation/simulation.gd
[combat]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/scripts/simulation/combat.gd
[sound]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/scripts/presentation/sound_director.gd
[project]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/project.godot
[registry]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/scripts/simulation/definitions/definitions.gd
[usa]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/scripts/simulation/definitions/usa.gd
[frc]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/scripts/simulation/definitions/frc.gd
[avoidance-note]: https://github.com/pdstuber/wargrid/blob/a9a0e3cd1825bbf05837d3898378d75657d6d345/docs/reference/unit-avoidance-spike.md
[avoidance-code]: https://github.com/pdstuber/wargrid/blob/a9a0e3cd1825bbf05837d3898378d75657d6d345/game/scripts/simulation/avoidance.gd
[view-tests]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/tests/test_view.gd
[scene-tests]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/tests/test_scene.gd
[sound-tests]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/tests/test_sound.gd
[performance]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/docs/reference/performance.md
[benchmark]: https://github.com/pdstuber/wargrid/blob/07c3ab65f373212816c1f34e6361e5a9b08cff28/game/scripts/debug/movement_benchmark.gd

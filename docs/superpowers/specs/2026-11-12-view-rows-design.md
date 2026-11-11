# View rows: design (2026-11-12)

Status: **proposed, waits for stop gate 2 (user approval). Not started.** Task T4 of the [performance next plan](../plans/2026-11-11-performance-next.md). Written against `perf-next` at bed2e7b (T1 clock and T3 rows in the tree, two RF tests being added uncommitted). Read-only design; no Godot process was run. Numbers come from the T3 rows in `docs/reference/performance-next-verification.md` (measured, probe copy of 577ca06). Lever C of the [performance note](../../reference/performance-next.md) (section 6), hot spots H3-H6 (section 3).

Rules: no simulation behaviour or trace change, typed GDScript, no generic framework, [determinism rules](../../reference/determinism-rules.md). Pass (plan): the game scenes no longer call `snapshot()` once per tick; the plumbing row improves by more than its spread on every layout; suite, pins and netplay unchanged.

## Decisions

1. **The simulation owns the rows, and builds them fresh on every call.** New `Simulation.view_state(detail_ids)` returns the small records the presentation reads plus `units`, a `ViewRows` object with packed columns. Only the simulation reads `_entities`; T5's worker will publish exactly this object per tick. Fresh packed arrays per call (about 16 allocations per tick, none per unit) need no double buffer and cannot be changed under a holder. Rejected: rows kept up to date by each system as they write (that is lever D1, touches every system, needs the golden scenarios first).
2. **Dense columns, one row per unit, id order.** Not per-kind arrays: drawing, picking and HUD all address "unit i", the depth sort covers every unit at once, and per-kind arrays would need a merge for both. Kind is an index into a per-call `kinds` table.
3. **The view keeps one item Dictionary per unit across ticks and rewrites its fields from the rows.** `WorldBatch.build`, the visual director and the pose code keep reading item Dictionaries, unchanged, so the golden batch test (WB18) stays green with its digest untouched and exercises the new path. A new Dictionary is made only when a unit appears. Rejected for now: `build()` reading rows directly. It saves the remaining in-place writes (estimate 0.06-0.26 ms, see Gain) but rewrites the golden path; it belongs with D1/T6.
4. **One `set_state` shape for tests, one for the game.** `WorldView.set_view(view, selected)` is the game path. `set_state(snapshot, selected)` stays and converts with `ViewRows.from_units(state.entities)`, so the 89 `set_state` calls in `test_view.gd`, the art lab and anything snapshot-shaped run through the same row code. `from_units` is also what the simulation calls on its live units: one fill function, no second reader.
5. **Every scene refresh reads `view_state()`, per tick and on input.** `_refresh()` never takes a snapshot. Input handlers that need full unit fields (`_matching_ids`, `_builder`, `_context_order`, `_container`, `_enemy_at`, `_unload_selected`, `_submit`'s `last_sequences`) keep their own `snapshot()` call, as today.
6. **HUD detail through `details`, not more columns.** The HUD needs the full unit record (combat mode, collection phase and `enabled`) for at most two units: the single selected unit and the inspected enemy. The scene passes those ids as `detail_ids`; `details` holds snapshot-shaped copies (`_entity_copy`). Rejected: a `simulation.unit(id)` query, because under T5 the HUD must not read the live simulation.
7. **No veterancy column.** The simulation has no veterancy field (`rg veterancy game/scripts/simulation` finds only a comment in `salvage.gd:41`). The per-frame chevron loop in `_draw_lines` (`world_view.gd:421-424`) never draws and is removed; `veterancy_lines(unit)` and its test V24 stay as the art placeholder. When the simulation gains veterancy, that change adds a `veterancy` byte column.

## 1. Row columns and owners

`game/scripts/simulation/view_rows.gd`, `extends RefCounted`, built by `Simulation.view_state()` (owner) and by `ViewRows.from_units()` (tests, labs). Typed members, all of length `size()`, row `i` is one unit, rows sorted by id. Defaults are those `WorldBatch.objects` / `_item` use today (`world_batch.gd:91-119`), so hand-built test units without a field keep working.

| Column | Type | Source field (unit Dictionary) | Default | Readers |
|---|---|---|---|---|
| `id` | `PackedInt32Array` | `id` | | everyone; `index_of(id)` is `id.bsearch` |
| `owner` | `PackedInt32Array` | `owner` | 0 | batch, picking, HUD, sound |
| `kind` | `PackedInt32Array` | index of `kind` in `kinds` (`PackedStringArray`, built per call) | `""` | batch role/layer, bounds, picking, HUD, sound |
| `hp`, `max_hp` | `PackedInt32Array` | `hp`, `max_hp` | 0 | batch, health bars |
| `target` | `PackedInt32Array` | `combat.target_id` | -1 | batch, visual director aim, focus boxes |
| `queue` | `PackedInt32Array` | `collection.target_id` while `collection.phase` begins with `waiting_` | -1 | HUD line position (`line_position`) |
| `x`, `y` | `PackedFloat64Array` | `position` | | everyone |
| `heading_x`, `heading_y` | `PackedFloat64Array` | `heading` | `[1.0, 0.0]` | batch (`atan2` stays in presentation: no trig in the simulation folder) |
| `order_x`, `order_y` | `PackedFloat64Array` | `order.target` | 0.0 | order marks |
| `status` | `PackedByteArray` | index of `status` in `STATUSES = ["moving", "path_pending", "arrived", "blocked", "idle", "contained"]` | 255 for any other value | `main.gd` HUD counts |
| `tier` | `PackedByteArray` | `combat.tier` | 0 | sound (weapon cue) |
| `flags` | `PackedByteArray` | bit constants below | 0 | as named |

Flags: `HORDE` (`combat.horde > 0`, batch ring), `CONTAINED` (has `container_id`, picking), `HOLE` (has `hole_id`, picking), `ATTACKING` (`combat.mode == "attack"`, focus box width), `ORDERED` (`order != null`, order marks), `WAITING_SOURCE` (`collection.phase == "waiting_source"`, pile labels via `_waiting_counts`).

The two collection fields T3 found missing are covered by `WAITING_SOURCE` plus `queue`; the full phase string for the HUD comes from `details`. Veterancy: decision 7. Rows carry no `route`, `destination`, `speed`, `passengers` or `combat` record; nothing per tick reads them outside the HUD detail.

`view_state(detail_ids: Array[int] = []) -> Dictionary` keys: `tick`, `map` (shared read-only, as in the snapshot), `players` (`_player_snapshots(true)`), `buildings`, `sources` (`_sorted_copies`), `match`, `command_results`, `crates` when any exist, all with the snapshot's values; `units`; `details`. Not included: `entities`, `pending_commands`, `last_sequences`, `path_queue`, `terrain_cells`, `next_*`, `rng`, `combat_events` (the directors get events through `collect_step`). Profiler zones: `view_state` around the whole call, `view_rows` around `from_units`, so the record copies show as the difference.

It is not a state fingerprint and holds an `Object`, which the snapshot rules forbid (determinism rules, "Snapshot values"); it never goes into `StateHash.digest` or a desync report.

## 2. Consumers

### `world_view.gd`

`_state` becomes the view state (from `set_view`, or converted in `set_state`). The shallow `state.duplicate()` (`view.copy`) goes: nothing reorders the caller's data any more. New members: `_order: PackedInt32Array` (row indices in today's depth order, built per tick by `WorldBatch.depth_order(units)` with the same key as `depth_sorted`, `world_batch.gd:132-144`, which it replaces), `_unit_items: Array[Dictionary]` (id order). Every loop that today walks `_state.entities` walks `_order` instead, so draw order, pick priority and Dictionary insertion order of the results stay as they are. `_drawn_position(unit)` becomes a lookup by row (`_drawn.get(id, Vector2(x[i], y[i]))`); `_vehicle_bounds`, `_pick_bounds`, `_ground_diamond` take kind and point instead of a unit Dictionary.

| Function (line today) | Rate | Reads after T4 |
|---|---|---|
| `set_state` / new `set_view` (179) | tick | rows: `_order`, unit items (merge walk below), structure items |
| `_remember_points` -> `_points_of` (569, 578) | tick | rows by `index_of` for wanted ids; buildings unchanged |
| `_refresh_structures` -> `_waiting_counts` (455, 544) | tick | `WAITING_SOURCE` and `queue` |
| `_draw_rects` health bars (404) | frame | `hp`, `max_hp`, kind, drawn point |
| `selected_unit_lines` (137), `order_marks` (340) | frame | rows; `ORDERED`, `order_x/y`, `owner` |
| `_draw_lines` chevrons (421) | frame | removed (decision 7) |
| `focus_targets`, `_draw_focus` (475, 484) | frame | `target`, `ATTACKING`, bounds |
| `_draw_inspected` (500), `resume_candidate` (309) | frame, and per HUD refresh | rows (`owner`, kind) |
| `pick_target`, `pick_entity`, `pick_entities`, `pick_object` (362, 373, 593, 610) | input | rows in reverse `_order`; `CONTAINED`, `HOLE`, kind |
| `pile_lines` (538) | per label | `_waiting_counts` on rows |
| `horde_count` (351) | overlay | items, unchanged |

No `world_view.gd` consumer needs a snapshot. Unit items: `_items` = unit items followed by today's building and source items (still built fresh, they are few). Order inside `_items` does not matter: `build()` sorts by layer, depth and id; `_track_poses`, `_apply_alpha` and the visual director key by id.

Merge walk, once per `set_view` (ids only ascend, so one pass):

```gdscript
var next: Array[Dictionary] = []
var j: int = 0
for i in units.size():
	var id: int = units.id[i]
	while j < _unit_items.size() and _unit_items[j].id < id: j += 1
	var item: Dictionary = _unit_items[j] if j < _unit_items.size() and _unit_items[j].id == id else {}
	next.append(WorldBatch.write_unit_item(item, units, i))
_unit_items = next
```

`WorldBatch.write_unit_item(item, units, i) -> Dictionary` fills an empty item with all 16 keys of `_item`, and on every call writes `owner`, `anchor`, `heading` (`atan2(heading_y, heading_x)`), `target_id`, `hp`, `max_hp`, `horde`; `role`, `layer` and `shadow` are rewritten only when `item.kind` differs from the row's kind. `WorldBatch.objects(state)` becomes `write_unit_item` over `ViewRows.from_units(state.entities)` plus `structure_items(state)` (today's building and source part), so WB18 runs the new code. The order inside `set_view` stays today's: items, `_track_poses`, `_apply_alpha(_alpha)`, visuals update, `_rebuild_batch`. T3's sub-zones (`view.objects`, `view.poses`, `view.visuals`, `view.build`) become permanent inside `view.batch`; T6 needs them.

### Scenes

- **`main.gd` `_refresh` (223)**: `_show(simulation.view_state(_detail_ids()))`. `_detail_ids()` returns `[]` here.
- **`main.gd` `_show` (226), selection pruning (H6)**: keep the selected ids for which `state.units.index_of(id) != -1`; no per-tick id list, no linear search. Overlay count from `units.size()`.
- **`main.gd` `_refresh_hud` (248)**: status counts from the `status` column.
- **`base_main.gd` `_refresh` (67)**: same view state; building checks on `state.buildings` unchanged. `_menu_kinds` (91): the selected unit's kind through `index_of`. `_refresh_hud` reads `command_results`, `players`, `buildings`, `tick`: all in the view state.
- **`skirmish_main.gd`**: `_detail_ids()` returns the single selected unit and `inspected_id` when set. `_selected_summary` and `_enemy_summary` read `state.details` (same fields as today); `_inspected` looks in `buildings`, then `details`; `_collection_suffix` calls `View.line_position(state.units, unit)`, which counts rows with `queue == unit.collection.target_id` and a lower id, plus one. Same result as today's predicate (`world_view.gd:551-555`) for any waiting unit with a target.
- **`online_main.gd`**: `_refresh` inherited. `_lockstep.start(snapshot)` (once) and `finish_tick(tick, snapshot if wants_snapshot)` (hash ticks) unchanged.
- **Picking**: unchanged callers; the view's pick functions read rows.
- **Sound director** (`sound_director.gd:53-99`): `update(state)` takes the view state. `_records` builds records for buildings only; unit lookups (`_lookup` for shot attacker and target, death, `_last_shot` cleanup, `_unit_ready`) use `index_of` on the current rows, then on the previous tick's rows, and build a small record only for an id an event names. No per-unit Dictionary per tick (today it makes one per unit per tick).
- **Visual director**: no change. It reads the unit items, which now persist; its `_anchors` stores `Vector2` values, not item references.

### What stays on `snapshot()`

Hash ticks and desync reports (`online_main.gd:28, 57`, `net/headless_client.gd:129, 159, 243, 247`, `net/seat_sim.gd:13`, `Lockstep._hash_snapshot`), replays, traces and every test that hashes or compares state, the bots inside the simulation step (`Skirmish.issue_opponent`, every 30 ticks), input handlers (`main.gd:61` once, `:201`, `:273`; `base_main.gd:41, 147, 216, 233, 264, 274, 281`; `skirmish_main.gd:136, 173`), workload setup (`movement_workload.gd:44`, `combat_workload.gd:36`, `movement_benchmark.gd:129`) and the labs (`lab_fight.gd:86, 91`, `art_lab.gd:49`, through `set_state`). Removed per-tick calls: `main.gd:224`, `base_main.gd:68`, `movement_benchmark.gd:164` (becomes `tick()`), `:168`, `:353`, `:424`, and `run_profile.gd` `_frame`. BM5 (snapshot node ceiling) is untouched because the snapshot is.

## 3. The split clock

No change to `presentation_clock.gd`. The clock decides when `_refresh()` runs; `_refresh()` now builds the view state instead of a snapshot, at the same moment. When the split is active, the refresh frame gets lighter by the gain below; the step frame is unchanged. Two steps in one frame still show the newer tick, as today. RF3 and RF5 read `_view._state.tick`, which the view state carries, so they stay as written. For T5: the view state is the hand-off unit. The remaining main-thread reads of the live simulation after T4 are `tick()` (clock), `combat_events()` / `command_results()` in `_collect_sound`, `team_of`, `match_over`, `preview_build` and the input-event snapshots; T5 owns them.

## 4. Test plan

Every new test uses only the simulation interface (after section 6's update) and public view functions. `tools/test_sim_boundary.py` enforces it.

- **VR1, characterization, written first on the unchanged tree.** New `game/tests/test_view_rows.gd`. Two real states: `Skirmish.create()` with bots stepped to tick 3000, and `CombatWorkload.create("hordes300")` at tick 400. For each, a fixed selection (the first 5 own units, one collector, one builder), fed through `set_state(sim.snapshot(), selection)`. Hash into one SHA-256: `WorldBatch.objects(snapshot)` built at detail 1 with shadows (points and colours), `selected_unit_lines()`, `focus_targets()` (keys and values in order), `order_marks()` with destinations on, `pick_entities` over the whole map, `pick_entity` and `pick_target` at five unit anchors, `pile_lines` per source, `resume_candidate()`, `horde_count()`. Record the digest as a constant on HEAD (run twice, same value). From task 2 on, the same constant must hold, fed through `set_view(sim.view_state([]), selection)` as well as `set_state`. A moved digest is a bug in the task, never re-recorded.
- **VR2, rows equal the snapshot on real data.** Six states: hordes300 at ticks 40, 400, 1500 (T3: targets only appear late), the skirmish at 3000, a team-match prefix at 2000 (`TeamMatch.create`), and a transports fixture from `test_benchmark.gd`'s `test_transports_fixture` setup. For every unit, a reader written in the test, not `from_units`, compares each column with the snapshot entity field by field (`==` on floats and ints), kind through `kinds`, every flag bit. Coverage checks fail on zero: at least one unit per state set with a target; across all states at least one each of `HORDE`, `CONTAINED`, `ATTACKING`, `ORDERED`, `WAITING_SOURCE`, a `queue` value and a non-zero `tier`. If a bit has no unit in these states, the task extends a state, it does not drop the check.
- **VR3, the other keys.** `view_state(ids)[k] == snapshot()[k]` for every key of section 1 except `units` and `details`; `details` equals the snapshot entities with those ids; an id that does not exist is left out.
- **VR4, read-only and independent.** `StateHash.digest(sim.snapshot())` is equal before and after a `view_state()` call; a held view state is unchanged after 30 steps (compare against a deep copy of its records and a copy of each column).
- **VR5, items persist.** Two `set_view` calls one tick apart: the same unit's item is `is_same` in both; a removed unit's item is gone; a spawned unit gets one; an item's `anchor` after the second call is the new position, not an interpolated leftover.
- **Golden batch, WB18** (`test_world_batch.gd:235`): unchanged, expected digest `412a2fbb...` untouched; it now goes through `from_units` and `write_unit_item`.
- **Per consumer that changes:** `test_view.gd` keeps every expected value; one case changes its access only (`test_view.gd:180` reads `_state.entities` for the depth order; it reads `_order` and `units.id` instead, same expected ids). Depth-sort tests of `depth_sorted` move to `depth_order` with the same expected order. Scene HUD: K4, S1 (line position) and E1 (inspection) keep their texts; K4's `main._refresh_hud(setup)` passes `view_state()` with the edited `match` instead of a snapshot. Selection pruning: add RF7 ("a dead selected unit leaves the selection, the others keep their order") if `rg` finds no existing case. Main scene counts: add one case for the `Moving / Pending / Arrived / Blocked` text if none exists. Sound: `test_sound.gd` and `test_announcer.gd` `_state` helpers add `units = ViewRows.from_units(entities)`; direct `sim.snapshot()` feeds become `sim.view_state()`; no expected value changes. `test_visual.gd`: unchanged. BM17 (`horde_camera`) builds rows with `from_units`.
- **Intended changes of expected values (list them in the verification row):** RF1 and RF2 (`test_base_scene.gd:253`, `test_skirmish_scene.gd:596`) assert `Profiler.calls(&"snapshot") == 1` per refresh; they become `== 0` with `Profiler.calls(&"view_state") == 1`, RF2's Produce label unchanged. New RF6: the base scene with processing off, 10 `_physics_process` calls: 0 `snapshot` calls, 10 `view_state` calls. This is the plan's pass condition as a test.
- **Gates per task** (plan Conventions): suite, lint, warnings; `run_benchmark.sh` for tasks touching `game/scripts/`; after task 6 the netplay `match` scenario. Pins, traces, digests, BM5 ceilings unchanged.

Reviewer, per test, names the change that makes it fail: VR1 a wrong depth key or a dropped pick filter; VR2 a column filled from the wrong field; VR4 a `view_state` that writes into a live unit; VR5 a merge walk that rebuilds items; RF6 a scene `_refresh` that snapshots.

## 5. Expected gain (per tick, ms, mean, headless `run_profile`)

"Hand-off" is T3's sum: `snapshot` + `view.copy` + `view.sort` + `view.batch` today; `view_state` + `view.sort` + `view.batch` after. The bound is T3's (measured parts, **a bound, not a design measurement**: it counts `view.objects` as zero and ignores the record copies). The estimate adds what this design keeps: in-place item writes and `atan2` (assumed 30-50 % of today's `view.objects`), five more columns than the probe (about +40 % of `view_rows`), and the building, source and player copies (not measured alone; T4 task 2's zones measure them).

| Row | Hand-off today (T3) | Lower bound from rows (T3) | Estimate after T4 | A/A spread (T3) | Plumbing budget 0.91 |
|---|---|---|---|---|---|
| skirmish3v3 | 0.862 | **0.393 (bound)** | 0.50-0.56 (estimate) | <= 0.01 | would pass |
| team_match | 1.415 | **0.629 (bound)** | 0.82-0.93 (estimate) | <= 0.01 | at the budget |
| hordes300 | 2.955 | **1.539 (bound)** | 1.80-1.90 (estimate) | <= 0.01 | exceeded |
| movement_open | 2.099 | **1.027 (bound)** | 1.23-1.31 (estimate) | <= 0.01 | exceeded |

Even the top of each estimate is 34-38 % under today, many times the spread. The rendered benchmark (`--zoom=0.5`, report-only) also loses the snapshot from `tick_ms`; per-frame draw loops read packed columns instead of Dictionaries, so `draw.units` may drop too (not estimated).

## 6. Simulation interface note

In `docs/reference/sim-interface.md`, update the status line to the implementing commit, append one sentence to the `snapshot()` bullet, and add two bullets under "State out" right after it:

> Since the view rows (2026-11-12) the game scenes call it only on input events and lockstep hash ticks; per-tick presentation reads `view_state()`.

> - `view_state(detail_ids: Array[int] = []) -> Dictionary`: what drawing, the HUD and sound read once per tick, without a full snapshot. `simulation.gd:<line>`. Keys `tick`, `map`, `players`, `buildings`, `sources`, `match`, `command_results`, and `crates` when any exist, with the same values as in `snapshot()`; `units`, a `ViewRows` (`view_rows.gd`) with one row per unit in id order; `details`, copies of the units in `detail_ids` that exist, shaped like `snapshot().entities[]`, in id order. Built fresh on every call, so a held one keeps its values; it changes nothing in the simulation. Not a state fingerprint: never hash it or put it in a desync report.
> - `ViewRows` (`view_rows.gd:<line>`): equal-length columns, row `i` is one unit. `PackedInt32Array`: `id`, `owner`, `kind` (index into `kinds`, a `PackedStringArray` built per call), `hp`, `max_hp`, `target` (`combat.target_id`, -1 for none), `queue` (`collection.target_id` while `collection.phase` begins with `waiting_`, else -1). `PackedFloat64Array`: `x`, `y` (`position`), `heading_x`, `heading_y` (`heading`, default `[1.0, 0.0]`), `order_x`, `order_y` (`order.target`, 0.0 without an order). `PackedByteArray`: `status` (index into `ViewRows.STATUSES`, 255 for another value), `tier` (`combat.tier`, 0 without combat), `flags` (`HORDE`: `combat.horde > 0`; `CONTAINED`: has `container_id`; `HOLE`: has `hole_id`; `ATTACKING`: `combat.mode == "attack"`; `ORDERED`: `order != null`; `WAITING_SOURCE`: `collection.phase == "waiting_source"`). `index_of(id) -> int` (binary search, -1 if absent). `ViewRows.from_units(units)` builds the same rows from snapshot entities in id order (tests, labs). A field the presentation needs per tick that is not a column becomes a new column in the same change, never a per-unit Dictionary again.

## 7. Risks

- **Stale reads.** A persistent item keeps any field that is not rewritten. Rule: `write_unit_item` writes every per-tick field on every call; kind-derived fields when the kind differs. VR5 and VR1 guard it. The HUD and the view read one view state per refresh; mixing it with live queries (`team_of`, `match_over`) sees the same tick as today, because no step runs between them.
- **Ordering.** Rows are in id order, today's entity list in the view was in depth order. Every loop that depended on that order walks `_order`; `_items` order is irrelevant to `build()` (total sort key) and to the id-keyed pose and visual code. VR1 hashes pick results and `focus_targets` key order.
- **Per-tick allocation.** Allowed per tick: the `ViewRows` object and its columns, one `kinds` table, the record copies the snapshot made anyway, one `_items` and one `_unit_items` Array, the existing pose and anchor Dictionaries. Not allowed: any Dictionary per unit per tick (the review checks `write_unit_item`, the sound director and `from_units`). Today there are three per unit (entity copy, its nested copies, the item) plus one in the sound director.
- **Route freezing.** `_entity_copy` makes a live unit's `route` read-only (`simulation.gd:596`); today every route is frozen every tick by the scene's snapshot, after T4 only on hash ticks, input events and for `details`. That would change behaviour only if simulation code edited a shared route in place; the only in-place edits are on the route being built (`simulation.gd:576-577`), and headless netplay clients (no per-tick snapshot) already agree with game clients. Guard: traces, pins, the netplay `match` scenario.
- **Int32 columns.** `id`, `hp`, `max_hp` and targets fit today (T3 compared them equal); VR2 catches an overflow.
- **Two entry points into the view.** `set_state` converts and `set_view` does not; both end in the same code, and VR1 runs both.

## 8. Tasks (Sonnet, one fresh subagent each, test-first)

Every task: Conventions' checks before `GREEN` (suite, lint, warnings; `run_benchmark.sh` when `game/scripts/` changed), VR1 and WB18 unchanged from task 1 on, changed paths listed. Do not touch the RF5 and auto-pick cases another agent adds.

1. **VR1 characterization.** New `game/tests/test_view_rows.gd` (registered like the other suites in `game/tests/run_tests.gd`) with VR1 only, on the unchanged code. Record the digest. Pass: green twice with the same digest; a deliberate swap of two pick filters in a scratch edit turns it red (then restore).
2. **ViewRows and `view_state`.** Red VR2, VR3, VR4 first. New `game/scripts/simulation/view_rows.gd`; `simulation.gd`: `view_state(detail_ids)` with zones `view_state` and `view_rows`. Section 6 wording into `docs/reference/sim-interface.md`. Pass: VR2-VR4 green with every coverage count above zero; `tools/test_sim_math.py` clean (`sh tools/run_python_checks.sh`); no trace or pin moved.
3. **WorldBatch from rows.** `world_batch.gd`: `write_unit_item`, `structure_items`, `depth_order`; `objects(state)` through `from_units`; `depth_sorted` replaced, its tests moved to `depth_order` with the same expected orders. Pass: WB18 digest unchanged, all `test_world_batch.gd` cases, VR1.
4. **WorldView on rows.** Red VR5 first. `world_view.gd`: `set_view`, `set_state` converting, `_order`, `_unit_items` merge walk, every consumer in the section 2 table on rows, `view.copy` and the chevron loop removed, T3 sub-zones permanent. `test_view.gd:180` access change only. Pass: all `test_view.gd` and `test_graphics_settings.gd` expected values unchanged, VR1 green through both `set_state` and `set_view`, VR5 green.
5. **Scenes and sound on the view state.** Red RF6 and the RF1/RF2 rewrite first. `main.gd` (`_refresh`, `_show`, `_refresh_hud`, `_detail_ids`), `base_main.gd` (`_refresh`, `_menu_kinds`), `skirmish_main.gd` (`_detail_ids`, `_selected_summary`, `_enemy_summary`, `_inspected`, `_collection_suffix`), `world_view.gd` `line_position(units, unit)`, `sound_director.gd` (`update`, `_records`, `_lookup`, `_unit_ready`, `_last_shot` cleanup), test helpers in `test_sound.gd` and `test_announcer.gd`, K4's `_refresh_hud` feed; RF7 and the main-scene count case if missing. Pass: RF1, RF2, RF6 green with the new values; S1, E1, K4, all sound and announcer expected values unchanged; netplay `match` scenario passes.
6. **Harness and rendered benchmark.** `game/benchmarks/run_profile.gd` `_frame`: one `view_state([])` and `set_view` per tick (the "twice" for base scenes is gone, the scenes now make one call); `game/scripts/debug/movement_benchmark.gd` per-tick sites (`:164` to `tick()`, `:168`, `:353` including `horde_camera` on rows and the horde sound state, `:424`); BM17 on rows. Pass: `test_benchmark.gd` green, `run_benchmark.sh` PASS lines as before, `run_profile.sh` prints the `view_state` and `view_rows` zones.
7. **Measure (coordinator, the plan's T4 "Measure").** `git archive` copies of the tree before task 2 and of HEAD; `run_profile.sh` A B A B A B on a quiet host; hand-off per row as in section 5 for every profiled layout, with median and spread; `run_benchmark.sh` before and after; then the rendered benchmark only after the user agrees to the window batch. Ledger row for the plumbing budget per layout. Pass: the plan's T4 pass condition.

Not checked: the record copy cost inside `view_state` (task 2 measures it), the cost of in-place item writes (estimate only), `draw.units` after the change, web behaviour.

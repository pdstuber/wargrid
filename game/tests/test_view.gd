@warning_ignore_start("untyped_declaration")
extends RefCounted

const View = preload("res://scripts/presentation/world_view.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Shapes = preload("res://scripts/presentation/shapes.gd")
const Bake = preload("res://scripts/presentation/shape_bake.gd")
const Director = preload("res://scripts/presentation/visual_director.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatFixture = preload("res://tests/combat_fixture.gd")
const MovementWorkload = preload("res://scripts/debug/movement_workload.gd")

func cases() -> Array[Callable]:
	return [test_pick, test_pile_label_drawn_over_buildings, test_box_and_order,test_economy_picking,test_build_preview,test_click_hint_lifetime,test_resume_hint,test_depth_order_matches_comparator,test_battery_shot_line,test_battery_target_line,test_building_label_has_no_kind_id,test_horde_count,test_rebuild_laborer_unselectable, test_crate_marks_frc_only, test_passengers_not_pickable, test_terrain_redraws_only_when_map_changes, test_structures_redraw_only_when_they_change, test_small_pile_view, test_structures_redraw_when_a_pile_vanishes, test_pick_under_roof, test_structure_bodies_in_shared_list, test_building_health_bar_in_overlay_pass, test_health_bar_rule, test_health_color_ends, test_selection_is_ground_diamond, test_biome_change_redraws_terrain, test_grid_only_while_placing, test_chevron_placeholder, test_cues_draw_on_low_in_the_view, test_effects_age_per_tick_not_per_refresh, test_bodies_submitted_each_frame, test_quality_change_rebuilds, test_draw_timing_only_on_request, test_air_pick_box_follows_lift, test_pick_covers_drawn_body, test_death_point_falls_back_to_previous_tick, test_selected_battery_line_without_a_shot, test_kind_info_follows_air_kinds, test_custom_ground_colors_rearm_the_biome]

func test_pick(runner) -> bool:
	var view = View.new()
	runner.check(view.pick_entity(Vector2.ZERO) == -1, "V1 empty")
	var sim = Simulation.new()
	sim.spawn(1, Vector2(2.5, 2.5))
	sim.spawn(2, Vector2(4.5, 4.5))
	var state: Dictionary = sim.snapshot()
	view.set_state(state, [1])
	var anchor := Iso.world_to_plane(Vector2(2.5, 2.5))
	var box: Rect2 = WorldBatch.pick_extent(state.entities[0].kind)
	runner.check(view.pick_entity(anchor + Vector2(0, -8)) == 1, "V1 interior")
	runner.check(view.pick_entity(anchor + box.position + Vector2(0.5, 0.5)) == 1, "V1 top left bound")
	for offset in [Vector2(-1, box.size.y / 2.0), Vector2(box.size.x + 1, box.size.y / 2.0), Vector2(box.size.x / 2.0, -1), Vector2(box.size.x / 2.0, box.size.y + 1)]:
		runner.check(view.pick_entity(anchor + box.position + offset) == -1, "V1 outside " + str(offset))
	runner.check(view.pick_entity(Iso.world_to_plane(Vector2(4.5, 4.5)) + Vector2(0, -8)) == -1, "V1 enemy ignored")
	state.entities.clear()
	runner.check(view.pick_entity(anchor + Vector2(0, -8)) == 1, "V1 set_state keeps its own entity list")
	view.free()
	return true

func test_box_and_order(runner) -> bool:
	var view = View.new()
	var sim = Simulation.new()
	sim.spawn(1, Vector2(2.5, 2.5))
	sim.spawn(1, Vector2(2.5, 3.5))
	sim.spawn(2, Vector2(3.5, 2.5))
	var state: Dictionary = sim.snapshot()
	var selected: Array[int] = [1]
	view.set_state(state, selected)
	selected.clear()
	runner.check(view._selected_ids == [1], "V2 selection array copied")
	var a := Iso.world_to_plane(Vector2(2.5, 2.5))
	var b := Iso.world_to_plane(Vector2(2.5, 3.5))
	runner.check(view.pick_entities(Rect2(a, b - a)) == [1, 2], "V2 normalized inclusive anchor rectangle")
	runner.check(view.pick_entities(Rect2(b, a - b)) == [1, 2], "V2 reversed rectangle")
	runner.check(view.pick_entities(Rect2(Vector2(-100, 0), Vector2(200, 200))) == [1, 2], "V2 enemy excluded, IDs sorted")
	state.entities[1].position = [2.5, 2.5]
	view.set_state(state, [])
	runner.check(view.pick_entity(a + Vector2(0, -8)) == 2, "V2 overlap tie picks last drawn ID")
	state.entities[0].position = [2.7, 2.7]
	state.entities[1].position = [2.6, 2.6]
	state.entities.reverse()
	view.set_state(state, [])
	runner.check(view.pick_entity(Vector2(0, 74)) == 1, "V2 ground depth precedes ID/input order")
	view.free()
	return true

func test_economy_picking(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(24,4),8)
	var building: int = Fixture.build(runner,sim,"usa_power_plant",Vector2i(8,4))
	var view = View.new()
	view.set_state(sim.snapshot(),[building])
	runner.check(view.pick_object(Iso.world_to_plane(Vector2(8,4))) == building,"V3 footprint inclusive origin")
	runner.check(view.pick_object(Iso.world_to_plane(Vector2(10,6))) == building,"V3 footprint inclusive far edge")
	runner.check(view.pick_object(Iso.world_to_plane(Vector2(25.5,5.5))) == source,"V3 neutral source")
	var air: int = sim.spawn(1,Vector2(25.5,5.5),"usa_collector")
	view.set_state(sim.snapshot(),[air])
	runner.check(view.pick_object(Iso.world_to_plane(Vector2(25.5,5.5)) + Vector2(0,-WorldBatch.AIR_LIFT - 8.0)) == air,"V3 air unit precedence over source")
	view.set_state({},[])
	runner.check(view.pick_object(Vector2.ZERO) == -1,"V3 empty safe")
	view.free()
	return true

func test_build_preview(runner) -> bool:
	var view = View.new()
	var cells: Array[Vector2i] = [Vector2i(8,4),Vector2i(9,4)]
	var sim = Fixture.make_world()
	var before: Dictionary = sim.snapshot()
	view.set_state(before,[])
	view.set_build_preview(cells,true)
	cells.clear()
	runner.check(view.get("_preview_cells") == [Vector2i(8,4),Vector2i(9,4)],"V4 preview copied")
	runner.check(sim.snapshot() == before,"V4 preview no simulation mutation")
	view.set_build_preview([],false)
	runner.check(view.get("_preview_cells") == [],"V4 preview clear")
	var main = preload("res://scripts/main.gd").new()
	var ids: Array[int] = [1]
	main.selected_ids = ids
	runner.check(main._view_selection() == [1],"V4 default selection hook")
	var selected: Array[int] = main._view_selection()
	selected.clear()
	runner.check(main.selected_ids == [1],"V4 hook selection copied")
	main.free()
	view.free()
	return true

func _tick_state(sim, ticks: int) -> Dictionary:
	for i in ticks: sim.step()
	return sim.snapshot()

func test_click_hint_lifetime(runner) -> bool:
	var view = View.new()
	var sim = Simulation.new()
	sim.spawn(1, Vector2(2.5, 2.5))
	var state: Dictionary = sim.snapshot()
	view.set_state(state, [])
	view.add_hint(Vector2(5, 5), state.tick)
	view.set_state(state, [])
	runner.check(view.hints().size() == 1, "H1 one click is one hint, stalled tick keeps exactly one")
	view.set_state(_tick_state(sim, 39), [])
	runner.check(view.hints().size() == 1, "H1 hint alive at +39")
	view.set_state(_tick_state(sim, 1), [])
	runner.check(view.hints().is_empty(), "H1 hint gone at +40")
	view.free()
	return true

func test_resume_hint(runner) -> bool:
	var view = View.new()
	var sim = Fixture.make_world()
	Fixture.send(sim, {"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4]})
	sim.step()
	Fixture.send(sim, {"type":"stop","entity_ids":[1]})
	sim.step()
	var state: Dictionary = sim.snapshot()
	var building: Dictionary = state.buildings[0]
	runner.check(building.builder_id == null, "H2 fixture: foundation has no builder")
	view.set_state(state, [1])
	view.set_hovered(building.id)
	runner.check(view.resume_candidate() == building.id, "H2 one builder selected over an unattended foundation")
	runner.check(View.building_label(building).ends_with(" paused"), "H2 label ends paused, got " + View.building_label(building))
	view.set_state(state, [])
	runner.check(view.resume_candidate() == -1, "H2 no builder selected")
	var second: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_builder")
	state = sim.snapshot()
	view.set_state(state, [1, second])
	runner.check(view.resume_candidate() == -1, "H2 two builders selected")
	state.buildings[0].builder_id = 1
	view.set_state(state, [1])
	runner.check(view.resume_candidate() == -1 and not View.building_label(state.buildings[0]).ends_with(" paused"), "H2 attached builder: no candidate, no paused")
	view.free()
	return true

func test_depth_order_matches_comparator(runner) -> bool:
	var sim = MovementWorkload.create("open")
	for i in range(40): sim.step()
	var state: Dictionary = sim.snapshot()
	var view = View.new()
	view.set_state(state, [])
	var expected: Array = state.entities.duplicate()
	expected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var depth_a: float = a.position[0] + a.position[1]
		var depth_b: float = b.position[0] + b.position[1]
		return a.id < b.id if depth_a == depth_b else depth_a < depth_b)
	var got: Array = view._state.entities.map(func(u): return u.id)
	runner.check(state.entities.size() == 300 and got == expected.map(func(u): return u.id), "VW2 depth order matches the comparator")
	view.free()
	return true

func _battery_world(with_tank: bool = true) -> Array:
	var sim = CombatFixture.world()
	sim.add_player(1, 10000)
	sim.add_player(2, 0)
	Fixture.add_completed(sim, 1, "usa_power_plant", Vector2i(1, 1))
	var battery: int = Fixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	var tank: int = sim.spawn(2, Vector2(16.5, 10.5), "usa_tank") if with_tank else -1
	return [sim, battery, tank]

func test_battery_shot_line(runner) -> bool:
	var view = View.new()
	var world: Array = _battery_world()
	var sim = world[0]
	sim.step()
	var state: Dictionary = sim.snapshot()
	view.set_state(state, [])
	var lines: Array = view.building_shot_lines()
	var centre: Vector2 = view._last_points[world[1]]
	runner.check(lines.size() == 1 and lines[0].from == centre + Vector2(0, -View.MUZZLE_LIFT), "V5 battery shot starts at the lifted muzzle")
	runner.check(lines.size() == 1 and lines[0].to == view._last_points[world[2]], "V5 battery shot ends at the target")
	view.set_state(state, [])
	runner.check(view.building_shot_lines().size() == 1, "V5 a stalled tick keeps one line")
	var shot_tick: int = lines[0].tick
	var alive := 0
	for i in 8:
		view.set_state(_tick_state(sim, 1), [])
		if view.building_shot_lines().any(func(l: Dictionary) -> bool: return l.tick == shot_tick): alive += 1
	runner.check(alive == View.SHOT_TICKS - 1, "V5 line lives SHOT_TICKS ticks, got " + str(alive + 1))
	view.free()
	return true

func test_battery_target_line(runner) -> bool:
	var view = View.new()
	var world: Array = _battery_world()
	var sim = world[0]
	sim.step()
	var state: Dictionary = sim.snapshot()
	view.set_state(state, [])
	runner.check(view.battery_target_lines().is_empty(), "V6 unselected battery draws no target line")
	view.set_state(state, [world[1]])
	var lines: Array = view.battery_target_lines()
	runner.check(lines.size() == 1 and lines[0].to == view._last_points[world[2]], "V6 selected battery draws a line to its target")
	var idle = _battery_world(false)
	idle[0].step()
	view.set_state(idle[0].snapshot(), [idle[1]])
	runner.check(view.battery_target_lines().is_empty(), "V6 selected battery without a target draws none")
	view.free()
	return true

func test_building_label_has_no_kind_id(runner) -> bool:
	var sim = Fixture.make_world()
	Fixture.send(sim, {"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4]})
	sim.step()
	var building: Dictionary = sim.snapshot().buildings[0]
	var label: String = View.building_label(building)
	runner.check(not label.contains("usa_") and not label.contains("P1") and label.ends_with("%"), "I4 progress label is just the percent, got " + label)
	building.completed = true
	runner.check(View.building_label(building).is_empty(), "I4 a completed building has no world text")
	return true

func test_horde_count(runner) -> bool:
	var view = View.new()
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 1000)
	var ids: Array = []
	for kind in ["china_rifle_infantry", "china_rifle_infantry", "china_light_vehicle", "usa_rifle_infantry"]:
		ids.append(sim.spawn(1, Vector2(3.5 + ids.size() * 3, 4.5), kind))
	sim._entities[ids[0]].combat.horde = 2
	sim._entities[ids[2]].combat.horde = 1
	view.set_state(sim.snapshot(), [])
	runner.check(view.horde_count() == 2, "V3 two units carry a horde bonus, got %d" % view.horde_count())
	view.free()
	return true

func test_rebuild_laborer_unselectable(runner) -> bool:
	var view = View.new()
	var sim = CombatFixture.world()
	sim.add_player(1, 1000)
	sim.add_player(2, 1000)
	var id: int = Fixture.add_completed(sim, 1, "frc_barracks", Vector2i(10, 10))
	sim.remove_object(id)
	var hole: Dictionary = sim.snapshot().buildings[0]
	while sim.tick() < hole.rebuild.respawn_tick: sim.step()
	sim.step()
	var state: Dictionary = sim.snapshot()
	var worker: Dictionary = state.entities.filter(func(u: Dictionary) -> bool: return u.has("hole_id"))[0]
	var site: Dictionary = state.buildings.filter(func(b: Dictionary) -> bool: return b.has("hole_id"))[0]
	view.set_state(state, [])
	var anchor := Iso.world_to_plane(Vector2(worker.position[0], worker.position[1])) + Vector2(0, -8)
	runner.check(view.pick_entity(anchor) == -1 and view.pick_entity(anchor, true) == -1, "V9 a click on the rebuild laborer selects nothing")
	runner.check(view.pick_entities(Rect2(anchor - Vector2(40, 40), Vector2(80, 80))).is_empty(), "V9 a drag box over the rebuild laborer selects nothing")
	var inside: Vector2 = Iso.world_to_plane(Vector2(11, 11))
	runner.check(view.pick_target(inside, 2) == site.id, "V9 pick_target over a masked hole returns the site")
	view.free()
	return true

func test_crate_marks_frc_only(runner) -> bool:
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	sim._crates.append({"cell": [4, 7], "until": 900})
	sim._crates.append({"cell": [12, 3], "until": 950})
	for seat in [[1, "frc", 2], [2, "usa", 0]]:
		sim._players[1].faction = seat[1]
		var view = View.new()
		view.local_player = 1
		view.set_state(sim.snapshot(), [])
		var marks: Array[Vector2] = view.crate_marks()
		runner.check(marks.size() == seat[2], "V10 a %s seat sees %d crate marks, got %d" % [seat[1], seat[2], marks.size()])
		for mark in marks:
			var world: Vector2 = Iso.plane_to_world(mark)
			runner.check(Vector2i(world.floor()) in [Vector2i(4, 7), Vector2i(12, 3)] and absf(world.x - floorf(world.x) - 0.5) < 0.01 and absf(world.y - floorf(world.y) - 0.5) < 0.01, "V10 a mark lies at the centre of its cell")
		view.free()
	return true

func test_passengers_not_pickable(runner) -> bool:
	var view = View.new()
	var sim = CombatFixture.world()
	sim.add_player(1, 1000)
	sim.add_player(2, 1000)
	var car: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_light_vehicle")
	var rider: int = sim.spawn(1, Vector2(12.5, 10.5), "usa_rifle_infantry")
	var foe_car: int = sim.spawn(2, Vector2(20.5, 20.5), "usa_light_vehicle")
	var foe_rider: int = sim.spawn(2, Vector2(22.5, 20.5), "usa_rifle_infantry")
	for pair: Array in [[rider, car], [foe_rider, foe_car]]:
		sim._entities[pair[0]].container_id = pair[1]
		sim._entities[pair[0]].position = sim._entities[pair[1]].position.duplicate()
	view.set_state(sim.snapshot(), [])
	var box := Rect2(Iso.world_to_plane(Vector2(10.5, 10.5)) - Vector2(60, 60), Vector2(120, 120))
	runner.check(view.pick_entities(box) == [car], "V10 a drag box over a loaded transport selects the carrier only: %s" % [view.pick_entities(box)])
	runner.check(view.pick_target(Iso.world_to_plane(Vector2(20.5, 20.5)) + Vector2(0, -8), 1) == foe_car, "V10 right-click on an enemy transport targets the carrier")
	view.free()
	return true

func test_terrain_redraws_only_when_map_changes(runner) -> bool:
	var sim = Fixture.make_world()
	var view = View.new()
	runner.root.add_child(view)
	var terrain = view.get_node("Terrain")
	runner.check(terrain.show_behind_parent,"V9 terrain draws behind the parent's objects")
	view.set_state({},[])
	await runner.process_frame
	runner.check(terrain.draws == 0,"V9 no map draws no terrain")
	view.set_state(sim.snapshot(),[])
	await runner.process_frame
	var first: int = terrain.draws
	runner.check(first == 1,"V9 first state draws the terrain once")
	for i in 10:
		sim.step()
		view.set_state(sim.snapshot(),[])
		view.queue_redraw()
	await runner.process_frame
	runner.check(terrain.draws == first,"V9 ten ticks on one map keep the cached terrain")
	Fixture.build(runner,sim,"usa_power_plant",Vector2i(8,4))
	view.set_state(sim.snapshot(),[])
	await runner.process_frame
	runner.check(terrain.draws == first + 1,"V9 a new building footprint redraws the terrain")
	view.set_state(Fixture.make_world().snapshot(),[])
	await runner.process_frame
	runner.check(terrain.draws == first + 2,"V9 a new simulation redraws the terrain")
	view.free()
	return true

func test_structures_redraw_only_when_they_change(runner) -> bool:
	var sim = Fixture.make_world()
	var hall: int = Fixture.add_completed(sim, 1, "usa_supply_center", Vector2i(7, 8))
	sim.add_supply_source(Vector2i(10, 10), 5)
	var view = View.new()
	runner.root.add_child(view)
	var layer = view.get_node("Structures")
	runner.check(layer.show_behind_parent, "V12 structures draw behind the parent's units")
	runner.check(view.get_node("Bodies").show_behind_parent and view.get_node("Bodies").get_index() > layer.get_index(), "V12 bodies draw over the footprints")
	view.set_state(sim.snapshot(), [])
	await runner.process_frame
	var first: int = layer.draws
	runner.check(first == 1, "V12 first state draws the structures once")
	for i in 10:
		sim.step()
		view.set_state(sim.snapshot(), [])
		view.queue_redraw()
	await runner.process_frame
	runner.check(layer.draws == first, "V12 ten ticks with no structure change keep the cached layer")
	var selected: Array[int] = [hall]
	view.set_state(sim.snapshot(), selected)
	await runner.process_frame
	runner.check(layer.draws == first + 1, "V12 selecting a building redraws the layer")
	Fixture.add_completed(sim, 1, "usa_power_plant", Vector2i(14, 8))
	view.set_state(sim.snapshot(), selected)
	await runner.process_frame
	runner.check(layer.draws == first + 2, "V12 a new building redraws the layer")
	view.free()
	return true

class LoggingView extends View:
	var order: Array[String] = []

	func _draw_label(_point: Vector2, text: String) -> void:
		if text.begins_with("Boxes"): order.append("label on parent" if _canvas == self else "label on other")

	func _draw_footprint(_origin: Array, size: Vector2i, color: Color, _selected: bool) -> void:
		if size == Vector2i(3, 3) and color != Color("9f8045"): order.append("building on parent" if _canvas == self else "building behind")

func test_pile_label_drawn_over_buildings(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(10, 10), 5)
	var hall: int = Fixture.add_completed(sim, 1, "usa_supply_center", Vector2i(7, 8))
	var view = LoggingView.new()
	runner.root.add_child(view)
	view.set_state(sim.snapshot(), [])
	var points: PackedVector2Array = view.pile_text_points(Fixture.object(sim, source))
	var label := Rect2(points[0] + Vector2(-View.LABEL_WIDTH / 2.0, -view.text_height()), Vector2(View.LABEL_WIDTH, 2.0 * view.text_height()))
	var origin: Array = Fixture.object(sim, hall).origin
	var diamond: PackedVector2Array = view._cell_polygon(Vector2(origin[0], origin[1]), Vector2(3, 3))
	runner.check(not Geometry2D.intersect_polygons(diamond, PackedVector2Array([label.position, Vector2(label.end.x, label.position.y), label.end, Vector2(label.position.x, label.end.y)])).is_empty(), "V11 fixture: the building diamond reaches the pile label")
	await runner.process_frame
	await runner.process_frame
	runner.check(view.order.has("building behind") and not view.order.has("building on parent"), "V11 the footprint is drawn on the layer behind the parent, got " + str(view.order))
	runner.check(view.order.has("label on parent") and not view.order.has("label on other"), "V11 the pile label is drawn by the parent, over every body, got " + str(view.order))
	view.free()
	return true

class SourceSizeView extends View:
	var sizes: Array[Vector2i] = []

	func _draw_footprint(_origin: Array, size: Vector2i, color: Color, _selected: bool) -> void:
		if color == Color("9f8045"): sizes.append(size)

func test_small_pile_view(runner) -> bool:
	var sim = Fixture.make_world()
	var pile: int = sim.add_supply_source(Vector2i(24,4),50,Vector2i.ONE,true)
	var dock: int = sim.add_supply_source(Vector2i(10,20),8)
	var view = SourceSizeView.new()
	runner.root.add_child(view)
	view.set_state(sim.snapshot(),[])
	runner.check(view.pick_object(Iso.world_to_plane(Vector2(24.5,4.5))) == pile and view.pick_source(Iso.world_to_plane(Vector2(24.5,4.5))) == pile,"V13 the pile's own cell picks it")
	runner.check(view.pick_object(Iso.world_to_plane(Vector2(25.5,5.5))) == -1 and view.pick_source(Iso.world_to_plane(Vector2(25.5,5.5))) == -1,"V13 a cell a 4x5 pile would cover does not")
	runner.check(view.pick_source(Iso.world_to_plane(Vector2(12,22))) == dock,"V13 docks still pick over 4x5")
	await runner.process_frame
	runner.check(view.sizes == [Vector2i.ONE,Vector2i(4,5)],"V13 each source drawn at its own footprint, got " + str(view.sizes))
	sim.remove_object(pile)
	var selected: Array[int] = [pile]
	view.set_state(sim.snapshot(),selected)
	view.queue_redraw()
	await runner.process_frame
	runner.check(view.pick_source(Iso.world_to_plane(Vector2(24.5,4.5))) == -1,"V13 a selected pile that vanished is not picked")
	view.free()
	return true

func test_structures_redraw_when_a_pile_vanishes(runner) -> bool:
	var sim = Fixture.make_world()
	var pile: int = sim.add_supply_source(Vector2i(10,10),1,Vector2i.ONE,true)
	var view = View.new()
	runner.root.add_child(view)
	var layer = view.get_node("Structures")
	view.set_state(sim.snapshot(),[])
	await runner.process_frame
	var first: int = layer.draws
	sim.remove_object(pile)
	view.set_state(sim.snapshot(),[])
	await runner.process_frame
	runner.check(layer.draws == first + 1,"V14 the structure layer redraws when a pile disappears")
	view.free()
	return true

func test_pick_under_roof(runner) -> bool:
	var sim = Fixture.make_world()
	Fixture.add_completed(sim, 1, "usa_factory", Vector2i(10, 10))
	var tank: int = sim.spawn(1, Vector2(11.5, 9.5), "usa_tank")
	var view = View.new()
	view.set_state(sim.snapshot(), [])
	runner.check(view.pick_entity(Iso.world_to_plane(Vector2(11.5, 9.5)) + Vector2(0, -8)) == tank, "V15 tank north of the factory is picked at its ground anchor")
	var highest: float = 0.0
	for part in Shapes.parts(&"war_factory", 2).size():
		for point in Bake.mesh(&"war_factory", part, 0, 2).points: highest = minf(highest, point.y)
	var roof: Vector2 = Iso.world_to_plane(Vector2(11.5, 11.5)) + Vector2(0, highest + 3.0)
	runner.check(view.pick_object(roof) == -1, "V15 a click on the drawn roof outside the ground footprint picks nothing")
	view.free()
	return true

func test_structure_bodies_in_shared_list(runner) -> bool:
	var sim = Fixture.make_world()
	var factory: int = Fixture.add_completed(sim, 1, "usa_factory", Vector2i(10, 10))
	var ids: Array = WorldBatch.objects(sim.snapshot()).map(func(item: Dictionary) -> int: return item.id)
	runner.check(ids.has(factory), "V16 the factory is in the shared object list")
	return true

class HealthView extends View:
	var canvases: Array = []

	func _draw_health(_top_left: Vector2, object: Dictionary, _selected: bool) -> void:
		if object.has("origin"): canvases.append(_canvas)

func test_building_health_bar_in_overlay_pass(runner) -> bool:
	var sim = Fixture.make_world()
	var factory: int = Fixture.add_completed(sim, 1, "usa_factory", Vector2i(10, 10))
	sim._buildings[factory].hp = 1000
	var view = HealthView.new()
	runner.root.add_child(view)
	view.set_state(sim.snapshot(), [])
	await runner.process_frame
	await runner.process_frame
	runner.check(not view.canvases.is_empty() and view.canvases.all(func(canvas) -> bool: return canvas == view), "V17 the building bar is drawn by the parent, got %d on other canvases" % view.canvases.filter(func(canvas) -> bool: return canvas != view).size())
	view.free()
	return true

func test_health_bar_rule(runner) -> bool:
	runner.check(not View.shows_health(false, 100, 100, false), "V18 unselected full hp shows no bar")
	runner.check(View.shows_health(true, 100, 100, false), "V18 selected full hp shows a bar")
	runner.check(View.shows_health(false, 99, 100, false), "V18 damaged shows a bar")
	runner.check(View.shows_health(false, 100, 100, true), "V18 hovered shows a bar")
	return true

func test_health_color_ends(runner) -> bool:
	runner.check(View.health_color(1.0) == Palette.HEALTH_GREEN, "V19 full is green")
	runner.check(View.health_color(0.5) == Palette.HEALTH_YELLOW, "V19 half is yellow")
	runner.check(View.health_color(0.0) == Palette.HEALTH_RED, "V19 empty is red")
	runner.check(View.health_color(0.75).is_equal_approx(Palette.HEALTH_YELLOW.lerp(Palette.HEALTH_GREEN, 0.5)), "V19 linear between")
	runner.check(View.health_color(2.0) == Palette.HEALTH_GREEN and View.health_color(-1.0) == Palette.HEALTH_RED, "V19 clamped")
	return true

func test_selection_is_ground_diamond(runner) -> bool:
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 1000)
	var tank: int = sim.spawn(1, Vector2(6.5, 7.5), "usa_tank")
	var view = View.new()
	view.set_state(sim.snapshot(), [])
	runner.check(view.selected_unit_lines().is_empty(), "V20 nothing selected draws no diamond")
	var selected: Array[int] = [tank]
	view.set_state(sim.snapshot(), selected)
	var lines: PackedVector2Array = view.selected_unit_lines()
	var anchor: Vector2 = Iso.world_to_plane(Vector2(6.5, 7.5))
	runner.check(lines.size() == 8, "V20 a selected unit adds 4 segments, got %d points" % lines.size())
	var center := Vector2.ZERO
	for point in lines: center += point / lines.size()
	runner.check(center.distance_to(anchor) < 0.01, "V20 the diamond is centred on the ground anchor")
	var top: float = lines[0].y
	var bottom: float = lines[4].y
	runner.check(lines[0].x == anchor.x and lines[2].x - lines[6].x > 2.0 * (bottom - top) - 0.01, "V20 the diamond is twice as wide as high, like a cell")
	view.free()
	return true

func test_biome_change_redraws_terrain(runner) -> bool:
	var sim = Fixture.make_world()
	var view = View.new()
	runner.root.add_child(view)
	var terrain = view.get_node("Terrain")
	view.set_state(sim.snapshot(), [])
	await runner.process_frame
	var first: int = terrain.draws
	view.set_biome(1)
	await runner.process_frame
	runner.check(terrain.draws == first + 1, "V21 a biome change on the same map redraws the terrain once")
	view.set_biome(1)
	await runner.process_frame
	runner.check(terrain.draws == first + 1, "V21 the same biome again keeps the cached terrain")
	terrain.set_palette(Palette.ground(0))
	await runner.process_frame
	runner.check(terrain.draws == first + 2, "V21 set_palette always redraws")
	view.free()
	return true

func test_grid_only_while_placing(runner) -> bool:
	var sim = Fixture.make_world()
	var view = View.new()
	runner.root.add_child(view)
	var terrain = view.get_node("Terrain")
	view.set_state(sim.snapshot(), [])
	await runner.process_frame
	var draws: int = terrain.draws
	runner.check(view.grid_lines().is_empty(), "V22 no grid without a preview")
	view.set_build_preview([Vector2i(8, 4)], true)
	await runner.process_frame
	runner.check(not view.grid_lines().is_empty() and view.grid_lines().size() % 2 == 0, "V22 grid lines while placing")
	view.set_build_preview([], false)
	await runner.process_frame
	runner.check(view.grid_lines().is_empty(), "V22 the grid ends with the preview")
	runner.check(terrain.draws == draws, "V22 the grid never redraws the cached terrain")
	view.free()
	return true

func test_chevron_placeholder(runner) -> bool:
	var view = View.new()
	var unit := {"id": 1, "kind": "usa_tank", "position": [3.0, 3.0]}
	runner.check(view.veterancy_lines(unit).is_empty(), "V24 no veterancy draws no chevron")
	unit.veterancy = 1
	runner.check(view.veterancy_lines(unit).size() == 4, "V24 rank 1 is one chevron of two segments")
	unit.veterancy = 3
	runner.check(view.veterancy_lines(unit).size() == 12, "V24 rank 3 is three chevrons")
	view.free()
	return true

class BodySpyView extends View:
	var body_draws: int = 0

	func draw_bodies() -> void:
		body_draws += 1
		super()

func _duel() -> Array:
	var sim = Fixture.make_world()
	var attacker: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_tank")
	var target: int = sim.spawn(2, Vector2(9.5, 5.5), "usa_tank")
	return [sim, attacker, target]

func _shot_director(attacker: int, target: int) -> Director:
	var director := Director.new()
	var events: Array[Dictionary] = [{"type": "shot", "tick": 1, "attacker_id": attacker, "target_id": target, "damage": 1, "splash": false}]
	var none: Array[Dictionary] = []
	director.collect_step(1, events, none)
	return director

func test_cues_draw_on_low_in_the_view(runner) -> bool:
	var duel := _duel()
	var counts: Array[int] = []
	for director in [null, _shot_director(duel[1], duel[2])]:
		var view = View.new()
		view.set_quality(GraphicsSettings.LOW)
		if director != null: view.set_visuals(director)
		view.set_state(duel[0].snapshot(), [])
		counts.append(view._batch.triangle_count)
		view.free()
	runner.check(counts[1] > counts[0], "V24 Low still draws shot cues, triangles %d without, %d with a shot" % counts)
	return true

func test_effects_age_per_tick_not_per_refresh(runner) -> bool:
	var duel := _duel()
	var director := _shot_director(duel[1], duel[2])
	var view = View.new()
	view.set_visuals(director)
	view.set_state(duel[0].snapshot(), [])
	view.set_state(duel[0].snapshot(), [])
	var ages: Array = director.effects().map(func(effect: Dictionary) -> int: return effect.age)
	runner.check(not ages.is_empty() and ages.all(func(age: int) -> bool: return age == 0), "V25 two refreshes of one tick do not age effects, got %s" % [ages])
	duel[0].step()
	view.set_state(duel[0].snapshot(), [])
	runner.check(director.effects().all(func(effect: Dictionary) -> bool: return effect.age == 1), "V25 the next tick ages them once")
	view.free()
	return true

func test_bodies_submitted_each_frame(runner) -> bool:
	var duel := _duel()
	var view = BodySpyView.new()
	runner.root.add_child(view)
	view.set_state(duel[0].snapshot(), [])
	await runner.process_frame
	await runner.process_frame
	runner.check(view.body_draws >= 1, "V26 the body layer asked the view to submit the batch, got %d" % view.body_draws)
	view.free()
	return true

func test_quality_change_rebuilds(runner) -> bool:
	var duel := _duel()
	var view = View.new()
	view.set_state(duel[0].snapshot(), [])
	var high: int = view._batch.triangle_count
	view.set_quality(GraphicsSettings.LOW)
	runner.check(view._batch.triangle_count < high, "V27 Low shows fewer triangles without a new tick (%d -> %d)" % [high, view._batch.triangle_count])
	view.free()
	var soldiers = Fixture.make_world()
	soldiers.spawn(1, Vector2(5.5, 5.5), "usa_rifle_infantry")
	view = View.new()
	view.set_state(soldiers.snapshot(), [])
	view.set_quality(GraphicsSettings.HIGH)
	view.set_zoom(0.5)
	var far: int = view._batch.triangle_count
	view.set_zoom(2.0)
	runner.check(view._batch.triangle_count > far, "V27 zoom changes the detail at once (%d -> %d)" % [far, view._batch.triangle_count])
	view.free()
	return true

func test_draw_timing_only_on_request(runner) -> bool:
	var duel := _duel()
	var view = View.new()
	runner.root.add_child(view)
	view.set_state(duel[0].snapshot(), [])
	await runner.process_frame
	await runner.process_frame
	runner.check(view.draw_usec == 0 and not view.time_draws, "V28 no draw timing unless asked")
	view.free()
	return true

func test_air_pick_box_follows_lift(runner) -> bool:
	var sim = Fixture.make_world()
	var heli: int = sim.spawn(1, Vector2(9.0, 9.0), "usa_collector")
	var view = View.new()
	view.set_state(sim.snapshot(), [])
	var anchor: Vector2 = Iso.world_to_plane(Vector2(9.0, 9.0))
	runner.check(view.pick_entity(anchor + Vector2(0, -WorldBatch.AIR_LIFT - 8.0)) == heli, "V29 the helicopter is picked where it is drawn")
	view.free()
	return true

func test_pick_covers_drawn_body(runner) -> bool:
	var view = View.new()
	var sim = CombatFixture.world()
	sim.add_player(1, 1000)
	for kind in ["usa_tank", "usa_rifle_infantry", "usa_light_vehicle", "usa_builder", "china_collector"]:
		var id: int = sim.spawn(1, Vector2(10.5, 10.5), kind)
		for quarter in 4:
			var state: Dictionary = sim.snapshot()
			var unit: Dictionary = state.entities.filter(func(u: Dictionary) -> bool: return u.id == id)[0]
			unit.heading = [cos(quarter * PI / 2.0), sin(quarter * PI / 2.0)]
			view.set_state(state, [])
			var batch = WorldBatch.new()
			batch.build(WorldBatch.objects(state).filter(func(item: Dictionary) -> bool: return item.id == id) as Array[Dictionary], {}, 1, 0)
			var top := Vector2(0, 1e9)
			var bottom := Vector2(0, -1e9)
			for point in batch.points:
				if point.y < top.y: top = point
				if point.y > bottom.y: bottom = point
			runner.check(view.pick_entity(top + Vector2(0, 1)) == id, "V16 %s heading %d: the top of the drawn body picks it (%s)" % [kind, quarter, top])
			runner.check(view.pick_entity(bottom + Vector2(0, -1)) == id, "V16 %s heading %d: the bottom of the drawn body picks it (%s)" % [kind, quarter, bottom])
		sim.remove_object(id)
	view.free()
	return true

func test_death_point_falls_back_to_previous_tick(runner) -> bool:
	var sim = Fixture.make_world()
	var id: int = sim.spawn(1, Vector2(6.5, 6.5), "usa_tank")
	var view = View.new()
	view.set_state(sim.snapshot(), [])
	runner.check(not view._last_points.has(id), "V30 an unshot unit has no remembered point")
	sim.remove_object(id)
	var gone: Dictionary = sim.snapshot()
	gone.combat_events = [{"type": "death", "tick": 1, "object_id": id}]
	view.set_state(gone, [])
	runner.check(view._last_points.get(id) == Iso.world_to_plane(Vector2(6.5, 6.5)) + Vector2(0, -8), "V30 a death keeps the point from the previous tick")
	view.free()
	return true

func test_selected_battery_line_without_a_shot(runner) -> bool:
	var view = View.new()
	var world: Array = _battery_world()
	world[0].step()
	var state: Dictionary = world[0].snapshot()
	state.combat_events = []
	view.set_state(state, [world[1]])
	var lines: Array = view.battery_target_lines()
	runner.check(lines.size() == 1 and view._last_points.has(world[2]), "V31 a selected battery with a target draws its line on a tick without a shot")
	view.free()
	return true

func test_kind_info_follows_air_kinds(runner) -> bool:
	var saved: Dictionary = Registry.air_kinds
	runner.check(WorldBatch.kind_info("usa_tank")[1] == WorldBatch.LAYER_GROUND, "V32 a tank is ground")
	Registry.air_kinds = {"usa_tank": true}
	runner.check(WorldBatch.kind_info("usa_tank")[1] == WorldBatch.LAYER_AIR, "V32 swapping air_kinds drops the cached layer")
	Registry.air_kinds = saved
	runner.check(WorldBatch.kind_info("usa_tank")[1] == WorldBatch.LAYER_GROUND, "V32 swapping back restores it")
	return true

func test_custom_ground_colors_rearm_the_biome(runner) -> bool:
	var view = View.new()
	view.set_biome(1)
	view.set_ground_colors({"ground": Color.RED, "cliff_top": Color.RED, "cliff_side": Color.RED, "water": Color.RED})
	view.set_biome(1)
	runner.check(view._terrain._colors.ground == Palette.ground(1).ground, "V33 set_biome applies again after custom ground colours")
	view.free()
	return true

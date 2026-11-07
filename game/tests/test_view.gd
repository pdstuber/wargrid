@warning_ignore_start("untyped_declaration")
extends RefCounted

const View = preload("res://scripts/presentation/world_view.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatFixture = preload("res://tests/combat_fixture.gd")
const MovementWorkload = preload("res://scripts/debug/movement_workload.gd")

func cases() -> Array[Callable]:
	return [test_pick, test_box_and_order,test_economy_picking,test_build_preview,test_click_hint_lifetime,test_resume_hint,test_heading_mark_layout,test_depth_order_matches_comparator,test_battery_shot_line,test_battery_target_line,test_building_icons,test_building_label_has_no_kind_id,test_horde_marks,test_rebuild_laborer_unselectable]

func test_pick(runner) -> bool:
	var view = View.new()
	runner.check(view.pick_entity(Vector2.ZERO) == -1, "V1 empty")
	var sim = Simulation.new()
	sim.spawn(1, Vector2(2.5, 2.5))
	sim.spawn(2, Vector2(4.5, 4.5))
	var state: Dictionary = sim.snapshot()
	view.set_state(state, [1])
	var anchor := Iso.world_to_plane(Vector2(2.5, 2.5))
	runner.check(view.pick_entity(anchor + Vector2(0, -8)) == 1, "V1 interior")
	runner.check(view.pick_entity(anchor + Vector2(-12, -16)) == 1, "V1 top left bound")
	for offset in [Vector2(12, -8), Vector2(0, 0), Vector2(-13, -8), Vector2(0, -17)]:
		runner.check(view.pick_entity(anchor + offset) == -1, "V1 outside " + str(offset))
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
	runner.check(view.pick_object(Iso.world_to_plane(Vector2(25.5,5.5)) + Vector2(0,-26)) == air,"V3 air unit precedence over source")
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

func test_heading_mark_layout(runner) -> bool:
	var view = View.new()
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 1000)
	var ids: Array = []
	for kind in ["usa_rifle_infantry", "usa_tank", "usa_builder", "usa_light_vehicle", "usa_collector"]:
		ids.append(sim.spawn(1, Vector2(3.5 + ids.size() * 2, 4.5), kind))
	view.set_state(sim.snapshot(), [])
	var marks: Array[Dictionary] = view.heading_marks()
	runner.check(marks.size() == 4, "V2 one mark per ground unit")
	for mark in marks:
		var bounds: Rect2 = view._vehicle_bounds(view._state.entities[ids.find(mark.id)])
		runner.check(bounds.has_point(mark.from) and bounds.has_point(mark.to), "V2 mark inside the unit rectangle " + str(mark.id))
		runner.check(mark.id != ids[4], "V2 no mark for a collector")
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

func test_building_icons(runner) -> bool:
	var expected := {"usa_command_center": "command", "usa_power_plant": "power", "usa_supply_center": "supply", "usa_barracks": "barracks", "usa_factory": "factory", "usa_defence": "battery"}
	for kind: String in expected: runner.check(View.icon_name(kind) == expected[kind], "I1 %s icon, got %s" % [kind, View.icon_name(kind)])
	for kind: String in Registry.buildings().filter(func(id: String) -> bool: return id not in ["china_defence", "frc_defence", "frc_hole_1", "frc_hole_2", "frc_hole_3"]): runner.check(not Registry.icon(kind).is_empty(), "I1 %s defines an icon" % kind)
	Registry.add_test_kind("test_depot", {"display_name": "Zeta Depot", "footprint": Vector2i(1, 1)})
	runner.check(View.icon_name("test_depot").is_empty() and View.fallback_letter("test_depot") == "Z", "I2 no icon falls back to the display-name initial")
	Registry.add_test_kind("test_other", {"display_name": "Other", "icon": "factory", "footprint": Vector2i(1, 1)})
	runner.check(View.icon_name("test_other") == "factory", "I2 a new kind picks its glyph from data alone")
	Registry.add_test_kind("test_odd", {"display_name": "Odd", "icon": "unheard_of", "footprint": Vector2i(1, 1)})
	runner.check(View.icon_name("test_odd").is_empty() and View.fallback_letter("test_odd") == "O", "I2 an unknown icon name falls back too")
	Registry.clear_test_kinds()
	for size in [1, 2, 3]:
		var radius: float = View.icon_radius(Vector2i(size, size + 1))
		runner.check(3.0 * radius <= 32.0 * size, "I3 glyph box stays inside a %d-cell diamond" % size)
		runner.check(radius < 23.0, "I3 glyph clear of the health bar at %d cells" % size)
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

func test_horde_marks(runner) -> bool:
	var view = View.new()
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 1000)
	var ids: Array = []
	for kind in ["china_rifle_infantry", "china_rifle_infantry", "china_light_vehicle", "usa_rifle_infantry"]:
		ids.append(sim.spawn(1, Vector2(3.5 + ids.size() * 3, 4.5), kind))
	sim._entities[ids[0]].combat.horde = 2
	sim._entities[ids[2]].combat.horde = 1
	view.set_state(sim.snapshot(), [])
	var marks: Array[Vector2] = view.horde_marks()
	runner.check(marks.size() == 2, "V3 one horde mark per unit with a bonus")
	for index in [0, 2]:
		var bounds: Rect2 = view._vehicle_bounds(view._state.entities[index])
		var hit: Array = marks.filter(func(mark: Vector2) -> bool: return bounds.has_point(mark) and mark.y > view.health_rect(bounds).end.y)
		runner.check(hit.size() == 1, "V3 the mark of unit %d sits inside its bounds below the health bar" % index)
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

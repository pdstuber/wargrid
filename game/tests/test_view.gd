extends RefCounted

const View = preload("res://scripts/presentation/world_view.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")

func cases() -> Array[Callable]:
	return [test_pick, test_box_and_order,test_economy_picking,test_build_preview,test_click_hint_lifetime,test_resume_hint,test_heading_mark_layout]

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
	state.entities[0].position[0] = 10
	state.entities.clear()
	runner.check(view.pick_entity(anchor + Vector2(0, -8)) == 1, "V1 set_state copies")
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
	var building: int = Fixture.build(runner,sim,"reactor",Vector2i(8,4))
	var view = View.new()
	view.set_state(sim.snapshot(),[building])
	runner.check(view.pick_object(Iso.world_to_plane(Vector2(8,4))) == building,"V3 footprint inclusive origin")
	runner.check(view.pick_object(Iso.world_to_plane(Vector2(10,6))) == building,"V3 footprint inclusive far edge")
	runner.check(view.pick_object(Iso.world_to_plane(Vector2(25.5,5.5))) == source,"V3 neutral source")
	var air: int = sim.spawn(1,Vector2(25.5,5.5),"collector")
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
	Fixture.send(sim, {"type":"build","builder_id":1,"building_kind":"reactor","origin":[8,4]})
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
	var second: int = sim.spawn(1, Vector2(5.5, 5.5), "builder")
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
	for kind in ["infantry", "tank", "builder", "vehicle", "collector"]:
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

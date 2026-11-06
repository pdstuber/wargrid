@warning_ignore_start("untyped_declaration")
extends RefCounted

const Base = preload("res://scenes/base.tscn")
const Fixture = preload("res://tests/economy_fixture.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")

func cases() -> Array[Callable]:
	return [test_base_ready,test_placement_input,test_production_ui,test_context_orders,test_execution_feedback,test_preview_hover_cost,test_resume_status,test_queue_label,test_one_snapshot_per_refresh]

func setup(runner):
	var main = Base.instantiate()
	runner.root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await runner.process_frame
	return main

func key(main, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	main._unhandled_input(event)

func pointer(main, plane: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = main.get_node("WorldView").get_global_transform_with_canvas() * plane
	event.button_index = button
	event.pressed = pressed
	main._unhandled_input(event)

func hover(main, plane: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = main.get_node("WorldView").get_global_transform_with_canvas() * plane
	main._unhandled_input(event)

func test_base_ready(runner) -> bool:
	var main = await setup(runner)
	var state: Dictionary = main.simulation.snapshot()
	runner.check(state.map.size == [32,32] and state.entities.size() == 1 and state.entities[0].kind == "usa_builder" and state.entities[0].position == [4.5,4.5],"Bs1 authored builder map")
	runner.check(state.players.size() == 1 and state.players[0].credits == 10000 and state.sources.size() == 1 and state.sources[0].origin == [24,4] and state.sources[0].boxes == 200 and state.buildings.is_empty(),"Bs1 authored economy")
	main._physics_process(0.0)
	runner.check(main.simulation.snapshot().tick == state.tick + 1,"Bs1 one physics tick")
	key(main,KEY_B)
	runner.check(main.simulation.snapshot().terrain_cells.is_empty(),"Bs1 B cannot toggle terrain")
	runner.check(main.get_node("HUD/Status").text.contains("Credits"),"Bs1 economy HUD")
	main.free()
	return true

func test_placement_input(runner) -> bool:
	var main = await setup(runner)
	main.simulation = Fixture.make_world()
	main.selected_ids.assign([1])
	main._refresh()
	var camera: Camera2D = main.get_node("Camera2D")
	var before: Dictionary = main.simulation.snapshot()
	for center in [Vector2(0,256),Vector2(80,320)]:
		for zoom in [.5,1.0,2.0]:
			camera.position = center
			camera.zoom = Vector2.ONE * zoom
			camera.force_update_scroll()
			await runner.process_frame
			key(main,KEY_1)
			hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
			runner.check(main._placement_kind == "usa_power_plant" and main.get_node("WorldView")._preview_cells == [Vector2i(8,4),Vector2i(9,4),Vector2i(8,5),Vector2i(9,5)],"Bs2 transformed snapped preview")
			var position: Vector2 = camera.position
			main.pan_camera(Vector2.RIGHT,1.0)
			main.change_zoom(1)
			runner.check(camera.position == position and camera.zoom.x == zoom,"Bs2 placement freezes camera")
			key(main,KEY_ESCAPE)
			runner.check(main.selected_ids == [1] and main._placement_kind.is_empty() and main.simulation.snapshot() == before,"Bs2 cancel no order spend preserves selection")
	key(main,KEY_1)
	hover(main,Iso.world_to_plane(Vector2(4.25,4.25)))
	pointer(main,Iso.world_to_plane(Vector2(4.25,4.25)),MOUSE_BUTTON_LEFT,false)
	runner.check(not main._placement_kind.is_empty() and main.simulation.snapshot() == before and not main._error.is_empty(),"Bs2 invalid remains mode reason")
	hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
	pointer(main,Iso.world_to_plane(Vector2(8.25,4.25)),MOUSE_BUTTON_LEFT,true)
	pointer(main,Iso.world_to_plane(Vector2(8.25,4.25)),MOUSE_BUTTON_LEFT,false)
	var state: Dictionary = main.simulation.snapshot()
	runner.check(main._placement_kind.is_empty() and state.pending_commands.size() == 1,"Bs2 release exactly one build")
	if not state.pending_commands.is_empty(): runner.check(state.pending_commands[0].type == "build" and state.pending_commands[0].origin == [8,4] and state.pending_commands[0].builder_id == 1 and state.pending_commands[0].sequence == 0,"Bs2 envelope")
	var queued: Dictionary = main.simulation.snapshot()
	pointer(main,Iso.world_to_plane(Vector2(4.5,4.5)) + Vector2(0,-8),MOUSE_BUTTON_LEFT,true)
	key(main,KEY_2)
	runner.check(main.is_selecting() and main._placement_kind.is_empty(),"Bs2 placement key waits for gesture")
	pointer(main,Iso.world_to_plane(Vector2(4.5,4.5)) + Vector2(0,-8),MOUSE_BUTTON_LEFT,false)
	runner.check(not main.is_selecting() and main._placement_kind == "usa_supply_center","Bs2 deferred placement after selection")
	pointer(main,Iso.world_to_plane(Vector2(10,10)),MOUSE_BUTTON_RIGHT,true)
	runner.check(main._placement_kind.is_empty() and main.selected_ids == [1] and main.simulation.snapshot() == queued,"Bs2 right cancel preserves state")
	main.free()
	return true

func test_production_ui(runner) -> bool:
	var main = await setup(runner)
	main.simulation = Fixture.make_world(50000)
	Fixture.build(runner,main.simulation,"usa_power_plant",Vector2i(5,5))
	var depot: int = Fixture.build(runner,main.simulation,"usa_supply_center",Vector2i(10,4))
	main._refresh()
	pointer(main,Iso.world_to_plane(Vector2(11.5,5.5)),MOUSE_BUTTON_LEFT,true)
	pointer(main,Iso.world_to_plane(Vector2(11.5,5.5)),MOUSE_BUTTON_LEFT,false)
	runner.check(main.selected_building_id == depot and main.selected_ids.is_empty() and main.get_node("WorldView")._selected_ids == [depot],"Bs3 building selection outline")
	main.selected_building_id = depot
	main.get_node("HUD/Economy/Produce").pressed.emit()
	key(main,KEY_E)
	var state: Dictionary = main.simulation.snapshot()
	runner.check(state.pending_commands.size() == 2,"Bs3 one command per produce")
	main._physics_process(0.0)
	var queue: Array = Fixture.object(main.simulation,depot).queue
	if queue.size() == 2:
		await runner.process_frame
		var button: Button = main.get_node("HUD/Economy/Queue").get_child(1)
		var viewport_point: Vector2 = button.get_global_rect().get_center()
		var press := InputEventMouseButton.new()
		press.position = runner.root.get_final_transform() * viewport_point
		press.global_position = press.position
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		Input.parse_input_event(press)
		await runner.process_frame
		main._physics_process(0.0)
		var release := InputEventMouseButton.new()
		release.position = press.position
		release.global_position = press.position
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		Input.parse_input_event(release)
		await runner.process_frame
		var commands: Array = main.simulation.snapshot().pending_commands
		runner.check(commands.size() == 1 and commands[0].type == "cancel_production" and commands[0].production_id == queue[1].id,"Bs3 real GUI release after tick cancels exact entry once")
		main._physics_process(0.0)
		runner.check(Fixture.object(main.simulation,depot).queue.size() == 1 and Fixture.object(main.simulation,depot).queue[0].id == queue[0].id,"Bs3 stable cancel entry ID")
	else: runner.check(false,"Bs3 queue populated")
	runner.check(main.has_node("HUD/Economy/Produce") and main.get_node("HUD/Economy/Produce").mouse_filter == Control.MOUSE_FILTER_STOP,"Bs3 GUI consumes mouse")
	main.simulation.remove_object(depot)
	main._refresh()
	runner.check(main.selected_building_id == -1,"Bs3 removed selection cleared")
	Fixture.send(main.simulation,{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,12]})
	main._physics_process(0.0)
	var foundation: int = main.simulation.snapshot().buildings.back().id
	main.selected_building_id = foundation
	main._refresh()
	var credits: int = main.simulation.snapshot().players[0].credits
	main.get_node("HUD/Economy/CancelBuild").pressed.emit()
	runner.check(main.simulation.snapshot().pending_commands.size() == 1 and main.simulation.snapshot().pending_commands[0].type == "cancel_build","Bs3 CancelBuild signal submits exactly once")
	main._physics_process(0.0)
	runner.check(Fixture.object(main.simulation,foundation).is_empty() and main.simulation.snapshot().players[0].credits == credits + 800 and main.selected_building_id == -1,"Bs3 CancelBuild refunds selected foundation")
	main.free()
	return true

func test_context_orders(runner) -> bool:
	var main = await setup(runner)
	main.simulation = Fixture.make_world()
	var source: int = main.simulation.add_supply_source(Vector2i(24,4),8)
	var air: int = main.simulation.spawn(1,Vector2(2.5,2.5),"usa_collector")
	main.selected_ids.assign([air])
	main._refresh()
	pointer(main,Iso.world_to_plane(Vector2(25.5,5.5)),MOUSE_BUTTON_RIGHT,true)
	var pending: Array = main.simulation.snapshot().pending_commands
	runner.check(pending.size() == 1 and pending[0].type == "gather" and pending[0].source_id == source,"Bs4 collector context gather")
	main.selected_ids.assign([1,air])
	var before: Dictionary = main.simulation.snapshot()
	pointer(main,Iso.world_to_plane(Vector2(25.5,5.5)),MOUSE_BUTTON_RIGHT,true)
	runner.check(main.simulation.snapshot() == before and not main._error.is_empty(),"Bs4 mixed context rejected")
	pointer(main,Iso.world_to_plane(Vector2(6.5,10.5)),MOUSE_BUTTON_RIGHT,true)
	runner.check(main.simulation.snapshot().pending_commands.size() == 2 and main.simulation.snapshot().pending_commands.back().type == "move","Bs4 mixed ordinary ground move")
	main.simulation = Fixture.make_world()
	Fixture.send(main.simulation,{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4]})
	main.simulation.step()
	Fixture.send(main.simulation,{"type":"stop","entity_ids":[1]})
	main.simulation.step()
	main.selected_ids.assign([1])
	main._refresh()
	pointer(main,Iso.world_to_plane(Vector2(8.5,4.5)),MOUSE_BUTTON_RIGHT,true)
	var resumed: Array = main.simulation.snapshot().pending_commands
	runner.check(resumed.size() == 1 and resumed[0].type == "resume_build" and resumed[0].builder_id == 1 and resumed[0].building_id == 2,"Bs4 builder context resumes foundation")
	pointer(main,Iso.world_to_plane(Vector2(4.5,4.5)) + Vector2(0,-8),MOUSE_BUTTON_LEFT,true)
	var selecting: Dictionary = main.simulation.snapshot()
	pointer(main,Iso.world_to_plane(Vector2(8.5,4.5)),MOUSE_BUTTON_RIGHT,true)
	runner.check(main.is_selecting() and main.simulation.snapshot() == selecting,"Bs4 context suppressed during active selection")
	key(main,KEY_ESCAPE)
	main.free()
	return true

func test_execution_feedback(runner) -> bool:
	var main = await setup(runner)
	main.simulation = Fixture.make_world(800)
	main._submit({"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4],"tick":2})
	main._submit({"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[12,4],"tick":2})
	Fixture.steps(main.simulation,3)
	main._refresh()
	runner.check(main.get_node("HUD/Status").text.contains("Insufficient credits"),"Bs5 due rejection visible")
	main._submit({"type":"stop","entity_ids":[999]})
	var error: String = main._error
	main._refresh()
	runner.check(not error.is_empty() and main._error == error,"Bs5 immediate error persists refresh")
	main.simulation.add_player(2,0)
	var other: int = main.simulation.spawn(2,Vector2(2.5,2.5))
	Fixture.send(main.simulation,{"type":"stop","entity_ids":[other],"player":2})
	main._physics_process(0.0)
	runner.check(main._error == error,"Bs5 unrelated player result preserves immediate error")
	main._submit({"type":"stop","entity_ids":[1]})
	runner.check(main._error.is_empty(),"Bs5 accepted clears immediate error")
	main.free()
	return true

func test_preview_hover_cost(runner) -> bool:
	var main = await setup(runner)
	main.simulation = Fixture.make_world()
	main.selected_ids.assign([1])
	main._refresh()
	key(main,KEY_1)
	var before: int = main.simulation.navigation_builds()
	for i in range(5): hover(main,Iso.world_to_plane(Vector2(8.25,4.25)) + Vector2(i * 0.1,0))
	runner.check(main.simulation.navigation_builds() - before <= 1,"Bs6 hovering one cell builds at most one preview grid")
	hover(main,Iso.world_to_plane(Vector2(12.25,4.25)))
	runner.check(main.simulation.navigation_builds() - before <= 2 and main.get_node("WorldView")._preview_cells[0] == Vector2i(12,4),"Bs6 a new cell recomputes the preview")
	key(main,KEY_ESCAPE)
	key(main,KEY_1)
	runner.check(not main.get_node("WorldView")._preview_cells.is_empty(),"Bs6 re-entering placement redraws the preview")
	main.free()
	return true

func test_resume_status(runner) -> bool:
	var main = await setup(runner)
	main.simulation = Fixture.make_world()
	Fixture.send(main.simulation,{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4]})
	main.simulation.step()
	Fixture.send(main.simulation,{"type":"stop","entity_ids":[1]})
	main.simulation.step()
	main.selected_ids.assign([1])
	main._refresh()
	var status: Label = main.get_node("HUD/Status")
	hover(main,Iso.world_to_plane(Vector2(8.5,4.5)))
	main._refresh()
	runner.check(status.text.contains("Right-click: resume"),"H6 resume hint shown while hovering")
	var economy: Control = main.get_node("HUD/Economy")
	runner.check(economy.position.y >= status.position.y + status.get_minimum_size().y,"H6 buttons below the resume line")
	hover(main,Iso.world_to_plane(Vector2(20.5,20.5)))
	main._refresh()
	runner.check(not status.text.contains("Right-click: resume"),"H6 hint gone off the building")
	main.free()
	return true

func test_queue_label(runner) -> bool:
	var BaseMain = load("res://scripts/base_main.gd")
	runner.check(BaseMain.queue_label({"id":10,"kind":"usa_tank","work":270000}) == "Cancel usa_tank (90%)","Bs5 started entry shows percent, no id or raw work")
	runner.check(BaseMain.queue_label({"id":12,"kind":"usa_tank","work":0}) == "Cancel usa_tank (queued)","Bs5 unstarted entry shows queued")
	return true

func test_one_snapshot_per_refresh(runner) -> bool:
	var main = await setup(runner)
	main.simulation = Fixture.make_world()
	main.selected_building_id = 1
	Profiler.reset()
	Profiler.enabled = true
	main._refresh()
	var calls: int = Profiler.calls(&"snapshot")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(calls == 1, "RF1 a refresh takes one snapshot, got %d" % calls)
	main.free()
	return true

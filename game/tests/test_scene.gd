@warning_ignore_start("untyped_declaration")
extends RefCounted

const Main = preload("res://scenes/main.tscn")
const Iso = preload("res://scripts/presentation/isometric.gd")

func cases() -> Array[Callable]:
	return [test_ready, test_clicks, test_rejection, test_camera, test_driver, test_boxes, test_drag_rules, test_obstacle_toggle, test_double_click_same_kind_on_screen, test_double_click_alt_whole_map, test_double_click_shift_keeps, test_double_click_ctrl_ignored, test_double_click_enemy_or_ground_plain]

func setup(runner):
	var main = Main.instantiate()
	runner.root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await runner.process_frame
	return main

func click(runner, view, plane: Vector2, button: MouseButton) -> void:
	var viewport_point: Vector2 = view.get_global_transform_with_canvas() * plane
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = runner.root.get_final_transform() * viewport_point
		event.global_position = event.position
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await runner.process_frame

func select(runner, main) -> void:
	await click(runner, main.get_node("WorldView"), Iso.world_to_plane(Vector2(1.5, 1.5)) + Vector2(0, -8), MOUSE_BUTTON_LEFT)

func test_ready(runner) -> bool:
	var main = await setup(runner)
	var state: Dictionary = main.simulation.snapshot()
	runner.check(state.entities.size() == 20 and state.entities[0].owner == 1 and state.entities[0].position == [1.5, 1.5], "S1 twenty vehicles")
	var positions: Dictionary = {}
	for i in range(state.entities.size()):
		var unit: Dictionary = state.entities[i]
		@warning_ignore("integer_division")
		runner.check(unit.id == i + 1 and unit.owner == 1 and unit.position == [float(i % 5) + 1.5, float(i / 5) + 1.5], "S1 authored start")
		positions[unit.position] = true
	runner.check(positions.size() == 20, "S1 unique starts")
	runner.check(state.map.blocked_cells.size() == 18, "S1 static obstacle")
	runner.check(main.has_node("Camera2D") and main.has_node("WorldView") and main.has_node("HUD/Status"), "S1 scene nodes")
	runner.check(main.selected_ids == [], "S1 no selection")
	runner.check(main.get_node("Camera2D").position == Iso.world_to_plane(Vector2(8, 8)), "S1 camera center")
	runner.check(main.get_node("HUD/Status").mouse_filter == Control.MOUSE_FILTER_IGNORE, "S1 HUD click through")
	runner.check(ProjectSettings.get_setting("physics/common/physics_ticks_per_second") == 30, "S1 tick rate")
	runner.check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "S1 renderer")
	for binding in [["camera_left", KEY_A, KEY_LEFT], ["camera_right", KEY_D, KEY_RIGHT], ["camera_up", KEY_W, KEY_UP], ["camera_down", KEY_S, KEY_DOWN], ["deselect", KEY_ESCAPE]]:
		for key in binding.slice(1):
			var event := InputEventKey.new()
			event.keycode = key
			runner.check(InputMap.action_has_event(binding[0], event), "S1 action binding " + str([binding[0], key]))
	main.free()
	return true

func test_clicks(runner) -> bool:
	var main = await setup(runner)
	var camera: Camera2D = main.get_node("Camera2D")
	var view = main.get_node("WorldView")
	var sequence := 0
	for center in [Vector2(0, 128), Vector2(80, 160)]:
		for zoom in [0.5, 1.0, 2.0]:
			camera.position = center
			camera.zoom = Vector2.ONE * zoom
			camera.force_update_scroll()
			await runner.process_frame
			await select(runner, main)
			runner.check(main.selected_ids == [1], "S2 transformed selection " + str([center, zoom]))
			await click(runner, view, Iso.world_to_plane(Vector2(4.5, 3.5)), MOUSE_BUTTON_RIGHT)
			var state: Dictionary = main.simulation.snapshot()
			runner.check(state.pending_commands.size() == sequence + 1, "S2 one command per press")
			if state.pending_commands.size() > sequence:
				var cmd: Dictionary = state.pending_commands[sequence]
				runner.check(Vector2(cmd.target[0], cmd.target[1]).distance_to(Vector2(4.5, 3.5)) <= 1e-5, "S2 inverse exact target")
				runner.check(cmd.player == 1 and cmd.entity_ids == [1] and cmd.tick == state.tick and cmd.sequence == sequence, "S2 command envelope")
			sequence += 1
	var target := Vector2(4.25, 3.1)
	await click(runner, view, Iso.world_to_plane(target), MOUSE_BUTTON_RIGHT)
	var pending: Array = main.simulation.snapshot().pending_commands
	runner.check(pending.size() == sequence + 1, "S2 non-center command queued")
	if pending.size() > sequence:
		var point: Array = pending[sequence].target
		runner.check(Vector2(point[0], point[1]).distance_to(target) <= 1e-5, "S2 exact non-center target")
	main.free()
	return true

func test_rejection(runner) -> bool:
	var main = await setup(runner)
	var view = main.get_node("WorldView")
	await select(runner, main)
	await click(runner, view, Iso.world_to_plane(Vector2(4.5, 3.5)), MOUSE_BUTTON_RIGHT)
	main._physics_process(0.0)
	var active: Dictionary = main.simulation.snapshot()
	await click(runner, view, Iso.world_to_plane(Vector2(7.5, 6.5)), MOUSE_BUTTON_RIGHT)
	runner.check(main.simulation.snapshot() == active, "S3 rejected order preserves active destination and sequence")
	runner.check(main.get_node("HUD/Status").text.contains("Target"), "S3 HUD rejection reason")
	await click(runner, view, Iso.world_to_plane(Vector2(5.5, 3.5)), MOUSE_BUTTON_RIGHT)
	var queued: Dictionary = main.simulation.snapshot()
	runner.check(queued.pending_commands.size() == 1 and queued.pending_commands[0].sequence == 1, "S3 rejection did not consume sequence")
	runner.check(not main.get_node("HUD/Status").text.contains("Target"), "S3 accepted clears error")
	await click(runner, view, Iso.world_to_plane(Vector2(0.5, 0.5)), MOUSE_BUTTON_LEFT)
	runner.check(main.selected_ids == [], "S3 empty clears")
	await click(runner, view, Iso.world_to_plane(Vector2(4.5, 4.5)), MOUSE_BUTTON_RIGHT)
	runner.check(main.simulation.snapshot() == queued, "S3 unselected right no order")
	await select(runner, main)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await runner.process_frame
	escape.pressed = false
	Input.parse_input_event(escape)
	await runner.process_frame
	runner.check(main.selected_ids == [], "S3 escape clears")
	main.free()
	return true

func test_camera(runner) -> bool:
	var main = await setup(runner)
	var camera: Camera2D = main.get_node("Camera2D")
	var before: Dictionary = main.simulation.snapshot()
	camera.position = Vector2(0, 128)
	main.pan_camera(Vector2.RIGHT, 0.5)
	runner.check(camera.position == Vector2(200, 128), "S4 pan zoom one")
	camera.position = Vector2(0, 128)
	main.change_zoom(1)
	main.pan_camera(Vector2.RIGHT, 0.5)
	runner.check(camera.zoom == Vector2(2, 2) and camera.position == Vector2(100, 128), "S4 pan zoom two")
	camera.position = Vector2(0, 128)
	main.pan_camera(Vector2.ONE, 0.5)
	runner.check(camera.position.distance_to(Vector2(100 / sqrt(2.0), 128 + 100 / sqrt(2.0))) <= 1e-5, "S4 normalized diagonal on both axes")
	for i in range(4):
		main.change_zoom(1)
	runner.check(camera.zoom == Vector2(2, 2), "S4 max zoom")
	main.change_zoom(-1)
	runner.check(camera.zoom == Vector2.ONE, "S4 middle zoom")
	for i in range(4):
		main.change_zoom(-1)
	runner.check(camera.zoom == Vector2(0.5, 0.5), "S4 min zoom")
	main.pan_camera(Vector2.ONE, 100)
	runner.check(camera.position == Vector2(512, 512), "S4 positive pan bounds")
	main.pan_camera(-Vector2.ONE, 100)
	runner.check(camera.position == Vector2(-512, 0), "S4 negative pan bounds")
	runner.check(main.simulation.snapshot() == before, "S4 camera cannot change simulation")
	main.free()
	return true

func test_driver(runner) -> bool:
	var main = Main.instantiate()
	runner.root.add_child(main)
	var before: int = main.simulation.snapshot().tick
	await runner.physics_frame
	await runner.process_frame
	runner.check(main.simulation.snapshot().tick > before, "S5 live driver advances")
	main.set_physics_process(false)
	main.set_process(false)
	before = main.simulation.snapshot().tick
	main._physics_process(0.0)
	runner.check(main.simulation.snapshot().tick == before + 1, "S5 one callback one tick")
	main.free()
	return true

func _mouse(runner, _main, viewport_point: Vector2, button: MouseButton, pressed: bool, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = runner.root.get_final_transform() * viewport_point
	event.global_position = event.position
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	Input.parse_input_event(event)
	await runner.process_frame

func _motion(runner, viewport_point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = runner.root.get_final_transform() * viewport_point
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	await runner.process_frame

func _box(runner, main, from: Vector2, to: Vector2, shift: bool = false) -> void:
	var transform: Transform2D = main.get_node("WorldView").get_global_transform_with_canvas()
	await _mouse(runner, main, transform * from, MOUSE_BUTTON_LEFT, true, shift)
	await _motion(runner, transform * to)
	await _mouse(runner, main, transform * to, MOUSE_BUTTON_LEFT, false, shift)

func _key(runner, key: Key, physical: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		if physical:
			event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await runner.process_frame

func test_boxes(runner) -> bool:
	var main = await setup(runner)
	var camera: Camera2D = main.get_node("Camera2D")
	for center in [Vector2(0, 128), Vector2(80, 160)]:
		for zoom in [0.5, 1.0, 2.0]:
			camera.position = center
			camera.zoom = Vector2.ONE * zoom
			camera.force_update_scroll()
			await runner.process_frame
			for reverse in [false, true]:
				await _box(runner, main, Vector2(33, 81) if reverse else Vector2(-33, 47), Vector2(-33, 47) if reverse else Vector2(33, 81))
				runner.check(main.selected_ids == [1, 2, 6, 7], "S6 transformed/reverse box " + str([center, zoom, reverse]))
	await click(runner, main.get_node("WorldView"), Iso.world_to_plane(Vector2(5.5, 1.5)) + Vector2(0, -8), MOUSE_BUTTON_LEFT)
	await _box(runner, main, Vector2(-33, 47), Vector2(33, 81), true)
	await _box(runner, main, Vector2(-33, 47), Vector2(33, 81), true)
	runner.check(main.selected_ids == [1, 2, 5, 6, 7], "S6 Shift union sorted without duplicates")
	var transform: Transform2D = main.get_node("WorldView").get_global_transform_with_canvas()
	var empty: Vector2 = transform * Vector2(0, 0)
	await _mouse(runner, main, empty, MOUSE_BUTTON_LEFT, true, true)
	await _mouse(runner, main, empty, MOUSE_BUTTON_LEFT, false, true)
	runner.check(main.selected_ids == [1, 2, 5, 6, 7], "S6 Shift empty preserves")
	await click(runner, main.get_node("WorldView"), Iso.world_to_plane(Vector2(12.5, 12.5)), MOUSE_BUTTON_RIGHT)
	var pending: Array = main.simulation.snapshot().pending_commands
	runner.check(pending.size() == 1 and pending[0].entity_ids == [1, 2, 5, 6, 7], "S6 exactly one sorted group order")
	main.free()
	return true

func test_drag_rules(runner) -> bool:
	var main = await setup(runner)
	var camera: Camera2D = main.get_node("Camera2D")
	var transform: Transform2D = main.get_node("WorldView").get_global_transform_with_canvas()
	var point: Vector2 = transform * (Iso.world_to_plane(Vector2(1.5, 1.5)) + Vector2(0, -8))
	await _mouse(runner, main, point, MOUSE_BUTTON_LEFT, true)
	runner.check(main.selected_ids == [], "S7 selection waits for release")
	await _mouse(runner, main, point + Vector2(5, 0), MOUSE_BUTTON_LEFT, false)
	runner.check(main.selected_ids == [1], "S7 five-pixel excursion is click")
	await _mouse(runner, main, point, MOUSE_BUTTON_LEFT, true)
	await _motion(runner, point + Vector2(6, 0))
	var before: Vector2 = camera.position
	var zoom: Vector2 = camera.zoom
	main.pan_camera(Vector2.RIGHT, 0.5)
	main.change_zoom(1)
	runner.check(camera.position == before and camera.zoom == zoom, "S7 camera frozen during drag")
	await _mouse(runner, main, point, MOUSE_BUTTON_RIGHT, true)
	await _mouse(runner, main, point, MOUSE_BUTTON_RIGHT, false)
	runner.check(main.simulation.snapshot().pending_commands == [], "S7 right during drag ignored")
	await _mouse(runner, main, point + Vector2(5, 0), MOUSE_BUTTON_LEFT, false)
	runner.check(main.selected_ids == [], "S7 max excursion retains drag classification")
	await _mouse(runner, main, point, MOUSE_BUTTON_LEFT, true)
	await _motion(runner, point + Vector2(100, 100))
	await _key(runner, KEY_ESCAPE)
	await _mouse(runner, main, point + Vector2(100, 100), MOUSE_BUTTON_LEFT, false)
	runner.check(main.selected_ids == [] and not main.get_node("HUD/SelectionBox").visible, "S7 Escape cancels drag and later release")
	main.pan_camera(Vector2.RIGHT, 0.25)
	runner.check(camera.position != before, "S7 camera resumes after cancel")
	main.free()
	return true

func test_obstacle_toggle(runner) -> bool:
	var main = await setup(runner)
	await _key(runner, KEY_B, true)
	runner.check(main.simulation.snapshot().map.blocked_cells.size() == 24, "S8 B adds authored obstacle")
	await _key(runner, KEY_B, true)
	runner.check(main.simulation.snapshot().map.blocked_cells.size() == 18, "S8 B removes authored obstacle")
	var command := {"tick": 0, "player": 1, "sequence": 0, "type": "move", "entity_ids": [1], "target": [10.5, 5.5]}
	runner.check(main.simulation.issue_command(command).ok, "S8 move onto toggle cell")
	for i in range(250):
		main._physics_process(0.0)
	runner.check(main.simulation.snapshot().entities[0].position == [10.5, 5.5], "S8 occupied toggle setup")
	var before: Dictionary = main.simulation.snapshot()
	await _key(runner, KEY_B, true)
	runner.check(main.simulation.snapshot() == before and not main.get_node("HUD/Status").text.is_empty(), "S8 occupied toggle rejected")
	runner.check(main.get_node("HUD/Status").text.contains("Obstacle would cover a unit"), "S8 occupied toggle rejection reason")
	command.tick = main.simulation.snapshot().tick
	command.sequence = 1
	command.target = [10.5, 3.5]
	runner.check(main.simulation.issue_command(command).ok, "S8 vacate toggle cell")
	for i in range(100):
		main._physics_process(0.0)
	await _key(runner, KEY_B, true)
	runner.check(main.simulation.snapshot().map.blocked_cells.size() == 24, "S8 rejected toggle preserves next action")
	main.free()
	return true

func _double_click(runner, main, plane: Vector2, shift: bool = false, ctrl: bool = false, alt: bool = false) -> void:
	var point: Vector2 = main.get_node("WorldView").get_global_transform_with_canvas() * plane
	for double in [false, true]:
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = runner.root.get_final_transform() * point
			event.global_position = event.position
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.double_click = double and pressed
			event.shift_pressed = shift
			event.ctrl_pressed = ctrl
			event.alt_pressed = alt
			Input.parse_input_event(event)
			await runner.process_frame

func _double_fixture(runner) -> Dictionary:
	var main = await setup(runner)
	var sim = main.simulation
	var fixture := {"main": main, "tank": sim.spawn(1, Vector2(3.5, 6.5), "usa_tank"), "far": sim.spawn(1, Vector2(14.5, 14.5)), "enemy": sim.spawn(2, Vector2(2.5, 6.5))}
	sim._entities[20].container_id = 1
	var camera: Camera2D = main.get_node("Camera2D")
	camera.position = Vector2(0, 128)
	camera.zoom = Vector2.ONE * 2.0
	camera.force_update_scroll()
	main._refresh()
	await runner.process_frame
	return fixture

func _light_ids(skip: Array) -> Array[int]:
	var ids: Array[int] = []
	for id in range(1, 21):
		if not skip.has(id): ids.append(id)
	return ids

func test_double_click_same_kind_on_screen(runner) -> bool:
	var fixture: Dictionary = await _double_fixture(runner)
	var main = fixture.main
	runner.check(fixture.far != -1 and fixture.tank != -1 and fixture.enemy != -1, "G26 fixture spawned")
	await _double_click(runner, main, Iso.world_to_plane(Vector2(3.5, 1.5)) + Vector2(0, -8))
	runner.check(main.selected_ids == _light_ids([20]), "G26 double click picks visible own same kind, not tank, off-screen or passenger")
	main.free()
	return true

func test_double_click_alt_whole_map(runner) -> bool:
	var fixture: Dictionary = await _double_fixture(runner)
	var main = fixture.main
	await _double_click(runner, main, Iso.world_to_plane(Vector2(3.5, 1.5)) + Vector2(0, -8), false, false, true)
	var expected := _light_ids([20])
	expected.append(fixture.far)
	runner.check(main.selected_ids == expected, "G26 Alt double click spans the whole map")
	main.free()
	return true

func test_double_click_shift_keeps(runner) -> bool:
	var fixture: Dictionary = await _double_fixture(runner)
	var main = fixture.main
	await click(runner, main.get_node("WorldView"), Iso.world_to_plane(Vector2(3.5, 6.5)) + Vector2(0, -8), MOUSE_BUTTON_LEFT)
	runner.check(main.selected_ids == [fixture.tank], "G26 tank selected first")
	await _double_click(runner, main, Iso.world_to_plane(Vector2(3.5, 1.5)) + Vector2(0, -8), true)
	var expected := _light_ids([20])
	expected.append(fixture.tank)
	expected.sort()
	runner.check(main.selected_ids == expected, "G26 Shift double click keeps the earlier selection")
	main.free()
	return true

func test_double_click_ctrl_ignored(runner) -> bool:
	var fixture: Dictionary = await _double_fixture(runner)
	var main = fixture.main
	await _double_click(runner, main, Iso.world_to_plane(Vector2(3.5, 1.5)) + Vector2(0, -8), false, true)
	runner.check(main.selected_ids == [3], "G26 Ctrl double click is a plain click")
	main.free()
	return true

func test_double_click_enemy_or_ground_plain(runner) -> bool:
	var fixture: Dictionary = await _double_fixture(runner)
	var main = fixture.main
	await _double_click(runner, main, Iso.world_to_plane(Vector2(2.5, 6.5)) + Vector2(0, -8))
	runner.check(main.selected_ids == [], "G26 double click on an enemy selects nothing")
	await _double_click(runner, main, Iso.world_to_plane(Vector2(12.5, 12.5)))
	runner.check(main.selected_ids == [], "G26 double click on empty ground selects nothing")
	main.free()
	return true

extends RefCounted

const Main = preload("res://scenes/main.tscn")
const Iso = preload("res://scripts/presentation/isometric.gd")

func cases() -> Array[Callable]:
	return [test_ready, test_clicks, test_rejection, test_camera, test_driver]

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
	await click(runner, main.get_node("WorldView"), Iso.world_to_plane(Vector2(2.5, 2.5)) + Vector2(0, -8), MOUSE_BUTTON_LEFT)

func test_ready(runner) -> bool:
	var main = await setup(runner)
	var state: Dictionary = main.simulation.snapshot()
	runner.check(state.entities.size() == 1 and state.entities[0].owner == 1 and state.entities[0].position == [2.5, 2.5], "S1 one vehicle")
	runner.check(state.map.blocked_cells.size() == 18, "S1 static obstacle")
	runner.check(main.has_node("Camera2D") and main.has_node("WorldView") and main.has_node("HUD/Status"), "S1 scene nodes")
	runner.check(main.selected_id == -1, "S1 no selection")
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
			runner.check(main.selected_id == 1, "S2 transformed selection " + str([center, zoom]))
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
	runner.check(main.selected_id == -1, "S3 empty clears")
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
	runner.check(main.selected_id == -1, "S3 escape clears")
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

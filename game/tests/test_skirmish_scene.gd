extends RefCounted

const Scene = preload("res://scenes/skirmish.tscn")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const BaseScene = preload("res://tests/test_base_scene.gd")
const View = preload("res://scripts/presentation/world_view.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")

func cases() -> Array[Callable]:
	return [test_skirmish_ready_and_tick, test_combat_context_input, test_match_hud_and_restart, test_combat_view]

func _setup(runner):
	var main = Scene.instantiate()
	runner.root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await runner.process_frame
	return main

func _pending(main, type: String = "") -> int:
	return main.simulation.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return type.is_empty() or command.type == type).size()

func _arena(main) -> Dictionary:
	var sim = Skirmish.create(false)
	var ids := {"infantry": sim.spawn(1, Vector2(10.5, 10.5), "infantry"), "tank": sim.spawn(1, Vector2(11.5, 10.5), "tank"), "enemy": sim.spawn(2, Vector2(15.5, 10.5), "tank")}
	sim.start_match([1, 2] as Array[int])
	main.simulation = sim
	main.selected_ids.assign([ids.infantry, ids.tank])
	main._refresh()
	return ids

func test_skirmish_ready_and_tick(runner) -> bool:
	var main = await _setup(runner)
	for path in ["WorldView", "Camera2D", "HUD/Status", "HUD/Result", "HUD/Restart", "HUD/Economy/Produce"]:
		runner.check(main.has_node(path), "K2 node " + path)
	runner.check(main.simulation.snapshot() == Skirmish.create().snapshot(), "K2 exact scenario")
	main._physics_process(0.0)
	var state: Dictionary = main.simulation.snapshot()
	runner.check(state.tick == 1 and state.buildings.size() == 1 and state.buildings[0].owner == 2 and state.buildings[0].kind == "reactor", "K2 one physics callback is one tick and the opponent command is due on the pre-step tick")
	main._process(0.1)
	main._refresh()
	runner.check(main.simulation.snapshot().tick == 1, "K2 _process and _refresh never step")
	main.simulation.remove_object(1)
	main.simulation.remove_object(2)
	main._physics_process(0.0)
	var frozen: Dictionary = main.simulation.snapshot()
	main._physics_process(0.0)
	runner.check(frozen.match.status == "draw" and main.simulation.snapshot() == frozen, "K2 terminal match stays frozen")
	main.free()
	return true

func test_combat_context_input(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	var camera: Camera2D = main.get_node("Camera2D")
	var enemy_point: Vector2 = Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8)
	for center in [Vector2(0, 256), Vector2(80, 320)]:
		for zoom in [0.5, 1.0, 2.0]:
			camera.position = center
			camera.zoom = Vector2.ONE * zoom
			camera.force_update_scroll()
			await runner.process_frame
			var before: int = _pending(main)
			helper.pointer(main, enemy_point, MOUSE_BUTTON_RIGHT, true)
			runner.check(_pending(main) == before + 1 and _pending(main, "move") == 0, "K3 enemy right-click submits one attack at zoom " + str(zoom))
	var group: Array = main.simulation.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "attack")
	runner.check(group[0].entity_ids == [ids.infantry, ids.tank] and group[0].target_id == ids.enemy, "K3 mixed infantry and tank is one group command")
	main.selected_ids.assign([1, ids.infantry])
	var pending: int = _pending(main)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_RIGHT, true)
	runner.check(_pending(main) == pending and _pending(main, "move") == 0 and not main._error.is_empty(), "K3 an unarmed member rejects the whole click without a move")
	main.selected_ids.assign([ids.infantry, ids.tank])
	pending = _pending(main)
	helper.key(main, KEY_A)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, false)
	runner.check(_pending(main) == pending + 1 and _pending(main, "attack_move") == 1 and not main._attack_move_mode, "K3 A then ground click submits one attack_move")
	helper.key(main, KEY_S)
	runner.check(_pending(main, "stop") == 1, "K3 S submits one stop")
	pending = _pending(main)
	helper.key(main, KEY_A)
	runner.check(main._attack_move_mode, "K3 A enters attack-move mode")
	helper.key(main, KEY_ESCAPE)
	runner.check(not main._attack_move_mode and main.selected_ids == [ids.infantry, ids.tank], "K3 Escape cancels attack-move and keeps the selection")
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, false)
	runner.check(_pending(main) == pending, "K3 no attack-move after Escape")
	main.selected_ids.assign([ids.infantry, ids.tank])
	helper.key(main, KEY_A)
	runner.check(main._attack_move_mode, "K3 A re-enters attack-move mode")
	helper.pointer(main, enemy_point, MOUSE_BUTTON_RIGHT, true)
	runner.check(not main._attack_move_mode and _pending(main) == pending, "K3 right-click cancels attack-move without an attack")
	main.selected_ids.assign([ids.infantry, ids.tank])
	helper.key(main, KEY_A)
	main.selected_ids.assign([1])
	helper.key(main, KEY_1)
	runner.check(not main._attack_move_mode and main._placement_kind == "reactor", "K3 placement clears a stale attack-move mode")
	helper.key(main, KEY_ESCAPE)
	main.selected_ids.assign([1])
	main._refresh()
	helper.key(main, KEY_1)
	helper.key(main, KEY_A)
	runner.check(main._placement_kind == "reactor" and not main._attack_move_mode, "K3 placement mode consumes controls first")
	main.free()
	return true

func test_match_hud_and_restart(runner) -> bool:
	var main = await _setup(runner)
	runner.check(View.owner_color(1) != View.owner_color(2), "K4 owner colors differ")
	var ids: Dictionary = _arena(main)
	main.selected_ids.assign([ids.tank])
	main._refresh()
	var text: String = main.get_node("HUD/Status").text
	runner.check(text.contains("Credits") and text.contains("tank #" + str(ids.tank)) and text.contains("HP 480/480") and text.contains("guard"), "K4 credits, kind, HP and order in the HUD")
	main.simulation.remove_object(2)
	main._physics_process(0.0)
	runner.check(main.get_node("HUD/Result").text == "Victory" and main.get_node("HUD/Restart").visible, "K4 victory and restart button")
	var before: Dictionary = main.simulation.snapshot()
	main._submit({"type": "move", "entity_ids": [ids.tank], "target": [12.5, 12.5]})
	main._unhandled_input(InputEventKey.new())
	runner.check(main.simulation.snapshot() == before and main._error == "Match ended", "K4 terminal match accepts no orders")
	main._placement_kind = "reactor"
	main._attack_move_mode = true
	main._sequence = 7
	main._error = "old"
	main._last_result_tick = 99
	main._last_result_sequence = 99
	main._selecting = true
	main._dragged = true
	main.get_node("Camera2D").position = Vector2(500, 500)
	main.get_node("Camera2D").zoom = Vector2.ONE * 2.0
	main.get_node("HUD/Restart").pressed.emit()
	runner.check(main.simulation.snapshot() == Skirmish.create().snapshot() and main.selected_ids.is_empty() and main._placement_kind.is_empty() and not main._attack_move_mode and main._sequence == 0 and main._error.is_empty() and main.get_node("Camera2D").zoom == Vector2.ONE and not main.get_node("HUD/Result").visible and main._last_result_tick == -1 and main._last_result_sequence == -1 and not main._selecting and not main._dragged and main.get_node("Camera2D").position != Vector2(500, 500) and main.get_node("WorldView")._preview_cells.is_empty(), "K4 restart leaves nothing from the old match")
	main.selected_ids.assign([1])
	main._submit({"type": "move", "entity_ids": [1], "target": [6.5, 14.5]})
	runner.check(main._error.is_empty() and _pending(main, "move") == 1, "K4 first order after restart is valid")
	for loser in [[1, "Defeat"], [-1, "Draw"]]:
		var other = await _setup(runner)
		if loser[0] == 1:
			other.simulation.remove_object(1)
		else:
			other.simulation.remove_object(1)
			other.simulation.remove_object(2)
		other._physics_process(0.0)
		runner.check(other.get_node("HUD/Result").text == loser[1], "K4 " + loser[1])
		other.free()
	main.free()
	return true

func test_combat_view(runner) -> bool:
	var main = await _setup(runner)
	var view = main.get_node("WorldView")
	var sim = Skirmish.create(false)
	var shooter: int = sim.spawn(1, Vector2(10.5, 10.5), "tank")
	var victim: int = sim.spawn(2, Vector2(14.5, 10.5), "tank")
	var historical: Dictionary = sim.snapshot()
	for unit in historical.entities:
		unit.erase("hp")
		unit.erase("max_hp")
		unit.erase("combat")
	historical.erase("combat_events")
	historical.erase("match")
	var none: Array[int] = []
	view.set_state(historical, none)
	await runner.process_frame
	runner.check(view.pick_target(Iso.world_to_plane(Vector2(14.5, 10.5)) + Vector2(0, -8), 1) == victim, "V1 historical snapshot tolerated and enemy picked")
	sim.step()
	var live: Dictionary = sim.snapshot()
	var copy: Dictionary = live.duplicate(true)
	view.set_state(live, none)
	await runner.process_frame
	runner.check(live == copy and view._last_points.has(shooter) and view._last_points.has(victim), "V1 cues are read-only and use last events")
	sim.remove_object(victim)
	var gone: Dictionary = sim.snapshot()
	gone.combat_events = [{"type": "death", "tick": 1, "object_id": victim}]
	view.set_state(gone, none)
	await runner.process_frame
	runner.check(view._last_points.has(victim), "V1 death cue keeps the last known point")
	runner.check(View.hp_fraction(-5, 100) == 0.0 and View.hp_fraction(500, 100) == 1.0 and View.hp_fraction(50, 100) == 0.5 and View.hp_fraction(1, 0) == 1.0, "V1 HP fill clamped 0..1")
	main.free()
	return true

@warning_ignore_start("untyped_declaration")
extends RefCounted

const Scene = preload("res://scenes/skirmish.tscn")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const BaseScene = preload("res://tests/test_base_scene.gd")
const View = preload("res://scripts/presentation/world_view.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const UiStyle = preload("res://scripts/presentation/ui_style.gd")
const ViewRows = preload("res://tests/test_view_rows.gd")

func cases() -> Array[Callable]:
	return [test_skirmish_ready_and_tick, test_combat_context_input, test_match_hud_and_restart, test_combat_view, test_hud_layout_and_focus, test_hud_build_line, test_enemy_selection_read_only, test_rally_input_and_marker, test_supply_pile_labels, test_attack_move_hint_and_rejection, test_selection_prunes_dead, test_order_marks_own_only, test_health_bar_clear_of_boxes, test_result_clear_of_status, test_silent_keys_explain, test_hud_strings_use_display_names, test_hud_font_size_is_shared, test_defence_attack_scene, test_enter_unload_scene, test_right_click_pile_gathers, test_right_click_pile_in_launcher_flow, test_frc_laborer_right_click_pile, test_one_snapshot_per_refresh, test_refresh_waits_for_next_frame, test_auto_pick_samples_present_time, test_hud_summaries_are_pinned]

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
	var ids := {"infantry": sim.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry"), "tank": sim.spawn(1, Vector2(11.5, 10.5), "usa_tank"), "enemy": sim.spawn(2, Vector2(15.5, 10.5), "usa_tank")}
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
	runner.check(state.tick == 1 and state.buildings.size() == 3 and state.buildings[2].owner == 2 and state.buildings[2].kind == "usa_power_plant", "K2 one physics callback is one tick and the opponent command is due on the pre-step tick")
	main._process(0.1)
	main._refresh()
	runner.check(main.simulation.snapshot().tick == 1, "K2 _process and _refresh never step")
	for building: Dictionary in main.simulation.snapshot().buildings: main.simulation.remove_object(building.id)
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
	runner.check(_pending(main) == pending + 1 and _pending(main, "move") == 0 and main._error.is_empty(), "K3 an unarmed member no longer rejects the click")
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
	runner.check(not main._attack_move_mode and main._placement_kind == "usa_power_plant", "K3 placement clears a stale attack-move mode")
	helper.key(main, KEY_ESCAPE)
	main.selected_ids.assign([1])
	main._refresh()
	helper.key(main, KEY_1)
	helper.key(main, KEY_A)
	runner.check(main._placement_kind == "usa_power_plant" and not main._attack_move_mode, "K3 placement mode consumes controls first")
	main.free()
	return true

func test_match_hud_and_restart(runner) -> bool:
	var main = await _setup(runner)
	runner.check(View.owner_color(1) != View.owner_color(2), "K4 owner colors differ")
	var ids: Dictionary = _arena(main)
	main.selected_ids.assign([ids.tank])
	main._refresh()
	var text: String = main.get_node("HUD/Status").text
	runner.check(text.contains("Credits") and text.contains("Battle Tank #" + str(ids.tank)) and text.contains("HP 480/480") and text.contains("guard"), "K4 credits, kind, HP and order in the HUD")
	var setup: Dictionary = main.simulation.view_state()
	setup.match.status = "setup"
	main._refresh_hud(setup)
	runner.check(main.get_node("HUD/Result").text.is_empty() and not main.get_node("HUD/Restart").visible, "K4 the setup phase shows no result")
	main.simulation.remove_object(3)
	main.simulation.remove_object(4)
	main._physics_process(0.0)
	runner.check(main.get_node("HUD/Result").text == "Victory" and main.get_node("HUD/Restart").visible, "K4 victory and restart button")
	main.simulation._players[main.local_player].team = 7
	runner.check(main._result_text({"status": "won", "winner": 7}) == "Victory" and main._result_text({"status": "won", "winner": main.local_player}) == "Defeat", "K4 result compares the winning team id with the local team")
	var before: Dictionary = main.simulation.snapshot()
	main._submit({"type": "move", "entity_ids": [ids.tank], "target": [12.5, 12.5]})
	main._unhandled_input(InputEventKey.new())
	runner.check(main.simulation.snapshot() == before and main._error == "Match ended", "K4 terminal match accepts no orders")
	main._placement_kind = "usa_power_plant"
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
			other.simulation.remove_object(2)
		else:
			other.simulation.remove_object(2)
			other.simulation.remove_object(3)
			other.simulation.remove_object(4)
		other._physics_process(0.0)
		runner.check(other.get_node("HUD/Result").text == loser[1], "K4 " + loser[1])
		other.free()
	main.free()
	return true

func test_combat_view(runner) -> bool:
	var main = await _setup(runner)
	var view = main.get_node("WorldView")
	var sim = Skirmish.create(false)
	sim.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	var victim: int = sim.spawn(2, Vector2(14.5, 10.5), "usa_tank")
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
	runner.check(live == copy, "V1 cues are read-only")
	runner.check(View.hp_fraction(-5, 100) == 0.0 and View.hp_fraction(500, 100) == 1.0 and View.hp_fraction(50, 100) == 0.5 and View.hp_fraction(1, 0) == 1.0, "V1 HP fill clamped 0..1")
	main.free()
	return true

func test_hud_layout_and_focus(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main.selected_ids.assign([ids.tank])
	main._refresh()
	var status: Label = main.get_node("HUD/Status")
	var economy: Control = main.get_node("HUD/Economy")
	runner.check(economy.position.y >= status.position.y + status.get_minimum_size().y, "K5 buttons sit below every status line")
	var view = main.get_node("WorldView")
	runner.check(view.focus_targets().is_empty(), "K5 no focus before an order")
	main._unhandled_input(_right_click(main, Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8)))
	main._physics_process(0.0)
	runner.check(view.focus_targets() == {ids.enemy: true}, "K5 explicit attack target is marked strongly, got " + str(view.focus_targets()))
	main.selected_ids.clear()
	main._refresh()
	runner.check(view.focus_targets().is_empty(), "K5 focus shows only for the selection")
	main.inspected_id = ids.enemy
	main._refresh()
	runner.check(economy.position.y >= status.position.y + status.get_minimum_size().y, "K5 buttons below an inspected enemy line")
	var pile: Dictionary = _pile_world(main)
	main.selected_ids.assign([pile.waiting])
	main._refresh()
	runner.check(economy.position.y >= status.position.y + status.get_minimum_size().y, "K5 buttons below a queued collector line")
	main.free()
	return true

func _pile_world(main) -> Dictionary:
	var sim = Skirmish.create(false)
	var source: int = sim.add_supply_source(Vector2i(8, 8), 10)
	var first: int = sim.spawn(1, Vector2(10.0, 10.5), "usa_collector")
	var second: int = sim.spawn(1, Vector2(10.0, 10.5), "usa_collector")
	Fixture.send(sim, {"type": "gather", "entity_ids": [first, second], "source_id": source})
	Fixture.steps(sim, 19)
	sim.start_match([1, 2] as Array[int])
	main.simulation = sim
	main.selected_ids.clear()
	main._refresh()
	return {"source": source, "docked": first, "waiting": second}

func test_hud_build_line(runner) -> bool:
	var main = await _setup(runner)
	var text: String = main.get_node("HUD/Status").text
	runner.check(text.contains("1-9: menu") and text.contains("U: unload") and not text.contains("1/2/3"), "H1 skirmish build line, got " + text)
	var base_helper = BaseScene.new()
	var base = await base_helper.setup(runner)
	var base_text: String = base.get_node("HUD/Status").text
	runner.check(base_text.contains("1-9: menu") and base_text.contains("U: unload") and not base_text.contains("1/2/3"), "H1 base scene shares the menu hint")
	base.free()
	main.free()
	return true

func test_enemy_selection_read_only(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	var enemy_point: Vector2 = Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_LEFT, false)
	var text: String = main.get_node("HUD/Status").text
	runner.check(main.inspected_id == ids.enemy and main.selected_ids.is_empty(), "E1 left-click selects the enemy read-only and replaces own selection")
	runner.check(text.contains("Enemy (P2) Battle Tank #%d HP 480/480" % ids.enemy), "E1 enemy line, got " + text)
	runner.check(text.contains("HP 480/480 | guard"), "E1 idle enemy shows its mode, got " + text)
	var before: Dictionary = main.simulation.snapshot()
	helper.key(main, KEY_E)
	helper.key(main, KEY_A)
	helper.key(main, KEY_S)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_RIGHT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_RIGHT, true)
	runner.check(main.simulation.snapshot() == before and not main._attack_move_mode and main.inspected_id == ids.enemy, "E1 E, A, S and right-clicks send nothing")
	var own_point: Vector2 = Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8)
	helper.pointer(main, own_point, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, own_point, MOUSE_BUTTON_LEFT, false)
	runner.check(main.selected_ids == [ids.infantry] and main.inspected_id == -1, "E1 own click selects own unit and clears inspection")
	helper.pointer(main, enemy_point, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_LEFT, false)
	main.simulation.remove_object(ids.enemy)
	main._refresh()
	runner.check(main.inspected_id == -1, "E1 dead enemy clears inspection")
	main.free()
	return true

func test_rally_input_and_marker(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	main.simulation = sim
	main.selected_ids.clear()
	main._refresh()
	var view = main.get_node("WorldView")
	runner.check(view.rally_marker().is_empty(), "R1 no marker without a selection")
	var click: Vector2 = Iso.world_to_plane(Vector2(13.5, 13.5))
	helper.pointer(main, click, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, click, MOUSE_BUTTON_LEFT, false)
	runner.check(main.selected_building_id == barracks and view.rally_marker() == [16.5, 13.5], "R1 marker shows the default rally while selected")
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 14.5)), MOUSE_BUTTON_RIGHT, true)
	var orders: Array = sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "set_rally")
	runner.check(orders.size() == 1 and orders[0].building_id == barracks and orders[0].target == [20.5, 14.5], "R1 right-click on ground issues set_rally for that cell")
	main._physics_process(0.0)
	runner.check(view.rally_marker() == [20.5, 14.5], "R1 marker follows the new rally")
	helper.key(main, KEY_ESCAPE)
	runner.check(view.rally_marker().is_empty(), "R1 marker absent when deselected")
	var reactor: int = Fixture.build(runner, sim, "usa_power_plant", Vector2i(20, 20))
	main.selected_building_id = reactor
	main.selected_ids.assign([reactor])
	main._refresh()
	runner.check(view.rally_marker().is_empty(), "R1 no marker for a reactor, which cannot take a rally")
	main.free()
	return true

func test_supply_pile_labels(runner) -> bool:
	var main = await _setup(runner)
	var pile: Dictionary = _pile_world(main)
	var view = main.get_node("WorldView")
	var source: Dictionary = Fixture.object(main.simulation, pile.source)
	runner.check(Fixture.object(main.simulation, pile.docked).collection.phase in ["loading"] and Fixture.object(main.simulation, pile.waiting).collection.phase == "waiting_source", "S1 fixture: one collector docked, one waiting")
	runner.check(view.pile_lines(source) == PackedStringArray(["Boxes %d" % source.boxes, "docked 1 · waiting 1"]), "S1 pile label, got " + str(view.pile_lines(source)))
	var points: PackedVector2Array = view.pile_text_points(source)
	runner.check(points.size() == 2 and points[1].y - points[0].y >= ThemeDB.fallback_font.get_height(UiStyle.FONT_SIZE), "S1 pile lines are a full text height apart, got " + str(points))
	main.selected_ids.assign([pile.waiting])
	main._refresh()
	runner.check(main.get_node("HUD/Status").text.contains("waiting_source (1st in line)"), "S1 waiting collector shows its place in line")
	main.selected_ids.assign([pile.docked])
	main._refresh()
	var text: String = main.get_node("HUD/Status").text
	runner.check(text.contains("| loading") and not text.contains("in line"), "S1 docked collector shows its phase only")
	main.free()
	return true

func _right_click(main, plane: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = main.get_node("WorldView").get_global_transform_with_canvas() * plane
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	return event

func test_attack_move_hint_and_rejection(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	var view = main.get_node("WorldView")
	helper.key(main, KEY_A)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, false)
	runner.check(view.hints().size() == 1, "H3 attack-move click leaves one hint")
	main.selected_ids.assign([ids.infantry])
	var before: int = view.hints().size()
	main.simulation.remove_object(ids.infantry)
	helper.pointer(main, Iso.world_to_plane(Vector2(8.5, 8.5)), MOUSE_BUTTON_RIGHT, true)
	runner.check(view.hints().size() == before, "H3 a second command replaces the marker, still one")
	main.selected_ids.clear()
	view.add_hint(Vector2(1, 1), 0)
	helper.pointer(main, Iso.world_to_plane(Vector2(9.5, 9.5)), MOUSE_BUTTON_RIGHT, true)
	runner.check(view.hints().size() == 1 and view.hints()[0].point == Vector2(1, 1), "H3 a right click with no movable selection adds no marker")
	main.free()
	return true

func test_selection_prunes_dead(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main.simulation.remove_object(ids.tank)
	main._refresh()
	runner.check(main.selected_ids == [ids.infantry], "H4 selection keeps only live ids, got " + str(main.selected_ids))
	main.free()
	return true

func test_order_marks_own_only(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	Fixture.send(main.simulation, {"type": "move", "entity_ids": [ids.tank], "target": [12.5, 14.5]})
	Fixture.send(main.simulation, {"type": "move", "player": 2, "entity_ids": [ids.enemy], "target": [16.5, 14.5]})
	Fixture.steps(main.simulation, 2)
	main._refresh()
	runner.check(main.get_node("WorldView").order_marks().is_empty(), "P1 order crosses are hidden by default")
	main.get_node("WorldView").set_show_destinations(true)
	var marks: Array[Vector2] = main.get_node("WorldView").order_marks()
	runner.check(marks == [Iso.world_to_plane(Vector2(12.5, 14.5))], "P1 only the local player's order shows a cross, got " + str(marks))
	main.free()
	return true

func test_health_bar_clear_of_boxes(runner) -> bool:
	var view = View.new()
	for half in [6.0, 15.0]:
		var bounds := Rect2(Vector2(100, 100), Vector2(half * 2.0, 16))
		runner.check(not view.health_rect(bounds).intersects(bounds.grow(4.0 + 1.5)), "P2 health bar clear of the focus box at half width %s" % half)
	view.free()
	return true

func test_result_clear_of_status(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main.selected_ids.assign([ids.tank])
	main.inspected_id = ids.enemy
	main.simulation.remove_object(3)
	main.simulation.remove_object(4)
	main._physics_process(0.0)
	await runner.process_frame
	await runner.process_frame
	var status: Rect2 = main.get_node("HUD/Status").get_global_rect()
	for path in ["HUD/Result", "HUD/Restart"]:
		var rect: Rect2 = main.get_node(path).get_global_rect()
		runner.check(main.get_node(path).visible and rect.position.y >= status.end.y, "P3 %s sits below the status text at any width, %s vs %s" % [path, rect, status])
	main.free()
	return true

func test_silent_keys_explain(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main.selected_ids.assign([ids.infantry])
	var before: Dictionary = main.simulation.snapshot()
	helper.key(main, KEY_1)
	runner.check(main._placement_kind.is_empty() and main.simulation.snapshot() == before and main._error == "Choose one builder", "P4 build key without a builder says why, got '%s'" % main._error)
	main._error = ""
	main.selected_ids.clear()
	helper.key(main, KEY_E)
	runner.check(main.simulation.snapshot() == before and main._error == "Select a production building", "P4 E without a building says why, got '%s'" % main._error)
	main.free()
	return true

func _hud_texts(main) -> Array[String]:
	var texts: Array[String] = [main.get_node("HUD/Status").text, main.get_node("HUD/Economy/Produce").text, main.get_node("HUD/Economy/CancelBuild").text]
	for group: String in ["BuildMenu", "Queue"]:
		for button in main.get_node("HUD/Economy/" + group).get_children(): texts.append(button.text)
	return texts

func test_hud_strings_use_display_names(runner) -> bool:
	var main = await _setup(runner)
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	main.simulation = sim
	main.selected_building_id = barracks
	main._produce_selected()
	main._produce_selected()
	main._physics_process(0.0)
	await runner.process_frame
	runner.check(main.get_node("HUD/Economy/Produce").text == "Produce Rifleman (E)", "N1 produce button names the unit, got " + main.get_node("HUD/Economy/Produce").text)
	runner.check(main.get_node("HUD/Economy/Queue").get_child_count() == 2, "N1 fixture: two queue entries")
	var shown: Array[String] = _hud_texts(main)
	var builder: int = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 1 and unit.kind == "usa_builder")[0].id
	main.selected_building_id = -1
	main.selected_ids.assign([builder])
	main._enter_placement("usa_power_plant")
	runner.check(main.get_node("HUD/Status").text.contains("Place: Power Plant"), "N1 placement line names the building")
	shown.append_array(_hud_texts(main))
	main._clear_placement()
	var enemy: Dictionary = sim.snapshot().buildings.filter(func(building: Dictionary) -> bool: return building.owner == 2)[0]
	main.inspected_id = enemy.id
	main._refresh()
	shown.append_array(_hud_texts(main))
	main.selected_building_id = sim.snapshot().buildings.filter(func(building: Dictionary) -> bool: return building.owner == 1 and building.kind == "usa_command_center")[0].id
	main._refresh()
	shown.append_array(_hud_texts(main))
	await runner.process_frame
	for text in shown: runner.check(not text.contains("usa_"), "N1 no raw kind id in HUD text: " + text)
	main.free()
	return true

func test_hud_font_size_is_shared(runner) -> bool:
	var main = await _setup(runner)
	var barracks: int = Fixture.build(runner, main.simulation, "usa_barracks", Vector2i(12, 12))
	main.selected_building_id = barracks
	main._produce_selected()
	main._physics_process(0.0)
	await runner.process_frame
	var controls: Array = [main.get_node("HUD/Status"), main.get_node("HUD/Economy/Produce"), main.get_node("HUD/Economy/CancelBuild")]
	controls.append_array(main.get_node("HUD/Economy/BuildMenu").get_children())
	controls.append_array(main.get_node("HUD/Economy/Queue").get_children())
	runner.check(controls.size() >= 4, "FS1 fixture: status, buttons and a queue entry")
	for control in controls: runner.check(control.get_theme_font_size("font_size") == UiStyle.FONT_SIZE, "FS1 %s uses the shared HUD size" % control.name)
	runner.check(UiStyle.FONT_SIZE < 16, "FS1 HUD text is smaller than the engine default")
	main.free()
	return true

func test_defence_attack_scene(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var sim = Skirmish.create(false)
	var defence: int = Fixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	var enemy: int = sim.spawn(2, Vector2(15.5, 10.5), "usa_tank")
	var distant: int = sim.spawn(2, Vector2(30.5, 30.5), "usa_tank")
	sim.start_match([1, 2] as Array[int])
	main.simulation = sim
	main.selected_ids.clear()
	main.selected_building_id = defence
	main._refresh()
	helper.pointer(main, Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
	var orders: Array = sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "defence_attack")
	runner.check(orders.size() == 1 and orders[0].building_id == defence and orders[0].target_id == enemy and main._error.is_empty(), "DA5 right-click on an enemy in reach submits defence_attack")
	helper.pointer(main, Iso.world_to_plane(Vector2(30.5, 30.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
	runner.check(main._error == "Target out of range" and sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "defence_attack").size() == 1, "DA5 out of reach shows Target out of range, got " + main._error + " " + str(distant))
	main.free()
	return true

func test_enter_unload_scene(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var sim = Skirmish.create(false)
	var hub: int = Fixture.add_completed(sim, 1, "frc_defence", Vector2i(10, 10))
	var enemy_hub: int = Fixture.add_completed(sim, 2, "frc_defence", Vector2i(20, 10))
	var rifle: int = sim.spawn(1, Vector2(14.5, 10.5), "frc_rifle_infantry")
	sim.start_match([1, 2] as Array[int])
	main.simulation = sim
	main.selected_ids.assign([rifle])
	main._refresh()
	var orders = func(type: String) -> Array: return sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == type)
	helper.pointer(main, Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
	var enters: Array = orders.call("enter")
	runner.check(enters.size() == 1 and enters[0].entity_ids == [rifle] and enters[0].target_id == hub and main._error.is_empty(), "TU1 right-click on an own hub submits enter")
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 10.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
	var attacks: Array = orders.call("attack")
	runner.check(attacks.size() == 1 and attacks[0].target_id == enemy_hub and orders.call("enter").size() == 1, "TU1 right-click on an enemy hub still attacks")
	main.selected_ids.clear()
	main.selected_building_id = hub
	main._refresh()
	helper.key(main, KEY_U)
	var unloads: Array = orders.call("unload")
	runner.check(unloads.size() == 1 and unloads[0].target_id == hub, "TU1 U with the hub selected submits unload")
	main.selected_building_id = -1
	main.selected_ids.assign([rifle])
	main._refresh()
	helper.key(main, KEY_U)
	runner.check(orders.call("unload").size() == 1 and main._error == "Select a container", "TU1 U without a container says why, got '%s'" % main._error)
	var hub_point: Vector2 = Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8)
	sim._entities[rifle].container_id = hub
	sim._entities[rifle].position = [10.5, 10.5]
	main._refresh()
	runner.check(main._view.pick_object(hub_point) == hub, "TU1 clicking an occupied hub picks the hub, not an occupant")
	var status: Label = main.get_node("HUD/Status")
	runner.check(Rect2(status.global_position, status.get_minimum_size()).end.x <= main.get_viewport().get_visible_rect().size.x, "TU1 the hint line keeps the status inside the viewport")
	main.free()
	return true

func test_right_click_pile_gathers(runner) -> bool:
	var helper = BaseScene.new()
	for kind in ["usa_collector", "china_collector", "frc_builder"]:
		var main = await _setup(runner)
		var sim = Skirmish.create(false)
		var pile: int = sim.add_supply_source(Vector2i(20, 8), 10)
		var unit: int = sim.spawn(1, Vector2(15.5, 9.5), kind)
		sim.start_match([1, 2] as Array[int])
		main.simulation = sim
		main.selected_ids.assign([unit])
		main._refresh()
		helper.pointer(main, Iso.world_to_plane(Vector2(21.5, 9.5)), MOUSE_BUTTON_RIGHT, true)
		var orders: Array = sim.snapshot().pending_commands
		runner.check(orders.size() == 1 and orders[0].type == "gather" and orders[0].source_id == pile and orders[0].entity_ids == [unit], "K10 right-click on a pile sends %s to gather" % kind)
		main.free()
	return true

func test_right_click_pile_in_launcher_flow(runner) -> bool:
	var helper = BaseScene.new()
	for faction in ["frc", "china", "usa"]:
		var main = await _setup(runner)
		var sim = Skirmish.create(true, "ai", {1: faction, 2: "usa"})
		main.simulation = sim
		var pile: Dictionary = sim.snapshot().sources[0]
		var collector: int = sim.spawn(1, Vector2(pile.origin[0] + 6.5, pile.origin[1] + 8.5), faction + ("_builder" if faction == "frc" else "_collector"))
		var centre := Vector2(pile.origin[0] + 2.0, pile.origin[1] + 2.5)
		main.selected_ids.assign([collector])
		main._refresh()
		helper.pointer(main, Iso.world_to_plane(centre), MOUSE_BUTTON_RIGHT, true)
		runner.check(_pending(main, "gather") == 1, "K11 %s collector right-click on the pile gathers, pending %s" % [faction, str(sim.snapshot().pending_commands)])
		var bystander: int = sim.spawn(1, centre, "usa_collector")
		var gathers: int = _pending(main, "gather")
		main._refresh()
		helper.pointer(main, Iso.world_to_plane(centre) + Vector2(0, -26), MOUSE_BUTTON_RIGHT, true)
		runner.check(_pending(main, "gather") == gathers + 1 and bystander > 0, "K12 %s right-click on a pile with an own helicopter hovering over it still gathers, pending %s err %s" % [faction, str(sim.snapshot().pending_commands.map(func(c: Dictionary) -> String: return c.type)), main._error])
		main.free()
	return true

func test_frc_laborer_right_click_pile(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var sim = Skirmish.create(true, "ai", {1: "frc", 2: "usa"})
	main.simulation = sim
	var pile: Dictionary = sim.snapshot().sources[0]
	var click: Vector2 = Iso.world_to_plane(Vector2(pile.origin[0] + 2.0, pile.origin[1] + 2.5))
	var laborers: Array[int] = []
	for unit: Dictionary in sim.snapshot().entities:
		if unit.owner == 1: laborers.append(unit.id)
	laborers.append(sim.spawn(1, Vector2(pile.origin[0] + 6.5, pile.origin[1] + 8.5), "frc_builder"))
	var site: Dictionary = Fixture.send(sim, {"type": "build", "builder_id": laborers[1], "building_kind": "frc_barracks", "origin": [pile.origin[0] + 8, pile.origin[1] + 8]})
	runner.check(site.ok, "K13 foundation for the laborer: " + site.error)
	Fixture.steps(sim, 40)
	main.selected_ids.assign(laborers)
	main._refresh()
	helper.pointer(main, click, MOUSE_BUTTON_RIGHT, true)
	var orders: Array = sim.snapshot().pending_commands.filter(func(c: Dictionary) -> bool: return c.type == "gather")
	runner.check(orders.size() == 1 and orders[0].entity_ids == laborers and orders[0].source_id == pile.id, "K13 several laborers, one of them building, right-click the pile gathers, got %s err %s" % [str(sim.snapshot().pending_commands), main._error])
	Fixture.steps(sim, 3)
	runner.check(sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.id in laborers and u.collection.enabled).size() == laborers.size(), "K13 every laborer, including the builder, starts collecting")
	main.selected_ids.assign([laborers[0]])
	main._refresh()
	helper.key(main, KEY_1)
	var ghost: String = main._placement_kind
	helper.pointer(main, click, MOUSE_BUTTON_RIGHT, true)
	var gathers: int = _pending(main, "gather")
	runner.check(not ghost.is_empty() and main._placement_kind.is_empty(), "K13 right-click with a build ghost cancels the ghost, ghost was " + ghost)
	helper.pointer(main, click, MOUSE_BUTTON_RIGHT, true)
	runner.check(_pending(main, "gather") == gathers + 1, "K13 the next right-click on the pile gathers")
	main.free()
	return true

func test_one_snapshot_per_refresh(runner) -> bool:
	var main = await _setup(runner)
	var sim = Skirmish.create()
	main.simulation = sim
	main.selected_building_id = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	Profiler.reset()
	Profiler.enabled = true
	main._refresh()
	var snapshots: int = Profiler.calls(&"snapshot")
	var views: int = Profiler.calls(&"view_state")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(snapshots == 0 and views == 1, "RF2 a skirmish refresh with a production building selected takes no snapshot and one view state, got %d and %d" % [snapshots, views])
	runner.check(main.get_node("HUD/Economy/Produce").text == "Produce Rifleman (E)", "RF2 produce label unchanged")
	main.free()
	return true

func test_refresh_waits_for_next_frame(runner) -> bool:
	var main = await _setup(runner)
	main.set_process(true)
	await runner.process_frame
	main._physics_process(0.0)
	runner.check(main.simulation.tick() == 1 and main._view._state.tick == 0, "RF3 a step does not refresh in its own frame")
	await runner.process_frame
	runner.check(main._view._state.tick == 0, "RF3 still not refreshed before the frame's _process")
	await runner.process_frame
	runner.check(main._view._state.tick == 1, "RF3 the next frame's _process refreshes")
	main.free()
	return true

func test_auto_pick_samples_present_time(runner) -> bool:
	var main = await _setup(runner)
	main._start_auto_pick(true)
	main._auto_frame = main.AUTO_SKIP_FRAMES
	main.set_process(true)
	await runner.process_frame
	main._physics_process(0.0)
	main.set_process(false)
	await runner.process_frame
	main._auto_tick_usec = 0
	main._view.draw_usec = 0
	main._auto_samples.clear()
	main._process(0.0)
	main._start_auto_pick(false)
	runner.check(main._auto_samples.size() == 1 and main._auto_samples[0] > 0.0, "RF4 the automatic quality sample includes the time of the frame's present")
	main.free()
	return true

const HUD_TEXTS: Array[String] = ["Rifleman #50 HP 156/180 | attack -> #31\n", "Supply Helicopter #45 HP 300/300 | waiting_source (3rd in line)\n", "Supply Helicopter #11 HP 300/300 | unloading\n", "Bulldozer #1 HP 250/250\n", "Enemy (P2) Rifleman #20 HP 180/180 | guard\n", "Enemy (P2) Headquarters #4 HP 5000/5000\n"]

func _ids_where(units: Array, test: Callable) -> Array[int]:
	var ids: Array[int] = []
	for unit: Dictionary in units:
		if test.call(unit): ids.append(unit.id)
	return ids

func test_hud_summaries_are_pinned(runner) -> bool:
	var main = await _setup(runner)
	var sim = ViewRows.skirmish_sim()
	main.simulation = sim
	var state: Dictionary = sim.snapshot()
	var own: Array = state.entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 1)
	var waiting: Array[int] = _ids_where(own, func(unit: Dictionary) -> bool: return unit.collection != null and unit.collection.phase.begins_with("waiting_"))
	var working: Array[int] = _ids_where(own, func(unit: Dictionary) -> bool: return unit.collection != null and unit.collection.enabled and not unit.collection.phase.begins_with("waiting_"))
	var firing: Array[int] = _ids_where(own, func(unit: Dictionary) -> bool: return unit.combat != null and unit.combat.target_id != null)
	var plain: Array[int] = _ids_where(own, func(unit: Dictionary) -> bool: return unit.combat == null and unit.collection == null)
	var enemy_unit: Array[int] = _ids_where(state.entities, func(unit: Dictionary) -> bool: return unit.owner == 2 and unit.combat != null)
	var enemy_building: Array[int] = _ids_where(state.buildings, func(building: Dictionary) -> bool: return building.owner == 2)
	runner.check(waiting.size() >= 2 and not working.is_empty() and not firing.is_empty() and not plain.is_empty() and not enemy_unit.is_empty() and not enemy_building.is_empty(), "HUD1 fixture: every case has its unit")
	var view: Dictionary = sim.view_state()
	var texts: Array[String] = []
	for id: int in [firing[0], waiting[-1], working[0], plain[0]]:
		main.selected_ids.assign([id])
		texts.append(main._selected_summary(view))
	main.selected_ids.clear()
	for id: int in [enemy_unit[0], enemy_building[0]]:
		main.inspected_id = id
		texts.append(main._enemy_summary(view))
	runner.check(texts == HUD_TEXTS, "HUD1 pinned summary texts, got " + str(texts))
	main.free()
	return true

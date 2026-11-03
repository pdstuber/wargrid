extends "res://scripts/base_main.gd"

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
var _attack_move_mode: bool = false

func _ready() -> void:
	super._ready()
	$HUD/Restart.pressed.connect(_restart)

func _create_simulation() -> RefCounted:
	return Skirmish.create()

func _step_simulation() -> void:
	Skirmish.issue_opponent(simulation)
	simulation.step()

func _placement_kinds() -> Dictionary:
	var kinds: Dictionary = super._placement_kinds()
	kinds[KEY_4] = "barracks"
	return kinds

func _production_kind(building: Dictionary) -> String:
	return Skirmish.UNIT_FOR.get(building.kind, super._production_kind(building))

func _process(delta: float) -> void:
	pan_camera(Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down"), delta)

func _enter_placement(kind: String) -> void:
	_attack_move_mode = false
	super._enter_placement(kind)

func _restart() -> void:
	simulation = _create_simulation()
	selected_ids.clear()
	selected_building_id = -1
	_placement_kind = ""
	_pending_placement = ""
	_attack_move_mode = false
	_selecting = false
	_dragged = false
	_error = ""
	_sequence = 0
	_last_result_tick = -1
	_last_result_sequence = -1
	_selection_box.hide()
	_camera.zoom = Vector2.ONE
	_reset_camera()
	var empty: Array[Vector2i] = []
	_view.set_build_preview(empty, false)
	_refresh()

func _ground(event: InputEventMouseButton) -> Vector2:
	return Iso.plane_to_world(_view.make_canvas_position_local(event.position))

func _unhandled_input(event: InputEvent) -> void:
	if simulation.match_over():
		return
	if not _placement_kind.is_empty():
		super._unhandled_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and not is_selecting():
		if event.physical_keycode == KEY_A and not selected_ids.is_empty():
			_attack_move_mode = true
			return
		if event.physical_keycode == KEY_S and not selected_ids.is_empty():
			_submit({"type":"stop","entity_ids":selected_ids.duplicate()})
			return
	if _attack_move_mode and (event.is_action_pressed("deselect") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed)):
		_attack_move_mode = false
		return
	if _attack_move_mode and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_attack_move_mode = false
			var target: Vector2 = _ground(event)
			_submit({"type":"attack_move","entity_ids":selected_ids.duplicate(),"target":[target.x,target.y]})
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_selecting() and not selected_ids.is_empty():
		var enemy: int = _view.pick_target(_view.make_canvas_position_local(event.position), 1)
		if enemy != -1:
			_submit({"type":"attack","entity_ids":selected_ids.duplicate(),"target_id":enemy})
			return
	super._unhandled_input(event)

func _selected_summary(state: Dictionary) -> String:
	if selected_ids.size() != 1: return ""
	for unit in state.entities:
		if unit.id != selected_ids[0]: continue
		var line: String = "%s #%d HP %d/%d" % [unit.kind, unit.id, unit.hp / 1000, unit.max_hp / 1000]
		if unit.combat != null: line += " | %s%s" % [unit.combat.mode, "" if unit.combat.target_id == null else " -> #" + str(unit.combat.target_id)]
		return line + "\n"
	return ""

func _result_text(match_state: Dictionary) -> String:
	if match_state.status == "ongoing": return ""
	if match_state.status == "draw": return "Draw"
	return "Victory" if match_state.winner == 1 else "Defeat"

func _refresh_hud(state: Dictionary) -> void:
	super._refresh_hud(state)
	var result: String = _result_text(state.match)
	var building: Dictionary = _building(state, selected_building_id)
	$HUD/Economy/Produce.text = "Produce %s (E)" % _production_kind(building) if not building.is_empty() else "Produce (E)"
	_status.text += "\n" + _selected_summary(state) + ("A: attack-move click | S: stop | 4: barracks | You are blue (P1)" if result.is_empty() else "")
	$HUD/Result.text = result
	$HUD/Result.visible = not result.is_empty()
	$HUD/Restart.visible = not result.is_empty()

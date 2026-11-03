extends "res://scripts/main.gd"

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
var selected_building_id: int = -1
var _placement_kind: String = ""
var _pending_placement: String = ""
var _preview_origin: Vector2i
var _last_result_tick: int = -1
var _last_result_sequence: int = -1

func _ready() -> void:
	super._ready()
	$HUD/Economy/Produce.pressed.connect(_produce_selected)
	$HUD/Economy/CancelBuild.pressed.connect(_cancel_build)

func _create_simulation() -> RefCounted:
	var sim = Simulation.new([],Vector2i(32,32))
	sim.add_player(1,10000)
	sim.spawn(1,Vector2(4.5,4.5),"builder")
	sim.add_supply_source(Vector2i(24,4),200)
	return sim

func _view_selection() -> Array[int]:
	var ids: Array[int] = []
	if selected_building_id != -1: ids.append(selected_building_id)
	else: ids.assign(selected_ids)
	return ids

func _building(state: Dictionary, id: int) -> Dictionary:
	for building in state.buildings:
		if building.id == id: return building
	return {}

func _refresh() -> void:
	if selected_building_id != -1 and _building(simulation.snapshot(),selected_building_id).is_empty(): selected_building_id = -1
	super._refresh()

func _refresh_hud(state: Dictionary) -> void:
	for result in state.command_results:
		if result.player == 1 and (result.tick > _last_result_tick or (result.tick == _last_result_tick and result.sequence > _last_result_sequence)):
			_error = result.error
			_last_result_tick = result.tick
			_last_result_sequence = result.sequence
	var player: Dictionary = state.players[0]
	var building: Dictionary = _building(state,selected_building_id)
	var detail: String = "Units: " + str(selected_ids)
	if not building.is_empty(): detail = "%s #%d | Work %d/%d" % [building.kind,building.id,building.work,Definitions.building(building.kind).ticks * 1000]
	_status.text = "Credits: %d | Power: %d/%d | Tick: %d\n%s | Place: %s\n1/2/3 build | Right: context/move | E: produce | Esc: cancel\n%s" % [player.credits,player.power_supply,player.power_demand,state.tick,detail,_placement_kind,_error]
	$HUD/Economy/Produce.visible = not building.is_empty() and building.completed and not Definitions.building(building.kind).produces.is_empty()
	$HUD/Economy/CancelBuild.visible = not building.is_empty() and not building.completed
	_refresh_queue(building.get("queue",[]))

func _refresh_queue(queue: Array) -> void:
	var ids: Array = queue.map(func(entry: Dictionary): return str(entry.id))
	for child in $HUD/Economy/Queue.get_children():
		if not ids.has(str(child.name)): child.free()
	for entry in queue:
		var button: Button = $HUD/Economy/Queue.get_node_or_null(str(entry.id))
		if button == null:
			button = Button.new()
			button.name = str(entry.id)
			button.pressed.connect(_cancel_entry.bind(entry.id))
			$HUD/Economy/Queue.add_child(button)
		button.text = "Cancel #%d %s (%d/%d)" % [entry.id,entry.kind,entry.work,Definitions.unit(entry.kind).ticks * 1000]

func pan_camera(direction: Vector2, delta: float) -> void:
	if _placement_kind.is_empty(): super.pan_camera(direction,delta)

func change_zoom(direction: int) -> void:
	if _placement_kind.is_empty(): super.change_zoom(direction)

func _builder() -> int:
	if selected_ids.size() != 1: return -1
	for unit in simulation.snapshot().entities:
		if unit.id == selected_ids[0] and unit.kind == "builder" and unit.owner == 1: return unit.id
	return -1

func _enter_placement(kind: String) -> void:
	if _builder() == -1: return
	_placement_kind = kind
	selected_building_id = -1
	_update_preview(_view.get_local_mouse_position())
	_refresh()

func _clear_placement() -> void:
	_placement_kind = ""
	var empty: Array[Vector2i] = []
	_view.set_build_preview(empty,false)
	_refresh()

func _update_preview(plane: Vector2) -> void:
	_preview_origin = Vector2i(Iso.plane_to_world(plane).floor())
	var preview: Dictionary = simulation.preview_build(1,_builder(),_placement_kind,_preview_origin)
	_view.set_build_preview(Construction.cells(_placement_kind,_preview_origin),preview.ok)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B: return
		var kind: String = {KEY_1:"reactor",KEY_2:"depot",KEY_3:"factory"}.get(event.physical_keycode,"")
		if not kind.is_empty():
			if is_selecting(): _pending_placement = kind
			else: _enter_placement(kind)
			return
		if event.physical_keycode == KEY_E:
			if not is_selecting() and _placement_kind.is_empty(): _produce_selected()
			return
	if not _placement_kind.is_empty():
		if event.is_action_pressed("deselect"):
			_clear_placement()
		elif event is InputEventMouseMotion:
			_update_preview(_view.make_canvas_position_local(event.position))
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: _clear_placement()
			elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				_update_preview(_view.make_canvas_position_local(event.position))
				_submit({"type":"build","builder_id":_builder(),"building_kind":_placement_kind,"origin":[_preview_origin.x,_preview_origin.y]})
				if _error.is_empty(): _clear_placement()
		return
	if event.is_action_pressed("deselect"):
		selected_building_id = -1
		_pending_placement = ""
	if event is InputEventMouseButton:
		var plane: Vector2 = _view.make_canvas_position_local(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_selecting():
			if _context_order(_view.pick_object(plane)): return
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and is_selecting():
			_update_drag(event.position)
			var building: Dictionary = _building(simulation.snapshot(),_view.pick_object(plane))
			if not _dragged and not building.is_empty() and building.owner == 1:
				selected_building_id = building.id
				selected_ids.clear()
				_selecting = false
				_selection_box.hide()
				_refresh()
				return
			selected_building_id = -1
	super._unhandled_input(event)
	if not is_selecting() and not _pending_placement.is_empty():
		var pending: String = _pending_placement
		_pending_placement = ""
		_enter_placement(pending)

func _context_order(id: int) -> bool:
	if selected_ids.is_empty(): return false
	var state: Dictionary = simulation.snapshot()
	for source in state.sources:
		if source.id != id: continue
		var collectors: bool = true
		for unit in state.entities:
			if selected_ids.has(unit.id) and unit.kind != "collector": collectors = false
		if collectors: _submit({"type":"gather","entity_ids":selected_ids.duplicate(),"source_id":id})
		else:
			_error = "Choose homogeneous collector selection"
			_refresh()
		return true
	var building: Dictionary = _building(state,id)
	if not building.is_empty() and building.owner == 1 and not building.completed:
		if _builder() != -1: _submit({"type":"resume_build","builder_id":_builder(),"building_id":id})
		else:
			_error = "Choose one builder"
			_refresh()
		return true
	return false

func _produce_selected() -> void:
	var building: Dictionary = _building(simulation.snapshot(),selected_building_id)
	if building.is_empty(): return
	_submit({"type":"produce","building_id":building.id,"unit_kind":Definitions.building(building.kind).produces})

func _cancel_entry(id: int) -> void:
	_submit({"type":"cancel_production","building_id":selected_building_id,"production_id":id})

func _cancel_build() -> void:
	_submit({"type":"cancel_build","building_id":selected_building_id})

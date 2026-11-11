extends "res://scripts/main.gd"

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const UiStyle = preload("res://scripts/presentation/ui_style.gd")
const MENU_COLUMNS: int = 4
var selected_building_id: int = -1
var _placement_kind: String = ""
var _pending_placement: String = ""
var _preview_origin: Vector2i
var _last_result_tick: int = -1
var _last_result_sequence: int = -1
var _preview_key: Array = []
var _menu: Array = []

func _ready() -> void:
	$HUD/Status.theme = UiStyle.hud_theme()
	$HUD/Economy.theme = UiStyle.hud_theme()
	var menu := GridContainer.new()
	menu.name = "BuildMenu"
	menu.columns = MENU_COLUMNS
	$HUD/Economy.add_child(menu)
	$HUD/Economy.move_child(menu,0)
	super._ready()
	$HUD/Economy/Produce.pressed.connect(_produce_selected)
	$HUD/Economy/CancelBuild.pressed.connect(_cancel_build)

func _escape_pending() -> bool:
	return super() or not _placement_kind.is_empty() or selected_building_id != -1 or not _pending_placement.is_empty()

func _create_simulation() -> Simulation:
	var sim: Simulation = Simulation.new([],Vector2i(32,32))
	sim.add_player(1,10000)
	sim.spawn(1,Vector2(4.5,4.5),"usa_builder")
	sim.add_supply_source(Vector2i(24,4),200)
	return sim

func _hint_point(payload: Dictionary) -> Variant:
	if payload.type != "resume_build": return super._hint_point(payload)
	var building: Dictionary = _building(simulation.snapshot(),payload.building_id)
	if building.is_empty(): return null
	return Vector2(building.origin[0],building.origin[1]) + Vector2(Definitions.building(building.kind).footprint) / 2.0

func _build_hint() -> String:
	return "1-9: menu  U: unload"

func _production_kind(building: Dictionary, _state: Dictionary) -> String:
	return Definitions.building(building.kind).produces

func _view_selection() -> Array[int]:
	var ids: Array[int] = []
	if selected_building_id != -1: ids.append(selected_building_id)
	else: ids.assign(selected_ids)
	return ids

func _local_state(state: Dictionary) -> Dictionary:
	for player: Dictionary in state.players:
		if player.id == local_player: return player
	return state.players[0]

func _building(state: Dictionary, id: int) -> Dictionary:
	for building: Dictionary in state.buildings:
		if building.id == id: return building
	return {}

func _refresh() -> void:
	var state: Dictionary = simulation.view_state()
	if selected_building_id != -1 and _building(state,selected_building_id).is_empty(): selected_building_id = -1
	_show(state)
	$HUD/Economy.position.y = maxf(116.0,_status.position.y + _status.get_minimum_size().y + 8.0)

func _refresh_hud(state: Dictionary) -> void:
	for result: Dictionary in stepped_results + state.command_results:
		if result.player == local_player and (result.tick > _last_result_tick or (result.tick == _last_result_tick and result.sequence > _last_result_sequence)):
			_error = result.error
			_last_result_tick = result.tick
			_last_result_sequence = result.sequence
	var player: Dictionary = _local_state(state)
	var building: Dictionary = _building(state,selected_building_id)
	var detail: String = "Units: " + str(selected_ids)
	if not building.is_empty(): detail = "%s #%d | Work %d/%d" % [Registry.kind(building.kind).display_name,building.id,building.work,Definitions.building(building.kind).ticks * 1000]
	var resume: String = "Right-click: resume\n" if _view.resume_candidate() != -1 else ""
	var placing: String = Registry.kind(_placement_kind).get("display_name","")
	_status.text = "Credits: %d | Power: %d/%d | Tick: %d\n%s | Place: %s\n%s | Right: context/move | E: produce | Esc: cancel\n%s%s" % [player.credits,player.power_supply,player.power_demand,state.tick,detail,placing,_build_hint(),resume,_error]
	$HUD/Economy/Produce.visible = not building.is_empty() and building.completed and not _production_kind(building, state).is_empty()
	$HUD/Economy/CancelBuild.visible = not building.is_empty() and not building.completed
	_refresh_menu(_menu_kinds(state,building))
	_refresh_queue(building.get("queue",[]))

func _menu_kinds(state: Dictionary, building: Dictionary) -> Array:
	if not building.is_empty(): return Registry.kind(building.kind).produces if building.completed else []
	var kind: String = Registry.faction(_local_state(state).get("faction",Registry.Factions.DEFAULT_FACTION)).get("start_unit","")
	if selected_ids.size() == 1:
		var i: int = state.units.index_of(selected_ids[0])
		var unit_kind: String = state.units.kinds[state.units.kind[i]] if i != -1 else ""
		if Registry.is_builder(unit_kind): kind = unit_kind
	return Registry.kind(kind).get("builds",[])

static func menu_label(index: int, kind: String) -> String:
	var quantity: int = Registry.kind(kind).get("quantity",1)
	return "%d: %s%s $%d" % [index + 1,Registry.kind(kind).display_name," x%d" % quantity if quantity > 1 else "",Registry.kind(kind).cost]

func _refresh_menu(kinds: Array) -> void:
	_menu = kinds
	var grid: GridContainer = $HUD/Economy/BuildMenu
	while grid.get_child_count() > kinds.size(): grid.get_child(grid.get_child_count() - 1).free()
	for i in kinds.size():
		var button: Button = grid.get_child(i) if i < grid.get_child_count() else null
		if button == null:
			button = Button.new()
			button.pressed.connect(_menu_choose.bind(i,false))
			grid.add_child(button)
		button.text = menu_label(i,kinds[i])

func _menu_choose(index: int, from_key: bool) -> void:
	var kind: String = _menu[index]
	if selected_building_id != -1: _submit({"type":"produce","building_id":selected_building_id,"unit_kind":kind})
	elif from_key and is_selecting(): _pending_placement = kind
	else: _enter_placement(kind)

func _refresh_queue(queue: Array) -> void:
	var ids: Array = queue.map(func(entry: Dictionary) -> String: return str(entry.id))
	for child in $HUD/Economy/Queue.get_children():
		if not ids.has(str(child.name)): child.free()
	for entry: Variant in queue:
		var button: Button = $HUD/Economy/Queue.get_node_or_null(str(entry.id))
		if button == null:
			button = Button.new()
			button.name = str(entry.id)
			button.pressed.connect(_cancel_entry.bind(entry.id))
			$HUD/Economy/Queue.add_child(button)
		button.text = queue_label(entry)

static func queue_label(entry: Dictionary) -> String:
	var label: String = Registry.kind(entry.kind).display_name
	if entry.work == 0: return "Cancel %s (queued)" % label
	return "Cancel %s (%d%%)" % [label,entry.work * 100 / (Definitions.unit(entry.kind).ticks * 1000)]

func pan_camera(direction: Vector2, delta: float) -> void:
	if _placement_kind.is_empty(): super.pan_camera(direction,delta)

func change_zoom(direction: int) -> void:
	if _placement_kind.is_empty(): super.change_zoom(direction)

func _builder() -> int:
	if selected_ids.size() != 1: return -1
	for unit: Dictionary in simulation.snapshot().entities:
		if unit.id == selected_ids[0] and Registry.is_builder(unit.kind) and unit.owner == local_player: return unit.id
	return -1

func _enter_placement(kind: String) -> void:
	if _builder() == -1:
		_error = "Choose one builder"
		_refresh()
		return
	_placement_kind = kind
	selected_building_id = -1
	_preview_key = []
	_update_preview(_view.get_local_mouse_position())
	_refresh()

func _clear_placement() -> void:
	_placement_kind = ""
	var empty: Array[Vector2i] = []
	_view.set_build_preview(empty,false)
	_refresh()

func _update_preview(plane: Vector2) -> void:
	_preview_origin = Vector2i(Iso.plane_to_world(plane).floor())
	var key: Array = [_placement_kind,_preview_origin,simulation.tick()]
	if key == _preview_key: return
	_preview_key = key
	var preview: Dictionary = simulation.preview_build(local_player,_builder(),_placement_kind,_preview_origin)
	_view.set_build_preview(Construction.cells(_placement_kind,_preview_origin),preview.ok)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: int = _view.pick_object(_view.make_canvas_position_local(event.position))
		if hovered != _view.hovered_id():
			_view.set_hovered(hovered)
			_refresh()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B: return
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index < _menu.size():
			_menu_choose(index,true)
			return
		if event.physical_keycode == KEY_E:
			if not is_selecting() and _placement_kind.is_empty(): _produce_selected()
			return
		if event.physical_keycode == KEY_U:
			if not is_selecting() and _placement_kind.is_empty(): _unload_selected()
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
			var source: int = _view.pick_source(plane)
			if _context_order(source if source != -1 else _view.pick_object(plane)) or _set_rally(plane): return
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and is_selecting():
			_update_drag(event.position)
			var building: Dictionary = _building(simulation.snapshot(),_view.pick_object(plane))
			if not _dragged and not building.is_empty() and building.owner == local_player:
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
	for source: Dictionary in state.sources:
		if source.id != id: continue
		var collectors: bool = true
		for unit: Dictionary in state.entities:
			if selected_ids.has(unit.id) and Registry.collects(unit.kind).is_empty(): collectors = false
		if collectors: _submit({"type":"gather","entity_ids":selected_ids.duplicate(),"source_id":id})
		else:
			_error = "Choose homogeneous collector selection"
			_refresh()
		return true
	var building: Dictionary = _building(state,id)
	if selected_ids != [id] and _container(state,id,building):
		_submit({"type":"enter","entity_ids":selected_ids.filter(func(unit_id: int) -> bool: return unit_id != id),"target_id":id})
		return true
	if not building.is_empty() and building.owner == local_player and not building.completed:
		if _builder() != -1: _submit({"type":"resume_build","builder_id":_builder(),"building_id":id})
		else:
			_error = "Choose one builder"
			_refresh()
		return true
	return false

func _container(state: Dictionary, id: int, building: Dictionary) -> bool:
	var host: Dictionary = building
	if host.is_empty():
		for unit: Dictionary in state.entities:
			if unit.id == id: host = unit
	return not host.is_empty() and host.owner == local_player and host.get("completed",true) and not Registry.kind(host.kind).get("contains",{}).is_empty()

func _unload_selected() -> void:
	var state: Dictionary = simulation.snapshot()
	var id: int = selected_building_id if selected_building_id != -1 else (selected_ids[0] if selected_ids.size() == 1 else -1)
	var building: Dictionary = _building(state,id)
	if not _container(state,id,building):
		_error = "Select a container"
		_refresh()
		return
	_submit({"type":"unload","target_id":id})

func _set_rally(plane: Vector2) -> bool:
	var building: Dictionary = _building(simulation.snapshot(),selected_building_id)
	if building.is_empty() or building.owner != local_player or not Registry.can_rally(building.kind): return false
	var cell: Vector2 = Iso.plane_to_world(plane).floor() + Vector2(.5,.5)
	_submit({"type":"set_rally","building_id":building.id,"target":[cell.x,cell.y]})
	return true

func _produce_selected() -> void:
	var state: Dictionary = simulation.snapshot()
	var building: Dictionary = _building(state,selected_building_id)
	if building.is_empty():
		_error = "Select a production building"
		_refresh()
		return
	_submit({"type":"produce","building_id":building.id,"unit_kind":_production_kind(building, state)})

func _cancel_entry(id: int) -> void:
	_submit({"type":"cancel_production","building_id":selected_building_id,"production_id":id})

func _cancel_build() -> void:
	_submit({"type":"cancel_build","building_id":selected_building_id})

extends RefCounted

const Iso = preload("res://scripts/presentation/isometric.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Construction = preload("res://scripts/simulation/construction.gd")

var selected_ids: Array[int] = []
var selected_building_id: int = -1
var inspected_id: int = -1
var menu: Array = []
var _screen: Node
var _selecting: bool = false
var _dragged: bool = false
var _start: Vector2
var _start_selection: Array[int] = []
var _shift: bool = false
var _double: bool = false
var _ctrl: bool = false
var _alt: bool = false
var _placement_kind: String = ""
var _pending_placement: String = ""
var _preview_origin: Vector2i
var _preview_key: Array = []
var _attack_move_mode: bool = false

func _init(screen: Node) -> void:
	_screen = screen

func handle(event: InputEvent) -> void:
	if _screen.driver.sim.match_over() or _screen._playtest.holds_match():
		return
	if event.is_action_pressed("deselect"): inspected_id = -1
	if _placement_kind.is_empty() and _combat_input(event): return
	_hover(event)
	if _economy_keys(event): return
	if not _placement_kind.is_empty():
		_placement_input(event)
		return
	if _building_input(event): return
	_selection_input(event)
	if not is_selecting() and not _pending_placement.is_empty():
		var pending: String = _pending_placement
		_pending_placement = ""
		_enter_placement(pending)

func busy() -> bool:
	return _selecting or not _placement_kind.is_empty()

func escape_pending() -> bool:
	return _attack_move_mode or inspected_id != -1 or _selecting or not selected_ids.is_empty() or not _placement_kind.is_empty() or selected_building_id != -1 or not _pending_placement.is_empty()

func reset() -> void:
	selected_ids.clear()
	selected_building_id = -1
	inspected_id = -1
	_placement_kind = ""
	_pending_placement = ""
	_attack_move_mode = false
	_selecting = false
	_dragged = false

func prune(state: Dictionary) -> void:
	if selected_building_id != -1 and _screen._building(state, selected_building_id).is_empty(): selected_building_id = -1
	selected_ids.assign(selected_ids.filter(func(id: int) -> bool: return state.units.index_of(id) != -1))
	if _screen._inspected(state).is_empty(): inspected_id = -1

func view_selection() -> Array[int]:
	var ids: Array[int] = []
	if selected_building_id != -1: ids.append(selected_building_id)
	else: ids.assign(selected_ids)
	return ids

func is_selecting() -> bool:
	return _selecting

func _combat_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and not is_selecting():
		if event.physical_keycode == KEY_A and not selected_ids.is_empty():
			_attack_move_mode = true
			return true
		if event.physical_keycode == KEY_S and not selected_ids.is_empty():
			_screen._submit({"type":"stop","entity_ids":selected_ids.duplicate()})
			return true
	if _attack_move_mode and (event.is_action_pressed("deselect") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed)):
		_attack_move_mode = false
		return true
	if _attack_move_mode and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_attack_move_mode = false
			var target: Vector2 = _ground(event)
			_screen._submit({"type":"attack_move","entity_ids":selected_ids.duplicate(),"target":[target.x,target.y]})
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_selecting() and _order_defence(event):
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_selecting() and not selected_ids.is_empty():
		var enemy: int = _screen._view.pick_target(_screen._view.make_canvas_position_local(event.position), _screen.local_player)
		if enemy != -1:
			_screen._submit({"type":"attack","entity_ids":selected_ids.duplicate(),"target_id":enemy})
			return true
	return false

func _hover(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: int = _screen._view.pick_object(_screen._view.make_canvas_position_local(event.position))
		if hovered != _screen._view.hovered_id():
			_screen._view.set_hovered(hovered)
			_screen._refresh()

func _economy_keys(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo): return false
	if event.physical_keycode == KEY_B: return true
	var index: int = event.physical_keycode - KEY_1
	if index >= 0 and index < menu.size():
		_menu_choose(index,true)
		return true
	if event.physical_keycode == KEY_E:
		if not is_selecting() and _placement_kind.is_empty(): _produce_selected()
		return true
	if event.physical_keycode == KEY_U:
		if not is_selecting() and _placement_kind.is_empty(): _unload_selected()
		return true
	return false

func _placement_input(event: InputEvent) -> void:
	if event.is_action_pressed("deselect"):
		_clear_placement()
	elif event is InputEventMouseMotion:
		_update_preview(_screen._view.make_canvas_position_local(event.position))
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: _clear_placement()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_update_preview(_screen._view.make_canvas_position_local(event.position))
			_screen._submit({"type":"build","builder_id":_builder(),"building_kind":_placement_kind,"origin":[_preview_origin.x,_preview_origin.y]})
			if _screen._error.is_empty(): _clear_placement()

func _building_input(event: InputEvent) -> bool:
	if event.is_action_pressed("deselect"):
		selected_building_id = -1
		_pending_placement = ""
	if event is InputEventMouseButton:
		var plane: Vector2 = _screen._view.make_canvas_position_local(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_selecting():
			var source: int = _screen._view.pick_source(plane)
			if _context_order(source if source != -1 else _screen._view.pick_object(plane)) or _set_rally(plane): return true
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and is_selecting():
			_update_drag(event.position)
			var building: Dictionary = _screen._building(_screen.driver.sim.snapshot(),_screen._view.pick_object(plane))
			if not _dragged and not building.is_empty() and building.owner == _screen.local_player:
				selected_building_id = building.id
				selected_ids.clear()
				_selecting = false
				_screen._selection_box.hide()
				_screen._refresh()
				return true
			selected_building_id = -1
	return false

func _selection_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_screen._perf.toggle()
	elif event.is_action_pressed("deselect"):
		selected_ids.clear()
		_selecting = false
		_screen._selection_box.hide()
		_screen._refresh()
	elif event is InputEventMouseMotion and _selecting:
		_update_drag(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_selecting = true
				_dragged = false
				_start = event.position
				_start_selection = selected_ids.duplicate()
				_shift = event.shift_pressed
				_double = event.double_click
				_ctrl = event.ctrl_pressed
				_alt = event.alt_pressed
			elif _selecting:
				_finish_selection(event.position)
		elif event.pressed and not _selecting:
			match event.button_index:
				MOUSE_BUTTON_RIGHT:
					if not selected_ids.is_empty():
						_move(Iso.plane_to_world(_screen._view.make_canvas_position_local(event.position)))
				MOUSE_BUTTON_WHEEL_UP:
					_screen.change_zoom(1)
				MOUSE_BUTTON_WHEEL_DOWN:
					_screen.change_zoom(-1)

func _update_drag(point: Vector2) -> void:
	_dragged = _dragged or _start.distance_to(point) >= 6.0
	var rect := Rect2(_start, point - _start).abs()
	_screen._selection_box.position = rect.position
	_screen._selection_box.size = rect.size
	_screen._selection_box.visible = _dragged

func _finish_selection(point: Vector2) -> void:
	_update_drag(point)
	var picked: Array[int] = []
	if _dragged:
		var from: Vector2 = _screen._view.make_canvas_position_local(_start)
		var to: Vector2 = _screen._view.make_canvas_position_local(point)
		picked = _screen._view.pick_entities(Rect2(from, to - from))
	else:
		var id: int = _screen._view.pick_entity(_screen._view.make_canvas_position_local(point))
		if id != -1 and _double and not _ctrl:
			picked = _matching_ids(id, _alt)
		elif id != -1:
			picked.append(id)
	selected_ids.clear()
	if _shift:
		selected_ids.assign(_start_selection)
	for id in picked:
		if not selected_ids.has(id):
			selected_ids.append(id)
	selected_ids.sort()
	_selecting = false
	_screen._selection_box.hide()
	_screen._refresh()
	inspected_id = -1
	if not _dragged and selected_ids.is_empty(): inspected_id = _enemy_at(_screen._view.make_canvas_position_local(point))
	_screen._refresh()

func _matching_ids(id: int, whole_map: bool) -> Array[int]:
	var view_rect: Rect2 = _screen._view.get_global_transform_with_canvas().affine_inverse() * _screen.get_viewport().get_visible_rect()
	var kinds: Dictionary = {}
	for unit: Dictionary in _screen.driver.sim.snapshot().entities:
		kinds[unit.id] = {"kind": unit.kind, "inside": unit.has("container_id")}
	var picked: Array[int] = []
	for other: int in _screen._view.pick_entities(Rect2(-1.0e6, -1.0e6, 2.0e6, 2.0e6) if whole_map else view_rect):
		if kinds[other].kind == kinds[id].kind and not kinds[other].inside:
			picked.append(other)
	return picked

func _move(target: Vector2) -> void:
	_screen._submit({"type":"move","entity_ids":selected_ids.duplicate(),"target":[target.x,target.y]})

func _hint_point(payload: Dictionary) -> Variant:
	if payload.type != "resume_build":
		if payload.type in ["move", "attack_move", "set_rally"]: return Vector2(payload.target[0], payload.target[1])
		return null
	var building: Dictionary = _screen._building(_screen.driver.sim.snapshot(),payload.building_id)
	if building.is_empty(): return null
	return Vector2(building.origin[0],building.origin[1]) + Vector2(Definitions.building(building.kind).footprint) / 2.0

func _menu_choose(index: int, from_key: bool) -> void:
	var kind: String = menu[index]
	if selected_building_id != -1: _screen._submit({"type":"produce","building_id":selected_building_id,"unit_kind":kind})
	elif from_key and is_selecting(): _pending_placement = kind
	else: _enter_placement(kind)

func _builder() -> int:
	if selected_ids.size() != 1: return -1
	for unit: Dictionary in _screen.driver.sim.snapshot().entities:
		if unit.id == selected_ids[0] and Registry.is_builder(unit.kind) and unit.owner == _screen.local_player: return unit.id
	return -1

func _enter_placement(kind: String) -> void:
	_attack_move_mode = false
	if _builder() == -1:
		_screen._error = "Choose one builder"
		_screen._refresh()
		return
	_placement_kind = kind
	selected_building_id = -1
	_preview_key = []
	_update_preview(_screen._view.get_local_mouse_position())
	_screen._refresh()

func _clear_placement() -> void:
	_placement_kind = ""
	var empty: Array[Vector2i] = []
	_screen._view.set_build_preview(empty,false)
	_screen._refresh()

func _update_preview(plane: Vector2) -> void:
	_preview_origin = Vector2i(Iso.plane_to_world(plane).floor())
	var key: Array = [_placement_kind,_preview_origin,_screen.driver.sim.tick()]
	if key == _preview_key: return
	_preview_key = key
	var preview: Dictionary = _screen.driver.sim.preview_build(_screen.local_player,_builder(),_placement_kind,_preview_origin)
	_screen._view.set_build_preview(Construction.cells(_placement_kind,_preview_origin),preview.ok)

func _context_order(id: int) -> bool:
	if selected_ids.is_empty(): return false
	var state: Dictionary = _screen.driver.sim.snapshot()
	for source: Dictionary in state.sources:
		if source.id != id: continue
		var collectors: bool = true
		for unit: Dictionary in state.entities:
			if selected_ids.has(unit.id) and Registry.collects(unit.kind).is_empty(): collectors = false
		if collectors: _screen._submit({"type":"gather","entity_ids":selected_ids.duplicate(),"source_id":id})
		else:
			_screen._error = "Choose homogeneous collector selection"
			_screen._refresh()
		return true
	var building: Dictionary = _screen._building(state,id)
	if selected_ids != [id] and _container(state,id,building):
		_screen._submit({"type":"enter","entity_ids":selected_ids.filter(func(unit_id: int) -> bool: return unit_id != id),"target_id":id})
		return true
	if not building.is_empty() and building.owner == _screen.local_player and not building.completed:
		if _builder() != -1: _screen._submit({"type":"resume_build","builder_id":_builder(),"building_id":id})
		else:
			_screen._error = "Choose one builder"
			_screen._refresh()
		return true
	return false

func _container(state: Dictionary, id: int, building: Dictionary) -> bool:
	var host: Dictionary = building
	if host.is_empty():
		for unit: Dictionary in state.entities:
			if unit.id == id: host = unit
	return not host.is_empty() and host.owner == _screen.local_player and host.get("completed",true) and not Registry.kind(host.kind).get("contains",{}).is_empty()

func _unload_selected() -> void:
	var state: Dictionary = _screen.driver.sim.snapshot()
	var id: int = selected_building_id if selected_building_id != -1 else (selected_ids[0] if selected_ids.size() == 1 else -1)
	var building: Dictionary = _screen._building(state,id)
	if not _container(state,id,building):
		_screen._error = "Select a container"
		_screen._refresh()
		return
	_screen._submit({"type":"unload","target_id":id})

func _set_rally(plane: Vector2) -> bool:
	var building: Dictionary = _screen._building(_screen.driver.sim.snapshot(),selected_building_id)
	if building.is_empty() or building.owner != _screen.local_player or not Registry.can_rally(building.kind): return false
	var cell: Vector2 = Iso.plane_to_world(plane).floor() + Vector2(.5,.5)
	_screen._submit({"type":"set_rally","building_id":building.id,"target":[cell.x,cell.y]})
	return true

func _produce_selected() -> void:
	var state: Dictionary = _screen.driver.sim.snapshot()
	var building: Dictionary = _screen._building(state,selected_building_id)
	if building.is_empty():
		_screen._error = "Select a production building"
		_screen._refresh()
		return
	_screen._submit({"type":"produce","building_id":building.id,"unit_kind":_screen._production_kind(building, state)})

func _cancel_entry(id: int) -> void:
	_screen._submit({"type":"cancel_production","building_id":selected_building_id,"production_id":id})

func _cancel_build() -> void:
	_screen._submit({"type":"cancel_build","building_id":selected_building_id})

func _ground(event: InputEventMouseButton) -> Vector2:
	return Iso.plane_to_world(_screen._view.make_canvas_position_local(event.position))

func _enemy_at(plane: Vector2) -> int:
	var id: int = _screen._view.pick_entity(plane, true)
	if id == -1: return _screen._view.pick_target(plane, _screen.local_player)
	for unit: Dictionary in _screen.driver.sim.snapshot().entities:
		if unit.id == id: return id if unit.owner != _screen.local_player else -1
	return -1

func _order_defence(event: InputEventMouseButton) -> bool:
	var building: Dictionary = _screen._building(_screen.driver.sim.snapshot(), selected_building_id)
	if building.is_empty() or building.owner != _screen.local_player or not building.completed or building.get("combat") == null: return false
	var enemy: int = _screen._view.pick_target(_screen._view.make_canvas_position_local(event.position), _screen.local_player)
	if enemy == -1: return false
	_screen._submit({"type":"defence_attack","building_id":building.id,"target_id":enemy})
	return true

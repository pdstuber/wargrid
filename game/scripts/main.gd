extends Node

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Zooms: Array[float] = [0.5, 1.0, 2.0]
var simulation = Simulation.new()
var selected_ids: Array[int] = []
var _sequence: int = 0
var _error: String = ""
var _selecting: bool = false
var _dragged: bool = false
var _start: Vector2
var _start_selection: Array[int] = []
var _shift: bool = false
var _obstacle_added: bool = false
var _base_blocked: Array[Vector2i] = []
var _camera_bounds: Rect2
@onready var _view: Node2D = $WorldView
@onready var _camera: Camera2D = $Camera2D
@onready var _status: Label = $HUD/Status
@onready var _selection_box: ReferenceRect = $HUD/SelectionBox

func _ready() -> void:
	for y in range(4, 10):
		for x in range(6, 9):
			_base_blocked.append(Vector2i(x, y))
	simulation = Simulation.new(_base_blocked)
	for y in range(1, 5):
		for x in range(1, 6):
			simulation.spawn(1, Vector2(x + 0.5, y + 0.5))
	var size: Array = simulation.snapshot().map.size
	_camera_bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
	for corner in [Vector2(size[0], 0), Vector2(0, size[1]), Vector2(size[0], size[1])]:
		_camera_bounds = _camera_bounds.expand(Iso.world_to_plane(corner))
	_camera.position = Iso.world_to_plane(Vector2(size[0], size[1]) / 2.0)
	_refresh()

func _physics_process(_delta: float) -> void:
	simulation.step()
	_refresh()

func _process(delta: float) -> void:
	pan_camera(Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down"), delta)

func pan_camera(direction: Vector2, delta: float) -> void:
	if _selecting:
		return
	_camera.position += direction.normalized() * 400.0 * delta / _camera.zoom.x
	_camera.position = _camera.position.clamp(_camera_bounds.position, _camera_bounds.end)

func change_zoom(direction: int) -> void:
	if _selecting:
		return
	var index: int = Zooms.find(_camera.zoom.x)
	index = clampi(index + signi(direction), 0, Zooms.size() - 1)
	_camera.zoom = Vector2.ONE * Zooms[index]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("deselect"):
		selected_ids.clear()
		_selecting = false
		_selection_box.hide()
		_refresh()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		_toggle_obstacle()
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
			elif _selecting:
				_finish_selection(event.position)
		elif event.pressed and not _selecting:
			match event.button_index:
				MOUSE_BUTTON_RIGHT:
					if not selected_ids.is_empty():
						_move(Iso.plane_to_world(_view.make_canvas_position_local(event.position)))
				MOUSE_BUTTON_WHEEL_UP:
					change_zoom(1)
				MOUSE_BUTTON_WHEEL_DOWN:
					change_zoom(-1)

func _update_drag(point: Vector2) -> void:
	_dragged = _dragged or _start.distance_to(point) >= 6.0
	var rect := Rect2(_start, point - _start).abs()
	_selection_box.position = rect.position
	_selection_box.size = rect.size
	_selection_box.visible = _dragged

func _finish_selection(point: Vector2) -> void:
	_update_drag(point)
	var picked: Array[int] = []
	if _dragged:
		var from: Vector2 = _view.make_canvas_position_local(_start)
		var to: Vector2 = _view.make_canvas_position_local(point)
		picked = _view.pick_entities(Rect2(from, to - from))
	else:
		var id: int = _view.pick_entity(_view.make_canvas_position_local(point))
		if id != -1:
			picked.append(id)
	selected_ids.clear()
	if _shift:
		selected_ids.assign(_start_selection)
	for id in picked:
		if not selected_ids.has(id):
			selected_ids.append(id)
	selected_ids.sort()
	_selecting = false
	_selection_box.hide()
	_refresh()

func _toggle_obstacle() -> void:
	var cells: Array[Vector2i] = _base_blocked.duplicate()
	if not _obstacle_added:
		for y in range(5, 11):
			cells.append(Vector2i(10, y))
	var result: Dictionary = simulation.replace_blocked_cells(cells)
	if result.ok:
		_obstacle_added = not _obstacle_added
	_error = result.error
	_refresh()

func _move(target: Vector2) -> void:
	var state: Dictionary = simulation.snapshot()
	var result: Dictionary = simulation.issue_command({
		"tick": state.tick, "player": 1, "sequence": _sequence, "type": "move",
		"entity_ids": selected_ids.duplicate(), "target": [target.x, target.y],
	})
	if result.ok:
		_sequence += 1
	_error = result.error
	_refresh()

func _refresh() -> void:
	var state: Dictionary = simulation.snapshot()
	_view.set_state(state, selected_ids)
	var counts := {"moving": 0, "path_pending": 0, "arrived": 0, "blocked": 0}
	for unit in state.entities:
		if counts.has(unit.status):
			counts[unit.status] += 1
	_status.text = "Left/drag: select | Shift: add | Right: move | WASD/arrows: pan | Wheel: zoom | Esc: clear | B: obstacle\nSelected: %d | Tick: %d | Moving: %d | Pending: %d | Arrived: %d | Blocked: %d\n%s" % [
		selected_ids.size(), state.tick, counts.moving, counts.path_pending, counts.arrived, counts.blocked, _error,
	]

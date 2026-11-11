extends Node

const Simulation = preload("res://scripts/simulation/simulation.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const PerfOverlay = preload("res://scripts/presentation/perf_overlay.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const LAUNCHER_SCENE: String = "res://scenes/launcher.tscn"
const MapData = preload("res://scripts/simulation/map_data.gd")
const ZOOMS: Array[float] = [0.5, 1.0, 2.0]
var simulation: Simulation = Simulation.new()
var selected_ids: Array[int] = []
var local_player: int = 1
var stepped_results: Array = []
var _sequence: int = 0
var _error: String = ""
var _selecting: bool = false
var _dragged: bool = false
var _start: Vector2
var _start_selection: Array[int] = []
var _shift: bool = false
var _double: bool = false
var _ctrl: bool = false
var _alt: bool = false
var _obstacle_added: bool = false
var _base_blocked: Array[Vector2i] = []
var _camera_bounds: Rect2
@onready var _view: Node2D = $WorldView
@onready var _camera: Camera2D = $Camera2D
var _perf: Label
var _clock := PresentationClock.new()
var _pause: Control
var change_scene: Callable = _change_scene
@onready var _status: Label = $HUD/Status
@onready var _selection_box: ReferenceRect = $HUD/SelectionBox

func _ready() -> void:
	_perf = PerfOverlay.new()
	$HUD.add_child(_perf)
	_pause = PauseMenu.new()
	_pause.confirm_leave = _confirm_leave()
	_pause.resume_requested.connect(_pause.close)
	_pause.leave_requested.connect(_leave)
	_pause.quit_requested.connect(func() -> void: get_tree().quit())
	_pause.quality_changed.connect(_view.set_quality)
	_pause.neon_changed.connect(_view.set_bright_owners)
	_pause.smooth_changed.connect(_view.set_smooth)
	_pause.destinations_changed.connect(_view.set_show_destinations)
	$HUD.add_child(_pause)
	_view.set_quality(GraphicsSettings.stored_quality())
	_view.set_bright_owners(GraphicsSettings.load_neon())
	_view.set_smooth(GraphicsSettings.load_smooth())
	_view.set_show_destinations(GraphicsSettings.load_destinations())
	_view.local_player = local_player
	simulation = _create_simulation()
	_clock = PresentationClock.new()
	_reset_camera()
	_refresh()

func _reset_camera() -> void:
	var size: Array = simulation.snapshot().map.size
	_camera_bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
	for corner: Variant in [Vector2(size[0], 0), Vector2(0, size[1]), Vector2(size[0], size[1])]:
		_camera_bounds = _camera_bounds.expand(Iso.world_to_plane(corner))
	var map: Dictionary = simulation.map_data()
	var start := MapData.start_cell(map, local_player) if not map.is_empty() else Vector2i(-1, -1)
	var focus := Vector2(start) + Vector2(0.5, 0.5) if start.x >= 0 else Vector2(size[0], size[1]) / 2.0
	_camera.position = Iso.world_to_plane(focus)

func _step_simulation() -> void:
	simulation.step()

func menu_open() -> bool:
	return _pause.visible

func _confirm_leave() -> bool:
	return false

func _pauses_sim() -> bool:
	return true

func _escape_pending() -> bool:
	return _selecting or not selected_ids.is_empty()

func _leave() -> void:
	change_scene.call(LAUNCHER_SCENE)

func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if event.physical_keycode == KEY_F3: return
	if event.is_action_pressed("deselect"):
		if _pause.visible: _pause.back()
		elif not _escape_pending(): _pause.open()
		else: return
	elif not _pause.visible: return
	get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if _pause.visible and _pauses_sim(): return
	var started: int = Time.get_ticks_usec()
	var tick_before: int = simulation.tick()
	_step_simulation()
	_perf.record_step((Time.get_ticks_usec() - started) / 1000.0)
	# A stall frame (online, waiting for the peer) is not a step frame; counting it would inflate the split share.
	var advanced: bool = simulation.tick() != tick_before
	if advanced: stepped_results.append_array(simulation.command_results().duplicate(true))
	if not is_processing() or (advanced and _clock.stepped(Engine.get_process_frames(), simulation.tick())): _refresh()

func _present_if_due() -> bool:
	if not _clock.rendered(Engine.get_process_frames(), simulation.tick()): return false
	_refresh()
	return true

func _process(delta: float) -> void:
	_present_if_due()
	pan_camera(Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down"), delta)
	_view.advance_frame()

func pan_camera(direction: Vector2, delta: float) -> void:
	if _selecting:
		return
	_camera.position += direction.normalized() * 400.0 * delta / _camera.zoom.x
	_camera.position = _camera.position.clamp(_camera_bounds.position, _camera_bounds.end)

func change_zoom(direction: int) -> void:
	if _selecting:
		return
	var index: int = ZOOMS.find(_camera.zoom.x)
	index = clampi(index + signi(direction), 0, ZOOMS.size() - 1)
	_camera.zoom = Vector2.ONE * ZOOMS[index]
	_view.set_zoom(ZOOMS[index])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_perf.toggle()
	elif event.is_action_pressed("deselect"):
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
				_double = event.double_click
				_ctrl = event.ctrl_pressed
				_alt = event.alt_pressed
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
	_selection_box.hide()
	_refresh()

func _matching_ids(id: int, whole_map: bool) -> Array[int]:
	var view_rect: Rect2 = _view.get_global_transform_with_canvas().affine_inverse() * get_viewport().get_visible_rect()
	var kinds: Dictionary = {}
	for unit: Dictionary in simulation.snapshot().entities:
		kinds[unit.id] = {"kind": unit.kind, "inside": unit.has("container_id")}
	var picked: Array[int] = []
	for other: int in _view.pick_entities(Rect2(-1.0e6, -1.0e6, 2.0e6, 2.0e6) if whole_map else view_rect):
		if kinds[other].kind == kinds[id].kind and not kinds[other].inside:
			picked.append(other)
	return picked

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
	_submit({"type":"move","entity_ids":selected_ids.duplicate(),"target":[target.x,target.y]})

func _refresh() -> void:
	_show(simulation.view_state())

func _show(state: Dictionary) -> void:
	_perf.set_counts(state.units.size(), state.get("buildings", []).size(), state.tick)
	_perf.split_share = _clock.split_share()
	var zone: int = Profiler.begin()
	selected_ids.assign(selected_ids.filter(func(id: int) -> bool: return state.units.index_of(id) != -1))
	Profiler.end(&"refresh.selection", zone)
	_view.set_view(state, _view_selection())
	zone = Profiler.begin()
	_refresh_hud(state)
	Profiler.end(&"refresh.hud", zone)
	stepped_results.clear()

func _create_simulation() -> Simulation:
	for y in range(4, 10):
		for x in range(6, 9):
			_base_blocked.append(Vector2i(x, y))
	simulation = Simulation.new(_base_blocked)
	for y in range(1, 5):
		for x in range(1, 6):
			simulation.spawn(1, Vector2(x + 0.5, y + 0.5))
	return simulation

func _refresh_hud(state: Dictionary) -> void:
	var counts := {"moving": 0, "path_pending": 0, "arrived": 0, "blocked": 0}
	for status: int in state.units.status:
		if status < ViewRows.STATUSES.size() and counts.has(ViewRows.STATUSES[status]):
			counts[ViewRows.STATUSES[status]] += 1
	_status.text = "Left/drag: select | Shift: add | Right: move | WASD/arrows: pan | Wheel: zoom | Esc: clear | B: obstacle\nSelected: %d | Tick: %d | Moving: %d | Pending: %d | Arrived: %d | Blocked: %d\n%s" % [
		selected_ids.size(), state.tick, counts.moving, counts.path_pending, counts.arrived, counts.blocked, _error,
	]

func _view_selection() -> Array[int]:
	return selected_ids.duplicate()

func is_selecting() -> bool:
	return _selecting

func _show_hint(payload: Dictionary) -> void:
	var point: Variant = _hint_point(payload)
	if point != null: _view.add_hint(point, simulation.tick())

func _hint_point(payload: Dictionary) -> Variant:
	if payload.type in ["move", "attack_move", "set_rally"]: return Vector2(payload.target[0], payload.target[1])
	return null

func _submit(payload: Dictionary) -> void:
	_show_hint(payload)
	var state: Dictionary = simulation.snapshot()
	var command: Dictionary = payload.duplicate(true)
	command.tick = command.get("tick",state.tick)
	command.player = local_player
	for entry: Variant in state.last_sequences:
		if entry.player == local_player: _sequence = maxi(_sequence,entry.sequence + 1)
	command.sequence = _sequence
	var result: Dictionary = simulation.issue_command(command)
	if result.ok: _sequence += 1
	_error = result.error
	_refresh()

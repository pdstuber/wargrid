extends Node

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Zooms: Array[float] = [0.5, 1.0, 2.0]
var simulation = Simulation.new()
var selected_id: int = -1
var _sequence: int = 0
var _error: String = ""
@onready var _view: Node2D = $WorldView
@onready var _camera: Camera2D = $Camera2D
@onready var _status: Label = $HUD/Status

func _ready() -> void:
	var blocked: Array[Vector2i] = []
	for y in range(4, 10):
		for x in range(6, 9):
			blocked.append(Vector2i(x, y))
	simulation = Simulation.new(blocked)
	simulation.spawn(1, Vector2(2.5, 2.5))
	_camera.position = Iso.world_to_plane(Vector2(8, 8))
	_refresh()

func _physics_process(_delta: float) -> void:
	simulation.step()
	_refresh()

func _process(delta: float) -> void:
	pan_camera(Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down"), delta)

func pan_camera(direction: Vector2, delta: float) -> void:
	_camera.position += direction.normalized() * 400.0 * delta / _camera.zoom.x
	_camera.position = _camera.position.clamp(Vector2(-512, 0), Vector2(512, 512))

func change_zoom(direction: int) -> void:
	var index: int = Zooms.find(_camera.zoom.x)
	index = clampi(index + signi(direction), 0, Zooms.size() - 1)
	_camera.zoom = Vector2.ONE * Zooms[index]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("deselect"):
		selected_id = -1
		_refresh()
	elif event is InputEventMouseButton and event.pressed:
		var point: Vector2 = _view.make_canvas_position_local(event.position)
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				selected_id = _view.pick_entity(point)
				_refresh()
			MOUSE_BUTTON_RIGHT:
				if selected_id != -1:
					_move(Iso.plane_to_world(point))
			MOUSE_BUTTON_WHEEL_UP:
				change_zoom(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				change_zoom(-1)

func _move(target: Vector2) -> void:
	var state: Dictionary = simulation.snapshot()
	var result: Dictionary = simulation.issue_command({
		"tick": state.tick, "player": 1, "sequence": _sequence, "type": "move",
		"entity_ids": [selected_id], "target": [target.x, target.y],
	})
	if result.ok:
		_sequence += 1
	_error = result.error
	_refresh()

func _refresh() -> void:
	var state: Dictionary = simulation.snapshot()
	_view.set_state(state, selected_id)
	_status.text = "Left: select | Right: move | WASD/arrows: pan | Wheel: zoom | Esc: deselect\nSelected: %s | Tick: %d | Status: %s\n%s" % [
		"none" if selected_id == -1 else str(selected_id), state.tick, state.entities[0].status, _error,
	]

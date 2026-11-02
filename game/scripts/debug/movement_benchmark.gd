extends Node

const Workload = preload("res://scripts/debug/movement_workload.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
var _simulation: RefCounted
var _layout_index: int = 0
var _layout_started: int
var _sample_started: int = 0
var _last_frame: int = 0
var _window_started: int = 0
var _window_ticks: int = 0
var _sample_ticks: int = 0
var _leg: int = -1
var _leg_ticks: int = 0
var _completed_legs: int = 0
var _queue_peak: int = 0
var _queue_start: int = -1
var _queue_drain: int = 0
var _tick_times := PackedFloat64Array()
var _frame_times := PackedFloat64Array()
var _command_times := PackedFloat64Array()
var _sampling_done: bool = false
@onready var _view: Node2D = $WorldView
@onready var _status: Label = $HUD/Status

func _ready() -> void:
	$Camera2D.position = Iso.world_to_plane(Vector2(32, 32))
	$Camera2D.zoom = Vector2(0.5, 0.5)
	print("M2 RENDERED engine=", Engine.get_version_info().string, " os=", OS.get_name(),
		" cpu=", OS.get_processor_name(), " resolution=", get_viewport().get_visible_rect().size,
		" zoom=0.5 map=64x64 units=300 seed=none warmup_wall_seconds=10 sample_wall_seconds=60")
	_begin_layout()

func _begin_layout() -> void:
	_simulation = Workload.create(["open", "dense"][_layout_index])
	_layout_started = Time.get_ticks_usec()
	_sample_started = 0
	_last_frame = 0
	_window_ticks = 0
	_sample_ticks = 0
	_leg = -1
	_leg_ticks = 0
	_completed_legs = 0
	_queue_peak = 0
	_queue_start = -1
	_queue_drain = 0
	_tick_times.clear()
	_frame_times.clear()
	_command_times.clear()
	_sampling_done = false

func _physics_process(_delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	var command_tick: bool = _leg == -1 or Workload.settled(_simulation)
	if command_tick:
		if _leg >= 0:
			_completed_legs += 1
		_leg += 1
		_leg_ticks = 0
		_queue_start = _simulation.snapshot().tick
		Workload.issue_leg(_simulation, _leg)
	_simulation.step()
	_leg_ticks += 1
	var state: Dictionary = _simulation.snapshot()
	_view.set_state(state, [])
	_status.text = "%s | %s | tick %d | leg %d | Esc: quit" % [["open", "dense"][_layout_index],
		"draining" if _sampling_done else ("sampling" if _sample_started > 0 else "warmup"), state.tick, _leg]
	var elapsed: float = (Time.get_ticks_usec() - started) / 1000.0
	if _sample_started > 0 and not _sampling_done:
		_sample_ticks += 1
		_window_ticks += 1
		_tick_times.append(elapsed)
	if command_tick:
		_command_times.append(elapsed)
	_queue_peak = maxi(_queue_peak, state.path_queue.size())
	if state.path_queue.is_empty() and _queue_start >= 0:
		_queue_drain = maxi(_queue_drain, state.tick - _queue_start)
		_queue_start = -1
	if _leg_ticks > 3000:
		_fail("Rendered workload leg exceeded 3000 ticks")
		return
	for unit in state.entities:
		if unit.status == "blocked":
			_fail("Rendered workload blocked unit " + str(unit.id))
			return
	if _sampling_done and Workload.settled(_simulation):
		_finish_layout(state)

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _sample_started == 0 and now - _layout_started >= 10000000:
		_sample_started = now
		_window_started = now
		_last_frame = now
	elif _sample_started > 0 and not _sampling_done:
		_frame_times.append((now - _last_frame) / 1000.0)
		_last_frame = now
		if now - _window_started >= 10000000:
			var seconds: float = (now - _window_started) / 1000000.0
			print("BACKLOG ", ["open", "dense"][_layout_index], " wall_seconds=", seconds,
				" physics_ticks=", _window_ticks, " expected_ticks=", seconds * 30.0,
				" cumulative_lag_ticks=", (now - _sample_started) / 1000000.0 * 30.0 - _sample_ticks)
			_window_started = now
			_window_ticks = 0
		if now - _sample_started >= 60000000:
			_sampling_done = true
			print("RENDERED SAMPLE ", ["open", "dense"][_layout_index], " wall_seconds=", (now - _sample_started) / 1000000.0,
				" physics_ticks=", _sample_ticks, " tick_ms=", JSON.stringify(Stats.summary(_tick_times)),
				" frame_interval_ms=", JSON.stringify(Stats.summary(_frame_times)),
				" command_tick_ms=", JSON.stringify(Stats.summary(_command_times)))

func _finish_layout(state: Dictionary) -> void:
	var goals: Dictionary = {}
	for unit in state.entities:
		if unit.destination == null or unit.position != unit.destination:
			_fail("Rendered workload missed destination")
			return
		goals[unit.destination] = true
	if goals.size() != 300 or _tick_times.is_empty() or _frame_times.is_empty():
		_fail("Rendered workload incomplete samples/destinations")
		return
	print("RENDERED COMPLETE ", ["open", "dense"][_layout_index], " completed_legs=", _completed_legs + 1,
		" queue_peak=", _queue_peak, " queue_drain_ticks=", _queue_drain, " arrived=300 unique_destinations=", goals.size())
	_layout_index += 1
	if _layout_index == 2:
		print("RENDERED BENCHMARK PASSED 2")
		get_tree().quit(0)
	else:
		_begin_layout()

func _fail(message: String) -> void:
	push_error(message)
	set_physics_process(false)
	set_process(false)
	get_tree().quit(1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("deselect"):
		get_tree().quit(1)

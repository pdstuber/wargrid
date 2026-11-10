extends Node

const Workload = preload("res://scripts/debug/movement_workload.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const SoundPlayer = preload("res://scripts/presentation/sound_player.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
# New with the ashfall layout (R2): worst of six rendered runs 3.02 ms plus about 50%. No ceiling exists for the other layouts.
const ASHFALL_FRAME_P95_MS: float = 3.3
# Fixed ceilings on max draw calls per frame in the sample window; never raised to pass.
const DRAW_CALL_CEILINGS: Dictionary = {"open": 50, "dense": 50, "horde": 50, "ashfall": 60}
const LAYOUTS: Array[String] = ["open", "dense", "ashfall", "horde"]
# `-- --profile` adds profiling zones and a third, 196x196 combat leg (spike-performance only).
var _profile: bool = OS.get_cmdline_user_args().has("--profile")
# `-- --sound` runs only the horde layout with a SoundPlayer and reports its cost.
var _sound_mode: bool = OS.get_cmdline_user_args().has("--sound")
var _sound: SoundPlayer
var _sound_state: Dictionary = {}
var _sound_cues: int = 0
var _sound_times := PackedFloat64Array()
var _large: bool = false
var _simulation: Simulation
var _layout_index: int = 3 if OS.get_cmdline_user_args().has("--sound") else 0
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
var _draw_calls := PackedFloat64Array()
var _sampling_done: bool = false
var _horde_start: Dictionary = {}
var _horde_peak: int = 0
var _horde_marked_ticks: int = 0
@onready var _view: Node2D = $WorldView
@onready var _status: Label = $HUD/Status

func _ready() -> void:
	# Vsync would quantize frame intervals to display refresh and hide render cost.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	$Camera2D.position = Iso.world_to_plane(Vector2(32, 32))
	$Camera2D.zoom = Vector2(0.5, 0.5)
	print("M2 RENDERED engine=", Engine.get_version_info().string, " os=", OS.get_name(),
		" cpu=", OS.get_processor_name(), " resolution=", get_viewport().get_visible_rect().size,
		" zoom=0.5 map=64x64 (ashfall layout 194x187) units=300 seed=none vsync=off warmup_wall_seconds=10 sample_wall_seconds=60")
	_begin_layout()

func _begin_layout() -> void:
	$Camera2D.position = Iso.world_to_plane(Vector2(32, 32)) if _layout_name() != "ashfall" else Iso.world_to_plane(Vector2(26, 118))
	_horde_start.clear()
	_horde_peak = 0
	_horde_marked_ticks = 0
	if _layout_name() == "horde":
		_simulation = CombatWorkload.create("horde_render")
		if _sound_mode and _sound == null:
			_sound = SoundPlayer.new(1)
			add_child(_sound)
		_sound_cues = 0
		_sound_times.clear()
		for unit: Dictionary in _simulation.snapshot().entities:
			if unit.owner == 1: _horde_start[unit.id] = unit.position
	else:
		_simulation = Workload.create(LAYOUTS[_layout_index])
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
	_draw_calls.clear()
	_sampling_done = false

func _physics_process(_delta: float) -> void:
	if _large:
		_large_tick()
		return
	if _layout_name() == "horde":
		_horde_tick()
		return
	var started: int = Time.get_ticks_usec()
	var command_tick: bool = _leg == -1 or Workload.settled(_simulation)
	if command_tick:
		if _leg >= 0:
			_completed_legs += 1
		_leg += 1
		_leg_ticks = 0
		_queue_start = _simulation.snapshot().tick
		Workload.issue_leg(_simulation, _leg, Workload.ASHFALL_ANCHORS if _layout_name() == "ashfall" else Workload.ANCHORS)
	_simulation.step()
	_leg_ticks += 1
	var state: Dictionary = _simulation.snapshot()
	var no_selection: Array[int] = []
	_view.set_state(state, no_selection)
	_status.text = "%s | %s | tick %d | leg %d | Esc: quit" % [LAYOUTS[_layout_index],
		"draining" if _sampling_done else ("sampling" if _sample_started > 0 else "warmup"), state.tick, _leg]
	var elapsed: float = (Time.get_ticks_usec() - started) / 1000.0
	if _sample_started > 0 and not _sampling_done:
		_sample_ticks += 1
		_window_ticks += 1
		_tick_times.append(elapsed)
	if command_tick:
		_command_times.append(elapsed)
	Profiler.end_tick()
	_queue_peak = maxi(_queue_peak, state.path_queue.size())
	if state.path_queue.is_empty() and _queue_start >= 0:
		_queue_drain = maxi(_queue_drain, state.tick - _queue_start)
		_queue_start = -1
	if _leg_ticks > 3000:
		_fail("Rendered workload leg exceeded 3000 ticks")
		return
	for unit: Dictionary in state.entities:
		if unit.status == "blocked":
			_fail("Rendered workload blocked unit " + str(unit.id))
			return
	if _sampling_done and Workload.settled(_simulation):
		_finish_layout(state)

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _sound != null and _sample_started > 0 and not _sampling_done and not _sound_state.is_empty():
		_sound.update(_sound_state)
		_sound_cues += _sound.last_requests().size()
		_sound_times.append((Time.get_ticks_usec() - now) / 1000.0)
	if _sample_started == 0 and now - _layout_started >= 10000000:
		_sample_started = now
		_window_started = now
		_last_frame = now
		Profiler.reset()
		Profiler.enabled = _profile
	elif _sample_started > 0 and not _sampling_done:
		_frame_times.append((now - _last_frame) / 1000.0)
		_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_last_frame = now
		if now - _window_started >= 10000000:
			var seconds: float = (now - _window_started) / 1000000.0
			print("BACKLOG ", _layout_name(), " wall_seconds=", seconds,
				" physics_ticks=", _window_ticks, " expected_ticks=", seconds * 30.0,
				" cumulative_lag_ticks=", (now - _sample_started) / 1000000.0 * 30.0 - _sample_ticks)
			_window_started = now
			_window_ticks = 0
		if now - _sample_started >= 60000000:
			_sampling_done = true
			print("RENDERED SAMPLE ", _layout_name(), " wall_seconds=", (now - _sample_started) / 1000000.0,
				" physics_ticks=", _sample_ticks, " tick_ms=", JSON.stringify(Stats.summary(_tick_times)),
				" frame_interval_ms=", JSON.stringify(Stats.summary(_frame_times)),
				" command_tick_ms=", JSON.stringify(Stats.summary(_command_times)),
				" draw_calls=", JSON.stringify(Stats.summary(_draw_calls)))
			for line in Profiler.report("rendered_" + _layout_name(), &"draw"): print(line)
			Profiler.enabled = false
			if _large:
				print("RENDERED PROFILE COMPLETE")
				get_tree().quit(0)

static func draw_call_failure(layout: String, max_calls: float) -> String:
	if not DRAW_CALL_CEILINGS.has(layout):
		return "No draw-call ceiling for layout %s" % layout
	if max_calls > DRAW_CALL_CEILINGS[layout]:
		return "Layout %s draws %d calls, ceiling %d" % [layout, int(max_calls), DRAW_CALL_CEILINGS[layout]]
	return ""

static func draw_call_gate(layout: String, max_calls: float, report_only: bool) -> String:
	return "" if report_only else draw_call_failure(layout, max_calls)

func _report_only() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		for flag: String in ["--quality", "--zoom", "--units", "--layout"]:
			if arg.begins_with(flag): return true
	return false

func _report_draw_calls(layout: String) -> bool:
	var max_calls: float = Stats.summary(_draw_calls).max
	var failure: String = draw_call_failure(layout, max_calls)
	print("DRAW_CALLS ", layout, " max=", int(max_calls), " p50=", int(Stats.summary(_draw_calls).p50), " ceiling=", DRAW_CALL_CEILINGS.get(layout, -1), " over=", failure != "")
	var gate: String = draw_call_gate(layout, max_calls, _report_only())
	if gate != "":
		_fail(gate)
		return false
	return true

func _finish_layout(state: Dictionary) -> void:
	var goals: Dictionary = {}
	for unit: Dictionary in state.entities:
		if unit.destination == null or unit.position != unit.destination:
			_fail("Rendered workload missed destination")
			return
		goals[unit.destination] = true
	if goals.size() != 300 or _tick_times.is_empty() or _frame_times.is_empty():
		_fail("Rendered workload incomplete samples/destinations")
		return
	if _layout_name() == "ashfall":
		var frame_p95: float = Stats.summary(_frame_times).p95
		print("ASHFALL map=194x187 units=300 buildings=6 frame_p95_ms=", frame_p95)
		if frame_p95 > ASHFALL_FRAME_P95_MS:
			_fail("Rendered ashfall frame p95 %.3f ms exceeds %.1f ms" % [frame_p95, ASHFALL_FRAME_P95_MS])
			return
	if not _report_draw_calls(_layout_name()): return
	print("RENDERED COMPLETE ", LAYOUTS[_layout_index], " completed_legs=", _completed_legs + 1,
		" queue_peak=", _queue_peak, " queue_drain_ticks=", _queue_drain, " arrived=300 unique_destinations=", goals.size())
	_layout_index += 1
	_begin_layout()

func _horde_tick() -> void:
	var started: int = Time.get_ticks_usec()
	_simulation.step()
	var state: Dictionary = _simulation.snapshot()
	if _sound != null:
		_sound.collect_step(state.tick, _simulation.combat_events(), _simulation.command_results())
		_sound_state = state
	var no_selection: Array[int] = []
	_view.set_state(state, no_selection)
	_status.text = "horde | %s | tick %d | Esc: quit" % ["draining" if _sampling_done else ("sampling" if _sample_started > 0 else "warmup"), state.tick]
	if _sample_started > 0 and not _sampling_done:
		_sample_ticks += 1
		_window_ticks += 1
		_tick_times.append((Time.get_ticks_usec() - started) / 1000.0)
		var marks: int = _view.horde_marks().size()
		_horde_peak = maxi(_horde_peak, marks)
		_horde_marked_ticks += 1 if marks > 0 else 0
	Profiler.end_tick()
	if _sampling_done:
		_finish_horde(state)

func _finish_horde(state: Dictionary) -> void:
	var moved: int = 0
	for unit: Dictionary in state.entities:
		if _horde_start.has(unit.id) and unit.position != _horde_start[unit.id]: moved += 1
	if _horde_peak == 0 or _horde_marked_ticks == 0 or moved == 0 or _tick_times.is_empty() or _frame_times.is_empty():
		_fail("Rendered horde workload drew no horde marks or no unit moved")
		return
	if not _report_draw_calls("horde"): return
	print("RENDERED COMPLETE horde horde_mark_peak=", _horde_peak, " marked_ticks=", _horde_marked_ticks, " of ", _sample_ticks, " units_moved=", moved)
	if _sound != null:
		if _sound_cues == 0:
			_fail("RENDERED SOUND cues=0")
			return
		print("RENDERED SOUND cues=", _sound_cues, " update_p95_ms=", Stats.summary(_sound_times).p95)
	print("RENDERED BENCHMARK PASSED 4")
	if _profile:
		_begin_large()
		return
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	set_physics_process(false)
	set_process(false)
	get_tree().quit(1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("deselect"):
		get_tree().quit(1)

func _layout_name() -> String:
	return "large_196" if _large else LAYOUTS[_layout_index]

func _begin_large() -> void:
	_large = true
	_simulation = CombatWorkload.create_large()
	$Camera2D.position = Iso.world_to_plane(Vector2(98, 98))
	_layout_started = Time.get_ticks_usec()
	_sample_started = 0
	_sample_ticks = 0
	_window_ticks = 0
	_tick_times.clear()
	_frame_times.clear()
	_draw_calls.clear()
	_sampling_done = false

func _large_tick() -> void:
	var started: int = Time.get_ticks_usec()
	_simulation.step()
	var no_selection: Array[int] = []
	_view.set_state(_simulation.snapshot(), no_selection)
	if _sample_started > 0 and not _sampling_done:
		_sample_ticks += 1
		_window_ticks += 1
		_tick_times.append((Time.get_ticks_usec() - started) / 1000.0)
	Profiler.end_tick()

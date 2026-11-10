extends Node

const Workload = preload("res://scripts/debug/movement_workload.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const SoundPlayer = preload("res://scripts/presentation/sound_player.gd")
const VisualDirector = preload("res://scripts/presentation/visual_director.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
# New with the ashfall layout (R2): worst of six rendered runs 3.02 ms plus about 50%. No ceiling exists for the other layouts.
const ASHFALL_FRAME_P95_MS: float = 3.3
# Fixed ceilings on max draw calls per frame in the sample window; never raised to pass.
const DRAW_CALL_CEILINGS: Dictionary = {"open": 50, "dense": 50, "horde": 50, "ashfall": 60}
const LAYOUTS: Array[String] = ["open", "dense", "ashfall", "horde"]
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
# `-- --profile` adds profiling zones and a third, 196x196 combat leg (spike-performance only).
var _profile: bool = OS.get_cmdline_user_args().has("--profile")
# `-- --sound` runs only the horde layout with a SoundPlayer and reports its cost.
var _sound_mode: bool = OS.get_cmdline_user_args().has("--sound")
var _sound: SoundPlayer
var _visuals := VisualDirector.new()
var _sound_state: Dictionary = {}
var _sound_cues: int = 0
var _sound_times := PackedFloat64Array()
var _large: bool = false
var _simulation: Simulation
var _web: bool = OS.has_feature("wargrid_render_bench")
var _sequence: Array[String] = _layouts_to_run()
var _layout_index: int = 0
var _lines := PackedStringArray()
var _script_usec: int = 0
var _carried_tick_usec: int = 0
var _cpu_script := PackedFloat64Array()
var _cpu_render := PackedFloat64Array()
var _cpu_setup := PackedFloat64Array()
var _cpu_total := PackedFloat64Array()
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
	if not _web: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var zoom: float = _zoom()
	$Camera2D.position = Iso.world_to_plane(Vector2(32, 32))
	$Camera2D.zoom = Vector2(zoom, zoom)
	_view.time_draws = true
	_view.set_quality(_quality())
	_view.set_zoom(zoom)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_emit("M2 RENDERED engine=" + Engine.get_version_info().string + " os=" + OS.get_name()
		+ " cpu=" + OS.get_processor_name() + " resolution=" + str(get_viewport().get_visible_rect().size)
		+ " zoom=" + str(zoom) + " quality=" + ("high" if _quality() == GraphicsSettings.HIGH else "low")
		+ " layouts=" + ",".join(_sequence) + " map=64x64 (ashfall layout 194x187) units=" + str(units_run(_units(), _sequence))
		+ " seed=none vsync=" + ("browser" if _web else "off") + " warmup_wall_seconds=10 sample_wall_seconds=60")
	_begin_layout()

func _arg(flag: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(flag + "="): return arg.trim_prefix(flag + "=")
	return fallback

func _layouts_to_run() -> Array[String]:
	var only: String = _arg("--layout", "")
	if only != "":
		assert(LAYOUTS.has(only), "unknown layout " + only)
		return [only] as Array[String]
	if _units() == 500 or OS.get_cmdline_user_args().has("--sound"): return ["horde"] as Array[String]
	var all: Array[String] = LAYOUTS.duplicate()
	if _web: all = ["horde", "ashfall"]
	return all

func _units() -> int:
	return int(_arg("--units", "300"))

func _zoom() -> float:
	return float(_arg("--zoom", "0.5"))

func _quality() -> int:
	return GraphicsSettings.LOW if _arg("--quality", "high") == "low" else GraphicsSettings.HIGH

func _emit(line: String) -> void:
	print(line)
	_lines.append(line)

func _begin_layout() -> void:
	_script_usec = 0
	_carried_tick_usec = 0
	_view.draw_usec = 0
	_cpu_script.clear()
	_cpu_render.clear()
	_cpu_setup.clear()
	_cpu_total.clear()
	$Camera2D.position = Iso.world_to_plane(Vector2(32, 32)) if _layout_name() != "ashfall" else Iso.world_to_plane(Vector2(26, 118))
	_visuals.reset()
	_view.set_visuals(_visuals)
	_horde_start.clear()
	_horde_peak = 0
	_horde_marked_ticks = 0
	if _layout_name() == "horde":
		_simulation = CombatWorkload.create("horde_render_500" if _units() == 500 else "horde_render")
		if _sound_mode and _sound == null:
			_sound = SoundPlayer.new(1)
			add_child(_sound)
		_sound_cues = 0
		_sound_times.clear()
		for unit: Dictionary in _simulation.snapshot().entities:
			if unit.owner == 1: _horde_start[unit.id] = unit.position
	else:
		_simulation = Workload.create(_layout_name())
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
	_status.text = "%s | %s | tick %d | leg %d | Esc: quit" % [_layout_name(),
		"draining" if _sampling_done else ("sampling" if _sample_started > 0 else "warmup"), state.tick, _leg]
	var elapsed: float = (Time.get_ticks_usec() - started) / 1000.0
	if _sample_started > 0 and not _sampling_done:
		_sample_ticks += 1
		_window_ticks += 1
		_tick_times.append(elapsed)
		_script_usec += Time.get_ticks_usec() - started
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
	_view.advance_frame()
	var now: int = Time.get_ticks_usec()
	if _sound != null and _sample_started > 0 and not _sampling_done and not _sound_state.is_empty():
		_sound.update(_sound_state)
		_sound_cues += _sound.last_requests().size()
		_sound_times.append((Time.get_ticks_usec() - now) / 1000.0)
	if _sample_started == 0 and now - _layout_started >= 10000000:
		_sample_started = now
		_window_started = now
		_last_frame = now
		_script_usec = 0
		_carried_tick_usec = 0
		_view.draw_usec = 0
		Profiler.reset()
		Profiler.enabled = _profile
	elif _sample_started > 0 and not _sampling_done:
		_frame_times.append((now - _last_frame) / 1000.0)
		_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_record_cpu_frame()
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
			_emit("RENDERED SAMPLE " + _layout_name() + " wall_seconds=" + str((now - _sample_started) / 1000000.0)
				+ " physics_ticks=" + str(_sample_ticks) + " tick_ms=" + JSON.stringify(Stats.summary(_tick_times))
				+ " frame_interval_ms=" + JSON.stringify(Stats.summary(_frame_times))
				+ " command_tick_ms=" + JSON.stringify(Stats.summary(_command_times))
				+ " draw_calls=" + JSON.stringify(Stats.summary(_draw_calls)))
			_emit("CPU_FRAME " + _layout_name() + " script_ms=" + JSON.stringify(Stats.summary(_cpu_script))
				+ " render_ms=" + JSON.stringify(Stats.summary(_cpu_render))
				+ " setup_ms=" + JSON.stringify(Stats.summary(_cpu_setup))
				+ " total_ms=" + JSON.stringify(Stats.summary(_cpu_total)))
			for line in Profiler.report("rendered_" + _layout_name(), &"draw"): print(line)
			Profiler.enabled = false
			if _large:
				print("RENDERED PROFILE COMPLETE")
				get_tree().quit(0)

func _record_cpu_frame() -> void:
	var script_ms: float = _script_ms()
	var render_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
	var setup_ms: float = RenderingServer.get_frame_setup_time_cpu()
	_cpu_script.append(script_ms)
	_cpu_render.append(render_ms)
	_cpu_setup.append(setup_ms)
	_cpu_total.append(script_ms + render_ms + setup_ms)

# Godot draws after _process, so the draw counted here belongs to the previous frame's tick.
func _script_ms() -> float:
	var script_ms: float = (_carried_tick_usec + _view.draw_usec) / 1000.0
	_carried_tick_usec = _script_usec
	_script_usec = 0
	_view.draw_usec = 0
	return script_ms

# The horde_render_500 workload exists only for the horde layout.
static func units_run(requested: int, layouts: Array[String]) -> int:
	return 500 if requested == 500 and layouts.has("horde") else 300

static func draw_call_failure(layout: String, max_calls: float) -> String:
	if not DRAW_CALL_CEILINGS.has(layout):
		return "No draw-call ceiling for layout %s" % layout
	if max_calls > DRAW_CALL_CEILINGS[layout]:
		return "Layout %s draws %d calls, ceiling %d" % [layout, int(max_calls), DRAW_CALL_CEILINGS[layout]]
	return ""

func _report_only() -> bool:
	if _web: return true
	for arg: String in OS.get_cmdline_user_args():
		for flag: String in ["--quality", "--zoom", "--units", "--layout"]:
			if arg.begins_with(flag): return true
	return false

func _report_draw_calls(layout: String) -> bool:
	var max_calls: float = Stats.summary(_draw_calls).max
	var failure: String = draw_call_failure(layout, max_calls)
	_emit("DRAW_CALLS " + layout + " max=" + str(int(max_calls)) + " p50=" + str(int(Stats.summary(_draw_calls).p50)) + " ceiling=" + str(DRAW_CALL_CEILINGS.get(layout, -1)) + " over=" + str(failure != ""))
	var gate: String = "" if _report_only() else failure
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
		_emit("ASHFALL map=194x187 units=300 buildings=6 frame_p95_ms=" + str(frame_p95))
		if frame_p95 > ASHFALL_FRAME_P95_MS and not _report_only():
			_fail("Rendered ashfall frame p95 %.3f ms exceeds %.1f ms" % [frame_p95, ASHFALL_FRAME_P95_MS])
			return
	if not _report_draw_calls(_layout_name()): return
	_emit("RENDERED COMPLETE " + _layout_name() + " completed_legs=" + str(_completed_legs + 1)
		+ " queue_peak=" + str(_queue_peak) + " queue_drain_ticks=" + str(_queue_drain) + " arrived=300 unique_destinations=" + str(goals.size()))
	_advance()

func _advance() -> void:
	_layout_index += 1
	if _layout_index < _sequence.size():
		_begin_layout()
		return
	_emit("RENDERED BENCHMARK PASSED " + str(_sequence.size()))
	if _profile:
		_begin_large()
	elif _web:
		_post()
	else:
		get_tree().quit(0)

func _post() -> void:
	set_physics_process(false)
	set_process(false)
	var http := HTTPRequest.new()
	add_child(http)
	var origin: String = str(JavaScriptBridge.eval("location.origin"))
	var body: String = "\n".join(_lines) + "\nUA " + str(JavaScriptBridge.eval("navigator.userAgent")) + "\n"
	http.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		_status.text = "posted" if code == 204 else "post failed %d" % code)
	if http.request(origin + "/result", ["Content-Type: text/plain"], HTTPClient.METHOD_POST, body) != OK:
		_status.text = "post failed"

# Zoom 0.5 shows the whole fight from a fixed camera; closer zooms follow the owner-1 army so they do not render empty ground.
static func horde_camera(entities: Array, level: float) -> Vector2:
	var fixed: Vector2 = Iso.world_to_plane(Vector2(32, 32))
	if level <= 0.5: return fixed
	var sum := Vector2.ZERO
	var count: int = 0
	for unit: Dictionary in entities:
		if unit.owner == 1:
			sum += Vector2(unit.position[0], unit.position[1])
			count += 1
	return Iso.world_to_plane(sum / count) if count > 0 else fixed

func _horde_tick() -> void:
	var started: int = Time.get_ticks_usec()
	_simulation.step()
	var state: Dictionary = _simulation.snapshot()
	_visuals.collect_step(state.tick, _simulation.combat_events(), _simulation.command_results())
	if _sound != null:
		_sound.collect_step(state.tick, _simulation.combat_events(), _simulation.command_results())
		_sound_state = state
	var no_selection: Array[int] = []
	$Camera2D.position = horde_camera(state.entities, $Camera2D.zoom.x)
	_view.set_state(state, no_selection)
	_status.text = "horde | %s | tick %d | Esc: quit" % ["draining" if _sampling_done else ("sampling" if _sample_started > 0 else "warmup"), state.tick]
	if _sample_started > 0 and not _sampling_done:
		_sample_ticks += 1
		_window_ticks += 1
		_tick_times.append((Time.get_ticks_usec() - started) / 1000.0)
		_script_usec += Time.get_ticks_usec() - started
		var marks: int = _view.horde_count()
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
	_emit("RENDERED COMPLETE horde horde_mark_peak=" + str(_horde_peak) + " marked_ticks=" + str(_horde_marked_ticks) + " of " + str(_sample_ticks) + " units_moved=" + str(moved))
	if _sound != null:
		if _sound_cues == 0:
			_fail("RENDERED SOUND cues=0")
			return
		print("RENDERED SOUND cues=", _sound_cues, " update_p95_ms=", Stats.summary(_sound_times).p95)
	_advance()

func _fail(message: String) -> void:
	push_error(message)
	if _web:
		_emit("RENDERED FAILED " + message)
		_post()
		return
	set_physics_process(false)
	set_process(false)
	get_tree().quit(1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("deselect"):
		get_tree().quit(1)

func _layout_name() -> String:
	return "large_196" if _large else _sequence[_layout_index]

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

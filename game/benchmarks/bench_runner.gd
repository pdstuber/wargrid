class_name WargridBenchRunner
extends SceneTree

const MovementWorkload = preload("res://scripts/debug/movement_workload.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const TeamMatch = preload("res://scripts/debug/team_match.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

# Yield to the browser between chunks so the page stays responsive; each tick is still timed alone.
const TICKS_PER_FRAME: int = 30
const WARMUP: int = 300
const SAMPLES: int = 1800

var _label: Label
var _lines := PackedStringArray()

func _initialize() -> void:
	_label = Label.new()
	root.add_child(_label)
	_run.call_deferred()

func _run() -> void:
	var isolated: String = str(JavaScriptBridge.eval("crossOriginIsolated")) if OS.has_feature("web") else "n/a"
	_emit("BENCH engine=%s os=%s cpu=%s web=%s debug_build=%s chunk=%d cross_origin_isolated=%s" % [Engine.get_version_info().string, OS.get_name(),
		OS.get_processor_name(), OS.has_feature("web"), OS.is_debug_build(), TICKS_PER_FRAME, isolated])
	for layout: String in ["open", "dense"]: await _movement(layout)
	for layout: String in ["open", "dense", "contact", "skirmish3v3"]: await _combat(layout)
	await _team()
	_emit("BENCH DONE")
	if OS.has_feature("web"): _post()
	else: quit(0)

func _movement(layout: String) -> void:
	var sim: Simulation = MovementWorkload.create(layout)
	var samples := PackedFloat64Array()
	var leg: int = -1
	for tick in range(WARMUP + SAMPLES):
		var start: int = Time.get_ticks_usec()
		if leg == -1 or MovementWorkload.settled(sim):
			leg += 1
			MovementWorkload.issue_leg(sim, leg)
		sim.step()
		var elapsed: float = (Time.get_ticks_usec() - start) / 1000.0
		if tick >= WARMUP: samples.append(elapsed)
		sim.snapshot()
		if tick % TICKS_PER_FRAME == 0: await process_frame
	_emit("HEADLESS %s tick_ms=%s legs=%d" % [layout, JSON.stringify(Stats.summary(samples)), leg + 1])

func _combat(layout: String) -> void:
	var sim: Simulation = CombatWorkload.create(layout)
	var samples := PackedFloat64Array()
	for tick in range(WARMUP + SAMPLES):
		var start: int = Time.get_ticks_usec()
		sim.step()
		var elapsed: float = (Time.get_ticks_usec() - start) / 1000.0
		if tick >= WARMUP: samples.append(elapsed)
		sim.snapshot()
		if tick % TICKS_PER_FRAME == 0: await process_frame
	_emit("COMBAT %s tick_ms=%s alive_end=%d" % [layout, JSON.stringify(Stats.summary(samples)), sim.snapshot().entities.size()])

func _team() -> void:
	var sim: Simulation = TeamMatch.create()
	var samples := PackedFloat64Array()
	Profiler.reset()
	Profiler.enabled = true
	var status: String = "cap"
	for tick in range(TeamMatch.TEAM_TICK_CAP):
		var start: int = Time.get_ticks_usec()
		TeamMatch.step(sim)
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
		Profiler.end_tick()
		if sim.tick() == WARMUP: Profiler.reset()
		var state: Dictionary = sim.snapshot()
		if tick % TICKS_PER_FRAME == 0: await process_frame
		if state.match.status != "ongoing":
			status = state.match.status
			break
	Profiler.enabled = false
	_emit("TEAM MATCH %s tick=%d" % [status, sim.tick()])
	_emit("TEAM TIMING %s" % JSON.stringify(Stats.summary(samples)))
	_emit("TEAM MEAN ms=%.3f" % Stats.mean(samples))
	_emit(Stats.worst_tick_line("bench", "team", samples, 0))

func _emit(line: String) -> void:
	print(line)
	_lines.append(line)
	_label.text = "\n".join(_lines)

func _post() -> void:
	var http := HTTPRequest.new()
	root.add_child(http)
	var origin: String = str(JavaScriptBridge.eval("location.origin"))
	var body: String = "\n".join(_lines) + "\nUA " + str(JavaScriptBridge.eval("navigator.userAgent")) + "\n"
	http.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		_emit("BENCH POSTED" if code == 204 else "BENCH POST FAILED %d" % code))
	if http.request(origin + "/result", ["Content-Type: text/plain"], HTTPClient.METHOD_POST, body) != OK:
		_emit("BENCH POST FAILED")

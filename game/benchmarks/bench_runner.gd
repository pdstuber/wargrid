class_name WargridBenchRunner
extends SceneTree

const MovementWorkload = preload("res://scripts/debug/movement_workload.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const TeamMatch = preload("res://scripts/debug/team_match.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")

const ROWS: Array[String] = ["move_open", "move_dense", "combat_open", "combat_dense", "contact", "skirmish3v3", "hordes300", "team"]
const OPTION_KEYS: Array[String] = ["only", "native", "slices", "timing", "probe", "record", "warm"]
const DIGEST_EVERY: int = 300

# Yield to the browser between chunks so the page stays responsive; each tick is still timed alone.
const TICKS_PER_FRAME: int = 30
const WARMUP: int = 300
const SAMPLES: int = 1800

var _label: Label
var _lines := PackedStringArray()
var _quiet: bool = false
var _failed: bool = false
var _last_digest: String = ""

func _initialize() -> void:
	_label = Label.new()
	root.add_child(_label)
	_run.call_deferred()

func _run() -> void:
	var isolated: String = str(JavaScriptBridge.eval("crossOriginIsolated")) if OS.has_feature("web") else "n/a"
	_emit("BENCH engine=%s os=%s cpu=%s web=%s debug_build=%s chunk=%d cross_origin_isolated=%s t_ms=%d" % [Engine.get_version_info().string, OS.get_name(),
		OS.get_processor_name(), OS.has_feature("web"), OS.is_debug_build(), TICKS_PER_FRAME, isolated, Time.get_ticks_msec()])
	var options: Dictionary = _options()
	if _failed: return
	var rows: Array[String] = ROWS
	if options.has("only"):
		var only: String = options.only
		if not ROWS.has(only):
			_fail("unknown row '%s' (known: %s)" % [only, ", ".join(ROWS)])
			return
		rows = [only]
		_quiet = true
		var warm: String = options.get("warm", "contact")
		if not ROWS.has(warm):
			_fail("unknown warm row '%s'" % warm)
			return
		await _row(warm)
		_quiet = false
	for id: String in rows: await _row(id)
	_emit("BENCH DONE")
	if OS.has_feature("web"): _post()
	else: quit(0)

func _options() -> Dictionary:
	var pairs: PackedStringArray
	if OS.has_feature("web"):
		var query: String = str(JavaScriptBridge.eval("location.search")).trim_prefix("?")
		pairs = query.split("&", false)
	else:
		pairs = OS.get_cmdline_user_args()
	var options := {}
	for pair: String in pairs:
		var parts: PackedStringArray = pair.uri_decode().split("=", true, 1)
		if not OPTION_KEYS.has(parts[0]):
			_fail("unknown option '%s' (known: %s)" % [parts[0], ", ".join(OPTION_KEYS)])
			return {}
		options[parts[0]] = parts[1] if parts.size() > 1 else ""
	return options

func _fail(message: String) -> void:
	_failed = true
	_quiet = false
	_emit("BENCH FAILED %s" % message)
	if OS.has_feature("web"): _post()
	else: quit(1)

func _row(id: String) -> void:
	match id:
		"move_open": await _movement("open")
		"move_dense": await _movement("dense")
		"combat_open": await _combat("open")
		"combat_dense": await _combat("dense")
		"contact", "skirmish3v3", "hordes300": await _combat(id)
		"team": await _team()

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
		var state: Dictionary = sim.snapshot()
		if sim.tick() % DIGEST_EVERY == 0: _digest("move_" + layout, sim.tick(), state)
		if tick % TICKS_PER_FRAME == 0: await process_frame
	_digest("move_" + layout, sim.tick(), sim.snapshot())
	_emit("HEADLESS %s tick_ms=%s legs=%d t_ms=%d" % [layout, JSON.stringify(Stats.summary(samples)), leg + 1, Time.get_ticks_msec()])

func _combat(layout: String) -> void:
	var sim: Simulation = CombatWorkload.create(layout)
	var samples := PackedFloat64Array()
	for tick in range(WARMUP + SAMPLES):
		var start: int = Time.get_ticks_usec()
		sim.step()
		var elapsed: float = (Time.get_ticks_usec() - start) / 1000.0
		if tick >= WARMUP: samples.append(elapsed)
		var state: Dictionary = sim.snapshot()
		if sim.tick() % DIGEST_EVERY == 0: _digest(_combat_id(layout), sim.tick(), state)
		if tick % TICKS_PER_FRAME == 0: await process_frame
	var last: Dictionary = sim.snapshot()
	_digest(_combat_id(layout), sim.tick(), last)
	_emit("COMBAT %s tick_ms=%s alive_end=%d t_ms=%d" % [layout, JSON.stringify(Stats.summary(samples)), last.entities.size(), Time.get_ticks_msec()])

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
		if sim.tick() % DIGEST_EVERY == 0: _digest("team", sim.tick(), state)
		if tick % TICKS_PER_FRAME == 0: await process_frame
		if state.match.status != "ongoing":
			status = state.match.status
			break
	Profiler.enabled = false
	_digest("team", sim.tick(), sim.snapshot())
	_emit("TEAM MATCH %s tick=%d" % [status, sim.tick()])
	_emit("TEAM TIMING %s t_ms=%d" % [JSON.stringify(Stats.summary(samples)), Time.get_ticks_msec()])

func _combat_id(layout: String) -> String:
	return layout if layout in ["contact", "skirmish3v3", "hordes300"] else "combat_" + layout

func _digest(row: String, tick: int, state: Dictionary) -> void:
	var key: String = "%s@%d" % [row, tick]
	if key == _last_digest: return
	_last_digest = key
	_emit("DIGEST %s tick=%d %s" % [row, tick, StateHash.digest(state)])

func _emit(line: String) -> void:
	if _quiet: return
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

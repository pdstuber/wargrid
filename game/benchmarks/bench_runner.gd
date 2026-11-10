class_name WargridBenchRunner
extends SceneTree

const MovementWorkload = preload("res://scripts/debug/movement_workload.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const TeamMatch = preload("res://scripts/debug/team_match.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const NativeBridge = preload("res://scripts/native/native_bridge.gd")
const NativeProbe = preload("res://benchmarks/native_probe.gd")
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
var _native_error: String = ""
var _native_mode: String = "off"
var _native_slices: Array = []

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
	_configure_native(options)
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
	for id: String in rows:
		await _row(id)
		if _failed: return
	if options.has("probe"):
		await _probe(options.probe)
		if _failed: return
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

func _configure_native(options: Dictionary) -> void:
	_native_mode = options.get("native", "off")
	var timing: bool = options.has("timing")
	if _native_mode == "off" and not timing: return
	var slices: Array = Array(str(options.get("slices", "")).split(",", false))
	var result: Dictionary = NativeBridge.configure(_native_mode, slices, timing, options.get("record", ""))
	if result.ok: _native_slices = slices
	else: _native_error = result.error

func _probe(mode: String) -> void:
	for line: String in NativeProbe.run(self, mode == "panic"): _emit(line)
	if mode != "panic": return
	_emit("PROBE panic calling")
	if OS.has_feature("web"):
		_post()
		await create_timer(1.5).timeout
	var probe: Object = ClassDB.instantiate(&"WargridProbe") if ClassDB.class_exists(&"WargridProbe") else null
	if probe != null: probe.panic_now()
	_emit("PROBE panic returned page_alive=true")

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
		if tick == WARMUP: NativeBridge.reset_report()
		var start: int = Time.get_ticks_usec()
		if leg == -1 or MovementWorkload.settled(sim):
			leg += 1
			MovementWorkload.issue_leg(sim, leg)
		sim.step()
		var elapsed: float = (Time.get_ticks_usec() - start) / 1000.0
		NativeBridge.record_tick(int(elapsed * 1000.0))
		if tick >= WARMUP: samples.append(elapsed)
		var state: Dictionary = sim.snapshot()
		if sim.tick() % DIGEST_EVERY == 0: _digest("move_" + layout, sim.tick(), state)
		if tick % TICKS_PER_FRAME == 0: await process_frame
	_digest("move_" + layout, sim.tick(), sim.snapshot())
	_emit("HEADLESS %s tick_ms=%s legs=%d t_ms=%d" % [layout, JSON.stringify(Stats.summary(samples)), leg + 1, Time.get_ticks_msec()])
	_slice_lines("move_" + layout)

func _combat(layout: String) -> void:
	var sim: Simulation = CombatWorkload.create(layout)
	var samples := PackedFloat64Array()
	for tick in range(WARMUP + SAMPLES):
		if tick == WARMUP: NativeBridge.reset_report()
		var start: int = Time.get_ticks_usec()
		sim.step()
		var elapsed: float = (Time.get_ticks_usec() - start) / 1000.0
		NativeBridge.record_tick(int(elapsed * 1000.0))
		if tick >= WARMUP: samples.append(elapsed)
		var state: Dictionary = sim.snapshot()
		if sim.tick() % DIGEST_EVERY == 0: _digest(_combat_id(layout), sim.tick(), state)
		if tick % TICKS_PER_FRAME == 0: await process_frame
	var last: Dictionary = sim.snapshot()
	_digest(_combat_id(layout), sim.tick(), last)
	_emit("COMBAT %s tick_ms=%s alive_end=%d t_ms=%d" % [layout, JSON.stringify(Stats.summary(samples)), last.entities.size(), Time.get_ticks_msec()])
	_slice_lines(_combat_id(layout))

func _team() -> void:
	var sim: Simulation = TeamMatch.create()
	var samples := PackedFloat64Array()
	Profiler.reset()
	Profiler.enabled = true
	var status: String = "cap"
	for tick in range(TeamMatch.TEAM_TICK_CAP):
		var start: int = Time.get_ticks_usec()
		TeamMatch.step(sim)
		var elapsed: float = (Time.get_ticks_usec() - start) / 1000.0
		samples.append(elapsed)
		NativeBridge.record_tick(int(elapsed * 1000.0))
		Profiler.end_tick()
		if sim.tick() == WARMUP:
			Profiler.reset()
			NativeBridge.reset_report()
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
	_slice_lines("team")

# Rows that must see entities in a selected slice, or the comparison measured nothing.
const MUST_SEE: Dictionary = {"horde": ["hordes300"], "move": ["hordes300", "move_open", "move_dense"]}

func _slice_lines(row: String) -> void:
	if _native_mode == "off" and _native_slices.is_empty() and _native_error.is_empty(): return
	if not _native_error.is_empty():
		var shown: String = "extension missing" if _native_error.begins_with("extension missing") else _native_error
		_emit("SLICE %s - mode=%s gd_ms=0.000 pack_ms=0.000 call_ms=0.000 apply_ms=0.000 calls=0 entities=0 in_bytes=0 out_bytes=0 ticks=0 tick_sum_ms=0.000 mismatch=%s" % [row, _native_mode, shown])
		return
	for line: String in NativeBridge.slice_lines(row): _emit(line)
	if _native_mode == "off": return
	var slices: Dictionary = NativeBridge.report().slices
	for slice_name: String in _native_slices:
		if MUST_SEE.get(slice_name, []).has(row) and slices[slice_name].entities == 0:
			_fail("slice %s saw no entities on row %s" % [slice_name, row])
			return

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

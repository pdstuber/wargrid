extends Node

const Lockstep = preload("res://scripts/net/lockstep.gd")
const RelayTransport = preload("res://scripts/net/relay_transport.gd")
const SeatSim = preload("res://scripts/net/seat_sim.gd")
const Wire = preload("res://scripts/net/wire.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const ScriptedHuman = preload("res://scripts/simulation/scripted_human.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const UNCAPPED_STEPS: int = 64
const CAPPED_STEPS: int = 2
const CLOSE_WAIT_MSEC: int = 1000
const ORACLE_MAX_TICKS: int = 30000

var _args: Dictionary = {}
var _transport: RefCounted
var _lockstep: RefCounted
var _sim: Simulation
var _seat: int = 0
var _hello_sent: bool = false
var _stalled: bool = false
var _status: String = ""
var _reason: String = ""
var _closing_since: int = 0
var _ending: bool = false
var _connect_msec: int = 0
var _match_map: String = MatchSettings.TEST_MAP
var _chosen: Array[int] = []
var _match_seed: int = 0
var state_rows := PackedStringArray()

func _ready() -> void:
	_args = _parse(OS.get_cmdline_user_args())
	var faction_error: String = _faction_error()
	if faction_error != "":
		printerr(faction_error)
		get_tree().quit(2)
		return
	if _args.has("replay-log"):
		_replay_oracle()
		return
	_transport = RelayTransport.new()
	var url: String = _args.get("relay", _args.get("probe-relay", ""))
	_connect_msec = Time.get_ticks_msec()
	if url == "" or _transport.connect_to(url) != OK:
		_finish("ended_relay", "cannot connect")

func _process(_delta: float) -> void:
	if _transport == null: return
	if _closing_since != 0:
		_transport.poll()
		if _transport.closed() or Time.get_ticks_msec() - _closing_since > CLOSE_WAIT_MSEC: _exit()
		return
	if _ending: return
	_receive(_transport.poll())
	if _lockstep == null:
		_pre_start()
	elif _args.has("uncapped"):
		_run_steps(UNCAPPED_STEPS)
	if _lockstep != null and not _ending: _receive(_transport.poll())

func _physics_process(_delta: float) -> void:
	if _lockstep != null and not _ending and not _args.has("uncapped"): _run_steps(CAPPED_STEPS)

func _pre_start() -> void:
	if _transport.closed():
		_finish("ended_relay", "connection to relay lost")
	elif _transport.is_open() and not _hello_sent:
		_hello_sent = true
		var build: String = _args.get("build", str(ProjectSettings.get_setting("application/config/version")))
		var hello: Dictionary = {"type": "hello", "protocol": Wire.PROTOCOL, "build": build, "match": "" if _args.get("match", "new") == "new" else _args["match"]}
		if _args.get("match", "new") == "new": hello["settings"] = MatchSettings.for_map(_map_id())
		_transport.send_text(Wire.encode(hello))

func _receive(frames: PackedStringArray) -> void:
	for text in frames:
		if _ending: return
		if _lockstep != null:
			_lockstep.receive(text)
			continue
		var decoded: Dictionary = Wire.decode(text)
		if not decoded.ok:
			_finish("ended_protocol", decoded.error)
			return
		var message: Dictionary = decoded.message
		match message.type:
			"welcome": _welcome(message)
			"start": _start(message)
			"error": _finish("ended_relay", message.reason)
			_: _finish("ended_protocol", "unexpected " + message.type)

func _welcome(message: Dictionary) -> void:
	_seat = message.seat
	print("NETCLIENT WELCOME SEAT ", _seat, " CODE ", message.match, " AT ", _now_ms())
	if _args.has("probe-relay"):
		print("RELAY WELCOME ", Time.get_ticks_msec() - _connect_msec)
		_finish("probed", "")
		return
	if _args.has("code-file"):
		var temp: String = str(_args["code-file"]) + ".tmp"
		var file := FileAccess.open(temp, FileAccess.WRITE)
		file.store_string(message.match)
		file.close()
		DirAccess.rename_absolute(temp, _args["code-file"])

func _map_id() -> String:
	return _args.get("map", MatchSettings.TEST_MAP)

func _start(message: Dictionary) -> void:
	var settings: Dictionary = message.settings.duplicate()
	if _args.has("perturb-map-hash") and _seat == 2: settings["map_hash"] = str(settings.get("map_hash", "")) + "x"
	var reason: String = MatchSettings.refusal(settings)
	if not reason.is_empty():
		_finish("ended_settings", reason)
		return
	var seats: Array[int] = []
	seats.assign(message.seats)
	var id: String = message.settings.map
	_match_map = id
	_match_seed = message.seed
	_chosen = MatchSettings.starts(id, _match_seed)
	print("NETCLIENT MAP ", id, " SEED ", message.seed, " STARTS ", ",".join(_chosen.map(str)) if not _chosen.is_empty() else "-")
	_sim = _match_sim(id, _chosen)
	_lockstep = Lockstep.new(_seat, seats, message.delay)
	_lockstep.send = _transport.send_text
	_lockstep.submit({"type": "choose_faction", "faction": _args.get("faction", Skirmish.default_faction())})
	_lockstep.start(_sim.snapshot())

func _match_sim(id: String, chosen: Array[int]) -> Simulation:
	return Skirmish.create(true, "human", {}, MatchSettings.map_path(id), chosen)

func _oracle_sim() -> Simulation:
	var id: String = _map_id()
	var chosen: Array[int] = MatchSettings.starts(id, int(_args.get("seed", "0")))
	if not _args.has("factions"): return _match_sim(id, chosen)
	var names: PackedStringArray = str(_args["factions"]).split(",")
	return Skirmish.create(true, "ai", {1: names[0], 2: names[1]}, MatchSettings.map_path(id), chosen)

func _run_steps(limit: int) -> void:
	for i in limit:
		if _ending: return
		if _transport.closed(): _lockstep.set_relay_lost()
		if _sim.match_over():
			_finish("match_over", "")
			return
		if _lockstep.status().begins_with("ended"):
			_finish(_lockstep.status(), _lockstep.end_reason())
			return
		if not _step_once(): break

func _step_once() -> bool:
	var tick: int = _sim.tick()
	if _lockstep.can_step(tick):
		if _test_hooks(tick): return false
		_run_script()
	if not _lockstep.advance(_sim):
		if _lockstep.status().begins_with("ended"): _finish(_lockstep.status(), _lockstep.end_reason())
		return false
	var after: int = _sim.tick()
	_lockstep.finish_tick(after, _sim.snapshot() if _lockstep.wants_snapshot(after) else null)
	return true

func _run_script() -> void:
	var seat_sim: RefCounted = SeatSim.new(_sim, _lockstep)
	match _args.get("seat-script", "idle"):
		"human":
			if _seat == 1: ScriptedHuman.issue(seat_sim)
			else: _finish("ended_protocol", "human script needs seat 1")
		"opponent": Skirmish.issue_opponent(seat_sim, _seat)

func _test_hooks(tick: int) -> bool:
	if _int_arg("perturb-at-tick") == tick: _sim._players[_seat].credits += 1
	if _int_arg("stop-at-tick") == tick:
		_finish("stopped", "")
		return true
	if _int_arg("exit-at-tick") == tick:
		_transport.poll()
		OS.kill(OS.get_process_id())
	if _int_arg("stall-at-tick") == tick and not _stalled:
		_stalled = true
		print("NETCLIENT STALL AT ", _now_ms())
		OS.delay_msec(int(float(_args.get("stall-seconds", "1")) * 1000.0))
		_receive(_transport.poll())
	return false

func _finish(status: String, reason: String) -> void:
	if _ending: return
	_ending = true
	_status = status
	_reason = reason
	if _lockstep != null:
		_write_logs()
		_lockstep.send = Callable()
	if _transport != null and _transport.is_open():
		_transport.close()
		_closing_since = maxi(Time.get_ticks_msec(), 1)
	else:
		_exit()

func _exit() -> void:
	_closing_since = 0
	var tick: int = _sim.tick() if _sim != null else 0
	print("NETCLIENT TIME ", _now_ms())
	print("NETCLIENT END ", _status, " TICK ", tick, " REASON ", _reason)
	get_tree().quit(0)

func _write_logs() -> void:
	if _args.has("hash-log"): _write_lines(_args["hash-log"], _lockstep.hash_rows())
	if _args.has("command-log"): _write_lines(_args["command-log"], Lockstep.log_lines(_lockstep.command_log()))
	if _status == "ended_desync" and _args.has("report-dir"):
		var file := FileAccess.open("%s/desync-seat%d.json" % [_args["report-dir"], _seat], FileAccess.WRITE)
		if file == null: return
		var report: Dictionary = _lockstep.desync_report()
		report.merge(MatchSettings.report_fields(_match_map, _match_seed, _chosen))
		file.store_string(JSON.stringify(report, "", true, true))
		file.close()

func _replay_oracle() -> void:
	var by_tick: Dictionary = {}
	for line in FileAccess.get_file_as_string(_args["replay-log"]).split("\n", false):
		var decoded: Dictionary = Wire.decode(line)
		if not decoded.ok:
			_status = "ended_protocol"
			_reason = decoded.error
			_exit()
			return
		by_tick[decoded.message.tick] = decoded.message.commands
	var every: int = _int_arg("hash-every") if _args.has("hash-every") else 30
	var max_ticks: int = _int_arg("oracle-ticks") if _args.has("oracle-ticks") else ORACLE_MAX_TICKS
	var sim: Simulation = _oracle_sim()
	_sim = sim
	var rows := PackedStringArray(["0\t" + StateHash.digest(sim.snapshot())])
	var state_ticks: PackedStringArray = str(_args.get("state-ticks", "")).split(",", false)
	while not sim.match_over() and sim.tick() < max_ticks:
		if state_ticks.has(str(sim.tick())): _state_row(sim)
		for command: Variant in by_tick.get(sim.tick(), []): sim.issue_command(command)
		sim.step()
		if sim.tick() % every == 0: rows.append("%d\t%s" % [sim.tick(), StateHash.digest(sim.snapshot())])
	if state_ticks.has(str(sim.tick())): _state_row(sim)
	if _args.has("hash-log"): _write_lines(_args["hash-log"], rows)
	_status = "match_over" if sim.match_over() else "oracle_overrun"
	print("ORACLE FINAL %d %s" % [sim.tick(), StateHash.digest(sim.snapshot())])
	_exit()

func _state_row(sim: Simulation) -> void:
	var state: Dictionary = sim.snapshot()
	var row: String = "ORACLE STATE %d %s %s" % [state.tick, StateHash.digest(state), state_summary(state)]
	state_rows.append(row)
	print(row)
	if not _args.has("snapshot-dir"): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_args["snapshot-dir"]))
	var file := FileAccess.open("%s/tick-%d.json" % [_args["snapshot-dir"], state.tick], FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(state))
	file.close()

static func state_summary(snapshot: Dictionary) -> String:
	var units: Dictionary = {}
	var buildings: Dictionary = {}
	for unit: Dictionary in snapshot.entities: units[str(unit.owner)] = units.get(str(unit.owner), 0) + 1
	for building: Dictionary in snapshot.buildings: buildings[str(building.owner)] = buildings.get(str(building.owner), 0) + 1
	var players: Array = snapshot.players.map(func(player: Dictionary) -> Dictionary: return {"id": player.id, "credits": player.credits})
	return JSON.stringify({"match": snapshot.match.status, "players": players, "units": units, "buildings": buildings}, "", true)

func _write_lines(path: String, lines: PackedStringArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return
	file.store_string("\n".join(lines) + "\n")
	file.close()

func _factions_error() -> String:
	if not _args.has("factions"): return ""
	var names: PackedStringArray = str(_args["factions"]).split(",")
	var known: String = ", ".join(Registry.Factions.FACTIONS.keys())
	if names.size() != 2: return "--factions needs two entries A,B; expected each of: %s" % known
	for entry in names:
		if Registry.faction(entry).is_empty(): return "Unknown --factions entry '%s'; expected one of: %s" % [entry, known]
	return ""

func _int_arg(key: String) -> int:
	return int(_args[key]) if _args.has(key) else -1

func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func _faction_error() -> String:
	var listed: String = _factions_error()
	if listed != "": return listed
	var faction: String = _args.get("faction", Skirmish.default_faction())
	return "" if not Registry.faction(faction).is_empty() else "Unknown --faction '%s'; expected one of: %s" % [faction, ", ".join(Registry.Factions.FACTIONS.keys())]

func _parse(raw: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = {}
	var i: int = 0
	while i < raw.size():
		var key: String = raw[i].trim_prefix("--")
		if i + 1 < raw.size() and not raw[i + 1].begins_with("--"):
			parsed[key] = raw[i + 1]
			i += 2
		else:
			parsed[key] = "true"
			i += 1
	return parsed

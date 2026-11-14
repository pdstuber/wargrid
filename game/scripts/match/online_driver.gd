extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const TimingStats = preload("res://scripts/debug/timing_stats.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const CATCH_UP_STEPS: int = 2
const MAX_CATCH_UP_CREDIT: int = 4
const DESYNC_DIR: String = "user://desync"
const LATENCY_FILE: String = "user://netplay-latency.txt"

var sim: Simulation
var web: bool = OS.has_feature("web")
var download: Callable = JavaScriptBridge.download_buffer
var _transport: RefCounted
var _lockstep: RefCounted
var _own_faction: String
var _map_path: String = ""
var _starts: Array[int] = []
var _seed: int = 0
var _report_path: String = ""
var _finished: bool = false
var _credit: int = 0
var _rejections_seen: int = 0
var _step_results: Array = []

func _init(transport: RefCounted, lockstep: RefCounted, _seat: int, faction: String) -> void:
	_transport = transport
	_lockstep = lockstep
	_own_faction = faction

func create(map_path: String, starts: Array[int], _factions: Dictionary, match_seed: int) -> void:
	_map_path = map_path
	_starts = starts
	_seed = match_seed
	sim = Skirmish.create(true, "human", {}, map_path, starts)

func start() -> void:
	_lockstep.send = _transport.send_text
	_lockstep.submit({"type": "choose_faction", "faction": _own_faction})
	_lockstep.start(sim.snapshot())

func detach() -> void:
	if _lockstep != null: _lockstep.send = Callable()

func leave() -> void:
	_finished = true
	_lockstep.set_relay_lost()
	_transport.close()

func step(after_tick: Callable) -> PackedStringArray:
	for text: Variant in _transport.poll(): _lockstep.receive(text)
	if not _finished and (_transport.closed() or _transport.silent(Time.get_ticks_usec())): _lockstep.set_relay_lost()
	_credit = mini(_credit + 1, MAX_CATCH_UP_CREDIT)
	_step_results = []
	for i in CATCH_UP_STEPS:
		if _credit < 1 or not _lockstep.advance(sim): break
		_credit -= 1
		after_tick.call()
		_step_results.append_array(sim.command_results().duplicate(true))
		var tick: int = sim.tick()
		_lockstep.finish_tick(tick, sim.snapshot() if _lockstep.wants_snapshot(tick) else null)
	var rejected: PackedStringArray = _new_rejections()
	if not _finished and (sim.match_over() or _lockstep.status().begins_with("ended")): _finish()
	return rejected

func step_results() -> Array:
	return _step_results

func _new_rejections() -> PackedStringArray:
	var errors := PackedStringArray()
	var rejections: Array = _lockstep.rejections()
	if rejections.size() > _rejections_seen:
		for i in range(_rejections_seen, rejections.size()): errors.append(rejections[i].error)
		_rejections_seen = rejections.size()
	return errors

func submit(payload: Dictionary) -> Dictionary:
	_lockstep.submit(payload)
	return {"ok": true, "error": ""}

func pauses_sim() -> bool:
	return false

func confirm_leave() -> bool:
	return true

func can_restart() -> bool:
	return false

func over() -> bool:
	return _finished

func match_log() -> Dictionary:
	var seats: Array = sim.view_state().players.map(func(player: Dictionary) -> String: return player.get("faction", ""))
	return {"mode": "online", "factions": seats, "commands": Lockstep.log_lines(_lockstep.command_log())}

func _finish() -> void:
	_finished = true
	if _lockstep.status() == "ended_desync": _report_path = _write_report()
	_write_latency()
	_transport.close()

func _write_report() -> String:
	var report: Dictionary = _report()
	var file_name: String = "desync-seat%d.json" % report.seat
	if web:
		download.call(JSON.stringify(report, "", true, true).to_utf8_buffer(), file_name, "application/json")
		return file_name
	DirAccess.make_dir_recursive_absolute(DESYNC_DIR)
	var path: String = "%s/%s" % [DESYNC_DIR, file_name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return ""
	file.store_string(JSON.stringify(report, "", true, true))
	file.close()
	return ProjectSettings.globalize_path(path)

func _report() -> Dictionary:
	var report: Dictionary = _lockstep.desync_report(sim)
	report.merge(MatchSettings.report_fields(_map_path.get_file().get_basename(), _seed, _starts))
	return report

func net_line() -> String:
	var latency: Dictionary = TimingStats.summary(_ms(_lockstep.latency_samples()))
	var rtt: Dictionary = TimingStats.summary(_ms(_transport.rtt_samples()))
	return "Cmd latency p95 %.0f ms | RTT p95 %.0f ms" % [latency.p95, rtt.p95]

func _write_latency() -> void:
	var line: String = latency_line()
	print(line)
	var file := FileAccess.open(LATENCY_FILE, FileAccess.WRITE)
	if file == null: return
	file.store_string(line + "\n")
	file.close()

func latency_line() -> String:
	var latency: Dictionary = TimingStats.summary(_ms(_lockstep.latency_samples()))
	var rtt: Dictionary = TimingStats.summary(_ms(_transport.rtt_samples()))
	return "NETPLAY LATENCY command n=%d p50=%.1f ms p95=%.1f ms | RTT n=%d p95=%.1f ms" % [latency.n, latency.p50, latency.p95, rtt.n, rtt.p95]

func _ms(microseconds: PackedInt64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for value in microseconds: out.append(float(value) / 1000.0)
	return out

func notice() -> String:
	match _lockstep.status():
		"waiting": return "Waiting for player %d" % _lockstep.waiting_for()[0]
		"ended_left": return "Opponent left before the start (a different map or version, or their game tab was hidden)" if _lockstep.left_before_start() else "Player %d disconnected" % _lockstep.left_seat()
		"ended_relay": return "Connection to relay lost" if _lockstep.end_reason() == "connection to relay lost" else "Relay: " + _lockstep.end_reason()
		"ended_desync": return ("Desync — report downloaded as %s" if web else "Desync — report saved to %s") % _report_path
		"ended_protocol": return "Protocol error: " + _lockstep.end_reason()
	return ""

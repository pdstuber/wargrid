extends "res://scripts/skirmish_main.gd"

const TimingStats = preload("res://scripts/debug/timing_stats.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const CATCH_UP_STEPS: int = 2
const MAX_CATCH_UP_CREDIT: int = 4
const DESYNC_DIR: String = "user://desync"
const LATENCY_FILE: String = "user://netplay-latency.txt"
var _transport: RefCounted
var _lockstep: RefCounted
var _report_path: String = ""
var web: bool = OS.has_feature("web")
var download: Callable = JavaScriptBridge.download_buffer
var _finished: bool = false
var _credit: int = 0
var _rejections_seen: int = 0
var _faction: String = Skirmish.default_faction()

func setup(transport: RefCounted, lockstep: RefCounted, seat: int, faction: String = Skirmish.default_faction()) -> void:
	_faction = faction
	_transport = transport
	_lockstep = lockstep
	local_player = seat

func _ready() -> void:
	super._ready()
	_perf.extra = _net_line
	_lockstep.send = _transport.send_text
	_lockstep.submit({"type": "choose_faction", "faction": _faction})
	_lockstep.start(simulation.snapshot())

func _exit_tree() -> void:
	if _lockstep != null: _lockstep.send = Callable()

func _create_simulation() -> Simulation:
	return Skirmish.create(true, "human", {}, map_path, starts)

func _confirm_leave() -> bool:
	return true

func _pauses_sim() -> bool:
	return false

func _leave() -> void:
	_finished = true
	_lockstep.set_relay_lost()
	_transport.close()
	super()

func _step_simulation() -> void:
	for text: Variant in _transport.poll(): _lockstep.receive(text)
	if not _finished and (_transport.closed() or _transport.silent(Time.get_ticks_usec())): _lockstep.set_relay_lost()
	_credit = mini(_credit + 1, MAX_CATCH_UP_CREDIT)
	for i in CATCH_UP_STEPS:
		if _credit < 1 or not _lockstep.advance(simulation): break
		_credit -= 1
		_collect_sound()
		var tick: int = simulation.tick()
		_lockstep.finish_tick(tick, simulation.snapshot() if _lockstep.wants_snapshot(tick) else null)
	var rejections: Array = _lockstep.rejections()
	if rejections.size() > _rejections_seen:
		_ensure_sound()
		for i in range(_rejections_seen, rejections.size()): _sound.rejected(rejections[i].error)
		_error = "Rejected: " + rejections.back().error
		_rejections_seen = rejections.size()
	if not _finished and (simulation.match_over() or _lockstep.status().begins_with("ended")): _finish()

func playtest_context() -> Dictionary:
	var context: Dictionary = super()
	context.over = _finished
	return context

func playtest_match() -> Dictionary:
	var seats: Array = simulation.view_state().players.map(func(player: Dictionary) -> String: return player.get("faction", ""))
	return _match_record("online", seats, Lockstep.log_lines(_lockstep.command_log()))

func _submit(payload: Dictionary) -> void:
	_show_hint(payload)
	_error = ""
	_lockstep.submit(payload)
	_playtest.observe_command(payload)
	_refresh()
	_sound.order(payload)

func _restart() -> void:
	pass

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
	var report: Dictionary = _lockstep.desync_report()
	report.merge(MatchSettings.report_fields(map_path.get_file().get_basename(), match_seed, starts))
	return report

func _net_line() -> String:
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
		"ended_left": return "Opponent left before the start (different map files or version)" if _lockstep.left_before_start() else "Player %d disconnected" % _lockstep.left_seat()
		"ended_relay": return "Connection to relay lost" if _lockstep.end_reason() == "connection to relay lost" else "Relay: " + _lockstep.end_reason()
		"ended_desync": return ("Desync — report downloaded as %s" if web else "Desync — report saved to %s") % _report_path
		"ended_protocol": return "Protocol error: " + _lockstep.end_reason()
	return ""

func _note() -> String:
	return _error + notice()

func _refresh_hud(state: Dictionary) -> void:
	super._refresh_hud(state)
	var line: String = notice()
	if not line.is_empty(): _status.text += "\n" + line
	$HUD/Restart.hide()

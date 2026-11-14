@warning_ignore_start("untyped_declaration")
class_name WargridTestRunner
extends SceneTree

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const SUITES = [preload("res://tests/test_combat.gd"), preload("res://tests/test_combat_navigation.gd"), preload("res://tests/test_base_scene.gd"), preload("res://tests/test_supply.gd"), preload("res://tests/test_production.gd"), preload("res://tests/test_construction.gd"), preload("res://tests/test_economy.gd"), preload("res://tests/test_simulation.gd"), preload("res://tests/test_isometric.gd"), preload("res://tests/test_navigation.gd"), preload("res://tests/test_movement.gd"), preload("res://tests/test_view.gd"), preload("res://tests/test_scene.gd"), preload("res://tests/test_replay.gd"), preload("res://tests/test_skirmish.gd"), preload("res://tests/test_skirmish_match.gd"), preload("res://tests/test_skirmish_scene.gd"), preload("res://tests/test_groups.gd"), preload("res://tests/test_repath.gd"), preload("res://tests/test_benchmark.gd"), preload("res://tests/test_state_hash.gd"), preload("res://tests/test_wire.gd"), preload("res://tests/test_lockstep.gd"), preload("res://tests/test_relay_transport.gd"), preload("res://tests/test_online_scene.gd"), preload("res://tests/test_profiler.gd"), preload("res://tests/test_map.gd"), preload("res://tests/test_teams.gd"), preload("res://tests/test_team_match.gd"), preload("res://tests/test_locomotion.gd"), preload("res://tests/test_allocation.gd"), preload("res://tests/test_navigation_incremental.gd"), preload("res://tests/test_factions.gd"), preload("res://tests/test_containers.gd"), preload("res://tests/test_defences.gd"), preload("res://tests/test_skirmish_waves.gd"), preload("res://tests/test_horde.gd"), preload("res://tests/test_ramp.gd"), preload("res://tests/test_perf_overlay.gd"), preload("res://tests/test_pause_menu.gd"), preload("res://tests/test_runner.gd"), preload("res://tests/test_logo.gd"), preload("res://tests/test_rebuild_holes.gd"), preload("res://tests/test_salvage.gd"), preload("res://tests/test_tunnels.gd"), preload("res://tests/test_supply_parity.gd"), preload("res://tests/test_sound.gd"), preload("res://tests/test_announcer.gd"), preload("res://tests/test_audio_settings.gd"), preload("res://tests/test_start_spots.gd"), preload("res://tests/test_match_settings.gd"), preload("res://tests/test_credits.gd"), preload("res://tests/test_shapes.gd"), preload("res://tests/test_shape_audit.gd"), preload("res://tests/test_world_batch.gd"), preload("res://tests/test_visual.gd"), preload("res://tests/test_graphics_settings.gd"), preload("res://tests/test_art_lab.gd"), preload("res://tests/test_presentation_clock.gd"), preload("res://tests/test_view_rows.gd"), preload("res://tests/test_playtest_replay.gd"), preload("res://tests/test_playtest.gd"), preload("res://tests/test_playtest_overlay.gd"), preload("res://tests/test_income_openings.gd"), preload("res://tests/test_dock_lock.gd"), preload("res://tests/test_order_voice.gd"), preload("res://tests/test_join_link.gd"), preload("res://tests/test_launcher.gd")]
var checks: int = 0
var failures: int = 0
var case_count: int = 0
var _active_case: String = "startup"
const WATCHDOG_SECONDS: int = 480 # real time, not frames: a case that blocks between frames must still be caught
var _watchdog := Thread.new()
var _watchdog_stop: bool = false
var _case_lock := Mutex.new()
# The slowest process bounds the run, so the long cases are dealt first and spread.
const CASE_SECONDS := {"test_team_match_prefix": 44.8, "test_frc_skirmish_match": 11.7, "test_mirror_match_script": 8.2, "test_china_skirmish_match": 4.7, "test_horde_render_layout": 4.2, "test_skirmish_core_series": 4.2, "test_settled_matches_snapshot_predicate": 4.2, "test_rows_equal_snapshot": 3.8, "test_openings_deposit": 3.0, "test_report_rows": 2.9, "test_multi_collector_rates": 2.8, "test_combat_fixtures": 1.9, "test_bot_counts_queued_collectors": 1.9, "test_team_match_pair": 1.1, "test_view_reads_digest_is_pinned": 1.1}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)

static func shard(count: int, args: PackedStringArray, costs: PackedFloat64Array = PackedFloat64Array()) -> Array[int]:
	var index: int = 0
	var total: int = 1
	for arg in args:
		if arg.begins_with("--shard="):
			var parts: PackedStringArray = arg.trim_prefix("--shard=").split("/")
			if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
				return []
			index = int(parts[0])
			total = int(parts[1])
	var picked: Array[int] = []
	if total < 1 or index < 0 or index >= total:
		return picked
	var order: Array[int] = []
	order.assign(range(count))
	order.sort_custom(func(a: int, b: int) -> bool: return _cost(costs, a) > _cost(costs, b) or (_cost(costs, a) == _cost(costs, b) and a < b))
	var busy: PackedFloat64Array = PackedFloat64Array()
	busy.resize(total)
	for i in order:
		var lightest: int = 0
		for p in range(1, total):
			if busy[p] < busy[lightest]:
				lightest = p
		busy[lightest] += _cost(costs, i)
		if lightest == index:
			picked.append(i)
	picked.sort()
	return picked

static func _cost(costs: PackedFloat64Array, i: int) -> float:
	return costs[i] if i < costs.size() else 1.0

static func only_filter(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with("--only="):
			return arg.trim_prefix("--only=")
	return ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	AudioSettings.path = "user://test-settings-%d.cfg" % OS.get_process_id() # a developer machine's real volumes must not reach the suite
	PlaytestSession.dir = "user://test-runner-playtests-%d" % OS.get_process_id() # scene tests resume and write sittings; the player's real one must stay untouched
	if current_scene != null: # exported builds also load the main scene (the launcher), whose UI swallows test clicks
		current_scene.free()
	_watchdog.start(_watch.bind(Time.get_ticks_msec() + WATCHDOG_SECONDS * 1000))
	var suites: Array = [] # a Callable does not keep its RefCounted suite alive
	var tests: Array[Callable] = []
	var only: String = only_filter(OS.get_cmdline_user_args())
	for suite_script in SUITES:
		if not suite_script.can_instantiate():
			print("FAIL: suite failed to load ", suite_script.resource_path)
			_stop_watchdog()
			quit(1)
			return
		var suite = suite_script.new()
		suites.append(suite)
		var selected: Array[Callable] = suite.cases()
		if selected.is_empty():
			failures += 1
			print("FAIL: zero tests in suite")
		for test in selected:
			if only.is_empty() or suite_script.resource_path.contains(only) or test.get_method().contains(only):
				tests.append(test)
	var costs: PackedFloat64Array = PackedFloat64Array()
	for test in tests:
		costs.append(CASE_SECONDS.get(test.get_method(), 0.1))
	for i in shard(tests.size(), OS.get_cmdline_user_args(), costs):
		var test: Callable = tests[i]
		_case_lock.lock()
		_active_case = test.get_method()
		_case_lock.unlock()
		case_count += 1
		var before: int = checks
		var completed: Variant = await test.call(self)
		if completed is not bool or completed != true or checks == before:
			failures += 1
			print("FAIL: incomplete/empty case ", test.get_method())
	if checks == 0 or case_count == 0:
		failures += 1
		print("FAIL: zero tests/checks")
	remove_dir(PlaytestSession.dir)
	await create_timer(0.5).timeout # the audio thread frees stopped playbacks asynchronously; quitting sooner leaks them
	print("CASES ", case_count, " CHECKS ", checks, " FAILURES ", failures)
	if failures == 0:
		print("TESTS PASSED ", checks)
	_stop_watchdog()
	quit(0 if failures == 0 else 1)

static func remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	for file in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)

func _stop_watchdog() -> void:
	_watchdog_stop = true
	_watchdog.wait_to_finish()

func _watch(deadline_ms: int) -> void:
	while not _watchdog_stop and Time.get_ticks_msec() < deadline_ms:
		OS.delay_msec(200)
	if _watchdog_stop:
		return
	_case_lock.lock()
	var active: String = _active_case
	_case_lock.unlock()
	print("FAIL: watchdog timeout in ", active)
	remove_dir(PlaytestSession.dir)
	OS.kill(OS.get_process_id())

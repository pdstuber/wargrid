@warning_ignore_start("untyped_declaration")
class_name WargridTestRunner
extends SceneTree

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const SUITES = [preload("res://tests/test_combat.gd"), preload("res://tests/test_combat_navigation.gd"), preload("res://tests/test_base_scene.gd"), preload("res://tests/test_supply.gd"), preload("res://tests/test_production.gd"), preload("res://tests/test_construction.gd"), preload("res://tests/test_economy.gd"), preload("res://tests/test_simulation.gd"), preload("res://tests/test_isometric.gd"), preload("res://tests/test_navigation.gd"), preload("res://tests/test_movement.gd"), preload("res://tests/test_view.gd"), preload("res://tests/test_scene.gd"), preload("res://tests/test_replay.gd"), preload("res://tests/test_skirmish.gd"), preload("res://tests/test_skirmish_match.gd"), preload("res://tests/test_skirmish_scene.gd"), preload("res://tests/test_groups.gd"), preload("res://tests/test_repath.gd"), preload("res://tests/test_benchmark.gd"), preload("res://tests/test_state_hash.gd"), preload("res://tests/test_wire.gd"), preload("res://tests/test_lockstep.gd"), preload("res://tests/test_relay_transport.gd"), preload("res://tests/test_online_scene.gd"), preload("res://tests/test_profiler.gd"), preload("res://tests/test_map.gd"), preload("res://tests/test_teams.gd"), preload("res://tests/test_team_match.gd"), preload("res://tests/test_locomotion.gd"), preload("res://tests/test_allocation.gd"), preload("res://tests/test_navigation_incremental.gd"), preload("res://tests/test_factions.gd"), preload("res://tests/test_containers.gd"), preload("res://tests/test_defences.gd"), preload("res://tests/test_skirmish_waves.gd"), preload("res://tests/test_horde.gd"), preload("res://tests/test_ramp.gd"), preload("res://tests/test_perf_overlay.gd"), preload("res://tests/test_pause_menu.gd"), preload("res://tests/test_runner.gd"), preload("res://tests/test_logo.gd"), preload("res://tests/test_rebuild_holes.gd"), preload("res://tests/test_salvage.gd"), preload("res://tests/test_tunnels.gd"), preload("res://tests/test_supply_parity.gd"), preload("res://tests/test_sound.gd"), preload("res://tests/test_announcer.gd"), preload("res://tests/test_audio_settings.gd"), preload("res://tests/test_start_spots.gd"), preload("res://tests/test_match_settings.gd")]
var checks: int = 0
var failures: int = 0
var case_count: int = 0
var _active_case: String = "startup"

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)

static func shard(count: int, args: PackedStringArray) -> Array[int]:
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
	for i in range(count):
		if i % total == index:
			picked.append(i)
	return picked

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	AudioSettings.path = "user://test-settings.cfg" # a developer machine's real volumes must not reach the suite
	if current_scene != null: # exported builds also load the main scene (the launcher), whose UI swallows test clicks
		current_scene.free()
	create_timer(60.0).timeout.connect(_timeout)
	var suites: Array = [] # a Callable does not keep its RefCounted suite alive
	var tests: Array[Callable] = []
	for suite_script in SUITES:
		var suite = suite_script.new()
		suites.append(suite)
		var selected: Array[Callable] = suite.cases()
		if selected.is_empty():
			failures += 1
			print("FAIL: zero tests in suite")
		tests.append_array(selected)
	for i in shard(tests.size(), OS.get_cmdline_user_args()):
		var test: Callable = tests[i]
		_active_case = test.get_method()
		case_count += 1
		var before: int = checks
		var completed: Variant = await test.call(self)
		if completed is not bool or completed != true or checks == before:
			failures += 1
			print("FAIL: incomplete/empty case ", test.get_method())
	if checks == 0 or case_count == 0:
		failures += 1
		print("FAIL: zero tests/checks")
	print("CASES ", case_count, " CHECKS ", checks, " FAILURES ", failures)
	if failures == 0:
		print("TESTS PASSED ", checks)
	quit(0 if failures == 0 else 1)

func _timeout() -> void:
	print("FAIL: watchdog timeout in ", _active_case)
	quit(1)

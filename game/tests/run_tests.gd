class_name WargridTestRunner
extends SceneTree

const Suites = [preload("res://tests/test_combat.gd"), preload("res://tests/test_combat_navigation.gd"), preload("res://tests/test_base_scene.gd"), preload("res://tests/test_supply.gd"), preload("res://tests/test_production.gd"), preload("res://tests/test_construction.gd"), preload("res://tests/test_economy.gd"), preload("res://tests/test_simulation.gd"), preload("res://tests/test_isometric.gd"), preload("res://tests/test_navigation.gd"), preload("res://tests/test_movement.gd"), preload("res://tests/test_view.gd"), preload("res://tests/test_scene.gd"), preload("res://tests/test_replay.gd"), preload("res://tests/test_skirmish.gd"), preload("res://tests/test_skirmish_match.gd"), preload("res://tests/test_skirmish_scene.gd"), preload("res://tests/test_groups.gd"), preload("res://tests/test_repath.gd"), preload("res://tests/test_benchmark.gd"), preload("res://tests/test_state_hash.gd"), preload("res://tests/test_wire.gd"), preload("res://tests/test_lockstep.gd"), preload("res://tests/test_relay_transport.gd"), preload("res://tests/test_online_scene.gd"), preload("res://tests/test_profiler.gd")]
var checks: int = 0
var failures: int = 0
var case_count: int = 0
var _active_case: String = "startup"

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if current_scene != null: # exported builds also load the main scene (the launcher), whose UI swallows test clicks
		current_scene.free()
	create_timer(60.0).timeout.connect(_timeout)
	for suite_script in Suites:
		var suite = suite_script.new()
		var selected: Array[Callable] = suite.cases()
		if selected.is_empty():
			failures += 1
			print("FAIL: zero tests in suite")
		for test in selected:
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

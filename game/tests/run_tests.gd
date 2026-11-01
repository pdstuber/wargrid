extends SceneTree

const Suites = [preload("res://tests/test_simulation.gd")]
var checks: int = 0
var failures: int = 0
var case_count: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)

func _initialize() -> void:
	for suite_script in Suites:
		var suite = suite_script.new()
		var selected: Array[Callable] = suite.cases()
		if selected.is_empty():
			failures += 1
			print("FAIL: zero tests in suite")
		for test in selected:
			case_count += 1
			var before: int = checks
			var completed: Variant = test.call(self)
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

@warning_ignore_start("untyped_declaration")
extends RefCounted

const Profiler = preload("res://scripts/debug/profiler.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")

func cases() -> Array[Callable]:
	return [test_disabled_records_nothing, test_enabled_series_and_report, test_profiling_keeps_determinism]

func test_disabled_records_nothing(runner) -> bool:
	Profiler.reset()
	Profiler.enabled = false
	Profiler.end(&"probe", Profiler.begin())
	Profiler.end_tick()
	runner.check(Profiler.calls(&"probe") == 0 and Profiler.ticks() == 0, "P1 disabled profiler records nothing")
	runner.check(Profiler.report("off").is_empty(), "P1 disabled report is empty")
	return true

func test_enabled_series_and_report(runner) -> bool:
	Profiler.reset()
	Profiler.enabled = true
	Profiler.end_tick()
	for i in range(3):
		Profiler.end(&"outer", Profiler.begin() - 2000)
		Profiler.end(&"inner", Profiler.begin())
		Profiler.end_tick()
	Profiler.enabled = false
	var lines: PackedStringArray = Profiler.report("t", &"outer")
	runner.check(Profiler.ticks() == 4 and Profiler.calls(&"outer") == 3, "P2 counts ticks and calls")
	runner.check(Profiler.series(&"outer").size() == 4 and Profiler.series(&"outer")[0] == 0.0, "P2 late zone is zero-filled")
	runner.check(lines.size() == 2 and lines[0].contains("zone=outer") and lines[0].contains("share=100.0%"), "P2 report sorted by mean: %s" % lines)
	runner.check(Profiler.slow.size() == 3 and Profiler.slow[0].begins_with("1 outer "), "P2 slow calls logged with tick: %s" % Profiler.slow)
	Profiler.reset()
	return true

func _digest(enabled: bool) -> String:
	Profiler.reset()
	Profiler.enabled = enabled
	var sim: RefCounted = CombatWorkload.create("skirmish3v3")
	for tick in range(200):
		sim.step()
		Profiler.end_tick()
	Profiler.enabled = false
	return StateHash.digest(sim.snapshot())

func test_profiling_keeps_determinism(runner) -> bool:
	var off: String = _digest(false)
	var on: String = _digest(true)
	runner.check(Profiler.ticks() == 200 and Profiler.calls(&"step") == 200, "P3 profiled run recorded every step")
	runner.check(on == off, "P3 profiling leaves the digest unchanged: %s vs %s" % [on, off])
	Profiler.reset()
	return true

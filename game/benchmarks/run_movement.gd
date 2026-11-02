extends SceneTree

const Workload = preload("res://scripts/debug/movement_workload.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("M2 HEADLESS engine=", Engine.get_version_info().string, " os=", OS.get_name(),
		" cpu=", OS.get_processor_name(), " map=64x64 units=300 seed=none warmup_ticks=300 sample_ticks=1800 unpaced=true")
	for layout in ["open", "dense"]:
		if not _measure(layout):
			quit(1)
			return
	print("BENCHMARK PASSED 2")
	quit(0)

func _measure(layout: String) -> bool:
	var sim: RefCounted = Workload.create(layout)
	var samples := PackedFloat64Array()
	var command_samples := PackedFloat64Array()
	var leg: int = -1
	var leg_start: int = 0
	var queue_start: int = -1
	var queue_peak: int = 0
	var queue_drain: int = 0
	var completed: int = 0
	for tick in range(2100):
		var start: int = Time.get_ticks_usec()
		var command_tick: bool = leg == -1 or Workload.settled(sim)
		if command_tick:
			if leg >= 0:
				completed += 1
			leg += 1
			leg_start = tick
			queue_start = tick
			Workload.issue_leg(sim, leg)
		sim.step()
		var elapsed: float = (Time.get_ticks_usec() - start) / 1000.0
		if tick >= 300:
			samples.append(elapsed)
		if command_tick:
			command_samples.append(elapsed)
		var state: Dictionary = sim.snapshot()
		queue_peak = maxi(queue_peak, state.path_queue.size())
		if state.path_queue.is_empty() and queue_start >= 0:
			queue_drain = maxi(queue_drain, tick - queue_start + 1)
			queue_start = -1
		if not _valid(state, tick + 1 - leg_start):
			return false
	var timed_counts: Dictionary = _counts(sim.snapshot())
	var drain_ticks: int = 0
	while not Workload.settled(sim):
		sim.step()
		drain_ticks += 1
		if not _valid(sim.snapshot(), 2100 + drain_ticks - leg_start):
			return false
	completed += 1
	var destinations: Dictionary = {}
	for unit in sim.snapshot().entities:
		if unit.destination == null or unit.position != unit.destination:
			push_error("Benchmark did not arrive at destination")
			return false
		destinations[Vector2i(Vector2(unit.destination[0], unit.destination[1]).floor())] = true
	if destinations.size() != 300 or samples.size() != 1800 or completed < 1:
		push_error("Benchmark incomplete workload")
		return false
	var summary: Dictionary = Stats.summary(samples)
	print("HEADLESS ", layout, " tick_ms=", JSON.stringify(summary), " command_tick_ms=", JSON.stringify(Stats.summary(command_samples)),
		" queue_peak=", queue_peak, " queue_drain_ticks=", queue_drain, " timed_counts=", JSON.stringify(timed_counts),
		" completed_legs=", completed, " drain_ticks=", drain_ticks, " final_counts=", JSON.stringify(_counts(sim.snapshot())), " unique_destinations=", destinations.size())
	print("BUDGET ", "PASS" if summary.p95 <= 8.0 and summary.p99 <= 16.0 else "FAIL", " ", layout, " simulation_only")
	return true

func _valid(state: Dictionary, leg_ticks: int) -> bool:
	if leg_ticks > 3000:
		push_error("Benchmark leg exceeded 3000 ticks")
		return false
	for unit in state.entities:
		if unit.status == "blocked":
			push_error("Benchmark blocked unit " + str(unit.id))
			return false
	return true

func _counts(state: Dictionary) -> Dictionary:
	var counts := {"arrived": 0, "blocked": 0, "moving": 0, "path_pending": 0}
	for unit in state.entities:
		counts[unit.status] = counts.get(unit.status, 0) + 1
	return counts

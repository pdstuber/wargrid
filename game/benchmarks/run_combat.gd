extends SceneTree

const Workload = preload("res://scripts/debug/combat_workload.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")

const WARMUP: int = 300
const SAMPLES: int = 1800

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("M4 COMBAT HEADLESS engine=", Engine.get_version_info().string, " os=", OS.get_name(),
		" cpu=", OS.get_processor_name(), " map=64x64 units=150v150 warmup_ticks=", WARMUP, " sample_ticks=", SAMPLES, " unpaced=true")
	for layout in ["open", "dense", "contact"]:
		if not _measure(layout):
			quit(1)
			return
	print("COMBAT BENCHMARK PASSED 3")
	quit(0)

func _measure(layout: String) -> bool:
	var sim: RefCounted = Workload.create(layout)
	var samples := PackedFloat64Array()
	var warmup := PackedFloat64Array()
	var snapshots := PackedFloat64Array()
	var work := PackedFloat64Array()
	var allocations := PackedFloat64Array()
	var shots: int = 0
	var deaths: int = 0
	var first_shot: int = -1
	var start_units: int = sim.snapshot().entities.size()
	for tick in range(WARMUP + SAMPLES):
		var started: int = Time.get_ticks_usec()
		sim.step()
		var elapsed: float = (Time.get_ticks_usec() - started) / 1000.0
		var snapshot_started: int = Time.get_ticks_usec()
		var state: Dictionary = sim.snapshot()
		var snapshot_elapsed: float = (Time.get_ticks_usec() - snapshot_started) / 1000.0
		for event in state.combat_events:
			if event.type == "shot":
				shots += 1
				if first_shot == -1: first_shot = tick
			else:
				deaths += 1
		if tick < WARMUP:
			warmup.append(elapsed)
		else:
			samples.append(elapsed)
			snapshots.append(snapshot_elapsed)
			work.append(sim.combat_work())
			allocations.append(sim.allocation_calls())
	var alive: int = sim.snapshot().entities.size()
	var summary: Dictionary = Stats.summary(samples)
	print("COMBAT ", layout, " tick_ms=", JSON.stringify(summary), " warmup_tick_ms=", JSON.stringify(Stats.summary(warmup)), " snapshot_ms=", JSON.stringify(Stats.summary(snapshots)),
		" combat_work=", JSON.stringify(Stats.summary(work)), " allocation_calls=", JSON.stringify(Stats.summary(allocations)),
		" shots=", shots, " deaths=", deaths, " first_shot=", first_shot, " alive_start=", start_units, " alive_end=", alive)
	print("COMBAT BUDGET ", "PASS" if summary.p95 <= 1.67 and summary.p99 <= 3.3 else "FAIL", " ", layout, " simulation_only")
	if deaths == 0 or alive + deaths != start_units or (layout == "contact" and (first_shot == -1 or first_shot >= 60)):
		push_error("Combat benchmark workload invalid for " + layout)
		return false
	return true

extends SceneTree

const Profiler = preload("res://scripts/debug/profiler.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

const WARMUP: int = 300
const SAMPLES: int = 1800
const SIZES: Array[int] = [25, 50, 100, 200, 400]
const MIN_MEAN_MS: float = 0.005
const SUPERLINEAR_RATIO: float = 2.2

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("SCALING HEADLESS engine=", Engine.get_version_info().string, " os=", OS.get_name(), " cpu=", OS.get_processor_name(),
		" warmup_ticks=", WARMUP, " sample_ticks=", SAMPLES, " unpaced=true zones=inclusive profiled=true")
	var means: Dictionary = {}
	for per_side in SIZES:
		var row: Dictionary = _size(per_side)
		if row.is_empty():
			quit(1)
			return
		means[per_side] = row
	_growth(means)
	print("SCALING COMPLETE ", SIZES.size())
	quit(0)

func _size(per_side: int) -> Dictionary:
	var sim: Simulation = CombatWorkload.create("open", per_side)
	Profiler.reset()
	Profiler.enabled = true
	for tick in range(WARMUP):
		sim.step()
		Profiler.end_tick()
	Profiler.reset()
	var shots: int = 0
	for tick in range(SAMPLES):
		sim.step()
		Profiler.end_tick()
		for event: Dictionary in sim.combat_events():
			if event.type == "shot": shots += 1
	Profiler.enabled = false
	var splash_calls: int = Profiler.calls(&"combat.splash")
	var units: int = 2 * per_side
	if shots == 0 or splash_calls == 0:
		push_error("SCALING units=%d: no shot inside the timed window (shots=%d splash_calls=%d)" % [units, shots, splash_calls])
		return {}
	var step: Dictionary = Stats.summary(Profiler.series(&"step"))
	print("SCALING units=%d ticks=%d step_mean=%.4f step_p99=%.4f step_max=%.3f shots=%d splash_calls=%d" % [units, SAMPLES, Stats.mean(Profiler.series(&"step")), step.p99, step.max, shots, splash_calls])
	var zone_means: Dictionary = {}
	for zone: Variant in Profiler.zone_names():
		var mean: float = Stats.mean(Profiler.series(zone))
		zone_means[zone] = mean
		print("SCALING_ZONE units=%d zone=%s mean_ms=%.4f max_ms=%.3f" % [units, zone, mean, Stats.summary(Profiler.series(zone)).max])
	return zone_means

func _growth(means: Dictionary) -> void:
	var last: Dictionary = means[SIZES[-1]]
	var zones: Array = last.keys()
	zones.sort()
	var superlinear: PackedStringArray = PackedStringArray()
	for zone: Variant in zones:
		if last[zone] < MIN_MEAN_MS: continue
		var ratios: PackedStringArray = PackedStringArray()
		var last_two_over: bool = true
		for index in range(1, SIZES.size()):
			var before: float = means[SIZES[index - 1]].get(zone, 0.0)
			var ratio: float = means[SIZES[index]].get(zone, 0.0) / before if before > 0.0 else INF
			ratios.append("%.2f" % ratio)
			if index >= SIZES.size() - 2 and ratio <= SUPERLINEAR_RATIO: last_two_over = false
		if last_two_over: superlinear.append(String(zone))
		print("SCALING_GROWTH zone=%s ratios=%s superlinear=%s" % [zone, ",".join(ratios), "yes" if last_two_over else "no"])
	print("SCALING_SUPERLINEAR ", ",".join(superlinear) if not superlinear.is_empty() else "none")

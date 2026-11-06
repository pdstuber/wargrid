extends SceneTree

const Workload = preload("res://scripts/debug/combat_workload.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

const WARMUP: int = 300
const SAMPLES: int = 1800
# Report-only stress rows, pinned at the worst of 13 runs + 5% (user decision 2026-11-03); raise only with user approval and a ledger line.
const STRESS_CEILING := {"open": [2.05, 3.86], "dense": [2.52, 4.02]}
const BUDGET_P95_MS: float = 1.82
const BUDGET_P99_MS: float = 3.64

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("M4 COMBAT HEADLESS engine=", Engine.get_version_info().string, " os=", OS.get_name(),
		" cpu=", OS.get_processor_name(), " map=64x64 units=150v150/105v105 warmup_ticks=", WARMUP, " sample_ticks=", SAMPLES, " unpaced=true")
	for layout: String in ["open", "dense", "contact", "skirmish3v3"]:
		if not _measure(layout):
			quit(1)
			return
	print("COMBAT BENCHMARK PASSED 4")
	quit(0)

func _measure(layout: String) -> bool:
	var sim: Simulation = Workload.create(layout)
	var samples := PackedFloat64Array()
	var warmup := PackedFloat64Array()
	var snapshots := PackedFloat64Array()
	var work := PackedFloat64Array()
	var allocations := PackedFloat64Array()
	var warmup_chases: int = 0
	var window_chases: int = 0
	var window_retaliations: int = 0
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
		for event: Dictionary in state.combat_events:
			if event.type == "shot":
				shots += 1
				if first_shot == -1: first_shot = tick
			else:
				deaths += 1
		if tick < WARMUP:
			warmup.append(elapsed)
			warmup_chases += sim.scan_chases()
		else:
			samples.append(elapsed)
			snapshots.append(snapshot_elapsed)
			work.append(sim.combat_work())
			allocations.append(sim.allocation_calls())
			window_chases += sim.scan_chases()
			window_retaliations += sim.retaliations()
	var alive: int = sim.snapshot().entities.size()
	var summary: Dictionary = Stats.summary(samples)
	print("COMBAT ", layout, " tick_ms=", JSON.stringify(summary), " warmup_tick_ms=", JSON.stringify(Stats.summary(warmup)), " snapshot_ms=", JSON.stringify(Stats.summary(snapshots)),
		" combat_work=", JSON.stringify(Stats.summary(work)), " allocation_calls=", JSON.stringify(Stats.summary(allocations)),
		" shots=", shots, " deaths=", deaths, " first_shot=", first_shot, " alive_start=", start_units, " alive_end=", alive,
		" scan_chases_warmup=", warmup_chases, " scan_chases_window=", window_chases, " retaliations_window=", window_retaliations)
	if STRESS_CEILING.has(layout):
		var ceiling: Array = STRESS_CEILING[layout]
		var within: bool = summary.p95 <= ceiling[0] and summary.p99 <= ceiling[1]
		print("COMBAT STRESS ", "PASS" if within else "FAIL", " ", layout, " exceeds the ", BUDGET_P95_MS, "/", BUDGET_P99_MS, " budget, report-only; ceiling p95/p99 ", ceiling)
		if not within:
			push_error("Combat stress ceiling exceeded for " + layout)
			return false
	else:
		var within_budget: bool = summary.p95 <= BUDGET_P95_MS and summary.p99 <= BUDGET_P99_MS
		print("COMBAT BUDGET ", "PASS" if within_budget else "FAIL", " ", layout, " simulation_only")
		if not within_budget:
			push_error("Combat budget exceeded for " + layout)
			return false
	if window_chases == 0 and layout != "contact":
		push_error("Combat benchmark never chased inside the timed window for " + layout)
		return false
	if window_retaliations == 0 and (layout == "contact" or layout == "skirmish3v3"):
		push_error("Combat benchmark never retaliated inside the timed window for " + layout)
		return false
	if deaths == 0 or alive + deaths != start_units or (layout == "contact" and (first_shot == -1 or first_shot >= 60)):
		push_error("Combat benchmark workload invalid for " + layout)
		return false
	return true

extends SceneTree

const Workload = preload("res://scripts/debug/combat_workload.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

const WARMUP: int = 300
const SAMPLES: int = 1800
# Report-only stress rows, pinned at the worst of the M7 runs (Task 0, 1, gate 1, gate 1 fixes) + 5% (user decision 2026-11-06, re-pinned after M7 armed units); raise only with user approval and a ledger line.
const STRESS_CEILING := {"open": [3.05, 4.23], "dense": [3.31, 5.01]}
const BUDGET_P95_MS: float = 1.82
const BUDGET_P99_MS: float = 3.64

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("M4 COMBAT HEADLESS engine=", Engine.get_version_info().string, " os=", OS.get_name(),
		" cpu=", OS.get_processor_name(), " map=64x64 units=150v150/105v105 warmup_ticks=", WARMUP, " sample_ticks=", SAMPLES, " unpaced=true")
	var breached: Array[String] = []
	for layout: String in ["open", "dense", "contact", "skirmish3v3"]:
		if not _measure(layout):
			breached.append(layout)
	if not _measure("transports"):
		breached.append("transports")
	if not _measure("defences"):
		breached.append("defences")
	if not _measure("docks"):
		breached.append("docks")
	if not _measure("hordes"):
		breached.append("hordes")
	if not breached.is_empty():
		for layout: String in breached:
			push_error("Combat benchmark failed for " + layout)
		quit(1)
		return
	print("COMBAT BENCHMARK PASSED 8")
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
	var riders: Dictionary = {}
	for unit: Dictionary in sim.snapshot().entities:
		if unit.has("container_id"): riders[unit.id] = true
	var defenders: Dictionary = {}
	for building: Dictionary in sim.snapshot().buildings:
		if building.has("combat"): defenders[building.id] = true
	var rider_shots: int = 0
	var defence_shots: int = 0
	var credits_at_window: int = 0
	var waiting_ticks: int = 0
	var stacked_ticks: int = 0
	var horde_checks: int = 0
	var horde_peak: int = 0
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
				if tick >= WARMUP and riders.has(event.attacker_id): rider_shots += 1
				if tick >= WARMUP and defenders.has(event.attacker_id): defence_shots += 1
				if first_shot == -1: first_shot = tick
			else:
				deaths += 1
		if tick == WARMUP: credits_at_window = state.players[0].credits
		if tick >= WARMUP:
			horde_checks += sim.horde_checks()
			var level_two: int = state.entities.filter(func(unit: Dictionary) -> bool: return unit.combat != null and unit.combat.get("horde", 0) == 2).size()
			horde_peak = maxi(horde_peak, level_two)
			var docked: Dictionary = {}
			var waiting: bool = false
			var stacked: bool = false
			for unit: Dictionary in state.entities:
				if unit.collection == null or not unit.collection.phase in ["waiting_source", "waiting_depot", "loading", "unloading"]: continue
				waiting = waiting or unit.collection.phase.begins_with("waiting_")
				stacked = stacked or docked.has(unit.position)
				docked[unit.position] = true
			waiting_ticks += 1 if waiting else 0
			stacked_ticks += 1 if stacked else 0
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
	if layout == "transports":
		print("COMBAT TRANSPORTS passenger_shots_window=", rider_shots, " passengers=", riders.size(), " report-only until gate 1")
		if riders.size() != 100 or rider_shots == 0:
			push_error("Combat benchmark: no passenger shots inside the timed window")
			return false
		return true
	if layout == "defences":
		print("COMBAT DEFENCES defence_shots_window=", defence_shots, " report-only until gate 1")
		if defence_shots == 0:
			push_error("Combat benchmark: no defence shots inside the timed window")
			return false
		return true
	if layout == "hordes":
		print("COMBAT HORDES checks_window=", horde_checks, " level2_peak_window=", horde_peak, " report-only")
		if horde_checks == 0 or horde_peak == 0:
			push_error("Combat benchmark: no horde checks or no horde of five inside the timed window")
			return false
		return true
	if layout == "docks":
		var earned: int = sim.snapshot().players[0].credits - credits_at_window
		print("COMBAT DOCKS credits_window=", earned, " waiting_ticks_window=", waiting_ticks, " stacked_ticks_window=", stacked_ticks, " report-only")
		if earned <= 0 or waiting_ticks == 0 or stacked_ticks > 0:
			push_error("Combat benchmark: no deliveries, no queued trucks or stacked trucks inside the timed window")
			return false
		return true
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

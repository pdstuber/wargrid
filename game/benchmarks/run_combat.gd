extends SceneTree

const Workload = preload("res://scripts/debug/combat_workload.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

const WARMUP: int = 300
const SAMPLES: int = 1800
# Regression ceilings for rows that exceed the budget: worst of 13 quiet runs + 5% (T3, 2026-11-08); raise only with user approval and a ledger line.
const STRESS_CEILING := {"open": [2.10, 2.59], "dense": [2.64, 3.95], "hordes300": [3.07, 4.05]}
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
	if not _measure("hordes300"):
		breached.append("hordes300")
	if not _measure("ramp"):
		breached.append("ramp")
	if not _measure("frc"):
		breached.append("frc")
	if not breached.is_empty():
		for layout: String in breached:
			push_error("Combat benchmark failed for " + layout)
		quit(1)
		return
	print("COMBAT BENCHMARK PASSED 10")
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
	var ramp_shots: int = 0
	var ramped: Dictionary = {}
	var frc := {"tier_start": -1, "tier_end": -1, "occupant_gain": false, "hole_gain": false, "hp": {}}
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
				if tick >= WARMUP and ramped.has(event.attacker_id): ramp_shots += 1
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
		if layout == "frc" and tick >= WARMUP: _track_frc(state, frc)
		if layout == "ramp":
			ramped.clear()
			for object: Dictionary in state.entities + state.buildings:
				if object.get("combat") != null and object.combat.get("ramp_level", 0) == 2: ramped[object.id] = true
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
		print("COMBAT TRANSPORTS passenger_shots_window=", rider_shots, " passengers=", riders.size())
		if not _budget_ok(layout, summary):
			return false
		if riders.size() != 100 or rider_shots == 0:
			push_error("Combat benchmark: no passenger shots inside the timed window")
			return false
		return true
	if layout == "defences":
		print("COMBAT DEFENCES defence_shots_window=", defence_shots)
		if not _budget_ok(layout, summary):
			return false
		if defence_shots == 0:
			push_error("Combat benchmark: no defence shots inside the timed window")
			return false
		return true
	if layout == "ramp":
		print("COMBAT RAMP level2_shots_window=", ramp_shots)
		if not _budget_ok(layout, summary):
			return false
		if ramp_shots == 0:
			push_error("Combat benchmark: no level 2 ramp shot inside the timed window")
			return false
		return true
	if layout == "frc":
		print("COMBAT FRC tier_start=", frc.tier_start, " tier_end=", frc.tier_end, " occupant_hp_rose=", frc.occupant_gain, " hole_hp_rose=", frc.hole_gain)
		if not _budget_ok(layout, summary):
			return false
		if frc.tier_start != 0 or frc.tier_end != 1 or not frc.occupant_gain or not frc.hole_gain:
			push_error("Combat benchmark: the frc salvage, tunnel heal or hole regeneration did not run inside the timed window")
			return false
		return true
	if layout == "hordes300":
		print("COMBAT ", layout.to_upper(), " checks_window=", horde_checks, " level2_peak_window=", horde_peak)
		if not _stress_ok(layout, summary):
			return false
		if horde_checks == 0 or horde_peak == 0:
			push_error("Combat benchmark: no horde checks or no horde of five inside the timed window")
			return false
		return true
	if layout == "docks":
		var earned: int = sim.snapshot().players[0].credits - credits_at_window
		print("COMBAT DOCKS credits_window=", earned, " waiting_ticks_window=", waiting_ticks, " stacked_ticks_window=", stacked_ticks)
		if not _budget_ok(layout, summary):
			return false
		if earned <= 0 or waiting_ticks == 0 or stacked_ticks > 0:
			push_error("Combat benchmark: no deliveries, no queued trucks or stacked trucks inside the timed window")
			return false
		return true
	var gate_ok: bool = _stress_ok(layout, summary) if STRESS_CEILING.has(layout) else _budget_ok(layout, summary)
	if not gate_ok:
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

func _budget_ok(layout: String, summary: Dictionary) -> bool:
	var ok: bool = Stats.within(summary, Stats.BUDGET_P95_MS, Stats.BUDGET_P99_MS)
	print("COMBAT BUDGET ", "PASS" if ok else "FAIL", " ", layout, " simulation_only")
	if not ok:
		push_error("Combat budget exceeded for " + layout)
	return ok

func _stress_ok(layout: String, summary: Dictionary) -> bool:
	var ceiling: Array = STRESS_CEILING[layout]
	var ok: bool = Stats.within(summary, ceiling[0], ceiling[1])
	print("COMBAT STRESS ", "PASS" if ok else "FAIL", " ", layout, " exceeds the ", Stats.BUDGET_P95_MS, "/", Stats.BUDGET_P99_MS, " budget, regression ceiling p95/p99 ", ceiling)
	if not ok:
		push_error("Combat stress ceiling exceeded for " + layout)
	return ok

func _track_frc(state: Dictionary, frc: Dictionary) -> void:
	for unit: Dictionary in state.entities:
		if unit.kind == "frc_tank" and unit.position[1] > 50.0:
			if frc.tier_start == -1: frc.tier_start = unit.combat.tier
			frc.tier_end = unit.combat.tier
		elif unit.has("container_id") and unit.hp > frc.hp.get(unit.id, 1 << 60):
			frc.occupant_gain = true
	for building: Dictionary in state.buildings:
		if building.has("rebuild") and building.hp > frc.hp.get(building.id, 1 << 60): frc.hole_gain = true
	frc.hp.clear()
	for object: Dictionary in state.entities + state.buildings:
		frc.hp[object.id] = object.hp

extends SceneTree

const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const TeamMatch = preload("res://scripts/debug/team_match.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

const WARMUP: int = 300
const SAMPLES: int = 1800
const FIRST_SHOT_LIMIT: int = 60

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	quit(0 if _play() else 1)

func _play() -> bool:
	var sim: Simulation = CombatWorkload.create("late_game_3v3")
	var seats: Array[int] = []
	for entry: Dictionary in TeamMatch.SEATS: seats.append(entry.seat)
	var samples := PackedFloat64Array()
	var counters := {"shots": 0, "deaths": 0, "commands": 0, "first_shot": -1}
	var alive_start: int = sim.snapshot().entities.size()
	Profiler.reset()
	for tick in range(WARMUP + SAMPLES):
		Profiler.enabled = tick >= WARMUP
		var started: int = Time.get_ticks_usec()
		TeamMatch.step(sim)
		var elapsed: float = (Time.get_ticks_usec() - started) / 1000.0
		Profiler.end_tick()
		_count(sim, tick, seats, counters)
		if tick >= WARMUP: samples.append(elapsed)
	Profiler.enabled = false
	_print_report(sim, samples, counters, alive_start)
	return _valid(counters)

func _count(sim: Simulation, tick: int, seats: Array[int], counters: Dictionary) -> void:
	for event: Dictionary in sim.combat_events():
		if event.type == "shot":
			if counters.first_shot == -1: counters.first_shot = tick
			if tick >= WARMUP: counters.shots += 1
		elif tick >= WARMUP:
			counters.deaths += 1
	if tick < WARMUP: return
	for result: Dictionary in sim.command_results():
		if result.ok and seats.has(result.player): counters.commands += 1

func _print_report(sim: Simulation, samples: PackedFloat64Array, counters: Dictionary, alive_start: int) -> void:
	print("LATE GAME 3v3 tick_ms=", JSON.stringify(Stats.summary(samples)), " mean_ms=%.3f" % Stats.mean(samples),
		" shots_window=%d deaths_window=%d bot_commands_window=%d alive_start=%d alive_end=%d" % [counters.shots, counters.deaths, counters.commands, alive_start, sim.snapshot().entities.size()])
	print(Stats.worst_tick_line("late_game", "late_game_3v3", samples, WARMUP))
	for line in Profiler.report("late_game"): print(line)

func _valid(counters: Dictionary) -> bool:
	var ok: bool = counters.first_shot != -1 and counters.first_shot < FIRST_SHOT_LIMIT and counters.shots > 0 and counters.deaths > 0 and counters.commands > 0
	if not ok:
		push_error("Late game canary workload invalid: " + JSON.stringify(counters))
		return false
	print("LATE GAME CANARY DONE")
	return true

extends SceneTree

const Wire = preload("res://scripts/net/wire.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

const FIXTURE: String = "res://benchmarks/p2_playtest_match.json"
const WARMUP: int = 300

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	quit(0 if _play() else 1)

func _play() -> bool:
	var match_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var by_tick: Dictionary = {}
	var total: int = 0
	for line: String in match_data.commands:
		var decoded: Dictionary = Wire.decode(line)
		if not decoded.ok:
			push_error("Fixture command line does not decode: " + str(decoded.error))
			return false
		by_tick[decoded.message.tick] = decoded.message.commands
		total += decoded.message.commands.size()
	var map: String = match_data.map
	var seed_value: int = int(match_data.seed)
	var names: Array = match_data.factions
	var sim: Simulation = Skirmish.create(true, "ai", {1: names[0], 2: names[1]}, MatchSettings.map_path(map), MatchSettings.starts(map, seed_value))
	var samples := PackedFloat64Array()
	var issued_after_warmup: int = 0
	var end_tick: int = int(match_data.end_tick)
	while not sim.match_over() and sim.tick() < end_tick:
		var tick: int = sim.tick()
		var started: int = Time.get_ticks_usec()
		for command: Variant in by_tick.get(tick, []):
			sim.issue_command(command)
			if tick >= WARMUP: issued_after_warmup += 1
		sim.step()
		var elapsed: float = (Time.get_ticks_usec() - started) / 1000.0
		if tick >= WARMUP: samples.append(elapsed)
	return _report(sim, match_data, samples, total, issued_after_warmup)

func _report(sim: Simulation, match_data: Dictionary, samples: PackedFloat64Array, total: int, issued_after_warmup: int) -> bool:
	var digest: String = StateHash.digest(sim.snapshot())
	if digest != match_data.end_digest or sim.tick() != int(match_data.end_tick):
		print("RECORDED MATCH DIFFERS tick=%d recorded=%s replayed=%s" % [sim.tick(), match_data.end_digest, digest])
		return false
	if issued_after_warmup == 0:
		print("RECORDED MATCH DIFFERS no command issued after warmup")
		return false
	print("RECORDED MATCH map=%s seed=%d ticks=%d commands=%d digest=matched" % [match_data.map, int(match_data.seed), sim.tick(), total])
	print("RECORDED TIMING ", JSON.stringify(Stats.summary(samples)))
	print("RECORDED MEAN ms=%.3f" % Stats.mean(samples))
	print(Stats.worst_tick_line("recorded", "p2_playtest", samples, WARMUP))
	return true

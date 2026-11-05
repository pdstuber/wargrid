extends SceneTree

const TeamMatch = preload("res://scripts/debug/team_match.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	quit(0 if _play() else 1)

func _play() -> bool:
	var sim: RefCounted = TeamMatch.create()
	var samples := PackedFloat64Array()
	var units_peak: int = 0
	for tick in range(TeamMatch.TEAM_TICK_CAP):
		var started: int = Time.get_ticks_usec()
		TeamMatch.step(sim)
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
		var state: Dictionary = sim.snapshot()
		units_peak = maxi(units_peak, state.entities.size())
		if state.match.status != "ongoing":
			print("TEAM MATCH ", state.match.status, " tick=", state.tick, " winner=", state.match.winner, " units_peak=", units_peak)
			print("TEAM TIMING ", Stats.summary(samples))
			return true
	print("TEAM MATCH cap tick=", sim.tick(), " winner=null units_peak=", units_peak)
	print("TEAM TIMING ", Stats.summary(samples))
	return false

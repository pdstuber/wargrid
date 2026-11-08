@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const TeamMatch = preload("res://scripts/debug/team_match.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Fixture = preload("res://tests/combat_fixture.gd")
const Economy = preload("res://tests/economy_fixture.gd")

const PREFIX_TICKS: int = 20000
const TRACE_INTERVAL: int = 200
const FINAL_DIGEST: String = "b1c0606ee2bb58fc"
const BUILD_CHECK_TICK: int = 3000
const TEAM_CORE_SERIES: int = 7949105010122908522

func cases() -> Array[Callable]:
	return [test_bot_never_targets_ally, test_dead_seat_bot_is_silent, test_team_match_prefix, test_team_core_series]

func _bot_world() -> RefCounted:
	var sim = Fixture.world()
	for seat in [[1, 1], [3, 1], [2, 2]]: sim.add_player(seat[0], 0, "ai", seat[1])
	return sim

func test_bot_never_targets_ally(runner) -> bool:
	var sim = _bot_world()
	var tank: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	sim.spawn(1, Vector2(2.5, 2.5), "usa_builder")
	var ally: int = sim.spawn(3, Vector2(11.5, 10.5), "usa_builder")
	var enemy: int = sim.spawn(2, Vector2(28.5, 10.5), "usa_builder")
	var barracks := {}
	for seat in [1, 2, 3]: barracks[seat] = Economy.add_completed(sim, seat, "usa_barracks", Vector2i(seat * 8, 25))
	sim.start_match([1, 2, 3] as Array[int])
	var attacks: int = 0
	var bad: int = 0
	for tick in range(Skirmish.WAVE_TIMEOUT + Skirmish.DECISION_TICKS * 30):
		sim.step()
		Skirmish.issue_opponent(sim, 1, 0)
		for command in sim.snapshot().pending_commands:
			if command.player == 1 and command.type == "attack":
				attacks += 1
				if not [enemy, barracks[2]].has(command.target_id): bad += 1
	runner.check(attacks > 0 and bad == 0 and tank != ally, "TB1 bot attacks the hostile seat, never the nearer ally")
	return true

func test_dead_seat_bot_is_silent(runner) -> bool:
	var sim = _bot_world()
	sim.spawn(2, Vector2(28.5, 10.5), "usa_builder")
	sim.spawn(3, Vector2(10.5, 10.5), "usa_builder")
	for seat in [2, 3]: Economy.add_completed(sim, seat, "usa_barracks", Vector2i(seat * 8, 25))
	sim.start_match([2, 3] as Array[int])
	var issued: int = 0
	for tick in range(Skirmish.DECISION_TICKS * 2):
		Skirmish.issue_opponent(sim, 1, 0)
		issued += sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.player == 1).size()
		sim.step()
	runner.check(issued == 0, "TB2 a seat without objects issues nothing")
	return true

func test_team_match_prefix(runner) -> bool:
	var a = TeamMatch.create()
	var b = TeamMatch.create()
	var rows: PackedStringArray = []
	var diverged: int = -1
	var tanks: bool = false
	var built: Dictionary = {}
	for tick in range(PREFIX_TICKS):
		if tick % TRACE_INTERVAL == 0:
			var state: Dictionary = a.snapshot()
			var digest: String = StateHash.digest(state)
			if digest != StateHash.digest(b.snapshot()) and diverged == -1: diverged = tick
			rows.append("%d\t%s" % [tick, digest])
			if state.entities.any(func(unit: Dictionary) -> bool: return unit.kind == "usa_tank"): tanks = true
		if tick == BUILD_CHECK_TICK: built = _completed_buildings(a)
		TeamMatch.step(a)
		TeamMatch.step(b)
		if tick % 600 == 599: await runner.process_frame
	runner.check(diverged == -1, "TB3 two runs agree every 200 ticks")
	runner.check(rows.size() == 100, "TB3 trace has 100 rows")
	var state: Dictionary = a.snapshot()
	for entry in TeamMatch.SEATS:
		runner.check(built.get(entry.seat, 0) == 5, "TB3 seat %d completes four buildings beside its command center" % entry.seat)
	runner.check(tanks, "TB3 a tank was produced")
	runner.check(StateHash.digest(state) == FINAL_DIGEST, "TB3 final digest %s at tick %d" % [StateHash.digest(state), PREFIX_TICKS])
	_write_trace(runner, rows)
	return true

func test_team_core_series(runner) -> bool:
	var sim = TeamMatch.create()
	var series: int = 0
	for tick in range(PREFIX_TICKS):
		TeamMatch.step(sim)
		series = (series * 31 + StateHash.core_check(sim.snapshot())) & 0x7fffffffffffffff
		if tick % 600 == 599: await runner.process_frame
	runner.check(series == TEAM_CORE_SERIES, "TB4 team core series pinned, got " + str(series))
	return true

func _write_trace(runner, rows: PackedStringArray) -> void:
	var path: String = OS.get_environment("WARGRID_TEAM_REPLAY_TRACE")
	if path.is_empty(): return
	var file := FileAccess.open(path, FileAccess.WRITE)
	runner.check(file != null, "TB3 team trace opens")
	if file == null: return
	file.store_string("\n".join(rows) + "\n")
	file.close()

func _completed_buildings(sim: RefCounted) -> Dictionary:
	var counts: Dictionary = {}
	for building in sim.snapshot().buildings:
		if building.completed: counts[building.owner] = counts.get(building.owner, 0) + 1
	return counts

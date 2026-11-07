@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Economy = preload("res://tests/economy_fixture.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

const RALLY := Vector2(43.5, 14.5)
const FULL: int = 8

func cases() -> Array[Callable]:
	return [test_lone_unit_waits_for_timeout, test_full_wave_releases_at_once, test_wave_shares_and_repicks_target, test_late_units_form_next_wave, test_target_score_battery_before_far_plant, test_target_score_distance_penalty, test_target_score_ties_lowest_id, test_target_score_classes, test_waves_deterministic, test_wave_leaves_masked_hole]

func _world() -> RefCounted:
	var sim = Simulation.new([], Vector2i(48, 32))
	sim.add_player(1, 10000)
	sim.add_player(2, 0)
	sim.spawn(2, Vector2(46.5, 28.5), "usa_builder")
	return sim

func _rally_units(sim: RefCounted, count: int, from: int = 0) -> Array:
	var ids: Array = []
	for i in range(from, from + count): ids.append(sim.spawn(2, RALLY + Vector2((i % 4) * 1.5 - 2.25, floori(i / 4.0) * 1.5 - 0.75), "usa_rifle_infantry"))
	return ids

func _run(sim: RefCounted, tick: int) -> void:
	while sim.tick() < tick:
		Skirmish.issue_opponent(sim)
		sim.step()

func _decide(sim: RefCounted) -> void:
	Skirmish.issue_opponent(sim)
	sim.step()

func _targets(sim: RefCounted, ids: Array) -> Array:
	var found: Array = []
	for id in ids:
		var combat: Dictionary = Economy.object(sim, id).combat
		found.append(combat.target_id if combat.mode == "attack" else null)
	return found

func _all(targets: Array, id: int) -> bool:
	return targets.all(func(target) -> bool: return target == id)

func test_lone_unit_waits_for_timeout(runner) -> bool:
	var sim = _world()
	var plant: int = Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(10, 20))
	var unit: Array = _rally_units(sim, 1)
	_run(sim, Skirmish.ATTACK_TICK + Skirmish.WAVE_TIMEOUT - Skirmish.DECISION_TICKS)
	_decide(sim)
	runner.check(_targets(sim, unit) == [null], "W1 a lone unit waits at the rally before the timeout, got " + str(_targets(sim, unit)))
	_run(sim, Skirmish.ATTACK_TICK + Skirmish.WAVE_TIMEOUT)
	_decide(sim)
	runner.check(_targets(sim, unit) == [plant], "W1 the lone unit attacks once WAVE_TIMEOUT ticks passed, got " + str(_targets(sim, unit)))
	return true

func test_full_wave_releases_at_once(runner) -> bool:
	var sim = _world()
	var plant: int = Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(10, 20))
	var ids: Array = _rally_units(sim, Skirmish.WAVE_MIN - 1)
	_run(sim, Skirmish.ATTACK_TICK)
	_decide(sim)
	runner.check(_targets(sim, ids).all(func(target) -> bool: return target == null), "W2 below WAVE_MIN the units keep waiting")
	ids.append_array(_rally_units(sim, 1, Skirmish.WAVE_MIN - 1))
	_run(sim, sim.tick() + Skirmish.DECISION_TICKS - sim.tick() % Skirmish.DECISION_TICKS)
	_decide(sim)
	runner.check(_all(_targets(sim, ids), plant), "W2 WAVE_MIN idle units attack together at once, got " + str(_targets(sim, ids)))
	return true

func test_wave_shares_and_repicks_target(runner) -> bool:
	var sim = _world()
	var plants: Array = [Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(30, 10)), Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(30, 17))]
	var ids: Array = _rally_units(sim, FULL)
	_run(sim, Skirmish.ATTACK_TICK)
	_decide(sim)
	var shared: Variant = _targets(sim, ids)[0]
	runner.check(plants.has(shared) and _all(_targets(sim, ids), shared), "W3 the wave shares one target although units stand nearer different ones, got " + str(_targets(sim, ids)))
	sim.remove_object(shared)
	_run(sim, sim.tick() + Skirmish.DECISION_TICKS - sim.tick() % Skirmish.DECISION_TICKS)
	_decide(sim)
	var other: int = plants[1] if shared == plants[0] else plants[0]
	runner.check(_all(_targets(sim, ids), other), "W3 the wave re-picks one shared target after it died, got " + str(_targets(sim, ids)))
	return true

func test_late_units_form_next_wave(runner) -> bool:
	var sim = _world()
	Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(10, 20))
	Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(2, 2))
	_rally_units(sim, FULL)
	_run(sim, Skirmish.ATTACK_TICK)
	_decide(sim)
	var late: Array = _rally_units(sim, 1, FULL)
	_run(sim, sim.tick() + Skirmish.WAVE_TIMEOUT - Skirmish.DECISION_TICKS - sim.tick() % Skirmish.DECISION_TICKS)
	_decide(sim)
	runner.check(_targets(sim, late) == [null], "W4 a unit that joins after the release waits for its own wave, got " + str(_targets(sim, late)))
	_run(sim, sim.tick() + Skirmish.DECISION_TICKS * 2)
	runner.check(_targets(sim, late)[0] != null, "W4 the late unit attacks after its own timeout, got " + str(_targets(sim, late)))
	return true

func _released_target(runner, build: Callable, label: String) -> int:
	var sim = _world()
	build.call(sim)
	var ids: Array = _rally_units(sim, FULL)
	_run(sim, Skirmish.ATTACK_TICK)
	_decide(sim)
	var targets: Array = _targets(sim, ids)
	runner.check(targets.all(func(target) -> bool: return target == targets[0]), label + " one shared target, got " + str(targets))
	return targets[0] if targets[0] != null else -1

func test_target_score_battery_before_far_plant(runner) -> bool:
	var ids: Array = []
	var picked: int = _released_target(runner, func(sim) -> void:
		ids.append(Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(29, 14)))
		ids.append(Economy.add_completed(sim, 1, "usa_defence", Vector2i(27, 14))), "T1")
	runner.check(picked == ids[1], "T1 a battery (29) 3 cells farther is picked ahead of a power plant (27), got " + str(picked) + " of " + str(ids))
	return true

func test_target_score_distance_penalty(runner) -> bool:
	var ids: Array = []
	var picked: int = _released_target(runner, func(sim) -> void:
		ids.append(sim.spawn(1, Vector2(5.5, 14.5), "usa_builder"))
		ids.append(Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(32, 14))), "T2")
	runner.check(picked == ids[1], "T2 a builder 38 cells away loses a point per 4 cells and a close power plant wins, got " + str(picked) + " of " + str(ids))
	return true

func test_target_score_ties_lowest_id(runner) -> bool:
	var ids: Array = []
	var picked: int = _released_target(runner, func(sim) -> void:
		ids.append(Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(30, 17)))
		ids.append(Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(30, 10))), "T3")
	runner.check(picked == ids[0], "T3 equal scores go to the lowest id, got " + str(picked) + " of " + str(ids))
	return true

func test_target_score_classes(runner) -> bool:
	var ids: Array = []
	var picked: int = _released_target(runner, func(sim) -> void:
		ids.append(Economy.add_completed(sim, 1, "usa_command_center", Vector2i(30, 10)))
		ids.append(Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(30, 17))), "T4")
	runner.check(picked == ids[1], "T4 the headquarters (26) ranks below a power plant (27) one cell farther, got " + str(picked) + " of " + str(ids))
	ids.clear()
	picked = _released_target(runner, func(sim) -> void:
		ids.append(Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(28, 10)))
		ids.append(sim.spawn(1, Vector2(29.5, 14.5), "usa_tank")), "T5")
	runner.check(picked == ids[1], "T5 a vehicle (28) ranks above a power plant (27) one cell farther, got " + str(picked) + " of " + str(ids))
	return true

func test_waves_deterministic(runner) -> bool:
	var a = _world()
	var b = _world()
	for sim in [a, b]:
		Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(10, 20))
		_rally_units(sim, 5)
		_run(sim, Skirmish.ATTACK_TICK + Skirmish.WAVE_TIMEOUT + 600)
	runner.check(a.snapshot() == b.snapshot(), "W5 two runs over the same ticks end in equal state")
	return true

func test_wave_leaves_masked_hole(runner) -> bool:
	var sim = _world()
	var plant: int = Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(10, 20))
	sim.remove_object(Economy.add_completed(sim, 1, "frc_barracks", Vector2i(10, 24)))
	sim.remove_object(plant)
	var hole: Dictionary = sim.snapshot().buildings.filter(func(b: Dictionary) -> bool: return b.has("rebuild"))[0]
	sim._buildings[hole.id].rebuild.respawn_tick = Skirmish.ATTACK_TICK + Skirmish.DECISION_TICKS
	var ids: Array = _rally_units(sim, FULL)
	_run(sim, Skirmish.ATTACK_TICK)
	_decide(sim)
	runner.check(_all(_targets(sim, ids), hole.id), "W10 the wave targets the unmasked hole, got " + str(_targets(sim, ids)))
	_run(sim, Skirmish.ATTACK_TICK + 3 * Skirmish.DECISION_TICKS)
	_decide(sim)
	var targets: Array = _targets(sim, ids)
	runner.check(Combat.masked(sim._buildings[hole.id]), "W10 the laborer has masked the hole")
	runner.check(targets.all(func(target) -> bool: return target != null and target != hole.id), "W10 the wave re-picks away from the masked hole instead of idling, got " + str(targets))
	return true

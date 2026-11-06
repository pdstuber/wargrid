@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/combat_fixture.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")

func cases() -> Array[Callable]:
	return [test_defence_fires_edge_range, test_defence_clip_and_reload, test_defence_picks_nearest_hostile, test_powered_defence_dark_when_low_power, test_bot_does_not_build_defence]

func _world() -> RefCounted:
	var sim = Fixture.world()
	sim.add_player(1, 10000)
	sim.add_player(2, 0)
	EconomyFixture.add_completed(sim, 1, "usa_power_plant", Vector2i(1, 1))
	return sim

func _shots(sim, defence: int) -> Array:
	return sim.snapshot().combat_events.filter(func(e: Dictionary) -> bool: return e.type == "shot" and e.attacker_id == defence)

func test_defence_fires_edge_range(runner) -> bool:
	var reach: float = 9.0 - 0.1 + CombatDefinitions.radius("usa_defence") + CombatDefinitions.radius("usa_tank")
	for case in [[reach - 0.01, true], [reach + 0.01, false]]:
		var sim = _world()
		var defence: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
		sim.spawn(2, Vector2(10.5 + case[0], 10.5), "usa_tank")
		sim.step()
		runner.check(_shots(sim, defence).size() == (1 if case[1] else 0), "DF1 battery edge reach " + str(case[0]))
	return true

func test_defence_clip_and_reload(runner) -> bool:
	var sim = _world()
	var defence: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	sim.spawn(2, Vector2(16.5, 10.5), "usa_tank")
	var ticks: Array = []
	for i in range(90):
		sim.step()
		for shot in _shots(sim, defence): ticks.append(shot.tick)
	runner.check(ticks == [0, 8, 16, 24, 84], "DF2 four shots then a 60 tick reload: " + str(ticks))
	return true

func test_defence_picks_nearest_hostile(runner) -> bool:
	var sim = _world()
	var defence: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	sim.spawn(1, Vector2(11.5, 10.5), "usa_tank")
	sim.spawn(2, Vector2(16.5, 10.5), "usa_tank")
	var near: int = sim.spawn(2, Vector2(14.5, 10.5), "usa_tank")
	sim.step()
	var shots: Array = _shots(sim, defence)
	runner.check(shots.size() == 1 and shots[0].target_id == near, "DF3 the nearest hostile is chosen, allies are not")
	return true

func test_powered_defence_dark_when_low_power(runner) -> bool:
	var sim = _world()
	var defence: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	sim.spawn(2, Vector2(16.5, 10.5), "usa_tank")
	sim.step()
	runner.check(_shots(sim, defence).size() == 1, "DF4 fires at supply 5 and demand 3")
	var drains: Array = []
	for x in [4, 20, 24]: drains.append(EconomyFixture.add_completed(sim, 1, "usa_supply_center", Vector2i(x, 20)))
	var silent: bool = true
	for i in range(100):
		sim.step()
		silent = silent and _shots(sim, defence).is_empty()
	runner.check(silent, "DF4 silent at demand 6 over supply 5")
	sim.remove_object(drains[0])
	sim.step()
	runner.check(_shots(sim, defence).size() == 1, "DF4 fires the tick after power returns")
	return true

func test_bot_does_not_build_defence(runner) -> bool:
	var sim = Skirmish.create(false)
	for tick in range(6000):
		Skirmish.issue_opponent(sim)
		sim.step()
	runner.check(not sim.snapshot().buildings.any(func(b: Dictionary) -> bool: return b.kind == "usa_defence"), "DF5 the bot never builds a battery")
	runner.check(Registry.kind("usa_builder").builds.has("usa_defence") and Skirmish.build_order().has("usa_defence") == false, "DF5 a builder may build one, the bot's build order omits it")
	var human = _world()
	var builder: int = human.spawn(1, Vector2(5.5, 5.5), "usa_builder")
	var sent: Dictionary = EconomyFixture.send(human, {"type": "build", "builder_id": builder, "building_kind": "usa_defence", "origin": [10, 10]})
	runner.check(sent.ok, "DF5 a human seat can order a battery: " + str(sent.get("error", "")))
	return true

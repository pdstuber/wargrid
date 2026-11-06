@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/combat_fixture.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")

func cases() -> Array[Callable]:
	return [test_defence_fires_edge_range, test_defence_clip_and_reload, test_defence_picks_nearest_hostile, test_powered_defence_dark_when_low_power, test_bot_does_not_build_defence, test_defence_shots_trigger_retaliation, test_defence_keeps_current_target, test_defence_splash, test_defence_ignores_air_and_contained, test_defence_deaths_after_all_shots, test_idle_defence_scans_on_interval, test_defence_keeps_target_without_scanning, test_defence_scan_deterministic]

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

func test_defence_shots_trigger_retaliation(runner) -> bool:
	for case in [[6.0, true], [7.9, true], [8.5, false]]:
		var sim = _world()
		EconomyFixture.add_completed(sim, 2, "usa_power_plant", Vector2i(1, 20))
		var defence: int = EconomyFixture.add_completed(sim, 2, "usa_defence", Vector2i(10, 10))
		var victim: int = sim.spawn(1, Vector2(10.5 + case[0], 10.5), "usa_rifle_infantry")
		sim.step()
		runner.check(_shots(sim, defence).size() == 1, "DF6 the battery shot the infantry at " + str(case[0]))
		var mode: String = Fixture.object(sim, victim).combat.mode
		runner.check((mode == "retaliate") == case[1], "DF6 infantry shot from the battery at %s cells: retaliate=%s, mode %s" % [case[0], case[1], mode])
	return true

func test_defence_keeps_current_target(runner) -> bool:
	var sim = _world()
	var defence: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	var first: int = sim.spawn(2, Vector2(16.5, 10.5), "usa_tank")
	sim.step()
	sim.spawn(2, Vector2(13.5, 10.5), "usa_tank")
	for i in range(8): sim.step()
	var second: Array = sim.snapshot().combat_events.filter(func(e: Dictionary) -> bool: return e.type == "shot" and e.attacker_id == defence)
	runner.check(second.size() == 1 and second[0].target_id == first, "DF7 the battery stays on its valid target while a nearer one appears, got " + str(second))
	return true

func test_defence_splash(runner) -> bool:
	var sim = _world()
	var defence: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	var target: int = sim.spawn(2, Vector2(16.5, 10.5), "usa_rifle_infantry")
	var ring: Array = []
	for offset in [Vector2(0.6, 0), Vector2(-0.6, 0), Vector2(0, 0.6), Vector2(0, -0.6)]: ring.append(sim.spawn(2, Vector2(16.5, 10.5) + offset, "usa_rifle_infantry"))
	var apart: int = sim.spawn(2, Vector2(16.5, 14.5), "usa_rifle_infantry")
	sim.step()
	var hits: Dictionary = {}
	for shot in _shots(sim, defence): hits[shot.target_id] = shot.splash
	runner.check(ring.size() == 4 and hits.size() >= 2 and hits.values().has(true) and not hits.has(apart), "DF8 the shot also splashes neighbours, not a unit far away, got " + str(hits))
	return true

func test_defence_ignores_air_and_contained(runner) -> bool:
	var sim = _world()
	var defence: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	var air: int = sim.spawn(2, Vector2(12.5, 10.5), "usa_collector")
	var passenger: int = sim.spawn(2, Vector2(14.5, 10.5), "usa_rifle_infantry")
	var car: int = sim.spawn(2, Vector2(14.5, 11.5), "usa_light_vehicle")
	EconomyFixture.send(sim, {"type": "enter", "player": 2, "entity_ids": [passenger], "target_id": car})
	for i in range(40): sim.step()
	runner.check(Fixture.object(sim, passenger).has("container_id"), "DF9 setup: the passenger boarded")
	var targets: Dictionary = {}
	for i in range(100):
		sim.step()
		for shot in _shots(sim, defence): targets[shot.target_id] = true
	runner.check(not targets.has(air) and not targets.has(passenger) and targets.has(car), "DF9 neither aircraft nor passenger is shot, the car is: " + str(targets.keys()))
	return true

func test_defence_deaths_after_all_shots(runner) -> bool:
	var sim = _world()
	var first: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	var second: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 12))
	EconomyFixture.add_completed(sim, 1, "usa_power_plant", Vector2i(1, 5))
	var tank: int = sim.spawn(2, Vector2(16.5, 11.5), "usa_tank")
	sim._entities[tank].hp = 1
	sim.step()
	var events: Array = sim.snapshot().combat_events
	var shooters: Array = events.filter(func(e: Dictionary) -> bool: return e.type == "shot" and e.target_id == tank).map(func(e: Dictionary) -> int: return e.attacker_id)
	var deaths: Array = events.filter(func(e: Dictionary) -> bool: return e.type == "death" and e.object_id == tank)
	runner.check(shooters == [first, second] and deaths.size() == 1, "DF10 both batteries fire on the tick the target dies, one death: " + str(shooters) + " " + str(deaths.size()))
	return true

# Work the battery adds: the same world without it is the baseline.
func _battery_work(at: Vector2, ticks: int, with_battery: bool) -> int:
	var sim = _world()
	if with_battery: EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	sim.spawn(2, at, "usa_builder")
	var work: int = 0
	for i in range(ticks):
		sim.step()
		work += sim.combat_work()
	return work

func test_idle_defence_scans_on_interval(runner) -> bool:
	var scans: int = _battery_work(Vector2(22.5, 10.5), 80, true) - _battery_work(Vector2(22.5, 10.5), 80, false)
	runner.check(scans > 0 and scans <= 11, "DF11 an idle battery scans once per 8 ticks, not every tick: " + str(scans))
	var late = _world()
	var battery: int = EconomyFixture.add_completed(late, 1, "usa_defence", Vector2i(10, 10))
	for i in range(3): late.step()
	late.spawn(2, Vector2(16.5, 10.5), "usa_tank")
	var ticks: Array = []
	for i in range(12):
		late.step()
		for shot in _shots(late, battery): ticks.append(shot.tick)
	runner.check(ticks.size() > 0 and ticks[0] == 8, "DF11 a target appearing mid-interval is shot at the next scan: " + str(ticks))
	return true

func test_defence_keeps_target_without_scanning(runner) -> bool:
	var extra: int = _battery_work(Vector2(16.5, 10.5), 40, true) - _battery_work(Vector2(16.5, 10.5), 40, false)
	runner.check(extra <= 2, "DF12 an acquired target is kept without rescanning: " + str(extra))
	return true

func test_defence_scan_deterministic(runner) -> bool:
	var runs: Array = []
	for n in range(2):
		var sim = _world()
		var defence: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
		for i in range(5): sim.step()
		sim.spawn(2, Vector2(16.5, 10.5), "usa_tank")
		var ticks: Array = []
		for i in range(40):
			sim.step()
			for shot in _shots(sim, defence): ticks.append(shot.tick)
		runs.append(ticks)
	runner.check(runs[0] == runs[1] and not runs[0].is_empty(), "DF13 identical runs give identical shot ticks")
	return true

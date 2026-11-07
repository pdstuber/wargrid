@warning_ignore_start("untyped_declaration")
extends RefCounted

const Production = preload("res://scripts/simulation/production.gd")
const Fixture = preload("res://tests/combat_fixture.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")

func cases() -> Array[Callable]:
	return [test_defence_fires_edge_range, test_defence_clip_and_reload, test_defence_picks_nearest_hostile, test_powered_defence_dark_when_low_power, test_bot_does_not_build_defence, test_defence_shots_trigger_retaliation, test_defence_keeps_current_target, test_defence_splash, test_defence_ignores_air_and_contained, test_defence_deaths_after_all_shots, test_idle_defence_scans_on_interval, test_defence_keeps_target_without_scanning, test_defence_scan_deterministic, test_defence_attack_overrides_nearest, test_defence_attack_rejections, test_defence_attack_same_tick_cases, test_defence_attack_edge_cases]

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
	runner.check(Registry.kind("usa_builder").builds.has("usa_defence") and Skirmish.build_order(Skirmish.default_faction()).has("usa_defence") == false, "DF5 a builder may build one, the bot's build order omits it")
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

func _order(sim, defence: int, target: int, extra: Dictionary = {}) -> Dictionary:
	var payload := {"type": "defence_attack", "building_id": defence, "target_id": target}
	payload.merge(extra)
	return Fixture.send(sim, payload)

func _last_result(sim) -> Dictionary:
	return sim.snapshot().command_results.back()

func test_defence_attack_overrides_nearest(runner) -> bool:
	var sim = _world()
	var defence: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	var near: int = sim.spawn(2, Vector2(14.5, 10.5), "usa_tank")
	var far: int = sim.spawn(2, Vector2(16.5, 10.5), "usa_tank")
	runner.check(_order(sim, defence, far).ok, "DA1 order accepted")
	sim.step()
	var shots: Array = _shots(sim, defence)
	runner.check(shots.size() == 1 and shots[0].target_id == far, "DA1 the first shot hits the named farther target, not " + str(near))
	for i in range(8): sim.step()
	shots = _shots(sim, defence)
	runner.check(shots.size() == 1 and shots[0].target_id == far, "DA1 the next shots keep the named target")
	return true

func test_defence_attack_rejections(runner) -> bool:
	var sim = _world()
	var defence: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	var foreign: int = EconomyFixture.add_completed(sim, 2, "usa_defence", Vector2i(20, 20))
	var plant: int = EconomyFixture.add_completed(sim, 1, "usa_power_plant", Vector2i(1, 5))
	var tank: int = sim.spawn(1, Vector2(12.5, 12.5), "usa_tank")
	var near: int = sim.spawn(2, Vector2(14.5, 10.5), "usa_tank")
	var far: int = sim.spawn(2, Vector2(30.5, 30.5), "usa_tank")
	for case in [[foreign, near, "Invalid owned defence"], [plant, near, "Invalid owned defence"], [tank, near, "Invalid owned defence"], [9999, near, "Invalid owned defence"], [defence, tank, "Invalid attack target"], [defence, 9999, "Invalid attack target"], [defence, far, "Target out of range"]]:
		var result: Dictionary = _order(sim, case[0], case[1])
		runner.check(not result.ok and result.error == case[2], "DA2 %s: got %s" % [case[2], result.error])
	var unfinished: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(5, 20))
	sim._buildings[unfinished].completed = false
	runner.check(_order(sim, unfinished, near).error == "Invalid owned defence", "DA2 an unfinished defence is rejected")
	runner.check(_order(sim, defence, near).ok, "DA2 a USA battery accepts a target in reach")
	var china = _world()
	var tower: int = EconomyFixture.add_completed(china, 1, "china_defence", Vector2i(10, 10))
	var enemy: int = china.spawn(2, Vector2(14.5, 10.5), "usa_tank")
	runner.check(_order(china, tower, enemy).ok, "DA2 a China tower accepts a target in reach")
	return true

func _same_tick_world() -> Dictionary:
	var sim = _world()
	var ids := {"sim": sim}
	ids.defence = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	ids.near = sim.spawn(2, Vector2(14.5, 10.5), "usa_tank")
	ids.far = sim.spawn(2, Vector2(16.5, 10.5), "usa_tank")
	ids.tank = sim.spawn(1, Vector2(12.5, 14.5), "usa_tank")
	ids.builder = sim.spawn(1, Vector2(4.5, 4.5), "usa_builder")
	ids.barracks = EconomyFixture.add_completed(sim, 1, "usa_barracks", Vector2i(20, 4))
	ids.foundation = EconomyFixture.add_completed(sim, 1, "usa_power_plant", Vector2i(25, 4))
	sim._buildings[ids.foundation].completed = false
	ids.car = sim.spawn(1, Vector2(8.5, 18.5), "usa_light_vehicle")
	ids.rifle = sim.spawn(1, Vector2(9.5, 18.5), "usa_rifle_infantry")
	ids.collector = sim.spawn(1, Vector2(6.5, 18.5), "usa_collector")
	ids.source = sim.add_supply_source(Vector2i(2, 24), 8)
	Production.enqueue(sim, ids.barracks, "usa_rifle_infantry")
	ids.production = sim._buildings[ids.barracks].queue[0].id
	return ids

func _other_commands(ids: Dictionary) -> Array:
	return [
		{"type": "move", "entity_ids": [ids.tank], "target": [8.5, 14.5]},
		{"type": "stop", "entity_ids": [ids.tank]},
		{"type": "build", "builder_id": ids.builder, "building_kind": "usa_power_plant", "origin": [6, 6]},
		{"type": "resume_build", "builder_id": ids.builder, "building_id": ids.foundation},
		{"type": "cancel_build", "building_id": ids.foundation},
		{"type": "produce", "building_id": ids.barracks, "unit_kind": "usa_rifle_infantry"},
		{"type": "cancel_production", "building_id": ids.barracks, "production_id": ids.production},
		{"type": "set_rally", "building_id": ids.barracks, "target": [22.5, 8.5]},
		{"type": "gather", "entity_ids": [ids.collector], "source_id": ids.source},
		{"type": "attack", "entity_ids": [ids.tank], "target_id": ids.near},
		{"type": "attack_move", "entity_ids": [ids.tank], "target": [8.5, 14.5]},
		{"type": "enter", "entity_ids": [ids.rifle], "target_id": ids.car},
		{"type": "unload", "target_id": ids.car},
		{"type": "defence_attack", "building_id": ids.defence, "target_id": ids.near}]

func test_defence_attack_same_tick_cases(runner) -> bool:
	var count: int = _other_commands(_same_tick_world()).size()
	for index in range(count):
		for defence_first in [true, false]:
			var ids: Dictionary = _same_tick_world()
			var sim = ids.sim
			var other: Dictionary = _other_commands(ids)[index]
			var label: String = "%s %s" % [other.type, "after" if defence_first else "before"]
			var companion: Dictionary = {}
			if not defence_first: companion = Fixture.send(sim, other)
			var order: Dictionary = _order(sim, ids.defence, ids.far)
			if defence_first: companion = Fixture.send(sim, other)
			runner.check(order.ok and companion.ok, "DA3 order and companion accepted with %s: %s" % [label, companion])
			var pending: Array = sim.snapshot().pending_commands.filter(func(c: Dictionary) -> bool: return c.type == "defence_attack")
			sim.step()
			var sequences: Array = pending.map(func(c: Dictionary) -> int: return c.sequence)
			var results: Array = sim.snapshot().command_results.filter(func(r: Dictionary) -> bool: return sequences.has(r.sequence))
			var target: Variant = sim.snapshot().buildings.filter(func(b: Dictionary) -> bool: return b.id == ids.defence)[0].combat.target_id
			var wanted: int = ids.near if other.type == "defence_attack" and defence_first else ids.far
			var shot: Array = _shots(sim, ids.defence)
			runner.check(results.all(func(r: Dictionary) -> bool: return r.ok) and shot.size() == 1 and shot[0].target_id == wanted and target == wanted, "DA3 %s: target %s expected %d, shots %s" % [label, str(target), wanted, str(shot)])
	return true

func test_defence_attack_edge_cases(runner) -> bool:
	var ids: Dictionary = _same_tick_world()
	var sim = ids.sim
	Fixture.send(sim, {"type": "enter", "entity_ids": [ids.far], "target_id": ids.builder, "player": 2})
	runner.check(_order(sim, ids.defence, ids.far).ok, "DA4 order for a target that is about to enter a carrier")
	sim.step()
	runner.check(_shots(sim, ids.defence).size() == 1, "DA4 the order applies the tick the target is told to enter")
	ids = _same_tick_world()
	sim = ids.sim
	_order(sim, ids.defence, ids.far)
	sim.remove_object(ids.far)
	sim.step()
	var result: Dictionary = _last_result(sim)
	runner.check(not result.ok and result.error == "Invalid attack target" and _shots(sim, ids.defence).size() == 1 and _shots(sim, ids.defence)[0].target_id == ids.near, "DA4 removed target: error at due time, scan picks the other: " + str(result))
	ids = _same_tick_world()
	sim = ids.sim
	_order(sim, ids.defence, ids.far)
	sim.remove_object(ids.defence)
	sim.step()
	result = _last_result(sim)
	runner.check(not result.ok and result.error == "Invalid owned defence" and _shots(sim, ids.defence).is_empty(), "DA4 defence removed before the order applies: error, no shot")
	ids = _same_tick_world()
	sim = ids.sim
	var killer: int = EconomyFixture.add_completed(sim, 2, "usa_defence", Vector2i(10, 14))
	sim._buildings[ids.defence].hp = 1
	_order(sim, ids.defence, ids.far)
	sim._buildings[killer].combat.target_id = ids.defence
	sim.step()
	runner.check(_last_result(sim).ok and not sim._buildings.has(ids.defence), "DA4 defence killed by fire the same tick: order ok, building gone")
	sim.step()
	runner.check(_shots(sim, ids.defence).is_empty(), "DA4 a dead defence fires no more")
	ids = _same_tick_world()
	sim = ids.sim
	for i in range(3): EconomyFixture.add_completed(sim, 1, "usa_supply_center", Vector2i(2 + i * 4, 20))
	_order(sim, ids.defence, ids.far)
	sim.step()
	runner.check(_last_result(sim).ok and _shots(sim, ids.defence).is_empty(), "DA4 a dark defence accepts the order and holds fire")
	var target: Variant = sim.snapshot().buildings.filter(func(b: Dictionary) -> bool: return b.id == ids.defence)[0].combat.target_id
	runner.check(target == ids.far, "DA4 a dark defence keeps its target")
	return true

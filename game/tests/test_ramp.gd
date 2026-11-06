@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/combat_fixture.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")

func cases() -> Array[Callable]:
	return [test_rotary_tank_intervals, test_rotary_tower_intervals, test_ramp_switch_within_coast_keeps_count, test_ramp_resets_after_coast, test_rotary_tower_dark_when_low_power, test_ramp_snapshot_keys_only_on_ramp_weapons]

func _world() -> RefCounted:
	var sim = Fixture.world()
	sim.add_player(1, 10000)
	sim.add_player(2, 0)
	return sim

func _dummy(sim, position: Vector2) -> int:
	var id: int = sim.spawn(2, position, "usa_builder")
	sim._entities[id].hp = 100000000
	sim._entities[id].max_hp = 100000000
	return id

func _ticks(sim, attacker: int, ticks: int) -> Array:
	var seen: Array = []
	for i in range(ticks):
		sim.step()
		for event in sim.snapshot().combat_events:
			if event.type == "shot" and event.attacker_id == attacker: seen.append(event.tick)
	return seen

func _gaps(ticks: Array) -> Array:
	var gaps: Array = []
	for i in range(1, ticks.size()): gaps.append(ticks[i] - ticks[i - 1])
	return gaps

func _tower(sim, origin: Vector2i = Vector2i(10, 10)) -> int:
	EconomyFixture.add_completed(sim, 1, "china_power_plant", Vector2i(1, 1))
	return EconomyFixture.add_completed(sim, 1, "china_defence", origin)

func test_rotary_tank_intervals(runner) -> bool:
	var sim = _world()
	var tank: int = sim.spawn(1, Vector2(10.5, 10.5), "china_tank")
	_dummy(sim, Vector2(14.5, 10.5))
	var gaps: Array = _gaps(_ticks(sim, tank, 60))
	runner.check(gaps.slice(0, 8) == [12, 12, 6, 6, 6, 6, 4, 4], "R1 rotary tank intervals " + str(gaps))
	var combat: Dictionary = sim._entities[tank].combat
	runner.check(combat.ramp_level == 2 and combat.ramp_shots >= 7, "R1 the tank stays at level 2 on continuous fire")
	return true

func test_rotary_tower_intervals(runner) -> bool:
	var sim = _world()
	var tower: int = _tower(sim)
	_dummy(sim, Vector2(16.5, 10.5))
	var gaps: Array = _gaps(_ticks(sim, tower, 50))
	runner.check(gaps.slice(0, 7) == [8, 4, 4, 4, 4, 2, 2], "R2 rotary tower intervals " + str(gaps))
	return true

func test_ramp_switch_within_coast_keeps_count(runner) -> bool:
	var sim = _world()
	var tank: int = sim.spawn(1, Vector2(10.5, 10.5), "china_tank")
	_dummy(sim, Vector2(14.5, 10.5))
	var other: int = _dummy(sim, Vector2(10.5, 14.5))
	var combat: Dictionary = sim._entities[tank].combat
	while combat.ramp_shots < 4: sim.step()
	var before: int = combat.ramp_shots
	combat.target_id = other
	var shot: Array = []
	while shot.is_empty():
		sim.step()
		shot = sim.snapshot().combat_events.filter(func(e: Dictionary) -> bool: return e.type == "shot" and e.attacker_id == tank)
	runner.check(shot[0].target_id == other and combat.ramp_level == 1 and combat.ramp_shots == before + 1 and combat.ramp_target == other, "R3 a switch inside the coast keeps level 1 and adds one (%d to %d)" % [before, combat.ramp_shots])
	return true

func test_ramp_resets_after_coast(runner) -> bool:
	var sim = _world()
	var tank: int = sim.spawn(1, Vector2(10.5, 10.5), "china_tank")
	var first: int = _dummy(sim, Vector2(14.5, 10.5))
	var combat: Dictionary = sim._entities[tank].combat
	while combat.ramp_level < 2: sim.step()
	sim.remove_object(first)
	for i in range(100): sim.step()
	var second: int = _dummy(sim, Vector2(10.5, 14.5))
	var shot: Array = []
	while shot.is_empty():
		sim.step()
		shot = sim.snapshot().combat_events.filter(func(e: Dictionary) -> bool: return e.type == "shot" and e.attacker_id == tank)
	runner.check(combat.ramp_level == 0 and combat.ramp_shots == 1 and combat.ramp_target == second, "R4 after the coast the ramp restarts at level 0, count 1")
	runner.check(combat.next_fire_tick == shot[0].tick + 12, "R4 the next delay is the slow one (%d after the shot)" % (combat.next_fire_tick - shot[0].tick))
	return true

func test_rotary_tower_dark_when_low_power(runner) -> bool:
	var sim = _world()
	var tower: int = _tower(sim)
	var plant: int = EconomyFixture.add_completed(sim, 1, "china_power_plant", Vector2i(4, 20))
	_dummy(sim, Vector2(16.5, 10.5))
	var combat: Dictionary = sim._buildings[tower].combat
	_ticks(sim, tower, 16)
	runner.check(combat.ramp_level == 1, "R5 the tower ramps while powered")
	for id in sim._buildings.keys():
		if sim._buildings[id].kind == "china_power_plant": sim.remove_object(id)
	runner.check(_ticks(sim, tower, 10).is_empty(), "R5 silent at demand 3 over supply 0")
	var count: int = combat.ramp_shots
	EconomyFixture.add_completed(sim, 1, "china_power_plant", Vector2i(1, 1))
	var back: Array = _ticks(sim, tower, 12)
	runner.check(not back.is_empty() and combat.ramp_shots == count + back.size() and combat.ramp_level >= 1, "R5 a short dark spell keeps the ramp count (%d to %d)" % [count, combat.ramp_shots])
	for id in sim._buildings.keys():
		if sim._buildings[id].kind == "china_power_plant": sim.remove_object(id)
	_ticks(sim, tower, 200)
	count = combat.ramp_shots
	EconomyFixture.add_completed(sim, 1, "china_power_plant", Vector2i(1, 1))
	_ticks(sim, tower, 2)
	runner.check(combat.ramp_level == 0 and combat.ramp_shots == 1, "R5 a long dark spell resets the ramp (was %d)" % count)
	return plant > 0

func test_ramp_snapshot_keys_only_on_ramp_weapons(runner) -> bool:
	var sim = _world()
	var usa: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	var battery: int = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(20, 20))
	var china: int = sim.spawn(1, Vector2(12.5, 10.5), "china_tank")
	var tower: int = _tower(sim, Vector2i(24, 24))
	var snapshot: Dictionary = sim.snapshot()
	var keys: Array = ["ramp_level", "ramp_shots", "ramp_target", "ramp_until"]
	var usa_clean: bool = true
	for record in [sim._entities[usa].combat, sim._buildings[battery].combat]:
		for key in keys: usa_clean = usa_clean and not record.has(key)
	runner.check(usa_clean, "R6 USA units and buildings have no ramp keys")
	var china_has: bool = true
	for record in [sim._entities[china].combat, sim._buildings[tower].combat]:
		for key in keys: china_has = china_has and record.has(key)
	runner.check(china_has and snapshot.entities.any(func(e: Dictionary) -> bool: return e.id == china and e.combat.has("ramp_level")), "R6 China ramp kinds carry all four keys, snapshot included")
	return true

@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/combat_fixture.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")

func cases() -> Array[Callable]:
	return [test_scout_car_holds_five, test_enter_and_unload, test_passengers_fire_while_moving, test_passengers_hold_fire_when_flag_off, test_passenger_damage_full_kills, test_passenger_damage_partial_survivors_exit, test_unload_same_tick_as_death, test_full_container_rejects, test_enter_rejections, test_passenger_commands_rejected, test_contained_not_target, test_container_same_tick_cases, test_unload_with_container_move, test_container_removed_while_approaching]

func _world() -> RefCounted:
	var sim = Fixture.world()
	sim.add_player(1, 10000)
	sim.add_player(2, 0)
	return sim

func _kind(id: String, percent: int = 100, fires: bool = true, accepts: Array = ["infantry"]) -> void:
	var row: Dictionary = Registry.kind("usa_light_vehicle").duplicate(true)
	row.contains = {"slots": 5, "accepts": accepts, "passengers_fire": fires, "passenger_damage_percent": percent}
	Registry.add_test_kind(id, row)

func _inside(sim, id: int) -> int:
	return Fixture.object(sim, id).get("container_id", 0)

func _load(sim, car: int, ids: Array, limit: int = 400) -> bool:
	var sent: Dictionary = Fixture.send(sim, {"type": "enter", "entity_ids": ids, "target_id": car})
	if not sent.ok: return false
	for i in range(limit):
		sim.step()
		if ids.all(func(id: int) -> bool: return _inside(sim, id) == car): return true
	return false

func _enters(unit: Dictionary) -> int:
	return unit.order.get("target_id", 0) if unit.order != null else 0

func _results(sim) -> Array:
	return sim.snapshot().command_results

func test_scout_car_holds_five(runner) -> bool:
	var contains: Dictionary = Registry.kind("usa_light_vehicle").get("contains", {})
	runner.check(contains.get("slots") == 5 and contains.get("accepts") == ["infantry"] and contains.get("passengers_fire") == true and contains.get("passenger_damage_percent") == 100, "CT0 scout car holds 5 infantry, they fire, full damage on death")
	runner.check(Registry.kind("usa_tank").get("contains", {}).is_empty(), "CT0 only the scout car carries passengers")
	return true

func test_enter_and_unload(runner) -> bool:
	var sim = _world()
	var car: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_light_vehicle")
	var a: int = sim.spawn(1, Vector2(8.5, 5.5), "usa_rifle_infantry")
	var b: int = sim.spawn(1, Vector2(8.5, 7.5), "usa_rifle_infantry")
	runner.check(_load(sim, car, [b, a]), "CT1 both infantry board")
	var carrier: Dictionary = Fixture.object(sim, car)
	var first: Dictionary = Fixture.object(sim, a)
	runner.check(first.container_id == car and first.status == "contained" and first.position == carrier.position, "CT1 boarded unit is contained at the container position")
	runner.check(carrier.passengers == [a, b], "CT1 passengers listed")
	var move: Dictionary = Fixture.send(sim, {"type": "move", "entity_ids": [car], "target": [20.5, 5.5]})
	for i in range(20): sim.step()
	carrier = Fixture.object(sim, car)
	runner.check(carrier.position[0] > 5.6 and Fixture.object(sim, a).position == carrier.position and Fixture.object(sim, b).position == carrier.position, "CT1 passengers travel with the container")
	runner.check(Fixture.send(sim, {"type": "stop", "entity_ids": [car]}).ok, "CT1 stop container")
	runner.check(not Fixture.send(sim, {"player": 2, "type": "unload", "target_id": car}).ok, "CT1 foreign unload rejected")
	runner.check(Fixture.send(sim, {"type": "unload", "target_id": car}).ok, "CT1 unload accepted")
	sim.step()
	var out_a: Dictionary = Fixture.object(sim, a)
	var out_b: Dictionary = Fixture.object(sim, b)
	carrier = Fixture.object(sim, car)
	runner.check(not out_a.has("container_id") and not out_b.has("container_id") and out_a.status == "arrived" and out_b.status == "arrived", "CT1 unloaded units are outside and arrived")
	runner.check(not carrier.has("passengers"), "CT1 container has no passengers")
	var cells: Dictionary = {}
	for unit in [out_a, out_b, carrier]: cells[Vector2i(Vector2(unit.position[0], unit.position[1]).floor())] = true
	runner.check(cells.size() == 3 and Vector2(out_a.position[0], out_a.position[1]).distance_to(Vector2(carrier.position[0], carrier.position[1])) < 2.0, "CT1 exits take distinct cells next to the container")
	runner.check(move.ok, "CT1 move accepted")
	return true

func _passenger_shots(sim, car: int, passenger: int) -> Array:
	var from_passenger: int = 0
	var from_car: int = 0
	for i in range(260):
		var before: Array = Fixture.object(sim, car).position
		sim.step()
		var moved: bool = Fixture.object(sim, car).position != before
		for event in sim.snapshot().combat_events:
			if event.type != "shot" or not moved: continue
			if event.attacker_id == passenger: from_passenger += 1
			if event.attacker_id == car: from_car += 1
	return [from_passenger, from_car]

func _fire_run(kind: String) -> Array:
	var sim = _world()
	var car: int = sim.spawn(1, Vector2(3.5, 10.5), kind)
	var rifle: int = sim.spawn(1, Vector2(5.5, 10.5), "usa_rifle_infantry")
	sim.spawn(2, Vector2(14.5, 12.5), "usa_builder")
	_load(sim, car, [rifle])
	Fixture.send(sim, {"type": "move", "entity_ids": [car], "target": [25.5, 10.5]})
	return _passenger_shots(sim, car, rifle)

func test_passengers_fire_while_moving(runner) -> bool:
	var shots: Array = _fire_run("usa_light_vehicle")
	runner.check(shots[0] > 0, "CT2 passenger fired while the container moved (%d shots)" % shots[0])
	runner.check(shots[1] == 0, "CT2 the moving container itself does not fire")
	return true

func test_passengers_hold_fire_when_flag_off(runner) -> bool:
	_kind("test_closed", 100, false)
	var shots: Array = _fire_run("test_closed")
	Registry.clear_test_kinds()
	runner.check(shots[0] == 0, "CT2 passengers hold fire when the container forbids it")
	return true

func test_passenger_damage_full_kills(runner) -> bool:
	var sim = _world()
	var car: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_light_vehicle")
	var a: int = sim.spawn(1, Vector2(8.5, 5.5), "usa_rifle_infantry")
	var b: int = sim.spawn(1, Vector2(8.5, 7.5), "usa_rifle_infantry")
	_load(sim, car, [a, b])
	sim.remove_object(car)
	var deaths: Array = sim.snapshot().combat_events.filter(func(event: Dictionary) -> bool: return event.type == "death").map(func(event: Dictionary) -> int: return event.object_id)
	runner.check(Fixture.object(sim, a).is_empty() and Fixture.object(sim, b).is_empty(), "CT3 full passenger damage kills the passengers")
	runner.check(deaths == [a, b], "CT3 passenger deaths reported in id order")
	return true

func test_passenger_damage_partial_survivors_exit(runner) -> bool:
	_kind("test_van", 40)
	var sim = _world()
	var car: int = sim.spawn(1, Vector2(5.5, 5.5), "test_van")
	var a: int = sim.spawn(1, Vector2(8.5, 5.5), "usa_rifle_infantry")
	var b: int = sim.spawn(1, Vector2(8.5, 7.5), "usa_rifle_infantry")
	_load(sim, car, [a, b])
	sim._entities[b].hp = 50000
	sim.remove_object(car)
	var survivor: Dictionary = Fixture.object(sim, a)
	Registry.clear_test_kinds()
	runner.check(survivor.hp == 108000 and not survivor.has("container_id") and survivor.status == "arrived", "CT3 survivor took 40 percent of max HP and exited")
	runner.check(Fixture.object(sim, b).is_empty(), "CT3 a passenger below the share dies")
	return true

func _death_setup(unload: bool) -> Array:
	var sim = _world()
	var car: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_light_vehicle")
	var passenger: int = sim.spawn(1, Vector2(7.5, 5.5), "usa_rifle_infantry")
	_load(sim, car, [passenger])
	sim._entities[car].hp = 1
	sim.spawn(2, Vector2(8.5, 5.5), "usa_rifle_infantry")
	if unload: Fixture.send(sim, {"type": "unload", "target_id": car})
	sim.step()
	return [sim, car, passenger]

func test_unload_same_tick_as_death(runner) -> bool:
	var setup: Array = _death_setup(true)
	var survivor: Dictionary = Fixture.object(setup[0], setup[2])
	runner.check(Fixture.object(setup[0], setup[1]).is_empty(), "CT4 the container died")
	runner.check(not survivor.is_empty() and survivor.hp == 180000 and not survivor.has("container_id"), "CT4 unload applies first: the passenger is out and takes no damage")
	var control: Array = _death_setup(false)
	runner.check(Fixture.object(control[0], control[1]).is_empty() and Fixture.object(control[0], control[2]).is_empty(), "CT4 without unload the passenger dies with the container")
	return true

func test_full_container_rejects(runner) -> bool:
	var sim = _world()
	var car: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_light_vehicle")
	var ids: Array = []
	for i in range(6): ids.append(sim.spawn(1, Vector2(14.5, 8.5 + i), "usa_rifle_infantry"))
	runner.check(Fixture.send(sim, {"type": "enter", "entity_ids": ids.slice(0, 5), "target_id": car}).ok, "CT5 five may enter")
	sim.step()
	var promised: Dictionary = Fixture.send(sim, {"type": "enter", "entity_ids": [ids[5]], "target_id": car})
	runner.check(not promised.ok and promised.error == "Container is full", "CT5 promised slots count as taken")
	for i in range(400): sim.step()
	var full: Dictionary = Fixture.send(sim, {"type": "enter", "entity_ids": [ids[5]], "target_id": car})
	runner.check(Fixture.object(sim, car).passengers.size() == 5 and not full.ok and full.error == "Container is full", "CT5 taken slots count as taken")
	var crowd = _world()
	var carrier: int = crowd.spawn(1, Vector2(10.5, 10.5), "usa_light_vehicle")
	var near: Array = []
	for position in [Vector2(11.5, 10.5), Vector2(9.5, 10.5), Vector2(10.5, 11.5), Vector2(10.5, 9.5), Vector2(11.4, 11.4), Vector2(9.6, 9.6)]:
		near.append(crowd.spawn(1, position, "usa_rifle_infantry"))
	runner.check(Fixture.send(crowd, {"type": "enter", "entity_ids": near, "target_id": carrier}).ok, "CT5 six may be ordered at five slots")
	crowd.step()
	var aboard: Array = Fixture.object(crowd, carrier).passengers
	var left_out: Dictionary = Fixture.object(crowd, near[5])
	runner.check(aboard == near.slice(0, 5) and not left_out.has("container_id") and _enters(left_out) == 0, "CT5 same-tick boarding fills slots in id order")
	return true

func test_enter_rejections(runner) -> bool:
	var sim = _world()
	var car: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_light_vehicle")
	var enemy_car: int = sim.spawn(2, Vector2(20.5, 5.5), "usa_light_vehicle")
	var tank: int = sim.spawn(1, Vector2(8.5, 5.5), "usa_tank")
	var rifle: int = sim.spawn(1, Vector2(8.5, 8.5), "usa_rifle_infantry")
	var rejects := {"foreign container": [[rifle], enemy_car], "not a container": [[rifle], tank], "class not accepted": [[tank], car], "missing target": [[rifle], 999]}
	for name in rejects:
		var result: Dictionary = Fixture.send(sim, {"type": "enter", "entity_ids": rejects[name][0], "target_id": rejects[name][1]})
		runner.check(not result.ok and result.error == "Cannot enter this container", "CT6 " + name + ": " + result.error)
	runner.check(Fixture.send(sim, {"type": "enter", "entity_ids": [rifle], "target_id": car}).ok, "CT6 valid enter accepted")
	_kind("test_ferry", 100, true, ["infantry", "air"])
	var ferry: int = sim.spawn(1, Vector2(12.5, 12.5), "test_ferry")
	var collector: int = sim.spawn(1, Vector2(15.5, 12.5), "usa_collector")
	var air: Dictionary = Fixture.send(sim, {"type": "enter", "entity_ids": [collector], "target_id": ferry})
	Registry.clear_test_kinds()
	runner.check(not air.ok and air.error == "Cannot enter this container", "CT6 aircraft cannot enter even when listed")
	return true

func test_passenger_commands_rejected(runner) -> bool:
	var sim = _world()
	var car: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_light_vehicle")
	var rifle: int = sim.spawn(1, Vector2(8.5, 5.5), "usa_rifle_infantry")
	var foe: int = sim.spawn(2, Vector2(25.5, 20.5), "usa_builder")
	_load(sim, car, [rifle])
	for payload in [{"type": "move", "entity_ids": [rifle], "target": [9.5, 9.5]}, {"type": "stop", "entity_ids": [rifle]}, {"type": "attack", "entity_ids": [rifle], "target_id": foe}, {"type": "attack_move", "entity_ids": [rifle], "target": [9.5, 9.5]}, {"type": "enter", "entity_ids": [rifle], "target_id": car}]:
		var result: Dictionary = Fixture.send(sim, payload)
		runner.check(not result.ok and result.error == "Unit is inside a transport", "CT7 " + payload.type + " names a passenger: " + result.error)
	return true

func test_contained_not_target(runner) -> bool:
	var sim = _world()
	var car: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_light_vehicle")
	var rifle: int = sim.spawn(1, Vector2(8.5, 5.5), "usa_rifle_infantry")
	var hunter: int = sim.spawn(2, Vector2(12.5, 5.5), "usa_rifle_infantry")
	runner.check(Combat.valid_target(sim, 2, rifle), "CT8 an outside unit is a target")
	Fixture.send(sim, {"player": 2, "type": "attack", "entity_ids": [hunter], "target_id": rifle})
	sim.step()
	_load(sim, car, [rifle])
	runner.check(not Combat.valid_target(sim, 2, rifle), "CT8 a passenger is no target")
	var result: Dictionary = Fixture.send(sim, {"player": 2, "type": "attack", "entity_ids": [hunter], "target_id": rifle})
	runner.check(not result.ok and result.error == "Invalid attack target", "CT8 attack on a passenger rejected")
	runner.check(Fixture.object(sim, hunter).combat.target_id != rifle, "CT8 boarding drops attackers' target")
	return true

func _unit_case(sim, unit: int, car: int, other: Dictionary, other_first: bool) -> Dictionary:
	var enter := {"type": "enter", "entity_ids": [unit], "target_id": car}
	for payload in ([other, enter] if other_first else [enter, other]): Fixture.send(sim, payload)
	sim.step()
	return Fixture.object(sim, unit)

func test_container_same_tick_cases(runner) -> bool:
	_kind("test_ferry", 100, true, ["infantry", "vehicle", "air"])
	var foe_position := Vector2(20.5, 20.5)
	var unit_cases := {
		"move": [func(u: Dictionary) -> bool: return u.order != null and u.order.target == [12.5, 12.5], {"type": "move", "target": [12.5, 12.5]}],
		"stop": [func(u: Dictionary) -> bool: return u.status == "idle", {"type": "stop"}],
		"attack_move": [func(u: Dictionary) -> bool: return u.combat.mode == "attack_move", {"type": "attack_move", "target": [12.5, 12.5]}],
		"attack": [func(u: Dictionary) -> bool: return u.combat.mode == "attack", {"type": "attack"}],
	}
	for name in unit_cases:
		for other_first in [true, false]:
			var sim = _world()
			var car: int = sim.spawn(1, Vector2(5.5, 5.5), "test_ferry")
			var rifle: int = sim.spawn(1, Vector2(9.5, 5.5), "usa_rifle_infantry")
			var foe: int = sim.spawn(2, foe_position, "usa_builder")
			var other: Dictionary = unit_cases[name][1].duplicate()
			other.entity_ids = [rifle]
			if name == "attack": other.target_id = foe
			var state: Dictionary = _unit_case(sim, rifle, car, other, other_first)
			var label: String = "CT9 %s %s enter: " % [name, "then" if other_first else "after"]
			if other_first:
				runner.check(_enters(state) == car and _results(sim).all(func(r: Dictionary) -> bool: return r.ok or name == "move"), label + "the later enter wins")
			else:
				runner.check(_enters(state) == 0 and unit_cases[name][0].call(state), label + "the later command wins")
	_builder_cases(runner)
	_unrelated_cases(runner)
	Registry.clear_test_kinds()
	return true

func _builder_cases(runner) -> void:
	for other_first in [true, false]:
		var sim = _world()
		var car: int = sim.spawn(1, Vector2(5.5, 5.5), "test_ferry")
		var builder: int = sim.spawn(1, Vector2(9.5, 5.5), "usa_builder")
		var build := {"type": "build", "builder_id": builder, "building_kind": "usa_power_plant", "origin": [20, 20]}
		var state: Dictionary = _unit_case(sim, builder, car, build, other_first)
		var label: String = "CT9 build %s enter: " % ("then" if other_first else "after")
		if other_first: runner.check(_enters(state) == car and state.construction_id == null, label + "the later enter wins")
		else: runner.check(_enters(state) == 0 and state.construction_id != null, label + "the later build wins")
	for other_first in [true, false]:
		var sim = _world()
		var car: int = sim.spawn(1, Vector2(5.5, 5.5), "test_ferry")
		var first: int = sim.spawn(1, Vector2(9.5, 5.5), "usa_builder")
		var second: int = sim.spawn(1, Vector2(9.5, 8.5), "usa_builder")
		Fixture.send(sim, {"type": "build", "builder_id": first, "building_kind": "usa_power_plant", "origin": [20, 20]})
		sim.step()
		var site: int = sim.snapshot().buildings[0].id
		var state: Dictionary = _unit_case(sim, second, car, {"type": "resume_build", "builder_id": second, "building_id": site}, other_first)
		var label: String = "CT9 resume_build %s enter: " % ("then" if other_first else "after")
		if other_first: runner.check(_enters(state) == car and state.construction_id == null, label + "the later enter wins")
		else: runner.check(_enters(state) == 0 and state.construction_id == site, label + "the later resume wins")

func _unrelated_cases(runner) -> void:
	for other_first in [true, false]:
		var sim = _world()
		var car: int = sim.spawn(1, Vector2(5.5, 5.5), "test_ferry")
		var rifle: int = sim.spawn(1, Vector2(9.5, 5.5), "usa_rifle_infantry")
		var collector: int = sim.spawn(1, Vector2(12.5, 12.5), "usa_collector")
		var source: int = sim.add_supply_source(Vector2i(20, 20), 100)
		var barracks: int = EconomyFixture.add_completed(sim, 1, "usa_barracks", Vector2i(24, 4))
		var site: int = EconomyFixture.add_completed(sim, 1, "usa_power_plant", Vector2i(24, 10))
		sim._buildings[site].completed = false
		Fixture.send(sim, {"type": "produce", "building_id": barracks, "unit_kind": "usa_rifle_infantry"})
		sim.step()
		var entry: int = sim.snapshot().buildings.filter(func(b: Dictionary) -> bool: return b.id == barracks)[0].queue[0].id
		var others: Array = [{"type": "cancel_build", "building_id": site}, {"type": "produce", "building_id": barracks, "unit_kind": "usa_rifle_infantry"}, {"type": "cancel_production", "building_id": barracks, "production_id": entry}, {"type": "set_rally", "building_id": barracks, "target": [26.5, 8.5]}, {"type": "gather", "entity_ids": [collector], "source_id": source}]
		var enter := {"type": "enter", "entity_ids": [rifle], "target_id": car}
		for payload in (others + [enter] if other_first else [enter] + others): Fixture.send(sim, payload)
		sim.step()
		var label: String = "CT9 economy commands %s enter: " % ("before" if other_first else "after")
		runner.check(_results(sim).all(func(r: Dictionary) -> bool: return r.ok), label + "every command applies")
		var state: Dictionary = sim.snapshot()
		runner.check(_enters(Fixture.object(sim, rifle)) == car and Fixture.object(sim, site).is_empty() and Fixture.object(sim, collector).collection.enabled and Fixture.object(sim, barracks).rally == [26.5, 8.5], label + "each takes effect beside the enter")
		runner.check(state.buildings.filter(func(b: Dictionary) -> bool: return b.id == barracks)[0].queue.size() == 1, label + "queue holds the new order only")

func test_unload_with_container_move(runner) -> bool:
	for unload_first in [true, false]:
		var sim = _world()
		var car: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_light_vehicle")
		var rifle: int = sim.spawn(1, Vector2(8.5, 5.5), "usa_rifle_infantry")
		_load(sim, car, [rifle])
		var unload := {"type": "unload", "target_id": car}
		var move := {"type": "move", "entity_ids": [car], "target": [25.5, 5.5]}
		for payload in ([unload, move] if unload_first else [move, unload]): Fixture.send(sim, payload)
		sim.step()
		var exit: Array = Fixture.object(sim, rifle).position
		for i in range(60): sim.step()
		var label: String = "CT10 unload %s move: " % ("then" if unload_first else "after")
		runner.check(Fixture.object(sim, rifle).position == exit and Fixture.object(sim, car).position[0] > exit[0] + 3.0, label + "passenger exits at the old position and the container leaves")
	return true

func test_container_removed_while_approaching(runner) -> bool:
	var sim = _world()
	var car: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_light_vehicle")
	var rifle: int = sim.spawn(1, Vector2(15.5, 5.5), "usa_rifle_infantry")
	Fixture.send(sim, {"type": "enter", "entity_ids": [rifle], "target_id": car})
	for i in range(3): sim.step()
	runner.check(_enters(Fixture.object(sim, rifle)) == car, "CT11 unit is approaching")
	sim.remove_object(car)
	var state: Dictionary = Fixture.object(sim, rifle)
	runner.check(state.status == "idle" and state.order == null and state.combat.mode == "guard", "CT11 walkers go idle when the container is removed")
	for i in range(5): sim.step()
	runner.check(Fixture.object(sim, rifle).status == "idle", "CT11 they stay idle")
	return true

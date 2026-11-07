@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/combat_fixture.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")

const A := Vector2i(10, 10)
const B := Vector2i(20, 10)
const FULL: String = "Container is full"
const CANNOT: String = "Cannot enter this container"

func cases() -> Array[Callable]:
	return [test_enter_one_hub_exit_another, test_tunnel_capacity_shared, test_tunnel_rejects, test_tunnel_heal_once_per_network, test_hub_spawns_two_fighters_once, test_hub_fires_tunnel_gun, test_last_hub_buries_occupants, test_tunnel_occupants_ignored, test_last_hub_dies_on_boarding_tick, test_tunnel_same_tick_cases]

func _world() -> RefCounted:
	var sim = Fixture.world()
	sim.add_player(1, 10000)
	sim.add_player(2, 0)
	return sim

func _hub(sim, origin: Vector2i, owner: int = 1) -> int:
	return EconomyFixture.add_completed(sim, owner, "frc_defence", origin)

func _tunnel(sim) -> Array:
	return sim.snapshot().players[0].get("tunnel", [])

func _units(sim, count: int, x: float = 14.5, y: float = 2.5, kind: String = "frc_rifle_infantry") -> Array:
	var ids: Array = []
	for i in count: ids.append(sim.spawn(1, Vector2(x, y + i), kind))
	return ids

func _inside(sim, id: int) -> int:
	return Fixture.object(sim, id).get("container_id", 0)

func _send(sim, payload: Dictionary) -> Dictionary:
	return Fixture.send(sim, payload)

func _board(sim, ids: Array, hub: int, limit: int = 600) -> bool:
	if not _send(sim, {"type": "enter", "entity_ids": ids, "target_id": hub}).ok: return false
	for i in range(limit):
		sim.step()
		if ids.all(func(id: int) -> bool: return _inside(sim, id) != 0): return true
	return false

func _deaths(sim) -> int:
	return sim.snapshot().combat_events.filter(func(e: Dictionary) -> bool: return e.type == "death").size()

func test_enter_one_hub_exit_another(runner) -> bool:
	var sim = _world()
	var a: int = _hub(sim, A)
	var b: int = _hub(sim, B)
	var ids: Array = _units(sim, 3)
	ids.append(sim.spawn(1, Vector2(14.5, 14.5), "frc_light_vehicle"))
	runner.check(_board(sim, ids, a), "TN1 three riflemen and a pickup board hub A")
	runner.check(_tunnel(sim) == ids and ids.all(func(id: int) -> bool: return _inside(sim, id) == a), "TN1 tunnel lists the ids in order, each inside hub A")
	runner.check(_send(sim, {"type": "unload", "target_id": b}).ok, "TN1 unload at hub B accepted")
	sim.step()
	var centre := Vector2(20.5, 10.5)
	var out: bool = ids.all(func(id: int) -> bool:
		var unit: Dictionary = Fixture.object(sim, id)
		return not unit.has("container_id") and unit.status == "arrived" and Vector2(unit.position[0], unit.position[1]).distance_to(centre) < 4.0)
	var cells: Dictionary = {}
	for id in ids: cells[Vector2i(Vector2(Fixture.object(sim, id).position[0], Fixture.object(sim, id).position[1]).floor())] = true
	runner.check(out and cells.size() == 4, "TN1 all four stand on distinct free cells around hub B, arrived")
	runner.check(not sim.snapshot().players[0].has("tunnel"), "TN1 tunnel key erased")
	return true

func test_tunnel_capacity_shared(runner) -> bool:
	var sim = _world()
	var a: int = _hub(sim, A)
	var b: int = _hub(sim, B)
	var ids: Array = _units(sim, 11)
	runner.check(_send(sim, {"type": "enter", "entity_ids": ids.slice(0, 6), "target_id": a}).ok and _send(sim, {"type": "enter", "entity_ids": ids.slice(6, 10), "target_id": b}).ok, "TN2 six at A and four at B accepted")
	sim.step()
	for hub in [a, b]:
		var extra: Dictionary = _send(sim, {"type": "enter", "entity_ids": [ids[10]], "target_id": hub})
		runner.check(not extra.ok and extra.error == FULL, "TN2 an 11th enter is full while ten walk: " + extra.error)
	for i in range(600): sim.step()
	runner.check(_tunnel(sim).size() == 10 and ids.slice(0, 10).all(func(id: int) -> bool: return _inside(sim, id) != 0), "TN2 all ten are inside")
	for hub in [a, b]:
		var extra: Dictionary = _send(sim, {"type": "enter", "entity_ids": [ids[10]], "target_id": hub})
		runner.check(not extra.ok and extra.error == FULL, "TN2 an 11th enter is full when the network is full: " + extra.error)
	return true

func test_tunnel_rejects(runner) -> bool:
	var sim = _world()
	var own: int = _hub(sim, A)
	var foreign: int = _hub(sim, B, 2)
	var site: int = _hub(sim, Vector2i(24, 20))
	sim._buildings[site].completed = false
	var rifle: int = _units(sim, 1)[0]
	var air: int = sim.spawn(1, Vector2(14.5, 20.5), "usa_collector")
	var rejects := {"air unit": [[air], own], "another seat's hub": [[rifle], foreign], "a hub foundation": [[rifle], site]}
	for name in rejects:
		var result: Dictionary = _send(sim, {"type": "enter", "entity_ids": rejects[name][0], "target_id": rejects[name][1]})
		runner.check(not result.ok and result.error == CANNOT, "TN3 " + name + ": " + result.error)
	runner.check(not _send(sim, {"type": "unload", "target_id": site}).ok, "TN3 a foundation cannot unload")
	runner.check(_send(sim, {"type": "enter", "entity_ids": [rifle], "target_id": own}).ok, "TN3 a rifleman may enter an own hub")
	return true

func test_tunnel_heal_once_per_network(runner) -> bool:
	for hubs in [1, 3]:
		var sim = _world()
		var first: int = _hub(sim, A)
		for i in range(hubs - 1): _hub(sim, Vector2i(20 + i * 3, 10))
		var rifle: int = _units(sim, 1)[0]
		_board(sim, [rifle], first)
		var unit: Dictionary = sim._entities[rifle]
		unit.hp = 1000
		var gain: int = (unit.max_hp + 149) / 150
		sim.step()
		runner.check(sim._entities[rifle].hp == 1000 + gain, "TN4 %d hub(s): one heal of %d per tick, got %d" % [hubs, gain, sim._entities[rifle].hp - 1000])
		for i in range(149): sim.step()
		runner.check(sim._entities[rifle].hp == unit.max_hp, "TN4 %d hub(s): full by tick 150" % hubs)
	return true

func _count(sim, kind: String) -> int:
	return sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.kind == kind).size()

func test_hub_spawns_two_fighters_once(runner) -> bool:
	var sim = _world()
	sim.spawn(1, Vector2(4.5, 4.5), "frc_builder")
	EconomyFixture.add_completed(sim, 1, "frc_barracks", Vector2i(2, 20))
	var hub: int = EconomyFixture.build(runner, sim, "frc_defence", Vector2i(10, 10))
	runner.check(hub != -1 and _count(sim, "frc_rocket_infantry") == 2, "TN5 a built hub spawns two rocket fighters")
	sim.remove_object(hub)
	for i in range(1800):
		sim.step()
		if sim.snapshot().buildings.any(func(b: Dictionary) -> bool: return b.kind == "frc_defence" and b.completed): break
	runner.check(sim.snapshot().buildings.any(func(b: Dictionary) -> bool: return b.kind == "frc_defence" and b.completed) and _count(sim, "frc_rocket_infantry") == 2, "TN5 a hub rebuilt from its hole spawns none")
	return true

func test_hub_fires_tunnel_gun(runner) -> bool:
	var reach: float = 7.0 - 0.1 + CombatDefinitions.radius("frc_defence") + CombatDefinitions.radius("usa_rifle_infantry")
	var sim = _world()
	var hub: int = _hub(sim, A)
	sim.spawn(2, Vector2(10.5 + reach - 0.05, 10.5), "usa_rifle_infantry")
	var shots: Array = []
	for i in range(18):
		sim.step()
		shots.append_array(sim.snapshot().combat_events.filter(func(e: Dictionary) -> bool: return e.type == "shot" and e.attacker_id == hub))
	runner.check(shots.map(func(s: Dictionary) -> int: return s.tick) == [0, 8, 16] and shots.all(func(s: Dictionary) -> bool: return s.damage == 15000), "TN6 15000 small-arms damage every 8 ticks at 6.85 edge to edge, got " + str(shots))
	var far = _world()
	var idle: int = _hub(far, A)
	far.spawn(2, Vector2(10.5 + reach + 0.05, 10.5), "usa_rifle_infantry")
	far.step()
	runner.check(far.snapshot().combat_events.filter(func(e: Dictionary) -> bool: return e.type == "shot" and e.attacker_id == idle).is_empty(), "TN6 no shot beyond 7.0")
	return true

func test_last_hub_buries_occupants(runner) -> bool:
	var sim = _world()
	var a: int = _hub(sim, A)
	var pickup: int = sim.spawn(1, Vector2(14.5, 14.5), "frc_light_vehicle")
	var riders: Array = _units(sim, 2, 14.5, 17.5)
	runner.check(_board(sim, riders, pickup), "TN7 two riflemen board the pickup")
	var rifle: int = _units(sim, 1, 16.5, 2.5)[0]
	runner.check(_board(sim, [pickup, rifle], a), "TN7 pickup and rifleman enter the hub")
	runner.check(sim._entities[riders[0]].container_id == pickup, "TN7 riders stay in the pickup")
	runner.check(_tunnel(sim) == [pickup, rifle], "TN7 riders are not in the tunnel list")
	sim.remove_object(a)
	var gone: bool = [pickup, rifle, riders[0], riders[1]].all(func(id: int) -> bool: return not sim._entities.has(id))
	runner.check(gone and _deaths(sim) == 0 and not sim.snapshot().players[0].has("tunnel"), "TN7 the last hub buries occupants and riders with no death events")
	var keep = _world()
	var first: int = _hub(keep, A)
	var second: int = _hub(keep, B)
	var late: int = _hub(keep, Vector2i(24, 10))
	var ids: Array = _units(keep, 2)
	_board(keep, ids, second)
	keep.remove_object(second)
	var moved: bool = ids.all(func(id: int) -> bool: return _inside(keep, id) == first and Fixture.object(keep, id).position == [10.5, 10.5])
	runner.check(moved and _tunnel(keep) == ids and late != -1, "TN7 with another hub the occupants move to the lowest-id remaining one")
	return true

func test_tunnel_occupants_ignored(runner) -> bool:
	var sim = _world()
	var a: int = _hub(sim, A)
	var rifle: int = _units(sim, 1)[0]
	runner.check(_board(sim, [rifle], a), "TN8 rifleman inside")
	var foe: int = sim.spawn(2, Vector2(12.5, 14.5), "usa_rifle_infantry")
	var hunter: int = sim.spawn(2, Vector2(14.5, 14.5), "usa_rocket_infantry")
	runner.check(not Combat.valid_target(sim, 2, rifle), "TN8 an occupant is no target")
	var hp: int = sim._entities[rifle].hp
	var before: int = _deaths(sim)
	for i in range(60): sim.step()
	var shot_at: bool = sim.snapshot().combat_events.any(func(e: Dictionary) -> bool: return e.type == "shot" and (e.attacker_id == rifle or e.target_id == rifle))
	runner.check(not shot_at and sim._entities[rifle].hp >= hp and _deaths(sim) == before, "TN8 occupants take and fire no shots")
	runner.check(sim._entities[rifle].combat.target_id == null and foe != hunter, "TN8 an occupant keeps no target")
	return true

func test_last_hub_dies_on_boarding_tick(runner) -> bool:
	var sim = _world()
	var a: int = _hub(sim, A)
	var rifle: int = sim.spawn(1, Vector2(10.5, 11.5), "frc_rifle_infantry")
	sim.spawn(2, Vector2(13.5, 10.5), "usa_rifle_infantry")
	sim._buildings[a].hp = 1
	_send(sim, {"type": "enter", "entity_ids": [rifle], "target_id": a})
	sim.step()
	var events: Array = sim.snapshot().combat_events.filter(func(e: Dictionary) -> bool: return e.type == "death")
	runner.check(events.map(func(e: Dictionary) -> Array: return [e.tick, e.object_id]) == [[0, a]], "TN9 the hub dies on the boarding tick and only it has a death event, got " + str(events))
	runner.check(not sim._entities.has(rifle) and not sim.snapshot().players[0].has("tunnel"), "TN9 the boarded rifleman goes with the network, tunnel key erased")
	return true

func _enters(unit: Dictionary) -> int:
	return unit.order.get("target_id", 0) if unit.order != null else 0

func _results(sim) -> Array:
	return sim.snapshot().command_results

func _same_tick(sim, unit: int, hub: int, other: Dictionary, other_first: bool) -> Dictionary:
	var enter := {"type": "enter", "entity_ids": [unit], "target_id": hub}
	for payload in ([other, enter] if other_first else [enter, other]): _send(sim, payload)
	sim.step()
	return Fixture.object(sim, unit)

func test_tunnel_same_tick_cases(runner) -> bool:
	var unit_cases := {
		"move": [func(u: Dictionary) -> bool: return u.order != null and u.order.target == [18.5, 18.5], {"type": "move", "target": [18.5, 18.5]}],
		"stop": [func(u: Dictionary) -> bool: return u.status == "idle", {"type": "stop"}],
		"attack_move": [func(u: Dictionary) -> bool: return u.combat.mode == "attack_move", {"type": "attack_move", "target": [18.5, 18.5]}],
		"attack": [func(u: Dictionary) -> bool: return u.combat.mode == "attack", {"type": "attack"}],
	}
	for name in unit_cases:
		for other_first in [true, false]:
			var sim = _world()
			var hub: int = _hub(sim, A)
			var rifle: int = _units(sim, 1, 16.5, 10.5)[0]
			var foe: int = sim.spawn(2, Vector2(26.5, 26.5), "usa_builder")
			var other: Dictionary = unit_cases[name][1].duplicate()
			other.entity_ids = [rifle]
			if name == "attack": other.target_id = foe
			var state: Dictionary = _same_tick(sim, rifle, hub, other, other_first)
			var label: String = "TN10 %s %s enter: " % [name, "then" if other_first else "after"]
			if other_first: runner.check(_enters(state) == hub, label + "the later enter wins")
			else: runner.check(_enters(state) == 0 and unit_cases[name][0].call(state), label + "the later command wins")
	_pickup_case(runner)
	_builder_cases(runner)
	_independent_cases(runner)
	_unload_cases(runner)
	return true

func _pickup_case(runner) -> void:
	for other_first in [true, false]:
		var sim = _world()
		var hub: int = _hub(sim, A)
		var pickup: int = sim.spawn(1, Vector2(16.5, 10.5), "frc_light_vehicle")
		var rifle: int = _units(sim, 1, 16.5, 14.5)[0]
		var board := {"type": "enter", "entity_ids": [rifle], "target_id": pickup}
		var state: Dictionary = _same_tick(sim, pickup, hub, board, other_first)
		runner.check(_enters(state) == hub and _enters(Fixture.object(sim, rifle)) == pickup, "TN10 enter(pickup) %s enter(hub): both apply to different units" % ("then" if other_first else "after"))

func _builder_cases(runner) -> void:
	for other_first in [true, false]:
		var sim = _world()
		var hub: int = _hub(sim, A)
		var builder: int = sim.spawn(1, Vector2(16.5, 10.5), "frc_builder")
		var build := {"type": "build", "builder_id": builder, "building_kind": "frc_supply_center", "origin": [22, 20]}
		var state: Dictionary = _same_tick(sim, builder, hub, build, other_first)
		var label: String = "TN10 build %s enter: " % ("then" if other_first else "after")
		if other_first: runner.check(_enters(state) == hub and state.construction_id == null, label + "the later enter wins")
		else: runner.check(_enters(state) == 0 and state.construction_id != null, label + "the later build wins")
	for other_first in [true, false]:
		var sim = _world()
		var hub: int = _hub(sim, A)
		var first: int = sim.spawn(1, Vector2(16.5, 10.5), "frc_builder")
		var second: int = sim.spawn(1, Vector2(16.5, 13.5), "frc_builder")
		_send(sim, {"type": "build", "builder_id": first, "building_kind": "frc_supply_center", "origin": [22, 20]})
		sim.step()
		var site: int = sim.snapshot().buildings.filter(func(b: Dictionary) -> bool: return b.kind == "frc_supply_center")[0].id
		var state: Dictionary = _same_tick(sim, second, hub, {"type": "resume_build", "builder_id": second, "building_id": site}, other_first)
		var label: String = "TN10 resume_build %s enter: " % ("then" if other_first else "after")
		if other_first: runner.check(_enters(state) == hub and state.construction_id == null, label + "the later enter wins")
		else: runner.check(_enters(state) == 0 and state.construction_id == site, label + "the later resume wins")

func _independent_cases(runner) -> void:
	for other_first in [true, false]:
		var sim = _world()
		var hub: int = _hub(sim, A)
		var rifle: int = _units(sim, 1, 16.5, 10.5)[0]
		var collector: int = sim.spawn(1, Vector2(12.5, 20.5), "frc_builder")
		var source: int = sim.add_supply_source(Vector2i(20, 24), 100)
		var barracks: int = EconomyFixture.add_completed(sim, 1, "frc_barracks", Vector2i(24, 4))
		var site: int = EconomyFixture.add_completed(sim, 1, "frc_supply_center", Vector2i(24, 10))
		sim._buildings[site].completed = false
		var target: int = sim.spawn(2, Vector2(10.5, 15.5), "usa_builder")
		_send(sim, {"type": "produce", "building_id": barracks, "unit_kind": "frc_rifle_infantry"})
		sim.step()
		var entry: int = sim.snapshot().buildings.filter(func(b: Dictionary) -> bool: return b.id == barracks)[0].queue[0].id
		var others: Array = [{"type": "cancel_build", "building_id": site}, {"type": "produce", "building_id": barracks, "unit_kind": "frc_rifle_infantry"}, {"type": "cancel_production", "building_id": barracks, "production_id": entry}, {"type": "set_rally", "building_id": barracks, "target": [26.5, 8.5]}, {"type": "gather", "entity_ids": [collector], "source_id": source}, {"type": "defence_attack", "building_id": hub, "target_id": target}]
		var enter := {"type": "enter", "entity_ids": [rifle], "target_id": hub}
		for payload in (others + [enter] if other_first else [enter] + others): _send(sim, payload)
		sim.step()
		var label: String = "TN10 independent commands %s enter: " % ("before" if other_first else "after")
		runner.check(_results(sim).all(func(r: Dictionary) -> bool: return r.ok), label + "every command applies")
		runner.check(_enters(Fixture.object(sim, rifle)) == hub and Fixture.object(sim, site).is_empty() and Fixture.object(sim, collector).collection.enabled and Fixture.object(sim, barracks).rally == [26.5, 8.5] and Fixture.object(sim, hub).combat.target_id == target, label + "each takes effect beside the enter")

func _unload_cases(runner) -> void:
	var sim = _world()
	var a: int = _hub(sim, A)
	var rifle: int = _units(sim, 1)[0]
	_board(sim, [rifle], a)
	var other: int = _units(sim, 1, 16.5, 10.5)[0]
	_send(sim, {"type": "unload", "target_id": a})
	_send(sim, {"type": "enter", "entity_ids": [other], "target_id": a})
	sim.step()
	runner.check(_results(sim).all(func(r: Dictionary) -> bool: return r.ok) and not sim._entities[rifle].has("container_id") and _enters(sim._entities[other]) == a, "TN10 unload and a second enter on one tick both apply")
	for doomed_is_unloaded in [true, false]:
		var world = _world()
		var first: int = _hub(world, A)
		var second: int = _hub(world, B)
		var ids: Array = _units(world, 2)
		_board(world, ids, first)
		var doomed: int = first if doomed_is_unloaded else second
		world._buildings[doomed].hp = 1
		var hp: Array = ids.map(func(id: int) -> int: return world._entities[id].hp)
		world.spawn(2, Vector2(13.5 if doomed_is_unloaded else 23.5, 10.5), "usa_rifle_infantry")
		_send(world, {"type": "unload", "target_id": first})
		world.step()
		var survivors: bool = ids.all(func(id: int) -> bool: return world._entities.has(id) and not world._entities[id].has("container_id"))
		var label: String = "the unloaded hub" if doomed_is_unloaded else "the other hub"
		runner.check(not world._buildings.has(doomed) and survivors and ids.map(func(id: int) -> int: return world._entities[id].hp) == hp and _deaths(world) == 1, "TN10 unload and the death of %s on one tick: occupants out and unharmed" % label)
	var walk = _world()
	var hub: int = _hub(walk, A)
	var rifles: Array = _units(walk, 2, 16.5, 10.5)
	_send(walk, {"type": "enter", "entity_ids": rifles, "target_id": hub})
	walk.step()
	runner.check(rifles.all(func(id: int) -> bool: return _enters(walk._entities[id]) == hub), "TN10 walkers are heading for the hub")
	walk.remove_object(hub)
	walk.step()
	runner.check(rifles.all(func(id: int) -> bool: return _enters(walk._entities[id]) == 0 and walk._entities[id].combat.mode == "guard"), "TN10 enter and the hub's removal on one tick: walkers give up and guard")

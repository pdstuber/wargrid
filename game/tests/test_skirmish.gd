@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Economy = preload("res://tests/economy_fixture.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Fixture = preload("res://tests/combat_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

func cases() -> Array[Callable]:
	return [test_skirmish_initial_state, test_roster_production, test_bot_cycles_unit_list, test_opponent_pays_and_retries, test_opponent_attack_policy, test_opponent_defends_base, test_defence_skips_busy_units, test_match_lifecycle, test_restart_state]

func _owned(items: Array, player: int) -> Array:
	return items.filter(func(item: Dictionary) -> bool: return item.owner == player)

func _built(items: Array, player: int) -> Array:
	return _owned(items, player).filter(func(item: Dictionary) -> bool: return item.kind != "usa_command_center")

func test_skirmish_initial_state(runner) -> bool:
	var sim = Skirmish.create()
	var state: Dictionary = sim.snapshot()
	runner.check(state.map.size == [48, 32], "K1 map size")
	runner.check(state.players.size() == 2 and state.players[0].credits == 10000 and state.players[1].credits == 10000, "K1 two players with 10000 credits")
	runner.check(state.entities.size() == 2 and state.entities[0].id == 1 and state.entities[0].owner == 1 and state.entities[0].kind == "usa_builder" and state.entities[0].position == [4.5, 14.5], "K1 builder one")
	runner.check(state.entities[1].id == 3 and state.entities[1].owner == 2 and state.entities[1].position == [43.5, 14.5], "K1 builder two")
	runner.check(state.sources.size() == 2 and state.sources[0].id == 5 and state.sources[0].origin == [5, 3] and state.sources[0].boxes == 200 and state.sources[1].id == 6 and state.sources[1].origin == [40, 3] and state.sources[1].boxes == 200, "K1 sources left then right")
	runner.check(state.buildings.map(func(building: Dictionary) -> Array: return [building.id, building.owner, building.kind, building.completed, building.origin]) == [[2, 1, "usa_command_center", true, [4, 17]], [4, 2, "usa_command_center", true, [41, 17]]] and state.pending_commands.is_empty() and state.tick == 0, "K1 only the command centers, no army or commands")
	runner.check(state.match == {"players": [1, 2], "status": "ongoing", "winner": null, "ended_tick": null} and Skirmish.create(false).snapshot().match == null, "K1 match starts after setup")
	runner.check(Skirmish.origin("usa_power_plant", 2) == Vector2i(38, 12) and Skirmish.origin("usa_supply_center", 2) == Vector2i(37, 5) and Skirmish.origin("usa_barracks", 2) == Vector2i(34, 12) and Skirmish.origin("usa_factory", 2) == Vector2i(33, 18) and Skirmish.origin("usa_factory", 1) == Vector2i(12, 18), "K1 mirrored origins")
	runner.check(Skirmish.create().snapshot() == state, "K1 creation is repeatable")
	return true

func _queue_and_wait(runner, sim: RefCounted, producer: int, kind: String, label: String) -> int:
	var before: int = sim.snapshot().players[0].credits
	var result: Dictionary = Economy.send(sim, {"type": "produce", "building_id": producer, "unit_kind": kind})
	runner.check(result.ok, label + " queued: " + result.error)
	sim.step()
	var cost: int = before - sim.snapshot().players[0].credits
	var count: int = _owned(sim.snapshot().entities, 1).filter(func(unit: Dictionary) -> bool: return unit.kind == kind).size()
	for tick in range(400):
		sim.step()
		if _owned(sim.snapshot().entities, 1).filter(func(unit: Dictionary) -> bool: return unit.kind == kind).size() > count:
			return tick * 1000 + cost
	return -1

func test_roster_production(runner) -> bool:
	var sim = Skirmish.create()
	var barracks: int = Economy.build(runner, sim, "usa_barracks", Skirmish.origin("usa_barracks", 1))
	runner.check(not Economy.send(sim, {"type": "produce", "building_id": barracks, "unit_kind": "usa_tank"}).ok, "R2 barracks rejects tanks")
	var infantry: int = _queue_and_wait(runner, sim, barracks, "usa_rifle_infantry", "R2")
	@warning_ignore("integer_division")
	runner.check(infantry % 1000 == 225 and infantry / 1000 >= 148 and infantry / 1000 <= 150, "R2 infantry costs 225 and takes 150 work ticks, got " + str(infantry))
	Economy.build(runner, sim, "usa_power_plant", Skirmish.origin("usa_power_plant", 1))
	Economy.build(runner, sim, "usa_supply_center", Skirmish.origin("usa_supply_center", 1))
	var factory: int = Economy.build(runner, sim, "usa_factory", Skirmish.origin("usa_factory", 1))
	runner.check(not Economy.send(sim, {"type": "produce", "building_id": factory, "unit_kind": "usa_rifle_infantry"}).ok, "R2 factory rejects infantry")
	var tank: int = _queue_and_wait(runner, sim, factory, "usa_tank", "R2")
	@warning_ignore("integer_division")
	runner.check(tank % 1000 == 900 and tank / 1000 >= 298 and tank / 1000 <= 300, "R2 tank costs 900 and takes 300 work ticks, got " + str(tank))
	var vehicle: int = _queue_and_wait(runner, sim, factory, "usa_light_vehicle", "R2")
	@warning_ignore("integer_division")
	runner.check(vehicle % 1000 == 700 and vehicle / 1000 >= 298 and vehicle / 1000 <= 300, "R2 legacy vehicle still 700 and 300 ticks, got " + str(vehicle))
	return true

func _decide(sim: RefCounted) -> void:
	if sim.snapshot().tick % 30 == 0: Skirmish.issue_opponent(sim)

func test_bot_cycles_unit_list(runner) -> bool:
	var sim = Skirmish.create()
	for tick in range(4000):
		Skirmish.issue_opponent(sim)
		sim.step()
	var kinds: Array = []
	for unit: Dictionary in sim.snapshot().entities:
		if unit.owner == 2 and Registry.kind(unit.kind).get("class", "") in ["infantry", "vehicle"] and not Registry.is_builder(unit.kind): kinds.append(unit.kind)
	var rifles: int = kinds.count("usa_rifle_infantry")
	var rockets: int = kinds.count("usa_rocket_infantry")
	var tanks: int = kinds.count("usa_tank")
	var scouts: int = kinds.count("usa_light_vehicle")
	runner.check(rifles + rockets >= 2 and absi(rifles - rockets) <= 1 and rifles >= rockets, "B3 barracks cycles rifle then rocket, fewest owned first")
	runner.check(tanks + scouts >= 1 and tanks >= scouts and tanks - scouts <= 1, "B3 factory cycles tank then scout car, fewest owned first")
	return true

func test_opponent_pays_and_retries(runner) -> bool:
	var sim = Skirmish.create()
	Skirmish.issue_opponent(sim)
	sim.step()
	var first: Dictionary = sim.snapshot()
	runner.check(_built(first.buildings, 2).size() == 1 and _built(first.buildings, 2)[0].kind == "usa_power_plant" and _built(first.buildings, 2)[0].origin == [38, 12] and first.players[1].credits == 9200, "O1 first decision places the mirrored reactor and pays 800")
	var open_sites: int = 0
	var most_queued: int = 0
	var paused_resumed: bool = false
	for tick in range(1, 3000):
		_decide(sim)
		if tick == 100:
			Economy.send(sim, {"player": 2, "type": "stop", "entity_ids": [3]})
		sim.step()
		var state: Dictionary = sim.snapshot()
		var mine: Array = _built(state.buildings, 2)
		open_sites = maxi(open_sites, mine.filter(func(building: Dictionary) -> bool: return not building.completed).size())
		for building in mine: most_queued = maxi(most_queued, building.queue.size())
		if tick == 101: paused_resumed = mine[0].builder_id == null
		if tick == 140: paused_resumed = paused_resumed and mine[0].builder_id == 3
	runner.check(open_sites == 1, "O1 never more than one unfinished structure")
	runner.check(paused_resumed, "O1 a paused foundation is resumed by the lowest builder")
	var final: Dictionary = sim.snapshot()
	var kinds: Array = _built(final.buildings, 2).map(func(building: Dictionary) -> String: return building.kind)
	runner.check(kinds == ["usa_power_plant", "usa_supply_center", "usa_barracks", "usa_factory"] and _built(final.buildings, 2).all(func(building: Dictionary) -> bool: return building.completed), "O1 all four structures completed in order")
	runner.check(most_queued <= 1, "O1 at most one queued unit per producer")
	runner.check(_owned(final.entities, 2).any(func(unit: Dictionary) -> bool: return unit.kind == "usa_rifle_infantry") and _owned(final.entities, 2).any(func(unit: Dictionary) -> bool: return unit.kind == "usa_tank"), "O1 produced both unit kinds")
	runner.check(sim.snapshot().last_sequences.any(func(entry: Dictionary) -> bool: return entry.player == 2 and entry.sequence >= 5), "O1 sequences continue from the snapshot")
	var poor = _world(100)
	var before: Dictionary = poor.snapshot()
	Skirmish.issue_opponent(poor)
	runner.check(poor.snapshot() == before, "O1 unaffordable site changes nothing")
	return true

func _world(credits: int) -> RefCounted:
	var sim = Simulation.new([], Vector2i(48, 32))
	sim.add_player(1, 10000)
	sim.add_player(2, credits)
	sim.spawn(2, Vector2(43.5, 14.5), "usa_builder")
	return sim

func _army(sim: RefCounted) -> Array:
	var ids: Array = []
	for at in [Vector2(30.5, 10.5), Vector2(30.5, 12.5), Vector2(32.5, 10.5)]:
		ids.append(sim.spawn(2, at, "usa_rifle_infantry"))
	ids.append(sim.spawn(2, Vector2(32.5, 12.5), "usa_tank"))
	return ids

func _attack_targets(sim: RefCounted, army: Array) -> Array:
	var targets: Array = []
	for unit in sim.snapshot().entities:
		if army.has(unit.id) and unit.combat.mode == "attack": targets.append(unit.combat.target_id)
	return targets

func _to_tick(sim: RefCounted, tick: int) -> void:
	while sim.snapshot().tick < tick: sim.step()

func test_opponent_attack_policy(runner) -> bool:
	var sim = Skirmish.create(false)
	Economy.build(runner, sim, "usa_power_plant", Skirmish.origin("usa_power_plant", 1))
	var depot: int = Economy.build(runner, sim, "usa_supply_center", Skirmish.origin("usa_supply_center", 1))
	var barracks: int = Economy.build(runner, sim, "usa_barracks", Skirmish.origin("usa_barracks", 1))
	var reactor: int = depot - 1
	var first: int = sim.spawn(1, Vector2(20.5, 9.5), "usa_builder")
	var second: int = sim.spawn(1, Vector2(20.5, 11.5), "usa_builder")
	_to_tick(sim, 5370)
	var army: Array = _army(sim)
	Skirmish.issue_opponent(sim)
	_to_tick(sim, 5399)
	sim.step()
	runner.check(_attack_targets(sim, army).is_empty(), "A3 no attack orders before tick 5400")
	Skirmish.issue_opponent(sim)
	sim.step()
	runner.check(_attack_targets(sim, army) == [first, second, first, second], "A3 builder first, nearest then lowest ID, got " + str(_attack_targets(sim, army)))
	_to_tick(sim, 5430)
	Skirmish.issue_opponent(sim)
	runner.check(sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "attack").is_empty(), "A3 attackers are not reissued")
	for builder in [1, first, second]: sim.remove_object(builder)
	for expected in [barracks, 2, depot, reactor]:
		_to_tick(sim, (sim.snapshot().tick / 30 + 1) * 30)
		Skirmish.issue_opponent(sim)
		sim.step()
		runner.check(_attack_targets(sim, army) == [expected, expected, expected, expected], "A3 next category target " + str(expected) + ", got " + str(_attack_targets(sim, army)))
		sim.remove_object(expected)
	var lone = _world(10000)
	lone.remove_object(1)
	var before: Dictionary = lone.snapshot()
	Skirmish.issue_opponent(lone)
	runner.check(lone.snapshot() == before, "A3 an eliminated opponent submits nothing")
	return true

func _defence_world(runner) -> Array:
	var sim = Skirmish.create(false)
	Economy.build(runner, sim, "usa_power_plant", Skirmish.origin("usa_power_plant", 1))
	var edge: float = Skirmish.origin("usa_power_plant", 1).x + Definitions.building("usa_power_plant").footprint.x
	return [sim, edge]

func _decide_now(sim: RefCounted) -> void:
	_to_tick(sim, (sim.snapshot().tick / 30 + 1) * 30)
	Skirmish.issue_opponent(sim, 1)
	sim.step()

func _mode(sim: RefCounted, id: int) -> Dictionary:
	return Economy.object(sim, id).combat

func test_opponent_defends_base(runner) -> bool:
	for case in [[9.0, true], [10.0, true], [10.5, false]]:
		var world: Array = _defence_world(runner)
		var sim = world[0]
		var y: float = Skirmish.origin("usa_power_plant", 1).y + 0.5
		var intruder: int = sim.spawn(2, Vector2(world[1] + case[0], y), "usa_rifle_infantry")
		var tank: int = sim.spawn(1, Vector2(30.5, 28.5), "usa_tank")
		_decide_now(sim)
		var combat: Dictionary = _mode(sim, tank)
		runner.check((combat.mode == "attack" and combat.target_id == intruder) == case[1], "D1 intruder at " + str(case[0]) + " cells: defended=" + str(case[1]) + ", got " + str(combat))
	return true

func test_defence_skips_busy_units(runner) -> bool:
	var world: Array = _defence_world(runner)
	var sim = world[0]
	var y: float = Skirmish.origin("usa_power_plant", 1).y + 0.5
	var intruder: int = sim.spawn(2, Vector2(world[1] + 9.0, y), "usa_rifle_infantry")
	var far: int = sim.spawn(2, Vector2(46.5, 28.5), "usa_rifle_infantry")
	var attacker: int = sim.spawn(1, Vector2(30.5, 28.5), "usa_tank")
	var walker: int = sim.spawn(1, Vector2(30.5, 26.5), "usa_tank")
	var idle: int = sim.spawn(1, Vector2(30.5, 24.5), "usa_tank")
	Economy.send(sim, {"type": "attack", "entity_ids": [attacker], "target_id": far})
	Economy.send(sim, {"type": "move", "entity_ids": [walker], "target": [30.5, 20.5]})
	sim.step()
	_decide_now(sim)
	runner.check(_mode(sim, attacker).target_id == far and _mode(sim, walker).mode == "move" and _mode(sim, idle).target_id == intruder, "D2 busy units keep their orders, the idle one defends")
	sim.remove_object(intruder)
	sim.remove_object(far)
	sim.step()
	runner.check(_mode(sim, idle).mode == "guard" and _mode(sim, attacker).mode == "guard", "D2 after the intruder dies defenders guard where they stand")
	_decide_now(sim)
	runner.check(_attack_targets(sim, [attacker, idle]).is_empty(), "D2 no wave before ATTACK_TICK")
	_to_tick(sim, Skirmish.ATTACK_TICK)
	Skirmish.issue_opponent(sim, 1)
	sim.step()
	runner.check(_attack_targets(sim, [idle]).size() == 1, "D2 the wave picks up idle units after ATTACK_TICK")
	return true

func _start(runner, sim: RefCounted, players: Array[int], ok: bool, label: String) -> void:
	var before: Dictionary = sim.snapshot()
	runner.check(sim.start_match(players).ok == ok, label)
	if not ok: runner.check(sim.snapshot() == before, label + " leaves state unchanged")

func test_match_lifecycle(runner) -> bool:
	var sim = Skirmish.create(false)
	var none: Array[int] = []
	_start(runner, sim, none, false, "M0 empty list rejected")
	_start(runner, sim, [1] as Array[int], false, "M0 one player rejected")
	_start(runner, sim, [1, 1] as Array[int], false, "M0 duplicate rejected")
	_start(runner, sim, [1, 3] as Array[int], false, "M0 unregistered rejected")
	_start(runner, sim, [1, 2, 3] as Array[int], false, "M0 three players rejected")
	_start(runner, sim, [0, 1] as Array[int], false, "M0 non-positive rejected")
	runner.check(sim.snapshot().match == null, "M0 no match after rejections")
	var eliminated = Skirmish.create(false)
	eliminated.remove_object(4)
	_start(runner, eliminated, [2, 1] as Array[int], false, "M0 eliminated player rejected")
	_start(runner, sim, [2, 1] as Array[int], true, "M0 start accepted")
	runner.check(sim.snapshot().match == {"players": [1, 2], "status": "ongoing", "winner": null, "ended_tick": null}, "M0 players sorted, ongoing")
	_start(runner, sim, [1, 2] as Array[int], false, "M0 second start rejected")
	var old = Fixture.world()
	old.spawn(1, Vector2(2.5, 2.5), "usa_light_vehicle")
	for tick in range(5): old.step()
	runner.check(old.snapshot().match == null and old.snapshot().tick == 5, "M0 old scenes have no match")
	var held = Skirmish.create(false)
	Economy.build(runner, held, "usa_power_plant", Skirmish.origin("usa_power_plant", 1))
	var barracks: int = Economy.build(runner, held, "usa_barracks", Skirmish.origin("usa_barracks", 1))
	var infantry: int = held.spawn(1, Vector2(20.5, 20.5), "usa_rifle_infantry")
	var reactor_of_held: int = barracks - 1
	Economy.send(held, {"type": "build", "builder_id": 1, "building_kind": "usa_supply_center", "origin": [8, 5]})
	for tick in range(60): held.step()
	var foundation: Dictionary = held.snapshot().buildings.filter(func(building: Dictionary) -> bool: return building.kind == "usa_supply_center")[0]
	runner.check(not foundation.completed, "M0 an unfinished foundation is on the map")
	held.start_match([1, 2] as Array[int])
	held.remove_object(1)
	held.step()
	runner.check(held.snapshot().match.status == "ongoing", "M0 losing only the builder does not lose")
	for id: int in [2, reactor_of_held, barracks]: held.remove_object(id)
	held.step()
	runner.check(held.snapshot().match.status == "ongoing", "M0 a foundation keeps the seat alive (Zero Hour)")
	held.remove_object(foundation.id)
	held.step()
	var lost: Dictionary = held.snapshot()
	runner.check(lost.match.status == "won" and lost.match.winner == 2 and lost.match.ended_tick == lost.tick - 1 and held.snapshot().entities.any(func(unit: Dictionary) -> bool: return unit.id == infantry), "M0 an army does not prevent defeat; ended_tick is the pre-increment tick")
	for tick in range(10): held.step()
	runner.check(held.snapshot() == lost, "M0 terminal state is frozen")
	var rejected: Dictionary = Economy.send(held, {"type": "move", "entity_ids": [infantry], "target": [22.5, 20.5]})
	runner.check(not rejected.ok and held.snapshot() == lost, "M0 terminal match rejects orders unchanged")
	var draw = Skirmish.create(false)
	draw.start_match([1, 2] as Array[int])
	draw.remove_object(2)
	draw.remove_object(4)
	draw.step()
	var drawn: Dictionary = draw.snapshot()
	runner.check(drawn.match.status == "draw" and drawn.match.winner == null and drawn.match.ended_tick == 0 and drawn.tick == 1, "M0 simultaneous elimination is a draw")
	return true

func test_restart_state(runner) -> bool:
	var old = Skirmish.create()
	for tick in range(120):
		Skirmish.issue_opponent(old)
		old.step()
	var fresh = Skirmish.create()
	runner.check(fresh.snapshot() == Skirmish.create().snapshot() and fresh.snapshot().match != null, "X1 fresh worlds are identical and have a match")
	for tick in range(30): old.step()
	runner.check(fresh.snapshot() == Skirmish.create().snapshot(), "X1 a used world cannot change its replacement")
	return true

@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Economy = preload("res://tests/economy_fixture.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Fixture = preload("res://tests/combat_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const SeatSim = preload("res://scripts/net/seat_sim.gd")
const Client = preload("res://scripts/net/headless_client.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const StartSpots = preload("res://scripts/simulation/start_spots.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const OnlineDriver = preload("res://scripts/match/online_driver.gd")

const ASHFALL := "res://data/maps/ashfall.json"
const CHOSEN: Array[int] = [5, 1]

func cases() -> Array[Callable]:
	return [test_skirmish_initial_state, test_roster_production, test_bot_cycles_unit_list, test_bot_reads_seat_faction, test_bot_plays_china, test_bot_plays_frc, test_bot_builds_tunnel_hub_never_enters, test_bot_collectors_per_supply_center, test_bot_counts_queued_collectors, test_bot_keeps_one_builder_four_gatherers, test_bot_leaves_rebuild_alone, test_opponent_pays_and_retries, test_opponent_attack_policy, test_wave_targets_base_unless_enemy_near, test_wave_target_removed_same_tick, test_wave_fights_unit_met_on_the_way, test_wave_ignores_far_unit_beside_building, test_opponent_defends_base, test_defence_skips_busy_units, test_bot_ignores_contained_units, test_match_lifecycle, test_restart_state, test_bot_state_survives_seat_wrapper, test_headless_client_rejects_unknown_faction, test_chosen_starts_become_bases, test_no_starts_leaves_default_map, test_bot_builds_on_chosen_start, test_bot_rally_follows_chosen_start, test_replay_oracle_uses_match_map, test_desync_report_names_map_seed_starts, test_seeded_diagonal_on_broken_crown]

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
	runner.check(state.sources.size() == 2 and state.sources[0].id == 5 and state.sources[0].origin == [2, 1] and state.sources[0].boxes == 400 and state.sources[1].id == 6 and state.sources[1].origin == [42, 1] and state.sources[1].boxes == 400, "K1 sources left then right")
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

func test_bot_reads_seat_faction(runner) -> bool:
	var sim = Skirmish.create(true, "ai", {1: "usa", 2: "china"})
	Skirmish.issue_opponent(sim)
	sim.step()
	var site: Array = _built(sim.snapshot().buildings, 2).map(func(b: Dictionary) -> String: return b.kind)
	runner.check(site == ["china_command_center", "china_power_plant"], "B4 the opponent reads the build order from its seat's faction, got " + str(site))
	Economy.add_completed(sim, 2, "china_barracks", Vector2i(20, 20))
	for i in 59: sim.step()
	Skirmish.issue_opponent(sim)
	sim.step()
	var queued: Array = _owned(sim.snapshot().buildings, 2).filter(func(b: Dictionary) -> bool: return not b.queue.is_empty())
	runner.check(not queued.is_empty() and queued.all(func(b: Dictionary) -> bool: return b.queue[0].kind == "china_rifle_infantry"), "B4 the opponent trains the faction's unit for the producer, got " + str(queued))
	return true

func test_bot_leaves_rebuild_alone(runner) -> bool:
	var sim = Skirmish.create(true, "ai", {1: "usa", 2: "frc"})
	var barracks: int = -1
	for tick in range(6000):
		Skirmish.issue_opponents(sim, [2])
		sim.step()
		for building: Dictionary in sim.snapshot().buildings:
			if building.owner == 2 and building.kind == "frc_barracks" and building.completed: barracks = building.id
		if barracks != -1: break
	runner.check(barracks != -1, "Fb2 the FRC bot builds its barracks")
	if barracks == -1: return true
	sim.remove_object(barracks)
	var rebuilt: bool = false
	var killed: bool = false
	var lost: bool = false
	var recovered: bool = false
	var first_laborer: int = -1
	var spawned: int = -1
	var interfered: String = ""
	var most: int = 0
	var last_free: int = 0
	var factory_tick: int = -1
	var removed_at: int = sim.tick()
	for tick in range(1800):
		Skirmish.issue_opponents(sim, [2])
		sim.step()
		var state: Dictionary = sim.snapshot()
		var worker: Array = state.entities.filter(func(u: Dictionary) -> bool: return u.has("hole_id"))
		if not worker.is_empty() and not killed and state.tick > spawned + 40:
			first_laborer = worker[0].id
			sim.remove_object(first_laborer)
			killed = true
		if not worker.is_empty() and spawned < 0: spawned = state.tick
		var mine: Array = state.buildings.filter(func(b: Dictionary) -> bool: return b.owner == 2 and b.kind == "frc_barracks")
		if mine.size() > 1: interfered = "second barracks"
		for site: Dictionary in mine.filter(func(b: Dictionary) -> bool: return b.has("hole_id")):
			var builder: Array = state.entities.filter(func(u: Dictionary) -> bool: return u.id == site.builder_id)
			if not builder.is_empty() and not builder[0].has("hole_id"): interfered = "bot builder on the site"
		var free: int = state.entities.filter(func(u: Dictionary) -> bool: return u.owner == 2 and u.kind == "frc_builder" and not u.has("hole_id")).size()
		most = maxi(most, free)
		recovered = recovered or (lost and not worker.is_empty() and worker[0].id != first_laborer and free == _frc_laborers() and last_free < free)
		last_free = free
		if killed and not worker.is_empty() and not lost and worker[0].id != first_laborer:
			lost = true
			sim.remove_object(state.entities.filter(func(u: Dictionary) -> bool: return u.owner == 2 and u.kind == "frc_builder" and not u.has("hole_id")).back().id)
		if factory_tick < 0 and state.buildings.any(func(b: Dictionary) -> bool: return b.owner == 2 and b.kind == "frc_factory"): factory_tick = state.tick
		rebuilt = rebuilt or mine.any(func(b: Dictionary) -> bool: return b.completed and not b.has("hole_id") and b.id != barracks)
	runner.check(interfered.is_empty(), "Fb2 the bot leaves the rebuild alone, saw: " + interfered)
	runner.check(rebuilt, "Fb2 the hole rebuilt the barracks")
	runner.check(most == _frc_laborers(), "Fb2 the bot keeps %d laborers without the rebuild laborer, most %d" % [_frc_laborers(), most])
	runner.check(recovered, "Fb2 a bot laborer lost while the rebuild laborer works is replaced up to %d, final %d" % [_frc_laborers(), last_free])
	runner.check(factory_tick >= 0 and factory_tick < removed_at + 300, "Fb2 the bot places the next build-order kind soon after the hole opens, tick %d" % factory_tick)
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

func _bot_until_attack(sim: RefCounted, army: Array, limit: int, player: int = 2) -> void:
	while sim.tick() < limit and _attack_targets(sim, army).size() < army.size():
		Skirmish.issue_opponent(sim, player)
		sim.step()

func test_opponent_attack_policy(runner) -> bool:
	var sim = Skirmish.create(false)
	Economy.build(runner, sim, "usa_power_plant", Skirmish.origin("usa_power_plant", 1))
	var depot: int = Economy.build(runner, sim, "usa_supply_center", Skirmish.origin("usa_supply_center", 1))
	var barracks: int = Economy.build(runner, sim, "usa_barracks", Skirmish.origin("usa_barracks", 1))
	var reactor: int = depot - 1
	sim.remove_object(3)
	sim.remove_object(4)
	var first: int = sim.spawn(1, Vector2(41.5, 22.5), "usa_builder")
	var second: int = sim.spawn(1, Vector2(45.5, 6.5), "usa_builder")
	_to_tick(sim, 5370)
	var army: Array = _army(sim)
	while sim.tick() < 5399:
		Skirmish.issue_opponent(sim)
		sim.step()
	runner.check(_attack_targets(sim, army).is_empty(), "A3 no attack orders before tick 5400")
	_bot_until_attack(sim, army, Skirmish.ATTACK_TICK + 4000)
	runner.check(_attack_targets(sim, army) == [first, first, first, first], "A3 the wave shares the best-scored target, a builder, got " + str(_attack_targets(sim, army)))
	_to_tick(sim, sim.tick() + Skirmish.DECISION_TICKS - sim.tick() % Skirmish.DECISION_TICKS)
	Skirmish.issue_opponent(sim)
	runner.check(sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "attack").is_empty(), "A3 attackers are not reissued")
	sim.remove_object(1)
	for expected in [first, second, barracks, reactor, depot, 2]:
		_to_tick(sim, sim.tick() + Skirmish.DECISION_TICKS - sim.tick() % Skirmish.DECISION_TICKS)
		Skirmish.issue_opponent(sim)
		sim.step()
		runner.check(_attack_targets(sim, army) == [expected, expected, expected, expected], "A3 next target by score " + str(expected) + ", got " + str(_attack_targets(sim, army)))
		sim.remove_object(expected)
	var lone = _world(10000)
	lone.remove_object(1)
	var before: Dictionary = lone.snapshot()
	Skirmish.issue_opponent(lone)
	runner.check(lone.snapshot() == before, "A3 an eliminated opponent submits nothing")
	return true

func _wave_world(rifle_at: Vector2) -> Array:
	var sim = Simulation.new([], Vector2i(160, 32))
	sim.add_player(1, 10000)
	sim.add_player(2, 10000)
	var building: int = Economy.add_completed(sim, 1, "usa_supply_center", Vector2i(150, 10))
	var rifle: int = sim.spawn(1, rifle_at, "usa_rifle_infantry")
	return [sim, _army(sim), building, rifle]

func test_wave_targets_base_unless_enemy_near(runner) -> bool:
	for case in [[Vector2(43.5, 22.5), 3], [Vector2(70.5, 11.5), 2]]:
		var world: Array = _wave_world(case[0])
		_to_tick(world[0], Skirmish.ATTACK_TICK)
		_bot_until_attack(world[0], world[1], Skirmish.ATTACK_TICK + 4000)
		var expected: int = world[case[1]]
		runner.check(_attack_targets(world[0], world[1]) == [expected, expected, expected, expected], "W1 enemy unit at " + str(case[0]) + ": wave targets " + str(expected) + ", got " + str(_attack_targets(world[0], world[1])))
	return true

func test_wave_target_removed_same_tick(runner) -> bool:
	var world: Array = _wave_world(Vector2(85.5, 11.5))
	var sim = world[0]
	_to_tick(sim, Skirmish.ATTACK_TICK)
	var ordered: Callable = func() -> bool: return sim.snapshot().pending_commands.any(func(command: Dictionary) -> bool: return command.type == "attack")
	while sim.tick() < Skirmish.ATTACK_TICK + 4000:
		Skirmish.issue_opponent(sim)
		if ordered.call(): break
		sim.step()
	runner.check(sim.snapshot().pending_commands.any(func(command: Dictionary) -> bool: return command.type == "attack" and command.target_id == world[2]), "W2 the wave order against the building is queued before it is removed")
	sim.remove_object(world[2])
	sim.step()
	_to_tick(sim, sim.tick() + Skirmish.DECISION_TICKS - sim.tick() % Skirmish.DECISION_TICKS)
	Skirmish.issue_opponent(sim)
	sim.step()
	runner.check(_attack_targets(sim, world[1]) == [world[3], world[3], world[3], world[3]], "W2 wave retargets the remaining unit after its target vanished, got " + str(_attack_targets(sim, world[1])))
	return true

func test_wave_fights_unit_met_on_the_way(runner) -> bool:
	var world: Array = _wave_world(Vector2(85.5, 11.5))
	var sim = world[0]
	_to_tick(sim, Skirmish.ATTACK_TICK)
	_bot_until_attack(sim, world[1], Skirmish.ATTACK_TICK + 4000)
	runner.check(_attack_targets(sim, world[1]) == [world[2], world[2], world[2], world[2]], "W3 the wave marches on the building, got " + str(_attack_targets(sim, world[1])))
	var wave_at: Vector2 = Vector2.ZERO
	for unit in sim.snapshot().entities:
		if world[1].has(unit.id): wave_at += Vector2(unit.position[0], unit.position[1]) / world[1].size()
	var met: int = sim.spawn(1, wave_at + Vector2(0.0, 6.0), "usa_rifle_infantry")
	_to_tick(sim, sim.tick() + Skirmish.DECISION_TICKS - sim.tick() % Skirmish.DECISION_TICKS)
	Skirmish.issue_opponent(sim)
	sim.step()
	runner.check(_attack_targets(sim, world[1]) == [met, met, met, met], "W3 a wave marching to a base fights an enemy unit that comes within reach, got " + str(_attack_targets(sim, world[1])))
	sim.remove_object(met)
	sim.step()
	_to_tick(sim, sim.tick() + Skirmish.DECISION_TICKS - sim.tick() % Skirmish.DECISION_TICKS)
	Skirmish.issue_opponent(sim)
	sim.step()
	runner.check(_attack_targets(sim, world[1]).has(world[2]) and not _attack_targets(sim, world[1]).has(met), "W3 once the unit is dead the wave resumes, got " + str(_attack_targets(sim, world[1])))
	return true

func test_wave_ignores_far_unit_beside_building(runner) -> bool:
	var sim = Simulation.new([], Vector2i(160, 32))
	sim.add_player(1, 10000)
	sim.add_player(2, 10000)
	var building: int = Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(53, 10))
	sim.spawn(1, Vector2(43.5, 25.5), "usa_tank")
	var army: Array = _army(sim)
	_to_tick(sim, Skirmish.ATTACK_TICK)
	_bot_until_attack(sim, army, Skirmish.ATTACK_TICK + 4000)
	runner.check(_attack_targets(sim, army) == [building, building, building, building], "W4 a building in reach beats a unit beyond it, got " + str(_attack_targets(sim, army)))
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
	_bot_until_attack(sim, [idle], Skirmish.ATTACK_TICK + 4000, 1)
	runner.check(_attack_targets(sim, [idle]).size() == 1, "D2 the wave picks up idle units after ATTACK_TICK")
	return true

func test_bot_ignores_contained_units(runner) -> bool:
	var sim = _world(10000)
	var row: Dictionary = Registry.kind("usa_light_vehicle").duplicate(true)
	row.contains = {"slots": 5, "accepts": ["vehicle"], "passengers_fire": true, "passenger_damage_percent": 100}
	Registry.add_test_kind("test_ferry", row)
	var builder: int = sim.spawn(1, Vector2(30.5, 20.5), "usa_builder")
	var ferry: int = sim.spawn(1, Vector2(31.5, 20.5), "test_ferry")
	Economy.add_completed(sim, 1, "usa_power_plant", Vector2i(10, 20))
	Economy.send(sim, {"type": "enter", "entity_ids": [builder], "target_id": ferry})
	for i in range(100): sim.step()
	runner.check(Economy.object(sim, builder).has("container_id"), "D3 setup: the builder boarded")
	var army: Array = _army(sim)
	_to_tick(sim, Skirmish.ATTACK_TICK)
	_bot_until_attack(sim, army, Skirmish.ATTACK_TICK + 4000)
	Registry.clear_test_kinds()
	runner.check(_attack_targets(sim, army) == [ferry, ferry, ferry, ferry], "D3 the wave hits the carrier, never the contained builder, got " + str(_attack_targets(sim, army)))
	var world: Array = _defence_world(runner)
	var base = world[0]
	var y: float = Skirmish.origin("usa_power_plant", 1).y + 0.5
	var held: Array = _loaded_car_for(base, Vector2(world[1] + 5.0, y))
	var tank: int = base.spawn(1, Vector2(30.5, 28.5), "usa_tank")
	runner.check(Economy.object(base, held[0]).has("container_id"), "D3 setup: the intruder passenger boarded")
	_decide_now(base)
	var combat: Dictionary = _mode(base, tank)
	runner.check(combat.mode == "attack" and combat.target_id == held[1], "D3 defence targets the loaded car, not its passenger, got " + str(combat))
	return true

func _loaded_car_for(sim: RefCounted, at: Vector2) -> Array:
	var rifle: int = sim.spawn(2, at, "usa_rifle_infantry")
	var car: int = sim.spawn(2, at + Vector2(0.0, 1.0), "usa_light_vehicle")
	Economy.send(sim, {"type": "enter", "player": 2, "entity_ids": [rifle], "target_id": car})
	for i in range(100): sim.step()
	return [rifle, car]

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

func test_bot_plays_china(runner) -> bool:
	var sim = Skirmish.create(true, "ai", {1: "usa", 2: "china"})
	for tick in range(4000):
		Skirmish.issue_opponent(sim)
		sim.step()
	var state: Dictionary = sim.snapshot()
	var kinds: Array = _owned(state.buildings, 2).map(func(b: Dictionary) -> String: return b.kind).filter(func(k: String) -> bool: return k != "china_command_center")
	runner.check(kinds.size() > 0 and kinds[0] == "china_power_plant", "B5 a China bot builds china_power_plant first, got " + str(kinds))
	var owned: Array = state.entities.filter(func(u: Dictionary) -> bool: return u.owner == 2).map(func(u: Dictionary) -> String: return u.kind)
	runner.check(owned.all(func(k: String) -> bool: return k.begins_with("china_")), "B5 a China bot owns only china_ units, got " + str(owned))
	runner.check(owned.any(func(k: String) -> bool: return k == "china_rifle_infantry" or k == "china_rocket_infantry" or k == "china_tank" or k == "china_light_vehicle"), "B5 a China bot trains combat units, got " + str(owned))
	return true

func _frc_laborers() -> int:
	return Registry.faction("frc").bot_collectors_per_supply_center

func _count_collectors(sim, kind: String) -> int:
	return sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.owner == 2 and u.kind == kind).size()

func _run_collector_bot(faction: String, ticks: int):
	var sim = Skirmish.create(true, "ai", {1: "usa", 2: faction})
	sim._players[2].credits = 1000000
	for tick in range(ticks):
		Skirmish.issue_opponent(sim, 2)
		sim.step()
	return sim

func test_bot_collectors_per_supply_center(runner) -> bool:
	var usa = _run_collector_bot("usa", 3600)
	runner.check(_count_collectors(usa, "usa_collector") == 2, "SK-C1 a USA bot runs two collectors per supply center, got %d" % _count_collectors(usa, "usa_collector"))
	runner.check(Registry.faction("usa").bot_collectors_per_supply_center == 2 and Registry.faction("china").bot_collectors_per_supply_center == 3 and Registry.faction("frc").bot_collectors_per_supply_center == 5, "SK-C3 faction values are USA 2, China 3, FRC 5")
	var china = _run_collector_bot("china", 3600)
	runner.check(_count_collectors(china, "china_collector") == 3, "SK-C2 a China bot runs three, got %d" % _count_collectors(china, "china_collector"))
	var lost: int = usa.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.owner == 2 and u.kind == "usa_collector")[0].id
	usa.remove_object(lost)
	for tick in range(900):
		Skirmish.issue_opponent(usa, 2)
		usa.step()
	runner.check(_count_collectors(usa, "usa_collector") == 2, "SK-C4 a lost collector is replaced, got %d" % _count_collectors(usa, "usa_collector"))
	return true

func _two_depot_collectors(faction: String, kind: String) -> int:
	var sim = Skirmish.create(true, "ai", {1: "usa", 2: faction})
	sim._players[2].credits = 1000000
	var depot: String = faction + "_supply_center"
	var second: bool = false
	for tick in range(5400):
		Skirmish.issue_opponent(sim, 2)
		if not second and sim.snapshot().buildings.any(func(b: Dictionary) -> bool: return b.owner == 2 and b.kind == depot and b.completed):
			var builder: int = sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.owner == 2 and Registry.is_builder(u.kind))[0].id
			var home: Vector2i = Skirmish._slot(sim, depot, 2)
			var sequence: int = sim.snapshot().last_sequences.filter(func(e: Dictionary) -> bool: return e.player == 2)[0].sequence
			for offset: Vector2i in [Vector2i(-6, 0), Vector2i(6, 0), Vector2i(0, -6), Vector2i(0, 6), Vector2i(-6, 6), Vector2i(6, -6), Vector2i(-10, 0), Vector2i(10, 0)]:
				var site: Vector2i = home + offset
				second = sim.issue_command({"type": "build", "builder_id": builder, "building_kind": depot, "origin": [site.x, site.y], "tick": sim.tick(), "player": 2, "sequence": sequence + 1}).ok
				if second: break
		sim.step()
	return _count_collectors(sim, kind) if second else -1

func test_bot_counts_queued_collectors(runner) -> bool:
	runner.check(_two_depot_collectors("usa", "usa_collector") == 4, "SK-C5 two supply centers, a USA bot owns exactly 4, got %d" % _two_depot_collectors("usa", "usa_collector"))
	runner.check(_two_depot_collectors("china", "china_collector") == 6, "SK-C5 two supply centers, a China bot owns exactly 6, got %d" % _two_depot_collectors("china", "china_collector"))
	return true

func test_bot_keeps_one_builder_four_gatherers(runner) -> bool:
	var sim = Skirmish.create(true, "ai", {1: "usa", 2: "frc"})
	var queued: bool = false
	for tick in range(3000):
		Skirmish.issue_opponents(sim, [2])
		sim.step()
		for building: Dictionary in sim.snapshot().buildings:
			if building.owner == 2 and building.kind == "frc_command_center" and not building.queue.is_empty(): queued = true
	var laborers: Array = sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.owner == 2 and u.kind == "frc_builder")
	laborers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	runner.check(laborers.size() == _frc_laborers(), "Fb1 the FRC bot owns exactly the faction count of laborers, got %d" % laborers.size())
	runner.check(not laborers.is_empty() and not laborers[0].collection.enabled, "Fb1 the lowest id stays the builder")
	runner.check(laborers.size() > 1 and laborers.slice(1).all(func(u: Dictionary) -> bool: return u.collection.enabled), "Fb1 the others collect")
	runner.check(not queued, "Fb1 the headquarters queue never held an entry")
	return true

func test_bot_plays_frc(runner) -> bool:
	var sim = Skirmish.create(true, "ai", {1: "usa", 2: "frc"})
	for tick in range(6000):
		Skirmish.issue_opponents(sim, [2])
		sim.step()
	var state: Dictionary = sim.snapshot()
	var kinds: Array = _owned(state.buildings, 2).map(func(b: Dictionary) -> String: return b.kind).filter(func(k: String) -> bool: return k != "frc_command_center")
	runner.check(kinds.size() > 0 and kinds[0] == "frc_supply_center", "Fb3 an FRC bot builds frc_supply_center first, got " + str(kinds))
	var owned: Array = _owned(state.entities, 2).map(func(u: Dictionary) -> String: return u.kind)
	runner.check(owned.all(func(k: String) -> bool: return k.begins_with("frc_")), "Fb3 an FRC bot owns only frc_ units, got " + str(owned))
	runner.check(owned.any(func(k: String) -> bool: return k != "frc_builder"), "Fb3 an FRC bot trains a combat unit within 6000 ticks, got " + str(owned))
	return true

func test_bot_builds_tunnel_hub_never_enters(runner) -> bool:
	var sim = Skirmish.create(true, "ai", {1: "usa", 2: "frc"})
	var inside: bool = false
	var tunnel: bool = false
	var order: Array = []
	for tick in range(6000):
		Skirmish.issue_opponents(sim, [2])
		sim.step()
		inside = inside or sim._entities.values().any(func(u: Dictionary) -> bool: return u.owner == 2 and u.has("container_id"))
		tunnel = tunnel or sim._players[2].has("tunnel")
		for building: Dictionary in sim._buildings.values():
			if building.owner == 2 and building.completed and building.kind != "frc_command_center" and not order.has(building.kind): order.append(building.kind)
	runner.check(order.slice(0, 4) == ["frc_supply_center", "frc_barracks", "frc_factory", "frc_defence"], "Fb4 an FRC bot completes the cache, barracks, factory and tunnel hub in order, got " + str(order))
	runner.check(not inside and not tunnel, "Fb4 the bot orders nothing into the hub: no container_id, no tunnel key")
	return true

func test_bot_state_survives_seat_wrapper(runner) -> bool:
	var sim = Skirmish.create()
	var lockstep = Lockstep.new(2, [1, 2] as Array[int], 2)
	var first: Dictionary = Skirmish._bot(SeatSim.new(sim, lockstep), 2)
	first.since = 77
	runner.check(Skirmish._bot(SeatSim.new(sim, lockstep), 2).since == 77, "SK20 a fresh seat wrapper sees the bot state of the earlier one")
	runner.check(Skirmish._bot(sim, 2).since == 77, "SK20 the real simulation holds the same bot state")
	return true

func test_headless_client_rejects_unknown_faction(runner) -> bool:
	var client = Client.new()
	client._args = {}
	runner.check(client._faction_error() == "", "SK21 no --faction falls back to the default")
	for faction: String in Registry.Factions.FACTIONS:
		client._args = {"faction": faction}
		runner.check(client._faction_error() == "", "SK21 --faction %s is accepted" % faction)
	client._args = {"faction": "gla"}
	runner.check(client._faction_error().contains("'gla'") and client._faction_error().contains("usa"), "SK21 an unknown --faction names the value and the valid ones: %s" % client._faction_error())
	client.free()
	return true

func _chosen_sim():
	return Skirmish.create(true, "ai", {1: "usa", 2: "china"}, ASHFALL, CHOSEN)

func _base_ok(sim, ashfall: Dictionary, player: int, seat: int, faction: String) -> bool:
	var cell := MapData.start_cell(ashfall, seat)
	var building: String = Registry.faction(faction).start_building
	var state: Dictionary = sim.snapshot()
	var unit_ok: bool = state.entities.any(func(e: Dictionary) -> bool: return e.owner == player and e.position == [cell.x + 0.5, cell.y + 0.5])
	var slot := MapData.slot(ashfall, seat, building)
	var building_ok: bool = state.buildings.any(func(b: Dictionary) -> bool: return b.owner == player and b.kind == building and b.origin == [slot.x, slot.y])
	return unit_ok and building_ok

func test_chosen_starts_become_bases(runner) -> bool:
	var ashfall := MapData.load(ASHFALL)
	var sim = _chosen_sim()
	runner.check(_base_ok(sim, ashfall, 1, 5, "usa"), "SK-S1 player 1's start building is on Ashfall seat 5")
	runner.check(_base_ok(sim, ashfall, 2, 1, "china"), "SK-S1 player 2's start building is on Ashfall seat 1")
	runner.check(MapData.start_cell(sim.map_data(), 1) == MapData.start_cell(ashfall, 5), "SK-S1 the camera start cell is seat 5's")
	return true

func test_no_starts_leaves_default_map(runner) -> bool:
	var a = Skirmish.create(true, "ai", Registry.Factions.DEFAULT_SKIRMISH, Skirmish.MAP_PATH)
	var b = Skirmish.create(true, "ai", Registry.Factions.DEFAULT_SKIRMISH, Skirmish.MAP_PATH, [] as Array[int])
	runner.check(StateHash.digest(a.snapshot()) == StateHash.digest(b.snapshot()), "SK-S2 empty starts keep the state hash")
	runner.check(is_same(a.map_data(), b.map_data()), "SK-S2 empty starts reuse the cached map")
	return true

func test_bot_builds_on_chosen_start(runner) -> bool:
	var ashfall := MapData.load(ASHFALL)
	var sim = _chosen_sim()
	var players: Array[int] = [1, 2]
	while sim.tick() < 900:
		Skirmish.issue_opponents(sim, players)
		sim.step()
	var first_usa: String = Skirmish.build_order("usa")[0]
	var first_china: String = Skirmish.build_order("china")[0]
	var state: Dictionary = sim.snapshot()
	var usa_slot := MapData.slot(ashfall, 5, first_usa)
	var china_slot := MapData.slot(ashfall, 1, first_china)
	runner.check(state.buildings.any(func(b: Dictionary) -> bool: return b.owner == 1 and b.kind == first_usa and b.origin == [usa_slot.x, usa_slot.y]), "SK-S3 player 1's bot builds on seat 5's slot")
	runner.check(state.buildings.any(func(b: Dictionary) -> bool: return b.owner == 2 and b.kind == first_china and b.origin == [china_slot.x, china_slot.y]), "SK-S3 player 2's bot builds on seat 1's slot")
	return true

func test_bot_rally_follows_chosen_start(runner) -> bool:
	var ashfall := MapData.load(ASHFALL)
	var sim = _chosen_sim()
	sim.spawn(1, Vector2(MapData.start_cell(ashfall, 3)) + Vector2(0.5, 0.5), "usa_rifle_infantry")
	var players: Array[int] = [1]
	Skirmish.issue_opponents(sim, players, 0)
	var seat5 := Vector2(MapData.start_cell(ashfall, 5)) + Vector2(0.5, 0.5)
	var moves: Array = sim.snapshot().pending_commands.filter(func(c: Dictionary) -> bool: return c.type == "move" and c.player == 1)
	runner.check(moves.size() == 1 and moves[0].target == [seat5.x, seat5.y], "SK-S3 player 1's wave rally is seat 5's start cell, got %s" % str(moves))
	return true

class OracleClient extends Client:
	func _exit() -> void:
		pass

func test_replay_oracle_uses_match_map(runner) -> bool:
	var log_path := "user://sk22_replay-%d.log" % OS.get_process_id()
	FileAccess.open(log_path, FileAccess.WRITE).close()
	var chosen := MatchSettings.starts("ashfall", 7)
	var ashfall := MapData.load(ASHFALL)
	var client = OracleClient.new()
	client._args = {"map": "ashfall", "seed": "7", "replay-log": log_path, "oracle-ticks": "1"}
	client._replay_oracle()
	var sim = client._sim
	runner.check(MapData.start_cell(sim.map_data(), 1) == MapData.start_cell(ashfall, chosen[0]), "SK22 the replay oracle puts seat 1 on the live match's start, want seat %d" % chosen[0])
	runner.check(MapData.start_cell(sim.map_data(), 2) == MapData.start_cell(ashfall, chosen[1]), "SK22 the replay oracle puts seat 2 on the live match's start, want seat %d" % chosen[1])
	client.free()
	client = OracleClient.new()
	client._args = {"replay-log": log_path, "oracle-ticks": "1"}
	client._replay_oracle()
	runner.check(is_same(client._sim.map_data(), Skirmish.create(true, "human", {}).map_data()), "SK22 no --map keeps the test map")
	client.free()
	DirAccess.remove_absolute(log_path)
	return true

func test_desync_report_names_map_seed_starts(runner) -> bool:
	var driver = OnlineDriver.new(null, Lockstep.new(1, [1, 2] as Array[int]), "usa")
	driver.create(MatchSettings.map_path("ashfall"), MatchSettings.starts("ashfall", 7), {}, 7)
	var report: Dictionary = driver._report()
	runner.check(report.get("map") == "ashfall" and report.get("seed") == 7 and report.get("starts") == MatchSettings.starts("ashfall", 7), "SK23 the online desync report names map, seed and starts, got %s" % [[report.get("map"), report.get("seed"), report.get("starts")]])
	return true

func test_seeded_diagonal_on_broken_crown(runner) -> bool:
	var path := "res://data/maps/broken_crown.json"
	var crown := MapData.load(path)
	var teams: Array[int] = [1, 2]
	var chosen: Array[int] = [0, 0]
	var seats := StartSpots.assign(crown, 7, teams, chosen)
	var sim = Skirmish.create(true, "ai", Registry.Factions.DEFAULT_SKIRMISH, path, seats)
	var a := MapData.start_cell(sim.map_data(), 1)
	var b := MapData.start_cell(sim.map_data(), 2)
	runner.check(absf(Vector2(a).distance_to(Vector2(b)) - 97.8) <= 0.1, "SK-S4 a seeded 1v1 on Broken Crown is diagonal: %s" % Vector2(a).distance_to(Vector2(b)))
	return true

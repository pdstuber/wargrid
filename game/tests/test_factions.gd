@warning_ignore_start("untyped_declaration")
extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const SeatSim = preload("res://scripts/net/seat_sim.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const LockstepTests = preload("res://tests/test_lockstep.gd")

func cases() -> Array[Callable]:
	return [test_foundation_keeps_seat_alive, test_cancel_last_foundation_defeats, test_choose_faction_online_same_hash, test_match_waits_for_all_factions, test_setup_rejects_commands_until_all_chose, test_choose_faction_same_tick_cases, test_capability_rules, test_start_has_command_center_and_builder, test_survival_counts_buildings_only, test_bot_trains_builder_without_one, test_bot_without_command_center, test_china_start, test_china_power_and_prerequisites, test_choose_faction_online_china_same_hash, test_choose_faction_online_frc_same_hash, test_frc_start, test_frc_needs_no_power]

func test_capability_rules(runner) -> bool:
	Registry.add_test_kind("x_maker", {"class": "vehicle", "cost": 1, "ticks": 1, "speed": 1.0, "locomotor": "wheels", "max_hp": 1000, "armor": "builder_vehicle", "weapon": "", "builds": ["usa_barracks"]})
	Registry.add_test_kind("x_hauler", {"class": "air", "cost": 1, "ticks": 1, "speed": 1.0, "locomotor": "air", "max_hp": 1000, "armor": "helicopter", "weapon": "", "collects": {"boxes": 2, "load_ticks": 3, "unload_ticks": 4, "box_value": 5}})
	var sim = EconomyFixture.make_world()
	var maker: int = sim.spawn(1, Vector2(10.5, 10.5), "x_maker")
	var placed: Dictionary = EconomyFixture.send(sim, {"type": "build", "builder_id": maker, "building_kind": "usa_barracks", "origin": [16, 16]})
	runner.check(placed.ok, "C1 a kind with builds places a foundation: " + placed.error)
	var hauler: int = sim.spawn(1, Vector2(12.5, 12.5), "x_hauler")
	var records: Array = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.id == hauler)
	runner.check(records.size() == 1 and records[0].collection != null, "C1 a kind with collects gets a collection record")
	Registry.clear_test_kinds()
	return true

func _foundation_world(runner) -> Dictionary:
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 10000)
	sim.add_player(2, 10000)
	var builder: int = sim.spawn(1, Vector2(4.5, 4.5), "usa_builder")
	sim.spawn(2, Vector2(26.5, 26.5), "usa_builder")
	EconomyFixture.add_completed(sim, 2, "usa_power_plant", Vector2i(20, 20))
	var placed: int = sim.snapshot().next_entity_id
	var result: Dictionary = EconomyFixture.send(sim, {"type": "build", "builder_id": builder, "building_kind": "usa_barracks", "origin": [8, 8]})
	runner.check(result.ok, "F1 foundation placed: " + result.error)
	EconomyFixture.steps(sim, 1)
	var started: Dictionary = sim.start_match([1, 2])
	runner.check(started.ok, "F1 match starts with a foundation as seat 1's only building: " + started.error)
	return {"sim": sim, "builder": builder, "foundation": placed}

func test_foundation_keeps_seat_alive(runner) -> bool:
	var world: Dictionary = _foundation_world(runner)
	var sim = world.sim
	sim.remove_object(world.builder)
	EconomyFixture.steps(sim, 5)
	runner.check(sim.snapshot().match.status == "ongoing", "F1 a foundation keeps its seat alive without any unit")
	return true

func test_cancel_last_foundation_defeats(runner) -> bool:
	var world: Dictionary = _foundation_world(runner)
	var sim = world.sim
	EconomyFixture.send(sim, {"type": "cancel_build", "building_id": world.foundation})
	EconomyFixture.steps(sim, 2)
	var state: Dictionary = sim.snapshot()
	runner.check(state.match.status == "won" and state.match.winner == 2, "F2 cancelling the last foundation defeats the seat even with a living builder")
	return true

func _online_pair(runner) -> Object:
	var net = LockstepTests.new()._pair(runner)
	for c in net.clients:
		var create: Callable = Skirmish.create
		c.sim = create.callv([true, "human", {}])
		c.seat_sim = SeatSim.new(c.sim, c.ls)
		c.target = 300
	return net

func test_choose_faction_online_same_hash(runner) -> bool:
	var net = _online_pair(runner)
	for c in net.clients: c.ls.submit({"type": "choose_faction", "faction": "usa"})
	net.connect_all()
	net.run()
	var a = net.clients[0]
	var b = net.clients[1]
	runner.check(a.sim.tick() == 300 and b.sim.tick() == 300, "F3 both reach tick 300")
	runner.check(a.ls.hash_rows() == b.ls.hash_rows() and a.ls.hash_rows().size() > 10, "F3 digests equal every 30 ticks")
	var state: Dictionary = a.sim.snapshot()
	var kinds: Array = []
	for building in state.buildings: kinds.append([building.owner, building.kind, building.completed])
	runner.check(kinds.has([1, "usa_command_center", true]) and kinds.has([2, "usa_command_center", true]), "F3 each seat has a completed command center")
	var builders: int = 0
	for unit in state.entities:
		if unit.kind == "usa_builder": builders += 1
	runner.check(builders == 2, "F3 each seat has one builder")
	return true

func test_choose_faction_online_china_same_hash(runner) -> bool:
	var net = _online_pair(runner)
	for c in net.clients: c.target = 3000
	for i in 2:
		var seat: int = i + 1
		net.clients[i].behavior = func(c) -> void:
			if c.sim.tick() >= 4: Skirmish.issue_opponent(c.seat_sim, seat)
	net.clients[0].ls.submit({"type": "choose_faction", "faction": "china"})
	net.clients[1].ls.submit({"type": "choose_faction", "faction": "usa"})
	net.connect_all()
	net.run()
	var a = net.clients[0]
	var b = net.clients[1]
	runner.check(a.sim.tick() == 3000 and b.sim.tick() == 3000, "F4 both reach tick 3000")
	runner.check(a.ls.hash_rows() == b.ls.hash_rows() and a.ls.hash_rows().size() >= 100, "F4 digests equal every 30 ticks")
	var kinds: Array = a.sim.snapshot().buildings.map(func(b2: Dictionary) -> String: return b2.kind)
	runner.check(kinds.has("china_command_center") and kinds.has("usa_command_center"), "F4 each seat has its own faction home")
	return true

func test_choose_faction_online_frc_same_hash(runner) -> bool:
	var net = _online_pair(runner)
	for c in net.clients: c.target = 3000
	for i in 2:
		var seat: int = i + 1
		net.clients[i].behavior = func(c) -> void:
			if c.sim.tick() >= 4: Skirmish.issue_opponent(c.seat_sim, seat)
	net.clients[0].ls.submit({"type": "choose_faction", "faction": "frc"})
	net.clients[1].ls.submit({"type": "choose_faction", "faction": "usa"})
	net.connect_all()
	net.run()
	var a = net.clients[0]
	var b = net.clients[1]
	runner.check(a.sim.tick() == 3000 and b.sim.tick() == 3000, "F6 both reach tick 3000")
	runner.check(a.ls.hash_rows() == b.ls.hash_rows() and a.ls.hash_rows().size() >= 100, "F6 digests equal every 30 ticks")
	var kinds: Array = a.sim.snapshot().buildings.map(func(b2: Dictionary) -> String: return b2.kind)
	runner.check(kinds.has("frc_command_center") and kinds.has("usa_command_center"), "F6 each seat has its own faction home")
	return true

func test_match_waits_for_all_factions(runner) -> bool:
	var net = _online_pair(runner)
	net.clients[0].ls.submit({"type": "choose_faction", "faction": "usa"})
	for i in 2: net.clients[1].ls.submit({"type": "stop", "entity_ids": [1]})
	var seen: Dictionary = {}
	net.clients[0].hook = func(c, tick: int) -> void: seen[tick] = c.sim.snapshot().match.status
	net.clients[1].hook = func(c, tick: int) -> void:
		if tick == 0: c.ls.submit({"type": "choose_faction", "faction": "usa"})
	for c in net.clients: c.target = 20
	net.connect_all()
	net.run()
	runner.check(seen.get(4) == "setup" and seen.get(5) == "setup", "F4 status stays setup through tick 5")
	runner.check(seen.get(6) == "ongoing", "F4 status is ongoing from tick 6")
	runner.check(net.clients[1].ls.rejections().any(func(r: Dictionary) -> bool: return r.error == "Choose a faction first"), "F4 seat 2's stops before its choice are rejected")
	return true

func test_setup_rejects_commands_until_all_chose(runner) -> bool:
	var sim = _setup_sim()
	var map: Dictionary = sim.map_data()
	EconomyFixture.steps(sim, 4)
	EconomyFixture.send(sim, {"type": "choose_faction", "faction": "usa"})
	EconomyFixture.steps(sim, 1)
	var unit: int = sim.snapshot().entities[0].id
	var early: Dictionary = EconomyFixture.send(sim, {"type": "move", "tick": 5, "entity_ids": [unit], "target": [10.5, 10.5]})
	runner.check(not early.ok and early.error == "Match has not started", "S2 seat 1's move waits for seat 2's choice: " + early.error)
	EconomyFixture.steps(sim, 4)
	EconomyFixture.send(sim, {"type": "choose_faction", "faction": "usa", "player": 2})
	EconomyFixture.steps(sim, 1)
	var state: Dictionary = sim.snapshot()
	var origin: Vector2i = MapData.slot(map, 2, "usa_command_center")
	var cell: Vector2 = Vector2(MapData.start_cell(map, 2)) + Vector2(0.5, 0.5)
	runner.check(state.buildings.any(func(b: Dictionary) -> bool: return b.owner == 2 and b.kind == "usa_command_center" and b.origin == [origin.x, origin.y]), "S2 seat 2 has its command center at its slot")
	runner.check(state.entities.any(func(e: Dictionary) -> bool: return e.owner == 2 and e.kind == "usa_builder" and Vector2(e.position[0], e.position[1]) == cell), "S2 seat 2's start unit stands on its start cell")
	var late: Dictionary = EconomyFixture.send(sim, {"type": "move", "entity_ids": [unit], "target": [10.5, 10.5]})
	runner.check(late.ok, "S2 seat 1's move is accepted once every seat chose: " + late.error)
	return true

const _SAME_TICK: Dictionary = {
	"move": {"entity_ids": [1], "target": [10.5, 10.5]}, "stop": {"entity_ids": [1]},
	"build": {"builder_id": 1, "building_kind": "usa_barracks", "origin": [8, 8]},
	"resume_build": {"builder_id": 1, "building_id": 2}, "cancel_build": {"building_id": 2},
	"produce": {"building_id": 2, "unit_kind": "usa_builder"}, "cancel_production": {"building_id": 2, "production_id": 1},
	"set_rally": {"building_id": 2, "target": [10.5, 10.5]}, "gather": {"entity_ids": [1], "source_id": 5},
	"attack": {"entity_ids": [1], "target_id": 4}, "attack_move": {"entity_ids": [1], "target": [10.5, 10.5]},
}

func _setup_sim() -> RefCounted:
	var create: Callable = Skirmish.create
	return create.callv([true, "human", {}])

func test_choose_faction_same_tick_cases(runner) -> bool:
	for type: String in _SAME_TICK:
		var sim = _setup_sim()
		var chosen: Dictionary = EconomyFixture.send(sim, {"type": "choose_faction", "faction": "usa"})
		var early: Dictionary = EconomyFixture.send(sim, _SAME_TICK[type].merged({"type": type}))
		runner.check(chosen.ok and not early.ok and early.error == "Choose a faction first", "T1 %s in the tick of its choose_faction is rejected before setup: %s" % [type, early.error])
		EconomyFixture.send(sim, {"type": "choose_faction", "faction": "usa", "player": 2})
		EconomyFixture.steps(sim, 1)
		var later: Dictionary = EconomyFixture.send(sim, _SAME_TICK[type].merged({"type": type}))
		runner.check(later.error != "Choose a faction first", "T1 %s the next tick follows its normal rules: %s" % [type, later.error])
	var sim = _setup_sim()
	EconomyFixture.send(sim, {"type": "choose_faction", "faction": "usa"})
	var twice: Dictionary = EconomyFixture.send(sim, {"type": "choose_faction", "faction": "usa"})
	EconomyFixture.steps(sim, 1)
	var outcomes: Array = sim.snapshot().command_results
	runner.check(twice.ok and outcomes.size() == 2 and outcomes[0].ok and outcomes[1].error == "Faction already chosen", "T2 a second choose_faction in the same tick is rejected")
	var unknown: Dictionary = EconomyFixture.send(_setup_sim(), {"type": "choose_faction", "faction": "narnia"})
	runner.check(not unknown.ok and unknown.error == "Unknown faction", "T2 an unknown faction is rejected")
	EconomyFixture.send(sim, {"type": "choose_faction", "faction": "usa", "player": 2})
	EconomyFixture.steps(sim, 1)
	var started: Dictionary = EconomyFixture.send(sim, {"type": "choose_faction", "faction": "usa"})
	runner.check(sim.snapshot().match.status == "ongoing" and not started.ok and started.error == "Faction already chosen", "T2 choose_faction after the match started is rejected")
	return true

func test_start_has_command_center_and_builder(runner) -> bool:
	var state: Dictionary = Skirmish.create().snapshot()
	for seat in [1, 2]:
		var homes: Array = state.buildings.filter(func(b: Dictionary) -> bool: return b.owner == seat)
		var origin: Vector2i = Skirmish.origin("usa_command_center", seat)
		runner.check(homes.size() == 1 and homes[0].kind == "usa_command_center" and homes[0].completed and homes[0].origin == [origin.x, origin.y], "C2 seat %d starts with a completed command center on its slot" % seat)
		runner.check(state.entities.filter(func(u: Dictionary) -> bool: return u.owner == seat and u.kind == "usa_builder").size() == 1, "C2 seat %d starts with one builder" % seat)
	runner.check(state.players.all(func(p: Dictionary) -> bool: return p.faction == "usa"), "C2 every seat records its faction")
	return true

func _survival_world(extra_kind: String) -> RefCounted:
	var sim = Simulation.new([], Vector2i(32, 32))
	for seat in [1, 2]:
		sim.add_player(seat, 0)
		sim.spawn(seat, Vector2(4.5 + seat * 10, 4.5), "usa_builder")
		EconomyFixture.add_completed(sim, seat, "usa_barracks", Vector2i(seat * 10, 10))
	sim.start_match([1, 2] as Array[int])
	sim.remove_object(4)
	if not extra_kind.is_empty(): EconomyFixture.add_completed(sim, 2, extra_kind, Vector2i(20, 20))
	EconomyFixture.steps(sim, 2)
	return sim

func test_survival_counts_buildings_only(runner) -> bool:
	Registry.add_test_kind("x_turret", {"cost": 1, "ticks": 1, "power": 0, "footprint": Vector2i(1, 1), "prerequisite": "", "max_hp": 1000, "armor": "structure", "weapon": "", "produces": [], "receives_supply": false, "counts_for_victory": false, "slot": "defence", "spawns_on_complete": []})
	var builder_only = _survival_world("")
	runner.check(builder_only.snapshot().match.status == "won" and builder_only.snapshot().entities.any(func(u: Dictionary) -> bool: return u.owner == 2 and u.kind == "usa_builder"), "S2 a living builder without buildings is defeated")
	var turret_only = _survival_world("x_turret")
	runner.check(turret_only.snapshot().match.status == "won", "S2 a building without counts_for_victory does not keep the seat alive")
	var center_only = _survival_world("usa_command_center")
	center_only.remove_object(3)
	EconomyFixture.steps(center_only, 3)
	runner.check(center_only.snapshot().match.status == "ongoing" and not center_only.snapshot().entities.any(func(u: Dictionary) -> bool: return u.owner == 2), "S2 a command center alone keeps the seat alive")
	Registry.clear_test_kinds()
	return true

func _bot_orders(sim, kind: String) -> int:
	return sim.snapshot().pending_commands.filter(func(c: Dictionary) -> bool: return c.player == 2 and c.type == "produce" and c.unit_kind == kind).size()

func test_bot_trains_builder_without_one(runner) -> bool:
	var sim = Skirmish.create(false)
	sim.remove_object(3)
	Skirmish.issue_opponent(sim)
	runner.check(_bot_orders(sim, "usa_builder") == 1, "B1 the bot trains a builder from its command center when it has none")
	EconomyFixture.steps(sim, 400)
	runner.check(sim.snapshot().entities.any(func(u: Dictionary) -> bool: return u.owner == 2 and u.kind == "usa_builder"), "B1 the trained builder exists")
	var other = Skirmish.create(false)
	Skirmish.issue_opponent(other)
	runner.check(_bot_orders(other, "usa_builder") == 0, "B1 a bot with a builder trains none")
	return true

func test_bot_without_command_center(runner) -> bool:
	var sim = Skirmish.create(false)
	sim.remove_object(3)
	sim.remove_object(4)
	EconomyFixture.add_completed(sim, 2, "usa_barracks", Vector2i(34, 12))
	Skirmish.issue_opponent(sim)
	EconomyFixture.steps(sim, 2)
	runner.check(_bot_orders(sim, "usa_builder") == 0 and sim.snapshot().buildings.any(func(b: Dictionary) -> bool: return b.owner == 2 and not b.queue.is_empty() and b.queue[0].kind == "usa_rifle_infantry"), "B2 without a command center or builder the bot keeps producing elsewhere")
	return true

func test_china_start(runner) -> bool:
	var state: Dictionary = Skirmish.create(true, "ai", {1: "china", 2: "usa"}).snapshot()
	var homes: Array = state.buildings.filter(func(b: Dictionary) -> bool: return b.owner == 1)
	runner.check(homes.size() == 1 and homes[0].kind == "china_command_center" and homes[0].completed, "Ch1 seat 1 starts with a completed china_command_center")
	var builders: Array = state.entities.filter(func(u: Dictionary) -> bool: return u.owner == 1)
	runner.check(builders.size() == 1 and builders[0].kind == "china_builder", "Ch1 seat 1 starts with one china_builder")
	return true

func test_china_power_and_prerequisites(runner) -> bool:
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 20000)
	sim.spawn(1, Vector2(4.5, 4.5), "china_builder")
	runner.check(not sim.preview_build(1, 1, "china_supply_center", Vector2i(10, 4)).ok, "Ch2 supply center needs a completed power plant")
	var plant: int = EconomyFixture.build(runner, sim, "china_power_plant", Vector2i(5, 5))
	runner.check(plant != -1 and sim.snapshot().players[0].power_supply == 10, "Ch2 power plant adds 10 supply")
	runner.check(not sim.preview_build(1, 1, "china_factory", Vector2i(16, 4)).ok, "Ch2 factory needs a supply center")
	var center: int = EconomyFixture.build(runner, sim, "china_supply_center", Vector2i(10, 4))
	runner.check(center != -1 and sim.preview_build(1, 1, "china_factory", Vector2i(16, 4)).ok, "Ch2 supply center unlocks the factory")
	return true

func test_frc_start(runner) -> bool:
	var state: Dictionary = Skirmish.create(true, "ai", {1: "frc", 2: "usa"}).snapshot()
	var homes: Array = state.buildings.filter(func(b: Dictionary) -> bool: return b.owner == 1)
	var slot: Vector2i = MapData.slot(Skirmish._default_map(), 1, "frc_command_center")
	runner.check(homes.size() == 1 and homes[0].kind == "frc_command_center" and homes[0].completed, "Fr1 seat 1 starts with a completed frc_command_center")
	runner.check(homes.size() == 1 and homes[0].origin == [slot.x, slot.y], "Fr1 the headquarters sits on the command_center slot")
	var laborers: Array = state.entities.filter(func(u: Dictionary) -> bool: return u.owner == 1)
	var start: Vector2i = MapData.start_cell(Skirmish._default_map(), 1)
	runner.check(laborers.size() == 1 and laborers[0].kind == "frc_builder" and laborers[0].position == [start.x + 0.5, start.y + 0.5], "Fr1 seat 1 starts with one frc_builder at the start cell")
	runner.check(laborers.size() == 1 and laborers[0].collection != null and not laborers[0].collection.enabled, "Fr1 the start laborer does not collect")
	return true

func test_frc_needs_no_power(runner) -> bool:
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 20000)
	var laborer: int = sim.spawn(1, Vector2(4.5, 4.5), "frc_builder")
	runner.check(laborer == 1 and sim.snapshot().players[0].work_rate == 1000, "Fr2 a seat with no power buildings works at full rate")
	runner.check(not sim.preview_build(1, laborer, "frc_factory", Vector2i(16, 4)).ok, "Fr2 the factory is rejected without a completed supply center")
	var barracks: int = EconomyFixture.build(runner, sim, "frc_barracks", Vector2i(10, 4))
	runner.check(barracks != -1 and sim.snapshot().players[0].power_supply == 0 and sim.snapshot().players[0].power_demand == 0, "Fr2 FRC buildings add no power supply or demand")
	var center: int = EconomyFixture.build(runner, sim, "frc_supply_center", Vector2i(16, 4))
	runner.check(center != -1 and sim.preview_build(1, laborer, "frc_factory", Vector2i(20, 10)).ok, "Fr2 a completed supply center unlocks the factory")
	return true

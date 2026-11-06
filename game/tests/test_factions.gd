@warning_ignore_start("untyped_declaration")
extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const SeatSim = preload("res://scripts/net/seat_sim.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")
const LockstepTests = preload("res://tests/test_lockstep.gd")

func cases() -> Array[Callable]:
	return [test_foundation_keeps_seat_alive, test_cancel_last_foundation_defeats, test_choose_faction_online_same_hash, test_match_waits_for_all_factions]

func _add_completed(sim, owner: int, kind: String, origin: Vector2i) -> int:
	var id: int = sim._next_entity_id
	sim._next_entity_id += 1
	var hp: int = CombatDefinitions.profile(kind).max_hp
	sim._buildings[id] = {"id":id,"owner":owner,"kind":kind,"hp":hp,"max_hp":hp,"origin":[origin.x,origin.y],"completed":true,"work":0,"paid_cost":0,"builder_id":null,"approach":null,"queue":[],"active_collector_id":null}
	sim._replace_union(sim._union_cells())
	return id

func _foundation_world(runner) -> Dictionary:
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 10000)
	sim.add_player(2, 10000)
	var builder: int = sim.spawn(1, Vector2(4.5, 4.5), "usa_builder")
	sim.spawn(2, Vector2(26.5, 26.5), "usa_builder")
	_add_completed(sim, 2, "usa_power_plant", Vector2i(20, 20))
	var placed: int = sim.snapshot().next_entity_id
	var result: Dictionary = EconomyFixture.send(sim, {"type": "build", "builder_id": builder, "building_kind": "usa_barracks", "origin": [8, 8]})
	runner.check(result.ok, "F1 foundation placed: " + result.error)
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

func test_match_waits_for_all_factions(runner) -> bool:
	var net = _online_pair(runner)
	net.clients[0].ls.submit({"type": "choose_faction", "faction": "usa"})
	for i in 2: net.clients[1].ls.submit({"type": "stop", "entity_ids": [1]})
	net.clients[1].ls.submit({"type": "choose_faction", "faction": "usa"})
	var seen: Dictionary = {}
	net.clients[0].hook = func(c, tick: int) -> void: seen[tick] = c.sim.snapshot().match.status
	for c in net.clients: c.target = 20
	net.connect_all()
	net.run()
	runner.check(seen.get(4) == "setup" and seen.get(5) == "setup", "F4 status stays setup through tick 5")
	runner.check(seen.get(6) == "ongoing", "F4 status is ongoing from tick 6")
	return true

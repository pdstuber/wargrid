extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")

func cases() -> Array[Callable]:
	return [test_definitions, test_players_and_kinds, test_economy_snapshot_isolation, test_variant_rejection, test_future_results_and_copy, test_stop_and_intent_order, test_air_spawn, test_air_and_mixed_move, test_air_obstacle_isolation, test_power_rates,test_remove_objects,test_economy_loop]

func test_definitions(runner) -> bool:
	for row in [["reactor",800,300,5,Vector2i(2,2)], ["depot",2000,300,-1,Vector2i(3,3)], ["factory",2000,450,-1,Vector2i(3,3)]]:
		var definition: Dictionary = Definitions.building(row[0])
		runner.check(definition.get("cost") == row[1] and definition.get("ticks") == row[2] and definition.get("power") == row[3] and definition.get("footprint") == row[4], "E1 building " + row[0])
		definition.cost = 1
		runner.check(Definitions.building(row[0]).get("cost") == row[1], "E1 building copied")
	for row in [["collector",1200,300,6.0,true], ["vehicle",700,300,3.0,false], ["builder",1000,150,3.0,false]]:
		var definition: Dictionary = Definitions.unit(row[0])
		runner.check(definition.get("cost") == row[1] and definition.get("ticks") == row[2] and definition.get("speed") == row[3] and definition.get("air") == row[4], "E1 unit " + row[0])
		definition.cost = 1
		runner.check(Definitions.unit(row[0]).get("cost") == row[1], "E1 unit copied")
	runner.check(Definitions.unit("unknown").is_empty() and Definitions.building("unknown").is_empty(), "E1 unknown")
	return true

func test_players_and_kinds(runner) -> bool:
	var sim = Simulation.new()
	runner.check(sim.add_player(1,10000).ok, "E2 add player")
	var before: Dictionary = sim.snapshot()
	for row in [[1,10000], [0,0], [2,-1]]:
		runner.check(not sim.add_player(row[0],row[1]).ok and sim.snapshot() == before, "E2 rejected unchanged")
	runner.check(sim.spawn(1,Vector2(1.5,1.5)) == 1, "E2 default vehicle")
	runner.check(sim.spawn(1,Vector2(2.5,1.5),"builder") == 2, "E2 builder")
	before = sim.snapshot()
	runner.check(sim.spawn(1,Vector2(3.5,1.5),"unknown") == -1 and sim.snapshot() == before, "E2 invalid kind unchanged")
	runner.check(sim.snapshot().entities[0].get("kind") == "vehicle" and sim.snapshot().entities[1].get("kind") == "builder", "E2 kinds")
	return true

func test_economy_snapshot_isolation(runner) -> bool:
	var terrain: Array[Vector2i] = [Vector2i(8,8)]
	var sim = Simulation.new(terrain)
	sim.add_player(1,10000)
	sim.spawn(1,Vector2(1.5,1.5),"collector")
	var before: Dictionary = sim.snapshot()
	runner.check(before.get("buildings") == [] and before.get("sources") == [] and before.get("command_results") == [] and before.get("next_production_id") == 1, "E3 initial roots")
	if not before.has("players") or not before.entities[0].has("collection"):
		runner.check(false,"E3 economy fields exist")
		return true
	var changed: Dictionary = sim.snapshot()
	changed.players[0].credits = 0
	changed.entities[0].kind = "vehicle"
	changed.entities[0].collection.cargo = 8
	changed.terrain_cells[0][0] = 2
	terrain.clear()
	runner.check(sim.snapshot() == before,"E3 snapshot and constructor isolation")
	return true

func test_variant_rejection(runner) -> bool:
	var sim = Fixture.make_world()
	var valid := {"type":"stop","entity_ids":[1],"tick":0,"player":1,"sequence":0}
	for key in valid.keys():
		var invalid: Dictionary = valid.duplicate(true)
		invalid.erase(key)
		var before: Dictionary = sim.snapshot()
		var result: Dictionary = sim.issue_command(invalid)
		runner.check(not result.ok and not result.error.is_empty() and sim.snapshot() == before,"E4 missing " + key)
	for ids in [[],[true],["1"],[1,1],[999]]:
		var invalid: Dictionary = valid.duplicate(true)
		invalid.entity_ids = ids
		var before: Dictionary = sim.snapshot()
		runner.check(not sim.issue_command(invalid).ok and sim.snapshot() == before,"E4 invalid IDs")
	var surplus: Dictionary = valid.duplicate(true)
	surplus.builder_id = true
	surplus.origin = "ignored"
	surplus.unit_kind = false
	runner.check(sim.issue_command(surplus).ok,"E4 surplus fields retain existing policy")
	var pending: Array = sim.snapshot().pending_commands
	runner.check(pending.size() == 1 and pending[0] == valid,"E4 normalize recognized variant fields only")
	var variants = Fixture.make_world(50000)
	var source: int = variants.add_supply_source(Vector2i(24,4),200)
	Fixture.build(runner,variants,"reactor",Vector2i(5,5))
	Fixture.build(runner,variants,"depot",Vector2i(10,4))
	var factory: int = Fixture.build(runner,variants,"factory",Vector2i(16,4))
	Fixture.send(variants,{"type":"build","builder_id":1,"building_kind":"reactor","origin":[8,12]})
	Fixture.send(variants,{"type":"produce","building_id":factory,"unit_kind":"vehicle"})
	variants.step()
	var foundation: int = variants.snapshot().buildings.back().id
	var entry: int = Fixture.object(variants,factory).queue[0].id
	var collector: int = -1
	for unit in variants.snapshot().entities:
		if unit.kind == "collector": collector = unit.id
	variants.add_player(2,50000)
	var foreign: int = variants.spawn(2,Vector2(2.5,2.5),"builder")
	var prototypes: Array = [
		{"type":"build","builder_id":1,"building_kind":"reactor","origin":[12,12]},
		{"type":"resume_build","builder_id":1,"building_id":foundation},
		{"type":"cancel_build","building_id":foundation},
		{"type":"produce","building_id":factory,"unit_kind":"vehicle"},
		{"type":"cancel_production","building_id":factory,"production_id":entry},
		{"type":"gather","entity_ids":[collector],"source_id":source},
		{"type":"stop","entity_ids":[1]},
	]
	var sequence: int = variants.snapshot().last_sequences[0].sequence + 1
	for prototype in prototypes:
		var cmd: Dictionary = prototype.duplicate(true)
		cmd.merge({"tick":variants.snapshot().tick + 100,"player":1,"sequence":sequence})
		for field in cmd.keys():
			var malformed: Dictionary = cmd.duplicate(true)
			malformed.erase(field)
			unchanged_rejection(runner,variants,malformed,"E4 missing variant " + field)
		for field in prototype.keys():
			if field == "type": continue
			var malformed: Dictionary = cmd.duplicate(true)
			malformed[field] = true
			unchanged_rejection(runner,variants,malformed,"E4 bool variant " + field)
			malformed[field] = "wrong"
			unchanged_rejection(runner,variants,malformed,"E4 string variant " + field)
		if cmd.type == "build":
			var malformed: Dictionary = cmd.duplicate(true)
			malformed.origin = [12.5,12]
			unchanged_rejection(runner,variants,malformed,"E4 fractional origin")
		var enemy: Dictionary = cmd.duplicate(true)
		enemy.player = 2
		enemy.sequence = 0
		unchanged_rejection(runner,variants,enemy,"E4 foreign economic variant")
		runner.check(variants.issue_command(cmd).ok,"E4 eligible variant " + cmd.type)
		unchanged_rejection(runner,variants,cmd,"E4 nonincreasing variant sequence")
		sequence += 1
	var mixed := {"tick":variants.snapshot().tick,"player":1,"sequence":sequence,"type":"stop","entity_ids":[1,foreign]}
	unchanged_rejection(runner,variants,mixed,"E4 mixed owner array")
	mixed.type = "unknown"
	unchanged_rejection(runner,variants,mixed,"E4 unknown type")
	return true

func test_future_results_and_copy(runner) -> bool:
	var sim = Fixture.make_world()
	var payload := {"type":"stop","entity_ids":[1],"tick":2}
	runner.check(Fixture.send(sim,payload).ok,"E5 future accepted")
	payload.entity_ids[0] = 999
	for index in range(2):
		sim.step()
		runner.check(sim.snapshot().command_results.is_empty() and sim.snapshot().pending_commands.size() == 1,"E5 waits")
	sim.step()
	runner.check(sim.snapshot().command_results == [{"tick":2,"player":1,"sequence":0,"ok":true,"error":""}],"E5 due result")
	var copy: Dictionary = sim.snapshot()
	if not copy.command_results.is_empty(): copy.command_results[0].error = "changed"
	runner.check(not sim.snapshot().command_results.is_empty() and sim.snapshot().command_results[0].error == "","E5 result copied")
	sim.step()
	runner.check(sim.snapshot().command_results.is_empty(),"E5 expires")
	return true

func test_stop_and_intent_order(runner) -> bool:
	var sim = Fixture.make_world()
	Fixture.send(sim,{"type":"move","entity_ids":[1],"target":[12.5,4.5]})
	Fixture.send(sim,{"type":"stop","entity_ids":[1]})
	sim.step()
	var unit: Dictionary = sim.snapshot().entities[0]
	runner.check(unit.position == [4.5,4.5] and unit.order == null and unit.destination == null and unit.route == [] and unit.status == "idle" and sim.snapshot().path_queue == [],"E6 stop wins")
	Fixture.send(sim,{"type":"stop","entity_ids":[1]})
	Fixture.send(sim,{"type":"move","entity_ids":[1],"target":[12.5,4.5]})
	var before: Dictionary = sim.snapshot()
	runner.check(not Fixture.send(sim,{"type":"stop","entity_ids":[999]}).ok and sim.snapshot() == before,"E6 invalid retains intent")
	sim.step()
	runner.check(sim.snapshot().entities[0].position[0] > 4.5,"E6 move wins")
	return true

func test_air_spawn(runner) -> bool:
	var blocked: Array[Vector2i] = [Vector2i(3,3)]
	var sim = Simulation.new(blocked)
	var ground: int = sim.spawn(1,Vector2(1.5,1.5))
	runner.check(sim.spawn(1,Vector2(3.5,3.5),"collector") == 2,"E7 air on solid")
	runner.check(sim.spawn(1,Vector2(1.5,1.5),"collector") == 3,"E7 air on ground")
	runner.check(sim.spawn(1,Vector2(1.5,1.5)) == -1,"E7 ground occupied")
	for point in [Vector2(-1,0),Vector2(16,0),Vector2(INF,0),Vector2(0,NAN)]:
		var before: Dictionary = sim.snapshot()
		runner.check(sim.spawn(1,point,"collector") == -1 and sim.snapshot() == before,"E7 air bounds unchanged")
	runner.check(ground == 1,"E7 ground retained")
	return true

func test_air_and_mixed_move(runner) -> bool:
	var blocked: Array[Vector2i] = []
	for y in range(16): blocked.append(Vector2i(3,y))
	var sim = Simulation.new(blocked)
	var air: int = sim.spawn(1,Vector2(1.5,1.5),"collector")
	runner.check(Fixture.send(sim,{"type":"move","entity_ids":[air],"target":[4.5,1.5]}).ok,"E8 air across wall accepted")
	for index in range(15):
		sim.step()
		runner.check(absf(sim.snapshot().entities[0].position[0] - (1.5 + .2 * (index + 1))) < 1e-5 and sim.snapshot().path_queue.is_empty(),"E8 direct air budget")
	runner.check(sim.snapshot().entities[0].status == "arrived","E8 exact fifteen ticks")
	var ground: int = sim.spawn(1,Vector2(1.5,2.5))
	var before: Dictionary = sim.snapshot()
	runner.check(not Fixture.send(sim,{"type":"move","entity_ids":[air,ground],"target":[3.5,2.5]}).ok and sim.snapshot() == before,"E8 mixed solid atomic")
	runner.check(Fixture.send(sim,{"type":"move","entity_ids":[air],"target":[3.5,2.5]}).ok,"E8 all air solid")
	runner.check(Fixture.send(sim,{"type":"move","entity_ids":[air,ground],"target":[2.5,2.5]}).ok,"E8 mixed accepted")
	sim.step()
	var units: Array = sim.snapshot().entities
	runner.check(units[0].destination == [2.5,2.5] and units[1].destination == [2.5,2.5],"E8 air does not reserve ground goal")
	return true

func test_air_obstacle_isolation(runner) -> bool:
	var sim = Simulation.new()
	sim.spawn(1,Vector2(1.5,1.5),"collector")
	Fixture.send(sim,{"type":"move","entity_ids":[1],"target":[4.5,1.5]})
	sim.step()
	var cells: Array[Vector2i] = [Vector2i(1,1),Vector2i(3,1)]
	runner.check(sim.replace_blocked_cells(cells).ok,"E9 terrain may cover air")
	runner.check(sim.snapshot().entities[0].status == "moving" and sim.snapshot().path_queue == [],"E9 air never repathed")
	Fixture.send(sim,{"type":"stop","entity_ids":[1]})
	sim.step()
	runner.check(sim.snapshot().entities[0].collection.cargo == 0 and not sim.snapshot().entities[0].collection.enabled,"E9 stop preserves cargo")
	return true

func test_power_rates(runner) -> bool:
	for row in [[0,0,1000],[0,2,500],[5,2,1000],[5,5,1000],[5,6,800],[5,10,500]]:
		runner.check(Definitions.work_rate(row[0],row[1]) == row[2],"E10 integer power " + str(row))
	return true

func test_remove_objects(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(24,4),8)
	var before: Dictionary = sim.snapshot()
	runner.check(not sim.remove_object(999).ok and sim.snapshot() == before,"E11 unknown unchanged")
	Fixture.send(sim,{"type":"build","builder_id":1,"building_kind":"reactor","origin":[8,4]})
	Fixture.send(sim,{"type":"move","entity_ids":[1],"target":[4.5,10.5]})
	sim.step()
	var building: int = sim.snapshot().buildings[0].id
	var destination: Array = Fixture.object(sim,1).destination
	runner.check(Fixture.send(sim,{"type":"resume_build","builder_id":1,"building_id":building}).ok,"E11 resume accepted")
	runner.check(Fixture.send(sim,{"type":"cancel_build","building_id":building}).ok,"E11 same tick cancel accepted")
	sim.step()
	var preserved: bool = Fixture.object(sim,1).destination == destination and Fixture.object(sim,1).construction_id == null
	runner.check(preserved,"E11 discarded canceled intent preserves prior manual order")
	if not preserved: return true
	var air: int = sim.spawn(1,Vector2(25.5,5.5),"collector")
	Fixture.send(sim,{"type":"gather","entity_ids":[air],"source_id":source,"tick":sim.snapshot().tick + 1})
	sim.remove_object(source)
	var next: int = sim.snapshot().next_entity_id
	Fixture.steps(sim,2)
	runner.check(not sim.snapshot().command_results[0].ok and sim.snapshot().next_entity_id == next,"E11 removed future target fails without ID gap")
	return true

func test_economy_loop(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(24,4),8)
	var reactor: int = Fixture.build(runner,sim,"reactor",Vector2i(5,5))
	var depot: int = Fixture.build(runner,sim,"depot",Vector2i(10,4))
	var factory: int = Fixture.build(runner,sim,"factory",Vector2i(16,4))
	if reactor == -1 or depot == -1 or factory == -1: return true
	var collector: int = -1
	for unit in sim.snapshot().entities:
		if unit.kind == "collector": collector = unit.id
	for index in range(3000):
		if sim.snapshot().players[0].credits == 5800: break
		sim.step()
	runner.check(sim.snapshot().players[0].credits == 5800,"E12 deposit600 after spend4800")
	Fixture.send(sim,{"type":"stop","entity_ids":[collector]})
	runner.check(Fixture.send(sim,{"type":"produce","building_id":factory,"unit_kind":"vehicle"}).ok,"E12 paid production accepted")
	Fixture.steps(sim,300)
	var state: Dictionary = sim.snapshot()
	runner.check(state.players[0].credits == 5100,"E12 10000-4800+600-700")
	runner.check(Fixture.object(sim,source).boxes == 0 and Fixture.object(sim,collector).collection.cargo == 0,"E12 source exhausted entire load deposited")
	runner.check(state.entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "vehicle").size() == 1 and state.entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "collector").size() == 1,"E12 one free collector one paid vehicle")
	runner.check(state.tick < 10000,"E12 bounded scenario")
	return true

func unchanged_rejection(runner, sim, command: Dictionary, label: String) -> void:
	var before: Dictionary = sim.snapshot()
	var result: Dictionary = sim.issue_command(command)
	runner.check(not result.ok and not result.error.is_empty() and sim.snapshot() == before,label)

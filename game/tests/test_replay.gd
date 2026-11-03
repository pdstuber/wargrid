extends RefCounted

const Fixture = preload("res://tests/economy_fixture.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

func cases() -> Array[Callable]:
	return [test_trace, test_exact_hash,test_economy_repeatability]

func _world(runner):
	var blocked: Array[Vector2i] = []
	for y in range(16):
		blocked.append(Vector2i(8, y))
	var sim = Simulation.new(blocked)
	for i in range(8):
		runner.check(sim.spawn(1, Vector2(1.25 + i % 4, 1.25 + 2 * (i / 4))) == i + 1, "R1 unique left spawn")
	for i in range(4):
		runner.check(sim.spawn(2, Vector2(10.25 + i, 2.25)) == 9 + i, "R1 unique right spawn")
	for entry in [[0, 0, [5.2, 5.1]], [0, 1, [1.7, 6.2]], [20, 2, [6.3, 10.7]], [80, 3, [12.3, 7.7]], [120, 4, [3.1, 4.2]]]:
		runner.check(sim.issue_command({"tick": entry[0], "player": 1, "sequence": entry[1], "type": "move", "entity_ids": [1, 2, 3, 4, 5, 6, 7, 8], "target": entry[2]}).ok, "R1 left command")
	for entry in [[0, 0, [14.1, 10.2]], [110, 1, [11.3, 3.7]]]:
		runner.check(sim.issue_command({"tick": entry[0], "player": 2, "sequence": entry[1], "type": "move", "entity_ids": [9, 10, 11, 12], "target": entry[2]}).ok, "R1 right command")
	var before: Dictionary = sim.snapshot()
	runner.check(not sim.issue_command({"tick": 0, "player": 1, "sequence": 5, "type": "move", "entity_ids": [1], "target": [8.2, 6.2]}).ok, "R1 invalid target")
	runner.check(sim.snapshot() == before, "R1 invalid unchanged")
	return sim

func _trace(runner, sim) -> PackedStringArray:
	var rows := PackedStringArray()
	for tick in range(1, 1201):
		sim.step()
		var state: Dictionary = sim.snapshot()
		runner.check(state.tick == tick, "R1 explicit tick %d" % tick)
		rows.append("%d\t%s" % [tick, _hash(state)])
	return rows

func test_trace(runner) -> bool:
	var a: PackedStringArray = _trace(runner, _world(runner))
	var b: PackedStringArray = _trace(runner, _world(runner))
	runner.check(a.size() == 1200 and b.size() == 1200, "R1 complete traces")
	for i in range(mini(a.size(), b.size())):
		runner.check(a[i] == b[i], "R1 exact replay tick %d" % (i + 1))
	var path: String = OS.get_environment("WARGRID_REPLAY_TRACE")
	if not path.is_empty():
		var file := FileAccess.open(path, FileAccess.WRITE)
		runner.check(file != null, "R1 trace output opens")
		if file == null:
			return false
		file.store_string("\n".join(a) + "\n")
		runner.check(file.get_error() == OK, "R1 trace output writes")
		file.close()
	return true

func _hash(state: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(state))
	return context.finish().hex_encode()

func test_exact_hash(runner) -> bool:
	var sim = _world(runner)
	sim.step()
	var state: Dictionary = sim.snapshot()
	var changed: Dictionary = state.duplicate(true)
	changed.entities[0].position[0] += 1e-12
	runner.check(_hash(state) != _hash(changed), "R2 retain full float precision")
	changed = state.duplicate(true)
	changed.map.blocked_cells[0][0] = 7
	runner.check(_hash(state) != _hash(changed), "R2 include nested map")
	return true

func test_economy_repeatability(runner) -> bool:
	var rows: PackedStringArray = _economy_trace(runner)
	runner.check(rows.size() == 1200,"R3 complete economy trace")
	var path: String = OS.get_environment("WARGRID_ECONOMY_REPLAY_TRACE")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		runner.check(file != null,"R3 economy trace opens")
		if file == null: return false
		file.store_string("\n".join(rows) + "\n")
		runner.check(file.get_error() == OK,"R3 economy trace writes")
		file.close()
	return true

func _economy_world(runner) -> Dictionary:
	var sim = Fixture.make_world(50000)
	var source: int = sim.add_supply_source(Vector2i(24,4),200)
	var reactor: int = Fixture.build(runner,sim,"reactor",Vector2i(5,5))
	var depot: int = Fixture.build(runner,sim,"depot",Vector2i(10,4))
	var factory: int = Fixture.build(runner,sim,"factory",Vector2i(16,4))
	var collector: int = -1
	for unit in sim.snapshot().entities:
		if unit.kind == "collector": collector = unit.id
	return {"sim":sim,"source":source,"reactor":reactor,"depot":depot,"factory":factory,"collector":collector,"temporary":-1}

func _economy_send(runner, world: Dictionary, payload: Dictionary) -> void:
	var result: Dictionary = Fixture.send(world.sim,payload)
	runner.check(result.ok,"R3 scenario command " + str(payload) + ": " + result.error)

func _economy_events(runner, world: Dictionary, index: int) -> void:
	var sim = world.sim
	match index:
		0:
			_economy_send(runner,world,{"type":"produce","building_id":world.factory,"unit_kind":"vehicle"})
			_economy_send(runner,world,{"type":"produce","building_id":world.factory,"unit_kind":"vehicle"})
			_economy_send(runner,world,{"type":"build","builder_id":1,"building_kind":"reactor","origin":[8,12],"tick":sim.snapshot().tick + 10})
		20:
			world.temporary = sim.snapshot().buildings.back().id
			_economy_send(runner,world,{"type":"cancel_build","building_id":world.temporary,"tick":sim.snapshot().tick + 60})
		40: _economy_send(runner,world,{"type":"cancel_build","building_id":world.temporary})
		50:
			var queue: Array = Fixture.object(sim,world.factory).queue
			_economy_send(runner,world,{"type":"cancel_production","building_id":world.factory,"production_id":queue.back().id})
		80: _economy_send(runner,world,{"type":"stop","entity_ids":[world.collector]})
		100:
			_economy_send(runner,world,{"type":"gather","entity_ids":[world.collector],"source_id":world.source})
			_economy_send(runner,world,{"type":"produce","building_id":world.depot,"unit_kind":"collector"})
		150: runner.check(sim.remove_object(world.reactor).ok,"R3 remove power")
		250:
			var before: Dictionary = sim.snapshot()
			runner.check(not Fixture.send(sim,{"type":"gather","entity_ids":[1,world.collector],"source_id":world.source}).ok and sim.snapshot() == before,"R3 invalid mixed gather unchanged")
		400: runner.check(sim.remove_object(world.source).ok,"R3 remove source")
		500:
			world.source = sim.add_supply_source(Vector2i(24,12),9)
			runner.check(world.source != -1,"R3 replacement finite source")
			_economy_send(runner,world,{"type":"gather","entity_ids":[world.collector],"source_id":world.source})
		650: _economy_send(runner,world,{"type":"produce","building_id":world.factory,"unit_kind":"vehicle"})
		700: runner.check(sim.remove_object(world.depot).ok,"R3 remove depot refund")
		900: runner.check(sim.remove_object(world.factory).ok,"R3 remove factory refund")
		1000: _economy_send(runner,world,{"type":"build","builder_id":1,"building_kind":"reactor","origin":[12,12]})
		1080: _economy_send(runner,world,{"type":"stop","entity_ids":[world.collector],"tick":sim.snapshot().tick + 50})
		1110: runner.check(sim.remove_object(world.collector).ok,"R3 remove future target")

func _economy_trace(runner) -> PackedStringArray:
	var a: Dictionary = _economy_world(runner)
	var b: Dictionary = _economy_world(runner)
	var initial: Dictionary = a.sim.snapshot()
	runner.check(initial == b.sim.snapshot() and initial.tick > 0,"R3 identical public setup absolute tick")
	for field in ["credits","boxes","work"]:
		var changed: Dictionary = initial.duplicate(true)
		match field:
			"credits": changed.players[0].credits += 1
			"boxes": changed.sources[0].boxes += 1
			"work": changed.buildings[0].work += 1
		runner.check(_hash(changed) != _hash(initial),"R3 digest retains one " + field)
	var rows := PackedStringArray()
	for index in range(1200):
		_economy_events(runner,a,index)
		_economy_events(runner,b,index)
		a.sim.step()
		b.sim.step()
		var state: Dictionary = a.sim.snapshot()
		runner.check(state == b.sim.snapshot() and state.tick == initial.tick + index + 1,"R3 exact entire snapshot step %d" % (index + 1))
		var changed: Dictionary = a.sim.snapshot()
		changed.players[0].credits += 1
		if not changed.sources.is_empty(): changed.sources[0].boxes += 1
		for unit in changed.entities:
			if unit.collection != null:
				unit.collection.remaining_ticks += 1
				unit.collection.target_id = -1
		for building in changed.buildings:
			building.work += 1
			if not building.queue.is_empty(): building.queue[0].paid_cost += 1
		runner.check(a.sim.snapshot() == state,"R3 deep economy snapshot isolation")
		rows.append("%d\t%s" % [index + 1,_hash(state)])
	return rows

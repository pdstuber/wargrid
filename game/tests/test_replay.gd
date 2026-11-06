@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/economy_fixture.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")

func cases() -> Array[Callable]:
	return [test_trace, test_exact_hash,test_economy_repeatability,test_combat_repeatability,test_combat_hash_sensitivity]

func _world(runner):
	var blocked: Array[Vector2i] = []
	for y in range(16):
		blocked.append(Vector2i(8, y))
	var sim = Simulation.new(blocked)
	for i in range(8):
		@warning_ignore("integer_division")
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

func _combat_world(runner) -> Dictionary:
	var sim = Skirmish.create(false)
	var barracks: int = Fixture.build(runner,sim,"barracks",Skirmish.origin("barracks",1))
	var ids := {"barracks":barracks}
	for key in ["inf1","inf2"]:
		ids[key] = sim.spawn(1,Vector2(20.5,10.5 if key == "inf1" else 11.5),"infantry")
	ids.tank1 = sim.spawn(1,Vector2(22.5,10.5),"tank")
	ids.enemy = sim.spawn(2,Vector2(26.5,10.5),"infantry")
	ids.duel1 = sim.spawn(1,Vector2(30.5,24.5),"tank")
	ids.duel2 = sim.spawn(2,Vector2(34.5,24.5),"tank")
	runner.check(sim.start_match([1,2] as Array[int]).ok,"R4 match starts after setup")
	return {"sim":sim,"ids":ids,"refund":0}

func _combat_events(runner, world: Dictionary, index: int) -> void:
	var sim = world.sim
	var ids: Dictionary = world.ids
	match index:
		0:
			for i in range(2): runner.check(Fixture.send(sim,{"type":"produce","building_id":ids.barracks,"unit_kind":"infantry"}).ok,"R4 produce")
			runner.check(Fixture.send(sim,{"type":"attack","entity_ids":[ids.inf1,ids.inf2],"target_id":ids.enemy}).ok,"R4 attack")
		5:
			var credits: int = sim.snapshot().players[0].credits
			var queue: Array = Fixture.object(sim,ids.barracks).queue
			runner.check(Fixture.send(sim,{"type":"cancel_production","building_id":ids.barracks,"production_id":queue.back().id}).ok,"R4 cancel production")
			world.refund = credits
		40: runner.check(Fixture.send(sim,{"type":"move","entity_ids":[ids.tank1],"target":[22.5,14.5]}).ok,"R4 move")
		80: runner.check(Fixture.send(sim,{"type":"attack_move","entity_ids":[ids.inf2,ids.tank1],"target":[40.5,14.5]}).ok,"R4 attack_move")
		150: runner.check(Fixture.send(sim,{"type":"stop","entity_ids":[ids.inf1]}).ok,"R4 stop")
		200:
			if not Fixture.object(sim,ids.enemy).is_empty(): runner.check(sim.remove_object(ids.enemy).ok,"R4 target removal")
		600:
			for at in [Vector2(38.5,14.5),Vector2(38.5,15.5),Vector2(38.5,13.5),Vector2(39.5,14.5),Vector2(39.5,15.5)]:
				runner.check(sim.spawn(1,at,"tank") != -1,"R4 finishing group")

func _combat_trace(runner) -> Dictionary:
	var a: Dictionary = _combat_world(runner)
	var b: Dictionary = _combat_world(runner)
	var base: int = a.sim.snapshot().tick
	runner.check(a.sim.snapshot() == b.sim.snapshot() and base > 0,"R4 identical public setup at an absolute tick")
	var rows := PackedStringArray()
	var seen := {"shots":0,"double_death":false,"refund":false,"ended":-1}
	var credits_before: int = 0
	for index in range(1200):
		_combat_events(runner,a,index)
		_combat_events(runner,b,index)
		if index == 5: credits_before = a.refund
		a.sim.step()
		b.sim.step()
		var state: Dictionary = a.sim.snapshot()
		runner.check(state == b.sim.snapshot(),"R4 exact entire snapshot step %d" % (index + 1))
		if index == 5 and state.players[0].credits >= credits_before + 225: seen.refund = true
		seen.shots += state.combat_events.filter(func(event: Dictionary) -> bool: return event.type == "shot").size()
		if state.combat_events.filter(func(event: Dictionary) -> bool: return event.type == "death").size() >= 2: seen.double_death = true
		if seen.ended == -1 and state.match.status != "ongoing": seen.ended = index
		rows.append("%d\t%s" % [index + 1,_hash(state)])
	return {"rows":rows,"seen":seen,"base":base,"tick":a.sim.snapshot().tick,"match":a.sim.snapshot().match}

func test_combat_repeatability(runner) -> bool:
	var result: Dictionary = _combat_trace(runner)
	var rows: PackedStringArray = result.rows
	runner.check(rows.size() == 1200,"R4 complete combat trace")
	runner.check(result.seen.shots > 0 and result.seen.double_death and result.seen.refund,"R4 shots, a simultaneous double death and a queue refund all happened")
	runner.check(result.seen.ended > 0 and result.seen.ended < 1199 and result.match.status == "won" and result.match.winner == 1,"R4 terminal state reached inside the trace")
	runner.check(result.tick == result.base + result.seen.ended + 1 and rows[result.seen.ended + 1].split("\t")[1] == rows[1199].split("\t")[1],"R4 absolute tick frozen after the terminal step")
	var path: String = OS.get_environment("WARGRID_COMBAT_REPLAY_TRACE")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		runner.check(file != null,"R4 combat trace opens")
		if file == null: return false
		file.store_string("\n".join(rows) + "\n")
		runner.check(file.get_error() == OK,"R4 combat trace writes")
		file.close()
	return true

func test_combat_hash_sensitivity(runner) -> bool:
	var world: Dictionary = _combat_world(runner)
	for index in range(60):
		_combat_events(runner,world,index)
		world.sim.step()
	var state: Dictionary = world.sim.snapshot()
	var armed: int = state.entities.find_custom(func(unit: Dictionary) -> bool: return unit.combat != null and unit.combat.target_id != null)
	runner.check(armed != -1,"R5 an engaged unit exists")
	var original: String = _hash(state)
	var mutations := {
		"hp": func(copy: Dictionary) -> void: copy.entities[armed].hp += 1,
		"next_fire_tick": func(copy: Dictionary) -> void: copy.entities[armed].combat.next_fire_tick += 1,
		"ammo": func(copy: Dictionary) -> void: copy.entities[armed].combat.shots_left += 1,
		"target_id": func(copy: Dictionary) -> void: copy.entities[armed].combat.target_id += 1,
		"winner": func(copy: Dictionary) -> void: copy.match.winner = 2,
	}
	for name in mutations:
		var copy: Dictionary = state.duplicate(true)
		mutations[name].call(copy)
		runner.check(_hash(copy) != original,"R5 digest retains one " + name)
	runner.check(_hash(world.sim.snapshot()) == original,"R5 live original unchanged")
	return true

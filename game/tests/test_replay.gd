extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")

func cases() -> Array[Callable]:
	return [test_trace, test_exact_hash]

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

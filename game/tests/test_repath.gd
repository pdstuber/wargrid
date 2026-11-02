extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Navigation = preload("res://scripts/simulation/grid_navigation.gd")
const Groups = preload("res://tests/test_groups.gd")

func cases() -> Array[Callable]:
	return [test_repath, test_disconnect, test_validation_and_future, test_queue_replay]

func _single() -> Simulation:
	var sim = Simulation.new()
	sim.spawn(1, Vector2(1.5, 1.5))
	var helper = Groups.new()
	sim.issue_command(helper.command(sim, [1], [6.5, 1.5]))
	for i in range(3):
		sim.step()
	return sim

func test_repath(runner) -> bool:
	var sim = _single()
	var position: Array = sim.snapshot().entities[0].position
	var cells: Array[Vector2i] = [Vector2i(3, 1)]
	runner.check(sim.replace_blocked_cells(cells).ok, "RP1 edit accepted")
	cells[0] = Vector2i(9, 9)
	var state: Dictionary = sim.snapshot()
	runner.check(state.entities[0].position == position and state.entities[0].status == "path_pending" and state.entities[0].route == [] and state.path_queue == [1], "RP1 edit queues from actual position without teleport")
	runner.check(state.map.blocked_cells == [[3, 1]], "RP1 installed blockers isolated")
	var nav = Navigation.new([Vector2i(3, 1)])
	var arrived := false
	for tick in range(150):
		var old: Array = sim.snapshot().entities[0].position
		sim.step()
		state = sim.snapshot()
		var unit: Dictionary = state.entities[0]
		for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
			runner.check(nav.is_walkable(Vector2(old[0], old[1]).lerp(Vector2(unit.position[0], unit.position[1]), fraction)), "RP1 avoids newly solid segments")
		if unit.status == "arrived":
			arrived = true
			break
	runner.check(arrived and state.entities[0].position == [6.5, 1.5], "RP1 new route arrives")
	return true

func test_disconnect(runner) -> bool:
	var sim = _single()
	var wall: Array[Vector2i] = []
	for y in range(16):
		wall.append(Vector2i(3, y))
	runner.check(sim.replace_blocked_cells(wall).ok, "RP2 wall accepted")
	var before: Dictionary = sim.snapshot()
	runner.check(before.entities[0].status == "blocked" and before.entities[0].destination == null and before.entities[0].order == null and before.entities[0].route == [] and before.path_queue == [], "RP2 disconnected mover fully cleared")
	for i in range(300):
		sim.step()
	runner.check(sim.snapshot().entities == before.entities, "RP2 blocked persists")
	runner.check(sim.replace_blocked_cells([]).ok, "RP2 wall removed")
	for i in range(20):
		sim.step()
	runner.check(sim.snapshot().entities == before.entities and sim.snapshot().path_queue == [], "RP2 removal does not revive order")
	var helper = Groups.new()
	runner.check(sim.issue_command(helper.command(sim, [1], [6.5, 1.5], 1)).ok, "RP2 new order recovers")
	for i in range(150):
		sim.step()
	runner.check(sim.snapshot().entities[0].status == "arrived" and sim.snapshot().entities[0].position == [6.5, 1.5], "RP2 recovery arrives")
	sim = _single()
	runner.check(sim.replace_blocked_cells([Vector2i(6, 1)]).ok and sim.snapshot().entities[0].status == "blocked", "RP2 reserved goal can be blocked")
	return true

func test_validation_and_future(runner) -> bool:
	var sim = _single()
	for cells in [[Vector2i(1, 1)], [Vector2i(16, 0)], [Vector2i(-1, 0)]]:
		var typed: Array[Vector2i] = []
		typed.assign(cells)
		var before: Dictionary = sim.snapshot()
		var result: Dictionary = sim.replace_blocked_cells(typed)
		runner.check(not result.ok and not result.error.is_empty() and sim.snapshot() == before, "RP3 occupied/outside atomic rejection")
	sim.replace_blocked_cells([Vector2i(3, 1), Vector2i(4, 1)])
	var before: Dictionary = sim.snapshot()
	runner.check(sim.replace_blocked_cells([Vector2i(4, 1), Vector2i(3, 1), Vector2i(3, 1)]).ok and sim.snapshot() == before, "RP3 normalized no-op retains route queue")
	sim = Simulation.new()
	sim.spawn(1, Vector2(1.5, 1.5))
	var helper = Groups.new()
	runner.check(sim.issue_command(helper.command(sim, [1], [3.5, 1.5], 0, 1, 5)).ok, "RP3 future target initially valid")
	runner.check(sim.replace_blocked_cells([Vector2i(3, 1)]).ok, "RP3 future target later blocked")
	for i in range(6):
		sim.step()
	runner.check(sim.snapshot().entities[0].status == "blocked" and sim.snapshot().entities[0].destination == null, "RP3 target invalid on application blocks")
	return true

func _replay(batch: int, reads: bool):
	var helper = Groups.new()
	var sim = helper._twenty()
	for base in range(0, 300, batch):
		for offset in range(batch):
			var tick: int = base + offset
			if tick == 1:
				sim.replace_blocked_cells([Vector2i(10, 1)])
			elif tick == 4:
				var wall: Array[Vector2i] = []
				for y in range(16):
					wall.append(Vector2i(8, y))
				sim.replace_blocked_cells(wall)
			elif tick == 20:
				sim.replace_blocked_cells([])
			elif tick == 21:
				sim.issue_command(helper.command(sim, range(1, 21), [12.5, 12.5], 1))
			sim.step()
			if reads:
				var changed: Dictionary = sim.snapshot()
				changed.path_queue.clear()
				changed.map.blocked_cells.clear()
	return sim.snapshot()

func test_queue_replay(runner) -> bool:
	var helper = Groups.new()
	var sim = helper._twenty()
	sim.step()
	var positions: Array = []
	for unit in sim.snapshot().entities:
		positions.append(unit.position)
	runner.check(sim.replace_blocked_cells([Vector2i(10, 1)]).ok, "RP4 queued edit accepted")
	var state: Dictionary = sim.snapshot()
	runner.check(state.path_queue == range(1, 21), "RP4 active queue rebuilt sorted once")
	for i in range(20):
		runner.check(state.entities[i].route == [] and state.entities[i].status == "path_pending" and state.entities[i].position == positions[i], "RP4 no stale route or teleport")
	var expected: Dictionary = _replay(1, false)
	for batch in [1, 3, 10]:
		runner.check(_replay(batch, true) == expected, "RP4 exact obstacle-edit replay batch %d" % batch)
	return true

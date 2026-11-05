extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Economy = preload("res://tests/economy_fixture.gd")
const Locomotion = preload("res://scripts/simulation/locomotion.gd")

func cases() -> Array[Callable]:
	return [test_start_delay_three_ticks, test_acceleration_curve, test_short_hop_no_overshoot, test_group_arrival_unchanged, test_reorder_keeps_speed]

func unit_of(sim, id: int) -> Dictionary:
	return Economy.object(sim, id)

func start_gap(sim, id: int, limit: int = 60) -> int:
	var moving_at: int = -1
	var origin: Array = []
	for index in range(limit):
		sim.step()
		var unit: Dictionary = unit_of(sim, id)
		if moving_at < 0 and unit.status == "moving":
			moving_at = index
			origin = unit.position
		if moving_at >= 0 and unit.position != origin: return index - moving_at
	return -1

func test_start_delay_three_ticks(runner) -> bool:
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 1000)
	var id: int = sim.spawn(1, Vector2(5.5, 5.5), "infantry")
	Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [15.5, 5.5]})
	runner.check(start_gap(sim, id) == 2, "L1 move starts 2 snapshots after moving")
	sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 1000)
	id = sim.spawn(1, Vector2(5.5, 5.5), "infantry")
	Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [15.5, 5.5]})
	sim.step()
	sim.step()
	runner.check(unit_of(sim, id).position == [5.5, 5.5], "L1 no movement before command tick + 2")
	sim.step()
	runner.check(unit_of(sim, id).position != [5.5, 5.5], "L1 first movement at command tick + g + 2")
	sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 1000)
	id = sim.spawn(1, Vector2(5.5, 5.5), "infantry")
	Economy.send(sim, {"type": "attack_move", "entity_ids": [id], "target": [15.5, 5.5]})
	runner.check(start_gap(sim, id) == 2, "L1 attack-move delay")
	sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 1000)
	sim.add_player(2, 1000)
	id = sim.spawn(1, Vector2(5.5, 5.5), "infantry")
	var target: int = sim.spawn(2, Vector2(11.5, 5.5), "infantry")
	Economy.send(sim, {"type": "attack", "entity_ids": [id], "target_id": target})
	runner.check(start_gap(sim, id) == 2, "L1 chase delay")
	sim = Economy.make_world(20000)
	var barracks: int = Economy.build(runner, sim, "barracks", Vector2i(8, 8))
	var before: Array = sim.snapshot().entities.map(func(e): return e.id)
	Economy.send(sim, {"type": "produce", "building_id": barracks, "unit_kind": "infantry"})
	var moving_at: int = -1
	var gap: int = -1
	var origin: Array = []
	for index in range(600):
		sim.step()
		for e in sim.snapshot().entities:
			if e.kind != "infantry" or before.has(e.id): continue
			if moving_at < 0 and e.status == "moving":
				moving_at = index
				origin = e.position
			if moving_at >= 0 and gap < 0 and e.position != origin: gap = index - moving_at
		if gap >= 0: break
	runner.check(moving_at >= 0 and gap == 2, "L1 production exit delay")
	return true

func test_acceleration_curve(runner) -> bool:
	for row in [["infantry", 6, 0.8], ["builder", 30, 1.2]]:
		var sim = Simulation.new([], Vector2i(64, 8))
		sim.add_player(1, 1000)
		var id: int = sim.spawn(1, Vector2(1.5, 3.5), row[0])
		Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [60.5, 3.5]})
		var steps: int = 0
		var speeds: Array = []
		for index in range(100):
			sim.step()
			var unit: Dictionary = unit_of(sim, id)
			if unit.position[0] != 1.5:
				speeds.append(unit.speed)
		runner.check(speeds.size() >= row[1], "L2 enough moving steps " + row[0])
		runner.check(absf(speeds[row[1] - 1] - row[2]) < 1e-9, "L2 full speed after step " + str(row[1]) + " " + row[0])
		runner.check(speeds[row[1] - 2] < row[2], "L2 below full speed one step earlier " + row[0])
	return true

func test_short_hop_no_overshoot(runner) -> bool:
	var sim = Simulation.new([], Vector2i(16, 16))
	sim.add_player(1, 1000)
	var id: int = sim.spawn(1, Vector2(5.2, 5.5), "builder")
	Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [5.5, 5.5]})
	var over: bool = false
	for index in range(120):
		sim.step()
		if unit_of(sim, id).position[0] > 5.5 + 1e-9: over = true
	var unit: Dictionary = unit_of(sim, id)
	runner.check(not over, "L3 never beyond the destination")
	runner.check(unit.position == [5.5, 5.5] and unit.status == "arrived", "L3 exact arrival")
	return true

func test_group_arrival_unchanged(runner) -> bool:
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 1000)
	var ids: Array = []
	for index in range(6): ids.append(sim.spawn(1, Vector2(3.5 + index, 3.5), "infantry"))
	Economy.send(sim, {"type": "move", "entity_ids": ids, "target": [20.5, 20.5]})
	for index in range(2000):
		sim.step()
	var done: bool = true
	for index in ids.size():
		var unit: Dictionary = unit_of(sim, ids[index])
		done = done and unit.status == "arrived" and unit.position == unit.destination
	runner.check(done, "L4 every unit arrives exactly on its slot")
	return true

func test_reorder_keeps_speed(runner) -> bool:
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 1000)
	var id: int = sim.spawn(1, Vector2(5.5, 5.5), "infantry")
	Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [25.5, 5.5]})
	for index in range(12): sim.step()
	var before: Dictionary = unit_of(sim, id)
	Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [5.5, 15.5]})
	sim.step()
	sim.step()
	var after: Dictionary = unit_of(sim, id)
	runner.check(before.speed == 0.8 and after.speed == 0.8 and after.status == "moving", "L5 re-order while moving keeps full speed")
	runner.check(is_equal_approx(Locomotion.braking_distance(0.8, 4.0), 0.08), "L5 braking distance")
	return true

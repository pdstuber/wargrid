extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Economy = preload("res://tests/economy_fixture.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Locomotion = preload("res://scripts/simulation/locomotion.gd")

func cases() -> Array[Callable]:
	return [test_start_delay_three_ticks, test_acceleration_curve, test_short_hop_no_overshoot, test_group_arrival_unchanged, test_reorder_keeps_speed, test_angle_between_accuracy, test_measured_turn_then_move, test_heading_factors, test_reorder_mid_turn, test_reorder_mid_cell_straight, test_dozer_turn_follows_speed]

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
	Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [29.5, 5.5]})
	sim.step()
	sim.step()
	var after: Dictionary = unit_of(sim, id)
	runner.check(before.speed == 0.8 and after.speed == 0.8 and after.move_after == before.move_after and after.status == "moving", "L5 re-order while moving keeps speed and gets no new start delay")
	runner.check(is_equal_approx(Locomotion.braking_distance(0.8, 4.0), 0.08), "L5 braking distance")
	return true

func test_angle_between_accuracy(runner) -> bool:
	var worst: float = 0.0
	for index in range(3600):
		var degrees: float = index / 10.0
		var radians: float = degrees * PI / 180.0
		var shown: float = degrees if degrees <= 180.0 else 360.0 - degrees
		var measured: float = Locomotion.angle_between(Vector2(1, 0), Vector2(cos(radians), sin(radians)))
		worst = maxf(worst, absf(measured - shown))
	runner.check(worst <= 0.1, "L6 angle error " + str(worst))
	return true

func first_move_offset(kind: String) -> int:
	var sim = Simulation.new([], Vector2i(64, 16))
	sim.add_player(1, 1000)
	var id: int = sim.spawn(1, Vector2(30.5, 8.5), kind)
	Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [5.5, 8.5]})
	var moving_at: int = -1
	for index in range(200):
		sim.step()
		var unit: Dictionary = unit_of(sim, id)
		if moving_at < 0 and unit.status == "moving": moving_at = index
		if unit.position != [30.5, 8.5]: return index - moving_at
	return -1

func test_measured_turn_then_move(runner) -> bool:
	# Ranger: 16.67 deg/tick, first move once 180 - 16.67 (k - 1) < 45: k = 9.1 -> 10 turns, offset 9 after the first moving tick.
	# Crusader: 6 deg/tick, 180 - 6 (k - 1) < 45: k = 23.5 -> 24, offset 23. Measured 11 and 24 are counted from the command, one tick before the first moving snapshot.
	# Dozer: wheels never stop, so the first move is the end of the start delay, offset 2.
	var expected := {"infantry": 9, "tank": 23, "builder": 2}
	var measured := {"infantry": 11, "tank": 24, "builder": 3}
	for kind in expected:
		var offset: int = first_move_offset(kind)
		runner.check(offset == expected[kind], "L7 first move " + kind + " " + str(offset))
		runner.check(absi(offset + 1 - measured[kind]) <= 1, "L7 within one tick of measured " + kind)
	return true

func test_heading_factors(runner) -> bool:
	var tank: Dictionary = Definitions.unit("tank")
	var infantry: Dictionary = Definitions.unit("infantry")
	var builder: Dictionary = Definitions.unit("builder")
	runner.check(is_equal_approx(Locomotion.heading_factor("treads", 22.5, tank), 0.5), "L8 treads half")
	runner.check(Locomotion.heading_factor("treads", 45.0, tank) == 0.0, "L8 treads zero at 45")
	runner.check(is_equal_approx(Locomotion.heading_factor("legs", 22.5, infantry), 0.5), "L8 legs half")
	runner.check(Locomotion.heading_factor("legs", 45.0, infantry) == 0.0, "L8 legs zero at 45")
	runner.check(is_equal_approx(Locomotion.heading_factor("wheels", 30.0, builder), maxf(builder.min_turn_speed, 1.2 / 4.0) / 1.2), "L8 wheels floor")
	runner.check(Locomotion.heading_factor("wheels", 9.0, builder) == 1.0, "L8 wheels straight")
	return true

func test_reorder_mid_turn(runner) -> bool:
	var sim = Simulation.new([], Vector2i(64, 16))
	sim.add_player(1, 1000)
	var id: int = sim.spawn(1, Vector2(30.5, 8.5), "tank")
	Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [5.5, 8.5]})
	for index in range(8): sim.step()
	var before: Dictionary = unit_of(sim, id)
	Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [30.5, 14.5]})
	sim.step()
	var after: Dictionary = unit_of(sim, id)
	runner.check(after.position == before.position, "L9 position does not jump")
	runner.check(Locomotion.angle_between(Vector2(before.heading[0], before.heading[1]), Vector2(after.heading[0], after.heading[1])) < 6.5 and Locomotion.angle_between(Vector2(before.heading[0], before.heading[1]), Vector2(after.heading[0], after.heading[1])) > 5.5, "L9 heading turns one 6 degree step from where it was")
	runner.check(before.speed == 0.0 and after.move_after == before.move_after + 8, "L9 re-order while still turning in place restarts the start delay")
	runner.check(Locomotion.angle_between(Vector2(after.heading[0], after.heading[1]), Vector2(0, 1)) < 175.0, "L9 heading follows the new route")
	return true

func test_reorder_mid_cell_straight(runner) -> bool:
	var sim = Simulation.new([], Vector2i(64, 16))
	sim.add_player(1, 1000)
	var id: int = sim.spawn(1, Vector2(5.5, 8.5), "tank")
	Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [40.5, 8.5]})
	for index in range(40): sim.step()
	var before: Dictionary = unit_of(sim, id)
	Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [50.5, 8.5]})
	var minimum: float = before.position[0]
	for index in range(30):
		sim.step()
		minimum = minf(minimum, unit_of(sim, id).position[0])
	var after: Dictionary = unit_of(sim, id)
	runner.check(minimum >= before.position[0] and after.heading[0] > 0.99, "L10 mid-cell re-order ahead never goes backwards or turns back")
	runner.check(after.speed > 0.0 and after.move_after == before.move_after, "L10 mid-cell re-order keeps moving without a new delay")
	return true

# Dozer 180 degree turn in the retail source build (parity trace turn_dozer, order at frame 8): 90 degrees turned 46 frames after the order. Later frames are not compared: the retail dozer also braked to 0.15 cells/s mid-turn there, cause not identified.
func test_dozer_turn_follows_speed(runner) -> bool:
	var sim = Simulation.new([], Vector2i(64, 16))
	sim.add_player(1, 1000)
	var id: int = sim.spawn(1, Vector2(30.5, 8.5), "builder")
	Economy.send(sim, {"type": "move", "entity_ids": [id], "target": [5.5, 8.5]})
	var quarter: int = -1
	for index in range(1, 301):
		sim.step()
		var unit: Dictionary = unit_of(sim, id)
		var left: float = Locomotion.angle_between(Vector2(unit.heading[0], unit.heading[1]), Vector2(-1.0, 0.0))
		if quarter < 0 and left <= 90.0: quarter = index
	runner.check(absi(quarter - 46) <= 6, "L11 dozer 90 degrees turned after %d ticks (retail 46)" % quarter)
	return true

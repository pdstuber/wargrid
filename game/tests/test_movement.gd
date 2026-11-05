extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Navigation = preload("res://scripts/simulation/grid_navigation.gd")

func cases() -> Array[Callable]:
	return [test_distance, test_short_zero, test_replacement, test_retarget, test_obstacle, test_blocked, test_invalid, test_replay, test_far_coordinates]

func order(sim, target: Vector2, sequence: int = 0, tick: int = -1) -> Dictionary:
	return sim.issue_command({"tick": sim.snapshot().tick if tick < 0 else tick, "player": 1,
		"sequence": sequence, "type": "move", "entity_ids": [1], "target": [target.x, target.y]})

func entity(sim) -> Dictionary:
	return sim.snapshot().entities[0]

func position(sim) -> Vector2:
	var point: Array = entity(sim).position
	return Vector2(point[0], point[1])

func advance(sim, ticks: int) -> void:
	for i in range(ticks):
		sim.step()

func arrived(runner, sim, target: Vector2, label: String) -> void:
	runner.check(position(sim) == target, label + " exact target")
	var unit: Dictionary = entity(sim)
	runner.check(unit.get("status") == "arrived" and unit.order == null and unit.get("route") == [], label + " finished state")

func test_distance(runner) -> bool:
	var sim = Simulation.new()
	sim.spawn(1, Vector2(1.5, 1.5))
	runner.check(entity(sim).get("status") == "idle", "M1 idle")
	runner.check(order(sim, Vector2(4.5, 1.5)).ok, "M1 accepted")
	advance(sim, 3)
	runner.check(position(sim).distance_to(Vector2(1.5 + 4.0 / 90.0, 1.5)) <= 1e-5, "M1 first budget")
	runner.check(entity(sim).get("status") == "moving", "M1 moving")
	advance(sim, 9)
	runner.check(position(sim).distance_to(Vector2(2.5 - 1.0 / 15.0, 1.5)) <= 1e-5, "M1 ten budgets (2 ramp ticks lose 1/15)")
	advance(sim, 22)
	arrived(runner, sim, Vector2(4.5, 1.5), "M1 arrival 32")
	var before: Dictionary = entity(sim)
	advance(sim, 30)
	runner.check(entity(sim) == before, "M1 arrival persists")
	return true

func test_short_zero(runner) -> bool:
	for target in [Vector2(1.55, 1.5), Vector2(1.5, 1.5)]:
		var sim = Simulation.new()
		sim.spawn(1, Vector2(1.5, 1.5))
		runner.check(order(sim, target).ok, "M2 accepted")
		advance(sim, 5)
		arrived(runner, sim, target, "M2 short/zero")
	return true

func test_replacement(runner) -> bool:
	var sim = Simulation.new()
	sim.spawn(1, Vector2(1.5, 1.5))
	runner.check(order(sim, Vector2(4.5, 1.5)).ok, "M3 first")
	runner.check(order(sim, Vector2(1.5, 4.5), 1).ok, "M3 second")
	advance(sim, 3)
	runner.check(position(sim).distance_to(Vector2(1.5, 1.5 + 4.0 / 90.0)) <= 1e-5, "M3 final order first ramp step")
	return true

func test_retarget(runner) -> bool:
	var sim = Simulation.new()
	sim.spawn(1, Vector2(1.5, 1.5))
	order(sim, Vector2(4.5, 1.5))
	advance(sim, 3)
	var before := position(sim)
	runner.check(order(sim, Vector2(1.5, 4.5), 1).ok, "M4 retarget accepted")
	runner.check(position(sim) == before, "M4 submission does not teleport")
	for i in range(100):
		sim.snapshot()
		runner.check(position(sim) == before, "M4 snapshot does not move")
		sim.step()
		var after := position(sim)
		runner.check(before.distance_to(after) <= 0.1 + 1e-5, "M4 bounded travel")
		before = after
	arrived(runner, sim, Vector2(1.5, 4.5), "M4 arrival")
	return true

func test_obstacle(runner) -> bool:
	var solids: Array[Vector2i] = [Vector2i(2, 1)]
	var sim = Simulation.new(solids)
	var nav = Navigation.new(solids)
	sim.spawn(1, Vector2(1.5, 1.5))
	runner.check(order(sim, Vector2(3.5, 1.5)).ok, "M5 accepted")
	for i in range(44):
		var before := position(sim)
		sim.step()
		var after := position(sim)
		runner.check(before.distance_to(after) <= 0.1 + 1e-5, "M5 budget")
		for sample in range(11):
			runner.check(nav.is_walkable(before.lerp(after, sample / 10.0)), "M5 sampled segment walkable")
	arrived(runner, sim, Vector2(3.5, 1.5), "M5 arrival 44")
	return true

func test_blocked(runner) -> bool:
	var wall: Array[Vector2i] = []
	for y in range(16):
		wall.append(Vector2i(3, y))
	var sim = Simulation.new(wall)
	sim.spawn(1, Vector2(1.5, 1.5))
	runner.check(order(sim, Vector2(5.5, 1.5)).ok, "M6 accepts unreachable walkable target")
	sim.step()
	var before: Dictionary = entity(sim)
	runner.check(before.position == [1.5, 1.5] and before.get("status") == "blocked" and before.order == null and before.get("route") == [], "M6 blocked and cleared")
	advance(sim, 300)
	runner.check(entity(sim) == before, "M6 persistent blocked")
	runner.check(order(sim, Vector2(1.5, 2.5), 1).ok, "M6 recovery order")
	advance(sim, 14)
	arrived(runner, sim, Vector2(1.5, 2.5), "M6 recovery")
	return true

func test_invalid(runner) -> bool:
	var sim = Simulation.new([Vector2i(2, 2)])
	for point in [Vector2(-0.01, 0), Vector2(16, 0), Vector2(2.5, 2.5)]:
		var before: Dictionary = sim.snapshot()
		runner.check(sim.spawn(1, point) == -1 and sim.snapshot() == before, "M7 invalid spawn no ID")
	runner.check(sim.spawn(1, Vector2(1.5, 1.5)) == 1, "M7 first valid ID")
	order(sim, Vector2(4.5, 1.5))
	advance(sim, 3)
	for target in [Vector2(2.5, 2.5), Vector2(16, 0), Vector2(-0.01, 0)]:
		var before: Dictionary = sim.snapshot()
		runner.check(not order(sim, target, 1).ok, "M7 invalid target rejected")
		runner.check(sim.snapshot() == before, "M7 route and sequence unchanged")
	advance(sim, 30)
	arrived(runner, sim, Vector2(4.5, 1.5), "M7 original continues")
	return true

func replay(batch: int, reads: bool = false):
	var sim = Simulation.new([Vector2i(2, 1)])
	sim.spawn(1, Vector2(1.5, 1.5))
	order(sim, Vector2(3.5, 1.5))
	order(sim, Vector2(1.5, 5.5), 1, 17)
	order(sim, Vector2(4.5, 4.5), 2, 68)
	for group in range(300 / batch):
		for tick in range(batch):
			if reads:
				var state: Dictionary = sim.snapshot()
				if not state.map.blocked_cells.is_empty():
					state.map.blocked_cells[0][0] = 9
				state.map.size[0] = 9
				if not state.entities[0].route.is_empty():
					state.entities[0].route[0][0] = 99
				state.entities[0].route.clear()
			sim.step()
	return sim

func test_replay(runner) -> bool:
	var expected: Dictionary = replay(1).snapshot()
	for batch in [1, 3, 10]:
		runner.check(replay(batch, true).snapshot() == expected, "M8 exact replay batch " + str(batch))
	arrived(runner, replay(10), Vector2(4.5, 4.5), "M8 final")
	return true

func test_far_coordinates(runner) -> bool:
	var sim = Simulation.new([], Vector2i(64, 64))
	sim.spawn(1, Vector2(51.5, 48.5))
	order(sim, Vector2(54.5, 48.5))
	advance(sim, 12)
	runner.check(absf(entity(sim).position[0] - (52.5 - 1.0 / 15.0)) <= 1e-5, "M9 far coordinate ten-tick distance")
	advance(sim, 22)
	arrived(runner, sim, Vector2(54.5, 48.5), "M9 far coordinate arrival")
	return true

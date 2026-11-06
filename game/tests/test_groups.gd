@warning_ignore_start("untyped_declaration")
extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Navigation = preload("res://scripts/simulation/grid_navigation.gd")
const Allocation = preload("res://scripts/simulation/destination_allocation.gd")

func cases() -> Array[Callable]:
	return [test_allocation, test_partial_and_copy, test_thirty_arrivals, test_reservations, test_replacement_release, test_partition, test_path_budget, test_queued_retarget, test_queue_replay, test_small_group_matches_brute_force]

func command(sim, ids: Array, target: Array, sequence: int = 0, player: int = 1, tick: int = -1) -> Dictionary:
	return {"tick": sim.snapshot().tick if tick < 0 else tick, "player": player, "sequence": sequence, "type": "move", "entity_ids": ids, "target": target}

func test_allocation(runner) -> bool:
	var nav = Navigation.new()
	var units: Array[Dictionary] = [
		{"id": 3, "position": [1.5, 3.5]}, {"id": 1, "position": [1.5, 1.5]}, {"id": 2, "position": [1.5, 2.5]},
	]
	var before: Array = units.duplicate(true)
	var expected := {1: Vector2(4.5, 4.5), 2: Vector2(4.5, 3.5), 3: Vector2(3.5, 4.5)}
	runner.check(Allocation.assign(nav, units, Vector2(4.5, 4.5), []) == expected, "G1 canonical slots")
	runner.check(units == before, "G1 input unchanged")
	units.reverse()
	runner.check(Allocation.assign(nav, units, Vector2(4.5, 4.5), []) == expected, "G1 input order independent")
	var single: Array[Dictionary] = [{"id": 1, "position": [1.5, 1.5]}]
	runner.check(Allocation.assign(nav, single, Vector2(4, 4.2), []) == {1: Vector2(4, 4.2)}, "G1 exact boundary target")
	return true

func test_partial_and_copy(runner) -> bool:
	var nav = Navigation.new([], Vector2i(2, 1))
	var units: Array[Dictionary] = [{"id": 2, "position": [0.5, 0.5]}, {"id": 1, "position": [0.5, 0.5]}]
	var goals: Dictionary = Allocation.assign(nav, units, Vector2(1.5, 0.5), [])
	runner.check(goals == {1: Vector2(1.5, 0.5), 2: null}, "G2 insufficient slots with transit overlap")
	var unavailable: Array[Vector2i] = [Vector2i(1, 0)]
	var before: Array[Vector2i] = unavailable.duplicate()
	runner.check(Allocation.assign(nav, units, Vector2(1.5, 0.5), unavailable) == {1: null, 2: null}, "G2 finite exhausted search")
	runner.check(unavailable == before, "G2 unavailable unchanged")
	nav = Navigation.new()
	units = [{"id": 1, "position": [1.5, 1.5]}, {"id": 2, "position": [4.5, 4.5]}]
	goals = Allocation.assign(nav, units, Vector2(4.5, 4.5), [])
	runner.check(goals.get(1) != Vector2(4.5, 4.5) and goals.get(2) == Vector2(4.5, 4.5), "G2 other unit cell excluded, own cell allowed")
	units = [{"id": 1, "position": [1.5, 1.5]}]
	var edge: Dictionary = Allocation.assign(nav, units, Vector2.ZERO, [])
	runner.check(edge == {1: Vector2.ZERO}, "G2 edge target")
	return true

func _thirty(blocked: Array[Vector2i]) -> Simulation:
	var sim = Simulation.new(blocked)
	for y in range(6):
		for x in range(5):
			sim.spawn(1, Vector2(x + 0.5, y + 0.5))
	return sim

func test_thirty_arrivals(runner) -> bool:
	for rectangle in [false, true]:
		var blocked: Array[Vector2i] = []
		if rectangle:
			for y in range(4, 10):
				for x in range(6, 9):
					blocked.append(Vector2i(x, y))
		var a = _thirty(blocked)
		var b = _thirty(blocked)
		var nav = Navigation.new(blocked)
		var ids: Array = range(1, 31)
		for sim in [a, b]:
			runner.check(sim.issue_command(command(sim, ids, [13.5, 12.5])).ok, "G3 group accepted")
		var all_arrived := false
		for tick in range(1800):
			var before: Dictionary = a.snapshot()
			a.step()
			b.step()
			var state: Dictionary = a.snapshot()
			runner.check(state == b.snapshot(), "G3 exact replay tick %d" % tick)
			all_arrived = true
			var slots: Dictionary = {}
			for i in range(30):
				var unit: Dictionary = state.entities[i]
				var old: Array = before.entities[i].position
				var start := Vector2(old[0], old[1])
				var finish := Vector2(unit.position[0], unit.position[1])
				for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
					runner.check(nav.is_walkable(start.lerp(finish, fraction)), "G3 no static-solid crossing")
				all_arrived = all_arrived and unit.get("status") == "arrived"
				if unit.get("destination") != null:
					var destination := Vector2(unit.destination[0], unit.destination[1])
					runner.check(not slots.has(Vector2i(destination.floor())), "G3 unique reserved cells")
					slots[Vector2i(destination.floor())] = true
			if all_arrived:
				runner.check(slots.size() == 30, "G3 thirty distinct arrivals")
				break
		runner.check(all_arrived, "G3 arrives within 1800 ticks")
	return true

func test_reservations(runner) -> bool:
	var sim = Simulation.new()
	for entry in [[1, Vector2(1.5, 1.5)], [1, Vector2(1.5, 2.5)], [2, Vector2(2.5, 1.5)], [2, Vector2(2.5, 2.5)]]:
		sim.spawn(entry[0], entry[1])
	runner.check(sim.issue_command(command(sim, [1, 2], [6.5, 6.5])).ok, "G4 first group")
	runner.check(sim.issue_command(command(sim, [3, 4], [6.5, 6.5], 0, 2)).ok, "G4 other owner group")
	sim.step()
	var state: Dictionary = sim.snapshot()
	var slots: Dictionary = {}
	for unit in state.entities:
		if unit.get("destination") != null:
			var cell := Vector2i(Vector2(unit.destination[0], unit.destination[1]).floor())
			runner.check(not slots.has(cell), "G4 cross-owner unique slots")
			slots[cell] = true
	runner.check(slots.size() == 4, "G4 all slots allocated")
	var before: Dictionary = sim.snapshot()
	runner.check(sim.spawn(1, Vector2(6.5, 6.5)) == -1 and sim.snapshot() == before, "G4 reserved spawn rejects without ID")
	var occupied: Array = state.entities[0].position
	runner.check(sim.spawn(1, Vector2(occupied[0], occupied[1])) == -1 and sim.snapshot() == before, "G4 occupied spawn rejects without ID")
	if state.entities[0].get("destination") != null:
		state.entities[0].destination[0] = 99
	runner.check(sim.snapshot() == before, "G4 destination snapshot isolated")
	return true

func test_replacement_release(runner) -> bool:
	var sim = Simulation.new()
	sim.spawn(1, Vector2(1.5, 1.5))
	sim.spawn(1, Vector2(1.5, 2.5))
	sim.issue_command(command(sim, [1, 2], [7.5, 7.5]))
	sim.issue_command(command(sim, [1], [12.5, 12.5], 1))
	sim.step()
	var state: Dictionary = sim.snapshot()
	runner.check(state.entities[0].get("destination") == [12.5, 12.5] and state.entities[1].get("destination") == [7.5, 7.5], "G5 superseded member consumes no old slot")
	sim.issue_command(command(sim, [1], [10.5, 10.5], 2, 1, 3))
	for i in range(2):
		sim.step()
	runner.check(sim.spawn(1, Vector2(12.5, 12.5)) == -1, "G5 future order retains reservation until due")
	sim.step()
	runner.check(sim.spawn(1, Vector2(12.5, 12.5)) == 3, "G5 applied replacement releases old reservation")
	return true

func test_partition(runner) -> bool:
	var wall: Array[Vector2i] = []
	for y in range(16):
		wall.append(Vector2i(3, y))
	var sim = Simulation.new(wall)
	sim.spawn(1, Vector2(1.5, 1.5))
	sim.spawn(1, Vector2(5.5, 1.5))
	runner.check(sim.issue_command(command(sim, [1, 2], [6.5, 5.5])).ok, "G6 partition command accepted")
	sim.step()
	var state: Dictionary = sim.snapshot()
	runner.check(state.entities[0].status == "blocked" and state.entities[0].order == null and state.entities[0].get("destination") == null and state.entities[0].route == [], "G6 unreachable member cleared")
	runner.check(state.entities[1].status == "moving" and state.entities[1].get("destination") == [6.5, 5.5], "G6 eligible member moves")
	return true

class CountingNavigation:
	extends "res://scripts/simulation/grid_navigation.gd"
	var calls: int = 0
	func route(from: Vector2, to: Vector2) -> Array[Vector2]:
		calls += 1
		return super.route(from, to)

func _twenty(blocked: Array[Vector2i] = []) -> Simulation:
	var sim = Simulation.new(blocked)
	for y in range(1, 5):
		for x in range(1, 6):
			sim._entities[sim.spawn(1, Vector2(x + 0.5, y + 0.5))].combat = null
	sim.issue_command(command(sim, range(1, 21), [13.5, 13.5]))
	return sim

func test_path_budget(runner) -> bool:
	var sim = _twenty()
	var nav := CountingNavigation.new()
	sim._navigation = nav
	for phase in range(3):
		nav.calls = 0
		var before: Dictionary = sim.snapshot()
		sim.step()
		var state: Dictionary = sim.snapshot()
		var expected: Array = range(9 + phase * 8, 21) if phase < 2 else []
		runner.check(state.get("path_queue") == expected, "G7 FIFO remaining queue phase %d" % phase)
		runner.check(nav.calls == (8 if phase < 2 else 4), "G7 query budget phase %d" % phase)
		for i in range(20):
			var unit: Dictionary = state.entities[i]
			if i >= (phase + 1) * 8:
				runner.check(unit.status == "path_pending" and unit.route == [] and unit.position == before.entities[i].position, "G7 waiting stays still")
			else:
				var old: Array = before.entities[i].position
				var distance: float = Vector2(unit.position[0], unit.position[1]).distance_to(Vector2(old[0], old[1]))
				runner.check(unit.status == "moving" and distance <= 0.1 + 1e-5, "G7 serviced/new movers stay within one budget")
	var wall: Array[Vector2i] = []
	for y in range(16):
		wall.append(Vector2i(8, y))
	sim = _twenty(wall)
	nav = CountingNavigation.new(wall)
	sim._navigation = nav
	sim.step()
	var blocked: Array = sim.snapshot().entities
	for i in range(300):
		sim.step()
	runner.check(nav.calls == 0 and sim.snapshot().entities == blocked and sim.snapshot().get("path_queue") == [], "G7 unreachable allocations never search/retry")
	return true

func test_queued_retarget(runner) -> bool:
	var sim = _twenty()
	sim.step()
	runner.check(sim.issue_command(command(sim, [9], [2.1, 13.2], 1)).ok, "G8 queued replacement")
	runner.check(sim.issue_command(command(sim, [9], [4.3, 12.7], 2)).ok, "G8 final replacement")
	var before: Dictionary = sim.snapshot()
	runner.check(not sim.issue_command(command(sim, [9], [16, 0], 3)).ok and sim.snapshot() == before, "G8 invalid replacement preserves queue/sequence")
	sim.step()
	var state: Dictionary = sim.snapshot()
	runner.check(state.get("path_queue") == [18, 19, 20, 9], "G8 stale queue entry removed, final appended once")
	runner.check(state.entities[8].status == "path_pending" and state.entities[8].route == [], "G8 replaced queued unit still waits")
	if not state.get("path_queue", []).is_empty():
		state.path_queue[0] = 999
		state.path_queue.clear()
	runner.check(sim.snapshot().get("path_queue") == [18, 19, 20, 9], "G8 queue snapshot isolated")
	sim.issue_command(command(sim, [1], [3.5, 13.5], 3))
	sim.step()
	state = sim.snapshot()
	runner.check(state.entities[8].status == "moving" and state.entities[19].status == "moving", "G8 low-ID repeated orders do not starve older requests")
	runner.check(state.entities[8].order.target == [4.3, 12.7], "G8 current final order routed")
	return true

func _queue_replay(batch: int, reads: bool):
	var sim = _twenty()
	sim.issue_command(command(sim, [9], [4.3, 12.7], 1, 1, 1))
	for base in range(0, 300, batch):
		for tick in range(batch):
			if reads:
				var state: Dictionary = sim.snapshot()
				state.path_queue.clear()
			sim.step()
	return sim.snapshot()

func test_queue_replay(runner) -> bool:
	var expected: Dictionary = _queue_replay(1, false)
	for batch in [1, 3, 10]:
		runner.check(_queue_replay(batch, true) == expected, "G9 exact queue replay batch %d" % batch)
	return true

func test_small_group_matches_brute_force(runner) -> bool:
	var nav = Navigation.new([Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6)], Vector2i(12, 12))
	var target := Vector2(8.5, 8.5)
	var unavailable: Array[Vector2i] = [Vector2i(7, 7), Vector2i(9, 9), Vector2i(8, 7)]
	var ok: bool = true
	for size in [1, 2, 3, 5, 8]:
		var units: Array[Dictionary] = []
		for i in range(size):
			units.append({"id": 10 - i, "position": [8.5, 8.5] if i == 1 else [4.5 + (i % 3), 7.5 + (i % 2)]})
		var expected: Dictionary = {}
		var taken: Dictionary = {}
		var ordered: Array[Dictionary] = units.duplicate()
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
		for unit in ordered:
			var best: Variant = null
			for cell in nav.cells_in_component(nav.component_at(target)):
				if taken.has(cell) or unavailable.has(cell): continue
				var own: bool = Vector2i(Vector2(unit.position[0], unit.position[1]).floor()) == cell
				var held: bool = false
				for other in units:
					if other.id != unit.id and Vector2i(Vector2(other.position[0], other.position[1]).floor()) == cell: held = true
				if held and not own: continue
				if best == null or _closer(cell, best, target): best = cell
			expected[unit.id] = Vector2(best) + Vector2(0.5, 0.5) if best != null else null
			if best != null: taken[best] = true
		ok = ok and Allocation.assign(nav, units, target, unavailable) == expected
	runner.check(ok, "G6 small groups equal the brute-force nearest-free-cell assignment")
	return true

func _closer(a: Vector2i, b: Vector2i, target: Vector2) -> bool:
	var da: float = (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(target)
	var db: float = (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(target)
	if da != db: return da < db
	return a.y < b.y or (a.y == b.y and a.x < b.x)

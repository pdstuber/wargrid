extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")

static func create(layout: String) -> Simulation:
	assert(layout == "open" or layout == "dense" or layout == "contact" or layout == "skirmish3v3" or layout == "transports")
	if layout == "skirmish3v3": return _skirmish3v3()
	if layout == "transports": return _transports()
	var solids: Array[Vector2i] = []
	if layout == "dense":
		for x: int in [26, 34, 42]:
			for y in range(64):
				if not (y >= 20 and y <= 27 or y >= 44 and y <= 51):
					solids.append(Vector2i(x, y))
	var sim: Simulation = Simulation.new(solids, Vector2i(64, 64))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	var contact: bool = layout == "contact"
	var columns: int = 3 if contact else 15
	var left_front: int = 31 if contact else 18
	var right_front: int = 33 if contact else 45
	var top: int = 7 if contact else 20
	_block(sim, 1, left_front, -1, columns, top, contact)
	_block(sim, 2, right_front, 1, columns, top, contact)
	if layout != "contact":
		for player: int in [1, 2]:
			var ids: Array[int] = []
			for unit: Dictionary in sim.snapshot().entities:
				if unit.owner == player: ids.append(unit.id)
			var target: Array = [52.5, 24.5] if player == 1 else [11.5, 24.5]
			var result: Dictionary = sim.issue_command({"tick": 0, "player": player, "sequence": 0, "type": "attack_move", "entity_ids": ids, "target": target})
			assert(result.ok, result.error)
	return sim

static func _block(sim: Simulation, player: int, front_x: int, direction: int, columns: int, top: int, interleave: bool) -> void:
	@warning_ignore("integer_division")
	var rows: int = 150 / columns
	var placed: int = 0
	for column in range(columns):
		for row in range(rows):
			var tank: bool = placed % 3 == 0 if interleave else placed < 50
			var id: int = sim.spawn(player, Vector2(front_x + direction * column + 0.5, top + row + 0.5), "usa_tank" if tank else "usa_rifle_infantry")
			assert(id > 0)
			placed += 1

# 20 scout cars with 5 riflemen each march on a block of 100 riflemen; contact comes after the warm-up, so passenger fire lands in the timed window.
static func _transports() -> Simulation:
	var sim: Simulation = Simulation.new([], Vector2i(64, 64))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	var cars: Array[int] = []
	for index in range(20):
		var car_position := Vector2(3.5, 4.5 + 3 * index)
		var car: int = sim.spawn(1, car_position, "usa_light_vehicle")
		assert(car > 0)
		cars.append(car)
		var riders: Array[int] = []
		for offset: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(0.9, 0.9)]:
			riders.append(sim.spawn(1, car_position + offset, "usa_rifle_infantry"))
		var entered: Dictionary = sim.issue_command({"tick": 0, "player": 1, "sequence": index, "type": "enter", "entity_ids": riders, "target_id": car})
		assert(entered.ok, entered.error)
	for column in range(10):
		for row in range(10):
			assert(sim.spawn(2, Vector2(48.5 + column, 19.5 + row), "usa_rifle_infantry") > 0)
	sim.step()
	var marched: Dictionary = sim.issue_command({"tick": sim.tick(), "player": 1, "sequence": 20, "type": "attack_move", "entity_ids": cars, "target": [60.5, 24.5]})
	assert(marched.ok, marched.error)
	return sim

# Three staggered lanes, 35 units per owner per lane (12 tanks); the last 9 of each group stay idle behind.
static func _skirmish3v3() -> Simulation:
	var sim: Simulation = Simulation.new([], Vector2i(64, 64))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	var lanes := [[10, 28], [30, 40], [50, 16]]
	for index in range(3):
		var lane: Array = lanes[index]
		for player: int in [1, 2]:
			var direction: int = -1 if player == 1 else 1
			var front: int = 32 + direction * (lane[1] / 2)
			var ids: Array[int] = []
			for placed in range(35):
				var kind: String = "usa_tank" if placed % 3 == 0 else "usa_rifle_infantry"
				@warning_ignore("integer_division")
				var position := Vector2(front + direction * (placed / 5) + 0.5, lane[0] - 2 + placed % 5 + 0.5)
				var id: int = sim.spawn(player, position, kind)
				assert(id > 0)
				if placed < 26: ids.append(id)
			var target: Array = [58.5 if player == 1 else 5.5, lane[0] + 0.5]
			var result: Dictionary = sim.issue_command({"tick": 0, "player": player, "sequence": index, "type": "attack_move", "entity_ids": ids, "target": target})
			assert(result.ok, result.error)
	return sim

# Profiling-only M6-scale probe: 196x196 with 8x8 mesas every 20 cells (10.5 % blocked), 3 lanes x 60 units per owner.
const LARGE := Vector2i(196, 196)

static func create_large() -> Simulation:
	var solids: Array[Vector2i] = []
	for top in range(10, 186, 20):
		for left in range(30, 166, 20):
			for y in range(top, top + 8):
				for x in range(left, left + 8): solids.append(Vector2i(x, y))
	var sim: Simulation = Simulation.new(solids, LARGE)
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	var lanes := [38, 98, 158]
	for index in range(lanes.size()):
		for player: int in [1, 2]:
			var front: int = 14 if player == 1 else 181
			var direction: int = -1 if player == 1 else 1
			var ids: Array[int] = []
			for placed in range(60):
				@warning_ignore("integer_division")
				var position := Vector2(front + direction * (placed / 6) + 0.5, lanes[index] - 3 + placed % 6 + 0.5)
				var id: int = sim.spawn(player, position, "usa_tank" if placed % 3 == 0 else "usa_rifle_infantry")
				assert(id > 0)
				ids.append(id)
			var target: Array = [190.5 if player == 1 else 5.5, lanes[index] + 0.5]
			var result: Dictionary = sim.issue_command({"tick": 0, "player": player, "sequence": index, "type": "attack_move", "entity_ids": ids, "target": target})
			assert(result.ok, result.error)
	return sim

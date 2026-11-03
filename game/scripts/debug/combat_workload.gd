extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")

static func create(layout: String) -> RefCounted:
	assert(layout == "open" or layout == "dense" or layout == "contact")
	var solids: Array[Vector2i] = []
	if layout == "dense":
		for x in [26, 34, 42]:
			for y in range(64):
				if not (y >= 20 and y <= 27 or y >= 44 and y <= 51):
					solids.append(Vector2i(x, y))
	var sim = Simulation.new(solids, Vector2i(64, 64))
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
		for player in [1, 2]:
			var ids: Array[int] = []
			for unit in sim.snapshot().entities:
				if unit.owner == player: ids.append(unit.id)
			var target: Array = [52.5, 24.5] if player == 1 else [11.5, 24.5]
			var result: Dictionary = sim.issue_command({"tick": 0, "player": player, "sequence": 0, "type": "attack_move", "entity_ids": ids, "target": target})
			assert(result.ok, result.error)
	return sim

static func _block(sim: RefCounted, player: int, front_x: int, direction: int, columns: int, top: int, interleave: bool) -> void:
	var rows: int = 150 / columns
	var placed: int = 0
	for column in range(columns):
		for row in range(rows):
			var tank: bool = placed % 3 == 0 if interleave else placed < 50
			var id: int = sim.spawn(player, Vector2(front_x + direction * column + 0.5, top + row + 0.5), "tank" if tank else "infantry")
			assert(id > 0)
			placed += 1

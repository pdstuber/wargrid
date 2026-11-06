extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")

static func create(layout: String) -> Simulation:
	assert(layout == "open" or layout == "dense")
	var solids: Array[Vector2i] = []
	if layout == "dense":
		for x: int in [26, 34, 42]:
			for y in range(64):
				if not (y >= 20 and y <= 27 or y >= 44 and y <= 51):
					solids.append(Vector2i(x, y))
	var sim: Simulation = Simulation.new(solids, Vector2i(64, 64))
	for y in range(2, 17):
		for x in range(2, 22):
			var id: int = sim.spawn(1, Vector2(x + 0.5, y + 0.5))
			assert(id > 0)
	return sim

static func issue_leg(sim: Simulation, leg: int) -> void:
	if leg > 0 and not settled(sim):
		return
	var state: Dictionary = sim.snapshot()
	var ids: Array[int] = []
	for unit: Dictionary in state.entities:
		ids.append(unit.id)
	var target := Vector2(52.5, 48.5) if leg % 2 == 0 else Vector2(11.5, 9.5)
	var result: Dictionary = sim.issue_command({"tick": state.tick, "player": 1, "sequence": leg,
		"type": "move", "entity_ids": ids, "target": [target.x, target.y]})
	assert(result.ok, result.error)

static func settled(sim: Simulation) -> bool:
	var state: Dictionary = sim.snapshot()
	if state.entities.is_empty() or not state.pending_commands.is_empty():
		return false
	for unit: Dictionary in state.entities:
		if unit.status != "arrived":
			return false
	return true

extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const ASHFALL_PATH := "res://data/maps/ashfall.json"
const ASHFALL_BASE: Array[String] = ["usa_power_plant", "usa_supply_center", "usa_barracks", "usa_factory", "usa_command_center", "usa_defence"]
const ANCHORS: Array[Vector2] = [Vector2(52.5, 48.5), Vector2(11.5, 9.5)]
const ASHFALL_ANCHORS: Array[Vector2] = [Vector2(41.5, 136.5), Vector2(11.5, 111.5)]

static func create(layout: String) -> Simulation:
	assert(layout == "open" or layout == "dense" or layout == "ashfall")
	if layout == "ashfall": return _ashfall()
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
			sim._entities[id].combat = null
	return sim

# The full-scale map: seat 1's six base buildings plus 300 move-only units in the open ground north of it.
static func _ashfall() -> Simulation:
	var map: Dictionary = MapData.load(ASHFALL_PATH)
	var sim: Simulation = MapData.create(map, [])
	for kind: String in ASHFALL_BASE:
		CombatWorkload._building(sim, kind, MapData.slot(map, 1, kind))
	for y in range(107, 122):
		for x in range(4, 24):
			var id: int = sim.spawn(1, Vector2(x + 0.5, y + 0.5))
			assert(id > 0)
			sim._entities[id].combat = null
	return sim

static func issue_leg(sim: Simulation, leg: int, anchors: Array[Vector2] = ANCHORS) -> void:
	if leg > 0 and not settled(sim):
		return
	var state: Dictionary = sim.snapshot()
	var ids: Array[int] = []
	for unit: Dictionary in state.entities:
		ids.append(unit.id)
	var target: Vector2 = anchors[leg % 2]
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

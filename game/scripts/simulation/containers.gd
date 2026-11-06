extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const BOARD_GAP: float = 0.5
const EXIT_SEARCH: int = 4
const CANNOT_ENTER: String = "Cannot enter this container"

static func rules(unit: Dictionary) -> Dictionary:
	return Registry.kind(unit.kind).get("contains", {})

static func entering(unit: Dictionary) -> bool:
	return unit.order != null and unit.order.type == "enter"

static func enter_error(sim: Simulation, command: Dictionary, live: Array) -> String:
	var carrier: Dictionary = sim._entities.get(command.target_id, {})
	if carrier.is_empty() or carrier.owner != command.player or rules(carrier).is_empty(): return CANNOT_ENTER
	for id: Variant in live:
		var role: String = Registry.kind(sim._entities[id].kind)["class"]
		if id == carrier.id or role == "air" or not rules(carrier).accepts.has(role): return CANNOT_ENTER
	return "" if _free_slots(sim, carrier) > 0 else "Container is full"

static func unload_error(sim: Simulation, command: Dictionary) -> String:
	var carrier: Dictionary = sim._entities.get(command.target_id, {})
	return "" if not carrier.is_empty() and carrier.owner == command.player and not rules(carrier).is_empty() else "Cannot unload this container"

static func _free_slots(sim: Simulation, carrier: Dictionary) -> int:
	var promised: int = 0
	for unit: Dictionary in sim._entities.values():
		if entering(unit) and unit.order.target_id == carrier.id: promised += 1
	return rules(carrier).slots - carrier.get("passengers", []).size() - promised

static func head_for(sim: Simulation, unit: Dictionary, carrier: Dictionary) -> void:
	unit.destination = carrier.position.duplicate()
	unit.order = {"type": "enter", "target": carrier.position.duplicate(), "target_id": carrier.id}
	unit.route = []
	unit.status = "path_pending"
	sim._path_queue.append(unit.id)
	sim._set_intent(unit, "move")

# Right after the advance loop: passengers follow their container, then arrivals board in id order.
static func step(sim: Simulation) -> void:
	var walkers: Array[int] = []
	for unit: Dictionary in sim._entities.values():
		if unit.has("passengers"):
			for id: int in unit.passengers: sim._entities[id].position = unit.position.duplicate()
		if entering(unit): walkers.append(unit.id)
	walkers.sort()
	for id in walkers: _walk(sim, sim._entities[id])

static func _walk(sim: Simulation, unit: Dictionary) -> void:
	var carrier: Dictionary = sim._entities.get(unit.order.target_id, {})
	if carrier.is_empty():
		_give_up(sim, unit)
	elif Combat.edge_gap(unit, carrier) <= BOARD_GAP + Combat.EDGE_EPS:
		if carrier.get("passengers", []).size() < rules(carrier).slots: _board(sim, unit, carrier)
		else: _give_up(sim, unit)
	elif unit.status == "arrived":
		head_for(sim, unit, carrier)
	elif unit.status != "moving" and unit.status != "path_pending":
		_give_up(sim, unit)

static func _give_up(sim: Simulation, unit: Dictionary) -> void:
	sim._stop_unit(unit)
	sim._set_intent(unit, "guard")

static func _board(sim: Simulation, unit: Dictionary, carrier: Dictionary) -> void:
	sim._stop_unit(unit)
	unit.container_id = carrier.id
	unit.status = "contained"
	unit.position = carrier.position.duplicate()
	unit.speed = 0.0
	carrier.get_or_add("passengers", []).append(unit.id)
	sim._set_intent(unit, "guard")
	Combat.object_removed(sim, unit.id)

static func unload(sim: Simulation, container_id: int) -> void:
	var carrier: Dictionary = sim._entities[container_id]
	var ids: Array = carrier.get("passengers", []).duplicate()
	carrier.erase("passengers")
	_exit_all(sim, carrier, ids)

static func _exit_all(sim: Simulation, carrier: Dictionary, ids: Array) -> void:
	var taken: Dictionary = sim.occupied_cells()
	ids.sort()
	for id: int in ids:
		var unit: Dictionary = sim._entities[id]
		unit.erase("container_id")
		unit.position = _free_cell(sim, carrier, taken)
		unit.status = "arrived"
		sim._set_intent(unit, "guard")

# Nearest walkable unoccupied cell to the container, ties by row then column; falls back to the container's own spot.
static func _free_cell(sim: Simulation, carrier: Dictionary, taken: Dictionary) -> Array:
	var centre := Vector2(carrier.position[0], carrier.position[1])
	var base := Vector2i(centre.floor())
	var best: Variant = null
	var best_distance: float = INF
	for dy in range(-EXIT_SEARCH, EXIT_SEARCH + 1):
		for dx in range(-EXIT_SEARCH, EXIT_SEARCH + 1):
			var cell: Vector2i = base + Vector2i(dx, dy)
			var point := Vector2(cell) + Vector2(0.5, 0.5)
			if taken.has(cell) or not sim._in_bounds(point) or not sim._navigation.is_walkable(point): continue
			if point.distance_squared_to(centre) < best_distance:
				best = point
				best_distance = point.distance_squared_to(centre)
	if best == null: return carrier.position.duplicate()
	taken[Vector2i(best.floor())] = true
	return [best.x, best.y]

# Called before the object leaves the entity table.
static func object_removed(sim: Simulation, id: int) -> void:
	var unit: Dictionary = sim._entities[id]
	if unit.has("container_id"): _leave(sim, unit)
	if not rules(unit).is_empty(): _release(sim, unit)

static func _leave(sim: Simulation, unit: Dictionary) -> void:
	var carrier: Dictionary = sim._entities.get(unit.container_id, {})
	if carrier.has("passengers"):
		carrier.passengers.erase(unit.id)
		if carrier.passengers.is_empty(): carrier.erase("passengers")

static func _release(sim: Simulation, carrier: Dictionary) -> void:
	for other: Dictionary in sim._entities.values():
		if entering(other) and other.order.target_id == carrier.id: _give_up(sim, other)
	var ids: Array = carrier.get("passengers", []).duplicate()
	carrier.erase("passengers")
	ids.sort()
	var survivors: Array = []
	for id: int in ids:
		var passenger: Dictionary = sim._entities[id]
		passenger.hp -= passenger.max_hp * rules(carrier).passenger_damage_percent / 100
		if passenger.hp > 0:
			survivors.append(id)
			continue
		sim._combat_events.append({"type": "death", "tick": sim._tick, "object_id": id})
		sim.remove_object(id)
	_exit_all(sim, carrier, survivors)

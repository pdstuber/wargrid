extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const BOARD_GAP: float = 0.5
const EXIT_SEARCH: int = 4
const CANNOT_ENTER: String = "Cannot enter this container"

static func rules(unit: Dictionary) -> Dictionary:
	return Registry.kind(unit.kind).get("contains", {})

static func carrier(sim: Simulation, id: int) -> Dictionary:
	if sim._entities.has(id): return sim._entities[id]
	return sim._buildings.get(id, {})

static func centre(host: Dictionary) -> Vector2:
	if not host.has("origin"): return Vector2(host.position[0], host.position[1])
	return Vector2(host.origin[0], host.origin[1]) + Vector2(Registry.kind(host.kind).footprint) / 2.0

static func shared(host: Dictionary) -> bool:
	return rules(host).get("shared", false)

static func tunnel(sim: Simulation, owner: int) -> Array:
	return sim._players[owner].get("tunnel", [])

static func entering(unit: Dictionary) -> bool:
	return unit.order != null and unit.order.type == "enter"

static func enter_error(sim: Simulation, command: Dictionary, live: Array) -> String:
	var host: Dictionary = carrier(sim, command.target_id)
	if host.is_empty() or host.has("container_id") or host.owner != command.player or rules(host).is_empty() or not host.get("completed", true): return CANNOT_ENTER
	for id: Variant in live:
		var role: String = Registry.kind(sim._entities[id].kind)["class"]
		if id == host.id or role == "air" or not rules(host).accepts.has(role): return CANNOT_ENTER
	return "" if _free_slots(sim, host, live) > 0 else "Container is full"

static func unload_error(sim: Simulation, command: Dictionary) -> String:
	var host: Dictionary = carrier(sim, command.target_id)
	return "" if not host.is_empty() and not host.has("container_id") and host.owner == command.player and not rules(host).is_empty() and host.get("completed", true) else "Cannot unload this container"

static func _free_slots(sim: Simulation, host: Dictionary, reissued: Array) -> int:
	var promised: int = 0
	var network: bool = shared(host)
	for unit: Dictionary in sim._entities.values():
		if not entering(unit) or reissued.has(unit.id): continue
		if unit.order.target_id == host.id or (network and unit.owner == host.owner and shared(carrier(sim, unit.order.target_id))): promised += 1
	var held: int = tunnel(sim, host.owner).size() if network else host.get("passengers", []).size()
	return rules(host).slots - held - promised

static func head_for(sim: Simulation, unit: Dictionary, host: Dictionary) -> void:
	var goal: Variant = host.position.duplicate() if not host.has("origin") else Construction.approach(sim, unit.id, host.kind, Vector2i(host.origin[0], host.origin[1]), sim._navigation, true)
	if goal == null: return _give_up(sim, unit)
	unit.destination = goal
	unit.order = {"type": "enter", "target": goal.duplicate(), "target_id": host.id}
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
	for player: Dictionary in sim._players.values():
		if player.has("tunnel"): _heal(sim, player)

static func _heal(sim: Simulation, player: Dictionary) -> void:
	var hub: Dictionary = _first_hub(sim, player.id, -1)
	var ticks: int = rules(hub).heal_ticks
	for id: int in player.tunnel:
		var unit: Dictionary = sim._entities[id]
		@warning_ignore("integer_division")
		unit.hp = mini(unit.max_hp, unit.hp + (unit.max_hp + ticks - 1) / ticks)

static func _first_hub(sim: Simulation, owner: int, skipped: int) -> Dictionary:
	var ids: Array = sim._buildings.keys()
	ids.sort()
	for id: int in ids:
		var building: Dictionary = sim._buildings[id]
		if id != skipped and building.owner == owner and building.completed and shared(building): return building
	return {}

static func _walk(sim: Simulation, unit: Dictionary) -> void:
	var host: Dictionary = carrier(sim, unit.order.target_id)
	if host.is_empty():
		_give_up(sim, unit)
	elif Combat.edge_gap(unit, host) <= BOARD_GAP + Combat.EDGE_EPS:
		var held: int = tunnel(sim, host.owner).size() if shared(host) else host.get("passengers", []).size()
		if held < rules(host).slots: _board(sim, unit, host)
		else: _give_up(sim, unit)
	elif unit.status == "arrived":
		head_for(sim, unit, host)
	elif unit.status != "moving" and unit.status != "path_pending":
		_give_up(sim, unit)

static func _give_up(sim: Simulation, unit: Dictionary) -> void:
	sim._stop_unit(unit)
	sim._set_intent(unit, "guard")

static func _board(sim: Simulation, unit: Dictionary, host: Dictionary) -> void:
	sim._stop_unit(unit)
	unit.container_id = host.id
	unit.status = "contained"
	var at: Vector2 = centre(host)
	unit.position = [at.x, at.y]
	unit.speed = 0.0
	var passengers: Array = sim._players[host.owner].get_or_add("tunnel", []) if shared(host) else host.get_or_add("passengers", [])
	passengers.insert(passengers.bsearch(unit.id), unit.id)
	sim._set_intent(unit, "guard")
	Combat.object_removed(sim, unit.id)

static func unload(sim: Simulation, container_id: int) -> void:
	var host: Dictionary = carrier(sim, container_id)
	var ids: Array
	if shared(host):
		ids = tunnel(sim, host.owner).duplicate()
		sim._players[host.owner].erase("tunnel")
	else:
		ids = host.get("passengers", []).duplicate()
		host.erase("passengers")
	_exit_all(sim, host, ids)

static func _exit_all(sim: Simulation, host: Dictionary, ids: Array) -> void:
	var taken: Dictionary = sim.occupied_cells()
	ids.sort()
	for id: int in ids:
		var unit: Dictionary = sim._entities[id]
		unit.erase("container_id")
		unit.position = _free_cell(sim, host, taken)
		unit.status = "arrived"
		sim._set_intent(unit, "guard")

# Nearest walkable unoccupied cell to the container, ties by row then column; falls back to the container's own spot.
static func _free_cell(sim: Simulation, host: Dictionary, taken: Dictionary) -> Array:
	var middle: Vector2 = centre(host)
	var base := Vector2i(middle.floor())
	var best: Variant = null
	var best_distance: float = INF
	for dy in range(-EXIT_SEARCH, EXIT_SEARCH + 1):
		for dx in range(-EXIT_SEARCH, EXIT_SEARCH + 1):
			var cell: Vector2i = base + Vector2i(dx, dy)
			var point := Vector2(cell) + Vector2(0.5, 0.5)
			if taken.has(cell) or not sim._in_bounds(point) or not sim._navigation.is_walkable(point): continue
			if point.distance_squared_to(middle) < best_distance:
				best = point
				best_distance = point.distance_squared_to(middle)
	if best == null: return [middle.x, middle.y]
	taken[Vector2i(best.floor())] = true
	return [best.x, best.y]

# Called before the object leaves the entity table.
static func object_removed(sim: Simulation, id: int) -> void:
	var unit: Dictionary = sim._entities[id]
	if unit.has("container_id"): _leave(sim, unit)
	if not rules(unit).is_empty(): _release(sim, unit)

static func _leave(sim: Simulation, unit: Dictionary) -> void:
	var host: Dictionary = carrier(sim, unit.container_id)
	if host.is_empty(): return
	var holder: Dictionary = sim._players[host.owner] if shared(host) else host
	var key: String = "tunnel" if shared(host) else "passengers"
	if holder.has(key):
		holder[key].erase(unit.id)
		if holder[key].is_empty(): holder.erase(key)

static func _release(sim: Simulation, host: Dictionary) -> void:
	for other: Dictionary in sim._entities.values():
		if entering(other) and other.order.target_id == host.id: _give_up(sim, other)
	var ids: Array = host.get("passengers", []).duplicate()
	host.erase("passengers")
	ids.sort()
	var survivors: Array = []
	for id: int in ids:
		var passenger: Dictionary = sim._entities[id]
		passenger.hp -= passenger.max_hp * rules(host).passenger_damage_percent / 100
		if passenger.hp > 0:
			survivors.append(id)
			continue
		sim._combat_events.append({"type": "death", "tick": sim._tick, "object_id": id})
		sim.remove_object(id)
	_exit_all(sim, host, survivors)

# The hub is still in the building table when this runs.
static func building_removed(sim: Simulation, building: Dictionary) -> void:
	if not building.completed or not shared(building): return
	for other: Dictionary in sim._entities.values():
		if entering(other) and other.order.target_id == building.id: _give_up(sim, other)
	var next: Dictionary = _first_hub(sim, building.owner, building.id)
	if next.is_empty(): _bury(sim, building.owner)
	else: _relocate(sim, building, next)

static func _relocate(sim: Simulation, from: Dictionary, to: Dictionary) -> void:
	var at: Vector2 = centre(to)
	for id: int in tunnel(sim, from.owner):
		if sim._entities[id].container_id != from.id: continue
		sim._entities[id].container_id = to.id
		sim._entities[id].position = [at.x, at.y]

# Zero Hour destroys every occupant (TunnelTracker.cpp:211-247) and a destroyed transport its riders (OpenContain.cpp:843-852).
static func _bury(sim: Simulation, owner: int) -> void:
	var ids: Array = tunnel(sim, owner).duplicate()
	sim._players[owner].erase("tunnel")
	for id: int in ids:
		for rider: int in sim._entities[id].get("passengers", []).duplicate(): sim.remove_object(rider)
		sim.remove_object(id)

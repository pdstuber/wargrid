extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

static func release(sim: Simulation, unit_id: int) -> void:
	var unit: Dictionary = sim._entities[unit_id]
	var collection: Dictionary = unit.collection
	if collection.target_id != null:
		var target: Dictionary = sim._sources.get(collection.target_id,sim._buildings.get(collection.target_id,{}))
		if target.get("active_collector_id") == unit_id: target.active_collector_id = null
	collection.target_id = null
	collection.erase("dock")
	collection.remaining_ticks = 0
	collection.phase = "seeking" if collection.enabled else "idle"

static func center(target: Dictionary) -> Array:
	return [target.origin[0] + 1.5,target.origin[1] + 1.5]

static func _is_ground(unit: Dictionary) -> bool:
	return not Registry.air_kinds.has(unit.kind)

static func _arrival(unit: Dictionary, target: Dictionary) -> Array:
	var dock: Variant = unit.collection.get("dock")
	return center(target) if dock == null else [dock[0] + 0.5,dock[1] + 0.5]

# Footprint plus its one-cell ring, corners included, as the dock cells of a pile or depot.
static func _ring(target: Dictionary) -> Array[Vector2i]:
	var size: Vector2i = Registry.SOURCE_FOOTPRINT if target.has("boxes") else Registry.building_view(target.kind).footprint
	var origin := Vector2i(target.origin[0],target.origin[1])
	var cells: Array[Vector2i] = []
	for y in range(origin.y - 1,origin.y + size.y + 1):
		for x in range(origin.x - 1,origin.x + size.x + 1):
			if x < origin.x or x >= origin.x + size.x or y < origin.y or y >= origin.y + size.y: cells.append(Vector2i(x,y))
	return cells

static func _claim_dock(sim: Simulation, unit: Dictionary, target: Dictionary) -> bool:
	var held: Dictionary = {}
	for other: Dictionary in sim._entities.values():
		if other.collection != null and other.collection.get("dock") != null and other.collection.target_id == target.id: held[Vector2i(other.collection.dock[0],other.collection.dock[1])] = true
	var component: int = sim._navigation.component_at(Vector2(unit.position[0],unit.position[1]))
	var best := Vector2i(-1,-1)
	var best_distance: float = INF
	for cell: Vector2i in _ring(target):
		var centre := Vector2(cell) + Vector2(.5,.5)
		if held.has(cell) or not sim._navigation.is_walkable(centre) or sim._navigation.component_at(centre) != component: continue
		var distance: float = (cell.x + .5 - unit.position[0]) ** 2 + (cell.y + .5 - unit.position[1]) ** 2
		if distance < best_distance:
			best = cell
			best_distance = distance
	if best_distance == INF: return false
	unit.collection.dock = [best.x,best.y]
	return true

static func nearest(unit: Dictionary, targets: Array) -> Dictionary:
	targets.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var pa: Array = center(a)
		var pb: Array = center(b)
		var da: float = (pa[0] - unit.position[0]) ** 2 + (pa[1] - unit.position[1]) ** 2
		var db: float = (pb[0] - unit.position[0]) ** 2 + (pb[1] - unit.position[1]) ** 2
		return da < db if da != db else a.id < b.id
	)
	return {} if targets.is_empty() else targets[0]

static func choose_target(sim: Simulation, unit: Dictionary) -> Dictionary:
	var collection: Dictionary = unit.collection
	if collection.cargo > 0:
		var depots: Array = []
		for building: Dictionary in sim._buildings.values():
			if building.owner == unit.owner and Registry.kind(building.kind).receives_supply and building.completed: depots.append(building)
		return nearest(unit,depots)
	if collection.preferred_source_id != null and sim._sources.has(collection.preferred_source_id):
		var preferred: Dictionary = sim._sources[collection.preferred_source_id]
		if preferred.boxes > 0: return preferred
	var sources: Array = []
	for source: Dictionary in sim._sources.values():
		if source.boxes > 0: sources.append(source)
	return nearest(unit,sources)

static func _seek(sim: Simulation, unit: Dictionary) -> void:
	var collection: Dictionary = unit.collection
	var target: Dictionary = choose_target(sim,unit)
	if target.is_empty():
		collection.phase = "idle"
		collection.retry_tick = sim._tick + 30
		sim._stop_unit(unit)
		return
	if _is_ground(unit) and not _claim_dock(sim,unit,target):
		collection.phase = "idle"
		collection.retry_tick = sim._tick + 30
		sim._stop_unit(unit)
		return
	collection.target_id = target.id
	var goal: Array = _arrival(unit,target)
	collection.phase = "flying_depot" if collection.cargo > 0 else "flying_source"
	unit.destination = goal.duplicate()
	unit.order = {"type":"move","target":goal.duplicate()}
	if _is_ground(unit) and unit.position != goal:
		unit.route = []
		unit.status = "path_pending"
		sim._path_queue.append(unit.id)
	else:
		unit.route = [sim._frozen(goal.duplicate())]
		unit.status = "moving"
	if unit.position == goal: _admit(sim,unit,target)

static func _admit(sim: Simulation, unit: Dictionary, target: Dictionary) -> void:
	var collection: Dictionary = unit.collection
	var depot: bool = collection.cargo > 0
	if not depot and target.boxes == 0:
		release(sim,unit.id)
		sim._stop_unit(unit)
		collection.retry_tick = sim._tick + 1
		return
	var waiting_before: bool = false
	for other: Dictionary in sim._entities.values():
		if other.id >= unit.id or other.collection == null or not other.collection.enabled: continue
		if other.collection.target_id == target.id and other.position == _arrival(other,target) and other.collection.phase in ["flying_source","waiting_source","flying_depot","waiting_depot"]:
			waiting_before = true
			break
	if target.active_collector_id == null and not waiting_before:
		target.active_collector_id = unit.id
		collection.phase = "unloading" if depot else "loading"
		collection.remaining_ticks = Registry.collects(unit.kind).unload_ticks if depot else Registry.collects(unit.kind).load_ticks
	else:
		collection.phase = "waiting_depot" if depot else "waiting_source"
	sim._stop_unit(unit)

static func step(sim: Simulation, unit_ids: Array[int]) -> void:
	for id in unit_ids:
		if not sim._entities.has(id): continue
		var unit: Dictionary = sim._entities[id]
		if unit.collection == null or not unit.collection.enabled: continue
		var collection: Dictionary = unit.collection
		if collection.phase in ["seeking","idle"]:
			if sim._tick >= collection.retry_tick: _seek(sim,unit)
			continue
		var target: Dictionary = sim._sources.get(collection.target_id,sim._buildings.get(collection.target_id,{}))
		if target.is_empty():
			release(sim,id)
			sim._stop_unit(unit)
			collection.retry_tick = sim._tick + 1
			continue
		if collection.phase.begins_with("flying_") and _is_ground(unit) and unit.status == "blocked":
			release(sim,id)
			collection.retry_tick = sim._tick + 30
			continue
		if collection.phase.begins_with("flying_") or collection.phase.begins_with("waiting_"):
			if unit.position == _arrival(unit,target): _admit(sim,unit,target)
			continue
		var ground: bool = _is_ground(unit)
		if collection.phase == "loading" and not ground and target.boxes <= 0:
			release(sim,id)
			collection.retry_tick = sim._tick + 1
			continue
		collection.remaining_ticks -= 1
		if collection.remaining_ticks > 0: continue
		if collection.phase == "loading":
			# Zero Hour waits one more delay after the last box; the air collector keeps M3's early departure (open item in m7-verification.md).
			if ground and (collection.cargo == Registry.collects(unit.kind).boxes or target.boxes == 0):
				release(sim,id)
				collection.retry_tick = sim._tick + 1
				continue
			target.boxes -= 1
			collection.cargo += 1
			if not ground and (collection.cargo == Registry.collects(unit.kind).boxes or target.boxes == 0):
				release(sim,id)
				collection.retry_tick = sim._tick + 1
			else: collection.remaining_ticks = Registry.collects(unit.kind).load_ticks
		elif collection.phase == "unloading":
			sim._players[unit.owner].credits += collection.cargo * Registry.collects(unit.kind).box_value
			collection.cargo = 0
			release(sim,id)
			collection.retry_tick = sim._tick + 1

static func object_removed(sim: Simulation, id: int) -> void:
	for unit: Dictionary in sim._entities.values():
		if unit.collection == null or unit.collection.target_id != id: continue
		release(sim,unit.id)
		sim._stop_unit(unit)
		unit.collection.retry_tick = sim._tick + 1

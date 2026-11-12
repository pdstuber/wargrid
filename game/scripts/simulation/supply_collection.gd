extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const DockC = preload("res://scripts/experiments/dock_c.gd")
const DockQueueWork = preload("res://scripts/experiments/dock_queue_work.gd")
const DockQueue = preload("res://scripts/simulation/dock_queue.gd")

const DOCK_SHIFT := 0.25
const DOCK_MODELS := ["hold", "split", "queue", "c1", "c2"]

static func release(sim: Simulation, unit_id: int) -> void:
	var unit: Dictionary = sim._entities[unit_id]
	var collection: Dictionary = unit.collection
	var target: Dictionary = {}
	if collection.target_id != null:
		target = sim._sources.get(collection.target_id,sim._buildings.get(collection.target_id,{}))
		if target.get("active_collector_id") == unit_id: target.active_collector_id = null
	collection.target_id = null
	collection.erase("dock")
	collection.remaining_ticks = 0
	collection.phase = "seeking" if collection.enabled else "idle"
	if sim.dock_model == "queue": DockQueue.leave(sim,target,unit_id)

static func _size(target: Dictionary) -> Vector2i:
	return Registry.source_footprint(target) if target.has("boxes") else Registry.building_view(target.kind).footprint

static func center(target: Dictionary) -> Array:
	var size: Vector2i = _size(target)
	return [target.origin[0] + size.x / 2.0,target.origin[1] + size.y / 2.0]

static func _is_ground(unit: Dictionary) -> bool:
	return not Registry.air_kinds.has(unit.kind)

static func _arrival(unit: Dictionary, target: Dictionary) -> Array:
	var dock: Variant = unit.collection.get("dock")
	if dock == null: return center(target)
	var size: Vector2i = _size(target)
	var offset := Vector2i(_toward(dock[0],target.origin[0],size.x),_toward(dock[1],target.origin[1],size.y))
	# Distinct spots per target even when a pile and a depot share the dock cell (as the spots on a Zero Hour object differ).
	return [dock[0] + 0.5 + offset.x * DOCK_SHIFT,dock[1] + 0.5 + offset.y * DOCK_SHIFT]

static func _toward(cell: int, origin: int, length: int) -> int:
	return signi(clampi(cell,origin,origin + length - 1) - cell)

# Footprint plus its one-cell ring, corners included, as the dock cells of a pile or depot.
static func _ring(target: Dictionary) -> Array[Vector2i]:
	var size: Vector2i = _size(target)
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
	var goal: Array = DockQueue.approach(unit,target) if sim.dock_model == "queue" else _arrival(unit,target)
	collection.phase = "flying_depot" if collection.cargo > 0 else "flying_source"
	_move_to(sim,unit,goal)
	if unit.position == goal: _admit(sim,unit,target)

static func _move_to(sim: Simulation, unit: Dictionary, goal: Array) -> void:
	unit.destination = goal.duplicate()
	unit.order = {"type":"move","target":goal.duplicate()}
	if _is_ground(unit) and unit.position != goal:
		unit.route = []
		unit.status = "path_pending"
		sim._path_queue.append(unit.id)
	else:
		unit.route = [sim._frozen(goal.duplicate())]
		unit.status = "moving"

# Air: lowest id first, ahead of all ground. Ground: waiters in the order they began waiting, then arrivals by id, so no truck starves.
static func _ahead(unit: Dictionary, other: Dictionary) -> bool:
	if not _is_ground(unit): return not _is_ground(other) and other.id < unit.id
	if not _is_ground(other): return true
	var other_waits: bool = other.collection.phase.begins_with("waiting_")
	if not unit.collection.phase.begins_with("waiting_"): return other_waits or other.id < unit.id
	if not other_waits: return false
	var mine: int = unit.collection.remaining_ticks
	var theirs: int = other.collection.remaining_ticks
	return theirs < mine or theirs == mine and other.id < unit.id

static func _load_delay(sim: Simulation, unit: Dictionary) -> int:
	if sim.dock_model == "queue": return DockQueueWork.QUEUE_WORK[unit.kind].source_box
	return DockC.tables[sim.dock_model][unit.kind].source.box if DockC.tables.has(sim.dock_model) else Registry.collects(unit.kind).load_ticks

static func _unload_delay(sim: Simulation, unit: Dictionary) -> int:
	if sim.dock_model == "queue": return DockQueueWork.QUEUE_WORK[unit.kind].depot
	return DockC.tables[sim.dock_model][unit.kind].depot.work if DockC.tables.has(sim.dock_model) else Registry.collects(unit.kind).unload_ticks

static func _end_stay(sim: Simulation, unit: Dictionary, target: Dictionary) -> void:
	if sim.dock_model == "queue":
		DockQueue.begin_leaving(sim,unit,target)
		return
	release(sim,unit.id)
	unit.collection.retry_tick = sim._tick + 1

static func _lead(sim: Simulation, unit: Dictionary, depot: bool) -> int:
	if not DockC.tables.has(sim.dock_model): return 0
	var row: Dictionary = DockC.tables[sim.dock_model][unit.kind]
	return row.depot.lead if depot else row.source.lead

static func _admit(sim: Simulation, unit: Dictionary, target: Dictionary) -> void:
	if sim.dock_model == "queue":
		DockQueue.arrive(sim,unit,target)
		return
	var collection: Dictionary = unit.collection
	var depot: bool = collection.cargo > 0
	if not depot and target.boxes == 0:
		release(sim,unit.id)
		sim._stop_unit(unit)
		collection.retry_tick = sim._tick + 1
		return
	var lead: int = _lead(sim,unit,depot)
	if lead > 0 and collection.phase.begins_with("flying_"):
		collection.phase = "lead_depot" if depot else "lead_source"
		collection.remaining_ticks = lead
		sim._stop_unit(unit)
		return
	var waiting_before: bool = false
	for other: Dictionary in sim._entities.values():
		if other.id == unit.id or other.collection == null or not other.collection.enabled: continue
		if other.collection.target_id == target.id and other.position == _arrival(other,target) and other.collection.phase in ["flying_source","waiting_source","flying_depot","waiting_depot"] and _ahead(unit,other):
			waiting_before = true
			break
	if target.active_collector_id == null and not waiting_before:
		target.active_collector_id = unit.id
		collection.phase = "unloading" if depot else "loading"
		collection.remaining_ticks = _unload_delay(sim,unit) if depot else _load_delay(sim,unit)
	else:
		# remaining_ticks is idle while waiting; a ground truck stores the tick it began waiting there, for first-come order.
		if _is_ground(unit) and not collection.phase.begins_with("waiting_"): collection.remaining_ticks = sim._tick
		collection.phase = "waiting_depot" if depot else "waiting_source"
	sim._stop_unit(unit)

static func step(sim: Simulation, unit_ids: Array[int]) -> void:
	assert(sim.dock_model in DOCK_MODELS, "unknown dock_model " + sim.dock_model)
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
		if sim.dock_model == "queue" and DockQueue.step_unit(sim,unit,target): continue
		if collection.phase.begins_with("flying_") and _is_ground(unit) and unit.status == "blocked":
			release(sim,id)
			collection.retry_tick = sim._tick + 30
			continue
		if collection.phase.begins_with("flying_") or collection.phase.begins_with("waiting_"):
			if unit.position == _arrival(unit,target): _admit(sim,unit,target)
			continue
		collection.remaining_ticks -= 1
		if collection.remaining_ticks > 0: continue
		if collection.phase.begins_with("lead_"):
			collection.phase = "waiting_depot" if collection.phase == "lead_depot" else "waiting_source"
			collection.remaining_ticks = sim._tick
			_admit(sim,unit,target)
		elif collection.phase == "loading":
			# Zero Hour waits one more delay after the last box at a permanent source.
			if collection.cargo == Registry.collects(unit.kind).boxes or target.boxes == 0:
				_end_stay(sim,unit,target)
				continue
			_load_box(collection, target)
			if target.boxes == 0 and target.get("delete_when_empty", false):
				sim.remove_object(target.id)
				continue
			collection.remaining_ticks = _load_delay(sim,unit)
		elif collection.phase == "unloading":
			sim._players[unit.owner].credits += collection.cargo * Registry.collects(unit.kind).box_value
			collection.cargo = 0
			_end_stay(sim,unit,target)

static func _load_box(collection: Dictionary, target: Dictionary) -> void:
	target.boxes -= 1
	collection.cargo += 1

static func object_removed(sim: Simulation, id: int) -> void:
	for unit: Dictionary in sim._entities.values():
		if unit.collection == null or unit.collection.target_id != id: continue
		release(sim,unit.id)
		sim._stop_unit(unit)
		unit.collection.retry_tick = sim._tick + 1

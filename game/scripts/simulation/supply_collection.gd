extends RefCounted

static func release(sim: RefCounted, unit_id: int) -> void:
	var unit: Dictionary = sim._entities[unit_id]
	var collection: Dictionary = unit.collection
	if collection.target_id != null:
		var target: Dictionary = sim._sources.get(collection.target_id,sim._buildings.get(collection.target_id,{}))
		if target.get("active_collector_id") == unit_id: target.active_collector_id = null
	collection.target_id = null
	collection.remaining_ticks = 0
	collection.phase = "seeking" if collection.enabled else "idle"

static func center(target: Dictionary) -> Array:
	return [target.origin[0] + 1.5,target.origin[1] + 1.5]

static func nearest(unit: Dictionary, targets: Array) -> Dictionary:
	targets.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var pa: Array = center(a)
		var pb: Array = center(b)
		var da: float = (pa[0] - unit.position[0]) ** 2 + (pa[1] - unit.position[1]) ** 2
		var db: float = (pb[0] - unit.position[0]) ** 2 + (pb[1] - unit.position[1]) ** 2
		return da < db if da != db else a.id < b.id
	)
	return {} if targets.is_empty() else targets[0]

static func choose_target(sim: RefCounted, unit: Dictionary) -> Dictionary:
	var collection: Dictionary = unit.collection
	if collection.cargo > 0:
		var depots: Array = []
		for building in sim._buildings.values():
			if building.owner == unit.owner and building.kind == "depot" and building.completed: depots.append(building)
		return nearest(unit,depots)
	if collection.preferred_source_id != null and sim._sources.has(collection.preferred_source_id):
		var preferred: Dictionary = sim._sources[collection.preferred_source_id]
		if preferred.boxes > 0: return preferred
	var sources: Array = []
	for source in sim._sources.values():
		if source.boxes > 0: sources.append(source)
	return nearest(unit,sources)

static func _seek(sim: RefCounted, unit: Dictionary) -> void:
	var collection: Dictionary = unit.collection
	var target: Dictionary = choose_target(sim,unit)
	if target.is_empty():
		collection.phase = "idle"
		collection.retry_tick = sim._tick + 30
		sim._stop_unit(unit)
		return
	collection.target_id = target.id
	var goal: Array = center(target)
	collection.phase = "flying_depot" if collection.cargo > 0 else "flying_source"
	unit.destination = goal.duplicate()
	unit.order = {"type":"move","target":goal.duplicate()}
	unit.route = [goal.duplicate()]
	unit.status = "moving"
	if unit.position == goal: _admit(sim,unit,target)

static func _admit(sim: RefCounted, unit: Dictionary, target: Dictionary) -> void:
	var collection: Dictionary = unit.collection
	var depot: bool = collection.cargo > 0
	if not depot and target.boxes == 0:
		release(sim,unit.id)
		sim._stop_unit(unit)
		collection.retry_tick = sim._tick + 1
		return
	var waiting_before: bool = false
	for other in sim._entities.values():
		if other.id >= unit.id or other.collection == null or not other.collection.enabled: continue
		if other.collection.target_id == target.id and other.position == center(target) and other.collection.phase in ["flying_source","waiting_source","flying_depot","waiting_depot"]:
			waiting_before = true
			break
	if target.active_collector_id == null and not waiting_before:
		target.active_collector_id = unit.id
		collection.phase = "unloading" if depot else "loading"
		collection.remaining_ticks = 87 if depot else 36
	else:
		collection.phase = "waiting_depot" if depot else "waiting_source"
	sim._stop_unit(unit)

static func step(sim: RefCounted, unit_ids: Array[int]) -> void:
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
		if collection.phase.begins_with("flying_") or collection.phase.begins_with("waiting_"):
			if unit.position == center(target): _admit(sim,unit,target)
			continue
		if collection.phase == "loading" and target.boxes <= 0:
			release(sim,id)
			collection.retry_tick = sim._tick + 1
			continue
		collection.remaining_ticks -= 1
		if collection.remaining_ticks > 0: continue
		if collection.phase == "loading":
			target.boxes -= 1
			collection.cargo += 1
			if collection.cargo == 8 or target.boxes == 0:
				release(sim,id)
				collection.retry_tick = sim._tick + 1
			else: collection.remaining_ticks = 36
		elif collection.phase == "unloading":
			sim._players[unit.owner].credits += collection.cargo * 75
			collection.cargo = 0
			release(sim,id)
			collection.retry_tick = sim._tick + 1

static func object_removed(sim: RefCounted, id: int) -> void:
	for unit in sim._entities.values():
		if unit.collection == null or unit.collection.target_id != id: continue
		release(sim,unit.id)
		sim._stop_unit(unit)
		unit.collection.retry_tick = sim._tick + 1

extends RefCounted

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Construction = preload("res://scripts/simulation/construction.gd")

static func enqueue(sim: RefCounted, building_id: int, kind: String) -> void:
	var building: Dictionary = sim._buildings[building_id]
	var cost: int = Definitions.unit(kind).cost
	sim._players[building.owner].credits -= cost
	building.queue.append({"id":sim._next_production_id,"kind":kind,"paid_cost":cost,"work":0})
	sim._next_production_id += 1

static func cancel(sim: RefCounted, building_id: int, entry_id: int) -> void:
	var building: Dictionary = sim._buildings[building_id]
	for index in range(building.queue.size()):
		if building.queue[index].id == entry_id:
			sim._players[building.owner].credits += building.queue[index].paid_cost
			building.queue.remove_at(index)
			return

static func refund_all(sim: RefCounted, building_id: int) -> void:
	var building: Dictionary = sim._buildings[building_id]
	for entry in building.queue: sim._players[building.owner].credits += entry.paid_cost
	building.queue.clear()

static func center(building: Dictionary) -> Vector2:
	var size: Vector2i = Definitions.building(building.kind).footprint
	return Vector2(building.origin[0],building.origin[1]) + Vector2(size) / 2.0

static func default_rally(sim: RefCounted, kind: String, origin: Vector2i) -> Array:
	var size: Array = sim._navigation.snapshot().size
	var fp: Vector2i = Definitions.building(kind).footprint
	var x: int = origin.x + fp.x + 2 if origin.x + fp.x / 2.0 < size[0] / 2.0 else origin.x - 3
	var y: int = origin.y + fp.y / 2
	return [clampi(x,0,size[0] - 1) + 0.5,clampi(y,0,size[1] - 1) + 0.5]

static func rally_target(sim: RefCounted, building: Dictionary, unit: Dictionary) -> Array:
	var target := Vector2(building.rally[0],building.rally[1])
	var component: int = sim._navigation.component_at(Vector2(unit.position[0],unit.position[1]))
	if sim._navigation.component_at(target) == component: return building.rally
	var best: Vector2 = Vector2(unit.position[0],unit.position[1])
	var best_distance: float = INF
	for cell in sim._navigation.cells_in_component(component):
		var center := Vector2(cell) + Vector2(.5,.5)
		var distance: float = center.distance_squared_to(target)
		if distance < best_distance:
			best = center
			best_distance = distance
	return [best.x,best.y]

static func spawn_collector(sim: RefCounted, building: Dictionary) -> int:
	var id: int = sim.spawn(building.owner,center(building),"collector")
	assert(id != -1)
	sim._entities[id].collection.enabled = true
	sim._entities[id].collection.phase = "seeking"
	return id

static func step(sim: RefCounted, rates: Dictionary) -> void:
	var ids: Array = sim._buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = sim._buildings[id]
		if not building.completed or building.queue.is_empty(): continue
		var entry: Dictionary = building.queue[0]
		var required: int = Definitions.unit(entry.kind).ticks * 1000
		entry.work = mini(required,entry.work + rates[building.owner])
		if entry.work != required: continue
		var spawned: int = -1
		if entry.kind == "collector":
			spawned = spawn_collector(sim,building)
		else:
			for cell in Construction.perimeter(building.kind,Vector2i(building.origin[0],building.origin[1])):
				spawned = sim.spawn(building.owner,Vector2(cell) + Vector2(.5,.5),entry.kind)
				if spawned != -1:
					var unit: Dictionary = sim._entities[spawned]
					var members: Array[Dictionary] = [unit]
					sim._assign_move(members,rally_target(sim,building,unit))
					sim._set_intent(unit,"move")
					break
		if spawned != -1: building.queue.pop_front()

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
				if spawned != -1: break
		if spawned != -1: building.queue.pop_front()

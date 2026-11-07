extends RefCounted

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

static func enqueue(sim: Simulation, building_id: int, kind: String) -> void:
	var building: Dictionary = sim._buildings[building_id]
	var cost: int = Definitions.unit(kind).cost
	sim._players[building.owner].credits -= cost
	building.queue.append({"id":sim._next_production_id,"kind":kind,"paid_cost":cost,"work":0})
	sim._next_production_id += 1

static func cancel(sim: Simulation, building_id: int, entry_id: int) -> void:
	var building: Dictionary = sim._buildings[building_id]
	for index in range(building.queue.size()):
		if building.queue[index].id == entry_id:
			sim._players[building.owner].credits += building.queue[index].paid_cost
			building.queue.remove_at(index)
			return

static func refund_all(sim: Simulation, building_id: int) -> void:
	var building: Dictionary = sim._buildings[building_id]
	for entry: Variant in building.queue: sim._players[building.owner].credits += entry.paid_cost
	building.queue.clear()

static func center(building: Dictionary) -> Vector2:
	var size: Vector2i = Definitions.building(building.kind).footprint
	return Vector2(building.origin[0],building.origin[1]) + Vector2(size) / 2.0

static func default_rally(sim: Simulation, kind: String, origin: Vector2i) -> Array:
	var size: Array = sim._navigation.snapshot().size
	var fp: Vector2i = Definitions.building(kind).footprint
	var x: int = origin.x + fp.x + 2 if origin.x + fp.x / 2.0 < size[0] / 2.0 else origin.x - 3
	@warning_ignore("integer_division")
	var y: int = origin.y + fp.y / 2
	return [clampi(x,0,size[0] - 1) + 0.5,clampi(y,0,size[1] - 1) + 0.5]

static func rally_target(sim: Simulation, building: Dictionary, unit: Dictionary) -> Array:
	var target := Vector2(building.rally[0],building.rally[1])
	var component: int = sim._navigation.component_at(Vector2(unit.position[0],unit.position[1]))
	if sim._navigation.component_at(target) == component: return building.rally
	var best: Vector2 = Vector2(unit.position[0],unit.position[1])
	var best_distance: float = INF
	for cell: Variant in sim._navigation.cells_in_component(component):
		var cell_center := Vector2(cell) + Vector2(.5,.5)
		var distance: float = cell_center.distance_squared_to(target)
		if distance < best_distance:
			best = cell_center
			best_distance = distance
	return [best.x,best.y]

static func spawn_air(sim: Simulation, building: Dictionary, kind: String) -> int:
	var id: int = sim.spawn(building.owner,center(building),kind)
	assert(id != -1)
	sim._entities[id].collection.enabled = true
	sim._entities[id].collection.phase = "seeking"
	return id

static func free_exits(sim: Simulation, building: Dictionary, occupied: Dictionary) -> int:
	var count: int = 0
	for cell in Construction.perimeter(building.kind,Vector2i(building.origin[0],building.origin[1])):
		var position := Vector2(cell) + Vector2(.5,.5)
		if sim._in_bounds(position) and sim._navigation.is_walkable(position) and not occupied.has(cell): count += 1
	return count

static func spawn_unit(sim: Simulation, building: Dictionary, kind: String, occupied: Variant) -> int:
	if Registry.air_kinds.has(kind): return spawn_air(sim,building,kind)
	if occupied == null: occupied = sim.occupied_cells()
	var quantity: int = Registry.kind(kind).get("quantity",1)
	if quantity > 1 and free_exits(sim,building,occupied) < quantity: return -1
	var spawned_ids: Array[int] = []
	for cell in Construction.perimeter(building.kind,Vector2i(building.origin[0],building.origin[1])):
		var spawned: int = sim.spawn(building.owner,Vector2(cell) + Vector2(.5,.5),kind,occupied)
		if spawned == -1: continue
		occupied[sim._cell(sim._entities[spawned].position)] = true
		spawned_ids.append(spawned)
		if spawned_ids.size() == quantity: break
	for id in spawned_ids: _send_out(sim,building,sim._entities[id],occupied)
	return -1 if spawned_ids.is_empty() else spawned_ids[0]

# Rally moves come after every unit is placed, so a rally cell cannot block a later exit of the same order.
static func _send_out(sim: Simulation, building: Dictionary, unit: Dictionary, occupied: Dictionary) -> void:
	if not Registry.collects(unit.kind).is_empty() and Registry.kind(building.kind).receives_supply:
		unit.collection.enabled = true
		unit.collection.phase = "seeking"
		return
	var members: Array[Dictionary] = [unit]
	sim._assign_move(members,rally_target(sim,building,unit))
	sim._set_intent(unit,"move")
	if unit.destination != null: occupied[sim._cell(unit.destination)] = true

static func step(sim: Simulation, rates: Dictionary) -> void:
	var ids: Array = sim._buildings.keys()
	ids.sort()
	var occupied: Variant = null
	for id: Variant in ids:
		var building: Dictionary = sim._buildings[id]
		if not building.completed or building.queue.is_empty(): continue
		var entry: Dictionary = building.queue[0]
		var required: int = Definitions.unit(entry.kind).ticks * 1000
		entry.work = mini(required,entry.work + rates[building.owner])
		if entry.work != required: continue
		if not Registry.air_kinds.has(entry.kind) and occupied == null: occupied = sim.occupied_cells()
		var spawned: int = spawn_unit(sim,building,entry.kind,occupied)
		if spawned != -1: building.queue.pop_front()

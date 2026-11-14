extends RefCounted

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Production = preload("res://scripts/simulation/production.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Navigation = preload("res://scripts/simulation/grid_navigation.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const RebuildHoles = preload("res://scripts/simulation/rebuild_holes.gd")

static func cells(kind: String, origin: Vector2i) -> Array[Vector2i]:
	return block(Definitions.building(kind).footprint, origin)

static func block(size: Vector2i, origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(origin.y,origin.y + size.y):
		for x in range(origin.x,origin.x + size.x): result.append(Vector2i(x,y))
	return result

static func perimeter(kind: String, origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size: Vector2i = Definitions.building(kind).footprint
	for y in range(origin.y - 1,origin.y + size.y + 1):
		for x in range(origin.x - 1,origin.x + size.x + 1):
			if (x >= origin.x and x < origin.x + size.x) != (y >= origin.y and y < origin.y + size.y): result.append(Vector2i(x,y))
	return result

static func footprint_error(sim: Simulation, footprint: Array[Vector2i], kind: String = "") -> String:
	var members: Array[Dictionary] = []
	var unavailable: Array[Vector2i] = sim._unavailable_cells(members)
	for cell in footprint:
		if not sim._navigation.is_walkable(Vector2(cell) + Vector2(.5,.5)): return "Footprint outside map or overlaps obstacle"
		if unavailable.has(cell): return "Footprint covers ground unit or destination"
	if kind.is_empty(): return ""
	var size: Array = sim._navigation.snapshot().size
	for cell in footprint:
		if cell.x < Registry.BUILD_EDGE_MARGIN or cell.y < Registry.BUILD_EDGE_MARGIN or cell.x >= size[0] - Registry.BUILD_EDGE_MARGIN or cell.y >= size[1] - Registry.BUILD_EDGE_MARGIN: return "Too close to the map edge"
	return "Too close to a supply source" if _near_source(sim,footprint,Registry.kind(kind).get("supply_clearance",0)) else ""

static func _near_source(sim: Simulation, footprint: Array[Vector2i], clearance: int) -> bool:
	if clearance == 0: return false
	for source: Dictionary in sim._sources.values():
		for cell in block(Registry.source_footprint(source),Vector2i(source.origin[0],source.origin[1])):
			for placed in footprint:
				if maxi(absi(placed.x - cell.x),absi(placed.y - cell.y)) <= clearance: return true
	return false

static func approach(sim: Simulation, builder_id: int, kind: String, origin: Vector2i, navigation: RefCounted, crowded: bool = false) -> Variant:
	var unit: Dictionary = sim._entities[builder_id]
	var position := Vector2(unit.position[0],unit.position[1])
	var component: int = navigation.component_at(position)
	var members: Array[Dictionary] = [unit]
	var unavailable: Array[Vector2i] = []
	if not crowded: unavailable = sim._unavailable_cells(members)
	var candidates: Array[Vector2i] = []
	for cell in perimeter(kind,origin):
		if navigation.component_at(Vector2(cell) + Vector2(.5,.5)) == component and component >= 0 and not unavailable.has(cell): candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		var da: float = (Vector2(a) + Vector2(.5,.5)).distance_squared_to(position)
		var db: float = (Vector2(b) + Vector2(.5,.5)).distance_squared_to(position)
		return da < db if da != db else a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	if candidates.is_empty(): return null
	return [candidates[0].x + .5,candidates[0].y + .5]

static func preview(sim: Simulation, player: int, builder_id: int, kind: String, origin: Vector2i) -> Dictionary:
	var result := {"ok":false,"error":"Invalid builder or building kind","cells":[],"approach":null}
	var definition: Dictionary = Definitions.building(kind)
	if definition.is_empty() or not sim._players.has(player) or not sim._entities.has(builder_id): return result
	var builder: Dictionary = sim._entities[builder_id]
	if builder.owner != player or builder.has("hole_id") or not Registry.kind(builder.kind).get("builds", []).has(kind): return result
	if builder.has("container_id"):
		result.error = "Unit is inside a transport"
		return result
	if not sim._has_prerequisite(player,definition.prerequisite):
		result.error = "Missing completed prerequisite"
		return result
	if sim._players[player].credits < definition.cost:
		result.error = "Insufficient credits"
		return result
	var footprint: Array[Vector2i] = cells(kind,origin)
	result.error = footprint_error(sim,footprint,kind)
	if not result.error.is_empty(): return result
	var navigation: RefCounted = sim._navigation
	if navigation.blocks_locally(footprint):
		result.navigation = null
	else:
		var blocked: Array[Vector2i] = sim._union_cells()
		blocked.append_array(footprint)
		var size: Array = sim._navigation.snapshot().size
		sim._navigation_builds += 1
		navigation = Navigation.new(blocked,Vector2i(size[0],size[1]))
		result.navigation = navigation
	result.approach = approach(sim,builder_id,kind,origin,navigation)
	if result.approach == null:
		result.error = "No reachable builder approach"
		return result
	for cell in footprint: result.cells.append([cell.x,cell.y])
	result.ok = true
	return result

static func place(sim: Simulation, command: Dictionary) -> Dictionary:
	var origin := Vector2i(command.origin[0],command.origin[1])
	var result: Dictionary = preview(sim,command.player,command.builder_id,command.building_kind,origin)
	if not result.ok: return result
	var definition: Dictionary = Definitions.building(command.building_kind)
	var id: int = sim._next_entity_id
	sim._next_entity_id += 1
	sim._players[command.player].credits -= definition.cost
	sim._buildings[id] = {"id":id,"owner":command.player,"kind":command.building_kind,"hp":CombatDefinitions.profile(command.building_kind).max_hp,"max_hp":CombatDefinitions.profile(command.building_kind).max_hp,"origin":command.origin.duplicate(),"completed":false,"work":0,"paid_cost":definition.cost,"builder_id":null,"approach":null,"queue":[],"active_collector_id":null}
	sim._replace_union(sim._union_cells(),result.navigation)
	result.erase("navigation")
	result.building_id = id
	return result

static func place_rebuild(sim: Simulation, hole: Dictionary) -> int:
	var kind: String = hole.rebuild.kind
	var id: int = sim._next_entity_id
	sim._next_entity_id += 1
	var hp: int = CombatDefinitions.profile(kind).max_hp
	var origin := Vector2i(hole.origin[0], hole.origin[1])
	sim._buildings[id] = {"id":id,"owner":hole.owner,"kind":kind,"hp":hp,"max_hp":hp,"origin":hole.origin.duplicate(),"completed":false,"work":0,"paid_cost":0,"builder_id":null,"approach":null,"queue":[],"active_collector_id":null,"hole_id":hole.id,"rally":Production.default_rally(sim,kind,origin)}
	return id

static func resume(sim: Simulation, command: Dictionary) -> Dictionary:
	var building: Dictionary = sim._buildings[command.building_id]
	var goal: Variant = approach(sim,command.builder_id,building.kind,Vector2i(building.origin[0],building.origin[1]),sim._navigation)
	return {"ok":goal != null,"error":"" if goal != null else "No reachable builder approach","approach":goal}

static func cancel(sim: Simulation, building_id: int) -> void:
	var building: Dictionary = sim._buildings[building_id]
	sim._players[building.owner].credits += building.paid_cost
	sim.remove_object(building_id)

static func rebuild_navigation(sim: Simulation) -> void:
	sim._replace_union(sim._union_cells())

static func step(sim: Simulation, rates: Dictionary) -> void:
	var ids: Array = sim._buildings.keys()
	ids.sort()
	for id: Variant in ids:
		if not sim._buildings.has(id): continue
		var building: Dictionary = sim._buildings[id]
		if building.completed or building.builder_id == null or not sim._entities.has(building.builder_id): continue
		var builder: Dictionary = sim._entities[building.builder_id]
		if builder.construction_id != id or builder.position != building.approach or builder.status != "arrived": continue
		var required: int = Definitions.building(building.kind).ticks * 1000
		building.work = mini(required,building.work + rates[building.owner])
		if building.work == required:
			building.completed = true
			var rebuilt: bool = building.has("hole_id")
			if not rebuilt: sim._spawn_on_complete(building)
			var combat: Variant = CombatDefinitions.initial_combat(building.kind)
			if combat != null: building.combat = combat
			builder.construction_id = null
			building.builder_id = null
			building.approach = null
			if rebuilt: RebuildHoles.site_completed(sim,building)

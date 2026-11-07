extends RefCounted

const Combat = preload("res://scripts/simulation/combat.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const Production = preload("res://scripts/simulation/production.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

static func step(sim: Simulation) -> void:
	var ids: Array = []
	for id: int in sim._buildings:
		if sim._buildings[id].has("rebuild"): ids.append(id)
	ids.sort()
	for id: int in ids:
		var hole: Dictionary = sim._buildings[id]
		var spec: Dictionary = Registry.kind(hole.kind).hole
		hole.hp = mini(hole.max_hp, hole.hp + spec.regen_per_tick)
		if hole.rebuild.worker_id == null and sim._tick >= hole.rebuild.respawn_tick: _spawn_worker(sim, hole, spec)

static func building_removed(sim: Simulation, building: Dictionary) -> void:
	if building.has("hole_id"): _site_gone(sim, building)
	elif building.has("rebuild"): _hole_gone(sim, building)
	elif building.completed and not Registry.kind(building.kind).get("rebuild_hole", "").is_empty() and sim._survives(building.owner): _open(sim, building)

static func unit_removed(sim: Simulation, unit: Dictionary) -> void:
	var hole: Dictionary = sim._buildings.get(unit.get("hole_id", -1), {})
	if hole.is_empty() or hole.rebuild.worker_id != unit.id: return
	hole.rebuild.worker_id = null
	hole.rebuild.respawn_tick = sim._tick + _delay(hole)

static func site_completed(sim: Simulation, site: Dictionary) -> void:
	var hole: Dictionary = sim._buildings.get(site.hole_id, {})
	site.erase("hole_id")
	if hole.is_empty(): return
	var worker: Variant = hole.rebuild.worker_id
	hole.rebuild.worker_id = null
	hole.rebuild.site_id = null
	if worker != null: sim.remove_object(worker)
	sim.remove_object(hole.id)

static func being_rebuilt(sim: Simulation, site: Dictionary) -> bool:
	var hole: Dictionary = sim._buildings.get(site.get("hole_id", -1), {})
	return not hole.is_empty() and hole.rebuild.worker_id != null

static func _delay(hole: Dictionary) -> int:
	return Registry.kind(hole.kind).hole.respawn_ticks

static func _open(sim: Simulation, building: Dictionary) -> void:
	var kind: String = Registry.kind(building.kind).rebuild_hole
	var id: int = sim._next_entity_id
	sim._next_entity_id += 1
	var hp: int = CombatDefinitions.profile(kind).max_hp
	sim._buildings[id] = {"id":id,"owner":building.owner,"kind":kind,"hp":hp,"max_hp":hp,"origin":building.origin.duplicate(),"completed":true,"work":0,"paid_cost":0,"builder_id":null,"approach":null,"queue":[],"active_collector_id":null,"rebuild":{"kind":building.kind,"respawn_tick":sim._tick + Registry.kind(kind).hole.respawn_ticks,"worker_id":null,"site_id":null}}

# The site is going away: the laborer goes silently and the hole waits again.
static func _site_gone(sim: Simulation, site: Dictionary) -> void:
	var hole: Dictionary = sim._buildings.get(site.hole_id, {})
	if hole.is_empty(): return
	var worker: Variant = hole.rebuild.worker_id
	hole.rebuild.worker_id = null
	hole.rebuild.site_id = null
	hole.rebuild.respawn_tick = sim._tick + _delay(hole)
	if worker != null: sim.remove_object(worker)

static func _hole_gone(sim: Simulation, hole: Dictionary) -> void:
	var worker: Variant = hole.rebuild.worker_id
	hole.rebuild.worker_id = null
	if hole.rebuild.site_id != null and sim._buildings.has(hole.rebuild.site_id): sim._buildings[hole.rebuild.site_id].erase("hole_id")
	if worker != null: sim.remove_object(worker)

static func _spawn_worker(sim: Simulation, hole: Dictionary, spec: Dictionary) -> void:
	var worker: int = -1
	var origin := Vector2i(hole.origin[0], hole.origin[1])
	for cell in Construction.perimeter(hole.kind, origin):
		worker = sim.spawn(hole.owner, Vector2(cell) + Vector2(0.5, 0.5), spec.worker)
		if worker != -1: break
	if worker == -1: return
	sim._entities[worker].hole_id = hole.id
	if hole.rebuild.site_id == null: hole.rebuild.site_id = Construction.place_rebuild(sim, hole)
	var approach: Variant = Construction.approach(sim, worker, hole.rebuild.kind, origin, sim._navigation)
	assert(approach != null)
	sim._attach_builder(sim._entities[worker], hole.rebuild.site_id, approach)
	hole.rebuild.worker_id = worker
	Combat.object_removed(sim, hole.id)

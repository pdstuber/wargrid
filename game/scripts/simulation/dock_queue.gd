extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Collection = preload("res://scripts/simulation/supply_collection.gd")

const SPOT_STEP := 1.5

# Dock model "queue": collectors that cannot dock wait at approach spots; the head moves in when the lock is free.
# The lock (target.active_collector_id, queue head) covers moving in, working and moving out.
# Ground approach spots are the collector's own claimed ring cell and do not shift as the line moves; air spots are one per line slot.

static func _suffix(target: Dictionary) -> String:
	return "source" if target.has("boxes") else "depot"

static func _air_spot(target: Dictionary, ray: Array, slot: int) -> Array:
	var middle: Array = Collection.center(target)
	return [middle[0] + ray[0] * SPOT_STEP * slot,middle[1] + ray[1] * SPOT_STEP * slot]

# The ray runs from the target toward where the collector comes from (the depot when it heads for a pile, the pile when it heads for a depot).
static func _ray(unit: Dictionary, target: Dictionary) -> Array:
	var middle: Array = Collection.center(target)
	var away := Vector2(unit.position[0] - middle[0],unit.position[1] - middle[1])
	var ray: Vector2 = Vector2(1,0) if away.is_zero_approx() else away.normalized()
	return [ray.x,ray.y]

static func approach(unit: Dictionary, target: Dictionary) -> Array:
	var collection: Dictionary = unit.collection
	if Collection._is_ground(unit):
		collection.approach = [collection.dock[0] + 0.5,collection.dock[1] + 0.5]
	else:
		collection.ray = _ray(unit,target)
		collection.approach = _air_spot(target,collection.ray,maxi(1,target.get("dock_queue",[]).size()))
	return collection.approach.duplicate()

static func _exit_spot(unit: Dictionary, target: Dictionary) -> Array:
	var collection: Dictionary = unit.collection
	return _air_spot(target,collection.ray,1) if not Collection._is_ground(unit) else collection.approach.duplicate()

static func arrive(sim: Simulation, unit: Dictionary, target: Dictionary) -> void:
	var collection: Dictionary = unit.collection
	if not target.has("dock_queue"):
		var empty: Array[int] = []
		target.dock_queue = empty
	if target.has("boxes") and target.boxes == 0:
		Collection.release(sim,unit.id)
		sim._stop_unit(unit)
		collection.retry_tick = sim._tick + 1
		return
	target.dock_queue.append(unit.id)
	collection.phase = "queued_" + _suffix(target)
	sim._stop_unit(unit)
	grant(sim,target)

# Gives the lock to the head of the line; a pile that ran empty while they stood in line sends them off again.
static func grant(sim: Simulation, target: Dictionary) -> void:
	var line: Array = target.get("dock_queue",[])
	while target.active_collector_id == null and not line.is_empty():
		var head: Dictionary = sim._entities[line[0]]
		if target.has("boxes") and target.boxes == 0:
			Collection.release(sim,head.id)
			sim._stop_unit(head)
			head.collection.retry_tick = sim._tick + 1
			continue
		target.active_collector_id = head.id
		head.collection.phase = "entering_" + _suffix(target)
		Collection._move_to(sim,head,Collection._arrival(head,target))

static func leave(sim: Simulation, target: Dictionary, unit_id: int) -> void:
	if not target.has("dock_queue"): return
	target.dock_queue.erase(unit_id)
	grant(sim,target)

static func begin_leaving(sim: Simulation, unit: Dictionary, target: Dictionary) -> void:
	unit.collection.phase = "leaving_" + _suffix(target)
	Collection._move_to(sim,unit,_exit_spot(unit,target))

# Returns true when the tick is handled here; loading and unloading use the shared countdown.
static func step_unit(sim: Simulation, unit: Dictionary, target: Dictionary) -> bool:
	var collection: Dictionary = unit.collection
	var phase: String = collection.phase
	if phase == "loading" or phase == "unloading": return false
	if Collection._is_ground(unit) and unit.status == "blocked":
		Collection.release(sim,unit.id)
		collection.retry_tick = sim._tick + (30 if phase.begins_with("flying_") else 1)
		return true
	if phase.begins_with("flying_"):
		if unit.position == collection.approach: arrive(sim,unit,target)
	elif phase.begins_with("queued_"):
		if not Collection._is_ground(unit): _advance_air(sim,unit,target)
	elif phase.begins_with("entering_"):
		if unit.position == Collection._arrival(unit,target):
			var depot: bool = phase == "entering_depot"
			collection.phase = "unloading" if depot else "loading"
			collection.remaining_ticks = Collection._unload_delay(sim,unit) if depot else Collection._load_delay(sim,unit)
			sim._stop_unit(unit)
	elif phase.begins_with("leaving_") and unit.position == _exit_spot(unit,target):
		Collection.release(sim,unit.id)
		collection.retry_tick = sim._tick + 1
	return true

static func _advance_air(sim: Simulation, unit: Dictionary, target: Dictionary) -> void:
	var spot: Array = _air_spot(target,unit.collection.ray,target.dock_queue.find(unit.id))
	if spot == unit.collection.approach: return
	unit.collection.approach = spot
	Collection._move_to(sim,unit,spot)

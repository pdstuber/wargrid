extends RefCounted

const NONE: int = 255
const STATUSES: Array[String] = ["moving", "path_pending", "arrived", "blocked", "idle", "contained"]
const HORDE: int = 1
const CONTAINED: int = 2
const HOLE: int = 4
const ATTACKING: int = 8
const ORDERED: int = 16
const WAITING_SOURCE: int = 32
const COLLECTING: int = 64
const DEFAULT_HEADING: Array = [1.0, 0.0]

var id := PackedInt32Array()
var owner := PackedInt32Array()
var kind := PackedInt32Array()
var hp := PackedInt32Array()
var max_hp := PackedInt32Array()
var target := PackedInt32Array()
var queue := PackedInt32Array()
var x := PackedFloat64Array()
var y := PackedFloat64Array()
var heading_x := PackedFloat64Array()
var heading_y := PackedFloat64Array()
var order_x := PackedFloat64Array()
var order_y := PackedFloat64Array()
var status := PackedByteArray()
var tier := PackedByteArray()
var mode := PackedByteArray()
var phase := PackedByteArray()
var flags := PackedByteArray()
var kinds := PackedStringArray()
var modes := PackedStringArray()
var phases := PackedStringArray()

func size() -> int:
	return id.size()

func index_of(unit_id: int) -> int:
	var i: int = id.bsearch(unit_id)
	return i if i < id.size() and id[i] == unit_id else -1

# Units must be in id order, as the snapshot lists them. One flat loop over local columns: the per-field helper version cost 3x as much (task 2 profile).
static func from_units(units: Array) -> RefCounted:
	var rows: RefCounted = new()
	rows._resize(units.size())
	rows._fill_all(units)
	assert(rows.kinds.size() < NONE and rows.modes.size() < NONE and rows.phases.size() < NONE)
	return rows

func _resize(n: int) -> void:
	for column: PackedInt32Array in [id, owner, kind, hp, max_hp, target, queue]: column.resize(n)
	for column: PackedFloat64Array in [x, y, heading_x, heading_y, order_x, order_y]: column.resize(n)
	for column: PackedByteArray in [status, tier, mode, phase, flags]: column.resize(n)

func _fill_all(units: Array) -> void:
	var c_id: PackedInt32Array = id
	var c_owner: PackedInt32Array = owner
	var c_kind: PackedInt32Array = kind
	var c_hp: PackedInt32Array = hp
	var c_max: PackedInt32Array = max_hp
	var c_target: PackedInt32Array = target
	var c_queue: PackedInt32Array = queue
	var c_x: PackedFloat64Array = x
	var c_y: PackedFloat64Array = y
	var c_hx: PackedFloat64Array = heading_x
	var c_hy: PackedFloat64Array = heading_y
	var c_ox: PackedFloat64Array = order_x
	var c_oy: PackedFloat64Array = order_y
	var c_status: PackedByteArray = status
	var c_tier: PackedByteArray = tier
	var c_mode: PackedByteArray = mode
	var c_phase: PackedByteArray = phase
	var c_flags: PackedByteArray = flags
	var kind_index: Dictionary = {}
	var mode_index: Dictionary = {}
	var phase_index: Dictionary = {}
	for i in units.size():
		var unit: Dictionary = units[i]
		var position: Array = unit.position
		var heading: Array = unit.get("heading", DEFAULT_HEADING)
		var combat: Variant = unit.get("combat")
		var collection: Variant = unit.get("collection")
		var order: Variant = unit.get("order")
		var bits: int = 0
		c_id[i] = unit.id
		c_owner[i] = unit.get("owner", 0)
		var label: String = unit.get("kind", "")
		var slot: int = kind_index.get(label, -1)
		if slot == -1:
			slot = kinds.size()
			kind_index[label] = slot
			kinds.append(label)
		c_kind[i] = slot
		c_hp[i] = unit.get("hp", 0)
		c_max[i] = unit.get("max_hp", 0)
		c_x[i] = position[0]
		c_y[i] = position[1]
		c_hx[i] = heading[0]
		c_hy[i] = heading[1]
		var found: int = STATUSES.find(unit.get("status", ""))
		c_status[i] = NONE if found == -1 else found
		if unit.has("container_id"): bits = CONTAINED
		if unit.has("hole_id"): bits |= HOLE
		if order != null:
			var goal: Array = order.target
			c_ox[i] = goal[0]
			c_oy[i] = goal[1]
			bits |= ORDERED
		if combat == null:
			c_target[i] = -1
			c_mode[i] = NONE
		else:
			var aim: Variant = combat.get("target_id")
			c_target[i] = -1 if aim == null else aim
			c_tier[i] = combat.get("tier", 0)
			var current: String = combat.get("mode", "")
			var mode_slot: int = mode_index.get(current, -1)
			if mode_slot == -1:
				mode_slot = modes.size()
				mode_index[current] = mode_slot
				modes.append(current)
			c_mode[i] = mode_slot
			if combat.get("horde", 0) > 0: bits |= HORDE
			if current == "attack": bits |= ATTACKING
		c_queue[i] = -1
		if collection == null:
			c_phase[i] = NONE
		else:
			var step: String = collection.phase
			var phase_slot: int = phase_index.get(step, -1)
			if phase_slot == -1:
				phase_slot = phases.size()
				phase_index[step] = phase_slot
				phases.append(step)
			c_phase[i] = phase_slot
			if collection.enabled: bits |= COLLECTING
			if step == "waiting_source" or step == "queued_source": bits |= WAITING_SOURCE
			var waiting: Variant = collection.target_id
			if waiting != null and (step.begins_with("waiting_") or step.begins_with("queued_")): c_queue[i] = waiting
		c_flags[i] = bits

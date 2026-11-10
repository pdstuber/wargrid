extends RefCounted

# Movement slice for the native spike; buffers per docs/reference/native-sim-spike-slice-move.md.

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Containers = preload("res://scripts/simulation/containers.gd")
const PREFIX: int = 4
const ARRIVED: int = 1
const FALLBACK: int = 2
const LOCOMOTORS: Dictionary = {"wheels": 1.0, "air": 2.0}
const FIELDS: Array[String] = ["x", "y", "heading_x", "heading_y", "speed", "consumed", "flags"]

var fallbacks: int = 0
var _kind_index: Dictionary = {}
var _kinds := PackedFloat64Array()
# Ids that take the non-moving branch this tick; apply zeroes their speed.
var _rest: Array[int] = []

# The movement loop of Simulation.step(), unchanged: the GDScript reference this slice is timed and compared against.
func step_gd(sim: Simulation, ids: Array[int]) -> void:
	for id in ids:
		var unit: Dictionary = sim._entities[id]
		if unit.status == "moving": sim._advance(unit)
		elif unit.status != "path_pending": unit.speed = 0.0

func pack(sim: Simulation, ids: Array[int]) -> Array:
	var rows := PackedInt64Array()
	var kinds := PackedInt32Array()
	var x := PackedFloat64Array()
	var y := PackedFloat64Array()
	var hx := PackedFloat64Array()
	var hy := PackedFloat64Array()
	var speed := PackedFloat64Array()
	var move_after := PackedInt64Array()
	var sent := PackedInt32Array()
	var length := PackedInt32Array()
	var wx := PackedFloat64Array()
	var wy := PackedFloat64Array()
	_rest.clear()
	for id in ids:
		var unit: Dictionary = sim._entities[id]
		if unit.status != "moving":
			if unit.status != "path_pending": _rest.append(id)
			continue
		rows.append(id)
		kinds.append(_index_of(unit.kind))
		var position: Array = unit.position
		x.append(position[0])
		y.append(position[1])
		var heading: Array = unit.heading
		hx.append(heading[0])
		hy.append(heading[1])
		speed.append(unit.speed)
		move_after.append(unit.move_after)
		var route: Array = unit.route
		var count: int = mini(route.size(), PREFIX)
		sent.append(count)
		length.append(route.size())
		for i in range(count):
			var waypoint: Array = route[i]
			wx.append(waypoint[0])
			wy.append(waypoint[1])
	return [rows, kinds, x, y, hx, hy, speed, move_after, sent, length, wx, wy, PackedInt64Array([sim.tick()]), _kinds]

func _index_of(kind: String) -> int:
	if _kind_index.is_empty():
		for name: String in Registry.units(): _add_kind(name)
	if not _kind_index.has(kind): _add_kind(kind)
	return _kind_index[kind]

func _add_kind(kind: String) -> void:
	var row: Dictionary = Registry.unit_view(kind)
	_kind_index[kind] = _kind_index.size()
	_kinds.append_array([row.speed, LOCOMOTORS.get(row.locomotor, 0.0), row.get("accel", 0.0), row.get("brake", 0.0), row.get("turn_cos", 0.0), row.get("turn_sin", 0.0), row.get("min_turn_speed", 0.0)])

func call_native(core: Object, inputs: Array) -> Array:
	return core.run(inputs)

func call_pass(core: Object, inputs: Array) -> Array:
	return core.run_pass(inputs)

func apply(sim: Simulation, inputs: Array, outputs: Array) -> void:
	var rows: PackedInt64Array = inputs[0]
	var old_hx: PackedFloat64Array = inputs[4]
	var old_hy: PackedFloat64Array = inputs[5]
	var x: PackedFloat64Array = outputs[0]
	var y: PackedFloat64Array = outputs[1]
	var hx: PackedFloat64Array = outputs[2]
	var hy: PackedFloat64Array = outputs[3]
	var speed: PackedFloat64Array = outputs[4]
	var consumed: PackedInt32Array = outputs[5]
	var flags: PackedByteArray = outputs[6]
	for i in range(rows.size()):
		var unit: Dictionary = sim._entities[rows[i]]
		if flags[i] & FALLBACK:
			fallbacks += 1
			sim._advance(unit)
			continue
		if hx[i] != old_hx[i] or hy[i] != old_hy[i]: unit.heading = [hx[i], hy[i]]
		unit.speed = speed[i]
		unit.position = [x[i], y[i]]
		if consumed[i] > 0: unit.route = unit.route.slice(consumed[i])
		if flags[i] & ARRIVED:
			if not Containers.entering(unit): unit.order = null
			unit.status = "arrived"
	for id in _rest: sim._entities[id].speed = 0.0

func compare(sim: Simulation, inputs: Array, outputs: Array) -> Dictionary:
	var rows: PackedInt64Array = inputs[0]
	var length: PackedInt32Array = inputs[9]
	var native_flags: PackedByteArray = outputs[6] if outputs.size() == FIELDS.size() and outputs[6] is PackedByteArray else PackedByteArray()
	var expected: Array = [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array(), PackedInt32Array(), PackedByteArray()]
	for i in range(rows.size()):
		var unit: Dictionary = sim._entities[rows[i]]
		# GDScript cannot know which waypoint the kernel wanted; the digests cover these rows.
		if native_flags.size() == rows.size() and native_flags[i] & FALLBACK:
			fallbacks += 1
			for b in range(5): expected[b].append(0.0)
			expected[5].append(0)
			expected[6].append(FALLBACK)
			continue
		var position: Array = unit.position
		var heading: Array = unit.heading
		var values: Array = [position[0], position[1], heading[0], heading[1], unit.speed]
		for b in range(5): expected[b].append(values[b])
		expected[5].append(length[i] - unit.route.size())
		expected[6].append(ARRIVED if unit.status == "arrived" else 0)
	return {"mismatch": _first_difference(rows, expected, outputs), "expected": expected}

static func _first_difference(rows: PackedInt64Array, expected: Array, outputs: Array) -> String:
	if outputs.size() != expected.size(): return "move: native returned %d buffers, expected %d" % [outputs.size(), expected.size()]
	for b in range(expected.size()):
		if typeof(outputs[b]) != typeof(expected[b]) or outputs[b].size() != expected[b].size():
			return "field=%s shape gd=%d native=%d" % [FIELDS[b], expected[b].size(), outputs[b].size()]
		var want: PackedByteArray = _bytes(expected[b])
		var got: PackedByteArray = _bytes(outputs[b])
		if want == got: continue
		@warning_ignore("integer_division")
		var width: int = want.size() / rows.size()
		for i in range(rows.size()):
			var a: PackedByteArray = want.slice(i * width, (i + 1) * width)
			var c: PackedByteArray = got.slice(i * width, (i + 1) * width)
			if a != c: return "entity=%d field=%s gd=%s (%s) native=%s (%s)" % [rows[i], FIELDS[b], expected[b][i], a.hex_encode(), outputs[b][i], c.hex_encode()]
	return ""

static func _bytes(buffer: Variant) -> PackedByteArray:
	return buffer if buffer is PackedByteArray else buffer.to_byte_array()

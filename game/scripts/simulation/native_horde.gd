extends RefCounted

# Horde step slice for the native spike; buffers per docs/reference/native-sim-spike-slice-horde.md.

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Horde = preload("res://scripts/simulation/horde.gd")

var _kind_index: Dictionary = {}
var _kind_f: PackedFloat64Array = PackedFloat64Array()
var _kind_i: PackedInt32Array = PackedInt32Array()
var _table_sent: bool = false

func step_gd(sim: Simulation, armed: Array[int]) -> void:
	Horde.step(sim, armed)

func pack(sim: Simulation, armed: Array[int]) -> Array:
	var ids := PackedInt64Array()
	var xs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	var kinds := PackedInt32Array()
	var owners := PackedInt32Array()
	var teams := PackedInt32Array()
	var contained := PackedByteArray()
	var horde_ticks := PackedInt64Array()
	var levels := PackedByteArray()
	var members: Array[Dictionary] = []
	for id: int in armed:
		if not sim._entities.has(id): continue
		var entity: Dictionary = sim._entities[id]
		var entity_combat: Dictionary = entity.combat
		if entity_combat.has("horde"): members.append(entity)
	_ensure_table(members)
	for unit: Dictionary in members:
		var unit_combat: Dictionary = unit.combat
		var position: Array = unit.position
		var unit_owner: int = unit.owner
		ids.append(unit.id)
		xs.append(position[0])
		ys.append(position[1])
		kinds.append(_kind_index[unit.kind])
		owners.append(unit_owner)
		teams.append(sim.team_of(unit_owner))
		contained.append(1 if unit.has("container_id") else 0)
		horde_ticks.append(unit_combat.horde_tick)
		levels.append(unit_combat.horde)
	var send_table: bool = not _table_sent
	return [ids, xs, ys, kinds, owners, teams, contained, horde_ticks, levels, PackedInt64Array([sim._tick]),
		_kind_f if send_table else PackedFloat64Array(), _kind_i if send_table else PackedInt32Array()]

func call_native(core: Object, inputs: Array) -> Array:
	var outputs: Array = core.run(inputs)
	if not outputs.is_empty(): _table_sent = true
	return outputs

func call_pass(core: Object, inputs: Array) -> Array:
	var outputs: Array = core.run_pass(inputs)
	if not outputs.is_empty(): _table_sent = true
	return outputs

func apply(sim: Simulation, inputs: Array, outputs: Array) -> void:
	var ids: PackedInt64Array = inputs[0]
	var rows: PackedInt32Array = outputs[0]
	var levels: PackedByteArray = outputs[1]
	var horde_ticks: PackedInt64Array = outputs[2]
	var changed: PackedByteArray = outputs[3]
	sim._horde_checks += rows.size()
	for at in range(rows.size()):
		var unit: Dictionary = sim._entities[ids[rows[at]]]
		var unit_combat: Dictionary = unit.combat
		unit_combat.horde_tick = horde_ticks[at]
		unit_combat.horde = levels[at]
		if changed[at] == 1: Combat.restart_wait(sim, unit_combat, CombatDefinitions.weapon(CombatDefinitions.profile(unit.kind).weapon))

func compare(sim: Simulation, inputs: Array, outputs: Array) -> Dictionary:
	var expected: Array = _expected(sim, inputs)
	return {"mismatch": "" if outputs.is_empty() else _first_difference(inputs[0], expected, outputs), "expected": expected}

# GDScript's outputs, read from the entities after step_gd ran.
func _expected(sim: Simulation, inputs: Array) -> Array:
	var ids: PackedInt64Array = inputs[0]
	var old_levels: PackedByteArray = inputs[8]
	var tick: int = inputs[9][0]
	var due_ticks: PackedInt64Array = inputs[7]
	var contained: PackedByteArray = inputs[6]
	var rows := PackedInt32Array()
	var levels := PackedByteArray()
	var horde_ticks := PackedInt64Array()
	var changed := PackedByteArray()
	for row in range(ids.size()):
		if due_ticks[row] > tick or contained[row] == 1: continue
		var unit: Dictionary = sim._entities[ids[row]]
		var unit_combat: Dictionary = unit.combat
		var level: int = unit_combat.horde
		rows.append(row)
		levels.append(level)
		horde_ticks.append(unit_combat.horde_tick)
		changed.append(1 if (old_levels[row] > 0) != (level > 0) else 0)
	return [rows, levels, horde_ticks, changed]

const FIELDS: Array[String] = ["row", "level", "horde_tick", "changed"]

func _first_difference(ids: PackedInt64Array, expected: Array, outputs: Array) -> String:
	if outputs.size() != expected.size(): return "output count gd=%d native=%d" % [expected.size(), outputs.size()]
	var due: PackedInt32Array = expected[0]
	for field in range(expected.size()):
		var want: Variant = expected[field]
		var got: Variant = outputs[field]
		if typeof(got) != typeof(want) or got.size() != want.size():
			return "field=%s shape gd=%d native=%d" % [FIELDS[field], want.size(), got.size() if typeof(got) == typeof(want) else -1]
		for at in range(want.size()):
			if want[at] != got[at]:
				return "entity=%d field=%s gd=%d native=%d" % [ids[due[at]], FIELDS[field], want[at], got[at]]
	return ""

# Kinds that carry a horde rule, sorted, so an index does not depend on spawn order.
func _ensure_table(members: Array[Dictionary]) -> void:
	if not _kind_index.is_empty() and members.all(func(unit: Dictionary) -> bool: return _kind_index.has(unit.kind)): return
	var kinds: Array[String] = []
	for kind: String in Registry.units():
		if Registry.kind(kind).has("horde"): kinds.append(kind)
	kinds.sort()
	var classes: Array[String] = []
	for kind in kinds:
		var class_name_of: String = Registry.kind(kind).get("class", "")
		if not classes.has(class_name_of): classes.append(class_name_of)
	classes.sort()
	_kind_index = {}
	_kind_f = PackedFloat64Array()
	_kind_i = PackedInt32Array()
	for kind in kinds:
		var row: Dictionary = Registry.kind(kind)
		var rule: Dictionary = row.horde
		_kind_index[kind] = _kind_index.size()
		_kind_f.append_array(PackedFloat64Array([rule.radius, CombatDefinitions.radius(kind)]))
		_kind_i.append_array(PackedInt32Array([rule.count, 0 if rule.match == "kind" else 1, classes.find(row.get("class", "")), Horde.rate(kind)]))
	_table_sent = false

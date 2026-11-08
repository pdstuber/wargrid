extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

# HordeUpdate.cpp: infantry re-check every 30 ticks, everything else every 31.
static func rate(kind: String) -> int:
	return 30 if Registry.kind(kind).get("class", "") == "infantry" else 31

static func first_check(sim: Simulation, kind: String) -> int:
	return sim._tick + 1 + sim.next_random() % rate(kind)

static func step(sim: Simulation, armed: Array[int]) -> void:
	var members: Array[Dictionary] = []
	for id: int in armed:
		if not sim._entities.has(id): continue
		var entity: Dictionary = sim._entities[id]
		var entity_combat: Dictionary = entity.combat
		if entity_combat.has("horde"): members.append(entity)
	var grid: Dictionary = {}
	var size: float = 0.0
	var tick: int = sim._tick
	for unit: Dictionary in members:
		var unit_combat: Dictionary = unit.combat
		var horde_tick: int = unit_combat.horde_tick
		if horde_tick > tick or unit.has("container_id"): continue
		if grid.is_empty():
			size = _cell_size(members)
			grid = _bucket(members, size)
		sim._horde_checks += 1
		unit_combat.horde_tick = tick + rate(unit.kind)
		_set_level(sim, unit, _level(sim, unit, grid, size))

# A neighbour is within rule radius plus both unit radii, so one cell of that width reaches every candidate from the 3x3 block.
static func _cell_size(members: Array[Dictionary]) -> float:
	var widest: float = 0.0
	var largest: float = 0.0
	var seen: Dictionary = {}
	for unit in members:
		if seen.has(unit.kind): continue
		seen[unit.kind] = true
		widest = maxf(widest, Registry.kind(unit.kind).horde.radius)
		largest = maxf(largest, CombatDefinitions.radius(unit.kind))
	return widest + 2.0 * largest

static func _cell(unit: Dictionary, size: float) -> Vector2i:
	var position: Array = unit.position
	var px: float = position[0]
	var py: float = position[1]
	return Vector2i(floori(px / size), floori(py / size))

static func _bucket(members: Array[Dictionary], size: float) -> Dictionary:
	var grid: Dictionary = {}
	for unit: Dictionary in members:
		var cell: Vector2i = _cell(unit, size)
		if not grid.has(cell): grid[cell] = [] as Array[Dictionary]
		var bucket: Array[Dictionary] = grid[cell]
		bucket.append(unit)
	return grid

static func _level(sim: Simulation, unit: Dictionary, grid: Dictionary, size: float) -> int:
	var unit_kind: String = unit.kind
	var rule: Dictionary = Registry.kind(unit_kind).horde
	var need: int = rule.count - 1
	if need <= 0: return 2
	var rule_radius: float = rule.radius
	var near: int = 0
	var rubbed: bool = false
	var home: Vector2i = _cell(unit, size)
	var unit_id: int = unit.id
	var unit_owner: int = unit.owner
	var unit_position: Array = unit.position
	var ux: float = unit_position[0]
	var uy: float = unit_position[1]
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var bucket: Array = grid.get(home + Vector2i(dx, dy), [])
			for other: Dictionary in bucket:
				var other_owner: int = other.owner
				if other.id == unit_id or other.has("container_id") or Combat.hostile(sim, unit_owner, other_owner) or not _matches(rule, unit, other): continue
				var other_position: Array = other.position
				var ox: float = float(other_position[0]) - ux
				var oy: float = float(other_position[1]) - uy
				if Combat._gap_between(ox, oy, CombatDefinitions.radius(unit_kind), CombatDefinitions.radius(other.kind)) > rule_radius: continue
				near += 1
				var other_combat: Dictionary = other.combat
				rubbed = rubbed or other_combat.horde == 2
				if near >= need: return 2
	return 1 if rubbed else 0

static func _matches(rule: Dictionary, unit: Dictionary, other: Dictionary) -> bool:
	if rule.match == "kind": return other.kind == unit.kind
	return Registry.kind(other.kind).get("class", "") == Registry.kind(unit.kind).get("class", "")

static func _set_level(sim: Simulation, unit: Dictionary, level: int) -> void:
	var combat: Dictionary = unit.combat
	var changed: bool = (combat.horde > 0) != (level > 0)
	combat.horde = level
	if changed: Combat.restart_wait(sim, combat, CombatDefinitions.weapon(CombatDefinitions.profile(unit.kind).weapon))

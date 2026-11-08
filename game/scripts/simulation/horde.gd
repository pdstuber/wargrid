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
	for id in armed:
		if sim._entities.has(id) and sim._entities[id].combat.has("horde"): members.append(sim._entities[id])
	var grid: Dictionary = {}
	var size: float = 0.0
	for unit in members:
		if unit.combat.horde_tick > sim._tick or unit.has("container_id"): continue
		if grid.is_empty():
			size = _cell_size(members)
			grid = _bucket(members, size)
		sim._horde_checks += 1
		unit.combat.horde_tick = sim._tick + rate(unit.kind)
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
	return Vector2i(floori(unit.position[0] / size), floori(unit.position[1] / size))

static func _bucket(members: Array[Dictionary], size: float) -> Dictionary:
	var grid: Dictionary = {}
	for unit in members:
		var cell: Vector2i = _cell(unit, size)
		if not grid.has(cell): grid[cell] = [] as Array[Dictionary]
		grid[cell].append(unit)
	return grid

static func _level(sim: Simulation, unit: Dictionary, grid: Dictionary, size: float) -> int:
	var rule: Dictionary = Registry.kind(unit.kind).horde
	var need: int = rule.count - 1
	if need <= 0: return 2
	var near: int = 0
	var rubbed: bool = false
	var home: Vector2i = _cell(unit, size)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for other: Dictionary in grid.get(home + Vector2i(dx, dy), []):
				if other.id == unit.id or other.has("container_id") or Combat.hostile(sim, unit.owner, other.owner) or not _matches(rule, unit, other): continue
				var ox: float = other.position[0] - unit.position[0]
				var oy: float = other.position[1] - unit.position[1]
				if Combat._gap_between(ox, oy, CombatDefinitions.radius(unit.kind), CombatDefinitions.radius(other.kind)) > rule.radius: continue
				near += 1
				rubbed = rubbed or other.combat.horde == 2
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

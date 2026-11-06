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

# shortcut: each due check scans all horde members (n^2/30 per tick); grid it if the hordes layout shows in the ledger.
static func step(sim: Simulation, armed: Array[int]) -> void:
	var members: Array[Dictionary] = []
	for id in armed:
		if sim._entities.has(id) and sim._entities[id].combat.has("horde"): members.append(sim._entities[id])
	for unit in members:
		var combat: Dictionary = unit.combat
		if combat.horde_tick > sim._tick or unit.has("container_id"): continue
		sim._horde_checks += 1
		combat.horde_tick = sim._tick + rate(unit.kind)
		_set_level(sim, unit, _level(sim, unit, members))

static func _level(sim: Simulation, unit: Dictionary, members: Array[Dictionary]) -> int:
	var rule: Dictionary = Registry.kind(unit.kind).horde
	var near: int = 0
	var rubbed: bool = false
	for other in members:
		if other.id == unit.id or other.has("container_id") or Combat.hostile(sim, unit.owner, other.owner) or not _matches(rule, unit, other): continue
		var dx: float = other.position[0] - unit.position[0]
		var dy: float = other.position[1] - unit.position[1]
		if Combat._gap_between(dx, dy, CombatDefinitions.radius(unit.kind), CombatDefinitions.radius(other.kind)) > rule.radius: continue
		near += 1
		rubbed = rubbed or other.combat.horde == 2
	if near >= rule.count - 1: return 2
	return 1 if rubbed else 0

static func _matches(rule: Dictionary, unit: Dictionary, other: Dictionary) -> bool:
	if rule.match == "kind": return other.kind == unit.kind
	return Registry.kind(other.kind).get("class", "") == Registry.kind(unit.kind).get("class", "")

static func _set_level(sim: Simulation, unit: Dictionary, level: int) -> void:
	var combat: Dictionary = unit.combat
	var changed: bool = (combat.horde > 0) != (level > 0)
	combat.horde = level
	if changed: Combat.restart_wait(sim, combat, CombatDefinitions.weapon(CombatDefinitions.profile(unit.kind).weapon))

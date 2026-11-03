extends RefCounted

const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const REPATH_TICKS: int = 15

static func record(sim: RefCounted, id: int) -> Dictionary:
	if sim._entities.has(id): return sim._entities[id]
	return sim._buildings.get(id, {})

static func valid_target(sim: RefCounted, owner: int, target_id: int) -> bool:
	var target: Dictionary = record(sim, target_id)
	return not target.is_empty() and target.owner != owner and target.kind != "collector"

static func distance_squared(position: Vector2, target: Dictionary) -> float:
	if not target.has("origin"):
		return position.distance_squared_to(Vector2(target.position[0], target.position[1]))
	var size: Vector2i = Definitions.building(target.kind).footprint
	var nearest := Vector2(clampf(position.x, target.origin[0], target.origin[0] + size.x), clampf(position.y, target.origin[1], target.origin[1] + size.y))
	return position.distance_squared_to(nearest)

# Source: retail AIData.ini GuardOuterModifierHuman / GuardOuterModifierAI.
const GUARD_OUTER_HUMAN: float = 2.2
const GUARD_OUTER_AI: float = 1.333

static func scan_radius(sim: RefCounted, unit: Dictionary) -> float:
	var player: Variant = sim._players.get(unit.owner)
	var ai: bool = player != null and player.controller == "ai"
	return CombatDefinitions.vision(unit.kind) * (GUARD_OUTER_AI if ai else GUARD_OUTER_HUMAN)

static var _reach_by_kind: Dictionary = {}

static func _reach(kind: String) -> float:
	if not _reach_by_kind.has(kind): _reach_by_kind[kind] = CombatDefinitions.weapon(CombatDefinitions.profile(kind).weapon).range
	return _reach_by_kind[kind]

static func _in_range(sim: RefCounted, unit: Dictionary, target: Dictionary) -> bool:
	sim._combat_work += 1
	var reach: float = _reach(unit.kind)
	return distance_squared(Vector2(unit.position[0], unit.position[1]), target) <= reach * reach

static func plan(sim: RefCounted, unit_ids: Array[int]) -> void:
	var candidates: Array = []
	var held := {"ready": false, "cells": {}}
	for unit_id in unit_ids:
		var unit: Dictionary = sim._entities[unit_id]
		if unit.combat.mode == "move" and unit.status != "moving" and unit.status != "path_pending": unit.combat.mode = "guard"
		var mode: String = unit.combat.mode
		if mode == "attack":
			_pursue(sim, unit, held)
			continue
		if mode != "guard" and mode != "attack_move": continue
		var combat: Dictionary = unit.combat
		var kept: Dictionary = record(sim, combat.target_id) if combat.target_id != null else {}
		if kept.is_empty() or kept.owner == unit.owner or not _in_range(sim, unit, kept):
			combat.target_id = null
			if sim._tick >= combat.repath_tick:
				if candidates.is_empty(): candidates = _targets(sim)
				combat.target_id = _nearest(sim, unit, candidates)
				if combat.target_id == null: combat.repath_tick = sim._tick + REPATH_TICKS - (sim._tick + unit.id) % REPATH_TICKS
		if mode != "attack_move": continue
		var moving: bool = unit.status == "moving" or unit.status == "path_pending"
		if combat.target_id != null:
			if moving:
				unit.route = []
				unit.status = "idle"
				sim._path_queue.erase(unit.id)
		elif unit.status == "idle" and unit.destination != null:
			unit.status = "path_pending"
			sim._path_queue.append(unit.id)
		elif not moving:
			combat.mode = "guard"
			combat.goal = null

static func _pursue(sim: RefCounted, unit: Dictionary, held: Dictionary) -> void:
	var combat: Dictionary = unit.combat
	var target: Dictionary = record(sim, combat.target_id)
	if _in_range(sim, unit, target):
		if unit.status == "moving" or unit.status == "path_pending": sim._stop_unit(unit)
		return
	if sim._tick < combat.repath_tick: return
	combat.repath_tick = sim._tick + REPATH_TICKS
	var reach: float = _reach(unit.kind)
	if unit.destination != null and (unit.status == "moving" or unit.status == "path_pending") and distance_squared(Vector2(unit.destination[0], unit.destination[1]), target) <= reach * reach: return
	if not held.ready: _hold_cells(sim, held)
	var previous: Variant = sim._cell(unit.destination) if unit.destination != null else null
	var goal: Variant = _firing_cell(sim, unit, target, reach, held.cells)
	if previous != null: held.cells.erase(previous)
	sim._path_queue.erase(unit.id)
	if goal == null:
		sim._stop_unit(unit)
		unit.status = "blocked"
		return
	held.cells[Vector2i(goal.floor())] = true
	unit.destination = [goal.x, goal.y]
	unit.order = {"type": "move", "target": [goal.x, goal.y]}
	unit.route = []
	unit.status = "path_pending"
	sim._path_queue.append(unit.id)

static func _hold_cells(sim: RefCounted, held: Dictionary) -> void:
	held.ready = true
	for other in sim._entities.values():
		if other.kind == "collector": continue
		held.cells[sim._cell(other.position)] = true
		if other.destination != null: held.cells[sim._cell(other.destination)] = true

static func _firing_cell(sim: RefCounted, unit: Dictionary, target: Dictionary, reach: float, held: Dictionary) -> Variant:
	var position := Vector2(unit.position[0], unit.position[1])
	var component: int = sim._navigation.component_at(position)
	var low := Vector2(target.position[0], target.position[1]) if not target.has("origin") else Vector2(target.origin[0], target.origin[1])
	var high := low
	if target.has("origin"): high += Vector2(Definitions.building(target.kind).footprint)
	var own: Vector2i = sim._cell(unit.position)
	var own_goal: Variant = sim._cell(unit.destination) if unit.destination != null else null
	var occupied: Vector2i = sim._cell(target.position) if not target.has("origin") else Vector2i(-1, -1)
	var best: Variant = null
	var best_distance: float = INF
	for y in range(int(floorf(low.y - reach)), int(floorf(high.y + reach)) + 1):
		for x in range(int(floorf(low.x - reach)), int(floorf(high.x + reach)) + 1):
			var cell := Vector2i(x, y)
			var center := Vector2(cell) + Vector2(0.5, 0.5)
			sim._combat_work += 1
			if cell == occupied or component < 0 or sim._navigation.component_at(center) != component: continue
			if held.has(cell) and cell != own and cell != own_goal: continue
			if distance_squared(center, target) > reach * reach: continue
			var distance: float = position.distance_squared_to(center)
			if best == null or distance < best_distance or (distance == best_distance and (cell.y < Vector2i(best.floor()).y or (cell.y == Vector2i(best.floor()).y and cell.x < Vector2i(best.floor()).x))):
				best = center
				best_distance = distance
	return best

static func _targets(sim: RefCounted) -> Array:
	var targets: Array = []
	for entity in sim._entities.values():
		if entity.kind != "collector": targets.append(entity)
	targets.append_array(sim._buildings.values())
	return targets

static func _nearest(sim: RefCounted, unit: Dictionary, candidates: Array) -> Variant:
	var best: Variant = null
	var best_distance: float = INF
	var reach: float = _reach(unit.kind)
	var position := Vector2(unit.position[0], unit.position[1])
	for target in candidates:
		if target.owner == unit.owner: continue
		sim._combat_work += 1
		var distance: float = distance_squared(position, target)
		if distance > reach * reach: continue
		if distance < best_distance or (distance == best_distance and target.id < best):
			best = target.id
			best_distance = distance
	return best

static func fire(sim: RefCounted, unit_ids: Array[int], moved_ids: Array[int]) -> void:
	var shots: Array[Dictionary] = []
	var damage: Dictionary = {}
	var moved: Dictionary = {}
	for unit_id in moved_ids: moved[unit_id] = true
	for unit_id in unit_ids:
		if moved.has(unit_id) or not sim._entities.has(unit_id): continue
		var unit: Dictionary = sim._entities[unit_id]
		var combat: Dictionary = unit.combat
		if combat.target_id == null or sim._tick < combat.next_fire_tick: continue
		var target: Dictionary = record(sim, combat.target_id)
		if target.is_empty() or target.owner == unit.owner or not _in_range(sim, unit, target): continue
		var weapon: Dictionary = CombatDefinitions.weapon(CombatDefinitions.profile(unit.kind).weapon)
		var amount: int = weapon.damage * CombatDefinitions.armor_percent(CombatDefinitions.profile(target.kind).armor, weapon.damage_type) / 100
		shots.append({"type": "shot", "tick": sim._tick, "attacker_id": unit_id, "target_id": target.id, "damage": amount})
		damage[target.id] = damage.get(target.id, 0) + amount
		_reload(sim, combat, weapon)
	sim._combat_events.append_array(shots)
	var dead: Array = damage.keys().filter(func(id: int) -> bool: return record(sim, id).hp <= damage[id])
	for id in damage:
		var hit: Dictionary = record(sim, id)
		hit.hp = maxi(0, hit.hp - damage[id])
	dead.sort()
	for id in dead:
		sim._combat_events.append({"type": "death", "tick": sim._tick, "object_id": id})
		sim.remove_object(id)

static func _reload(sim: RefCounted, combat: Dictionary, weapon: Dictionary) -> void:
	if weapon.clip_size == 0:
		combat.next_fire_tick = sim._tick + weapon.delay_ticks
		return
	combat.shots_left -= 1
	if combat.shots_left == 0:
		combat.shots_left = weapon.clip_size
		combat.next_fire_tick = sim._tick + weapon.reload_ticks
	else:
		combat.next_fire_tick = sim._tick + weapon.delay_ticks

static func object_removed(sim: RefCounted, id: int) -> void:
	for unit in sim._entities.values():
		if unit.combat == null or unit.combat.target_id != id: continue
		unit.combat.target_id = null
		unit.combat.repath_tick = sim._tick
		if unit.combat.mode == "attack":
			unit.combat.mode = "guard"
			sim._stop_unit(unit)

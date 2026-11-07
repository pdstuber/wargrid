extends RefCounted

const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Containers = preload("res://scripts/simulation/containers.gd")
const Shared = preload("res://scripts/simulation/definitions/shared.gd")
const REPATH_TICKS: int = 8
# Zero Hour fires at range - 0.1 cells measured edge to edge; EDGE_EPS absorbs float noise at the boundary.
const RANGE_SLACK: float = 0.1
const EDGE_EPS: float = 1e-6
# Largest building radius (3x3 footprint), bounds the nearest-target grid window.
const MAX_TARGET_RADIUS: float = 2.2
# Fixed in ticks: a shorter wait lets attack_move dither at a wall (U1, cadence 8 vs 15).
const UNREACHABLE_BACKOFF_TICKS: int = 60

static func record(sim: Simulation, id: int) -> Dictionary:
	if sim._entities.has(id): return sim._entities[id]
	return sim._buildings.get(id, {})

static func hostile(sim: Simulation, a: int, b: int) -> bool:
	if a == b: return false
	var team_a: int = sim.team_of(a)
	var team_b: int = sim.team_of(b)
	return team_a == 0 or team_b == 0 or team_a != team_b

static func masked(target: Dictionary) -> bool:
	return target.has("rebuild") and target.rebuild.worker_id != null

static func valid_target(sim: Simulation, owner: int, target_id: int) -> bool:
	var target: Dictionary = record(sim, target_id)
	return not target.is_empty() and hostile(sim, owner, target.owner) and not Registry.air_kinds.has(target.kind) and not target.has("container_id") and not masked(target)

static func distance_squared(position: Vector2, target: Dictionary) -> float:
	if not target.has("origin"):
		return position.distance_squared_to(Vector2(target.position[0], target.position[1]))
	var size: Vector2i = Definitions.building(target.kind).footprint
	var nearest := Vector2(clampf(position.x, target.origin[0], target.origin[0] + size.x), clampf(position.y, target.origin[1], target.origin[1] + size.y))
	return position.distance_squared_to(nearest)

static func edge_gap(unit: Dictionary, target: Dictionary) -> float:
	return _gap_at(unit.position[0], unit.position[1], unit.kind, target)

static func _gap_at(x: float, y: float, kind: String, target: Dictionary) -> float:
	var cx: float = target.position[0] if not target.has("origin") else target.origin[0] + Definitions.building(target.kind).footprint.x * 0.5
	var cy: float = target.position[1] if not target.has("origin") else target.origin[1] + Definitions.building(target.kind).footprint.y * 0.5
	return _gap_between(x - cx, y - cy, CombatDefinitions.radius(kind), CombatDefinitions.radius(target.kind))

static func _gap_between(dx: float, dy: float, radius_a: float, radius_b: float) -> float:
	return maxf(0.0, sqrt(dx * dx + dy * dy) - radius_a - radius_b)

# Source: retail AIData.ini GuardOuterModifierHuman / GuardOuterModifierAI.
const GUARD_OUTER_HUMAN: float = 2.2
const GUARD_OUTER_AI: float = 1.333
# Source: retail AIData.ini RetaliationDistance / RetaliationFriendsRadius; leash factors from AIStates.cpp guard states.
const RETALIATION_DISTANCE: float = 8.0
const RETALIATION_FRIENDS_RADIUS: float = 4.8
const RETALIATION_TICKS: int = 300
const RETURN_SCAN_TICKS: int = 30
const LEASH_UNIT: float = 1.8
const LEASH_ATTACKER: float = 4.0

static func is_ai(sim: Simulation, owner: int) -> bool:
	var player: Variant = sim._players.get(owner)
	return player != null and player.controller == "ai"

static func scan_radius(sim: Simulation, unit: Dictionary) -> float:
	return CombatDefinitions.vision(unit.kind) * (GUARD_OUTER_AI if is_ai(sim, unit.owner) else GUARD_OUTER_HUMAN)

static var _reach_by_kind: Dictionary = {}

static func _reach(kind: String) -> float:
	if not _reach_by_kind.has(kind): _reach_by_kind[kind] = CombatDefinitions.weapon(CombatDefinitions.profile(kind).weapon).range - RANGE_SLACK
	return _reach_by_kind[kind]

static func _in_range(sim: Simulation, unit: Dictionary, target: Dictionary) -> bool:
	sim._combat_work += 1
	return _reaches(unit, target)

static func _reaches(unit: Dictionary, target: Dictionary) -> bool:
	return edge_gap(unit, target) <= _reach(unit.kind) + EDGE_EPS

static func plan(sim: Simulation, unit_ids: Array[int]) -> void:
	var grid_box := {"ready": false, "grid": {}}
	var held := {"ready": false, "cells": {}, "rings": {}}
	for unit_id in unit_ids:
		var unit: Dictionary = sim._entities[unit_id]
		if unit.has("container_id"):
			_plan_passenger(sim, unit, grid_box)
			continue
		if unit.combat.mode == "move" and unit.status != "moving" and unit.status != "path_pending" and not Containers.entering(unit): unit.combat.mode = "guard"
		var mode: String = unit.combat.mode
		if mode == "attack":
			_pursue(sim, unit, held)
			continue
		if mode == "retaliate":
			_plan_retaliate(sim, unit, held, grid_box)
			continue
		if mode != "guard" and mode != "attack_move": continue
		var combat: Dictionary = unit.combat
		var kept: Dictionary = record(sim, combat.target_id) if combat.target_id != null else {}
		var human: bool = not is_ai(sim, unit.owner)
		if not kept.is_empty() and hostile(sim, unit.owner, kept.owner) and human and _left_range(unit, kept, mode):
			combat.retarget = mode == "attack_move"
			kept = {}
		if kept.is_empty() or not hostile(sim, unit.owner, kept.owner):
			combat.target_id = null
			if sim._tick >= combat.repath_tick or combat.retarget:
				var grid: Dictionary = _grid(sim, grid_box)
				var zone: int = Profiler.begin()
				combat.target_id = _nearest(sim, unit, grid, _scan_radius_for(sim, unit, human), false, human and not unit.combat.retarget)
				Profiler.end(&"combat.nearest", zone)
				combat.retarget = false
				if combat.target_id != null and not _reaches(unit, record(sim, combat.target_id)): sim._scan_chases += 1
				if combat.target_id == null: combat.repath_tick = sim._tick + REPATH_TICKS - (sim._tick + unit.id) % REPATH_TICKS
		if combat.target_id == null:
			_end_chase(sim, unit)
		else:
			_engage(sim, unit, record(sim, combat.target_id), held)
			if unit.status == "blocked":
				combat.target_id = null
				combat.repath_tick = sim._tick + UNREACHABLE_BACKOFF_TICKS
				_end_chase(sim, unit)
		if mode != "attack_move": continue
		var moving: bool = unit.status == "moving" or unit.status == "path_pending"
		if combat.target_id != null:
			if moving and not sim._chases.has(unit.id):
				unit.route = []
				unit.status = "idle"
				sim._path_queue.erase(unit.id)
		elif unit.status == "idle" and unit.destination != null:
			unit.status = "path_pending"
			sim._path_queue.append(unit.id)
		elif not moving:
			combat.mode = "guard"
			combat.goal = null

# A passenger only shoots what is already in reach of its container; it never approaches.
static func _plan_passenger(sim: Simulation, unit: Dictionary, grid_box: Dictionary) -> void:
	var combat: Dictionary = unit.combat
	if not Containers.rules(sim._entities[unit.container_id]).passengers_fire:
		combat.target_id = null
		return
	var kept: Dictionary = record(sim, combat.target_id) if combat.target_id != null else {}
	if not kept.is_empty() and hostile(sim, unit.owner, kept.owner) and _reaches(unit, kept): return
	combat.target_id = null
	if sim._tick < combat.repath_tick: return
	combat.target_id = _nearest(sim, unit, _grid(sim, grid_box), _reach(unit.kind), false, true)
	if combat.target_id == null: combat.repath_tick = sim._tick + REPATH_TICKS - (sim._tick + unit.id) % REPATH_TICKS

static func _grid(sim: Simulation, box: Dictionary) -> Dictionary:
	if not box.ready:
		var zone: int = Profiler.begin()
		box.grid = _build_grid(sim)
		Profiler.end(&"combat.build_grid", zone)
		box.ready = true
	return box.grid

static func _scan_radius_for(sim: Simulation, unit: Dictionary, human: bool) -> float:
	return _reach(unit.kind) if human and not unit.combat.retarget else _scan_reach(sim, unit)

# An attack-move approach has no leash; only a halted (firing) unit drops a target that left weapon range.
static func _left_range(unit: Dictionary, target: Dictionary, mode: String) -> bool:
	if mode == "attack_move" and unit.status != "idle": return false
	return not _reaches(unit, target)

static func _scan_reach(sim: Simulation, unit: Dictionary) -> float:
	return maxf(scan_radius(sim, unit), _reach(unit.kind))

static func _engage(sim: Simulation, unit: Dictionary, target: Dictionary, held: Dictionary) -> void:
	if _in_range(sim, unit, target):
		if sim._chases.has(unit.id) and unit.status != "idle": _halt(sim, unit)
		return
	if not sim._chases.has(unit.id):
		sim._chases[unit.id] = unit.destination.duplicate() if unit.combat.mode == "attack_move" and unit.destination != null else null
	_approach(sim, unit, target, held)

static func _end_chase(sim: Simulation, unit: Dictionary) -> void:
	if not sim._chases.has(unit.id): return
	_halt(sim, unit)
	sim._chases.erase(unit.id)

static func _halt(sim: Simulation, unit: Dictionary) -> void:
	sim._stop_unit(unit)
	var resume: Variant = sim._chases[unit.id]
	if resume == null: return
	unit.destination = resume.duplicate()
	unit.order = {"type": "move", "target": resume.duplicate()}

static func _pursue(sim: Simulation, unit: Dictionary, held: Dictionary) -> void:
	var target: Dictionary = record(sim, unit.combat.target_id)
	if _in_range(sim, unit, target):
		if unit.status == "moving" or unit.status == "path_pending": sim._stop_unit(unit)
		return
	_approach(sim, unit, target, held)

static func _approach(sim: Simulation, unit: Dictionary, target: Dictionary, held: Dictionary) -> void:
	var combat: Dictionary = unit.combat
	if sim._tick < combat.repath_tick: return
	combat.repath_tick = sim._tick + REPATH_TICKS - (sim._tick + unit.id) % REPATH_TICKS
	var reach: float = _reach(unit.kind)
	if unit.destination != null and (unit.status == "moving" or unit.status == "path_pending") and _gap_at(unit.destination[0], unit.destination[1], unit.kind, target) <= reach + EDGE_EPS: return
	var zone: int = Profiler.begin()
	if not held.ready: _hold_cells(sim, held)
	var previous: Variant = sim._cell(unit.destination) if unit.destination != null else null
	var goal: Variant = _firing_cell(sim, unit, target, reach, held)
	Profiler.end(&"combat.firing_cell", zone)
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

static func _hold_cells(sim: Simulation, held: Dictionary) -> void:
	held.ready = true
	for other: Dictionary in sim._entities.values():
		if Registry.air_kinds.has(other.kind) or other.has("container_id"): continue
		held.cells[sim._cell(other.position)] = true
		if other.destination != null: held.cells[sim._cell(other.destination)] = true

static func _firing_cell(sim: Simulation, unit: Dictionary, target: Dictionary, reach: float, held: Dictionary) -> Variant:
	var position := Vector2(unit.position[0], unit.position[1])
	var component: int = sim._navigation.component_at(position)
	var own: Vector2i = sim._cell(unit.position)
	var own_goal: Variant = sim._cell(unit.destination) if unit.destination != null else null
	var occupied: Vector2i = sim._cell(target.position) if not target.has("origin") else Vector2i(-1, -1)
	var best: Variant = null
	var best_distance: float = INF
	var ring: Dictionary = _reach_ring(held.rings, unit.kind, target, reach)
	sim._combat_work += ring.window_cells
	for cell: Variant in ring.cells:
		var center := Vector2(cell) + Vector2(0.5, 0.5)
		var distance: float = position.distance_squared_to(center)
		if best != null and distance > best_distance: continue
		if cell == occupied or component < 0 or sim._navigation.component_at(center) != component: continue
		if held.cells.has(cell) and cell != own and cell != own_goal: continue
		if best == null or distance < best_distance or (distance == best_distance and (cell.y < Vector2i(best.floor()).y or (cell.y == Vector2i(best.floor()).y and cell.x < Vector2i(best.floor()).x))):
			best = center
			best_distance = distance
	return best

# Cells within weapon reach of the target for one attacker kind; shared by every attacker of that kind within a tick.
static func _reach_ring(rings: Dictionary, kind: String, target: Dictionary, reach: float) -> Dictionary:
	var by_kind: Dictionary = rings.get_or_add(target.id, {})
	if by_kind.has(kind): return by_kind[kind]
	var low := Vector2(target.position[0], target.position[1]) if not target.has("origin") else Vector2(target.origin[0], target.origin[1])
	var high := low
	if target.has("origin"): high += Vector2(Definitions.building(target.kind).footprint)
	var unit_radius: float = CombatDefinitions.radius(kind)
	var target_radius: float = CombatDefinitions.radius(target.kind)
	var window: float = reach + unit_radius + target_radius
	var cx: float = target.position[0] if not target.has("origin") else target.origin[0] + Definitions.building(target.kind).footprint.x * 0.5
	var cy: float = target.position[1] if not target.has("origin") else target.origin[1] + Definitions.building(target.kind).footprint.y * 0.5
	var limit: float = reach + EDGE_EPS
	var cells: Array[Vector2i] = []
	var examined: int = 0
	for y in range(int(floorf(low.y - window)), int(floorf(high.y + window)) + 1):
		for x in range(int(floorf(low.x - window)), int(floorf(high.x + window)) + 1):
			examined += 1
			if _gap_between(x + 0.5 - cx, y + 0.5 - cy, unit_radius, target_radius) <= limit: cells.append(Vector2i(x, y))
	by_kind[kind] = {"cells": cells, "window_cells": examined}
	return by_kind[kind]

const GRID_CELL: int = 8

static func _build_grid(sim: Simulation) -> Dictionary:
	var grid: Dictionary = {}
	for entity: Dictionary in sim._entities.values():
		if Registry.air_kinds.has(entity.kind) or entity.has("container_id"): continue
		_bucket(grid, int(floorf(entity.position[0] / GRID_CELL)), int(floorf(entity.position[1] / GRID_CELL)), entity)
	for building: Dictionary in sim._buildings.values():
		if masked(building): continue
		var size: Vector2i = Definitions.building(building.kind).footprint
		for y in range(int(floorf(building.origin[1] / GRID_CELL)), int(floorf((building.origin[1] + size.y) / GRID_CELL)) + 1):
			for x in range(int(floorf(building.origin[0] / GRID_CELL)), int(floorf((building.origin[0] + size.x) / GRID_CELL)) + 1):
				_bucket(grid, x, y, building)
	return grid

static func _bucket(grid: Dictionary, x: int, y: int, target: Dictionary) -> void:
	var key := Vector2i(x, y)
	if not grid.has(key): grid[key] = []
	grid[key].append(target)

# edge: radius is a weapon reach tested edge to edge; otherwise a centre scan radius.
static func _nearest(sim: Simulation, unit: Dictionary, grid: Dictionary, radius: float, units_only: bool = false, edge: bool = false) -> Variant:
	var best: Variant = null
	var best_distance: float = INF
	var position := Vector2(unit.position[0], unit.position[1])
	var window: float = radius + CombatDefinitions.radius(unit.kind) + MAX_TARGET_RADIUS if edge else radius
	for y in range(int(floorf((position.y - window) / GRID_CELL)), int(floorf((position.y + window) / GRID_CELL)) + 1):
		for x in range(int(floorf((position.x - window) / GRID_CELL)), int(floorf((position.x + window) / GRID_CELL)) + 1):
			for target: Variant in grid.get(Vector2i(x, y), []):
				if not hostile(sim, unit.owner, target.owner) or (units_only and target.has("origin")): continue
				sim._combat_work += 1
				var distance: float = edge_gap(unit, target) if edge else distance_squared(position, target)
				if distance > (radius + EDGE_EPS if edge else radius * radius): continue
				if distance < best_distance or (distance == best_distance and target.id < best):
					best = target.id
					best_distance = distance
	return best

static func fire(sim: Simulation, unit_ids: Array[int], moved_ids: Array[int]) -> void:
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
		if target.is_empty() or not hostile(sim, unit.owner, target.owner) or not _in_range(sim, unit, target): continue
		var weapon: Dictionary = CombatDefinitions.weapon(CombatDefinitions.profile(unit.kind).weapon)
		_hit(shots, damage, sim, unit_id, target, weapon, false)
		if weapon.primary_radius > 0.0: _splash(shots, damage, sim, unit, target, weapon)
		_reload(sim, combat, weapon)
		_ramp_after_shot(sim, combat, weapon)
	sim._combat_events.append_array(shots)
	var dead: Array = damage.keys().filter(func(id: int) -> bool: return record(sim, id).hp <= damage[id])
	for id: Variant in damage:
		var hit: Dictionary = record(sim, id)
		hit.hp = maxi(0, hit.hp - damage[id])
	var zone: int = Profiler.begin()
	_retaliate_trigger(sim, shots)
	Profiler.end(&"combat.retaliate", zone)
	dead.sort()
	for id: Variant in dead:
		sim._combat_events.append({"type": "death", "tick": sim._tick, "object_id": id})
		sim.remove_object(id)

# Retail Patriot MinIdleScanInterval = MaxIdleScanInterval = 250 ms (INIZH.big factionbuilding.ini) = 8 ticks, so no random draw.
const DEFENCE_SCAN_TICKS: int = 8

static func fire_defences(sim: Simulation) -> void:
	var ids: Array = []
	for id: int in sim._buildings:
		if sim._buildings[id].completed and sim._buildings[id].has("combat"): ids.append(id)
	if ids.is_empty(): return
	ids.sort()
	var shots: Array[Dictionary] = []
	var damage: Dictionary = {}
	var dark: Dictionary = {}
	for id: int in ids:
		var building: Dictionary = sim._buildings[id]
		if _is_dark(sim, building, dark): continue
		var combat: Dictionary = building.combat
		var weapon: Dictionary = CombatDefinitions.weapon(CombatDefinitions.profile(building.kind).weapon)
		if not _defence_target_valid(sim, building):
			combat.target_id = null
			if sim._tick >= combat.get("scan_tick", 0):
				combat.target_id = _defence_pick(sim, building, weapon)
				combat.scan_tick = sim._tick + DEFENCE_SCAN_TICKS
		if combat.target_id == null or sim._tick < combat.next_fire_tick: continue
		_hit(shots, damage, sim, id, record(sim, combat.target_id), weapon, false)
		if weapon.primary_radius > 0.0: _splash(shots, damage, sim, building, record(sim, combat.target_id), weapon)
		_reload(sim, combat, weapon)
		_ramp_after_shot(sim, combat, weapon)
	sim._combat_events.append_array(shots)
	var dead: Array = damage.keys().filter(func(target: int) -> bool: return record(sim, target).hp <= damage[target])
	for target: Variant in damage: record(sim, target).hp = maxi(0, record(sim, target).hp - damage[target])
	_retaliate_trigger(sim, shots)
	dead.sort()
	for target: Variant in dead:
		sim._combat_events.append({"type": "death", "tick": sim._tick, "object_id": target})
		sim.remove_object(target)

static func _is_dark(sim: Simulation, building: Dictionary, cache: Dictionary) -> bool:
	if not Registry.kind(building.kind).get("powered", false): return false
	if not cache.has(building.owner): cache[building.owner] = _short_of_power(sim, building.owner)
	return cache[building.owner]

static func _short_of_power(sim: Simulation, owner: int) -> bool:
	var balance: int = 0
	for building: Dictionary in sim._buildings.values():
		if building.owner == owner and building.completed: balance += Definitions.building(building.kind).power
	return balance < 0

static func _defence_gap(building: Dictionary, target: Dictionary) -> float:
	var from: Vector2 = _victim_centre(building)
	var to: Vector2 = _victim_centre(target)
	return _gap_between(to.x - from.x, to.y - from.y, CombatDefinitions.radius(building.kind), CombatDefinitions.radius(target.kind))

static func _defence_in_reach(building: Dictionary, target: Dictionary, weapon_range: float) -> bool:
	return _defence_gap(building, target) <= weapon_range - RANGE_SLACK + EDGE_EPS

static func defence_attack_error(sim: Simulation, command: Dictionary) -> String:
	var building: Dictionary = sim._buildings.get(command.building_id, {})
	if building.is_empty() or building.owner != command.player or not building.completed or not building.has("combat"): return "Invalid owned defence"
	if not valid_target(sim, command.player, command.target_id): return "Invalid attack target"
	var weapon: Dictionary = CombatDefinitions.weapon(CombatDefinitions.profile(building.kind).weapon)
	return "" if _defence_in_reach(building, record(sim, command.target_id), weapon.range) else "Target out of range"

static func _defence_target_valid(sim: Simulation, building: Dictionary) -> bool:
	var id: Variant = building.combat.target_id
	if id == null or not valid_target(sim, building.owner, id): return false
	return _defence_in_reach(building, record(sim, id), CombatDefinitions.weapon(CombatDefinitions.profile(building.kind).weapon).range)

# shortcut: scans every object per due scan (every 8 ticks); grid it if the defences layout still shows in the ledger.
static func _defence_pick(sim: Simulation, building: Dictionary, weapon: Dictionary) -> Variant:
	var best: Variant = null
	var best_gap: float = INF
	for pool: Variant in [sim._entities, sim._buildings]:
		for target: Dictionary in pool.values():
			if not valid_target(sim, building.owner, target.id): continue
			sim._combat_work += 1
			var gap: float = _defence_gap(building, target)
			if gap > weapon.range - RANGE_SLACK + EDGE_EPS: continue
			if gap < best_gap or (gap == best_gap and target.id < best):
				best = target.id
				best_gap = gap
	return best

static func _hit(shots: Array[Dictionary], damage: Dictionary, sim: Simulation, attacker_id: int, target: Dictionary, weapon: Dictionary, splash: bool) -> void:
	var amount: int = weapon.damage * CombatDefinitions.armor_percent(CombatDefinitions.profile(target.kind).armor, weapon.damage_type) / 100
	shots.append({"type": "shot", "tick": sim._tick, "attacker_id": attacker_id, "target_id": target.id, "damage": amount, "splash": splash})
	damage[target.id] = damage.get(target.id, 0) + amount

# Against infantry the shell lands at a seeded point (uniform angle and radius) and blasts a wider radius.
static func _splash(shots: Array[Dictionary], damage: Dictionary, sim: Simulation, unit: Dictionary, target: Dictionary, weapon: Dictionary) -> void:
	var impact: Vector2 = _victim_centre(target)
	var radius: float = weapon.primary_radius
	if Registry.kind(target.kind).get("class", "") == "infantry":
		impact += _scatter(sim) * CombatDefinitions.SCATTER_VS_INFANTRY * sim.next_random() / 4294967296.0
		radius = CombatDefinitions.INFANTRY_BLAST
	for victim in splash_victims(sim, impact, radius, weapon.affects, unit):
		if victim.id != target.id: _hit(shots, damage, sim, unit.id, victim, weapon, true)

static func _scatter(sim: Simulation) -> Vector2:
	while true:
		var d := Vector2(sim.next_random() / 2147483648.0 - 1.0, sim.next_random() / 2147483648.0 - 1.0)
		var squared: float = d.length_squared()
		if squared > 1e-12 and squared <= 1.0: return d / sqrt(squared)
	return Vector2.ZERO

# shortcut: scans every object per cannon shot; grid it if cannon shots x objects shows in the ledger.
static func splash_victims(sim: Simulation, impact: Vector2, radius: float, affects: Array, attacker: Dictionary) -> Array[Dictionary]:
	var victims: Array[Dictionary] = []
	for pool: Variant in [sim._entities, sim._buildings]:
		for victim: Variant in pool.values():
			if victim.id == attacker.id or Registry.air_kinds.has(victim.kind) or victim.has("container_id") or masked(victim): continue
			if (_victim_centre(victim).distance_to(impact) - CombatDefinitions.radius(victim.kind)) > radius + EDGE_EPS: continue
			if affects.has("enemies" if hostile(sim, attacker.owner, victim.owner) else "allies"): victims.append(victim)
	victims.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return victims

# shortcut: horde wins over ramp; combine them when a kind has both.
static func bonus_delay(combat: Dictionary, weapon: Dictionary, ticks: int) -> int:
	var percent: int = 100
	if combat.get("horde", 0) > 0: percent = Shared.HORDE_RATE_PERCENT
	elif combat.get("ramp_level", 0) > 0: percent = weapon.ramp.percent[combat.ramp_level - 1]
	@warning_ignore("integer_division")
	return ticks * 100 / percent

# FiringTracker.cpp: shots on one target (or a switch inside the coast) raise the rate; a pause past the coast drops it.
static func _ramp_after_shot(sim: Simulation, combat: Dictionary, weapon: Dictionary) -> void:
	if not weapon.has("ramp"): return
	var ramp: Dictionary = weapon.ramp
	var old_level: int = combat.ramp_level
	var tick: int = sim._tick
	if combat.ramp_until != 0 and tick > combat.ramp_until: _ramp_cool(combat)
	if combat.target_id == combat.ramp_target:
		combat.ramp_shots += 1
	elif tick < combat.ramp_until:
		combat.ramp_shots += 1
		combat.ramp_target = combat.target_id
	else:
		combat.ramp_shots = 1
		combat.ramp_target = combat.target_id
	combat.ramp_until = combat.next_fire_tick + ramp.coast_ticks
	if combat.ramp_level == 0:
		if combat.ramp_shots > ramp.shots[0]: combat.ramp_level = 1
	elif combat.ramp_level == 1:
		if combat.ramp_shots < ramp.shots[0]: _ramp_cool(combat)
		elif combat.ramp_shots > ramp.shots[1]: combat.ramp_level = 2
	elif combat.ramp_shots < ramp.shots[1]: _ramp_cool(combat)
	if combat.ramp_level != old_level: restart_wait(sim, combat, weapon)

static func _ramp_cool(combat: Dictionary) -> void:
	combat.ramp_level = 0
	combat.ramp_shots = 0
	combat.ramp_target = null

# Object.cpp:4674-4684: a bonus change restarts the wait that is pending, at the new rate.
static func restart_wait(sim: Simulation, combat: Dictionary, weapon: Dictionary) -> void:
	if combat.next_fire_tick <= sim._tick: return
	var reloading: bool = weapon.clip_size > 0 and combat.shots_left == weapon.clip_size
	combat.next_fire_tick = sim._tick + bonus_delay(combat, weapon, weapon.reload_ticks if reloading else weapon.delay_ticks)

static func _reload(sim: Simulation, combat: Dictionary, weapon: Dictionary) -> void:
	if weapon.clip_size == 0:
		combat.next_fire_tick = sim._tick + bonus_delay(combat, weapon, weapon.delay_ticks)
		return
	combat.shots_left -= 1
	if combat.shots_left == 0:
		combat.shots_left = weapon.clip_size
		combat.next_fire_tick = sim._tick + bonus_delay(combat, weapon, weapon.reload_ticks)
	else:
		combat.next_fire_tick = sim._tick + bonus_delay(combat, weapon, weapon.delay_ticks)

static func object_removed(sim: Simulation, id: int) -> void:
	for unit: Dictionary in sim._entities.values():
		if unit.combat == null or unit.combat.target_id != id: continue
		unit.combat.target_id = null
		unit.combat.repath_tick = sim._tick
		unit.combat.retarget = unit.combat.mode == "attack_move" and not is_ai(sim, unit.owner)
		if unit.combat.mode == "retaliate":
			_go_home(sim, unit)
		if unit.combat.mode == "attack":
			unit.combat.mode = "guard"
			sim._stop_unit(unit)

static func _is_idle_guard(unit: Dictionary) -> bool:
	return unit.combat.mode == "guard" and unit.combat.target_id == null and unit.status != "moving" and unit.status != "path_pending"

static func _victim_centre(victim: Dictionary) -> Vector2:
	if not victim.has("origin"): return Vector2(victim.position[0], victim.position[1])
	return Vector2(victim.origin[0], victim.origin[1]) + Vector2(Definitions.building(victim.kind).footprint) * 0.5

static func _friends_radius(victim: Dictionary) -> float:
	if not victim.has("origin"): return RETALIATION_FRIENDS_RADIUS
	return RETALIATION_FRIENDS_RADIUS + 0.5 * Vector2(Definitions.building(victim.kind).footprint).length()

# shortcut: joiners are scanned per shot among units that can still join (idle guards, target-less retaliators); grid them if idle guards x shots shows in the ledger.
static func _retaliate_trigger(sim: Simulation, shots: Array[Dictionary]) -> void:
	var armed: Array = []
	var built: bool = false
	for shot in shots:
		var victim: Dictionary = record(sim, shot.target_id)
		var attacker: Dictionary = record(sim, shot.attacker_id)
		if victim.is_empty() or attacker.is_empty() or is_ai(sim, victim.owner) or not hostile(sim, victim.owner, attacker.owner): continue
		if distance_squared(_victim_centre(attacker), victim) > RETALIATION_DISTANCE * RETALIATION_DISTANCE: continue
		if not built:
			built = true
			for unit: Dictionary in sim._entities.values():
				if unit.combat != null and _can_join(unit): armed.append(unit)
			armed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
		var centre := _victim_centre(victim)
		var radius: float = _friends_radius(victim)
		for unit: Variant in armed:
			sim._combat_work += 1
			if unit.owner != victim.owner or unit.hp <= 0: continue
			if unit.id == victim.id and unit.combat.mode == "retaliate" and unit.combat.target_id == null:
				_retarget_retaliation(sim, unit, attacker)
			elif _is_idle_guard(unit) and Vector2(unit.position[0], unit.position[1]).distance_squared_to(centre) <= radius * radius:
				_join_retaliation(sim, unit, attacker)

static func _can_join(unit: Dictionary) -> bool:
	return not unit.has("container_id") and (_is_idle_guard(unit) or (unit.combat.mode == "retaliate" and unit.combat.target_id == null))

static func _retarget_retaliation(sim: Simulation, unit: Dictionary, attacker: Dictionary) -> void:
	unit.combat.target_id = attacker.id
	unit.combat.until = sim._tick + RETALIATION_TICKS
	unit.combat.repath_tick = sim._tick

static func _join_retaliation(sim: Simulation, unit: Dictionary, attacker: Dictionary) -> void:
	unit.combat.mode = "retaliate"
	unit.combat.goal = unit.position.duplicate()
	_retarget_retaliation(sim, unit, attacker)
	sim._retaliations += 1

static func _go_home(sim: Simulation, unit: Dictionary) -> void:
	unit.combat.target_id = null
	unit.combat.repath_tick = sim._tick + RETURN_SCAN_TICKS
	var members: Array[Dictionary] = [unit]
	sim._path_queue.erase(unit.id)
	sim._assign_move(members, unit.combat.goal)

static func _plan_retaliate(sim: Simulation, unit: Dictionary, held: Dictionary, grid_box: Dictionary) -> void:
	var combat: Dictionary = unit.combat
	var home := Vector2(combat.goal[0], combat.goal[1])
	var vision: float = CombatDefinitions.vision(unit.kind)
	if combat.target_id == null:
		_plan_return(sim, unit, home, vision, grid_box)
		return
	var attacker: Dictionary = record(sim, combat.target_id)
	var away: bool = Vector2(unit.position[0], unit.position[1]).distance_squared_to(home) > pow(vision * LEASH_UNIT, 2)
	if attacker.is_empty() or away or sim._tick >= combat.until or distance_squared(home, attacker) > pow(vision * LEASH_ATTACKER, 2):
		_go_home(sim, unit)
		return
	_pursue(sim, unit, held)
	if unit.status == "blocked": _go_home(sim, unit)

static func _plan_return(sim: Simulation, unit: Dictionary, home: Vector2, vision: float, grid_box: Dictionary) -> void:
	var combat: Dictionary = unit.combat
	if unit.status != "moving" and unit.status != "path_pending":
		combat.mode = "guard"
		combat.goal = null
		return
	if sim._tick < combat.repath_tick: return
	combat.repath_tick = sim._tick + RETURN_SCAN_TICKS
	var scout := {"position": [home.x, home.y], "owner": unit.owner}
	var found: Variant = _nearest(sim, scout, _grid(sim, grid_box), vision * LEASH_UNIT, true)
	if found == null: return
	combat.target_id = found
	combat.until = sim._tick + RETALIATION_TICKS
	combat.repath_tick = sim._tick

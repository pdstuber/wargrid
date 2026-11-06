extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")

const START_CREDITS: int = 10000
const DECISION_TICKS: int = 30
const ATTACK_TICK: int = 5400
const DEFENCE_RADIUS: float = 10.0
const BUILD_ORDER: Array[String] = ["usa_power_plant", "usa_supply_center", "usa_barracks", "usa_factory"]
const MAP_PATH := "res://data/maps/skirmish.json"
const UNIT_FOR := {"usa_barracks": "usa_rifle_infantry", "usa_factory": "usa_tank"}
const TARGET_CATEGORIES: Array = [["usa_builder"], ["usa_barracks", "usa_factory"], ["usa_supply_center"], ["usa_power_plant"]]

static var _skirmish_map: Dictionary = {}

static func origin(kind: String, player: int) -> Vector2i:
	return MapData.slot(_default_map(), player, kind)

static func _default_map() -> Dictionary:
	if _skirmish_map.is_empty(): _skirmish_map = MapData.load(MAP_PATH)
	return _skirmish_map

static func _slot(sim: RefCounted, kind: String, player: int) -> Vector2i:
	var map: Dictionary = sim.map_data()
	return MapData.slot(map if not map.is_empty() else _default_map(), player, kind)

static func create(with_match: bool = true, second_controller: String = "ai") -> Simulation:
	var seats: Array[Dictionary] = [
		{"seat": 1, "team": 1, "controller": "human", "credits": START_CREDITS},
		{"seat": 2, "team": 2, "controller": second_controller, "credits": START_CREDITS}]
	var sim: Simulation = MapData.create(_default_map(), seats)
	if with_match: sim.start_match([1, 2] as Array[int])
	return sim

static func issue_opponent(sim: RefCounted, player: int = 2, attack_tick: int = ATTACK_TICK) -> void:
	issue_opponents(sim, [player], attack_tick)

static func issue_opponents(sim: RefCounted, players: Array[int], attack_tick: int = ATTACK_TICK) -> void:
	if sim.tick() % DECISION_TICKS != 0: return
	var zone: int = Profiler.begin()
	var state: Dictionary = sim.snapshot()
	for player in players: _decide(sim, player, attack_tick, state)
	Profiler.end(&"opponent.decide", zone)

static func _decide(sim: RefCounted, player: int, attack_tick: int, state: Dictionary) -> void:
	var sequence: int = -1
	for entry: Variant in state.last_sequences:
		if entry.player == player: sequence = entry.sequence
	var credits: int = 0
	for entry: Dictionary in state.players:
		if entry.id == player: credits = entry.credits
	var teams := {}
	for entry: Dictionary in state.players: teams[entry.id] = entry.team
	var ctx := {"sim": sim, "player": player, "tick": state.tick, "sequence": sequence, "credits": credits, "teams": teams}
	var buildings: Array = state.buildings.filter(func(building: Dictionary) -> bool: return building.owner == player)
	_build(ctx, state, buildings)
	_produce(ctx, buildings)
	var defending: Dictionary = _defend(ctx, state, buildings)
	if state.tick >= attack_tick: _attack(ctx, state, defending)

static func _send(ctx: Dictionary, payload: Dictionary) -> bool:
	payload.tick = ctx.tick
	payload.player = ctx.player
	payload.sequence = ctx.sequence + 1
	if not ctx.sim.issue_command(payload).ok: return false
	ctx.sequence += 1
	return true

static func _build(ctx: Dictionary, state: Dictionary, buildings: Array) -> void:
	var builder: int = -1
	for unit: Dictionary in state.entities:
		if unit.owner == ctx.player and unit.kind == "usa_builder":
			builder = unit.id
			break
	if builder == -1: return
	for building: Variant in buildings:
		if building.completed: continue
		if building.builder_id == null: _send(ctx, {"type": "resume_build", "builder_id": builder, "building_id": building.id})
		return
	for kind in BUILD_ORDER:
		if buildings.any(func(building: Dictionary) -> bool: return building.kind == kind): continue
		var cost: int = Definitions.building(kind).cost
		var site: Vector2i = _slot(ctx.sim, kind, ctx.player)
		if ctx.credits >= cost and _send(ctx, {"type": "build", "builder_id": builder, "building_kind": kind, "origin": [site.x, site.y]}): ctx.credits -= cost
		return

static func _produce(ctx: Dictionary, buildings: Array) -> void:
	for building: Variant in buildings:
		if not building.completed or not building.queue.is_empty() or not UNIT_FOR.has(building.kind): continue
		var cost: int = Definitions.unit(UNIT_FOR[building.kind]).cost
		if ctx.credits >= cost and _send(ctx, {"type": "produce", "building_id": building.id, "unit_kind": UNIT_FOR[building.kind]}): ctx.credits -= cost

static func _attack(ctx: Dictionary, state: Dictionary, skip: Dictionary = {}) -> void:
	var enemies: Array = state.entities.filter(func(unit: Dictionary) -> bool: return _hostile(ctx, unit.owner) and unit.kind != "usa_collector")
	enemies.append_array(state.buildings.filter(func(building: Dictionary) -> bool: return _hostile(ctx, building.owner)))
	var groups := {}
	for unit: Dictionary in state.entities:
		if unit.owner != ctx.player or skip.has(unit.id) or not _idle(unit): continue
		var target: Variant = _pick(unit, enemies)
		if target == null: continue
		if not groups.has(target): groups[target] = []
		groups[target].append(unit.id)
	var targets: Array = groups.keys()
	targets.sort()
	for target: Variant in targets: _send(ctx, {"type": "attack", "entity_ids": groups[target], "target_id": target})

static func _hostile(ctx: Dictionary, owner: int) -> bool:
	return owner != ctx.player and ctx.teams.get(owner, 0) != ctx.teams.get(ctx.player, -1)

static func _idle(unit: Dictionary) -> bool:
	return unit.combat != null and unit.combat.mode == "guard" and unit.combat.target_id == null

static func _defend(ctx: Dictionary, state: Dictionary, buildings: Array) -> Dictionary:
	var intruders: Array = state.entities.filter(func(unit: Dictionary) -> bool:
		if not _hostile(ctx, unit.owner) or unit.kind == "usa_collector": return false
		var at := Vector2(unit.position[0], unit.position[1])
		return buildings.any(func(building: Dictionary) -> bool: return Combat.distance_squared(at, building) <= DEFENCE_RADIUS * DEFENCE_RADIUS))
	var sent := {}
	if intruders.is_empty(): return sent
	var groups := {}
	for unit: Dictionary in state.entities:
		if unit.owner != ctx.player or not _idle(unit): continue
		var target: Variant = _nearest(unit, intruders)
		if not groups.has(target): groups[target] = []
		groups[target].append(unit.id)
	var targets: Array = groups.keys()
	targets.sort()
	for target: Variant in targets:
		if not _send(ctx, {"type": "attack", "entity_ids": groups[target], "target_id": target}): continue
		for id: Variant in groups[target]: sent[id] = true
	return sent

static func _pick(unit: Dictionary, enemies: Array) -> Variant:
	var position := Vector2(unit.position[0], unit.position[1])
	for category: Variant in TARGET_CATEGORIES:
		var best: Variant = null
		var best_distance: float = INF
		for enemy: Variant in enemies:
			if not category.has(enemy.kind): continue
			var distance: float = Combat.distance_squared(position, enemy)
			if distance < best_distance or (distance == best_distance and enemy.id < best):
				best = enemy.id
				best_distance = distance
		if best != null: return best
	return null

static func _nearest(unit: Dictionary, enemies: Array) -> int:
	var position := Vector2(unit.position[0], unit.position[1])
	var best: int = -1
	var best_distance: float = INF
	for enemy: Variant in enemies:
		var distance: float = Combat.distance_squared(position, enemy)
		if distance < best_distance or (distance == best_distance and enemy.id < best):
			best = enemy.id
			best_distance = distance
	return best

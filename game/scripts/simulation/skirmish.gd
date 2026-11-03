extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")

const SIZE := Vector2i(48, 32)
const START_CREDITS: int = 10000
const DECISION_TICKS: int = 30
const ATTACK_TICK: int = 5400
const BUILD_ORDER: Array[String] = ["reactor", "depot", "barracks", "factory"]
const LEFT_ORIGINS := {"reactor": Vector2i(8, 12), "depot": Vector2i(8, 5), "barracks": Vector2i(12, 12), "factory": Vector2i(12, 18)}
const UNIT_FOR := {"barracks": "infantry", "factory": "tank"}
const TARGET_CATEGORIES: Array = [["builder"], ["barracks", "factory"], ["depot"], ["reactor"]]

static func origin(kind: String, player: int) -> Vector2i:
	var left: Vector2i = LEFT_ORIGINS[kind]
	if player == 1: return left
	return Vector2i(SIZE.x - left.x - Definitions.building(kind).footprint.x, left.y)

static func create(with_match: bool = true) -> RefCounted:
	var sim = Simulation.new([], SIZE)
	sim.add_player(1, START_CREDITS)
	sim.add_player(2, START_CREDITS, "ai")
	sim.spawn(1, Vector2(4.5, 14.5), "builder")
	sim.spawn(2, Vector2(43.5, 14.5), "builder")
	sim.add_supply_source(Vector2i(5, 3), 200)
	sim.add_supply_source(Vector2i(40, 3), 200)
	if with_match: sim.start_match([1, 2] as Array[int])
	return sim

static func issue_opponent(sim: RefCounted, player: int = 2, attack_tick: int = ATTACK_TICK) -> void:
	if sim.tick() % DECISION_TICKS != 0: return
	var state: Dictionary = sim.snapshot()
	var sequence: int = -1
	for entry in state.last_sequences:
		if entry.player == player: sequence = entry.sequence
	var credits: int = 0
	for entry in state.players:
		if entry.id == player: credits = entry.credits
	var ctx := {"sim": sim, "player": player, "tick": state.tick, "sequence": sequence, "credits": credits}
	var buildings: Array = state.buildings.filter(func(building: Dictionary) -> bool: return building.owner == player)
	_build(ctx, state, buildings)
	_produce(ctx, buildings)
	if state.tick >= attack_tick: _attack(ctx, state)

static func _send(ctx: Dictionary, payload: Dictionary) -> bool:
	payload.tick = ctx.tick
	payload.player = ctx.player
	payload.sequence = ctx.sequence + 1
	if not ctx.sim.issue_command(payload).ok: return false
	ctx.sequence += 1
	return true

static func _build(ctx: Dictionary, state: Dictionary, buildings: Array) -> void:
	var builder: int = -1
	for unit in state.entities:
		if unit.owner == ctx.player and unit.kind == "builder":
			builder = unit.id
			break
	if builder == -1: return
	for building in buildings:
		if building.completed: continue
		if building.builder_id == null: _send(ctx, {"type": "resume_build", "builder_id": builder, "building_id": building.id})
		return
	for kind in BUILD_ORDER:
		if buildings.any(func(building: Dictionary) -> bool: return building.kind == kind): continue
		var cost: int = Definitions.building(kind).cost
		var site: Vector2i = origin(kind, ctx.player)
		if ctx.credits >= cost and _send(ctx, {"type": "build", "builder_id": builder, "building_kind": kind, "origin": [site.x, site.y]}): ctx.credits -= cost
		return

static func _produce(ctx: Dictionary, buildings: Array) -> void:
	for building in buildings:
		if not building.completed or not building.queue.is_empty() or not UNIT_FOR.has(building.kind): continue
		var cost: int = Definitions.unit(UNIT_FOR[building.kind]).cost
		if ctx.credits >= cost and _send(ctx, {"type": "produce", "building_id": building.id, "unit_kind": UNIT_FOR[building.kind]}): ctx.credits -= cost

static func _attack(ctx: Dictionary, state: Dictionary) -> void:
	var enemies: Array = state.entities.filter(func(unit: Dictionary) -> bool: return unit.owner != ctx.player and unit.kind != "collector")
	enemies.append_array(state.buildings.filter(func(building: Dictionary) -> bool: return building.owner != ctx.player))
	var groups := {}
	for unit in state.entities:
		if unit.owner != ctx.player or unit.combat == null or unit.combat.mode != "guard" or unit.combat.target_id != null: continue
		var target: Variant = _pick(unit, enemies)
		if target == null: continue
		if not groups.has(target): groups[target] = []
		groups[target].append(unit.id)
	var targets: Array = groups.keys()
	targets.sort()
	for target in targets: _send(ctx, {"type": "attack", "entity_ids": groups[target], "target_id": target})

static func _pick(unit: Dictionary, enemies: Array) -> Variant:
	var position := Vector2(unit.position[0], unit.position[1])
	for category in TARGET_CATEGORIES:
		var best: Variant = null
		var best_distance: float = INF
		for enemy in enemies:
			if not category.has(enemy.kind): continue
			var distance: float = Combat.distance_squared(position, enemy)
			if distance < best_distance or (distance == best_distance and enemy.id < best):
				best = enemy.id
				best_distance = distance
		if best != null: return best
	return null

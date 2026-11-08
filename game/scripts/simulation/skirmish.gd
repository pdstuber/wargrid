extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

const START_CREDITS: int = 10000
const DECISION_TICKS: int = 30
const ATTACK_TICK: int = 5400
const DEFENCE_RADIUS: float = 10.0
const WAVE_MIN: int = 6
const WAVE_TIMEOUT: int = 1800
const RALLY_RADIUS: float = 6.0
const DISTANCE_STEP: float = 4.0
# FRC bot: one builder plus six gatherers (user 2026-11-07); only for a faction whose start unit also collects.
const LABORERS: int = 7
const BOT_META := &"skirmish_bot"
const MAP_PATH := "res://data/maps/skirmish.json"

static var _skirmish_map: Dictionary = {}

static func default_faction() -> String:
	return Registry.Factions.DEFAULT_FACTION

static func build_order(faction: String) -> Array:
	return Registry.faction(faction).build_order

static func unit_for(faction: String, producer: String, owned: Array = []) -> String:
	var units: Array = Registry.faction(faction).units_for.get(producer, [])
	var pick: String = ""
	for kind: String in units:
		if pick.is_empty() or owned.count(kind) < owned.count(pick): pick = kind
	return pick

static func origin(kind: String, player: int) -> Vector2i:
	return MapData.slot(_default_map(), player, kind)

static func _default_map() -> Dictionary:
	if _skirmish_map.is_empty(): _skirmish_map = MapData.load(MAP_PATH)
	return _skirmish_map

static func _slot(sim: RefCounted, kind: String, player: int) -> Vector2i:
	var map: Dictionary = sim.map_data()
	return MapData.slot(map if not map.is_empty() else _default_map(), player, kind)

static func create(with_match: bool = true, second_controller: String = "ai", factions: Dictionary = Registry.Factions.DEFAULT_SKIRMISH, map_path: String = MAP_PATH, starts: Array[int] = []) -> Simulation:
	var seats: Array[Dictionary] = [
		{"seat": 1, "team": 1, "controller": "human", "credits": START_CREDITS},
		{"seat": 2, "team": 2, "controller": second_controller, "credits": START_CREDITS}]
	for seat in seats:
		if factions.has(seat.seat): seat.faction = factions[seat.seat]
		seat.defer = factions.is_empty()
	var map: Dictionary = _default_map() if map_path == MAP_PATH else MapData.load(map_path)
	if not starts.is_empty():
		map = MapData.with_starts(map, starts)
		if map.is_empty(): push_error("Chosen starts not on map: " + str(starts))
	var sim: Simulation = MapData.create(map, seats)
	if not with_match: return sim
	if factions.is_empty(): sim.begin_setup([1, 2] as Array[int])
	else: sim.start_match([1, 2] as Array[int])
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
	var faction: String = _faction(state, player)
	_build(ctx, state, buildings, faction)
	_produce(ctx, state, buildings, faction)
	var defending: Dictionary = _defend(ctx, state, buildings)
	if state.tick >= attack_tick: _attack(ctx, state, defending)

static func _send(ctx: Dictionary, payload: Dictionary) -> bool:
	payload.tick = ctx.tick
	payload.player = ctx.player
	payload.sequence = ctx.sequence + 1
	if not ctx.sim.issue_command(payload).ok: return false
	ctx.sequence += 1
	return true

static func _build(ctx: Dictionary, state: Dictionary, buildings: Array, faction: String) -> void:
	var builder: int = -1
	for unit: Dictionary in state.entities:
		if unit.owner == ctx.player and Registry.is_builder(unit.kind) and not unit.has("hole_id"):
			builder = unit.id
			break
	if builder == -1: return
	for building: Variant in buildings:
		if building.completed or building.has("hole_id"): continue
		if building.builder_id == null: _send(ctx, {"type": "resume_build", "builder_id": builder, "building_id": building.id})
		return
	for kind: String in build_order(faction):
		if buildings.any(func(building: Dictionary) -> bool: return building.kind == kind or building.get("rebuild", {}).get("kind") == kind): continue
		var cost: int = Definitions.building(kind).cost
		var site: Vector2i = _slot(ctx.sim, kind, ctx.player)
		if ctx.credits >= cost and _send(ctx, {"type": "build", "builder_id": builder, "building_kind": kind, "origin": [site.x, site.y]}): ctx.credits -= cost
		return

static func _produce(ctx: Dictionary, state: Dictionary, buildings: Array, faction: String) -> void:
	var mine: Array = state.entities.filter(func(unit: Dictionary) -> bool: return unit.owner == ctx.player and not unit.has("hole_id"))
	var replace_builder: bool = not mine.any(func(unit: Dictionary) -> bool: return Registry.is_builder(unit.kind))
	var start_unit: String = Registry.faction(faction).start_unit
	var gatherers: bool = not Registry.collects(start_unit).is_empty()
	var owned: Array = mine.map(func(unit: Dictionary) -> String: return unit.kind)
	for building: Variant in buildings:
		if not building.completed or not building.queue.is_empty(): continue
		var row: Dictionary = Registry.kind(building.kind)
		var kind: String = unit_for(faction, building.kind, owned)
		if row.produces.has(start_unit) and (replace_builder or (gatherers and row.receives_supply and owned.count(start_unit) < LABORERS)): kind = start_unit
		if kind.is_empty(): continue
		var cost: int = Definitions.unit(kind).cost
		if ctx.credits >= cost and _send(ctx, {"type": "produce", "building_id": building.id, "unit_kind": kind}):
			ctx.credits -= cost
			owned.append(kind)
		if kind == start_unit: replace_builder = false

static func _faction(state: Dictionary, player: int) -> String:
	for entry: Dictionary in state.players:
		if entry.id == player: return entry.get("faction", Registry.Factions.DEFAULT_FACTION)
	return Registry.Factions.DEFAULT_FACTION

static func _attack(ctx: Dictionary, state: Dictionary, skip: Dictionary = {}) -> void:
	var enemies: Array = state.entities.filter(func(unit: Dictionary) -> bool: return _hostile(ctx, unit.owner) and not Registry.air_kinds.has(unit.kind) and not unit.has("container_id"))
	enemies.append_array(state.buildings.filter(func(building: Dictionary) -> bool: return _hostile(ctx, building.owner) and not Combat.masked(building)))
	var mine := {}
	for unit: Dictionary in state.entities:
		if unit.owner == ctx.player: mine[unit.id] = unit
	var bot: Dictionary = _bot(ctx.sim, ctx.player)
	_drive_waves(ctx, bot, mine, enemies, skip)
	_gather(ctx, bot, mine, enemies, skip)

static func _bot(seat_or_sim: RefCounted, player: int) -> Dictionary:
	var sim: RefCounted = seat_or_sim.simulation() if seat_or_sim.has_method("simulation") else seat_or_sim # a seat wrapper is rebuilt every decision
	if not sim.has_meta(BOT_META): sim.set_meta(BOT_META, {})
	return sim.get_meta(BOT_META).get_or_add(player, {"since": -1, "waves": []})

static func _drive_waves(ctx: Dictionary, bot: Dictionary, mine: Dictionary, enemies: Array, skip: Dictionary) -> void:
	var live: Array = []
	for wave: Dictionary in bot.waves:
		wave.ids = wave.ids.filter(func(id: int) -> bool: return mine.has(id))
		if wave.ids.is_empty(): continue
		if not enemies.any(func(enemy: Dictionary) -> bool: return enemy.id == wave.target):
			var target: Variant = _pick(_centre(wave.ids, mine), enemies)
			if target == null: continue
			wave.target = target
		live.append(wave)
		var idle: Array = wave.ids.filter(func(id: int) -> bool: return not skip.has(id) and _idle(mine[id]))
		if not idle.is_empty(): _send(ctx, {"type": "attack", "entity_ids": idle, "target_id": wave.target})
	bot.waves = live

static func _gather(ctx: Dictionary, bot: Dictionary, mine: Dictionary, enemies: Array, skip: Dictionary) -> void:
	var waving := {}
	for wave: Dictionary in bot.waves:
		for id: int in wave.ids: waving[id] = true
	var rally: Vector2 = _rally(ctx)
	var ready: Array = []
	var walking: Array = []
	for id: int in mine:
		if waving.has(id) or skip.has(id) or not _idle(mine[id]): continue
		var at := Vector2(mine[id].position[0], mine[id].position[1])
		(ready if at.distance_to(rally) <= RALLY_RADIUS else walking).append(id)
	if not walking.is_empty(): _send(ctx, {"type": "move", "entity_ids": walking, "target": [rally.x, rally.y]})
	if ready.is_empty():
		bot.since = -1
		return
	if bot.since < 0: bot.since = ctx.tick
	if ready.size() < WAVE_MIN and ctx.tick - bot.since < WAVE_TIMEOUT: return
	var target: Variant = _pick(_centre(ready, mine), enemies)
	if target == null or not _send(ctx, {"type": "attack", "entity_ids": ready, "target_id": target}): return
	bot.waves.append({"ids": ready, "target": target})
	bot.since = -1

static func _rally(ctx: Dictionary) -> Vector2:
	var map: Dictionary = ctx.sim.map_data()
	return Vector2(MapData.start_cell(map if not map.is_empty() else _default_map(), ctx.player)) + Vector2(0.5, 0.5)

static func _centre(ids: Array, mine: Dictionary) -> Vector2:
	var sum := Vector2.ZERO
	for id: int in ids: sum += Vector2(mine[id].position[0], mine[id].position[1])
	return sum / ids.size()

static func _hostile(ctx: Dictionary, owner: int) -> bool:
	return owner != ctx.player and ctx.teams.get(owner, 0) != ctx.teams.get(ctx.player, -1)

static func _idle(unit: Dictionary) -> bool:
	return unit.combat != null and unit.combat.mode == "guard" and unit.combat.target_id == null

static func _defend(ctx: Dictionary, state: Dictionary, buildings: Array) -> Dictionary:
	var intruders: Array = state.entities.filter(func(unit: Dictionary) -> bool:
		if not _hostile(ctx, unit.owner) or Registry.air_kinds.has(unit.kind) or unit.has("container_id"): return false
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

# Score = priority - one point per DISTANCE_STEP cells (min 1): the Zero Hour attack-priority rule, numbers in docs/reference/m7-verification-archive-research.md.
static func _pick(position: Vector2, enemies: Array) -> Variant:
	var best: Variant = null
	var best_score: int = 0
	for enemy: Dictionary in enemies:
		var score: int = maxi(_priority(enemy.kind) - floori(sqrt(Combat.distance_squared(position, enemy)) / DISTANCE_STEP), 1)
		if best == null or score > best_score or (score == best_score and enemy.id < best):
			best = enemy.id
			best_score = score
	return best

static func _priority(kind: String) -> int:
	var row: Dictionary = Registry.kind(kind)
	if Registry.is_builder(kind): return 28
	if row.has("class"): return 28 if row["class"] == "vehicle" else 27
	if not row.get("weapon", "").is_empty(): return 29
	var produces: Array = row.get("produces", [])
	if produces.any(Registry.is_builder): return 26
	return 27 if row.get("receives_supply", false) or row.get("power", 0) > 0 or not produces.is_empty() else 1

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

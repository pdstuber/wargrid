extends RefCounted

const Skirmish = preload("res://scripts/simulation/skirmish.gd")

const TICK_LIMIT: int = 10800
const HUMAN_ATTACK_TICK: int = 9000
const STAGE := Vector2(18.5, 14.5)
const TERMINAL_TICK: int = 10667
const WINNER: int = 1

func cases() -> Array[Callable]:
	return [test_mirror_match_script]

func _command(sim: RefCounted, state: Dictionary, ids: Array, target: Array) -> void:
	var sequence: int = -1
	for entry in state.last_sequences:
		if entry.player == 1: sequence = entry.sequence
	sim.issue_command({"type": "attack_move", "entity_ids": ids, "target": target, "tick": state.tick, "player": 1, "sequence": sequence + 1})

func _threat(state: Dictionary) -> Variant:
	var home: Array[Vector2] = []
	for unit in state.entities:
		if unit.owner == 1 and unit.kind == "builder": home.append(Vector2(unit.position[0], unit.position[1]))
	for building in state.buildings:
		if building.owner == 1: home.append(Vector2(building.origin[0] + 1.0, building.origin[1] + 1.0))
	var best: Variant = null
	var best_distance: float = 16.0
	for unit in state.entities:
		if unit.owner != 2 or unit.combat == null: continue
		for point in home:
			var distance: float = point.distance_to(Vector2(unit.position[0], unit.position[1]))
			if distance < best_distance:
				best = unit.position
				best_distance = distance
	return best

func _human(sim: RefCounted) -> void:
	Skirmish.issue_opponent(sim, 1, HUMAN_ATTACK_TICK)
	var state: Dictionary = sim.snapshot()
	if state.tick % 30 != 0 or state.tick >= HUMAN_ATTACK_TICK: return
	var threat: Variant = _threat(state)
	var ids: Array = []
	for unit in state.entities:
		if unit.owner != 1 or unit.combat == null: continue
		if threat != null and unit.combat.mode != "attack": ids.append(unit.id)
		elif threat == null and unit.combat.mode == "guard" and unit.status == "idle" and unit.position[0] < STAGE.x - 3.0: ids.append(unit.id)
	if not ids.is_empty(): _command(sim, state, ids, threat if threat != null else [STAGE.x, STAGE.y])

func _credits(state: Dictionary, player: int) -> int:
	for entry in state.players:
		if entry.id == player: return entry.credits
	return -1

func test_mirror_match_script(runner) -> bool:
	var a = Skirmish.create()
	var b = Skirmish.create()
	var first := {"deposit": -1, "shot": -1, "death": -1, "infantry": -1, "tank": -1}
	var completed := {}
	var kinds := {}
	var deposits := {1: 0, 2: 0}
	var credits := {1: 10000, 2: 10000}
	var cargo_before := {}
	var delivered: int = 0
	var boxes_ok: bool = true
	var known_buildings: Array = []
	var created: int = 0
	var negatives: int = 0
	var diverged: int = -1
	var terminal: int = -1
	for tick in range(TICK_LIMIT):
		_human(a)
		_human(b)
		Skirmish.issue_opponent(a)
		Skirmish.issue_opponent(b)
		a.step()
		b.step()
		var state: Dictionary = a.snapshot()
		if diverged == -1 and state != b.snapshot(): diverged = tick
		var building_ids: Array = state.buildings.map(func(building: Dictionary) -> int: return building.id)
		var building_lost: bool = known_buildings.any(func(id: int) -> bool: return not building_ids.has(id))
		known_buildings = building_ids
		for building in state.buildings:
			if building.completed and not completed.has(building.id): completed[building.id] = tick
			if building.completed: kinds.get_or_add(building.owner, {})[building.kind] = true
		for event in state.combat_events:
			if event.type == "shot" and first.shot == -1: first.shot = tick
			if event.type == "death" and first.death == -1: first.death = tick
		var carried: int = 0
		var deposit := {1: 0, 2: 0}
		var cargo_now := {}
		for unit in state.entities:
			if unit.hp <= 0: negatives += 1
			if (unit.kind == "infantry" or unit.kind == "tank") and first[unit.kind] == -1: first[unit.kind] = tick
			if unit.collection == null: continue
			carried += unit.collection.cargo
			cargo_now[unit.id] = unit.collection.cargo
			if cargo_before.get(unit.id, 0) > 0 and unit.collection.cargo == 0: deposit[unit.owner] += cargo_before[unit.id] * 75
		cargo_before = cargo_now
		var stock: int = 0
		for source in state.sources:
			if source.boxes < 0: negatives += 1
			stock += source.boxes
		for player in [1, 2]:
			var now: int = _credits(state, player)
			if now < 0: negatives += 1
			if now > credits[player] + deposit[player] and not building_lost: boxes_ok = false
			if deposit[player] > 0:
				deposits[player] += deposit[player]
				delivered += deposit[player] / 75
				if first.deposit == -1: first.deposit = tick
			credits[player] = now
		if stock + carried + delivered != 400: boxes_ok = false
		if state.match.status != "ongoing":
			terminal = tick
			break
		if tick % 600 == 599: await runner.process_frame
	var end: Dictionary = a.snapshot()
	runner.check(diverged == -1, "S1 two fresh worlds stay identical, first divergence " + str(diverged))
	runner.check(terminal == TERMINAL_TICK and end.match.winner == WINNER and end.match.ended_tick == TERMINAL_TICK and end.tick == TERMINAL_TICK + 1, "S1 pinned outcome, got " + str(terminal) + " " + str(end.match))
	runner.check(terminal >= 9000 and terminal <= TICK_LIMIT - 1, "S1 terminal inside the six-minute window")
	runner.check([1, 2].all(func(owner: int) -> bool: return Skirmish.BUILD_ORDER.all(func(kind: String) -> bool: return kinds.get(owner, {}).has(kind))) and not first.values().has(-1) and first.values().all(func(tick: int) -> bool: return tick < terminal), "S1 economy, production and combat all happened before the end, got " + str(first) + " " + str(kinds))
	runner.check(deposits[1] > 0 and deposits[2] > 0 and boxes_ok and negatives == 0, "S1 both owners deposited, supply conserved, nothing negative: " + str(deposits))
	return true

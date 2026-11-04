extends RefCounted

# formerly in test_skirmish_match.gd
const Skirmish = preload("res://scripts/simulation/skirmish.gd")

const HUMAN_ATTACK_TICK: int = 9000
const STAGE := Vector2(18.5, 14.5)

static func _command(sim: RefCounted, state: Dictionary, ids: Array, target: Array) -> void:
	var sequence: int = -1
	for entry in state.last_sequences:
		if entry.player == 1: sequence = entry.sequence
	sim.issue_command({"type": "attack_move", "entity_ids": ids, "target": target, "tick": state.tick, "player": 1, "sequence": sequence + 1})

static func _threat(state: Dictionary) -> Variant:
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

static func issue(sim: RefCounted) -> void:
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

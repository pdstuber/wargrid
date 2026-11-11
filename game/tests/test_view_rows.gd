@warning_ignore_start("untyped_declaration")
extends RefCounted

const View = preload("res://scripts/presentation/world_view.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

const SKIRMISH_TICKS: int = 3000
const HORDES_TICKS: int = 400
const EXTRA_COLLECTORS: int = 3
const EXPECTED_DIGEST: String = "2046606c78e467de7a7ec23c0342b31e5b9136fcdb2f2ee2ac920fad7e6b60af"

func cases() -> Array[Callable]:
	return [test_view_reads_digest_is_pinned]

# At tick 3000 nothing has a target or waits, so the fixture adds an attacker and a collector line.
static func skirmish_sim() -> RefCounted:
	var sim = Skirmish.create()
	for i in SKIRMISH_TICKS:
		Skirmish.issue_opponents(sim, [1, 2])
		sim.step()
	var sequence: int = _sequence(sim.snapshot())
	for i in EXTRA_COLLECTORS:
		var id: int = sim.spawn(1, Vector2(6.5 + i, 4.5), "usa_collector")
		sequence += 1
		sim.issue_command({"tick": sim.tick(), "player": 1, "sequence": sequence, "type": "gather", "entity_ids": [id], "source_id": 5})
	for i in 100: sim.step()
	var state: Dictionary = sim.snapshot()
	var spot := Vector2(28.5, 19.5)
	var enemies: Array = state.entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 2 and unit.combat != null)
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a.position[0], a.position[1]).distance_to(spot) < Vector2(b.position[0], b.position[1]).distance_to(spot))
	var attacker: int = sim.spawn(1, spot, "usa_rifle_infantry")
	sim.issue_command({"tick": sim.tick(), "player": 1, "sequence": _sequence(state) + EXTRA_COLLECTORS + 1, "type": "attack", "entity_ids": [attacker], "target_id": enemies[0].id})
	for i in 10: sim.step()
	return sim

static func _sequence(state: Dictionary) -> int:
	for entry: Variant in state.last_sequences:
		if entry.player == 1: return entry.sequence
	return -1

static func hordes_sim() -> RefCounted:
	var sim = CombatWorkload.create("hordes300")
	for i in HORDES_TICKS: sim.step()
	return sim

static func selection(state: Dictionary) -> Array[int]:
	var picked: Array[int] = []
	var own: Array = state.entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 1)
	for unit: Dictionary in own.slice(0, 5): picked.append(unit.id)
	for unit: Dictionary in own:
		if picked.has(unit.id): continue
		if unit.collection != null and not picked.any(func(id: int) -> bool: return _unit(own, id).collection != null): picked.append(unit.id)
		elif Registry.is_builder(unit.kind) and not picked.any(func(id: int) -> bool: return Registry.is_builder(_unit(own, id).kind)): picked.append(unit.id)
	var attacker: Array = own.filter(func(unit: Dictionary) -> bool: return unit.combat != null and unit.combat.target_id != null and not picked.has(unit.id))
	if not attacker.is_empty(): picked.append(attacker[0].id)
	return picked

static func _unit(units: Array, id: int) -> Dictionary:
	for unit: Dictionary in units:
		if unit.id == id: return unit
	return {}

static func view_reads(state: Dictionary) -> Array:
	var chosen: Array[int] = selection(state)
	var view = View.new()
	view.set_show_destinations(true)
	view.set_state(state, chosen)
	var batch = WorldBatch.new()
	batch.build(WorldBatch.objects(state), {}, 1, true)
	var parts: Array = [batch.points, batch.colors, view.selected_unit_lines()]
	var focus: Dictionary = view.focus_targets()
	parts.append([focus.keys(), focus.values()])
	parts.append(view.order_marks())
	parts.append(view.pick_entities(Rect2(-1000, -1000, 4000, 4000)))
	for unit: Dictionary in state.entities.slice(0, 5):
		var anchor: Vector2 = Iso.world_to_plane(Vector2(unit.position[0], unit.position[1])) + Vector2(0, -8)
		parts.append([view.pick_entity(anchor), view.pick_entity(anchor, true), view.pick_target(anchor, 1), view.pick_target(anchor, 2)])
	for source: Dictionary in state.sources: parts.append(view.pile_lines(source))
	parts.append(view.horde_count())
	view.set_hovered(state.buildings[0].id if not state.buildings.is_empty() else -1)
	parts.append(view.resume_candidate())
	parts.append(chosen)
	view.free()
	return parts

static func digest(sims: Array) -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	for sim in sims: hasher.update(var_to_bytes(view_reads(sim.snapshot())))
	return hasher.finish().hex_encode()

func test_view_reads_digest_is_pinned(runner) -> bool:
	var skirmish = skirmish_sim()
	var hordes = hordes_sim()
	for sim in [skirmish, hordes]:
		var state: Dictionary = sim.snapshot()
		var parts: Array = view_reads(state)
		runner.check(selection(state).size() >= 5, "VR1 fixture: a selection of at least five")
		runner.check(parts[0].size() > 0, "VR1 fixture: batch points exist, got " + str(parts[0].size()))
	runner.check(view_reads(skirmish.snapshot())[3][0].size() > 0, "VR1 fixture: skirmish selection has a focus target")
	runner.check(view_reads(hordes.snapshot())[5].size() > 0, "VR1 fixture: hordes pick_entities non-empty")
	var first: String = digest([skirmish, hordes])
	runner.check(first == digest([skirmish, hordes]), "VR1 digest is repeatable on one state")
	runner.check(first == EXPECTED_DIGEST, "VR1 view reads digest, got " + first)
	return true

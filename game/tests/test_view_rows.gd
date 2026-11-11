@warning_ignore_start("untyped_declaration")
extends RefCounted

const View = preload("res://scripts/presentation/world_view.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const TeamMatch = preload("res://scripts/debug/team_match.gd")

const SKIRMISH_TICKS: int = 3000
const HORDES_TICKS: int = 400
const EXTRA_COLLECTORS: int = 3
const EXPECTED_DIGEST: String = "2046606c78e467de7a7ec23c0342b31e5b9136fcdb2f2ee2ac920fad7e6b60af"

func cases() -> Array[Callable]:
	return [test_view_reads_digest_is_pinned, test_rows_equal_snapshot, test_view_state_other_keys, test_view_state_is_read_only, test_view_items_persist, test_view_batch_equals_snapshot_batch]

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

static func view_reads(state: Dictionary, view_state: Dictionary = {}) -> Array:
	var chosen: Array[int] = selection(state)
	var view = View.new()
	view.set_show_destinations(true)
	if view_state.is_empty(): view.set_state(state, chosen)
	else: view.set_view(view_state, chosen)
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

static func digest(sims: Array, through_view_state: bool = false) -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	for sim in sims: hasher.update(var_to_bytes(view_reads(sim.snapshot(), sim.view_state() if through_view_state else {})))
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
	var rows_digest: String = digest([skirmish, hordes], true)
	runner.check(rows_digest == EXPECTED_DIGEST, "VR1 the same digest through set_view, got " + rows_digest)
	return true

func test_view_batch_equals_snapshot_batch(runner) -> bool:
	for sim in [skirmish_sim(), hordes_sim()]:
		var state: Dictionary = sim.snapshot()
		var chosen: Array[int] = selection(state)
		var from_snapshot = View.new()
		from_snapshot.set_state(state, chosen)
		var from_view = View.new()
		from_view.set_view(sim.view_state(), chosen)
		var expected = WorldBatch.new()
		expected.build(WorldBatch.objects(state), {}, from_view.detail(), from_view._quality == GraphicsSettings.HIGH)
		runner.check(from_snapshot._batch.points.size() > 0, "VR1 batch fixture: points exist")
		runner.check(expected.points == from_view._batch.points and expected.colors == from_view._batch.colors, "VR1 the WorldView batch equals WorldBatch.objects")
		runner.check(from_snapshot._batch.points == from_view._batch.points, "VR1 the WorldView batch points match through set_view")
		runner.check(from_snapshot._batch.colors == from_view._batch.colors, "VR1 the WorldView batch colors match through set_view")
		from_snapshot.free()
		from_view.free()
	return true

static func _view_of(snapshot: Dictionary, entities: Array, tick: int) -> Dictionary:
	var state: Dictionary = snapshot.duplicate()
	state.units = ViewRows.from_units(entities)
	state.tick = tick
	return state

func test_view_items_persist(runner) -> bool:
	var sim = Skirmish.create()
	for i in 5: sim.step()
	var snapshot: Dictionary = sim.snapshot()
	var view = View.new()
	view.set_smooth(false)
	view.set_view(_view_of(snapshot, snapshot.entities, 1), [])
	var before: Array = view._unit_items.duplicate()
	var next: Array = snapshot.entities.duplicate(true)
	var gone: int = next.pop_back().id
	next[0].position = [next[0].position[0] + 1.0, next[0].position[1] + 1.0]
	var spawned: Dictionary = next[0].duplicate(true)
	spawned.id = snapshot.entities[-1].id + 10
	next.append(spawned)
	view.set_view(_view_of(snapshot, next, 2), [])
	var items: Array = view._unit_items
	runner.check(snapshot.entities.size() >= 2 and items.size() == next.size(), "VR5 fixture: two or more units, one removed, one added")
	runner.check(is_same(items[0], before[0]), "VR5 a surviving unit keeps its item")
	runner.check(items.all(func(item: Dictionary) -> bool: return item.id != gone) and before.any(func(item: Dictionary) -> bool: return item.id == gone), "VR5 a removed unit's item is gone")
	runner.check(items[-1].id == spawned.id and not before.any(func(item: Dictionary) -> bool: return is_same(item, items[-1])), "VR5 a spawned unit gets a new item")
	runner.check(items[0].anchor == Vector2(next[0].position[0], next[0].position[1]), "VR5 the item holds the new position")
	view.free()
	return true

static func vr2_states() -> Array:
	var states: Array = []
	var hordes = CombatWorkload.create("hordes300")
	for target in [40, 400, 1500]:
		while hordes.tick() < target: hordes.step()
		states.append(hordes.snapshot())
	var skirmish = skirmish_sim()
	states.append(skirmish.snapshot())
	var team = TeamMatch.create()
	for i in 2000: TeamMatch.step(team)
	states.append(team.snapshot())
	var transports: Dictionary = CombatWorkload.create("transports").snapshot()
	var armed: Array = transports.entities.filter(func(unit: Dictionary) -> bool: return unit.combat != null)
	armed[0].combat.tier = 2 # only a salvage pickup raises a tier, which needs a private crate write
	states.append(transports)
	return states

static func flag_of(unit: Dictionary) -> int:
	var combat: Variant = unit.combat
	var collection: Variant = unit.collection
	var bits: int = 0
	if combat != null and combat.get("horde", 0) > 0: bits |= ViewRows.HORDE
	if unit.has("container_id"): bits |= ViewRows.CONTAINED
	if unit.has("hole_id"): bits |= ViewRows.HOLE
	if combat != null and combat.mode == "attack": bits |= ViewRows.ATTACKING
	if unit.order != null: bits |= ViewRows.ORDERED
	if collection != null and collection.phase == "waiting_source": bits |= ViewRows.WAITING_SOURCE
	if collection != null and collection.enabled: bits |= ViewRows.COLLECTING
	return bits

static func expected_row(unit: Dictionary) -> Dictionary:
	var combat: Variant = unit.combat
	var collection: Variant = unit.collection
	var heading: Array = unit.get("heading", [1.0, 0.0])
	var waiting: bool = collection != null and collection.phase.begins_with("waiting_")
	var status: int = ViewRows.STATUSES.find(unit.status)
	return {"id": unit.id, "owner": unit.owner, "hp": unit.hp, "max_hp": unit.max_hp, "x": unit.position[0], "y": unit.position[1],
		"heading_x": heading[0], "heading_y": heading[1],
		"target": -1 if combat == null or combat.target_id == null else combat.target_id,
		"queue": collection.target_id if waiting and collection.target_id != null else -1,
		"order_x": unit.order.target[0] if unit.order != null else 0.0, "order_y": unit.order.target[1] if unit.order != null else 0.0,
		"status": 255 if status == -1 else status, "tier": combat.get("tier", 0) if combat != null else 0, "flags": flag_of(unit)}

static func row_mismatch(rows, i: int, unit: Dictionary) -> String:
	var want: Dictionary = expected_row(unit)
	for column: String in want:
		if rows.get(column)[i] != want[column]: return "%s of unit %d: row %s, snapshot %s" % [column, unit.id, str(rows.get(column)[i]), str(want[column])]
	if rows.kinds[rows.kind[i]] != unit.kind: return "kind of unit %d" % unit.id
	var combat: Variant = unit.combat
	var collection: Variant = unit.collection
	if (rows.mode[i] == ViewRows.NONE) != (combat == null) or (combat != null and rows.modes[rows.mode[i]] != combat.mode): return "mode of unit %d" % unit.id
	if (rows.phase[i] == ViewRows.NONE) != (collection == null) or (collection != null and rows.phases[rows.phase[i]] != collection.phase): return "phase of unit %d" % unit.id
	return ""

static func tally(rows, seen: Dictionary) -> void:
	for i in rows.size():
		for bit in [ViewRows.HORDE, ViewRows.CONTAINED, ViewRows.HOLE, ViewRows.ATTACKING, ViewRows.ORDERED, ViewRows.WAITING_SOURCE, ViewRows.COLLECTING]:
			if rows.flags[i] & bit != 0: seen["flag%d" % bit] = true
		if rows.queue[i] != -1: seen.queue = true
		if rows.tier[i] != 0: seen.tier = true
		if rows.mode[i] == ViewRows.NONE: seen.mode_none = true
		elif rows.modes[rows.mode[i]] != "guard": seen.mode_other = true
		if rows.phase[i] == ViewRows.NONE: seen.phase_none = true
		elif rows.phases[rows.phase[i]].begins_with("waiting_"): seen.phase_waiting = true

func test_rows_equal_snapshot(runner) -> bool:
	var seen: Dictionary = {}
	var with_target: int = 0
	for state in vr2_states():
		var rows = ViewRows.from_units(state.entities)
		runner.check(rows.size() == state.entities.size(), "VR2 one row per unit")
		var bad: String = ""
		var targets: int = 0
		for i in rows.size():
			bad = row_mismatch(rows, i, state.entities[i])
			if bad != "": break
			if rows.target[i] != -1: targets += 1
		runner.check(bad == "", "VR2 rows equal snapshot: " + bad)
		runner.check(rows.index_of(state.entities[0].id) == 0 and rows.index_of(-7) == -1, "VR2 index_of")
		tally(rows, seen)
		if targets > 0: with_target += 1
	runner.check(with_target >= 2, "VR2 coverage: states with a target, got " + str(with_target))
	for key in ["flag1", "flag2", "flag8", "flag16", "flag32", "flag64", "queue", "tier", "mode_none", "mode_other", "phase_none", "phase_waiting"]:
		runner.check(seen.has(key), "VR2 coverage: " + key)
	return true

func test_view_state_other_keys(runner) -> bool:
	for sim in [skirmish_sim(), hordes_sim()]:
		var view: Dictionary = sim.view_state()
		var snap: Dictionary = sim.snapshot()
		var allowed: Array = ["tick", "map", "players", "buildings", "sources", "match", "command_results", "units"]
		if snap.has("crates"): allowed.append("crates")
		for key: String in allowed:
			if key != "units": runner.check(view.has(key) and view[key] == snap[key], "VR3 key " + key)
		for key: String in view: runner.check(allowed.has(key), "VR3 no extra key " + key)
		runner.check(view.units.size() == snap.entities.size(), "VR3 units present")
		var bad: String = ""
		for i in view.units.size():
			bad = row_mismatch(view.units, i, snap.entities[i])
			if bad != "": break
		runner.check(bad == "", "VR3 view_state rows equal the snapshot: " + bad)
	return true

func held_copy(view: Dictionary) -> Dictionary:
	var copy: Dictionary = {}
	for key: String in view:
		if key == "units": continue
		copy[key] = view[key].duplicate(true) if view[key] is Array or view[key] is Dictionary else view[key]
	var rows = view.units
	for column in ["id", "owner", "kind", "hp", "max_hp", "target", "queue", "x", "y", "heading_x", "heading_y", "order_x", "order_y", "status", "tier", "mode", "phase", "flags", "kinds", "modes", "phases"]:
		copy["units." + column] = rows.get(column).duplicate()
	return copy

func test_view_state_is_read_only(runner) -> bool:
	var a = Skirmish.create()
	var b = Skirmish.create()
	var before: String = StateHash.digest(a.snapshot())
	a.view_state()
	runner.check(StateHash.digest(a.snapshot()) == before, "VR4 view_state leaves the digest unchanged")
	var held: Dictionary = {}
	var kept: Dictionary = {}
	for tick in 300:
		a.view_state()
		Skirmish.issue_opponents(a, [1, 2])
		Skirmish.issue_opponents(b, [1, 2])
		a.step()
		b.step()
		if tick == 150: held = a.view_state(); kept = held_copy(held)
		if tick == 180: runner.check(held_copy(held) == kept, "VR4 a held view state is unchanged after 30 steps")
		if tick % 30 == 29: runner.check(StateHash.digest(a.snapshot()) == StateHash.digest(b.snapshot()), "VR4 digests equal at tick " + str(a.tick()))
	runner.check(StateHash.digest(a.snapshot()) == StateHash.digest(b.snapshot()), "VR4 digests equal at the end")
	return true

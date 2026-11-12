@warning_ignore_start("untyped_declaration")
extends RefCounted

const Parity = preload("res://tests/test_supply_parity.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")

const KINDS := ["usa_collector", "china_collector", "frc_builder"]
const LONE_DEPOSITS := {
	"usa_collector": {
		3: [659, 1327, 1995, 2663, 3331, 3999, 4667, 5335, 6003],
		9: [718, 1446, 2174, 2902, 3630, 4358, 5086, 5814, 6542],
	},
	"china_collector": {
		3: [382, 805, 1228, 1651, 2074, 2497, 2920, 3343, 3766],
		9: [607, 1254, 1901, 2548, 3195, 3842, 4489, 5136, 5783],
	},
	"frc_builder": {
		3: [296, 607, 918, 1229, 1540, 1851, 2162, 2473, 2784],
		9: [656, 1327, 1998, 2669, 3340, 4011, 4682, 5353, 6024],
	},
}
const LOCK_TABLE := {
	"frc_builder": {"source": {"lead": 38, "box": 23}, "depot": {"lead": 6, "work": 39}},
	"china_collector": {"source": {"lead": 5, "box": 37}, "depot": {"lead": 0, "work": 37}},
	"usa_collector": {"source": {"lead": 18, "box": 41}, "depot": {"lead": 60, "work": 153}},
}
const COMMAND_ROWS := ["move", "stop", "attack_move", "enter", "build", "resume_build", "gather other", "gather same", "attack", "remove actor", "remove pile"]
const LEAVES := ["move", "stop", "attack_move", "enter", "build", "resume_build"]

func cases() -> Array[Callable]:
	return [test_lone_cycles_pinned, test_lock_data_follows_the_rule, test_lone_lock_window, test_lead_is_not_exclusive, test_two_leads_end_on_one_tick, test_stop_during_lead, test_removal_while_locked, test_pile_empties_during_lead, test_commands_in_lead_and_lock, test_lead_is_not_queued_in_view]

func deposit_ticks(kind: String, gap: int, count: int) -> Array:
	var sim = Parity.new().layout(kind, gap, 1).sim
	var ticks: Array = []
	var last: int = sim.view_state().players[0].credits
	for index in range(30000):
		sim.step()
		var credits: int = sim.view_state().players[0].credits
		if credits == last: continue
		last = credits
		ticks.append(sim.tick())
		if ticks.size() == count: break
	return ticks

func test_lone_cycles_pinned(runner) -> bool:
	for kind in KINDS:
		for gap in [3, 9]:
			var ticks: Array = deposit_ticks(kind, gap, 9)
			runner.check(LONE_DEPOSITS.get(kind, {}).get(gap, []) == ticks, "DL0 a lone %s at gap %d deposits on the same ticks as before c1, got %s" % [kind, gap, ticks])
	return true

func phases_of(view: Dictionary) -> Dictionary:
	var units = view.units
	var out: Dictionary = {}
	for index in range(units.size()):
		if units.phase[index] != units.NONE: out[units.id[index]] = units.phases[units.phase[index]]
	return out

func count_phase(phases: Dictionary, phase: String) -> int:
	return phases.values().count(phase)

func collection_of(sim, id: int) -> Dictionary:
	return Fixture.object(sim, id).get("collection", {})

func lock_of(kind: String) -> Dictionary:
	return Registry.collects(kind).get("lock", {})

# Two laborers a few cells apart on one pile edge reach their dock spots together.
func pair_world(boxes: int, delete_when_empty: bool, extras: bool = false, second_spot: Vector2 = Vector2(7.5, 12.5)) -> Dictionary:
	var sim = Fixture.make_world(10000, Vector2i(48, 24))
	var depot: int = Fixture.add_completed(sim, 1, "frc_supply_center", Vector2i(2, 10))
	var source: int = sim.add_supply_source(Vector2i(8, 9), boxes, Vector2i(4, 5), delete_when_empty)
	var first: int = sim.spawn(1, Vector2(7.5, 10.5), "frc_builder")
	var second: int = sim.spawn(1, second_spot, "frc_builder")
	var world: Dictionary = {"sim": sim, "depot": depot, "source": source, "first": first, "second": second}
	if extras:
		world.hub = Fixture.add_completed(sim, 1, "frc_defence", Vector2i(30, 18))
		world.other = sim.add_supply_source(Vector2i(24, 9), 400)
	Fixture.send(sim, {"type": "gather", "entity_ids": [first, second], "source_id": source})
	return world

func test_lock_data_follows_the_rule(runner) -> bool:
	for kind in KINDS:
		var c: Dictionary = Registry.collects(kind)
		var loads: int = c.boxes + 1
		@warning_ignore("integer_division")
		var earned: int = (c.boxes * c.box_value * 184 + 299) / 300
		@warning_ignore("integer_division")
		var box: int = (2 * earned + loads) / (2 * loads)
		var lock: Dictionary = c.get("lock", {})
		var source: Dictionary = lock.get("source", {})
		var depot: Dictionary = lock.get("depot", {})
		var ruled: bool = source.get("box") == box and source.get("lead") == loads * c.load_ticks - loads * box and source.get("lead", -1) >= 0
		ruled = ruled and depot.has("lead") and depot.get("lead", 0) + depot.get("work", 0) == c.unload_ticks
		runner.check(ruled and lock == LOCK_TABLE[kind], "DL1 %s pile lock is %d ticks per load from 184 ticks per 300 credits, got %s" % [kind, box, lock])
	return true

func phase_runs(sim, id: int, ticks: int) -> Array:
	var runs: Array = []
	for index in range(ticks):
		sim.step()
		var phase: Variant = phases_of(sim.view_state()).get(id)
		if not runs.is_empty() and runs[-1][0] == phase: runs[-1][1] += 1
		else: runs.append([phase, 1])
	return runs

# The runs from the first one in `starts`: a lead run when lead > 0, then the work run.
func visit(runs: Array, starts: Array, lead: int) -> Array:
	for index in range(runs.size()):
		if runs[index][0] in starts: return runs.slice(index, index + (2 if lead > 0 else 1))
	return []

func test_lone_lock_window(runner) -> bool:
	for kind in KINDS:
		var world: Dictionary = Parity.new().layout(kind, 3, 1)
		var lock: Dictionary = lock_of(kind)
		if not lock.has("source"):
			runner.check(false, "DL2 %s has lock data" % kind)
			continue
		var loads: int = Registry.collects(kind).boxes + 1
		var runs: Array = phase_runs(world.sim, world.ids[0], 3000)
		var source: Array = [["lead_source", lock.source.lead]] if lock.source.lead > 0 else []
		source.append(["loading", loads * lock.source.box])
		var depot: Array = [["lead_depot", lock.depot.lead]] if lock.depot.lead > 0 else []
		depot.append(["unloading", lock.depot.work])
		runner.check(visit(runs, ["lead_source", "loading"], lock.source.lead) == source, "DL2 a lone %s stands lead %d then holds the pile %d ticks, got %s" % [kind, lock.source.lead, loads * lock.source.box, visit(runs, ["lead_source", "loading"], lock.source.lead)])
		runner.check(visit(runs, ["lead_depot", "unloading"], lock.depot.lead) == depot, "DL2 a lone %s stands lead %d then holds the depot %d ticks, got %s" % [kind, lock.depot.lead, lock.depot.work, visit(runs, ["lead_depot", "unloading"], lock.depot.lead)])
		if lock.depot.lead == 0: runner.check(not runs.any(func(run) -> bool: return run[0] == "lead_depot"), "DL2 a lone %s has no depot lead" % kind)
	return true

func test_lead_is_not_exclusive(runner) -> bool:
	var sim = Parity.new().layout("frc_builder", 3, 2).sim
	var overlapped: bool = false
	var doubled: bool = false
	for index in range(1500):
		sim.step()
		var phases: Dictionary = phases_of(sim.view_state())
		if count_phase(phases, "loading") == 1 and count_phase(phases, "lead_source") >= 1: overlapped = true
		if count_phase(phases, "loading") > 1 or count_phase(phases, "unloading") > 1: doubled = true
	runner.check(overlapped, "DL3 one laborer loads while another stands its lead")
	runner.check(not doubled, "DL3 never two laborers loading at one pile or unloading at one depot")
	return true

# Tick each id leaves lead_source and the phase it leaves into.
func lead_ends(sim, ids: Array, ticks: int) -> Dictionary:
	var leading: Dictionary = {}
	var left: Dictionary = {}
	var after: Dictionary = {}
	for index in range(ticks):
		sim.step()
		var view: Dictionary = sim.view_state()
		var phases: Dictionary = phases_of(view)
		for id in ids:
			if phases.get(id) == "lead_source": leading[id] = true
			elif leading.has(id) and not left.has(id):
				left[id] = view.tick
				after[id] = phases.get(id)
		if left.size() == ids.size(): break
	return {"left": left, "after": after}

func test_two_leads_end_on_one_tick(runner) -> bool:
	var world: Dictionary = pair_world(400, false)
	var ends: Dictionary = lead_ends(world.sim, [world.first, world.second], 600)
	runner.check(ends.left.size() == 2 and ends.left[world.first] == ends.left[world.second], "DL4 both leads end on one tick, got %s" % [ends.left])
	runner.check(ends.after.get(world.first) == "loading" and ends.after.get(world.second) == "waiting_source", "DL4 two leads ending on one tick: the lower id takes the lock, got %s" % [ends.after])
	var sim = Fixture.make_world(10000, Vector2i(48, 24))
	Fixture.add_completed(sim, 1, "frc_supply_center", Vector2i(2, 10))
	var source: int = sim.add_supply_source(Vector2i(8, 9), 400, Vector2i(4, 5), false)
	var laborer: int = sim.spawn(1, Vector2(7.5, 10.5), "frc_builder")
	var chinook: int = sim.spawn(1, Vector2(10.0, 11.5), "usa_collector")
	Fixture.send(sim, {"type": "gather", "entity_ids": [laborer], "source_id": source})
	var due: bool = false
	for index in range(600):
		sim.step()
		if phases_of(sim.view_state()).get(laborer) == "lead_source" and collection_of(sim, laborer).remaining_ticks == 19:
			due = true
			break
	runner.check(laborer < chinook and due, "DL4 mixed pile: the laborer stands its lead with 19 ticks left")
	Fixture.send(sim, {"type": "gather", "entity_ids": [chinook], "source_id": source})
	ends = lead_ends(sim, [laborer, chinook], 100)
	runner.check(ends.left.size() == 2 and ends.left[laborer] == ends.left[chinook], "DL4 mixed pile: both leads end on one tick, got %s" % [ends.left])
	runner.check(ends.after.get(laborer) == "loading" and ends.after.get(chinook) == "waiting_source", "DL4 mixed pile: the lower id takes the lock, not air first, got %s" % [ends.after])
	return true

func test_stop_during_lead(runner) -> bool:
	var world: Dictionary = pair_world(400, false)
	var sim = world.sim
	var leading: bool = false
	for index in range(200):
		sim.step()
		if phases_of(sim.view_state()).get(world.first) == "lead_source":
			leading = true
			break
	runner.check(leading, "DL5 the first laborer reaches its lead")
	Fixture.send(sim, {"type": "stop", "entity_ids": [world.first]})
	var loaded: bool = false
	var first_back: bool = false
	for index in range(300):
		sim.step()
		var phases: Dictionary = phases_of(sim.view_state())
		if phases.get(world.second) == "loading": loaded = true
		if phases.get(world.first) in ["lead_source", "waiting_source", "loading"]: first_back = true
	runner.check(loaded, "DL5 the second laborer still loads after the first was stopped in its lead")
	runner.check(not first_back, "DL5 the stopped laborer no longer collects")
	return true

func wait_for_waiter(world: Dictionary) -> bool:
	for index in range(600):
		world.sim.step()
		var phases: Dictionary = phases_of(world.sim.view_state())
		if phases.get(world.first) == "loading" and phases.get(world.second) == "waiting_source": return true
	return false

func test_removal_while_locked(runner) -> bool:
	var world: Dictionary = pair_world(400, false)
	runner.check(wait_for_waiter(world), "DL6 the second laborer waits behind the lock holder")
	world.sim.remove_object(world.first)
	world.sim.step()
	runner.check(phases_of(world.sim.view_state()).get(world.second) == "loading", "DL6 removing the lock holder lets the waiter load on the next tick")
	world = pair_world(400, false)
	runner.check(wait_for_waiter(world), "DL6 the second laborer waits behind the lock holder again")
	Fixture.send(world.sim, {"type": "stop", "entity_ids": [world.first]})
	world.sim.step()
	runner.check(phases_of(world.sim.view_state()).get(world.second) == "loading", "DL6 stopping the lock holder lets the waiter load on the next tick")
	world = pair_world(1, true)
	runner.check(wait_for_waiter(world), "DL6 the second laborer waits behind the last box")
	for index in range(600):
		world.sim.step()
		if world.sim.view_state().sources.is_empty(): break
	var stuck: int = 0
	for phase in phases_of(world.sim.view_state()).values():
		if phase in ["lead_source", "waiting_source", "loading"]: stuck += 1
	runner.check(world.sim.view_state().sources.is_empty() and stuck == 0, "DL6 deleting the emptied pile frees every collector")
	return true

func test_pile_empties_during_lead(runner) -> bool:
	var world: Dictionary = pair_world(1, false, false, Vector2(6.5, 12.5))
	var sim = world.sim
	var seen: bool = false
	var loaded: bool = false
	var cargo: int = 0
	for index in range(600):
		sim.step()
		var view: Dictionary = sim.view_state()
		var phase: Variant = phases_of(view).get(world.second)
		if phase == "lead_source" and view.sources.size() == 1 and view.sources[0].boxes == 0: seen = true
		if phase == "loading": loaded = true
		cargo = maxi(cargo, collection_of(sim, world.second).cargo)
	runner.check(seen, "DL7 the second laborer stands its lead while the pile is at 0 boxes")
	runner.check(not loaded and cargo == 0, "DL7 a lead ending at an emptied pile never loads or locks, cargo %d" % cargo)
	return true

func reach(world: Dictionary, state: String) -> bool:
	for index in range(600):
		world.sim.step()
		var phases: Dictionary = phases_of(world.sim.view_state())
		if state == "locked" and phases.get(world.first) == "loading" and phases.get(world.second) == "waiting_source": return true
		if state == "lead" and phases.get(world.first) == "lead_source" and collection_of(world.sim, world.first).remaining_ticks == 1: return true
	return false

func command_world(row: String) -> Dictionary:
	var world: Dictionary = pair_world(400, false, true)
	if row != "resume_build": return world
	var sim = world.sim
	var third: int = sim.spawn(1, Vector2(34.5, 6.5), "frc_builder")
	world.foundation = sim.snapshot().next_entity_id
	Fixture.send(sim, {"type": "build", "builder_id": third, "building_kind": "frc_supply_center", "origin": [30, 2]})
	sim.step()
	Fixture.send(sim, {"type": "stop", "entity_ids": [third]})
	return world

func act(world: Dictionary, row: String) -> Dictionary:
	var sim = world.sim
	var first: int = world.first
	match row:
		"move": return Fixture.send(sim, {"type": "move", "entity_ids": [first], "target": [20.5, 20.5]})
		"stop": return Fixture.send(sim, {"type": "stop", "entity_ids": [first]})
		"attack_move": return Fixture.send(sim, {"type": "attack_move", "entity_ids": [first], "target": [20.5, 20.5]})
		"enter": return Fixture.send(sim, {"type": "enter", "entity_ids": [first], "target_id": world.hub})
		"build": return Fixture.send(sim, {"type": "build", "builder_id": first, "building_kind": "frc_supply_center", "origin": [30, 2]})
		"resume_build": return Fixture.send(sim, {"type": "resume_build", "builder_id": first, "building_id": world.foundation})
		"gather other": return Fixture.send(sim, {"type": "gather", "entity_ids": [first], "source_id": world.other})
		"gather same": return Fixture.send(sim, {"type": "gather", "entity_ids": [first], "source_id": world.source})
		"attack": return Fixture.send(sim, {"type": "attack", "entity_ids": [first], "target_id": world.hub})
		"remove actor": return sim.remove_object(first)
		"remove pile": return sim.remove_object(world.source)
	return {}

# Steps on while `id` still stands its lead; true when it then loads.
func loads_after_lead(sim, id: int) -> bool:
	for index in range(100):
		var phase: Variant = phases_of(sim.view_state()).get(id)
		if phase != "lead_source": return phase == "loading"
		sim.step()
	return false

func never_loads_here(world: Dictionary) -> bool:
	for index in range(300):
		world.sim.step()
		if phases_of(world.sim.view_state()).get(world.first) == "loading" and collection_of(world.sim, world.first).target_id == world.source: return false
	return true

func test_commands_in_lead_and_lock(runner) -> bool:
	var lead: int = lock_of("frc_builder").get("source", {}).get("lead", -1)
	for state in ["lead", "locked"]:
		for row in COMMAND_ROWS:
			var world: Dictionary = command_world(row)
			var sim = world.sim
			if not reach(world, state):
				runner.check(false, "DL8 %s during %s: the state is reached" % [row, state])
				continue
			var cargo: Array = [collection_of(sim, world.first).cargo, collection_of(sim, world.second).cargo]
			var result: Dictionary = act(world, row)
			sim.step()
			var phases: Dictionary = phases_of(sim.view_state())
			var failed: bool = sim.view_state().command_results.any(func(r) -> bool: return not r.ok)
			if row == "attack":
				runner.check(not result.ok and result.error == "Attack requires armed units", "DL8 %s during %s: rejected, got %s" % [row, state, result])
				runner.check(phases.get(world.first) == "loading" and phases.get(world.second) == "waiting_source", "DL8 %s during %s: the step runs as without a command, got %s" % [row, state, phases])
				continue
			runner.check(result.ok and not failed, "DL8 %s during %s: accepted, got %s %s" % [row, state, result, sim.view_state().command_results])
			if row == "remove pile":
				var first: Dictionary = collection_of(sim, world.first)
				var second: Dictionary = collection_of(sim, world.second)
				runner.check(first.target_id == null and second.target_id == null and [first.cargo, second.cargo] == cargo, "DL8 %s during %s: both lose the target and keep cargo %s, got %s %s" % [row, state, cargo, first, second])
				continue
			if row == "gather other": runner.check(collection_of(sim, world.first).target_id == world.other, "DL8 %s during %s: first heads for the other pile" % [row, state])
			if row == "gather same": runner.check(phases.get(world.first) == "lead_source" and collection_of(sim, world.first).remaining_ticks == lead, "DL8 %s during %s: first restarts its lead, got %s" % [row, state, collection_of(sim, world.first)])
			if state == "locked": runner.check(phases.get(world.second) == "loading", "DL8 %s during %s: the lock is freed and second loads after the step, got %s" % [row, state, phases])
			else: runner.check(loads_after_lead(sim, world.second), "DL8 %s during %s: second loads when its lead ends, got %s" % [row, state, phases_of(sim.view_state())])
			if state == "lead" and row in LEAVES: runner.check(never_loads_here(world), "DL8 %s during %s: first never loads at this pile" % [row, state])
	var world: Dictionary = pair_world(400, false)
	var sim = world.sim
	var reached: bool = false
	for index in range(2000):
		sim.step()
		if phases_of(sim.view_state()).get(world.first) == "lead_depot":
			reached = true
			break
	runner.check(reached and collection_of(sim, world.first).cargo == 1, "DL8 remove depot during lead_depot: the state is reached")
	sim.remove_object(world.depot)
	sim.step()
	var after: Dictionary = collection_of(sim, world.first)
	runner.check(after.cargo == 1 and after.target_id == null, "DL8 remove depot during lead_depot: keeps cargo 1 and loses the target, got %s" % [after])
	return true

func test_lead_is_not_queued_in_view(runner) -> bool:
	var world: Dictionary = pair_world(400, false)
	var sim = world.sim
	var leading: bool = false
	var waiting: bool = false
	for index in range(600):
		sim.step()
		var units = sim.view_state().units
		var row: int = units.index_of(world.first)
		if row != -1 and units.phase[row] != units.NONE and units.phases[units.phase[row]] == "lead_source":
			leading = true
			runner.check(units.queue[row] == -1 and units.flags[row] & ViewRows.WAITING_SOURCE == 0, "DL9 a laborer in its lead is neither queued nor waiting in the view")
		row = units.index_of(world.second)
		if row != -1 and units.phase[row] != units.NONE and units.phases[units.phase[row]] == "waiting_source":
			waiting = true
			runner.check(units.queue[row] == world.source and units.flags[row] & ViewRows.WAITING_SOURCE != 0, "DL9 a waiting laborer is queued at its pile in the view")
		if leading and waiting: break
	runner.check(leading and waiting, "DL9 a lead and a wait were both seen")
	return true

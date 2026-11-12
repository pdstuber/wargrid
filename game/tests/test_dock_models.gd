@warning_ignore_start("untyped_declaration")
extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Parity = preload("res://tests/test_supply_parity.gd")
const Openings = preload("res://tests/test_income_openings.gd")

const Fixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const DockC = preload("res://scripts/experiments/dock_c.gd")

const MODELS := ["hold", "split", "queue", "c1", "c2"]
const RATIOS := {"c1": Vector2i(184, 300), "c2": Vector2i(44, 75)}
const GATHER_TICK := 0

func cases() -> Array[Callable]:
	return [test_default_model_is_hold, test_steady_rate_window, test_split_lone_cycle_unchanged, test_split_overlaps_lead_in, test_split_same_tick_arrival, test_split_stop_during_lead, test_split_release_on_removal, test_c_tables_follow_the_rule, test_c_lock_clamps_to_the_stand, test_c_lone_cycle_unchanged, test_queue_fifo, test_queue_lock_covers_moves, test_queue_air, test_queue_same_tick_and_removal, test_report_rows]

func models() -> Array:
	var wanted: String = OS.get_environment("WARGRID_DOCK_MODELS")
	if wanted.is_empty(): return MODELS
	var picked: Array = []
	for name in wanted.split(","):
		if name.strip_edges() in MODELS: picked.append(name.strip_edges())
	return picked

func test_default_model_is_hold(runner) -> bool:
	runner.check(Simulation.new([], Vector2i(8, 8)).dock_model == "hold", "a new simulation uses the hold dock model")
	return true

func test_steady_rate_window(runner) -> bool:
	var parity = Parity.new()
	var old: float = parity.rate(parity.layout("frc_builder", 3, 2, "hold").sim, 17)
	var steady: Dictionary = parity.steady_rate(parity.layout("frc_builder", 3, 2, "hold").sim, GATHER_TICK)
	runner.check(absf(steady.per_min - old) <= 0.02 * old, "steady window %.1f within 2%% of the first-deposits rate %.1f" % [steady.per_min, old])
	runner.check(not steady.short, "frc_builder gap 3 x2 fills the steady window")
	return true

func deposit_ticks(sim, count: int) -> Array:
	var ticks: Array = []
	var last: int = sim.view_state().players[0].credits
	for index in range(30000):
		sim.step()
		var credits: int = sim.view_state().players[0].credits
		if credits != last: ticks.append(sim.view_state().tick)
		last = credits
		if ticks.size() == count: break
	return ticks

func test_split_lone_cycle_unchanged(runner) -> bool:
	var parity = Parity.new()
	for kind in parity.TARGETS:
		var held: Array = deposit_ticks(parity.layout(kind, 3, 1, "hold").sim, 9)
		var split: Array = deposit_ticks(parity.layout(kind, 3, 1, "split").sim, 9)
		runner.check(held.size() == 9 and split == held, "%s lone deposits are the same under split: %s vs %s" % [kind, split, held])
	return true

func test_c_tables_follow_the_rule(runner) -> bool:
	var parity = Parity.new()
	for model in RATIOS:
		var table: Dictionary = DockC.tables[model]
		for kind in parity.TARGETS:
			var collects: Dictionary = Registry.collects(kind)
			var loads: int = collects.boxes + 1
			var stand: int = loads * collects.load_ticks
			var earned: int = ceili(collects.boxes * collects.box_value * RATIOS[model].x / float(RATIOS[model].y))
			var box: int = roundi(earned / float(loads))
			var lead: int = stand - loads * box
			var entry: Dictionary = table[kind].source
			runner.check(entry.lead == lead and entry.box == box, "%s %s source is lead %d box %d, got %s" % [model, kind, lead, box, entry])
			runner.check(entry.lead + loads * entry.box == stand, "%s %s source keeps today's pile stand %d" % [model, kind, stand])
			runner.check(table[kind].depot.lead + table[kind].depot.work == collects.unload_ticks, "%s %s depot keeps today's unload stand" % [model, kind])
	return true

func test_c_lock_clamps_to_the_stand(runner) -> bool:
	var collects: Dictionary = Registry.collects(Parity.new().TARGETS.keys()[0])
	var entry: Dictionary = DockC.source_entry(collects, Vector2i(1000, 300))
	runner.check(entry.lead == 0 and entry.box == collects.load_ticks, "a computed lock longer than the stand clamps to lead 0, box load_ticks, got %s" % [entry])
	return true

func test_c_lone_cycle_unchanged(runner) -> bool:
	var parity = Parity.new()
	for kind in parity.TARGETS:
		var held: Array = deposit_ticks(parity.layout(kind, 3, 1, "hold").sim, 9)
		for model in RATIOS:
			var ticks: Array = deposit_ticks(parity.layout(kind, 3, 1, model).sim, 9)
			runner.check(held.size() == 9 and ticks == held, "%s lone deposits are the same under %s: %s vs %s" % [kind, model, ticks, held])
	return true

func phases_of(view: Dictionary) -> Dictionary:
	var units = view.units
	var out: Dictionary = {}
	for index in range(units.size()):
		if units.phase[index] != units.NONE: out[units.id[index]] = units.phases[units.phase[index]]
	return out

func count_phase(phases: Dictionary, phase: String) -> int:
	return phases.values().count(phase)

func test_split_overlaps_lead_in(runner) -> bool:
	var sim = Parity.new().layout("frc_builder", 3, 2, "split").sim
	var overlapped: bool = false
	var doubled: bool = false
	for index in range(1500):
		sim.step()
		var phases: Dictionary = phases_of(sim.view_state())
		if count_phase(phases, "loading") == 1 and count_phase(phases, "lead_source") >= 1: overlapped = true
		if count_phase(phases, "loading") > 1: doubled = true
	runner.check(overlapped, "split: one laborer loads while another is still in its lead-in")
	runner.check(not doubled, "split: never two laborers loading at one pile")
	return true

func dock_world(model: String, kind: String, spots: Array, boxes: int, delete_when_empty: bool) -> Dictionary:
	var sim = Fixture.make_world(10000, Vector2i(48, 24))
	sim.dock_model = model
	Fixture.add_completed(sim, 1, Parity.DEPOT_OF[kind], Vector2i(2, 10))
	var source: int = sim.add_supply_source(Vector2i(8, 9), boxes, Vector2i(4, 5), delete_when_empty)
	var ids: Array = []
	for spot in spots: ids.append(sim.spawn(1, spot, kind))
	Fixture.send(sim, {"type": "gather", "entity_ids": ids, "source_id": source})
	return {"sim": sim, "ids": ids, "source": source, "first": ids[0], "second": ids[1]}

# Laborers a few cells apart on one pile edge reach their dock spots together.
func pair_world(boxes: int, delete_when_empty: bool) -> Dictionary:
	return dock_world("split", "frc_builder", [Vector2(7.5, 10.5), Vector2(7.5, 12.5)], boxes, delete_when_empty)

func test_split_same_tick_arrival(runner) -> bool:
	var world: Dictionary = pair_world(400, false)
	var sim = world.sim
	var left: Dictionary = {}
	var leading: Dictionary = {}
	var after: Dictionary = {}
	for index in range(600):
		sim.step()
		var view: Dictionary = sim.view_state()
		var phases: Dictionary = phases_of(view)
		for id in [world.first, world.second]:
			if phases.get(id) == "lead_source": leading[id] = true
			elif leading.has(id) and not left.has(id):
				left[id] = view.tick
				after[id] = phases.get(id)
		if left.size() == 2: break
	runner.check(left.size() == 2, "split: both lead-ins end")
	runner.check(left.size() == 2 and left[world.first] == left[world.second], "split: both lead-ins end on one tick, got %s" % [left])
	runner.check(after.get(world.first) == "loading" and after.get(world.second) == "waiting_source", "split: both lead-ins ending on one tick give the lock to the lower id, got %s" % [after])
	return true

func test_split_stop_during_lead(runner) -> bool:
	var world: Dictionary = pair_world(400, false)
	var sim = world.sim
	var leading: bool = false
	for index in range(200):
		sim.step()
		if phases_of(sim.view_state()).get(world.first) == "lead_source":
			leading = true
			break
	runner.check(leading, "split: the first laborer reaches its lead-in")
	Fixture.send(sim, {"type": "stop", "entity_ids": [world.first]})
	var loaded: bool = false
	var first_back: bool = false
	for index in range(300):
		sim.step()
		var phases: Dictionary = phases_of(sim.view_state())
		if phases.get(world.second) == "loading": loaded = true
		if phases.get(world.first) in ["lead_source", "waiting_source", "loading"]: first_back = true
	runner.check(loaded, "split: the second laborer still reaches loading after the first was stopped in its lead-in")
	runner.check(not first_back, "split: the stopped laborer no longer collects")
	return true

func wait_for_waiter(world: Dictionary) -> bool:
	for index in range(600):
		world.sim.step()
		var phases: Dictionary = phases_of(world.sim.view_state())
		if phases.get(world.first) == "loading" and phases.get(world.second) == "waiting_source": return true
	return false

func test_split_release_on_removal(runner) -> bool:
	var world: Dictionary = pair_world(400, false)
	runner.check(wait_for_waiter(world), "split: the second laborer waits behind the lock holder")
	world.sim.remove_object(world.first)
	world.sim.step()
	runner.check(phases_of(world.sim.view_state()).get(world.second) == "loading", "split: removing the lock holder lets the waiter load on the next tick")
	world = pair_world(400, false)
	runner.check(wait_for_waiter(world), "split: the second laborer waits behind the lock holder again")
	Fixture.send(world.sim, {"type": "stop", "entity_ids": [world.first]})
	world.sim.step()
	runner.check(phases_of(world.sim.view_state()).get(world.second) == "loading", "split: stopping the lock holder lets the waiter load on the next tick")
	world = pair_world(1, true)
	runner.check(wait_for_waiter(world), "split: the second laborer waits behind the last box")
	for index in range(600):
		world.sim.step()
		if world.sim.view_state().sources.is_empty(): break
	var stuck: int = 0
	for phase in phases_of(world.sim.view_state()).values():
		if phase in ["lead_source", "waiting_source", "loading"]: stuck += 1
	runner.check(world.sim.view_state().sources.is_empty() and stuck == 0, "split: deleting the emptied pile frees every collector")
	return true

const LOCKED_SOURCE := ["entering_source", "loading", "leaving_source"]
const LOCKED_DEPOT := ["entering_depot", "unloading", "leaving_depot"]
const QUEUED := ["queued_source", "queued_depot"]

func locked_count(phases: Dictionary, names: Array) -> int:
	var count: int = 0
	for phase in phases.values():
		if phase in names: count += 1
	return count

func position_of(view: Dictionary, id: int) -> Vector2:
	var index: int = view.units.index_of(id)
	return Vector2(view.units.x[index], view.units.y[index])

# Three laborers on the east edge, the farthest spawned first, so arrival order is not id order; ties on one tick go to the lower id.
func test_queue_fifo(runner) -> bool:
	var world: Dictionary = dock_world("queue", "frc_builder", [Vector2(16.5, 11.5), Vector2(15.5, 11.5), Vector2(14.5, 11.5)], 400, false)
	var arrived: Dictionary = {}
	var entered: Dictionary = {}
	var shared_spot: bool = false
	var two_queued: bool = false
	var doubled: bool = false
	for index in range(1500):
		world.sim.step()
		var view: Dictionary = world.sim.view_state()
		var phases: Dictionary = phases_of(view)
		for id in world.ids:
			var phase: Variant = phases.get(id)
			if phase in ["queued_source", "entering_source"] and not arrived.has(id): arrived[id] = view.tick
			if phase == "entering_source" and not entered.has(id): entered[id] = view.tick
		var spots: Array = []
		for id in world.ids:
			if phases.get(id) == "queued_source": spots.append(position_of(view, id))
		two_queued = two_queued or spots.size() == 2
		for index_a in range(spots.size()):
			for index_b in range(index_a):
				if spots[index_a] == spots[index_b]: shared_spot = true
		if locked_count(phases, LOCKED_SOURCE) > 1: doubled = true
		if entered.size() == 3: break
	var by_arrival: Array = world.ids.duplicate()
	by_arrival.sort_custom(func(a, b): return arrived.get(a, 0) < arrived.get(b, 0) or arrived.get(a, 0) == arrived.get(b, 0) and a < b)
	var by_lock: Array = world.ids.duplicate()
	by_lock.sort_custom(func(a, b): return entered.get(a, 0) < entered.get(b, 0))
	runner.check(arrived.size() == 3 and entered.size() == 3, "queue: all three laborers arrive and get the lock, arrived %s entered %s" % [arrived, entered])
	runner.check(by_arrival == by_lock and by_arrival[0] == world.ids[2], "queue: the lock goes in arrival order %s, got %s" % [by_arrival, by_lock])
	runner.check(not doubled, "queue: never two laborers locked at the pile")
	runner.check(two_queued and not shared_spot, "queue: queued laborers stand on distinct cells")
	return true

func test_queue_lock_covers_moves(runner) -> bool:
	var world: Dictionary = dock_world("queue", "frc_builder", [Vector2(7.5, 10.5), Vector2(7.5, 12.5)], 400, false)
	var holder_phases: Array = []
	var holder: int = -1
	var last_leaving: int = -1
	var first_entering_other: int = -1
	var waited_while_entering: bool = false
	var waited_while_leaving: bool = false
	var doubled: bool = false
	for index in range(900):
		world.sim.step()
		var view: Dictionary = world.sim.view_state()
		var phases: Dictionary = phases_of(view)
		if locked_count(phases, LOCKED_SOURCE) > 1: doubled = true
		if holder == -1:
			for id in world.ids:
				if phases.get(id) == "entering_source": holder = id
		if holder == -1: continue
		var other: int = world.ids[1] if holder == world.ids[0] else world.ids[0]
		var phase: Variant = phases.get(holder)
		if holder_phases.is_empty() or holder_phases[-1] != phase: holder_phases.append(phase)
		if phases.get(other) == "queued_source":
			if phase == "entering_source": waited_while_entering = true
			if phase == "leaving_source": waited_while_leaving = true
		if phase == "leaving_source": last_leaving = view.tick
		if phases.get(other) == "entering_source" and first_entering_other == -1: first_entering_other = view.tick
		if first_entering_other != -1: break
	runner.check(holder_phases.slice(0, 3) == ["entering_source", "loading", "leaving_source"], "queue: the holder goes entering, loading, leaving, got %s" % [holder_phases])
	runner.check(waited_while_entering and waited_while_leaving, "queue: the next laborer waits while the holder moves in and out")
	runner.check(first_entering_other > last_leaving and last_leaving > 0 and not doubled, "queue: the next laborer enters only after the holder left (%d after %d)" % [first_entering_other, last_leaving])
	return true

func test_queue_air(runner) -> bool:
	var world: Dictionary = Parity.new().layout("usa_collector", 9, 2, "queue")
	var unloaded: Dictionary = {}
	var waited_apart: bool = false
	var doubled: bool = false
	for index in range(5000):
		world.sim.step()
		var view: Dictionary = world.sim.view_state()
		var phases: Dictionary = phases_of(view)
		if locked_count(phases, LOCKED_SOURCE) > 1 or locked_count(phases, LOCKED_DEPOT) > 1: doubled = true
		for id in world.ids:
			if phases.get(id) == "unloading": unloaded[id] = true
			if phases.get(id) == "queued_source":
				for other in world.ids:
					if phases.get(other) == "loading" and position_of(view, id).distance_to(position_of(view, other)) > 1.0: waited_apart = true
		if unloaded.size() == 2: break
	runner.check(waited_apart, "queue air: the second helicopter waits at an air spot while the first loads")
	runner.check(unloaded.size() == 2, "queue air: both helicopters deposit, got %s" % [unloaded.keys()])
	runner.check(not doubled, "queue air: never two helicopters locked at one object")
	return true

func advance_until(world: Dictionary, check: Callable, ticks: int) -> bool:
	for index in range(ticks):
		world.sim.step()
		if check.call(phases_of(world.sim.view_state())): return true
	return false

func trio_world() -> Dictionary:
	return dock_world("queue", "frc_builder", [Vector2(7.5, 10.5), Vector2(7.5, 12.5), Vector2(7.5, 14.5)], 400, false)

func test_queue_same_tick_and_removal(runner) -> bool:
	var world: Dictionary = dock_world("queue", "frc_builder", [Vector2(7.5, 10.5), Vector2(7.5, 12.5)], 400, false)
	advance_until(world, func(p): return locked_count(p, LOCKED_SOURCE) == 1 and count_phase(p, "queued_source") == 1, 600)
	var phases: Dictionary = phases_of(world.sim.view_state())
	runner.check(phases.get(world.first) == "entering_source" and phases.get(world.second) == "queued_source", "queue: same-tick arrivals give the lock to the lower id, got %s" % [phases])
	world.sim.remove_object(world.first)
	world.sim.step()
	runner.check(phases_of(world.sim.view_state()).get(world.second) == "entering_source", "queue: removing the holder gives the next laborer the lock on the next tick")
	for stopped in [1, 2]:
		world = trio_world()
		var ready: bool = advance_until(world, func(p): return locked_count(p, LOCKED_SOURCE) == 1 and count_phase(p, "queued_source") == 2, 900)
		runner.check(ready, "queue: one laborer holds the lock and two queue")
		var queued: Array = []
		var held: Dictionary = phases_of(world.sim.view_state())
		for id in world.ids:
			if held.get(id) == "queued_source": queued.append(id)
		Fixture.send(world.sim, {"type": "stop", "entity_ids": [queued[stopped - 1]]})
		var other: int = queued[2 - stopped]
		var reached: bool = advance_until(world, func(p): return p.get(other) == "entering_source", 600)
		runner.check(reached, "queue: stopping queued laborer %d leaves the other one a place in line" % stopped)
		var back: bool = false
		for index in range(300):
			world.sim.step()
			if phases_of(world.sim.view_state()).get(queued[stopped - 1]) in ["queued_source", "entering_source", "loading", "leaving_source"]: back = true
		runner.check(not back, "queue: the stopped laborer no longer collects")
	world = dock_world("queue", "frc_builder", [Vector2(7.5, 10.5), Vector2(7.5, 12.5)], 1, true)
	runner.check(advance_until(world, func(p): return count_phase(p, "queued_source") == 1, 600), "queue: the second laborer waits behind the last box")
	for index in range(900):
		world.sim.step()
		if world.sim.view_state().sources.is_empty(): break
	var stuck: int = 0
	for phase in phases_of(world.sim.view_state()).values():
		if phase in ["queued_source", "entering_source", "loading", "leaving_source"]: stuck += 1
	runner.check(world.sim.view_state().sources.is_empty() and stuck == 0, "queue: deleting the emptied pile frees every collector")
	return true

func seconds_text(seconds: float) -> String:
	return "-" if seconds < 0.0 else "%.1f" % seconds

func single_line(parity, model: String, kind: String, gap: int) -> String:
	var measured: float = parity.rate(parity.layout(kind, gap, 1, model).sim, 9)
	return "DOCK %s single %s gap=%d rate=%.1f" % [model, kind, gap, measured]

func multi_line(parity, model: String, kind: String, gap: int, count: int) -> String:
	var old: float = parity.rate(parity.layout(kind, gap, count, model).sim, 1 + 8 * count)
	var steady: Dictionary = parity.steady_rate(parity.layout(kind, gap, count, model).sim, GATHER_TICK)
	return "DOCK %s multi %s gap=%d x%d old=%.1f steady=%.1f pile_empty=%s short=%s" % [model, kind, gap, count, old, steady.per_min, seconds_text(steady.pile_empty_s), str(steady.short).to_lower()]

func rate_of(line: String, key: String) -> float:
	for part in line.split(" "):
		if part.begins_with(key + "="): return part.trim_prefix(key + "=").to_float()
	return -1.0

# Report only beyond "deposits": the judging against Zero Hour happens in the experiment report.
func test_report_rows(runner) -> bool:
	var parity = Parity.new()
	var openings = Openings.new()
	var picked: Array = models()
	runner.check(not picked.is_empty(), "WARGRID_DOCK_MODELS names at least one known model")
	for model in picked:
		for kind in parity.TARGETS:
			for gap in parity.TARGETS[kind]:
				var line: String = single_line(parity, model, kind, gap)
				print(line)
				runner.check(rate_of(line, "rate") > 0.0, "%s deposits" % line)
		var multi_rows: Array = parity.MULTI.duplicate()
		multi_rows.append(["usa_collector", 9, 4, parity.FOUR_HELICOPTERS_GAP_9])
		for row in multi_rows:
			var line: String = multi_line(parity, model, row[0], row[1], row[2])
			print(line)
			runner.check(rate_of(line, "old") > 0.0 and rate_of(line, "steady") > 0.0, "%s deposits" % line)
		for gap in openings.GAPS:
			for name in openings.OPENINGS:
				var opening: Dictionary = openings.run_opening(name, gap, model)
				print(openings.report_line(name, gap, opening, model))
				runner.check(opening.steady > 0.0 and opening.gross[openings.END_TICK] > opening.spend, "%s gap %d under %s earns more than it spent" % [name, gap, model])
	return true

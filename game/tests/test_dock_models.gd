@warning_ignore_start("untyped_declaration")
extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Parity = preload("res://tests/test_supply_parity.gd")
const Openings = preload("res://tests/test_income_openings.gd")

const Fixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const EconomyDefinitions = preload("res://scripts/simulation/economy_definitions.gd")
const DockC = preload("res://scripts/experiments/dock_c.gd")
const Metrics = preload("res://tests/dock_metrics.gd")
const Probe = preload("res://tests/dock_probe.gd")
const CellTrace = preload("res://tests/dock_cell_trace.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")

const MODELS := ["hold", "split", "queue", "c1", "c2"]
const DEFAULT_MODELS := ["hold", "split", "queue"]
const RATIOS := {"c1": Vector2i(184, 300), "c2": Vector2i(44, 75)}
const GATHER_TICK := 0
const SWEEP_MAX := 8
const SWEEP := [{"kind": "frc_builder", "gap": 3}, {"kind": "frc_builder", "gap": 9}, {"kind": "china_collector", "gap": 9}, {"kind": "usa_collector", "gap": 9}]

func cases() -> Array[Callable]:
	return [test_default_model_is_hold, test_steady_rate_window, test_split_lone_cycle_unchanged, test_split_overlaps_lead_in, test_split_same_tick_arrival, test_split_stop_during_lead, test_split_release_on_removal, test_c_tables_follow_the_rule, test_c_lock_clamps_to_the_stand, test_c_fractional_earnings_round_up, test_c_lone_cycle_unchanged, test_queue_fifo, test_queue_lock_covers_moves, test_queue_air, test_queue_same_tick_and_removal, test_report_rows, test_wargrid_saturation_matches_python, test_wargrid_saturation_skips_short, test_phase_shares_sum_to_100, test_sweep_row_flags_an_emptied_pile, test_sweep_rows, test_probe_transplant_spawns_every_start, test_probe_transplant_fails_on_an_occupied_start, test_probe_delayed_gather, test_probe_window_rate, test_probe_swap_rows, test_probe_gap_counts_empty_samples, test_probe_leg_parts, test_probe_leg_zones_and_distance, test_probe_unknown_phase_is_other, test_probe_drops_partial_legs, test_probe_counts_overlaps, test_probe_drop_counts_blocked, test_probe_cycle, test_probe_leaves_the_run_unchanged, test_probe_rows, test_cell_trace_leg_cells, test_cell_trace_held_names_other_holders, test_cell_trace_leg_without_dock, test_cell_trace_drops_partial_legs, test_cell_trace_counts_reroutes, test_cell_trace_geometry, test_cell_trace_keeps_trace_only_when_asked, test_cell_trace_leaves_the_run_unchanged, test_cell_trip]

func models() -> Array:
	var wanted: String = OS.get_environment("WARGRID_DOCK_MODELS")
	if wanted.is_empty(): return DEFAULT_MODELS # c1 and c2 add two long-sim models; the unfiltered CI suite stays on the original three
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

func test_c_fractional_earnings_round_up(runner) -> bool:
	var collects: Dictionary = Registry.collects(Parity.new().TARGETS.keys()[0])
	var loads: int = collects.boxes + 1
	var entry: Dictionary = DockC.source_entry(collects, Vector2i(1, 7))
	var credits: int = collects.boxes * collects.box_value
	runner.check(credits % 7 != 0, "the 1/7 fixture leaves a fractional earning")
	runner.check(entry.box == roundi(ceili(credits / 7.0) / float(loads)), "ratio 1/7 sizes the lock from the rounded-up earning, got %s" % [entry])
	runner.check(entry.box != roundi(floori(credits / 7.0) / float(loads)), "floor would give a different box, got %s" % [entry])
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

func test_wargrid_saturation_matches_python(runner) -> bool:
	var rates := {1: 434.0, 2: 855.0, 3: 1270.0, 4: 1650.0, 5: 2000.0, 6: 2010.0, 7: 2010.0, 8: 1990.0}
	var s: Dictionary = Metrics.saturation(rates, 200)
	runner.check(s.cap == 2010.0 and s.n_cap == 6 and s.n90 == 5 and s.spend90 == 800, "saturation cap/n_cap/n90/spend90, got %s" % [s])
	runner.check(s.marginal[6] == 10.0, "marginal at 6 is 10, got %s" % [s.marginal])
	runner.check(is_inf(s.payback_s[8]) and is_inf(s.payback_s[7]), "a zero or negative marginal pays back never (inf), got %s" % [s.payback_s])
	runner.check(s.payback_s[2] == 200.0 / ((855.0 - 434.0) / 60.0), "payback at 2 is cost / (marginal per second), got %s" % [s.payback_s[2]])
	runner.check(s.skipped == [], "nothing skipped, got %s" % [s.skipped])
	return true

func test_wargrid_saturation_skips_short(runner) -> bool:
	var s: Dictionary = Metrics.saturation({1: 400.0, 2: 800.0, 3: null, 4: 900.0, 5: 5000.0}, 200, [4, 5])
	runner.check(s.skipped == [3, 4, 5], "short and missing rows are skipped, got %s" % [s.skipped])
	runner.check(s.cap == 800.0 and s.n_cap == 2 and s.n90 == 2, "skipped rows do not set the cap, got %s" % [s])
	runner.check(s.marginal.keys() == [2], "marginal only between used neighbours, got %s" % [s.marginal.keys()])
	runner.check(Metrics.saturation({1: 5.0}, 200, [1]) == {"skipped": [1]}, "all rows skipped gives only the skipped list")
	return true

func test_phase_shares_sum_to_100(runner) -> bool:
	var sim = Parity.new().layout("frc_builder", 3, 7, "hold").sim
	var tally: Dictionary = {}
	for index in range(3000):
		sim.step()
		count_unit_phases(sim.view_state(), "frc_builder", tally)
	var shares: Dictionary = phase_shares(tally)
	var total: float = 0.0
	for share in shares.values(): total += share
	runner.check(absf(total - 100.0) <= 0.1, "phase shares sum to 100, got %f from %s" % [total, shares])
	runner.check(shares.has("loading") and shares.has("unloading"), "shares include loading and unloading, got %s" % [shares.keys()])
	return true

func test_sweep_row_flags_an_emptied_pile(runner) -> bool:
	var world: Dictionary = dock_world("hold", "frc_builder", [Vector2(7.5, 10.5), Vector2(7.5, 12.5), Vector2(7.5, 14.5)], 20, false)
	var row: Dictionary = sweep_row(world.sim, "hold", "frc_builder", 3, 3)
	runner.check(row.short and row.line.ends_with("short=true") and "pile_empty=-" not in row.line, "an emptied pile is reported with its time and short, got %s" % [row.line])
	return true

func test_sweep_rows(runner) -> bool:
	if OS.get_environment("WARGRID_DOCK_SWEEP") != "1":
		runner.check(true, "dock sweep rows run only with WARGRID_DOCK_SWEEP=1")
		return true
	var parity = Parity.new()
	var openings = Openings.new()
	for model in models():
		for target in SWEEP:
			var rates: Dictionary = {}
			var short: Array = []
			for count in range(1, SWEEP_MAX + 1):
				var row: Dictionary = sweep_row(parity.layout(target.kind, target.gap, count, model).sim, model, target.kind, target.gap, count)
				print(row.line)
				runner.check(row.rate > 0.0, "%s deposits" % row.line)
				rates[count] = row.rate
				if row.short: short.append(count)
			var line: String = saturation_line(model, target.kind, target.gap, Metrics.saturation(rates, int(EconomyDefinitions.unit(target.kind).cost), short))
			print(line)
			runner.check(line.contains(" cap=") or line.contains(" skipped="), "%s is a saturation row" % line)
		var tally: Dictionary = {}
		var counter := func(tick: int, view: Dictionary, source: int) -> void:
			if tick > openings.STEADY_FROM_TICK and openings.pile_boxes(view, source) > 0: count_unit_phases(view, "frc_builder", tally)
		openings.run_opening("frc7", 3, model, counter)
		var line: String = phases_line(model, phase_shares(tally))
		print(line)
		runner.check(not tally.is_empty(), "%s has phase counts" % line)
	return true

func sweep_row(sim, model: String, kind: String, gap: int, count: int) -> Dictionary:
	var steady: Dictionary = Parity.new().steady_rate(sim, GATHER_TICK)
	var line: String = "DOCK %s sweep %s gap=%d n=%d steady=%.1f pile_empty=%s short=%s" % [model, kind, gap, count, steady.per_min, seconds_text(steady.pile_empty_s), str(steady.short).to_lower()]
	return {"line": line, "rate": steady.per_min, "short": steady.short}

func joined(values: Dictionary, format: Callable) -> String:
	var parts: Array = []
	var keys: Array = values.keys()
	keys.sort()
	for key in keys: parts.append("%d:%s" % [key, format.call(values[key])])
	return ",".join(parts)

func saturation_line(model: String, kind: String, gap: int, result: Dictionary) -> String:
	var skipped: String = "-" if result.skipped.is_empty() else ",".join(result.skipped.map(str))
	if not result.has("cap"): return "DOCK %s saturation %s gap=%d skipped=%s" % [model, kind, gap, skipped]
	var payback := func(value: float) -> String: return "inf" if is_inf(value) else "%.1f" % value
	var plain := func(value: float) -> String: return "%.1f" % value
	return "DOCK %s saturation %s gap=%d cap=%.1f n_cap=%d n90=%d spend90=%d marginal=%s payback_s=%s skipped=%s" % [model, kind, gap, result.cap, result.n_cap, result.n90, result.spend90, joined(result.marginal, plain), joined(result.payback_s, payback), skipped]

func count_unit_phases(view: Dictionary, kind: String, tally: Dictionary) -> void:
	var units = view.units
	for index in range(units.size()):
		if units.kinds[units.kind[index]] != kind: continue
		var phase: String = "none" if units.phase[index] == units.NONE else units.phases[units.phase[index]]
		tally[phase] = tally.get(phase, 0) + 1

func phase_shares(tally: Dictionary) -> Dictionary:
	var total: int = 0
	for count in tally.values(): total += count
	var shares: Dictionary = {}
	for phase in tally: shares[phase] = 100.0 * tally[phase] / total
	return shares

func phases_line(model: String, shares: Dictionary) -> String:
	var names: Array = shares.keys()
	names.sort()
	var parts: Array = []
	for name in names: parts.append("%s=%.1f" % [name, shares[name]])
	return "DOCK %s phases frc7 gap=3 %s" % [model, ",".join(parts)]

func collecting(sim, id: int) -> bool:
	var units = sim.view_state().units
	var index: int = units.index_of(id)
	return index >= 0 and (units.flags[index] & ViewRows.COLLECTING) != 0

func test_probe_transplant_spawns_every_start(runner) -> bool:
	var world: Dictionary = transplant("split", [{"tick": 0, "position": Vector2(5.5, 10.5)}, {"tick": 5, "position": Vector2(5.5, 12.5)}])
	runner.check(world.ids.size() == 2 and not world.ids.has(-1), "every start spawns, got %s" % [world.ids])
	runner.check(world.sim.view_state().tick == 5, "transplant returns after the last start's tick")
	world.sim.step()
	runner.check(collecting(world.sim, world.ids[0]) and collecting(world.sim, world.ids[1]), "every transplanted unit gathers")
	return true

func test_probe_transplant_fails_on_an_occupied_start(runner) -> bool:
	var world: Dictionary = transplant("split", [{"tick": 0, "position": Vector2(3.5, 11.5)}])
	runner.check(world.ids.has(-1), "a start inside the depot is reported as -1, not skipped")
	return true

func test_probe_delayed_gather(runner) -> bool:
	var world: Dictionary = delayed_world("split", 10)
	var last: int = world.ids[world.ids.size() - 1]
	runner.check(world.sim.view_state().tick == 10 and not collecting(world.sim, last), "the delayed unit is not gathering before its delay")
	world.sim.step()
	runner.check(collecting(world.sim, last) and collecting(world.sim, world.ids[0]), "the delayed unit gathers after its delay, the others from the start")
	return true

func test_probe_window_rate(runner) -> bool:
	runner.check(window_rate(PackedInt32Array([0, 0, 75, 75]), 1, 3) == 1800.0 * 75 / 2, "window rate is credits per minute over the window")
	return true

const PERTURB_DELAYS := [0, 1, 2, 3, 5, 8, 13, 21]
const PROBE_TO_TICK := 18000
const PROBE_DEPOT := Vector2(3.5, 11.5)

func probe_pile(gap: int) -> Vector2:
	return Vector2(7 + gap, 11.5)

func probe_models() -> Array:
	return models().filter(func(model: String) -> bool: return model != "queue")

func opening_starts(model: String) -> Dictionary:
	var seen: Dictionary = {}
	var starts: Array = []
	var recorder := func(tick: int, view: Dictionary, _source: int) -> void:
		var units = view.units
		for index in range(units.size()):
			if units.kinds[units.kind[index]] != "frc_builder" or seen.has(units.id[index]) or (units.flags[index] & ViewRows.COLLECTING) == 0: continue
			seen[units.id[index]] = true
			starts.append({"tick": tick, "position": Vector2(units.x[index], units.y[index])})
	var opening: Dictionary = Openings.new().run_opening("frc7", 3, model, recorder)
	starts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.tick < b.tick)
	return {"starts": starts, "steady": opening.steady}

# Sweep world (Parity.layout gap 3), units spawned and sent to gather at the starts' ticks relative to the first.
func transplant(model: String, starts: Array) -> Dictionary:
	var sim = Fixture.make_world(10000, Vector2i(48, 24))
	sim.dock_model = model
	Fixture.add_completed(sim, 1, "frc_supply_center", Vector2i(2, 10))
	var source: int = sim.add_supply_source(Vector2i(8, 9), 400)
	var ids: Array = []
	for start in starts:
		while sim.view_state().tick < start.tick - starts[0].tick: sim.step()
		var id: int = sim.spawn(1, start.position, "frc_builder")
		ids.append(id)
		if id >= 0: Fixture.send(sim, {"type": "gather", "entity_ids": [id], "source_id": source})
	return {"sim": sim, "source": source, "ids": ids}

func credits_until(sim, to_tick: int) -> PackedInt32Array:
	var credits := PackedInt32Array()
	credits.resize(to_tick + 1)
	var view: Dictionary = sim.view_state()
	for tick in range(view.tick + 1): credits[tick] = view.players[0].credits
	while view.tick < to_tick:
		sim.step()
		view = sim.view_state()
		credits[view.tick] = view.players[0].credits
	return credits

func window_rate(credits: PackedInt32Array, from_tick: int, to_tick: int) -> float:
	return 1800.0 * (credits[to_tick] - credits[from_tick]) / (to_tick - from_tick)

func delayed_world(model: String, delay: int) -> Dictionary:
	var world: Dictionary = Parity.new().layout("frc_builder", 3, 7, model)
	if delay <= 0: return world
	var last: int = world.ids[world.ids.size() - 1]
	Fixture.send(world.sim, {"type": "stop", "entity_ids": [last]})
	while world.sim.view_state().tick < delay: world.sim.step()
	Fixture.send(world.sim, {"type": "gather", "entity_ids": [last], "source_id": world.source})
	return world

func delayed_sweep(model: String, delay: int) -> float:
	return Parity.new().steady_rate(delayed_world(model, delay).sim, GATHER_TICK).per_min

func test_probe_swap_rows(runner) -> bool:
	if OS.get_environment("WARGRID_DOCK_PROBE") != "1":
		runner.check(true, "dock probe rows run only with WARGRID_DOCK_PROBE=1")
		return true
	for model in probe_models():
		var opening: Dictionary = opening_starts(model)
		var starts: Array = opening.starts
		var t0: int = starts[0].tick
		var sweep: float = Parity.new().steady_rate(Parity.new().layout("frc_builder", 3, 7, model).sim, GATHER_TICK).per_min
		var world: Dictionary = transplant(model, starts)
		var spawned: int = world.ids.filter(func(id: int) -> bool: return id >= 0).size()
		var credits: PackedInt32Array = credits_until(world.sim, PROBE_TO_TICK)
		var relative: Array = starts.map(func(start: Dictionary) -> String: return str(start.tick - t0))
		print("DOCK %s swap frc7 gap=3 opening=%.1f sweep_n7=%.1f transplant=%.1f transplant_opening_window=%.1f t0=%d spawned=%d starts=%s" % [model, opening.steady, sweep, window_rate(credits, 9000, PROBE_TO_TICK), window_rate(credits, 9000 - t0, PROBE_TO_TICK - t0), t0, spawned, ",".join(relative)])
		runner.check(spawned == 7, "%s transplant spawns all 7 starts, got %d of %d" % [model, spawned, starts.size()])
		runner.check(Openings.new().pile_boxes(world.sim.view_state(), world.source) > 0, "%s transplant pile still has boxes at the end" % model)
		var rates: Dictionary = {}
		for delay in PERTURB_DELAYS: rates[delay] = delayed_sweep(model, delay)
		var spread: float = rates.values().max() - rates.values().min()
		print("DOCK %s perturb frc_builder gap=3 n=7 rates=%s spread=%.1f" % [model, joined(rates, func(value: float) -> String: return "%.1f" % value), spread])
	return true

func unit_row(phase: String, status: String = "moving", position: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"phase": phase, "status": status, "position": position}

func feed(probe, timeline: Array) -> void:
	for tick in range(timeline.size()): probe.observe(tick + 1, timeline[tick])

func test_probe_gap_counts_empty_samples(runner) -> bool:
	var probe = Probe.new()
	var timeline: Array = []
	for tick in range(1, 7):
		var units: Dictionary = {}
		if tick <= 3: units[1] = unit_row("loading")
		if tick == 6: units[2] = unit_row("loading")
		if tick <= 5: units[3] = unit_row("waiting_source")
		timeline.append(units)
	feed(probe, timeline)
	var s: Dictionary = probe.summary()
	runner.check(s.gaps == [2] and s.contended == [2] and s.ready == [2], "two empty samples between holders, contended and ready, got %s" % [s])
	runner.check(s.idle_samples == 2 and s.samples == 6, "idle samples counted, got %s" % [s])
	var direct = Probe.new()
	feed(direct, [{1: unit_row("loading")}, {1: unit_row("flying_depot"), 2: unit_row("loading")}])
	runner.check(direct.summary().gaps == [0] and direct.summary().contended == [], "a direct handoff is a 0 gap, uncontended, got %s" % [direct.summary()])
	return true

func test_probe_leg_parts(runner) -> bool:
	var probe = Probe.new()
	var timeline: Array = [{1: unit_row("unloading")}, {1: unit_row("seeking")}, {1: unit_row("flying_source", "path_pending")}]
	for x in [1.0, 2.0, 3.0]: timeline.append({1: unit_row("flying_source", "moving", Vector2(x, 0))})
	timeline.append({1: unit_row("lead_source", "arrived", Vector2(3, 0))})
	timeline.append({1: unit_row("lead_source", "arrived", Vector2(3, 0))})
	timeline.append({1: unit_row("loading", "arrived", Vector2(3, 0))})
	feed(probe, timeline)
	var legs: Array = probe.summary().legs_empty
	var expected: Dictionary = {"total": 7, "flying": 4, "standing": 2, "other": 1, "moved": 3, "path_pending": 1}
	runner.check(legs.size() == 1 and expected.keys().all(func(key: String) -> bool: return legs[0][key] == expected[key]), "one empty leg with its parts, got %s" % [legs])
	return true

func test_probe_leg_zones_and_distance(runner) -> bool:
	var probe = Probe.new(Vector2(0, 0), Vector2(9, 0))
	var timeline: Array = [{1: unit_row("unloading", "arrived", Vector2(0, 0))}, {1: unit_row("flying_source", "moving", Vector2(1, 0))}]
	timeline.append({1: unit_row("flying_source", "moving", Vector2(4.5, 0)), 2: unit_row("lead_source", "arrived", Vector2(4.5, 0.5))})
	timeline.append({1: unit_row("flying_source", "moving", Vector2(8, 0))})
	timeline.append({1: unit_row("loading", "arrived", Vector2(8, 0))})
	feed(probe, timeline)
	var leg: Dictionary = probe.summary().legs_empty[0]
	runner.check(is_equal_approx(leg.distance, 8.0), "leg distance is the path walked, got %s" % [leg])
	runner.check(leg.flying_depot_zone == 1 and leg.flying_mid == 1 and leg.flying_pile_zone == 1, "flying ticks split by thirds of the depot-pile axis, got %s" % [leg])
	runner.check(leg.crowded == 1, "a flying tick with another unit within one cell is crowded, got %s" % [leg])
	return true

func test_probe_unknown_phase_is_other(runner) -> bool:
	var probe = Probe.new()
	feed(probe, [{1: unit_row("unloading")}, {1: unit_row("none")}, {1: unit_row("flying_source")}, {1: unit_row("loading")}])
	var leg: Dictionary = probe.summary().legs_empty[0]
	runner.check(leg.other == 1 and leg.total == leg.flying + leg.standing + leg.other, "an unnamed phase counts as other, got %s" % [leg])
	return true

func test_probe_drops_partial_legs(runner) -> bool:
	var probe = Probe.new()
	feed(probe, [{1: unit_row("flying_source")}, {1: unit_row("loading")}, {1: unit_row("flying_depot")}])
	var s: Dictionary = probe.summary()
	runner.check(s.legs_empty == [] and s.legs_loaded == [], "a leg cut by the first sighting or the last tick is dropped, got %s" % [s])
	return true

func test_probe_counts_overlaps(runner) -> bool:
	var probe = Probe.new()
	feed(probe, [{1: unit_row("loading")}, {1: unit_row("loading"), 2: unit_row("loading")}, {2: unit_row("loading")}])
	runner.check(probe.summary().overlaps == 1 and probe.summary().gaps == [], "two loading units on one tick is an overlap, not a gap, got %s" % [probe.summary()])
	return true

func test_probe_drop_counts_blocked(runner) -> bool:
	var probe = Probe.new()
	feed(probe, [{1: unit_row("flying_source", "blocked")}, {1: unit_row("seeking", "idle")}])
	runner.check(probe.summary().drops == 1 and probe.summary().drops_blocked == 1, "a blocked flight that falls back to seeking is a blocked drop, got %s" % [probe.summary()])
	return true

func test_probe_cycle(runner) -> bool:
	var probe = Probe.new()
	for tick in range(1, 400):
		probe.observe(tick, {1: unit_row("unloading" if tick in [10, 11, 320] else "flying_source")})
	runner.check(probe.summary().cycles == [310] and probe.summary().trips == 2, "cycle is ticks between unloading starts, got %s" % [probe.summary()])
	runner.check(Probe.quantile([3, 1, 2], 0.5) == 2.0 and Probe.quantile([], 0.5) == -1.0, "nearest-rank median, -1 when empty")
	return true

func test_probe_leaves_the_run_unchanged(runner) -> bool:
	var a = Parity.new().layout("frc_builder", 3, 7, "split").sim
	var b = Parity.new().layout("frc_builder", 3, 7, "split").sim
	var probe = Probe.new()
	for index in range(3000):
		a.step()
		b.step()
		var view: Dictionary = b.view_state()
		probe.observe(view.tick, Probe.units_of(view, "frc_builder"))
	runner.check(StateHash.digest(a.snapshot()) == StateHash.digest(b.snapshot()), "observing every tick leaves the state hash unchanged")
	runner.check(probe.summary().trips > 0, "the observed run records trips")
	return true

func probe_sweep(model: String, gap: int, count: int) -> Dictionary:
	var world: Dictionary = Parity.new().layout("frc_builder", gap, count, model)
	var probe = Probe.new(PROBE_DEPOT, probe_pile(gap))
	var openings = Openings.new()
	while world.sim.view_state().tick < PROBE_TO_TICK:
		world.sim.step()
		var view: Dictionary = world.sim.view_state()
		if openings.pile_boxes(view, world.source) <= 0: break
		if view.tick > 9000: probe.observe(view.tick, Probe.units_of(view, "frc_builder"))
	return probe.summary()

func probe_opening(model: String, gap: int) -> Dictionary:
	var probe = Probe.new(PROBE_DEPOT, probe_pile(gap))
	var openings = Openings.new()
	var observer := func(tick: int, view: Dictionary, source: int) -> void:
		if tick > openings.STEADY_FROM_TICK and openings.pile_boxes(view, source) > 0: probe.observe(tick, Probe.units_of(view, "frc_builder"))
	openings.run_opening("frc7", gap, model, observer)
	return probe.summary()

func test_probe_rows(runner) -> bool:
	if OS.get_environment("WARGRID_DOCK_PROBE") != "1":
		runner.check(true, "dock probe rows run only with WARGRID_DOCK_PROBE=1")
		return true
	for model in probe_models():
		var rows: Dictionary = {}
		for gap in [3, 9]:
			for count in [1, 7]: rows["sweep_g%d_n%d" % [gap, count]] = probe_sweep(model, gap, count)
			rows["frc7_g%d" % gap] = probe_opening(model, gap)
		for scenario in rows:
			print(Probe.line(model, scenario, rows[scenario]))
			runner.check(rows[scenario].trips > 0 and rows[scenario].overlaps == 0, "%s %s has trips and no overlaps" % [model, scenario])
	return true

func cell_row(id: int, phase: String, position: Vector2, dock: Variant = null, target: int = 5, status: String = "moving", route: Array = []) -> Dictionary:
	var collection: Dictionary = {"phase": phase, "target_id": target}
	if dock != null: collection.dock = dock
	return {"id": id, "kind": "frc_builder", "position": [position.x, position.y], "status": status, "route": route, "collection": collection}

func cell_feed(trace, timeline: Array) -> void:
	for tick in range(timeline.size()): trace.observe(tick + 1, timeline[tick])

func cell_leg_timeline() -> Array:
	var route: Array = [[6.5, 11.5], [7.5, 11.5], [7.5, 10.5]]
	var start := Vector2(5.5, 11.5)
	return [
		[cell_row(1, "unloading", start)],
		[cell_row(1, "seeking", start, null, 5, "idle")],
		[cell_row(1, "flying_source", start, [7, 10], 5, "path_pending")],
		[cell_row(1, "flying_source", start, [7, 10], 5, "moving", route)],
		[cell_row(1, "flying_source", Vector2(6.5, 11.5), [7, 10], 5, "moving", route)],
		[cell_row(1, "flying_source", Vector2(7.5, 11.5), [7, 10], 5, "moving", route)],
		[cell_row(1, "flying_source", Vector2(7.5, 10.5), [7, 10], 5, "moving", route)],
		[cell_row(1, "loading", Vector2(7.5, 10.5), [7, 10])],
	]

func test_cell_trace_leg_cells(runner) -> bool:
	var trace = CellTrace.new()
	cell_feed(trace, cell_leg_timeline())
	runner.check(trace.legs.size() == 1, "one closed leg, got %d" % trace.legs.size())
	if trace.legs.is_empty(): return true
	var leg: Dictionary = trace.legs[0]
	runner.check(leg.kind == "empty" and leg.start_cell == Vector2i(5, 11) and leg.end_cell == Vector2i(7, 10), "empty leg from 5,11 to 7,10, got %s" % [leg])
	runner.check(leg.route == 3.0 and leg.corners == 1 and leg.moved_len == 3.0, "route 3 with one corner, walked 3, got %s" % [leg])
	runner.check(leg.flying == 5 and leg.moved_ticks == 3 and leg.routes == 1 and leg.held == "", "flying 5, moved 3 ticks, one route, nobody held, got %s" % [leg])
	return true

func test_cell_trace_held_names_other_holders(runner) -> bool:
	var trace = CellTrace.new()
	var timeline: Array = cell_leg_timeline()
	for row in timeline:
		row.append(cell_row(2, "loading", Vector2(7.5, 11.5), [7, 11]))
		row.append(cell_row(3, "unloading", Vector2(5.5, 11.5), [5, 11], 9))
	cell_feed(trace, timeline)
	var held := ""
	for leg in trace.legs:
		if leg.id == 1: held = leg.held
	runner.check(held == "7,11:loading", "held names the other holder of the same target only, got '%s'" % held)
	return true

func test_cell_trace_leg_without_dock(runner) -> bool:
	var trace = CellTrace.new()
	var start := Vector2(5.5, 11.5)
	cell_feed(trace, [[cell_row(1, "unloading", start)], [cell_row(1, "seeking", start)], [cell_row(1, "idle", start)], [cell_row(1, "flying_source", start)], [cell_row(1, "loading", start)]])
	runner.check(trace.legs.size() == 1 and trace.legs[0].end_cell == Vector2i(-1, -1), "a leg without a claim stays, with no end cell")
	return true

func test_cell_trace_drops_partial_legs(runner) -> bool:
	var trace = CellTrace.new()
	var start := Vector2(5.5, 11.5)
	cell_feed(trace, [[cell_row(1, "flying_source", start)], [cell_row(1, "flying_source", start)], [cell_row(1, "loading", start)], [cell_row(1, "flying_depot", start)]])
	runner.check(trace.legs.is_empty(), "a leg first seen mid-way and a leg still open at the end are dropped, got %s" % [trace.legs])
	return true

func test_cell_trace_counts_reroutes(runner) -> bool:
	var trace = CellTrace.new()
	var start := Vector2(5.5, 11.5)
	var first: Array = [[6.5, 11.5]]
	var second: Array = [[5.5, 12.5]]
	cell_feed(trace, [[cell_row(1, "unloading", start)], [cell_row(1, "flying_source", start, [7, 10], 5, "path_pending")], [cell_row(1, "flying_source", start, [7, 10], 5, "moving", first)], [cell_row(1, "flying_source", start, [7, 10], 5, "path_pending")], [cell_row(1, "flying_source", start, [7, 10], 5, "moving", second)], [cell_row(1, "loading", start)]])
	runner.check(trace.legs.size() == 1 and trace.legs[0].routes == 2 and trace.legs[0].route == 1.0, "two routes, length from the first one, got %s" % [trace.legs])
	return true

func test_cell_trace_geometry(runner) -> bool:
	runner.check(CellTrace.route_length(Vector2(0, 0), [[1.0, 0.0], [1.0, 1.0]]) == 2.0, "route length sums the segments")
	runner.check(CellTrace.corners(Vector2(0, 0), [[1.0, 0.0], [1.0, 1.0]]) == 1 and CellTrace.corners(Vector2(0, 0), [[1.0, 0.0], [2.0, 0.0]]) == 0, "a turn is a corner, a straight run is not")
	runner.check(CellTrace.manhattan(Vector2i(5, 11), Vector2i(7, 10)) == 3, "manhattan distance")
	return true

func test_cell_trace_keeps_trace_only_when_asked(runner) -> bool:
	var kept = CellTrace.new(true)
	var plain = CellTrace.new()
	cell_feed(kept, cell_leg_timeline())
	cell_feed(plain, cell_leg_timeline())
	var leg: Dictionary = kept.legs[0]
	runner.check(leg.trace.size() == leg.end_tick - leg.start_tick + 1 and leg.trace[0].begins_with("T "), "one trace line per leg tick")
	runner.check(plain.legs[0].trace.is_empty(), "no trace lines unless asked")
	return true

func test_cell_trace_leaves_the_run_unchanged(runner) -> bool:
	var a = Parity.new().layout("frc_builder", 3, 7, "split").sim
	var b = Parity.new().layout("frc_builder", 3, 7, "split").sim
	var trace = CellTrace.new()
	for index in range(3000):
		a.step()
		b.step()
		trace.observe(b.view_state().tick, b.snapshot().entities)
	runner.check(StateHash.digest(a.snapshot()) == StateHash.digest(b.snapshot()), "snapshotting every tick leaves the state hash unchanged")
	runner.check(not trace.legs.is_empty(), "the observed run records legs")
	return true

func trip_leg(legs: Array, low: int, high: int) -> Dictionary:
	for leg in legs:
		if leg.kind == "loaded" and leg.flying >= low and leg.flying <= high: return leg
	return {}

func print_trip(label: String, leg: Dictionary) -> void:
	if leg.is_empty(): return
	var start: Vector2i = leg.start_cell
	var end: Vector2i = leg.end_cell
	print("DOCK split trip %s id=%d start=%d,%d end=%d,%d route=%.2f manhattan=%d corners=%d flying=%d moved_len=%.2f held=%s" % [label, leg.id, start.x, start.y, end.x, end.y, leg.route, CellTrace.manhattan(start, end), leg.corners, leg.flying, leg.moved_len, leg.held])
	for line in leg.trace: print("DOCK split trip %s %s" % [label, line])

func test_cell_trip(runner) -> bool:
	if OS.get_environment("WARGRID_DOCK_PROBE") != "1":
		runner.check(true, "dock cell trip runs only with WARGRID_DOCK_PROBE=1")
		return true
	var world: Dictionary = transplant("split", opening_starts("split").starts)
	runner.check(not world.ids.has(-1) and world.ids.size() == 7, "all 7 transplant starts spawn, got %s" % [world.ids])
	var trace = CellTrace.new(true)
	var openings = Openings.new()
	while world.sim.view_state().tick < PROBE_TO_TICK:
		world.sim.step()
		var view: Dictionary = world.sim.view_state()
		if openings.pile_boxes(view, world.source) <= 0: break
		if view.tick > 9000: trace.observe(view.tick, world.sim.snapshot().entities)
	var loaded: Array = trace.legs.filter(func(leg: Dictionary) -> bool: return leg.kind == "loaded")
	print("DOCK split trip loaded_flying_median=%.1f" % Probe.quantile(loaded.map(func(leg: Dictionary) -> float: return float(leg.flying)), 0.5))
	for kind in ["empty", "loaded"]: print("DOCK split trip flying_%s=%s" % [kind, ",".join(trace.legs.filter(func(leg: Dictionary) -> bool: return leg.kind == kind).map(func(leg: Dictionary) -> String: return str(leg.flying)))])
	var slow: Dictionary = trip_leg(trace.legs, 127, 139)
	var normal: Dictionary = trip_leg(trace.legs, 91, 103)
	runner.check(not slow.is_empty() and not normal.is_empty(), "a slow (127..139) and a normal (91..103, the fast loaded leg of this run is 97) loaded leg exist")
	print_trip("slow", slow)
	print_trip("normal", normal)
	return true

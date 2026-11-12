@warning_ignore_start("untyped_declaration")
extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Parity = preload("res://tests/test_supply_parity.gd")
const Openings = preload("res://tests/test_income_openings.gd")

const Fixture = preload("res://tests/economy_fixture.gd")

const MODELS := ["hold", "split"]
const GATHER_TICK := 0

func cases() -> Array[Callable]:
	return [test_default_model_is_hold, test_steady_rate_window, test_split_lone_cycle_unchanged, test_split_overlaps_lead_in, test_split_same_tick_arrival, test_split_release_on_removal, test_report_rows]

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

# Laborers a few cells apart on one pile edge reach their dock spots together.
func pair_world(boxes: int, delete_when_empty: bool) -> Dictionary:
	var sim = Fixture.make_world(10000, Vector2i(48, 24))
	sim.dock_model = "split"
	Fixture.add_completed(sim, 1, "frc_supply_center", Vector2i(2, 10))
	var source: int = sim.add_supply_source(Vector2i(8, 9), boxes, Vector2i(4, 5), delete_when_empty)
	var first: int = sim.spawn(1, Vector2(7.5, 10.5), "frc_builder")
	var second: int = sim.spawn(1, Vector2(7.5, 12.5), "frc_builder")
	Fixture.send(sim, {"type": "gather", "entity_ids": [first, second], "source_id": source})
	return {"sim": sim, "first": first, "second": second}

func test_split_same_tick_arrival(runner) -> bool:
	var world: Dictionary = pair_world(400, false)
	var sim = world.sim
	var lead_ended: bool = false
	var simultaneous: bool = false
	var was_leading: bool = false
	for index in range(600):
		sim.step()
		var phases: Dictionary = phases_of(sim.view_state())
		var leading: bool = count_phase(phases, "lead_source") > 0
		if was_leading and not leading:
			lead_ended = true
			simultaneous = phases.get(world.first) == "loading" and phases.get(world.second) == "waiting_source"
			break
		was_leading = leading
	runner.check(lead_ended, "split: the lead-in ends")
	runner.check(simultaneous, "split: both lead-ins ending on one tick give the lock to the lower id")
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

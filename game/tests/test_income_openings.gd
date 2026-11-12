@warning_ignore_start("untyped_declaration")
extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Fixture = preload("res://tests/economy_fixture.gd")

const TICKS_PER_SECOND := 30
const SECONDS := [60, 120, 180, 300, 600]
const END_TICK := 600 * TICKS_PER_SECOND
const STEADY_FROM_TICK := 300 * TICKS_PER_SECOND
const START_CREDITS := 10000
const PILE_BOXES := 400
const DEPOT_ORIGIN := Vector2i(2, 10)
# faction, collector kind, trained collectors, collectors in total (start worker and free spawn included).
const OPENINGS := {
	"usa2": {"faction": "usa", "collector": "usa_collector", "trained": 1, "total": 2},
	"china3": {"faction": "china", "collector": "china_collector", "trained": 2, "total": 3},
	"frc5": {"faction": "frc", "collector": "frc_builder", "trained": 3, "total": 5},
	"frc7": {"faction": "frc", "collector": "frc_builder", "trained": 5, "total": 7},
}
const GAPS := [3, 9]

var rows: Dictionary = {}

func cases() -> Array[Callable]:
	return [test_openings_deposit, test_steady_is_a_fixed_window, test_report_rows]

func row_for(name: String, gap: int) -> Dictionary:
	var key: String = "%s/%d" % [name, gap]
	if not rows.has(key): rows[key] = run_opening(name, gap)
	return rows[key]

func credits_of(view: Dictionary) -> int:
	return view.players[0].credits

func completed(view: Dictionary, kind: String) -> bool:
	for building in view.buildings:
		if building.kind == kind and building.completed: return true
	return false

func unloading_ids(view: Dictionary) -> Dictionary:
	var units = view.units
	var ids: Dictionary = {}
	for index in range(units.size()):
		if units.phase[index] != units.NONE and units.phases[units.phase[index]] == "unloading": ids[units.id[index]] = true
	return ids

func count_kind(view: Dictionary, kind: String) -> int:
	var units = view.units
	var count: int = 0
	for index in range(units.size()):
		if units.kinds[units.kind[index]] == kind: count += 1
	return count

func pile_boxes(view: Dictionary, source: int) -> int:
	for entry in view.sources:
		if entry.id == source: return entry.boxes
	return -1

func depot_id(view: Dictionary, kind: String) -> int:
	for building in view.buildings:
		if building.kind == kind: return building.id
	return -1

func order(sim, payload: Dictionary) -> void:
	var result: Dictionary = Fixture.send(sim, payload)
	assert(result.ok, "income opening order accepted: " + result.error)

# Depot at (2,10), pile 4x5 at x = 5 + gap, as in test_supply_parity.gd; prerequisites complete before t = 0.
func setup(name: String, gap: int) -> Dictionary:
	var faction: String = OPENINGS[name].faction
	var plant: String = faction + "_power_plant"
	var needs_plant: bool = faction != "frc"
	var sim = Simulation.new([], Vector2i(48, 24))
	sim.add_player(1, START_CREDITS + (Definitions.building(plant).cost if needs_plant else 0))
	var builder: int = sim.spawn(1, Vector2(8.5, 15.5), faction + "_builder")
	if needs_plant:
		order(sim, {"type": "build", "builder_id": builder, "building_kind": plant, "origin": [2, 17]})
		for index in range(3000):
			sim.step()
			if completed(sim.view_state(), plant): break
	return {"sim": sim, "builder": builder, "source": sim.add_supply_source(Vector2i(5 + gap, 9), PILE_BOXES), "depot": faction + "_supply_center"}

# Gross is every credit the pile paid, so orders paid this tick are added back.
func run_opening(name: String, gap: int, model: String = "hold", on_tick: Callable = Callable()) -> Dictionary:
	var opening: Dictionary = OPENINGS[name]
	var world: Dictionary = setup(name, gap)
	var sim = world.sim
	sim.dock_model = model
	var kind: String = opening.collector
	var depot_cost: int = Definitions.building(world.depot).cost
	var spend: int = depot_cost + opening.trained * Definitions.unit(kind).cost
	var previous: int = credits_of(sim.view_state())
	var start_credits: int = previous
	var pending: int = depot_cost
	order(sim, {"type": "build", "builder_id": world.builder, "building_kind": world.depot, "origin": [DEPOT_ORIGIN.x, DEPOT_ORIGIN.y]})
	var gross := PackedInt32Array([0])
	var first_deposit: Dictionary = {}
	var unloading: Dictionary = {}
	var started: bool = false
	var pile_empty: int = -1
	var break_even: int = -1
	var view: Dictionary = {}
	for tick in range(1, END_TICK + 1):
		sim.step()
		view = sim.view_state()
		if on_tick.is_valid(): on_tick.call(tick, view, world.source)
		var credits: int = credits_of(view)
		gross.append(gross[tick - 1] + credits - previous + pending)
		previous = credits
		pending = 0
		if break_even < 0 and gross[tick] >= spend: break_even = tick
		if pile_empty < 0 and pile_boxes(view, world.source) == 0: pile_empty = tick
		var now: Dictionary = unloading_ids(view)
		for id in unloading:
			if not now.has(id) and not first_deposit.has(id): first_deposit[id] = tick
		unloading = now
		if not started and completed(view, world.depot):
			started = true
			for index in range(opening.trained):
				order(sim, {"type": "produce", "building_id": depot_id(view, world.depot), "unit_kind": kind})
			pending = opening.trained * Definitions.unit(kind).cost
			if opening.faction == "frc": order(sim, {"type": "gather", "entity_ids": [world.builder], "source_id": world.source})
	var row: Dictionary = summarize(gross, spend, first_deposit, pile_empty, break_even, count_kind(view, kind))
	row.start_credits = start_credits
	return row

func summarize(gross: PackedInt32Array, spend: int, first_deposit: Dictionary, pile_empty: int, break_even: int, collectors: int) -> Dictionary:
	var end: int = END_TICK if pile_empty < 0 else mini(END_TICK, pile_empty)
	var steady: float = 0.0
	if end > STEADY_FROM_TICK: steady = 1800.0 * (gross[end] - gross[STEADY_FROM_TICK]) / (end - STEADY_FROM_TICK)
	return {"gross": gross, "spend": spend, "depositors": first_deposit.size(), "collectors": collectors, "pile_empty": pile_empty, "break_even": break_even, "steady": steady, "start_credits": 0}

func report_line(name: String, gap: int, row: Dictionary, model: String = "") -> String:
	var gross: Array = []
	var net: Array = []
	for second in SECONDS:
		gross.append(str(row.gross[second * TICKS_PER_SECOND]))
		net.append(str(row.gross[second * TICKS_PER_SECOND] - row.spend))
	var suffix: String = "" if model.is_empty() else " model=" + model
	return "INCOME %s gap=%d gross=%s net=%s steady=%.1f break_even=%s depositors=%d pile_empty=%s%s" % [name, gap, ",".join(gross), ",".join(net), row.steady, seconds_text(row.break_even), row.depositors, seconds_text(row.pile_empty), suffix]

func seconds_text(tick: int) -> String:
	return "-" if tick < 0 else "%.1f" % [tick / float(TICKS_PER_SECOND)]

func test_openings_deposit(runner) -> bool:
	for name in OPENINGS:
		var row: Dictionary = row_for(name, 3)
		runner.check(row.start_credits == START_CREDITS, "%s starts the depot order with %d credits, got %d" % [name, START_CREDITS, row.start_credits])
		runner.check(row.collectors == OPENINGS[name].total, "%s has %d collectors, got %d" % [name, OPENINGS[name].total, row.collectors])
		runner.check(row.depositors == OPENINGS[name].total, "%s: every collector deposits at least once, got %d" % [name, row.depositors])
	return true

func gross_by(per_tick: Callable) -> PackedInt32Array:
	var gross := PackedInt32Array([0])
	for tick in range(1, END_TICK + 1): gross.append(gross[tick - 1] + per_tick.call(tick))
	return gross

func test_steady_is_a_fixed_window(runner) -> bool:
	var first: Dictionary = {1: 100, 2: 7000}
	var row: Dictionary = summarize(gross_by(func(tick: int) -> int: return 1 if tick <= STEADY_FROM_TICK else 2), 0, first, -1, -1, 2)
	runner.check(is_equal_approx(row.steady, 2.0 * 1800.0), "steady is credits per minute from 300 s to 600 s, got %f" % row.steady)
	var sparse := gross_by(func(tick: int) -> int: return 75 if tick % 1000 == 0 else 0)
	row = summarize(sparse, 0, first, -1, -1, 2)
	runner.check(is_equal_approx(row.steady, 1800.0 * (sparse[END_TICK] - sparse[STEADY_FROM_TICK]) / (END_TICK - STEADY_FROM_TICK)), "steady ends at 600 s, not at the last deposit, got %f" % row.steady)
	row = summarize(gross_by(func(tick: int) -> int: return 2 if tick <= 12000 else 10), 0, first, 12000, -1, 2)
	runner.check(is_equal_approx(row.steady, 2.0 * 1800.0), "an empty pile ends the window, got %f" % row.steady)
	return true

# Report only: the rows are evidence for docs/reference/faction-income-parity.md, not gated.
func test_report_rows(runner) -> bool:
	for gap in GAPS:
		for name in OPENINGS:
			var row: Dictionary = row_for(name, gap)
			print(report_line(name, gap, row))
			runner.check(row.steady > 0.0 and row.gross[END_TICK] > row.spend, "%s gap %d earns more than it spent" % [name, gap])
	return true

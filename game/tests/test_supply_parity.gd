@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/economy_fixture.gd")
const Collection = preload("res://scripts/simulation/supply_collection.gd")

# Zero Hour credits/min by gap in cells between depot and pile (centre to centre = gap + 3.5): POOLED values of
# 3 runs each in docs/reference/m7-supply-parity-measured.md.
const TARGETS := {
	"usa_collector": {3: 1646.0, 9: 1468.0, 27: 1181.0},
	"china_collector": {3: 1294.0, 9: 829.0, 27: 407.0},
	"frc_builder": {3: 434.0, 9: 201.0},
}
const DEPOT_OF := {"usa_collector": "usa_supply_center", "china_collector": "china_supply_center", "frc_builder": "frc_supply_center"}
# kind, gap, collector count, pooled Zero Hour credits/min.
const MULTI := [
	["usa_collector", 9, 2, 2770.0],
	["frc_builder", 3, 2, 855.0],
	["frc_builder", 3, 4, 1590.0],
	["china_collector", 9, 2, 1668.0],
	["china_collector", 9, 4, 2814.0],
]
const FOUR_HELICOPTERS_GAP_9 := 3116.0
const TOLERANCE := 0.05
const STEADY_FROM_SECONDS := 300
const STEADY_TO_SECONDS := 600
const SHORT_SECONDS := 450

func cases() -> Array[Callable]:
	return [test_collector_rates_match_zero_hour,test_multi_collector_rates,test_four_helicopters_reported,test_gap_one_arrival_points_apart]

# Depot 3x3 at (2,10), pile 4x5 east of it, both centred on y 11.5.
func layout(kind: String, gap: int, count: int = 1, model := "hold") -> Dictionary:
	var sim = Fixture.make_world(10000,Vector2i(48,24))
	sim.dock_model = model
	var depot: int = Fixture.add_completed(sim,1,DEPOT_OF[kind],Vector2i(2,10))
	var source: int = sim.add_supply_source(Vector2i(5 + gap,9),400)
	var ids: Array = []
	for index in range(count): ids.append(sim.spawn(1,Vector2(5.5,10.5 + index),kind))
	Fixture.send(sim,{"type":"gather","entity_ids":ids,"source_id":source})
	return {"sim":sim,"depot":depot,"source":source,"ids":ids}

# Credits per minute between the first and the last of `deposits` deposits.
func rate(sim, deposits: int, maximum: int = 60000) -> float:
	var last: int = sim._players[1].credits
	var count: int = 0
	var first_tick: int = 0
	var first_credits: int = 0
	for index in range(maximum):
		sim.step()
		var credits: int = sim._players[1].credits
		if credits == last: continue
		last = credits
		count += 1
		if count == 1:
			first_tick = sim._tick
			first_credits = credits
		elif count == deposits:
			return 1800.0 * (credits - first_credits) / (sim._tick - first_tick)
	return -1.0

# Credits per minute 300-600 s after the gather order, ending early when the pile is empty; short when that ends before 450 s.
func steady_rate(sim, gather_tick: int) -> Dictionary:
	var from_tick: int = gather_tick + STEADY_FROM_SECONDS * 30
	var to_tick: int = gather_tick + STEADY_TO_SECONDS * 30
	var from_credits: int = 0
	var end_tick: int = to_tick
	var end_credits: int = 0
	var empty_tick: int = -1
	for index in range(to_tick - sim.view_state().tick + 1):
		sim.step()
		var view: Dictionary = sim.view_state()
		var tick: int = view.tick
		var credits: int = view.players[0].credits
		if tick == from_tick: from_credits = credits
		if pile_is_empty(view):
			empty_tick = tick
			end_tick = tick
			end_credits = credits
			break
		if tick == to_tick:
			end_credits = credits
			break
	var per_min: float = 0.0 if end_tick <= from_tick else 1800.0 * (end_credits - from_credits) / (end_tick - from_tick)
	return {"per_min": per_min, "pile_empty_s": -1.0 if empty_tick < 0 else (empty_tick - gather_tick) / 30.0, "short": end_tick - gather_tick < SHORT_SECONDS * 30}

func pile_is_empty(view: Dictionary) -> bool:
	for source in view.sources:
		if source.boxes > 0: return false
	return true

func within(value: float, expected: float) -> bool:
	return absf(value - expected) <= TOLERANCE * expected

func test_collector_rates_match_zero_hour(runner) -> bool:
	for kind in TARGETS:
		for gap in TARGETS[kind]:
			var world: Dictionary = layout(kind,gap)
			var measured: float = rate(world.sim,9)
			runner.check(within(measured,TARGETS[kind][gap]),"Ep1-Ep3 %s gap %d within 5%% of Zero Hour %.0f/min, got %.1f" % [kind,gap,TARGETS[kind][gap],measured])
	return true

func test_multi_collector_rates(runner) -> bool:
	for row in MULTI:
		var measured: float = rate(layout(row[0],row[1],row[2]).sim,1 + 8 * row[2])
		runner.check(within(measured,row[3]),"Ep4/Ep6/Ep7 %d x %s gap %d within 5%% of %.0f/min, got %.1f" % [row[2],row[0],row[1],row[3],measured])
	return true

# Not gated: Zero Hour's 2.12x for four helicopter collectors contradicts its 1.89x for two (docs/reference/m7-economy-rework-plan.md, R2.1).
func test_four_helicopters_reported(runner) -> bool:
	var measured: float = rate(layout("usa_collector",9,4).sim,33)
	print("Ep4b four helicopter collectors gap 9: %.1f/min (reported, not gated, ZH %.0f)" % [measured,FOUR_HELICOPTERS_GAP_9])
	runner.check(measured > 0.0,"Ep4b four helicopter collectors gap 9 deposit")
	return true

func test_gap_one_arrival_points_apart(runner) -> bool:
	var world: Dictionary = layout("frc_builder",1)
	var sim = world.sim
	var points: Dictionary = {}
	for index in range(3000):
		sim.step()
		var unit: Dictionary = sim._entities[world.ids[0]]
		var phase: String = unit.collection.phase
		if phase in ["loading","unloading"] and not points.has(phase): points[phase] = Collection._arrival(unit,sim._sources.get(world.source) if phase == "loading" else sim._buildings[world.depot])
	runner.check(points.size() == 2 and Vector2(points.loading[0],points.loading[1]).distance_to(Vector2(points.unloading[0],points.unloading[1])) > 0.49,"Ep5 gap 1 laborer pile and depot arrival points are 0.5 cell apart, got %s" % [points])
	return true

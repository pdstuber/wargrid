@warning_ignore_start("untyped_declaration")
extends RefCounted

const Parity = preload("res://tests/test_supply_parity.gd")

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

func cases() -> Array[Callable]:
	return [test_lone_cycles_pinned]

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
	for kind in ["usa_collector", "china_collector", "frc_builder"]:
		for gap in [3, 9]:
			var ticks: Array = deposit_ticks(kind, gap, 9)
			runner.check(LONE_DEPOSITS.get(kind, {}).get(gap, []) == ticks, "DL0 a lone %s at gap %d deposits on the same ticks as before c1, got %s" % [kind, gap, ticks])
	return true

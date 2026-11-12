@warning_ignore_start("untyped_declaration")
extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Parity = preload("res://tests/test_supply_parity.gd")
const Openings = preload("res://tests/test_income_openings.gd")

const MODELS := ["hold"]
const GATHER_TICK := 0

func cases() -> Array[Callable]:
	return [test_default_model_is_hold, test_steady_rate_window, test_report_rows]

func models() -> Array:
	var wanted: String = OS.get_environment("WARGRID_DOCK_MODELS")
	if wanted.is_empty(): return MODELS
	var picked: Array = []
	for name in wanted.split(","):
		if name in MODELS: picked.append(name)
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
	for model in models():
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

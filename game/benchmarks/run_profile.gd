extends SceneTree

const Profiler = preload("res://scripts/debug/profiler.gd")
const MovementWorkload = preload("res://scripts/debug/movement_workload.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const ScriptedHuman = preload("res://scripts/simulation/scripted_human.gd")
const View = preload("res://scripts/presentation/world_view.gd")

const WARMUP: int = 300
const SAMPLES: int = 1800
const MATCH_LIMIT: int = 12000
const TOP_SLOW: int = 10
var _view: Node2D
var _no_selection: Array[int] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("PROFILE HEADLESS engine=", Engine.get_version_info().string, " os=", OS.get_name(), " cpu=", OS.get_processor_name(),
		" warmup_ticks=", WARMUP, " sample_ticks=", SAMPLES, " unpaced=true zones=inclusive")
	_view = View.new()
	var done: int = 0
	for layout: String in ["open", "dense"]:
		_movement(layout)
		done += 1
	for layout: String in ["contact", "skirmish3v3", "open"]:
		_fixed("combat_" + layout, CombatWorkload.create(layout), 1)
		done += 1
	_skirmish()
	done += 1
	_large()
	done += 1
	_view.free()
	print("PROFILE COMPLETE ", done)
	quit(0)

# Mirrors one rendered tick: the scene snapshots (base scenes twice), then the view copies and sorts.
func _frame(sim: RefCounted, snapshots: int) -> void:
	var state: Dictionary = {}
	for i in range(snapshots): state = sim.snapshot()
	_view.set_state(state, _no_selection)
	Profiler.end_tick()

func _harness(workload: Callable) -> Variant:
	Profiler.enabled = false
	var result: Variant = workload.call()
	Profiler.enabled = true
	return result

func _phase(label: String, warmup: bool) -> void:
	for line in Profiler.report(label + (".warmup" if warmup else "")): print(line)
	var slow: Array = Array(Profiler.slow)
	slow.sort_custom(func(a: String, b: String) -> bool: return a.get_slice(" ", 2).to_float() > b.get_slice(" ", 2).to_float())
	for line: Variant in slow.slice(0, TOP_SLOW): print("PROFILE_SLOW ", label, " ", line)
	print("PROFILE_SLOW_COUNT ", label, " ", slow.size())
	Profiler.reset()

func _movement(layout: String) -> void:
	var sim: RefCounted = MovementWorkload.create(layout)
	Profiler.reset()
	Profiler.enabled = true
	var leg: int = 0
	for tick in range(WARMUP + SAMPLES):
		if tick == WARMUP: _phase("movement_" + layout, true)
		if tick == 0 or _harness(func() -> bool: return MovementWorkload.settled(sim)):
			_harness(func() -> void: MovementWorkload.issue_leg(sim, leg))
			leg += 1
		sim.step()
		_frame(sim, 1)
	_phase("movement_" + layout, false)
	Profiler.enabled = false
	print("PROFILE_END movement_", layout, " legs=", leg)

func _fixed(label: String, sim: RefCounted, snapshots: int, edits: Dictionary = {}) -> void:
	Profiler.reset()
	Profiler.enabled = true
	var start_units: int = sim.snapshot().entities.size()
	for tick in range(WARMUP + SAMPLES):
		if tick == WARMUP: _phase(label, true)
		if edits.has(tick): edits[tick].call()
		sim.step()
		_frame(sim, snapshots)
	_phase(label, false)
	Profiler.enabled = false
	print("PROFILE_END ", label, " units_start=", start_units, " units_end=", sim.snapshot().entities.size())

func _skirmish() -> void:
	var sim: RefCounted = Skirmish.create()
	Profiler.reset()
	Profiler.enabled = true
	var peak: int = 0
	while not sim.match_over() and sim.tick() < MATCH_LIMIT:
		if sim.tick() == WARMUP: _phase("skirmish_match", true)
		_harness(func() -> void: ScriptedHuman.issue(sim))
		Skirmish.issue_opponent(sim)
		sim.step()
		_frame(sim, 2)
		peak = maxi(peak, _harness(func() -> int: return sim.snapshot().entities.size()))
	_phase("skirmish_match", false)
	Profiler.enabled = false
	print("PROFILE_END skirmish_match ticks=", sim.tick(), " over=", sim.match_over(), " peak_entities=", peak)

func _large() -> void:
	var sim: RefCounted = CombatWorkload.create_large()
	var started: int = Time.get_ticks_usec()
	var route: Array[Vector2] = sim._navigation.route(Vector2(5.5, 98.5), Vector2(190.5, 98.5))
	print("PROFILE_ROUTE large start_to_start_ms=", (Time.get_ticks_usec() - started) / 1000.0, " points=", route.size())
	var obstacle: Array[Vector2i] = []
	for y in range(60, 68):
		for x in range(98, 106): obstacle.append(Vector2i(x, y))
	# Same path as a building placement or death: one full navigation rebuild plus requeue of every mover.
	var add := func() -> void:
		var cells: Array[Vector2i] = sim._union_cells()
		cells.append_array(obstacle)
		sim._replace_union(cells)
	var remove := func() -> void: sim._replace_union(sim._union_cells())
	_fixed("large_196", sim, 1, {600: add, 1200: remove})

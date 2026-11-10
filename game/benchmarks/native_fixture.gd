extends SceneTree

# Headless driver for the native spike: one workload in one bridge mode, DIGEST lines, the bridge report, optional fixture.
# godot --headless --path game --script res://benchmarks/native_fixture.gd -- only=hordes300 native=shadow slices=horde,move ticks=600 record=/abs/file.bin

const NativeBridge = preload("res://scripts/native/native_bridge.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const MovementWorkload = preload("res://scripts/debug/movement_workload.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const WORKLOADS: Array[String] = ["small", "hordes300", "move_open", "move_dense"]
const DEFAULTS: Dictionary = {"only": "small", "native": "off", "slices": "", "timing": "0", "record": "", "ticks": "600"}
const DIGEST_EVERY: int = 300
const CLASSES: Array[StringName] = [&"WargridHorde", &"WargridMovement", &"WargridProbe"]

func _initialize() -> void:
	quit(1) # stays the exit code if a script error aborts the run below
	quit(_run(OS.get_cmdline_user_args()))

func _run(args: PackedStringArray) -> int:
	var options: Dictionary = parse(args)
	if options.has("error"): return _fail(options.error)
	var workload: String = options.only
	var sim: Simulation = create(workload)
	var slices: Array = Array(options.slices.split(",", false))
	var configured: Dictionary = NativeBridge.configure(options.native, slices, options.timing in ["1", "on"], options.record)
	print("EXTENSION ", _extension())
	if not configured.ok: return _fail(configured.error)
	var leg: int = -1
	var ticks: int = int(options.ticks)
	for tick in range(ticks):
		leg = drive(sim, workload, tick, leg)
		var start: int = Time.get_ticks_usec()
		sim.step()
		NativeBridge.record_tick(Time.get_ticks_usec() - start)
		if (tick + 1) % DIGEST_EVERY == 0 or tick + 1 == ticks: print("DIGEST %s tick=%d %s" % [workload, sim.tick(), StateHash.digest(sim.snapshot())])
	for line in NativeBridge.slice_lines(workload): print(line)
	NativeBridge.configure("off")
	print("FIXTURE DONE %s mode=%s ticks=%d" % [workload, options.native, ticks])
	return 0

func _fail(text: String) -> int:
	NativeBridge.configure("off")
	print("FIXTURE FAILED ", text)
	return 1

func _extension() -> String:
	var found: Array[String] = []
	for class_id: StringName in CLASSES:
		if ClassDB.class_exists(class_id): found.append(String(class_id))
	var probe: String = ClassDB.instantiate(&"WargridProbe").version() if ClassDB.class_exists(&"WargridProbe") else "none"
	return "classes=%s probe=%s" % [",".join(found) if not found.is_empty() else "none", probe]

static func parse(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = DEFAULTS.duplicate()
	for arg in args:
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2 or not options.has(parts[0]): return {"error": "unknown option %s" % arg}
		options[parts[0]] = parts[1]
	if not WORKLOADS.has(options.only): return {"error": "unknown workload %s" % options.only}
	if not options.ticks.is_valid_int() or int(options.ticks) < 1: return {"error": "bad ticks %s" % options.ticks}
	return options

static func create(workload: String) -> Simulation:
	if workload == "hordes300": return CombatWorkload.create("hordes300")
	if workload.begins_with("move_"): return MovementWorkload.create(workload.trim_prefix("move_"))
	return _small()

# Six militia (the middle ones reach a horde, the corners only touch it) and two enemy riflemen far away.
static func _small() -> Simulation:
	var sim := Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	for spot: Vector2 in [Vector2(4.5, 4.5), Vector2(5.5, 4.5), Vector2(6.5, 4.5), Vector2(4.5, 5.5), Vector2(5.5, 5.5), Vector2(6.5, 5.5)]:
		sim.spawn(1, spot, "china_rifle_infantry")
	sim.spawn(2, Vector2(24.5, 24.5), "usa_rifle_infantry")
	sim.spawn(2, Vector2(25.5, 24.5), "usa_rifle_infantry")
	return sim

## Commands for the tick about to run; returns the movement leg counter.
static func drive(sim: Simulation, workload: String, tick: int, leg: int) -> int:
	if workload == "small":
		if tick == 0:
			_move(sim, 1, 0, [1, 2, 3], [12.5, 4.5])
			_move(sim, 2, 0, [7, 8], [20.5, 24.5])
		elif tick == 45:
			_move(sim, 1, 1, [4, 5, 6], [12.5, 6.5])
	elif workload.begins_with("move_") and (leg == -1 or MovementWorkload.settled(sim)):
		leg += 1
		MovementWorkload.issue_leg(sim, leg)
	return leg

static func _move(sim: Simulation, player: int, sequence: int, ids: Array, target: Array) -> void:
	var result: Dictionary = sim.issue_command({"tick": sim.tick(), "player": player, "sequence": sequence, "type": "move", "entity_ids": ids, "target": target})
	assert(result.ok, result.error)

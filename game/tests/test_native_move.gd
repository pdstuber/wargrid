@warning_ignore_start("untyped_declaration")
extends RefCounted

const NativeBridge = preload("res://scripts/native/native_bridge.gd")
const Fixture = preload("res://benchmarks/native_fixture.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")

func cases() -> Array[Callable]:
	return [test_bridge_off_by_default, test_native_mode_needs_extension, test_timed_off_keeps_digests, test_native]

func test_bridge_off_by_default(runner) -> bool:
	runner.check(NativeBridge.mode() == "off", "bridge starts in mode off")
	return true

func test_native_mode_needs_extension(runner) -> bool:
	var result: Dictionary = NativeBridge.configure("native", ["move"])
	if not ClassDB.class_exists(&"WargridMovement"):
		runner.check(not result.ok and result.error.contains("WargridMovement"), "a missing extension is reported")
		runner.check(NativeBridge.mode() == "off", "a missing extension leaves the bridge off")
	else:
		runner.check(result.ok, "native mode starts when the extension is loaded")
	runner.check(not NativeBridge.configure("fast", ["move"]).ok, "an unknown mode is rejected")
	runner.check(not NativeBridge.configure("off", ["avoid"], true).ok, "an unknown slice is rejected")
	NativeBridge.configure("off")
	runner.check(NativeBridge.mode() == "off", "configure off resets the bridge")
	return true

func digests(ticks: int) -> PackedStringArray:
	var sim = Fixture.create("small")
	var out := PackedStringArray()
	for tick in range(ticks):
		Fixture.drive(sim, "small", tick, -1)
		sim.step()
		out.append(StateHash.digest(sim.snapshot()))
	return out

# The timed GDScript path must be the same game as the plain one, tick by tick.
func test_timed_off_keeps_digests(runner) -> bool:
	var plain: PackedStringArray = digests(90)
	runner.check(NativeBridge.configure("off", ["horde", "move"], true).ok, "timed off needs no extension")
	var timed: PackedStringArray = digests(90)
	var report: Dictionary = NativeBridge.report()
	NativeBridge.configure("off")
	runner.check(plain == timed, "timed off keeps every tick's digest")
	runner.check(report.slices.move.calls == 90 and report.slices.horde.calls == 90, "both slices ran through the hook each tick")
	runner.check(report.slices.move.gd > 0, "the movement slice was timed")
	return true

func test_native(runner) -> bool:
	if not ClassDB.class_exists(&"WargridMovement"):
		runner.check(OS.get_environment("WARGRID_NATIVE_REQUIRED") != "1", "WargridMovement is loaded when WARGRID_NATIVE_REQUIRED=1")
		return true
	var ran: int = 0
	var core: Object = ClassDB.instantiate(&"WargridMovement")
	runner.check(core.run([]).is_empty() and core.last_error().contains("not implemented"), "movement stub answers not implemented")
	ran += 1
	print("NATIVE CASES RAN ", ran)
	return true

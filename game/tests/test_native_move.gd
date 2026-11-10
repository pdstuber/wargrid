@warning_ignore_start("untyped_declaration")
extends RefCounted

const NativeBridge = preload("res://scripts/native/native_bridge.gd")
const Fixture = preload("res://benchmarks/native_fixture.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const LAYOUTS: Array[String] = ["small", "air", "wheels", "enter", "stop"]

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

# Small scenarios for the boundary cases: air (heading snaps), wheels from standstill (below turn speed) next to treads, infantry entering a vehicle,
# and a stop at full speed (the non-moving branch that zeroes speed).
func make(layout: String) -> Object:
	if layout == "small" or layout == "move_open": return Fixture.create(layout)
	var sim := Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 0)
	if layout == "air":
		sim.spawn(1, Vector2(4.5, 4.5), "usa_collector")
	elif layout == "wheels":
		sim.spawn(1, Vector2(12.5, 10.5), "usa_light_vehicle")
		sim.spawn(1, Vector2(12.5, 14.5), "frc_light_vehicle")
		sim.spawn(1, Vector2(12.5, 18.5), "china_tank")
	elif layout == "stop":
		sim.spawn(1, Vector2(4.5, 4.5), "usa_tank")
	elif layout == "enter":
		sim.spawn(1, Vector2(8.5, 6.5), "usa_light_vehicle")
		sim.spawn(1, Vector2(4.5, 4.5), "usa_rifle_infantry")
		sim.spawn(1, Vector2(5.5, 4.5), "usa_rifle_infantry")
	return sim

func drive(sim, layout: String, tick: int, leg: int) -> int:
	if layout == "small" or layout == "move_open": return Fixture.drive(sim, layout, tick, leg)
	if layout == "air" and tick in [0, 80]:
		command(sim, 0 if tick == 0 else 1, {"type": "move", "entity_ids": [1], "target": [16.5, 4.5] if tick == 0 else [16.5, 20.5]})
	elif layout == "wheels" and tick == 0:
		command(sim, 0, {"type": "move", "entity_ids": [1, 2, 3], "target": [3.5, 14.5]})
	elif layout == "stop" and tick in [0, 60]:
		command(sim, 0 if tick == 0 else 1, {"type": "move", "entity_ids": [1], "target": [28.5, 4.5]} if tick == 0 else {"type": "stop", "entity_ids": [1]})
	elif layout == "enter" and tick == 0:
		command(sim, 0, {"type": "enter", "entity_ids": [2, 3], "target_id": 1})
	return leg

func command(sim, sequence: int, fields: Dictionary) -> void:
	var order: Dictionary = {"tick": sim.tick(), "player": 1, "sequence": sequence}
	order.merge(fields)
	var result: Dictionary = sim.issue_command(order)
	assert(result.ok, result.error)

# Digest after every tick of a layout in one bridge mode, and the last snapshot.
func play(layout: String, mode: String, ticks: int) -> Dictionary:
	var sim = make(layout)
	var configured: Dictionary = NativeBridge.configure(mode, ["move"]) if mode != "off" else {"ok": true, "error": ""}
	var out := PackedStringArray()
	var leg: int = -1
	if configured.ok:
		for tick in range(ticks):
			leg = drive(sim, layout, tick, leg)
			sim.step()
			out.append(StateHash.digest(sim.snapshot()))
	var report: Dictionary = NativeBridge.report()
	NativeBridge.configure("off")
	return {"ok": configured.ok, "error": configured.error, "digests": out, "report": report, "last": sim.snapshot()}

func same_digests(runner, layout: String, mode: String, ticks: int, every: int) -> Dictionary:
	var base: Dictionary = play(layout, "off", ticks)
	var other: Dictionary = play(layout, mode, ticks)
	var wrong: int = 0
	for tick in range(every - 1, ticks, every):
		if base.digests[tick] != other.digests[tick]: wrong += 1
	var line: Dictionary = other.report.slices.get("move", {"error": "no move slice"})
	runner.check(other.ok and wrong == 0 and base.digests[ticks - 1] == other.digests[ticks - 1] and line.error.is_empty(), "%s %s: digests equal off every %d ticks (%s %s)" % [layout, mode, every, other.error, line.error])
	return base

func shadow_clean(runner, layout: String, ticks: int) -> Dictionary:
	var run: Dictionary = play(layout, "shadow", ticks)
	var line: Dictionary = run.report.slices.get("move", {"mismatch": "no move slice", "error": "", "calls": 0, "entities": 0})
	runner.check(line.mismatch.is_empty() and line.error.is_empty() and line.calls == ticks and line.entities > 0, "%s shadow: no mismatch in %d ticks (%s%s)" % [layout, ticks, line.mismatch, line.error])
	return run

func entity(state: Dictionary, id: int) -> Dictionary:
	for unit: Dictionary in state.entities:
		if unit.id == id: return unit
	return {}

# Native cases run only with the extension; WARGRID_NATIVE_REQUIRED=1 turns its absence into a failure.
func test_native(runner) -> bool:
	if not ClassDB.class_exists(&"WargridMovement"):
		runner.check(OS.get_environment("WARGRID_NATIVE_REQUIRED") != "1", "WargridMovement is loaded when WARGRID_NATIVE_REQUIRED=1")
		return true
	var ran: int = 0
	shadow_clean(runner, "move_open", 600)
	ran += 1
	same_digests(runner, "move_open", "native", 600, 30)
	ran += 1
	same_digests(runner, "move_open", "pass", 600, 30)
	ran += 1
	var finals: Dictionary = {}
	for layout: String in LAYOUTS:
		shadow_clean(runner, layout, 240)
		finals[layout] = same_digests(runner, layout, "native", 240, 1).last
		same_digests(runner, layout, "pass", 240, 1)
		ran += 1
	var heli: Dictionary = entity(finals.air, 1)
	runner.check(heli.heading == [0.0, 1.0] and heli.status == "arrived", "the air unit snapped its heading to the second leg and arrived")
	runner.check(entity(finals.wheels, 1).status == "arrived" and entity(finals.wheels, 2).status == "arrived" and entity(finals.wheels, 3).heading == [-1.0, 0.0], "wheels arrived and treads turned round")
	runner.check(entity(finals.stop, 1).status == "idle" and entity(finals.stop, 1).speed == 0.0 and entity(finals.stop, 1).position[0] > 5.0, "a unit stopped while moving keeps no speed")
	runner.check(entity(finals.enter, 2).has("container_id") and entity(finals.enter, 3).has("container_id"), "infantry entered the vehicle on arrival")
	ran += 1
	var core: Object = ClassDB.instantiate(&"WargridMovement")
	runner.check(core.run([]).is_empty() and core.last_error().contains("expected 14 inputs"), "a malformed call is refused with a reason")
	runner.check(core.run_pass([]).is_empty(), "the pass-through refuses the same input")
	ran += 1
	print("NATIVE CASES RAN ", ran)
	return true

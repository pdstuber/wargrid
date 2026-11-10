@warning_ignore_start("untyped_declaration")
extends RefCounted

const NativeBridge = preload("res://scripts/native/native_bridge.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const Fixture = preload("res://benchmarks/native_fixture.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

# Same bytes as native/core/src/fixture.rs SAMPLE, so the GDScript writer and the Rust reader agree on the format.
const FIXTURE_SAMPLE := "574746580100000005686f72646507000000000000000200000002010000000700000005020000000000000000000080000000000000f83f01000000010100000001"

func cases() -> Array[Callable]:
	return [test_bridge_off_by_default, test_shadow_needs_extension, test_fixture_bytes, test_timed_off_horde, test_native]

func test_bridge_off_by_default(runner) -> bool:
	runner.check(NativeBridge.mode() == "off", "bridge starts in mode off")
	runner.check(NativeBridge.report().slices.is_empty(), "no slice is selected by default")
	return true

func test_shadow_needs_extension(runner) -> bool:
	var result: Dictionary = NativeBridge.configure("shadow", ["horde"])
	if ClassDB.class_exists(&"WargridHorde"):
		runner.check(result.ok and NativeBridge.mode() == "shadow", "shadow starts when the extension is loaded")
	else:
		runner.check(not result.ok and result.error.contains("WargridHorde"), "a missing extension is reported")
		runner.check(NativeBridge.mode() == "off", "a missing extension leaves the bridge off")
	NativeBridge.configure("off")
	runner.check(NativeBridge.mode() == "off", "configure off resets the bridge")
	return true

func test_fixture_bytes(runner) -> bool:
	var path := "user://native-fixture-%d.bin" % OS.get_process_id()
	var file: FileAccess = NativeBridge.open_fixture(path)
	NativeBridge.write_record(file, "horde", 7, [PackedInt32Array([7]), PackedFloat64Array([-0.0, 1.5])], [PackedByteArray([1])])
	file.close()
	runner.check(FileAccess.get_file_as_bytes(path).hex_encode() == FIXTURE_SAMPLE, "fixture bytes follow the boundary note")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return true

func make(layout: String) -> Object:
	if layout == "small" or layout == "hordes300": return Fixture.create(layout)
	var sim := Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 0, "human", 1)
	sim.add_player(2, 0, "human", 2)
	sim.add_player(3, 0, "human", 1)
	if layout == "allies":
		for spot: Vector2 in [Vector2(4.5, 4.5), Vector2(5.5, 4.5), Vector2(6.5, 4.5), Vector2(4.5, 5.5), Vector2(5.5, 5.5), Vector2(6.5, 5.5)]:
			sim.spawn(3 if int(spot.x) % 2 == 0 else 1, spot, "china_rifle_infantry")
	elif layout == "hostile":
		for spot: Vector2 in [Vector2(4.5, 4.5), Vector2(5.5, 4.5), Vector2(6.5, 4.5), Vector2(4.5, 5.5), Vector2(5.5, 5.5), Vector2(6.5, 5.5)]:
			sim.spawn(1 if spot.x < 5.0 else 2, spot, "china_rifle_infantry")
	elif layout == "alone":
		sim.spawn(1, Vector2(4.5, 4.5), "china_rifle_infantry")
		sim.spawn(1, Vector2(5.0, 4.5), "china_rifle_infantry")
		sim.spawn(2, Vector2(4.8, 4.5), "china_rifle_infantry")
	elif layout == "tanks":
		for column in range(6):
			sim.spawn(1, Vector2(4.5 + column * 1.3, 4.5), "china_light_vehicle" if column % 2 == 0 else "china_rocket_infantry")
	return sim

# Digest after every tick of a layout in one bridge mode; also the highest horde level seen and the number of due checks.
func play(layout: String, mode: String, ticks: int) -> Dictionary:
	var sim = make(layout)
	var configured: Dictionary = NativeBridge.configure(mode, ["horde"] if mode != "off" else [])
	var digests := PackedStringArray()
	var peak: int = 0
	var checks: int = 0
	if configured.ok:
		for tick in range(ticks):
			Fixture.drive(sim, layout, tick, -1)
			sim.step()
			checks += sim.horde_checks()
			digests.append(StateHash.digest(sim.snapshot()))
			for unit in sim.snapshot().entities:
				if unit.combat != null: peak = maxi(peak, unit.combat.get("horde", 0))
	var report: Dictionary = NativeBridge.report()
	NativeBridge.configure("off")
	return {"ok": configured.ok, "error": configured.error, "digests": digests, "peak": peak, "checks": checks, "report": report}

func test_timed_off_horde(runner) -> bool:
	var plain: Dictionary = play("small", "off", 90)
	var sim = make("small")
	runner.check(NativeBridge.configure("off", ["horde"], true).ok, "timed off needs no extension")
	var timed := PackedStringArray()
	for tick in range(90):
		Fixture.drive(sim, "small", tick, -1)
		sim.step()
		timed.append(StateHash.digest(sim.snapshot()))
	var report: Dictionary = NativeBridge.report()
	NativeBridge.configure("off")
	runner.check(plain.digests == timed, "timed off keeps the horde slice's digests")
	runner.check(report.slices.horde.calls == 90 and plain.peak == 2 and plain.checks > 0, "the horde slice ran and a horde formed")
	return true

func same_digests(runner, layout: String, mode: String, ticks: int, every: int) -> int:
	var base: Dictionary = play(layout, "off", ticks)
	var other: Dictionary = play(layout, mode, ticks)
	var wrong: int = 0
	for tick in range(every - 1, ticks, every):
		if base.digests[tick] != other.digests[tick]: wrong += 1
	runner.check(other.ok and wrong == 0 and base.digests[ticks - 1] == other.digests[ticks - 1], "%s %s: digests equal off every %d ticks (%s)" % [layout, mode, every, other.error])
	return base.peak

func shadow_clean(runner, layout: String, ticks: int) -> void:
	var run: Dictionary = play(layout, "shadow", ticks)
	var line: Dictionary = run.report.slices.get("horde", {"mismatch": "no horde slice", "calls": 0})
	runner.check(line.mismatch.is_empty() and line.calls == ticks, "%s shadow: no mismatch in %d ticks (%s)" % [layout, ticks, line.mismatch])

# Native cases run only with the extension; WARGRID_NATIVE_REQUIRED=1 turns its absence into a failure.
func test_native(runner) -> bool:
	if not ClassDB.class_exists(&"WargridHorde"):
		runner.check(OS.get_environment("WARGRID_NATIVE_REQUIRED") != "1", "WargridHorde is loaded when WARGRID_NATIVE_REQUIRED=1")
		return true
	var ran: int = 0
	shadow_clean(runner, "hordes300", 600)
	ran += 1
	var peak: int = same_digests(runner, "hordes300", "native", 600, 30)
	runner.check(peak == 2, "hordes300 reaches level 2")
	ran += 1
	same_digests(runner, "hordes300", "pass", 600, 30)
	ran += 1
	for layout: String in ["small", "allies", "hostile", "alone", "tanks"]:
		shadow_clean(runner, layout, 150)
		same_digests(runner, layout, "native", 150, 1)
		same_digests(runner, layout, "pass", 150, 1)
		ran += 1
	runner.check(play("allies", "off", 150).peak == 2, "units of allied teams count as neighbours")
	runner.check(play("hostile", "off", 150).peak < 2, "a hostile unit in range is not a neighbour")
	runner.check(play("alone", "off", 150).peak == 0, "fewer neighbours than the rule needs stays level 0")
	ran += 1
	var empty = Simulation.new([], Vector2i(16, 16))
	empty.add_player(1, 0)
	runner.check(NativeBridge.configure("native", ["horde"]).ok, "native starts without members")
	for tick in range(40): empty.step()
	var report: Dictionary = NativeBridge.report()
	NativeBridge.configure("off")
	runner.check(report.slices.horde.error.is_empty() and report.slices.horde.calls == 40, "a sim without members runs clean")
	ran += 1
	var core: Object = ClassDB.instantiate(&"WargridHorde")
	runner.check(core.run([]).is_empty() and core.last_error().contains("expected 12 inputs"), "a malformed call is refused with a reason")
	ran += 1
	print("NATIVE CASES RAN ", ran)
	return true

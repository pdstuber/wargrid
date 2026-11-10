@warning_ignore_start("untyped_declaration")
extends RefCounted

const NativeBridge = preload("res://scripts/native/native_bridge.gd")

# Same bytes as native/core/src/fixture.rs SAMPLE, so the GDScript writer and the Rust reader agree on the format.
const FIXTURE_SAMPLE := "574746580100000005686f72646507000000000000000200000002010000000700000005020000000000000000000080000000000000f83f01000000010100000001"

func cases() -> Array[Callable]:
	return [test_bridge_off_by_default, test_shadow_needs_extension, test_fixture_bytes, test_native]

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

# Native cases run only with the extension; WARGRID_NATIVE_REQUIRED=1 turns its absence into a failure.
func test_native(runner) -> bool:
	if not ClassDB.class_exists(&"WargridHorde"):
		runner.check(OS.get_environment("WARGRID_NATIVE_REQUIRED") != "1", "WargridHorde is loaded when WARGRID_NATIVE_REQUIRED=1")
		return true
	var ran: int = 0
	var core: Object = ClassDB.instantiate(&"WargridHorde")
	runner.check(core.run([]).is_empty() and core.last_error().contains("not implemented"), "horde stub answers not implemented")
	ran += 1
	print("NATIVE CASES RAN ", ran)
	return true

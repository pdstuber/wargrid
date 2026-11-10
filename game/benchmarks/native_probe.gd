extends RefCounted

const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

const REPEATS: int = 300
const ENTITIES: int = 400

static func run(_runner: Object, _with_panic: bool) -> PackedStringArray:
	if not ClassDB.class_exists(&"WargridProbe"): return PackedStringArray(["PROBE echo ok=false error=extension missing"])
	var probe: Object = ClassDB.instantiate(&"WargridProbe")
	var lines := PackedStringArray()
	lines.append("PROBE version %s" % probe.version())
	lines.append(_echo(probe))
	lines.append_array(_snapshot(probe))
	lines.append(_grow(probe))
	return lines

static func _echo(probe: Object) -> String:
	var input := PackedFloat64Array()
	for i: int in 1024: input.append(i * 0.25 - 100.0)
	var output: PackedFloat64Array = probe.echo(input)
	var ok: bool = output.size() == input.size()
	for i: int in mini(input.size(), output.size()):
		if output[i] != input[i] * 2.0 + 1.0: ok = false
	return "PROBE echo ok=%s n=%d" % [ok, output.size()]

static func _snapshot(probe: Object) -> PackedStringArray:
	var sim: Simulation = CombatWorkload.create("hordes300")
	for i: int in 100: sim.step()
	var real: Dictionary = sim.snapshot().entities[0]
	var types := PackedStringArray()
	for key: Variant in real: types.append("%s:%s" % [key, type_string(typeof(real[key]))])
	probe.load_records(ENTITIES)
	var native: Dictionary = probe.snapshot_dicts(1)[0]
	var native_types := PackedStringArray()
	for key: Variant in native: native_types.append("%s:%s" % [key, type_string(typeof(native[key]))])
	var lines := PackedStringArray(["PROBE keys real=%s" % ",".join(types), "PROBE keys match=%s" % (types == native_types)])
	var gd_us: int = 0
	var dicts_us: int = 0
	var packed_us: int = 0
	var sink: int = 0
	for i: int in REPEATS:
		var start: int = Time.get_ticks_usec()
		sink += sim.snapshot().entities.size()
		gd_us += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		sink += probe.snapshot_dicts(ENTITIES).size()
		dicts_us += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		sink += probe.snapshot_packed(ENTITIES).size()
		packed_us += Time.get_ticks_usec() - start
	lines.append("PROBE snapshot gd_ms=%.3f dicts_ms=%.3f packed_ms=%.3f n=%d repeats=%d sink=%d" % [gd_us / 1000.0, dicts_us / 1000.0, packed_us / 1000.0, ENTITIES, REPEATS, sink])
	return lines

# A packed array held across a native allocation that grows WASM memory must still read back intact.
static func _grow(probe: Object) -> String:
	var held := PackedFloat64Array()
	for i: int in 4096: held.append(i * 0.5)
	var before: int = _heap_bytes()
	var checksum: int = probe.grow(256)
	var after: int = _heap_bytes()
	var ok: bool = true
	for i: int in held.size():
		if held[i] != i * 0.5: ok = false
	var fresh := PackedFloat64Array([1.5, 2.5])
	return "PROBE grow held_ok=%s fresh_ok=%s checksum=%d heap_before=%d heap_after=%d" % [ok, fresh[1] == 2.5, checksum, before, after]

static func _heap_bytes() -> int:
	if not OS.has_feature("web"): return -1
	return int(JavaScriptBridge.eval("(typeof HEAPU8!=='undefined'?HEAPU8.length:(Module&&Module.HEAPU8?Module.HEAPU8.length:-1))"))

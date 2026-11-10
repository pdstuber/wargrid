extends RefCounted

# Spike-only switch between the GDScript slices and their Rust ports (docs/reference/native-sim-spike-boundary.md).
# Only benchmarks, the fixture driver and tests call configure; the default leaves Simulation.native null.

const Simulation = preload("res://scripts/simulation/simulation.gd")
const MODES: Array[String] = ["off", "shadow", "native", "pass"]
const SLICES: Dictionary = {
	"horde": {"script": "res://scripts/simulation/native_horde.gd", "native_class": &"WargridHorde"},
	"move": {"script": "res://scripts/simulation/native_move.gd", "native_class": &"WargridMovement"},
}
const TAGS: Dictionary = {TYPE_PACKED_BYTE_ARRAY: 1, TYPE_PACKED_INT32_ARRAY: 2, TYPE_PACKED_INT64_ARRAY: 3, TYPE_PACKED_FLOAT32_ARRAY: 4, TYPE_PACKED_FLOAT64_ARRAY: 5}
const WIDTHS: Dictionary = {1: 1, 2: 4, 3: 8, 4: 4, 5: 8}
const FIXTURE_VERSION: int = 1

static var _mode: String = "off"
static var _parts: Dictionary = {}
static var _stats: Dictionary = {}
static var _ticks: int = 0
static var _tick_sum: int = 0
static var _file: FileAccess = null

static func mode() -> String:
	return _mode

## Selects mode and slices; on any error the bridge stays off and says why. `timing` only matters for mode off.
static func configure(mode_name: String, slices: Array = [], timing: bool = false, record: String = "") -> Dictionary:
	_stop()
	if mode_name == "off" and not timing: return {"ok": true, "error": ""}
	var error: String = _check(mode_name, slices, record)
	var parts: Dictionary = {}
	for slice_name: String in slices:
		if not error.is_empty(): break
		var part: Dictionary = _load_part(slice_name, mode_name != "off")
		error = part.get("error", "")
		parts[slice_name] = part
	if error.is_empty() and not record.is_empty():
		_file = open_fixture(record)
		if _file == null: error = "cannot write fixture %s" % record
	if not error.is_empty():
		_stop()
		return {"ok": false, "error": error}
	_mode = mode_name
	_parts = parts
	for slice_name: String in parts: _stats[slice_name] = _empty_stats()
	Simulation.native = new()
	return {"ok": true, "error": ""}

static func _check(mode_name: String, slices: Array, record: String) -> String:
	if not MODES.has(mode_name): return "unknown mode %s" % mode_name
	if slices.is_empty(): return "no slice selected"
	for slice_name: Variant in slices:
		if not SLICES.has(slice_name): return "unknown slice %s" % slice_name
	if not record.is_empty() and mode_name != "shadow": return "record needs mode shadow"
	return ""

# Loaded by name only when selected, so a broken slice file or a missing library cannot touch mode off.
static func _load_part(slice_name: String, needs_extension: bool) -> Dictionary:
	var entry: Dictionary = SLICES[slice_name]
	var slice_script: Script = load(entry.script)
	if slice_script == null or not slice_script.can_instantiate(): return {"error": "slice script %s failed to load" % entry.script}
	var part: Dictionary = {"slice": slice_script.new(), "ext": null}
	if needs_extension:
		if not ClassDB.class_exists(entry.native_class): return {"error": "extension missing: class %s not loaded" % entry.native_class}
		part.ext = ClassDB.instantiate(entry.native_class)
	return part

static func _stop() -> void:
	Simulation.native = null
	if _file != null: _file.close()
	_file = null
	_mode = "off"
	_parts = {}
	reset_report()

static func _empty_stats() -> Dictionary:
	return {"gd": 0, "pack": 0, "call": 0, "apply": 0, "calls": 0, "entities": 0, "in_bytes": 0, "out_bytes": 0, "mismatch": "", "error": ""}

## Sums in microseconds over the sampled window, per slice.
static func report() -> Dictionary:
	return {"mode": _mode, "slices": _stats.duplicate(true), "ticks": _ticks, "tick_sum": _tick_sum}

static func reset_report() -> void:
	for slice_name: String in _stats: _stats[slice_name] = _empty_stats()
	if _parts.is_empty(): _stats = {}
	_ticks = 0
	_tick_sum = 0

## The caller times sim.step() and reports it here, so tick_sum covers the same window as the slice sums.
static func record_tick(usec: int) -> void:
	_ticks += 1
	_tick_sum += usec

static func slice_lines(row: String) -> PackedStringArray:
	var lines := PackedStringArray()
	var names: Array = _stats.keys()
	names.sort()
	for slice_name: String in names:
		var s: Dictionary = _stats[slice_name]
		var problem: String = s.mismatch if not s.mismatch.is_empty() else ("error " + s.error if not s.error.is_empty() else "none")
		lines.append("SLICE %s %s mode=%s gd_ms=%.3f pack_ms=%.3f call_ms=%.3f apply_ms=%.3f calls=%d entities=%d in_bytes=%d out_bytes=%d ticks=%d tick_sum_ms=%.3f mismatch=%s" % [
			row, slice_name, _mode, s.gd / 1000.0, s.pack / 1000.0, s.call / 1000.0, s.apply / 1000.0, s.calls, s.entities, s.in_bytes, s.out_bytes, _ticks, _tick_sum / 1000.0, problem])
	return lines

# Hooks called by simulation.gd step(); false means "not selected, run your own lines".
func move(sim: Simulation, ids: Array[int]) -> bool:
	return _run("move", sim, ids)

func horde(sim: Simulation, armed: Array[int]) -> bool:
	return _run("horde", sim, armed)

static func _run(slice_name: String, sim: Simulation, ids: Array[int]) -> bool:
	if not _parts.has(slice_name): return false
	var part: Dictionary = _parts[slice_name]
	var stats: Dictionary = _stats[slice_name]
	stats.calls += 1
	if _mode == "off": _step_gd(part.slice, stats, sim, ids)
	else: _step_native(slice_name, part, stats, sim, ids)
	return true

static func _step_gd(slice: RefCounted, stats: Dictionary, sim: Simulation, ids: Array[int]) -> void:
	var start: int = Time.get_ticks_usec()
	slice.step_gd(sim, ids)
	stats.gd += Time.get_ticks_usec() - start

static func _step_native(slice_name: String, part: Dictionary, stats: Dictionary, sim: Simulation, ids: Array[int]) -> void:
	var slice: RefCounted = part.slice
	var start: int = Time.get_ticks_usec()
	var inputs: Array = slice.pack(sim, ids)
	var packed: int = Time.get_ticks_usec()
	var outputs: Array = slice.call_pass(part.ext, inputs) if _mode == "pass" else slice.call_native(part.ext, inputs)
	var called: int = Time.get_ticks_usec()
	stats.pack += packed - start
	stats.call += called - packed
	stats.entities += inputs[0].size() if not inputs.is_empty() else 0
	stats.in_bytes += bytes_of(inputs)
	stats.out_bytes += bytes_of(outputs)
	if outputs.is_empty() and stats.error.is_empty():
		stats.error = "tick=%d %s" % [sim.tick(), part.ext.last_error()]
	if _mode == "native" and not outputs.is_empty():
		slice.apply(sim, inputs, outputs)
		stats.apply += Time.get_ticks_usec() - called
		return
	# Mode pass, mode shadow, or a failed native call: GDScript decides, so the game always goes on.
	_step_gd(slice, stats, sim, ids)
	if _mode != "shadow": return
	var verdict: Dictionary = slice.compare(sim, inputs, outputs)
	if stats.mismatch.is_empty() and not verdict.mismatch.is_empty():
		stats.mismatch = "tick=%d %s" % [sim.tick(), verdict.mismatch]
	if _file != null: write_record(_file, slice_name, sim.tick(), inputs, verdict.expected)

static func bytes_of(buffers: Array) -> int:
	var total: int = 0
	for buffer: Variant in buffers:
		total += WIDTHS[TAGS[typeof(buffer)]] * buffer.size()
	return total

static func open_fixture(path: String) -> FileAccess:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return null
	file.store_buffer("WGFX".to_ascii_buffer())
	file.store_32(FIXTURE_VERSION)
	return file

static func write_record(file: FileAccess, slice_name: String, tick: int, inputs: Array, outputs: Array) -> void:
	var name_bytes: PackedByteArray = slice_name.to_utf8_buffer()
	file.store_8(name_bytes.size())
	file.store_buffer(name_bytes)
	file.store_64(tick)
	for buffers: Array in [inputs, outputs]:
		file.store_32(buffers.size())
		for buffer: Variant in buffers:
			file.store_8(TAGS[typeof(buffer)])
			file.store_32(buffer.size())
			file.store_buffer(buffer if buffer is PackedByteArray else buffer.to_byte_array())

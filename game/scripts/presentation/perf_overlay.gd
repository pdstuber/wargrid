extends Label

const TimingStats = preload("res://scripts/debug/timing_stats.gd")
const UiStyle = preload("res://scripts/presentation/ui_style.gd")
const WINDOW: int = 120
const REFRESH_SECONDS: float = 0.25
var extra: Callable = Callable()
var _frames := PackedFloat64Array()
var _steps := PackedFloat64Array()
var _frame_count: int = 0
var _step_count: int = 0
var _units: int = 0
var _buildings: int = 0
var _tick: int = 0
var _since_refresh: float = 0.0

func _init() -> void:
	name = "PerfOverlay"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiStyle.hud_theme()
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -16.0
	offset_right = -16.0
	offset_top = 16.0
	_frames.resize(WINDOW)
	_steps.resize(WINDOW)

func toggle() -> void:
	visible = not visible
	if visible: refresh_text()

func record_frame(ms: float) -> void:
	_frames[_frame_count % WINDOW] = ms
	_frame_count += 1

func record_step(ms: float) -> void:
	_steps[_step_count % WINDOW] = ms
	_step_count += 1

func set_counts(units: int, buildings: int, tick: int) -> void:
	_units = units
	_buildings = buildings
	_tick = tick

func _process(delta: float) -> void:
	record_frame(delta * 1000.0)
	_since_refresh += delta
	if _since_refresh < REFRESH_SECONDS: return
	_since_refresh = 0.0
	if visible: refresh_text()

func refresh_text() -> void:
	var frame: Dictionary = _summary(_frames, _frame_count)
	var step: Dictionary = _summary(_steps, _step_count)
	var lines: String = "FPS %d\nFrame %.1f / p95 %.1f / max %.1f ms\nSim step %.2f / p95 %.2f ms\nUnits %d | Buildings %d | Tick %d" % [
		Engine.get_frames_per_second(), frame.last, frame.p95, frame.max, step.last, step.p95, _units, _buildings, _tick]
	if extra.is_valid(): lines += "\n" + str(extra.call())
	text = lines

static func _summary(ring: PackedFloat64Array, count: int) -> Dictionary:
	var n: int = mini(count, WINDOW)
	var stats: Dictionary = TimingStats.summary(ring.slice(0, n))
	stats["last"] = ring[(count - 1) % WINDOW] if count > 0 else 0.0
	return stats

static func summarize(samples: PackedFloat64Array) -> Dictionary:
	var ring := PackedFloat64Array()
	ring.resize(WINDOW)
	for i in samples.size(): ring[i % WINDOW] = samples[i]
	return _summary(ring, samples.size())

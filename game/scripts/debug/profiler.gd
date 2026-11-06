extends RefCounted

# Named, inclusive timing zones (after OpenRA PerfHistory/PerfTickLogger); off by default, so zones cost one bool check.
const Stats = preload("res://scripts/debug/timing_stats.gd")
const SLOW_MS: float = 1.0
static var enabled: bool = false
static var slow: PackedStringArray = PackedStringArray()
static var _current: Dictionary = {}
static var _calls: Dictionary = {}
static var _series: Dictionary = {}
static var _ticks: int = 0

static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func end(zone: StringName, start: int) -> void:
	if not enabled: return
	var elapsed: int = Time.get_ticks_usec() - start
	_current[zone] = _current.get(zone, 0) + elapsed
	_calls[zone] = _calls.get(zone, 0) + 1
	if elapsed >= SLOW_MS * 1000.0: slow.append("%d %s %.3f" % [_ticks, zone, elapsed / 1000.0])

static func end_tick() -> void:
	if not enabled: return
	for zone: Variant in _current:
		if not _series.has(zone):
			var zeros: Array = []
			zeros.resize(_ticks)
			zeros.fill(0.0)
			_series[zone] = zeros
	for zone: Variant in _series: _series[zone].append(_current.get(zone, 0) / 1000.0)
	_current.clear()
	_ticks += 1

static func reset() -> void:
	slow.clear()
	_current.clear()
	_calls.clear()
	_series.clear()
	_ticks = 0

static func ticks() -> int:
	return _ticks

static func calls(zone: StringName) -> int:
	return _calls.get(zone, 0)

static func series(zone: StringName) -> PackedFloat64Array:
	return PackedFloat64Array(_series.get(zone, []))

static func _mean(zone: StringName) -> float:
	var total: float = 0.0
	for value: Variant in _series[zone]: total += value
	return total / maxi(_ticks, 1)

# Zones sorted by mean ms per tick; share is relative to `total_zone`.
static func report(label: String, total_zone: StringName = &"step") -> PackedStringArray:
	var zones: Array = _series.keys()
	var means: Dictionary = {}
	for zone: Variant in zones: means[zone] = _mean(zone)
	zones.sort_custom(func(a: StringName, b: StringName) -> bool: return means[a] > means[b] or (means[a] == means[b] and String(a) < String(b)))
	var total: float = means.get(total_zone, 0.0)
	var lines := PackedStringArray()
	for zone: Variant in zones:
		var summary: Dictionary = Stats.summary(series(zone))
		lines.append("PROFILE %s zone=%s mean_ms=%.4f share=%.1f%% p50=%.4f p95=%.4f max=%.3f calls_per_tick=%.2f" % [label, zone, means[zone],
			100.0 * means[zone] / total if total > 0.0 else 0.0, summary.p50, summary.p95, summary.max, float(_calls.get(zone, 0)) / maxi(_ticks, 1)])
	return lines

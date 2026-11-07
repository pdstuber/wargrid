extends SceneTree

# Report-only host calibration: fixed work per sample, no gate. Usage: -- --minutes=2
const ITERATIONS := 20000
const MINUTE_USEC := 60_000_000

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var minutes: float = 1.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = arg.trim_prefix("--minutes=").to_float()
	if minutes <= 0.0:
		push_error("--minutes must be positive")
		quit(1)
		return
	print("CALIBRATION engine=", Engine.get_version_info().string, " os=", OS.get_name(),
		" cpu=", OS.get_processor_name(), " iterations=", ITERATIONS, " minutes=", minutes)
	var end: int = Time.get_ticks_usec() + int(minutes * MINUTE_USEC)
	var minute: int = 0
	var sink: float = 0.0
	while Time.get_ticks_usec() < end:
		var samples := PackedFloat64Array()
		var minute_end: int = mini(Time.get_ticks_usec() + MINUTE_USEC, end)
		while Time.get_ticks_usec() < minute_end:
			var start: int = Time.get_ticks_usec()
			sink += _work()
			samples.append((Time.get_ticks_usec() - start) / 1000.0)
		_report(minute, samples)
		minute += 1
	print("CALIBRATION DONE sink=", sink)
	quit(0)

func _work() -> float:
	var i: int = 0
	var h: int = 17
	var f: float = 1.0
	while i < ITERATIONS:
		h = (h * 31 + i) & 0xFFFFFF
		f = f * 1.0000001 + sqrt(float(h & 1023)) * 0.001
		i += 1
	return f + h

func _percentile(sorted: PackedFloat64Array, p: float) -> float:
	return sorted[mini(sorted.size() - 1, int(p * sorted.size()))]

func _report(minute: int, samples: PackedFloat64Array) -> void:
	if samples.is_empty():
		return
	samples.sort()
	print("CAL minute=%d n=%d p50=%.3f p95=%.3f p99=%.3f max=%.3f ms" % [minute, samples.size(),
		_percentile(samples, 0.5), _percentile(samples, 0.95), _percentile(samples, 0.99), samples[-1]])

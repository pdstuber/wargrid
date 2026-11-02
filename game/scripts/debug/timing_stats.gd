extends RefCounted

static func summary(samples: PackedFloat64Array) -> Dictionary:
	if samples.is_empty():
		return {"n": 0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var sorted := samples.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	return {"n": n, "p50": sorted[ceili(0.50 * n) - 1], "p95": sorted[ceili(0.95 * n) - 1],
		"p99": sorted[ceili(0.99 * n) - 1], "max": sorted[n - 1]}

extends RefCounted

const BUDGET_P95_MS: float = 1.82
const BUDGET_P99_MS: float = 3.64

static func within(stats: Dictionary, p95_limit: float, p99_limit: float) -> bool:
	return stats.p95 <= p95_limit and stats.p99 <= p99_limit

static func summary(samples: PackedFloat64Array) -> Dictionary:
	if samples.is_empty():
		return {"n": 0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var sorted := samples.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	return {"n": n, "p50": sorted[ceili(0.50 * n) - 1], "p95": sorted[ceili(0.95 * n) - 1],
		"p99": sorted[ceili(0.99 * n) - 1], "max": sorted[n - 1]}

static func mean(samples: PackedFloat64Array) -> float:
	if samples.is_empty():
		return 0.0
	var total: float = 0.0
	for sample in samples:
		total += sample
	return total / samples.size()

static func worst(samples: PackedFloat64Array) -> Dictionary:
	var result := {"ms": 0.0, "index": -1}
	for i in samples.size():
		if result.index == -1 or samples[i] > result.ms:
			result = {"ms": samples[i], "index": i}
	return result

static func over_budget_line(layout: String, stats: Dictionary) -> String:
	if within(stats, BUDGET_P95_MS, BUDGET_P99_MS):
		return ""
	return "OVER BUDGET %s p95=%.3f p99=%.3f budget=%.2f/%.2f" % [layout, stats.p95, stats.p99, BUDGET_P95_MS, BUDGET_P99_MS]

static func worst_tick_line(bench: String, row: String, samples: PackedFloat64Array, warmup: int) -> String:
	var worst_sample: Dictionary = worst(samples)
	return "WORST TICK %s %s ms=%.3f tick=%d" % [bench, row, worst_sample.ms, warmup + worst_sample.index]

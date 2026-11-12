extends RefCounted

static func saturation(rates: Dictionary, collector_cost: int, short: Array = []) -> Dictionary:
	var keys: Array = rates.keys()
	keys.sort()
	var skipped: Array = []
	var used: Dictionary = {}
	for n: int in keys:
		if rates[n] == null or n in short: skipped.append(n)
		else: used[n] = rates[n]
	if used.is_empty(): return {"skipped": skipped}
	var cap: float = used.values().max()
	var n_cap: int = -1
	var n90: int = -1
	var marginal: Dictionary = {}
	var payback_s: Dictionary = {}
	for n: int in used:
		if n_cap < 0 and used[n] == cap: n_cap = n
		if n90 < 0 and used[n] >= 0.9 * cap: n90 = n
		if used.has(n - 1):
			marginal[n] = used[n] - used[n - 1]
			payback_s[n] = collector_cost / (marginal[n] / 60.0) if marginal[n] > 0.0 else INF
	return {"cap": cap, "n_cap": n_cap, "n90": n90, "spend90": (n90 - 1) * collector_cost, "marginal": marginal, "payback_s": payback_s, "skipped": skipped}

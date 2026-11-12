extends RefCounted

const ViewRows = preload("res://scripts/simulation/view_rows.gd")

const LEG_KEYS: Array[String] = ["total", "flying", "standing", "other", "moved", "path_pending", "flying_depot_zone", "flying_mid", "flying_pile_zone", "crowded", "distance"]

var samples: int = 0
var idle_samples: int = 0
var gaps: Array[int] = []
var contended: Array[int] = []
var ready: Array[int] = []
var overlaps: int = 0
var legs_empty: Array[Dictionary] = []
var legs_loaded: Array[Dictionary] = []
var drops: int = 0
var drops_blocked: int = 0
var cycles: Array[int] = []
var trips: int = 0

var _last_holders: Array = []
var _empty_run: int = 0
var _last_contended: bool = false
var _last_ready: bool = false
var _previous: Dictionary = {}
var _legs: Dictionary = {}
var _last_unloading: Dictionary = {}
var _depot: Vector2
var _pile: Vector2

func _init(depot: Vector2 = Vector2.ZERO, pile: Vector2 = Vector2(1, 0)) -> void:
	_depot = depot
	_pile = pile

static func units_of(view: Dictionary, kind: String) -> Dictionary:
	var units: ViewRows = view.units
	var found: Dictionary = {}
	for index: int in range(units.size()):
		if units.kinds[units.kind[index]] != kind: continue
		var phase_slot: int = units.phase[index]
		var status_slot: int = units.status[index]
		found[units.id[index]] = {
			"phase": "none" if phase_slot == ViewRows.NONE else units.phases[phase_slot],
			"status": "other" if status_slot == ViewRows.NONE else ViewRows.STATUSES[status_slot],
			"position": Vector2(units.x[index], units.y[index]),
		}
	return found

func observe(tick: int, units: Dictionary) -> void:
	samples += 1
	_observe_pile(units)
	for id: int in units:
		_observe_unit(tick, id, units)
	_previous = units

func _observe_pile(units: Dictionary) -> void:
	var holders: Array = units.keys().filter(func(id: int) -> bool: return units[id].phase == "loading")
	if holders.size() > 1: overlaps += 1
	if holders.is_empty():
		idle_samples += 1
		if not _last_holders.is_empty(): _empty_run += 1
		return
	if not _last_holders.is_empty() and (_empty_run > 0 or not _last_holders.has(holders[0])): _close_gap()
	_last_holders = holders
	_empty_run = 0
	_last_contended = false
	_last_ready = false
	for id: int in units:
		if id in holders: continue
		if units[id].phase == "waiting_source": _last_ready = true
		if units[id].phase in ["waiting_source", "lead_source"]: _last_contended = true

func _close_gap() -> void:
	gaps.append(_empty_run)
	if _last_contended: contended.append(_empty_run)
	if _last_ready: ready.append(_empty_run)

func _observe_unit(tick: int, id: int, units: Dictionary) -> void:
	if not _previous.has(id): return
	var row: Dictionary = units[id]
	var before: Dictionary = _previous[id]
	var phase: String = row.phase
	if before.phase.begins_with("flying_") and phase in ["seeking", "idle"]:
		drops += 1
		if "blocked" in [before.status, row.status]: drops_blocked += 1
	if phase == "unloading" and before.phase != "unloading":
		trips += 1
		if _last_unloading.has(id): cycles.append(tick - _last_unloading[id])
		_last_unloading[id] = tick
	if phase == "loading" and before.phase != "loading": _close_leg(id, legs_empty)
	if phase == "unloading" and before.phase != "unloading": _close_leg(id, legs_loaded)
	if before.phase == "unloading" and phase != "unloading": _legs[id] = _new_leg()
	if before.phase == "loading" and phase != "loading": _legs[id] = _new_leg()
	if _legs.has(id): _count(_legs[id], id, units, before)

func _new_leg() -> Dictionary:
	var leg: Dictionary = {}
	for key: String in LEG_KEYS: leg[key] = 0
	leg.distance = 0.0
	return leg

func _count(leg: Dictionary, id: int, units: Dictionary, before: Dictionary) -> void:
	var row: Dictionary = units[id]
	var phase: String = row.phase
	leg.total += 1
	leg.distance += row.position.distance_to(before.position)
	if phase.begins_with("flying_"):
		leg.flying += 1
		leg[_zone(row.position)] += 1
		if _crowded(id, units): leg.crowded += 1
	elif phase.begins_with("lead_") or phase.begins_with("waiting_"): leg.standing += 1
	else: leg.other += 1
	if row.position != before.position: leg.moved += 1
	if row.status == "path_pending": leg.path_pending += 1

func _zone(position: Vector2) -> String:
	var axis: Vector2 = _pile - _depot
	var along: float = (position - _depot).dot(axis) / axis.length_squared()
	if along < 1.0 / 3.0: return "flying_depot_zone"
	return "flying_pile_zone" if along > 2.0 / 3.0 else "flying_mid"

func _crowded(id: int, units: Dictionary) -> bool:
	for other: int in units:
		if other != id and units[other].position.distance_to(units[id].position) <= 1.0: return true
	return false

func _close_leg(id: int, into: Array[Dictionary]) -> void:
	if _legs.has(id): into.append(_legs[id])
	_legs.erase(id)

func summary() -> Dictionary:
	return {"samples": samples, "idle_samples": idle_samples, "gaps": gaps, "contended": contended, "ready": ready, "overlaps": overlaps, "legs_empty": legs_empty, "legs_loaded": legs_loaded, "drops": drops, "drops_blocked": drops_blocked, "cycles": cycles, "trips": trips}

static func quantile(values: Array, q: float) -> float:
	if values.is_empty(): return -1.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[clampi(ceili(q * sorted.size()) - 1, 0, sorted.size() - 1)])

static func total(values: Array) -> int:
	var sum: int = 0
	for value: int in values: sum += value
	return sum

static func _leg_text(legs: Array[Dictionary]) -> String:
	var parts: Array = []
	for key: String in LEG_KEYS: parts.append("%.1f" % quantile(legs.map(func(leg: Dictionary) -> float: return float(leg[key])), 0.5))
	return "/".join(parts)

static func _leg_sum(legs: Array[Dictionary], key: String) -> int:
	return total(legs.map(func(leg: Dictionary) -> int: return int(leg[key])))

static func _p90(legs: Array[Dictionary], key: String) -> String:
	return "%.1f" % quantile(legs.map(func(leg: Dictionary) -> int: return leg[key]), 0.9)

static func line(model: String, scenario: String, s: Dictionary) -> String:
	return "DOCK %s probe %s samples=%d idle=%.1f gaps=%d/%.1f/%d contended=%d/%.1f/%d ready=%d/%.1f overlaps=%d empty=%s loaded=%s path_pending_p90=%s/%s path_pending_sum=%d/%d drops=%d blocked=%d cycle=%.1f trips=%d" % [
		model, scenario, s.samples, 100.0 * s.idle_samples / maxi(s.samples, 1),
		s.gaps.size(), quantile(s.gaps, 0.5), total(s.gaps),
		s.contended.size(), quantile(s.contended, 0.5), total(s.contended),
		s.ready.size(), quantile(s.ready, 0.5), s.overlaps,
		_leg_text(s.legs_empty), _leg_text(s.legs_loaded),
		_p90(s.legs_empty, "path_pending"), _p90(s.legs_loaded, "path_pending"),
		_leg_sum(s.legs_empty, "path_pending"), _leg_sum(s.legs_loaded, "path_pending"),
		s.drops, s.drops_blocked, quantile(s.cycles, 0.5), s.trips]

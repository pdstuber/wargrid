extends RefCounted

const Usa = preload("res://scripts/simulation/definitions/usa.gd")
const Factions = preload("res://scripts/simulation/definitions/factions.gd")

const DEFAULT_SPAWN := "usa_light_vehicle"
const SOURCE_FOOTPRINT := Vector2i(3, 3)
const UNIT_KEYS: Array[String] = ["cost", "ticks", "speed", "accel", "brake", "locomotor", "min_turn_speed", "turn_cos", "turn_sin"]
const BUILDING_KEYS: Array[String] = ["cost", "ticks", "power", "footprint", "prerequisite"]

static var _extra: Dictionary = {}
static var _unit_cache: Dictionary = {}
static var _building_cache: Dictionary = {}
static var _profile_cache: Dictionary = {}
static var air_kinds: Dictionary = _air_kinds()

static func kind(id: String) -> Dictionary:
	return _extra[id] if _extra.has(id) else Usa.KINDS.get(id, {})

static func faction(id: String) -> Dictionary:
	return Factions.FACTIONS.get(id, {})

static func units() -> Array[String]:
	return _ids(true)

static func buildings() -> Array[String]:
	return _ids(false)

static func is_builder(id: String) -> bool:
	return not kind(id).get("builds", []).is_empty()

static func collects(id: String) -> Dictionary:
	return kind(id).get("collects", {})

static func can_rally(id: String) -> bool:
	return kind(id).get("produces", []).any(func(unit: String) -> bool: return collects(unit).is_empty())

# Test-only kinds are cleared by clear_test_kinds.
static func add_test_kind(id: String, row: Dictionary) -> void:
	_extra[id] = row
	_reset()

static func clear_test_kinds() -> void:
	_extra = {}
	_reset()

# Projections that keep today's economy and combat dictionary shapes; cached so callers share one dictionary.
static func unit_view(id: String) -> Dictionary:
	if _unit_cache.has(id): return _unit_cache[id]
	var row: Dictionary = kind(id)
	if not row.has("class"): return {}
	_unit_cache[id] = _unit_view(id, row)
	return _unit_cache[id]

static func building_view(id: String) -> Dictionary:
	if _building_cache.has(id): return _building_cache[id]
	var row: Dictionary = kind(id)
	if not row.has("footprint"): return {}
	_building_cache[id] = _building_view(row)
	return _building_cache[id]

static func profile_view(id: String) -> Dictionary:
	if _profile_cache.has(id): return _profile_cache[id]
	var row: Dictionary = kind(id)
	if not row.has("max_hp"): return {}
	_profile_cache[id] = {"max_hp": row.max_hp, "armor": row.armor, "weapon": row.weapon}
	return _profile_cache[id]

static func _unit_view(id: String, row: Dictionary) -> Dictionary:
	var view: Dictionary = {}
	for key: String in UNIT_KEYS:
		if row.has(key): view[key] = row[key]
	view.air = row["class"] == "air"
	view.producer = _producer_of(id)
	return view

static func _building_view(row: Dictionary) -> Dictionary:
	var view: Dictionary = {}
	for key: String in BUILDING_KEYS: view[key] = row[key]
	view.produces = row.produces[0] if not row.produces.is_empty() else ""
	return view

static func _producer_of(unit_id: String) -> String:
	for id: String in buildings():
		if kind(id).produces.has(unit_id): return id
	return ""

static func _ids(want_units: bool) -> Array[String]:
	var found: Array[String] = []
	for source: Dictionary in [Usa.KINDS, _extra]:
		for id: String in source:
			if source[id].has("class") == want_units: found.append(id)
	found.sort()
	return found

static func _air_kinds() -> Dictionary:
	var found: Dictionary = {}
	for id: String in units():
		if kind(id)["class"] == "air": found[id] = true
	return found

static func _reset() -> void:
	_unit_cache = {}
	_building_cache = {}
	_profile_cache = {}
	air_kinds = _air_kinds()

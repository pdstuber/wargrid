extends RefCounted

const Definitions = preload("res://scripts/simulation/definitions/definitions.gd")

const HEADING_BUCKETS: int = 64
const SLOT_ROOF: int = 0
const SLOT_ROOF_DARK: int = 1
const SLOT_SIDE: int = 2
const SLOT_SIDE_DARK: int = 3
const SLOT_MACHINE: int = 4
const SLOT_SMOKE: int = 5
const SLOT_OWNER_FLAT: int = 6
const SLOT_SKIN: int = 7

const TANK_ROLES := {"usa_tank": &"tank_usa", "china_tank": &"tank_china_gatling", "frc_tank": &"tank_frc", "china_light_vehicle": &"tank_china"}
const BUILDING_SUFFIXES := {"power_plant": &"power_plant", "factory": &"war_factory", "supply_center": &"supply_depot", "command_center": &"command_center", "barracks": &"barracks"}
const SUPPLY_STEPS: Array[int] = [1, 5, 15, 40]

static var _parts_cache: Dictionary = {}
static var _turreted: Dictionary = {}

static func role(kind: String) -> StringName:
	var row: Dictionary = Definitions.kind(kind)
	if TANK_ROLES.has(kind):
		return TANK_ROLES[kind]
	if row.has("footprint"):
		return _building_role(kind, row.footprint)
	match row.get("class", ""):
		"infantry":
			return _infantry_role(kind)
		"air":
			return &"helicopter"
		"vehicle":
			return _vehicle_role(kind)
	return &"default_vehicle"

static func _infantry_role(kind: String) -> StringName:
	if kind.ends_with("_rocket_infantry"):
		return &"rocket_infantry"
	return &"laborer" if kind.ends_with("_builder") else &"infantry"

static func _vehicle_role(kind: String) -> StringName:
	if kind.ends_with("_builder"):
		return &"bulldozer"
	return &"collector_truck" if kind.ends_with("_collector") else &"light_vehicle"

static func _building_role(kind: String, footprint: Vector2i) -> StringName:
	if kind.contains("_hole_"):
		return StringName("rubble_%d" % footprint.x)
	if kind.ends_with("_defence"):
		return StringName("defence_" + kind.get_slice("_", 0))
	for suffix: String in BUILDING_SUFFIXES:
		if kind.ends_with(suffix):
			return BUILDING_SUFFIXES[suffix]
	return &"default_building"

# A pile's variant packs stack level (0-4) with its footprint, so small piles bake smaller.
static func source_variant(boxes: int, footprint: Vector2i) -> int:
	var level: int = 0
	for step in SUPPLY_STEPS:
		if boxes >= step: level += 1
	return level | (footprint.x << 4) | (footprint.y << 8)

static func parts(role_name: StringName, detail: int, variant: int = 0) -> Array[Dictionary]:
	var by_role: Dictionary = _parts_cache.get_or_add(role_name, {})
	var key: int = detail | (variant << 2)
	if not by_role.has(key):
		by_role[key] = _build_parts(role_name, detail, variant)
	return by_role[key]

static func has_turret(role_name: StringName) -> bool:
	if not _turreted.has(role_name):
		_turreted[role_name] = parts(role_name, 0).any(func(part: Dictionary) -> bool: return part.angle == &"turret")
	return _turreted[role_name]

static func _build_parts(role_name: StringName, detail: int, variant: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	match role_name:
		&"infantry":
			found.append(_part(&"body", &"heading", _soldier() + [_prim(&"box", Vector3(0.12, 0.1, 2.2), Vector3(0.22, 0.04, 0.4), SLOT_MACHINE)]))
		&"laborer":
			found.append(_part(&"body", &"heading", _soldier() + [_prim(&"box", Vector3(-0.1, 0, 2.45), Vector3(0.06, 0.09, 0.45), SLOT_ROOF_DARK), _prim(&"box", Vector3(-0.1, 0, 2.9), Vector3(0.05, 0.11, 0.3), SLOT_SKIN)]))
		&"rocket_infantry":
			found.append(_part(&"body", &"heading", _soldier() + [_prim(&"box", Vector3(0, 0.11, 2.4), Vector3(0.3, 0.07, 0.7), SLOT_MACHINE)]))
		&"bulldozer":
			found.append(_part(&"body", &"heading", [_prim(&"box", Vector3(-0.04, 0, 0), Vector3(0.56, 0.44, 2.5), SLOT_ROOF), _prim(&"box", Vector3(0.29, 0, 0), Vector3(0.1, 0.6, 2.5), SLOT_MACHINE)]))
			found.append(_part(&"cab", &"heading", [_prim(&"box", Vector3(-0.1, 0, 2.5), Vector3(0.28, 0.32, 2), SLOT_ROOF_DARK)]))
		&"tank_usa":
			_append_tank(found, Vector2(0.75, 0.5), Vector3(0.4, 0.34, 1), 0.4, 0.0, false)
		&"tank_china":
			_append_tank(found, Vector2(0.8, 0.6), Vector3(0.5, 0.4, 1), 0.45, 0.0, false)
		&"tank_china_gatling":
			_append_tank(found, Vector2(0.8, 0.6), Vector3(0.45, 0.45, 1), 0.35, 0.0, true)
		&"tank_frc":
			_append_tank(found, Vector2(0.7, 0.45), Vector3(0.34, 0.34, 1), 0.36, 0.055, false)
		&"power_plant":
			found.append(_part(&"body", &"fixed", _slab(1.7, 3, variant) + _drums(variant)))
		&"war_factory":
			found.append(_part(&"body", &"fixed", _slab(2.6, 14, variant) + _smoke(2.6, 14, variant)))
			found.append(_part(&"opening", &"fixed", [_prim(&"box", Vector3(-0.65, 1.32, 0), Vector3(1.0, 0.04, 8), SLOT_SIDE_DARK), _prim(&"box", Vector3(-0.65, 1.42, 0), Vector3(1.0, 0.16, 0.5), SLOT_MACHINE)]))
		&"supply_depot":
			found.append(_part(&"body", &"fixed", _slab(2.6, 5, variant)))
			found.append(_part(&"gantry", &"fixed", [_prim(&"box", Vector3(-0.35, -0.35, 5), Vector3(0.7, 0.7, 3), SLOT_ROOF_DARK)]))
		&"supply_source":
			var pile: Array = _pile(variant)
			found.append(_part(&"body", &"fixed", pile.slice(0, 1)))
			found.append(_part(&"crates", &"fixed", pile.slice(1).filter(func(prim: Dictionary) -> bool: return prim.offset.z < 1.0)))
			found.append(_part(&"stack", &"fixed", pile.slice(1).filter(func(prim: Dictionary) -> bool: return prim.offset.z >= 1.0)))
		&"light_vehicle":
			found.append(_part(&"body", &"heading", [_prim(&"box", Vector3.ZERO, Vector3(0.78, 0.42, 2.5), SLOT_ROOF)]))
			found.append(_part(&"cab", &"heading", [_prim(&"box", Vector3(-0.08, 0, 2.5), Vector3(0.36, 0.36, 1.5), SLOT_ROOF_DARK)]))
			found.append(_part(&"turret", &"turret", [_prim(&"box", Vector3(0, 0, 4), Vector3(0.12, 0.12, 0.5), SLOT_MACHINE), _prim(&"box", Vector3(0.17, 0, 4.1), Vector3(0.22, 0.06, 0.3), SLOT_MACHINE)]))
		&"collector_truck":
			found.append(_part(&"body", &"heading", [_prim(&"box", Vector3.ZERO, Vector3(0.84, 0.44, 2), SLOT_ROOF)]))
			found.append(_part(&"cargo", &"heading", [_prim(&"box", Vector3(-0.12, 0, 2), Vector3(0.4, 0.32, 1.5), SLOT_MACHINE), _prim(&"box", Vector3(0.3, 0, 2), Vector3(0.22, 0.4, 2.5), SLOT_ROOF_DARK)]))
		&"helicopter":
			found.append(_part(&"body", &"heading", [_prim(&"box", Vector3(0.1, 0, 0), Vector3(0.7, 0.4, 3), SLOT_ROOF), _prim(&"box", Vector3(-0.43, 0, 1), Vector3(0.36, 0.12, 0.6), SLOT_MACHINE)]))
			found.append(_part(&"rotor", &"fixed", [_prim(&"box", Vector3(0.1, 0, 3), Vector3(1.0, 0.1, 0.3), SLOT_MACHINE), _prim(&"box", Vector3(0.1, 0, 3.3), Vector3(0.1, 1.0, 0.3), SLOT_MACHINE)]))
		&"command_center":
			found.append(_part(&"body", &"fixed", _slab(2.6, 14, variant) + _smoke(2.6, 14, variant)))
			found.append(_part(&"roof", &"fixed", [_prim(&"box", Vector3(-0.4, -0.4, 14), Vector3(0.8, 0.8, 4), SLOT_MACHINE)]))
		&"barracks":
			found.append(_part(&"body", &"fixed", _slab(1.7, 6, variant) + _smoke(1.7, 6, variant)))
			found.append(_part(&"doors", &"fixed", [_prim(&"box", Vector3(-0.45, 0.87, 0), Vector3(0.5, 0.04, 3), SLOT_SIDE_DARK)]))
		&"defence_usa":
			found.append(_part(&"body", &"fixed", [_prim(&"box", Vector3.ZERO, Vector3(0.8, 0.8, 2.5), SLOT_ROOF_DARK)]))
			found.append(_part(&"turret", &"turret", [_prim(&"box", Vector3(0, 0, 2.5), Vector3(0.45, 0.35, 1.2), SLOT_ROOF)]))
			found.append(_part(&"rack", &"turret", [_prim(&"box", Vector3(0.1, 0, 3.7), Vector3(0.3, 0.25, 0.4), SLOT_MACHINE)]))
		&"defence_china":
			found.append(_part(&"body", &"fixed", [_prim(&"box", Vector3.ZERO, Vector3(0.8, 0.8, 2.5), SLOT_ROOF_DARK)]))
			found.append(_part(&"turret", &"turret", [_prim(&"box", Vector3(0, 0, 2.5), Vector3(0.4, 0.4, 1), SLOT_ROOF), _prim(&"box", Vector3(0.34, -0.07, 2.8), Vector3(0.28, 0.05, 0.5), SLOT_MACHINE), _prim(&"box", Vector3(0.34, 0.07, 2.8), Vector3(0.28, 0.05, 0.5), SLOT_MACHINE)]))
		&"defence_frc":
			found.append(_part(&"body", &"fixed", [_prim(&"box", Vector3.ZERO, Vector3(0.8, 0.8, 1), SLOT_ROOF_DARK)]))
			found.append(_part(&"hole", &"fixed", [_prim(&"box", Vector3(0, 0, 1), Vector3(0.4, 0.4, 0.2), SLOT_SMOKE)]))
		&"rubble_1", &"rubble_2", &"rubble_3":
			var side: float = float(String(role_name).substr(7)) - 0.4
			found.append(_part(&"body", &"fixed", [_prim(&"box", Vector3.ZERO, Vector3(side, side, 0.5), SLOT_MACHINE), _prim(&"box", Vector3(side / 4.0, 0, 0.5), Vector3(side / 3.0, side / 3.0, 0.8), SLOT_SIDE_DARK)]))
		&"default_building":
			found.append(_part(&"body", &"fixed", [_prim(&"box", Vector3.ZERO, Vector3(2.0, 2.0, 14), SLOT_ROOF)]))
		_:
			var prims: Array = [_prim(&"box", Vector3.ZERO, Vector3(0.8, 0.5, 3), SLOT_ROOF)]
			if detail > 0:
				prims.append(_prim(&"box", Vector3(0, 0, 3), Vector3(0.3, 0.3, 1.5), SLOT_MACHINE))
			found.append(_part(&"body", &"heading", prims))
	return found

# Ground at Zero Hour's height to length ratio: tracks 1.5, deck 2 and turret 1 unit (10.5 px).
static func _append_tank(found: Array[Dictionary], hull: Vector2, dome: Vector3, barrel: float, sideways: float, twin: bool) -> void:
	var prims: Array = [_prim(&"box", Vector3.ZERO, Vector3(hull.x, hull.y - 0.2, 2), SLOT_ROOF_DARK)]
	for lateral: float in [-1.0, 1.0]:
		prims.append(_prim(&"box", Vector3(0, lateral * (hull.y / 2.0 - 0.05), 0), Vector3(hull.x - 0.04, 0.1, 1.5), SLOT_SIDE))
	found.append(_part(&"body", &"heading", prims))
	var turret: Array = [_prim(&"box", Vector3(0, 0, 2), dome, SLOT_ROOF)]
	var reach: float = dome.x / 2.0 + barrel / 2.0
	if twin:
		for lateral: float in [-1.0, 1.0]:
			turret.append(_prim(&"box", Vector3(reach, lateral * 0.08, 2.2), Vector3(barrel, 0.07, 0.6), SLOT_MACHINE))
	else:
		turret.append(_prim(&"box", Vector3(reach, 0, 2.2), Vector3(barrel, 0.12, 0.7), SLOT_MACHINE))
	found.append(_part(&"turret", &"turret", turret, Vector2(0, sideways)))

# 0.16 cell wide, 4.5 units tall: dark legs, torso in the full owner colour, light head.
static func _soldier() -> Array:
	return [_prim(&"cylinder", Vector3.ZERO, Vector3(0.13, 0.13, 1.8), SLOT_SIDE_DARK), _prim(&"cylinder", Vector3(0, 0, 1.8), Vector3(0.16, 0.16, 1.4), SLOT_OWNER_FLAT), _prim(&"cylinder", Vector3(0, 0, 3.2), Vector3(0.11, 0.11, 1.3), SLOT_SKIN)]

# Four quadrants, so damage can knock one out and the roof gets fewer triangles.
static func _slab(side: float, height: float, variant: int) -> Array:
	var roof: int = SLOT_ROOF if variant == 0 else SLOT_ROOF_DARK
	var prims: Array = []
	var quarter: float = side / 2.0
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		if variant > 0 and corner == Vector2(1, 1):
			continue
		prims.append(_prim(&"box", Vector3(corner.x * quarter / 2.0, corner.y * quarter / 2.0, 0), Vector3(quarter, quarter, height), roof))
	return prims

static func _smoke(side: float, height: float, variant: int) -> Array:
	if variant < 2:
		return []
	return [_prim(&"box", Vector3(side / 4.0, side / 4.0, 0), Vector3(0.4, 0.4, height + 3), SLOT_SMOKE)]

static func _drums(variant: int) -> Array:
	var prims: Array = _smoke(1.7, 3, variant)
	for at: Vector2 in [Vector2(-0.4, -0.4), Vector2(0.3, -0.3)]:
		prims.append(_prim(&"cylinder", Vector3(at.x, at.y, 3), Vector3(0.5, 0.5, 10), SLOT_MACHINE))
	return prims

static func _pile(variant: int) -> Array:
	var level: int = variant & 15
	var footprint := Vector2(maxi((variant >> 4) & 15, 1), maxi((variant >> 8) & 15, 1))
	if variant == 0:
		footprint = Vector2(4, 5)
	var crate: float = minf(footprint.x, footprint.y) * 0.3
	var rise: float = 1.5
	var prims: Array = [_prim(&"box", Vector3.ZERO, Vector3(footprint.x - 0.2, footprint.y - 0.2, 0.5), SLOT_SIDE_DARK)]
	var spots: Array = [[Vector2(-0.25, -0.2), 0.0, 2], [Vector2.ZERO, 0.0, 1], [Vector2.ZERO, rise, 4], [Vector2(0.25, 0.2), 0.0, 3]]
	for spot: Array in spots:
		if level >= spot[2]:
			var at: Vector2 = spot[0]
			prims.append(_prim(&"box", Vector3(at.x * footprint.x, at.y * footprint.y, 0.5 + spot[1]), Vector3(crate, crate, rise), SLOT_ROOF))
	return prims

# pivot: where a turret part turns, in the hull frame; its prims are relative to it.
static func _part(part_name: StringName, angle: StringName, prims: Array, pivot := Vector2.ZERO) -> Dictionary:
	return {"name": part_name, "angle": angle, "prims": prims, "pivot": pivot}

static func _prim(type: StringName, offset: Vector3, size: Vector3, slot: int) -> Dictionary:
	return {"type": type, "offset": offset, "size": size, "slot": slot}

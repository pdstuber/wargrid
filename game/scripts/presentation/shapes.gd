extends RefCounted

const Definitions = preload("res://scripts/simulation/definitions/definitions.gd")

const HEADING_BUCKETS: int = 64
const SLOT_ROOF: int = 0
const SLOT_ROOF_DARK: int = 1
const SLOT_SIDE: int = 2
const SLOT_SIDE_DARK: int = 3
const SLOT_MACHINE: int = 4
const SLOT_GLOW: int = 5
const SLOT_OUTLINE: int = 6
const SLOT_SHADOW: int = 7

const TANK_ROLES := {"usa_tank": &"tank_usa", "china_tank": &"tank_china", "frc_tank": &"tank_frc", "china_light_vehicle": &"tank_china"}
const BUILDING_SUFFIXES := {"power_plant": &"power_plant", "factory": &"war_factory", "supply_center": &"supply_depot", "command_center": &"command_center", "barracks": &"barracks", "defence": &"defence"}
const SUPPLY_STEPS: Array[int] = [1, 5, 15, 40]

static var _parts_cache: Dictionary = {}

static func role(kind: String) -> StringName:
	var row: Dictionary = Definitions.kind(kind)
	if TANK_ROLES.has(kind):
		return TANK_ROLES[kind]
	if row.has("footprint"):
		return _building_role(kind, row.footprint)
	match row.get("class", ""):
		"infantry":
			return &"rocket_infantry" if kind.ends_with("_rocket_infantry") else &"infantry"
		"air":
			return &"helicopter"
		"vehicle":
			return _vehicle_role(kind)
	return &"default_vehicle"

static func _vehicle_role(kind: String) -> StringName:
	if kind.ends_with("_builder"):
		return &"bulldozer"
	return &"collector_truck" if kind.ends_with("_collector") else &"light_vehicle"

static func _building_role(kind: String, footprint: Vector2i) -> StringName:
	if kind.contains("_hole_"):
		return StringName("rubble_%d" % footprint.x)
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

static func _build_parts(role_name: StringName, detail: int, variant: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	match role_name:
		&"infantry":
			var prims: Array = [_prim(&"cylinder", Vector3.ZERO, Vector3(0.3, 0.3, 6), SLOT_ROOF)]
			if detail > 0:
				prims.append(_prim(&"cylinder", Vector3(0, 0, 6), Vector3(0.2, 0.2, 3), SLOT_MACHINE))
			found.append(_part(&"body", &"heading", prims))
		&"bulldozer":
			var prims: Array = [_prim(&"box", Vector3.ZERO, Vector3(1.1, 0.8, 4), SLOT_ROOF), _prim(&"box", Vector3(0.65, 0, 0), Vector3(0.2, 1.1, 3), SLOT_MACHINE)]
			if detail > 0:
				prims.append(_prim(&"box", Vector3(-0.15, 0, 4), Vector3(0.5, 0.6, 3), SLOT_ROOF_DARK))
			found.append(_part(&"body", &"heading", prims))
		&"tank_usa":
			_append_tank(found, detail, Vector3(1.4, 0.9, 4), Vector3(0.6, 0.6, 3), 0.7)
		&"tank_china":
			_append_tank(found, detail, Vector3(1.5, 1.0, 3), Vector3(0.9, 0.7, 2), 0.9)
		&"tank_frc":
			_append_tank(found, detail, Vector3(1.2, 0.7, 4), Vector3(0.4, 0.4, 5), 0.5)
		&"power_plant":
			found.append(_part(&"body", &"fixed", _slab(1.7, 10, variant) + _tower(detail, variant)))
		&"war_factory":
			var prims: Array = _slab(2.6, 14, variant)
			if detail > 0:
				prims.append(_prim(&"box", Vector3(1.0, 0, 0), Vector3(0.5, 1.2, 8), SLOT_MACHINE))
			found.append(_part(&"body", &"fixed", prims + _smoke(2.6, 14, variant)))
		&"supply_depot":
			var prims: Array = _slab(2.6, 8, variant)
			if detail > 0:
				prims.append(_prim(&"box", Vector3.ZERO, Vector3(1.2, 1.2, 12), SLOT_ROOF_DARK if variant > 0 else SLOT_GLOW))
			found.append(_part(&"body", &"fixed", prims))
		&"supply_source":
			found.append(_part(&"body", &"fixed", _pile(variant)))
		&"light_vehicle":
			var prims: Array = [_prim(&"box", Vector3.ZERO, Vector3(1.1, 0.7, 3), SLOT_ROOF)]
			if detail > 0:
				prims.append(_prim(&"box", Vector3(-0.1, 0, 3), Vector3(0.6, 0.55, 2), SLOT_ROOF_DARK))
			found.append(_part(&"body", &"heading", prims))
		&"collector_truck":
			var prims: Array = [_prim(&"box", Vector3(-0.2, 0, 0), Vector3(1.0, 0.8, 4), SLOT_ROOF), _prim(&"box", Vector3(0.6, 0, 0), Vector3(0.4, 0.7, 3), SLOT_MACHINE)]
			if detail > 0:
				prims.append(_prim(&"box", Vector3(-0.2, 0, 4), Vector3(0.7, 0.5, 2), SLOT_GLOW))
			found.append(_part(&"body", &"heading", prims))
		&"helicopter":
			found.append(_part(&"body", &"heading", [_prim(&"box", Vector3.ZERO, Vector3(1.2, 0.5, 3), SLOT_ROOF), _prim(&"box", Vector3(-0.8, 0, 1), Vector3(0.6, 0.15, 1), SLOT_MACHINE)]))
			var rotor := _part(&"rotor", &"fixed", [_prim(&"box", Vector3(0, 0, 3), Vector3(2.0, 0.12, 0.5), SLOT_MACHINE), _prim(&"box", Vector3(0, 0, 3), Vector3(0.12, 2.0, 0.5), SLOT_MACHINE)])
			rotor.pivot = Vector3(0, 0, 3)
			found.append(rotor)
		&"rocket_infantry":
			var prims: Array = [_prim(&"cylinder", Vector3.ZERO, Vector3(0.3, 0.3, 6), SLOT_ROOF), _prim(&"box", Vector3(0, 0.2, 5), Vector3(0.7, 0.12, 1.5), SLOT_MACHINE)]
			if detail > 0:
				prims.append(_prim(&"cylinder", Vector3(0, 0, 6), Vector3(0.2, 0.2, 3), SLOT_MACHINE))
			found.append(_part(&"body", &"heading", prims))
		&"command_center":
			found.append(_part(&"body", &"fixed", _slab(2.6, 18, variant) + _tower(detail, variant) + [_prim(&"box", Vector3(0, 0, 18), Vector3(1.0, 1.0, 4), SLOT_MACHINE)]))
		&"barracks":
			var prims: Array = _slab(1.7, 8, variant)
			if detail > 0:
				prims.append(_prim(&"box", Vector3(0.5, 0, 0), Vector3(0.3, 0.6, 5), SLOT_MACHINE))
			found.append(_part(&"body", &"fixed", prims + _smoke(1.7, 8, variant)))
		&"defence":
			found.append(_part(&"body", &"fixed", [_prim(&"box", Vector3.ZERO, Vector3(0.8, 0.8, 4), SLOT_ROOF_DARK)]))
			var turret := _part(&"turret", &"heading", [_prim(&"box", Vector3(0, 0, 4), Vector3(0.5, 0.5, 2), SLOT_ROOF), _prim(&"box", Vector3(0.5, 0, 5), Vector3(0.5, 0.15, 1), SLOT_MACHINE)])
			turret.pivot = Vector3(0, 0, 4)
			found.append(turret)
		&"rubble_1", &"rubble_2", &"rubble_3":
			var side: float = float(String(role_name).substr(7)) - 0.4
			found.append(_part(&"body", &"fixed", [_prim(&"box", Vector3.ZERO, Vector3(side, side, 1.5), SLOT_MACHINE), _prim(&"box", Vector3(side / 4.0, 0, 1.5), Vector3(side / 3.0, side / 3.0, 2), SLOT_SIDE_DARK)]))
		&"default_building":
			found.append(_part(&"body", &"fixed", [_prim(&"box", Vector3.ZERO, Vector3(2.0, 2.0, 14), SLOT_ROOF)]))
		_:
			var prims: Array = [_prim(&"box", Vector3.ZERO, Vector3(0.8, 0.5, 8), SLOT_ROOF)]
			if detail > 0:
				prims.append(_prim(&"box", Vector3(0, 0, 8), Vector3(0.3, 0.3, 3), SLOT_MACHINE))
			found.append(_part(&"body", &"heading", prims))
	return found

static func _append_tank(found: Array[Dictionary], detail: int, hull: Vector3, dome: Vector3, barrel: float) -> void:
	found.append(_part(&"body", &"heading", [_prim(&"box", Vector3.ZERO, hull, SLOT_ROOF)]))
	var prims: Array = [_prim(&"box", Vector3(0, 0, hull.z), dome, SLOT_ROOF)]
	if detail > 0:
		prims.append(_prim(&"box", Vector3(dome.x / 2.0 + barrel / 2.0, 0, hull.z + dome.z / 2.0), Vector3(barrel, 0.15, 1), SLOT_MACHINE))
	var turret := _part(&"turret", &"heading", prims)
	turret.pivot = Vector3(0, 0, hull.z)
	found.append(turret)

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
	return [_prim(&"box", Vector3(side / 4.0, side / 4.0, 0), Vector3(0.4, 0.4, height + 8), SLOT_GLOW)]

static func _tower(detail: int, variant: int) -> Array:
	var prims: Array = _smoke(1.7, 10, variant)
	if detail > 0:
		prims.append(_prim(&"cylinder", Vector3(-0.4, -0.4, 10), Vector3(0.4, 0.4, 6), SLOT_MACHINE))
	return prims

static func _pile(variant: int) -> Array:
	var level: int = variant & 15
	var footprint := Vector2(maxi((variant >> 4) & 15, 1), maxi((variant >> 8) & 15, 1))
	if variant == 0:
		footprint = Vector2(4, 5)
	var crate: float = minf(footprint.x, footprint.y) * 0.3
	var rise: float = 4.0
	var prims: Array = [_prim(&"box", Vector3.ZERO, Vector3(footprint.x - 0.2, footprint.y - 0.2, 1.5), SLOT_MACHINE)]
	var spots: Array = [[Vector2(-0.25, -0.2), 0.0, 2], [Vector2.ZERO, 0.0, 1], [Vector2.ZERO, rise, 4], [Vector2(0.25, 0.2), 0.0, 3]]
	for spot: Array in spots:
		if level >= spot[2]:
			var at: Vector2 = spot[0]
			prims.append(_prim(&"box", Vector3(at.x * footprint.x, at.y * footprint.y, 1.5 + spot[1]), Vector3(crate, crate, rise), SLOT_ROOF))
	return prims

static func _part(part_name: StringName, angle: StringName, prims: Array) -> Dictionary:
	return {"name": part_name, "angle": angle, "pivot": Vector3.ZERO, "prims": prims}

static func _prim(type: StringName, offset: Vector3, size: Vector3, slot: int) -> Dictionary:
	return {"type": type, "offset": offset, "size": size, "slot": slot}

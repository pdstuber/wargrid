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

static func role(kind: String) -> StringName:
	var row: Dictionary = Definitions.kind(kind)
	if row.has("footprint"):
		return &"default_building"
	return &"default_infantry" if row.get("class", "") == "infantry" else &"default_vehicle"

static func parts(role_name: StringName, detail: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	match role_name:
		&"default_infantry":
			found.append(_part(&"body", &"heading", [_prim(&"cylinder", Vector3.ZERO, Vector3(0.3, 0.3, 9), SLOT_ROOF)]))
		&"default_building":
			found.append(_part(&"body", &"fixed", [_prim(&"box", Vector3.ZERO, Vector3(2.0, 2.0, 14), SLOT_ROOF)]))
		&"default_source":
			found.append(_part(&"body", &"fixed", [_prim(&"cylinder", Vector3.ZERO, Vector3(1.2, 1.2, 3), SLOT_GLOW)]))
		_:
			var prims: Array = [_prim(&"box", Vector3.ZERO, Vector3(0.8, 0.5, 8), SLOT_ROOF)]
			if detail > 0:
				prims.append(_prim(&"box", Vector3(0, 0, 8), Vector3(0.3, 0.3, 3), SLOT_MACHINE))
			found.append(_part(&"body", &"heading", prims))
	return found

static func _part(part_name: StringName, angle: StringName, prims: Array) -> Dictionary:
	return {"name": part_name, "angle": angle, "pivot": Vector3.ZERO, "prims": prims}

static func _prim(type: StringName, offset: Vector3, size: Vector3, slot: int) -> Dictionary:
	return {"type": type, "offset": offset, "size": size, "slot": slot}

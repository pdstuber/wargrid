extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const VARIANTS := 2
const LINES := {"infantry": ["move", "attack"], "vehicle": ["move", "attack"], "worker": ["move", "work"]}
const ORDER_LINE := {"move": "move", "enter": "move", "unload": "move", "attack": "attack", "attack_move": "attack", "gather": "work", "build": "work", "resume_build": "work"}

static func role(kind: String) -> String:
	var row: Dictionary = Registry.kind(kind)
	if Registry.is_builder(kind) or not Registry.collects(kind).is_empty(): return "worker"
	return "infantry" if row.get("class") == "infantry" else "vehicle"

static func speakers(payload: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	match payload.get("type"):
		"unload": ids.append(payload.get("target_id", -1))
		"build", "resume_build": ids.append(payload.get("builder_id", -1))
		_: ids.assign(payload.get("entity_ids", []))
	return ids

static func path(unit_role: String, line: String, variant: int) -> String:
	return "res://audio/voice/units/%s_%s_%d.wav" % [unit_role, line, variant]

extends RefCounted

const FNV_SEED: int = 2166136261
const FNV_PRIME: int = 16777619
const MASK: int = 0xFFFFFFFF
const NONFINITE: int = 0x7FF0000000000000

static func digest(state: Dictionary) -> String:
	return "%08x%08x" % [state.hash() & MASK, core_check(state)]

static func core_check(state: Dictionary) -> int:
	var h: int = FNV_SEED
	for entity in state.entities:
		h = _mix(h, entity.id)
		h = _mix(h, entity.owner)
		h = _mix(h, entity.hp)
		h = _mix(h, entity.position[0])
		h = _mix(h, entity.position[1])
	for player in state.players:
		h = _mix(h, player.credits)
	return h

static func _mix(h: int, value: Variant) -> int:
	var word: int
	if value is float:
		word = floori(value * 1024.0) if is_finite(value) else NONFINITE
	else:
		word = value
	return ((h ^ (word & MASK)) * FNV_PRIME) & MASK

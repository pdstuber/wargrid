extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

static func unit(kind: String) -> Dictionary:
	return Registry.unit_view(kind)

static func building(kind: String) -> Dictionary:
	return Registry.building_view(kind)

static func work_rate(supply: int, demand: int) -> int:
	if demand == 0 or supply >= demand:
		return 1000
	@warning_ignore("integer_division")
	return clampi(int(supply * 1000 / demand),500,800)

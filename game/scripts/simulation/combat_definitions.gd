extends RefCounted

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Shared = preload("res://scripts/simulation/definitions/shared.gd")

const SCATTER_VS_INFANTRY: float = Shared.SCATTER_VS_INFANTRY
const INFANTRY_BLAST: float = Shared.INFANTRY_BLAST

static func profile(kind: String) -> Dictionary:
	return Registry.profile_view(kind)

static func weapon(kind: String) -> Dictionary:
	return Shared.WEAPONS.get(kind, {})

static func radius(kind: String) -> float:
	var row: Dictionary = Registry.kind(kind)
	if row.has("radius"): return row.radius
	var footprint: Vector2i = Definitions.building(kind).footprint
	return 0.5 * sqrt(float(footprint.x * footprint.x + footprint.y * footprint.y))

static func vision(kind: String) -> float:
	return Registry.kind(kind).get("vision", 0.0)

static func armor_percent(armor: String, damage_type: String) -> int:
	return Shared.ARMOR.get(armor, {}).get(damage_type, 0)

static func initial_combat(kind: String) -> Variant:
	var weapon_kind: String = profile(kind).get("weapon", "")
	if weapon_kind.is_empty(): return null
	var combat: Dictionary = {"mode": "guard", "target_id": null, "goal": null, "next_fire_tick": 0, "shots_left": weapon(weapon_kind).clip_size, "repath_tick": 0, "retarget": false, "until": 0}
	if Registry.kind(kind).has("weapon_tiers"): combat.tier = 0
	if weapon(weapon_kind).has("ramp"): combat.merge({"ramp_level": 0, "ramp_shots": 0, "ramp_target": null, "ramp_until": 0})
	return combat

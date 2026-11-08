extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Shared = preload("res://scripts/simulation/definitions/shared.gd")

const CUES := {
	"rifle_burst": {"sound": "rifle_burst", "limit": 4, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false},
	"carbine": {"sound": "carbine", "limit": 4, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false},
	"cannon": {"sound": "cannon", "limit": 2, "pitch": 1.0, "jitter": 0.0, "gain_db": -3.8, "ui": false},
	"launch": {"sound": "explosion", "limit": 4, "pitch": 1.5, "jitter": 0.0, "gain_db": -6.0, "ui": false},
	"impact": {"sound": "explosion", "limit": 4, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false},
	"infantry_death": {"sound": "infantry_death", "limit": 3, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false},
	"vehicle_death": {"sound": "vehicle_death", "limit": 4, "pitch": 1.0, "jitter": 0.05, "gain_db": 0.0, "ui": false},
	"building": {"sound": "building_small", "limit": 2, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false},
	"placement": {"sound": "click", "limit": 2, "pitch": 0.8, "jitter": 0.0, "gain_db": 0.0, "ui": true},
	"click": {"sound": "click", "limit": 2, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": true},
	"error": {"sound": "error", "limit": 2, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": true},
}

# No catch-all: a new weapon needs a row (spec section 2).
const SHOT_BY_WEAPON := {"rifle": "rifle_burst", "militia_gun": "carbine", "cannon": "cannon", "pickup_cannon": "cannon"}
const SHOT_BY_DAMAGE := {"small_arms": "carbine", "rapid_fire": "carbine", "gattling": "carbine", "armor_piercing": "cannon", "infantry_missile": "launch", "explosion": "launch"}

static func weapon_id(kind: String, tier: int) -> String:
	var row: Dictionary = Registry.kind(kind)
	var tiers: Array = row.get("weapon_tiers", [])
	return tiers[tier] if not tiers.is_empty() else row.get("weapon", "")

static func shot_cue(weapon: String) -> String:
	if SHOT_BY_WEAPON.has(weapon): return SHOT_BY_WEAPON[weapon]
	return SHOT_BY_DAMAGE.get(Shared.WEAPONS.get(weapon, {}).get("damage_type", ""), "")

static func death_cue(kind: String, is_building: bool) -> String:
	if is_building: return "building"
	return "infantry_death" if Registry.kind(kind).get("armor", "") == "human" else "vehicle_death"

static func building_sound(kind: String) -> String:
	var row: Dictionary = Registry.kind(kind)
	if row.has("hole"): return "building_small"
	var footprint: Vector2i = row.get("footprint", Vector2i.ONE)
	return "building_large" if footprint.x * footprint.y >= 9 else "building_small"

static func path(sound: String) -> String:
	return "res://audio/sfx/%s.wav" % sound

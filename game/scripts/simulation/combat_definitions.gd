extends RefCounted

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")

const ARMOR := {
	"human": {"small_arms": 100, "armor_piercing": 10},
	"tank": {"small_arms": 25, "armor_piercing": 100},
	"dozer": {"small_arms": 25, "armor_piercing": 100},
	"humvee": {"small_arms": 50, "armor_piercing": 100},
	"structure": {"small_arms": 50, "armor_piercing": 100},
	"chinook": {"small_arms": 50, "armor_piercing": 50},
}

static func profile(kind: String) -> Dictionary:
	match kind:
		"infantry": return {"max_hp": 180000, "armor": "human", "weapon": "rifle"}
		"tank": return {"max_hp": 480000, "armor": "tank", "weapon": "cannon"}
		"builder": return {"max_hp": 250000, "armor": "dozer", "weapon": ""}
		"collector": return {"max_hp": 300000, "armor": "chinook", "weapon": ""}
		"vehicle": return {"max_hp": 240000, "armor": "humvee", "weapon": ""}
		"reactor": return {"max_hp": 800000, "armor": "structure", "weapon": ""}
		"barracks": return {"max_hp": 1000000, "armor": "structure", "weapon": ""}
		"depot", "factory": return {"max_hp": 2000000, "armor": "structure", "weapon": ""}
	return {}

static func weapon(kind: String) -> Dictionary:
	match kind:
		"rifle": return {"damage": 5000, "damage_type": "small_arms", "range": 4.0, "delay_ticks": 4, "clip_size": 3, "reload_ticks": 22, "primary_radius": 0.0, "secondary_radius": 0.0, "secondary_damage": 0, "affects": []}
		"cannon": return {"damage": 60000, "damage_type": "armor_piercing", "range": 6.0, "delay_ticks": 60, "clip_size": 0, "reload_ticks": 0, "primary_radius": 0.2, "secondary_radius": 0.0, "secondary_damage": 0, "affects": ["allies", "enemies", "neutrals"]}
	return {}

# Zero Hour ScatterRadiusVsInfantry 10 and a 12-unit reach, scaled by 25/15 for Wargrid's one-unit-per-cell spacing, less the 7-unit Ranger radius (docs/reference/m6-verification.md, Splash finding).
const SCATTER_VS_INFANTRY: float = 2.0 / 3.0
const INFANTRY_BLAST: float = 0.52

# Source: Zero Hour geometry at 25 units per cell: infantry cylinder r 7, boxes as half-diagonals (docs/reference/m6-verification.md Values table).
static func radius(kind: String) -> float:
	match kind:
		"infantry": return 0.28
		"tank", "builder": return 0.7211102550927978
		"vehicle": return 0.6260990336999411
		"collector": return 0.835224520712844
	var footprint: Vector2i = Definitions.building(kind).footprint
	return 0.5 * sqrt(float(footprint.x * footprint.x + footprint.y * footprint.y))

# Source: Zero Hour AmericaInfantryRanger/AmericaTankCrusader VisionRange 100/150 at 25 units per cell.
static func vision(kind: String) -> float:
	match kind:
		"infantry": return 4.0
		"tank": return 6.0
	return 0.0

static func armor_percent(armor: String, damage_type: String) -> int:
	return ARMOR.get(armor, {}).get(damage_type, 0)

static func initial_combat(kind: String) -> Variant:
	var weapon_kind: String = profile(kind).get("weapon", "")
	if weapon_kind.is_empty(): return null
	return {"mode": "guard", "target_id": null, "goal": null, "next_fire_tick": 0, "shots_left": weapon(weapon_kind).clip_size, "repath_tick": 0, "retarget": false, "until": 0}

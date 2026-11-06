extends RefCounted

const ARMOR := {
	"human": {"small_arms": 100, "armor_piercing": 10},
	"tank": {"small_arms": 25, "armor_piercing": 100},
	"builder_vehicle": {"small_arms": 25, "armor_piercing": 100},
	"light_vehicle": {"small_arms": 50, "armor_piercing": 100},
	"structure": {"small_arms": 50, "armor_piercing": 100},
	"structure_tough": {"small_arms": 50, "armor_piercing": 100},
	"helicopter": {"small_arms": 50, "armor_piercing": 50},
}

const WEAPONS := {
	"rifle": {"damage": 5000, "damage_type": "small_arms", "range": 4.0, "delay_ticks": 4, "clip_size": 3, "reload_ticks": 22, "primary_radius": 0.0, "secondary_radius": 0.0, "secondary_damage": 0, "affects": []},
	"cannon": {"damage": 60000, "damage_type": "armor_piercing", "range": 6.0, "delay_ticks": 60, "clip_size": 0, "reload_ticks": 0, "primary_radius": 0.2, "secondary_radius": 0.0, "secondary_damage": 0, "affects": ["allies", "enemies", "neutrals"]},
}

# Zero Hour ScatterRadiusVsInfantry 10 and a 12-unit reach, scaled by 25/15 for Wargrid's one-unit-per-cell spacing, less the 7-unit Ranger radius (docs/reference/m6-verification.md, Splash finding).
const SCATTER_VS_INFANTRY: float = 2.0 / 3.0
const INFANTRY_BLAST: float = 0.52

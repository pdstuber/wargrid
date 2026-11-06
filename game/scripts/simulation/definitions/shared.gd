extends RefCounted

const ARMOR := {
	"human": {"small_arms": 100, "armor_piercing": 10, "infantry_missile": 10, "explosion": 100, "rapid_fire": 100, "gattling": 100},
	"tank": {"small_arms": 25, "armor_piercing": 100, "infantry_missile": 100, "explosion": 100, "rapid_fire": 25, "gattling": 10},
	"builder_vehicle": {"small_arms": 25, "armor_piercing": 100, "infantry_missile": 100, "explosion": 100, "rapid_fire": 25, "gattling": 10},
	"light_vehicle": {"small_arms": 50, "armor_piercing": 100, "infantry_missile": 50, "explosion": 100, "rapid_fire": 50, "gattling": 50},
	"structure": {"small_arms": 50, "armor_piercing": 100, "infantry_missile": 50, "explosion": 100, "rapid_fire": 50, "gattling": 10},
	"structure_tough": {"small_arms": 50, "armor_piercing": 100, "infantry_missile": 50, "explosion": 80, "rapid_fire": 50, "gattling": 10},
	"helicopter": {"small_arms": 50, "armor_piercing": 50, "infantry_missile": 25, "explosion": 50, "rapid_fire": 50, "gattling": 50},
	"base_defense": {"small_arms": 50, "armor_piercing": 100, "infantry_missile": 25, "explosion": 100, "rapid_fire": 50, "gattling": 25},
}

const WEAPONS := {
	"rifle": {"damage": 5000, "damage_type": "small_arms", "range": 4.0, "delay_ticks": 4, "clip_size": 3, "reload_ticks": 22, "primary_radius": 0.0, "secondary_radius": 0.0, "secondary_damage": 0, "affects": []},
	"cannon": {"damage": 60000, "damage_type": "armor_piercing", "range": 6.0, "delay_ticks": 60, "clip_size": 0, "reload_ticks": 0, "primary_radius": 0.2, "secondary_radius": 0.0, "secondary_damage": 0, "affects": ["allies", "enemies", "neutrals"]},
	"rocket": {"damage": 40000, "damage_type": "infantry_missile", "range": 7.0, "delay_ticks": 30, "clip_size": 0, "reload_ticks": 0, "primary_radius": 0.2, "secondary_radius": 0.0, "secondary_damage": 0, "affects": ["allies", "enemies", "neutrals"]},
	"battery": {"damage": 30000, "damage_type": "explosion", "range": 9.0, "delay_ticks": 8, "clip_size": 4, "reload_ticks": 60, "primary_radius": 0.2, "secondary_radius": 0.0, "secondary_damage": 0, "affects": ["allies", "enemies", "neutrals"]},
	"militia_gun": {"damage": 15000, "damage_type": "small_arms", "range": 4.0, "delay_ticks": 30, "clip_size": 0, "reload_ticks": 0, "primary_radius": 0.0, "secondary_radius": 0.0, "secondary_damage": 0, "affects": []},
	"scout_gun": {"damage": 10000, "damage_type": "rapid_fire", "range": 6.0, "delay_ticks": 6, "clip_size": 0, "reload_ticks": 0, "primary_radius": 0.0, "secondary_radius": 0.0, "secondary_damage": 0, "affects": []},
}

# Zero Hour ScatterRadiusVsInfantry 10 and a 12-unit reach, scaled by 25/15 for Wargrid's one-unit-per-cell spacing, less the 7-unit Ranger radius (docs/reference/m6-verification.md, Splash finding).
const SCATTER_VS_INFANTRY: float = 2.0 / 3.0
const INFANTRY_BLAST: float = 0.52

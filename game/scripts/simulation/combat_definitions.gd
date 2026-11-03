extends RefCounted

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
		"rifle": return {"damage": 5000, "damage_type": "small_arms", "range": 4.0, "delay_ticks": 3, "clip_size": 3, "reload_ticks": 21}
		"cannon": return {"damage": 60000, "damage_type": "armor_piercing", "range": 6.0, "delay_ticks": 60, "clip_size": 0, "reload_ticks": 0}
	return {}

static func armor_percent(armor: String, damage_type: String) -> int:
	return ARMOR.get(armor, {}).get(damage_type, 0)

static func initial_combat(kind: String) -> Variant:
	var weapon_kind: String = profile(kind).get("weapon", "")
	if weapon_kind.is_empty(): return null
	return {"mode": "guard", "target_id": null, "goal": null, "next_fire_tick": 0, "shots_left": weapon(weapon_kind).clip_size, "repath_tick": 0}

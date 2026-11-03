extends SceneTree

const Economy = preload("res://scripts/simulation/economy_definitions.gd")
const Combat = preload("res://scripts/simulation/combat_definitions.gd")

func _initialize() -> void:
	var out := {"weapons": {}, "armor": {}}
	for kind in ["infantry", "tank", "builder", "vehicle", "collector", "barracks", "reactor", "depot", "factory"]:
		var record: Dictionary = Economy.unit(kind)
		if record.is_empty(): record = Economy.building(kind)
		var profile: Dictionary = Combat.profile(kind)
		out[kind] = {"cost": record.cost, "ticks": record.ticks, "max_hp": profile.max_hp, "armor": profile.armor}
		if record.has("speed"):
			out[kind].speed = record.speed
			out[kind].weapon = profile.weapon
		else:
			out[kind].power = record.power
	for name in ["rifle", "cannon"]: out.weapons[name] = Combat.weapon(name)
	for armor in ["human", "tank", "dozer", "humvee", "structure", "chinook"]:
		out.armor[armor] = {"small_arms": Combat.armor_percent(armor, "small_arms"), "armor_piercing": Combat.armor_percent(armor, "armor_piercing")}
	print("WARGRID_DEFINITIONS ", JSON.stringify(out))
	quit(0)

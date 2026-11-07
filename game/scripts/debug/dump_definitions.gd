extends SceneTree

const Economy = preload("res://scripts/simulation/economy_definitions.gd")
const Combat = preload("res://scripts/simulation/combat_definitions.gd")

func _initialize() -> void:
	var out := {"weapons": {}, "armor": {}}
	for kind: String in ["usa_rifle_infantry", "usa_tank", "usa_builder", "usa_light_vehicle", "usa_collector", "usa_barracks", "usa_power_plant", "usa_supply_center", "usa_factory"]:
		var record: Dictionary = Economy.unit(kind)
		if record.is_empty(): record = Economy.building(kind)
		var profile: Dictionary = Combat.profile(kind)
		out[kind] = {"cost": record.cost, "ticks": record.ticks, "max_hp": profile.max_hp, "armor": profile.armor}
		if record.has("speed"):
			out[kind].speed = record.speed
			out[kind].weapon = profile.weapon
		else:
			out[kind].power = record.power
	for name: String in ["rifle", "cannon", "scout_gun"]: out.weapons[name] = Combat.weapon(name)
	for armor: String in ["human", "tank", "builder_vehicle", "light_vehicle", "structure", "helicopter"]:
		out.armor[armor] = {"small_arms": Combat.armor_percent(armor, "small_arms"), "armor_piercing": Combat.armor_percent(armor, "armor_piercing")}
	print("WARGRID_DEFINITIONS ", JSON.stringify(out))
	quit(0)

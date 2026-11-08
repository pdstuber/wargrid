extends RefCounted

const DEFAULT_FACTION := "usa"
const DEFAULT_SKIRMISH := {1: "usa", 2: "usa"}

const FACTIONS := {
	"usa": {
		"display_name": "United States",
		"start_building": "usa_command_center",
		"start_unit": "usa_builder",
		"build_order": ["usa_power_plant", "usa_supply_center", "usa_barracks", "usa_factory"],
		"bot_collectors_per_supply_center": 2,
		"units_for": {"usa_barracks": ["usa_rifle_infantry", "usa_rocket_infantry"], "usa_factory": ["usa_tank", "usa_light_vehicle"]},
	},
	"china": {
		"display_name": "China",
		"start_building": "china_command_center",
		"start_unit": "china_builder",
		"build_order": ["china_power_plant", "china_supply_center", "china_barracks", "china_factory"],
		"bot_collectors_per_supply_center": 3,
		"units_for": {"china_barracks": ["china_rifle_infantry", "china_rocket_infantry"], "china_factory": ["china_tank", "china_light_vehicle"]},
	},
	"frc": {
		"display_name": "Free Resistance Coalition",
		"start_building": "frc_command_center",
		"start_unit": "frc_builder",
		"build_order": ["frc_supply_center", "frc_barracks", "frc_factory", "frc_defence"],
		"bot_collectors_per_supply_center": 5,
		"units_for": {"frc_barracks": ["frc_rifle_infantry", "frc_rocket_infantry"], "frc_factory": ["frc_tank", "frc_light_vehicle"]},
	},
}

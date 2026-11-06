extends RefCounted

const DEFAULT_FACTION := "usa"
const DEFAULT_SKIRMISH := {1: "usa", 2: "usa"}

const FACTIONS := {
	"usa": {
		"display_name": "United States",
		"start_building": "usa_command_center",
		"start_unit": "usa_builder",
		"build_order": ["usa_power_plant", "usa_supply_center", "usa_barracks", "usa_factory"],
		"units_for": {"usa_barracks": ["usa_rifle_infantry", "usa_rocket_infantry"], "usa_factory": ["usa_tank", "usa_light_vehicle"]},
	},
	"china": {
		"display_name": "China",
		"start_building": "china_command_center",
		"start_unit": "china_builder",
		"build_order": ["china_power_plant", "china_supply_center", "china_barracks", "china_factory"],
		"units_for": {"china_barracks": ["china_rifle_infantry", "china_rocket_infantry"], "china_factory": ["china_tank", "china_light_vehicle"]},
	},
}

extends RefCounted

const DEFAULT_FACTION := "usa"
const DEFAULT_SKIRMISH := {1: "usa", 2: "usa"}

const FACTIONS := {
	"usa": {
		"display_name": "United States",
		"start_building": "",
		"start_unit": "usa_builder",
		"build_order": ["usa_power_plant", "usa_supply_center", "usa_barracks", "usa_factory"],
		"units_for": {"usa_barracks": ["usa_rifle_infantry"], "usa_factory": ["usa_tank"]},
	},
}

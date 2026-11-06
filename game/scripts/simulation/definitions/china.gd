extends RefCounted

# Zero Hour China rows at Wargrid scale; INI sources in docs/reference/m7-factions.md.
const KINDS := {
	"china_collector": {"display_name": "Supply Truck", "class": "vehicle", "cost": 600, "ticks": 300, "speed": 1.6, "accel": 9.6, "brake": 2.0, "locomotor": "wheels", "min_turn_speed": 0.6, "turn_cos": 0.9986295347545738, "turn_sin": 0.052335956242943835, "max_hp": 300000, "armor": "light_vehicle", "weapon": "", "radius": 0.73539105, "collects": {"boxes": 4, "load_ticks": 30, "unload_ticks": 12, "box_value": 75}},
	"china_power_plant": {"display_name": "Nuclear Reactor", "cost": 1000, "ticks": 300, "power": 10, "footprint": Vector2i(2, 2), "prerequisite": "", "max_hp": 1500000, "armor": "structure", "weapon": "", "produces": [], "receives_supply": false, "counts_for_victory": true, "icon": "power", "slot": "power_plant", "spawns_on_complete": []},
	"china_supply_center": {"display_name": "Supply Center", "cost": 1500, "ticks": 300, "power": -1, "footprint": Vector2i(3, 3), "prerequisite": "china_power_plant", "max_hp": 2000000, "armor": "structure", "weapon": "", "produces": ["china_collector"], "receives_supply": true, "counts_for_victory": true, "icon": "supply", "slot": "supply_center", "spawns_on_complete": ["china_collector"]},
}

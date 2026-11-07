@warning_ignore_start("untyped_declaration")
extends RefCounted

const MapData = preload("res://scripts/simulation/map_data.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")

func cases() -> Array[Callable]:
	return [test_maps_load, test_converted_maps_load, test_bad_map_rejected, test_skirmish_identical, test_exports_ship_map_notice]

func test_maps_load(runner) -> bool:
	var skirmish := MapData.load("res://data/maps/skirmish.json")
	var ashfall := MapData.load("res://data/maps/ashfall.json")
	runner.check(Vector2i(int(skirmish.size[0]), int(skirmish.size[1])) == Vector2i(48, 32) and Vector2i(int(ashfall.size[0]), int(ashfall.size[1])) == Vector2i(194, 187), "MP1 map sizes")
	runner.check(MapData.slot(skirmish, 1, "usa_factory") == Vector2i(12, 18) and MapData.slot(skirmish, 2, "usa_power_plant") == Vector2i(38, 12) and MapData.slot(skirmish, 2, "usa_supply_center") == Vector2i(37, 5) and MapData.slot(skirmish, 2, "usa_barracks") == Vector2i(34, 12) and MapData.slot(skirmish, 2, "usa_factory") == Vector2i(33, 18), "MP1 skirmish slots equal today's origins")
	runner.check(ashfall.starts.size() == 8 and ashfall.sources.size() == 12, "MP1 Ashfall starts and sources")
	return true

func test_converted_maps_load(runner) -> bool:
	var expected := {"dry_wells": ["Dry Wells", Vector2i(81, 108), 2, 4], "broken_crown": ["Broken Crown", Vector2i(112, 100), 4, 8]}
	for file: String in expected:
		var map := MapData.load("res://data/maps/%s.json" % file)
		var want: Array = expected[file]
		runner.check(map.name == want[0] and Vector2i(int(map.size[0]), int(map.size[1])) == want[1] and map.starts.size() == want[2] and map.sources.size() == want[3], "MP6 %s size, starts and sources" % file)
		var seats: Array[Dictionary] = []
		for start: Dictionary in map.starts: seats.append({"seat": int(start.seat), "credits": 0, "controller": "ai", "faction": ["usa", "china", "frc"][seats.size() % 3]})
		var state: Dictionary = MapData.create(map, seats).snapshot()
		runner.check(state.entities.size() == want[2] and state.buildings.size() == want[2] and state.sources.size() == want[3], "MP6 %s seats every faction with its start building, start unit and sources" % file)
	return true

func test_bad_map_rejected(runner) -> bool:
	var text := FileAccess.get_file_as_string("res://data/maps/skirmish.json")
	var map: Dictionary = JSON.parse_string(text)
	runner.check(not MapData.parse(text).is_empty(), "MP2 good map parses")
	map.cells[18] = ".".repeat(12) + "#" + ".".repeat(35)
	runner.check(MapData.parse(JSON.stringify(map)).is_empty(), "MP2 slot on a cliff cell is rejected")
	map = JSON.parse_string(text)
	map.cells[3] = ".....#" + ".".repeat(42)
	runner.check(MapData.parse(JSON.stringify(map)).is_empty(), "MP2 source on a cliff cell is rejected")
	return true

func test_skirmish_identical(runner) -> bool:
	var sim = Skirmish.create()
	var state: Dictionary = sim.snapshot()
	runner.check(sim.map_data().name == "Skirmish" and state.entities.size() == 2 and state.entities[0].id == 1 and state.entities[1].id == 3, "MP3 builders then sources keep ids")
	runner.check(Skirmish.create(false, "human").map_data().starts.size() == 2, "MP3 second controller reaches the sim")
	return true

func test_exports_ship_map_notice(runner) -> bool:
	runner.check(FileAccess.file_exists("res://data/maps/NOTICE.md"), "MP5 EA's map notice is in the project or pack")
	if not FileAccess.file_exists("res://export_presets.cfg"): return true # exported packs omit the presets; the project run checks them
	var config := ConfigFile.new()
	runner.check(config.load("res://export_presets.cfg") == OK, "MP5 export presets load")
	var presets: int = 0
	for section in config.get_sections():
		if section.ends_with(".options"): continue
		presets += 1
		runner.check("data/maps/NOTICE.md" in str(config.get_value(section, "include_filter", "")), "MP5 %s ships EA's map notice" % config.get_value(section, "name", section))
	runner.check(presets == 10, "MP5 ten presets checked")
	return true

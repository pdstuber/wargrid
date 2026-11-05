extends RefCounted

const MapData = preload("res://scripts/simulation/map_data.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")

func cases() -> Array[Callable]:
	return [test_maps_load, test_bad_map_rejected, test_skirmish_identical]

func test_maps_load(runner) -> bool:
	var skirmish := MapData.load("res://data/maps/skirmish.json")
	var ashfall := MapData.load("res://data/maps/ashfall.json")
	runner.check(Vector2i(int(skirmish.size[0]), int(skirmish.size[1])) == Vector2i(48, 32) and Vector2i(int(ashfall.size[0]), int(ashfall.size[1])) == Vector2i(194, 187), "MP1 map sizes")
	runner.check(MapData.slot(skirmish, 1, "factory") == Vector2i(12, 18) and MapData.slot(skirmish, 2, "reactor") == Vector2i(38, 12) and MapData.slot(skirmish, 2, "depot") == Vector2i(37, 5) and MapData.slot(skirmish, 2, "barracks") == Vector2i(34, 12) and MapData.slot(skirmish, 2, "factory") == Vector2i(33, 18), "MP1 skirmish slots equal today's origins")
	runner.check(ashfall.starts.size() == 8 and ashfall.sources.size() == 12, "MP1 Ashfall starts and sources")
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
	runner.check(sim.map_data().name == "Skirmish" and state.entities.size() == 2 and state.entities[0].id == 1 and state.entities[1].id == 2, "MP3 builders then sources keep ids")
	runner.check(Skirmish.create(false, "human").map_data().starts.size() == 2, "MP3 second controller reaches the sim")
	return true

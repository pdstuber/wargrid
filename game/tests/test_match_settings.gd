@warning_ignore_start("untyped_declaration")
extends RefCounted

const MatchSettings = preload("res://scripts/match_settings.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const StartSpots = preload("res://scripts/simulation/start_spots.gd")

func cases() -> Array[Callable]:
	return [test_names, test_line_endings, test_refusals, test_test_map, test_seeded_starts]

func test_names(runner) -> bool:
	for id: String in MatchSettings.PLAY_MAPS:
		runner.check(MatchSettings.PLAY_MAPS[id] == MapData.load(MatchSettings.map_path(id)).name, "MS1 display name of %s matches the map file" % id)
	return true

func test_line_endings(runner) -> bool:
	var original: String = MatchSettings.map_path("dry_wells")
	var copy := "user://ms2_crlf-%d.json" % OS.get_process_id()
	var file := FileAccess.open(copy, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(original).replace("\n", "\r\n"))
	file.close()
	runner.check(MatchSettings.map_hash(copy) == MatchSettings.map_hash(original), "MS2 line endings do not change the hash")
	DirAccess.remove_absolute(copy)
	return true

func test_refusals(runner) -> bool:
	var missing := "The host's map is not in your build"
	for bad: Dictionary in [{}, {"map": 5}, {"map": "../project"}, {"map": "nope"}, {"map": "../maps/ashfall", "map_hash": MatchSettings.map_hash(MatchSettings.map_path("ashfall"))}, {"map": "../../../protocol/vectors/hello", "map_hash": "0"}, {"map": "ASHFALL", "map_hash": MatchSettings.map_hash(MatchSettings.map_path("ashfall"))}]:
		runner.check(MatchSettings.refusal(bad) == missing, "MS3 an unknown map id is refused: %s" % str(bad))
	for bad: Dictionary in [{"map": "ashfall"}, {"map": "ashfall", "map_hash": "0"}]:
		runner.check(MatchSettings.refusal(bad) == "Your copy of Ashfall differs from the host's", "MS3 a different map file is refused: %s" % str(bad))
	for id: String in ["dry_wells", "broken_crown", "ashfall", "skirmish"]:
		runner.check(MatchSettings.refusal(MatchSettings.for_map(id)).is_empty(), "MS3 own settings for %s are accepted" % id)
	return true

func test_test_map(runner) -> bool:
	runner.check(MatchSettings.starts("skirmish", 9).is_empty(), "MS4 the test map keeps its seats")
	return true

func test_seeded_starts(runner) -> bool:
	var map: Dictionary = MapData.load(MatchSettings.map_path("ashfall"))
	for s in 4:
		var got: Array[int] = MatchSettings.starts("ashfall", s)
		runner.check(got.size() == 2 and got == StartSpots.assign(map, s, [1, 2], [0, 0]), "MS5 a play map gets seeded starts for seed %d" % s)
	return true

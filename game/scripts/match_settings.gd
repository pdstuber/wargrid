extends RefCounted

const MapData = preload("res://scripts/simulation/map_data.gd")
const StartSpots = preload("res://scripts/simulation/start_spots.gd")

const PLAY_MAPS := {"dry_wells": "Dry Wells", "broken_crown": "Broken Crown", "ashfall": "Ashfall"}
const TEST_MAP := "skirmish"
const NOT_IN_BUILD := "The host's map is not in your build"

static func map_path(id: String) -> String:
	return "res://data/maps/%s.json" % id

static func map_hash(path: String) -> String:
	# No .gitattributes, so a CRLF checkout must not make the hashes differ.
	return FileAccess.get_file_as_string(path).replace("\r", "").sha256_text()

static func for_map(id: String) -> Dictionary:
	return {"map": id, "map_hash": map_hash(map_path(id))}

static func refusal(settings: Dictionary) -> String:
	var id: Variant = settings.get("map")
	if not id is String or not _valid_id(id) or not FileAccess.file_exists(map_path(id)): return NOT_IN_BUILD
	var theirs: Variant = settings.get("map_hash")
	if not theirs is String or theirs != map_hash(map_path(id)): return "Your copy of %s differs from the host's" % PLAY_MAPS.get(id, id)
	return ""

static func starts(id: String, match_seed: int) -> Array[int]:
	# The test map keeps seat N on start N so pinned traces hold.
	if id == TEST_MAP: return []
	return StartSpots.assign(MapData.load(map_path(id)), match_seed, [1, 2], [0, 0])

static func _valid_id(id: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-z0-9_]{1,32}$")
	return pattern.search(id) != null

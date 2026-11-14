extends RefCounted

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const SECTION := "launcher"

static func load_picks() -> Dictionary:
	var config := ConfigFile.new()
	config.load(AudioSettings.path)
	var default_map: String = MatchSettings.PLAY_MAPS.keys()[0]
	return {
		"faction": _valid(config, "faction", Registry.Factions.FACTIONS, Registry.Factions.DEFAULT_FACTION),
		"bot_faction": _valid(config, "bot_faction", Registry.Factions.FACTIONS, Registry.Factions.DEFAULT_FACTION),
		"map": _valid(config, "map", MatchSettings.PLAY_MAPS, default_map),
	}

static func save_picks(picks: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(AudioSettings.path)
	for key: String in picks: config.set_value(SECTION, key, picks[key])
	config.save(AudioSettings.path)

static func fullscreen() -> bool:
	var config := ConfigFile.new()
	config.load(AudioSettings.path)
	var stored: Variant = config.get_value(SECTION, "fullscreen", false)
	return stored if stored is bool else false

static func save_fullscreen(on: bool) -> void:
	save_picks({"fullscreen": on})

static func _valid(config: ConfigFile, key: String, ids: Dictionary, fallback: String) -> String:
	var stored: Variant = config.get_value(SECTION, key, fallback)
	return stored if stored is String and ids.has(stored) else fallback

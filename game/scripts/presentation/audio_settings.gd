extends RefCounted

const DEFAULTS := {"music": 1.0, "effects": 1.0, "voice": 1.0}
const BUSES := {"music": "Music", "effects": "Effects", "voice": "Voice"}
const SECTION := "audio"
static var path := "user://settings.cfg"

static func load_volumes() -> Dictionary:
	var config := ConfigFile.new()
	var loaded: bool = config.load(path) == OK
	var volumes: Dictionary = {}
	for key: String in DEFAULTS:
		var value: Variant = config.get_value(SECTION, key, DEFAULTS[key]) if loaded else DEFAULTS[key]
		volumes[key] = clampf(value, 0.0, 1.0) if value is float or value is int else DEFAULTS[key]
	return volumes

static func save_volumes(volumes: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(path)
	for key: String in DEFAULTS: config.set_value(SECTION, key, volumes[key])
	config.save(path)

static func apply(volumes: Dictionary) -> void:
	for key: String in BUSES:
		var index: int = AudioServer.get_bus_index(BUSES[key])
		AudioServer.set_bus_mute(index, volumes[key] == 0.0)
		if volumes[key] > 0.0: AudioServer.set_bus_volume_db(index, linear_to_db(volumes[key]))

extends RefCounted

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const COMMIT_PATH := "res://build_commit.txt"
const SECTION := "playtest"

static func enabled(version: String = str(ProjectSettings.get_setting("application/config/version"))) -> bool:
	var config := ConfigFile.new()
	var stored: Variant = config.get_value(SECTION, "enabled") if config.load(AudioSettings.path) == OK and config.has_section_key(SECTION, "enabled") else null
	return stored if stored is bool else version.ends_with("-dev")

static func save_enabled(on: bool) -> void:
	var config := ConfigFile.new()
	config.load(AudioSettings.path)
	config.set_value(SECTION, "enabled", on)
	config.save(AudioSettings.path)

static func build_id(version: String = str(ProjectSettings.get_setting("application/config/version")), commit_path: String = COMMIT_PATH) -> String:
	var commit: String = FileAccess.get_file_as_string(commit_path).strip_edges() if FileAccess.file_exists(commit_path) else ""
	return "%s+%s" % [version, commit if not commit.is_empty() else "unknown"]

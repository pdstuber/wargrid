extends RefCounted

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const LOW := 0
const HIGH := 1
const AUTO_LOW_P95_MS := 8.3
const FLAG_SHADOWS := 1
const SECTION := "graphics"

static func load_quality() -> int:
	var config := ConfigFile.new()
	if config.load(AudioSettings.path) != OK: return -1
	var value: Variant = config.get_value(SECTION, "quality", -1)
	return value if value is int and (value == LOW or value == HIGH) else -1

static func save_quality(quality: int) -> void:
	var config := ConfigFile.new()
	config.load(AudioSettings.path)
	config.set_value(SECTION, "quality", quality)
	config.save(AudioSettings.path)

static func pick(frame_p95_ms: float) -> int:
	return LOW if frame_p95_ms > AUTO_LOW_P95_MS else HIGH

static func flags(quality: int) -> int:
	return FLAG_SHADOWS if quality == HIGH else 0

static func detail(quality: int, zoom: float) -> int:
	if quality != HIGH: return 0
	return 0 if zoom < 1.0 else (1 if zoom < 2.0 else 2)

extends RefCounted

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const LOW := 0
const HIGH := 1
const AUTO_LOW_P95_MS := 8.3
const SECTION := "graphics"

static func _read(key: String, fallback: Variant) -> Variant:
	var config := ConfigFile.new()
	if config.load(AudioSettings.path) != OK: return fallback
	return config.get_value(SECTION, key, fallback)

static func _write(key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(AudioSettings.path)
	config.set_value(SECTION, key, value)
	config.save(AudioSettings.path)

static func load_quality() -> int:
	var value: Variant = _read("quality", -1)
	return value if value is int and (value == LOW or value == HIGH) else -1

static func save_quality(quality: int) -> void:
	_write("quality", quality)

static func stored_quality() -> int:
	var stored: int = load_quality()
	return stored if stored != -1 else HIGH

static func pick(frame_p95_ms: float) -> int:
	return LOW if frame_p95_ms > AUTO_LOW_P95_MS else HIGH

static func detail(quality: int, zoom: float) -> int:
	if quality != HIGH: return 0
	return 0 if zoom < 1.0 else (1 if zoom < 2.0 else 2)

static func load_neon() -> bool:
	var value: Variant = _read("neon", false)
	return value is bool and value

static func save_neon(neon: bool) -> void:
	_write("neon", neon)

static func load_destinations() -> bool:
	var value: Variant = _read("destinations", false)
	return value is bool and value

static func save_destinations(on: bool) -> void:
	_write("destinations", on)

static func load_smooth() -> bool:
	var value: Variant = _read("smooth", -1)
	return value if value is bool else stored_quality() == HIGH

static func save_smooth(smooth: bool) -> void:
	_write("smooth", smooth)

@warning_ignore_start("untyped_declaration")
extends RefCounted

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const VolumeSliders = preload("res://scripts/presentation/volume_sliders.gd")
const MusicPlayer = preload("res://scripts/presentation/music_player.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const Launcher = preload("res://scenes/launcher.tscn")
const Skirmish = preload("res://scenes/skirmish.tscn")
const REAL := "user://settings.cfg"
var scratch: String = "user://test-settings-%d.cfg" % OS.get_process_id() # shards and worktrees share user://

func cases() -> Array[Callable]:
	return [test_settings_missing_and_corrupt, test_settings_round_trip, test_slider_sets_bus_and_saves, test_bus_levels, test_tests_use_scratch_settings, test_playlist_order_and_gap, test_menu_track_repeats, test_match_playlist_is_shuffled, test_scene_plays_a_shuffled_playlist, test_mute_toggle, test_mute_key_in_match, test_mute_key_in_launcher_and_text_field]

func _begin() -> String:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	return saved

func _end(saved: String) -> void:
	DirAccess.remove_absolute(scratch)
	AudioSettings.path = saved
	AudioSettings.apply(AudioSettings.DEFAULTS)
	AudioServer.set_bus_mute(0, false)

func _write(values: Dictionary) -> void:
	var config := ConfigFile.new()
	for key: String in values: config.set_value(AudioSettings.SECTION, key, values[key])
	config.save(scratch)

func test_settings_missing_and_corrupt(runner) -> bool:
	var saved := _begin()
	var volumes: Dictionary = AudioSettings.load_volumes()
	runner.check(volumes.music == 1.0 and volumes.effects == 1.0 and volumes.voice == 1.0, "AS1 music default 1.0, got %s" % [volumes])
	_write({"music": "loud", "voice": 3.0, "effects": -1.0})
	volumes = AudioSettings.load_volumes()
	runner.check(volumes.music == 1.0, "AS1 non-number gives 1.0, got %s" % volumes.music)
	runner.check(volumes.voice == 1.0, "AS1 3.0 clamps to 1.0, got %s" % volumes.voice)
	runner.check(volumes.effects == 0.0, "AS1 -1.0 clamps to 0.0, got %s" % volumes.effects)
	_end(saved)
	return true

func test_settings_round_trip(runner) -> bool:
	var saved := _begin()
	var config := ConfigFile.new()
	config.set_value("audio", "other", 7)
	config.set_value("video", "scale", 2)
	config.save(scratch)
	AudioSettings.save_volumes({"music": 0.25, "effects": 0.5, "voice": 0.75})
	var volumes: Dictionary = AudioSettings.load_volumes()
	runner.check(volumes.music == 0.25 and volumes.effects == 0.5 and volumes.voice == 0.75, "AS2 volumes load back, got %s" % [volumes])
	config = ConfigFile.new()
	config.load(scratch)
	runner.check(config.get_value("audio", "other", 0) == 7 and config.get_value("video", "scale", 0) == 2, "AS2 unrelated keys and sections survive")
	_end(saved)
	return true

func test_slider_sets_bus_and_saves(runner) -> bool:
	var saved := _begin()
	var sliders := VolumeSliders.new()
	runner.root.add_child(sliders)
	runner.check(not FileAccess.file_exists(scratch), "AS3 constructing sliders writes nothing")
	var index: int = AudioServer.get_bus_index("Music")
	sliders.get_node("Music").value = 0.5
	runner.check(absf(AudioServer.get_bus_volume_db(index) - linear_to_db(0.5)) < 0.01, "AS3 Music 0.5 sets the bus, got %s" % AudioServer.get_bus_volume_db(index))
	runner.check(AudioSettings.load_volumes().music == 0.5, "AS3 slider change is saved")
	sliders.get_node("Music").value = 0.0
	runner.check(AudioServer.is_bus_mute(index), "AS3 0 mutes the bus")
	sliders.free()
	_end(saved)
	return true

func test_bus_levels(runner) -> bool:
	var effects: int = AudioServer.get_bus_index("Effects")
	AudioSettings.apply({"music": 1.0, "effects": 1.0, "voice": 1.0})
	runner.check(absf(AudioServer.get_bus_volume_db(effects) + 6.0) < 0.01, "AS3b Effects 1.0 is -6 dB, got %s" % AudioServer.get_bus_volume_db(effects))
	runner.check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))) < 0.01, "AS3b Music 1.0 stays 0 dB")
	runner.check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Voice"))) < 0.01, "AS3b Voice 1.0 stays 0 dB")
	AudioSettings.apply({"music": 1.0, "effects": 0.5, "voice": 1.0})
	runner.check(absf(AudioServer.get_bus_volume_db(effects) - (linear_to_db(0.5) - 6.0)) < 0.01, "AS3b Effects 0.5 is -12.02 dB, got %s" % AudioServer.get_bus_volume_db(effects))
	AudioSettings.apply({"music": 1.0, "effects": 0.0, "voice": 1.0})
	runner.check(AudioServer.is_bus_mute(effects), "AS3b Effects 0 mutes")
	AudioSettings.apply(AudioSettings.DEFAULTS)
	return true

func test_tests_use_scratch_settings(runner) -> bool:
	var before: int = FileAccess.get_modified_time(REAL) if FileAccess.file_exists(REAL) else 0
	runner.check(AudioSettings.path != REAL, "AS4 the suite redirects the settings path, got %s" % AudioSettings.path)
	var sliders := VolumeSliders.new()
	runner.root.add_child(sliders)
	sliders.get_node("Music").value = 0.4
	var after: int = FileAccess.get_modified_time(REAL) if FileAccess.file_exists(REAL) else 0
	runner.check(before == after, "AS4 real settings file untouched (%d to %d)" % [before, after])
	runner.check(FileAccess.file_exists(AudioSettings.path), "AS4 slider change landed in the redirected file")
	DirAccess.remove_absolute(AudioSettings.path)
	AudioSettings.apply(AudioSettings.DEFAULTS)
	sliders.free()
	return true

func test_playlist_order_and_gap(runner) -> bool:
	var player := MusicPlayer.new()
	player.play_list(MusicPlayer.PLAYLIST, MusicPlayer.GAP_SECONDS)
	runner.check(player.track_index() == 0 and not player.waiting(), "AS5 starts on track 0")
	player.finished.emit()
	runner.check(player.waiting(), "AS5 waits after finished")
	player.advance(24.9)
	runner.check(player.waiting() and player.track_index() == 0, "AS5 still waiting at 24.9 s")
	player.advance(0.2)
	runner.check(player.track_index() == 1 and not player.waiting(), "AS5 next track after 25 s, got %d" % player.track_index())
	for i in 4:
		player.finished.emit()
		player.advance(25.0)
	runner.check(player.track_index() == 0, "AS5 wraps after the fifth track, got %d" % player.track_index())
	player.free()
	return true

func test_menu_track_repeats(runner) -> bool:
	var player := MusicPlayer.new()
	player.play_list([MusicPlayer.MENU], 0.0)
	player.finished.emit()
	player.advance(0.0)
	runner.check(player.track_index() == 0 and not player.waiting(), "AS6 menu track repeats at once")
	player.free()
	return true

func _shuffled_with(seed_value: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return MusicPlayer.shuffled(MusicPlayer.PLAYLIST, rng)

func _sorted(paths: Array[String]) -> Array[String]:
	var copy := paths.duplicate()
	copy.sort()
	return copy

func test_match_playlist_is_shuffled(runner) -> bool:
	var first := _shuffled_with(1)
	runner.check(first.size() == 5 and _sorted(first) == _sorted(MusicPlayer.PLAYLIST), "MU1 the shuffle keeps the same five tracks, got %s" % [first])
	runner.check(first == _shuffled_with(1), "MU1 one seed gives one order")
	runner.check(first != _shuffled_with(2), "MU1 seeds 1 and 2 give different orders")
	var literal: Array[String] = ["res://audio/music/conflict.ogg", "res://audio/music/enemy_spotted.ogg", "res://audio/music/mammoth.ogg", "res://audio/music/stay_the_course.ogg", "res://audio/music/hitman.ogg"]
	runner.check(MusicPlayer.PLAYLIST == literal, "MU1 PLAYLIST keeps its source order")
	return true

func _music_of(scene: Node) -> Node:
	for child in scene.get_children():
		if child.get_script() == MusicPlayer: return child
	return null

func _match_music(runner) -> Array:
	var main = Skirmish.instantiate()
	runner.root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	await runner.process_frame
	return [main, _music_of(main)]

func test_scene_plays_a_shuffled_playlist(runner) -> bool:
	var orders: Array = []
	for i in 6:
		var started: Array = await _match_music(runner)
		if started[1] != null and not orders.has(started[1]._paths): orders.append(started[1]._paths.duplicate())
		started[0].free()
	runner.check(orders.size() >= 2, "MU2 six matches play at least two different orders, got %d" % orders.size())
	var started: Array = await _match_music(runner)
	var main = started[0]
	var music = started[1]
	runner.check(music != null and _sorted(music._paths) == _sorted(MusicPlayer.PLAYLIST), "MU2 the match plays the five tracks")
	music.finished.emit()
	music.advance(MusicPlayer.GAP_SECONDS)
	var before: Array[String] = music._paths.duplicate()
	runner.check(music.track_index() == 1 and music.stream.resource_path == before[1], "MU2 fixture: the match is on track 1")
	main._restart()
	runner.check(music._paths == before and music.track_index() == 1 and not music.waiting() and music.stream.resource_path == before[1], "MU2 Restart keeps the running track and playlist")
	main.free()
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var menu = _music_of(launcher)
	runner.check(menu != null and menu._paths == [MusicPlayer.MENU], "MU2 the launcher plays the menu track only")
	launcher.free()
	return true

func test_mute_toggle(runner) -> bool:
	var saved := _begin()
	var sliders := VolumeSliders.new()
	var mute: Button = sliders.get_node("Mute")
	mute.button_pressed = true
	runner.check(AudioServer.is_bus_mute(0), "AS7 Mute button mutes Master")
	mute.button_pressed = false
	runner.check(not AudioServer.is_bus_mute(0), "AS7 second toggle restores Master")
	runner.check(not FileAccess.file_exists(scratch), "AS7 mute is not saved")
	runner.check(AudioSettings.load_volumes().music == 1.0 and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "AS7 slider values untouched")
	sliders.free()
	_end(saved)
	return true

func _key(code: Key, unicode: int = 0) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.unicode = unicode
	event.pressed = true
	return event

func test_mute_key_in_match(runner) -> bool:
	var main = Skirmish.instantiate()
	runner.root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	await runner.process_frame
	runner.root.push_input(_key(KEY_M, 109))
	runner.check(AudioServer.is_bus_mute(0), "AS8 M mutes Master in a match")
	runner.root.push_input(_key(KEY_M, 109))
	runner.check(not AudioServer.is_bus_mute(0), "AS8 M again restores Master")
	AudioServer.set_bus_mute(0, false)
	main.free()
	return true

func test_mute_key_in_launcher_and_text_field(runner) -> bool:
	var launcher = Launcher.instantiate()
	launcher.prerelease = true
	runner.root.add_child(launcher)
	await runner.process_frame
	await runner.process_frame
	runner.root.push_input(_key(KEY_M, 109))
	runner.check(AudioServer.is_bus_mute(0), "AS9 M mutes Master in the launcher")
	runner.root.push_input(_key(KEY_M, 109))
	launcher.get_node("Center/Box/Advanced").button_pressed = true
	var field: LineEdit = launcher.find_child("RelayUrl", true, false)
	field.grab_focus()
	var before: String = field.text
	runner.root.push_input(_key(KEY_M, 109))
	runner.check(field.has_focus() and field.text != before, "AS9 fixture: the focused field took the letter")
	runner.check(not AudioServer.is_bus_mute(0), "AS9 M typed into a text field does not mute")
	AudioServer.set_bus_mute(0, false)
	launcher.free()
	return true

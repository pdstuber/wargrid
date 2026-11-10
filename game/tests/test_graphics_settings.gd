@warning_ignore_start("untyped_declaration")
extends RefCounted

const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const Skirmish = preload("res://scenes/skirmish.tscn")
var scratch: String = "user://test-graphics-%d.cfg" % OS.get_process_id()

func cases() -> Array[Callable]:
	return [test_detail_by_zoom, test_pick_threshold, test_settings_round_trip_keeps_audio, test_corrupt_file_gives_unset, test_auto_pick_skipped_headless, test_menu_toggle_saves_and_emits, test_view_follows_quality_and_zoom, test_auto_pick_ignores_cold_frames, test_menu_label_follows_stored_quality, test_auto_pick_samples_tick_and_draw_time, test_neon_setting, test_neon_menu_and_wiring]

func _begin() -> String:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	return saved

func _end(saved: String) -> void:
	DirAccess.remove_absolute(scratch)
	AudioSettings.path = saved

func test_detail_by_zoom(runner) -> bool:
	runner.check(GraphicsSettings.detail(GraphicsSettings.LOW, 2.0) == 0, "Q2 Low stays at detail 0 when zoomed in")
	var got: Array = [0.5, 1.0, 2.0].map(func(zoom: float) -> int: return GraphicsSettings.detail(GraphicsSettings.HIGH, zoom))
	runner.check(got == [0, 1, 2], "Q2 High detail by zoom, got " + str(got))
	return true

func test_pick_threshold(runner) -> bool:
	runner.check(GraphicsSettings.pick(8.3) == GraphicsSettings.HIGH, "Q3 8.3 ms keeps High")
	runner.check(GraphicsSettings.pick(8.31) == GraphicsSettings.LOW, "Q3 8.31 ms picks Low")
	return true

func test_settings_round_trip_keeps_audio(runner) -> bool:
	var saved := _begin()
	runner.check(GraphicsSettings.load_quality() == -1, "Q4 unset without a file")
	AudioSettings.save_volumes({"music": 0.25, "effects": 0.5, "voice": 0.75})
	GraphicsSettings.save_quality(GraphicsSettings.LOW)
	runner.check(GraphicsSettings.load_quality() == GraphicsSettings.LOW, "Q4 quality round trip")
	runner.check(AudioSettings.load_volumes() == {"music": 0.25, "effects": 0.5, "voice": 0.75}, "Q4 audio volumes kept")
	AudioSettings.save_volumes({"music": 1.0, "effects": 1.0, "voice": 1.0})
	runner.check(GraphicsSettings.load_quality() == GraphicsSettings.LOW, "Q4 saving audio keeps quality")
	_end(saved)
	return true

func test_corrupt_file_gives_unset(runner) -> bool:
	var saved := _begin()
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", "high")
	config.save(scratch)
	runner.check(GraphicsSettings.load_quality() == -1, "Q5 wrong type gives unset")
	config.set_value("graphics", "quality", 7)
	config.save(scratch)
	runner.check(GraphicsSettings.load_quality() == -1, "Q5 out-of-range value gives unset")
	_end(saved)
	return true

func test_auto_pick_skipped_headless(runner) -> bool:
	var saved := _begin()
	var main = Skirmish.instantiate()
	runner.root.add_child(main)
	await runner.process_frame
	for i in 130: main._process(0.016)
	runner.check(DisplayServer.get_name() == "headless", "Q6 fixture runs headless")
	runner.check(GraphicsSettings.load_quality() == -1 and not FileAccess.file_exists(scratch), "Q6 nothing saved")
	main.free()
	_end(saved)
	return true

func test_menu_toggle_saves_and_emits(runner) -> bool:
	var saved := _begin()
	var menu = PauseMenu.new(false)
	var seen: Array[int] = []
	menu.quality_changed.connect(func(quality: int) -> void: seen.append(quality))
	var button: Button = menu.find_child("Quality", true, false)
	runner.check(button.text == "Quality: High", "Q7 starts on High when unset, got " + button.text)
	button.pressed.emit()
	runner.check(seen == [GraphicsSettings.LOW] and GraphicsSettings.load_quality() == GraphicsSettings.LOW and button.text == "Quality: Low", "Q7 toggle goes Low, saves and emits")
	button.pressed.emit()
	runner.check(seen == [GraphicsSettings.LOW, GraphicsSettings.HIGH] and button.text == "Quality: High", "Q7 toggle back to High")
	menu.free()
	_end(saved)
	return true

func test_view_follows_quality_and_zoom(runner) -> bool:
	var saved := _begin()
	GraphicsSettings.save_quality(GraphicsSettings.LOW)
	var main = Skirmish.instantiate()
	runner.root.add_child(main)
	await runner.process_frame
	runner.check(main._view.detail() == 0 and main._view._quality == GraphicsSettings.LOW, "Q8 stored Low applied at start")
	main._pause.quality_changed.emit(GraphicsSettings.HIGH)
	main.change_zoom(1)
	runner.check(main._view.detail() == 2 and main._view._quality == GraphicsSettings.HIGH, "Q8 High and zoom 2.0 give detail 2")
	main.change_zoom(-1)
	main.change_zoom(-1)
	runner.check(main._view.detail() == 0, "Q8 zoom 0.5 gives detail 0")
	main.free()
	_end(saved)
	return true

func test_auto_pick_ignores_cold_frames(runner) -> bool:
	var saved := _begin()
	var main = Skirmish.instantiate()
	runner.root.add_child(main)
	await runner.process_frame
	main._auto_pending = true
	for i in main.AUTO_SKIP_FRAMES: main._auto_sample(90.0)
	runner.check(main._auto_pending and GraphicsSettings.load_quality() == -1, "Q9 cold frames alone decide nothing")
	for i in main.AUTO_FRAMES: main._auto_sample(2.0)
	runner.check(not main._auto_pending and GraphicsSettings.load_quality() == GraphicsSettings.HIGH, "Q9 a fast machine keeps High despite slow cold frames")
	for i in 20: main._auto_sample(20.0)
	runner.check(main._auto_samples.size() == main.AUTO_FRAMES and GraphicsSettings.load_quality() == GraphicsSettings.HIGH, "Q9 a decided pick is not revisited by later frames")
	main._auto_pending = true
	main._auto_samples.clear()
	main._auto_frame = 0
	for i in main.AUTO_SKIP_FRAMES + main.AUTO_FRAMES: main._auto_sample(20.0)
	runner.check(GraphicsSettings.load_quality() == GraphicsSettings.LOW, "Q9 a slow machine picks Low")
	runner.check(main._view.detail() == 0, "Q9 the running view follows the pick")
	main.free()
	_end(saved)
	return true

func test_menu_label_follows_stored_quality(runner) -> bool:
	var saved := _begin()
	var menu = PauseMenu.new(false)
	runner.root.add_child(menu)
	var button: Button = menu.find_child("Quality", true, false)
	GraphicsSettings.save_quality(GraphicsSettings.LOW)
	menu.open()
	runner.check(button.text == "Quality: Low", "Q10 opening the menu shows the stored quality, got " + button.text)
	menu.free()
	_end(saved)
	return true

func test_auto_pick_samples_tick_and_draw_time(runner) -> bool:
	var saved := _begin()
	var main = Skirmish.instantiate()
	runner.root.add_child(main)
	await runner.process_frame
	runner.check(not main._view.time_draws, "Q12 no draw timing while nothing is being picked")
	main._start_auto_pick(true)
	runner.check(main._auto_pending and main._view.time_draws, "Q12 picking turns the draw timer on")
	main._physics_process(0.016)
	runner.check(main._auto_tick_usec > 0, "Q12 the tick time is accumulated")
	main._auto_frame = main.AUTO_SKIP_FRAMES
	main._auto_tick_usec = 3000
	main._view.draw_usec = 2000
	main._process(0.016)
	runner.check(main._auto_samples == PackedFloat32Array([5.0]) and main._auto_tick_usec == 0 and main._view.draw_usec == 0, "Q12 a frame samples tick plus draw time, then resets both, got %s" % [main._auto_samples])
	main.free()
	_end(saved)
	return true

func test_neon_setting(runner) -> bool:
	var saved := _begin()
	runner.check(not GraphicsSettings.load_neon(), "W8 Neon is off without a file")
	AudioSettings.save_volumes({"music": 0.25, "effects": 0.5, "voice": 0.75})
	GraphicsSettings.save_quality(GraphicsSettings.LOW)
	GraphicsSettings.save_neon(true)
	runner.check(GraphicsSettings.load_neon() and GraphicsSettings.load_quality() == GraphicsSettings.LOW, "W8 Neon round trip keeps quality")
	runner.check(AudioSettings.load_volumes() == {"music": 0.25, "effects": 0.5, "voice": 0.75}, "W8 Neon keeps the audio volumes")
	GraphicsSettings.save_quality(GraphicsSettings.HIGH)
	runner.check(GraphicsSettings.load_neon(), "W8 saving quality keeps Neon")
	var config := ConfigFile.new()
	config.set_value("graphics", "neon", "yes")
	config.save(scratch)
	runner.check(not GraphicsSettings.load_neon(), "W8 a wrong type reads as off")
	_end(saved)
	return true

func test_neon_menu_and_wiring(runner) -> bool:
	var saved := _begin()
	var menu = PauseMenu.new(false)
	runner.root.add_child(menu)
	var seen: Array[bool] = []
	menu.neon_changed.connect(func(neon: bool) -> void: seen.append(neon))
	var button: Button = menu.find_child("Neon", true, false)
	runner.check(button != null and button.text == "Neon colours: Off", "W8 the menu starts with Neon off")
	button.pressed.emit()
	runner.check(seen == [true] and GraphicsSettings.load_neon() and button.text == "Neon colours: On", "W8 the toggle saves and emits")
	GraphicsSettings.save_neon(false)
	menu.open()
	runner.check(button.text == "Neon colours: Off", "W8 opening the menu re-reads the stored setting")
	menu.free()
	GraphicsSettings.save_neon(true)
	var main = Skirmish.instantiate()
	runner.root.add_child(main)
	await runner.process_frame
	runner.check(main._view._batch.bright_owners, "W8 a stored Neon setting applies at start")
	main._pause.neon_changed.emit(false)
	runner.check(not main._view._batch.bright_owners, "W8 the menu signal reaches the view")
	main.free()
	_end(saved)
	return true

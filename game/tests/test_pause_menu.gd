@warning_ignore_start("untyped_declaration")
extends RefCounted

const Base = preload("res://scenes/base.tscn")
const Skirmish = preload("res://scenes/skirmish.tscn")
const OnlineScene = preload("res://scenes/online_skirmish.tscn")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const Wire = preload("res://scripts/net/wire.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const LAUNCHER: String = "res://scenes/launcher.tscn"

class FakeTransport extends RefCounted:
	var frames := PackedStringArray()
	var close_calls: int = 0
	func poll() -> PackedStringArray:
		var out := frames
		frames = PackedStringArray()
		return out
	func send_text(_text: String) -> void: pass
	func closed() -> bool: return close_calls > 0
	func silent(_now: int) -> bool: return false
	func close() -> void: close_calls += 1
	func rtt_samples() -> PackedInt64Array: return PackedInt64Array()

func cases() -> Array[Callable]:
	return [test_esc_toggles_and_defers_to_cancel, test_offline_pauses_sim, test_offline_leave_and_quit, test_online_keeps_running, test_online_leave_confirm, test_online_leave_cancel, test_quit_hidden_on_web, test_menu_layout]

var helper_scratch: String = "user://test-pause-settings-%d.cfg" % OS.get_process_id()

func _helper_off() -> String:
	var saved: String = AudioSettings.path
	AudioSettings.path = helper_scratch
	DirAccess.remove_absolute(helper_scratch)
	PlaytestSettings.save_enabled(false)
	return saved

func _helper_restore(saved: String) -> void:
	DirAccess.remove_absolute(helper_scratch)
	AudioSettings.path = saved

func _esc(main) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	main._input(event)

func _scene(runner, packed):
	var main = packed.instantiate()
	runner.root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	await runner.process_frame
	return main

func _online(runner):
	var transport := FakeTransport.new()
	var seats: Array[int] = [1, 2]
	var lockstep = Lockstep.new(1, seats)
	var main = OnlineScene.instantiate()
	main.setup(transport, lockstep, 1)
	runner.root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	await runner.process_frame
	return {"main": main, "transport": transport, "lockstep": lockstep}

func _click(main, name: String) -> void:
	for button: Button in main.get_node("HUD/PauseMenu").find_children("*", "Button", true, false):
		if button.text == name and button.is_visible_in_tree():
			button.pressed.emit()
			return
	assert(false, "no visible button " + name)

func test_esc_toggles_and_defers_to_cancel(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	var menu: Control = main.get_node("HUD/PauseMenu")
	runner.check(not menu.visible, "E1 menu hidden by default")
	main.selected_ids.assign([1])
	_esc(main)
	runner.check(not menu.visible, "E1 Esc with a selection leaves the menu closed (unhandled input clears it)")
	main.selected_ids.clear()
	main._attack_move_mode = true
	_esc(main)
	runner.check(not menu.visible, "E1 Esc in attack-move mode leaves the menu closed")
	main._attack_move_mode = false
	main.free()
	main = await _scene(runner, Base)
	menu = main.get_node("HUD/PauseMenu")
	main.selected_ids.assign([main.simulation.snapshot().entities[0].id])
	main._enter_placement("usa_barracks")
	runner.check(not main._placement_kind.is_empty(), "E1 fixture: placement entered")
	_esc(main)
	runner.check(not menu.visible, "E1 Esc during placement leaves the menu closed")
	main._clear_placement()
	main.selected_ids.clear()
	_esc(main)
	runner.check(menu.visible and main.menu_open(), "E1 Esc with nothing to cancel opens the menu")
	_esc(main)
	runner.check(not menu.visible, "E1 second Esc closes it")
	main.free()
	return true

func test_offline_pauses_sim(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	main._physics_process(0.0)
	var tick: int = main.simulation.tick()
	runner.check(tick > 0, "E2 fixture: sim advances while closed")
	_esc(main)
	for i in 5: main._physics_process(0.0)
	runner.check(main.simulation.tick() == tick, "E2 tick frozen while the menu is open")
	_click(main, "Resume")
	runner.check(not main.menu_open(), "E2 Resume closes the menu")
	main._physics_process(0.0)
	runner.check(main.simulation.tick() == tick + 1, "E2 tick advances after Resume")
	main.free()
	return true

func test_offline_leave_and_quit(runner) -> bool:
	var saved: String = _helper_off()
	var main = await _scene(runner, Skirmish)
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	_esc(main)
	_click(main, "Back to main menu")
	runner.check(scenes == [LAUNCHER], "E3 offline leave goes straight to the launcher, got " + str(scenes))
	_helper_restore(saved)
	main.free()
	return true

func test_online_keeps_running(runner) -> bool:
	var online: Dictionary = await _online(runner)
	var main = online.main
	for tick in range(4, 40): online.transport.frames.append(Wire.encode(Wire.tick_message(2, tick, [], null)))
	main._physics_process(0.0)
	_esc(main)
	runner.check(main.menu_open(), "E4 online menu opens")
	var tick: int = main.simulation.tick()
	for i in 6: main._physics_process(0.0)
	runner.check(main.simulation.tick() > tick, "E4 online sim keeps stepping while the menu is open")
	main.free()
	return true

func test_online_leave_confirm(runner) -> bool:
	var saved: String = _helper_off()
	var online: Dictionary = await _online(runner)
	var main = online.main
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	_esc(main)
	_click(main, "Back to main menu")
	runner.check(scenes.is_empty() and online.transport.close_calls == 0, "E5 asking does not leave yet")
	runner.check(main.get_node("HUD/PauseMenu").is_confirming(), "E5 confirmation shown")
	_click(main, "Leave")
	runner.check(online.transport.close_calls == 1, "E5 leave closes the transport once")
	runner.check(online.lockstep.status().begins_with("ended"), "E5 lockstep ended for this client, got " + online.lockstep.status())
	runner.check(scenes == [LAUNCHER], "E5 launcher scene requested")
	_helper_restore(saved)
	main.free()
	return true

func test_online_leave_cancel(runner) -> bool:
	var online: Dictionary = await _online(runner)
	var main = online.main
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	_esc(main)
	_click(main, "Back to main menu")
	_click(main, "Cancel")
	runner.check(scenes.is_empty() and online.transport.close_calls == 0 and online.lockstep.status() != "ended_relay", "E6 cancel keeps the match")
	runner.check(main.menu_open() and not main.get_node("HUD/PauseMenu").is_confirming(), "E6 back on the main menu list")
	_click(main, "Back to main menu")
	_esc(main)
	runner.check(main.menu_open() and not main.get_node("HUD/PauseMenu").is_confirming(), "E6 Esc in the confirmation returns to the list")
	main.free()
	return true

func test_quit_hidden_on_web(runner) -> bool:
	for web in [false, true]:
		var menu = PauseMenu.new(web)
		var texts: Array = menu.find_children("*", "Button", true, false).map(func(button: Button) -> String: return button.text)
		runner.check(texts.has("Quit") != web, "E7 Quit present only off the web (web=%s)" % web)
		menu.free()
	return true

func test_menu_layout(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	var original: Vector2i = runner.root.size
	_esc(main)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		runner.root.size = size
		await runner.process_frame
		await runner.process_frame
		var menu: Control = main.get_node("HUD/PauseMenu")
		var buttons: Array = menu.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.is_visible_in_tree())
		var hud: Array[Rect2] = []
		for path in ["HUD/Status", "HUD/Economy"]:
			var control: Control = main.get_node(path)
			hud.append(Rect2(control.global_position, control.get_combined_minimum_size()))
		var quality: Button = menu.find_child("Quality", true, false)
		runner.check(quality != null and quality.is_visible_in_tree() and buttons.has(quality), "E8 quality toggle is visible")
		var neon: Button = menu.find_child("Neon", true, false)
		runner.check(neon != null and neon.is_visible_in_tree() and buttons.has(neon), "E8 the Neon toggle is visible at %s" % size)
		var smooth: Button = menu.find_child("Smooth", true, false)
		runner.check(smooth != null and smooth.is_visible_in_tree() and buttons.has(smooth), "E8 the Smooth toggle is visible at %s" % size)
		var destinations: Button = menu.find_child("Destinations", true, false)
		runner.check(destinations != null and destinations.is_visible_in_tree() and buttons.has(destinations), "E8 the Destinations toggle is visible at %s" % size)
		var playtest: Button = menu.find_child("Playtest", true, false)
		runner.check(playtest != null and playtest.is_visible_in_tree() and buttons.has(playtest), "E8 the Playtest toggle is visible at %s" % size)
		var sliders: Array = menu.find_children("*", "Range", true, false).filter(func(slider: Range) -> bool: return slider.is_visible_in_tree())
		var labels: Array = menu.find_child("Volume", true, false).find_children("*Label", "Label", true, false)
		runner.check(sliders.size() == 3 and labels.size() == 4, "E8 menu has 3 sliders and their labels, got %d and %d" % [sliders.size(), labels.size()])
		for control: Control in sliders + labels:
			var rect: Rect2 = control.get_global_rect()
			runner.check(Rect2(Vector2.ZERO, Vector2(size)).encloses(rect), "E8 %s inside %s" % [control.name, size])
			for other in hud: runner.check(not rect.intersects(other), "E8 %s clear of HUD text at %s" % [control.name, size])
			for button: Control in buttons: runner.check(not rect.intersects(button.get_global_rect()), "E8 %s clear of %s at %s" % [control.name, button.name, size])
		for i in buttons.size():
			var rect: Rect2 = buttons[i].get_global_rect()
			runner.check(Rect2(Vector2.ZERO, Vector2(size)).encloses(rect), "E8 button %d inside %s" % [i, size])
			for other in hud: runner.check(not rect.intersects(other), "E8 button %d clear of HUD text at %s" % [i, size])
			for j in range(i + 1, buttons.size()): runner.check(not rect.intersects(buttons[j].get_global_rect()), "E8 buttons %d and %d apart at %s" % [i, j, size])
	runner.root.size = original
	main.free()
	return true

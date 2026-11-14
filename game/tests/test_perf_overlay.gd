@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scenes/skirmish.tscn")
const Overlay = preload("res://scripts/presentation/perf_overlay.gd")
const Fixture = preload("res://tests/economy_fixture.gd")

func cases() -> Array[Callable]:
	return [test_summary_math, test_f3_toggles_hidden_default, test_layout_clear_of_hud, test_step_and_counts_shown, test_skirmish_wired, test_split_share_shown, test_f3_toggles_during_placement]

func _scene(runner, packed):
	var main = packed.instantiate()
	runner.root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await runner.process_frame
	return main

func _f3(main) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F3
	event.keycode = KEY_F3
	event.pressed = true
	main._unhandled_input(event)

func test_summary_math(runner) -> bool:
	var samples := PackedFloat64Array()
	for i in range(1, 101): samples.append(float(i))
	var stats: Dictionary = Overlay.summarize(samples)
	runner.check(stats.p95 == 95.0 and stats.max == 100.0 and stats.last == 100.0, "PO1 p95/max/last of 1..100")
	var long := PackedFloat64Array()
	for i in range(1, 201): long.append(float(i))
	stats = Overlay.summarize(long)
	runner.check(stats.p95 == 194.0 and stats.max == 200.0 and stats.last == 200.0, "PO1 window keeps the last 120 samples (81..200)")
	runner.check(Overlay.summarize(PackedFloat64Array()).last == 0.0, "PO1 empty sample is zero")
	return true

func test_f3_toggles_hidden_default(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	var overlay: Label = main.get_node("HUD/PerfOverlay")
	runner.check(not overlay.visible, "PO2 hidden by default")
	_f3(main)
	runner.check(overlay.visible and overlay.text.contains("FPS"), "PO2 F3 shows overlay with text")
	_f3(main)
	runner.check(not overlay.visible, "PO2 second F3 hides it")
	main.free()
	return true

func test_layout_clear_of_hud(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	main.get_node("HUD/PerfOverlay").set_counts(300, 12, 123456)
	_f3(main)
	await runner.process_frame
	var overlay: Label = main.get_node("HUD/PerfOverlay")
	var rect: Rect2 = overlay.get_global_rect()
	var viewport: Rect2 = main.get_viewport().get_visible_rect()
	runner.check(viewport.encloses(rect), "PO3 overlay inside the viewport")
	for path in ["HUD/Status", "HUD/Economy"]:
		var other: Control = main.get_node(path)
		var other_rect := Rect2(other.global_position, other.get_combined_minimum_size())
		runner.check(not rect.intersects(other_rect), "PO3 overlay clear of " + path)
	main.free()
	return true

func test_step_and_counts_shown(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	_f3(main)
	main._physics_process(0.0)
	var snapshot: Dictionary = main.driver.sim.snapshot()
	main.get_node("HUD/PerfOverlay").refresh_text()
	var text: String = main.get_node("HUD/PerfOverlay").text
	runner.check(text.contains("Units %d | Buildings %d | Tick %d" % [snapshot.entities.size(), snapshot.buildings.size(), snapshot.tick]), "PO4 counts and tick from the live state")
	runner.check(main.get_node("HUD/PerfOverlay")._step_count == 1, "PO4 physics step was timed")
	main.free()
	return true

func test_skirmish_wired(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	runner.check(main.get_node("HUD/PerfOverlay") != null and not main.get_node("HUD/PerfOverlay").visible, "PO5 skirmish has the hidden overlay")
	main.free()
	return true

func test_split_share_shown(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	var overlay: Label = main.get_node("HUD/PerfOverlay")
	overlay.split_share = 0.97
	overlay.refresh_text()
	runner.check(overlay.text.contains("split 97%"), "PO6 split share shown")
	main.free()
	return true

func test_f3_toggles_during_placement(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	main.driver.sim = Fixture.make_world()
	main.orders.selected_ids.assign([1])
	main._refresh()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.keycode = KEY_1
	key.pressed = true
	main._unhandled_input(key)
	var kind: String = main.orders._placement_kind
	var queued: int = main.driver.sim.snapshot().pending_commands.size()
	var overlay: Label = main.get_node("HUD/PerfOverlay")
	runner.check(not kind.is_empty(), "PO19 placement is active")
	_f3(main)
	var shown: bool = overlay.visible and main.orders._placement_kind == kind and main.driver.sim.snapshot().pending_commands.size() == queued
	runner.check(shown, "PO19 F3 toggles the overlay during placement and keeps the placement")
	_f3(main)
	runner.check(not overlay.visible and main.orders._placement_kind == kind, "PO19 second F3 hides it, placement still active")
	main.free()
	return true

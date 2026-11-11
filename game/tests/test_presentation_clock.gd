@warning_ignore_start("untyped_declaration")
extends RefCounted

const Clock = preload("res://scripts/presentation/presentation_clock.gd")

func cases() -> Array[Callable]:
	return [test_clock_table, test_clock_retry, test_clock_counters]

func _run(steps_per_frame: Array) -> Array:
	var clock := Clock.new()
	return _drive(clock, steps_per_frame)

func _drive(clock, steps_per_frame: Array) -> Array:
	var refreshed := []
	var tick := 0
	for frame in steps_per_frame.size():
		var due := false
		for i in steps_per_frame[frame]:
			tick += 1
			if clock.stepped(frame, tick): due = true
		if clock.rendered(frame, tick): due = true
		if due: refreshed.append(frame)
	return refreshed

func test_clock_table(runner) -> bool:
	runner.check(_run([1, 0, 1, 0]) == [1, 3], "PC1 60 fps: refresh in every idle frame")
	runner.check(_run([1, 0, 0, 0, 1, 0, 0, 0]) == [1, 5], "PC1 120 fps: one refresh per tick")
	runner.check(_run([1, 1, 1, 1]) == [1, 2, 3], "PC1 30 fps: fallback from frame 3 on")
	runner.check(_run([1, 1, 0, 1, 1, 0]) == [1, 3, 4], "PC1 45 fps: fallback, nothing skipped after the first")
	runner.check(_run([2, 0]) == [1], "PC1 two steps in one frame: one refresh")
	return true

func test_clock_retry(runner) -> bool:
	var frames := []
	for i in 200: frames.append(1)
	var refreshed := _run(frames)
	runner.check(refreshed.has(150) and not refreshed.has(151) and refreshed.has(152), "PC2 after 150 ticks one tick is deferred, the next frame refreshes")
	runner.check(refreshed.has(153), "PC2 fallback restarts")
	return true

func test_clock_counters(runner) -> bool:
	var split := Clock.new()
	_drive(split, [1, 0, 1, 0])
	runner.check(split.split_share() == 1.0, "PC3 split share is 100 percent when every refresh came from rendered")
	var fallback := Clock.new()
	_drive(fallback, [1, 1, 1, 1])
	runner.check(fallback.split_share() < 0.5, "PC3 split share drops in fallback")
	return true

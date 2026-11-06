extends SceneTree

const Workload = preload("res://scripts/debug/combat_workload.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const Wire = preload("res://scripts/net/wire.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

const WARMUP: int = 300
const SAMPLES: int = 1800
const BUDGET_P99_MS: float = 0.6

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("LOCKSTEP HEADLESS engine=", Engine.get_version_info().string, " os=", OS.get_name(), " cpu=", OS.get_processor_name(),
		" layout=contact delay=4 hash_every=30 warmup_ticks=", WARMUP, " sample_ticks=", SAMPLES)
	quit(0 if _measure() else 1)

func _measure() -> bool:
	var sim: Simulation = Workload.create("contact")
	var seats: Array[int] = [1, 2]
	var mine := Lockstep.new(1, seats)
	var peer := Lockstep.new(2, seats)
	var inbox: Array[String] = []
	var peer_inbox: Array[String] = []
	mine.send = func(text: String) -> void: peer_inbox.append(text)
	peer.send = func(text: String) -> void: inbox.append(text)
	mine.start(sim.snapshot())
	peer.start(sim.snapshot())
	var overhead := PackedFloat64Array()
	var snapshots := PackedFloat64Array()
	var hash_ticks: int = 0
	var busy_windows: int = 0
	var window_has_commands: bool = false
	for tick in range(WARMUP + SAMPLES):
		if tick % 10 == 0: mine.submit({"type": "move", "entity_ids": [1], "target": [10.5, 10.5]})
		if tick % 15 == 0: peer.submit({"type": "stop", "entity_ids": [2]})
		var received_at: int = Time.get_ticks_usec()
		for text in inbox: mine.receive(text)
		var receive_ms: float = (Time.get_ticks_usec() - received_at) / 1000.0
		if tick >= WARMUP and _has_commands(inbox): window_has_commands = true
		inbox.clear()
		for text in peer_inbox: peer.receive(text)
		peer_inbox.clear()
		if not mine.advance(sim):
			push_error("Lockstep benchmark stalled at tick %d: %s" % [tick, mine.status()])
			return false
		var after: int = sim.tick()
		var wants: bool = mine.wants_snapshot(after)
		var snapshot_started: int = Time.get_ticks_usec()
		var state: Variant = sim.snapshot() if wants else null
		var snapshot_ms: float = (Time.get_ticks_usec() - snapshot_started) / 1000.0
		var finish_started: int = Time.get_ticks_usec()
		mine.finish_tick(after, state)
		var finish_ms: float = (Time.get_ticks_usec() - finish_started) / 1000.0
		peer.finish_tick(after, state)
		if tick >= WARMUP:
			overhead.append(receive_ms + finish_ms)
			if wants:
				hash_ticks += 1
				snapshots.append(snapshot_ms)
			if (tick - WARMUP) % 30 == 29:
				if window_has_commands: busy_windows += 1
				window_has_commands = false
	var summary: Dictionary = Stats.summary(overhead)
	print("LOCKSTEP overhead_ms=", JSON.stringify(summary), " snapshot_ms_on_hash_ticks=", JSON.stringify(Stats.summary(snapshots)),
		" hash_ticks=", hash_ticks, " busy_30_tick_windows=", busy_windows, " alive_end=", sim.snapshot().entities.size())
	@warning_ignore("integer_division")
	if hash_ticks < 60 or busy_windows < SAMPLES / 30:
		push_error("Lockstep benchmark workload invalid: hash_ticks=%d busy_windows=%d" % [hash_ticks, busy_windows])
		return false
	var within: bool = summary.p99 <= BUDGET_P99_MS
	print("LOCKSTEP BUDGET ", "PASS" if within else "FAIL", " p99 ", summary.p99, " ms (limit ", BUDGET_P99_MS, ")")
	if not within:
		push_error("Lockstep overhead budget exceeded")
		return false
	print("LOCKSTEP BENCHMARK PASSED 1")
	return true

func _has_commands(texts: Array[String]) -> bool:
	for text in texts:
		if not Wire.decode(text).message.commands.is_empty(): return true
	return false

extends RefCounted

var _local_player: int
var _rng: RandomNumberGenerator
var _pending: Array[Dictionary] = []
var _last_collected: int = -1

func _init(local_player: int, rng: RandomNumberGenerator = null) -> void:
	_local_player = local_player
	_rng = rng
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()

func collect_step(tick: int, events: Array[Dictionary], results: Array[Dictionary]) -> void:
	if tick <= _last_collected: return
	_last_collected = tick
	_pending.append({"tick": tick, "events": events.duplicate(true), "results": results.duplicate(true)})

func collected_ticks() -> Array[int]:
	var ticks: Array[int] = []
	for step: Dictionary in _pending: ticks.append(step.tick)
	return ticks

func pending_step(index: int) -> Dictionary:
	return _pending[index]

func update(_state: Dictionary) -> Array[Dictionary]:
	return []

func reset() -> void:
	_pending.clear()
	_last_collected = -1

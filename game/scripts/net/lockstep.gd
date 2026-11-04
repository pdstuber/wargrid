extends RefCounted

const Wire = preload("res://scripts/net/wire.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")

var send: Callable = func(_frame: String) -> void: pass

var _seat: int
var _seats: Array[int]
var _delay: int
var _hash_interval: int
var _clock: Callable
var _status: String = "running"
var _next_tick: int = 0
var _packets: Dictionary = {}
var _last_received: Dictionary = {}
var _last_sent: int = 0
var _queue: Array = []
var _sequence: int = 0
var _submit_times: Dictionary = {}
var _own_hashes: Dictionary = {}
var _hash_order: Array[int] = []
var _hash_snapshot: Dictionary = {}
var _command_log: Array[Dictionary] = []
var _latency: PackedInt64Array = PackedInt64Array()
var _left_seat: int = 0
var _left_after: int = 0
var _end_reason: String = ""
var _desync_tick: int = -1
var _rejections: Array[Dictionary] = []

func _init(seat: int, seats: Array[int], delay: int = 4, hash_interval: int = 30, clock: Callable = Time.get_ticks_usec) -> void:
	_seat = seat
	_seats = seats.duplicate()
	_seats.sort()
	_last_sent = delay - 1
	_delay = delay
	_hash_interval = hash_interval
	_clock = clock
	for s in _seats:
		_packets[s] = {}
		_last_received[s] = delay - 1
		for tick in delay:
			_packets[s][tick] = {"commands": []}

func start(state: Dictionary) -> void:
	_last_sent = _delay - 1
	finish_tick(0, state)

func submit(payload: Dictionary) -> void:
	var command: Dictionary = payload.duplicate(true)
	command.tick = _last_sent + 1
	command.player = _seat
	command.sequence = _sequence
	_submit_times[_sequence] = _clock.call()
	_sequence += 1
	_queue.append(command)

func receive(text: String) -> void:
	if _ended(): return
	var decoded: Dictionary = Wire.decode(text)
	if not decoded.ok:
		_end("ended_protocol", decoded.error)
		return
	var message: Dictionary = decoded.message
	match message.type:
		"tick": _receive_tick(message)
		"left": _receive_left(message)
		"error": _end("ended_relay", message.reason)
		_: _end("ended_protocol", "unexpected " + message.type)

func can_step(sim_tick: int) -> bool:
	return waiting_for_tick(sim_tick).is_empty()

func waiting_for() -> Array[int]:
	return waiting_for_tick(_next_tick)

func waiting_for_tick(sim_tick: int) -> Array[int]:
	var missing: Array[int] = []
	for s in _seats:
		if not _packets[s].has(sim_tick): missing.append(s)
	return missing

func advance(sim: RefCounted) -> bool:
	if _ended() or sim.match_over(): return false
	var tick: int = sim.tick()
	if _left_seat != 0 and (tick > _left_after or not _packets[_left_seat].has(tick)): return _end("ended_left", "player %d disconnected" % _left_seat)
	if not can_step(tick):
		_status = "waiting"
		return false
	if not _verify_hashes(tick): return false
	var now: int = _clock.call()
	for s in _seats:
		for command in _packets[s][tick].commands:
			var result: Dictionary = sim.issue_command(command)
			_command_log.append(command)
			if s != _seat: continue
			_latency.append(now - _submit_times[command.sequence])
			_submit_times.erase(command.sequence)
			if not result.ok: _rejections.append({"tick": tick, "sequence": command.sequence, "error": result.error})
	for s in _seats: _packets[s].erase(tick)
	sim.step()
	_next_tick = tick + 1
	_status = "running"
	return true

func finish_tick(tick: int, state: Variant) -> void:
	var hash: Variant = null
	if state != null and tick % _hash_interval == 0:
		var value: String = StateHash.digest(state)
		_own_hashes[tick] = value
		_hash_order.append(tick)
		_hash_snapshot = state
		hash = {"tick": tick, "value": value}
	var packet_tick: int = tick + _delay
	var commands: Array = _queue
	_queue = []
	var text: String = Wire.encode(Wire.tick_message(_seat, packet_tick, commands, hash))
	_packets[_seat][packet_tick] = Wire.decode(text).message
	_last_sent = packet_tick
	send.call(text)

func wants_snapshot(tick: int) -> bool:
	return tick % _hash_interval == 0

func rejections() -> Array[Dictionary]:
	return _rejections

func status() -> String:
	return _status

func set_relay_lost() -> void:
	_end("ended_relay", "connection to relay lost")

func left_seat() -> int:
	return _left_seat

func end_reason() -> String:
	return _end_reason

func hash_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for tick in _hash_order: rows.append("%d\t%s" % [tick, _own_hashes[tick]])
	return rows

func command_log() -> Array[Dictionary]:
	return _command_log

func latency_samples() -> PackedInt64Array:
	return _latency

func desync_report() -> Dictionary:
	return {"seat": _seat, "tick": _desync_tick, "hash_rows": hash_rows(), "command_log": _command_log, "snapshot": _hash_snapshot}

func _ended() -> bool:
	return _status.begins_with("ended")

func _end(status: String, reason: String) -> bool:
	_status = status
	_end_reason = reason
	return false

func _receive_tick(message: Dictionary) -> void:
	var s: int = message.seat
	if s == _seat or not _seats.has(s):
		_end("ended_protocol", "bad seat")
		return
	if message.tick != _last_received[s] + 1:
		_end("ended_protocol", "tick out of order")
		return
	for command in message.commands:
		if command.get("player") != s or command.get("tick") != message.tick:
			_end("ended_protocol", "bad command stamp")
			return
	_last_received[s] = message.tick
	_packets[s][message.tick] = message

func _receive_left(message: Dictionary) -> void:
	if message.seat == _seat or not _seats.has(message.seat):
		_end("ended_protocol", "bad left seat")
		return
	_left_seat = message.seat
	_left_after = message.after_tick

func _verify_hashes(tick: int) -> bool:
	for s in _seats:
		var packet: Dictionary = _packets[s][tick]
		if not packet.has("hash"): continue
		var hash: Dictionary = packet.hash
		if _own_hashes.get(hash.tick) != hash.value:
			_desync_tick = hash.tick
			_end("ended_desync", "hash mismatch at tick %d (seat %d)" % [hash.tick, s])
			return false
	return true

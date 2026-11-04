extends RefCounted

const Wire = preload("res://scripts/net/wire.gd")
const PING_INTERVAL_USEC: int = 1_000_000
const BUFFER_BYTES: int = 1 << 17

var _peer := WebSocketPeer.new()
var _clock: Callable
var _called: bool = false
var _sent_any: bool = false
var _last_ping: int = 0
var _rtt := PackedInt64Array()

func _init(clock: Callable = Time.get_ticks_usec) -> void:
	_clock = clock
	_peer.inbound_buffer_size = BUFFER_BYTES
	_peer.outbound_buffer_size = BUFFER_BYTES

func connect_to(url: String) -> Error:
	_called = true
	return _peer.connect_to_url(url)

func poll() -> PackedStringArray:
	var frames := PackedStringArray()
	if not _called: return frames
	_peer.poll()
	while _peer.get_available_packet_count() > 0:
		var text: String = _peer.get_packet().get_string_from_utf8()
		if not _take_pong(text): frames.append(text)
	var ping: String = take_ping(_clock.call())
	if ping != "": _peer.send_text(ping)
	return frames

func send_text(text: String) -> void:
	if not is_open(): return
	_sent_any = true
	_peer.send_text(text)

func is_open() -> bool:
	return _called and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN

func closed() -> bool:
	return _called and _peer.get_ready_state() == WebSocketPeer.STATE_CLOSED

func close() -> void:
	if _called: _peer.close()

func rtt_samples() -> PackedInt64Array:
	return _rtt

func take_ping(now: int) -> String:
	if not is_open() or not _sent_any or now - _last_ping < PING_INTERVAL_USEC: return ""
	_last_ping = now
	return Wire.encode({"type": "ping", "t": now})

func _take_pong(text: String) -> bool:
	if text.length() > 64 or not text.contains("\"pong\""): return false
	var decoded: Dictionary = Wire.decode(text)
	if not decoded.ok or decoded.message.type != "pong": return false
	_rtt.append(int(_clock.call()) - int(decoded.message.t))
	return true

extends RefCounted

const RelayTransport = preload("res://scripts/net/relay_transport.gd")
const Wire = preload("res://scripts/net/wire.gd")

func cases() -> Array[Callable]:
	return [test_never_connected, test_pong_recorded, test_buffers_fit_frame_cap]

func test_never_connected(runner) -> bool:
	var transport = RelayTransport.new()
	runner.check(transport.poll().is_empty(), "T1 poll on never-connected is empty")
	runner.check(not transport.closed() and not transport.is_open(), "T1 never-connected is neither open nor closed")
	transport.send_text("x")
	transport.close()
	runner.check(transport.take_ping(10_000_000) == "", "T1 no ping without an open socket")
	return true

func test_pong_recorded(runner) -> bool:
	var now := [1000]
	var transport = RelayTransport.new(func() -> int: return now[0])
	now[0] = 1500
	runner.check(transport._take_pong(Wire.encode({"type": "pong", "t": 1000})), "T3 pong consumed")
	runner.check(transport.rtt_samples() == PackedInt64Array([500]), "T3 rtt is clock difference in microseconds")
	runner.check(not transport._take_pong(Wire.encode({"type": "left", "seat": 2, "after_tick": 5})), "T3 other frames pass through")
	return true

func test_buffers_fit_frame_cap(runner) -> bool:
	var transport = RelayTransport.new()
	runner.check(transport._peer.inbound_buffer_size >= Wire.MAX_FRAME_BYTES and transport._peer.outbound_buffer_size >= Wire.MAX_FRAME_BYTES, "T4 WebSocket buffers hold a 65,536-byte frame")
	return true

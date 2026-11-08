@warning_ignore_start("untyped_declaration")
extends RefCounted

const Lockstep = preload("res://scripts/net/lockstep.gd")
const SeatSim = preload("res://scripts/net/seat_sim.gd")
const Wire = preload("res://scripts/net/wire.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const ScriptedHuman = preload("res://scripts/simulation/scripted_human.gd")
const COMMAND_TYPES: Array[String] = ["move", "stop", "build", "resume_build", "cancel_build", "produce", "cancel_production", "set_rally", "gather", "attack", "attack_move", "defence_attack"]

class Client extends RefCounted:
	var seat: int
	var sim: RefCounted
	var ls: RefCounted
	var seat_sim: RefCounted
	var behavior: Callable = func(_c) -> void: pass
	var hook: Callable = func(_c, _tick: int) -> void: pass
	var inbox: Array = []
	var last_due: int = 0
	var target: int = 1 << 30
	var results: Array = []
	var sent: Array[String] = []

class Net extends RefCounted:
	var clients: Array[Client] = []
	var now: int = 0
	var max_delay: int = 0
	var rng := RandomNumberGenerator.new()

	func add(seat: int, _controller_seat_two: String, clock: Callable = Time.get_ticks_usec) -> Client:
		var c := Client.new()
		c.seat = seat
		c.sim = Skirmish.create(true, "human")
		var seats: Array[int] = [1, 2]
		c.ls = Lockstep.new(seat, seats, 4, 30, clock)
		c.seat_sim = SeatSim.new(c.sim, c.ls)
		clients.append(c)
		return c

	func connect_all() -> void:
		for c in clients:
			c.ls.send = func(text: String) -> void:
				c.sent.append(text)
				for other in clients:
					if other == c: continue
					other.last_due = maxi(other.last_due, now + (rng.randi_range(0, max_delay) if max_delay > 0 else 0))
					other.inbox.append([other.last_due, text])
			c.ls.start(c.sim.snapshot())

	func run(max_iterations: int = 100000) -> void:
		for i in max_iterations:
			var active: bool = false
			for c in clients:
				while not c.inbox.is_empty() and c.inbox[0][0] <= now:
					c.ls.receive(c.inbox.pop_front()[1])
				if c.ls.status().begins_with("ended") or c.sim.tick() >= c.target: continue
				active = true
				var tick: int = c.sim.tick()
				if c.ls.can_step(tick):
					c.behavior.call(c)
					c.hook.call(c, tick)
				if c.ls.advance(c.sim):
					var after: int = c.sim.tick()
					c.ls.finish_tick(after, c.sim.snapshot() if c.ls.wants_snapshot(after) else null)
					c.results.append(c.sim.snapshot().command_results)
			now += 1
			if not active: break
		for c in clients:
			c.ls.send = Callable()
			c.behavior = Callable()
			c.hook = Callable()

func _pair(_runner, max_delay: int = 0) -> Net:
	var net := Net.new()
	net.max_delay = max_delay
	net.rng.seed = 5
	net.add(1, "human")
	net.add(2, "human")
	return net

func cases() -> Array[Callable]:
	return [test_delay_and_prefill, test_two_clients_equal_hashes, test_own_command_uses_wire_form, test_cross_seat_same_tick, test_many_commands_one_tick, test_desync_detected, test_left_after_tick, test_protocol_errors, test_latency_samples, test_left_with_missing_packets, test_rejections_reported, test_submit_before_start, test_relay_lost_keeps_earlier_end, test_left_before_start]

func _scripts(net: Net) -> void:
	net.clients[0].behavior = func(c) -> void: ScriptedHuman.issue(c.seat_sim)
	net.clients[1].behavior = func(c) -> void: Skirmish.issue_opponent(c.seat_sim, 2)

func _move(entity: int = 1) -> Dictionary:
	return {"type": "move", "entity_ids": [entity], "target": [10.5, 10.5]}

func test_delay_and_prefill(runner) -> bool:
	var sim = Skirmish.create(true, "human")
	var seats: Array[int] = [1, 2]
	var ls = Lockstep.new(1, seats)
	ls.start(sim.snapshot())
	for tick in range(4):
		var stepped: bool = ls.advance(sim)
		runner.check(stepped, "L1 prefilled tick %d steps without a peer packet" % tick)
		if stepped: ls.finish_tick(sim.tick(), null)
	runner.check(not ls.advance(sim) and ls.status() == "waiting" and ls.waiting_for() == [2] and sim.tick() == 4, "L1 tick 4 waits for seat 2")
	var net := _pair(runner)
	net.clients[0].hook = func(c, tick: int) -> void:
		if tick == 10 and c.seat == 1: c.ls.submit({"type": "stop", "entity_ids": [1]})
	net.clients[0].target = 20
	net.clients[1].target = 20
	net.connect_all()
	net.run()
	for c in net.clients:
		var at_15: Array = []
		for tick_results in c.results:
			for r in tick_results:
				if r.tick == 15 and r.ok and r.sequence == 0 and r.player == 1: at_15.append(r)
		runner.check(at_15.size() == 1 and c.sim.tick() == 20 and c.ls.status() == "running", "L1 seat %d: command from tick 10 accepted in the step at tick 15" % c.seat)
	return true

func test_two_clients_equal_hashes(runner) -> bool:
	var net := _pair(runner, 6)
	_scripts(net)
	for c in net.clients: c.target = 1800
	net.connect_all()
	net.run()
	var a: Client = net.clients[0]
	var b: Client = net.clients[1]
	runner.check(a.sim.tick() == 1800 and b.sim.tick() == 1800, "L2 both reach tick 1800")
	runner.check(a.ls.hash_rows() == b.ls.hash_rows() and a.ls.hash_rows().size() == 61, "L2 hash rows equal")
	runner.check(a.ls.command_log() == b.ls.command_log() and a.ls.command_log().size() > 10, "L2 command logs equal")
	var oracle = Skirmish.create(true, "human")
	var rows := PackedStringArray()
	var log_rows: Array = a.ls.command_log().duplicate()
	for tick in range(1801):
		if tick % 30 == 0: rows.append("%d\t%s" % [tick, StateHash.digest(oracle.snapshot())])
		if tick == 1800: break
		while not log_rows.is_empty() and log_rows[0].tick == tick: oracle.issue_command(log_rows.pop_front())
		oracle.step()
	runner.check(rows == a.ls.hash_rows(), "L2 single-process replay of the command log matches")
	return true

func test_own_command_uses_wire_form(runner) -> bool:
	var net := _pair(runner)
	net.clients[0].hook = func(c, tick: int) -> void:
		if tick == 3: c.ls.submit({"type": "move", "entity_ids": [1], "target": [0.1 + 0.2, 3]})
	for c in net.clients: c.target = 12
	net.connect_all()
	net.run()
	var log_rows: Array = net.clients[0].ls.command_log().filter(func(m: Dictionary) -> bool: return m.type == "move")
	runner.check(log_rows.size() == 1 and typeof(log_rows[0].tick) == TYPE_INT and typeof(log_rows[0].entity_ids[0]) == TYPE_INT, "L3 applied command has int fields")
	runner.check(log_rows.size() == 1 and log_rows[0].target[0] == 0.30000000000000004, "L3 target keeps full precision")
	var sent: Dictionary = Wire.decode(net.clients[0].sent.filter(func(t: String) -> bool: return t.contains('"move"'))[0]).message
	runner.check(sent.commands[0] == log_rows[0], "L3 applied equals decoded sent form")
	runner.check(typeof(log_rows[0].target[1]) == TYPE_FLOAT, "L3 integral target stays float after the wire")
	return true

func _own(state: Dictionary, owner: int) -> Dictionary:
	var units: Array = state.entities.filter(func(u: Dictionary) -> bool: return u.owner == owner and u.combat != null)
	var builder: int = 1
	for u in state.entities:
		if u.owner == owner and u.kind == "usa_builder": builder = u.id
	var buildings: Array = state.buildings.filter(func(b: Dictionary) -> bool: return b.owner == owner)
	var enemy: Array = state.entities.filter(func(u: Dictionary) -> bool: return u.owner != owner and u.combat != null)
	var enemy_buildings: Array = state.buildings.filter(func(b: Dictionary) -> bool: return b.owner != owner)
	var enemy_target: int = enemy[0].id if not enemy.is_empty() else (enemy_buildings[0].id if not enemy_buildings.is_empty() else 1)
	var ids: Array = units.map(func(u: Dictionary) -> int: return u.id)
	if ids.is_empty(): ids = [builder]
	var barracks: Array = buildings.filter(func(b: Dictionary) -> bool: return b.kind == "usa_barracks")
	var incomplete: Array = buildings.filter(func(b: Dictionary) -> bool: return not b.completed)
	var any_building: int = buildings[0].id if not buildings.is_empty() else 1
	return {"ids": ids, "builder": builder, "producer": barracks[0].id if not barracks.is_empty() else any_building, "any": any_building, "cancel": incomplete[0].id if not incomplete.is_empty() else any_building, "enemy": enemy_target, "source": state.sources[0].id, "owner": owner, "buildings": buildings.size()}

func _make(type: String, o: Dictionary) -> Dictionary:
	match type:
		"move": return {"type": type, "entity_ids": o.ids, "target": [20.5, 14.5]}
		"stop": return {"type": type, "entity_ids": o.ids}
		"build": return {"type": type, "builder_id": o.builder, "building_kind": "usa_power_plant", "origin": [20 + o.owner, 2]}
		"resume_build": return {"type": type, "builder_id": o.builder, "building_id": o.cancel}
		"cancel_build": return {"type": type, "building_id": o.cancel}
		"produce": return {"type": type, "building_id": o.producer, "unit_kind": "usa_rifle_infantry"}
		"cancel_production": return {"type": type, "building_id": o.producer, "production_id": 1}
		"set_rally": return {"type": type, "building_id": o.producer, "target": [18.5, 14.5]}
		"gather": return {"type": type, "entity_ids": [o.builder], "source_id": o.source}
		"attack": return {"type": type, "entity_ids": o.ids, "target_id": o.enemy}
	return {"type": "attack_move", "entity_ids": o.ids, "target": [24.5, 14.5]}

func test_cross_seat_same_tick(runner) -> bool:
	var start_tick: int = 1500
	var net := _pair(runner, 3)
	_scripts(net)
	for c in net.clients:
		c.target = start_tick + 121 + 20
		c.hook = func(client, tick: int) -> void:
			var index: int = tick - start_tick
			if index < 0 or index >= 121: return
			@warning_ignore("integer_division")
			var type: String = COMMAND_TYPES[index / 11] if client.seat == 1 else COMMAND_TYPES[index % 11]
			client.ls.submit(_make(type, _own(client.sim.snapshot(), client.seat)))
	net.connect_all()
	net.run()
	var a: Client = net.clients[0]
	var b: Client = net.clients[1]
	runner.check(a.sim.tick() == b.sim.tick() and a.sim.tick() >= start_tick + 141, "L4 both clients ran through every pair")
	runner.check(a.ls.hash_rows() == b.ls.hash_rows(), "L4 hash rows equal across all 121 same-tick pairs")
	runner.check(a.results == b.results, "L4 command results equal on both clients every tick")
	runner.check(a.ls.command_log() == b.ls.command_log(), "L4 applied commands equal")
	runner.check(_own(a.sim.snapshot(), 1).buildings >= 3, "L4 world was built up enough for building commands")
	var accepted: int = 0
	for tick_results in a.results:
		for r in tick_results:
			if r.ok: accepted += 1
	runner.check(accepted > 60, "L4 many cross-seat commands were actually accepted (%d)" % accepted)
	return true

func test_many_commands_one_tick(runner) -> bool:
	var net := _pair(runner, 2)
	var ids: Array = []
	for c in net.clients:
		ids = []
		for y in range(16, 32):
			for x in range(0, 24):
				var id: int = c.sim.spawn(1, Vector2(x + 0.5, y + 0.5), "usa_rifle_infantry")
				if id > 0 and ids.size() < 300: ids.append(id)
	runner.check(ids.size() == 300, "L5 300 units spawned")
	var sender: Client = net.clients[0]
	sender.hook = func(c, tick: int) -> void:
		if tick != 10: return
		for i in 50: c.ls.submit({"type": "stop", "entity_ids": [1]})
		c.ls.submit({"type": "move", "entity_ids": ids, "target": [10.5, 10.5]})
	for c in net.clients: c.target = 30
	net.connect_all()
	net.run()
	var b: Client = net.clients[1]
	var applied: Array = b.ls.command_log().filter(func(m: Dictionary) -> bool: return m.player == 1)
	var sequences: Array = applied.map(func(m: Dictionary) -> int: return m.sequence)
	runner.check(sequences == range(51), "L5 51 commands applied in sequence order on the peer")
	runner.check(applied.size() == 51 and applied[50].entity_ids.size() == 300, "L5 300-id move intact")
	runner.check(sender.ls.command_log() == b.ls.command_log() and sender.results == b.results, "L5 both clients applied identically")
	var largest: int = 0
	for text in sender.sent: largest = maxi(largest, text.to_utf8_buffer().size())
	runner.check(largest > 3000 and largest < 65536, "L5 largest frame %d bytes below cap" % largest)
	return true

func test_desync_detected(runner) -> bool:
	var net := _pair(runner, 2)
	_scripts(net)
	for c in net.clients: c.target = 200
	net.clients[1].hook = func(c, tick: int) -> void:
		if tick == 40: c.sim._players[2].credits += 1
	net.connect_all()
	net.run()
	for c in net.clients:
		runner.check(c.ls.status() == "ended_desync", "L6 seat %d ended_desync" % c.seat)
		var report: Dictionary = c.ls.desync_report()
		runner.check(report.tick == 60 and report.snapshot.tick == 60, "L6 seat %d report is for hash tick 60" % c.seat)
	runner.check(net.clients[0].ls.command_log() == net.clients[1].ls.command_log(), "L6 report command logs equal")
	runner.check(net.clients[0].ls.desync_report().hash_rows.size() == 3, "L6 hash rows 0, 30, 60")
	return true

func test_left_after_tick(runner) -> bool:
	var net := _pair(runner)
	net.clients[1].target = 16
	net.connect_all()
	net.clients[0].inbox.append([0, Wire.encode({"type": "left", "seat": 2, "after_tick": 20})])
	net.run()
	var a: Client = net.clients[0]
	runner.check(a.ls.status() == "ended_left" and a.ls.left_seat() == 2 and a.sim.tick() == 21, "L7 stepped to 21 then ended_left")
	return true

func _fresh():
	var sim = Skirmish.create(true, "human")
	var seats: Array[int] = [1, 2]
	var ls = Lockstep.new(1, seats)
	ls.start(sim.snapshot())
	return [sim, ls]

func _tick_frame(seat: int, tick: int, commands: Array = []) -> String:
	return Wire.encode(Wire.tick_message(seat, tick, commands, null))

func test_protocol_errors(runner) -> bool:
	var bad := {
		"duplicate tick": [_tick_frame(2, 4), _tick_frame(2, 4)],
		"skipped tick": [_tick_frame(2, 5)],
		"already stepped tick": [_tick_frame(2, 4), _tick_frame(2, 3)],
		"command player mismatch": [_tick_frame(2, 4, [{"type": "stop", "tick": 4, "player": 1, "sequence": 0, "entity_ids": [1]}])],
		"command tick mismatch": [_tick_frame(2, 4, [{"type": "stop", "tick": 9, "player": 2, "sequence": 0, "entity_ids": [1]}])],
		"own seat": [_tick_frame(1, 4)],
		"unknown message type": ['{"type":"nope"}'],
		"garbage": ["not json"],
		"unexpected welcome": ['{"type":"welcome","seat":1,"match":"ABC234"}'],
	}
	for name in bad:
		var pair = _fresh()
		for frame in bad[name]: pair[1].receive(frame)
		runner.check(pair[1].status() == "ended_protocol", "L8 %s ends protocol" % name)
		runner.check(not pair[1].advance(pair[0]) and pair[0].tick() == 0, "L8 %s: no step" % name)
	var pair = _fresh()
	pair[1].receive('{"type":"error","reason":"match full"}')
	runner.check(pair[1].status() == "ended_relay" and pair[1].end_reason() == "match full", "L8 relay error keeps its reason")
	return true

func test_latency_samples(runner) -> bool:
	var clock_value: Array = [0]
	var clock := func() -> int: return clock_value[0]
	var net := Net.new()
	net.add(1, "human", clock)
	net.add(2, "human", clock)
	for c in net.clients:
		c.target = 40
		c.hook = func(client, tick: int) -> void:
			if client.seat == 1 and tick == 10: client.ls.submit(_move())
	net.connect_all()
	# one clock step per loop iteration; both clients advance once per iteration
	for c in net.clients:
		var inner: Callable = c.hook
		c.hook = func(client, tick: int) -> void:
			if client.seat == 1: clock_value[0] = tick * 33333
			inner.call(client, tick)
	net.run()
	var samples: PackedInt64Array = net.clients[0].ls.latency_samples()
	runner.check(samples.size() == 1 and samples[0] == 5 * 33333, "L9 latency sample is 5 ticks (%s)" % str(samples))
	return true

func test_left_with_missing_packets(runner) -> bool:
	var net := _pair(runner)
	net.clients[1].target = 16
	net.connect_all()
	net.clients[0].inbox.append([0, Wire.encode({"type": "left", "seat": 2, "after_tick": 40})])
	net.run()
	var a: Client = net.clients[0]
	runner.check(a.ls.status() == "ended_left" and a.sim.tick() == 21, "L10 a never-delivered packet ends the match instead of hanging (tick %d)" % a.sim.tick())
	return true

func test_rejections_reported(runner) -> bool:
	var net := _pair(runner)
	net.clients[0].hook = func(c, tick: int) -> void:
		if tick == 3: c.ls.submit({"type": "move", "entity_ids": [2], "target": [10.5, 10.5]})
	for c in net.clients: c.target = 12
	net.connect_all()
	net.run()
	var rejected: Array = net.clients[0].ls.rejections()
	runner.check(rejected.size() == 1 and rejected[0].sequence == 0 and not rejected[0].error.is_empty(), "L11 own rejected command is reported with its error")
	runner.check(net.clients[1].ls.rejections().is_empty(), "L11 peer commands are not reported as own rejections")
	return true

func test_submit_before_start(runner) -> bool:
	var sim = Skirmish.create(true, "human")
	var seats: Array[int] = [2, 1]
	var ls = Lockstep.new(1, seats)
	ls.submit({"type": "stop", "entity_ids": [1]})
	ls.start(sim.snapshot())
	runner.check(ls.wants_snapshot(30) and not ls.wants_snapshot(31), "L12 wants_snapshot follows hash_interval")
	runner.check(ls.waiting_for_tick(4) == [2], "L12 seat order does not matter")
	return true

func test_relay_lost_keeps_earlier_end(runner) -> bool:
	var seats: Array[int] = [1, 2]
	var ls = Lockstep.new(1, seats)
	ls.receive(Wire.encode({"type": "error", "reason": "build mismatch"}))
	ls.set_relay_lost()
	runner.check(ls.status() == "ended_relay" and ls.end_reason() == "build mismatch", "L13 socket close after an error keeps the error reason")
	var other = Lockstep.new(1, seats)
	other.set_relay_lost()
	runner.check(other.status() == "ended_relay" and other.end_reason() == "connection to relay lost", "L13 close on a running match reports relay lost")
	return true

func test_left_before_start(runner) -> bool:
	var early: Array = _fresh()
	runner.check(not early[1].left_before_start(), "L14 no left, not before the start")
	early[1].receive('{"type":"left","seat":2,"after_tick":3}')
	runner.check(early[1].left_before_start(), "L14 after_tick 3 with delay 4 is before the start")
	var edge: Array = _fresh()
	edge[1].receive('{"type":"left","seat":2,"after_tick":4}')
	runner.check(not edge[1].left_before_start(), "L14 after_tick 4 with delay 4 is not before the start")
	return true

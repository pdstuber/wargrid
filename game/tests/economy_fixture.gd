extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")

static func make_world(credits: int = 10000, size: Vector2i = Vector2i(32,32)) -> RefCounted:
	var sim = Simulation.new([],size)
	sim.add_player(1,credits)
	sim.spawn(1,Vector2(4.5,4.5),"builder")
	return sim

static func send(sim: RefCounted, payload: Dictionary) -> Dictionary:
	var state: Dictionary = sim.snapshot()
	var command: Dictionary = payload.duplicate(true)
	command.tick = command.get("tick",state.tick)
	command.player = command.get("player",1)
	var sequence: int = -1
	for entry in state.last_sequences:
		if entry.player == command.player:
			sequence = entry.sequence
	command.sequence = command.get("sequence",sequence + 1)
	return sim.issue_command(command)

static func build(runner, sim: RefCounted, kind: String, origin: Vector2i, max_ticks: int = 3000) -> int:
	var next: int = sim.snapshot().next_entity_id
	var result: Dictionary = send(sim,{"type":"build","builder_id":1,"building_kind":kind,"origin":[origin.x,origin.y]})
	runner.check(result.ok,"fixture build accepted " + kind + ": " + result.error)
	if not result.ok: return -1
	for index in range(max_ticks):
		sim.step()
		for building in sim.snapshot().buildings:
			if building.id == next and building.completed: return next
		for outcome in sim.snapshot().command_results:
			if not outcome.ok:
				runner.check(false,"fixture build execution: " + outcome.error)
				return -1
	runner.check(false,"fixture build timeout " + kind)
	return -1

static func object(sim: RefCounted, id: int) -> Dictionary:
	var state: Dictionary = sim.snapshot()
	for key in ["entities","buildings","sources"]:
		for item in state[key]:
			if item.id == id: return item
	return {}

static func steps(sim: RefCounted, count: int) -> void:
	for index in range(count): sim.step()

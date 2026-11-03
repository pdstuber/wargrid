extends RefCounted

const Economy = preload("res://tests/economy_fixture.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

static func world() -> RefCounted:
	return Simulation.new([], Vector2i(32, 32))

static func send(sim: RefCounted, payload: Dictionary) -> Dictionary:
	return Economy.send(sim, payload)

static func object(sim: RefCounted, id: int) -> Dictionary:
	return Economy.object(sim, id)

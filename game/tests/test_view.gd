extends RefCounted

const View = preload("res://scripts/presentation/world_view.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")

func cases() -> Array[Callable]:
	return [test_pick]

func test_pick(runner) -> bool:
	var view = View.new()
	runner.check(view.pick_entity(Vector2.ZERO) == -1, "V1 empty")
	var sim = Simulation.new()
	sim.spawn(1, Vector2(2.5, 2.5))
	sim.spawn(2, Vector2(4.5, 4.5))
	var state: Dictionary = sim.snapshot()
	view.set_state(state, 1)
	var anchor := Iso.world_to_plane(Vector2(2.5, 2.5))
	runner.check(view.pick_entity(anchor + Vector2(0, -8)) == 1, "V1 interior")
	runner.check(view.pick_entity(anchor + Vector2(-12, -16)) == 1, "V1 top left bound")
	for offset in [Vector2(12, -8), Vector2(0, 0), Vector2(-13, -8), Vector2(0, -17)]:
		runner.check(view.pick_entity(anchor + offset) == -1, "V1 outside " + str(offset))
	runner.check(view.pick_entity(Iso.world_to_plane(Vector2(4.5, 4.5)) + Vector2(0, -8)) == -1, "V1 enemy ignored")
	state.entities[0].position[0] = 10
	state.entities.clear()
	runner.check(view.pick_entity(anchor + Vector2(0, -8)) == 1, "V1 set_state copies")
	view.free()
	return true

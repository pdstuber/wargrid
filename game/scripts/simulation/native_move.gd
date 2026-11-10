extends RefCounted

# Movement slice for the native spike; buffers per docs/reference/native-sim-spike-slice-move.md. Stub until T6.

const Simulation = preload("res://scripts/simulation/simulation.gd")

# The movement loop of Simulation.step(), unchanged: the GDScript reference this slice is timed and compared against.
func step_gd(sim: Simulation, ids: Array[int]) -> void:
	for id in ids:
		var unit: Dictionary = sim._entities[id]
		if unit.status == "moving": sim._advance(unit)
		elif unit.status != "path_pending": unit.speed = 0.0

func pack(_sim: Simulation, _ids: Array[int]) -> Array:
	return []

func call_native(core: Object, inputs: Array) -> Array:
	return core.run(inputs)

func call_pass(core: Object, inputs: Array) -> Array:
	return core.run_pass(inputs)

func apply(_sim: Simulation, _inputs: Array, _outputs: Array) -> void:
	pass

func compare(_sim: Simulation, _inputs: Array, _outputs: Array) -> Dictionary:
	return {"mismatch": "move: compare not implemented", "expected": []}

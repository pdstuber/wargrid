extends RefCounted

# Horde step slice for the native spike; buffers per docs/reference/native-sim-spike-slice-horde.md. Stub until T5.

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Horde = preload("res://scripts/simulation/horde.gd")

func step_gd(sim: Simulation, armed: Array[int]) -> void:
	Horde.step(sim, armed)

func pack(_sim: Simulation, _armed: Array[int]) -> Array:
	return []

func call_native(core: Object, inputs: Array) -> Array:
	return core.run(inputs)

func call_pass(core: Object, inputs: Array) -> Array:
	return core.run_pass(inputs)

func apply(_sim: Simulation, _inputs: Array, _outputs: Array) -> void:
	pass

func compare(_sim: Simulation, _inputs: Array, _outputs: Array) -> Dictionary:
	return {"mismatch": "horde: compare not implemented", "expected": []}

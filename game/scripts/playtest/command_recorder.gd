extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")

var _sim: Simulation
var _commands: Array[Dictionary] = []

func _init(sim: Simulation) -> void:
	_sim = sim

func issue_command(command: Dictionary) -> Dictionary:
	var result: Dictionary = _sim.issue_command(command)
	if result.ok: _commands.append(command.duplicate(true))
	return result

func snapshot() -> Dictionary:
	return _sim.snapshot()

func tick() -> int:
	return _sim.tick()

func map_data() -> Dictionary:
	return _sim.map_data()

func simulation() -> Simulation:
	return _sim

func commands() -> Array[Dictionary]:
	return _commands

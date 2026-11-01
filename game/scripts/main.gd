extends Node

const Simulation = preload("res://scripts/simulation/simulation.gd")
var simulation = Simulation.new()

func _physics_process(_delta: float) -> void:
	simulation.step()

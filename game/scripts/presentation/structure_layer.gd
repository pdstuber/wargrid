extends Node2D

var draws: int = 0

func _draw() -> void:
	draws += 1
	get_parent().draw_structures()

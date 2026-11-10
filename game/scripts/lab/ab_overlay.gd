extends Node2D

const AbVariants = preload("res://scripts/lab/ab_variants.gd")

var variants: AbVariants
var on_top: bool = false

func _draw() -> void:
	if variants == null: return
	if on_top: variants.draw_top(self)
	else: variants.draw_ground(self)

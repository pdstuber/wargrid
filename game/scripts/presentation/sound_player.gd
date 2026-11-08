extends Node2D

const SoundDirector = preload("res://scripts/presentation/sound_director.gd")
var director: SoundDirector

func _init(local_player: int) -> void:
	name = "Sound"
	director = SoundDirector.new(local_player)

func collect_step(tick: int, events: Array[Dictionary], results: Array[Dictionary]) -> void:
	director.collect_step(tick, events, results)

func update(state: Dictionary) -> void:
	director.update(state)

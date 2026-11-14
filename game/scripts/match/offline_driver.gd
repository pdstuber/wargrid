extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const CommandRecorder = preload("res://scripts/playtest/command_recorder.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")

var sim: Simulation
var recorder: CommandRecorder
var _player: int
var _sequence: int = 0
var _factions: Dictionary = {}

func _init(player: int) -> void:
	_player = player

func create(map_path: String, starts: Array[int], factions: Dictionary, _match_seed: int) -> void:
	_factions = factions
	_sequence = 0
	recorder = null
	sim = Skirmish.create(true, "ai", factions, map_path, starts)

func start() -> void:
	pass

# Tests swap `driver.sim` directly; a recorder left on the old one would swallow commands.
func _recording() -> CommandRecorder:
	if recorder == null or not is_same(recorder.simulation(), sim): recorder = CommandRecorder.new(sim)
	return recorder

func step(after_tick: Callable) -> PackedStringArray:
	Skirmish.issue_opponent(_recording())
	sim.step()
	after_tick.call()
	return PackedStringArray()

func step_results() -> Array:
	return sim.command_results().duplicate(true)

func submit(payload: Dictionary) -> Dictionary:
	var state: Dictionary = sim.snapshot()
	var command: Dictionary = payload.duplicate(true)
	command.tick = command.get("tick",state.tick)
	command.player = _player
	for entry: Variant in state.last_sequences:
		if entry.player == _player: _sequence = maxi(_sequence,entry.sequence + 1)
	command.sequence = _sequence
	var result: Dictionary = _recording().issue_command(command)
	if result.ok: _sequence += 1
	return result

func notice() -> String:
	return ""

func pauses_sim() -> bool:
	return true

func confirm_leave() -> bool:
	return false

func can_restart() -> bool:
	return true

func over() -> bool:
	return sim.match_over()

func leave() -> void:
	pass

func detach() -> void:
	pass

func match_log() -> Dictionary:
	return {"mode": "offline", "factions": [_factions[1], _factions[2]], "commands": Lockstep.log_lines(_recording().commands())}

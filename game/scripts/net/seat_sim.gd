extends RefCounted

var _sim: RefCounted
var _lockstep: RefCounted

func _init(sim: RefCounted, lockstep: RefCounted) -> void:
	_sim = sim
	_lockstep = lockstep

func snapshot() -> Dictionary:
	return _sim.snapshot()

func tick() -> int:
	return _sim.tick()

func issue_command(command: Dictionary) -> Dictionary:
	_lockstep.submit(command)
	return {"ok": true, "error": ""}

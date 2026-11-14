extends "res://scripts/skirmish_main.gd"

const OnlineDriver = preload("res://scripts/match/online_driver.gd")

func setup(transport: RefCounted, lockstep: RefCounted, seat: int, faction: String = Skirmish.default_faction()) -> void:
	driver = OnlineDriver.new(transport, lockstep, seat, faction)
	local_player = seat

func _ready() -> void:
	super._ready()
	_perf.extra = driver.net_line
	driver.start()

func _exit_tree() -> void:
	driver.detach()

func _leave() -> void:
	driver.leave()
	super()

func _restart() -> void:
	pass

func _note() -> String:
	return _error + driver.notice()

func _refresh_hud(state: Dictionary) -> void:
	super._refresh_hud(state)
	var line: String = driver.notice()
	if not line.is_empty(): _status.text += "\n" + line
	$HUD/Restart.hide()

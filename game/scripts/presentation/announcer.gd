extends RefCounted

const EXPIRY_TICKS := 150
const COOLDOWN_TICKS := {"base_under_attack": 900, "building_lost": 900, "low_power": 3600}
# Zero Hour retail Eva.ini priorities; victory and defeat are not EVA lines, so they rank on top.
const PRIORITY := {"victory": 9, "defeat": 9, "building_lost": 8, "base_under_attack": 7, "insufficient_funds": 3, "low_power": 2, "construction_complete": 1, "unit_ready": 1}

var _waiting: Array[Dictionary] = []
var _last_started: Dictionary = {}

static func path(line: String) -> String:
	return "res://audio/voice/%s.wav" % line

func request(line: String, tick: int) -> void:
	for entry: Dictionary in _waiting:
		if entry.line == line: return
	if tick - _last_started.get(line, -1000000) < COOLDOWN_TICKS.get(line, 0): return
	_waiting.append({"line": line, "tick": tick})

func next(tick: int, busy: bool) -> String:
	_waiting = _waiting.filter(func(entry: Dictionary) -> bool: return tick - entry.tick <= EXPIRY_TICKS)
	if busy or _waiting.is_empty(): return ""
	var best: Dictionary = _waiting[0]
	for entry: Dictionary in _waiting:
		if PRIORITY[entry.line] > PRIORITY[best.line]: best = entry
	_waiting.erase(best)
	_last_started[best.line] = tick
	return best.line

func clear() -> void:
	_waiting.clear()
	_last_started.clear()

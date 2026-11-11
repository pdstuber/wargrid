class_name PresentationClock
extends RefCounted

const RETRY_TICKS := 150
const SHARE_WINDOW := 300

var _pending := false
var _pending_frame := -1
var _last_step_frame := -1
var _immediate_until := 0
var _split := 0
var _fallback := 0

# Called after each simulation step. True: refresh now, in this frame.
func stepped(frame_id: int, tick: int) -> bool:
	_last_step_frame = frame_id
	if tick < _immediate_until:
		_count(false)
		return true
	if not _pending:
		_pending = true
		_pending_frame = frame_id
	return false

# Called once per rendered frame. True: refresh now.
func rendered(frame_id: int, tick: int) -> bool:
	if not _pending or _pending_frame == frame_id: return false
	_pending = false
	# shortcut: no idle frame came between two ticks, so splitting cannot help at this frame rate; retry later.
	var idle := _last_step_frame != frame_id
	if not idle: _immediate_until = tick + RETRY_TICKS
	_count(idle)
	return true

# Share of recent refreshes that ran in an idle frame.
func split_share() -> float:
	var total := _split + _fallback
	return float(_split) / total if total > 0 else 0.0

func _count(is_split: bool) -> void:
	if is_split: _split += 1
	else: _fallback += 1
	if _split + _fallback > SHARE_WINDOW:
		_split /= 2
		_fallback /= 2

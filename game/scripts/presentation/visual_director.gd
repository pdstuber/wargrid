extends RefCounted

const Shapes = preload("res://scripts/presentation/shapes.gd")
const MAX_PENDING := 8
const MAX_EFFECTS := 256
const FADE_TICKS := 60
const MUZZLE_TICKS := 4
const HIT_TICKS := 6
const TURRET_RATE := 0.15

var dropped: int = 0
var _pending: Array[Dictionary] = []
var _consumed: Array[int] = []
var _effects: Array[Dictionary] = []
var _angles: Dictionary = {}
var _anchors: Dictionary = {}
var _previous: Dictionary = {}
var _last_collected: int = -1
var _has_turret: Dictionary = {}

func collect_step(tick: int, events: Array[Dictionary], _results: Array[Dictionary]) -> void:
	if tick <= _last_collected: return
	_last_collected = tick
	_pending.append({"tick": tick, "events": events.duplicate(true)})
	if _pending.size() > MAX_PENDING:
		_pending.pop_front()
		dropped += 1

func update(objects: Array[Dictionary]) -> void:
	_previous = _anchors
	_anchors = {}
	for object: Dictionary in objects: _anchors[object.id] = object.anchor
	_age()
	for step: Dictionary in _pending:
		_consume(step)
		_consumed.append(step.tick)
	if _consumed.size() > MAX_PENDING: _consumed = _consumed.slice(-MAX_PENDING)
	_pending.clear()
	if _effects.size() > MAX_EFFECTS: _effects = _effects.slice(-MAX_EFFECTS)
	_aim(objects)

func effects() -> Array[Dictionary]:
	return _effects

func turret_angles() -> Dictionary:
	return _angles

func consumed_ticks() -> Array[int]:
	return _consumed

func reset() -> void:
	_pending.clear()
	_consumed.clear()
	_effects.clear()
	_angles.clear()
	_anchors = {}
	_previous = {}
	_last_collected = -1
	dropped = 0

func _age() -> void:
	var live: Array[Dictionary] = []
	for effect: Dictionary in _effects:
		effect.age += 1
		if effect.age < _life(effect.type): live.append(effect)
	_effects = live

func _life(type: StringName) -> int:
	return FADE_TICKS if type == &"fade" else (MUZZLE_TICKS if type == &"muzzle" else HIT_TICKS)

func _consume(step: Dictionary) -> void:
	var seen := {}
	for event: Dictionary in step.events:
		if event.type == "shot":
			_add_once(seen, &"muzzle", event.attacker_id, 0)
			_add_once(seen, &"hit", event.target_id, 1)
		elif event.type == "death":
			_add_once(seen, &"fade", event.object_id, 2)

func _add_once(seen: Dictionary, type: StringName, id: int, slot: int) -> void:
	var key: int = id * 4 + slot
	var anchor: Variant = _anchors.get(id, _previous.get(id))
	if seen.has(key) or anchor == null: return
	seen[key] = true
	_effects.append({"type": type, "anchor": anchor, "age": 0, "id": id})

func _aim(objects: Array[Dictionary]) -> void:
	for id: int in _angles.keys():
		if not _anchors.has(id): _angles.erase(id)
	for object: Dictionary in objects:
		var id: int = object.id
		if object.target_id < 0 and not _angles.has(id): continue
		if not _turreted(object.role): continue
		var current: float = _angles.get(id, object.heading)
		var goal: float = object.heading
		if object.target_id >= 0:
			var target: Variant = _anchors.get(object.target_id)
			if target == null: continue
			goal = (target - object.anchor).angle()
		var step: float = clampf(wrapf(goal - current, -PI, PI), -TURRET_RATE, TURRET_RATE)
		if object.target_id < 0 and is_equal_approx(wrapf(goal - current, -PI, PI), step): _angles.erase(id)
		else: _angles[id] = wrapf(current + step, -PI, PI)

func _turreted(role: StringName) -> bool:
	if not _has_turret.has(role):
		_has_turret[role] = Shapes.parts(role, 0).any(func(part: Dictionary) -> bool: return part.name == &"turret")
	return _has_turret[role]

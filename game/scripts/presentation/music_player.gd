extends AudioStreamPlayer

const GAP_SECONDS := 25.0
const MENU := "res://audio/music/stay_the_course.ogg"
const PLAYLIST: Array[String] = [
	"res://audio/music/conflict.ogg", "res://audio/music/enemy_spotted.ogg", "res://audio/music/mammoth.ogg",
	"res://audio/music/stay_the_course.ogg", "res://audio/music/hitman.ogg",
]
var _paths: Array[String] = []
var _gap: float = 0.0
var _index: int = 0
var _wait: float = -1.0
var _rng: RandomNumberGenerator

func _init() -> void:
	name = "Music"
	bus = &"Music"
	finished.connect(func() -> void: _wait = _gap)

static func shuffled(paths: Array[String], rng: RandomNumberGenerator) -> Array[String]:
	var order := paths.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var held: String = order[i]
		order[i] = order[j]
		order[j] = held
	return order

static var _last_played: String = ""

static func avoiding(order: Array[String], last: String, rng: RandomNumberGenerator) -> Array[String]:
	if order[0] != last: return order
	var j: int = rng.randi_range(1, order.size() - 1)
	order[0] = order[j]
	order[j] = last
	return order

func play_list(paths: Array[String], gap: float) -> void:
	_paths = paths
	_gap = gap
	_index = 0
	_play_current()

func play_match(rng: RandomNumberGenerator, gap: float) -> void:
	_rng = rng
	play_list(avoiding(shuffled(PLAYLIST, rng), _last_played, rng), gap)

func advance(delta: float) -> void:
	if _wait < 0.0: return
	_wait -= delta
	if _wait > 0.0: return
	_wait = -1.0
	_index = (_index + 1) % _paths.size()
	if _index == 0 and _rng != null: _paths = avoiding(shuffled(_paths, _rng), _paths[_paths.size() - 1], _rng)
	_play_current()

func track_index() -> int:
	return _index

func waiting() -> bool:
	return _wait >= 0.0

func _process(delta: float) -> void:
	advance(delta)

func _play_current() -> void:
	_wait = -1.0
	stream = load(_paths[_index])
	if _rng != null: _last_played = _paths[_index]
	# Headless runs (tests) would exit with the ogg playback still queued in the audio server, which Godot reports as a leak.
	if is_inside_tree() and DisplayServer.get_name() != "headless": play()

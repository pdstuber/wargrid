extends Node2D

const SoundDirector = preload("res://scripts/presentation/sound_director.gd")
const Announcer = preload("res://scripts/presentation/announcer.gd")
const Cues = preload("res://scripts/presentation/sound_cues.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const WORLD_VOICES := 25
const UI_VOICES := 2
# Godot's 2D gain is pow(1 - d / max, a); a = 0.5 fits the -6 dB per doubling target between 7 and 28 cells (docs/reference/sound-spike.md).
const ATTENUATION := 0.5
const MAX_DISTANCE_PX := 1145.0

var director: SoundDirector
var _world: Array[AudioStreamPlayer2D] = []
var _ui: Array[AudioStreamPlayer] = []
var _world_cues: Array[String] = []
var _ui_cues: Array[String] = []
var _voice := AudioStreamPlayer.new()
var _streams: Dictionary = {}
var _last: Array[Dictionary] = []

func _init(local_player: int) -> void:
	name = "Sound"
	director = SoundDirector.new(local_player)

func _ready() -> void:
	_voice.bus = &"Voice"
	add_child(_voice)
	for i in WORLD_VOICES:
		var player := AudioStreamPlayer2D.new()
		player.bus = &"Effects"
		player.max_distance = MAX_DISTANCE_PX
		player.attenuation = ATTENUATION
		add_child(player)
		_world.append(player)
		_world_cues.append("")
	for i in UI_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"Effects"
		add_child(player)
		_ui.append(player)
		_ui_cues.append("")
	for button: Node in get_parent().find_children("*", "BaseButton", true, false): _watch(button)
	get_tree().node_added.connect(_on_node_added)

func collect_step(tick: int, events: Array[Dictionary], results: Array[Dictionary]) -> void:
	director.collect_step(tick, events, results)

func update(state: Dictionary) -> void:
	play(director.update(state))
	var line: String = director.announcer.next(state.get("tick", 0), _voice.playing)
	if line.is_empty(): return
	_voice.stream = load(Announcer.path(line))
	_voice.play()

func rejected(error: String) -> void:
	director.rejected(error)

func last_requests() -> Array[Dictionary]:
	return _last

func play(requests: Array[Dictionary]) -> void:
	_last = requests
	var world: Array[Dictionary] = []
	var ui: Array[Dictionary] = []
	for request: Dictionary in requests: (world if request.position != null else ui).append(request)
	var camera: Camera2D = get_viewport().get_camera_2d() if is_inside_tree() else null
	var listener: Vector2 = camera.get_screen_center_position() if camera != null else Vector2.ZERO
	_fill(world, plan(world, _playing(_world, _world_cues), listener, MAX_DISTANCE_PX), _world, _world_cues)
	_fill(ui, plan(ui, _playing(_ui, _ui_cues), listener, MAX_DISTANCE_PX), _ui, _ui_cues)

# Returns per request a pool slot, or -1 when it is out of earshot, over its cue limit or no slot is free.
static func plan(requests: Array[Dictionary], playing: Array[String], listener: Vector2, max_distance: float) -> Array[int]:
	var slots: Array[String] = playing.duplicate()
	var result: Array[int] = []
	for request: Dictionary in requests:
		var slot: int = -1
		var heard: bool = request.position == null or Iso.world_to_plane(request.position).distance_to(listener) <= max_distance
		if heard and slots.count(request.cue) < Cues.CUES[request.cue].limit: slot = slots.find("")
		if slot != -1: slots[slot] = request.cue
		result.append(slot)
	return result

func _playing(players: Array, cues: Array[String]) -> Array[String]:
	var playing: Array[String] = []
	for i in players.size(): playing.append(cues[i] if players[i].playing else "")
	return playing

func _fill(requests: Array[Dictionary], slots: Array[int], players: Array, cues: Array[String]) -> void:
	for i in requests.size():
		if slots[i] == -1: continue
		var request: Dictionary = requests[i]
		var player: Node = players[slots[i]]
		player.stream = _stream(request.sound)
		player.pitch_scale = request.pitch
		player.volume_db = Cues.CUES[request.cue].gain_db
		if request.position != null: player.position = Iso.world_to_plane(request.position)
		cues[slots[i]] = request.cue
		player.play()

func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound): _streams[sound] = load(Cues.path(sound))
	return _streams[sound]

func _on_node_added(node: Node) -> void:
	if node is BaseButton and get_parent().is_ancestor_of(node): _watch(node)

func _watch(button: Node) -> void:
	(button as BaseButton).pressed.connect(_click)

func _click() -> void:
	var requests: Array[Dictionary] = [director.ui_request("click")]
	play(requests)

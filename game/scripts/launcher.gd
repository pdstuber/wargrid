extends Control

const Lockstep = preload("res://scripts/net/lockstep.gd")
const RelayTransport = preload("res://scripts/net/relay_transport.gd")
const Wire = preload("res://scripts/net/wire.gd")
const OnlineScene = preload("res://scenes/online_skirmish.tscn")
const OFFLINE_SCENE: String = "res://scenes/skirmish.tscn"
const HEADLESS_FLAGS: Array[String] = ["--netclient", "--relay", "--replay-log", "--probe-relay"]
var _transport: RefCounted
var _match: String = ""
var _seat: int = 0
var _hello_sent: bool = false
var _lockstep: RefCounted
@onready var _status: Label = $Center/Box/Status

func _ready() -> void:
	# Release exports reject a scene path argument, so CI and Task 10 reach the headless client through these flags.
	for flag in HEADLESS_FLAGS:
		if flag in OS.get_cmdline_user_args():
			get_tree().change_scene_to_file.call_deferred("res://scenes/net_headless.tscn")
			return
	$Center/Box/Offline.pressed.connect(_play_offline)
	$Center/Box/Create.pressed.connect(_connect.bind(""))
	$Center/Box/JoinRow/Join.pressed.connect(func() -> void: _connect($Center/Box/JoinRow/Code.text.strip_edges().to_upper()))
	set_process(false)

func _play_offline() -> void:
	get_tree().change_scene_to_file(OFFLINE_SCENE)

func _connect(code: String) -> void:
	_match = code
	_hello_sent = false
	_transport = RelayTransport.new()
	var error: Error = _transport.connect_to($Center/Box/RelayUrl.text.strip_edges())
	if error != OK:
		_fail("Cannot connect to relay")
		return
	_status.text = "Connecting…"
	_set_busy(true)
	set_process(true)

func _set_busy(busy: bool) -> void:
	for path in ["Offline", "Create", "RelayUrl", "JoinRow/Code", "JoinRow/Join"]:
		var control: Control = get_node("Center/Box/" + path)
		if control is BaseButton: control.disabled = busy
		else: control.editable = not busy

func _fail(reason: String) -> void:
	_status.text = reason
	_transport = null
	_set_busy(false)
	set_process(false)

func _process(_delta: float) -> void:
	var frames: PackedStringArray = _transport.poll()
	if _transport.is_open() and not _hello_sent:
		_hello_sent = true
		_transport.send_text(Wire.encode({"type": "hello", "protocol": Wire.PROTOCOL, "build": str(ProjectSettings.get_setting("application/config/version")), "match": _match}))
	for text in frames:
		if _lockstep != null: _lockstep.receive(text)
		elif not _handle(text): return
	if _transport.closed() or _transport.silent(Time.get_ticks_usec()): _fail("Connection to relay lost")

func _handle(text: String) -> bool:
	var decoded: Dictionary = Wire.decode(text)
	if not decoded.ok:
		_fail("Protocol error: " + decoded.error)
		return false
	var message: Dictionary = decoded.message
	match message.type:
		"welcome":
			_seat = message.seat
			_status.text = "Match code: %s — waiting for player 2" % message.match if _seat == 1 else "Joined match %s" % message.match
		"start": _start(message)
		"error":
			_transport.close()
			_fail(message.reason)
			return false
		_:
			_fail("Protocol error: unexpected " + message.type)
			return false
	return true

func _start(message: Dictionary) -> void:
	var seats: Array[int] = []
	seats.assign(message.seats)
	_lockstep = Lockstep.new(_seat, seats, message.delay)
	var game: Node = OnlineScene.instantiate()
	game.setup(_transport, _lockstep, _seat)
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	queue_free()

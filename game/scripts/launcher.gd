extends Control

const Lockstep = preload("res://scripts/net/lockstep.gd")
const RelayTransport = preload("res://scripts/net/relay_transport.gd")
const Wire = preload("res://scripts/net/wire.gd")
const OnlineScene = preload("res://scenes/online_skirmish.tscn")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const SoundPlayer = preload("res://scripts/presentation/sound_player.gd")
const MusicPlayer = preload("res://scripts/presentation/music_player.gd")
const VolumeSliders = preload("res://scripts/presentation/volume_sliders.gd")
const SkirmishMain = preload("res://scripts/skirmish_main.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const Credits = preload("res://scripts/presentation/credits.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const FocusCardView = preload("res://scripts/playtest/focus_card_view.gd")
const OFFLINE_SCENE: String = "res://scenes/skirmish.tscn"
const HEADLESS_FLAGS: Array[String] = ["--netclient", "--relay", "--replay-log", "--probe-relay"]
var _transport: RefCounted
var _match: String = ""
var _seat: int = 0
var _code: String = ""
var _hello_sent: bool = false
var _lockstep: RefCounted
@onready var _status: Label = $Center/Box/Status

func _ready() -> void:
	# Release exports reject a scene path argument, so CI and Task 10 reach the headless client through these flags.
	for flag in HEADLESS_FLAGS:
		if flag in OS.get_cmdline_user_args():
			get_tree().change_scene_to_file.call_deferred("res://scenes/net_headless.tscn")
			return
	_fill_factions()
	_fill_maps()
	_add_audio()
	_add_playtest()
	$Center/Box/Offline.pressed.connect(func() -> void:
		_offline_setup()
		get_tree().change_scene_to_file(OFFLINE_SCENE))
	$Center/Box/Create.pressed.connect(_connect.bind(""))
	$Center/Box/JoinRow/Join.pressed.connect(func() -> void: _connect($Center/Box/JoinRow/Code.text.strip_edges().to_upper()))
	$Center/Box/Credits.pressed.connect(_show_credits.bind(true))
	$CreditsPanel/Box/Close.pressed.connect(_show_credits.bind(false))
	$Center/Box/WaitRow/Copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(_code))
	$Center/Box/WaitRow/Cancel.pressed.connect(func() -> void:
		_transport.close()
		_fail("Match cancelled"))
	set_process(false)

func _show_credits(open: bool) -> void:
	var text: RichTextLabel = $CreditsPanel/Box/Text
	if open and text.text.is_empty():
		text.text = Credits.text(FileAccess.get_file_as_string("res://audio/CREDITS.md"), FileAccess.get_file_as_string("res://data/maps/NOTICE.md"), Engine.get_license_text(), Engine.get_copyright_info(), Engine.get_license_info())
	$CreditsPanel.visible = open
	$Center.visible = not open

func _add_playtest() -> void:
	var box: VBoxContainer = $Center/Box
	var toggle := CheckButton.new()
	toggle.name = "PlaytestSwitch"
	toggle.text = "Playtest helper"
	toggle.button_pressed = PlaytestSettings.enabled()
	box.add_child(toggle)
	box.move_child(toggle, $Center/Box/Credits.get_index())
	var cards: Array[Dictionary] = FocusCards.load_cards()
	if cards.is_empty(): return
	var panel := FocusCardView.new(cards, PlaytestSession.open_count)
	add_child(panel)
	var build := Button.new()
	build.name = "ThisBuild"
	build.visible = toggle.button_pressed
	box.add_child(build)
	box.move_child(build, $Center/Box/Offline.get_index() + 1)
	var show_panel := func(open: bool) -> void:
		build.text = "This build: " + FocusCards.card(FocusCards.chosen, cards).title
		panel.visible = open
		$Center.visible = not open
	show_panel.call(false)
	build.pressed.connect(show_panel.bind(true))
	panel.get_node("Box/Close").pressed.connect(show_panel.bind(false))
	toggle.toggled.connect(func(on: bool) -> void:
		PlaytestSettings.save_enabled(on)
		build.visible = on)

func _add_audio() -> void:
	add_child(SoundPlayer.new(0))
	var music := MusicPlayer.new()
	add_child(music)
	music.play_list([MusicPlayer.MENU], 0.0)
	var sliders := VolumeSliders.new()
	$Center/Box.add_child(sliders)
	$Center/Box.move_child(sliders, $Center/Box/WaitRow.get_index())

func _fill_factions() -> void:
	var ids: Array = Registry.Factions.FACTIONS.keys()
	ids.sort()
	for selector: OptionButton in [$Center/Box/FactionRow/Own, $Center/Box/FactionRow/Opponent]:
		for id: String in ids:
			selector.add_item(Registry.faction(id).display_name)
			selector.set_item_metadata(selector.item_count - 1, id)
		selector.select(maxi(ids.find(Registry.Factions.DEFAULT_FACTION), 0))

func _faction(selector: OptionButton) -> String:
	return selector.get_item_metadata(selector.selected)

func _fill_maps() -> void:
	var selector: OptionButton = $Center/Box/Map
	for id: String in MatchSettings.PLAY_MAPS:
		selector.add_item(MatchSettings.PLAY_MAPS[id])
		selector.set_item_metadata(selector.item_count - 1, id)

func _map_id() -> String:
	var selector: OptionButton = $Center/Box/Map
	return selector.get_item_metadata(selector.selected)

func _offline_setup() -> void:
	var id: String = _map_id()
	SkirmishMain.factions = {1: _faction($Center/Box/FactionRow/Own), 2: _faction($Center/Box/FactionRow/Opponent)}
	SkirmishMain.map_path = MatchSettings.map_path(id)
	SkirmishMain.match_seed = randi()
	SkirmishMain.starts = MatchSettings.starts(id, SkirmishMain.match_seed)

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
	for path: String in ["Offline", "Create", "RelayUrl", "JoinRow/Code", "JoinRow/Join", "FactionRow/Own", "FactionRow/Opponent", "Map"]:
		var control: Control = get_node("Center/Box/" + path)
		if control is BaseButton: control.disabled = busy
		else: control.editable = not busy

func _fail(reason: String) -> void:
	_status.text = reason
	_transport = null
	$Center/Box/WaitRow.hide()
	_set_busy(false)
	set_process(false)

func _process(_delta: float) -> void:
	if _transport == null: return
	var frames: PackedStringArray = _transport.poll()
	if _transport.is_open() and not _hello_sent:
		_hello_sent = true
		var hello: Dictionary = {"type": "hello", "protocol": Wire.PROTOCOL, "build": str(ProjectSettings.get_setting("application/config/version")), "match": _match}
		if _match.is_empty(): hello["settings"] = MatchSettings.for_map(_map_id())
		_transport.send_text(Wire.encode(hello))
	for text in frames:
		if _lockstep != null: _lockstep.receive(text)
		elif not _handle(text): return
	if _transport.closed() or _transport.silent(Time.get_ticks_usec()): _fail("Connection to relay lost")

func _handle(text: String) -> bool:
	var decoded: Dictionary = Wire.decode(text)
	if not decoded.ok:
		_transport.close()
		_fail("Protocol error: " + decoded.error)
		return false
	var message: Dictionary = decoded.message
	match message.type:
		"welcome":
			_seat = message.seat
			_code = message.match
			$Center/Box/WaitRow.visible = _seat == 1
			_status.text = "Match code: %s — waiting for player 2" % message.match if _seat == 1 else "Joined match %s" % message.match
		"start": return _start(message)
		"error":
			_transport.close()
			_fail(message.reason)
			return false
		_:
			_transport.close()
			_fail("Protocol error: unexpected " + message.type)
			return false
	return true

func _start(message: Dictionary) -> bool:
	var reason: String = MatchSettings.refusal(message.settings)
	if not reason.is_empty():
		_transport.close()
		_fail(reason)
		return false
	var seats: Array[int] = []
	seats.assign(message.seats)
	_lockstep = Lockstep.new(_seat, seats, message.delay)
	var id: String = message.settings.map
	SkirmishMain.map_path = MatchSettings.map_path(id)
	SkirmishMain.match_seed = message.seed
	SkirmishMain.starts = MatchSettings.starts(id, message.seed)
	$Center/Box/WaitRow.hide()
	var game: Node = OnlineScene.instantiate()
	game.setup(_transport, _lockstep, _seat, _faction($Center/Box/FactionRow/Own))
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	queue_free()
	return true

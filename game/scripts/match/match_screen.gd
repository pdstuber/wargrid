extends Node

const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const PerfOverlay = preload("res://scripts/presentation/perf_overlay.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const OfflineDriver = preload("res://scripts/match/offline_driver.gd")
const OnlineDriver = preload("res://scripts/match/online_driver.gd")
const Orders = preload("res://scripts/match/orders.gd")
const LAUNCHER_SCENE: String = "res://scenes/launcher.tscn"
const MapData = preload("res://scripts/simulation/map_data.gd")
const ZOOMS: Array[float] = [0.5, 1.0, 2.0]
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const UiStyle = preload("res://scripts/presentation/ui_style.gd")
const MENU_COLUMNS: int = 4
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const View = preload("res://scripts/presentation/world_view.gd")
const SoundPlayer = preload("res://scripts/presentation/sound_player.gd")
const VisualDirector = preload("res://scripts/presentation/visual_director.gd")
const MusicPlayer = preload("res://scripts/presentation/music_player.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const PlaytestOverlay = preload("res://scripts/playtest/playtest_overlay.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const AUTO_FRAMES: int = 120
const AUTO_SKIP_FRAMES: int = 60
static var factions: Dictionary = Registry.Factions.DEFAULT_SKIRMISH
static var map_path: String = Skirmish.MAP_PATH
static var starts: Array[int] = []
static var match_seed: int = 0
var driver: RefCounted
var orders: RefCounted = Orders.new(self)
var local_player: int = 1
var stepped_results: Array = []
var _error: String = ""
var _shown_note: String = ""
var _last_result_tick: int = -1
var _last_result_sequence: int = -1
var _camera_bounds: Rect2
@onready var _view: Node2D = $WorldView
@onready var _camera: Camera2D = $Camera2D
var _perf: Label
var _clock := PresentationClock.new()
var _pause: Control
var change_scene: Callable = _change_scene
@onready var _status: Label = $HUD/Status
@onready var _selection_box: ReferenceRect = $HUD/SelectionBox
var _sound: SoundPlayer = null
var _auto_samples := PackedFloat32Array()
var _auto_pending: bool = false
var _auto_frame: int = 0
var _auto_tick_usec: int = 0
var _visuals := VisualDirector.new()
var _playtest: PlaytestOverlay

func setup(transport: RefCounted, lockstep: RefCounted, seat: int, faction: String = Skirmish.default_faction()) -> void:
	driver = OnlineDriver.new(transport, lockstep, seat, faction)
	local_player = seat

func _ready() -> void:
	if driver == null: driver = OfflineDriver.new(local_player)
	$HUD/Status.theme = UiStyle.hud_theme()
	$HUD/Economy.theme = UiStyle.hud_theme()
	var menu := GridContainer.new()
	menu.name = "BuildMenu"
	menu.columns = MENU_COLUMNS
	$HUD/Economy.add_child(menu)
	$HUD/Economy.move_child(menu,0)
	_perf = PerfOverlay.new()
	$HUD.add_child(_perf)
	_pause = PauseMenu.new()
	_pause.confirm_leave = _confirm_leave()
	_pause.resume_requested.connect(_pause.close)
	_pause.leave_requested.connect(_leave)
	_pause.quit_requested.connect(func() -> void: get_tree().quit())
	_pause.quality_changed.connect(_view.set_quality)
	_pause.neon_changed.connect(_view.set_bright_owners)
	_pause.smooth_changed.connect(_view.set_smooth)
	_pause.destinations_changed.connect(_view.set_show_destinations)
	$HUD.add_child(_pause)
	_view.set_quality(GraphicsSettings.stored_quality())
	_view.set_bright_owners(GraphicsSettings.load_neon())
	_view.set_smooth(GraphicsSettings.load_smooth())
	_view.set_show_destinations(GraphicsSettings.load_destinations())
	_view.local_player = local_player
	_create_world()
	_clock = PresentationClock.new()
	_reset_camera()
	_refresh()
	$HUD/Economy/Produce.pressed.connect(orders._produce_selected)
	$HUD/Economy/CancelBuild.pressed.connect(orders._cancel_build)
	_view.set_visuals(_visuals)
	_start_auto_pick(GraphicsSettings.load_quality() == -1 and DisplayServer.get_name() != "headless")
	$HUD/Restart.pressed.connect(_restart)
	var music := MusicPlayer.new()
	add_child(music)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	music.play_match(rng, MusicPlayer.GAP_SECONDS)
	_add_playtest()
	if driver.has_method("net_line"): _perf.extra = driver.net_line
	driver.start()

func _exit_tree() -> void:
	driver.detach()

func _add_playtest() -> void:
	_playtest = PlaytestOverlay.new()
	_playtest.setup(FocusCards.card(FocusCards.shown(), FocusCards.load_cards()), playtest_context, playtest_match)
	$HUD.add_child(_playtest)
	$HUD.move_child(_playtest, _pause.get_index())
	_pause.opened.connect(_playtest.observe_menu)
	_pause.playtest_changed.connect(_playtest.set_active)
	_playtest.set_active(PlaytestSettings.enabled())

func _reset_camera() -> void:
	var size: Array = driver.sim.snapshot().map.size
	_camera_bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
	for corner: Variant in [Vector2(size[0], 0), Vector2(0, size[1]), Vector2(size[0], size[1])]:
		_camera_bounds = _camera_bounds.expand(Iso.world_to_plane(corner))
	var map: Dictionary = driver.sim.map_data()
	var start := MapData.start_cell(map, local_player) if not map.is_empty() else Vector2i(-1, -1)
	var focus := Vector2(start) + Vector2(0.5, 0.5) if start.x >= 0 else Vector2(size[0], size[1]) / 2.0
	_camera.position = Iso.world_to_plane(focus)

func _create_world() -> void:
	driver.create(map_path, starts, factions, match_seed)

func playtest_context() -> Dictionary:
	var camera: Vector2 = Iso.plane_to_world(_camera.position)
	return {"tick": driver.sim.tick(), "camera": [camera.x, camera.y], "selected": orders.view_selection(), "over": driver.over(), "menu": _pause.visible}

func playtest_match() -> Dictionary:
	var played: Dictionary = driver.match_log()
	return _match_record(played.mode, played.factions, played.commands)

func _match_record(mode: String, match_factions: Array, lines: PackedStringArray) -> Dictionary:
	var state: Dictionary = driver.sim.snapshot()
	return {"mode": mode, "map": map_path.get_file().get_basename(), "seed": match_seed, "factions": match_factions, "seat": local_player, "end_tick": state.tick, "end_digest": StateHash.digest(state), "build": PlaytestSettings.build_id(), "result": _result_text(state.match), "commands": lines}

func _step_simulation() -> void:
	var rejected: PackedStringArray = driver.step(_collect_sound)
	if rejected.is_empty(): return
	_ensure_sound()
	for error in rejected: _sound.rejected(error)
	_error = "Rejected: " + rejected[-1]

func menu_open() -> bool:
	return _pause.visible or _playtest.holds_match()

func _confirm_leave() -> bool:
	return driver.confirm_leave()

func _pauses_sim() -> bool:
	return driver.pauses_sim()

func _escape_pending() -> bool:
	return not driver.sim.match_over() and orders.escape_pending()

func _leave() -> void:
	driver.leave()
	if _playtest.end_match():
		_pause.close()
		await _playtest.finished
	change_scene.call(LAUNCHER_SCENE)

func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if event.physical_keycode == KEY_F3: return
	if event.is_action_pressed("deselect"):
		if _pause.visible: _pause.back()
		elif not _escape_pending(): _pause.open()
		else: return
	elif not _pause.visible: return
	get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_step_frame()
	if _auto_pending: _auto_tick_usec += Time.get_ticks_usec() - started

func _step_frame() -> void:
	if menu_open() and _pauses_sim(): return
	var started: int = Time.get_ticks_usec()
	var tick_before: int = driver.sim.tick()
	_step_simulation()
	_perf.record_step((Time.get_ticks_usec() - started) / 1000.0)
	# A stall frame (online, waiting for the peer) is not a step frame; counting it would inflate the split share.
	var advanced: bool = driver.sim.tick() != tick_before
	if advanced: stepped_results.append_array(driver.sim.command_results().duplicate(true))
	if not is_processing() or (advanced and _clock.stepped(Engine.get_process_frames(), driver.sim.tick())) or (not advanced and _note() != _shown_note): _refresh()

func _present_if_due() -> bool:
	if not _clock.rendered(Engine.get_process_frames(), driver.sim.tick()): return false
	_refresh()
	return true

func _process(delta: float) -> void:
	var presented_at: int = Time.get_ticks_usec()
	if _present_if_due() and _auto_pending: _auto_tick_usec += Time.get_ticks_usec() - presented_at
	pan_camera(Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down"), delta)
	_view.advance_frame()
	if not _auto_pending: return
	_auto_sample((_auto_tick_usec + _view.draw_usec) / 1000.0)
	_auto_tick_usec = 0
	_view.draw_usec = 0

# shortcut: measured at match start on a nearly empty map, so it only catches very slow machines; re-check under load if playtesters report a slow High.
# The first frames hold scene load and lazy bakes, so they are skipped.
func _start_auto_pick(enabled: bool) -> void:
	_auto_pending = enabled
	_view.time_draws = enabled

func _auto_sample(frame_ms: float) -> void:
	if not _auto_pending: return
	_auto_frame += 1
	if _auto_frame <= AUTO_SKIP_FRAMES: return
	_auto_samples.append(frame_ms)
	if _auto_samples.size() < AUTO_FRAMES: return
	_start_auto_pick(false)
	_auto_samples.sort()
	var quality: int = GraphicsSettings.pick(_auto_samples[int(AUTO_FRAMES * 0.95)])
	GraphicsSettings.save_quality(quality)
	_view.set_quality(quality)

func pan_camera(direction: Vector2, delta: float) -> void:
	if orders.busy():
		return
	_camera.position += direction.normalized() * 400.0 * delta / _camera.zoom.x
	_camera.position = _camera.position.clamp(_camera_bounds.position, _camera_bounds.end)

func change_zoom(direction: int) -> void:
	if orders.busy():
		return
	var index: int = ZOOMS.find(_camera.zoom.x)
	index = clampi(index + signi(direction), 0, ZOOMS.size() - 1)
	_camera.zoom = Vector2.ONE * ZOOMS[index]
	_view.set_zoom(ZOOMS[index])

func _unhandled_input(event: InputEvent) -> void:
	orders.handle(event)

func _refresh() -> void:
	var state: Dictionary = driver.sim.view_state()
	_show(state)
	$HUD/Economy.position.y = maxf(116.0,_status.position.y + _status.get_minimum_size().y + 8.0)

func _note() -> String:
	return _error + driver.notice()

func _show(state: Dictionary) -> void:
	_shown_note = _note()
	_perf.set_counts(state.units.size(), state.get("buildings", []).size(), state.tick)
	_perf.split_share = _clock.split_share()
	var zone: int = Profiler.begin()
	orders.prune(state)
	Profiler.end(&"refresh.selection", zone)
	_view.set_view(state, orders.view_selection())
	zone = Profiler.begin()
	_refresh_hud(state)
	Profiler.end(&"refresh.hud", zone)
	stepped_results.clear()

func _show_hint(payload: Dictionary) -> void:
	var point: Variant = orders._hint_point(payload)
	if point != null: _view.add_hint(point, driver.sim.tick())

func _submit(payload: Dictionary) -> void:
	_show_hint(payload)
	var result: Dictionary = driver.submit(payload)
	_error = result.error
	_refresh()
	if not _error.is_empty(): _sound.rejected(_error)
	else: _playtest.observe_command(payload)
	if result.ok: _sound.order(payload)

func _ensure_sound() -> void:
	if _sound != null: return
	_sound = SoundPlayer.new(local_player)
	add_child(_sound)

func _collect_sound() -> void:
	_ensure_sound()
	_sound.collect_step(driver.sim.tick(), driver.sim.combat_events(), driver.sim.command_results())
	_visuals.collect_step(driver.sim.tick(), driver.sim.combat_events(), driver.sim.command_results())

func _build_hint() -> String:
	return "1-9: menu  U: unload"

func _production_kind(building: Dictionary, state: Dictionary) -> String:
	var kind: String = Skirmish.unit_for(_local_state(state).get("faction", Skirmish.default_faction()), building.kind)
	return kind if not kind.is_empty() else Definitions.building(building.kind).produces

func _local_state(state: Dictionary) -> Dictionary:
	for player: Dictionary in state.players:
		if player.id == local_player: return player
	return state.players[0]

func _building(state: Dictionary, id: int) -> Dictionary:
	for building: Dictionary in state.buildings:
		if building.id == id: return building
	return {}

func _refresh_hud(state: Dictionary) -> void:
	_ensure_sound()
	_economy_hud(state)
	_match_hud(state)
	var line: String = driver.notice()
	if not line.is_empty(): _status.text += "\n" + line
	if not driver.can_restart(): $HUD/Restart.hide()
	_sound.update(state)

func _economy_hud(state: Dictionary) -> void:
	for result: Dictionary in stepped_results + state.command_results:
		if result.player == local_player and (result.tick > _last_result_tick or (result.tick == _last_result_tick and result.sequence > _last_result_sequence)):
			_error = result.error
			_last_result_tick = result.tick
			_last_result_sequence = result.sequence
	var player: Dictionary = _local_state(state)
	var building: Dictionary = _building(state,orders.selected_building_id)
	var detail: String = "Units: " + str(orders.selected_ids)
	if not building.is_empty(): detail = "%s #%d | Work %d/%d" % [Registry.kind(building.kind).display_name,building.id,building.work,Definitions.building(building.kind).ticks * 1000]
	var resume: String = "Right-click: resume\n" if _view.resume_candidate() != -1 else ""
	var placing: String = Registry.kind(orders._placement_kind).get("display_name","")
	_status.text = "Credits: %d | Power: %d/%d | Tick: %d\n%s | Place: %s\n%s | Right: context/move | E: produce | Esc: cancel\n%s%s" % [player.credits,player.power_supply,player.power_demand,state.tick,detail,placing,_build_hint(),resume,_error]
	$HUD/Economy/Produce.visible = not building.is_empty() and building.completed and not _production_kind(building, state).is_empty()
	$HUD/Economy/CancelBuild.visible = not building.is_empty() and not building.completed
	_refresh_menu(_menu_kinds(state,building))
	_refresh_queue(building.get("queue",[]))

func _match_hud(state: Dictionary) -> void:
	var result: String = "" if state.match == null else _result_text(state.match)
	var building: Dictionary = _building(state, orders.selected_building_id)
	_view.set_inspected(orders.inspected_id)
	$HUD/Economy/Produce.text = "Produce %s (E)" % Registry.kind(_production_kind(building, state)).get("display_name", "") if not building.is_empty() else "Produce (E)"
	_status.text += "\n" + (_selected_summary(state) + _enemy_summary(state)) + ("A: attack-move click | S: stop | You are %s (P%d)" % [("blue" if local_player == 1 else "red"), local_player] if result.is_empty() else "")
	$HUD/Result.text = result
	$HUD/Result.visible = not result.is_empty()
	$HUD/Restart.visible = not result.is_empty()

func _menu_kinds(state: Dictionary, building: Dictionary) -> Array:
	if not building.is_empty(): return Registry.kind(building.kind).produces if building.completed else []
	var kind: String = Registry.faction(_local_state(state).get("faction",Registry.Factions.DEFAULT_FACTION)).get("start_unit","")
	if orders.selected_ids.size() == 1:
		var i: int = state.units.index_of(orders.selected_ids[0])
		var unit_kind: String = state.units.kinds[state.units.kind[i]] if i != -1 else ""
		if Registry.is_builder(unit_kind): kind = unit_kind
	return Registry.kind(kind).get("builds",[])

static func menu_label(index: int, kind: String) -> String:
	var quantity: int = Registry.kind(kind).get("quantity",1)
	return "%d: %s%s $%d" % [index + 1,Registry.kind(kind).display_name," x%d" % quantity if quantity > 1 else "",Registry.kind(kind).cost]

func _refresh_menu(kinds: Array) -> void:
	orders.menu = kinds
	var grid: GridContainer = $HUD/Economy/BuildMenu
	while grid.get_child_count() > kinds.size(): grid.get_child(grid.get_child_count() - 1).free()
	for i in kinds.size():
		var button: Button = grid.get_child(i) if i < grid.get_child_count() else null
		if button == null:
			button = Button.new()
			button.pressed.connect(orders._menu_choose.bind(i,false))
			grid.add_child(button)
		button.text = menu_label(i,kinds[i])

func _refresh_queue(queue: Array) -> void:
	var ids: Array = queue.map(func(entry: Dictionary) -> String: return str(entry.id))
	for child in $HUD/Economy/Queue.get_children():
		if not ids.has(str(child.name)): child.free()
	for entry: Variant in queue:
		var button: Button = $HUD/Economy/Queue.get_node_or_null(str(entry.id))
		if button == null:
			button = Button.new()
			button.name = str(entry.id)
			button.pressed.connect(orders._cancel_entry.bind(entry.id))
			$HUD/Economy/Queue.add_child(button)
		button.text = queue_label(entry)

static func queue_label(entry: Dictionary) -> String:
	var label: String = Registry.kind(entry.kind).display_name
	if entry.work == 0: return "Cancel %s (queued)" % label
	return "Cancel %s (%d%%)" % [label,entry.work * 100 / (Definitions.unit(entry.kind).ticks * 1000)]

func _restart() -> void:
	if not driver.can_restart(): return
	_playtest.begin_match()
	_create_world()
	_clock = PresentationClock.new()
	_sound.director.reset()
	_sound._unit_voice.stop()
	_visuals.reset()
	orders.reset()
	_error = ""
	stepped_results.clear()
	_last_result_tick = -1
	_last_result_sequence = -1
	_selection_box.hide()
	_camera.zoom = Vector2.ONE
	_view.set_zoom(1.0)
	_reset_camera()
	var empty: Array[Vector2i] = []
	_view.set_build_preview(empty, false)
	_refresh()

func _selected_summary(state: Dictionary) -> String:
	if orders.selected_ids.size() != 1: return ""
	var i: int = state.units.index_of(orders.selected_ids[0])
	if i == -1: return ""
	var unit: Dictionary = _unit_record(state.units, i)
	var line: String = "%s #%d HP %d/%d" % [Registry.kind(unit.kind).display_name, unit.id, unit.hp / 1000, unit.max_hp / 1000]
	if unit.combat != null: line += " | %s%s" % [unit.combat.mode, "" if unit.combat.target_id == null else " -> #" + str(unit.combat.target_id)]
	if unit.collection != null and unit.collection.enabled: line += _collection_suffix(state, unit)
	return line + "\n"

func _unit_record(units: RefCounted, i: int) -> Dictionary:
	var target: Variant = units.target[i] if units.target[i] != -1 else null
	var combat: Variant = {"mode": units.modes[units.mode[i]], "target_id": target} if units.mode[i] != ViewRows.NONE else null
	var collection: Variant = {"enabled": (units.flags[i] & ViewRows.COLLECTING) != 0, "phase": units.phases[units.phase[i]]} if units.phase[i] != ViewRows.NONE else null
	return {"id": units.id[i], "owner": units.owner[i], "kind": units.kinds[units.kind[i]], "hp": units.hp[i], "max_hp": units.max_hp[i], "combat": combat, "collection": collection}

func _collection_suffix(state: Dictionary, unit: Dictionary) -> String:
	var line: String = " | " + unit.collection.phase
	if unit.collection.phase.begins_with("waiting_"): line += " (%s in line)" % _ordinal(View.line_position(state.units, state.units.index_of(unit.id)))
	return line

func _ordinal(n: int) -> String:
	var suffix: String = "th" if n % 100 in [11, 12, 13] else {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return str(n) + suffix

func _inspected(state: Dictionary) -> Dictionary:
	var i: int = state.units.index_of(orders.inspected_id)
	if i != -1: return _unit_record(state.units, i)
	for building: Dictionary in state.buildings:
		if building.id == orders.inspected_id: return building
	return {}

func _enemy_summary(state: Dictionary) -> String:
	var object: Dictionary = _inspected(state)
	if object.is_empty(): return ""
	var line: String = "Enemy (P%d) %s #%d HP %d/%d" % [object.owner, Registry.kind(object.kind).display_name, object.id, object.hp / 1000, object.max_hp / 1000]
	var combat: Variant = object.get("combat")
	if combat != null: line += " | " + combat.mode + ("" if combat.target_id == null else " -> #%d" % combat.target_id)
	return line + "\n"

func _result_text(match_state: Dictionary) -> String:
	if match_state.status == "draw": return "Draw"
	if match_state.status != "won": return ""
	return "Victory" if match_state.winner == driver.sim.team_of(local_player) else "Defeat"

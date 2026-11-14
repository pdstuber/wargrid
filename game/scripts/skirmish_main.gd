extends "res://scripts/base_main.gd"

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const View = preload("res://scripts/presentation/world_view.gd")
const SoundPlayer = preload("res://scripts/presentation/sound_player.gd")
const VisualDirector = preload("res://scripts/presentation/visual_director.gd")
const MusicPlayer = preload("res://scripts/presentation/music_player.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const PlaytestOverlay = preload("res://scripts/playtest/playtest_overlay.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
var _sound: SoundPlayer = null
var _auto_samples := PackedFloat32Array()
var _auto_pending: bool = false
var _auto_frame: int = 0
const AUTO_FRAMES: int = 120
const AUTO_SKIP_FRAMES: int = 60
var _auto_tick_usec: int = 0

var _visuals := VisualDirector.new()
var _attack_move_mode: bool = false
var inspected_id: int = -1
var _playtest: PlaytestOverlay
static var factions: Dictionary = Registry.Factions.DEFAULT_SKIRMISH
static var map_path: String = Skirmish.MAP_PATH
static var starts: Array[int] = []
static var match_seed: int = 0

func _ready() -> void:
	super._ready()
	_view.set_visuals(_visuals)
	_start_auto_pick(GraphicsSettings.load_quality() == -1 and DisplayServer.get_name() != "headless")
	$HUD/Restart.pressed.connect(_restart)
	var music := MusicPlayer.new()
	add_child(music)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	music.play_match(rng, MusicPlayer.GAP_SECONDS)
	_add_playtest()

func _add_playtest() -> void:
	_playtest = PlaytestOverlay.new()
	_playtest.setup(FocusCards.card(FocusCards.shown(), FocusCards.load_cards()), playtest_context, playtest_match)
	$HUD.add_child(_playtest)
	$HUD.move_child(_playtest, _pause.get_index())
	_pause.opened.connect(_playtest.observe_menu)
	_pause.playtest_changed.connect(_playtest.set_active)
	_playtest.set_active(PlaytestSettings.enabled())

func menu_open() -> bool:
	return super() or _playtest.holds_match()

func _create_world() -> void:
	driver.create(map_path, starts, factions, match_seed)

func playtest_context() -> Dictionary:
	var camera: Vector2 = Iso.plane_to_world(_camera.position)
	return {"tick": driver.sim.tick(), "camera": [camera.x, camera.y], "selected": _view_selection(), "over": driver.over(), "menu": _pause.visible}

func playtest_match() -> Dictionary:
	var played: Dictionary = driver.match_log()
	return _match_record(played.mode, played.factions, played.commands)

func _match_record(mode: String, match_factions: Array, lines: PackedStringArray) -> Dictionary:
	var state: Dictionary = driver.sim.snapshot()
	return {"mode": mode, "map": map_path.get_file().get_basename(), "seed": match_seed, "factions": match_factions, "seat": local_player, "end_tick": state.tick, "end_digest": StateHash.digest(state), "build": PlaytestSettings.build_id(), "result": _result_text(state.match), "commands": lines}

func _escape_pending() -> bool:
	return not driver.sim.match_over() and (_attack_move_mode or inspected_id != -1 or super())

func _step_simulation() -> void:
	var rejected: PackedStringArray = driver.step(_collect_sound)
	if rejected.is_empty(): return
	_ensure_sound()
	for error in rejected: _sound.rejected(error)
	_error = "Rejected: " + rejected[-1]

func _ensure_sound() -> void:
	if _sound != null: return
	_sound = SoundPlayer.new(local_player)
	add_child(_sound)

func _submit(payload: Dictionary) -> void:
	_show_hint(payload)
	var result: Dictionary = driver.submit(payload)
	_error = result.error
	_refresh()
	if not _error.is_empty(): _sound.rejected(_error)
	else: _playtest.observe_command(payload)
	if result.ok: _sound.order(payload)

func _collect_sound() -> void:
	_ensure_sound()
	_sound.collect_step(driver.sim.tick(), driver.sim.combat_events(), driver.sim.command_results())
	_visuals.collect_step(driver.sim.tick(), driver.sim.combat_events(), driver.sim.command_results())

func _production_kind(building: Dictionary, state: Dictionary) -> String:
	var kind: String = Skirmish.unit_for(_local_state(state).get("faction", Skirmish.default_faction()), building.kind)
	return kind if not kind.is_empty() else super._production_kind(building, state)

func _physics_process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	super(delta)
	if _auto_pending: _auto_tick_usec += Time.get_ticks_usec() - started

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

func _enter_placement(kind: String) -> void:
	_attack_move_mode = false
	super._enter_placement(kind)

func _leave() -> void:
	if _playtest.end_match():
		_pause.close()
		await _playtest.finished
	super()

func _restart() -> void:
	_playtest.begin_match()
	_create_world()
	_clock = PresentationClock.new()
	_sound.director.reset()
	_sound._unit_voice.stop()
	_visuals.reset()
	selected_ids.clear()
	selected_building_id = -1
	inspected_id = -1
	_placement_kind = ""
	_pending_placement = ""
	_attack_move_mode = false
	_selecting = false
	_dragged = false
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

func _ground(event: InputEventMouseButton) -> Vector2:
	return Iso.plane_to_world(_view.make_canvas_position_local(event.position))

func _finish_selection(point: Vector2) -> void:
	super._finish_selection(point)
	inspected_id = -1
	if not _dragged and selected_ids.is_empty(): inspected_id = _enemy_at(_view.make_canvas_position_local(point))
	_refresh()

func _enemy_at(plane: Vector2) -> int:
	var id: int = _view.pick_entity(plane, true)
	if id == -1: return _view.pick_target(plane, local_player)
	for unit: Dictionary in driver.sim.snapshot().entities:
		if unit.id == id: return id if unit.owner != local_player else -1
	return -1

func _unhandled_input(event: InputEvent) -> void:
	if driver.sim.match_over() or _playtest.holds_match():
		return
	if event.is_action_pressed("deselect"): inspected_id = -1
	if not _placement_kind.is_empty():
		super._unhandled_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and not is_selecting():
		if event.physical_keycode == KEY_A and not selected_ids.is_empty():
			_attack_move_mode = true
			return
		if event.physical_keycode == KEY_S and not selected_ids.is_empty():
			_submit({"type":"stop","entity_ids":selected_ids.duplicate()})
			return
	if _attack_move_mode and (event.is_action_pressed("deselect") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed)):
		_attack_move_mode = false
		return
	if _attack_move_mode and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_attack_move_mode = false
			var target: Vector2 = _ground(event)
			_submit({"type":"attack_move","entity_ids":selected_ids.duplicate(),"target":[target.x,target.y]})
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_selecting() and _order_defence(event):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_selecting() and not selected_ids.is_empty():
		var enemy: int = _view.pick_target(_view.make_canvas_position_local(event.position), local_player)
		if enemy != -1:
			_submit({"type":"attack","entity_ids":selected_ids.duplicate(),"target_id":enemy})
			return
	super._unhandled_input(event)

func _order_defence(event: InputEventMouseButton) -> bool:
	var building: Dictionary = _building(driver.sim.snapshot(), selected_building_id)
	if building.is_empty() or building.owner != local_player or not building.completed or building.get("combat") == null: return false
	var enemy: int = _view.pick_target(_view.make_canvas_position_local(event.position), local_player)
	if enemy == -1: return false
	_submit({"type":"defence_attack","building_id":building.id,"target_id":enemy})
	return true

func _selected_summary(state: Dictionary) -> String:
	if selected_ids.size() != 1: return ""
	var i: int = state.units.index_of(selected_ids[0])
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
	var i: int = state.units.index_of(inspected_id)
	if i != -1: return _unit_record(state.units, i)
	for building: Dictionary in state.buildings:
		if building.id == inspected_id: return building
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

func _refresh_hud(state: Dictionary) -> void:
	_ensure_sound()
	super._refresh_hud(state)
	_sound.update(state)
	var result: String = "" if state.match == null else _result_text(state.match)
	var building: Dictionary = _building(state, selected_building_id)
	if _inspected(state).is_empty(): inspected_id = -1
	_view.set_inspected(inspected_id)
	$HUD/Economy/Produce.text = "Produce %s (E)" % Registry.kind(_production_kind(building, state)).get("display_name", "") if not building.is_empty() else "Produce (E)"
	_status.text += "\n" + (_selected_summary(state) + _enemy_summary(state)) + ("A: attack-move click | S: stop | You are %s (P%d)" % [("blue" if local_player == 1 else "red"), local_player] if result.is_empty() else "")
	$HUD/Result.text = result
	$HUD/Result.visible = not result.is_empty()
	$HUD/Restart.visible = not result.is_empty()

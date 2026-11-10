extends Node

const Fight = preload("res://scripts/lab/lab_fight.gd")
const AbVariants = preload("res://scripts/lab/ab_variants.gd")
const AbOverlay = preload("res://scripts/lab/ab_overlay.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const VisualDirector = preload("res://scripts/presentation/visual_director.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const ZOOMS: Array[float] = [0.5, 1.0, 2.0]
const RESTART_TICK: int = 2400
const PAN_SPEED: float = 400.0

var fight: Fight = Fight.new()
var variants := AbVariants.new()
var question_index: int = 0
var quality: int = GraphicsSettings.HIGH
var zoom_index: int = 1
var picked_text: String = "none yet"
var paused: bool = false
var _previous: Dictionary = {}
var _current: Dictionary = {}
var _selected: Array[int] = []
var _visuals := VisualDirector.new()
var _ground := AbOverlay.new()
var _top := AbOverlay.new()
@onready var _view: Node2D = $WorldView
@onready var _camera: Camera2D = $Camera2D
@onready var _status: Label = $HUD/Status

func _ready() -> void:
	_view.set_visuals(_visuals)
	_ground.variants = variants
	_ground.show_behind_parent = true
	_view.add_child(_ground)
	_view.move_child(_ground, _view.get_node("Bodies").get_index())
	_top.variants = variants
	_top.on_top = true
	_view.add_child(_top)
	_camera.position = Iso.world_to_plane(Fight.FOCUS)
	_apply_view()
	advance()

func current_question() -> StringName:
	return AbVariants.QUESTIONS[question_index]

func advance() -> void:
	var sim := fight.simulation
	fight.step()
	_visuals.collect_step(sim.tick(), sim.combat_events(), sim.command_results())
	_previous = _current
	_current = sim.snapshot()
	variants.observe(_current, WorldBatch.objects(_current), sim.combat_events())
	_show(_current)
	if sim.tick() >= RESTART_TICK: restart()

func restart() -> void:
	fight = Fight.new()
	_visuals.reset()
	variants.reset()
	_previous = {}
	_current = {}
	_selected.clear()
	advance()

func _show(state: Dictionary) -> void:
	variants.focus = current_question()
	variants.apply(_view, _camera)
	_view.set_state(AbVariants.recolored(state, variants.opponent_owner), _selected)

func _physics_process(_delta: float) -> void:
	if not paused: advance()

func _process(delta: float) -> void:
	var pan := Vector2(int(Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_LEFT)), int(Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_UP)))
	_camera.position += pan.normalized() * PAN_SPEED * delta / _camera.zoom.x
	if variants.is_b(&"interpolation") and not paused: _show(AbVariants.interpolate(_previous, _current, Engine.get_physics_interpolation_fraction()))
	_ground.queue_redraw()
	_top.queue_redraw()
	_status.text = status_text()

func status_text() -> String:
	var question: StringName = current_question()
	var labels: Array = AbVariants.LABELS[question]
	var letter: String = "ABCDEF"[variants.variant(question)]
	var options := PackedStringArray()
	for i in labels.size(): options.append("%s: %s" % ["ABCDEF"[i], labels[i]])
	var separator: String = " | " if labels.size() > 2 else "\n"
	var lines: PackedStringArray = [
		"%d/%d %s | variant %s | %s | zoom %s" % [question_index + 1, AbVariants.QUESTIONS.size(), question, letter, "High" if quality == GraphicsSettings.HIGH else "Low", ZOOMS[zoom_index]],
		separator.join(options),
		"PageUp/PageDown or [ ]: question | Tab: next variant | Q: Low/High | Z: zoom | O: opponent colour (now P%d) | Space: pause | R: restart | arrows: pan | Esc: quit" % variants.opponent_owner,
	]
	if question == &"sand_tone": lines.append("step %d/%d %s" % [variants.variant(question) + 1, labels.size(), labels[variants.variant(question)]])
	if question == &"infantry_pick": lines.append("Clicks test the infantry click box. Last click: " + picked_text)
	return "\n".join(lines)

func step_question(direction: int) -> void:
	question_index = posmod(question_index + direction, AbVariants.QUESTIONS.size())
	if not _current.is_empty(): _show(_current)

func toggle_variant() -> void:
	variants.set_variant(current_question(), (variants.variant(current_question()) + 1) % variants.variant_count(current_question()))
	_show(_current)

func toggle_quality() -> void:
	quality = GraphicsSettings.LOW if quality == GraphicsSettings.HIGH else GraphicsSettings.HIGH
	_apply_view()

func cycle_opponent_colour() -> void:
	variants.opponent_owner = 2 if variants.opponent_owner >= 8 else variants.opponent_owner + 1
	_show(_current)

func cycle_zoom() -> void:
	zoom_index = (zoom_index + 1) % ZOOMS.size()
	_apply_view()

func _apply_view() -> void:
	_view.set_quality(quality)
	_camera.zoom = Vector2.ONE * ZOOMS[zoom_index]
	_view.set_zoom(ZOOMS[zoom_index])

func click(plane_point: Vector2) -> void:
	var id: int = _view.pick_entity(plane_point, true)
	_selected.clear()
	picked_text = "nothing"
	if id != -1:
		_selected.append(id)
		for unit: Dictionary in _current.entities:
			if unit.id == id: picked_text = "%s #%d" % [unit.kind, id]
	_show(_current)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click(_view.make_canvas_position_local(event.position))
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.physical_keycode)

func _key(code: Key) -> void:
	match code:
		KEY_PAGEUP, KEY_BRACKETLEFT: step_question(-1)
		KEY_PAGEDOWN, KEY_BRACKETRIGHT: step_question(1)
		KEY_TAB: toggle_variant()
		KEY_Q: toggle_quality()
		KEY_Z: cycle_zoom()
		KEY_O: cycle_opponent_colour()
		KEY_SPACE: paused = not paused
		KEY_R: restart()
		KEY_ESCAPE: get_tree().quit()

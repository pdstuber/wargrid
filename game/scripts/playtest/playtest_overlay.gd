extends Control

const UiStyle = preload("res://scripts/presentation/ui_style.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const MarkerCapture = preload("res://scripts/playtest/marker_capture.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const SessionForm = preload("res://scripts/playtest/session_form.gd")
signal finished
const CHECKLIST_KEY: Key = KEY_QUOTELEFT
const MARKER_KEY: Key = KEY_N
const CHECKLIST_WIDTH: float = 320.0
const DIALOG_WIDTH: float = 360.0
const MARGIN: float = 16.0
var image_source: Callable = _viewport_image
var web: bool = OS.has_feature("web")
var download: Callable = JavaScriptBridge.download_buffer
var match_record: Callable
var _card: Dictionary
var _context: Callable
var _active: bool = false
var _session: PlaytestSession
var _checklist: PanelContainer
var _boxes: Dictionary = {}
var _dialog: PanelContainer
var _form: SessionForm
var _reviewed: bool = false
var _text: LineEdit
var _save: Button
var _kinds: Dictionary = {}
var _kind: String = ""
var _captured: Dictionary = {}
var _jpg: String = ""

func setup(card: Dictionary, context: Callable, record: Callable) -> void:
	_card = card
	_context = context
	match_record = record
	name = "Playtest"
	theme = UiStyle.hud_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_checklist()
	_build_dialog()
	_build_form()

func set_active(on: bool) -> void:
	if on == _active: return
	_active = on
	if not on:
		_checklist.hide()
		cancel_marker()
		return
	_open_session()
	_checklist.show()

func _open_session() -> void:
	_session = PlaytestSession.resume_or_open(str(_card.get("id", "")), PlaytestSettings.build_id())
	for id: String in _boxes: _boxes[id].set_pressed_no_signal(checked(id))

func end_match() -> bool:
	if not _active or (_reviewed and PlaytestSession.current != _session): return false
	cancel_marker()
	_checklist.hide()
	if _reviewed: _form.open_leave(_session)
	else:
		_reviewed = true
		_form.open_review(_session, _session.finish_match(match_record.call()))
	return true

func begin_match() -> void:
	_reviewed = false
	_form.hide()
	if _session != null: _session.clear_pending()
	if not _active: return
	_open_session()
	_checklist.show()

func reviewing() -> bool:
	return _form.visible

func _process(_delta: float) -> void:
	if _active and not _reviewed and _context.call().over: end_match()

func is_active() -> bool:
	return _active

func holds_match() -> bool:
	return _dialog.visible or _form.visible

func checked(item_id: String) -> bool:
	return _session != null and _session.data.checklist.get(item_id, false)

func observe_command(payload: Dictionary) -> void:
	_tick_triggers(func(trigger: String) -> bool: return FocusCards.matches_command(trigger, payload))

func observe_menu() -> void:
	_tick_triggers(func(trigger: String) -> bool: return trigger == "esc_menu")

func open_marker() -> void:
	if not _active or _dialog.visible or _form.visible: return
	var context: Dictionary = _context.call()
	if context.over or context.menu: return
	_captured = context
	_jpg = MarkerCapture.jpg_base64(image_source.call())
	_choose_kind("")
	_text.clear()
	_dialog.show()
	_text.grab_focus()

func save_marker(kind: String, text: String) -> void:
	_session.add_marker(MarkerCapture.marker(kind, text, _captured, _jpg))
	cancel_marker()

func cancel_marker() -> void:
	_dialog.hide()

func _input(event: InputEvent) -> void:
	if not _active or not (event is InputEventKey and event.pressed and not event.echo): return
	var key: Key = (event as InputEventKey).physical_keycode
	if _form.visible:
		if key != KEY_ESCAPE: return
	elif _dialog.visible:
		if key != KEY_ESCAPE: return
		cancel_marker()
	elif key == CHECKLIST_KEY: _checklist.visible = not _checklist.visible
	elif key == MARKER_KEY: open_marker()
	else:
		_tick_triggers(func(trigger: String) -> bool: return trigger.begins_with("key:") and OS.find_keycode_from_string(trigger.substr(4)) == key)
		return
	get_viewport().set_input_as_handled()

func _viewport_image() -> Image:
	return get_viewport().get_texture().get_image()

func _tick_triggers(matches: Callable) -> void:
	if not _active: return
	for item: Dictionary in _card.get("try", []):
		var id: String = item.id
		if item.has("trigger") and not checked(id) and matches.call(item.trigger):
			_boxes[id].set_pressed_no_signal(true)
			_session.set_checked(id, true)

func _build_checklist() -> void:
	_checklist = _corner_panel("Checklist", CHECKLIST_WIDTH, 1.0)
	var box := VBoxContainer.new()
	_checklist.add_child(box)
	var title := Label.new()
	title.text = str(_card.get("title", ""))
	box.add_child(title)
	for item: Dictionary in _card.get("try", []):
		var check := CheckBox.new()
		check.name = item.id
		check.text = item.text
		check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		check.focus_mode = Control.FOCUS_NONE
		check.toggled.connect(func(on: bool) -> void: _session.set_checked(item.id, on))
		box.add_child(check)
		_boxes[item.id] = check
	_checklist.hide()

func _build_form() -> void:
	_form = SessionForm.new()
	add_child(_form)
	_form.next_match.connect(_close_form)
	_form.closed.connect(_close_form)
	_form.end_session.connect(func() -> void: _form.open_questions(_session, _card))
	_form.save_requested.connect(func() -> void: _form.show_saved(_session.write(web, download), web))
	_form.discard_requested.connect(func() -> void:
		_session.discard()
		_close_form())

func _close_form() -> void:
	_form.hide()
	finished.emit()

func _build_dialog() -> void:
	_dialog = _corner_panel("MarkerDialog", DIALOG_WIDTH, 0.5)
	var box := VBoxContainer.new()
	_dialog.add_child(box)
	var kinds := HBoxContainer.new()
	box.add_child(kinds)
	for kind in MarkerCapture.KINDS:
		var button := Button.new()
		button.name = kind.capitalize()
		button.text = kind.capitalize()
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose_kind.bind(kind))
		kinds.add_child(button)
		_kinds[kind] = button
	_text = LineEdit.new()
	_text.name = "Text"
	_text.placeholder_text = "Optional note"
	box.add_child(_text)
	var row := HBoxContainer.new()
	box.add_child(row)
	_save = SessionForm.add_action(row, "Save", "Save", func() -> void: save_marker(_kind, _text.text))
	SessionForm.add_action(row, "Cancel", "Cancel", cancel_marker)
	_dialog.hide()

func _choose_kind(kind: String) -> void:
	_kind = kind
	for id: String in _kinds: _kinds[id].set_pressed_no_signal(id == kind)
	_save.disabled = kind.is_empty()

# Both panels sit on the bottom edge and grow upward; `anchor_x` 1.0 is the right corner, 0.5 the centre.
func _corner_panel(panel_name: String, width: float, anchor_x: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.anchor_left = anchor_x
	panel.anchor_right = anchor_x
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	var right: float = -MARGIN if anchor_x == 1.0 else width / 2.0
	panel.offset_left = right - width
	panel.offset_right = right
	panel.offset_top = -MARGIN
	panel.offset_bottom = -MARGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	return panel

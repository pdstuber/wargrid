extends PanelContainer

signal next_match
signal end_session
signal save_requested
signal discard_requested
signal closed
const WIDTH: float = 420.0
const MARGIN: float = 16.0
const SCORES: int = 5
var _content: VBoxContainer
var _buttons: HBoxContainer
var _session: PlaytestSession

func _init() -> void:
	name = "SessionForm"
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -MARGIN - WIDTH
	offset_right = -MARGIN
	offset_top = MARGIN
	offset_bottom = -MARGIN
	var outer := VBoxContainer.new()
	add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_buttons = HBoxContainer.new()
	outer.add_child(_buttons)
	hide()

func open_review(session: PlaytestSession, match_index: int) -> void:
	_reset(session, "Match %d" % (match_index + 1))
	_add_markers(match_index)
	_action("NextMatch", "Next match", next_match)
	_action("EndSession", "End session", end_session)
	show()

func open_leave(session: PlaytestSession) -> void:
	_reset(session, "Leaving")
	_action("EndSession", "End session", end_session)
	_action("Leave", "Leave", closed)
	show()

func open_questions(session: PlaytestSession, card: Dictionary) -> void:
	_reset(session, "How was it?")
	for question: Dictionary in card.get("questions", []):
		_add_question(question)
	for m: int in session.data.matches.size():
		_add_label("Match %d" % (m + 1))
		_add_markers(m)
	_action("SaveSession", "Save session", save_requested)
	_action("DiscardSession", "Discard", discard_requested)
	show()

func show_saved(where: String, web: bool) -> void:
	_reset(_session, "Session")
	if where.is_empty():
		_add_label("Could not save the session file. It is kept for this sitting.")
		_action("SaveSession", "Try again", save_requested)
		_action("Close", "Close", closed)
		return
	_add_label(("Downloaded %s" if web else "Saved to %s") % where)
	if not web: _action("ShowInFolder", "Show in folder", Callable(OS, "shell_show_in_file_manager").bind(where))
	_action("Close", "Close", closed)

func _reset(session: PlaytestSession, title: String) -> void:
	_session = session
	for box: Control in [_content, _buttons]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_add_label(title)

func _add_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)
	return label

func _action(button_name: String, label: String, target: Variant) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(target.emit if target is Signal else target)
	_buttons.add_child(button)

func _add_markers(match_index: int) -> void:
	var markers: Array = _session.data.matches[match_index].markers
	if markers.is_empty(): _add_label("No markers.")
	for k: int in markers.size():
		var marker: Dictionary = markers[k]
		var text: String = "%s, tick %d" % [str(marker.kind).capitalize(), int(marker.tick)]
		if not str(marker.text).is_empty(): text += ": " + str(marker.text)
		_add_label(text)
		var comment := LineEdit.new()
		comment.name = "Comment_%d_%d" % [match_index, k]
		comment.placeholder_text = "Comment"
		comment.text = marker.comment
		comment.text_changed.connect(func(value: String) -> void: _session.set_comment(match_index, k, value))
		_content.add_child(comment)

func _add_question(question: Dictionary) -> void:
	var id: String = question.id
	var stored: Dictionary = _session.data.answers.get(id, {})
	var score: Array[int] = [int(stored.get("score", 0))]
	_add_label(question.text)
	var row := HBoxContainer.new()
	_content.add_child(row)
	var group := ButtonGroup.new()
	var answer := LineEdit.new()
	for n: int in range(1, SCORES + 1):
		var button := Button.new()
		button.name = "%s_%d" % [id, n]
		button.text = str(n)
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_pressed_no_signal(score[0] == n)
		button.toggled.connect(func(on: bool) -> void:
			if not on: return
			score[0] = n
			_session.set_answer(id, n, answer.text))
		row.add_child(button)
	answer.name = "Answer_" + id
	answer.placeholder_text = "Optional comment"
	answer.text = str(stored.get("text", ""))
	answer.text_changed.connect(func(value: String) -> void: _session.set_answer(id, score[0], value))
	_content.add_child(answer)

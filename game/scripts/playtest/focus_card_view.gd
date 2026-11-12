extends PanelContainer

const UiStyle = preload("res://scripts/presentation/ui_style.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
var _cards: Array[Dictionary]
var _open_count: Callable
var _picker: OptionButton
var _session: Label
var _content: VBoxContainer

func _init(cards: Array[Dictionary], open_count: Callable = func() -> int: return -1) -> void:
	name = "FocusPanel"
	_cards = cards
	_open_count = open_count
	visible = false
	theme = UiStyle.hud_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 32.0
	offset_top = 32.0
	offset_right = -32.0
	offset_bottom = -32.0
	var box := VBoxContainer.new()
	box.name = "Box"
	add_child(box)
	_picker = OptionButton.new()
	_picker.name = "Picker"
	_picker.visible = cards.size() > 1
	for entry in cards: _picker.add_item(entry.title)
	_picker.item_selected.connect(_pick)
	box.add_child(_picker)
	_session = Label.new()
	_session.name = "OpenSession"
	box.add_child(_session)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_content)
	var close := Button.new()
	close.name = "Close"
	close.text = "Close"
	box.add_child(close)
	visibility_changed.connect(_render)
	_render()

func _pick(index: int) -> void:
	FocusCards.chosen = _cards[index].id
	_render()

func _render() -> void:
	var current: Dictionary = FocusCards.card(FocusCards.shown(), _cards)
	if current.is_empty(): return
	_picker.select(_cards.find(current))
	var open: int = _open_count.call()
	_picker.disabled = open >= 0
	_session.visible = open >= 0
	_session.text = "Session open: %d %s" % [open, "match" if open == 1 else "matches"]
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_add(current.title, 28)
	_add("New in this build")
	for line: String in current.new: _add("• " + line)
	_add("Try")
	for step: Dictionary in current.get("try"): _add("• " + step.text)

func _add(text: String, font_size: int = 0) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size > 0: label.add_theme_font_size_override("font_size", font_size)
	_content.add_child(label)

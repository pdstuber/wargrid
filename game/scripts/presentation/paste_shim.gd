extends Node

const JoinLink = preload("res://scripts/join_link.gd")
const MENU_PASTE_ID := 1000
# The capture listener stops the keydown before Godot's canvas listener cancels it, so the browser fires `paste`.
const JS := "if (!window.wargridPasteInstalled) { window.wargridPasteInstalled = true; window.addEventListener('keydown', e => { if (window.wargridPaste && (e.metaKey || e.ctrlKey) && !e.altKey && e.key.toLowerCase() === 'v') e.stopImmediatePropagation(); }, true); window.addEventListener('paste', e => { if (window.wargridPaste) window.wargridPaste(e.clipboardData.getData('text')); }, true); }"
const READ_JS := "navigator.clipboard.readText().then(t => window.wargridPaste && window.wargridPaste(t)).catch(() => {})"
var _callback: JavaScriptObject

func _init() -> void:
	name = "PasteShim"

func _ready() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(JS, true)
	_callback = JavaScriptBridge.create_callback(_on_paste)
	JavaScriptBridge.get_interface("window").wargridPaste = _callback

func _exit_tree() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.wargridPaste = null", true)

func _on_paste(args: Array) -> void:
	insert(get_viewport().gui_get_focus_owner(), str(args[0]))

static func insert(focus: Control, text: String) -> bool:
	var edit := focus as LineEdit
	if edit == null or not edit.editable or not edit.is_visible_in_tree() or text.length() > JoinLink.MAX_INPUT:
		return false
	if edit.is_in_group("join_code"):
		return _set_code(edit, JoinLink.code_from(text))
	return _insert_at_caret(edit, text.strip_escapes())

static func _set_code(edit: LineEdit, code: String) -> bool:
	if code.is_empty():
		return false
	edit.text = code
	edit.caret_column = code.length()
	edit.text_changed.emit(edit.text)
	return true

static func _insert_at_caret(edit: LineEdit, text: String) -> bool:
	if text.is_empty():
		return false
	if edit.has_selection():
		var from: int = edit.get_selection_from_column()
		edit.delete_text(from, edit.get_selection_to_column())
		edit.caret_column = from
	edit.deselect()
	edit.insert_text_at_caret(text)
	edit.text_changed.emit(edit.text)
	return true

# Godot's stock Paste reads a clipboard cache that is stale on web; this item reads it itself.
static func adopt(edit: LineEdit, reader: Callable = Callable()) -> void:
	var menu: PopupMenu = edit.get_menu()
	var stock: int = menu.get_item_index(LineEdit.MENU_PASTE)
	if stock != -1:
		menu.remove_item(stock)
	if menu.get_item_index(MENU_PASTE_ID) != -1:
		return
	menu.add_item("Paste", MENU_PASTE_ID)
	menu.id_pressed.connect(func(id: int) -> void:
		if id == MENU_PASTE_ID:
			(reader if reader.is_valid() else _read_clipboard).call())

static func _read_clipboard() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(READ_JS, true)

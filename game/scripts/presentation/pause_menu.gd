extends Control

const UiStyle = preload("res://scripts/presentation/ui_style.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const VolumeSliders = preload("res://scripts/presentation/volume_sliders.gd")
signal resume_requested
signal leave_requested
signal quit_requested
signal quality_changed(quality: int)
signal neon_changed(neon: bool)
var confirm_leave: bool = false
var _confirming: bool = false
var _main_box: VBoxContainer
var _confirm_box: VBoxContainer
var _quality_button: Button
var _neon_button: Button
var _neon: bool = false
var _quality: int = GraphicsSettings.HIGH

func _init(web: bool = OS.has_feature("web")) -> void:
	name = "PauseMenu"
	visible = false
	theme = UiStyle.hud_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_main_box = _box(center)
	_button(_main_box, "Resume", resume_requested.emit)
	_button(_main_box, "Back to main menu", _leave_pressed)
	# The browser tab cannot be closed by the game.
	if not web: _button(_main_box, "Quit", quit_requested.emit)
	_quality_button = _button(_main_box, "", _toggle_quality)
	_quality_button.name = "Quality"
	_show_quality(GraphicsSettings.load_quality())
	_neon_button = _button(_main_box, "", _toggle_neon)
	_neon_button.name = "Neon"
	_show_neon(GraphicsSettings.load_neon())
	_main_box.add_child(VolumeSliders.new())
	_confirm_box = _box(center)
	_confirm_box.visible = false
	var question := Label.new()
	question.text = "Leave the match?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_box.add_child(question)
	_button(_confirm_box, "Leave", leave_requested.emit)
	_button(_confirm_box, "Cancel", _show_main)

func is_confirming() -> bool:
	return _confirming

func open() -> void:
	_show_quality(GraphicsSettings.load_quality())
	_show_neon(GraphicsSettings.load_neon())
	visible = true
	_show_main()

func close() -> void:
	visible = false

func back() -> void:
	if _confirming: _show_main()
	else: close()

func _box(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 220.0
	parent.add_child(box)
	return box

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _leave_pressed() -> void:
	if not confirm_leave:
		leave_requested.emit()
		return
	_confirming = true
	_main_box.visible = false
	_confirm_box.visible = true
	_confirm_box.get_child(1).grab_focus()

func _show_main() -> void:
	_confirming = false
	_confirm_box.visible = false
	_main_box.visible = true
	_main_box.get_child(0).grab_focus()

func _toggle_quality() -> void:
	_show_quality(GraphicsSettings.HIGH if _quality == GraphicsSettings.LOW else GraphicsSettings.LOW)
	GraphicsSettings.save_quality(_quality)
	quality_changed.emit(_quality)

func _show_quality(stored: int) -> void:
	_quality = stored if stored != -1 else GraphicsSettings.HIGH
	_quality_button.text = "Quality: " + ("Low" if _quality == GraphicsSettings.LOW else "High")

func _toggle_neon() -> void:
	_show_neon(not _neon)
	GraphicsSettings.save_neon(_neon)
	neon_changed.emit(_neon)

func _show_neon(neon: bool) -> void:
	_neon = neon
	_neon_button.text = "Neon colours: " + ("On" if neon else "Off")

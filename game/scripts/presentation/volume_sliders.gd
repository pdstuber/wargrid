extends GridContainer

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
var _mute: CheckButton

func _init() -> void:
	name = "Volume"
	columns = 3
	var volumes: Dictionary = AudioSettings.load_volumes()
	for key: String in AudioSettings.DEFAULTS:
		var title: String = key.capitalize()
		var label := Label.new()
		label.name = title + "Label"
		label.text = title
		add_child(label)
		var slider := HSlider.new()
		slider.name = title
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = volumes[key]
		slider.custom_minimum_size.x = 200.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(slider)
		var shown := Label.new()
		shown.name = title + "Value"
		shown.custom_minimum_size.x = 40.0
		shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		shown.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		add_child(shown)
	var master := Label.new()
	master.name = "MuteLabel"
	master.text = "Master"
	add_child(master)
	_mute = CheckButton.new()
	_mute.name = "Mute"
	_mute.text = "Mute"
	_mute.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_mute.button_pressed = AudioServer.is_bus_mute(0)
	add_child(_mute)
	var gap := Control.new()
	gap.name = "MuteGap"
	add_child(gap)
	_show_values(volumes)
	for key: String in AudioSettings.DEFAULTS: get_node(key.capitalize()).value_changed.connect(_changed)
	_mute.toggled.connect(func(on: bool) -> void: AudioServer.set_bus_mute(0, on))

# Master mute is session-only (never saved), so a muted session cannot leave the next start silent.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		_mute.button_pressed = not _mute.button_pressed

func _changed(_value: float) -> void:
	var volumes: Dictionary = {}
	for key: String in AudioSettings.DEFAULTS: volumes[key] = get_node(key.capitalize()).value
	_show_values(volumes)
	AudioSettings.apply(volumes)
	AudioSettings.save_volumes(volumes)

func _show_values(volumes: Dictionary) -> void:
	for key: String in AudioSettings.DEFAULTS: get_node(key.capitalize() + "Value").text = str(roundi(volumes[key] * 100.0))

extends GridContainer

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
var _mute: Button

func _init() -> void:
	name = "Volume"
	columns = 2
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
	var master := Label.new()
	master.name = "MuteLabel"
	master.text = "Master"
	add_child(master)
	_mute = Button.new()
	_mute.name = "Mute"
	_mute.text = "Mute"
	_mute.toggle_mode = true
	_mute.button_pressed = AudioServer.is_bus_mute(0)
	add_child(_mute)
	for key: String in AudioSettings.DEFAULTS: get_node(key.capitalize()).value_changed.connect(_changed)
	_mute.toggled.connect(func(on: bool) -> void: AudioServer.set_bus_mute(0, on))

# Master mute is session-only (never saved), so a muted session cannot leave the next start silent.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		_mute.button_pressed = not _mute.button_pressed

func _changed(_value: float) -> void:
	var volumes: Dictionary = {}
	for key: String in AudioSettings.DEFAULTS: volumes[key] = get_node(key.capitalize()).value
	AudioSettings.apply(volumes)
	AudioSettings.save_volumes(volumes)

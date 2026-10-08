class_name SettingsScreen
extends MenuScreen
## Player preferences: text speed, auto mode delay, volumes, full screen, and
## skipping unread lines.

const SLIDERS := [
	["Text speed", "text_speed", 0.0, 120.0, 1.0],
	["Auto mode delay", "auto_delay", 0.2, 5.0, 0.1],
	["Master volume", "master_volume", 0.0, 1.0, 0.05],
	["Music volume", "music_volume", 0.0, 1.0, 0.05],
	["Sound volume", "sounds_volume", 0.0, 1.0, 0.05],
	["Ambience volume", "ambience_volume", 0.0, 1.0, 0.05],
	["Voice volume", "voice_volume", 0.0, 1.0, 0.05],
]
const TOGGLES := [
	["Full screen", "fullscreen"],
	["Skip unread lines", "skip_unread"],
]

var _controls: Dictionary = {}


func _ready() -> void:
	add_dim(0.75)
	var column := add_center_panel(520)
	column.add_child(MenuScreen.make_title("Settings"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	column.add_child(grid)
	for row in SLIDERS:
		grid.add_child(_label(row[0]))
		var slider := HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = row[4]
		slider.custom_minimum_size = Vector2(240, 28)
		slider.value_changed.connect(func(value: float) -> void: _apply_setting(row[1], value))
		grid.add_child(slider)
		_controls[row[1]] = slider
	for row in TOGGLES:
		grid.add_child(_label(row[0]))
		var toggle := CheckButton.new()
		toggle.toggled.connect(func(on: bool) -> void: _apply_setting(row[1], on))
		grid.add_child(toggle)
		_controls[row[1]] = toggle
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.add_child(MenuScreen.make_button("Reset to defaults", _reset))
	buttons.add_child(MenuScreen.make_button("Back", func() -> void: menus.close_top()))
	column.add_child(buttons)


func open() -> void:
	var settings := menus.settings()
	if settings == null:
		return
	for key in _controls:
		var control: Control = _controls[key]
		if control is HSlider:
			control.set_value_no_signal(float(settings.get_value(key)))
		elif control is CheckButton:
			control.set_pressed_no_signal(bool(settings.get_value(key)))
	focus_first()


func _apply_setting(key: String, value: Variant) -> void:
	if menus.settings() != null:
		menus.settings().set_value(key, value)


func _reset() -> void:
	if menus.settings() != null:
		menus.settings().reset_to_defaults()
		open()


static func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

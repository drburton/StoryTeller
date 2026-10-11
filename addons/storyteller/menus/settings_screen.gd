class_name SettingsScreen
extends MenuScreen
## Player preferences: text speed, auto mode delay, text size, volumes, full
## screen, skipping unread lines, and the language when the game has
## translations.

const SLIDERS := [
	["Text speed", "text_speed", 0.0, 120.0, 1.0],
	["Auto mode delay", "auto_delay", 0.2, 5.0, 0.1],
	["Text size", "text_size", 0.8, 1.6, 0.1],
	["Master volume", "master_volume", 0.0, 1.0, 0.05],
	["Music volume", "music_volume", 0.0, 1.0, 0.05],
	["Sound volume", "sounds_volume", 0.0, 1.0, 0.05],
	["Ambience volume", "ambience_volume", 0.0, 1.0, 0.05],
	["Voice volume", "voice_volume", 0.0, 1.0, 0.05],
]
const TOGGLES := [
	["Full screen", "fullscreen"],
	["Skip unread lines", "skip_unread"],
	["Typing sounds", "typing_sounds"],
]

## Language names in their own language, so players can find theirs.
## Others fall back to Godot's English name.
const NATIVE_NAMES := {
	"ar": "العربية", "de": "Deutsch", "en": "English", "es": "Español",
	"fr": "Français", "id": "Bahasa Indonesia", "it": "Italiano", "ja": "日本語",
	"ko": "한국어", "nl": "Nederlands", "pl": "Polski", "pt": "Português",
	"ru": "Русский", "tr": "Türkçe", "uk": "Українська", "vi": "Tiếng Việt",
	"zh": "中文",
}

var _controls: Dictionary = {}
var _locales := PackedStringArray()


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
		toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		toggle.toggled.connect(func(on: bool) -> void: _apply_setting(row[1], on))
		grid.add_child(toggle)
		_controls[row[1]] = toggle
	_locales = _available_locales()
	if _locales.size() > 1:
		grid.add_child(_label("Language"))
		var languages := OptionButton.new()
		languages.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		for locale in _locales:
			languages.add_item(NATIVE_NAMES.get(locale, TranslationServer.get_locale_name(locale)))
		languages.item_selected.connect(func(index: int) -> void: _apply_setting("language", _locales[index]))
		grid.add_child(languages)
		_controls["language"] = languages
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
		elif control is OptionButton:
			control.select(_closest_locale(TranslationServer.get_locale()))
	focus_first()


func _apply_setting(key: String, value: Variant) -> void:
	if menus.settings() != null:
		menus.settings().set_value(key, value)


## Languages the game has translations for, one per language code.
static func _available_locales() -> PackedStringArray:
	var result := PackedStringArray()
	for locale in TranslationServer.get_loaded_locales():
		var code := locale.get_slice("_", 0)
		if code not in result:
			result.append(code)
	result.sort()
	return result


func _closest_locale(locale: String) -> int:
	var index := _locales.find(locale.get_slice("_", 0))
	return maxi(index, 0)


func _reset() -> void:
	if menus.settings() != null:
		menus.settings().reset_to_defaults()
		open()


static func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

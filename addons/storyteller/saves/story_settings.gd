class_name StorySettings
extends StoryCrew
## Crew member for player preferences: text speed, auto mode delay, volumes,
## full screen, skipping, and language. Changes apply at once and are saved
## to [member path].

signal changed(key: String, value: Variant)

const DEFAULTS := {
	"text_speed": 40.0,
	"auto_delay": 1.0,
	"text_size": 1.0,
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sounds_volume": 1.0,
	"ambience_volume": 1.0,
	"voice_volume": 1.0,
	"fullscreen": false,
	"skip_unread": false,
	"typing_sounds": true,
	"high_contrast": false,
	"read_aloud": false,
	"language": "",
}

var path := "user://settings.cfg"
var values: Dictionary = {}


func get_crew_name() -> StringName:
	return &"Settings"


func setup(config: StoryConfig) -> void:
	path = config.settings_path
	values = DEFAULTS.duplicate()
	values["text_speed"] = config.text_speed
	load_settings()
	apply_all.call_deferred()


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


## Changes a setting, applies it, and saves.
func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("StoryTeller: unknown setting '%s'." % key)
		return
	values[key] = value
	save_settings()
	apply(key)
	changed.emit(key, value)


func reset_to_defaults() -> void:
	for key in DEFAULTS:
		set_value(key, DEFAULTS[key])


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key in DEFAULTS:
		if file.has_section_key("settings", key):
			values[key] = file.get_value("settings", key)


func save_settings() -> void:
	var file := ConfigFile.new()
	for key in values:
		file.set_value("settings", key, values[key])
	file.save(path)


func apply_all() -> void:
	for key in values:
		# An unset language leaves the locale the game started with.
		if key == "language" and str(values[key]).is_empty():
			continue
		apply(key)


## Pushes one setting to the crew member or engine system that uses it.
func apply(key: String) -> void:
	var value: Variant = values[key]
	match key:
		"text_speed", "auto_delay", "text_size", "read_aloud":
			var dialogue := _crew(&"Dialogue")
			if dialogue != null and dialogue.has_method("apply_setting"):
				dialogue.apply_setting(key, value)
		"high_contrast":
			for crew_name in [&"Dialogue", &"Menus"]:
				var member := _crew(crew_name)
				if member != null and member.has_method("apply_setting"):
					member.apply_setting(key, value)
		"master_volume":
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(value), 0.0001)))
		"music_volume", "sounds_volume", "ambience_volume", "voice_volume":
			var audio := _crew(&"Audio") as StoryAudio
			if audio != null:
				audio.set_kind_volume(key.trim_suffix("_volume"), float(value))
		"fullscreen":
			if DisplayServer.get_name() != "headless" and not Engine.is_editor_hint():
				var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED
				if DisplayServer.window_get_mode() != mode:
					DisplayServer.window_set_mode(mode)
		"language":
			# Empty means the player's system language.
			TranslationServer.set_locale(str(value) if not str(value).is_empty() else OS.get_locale())


func _crew(crew_name: StringName) -> Node:
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(crew_name)
	return null

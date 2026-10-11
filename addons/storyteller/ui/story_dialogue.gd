class_name StoryDialogue
extends StoryCrew
## Crew member that shows lines and choices on screen. It is the director's
## default presenter.
##
## Creates a [CanvasLayer] holding the dialogue boxes and the choice menu.
## Two dialogue styles are built in: "classic" (a box at the bottom) and
## "page" (full-screen text). Tales switch with [code]dialogue_style("page")[/code].
## Projects can replace or add styles in [StoryConfig].
##
## Choice menus have styles too, picked with [code]choose(style = "...")[/code]:
## "list" (the default) and "pictures" are built in,
## [member StoryConfig.choice_styles] adds scenes, and
## [method add_choice_style] lets game code take over choices, for example
## to let players choose by clicking objects in a 2D or 3D scene.

## Input actions registered at runtime when the project doesn't define
## them: keys, mouse buttons, and gamepad buttons.
const INPUT_ACTIONS := {
	"story_continue": [{"key": KEY_SPACE}, {"key": KEY_ENTER}, {"key": KEY_KP_ENTER}, {"joy": JOY_BUTTON_A}],
	"story_skip": [{"key": KEY_CTRL}, {"joy": JOY_BUTTON_RIGHT_SHOULDER}],
	"story_auto": [{"key": KEY_A}, {"joy": JOY_BUTTON_Y}],
	"story_rewind": [{"key": KEY_PAGEUP}, {"mouse": MOUSE_BUTTON_WHEEL_UP}, {"joy": JOY_BUTTON_LEFT_SHOULDER}],
	"story_menu": [{"key": KEY_ESCAPE}, {"mouse": MOUSE_BUTTON_RIGHT}, {"joy": JOY_BUTTON_START}],
	"story_history": [{"key": KEY_H}, {"joy": JOY_BUTTON_BACK}],
	"story_hide_ui": [{"key": KEY_V}, {"mouse": MOUSE_BUTTON_MIDDLE}, {"joy": JOY_BUTTON_X}],
	"story_quick_save": [{"key": KEY_F5}],
	"story_quick_load": [{"key": KEY_F9}],
}

var layer: CanvasLayer
## The dialogue box in use.
var dialogue_box: DialogueBox
## The default ("list") choice menu.
var choice_menu: ChoiceMenu
## Folder with the pictures that [code]@picture("name")[/code] names.
var choice_picture_folder := "res://story/choices"
## Name of the dialogue style in use.
var style := "classic"
## Skip mode switched on from the quick menu (as opposed to holding Ctrl).
var skip_toggled := false
## Returns true while menus should get the player's input.
var input_blocked := func() -> bool: return false:
	set(value):
		input_blocked = value
		for box in _styles.values():
			box.input_blocked = _box_blocked
## True while the player has hidden the dialogue box to look at the scene
## (V, the middle mouse button, or the quick menu's Hide). The next key,
## click, or button brings it back without continuing the story.
var ui_hidden := false
## Default typing sound, from [member StoryConfig.typing_sound].
var typing_sound := ""
## Characters between two typing sounds.
var typing_sound_every := 3

var _typing_sound_now := ""
var _typed_since_sound := 0

## The theme from the config, and its high-contrast copy once needed.
var _theme: Theme
var _contrast_theme: Theme
var _styles: Dictionary = {}
## Choice style name to its menu: a [ChoiceMenu] or any object with
## [method ChoiceMenu.choose].
var _choice_styles: Dictionary = {}
var _line_read := false


func get_crew_name() -> StringName:
	return &"Dialogue"


func setup(config: StoryConfig) -> void:
	_register_input_actions()
	layer = CanvasLayer.new()
	layer.name = "DialogueLayer"
	layer.layer = 10
	add_child(layer)
	var theme := config.theme if config.theme != null else StoryTheme.build_default()
	_theme = theme
	var scenes := {"classic": config.dialogue_box_scene, "page": null}
	for style_name in config.dialogue_styles:
		scenes[style_name] = config.dialogue_styles[style_name]
	for style_name in scenes:
		var fallback: Script = PageDialogueBox if style_name == "page" else ClassicDialogueBox
		var box := _instantiate(scenes[style_name], fallback) as DialogueBox
		box.name = style_name.capitalize() + "Box"
		box.characters_per_second = config.text_speed
		box.text_reveal = config.text_reveal
		box.theme = theme
		box.on_text_tag = _run_text_tag
		box.box_transition = config.dialogue_box_transition
		box.box_transition_time = config.dialogue_box_transition_time
		box.input_blocked = _box_blocked
		box.characters_typed.connect(_on_characters_typed)
		layer.add_child(box)
		_styles[style_name] = box
	dialogue_box = _styles["classic"]
	choice_picture_folder = config.choice_picture_folder
	typing_sound = config.typing_sound
	typing_sound_every = config.typing_sound_every
	var choice_scenes := {"list": config.choice_menu_scene, "pictures": null}
	for style_name in config.choice_styles:
		choice_scenes[style_name] = config.choice_styles[style_name]
	for style_name in choice_scenes:
		var fallback: Script = PictureChoiceMenu if style_name == "pictures" else ListChoiceMenu
		var menu := _instantiate(choice_scenes[style_name], fallback) as ChoiceMenu
		menu.name = style_name.capitalize().replace(" ", "") + "ChoiceMenu"
		menu.theme = theme
		layer.add_child(menu)
		_choice_styles[style_name] = menu
	choice_menu = _choice_styles["list"]


func clear() -> void:
	set_style("classic")
	set_ui_hidden(false)
	hide_all()


## Switches the dialogue style, e.g. "classic" or "page".
func set_style(style_name: String) -> bool:
	if not _styles.has(style_name):
		return false
	if style_name == style:
		return true
	var previous := dialogue_box
	dialogue_box = _styles[style_name]
	dialogue_box.characters_per_second = previous.characters_per_second
	dialogue_box.auto_delay = previous.auto_delay
	dialogue_box.auto_advance = previous.auto_advance
	previous.hide_box()
	style = style_name
	return true


func get_style_names() -> PackedStringArray:
	return PackedStringArray(_styles.keys())


func hide_all() -> void:
	for box in _styles.values():
		box.hide_box()


## True while a dialogue box is on screen.
func is_showing() -> bool:
	return dialogue_box != null and dialogue_box.visible and not ui_hidden


## Hides or shows the dialogue box and choices so the player can see the
## scene. The story waits while they are hidden.
func set_ui_hidden(hidden: bool) -> void:
	ui_hidden = hidden
	if layer != null:
		layer.visible = not hidden


## Presenter method: shows one line. Awaitable.
func show_line(line: Dictionary) -> void:
	_line_read = line.get("read", false)
	_typing_sound_now = _typing_sound_for(line)
	_typed_since_sound = typing_sound_every
	var stage := _crew(&"Stage")
	if stage != null and stage.has_method("get_line_portrait") and not line.has("portrait"):
		line = line.duplicate()
		line["portrait"] = stage.get_line_portrait(str(line.get("speaker_id", "")), str(line.get("mood", "")))
		var profile: CastProfile = stage.get_profile(str(line.get("speaker_id", "")))
		if profile != null and profile.text_color.a > 0.0:
			line["text_color"] = profile.text_color
	await dialogue_box.show_line(line)


## Presenter method: shows choices in the menu of the style named by
## [code]settings["style"][/code] ("list" when there is none) and returns
## the picked index. Options with a [code]"picture"[/code] name get the
## texture in its place. Awaitable.
func choose(options: Array[Dictionary], settings: Dictionary) -> int:
	var style_name := str(settings.get("style", "list"))
	var menu: Object = _choice_styles.get(style_name)
	if menu == null or not is_instance_valid(menu):
		_report("There is no choice style '%s'. Styles: %s." % [style_name, ", ".join(get_choice_style_names())])
		menu = choice_menu
	var shown: Array[Dictionary] = []
	for option in options:
		var copy := option.duplicate()
		var picture_name := str(option.get("picture", ""))
		copy["picture"] = null
		if not picture_name.is_empty():
			copy["picture"] = StoryAssets.load_asset(choice_picture_folder, picture_name, StoryAssets.IMAGE_EXTENSIONS)
			if copy["picture"] == null:
				_report("There is no choice picture '%s' in %s." % [picture_name, choice_picture_folder])
		shown.append(copy)
	return await menu.choose(shown, settings)


## Adds or replaces the choice style [param style_name]. [param menu] is a
## [ChoiceMenu] or any object with an awaitable
## [code]choose(options, settings) -> int[/code], and optionally
## [code]cancel()[/code]. It is used as it is, not added to the dialogue
## layer, so a node in the game's own scene can offer the choices:
## [codeblock]
## # In the game: let the player pick by clicking doors in the 3D scene.
## Story.get_crew(&"Dialogue").add_choice_style("doors", $DoorPicker)
## # In a tale, with option ids the picker knows:
## # choose(style = "doors"):
## #     @id("red") "The red door": jump red
## [/codeblock]
func add_choice_style(style_name: String, menu: Object) -> void:
	_choice_styles[style_name] = menu


func remove_choice_style(style_name: String) -> void:
	if style_name != "list":
		_choice_styles.erase(style_name)


func get_choice_style_names() -> PackedStringArray:
	return PackedStringArray(_choice_styles.keys())


## The menu of [param style_name], or null.
func get_choice_menu(style_name: String) -> Object:
	return _choice_styles.get(style_name)


## Presenter method: releases a line or choice that is waiting for the
## player, used when a save is loaded.
func cancel() -> void:
	for box in _styles.values():
		box.cancel()
	for menu in _choice_styles.values():
		if is_instance_valid(menu) and menu.has_method("cancel"):
			menu.cancel()


## Called by the Settings crew member.
func apply_setting(key: String, value: Variant) -> void:
	if key == "high_contrast":
		if value and _contrast_theme == null:
			_contrast_theme = StoryTheme.high_contrast(_theme)
		var theme: Theme = _contrast_theme if value else _theme
		for control in _styles.values() + _choice_styles.values():
			if control is Control and is_instance_valid(control) and control.get_parent() == layer:
				control.theme = theme
		return
	for box in _styles.values():
		match key:
			"text_speed":
				box.characters_per_second = float(value)
			"auto_delay":
				box.auto_delay = float(value)
			"text_size":
				box.text_scale = float(value)


func capture() -> Dictionary:
	return {"style": style}


func restore(data: Dictionary) -> void:
	set_style(data.get("style", "classic"))


func _process(_delta: float) -> void:
	if dialogue_box == null:
		return
	# Skipping stops at unread lines unless the player allows skipping them.
	var settings := _crew(&"Settings")
	var skip_unread: bool = settings != null and settings.get_value("skip_unread")
	var wants_skip: bool = (Input.is_action_pressed("story_skip") or skip_toggled) and not _box_blocked.call()
	var skip: bool = wants_skip and (skip_unread or _line_read)
	dialogue_box.skipping = skip
	var director := _director()
	if director != null:
		director.skipping = skip


func _input(event: InputEvent) -> void:
	# While hidden, any press only brings the dialogue back.
	if ui_hidden and _is_press(event):
		set_ui_hidden(false)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if dialogue_box == null or input_blocked.call():
		return
	if event.is_action_pressed("story_auto"):
		dialogue_box.auto_advance = not dialogue_box.auto_advance
	elif event.is_action_pressed("story_hide_ui") and is_showing():
		set_ui_hidden(true)
		get_viewport().set_input_as_handled()


## The typing sound for [param line]: none for voiced lines, else the
## speaker's own, else the default.
func _typing_sound_for(line: Dictionary) -> String:
	if not str(line.get("voice", "")).is_empty():
		return ""
	var stage := _crew(&"Stage")
	if stage != null and stage.has_method("get_profile") and not str(line.get("speaker_id", "")).is_empty():
		var profile: CastProfile = stage.get_profile(line["speaker_id"])
		if profile != null and not profile.typing_sound.is_empty():
			return profile.typing_sound
	return typing_sound


func _on_characters_typed(count: int) -> void:
	if _typing_sound_now.is_empty():
		return
	var settings := _crew(&"Settings")
	if settings != null and not settings.get_value("typing_sounds"):
		return
	_typed_since_sound += count
	if _typed_since_sound < typing_sound_every:
		return
	_typed_since_sound = 0
	var audio := _crew(&"Audio") as StoryAudio
	if audio != null:
		var problem := audio.play_blip(_typing_sound_now, 0.6)
		if not problem.is_empty():
			_report(problem)
			_typing_sound_now = ""


func _box_blocked() -> bool:
	return ui_hidden or input_blocked.call()


static func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton or event is InputEventJoypadButton:
		return event.pressed
	return false


## Runs an [code][act][/code] or [code][sound][/code] tag that typing reached.
func _run_text_tag(_tag: String, value: String) -> void:
	var director := _director()
	if director != null and value.is_valid_int():
		await director.run_text_act(value.to_int())


func _director() -> TaleDirector:
	return _crew(&"TaleDirector") as TaleDirector


func _report(message: String) -> void:
	var director := _director()
	if director != null:
		director.report_error(message)
	else:
		push_warning("StoryTeller: " + message)


func _crew(crew_name: StringName) -> Node:
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(crew_name)
	return null


static func _instantiate(scene: PackedScene, fallback: Script) -> Control:
	if scene != null:
		return scene.instantiate()
	return fallback.new()


static func _register_input_actions() -> void:
	for action in INPUT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for binding: Dictionary in INPUT_ACTIONS[action]:
			var event: InputEvent
			if binding.has("mouse"):
				event = InputEventMouseButton.new()
				event.button_index = binding["mouse"]
			elif binding.has("joy"):
				event = InputEventJoypadButton.new()
				event.button_index = binding["joy"]
			else:
				event = InputEventKey.new()
				event.keycode = binding["key"]
			InputMap.action_add_event(action, event)

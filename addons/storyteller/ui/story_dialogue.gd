class_name StoryDialogue
extends StoryCrew
## Crew member that shows lines and choices on screen. It is the director's
## default presenter.
##
## Creates a [CanvasLayer] holding the dialogue boxes and the choice menu.
## Two dialogue styles are built in: "classic" (a box at the bottom) and
## "page" (full-screen text). Tales switch with [code]dialogue_style("page")[/code].
## Projects can replace or add styles in [StoryConfig].

## Input actions registered at runtime when the project doesn't define them.
const INPUT_ACTIONS := {
	"story_continue": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	"story_skip": [KEY_CTRL],
	"story_auto": [KEY_A],
	"story_rewind": [KEY_PAGEUP, MOUSE_BUTTON_WHEEL_UP],
	"story_menu": [KEY_ESCAPE, MOUSE_BUTTON_RIGHT],
	"story_history": [KEY_H],
	"story_quick_save": [KEY_F5],
	"story_quick_load": [KEY_F9],
}

var layer: CanvasLayer
## The dialogue box in use.
var dialogue_box: DialogueBox
var choice_menu: ChoiceMenu
## Name of the dialogue style in use.
var style := "classic"
## Skip mode switched on from the quick menu (as opposed to holding Ctrl).
var skip_toggled := false
## Returns true while menus should get the player's input.
var input_blocked := func() -> bool: return false:
	set(value):
		input_blocked = value
		for box in _styles.values():
			box.input_blocked = value

var _styles: Dictionary = {}
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
	var scenes := {"classic": config.dialogue_box_scene, "page": null}
	for style_name in config.dialogue_styles:
		scenes[style_name] = config.dialogue_styles[style_name]
	for style_name in scenes:
		var fallback: Script = PageDialogueBox if style_name == "page" else ClassicDialogueBox
		var box := _instantiate(scenes[style_name], fallback) as DialogueBox
		box.name = style_name.capitalize() + "Box"
		box.characters_per_second = config.text_speed
		box.theme = theme
		box.on_text_tag = _run_text_tag
		layer.add_child(box)
		_styles[style_name] = box
	dialogue_box = _styles["classic"]
	choice_menu = _instantiate(config.choice_menu_scene, ListChoiceMenu) as ChoiceMenu
	choice_menu.theme = theme
	layer.add_child(choice_menu)


func clear() -> void:
	set_style("classic")
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
	return dialogue_box != null and dialogue_box.visible


## Presenter method: shows one line. Awaitable.
func show_line(line: Dictionary) -> void:
	_line_read = line.get("read", false)
	await dialogue_box.show_line(line)


## Presenter method: shows choices and returns the picked index. Awaitable.
func choose(options: Array[Dictionary], settings: Dictionary) -> int:
	return await choice_menu.choose(options, settings)


## Presenter method: releases a line or choice that is waiting for the
## player, used when a save is loaded.
func cancel() -> void:
	for box in _styles.values():
		box.cancel()
	if choice_menu != null and choice_menu.has_method("cancel"):
		choice_menu.cancel()


## Called by the Settings crew member.
func apply_setting(key: String, value: Variant) -> void:
	for box in _styles.values():
		match key:
			"text_speed":
				box.characters_per_second = float(value)
			"auto_delay":
				box.auto_delay = float(value)


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
	var wants_skip: bool = (Input.is_action_pressed("story_skip") or skip_toggled) and not input_blocked.call()
	var skip: bool = wants_skip and (skip_unread or _line_read)
	dialogue_box.skipping = skip
	var director := _director()
	if director != null:
		director.skipping = skip


func _unhandled_input(event: InputEvent) -> void:
	if dialogue_box != null and not input_blocked.call() and event.is_action_pressed("story_auto"):
		dialogue_box.auto_advance = not dialogue_box.auto_advance


## Runs an [code][act][/code] or [code][sound][/code] tag that typing reached.
func _run_text_tag(_tag: String, value: String) -> void:
	var director := _director()
	if director != null and value.is_valid_int():
		await director.run_text_act(value.to_int())


func _director() -> TaleDirector:
	return _crew(&"TaleDirector") as TaleDirector


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
		for code in INPUT_ACTIONS[action]:
			var event: InputEvent
			if code in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_RIGHT]:
				event = InputEventMouseButton.new()
				event.button_index = code
			else:
				event = InputEventKey.new()
				event.keycode = code
			InputMap.action_add_event(action, event)

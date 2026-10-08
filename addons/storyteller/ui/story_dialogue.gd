class_name StoryDialogue
extends StoryCrew
## Crew member that shows lines and choices on screen. It is the director's
## default presenter.
##
## Creates a [CanvasLayer] holding the dialogue box and the choice menu.
## Projects can replace either with their own scenes in [StoryConfig].

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
var dialogue_box: DialogueBox
var choice_menu: ChoiceMenu
var _line_read := false


func get_crew_name() -> StringName:
	return &"Dialogue"


func setup(config: StoryConfig) -> void:
	_register_input_actions()
	layer = CanvasLayer.new()
	layer.name = "DialogueLayer"
	layer.layer = 10
	add_child(layer)
	dialogue_box = _instantiate(config.dialogue_box_scene, ClassicDialogueBox) as DialogueBox
	dialogue_box.characters_per_second = config.text_speed
	layer.add_child(dialogue_box)
	choice_menu = _instantiate(config.choice_menu_scene, ListChoiceMenu) as ChoiceMenu
	layer.add_child(choice_menu)


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
	if dialogue_box != null and dialogue_box.has_method("cancel"):
		dialogue_box.cancel()
	if choice_menu != null and choice_menu.has_method("cancel"):
		choice_menu.cancel()


## Called by the Settings crew member.
func apply_setting(key: String, value: Variant) -> void:
	match key:
		"text_speed":
			dialogue_box.characters_per_second = float(value)
		"auto_delay":
			dialogue_box.auto_delay = float(value)


func _process(_delta: float) -> void:
	if dialogue_box == null:
		return
	# Skipping stops at unread lines unless the player allows skipping them.
	var settings := _crew(&"Settings")
	var skip_unread: bool = settings != null and settings.get_value("skip_unread")
	var skip := Input.is_action_pressed("story_skip") and (skip_unread or _line_read)
	dialogue_box.skipping = skip
	var director := _director()
	if director != null:
		director.skipping = skip


func _unhandled_input(event: InputEvent) -> void:
	if dialogue_box != null and event.is_action_pressed("story_auto"):
		dialogue_box.auto_advance = not dialogue_box.auto_advance


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

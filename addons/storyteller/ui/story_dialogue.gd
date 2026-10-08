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
}

var layer: CanvasLayer
var dialogue_box: DialogueBox
var choice_menu: ChoiceMenu


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
	await dialogue_box.show_line(line)


## Presenter method: shows choices and returns the picked index. Awaitable.
func choose(options: Array[Dictionary], settings: Dictionary) -> int:
	return await choice_menu.choose(options, settings)


func _process(_delta: float) -> void:
	if dialogue_box == null:
		return
	var skip_held := Input.is_action_pressed("story_skip")
	dialogue_box.skipping = skip_held
	var director := _director()
	if director != null:
		director.skipping = skip_held


func _unhandled_input(event: InputEvent) -> void:
	if dialogue_box != null and event.is_action_pressed("story_auto"):
		dialogue_box.auto_advance = not dialogue_box.auto_advance


func _director() -> TaleDirector:
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(&"TaleDirector") as TaleDirector
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
		for keycode in INPUT_ACTIONS[action]:
			var event := InputEventKey.new()
			event.keycode = keycode
			InputMap.action_add_event(action, event)

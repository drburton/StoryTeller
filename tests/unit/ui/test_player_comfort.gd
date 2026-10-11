extends "res://tests/framework/story_test.gd"
## Tests for gamepad bindings, hiding the interface, and text size.

const StoryScript := preload("res://addons/storyteller/core/story.gd")

var story: Node
var director: TaleDirector
var dialogue: StoryDialogue
var shown: Array[String] = []


func before_each() -> void:
	story = track(StoryScript.new())
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StorySettings, StoryDialogue, StoryMenus]
	config.settings_path = "user://test_comfort_settings.cfg"
	config.text_speed = 0.0
	config.dialogue_box_transition = "none"
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	dialogue = story.get_crew(&"Dialogue")
	shown.clear()
	director.line_started.connect(func(line: Dictionary) -> void: shown.append(line["text"]))
	await tree.process_frame


func after_each() -> void:
	DirAccess.remove_absolute("user://test_comfort_settings.cfg")


func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		tree.root.push_input(event)
	await tree.process_frame


func _play(source: String) -> void:
	var result := TaleCompiler.build(source, "t", director.make_check_context("t"))
	director.add_tale(result["tale"])
	director.play("t")
	await tree.process_frame
	await tree.process_frame


func test_gamepad_buttons_are_bound_by_default() -> void:
	var joypad := func(action: String) -> Array:
		return InputMap.action_get_events(action).filter(func(event: InputEvent) -> bool: return event is InputEventJoypadButton).map(func(event: InputEventJoypadButton) -> int: return event.button_index)
	assert_eq(joypad.call("story_continue"), [JOY_BUTTON_A])
	assert_eq(joypad.call("story_menu"), [JOY_BUTTON_START])
	assert_eq(joypad.call("story_hide_ui"), [JOY_BUTTON_X])
	assert_true(InputMap.action_has_event("story_hide_ui", _key(KEY_V)))


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event


func test_hiding_the_interface_waits_for_any_press() -> void:
	await _play("beat start:\n\t\"One.\"\n\t\"Two.\"\n")
	assert_eq(shown, ["One."])
	await _press_key(KEY_V)
	assert_true(dialogue.ui_hidden)
	assert_false(dialogue.layer.visible)
	assert_false(dialogue.is_showing(), "so the quick menu hides too")
	dialogue.skip_toggled = true
	await tree.process_frame
	assert_false(director.skipping, "skipping waits while the interface is hidden")
	dialogue.skip_toggled = false
	await _press_key(KEY_SPACE)
	assert_false(dialogue.ui_hidden)
	assert_eq(shown, ["One."], "the press that shows the interface does not continue")
	await _press_key(KEY_SPACE)
	await tree.process_frame
	assert_eq(shown, ["One.", "Two."])


func test_quick_menu_hide_and_auto_mode_wait() -> void:
	dialogue.dialogue_box.auto_delay = 0.0
	dialogue.dialogue_box.auto_advance = true
	(story.get_crew(&"Menus") as StoryMenus).hide_ui()
	await _play("beat start:\n\t\"One.\"\n\t\"Two.\"\n")
	await tree.create_timer(0.3).timeout
	assert_eq(shown, ["One."], "auto mode holds while hidden")
	dialogue.set_ui_hidden(false)
	await tree.create_timer(0.3).timeout
	assert_eq(shown, ["One.", "Two."])


func test_text_size_setting_scales_dialogue_text() -> void:
	var settings: StorySettings = story.get_crew(&"Settings")
	settings.set_value("text_size", 1.5)
	var box := dialogue.dialogue_box as ClassicDialogueBox
	var text: RichTextLabel = box.find_child("Text", true, false)
	var speaker: Label = box.find_child("Name", true, false)
	assert_eq(text.get_theme_font_size("normal_font_size"), 30)
	assert_eq(speaker.get_theme_font_size("font_size"), 33)
	dialogue.set_style("page")
	var page_text: RichTextLabel = dialogue.dialogue_box.find_child("Text", true, false)
	assert_eq(page_text.get_theme_font_size("normal_font_size"), 30, "every style follows the setting")

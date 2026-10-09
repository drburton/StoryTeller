extends "res://tests/framework/story_test.gd"
## Tests for choice styles: the "pictures" menu, @picture, the style
## registry in StoryDialogue, and choice styles that game code provides.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const DOORS := "beat start:\n\tchoose(style = \"pictures\", columns = 2):\n\t\t@picture(\"red_door\") \"The red door\": \"red\"\n\t\t@id(\"blue\") @picture(\"blue_door\") \"The blue door\": \"blue\"\n\t\t\"Neither\": \"none\"\n\t\"done\"\n"

var story: Node
var director: TaleDirector
var dialogue: StoryDialogue
var errors: Array[String] = []
var shown: Array[String] = []


## A choice style made by game code: picks the option with [member wanted]
## as its id, the way a 3D scene might when the player clicks an object.
class WorldPicker:
	extends RefCounted
	var wanted := ""
	var seen: Array = []

	func choose(options: Array[Dictionary], settings: Dictionary) -> int:
		seen.append([options.map(func(option: Dictionary) -> String: return option["id"]), settings.get("style")])
		await Engine.get_main_loop().process_frame
		for i in options.size():
			if options[i]["id"] == wanted:
				return i
		return -1


func before_each() -> void:
	story = track(StoryScript.new())
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryDialogue]
	config.text_speed = 0.0
	config.dialogue_box_transition = "none"
	config.choice_picture_folder = "res://tests/fixtures/choices"
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	dialogue = story.get_crew(&"Dialogue")
	errors.clear()
	shown.clear()
	director.runtime_error.connect(func(message: String, _tale: String, line: int) -> void:
		errors.append("%d: %s" % [line, message]))
	director.line_started.connect(func(line: Dictionary) -> void: shown.append(line["text"]))
	await tree.process_frame


func _add(source: String) -> void:
	var result := TaleCompiler.build(source, "doors", director.make_check_context("doors"))
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail(str(diagnostic))
	director.add_tale(result["tale"])


## Plays the tale, continuing lines and handing each visible choice menu
## to [param on_menu].
func _play(on_menu: Callable) -> void:
	var state := {"done": false}
	var run := func() -> void:
		await director.play("doors")
		state["done"] = true
	run.call()
	for i in 60:
		await tree.process_frame
		if state["done"]:
			return
		var menu: Control = null
		for style_name in dialogue.get_choice_style_names():
			var candidate: Variant = dialogue.get_choice_menu(style_name)
			if candidate is Control and candidate.visible:
				menu = candidate
		if menu != null:
			on_menu.call(menu)
		else:
			(dialogue.dialogue_box as ClassicDialogueBox).continue_pressed.emit()


func test_pictures_style_shows_picture_cards() -> void:
	_add(DOORS)
	var cards := []
	await _play(func(menu: Control) -> void:
		if not cards.is_empty():
			return
		assert_true(menu is PictureChoiceMenu)
		cards.append_array(menu.find_children("*", "Button", true, false))
		var pictures := cards.map(func(card: Button) -> Variant:
			var rect: TextureRect = card.find_child("Picture", true, false)
			return rect.texture.resource_path.get_file() if rect != null else null)
		assert_eq(pictures, ["red_door.png", "blue_door.png", null], "an option without @picture shows its text alone")
		assert_eq(cards.map(func(card: Button) -> String: return card.find_child("Caption", true, false).text), ["The red door", "The blue door", "Neither"])
		assert_eq(menu.find_children("*", "GridContainer", true, false)[0].columns, 2)
		cards[1].pressed.emit())
	assert_eq(errors, [])
	assert_eq(shown, ["blue", "done"])


func test_picture_menu_timeout_and_disabled_options() -> void:
	var menu: PictureChoiceMenu = track(PictureChoiceMenu.new())
	tree.root.add_child(menu)
	var options: Array[Dictionary] = [
		{"text": "A", "id": "a", "enabled": true, "picture": null},
		{"text": "B", "id": "b", "enabled": false, "picture": null},
	]
	var state := {"result": -99}
	var run := func() -> void: state["result"] = await menu.choose(options, {"timeout": 0.05})
	run.call()
	await tree.process_frame
	var cards := menu.find_children("*", "Button", true, false)
	assert_eq(cards.map(func(card: Button) -> bool: return card.disabled), [false, true])
	assert_eq(menu.find_children("*", "ProgressBar", true, false).size(), 1, "a countdown bar")
	await tree.create_timer(0.2).timeout
	assert_eq(state["result"], -1)
	assert_false(menu.visible)


func test_compiler_and_checker_know_picture() -> void:
	var result := TaleCompiler.build(DOORS, "doors")
	var tale: Tale = result["tale"]
	var choose: Dictionary = tale.instructions[tale.get_beat_start("start")]
	assert_eq(choose["options"].map(func(option: Dictionary) -> String: return option["picture"]), ["red_door", "blue_door", ""])
	var bad := TaleCompiler.build("beat start:\n\t@picture(\"x\") \"Narration\"\n\tchoose:\n\t\t@picture \"A\": pass\n", "bad")
	var messages := PackedStringArray()
	for diagnostic in bad["diagnostics"]:
		messages.append(diagnostic.message)
	assert_eq(messages, PackedStringArray([
		"@picture only applies to choice options.",
		"@picture needs one text argument, e.g. @picture(\"...\").",
	]))


func test_missing_picture_and_unknown_style_are_reported() -> void:
	_add("beat start:\n\tchoose(style = \"sparkles\"):\n\t\t\"A\": pass\n\tchoose(style = \"pictures\"):\n\t\t@picture(\"no_such_door\") \"B\": pass\n")
	var menus := []
	await _play(func(menu: Control) -> void:
		menus.append(str(menu.get_script().get_global_name()))
		menu.find_children("*", "Button", true, false)[0].pressed.emit())
	assert_eq(menus.slice(0, 1), ["ListChoiceMenu"], "an unknown style falls back to the list")
	assert_eq(errors, [
		"2: There is no choice style 'sparkles'. Styles: list, pictures.",
		"4: There is no choice picture 'no_such_door' in res://tests/fixtures/choices.",
	])


func test_game_code_can_provide_a_choice_style() -> void:
	var picker := WorldPicker.new()
	picker.wanted = "blue"
	dialogue.add_choice_style("world", picker)
	_add(DOORS.replace("style = \"pictures\", columns = 2", "style = \"world\""))
	await _play(func(_menu: Control) -> void: fail("no menu should open"))
	assert_eq(errors, [])
	assert_eq(shown, ["blue", "done"])
	assert_eq(picker.seen.size(), 1)
	assert_eq(picker.seen[0][1], "world")
	assert_has(picker.seen[0][0], "blue", "options keep their @id")
	dialogue.remove_choice_style("world")
	assert_false(dialogue.get_choice_style_names().has("world"))
	dialogue.remove_choice_style("list")
	assert_true(dialogue.get_choice_style_names().has("list"), "the list style always stays")


func test_config_adds_choice_styles() -> void:
	var other: Node = track(StoryScript.new())
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryDialogue]
	var scene := PackedScene.new()
	var root := PictureChoiceMenu.new()
	scene.pack(root)
	root.free()
	config.choice_styles = {"gallery": scene}
	other.start(config)
	tree.root.add_child(other)
	var other_dialogue: StoryDialogue = other.get_crew(&"Dialogue")
	assert_eq(other_dialogue.get_choice_style_names(), PackedStringArray(["list", "pictures", "gallery"]))
	assert_true(other_dialogue.get_choice_menu("gallery") is PictureChoiceMenu)

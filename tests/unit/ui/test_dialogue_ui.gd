extends "res://tests/framework/story_test.gd"
## Tests for the built-in dialogue box, choice menu, and Dialogue crew,
## driven by simulated player input.

const StoryScript := preload("res://addons/storyteller/core/story.gd")


func _line(text: String, speaker := "") -> Dictionary:
	return {"speaker_id": speaker, "speaker_name": speaker, "mood": "", "text": text, "id": "x", "voice": ""}


## Presses continue every frame until [param done] says to stop.
func _press_continue_until(box: ClassicDialogueBox, state: Dictionary) -> void:
	while not state["done"]:
		await tree.process_frame
		box.continue_pressed.emit()


func test_extract_pauses() -> void:
	var parsed := DialogueBox.extract_pauses("Hi.[pause] [b]Bold[/b][pause=0.5] end")
	assert_eq(parsed["text"], "Hi. [b]Bold[/b] end")
	assert_eq(parsed["pauses"], [{"at": 3, "seconds": -1.0}, {"at": 8, "seconds": 0.5}])
	assert_eq(DialogueBox.extract_pauses("plain")["pauses"], [])


func test_classic_box_reveals_and_waits_for_continue() -> void:
	var box: ClassicDialogueBox = track(ClassicDialogueBox.new())
	tree.root.add_child(box)
	box.characters_per_second = 0.0
	var state := {"done": false}
	var finish := func() -> void:
		await box.show_line(_line("Hello[pause] there", "Mira"))
		state["done"] = true
	finish.call()
	await tree.process_frame
	assert_false(state["done"], "waits for the player")
	assert_eq(box.get_node("Panel").find_child("Name", true, false).text, "Mira")
	var text_label: RichTextLabel = box.find_child("Text", true, false)
	assert_eq(text_label.visible_characters, 5, "stops at [pause]")
	box.continue_pressed.emit()
	await tree.process_frame
	assert_eq(text_label.visible_characters, 11)
	assert_false(state["done"])
	box.continue_pressed.emit()
	await tree.process_frame
	assert_true(state["done"])


func test_classic_box_skipping_needs_no_input() -> void:
	var box: ClassicDialogueBox = track(ClassicDialogueBox.new())
	tree.root.add_child(box)
	box.skipping = true
	var started := Time.get_ticks_msec()
	await box.show_line(_line("Fast[pause=5] line"))
	assert_true(Time.get_ticks_msec() - started < 1000, "timed pauses are skipped too")


func test_list_menu_returns_clicked_option() -> void:
	var menu: ListChoiceMenu = track(ListChoiceMenu.new())
	tree.root.add_child(menu)
	var options: Array[Dictionary] = [
		{"text": "A", "id": "a", "enabled": true},
		{"text": "B", "id": "b", "enabled": false},
		{"text": "C", "id": "c", "enabled": true},
	]
	var state := {"result": -99}
	var run := func() -> void: state["result"] = await menu.choose(options, {})
	run.call()
	await tree.process_frame
	var buttons := menu.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), 3)
	assert_true(buttons[1].disabled)
	buttons[2].pressed.emit()
	await tree.process_frame
	await tree.process_frame
	assert_eq(state["result"], 2)
	assert_false(menu.visible)


func test_list_menu_timeout() -> void:
	var menu: ListChoiceMenu = track(ListChoiceMenu.new())
	tree.root.add_child(menu)
	var options: Array[Dictionary] = [{"text": "A", "id": "a", "enabled": true}]
	var result: int = await menu.choose(options, {"timeout": 0.05})
	assert_eq(result, -1)


func test_story_plays_through_dialogue_crew() -> void:
	var story: Node = track(StoryScript.new())
	var config := StoryConfig.new()
	config.text_speed = 0.0
	story.start(config)
	tree.root.add_child(story)
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	var dialogue: StoryDialogue = story.get_crew(&"Dialogue")
	var result := TaleCompiler.build("var picked := \"\"\nbeat start:\n\t\"First.\"\n\tchoose:\n\t\t\"Left\": picked = \"left\"\n\t\t\"Right\": picked = \"right\"\n\t\"You went {picked}.\"\n", "ui_tale", director.make_check_context("ui_tale"))
	director.add_tale(result["tale"])
	var shown: Array[String] = []
	director.line_started.connect(func(line: Dictionary) -> void: shown.append(line["text"]))

	var state := {"done": false}
	var run := func() -> void:
		await story.play("ui_tale")
		state["done"] = true
	run.call()
	var box := dialogue.dialogue_box as ClassicDialogueBox
	for i in 30:
		await tree.process_frame
		if state["done"]:
			break
		var buttons := dialogue.choice_menu.find_children("*", "Button", true, false)
		if dialogue.choice_menu.visible and buttons.size() == 2:
			buttons[1].pressed.emit()
		else:
			box.continue_pressed.emit()
	assert_true(state["done"], "story finished")
	assert_eq(shown, ["First.", "You went right."])

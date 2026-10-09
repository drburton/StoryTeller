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


func test_extract_tags() -> void:
	var parsed := DialogueBox.extract_tags("A[speed=2]bc[/speed]d[instant]ef[act=0]g[/instant][sound=1]h[speed=0.5]ij")
	assert_eq(parsed["text"], "Abcdefghij")
	assert_eq(parsed["stops"], [
		{"at": 6, "kind": "tag", "tag": "act", "value": "0"},
		{"at": 7, "kind": "tag", "tag": "sound", "value": "1"},
	])
	assert_eq(parsed["spans"], [
		{"from": 1, "to": 3, "factor": 2.0},
		{"from": 4, "to": 7, "factor": 0.0},
		{"from": 8, "to": 10, "factor": 0.5},
	], "an unclosed span runs to the end")
	assert_eq(DialogueBox.extract_pauses("Hi[act=0] [b]you[/b][pause]")["text"], "Hi [b]you[/b]", "history text leaves out every typing tag")
	assert_eq(DialogueBox.plain_text("[b]Hi[/b][pause] [speed=2]you[/speed][act=0]."), "Hi you.")


func test_instant_span_shows_at_once_while_typing() -> void:
	var box: ClassicDialogueBox = track(ClassicDialogueBox.new())
	tree.root.add_child(box)
	box.characters_per_second = 1.0
	box.show_line(_line("a[instant]long sentence[/instant]b"))
	var text_label: RichTextLabel = box.find_child("Text", true, false)
	for i in 3:
		await tree.process_frame
	assert_true(text_label.visible_characters < 2, "slow typing before the span")
	box.characters_per_second = 1000.0
	for i in 3:
		await tree.process_frame
	assert_true(text_label.visible_characters >= 15, "the span appears in one step")
	box.cancel()


func test_speed_span_changes_typing_speed() -> void:
	var box: ClassicDialogueBox = track(ClassicDialogueBox.new())
	tree.root.add_child(box)
	box._spans = [{"from": 2, "to": 4, "factor": 3.0}, {"from": 3, "to": 6, "factor": 0.5}, {"from": 8, "to": 9, "factor": 0.0}]
	assert_eq(box._speed_at(0), 1.0)
	assert_eq(box._speed_at(2), 3.0)
	assert_eq(box._speed_at(3), 1.5, "nested spans multiply")
	assert_eq(box._speed_at(5), 0.5)
	assert_eq(box._speed_at(8), 0.0)
	assert_eq(box._instant_end(8), 9)


func test_text_tags_call_handler_in_order() -> void:
	var box: ClassicDialogueBox = track(ClassicDialogueBox.new())
	tree.root.add_child(box)
	box.characters_per_second = 0.0
	var calls: Array = []
	var text_label: RichTextLabel = box.find_child("Text", true, false)
	box.on_text_tag = func(tag: String, value: String) -> void:
		calls.append([tag, value, text_label.visible_characters])
	var state := {"done": false}
	var finish := func() -> void:
		await box.show_line(_line("One[act=0] two[pause][sound=1] three"))
		state["done"] = true
	finish.call()
	await tree.process_frame
	assert_eq(calls, [["act", "0", 3]], "runs where the tag is, then stops at the pause")
	box.continue_pressed.emit()
	await tree.process_frame
	assert_eq(calls, [["act", "0", 3], ["sound", "1", 7]])
	box.continue_pressed.emit()
	await tree.process_frame
	assert_true(state["done"])


func test_click_while_typing_shows_text_up_to_next_pause() -> void:
	var box: ClassicDialogueBox = track(ClassicDialogueBox.new())
	tree.root.add_child(box)
	box.characters_per_second = 1.0
	var calls: Array = []
	box.on_text_tag = func(tag: String, _value: String) -> void: calls.append(tag)
	box.show_line(_line("Slow text[act=0] keeps going[pause] then more"))
	await tree.process_frame
	box._advance()
	for i in 3:
		await tree.process_frame
	var text_label: RichTextLabel = box.find_child("Text", true, false)
	assert_eq(text_label.visible_characters, 21, "past the act tag, up to the pause")
	assert_eq(calls, ["act"], "tags passed on the way still run")
	box.cancel()


func test_story_runs_text_tags_while_the_line_shows() -> void:
	var story: Node = track(StoryScript.new())
	var config := StoryConfig.new()
	config.text_speed = 0.0
	story.start(config)
	tree.root.add_child(story)
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	var dialogue: StoryDialogue = story.get_crew(&"Dialogue")
	var source := "var hits := 0\nbeat start:\n\t\"Ow![act=emit(\\\"hit\\\", hits + 1)] That hurt.\"\n\tchoose:\n\t\t\"Pick[act=emit(\\\"never\\\")]\": pass\n"
	var result := TaleCompiler.build(source, "tag_tale", director.make_check_context("tag_tale"))
	assert_eq(result["diagnostics"].size(), 0)
	director.add_tale(result["tale"])
	var signals: Array = []
	director.story_signal.connect(func(signal_name: String, value: Variant) -> void: signals.append([signal_name, value]))
	var lines: Array[String] = []
	director.line_started.connect(func(line: Dictionary) -> void: lines.append(line["text"]))
	story.play("tag_tale")
	await tree.process_frame
	await tree.process_frame
	assert_eq(lines, ["Ow![act=0] That hurt."])
	assert_eq(signals, [["hit", 1]], "the act ran before the player continued")
	dialogue.dialogue_box.continue_pressed.emit()
	for i in 3:
		await tree.process_frame
	var buttons := dialogue.choice_menu.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), 1)
	assert_eq(buttons[0].text, "Pick", "choices leave tags out")
	director.stop()


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		tree.root.push_input(event)


func test_clicking_the_box_continues() -> void:
	var old_size := tree.root.size
	tree.root.size = Vector2i(1280, 720)
	for script in [ClassicDialogueBox, PageDialogueBox]:
		var box: DialogueBox = track(script.new())
		tree.root.add_child(box)
		box.characters_per_second = 0.0
		var state := {"done": false}
		var finish := func() -> void:
			await box.show_line(_line("Hello", "Ada"))
			state["done"] = true
		finish.call()
		await tree.process_frame
		await tree.process_frame
		var indicator: Control = box.find_child("Indicator", true, false)
		if indicator == null:
			indicator = box.get_node("Panel")
		_click(indicator.get_global_rect().get_center())
		await tree.process_frame
		assert_true(state["done"], "a click on the arrow of %s continues" % script.get_global_name())
		box.hide_box()
	tree.root.size = old_size


func test_code_is_tinted_by_the_theme() -> void:
	assert_eq(DialogueBox.tint_code("Use [code]wait(1)[/code].", Color(1, 0, 0)), "Use [code][color=#ff0000]wait(1)[/color][/code].")
	var box: ClassicDialogueBox = track(ClassicDialogueBox.new())
	tree.root.add_child(box)
	box.characters_per_second = 0.0
	var text_label: RichTextLabel = box.find_child("Text", true, false)
	box.show_line(_line("Plain [code]x[/code]"))
	await tree.process_frame
	assert_false(text_label.text.contains("[color="), "no tint without a code_color in the theme")
	box.cancel()
	box.theme = StoryTheme.build_default()
	box.show_line(_line("Tinted [code]x[/code]"))
	await tree.process_frame
	assert_true(text_label.text.contains("[code][color=#%s]x[/color][/code]" % StoryTheme.CODE.to_html(false)), "the default theme tints code")
	box.cancel()

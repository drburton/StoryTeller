extends "res://tests/framework/story_test.gd"
## Tests for the menus, dialogue styles, and text input, driven by simulated
## clicks and key presses.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const SAVE_FOLDER := "user://test_menu_saves"
const SETTINGS_PATH := "user://test_menu_settings.cfg"

var story: Node
var director: TaleDirector
var menus: StoryMenus
var dialogue: StoryDialogue
var shown: Array[String] = []


func before_each() -> void:
	_clean()
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryAudio, StorySaves, StorySettings, StoryRewind, StoryHistory, StoryDialogue, StoryMenus]
	config.save_folder = SAVE_FOLDER
	config.settings_path = SETTINGS_PATH
	config.start_tale = "menu_tale"
	config.text_speed = 0.0
	config.game_title = "Test Game"
	config.dialogue_box_transition = "none"
	config.autosave_on_choice = false
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	menus = story.get_crew(&"Menus")
	dialogue = story.get_crew(&"Dialogue")
	shown.clear()
	director.line_started.connect(func(line: Dictionary) -> void: shown.append(line["text"]))
	await tree.process_frame


func after_each() -> void:
	_clean()


func _clean() -> void:
	if DirAccess.dir_exists_absolute(SAVE_FOLDER):
		for file_name in DirAccess.get_files_at(SAVE_FOLDER):
			DirAccess.remove_absolute(SAVE_FOLDER.path_join(file_name))
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


func _add(source: String, tale_name := "menu_tale") -> void:
	var result := TaleCompiler.build(source, tale_name, director.make_check_context(tale_name))
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail(str(diagnostic))
	director.add_tale(result["tale"])


func _press(button_text: String) -> void:
	for button in story.find_children("*", "Button", true, false):
		if button.text == button_text and button.is_visible_in_tree() and not button.disabled:
			button.pressed.emit()
			await tree.process_frame
			return
	fail("no visible, enabled button '%s'" % button_text)


func _continue() -> void:
	dialogue.dialogue_box.continue_pressed.emit()
	await tree.process_frame


func _key(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await tree.process_frame
	await tree.process_frame


func test_title_screen_starts_a_new_game() -> void:
	_add("beat start:\n\t\"Hello.\"\n")
	menus.show_title()
	await tree.process_frame
	assert_true(menus.is_open())
	assert_eq(story.find_child("TitleScreen", true, false).find_child("*", true, false) != null, true)
	var continue_button: Button = _find_button("Continue")
	assert_true(continue_button.disabled, "no saves yet")
	await _press("New Game")
	assert_false(menus.is_open())
	assert_true(director.is_playing())
	assert_eq(shown, ["Hello."])


func test_story_end_returns_to_title() -> void:
	_add("beat start:\n\t\"Only line.\"\n")
	await _press_new_game()
	await _continue()
	await tree.process_frame
	await tree.process_frame
	assert_false(director.is_playing())
	assert_true(menus.is_open(), "title screen is back")


func test_pause_menu_blocks_dialogue_input() -> void:
	_add("beat start:\n\t\"One.\"\n\t\"Two.\"\n")
	await _press_new_game()
	await _key("story_menu")
	assert_true(menus.is_open())
	await _key("story_continue")
	assert_eq(shown, ["One."], "continue is ignored while the menu is open")
	await _press("Resume")
	assert_false(menus.is_open())
	await _key("story_continue")
	assert_eq(shown, ["One.", "Two."])


func test_save_and_load_through_screens() -> void:
	_add("var n := 0\nbeat start:\n\tn += 1\n\t\"Line {n}.\"\n\tn += 1\n\t\"Line {n}.\"\n\t\"End.\"\n")
	await _press_new_game()
	menus.open("save")
	await tree.process_frame
	await _press_slot("Slot 1")
	assert_true(menus.saves().has_slot("1"))
	menus.close_all()
	await _continue()
	assert_eq(shown, ["Line 1.", "Line 2."])
	menus.open("load")
	await tree.process_frame
	await _press_slot("Slot 1")
	await _press("Yes")
	await tree.process_frame
	assert_false(menus.is_open())
	assert_eq(shown, ["Line 1.", "Line 2.", "Line 1."], "the saved line is shown again")


func test_overwrite_asks_first() -> void:
	_add("beat start:\n\t\"Line.\"\n")
	await _press_new_game()
	menus.saves().save_slot("1")
	var first_time: float = menus.saves().read_slot("1")["saved_at"]
	menus.open("save")
	await tree.process_frame
	await _press_slot("Slot 1")
	await _press("No")
	assert_eq(menus.saves().read_slot("1")["saved_at"], first_time, "kept after answering No")


func test_settings_screen_changes_settings() -> void:
	menus.open("settings")
	await tree.process_frame
	var screen := story.find_child("SettingsScreen", true, false)
	var sliders := screen.find_children("*", "HSlider", true, false)
	sliders[0].value = 77.0
	assert_eq(menus.settings().get_value("text_speed"), 77.0)
	assert_eq(dialogue.dialogue_box.characters_per_second, 77.0)
	var toggles := screen.find_children("*", "CheckButton", true, false)
	toggles[1].button_pressed = true
	assert_true(menus.settings().get_value("skip_unread"))


func test_history_screen_lists_lines() -> void:
	_add("const ADA := \"Ada\"\nbeat start:\n\tADA: \"First.\"\n\t\"Second.\"\n\t\"Third.\"\n")
	await _press_new_game()
	await _continue()
	await _key("story_history")
	var screen := story.find_child("HistoryScreen", true, false)
	var texts := screen.find_children("*", "RichTextLabel", true, false).map(func(label: RichTextLabel) -> String: return label.text)
	assert_eq(texts, ["First.", "Second."])


func test_ask_text_action() -> void:
	_add("var player := \"\"\nbeat start:\n\tplayer = await ask_text(\"Your name?\", \"Sam\")\n\t\"Hi {player}.\"\n")
	await _press_new_game()
	await tree.process_frame
	assert_true(menus.is_open())
	var edit: LineEdit = story.find_children("*", "LineEdit", true, false)[0]
	assert_eq(edit.text, "Sam")
	edit.text = "Robin"
	await _press("OK")
	await tree.process_frame
	assert_eq(shown, ["Hi Robin."])


func test_page_style_collects_lines() -> void:
	_add("beat start:\n\tdialogue_style(\"page\")\n\t\"First paragraph.\"\n\t\"Second paragraph.\"\n\tclear_page()\n\t\"New page.\"\n\tdialogue_style(\"classic\")\n\t\"Back in the box.\"\n")
	await _press_new_game()
	var page: PageDialogueBox = dialogue._styles["page"]
	var text: RichTextLabel = page.find_child("Text", true, false)
	assert_true(page.visible)
	await _continue()
	assert_eq(text.get_parsed_text(), "First paragraph.\nSecond paragraph.")
	await _continue()
	assert_eq(text.get_parsed_text(), "New page.")
	await _continue()
	assert_false(page.visible)
	assert_eq(dialogue.style, "classic")
	assert_eq(shown.back(), "Back in the box.")


func test_unknown_dialogue_style_is_reported() -> void:
	var errors := []
	director.runtime_error.connect(func(message: String, _tale: String, _line: int) -> void: errors.append(message))
	_add("beat start:\n\tdialogue_style(\"comic\")\n\t\"x\"\n")
	await _press_new_game()
	assert_eq(errors, ["Unknown dialogue style 'comic'. Styles: classic, page."])


func test_quick_menu_shows_while_playing() -> void:
	_add("beat start:\n\t\"Line.\"\n")
	assert_false(menus.quick_menu.visible)
	await _press_new_game()
	await tree.process_frame
	assert_true(menus.quick_menu.visible)
	await _press("Auto")
	assert_true(dialogue.dialogue_box.auto_advance)
	await _press("Menu")
	assert_true(menus.is_open())
	await tree.process_frame
	assert_false(menus.quick_menu.visible)


func test_quick_menu_follows_the_dialogue_style() -> void:
	_add("beat start:\n\t\"Classic.\"\n\tdialogue_style(\"page\")\n\t\"Page.\"\n")
	await _press_new_game()
	await tree.process_frame
	var corner := menus.quick_menu.get_rect().end
	assert_eq(corner, dialogue.dialogue_box.get_quick_menu_corner())
	var classic_corner := corner
	await _continue()
	await tree.process_frame
	assert_eq(dialogue.style, "page")
	assert_eq(menus.quick_menu.get_rect().end, dialogue.dialogue_box.get_quick_menu_corner())
	assert_ne(menus.quick_menu.get_rect().end, classic_corner)


func test_language_picker_lists_translations() -> void:
	var locale := TranslationServer.get_locale()
	var added: Array[Translation] = []
	for code in ["en", "es"]:
		var translation := Translation.new()
		translation.locale = code
		translation.add_message("Settings", "Ajustes" if code == "es" else "Settings")
		TranslationServer.add_translation(translation)
		added.append(translation)
	menus.open("settings")
	await tree.process_frame
	var picker: OptionButton = story.find_child("SettingsScreen", true, false).find_children("*", "OptionButton", true, false)[0]
	assert_eq(picker.item_count, 2)
	assert_eq(picker.get_item_text(1), "Español")
	picker.select(1)
	picker.item_selected.emit(1)
	assert_eq(TranslationServer.get_locale(), "es")
	assert_eq(menus.settings().get_value("language"), "es")
	for translation in added:
		TranslationServer.remove_translation(translation)
	TranslationServer.set_locale(locale)


func _press_new_game() -> void:
	menus.show_title()
	await tree.process_frame
	await _press("New Game")
	await tree.process_frame


func _press_slot(label_start: String) -> void:
	for label in story.find_children("*", "Label", true, false):
		if label.text.begins_with(label_start) and label.is_visible_in_tree():
			var button := label.get_parent().get_parent() as Button
			button.pressed.emit()
			await tree.process_frame
			return
	fail("no slot '%s'" % label_start)


func _find_button(text: String) -> Button:
	for button in story.find_children("*", "Button", true, false):
		if button.text == text and button.is_visible_in_tree():
			return button
	return null


func _screen() -> SaveLoadScreen:
	return story.find_child("SaveLoadScreen", true, false) as SaveLoadScreen


func _visible_slot_names() -> Array:
	var names := []
	for label in story.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and (label.text.begins_with("Slot ") or label.text.begins_with("Auto save") or label.text.begins_with("Quick save")):
			names.append(label.text.get_slice("  ", 0))
	return names


func test_save_screen_adds_pages_as_slots_fill() -> void:
	menus.slot_count = 3
	_add("beat start:\n\t\"Line.\"\n")
	await _press_new_game()
	menus.open("save")
	await tree.process_frame
	assert_eq(_screen().get_page_count(), 1)
	assert_false(_screen()._nav.visible, "no page controls for one page")
	for slot in ["1", "2", "3"]:
		menus.saves().save_slot(slot)
	_screen().show_page(1)
	assert_eq(_screen().get_page_count(), 2, "a new page once the last one is full")
	assert_true(_screen()._nav.visible)
	assert_eq(_screen()._page_label.text, "Page 1 of 2")
	await _press("Next")
	assert_eq(_visible_slot_names(), ["Slot 4", "Slot 5", "Slot 6"])
	await _press_slot("Slot 5")
	assert_true(menus.saves().has_slot("5"))
	assert_eq(_screen().get_page_count(), 2)
	menus.saves().save_slot("6")
	_screen().show_page(2)
	assert_eq(_screen().get_page_count(), 3)
	menus.close_all()
	menus.open("load")
	await tree.process_frame
	assert_eq(_screen().get_page_count(), 2, "load pages stop at the last save")
	assert_eq(_screen().page, 2, "the screen remembers its page")
	_screen().show_page(1)
	assert_eq(_visible_slot_names(), ["Auto save", "Quick save", "Slot 1", "Slot 2", "Slot 3"])


func test_page_limit() -> void:
	menus.slot_count = 3
	menus.save_pages = 2
	_add("beat start:\n\t\"Line.\"\n")
	await _press_new_game()
	for slot in ["1", "2", "3", "4", "5", "6"]:
		menus.saves().save_slot(slot)
	menus.open("save")
	await tree.process_frame
	assert_eq(_screen().get_page_count(), 2)
	_screen().show_page(9)
	assert_eq(_screen().page, 2)


func test_rename_and_delete_from_the_screen() -> void:
	_add("beat start:\n\t\"Line.\"\n")
	await _press_new_game()
	menus.saves().save_slot("1")
	menus.open("load")
	await tree.process_frame
	await _press("Rename")
	var edit: LineEdit = story.find_children("*", "LineEdit", true, false)[0]
	edit.text = "  Before the exam  "
	await _press("OK")
	await tree.process_frame
	assert_eq(menus.saves().get_slot_info("1")["label"], "Before the exam")
	var labels := story.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree() and label.text == "Before the exam")
	assert_eq(labels.size(), 1, "the name shows on the slot")
	await _press("Delete")
	await _press("No")
	assert_true(menus.saves().has_slot("1"), "kept after answering No")
	await _press("Delete")
	await _press("Yes")
	assert_false(menus.saves().has_slot("1"))
	assert_null(_find_button("Rename"), "empty slots have no actions")


func test_slot_labels() -> void:
	_add("beat start:\n\t\"Line.\"\n")
	await _press_new_game()
	var saves := menus.saves()
	assert_eq(saves.set_slot_label("4", "x"), ERR_FILE_NOT_FOUND)
	saves.save_slot("4")
	assert_eq(saves.set_slot_label("4", "Chapter one"), OK)
	assert_eq(saves.read_slot("4")["label"], "Chapter one")
	assert_eq(saves.highest_numbered_slot(), 4)
	saves.save_slot("4")
	assert_false(saves.get_slot_info("4").has("label"), "saving again starts without a name")
	saves.set_slot_label("4", "Again")
	saves.set_slot_label("4", "")
	assert_false(saves.get_slot_info("4").has("label"), "an empty name removes it")


func test_timed_autosave() -> void:
	_add("beat start:\n\t\"One.\"\n\t\"Two.\"\n\t\"Three.\"\n")
	var saves := menus.saves()
	await _press_new_game()
	assert_false(saves.has_slot(StorySaves.AUTO_SLOT), "off by default")
	saves.autosave_minutes = 1.0
	saves._since_autosave = 59.0
	await _continue()
	assert_false(saves.has_slot(StorySaves.AUTO_SLOT), "not yet a minute")
	saves._since_autosave = 61.0
	await _continue()
	assert_true(saves.has_slot(StorySaves.AUTO_SLOT), "saved at the next line")
	assert_eq(saves.read_slot(StorySaves.AUTO_SLOT)["text"], "Three.")
	assert_true(saves._since_autosave < 1.0, "the timer starts over")


func test_title_screen_art_and_music() -> void:
	var audio := menus.audio()
	audio.audio_folder = "res://tests/fixtures/audio"
	menus.title_music = "theme"
	var image := Image.create(8, 8, false, Image.FORMAT_RGB8)
	menus.title_background = ImageTexture.create_from_image(image)
	_add("beat start:\n\t\"Line.\"\n")
	menus.show_title()
	await tree.process_frame
	assert_eq(audio.get_music_track(), "theme", "title music plays")
	var art: TextureRect = story.find_child("Art", true, false)
	assert_true(art.is_visible_in_tree())
	assert_eq(art.texture, menus.title_background)
	await _press("New Game")
	assert_eq(audio.get_music_track(), "", "and stops when a game starts")
	menus.title_background = null
	menus.show_title()
	await tree.process_frame
	assert_false(art.visible, "plain background without art")

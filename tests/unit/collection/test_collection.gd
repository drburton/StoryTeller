extends "res://tests/framework/story_test.gd"
## Tests for collect(), collected(), global unlocks, and the Extras screen.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const SAVE_FOLDER := "user://test_collection_saves"
const SETTINGS_PATH := "user://test_collection_settings.cfg"

var story: Node
var director: TaleDirector
var collection: StoryCollection
var menus: StoryMenus
var dialogue: StoryDialogue
var errors: Array[String] = []


func before_each() -> void:
	_clean()
	story = await _make_story()
	errors.clear()
	director.runtime_error.connect(func(message: String, _tale: String, line: int) -> void:
		errors.append("%d: %s" % [line, message]))


func after_each() -> void:
	_clean()


func _make_story() -> Node:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryAudio, StoryCollection, StorySaves, StorySettings, StoryDialogue, StoryMenus]
	config.collection_folder = "res://tests/fixtures/collection"
	config.audio_folder = "res://tests/fixtures/audio"
	config.save_folder = SAVE_FOLDER
	config.settings_path = SETTINGS_PATH
	config.autosave_on_choice = false
	config.text_speed = 0.0
	config.start_tale = "main"
	var made: Node = track(StoryScript.new())
	made.start(config)
	tree.root.add_child(made)
	director = made.get_crew(&"TaleDirector")
	collection = made.get_crew(&"Collection")
	menus = made.get_crew(&"Menus")
	dialogue = made.get_crew(&"Dialogue")
	await tree.process_frame
	return made


func _clean() -> void:
	if DirAccess.dir_exists_absolute(SAVE_FOLDER):
		for file_name in DirAccess.get_files_at(SAVE_FOLDER):
			DirAccess.remove_absolute(SAVE_FOLDER.path_join(file_name))
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


func _play(source: String) -> void:
	var result := TaleCompiler.build(source, "main", director.make_check_context("main"))
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail(str(diagnostic))
	director.add_tale(result["tale"])
	director.play("main")
	for i in 60:
		await tree.process_frame
		if not director.is_playing():
			return
		if dialogue.dialogue_box._waiting:
			dialogue.dialogue_box.continue_pressed.emit()


func _titles(items: Array[CollectionItem]) -> Array:
	return items.map(func(item: CollectionItem) -> String: return item.title)


func test_scan_finds_items_by_kind_and_order() -> void:
	assert_eq(_titles(collection.get_items("image")), ["Night", "A Sunny Day"], "order first, then title")
	assert_eq(_titles(collection.get_items("music")), ["Main Theme"])
	assert_true(collection.has_item("day_picture"), "id defaults to the file name")
	assert_true(collection.has_item("robin"), "or comes from the file")


func test_collect_unlocks_and_collected_reads_it() -> void:
	await _play("var seen := false\n\nbeat start:\n\tcollect(\"day_picture\")\n\tseen = collected(\"day_picture\")\n\t\"Done {seen} {collected(\\\"robin\\\")}.\"\n")
	assert_eq(errors, [])
	assert_true(collection.is_collected("day_picture"))
	assert_eq(director.get_tale_var("main", "seen"), [true, true])
	assert_eq(menus.get_notices(), PackedStringArray(["Unlocked: A Sunny Day"]))


func test_unknown_item_is_reported() -> void:
	await _play("beat start:\n\tcollect(\"unicorn\")\n\t\"x\"\n")
	assert_eq(errors, ["2: There is no collection item 'unicorn' in res://tests/fixtures/collection."])


func test_unlocks_are_kept_across_playthroughs() -> void:
	collection.collect("robin")
	story.get_crew(&"Saves").save_globals()
	await _make_story()
	assert_true(collection.is_collected("robin"))
	assert_false(collection.is_collected("day_picture"))


func test_extras_screen_shows_locked_and_unlocked_items() -> void:
	collection.collect("day_picture")
	collection.collect("robin")
	collection.collect("theme_song")
	menus.show_title()
	await tree.process_frame
	var extras_button := _button("Extras")
	assert_not_null(extras_button)
	extras_button.pressed.emit()
	await tree.process_frame
	var screen: ExtrasScreen = story.find_child("ExtrasScreen", true, false)
	assert_true(screen.visible)
	var tabs: TabContainer = screen.find_children("*", "TabContainer", true, false)[0]
	assert_eq([tabs.get_tab_title(0), tabs.get_tab_title(1), tabs.get_tab_title(2)], ["Gallery", "Music", "Codex"])
	var gallery_buttons := tabs.get_child(0).find_children("*", "Button", true, false)
	assert_eq(gallery_buttons.map(func(button: Button) -> bool: return button.disabled), [true, false], "night is locked")
	gallery_buttons[1].pressed.emit()
	assert_true(screen._viewer.visible)
	assert_eq(screen._viewer_caption.text, "The first morning.")
	assert_false(screen.on_back(), "Escape closes the picture first")
	assert_false(screen._viewer.visible)
	tabs.get_child(1).find_children("*", "Button", true, false)[0].pressed.emit()
	assert_eq(menus.audio().get_music_track(), "theme")
	screen._codex_list.item_selected.emit(0)
	assert_true(screen._codex_text.text.contains("Likes early mornings."))
	_button("Back").pressed.emit()
	assert_eq(menus.audio().get_music_track(), "", "leaving stops the music room track")


func test_title_hides_extras_without_a_collection() -> void:
	for id in ["day_picture", "night_picture", "theme_song", "robin"]:
		collection._items.erase(id)
	menus.show_title()
	await tree.process_frame
	assert_null(_button("Extras"))


func _button(text: String) -> Button:
	for button in story.find_children("*", "Button", true, false):
		if button.text == text and button.is_visible_in_tree():
			return button
	return null

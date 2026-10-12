extends "res://tests/framework/story_test.gd"
## Tests for the Studio app (studio/studio.tscn): the home screen with the
## student's stories, a story open in the blocks, saving, and playing.

const StudioScene := preload("res://studio/studio.tscn")
const ROOT := "user://test_studio_stories"
const SETTINGS := "user://test_studio_settings.json"


func before_each() -> void:
	super()
	_clean()


func after_each() -> void:
	_clean()
	var story: Node = tree.root.get_node("Story")
	story.start(story.load_config())
	super()


func _clean() -> void:
	StudioLibrary._remove_folder(ROOT)
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)


func _open() -> Control:
	var studio: Control = track(StudioScene.instantiate())
	studio.library_root = ROOT
	studio.settings_path = SETTINGS
	tree.root.add_child(studio)
	await tree.process_frame
	return studio


func _press(root: Node, label: String) -> void:
	for button in root.find_children("*", "Button", true, false):
		if button.get_meta("dialog_button", "") == label:
			button.pressed.emit()
			return
	fail("no button " + label)


## The name field of the dialog open over [param root].
func _name_field(root: Node) -> LineEdit:
	for field in root.find_children("*", "LineEdit", true, false):
		if field.get_meta("field_key", "") == "dialog:name":
			return field
	return null


func _titles(studio: Control) -> Array:
	return studio.home.get_cards().map(func(card: Control) -> String:
		return studio.library.get_story(card.get_meta("story_id"))["title"])


func test_home_shows_the_sample_with_its_picture() -> void:
	var studio := await _open()
	assert_true(studio.home.visible)
	assert_false(studio.story.visible)
	assert_eq(_titles(studio), ["Where's Biscuit?"])
	assert_true(studio.home.story_picture("wheres_biscuit") is Texture2D, "the card shows the first background")
	assert_eq(StudioHome.changed_words(0.0, 86400.0 * 3.5), "Changed 3 days ago")
	assert_eq(StudioHome.changed_words(100.0, 200.0), "Changed today")


func test_a_new_story_opens_in_the_blocks_and_saves_every_change() -> void:
	var studio := await _open()
	studio.home.new_story()
	var field := _name_field(studio.home)
	field.text = "Space Trip"
	_press(studio.home, "A blank story")
	await tree.process_frame
	assert_true(studio.story.visible)
	assert_eq(studio.story.story_id, "space_trip")
	assert_eq(studio.story.editor.tale_name(), "space_trip")
	assert_eq(studio.story._title_button.text, "Space Trip  ✎")
	assert_true(studio.story.editor.add_block("narrate", 0, 1, {"text": "Blast off!"}))
	assert_true(studio.library.read_tale("space_trip").contains("\"Blast off!\""), "saved at once")
	assert_false(studio.story._undo_button.disabled)
	studio.story.home_requested.emit()
	assert_true(studio.home.visible)
	assert_eq(_titles(studio), ["Space Trip", "Where's Biscuit?"], "the latest change comes first")


func test_a_copy_of_the_sample() -> void:
	var studio := await _open()
	studio.home.new_story()
	_press(studio.home, "A copy of Where's Biscuit?")
	await tree.process_frame
	assert_eq(studio.story.story_id, "my_story")
	assert_eq(studio.story.editor.get_scenes().size(), 9)


func test_stories_are_renamed_shared_and_deleted() -> void:
	var studio := await _open()
	var id: String = studio.library.create("Old name")
	studio.home.refresh()
	studio.home.rename_story(id)
	var field := _name_field(studio.home)
	field.text = "New name"
	_press(studio.home, "OK")
	assert_eq(studio.library.get_story(id)["title"], "New name")
	var messages := []
	StudioFiles.share(studio.library, id, func(text: String) -> void: messages.append(text))
	assert_true(FileAccess.file_exists(StudioFiles.OUTBOX.path_join(id + ".zip")))
	assert_true(studio.library.get_story(id)["shared"] > 0.0)
	assert_eq(messages.size(), 1)
	var opened := []
	StudioFiles.open_path(studio.library, StudioFiles.OUTBOX.path_join(id + ".zip"), func(new_id: String) -> void: opened.append(new_id), fail)
	assert_eq(opened, ["old_name_2"], "opening a story file adds it")
	studio.home.confirm_delete(id)
	_press(studio.home, "Keep it")
	assert_false(studio.library.get_story(id).is_empty())
	studio.home.confirm_delete(id)
	_press(studio.home, "Delete")
	assert_true(studio.library.get_story(id).is_empty())
	assert_eq(_titles(studio), ["New name", "Where's Biscuit?"])
	DirAccess.remove_absolute(StudioFiles.OUTBOX.path_join(id + ".zip"))


func test_cards_remind_to_share_old_changes() -> void:
	var studio := await _open()
	var id: String = studio.library.create("Old story")
	studio.library._update(id, {"created": 0.0, "changed": 100.0})
	studio.home.refresh()
	var reminders: Array = studio.home.find_children("*", "Label", true, false).filter(func(label: Node) -> bool: return label.has_meta("reminder"))
	assert_eq(reminders.size(), 1)


func test_renaming_from_the_story_screen() -> void:
	var studio := await _open()
	studio.open_story("wheres_biscuit")
	studio.story.rename()
	var field: LineEdit = studio.story.editor.get_dialog().find_children("*", "LineEdit", true, false)[0]
	field.text = "Biscuit Hunt"
	field.text_submitted.emit(field.text)
	assert_eq(studio.story._title_button.text, "Biscuit Hunt  ✎")
	assert_eq(studio.library.get_story("wheres_biscuit")["title"], "Biscuit Hunt")


func test_problems_do_not_stop_a_story_from_playing() -> void:
	assert_not_null(StudioStoryScreen.compile_story("beat start:\n\tmira: \"Hi\"\n", "t", null), "an unknown speaker is only a hint")
	assert_null(StudioStoryScreen.compile_story("beat start:\n\tif:\n", "t", null), "a mistake in the text stops it")


func test_play_shows_the_story_and_comes_back() -> void:
	var studio := await _open()
	studio.open_story("wheres_biscuit")
	studio.story.play("couch")
	await tree.process_frame
	assert_true(studio.story.is_playing())
	assert_false(studio.visible, "the story plays full screen")
	var story: Node = tree.root.get_node("Story")
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	assert_true(director.is_playing())
	studio.story.stop_playing()
	await tree.process_frame
	assert_false(studio.story.is_playing())
	assert_true(studio.visible)
	assert_false(story.has_crew(&"TaleDirector"))


func test_code_blocks_are_a_saved_setting() -> void:
	var studio := await _open()
	studio.open_story("wheres_biscuit")
	studio.story.editor.show_group("code")
	assert_eq(studio.story.editor.get_palette_blocks().size(), 1, "only Note")
	studio.set_show_code_blocks(true)
	assert_eq(studio.story.editor.get_palette_blocks().size(), 2, "Note and Code")
	studio.queue_free()
	await tree.process_frame
	var again := await _open()
	assert_true(again.settings["show_code_blocks"], "remembered")


func test_the_preview_follows_the_chosen_block() -> void:
	var studio := await _open()
	studio.open_story("wheres_biscuit")
	var editor: StudioBlockEditor = studio.story.editor
	assert_eq(studio.story.chosen_block().line_start, 11, "the first block of the scene until one is tapped")
	var theo := editor.get_blocks()[6]
	editor.select_block(theo)
	assert_eq(studio.story.chosen_block().line_start, 17)
	# The preview plays the setup over real time; wait for Theo, up to three seconds.
	var stage: Node = studio.story.preview.story.get_crew(&"Stage")
	var waited := 0.0
	while stage.capture()["cast"].keys() != ["cleo", "theo"] and waited < 3.0:
		await tree.create_timer(0.1).timeout
		waited += 0.1
	assert_eq(stage.capture()["cast"].keys(), ["cleo", "theo"])
	editor.select_scene("couch")
	assert_eq(studio.story.chosen_block().line_start, editor.doc.find_beat("couch").body[0].line_start)


func test_play_from_here_starts_at_the_chosen_block() -> void:
	var studio := await _open()
	studio.open_story("wheres_biscuit")
	var editor: StudioBlockEditor = studio.story.editor
	editor.select_block(editor.get_blocks()[6])
	studio.story.play_from_here()
	await tree.process_frame
	assert_true(studio.story.is_playing())
	var director: TaleDirector = tree.root.get_node("Story").get_crew(&"TaleDirector")
	assert_true(director.get_tale("wheres_biscuit").get_beat_start(StudioFromHere.FROM_HERE_BEAT) >= 0)
	assert_false(studio.story.preview.get_director().is_playing(), "the preview waits")
	studio.story.stop_playing()
	await tree.process_frame
	assert_eq(studio.story.preview.viewport.render_target_update_mode, SubViewport.UPDATE_ALWAYS)


func test_starter_characters_come_into_a_story_when_used() -> void:
	var studio := await _open()
	var id: String = studio.library.create("Space Trip")
	studio.open_story(id)
	var editor: StudioBlockEditor = studio.story.editor
	assert_true(studio.library.asset_names(id, "cast").is_empty(), "a blank story has no characters of its own")
	var offered := editor.character_items().map(func(item: Dictionary) -> String: return item["value"])
	assert_true(offered.has("theo") and offered.has("mira"), "the pickers offer the starter library")
	assert_true(editor.add_block("show", 0, 0))
	var show := editor.get_blocks()[0]
	assert_eq(show.get_meta("block")["fields"]["character"], "theo")
	assert_eq(studio.library.asset_names(id, "cast"), PackedStringArray(["theo"]), "copied into the story")
	assert_true(editor.get_hints(editor.get_blocks()[0]).is_empty(), "no hint once Theo is in the story")
	assert_true(editor.add_block("background", 0, 0))
	assert_eq(studio.library.asset_names(id, "backdrops").size(), 1)
	assert_true(studio.home.story_picture(id) is Texture2D)

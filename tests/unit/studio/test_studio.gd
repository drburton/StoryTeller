extends "res://tests/framework/story_test.gd"
## Tests for the Studio app (studio/studio.tscn): it opens the sample story
## in the blocks, saves every change, and plays the story as it is.

const StudioScene := preload("res://studio/studio.tscn")
const Studio := preload("res://studio/studio.gd")


func before_each() -> void:
	super()
	_clean()


func after_each() -> void:
	_clean()
	var story: Node = tree.root.get_node("Story")
	story.start(story.load_config())
	super()


func _clean() -> void:
	if FileAccess.file_exists(Studio.SAVED_TALE):
		DirAccess.remove_absolute(Studio.SAVED_TALE)


func _open() -> Control:
	var studio: Control = track(StudioScene.instantiate())
	tree.root.add_child(studio)
	await tree.process_frame
	return studio


func test_the_sample_opens_and_every_change_is_saved() -> void:
	var studio := await _open()
	var editor: StudioBlockEditor = studio.editor
	assert_eq(editor.get_scenes().size(), 9)
	assert_eq(editor.tale_name(), "wheres_biscuit")
	assert_true(studio._undo_button.disabled)
	assert_true(editor.add_block("narrate", 0, 0, {"text": "Saved at once."}))
	assert_true(FileAccess.file_exists(Studio.SAVED_TALE))
	assert_eq(FileAccess.get_file_as_string(Studio.SAVED_TALE), editor.source)
	assert_false(studio._undo_button.disabled)
	studio.queue_free()
	await tree.process_frame
	var again := await _open()
	assert_eq(again.editor.get_blocks()[0].get_meta("block")["fields"]["text"], "Saved at once.", "the saved copy opens next time")
	again._on_menu(1)
	assert_eq(again.editor.source, FileAccess.get_file_as_string(Studio.SAMPLE_TALE), "the sample can start over")
	assert_true(again.editor.can_undo(), "and starting over can be undone")


func test_problems_do_not_stop_a_story_from_playing() -> void:
	assert_not_null(Studio.compile_story("beat start:\n\tmira: \"Hi\"\n", "t", null), "an unknown speaker is only a hint")
	assert_null(Studio.compile_story("beat start:\n\tif:\n", "t", null), "a mistake in the text stops it")


func test_play_shows_the_story_and_comes_back() -> void:
	var studio := await _open()
	studio.play("couch")
	await tree.process_frame
	assert_true(studio.is_playing())
	assert_false(studio.visible, "the story plays full screen")
	var story: Node = tree.root.get_node("Story")
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	assert_not_null(director)
	assert_true(director.is_playing())
	studio.stop_playing()
	await tree.process_frame
	assert_false(studio.is_playing())
	assert_true(studio.visible)
	assert_false(story.has_crew(&"TaleDirector"))


func test_code_blocks_are_a_setting() -> void:
	var studio := await _open()
	studio.editor.show_group("code")
	assert_eq(studio.editor.get_palette_blocks().size(), 1, "only Note")
	studio._on_menu(0)
	assert_eq(studio.editor.get_palette_blocks().size(), 2, "Note and Code")

extends "res://tests/framework/story_test.gd"
## Tests for save slots, global data, read tracking, and settings.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const SAVE_FOLDER := "user://test_saves"
const SETTINGS_PATH := "user://test_settings.cfg"

const SOURCE := """var count := 0
@global var endings := 0

beat start:
	count += 1
	"First {count}."
	"Second {count}."
	choose:
		"Left":
			"Went left."
		"Right":
			"Went right."
	endings += 1
	"The end."
"""


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _clean() -> void:
	if DirAccess.dir_exists_absolute(SAVE_FOLDER):
		for file_name in DirAccess.get_files_at(SAVE_FOLDER):
			DirAccess.remove_absolute(SAVE_FOLDER.path_join(file_name))
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


## Makes a Story with director, saves, settings, and a scripted presenter.
func _make_story() -> Dictionary:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StorySaves, StorySettings]
	config.save_folder = SAVE_FOLDER
	config.settings_path = SETTINGS_PATH
	var story: Node = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	var presenter: ScriptedPresenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	director.presenter = presenter
	await tree.process_frame
	director.add_tale(TaleCompiler.build(SOURCE, "main", director.make_check_context("main"))["tale"])
	return {"story": story, "director": director, "saves": story.get_crew(&"Saves"), "settings": story.get_crew(&"Settings"), "presenter": presenter}


func test_save_and_load_slot_shows_the_saved_line_again() -> void:
	var first := await _make_story()
	var saves: StorySaves = first["saves"]
	first["presenter"].on_line = func(line: Dictionary) -> void:
		if line["text"] == "Second 1.":
			assert_eq(saves.save_slot("1"), OK)
	first["presenter"].picks = ["Left"]
	await first["director"].play("main")
	assert_true(saves.has_slot("1"))
	var info := saves.get_slot_info("1")
	assert_eq(info["text"], "Second 1.")
	assert_eq(info["format"], StorySaves.FORMAT)

	var second := await _make_story()
	second["presenter"].picks = ["Right"]
	assert_eq(second["saves"].load_slot("1"), OK)
	while second["director"].is_playing():
		await tree.process_frame
	assert_eq(second["presenter"].lines, ["Second 1.", "Went right.", "The end."])


func test_loading_during_a_choice_reshows_the_choice() -> void:
	var game := await _make_story()
	var saves: StorySaves = game["saves"]
	var director: TaleDirector = game["director"]
	director.choice_started.connect(func(_options: Array[Dictionary]) -> void:
		if not saves.has_slot("at_choice"):
			saves.save_slot("at_choice"), CONNECT_ONE_SHOT)
	game["presenter"].picks = ["Left", "Right"]
	await director.play("main")
	assert_eq(saves.load_slot("at_choice"), OK)
	while director.is_playing():
		await tree.process_frame
	assert_eq(game["presenter"].offered.size(), 2, "the choice was shown again")
	assert_eq(game["presenter"].lines.slice(-2), ["Went right.", "The end."])


func test_load_while_playing_keeps_play_waiting() -> void:
	var game := await _make_story()
	var saves: StorySaves = game["saves"]
	var director: TaleDirector = game["director"]
	var loaded := [false]
	game["presenter"].on_line = func(line: Dictionary) -> void:
		if line["text"] == "First 1.":
			saves.save_slot("early")
		elif line["text"] == "Went left." and not loaded[0]:
			loaded[0] = true
			saves.load_slot.call_deferred("early")
	game["presenter"].picks = ["Left", "Right"]
	await director.play("main")
	assert_eq(game["presenter"].lines.slice(-4), ["First 1.", "Second 1.", "Went right.", "The end."], "play() returned only after the loaded story ended")


func test_autosave_before_choices_and_quick_save() -> void:
	var game := await _make_story()
	var saves: StorySaves = game["saves"]
	game["presenter"].picks = ["Left"]
	await game["director"].play("main")
	assert_true(saves.has_slot(StorySaves.AUTO_SLOT))
	assert_eq(saves.quick_save(), OK)
	assert_true(saves.has_slot(StorySaves.QUICK_SLOT))
	assert_eq(saves.latest_slot(), StorySaves.QUICK_SLOT)
	assert_has(saves.list_slots(), StorySaves.AUTO_SLOT)
	saves.delete_slot(StorySaves.QUICK_SLOT)
	assert_false(saves.has_slot(StorySaves.QUICK_SLOT))


func test_globals_and_read_lines_persist() -> void:
	var first := await _make_story()
	await first["director"].play("main")
	first["saves"].save_globals()
	var second := await _make_story()
	var director: TaleDirector = second["director"]
	assert_eq(JSON.to_native(director.capture_globals()["vars"]), {"endings": 1})
	var tale := director.get_tale("main")
	assert_true(director.is_line_read(tale.instructions[1]["id"]), "the first line was read last time")
	await director.play("main")
	assert_true(second["presenter"].line_data[0]["read"])


func test_old_formats_are_migrated() -> void:
	var game := await _make_story()
	var saves: StorySaves = game["saves"]
	DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)
	var file := FileAccess.open(SAVE_FOLDER.path_join("old.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": 0, "body": {"crew": {}}}))
	file.close()
	assert_eq(saves.read_slot("old"), {}, "no migration registered yet")
	saves.migrations[0] = func(data: Dictionary) -> Dictionary:
		return {"state": data["body"], "text": "upgraded"}
	var upgraded := saves.read_slot("old")
	assert_eq(upgraded["format"], StorySaves.FORMAT)
	assert_eq(upgraded["text"], "upgraded")


func test_damaged_slot_is_reported() -> void:
	var game := await _make_story()
	DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)
	var file := FileAccess.open(SAVE_FOLDER.path_join("bad.json"), FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_eq(game["saves"].load_slot("bad"), ERR_FILE_NOT_FOUND)


func test_settings_persist_and_apply() -> void:
	var game := await _make_story()
	var settings: StorySettings = game["settings"]
	assert_eq(settings.get_value("text_speed"), 40.0)
	settings.set_value("text_speed", 80.0)
	settings.set_value("skip_unread", true)
	var other := await _make_story()
	assert_eq(other["settings"].get_value("text_speed"), 80.0)
	assert_true(other["settings"].get_value("skip_unread"))
	other["settings"].reset_to_defaults()
	assert_eq(other["settings"].get_value("text_speed"), StorySettings.DEFAULTS["text_speed"])


func test_settings_reach_dialogue_and_audio() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryAudio, StorySettings, StoryDialogue]
	config.settings_path = SETTINGS_PATH
	var story: Node = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	await tree.process_frame
	var settings: StorySettings = story.get_crew(&"Settings")
	settings.set_value("text_speed", 12.0)
	settings.set_value("auto_delay", 2.5)
	settings.set_value("music_volume", 0.25)
	var dialogue: StoryDialogue = story.get_crew(&"Dialogue")
	assert_eq(dialogue.dialogue_box.characters_per_second, 12.0)
	assert_eq(dialogue.dialogue_box.auto_delay, 2.5)
	assert_eq(story.get_crew(&"Audio").volumes["music"], 0.25)

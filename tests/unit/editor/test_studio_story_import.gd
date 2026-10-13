extends "res://tests/framework/story_test.gd"
## Tests for Open a Studio story (addons/storyteller/editor/
## studio_story_import.gd and core/story_file.gd): a story file shared from
## the Studio becomes a story folder of its own in a Godot project, with a
## config and a scene that plays it (decision 0022).

const STORIES := "user://test_import_stories"
const PROJECT := "user://test_import_project"
const ZIP := "user://test_import_story.zip"

var library: StudioLibrary


func before_each() -> void:
	super()
	StudioLibrary._remove_folder(STORIES)
	StudioLibrary._remove_folder(PROJECT)
	library = StudioLibrary.new(STORIES)


func after_each() -> void:
	StudioLibrary._remove_folder(STORIES)
	StudioLibrary._remove_folder(PROJECT)
	if FileAccess.file_exists(ZIP):
		DirAccess.remove_absolute(ZIP)
	super()


func _shared_story() -> String:
	var id := library.create("Castle Trip", "beat start:\n\tbackdrop(\"castle\")\n\tmusic(\"adventure\")\n\tmaya.enter(\"happy\", at = LEFT)\n\tmaya: \"We made it!\"\n\tsound(\"pop\")\n\tif visited(\"castle_trip.start\"):\n\t\t\"Again!\"\n")
	library.add_starter_items(id)
	assert_true(library.pack(id, ZIP))
	return id


func test_a_story_file_becomes_a_story_folder() -> void:
	_shared_story()
	var result := StudioStoryImport.open(ZIP, PROJECT)
	assert_eq(result["error"], "")
	assert_eq(result["title"], "Castle Trip")
	var folder := PROJECT.path_join("castle_trip")
	assert_eq(result["folder"], folder)
	assert_eq(result["tale_path"], folder.path_join("tales/castle_trip.tale"))
	for file in ["backdrops/castle.png", "cast/maya/happy.png", "cast/maya/profile.json", "audio/music/adventure.wav", "audio/sounds/pop.wav"]:
		assert_true(FileAccess.file_exists(folder.path_join(file)), file)
	var config := load(result["config_path"]) as StoryConfig
	assert_eq(config.tales_folder, folder.path_join("tales"))
	assert_eq(config.cast_folder, folder.path_join("cast"))
	assert_eq(config.start_tale, "castle_trip")
	assert_eq(config.game_title, "Castle Trip")
	assert_eq(config.save_folder, "user://castle_trip_saves")
	var scene := load(result["scene_path"]) as PackedScene
	var launcher := scene.instantiate()
	assert_true(launcher is StoryLauncher)
	assert_eq(launcher.config.resource_path, result["config_path"], "the scene uses the story's own config")
	launcher.free()


func test_the_added_story_checks_with_its_own_pictures_and_sounds() -> void:
	_shared_story()
	var result := StudioStoryImport.open(ZIP, PROJECT)
	var config := load(result["config_path"]) as StoryConfig
	var source := FileAccess.get_file_as_string(result["tale_path"])
	var context := TaleSignatures.make_context(result["tale_path"], "castle_trip", config)
	var problems := TaleChecker.check(TaleParser.parse(source), context)
	assert_eq(problems.map(func(problem: TaleDiagnostic) -> String: return problem.message), [])
	assert_eq(StoryStage.scan_cast(config.cast_folder)["maya"].get_display_name(), "Maya")


func test_a_second_copy_gets_its_own_folder() -> void:
	_shared_story()
	StudioStoryImport.open(ZIP, PROJECT)
	var second := StudioStoryImport.open(ZIP, PROJECT)
	assert_eq(second["folder"], PROJECT.path_join("castle_trip_2"))
	var text := FileAccess.get_file_as_string(second["tale_path"])
	assert_true(text.contains("visited(\"castle_trip_2.start\")"), "tests name the new copy")
	assert_eq((load(second["config_path"]) as StoryConfig).start_tale, "castle_trip_2")


func test_files_that_are_not_stories_are_refused() -> void:
	var result := StudioStoryImport.open("res://README.md", PROJECT)
	assert_eq(result["error"], "That file is not a story file.")
	var packer := ZIPPacker.new()
	packer.open(ZIP)
	packer.start_file("story.json")
	packer.write_file("{}".to_utf8_buffer())
	packer.close_file()
	packer.start_file("tales/sneaky.tale")
	packer.write_file("beat start:\n\t\"Hi\"\n".to_utf8_buffer())
	packer.close_file()
	packer.start_file("cast/sneaky.tres")
	packer.write_file("[gd_resource]".to_utf8_buffer())
	packer.close_file()
	packer.start_file("scripts/run.gd")
	packer.write_file("extends Node".to_utf8_buffer())
	packer.close_file()
	packer.close()
	result = StudioStoryImport.open(ZIP, PROJECT)
	assert_eq(result["error"], "")
	assert_false(FileAccess.file_exists(result["folder"].path_join("cast/sneaky.tres")), "no resources, which could run code")
	assert_false(DirAccess.dir_exists_absolute(result["folder"].path_join("scripts")))


func test_the_story_tab_opens_a_studio_story() -> void:
	_shared_story()
	var panel: TaleEditorPanel = track(TaleEditorPanel.new())
	tree.root.add_child(panel)
	var tale := panel.open_studio_story(ZIP, PROJECT)
	assert_eq(tale, PROJECT.path_join("castle_trip/tales/castle_trip.tale"))
	assert_eq(panel.get_current_path(), tale)
	assert_eq(panel.open_studio_story("res://README.md", PROJECT), "")

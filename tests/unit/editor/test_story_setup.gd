extends "res://tests/framework/story_test.gd"
## Tests for the setup wizard: StorySetup makes folders, a config, a first
## tale, and a main scene, and never overwrites.

const ROOT := "user://setup_test/story"
const SCENE := "user://setup_test/main.tscn"


func before_each() -> void:
	_remove("user://setup_test")


func after_each() -> void:
	_remove("user://setup_test")


func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for folder in DirAccess.get_directories_at(path):
		_remove(path.path_join(folder))
	DirAccess.remove_absolute(path)


func test_setup_makes_a_project_that_plays() -> void:
	var result := StorySetup.run({"root": ROOT, "scene_path": SCENE, "game_title": "Lighthouse", "languages": PackedStringArray(["es"])})
	assert_eq(result["errors"], PackedStringArray())
	for folder in ["tales", "cast", "backdrops", "props", "cgs", "choices", "transitions", "collection", "translations", "audio/music", "audio/voice"]:
		assert_true(DirAccess.dir_exists_absolute(ROOT.path_join(folder)), folder)
	var config := load(result["config_path"]) as StoryConfig
	assert_not_null(config)
	assert_eq(config.tales_folder, ROOT.path_join("tales"))
	assert_eq(config.choice_picture_folder, ROOT.path_join("choices"))
	assert_eq(config.translation_file, ROOT.path_join("translations/story.csv"))
	assert_eq(config.game_title, "Lighthouse")
	assert_eq(config.languages, PackedStringArray(["es"]))
	assert_eq(config.start_tale, "start")
	var tale_source := FileAccess.get_file_as_string(result["tale_path"])
	assert_true(tale_source.contains(result["tale_path"]), "the tale says where it lives")
	var director: TaleDirector = track(TaleDirector.new())
	var built := TaleCompiler.build(tale_source, "start", director.make_check_context("start"))
	for diagnostic in built["diagnostics"]:
		fail(str(diagnostic))
	var scene := load(SCENE) as PackedScene
	var node: Node = scene.instantiate()
	assert_true(node.get_script().source_code.contains("Story.show_title()"))
	node.free()


func test_setup_keeps_what_exists() -> void:
	StorySetup.run({"root": ROOT, "scene_path": SCENE})
	var file := FileAccess.open(ROOT.path_join("tales/start.tale"), FileAccess.WRITE)
	file.store_string("beat start:\n\t\"Mine.\"\n")
	file.close()
	var again := StorySetup.run({"root": ROOT, "scene_path": SCENE, "game_title": "Other"})
	assert_eq(again["created"], PackedStringArray())
	assert_eq(again["kept"].size(), 4, "config, tale, script, scene")
	assert_eq(FileAccess.get_file_as_string(ROOT.path_join("tales/start.tale")), "beat start:\n\t\"Mine.\"\n")
	assert_eq((load(again["config_path"]) as StoryConfig).game_title, "")


func test_setup_without_extras() -> void:
	var result := StorySetup.run({"root": ROOT, "sample_tale": false, "starter_scene": false})
	assert_eq(result["tale_path"], "")
	assert_eq(result["scene_path"], "")
	assert_eq((load(result["config_path"]) as StoryConfig).start_tale, "")


func test_wizard_dialog_passes_its_fields() -> void:
	var dialog: StorySetupDialog = track(StorySetupDialog.new())
	dialog.root_field.text = ROOT
	dialog.title_field.text = "  Lighthouse "
	dialog.languages_field.text = "es, fr,"
	dialog.scene_check.button_pressed = false
	var result := dialog.run_setup()
	assert_eq(result["errors"], PackedStringArray())
	var config := load(result["config_path"]) as StoryConfig
	assert_eq(config.game_title, "Lighthouse")
	assert_eq(config.languages, PackedStringArray(["es", "fr"]))
	assert_eq(result["scene_path"], "")
	assert_false(StorySetup.needs_setup(), "this project already has its config")

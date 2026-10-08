extends "res://tests/framework/story_test.gd"
## Keeps the demo working: its tales check cleanly and its config opens on
## the title screen.

const TaleImporter := preload("res://addons/storyteller/editor/tale_importer.gd")
const DEMO_TALES := "res://demo/tales"


func test_demo_tales_have_no_diagnostics() -> void:
	var names := PackedStringArray()
	for file_name in DirAccess.get_files_at(DEMO_TALES):
		if not file_name.ends_with(".tale"):
			continue
		var path := DEMO_TALES.path_join(file_name)
		var tale_name := file_name.get_basename()
		names.append(tale_name)
		var context := TaleImporter._make_context(path, tale_name)
		var result := TaleCompiler.build(FileAccess.get_file_as_string(path), tale_name, context)
		for diagnostic in result["diagnostics"]:
			fail("%s: %s" % [file_name, diagnostic])
	assert_has(names, "welcome")


func test_demo_config_starts_from_the_title_screen() -> void:
	var config := load("res://demo/story_config.tres") as StoryConfig
	assert_eq(config.start_tale, "welcome")
	assert_true(ResourceLoader.exists(DEMO_TALES.path_join(config.start_tale + ".tale")))
	assert_false(config.game_title.is_empty())

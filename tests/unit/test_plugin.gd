extends "res://tests/framework/story_test.gd"
## Checks that the addon's metadata and project wiring stay consistent.

const PLUGIN_CFG := "res://addons/storyteller/plugin.cfg"
const StoryScript := preload("res://addons/storyteller/core/story.gd")


func _plugin_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(PLUGIN_CFG), OK, "plugin.cfg loads")
	return cfg


func test_plugin_cfg_fields() -> void:
	var cfg := _plugin_cfg()
	assert_eq(cfg.get_value("plugin", "name", ""), "StoryTeller")
	var script_path := PLUGIN_CFG.get_base_dir().path_join(cfg.get_value("plugin", "script", ""))
	assert_true(ResourceLoader.exists(script_path), "plugin script exists")


func test_versions_match() -> void:
	var cfg := _plugin_cfg()
	assert_eq(cfg.get_value("plugin", "version", ""), StoryScript.VERSION)


func test_autoload_registered() -> void:
	assert_eq(
		ProjectSettings.get_setting("autoload/Story", ""),
		"*res://addons/storyteller/core/story.gd",
	)


func test_running_godot_meets_project_version() -> void:
	var features: PackedStringArray = ProjectSettings.get_setting("application/config/features", PackedStringArray())
	var required := ""
	for feature in features:
		if feature.count(".") == 1 and feature.get_slice(".", 0).is_valid_int():
			required = feature
	assert_ne(required, "", "project.godot declares a Godot version")
	var info := Engine.get_version_info()
	var running := Vector2i(info["major"], info["minor"])
	var minimum := Vector2i(required.get_slice(".", 0).to_int(), required.get_slice(".", 1).to_int())
	assert_true(running >= minimum, "Godot %d.%d is older than the project's %s" % [running.x, running.y, required])


func test_addon_ships_project_license() -> void:
	# The addon folder is distributed on its own (Asset Library), so it carries
	# a copy of the license that must match the repository's.
	var root_license := FileAccess.get_file_as_string("res://LICENSE")
	var addon_license := FileAccess.get_file_as_string("res://addons/storyteller/LICENSE")
	assert_true(root_license.begins_with("MIT License"), "root LICENSE is MIT")
	assert_eq(addon_license, root_license, "addon LICENSE matches root LICENSE")

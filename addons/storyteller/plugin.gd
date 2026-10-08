@tool
extends EditorPlugin
## Editor entry point for StoryTeller.
##
## Registers the [code]Story[/code] autoload, the project settings that
## StoryTeller reads at runtime, and the importer for [code].tale[/code] files.

const AUTOLOAD_NAME := "Story"
const AUTOLOAD_PATH := "res://addons/storyteller/core/story.gd"
const StoryScript := preload("res://addons/storyteller/core/story.gd")
const TaleImporter := preload("res://addons/storyteller/editor/tale_importer.gd")

var _tale_importer: EditorImportPlugin


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	_register_project_settings()
	ProjectSettings.save()


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _enter_tree() -> void:
	_register_project_settings()
	_tale_importer = TaleImporter.new()
	add_import_plugin(_tale_importer)


func _exit_tree() -> void:
	remove_import_plugin(_tale_importer)
	_tale_importer = null


func _register_project_settings() -> void:
	var setting := StoryScript.CONFIG_SETTING
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, StoryConfig.DEFAULT_PATH)
	ProjectSettings.set_initial_value(setting, StoryConfig.DEFAULT_PATH)
	ProjectSettings.set_as_basic(setting, true)
	ProjectSettings.add_property_info({
		"name": setting,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tres,*.res",
	})

@tool
extends EditorPlugin
## Editor entry point for StoryTeller.
##
## Registers the [code]Story[/code] autoload, the project settings that
## StoryTeller reads at runtime, the importer for [code].tale[/code] files,
## and the "Story" main screen for editing tales.

const AUTOLOAD_NAME := "Story"
const AUTOLOAD_PATH := "res://addons/storyteller/core/story.gd"
const StoryScript := preload("res://addons/storyteller/core/story.gd")
const TaleImporter := preload("res://addons/storyteller/editor/tale_importer.gd")

var _tale_importer: EditorImportPlugin
var _panel: TaleEditorPanel


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
	_panel = TaleEditorPanel.new()
	_panel.name = "StoryEditor"
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_make_visible(false)


func _exit_tree() -> void:
	remove_import_plugin(_tale_importer)
	_tale_importer = null
	if _panel:
		_panel.queue_free()
		_panel = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _panel:
		_panel.visible = visible
		if visible:
			_panel.refresh_files()


func _get_plugin_name() -> String:
	return "Story"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("TextFile", "EditorIcons")


## Selecting a compiled tale in the FileSystem dock opens its source in the
## Story screen (without switching to it).
func _handles(object: Object) -> bool:
	return object is Tale


func _edit(object: Object) -> void:
	if object is Tale and _panel and not object.source_path.is_empty():
		_panel.open_file(object.source_path)


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

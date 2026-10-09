@tool
class_name StorySetup
extends RefCounted
## Sets up a project for StoryTeller: the story folders, a [StoryConfig]
## that points at them, a first tale, and a main scene that opens the
## title screen. The setup wizard in the Story tab runs it; it never
## overwrites a file that already exists.
## [codeblock]
## var result := StorySetup.run({"game_title": "Lighthouse"})
## result["created"]   # paths written
## result["kept"]      # paths that already existed and were left alone
## StorySetup.register(result["config_path"], result["scene_path"])
## [/codeblock]

## Folders made under the root, by their [StoryConfig] property.
const FOLDERS := {
	"tales_folder": "tales",
	"cast_folder": "cast",
	"backdrop_folder": "backdrops",
	"prop_folder": "props",
	"cg_folder": "cgs",
	"choice_picture_folder": "choices",
	"transition_folder": "transitions",
	"collection_folder": "collection",
	"audio_folder": "audio",
}
const AUDIO_SUBFOLDERS: Array[String] = ["music", "sounds", "ambience", "voice"]
const SAMPLE_TALE := "start"

const DEFAULTS := {
	"root": "res://story",
	"game_title": "",
	"source_language": "en",
	"languages": [],
	"sample_tale": true,
	"starter_scene": true,
	"scene_path": "res://main.tscn",
}


## Creates what is missing. [param options] may set: [code]root[/code]
## (folder for everything, "res://story"), [code]game_title[/code],
## [code]source_language[/code] ("en"), [code]languages[/code] (more
## languages to translate into), [code]sample_tale[/code] and
## [code]starter_scene[/code] (both true), and [code]scene_path[/code]
## ("res://main.tscn"). Returns [code]{"created", "kept", "errors",
## "config_path", "scene_path", "tale_path"}[/code].
static func run(options := {}) -> Dictionary:
	var settings := DEFAULTS.duplicate()
	settings.merge(options, true)
	var root: String = settings["root"].trim_suffix("/")
	var result := {
		"created": PackedStringArray(), "kept": PackedStringArray(), "errors": PackedStringArray(),
		"config_path": root.path_join("story_config.tres"), "scene_path": "", "tale_path": "",
	}
	for property in FOLDERS:
		_make_folder(root.path_join(FOLDERS[property]), result)
	for sub in AUDIO_SUBFOLDERS:
		_make_folder(root.path_join("audio").path_join(sub), result)
	_make_folder(root.path_join("translations"), result)

	if FileAccess.file_exists(result["config_path"]):
		result["kept"].append(result["config_path"])
	else:
		var config := StoryConfig.new()
		for property in FOLDERS:
			config.set(property, root.path_join(FOLDERS[property]))
		config.translation_file = root.path_join("translations").path_join("story.csv")
		config.game_title = settings["game_title"]
		config.source_language = settings["source_language"]
		config.languages = PackedStringArray(settings["languages"])
		if settings["sample_tale"]:
			config.start_tale = SAMPLE_TALE
		_save_resource(config, result["config_path"], result)

	if settings["sample_tale"]:
		result["tale_path"] = root.path_join("tales").path_join(SAMPLE_TALE + ".tale")
		_write_text(result["tale_path"], sample_tale(result["tale_path"]), result)

	if settings["starter_scene"]:
		result["scene_path"] = settings["scene_path"]
		var script_path: String = settings["scene_path"].get_basename() + ".gd"
		_write_text(script_path, STARTER_SCRIPT, result)
		if FileAccess.file_exists(result["scene_path"]):
			result["kept"].append(result["scene_path"])
		elif result["errors"].is_empty():
			var node := Node.new()
			node.name = result["scene_path"].get_file().get_basename().to_pascal_case()
			node.set_script(load(script_path))
			var scene := PackedScene.new()
			scene.pack(node)
			node.free()
			_save_resource(scene, result["scene_path"], result)
	return result


## Points the project at [param config_path], and makes [param scene_path]
## the main scene when the project has none. Saves the project settings.
static func register(config_path: String, scene_path := "") -> void:
	ProjectSettings.set_setting("storyteller/config_path", config_path)
	if not scene_path.is_empty() and str(ProjectSettings.get_setting("application/run/main_scene", "")).is_empty():
		ProjectSettings.set_setting("application/run/main_scene", scene_path)
	ProjectSettings.save()


## True when the project's configured [StoryConfig] file does not exist.
static func needs_setup() -> bool:
	var path: String = ProjectSettings.get_setting("storyteller/config_path", StoryConfig.DEFAULT_PATH)
	return not ResourceLoader.exists(path)


## The first tale the wizard writes, mentioning where it lives.
static func sample_tale(path: String) -> String:
	return SAMPLE_TEXT % path


const STARTER_SCRIPT := """extends Node
## Opens the StoryTeller title screen. Made by the StoryTeller setup wizard;
## New Game plays the tale named in the StoryConfig's start_tale.


func _ready() -> void:
	Story.show_title()
"""

const SAMPLE_TEXT := """## Your first tale. Edit it in the Story tab (Text or Cards), or replace it.
@title("Chapter 1")

var courage := 0

@heading("The beginning")
beat start:
	"A new story starts here."
	"Each line of a tale appears on screen in turn. Click or press Space to go on."
	choose:
		"Step forward":
			courage += 1
			jump onward
		"Wait and listen":
			jump onward

@heading("Onward")
beat onward:
	if courage > 0:
		"You stepped forward."
	else:
		"You waited, and listened."
	"This tale is %s. Open it in the Story tab to keep writing."
"""


static func _make_folder(path: String, result: Dictionary) -> void:
	if DirAccess.dir_exists_absolute(path):
		return
	var error := DirAccess.make_dir_recursive_absolute(path)
	if error == OK:
		result["created"].append(path)
	else:
		result["errors"].append("Can't make the folder %s (%s)." % [path, error_string(error)])


static func _write_text(path: String, text: String, result: Dictionary) -> void:
	if FileAccess.file_exists(path):
		result["kept"].append(path)
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		result["errors"].append("Can't write %s." % path)
		return
	file.store_string(text)
	file.close()
	result["created"].append(path)


static func _save_resource(resource: Resource, path: String, result: Dictionary) -> void:
	var error := ResourceSaver.save(resource, path)
	if error == OK:
		result["created"].append(path)
	else:
		result["errors"].append("Can't save %s (%s)." % [path, error_string(error)])

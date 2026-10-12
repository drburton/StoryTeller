@tool
class_name StudioStoryImport
extends RefCounted
## Adds a story file from Visual Novel StoryTeller Studio to this project
## (decision 0022): the Story tab's [b]Open a Studio story[/b]. A student
## shares a story file with a teacher or parent, who opens it here, reads
## it, and decides whether to export it as a game.
## [codeblock]
## var result := StudioStoryImport.open("C:/Downloads/space_trip.zip")
## result["folder"]       # res://studio_stories/space_trip
## result["scene_path"]   # its main.tscn: open it and press F6 to play
## [/codeblock]
## The story gets a folder of its own, like the Where's Biscuit example:
## its tale, pictures, and sounds as they were in the file (see
## [StoryFile]), a story_config.tres pointing at them, and a main.tscn
## that plays it with a [StoryLauncher]. Nothing already in the project is
## changed; a second copy of a story gets a folder of its own.

## Where stories are added, unless another folder is given.
const DEFAULT_PARENT := "res://studio_stories"


## Adds the story file at [param zip_path] in a new folder under
## [param parent]. Returns [code]{"error", "title", "folder", "tale_path",
## "config_path", "scene_path"}[/code]; [code]error[/code] is empty when it
## worked. Run a file system scan afterwards so Godot imports the new files.
static func open(zip_path: String, parent := DEFAULT_PARENT) -> Dictionary:
	var result := {"error": "", "title": "", "folder": "", "tale_path": "", "config_path": "", "scene_path": ""}
	var file := StoryFile.read(zip_path)
	if not file["error"].is_empty():
		result["error"] = file["error"]
		return result
	var old_id: String = file["tale_name"]
	var base := old_id if StoryFile.make_name(old_id) == old_id and not old_id.is_empty() else StoryFile.make_name(file["title"])
	if base.is_empty():
		base = "story"
	var id := base
	var n := 2
	parent = parent.trim_suffix("/")
	while DirAccess.dir_exists_absolute(parent.path_join(id)):
		id = "%s_%d" % [base, n]
		n += 1
	var folder := parent.path_join(id)
	result["title"] = file["title"]
	result["folder"] = folder
	result["tale_path"] = folder.path_join("tales").path_join(id + ".tale")
	result["config_path"] = folder.path_join("story_config.tres")
	result["scene_path"] = folder.path_join("main.tscn")
	DirAccess.make_dir_recursive_absolute(folder.path_join("tales"))
	var tale := FileAccess.open(result["tale_path"], FileAccess.WRITE)
	if tale == null:
		result["error"] = "Can't write %s (%s)." % [result["tale_path"], error_string(FileAccess.get_open_error())]
		return result
	tale.store_string(StoryFile.renamed(file["text"], old_id, id))
	tale.close()
	StoryFile.write_assets(file["assets"], folder)

	var config := make_config(folder, id, file["title"])
	var error := ResourceSaver.save(config, result["config_path"])
	if error != OK:
		result["error"] = "Can't save %s (%s)." % [result["config_path"], error_string(error)]
		return result
	var launcher := StoryLauncher.new()
	launcher.name = id.to_pascal_case()
	# The saved config, so the scene points at its file.
	launcher.config = ResourceLoader.load(result["config_path"], "", ResourceLoader.CACHE_MODE_REPLACE) as StoryConfig
	var scene := PackedScene.new()
	scene.pack(launcher)
	launcher.free()
	error = ResourceSaver.save(scene, result["scene_path"])
	if error != OK:
		result["error"] = "Can't save %s (%s)." % [result["scene_path"], error_string(error)]
	return result


## A [StoryConfig] for a Studio story in [param folder] whose tale is
## [param id]: the story's own folders, title, saves, and settings.
static func make_config(folder: String, id: String, title: String) -> StoryConfig:
	var config := StoryConfig.new()
	config.tales_folder = folder.path_join("tales")
	config.backdrop_folder = folder.path_join("backdrops")
	config.cg_folder = folder.path_join("cgs")
	config.cast_folder = folder.path_join("cast")
	config.audio_folder = folder.path_join("audio")
	config.prop_folder = folder.path_join("props")
	config.start_tale = id
	config.game_title = title
	config.save_folder = "user://%s_saves" % id
	config.settings_path = "user://%s_settings.cfg" % id
	return config

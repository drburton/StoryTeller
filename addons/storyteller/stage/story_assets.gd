class_name StoryAssets
extends RefCounted
## Finds story assets by name using folder conventions, e.g. the backdrop
## "classroom" is res://story/backdrops/classroom.png (or .webp, .jpg, ...).

const IMAGE_EXTENSIONS: Array[String] = ["png", "webp", "jpg", "jpeg", "svg", "tres"]
const AUDIO_EXTENSIONS: Array[String] = ["ogg", "mp3", "wav", "tres"]
const SCENE_EXTENSIONS: Array[String] = ["tscn", "scn"]


## Path of the first existing "<folder>/<name>.<extension>", or "".
## A name that is already a resource path is returned as is when it exists.
static func find(folder: String, asset_name: String, extensions: Array[String]) -> String:
	if asset_name.begins_with("res://") or asset_name.begins_with("user://"):
		return asset_name if ResourceLoader.exists(asset_name) else ""
	for extension in extensions:
		var path := folder.path_join("%s.%s" % [asset_name, extension])
		if ResourceLoader.exists(path):
			return path
	return ""


## Loads [param asset_name] from [param folder], or returns null.
static func load_asset(folder: String, asset_name: String, extensions: Array[String]) -> Resource:
	var path := find(folder, asset_name, extensions)
	return load(path) if not path.is_empty() else null


## Starts loading [param path] in the background so it is ready when needed.
static func preload_path(path: String) -> void:
	if not path.is_empty() and not ResourceLoader.has_cached(path):
		ResourceLoader.load_threaded_request(path)

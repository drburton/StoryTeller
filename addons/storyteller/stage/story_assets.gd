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


## Names of the assets in [param folder] with one of [param extensions],
## sorted. Works in exported games, whose folders hold .import and .remap
## files.
static func list_names(folder: String, extensions: Array) -> PackedStringArray:
	var names := PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder):
		return names
	for file_name in ResourceLoader.list_directory(folder):
		if file_name.get_extension().to_lower() in extensions and file_name.get_basename() not in names:
			names.append(file_name.get_basename())
	names.sort()
	return names


## CGs in [param folder] and their variants: an image "<name>.png" is a CG
## with one variant, "", and a folder "<name>/" is a CG whose images are its
## variants. Returns {name: PackedStringArray of variants}.
static func scan_cgs(folder: String) -> Dictionary:
	var cgs := {}
	if not DirAccess.dir_exists_absolute(folder):
		return cgs
	for cg_name in list_names(folder, IMAGE_EXTENSIONS):
		cgs[cg_name] = PackedStringArray([""])
	for entry in ResourceLoader.list_directory(folder):
		var cg_name := entry.trim_suffix("/")
		if entry.ends_with("/") and not cg_name.begins_with(".") and not cgs.has(cg_name):
			var variants := list_names(folder.path_join(cg_name), IMAGE_EXTENSIONS)
			if not variants.is_empty():
				cgs[cg_name] = variants
	return cgs


## Path of a CG picture: "<folder>/<name>.png" for the variant "", or
## "<folder>/<name>/<variant>.png". Empty when it does not exist.
static func find_cg(folder: String, cg_name: String, variant: String) -> String:
	if variant.is_empty():
		return find(folder, cg_name, IMAGE_EXTENSIONS)
	return find(folder.path_join(cg_name), variant, IMAGE_EXTENSIONS)


## The variant shown when a tale names none: "default" when there is one,
## otherwise the first in name order.
static func default_cg_variant(variants: PackedStringArray) -> String:
	if variants.is_empty():
		return ""
	return "default" if "default" in variants else variants[0]


## Starts loading [param path] in the background so it is ready when needed.
static func preload_path(path: String) -> void:
	if not path.is_empty() and not ResourceLoader.has_cached(path):
		ResourceLoader.load_threaded_request(path)

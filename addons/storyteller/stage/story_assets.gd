class_name StoryAssets
extends RefCounted
## Finds story assets by name using folder conventions, e.g. the backdrop
## "classroom" is res://story/backdrops/classroom.png (or .webp, .jpg, ...).

const IMAGE_EXTENSIONS: Array[String] = ["png", "webp", "jpg", "jpeg", "svg", "tres"]
const AUDIO_EXTENSIONS: Array[String] = ["ogg", "mp3", "wav", "tres"]
const SCENE_EXTENSIONS: Array[String] = ["tscn", "scn"]
## Pictures and sounds read straight from their files when they were never
## imported, such as those a game or the Studio saves in user://, or files
## kept as they are on import.
const RAW_IMAGE_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]
const RAW_AUDIO_EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]

## Raw files already read: path to [signature, resource], where the
## signature is the file's modified time and size.
static var _raw_cache := {}


## Path of the first existing "<folder>/<name>.<extension>", or "".
## A name that is already a resource path is returned as is when it exists.
static func find(folder: String, asset_name: String, extensions: Array[String]) -> String:
	if asset_name.begins_with("res://") or asset_name.begins_with("user://"):
		return asset_name if exists(asset_name) else ""
	for extension in extensions:
		var path := folder.path_join("%s.%s" % [asset_name, extension])
		if exists(path):
			return path
	return ""


## True when [param path] is an imported resource, or a picture or sound
## file that can be read as it is (see [constant RAW_IMAGE_EXTENSIONS]).
static func exists(path: String) -> bool:
	return is_raw(path) or ResourceLoader.exists(path)


## True when [param path] is a picture or sound file read straight from
## disk, not an imported resource. Imported files have a ".import" file
## beside them, in the editor and in exported games; ResourceLoader can't
## tell them apart, since an exported game reports raw files as resources.
static func is_raw(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return (extension in RAW_IMAGE_EXTENSIONS or extension in RAW_AUDIO_EXTENSIONS) \
		and not FileAccess.file_exists(path + ".import") and FileAccess.file_exists(path)


## Loads [param asset_name] from [param folder], or returns null.
static func load_asset(folder: String, asset_name: String, extensions: Array[String]) -> Resource:
	return load_path(find(folder, asset_name, extensions))


## Loads the resource at [param path]: an imported resource, or a raw
## picture (as a texture) or sound. A raw file is read again when its
## modified time or size changes. Null when there is nothing there.
static func load_path(path: String) -> Resource:
	if path.is_empty():
		return null
	if not is_raw(path):
		return load(path) if ResourceLoader.exists(path) else null
	var signature := _signature(path)
	var cached: Array = _raw_cache.get(path, [])
	if not cached.is_empty() and cached[0] == signature:
		return cached[1]
	var resource := _load_raw(path)
	_raw_cache[path] = [signature, resource]
	return resource


## Drops the raw file at [param path] from the cache, for a program that has
## just replaced it.
static func forget_raw(path: String) -> void:
	_raw_cache.erase(path)


## The modified time and size of a raw file. Modified times count whole
## seconds, so the size catches a file replaced within the same second.
static func _signature(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	var size := file.get_length() if file != null else -1
	return "%d:%d" % [FileAccess.get_modified_time(path), size]


static func _load_raw(path: String) -> Resource:
	var extension := path.get_extension().to_lower()
	if extension in RAW_IMAGE_EXTENSIONS:
		var image := Image.load_from_file(path)
		return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
	match extension:
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
	return null


## Entries of [param folder] as [method ResourceLoader.list_directory]
## gives them (imported files, and folders ending in "/"), plus raw pictures
## and sounds that were never imported.
static func list_directory(folder: String) -> PackedStringArray:
	var entries := ResourceLoader.list_directory(folder)
	var dir := DirAccess.open(folder)
	if dir == null:
		return entries
	for file_name in dir.get_files():
		var extension := file_name.get_extension().to_lower()
		if (extension in RAW_IMAGE_EXTENSIONS or extension in RAW_AUDIO_EXTENSIONS) and file_name not in entries:
			entries.append(file_name)
	return entries


## Names of the assets in [param folder] with one of [param extensions],
## sorted. Works in exported games, whose folders hold .import and .remap
## files.
static func list_names(folder: String, extensions: Array) -> PackedStringArray:
	var names := PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder):
		return names
	for file_name in list_directory(folder):
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
	for entry in list_directory(folder):
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
	if not path.is_empty() and ResourceLoader.exists(path) and not ResourceLoader.has_cached(path):
		ResourceLoader.load_threaded_request(path)

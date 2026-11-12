class_name StoryAssets
extends RefCounted
## Finds story assets by name using folder conventions, e.g. the backdrop
## "classroom" is res://story/backdrops/classroom.png (or .webp, .jpg, ...).
##
## Any asset folder can hold a folder per language with versions of its
## files, for pictures with text and voice recorded in other languages
## (decision 0031): res://story/backdrops/es/classroom.png is shown while
## the game is in Spanish. A file a language folder lacks comes from the
## main folder. A language folder is named with the code of a language the
## game has (see [method is_language_folder]), such as "es" or "pt_BR", and
## is not a CG or cast member.

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
## The language the tales are written in. [code]Story[/code] sets it from
## [member StoryConfig.source_language]. Language folders are not searched
## while the game is in this language.
static var source_language := "en"
## The languages a story has: its source language and
## [member StoryConfig.languages]. [code]Story[/code] sets them.
static var languages := PackedStringArray()
## Paths passed to [method ResourceLoader.load_threaded_request] whose
## result has not been collected yet. Godot keeps each request until
## [method ResourceLoader.load_threaded_get] collects it, and reports the
## ones still waiting as leaked objects when the game quits.
static var _requested := {}


## Path of the first existing "<folder>/<name>.<extension>", or "".
## A name that is already a resource path is returned as is when it exists.
static func find(folder: String, asset_name: String, extensions: Array[String]) -> String:
	if asset_name.begins_with("res://") or asset_name.begins_with("user://"):
		return asset_name if exists(asset_name) else ""
	for language in language_folders():
		var localized := _find_in(folder.path_join(language), asset_name, extensions)
		if not localized.is_empty():
			return localized
	return _find_in(folder, asset_name, extensions)


## The language folders searched before the main folder, most specific
## first: the locale ("es_MX") and its language ("es"). None while the game
## is in [member source_language].
static func language_folders() -> PackedStringArray:
	var locale := TranslationServer.get_locale()
	var language := locale.get_slice("_", 0)
	if locale.is_empty() or language == source_language.get_slice("_", 0):
		return PackedStringArray()
	var folders := PackedStringArray()
	if locale != language:
		folders.append(locale)
	folders.append(language)
	return folders


## True when [param name] is the code of a language the game has: one with
## a translation loaded, the source language, or one of [member languages].
## Such a folder holds versions of assets for that language, not a CG or a
## cast member, so a character can still be called "leo".
static func is_language_folder(name: String) -> bool:
	if name.is_empty():
		return false
	if name == source_language or name in languages:
		return true
	for locale in TranslationServer.get_loaded_locales():
		if name == locale or name == locale.get_slice("_", 0):
			return true
	return false


## The version of [param resource] for the game's language: a file named
## "<name>.<language>.<ext>" next to it, such as title.es.png for
## title.png, or [param resource] itself. For pictures set directly in the
## config, such as [member StoryConfig.title_background].
static func localized_resource(resource: Resource) -> Resource:
	if resource == null or resource.resource_path.is_empty():
		return resource
	var path := resource.resource_path
	for language in language_folders():
		var candidate := "%s.%s.%s" % [path.get_basename(), language, path.get_extension()]
		if exists(candidate):
			return load_path(candidate)
	return resource


static func _find_in(folder: String, asset_name: String, extensions: Array[String]) -> String:
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
		if _requested.has(path):
			_requested.erase(path)
			return ResourceLoader.load_threaded_get(path)
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
		if entry.ends_with("/") and not cg_name.begins_with(".") and not cgs.has(cg_name) and not is_language_folder(cg_name):
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
	if path.is_empty() or _requested.has(path) or not ResourceLoader.exists(path) or ResourceLoader.has_cached(path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_requested[path] = true


## Collects every background load [method preload_path] started that was
## never used, waiting for those still loading, so Godot can let them go.
## The [code]Story[/code] autoload calls this when it shuts down.
static func finish_preloads() -> void:
	for path in _requested.keys():
		ResourceLoader.load_threaded_get(path)
	_requested.clear()


## Number of background loads waiting to be collected, for tests.
static func pending_preloads() -> int:
	return _requested.size()

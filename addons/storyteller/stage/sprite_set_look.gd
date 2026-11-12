@tool
class_name SpriteSetLook
extends CastLook
## One texture per mood. Textures come from [member moods], or from image
## files named after moods in [member folder] (e.g. smile.png, sad.webp).
## A language folder in it (e.g. es/smile.png) has versions for that
## language, for faces with text (decision 0031).

const IMAGE_EXTENSIONS: Array[String] = ["png", "webp", "jpg", "jpeg", "svg"]

## Mood name to texture.
@export var moods: Dictionary[String, Texture2D] = {}
## Folder scanned for "<mood>.<ext>" images not listed in [member moods].
@export_dir var folder := ""

## Textures read from [member folder], by path.
var _loaded: Dictionary = {}


func create_visual() -> Node2D:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	return sprite


func apply_mood(visual: Node2D, mood: String) -> bool:
	var texture := get_texture(mood)
	if texture == null:
		return false
	var sprite := visual as Sprite2D
	sprite.texture = texture
	sprite.offset = Vector2(0, -texture.get_height() / 2.0)
	return true


func get_texture(mood: String) -> Texture2D:
	if moods.has(mood):
		return moods[mood]
	if folder.is_empty():
		return null
	var path := StoryAssets.find(folder, mood, IMAGE_EXTENSIONS)
	if path.is_empty():
		return null
	if _loaded.has(path):
		return _loaded[path]
	var texture := StoryAssets.load_path(path) as Texture2D
	# Raw pictures are read again when they change, so they are not kept.
	if not StoryAssets.is_raw(path):
		_loaded[path] = texture
	return texture


func get_preview(mood: String) -> Texture2D:
	return get_texture(mood)


func get_moods() -> PackedStringArray:
	var names := PackedStringArray(moods.keys())
	if not folder.is_empty() and DirAccess.dir_exists_absolute(folder):
		# list_directory sees imported files in exported games, where the
		# folder only holds .import files.
		for file_name in StoryAssets.list_directory(folder):
			var extension := file_name.get_extension().to_lower()
			var mood := file_name.get_basename()
			# "<mood>_talk" images are mouth frames for lip-flap, not moods.
			if extension in IMAGE_EXTENSIONS and mood not in names and not mood.ends_with("_talk"):
				names.append(mood)
	names.sort()
	return names

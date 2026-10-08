@tool
class_name SpriteSetLook
extends CastLook
## One texture per mood. Textures come from [member moods], or from image
## files named after moods in [member folder] (e.g. smile.png, sad.webp).

const IMAGE_EXTENSIONS: Array[String] = ["png", "webp", "jpg", "jpeg", "svg"]

## Mood name to texture.
@export var moods: Dictionary[String, Texture2D] = {}
## Folder scanned for "<mood>.<ext>" images not listed in [member moods].
@export_dir var folder := ""


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
	for extension in IMAGE_EXTENSIONS:
		var path := folder.path_join("%s.%s" % [mood, extension])
		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			moods[mood] = texture
			return texture
	return null


func get_moods() -> PackedStringArray:
	var names := PackedStringArray(moods.keys())
	if not folder.is_empty():
		for file_name in DirAccess.get_files_at(folder):
			var extension := file_name.get_extension().to_lower()
			var mood := file_name.get_basename()
			if extension in IMAGE_EXTENSIONS and mood not in names:
				names.append(mood)
	names.sort()
	return names

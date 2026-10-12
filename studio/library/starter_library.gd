class_name StudioStarter
extends RefCounted
## The Studio's starter library (docs/studio-design.md §6): characters,
## backgrounds, music, and sounds a student can use at once. For now it
## gathers the art and sounds of the Where's Biscuit example and the
## plugin's demo.
##
## A story gets its own copy of each item it uses, as plain pictures and
## sounds in its folder (decisions 0022 and 0023), so a story file carries
## everything it needs.

const BACKDROPS := {
	"living_room": "res://examples/wheres_biscuit/backdrops/living_room.png",
	"backyard": "res://examples/wheres_biscuit/backdrops/backyard.png",
	"classroom": "res://demo/story/backdrops/classroom_morning.png",
	"library": "res://demo/story/backdrops/library.png",
	"library_at_night": "res://demo/story/backdrops/library_night.png",
	"riverside": "res://demo/story/backdrops/riverside_evening.png",
}
const CHARACTERS := {
	"theo": "res://examples/wheres_biscuit/cast/theo.tres",
	"leo": "res://examples/wheres_biscuit/cast/leo.tres",
	"cleo": "res://examples/wheres_biscuit/cast/cleo.tres",
	"biscuit": "res://examples/wheres_biscuit/cast/biscuit.tres",
	"ada": "res://demo/story/cast/ada.tres",
	"mira": "res://demo/story/cast/mira.tres",
}
const MUSIC := {
	"quiet_morning": "res://demo/story/audio/music/quiet_morning.wav",
	"library_theme": "res://demo/story/audio/music/library_theme.wav",
}
const SOUNDS := {
	"chime": "res://demo/story/audio/sounds/chime.wav",
	"page_turn": "res://demo/story/audio/sounds/page_turn.wav",
	"rain": "res://demo/story/audio/ambience/rain.wav",
}
## Each kind of item: its list, and where a story keeps its copies.
const KINDS := {
	"backdrops": {"items": BACKDROPS, "folder": "backdrops"},
	"cast": {"items": CHARACTERS, "folder": "cast"},
	"music": {"items": MUSIC, "folder": "audio/music"},
	"sounds": {"items": SOUNDS, "folder": "audio/sounds"},
}


## Names of the starter items of [param kind] ("backdrops", "cast",
## "music", or "sounds"), in library order.
static func names(kind: String) -> PackedStringArray:
	return PackedStringArray(KINDS[kind]["items"].keys())


static func has(kind: String, item: String) -> bool:
	return KINDS.has(kind) and KINDS[kind]["items"].has(item)


## The starter character [param id]'s profile.
static func profile(id: String) -> CastProfile:
	return load(CHARACTERS[id]) as CastProfile if CHARACTERS.has(id) else null


## A picture of a starter background, or of a starter character with
## [param mood] (its usual face when empty).
static func picture(kind: String, item: String, mood := "") -> Texture2D:
	if kind == "backdrops" and BACKDROPS.has(item):
		return load(BACKDROPS[item]) as Texture2D
	var character := profile(item) if kind == "cast" else null
	if character == null or character.look == null:
		return null
	return character.look.get_preview(mood if not mood.is_empty() else character.default_mood)


## Copies the starter item [param item] of [param kind] into the story
## folder [param story_folder], as plain pictures and sounds. Returns false
## when there is no such item or it could not be copied.
static func copy_into(kind: String, item: String, story_folder: String) -> bool:
	if not has(kind, item):
		return false
	var folder := story_folder.path_join(KINDS[kind]["folder"])
	DirAccess.make_dir_recursive_absolute(folder)
	match kind:
		"backdrops":
			return _save_picture(load(BACKDROPS[item]) as Texture2D, folder.path_join(item + ".png"))
		"cast":
			return _copy_character(item, folder.path_join(item))
		_:
			var stream := load(KINDS[kind]["items"][item]) as AudioStreamWAV
			return stream != null and stream.save_to_wav(folder.path_join(item + ".wav")) == OK
	return false


static func _copy_character(id: String, folder: String) -> bool:
	var character := profile(id)
	if character == null or not character.look is SpriteSetLook:
		return false
	DirAccess.make_dir_recursive_absolute(folder)
	var look := character.look as SpriteSetLook
	var copied := false
	for mood in look.get_moods():
		copied = _save_picture(look.get_texture(mood), folder.path_join(mood + ".png")) or copied
		var talk := look.get_texture(mood + "_talk")
		if talk != null:
			_save_picture(talk, folder.path_join(mood + "_talk.png"))
	var details := {"display_name": character.get_display_name(), "name_color": "#" + character.name_color.to_html(false),
		"default_mood": character.default_mood}
	var file := FileAccess.open(folder.path_join("profile.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(details, "\t"))
	return copied


static func _save_picture(texture: Texture2D, path: String) -> bool:
	var image := texture.get_image() if texture != null else null
	if image == null:
		return false
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	var saved := image.save_png(path) == OK
	StoryAssets.forget_raw(path)
	return saved

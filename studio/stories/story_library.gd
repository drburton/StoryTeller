class_name StudioLibrary
extends RefCounted
## The student's stories, kept in the app's own storage (Godot's
## [code]user://[/code], docs/studio-design.md §8). Each story is a folder
## named by its id:
## [codeblock]
## story.json            its title, and when it was made, changed, opened, and shared
## tales/<id>.tale       its TaleScript, which the blocks edit
## backdrops/<name>.png  its backgrounds (also .jpg and .webp)
## cgs/<name>.png        its big pictures
## cast/<name>/<face>.png  its characters, one picture per face, with an
##                       optional profile.json (display name and name color)
## audio/music/<name>.ogg  its music (also .wav and .mp3)
## audio/sounds/<name>.ogg its sounds
## saves/                saved games from playing it, never shared
## [/codeblock]
## Pictures and sounds are plain files (decision 0023), copied in from the
## starter library ([StudioStarter]) when the story uses one, or added by the
## student. The id is also the tale's name, so it never changes; renaming a
## story changes only its title. [method pack] puts a story into one .zip
## file to share, and [method unpack] adds a story from one.

const ROOT := "user://stories"
const SAMPLE_TALE := "res://examples/wheres_biscuit/tales/wheres_biscuit.tale"
## The sample's text in an exported app, which holds only the imported tale
## (tools/build_studio.sh copies it in).
const SAMPLE_COPY := "res://studio/samples/wheres_biscuit.tale.txt"
const SAMPLE_ID := "wheres_biscuit"
const SAMPLE_TITLE := "Where's Biscuit?"
const BLANK_TALE := "beat start:\n\t\"Once upon a time...\"\n"
## Days a changed story can go unshared before the home screen reminds the
## student to share a copy.
const REMIND_DAYS := 7
## The largest tale a story file may hold, in bytes.
const MAX_TALE_BYTES := 1 << 20
## The largest picture or sound a story file may hold, and the most in all.
const MAX_ASSET_BYTES := 25 << 20
const MAX_FILE_BYTES := 250 << 20
## Pictures, sounds, and character profiles a story file may hold, by path.
const ASSET_PATTERN := "^(backdrops/\\w+\\.(png|jpe?g|webp)|cgs/\\w+(/\\w+)?\\.(png|jpe?g|webp)|cast/\\w+/(\\w+\\.(png|jpe?g|webp)|profile\\.json)|audio/(music|sounds)/\\w+\\.(ogg|wav|mp3))$"
## Where a story keeps each kind of picture and sound.
const ASSET_FOLDERS := {"backdrops": "backdrops", "cgs": "cgs", "cast": "cast", "music": "audio/music", "sounds": "audio/sounds"}
## Largest added backgrounds and big pictures, and faces, in pixels.
const MAX_PICTURE := Vector2i(1920, 1080)
const MAX_FACE := Vector2i(1024, 1024)

## The folder that holds the stories.
var root: String
## Why the last [method pack] or [method unpack] failed, in plain words.
var last_error := ""


func _init(folder := ROOT) -> void:
	root = folder


## Every story, most recently changed first. Each is its story.json with
## its [code]"id"[/code].
func list() -> Array[Dictionary]:
	var stories: Array[Dictionary] = []
	for id in DirAccess.get_directories_at(root):
		var story := get_story(id)
		if not story.is_empty():
			stories.append(story)
	stories.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["changed"] > b["changed"])
	return stories


## The story [param id]'s details, or an empty dictionary when there is none.
func get_story(id: String) -> Dictionary:
	var path := root.path_join(id).path_join("story.json")
	if not FileAccess.file_exists(path) or not FileAccess.file_exists(tale_path(id)):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return {}
	var story := {"title": id, "created": 0.0, "changed": 0.0, "opened": 0.0, "shared": 0.0}
	story.merge(data, true)
	story["id"] = id
	return story


func tale_path(id: String) -> String:
	return root.path_join(id).path_join("tales").path_join(id + ".tale")


func read_tale(id: String) -> String:
	return FileAccess.get_file_as_string(tale_path(id))


## Saves the story's text and notes the change.
func save_tale(id: String, text: String) -> void:
	_write(tale_path(id), text)
	_update(id, {"changed": _now()})


## Makes a new story called [param title] holding [param text]. Returns its
## id, made from the title. When the text is a copy of the story
## [param copied_id], its "has been to" tests are pointed at the new story.
func create(title: String, text := BLANK_TALE, copied_id := "") -> String:
	var id := new_id(title)
	var now := _now()
	_write(tale_path(id), _renamed(text, copied_id, id))
	_write_story(id, {"title": title.strip_edges(), "created": now, "changed": now, "opened": 0.0, "shared": 0.0})
	return id


## Adds the Where's Biscuit sample the first time the Studio starts, and
## adopts a copy the first Studio build saved without its story.json.
func add_sample() -> void:
	var marker := root.path_join(".sample_added")
	if FileAccess.file_exists(marker):
		return
	var first_copy := root.path_join(SAMPLE_ID).path_join(SAMPLE_ID + ".tale")
	if FileAccess.file_exists(first_copy) and FileAccess.get_file_as_string(first_copy).strip_edges().is_empty():
		# That build could save an empty copy when it ran exported.
		DirAccess.remove_absolute(first_copy)
	if FileAccess.file_exists(first_copy) and not FileAccess.file_exists(tale_path(SAMPLE_ID)):
		DirAccess.make_dir_recursive_absolute(tale_path(SAMPLE_ID).get_base_dir())
		DirAccess.rename_absolute(first_copy, tale_path(SAMPLE_ID))
	if FileAccess.file_exists(tale_path(SAMPLE_ID)) and get_story(SAMPLE_ID).is_empty():
		var now := _now()
		_write_story(SAMPLE_ID, {"title": SAMPLE_TITLE, "created": now, "changed": now, "opened": 0.0, "shared": 0.0})
	elif get_story(SAMPLE_ID).is_empty():
		var id := create(SAMPLE_TITLE, sample_text())
		if id != SAMPLE_ID:
			push_warning("Studio: the sample story got the id '%s'." % id)
	_write(marker, "")


## The text of the Where's Biscuit sample.
static func sample_text() -> String:
	var text := FileAccess.get_file_as_string(SAMPLE_TALE) if FileAccess.file_exists(SAMPLE_TALE) else ""
	if text.is_empty() and FileAccess.file_exists(SAMPLE_COPY):
		text = FileAccess.get_file_as_string(SAMPLE_COPY)
	return text


func rename(id: String, title: String) -> void:
	if not title.strip_edges().is_empty():
		_update(id, {"title": title.strip_edges()})


func mark_opened(id: String) -> void:
	_update(id, {"opened": _now()})


func mark_shared(id: String) -> void:
	_update(id, {"shared": _now()})


## Removes the story and everything in its folder.
func delete(id: String) -> void:
	_remove_folder(root.path_join(id))


## True when [param story] has changed since it was last shared, and it has
## gone [constant REMIND_DAYS] days without sharing.
static func needs_reminder(story: Dictionary, now := -1.0) -> bool:
	if now < 0.0:
		now = _now()
	var since: float = maxf(story.get("shared", 0.0), story.get("created", 0.0))
	return story.get("changed", 0.0) > story.get("shared", 0.0) and now - since > REMIND_DAYS * 86400.0


## An unused id for a story called [param title]: "My Story" is "my_story",
## then "my_story_2".
func new_id(title: String) -> String:
	var base := StudioBlockEditor.make_name(title)
	if base.is_empty():
		base = "story"
	var id := base
	var n := 2
	while _is_taken(id):
		id = "%s_%d" % [base, n]
		n += 1
	return id


# --- Story files ----------------------------------------------------------

## Writes the story [param id] to a .zip at [param zip_path]: its
## story.json, its tale, and its pictures and sounds. Returns false and sets
## [member last_error] when it can't.
func pack(id: String, zip_path: String) -> bool:
	var story := get_story(id)
	if story.is_empty():
		last_error = "There is no story to share."
		return false
	var packer := ZIPPacker.new()
	if packer.open(zip_path) != OK:
		last_error = "The story file could not be made."
		return false
	var info := story.duplicate()
	info.erase("opened")
	_pack_file(packer, "story.json", JSON.stringify(info, "\t").to_utf8_buffer())
	_pack_file(packer, "tales/%s.tale" % id, read_tale(id).to_utf8_buffer())
	var pattern := RegEx.create_from_string(ASSET_PATTERN)
	for path in _files_under(folder(id), ""):
		if pattern.search(path) != null:
			_pack_file(packer, path, FileAccess.get_file_as_bytes(folder(id).path_join(path)))
	packer.close()
	return true


## Adds the story in the .zip at [param zip_path] as a new story and returns
## its id, or "" with [member last_error] set. Only the story's details, its
## tale, and pictures, sounds, and character profiles in their usual places
## are read from the file; anything else in it is left out.
func unpack(zip_path: String) -> String:
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		last_error = "That file is not a story file."
		return ""
	var files := reader.get_files()
	var tales := Array(files).filter(func(file: String) -> bool:
		return file.begins_with("tales/") and file.ends_with(".tale") and file.count("/") == 1)
	if not files.has("story.json") or tales.size() != 1:
		reader.close()
		last_error = "That file is not a story from the Studio."
		return ""
	var info = JSON.parse_string(reader.read_file("story.json").get_string_from_utf8())
	var bytes := reader.read_file(tales[0])
	if not info is Dictionary or bytes.size() > MAX_TALE_BYTES:
		reader.close()
		last_error = "That story file is damaged."
		return ""
	var pattern := RegEx.create_from_string(ASSET_PATTERN)
	var assets := {}
	var total := bytes.size()
	for file in files:
		if pattern.search(file) == null:
			continue
		var data := reader.read_file(file)
		total += data.size()
		if data.size() > MAX_ASSET_BYTES or total > MAX_FILE_BYTES:
			reader.close()
			last_error = "That story file is too big."
			return ""
		assets[file] = data
	reader.close()
	var old_id: String = tales[0].get_file().get_basename()
	var title := str(info.get("title", old_id))
	var text := bytes.get_string_from_utf8()
	var id := new_id(old_id if old_id.is_valid_identifier() else title)
	var now := _now()
	_write(tale_path(id), _renamed(text, old_id, id))
	for file in assets:
		var path := folder(id).path_join(file)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var out := FileAccess.open(path, FileAccess.WRITE)
		if out != null:
			out.store_buffer(assets[file])
	_write_story(id, {"title": title, "created": float(info.get("created", now)), "changed": now, "opened": 0.0, "shared": now})
	return id


static func _pack_file(packer: ZIPPacker, path: String, data: PackedByteArray) -> void:
	packer.start_file(path)
	packer.write_file(data)
	packer.close_file()


## Paths of the files under [param base]/[param sub], relative to [param base].
static func _files_under(base: String, sub: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(base.path_join(sub))
	if dir == null:
		return found
	for file_name in dir.get_files():
		found.append(sub.path_join(file_name) if not sub.is_empty() else file_name)
	for child in dir.get_directories():
		found.append_array(_files_under(base, sub.path_join(child) if not sub.is_empty() else child))
	return found


# --- Pictures and sounds --------------------------------------------------

## The story's folder.
func folder(id: String) -> String:
	return root.path_join(id)


## Where the story [param id] keeps pictures or sounds of [param kind]
## ("backdrops", "cgs", "cast", "music", or "sounds").
func asset_folder(id: String, kind: String) -> String:
	return folder(id).path_join(ASSET_FOLDERS[kind])


## [param base] with its folders set to the story [param id]'s own, for
## playing, previewing, and checking it.
func story_config(id: String, base: StoryConfig) -> StoryConfig:
	var config := base.duplicate() as StoryConfig
	config.tales_folder = folder(id).path_join("tales")
	config.backdrop_folder = asset_folder(id, "backdrops")
	config.cg_folder = asset_folder(id, "cgs")
	config.cast_folder = asset_folder(id, "cast")
	config.audio_folder = folder(id).path_join("audio")
	config.prop_folder = folder(id).path_join("props")
	config.save_folder = folder(id).path_join("saves")
	config.start_tale = id
	config.game_title = get_story(id).get("title", id)
	return config


## Names of the story's own pictures or sounds of [param kind], sorted.
func asset_names(id: String, kind: String) -> PackedStringArray:
	if kind == "cast":
		var ids := Array(StoryStage.scan_cast(asset_folder(id, kind)).keys())
		ids.sort()
		return PackedStringArray(ids)
	var extensions := StoryAssets.RAW_AUDIO_EXTENSIONS if kind in ["music", "sounds"] else StoryAssets.RAW_IMAGE_EXTENSIONS
	return StoryAssets.list_names(asset_folder(id, kind), extensions)


func has_asset(id: String, kind: String, item: String) -> bool:
	return item in asset_names(id, kind)


## Copies in, from the starter library, each picture and sound the story's
## tale uses but doesn't have yet. Returns them as "kind/name".
func add_starter_items(id: String) -> PackedStringArray:
	var copied := PackedStringArray()
	var used := names_used(read_tale(id))
	for kind in used:
		var have := asset_names(id, kind)
		for item in used[kind]:
			if item not in have and StudioStarter.has(kind, item) and StudioStarter.copy_into(kind, item, folder(id)):
				copied.append("%s/%s" % [kind, item])
	return copied


## Adds the starter item [param item] of [param kind] to the story.
func add_starter_item(id: String, kind: String, item: String) -> bool:
	return has_asset(id, kind, item) or StudioStarter.copy_into(kind, item, folder(id))


## Adds [param image] as the story's background or big picture
## ([param kind] "backdrops" or "cgs") called [param name], scaled down
## when it is large. Returns the name it is saved under, or "".
func add_picture(id: String, kind: String, name: String, image: Image) -> String:
	var item := StudioBlockEditor.make_name(name)
	if item.is_empty() or image == null or image.is_empty():
		return ""
	return item if _save_image(asset_folder(id, kind).path_join(item), _fitted(image, MAX_PICTURE)) else ""


## Adds [param image] as the face [param face] of the character
## [param character], making the character when it is new. Returns the
## character's id, or "".
func add_face(id: String, character: String, face: String, image: Image) -> String:
	var character_id := StudioBlockEditor.make_name(character)
	var mood := StudioBlockEditor.make_name(face)
	if character_id.is_empty() or mood.is_empty() or image == null or image.is_empty():
		return ""
	var character_folder := asset_folder(id, "cast").path_join(character_id)
	var details_path := character_folder.path_join("profile.json")
	if not FileAccess.file_exists(details_path):
		_write(details_path, JSON.stringify({"display_name": character.strip_edges()}, "\t"))
	return character_id if _save_image(character_folder.path_join(mood), _fitted(image, MAX_FACE)) else ""


## Copies the sound file at [param source] into the story as music or a
## sound ([param kind] "music" or "sounds") called [param name]. Returns the
## name, or "" when it isn't a sound the Studio can play.
func add_sound(id: String, kind: String, name: String, source: String) -> String:
	var item := StudioBlockEditor.make_name(name)
	var bytes := FileAccess.get_file_as_bytes(source)
	if item.is_empty() or bytes.is_empty() or bytes.size() > MAX_ASSET_BYTES:
		return ""
	# A picked file may have no extension, so its first bytes tell its kind.
	var extension := StudioFiles.sound_kind(bytes)
	if extension.is_empty():
		return ""
	var target_folder := asset_folder(id, kind)
	_remove_variants(target_folder.path_join(item), StoryAssets.RAW_AUDIO_EXTENSIONS)
	var path := target_folder.path_join("%s.%s" % [item, extension])
	DirAccess.make_dir_recursive_absolute(target_folder)
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return ""
	out.store_buffer(bytes)
	out.close()
	StoryAssets.forget_raw(path)
	if StoryAssets.load_path(path) == null:
		DirAccess.remove_absolute(path)
		return ""
	return item


## Names each kind of picture and sound [param text] uses: backgrounds,
## big pictures, characters, music, and sounds, as
## [code]{"backdrops": [...], "cgs": [...], "cast": [...], "music": [...], "sounds": [...]}[/code].
static func names_used(text: String) -> Dictionary:
	var used := {"backdrops": [], "cgs": [], "cast": [], "music": [], "sounds": []}
	var calls := {"backdrop": "backdrops", "cg": "cgs", "music": "music", "sound": "sounds", "ambience": "sounds"}
	var pending: Array = TaleParser.parse(text).statements.duplicate()
	var exprs: Array = []
	while not pending.is_empty():
		var node: TaleNode = pending.pop_back()
		pending.append_array(node.body)
		if node.kind == TaleNode.Kind.DIALOGUE and not node.name.is_empty():
			_add_name(used["cast"], node.name)
		for expr in [node.expr, node.target, node.condition]:
			if expr != null:
				exprs.append(expr)
	while not exprs.is_empty():
		var expr: TaleExpr = exprs.pop_back()
		exprs.append_array(expr.operands)
		exprs.append_array(expr.args)
		exprs.append_array(expr.named_args.values())
		if expr.kind == TaleExpr.Kind.ATTRIBUTE and expr.operands[0].kind == TaleExpr.Kind.IDENTIFIER:
			_add_name(used["cast"], expr.operands[0].name)
		elif expr.kind == TaleExpr.Kind.CALL and expr.operands[0].kind == TaleExpr.Kind.IDENTIFIER \
				and calls.has(expr.operands[0].name) and not expr.args.is_empty() \
				and expr.args[0].kind == TaleExpr.Kind.LITERAL and expr.args[0].value is String:
			_add_name(used[calls[expr.operands[0].name]], expr.args[0].value)
	return used


static func _add_name(names: Array, item: String) -> void:
	if item not in names:
		names.append(item)


## [param image] scaled down to fit [param limit], keeping its shape.
static func _fitted(image: Image, limit: Vector2i) -> Image:
	var fitted := image.duplicate() as Image
	if fitted.is_compressed():
		fitted.decompress()
	var scale := minf(1.0, minf(float(limit.x) / fitted.get_width(), float(limit.y) / fitted.get_height()))
	if scale < 1.0:
		fitted.resize(maxi(1, roundi(fitted.get_width() * scale)), maxi(1, roundi(fitted.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	return fitted


## Saves [param image] at [param path] plus an extension: .png when it has
## see-through parts, otherwise .jpg, which keeps photos small. Other
## pictures with the same name are removed.
static func _save_image(path: String, image: Image) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_remove_variants(path, StoryAssets.RAW_IMAGE_EXTENSIONS)
	var see_through := image.detect_alpha() != Image.ALPHA_NONE
	var file := path + (".png" if see_through else ".jpg")
	var saved := (image.save_png(file) if see_through else image.save_jpg(file, 0.85)) == OK
	StoryAssets.forget_raw(file)
	return saved


static func _remove_variants(path: String, extensions: Array[String]) -> void:
	for extension in extensions:
		if FileAccess.file_exists("%s.%s" % [path, extension]):
			DirAccess.remove_absolute("%s.%s" % [path, extension])
			StoryAssets.forget_raw("%s.%s" % [path, extension])


# --- Files ----------------------------------------------------------------

## True when a folder for [param id] exists with anything in it. An empty
## folder left behind can be used again.
func _is_taken(id: String) -> bool:
	var dir := DirAccess.open(root.path_join(id))
	if dir == null:
		return false
	dir.include_hidden = true
	return not dir.get_files().is_empty() or not dir.get_directories().is_empty()


## [param text] with its "has been to" tests of the story [param old_id]
## pointed at [param new_id], since tests name the story.
static func _renamed(text: String, old_id: String, new_id: String) -> String:
	if old_id.is_empty() or old_id == new_id:
		return text
	return text.replace("visited(\"%s." % old_id, "visited(\"%s." % new_id)


static func _now() -> float:
	return Time.get_unix_time_from_system()


func _update(id: String, changes: Dictionary) -> void:
	var story := get_story(id)
	if story.is_empty():
		return
	story.merge(changes, true)
	story.erase("id")
	_write_story(id, story)


func _write_story(id: String, story: Dictionary) -> void:
	_write(root.path_join(id).path_join("story.json"), JSON.stringify(story, "\t"))


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


static func _remove_folder(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	dir.include_hidden = true
	for sub in dir.get_directories():
		_remove_folder(folder.path_join(sub))
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(folder)

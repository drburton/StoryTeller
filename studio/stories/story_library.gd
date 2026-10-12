class_name StudioLibrary
extends RefCounted
## The student's stories, kept in the app's own storage (Godot's
## [code]user://[/code], docs/studio-design.md §8). Each story is a folder
## named by its id:
## [codeblock]
## story.json          its title, and when it was made, changed, opened, and shared
## tales/<id>.tale     its TaleScript, which the blocks edit
## [/codeblock]
## The id is also the tale's name, so it never changes; renaming a story
## changes only its title. [method pack] puts a story into one .zip file to
## share, and [method unpack] adds a story from one.

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
## story.json and its tale. Returns false and sets [member last_error] when
## it can't.
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
	packer.start_file("story.json")
	packer.write_file(JSON.stringify(info, "\t").to_utf8_buffer())
	packer.close_file()
	packer.start_file("tales/%s.tale" % id)
	packer.write_file(read_tale(id).to_utf8_buffer())
	packer.close_file()
	packer.close()
	return true


## Adds the story in the .zip at [param zip_path] as a new story and returns
## its id, or "" with [member last_error] set. Only the story's details and
## its tale are read from the file.
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
	reader.close()
	if not info is Dictionary or bytes.size() > MAX_TALE_BYTES:
		last_error = "That story file is damaged."
		return ""
	var old_id: String = tales[0].get_file().get_basename()
	var title := str(info.get("title", old_id))
	var text := bytes.get_string_from_utf8()
	var id := new_id(old_id if old_id.is_valid_identifier() else title)
	var now := _now()
	_write(tale_path(id), _renamed(text, old_id, id))
	_write_story(id, {"title": title, "created": float(info.get("created", now)), "changed": now, "opened": 0.0, "shared": now})
	return id


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

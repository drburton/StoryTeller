class_name StorySaves
extends StoryCrew
## Crew member that saves and loads games.
##
## Each slot is a JSON file with the whole story state plus a PNG thumbnail.
## Data that outlives a playthrough (global variables, read lines) goes in a
## separate global file, saved automatically.
## [codeblock]
## var saves: StorySaves = Story.get_crew(&"Saves")
## saves.save_slot("1")
## saves.load_slot("1")
## [/codeblock]

signal saved(slot: String)
signal loaded(slot: String)

## Version of the slot file layout. Older files are upgraded with [member migrations].
const FORMAT := 1
const QUICK_SLOT := "quick"
const AUTO_SLOT := "auto"
const GLOBAL_FILE := "global.json"
## Seconds between automatic writes of the global file while it has changes.
const GLOBAL_SAVE_DELAY := 5.0

var folder := "user://saves"
var thumbnail_size := Vector2i(320, 180)
## Save to the "auto" slot before every choice.
var autosave_on_choice := true
## Minutes of play between saves to the "auto" slot, made when the next
## line shows. 0 turns timed autosaves off.
var autosave_minutes := 0.0
## Seconds played in the current game.
var playtime := 0.0
## Upgrades for older slot files: format number to a Callable that takes the
## file's dictionary and returns it in the next format.
var migrations: Dictionary = {}

var _thumbnail: Image
var _last_line := {"speaker": "", "text": ""}
var _globals_dirty := false
var _since_global_save := 0.0
## Seconds played since the last timed autosave.
var _since_autosave := 0.0


func get_crew_name() -> StringName:
	return &"Saves"


func setup(config: StoryConfig) -> void:
	folder = config.save_folder
	autosave_on_choice = config.autosave_on_choice
	autosave_minutes = config.autosave_minutes
	DirAccess.make_dir_recursive_absolute(folder)
	_connect_director.call_deferred()


func clear() -> void:
	playtime = 0.0
	_since_autosave = 0.0
	_last_line = {"speaker": "", "text": ""}


## Takes a screenshot for the next save. Menus call this before they open,
## so the thumbnail shows the story instead of the menu.
func capture_thumbnail() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return
	image.resize(thumbnail_size.x, thumbnail_size.y, Image.INTERPOLATE_BILINEAR)
	_thumbnail = image


## Saves the current story to [param slot]. Returns OK or an error code.
func save_slot(slot: String) -> Error:
	var story := get_parent()
	if story == null or not story.has_method("capture"):
		return ERR_UNCONFIGURED
	if _thumbnail == null:
		capture_thumbnail()
	var data := {
		"format": FORMAT,
		"storyteller": story.VERSION,
		"slot": slot,
		"saved_at": Time.get_unix_time_from_system(),
		"playtime": playtime,
		"speaker": _last_line["speaker"],
		"text": _last_line["text"],
		"state": story.capture(),
	}
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if _thumbnail != null:
		_thumbnail.save_png(_thumbnail_path(slot))
	elif FileAccess.file_exists(_thumbnail_path(slot)):
		DirAccess.remove_absolute(_thumbnail_path(slot))
	_thumbnail = null
	save_globals()
	saved.emit(slot)
	return OK


## Loads [param slot] and continues the story from the line that was showing.
## Returns OK or an error code.
func load_slot(slot: String) -> Error:
	var data := read_slot(slot)
	if data.is_empty():
		return ERR_FILE_NOT_FOUND
	var story := get_parent()
	story.restore(data["state"])
	playtime = float(data.get("playtime", 0.0))
	_since_autosave = 0.0
	_last_line = {"speaker": data.get("speaker", ""), "text": data.get("text", "")}
	loaded.emit(slot)
	var director := _director()
	if director != null:
		director.resume()
	return OK


## Reads a slot file and upgrades it to the current format. Returns {} if
## the slot is missing or unreadable.
func read_slot(slot: String) -> Dictionary:
	if not has_slot(slot):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(slot)))
	if not parsed is Dictionary:
		push_error("StoryTeller: save slot '%s' is damaged." % slot)
		return {}
	var data: Dictionary = parsed
	var format := int(data.get("format", 0))
	while format < FORMAT:
		if not migrations.has(format):
			push_error("StoryTeller: save slot '%s' uses format %d, which can't be upgraded." % [slot, format])
			return {}
		data = migrations[format].call(data)
		format += 1
		data["format"] = format
	return data


## Gives a saved slot a name chosen by the player, shown on the save and
## load screens. An empty name removes it. Saving to the slot again starts
## without a name. Returns OK, or an error code when the slot is empty.
func set_slot_label(slot: String, label: String) -> Error:
	if not has_slot(slot):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(slot)))
	if not parsed is Dictionary:
		return ERR_FILE_CORRUPT
	var data: Dictionary = parsed
	if label.strip_edges().is_empty():
		data.erase("label")
	else:
		data["label"] = label.strip_edges()
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK


## The highest numbered slot that holds a save, or 0 when there is none.
func highest_numbered_slot() -> int:
	var highest := 0
	for slot in list_slots():
		if slot.is_valid_int():
			highest = maxi(highest, slot.to_int())
	return highest


## Information about a slot for menus: slot, saved_at, playtime, speaker,
## text, label (the player's name for it, if any), and thumbnail (a
## Texture2D or null). Returns {} for empty slots.
func get_slot_info(slot: String) -> Dictionary:
	var data := read_slot(slot)
	if data.is_empty():
		return {}
	data.erase("state")
	data["thumbnail"] = null
	if FileAccess.file_exists(_thumbnail_path(slot)):
		var image := Image.load_from_file(ProjectSettings.globalize_path(_thumbnail_path(slot)))
		if image != null:
			data["thumbnail"] = ImageTexture.create_from_image(image)
	return data


func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_slot(slot: String) -> void:
	for path in [_slot_path(slot), _thumbnail_path(slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Names of all saved slots, newest first.
func list_slots() -> PackedStringArray:
	var slots: Array = []
	for file_name in DirAccess.get_files_at(folder):
		if file_name.ends_with(".json") and file_name != GLOBAL_FILE:
			slots.append(file_name.get_basename())
	var times := {}
	for slot in slots:
		times[slot] = float(read_slot(slot).get("saved_at", 0.0))
	slots.sort_custom(func(a: String, b: String) -> bool: return times[a] > times[b])
	return PackedStringArray(slots)


## The most recently saved slot, or "" if there are none. Used by "Continue".
func latest_slot() -> String:
	var slots := list_slots()
	return slots[0] if not slots.is_empty() else ""


func quick_save() -> Error:
	return save_slot(QUICK_SLOT)


func quick_load() -> Error:
	return load_slot(QUICK_SLOT)


## Writes global variables and read lines to the global file.
func save_globals() -> void:
	var director := _director()
	if director == null:
		return
	var file := FileAccess.open(folder.path_join(GLOBAL_FILE), FileAccess.WRITE)
	if file == null:
		return
	var crew := {}
	for member in _global_keepers():
		crew[str(member.get_crew_name())] = member.capture_globals()
	file.store_string(JSON.stringify({"format": FORMAT, "director": director.capture_globals(), "crew": crew}))
	file.close()
	_globals_dirty = false
	_since_global_save = 0.0


func load_globals() -> void:
	var director := _director()
	var path := folder.path_join(GLOBAL_FILE)
	if director == null or not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		director.restore_globals(parsed.get("director", {}))
		var crew: Dictionary = parsed.get("crew", {})
		for member in _global_keepers():
			var crew_name := str(member.get_crew_name())
			if crew.has(crew_name):
				member.restore_globals(crew[crew_name])


func _process(delta: float) -> void:
	var director := _director()
	if director != null and director.is_playing():
		playtime += delta
		_since_autosave += delta
	if _globals_dirty:
		_since_global_save += delta
		if _since_global_save >= GLOBAL_SAVE_DELAY:
			save_globals()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _globals_dirty:
			save_globals()


func _connect_director() -> void:
	var director := _director()
	if director == null:
		return
	load_globals()
	director.line_started.connect(func(line: Dictionary) -> void:
		_last_line = {"speaker": line["speaker_name"], "text": DialogueBox.plain_text(line["text"])}
		_globals_dirty = true
		if autosave_minutes > 0.0 and _since_autosave >= autosave_minutes * 60.0:
			_since_autosave = 0.0
			save_slot(AUTO_SLOT))
	director.choice_started.connect(func(_options: Array[Dictionary]) -> void:
		if autosave_on_choice:
			save_slot(AUTO_SLOT))
	director.story_finished.connect(save_globals)
	for member in _global_keepers():
		if member.has_signal("globals_changed"):
			member.globals_changed.connect(func() -> void: _globals_dirty = true)


## Crew members other than the director with data kept across
## playthroughs: they have capture_globals() and restore_globals().
func _global_keepers() -> Array[Node]:
	var result: Array[Node] = []
	var story := get_parent()
	if story == null:
		return result
	# Children rather than get_crew(): this also runs while the Story is
	# being freed, when some members are already gone.
	for member in story.get_children():
		if not is_instance_valid(member) or member.is_queued_for_deletion():
			continue
		if member is TaleDirector or member == self or not member is StoryCrew:
			continue
		if member.has_method("capture_globals") and member.has_method("restore_globals"):
			result.append(member)
	return result


func _slot_path(slot: String) -> String:
	return folder.path_join(slot.validate_filename() + ".json")


func _thumbnail_path(slot: String) -> String:
	return folder.path_join(slot.validate_filename() + ".png")


func _director() -> TaleDirector:
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(&"TaleDirector") as TaleDirector
	return null

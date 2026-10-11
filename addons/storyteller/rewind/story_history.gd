class_name StoryHistory
extends StoryCrew
## Crew member that keeps the log of lines the player has read, for the
## history screen. The log is part of saves and rewinds with the story.

signal entry_added(entry: Dictionary)
signal changed

## Most entries kept; older ones are dropped.
var max_entries := 200

## Entries: speaker, color, text, voice, id. The last entry is "pending"
## while its line is still on screen.
var _entries: Array[Dictionary] = []


func get_crew_name() -> StringName:
	return &"History"


func setup(config: StoryConfig) -> void:
	max_entries = config.history_size
	_connect_director.call_deferred()


func clear() -> void:
	_entries.clear()
	changed.emit()


## Entries for display, oldest first, including the line on screen.
func get_entries() -> Array[Dictionary]:
	return _entries


## Leaves out the line on screen: when a save or rewind point is loaded, that
## line is shown again and added back.
func capture() -> Dictionary:
	var saved: Array = []
	for entry in _entries:
		if not entry.get("pending", false):
			saved.append({"speaker": entry["speaker"], "color": [entry["color"].r, entry["color"].g, entry["color"].b], "text": entry["text"], "voice": entry["voice"], "id": entry["id"]})
	return {"entries": saved}


func restore(data: Dictionary) -> void:
	_entries.clear()
	for saved in data.get("entries", []):
		var color: Array = saved.get("color", [1.0, 1.0, 1.0])
		_entries.append({"speaker": saved["speaker"], "color": Color(color[0], color[1], color[2]), "text": saved["text"], "voice": saved.get("voice", ""), "id": saved.get("id", ""), "pending": false})
	changed.emit()


func _connect_director() -> void:
	var story := get_parent()
	var director := story.get_crew(&"TaleDirector") as TaleDirector if story != null and story.has_method("get_crew") else null
	if director == null:
		return
	director.line_started.connect(_on_line_started)
	director.line_finished.connect(func(_line: Dictionary) -> void:
		if not _entries.is_empty():
			_entries.back()["pending"] = false)


func _on_line_started(line: Dictionary) -> void:
	if not _entries.is_empty() and _entries.back().get("pending", false):
		_entries.pop_back()
	var entry := {
		"speaker": line["speaker_name"],
		"color": line.get("speaker_color", Color.WHITE),
		"text": line["text"],
		"voice": line["voice"],
		"id": line["id"],
		"pending": true,
	}
	_entries.append(entry)
	while _entries.size() > max_entries:
		_entries.pop_front()
	entry_added.emit(entry)
	changed.emit()

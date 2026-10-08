class_name StoryCollection
extends StoryCrew
## Crew member for unlockables: gallery pictures, music room tracks, and
## codex entries ([CollectionItem] files in
## [member StoryConfig.collection_folder]). Unlocks are kept across
## playthroughs with the global data.
## [codeblock]
## collect("library_at_night")
## if collected("ada_profile"):
##     ada: "You've read my file, then."
## [/codeblock]

## Emitted when an item is unlocked for the first time.
signal item_collected(item: CollectionItem)
## Emitted when data kept across playthroughs changes.
signal globals_changed

const KINDS := ["image", "music", "entry"]

var collection_folder := "res://story/collection"

var _items: Dictionary = {}
var _unlocked: Dictionary = {}


func get_crew_name() -> StringName:
	return &"Collection"


func setup(config: StoryConfig) -> void:
	collection_folder = config.collection_folder
	_items = scan(collection_folder)


## Unlocks the item called [param id]. Returns an error message or "".
func collect(id: String) -> String:
	if not _items.has(id):
		return "There is no collection item '%s' in %s." % [id, collection_folder]
	if _unlocked.has(id):
		return ""
	_unlocked[id] = true
	item_collected.emit(_items[id])
	globals_changed.emit()
	return ""


func is_collected(id: String) -> bool:
	return _unlocked.has(id)


func has_item(id: String) -> bool:
	return _items.has(id)


func get_item(id: String) -> CollectionItem:
	return _items.get(id)


## Items of one [param kind] ("image", "music", or "entry"), in display order.
func get_items(kind: String) -> Array[CollectionItem]:
	var result: Array[CollectionItem] = []
	for item in _items.values():
		if item.kind == kind:
			result.append(item)
	result.sort_custom(func(a: CollectionItem, b: CollectionItem) -> bool:
		return a.order < b.order if a.order != b.order else a.title.naturalnocasecmp_to(b.title) < 0)
	return result


func is_empty() -> bool:
	return _items.is_empty()


## Adds an item in code, replacing one with the same id.
func add_item(item: CollectionItem) -> void:
	_items[item.id] = item


## Unlocks everything, for testing a game's Extras screen.
func unlock_all() -> void:
	for id in _items:
		_unlocked[id] = true
	globals_changed.emit()


func capture_globals() -> Dictionary:
	return {"unlocked": _unlocked.keys()}


func restore_globals(data: Dictionary) -> void:
	_unlocked.clear()
	for id in data.get("unlocked", []):
		_unlocked[str(id)] = true


## Finds [CollectionItem] files in [param folder].
static func scan(folder: String) -> Dictionary:
	var items := {}
	if not DirAccess.dir_exists_absolute(folder):
		return items
	for file_name in ResourceLoader.list_directory(folder):
		if file_name.get_extension() not in ["tres", "res"]:
			continue
		var item := load(folder.path_join(file_name)) as CollectionItem
		if item == null:
			continue
		if item.id.is_empty():
			item.id = file_name.get_basename()
		if item.title.is_empty():
			item.title = item.id.capitalize()
		items[item.id] = item
	return items

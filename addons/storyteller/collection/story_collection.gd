class_name StoryCollection
extends StoryCrew
## Crew member for unlockables: gallery pictures, music room tracks, and
## codex entries ([CollectionItem] files in
## [member StoryConfig.collection_folder]). Unlocks are kept across
## playthroughs with the global data.
##
## Every CG in [member StoryConfig.cg_folder] has a gallery item: one saved
## with [member CollectionItem.cg] set (or with the CG's name as its id),
## or one made automatically. Showing a CG unlocks its item and records the
## variant, and the gallery shows the variants the player has seen.
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
## Display order of gallery items made automatically for CGs, after most
## saved items.
const CG_ORDER := 1000

var collection_folder := "res://story/collection"
var cg_folder := "res://story/cgs"

var _items: Dictionary = {}
var _unlocked: Dictionary = {}
## CG name to its variants, from [method StoryAssets.scan_cgs].
var _cgs: Dictionary = {}
## Item id to the CG variants the player has seen, in the order seen.
var _seen_variants: Dictionary = {}


func get_crew_name() -> StringName:
	return &"Collection"


func setup(config: StoryConfig) -> void:
	collection_folder = config.collection_folder
	cg_folder = config.cg_folder
	_items = scan(collection_folder)
	_cgs = StoryAssets.scan_cgs(cg_folder)
	add_cg_items(_items, _cgs)
	_connect_stage.call_deferred()


## Links CGs to gallery items in [param items] and adds an item for each CG
## that has none. A saved item is linked when its [member CollectionItem.cg]
## names the CG, or when its id is the CG's name and it has no image.
static func add_cg_items(items: Dictionary, cgs: Dictionary) -> void:
	var linked := {}
	for item in items.values():
		if item.cg.is_empty() and item.kind == "image" and item.image == null and cgs.has(item.id):
			item.cg = item.id
		if not item.cg.is_empty():
			linked[item.cg] = true
	var names := cgs.keys()
	names.sort()
	for i in names.size():
		var cg_name: String = names[i]
		if linked.has(cg_name) or items.has(cg_name):
			continue
		var item := CollectionItem.new()
		item.id = cg_name
		item.kind = "image"
		item.cg = cg_name
		item.title = cg_name.capitalize()
		item.order = CG_ORDER + i
		items[cg_name] = item


## Records that the player saw [param variant] of the CG [param cg_name]
## and unlocks its gallery item. The Stage calls this through
## [signal StoryStage.cg_shown].
func see_cg(cg_name: String, variant: String) -> void:
	var item := get_cg_item(cg_name)
	if item == null:
		return
	var seen: Array = _seen_variants.get(item.id, [])
	var is_new := variant not in seen
	if is_new:
		seen.append(variant)
		_seen_variants[item.id] = seen
	if not _unlocked.has(item.id):
		collect(item.id)
	elif is_new:
		globals_changed.emit()


## The gallery item for the CG [param cg_name], or null.
func get_cg_item(cg_name: String) -> CollectionItem:
	for item in _items.values():
		if item.cg == cg_name:
			return item
	return null


## Pictures to show for a gallery item: its image, or the variants of its
## CG that the player has seen. When the item was unlocked another way (by
## collect() or unlock_all), every variant is shown.
func get_pictures(item: CollectionItem) -> Array[Texture2D]:
	var pictures: Array[Texture2D] = []
	if item.cg.is_empty():
		if item.image != null:
			pictures.append(item.image)
		return pictures
	var seen: Array = _seen_variants.get(item.id, [])
	for variant in _cgs.get(item.cg, PackedStringArray()):
		if seen.is_empty() or variant in seen:
			var texture := load(StoryAssets.find_cg(cg_folder, item.cg, variant)) as Texture2D
			if texture != null:
				pictures.append(texture)
	return pictures


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
	return {"unlocked": _unlocked.keys(), "cg_variants": _seen_variants.duplicate(true)}


func restore_globals(data: Dictionary) -> void:
	_unlocked.clear()
	for id in data.get("unlocked", []):
		_unlocked[str(id)] = true
	_seen_variants.clear()
	var variants: Dictionary = data.get("cg_variants", {})
	for id in variants:
		var seen: Array = []
		for variant in variants[id]:
			seen.append(str(variant))
		_seen_variants[str(id)] = seen


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


func _connect_stage() -> void:
	var story := get_parent()
	if story == null or not story.has_method("get_crew"):
		return
	var stage := story.get_crew(&"Stage") as StoryStage
	if stage != null and not stage.cg_shown.is_connected(see_cg):
		stage.cg_shown.connect(see_cg)

class_name StoryStage
extends StoryCrew
## Crew member that owns what is drawn behind the dialogue box: backdrops,
## cast members, and props, each on its own [CanvasLayer].
##
## Cast members are found in [member StoryConfig.cast_folder]:
## [code]<id>.tres[/code] ([CastProfile]) files, or [code]<id>/[/code]
## folders of mood images.

## Canvas layers, back to front. The dialogue box uses layer 10.
const BACKDROP_LAYER := -10
const CAST_LAYER := -5
const PROP_LAYER := -4

var backdrop_layer: CanvasLayer
var cast_layer: CanvasLayer
var prop_layer: CanvasLayer
## Dim cast members who are not speaking.
var highlight_speaker := true

var _profiles: Dictionary = {}
var _cast: Dictionary = {}


func get_crew_name() -> StringName:
	return &"Stage"


func setup(config: StoryConfig) -> void:
	highlight_speaker = config.highlight_speaker
	backdrop_layer = _make_layer("Backdrops", BACKDROP_LAYER)
	cast_layer = _make_layer("Cast", CAST_LAYER)
	prop_layer = _make_layer("Props", PROP_LAYER)
	_profiles = scan_cast(config.cast_folder)
	_connect_director.call_deferred()


func _ready() -> void:
	get_viewport().size_changed.connect(_relayout)


func clear() -> void:
	for member in _cast.values():
		member.queue_free()
	_cast.clear()


## Registers a profile in code, replacing one with the same id.
func add_profile(profile: CastProfile) -> void:
	_profiles[profile.id] = profile
	if _cast.has(profile.id):
		_cast[profile.id].queue_free()
		_cast.erase(profile.id)


func has_cast(id: String) -> bool:
	return _profiles.has(id)


## Returns the cast member called [param id], creating it the first time,
## or null if there is no such profile.
func get_cast(id: String) -> CastMember:
	if _cast.has(id):
		return _cast[id]
	if not _profiles.has(id):
		return null
	var member := CastMember.new()
	member.setup(_profiles[id])
	member.is_skipping = _is_skipping
	cast_layer.add_child(member)
	_cast[id] = member
	return member


## Cast ids and their moods, for the checker.
func get_cast_moods() -> Dictionary:
	var result := {}
	for id in _profiles:
		var profile: CastProfile = _profiles[id]
		result[id] = profile.look.get_moods() if profile.look else PackedStringArray()
	return result


## Name provider for the director: cast members by id.
func resolve_tale_name(tale_name: String) -> Array:
	if has_cast(tale_name):
		return [true, get_cast(tale_name)]
	return [false, null]


func capture() -> Dictionary:
	var cast := {}
	for id in _cast:
		cast[id] = _cast[id].capture()
	return {"cast": cast}


func restore(data: Dictionary) -> void:
	for member in _cast.values():
		member.finish_animations()
		member.visible = false
		member.on_stage = false
	var cast: Dictionary = data.get("cast", {})
	for id in cast:
		var member := get_cast(id)
		if member != null:
			member.restore(cast[id])


## Finds cast profiles in [param folder]: "<id>.tres" files holding a
## [CastProfile], and "<id>/" folders of mood images.
static func scan_cast(folder: String) -> Dictionary:
	var profiles := {}
	if not DirAccess.dir_exists_absolute(folder):
		return profiles
	for file_name in DirAccess.get_files_at(folder):
		if file_name.get_extension() in ["tres", "res"]:
			var profile := load(folder.path_join(file_name)) as CastProfile
			if profile != null:
				if profile.id.is_empty():
					profile.id = file_name.get_basename()
				profiles[profile.id] = profile
	for sub in DirAccess.get_directories_at(folder):
		if profiles.has(sub) or sub.begins_with("."):
			continue
		var profile := CastProfile.new()
		profile.id = sub
		var look := SpriteSetLook.new()
		look.folder = folder.path_join(sub)
		profile.look = look
		var moods := look.get_moods()
		if not moods.is_empty():
			profile.default_mood = "neutral" if "neutral" in moods else moods[0]
		profiles[sub] = profile
	for id in profiles:
		var profile: CastProfile = profiles[id]
		if profile.look is SpriteSetLook and profile.look.folder.is_empty() and profile.look.moods.is_empty():
			profile.look.folder = folder.path_join(id)
	return profiles


func _make_layer(layer_name: String, index: int) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = layer_name
	layer.layer = index
	add_child(layer)
	return layer


func _connect_director() -> void:
	var director := _director()
	if director != null and not director.line_started.is_connected(_on_line_started):
		director.line_started.connect(_on_line_started)


func _on_line_started(line: Dictionary) -> void:
	var speaker: String = line["speaker_id"]
	var speaking := _cast.get(speaker) as CastMember
	if speaking != null and not line["mood"].is_empty():
		speaking.mood = line["mood"]
	if not highlight_speaker:
		return
	for id in _cast:
		var member: CastMember = _cast[id]
		member.set_highlighted(speaker.is_empty() or speaking == null or member == speaking)


func _is_skipping() -> bool:
	var director := _director()
	return director != null and director.skipping


func _director() -> TaleDirector:
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(&"TaleDirector") as TaleDirector
	return null


func _relayout() -> void:
	for member in _cast.values():
		member.relayout()

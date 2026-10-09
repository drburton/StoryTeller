class_name StoryStage
extends StoryCrew
## Crew member that owns what is drawn behind the dialogue box: backdrops,
## cast members, props, and CGs, each on its own [CanvasLayer], plus the
## camera that moves the backdrop, cast, and props.
##
## Cast members are found in [member StoryConfig.cast_folder]:
## [code]<id>.tres[/code] ([CastProfile]) files, or [code]<id>/[/code]
## folders of mood images. Backdrops and props are images (or scenes, for
## props) named after the files in their folders. CGs are full-screen event
## pictures in [member StoryConfig.cg_folder] (see [method StoryAssets.scan_cgs]).

## Emitted when a CG is shown by [method show_cg], so the gallery can
## unlock it. Not emitted when a save is restored.
signal cg_shown(cg_name: String, variant: String)

## Canvas layers, back to front. They draw above the game's own canvas
## (layer 0) and below the dialogue box (layer 10). The backdrop is
## transparent until a tale shows one, so games that only use dialogue are
## not covered. CGs cover the stage; weather and color filters (layers 5
## and 6) draw over them.
const BACKDROP_LAYER := 1
const CAST_LAYER := 2
const PROP_LAYER := 3
const CG_LAYER := 4

var backdrop_layer: CanvasLayer
var cast_layer: CanvasLayer
var prop_layer: CanvasLayer
var cg_layer: CanvasLayer
## Shows CGs, with the same transitions as backdrops.
var cg_view: BackdropView
var backdrop_view: BackdropView
var camera: StageCamera
## Dim cast members who are not speaking.
var highlight_speaker := true
var backdrop_folder := "res://story/backdrops"
var prop_folder := "res://story/props"
var transition_folder := "res://story/transitions"
var cg_folder := "res://story/cgs"

var _profiles: Dictionary = {}
var _cast: Dictionary = {}
## Prop name to {"node": Node2D, "at": Vector2}.
var _props: Dictionary = {}
## The CG on screen: {"name", "variant"}, or empty.
var _cg: Dictionary = {}


func get_crew_name() -> StringName:
	return &"Stage"


func setup(config: StoryConfig) -> void:
	highlight_speaker = config.highlight_speaker
	backdrop_folder = config.backdrop_folder
	prop_folder = config.prop_folder
	cg_folder = config.cg_folder
	backdrop_layer = _make_layer("Backdrops", BACKDROP_LAYER)
	cast_layer = _make_layer("Cast", CAST_LAYER)
	prop_layer = _make_layer("Props", PROP_LAYER)
	cg_layer = _make_layer("CGs", CG_LAYER)
	backdrop_view = BackdropView.new()
	backdrop_view.name = "BackdropView"
	backdrop_layer.add_child(backdrop_view)
	cg_view = BackdropView.new()
	cg_view.name = "CGView"
	cg_layer.add_child(cg_view)
	camera = StageCamera.new()
	camera.name = "Camera"
	camera.layers = [backdrop_layer, cast_layer, prop_layer]
	camera.is_skipping = _is_skipping
	add_child(camera)
	_profiles = scan_cast(config.cast_folder)
	_connect_director.call_deferred()


func _ready() -> void:
	get_viewport().size_changed.connect(_relayout)


func clear() -> void:
	for member in _cast.values():
		member.queue_free()
	_cast.clear()
	for prop_name in _props.keys():
		_props[prop_name]["node"].queue_free()
	_props.clear()
	if backdrop_view:
		backdrop_view.show_backdrop(Color.TRANSPARENT, Color.TRANSPARENT, "none", 0.0)
	_cg = {}
	if cg_view:
		cg_view.show_backdrop(Color.TRANSPARENT, Color.TRANSPARENT, "none", 0.0)
	if camera:
		camera.restore({})


## Shows a backdrop: an image name from [member backdrop_folder], or a
## Color. Awaitable. Returns an error message, or "" on success.
func show_backdrop(source: Variant, transition := "fade", time := 1.0, mask := "") -> String:
	var mask_texture: Texture2D = null
	if not mask.is_empty():
		mask_texture = StoryAssets.load_asset(transition_folder, mask, StoryAssets.IMAGE_EXTENSIONS) as Texture2D
		if mask_texture == null:
			return "Transition mask '%s' was not found in %s." % [mask, transition_folder]
	if source is Color:
		await backdrop_view.show_backdrop(source, source, transition, time, mask_texture, _is_skipping())
		return ""
	var texture := StoryAssets.load_asset(backdrop_folder, str(source), StoryAssets.IMAGE_EXTENSIONS) as Texture2D
	if texture == null:
		return "Backdrop '%s' was not found in %s." % [source, backdrop_folder]
	await backdrop_view.show_backdrop(texture, str(source), transition, time, mask_texture, _is_skipping())
	return ""


## Shows a CG over the stage: a full-screen picture from [member cg_folder].
## [param variant] picks one picture of a CG folder; empty shows the
## "default" variant, or the first. Showing another CG, or another variant
## of the same one, blends from the picture on screen. Awaitable. Returns
## an error message, or "" on success.
func show_cg(cg_name: String, variant := "", transition := "fade", time := 1.0) -> String:
	var found := _find_cg(cg_name, variant)
	if found[1] is String:
		return found[1]
	_cg = {"name": cg_name, "variant": found[0]}
	cg_shown.emit(cg_name, found[0])
	await cg_view.show_backdrop(found[1], "%s/%s" % [cg_name, found[0]], transition, time, null, _is_skipping())
	return ""


## Removes the CG and shows the stage again. Awaitable.
func hide_cg(transition := "fade", time := 1.0) -> void:
	if _cg.is_empty():
		return
	_cg = {}
	await cg_view.show_backdrop(Color.TRANSPARENT, Color.TRANSPARENT, transition, time, null, _is_skipping())


## The CG on screen as [code]{"name", "variant"}[/code], or an empty
## dictionary.
func get_cg() -> Dictionary:
	return _cg.duplicate()


## Returns [variant, Texture2D] for a CG, or [variant, error message].
func _find_cg(cg_name: String, variant: String) -> Array:
	var variants: PackedStringArray = StoryAssets.scan_cgs(cg_folder).get(cg_name, PackedStringArray())
	if variants.is_empty():
		return [variant, "CG '%s' was not found in %s." % [cg_name, cg_folder]]
	if variant.is_empty():
		variant = StoryAssets.default_cg_variant(variants)
	elif variant not in variants:
		if variants[0].is_empty():
			return [variant, "CG '%s' is a single picture and has no variant '%s'." % [cg_name, variant]]
		return [variant, "CG '%s' has no variant '%s'. Its variants are: %s." % [cg_name, variant, ", ".join(variants)]]
	var texture := load(StoryAssets.find_cg(cg_folder, cg_name, variant)) as Texture2D
	if texture == null:
		return [variant, "CG '%s' could not be loaded." % cg_name]
	return [variant, texture]


## Shows a prop (an image or scene from [member prop_folder]) centered at a
## stage position. Awaitable. Returns an error message or "".
func show_prop(prop_name: String, at := Vector2(0.5, 0.5), time := 0.3) -> String:
	var node: Node2D
	if _props.has(prop_name):
		node = _props[prop_name]["node"]
	else:
		var path := StoryAssets.find(prop_folder, prop_name, StoryAssets.IMAGE_EXTENSIONS + StoryAssets.SCENE_EXTENSIONS)
		if path.is_empty():
			return "Prop '%s' was not found in %s." % [prop_name, prop_folder]
		var resource := load(path)
		if resource is PackedScene:
			node = resource.instantiate() as Node2D
		else:
			var sprite := Sprite2D.new()
			sprite.texture = resource
			node = sprite
		if node == null:
			return "Prop '%s' must be an image or a scene with a Node2D root." % prop_name
		node.name = prop_name
		prop_layer.add_child(node)
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1152, 648)
	node.position = Vector2(at.x * size.x, size.y - at.y * size.y)
	_props[prop_name] = {"node": node, "at": at}
	await _fade(node, 1.0, time)
	return ""


## Removes a prop. Awaitable.
func hide_prop(prop_name: String, time := 0.3) -> void:
	if not _props.has(prop_name):
		return
	var node: Node2D = _props[prop_name]["node"]
	_props.erase(prop_name)
	await _fade(node, 0.0, time)
	node.queue_free()


## Removes all props. Awaitable.
func clear_props(time := 0.3) -> void:
	var names := _props.keys()
	for i in names.size():
		if i == names.size() - 1:
			await hide_prop(names[i], time)
		else:
			hide_prop(names[i], time)


## Every cast member on stage exits. Awaitable.
func exit_all(time := 0.4) -> void:
	var leaving: Array[CastMember] = []
	for member in _cast.values():
		if member.on_stage:
			leaving.append(member)
	for i in leaving.size():
		if i == leaving.size() - 1:
			await leaving[i].exit(time)
		else:
			leaving[i].exit(time)


func get_prop_names() -> PackedStringArray:
	return PackedStringArray(_props.keys())


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
	member.report_error = _report_error
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


## Cast ids and the names of their fields ([member CastProfile.fields]),
## for the checker and autocomplete.
func get_cast_fields() -> Dictionary:
	var result := {}
	for id in _profiles:
		result[id] = (_profiles[id] as CastProfile).get_field_names()
	return result


## Starts loading a backdrop or prop in the background.
func preload_asset(kind: String, asset_name: String) -> void:
	match kind:
		"backdrop":
			StoryAssets.preload_path(StoryAssets.find(backdrop_folder, asset_name, StoryAssets.IMAGE_EXTENSIONS))
		"prop":
			StoryAssets.preload_path(StoryAssets.find(prop_folder, asset_name, StoryAssets.IMAGE_EXTENSIONS + StoryAssets.SCENE_EXTENSIONS))
		"cg":
			var variants: PackedStringArray = StoryAssets.scan_cgs(cg_folder).get(asset_name, PackedStringArray())
			if not variants.is_empty():
				StoryAssets.preload_path(StoryAssets.find_cg(cg_folder, asset_name, StoryAssets.default_cg_variant(variants)))


## Names this crew member adds to tales, for the checker.
func get_tale_names() -> PackedStringArray:
	return PackedStringArray(["camera"])


## Name provider for the director: cast members by id, and "camera".
func resolve_tale_name(tale_name: String) -> Array:
	if has_cast(tale_name):
		return [true, get_cast(tale_name)]
	if tale_name == "camera" and camera != null:
		return [true, camera]
	return [false, null]


func capture() -> Dictionary:
	var cast := {}
	for id in _cast:
		cast[id] = _cast[id].capture()
	var props := {}
	for prop_name in _props:
		var at: Vector2 = _props[prop_name]["at"]
		props[prop_name] = [at.x, at.y]
	var backdrop: Variant = backdrop_view.current
	if backdrop is Color:
		backdrop = [backdrop.r, backdrop.g, backdrop.b, backdrop.a]
	return {"cast": cast, "backdrop": backdrop, "props": props, "camera": camera.capture(), "cg": _cg.duplicate()}


func restore(data: Dictionary) -> void:
	for member in _cast.values():
		member.finish_animations()
		member.visible = false
		member.on_stage = false
		member.display_name = ""
		member.draw_order = 0
		member.reset_fields()
	var cast: Dictionary = data.get("cast", {})
	for id in cast:
		var member := get_cast(id)
		if member != null:
			member.restore(cast[id])
	var backdrop: Variant = data.get("backdrop", [0.0, 0.0, 0.0, 0.0])
	if backdrop is Array:
		backdrop = Color(backdrop[0], backdrop[1], backdrop[2], backdrop[3])
	show_backdrop(backdrop, "none", 0.0)
	for prop_name in _props.keys():
		_props[prop_name]["node"].queue_free()
	_props.clear()
	var props: Dictionary = data.get("props", {})
	for prop_name in props:
		show_prop(prop_name, Vector2(props[prop_name][0], props[prop_name][1]), 0.0)
	camera.restore(data.get("camera", {}))
	var cg: Dictionary = data.get("cg", {})
	var found := _find_cg(str(cg.get("name", "")), str(cg.get("variant", ""))) if not cg.is_empty() else []
	if not found.is_empty() and found[1] is Texture2D:
		_cg = {"name": str(cg["name"]), "variant": found[0]}
		cg_view.show_backdrop(found[1], "%s/%s" % [_cg["name"], found[0]], "none", 0.0)
	else:
		if not found.is_empty():
			push_warning("StoryTeller: %s" % found[1])
		_cg = {}
		cg_view.show_backdrop(Color.TRANSPARENT, Color.TRANSPARENT, "none", 0.0)


## Finds cast profiles in [param folder]: "<id>.tres" files holding a
## [CastProfile], and "<id>/" folders of mood images.
static func scan_cast(folder: String) -> Dictionary:
	var profiles := {}
	if not DirAccess.dir_exists_absolute(folder):
		return profiles
	# list_directory (not DirAccess) so exported games, whose folders hold
	# .remap and .import files, find the same entries.
	var entries := ResourceLoader.list_directory(folder)
	for file_name in entries:
		if file_name.get_extension() in ["tres", "res"]:
			var profile := load(folder.path_join(file_name)) as CastProfile
			if profile != null:
				if profile.id.is_empty():
					profile.id = file_name.get_basename()
				profiles[profile.id] = profile
	for entry in entries:
		if not entry.ends_with("/"):
			continue
		var sub := entry.trim_suffix("/")
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


func _fade(node: CanvasItem, alpha: float, time: float) -> void:
	if time <= 0.0 or _is_skipping() or not node.is_inside_tree():
		node.modulate.a = alpha
		return
	if alpha > 0.0 and node.modulate.a >= alpha:
		node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", alpha, time)
	await tween.finished


func _report_error(message: String) -> void:
	var director := _director()
	if director != null:
		director.report_error(message)
	else:
		push_warning("StoryTeller: " + message)


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

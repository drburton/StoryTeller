class_name TaleSignatures
extends RefCounted
## What the visual editor knows about calls: the parameters of built-in
## actions, cast member methods, and camera methods (to build forms), and
## the values that fit a parameter (to offer them in a list).

const CAST_SCRIPT := preload("res://addons/storyteller/stage/cast_member.gd")
const CAMERA_SCRIPT := preload("res://addons/storyteller/stage/stage_camera.gd")
const CAST_TRANSITIONS: Array[String] = ["fade", "slide_left", "slide_right", "none"]

static var _actions: Dictionary = {}


## Parameters for [param callee] (an action name, "cast_id.method", or
## "camera.method"), as from [method TaleCalls.parameters], or an empty list
## when unknown.
static func for_callee(callee: String, context: TaleCheckContext) -> Array[Dictionary]:
	if "." in callee:
		var owner := callee.get_slice(".", 0)
		var method := callee.get_slice(".", 1)
		if context != null and context.cast.has(owner) and method in TaleCompletion.CAST_METHODS:
			return TaleCalls.parameters(CAST_SCRIPT, method)
		if owner == "camera" and method in TaleCompletion.CAMERA_METHODS:
			return TaleCalls.parameters(CAMERA_SCRIPT, method)
		return []
	var script: Script = action_scripts().get(callee)
	return TaleCalls.parameters(script, "run", 1) if script != null else []


## Built-in action scripts by action name.
static func action_scripts() -> Dictionary:
	if _actions.is_empty():
		for script in TaleDirector.BUILTIN_ACTIONS:
			var action: TaleAction = script.new()
			_actions[action.get_action_name()] = script
	return _actions


## Values that fit [param param] of [param callee], such as backdrop names
## for backdrop("..."), or an empty list.
static func choices(callee: String, param: String, config: StoryConfig, context: TaleCheckContext) -> PackedStringArray:
	var method := callee.get_slice(".", 1) if "." in callee else callee
	match [method, param]:
		["backdrop", "name"]:
			return _assets(config.backdrop_folder, StoryAssets.IMAGE_EXTENSIONS)
		["backdrop", "transition"], ["cg", "transition"], ["hide_cg", "transition"]:
			return PackedStringArray(BackdropView.TRANSITIONS.keys())
		["cg", "name"]:
			var cgs := PackedStringArray(StoryAssets.scan_cgs(config.cg_folder).keys())
			cgs.sort()
			return cgs
		["backdrop", "mask"]:
			return _assets("res://story/transitions", StoryAssets.IMAGE_EXTENSIONS)
		["prop", "name"], ["hide_prop", "name"]:
			return _assets(config.prop_folder, StoryAssets.IMAGE_EXTENSIONS + StoryAssets.SCENE_EXTENSIONS)
		["music", "track"]:
			return _assets(config.audio_folder.path_join("music"), StoryAssets.AUDIO_EXTENSIONS)
		["sound", "name"]:
			return _assets(config.audio_folder.path_join("sounds"), StoryAssets.AUDIO_EXTENSIONS)
		["ambience", "name"]:
			return _assets(config.audio_folder.path_join("ambience"), StoryAssets.AUDIO_EXTENSIONS)
		["voice", "clip"]:
			return _assets(config.audio_folder.path_join("voice"), StoryAssets.AUDIO_EXTENSIONS)
		["play_movie", "name"]:
			return _assets(config.movie_folder, ["ogv"])
		["collect", "id"]:
			var ids := PackedStringArray(StoryCollection.scan(config.collection_folder).keys())
			ids.sort()
			return ids
		["weather", "kind"]:
			return PackedStringArray(StoryEffects.WEATHER_KINDS)
		["filter", "name"]:
			return PackedStringArray(StoryEffects.FILTERS)
		["dialogue_style", "name"]:
			return PackedStringArray(["classic", "page"])
		["enter", "mood_name"]:
			var owner := callee.get_slice(".", 0)
			if context != null and context.cast.has(owner):
				return PackedStringArray(context.cast[owner])
		["enter", "transition"], ["exit", "transition"]:
			return PackedStringArray(CAST_TRANSITIONS)
		["enter", "at"], ["move_to", "at"]:
			return PackedStringArray(["LEFT", "CENTER", "RIGHT"])
	return PackedStringArray()


static func _assets(folder: String, extensions: Array) -> PackedStringArray:
	return StoryAssets.list_names(folder, extensions)

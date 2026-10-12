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


## Action scripts by action name: the built-in ones and those in the
## project's [member StoryConfig.actions].
static func action_scripts() -> Dictionary:
	if _actions.is_empty():
		for script in TaleDirector.BUILTIN_ACTIONS:
			var action: TaleAction = script.new()
			_actions[action.get_action_name()] = script
	var result := _actions.duplicate()
	for action in StoryConfig.make_actions(preload("res://addons/storyteller/core/story.gd").load_config().get_action_scripts()):
		result[action.get_action_name()] = action.get_script()
	return result


## Values that fit [param param] of [param callee], such as backdrop names
## for backdrop("..."), or an empty list.
static func choices(callee: String, param: String, config: StoryConfig, context: TaleCheckContext) -> PackedStringArray:
	var method := callee.get_slice(".", 1) if "." in callee else callee
	match [method, param]:
		["backdrop", "name"]:
			return _assets(config.backdrop_folder, StoryAssets.IMAGE_EXTENSIONS)
		["backdrop", "transition"], ["cg", "transition"], ["hide_cg", "transition"]:
			var names := PackedStringArray(BackdropView.TRANSITIONS.keys())
			var extra := StoryStage.scan_transitions(config.transition_folder).keys()
			extra.append_array(config.transitions.keys())
			extra.sort()
			for transition_name in extra:
				if transition_name not in names:
					names.append(transition_name)
			return names
		["cg", "name"]:
			var cgs := PackedStringArray(StoryAssets.scan_cgs(config.cg_folder).keys())
			cgs.sort()
			return cgs
		["backdrop", "mask"]:
			return _assets(config.transition_folder, StoryAssets.IMAGE_EXTENSIONS)
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


## Builds a check context for the tale at [param source_file] with the
## built-in actions, the cast and assets of the tale's StoryConfig (see
## [method Story.config_for_tale]), and the beats and variables of the other
## tales in the same folder. Works outside the editor too, so the Studio can
## check stories on a tablet. [param story_config] replaces the tale's own
## config, for a tale kept outside the project.
static func make_context(source_file: String, tale_name: String, story_config: StoryConfig = null) -> TaleCheckContext:
	var config: StoryConfig = story_config if story_config != null \
		else preload("res://addons/storyteller/core/story.gd").config_for_tale(source_file)
	var director := TaleDirector.new()
	director.setup(config)
	var context := director.make_check_context(tale_name)
	director.free()
	var profiles := StoryStage.scan_cast(config.cast_folder)
	for id in profiles:
		var profile: CastProfile = profiles[id]
		context.add_cast(id, profile.look.get_moods() if profile.look else PackedStringArray(), profile.get_field_names())
	add_asset_checks(context, config)
	context.add_exposed("camera")
	for exposed_name in config.exposed_names:
		context.add_exposed(exposed_name)
	var folder := source_file.get_base_dir()
	for file_name in DirAccess.get_files_at(folder):
		if not file_name.ends_with(".tale") or file_name.get_basename() == tale_name:
			continue
		var doc := TaleParser.parse(FileAccess.get_file_as_string(folder.path_join(file_name)))
		var beats := PackedStringArray()
		var vars := PackedStringArray()
		for statement in doc.statements:
			if statement.kind == TaleNode.Kind.BEAT:
				beats.append(statement.name)
			elif statement.kind == TaleNode.Kind.VAR or statement.kind == TaleNode.Kind.CONST:
				vars.append(statement.name)
		context.add_tale(file_name.get_basename(), beats, vars)
	return context


## Adds to [param context] checks that warn about asset names in tales that
## match no file, such as [code]backdrop("libary")[/code].
static func add_asset_checks(context: TaleCheckContext, config: StoryConfig) -> void:
	var folder_check := func(kind: String, folder: String, extensions: Array) -> Callable:
		var typed: Array[String] = []
		typed.assign(extensions)
		return func(asset_name: String) -> String:
			if StoryAssets.find(folder, asset_name, typed).is_empty():
				return "There is no %s '%s' in %s." % [kind, asset_name, folder]
			return ""
	var images := StoryAssets.IMAGE_EXTENSIONS
	var audio := StoryAssets.AUDIO_EXTENSIONS
	context.add_asset_check("backdrop", "name", folder_check.call("backdrop", config.backdrop_folder, images))
	var props := folder_check.call("prop", config.prop_folder, images + StoryAssets.SCENE_EXTENSIONS)
	context.add_asset_check("prop", "name", props)
	context.add_asset_check("music", "track", folder_check.call("music track", config.audio_folder.path_join("music"), audio))
	context.add_asset_check("sound", "name", folder_check.call("sound", config.audio_folder.path_join("sounds"), audio))
	context.add_asset_check("ambience", "name", folder_check.call("ambience", config.audio_folder.path_join("ambience"), audio))
	context.add_asset_check("voice", "clip", folder_check.call("voice clip", config.audio_folder.path_join("voice"), audio))
	context.add_asset_check("play_movie", "name", folder_check.call("movie", config.movie_folder, ["ogv"]))
	var cg_folder := config.cg_folder
	context.add_asset_check("cg", "name", func(cg_name: String) -> String:
		if not StoryAssets.scan_cgs(cg_folder).has(cg_name):
			return "There is no CG '%s' in %s." % [cg_name, cg_folder]
		return "")
	var collection_folder := config.collection_folder
	context.add_asset_check("collect", "id", func(id: String) -> String:
		if not StoryCollection.scan(collection_folder).has(id):
			return "There is no collection item '%s' in %s." % [id, collection_folder]
		return "")


static func _assets(folder: String, extensions: Array) -> PackedStringArray:
	return StoryAssets.list_names(folder, extensions)

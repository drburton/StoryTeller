extends SceneTree
## Plays a tale down every path, taking each option at every choice, and
## prints what it finds (see [TalePaths]): errors, paths that get stuck or
## loop, and scenes no path reaches. Run it in your project's folder:
## [codeblock]
## godot --headless --path . -s res://addons/storyteller/editor/explore_paths.gd -- runaway
## godot --headless --path . -s res://addons/storyteller/editor/explore_paths.gd -- runaway bridge
## godot --headless --path . -s res://addons/storyteller/editor/explore_paths.gd -- path/to/draft.tale --expose=set3d
## [/codeblock]
## The first argument is a tale in the tales folder set in StoryConfig, or a
## .tale file anywhere; the second is the scene to start from ("start").
## [code]--expose=name,name[/code] adds names game code exposes to the ones
## in StoryConfig.exposed_names, for a draft tried outside its project.
## Exits with 1 when a path has a problem.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := PackedStringArray()
	var exposed := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expose="):
			exposed.append_array(arg.trim_prefix("--expose=").split(",", false))
		else:
			args.append(arg)
	if args.is_empty():
		printerr("Give a tale name or a .tale file, such as: -- runaway")
		quit(2)
		return
	var config: StoryConfig = preload("res://addons/storyteller/core/story.gd").load_config().duplicate()
	config.exposed_names = config.exposed_names + exposed
	var tale_name := args[0]
	var sources := {}
	if tale_name.ends_with(".tale"):
		var source := FileAccess.get_file_as_string(tale_name)
		if source.is_empty():
			printerr("Can't read %s." % tale_name)
			quit(2)
			return
		tale_name = tale_name.get_file().get_basename()
		sources[tale_name] = source
	var paths := TalePaths.new()
	root.add_child(paths)
	var report := await paths.explore(config, tale_name, args[1] if args.size() > 1 else "start", sources)
	print(TalePaths.describe(report))
	quit(1 if not report["problems"].is_empty() else 0)

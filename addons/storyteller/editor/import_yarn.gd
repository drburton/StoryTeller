extends SceneTree
## Converts Yarn Spinner scripts into tales from the command line, like the
## "Import Yarn" button in the Story tab:
## [codeblock]
## godot --headless --path . -s res://addons/storyteller/editor/import_yarn.gd -- path/to/intro.yarn
## [/codeblock]
## Each file becomes a tale with the same name in the tales folder set in
## StoryConfig. Run the editor (or [code]--import[/code]) afterwards so
## Godot imports the new tales.


func _initialize() -> void:
	var config: StoryConfig = preload("res://addons/storyteller/core/story.gd").load_config()
	var cast_ids := PackedStringArray(StoryStage.scan_cast(config.cast_folder).keys())
	var failed := false
	for yarn_path in OS.get_cmdline_user_args():
		var result := YarnConverter.import_file(yarn_path, config.tales_folder, cast_ids)
		if not result["error"].is_empty():
			printerr(result["error"])
			failed = true
			continue
		print("Imported %s as %s." % [yarn_path, result["path"]])
		for note in result["notes"]:
			print("  " + note)
	quit(1 if failed else 0)

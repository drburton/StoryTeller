extends SceneTree
## Checks .tale files with the project's StoryConfig (cast, assets, actions)
## and prints every problem. Handy for checking examples in documentation:
## [codeblock]
## godot --headless --path . -s res://tools/check_tale.gd -- path/to/a.tale [more.tale]
## [/codeblock]
## Exits with 1 when any file has an error.

const TaleImporter := preload("res://addons/storyteller/editor/tale_importer.gd")


func _initialize() -> void:
	var failed := false
	for path in OS.get_cmdline_user_args():
		var tale_name := path.get_file().get_basename()
		var context := TaleImporter._make_context(path, tale_name)
		var result := TaleCompiler.build(FileAccess.get_file_as_string(path), tale_name, context)
		var problems := 0
		for diagnostic in result["diagnostics"]:
			print("%s: %s" % [path, diagnostic])
			problems += 1
			failed = failed or diagnostic.is_error()
		if problems == 0:
			print("%s: clean" % path)
	quit(1 if failed else 0)

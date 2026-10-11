extends SceneTree
## Exports strings for translation from the command line, like the
## "Export Strings" button in the Story tab:
## [codeblock]
## godot --headless --path . -s res://addons/storyteller/editor/export_strings.gd
## godot --headless --path . -s res://addons/storyteller/editor/export_strings.gd -- --languages=es,fr
## [/codeblock]
## Run the editor (or [code]--import[/code]) afterwards so Godot imports the CSV.


func _initialize() -> void:
	var config: StoryConfig = preload("res://addons/storyteller/core/story.gd").load_config()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--languages="):
			for language in arg.get_slice("=", 1).split(",", false):
				if language not in config.languages:
					config.languages.append(language.strip_edges())
	var result := StoryStrings.export_strings(config)
	for problem in result["problems"]:
		printerr(problem)
	print("Exported %d strings to %s." % [result["count"], config.translation_file])
	quit(1 if not result["problems"].is_empty() else 0)

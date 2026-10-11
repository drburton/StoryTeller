extends SceneTree
## Regenerates docs/action-reference.md from the built-in actions (see
## [ActionReference]):
## [codeblock]
## godot --headless --path . -s res://addons/storyteller/editor/write_action_reference.gd
## [/codeblock]


func _initialize() -> void:
	var error := ActionReference.write()
	if error != OK:
		printerr("Can't write %s: %s" % [ActionReference.PATH, error_string(error)])
	else:
		print("Wrote %s." % ActionReference.PATH)
	quit(error)

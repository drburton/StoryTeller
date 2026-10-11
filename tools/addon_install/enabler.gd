@tool
extends EditorPlugin
## Used by tools/check_addon_install.sh in a throwaway project. Does what a
## new user does in the editor: enables StoryTeller in Project Settings and
## presses Set Up Project in the Story tab. Prints what it finds, then quits.


func _enter_tree() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	EditorInterface.set_plugin_enabled("storyteller", true)
	await get_tree().create_timer(1.0).timeout
	print("CHECK enabled=%s" % EditorInterface.is_plugin_enabled("storyteller"))
	print("CHECK autoload=%s" % ProjectSettings.has_setting("autoload/Story"))
	var panel := EditorInterface.get_editor_main_screen().get_node_or_null("StoryEditor")
	print("CHECK story_tab=%s" % (panel != null))
	var setup: GDScript = load("res://addons/storyteller/editor/story_setup.gd")
	print("CHECK needs_setup=%s" % setup.needs_setup())
	var result: Dictionary = setup.run({"game_title": "Install Check"})
	setup.register(result["config_path"], result["scene_path"])
	print("CHECK setup_errors=%d" % result["errors"].size())
	for error in result["errors"]:
		print("CHECK setup_error: %s" % error)
	EditorInterface.get_resource_filesystem().scan()
	await get_tree().create_timer(3.0).timeout
	print("CHECK main_scene=%s" % ProjectSettings.get_setting("application/run/main_scene", ""))
	ProjectSettings.save()
	print("CHECK editor_done")
	get_tree().quit()

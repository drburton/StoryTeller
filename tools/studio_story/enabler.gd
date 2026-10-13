@tool
extends EditorPlugin
## Used by tools/check_studio_story.sh in a throwaway project. Does what a
## teacher does in the editor: enables StoryTeller and presses Open a
## Studio story in the Story tab with the student's story file. Makes the
## story's scene the main scene, prints what it finds, then quits.


func _enter_tree() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	EditorInterface.set_plugin_enabled("storyteller", true)
	await get_tree().create_timer(1.0).timeout
	print("CHECK enabled=%s" % EditorInterface.is_plugin_enabled("storyteller"))
	var panel := EditorInterface.get_editor_main_screen().get_node_or_null("StoryEditor")
	print("CHECK story_tab=%s" % (panel != null))
	if panel == null:
		get_tree().quit()
		return
	var tale: String = panel.open_studio_story(OS.get_environment("STUDIO_STORY_ZIP"))
	print("CHECK tale=%s" % tale)
	await get_tree().create_timer(3.0).timeout
	var scene := tale.get_base_dir().get_base_dir().path_join("main.tscn")
	print("CHECK scene=%s" % ResourceLoader.exists(scene))
	print("CHECK problems=%d" % panel.get_diagnostics().size())
	for diagnostic in panel.get_diagnostics():
		print("CHECK problem: %s" % diagnostic.message)
	ProjectSettings.set_setting("application/run/main_scene", scene)
	ProjectSettings.save()
	print("CHECK editor_done")
	get_tree().quit()

extends SceneTree
## Used by tools/check_addon_install.sh. Opens the main scene that Set Up
## Project made, presses New Game, checks that the first line shows in the
## dialogue box, then plays the starter tale to its end, picking the first
## option at each choice. Exits with 1 on any problem.

var _problems: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var story: Node = root.get_node_or_null("Story")
	if story == null:
		_finish(["The Story autoload is missing."])
		return
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene.is_empty() or not ResourceLoader.exists(main_scene):
		_finish(["No main scene."])
		return
	root.add_child(load(main_scene).instantiate())
	await create_timer(0.5).timeout
	var menus: StoryMenus = story.get_crew(&"Menus")
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	var dialogue: StoryDialogue = story.get_crew(&"Dialogue")
	director.runtime_error.connect(func(message: String, tale_name: String, line: int) -> void:
		_problems.append("%s:%d: %s" % [tale_name, line, message]))
	var lines: PackedStringArray = []
	director.line_started.connect(func(line: Dictionary) -> void: lines.append(str(line["text"])))
	director.choice_started.connect(func(_options: Array[Dictionary]) -> void:
		await process_frame
		dialogue.get_choice_menu("list").pick(0))
	var finished := [false]
	director.story_finished.connect(func() -> void: finished[0] = true)

	menus.start_new_game()
	await create_timer(1.0).timeout
	if lines.is_empty() or not dialogue.is_showing():
		_problems.append("New Game did not show a line in the dialogue box.")
	else:
		print("CHECK first_line=%s" % lines[0])
	(story.get_crew(&"Settings") as StorySettings).set_value("skip_unread", true)
	dialogue.skip_toggled = true
	for i in 300:
		if finished[0]:
			break
		await create_timer(0.1).timeout
	if not finished[0]:
		_problems.append("The starter tale did not finish. Lines seen: %s" % [lines])
	print("CHECK lines=%d" % lines.size())
	_finish(_problems)


func _finish(problems: PackedStringArray) -> void:
	for problem in problems:
		print("CHECK problem: %s" % problem)
	print("CHECK play_done")
	quit(1 if not problems.is_empty() else 0)

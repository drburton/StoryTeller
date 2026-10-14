extends SceneTree
## Run inside an exported game by tools/check_export.sh and
## tools/check_windows_export.ps1, the way a player first uses it: opens the
## main scene, presses New Game, checks that a line shows in the dialogue
## box, saves to a slot, starts again, loads the slot, and checks that the
## same line comes back. Exits with 1 on any problem.

const SLOT := "export_check"

var _problems: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var story: Node = root.get_node_or_null("Story")
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if story == null or main_scene.is_empty():
		_finish(["The Story autoload or the main scene is missing."])
		return
	root.add_child(load(main_scene).instantiate())
	await create_timer(0.5).timeout
	var menus: StoryMenus = story.get_crew(&"Menus")
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	var dialogue: StoryDialogue = story.get_crew(&"Dialogue")
	var saves: StorySaves = story.get_crew(&"Saves")
	director.runtime_error.connect(func(message: String, tale_name: String, line: int) -> void:
		_problems.append("%s:%d: %s" % [tale_name, line, message]))
	var lines: PackedStringArray = []
	director.line_started.connect(func(line: Dictionary) -> void: lines.append(str(line["text"])))

	menus.start_new_game()
	# The first line may follow a transition or a character walking in.
	for i in 50:
		if not lines.is_empty() and dialogue.is_showing():
			break
		await create_timer(0.1).timeout
	if lines.is_empty() or not dialogue.is_showing():
		_finish(["New Game did not show a line in the dialogue box."])
		return
	var first := lines[-1]
	print("CHECK first_line=%s" % first)
	if saves.save_slot(SLOT) != OK:
		_problems.append("Saving to a slot failed.")
	menus.start_new_game()
	await create_timer(0.5).timeout
	lines.clear()
	if saves.load_slot(SLOT) != OK:
		_problems.append("Loading the slot failed.")
	for i in 50:
		if first in lines:
			break
		await create_timer(0.1).timeout
	if first not in lines:
		_problems.append("Loading the slot did not show the saved line. Lines seen: %s" % [lines])
	else:
		print("CHECK loaded_line=%s" % first)
	saves.delete_slot(SLOT)
	_finish(_problems)


func _finish(problems: PackedStringArray) -> void:
	for problem in problems:
		print("CHECK problem: %s" % problem)
	print("Play check %s." % ("failed" if not problems.is_empty() else "passed"))
	var story: Node = root.get_node_or_null("Story")
	if story != null:
		story.shut_down()
	for child in root.get_children():
		if child != story:
			child.queue_free()
	await create_timer(0.5).timeout
	quit(1 if not problems.is_empty() else 0)

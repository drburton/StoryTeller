extends SceneTree
## Saves the Studio screenshots the textbook uses (docs/studio-design.md
## §13), so they can be made again for a new edition. Each shot in
## studio/lessons/screenshots.json starts from an empty set of stories and
## follows its steps:
## [codeblock]
## ["sample"]                    the home screen with the sample story
## ["new_story"] / ["lessons"]   a home screen dialog
## ["lesson", id, finished?]     opens a lesson's start or finished version
## ["template", id]              opens a new story from a template
## ["palette", group]            shows a group of blocks in the palette
## ["select", n]                 taps the nth block of the scene (from 1)
## ["scene", name]               shows another scene
## ["map"]                       opens the map of scenes
## ["hint", n]                   taps the nth ! on the blocks (from 1)
## ["add", kind]                 + Add in the library panel (cast, backdrops, sounds)
## ["play"]                      plays the story from the start
## [/codeblock]
## Run it with tools/studio_screenshots.sh, which draws on a screen.

const SHOTS := "res://studio/lessons/screenshots.json"
const LIBRARY := "user://screenshot_stories"
const SETTINGS := "user://screenshot_settings.json"

var _out := ""
var _problems: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: -s res://tools/studio_screenshots.gd -- <output folder> [shot names...]")
		quit(2)
		return
	_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	var only := args.slice(1)
	var shots = JSON.parse_string(FileAccess.get_file_as_string(SHOTS))
	if not shots is Array:
		printerr("Can't read " + SHOTS)
		quit(1)
		return
	for shot in shots:
		if only.is_empty() or shot["name"] in only:
			await _take(shot)
	StudioLibrary._remove_folder(LIBRARY)
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)
	for problem in _problems:
		printerr(problem)
	quit(1 if not _problems.is_empty() else 0)


func _take(shot: Dictionary) -> void:
	StudioLibrary._remove_folder(LIBRARY)
	var studio: Control = load("res://studio/studio.tscn").instantiate()
	studio.library_root = LIBRARY
	studio.settings_path = SETTINGS
	root.add_child(studio)
	await process_frame
	for step in shot["steps"]:
		if not await _step(studio, step):
			_problems.append("%s: can't do %s" % [shot["name"], step])
	await create_timer(1.0).timeout
	var path: String = _out.path_join(shot["name"] + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("Saved %s (%s)" % [path, shot.get("about", "")])
	if studio.story.is_playing():
		studio.story.stop_playing()
	root.remove_child(studio)
	studio.free()
	await process_frame


func _step(studio: Control, step: Array) -> bool:
	var editor: StudioBlockEditor = studio.story.editor
	match step[0]:
		"sample":
			studio.library.add_sample()
			studio.home.refresh()
		"new_story":
			studio.home.new_story()
		"lessons":
			studio.home.open_lessons()
		"lesson":
			return not studio.home.start_lesson(step[1], step.size() > 2 and step[2]).is_empty()
		"template":
			var text := StudioTemplates.template_text(step[1])
			if text.is_empty():
				return false
			studio.open_story(studio.library.create("My story", text, step[1]))
		"palette":
			editor.show_group(step[1])
		"select":
			var blocks := editor.get_blocks()
			if blocks.size() < int(step[1]):
				return false
			editor.select_block(blocks[int(step[1]) - 1])
		"scene":
			editor.select_scene(step[1])
		"map":
			studio.story.open_map()
		"hint":
			var badges := editor.find_children("*", "Button", true, false).filter(func(button: Node) -> bool: return button.has_meta("hint_badge"))
			if badges.size() < int(step[1]):
				return false
			badges[int(step[1]) - 1].pressed.emit()
		"add":
			studio.story.library_panel.open_add(step[1])
		"play":
			studio.story.play("start")
			await create_timer(1.5).timeout
		_:
			return false
	await process_frame
	return true

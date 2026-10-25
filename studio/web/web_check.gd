class_name StudioWebCheck
extends Node
## Checks the Studio's web version from inside the page, for
## tools/check_studio_web.sh. It runs only when the page address asks for
## it, in two visits:
## [codeblock]
## index.html?check=make     makes a story from a template, adds a starter
##                           character, and saves a copy of it
## index.html?check=reopen   after a reload: the story, its tale, and its
##                           pictures are still there, it opens in the
##                           blocks and the map, and it plays
## [/codeblock]
## Each visit prints "STUDIO CHECK <step> passed" or "... failed: <why>" to
## the browser console. The story it makes is called "Web Check".

const TITLE := "Web Check"

var studio: Control
var step := ""
var problems: PackedStringArray = []


func _init(app: Control, check_step: String) -> void:
	studio = app
	step = check_step


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await studio.get_tree().process_frame
	match step:
		"make":
			await make()
		"reopen":
			await reopen()
		_:
			problems.append("unknown step '%s'" % step)
	report()


## The id of the story this check makes, or "".
func story_id() -> String:
	for story in studio.library.list():
		if story.get("title", "") == TITLE:
			return story["id"]
	return ""


func make() -> void:
	var old := story_id()
	if not old.is_empty():
		studio.library.delete(old)
	var text := StudioTemplates.template_text("mystery")
	var id: String = studio.library.create(TITLE, text, "mystery")
	studio.open_story(id)
	await studio.get_tree().process_frame
	if not studio.story.library_panel.add_starter("cast", "robo"):
		problems.append("Robo could not be added")
	if not studio.library.has_asset(id, "backdrops", "library"):
		problems.append("the story's background was not copied in")
	var zip := StudioFiles.OUTBOX.path_join("web_check.zip")
	DirAccess.make_dir_recursive_absolute(StudioFiles.OUTBOX)
	if not studio.library.pack(id, zip) or FileAccess.get_file_as_bytes(zip).size() < 1000:
		problems.append("the story file could not be made")
	print("STUDIO CHECK storage kept: %s" % StudioWeb.storage_is_kept())
	# The browser saves the app's files in the background.
	await studio.get_tree().create_timer(3.0).timeout


func reopen() -> void:
	var id := story_id()
	if id.is_empty():
		problems.append("the story was gone after the page was loaded again")
		return
	if not studio.library.read_tale(id).contains("clues"):
		problems.append("the story's tale was not kept")
	for item in [["cast", "robo"], ["cast", "maya"], ["backdrops", "library"]]:
		if not studio.library.has_asset(id, item[0], item[1]):
			problems.append("the story's %s %s was not kept" % item)
	studio.open_story(id)
	await studio.get_tree().process_frame
	if studio.story.editor.get_blocks().is_empty():
		problems.append("the story did not open in the blocks")
	var map: StudioSceneMap = studio.story.open_map()
	if map.get_scenes().size() < 5:
		problems.append("the map shows %d scenes" % map.get_scenes().size())
	map.close()
	var lines: PackedStringArray = []
	studio.story.play("start")
	var story: Node = studio.get_node("/root/Story")
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	var dialogue: StoryDialogue = story.get_crew(&"Dialogue")
	director.line_started.connect(func(line: Dictionary) -> void: lines.append(str(line["text"])))
	# The first line may come before this hears of it, so the dialogue box
	# showing is what counts.
	for i in 50:
		if dialogue.is_showing():
			break
		await studio.get_tree().create_timer(0.1).timeout
	if not dialogue.is_showing():
		problems.append("the story did not play")
	elif not lines.is_empty():
		print("STUDIO CHECK first line: %s" % lines[0])
	await studio.get_tree().create_timer(1.0).timeout


func report() -> void:
	if problems.is_empty():
		print("STUDIO CHECK %s passed" % step)
	else:
		print("STUDIO CHECK %s failed: %s" % [step, "; ".join(problems)])

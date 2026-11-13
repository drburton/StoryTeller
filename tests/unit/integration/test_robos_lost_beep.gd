extends "res://tests/framework/story_test.gd"
## Keeps the "Robo's Lost Beep" example working: the tale checks cleanly and
## every route plays to the ending its choices earn.

const TaleImporter := preload("res://addons/storyteller/editor/tale_importer.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const FOLDER := "res://examples/robos_lost_beep"
const TALE := FOLDER + "/tales/robos_lost_beep.tale"
const CONFIG := FOLDER + "/story_config.tres"

## Picks for each route, and the beat each one ends in.
const ROUTES := [
	[[0, 0, 2], "super_helpers"],
	[[1, 0, 2], "super_helpers"],
	[[0, 0, 0], "happy_again"],
	[[1, 1, 0], "happy_again"],
	[[0, 1, 1], "happy_again"],
	[[1, 1, 2], "happy_again"],
]


func test_tale_has_no_diagnostics() -> void:
	var context := TaleImporter._make_context(TALE, "robos_lost_beep")
	var result := TaleCompiler.build(FileAccess.get_file_as_string(TALE), "robos_lost_beep", context)
	assert_eq(result["diagnostics"].size(), 0, str(result["diagnostics"]))


func test_tale_uses_the_config_next_to_it() -> void:
	var story := preload("res://addons/storyteller/core/story.gd")
	assert_eq(story.config_for_tale(TALE).resource_path, CONFIG)
	assert_eq(story.config_for_tale("examples/robos_lost_beep/tales/robos_lost_beep.tale").resource_path, CONFIG, "relative paths work too")
	assert_eq(story.config_for_tale("res://demo/tales/welcome.tale").resource_path, story.load_config().resource_path)
	assert_eq(story.config_for_tale("res://examples/robos_lost_beep/x.tale").resource_path, story.load_config().resource_path,
		"a config only owns its own tales folder")


func test_every_route_reaches_its_ending() -> void:
	var seen := {}
	for route in ROUTES:
		var picks: Array = route[0]
		var run := await _play_tale(picks)
		assert_eq(run["errors"], [], str(picks))
		assert_eq(run["offered"].map(func(options: Array) -> int: return options.size()), [2, 2, 3], str(picks))
		assert_eq(run["lines"].back(), "The end.")
		var ending := "Maya: Robo said our names!" if route[1] == "super_helpers" else "Sam: Good luck with that!"
		assert_has(run["lines"], ending, str(picks))
		for line in run["lines"]:
			seen[line] = true
	assert_has(seen, "Maya: No button. But look, little paw prints!", "the slide route")
	assert_has(seen, "Sam: No button. Who left these little paw prints?", "the swings route")
	assert_has(seen, "Sam: My lost marble! I looked for it all week.", "the sandbox route")


## Plays the tale with [param picks]. Returns {"errors", "lines", "offered"}.
func _play_tale(picks: Array) -> Dictionary:
	var config := (load(CONFIG) as StoryConfig).duplicate()
	config.save_folder = "user://test_robo_saves"
	config.settings_path = "user://test_robo_settings.cfg"
	config.return_to_title = false
	var story: Node = track(preload("res://addons/storyteller/core/story.gd").new())
	story.start(config)
	tree.root.add_child(story)
	await tree.process_frame
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	var presenter: ScriptedPresenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	director.presenter = presenter
	(story.get_crew(&"Settings") as StorySettings).set_value("skip_unread", true)
	(story.get_crew(&"Dialogue") as StoryDialogue).skip_toggled = true
	var errors := []
	director.runtime_error.connect(func(message: String, tale_name: String, line: int) -> void:
		errors.append("%s:%d: %s" % [tale_name, line, message]))
	presenter.picks = picks.duplicate()
	await director.play("robos_lost_beep")
	for file_name in DirAccess.get_files_at("user://test_robo_saves"):
		DirAccess.remove_absolute("user://test_robo_saves".path_join(file_name))
	DirAccess.remove_absolute("user://test_robo_settings.cfg")
	return {"errors": errors, "lines": presenter.lines, "offered": presenter.offered}


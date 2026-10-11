extends "res://tests/framework/story_test.gd"
## Interruption tests: the demo is saved at points spread through it, each
## save is loaded, and the story must go on exactly as it did the first
## time. Rewinding one step at the same points must show the line before
## and then go on the same way.

const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const SAVE_FOLDER := "user://test_interruption_saves"
## Picks are option positions, as in test_demo.gd.
const PICKS := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0]
## How many points to interrupt at.
const POINTS := 8

var story: Node
var director: TaleDirector
var presenter: ScriptedPresenter


func after_each() -> void:
	if DirAccess.dir_exists_absolute(SAVE_FOLDER):
		for file_name in DirAccess.get_files_at(SAVE_FOLDER):
			DirAccess.remove_absolute(SAVE_FOLDER.path_join(file_name))
	DirAccess.remove_absolute("user://test_interruption_settings.cfg")


func _start() -> void:
	var config := (load("res://demo/story_config.tres") as StoryConfig).duplicate()
	config.save_folder = SAVE_FOLDER
	config.settings_path = "user://test_interruption_settings.cfg"
	config.return_to_title = false
	config.autosave_on_choice = false
	story = track(preload("res://addons/storyteller/core/story.gd").new())
	story.start(config)
	tree.root.add_child(story)
	await tree.process_frame
	director = story.get_crew(&"TaleDirector")
	presenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	director.presenter = presenter
	(story.get_crew(&"Settings") as StorySettings).set_value("skip_unread", true)
	(story.get_crew(&"Dialogue") as StoryDialogue).skip_toggled = true
	_answer_name()


## Types "Robin" into the name prompt whenever it opens.
func _answer_name() -> void:
	var menus: StoryMenus = story.get_crew(&"Menus")
	while is_instance_valid(story):
		var dialog: TextInputDialog = menus._screens.get("text_input")
		if dialog != null and dialog.visible:
			dialog._edit.text = "Robin"
			dialog._submit()
		await tree.process_frame


## Plays the whole demo once, saving to slot "at_N" when line N shows, for
## each N in [param points]. Returns the lines and, for each point, the
## picks still to come.
func _play_and_save(points: Array) -> Dictionary:
	var remaining := {}
	var saves: StorySaves = story.get_crew(&"Saves")
	presenter.on_line = func(_line: Dictionary) -> void:
		var index := presenter.lines.size()
		if index in points:
			saves.save_slot("at_%d" % index)
			remaining[index] = presenter.picks.duplicate()
	presenter.picks = PICKS.duplicate()
	story.clear_all()
	await director.play("welcome")
	presenter.on_line = Callable()
	return {"lines": presenter.lines.duplicate(), "remaining": remaining}


func _points(line_count: int) -> Array:
	var points := []
	for i in POINTS:
		points.append(1 + i * (line_count - 2) / (POINTS - 1))
	return points


func test_loading_a_save_continues_the_same_way() -> void:
	await _start()
	var first := await _play_and_save([])
	var lines: Array = first["lines"]
	assert_true(lines.size() > 50, "the demo has %d lines" % lines.size())
	var points := _points(lines.size())
	presenter.lines.clear()
	presenter.line_data.clear()
	var second := await _play_and_save(points)
	assert_eq(second["lines"], lines, "saving does not change the story")
	var saves: StorySaves = story.get_crew(&"Saves")
	for point in points:
		presenter.lines.clear()
		presenter.picks = second["remaining"][point].duplicate()
		assert_eq(saves.load_slot("at_%d" % point), OK)
		while director.is_playing():
			await tree.process_frame
		assert_eq(presenter.lines, lines.slice(point), "loading at line %d" % point)


func test_rewinding_one_step_shows_the_line_before() -> void:
	await _start()
	# Choices offered before each line: rewinding just after a choice goes
	# back to the choice, so those lines are skipped.
	var choices_before := {}
	director.choice_started.connect(func(_options: Array[Dictionary]) -> void: choices_before["now"] = choices_before.get("now", 0) + 1)
	director.line_started.connect(func(_line: Dictionary) -> void: choices_before[presenter.lines.size()] = choices_before.get("now", 0))
	var first := await _play_and_save([])
	var lines: Array = first["lines"]
	var rewind: StoryRewind = story.get_crew(&"Rewind")
	# Later runs keep adding to choices_before, so keep the first run's.
	var first_choices := choices_before.duplicate()
	# Not the last point: the story ends before a rewind there could run.
	for start_point in _points(lines.size()).slice(1, -1):
		var point: int = start_point
		while point < lines.size() and first_choices.get(point) != first_choices.get(point - 1):
			point += 1
		presenter.lines.clear()
		var done := {"rewound": false}
		presenter.on_line = func(_line: Dictionary) -> void:
			if presenter.lines.size() == point and not done["rewound"]:
				done["rewound"] = true
				assert_true(rewind.can_rewind(), "can rewind at line %d" % point)
				rewind.rewind.call_deferred()
		presenter.picks = PICKS.duplicate()
		story.clear_all()
		await director.play("welcome")
		presenter.on_line = Callable()
		assert_true(done["rewound"])
		var expected := lines.slice(0, point + 1)
		expected.append_array(lines.slice(point - 1))
		assert_eq(presenter.lines.size(), expected.size(), "rewinding at line %d shows the line before again" % point)
		assert_eq(presenter.lines.slice(point + 1, point + 4), expected.slice(point + 1, point + 4), "and goes on the same way (line %d)" % point)

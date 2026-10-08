extends "res://tests/framework/story_test.gd"
## Tests for rewinding and the history log.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const SAVE_FOLDER := "user://test_rewind_saves"

var story: Node
var director: TaleDirector
var rewind: StoryRewind
var history: StoryHistory
var presenter: ScriptedPresenter


func before_each() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StorySaves, StoryRewind, StoryHistory]
	config.save_folder = SAVE_FOLDER
	config.autosave_on_choice = false
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	rewind = story.get_crew(&"Rewind")
	history = story.get_crew(&"History")
	presenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	director.presenter = presenter
	await tree.process_frame


func after_each() -> void:
	for file_name in DirAccess.get_files_at(SAVE_FOLDER):
		DirAccess.remove_absolute(SAVE_FOLDER.path_join(file_name))


func _add(source: String) -> void:
	var result := TaleCompiler.build(source, "main", director.make_check_context("main"))
	for diagnostic in result["diagnostics"]:
		fail(str(diagnostic))
	director.add_tale(result["tale"])


## Plays "main" until it ends, including any rewinds and loads on the way.
func _play_to_end() -> void:
	director.play("main")
	while director.is_playing():
		await tree.process_frame


func _texts() -> Array:
	return history.get_entries().map(func(entry: Dictionary) -> String: return entry["text"])


func test_history_records_lines() -> void:
	_add("const GUIDE := \"Ada\"\nbeat start:\n\t\"One.\"\n\tGUIDE: \"Two.\"\n")
	var pending := []
	presenter.on_line = func(_line: Dictionary) -> void: pending.append(history.get_entries().back()["pending"])
	await _play_to_end()
	assert_eq(_texts(), ["One.", "Two."])
	assert_eq(history.get_entries()[1]["speaker"], "Ada")
	assert_eq(pending, [true, true], "the line on screen is pending")
	assert_false(history.get_entries()[1]["pending"])


func test_rewind_goes_back_one_line_with_state() -> void:
	_add("var n := 0\nbeat start:\n\tn += 1\n\t\"A {n}\"\n\tn += 1\n\t\"B {n}\"\n\tn += 1\n\t\"C {n}\"\n")
	var rewound := [false]
	presenter.on_line = func(line: Dictionary) -> void:
		if line["text"] == "C 3" and not rewound[0]:
			rewound[0] = true
			rewind.rewind.call_deferred()
	await _play_to_end()
	assert_eq(presenter.lines, ["A 1", "B 2", "C 3", "B 2", "C 3"], "variables went back too")
	assert_eq(_texts(), ["A 1", "B 2", "C 3"], "history has no duplicates")


func test_rewind_back_to_a_choice() -> void:
	_add("beat start:\n\tchoose:\n\t\t\"Left\": \"Went left.\"\n\t\t\"Right\": \"Went right.\"\n\t\"End.\"\n")
	presenter.picks = ["Left", "Right"]
	var rewound := [false]
	presenter.on_line = func(line: Dictionary) -> void:
		if line["text"] == "Went left." and not rewound[0]:
			rewound[0] = true
			rewind.rewind.call_deferred()
	await _play_to_end()
	assert_eq(presenter.offered.size(), 2, "the choice was offered again")
	assert_eq(presenter.lines, ["Went left.", "Went right.", "End."])


func test_no_rewind_is_a_barrier() -> void:
	_add("beat start:\n\t\"Before.\"\n\t@no_rewind\n\t\"Point of no return.\"\n\t\"After.\"\n")
	var results := []
	presenter.on_line = func(line: Dictionary) -> void:
		if line["text"] == "After.":
			results.append(rewind.get_available_steps())
	await _play_to_end()
	assert_eq(results, [1], "only back to the barrier line, not before it")


func test_rewind_limits() -> void:
	_add("beat start:\n\t\"Only line.\"\n")
	var results := []
	presenter.on_line = func(_line: Dictionary) -> void: results.append(rewind.rewind())
	await _play_to_end()
	assert_eq(results, [false], "nothing to rewind to")
	rewind.depth = 2
	_add("beat start:\n\t\"1\"\n\t\"2\"\n\t\"3\"\n\t\"4\"\n")
	presenter.on_line = func(_line: Dictionary) -> void: results.append(rewind.get_available_steps())
	await _play_to_end()
	assert_eq(results.slice(1), [0, 1, 2, 2], "depth caps the steps")


func test_history_survives_save_and_load_without_duplicates() -> void:
	_add("beat start:\n\t\"One.\"\n\t\"Two.\"\n\t\"Three.\"\n")
	var saves: StorySaves = story.get_crew(&"Saves")
	var loaded := [false]
	presenter.on_line = func(line: Dictionary) -> void:
		if line["text"] == "Two." and not saves.has_slot("h"):
			saves.save_slot("h")
		elif line["text"] == "Three." and not loaded[0]:
			loaded[0] = true
			saves.load_slot.call_deferred("h")
	await _play_to_end()
	assert_eq(_texts(), ["One.", "Two.", "Three."])

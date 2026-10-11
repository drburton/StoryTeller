extends "res://tests/framework/story_test.gd"
## Tests for the debug console and live reload of edited tales.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const TALE_PATH := "user://test_reload/main.tale"
const SOURCE := """var trust := 1

beat start:
	"One."
	"Two."
	"Three."

beat other:
	"Elsewhere {trust}."
"""

var story: Node
var director: TaleDirector
var console: StoryConsole
var presenter: ScriptedPresenter
var output: Array[String] = []


func before_each() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryConsole]
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	director.live_reload = false
	console = story.get_crew(&"Console")
	presenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	director.presenter = presenter
	output.clear()
	console.printed.connect(func(text: String) -> void: output.append(text))
	_write(SOURCE)
	await tree.process_frame
	var result := TaleCompiler.build(SOURCE, "main", director.make_check_context("main"), TALE_PATH)
	director.add_tale(result["tale"])


func after_each() -> void:
	if FileAccess.file_exists(TALE_PATH):
		DirAccess.remove_absolute(TALE_PATH)


func _write(source: String) -> void:
	DirAccess.make_dir_recursive_absolute(TALE_PATH.get_base_dir())
	var file := FileAccess.open(TALE_PATH, FileAccess.WRITE)
	file.store_string(source)
	file.close()


func test_position_variables_and_expressions() -> void:
	var seen := {}
	presenter.on_line = func(line: Dictionary) -> void:
		if line["text"] == "Two.":
			seen.merge(director.get_position())
	await director.play("main")
	assert_eq(seen, {"tale": "main", "beat": "start", "line": 5})
	assert_eq(director.get_position(), {}, "nothing plays afterwards")


func test_console_sets_and_shows_values() -> void:
	presenter.on_line = func(line: Dictionary) -> void:
		if line["text"] == "One.":
			_console_session.call_deferred()
	await director.play("main")
	await tree.process_frame
	assert_has(output, "trust = 3")
	assert_has(output, "6")
	assert_has(output, "\"main\"")
	assert_true(output.any(func(text: String) -> bool: return text.begins_with("Expected")), "parse errors are shown: %s" % [output])


func _console_session() -> void:
	await console.run_command("trust = 3")
	await console.run_command("trust * 2")
	await console.run_command("str(\"main\")")
	await console.run_command("trust +")


func test_console_jumps_to_a_beat() -> void:
	presenter.on_line = func(line: Dictionary) -> void:
		if line["text"] == "One.":
			console.run_command.call_deferred("jump other")
	await director.play("main")
	assert_eq(presenter.lines, ["One.", "Elsewhere 1."])
	assert_has(output, "Jumped to main.other.")


func test_console_reports_unknown_beats_and_help() -> void:
	await console.run_command("jump main.nowhere")
	assert_has(output, "Tale 'main' has no beat 'nowhere'.")
	await console.run_command("help")
	assert_true(output.back().begins_with("Commands:"))


func test_console_toggles_with_its_key() -> void:
	assert_false(console.is_open())
	console.toggle()
	assert_true(console.is_open())
	assert_true(InputMap.has_action("story_console"))
	console.toggle()
	assert_false(console.is_open())


func test_reload_continues_at_the_same_line() -> void:
	var edited := SOURCE.replace("\"Two.\"", "@id(\"two\") \"Two, edited.\"").replace("\"One.\"", "\"One.\"\n\t\"Inserted.\"")
	var reloaded := []
	director.tale_reloaded.connect(func(tale_name: String) -> void: reloaded.append(tale_name))
	presenter.on_line = func(line: Dictionary) -> void:
		if line["text"] == "Two." and reloaded.is_empty():
			_write(edited)
			director.reload_tale.call_deferred("main")
	await director.play("main")
	assert_eq(reloaded, ["main"])
	assert_eq(presenter.lines, ["One.", "Two.", "Two, edited.", "Three."], "the edited line is found from the line after it")


func test_reload_keeps_old_version_on_errors() -> void:
	_write("beat start:\n\tif:\n")
	var problem: String = await director.reload_tale("main")
	assert_true(problem.begins_with(TALE_PATH + ":2:"), problem)
	assert_eq(director.get_tale("main").get_beat_start("other") >= 0, true)


func test_reload_adds_new_variables() -> void:
	await director.play("main", "other")
	_write(SOURCE.replace("var trust := 1", "var trust := 1\nvar mood := \"calm\""))
	assert_eq(await director.reload_tale("main"), "")
	assert_eq(director.get_tale_var("main", "mood"), [true, "calm"])
	assert_eq(director.get_tale_var("main", "trust"), [true, 1])


func test_check_for_edits_notices_changed_files() -> void:
	var reloaded := []
	director.tale_reloaded.connect(func(tale_name: String) -> void: reloaded.append(tale_name))
	await director.check_for_edits()
	assert_eq(reloaded, [], "the first check only records times")
	director._source_times[TALE_PATH] = 0
	await director.check_for_edits()
	assert_eq(reloaded, ["main"])


func test_map_pc_after_deleting_the_current_line() -> void:
	var old: Tale = TaleCompiler.build("beat start:\n\t\"A\"\n\t\"B\"\n\t\"C\"\n", "t")["tale"]
	var new: Tale = TaleCompiler.build("beat start:\n\t\"A\"\n\t\"C\"\n", "t")["tale"]
	assert_eq(new.texts[new.instructions[TaleDirector._map_pc(old, new, "start", 1)]["id"]], "C")


func test_map_pc_by_id_and_missing_beat() -> void:
	var old: Tale = TaleCompiler.build("beat start:\n\t@id(\"a\") \"A\"\n\t@id(\"b\") \"B\"\n", "t")["tale"]
	var new: Tale = TaleCompiler.build("beat start:\n\t\"New\"\n\t@id(\"b\") \"B changed\"\n\t@id(\"a\") \"A\"\n", "t")["tale"]
	assert_eq(new.instructions[TaleDirector._map_pc(old, new, "start", 1)]["id"], "b")
	assert_eq(TaleDirector._map_pc(old, new, "gone", 0), -1)

extends "res://tests/framework/story_test.gd"
## Tests for backdrops, transitions, props, and the camera.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const FIXTURES := "res://tests/fixtures/stage"

var story: Node
var director: TaleDirector
var stage: StoryStage
var presenter: ScriptedPresenter
var errors: Array[String] = []


func before_each() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage]
	config.cast_folder = "res://tests/fixtures/cast"
	config.backdrop_folder = FIXTURES.path_join("backdrops")
	config.prop_folder = FIXTURES.path_join("props")
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	stage = story.get_crew(&"Stage")
	stage.transition_folder = FIXTURES.path_join("transitions")
	presenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	director.presenter = presenter
	errors.clear()
	director.runtime_error.connect(func(message: String, _tale: String, line: int) -> void:
		errors.append("%d: %s" % [line, message]))
	await tree.process_frame


func _play(source: String) -> void:
	var result := TaleCompiler.build(source, "main", director.make_check_context("main"))
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail(str(diagnostic))
	if result["tale"]:
		director.add_tale(result["tale"])
		await director.play("main")


func test_backdrop_by_name_and_color() -> void:
	await _play("beat start:\n\tbackdrop(\"day\", time = 0)\n\t\"one\"\n\tbackdrop(Color.BLACK, transition = \"none\")\n\t\"two\"\n")
	assert_eq(errors, [])
	assert_eq(stage.backdrop_view.current, Color.BLACK)


func test_backdrop_transition_runs_over_time() -> void:
	_play("beat start:\n\tbackdrop(\"night\", transition = \"dissolve\", time = 0.2)\n\t\"after\"\n")
	await tree.process_frame
	await tree.process_frame
	var progress := stage.backdrop_view.get_progress()
	assert_true(progress > 0.0 and progress < 1.0, "midway: %s" % progress)
	while presenter.lines.is_empty():
		await tree.process_frame
	assert_eq(stage.backdrop_view.get_progress(), 1.0, "line waited for the transition")
	assert_eq(stage.backdrop_view.current, "night")


func test_every_transition_name_works() -> void:
	var source := "beat start:\n"
	for transition in BackdropView.TRANSITIONS:
		source += "\tbackdrop(\"day\", transition = \"%s\", time = 0.01)\n" % transition
	source += "\tbackdrop(\"night\", transition = \"dissolve\", time = 0.01, mask = \"ramp\")\n\t\"done\"\n"
	await _play(source)
	assert_eq(errors, [])
	assert_eq(presenter.lines, ["done"])


func test_missing_assets_are_reported() -> void:
	await _play("beat start:\n\tbackdrop(\"moon\")\n\tprop(\"sword\")\n\tbackdrop(\"day\", mask = \"zigzag\")\n\t\"still going\"\n")
	assert_eq(presenter.lines, ["still going"])
	assert_eq(errors.size(), 3)
	assert_true(errors[0].begins_with("2: Backdrop 'moon' was not found"))
	assert_true(errors[1].begins_with("3: Prop 'sword' was not found"))
	assert_true(errors[2].begins_with("4: Transition mask 'zigzag' was not found"))


func test_props() -> void:
	await _play("beat start:\n\tprop(\"lamp\", at = Vector2(0.2, 0.5), time = 0)\n\t\"lit\"\n")
	assert_eq(stage.get_prop_names(), PackedStringArray(["lamp"]))
	var lamp: Node2D = stage.prop_layer.get_node("lamp")
	var size := lamp.get_viewport_rect().size
	assert_true(lamp.position.is_equal_approx(Vector2(size.x * 0.2, size.y * 0.5)))
	await _play("beat start:\n\tawait hide_prop(\"lamp\", time = 0.05)\n\t\"dark\"\n")
	assert_eq(stage.get_prop_names(), PackedStringArray())


func test_camera_from_tales() -> void:
	await _play("beat start:\n\tawait camera.zoom(2.0, time = 0.05)\n\tcamera.pan(Vector2(0.1, 0), time = 0)\n\t\"{camera.zoom_level}\"\n")
	assert_eq(presenter.lines, ["2.0"])
	var transform := stage.cast_layer.transform
	var size := stage.get_viewport().get_visible_rect().size
	assert_true(transform.get_scale().is_equal_approx(Vector2(2, 2)))
	var center_on_screen := transform * (size / 2.0)
	assert_true(center_on_screen.is_equal_approx(size / 2.0 - Vector2(0.1 * size.x * 2.0, 0)), "pan moves the view left")
	assert_eq(stage.backdrop_layer.transform, transform, "all stage layers move together")


func test_shake_returns_to_rest() -> void:
	await _play("beat start:\n\tawait shake(1.0, time = 0.1)\n\t\"done\"\n")
	assert_eq(stage.cast_layer.transform, Transform2D.IDENTITY)


func test_skipping_finishes_transitions_at_once() -> void:
	director.skipping = true
	var started := Time.get_ticks_msec()
	await _play("beat start:\n\tawait backdrop(\"night\", time = 5)\n\tawait camera.zoom(3, time = 5)\n\tawait shake(1, time = 5)\n\t\"done\"\n")
	assert_true(Time.get_ticks_msec() - started < 1000)
	assert_eq(stage.camera.zoom_level, 3.0)


func test_capture_and_restore_scenery() -> void:
	await _play("beat start:\n\tbackdrop(\"night\", time = 0)\n\tprop(\"lamp\", time = 0)\n\tcamera.zoom(1.5, time = 0)\n\t\"x\"\n")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(stage.capture()))
	stage.clear()
	assert_eq(stage.backdrop_view.current, Color.BLACK)
	stage.restore(saved)
	assert_eq(stage.backdrop_view.current, "night")
	assert_eq(stage.get_prop_names(), PackedStringArray(["lamp"]))
	assert_eq(stage.camera.zoom_level, 1.5)

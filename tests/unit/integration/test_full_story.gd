extends "res://tests/framework/story_test.gd"
## Runs tales through a complete Story (director, stage, audio) and checks
## preloading and saving and resuming the whole state.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")

const SOURCE := """var visits := 0

beat start:
	backdrop("day", time = 0)
	music("theme", fade = 0)
	robin.enter("neutral", at = LEFT, time = 0)
	visits += 1
	robin (smile): "First line."
	camera.zoom(1.5, time = 0)
	robin.move_to(RIGHT, time = 0)
	backdrop("night", time = 0)
	robin: "Second line, visit {visits}."
	"Third line."
"""


func _make_story() -> Array:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage, StoryAudio]
	config.cast_folder = "res://tests/fixtures/cast"
	config.backdrop_folder = "res://tests/fixtures/stage/backdrops"
	config.audio_folder = "res://tests/fixtures/audio"
	var story: Node = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	var presenter: ScriptedPresenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	director.presenter = presenter
	await tree.process_frame
	var result := TaleCompiler.build(SOURCE, "full", director.make_check_context("full"))
	for diagnostic in result["diagnostics"]:
		fail("unexpected: %s" % diagnostic)
	director.add_tale(result["tale"])
	return [story, presenter]


func test_beat_assets_are_requested_when_the_beat_starts() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, preload("res://tests/fixtures/recording_loader.gd")]
	var story: Node = track(StoryScript.new())
	story.start(config)
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	var recorder: Node = story.get_crew(&"Recorder")
	var tale := TaleCompiler.compile(TaleParser.parse("var name := \"x\"\nbeat start:\n\tbackdrop(\"day\")\n\tmusic(\"theme\", fade = 0)\n\tbackdrop(name)\n\t@voice(\"hello\") \"Hi.\"\n\tjump other\nbeat other:\n\tsound(\"bell\")\n"), "t")
	director.add_tale(tale)
	director._enter_beat(tale, "start")
	assert_eq(recorder.requests, ["backdrop:day", "music:theme", "voice:hello"], "only literal names in this beat")


func test_save_mid_story_and_resume_everything() -> void:
	var made := await _make_story()
	var story: Node = made[0]
	var presenter: ScriptedPresenter = made[1]
	var saved := {}
	presenter.on_line = func(line: Dictionary) -> void:
		if line["text"] == "Second line, visit 1." and saved.is_empty():
			saved.merge(JSON.parse_string(JSON.stringify(story.capture())))
	await story.play("full")
	assert_eq(presenter.lines, ["Robin: First line.", "Robin: Second line, visit 1.", "Third line."])

	var again := await _make_story()
	var restored: Node = again[0]
	var second_presenter: ScriptedPresenter = again[1]
	restored.restore(saved)
	var stage: StoryStage = restored.get_crew(&"Stage")
	var audio: StoryAudio = restored.get_crew(&"Audio")
	assert_eq(stage.backdrop_view.current, "night")
	assert_eq(stage.camera.zoom_level, 1.5)
	assert_eq(stage.get_cast("robin").stage_position, TaleDirector.POSITIONS["RIGHT"])
	assert_eq(stage.get_cast("robin").mood, "smile")
	assert_eq(audio.get_music_track(), "theme")
	await restored.get_crew(&"TaleDirector").resume()
	assert_eq(second_presenter.lines, ["Robin: Second line, visit 1.", "Third line."], "shows the saved line again, then continues")

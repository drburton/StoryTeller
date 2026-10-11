extends "res://tests/framework/story_test.gd"
## Tests for dialogue box portraits: which picture a line gets, and the
## classic box showing it.

const StoryScript := preload("res://addons/storyteller/core/story.gd")

var story: Node
var director: TaleDirector
var stage: StoryStage
var dialogue: StoryDialogue


func before_each() -> void:
	story = track(StoryScript.new())
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage, StoryAudio, StorySettings, StoryDialogue]
	config.cast_folder = "res://tests/fixtures/cast"
	config.settings_path = "user://test_portrait_settings.cfg"
	config.text_speed = 0.0
	config.dialogue_box_transition = "none"
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	stage = story.get_crew(&"Stage")
	dialogue = story.get_crew(&"Dialogue")
	await tree.process_frame


func after_each() -> void:
	DirAccess.remove_absolute("user://test_portrait_settings.cfg")


func _file(texture: Texture2D) -> String:
	return texture.resource_path.get_file() if texture != null else ""


func test_portraits_follow_the_mood() -> void:
	assert_null(stage.get_portrait("robin", "smile"), "no portrait folder, no portrait")
	var profile := stage.get_profile("robin")
	profile.portrait_folder = "res://tests/fixtures/cast/robin"
	profile.default_mood = "neutral"
	assert_eq(_file(stage.get_portrait("robin", "smile")), "smile.png")
	assert_eq(_file(stage.get_portrait("robin", "furious")), "neutral.png", "unknown moods use the default mood's")
	assert_null(stage.get_portrait("nobody"))
	stage.get_cast("robin").mood = "smile"
	assert_eq(_file(stage.get_portrait("robin")), "smile.png", "no mood: the current one")


## Plays [param line_source] and returns the classic box's portrait while
## the line shows.
func _portrait_shown(line_source: String) -> TextureRect:
	var result := TaleCompiler.build("beat start:\n\t%s\n\t\"Next.\"\n" % line_source, "t", director.make_check_context("t"))
	director.add_tale(result["tale"])
	director.play("t")
	for i in 3:
		await tree.process_frame
	var portrait: TextureRect = dialogue.dialogue_box.get_node("Panel").find_child("Portrait", true, false)
	return portrait


func test_the_classic_box_shows_the_speakers_portrait() -> void:
	stage.get_profile("robin").portrait_folder = "res://tests/fixtures/cast/robin"
	var portrait := await _portrait_shown("robin (smile): \"Hello.\"")
	assert_true(portrait.visible, "shown beside a character's line")
	assert_eq(_file(portrait.texture), "smile.png")
	director.stop()
	portrait = await _portrait_shown("\"Narration.\"")
	assert_false(portrait.visible, "hidden for narration")
	director.stop()


func test_portraits_can_show_only_off_stage() -> void:
	var profile := stage.get_profile("robin")
	profile.portrait_folder = "res://tests/fixtures/cast/robin"
	profile.portrait_off_stage_only = true
	assert_not_null(stage.get_line_portrait("robin", "smile"), "not entered yet")
	stage.get_cast("robin").enter("smile", Vector2(0.5, 0.0), 0.0)
	assert_null(stage.get_line_portrait("robin", "smile"), "on stage")
	assert_not_null(stage.get_portrait("robin", "smile"), "get_portrait ignores the stage")

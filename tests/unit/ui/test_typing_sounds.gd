extends "res://tests/framework/story_test.gd"
## Tests for typing sounds: the default, a character's own, voiced lines,
## and the player's setting.

const StoryScript := preload("res://addons/storyteller/core/story.gd")

var story: Node
var director: TaleDirector
var dialogue: StoryDialogue
var audio: StoryAudio


func before_each() -> void:
	story = track(StoryScript.new())
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage, StoryAudio, StorySettings, StoryDialogue]
	config.cast_folder = "res://tests/fixtures/cast"
	config.audio_folder = "res://tests/fixtures/audio"
	config.settings_path = "user://test_typing_settings.cfg"
	config.text_speed = 60.0
	config.dialogue_box_transition = "none"
	config.typing_sound = "tick"
	config.typing_sound_every = 1
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	dialogue = story.get_crew(&"Dialogue")
	audio = story.get_crew(&"Audio")
	await tree.process_frame


func after_each() -> void:
	DirAccess.remove_absolute("user://test_typing_settings.cfg")


## Shows [param line_source] until it has typed for a while, then returns
## the file name of the last typing sound, or "".
func _typing_sound_of(line_source: String) -> String:
	var result := TaleCompiler.build("beat start:\n\t%s\n" % line_source, "t", director.make_check_context("t"))
	director.add_tale(result["tale"])
	director.play("t")
	for i in 20:
		await tree.process_frame
	var stream := audio.get_blip_stream()
	director.stop()
	return stream.resource_path.get_file() if stream != null else ""


func test_lines_type_with_the_default_sound() -> void:
	assert_eq(await _typing_sound_of("\"A long enough line to type for a while.\""), "tick.wav")


func test_a_character_can_have_their_own_sound() -> void:
	(story.get_crew(&"Stage") as StoryStage).get_profile("robin").typing_sound = "bell"
	assert_eq(await _typing_sound_of("robin: \"A long enough line to type for a while.\""), "bell.wav")


func test_voiced_lines_and_the_setting_keep_quiet() -> void:
	assert_eq(await _typing_sound_of("@voice(\"bell\") \"A long enough line to type for a while.\""), "", "the voice speaks instead")
	(story.get_crew(&"Settings") as StorySettings).set_value("typing_sounds", false)
	assert_eq(await _typing_sound_of("\"A long enough line to type for a while.\""), "", "players can turn them off")

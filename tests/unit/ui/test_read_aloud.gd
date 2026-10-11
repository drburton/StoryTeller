extends "res://tests/framework/story_test.gd"
## Tests for "Read lines aloud": what is spoken for lines and choices, and
## what stays quiet. The system voice is replaced by a recorder.

const StoryScript := preload("res://addons/storyteller/core/story.gd")

var story: Node
var director: TaleDirector
var dialogue: StoryDialogue
var spoken: Array[String] = []


func before_each() -> void:
	story = track(StoryScript.new())
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage, StoryAudio, StorySettings, StoryDialogue]
	config.cast_folder = "res://tests/fixtures/cast"
	config.settings_path = "user://test_read_aloud_settings.cfg"
	config.text_speed = 0.0
	config.dialogue_box_transition = "none"
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	dialogue = story.get_crew(&"Dialogue")
	spoken.clear()
	dialogue.speak = func(text: String) -> void: spoken.append(text)
	await tree.process_frame


func after_each() -> void:
	DirAccess.remove_absolute("user://test_read_aloud_settings.cfg")


func _play(source: String, frames := 4) -> void:
	var result := TaleCompiler.build(source, "t", director.make_check_context("t"))
	director.add_tale(result["tale"])
	director.play("t")
	for i in frames:
		await tree.process_frame


func test_lines_are_read_with_the_speaker_once_turned_on() -> void:
	await _play("beat start:\n\trobin: \"[b]Hello[/b] there.\"\n")
	assert_eq(spoken, [] as Array[String], "off by default")
	director.stop()
	(story.get_crew(&"Settings") as StorySettings).set_value("read_aloud", true)
	await _play("beat start:\n\trobin: \"[b]Hello[/b] there.\"\n")
	assert_eq(spoken, ["Robin: Hello there."] as Array[String], "tags are left out")
	director.stop()
	spoken.clear()
	await _play("beat start:\n\t\"Rain falls.\"\n")
	assert_eq(spoken, ["Rain falls."] as Array[String], "narration has no speaker")
	director.stop()


func test_choices_are_read_and_voiced_lines_stay_quiet() -> void:
	(story.get_crew(&"Settings") as StorySettings).set_value("read_aloud", true)
	await _play("beat start:\n\t@voice(\"bell\") \"Ding.\"\n")
	assert_eq(spoken, [] as Array[String], "the voice clip speaks instead")
	director.stop()
	await _play("beat start:\n\tchoose:\n\t\t\"Stay\":\n\t\t\tpass\n\t\t\"Go\":\n\t\t\tpass\n")
	assert_eq(spoken, ["Choices: Stay. Go."] as Array[String])
	director.stop()

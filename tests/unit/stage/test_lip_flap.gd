extends "res://tests/framework/story_test.gd"
## Tests for lip-flap: a character with "<mood>_talk" frames moves their
## mouth while their voice clip plays.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")

var story: Node
var director: TaleDirector
var stage: StoryStage


func before_each() -> void:
	story = track(StoryScript.new())
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage, StoryAudio]
	config.cast_folder = "res://tests/fixtures/cast"
	config.audio_folder = "res://tests/fixtures/audio"
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	stage = story.get_crew(&"Stage")
	await tree.process_frame


func _texture_file(member: CastMember) -> String:
	var sprite := member.find_children("*", "Sprite2D", true, false)[0] as Sprite2D
	return sprite.texture.resource_path.get_file()


func test_the_mouth_moves_while_talking() -> void:
	var robin := stage.get_cast("robin")
	robin.enter("smile", Vector2(0.5, 0.0), 0.0)
	var talking := {"on": true}
	robin.talk_while(func() -> bool: return talking["on"])
	assert_true(robin.is_talking())
	var seen := {}
	for i in 30:
		await tree.process_frame
		seen[_texture_file(robin)] = true
		if seen.size() == 2:
			break
	await tree.create_timer(0.3).timeout
	seen[_texture_file(robin)] = true
	assert_true(seen.has("smile.png") and seen.has("smile_talk.png"), "both frames show: %s" % [seen.keys()])
	assert_eq(robin.mood, "smile", "the mood itself stays")
	talking["on"] = false
	await tree.process_frame
	await tree.process_frame
	assert_false(robin.is_talking())
	assert_eq(_texture_file(robin), "smile.png", "the mouth closes when the voice ends")


func test_talk_frames_are_not_moods_and_are_optional() -> void:
	var robin := stage.get_cast("robin")
	assert_false("smile_talk" in robin.profile.look.get_moods(), "talk frames are left out of the mood list")
	robin.enter("neutral", Vector2(0.5, 0.0), 0.0)
	robin.talk_while(func() -> bool: return true)
	assert_false(robin.is_talking(), "no neutral_talk frame, so nothing happens")


func test_voiced_lines_flap_the_speakers_mouth() -> void:
	var presenter: ScriptedPresenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	var talking_when_shown := []
	presenter.on_line = func(_line: Dictionary) -> void:
		await tree.process_frame
		talking_when_shown.append(stage.get_cast("robin").is_talking())
	director.presenter = presenter
	var source := "beat start:\n\trobin.enter(\"smile\", time = 0)\n\t@voice(\"hello\") robin: \"Hello!\"\n\trobin: \"No voice.\"\n"
	var result := TaleCompiler.build(source, "t", director.make_check_context("t"))
	director.add_tale(result["tale"])
	await director.play("t")
	assert_eq(talking_when_shown, [true, false])

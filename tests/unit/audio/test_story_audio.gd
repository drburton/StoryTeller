extends "res://tests/framework/story_test.gd"
## Tests for the Audio crew member and audio actions. They run on Godot's
## dummy audio driver, so they check state and timing rather than sound.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")

var story: Node
var director: TaleDirector
var audio: StoryAudio
var presenter: ScriptedPresenter
var errors: Array[String] = []


func before_each() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryAudio]
	config.audio_folder = "res://tests/fixtures/audio"
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	audio = story.get_crew(&"Audio")
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


func test_music_plays_and_crossfades() -> void:
	await _play("beat start:\n\tmusic(\"theme\", fade = 0)\n\t\"one\"\n\tmusic(\"other\", volume = 0.5, fade = 0.05)\n\t\"two\"\n")
	assert_eq(errors, [])
	assert_eq(audio.get_music_track(), "other")
	assert_eq(audio.capture()["music"], {"track": "other", "volume": 0.5, "loop": true})


func test_same_track_only_changes_volume() -> void:
	audio.play_music("theme", 1.0, 0.0)
	var player_count_before := audio.find_children("Music*", "AudioStreamPlayer", true, false).filter(
		func(p: AudioStreamPlayer) -> bool: return p.playing).size()
	audio.play_music("theme", 0.3, 0.0)
	var playing := audio.find_children("Music*", "AudioStreamPlayer", true, false).filter(
		func(p: AudioStreamPlayer) -> bool: return p.playing)
	assert_eq(playing.size(), player_count_before)
	assert_true(is_equal_approx(db_to_linear(playing[0].volume_db), 0.3))


func test_stop_music_and_audio() -> void:
	await _play("beat start:\n\tmusic(\"theme\", fade = 0)\n\tambience(\"rain\", fade = 0)\n\tstop_music(fade = 0)\n\t\"x\"\n")
	assert_eq(audio.get_music_track(), "")
	assert_eq(audio.get_ambience_track(), "rain")
	await _play("beat start:\n\tstop_audio(fade = 0)\n\t\"y\"\n")
	assert_eq(audio.get_ambience_track(), "")


func test_awaited_sound_takes_its_length() -> void:
	var started := Time.get_ticks_msec()
	await _play("beat start:\n\tawait sound(\"bell\")\n\t\"after bell\"\n")
	assert_true(Time.get_ticks_msec() - started >= 140, "waited for the 0.15 s sound")
	assert_eq(presenter.lines, ["after bell"])


func test_voice_annotation_plays_clip() -> void:
	var clips := []
	presenter.on_line = func(_line: Dictionary) -> void: clips.append(audio.get_voice_clip())
	await _play("beat start:\n\t@voice(\"hello\") \"Hello there.\"\n\t\"No voice.\"\n")
	assert_eq(errors, [])
	assert_eq(clips, ["hello", ""], "the voice plays with its line and stops at the next")
	assert_eq(audio.get_node("Voice").stream.resource_path, "res://tests/fixtures/audio/voice/hello.wav")


func test_missing_audio_is_reported() -> void:
	await _play("beat start:\n\tmusic(\"nope\")\n\tsound(\"nope\")\n\t@voice(\"nope\") \"Line.\"\n")
	assert_eq(errors.size(), 3)
	assert_true(errors[0].begins_with("2: Music 'nope' was not found"))
	assert_true(errors[1].begins_with("3: Sound 'nope' was not found"))
	assert_true(errors[2].begins_with("4: Voice clip 'nope' was not found"))


func test_skipping_silences_sounds_and_voices() -> void:
	director.skipping = true
	var started := Time.get_ticks_msec()
	await _play("beat start:\n\tawait sound(\"bell\")\n\tawait voice(\"hello\")\n\t\"done\"\n")
	assert_true(Time.get_ticks_msec() - started < 100)
	assert_eq(audio.get_voice_clip(), "")


func test_player_volume_settings() -> void:
	audio.play_music("theme", 1.0, 0.0)
	audio.set_kind_volume("music", 0.5)
	var playing := audio.find_children("Music*", "AudioStreamPlayer", true, false).filter(
		func(p: AudioStreamPlayer) -> bool: return p.playing)
	assert_true(is_equal_approx(db_to_linear(playing[0].volume_db), 0.5))


func test_capture_and_restore() -> void:
	audio.play_music("theme", 0.7, 0.0, false)
	audio.play_ambience("rain", 0.4, 0.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(audio.capture()))
	audio.stop_all(0.0)
	audio.restore(saved)
	assert_eq(audio.get_music_track(), "theme")
	assert_eq(audio.get_ambience_track(), "rain")
	assert_eq(audio.capture()["music"]["loop"], false)

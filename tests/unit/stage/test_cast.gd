extends "res://tests/framework/story_test.gd"
## Tests for cast members, looks, and the Stage crew member.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const CAST_FOLDER := "res://tests/fixtures/cast"

var story: Node
var director: TaleDirector
var stage: StoryStage
var presenter: ScriptedPresenter
var errors: Array[String] = []


func before_each() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage]
	config.cast_folder = CAST_FOLDER
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	stage = story.get_crew(&"Stage")
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


func _texture(color: Color, size := Vector2i(32, 64)) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func test_scan_cast_finds_image_folders() -> void:
	var profiles := StoryStage.scan_cast(CAST_FOLDER)
	assert_eq(profiles.keys(), ["robin"])
	var robin: CastProfile = profiles["robin"]
	assert_eq(robin.get_display_name(), "Robin")
	assert_eq(robin.default_mood, "neutral")
	assert_eq(robin.look.get_moods(), PackedStringArray(["neutral", "smile"]))


func test_check_context_knows_cast_and_moods() -> void:
	var context := director.make_check_context("main")
	assert_eq(context.cast, {"robin": PackedStringArray(["neutral", "smile"])})


func test_tales_control_cast_members() -> void:
	await _play("beat start:\n\trobin.enter(\"smile\", at = LEFT, time = 0)\n\t\"{robin.mood} {robin.on_stage}\"\n\trobin.mood = \"neutral\"\n\tawait robin.move_to(RIGHT, time = 0.05)\n\trobin (smile): \"Hello.\"\n")
	var robin := stage.get_cast("robin")
	assert_eq(presenter.lines, ["smile true", "Robin: Hello."])
	assert_eq(robin.mood, "smile", "the dialogue mood was applied")
	assert_eq(robin.stage_position, Vector2(0.75, 0.0))
	var size := robin.get_viewport_rect().size
	assert_true(robin.position.distance_to(Vector2(size.x * 0.75, size.y)) < 1.0, "moved to RIGHT")
	assert_true(robin.visible)
	assert_eq(errors, [])


func test_exit_hides_after_fading() -> void:
	await _play("beat start:\n\trobin.enter(time = 0)\n\tawait robin.exit(time = 0.05)\n\t\"{robin.on_stage}\"\n")
	assert_eq(presenter.lines, ["false"])
	assert_false(stage.get_cast("robin").visible)


func test_lines_wait_for_entrances() -> void:
	await _play("beat start:\n\trobin.enter(time = 0.1)\n\t\"after\"\n")
	assert_true(presenter.line_data.size() == 1)
	assert_eq(stage.get_cast("robin").modulate.a, 1.0, "fade finished before the line")


func test_cast_members_are_sandboxed() -> void:
	await _play("beat start:\n\trobin.queue_free()\n\trobin.enter(colour = 1)\n\t\"still here\"\n")
	assert_eq(errors, ["2: 'queue_free' is not available to tales.", "3: 'enter' has no argument named 'colour'."])
	assert_true(is_instance_valid(stage.get_cast("robin")))


func test_speaker_highlight_dims_others() -> void:
	var other := CastProfile.new()
	other.id = "kit"
	other.look = SpriteSetLook.new()
	other.look.moods["neutral"] = _texture(Color.RED)
	stage.add_profile(other)
	await _play("beat start:\n\trobin.enter(time = 0)\n\tkit.enter(\"neutral\", time = 0)\n\trobin: \"Me first.\"\n")
	assert_eq(stage.get_cast("robin").modulate, Color.WHITE)
	assert_eq(stage.get_cast("kit").modulate, CastMember.DIMMED)


func test_speaker_name_and_color_from_profile() -> void:
	var profile := CastProfile.new()
	profile.id = "kit"
	profile.display_name = "Kit Marlow"
	profile.name_color = Color.ORANGE
	stage.add_profile(profile)
	await _play("beat start:\n\tkit: \"Hi.\"\n")
	assert_eq(presenter.line_data[0]["speaker_name"], "Kit Marlow")
	assert_eq(presenter.line_data[0]["speaker_color"], Color.ORANGE)


func test_layered_look() -> void:
	var look := LayeredLook.new()
	look.groups = {
		"body": {"plain": _texture(Color.GRAY)},
		"face": {"smile": _texture(Color.YELLOW), "frown": _texture(Color.BLUE)},
	}
	look.order = PackedStringArray(["body", "face"])
	look.defaults = {"body": "plain", "face": "smile"}
	look.presets = {"upset": "face=frown"}
	var visual: Node2D = track(look.create_visual())
	assert_eq(visual.get_child(0).name, &"body")
	var face: Sprite2D = visual.get_node("face")
	assert_eq(face.texture, look.groups["face"]["smile"])
	assert_true(look.apply_mood(visual, "upset"))
	assert_eq(face.texture, look.groups["face"]["frown"])
	assert_true(look.apply_mood(visual, "face=smile"))
	assert_false(look.apply_mood(visual, "face=wink"))
	assert_false(look.apply_mood(visual, "nonsense"))
	assert_eq(LayeredLook.parse_choices("a=b, c = d"), {"a": "b", "c": "d"})
	assert_has(look.get_moods(), "upset")
	assert_has(look.get_moods(), "face=frown")


func test_unknown_mood_keeps_current_mood() -> void:
	var robin := stage.get_cast("robin")
	robin.mood = "smile"
	robin.mood = "furious"
	assert_eq(robin.mood, "smile")


func test_capture_and_restore() -> void:
	await _play("beat start:\n\trobin.enter(\"smile\", at = Vector2(0.3, 0.1), time = 0)\n\trobin.flip = true\n\trobin.tint = Color(1, 0.5, 0.5)\n")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(stage.capture()))
	stage.get_cast("robin").exit(0.0)
	stage.restore(saved)
	var robin := stage.get_cast("robin")
	assert_true(robin.on_stage)
	assert_true(robin.visible)
	assert_eq(robin.mood, "smile")
	assert_true(robin.flip)
	assert_true(robin.stage_position.is_equal_approx(Vector2(0.3, 0.1)))
	assert_true(robin.tint.is_equal_approx(Color(1, 0.5, 0.5)))


func test_checker_reports_unknown_cast_moods() -> void:
	var result := TaleCompiler.build("beat start:\n\trobin (furious): \"Grr.\"\n", "main", director.make_check_context("main"))
	assert_eq(str(result["diagnostics"][0]), "2:2: warning: Cast member 'robin' has no mood 'furious'.")

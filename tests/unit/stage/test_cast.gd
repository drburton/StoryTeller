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
	var result := TaleCompiler.build("beat start:\n\trobin.queue_free()\n", "main", director.make_check_context("main"))
	assert_eq(str(result["diagnostics"][0]), "2:2: error: Cast member 'robin' has no 'queue_free'. Its fields come from the cast profile.", "the checker catches it")
	assert_eq(await director.evaluate_source("robin.queue_free()"), [false, "'queue_free' is not available to tales."], "and so does the runtime, for code that skips the checker")
	await _play("beat start:\n\trobin.enter(colour = 1)\n\t\"still here\"\n")
	assert_eq(errors, ["2: 'enter' has no argument named 'colour'."])
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


func test_interrupted_animations_do_not_block() -> void:
	await _play("beat start:\n\trobin.enter(time = 0)\n\trobin.move_to(LEFT, time = 0.3)\n\trobin.move_to(RIGHT, time = 0.05)\n\t\"done\"\n")
	assert_eq(presenter.lines, ["done"])
	stage.get_cast("robin").move_to(TaleDirector.POSITIONS["LEFT"], 5.0)
	stage.get_cast("robin").finish_animations()
	assert_eq(stage.get_cast("robin").stage_position, TaleDirector.POSITIONS["LEFT"])


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


func test_tales_rename_cast_members() -> void:
	var source := "var typed := \"Robbie\"\n\nbeat start:\n\trobin.display_name = \"???\"\n\trobin: \"Who am I?\"\n\trobin.display_name = typed\n\trobin: \"I'm {robin.display_name}.\"\n\trobin.display_name = \"\"\n\trobin: \"Back to my real name.\"\n\trobin.display_name = 7\n\trobin: \"Lucky.\"\n"
	await _play(source)
	assert_eq(errors, [])
	assert_eq(presenter.lines, ["???: Who am I?", "Robbie: I'm Robbie.", "Robin: Back to my real name.", "7: Lucky."])


func test_renames_are_saved_and_reset_on_load() -> void:
	var robin := stage.get_cast("robin")
	robin.display_name = "???"
	var saved: Dictionary = JSON.parse_string(JSON.stringify(stage.capture()))
	assert_eq(saved["cast"]["robin"]["display_name"], "???")
	robin.display_name = "Someone else"
	stage.restore(saved)
	assert_eq(robin.display_name, "???")
	stage.restore({})
	assert_eq(robin.display_name, "Robin", "a save without the rename shows the profile name")
	robin.display_name = "???"
	stage.restore({"cast": {"robin": {"mood": "smile"}}})
	assert_eq(robin.display_name, "Robin", "saves from before renames show the profile name")


## A scene look whose AnimationPlayer has "neutral" (looping, used as the
## mood), "wave" (0.1 seconds), and "sway" (looping).
func _scene_look() -> SceneLook:
	var root := Node2D.new()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	var library := AnimationLibrary.new()
	for spec in [["neutral", 0.5, true], ["wave", 0.1, false], ["sway", 0.5, true]]:
		var animation := Animation.new()
		animation.length = spec[1]
		animation.loop_mode = Animation.LOOP_LINEAR if spec[2] else Animation.LOOP_NONE
		library.add_animation(spec[0], animation)
	player.add_animation_library("", library)
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	var look := SceneLook.new()
	look.scene = packed
	look.mood_names = PackedStringArray(["neutral"])
	return look


func _add_kit() -> CastMember:
	var profile := CastProfile.new()
	profile.id = "kit"
	profile.look = _scene_look()
	profile.default_mood = "neutral"
	stage.add_profile(profile)
	return stage.get_cast("kit")


func test_hop_shake_and_nod_move_only_the_look() -> void:
	var robin := stage.get_cast("robin")
	robin.enter("", Vector2(0.5, 0.0), 0.0)
	var resting := robin.position
	var look: Node2D = robin._visual
	for call in [["hop", [0.05, 0.3]], ["shake", [1.0, 0.3]], ["nod", [0.3]]]:
		var done := {"value": false}
		var run := func() -> void:
			await robin.callv(call[0], call[1])
			done["value"] = true
		run.call()
		var moved := Vector2.ZERO
		for i in 6:
			await tree.process_frame
			if look.position.length() > moved.length():
				moved = look.position
		match call[0]:
			"hop":
				assert_true(moved.y < 0.0, "hop lifts the look")
			"shake":
				assert_true(absf(moved.x) > 0.0, "shake moves it sideways")
			"nod":
				assert_true(moved.y > 0.0, "nod dips it")
		for i in 40:
			if done["value"]:
				break
			await tree.process_frame
		assert_true(done["value"], "%s finishes" % call[0])
		assert_eq(look.position, Vector2.ZERO, "%s comes back to rest" % call[0])
		assert_eq(robin.position, resting, "the character's place doesn't change")


func test_movements_finish_at_once_when_skipping_or_interrupted() -> void:
	var robin := stage.get_cast("robin")
	robin.enter("", Vector2(0.5, 0.0), 0.0)
	robin.hop(0.05, 5.0)
	await tree.process_frame
	await tree.process_frame
	assert_ne(robin._visual.position, Vector2.ZERO)
	robin.finish_animations()
	assert_eq(robin._visual.position, Vector2.ZERO)
	robin.is_skipping = func() -> bool: return true
	var started := Time.get_ticks_msec()
	await robin.shake(1.0, 5.0)
	assert_true(Time.get_ticks_msec() - started < 500, "skipping doesn't wait")


func test_tales_use_movements_and_drawing_order() -> void:
	var kit := _add_kit()
	await _play("beat start:\n\trobin.enter(time = 0)\n\tkit.enter(time = 0)\n\trobin.hop(time = 0.05)\n\tkit.nod(time = 0.05)\n\tawait robin.shake(time = 0.05)\n\trobin.to_front()\n\t\"one\"\n\trobin.to_back()\n\tkit.draw_order = 5\n\t\"two\"\n")
	assert_eq(errors, [])
	assert_eq(presenter.lines, ["one", "two"])
	var robin := stage.get_cast("robin")
	assert_true(robin.draw_order < kit.draw_order, "to_back and draw_order")
	assert_eq(kit.z_index, 5)


func test_to_front_and_to_back() -> void:
	var robin := stage.get_cast("robin")
	var kit := _add_kit()
	assert_eq([robin.draw_order, kit.draw_order], [0, 0])
	robin.to_front()
	assert_eq([robin.draw_order, kit.draw_order], [1, 0])
	robin.to_front()
	assert_eq(robin.draw_order, 1, "already in front")
	kit.to_front()
	assert_eq(kit.draw_order, 2)
	kit.to_back()
	assert_eq(kit.draw_order, 0)
	assert_eq([robin.z_index, kit.z_index], [1, 0])


func test_drawing_order_is_saved() -> void:
	var robin := stage.get_cast("robin")
	robin.draw_order = 3
	var saved: Dictionary = JSON.parse_string(JSON.stringify(stage.capture()))
	robin.draw_order = -2
	stage.restore(saved)
	assert_eq(robin.draw_order, 3)
	stage.restore({})
	assert_eq(robin.draw_order, 0)


func test_animate_plays_a_scene_animation_then_the_mood() -> void:
	var kit := _add_kit()
	var player: AnimationPlayer = kit._visual.get_node("AnimationPlayer")
	await _play("beat start:\n\tkit.enter(time = 0)\n\tkit.animate(\"wave\")\n\t\"waving\"\n")
	assert_eq(errors, [])
	assert_eq(player.current_animation, "neutral", "the mood plays again after the animation")
	var started := Time.get_ticks_msec()
	await kit.animate("sway")
	assert_true(Time.get_ticks_msec() - started < 100, "a looping animation returns at once")
	assert_eq(player.current_animation, "sway")


func test_animate_reports_missing_animations() -> void:
	_add_kit()
	await _play("beat start:\n\tkit.animate(\"dance\")\n\trobin.animate(\"wave\")\n\t\"x\"\n")
	assert_eq(errors, [
		"2: kit has no animation 'dance'. Named animations need a scene look with an AnimationPlayer.",
		"3: robin has no animation 'wave'. Named animations need a scene look with an AnimationPlayer.",
	])


func _add_friend() -> CastMember:
	var profile := CastProfile.new()
	profile.id = "pat"
	profile.fields = {"affection": 0, "met": false, "gifts": []}
	stage.add_profile(profile)
	return stage.get_cast("pat")


func test_tales_read_and_change_fields() -> void:
	var pat := _add_friend()
	await _play("beat start:\n\tpat.affection += 2\n\tpat.met = true\n\tpat.gifts.append(\"tea\")\n\tif pat.affection > 1 and pat.met:\n\t\tpat: \"Affection {pat.affection}, gifts {len(pat.gifts)}.\"\n")
	assert_eq(errors, [])
	assert_eq(presenter.lines, ["Pat: Affection 2, gifts 1."])
	assert_eq([pat.get_field("affection"), pat.get_field("met"), pat.get_field("gifts")], [2, true, ["tea"]])
	assert_true(pat.set_field("affection", 5))
	assert_false(pat.set_field("loyalty", 1), "only declared fields")
	assert_eq(pat.get_field("affection"), 5)


func test_fields_start_over_from_the_profile() -> void:
	var pat := _add_friend()
	pat.get_field("gifts").append("cake")
	pat.reset_fields()
	assert_eq(pat.get_field("gifts"), [], "starting values are copied, not shared")
	assert_eq(pat.profile.fields["gifts"], [])


func test_fields_are_saved_with_their_types() -> void:
	var pat := _add_friend()
	pat.set_field("affection", 3)
	pat.set_field("gifts", ["tea", Vector2(1, 2)])
	var saved: Dictionary = JSON.parse_string(JSON.stringify(stage.capture()))
	pat.reset_fields()
	stage.restore(saved)
	assert_eq(typeof(pat.get_field("affection")), TYPE_INT, "whole numbers stay whole")
	assert_eq(pat.get_field("affection"), 3)
	assert_eq(pat.get_field("gifts"), ["tea", Vector2(1, 2)])
	stage.restore({})
	assert_eq(pat.get_field("affection"), 0, "a save without the member starts it over")
	stage.restore({"cast": {"pat": {"fields": JSON.from_native({"affection": 7, "dropped": 1})}}})
	assert_eq([pat.get_field("affection"), pat.get_field("met")], [7, false], "new fields keep their starting values")
	assert_false(pat.has_field("dropped"))


func test_checker_and_autocomplete_know_fields() -> void:
	_add_friend()
	var context := director.make_check_context("main")
	assert_eq(context.cast_fields["pat"], PackedStringArray(["affection", "gifts", "met"]))
	assert_eq(context.cast_fields["robin"], PackedStringArray())
	var result := TaleCompiler.build("beat start:\n\tpat.affection += 1\n\tpat.afection += 1\n\trobin.affection = 1\n\tpat.hop()\n", "main", context)
	assert_eq(result["diagnostics"].map(func(d: TaleDiagnostic) -> String: return str(d)), [
		"3:2: error: Cast member 'pat' has no 'afection'. Its fields come from the cast profile.",
		"4:2: error: Cast member 'robin' has no 'affection'. Its fields come from the cast profile.",
	])
	var found := TaleCompletion.suggest("beat a:\n\tpat.aff", 1, 8, context)
	assert_eq(found.map(func(item: Dictionary) -> String: return item["text"]), ["affection"])


func test_field_names_that_clash_are_left_out() -> void:
	var profile := CastProfile.new()
	profile.id = "lee"
	profile.fields = {"trust": 0, "mood": 1, "rotation": 2, "bad name": 3, "hop": 4}
	assert_eq(profile.get_field_names(), PackedStringArray(["trust"]))
	assert_eq(profile.get_field_problems().size(), 4)
	assert_true(profile.get_field_problems()[0].contains("can't have a field named 'mood'"))

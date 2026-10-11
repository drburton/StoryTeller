extends "res://tests/framework/story_test.gd"
## Tests for transitions beyond the built-in ones: StoryTransition files,
## the stage's registry, custom shaders, and the editor's transition list.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const TINT_SHADER := "shader_type canvas_item;\nuniform vec4 from_color : source_color;\nuniform vec4 to_color : source_color;\nuniform float progress = 1.0;\nuniform vec4 tint : source_color;\nvoid fragment() { COLOR = mix(from_color, to_color, progress) * tint; }\n"


func _view() -> BackdropView:
	var view: BackdropView = track(BackdropView.new())
	tree.root.add_child(view)
	return view


func test_a_transition_can_reuse_a_built_in_mode_with_its_own_mask() -> void:
	var view := _view()
	var mask := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_L8))
	var swirl := StoryTransition.new()
	swirl.mode = StoryTransition.Mode.WIPE
	swirl.direction = Vector2.DOWN
	swirl.mask = mask
	swirl.softness = 0.3
	view.transitions = {"swirl": swirl}
	assert_true(view.has_transition("swirl"))
	assert_has(view.get_transition_names(), "swirl")
	view.show_backdrop(Color.RED, "red", "swirl", 0.5)
	var material := view.get_material_in_use()
	assert_eq(material.get_shader_parameter("mode"), 3)
	assert_eq(material.get_shader_parameter("direction"), Vector2.DOWN)
	assert_eq(material.get_shader_parameter("mask_tex"), mask)
	assert_true(material.get_shader_parameter("has_mask"))
	assert_eq(material.get_shader_parameter("smoothness"), 0.3)
	view.finish()
	view.show_backdrop(Color.BLUE, "blue", "dissolve", 0.5)
	assert_false(material.get_shader_parameter("has_mask"), "built-in transitions go back to no mask")
	assert_eq(material.get_shader_parameter("smoothness"), 0.08)
	view.finish()


func test_a_transition_with_its_own_shader_takes_over_and_hands_back() -> void:
	var view := _view()
	var shader := Shader.new()
	shader.code = TINT_SHADER
	var tinted := StoryTransition.new()
	tinted.shader = shader
	tinted.parameters = {"tint": Color.GREEN}
	view.transitions = {"tinted": tinted}
	view.show_backdrop(Color.WHITE, "white", "none", 0.0)
	var state := {"done": false}
	var run := func() -> void:
		await view.show_backdrop(Color.RED, "red", "tinted", 0.2)
		state["done"] = true
	run.call()
	var material := view.get_material_in_use()
	assert_eq(material.shader, shader)
	assert_eq(material.get_shader_parameter("from_color"), Color.WHITE)
	assert_eq(material.get_shader_parameter("to_color"), Color.RED)
	assert_eq(material.get_shader_parameter("tint"), Color.GREEN)
	await tree.create_timer(0.4).timeout
	assert_true(state["done"])
	var after := view.get_material_in_use()
	assert_ne(after.shader, shader, "the built-in shader draws again once it ends")
	assert_eq(after.get_shader_parameter("to_color"), Color.RED)
	assert_eq(view.get_progress(), 1.0)
	assert_eq(view.current, "red")


func test_unknown_transitions_fall_back_to_fade() -> void:
	var view := _view()
	view.show_backdrop(Color.RED, "red", "sparkle", 0.5)
	assert_eq(view.get_material_in_use().get_shader_parameter("mode"), 1)
	view.finish()


func test_stage_finds_transition_files_and_takes_more() -> void:
	var story: Node = track(StoryScript.new())
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage]
	config.transition_folder = "res://tests/fixtures/transitions"
	config.transitions = {"quick": StoryTransition.new()}
	story.start(config)
	tree.root.add_child(story)
	var stage: StoryStage = story.get_crew(&"Stage")
	assert_eq(stage.transitions.keys(), ["swirl", "quick"])
	assert_eq(stage.transitions["swirl"].softness, 0.2)
	stage.add_transition("late", StoryTransition.new())
	assert_true(stage.backdrop_view.has_transition("late"))
	assert_true(stage.cg_view.has_transition("late"), "CGs share the transitions")
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	var result := TaleCompiler.build("beat start:\n\tbackdrop(Color.RED, transition = \"swirl\", time = 0)\n", "t", director.make_check_context("t"))
	director.add_tale(result["tale"])
	await director.play("t")
	assert_eq(stage.backdrop_view.current, Color.RED)


func test_editor_lists_registered_transitions() -> void:
	var config := StoryConfig.new()
	config.transition_folder = "res://tests/fixtures/transitions"
	config.transitions = {"quick": StoryTransition.new()}
	var names := TaleSignatures.choices("backdrop", "transition", config, TaleCheckContext.new())
	assert_eq(names.slice(names.size() - 2), PackedStringArray(["quick", "swirl"]))
	assert_has(names, "fade")

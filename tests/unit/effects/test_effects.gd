extends "res://tests/framework/story_test.gd"
## Tests for weather, filters, flashes, screen fades, exit_all, and autosave.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const SAVE_FOLDER := "user://test_effect_saves"

var story: Node
var director: TaleDirector
var effects: StoryEffects
var presenter: ScriptedPresenter
var errors: Array[String] = []


func before_each() -> void:
	_clean()
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage, StoryEffects, StorySaves]
	config.cast_folder = "res://tests/fixtures/cast"
	config.movie_folder = "res://tests/fixtures/movies"
	config.save_folder = SAVE_FOLDER
	config.autosave_on_choice = false
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	effects = story.get_crew(&"Effects")
	presenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	director.presenter = presenter
	errors.clear()
	director.runtime_error.connect(func(message: String, _tale: String, line: int) -> void:
		errors.append("%d: %s" % [line, message]))
	await tree.process_frame


func after_each() -> void:
	_clean()


func _clean() -> void:
	if DirAccess.dir_exists_absolute(SAVE_FOLDER):
		for file_name in DirAccess.get_files_at(SAVE_FOLDER):
			DirAccess.remove_absolute(SAVE_FOLDER.path_join(file_name))


func _play(source: String) -> void:
	var result := TaleCompiler.build(source, "main", director.make_check_context("main"))
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail(str(diagnostic))
	if result["tale"]:
		director.add_tale(result["tale"])
		await director.play("main")


func test_layers_sit_between_stage_dialogue_and_menus() -> void:
	assert_true(effects.weather_layer.layer > StoryStage.PROP_LAYER)
	assert_true(effects.filter_layer.layer < 10, "filters leave the dialogue box alone")
	assert_true(effects.screen_layer.layer > 10, "fades cover the dialogue box")
	assert_true(effects.screen_layer.layer < 20, "menus stay visible")


func test_weather_starts_and_stops() -> void:
	await _play("beat start:\n\tweather(\"rain\", strength = 0.5, fade = 0)\n\t\"Rain.\"\n")
	assert_eq(errors, [])
	assert_eq(effects.get_weather(), "rain")
	assert_eq(effects.weather_layer.get_child_count(), 1)
	await _play("beat start:\n\tweather(\"none\", fade = 0)\n\t\"Dry.\"\n")
	await tree.process_frame
	assert_eq(effects.get_weather(), "none")
	assert_eq(effects.weather_layer.get_child_count(), 0)


func test_filter_changes_strength_over_time() -> void:
	_play("beat start:\n\tfilter(\"sepia\", time = 0.2)\n\t\"Old photo.\"\n")
	await tree.process_frame
	var material: ShaderMaterial = effects.filter_layer.get_child(0).material
	var midway: float = material.get_shader_parameter("strength")
	assert_true(midway < 1.0, "still fading in")
	await tree.create_timer(0.35).timeout
	assert_eq(material.get_shader_parameter("strength"), 1.0)
	assert_eq(material.get_shader_parameter("mode"), StoryEffects.FILTERS.find("sepia"))
	assert_eq(presenter.lines, ["Old photo."])


func test_blur_and_vignette_are_filters() -> void:
	var material: ShaderMaterial = effects.filter_layer.get_child(0).material
	for filter_name in ["blur", "vignette"]:
		assert_eq(await effects.set_filter(filter_name, 0.5, 0.0), "")
		assert_eq(material.get_shader_parameter("mode"), StoryEffects.FILTERS.find(filter_name))
		assert_eq(material.get_shader_parameter("strength"), 0.5)
	await effects.set_filter("none", 1.0, 0.0)


func test_unknown_names_are_reported() -> void:
	await _play("beat start:\n\tweather(\"hail\")\n\tfilter(\"neon\")\n\t\"x\"\n")
	assert_eq(errors, [
		"2: Unknown weather 'hail'. Kinds: none, rain, snow.",
		"3: Unknown filter 'neon'. Filters: none, grayscale, sepia, night, warm, cold, blur, vignette.",
	])


func test_fade_out_and_in() -> void:
	await _play("beat start:\n\tawait fade_out(Color.BLACK, time = 0)\n\t\"Dark.\"\n")
	assert_true(effects.is_faded_out())
	await _play("beat start:\n\tawait fade_in(time = 0.05)\n\t\"Light.\"\n")
	assert_false(effects.is_faded_out())


func test_flash_fades_away() -> void:
	await _play("beat start:\n\tawait flash(Color.RED, time = 0.05)\n\t\"Boom.\"\n")
	var flash: ColorRect = effects.screen_layer.get_node("Flash")
	assert_eq(flash.color.a, 0.0)
	assert_eq(flash.color.r, 1.0)


func test_capture_and_restore() -> void:
	await _play("beat start:\n\tweather(\"snow\", fade = 0)\n\tfilter(\"night\", strength = 0.5, time = 0)\n\tfade_out(Color.WHITE, time = 0)\n\t\"x\"\n")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(effects.capture()))
	effects.clear()
	await tree.process_frame
	assert_eq(effects.get_weather(), "none")
	effects.restore(saved)
	assert_eq(effects.get_weather(), "snow")
	assert_eq(effects.get_filter(), "night")
	var material: ShaderMaterial = effects.filter_layer.get_child(0).material
	assert_eq(material.get_shader_parameter("strength"), 0.5)
	assert_true(effects.is_faded_out())


func test_skipping_makes_effects_instant() -> void:
	director.skipping = true
	await _play("beat start:\n\tawait fade_out(time = 5.0)\n\tawait filter(\"grayscale\", time = 5.0)\n\t\"x\"\n")
	assert_true(effects.is_faded_out())
	assert_eq(effects.filter_layer.get_child(0).material.get_shader_parameter("strength"), 1.0)


func test_exit_all_and_autosave() -> void:
	await _play("beat start:\n\trobin.enter(time = 0)\n\t\"Hi.\"\n\tawait exit_all(time = 0)\n\tautosave()\n\t\"Bye.\"\n")
	assert_eq(errors, [])
	var stage: StoryStage = story.get_crew(&"Stage")
	assert_false(stage.get_cast("robin").on_stage)
	var saves: StorySaves = story.get_crew(&"Saves")
	assert_true(saves.has_slot(StorySaves.AUTO_SLOT))


func test_movie_plays_to_the_end() -> void:
	var started := Time.get_ticks_msec()
	_play("beat start:\n\tawait play_movie(\"short\")\n\t\"After.\"\n")
	await tree.process_frame
	assert_true(effects.is_playing_movie())
	assert_eq(presenter.lines, [], "the line waits for the movie")
	for i in 300:
		if not presenter.lines.is_empty():
			break
		await tree.process_frame
	assert_eq(presenter.lines, ["After."])
	assert_false(effects.is_playing_movie())
	assert_true(Time.get_ticks_msec() - started >= 400, "it ran about half a second")


func test_movie_can_be_skipped() -> void:
	_play("beat start:\n\tawait play_movie(\"short\")\n\t\"After.\"\n")
	await tree.process_frame
	effects.skip_movie()
	await tree.process_frame
	await tree.process_frame
	assert_false(effects.is_playing_movie())
	assert_eq(presenter.lines, ["After."])


func test_unskippable_movie_ignores_skip_requests() -> void:
	_play("beat start:\n\tawait play_movie(\"short\", skippable = false)\n\t\"After.\"\n")
	await tree.process_frame
	effects.skip_movie()
	await tree.process_frame
	assert_true(effects.is_playing_movie())


func test_missing_movie_is_reported_and_skip_mode_skips_movies() -> void:
	await _play("beat start:\n\tplay_movie(\"nope\")\n\t\"x\"\n")
	assert_eq(errors, ["2: Movie 'nope' was not found in res://tests/fixtures/movies."])
	director.skipping = true
	await _play("beat start:\n\tawait play_movie(\"short\")\n\t\"y\"\n")
	assert_false(effects.is_playing_movie())

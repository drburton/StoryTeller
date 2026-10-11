extends "res://tests/framework/story_test.gd"
## Tests for CGs: cg(), hide_cg(), saving them, and their gallery items.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const SAVE_FOLDER := "user://test_cg_saves"
const SETTINGS_PATH := "user://test_cg_settings.cfg"
const CG_FOLDER := "res://tests/fixtures/cgs"

var story: Node
var director: TaleDirector
var stage: StoryStage
var collection: StoryCollection
var menus: StoryMenus
var dialogue: StoryDialogue
var errors: Array[String] = []


func before_each() -> void:
	_clean()
	await _make_story()


func after_each() -> void:
	_clean()


func _make_story() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage, StoryEffects, StoryAudio, StoryCollection, StorySaves, StorySettings, StoryDialogue, StoryMenus]
	config.cast_folder = "res://tests/fixtures/cast"
	config.backdrop_folder = "res://tests/fixtures/stage/backdrops"
	config.cg_folder = CG_FOLDER
	config.collection_folder = "res://tests/fixtures/collection"
	config.audio_folder = "res://tests/fixtures/audio"
	config.save_folder = SAVE_FOLDER
	config.settings_path = SETTINGS_PATH
	config.autosave_on_choice = false
	config.text_speed = 0.0
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	stage = story.get_crew(&"Stage")
	collection = story.get_crew(&"Collection")
	menus = story.get_crew(&"Menus")
	dialogue = story.get_crew(&"Dialogue")
	errors.clear()
	director.runtime_error.connect(func(message: String, _tale: String, line: int) -> void:
		errors.append("%d: %s" % [line, message]))
	await tree.process_frame


func _clean() -> void:
	if DirAccess.dir_exists_absolute(SAVE_FOLDER):
		for file_name in DirAccess.get_files_at(SAVE_FOLDER):
			DirAccess.remove_absolute(SAVE_FOLDER.path_join(file_name))
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


## Plays [param body] as the start beat, pressing continue at every line,
## and stops at the line "stop".
func _play(body: String) -> void:
	var result := TaleCompiler.build("beat start:\n" + body, "main", director.make_check_context("main"))
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail(str(diagnostic))
	director.add_tale(result["tale"])
	var state := {"stop": false}
	director.line_started.connect(func(line: Dictionary) -> void:
		if line["text"] == "stop":
			state["stop"] = true)
	director.play("main")
	for i in 60:
		await tree.process_frame
		if not director.is_playing() or state["stop"]:
			return
		if dialogue.dialogue_box._waiting:
			dialogue.dialogue_box.continue_pressed.emit()


func test_scan_finds_single_pictures_and_variant_folders() -> void:
	var cgs := StoryAssets.scan_cgs(CG_FOLDER)
	assert_eq(cgs, {"letter": PackedStringArray([""]), "rooftop": PackedStringArray(["day", "default", "night"])})
	assert_eq(StoryAssets.default_cg_variant(cgs["rooftop"]), "default")
	assert_eq(StoryAssets.default_cg_variant(PackedStringArray(["b", "a"])), "b", "the first when there is no default")
	assert_eq(StoryAssets.find_cg(CG_FOLDER, "rooftop", "night"), CG_FOLDER + "/rooftop/night.png")
	assert_eq(StoryAssets.find_cg(CG_FOLDER, "letter", ""), CG_FOLDER + "/letter.png")
	assert_eq(StoryAssets.scan_cgs("res://no/such/folder"), {})


func test_cg_layer_is_above_the_stage_and_below_weather() -> void:
	var effects: StoryEffects = story.get_crew(&"Effects")
	assert_true(stage.cg_layer.layer > stage.prop_layer.layer)
	assert_true(stage.cg_layer.layer < effects.weather_layer.layer, "rain falls over a CG")
	assert_true(stage.cg_layer.layer < effects.filter_layer.layer)
	assert_false(stage.cg_layer in stage.camera.layers, "the camera leaves CGs alone")


func test_cg_shows_variants_and_hides() -> void:
	await _play("\tcg(\"rooftop\", time = 0)\n\t\"stop\"\n")
	assert_eq(errors, [])
	assert_eq(stage.get_cg(), {"name": "rooftop", "variant": "default"})
	assert_eq(stage.cg_view.current, "rooftop/default")
	assert_true(stage.cg_view._material.get_shader_parameter("to_has_tex"))
	await stage.show_cg("rooftop", "night", "dissolve", 0.0)
	assert_eq(stage.get_cg(), {"name": "rooftop", "variant": "night"})
	await stage.hide_cg("fade", 0.0)
	assert_eq(stage.get_cg(), {})
	assert_eq(stage.cg_view.current, Color.TRANSPARENT)
	assert_false(stage.cg_view._material.get_shader_parameter("to_has_tex"), "the stage shows again")


func test_cg_problems_are_reported() -> void:
	await _play("\tcg(\"unicorn\")\n\tcg(\"rooftop\", \"noon\")\n\tcg(\"letter\", \"folded\")\n\t\"stop\"\n")
	assert_eq(errors, [
		"2: CG 'unicorn' was not found in res://tests/fixtures/cgs.",
		"3: CG 'rooftop' has no variant 'noon'. Its variants are: day, default, night.",
		"4: CG 'letter' is a single picture and has no variant 'folded'.",
	])
	assert_eq(stage.get_cg(), {})


func test_cg_is_saved_and_restored() -> void:
	await stage.show_cg("rooftop", "day", "none", 0.0)
	var saved := stage.capture()
	assert_eq(saved["cg"], {"name": "rooftop", "variant": "day"})
	await stage.hide_cg("none", 0.0)
	stage.restore(saved)
	assert_eq(stage.get_cg(), {"name": "rooftop", "variant": "day"})
	assert_eq(stage.cg_view.current, "rooftop/day")
	stage.restore({})
	assert_eq(stage.get_cg(), {}, "saves from before CGs show none")
	await stage.show_cg("letter", "", "none", 0.0)
	stage.clear()
	assert_eq(stage.get_cg(), {})
	assert_eq(stage.cg_view.current, Color.TRANSPARENT)


func test_every_cg_has_a_gallery_item() -> void:
	var letter := collection.get_cg_item("letter")
	assert_not_null(letter)
	assert_eq([letter.id, letter.kind, letter.title], ["letter", "image", "Letter"])
	assert_true(letter.order >= StoryCollection.CG_ORDER, "after saved items")
	assert_eq(collection.get_cg_item("rooftop").id, "rooftop")
	var titles := collection.get_items("image").map(func(item: CollectionItem) -> String: return item.title)
	assert_eq(titles, ["Night", "A Sunny Day", "Letter", "Rooftop"])


func test_saved_items_link_to_cgs() -> void:
	var by_field := CollectionItem.new()
	by_field.id = "first_kiss"
	by_field.cg = "rooftop"
	by_field.title = "Rooftop at Dusk"
	var by_id := CollectionItem.new()
	by_id.id = "letter"
	by_id.title = "The Letter"
	var items := {"first_kiss": by_field, "letter": by_id}
	StoryCollection.add_cg_items(items, StoryAssets.scan_cgs(CG_FOLDER))
	assert_eq(items.keys(), ["first_kiss", "letter"], "no extra items for linked CGs")
	assert_eq(by_id.cg, "letter", "an item named after a CG, with no image, is its gallery item")


func test_showing_a_cg_unlocks_it_and_records_variants() -> void:
	await _play("\tcg(\"rooftop\", \"night\", time = 0)\n\t\"one\"\n\tcg(\"rooftop\", \"day\", time = 0)\n\t\"two\"\n\tcg(\"rooftop\", \"night\", time = 0)\n\t\"stop\"\n")
	assert_eq(errors, [])
	var item := collection.get_cg_item("rooftop")
	assert_true(collection.is_collected("rooftop"))
	assert_false(collection.is_collected("letter"))
	assert_eq(menus.get_notices(), PackedStringArray(), "CGs unlock without a notice over the picture")
	var pictures := collection.get_pictures(item)
	assert_eq(pictures.map(func(texture: Texture2D) -> String: return texture.resource_path),
		[CG_FOLDER + "/rooftop/day.png", CG_FOLDER + "/rooftop/night.png"], "seen variants, in folder order")
	collection.collect("letter")
	assert_eq(collection.get_pictures(collection.get_cg_item("letter")).size(), 1)


func test_seen_variants_are_kept_across_playthroughs() -> void:
	await stage.show_cg("rooftop", "night", "none", 0.0)
	story.get_crew(&"Saves").save_globals()
	await _make_story()
	assert_true(collection.is_collected("rooftop"))
	assert_eq(collection.get_pictures(collection.get_cg_item("rooftop")).size(), 1)
	collection.unlock_all()
	assert_eq(collection.get_pictures(collection.get_cg_item("letter")).size(), 1)


func test_gallery_viewer_steps_through_seen_variants() -> void:
	await stage.show_cg("rooftop", "night", "none", 0.0)
	await stage.show_cg("rooftop", "default", "none", 0.0)
	menus.open("extras")
	await tree.process_frame
	var screen: ExtrasScreen = story.find_child("ExtrasScreen", true, false)
	var buttons := screen.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.tooltip_text == "Rooftop")
	assert_eq(buttons.size(), 1)
	buttons[0].pressed.emit()
	assert_eq(screen.get_viewer_index(), 0)
	assert_eq(screen._viewer_caption.text, "Rooftop  (1/2)")
	screen._on_viewer_clicked()
	assert_eq(screen.get_viewer_index(), 1)
	assert_eq(screen._viewer_caption.text, "Rooftop  (2/2)")
	screen._on_viewer_clicked()
	assert_eq(screen.get_viewer_index(), -1, "the click after the last picture closes the viewer")

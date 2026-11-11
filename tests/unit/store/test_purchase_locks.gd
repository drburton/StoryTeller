extends "res://tests/framework/story_test.gd"
## Tests for paid content outside the story itself (M13 phase 1, part 2):
## locked save slots, the lock in the Map view, and the path explorer
## playing both the owned and unowned way.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const SAVE_FOLDER := "user://test_purchase_locks_saves"
const PAID := "beat start:\n\t\"Free.\"\n\tif await offer(\"full_story\"):\n\t\tjump paid\n\t\"Demo ends.\"\n\n@needs(\"full_story\")\nbeat paid:\n\t\"Paid one.\"\n\t\"Paid two.\"\n"

var story: Node
var director: TaleDirector
var store: StoryStore
var test_store: TestStoreBackend
var saves: StorySaves
var menus: StoryMenus
var dialogue: StoryDialogue
var shown: Array[String] = []


func before_each() -> void:
	super()
	_clean()
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStore, StorySaves, StorySettings, StoryDialogue, StoryMenus]
	config.save_folder = SAVE_FOLDER
	config.settings_path = SAVE_FOLDER.path_join("settings.cfg")
	config.product_folder = "res://no_such_folder"
	var product := StoryProduct.new()
	product.id = "full_story"
	product.title = "The whole story"
	config.products = [product]
	config.store = "none"
	config.text_speed = 0.0
	config.dialogue_box_transition = "none"
	config.autosave_on_choice = false
	config.start_tale = "main"
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	store = story.get_crew(&"Store")
	saves = story.get_crew(&"Saves")
	menus = story.get_crew(&"Menus")
	dialogue = story.get_crew(&"Dialogue")
	test_store = TestStoreBackend.new()
	test_store.path = ""
	await store.set_backend(test_store)
	shown.clear()
	director.line_started.connect(func(line: Dictionary) -> void: shown.append(line["text"]))
	var result := TaleCompiler.build(PAID, "main", director.make_check_context("main"))
	director.add_tale(result["tale"])
	await tree.process_frame


func after_each() -> void:
	_clean()
	super()


func _clean() -> void:
	if DirAccess.dir_exists_absolute(SAVE_FOLDER):
		for file_name in DirAccess.get_files_at(SAVE_FOLDER):
			DirAccess.remove_absolute(SAVE_FOLDER.path_join(file_name))


func _continue() -> void:
	dialogue.dialogue_box.continue_pressed.emit()
	await tree.process_frame


func _press(button_text: String) -> void:
	for button in story.find_children("*", "Button", true, false):
		if button.text == button_text and button.is_visible_in_tree() and not button.disabled:
			button.pressed.emit()
			await tree.process_frame
			await tree.process_frame
			return
	fail("no visible, enabled button '%s'" % button_text)


## Plays into the paid beat as an owner and saves on its first line.
func _save_in_paid_content() -> void:
	test_store.set_owned("full_story", true)
	director.play("main")
	await tree.process_frame
	await _continue()
	assert_eq(shown, ["Free.", "Paid one."])
	assert_eq(saves.save_slot("1"), OK)
	director.stop()
	test_store.set_owned("full_story", false)
	# The story ending shows the title screen at the end of the frame.
	await tree.process_frame


func test_a_save_in_free_content_needs_nothing() -> void:
	director.play("main")
	await tree.process_frame
	saves.save_slot("1")
	assert_eq(saves.read_slot("1")["needs"], [])
	assert_eq(saves.get_locked_products("1"), PackedStringArray())


func test_a_save_after_a_needs_beat_is_locked_without_the_product() -> void:
	await _save_in_paid_content()
	assert_eq(saves.read_slot("1")["needs"], ["full_story"])
	assert_eq(saves.get_locked_products("1"), PackedStringArray(["full_story"]))
	assert_eq(saves.load_slot("1"), ERR_UNAUTHORIZED)
	test_store.set_owned("full_story", true)
	assert_eq(saves.get_locked_products("1"), PackedStringArray())
	assert_eq(saves.load_slot("1"), OK)
	await tree.process_frame
	assert_eq(shown.back(), "Paid one.")


func test_the_paid_products_survive_a_load() -> void:
	await _save_in_paid_content()
	test_store.set_owned("full_story", true)
	saves.load_slot("1")
	await tree.process_frame
	assert_eq(director.get_paid_products(), PackedStringArray(["full_story"]))
	assert_eq(saves.save_slot("2"), OK)
	assert_eq(saves.read_slot("2")["needs"], ["full_story"], "a save made after loading needs it too")


func test_the_load_screen_shows_a_locked_save() -> void:
	await _save_in_paid_content()
	menus.open("load")
	await tree.process_frame
	var texts := story.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	assert_has(texts, "Locked: The whole story")


func test_loading_a_locked_save_offers_the_product_first() -> void:
	await _save_in_paid_content()
	menus.open("load")
	await tree.process_frame
	var slot_button: Button = null
	for button in story.find_child("SaveLoadScreen", true, false).find_children("*", "Button", true, false):
		if not button.disabled and button.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text.begins_with("Locked")):
			slot_button = button
	slot_button.pressed.emit()
	await tree.process_frame
	assert_true(story.find_child("OfferScreen", true, false).is_visible_in_tree())
	await _press("Buy")
	await tree.process_frame
	assert_true(store.owns("full_story"))
	assert_false(menus.is_open())
	assert_eq(shown.back(), "Paid one.")


func test_declining_keeps_the_save_unloaded() -> void:
	await _save_in_paid_content()
	shown.clear()
	var loaded := [null]
	(func() -> void: loaded[0] = await menus.load_slot("1")).call()
	await tree.process_frame
	await _press("Not now")
	assert_eq(loaded[0], false)
	assert_eq(shown, [])


func test_the_map_marks_needs_beats() -> void:
	var docs := {"main": TaleParser.parse(PAID)}
	var graph := StoryGraph.build(docs, "main")
	assert_eq(graph.beats["main.paid"]["needs"], "full_story")
	assert_eq(graph.beats["main.start"]["needs"], "")
	var map: StoryMapView = track(StoryMapView.new())
	tree.root.add_child(map)
	map.show_story({"user://test_purchase_locks_tales/main.tale": PAID}, "main")
	await tree.process_frame
	var lock := map.get_beat_node("main.paid").find_child("Needs", true, false) as Label
	assert_not_null(lock)
	assert_eq(lock.text, "🔒 needs full_story")
	assert_null(map.get_beat_node("main.start").find_child("Needs", true, false))


func test_the_path_explorer_plays_both_ways() -> void:
	var config := StoryConfig.new()
	config.tales_folder = "user://test_purchase_locks_tales"
	config.product_folder = "res://no_such_folder"
	var product := StoryProduct.new()
	product.id = "full_story"
	config.products = [product]
	assert_true(TalePaths.sells_products(config))
	var paths: TalePaths = track(TalePaths.new())
	tree.root.add_child(paths)
	var report := await paths.explore(config, "main", "start", {"main": PAID})
	assert_eq(report["paths"], 2, "one without the product, one with it")
	assert_eq(report["endings"], {"main.start": 1, "main.paid": 1})
	assert_eq(report["unreached"], PackedStringArray())
	assert_eq(report["problems"], [])


func test_the_path_explorer_plays_once_without_products() -> void:
	var config := StoryConfig.new()
	config.tales_folder = "user://test_purchase_locks_tales"
	config.product_folder = "res://no_such_folder"
	assert_false(TalePaths.sells_products(config))
	var paths: TalePaths = track(TalePaths.new())
	tree.root.add_child(paths)
	var report := await paths.explore(config, "main", "start", {"main": "beat start:\n\t\"Only.\"\n"})
	assert_eq(report["paths"], 1)


func test_owner_paths_are_named_in_problems() -> void:
	var config := StoryConfig.new()
	config.tales_folder = "user://test_purchase_locks_tales"
	config.product_folder = "res://no_such_folder"
	var product := StoryProduct.new()
	product.id = "full_story"
	config.products = [product]
	var paths: TalePaths = track(TalePaths.new())
	tree.root.add_child(paths)
	var source := "beat start:\n\tif owns(\"full_story\"):\n\t\tmusic(\"no_such_track\")\n\t\"End.\"\n"
	var report := await paths.explore(config, "main", "start", {"main": source})
	assert_eq(report["problems"].size(), 1)
	assert_eq(report["problems"][0]["path"], PackedStringArray([TalePaths.OWNER_STEP]))

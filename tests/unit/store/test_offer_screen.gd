extends "res://tests/framework/story_test.gd"
## Tests for the purchase screen and Restore purchases in the menus.

const StoryScript := preload("res://addons/storyteller/core/story.gd")

var story: Node
var director: TaleDirector
var store: StoryStore
var test_store: TestStoreBackend
var menus: StoryMenus
var dialogue: StoryDialogue
var shown: Array[String] = []


func before_each() -> void:
	super()
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStore, StoryDialogue, StoryMenus]
	config.product_folder = "res://no_such_folder"
	var product := StoryProduct.new()
	product.id = "full_story"
	product.title = "The whole story"
	product.description = "Chapters two to five."
	config.products = [product]
	config.store = "none"
	config.text_speed = 0.0
	config.dialogue_box_transition = "none"
	config.start_tale = "main"
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	store = story.get_crew(&"Store")
	menus = story.get_crew(&"Menus")
	dialogue = story.get_crew(&"Dialogue")
	test_store = TestStoreBackend.new()
	test_store.path = ""
	await store.set_backend(test_store)
	shown.clear()
	director.line_started.connect(func(line: Dictionary) -> void: shown.append(line["text"]))
	await tree.process_frame


func _add(source: String) -> void:
	var result := TaleCompiler.build(source, "main", director.make_check_context("main"))
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail(str(diagnostic))
	director.add_tale(result["tale"])


func _press(button_text: String) -> void:
	var button := _button(button_text)
	if button == null or not button.is_visible_in_tree() or button.disabled:
		fail("no visible, enabled button '%s'" % button_text)
		return
	button.pressed.emit()
	await tree.process_frame
	await tree.process_frame


func _button(button_text: String) -> Button:
	for button in story.find_children("*", "Button", true, false):
		if button.text == button_text and button.is_visible_in_tree():
			return button
	return null


func _continue() -> void:
	dialogue.dialogue_box.continue_pressed.emit()
	await tree.process_frame


func _screen() -> OfferScreen:
	return story.find_child("OfferScreen", true, false) as OfferScreen


func test_the_screen_shows_the_product_and_price() -> void:
	_add("beat start:\n\toffer(\"full_story\")\n\t\"After.\"\n")
	director.play("main")
	await tree.process_frame
	var screen := _screen()
	assert_true(screen.is_visible_in_tree())
	var texts := screen.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	assert_has(texts, "The whole story")
	assert_has(texts, "Chapters two to five.")
	assert_has(texts, "$4.99")
	await _press("Not now")
	assert_false(screen.visible)
	assert_eq(shown, ["After."])


func test_buying_from_the_screen_unlocks_a_needs_beat() -> void:
	_add("beat start:\n\t\"Free.\"\n\tjump paid\n\n@needs(\"full_story\")\nbeat paid:\n\t\"Paid.\"\n")
	director.play("main")
	await tree.process_frame
	await _continue()
	assert_true(_screen().is_visible_in_tree())
	await _press("Buy")
	assert_true(store.owns("full_story"))
	assert_false(menus.is_open())
	assert_eq(shown, ["Free.", "Paid."])


func test_not_now_at_a_needs_beat_returns_to_the_title() -> void:
	_add("beat start:\n\t\"Free.\"\n\tjump paid\n\n@needs(\"full_story\")\nbeat paid:\n\t\"Paid.\"\n")
	director.play("main")
	await tree.process_frame
	await _continue()
	await _press("Not now")
	await tree.process_frame
	assert_eq(shown, ["Free."])
	assert_true(menus.is_title_showing())


func test_a_failed_purchase_keeps_the_screen_open() -> void:
	_add("beat start:\n\toffer(\"full_story\")\n\t\"After.\"\n")
	director.play("main")
	await tree.process_frame
	test_store.next_result = StoreBackend.Result.FAILED
	await _press("Buy")
	var message := _screen().find_child("Message", true, false) as Label
	assert_true(message.visible)
	assert_eq(message.text, "The purchase didn't go through. Please try again.")
	assert_true(_screen().is_visible_in_tree(), "still open")
	await _press("Buy")
	assert_false(_screen().visible)
	assert_true(store.owns("full_story"))


func test_a_pending_purchase_closes_with_a_notice() -> void:
	_add("beat start:\n\tif await offer(\"full_story\"):\n\t\t\"Bought.\"\n\telse:\n\t\t\"Not yet.\"\n")
	director.play("main")
	await tree.process_frame
	test_store.next_result = StoreBackend.Result.PENDING
	await _press("Buy")
	assert_eq(shown, ["Not yet."])
	assert_eq(menus.get_notices(), PackedStringArray(["Your purchase is waiting for the store to confirm it."]))


func test_restore_purchases_shows_on_the_title_and_pause_menus() -> void:
	_add("beat start:\n\t\"Line.\"\n")
	menus.show_title()
	await tree.process_frame
	assert_not_null(_button("Restore purchases"), "on the title screen")
	await _press("Restore purchases")
	assert_eq(menus.get_notices(), PackedStringArray(["Purchases restored."]))
	await _press("New Game")
	menus.open("pause")
	await tree.process_frame
	assert_not_null(_button("Restore purchases"), "in the pause menu")


func test_no_restore_button_without_products() -> void:
	store._products.clear()
	menus.show_title()
	await tree.process_frame
	assert_null(_button("Restore purchases"))

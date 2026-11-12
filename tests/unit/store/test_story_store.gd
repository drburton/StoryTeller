extends "res://tests/framework/story_test.gd"
## Tests for demos and purchases (decision 0029): the Store crew member,
## the test store, owns(), offer(), and @needs.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")

var story: Node
var director: TaleDirector
var store: StoryStore
var test_store: TestStoreBackend
var presenter: ScriptedPresenter
var errors: Array[String] = []


func before_each() -> void:
	super()
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStore]
	config.product_folder = "res://no_such_folder"
	config.products = [_product("full_story", "The whole story"), _product("bonus", "A bonus chapter")]
	config.store = "none"
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	store = story.get_crew(&"Store")
	test_store = TestStoreBackend.new()
	test_store.path = ""
	await store.set_backend(test_store)
	presenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	director.presenter = presenter
	errors.clear()
	director.runtime_error.connect(func(message: String, _tale: String, line: int) -> void:
		errors.append("%d: %s" % [line, message]))


static func _product(id: String, title: String) -> StoryProduct:
	var product := StoryProduct.new()
	product.id = id
	product.title = title
	return product


func _play(source: String) -> void:
	var result := TaleCompiler.build(source, "main", director.make_check_context("main"))
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail(str(diagnostic))
			return
	director.add_tale(result["tale"])
	await director.play("main")


func test_the_reader_owns_nothing_at_first() -> void:
	assert_false(store.owns("full_story"))
	assert_eq(store.get_products().map(func(p: StoryProduct) -> String: return p.id), ["bonus", "full_story"])
	assert_eq(store.get_price("full_story"), "$4.99", "the test store's price")


func test_buying_makes_the_reader_own_it() -> void:
	var changes := [0]
	store.ownership_changed.connect(func() -> void: changes[0] += 1)
	assert_eq(await store.purchase("full_story"), StoreBackend.Result.BOUGHT)
	assert_true(store.owns("full_story"))
	assert_false(store.owns("bonus"))
	assert_eq(changes[0], 1)


func test_a_refund_locks_it_again() -> void:
	test_store.set_owned("bonus", true)
	assert_true(store.owns("bonus"))
	test_store.set_owned("bonus", false)
	assert_false(store.owns("bonus"))


func test_a_cancelled_purchase_owns_nothing() -> void:
	test_store.next_result = StoreBackend.Result.CANCELLED
	assert_eq(await store.purchase("full_story"), StoreBackend.Result.CANCELLED)
	assert_false(store.owns("full_story"))
	assert_eq(await store.purchase("full_story"), StoreBackend.Result.BOUGHT, "the next one goes through")


func test_the_test_store_keeps_what_was_bought() -> void:
	var path := "user://test_store_keeps.cfg"
	var first := TestStoreBackend.new()
	first.path = path
	first.start()
	first.set_owned("bonus", true)
	var second := TestStoreBackend.new()
	second.path = path
	second.start()
	assert_true(second.owns("bonus"))
	DirAccess.remove_absolute(path)


func test_ownership_is_kept_with_the_global_data() -> void:
	test_store.set_owned("full_story", true)
	var saved := store.capture_globals()
	assert_eq(saved, {"owned": ["full_story"]})
	await store.set_backend(OfflineBackend.new())
	store.restore_globals({"owned": ["bonus"]})
	assert_true(store.owns("bonus"), "used while the store hasn't answered")
	assert_false(store.owns("full_story"))


func test_the_store_wins_over_the_global_data() -> void:
	store.restore_globals({"owned": ["full_story"]})
	assert_false(store.owns("full_story"))


func test_offer_buys_without_menus() -> void:
	assert_true(await store.offer("full_story"))
	assert_true(store.owns("full_story"))


func test_offer_of_something_owned_buys_nothing() -> void:
	test_store.set_owned("full_story", true)
	test_store.next_result = StoreBackend.Result.FAILED
	assert_true(await store.offer("full_story"))


func test_owns_in_a_tale() -> void:
	await _play("beat start:\n\tif owns(\"full_story\"):\n\t\t\"Full.\"\n\telse:\n\t\t\"Demo.\"\n")
	test_store.set_owned("full_story", true)
	await _play("beat start:\n\tif owns(\"full_story\"):\n\t\t\"Full.\"\n\telse:\n\t\t\"Demo.\"\n")
	assert_eq(presenter.lines, ["Demo.", "Full."])
	assert_eq(errors, [])


func test_offer_in_a_tale() -> void:
	test_store.next_result = StoreBackend.Result.CANCELLED
	await _play("beat start:\n\tif await offer(\"bonus\"):\n\t\t\"Bought.\"\n\telse:\n\t\t\"Maybe later.\"\n\tif await offer(\"bonus\"):\n\t\t\"Bought.\"\n")
	assert_eq(presenter.lines, ["Maybe later.", "Bought."])
	assert_eq(errors, [])


func test_offer_of_an_unknown_product_is_an_error() -> void:
	await _play("beat start:\n\toffer(\"nope\")\n\t\"After.\"\n")
	assert_eq(errors, ["2: There is no product 'nope' in res://no_such_folder."])


func test_a_needs_beat_plays_for_owners() -> void:
	test_store.set_owned("full_story", true)
	await _play("beat start:\n\t\"Free.\"\n\tjump paid\n\n@needs(\"full_story\")\nbeat paid:\n\t\"Paid.\"\n")
	assert_eq(presenter.lines, ["Free.", "Paid."])


func test_a_needs_beat_offers_the_product() -> void:
	await _play("beat start:\n\t\"Free.\"\n\tjump paid\n\n@needs(\"full_story\")\nbeat paid:\n\t\"Paid.\"\n")
	assert_eq(presenter.lines, ["Free.", "Paid."], "bought on the way in")
	assert_true(store.owns("full_story"))


func test_a_needs_beat_ends_the_story_when_not_bought() -> void:
	var locked: Array = []
	director.beat_locked.connect(func(tale: String, beat: String, product: String) -> void: locked.append([tale, beat, product]))
	test_store.next_result = StoreBackend.Result.CANCELLED
	await _play("beat start:\n\t\"Free.\"\n\tpaid()\n\t\"Never.\"\n\n@needs(\"full_story\")\nbeat paid:\n\t\"Paid.\"\n")
	assert_eq(presenter.lines, ["Free."])
	assert_eq(locked, [["main", "paid", "full_story"]])
	assert_false(director.is_playing())


func test_playing_a_needs_beat_directly_is_locked_too() -> void:
	test_store.next_result = StoreBackend.Result.CANCELLED
	await _play("@needs(\"full_story\")\nbeat start:\n\t\"Paid.\"\n")
	assert_eq(presenter.lines, [])


func test_without_a_store_needs_beats_are_locked() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector]
	var bare: Node = track(StoryScript.new())
	bare.start(config)
	tree.root.add_child(bare)
	director = bare.get_crew(&"TaleDirector")
	director.presenter = presenter
	await _play("beat start:\n\t\"Free.\"\n\tif owns(\"full_story\"):\n\t\t\"Never.\"\n\tjump paid\n\n@needs(\"full_story\")\nbeat paid:\n\t\"Paid.\"\n")
	assert_eq(presenter.lines, ["Free."])


func test_the_checker_knows_owns_and_needs() -> void:
	var context := director.make_check_context("main")
	var ids := ["full_story"]
	context.add_asset_check("offer", "id", func(id: String) -> String:
		return "" if id in ids else "There is no product '%s'." % id)
	var source := "@needs(\"full_story\")\nbeat start:\n\tif owns(\"bonsu\"):\n\t\toffer(\"chapter\")\n\t@needs(\"full_story\")\n\t\"Line.\"\n\n@needs\nbeat other:\n\tpass\n\n@needs(\"extra\")\nbeat third:\n\tpass\n"
	var messages: Array[String] = []
	for diagnostic in TaleCompiler.build(source, "main", context)["diagnostics"]:
		messages.append("%d: %s" % [diagnostic.line, diagnostic.message])
	assert_eq(messages, [
		"3: There is no product 'bonsu'.",
		"4: There is no product 'chapter'.",
		"5: @needs only applies to beats.",
		"8: @needs needs one text argument, e.g. @needs(\"...\").",
		"12: There is no product 'extra'.",
	])


func test_console_store_commands() -> void:
	var console := StoryConsole.new()
	story.add_child(console)
	var log: Array[String] = []
	console.printed.connect(func(text: String) -> void: log.append(text))
	await console.run_command("store own bonus")
	assert_true(store.owns("bonus"))
	await console.run_command("store")
	assert_has(log, "  bonus  owned")
	assert_has(log, "  full_story  not owned")
	await console.run_command("store drop bonus")
	assert_false(store.owns("bonus"))
	await console.run_command("store own full_story")
	await console.run_command("store reset")
	assert_false(store.owns("full_story"))
	console.free()


func test_scan_finds_products_and_names_them() -> void:
	var folder := "user://test_store_products"
	DirAccess.make_dir_recursive_absolute(folder)
	ResourceSaver.save(StoryProduct.new(), folder.path_join("chapter_two.tres"))
	var found := StoryStore.scan(folder)
	assert_eq(found.keys(), ["chapter_two"])
	assert_eq(found["chapter_two"].title, "Chapter Two")
	DirAccess.remove_absolute(folder.path_join("chapter_two.tres"))


## A store that hasn't answered yet, such as one with no connection.
class OfflineBackend extends StoreBackend:
	func is_ready() -> bool:
		return false

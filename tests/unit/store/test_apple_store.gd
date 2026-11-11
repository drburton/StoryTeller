extends "res://tests/framework/story_test.gd"
## Tests for AppleStoreBackend, with a stand-in for the Godot StoreKit 2
## plugin, which only exists in iOS and macOS exports.

const State := AppleStoreBackend.TransactionState
const StoryScript := preload("res://addons/storyteller/core/story.gd")

var kit: FakeStoreKit
var backend: AppleStoreBackend


func before_each() -> void:
	super()
	kit = FakeStoreKit.new()
	kit.catalog = {
		"com.example.full": {"price": "$4.99", "purchased": false},
		"bonus": {"price": "$0.99", "purchased": false},
	}
	backend = AppleStoreBackend.new()
	backend.plugin = kit
	backend.products = {
		"full_story": _product("full_story", "com.example.full"),
		"bonus": _product("bonus", ""),
	}


static func _product(id: String, apple_id: String) -> StoryProduct:
	var product := StoryProduct.new()
	product.id = id
	product.apple_id = apple_id
	return product


func test_start_asks_for_prices_and_ownership() -> void:
	kit.catalog["bonus"]["purchased"] = true
	assert_false(backend.is_ready())
	await backend.start()
	assert_true(backend.is_ready())
	assert_eq(kit.asked, ["com.example.full", "bonus"], "the apple_id, or the product's own id")
	assert_eq(backend.get_price("full_story"), "$4.99")
	assert_false(backend.owns("full_story"))
	assert_true(backend.owns("bonus"), "bought before")


func test_buying() -> void:
	await backend.start()
	assert_eq(await backend.purchase("full_story"), StoreBackend.Result.BOUGHT)
	assert_true(backend.owns("full_story"))
	assert_eq(kit.bought, ["com.example.full"])


func test_cancelled_pending_and_failed_purchases() -> void:
	await backend.start()
	kit.next_state = State.CANCELLED
	assert_eq(await backend.purchase("full_story"), StoreBackend.Result.CANCELLED)
	kit.next_state = State.PENDING
	assert_eq(await backend.purchase("full_story"), StoreBackend.Result.PENDING)
	kit.next_state = State.FAILED
	assert_eq(await backend.purchase("full_story"), StoreBackend.Result.FAILED)
	kit.next_error = "Network unavailable"
	assert_eq(await backend.purchase("full_story"), StoreBackend.Result.FAILED)
	assert_false(backend.owns("full_story"))


func test_a_purchase_waits_for_its_own_transaction() -> void:
	await backend.start()
	kit.before_next = {"error": "", "product_id": "bonus", "transaction_state": State.PURCHASED}
	assert_eq(await backend.purchase("full_story"), StoreBackend.Result.BOUGHT)
	assert_true(backend.owns("full_story"))
	assert_true(backend.owns("bonus"), "the other transaction counts too")


func test_an_approved_ask_to_buy_arrives_later() -> void:
	await backend.start()
	kit.next_state = State.PENDING
	assert_eq(await backend.purchase("full_story"), StoreBackend.Result.PENDING)
	var changes := [0]
	backend.changed.connect(func() -> void: changes[0] += 1)
	kit.transaction_state_changed.emit({"error": "", "product_id": "com.example.full", "transaction_state": State.PURCHASED})
	assert_true(backend.owns("full_story"))
	assert_eq(changes[0], 1)


func test_a_refund_locks_it_again() -> void:
	kit.catalog["com.example.full"]["purchased"] = true
	await backend.start()
	var changes := [0]
	backend.changed.connect(func() -> void: changes[0] += 1)
	kit.transaction_state_changed.emit({"error": "", "product_id": "com.example.full", "transaction_state": State.REFUNDED})
	assert_false(backend.owns("full_story"))
	kit.transaction_state_changed.emit({"error": "", "product_id": "com.example.other_game", "transaction_state": State.REFUNDED})
	assert_eq(changes[0], 1, "transactions for other products are ignored")


func test_restore_syncs_and_asks_again() -> void:
	await backend.start()
	assert_true(backend.can_restore())
	kit.catalog["bonus"]["purchased"] = true
	var changes := [0]
	backend.changed.connect(func() -> void: changes[0] += 1)
	await backend.restore()
	assert_eq(kit.syncs, 1)
	assert_true(backend.owns("bonus"))
	assert_eq(changes[0], 1)


func test_a_product_missing_from_the_app_store_is_not_owned() -> void:
	kit.catalog.erase("bonus")
	await backend.start()
	assert_true(backend.is_ready())
	assert_false(backend.owns("bonus"))
	assert_eq(backend.get_price("bonus"), "")


func test_without_the_plugin_nothing_can_be_bought() -> void:
	var bare := AppleStoreBackend.new()
	bare.products = backend.products
	if not AppleStoreBackend.is_available():
		await bare.start()
		assert_false(bare.is_ready())
		assert_false(bare.can_restore())
		assert_eq(await bare.purchase("full_story"), StoreBackend.Result.FAILED)


func test_the_store_crew_member_sells_through_it() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStore]
	config.product_folder = "res://no_such_folder"
	config.products = [backend.products["full_story"]]
	config.store = "none"
	var story: Node = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	var store: StoryStore = story.get_crew(&"Store")
	var apple := AppleStoreBackend.new()
	apple.plugin = kit
	await store.set_backend(apple)
	assert_eq(store.get_price("full_story"), "$4.99")
	assert_true(await store.offer("full_story"))
	assert_true(store.owns("full_story"))
	kit.transaction_state_changed.emit({"error": "", "product_id": "com.example.full", "transaction_state": State.REFUNDED})
	assert_false(store.owns("full_story"), "the crew member hears about the refund")


func test_config_picks_the_backend() -> void:
	var config := StoryConfig.new()
	config.store = "apple"
	assert_true(StoryStore.make_backend(config) is AppleStoreBackend)
	config.store = "auto"
	assert_true(StoryStore.make_backend(config) is TestStoreBackend, "running from the editor")


## Stands in for the plugin's GodotStoreKit2 object: the same methods and
## signals, answering from [member catalog] at the end of the frame.
class FakeStoreKit extends RefCounted:
	signal product_info_received(product_info: Dictionary)
	signal transaction_state_changed(transaction: Dictionary)
	signal synchronized

	## App Store product id to {"price", "purchased"}.
	var catalog := {}
	var next_state := State.PURCHASED
	var next_error := ""
	## A transaction for another product reported just before the next one.
	var before_next := {}
	var asked: Array[String] = []
	var bought: Array[String] = []
	var syncs := 0

	func request_product_info(product_id: String) -> Signal:
		asked.append(product_id)
		var info := {"error": "No product with id %s." % product_id}
		if catalog.has(product_id):
			info = {"error": "", "product_id": product_id, "display_name": product_id,
				"localized_price": catalog[product_id]["price"], "is_purchased": catalog[product_id]["purchased"]}
		product_info_received.emit.call_deferred(info)
		return product_info_received

	func purchase_product(product_id: String, _quantity: int) -> Signal:
		var transaction := {"error": next_error} if not next_error.is_empty() else \
			{"error": "", "product_id": product_id, "transaction_state": next_state}
		if next_error.is_empty() and next_state == State.PURCHASED:
			bought.append(product_id)
			catalog[product_id]["purchased"] = true
		next_state = State.PURCHASED
		next_error = ""
		if not before_next.is_empty():
			transaction_state_changed.emit.call_deferred(before_next)
			before_next = {}
		transaction_state_changed.emit.call_deferred(transaction)
		return transaction_state_changed

	func sync() -> Signal:
		syncs += 1
		synchronized.emit.call_deferred()
		return synchronized

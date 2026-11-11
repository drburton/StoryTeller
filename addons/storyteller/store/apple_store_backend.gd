class_name AppleStoreBackend
extends StoreBackend
## Sells through the Apple App Store with StoreKit 2, using the Godot
## StoreKit 2 plugin (github.com/godot-sdk-integrations/godot-storekit2).
## Install its release into the project's [code]ios/plugins[/code] folder
## and turn it on under Plugins in the iOS export preset.
##
## Each [StoryProduct] is sold under its [member StoryProduct.apple_id],
## the product id in App Store Connect, or under its own id when that is
## empty. Create each one there as a non-consumable in-app purchase.
##
## The plugin's API is still a draft (v0.2), so everything that depends on
## it is kept in this class.

## Name of the plugin's class.
const PLUGIN_CLASS := "GodotStoreKit2"

## The plugin's TransactionState values.
enum TransactionState { FAILED, REFUNDED, PENDING, PURCHASED, RESTORED, EXPIRED, CANCELLED }

## The plugin's object. Tests set a stand-in before [method start].
var plugin: Object

var _answered := false
var _owned: Dictionary = {}
var _prices: Dictionary = {}


## True when the plugin is in this build: an iOS or macOS export with the
## plugin turned on.
static func is_available() -> bool:
	return ClassDB.class_exists(PLUGIN_CLASS)


func get_store_name() -> String:
	return "apple"


func start() -> void:
	if plugin == null and is_available():
		plugin = ClassDB.instantiate(PLUGIN_CLASS)
	if plugin == null:
		push_error("StoryTeller: the Godot StoreKit 2 plugin is not in this build, so nothing can be bought.")
		return
	# Refunds, revoked purchases, Ask to Buy approvals, and purchases made on
	# another device arrive through this signal at any time, also at launch.
	plugin.transaction_state_changed.connect(_on_transaction)
	await _ask_products()
	_answered = true


func is_ready() -> bool:
	return _answered


func owns(id: String) -> bool:
	return _owned.has(id)


func get_price(id: String) -> String:
	return _prices.get(id, "")


func purchase(id: String) -> Result:
	if plugin == null or not products.has(id):
		return Result.FAILED
	var apple_id := store_id(products[id])
	var transaction: Dictionary = await plugin.purchase_product(apple_id, 1)
	# The signal reports every transaction, so wait for this product's.
	while not transaction.get("error", "") and transaction.get("product_id", "") != apple_id:
		transaction = await plugin.transaction_state_changed
	if transaction.get("error", ""):
		push_warning("StoryTeller: App Store purchase of '%s' failed: %s" % [apple_id, transaction["error"]])
		return Result.FAILED
	match int(transaction.get("transaction_state", TransactionState.FAILED)):
		TransactionState.PURCHASED, TransactionState.RESTORED:
			_owned[id] = true
			return Result.BOUGHT
		TransactionState.PENDING:
			return Result.PENDING
		TransactionState.CANCELLED:
			return Result.CANCELLED
	return Result.FAILED


func can_restore() -> bool:
	return plugin != null


## Syncs with the App Store, which asks the reader to sign in, so only call
## it when they press Restore purchases.
func restore() -> void:
	if plugin == null:
		return
	await plugin.sync()
	await _ask_products()
	changed.emit()


## The App Store product id for [param product].
static func store_id(product: StoryProduct) -> String:
	return product.apple_id if not product.apple_id.is_empty() else product.id


## Asks the App Store for each product's price and whether the reader owns
## it. Awaitable.
func _ask_products() -> void:
	for id in products:
		var info: Dictionary = await plugin.request_product_info(store_id(products[id]))
		if info.get("error", ""):
			push_warning("StoryTeller: the App Store has no product '%s': %s" % [store_id(products[id]), info["error"]])
			continue
		_prices[id] = str(info.get("localized_price", ""))
		if info.get("is_purchased", false):
			_owned[id] = true
		else:
			_owned.erase(id)


func _on_transaction(transaction: Dictionary) -> void:
	if transaction.get("error", ""):
		return
	var id := _product_for(str(transaction.get("product_id", "")))
	if id.is_empty():
		return
	match int(transaction.get("transaction_state", TransactionState.FAILED)):
		TransactionState.PURCHASED, TransactionState.RESTORED:
			if _owned.has(id):
				return
			_owned[id] = true
		TransactionState.REFUNDED, TransactionState.EXPIRED:
			if not _owned.has(id):
				return
			_owned.erase(id)
		_:
			return
	changed.emit()


## The [StoryProduct] id sold under [param apple_id], or "".
func _product_for(apple_id: String) -> String:
	for id in products:
		if store_id(products[id]) == apple_id:
			return id
	return ""

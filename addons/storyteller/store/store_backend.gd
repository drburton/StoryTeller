class_name StoreBackend
extends RefCounted
## Connects [StoryStore] to one store, such as Steam or the test store.
##
## This base class sells nothing and owns nothing, which is what a game
## without a store gets. A backend for another storefront or a game's own
## key system extends it and is set in [member StoryConfig.store_backend].

## Emitted when what the reader owns may have changed, for example after a
## purchase, a refund, or restoring purchases.
signal changed

## What [method purchase] gives back.
enum Result {
	## The reader owns the product now.
	BOUGHT,
	## The reader closed the store without buying.
	CANCELLED,
	## The store is still confirming the purchase, for example a payment
	## by bank transfer. [signal changed] tells when it goes through.
	PENDING,
	## Something went wrong, such as no connection.
	FAILED,
}

## Products by id, set by [StoryStore] before [method start].
var products: Dictionary[String, StoryProduct] = {}


## Name shown by the debug console.
func get_store_name() -> String:
	return "none"


## Connects to the store. Awaitable.
func start() -> void:
	pass


## True when the store has answered, so [method owns] can be trusted.
## While it is false, [StoryStore] uses what the reader owned last time.
func is_ready() -> bool:
	return true


## True when the reader owns the product [param id].
func owns(_id: String) -> bool:
	return false


## The store's price for [param id], ready to show, or "".
func get_price(_id: String) -> String:
	return ""


## Asks the store to sell [param id]. Awaitable; returns a [enum Result].
func purchase(_id: String) -> Result:
	return Result.FAILED


## True when the store can restore purchases made on another device or
## before a reinstall. Apple requires a button for it.
func can_restore() -> bool:
	return false


## Asks the store for everything the reader bought. Awaitable.
func restore() -> void:
	pass

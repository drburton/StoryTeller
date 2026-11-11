class_name TestStoreBackend
extends StoreBackend
## A pretend store for making and testing a game without a store account.
## Buying always works unless [member next_result] says otherwise. What the
## reader owns is kept in [member path], so it survives restarting the game.
## The debug console's [code]store[/code] commands change it.

## File that keeps what the reader owns, or "" to keep it in memory only.
var path := "user://test_store.cfg"
## What the next [method purchase] gives, to try out a cancelled, pending,
## or failed purchase.
var next_result := Result.BOUGHT

var _owned: Dictionary = {}


func get_store_name() -> String:
	return "test"


func start() -> void:
	_owned.clear()
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var file := ConfigFile.new()
	if file.load(path) == OK:
		for id in file.get_value("store", "owned", []):
			_owned[str(id)] = true


func owns(id: String) -> bool:
	return _owned.has(id)


func get_price(id: String) -> String:
	return products[id].test_price if products.has(id) else ""


func purchase(id: String) -> Result:
	var result := next_result
	next_result = Result.BOUGHT
	if result == Result.BOUGHT:
		set_owned(id, true)
	return result


func can_restore() -> bool:
	return true


func restore() -> void:
	changed.emit()


## Gives or takes away [param id], as a purchase or a refund would.
func set_owned(id: String, owned: bool) -> void:
	if owned == _owned.has(id):
		return
	if owned:
		_owned[id] = true
	else:
		_owned.erase(id)
	_save()
	changed.emit()


## Takes away everything, as on a new account.
func reset() -> void:
	_owned.clear()
	_save()
	changed.emit()


func _save() -> void:
	if path.is_empty():
		return
	var file := ConfigFile.new()
	file.set_value("store", "owned", _owned.keys())
	file.save(path)

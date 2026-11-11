class_name StoryStore
extends StoryCrew
## Crew member for demos and purchases (decision 0029): what the reader
## owns, and buying more. Paid content ships in the game, locked until the
## reader buys its [StoryProduct].
##
## [codeblock]
## if owns("full_story"):
##     jump chapter_2
## if await offer("full_story"):    # shows the purchase screen
##     jump chapter_2
##
## @needs("full_story")             # entering it without the product
## beat chapter_2:                  # shows the purchase screen
## [/codeblock]
## The store decides what the reader owns. The last answer is kept with the
## global data, so the game still works offline.

## Emitted when what the reader owns changes.
signal ownership_changed
## Emitted when data kept across playthroughs changes.
signal globals_changed

var product_folder := "res://story/products"
## The store this game sells through. See [member StoryConfig.store].
var backend: StoreBackend

var _products: Dictionary[String, StoryProduct] = {}
## Product ids the reader owned when the store last answered.
var _owned: Dictionary = {}


func get_crew_name() -> StringName:
	return &"Store"


func setup(config: StoryConfig) -> void:
	product_folder = config.product_folder
	_products = scan(product_folder)
	for product in config.products:
		if product != null:
			add_product(product)
	set_backend(make_backend(config))


## The backend [param config] asks for: its
## [member StoryConfig.store_backend] script, or one named by
## [member StoryConfig.store]. "auto" uses the test store when the game
## runs from the editor, and no store otherwise.
static func make_backend(config: StoryConfig) -> StoreBackend:
	if config.store_backend != null:
		var made: Variant = config.store_backend.new()
		if made is StoreBackend:
			return made
		push_error("StoryTeller: StoryConfig.store_backend must extend StoreBackend.")
	match config.store:
		"test":
			return TestStoreBackend.new()
		"auto":
			return TestStoreBackend.new() if OS.has_feature("editor") else StoreBackend.new()
		"none":
			return StoreBackend.new()
	push_error("StoryTeller: unknown store '%s' in StoryConfig.store." % config.store)
	return StoreBackend.new()


## Switches to [param new_backend] and asks it what the reader owns.
## Awaitable.
func set_backend(new_backend: StoreBackend) -> void:
	if backend != null and backend.changed.is_connected(refresh):
		backend.changed.disconnect(refresh)
	backend = new_backend
	backend.products = _products
	backend.changed.connect(refresh)
	await backend.start()
	refresh()


## Asks the backend again what the reader owns.
func refresh() -> void:
	if backend == null or not backend.is_ready():
		return
	var owned := {}
	for id in _products:
		if backend.owns(id):
			owned[id] = true
	if owned == _owned:
		return
	_owned = owned
	ownership_changed.emit()
	globals_changed.emit()


## True when the reader owns [param id]. Always false in an export with the
## [code]demo[/code] feature tag, a separate demo build.
func owns(id: String) -> bool:
	if is_demo_build():
		return false
	return _owned.has(id)


## True in an export with the [code]demo[/code] feature tag.
static func is_demo_build() -> bool:
	return OS.has_feature("demo")


## Offers [param id] to the reader on the purchase screen. Awaitable;
## returns true when they own it afterwards. Returns true at once when
## they already do. Without the Menus crew member, it buys straight away.
func offer(id: String) -> bool:
	if owns(id):
		return true
	if not _products.has(id):
		push_error("StoryTeller: there is no product '%s' in %s." % [id, product_folder])
		return false
	var menus := _crew(&"Menus")
	if menus != null and menus.has_method("offer"):
		await menus.offer(_products[id])
	elif not is_demo_build():
		await purchase(id)
	return owns(id)


## Buys [param id] through the backend. Awaitable; returns a
## [enum StoreBackend.Result].
func purchase(id: String) -> StoreBackend.Result:
	if is_demo_build() or backend == null:
		return StoreBackend.Result.FAILED
	var result: StoreBackend.Result = await backend.purchase(id)
	refresh()
	return result


func can_restore() -> bool:
	return backend != null and backend.can_restore() and not _products.is_empty() and not is_demo_build()


## Asks the store for everything the reader bought. Awaitable.
func restore_purchases() -> void:
	if backend != null:
		await backend.restore()
		refresh()


## The store's price for [param id], ready to show, or "".
func get_price(id: String) -> String:
	return backend.get_price(id) if backend != null else ""


func has_product(id: String) -> bool:
	return _products.has(id)


func get_product(id: String) -> StoryProduct:
	return _products.get(id)


## Every product, sorted by id.
func get_products() -> Array[StoryProduct]:
	var ids := _products.keys()
	ids.sort()
	var result: Array[StoryProduct] = []
	for id in ids:
		result.append(_products[id])
	return result


## Adds a product in code, replacing one with the same id.
func add_product(product: StoryProduct) -> void:
	if product.id.is_empty():
		push_error("StoryTeller: a StoryProduct needs an id.")
		return
	_products[product.id] = product


func capture_globals() -> Dictionary:
	return {"owned": _owned.keys()}


func restore_globals(data: Dictionary) -> void:
	# The store's answer wins; this is only for when it hasn't answered yet.
	if backend != null and backend.is_ready():
		return
	_owned.clear()
	for id in data.get("owned", []):
		_owned[str(id)] = true


## Finds [StoryProduct] files in [param folder].
static func scan(folder: String) -> Dictionary[String, StoryProduct]:
	var products: Dictionary[String, StoryProduct] = {}
	if not DirAccess.dir_exists_absolute(folder):
		return products
	for file_name in ResourceLoader.list_directory(folder):
		if file_name.get_extension() not in ["tres", "res"]:
			continue
		var product := load(folder.path_join(file_name)) as StoryProduct
		if product == null:
			continue
		if product.id.is_empty():
			product.id = file_name.get_basename()
		if product.title.is_empty():
			product.title = product.id.capitalize()
		products[product.id] = product
	return products


func _crew(crew_name: StringName) -> Node:
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(crew_name)
	return null

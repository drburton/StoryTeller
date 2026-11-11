class_name OfferScreen
extends MenuScreen
## The purchase screen: a product's picture, title, description, and price,
## with Buy and Not now. Opened by offer() in tales and @needs beats,
## through [method StoryMenus.offer].
##
## A game can use its own scene instead ([member StoryConfig.offer_scene]):
## its root extends this class, overrides [method _ready] and
## [method open] to build and fill its own controls, and calls
## [method buy] and [method decline].

## Emitted when the screen is done. [param bought] is true when the reader
## owns the product.
signal answered(bought: bool)

## The product on offer.
var product: StoryProduct
## The store selling it.
var store: StoryStore

var _picture: TextureRect
var _title: Label
var _description: Label
var _price: Label
var _message: Label
var _buy: Button
var _decline: Button


func _ready() -> void:
	add_dim(0.6)
	var column := add_center_panel(460)
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.custom_minimum_size = Vector2(0, 200)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_picture)
	_title = MenuScreen.make_title("", 26)
	column.add_child(_title)
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_description)
	_price = MenuScreen.make_title("", 22)
	_price.name = "Price"
	column.add_child(_price)
	_message = Label.new()
	_message.name = "Message"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	_buy = MenuScreen.make_button("Buy", buy)
	_buy.name = "Buy"
	buttons.add_child(_buy)
	_decline = MenuScreen.make_button("Not now", decline)
	_decline.name = "NotNow"
	buttons.add_child(_decline)
	column.add_child(buttons)


func open() -> void:
	var demo := StoryStore.is_demo_build()
	_picture.texture = product.picture
	_picture.visible = product.picture != null
	_title.text = tr(product.title)
	_description.text = tr(product.description)
	_description.visible = not product.description.is_empty()
	_price.text = store.get_price(product.id) if not demo else ""
	_price.visible = not _price.text.is_empty()
	_message.text = tr("The full game is a separate purchase.") if demo else ""
	_message.visible = demo
	_buy.visible = not demo
	_buy.disabled = false
	_decline.disabled = false
	_decline.text = "OK" if demo else "Not now"
	focus_first()


## Asks the store to sell the product, and closes the screen when the
## reader owns it. Awaitable.
func buy() -> void:
	_set_busy(true)
	var result: StoreBackend.Result = await store.purchase(product.id)
	_set_busy(false)
	match result:
		StoreBackend.Result.BOUGHT:
			answered.emit(true)
		StoreBackend.Result.PENDING:
			menus.show_notice(tr("Your purchase is waiting for the store to confirm it."))
			answered.emit(false)
		StoreBackend.Result.FAILED:
			_show_message(tr("The purchase didn't go through. Please try again."))


## Closes the screen without buying.
func decline() -> void:
	answered.emit(store.owns(product.id))


func on_back() -> bool:
	decline()
	return false


func _set_busy(busy: bool) -> void:
	if _buy != null:
		_buy.disabled = busy
	if _decline != null:
		_decline.disabled = busy


func _show_message(text: String) -> void:
	if _message != null:
		_message.text = text
		_message.visible = true

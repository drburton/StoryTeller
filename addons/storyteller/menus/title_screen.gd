class_name TitleScreen
extends MenuScreen
## The title screen: New Game, Continue, Load, Extras (when the game has a
## collection), Settings, and Quit, over [member StoryConfig.title_background]
## when the game sets one. [StoryMenus] plays [member StoryConfig.title_music].

var _continue: Button
var _load: Button
var _extras: Button
var _title: Label
var _art: TextureRect
var _wash: ColorRect


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.07, 0.1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_art = TextureRect.new()
	_art.name = "Art"
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	# Darkens the art a little so the title and buttons stay readable.
	_wash = ColorRect.new()
	_wash.color = Color(0, 0, 0, 0.35)
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wash)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(320, 0)
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	_title = MenuScreen.make_title("", 44)
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	column.add_child(_title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	column.add_child(spacer)
	column.add_child(MenuScreen.make_button("New Game", func() -> void: menus.start_new_game()))
	_continue = MenuScreen.make_button("Continue", func() -> void: menus.continue_game())
	column.add_child(_continue)
	_load = MenuScreen.make_button("Load", func() -> void: menus.open("load"))
	column.add_child(_load)
	_extras = MenuScreen.make_button("Extras", func() -> void: menus.open("extras"))
	column.add_child(_extras)
	column.add_child(MenuScreen.make_button("Settings", func() -> void: menus.open("settings")))
	if menus.can_quit():
		column.add_child(MenuScreen.make_button("Quit", func() -> void: menus.quit_game()))


func open() -> void:
	_title.text = menus.get_game_title()
	_art.texture = menus.title_background
	_art.visible = menus.title_background != null
	_wash.visible = _art.visible
	var has_saves := menus.saves() != null and not menus.saves().latest_slot().is_empty()
	_continue.disabled = not has_saves
	_load.disabled = not has_saves
	_extras.visible = menus.collection() != null and not menus.collection().is_empty()
	focus_first()


func on_back() -> bool:
	return false

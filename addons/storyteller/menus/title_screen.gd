class_name TitleScreen
extends MenuScreen
## The title screen: New Game, Continue, Load, Settings, and Quit.

var _continue: Button
var _load: Button
var _title: Label


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.07, 0.1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(320, 0)
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	_title = MenuScreen.make_title("", 44)
	column.add_child(_title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	column.add_child(spacer)
	column.add_child(MenuScreen.make_button("New Game", func() -> void: menus.start_new_game()))
	_continue = MenuScreen.make_button("Continue", func() -> void: menus.continue_game())
	column.add_child(_continue)
	_load = MenuScreen.make_button("Load", func() -> void: menus.open("load"))
	column.add_child(_load)
	column.add_child(MenuScreen.make_button("Settings", func() -> void: menus.open("settings")))
	column.add_child(MenuScreen.make_button("Quit", func() -> void: menus.quit_game()))


func open() -> void:
	_title.text = menus.get_game_title()
	var has_saves := menus.saves() != null and not menus.saves().latest_slot().is_empty()
	_continue.disabled = not has_saves
	_load.disabled = not has_saves
	focus_first()


func on_back() -> bool:
	return false

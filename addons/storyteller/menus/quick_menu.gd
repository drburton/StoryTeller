class_name QuickMenu
extends HBoxContainer
## A row of small buttons above the dialogue box: History, Skip, Auto, Save,
## Load, Settings, and Menu.

var menus: StoryMenus
var _skip: Button
var _auto: Button


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.7
	anchor_bottom = 0.7
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -28
	offset_bottom = -4
	add_theme_constant_override("separation", 4)
	_add("History", func() -> void: menus.open("history"))
	_skip = _add("Skip", func() -> void: menus.toggle_skip())
	_skip.toggle_mode = true
	_auto = _add("Auto", func() -> void: menus.toggle_auto())
	_auto.toggle_mode = true
	_add("Save", func() -> void: menus.open("save"))
	_add("Load", func() -> void: menus.open("load"))
	_add("Settings", func() -> void: menus.open("settings"))
	_add("Menu", func() -> void: menus.open("pause"))


## Updates the Skip and Auto buttons to match the dialogue state.
func sync(skip_on: bool, auto_on: bool) -> void:
	_skip.set_pressed_no_signal(skip_on)
	_auto.set_pressed_no_signal(auto_on)


func _add(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(action)
	add_child(button)
	return button

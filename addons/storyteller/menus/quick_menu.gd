class_name QuickMenu
extends HBoxContainer
## A row of small buttons beside the dialogue box: History, Skip, Auto,
## Save, Load, Settings, and Menu. [StoryMenus] places it at
## [method DialogueBox.get_quick_menu_corner].

var menus: StoryMenus
## Drawn behind the buttons so they stay readable over busy backdrops.
var backing := Color(0.0, 0.0, 0.0, 0.45)
var _skip: Button
var _auto: Button


func _ready() -> void:
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


## Updates the Skip and Auto buttons to match the dialogue state, and moves
## the row so its bottom-right corner sits at [param corner].
func sync(skip_on: bool, auto_on: bool, corner: Vector2) -> void:
	_skip.set_pressed_no_signal(skip_on)
	_auto.set_pressed_no_signal(auto_on)
	position = corner - size


func _draw() -> void:
	if backing.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size).grow_individual(6, 0, 6, 0), backing)


func _add(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(action)
	add_child(button)
	return button

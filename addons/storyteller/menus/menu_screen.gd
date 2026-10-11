class_name MenuScreen
extends Control
## Base class for StoryTeller menu screens. Screens fill the window, block
## input to the story while open, and are managed by [StoryMenus].

## The menus crew member that opened this screen.
var menus: StoryMenus


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Called each time the screen opens, to refresh its contents.
func open() -> void:
	pass


## Called when the player presses the menu key (Escape) on this screen.
## Return false to keep the screen open.
func on_back() -> bool:
	return true


## A translucent full-screen backdrop behind a centered panel.
func add_dim(alpha := 0.6) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


## A centered panel with a vertical column inside. Returns the column.
func add_center_panel(min_width := 360) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column


static func make_title(text: String, size := 28) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	return label


static func make_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(action)
	return button


## Focuses the first enabled button, for keyboard and gamepad players.
func focus_first() -> void:
	for button in find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			return

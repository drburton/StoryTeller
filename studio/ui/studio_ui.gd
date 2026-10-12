class_name StudioUI
extends RefCounted
## Small building blocks for the Studio's screens: labels, buttons sized for
## a finger, and a dialog shown over a screen.

const FONT_SIZE := 20
## Smallest height of anything a finger taps (docs/studio-design.md §2).
const TOUCH_SIZE := 44
const BACKGROUND := Color("1b1e27")


static func label(text: String, font_size := FONT_SIZE, color := Color.WHITE) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


static func button(text: String, on_press: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(TOUCH_SIZE, TOUCH_SIZE)
	result.add_theme_font_size_override("font_size", FONT_SIZE)
	result.pressed.connect(on_press)
	return result


static func flat(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style


## Shows a dialog over [param parent] with [param question] at its top, and
## returns the column to fill. The dialog is the column's
## [code]"dialog"[/code] meta; free it to close.
static func open_dialog(parent: Node, question: String) -> VBoxContainer:
	var dialog := Control.new()
	dialog.top_level = true
	dialog.z_index = 30
	dialog.size = parent.get_viewport().get_visible_rect().size if parent.is_inside_tree() else Vector2(1024, 768)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(center)
	var panel := PanelContainer.new()
	var style := flat(Color(0.16, 0.17, 0.21), 12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size.x = 480
	panel.add_child(column)
	var title := label(question, FONT_SIZE + 2)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	column.set_meta("dialog", dialog)
	parent.add_child(dialog)
	return column


## A row of buttons at the end of a dialog's [param column], one per
## [code][text, action][/code] pair. Each closes the dialog first.
static func add_buttons(column: VBoxContainer, buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var dialog: Control = column.get_meta("dialog")
	for pair in buttons:
		var action: Callable = pair[1]
		var item := button(pair[0], func() -> void:
			dialog.queue_free()
			if action.is_valid():
				action.call())
		item.custom_minimum_size.x = TOUCH_SIZE * 2
		item.set_meta("dialog_button", pair[0])
		row.add_child(item)
	return row

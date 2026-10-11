class_name PageDialogueBox
extends DialogueBox
## Full-screen dialogue style for prose-heavy scenes: lines collect on a page
## like a book until the page fills up or [method clear_page] is called.

const TEXT_SIZE := 20

## Lines kept on a page before it is cleared automatically.
var lines_per_page := 8

var _panel: PanelContainer
var _text_label: RichTextLabel
var _indicator: Label
var _line_count := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	# Let clicks on the box reach _gui_input so they continue the story.
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 80
	_panel.offset_right = -80
	_panel.offset_top = 40
	_panel.offset_bottom = -40
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	_text_label = RichTextLabel.new()
	_text_label.name = "Text"
	_text_label.bbcode_enabled = true
	_text_label.scroll_active = false
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("normal_font_size", 20)
	_text_label.add_theme_font_size_override("bold_font_size", 20)
	_text_label.add_theme_constant_override("paragraph_separation", 14)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text_label)
	_indicator = Label.new()
	_indicator.text = "▼"
	_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_indicator.visible = false
	column.add_child(_indicator)
	_apply_text_scale()
	hide()


func _apply_text_scale() -> void:
	if _text_label == null:
		return
	for font in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		_text_label.add_theme_font_size_override(font, roundi(TEXT_SIZE * text_scale))


func show_line(line: Dictionary) -> void:
	if not await begin_line():
		return
	if _line_count >= lines_per_page:
		clear_page()
	var prefix := ""
	if not line["speaker_name"].is_empty():
		var color: Color = line.get("speaker_color", Color.WHITE)
		prefix = "[b][color=#%s]%s[/color][/b]  " % [color.to_html(false), line["speaker_name"]]
	var paragraph: String = ("\n" if _line_count > 0 else "") + prefix + line["text"]
	_line_count += 1
	await reveal(_text_label, paragraph, _indicator)


## Below the page, in the margin under the panel.
func get_quick_menu_corner() -> Vector2:
	var rect := _panel.get_global_rect()
	return Vector2(rect.end.x, rect.end.y + 36)


func clear_page() -> void:
	_text_label.text = ""
	_line_count = 0


func _on_hidden() -> void:
	clear_page()

class_name ClassicDialogueBox
extends DialogueBox
## The default dialogue style: a box along the bottom of the screen with a
## name plate and typewriter text. Restyle it with a Godot [Theme].

const NAME_SIZE := 22
const TEXT_SIZE := 20
## Width and height of the speaker's portrait, when they have one.
const PORTRAIT_SIZE := 150

var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _indicator: Label
var _portrait: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	# Let clicks on the box reach _gui_input so they continue the story.
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.7
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 24
	_panel.offset_right = -24
	_panel.offset_top = 0
	_panel.offset_bottom = -24
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.visible = false
	row.add_child(_portrait)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)

	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.add_theme_font_size_override("font_size", NAME_SIZE)
	column.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.name = "Text"
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text_label)

	_indicator = Label.new()
	_indicator.name = "Indicator"
	_indicator.text = "▼"
	_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_indicator.visible = false
	column.add_child(_indicator)
	_apply_text_scale()
	hide()


func _apply_text_scale() -> void:
	if _text_label == null:
		return
	_name_label.add_theme_font_size_override("font_size", roundi(NAME_SIZE * text_scale))
	for font in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		_text_label.add_theme_font_size_override(font, roundi(TEXT_SIZE * text_scale))


func get_quick_menu_corner() -> Vector2:
	var rect := _panel.get_global_rect()
	return Vector2(rect.end.x - 4, rect.position.y - 4)


func show_line(line: Dictionary) -> void:
	_name_label.text = line["speaker_name"]
	_name_label.add_theme_color_override("font_color", line.get("speaker_color", Color.WHITE))
	_name_label.visible = not line["speaker_name"].is_empty()
	_portrait.texture = line.get("portrait")
	if line.has("text_color"):
		_text_label.add_theme_color_override("default_color", line["text_color"])
	else:
		_text_label.remove_theme_color_override("default_color")
	_portrait.visible = _portrait.texture != null
	_text_label.text = ""
	if not await begin_line():
		return
	await reveal(_text_label, line["text"], _indicator)

class_name PictureChoiceMenu
extends ChoiceMenu
## The "pictures" choice style: a row of picture cards with the option text
## under each. Pictures come from [code]@picture("name")[/code] on each
## option; an option without one shows its text alone. Supports
## [code]choose(timeout = seconds)[/code] and
## [code]choose(columns = n)[/code] (four by default).
## [codeblock]
## choose(style = "pictures"):
##     @picture("umbrella") "Share mine.": jump share
##     @picture("armchair") "Wait it out here.": jump wait
## [/codeblock]

const PICTURE_SIZE := Vector2(240, 150)
## Room for two lines of option text under the picture.
const CAPTION_HEIGHT := 52.0
const CARD_MARGIN := 8.0
const DEFAULT_COLUMNS := 4

var _column: VBoxContainer
var _grid: GridContainer
var _timer_bar: ProgressBar


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Centered in the space above the classic dialogue box.
	center.anchor_bottom = 0.7
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	center.add_child(_column)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_column.add_child(_grid)
	hide()


func choose(options: Array[Dictionary], settings: Dictionary) -> int:
	for child in _grid.get_children():
		child.queue_free()
	if _timer_bar != null:
		_timer_bar.queue_free()
	_grid.columns = clampi(int(settings.get("columns", DEFAULT_COLUMNS)), 1, maxi(options.size(), 1))
	var first_enabled: Button = null
	for i in options.size():
		var card := _make_card(options[i])
		card.pressed.connect(pick.bind(i))
		_grid.add_child(card)
		if first_enabled == null and not card.disabled:
			first_enabled = card
	_timer_bar = ChoiceMenu.make_timer_bar(settings)
	if _timer_bar != null:
		_column.add_child(_timer_bar)
	show()
	if first_enabled:
		first_enabled.grab_focus()
	return await wait_for_pick(float(settings.get("timeout", 0.0)), _timer_bar)


func _make_card(option: Dictionary) -> Button:
	var button := Button.new()
	button.disabled = not option["enabled"]
	button.tooltip_text = option["text"]
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = CARD_MARGIN
	box.offset_top = CARD_MARGIN
	box.offset_right = -CARD_MARGIN
	box.offset_bottom = -CARD_MARGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var picture: Texture2D = option.get("picture")
	if picture != null:
		var rect := TextureRect.new()
		rect.name = "Picture"
		rect.texture = picture
		rect.custom_minimum_size = PICTURE_SIZE
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if button.disabled:
			rect.modulate = Color(1, 1, 1, 0.4)
		box.add_child(rect)
	var label := Label.new()
	label.name = "Caption"
	label.text = option["text"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PICTURE_SIZE.x, CAPTION_HEIGHT)
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	# Every card is the same size, with or without a picture, so the grid
	# lines up.
	button.custom_minimum_size = Vector2(PICTURE_SIZE.x, PICTURE_SIZE.y + CAPTION_HEIGHT) + Vector2.ONE * CARD_MARGIN * 2
	return button

class_name ClassicDialogueBox
extends DialogueBox
## The default dialogue style: a box along the bottom of the screen with a
## name plate and typewriter text. Restyle it with a Godot [Theme].

## Emitted when the player asks to continue (click, tap, or accept key).
signal continue_pressed

var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _indicator: Label
var _typing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.name = "Panel"
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

	var column := VBoxContainer.new()
	margin.add_child(column)

	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.add_theme_font_size_override("font_size", 22)
	column.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.name = "Text"
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("normal_font_size", 20)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text_label)

	_indicator = Label.new()
	_indicator.name = "Indicator"
	_indicator.text = "▼"
	_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_indicator.visible = false
	column.add_child(_indicator)
	hide()


func show_line(line: Dictionary) -> void:
	show()
	var parsed := DialogueBox.extract_pauses(line["text"])
	_name_label.text = line["speaker_name"]
	_name_label.add_theme_color_override("font_color", line.get("speaker_color", Color.WHITE))
	_name_label.visible = not line["speaker_name"].is_empty()
	_text_label.text = parsed["text"]
	_text_label.visible_characters = 0
	var total := _text_label.get_parsed_text().length()
	var stops: Array = parsed["pauses"].duplicate()
	stops.append({"at": total, "seconds": -1.0})
	for stop in stops:
		await _reveal_to(stop["at"])
		if stop["seconds"] >= 0.0:
			if not skipping:
				await get_tree().create_timer(stop["seconds"]).timeout
		else:
			await _wait_for_continue()
	line_revealed.emit()


func _reveal_to(count: int) -> void:
	if skipping or characters_per_second <= 0.0:
		_text_label.visible_characters = count
		return
	_typing = true
	var shown := float(_text_label.visible_characters)
	while _typing and shown < count:
		await get_tree().process_frame
		shown += characters_per_second * get_process_delta_time()
		_text_label.visible_characters = mini(int(shown), count)
	_text_label.visible_characters = count
	_typing = false


func _wait_for_continue() -> void:
	if skipping:
		await get_tree().process_frame
		return
	_indicator.visible = true
	if auto_advance:
		var delay := auto_delay + _text_label.get_parsed_text().length() * 0.03
		var timer := get_tree().create_timer(delay)
		while timer.time_left > 0.0 and auto_advance and not skipping:
			var pressed := await _next_input_or_frame()
			if pressed:
				break
	else:
		await continue_pressed
	_indicator.visible = false


## Waits one frame. Returns true if the player pressed continue meanwhile.
func _next_input_or_frame() -> bool:
	var state := {"pressed": false}
	var mark := func() -> void: state["pressed"] = true
	continue_pressed.connect(mark, CONNECT_ONE_SHOT)
	await get_tree().process_frame
	if continue_pressed.is_connected(mark):
		continue_pressed.disconnect(mark)
	return state["pressed"]


func _gui_input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touched: bool = event is InputEventScreenTouch and event.pressed
	if clicked or touched:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("story_continue"):
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if _typing:
		_typing = false
	else:
		continue_pressed.emit()

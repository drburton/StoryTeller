class_name HistoryScreen
extends MenuScreen
## Scrollable log of past lines, with a button to replay each voiced line.

var _scroll: ScrollContainer
var _list: VBoxContainer


func _ready() -> void:
	add_dim(0.8)
	var column := add_center_panel(760)
	column.add_child(MenuScreen.make_title("History"))
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(720, 420)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	_scroll.add_child(_list)
	column.add_child(MenuScreen.make_button("Back", func() -> void: menus.close_top()))


func open() -> void:
	for child in _list.get_children():
		child.queue_free()
	var history := menus.history()
	var entries: Array[Dictionary] = history.get_entries() if history else []
	if entries.is_empty():
		_list.add_child(MenuScreen.make_title("Nothing yet.", 18))
	for entry in entries:
		_list.add_child(_make_entry(entry))
	focus_first()
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _make_entry(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var voice: String = entry.get("voice", "")
	if not voice.is_empty():
		var play := Button.new()
		play.text = "▶"
		play.tooltip_text = "Replay voice"
		play.pressed.connect(func() -> void:
			var audio := menus.audio()
			if audio != null:
				audio.play_voice(voice))
		row.add_child(play)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_column)
	if not str(entry["speaker"]).is_empty():
		var name_label := Label.new()
		name_label.text = entry["speaker"]
		name_label.add_theme_color_override("font_color", entry.get("color", Color.WHITE))
		text_column.add_child(name_label)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.text = DialogueBox.extract_pauses(entry["text"])["text"]
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_child(text)
	return row

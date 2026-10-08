class_name SaveLoadScreen
extends MenuScreen
## Grid of save slots with thumbnails. Opened in "save" or "load" mode.

const THUMBNAIL_SIZE := Vector2(192, 108)

var mode := "load"
var _title: Label
var _grid: GridContainer


func _ready() -> void:
	add_dim(0.75)
	var column := add_center_panel(700)
	_title = MenuScreen.make_title("")
	column.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	column.add_child(_grid)
	column.add_child(MenuScreen.make_button("Back", func() -> void: menus.close_top()))


func open() -> void:
	_title.text = "Save" if mode == "save" else "Load"
	for child in _grid.get_children():
		child.queue_free()
	var slots: Array[String] = []
	if mode == "load":
		slots.append_array([StorySaves.AUTO_SLOT, StorySaves.QUICK_SLOT])
	for i in menus.slot_count:
		slots.append(str(i + 1))
	for slot in slots:
		_grid.add_child(_make_slot(slot))
	focus_first()


func _make_slot(slot: String) -> Button:
	var info: Dictionary = menus.saves().get_slot_info(slot) if menus.saves() else {}
	var button := Button.new()
	button.custom_minimum_size = Vector2(THUMBNAIL_SIZE.x + 20, THUMBNAIL_SIZE.y + 76)
	button.disabled = mode == "load" and info.is_empty()
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_top = 8
	box.offset_right = -10
	button.add_child(box)
	var picture := TextureRect.new()
	picture.custom_minimum_size = THUMBNAIL_SIZE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = info.get("thumbnail")
	box.add_child(picture)
	var name_label := Label.new()
	name_label.text = _slot_label(slot) + ("" if info.is_empty() else "  " + _date(info.get("saved_at", 0.0)))
	name_label.add_theme_font_size_override("font_size", 14)
	box.add_child(name_label)
	var text_label := Label.new()
	text_label.text = "Empty" if info.is_empty() else str(info.get("text", ""))
	text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_label.custom_minimum_size = Vector2(THUMBNAIL_SIZE.x, 0)
	text_label.add_theme_font_size_override("font_size", 13)
	text_label.modulate = Color(1, 1, 1, 0.75)
	box.add_child(text_label)
	button.pressed.connect(_on_slot_pressed.bind(slot, not info.is_empty()))
	return button


func _on_slot_pressed(slot: String, occupied: bool) -> void:
	var saves := menus.saves()
	if mode == "save":
		if occupied and not await menus.confirm("Overwrite %s?" % _slot_label(slot).to_lower()):
			return
		saves.save_slot(slot)
		open()
	else:
		if menus.is_story_playing() and not await menus.confirm("Load this save? Unsaved progress will be lost."):
			return
		menus.close_all()
		saves.load_slot(slot)


static func _slot_label(slot: String) -> String:
	match slot:
		StorySaves.AUTO_SLOT:
			return "Auto save"
		StorySaves.QUICK_SLOT:
			return "Quick save"
	return "Slot %s" % slot


static func _date(unix_time: float) -> String:
	var date := Time.get_datetime_dict_from_unix_time(int(unix_time))
	return "%04d-%02d-%02d %02d:%02d" % [date["year"], date["month"], date["day"], date["hour"], date["minute"]]

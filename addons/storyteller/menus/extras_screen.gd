class_name ExtrasScreen
extends MenuScreen
## Extras: the gallery, music room, and codex filled by collect(). Locked
## items are shown but cannot be opened.

const THUMBNAIL_SIZE := Vector2(176, 99)

var _tabs: TabContainer
var _viewer: Control
var _viewer_picture: TextureRect
var _viewer_caption: Label
var _codex_list: ItemList
var _codex_text: RichTextLabel
var _codex_items: Array[CollectionItem] = []
var _playing_music := false


func _ready() -> void:
	add_dim(0.85)
	var column := add_center_panel(860)
	column.add_child(MenuScreen.make_title("Extras"))
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(840, 420)
	column.add_child(_tabs)
	column.add_child(MenuScreen.make_button("Back", _leave))
	_viewer = Control.new()
	_viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewer.visible = false
	_viewer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_viewer.hide())
	add_child(_viewer)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0.95)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewer.add_child(black)
	_viewer_picture = TextureRect.new()
	_viewer_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewer_picture.offset_bottom = -48
	_viewer_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_viewer_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_viewer_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewer.add_child(_viewer_picture)
	_viewer_caption = Label.new()
	_viewer_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_viewer_caption.offset_top = -44
	_viewer_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_viewer.add_child(_viewer_caption)


func open() -> void:
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	var collection := menus.collection()
	if collection != null:
		if not collection.get_items("image").is_empty():
			_add_tab(_build_gallery(collection), "Gallery")
		if not collection.get_items("music").is_empty():
			_add_tab(_build_music(collection), "Music")
		if not collection.get_items("entry").is_empty():
			_add_tab(_build_codex(collection), "Codex")
	_viewer.hide()
	focus_first()


func on_back() -> bool:
	if _viewer.visible:
		_viewer.hide()
		return false
	_stop_music()
	return true


## Shows a gallery picture full screen.
func view(item: CollectionItem) -> void:
	_viewer_picture.texture = item.image
	_viewer_caption.text = item.text if not item.text.is_empty() else item.title
	_viewer.show()


func _leave() -> void:
	_stop_music()
	menus.close_top()


func _add_tab(content: Control, title: String) -> void:
	_tabs.add_child(content)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, title)


func _build_gallery(collection: StoryCollection) -> Control:
	var scroll := ScrollContainer.new()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for item in collection.get_items("image"):
		var unlocked := collection.is_collected(item.id)
		var button := Button.new()
		button.custom_minimum_size = THUMBNAIL_SIZE + Vector2(16, 40)
		button.disabled = not unlocked
		button.tooltip_text = item.title if unlocked else "Locked"
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 8
		box.offset_top = 8
		box.offset_right = -8
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(box)
		var picture := TextureRect.new()
		picture.custom_minimum_size = THUMBNAIL_SIZE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.texture = item.image if unlocked else null
		box.add_child(picture)
		var label := Label.new()
		label.text = item.title if unlocked else "Locked"
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 13)
		box.add_child(label)
		button.pressed.connect(view.bind(item))
		grid.add_child(button)
	return scroll


func _build_music(collection: StoryCollection) -> Control:
	var scroll := ScrollContainer.new()
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for item in collection.get_items("music"):
		var unlocked := collection.is_collected(item.id)
		var button := MenuScreen.make_button(item.title if unlocked else "Locked", _play_music.bind(item))
		button.disabled = not unlocked
		list.add_child(button)
	return scroll


func _build_codex(collection: StoryCollection) -> Control:
	var split := HSplitContainer.new()
	split.split_offset = 240
	_codex_list = ItemList.new()
	_codex_list.custom_minimum_size = Vector2(220, 0)
	_codex_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	split.add_child(_codex_list)
	_codex_text = RichTextLabel.new()
	_codex_text.bbcode_enabled = true
	_codex_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	split.add_child(_codex_text)
	_codex_items = collection.get_items("entry")
	for item in _codex_items:
		var unlocked := collection.is_collected(item.id)
		var index := _codex_list.add_item(tr(item.title) if unlocked else tr("Locked"))
		_codex_list.set_item_disabled(index, not unlocked)
	_codex_list.item_selected.connect(_show_entry)
	_codex_text.text = ""
	return split


func _show_entry(index: int) -> void:
	var item := _codex_items[index]
	_codex_text.text = "[font_size=24]%s[/font_size]\n\n%s" % [tr(item.title), tr(item.text)]


func _play_music(item: CollectionItem) -> void:
	var audio := menus.audio()
	if audio != null:
		audio.play_music(item.music, 1.0, 0.5)
		_playing_music = true


func _stop_music() -> void:
	if _playing_music and menus.audio() != null:
		menus.audio().stop_music(0.5)
	_playing_music = false

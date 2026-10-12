class_name StudioHome
extends Control
## The Studio's home screen (docs/studio-design.md §8): the student's stories
## as cards with a picture, a card to start a new story, and a way to open a
## story file. Each card's ⋯ renames, shares, or deletes its story.

## Emitted when the student opens the story [param id].
signal story_chosen(id: String)

const CARD_SIZE := Vector2(250, 230)
const PICTURE_SIZE := Vector2(226, 127)

var library: StudioLibrary
var config: StoryConfig
## The top bar, where the app adds its ⋯ menu.
var bar: HBoxContainer
var _cards: HFlowContainer
var _message: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = StudioUI.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	column.add_child(bar)
	var title := StudioUI.label("Your stories", StudioUI.FONT_SIZE + 10)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	bar.add_child(StudioUI.button("Open a story file", func() -> void:
		StudioFiles.open(library, _on_opened, show_message)))
	_message = StudioUI.label("", StudioUI.FONT_SIZE - 2, Color(1, 0.85, 0.5))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	column.add_child(_message)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_cards = HFlowContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("h_separation", 16)
	_cards.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_cards)


## Shows the stories as they are now.
func refresh() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_cards.add_child(_new_story_card())
	for story in library.list():
		_cards.add_child(_story_card(story))


## Story cards in order, without the New story card.
func get_cards() -> Array[Control]:
	var result: Array[Control] = []
	for child in _cards.get_children():
		if child.has_meta("story_id"):
			result.append(child)
	return result


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = not text.is_empty()


## Asks for a name, then makes a blank story or a copy of the sample, and
## opens it.
func new_story() -> void:
	var column := StudioUI.open_dialog(self, "Name your new story")
	var name_field := LineEdit.new()
	name_field.text = "My story"
	name_field.select_all_on_focus = true
	name_field.custom_minimum_size.y = StudioUI.TOUCH_SIZE
	name_field.add_theme_font_size_override("font_size", StudioUI.FONT_SIZE)
	name_field.set_meta("field_key", "dialog:name")
	column.add_child(name_field)
	column.add_child(StudioUI.label("Start with", StudioUI.FONT_SIZE - 2, Color(0.85, 0.87, 0.9)))
	var make := func(text: String, copied_id: String) -> void:
		var title := name_field.text.strip_edges()
		story_chosen.emit(library.create(title if not title.is_empty() else "My story", text, copied_id))
	StudioUI.add_buttons(column, [
		["Cancel", Callable()],
		["A copy of " + StudioLibrary.SAMPLE_TITLE, make.bind(StudioLibrary.sample_text(), StudioLibrary.SAMPLE_ID)],
		["A blank story", make.bind(StudioLibrary.BLANK_TALE, "")],
	])
	(func() -> void:
		if name_field.is_inside_tree():
			name_field.grab_focus()).call_deferred()


## The ⋯ menu of a story card: Rename, Share, and Delete, under
## [param button] when it is given.
func open_story_menu(id: String, button: Control = null) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.add_theme_font_size_override("font_size", StudioUI.FONT_SIZE + 2)
	menu.add_item("Rename", 0)
	menu.add_item("Share", 1)
	menu.add_item("Delete", 2)
	menu.id_pressed.connect(_on_story_menu.bind(id))
	menu.popup_hide.connect(menu.queue_free)
	add_child(menu)
	var at := button.get_global_rect().position + Vector2(0, button.size.y) if button != null else get_global_mouse_position()
	menu.popup(Rect2i(Vector2i(at), Vector2i.ZERO))
	return menu


func _on_story_menu(item: int, id: String) -> void:
	if item == 0:
		rename_story(id)
	elif item == 1:
		StudioFiles.share(library, id, func(text: String) -> void:
			show_message(text)
			refresh())
	else:
		confirm_delete(id)


func rename_story(id: String) -> void:
	var column := StudioUI.open_dialog(self, "Name of your story")
	var field := LineEdit.new()
	field.text = library.get_story(id).get("title", id)
	field.custom_minimum_size.y = StudioUI.TOUCH_SIZE
	field.add_theme_font_size_override("font_size", StudioUI.FONT_SIZE)
	field.set_meta("field_key", "dialog:name")
	column.add_child(field)
	StudioUI.add_buttons(column, [["Cancel", Callable()], ["OK", func() -> void:
		library.rename(id, field.text)
		refresh()]])


## Asks before deleting, since a deleted story can't come back.
func confirm_delete(id: String) -> void:
	var title: String = library.get_story(id).get("title", id)
	var column := StudioUI.open_dialog(self, "Delete “%s”? It can't come back unless you shared a copy." % title)
	StudioUI.add_buttons(column, [["Keep it", Callable()], ["Delete", func() -> void:
		library.delete(id)
		refresh()]])


func _on_opened(id: String) -> void:
	show_message("Opened “%s”." % library.get_story(id)["title"])
	refresh()


func _new_story_card() -> Control:
	var card := _card_panel(Color(0.22, 0.25, 0.32))
	card.set_meta("new_story", true)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var plus := StudioUI.label("+", 64)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(plus)
	var words := StudioUI.label("New story", StudioUI.FONT_SIZE + 2)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(words)
	card.gui_input.connect(_on_card_input.bind(new_story))
	return card


func _story_card(story: Dictionary) -> Control:
	var id: String = story["id"]
	var card := _card_panel(Color(0.18, 0.2, 0.26))
	card.set_meta("story_id", id)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var texture := story_picture(id)
	if texture != null:
		var picture := TextureRect.new()
		picture.custom_minimum_size = PICTURE_SIZE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.texture = texture
		column.add_child(picture)
	else:
		column.add_child(_letter_tile(story["title"]))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var title := StudioUI.label(story["title"], StudioUI.FONT_SIZE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)
	var more := StudioUI.button("⋯", Callable())
	more.pressed.connect(func() -> void: open_story_menu(id, more))
	more.set_meta("story_menu", id)
	row.add_child(more)
	column.add_child(StudioUI.label(changed_words(story["changed"]), StudioUI.FONT_SIZE - 4, Color(0.75, 0.78, 0.85)))
	if StudioLibrary.needs_reminder(story):
		var reminder := StudioUI.label("Share a copy to keep it safe", StudioUI.FONT_SIZE - 4, Color(1, 0.75, 0.35))
		reminder.set_meta("reminder", true)
		column.add_child(reminder)
	card.gui_input.connect(_on_card_input.bind(func() -> void: story_chosen.emit(id)))
	return card


## A colored tile with the first letter of [param title], for a story that
## has no background yet.
func _letter_tile(title: String) -> Control:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = PICTURE_SIZE
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var colors: Array = StoryBlocks.GROUPS.values().map(func(group: Dictionary) -> Color: return group["color"])
	tile.add_theme_stylebox_override("panel", StudioUI.flat(colors[absi(title.hash()) % 5], 8))
	var letter := StudioUI.label(title.strip_edges().left(1).to_upper(), 64)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(letter)
	return tile


func _card_panel(color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StudioUI.flat(color, 12)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	return card


## A tap on a card: a press and a release without much movement, so
## scrolling the cards with a finger doesn't open one.
func _on_card_input(event: InputEvent, action: Callable) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			set_meta("press_at", event.global_position)
		elif has_meta("press_at") and event.global_position.distance_to(get_meta("press_at")) < 12.0:
			remove_meta("press_at")
			action.call()


## "Changed today", "Changed yesterday", or "Changed 3 days ago".
static func changed_words(changed: float, now := -1.0) -> String:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var days := int((now - changed) / 86400.0)
	if days <= 0:
		return "Changed today"
	return "Changed yesterday" if days == 1 else "Changed %d days ago" % days


## A picture for the story's card: the first background it shows, from the
## story's own pictures or the starter library, or null.
func story_picture(id: String) -> Texture2D:
	var found := RegEx.create_from_string("backdrop\\(\"([^\"]+)\"").search(library.read_tale(id))
	if found == null:
		return null
	var path := StoryAssets.find(library.asset_folder(id, "backdrops"), found.get_string(1), StoryAssets.IMAGE_EXTENSIONS)
	if not path.is_empty():
		return StoryAssets.load_path(path) as Texture2D
	return StudioStarter.picture("backdrops", found.get_string(1))

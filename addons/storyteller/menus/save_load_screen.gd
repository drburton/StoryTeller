class_name SaveLoadScreen
extends MenuScreen
## Pages of save slots with thumbnails. Opened in "save" or "load" mode.
##
## Each page shows [member StoryMenus.slot_count] numbered slots. When
## saving, there is always a page with a free slot after the highest one in
## use, so players can keep as many saves as they like (unless
## [member StoryMenus.save_pages] sets a limit). Saved slots can be renamed
## and deleted from the screen. In "load" mode the auto and quick save
## slots come first on page 1.

const THUMBNAIL_SIZE := Vector2(176, 99)
## Height kept free for the title, page controls, and Back button. The
## slots scroll when a page is taller than the rest of the window.
const RESERVED_HEIGHT := 200.0

var mode := "load"
## Page shown, from 1. Kept while the game runs, so the screen reopens on
## the page the player last used.
var page := 1
var _title: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _nav: HBoxContainer
var _page_label: Label
var _previous: Button
var _next: Button


func _ready() -> void:
	add_dim(0.75)
	var column := add_center_panel(700)
	_title = MenuScreen.make_title("")
	column.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_grid)
	column.add_child(_scroll)
	_nav = HBoxContainer.new()
	_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	_nav.add_theme_constant_override("separation", 16)
	_previous = MenuScreen.make_button("Previous", func() -> void: show_page(page - 1))
	_nav.add_child(_previous)
	_page_label = Label.new()
	_page_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_nav.add_child(_page_label)
	_next = MenuScreen.make_button("Next", func() -> void: show_page(page + 1))
	_nav.add_child(_next)
	column.add_child(_nav)
	column.add_child(MenuScreen.make_button("Back", func() -> void: menus.close_top()))


func open() -> void:
	_title.text = "Save" if mode == "save" else "Load"
	show_page(page)
	focus_first()


## Number of pages: up to the highest slot in use, plus room for one more
## save in "save" mode, within [member StoryMenus.save_pages] when set.
func get_page_count() -> int:
	var per_page := maxi(menus.slot_count, 1)
	var highest := menus.saves().highest_numbered_slot() if menus.saves() else 0
	var needed := highest + 1 if mode == "save" else highest
	var count := maxi(1, ceili(float(needed) / per_page))
	if menus.save_pages > 0:
		count = mini(count, menus.save_pages)
	return count


## Shows page [param number] (clamped to the pages there are).
func show_page(number: int) -> void:
	var count := get_page_count()
	page = clampi(number, 1, count)
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var slots: Array[String] = []
	if mode == "load" and page == 1:
		slots.append_array([StorySaves.AUTO_SLOT, StorySaves.QUICK_SLOT])
	var first := (page - 1) * menus.slot_count + 1
	for i in menus.slot_count:
		slots.append(str(first + i))
	for slot in slots:
		_grid.add_child(_make_slot(slot))
	_nav.visible = count > 1
	_page_label.text = tr("Page %d of %d") % [page, count]
	_previous.disabled = page <= 1
	_next.disabled = page >= count
	_fit_to_window()


## Sizes the scroll area to the slots, or to the window when they are taller.
func _fit_to_window() -> void:
	var wanted := _grid.get_combined_minimum_size()
	var window_height := get_viewport_rect().size.y if is_inside_tree() else 648.0
	var height := minf(wanted.y, maxf(window_height - RESERVED_HEIGHT, 160.0))
	var scrollbar := 14.0 if height < wanted.y else 0.0
	_scroll.custom_minimum_size = Vector2(wanted.x + scrollbar, height)
	_scroll.scroll_vertical = 0


func _make_slot(slot: String) -> Control:
	var info: Dictionary = menus.saves().get_slot_info(slot) if menus.saves() else {}
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)
	var button := Button.new()
	button.custom_minimum_size = Vector2(THUMBNAIL_SIZE.x + 20, THUMBNAIL_SIZE.y + 76)
	button.disabled = mode == "load" and info.is_empty()
	cell.add_child(button)
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
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.text = _slot_label(slot) + ("" if info.is_empty() else "  " + _date(info.get("saved_at", 0.0)))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(THUMBNAIL_SIZE.x, 0)
	box.add_child(name_label)
	var label := str(info.get("label", ""))
	var text_label := Label.new()
	text_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if info.is_empty():
		text_label.text = tr("Empty")
	else:
		text_label.text = label if not label.is_empty() else str(info.get("text", ""))
	text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_label.custom_minimum_size = Vector2(THUMBNAIL_SIZE.x, 0)
	text_label.add_theme_font_size_override("font_size", 13)
	text_label.modulate = Color(1, 1, 1, 1.0 if not label.is_empty() else 0.75)
	box.add_child(text_label)
	button.pressed.connect(_on_slot_pressed.bind(slot, not info.is_empty()))
	# Rename and Delete sit under saved slots; empty slots keep the space so
	# the grid lines up.
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.custom_minimum_size = Vector2(0, 30)
	cell.add_child(actions)
	if not info.is_empty():
		for action in [["Rename", _rename.bind(slot, label)], ["Delete", _delete.bind(slot)]]:
			var small := Button.new()
			small.text = action[0]
			small.add_theme_font_size_override("font_size", 13)
			small.pressed.connect(action[1])
			actions.add_child(small)
	return cell


func _on_slot_pressed(slot: String, occupied: bool) -> void:
	var saves := menus.saves()
	if mode == "save":
		if occupied and not await menus.confirm(tr("Overwrite %s?") % _slot_label(slot)):
			return
		saves.save_slot(slot)
		show_page(page)
	else:
		if menus.is_story_playing() and not await menus.confirm("Load this save? Unsaved progress will be lost."):
			return
		menus.close_all()
		saves.load_slot(slot)


func _rename(slot: String, current: String) -> void:
	var label := await menus.ask_text(tr("Name this save"), current, 30)
	menus.saves().set_slot_label(slot, label)
	show_page(page)


func _delete(slot: String) -> void:
	if not await menus.confirm(tr("Delete %s?") % _slot_label(slot)):
		return
	menus.saves().delete_slot(slot)
	show_page(page)


static func _slot_label(slot: String) -> String:
	match slot:
		StorySaves.AUTO_SLOT:
			return TranslationServer.translate("Auto save")
		StorySaves.QUICK_SLOT:
			return TranslationServer.translate("Quick save")
	return TranslationServer.translate("Slot %s") % slot


static func _date(unix_time: float) -> String:
	var date := Time.get_datetime_dict_from_unix_time(int(unix_time))
	return "%04d-%02d-%02d %02d:%02d" % [date["year"], date["month"], date["day"], date["hour"], date["minute"]]

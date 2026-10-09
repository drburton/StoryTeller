class_name StoryMenus
extends StoryCrew
## Crew member for the player-facing menus: title screen, pause menu, save
## and load screens, settings, history, confirmations, text input, and the
## quick menu above the dialogue box.
##
## [codeblock]
## Story.show_title()           # from the game's main scene
## [/codeblock]
## Escape (or a right click) opens the pause menu while a story plays, H
## opens the history, F5 and F9 quick save and quick load.

## Emitted when the player starts a new game from the title screen.
signal new_game_started
## Emitted when the title screen opens.
signal title_shown

const SCREENS := {
	"title": preload("res://addons/storyteller/menus/title_screen.gd"),
	"pause": preload("res://addons/storyteller/menus/pause_menu.gd"),
	"save": preload("res://addons/storyteller/menus/save_load_screen.gd"),
	"load": preload("res://addons/storyteller/menus/save_load_screen.gd"),
	"settings": preload("res://addons/storyteller/menus/settings_screen.gd"),
	"history": preload("res://addons/storyteller/menus/history_screen.gd"),
	"confirm": preload("res://addons/storyteller/menus/confirm_dialog.gd"),
	"text_input": preload("res://addons/storyteller/menus/text_input_dialog.gd"),
	"extras": preload("res://addons/storyteller/menus/extras_screen.gd"),
}
## Seconds a notice from show_notice() stays on screen.
const NOTICE_TIME := 2.5

## Every piece of menu text, for "Export Strings". Menus are translated by
## Godot with these texts as keys. A test keeps this list complete.
const UI_TEXT: Array[String] = [
	"New Game", "Continue", "Load", "Save", "Settings", "Quit", "Paused",
	"Resume", "History", "Title Screen", "Back", "Yes", "No", "OK",
	"Reset to defaults", "Nothing yet.", "Replay voice", "Skip", "Auto", "Menu",
	"Empty", "Auto save", "Quick save", "Slot %s", "Overwrite %s?", "Language",
	"Load this save? Unsaved progress will be lost.",
	"Return to the title screen? Unsaved progress will be lost.",
	"Quit the game? Unsaved progress will be lost.",
	"Text speed", "Auto mode delay", "Master volume", "Music volume",
	"Sound volume", "Ambience volume", "Voice volume", "Full screen",
	"Skip unread lines", "Extras", "Gallery", "Music", "Codex", "Locked",
	"Unlocked: %s", "Previous", "Next", "Page %d of %d", "Rename", "Delete",
	"Delete %s?", "Name this save",
]

var layer: CanvasLayer
var root: Control
var quick_menu: QuickMenu
## Numbered save slots on each page of the save and load screens.
var slot_count := 6
## Pages of numbered slots, or 0 for as many as players fill.
var save_pages := 0
var start_tale := ""
var start_beat := "start"
var game_title := ""
var return_to_title := true
var show_quick_menu := true

var _notices: VBoxContainer
var _screens: Dictionary = {}
var _stack: Array[MenuScreen] = []
var _title_active := false


func get_crew_name() -> StringName:
	return &"Menus"


func setup(config: StoryConfig) -> void:
	slot_count = config.save_slot_count
	save_pages = config.save_pages
	start_tale = config.start_tale
	start_beat = config.start_beat
	game_title = config.game_title
	return_to_title = config.return_to_title
	show_quick_menu = config.show_quick_menu
	layer = CanvasLayer.new()
	layer.name = "MenuLayer"
	layer.layer = 20
	add_child(layer)
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = config.theme if config.theme != null else StoryTheme.build_default()
	layer.add_child(root)
	# Notices get their own layer so they show above every menu screen.
	var notice_layer := CanvasLayer.new()
	notice_layer.name = "NoticeLayer"
	notice_layer.layer = layer.layer + 1
	add_child(notice_layer)
	_notices = VBoxContainer.new()
	_notices.name = "Notices"
	_notices.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_notices.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_notices.offset_left = -24
	_notices.offset_right = -24
	_notices.offset_top = 24
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notices.theme = root.theme
	notice_layer.add_child(_notices)
	quick_menu = QuickMenu.new()
	quick_menu.menus = self
	quick_menu.visible = false
	root.add_child(quick_menu)
	_connect.call_deferred()


## Opens a screen on top of any open ones: "title", "pause", "save", "load",
## "settings", "history". Returns the screen.
func open(screen_name: String) -> MenuScreen:
	if screen_name in ["pause", "save"] and saves() != null and _stack.is_empty():
		saves().capture_thumbnail()
	var screen := _screen(screen_name)
	if screen is SaveLoadScreen:
		screen.mode = screen_name
	if screen in _stack:
		_stack.erase(screen)
	_stack.append(screen)
	screen.move_to_front()
	screen.show()
	screen.open()
	return screen


## Closes the top screen.
func close_top() -> void:
	if _stack.is_empty():
		return
	var screen: MenuScreen = _stack.pop_back()
	screen.hide()
	if not _stack.is_empty():
		_stack.back().open()


func close_all() -> void:
	for screen in _stack:
		screen.hide()
	_stack.clear()
	_title_active = false


## True while any menu screen is open.
func is_open() -> bool:
	return not _stack.is_empty()


func is_story_playing() -> bool:
	return director() != null and director().is_playing()


## Stops the story and shows the title screen.
func show_title() -> void:
	close_all()
	_title_active = true
	if director() != null:
		director().stop()
	var dialogue := _dialogue()
	if dialogue != null:
		dialogue.hide_all()
	_title_active = true
	open("title")
	title_shown.emit()


## Clears the story state and plays [member start_tale] from the start.
func start_new_game() -> void:
	close_all()
	var story := get_parent()
	if story != null and story.has_method("clear_all"):
		story.clear_all()
	if start_tale.is_empty():
		push_error("StoryTeller: set StoryConfig.start_tale to the tale New Game should play.")
		return
	new_game_started.emit()
	director().play(start_tale, start_beat)


## Loads the most recent save.
func continue_game() -> void:
	var slot := saves().latest_slot() if saves() else ""
	if slot.is_empty():
		return
	close_all()
	saves().load_slot(slot)


## False where a game cannot close itself, such as in a web browser. The
## title screen and pause menu leave out Quit there.
func can_quit() -> bool:
	return not OS.has_feature("web")


func quit_game() -> void:
	if saves() != null:
		saves().save_globals()
	get_tree().quit()


## Asks a yes or no question. Awaitable; returns the answer.
func confirm(message: String) -> bool:
	var dialog := open("confirm") as ConfirmDialog
	dialog.message = message
	dialog.open()
	var yes: bool = await dialog.answered
	_close(dialog)
	return yes


## Asks the player to type text. Awaitable; returns what they typed, or
## [param default_text] if they left it empty.
func ask_text(prompt: String, default_text := "", max_length := 24) -> String:
	var dialog := _screen("text_input") as TextInputDialog
	dialog.prompt = prompt
	dialog.default_text = default_text
	dialog.max_length = max_length
	open("text_input")
	var text: String = await dialog.submitted
	_close(dialog)
	return text


func toggle_skip() -> void:
	var dialogue := _dialogue()
	if dialogue != null:
		dialogue.skip_toggled = not dialogue.skip_toggled


func toggle_auto() -> void:
	var dialogue := _dialogue()
	if dialogue != null:
		dialogue.dialogue_box.auto_advance = not dialogue.dialogue_box.auto_advance


func director() -> TaleDirector:
	return _crew(&"TaleDirector") as TaleDirector


func saves() -> StorySaves:
	return _crew(&"Saves") as StorySaves


func settings() -> StorySettings:
	return _crew(&"Settings") as StorySettings


func history() -> StoryHistory:
	return _crew(&"History") as StoryHistory


func collection() -> StoryCollection:
	return _crew(&"Collection") as StoryCollection


## Shows a short message in the top-right corner, such as an unlock.
func show_notice(text: String) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var label := Label.new()
	label.text = text
	panel.add_child(label)
	_notices.add_child(panel)
	var tween := panel.create_tween()
	tween.tween_interval(NOTICE_TIME)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panel.queue_free)


func get_notices() -> PackedStringArray:
	var result := PackedStringArray()
	for panel in _notices.get_children():
		if not panel.is_queued_for_deletion():
			result.append(panel.get_child(0).text)
	return result


func audio() -> StoryAudio:
	return _crew(&"Audio") as StoryAudio


func get_game_title() -> String:
	if not game_title.is_empty():
		return game_title
	return str(ProjectSettings.get_setting("application/config/name", "StoryTeller"))


func _process(_delta: float) -> void:
	var dialogue := _dialogue()
	var dialogue_showing := dialogue != null and dialogue.is_showing()
	var effects := _crew(&"Effects") as StoryEffects
	var faded := effects != null and effects.is_faded_out()
	quick_menu.visible = show_quick_menu and is_story_playing() and _stack.is_empty() and dialogue_showing and not faded
	if quick_menu.visible:
		quick_menu.sync(dialogue.skip_toggled, dialogue.dialogue_box.auto_advance, dialogue.dialogue_box.get_quick_menu_corner())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("story_menu"):
		if not _stack.is_empty():
			if _stack.back().on_back():
				close_top()
		elif is_story_playing():
			open("pause")
		else:
			return
		get_viewport().set_input_as_handled()
	elif _stack.is_empty() and is_story_playing():
		if event.is_action_pressed("story_history"):
			open("history")
		elif event.is_action_pressed("story_quick_save") and saves():
			saves().quick_save()
		elif event.is_action_pressed("story_quick_load") and saves() and saves().has_slot(StorySaves.QUICK_SLOT):
			saves().quick_load()
		else:
			return
		get_viewport().set_input_as_handled()


func _screen(screen_name: String) -> MenuScreen:
	var key := "save_load" if screen_name in ["save", "load"] else screen_name
	if not _screens.has(key):
		var screen: MenuScreen = SCREENS[screen_name].new()
		screen.name = key.capitalize().replace(" ", "") + "Screen"
		screen.menus = self
		screen.hide()
		root.add_child(screen)
		_screens[key] = screen
	return _screens[key]


func _close(screen: MenuScreen) -> void:
	_stack.erase(screen)
	screen.hide()
	if not _stack.is_empty():
		_stack.back().open()


func _connect() -> void:
	var dialogue := _dialogue()
	if dialogue != null:
		dialogue.input_blocked = is_open
	if director() != null:
		director().story_finished.connect(func() -> void:
			if return_to_title and _title_active == false and not start_tale.is_empty() and not is_story_playing():
				show_title.call_deferred())


func _dialogue() -> StoryDialogue:
	return _crew(&"Dialogue") as StoryDialogue


func _crew(crew_name: StringName) -> Node:
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(crew_name)
	return null

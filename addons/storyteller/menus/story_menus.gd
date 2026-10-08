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
}

var layer: CanvasLayer
var root: Control
var quick_menu: QuickMenu
## Numbered save slots shown on the save and load screens.
var slot_count := 9
var start_tale := ""
var start_beat := "start"
var game_title := ""
var return_to_title := true
var show_quick_menu := true

var _screens: Dictionary = {}
var _stack: Array[MenuScreen] = []
var _title_active := false


func get_crew_name() -> StringName:
	return &"Menus"


func setup(config: StoryConfig) -> void:
	slot_count = config.save_slot_count
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


func audio() -> StoryAudio:
	return _crew(&"Audio") as StoryAudio


func get_game_title() -> String:
	if not game_title.is_empty():
		return game_title
	return str(ProjectSettings.get_setting("application/config/name", "StoryTeller"))


func _process(_delta: float) -> void:
	var dialogue := _dialogue()
	var dialogue_showing := dialogue != null and dialogue.is_showing()
	quick_menu.visible = show_quick_menu and is_story_playing() and _stack.is_empty() and dialogue_showing
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

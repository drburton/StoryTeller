extends Control
## Visual Novel StoryTeller Studio (docs/studio-design.md): the home screen
## with the student's stories, and one story open in the blocks. Stories
## are kept in the app's own storage ([StudioLibrary]). The stage preview
## (step S3) and the starter library (S4) come next; until then stories use
## the characters, backgrounds, and sounds of the Where's Biscuit sample.

const STORY_CONFIG := "res://examples/wheres_biscuit/story_config.tres"
const CHECK_SCENE := "res://studio/check/tablet_check.tscn"
const SETTINGS_PATH := "user://studio_settings.json"

## The folder of the student's stories. Tests set it before the app starts.
var library_root := StudioLibrary.ROOT
## Where the app's settings are saved. Tests set it before the app starts.
var settings_path := SETTINGS_PATH
var library: StudioLibrary
var config: StoryConfig
var home: StudioHome
var story: StudioStoryScreen
var settings := {"show_code_blocks": false}
var _menu: MenuButton


func _ready() -> void:
	library = StudioLibrary.new(library_root)
	library.add_sample()
	config = load(STORY_CONFIG)
	_load_settings()
	home = StudioHome.new()
	home.library = library
	home.config = config
	home.story_chosen.connect(open_story)
	add_child(home)
	story = StudioStoryScreen.new()
	story.library = library
	story.config = config
	story.home_requested.connect(show_home)
	add_child(story)
	_add_menu()
	show_home()


## Opens the story [param id] in the blocks.
func open_story(id: String) -> void:
	home.visible = false
	home.show_message("")
	story.visible = true
	story.editor.show_code_blocks = settings["show_code_blocks"]
	story.open(id)


func show_home() -> void:
	story.visible = false
	home.refresh()
	home.visible = true


## Turns the Code block in the palette on or off, and remembers it.
func set_show_code_blocks(shown: bool) -> void:
	settings["show_code_blocks"] = shown
	story.editor.show_code_blocks = shown
	_menu.get_popup().set_item_checked(0, shown)
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(settings))


func _load_settings() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(settings_path)) if FileAccess.file_exists(settings_path) else null
	if data is Dictionary:
		settings.merge(data, true)


func _add_menu() -> void:
	_menu = MenuButton.new()
	_menu.text = "⋯"
	_menu.flat = false
	_menu.custom_minimum_size = Vector2(StudioUI.TOUCH_SIZE + 12, StudioUI.TOUCH_SIZE)
	_menu.add_theme_font_size_override("font_size", StudioUI.FONT_SIZE)
	var popup := _menu.get_popup()
	popup.add_theme_font_size_override("font_size", StudioUI.FONT_SIZE)
	popup.add_check_item("Show Code blocks", 0)
	popup.set_item_checked(0, settings["show_code_blocks"])
	popup.add_item("Tablet check", 1)
	popup.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			set_show_code_blocks(not settings["show_code_blocks"])
		else:
			Engine.set_meta("studio_return", scene_file_path)
			get_tree().change_scene_to_file(CHECK_SCENE))
	home.bar.add_child(_menu)

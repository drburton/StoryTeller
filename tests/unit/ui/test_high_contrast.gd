extends "res://tests/framework/story_test.gd"
## Tests for the high-contrast and readable font settings: the dialogue
## boxes, choice menus, and menus switch theme and back.

const StoryScript := preload("res://addons/storyteller/core/story.gd")


func test_display_settings_switch_every_themed_layer() -> void:
	var story: Node = track(StoryScript.new())
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage, StoryAudio, StorySettings, StoryDialogue, StoryMenus]
	config.settings_path = "user://test_contrast_settings.cfg"
	story.start(config)
	tree.root.add_child(story)
	await tree.process_frame
	var dialogue: StoryDialogue = story.get_crew(&"Dialogue")
	var menus: StoryMenus = story.get_crew(&"Menus")
	var normal := dialogue.dialogue_box.theme
	var menus_normal := menus.root.theme
	(story.get_crew(&"Settings") as StorySettings).set_value("high_contrast", true)
	var contrast := dialogue.dialogue_box.theme
	assert_ne(contrast, normal)
	assert_eq(contrast.get_color("default_color", "RichTextLabel"), Color.WHITE)
	var panel := contrast.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert_eq(panel.bg_color, Color.BLACK, "panels are opaque")
	assert_eq(dialogue.choice_menu.theme, contrast)
	assert_eq(menus.root.theme.get_stylebox("panel", "PanelContainer").bg_color, Color.BLACK)
	assert_eq(menus.quick_menu.backing, Color.BLACK, "the quick menu's backing is opaque")
	assert_true(is_equal_approx((normal.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color.a, 0.9), "the normal theme is not changed")
	(story.get_crew(&"Settings") as StorySettings).set_value("high_contrast", false)
	assert_eq(dialogue.dialogue_box.theme, normal)
	assert_eq(menus.root.theme, menus_normal)
	assert_eq(menus.quick_menu.backing, QuickMenu.BACKING)
	var settings := story.get_crew(&"Settings") as StorySettings
	settings.set_value("readable_font", true)
	var readable := dialogue.dialogue_box.theme
	assert_true(readable.default_font is SystemFont, "a readable system font")
	assert_eq((readable.default_font as SystemFont).font_names[0], "Atkinson Hyperlegible")
	assert_eq((readable.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color, (normal.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color, "panels unchanged without high contrast")
	settings.set_value("high_contrast", true)
	var both := dialogue.dialogue_box.theme
	assert_true(both.default_font is SystemFont and (both.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color == Color.BLACK, "the two combine")
	assert_true(menus.root.theme.default_font is SystemFont, "menus get the font too")
	settings.set_value("high_contrast", false)
	settings.set_value("readable_font", false)
	assert_eq(dialogue.dialogue_box.theme, normal)
	DirAccess.remove_absolute("user://test_contrast_settings.cfg")

extends "res://tests/framework/story_test.gd"
## Tests for the Studio's library panel (studio/library/library_panel.gd):
## the story's characters, backgrounds, and sounds, and adding them from the
## starter library or the student's own files.

const ROOT := "user://test_panel_stories"
const SOUND := "user://test_panel_sound.ogg.bin"

var library: StudioLibrary


func before_each() -> void:
	super()
	StudioLibrary._remove_folder(ROOT)
	library = StudioLibrary.new(ROOT)


func after_each() -> void:
	StudioLibrary._remove_folder(ROOT)
	if FileAccess.file_exists(SOUND):
		DirAccess.remove_absolute(SOUND)
	super()


func _open(id: String) -> StudioLibraryPanel:
	var panel: StudioLibraryPanel = track(StudioLibraryPanel.new())
	tree.root.add_child(panel)
	panel.show_story(library, id)
	await tree.process_frame
	return panel


static func _photo(size: Vector2i) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.5, 0.2, 1.0))
	return image


func _press(root: Node, meta: String, value: String) -> void:
	for button in root.find_children("*", "Button", true, false):
		if str(button.get_meta(meta, "")) == value:
			button.pressed.emit()
			return
	fail("no button %s = %s" % [meta, value])


func test_the_panel_shows_the_storys_own_pictures() -> void:
	library.add_sample()
	library.add_starter_items("wheres_biscuit")
	var panel := await _open("wheres_biscuit")
	assert_eq(panel.get_tiles("cast").keys(), ["biscuit", "cleo", "leo", "theo"])
	assert_eq(panel.get_tiles("cast")["theo"].text, "Theo")
	assert_true(panel.get_tiles("cast")["theo"].icon is Texture2D, "a face on each character")
	assert_eq(panel.get_tiles("backdrops").keys(), ["backyard", "living_room"])
	assert_true(panel.get_tiles("sounds").is_empty())


func test_adding_from_the_starter_library() -> void:
	var id := library.create("Space Trip")
	var panel := await _open(id)
	var changes := []
	panel.assets_changed.connect(func() -> void: changes.append(true))
	var column := panel.open_add("backdrops")
	var offered := column.find_children("*", "Button", true, false).filter(func(button: Node) -> bool: return button.has_meta("starter_kind"))
	assert_eq(offered.map(func(button: Node) -> String: return button.get_meta("item")), Array(StudioStarter.names("backdrops")))
	_press(column, "item", "classroom")
	assert_eq(panel.get_tiles("backdrops").keys(), ["classroom"])
	assert_eq(changes.size(), 1)
	column = panel.open_add("backdrops")
	assert_false(column.find_children("*", "Button", true, false).any(func(button: Node) -> bool: return button.get_meta("item", "") == "classroom"), "only what the story doesn't have")
	column.get_meta("dialog").queue_free()
	column = panel.open_add("sounds")
	_press(column, "item", "quiet_morning")
	assert_eq(panel.get_tiles("sounds").keys(), ["quiet_morning"])
	assert_eq(panel.get_tiles("sounds")["quiet_morning"].text, "♫ Quiet morning")


func test_adding_the_students_own_pictures_and_sounds() -> void:
	var id := library.create("Space Trip")
	var panel := await _open(id)
	assert_eq(panel.add_own_picture("Moon Base", _photo(Vector2i(800, 450))), "moon_base")
	assert_true(panel.get_tiles("backdrops")["moon_base"].icon is Texture2D)
	assert_eq(panel.add_own_face("Captain Zed", "brave", _photo(Vector2i(200, 300))), "captain_zed")
	assert_eq(panel.get_tiles("cast")["captain_zed"].text, "Captain Zed")
	var faces := panel.open_character("captain_zed")
	assert_eq(faces.find_children("*", "Button", true, false).filter(func(button: Node) -> bool:
		return button.get_meta("item", "") == "brave").size(), 1)
	faces.get_meta("dialog").queue_free()
	# A picked sound may have no extension; its first bytes tell its kind.
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.data = PackedByteArray([0, 0, 40, 40, 0, 0, 40, 40])
	tone.save_to_wav("user://test_panel_tone.wav")
	DirAccess.rename_absolute("user://test_panel_tone.wav", SOUND)
	assert_eq(panel.add_own_sound("sounds", "Boing", SOUND), "boing")
	assert_eq(panel.get_tiles("sounds")["boing"].text, "♪ Boing")
	panel.play_sound("sounds", "boing")
	assert_true(panel._player.stream is AudioStreamWAV)
	assert_eq(panel.add_own_sound("sounds", "notes", "res://README.md"), "")
	assert_true(panel._message.text.contains("isn't a sound"))


func test_a_character_added_in_the_panel_reaches_the_blocks() -> void:
	var studio: Control = track(preload("res://studio/studio.tscn").instantiate())
	studio.library_root = ROOT
	studio.settings_path = "user://test_panel_settings.json"
	tree.root.add_child(studio)
	await tree.process_frame
	var id: String = studio.library.create("Space Trip")
	studio.open_story(id)
	studio.story.library_panel.add_own_face("Captain Zed", "brave", _photo(Vector2i(200, 300)))
	var characters: Array = studio.story.editor.character_items().map(func(item: Dictionary) -> String: return item["label"])
	assert_eq(characters[0], "Captain Zed", "the story's own characters come first")
	assert_true(studio.story.editor.check_context.cast.has("captain_zed"), "hints know the new character")
	var editor: StudioBlockEditor = studio.story.editor
	assert_true(editor.add_block("show", 0, 0, {"character": "captain_zed"}))
	var chip: Button = editor.get_blocks()[0].find_children("*", "Button", true, false).filter(func(button: Node) -> bool:
		return button.get_meta("field_key", "") == "field:character")[0]
	assert_eq(chip.text, "Captain Zed", "chips show the character's own name")
	if FileAccess.file_exists("user://test_panel_settings.json"):
		DirAccess.remove_absolute("user://test_panel_settings.json")
	var story: Node = tree.root.get_node("Story")
	story.start(story.load_config())


func test_the_studios_own_starter_art() -> void:
	var maya := StudioStarter.profile("maya")
	assert_eq(maya.get_display_name(), "Maya", "folder characters read their profile.json")
	assert_eq(maya.default_mood, "neutral")
	assert_eq(Array(maya.look.get_moods()), ["happy", "neutral", "sad", "surprised", "thinking"])
	assert_true(StudioStarter.picture("cast", "robo", "happy") is Texture2D)
	assert_true(StudioStarter.picture("backdrops", "space") is Texture2D)
	var id := library.create("Space Trip")
	var panel := await _open(id)
	assert_true(panel.add_starter("cast", "whiskers"))
	assert_true(panel.add_starter("backdrops", "castle"))
	assert_true(panel.add_starter("music", "adventure"))
	assert_true(panel.add_starter("sounds", "pop"))
	assert_eq(panel.get_tiles("cast")["whiskers"].text, "Whiskers")
	assert_eq(panel.get_tiles("cast")["whiskers"].get_meta("item"), "whiskers")
	var copied: CastProfile = StoryStage.scan_cast(library.asset_folder(id, "cast"))["whiskers"]
	assert_eq(copied.name_color.to_html(false), "f09646", "the copy keeps the name color")
	assert_eq(copied.look.get_moods().size(), 5)
	assert_eq(panel.get_tiles("backdrops").keys(), ["castle"])
	assert_eq(panel.get_tiles("sounds").keys(), ["adventure", "pop"])


func test_sound_tiles_show_their_whole_name() -> void:
	var id := library.create("Space Trip")
	library.add_starter_item(id, "music", "adventure")
	var panel := await _open(id)
	var tile: Button = panel.get_tiles("sounds")["adventure"]
	assert_false(tile.clip_text)
	assert_true(tile.get_combined_minimum_size().x >= tile.get_theme_font("font").get_string_size(tile.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tile.get_theme_font_size("font_size")).x)

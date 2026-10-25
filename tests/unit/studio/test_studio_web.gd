extends "res://tests/framework/story_test.gd"
## Tests for the Studio's web version (studio/web/): the self-check that
## tools/check_studio_web.sh runs in a browser also passes on a desktop,
## and the browser helpers do nothing outside a browser.

const ROOT := "user://test_web_stories"
const SETTINGS := "user://test_web_settings.json"

var studio: Control


func before_each() -> void:
	super()
	StudioLibrary._remove_folder(ROOT)
	studio = track(preload("res://studio/studio.tscn").instantiate())
	studio.library_root = ROOT
	studio.settings_path = SETTINGS
	tree.root.add_child(studio)
	await tree.process_frame


func after_each() -> void:
	if studio.story.is_playing():
		studio.story.stop_playing()
	StudioLibrary._remove_folder(ROOT)
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)
	var story: Node = tree.root.get_node("Story")
	story.start(story.load_config())
	super()


func test_the_web_check_makes_a_story_and_finds_it_again() -> void:
	var make: StudioWebCheck = track(StudioWebCheck.new(studio, "make"))
	await make.make()
	assert_eq(make.problems, PackedStringArray())
	var id := make.story_id()
	assert_false(id.is_empty())
	assert_true(studio.library.has_asset(id, "cast", "robo"))
	studio.show_home()
	var reopen: StudioWebCheck = track(StudioWebCheck.new(studio, "reopen"))
	await reopen.reopen()
	assert_eq(reopen.problems, PackedStringArray())
	assert_true(studio.story.is_playing(), "the story plays")


func test_the_web_check_notices_a_missing_story() -> void:
	var reopen: StudioWebCheck = track(StudioWebCheck.new(studio, "reopen"))
	await reopen.reopen()
	assert_eq(reopen.problems, PackedStringArray(["the story was gone after the page was loaded again"]))


func test_browser_helpers_do_nothing_outside_a_browser() -> void:
	assert_false(StudioWeb.is_web())
	assert_eq(StudioWeb.query("check"), "")
	assert_true(StudioWeb.storage_is_kept())
	StudioWeb.keep_storage()
	StudioWeb.save_file(PackedByteArray([1, 2, 3]), "x.zip")
	var called := []
	StudioWeb.pick_file(".zip", func(_bytes: PackedByteArray, _name: String) -> void: called.append(true))
	assert_eq(called, [])


func test_a_picked_picture_is_read_from_its_bytes() -> void:
	var image := Image.create(4, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color.ORANGE)
	assert_eq(StudioFiles.picture_from_bytes(image.save_png_to_buffer()).get_size(), Vector2i(4, 3))
	assert_null(StudioFiles.picture_from_bytes("not a picture".to_utf8_buffer()))
	var path := StudioFiles._save_picked("RIFF....".to_utf8_buffer(), "birdsong")
	assert_eq(path, StudioFiles.OUTBOX.path_join("birdsong"))
	assert_eq(StudioFiles._save_picked(PackedByteArray(), "empty"), "")
	DirAccess.remove_absolute(path)

extends "res://tests/framework/story_test.gd"
## Tests for the Studio's story library (studio/stories/): stories in the
## app's storage, and story files to share and open.

const ROOT := "user://test_stories"
const ZIP := "user://test_story_file.zip"

var library: StudioLibrary


func before_each() -> void:
	super()
	_clean()
	library = StudioLibrary.new(ROOT)


func after_each() -> void:
	_clean()
	super()


func _clean() -> void:
	StudioLibrary._remove_folder(ROOT)
	if FileAccess.file_exists(ZIP):
		DirAccess.remove_absolute(ZIP)


func test_stories_are_made_listed_and_renamed() -> void:
	var id := library.create("My Story")
	assert_eq(id, "my_story")
	assert_eq(library.create("My story!"), "my_story_2", "ids never repeat")
	assert_eq(library.create("!!!"), "story")
	assert_eq(library.read_tale(id), StudioLibrary.BLANK_TALE)
	assert_false(TaleParser.parse(library.read_tale(id)).has_errors(), "a blank story is a valid tale")
	library.save_tale(id, "beat start:\n\t\"Changed.\"\n")
	var stories := library.list()
	assert_eq(stories.map(func(story: Dictionary) -> String: return story["id"]).front(), "my_story", "the latest change comes first")
	assert_eq(stories.size(), 3)
	library.rename(id, "The Big Day")
	assert_eq(library.get_story(id)["title"], "The Big Day")
	assert_eq(library.tale_path(id), ROOT + "/my_story/tales/my_story.tale", "renaming keeps the id")
	library.delete(id)
	assert_true(library.get_story(id).is_empty())
	assert_false(DirAccess.dir_exists_absolute(ROOT + "/my_story"))


func test_the_sample_is_added_once() -> void:
	library.add_sample()
	assert_eq(library.list().size(), 1)
	assert_eq(library.get_story("wheres_biscuit")["title"], "Where's Biscuit?")
	assert_eq(library.read_tale("wheres_biscuit"), FileAccess.get_file_as_string(StudioLibrary.SAMPLE_TALE))
	library.delete("wheres_biscuit")
	library.add_sample()
	assert_true(library.list().is_empty(), "a deleted sample stays deleted")


func test_a_copy_saved_before_story_folders_is_kept() -> void:
	StudioLibrary._write(ROOT + "/wheres_biscuit/wheres_biscuit.tale", "beat start:\n\t\"My version.\"\n")
	library.add_sample()
	assert_eq(library.read_tale("wheres_biscuit"), "beat start:\n\t\"My version.\"\n")
	assert_eq(library.get_story("wheres_biscuit")["title"], "Where's Biscuit?")


func test_stories_go_into_a_file_and_come_back() -> void:
	var id := library.create("Space Trip", "beat start:\n\tif visited(\"space_trip.moon\"):\n\t\tpass\n\tjump moon\n\nbeat moon:\n\tpass\n")
	assert_true(library.pack(id, ZIP))
	var reader := ZIPReader.new()
	assert_eq(reader.open(ZIP), OK)
	assert_eq(Array(reader.get_files()).filter(func(file: String) -> bool: return not file.ends_with("/")), ["story.json", "tales/space_trip.tale"])
	reader.close()
	var copy := library.unpack(ZIP)
	assert_eq(copy, "space_trip_2", "a second copy gets its own id")
	assert_eq(library.get_story(copy)["title"], "Space Trip")
	assert_true(library.read_tale(copy).contains("visited(\"space_trip_2.moon\")"), "its tests point at the copy")
	library.delete(id)
	assert_eq(library.unpack(ZIP), "space_trip", "on another device the id stays")


func test_files_that_are_not_stories_are_refused() -> void:
	assert_eq(library.unpack("user://no_such_file.zip"), "")
	assert_eq(library.last_error, "That file is not a story file.")
	var packer := ZIPPacker.new()
	packer.open(ZIP)
	packer.start_file("../escape.tale")
	packer.write_file("beat start:\n\tpass\n".to_utf8_buffer())
	packer.close_file()
	packer.close()
	assert_eq(library.unpack(ZIP), "")
	assert_eq(library.last_error, "That file is not a story from the Studio.")
	assert_true(library.list().is_empty())


func test_reminders_to_share_a_copy() -> void:
	var day := 86400.0
	var story := {"created": 0.0, "changed": 2 * day, "shared": 0.0}
	assert_false(StudioLibrary.needs_reminder(story, 3 * day), "a new story")
	assert_true(StudioLibrary.needs_reminder(story, 8 * day), "a week without sharing")
	story["shared"] = 5 * day
	assert_false(StudioLibrary.needs_reminder(story, 20 * day), "nothing changed since sharing")
	story["changed"] = 6 * day
	assert_true(StudioLibrary.needs_reminder(story, 13 * day))


func test_an_empty_folder_left_behind_does_not_take_an_id() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "/wheres_biscuit")
	library.add_sample()
	assert_eq(library.list().map(func(story: Dictionary) -> String: return story["id"]), ["wheres_biscuit"])


func test_a_copy_points_its_tests_at_itself() -> void:
	var id := library.create("Copy", "beat start:\n\tif visited(\"original.start\"):\n\t\tpass\n", "original")
	assert_eq(library.read_tale(id), "beat start:\n\tif visited(\"copy.start\"):\n\t\tpass\n")


func test_an_empty_first_copy_gives_way_to_the_sample() -> void:
	StudioLibrary._write(ROOT + "/wheres_biscuit/wheres_biscuit.tale", "")
	library.add_sample()
	assert_eq(library.read_tale("wheres_biscuit"), StudioLibrary.sample_text())
	assert_false(FileAccess.file_exists(ROOT + "/wheres_biscuit/wheres_biscuit.tale"))

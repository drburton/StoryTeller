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


static func _photo(size: Vector2i, see_through := false) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.6, 0.9, 0.5 if see_through else 1.0))
	return image


func test_a_story_has_its_own_folders() -> void:
	var id := library.create("Space Trip")
	var config := library.story_config(id, load("res://examples/wheres_biscuit/story_config.tres"))
	assert_eq(config.backdrop_folder, ROOT + "/space_trip/backdrops")
	assert_eq(config.cast_folder, ROOT + "/space_trip/cast")
	assert_eq(config.audio_folder, ROOT + "/space_trip/audio")
	assert_eq(config.tales_folder, ROOT + "/space_trip/tales")
	assert_eq(config.save_folder, ROOT + "/space_trip/saves")
	assert_eq(config.game_title, "Space Trip")


func test_the_names_a_tale_uses() -> void:
	var used := StudioLibrary.names_used("beat start:\n\tbackdrop(\"yard\")\n\ttheo.enter(\"happy\", at = LEFT)\n\tleo: \"Hi\"\n\tmira.mood = \"smile\"\n\tif score > 1:\n\t\tmusic(\"theme\")\n\tsound(\"ding\")\n\tcg(\"hug\")\n")
	assert_eq(used["backdrops"], ["yard"])
	assert_eq(used["cgs"], ["hug"])
	assert_eq(used["music"], ["theme"])
	assert_eq(used["sounds"], ["ding"])
	used["cast"].sort()
	assert_eq(used["cast"], ["leo", "mira", "theo"])


func test_starter_items_the_story_uses_are_copied_in() -> void:
	library.add_sample()
	var copied := library.add_starter_items("wheres_biscuit")
	copied.sort()
	assert_eq(copied, PackedStringArray(["backdrops/backyard", "backdrops/living_room", "cast/biscuit", "cast/cleo", "cast/leo", "cast/theo"]))
	assert_eq(library.asset_names("wheres_biscuit", "cast"), PackedStringArray(["biscuit", "cleo", "leo", "theo"]))
	var theo: CastProfile = StoryStage.scan_cast(library.asset_folder("wheres_biscuit", "cast"))["theo"]
	assert_eq(theo.get_display_name(), "Theo")
	assert_eq(theo.default_mood, "neutral")
	assert_true(theo.look.get_moods().size() >= 4, "every face")
	assert_true(library.add_starter_items("wheres_biscuit").is_empty(), "copied once")
	assert_true(library.add_starter_item("wheres_biscuit", "music", "quiet_morning"))
	assert_true(StoryAssets.load_asset(library.asset_folder("wheres_biscuit", "music"), "quiet_morning", StoryAssets.AUDIO_EXTENSIONS) is AudioStreamWAV)


func test_the_students_own_pictures_and_sounds() -> void:
	var id := library.create("Space Trip")
	assert_eq(library.add_picture(id, "backdrops", "My Room", _photo(Vector2i(4000, 3000))), "my_room")
	var room := StoryAssets.load_asset(library.asset_folder(id, "backdrops"), "my_room", StoryAssets.IMAGE_EXTENSIONS) as Texture2D
	assert_eq(room.get_size(), Vector2(1440, 1080), "scaled down to fit")
	assert_true(FileAccess.file_exists(library.asset_folder(id, "backdrops").path_join("my_room.jpg")), "photos are saved small")
	assert_eq(library.add_face(id, "Grandma Rose", "Happy", _photo(Vector2i(300, 400), true)), "grandma_rose")
	assert_eq(library.add_face(id, "Grandma Rose", "sad", _photo(Vector2i(300, 400), true)), "grandma_rose")
	var grandma: CastProfile = StoryStage.scan_cast(library.asset_folder(id, "cast"))["grandma_rose"]
	assert_eq(grandma.get_display_name(), "Grandma Rose")
	assert_eq(grandma.look.get_moods(), PackedStringArray(["happy", "sad"]))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = PackedByteArray([0, 0, 10, 10, 0, 0])
	stream.save_to_wav("user://test_ding.wav")
	assert_eq(library.add_sound(id, "sounds", "Ding!", "user://test_ding.wav"), "ding")
	assert_eq(library.asset_names(id, "sounds"), PackedStringArray(["ding"]))
	assert_eq(library.add_sound(id, "sounds", "notes", "res://README.md"), "", "only sounds")
	DirAccess.remove_absolute("user://test_ding.wav")


func test_story_files_carry_pictures_and_sounds() -> void:
	library.add_sample()
	library.add_starter_items("wheres_biscuit")
	library.add_picture("wheres_biscuit", "backdrops", "my room", _photo(Vector2i(64, 48)))
	assert_true(library.pack("wheres_biscuit", ZIP))
	var reader := ZIPReader.new()
	reader.open(ZIP)
	var files := Array(reader.get_files())
	reader.close()
	assert_true(files.has("backdrops/my_room.jpg"))
	assert_true(files.has("cast/theo/neutral.png"))
	assert_true(files.has("cast/theo/profile.json"))
	var copy := library.unpack(ZIP)
	assert_eq(library.asset_names(copy, "backdrops"), library.asset_names("wheres_biscuit", "backdrops"))
	assert_eq(library.asset_names(copy, "cast"), PackedStringArray(["biscuit", "cleo", "leo", "theo"]))


func test_story_files_leave_out_anything_else() -> void:
	var packer := ZIPPacker.new()
	packer.open(ZIP)
	for entry in [["story.json", "{\"title\": \"Odd\"}"], ["tales/odd.tale", "beat start:\n\tpass\n"],
			["backdrops/ok.png", "x"], ["backdrops/../../escape.png", "x"], ["cast/bad/profile.tres", "x"],
			["scripts/run.gd", "x"], ["backdrops/sub/deep.png", "x"]]:
		packer.start_file(entry[0])
		packer.write_file(entry[1].to_utf8_buffer())
		packer.close_file()
	packer.close()
	var id := library.unpack(ZIP)
	assert_eq(id, "odd")
	var files := StudioLibrary._files_under(library.folder(id), "")
	files.sort()
	assert_eq(files, PackedStringArray(["backdrops/ok.png", "story.json", "tales/odd.tale"]))

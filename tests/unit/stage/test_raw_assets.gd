extends "res://tests/framework/story_test.gd"
## Tests for pictures and sounds read straight from their files, outside
## the import system: what a game or the Studio saves in user://.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const ROOT := "user://test_raw_assets"


func before_each() -> void:
	super()
	_clean(ROOT)
	DirAccess.make_dir_recursive_absolute(ROOT.path_join("cast/sam"))
	DirAccess.make_dir_recursive_absolute(ROOT.path_join("backdrops"))
	DirAccess.make_dir_recursive_absolute(ROOT.path_join("audio/sounds"))
	_picture(Color.RED, 40).save_png(ROOT.path_join("backdrops/yard.png"))
	_picture(Color.GREEN, 20).save_png(ROOT.path_join("cast/sam/happy.png"))
	_picture(Color.BLUE, 20).save_jpg(ROOT.path_join("cast/sam/sad.jpg"))
	_tone().save_to_wav(ROOT.path_join("audio/sounds/ding.wav"))


func after_each() -> void:
	_clean(ROOT)
	super()


static func _clean(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for sub in dir.get_directories():
		_clean(folder.path_join(sub))
	for file_name in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(folder)


## A short tone as an uncompressed sound, which can be saved as a .wav file.
static func _tone() -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(4000 * 2)
	for i in 4000:
		data.encode_s16(i * 2, int(sin(i * 0.1) * 8000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 16000
	stream.data = data
	return stream


static func _picture(color: Color, size: int) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image


func test_raw_pictures_and_sounds_are_found_and_loaded() -> void:
	assert_eq(StoryAssets.find(ROOT.path_join("backdrops"), "yard", StoryAssets.IMAGE_EXTENSIONS), ROOT.path_join("backdrops/yard.png"))
	assert_true(StoryAssets.is_raw(ROOT.path_join("backdrops/yard.png")))
	var texture := StoryAssets.load_asset(ROOT.path_join("backdrops"), "yard", StoryAssets.IMAGE_EXTENSIONS) as Texture2D
	assert_not_null(texture)
	assert_eq(texture.get_size(), Vector2(40, 40))
	assert_eq(StoryAssets.list_names(ROOT.path_join("backdrops"), StoryAssets.IMAGE_EXTENSIONS), PackedStringArray(["yard"]))
	var sound := StoryAssets.load_asset(ROOT.path_join("audio/sounds"), "ding", StoryAssets.AUDIO_EXTENSIONS)
	assert_true(sound is AudioStreamWAV)
	assert_false(StoryAssets.is_raw("res://demo/story/audio/sounds/chime.wav"), "imported files load as before")
	assert_eq(StoryAssets.load_path(ROOT.path_join("backdrops/missing.png")), null)


func test_a_folder_of_raw_faces_is_a_character() -> void:
	var cast := StoryStage.scan_cast(ROOT.path_join("cast"))
	assert_eq(cast.keys(), ["sam"])
	var look: CastLook = cast["sam"].look
	assert_eq(look.get_moods(), PackedStringArray(["happy", "sad"]))
	assert_eq(look.get_preview("happy").get_size(), Vector2(20, 20))
	assert_not_null(look.get_preview("sad"), "jpg faces too")


func test_a_changed_picture_is_read_again() -> void:
	var path := ROOT.path_join("backdrops/yard.png")
	assert_eq(StoryAssets.load_path(path).get_size(), Vector2(40, 40))
	# Modified times count whole seconds.
	await tree.create_timer(1.1).timeout
	_picture(Color.RED, 60).save_png(path)
	assert_eq(StoryAssets.load_path(path).get_size(), Vector2(60, 60))


func test_the_stage_shows_raw_pictures() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage]
	config.cast_folder = ROOT.path_join("cast")
	config.backdrop_folder = ROOT.path_join("backdrops")
	var story: Node = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	var presenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	director.presenter = presenter
	await tree.process_frame
	var result := TaleCompiler.build("beat start:\n\tbackdrop(\"yard\", transition = \"none\")\n\tsam.enter(\"happy\", at = LEFT)\n\tsam: \"Hello!\"\n", "main", director.make_check_context("main"))
	for diagnostic in result["diagnostics"]:
		assert_false(diagnostic.is_error(), str(diagnostic))
	director.add_tale(result["tale"])
	await director.play("main")
	var stage: StoryStage = story.get_crew(&"Stage")
	var state := stage.capture()
	assert_eq(state["backdrop"], "yard")
	assert_eq(state["cast"]["sam"]["mood"], "happy")
	assert_eq(presenter.lines, ["Sam: Hello!"])

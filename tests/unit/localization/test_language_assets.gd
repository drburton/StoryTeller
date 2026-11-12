extends "res://tests/framework/story_test.gd"
## Tests for pictures and voice per language (decision 0031): language
## folders in asset folders, the voice fallback to the source language, the
## title picture's language versions, the stage switching pictures when the
## language changes, and products in Export Strings.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ROOT := "user://test_language_assets"

var _locale := ""


func before_each() -> void:
	super()
	_locale = TranslationServer.get_locale()
	_clean(ROOT)
	for folder in ["backdrops/es", "cast/sam/es", "cast/leo", "cgs/es", "cgs/party", "audio/voice/es", "audio/voice/en"]:
		DirAccess.make_dir_recursive_absolute(ROOT.path_join(folder))
	_picture(40).save_png(ROOT.path_join("backdrops/street.png"))
	_picture(20).save_png(ROOT.path_join("backdrops/es/street.png"))
	_picture(40).save_png(ROOT.path_join("backdrops/plain.png"))
	_picture(30).save_png(ROOT.path_join("cast/sam/happy.png"))
	_picture(10).save_png(ROOT.path_join("cast/sam/es/happy.png"))
	_picture(30).save_png(ROOT.path_join("cast/leo/happy.png"))
	_picture(30).save_png(ROOT.path_join("cgs/party/default.png"))
	_picture(30).save_png(ROOT.path_join("cgs/es/party.png"))
	_picture(40).save_png(ROOT.path_join("title.png"))
	_picture(20).save_png(ROOT.path_join("title.es.png"))
	_tone(4000).save_to_wav(ROOT.path_join("audio/voice/es/line.wav"))
	_tone(2000).save_to_wav(ROOT.path_join("audio/voice/en/line.wav"))
	_tone(1000).save_to_wav(ROOT.path_join("audio/voice/en/only_english.wav"))
	_tone(500).save_to_wav(ROOT.path_join("audio/voice/old.wav"))
	StoryAssets.source_language = "en"
	StoryAssets.languages = PackedStringArray(["es"])


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	StoryAssets.languages = PackedStringArray()
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


static func _picture(size: int) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


static func _tone(samples: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		data.encode_s16(i * 2, int(sin(i * 0.1) * 8000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 16000
	stream.data = data
	return stream


func _find(asset: String) -> String:
	return StoryAssets.find(ROOT.path_join("backdrops"), asset, StoryAssets.IMAGE_EXTENSIONS)


func test_a_language_folder_wins_in_its_language() -> void:
	TranslationServer.set_locale("en")
	assert_eq(_find("street"), ROOT.path_join("backdrops/street.png"), "the source language uses the main folder")
	TranslationServer.set_locale("es")
	assert_eq(_find("street"), ROOT.path_join("backdrops/es/street.png"), "Spanish uses its folder")
	assert_eq(_find("plain"), ROOT.path_join("backdrops/plain.png"), "a picture Spanish lacks comes from the main folder")
	TranslationServer.set_locale("es_MX")
	assert_eq(_find("street"), ROOT.path_join("backdrops/es/street.png"), "a regional locale uses its language's folder")
	TranslationServer.set_locale("fr")
	assert_eq(_find("street"), ROOT.path_join("backdrops/street.png"), "another language uses the main folder")


func test_language_folders_are_not_cgs_or_cast_members() -> void:
	assert_true(StoryAssets.is_language_folder("es"))
	assert_true(StoryAssets.is_language_folder("en"), "the source language")
	assert_false(StoryAssets.is_language_folder("leo"), "a character's name")
	assert_false(StoryAssets.is_language_folder("sam"))
	assert_eq(StoryAssets.scan_cgs(ROOT.path_join("cgs")).keys(), ["party"], "es/ is not a CG")
	var cast: Array = StoryStage.scan_cast(ROOT.path_join("cast")).keys()
	cast.sort()
	assert_eq(cast, ["leo", "sam"], "es/ inside sam/ is not a character, and leo still is")


func test_a_face_has_a_version_per_language() -> void:
	var look := SpriteSetLook.new()
	look.folder = ROOT.path_join("cast/sam")
	TranslationServer.set_locale("en")
	assert_eq(look.get_texture("happy").get_width(), 30)
	TranslationServer.set_locale("es")
	assert_eq(look.get_texture("happy").get_width(), 10, "the Spanish face")
	assert_eq(look.get_moods(), PackedStringArray(["happy"]), "the language folder adds no mood")


func test_voice_per_language_falls_back_to_the_source_language() -> void:
	var audio := StoryAudio.new()
	audio.audio_folder = ROOT.path_join("audio")
	TranslationServer.set_locale("es")
	assert_eq(audio.find_stream_path("voice", "line"), ROOT.path_join("audio/voice/es/line.wav"), "the Spanish recording")
	assert_eq(audio.find_stream_path("voice", "only_english"), ROOT.path_join("audio/voice/en/only_english.wav"), "a line Spanish lacks plays in the source language")
	assert_eq(audio.find_stream_path("voice", "old"), ROOT.path_join("audio/voice/old.wav"), "the voice folder itself still works")
	TranslationServer.set_locale("en")
	assert_eq(audio.find_stream_path("voice", "line"), ROOT.path_join("audio/voice/en/line.wav"), "the source language's folder")
	assert_eq(audio.find_stream_path("music", "line"), "", "only voice falls back")
	audio.free()


func test_the_title_picture_has_language_versions() -> void:
	var title := StoryAssets.load_path(ROOT.path_join("title.png")) as Texture2D
	title.resource_path = ROOT.path_join("title.png")
	TranslationServer.set_locale("en")
	assert_eq(StoryAssets.localized_resource(title), title)
	TranslationServer.set_locale("es")
	assert_eq((StoryAssets.localized_resource(title) as Texture2D).get_width(), 20, "title.es.png")
	assert_null(StoryAssets.localized_resource(null))


func test_the_stage_switches_pictures_when_the_language_changes() -> void:
	TranslationServer.set_locale("en")
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage]
	config.backdrop_folder = ROOT.path_join("backdrops")
	config.cast_folder = ROOT.path_join("cast")
	config.languages = PackedStringArray(["es"])
	var story: Node = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	await tree.process_frame
	var stage := story.get_crew(&"Stage") as StoryStage
	await stage.show_backdrop("street", "none", 0.0)
	var member := stage.get_cast("sam")
	await member.enter("happy", Vector2(0.5, 0.0), 0.0, "none")
	await tree.process_frame
	assert_eq(stage.backdrop_view._sides["to_size"], Vector2(40, 40), "the English backdrop")
	TranslationServer.set_locale("es")
	await tree.process_frame
	await tree.process_frame
	assert_eq(stage.backdrop_view._sides["to_size"], Vector2(20, 20), "the Spanish backdrop, at once")
	assert_eq((member.find_child("Sprite", true, false) as Sprite2D).texture.get_width(), 10, "the Spanish face")


func test_export_strings_lists_products() -> void:
	var config := StoryConfig.new()
	config.tales_folder = ROOT.path_join("no_tales")
	config.cast_folder = ROOT.path_join("no_cast")
	config.collection_folder = ROOT.path_join("no_collection")
	config.product_folder = ROOT.path_join("no_products")
	var product := StoryProduct.new()
	product.id = "full_story"
	product.title = "The whole story"
	product.description = "Chapters two to five."
	config.products = [product]
	var keys: Array = StoryStrings.collect(config)["entries"].map(func(entry: Dictionary) -> String: return entry["key"])
	assert_has(keys, "The whole story")
	assert_has(keys, "Chapters two to five.")

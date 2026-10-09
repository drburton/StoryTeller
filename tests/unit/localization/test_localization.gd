extends "res://tests/framework/story_test.gd"
## Tests for translated lines, options, and names, and for exporting
## strings to CSV.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const CSV_PATH := "user://test_strings/story.csv"
const SOURCE := """var guest := "Sam"

beat start:
	robin: "Hello, {guest}."
	choose:
		"Wave":
			"You wave."
		"Leave":
			pass
"""

var story: Node
var director: TaleDirector
var presenter: ScriptedPresenter
var errors: Array[String] = []
var _translations: Array[Translation] = []
var _locale := ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_clean_csv()
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryStage]
	config.cast_folder = "res://tests/fixtures/cast"
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	presenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	director.presenter = presenter
	errors.clear()
	director.runtime_error.connect(func(message: String, _tale: String, line: int) -> void:
		errors.append("%d: %s" % [line, message]))
	await tree.process_frame


func after_each() -> void:
	for translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()
	TranslationServer.set_locale(_locale)
	_clean_csv()


func _clean_csv() -> void:
	if FileAccess.file_exists(CSV_PATH):
		DirAccess.remove_absolute(CSV_PATH)


func _translate(locale: String, messages: Dictionary) -> void:
	var translation := Translation.new()
	translation.locale = locale
	for key in messages:
		translation.add_message(key, messages[key])
	TranslationServer.add_translation(translation)
	_translations.append(translation)


func _tale() -> Tale:
	var result := TaleCompiler.build(SOURCE, "main", director.make_check_context("main"))
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail(str(diagnostic))
	director.add_tale(result["tale"])
	return result["tale"]


func _key(tale: Tale, text: String) -> String:
	for id in tale.texts:
		if tale.texts[id] == text:
			return tale.translation_key(id)
	fail("no line '%s'" % text)
	return ""


func test_compile_text_handles_interpolation() -> void:
	var compiled := TaleCompiler.compile_text("Hola, {guest}. {{ok}}")
	assert_eq(compiled["errors"], PackedStringArray())
	assert_eq(compiled["parts"], ["Hola, ", ["name", "guest"], ". {ok}"])
	assert_eq(TaleCompiler.compile_text("Bad {")["errors"].size(), 1)


func test_tale_records_source_text_by_id() -> void:
	var tale := _tale()
	assert_eq(tale.texts.values(), ["Hello, {guest}.", "Wave", "You wave.", "Leave"])
	assert_true(_key(tale, "Wave").begins_with("main:start_"))


func test_lines_options_and_names_use_the_translation() -> void:
	var tale := _tale()
	_translate("es", {
		_key(tale, "Hello, {guest}."): "Hola, {guest}.",
		_key(tale, "Wave"): "Saludar",
		_key(tale, "You wave."): "Saludas.",
		"Robin": "Petirrojo",
	})
	TranslationServer.set_locale("es")
	await director.play("main")
	assert_eq(errors, [])
	assert_eq(presenter.lines, ["Petirrojo: Hola, Sam.", "Saludas."])
	assert_eq(presenter.offered[0], ["Saludar", "Leave"])


func test_names_given_during_play_are_translated() -> void:
	var result := TaleCompiler.build("beat start:\n\trobin.display_name = \"The Stranger\"\n\trobin: \"Hm.\"\n", "main", director.make_check_context("main"))
	director.add_tale(result["tale"])
	_translate("es", {"The Stranger": "El Desconocido"})
	TranslationServer.set_locale("es")
	await director.play("main")
	assert_eq(errors, [])
	assert_eq(presenter.lines, ["El Desconocido: Hm."])


func test_source_language_shows_the_tale_text() -> void:
	var tale := _tale()
	_translate("en", {_key(tale, "Hello, {guest}."): "Old text from the CSV."})
	TranslationServer.set_locale("en_US")
	await director.play("main")
	assert_eq(presenter.lines[0], "Robin: Hello, Sam.")


func test_broken_translation_is_reported_and_original_shown() -> void:
	var tale := _tale()
	_translate("es", {_key(tale, "Hello, {guest}."): "Hola, {guest."})
	TranslationServer.set_locale("es")
	await director.play("main")
	assert_eq(presenter.lines[0], "Robin: Hello, Sam.")
	assert_eq(errors.size(), 1)
	assert_true(errors[0].begins_with("4: The es translation of this line has a problem"))


func _config() -> StoryConfig:
	var config := StoryConfig.new()
	config.tales_folder = "res://tests/fixtures/localization/tales"
	config.cast_folder = "res://tests/fixtures/cast"
	config.game_title = "Test Game"
	return config


func test_collect_finds_every_string() -> void:
	var result := StoryStrings.collect(_config())
	assert_eq(result["problems"], PackedStringArray())
	var texts := {}
	for entry in result["entries"]:
		texts[entry["key"]] = entry["text"]
	assert_eq(texts.get("meeting:stay_quiet"), "Say nothing", "pinned ids are kept")
	assert_eq(texts.get("The Meeting"), "The Meeting", "tale title")
	assert_eq(texts.get("Your name?"), "Your name?", "tr() text")
	assert_eq(texts.get("Robin"), "Robin", "cast name")
	assert_eq(texts.get("The Stranger"), "The Stranger", "a name given during play")
	assert_eq(texts.get("Test Game"), "Test Game", "game title")
	assert_eq(texts.get("New Game"), "New Game", "menu text")
	var lines: Array = result["entries"].filter(func(entry: Dictionary) -> bool: return entry["key"].begins_with("meeting:"))
	assert_eq(lines.map(func(entry: Dictionary) -> String: return entry["text"]), ["A quiet room.", "Hello, {guest}.", "Wave", "Say nothing", "Hi!"], "options come with their choice")
	assert_eq(lines[1]["context"], "meeting.tale:8 (robin)")


func test_runtime_keys_match_exported_keys() -> void:
	var source := FileAccess.get_file_as_string("res://tests/fixtures/localization/tales/meeting.tale")
	var built := TaleCompiler.build(source, "meeting", director.make_check_context("meeting"))
	for diagnostic in built["diagnostics"]:
		if diagnostic.is_error():
			fail(str(diagnostic))
	var runtime_keys := []
	for id in built["tale"].texts:
		runtime_keys.append(built["tale"].translation_key(id))
	var exported: Array = StoryStrings.collect(_config())["entries"].map(func(entry: Dictionary) -> String: return entry["key"])
	for key in runtime_keys:
		assert_has(exported, key)


func test_write_csv_keeps_translations_across_exports() -> void:
	var entries: Array[Dictionary] = [
		{"key": "t:a", "text": "Hello.", "context": "t.tale:3"},
		{"key": "t:b", "text": "Bye.", "context": "t.tale:4"},
		{"key": "t:c", "text": "Gone soon.", "context": "t.tale:5"},
	]
	assert_eq(StoryStrings.write_csv(CSV_PATH, entries, "en", PackedStringArray(["es"])), OK)
	var first := StoryStrings.read_csv(CSV_PATH)
	assert_eq(first["languages"], ["en", "es"])
	# A translator fills in Spanish.
	var file := FileAccess.open(CSV_PATH, FileAccess.WRITE)
	file.store_csv_line(PackedStringArray(["keys", "en", "es", "_context", "_status"]))
	file.store_csv_line(PackedStringArray(["t:a", "Hello.", "Hola.", "t.tale:3", ""]))
	file.store_csv_line(PackedStringArray(["t:b", "Bye.", "Adiós.", "t.tale:4", ""]))
	file.store_csv_line(PackedStringArray(["t:c", "Gone soon.", "Pronto.", "t.tale:5", ""]))
	file.close()
	# The writer edits one line, removes another, and adds a third.
	var second: Array[Dictionary] = [
		{"key": "t:a", "text": "Hello.", "context": "t.tale:3"},
		{"key": "t:b", "text": "Goodbye.", "context": "t.tale:4"},
		{"key": "t:d", "text": "New line.", "context": "t.tale:6"},
	]
	assert_eq(StoryStrings.write_csv(CSV_PATH, second, "en", PackedStringArray()), OK)
	var rows: Dictionary = StoryStrings.read_csv(CSV_PATH)["rows"]
	assert_eq(rows["t:a"], {"en": "Hello.", "es": "Hola.", "_context": "t.tale:3", "_status": ""})
	assert_eq(rows["t:b"]["es"], "Adiós.")
	assert_eq(rows["t:b"]["_status"], StoryStrings.STATUS_CHANGED)
	assert_eq(rows["t:c"]["_status"], StoryStrings.STATUS_UNUSED)
	assert_eq(rows["t:c"]["es"], "Pronto.", "translations of unused lines are kept")
	assert_eq(rows["t:d"]["es"], "")
	assert_eq(StoryStrings.read_csv(CSV_PATH)["order"], ["t:a", "t:b", "t:d", "t:c"])


func test_register_translations_adds_project_settings() -> void:
	var setting := "internationalization/locale/translations"
	var before: Variant = ProjectSettings.get_setting(setting, PackedStringArray())
	var entries: Array[Dictionary] = [{"key": "t:a", "text": "Hello.", "context": ""}]
	StoryStrings.write_csv(CSV_PATH, entries, "en", PackedStringArray(["es"]))
	assert_true(StoryStrings.register_translations(CSV_PATH))
	var paths := PackedStringArray(ProjectSettings.get_setting(setting))
	assert_has(paths, "user://test_strings/story.en.translation")
	assert_has(paths, "user://test_strings/story.es.translation")
	assert_false(StoryStrings.register_translations(CSV_PATH), "nothing new the second time")
	ProjectSettings.set_setting(setting, before)


func test_menu_text_list_is_complete() -> void:
	var pattern := RegEx.create_from_string("(?:make_button|make_title|_add|confirm|tr|_label|translate)\\(\"((?:[^\"\\\\]|\\\\.)+)\"|^\\s*\\[\"([^\"]+)\", \"")
	var missing := []
	for folder in ["res://addons/storyteller/menus", "res://addons/storyteller/ui"]:
		for file_name in DirAccess.get_files_at(folder):
			if file_name.get_extension() != "gd":
				continue
			for line in FileAccess.get_file_as_string(folder.path_join(file_name)).split("\n"):
				for found in pattern.search_all(line):
					var text := found.get_string(1) if not found.get_string(1).is_empty() else found.get_string(2)
					if text not in StoryMenus.UI_TEXT and text not in missing:
						missing.append(text)
	assert_eq(missing, [], "add these to StoryMenus.UI_TEXT")


func test_named_styles_apply_to_lines_and_translations() -> void:
	assert_true(director.text_styles.has("whisper"), "the config's default styles reach the director")
	director.text_styles = {"whisper": "[i]"}
	var result := TaleCompiler.build("beat start:\n\trobin: \"[whisper]Over here.[/whisper]\"\n", "main", director.make_check_context("main"))
	director.add_tale(result["tale"])
	await director.play("main")
	assert_eq(presenter.lines, ["Robin: [i]Over here.[/i]"])
	_translate("es", {_key(result["tale"], "[whisper]Over here.[/whisper]"): "[whisper]Por aquí.[/whisper]"})
	TranslationServer.set_locale("es")
	presenter.lines.clear()
	await director.play("main")
	assert_eq(presenter.lines, ["Robin: [i]Por aquí.[/i]"], "translations use the styles too")

extends "res://tests/framework/story_test.gd"
## Keeps the demo working: its tales check cleanly, its config opens on
## the title screen, and the 3D scene's conversation opens the gate.

const TaleImporter := preload("res://addons/storyteller/editor/tale_importer.gd")
const DEMO_TALES := "res://demo/tales"
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")


func test_demo_tales_have_no_diagnostics() -> void:
	var names := PackedStringArray()
	for file_name in DirAccess.get_files_at(DEMO_TALES):
		if not file_name.ends_with(".tale"):
			continue
		var path := DEMO_TALES.path_join(file_name)
		var tale_name := file_name.get_basename()
		names.append(tale_name)
		var context := TaleImporter._make_context(path, tale_name)
		var result := TaleCompiler.build(FileAccess.get_file_as_string(path), tale_name, context)
		for diagnostic in result["diagnostics"]:
			fail("%s: %s" % [file_name, diagnostic])
	assert_has(names, "welcome")


func test_demo_config_starts_from_the_title_screen() -> void:
	var config := load("res://demo/story_config.tres") as StoryConfig
	assert_eq(config.start_tale, "welcome")
	assert_true(ResourceLoader.exists(DEMO_TALES.path_join(config.start_tale + ".tale")))
	assert_false(config.game_title.is_empty())


func test_whole_demo_plays_without_errors() -> void:
	var run := await _play_demo("en")
	assert_eq(run["errors"], [])
	var lines: Array = run["lines"]
	assert_has(lines, "Ada: Nice to meet you, Robin.")
	assert_has(lines, "???: Oh! A visitor.[pause] Welcome to StoryTeller.", "Ada's name is hidden until she introduces herself")
	assert_has(lines, "Ada: I'm Ada. I look after this library.")
	assert_has(lines, "Mira: Thanks for today, Sam. Really.")
	assert_has(lines, "Mira: Same table tomorrow? I'll bring the coffee.", "two right answers and the umbrella raise friendship to 4")
	assert_has(lines, "Studied with Mira. Answered 2 of her questions.")
	assert_has(lines, "Mira: My coat is still drying from last night, you know.", "chapter 2 remembers staying late")
	assert_has(lines, "Question two asks when the library was built. Easy, after yesterday.", "and the quiz score")
	assert_has(lines, "Mira: I was going to ask you that.", "friendship opens the last option")
	assert_has(lines, "Mira: Results come out next week. We'll read them together.", "and the closer ending")
	assert_eq(lines.back(), "End of the StoryTeller demo. Thank you for playing.")
	for id in ["library", "library_theme", "talescript", "library_night", "classroom", "quiet_morning", "mira", "history_note"]:
		assert_true(run["collected"].has(id), id)
	assert_eq(run["route_titles"], [
		"A visitor in the library", "Questions for Ada", "The first morning", "An honest answer", "Off to class",
		"Lunch at the library", "Quiz time", "Rain on the windows", "Goodnight",
		"Exam morning", "The exam", "After the bell", "Study partners", "The end",
	], "the route chart shows every beat played, by its heading")
	assert_true(run["choice_settings"].any(func(settings: Dictionary) -> bool: return settings.get("style") == "pictures"), "chapter 1 has a picture choice")


func test_demo_choice_pictures_exist() -> void:
	var config := load("res://demo/story_config.tres") as StoryConfig
	var pictures := []
	for file_name in DirAccess.get_files_at(DEMO_TALES):
		if not file_name.ends_with(".tale"):
			continue
		var path := DEMO_TALES.path_join(file_name)
		var context := TaleImporter._make_context(path, file_name.get_basename())
		var tale: Tale = TaleCompiler.build(FileAccess.get_file_as_string(path), file_name.get_basename(), context)["tale"]
		for instruction in tale.instructions:
			if instruction["op"] == "choose":
				for option in instruction["options"]:
					if not option["picture"].is_empty():
						pictures.append(option["picture"])
	assert_eq(pictures, ["umbrella", "armchair", "door"])
	for picture in pictures:
		assert_ne(StoryAssets.find(config.choice_picture_folder, picture, StoryAssets.IMAGE_EXTENSIONS), "", picture)


func test_whole_demo_plays_in_spanish() -> void:
	var run := await _play_demo("es")
	assert_eq(run["errors"], [])
	var lines: Array = run["lines"]
	assert_has(lines, "Ada: Encantada de conocerte, Robin.")
	assert_has(lines, "Estudié con Mira. Respondí 2 de sus preguntas.")
	assert_has(lines, "Mira: ¿La misma mesa mañana? Yo traigo el café.")
	assert_has(lines, "Mira: Las notas salen la semana que viene. Las leeremos juntos.")
	assert_eq(lines.back(), "Fin de la demo de StoryTeller. Gracias por jugar.")
	assert_eq(run["route_titles"].slice(0, 3), ["Una visita en la biblioteca", "Preguntas para Ada", "La primera mañana"])


func test_spanish_translation_is_complete() -> void:
	var config := load("res://demo/story_config.tres") as StoryConfig
	var rows: Dictionary = StoryStrings.read_csv(config.translation_file)["rows"]
	var missing := []
	for entry in StoryStrings.collect(config)["entries"]:
		if not rows.has(entry["key"]) or str(rows[entry["key"]].get("es", "")).is_empty():
			missing.append(entry["key"])
	assert_eq(missing, [], "export strings and translate these")
	for key in rows:
		assert_eq(rows[key].get("_status", ""), "", "%s is marked %s" % [key, rows[key].get("_status")])


## Plays welcome, the prologue, and chapter 1 in skip mode with scripted
## choices. Returns {"errors", "lines", "collected"}.
func _play_demo(locale: String) -> Dictionary:
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale(locale)
	var config := (load("res://demo/story_config.tres") as StoryConfig).duplicate()
	config.save_folder = "user://test_demo_saves"
	config.settings_path = "user://test_demo_settings.cfg"
	config.return_to_title = false
	var story: Node = track(preload("res://addons/storyteller/core/story.gd").new())
	story.start(config)
	tree.root.add_child(story)
	await tree.process_frame
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	var menus: StoryMenus = story.get_crew(&"Menus")
	var presenter: ScriptedPresenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	director.presenter = presenter
	# Skip everything, the way a player would: skip on, unread lines too.
	(story.get_crew(&"Settings") as StorySettings).set_value("skip_unread", true)
	(story.get_crew(&"Dialogue") as StoryDialogue).skip_toggled = true
	var errors := []
	director.runtime_error.connect(func(message: String, tale_name: String, line: int) -> void:
		errors.append("%s:%d: %s" % [tale_name, line, message]))
	_answer_name(menus, director)
	# Picks are option positions, so the same path works in every language.
	presenter.picks = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0]
	await director.play("welcome")
	var collection: StoryCollection = story.get_crew(&"Collection")
	var collected := []
	for item_kind in StoryCollection.KINDS:
		for item in collection.get_items(item_kind):
			if collection.is_collected(item.id):
				collected.append(item.id)
	var chart := RouteChart.build(director.routes, director)
	var titles := chart.nodes.map(func(node: Dictionary) -> String: return node["title"])
	for file_name in DirAccess.get_files_at("user://test_demo_saves"):
		DirAccess.remove_absolute("user://test_demo_saves".path_join(file_name))
	DirAccess.remove_absolute("user://test_demo_settings.cfg")
	TranslationServer.set_locale(previous_locale)
	if not presenter.picks.is_empty():
		errors.append("unused picks: %s" % [presenter.picks])
	return {"errors": errors, "lines": presenter.lines, "collected": collected, "route_titles": titles, "choice_settings": presenter.settings}


## Types "Robin" into the name prompt whenever it opens, until the story ends.
func _answer_name(menus: StoryMenus, director: TaleDirector) -> void:
	await tree.process_frame
	while director.is_playing():
		var dialog: TextInputDialog = menus._screens.get("text_input")
		if dialog != null and dialog.visible:
			dialog._edit.text = "Robin"
			dialog._submit()
		await tree.process_frame


func test_dialogue_only_preset() -> void:
	var config := StoryConfig.dialogue_only()
	var names := config.crew.map(func(script: Script) -> String: return script.get_global_name())
	assert_eq(names, ["TaleDirector", "StoryAudio", "StorySaves", "StorySettings", "StoryHistory", "StoryDialogue"])
	assert_false(config.show_quick_menu)


func test_embedded_scene_conversation_opens_the_gate() -> void:
	var story: Node = tree.root.get_node("Story")
	var scene: Node3D = track(load("res://demo/embedded/embedded_demo.tscn").instantiate())
	tree.root.add_child(scene)
	await tree.process_frame
	assert_false(story.get_crew_names().has(&"Stage"), "the scene uses the dialogue-only crew")
	var presenter: ScriptedPresenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	director.presenter = presenter
	presenter.picks = ["Tell me the password?", "\"Lantern.\""]
	var signals := []
	director.story_signal.connect(func(signal_name: String, _value: Variant) -> void: signals.append(signal_name))
	await scene.talk()
	assert_eq(presenter.lines, [
		"Rook: Halt. Nobody passes without the password.",
		"Rook: That's not how passwords work.",
		"Rook: Halt. Nobody passes without the password.",
		"Rook: ...Fine. Who told you?",
		"Rook: Mind the step.",
	])
	assert_eq(signals, ["rook_impressed"])
	assert_true(scene._gate.is_open)
	await scene.talk()
	assert_eq(presenter.lines.back(), "Rook: The gate's open. Go on, the garden won't wait.")
	story.start(story.load_config())

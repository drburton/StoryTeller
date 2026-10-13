extends "res://tests/framework/story_test.gd"
## Tests for the Studio's templates and lessons (studio/templates/,
## studio/lessons/): every one opens in the blocks with no Code blocks,
## checks with the starter library, and starts a new story from the home
## screen.

const ROOT := "user://test_template_stories"

var library: StudioLibrary


func before_each() -> void:
	super()
	StudioLibrary._remove_folder(ROOT)
	library = StudioLibrary.new(ROOT)


func after_each() -> void:
	StudioLibrary._remove_folder(ROOT)
	super()


## Every text to start from: [name, text], with each lesson's start and
## finished version.
func _texts() -> Array:
	var texts := []
	for template in StudioTemplates.templates():
		texts.append([template["id"], StudioTemplates.template_text(template["id"])])
	for lesson in StudioTemplates.lessons():
		texts.append([lesson["id"] + "_start", StudioTemplates.lesson_text(lesson["id"])])
		texts.append([lesson["id"] + "_finished", StudioTemplates.lesson_text(lesson["id"], true)])
	return texts


func _all_cards(doc: TaleDocument) -> Array[TaleCard]:
	var cards: Array[TaleCard] = []
	var pending: Array[TaleCard] = []
	for statement in doc.statements:
		if statement.kind == TaleNode.Kind.BEAT:
			pending.append_array(TaleCard.build(statement))
	while not pending.is_empty():
		var card: TaleCard = pending.pop_front()
		cards.append(card)
		for lane in card.lanes:
			pending.append_array(lane["cards"])
	return cards


## Problems the checker finds in [param text] as the story [param id],
## with the starter items it uses copied in.
func _problems(text: String, id: String) -> Array:
	var story := library.create(id, text)
	library.add_starter_items(story)
	var config := library.story_config(story, StoryConfig.new())
	var context := TaleSignatures.make_context(library.tale_path(story), story, config)
	return TaleChecker.check(TaleParser.parse(library.read_tale(story)), context).map(func(problem: TaleDiagnostic) -> String:
		return "line %d: %s" % [problem.line, problem.message])


func test_there_are_templates_and_lessons() -> void:
	assert_eq(StudioTemplates.templates().map(func(template: Dictionary) -> String: return template["id"]), ["mystery", "adventure", "choose_your_path"])
	assert_eq(StudioTemplates.lessons().size(), 5)
	for entry in _texts():
		assert_false(entry[1].is_empty(), entry[0] + " has text")


func test_every_template_and_lesson_opens_in_the_blocks() -> void:
	for entry in _texts():
		var doc := TaleParser.parse(entry[1])
		assert_false(doc.has_errors(), entry[0] + " parses")
		var types := {}
		for card in _all_cards(doc):
			var block := StoryBlocks.describe(card, entry[1])
			assert_ne(block["type"], "code", "%s line %d: %s" % [entry[0], card.node.line_start, block["fields"].get("code", "")])
			types[block["type"]] = true
		assert_true(types.has("background"), entry[0] + " has a background")


func test_templates_and_finished_lessons_check_with_the_starter_library() -> void:
	for entry in _texts():
		if entry[0].ends_with("_start"):
			continue
		assert_eq(_problems(entry[1], entry[0]), [], entry[0])


func test_the_debugging_lesson_has_three_mistakes() -> void:
	var problems := _problems(StudioTemplates.lesson_text("lesson_5"), "lesson_5")
	assert_eq(problems.size(), 3, str(problems))


func test_new_story_offers_the_templates() -> void:
	var home: StudioHome = track(StudioHome.new())
	home.library = library
	tree.root.add_child(home)
	var opened := []
	home.story_chosen.connect(func(id: String) -> void: opened.append(id))
	home.new_story()
	var offered := home.find_children("*", "Button", true, false).map(func(button: Node) -> String: return button.get_meta("dialog_button", "")).filter(func(words: String) -> bool: return not words.is_empty())
	assert_eq(offered, ["A blank story", "A mystery", "An adventure", "Choose your path", "A copy of Where's Biscuit?", "Cancel"])
	for button in home.find_children("*", "Button", true, false):
		if button.get_meta("dialog_button", "") == "An adventure":
			button.pressed.emit()
	assert_eq(opened, ["my_story"])
	var text := library.read_tale("my_story")
	assert_true(text.contains("visited(\"my_story.forest\")"), "tests point at the new story")
	assert_false(text.contains("adventure.forest"))


func test_lessons_start_a_story_from_the_home_screen() -> void:
	var home: StudioHome = track(StudioHome.new())
	home.library = library
	tree.root.add_child(home)
	var opened := []
	home.story_chosen.connect(func(id: String) -> void: opened.append(id))
	var column := home.open_lessons()
	var starts := column.find_children("*", "Button", true, false).filter(func(button: Node) -> bool: return button.get_meta("lesson_button", "") == "Start")
	assert_eq(starts.size(), 5)
	starts[2].pressed.emit()
	assert_eq(library.get_story(opened[0])["title"], "3. Two ways to go")
	assert_eq(library.read_tale(opened[0]), StudioTemplates.lesson_text("lesson_3"))
	var finished := home.start_lesson("lesson_3", true)
	assert_eq(library.get_story(finished)["title"], "3. Two ways to go (finished)")
	assert_eq(home.start_lesson("no_such_lesson"), "")


func test_the_screenshot_list_names_steps_lessons_and_templates_that_exist() -> void:
	var shots = JSON.parse_string(FileAccess.get_file_as_string("res://studio/lessons/screenshots.json"))
	assert_true(shots is Array and not shots.is_empty())
	var steps := ["sample", "new_story", "lessons", "lesson", "template", "palette", "select", "scene", "map", "hint", "add", "play"]
	var names := {}
	for shot in shots:
		assert_false(names.has(shot["name"]), "one shot per name: " + shot["name"])
		names[shot["name"]] = true
		for step in shot["steps"]:
			assert_has(steps, step[0], shot["name"])
			if step[0] == "lesson":
				assert_false(StudioTemplates.lesson_text(step[1]).is_empty(), "%s: lesson %s" % [shot["name"], step[1]])
			elif step[0] == "template":
				assert_false(StudioTemplates.template_text(step[1]).is_empty(), "%s: template %s" % [shot["name"], step[1]])
			elif step[0] == "palette":
				assert_true(StoryBlocks.GROUPS.has(step[1]), "%s: group %s" % [shot["name"], step[1]])
	var script := FileAccess.get_file_as_string("res://tools/studio_screenshots.gd")
	for step in steps:
		assert_true(script.contains("\t\t\"%s\":" % step), "the script does " + step)

extends "res://tests/framework/story_test.gd"
## Tests for project extensions loaded from the config: custom actions
## listed in StoryConfig.actions or saved in StoryConfig.action_folder, and
## tales in StoryConfig.mod_folder.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const RING_BELL := preload("res://tests/fixtures/actions/action_ring_bell.gd")


func test_config_actions_run_in_tales_and_are_known_to_the_checker() -> void:
	var story: Node = track(StoryScript.new())
	var config := StoryConfig.new()
	config.crew = [TaleDirector]
	config.actions = [RING_BELL]
	story.start(config)
	tree.root.add_child(story)
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	var context := director.make_check_context("t")
	assert_true(context.actions.has("ring_bell"))
	var result := TaleCompiler.build("beat start:\n\tring_bell(times = 3)\n", "t", context)
	for diagnostic in result["diagnostics"]:
		fail(str(diagnostic))
	var bad := TaleCompiler.build("beat start:\n\tring_bell(loud = true)\n", "t", context)
	assert_eq(bad["diagnostics"].size(), 1, "its parameters are checked like a built-in action's")
	var rings := []
	director.story_signal.connect(func(signal_name: String, value: Variant) -> void: rings.append([signal_name, value]))
	director.add_tale(result["tale"])
	await director.play("t")
	assert_eq(rings, [["bell", 3]])


func test_entries_that_are_not_actions_are_skipped() -> void:
	var scripts: Array[Script] = [RING_BELL, preload("res://tests/fixtures/fake_crew.gd"), null]
	var made := StoryConfig.make_actions(scripts)
	assert_eq(made.size(), 1)
	assert_eq(made[0].get_action_name(), "ring_bell")


func test_actions_in_the_action_folder_are_found() -> void:
	var config := StoryConfig.new()
	config.action_folder = "res://tests/fixtures/actions"
	assert_eq(config.get_action_scripts(), [RING_BELL] as Array[Script], "actions only")
	config.actions = [RING_BELL]
	assert_eq(config.get_action_scripts().size(), 1, "listed scripts are not added twice")
	config.action_folder = "res://no_such_folder"
	assert_eq(config.get_action_scripts(), [RING_BELL] as Array[Script])


func test_the_mod_folder_loads_when_the_story_starts() -> void:
	var folder := "user://test_mod_start"
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder.path_join("visitor.tale"), FileAccess.WRITE)
	file.store_string("beat start:\n\t\"A visiting story.\"\n")
	file.close()
	var story: Node = track(StoryScript.new())
	var config := StoryConfig.new()
	config.crew = [TaleDirector]
	config.mod_folder = folder
	story.start(config)
	tree.root.add_child(story)
	await tree.process_frame
	var director: TaleDirector = story.get_crew(&"TaleDirector")
	assert_not_null(director.get_tale("visitor"))
	DirAccess.remove_absolute(folder.path_join("visitor.tale"))

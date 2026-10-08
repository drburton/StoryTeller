extends "res://tests/framework/story_test.gd"
## Tests for the Story autoload's crew lifecycle.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const FakeCrew := preload("res://tests/fixtures/fake_crew.gd")
const OtherCrew := preload("res://tests/fixtures/other_crew.gd")
const NotCrew := preload("res://tests/fixtures/not_crew.gd")


func _make_story(crew: Array[Script] = []) -> Node:
	var config := StoryConfig.new()
	config.crew = crew
	var story: Node = track(StoryScript.new())
	story.start(config)
	return story


func test_start_with_empty_config() -> void:
	var story := _make_story()
	assert_true(story.is_ready)
	assert_eq(story.get_crew_names().size(), 0)


func test_start_emits_crew_ready() -> void:
	var story: Node = track(StoryScript.new())
	var emitted := [false]
	story.crew_ready.connect(func() -> void: emitted[0] = true)
	story.start(StoryConfig.new())
	assert_true(emitted[0], "crew_ready should fire")


func test_crew_created_in_config_order() -> void:
	var story := _make_story([FakeCrew, OtherCrew])
	assert_eq(story.get_crew_names(), [&"Fake", &"Other"])
	assert_true(story.has_crew(&"Fake"))
	assert_eq(story.get_crew(&"Other").name, &"Other", "node is named after the crew key")


func test_setup_receives_config() -> void:
	var story := _make_story([FakeCrew])
	var fake: Node = story.get_crew(&"Fake")
	assert_eq(fake.setup_count, 1)
	assert_true(fake.setup_config == story.config)


func test_missing_crew_returns_null() -> void:
	var story := _make_story()
	assert_null(story.get_crew(&"Nope"))


func test_duplicate_crew_is_rejected() -> void:
	var story := _make_story([FakeCrew])
	var added: bool = story.add_crew(FakeCrew.new())
	assert_false(added)
	assert_eq(story.get_crew_names().size(), 1)


func test_non_crew_script_is_skipped() -> void:
	var story := _make_story([NotCrew, OtherCrew])
	assert_eq(story.get_crew_names(), [&"Other"])


func test_clear_all_resets_members() -> void:
	var story := _make_story([FakeCrew])
	var fake: Node = story.get_crew(&"Fake")
	fake.value = 5
	story.clear_all()
	assert_eq(fake.clear_count, 1)
	assert_eq(fake.value, 0)


func test_capture_and_restore_round_trip() -> void:
	var story := _make_story([FakeCrew])
	story.get_crew(&"Fake").value = 42
	var state: Dictionary = story.capture()
	assert_eq(state["format"], StoryScript.STATE_FORMAT)

	var json := JSON.stringify(state)
	story.get_crew(&"Fake").value = 0
	story.restore(JSON.parse_string(json))
	assert_eq(story.get_crew(&"Fake").value, 42, "state survives JSON")


func test_restore_skips_unknown_crew() -> void:
	var story := _make_story([FakeCrew])
	story.restore({"format": StoryScript.STATE_FORMAT, "crew": {"Gone": {}, "Fake": {"value": 3}}})
	assert_eq(story.get_crew(&"Fake").value, 3)


func test_restart_replaces_crew() -> void:
	var story := _make_story([FakeCrew])
	var first: Node = story.get_crew(&"Fake")
	story.start(StoryConfig.new())
	assert_false(is_instance_valid(first), "old crew is freed")
	assert_eq(story.get_crew_names().size(), 0)


func test_shut_down_calls_teardown() -> void:
	var story := _make_story([FakeCrew])
	var fake: Node = story.get_crew(&"Fake")
	var events := []
	fake.events = events
	story.shut_down()
	assert_eq(events, ["teardown"])
	assert_false(story.is_ready)
	assert_eq(story.get_crew_names().size(), 0)


func test_story_in_tree_starts_itself() -> void:
	var story: Node = track(StoryScript.new())
	tree.root.add_child(story)
	assert_true(story.is_ready, "_ready starts the story with the project config")
	assert_not_null(story.config)


func test_load_config_falls_back_to_defaults() -> void:
	var setting := StoryScript.CONFIG_SETTING
	var had_setting := ProjectSettings.has_setting(setting)
	var previous: Variant = ProjectSettings.get_setting(setting, null)
	ProjectSettings.set_setting(setting, "res://does/not/exist.tres")
	var config: StoryConfig = StoryScript.load_config()
	assert_not_null(config)
	assert_eq(config.crew.size(), 0)
	if had_setting:
		ProjectSettings.set_setting(setting, previous)
	else:
		ProjectSettings.set_setting(setting, null)

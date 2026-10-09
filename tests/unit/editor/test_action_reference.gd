extends "res://tests/framework/story_test.gd"
## Keeps docs/action-reference.md in step with the built-in actions.


func test_reference_is_current() -> void:
	var on_disk := FileAccess.get_file_as_string(ActionReference.PATH).replace("\r\n", "\n")
	assert_true(on_disk == ActionReference.build(), "docs/action-reference.md is out of date; run addons/storyteller/editor/write_action_reference.gd")


func test_every_action_has_a_section_and_a_description() -> void:
	var text := ActionReference.build()
	for script in TaleDirector.BUILTIN_ACTIONS:
		var action: TaleAction = script.new()
		assert_true(text.contains("\n## %s\n" % action.get_action_name()), action.get_action_name())
	assert_false(text.contains("No description yet."), "every action script has a ## comment")
	assert_true(text.contains("backdrop(name, transition = \"fade\", time = 1.0, mask = \"\")"))
	assert_true(text.contains("fade_out(color = Color.BLACK, time = 0.5)"))
	assert_true(text.contains("prop(name, at = Vector2(0.5, 0.5), time = 0.3)"))

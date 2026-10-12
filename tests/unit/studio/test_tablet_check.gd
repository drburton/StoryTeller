extends "res://tests/framework/story_test.gd"
## Tests for the Studio's tablet check app (studio/check/): its panels,
## block dragging, saved results, and the summary a tester sends back.

const CheckScene := preload("res://studio/check/tablet_check.tscn")
const TabletCheck := preload("res://studio/check/tablet_check.gd")


func before_each() -> void:
	super()
	_clean()


func after_each() -> void:
	_clean()
	super()


func _clean() -> void:
	# The check counts one start per app run; each test is a fresh run.
	if Engine.has_meta("tablet_check_counted"):
		Engine.remove_meta("tablet_check_counted")
	for path in [TabletCheck.RESULTS_PATH, TabletCheck.STARTS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _open() -> Control:
	var check: Control = track(CheckScene.instantiate())
	tree.root.add_child(check)
	await tree.process_frame
	return check


func _dropped(check: Control) -> Array:
	return check._drop_column.get_children().map(func(block: Node) -> String: return block.get_meta("block_name"))


func test_every_check_appears_in_the_summary() -> void:
	var check := await _open()
	var summary: String = check.summary()
	for item in TabletCheck.CHECKS:
		assert_true(summary.contains("%s: not checked" % item["title"]), item["title"])
	assert_true(summary.contains(OS.get_name()), "names the device")


func test_blocks_are_copied_from_the_palette_and_reordered() -> void:
	var check := await _open()
	var palette: Array = check.find_children("*", "PanelContainer", true, false).filter(func(node: Node) -> bool:
		return node.has_meta("block_name") and node.get_parent() != check._drop_column)
	var area: Rect2 = (check._drop_column.get_parent() as Control).get_global_rect()
	for i in [0, 3]:
		check._start_drag(palette[i], palette[i].get_global_rect().get_center())
		check._drop(area.get_center() + Vector2(0, area.size.y / 3))
		await tree.process_frame
	assert_eq(_dropped(check), ["Say", "Choice"])
	assert_eq(palette.size(), TabletCheck.BLOCK_NAMES.size(), "the palette keeps its blocks")
	assert_false(check._drop_hint.visible)
	await tree.process_frame
	var choice: Control = check._drop_column.get_child(1)
	check._start_drag(choice, choice.get_global_rect().get_center())
	check._drop(area.position + Vector2(20, 2))
	assert_eq(_dropped(check), ["Choice", "Say"], "dropping above the first block moves it to the top")
	var say: Control = check._drop_column.get_child(1)
	check._start_drag(say, say.get_global_rect().get_center())
	check._drop(Vector2(-500, -500))
	await tree.process_frame
	assert_eq(_dropped(check), ["Choice"], "dropping outside the box removes the block")


func test_results_and_starts_are_kept_between_runs() -> void:
	var first := await _open()
	var works: Button = first.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.text == "Works")[0]
	works.pressed.emit()
	assert_true(first.summary().contains("1. Starting up: works"))
	first.queue_free()
	await tree.process_frame
	var second := await _open()
	assert_true(second.summary().contains("1. Starting up: works"), "results are read back")
	assert_eq(second._starts, 1, "the second screen in the same run doesn't count as a new start")


func test_tune_is_a_short_sound() -> void:
	var tune := TabletCheck._tune()
	assert_eq(tune.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_true(tune.get_length() > 0.5 and tune.get_length() < 1.0, str(tune.get_length()))

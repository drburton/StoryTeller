extends "res://tests/framework/story_test.gd"
## Tests for the Studio's block editor (studio/blocks/): showing a scene's
## blocks, adding, moving and deleting them by dragging, editing fields,
## arms of Choice and If blocks, and undo.

const BlockEditor := preload("res://studio/blocks/block_editor.gd")
const EXAMPLE := "res://examples/wheres_biscuit/tales/wheres_biscuit.tale"
const SOURCE := """var score := 0

beat start:
	backdrop("yard")
	theo.enter("happy", at = LEFT)
	theo: "Where is Biscuit?"
	choose:
		"Look in the box":
			score += 1
		"Look outside":
			pass
	jump yard

beat yard:
	"The yard is quiet."
"""


func _open(text := SOURCE) -> StudioBlockEditor:
	var editor: StudioBlockEditor = track(BlockEditor.new())
	editor.size = Vector2(1100, 760)
	tree.root.add_child(editor)
	editor.set_source(text)
	await tree.process_frame
	await tree.process_frame
	return editor


func _types(editor: StudioBlockEditor) -> Array:
	return editor.get_blocks().map(func(block: Control) -> String: return block.get_meta("block")["type"])


func _beat_lines(editor: StudioBlockEditor, beat_name: String) -> PackedStringArray:
	var doc := TaleParser.parse(editor.source)
	var span := TaleEdit.span(doc.find_beat(beat_name))
	return editor.source.split("\n").slice(span.x, span.y)


func _palette_block(editor: StudioBlockEditor, group: String, type: String) -> Control:
	editor.show_group(group)
	for block in editor.get_palette_blocks():
		if block.get_meta("new_type") == type:
			return block
	return null


func test_a_scene_shows_its_blocks_and_arms() -> void:
	var editor := await _open()
	assert_eq(editor.get_scenes(), PackedStringArray(["start", "yard"]))
	assert_eq(editor.get_scene_buttons()[1].text, "Yard")
	assert_eq(_types(editor), ["background", "show", "say", "choice", "add", "go_to"])
	assert_eq(editor.lane_count(), 3, "the scene and two options")
	editor.select_scene("yard")
	assert_eq(_types(editor), ["narrate"])
	assert_eq(StudioBlockEditor.scene_title("toy_box"), "Toy box")


func test_the_example_story_shows_without_code_blocks() -> void:
	var editor := await _open(FileAccess.get_file_as_string(EXAMPLE))
	for scene in editor.get_scenes():
		editor.select_scene(scene)
		assert_false(_types(editor).has("code"), scene)
		assert_false(_types(editor).is_empty(), scene)


func test_new_blocks_are_added_and_undone() -> void:
	var editor := await _open()
	var changes := []
	editor.source_changed.connect(func(text: String) -> void: changes.append(text))
	assert_true(editor.add_block("narrate", 0, 0, {"text": "A sunny day."}))
	assert_eq(_beat_lines(editor, "start")[0], "\t\"A sunny day.\"")
	assert_true(editor.add_block("hide", 0, 2))
	assert_eq(_beat_lines(editor, "start")[2], "\ttheo.exit()", "the character is the story's first one")
	assert_eq(changes.size(), 2)
	assert_true(editor.undo())
	assert_true(editor.undo())
	assert_eq(editor.source, SOURCE)
	assert_false(editor.can_undo())
	assert_true(editor.redo())
	assert_eq(_beat_lines(editor, "start")[0], "\t\"A sunny day.\"")
	assert_eq(changes.size(), 5)


func test_number_blocks_declare_their_number() -> void:
	var editor := await _open("beat start:\n\t\"Hi\"\n")
	assert_true(editor.add_block("add", 0, 1))
	assert_eq(editor.source, "var score := 0\n\nbeat start:\n\t\"Hi\"\n\tscore += 1\n")
	assert_true(editor.add_block("ask_name", 0, 0))
	assert_true(editor.source.begins_with("var score := 0\nvar player_name := \"\"\n"))
	assert_false(TaleParser.parse(editor.source).has_errors())


func test_blocks_move_between_lists() -> void:
	var editor := await _open()
	var blocks := editor.get_blocks()
	assert_true(editor.move_block(blocks[0], 0, 3), "background under the speech")
	assert_eq(_types(editor), ["show", "say", "background", "choice", "add", "go_to"])
	var choice := editor.get_blocks()[3]
	var outside := editor.arm_lane(choice, 1)
	assert_true(editor.move_block(editor.get_blocks()[0], outside, 0), "show into the second option")
	assert_eq(_beat_lines(editor, "start").slice(5, 8), PackedStringArray(["\t\t\"Look outside\":", "\t\t\ttheo.enter(\"happy\", at = LEFT)", "\tjump yard"]))
	choice = editor.get_blocks()[2]
	assert_eq(choice.get_meta("block")["type"], "choice")
	assert_false(editor.move_block(choice, editor.arm_lane(choice, 0), 0), "not into itself")
	assert_false(TaleParser.parse(editor.source).has_errors())


func test_dragging_from_the_palette_and_back_to_it() -> void:
	var editor := await _open()
	var narrate := _palette_block(editor, "talk", "narrate")
	var say := editor.get_blocks()[2]
	editor.start_drag(narrate, narrate.get_global_rect().get_center())
	editor.move_drag(say.get_global_rect().get_center() - Vector2(0, say.size.y / 4))
	assert_eq(editor.get_drop_target(), {"lane": 0, "index": 2})
	assert_true(editor._drop_line.visible, "a line shows where it lands")
	editor.drop(say.get_global_rect().get_center() - Vector2(0, say.size.y / 4))
	await tree.process_frame
	assert_eq(_types(editor), ["background", "show", "narrate", "say", "choice", "add", "go_to"])
	var first := editor.get_blocks()[0]
	editor.start_drag(first, first.get_global_rect().get_center())
	editor.move_drag(editor.palette.get_global_rect().get_center())
	assert_eq(editor.get_drop_target(), {"delete": true})
	editor.drop(editor.palette.get_global_rect().get_center())
	await tree.process_frame
	assert_eq(_types(editor), ["show", "narrate", "say", "choice", "add", "go_to"])
	assert_false(editor.is_dragging())


func test_dragging_with_the_mouse() -> void:
	var old_size := tree.root.size
	tree.root.size = Vector2i(1280, 800)
	var editor := await _open()
	var show := editor.get_blocks()[1]
	var from := show.get_global_rect().get_center()
	var to := editor.get_blocks()[0].get_global_rect().position + Vector2(10, 2)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	tree.root.push_input(press)
	await tree.process_frame
	assert_eq(editor._pressing, show, "pressing a chip holds its block")
	for step in 5:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = from.lerp(to, (step + 1) / 5.0)
		motion.global_position = motion.position
		motion.relative = (to - from) / 5.0
		tree.root.push_input(motion)
		await tree.process_frame
	assert_true(editor.is_dragging())
	var release := press.duplicate()
	release.pressed = false
	release.position = to
	release.global_position = to
	tree.root.push_input(release)
	await tree.process_frame
	await tree.process_frame
	assert_eq(_types(editor), ["show", "background", "say", "choice", "add", "go_to"])
	tree.root.size = old_size


func test_nothing_goes_after_go_to_scene() -> void:
	var editor := await _open()
	assert_eq(editor.allowed_index(0, 5, "say", null), 4, "a block dropped at the end goes above Go to scene")
	assert_eq(editor.allowed_index(0, 5, "the_end", null), -1, "the list already ends")
	var choice := editor.get_blocks()[3]
	assert_eq(editor.allowed_index(editor.arm_lane(choice, 1), 0, "go_to", null), 0)
	var go_to := editor.get_blocks()[5]
	assert_eq(editor.allowed_index(0, 2, "go_to", go_to), 5, "moving Go to scene keeps it at the end")


func test_fields_rewrite_their_line() -> void:
	var editor := await _open()
	var show := editor.get_blocks()[1]
	editor.edit_field(show, "field:position")
	assert_eq(_beat_lines(editor, "start")[1], "\ttheo.enter(\"happy\", at = CENTER)", "a tap moves to the next place")
	var say := editor.get_blocks()[2]
	editor.edit_field(say, "field:text")
	var dialog := editor.get_dialog()
	assert_not_null(dialog)
	var field: LineEdit = dialog.find_children("*", "LineEdit", true, false)[0]
	assert_eq(field.text, "Where is Biscuit?")
	field.text = "Biscuit? Where are you?"
	field.text_submitted.emit(field.text)
	assert_null(editor.get_dialog())
	assert_eq(_beat_lines(editor, "start")[2], "\ttheo: \"Biscuit? Where are you?\"")
	var choice := editor.get_blocks()[3]
	assert_true(editor.set_field(choice, "arm:0:text", "Check the box"))
	assert_eq(_beat_lines(editor, "start")[4], "\t\t\"Check the box\":")


func test_changes_that_would_break_the_tale_are_refused() -> void:
	var editor := await _open()
	var add := editor.get_blocks()[4]
	assert_false(editor.set_field(add, "field:value", "two words"))
	assert_eq(editor.source, SOURCE)
	assert_true(editor._message.visible)
	assert_false(editor.can_undo())


func test_choice_and_if_arms() -> void:
	var editor := await _open()
	var choice := editor.get_blocks()[3]
	assert_true(editor.add_arm(choice, "option"))
	choice = editor.get_blocks()[3]
	assert_eq(choice.get_meta("block")["arms"].size(), 3)
	assert_true(editor.remove_arm(choice, 0))
	choice = editor.get_blocks()[3]
	assert_true(editor.remove_arm(choice, 0))
	choice = editor.get_blocks()[3]
	assert_false(editor.remove_arm(choice, 0), "a choice keeps one option")
	assert_true(editor.add_block("if", 0, 0))
	var check := editor.get_blocks()[0]
	assert_eq(check.get_meta("block")["type"], "if")
	assert_true(editor.add_arm(check, "else"))
	check = editor.get_blocks()[0]
	assert_false(editor.add_arm(check, "else"), "one Otherwise")
	assert_true(editor.add_arm(check, "elif"))
	assert_eq(_beat_lines(editor, "start").slice(0, 6), PackedStringArray(["\tif score >= 1:", "\t\tpass", "\telif score >= 1:", "\t\tpass", "\telse:", "\t\tpass"]))
	check = editor.get_blocks()[0]
	assert_false(editor.remove_arm(check, 0), "the If arm stays")
	assert_true(editor.remove_arm(check, 2))
	assert_false(TaleParser.parse(editor.source).has_errors())


func test_scenes_with_only_notes_stay_valid() -> void:
	var editor := await _open()
	editor.add_scene()
	assert_eq(editor.current_scene, "scene_3")
	assert_eq(_types(editor), [])
	assert_true(editor.add_block("note", 0, 0, {"text": "Biscuit hides here"}))
	assert_false(TaleParser.parse(editor.source).has_errors())
	assert_eq(_types(editor), ["note"])
	editor.select_scene("yard")
	assert_true(editor.add_block("note", 0, 0, {"text": "Quiet"}))
	assert_true(editor.delete_block(editor.get_blocks()[1]))
	assert_false(TaleParser.parse(editor.source).has_errors())
	assert_eq(_types(editor), ["note"])


func test_code_blocks_hold_their_text() -> void:
	var editor := await _open("beat start:\n\tfor i in 3:\n\t\tpass\n\t\"Hi\"\n")
	var code := editor.get_blocks()[0]
	assert_eq(code.get_meta("block")["type"], "code")
	assert_true(editor.set_field(code, "field:code", "for i in 2:\n\t\"Again\""))
	assert_eq(editor.source, "beat start:\n\tfor i in 2:\n\t\t\"Again\"\n\t\"Hi\"\n")
	assert_true(editor.set_field(editor.get_blocks()[0], "field:code", ""))
	assert_eq(editor.source, "beat start:\n\t\"Hi\"\n")
	assert_false(editor.add_block("code", 0, 0), "asks for the code first")
	assert_not_null(editor.get_dialog())
	editor.close_dialog()


func test_tapping_a_palette_block_adds_it_under_the_chosen_block() -> void:
	var editor := await _open()
	editor.select_block(editor.get_blocks()[0])
	editor._tap(_palette_block(editor, "scene", "sound"))
	assert_eq(_types(editor), ["background", "sound", "show", "say", "choice", "add", "go_to"])
	editor._selected_line = -1
	editor._tap(_palette_block(editor, "choose", "the_end"))
	assert_true(editor._message.visible, "the scene already ends")
	editor._tap(_palette_block(editor, "talk", "say"))
	assert_eq(_types(editor).slice(-2), ["say", "go_to"])


func test_long_press_menu_duplicates_and_deletes() -> void:
	var editor := await _open()
	var menu := editor.open_block_menu(editor.get_blocks()[2])
	menu.id_pressed.emit(0)
	assert_eq(_types(editor), ["background", "show", "say", "say", "choice", "add", "go_to"])
	menu.hide()
	menu = editor.open_block_menu(editor.get_blocks()[6])
	assert_true(menu.is_item_disabled(0), "Go to scene is not copied")
	menu.id_pressed.emit(1)
	assert_eq(_types(editor), ["background", "show", "say", "say", "choice", "add"])
	menu.hide()


func _tap_at(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		tree.root.push_input(event)
		await tree.process_frame


func test_taps_edit_chips_and_choose_blocks() -> void:
	var old_size := tree.root.size
	tree.root.size = Vector2i(1280, 800)
	var editor := await _open()
	var lines := []
	editor.block_selected.connect(func(line: int) -> void: lines.append(line))
	var chip: Control = editor.get_blocks()[1].find_children("*", "Button", true, false).filter(func(button: Node) -> bool:
		return button.get_meta("field_key", "") == "field:position")[0]
	await _tap_at(chip.get_global_rect().get_center())
	assert_eq(_beat_lines(editor, "start")[1], "\ttheo.enter(\"happy\", at = CENTER)")
	var words: Control = editor.get_blocks()[2].find_children("*", "Label", true, false).filter(func(label: Node) -> bool:
		return label.text == "says")[0]
	await _tap_at(words.get_global_rect().get_center())
	assert_eq(lines, [6])
	assert_eq(editor.get_selected_line(), 6)
	assert_null(editor.get_dialog())
	tree.root.size = old_size

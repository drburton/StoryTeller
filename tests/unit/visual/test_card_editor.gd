extends "res://tests/framework/story_test.gd"
## Tests for the card editor in the Story tab: card edits become small text
## edits, and undo works across the text and card views.

const PATH := "user://card_editor_test.tale"
const SOURCE := """var trust := 0
const narrator := "Narrator"

beat start:
	"Sunlight."
	narrator: "Morning."
	wait(1.0)  # a pause
	choose:
		"Wave":
			trust += 1
		"Leave":
			jump other
	if trust > 0:
		"Friends."
	for i in 2:
		"Again."

beat other:
	pass
"""

var panel: TaleEditorPanel
var editor: TaleCardEditor


func before_each() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	panel = track(TaleEditorPanel.new())
	tree.root.add_child(panel)
	panel.open_file(PATH)
	panel.show_view("cards")
	editor = panel.card_editor
	await tree.process_frame


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _kinds() -> Array:
	return editor.get_card_panels().map(func(card: Control) -> String: return card.get_meta("card_kind"))


func _field(key: String) -> Control:
	var fields := editor.get_fields()
	assert_true(fields.has(key), "no field %s; have %s" % [key, fields.keys()])
	return fields.get(key)


func _set_text(key: String, text: String) -> void:
	var field := _field(key)
	var line: Control = field.get_meta("line_edit") if field.has_meta("line_edit") else field
	line.text = text
	if line.has_meta("commit"):
		line.get_meta("commit").call()
	else:
		field.get_meta("commit").call()


func _changed_lines(text: String) -> Array:
	var a := SOURCE.split("\n")
	var b := text.split("\n")
	var changed := []
	for i in maxi(a.size(), b.size()):
		var x := a[i] if i < a.size() else "<none>"
		var y := b[i] if i < b.size() else "<none>"
		if x != y:
			changed.append(y)
	return changed


func test_cards_show_the_beat() -> void:
	assert_eq(_kinds(), ["NARRATION", "DIALOGUE", "ACTION", "CHOICE", "SET", "JUMP", "CONDITION", "NARRATION", "SCRIPT"])
	assert_eq(editor.beat_list.item_count, 2)
	assert_eq(panel.code_edit.visible, false)


func test_editing_narration_changes_one_line_and_undo_restores_it() -> void:
	_set_text("b/0:text", "Moonlight.")
	assert_eq(_changed_lines(panel.code_edit.text), ["\t\"Moonlight.\""])
	assert_true(panel.is_dirty(PATH), "dirty")
	editor.undo_requested.emit()
	assert_eq(panel.code_edit.text, SOURCE)
	editor.redo_requested.emit()
	assert_true(panel.code_edit.text.contains("\"Moonlight.\""), "redo: " + panel.code_edit.text)


func test_dialogue_and_action_fields() -> void:
	_set_text("b/1:text", "Good \"morning\".")
	assert_eq(_changed_lines(panel.code_edit.text), ["\tnarrator: \"Good \\\"morning\\\".\""])
	_set_text("b/2:seconds", "2.5")
	assert_true(panel.code_edit.text.contains("\twait(2.5)  # a pause") or panel.code_edit.text.contains("\twait(2.5) # a pause"), panel.code_edit.text)


func test_typed_action_form_writes_named_arguments() -> void:
	panel.code_edit.text = SOURCE.replace("wait(1.0)  # a pause", "backdrop(\"library\")")
	panel.check_now()
	panel.show_view("cards")
	_set_text("b/2:time", "2.0")
	assert_true(panel.code_edit.text.contains("\tbackdrop(\"library\", time = 2.0)\n"), panel.code_edit.text)
	_set_text("b/2:name", "=Color.BLACK")
	assert_true(panel.code_edit.text.contains("\tbackdrop(Color.BLACK, time = 2.0)\n"), panel.code_edit.text)
	_field("b/2:await").button_pressed = true
	assert_true(panel.code_edit.text.contains("\tawait backdrop(Color.BLACK, time = 2.0)\n"), panel.code_edit.text)


func test_choice_lanes() -> void:
	_set_text("b/3/o0:text", "Wave back")
	assert_eq(_changed_lines(panel.code_edit.text), ["\t\t\"Wave back\":"])
	_field("b/3/o1:once").button_pressed = true
	assert_true(panel.code_edit.text.contains("\t\t@once \"Leave\":\n"))
	_set_text("b/3/o1:condition", "trust > 0")
	assert_true(panel.code_edit.text.contains("\t\t@once \"Leave\" if trust > 0:\n"))
	_field("b/3:add_option").pressed.emit()
	assert_true(panel.code_edit.text.contains("\t\t\tjump other\n\t\t\"New option\":\n\t\t\tpass\n"), panel.code_edit.text)
	_field("b/3/o2:delete").pressed.emit()
	assert_false(panel.code_edit.text.contains("New option"))


func test_condition_lanes() -> void:
	_set_text("b/4/c0:condition", "trust > 1")
	assert_eq(_changed_lines(panel.code_edit.text), ["\tif trust > 1:"])
	_field("b/4:add_else").pressed.emit()
	assert_true(panel.code_edit.text.contains("\t\t\"Friends.\"\n\telse:\n\t\tpass\n"), panel.code_edit.text)
	_field("b/4:add_elif").pressed.emit()
	assert_true(panel.code_edit.text.contains("\t\t\"Friends.\"\n\telif true:\n\t\tpass\n\telse:\n"), panel.code_edit.text)


func test_add_move_and_delete_cards() -> void:
	var add: MenuButton = _field("b:add")
	var popup := add.get_popup()
	popup.id_pressed.emit(popup.get_item_id(NEW_INDEX("Narration")))
	assert_true(panel.code_edit.text.contains("\t\t\"Again.\"\n\t\"New line.\"\n"), panel.code_edit.text)
	_field("b/0:down").pressed.emit()
	var lines := panel.code_edit.text.split("\n")
	assert_eq([lines[4], lines[5]], ["\tnarrator: \"Morning.\"", "\t\"Sunlight.\""])
	_field("b/1:delete").pressed.emit()
	assert_false(panel.code_edit.text.contains("Sunlight"))


func NEW_INDEX(kind: String) -> int:
	return TaleCardEditor.NEW_CARDS.find(kind)


func test_actions_menu_inserts_a_call_with_required_arguments() -> void:
	var add: MenuButton = _field("b/0:insert")
	var actions: PopupMenu = add.get_popup().get_node("Actions")
	for i in actions.item_count:
		if actions.get_item_text(i) == "weather":
			actions.id_pressed.emit(actions.get_item_id(i))
	assert_true(panel.code_edit.text.contains("\t\"Sunlight.\"\n\tweather(\"none\")\n"), panel.code_edit.text)


func test_script_cards_edit_raw_text() -> void:
	var script: CodeEdit = _field("b/5:script")
	assert_eq(script.text, "for i in 2:\n\t\"Again.\"")
	script.text = "for i in 3:\n\t\"Again and again.\""
	script.get_meta("commit").call()
	assert_true(panel.code_edit.text.contains("\tfor i in 3:\n\t\t\"Again and again.\"\n"), panel.code_edit.text)


func test_beats_add_rename_delete() -> void:
	editor.add_new_beat()
	assert_true(panel.code_edit.text.ends_with("beat other:\n\tpass\n\nbeat new_beat:\n\tpass\n"), panel.code_edit.text)
	assert_eq(editor.current_beat, "new_beat")
	editor.rename_beat("finale")
	assert_true(panel.code_edit.text.ends_with("beat finale:\n\tpass\n"), "rename: " + JSON.stringify(panel.code_edit.text.right(40)))
	editor.delete_current_beat()
	assert_true(panel.code_edit.text.ends_with("beat other:\n\tpass\n"), "delete: " + JSON.stringify(panel.code_edit.text.right(40)))


func test_drag_and_drop_moves_cards_into_lanes() -> void:
	var dialogue: Control = editor.get_card_panels()[1]
	var card: TaleCard = dialogue.get_meta("card")
	var wave: TaleNode = TaleEdit.content_children(editor.doc.find_beat("start"))[3].body[0]
	editor._drop(Vector2.ZERO, {"tale_card_lines": [card.node.line_start]}, wave, 1)
	assert_true(panel.code_edit.text.contains("\t\t\ttrust += 1\n\t\t\tnarrator: \"Morning.\"\n"), panel.code_edit.text)


func test_a_card_cannot_be_dropped_inside_itself() -> void:
	var choice: TaleCard = editor.get_card_panels()[3].get_meta("card")
	var wave: TaleNode = choice.lanes[0]["node"]
	editor._drop(Vector2.ZERO, {"tale_card_lines": [choice.node.line_start]}, wave, 0)
	assert_eq(panel.code_edit.text, SOURCE)


func test_problems_show_on_cards() -> void:
	_set_text("b/3/o1/0:target", "nowhere")
	panel.check_now()
	var jump: Control = editor.get_card_panels().filter(func(card: Control) -> bool: return card.get_meta("card_kind") == "JUMP")[0]
	assert_true(jump.tooltip_text.contains("Unknown beat 'nowhere'"), jump.tooltip_text)

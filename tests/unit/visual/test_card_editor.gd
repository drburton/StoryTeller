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


func test_markup_buttons_wrap_the_selection_or_insert_at_the_caret() -> void:
	var text: TextEdit = _field("b/0:text")
	text.select(0, 0, 0, 8)
	_field("b/0:markup:bold").pressed.emit()
	assert_eq(_changed_lines(panel.code_edit.text), ["\t\"[b]Sunlight[/b].\""])
	text = _field("b/0:text")
	text.set_caret_column(text.text.length())
	_field("b/0:markup:pause").pressed.emit()
	assert_eq(_changed_lines(panel.code_edit.text), ["\t\"[b]Sunlight[/b].[pause]\""])
	# Dialogue cards have the bar too; with no selection the caret ends up
	# between the tags.
	text = _field("b/1:text")
	text.set_caret_column(0)
	_field("b/1:markup:slow").pressed.emit()
	assert_true(panel.code_edit.text.contains("\tnarrator: \"[speed=0.5][/speed]Morning.\""), panel.code_edit.text)
	await tree.process_frame
	text = _field("b/1:text")
	assert_eq(text.get_caret_column(), "[speed=0.5]".length(), "caret between the tags")


func test_style_menu_lists_the_projects_text_styles() -> void:
	var menu: MenuButton = _field("b/0:markup:style")
	var popup := menu.get_popup()
	var index := -1
	for i in popup.item_count:
		if popup.get_item_text(i) == "whisper":
			index = i
	assert_true(index >= 0, "whisper is listed")
	var text: TextEdit = _field("b/0:text")
	text.select(0, 0, 0, 8)
	popup.index_pressed.emit(index)
	assert_eq(_changed_lines(panel.code_edit.text), ["\t\"[whisper]Sunlight[/whisper].\""])


func test_speaker_and_mood_pickers_show_thumbnails() -> void:
	panel.code_edit.text = SOURCE.replace("narrator: \"Morning.\"", "mira (smile): \"Morning.\"")
	panel.check_now()
	panel.show_view("cards")
	var thumbnail := editor.get_thumbnail("mira", "smile")
	assert_not_null(thumbnail)
	assert_eq(thumbnail.get_size(), Vector2(TaleCardEditor.THUMBNAIL_SIZE, TaleCardEditor.THUMBNAIL_SIZE))
	assert_null(editor.get_thumbnail("narrator", ""), "not a cast member")
	var mood: OptionButton = _field("b/1:mood")
	assert_eq(mood.get_item_text(mood.selected), "smile")
	assert_eq(mood.get_item_icon(mood.selected), thumbnail)
	var speaker: OptionButton = _field("b/1:speaker")
	assert_not_null(speaker.get_item_icon(speaker.selected))


func test_set_variable_card_picks_from_known_variables() -> void:
	var names := editor.assignable_names()
	assert_eq(names[0], "trust", "this tale's variables first")
	assert_has(names, "mira.friendship", "cast fields")
	var line: LineEdit = _field("b/3/o0/0:target")
	var menu: MenuButton = line.get_parent().get_child(1)
	var popup := menu.get_popup()
	popup.id_pressed.emit(popup.get_item_id(names.find("mira.friendship")))
	assert_true(panel.code_edit.text.contains("\t\t\tmira.friendship += 1\n"), panel.code_edit.text)


## The list beside the field [param key], and the index of [param item].
func _list_item(key: String, item: String) -> Array:
	var line: LineEdit = _field(key)
	var popup := (line.get_parent().get_child(1) as MenuButton).get_popup()
	for i in popup.item_count:
		if popup.get_item_text(i) == item:
			return [popup, i]
	return [popup, -1]


func test_asset_lists_show_pictures() -> void:
	panel.code_edit.text = SOURCE.replace("wait(1.0)  # a pause", "backdrop(\"library\")")
	panel.check_now()
	panel.show_view("cards")
	var found := _list_item("b/2:name", "library")
	assert_true(found[1] >= 0, "library is listed")
	var icon: Texture2D = found[0].get_item_icon(found[1])
	assert_not_null(icon, "backdrops have pictures")
	assert_eq(icon.get_height(), TaleCardEditor.THUMBNAIL_SIZE)
	found = _list_item("b/2:transition", "fade")
	assert_null(found[0].get_item_icon(found[1]), "transitions have none")


func test_choice_and_condition_cards_fold() -> void:
	assert_false(editor.get_fields().has("b/1:collapse"), "only cards with lanes fold")
	_field("b/3:collapse").pressed.emit()
	assert_true(editor.is_folded("b/3"))
	assert_false(_field("b/3/o0:text").is_visible_in_tree(), "the lanes are hidden")
	var choice: Control = editor.get_card_panels()[3]
	var labels := choice.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.visible and label.text.begins_with("2 options"))
	assert_eq(labels.size(), 1, "a summary shows instead")
	assert_eq(labels[0].text, "2 options: \"Wave\", \"Leave\"")
	# Folding survives edits elsewhere and stays with the beat.
	_set_text("b/0:text", "Moonlight.")
	assert_true(editor.is_folded("b/3"))
	editor.select_beat("other")
	assert_false(editor.is_folded("b/3"))
	editor.select_beat("start")
	_field("b/3:collapse").pressed.emit()
	assert_true(_field("b/3/o0:text").is_visible_in_tree())


func _alt_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.alt_pressed = true
	event.pressed = true
	return event


func test_alt_arrows_move_the_focused_card() -> void:
	var text: TextEdit = _field("b/0:text")
	text.grab_focus()
	assert_true(editor._handle_card_keys(_alt_key(KEY_DOWN), text))
	var lines := panel.code_edit.text.split("\n")
	assert_eq([lines[4], lines[5]], ["\tnarrator: \"Morning.\"", "\t\"Sunlight.\""])
	await tree.process_frame
	var focused := tree.root.gui_get_focus_owner()
	assert_eq(focused.get_meta("field_key") if focused != null else "", "b/1:text", "focus follows the card")
	assert_true(editor._handle_card_keys(_alt_key(KEY_UP), focused))
	assert_eq(panel.code_edit.text, SOURCE)
	await tree.process_frame
	focused = tree.root.gui_get_focus_owner()
	editor._handle_card_keys(_alt_key(KEY_UP), focused)
	assert_eq(panel.code_edit.text, SOURCE, "the first card stays first")
	await tree.process_frame
	focused = tree.root.gui_get_focus_owner()
	assert_true(editor._handle_card_keys(_alt_key(KEY_INSERT), focused))
	assert_true(panel.code_edit.text.contains("\t\"Sunlight.\"\n\t\"New line.\"\n"), panel.code_edit.text)
	await tree.process_frame
	focused = tree.root.gui_get_focus_owner()
	assert_eq(focused.get_meta("field_key") if focused != null else "", "b/1:text", "the new card has focus")


func test_typing_narrows_a_list() -> void:
	var line: LineEdit = _field("b/3/o1/0:target")
	var menu: MenuButton = line.get_parent().get_child(1)
	var popup := menu.get_popup()
	var all := popup.item_count
	assert_true(all > 2, "beats of this and other tales are listed")
	line.text = "OTH"
	menu.about_to_popup.emit()
	var names := []
	for i in popup.item_count:
		names.append(popup.get_item_text(i))
	assert_has(names, "other")
	assert_true(names.size() < all and names.all(func(n: String) -> bool: return "oth" in n), "only names containing the typed text, in any case: %s" % [names])
	line.text = "zzz"
	menu.about_to_popup.emit()
	assert_eq(popup.item_count, all, "everything when nothing matches")
	line.text = "start"
	menu.about_to_popup.emit()
	assert_eq(popup.item_count, all, "a whole name lists everything, to pick another")


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


func test_picture_fields_for_picture_choices() -> void:
	assert_false(editor.get_fields().has("b/3/o0:picture"), "a list choice has no picture fields")
	var pictures_path := "user://card_editor_pictures.tale"
	var file := FileAccess.open(pictures_path, FileAccess.WRITE)
	file.store_string("beat start:\n\tchoose(style = \"pictures\"):\n\t\t@once \"Red\":\n\t\t\tpass\n\t\t@picture(\"blue_door\") \"Blue\":\n\t\t\tpass\n")
	file.close()
	panel.open_file(pictures_path)
	panel.show_view("cards")
	await tree.process_frame
	assert_eq(_field("b/0/o1:picture").get_meta("line_edit").text, "blue_door")
	var found := _list_item("b/0/o1:picture", "umbrella")
	assert_not_null(found[0].get_item_icon(found[1]), "choice pictures are shown in the list")
	_set_text("b/0/o0:picture", "red_door")
	assert_true(panel.code_edit.text.contains("\t\t@picture(\"red_door\") @once \"Red\":\n"), panel.code_edit.text)
	_set_text("b/0/o1:picture", "")
	assert_true(panel.code_edit.text.contains("\t\t\"Blue\":\n"), panel.code_edit.text)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pictures_path))


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


func _paste(menu_key: String) -> void:
	var popup := (_field(menu_key) as MenuButton).get_popup()
	popup.about_to_popup.emit()
	var paste := popup.item_count - 1
	assert_eq(popup.get_item_text(paste), "Paste")
	assert_false(popup.is_item_disabled(paste), "Paste is enabled")
	popup.id_pressed.emit(popup.get_item_id(paste))


func test_copied_cards_paste_into_another_tale() -> void:
	_field("b/3:copy").pressed.emit()
	assert_eq(TaleCardEditor.paste_text(), "choose:\n\t\"Wave\":\n\t\ttrust += 1\n\t\"Leave\":\n\t\tjump other")
	var other_path := "user://card_editor_other.tale"
	var file := FileAccess.open(other_path, FileAccess.WRITE)
	file.store_string("beat other:\n    \"Hello.\"\n")
	file.close()
	panel.open_file(other_path)
	panel.show_view("cards")
	await tree.process_frame
	# The other tale indents with spaces; the pasted lines follow it.
	_paste("b/0:insert")
	assert_eq(panel.code_edit.text, "beat other:\n    \"Hello.\"\n    choose:\n        \"Wave\":\n            trust += 1\n        \"Leave\":\n            jump other\n")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(other_path))


func test_paste_takes_only_tale_lines() -> void:
	assert_true(TaleCardEditor.can_paste_text("\"Hi.\"\nada: \"Hello.\""))
	assert_true(TaleCardEditor.can_paste_text("if trust > 0:\n\t\"Friends.\""))
	assert_false(TaleCardEditor.can_paste_text(""))
	assert_false(TaleCardEditor.can_paste_text("beat start:\n\tpass"), "a whole beat")
	assert_false(TaleCardEditor.can_paste_text("Dear diary, (today"), "plain prose")


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

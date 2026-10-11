extends "res://tests/framework/story_test.gd"
## Builds a branching scene from an empty file using only the card editor,
## the way a writer would, and checks the file reads like hand-written
## TaleScript (the M5 exit criterion, without the writer).

const PATH := "user://visual_scene_test.tale"
const EXPECTED := """beat start:
	backdrop("classroom_morning")
	"The bell rings."
	ada (smile): "Ready for the exam?"
	choose:
		"Yes":
			"You nod and pick up your pen."
		@once "Not yet":
			jump ending

beat ending:
	"You stay a little longer."
"""

var panel: TaleEditorPanel
var editor: TaleCardEditor


func before_each() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("")
	file.close()
	panel = track(TaleEditorPanel.new())
	tree.root.add_child(panel)
	panel.open_file(PATH)
	panel.show_view("cards")
	editor = panel.card_editor


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _field(key: String) -> Control:
	var fields := editor.get_fields()
	assert_true(fields.has(key), "no field %s in %s" % [key, fields.keys()])
	return fields.get(key)


func _type(key: String, text: String) -> void:
	var field := _field(key)
	var line: Control = field.get_meta("line_edit") if field.has_meta("line_edit") else field
	line.text = text
	(line.get_meta("commit") if line.has_meta("commit") else field.get_meta("commit")).call()


func _add(menu_key: String, kind: String) -> void:
	var popup: PopupMenu = (_field(menu_key) as MenuButton).get_popup()
	var index := TaleCardEditor.NEW_CARDS.find(kind)
	if index >= 0:
		popup.id_pressed.emit(popup.get_item_id(index))
		return
	var actions: PopupMenu = popup.get_node("Actions")
	for i in actions.item_count:
		if actions.get_item_text(i) == kind:
			actions.id_pressed.emit(actions.get_item_id(i))


func _pick(key: String, item: String) -> void:
	var button: OptionButton = _field(key)
	for i in button.item_count:
		if button.get_item_text(i) == item:
			button.select(i)
			button.item_selected.emit(i)


func test_writer_builds_a_branching_scene_with_cards_only() -> void:
	editor.add_new_beat()
	editor.rename_beat("start")
	_add("b:add", "backdrop")
	_add("b:add", "Narration")
	_type("b/1:text", "The bell rings.")
	_add("b:add", "Dialogue")
	_pick("b/2:speaker", "ada")
	_pick("b/2:mood", "smile")
	_type("b/2:text", "Ready for the exam?")
	_add("b:add", "Choice")
	_type("b/3/o0:text", "Yes")
	_type("b/3/o1:text", "Not yet")
	_field("b/3/o1:once").button_pressed = true
	_add("b/3/o0:add", "Narration")
	_type("b/3/o0/0:text", "You nod and pick up your pen.")
	editor.add_new_beat()
	editor.rename_beat("ending")
	_add("b:add", "Narration")
	_type("b/0:text", "You stay a little longer.")
	editor.select_beat("start")
	_add("b/3/o1:add", "Jump")
	_type("b/3/o1/0:target", "ending")
	assert_eq(panel.code_edit.text, EXPECTED)
	panel.check_now()
	assert_eq(panel.get_diagnostics(), [], "the scene checks cleanly")

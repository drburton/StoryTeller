extends "res://tests/framework/story_test.gd"
## Tests for autocomplete suggestions in the Story editor.

const SOURCE := """var trust := 0
const LIMIT := 3

beat start:
	var local_note := ""
	mira.enter("smile")
	jump other

beat other:
	pass
"""


func _context() -> TaleCheckContext:
	var context := TaleCheckContext.new()
	context.add_action("wait", ["seconds"], 1)
	context.add_action("backdrop", ["name", "transition"], 1)
	context.add_cast("mira", ["smile", "sad", "curious"])
	context.add_exposed("inventory")
	context.add_tale("chapter_1", ["start", "rooftop"], ["weather"])
	return context


## Texts suggested with the caret at the end of [param typed], which is
## added as a new line in a beat of SOURCE (or replaces it with top_level).
func _texts(typed: String, top_level := false) -> Array:
	var source := SOURCE + ("" if top_level else "\nbeat extra:\n") + typed
	var lines := source.split("\n")
	var found := TaleCompletion.suggest(source, lines.size() - 1, typed.length(), _context())
	return found.map(func(item: Dictionary) -> String: return item["text"])


func test_statement_start_offers_keywords_actions_cast_and_variables() -> void:
	var texts := _texts("\t")
	for expected in ["if", "choose", "jump", "wait", "backdrop", "mira", "trust", "LIMIT", "local_note", "inventory", "start"]:
		assert_has(texts, expected)
	assert_false("len" in texts, "functions are offered inside expressions")


func test_prefix_filters_and_sorts() -> void:
	assert_eq(_texts("\tw"), ["wait", "while"])
	assert_eq(_texts("\ttr"), ["trust"])


func test_top_level_offers_declarations() -> void:
	assert_eq(_texts("", true), ["beat", "const", "var"])


func test_annotations() -> void:
	assert_eq(_texts("\t@"), ["global", "heading", "id", "no_rewind", "once", "picture", "show_disabled", "skip_safe", "title", "voice"])
	assert_eq(_texts("\t@s"), ["show_disabled", "skip_safe"])


func test_jump_targets() -> void:
	assert_eq(_texts("\tjump "), ["chapter_1", "extra", "other", "start"])
	assert_eq(_texts("\tjump chapter_1."), ["rooftop", "start"])
	var found := TaleCompletion.suggest("beat a:\n\tjump ch", 1, 8, _context())
	assert_eq(found[0]["insert"], "chapter_1.", "picking a tale adds the dot")


func test_members_of_cast_and_camera() -> void:
	assert_has(_texts("\tmira."), "enter")
	assert_has(_texts("\tmira."), "mood")
	assert_has(_texts("\tmira."), "display_name")
	assert_eq(_texts("\tcamera.z"), ["zoom", "zoom_level"])
	assert_eq(_texts("\tinventory."), [], "exposed objects have no known members")


func test_moods_after_speaker_and_in_enter() -> void:
	assert_eq(_texts("\tmira ("), ["curious", "sad", "smile"])
	assert_eq(_texts("\tmira.enter(\"s"), ["sad", "smile"])


func test_expressions_offer_functions_and_constants() -> void:
	var texts := _texts("\tif ")
	assert_has(texts, "len")
	assert_has(texts, "CENTER")
	assert_has(texts, "not")
	assert_has(texts, "chapter_1")


func test_nothing_inside_strings_or_comments() -> void:
	assert_eq(_texts("\t\"Hello th"), [])
	assert_eq(_texts("\tpass # wa"), [])


func test_actions_insert_a_call() -> void:
	var found := TaleCompletion.suggest("beat a:\n\twa", 1, 3, _context())
	assert_eq(found[0], {"kind": TaleCompletion.Kind.ACTION, "text": "wait", "insert": "wait("})


func test_panel_fills_the_completion_popup() -> void:
	var path := "user://completion_test.tale"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("beat start:\n\tpass\n")
	file.close()
	var panel: TaleEditorPanel = track(TaleEditorPanel.new())
	tree.root.add_child(panel)
	panel.open_file(path)
	panel.code_edit.text = "beat start:\n\tjump st"
	panel.code_edit.set_caret_line(1)
	panel.code_edit.set_caret_column(8)
	panel.show_completions()
	var options := panel.code_edit.get_code_completion_options()
	assert_eq(options.map(func(option: Dictionary) -> String: return option["display_text"]), ["start"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

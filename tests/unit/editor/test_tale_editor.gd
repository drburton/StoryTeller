extends "res://tests/framework/story_test.gd"
## Tests for the Story screen: syntax highlighting, file listing, and the
## editor panel's live checking and saving.


## Returns the role names a highlighted line uses, in column order,
## as "column:role".
func _roles(text: String, open_quote := "") -> Array:
	var highlighter := TaleSyntaxHighlighter.new()
	var by_color := {}
	for role in highlighter.palette:
		by_color[highlighter.palette[role]] = role
	var result := highlighter.highlight_line(text, open_quote)
	var columns: Array = result["colors"].keys()
	columns.sort()
	var roles := []
	for column in columns:
		roles.append("%d:%s" % [column, by_color[result["colors"][column]["color"]]])
	return roles


func test_highlights_beat_and_keywords() -> void:
	assert_eq(_roles("beat start:"), ["0:keyword", "5:beat", "10:symbol"])
	assert_eq(_roles("\tjump other.start"), ["1:keyword", "6:beat", "11:symbol", "12:beat"])


func test_highlights_dialogue_parts() -> void:
	assert_eq(_roles("\tmira (sad): \"Hi {name}[pause]!\""), [
		"1:speaker", "6:symbol", "7:text", "10:symbol", "11:symbol",
		"13:string", "17:interpolation", "23:tag", "30:string",
	])


func test_highlights_comments_numbers_annotations() -> void:
	assert_eq(_roles("@global var gold := 10 # note"), [
		"0:annotation", "8:keyword", "12:text", "17:symbol", "18:symbol", "20:number", "23:comment",
	])
	assert_eq(_roles("## Tale description"), ["0:doc_comment"])


func test_triple_quoted_strings_span_lines() -> void:
	var highlighter := TaleSyntaxHighlighter.new()
	var first := highlighter.highlight_line("\tjonas: \"\"\"It was")
	assert_eq(first["open_quote"], "\"\"\"")
	var second := highlighter.highlight_line("a long night.\"\"\" # end", first["open_quote"])
	assert_eq(second["open_quote"], "")
	assert_eq(_roles("a long night.\"\"\" # end", "\"\"\""), ["0:string", "16:text", "17:comment"])


func test_list_tale_files_skips_ignored_folders() -> void:
	var files := TaleEditorPanel.list_tale_files("res://")
	assert_has(files, "res://demo/tales/welcome.tale")
	assert_has(files, "res://tests/import/sample.tale")
	for path in files:
		assert_false(path.begins_with("res://tests/fixtures/talescript/"), "%s is in a .gdignore folder" % path)


func test_panel_checks_and_saves() -> void:
	var path := "user://panel_test.tale"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("beat start:\n\t\"Hello\"\n")
	file.close()

	var panel: TaleEditorPanel = track(TaleEditorPanel.new())
	tree.root.add_child(panel)
	panel.open_file(path)
	assert_eq(panel.get_current_path(), path)
	assert_eq(panel.get_diagnostics().size(), 0)

	panel.code_edit.text = "beat start:\n\tjump nowhere\n"
	panel.code_edit.text_changed.emit()
	assert_true(panel.is_dirty(path))
	panel.check_now()
	assert_eq(panel.get_diagnostics().size(), 1)
	assert_eq(panel.get_diagnostics()[0].message, "Unknown beat 'nowhere'.")
	assert_eq(panel.problem_list.get_item_text(0), "Error  Line 2: Unknown beat 'nowhere'.")

	panel.save_current()
	assert_false(panel.is_dirty(path))
	assert_eq(FileAccess.get_file_as_string(path), "beat start:\n\tjump nowhere\n")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_panel_keeps_unsaved_edits_when_switching() -> void:
	var first := "user://panel_a.tale"
	var second := "user://panel_b.tale"
	for path in [first, second]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("beat start:\n\tpass\n")
		file.close()
	var panel: TaleEditorPanel = track(TaleEditorPanel.new())
	tree.root.add_child(panel)
	panel.open_file(first)
	panel.code_edit.text = "beat start:\n\t\"edited\"\n"
	panel.code_edit.text_changed.emit()
	panel.open_file(second)
	panel.open_file(first)
	assert_eq(panel.code_edit.text, "beat start:\n\t\"edited\"\n")
	assert_true(panel.is_dirty(first))
	assert_false(panel.is_dirty(second))
	for path in [first, second]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_add_ons_can_extend_the_story_tab() -> void:
	var path := "user://hooks_test.tale"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("beat start:\n\t\"One.\"\n\t\"Two.\"\n")
	file.close()
	assert_null(TaleEditorPanel.get_instance(), "no Story tab yet")
	var panel: TaleEditorPanel = track(TaleEditorPanel.new())
	tree.root.add_child(panel)
	assert_eq(TaleEditorPanel.get_instance(), panel)
	var lines := []
	panel.line_selected.connect(func(selected_path: String, line: int) -> void: lines.append([selected_path.get_file(), line]))
	panel.open_file(path)
	panel.code_edit.set_caret_line(2)
	await tree.process_frame
	assert_eq(panel.get_selected_line(), 3)
	panel.show_view("cards")
	await tree.process_frame
	var field: Control = panel.card_editor.get_fields()["b/0:text"]
	(field.get_meta("line_edit") if field.has_meta("line_edit") else field).grab_focus()
	await tree.process_frame
	assert_eq(lines, [["hooks_test.tale", 1], ["hooks_test.tale", 3], ["hooks_test.tale", 2]], "opening, the caret, then a card")
	var button := Button.new()
	panel.add_toolbar_control(button)
	var toolbar := button.get_parent()
	assert_eq(toolbar.get_child(button.get_index() + 1).text, "Text", "added before the view buttons")
	var side := Label.new()
	var tabs: TabContainer = panel.find_child("SidePanels", true, false)
	assert_false(tabs.visible)
	panel.add_side_panel(side, "Preview")
	assert_true(tabs.visible)
	assert_eq(tabs.get_tab_title(0), "Preview")
	panel.remove_side_panel(side)
	panel.remove_toolbar_control(button)
	assert_false(tabs.visible)
	side.free()
	button.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_pin_line_ids_button_edits_the_open_tale() -> void:
	var path := "user://pin_test.tale"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("beat start:\n\t\"One.\"\n")
	file.close()
	var panel: TaleEditorPanel = track(TaleEditorPanel.new())
	tree.root.add_child(panel)
	panel.open_file(path)
	assert_eq(panel.pin_line_ids(), 1)
	assert_true(panel.code_edit.text.contains("\t@id(\"start_"), panel.code_edit.text)
	assert_true(panel.is_dirty(path), "pinning is an unsaved edit")
	panel.code_edit.undo()
	assert_eq(panel.code_edit.text, "beat start:\n\t\"One.\"\n", "and can be undone")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

extends "res://tests/framework/story_test.gd"
## Tests for TaleParser beyond the golden fixtures.

const K := TaleNode.Kind


func _parse(source: String) -> TaleDocument:
	return TaleParser.parse(source)


func _first_in_beat(source: String) -> TaleNode:
	var doc := _parse("beat test:\n" + source)
	var body := doc.statements[0].body
	return body[0] if not body.is_empty() else null


func _errors(doc: TaleDocument) -> PackedStringArray:
	var texts := PackedStringArray()
	for diagnostic in doc.diagnostics:
		texts.append(str(diagnostic))
	return texts


func test_sample_from_plan_parses_without_errors() -> void:
	var doc := _parse(FileAccess.get_file_as_string("res://tests/fixtures/talescript/prologue.tale"))
	assert_eq(_errors(doc), PackedStringArray())
	assert_not_null(doc.find_beat("walk"))
	assert_null(doc.find_beat("missing"))


func test_dialogue_and_narration() -> void:
	var line := _first_in_beat("\tmira (soft): \"Hi\"\n")
	assert_eq(line.kind, K.DIALOGUE)
	assert_eq(line.name, "mira")
	assert_eq(line.mood, "soft")
	assert_eq(line.expr.value, "Hi")
	assert_eq(_first_in_beat("\t\"Rain.\"\n").kind, K.NARRATION)


func test_calls_are_not_dialogue() -> void:
	assert_eq(_first_in_beat("\tmira.enter(\"smile\")\n").kind, K.EXPRESSION)
	assert_eq(_first_in_beat("\tshake(0.3)\n").kind, K.EXPRESSION)


func test_named_arguments_keep_order() -> void:
	var call := _first_in_beat("\tshow(1, b = 2, a = 3)\n").expr
	assert_eq(call.get_call_name(), "show")
	assert_eq(call.args.size(), 1)
	assert_eq(call.named_args.keys(), ["b", "a"])


func test_if_elif_else_are_siblings() -> void:
	var doc := _parse("beat t:\n\tif a:\n\t\tpass\n\telif b:\n\t\tpass\n\telse:\n\t\tpass\n")
	var kinds := []
	for node in doc.statements[0].body:
		kinds.append(node.kind)
	assert_eq(kinds, [K.IF, K.ELIF, K.ELSE])


func test_inline_block_body() -> void:
	var node := _first_in_beat("\tif done: jump end\n")
	assert_eq(node.body.size(), 1)
	assert_true(node.body[0].inline)
	assert_eq(node.body[0].jump_target, "end")


func test_annotations_attach_to_statement() -> void:
	var doc := _parse("@global var seen := false\n")
	var node := doc.statements[0]
	assert_eq(node.kind, K.VAR)
	assert_eq(node.annotations.size(), 1)
	assert_eq(node.annotations[0].name, "global")


func test_choose_context_parses_options() -> void:
	var node := _first_in_beat("\tchoose:\n\t\t\"A\" if x > 1:\n\t\t\tpass\n\t\ttimeout:\n\t\t\tpass\n")
	assert_eq(node.kind, K.CHOOSE)
	assert_eq(node.body[0].kind, K.OPTION)
	assert_eq(node.body[0].condition.to_sexpr(), "(> x 1)")
	assert_eq(node.body[1].kind, K.TIMEOUT)


func test_spaces_work_for_indentation() -> void:
	var doc := _parse("beat t:\n    if x:\n        \"y\"\n    \"z\"\n")
	assert_eq(_errors(doc), PackedStringArray())
	assert_eq(doc.statements[0].body.size(), 2)


func test_mixed_indentation_is_an_error() -> void:
	var doc := _parse("beat t:\n\t\"x\"\nbeat u:\n    \"y\"\n")
	assert_eq(_errors(doc), PackedStringArray(["4:1: error: Indentation uses tabs elsewhere in this file."]))


func test_missing_block_is_an_error() -> void:
	var doc := _parse("beat t:\nbeat u:\n\tpass\n")
	assert_eq(_errors(doc), PackedStringArray(["2:1: error: Expected an indented block after 'beat t'."]))


func test_dedent_to_unknown_level_is_an_error() -> void:
	var doc := _parse("beat t:\n\t\tif x:\n\t\t\t\"y\"\n\t\"z\"\n")
	assert_eq(_errors(doc), PackedStringArray(["4:1: error: Indentation does not match any outer block."]))


func test_statements_outside_beats_are_errors() -> void:
	var doc := _parse("\"Lost narration\"\n")
	assert_eq(doc.statements[0].kind, K.ERROR)
	assert_true(doc.has_errors())


func test_keywords_cannot_be_names() -> void:
	var doc := _parse("var match := 1\n")
	assert_eq(_errors(doc), PackedStringArray(["1:5: error: 'match' is a reserved word and can't be used as a variable name."]))


func test_trailing_comment_is_kept() -> void:
	var node := _first_in_beat("\tjump end  # go\n")
	assert_eq(node.comment, " go")


func test_orphaned_block_reports_one_error() -> void:
	var doc := _parse("var x := 1\n\t\"one\"\n\t\"two\"\n\t\"three\"\nbeat b:\n\tpass\n")
	assert_eq(_errors(doc), PackedStringArray(["2:1: error: Unexpected indentation."]))
	assert_eq(doc.to_source(), "var x := 1\n\t\"one\"\n\t\"two\"\n\t\"three\"\nbeat b:\n\tpass\n")
	assert_not_null(doc.find_beat("b"))

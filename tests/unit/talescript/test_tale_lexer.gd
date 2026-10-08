extends "res://tests/framework/story_test.gd"
## Tests for TaleLexer.

const T := TaleToken.Type


func _lex(source: String) -> Array[TaleToken]:
	return TaleLexer.new().tokenize(source)


func _types(tokens: Array[TaleToken]) -> Array:
	var types := []
	for token in tokens:
		types.append(token.type)
	return types


func test_simple_line() -> void:
	var tokens := _lex("mira: \"Hi\"\n")
	assert_eq(_types(tokens), [T.IDENTIFIER, T.OPERATOR, T.STRING, T.NEWLINE, T.END])
	assert_eq(tokens[2].value, "Hi")
	assert_eq(tokens[2].column, 7)


func test_keywords_and_identifiers() -> void:
	var tokens := _lex("beat timeout choose")
	assert_eq(tokens[0].type, T.KEYWORD)
	assert_eq(tokens[1].type, T.IDENTIFIER, "'timeout' is only special inside choose")
	assert_eq(tokens[2].type, T.KEYWORD)


func test_numbers() -> void:
	var tokens := _lex("42 1_000 0xFF 0b101 2.5 .5 1e3 7.")
	assert_eq(tokens[0].value, 42)
	assert_eq(tokens[1].value, 1000)
	assert_eq(tokens[2].value, 255)
	assert_eq(tokens[3].value, 5)
	assert_eq(tokens[4].type, T.FLOAT)
	assert_eq(tokens[4].value, 2.5)
	assert_eq(tokens[5].value, 0.5)
	assert_eq(tokens[6].value, 1000.0)
	assert_eq(tokens[6].type, T.FLOAT)
	assert_eq(tokens[7].type, T.INT, "a dot without digits is an operator")
	assert_true(tokens[8].is_op("."))


func test_string_escapes() -> void:
	var tokens := _lex("\"a\\nb\\t\\\"c\\\" \\u00e9\" 'it\\'s'")
	assert_eq(tokens[0].value, "a\nb\t\"c\" é")
	assert_eq(tokens[1].value, "it's")


func test_triple_quoted_string_spans_lines() -> void:
	var tokens := _lex("\"\"\"one\ntwo\"\"\"\nx")
	assert_eq(tokens[0].value, "one\ntwo")
	assert_eq(tokens[1].type, T.NEWLINE)
	assert_eq(tokens[1].line, 2)
	assert_eq(tokens[2].line, 3)


func test_brackets_join_lines() -> void:
	var tokens := _lex("f(\n\t1,\n)\nx")
	assert_eq(_types(tokens), [T.IDENTIFIER, T.OPERATOR, T.INT, T.OPERATOR, T.OPERATOR, T.NEWLINE, T.IDENTIFIER, T.END])


func test_backslash_continuation() -> void:
	var tokens := _lex("x = 1 + \\\n\t2\n")
	assert_eq(_types(tokens), [T.IDENTIFIER, T.OPERATOR, T.INT, T.OPERATOR, T.INT, T.NEWLINE, T.END])


func test_comments_and_annotations() -> void:
	var tokens := _lex("@once \"a\": # note\r\n")
	assert_eq(tokens[0].type, T.ANNOTATION)
	assert_eq(tokens[0].value, "once")
	assert_eq(tokens[3].type, T.COMMENT)
	assert_eq(tokens[3].value, " note", "carriage return is not part of the comment")


func test_longest_operator_wins() -> void:
	var tokens := _lex("a **= b := c != d")
	assert_true(tokens[1].is_op("**="))
	assert_true(tokens[3].is_op(":="))
	assert_true(tokens[5].is_op("!="))


func test_errors_are_reported_with_positions() -> void:
	var lexer := TaleLexer.new()
	lexer.tokenize("x = 1;\n\"open\n$")
	var messages := []
	for diagnostic in lexer.diagnostics:
		messages.append("%d:%d" % [diagnostic.line, diagnostic.column])
	assert_eq(messages, ["1:6", "2:1", "3:1"])


func test_unclosed_bracket_stops_at_dedent() -> void:
	var lexer := TaleLexer.new()
	var tokens := lexer.tokenize("\tx = (1 +\n\ty = 2\n")
	assert_eq(lexer.diagnostics.size(), 1)
	var newlines := 0
	for token in tokens:
		if token.type == T.NEWLINE:
			newlines += 1
	assert_eq(newlines, 2, "the second line is not swallowed")
